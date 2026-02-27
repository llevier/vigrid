#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Vigrid Shell API - A secure REST API for executing shell commands on a Vigrid NAS.

Features:
  - Token-based authentication (Bearer tokens)
  - IP-based access control (CIDR deny/allow, deny-first, default-deny)
  - Per-token command whitelisting/blacklisting via regex (deny-first)
  - Forbidden character checking in command arguments
  - Synchronous and asynchronous command execution with FIFO queue
  - Dry-run mode (commands logged but not executed)
  - Configuration file integrity monitoring
  - HTTPS or HTTP operation
  - Comprehensive structured logging (syslog or JSON format)
  - Foreground/debug mode for troubleshooting
  - systemd service integration with auto-restart
  - User identity switching per token (sudo)

Configuration is loaded from a YAML file (vigrid-shell-api.conf).

Author : Vigrid Project
License: MIT
"""

# =============================================================================
# Standard library imports
# =============================================================================
import argparse
import datetime
import hashlib
import ipaddress
import json
import logging
import logging.handlers
import os
import pwd
import grp
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import traceback
import uuid
from collections import OrderedDict

# =============================================================================
# Third-party imports (installed inside the Python virtual environment)
# =============================================================================
try:
    import yaml
    from flask import Flask, request, jsonify, g
except ImportError as _imp_err:
    print("FATAL: Missing dependency: %s" % _imp_err, file=sys.stderr)
    print("Run: pip install Flask PyYAML", file=sys.stderr)
    sys.exit(1)

# =============================================================================
# Application constants
# =============================================================================
APP_NAME = "vigrid-shell-api"
APP_VERSION = "1.0.0"
DEFAULT_BIND = "0.0.0.0"
DEFAULT_PORT = 8443
DEFAULT_LOG_DIR = "/var/log"
DEFAULT_LOG_FORMAT = "syslog"
DEFAULT_LOG_LEVEL = "INFO"
DEFAULT_RUN_AS = "root"
# Default forbidden characters -- a Python list to avoid YAML escaping issues.
DEFAULT_FORBIDDEN_CHARS = ['"', "'", ';', '\\', '|', '&', '(', ')', '{', '}', '$', '`']
DEFAULT_COMMAND_PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# =============================================================================
# Global mutable state
# =============================================================================
app = Flask(__name__)

config = {}                # Parsed configuration dict
config_file_path = None    # Absolute path to configuration file
config_hash = None         # SHA-256 of the config file content at load time
logger = None              # logging.Logger instance

# Execution queue and tracking
execution_queue = queue.Queue()
pending_orders = OrderedDict()   # order_id -> order dict
pending_lock = threading.Lock()
current_order = None
current_order_lock = threading.Lock()
current_process = None           # subprocess.Popen of the running command
current_process_lock = threading.Lock()
worker_thread = None
shutdown_event = threading.Event()


# #############################################################################
#  CONFIGURATION
# #############################################################################

def _utcnow_iso():
    """Return the current UTC time as an ISO-8601 string."""
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%S.%fZ"
    )


def load_config(path):
    """Load and validate the YAML configuration file.

    Sets the global ``config_hash`` used for integrity checking.

    Args:
        path: Absolute path to the YAML configuration file.

    Returns:
        dict -- the parsed and defaulted configuration.
    """
    global config_hash, config_file_path
    config_file_path = os.path.abspath(path)

    try:
        with open(config_file_path, "r", encoding="utf-8") as fh:
            raw = fh.read()
    except Exception as exc:
        print("FATAL: Cannot read configuration file %s: %s" % (config_file_path, exc),
              file=sys.stderr)
        sys.exit(1)

    config_hash = hashlib.sha256(raw.encode("utf-8")).hexdigest()

    try:
        cfg = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        print("FATAL: Invalid YAML in %s: %s" % (config_file_path, exc),
              file=sys.stderr)
        sys.exit(1)

    if not isinstance(cfg, dict):
        print("FATAL: Configuration file must be a YAML mapping.", file=sys.stderr)
        sys.exit(1)

    # ---- Apply sane defaults ------------------------------------------------
    cfg.setdefault("bind", DEFAULT_BIND)
    cfg.setdefault("port", DEFAULT_PORT)
    cfg.setdefault("run_as", DEFAULT_RUN_AS)
    cfg.setdefault("log_dir", DEFAULT_LOG_DIR)
    cfg.setdefault("log_format", DEFAULT_LOG_FORMAT)
    cfg.setdefault("log_level", DEFAULT_LOG_LEVEL)
    cfg.setdefault("command_path", DEFAULT_COMMAND_PATH)
    cfg.setdefault("dry_run", False)
    cfg.setdefault("tokens", {})
    cfg.setdefault("acl", {"deny": [], "allow": []})
    cfg.setdefault("ssl", {})

    # forbidden_chars: accept either a list of chars or a single string.
    fc = cfg.get("forbidden_chars", None)
    if fc is None:
        cfg["forbidden_chars"] = list(DEFAULT_FORBIDDEN_CHARS)
    elif isinstance(fc, str):
        cfg["forbidden_chars"] = list(fc)
    elif isinstance(fc, list):
        cfg["forbidden_chars"] = [str(c) for c in fc]
    else:
        cfg["forbidden_chars"] = list(DEFAULT_FORBIDDEN_CHARS)

    return cfg


def verify_config_integrity():
    """Return True if the configuration file is unchanged since load.

    Compares the current SHA-256 hash of the config file against the
    hash computed at load time.  Any change (even whitespace) triggers
    a mismatch.
    """
    try:
        with open(config_file_path, "r", encoding="utf-8") as fh:
            current = hashlib.sha256(fh.read().encode("utf-8")).hexdigest()
        return current == config_hash
    except Exception:
        return False


# #############################################################################
#  LOGGING
# #############################################################################

class _JsonFormatter(logging.Formatter):
    """Format log records as single-line JSON objects."""

    def format(self, record):
        obj = {
            "timestamp": _utcnow_iso(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info and record.exc_info[0] is not None:
            obj["exception"] = self.formatException(record.exc_info)
        return json.dumps(obj, ensure_ascii=True)


def setup_logging(cfg, debug=False):
    """Configure and return the application logger.

    Creates a rotating file handler and optionally a stderr handler
    for debug/foreground mode.

    Args:
        cfg:   Configuration dict.
        debug: If True, force DEBUG level and add a stderr handler.

    Returns:
        logging.Logger
    """
    log_dir = cfg.get("log_dir", DEFAULT_LOG_DIR)
    fmt_type = cfg.get("log_format", DEFAULT_LOG_FORMAT).lower()
    level_str = "DEBUG" if debug else cfg.get("log_level", DEFAULT_LOG_LEVEL).upper()
    level = getattr(logging, level_str, logging.INFO)

    _logger = logging.getLogger(APP_NAME)
    _logger.setLevel(level)
    _logger.handlers.clear()

    log_file = os.path.join(log_dir, APP_NAME + ".log")

    # Choose formatter
    if fmt_type == "json":
        formatter = _JsonFormatter()
    else:
        formatter = logging.Formatter(
            "%(asctime)s %(name)s %(levelname)s %(message)s",
            datefmt="%b %d %H:%M:%S",
        )

    # File handler with rotation (50 MB, 5 backups)
    try:
        fh = logging.handlers.RotatingFileHandler(
            log_file, maxBytes=50 * 1024 * 1024, backupCount=5,
        )
        fh.setFormatter(formatter)
        _logger.addHandler(fh)
    except Exception as exc:
        print("WARNING: Cannot open log file %s: %s -- falling back to stderr"
              % (log_file, exc), file=sys.stderr)
        sh = logging.StreamHandler(sys.stderr)
        sh.setFormatter(formatter)
        _logger.addHandler(sh)

    # Stderr handler in debug/foreground mode
    if debug:
        sh = logging.StreamHandler(sys.stderr)
        sh.setLevel(logging.DEBUG)
        sh.setFormatter(formatter)
        _logger.addHandler(sh)

    return _logger


# #############################################################################
#  ACCESS CONTROL -- IP ACL
# #############################################################################

def check_ip_acl(client_ip):
    """Check whether *client_ip* is allowed through the deny/allow ACL.

    Evaluation order:
      1. deny list -- first CIDR match --> REJECT
      2. allow list -- first CIDR match --> ACCEPT
      3. Default --> REJECT

    This design makes it possible to deny a specific IP while allowing
    its surrounding subnet.

    Returns:
        bool -- True if allowed, False otherwise.
    """
    acl = config.get("acl", {})
    deny_list = acl.get("deny", []) or []
    allow_list = acl.get("allow", []) or []

    try:
        addr = ipaddress.ip_address(client_ip)
    except ValueError:
        if logger:
            logger.warning("Invalid client IP address: %s", client_ip)
        return False

    # Step 1: check deny list (first match wins)
    for entry in deny_list:
        try:
            if addr in ipaddress.ip_network(str(entry), strict=False):
                if logger:
                    logger.info("IP %s denied by ACL deny rule: %s", client_ip, entry)
                return False
        except ValueError:
            if logger:
                logger.warning("Invalid deny ACL entry: %s", entry)

    # Step 2: check allow list (first match wins)
    for entry in allow_list:
        try:
            if addr in ipaddress.ip_network(str(entry), strict=False):
                if logger:
                    logger.debug("IP %s allowed by ACL allow rule: %s", client_ip, entry)
                return True
        except ValueError:
            if logger:
                logger.warning("Invalid allow ACL entry: %s", entry)

    # Step 3: default deny
    if logger:
        logger.info("IP %s denied by default (no matching allow rule)", client_ip)
    return False


# #############################################################################
#  ACCESS CONTROL -- TOKEN AUTHENTICATION
# #############################################################################

def authenticate(token_value):
    """Validate a bearer token string.

    Iterates over all configured tokens and compares the secret.

    Returns:
        tuple(str, dict) -- (token_name, token_config) or (None, None).
    """
    for name, tcfg in config.get("tokens", {}).items():
        if tcfg.get("secret") == token_value:
            return name, tcfg
    return None, None


# #############################################################################
#  ACCESS CONTROL -- COMMAND AUTHORIZATION
# #############################################################################

def check_command_authorization(full_cmd, token_cfg):
    """Check whether *full_cmd* is authorized for the given token.

    Evaluation order:
      1. deny_commands -- first regex match --> REJECT
      2. allow_commands -- first regex match --> ACCEPT
      3. Default --> REJECT

    Args:
        full_cmd:  The full command string (command name + arguments).
        token_cfg: Token configuration dict.

    Returns:
        tuple(bool, str) -- (allowed, reason)
    """
    # Step 1: check deny patterns
    for pattern in (token_cfg.get("deny_commands") or []):
        try:
            if re.search(pattern, full_cmd):
                return False, "Command matches deny pattern: %s" % pattern
        except re.error as exc:
            if logger:
                logger.warning("Invalid deny regex '%s': %s", pattern, exc)

    # Step 2: check allow patterns
    for pattern in (token_cfg.get("allow_commands") or []):
        try:
            if re.search(pattern, full_cmd):
                return True, "Command matches allow pattern: %s" % pattern
        except re.error as exc:
            if logger:
                logger.warning("Invalid allow regex '%s': %s", pattern, exc)

    # Step 3: default deny
    return False, "Command does not match any allow pattern"


# #############################################################################
#  VALIDATION HELPERS
# #############################################################################

def validate_user(username):
    """Verify that *username* exists and has a usable login shell.

    A user with /usr/sbin/nologin, /bin/false, or /sbin/nologin as shell
    is considered disabled and rejected.

    Returns:
        tuple(bool, str) -- (valid, reason)
    """
    try:
        pw = pwd.getpwnam(username)
    except KeyError:
        return False, "User '%s' does not exist on this system" % username

    disabled = ("/usr/sbin/nologin", "/bin/false", "/sbin/nologin")
    if pw.pw_shell in disabled:
        return False, "User '%s' has a disabled shell: %s" % (username, pw.pw_shell)
    return True, "OK"


def check_forbidden_chars(arg_string):
    """Check an argument string for forbidden characters.

    Returns:
        tuple(bool, str|None) -- (True, None) if clean, or (False, offending_char).
    """
    forbidden = config.get("forbidden_chars", DEFAULT_FORBIDDEN_CHARS)
    for ch in arg_string:
        if ch in forbidden:
            return False, ch
    return True, None


def resolve_command(cmd_name):
    """Resolve *cmd_name* to a full path via the configured command_path.

    Searches each directory in the colon-separated command_path for an
    executable file matching the command name.

    Returns:
        str or None -- full path if found, None otherwise.
    """
    # If cmd_name is already an absolute path, check it directly
    if os.path.isabs(cmd_name):
        if os.path.isfile(cmd_name) and os.access(cmd_name, os.X_OK):
            return cmd_name
        return None

    for directory in config.get("command_path", DEFAULT_COMMAND_PATH).split(":"):
        full = os.path.join(directory, cmd_name)
        if os.path.isfile(full) and os.access(full, os.X_OK):
            return full
    return None


# #############################################################################
#  COMMAND EXECUTION
# #############################################################################

def execute_command(command, arguments, run_as_user, dry_run=False, timeout=None):
    """Execute a command and capture stdout, stderr, return_code.

    If *run_as_user* differs from the current process user, the command
    is wrapped with ``sudo -u <user> --``.

    If *dry_run* is True the command is **not** executed; a log entry
    is written and synthetic success is returned.

    Args:
        command:     Full path to the command.
        arguments:   List of argument strings.
        run_as_user: Unix username to run the command as.
        dry_run:     If True, do not execute.
        timeout:     Seconds before killing the command (None = no limit).

    Returns:
        dict with keys: stdout, stderr, return_code, dry_run
    """
    global current_process

    # Build the command list, potentially with sudo for user switching
    cmd_list = []
    current_user = pwd.getpwuid(os.getuid()).pw_name
    if run_as_user != current_user:
        cmd_list = ["sudo", "-u", run_as_user, "--"]
    cmd_list.append(command)
    cmd_list.extend(arguments)

    if dry_run:
        if logger:
            logger.info("DRY-RUN: Would execute: %s", " ".join(cmd_list))
        return {
            "stdout": "",
            "stderr": "",
            "return_code": 0,
            "dry_run": True,
        }

    if logger:
        logger.info("Executing: %s (as user: %s)", " ".join(cmd_list), run_as_user)

    env = os.environ.copy()
    env["PATH"] = config.get("command_path", DEFAULT_COMMAND_PATH)

    try:
        proc = subprocess.Popen(
            cmd_list,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            start_new_session=True,
        )
        with current_process_lock:
            current_process = proc

        try:
            stdout_data, stderr_data = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout_data, stderr_data = proc.communicate()
            if logger:
                logger.warning("Command timed out after %s seconds", timeout)
            return {
                "stdout": stdout_data.decode("utf-8", errors="replace"),
                "stderr": stderr_data.decode("utf-8", errors="replace") + "\nCommand timed out.",
                "return_code": -1,
                "dry_run": False,
            }
        finally:
            with current_process_lock:
                current_process = None

        return {
            "stdout": stdout_data.decode("utf-8", errors="replace"),
            "stderr": stderr_data.decode("utf-8", errors="replace"),
            "return_code": proc.returncode,
            "dry_run": False,
        }
    except Exception as exc:
        if logger:
            logger.error("Failed to execute command: %s", exc)
        return {"stdout": "", "stderr": str(exc), "return_code": -1, "dry_run": False}


# #############################################################################
#  ORDER QUEUE WORKER
# #############################################################################

def queue_worker():
    """Background thread: pull orders from the FIFO queue and execute them.

    Orders are processed strictly in FIFO order, one at a time.
    When a synchronous order is processed, its sync_done event is set
    so the waiting HTTP handler can return the result.
    """
    global current_order

    if logger:
        logger.info("Queue worker started")

    while not shutdown_event.is_set():
        try:
            order = execution_queue.get(timeout=1)
        except queue.Empty:
            continue

        oid = order["order_id"]
        if logger:
            logger.info("Processing order %s: %s %s", oid,
                        order["command"], " ".join(order["arguments"]))

        with current_order_lock:
            current_order = order
            order["status"] = "running"
            order["started_at"] = _utcnow_iso()

        try:
            result = execute_command(
                order["resolved_command"],
                order["arguments"],
                order["run_as_user"],
                dry_run=order.get("dry_run", False),
                timeout=order.get("timeout"),
            )
            order["result"] = result
            order["status"] = "completed"
        except Exception as exc:
            if logger:
                logger.error("Order %s failed: %s", oid, exc, exc_info=True)
            order["result"] = {
                "stdout": "",
                "stderr": "Internal error: %s" % exc,
                "return_code": -1,
                "dry_run": order.get("dry_run", False),
            }
            order["status"] = "failed"
        finally:
            order["completed_at"] = _utcnow_iso()
            with current_order_lock:
                current_order = None
            with pending_lock:
                pending_orders.pop(oid, None)
            if order.get("synchronous") and "sync_done" in order:
                order["sync_done"].set()
            execution_queue.task_done()
            if logger:
                logger.info("Order %s finished, return_code=%s",
                            oid, order.get("result", {}).get("return_code"))

    if logger:
        logger.info("Queue worker stopped")


# #############################################################################
#  FLASK -- PRE-REQUEST MIDDLEWARE
# #############################################################################

@app.before_request
def _before_request():
    """Runs before every request: config integrity, IP ACL, authentication.

    - /api/v1/health is public but IP ACL still applies.
    - All other endpoints require a valid Bearer token.
    - Config integrity is checked on every authenticated request.
    """

    # Health endpoint is public (but IP ACL still applies).
    if request.path == "/api/v1/health":
        return None

    # Config integrity check
    if not verify_config_integrity():
        if logger:
            logger.critical("Configuration file modified on disk! Rejecting request.")
        return jsonify({
            "status": "error",
            "message": "Configuration integrity check failed. Restart the service.",
        }), 503

    # IP ACL
    client_ip = request.remote_addr
    if not check_ip_acl(client_ip):
        if logger:
            logger.warning("IP %s denied on %s %s", client_ip, request.method, request.path)
        return jsonify({"status": "error", "message": "Access denied"}), 403

    # Token authentication
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        if logger:
            logger.warning("Missing/invalid Authorization header from %s", client_ip)
        return jsonify({
            "status": "error",
            "message": "Authentication required. Use 'Authorization: Bearer <token>'.",
        }), 401

    token_name, token_cfg = authenticate(auth[7:])
    if token_name is None:
        if logger:
            logger.warning("Invalid token from %s", client_ip)
        return jsonify({"status": "error", "message": "Invalid authentication token"}), 401

    # Store authenticated context for downstream handlers
    g.token_name = token_name
    g.token_cfg = token_cfg
    g.client_ip = client_ip
    if logger:
        logger.debug("Authenticated token '%s' from %s", token_name, client_ip)
    return None


# #############################################################################
#  API ENDPOINTS
# #############################################################################

@app.route("/api/v1/health", methods=["GET"])
def ep_health():
    """Health check -- no authentication required.  IP ACL still applies."""
    client_ip = request.remote_addr
    if not check_ip_acl(client_ip):
        return jsonify({"status": "error", "message": "Access denied"}), 403
    return jsonify({
        "status": "ok",
        "service": APP_NAME,
        "version": APP_VERSION,
        "timestamp": _utcnow_iso(),
    }), 200


@app.route("/api/v1/execute", methods=["POST"])
def ep_execute():
    """Execute a shell command (synchronous or asynchronous).

    POST JSON body:
      command      (str)       -- required, the command name
      arguments    (list[str]) -- optional, default []
      synchronous  (bool)      -- optional, default false
      timeout      (int|null)  -- optional, seconds before kill

    Validation pipeline:
      1. Parse and validate JSON body
      2. Check forbidden characters in arguments
      3. Check command authorization (deny-first, then allow)
      4. Resolve command path
      5. Validate target user
      6. Queue for execution

    Returns:
      - HTTP 200 with result for synchronous requests
      - HTTP 202 with order_id for asynchronous requests
    """
    try:
        data = request.get_json(force=True)
    except Exception:
        return jsonify({"status": "error", "message": "Invalid JSON body"}), 400

    if not data or "command" not in data:
        return jsonify({"status": "error", "message": "Missing 'command' field"}), 400

    command_name = str(data["command"]).strip()
    arguments = data.get("arguments", [])
    synchronous = bool(data.get("synchronous", False))
    timeout = data.get("timeout", None)

    if not isinstance(arguments, list):
        return jsonify({"status": "error", "message": "'arguments' must be a list"}), 400

    arguments = [str(a) for a in arguments]

    # Check forbidden characters in all arguments
    for arg in arguments:
        ok, bad = check_forbidden_chars(arg)
        if not ok:
            if logger:
                logger.warning("Forbidden char '%s' in argument, token '%s', cmd '%s'",
                               bad, g.token_name, command_name)
            return jsonify({
                "status": "error",
                "message": "Forbidden character in argument: '%s'" % bad,
            }), 400

    # Build the full command string for authorization matching
    full_cmd = command_name + (" " + " ".join(arguments) if arguments else "")

    # Command authorization (deny-first, then allow)
    allowed, reason = check_command_authorization(full_cmd, g.token_cfg)
    if not allowed:
        if logger:
            logger.warning("Command denied for '%s': %s (cmd: %s)",
                           g.token_name, reason, full_cmd)
        return jsonify({
            "status": "error",
            "message": "Command not authorized: %s" % reason,
        }), 403

    # Resolve the command to its full path
    resolved = resolve_command(command_name)
    if resolved is None:
        if logger:
            logger.warning("Command '%s' not found in PATH", command_name)
        return jsonify({
            "status": "error",
            "message": "Command '%s' not found" % command_name,
        }), 404

    # Validate the target Unix user
    run_as = g.token_cfg.get("user", config.get("run_as", DEFAULT_RUN_AS))
    valid, ureason = validate_user(run_as)
    if not valid:
        if logger:
            logger.warning("User validation failed for '%s': %s", run_as, ureason)
        return jsonify({"status": "error", "message": ureason}), 403

    # Build the order and queue it
    oid = str(uuid.uuid4())
    order = {
        "order_id": oid,
        "command": command_name,
        "resolved_command": resolved,
        "arguments": arguments,
        "run_as_user": run_as,
        "dry_run": config.get("dry_run", False),
        "synchronous": synchronous,
        "timeout": timeout,
        "status": "queued",
        "queued_at": _utcnow_iso(),
        "started_at": None,
        "completed_at": None,
        "result": None,
        "token_name": g.token_name,
        "client_ip": g.client_ip,
    }
    if synchronous:
        order["sync_done"] = threading.Event()

    if logger:
        logger.info("Order %s queued: %s %s (sync=%s user=%s token=%s ip=%s)",
                     oid, command_name, " ".join(arguments),
                     synchronous, run_as, g.token_name, g.client_ip)

    with pending_lock:
        pending_orders[oid] = order
    execution_queue.put(order)

    if synchronous:
        # Block until the queue worker finishes this order
        order["sync_done"].wait()
        r = order.get("result", {})
        return jsonify({
            "status": "ok",
            "order_id": oid,
            "result": {
                "stdout": r.get("stdout", ""),
                "stderr": r.get("stderr", ""),
                "return_code": r.get("return_code", -1),
                "dry_run": r.get("dry_run", False),
            },
        }), 200
    else:
        return jsonify({
            "status": "ok",
            "order_id": oid,
            "message": "Command queued for execution",
        }), 202


@app.route("/api/v1/queue", methods=["GET"])
def ep_queue():
    """List all pending and running orders.

    Returns the current queue contents including the currently running
    order (if any) and all pending orders with their metadata.
    """
    orders = []
    with pending_lock:
        for oid, o in pending_orders.items():
            orders.append({
                "order_id": oid,
                "command": o["command"],
                "arguments": o["arguments"],
                "status": o["status"],
                "queued_at": o["queued_at"],
                "started_at": o["started_at"],
                "token_name": o["token_name"],
                "client_ip": o["client_ip"],
                "synchronous": o.get("synchronous", False),
            })

    # Include the current order if it has already left pending_orders
    with current_order_lock:
        if current_order is not None:
            co = current_order
            if not any(x["order_id"] == co["order_id"] for x in orders):
                orders.insert(0, {
                    "order_id": co["order_id"],
                    "command": co["command"],
                    "arguments": co["arguments"],
                    "status": co["status"],
                    "queued_at": co["queued_at"],
                    "started_at": co["started_at"],
                    "token_name": co["token_name"],
                    "client_ip": co["client_ip"],
                    "synchronous": co.get("synchronous", False),
                })

    return jsonify({"status": "ok", "queue_size": len(orders), "orders": orders}), 200


@app.route("/api/v1/kill", methods=["POST"])
def ep_kill():
    """Send a signal to the currently running command.

    POST JSON body:
      signal (str) -- optional, default SIGTERM

    Supported signals: SIGHUP, SIGTERM, SIGKILL, SIGINT, SIGUSR1, SIGUSR2.
    The signal is sent to the entire process group to ensure child
    processes are also affected.
    """
    try:
        data = request.get_json(force=True) or {}
    except Exception:
        data = {}

    sig_name = str(data.get("signal", "SIGTERM")).upper()
    sig_map = {
        "SIGHUP": signal.SIGHUP,
        "SIGTERM": signal.SIGTERM,
        "SIGKILL": signal.SIGKILL,
        "SIGINT": signal.SIGINT,
        "SIGUSR1": signal.SIGUSR1,
        "SIGUSR2": signal.SIGUSR2,
    }

    if sig_name not in sig_map:
        return jsonify({
            "status": "error",
            "message": "Unsupported signal: %s. Supported: %s" % (
                sig_name, ", ".join(sorted(sig_map))),
        }), 400

    with current_process_lock:
        proc = current_process

    if proc is None:
        return jsonify({"status": "ok", "message": "No command is currently running"}), 200

    try:
        os.killpg(os.getpgid(proc.pid), sig_map[sig_name])
        if logger:
            logger.warning("Sent %s to PID %d (token '%s', ip %s)",
                           sig_name, proc.pid, g.token_name, g.client_ip)
        return jsonify({
            "status": "ok",
            "message": "Signal %s sent to PID %d" % (sig_name, proc.pid),
        }), 200
    except ProcessLookupError:
        return jsonify({"status": "ok", "message": "Process already terminated"}), 200
    except Exception as exc:
        if logger:
            logger.error("Failed to send signal: %s", exc)
        return jsonify({"status": "error", "message": "Failed to send signal: %s" % exc}), 500


@app.route("/api/v1/reload", methods=["POST"])
def ep_reload():
    """Reload the configuration from disk.

    Re-reads the YAML config file, updates the config hash (for integrity
    checking), and reconfigures the logger.  The queue worker is not
    restarted.
    """
    global config, config_hash, logger

    if logger:
        logger.info("Reload requested by token '%s' from %s", g.token_name, g.client_ip)
    try:
        new = load_config(config_file_path)
        config = new
        logger = setup_logging(config, debug=(logger.level == logging.DEBUG))
        if logger:
            logger.info("Configuration reloaded successfully")
        return jsonify({"status": "ok", "message": "Configuration reloaded successfully"}), 200
    except Exception as exc:
        if logger:
            logger.error("Reload failed: %s", exc)
        return jsonify({"status": "error", "message": "Reload failed: %s" % exc}), 500


@app.route("/api/v1/status", methods=["GET"])
def ep_status():
    """Return service status information.

    Includes: service name, version, dry-run state, queue depth,
    and the currently running order (if any).
    """
    cur = None
    with current_order_lock:
        if current_order is not None:
            cur = {
                "order_id": current_order["order_id"],
                "command": current_order["command"],
                "arguments": current_order["arguments"],
                "started_at": current_order["started_at"],
            }
    return jsonify({
        "status": "ok",
        "service": APP_NAME,
        "version": APP_VERSION,
        "dry_run": config.get("dry_run", False),
        "queue_depth": execution_queue.qsize(),
        "current_order": cur,
        "timestamp": _utcnow_iso(),
    }), 200


# #############################################################################
#  FLASK ERROR HANDLERS
# #############################################################################

@app.errorhandler(404)
def _err_404(_e):
    """Handle 404 Not Found errors."""
    return jsonify({"status": "error", "message": "Endpoint not found"}), 404

@app.errorhandler(405)
def _err_405(_e):
    """Handle 405 Method Not Allowed errors."""
    return jsonify({"status": "error", "message": "Method not allowed"}), 405

@app.errorhandler(500)
def _err_500(_e):
    """Handle 500 Internal Server Error."""
    if logger:
        logger.error("Internal server error: %s", _e, exc_info=True)
    return jsonify({"status": "error", "message": "Internal server error"}), 500


# #############################################################################
#  SIGNAL HANDLERS
# #############################################################################

def _on_sighup(_signum, _frame):
    """Handle SIGHUP: reload configuration from disk."""
    global config, config_hash
    if logger:
        logger.info("Received SIGHUP -- reloading configuration")
    try:
        config = load_config(config_file_path)
        if logger:
            logger.info("Configuration reloaded via SIGHUP")
    except Exception as exc:
        if logger:
            logger.error("SIGHUP reload failed: %s", exc)

def _on_sigterm(_signum, _frame):
    """Handle SIGTERM: initiate graceful shutdown."""
    if logger:
        logger.info("Received SIGTERM -- shutting down")
    shutdown_event.set()


# #############################################################################
#  MAIN
# #############################################################################

def parse_arguments():
    """Parse command-line arguments and return the namespace."""
    p = argparse.ArgumentParser(
        description="Vigrid Shell API - Secure shell command execution service",
    )
    p.add_argument("-c", "--config", required=True,
                   help="Path to configuration file")
    p.add_argument("-f", "--foreground", action="store_true",
                   help="Run in foreground mode")
    p.add_argument("-d", "--debug", action="store_true",
                   help="Enable debug mode (implies --foreground)")
    p.add_argument("--dry-run", action="store_true",
                   help="Force dry-run mode (override config)")
    p.add_argument("--bind", default=None,
                   help="Override bind address")
    p.add_argument("--port", type=int, default=None,
                   help="Override listen port")
    p.add_argument("-v", "--version", action="version",
                   version="%s %s" % (APP_NAME, APP_VERSION))
    return p.parse_args()


def main():
    """Application entry point.

    1. Parse CLI arguments
    2. Load configuration
    3. Setup logging
    4. Start queue worker thread
    5. Configure SSL if enabled
    6. Start Flask HTTP(S) server
    """
    global config, logger, worker_thread

    args = parse_arguments()
    if args.debug:
        args.foreground = True

    # Load configuration
    config = load_config(args.config)

    # CLI overrides
    if args.dry_run:
        config["dry_run"] = True
    if args.bind:
        config["bind"] = args.bind
    if args.port:
        config["port"] = args.port

    # Setup logging
    logger = setup_logging(config, debug=args.debug)

    logger.info("=" * 60)
    logger.info("%s v%s starting", APP_NAME, APP_VERSION)
    logger.info("Config : %s", config_file_path)
    logger.info("Bind   : %s:%d", config["bind"], config["port"])
    logger.info("Dry-run: %s", config.get("dry_run", False))
    logger.info("Run-as : %s", config.get("run_as", DEFAULT_RUN_AS))
    logger.info("Log    : %s / %s", config.get("log_level"), config.get("log_format"))
    logger.info("=" * 60)

    # Signal handlers
    signal.signal(signal.SIGHUP, _on_sighup)
    signal.signal(signal.SIGTERM, _on_sigterm)

    # Start the FIFO queue worker thread
    worker_thread = threading.Thread(target=queue_worker, daemon=True, name="queue-worker")
    worker_thread.start()
    logger.info("Queue worker thread started")

    # SSL context
    ssl_ctx = None
    ssl_cfg = config.get("ssl", {})
    if ssl_cfg.get("enabled", False):
        cert = ssl_cfg.get("certificate")
        key = ssl_cfg.get("private_key")
        if cert and key and os.path.isfile(cert) and os.path.isfile(key):
            ssl_ctx = (cert, key)
            logger.info("HTTPS enabled: cert=%s key=%s", cert, key)
        else:
            logger.warning("SSL enabled but cert/key missing or not found -- falling back to HTTP")

    # Run Flask
    try:
        proto = "HTTPS" if ssl_ctx else "HTTP"
        logger.info("Starting %s server on %s:%d", proto, config["bind"], config["port"])
        app.run(
            host=config["bind"],
            port=config["port"],
            ssl_context=ssl_ctx,
            debug=False,
            use_reloader=False,
            threaded=True,
        )
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
    except Exception as exc:
        logger.critical("Fatal: %s", exc, exc_info=True)
        sys.exit(1)
    finally:
        shutdown_event.set()
        logger.info("%s stopped", APP_NAME)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("FATAL: %s" % exc, file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

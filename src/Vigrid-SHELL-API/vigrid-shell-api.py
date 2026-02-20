#!/usr/bin/env python3
"""
Vigrid Shell API - Execute shell commands remotely
"""

import os
import sys
import re
import json
import time
import signal
import socket
import hashlib
import hmac
import threading
import queue
import logging
import logging.handlers
import traceback
import subprocess
import ssl
from datetime import datetime
from fnmatch import fnmatch
from functools import wraps
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
import configparser
from urllib.parse import urlparse, parse_qs
import ipaddress

VERSION = "1.0.0"

class Config:
    def __init__(self, config_file):
        self.config_file = config_file
        self.listen_ip = "0.0.0.0"
        self.listen_port = 5000
        self.use_https = False
        self.cert_file = ""
        self.key_file = ""
        self.run_as_user = "root"
        self.dry_run = False
        self.command_paths = ["/bin", "/usr/bin", "/usr/local/bin", "/sbin", "/usr/sbin"]
        self.allowed_commands_read = []
        self.allowed_commands_write = []
        self.forbidden_commands_read = []
        self.forbidden_commands_write = []
        self.allowed_ips = []
        self.blacklist_ips = []
        self.deny_by_default = True
        self.log_file = "/var/log/vigrid-shell-api.log"
        self.log_format = "json"
        self.log_level = "info"
        self.tokens = {}
        self.config_hash = ""
        self.reload_flag = False
        self.original_config_mtime = 0
        
    def load(self):
        if not os.path.exists(self.config_file):
            raise FileNotFoundError(f"Configuration file not found: {self.config_file}")
        
        self.original_config_mtime = os.path.getmtime(self.config_file)
        
        parser = configparser.ConfigParser()
        parser.read(self.config_file)
        
        if not parser.has_section("server"):
            raise ValueError("Missing [server] section in config")
        
        self.listen_ip = parser.get("server", "listen_ip", fallback="0.0.0.0")
        self.listen_port = parser.getint("server", "listen_port", fallback=5000)
        self.use_https = parser.getboolean("server", "use_https", fallback=False)
        self.cert_file = parser.get("server", "cert_file", fallback="")
        self.key_file = parser.get("server", "key_file", fallback="")
        self.run_as_user = parser.get("server", "run_as_user", fallback="root")
        self.dry_run = parser.getboolean("server", "dry_run", fallback=False)
        
        if parser.has_section("paths"):
            paths = parser.get("paths", "command_paths", fallback="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin")
            self.command_paths = paths.split(":")
        
        if parser.has_section("commands"):
            self._load_command_list(parser, "commands", "allowed_read", self, "allowed_commands_read")
            self._load_command_list(parser, "commands", "allowed_write", self, "allowed_commands_write")
            self._load_command_list(parser, "commands", "forbidden_read", self, "forbidden_commands_read")
            self._load_command_list(parser, "commands", "forbidden_write", self, "forbidden_commands_write")
        
        if parser.has_section("network"):
            self._load_ip_list(parser, "network", "allowed_ips", self.allowed_ips)
            self._load_ip_list(parser, "network", "blacklist_ips", self.blacklist_ips)
            self.deny_by_default = parser.getboolean("network", "deny_by_default", fallback=True)
        
        if parser.has_section("logging"):
            self.log_file = parser.get("logging", "log_file", fallback="/var/log/vigrid-shell-api.log")
            self.log_format = parser.get("logging", "log_format", fallback="json")
            self.log_level = parser.get("logging", "log_level", fallback="info")
        
        if parser.has_section("tokens"):
            for key, value in parser.items("tokens"):
                parts = value.split(":")
                if len(parts) >= 2:
                    self.tokens[key] = {
                        "login": parts[0],
                        "level": parts[1]
                    }
        
        self._compute_config_hash()
    
    def _load_command_list(self, parser, section, key, obj, attr_name):
        value = parser.get(section, key, fallback="")
        if value:
            attr_list = getattr(obj, attr_name)
            for line in value.split("\n"):
                line = line.strip()
                if line and not line.startswith("#"):
                    attr_list.append(line)
    
    def _load_ip_list(self, parser, section, key, dest):
        value = parser.get(section, key, fallback="")
        if value:
            for line in value.split("\n"):
                line = line.strip()
                if line and not line.startswith("#"):
                    dest.append(line)
    
    def _compute_config_hash(self):
        with open(self.config_file, "rb") as f:
            self.config_hash = hashlib.sha256(f.read()).hexdigest()
    
    def check_config_modified(self):
        try:
            current_mtime = os.path.getmtime(self.config_file)
            if current_mtime != self.original_config_mtime:
                return True
        except:
            pass
        return False
    
    def reload(self):
        self.load()


class Logger:
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger("vigrid-shell-api")
        self.logger.setLevel(getattr(logging, config.log_level.upper(), logging.INFO))
        
        if config.log_format == "json":
            handler = logging.handlers.RotatingFileHandler(
                config.log_file, maxBytes=10*1024*1024, backupCount=5
            )
            handler.setFormatter(JsonFormatter())
        else:
            handler = logging.handlers.RotatingFileHandler(
                config.log_file, maxBytes=10*1024*1024, backupCount=5
            )
            handler.setFormatter(logging.Formatter(
                '%(asctime)s %(levelname)s %(message)s'
            ))
        
        self.logger.addHandler(handler)
    
    def log(self, level, action, details):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": level,
            "action": action,
            "details": details
        }
        
        if level == "debug":
            self.logger.debug(json.dumps(log_entry))
        elif level == "info":
            self.logger.info(json.dumps(log_entry))
        elif level == "warning":
            self.logger.warning(json.dumps(log_entry))
        elif level == "error":
            self.logger.error(json.dumps(log_entry))


class JsonFormatter(logging.Formatter):
    def format(self, record):
        return record.getMessage()


class CommandQueue:
    def __init__(self):
        self.queue = queue.Queue()
        self.current = None
        self.lock = threading.Lock()
        self.counter = 0
    
    def add(self, command, args, token_info, async_mode=False):
        with self.lock:
            self.counter += 1
            job_id = self.counter
            job = {
                "id": job_id,
                "command": command,
                "args": args,
                "token_info": token_info,
                "async_mode": async_mode,
                "status": "pending",
                "requested_at": datetime.utcnow().isoformat(),
                "started_at": None,
                "completed_at": None,
                "result": None,
                "process": None
            }
            self.queue.put(job)
            return job_id
    
    def get_next(self):
        try:
            job = self.queue.get_nowait()
            with self.lock:
                self.current = job
                job["status"] = "running"
                job["started_at"] = datetime.utcnow().isoformat()
            return job
        except queue.Empty:
            return None
    
    def complete(self, job_id, result):
        with self.lock:
            if self.current and self.current["id"] == job_id:
                self.current["status"] = "completed"
                self.current["completed_at"] = datetime.utcnow().isoformat()
                self.current["result"] = result
                self.current = None
    
    def kill_current(self, signal_type):
        with self.lock:
            if self.current and self.current["process"]:
                try:
                    os.kill(self.current["process"].pid, signal_type)
                    return True
                except:
                    return False
        return False
    
    def list_pending(self):
        result = []
        with self.lock:
            if self.current:
                result.append(self.current.copy())
        temp_list = []
        while not self.queue.empty():
            try:
                job = self.queue.get_nowait()
                temp_list.append(job)
                result.append(job.copy())
            except queue.Empty:
                break
        for job in temp_list:
            self.queue.put(job)
        return result


class ForbiddenChars:
    FORBIDDEN = "':;\\|&(){$}<>`"
    
    @staticmethod
    def contains(text):
        for char in ForbiddenChars.FORBIDDEN:
            if char in text:
                return True
        return False


class IPChecker:
    def __init__(self, config):
        self.config = config
    
    def is_allowed(self, ip_str):
        try:
            client_ip = ipaddress.ip_address(ip_str)
            
            for pattern in self.config.blacklist_ips:
                if self._match_ip(client_ip, pattern):
                    if self.config.deny_by_default:
                        for allow_pattern in self.config.allowed_ips:
                            if self._match_ip(client_ip, allow_pattern):
                                return True
                        return False
                    return False
            
            if self.config.allowed_ips:
                for pattern in self.config.allowed_ips:
                    if self._match_ip(client_ip, pattern):
                        return True
                return self.config.deny_by_default
            
            return not self.config.deny_by_default
        
        except:
            return False
    
    def _match_ip(self, client_ip, pattern):
        try:
            if "/" in pattern:
                network = ipaddress.ip_network(pattern, strict=False)
                return client_ip in network
            else:
                return client_ip == ipaddress.ip_address(pattern)
        except:
            return False


class CommandChecker:
    def __init__(self, config):
        self.config = config
    
    def is_allowed(self, command, level):
        if level == "read":
            allowed = self.config.allowed_commands_read
            forbidden = self.config.forbidden_commands_read
        else:
            allowed = self.config.allowed_commands_write
            forbidden = self.config.forbidden_commands_write
        
        for pattern in forbidden:
            if self._match_command(command, pattern):
                return False
        
        if not allowed:
            return False
        
        for pattern in allowed:
            if self._match_command(command, pattern):
                return True
        
        return False
    
    def _match_command(self, command, pattern):
        try:
            if re.match(pattern, command):
                return True
        except:
            pass
        return fnmatch(command, pattern)


class ShellExecutor:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
    
    def execute(self, command, args, async_mode=False, callback=None):
        if ForbiddenChars.contains(command):
            return {
                "success": False,
                "error": "Command contains forbidden characters",
                "stdout": "",
                "stderr": "",
                "exit_code": 1
            }
        
        if self.config.dry_run:
            self.logger.log("info", "dry_run_execute", {
                "command": command,
                "args": args
            })
            return {
                "success": True,
                "stdout": f"[DRY-RUN] Would execute: {command} {' '.join(args)}",
                "stderr": "",
                "exit_code": 0
            }
        
        full_command = [command] + args
        
        for i, part in enumerate(full_command):
            if ForbiddenChars.contains(part):
                return {
                    "success": False,
                    "error": f"Argument {i} contains forbidden characters",
                    "stdout": "",
                    "stderr": "",
                    "exit_code": 1
                }
        
        try:
            if async_mode:
                proc = subprocess.Popen(
                    full_command,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    cwd="/"
                )
                return {
                    "success": True,
                    "async": True,
                    "pid": proc.pid,
                    "stdout": "",
                    "stderr": "",
                    "exit_code": 0
                }
            else:
                result = subprocess.run(
                    full_command,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    cwd="/",
                    timeout=300
                )
                return {
                    "success": result.returncode == 0,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "exit_code": result.returncode
                }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "error": "Command timed out",
                "stdout": "",
                "stderr": "",
                "exit_code": 124
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "stdout": "",
                "stderr": "",
                "exit_code": 1
            }


class APIHandler(BaseHTTPRequestHandler):
    config = None
    logger = None
    cmd_queue = None
    ip_checker = None
    cmd_checker = None
    executor = None
    
    def log_message(self, format, *args):
        pass
    
    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))
    
    def _get_client_ip(self):
        return self.client_address[0]
    
    def _check_auth(self):
        auth_header = self.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return None
        
        token = auth_header[7:]
        
        if token not in self.config.tokens:
            return None
        
        return self.config.tokens[token]
    
    def _check_ip(self):
        client_ip = self._get_client_ip()
        return self.ip_checker.is_allowed(client_ip)
    
    def do_POST(self):
        if not self._check_ip():
            self.logger.log("warning", "ip_blocked", {"ip": self._get_client_ip()})
            self._send_json(403, {"error": "IP not allowed"})
            return
        
        token_info = self._check_auth()
        if not token_info:
            self.logger.log("warning", "auth_failed", {"ip": self._get_client_ip()})
            self._send_json(401, {"error": "Authentication required"})
            return
        
        if self.config.check_config_modified():
            self.logger.log("error", "config_modified", {"ip": self._get_client_ip()})
            self._send_json(403, {"error": "Configuration file modified - service restart required"})
            return
        
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            self._send_json(400, {"error": "No content"})
            return
        
        try:
            body = self.rfile.read(content_length)
            data = json.loads(body.decode("utf-8"))
        except:
            self._send_json(400, {"error": "Invalid JSON"})
            return
        
        path = self.path
        
        if path == "/api/v1/execute":
            self._handle_execute(data, token_info)
        elif path == "/api/v1/queue":
            self._handle_queue(data, token_info)
        elif path == "/api/v1/kill":
            self._handle_kill(data, token_info)
        else:
            self._send_json(404, {"error": "Not found"})
    
    def do_GET(self):
        if not self._check_ip():
            self.logger.log("warning", "ip_blocked", {"ip": self._get_client_ip()})
            self._send_json(403, {"error": "IP not allowed"})
            return
        
        token_info = self._check_auth()
        if not token_info:
            self.logger.log("warning", "auth_failed", {"ip": self._get_client_ip()})
            self._send_json(401, {"error": "Authentication required"})
            return
        
        path = self.path
        
        if path == "/api/v1/queue":
            self._handle_queue_list(token_info)
        elif path == "/api/v1/status":
            self._handle_status(token_info)
        else:
            self._send_json(404, {"error": "Not found"})
    
    def _handle_execute(self, data, token_info):
        command = data.get("command", "")
        args = data.get("args", [])
        async_mode = data.get("async", False)
        
        if not command:
            self._send_json(400, {"error": "Command required"})
            return
        
        token_level = token_info["level"]
        
        if token_level == "write":
            if self.cmd_checker.is_allowed(command, "write"):
                level = "write"
            elif self.cmd_checker.is_allowed(command, "read"):
                level = "read"
            else:
                self.logger.log("warning", "command_denied", {
                    "command": command,
                    "level": "write/read",
                    "login": token_info["login"]
                })
                self._send_json(403, {"error": "Command not allowed"})
                return
        else:
            if not self.cmd_checker.is_allowed(command, "read"):
                self.logger.log("warning", "command_denied", {
                    "command": command,
                    "level": "read",
                    "login": token_info["login"]
                })
                self._send_json(403, {"error": "Command not allowed"})
                return
            level = "read"
        
        if async_mode:
            job_id = self.cmd_queue.add(command, args, token_info, True)
            
            self.logger.log("info", "command_queued", {
                "job_id": job_id,
                "command": command,
                "args": args,
                "login": token_info["login"],
                "ip": self._get_client_ip()
            })
            
            self._send_json(202, {"job_id": job_id, "status": "queued"})
        else:
            job_id = self.cmd_queue.add(command, args, token_info, False)
            
            self.logger.log("info", "command_queued", {
                "job_id": job_id,
                "command": command,
                "args": args,
                "login": token_info["login"],
                "ip": self._get_client_ip()
            })
            
            job = self.cmd_queue.get_next()
            if job:
                result = self.executor.execute(
                    job["command"],
                    job["args"],
                    False
                )
                
                self.cmd_queue.complete(job["id"], result)
                
                self.logger.log("info", "command_executed", {
                    "job_id": job["id"],
                    "exit_code": result.get("exit_code")
                })
                
                self._send_json(200, {
                    "job_id": job["id"],
                    "status": "completed",
                    "result": result
                })
            else:
                self._send_json(202, {"job_id": job_id, "status": "queued"})
    
    def _handle_queue(self, data, token_info):
        action = data.get("action", "")
        
        if action == "process":
            job = self.cmd_queue.get_next()
            if not job:
                self._send_json(200, {"status": "idle"})
                return
            
            result = self.executor.execute(
                job["command"],
                job["args"],
                job["async_mode"]
            )
            
            self.cmd_queue.complete(job["id"], result)
            
            self.logger.log("info", "command_completed", {
                "job_id": job["id"],
                "exit_code": result.get("exit_code")
            })
            
            self._send_json(200, {
                "job_id": job["id"],
                "status": "completed",
                "result": result
            })
        else:
            self._send_json(400, {"error": "Invalid action"})
    
    def _handle_queue_list(self, token_info):
        jobs = self.cmd_queue.list_pending()
        self._send_json(200, {"jobs": jobs})
    
    def _handle_kill(self, data, token_info):
        signal_type = data.get("signal", "SIGTERM")
        
        sig = getattr(signal, f"SIG{signal_type}", signal.SIGTERM)
        
        if self.cmd_queue.kill_current(sig):
            self.logger.log("info", "process_killed", {
                "signal": signal_type,
                "login": token_info["login"]
            })
            self._send_json(200, {"status": "killed"})
        else:
            self._send_json(404, {"error": "No running process"})
    
    def _handle_status(self, token_info):
        self._send_json(200, {
            "version": VERSION,
            "status": "running",
            "dry_run": self.config.dry_run
        })


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = False


def create_ssl_context(config):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(config.cert_file, config.key_file)
    return context


def run_server(config, debug=False):
    try:
        config.reload()
    except Exception as e:
        print(f"Failed to load config: {e}", file=sys.stderr)
        return 1
    
    logger = Logger(config)
    logger.log("info", "service_start", {
        "version": VERSION,
        "listen": f"{config.listen_ip}:{config.listen_port}",
        "https": config.use_https,
        "dry_run": config.dry_run
    })
    
    cmd_queue = CommandQueue()
    ip_checker = IPChecker(config)
    cmd_checker = CommandChecker(config)
    executor = ShellExecutor(config, logger)
    
    APIHandler.config = config
    APIHandler.logger = logger
    APIHandler.cmd_queue = cmd_queue
    APIHandler.ip_checker = ip_checker
    APIHandler.cmd_checker = cmd_checker
    APIHandler.executor = executor
    
    server = ThreadedHTTPServer((config.listen_ip, config.listen_port), APIHandler)
    
    if config.use_https and config.cert_file and config.key_file:
        server.socket = create_ssl_context(config).wrap_socket(server.socket, server_side=True)
        logger.log("info", "https_enabled", {})
    
    logger.log("info", "server_ready", {})
    
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    
    def signal_handler(signum, frame):
        logger.log("info", "service_stop", {"signal": signum})
        server.shutdown()
    
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    if config.reload_flag:
        logger.log("info", "reload_requested", {})
        config.reload_flag = False
    
    server_thread.join()
    
    return 0


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Vigrid Shell API")
    parser.add_argument("-c", "--config", default="/home/gns3/etc/vigrid-shell-api.conf",
                        help="Configuration file path")
    parser.add_argument("-d", "--debug", action="store_true",
                        help="Run in foreground with debug logging")
    parser.add_argument("--reload", action="store_true",
                        help="Reload configuration")
    
    args = parser.parse_args()
    
    if args.reload:
        print("Reload signal sent")
        return 0
    
    try:
        config = Config(args.config)
        config.load()
    except FileNotFoundError:
        print(f"Configuration file not found: {args.config}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Configuration error: {e}", file=sys.stderr)
        return 1
    
    if args.debug:
        config.log_level = "debug"
    
    return run_server(config, debug=args.debug)


if __name__ == "__main__":
    sys.exit(main())

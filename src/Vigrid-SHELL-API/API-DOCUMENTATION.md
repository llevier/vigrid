# Vigrid Shell API - Documentation

## Overview

The Vigrid Shell API is a secure REST API for executing shell commands on a
Linux system.  It is designed for Vigrid NAS management but works on any
Linux distribution (Ubuntu / Debian recommended).

### Key features

- Token-based authentication (Bearer tokens)
- IP-based access control (CIDR deny/allow lists, deny-first, default-deny)
- Per-token command authorization via regex (deny-first, default-deny)
- Per-token Unix user identity switching (sudo)
- Forbidden character checking in command arguments
- Synchronous and asynchronous execution with FIFO queue
- Dry-run mode (commands logged but never executed)
- Configuration integrity monitoring (blocks tampering at runtime)
- HTTP or HTTPS operation (with configurable certificates)
- Structured logging: syslog or JSON format, configurable verbosity
- Foreground / debug mode for step-by-step troubleshooting
- systemd service integration with automatic restart on crash
- Queue management: list pending orders, kill running commands

## Installation

### Prerequisites

- Linux (Ubuntu / Debian recommended)
- Python 3.8+
- `python3-venv` package
- systemd (for service management)
- Root privileges

### Install

```bash
sudo ./install.sh <install_dir> <config_dir>
```

Example:

```bash
sudo ./install.sh /opt/vigrid-shell-api /etc/vigrid-shell-api
```

This will:

1. Copy application files to `<install_dir>/`
2. Copy documentation, test script, and uninstall script to `<install_dir>/`
3. Create a Python virtual environment at `<install_dir>/venv/`
4. Install Python dependencies (Flask, PyYAML)
5. Copy the default configuration to `<config_dir>/vigrid-shell-api.conf`
6. Install a systemd service (`vigrid-shell-api.service`)
7. Create the log file at `/var/log/vigrid-shell-api.log`

### Uninstall

```bash
sudo ./uninstall.sh <install_dir> <config_dir>
```

A copy of `uninstall.sh` is also placed in `<install_dir>/` during installation.
This removes everything created by `install.sh` (service, venv, config, logs).
The source directory is **never** modified.

## Configuration

File: `<config_dir>/vigrid-shell-api.conf` (YAML format).

### Network

```yaml
bind: "0.0.0.0"      # 0.0.0.0 = all interfaces
port: 8443
```

### SSL / TLS (HTTPS)

```yaml
ssl:
  enabled: true
  certificate: "/path/to/server.crt"
  private_key: "/path/to/server.key"
```

When `ssl.enabled` is `false` or the files are missing, the API falls back to
plain HTTP.

### Runtime

```yaml
run_as: "root"        # Default user for command execution
dry_run: false        # true = log commands but do not execute
```

### Command search path

```yaml
command_path: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
```

Colon-separated list of directories searched to resolve command names
(equivalent to the shell `$PATH`).

### Forbidden characters

```yaml
forbidden_chars:
  - '"'
  - "'"
  - ";"
  - "\\"
  - "|"
  - "&"
  - "("
  - ")"
  - "{"
  - "}"
  - "$"
  - "`"
```

Characters that are **not allowed** in command arguments.  Using a YAML list
avoids any escaping ambiguity.  A plain string value is also accepted and will
be split into individual characters.

### Logging

```yaml
log_dir: "/var/log"
log_format: "syslog"      # "syslog" or "json"
log_level: "INFO"         # DEBUG, INFO, WARNING, ERROR, CRITICAL
```

Log file: `<log_dir>/vigrid-shell-api.log` (rotating, 50 MB max, 5 backups).

### IP access control

```yaml
acl:
  deny:
    - "192.168.1.100/32"     # Deny this specific host
  allow:
    - "127.0.0.0/8"          # Allow localhost
    - "192.168.1.0/24"       # Allow this subnet
```

**Evaluation order:**

1. Check **deny** list -- first CIDR match --> REJECT
2. Check **allow** list -- first CIDR match --> ACCEPT
3. Default --> REJECT

This allows denying a specific IP while allowing its surrounding subnet.

### Authentication tokens

```yaml
tokens:
  admin:
    secret: "your-secret-token-here"
    user: "root"
    allow_commands:
      - ".*"
    deny_commands:
      - "^shutdown"
      - "^reboot"

  monitor:
    secret: "monitor-token-here"
    user: "nobody"
    allow_commands:
      - "^ls"
      - "^ps"
    deny_commands: []
```

Each token defines:

| Field | Description |
|-------|-------------|
| `secret` | The bearer token string |
| `user` | Unix user under which commands run (identity switching via sudo) |
| `allow_commands` | Regex patterns -- first match accepts |
| `deny_commands` | Regex patterns -- first match rejects |

**Command authorization order:**

1. Check `deny_commands` -- first regex match --> REJECT
2. Check `allow_commands` -- first regex match --> ACCEPT
3. Default --> REJECT

Regex patterns are matched against the **full** command string
(`<command> <arg1> <arg2> ...`).

If the Unix `user` associated with a token does not exist on the system or has
a disabled shell (`/usr/sbin/nologin`, `/bin/false`), the request is rejected.

**User identity switching:**

When a token specifies a `user` that differs from the user running the API
process (typically root), the command is executed via
`sudo -u <user> -- <command> <args...>`.  The system administrator must
configure `/etc/sudoers` accordingly (e.g., `NOPASSWD` entries).

## Running the API

### As a systemd service

```bash
sudo systemctl start   vigrid-shell-api
sudo systemctl stop    vigrid-shell-api
sudo systemctl restart vigrid-shell-api
sudo systemctl status  vigrid-shell-api
sudo systemctl enable  vigrid-shell-api    # start on boot
```

The service restarts automatically on crash (`Restart=always`, `RestartSec=3`).
The API **cannot** be stopped via any API call -- only `systemctl` works.

### Foreground / debug mode

```bash
# Foreground
<install_dir>/venv/bin/python3 <install_dir>/vigrid-shell-api.py \
    -c <config_dir>/vigrid-shell-api.conf --foreground

# Debug (verbose logging to stderr + log file, implies --foreground)
<install_dir>/venv/bin/python3 <install_dir>/vigrid-shell-api.py \
    -c <config_dir>/vigrid-shell-api.conf --debug

# Dry-run override from CLI
... --foreground --dry-run

# Override bind/port from CLI
... --foreground --bind 127.0.0.1 --port 9090
```

### Command-line options

| Option | Description |
|--------|-------------|
| `-c, --config` | Path to configuration file (**required**) |
| `-f, --foreground` | Run in foreground |
| `-d, --debug` | Debug mode (implies `--foreground`) |
| `--dry-run` | Force dry-run mode |
| `--bind` | Override bind address |
| `--port` | Override listen port |
| `-v, --version` | Show version |

## API endpoints

All endpoints except `/api/v1/health` require:

```
Authorization: Bearer <token>
```

All request bodies must be JSON.  All responses are JSON.

---

### GET /api/v1/health

Health check.  No authentication.  IP ACL still applies.

```json
{"status": "ok", "service": "vigrid-shell-api", "version": "1.0.0", "timestamp": "..."}
```

---

### POST /api/v1/execute

Execute a shell command.

**Request:**

```json
{
    "command": "ls",
    "arguments": ["-la", "/tmp"],
    "synchronous": true,
    "timeout": 30
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `command` | string | **yes** | -- | Command name |
| `arguments` | list | no | `[]` | Command arguments |
| `synchronous` | bool | no | `false` | Block until done |
| `timeout` | int | no | `null` | Seconds before kill |

**Response (synchronous, HTTP 200):**

```json
{
    "status": "ok",
    "order_id": "uuid",
    "result": {
        "stdout": "...",
        "stderr": "...",
        "return_code": 0,
        "dry_run": false
    }
}
```

**Response (asynchronous, HTTP 202):**

```json
{
    "status": "ok",
    "order_id": "uuid",
    "message": "Command queued for execution"
}
```

---

### GET /api/v1/queue

List pending and running orders.

```json
{
    "status": "ok",
    "queue_size": 1,
    "orders": [
        {
            "order_id": "...",
            "command": "sleep",
            "arguments": ["60"],
            "status": "running",
            "queued_at": "...",
            "started_at": "...",
            "token_name": "admin",
            "client_ip": "127.0.0.1",
            "synchronous": false
        }
    ]
}
```

---

### POST /api/v1/kill

Send a signal to the currently running command.

**Request:**

```json
{"signal": "SIGTERM"}
```

Supported signals: `SIGHUP`, `SIGTERM`, `SIGKILL`, `SIGINT`, `SIGUSR1`, `SIGUSR2`.

---

### POST /api/v1/reload

Reload the configuration from disk.  This updates the config hash used for
integrity checking.

```json
{"status": "ok", "message": "Configuration reloaded successfully"}
```

---

### GET /api/v1/status

Service status and queue information.

```json
{
    "status": "ok",
    "service": "vigrid-shell-api",
    "version": "1.0.0",
    "dry_run": false,
    "queue_depth": 0,
    "current_order": null,
    "timestamp": "..."
}
```

## HTTP status codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 202 | Accepted (async command queued) |
| 400 | Bad request (invalid JSON, missing fields, forbidden chars) |
| 401 | Authentication failed |
| 403 | Access denied (IP ACL, command not authorized, user invalid) |
| 404 | Command or endpoint not found |
| 405 | Method not allowed |
| 500 | Internal server error |
| 503 | Configuration integrity check failed |

## Usage examples

```bash
# Execute synchronously
curl -s -X POST http://127.0.0.1:8443/api/v1/execute \
    -H "Authorization: Bearer VigridAdmin-Secret-Token-Change-Me" \
    -H "Content-Type: application/json" \
    -d '{"command": "ls", "arguments": ["-la", "/tmp"], "synchronous": true}'

# Execute asynchronously
curl -s -X POST http://127.0.0.1:8443/api/v1/execute \
    -H "Authorization: Bearer VigridAdmin-Secret-Token-Change-Me" \
    -H "Content-Type: application/json" \
    -d '{"command": "ps", "arguments": ["aux"]}'

# Health check
curl -s http://127.0.0.1:8443/api/v1/health

# Service status
curl -s http://127.0.0.1:8443/api/v1/status \
    -H "Authorization: Bearer VigridAdmin-Secret-Token-Change-Me"

# Queue listing
curl -s http://127.0.0.1:8443/api/v1/queue \
    -H "Authorization: Bearer VigridAdmin-Secret-Token-Change-Me"

# Kill running command
curl -s -X POST http://127.0.0.1:8443/api/v1/kill \
    -H "Authorization: Bearer VigridAdmin-Secret-Token-Change-Me" \
    -H "Content-Type: application/json" \
    -d '{"signal": "SIGKILL"}'

# Reload configuration
curl -s -X POST http://127.0.0.1:8443/api/v1/reload \
    -H "Authorization: Bearer VigridAdmin-Secret-Token-Change-Me" \
    -H "Content-Type: application/json" \
    -d '{}'
```

## Security considerations

1. **Change default tokens** immediately after installation
2. **Restrict IP ACLs** to trusted networks only
3. **Use HTTPS** in production
4. **Least privilege**: create tokens with minimal command access
5. **Config protection**: the API detects disk modifications and rejects all
   requests until restarted (or reloaded via the reload endpoint)
6. The API **cannot be stopped via API calls** -- only `systemctl`
7. **Forbidden characters** in arguments prevent shell injection
8. Commands are resolved via a fixed `command_path`, not the system `$PATH`
9. **User switching** via sudo allows per-token isolation of privileges

## Testing

A comprehensive test script is included:

```bash
# Full mode: install, HTTP tests, HTTPS tests, dry-run tests, uninstall
sudo ./test-api.sh

# Test-only mode: against an already running service
sudo ./test-api.sh -t 127.0.0.1 8443 http
sudo ./test-api.sh -t 127.0.0.1 8443 https
```

The full-mode test:

- Installs the API into a temporary directory
- Generates a test configuration with dedicated tokens
- Creates a temporary Unix user (`_vigridtest`) for identity switching tests
- Runs 80+ tests covering all endpoints, authentication, authorization,
  forbidden characters, error handling, queue management, kill, timeout,
  deny-overrides-allow priority, user identity switching, and log verification
- Tests HTTP, HTTPS (with auto-generated self-signed certificate), and dry-run
- Verifies each operation against the log file
- Uninstalls and verifies cleanup

## Architecture

```
Client --> [IP ACL] --> [Auth] --> [Command Auth] --> [Char Check] --> [Queue]
                                                                         |
                                                                    [FIFO Worker]
                                                                         |
                                                                    [sudo -u user]
                                                                         |
                                                                    [subprocess]
```

- All commands execute in a single FIFO queue (strictly ordered, one at a time)
- Synchronous requests block until their command completes
- Asynchronous requests return immediately with an order UUID
- The queue worker runs in a dedicated background thread
- systemd restarts the service automatically on crash
- Each token can specify a different Unix user for execution

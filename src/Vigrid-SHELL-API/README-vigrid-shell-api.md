# Vigrid Shell API

Remote shell command execution API for Vigrid NAS management.

## Overview

Vigrid Shell API is a Python-based REST API that allows remote execution of shell commands on Linux systems. It is designed for managing Vigrid NAS installations with secure authentication, IP filtering, and command restrictions.

## Features

- Execute shell commands remotely via REST API
- Token-based authentication with read/write access levels
- IP whitelist/blacklist with CIDR support
- Command whitelist/blacklist with regex support
- HTTP and HTTPS support
- Dry-run mode for testing
- Synchronous and asynchronous command execution
- Queue management with kill capability
- Comprehensive logging (JSON or syslog format)
- Configuration change detection
- Systemd service integration

## Installation

### Prerequisites

- Python 3.8+
- Linux (Ubuntu/Debian)
- Root access for installation

### Quick Install

```bash
cd /home/llevier/Vigrid-SHELL-API
sudo ./install.sh
```

### Manual Steps

1. Install Python dependencies:
```bash
python3 -m venv venv
source venv/bin/activate
pip install flask configparser
```

2. Copy files to installation directory:
```bash
sudo mkdir -p %%VSTORAGE_GNS3%%/bin/Vigrid-SHELL-API
sudo cp vigrid-shell-api.py %%VSTORAGE_GNS3%%/bin/Vigrid-SHELL-API/
sudo cp vigrid-shell-api.conf %%VSTORAGE_GNS3%%/etc/
```

3. Install systemd service:
```bash
sudo cp vigrid-shell-api.service /etc/systemd/system/
sudo systemctl daemon-reload
```

4. Start the service:
```bash
sudo systemctl start vigrid-shell-api
sudo systemctl enable vigrid-shell-api
```

## Configuration

Configuration file: `/home/gns3/etc/vigrid-shell-api.conf`

### Server Section

```ini
[server]
listen_ip = 0.0.0.0        # IP to listen on (0.0.0.0 for all)
listen_port = 5000           # Port to listen on
use_https = false           # Enable HTTPS
cert_file =                 # Path to SSL certificate (for HTTPS)
key_file =                  # Path to SSL key (for HTTPS)
run_as_user = root          # User to run as (root or other)
dry_run = false            # Dry-run mode (no actual commands executed)
```

### Paths Section

Defines where to look for commands (like PATH in shell):

```ini
[paths]
command_paths = /bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin
```

### Commands Section

Commands are defined using **regex patterns**. Each pattern must match the entire command name using `^` (start) and `$` (end).

**Important:**
- A **write token** can execute commands in BOTH `allowed_write` AND `allowed_read` lists
- A **read token** can only execute commands in `allowed_read` list
- Forbidden patterns are checked FIRST, then allowed patterns

```ini
[commands]
# Commands allowed for read-only tokens (and write tokens)
allowed_read = 
    ^ls$
    ^ps$
    ^df$
    ^du$
    ^whoami$
    ^id$
    ^cat$

# Commands allowed for write tokens only
allowed_write = 
    ^ls$
    ^ps$
    ^echo$
    ^sleep$

# Commands always forbidden (checked first)
forbidden_read = 

forbidden_write = 
    ^rm -rf /$
    ^mkfs\..*$
    ^dd if=$
```

### Network Section

IP filtering with CIDR support. Uses "deny then allow" logic:
1. Check blacklist first - if IP matches and deny_by_default=true, block
2. Check whitelist - if IP matches, allow
3. If deny_by_default=true, block by default

```ini
[network]
allowed_ips = 
    127.0.0.1
    192.168.0.0/16
    10.0.0.0/8

blacklist_ips = 
    192.168.1.100

deny_by_default = true   # Block everything not explicitly allowed
```

### Logging Section

```ini
[logging]
log_file = /var/log/vigrid-shell-api.log
log_format = json        # json or standard
log_level = info         # debug, info, warning, error
```

### Tokens Section

Format: `token_name = login:access_level`

- `login`: Just a label for logging/identification
- `access_level`: `read` or `write`

```ini
[tokens]
my_write_token = admin:write
my_read_token = monitor:read
```

## Usage

### Running the API

#### As Systemd Service

```bash
# Start service
sudo systemctl start vigrid-shell-api

# Stop service
sudo systemctl stop vigrid-shell-api

# Restart service
sudo systemctl restart vigrid-shell-api

# Check status
sudo systemctl status vigrid-shell-api

# Reload configuration (sends SIGHUP)
sudo systemctl reload vigrid-shell-api

# Enable at boot
sudo systemctl enable vigrid-shell-api
```

#### Manual/Foreground Mode

```bash
# Normal mode
python3 vigrid-shell-api.py -c /home/gns3/etc/vigrid-shell-api.conf

# Debug mode (shows all HTTP requests)
python3 vigrid-shell-api.py -c /home/gns3/etc/vigrid-shell-api.conf -d

# Reload configuration
python3 vigrid-shell-api.py -c /home/gns3/etc/vigrid-shell-api.conf --reload
```

## API Reference

All API endpoints require authentication. Include the token in the `Authorization` header:

```bash
curl -H "Authorization: Bearer <your_token>" ...
```

---

### GET /api/v1/status

Get API status information.

**Authentication:** Required

**Response (200):**
```json
{
    "version": "1.0.0",
    "status": "running",
    "dry_run": false
}
```

**Example:**
```bash
curl -s http://localhost:5000/api/v1/status \
  -H "Authorization: Bearer my_write_token"
```

---

### POST /api/v1/execute

Execute a shell command. The access level is automatically determined by your token:
- **Write token**: Can run commands from `allowed_write` OR `allowed_read` lists
- **Read token**: Can only run commands from `allowed_read` list

**Authentication:** Required

**Request Body:**
```json
{
    "command": "ls",
    "args": ["-la", "/tmp"],
    "async": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `command` | string | Yes | Command to execute |
| `args` | array | No | Command arguments as array |
| `async` | boolean | No | If true, queue job without waiting for result (default: false) |

**Response - Sync mode (200):**
```json
{
    "job_id": 1,
    "status": "completed",
    "result": {
        "success": true,
        "stdout": "total 4\ndrwxr-xr-x   2 root root 4096 Feb 18 12:00 /tmp\n",
        "stderr": "",
        "exit_code": 0
    }
}
```

**Response - Async mode (202):**
```json
{
    "job_id": 1,
    "status": "queued"
}
```

**Error Response (403):**
```json
{
    "error": "Command not allowed"
}
```

**Example - Synchronous execution:**
```bash
curl -s -X POST http://localhost:5000/api/v1/execute \
  -H "Authorization: Bearer my_write_token" \
  -H "Content-Type: application/json" \
 ": "ls", "args": [ -d '{"command"/"]}'
```

**Example - Asynchronous execution:**
```bash
curl -s -X POST http://localhost:5000/api/v1/execute \
  -H "Authorization: Bearer my_write_token" \
  -H "Content-Type: application/json" \
  -d '{"command": "sleep", "args": ["30"], "async": true}'
```

---

### GET /api/v1/queue

List all pending and running jobs in the queue. Shows current job and queued jobs.

**Authentication:** Required

**Response (200):**
```json
{
    "jobs": [
        {
            "id": 1,
            "command": "sleep",
            "args": ["30"],
            "status": "running",
            "requested_at": "2026-02-18T12:00:00",
            "started_at": "2026-02-18T12:00:01",
            "completed_at": null
        },
        {
            "id": 2,
            "command": "ls",
            "args": ["/"],
            "status": "pending",
            "requested_at": "2026-02-18T12:00:02",
            "started_at": null,
            "completed_at": null
        }
    ]
}
```

**Example:**
```bash
curl -s http://localhost:5000/api/v1/queue \
  -H "Authorization: Bearer my_write_token"
```

---

### POST /api/v1/queue

Process the next job in the queue (mainly for async mode).

**Authentication:** Required

**Request Body:**
```json
{
    "action": "process"
}
```

**Response (200):**
```json
{
    "job_id": 1,
    "status": "completed",
    "result": {
        "success": true,
        "stdout": "...",
        "stderr": "",
        "exit_code": 0
    }
}
```

---

### POST /api/v1/kill

Kill the currently running command using a signal.

**Authentication:** Required

**Request Body:**
```json
{
    "signal": "SIGTERM"
}
```

| Signal | Description |
|--------|-------------|
| `SIGTERM` | Graceful termination (default) |
| `SIGHUP` | Hangup signal |
| `SIGKILL` | Force kill (immediate) |

**Response (200):**
```json
{
    "status": "killed"
}
```

**Response - No running job (404):**
```json
{
    "error": "No running process"
}
```

**Example:**
```bash
curl -s -X POST http://localhost:5000/api/v1/kill \
  -H "Authorization: Bearer my_write_token" \
  -H "Content-Type: application/json" \
  -d '{"signal": "SIGTERM"}'
```

---

## HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 202 | Accepted (job queued) |
| 400 | Bad request (invalid JSON) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (IP blocked, command not allowed, config modified) |
| 404 | Endpoint not found |
| 500 | Internal server error |

## Security Features

### Forbidden Characters

Commands and arguments cannot contain these characters (prevents injection):
```
' : ; \ | & ( ) { } $ < > `
```

**Note:** Detection happens at execution time - the job is queued but fails with error if forbidden chars detected.

### IP Filtering

The analysis order is:
1. If IP matches blacklist AND deny_by_default=true → block (unless also in whitelist)
2. If IP matches whitelist → allow
3. If deny_by_default=true → block
4. If deny_by_default=false → allow

This allows patterns like:
```
allowed_ips = 192.168.0.0/16
blacklist_ips = 192.168.1.100
```
To allow the entire subnet except one IP.

### Command Filtering

The analysis order is:
1. Check forbidden patterns first (any match → block)
2. For write tokens: check allowed_write, then allowed_read
3. For read tokens: check allowed_read only
4. Any non-listed command → block (default deny)

### Configuration Monitoring

The API computes a hash of the config file at startup. If the file is modified:
- All API requests return 403 until service restart
- Protects against config tampering while running

## Dry-Run Mode

When `dry_run = true` in config:
- Commands are logged but NOT executed
- Returns success with "[DRY-RUN] Would execute: ..." message
- Useful for testing without side effects

## Logging

Logs include: timestamp, level, action, and details (who, what, when, from where).

**Log actions logged:**
- `service_start` / `service_stop` / `service_ready`
- `command_queued` / `command_executed` / `command_completed`
- `ip_blocked` / `auth_failed` / `command_denied`
- `process_killed` / `config_modified`

**Example JSON log:**
```json
{"timestamp": "2026-02-18T12:00:00", "level": "info", "action": "command_queued", "details": {"job_id": 1, "command": "ls", "login": "admin", "ip": "192.168.1.10"}}
```

## Uninstall

```bash
cd /home/llevier/Vigrid-SHELL-API
sudo ./uninstall.sh
```

## Troubleshooting

### Service won't start

1. Check configuration syntax:
```bash
python3 -c "import configparser; c = configparser.ConfigParser(); c.read('/home/gns3/etc/vigrid-shell-api.conf')"
```

2. Check logs:
```bash
journalctl -u vigrid-shell-api -n 50
sudo tail -f /var/log/vigrid-shell-api.log
```

3. Run in debug mode:
```bash
sudo %%VSTORAGE_GNS3%%/bin/Vigrid-SHELL-API/venv/bin/python3 %%VSTORAGE_GNS3%%/bin/Vigrid-SHELL-API/vigrid-shell-api.py -c %%VSTORAGE_GNS3%%/etc/vigrid-shell-api.conf -d
```

### Permission denied

- Ensure `run_as_user` exists and has permissions
- For root commands, configure sudoers: `echo "username ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/vigrid-shell-api`

### Connection refused

- Check firewall: `sudo ufw allow 5000/tcp`
- Verify port in config matches service status

### Commands blocked unexpectedly

- Check the regex patterns - use `^command$` for exact match
- Verify token level matches command list
- Check logs for `command_denied` with reason

## License

Internal use only - Vigrid Project

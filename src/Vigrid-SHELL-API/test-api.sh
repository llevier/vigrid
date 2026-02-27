#!/bin/bash
# =============================================================================
# Vigrid Shell API -- Comprehensive Test Script
# =============================================================================
#
# Two operating modes:
#
#   FULL (autonomous, default):
#     ./test-api.sh
#     Installs the API into a temporary directory, generates test configs,
#     creates a temporary Unix user for identity tests, runs HTTP / HTTPS /
#     dry-run test suites, then uninstalls everything.  Fully self-contained.
#
#   TEST-ONLY (against a running service):
#     ./test-api.sh -t <config_file>
#     Reads the given configuration file to discover: bind address, port,
#     SSL mode, tokens (secrets, users, allow/deny command patterns),
#     forbidden characters, and log path.  Builds and runs all applicable
#     tests dynamically from those values.  Installs/uninstalls nothing.
#
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_INSTALL_DIR="/tmp/vigrid-shell-api-test-inst"
TEST_CONFIG_DIR="/tmp/vigrid-shell-api-test-conf"
SERVICE_NAME="vigrid-shell-api"
TEST_USER="_vigridtest"

TEST_ONLY=false
CONFIG_FILE=""
API_PID=""
CREATED_TEST_USER=false

PASS=0; FAIL=0; TOTAL=0

# Dynamically populated from config
CFG_BIND=""
CFG_PORT=""
CFG_SSL_ENABLED=""
CFG_LOG_DIR=""
CFG_LOG_FILE=""
CFG_DRY_RUN=""
BAD_TOKEN="Invalid-Token-XXXXX"

# Arrays populated by parse_config  (indexed by token name)
declare -A TOKEN_SECRETS
declare -A TOKEN_USERS
declare -a TOKEN_NAMES
declare -a CFG_FORBIDDEN_CHARS
declare -A TOKEN_ALLOW       # JSON array string per token
declare -A TOKEN_DENY        # JSON array string per token

# ---- colours ----------------------------------------------------------------
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; N='\033[0m'

# ---- helpers ----------------------------------------------------------------
log_h()  { echo -e "\n${B}=== $1 ===${N}"; }
log_sh() { echo -e "\n${Y}--- $1 ---${N}"; }
log_i()  { echo -e "[INFO]  $1"; }
log_p()  { echo -e "  ${G}[PASS]${N} $1"; PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); }
log_f()  { echo -e "  ${R}[FAIL]${N} $1"; FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); }
log_c()  { echo -e "  ${B}[CURL]${N} $1"; }

# ---- cleanup on exit --------------------------------------------------------
cleanup() {
    if [ -n "$API_PID" ] && kill -0 "$API_PID" 2>/dev/null; then
        kill "$API_PID" 2>/dev/null; wait "$API_PID" 2>/dev/null || true
    fi
    # Only remove the test user if we created it
    if [ "$CREATED_TEST_USER" = "true" ] && id "$TEST_USER" &>/dev/null; then
        userdel -r "$TEST_USER" 2>/dev/null || true
        rm -f "/etc/sudoers.d/$TEST_USER" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# =============================================================================
#  CONFIG PARSER  -- extract everything from a YAML config file via python3
# =============================================================================
parse_config() {
    local cfgfile="$1"
    [ ! -f "$cfgfile" ] && { echo "[ERROR] Config file not found: $cfgfile"; exit 1; }

    log_i "Parsing configuration: $cfgfile"

    # Single python3 call that dumps all needed values as shell assignments
    eval "$(python3 -c "
import sys, yaml, json

with open('$cfgfile', 'r') as f:
    cfg = yaml.safe_load(f)

# --- scalars -----------------------------------------------------------------
bind_addr = cfg.get('bind', '0.0.0.0')
port      = cfg.get('port', 8443)
ssl_cfg   = cfg.get('ssl', {}) or {}
ssl_on    = 'true' if ssl_cfg.get('enabled', False) else 'false'
log_dir   = cfg.get('log_dir', '/var/log')
dry_run   = 'true' if cfg.get('dry_run', False) else 'false'

print('CFG_BIND=%s' % repr(str(bind_addr)))
print('CFG_PORT=%s' % repr(str(port)))
print('CFG_SSL_ENABLED=%s' % repr(ssl_on))
print('CFG_LOG_DIR=%s' % repr(str(log_dir)))
print('CFG_DRY_RUN=%s' % repr(dry_run))

# --- forbidden chars ---------------------------------------------------------
fc = cfg.get('forbidden_chars', [])
if isinstance(fc, str):
    fc = list(fc)
elif not isinstance(fc, list):
    fc = []
# Emit as a bash-safe array
parts = []
for c in fc:
    s = str(c)
    # Escape single-quotes for bash
    s = s.replace(\"'\", \"'\\\"'\\\"'\")
    parts.append(\"'\" + s + \"'\")
print('CFG_FORBIDDEN_CHARS=(%s)' % ' '.join(parts))

# --- tokens ------------------------------------------------------------------
tokens = cfg.get('tokens', {}) or {}
names = list(tokens.keys())
print('TOKEN_NAMES=(%s)' % ' '.join(repr(n) for n in names))

for name, tcfg in tokens.items():
    secret  = tcfg.get('secret', '')
    user    = tcfg.get('user', 'root')
    allow_c = tcfg.get('allow_commands', []) or []
    deny_c  = tcfg.get('deny_commands', []) or []
    print('TOKEN_SECRETS[%s]=%s' % (repr(name), repr(str(secret))))
    print('TOKEN_USERS[%s]=%s'   % (repr(name), repr(str(user))))
    print('TOKEN_ALLOW[%s]=%s'   % (repr(name), repr(json.dumps(allow_c))))
    print('TOKEN_DENY[%s]=%s'    % (repr(name), repr(json.dumps(deny_c))))
" 2>&1)" || { echo "[ERROR] Failed to parse config file"; exit 1; }

    CFG_LOG_FILE="${CFG_LOG_DIR}/${SERVICE_NAME}.log"

    # Determine protocol
    if [ "$CFG_SSL_ENABLED" = "true" ]; then
        CFG_PROTO="https"
    else
        CFG_PROTO="http"
    fi

    log_i "  Bind      : ${CFG_BIND}:${CFG_PORT}"
    log_i "  Protocol  : ${CFG_PROTO}"
    log_i "  Dry-run   : ${CFG_DRY_RUN}"
    log_i "  Log file  : ${CFG_LOG_FILE}"
    log_i "  Tokens    : ${TOKEN_NAMES[*]}"
    log_i "  Forbidden : ${#CFG_FORBIDDEN_CHARS[@]} chars"
    for tn in "${TOKEN_NAMES[@]}"; do
        log_i "    token '$tn': user=${TOKEN_USERS[$tn]}  allow=${TOKEN_ALLOW[$tn]}  deny=${TOKEN_DENY[$tn]}"
    done
}

# =============================================================================
#  HELPERS: pick tokens by role
# =============================================================================
# Find first token whose allow_commands contains ".*" (broadest)
find_admin_token() {
    for tn in "${TOKEN_NAMES[@]}"; do
        if echo "${TOKEN_ALLOW[$tn]}" | grep -q '"\.\*"'; then
            echo "$tn"; return
        fi
    done
    # Fallback: first token
    echo "${TOKEN_NAMES[0]}"
}

# Find first token that is NOT the admin (narrower permissions)
find_restricted_token() {
    local admin="$1"
    for tn in "${TOKEN_NAMES[@]}"; do
        [ "$tn" != "$admin" ] && { echo "$tn"; return; }
    done
    echo ""
}

# From a token's allow list, extract command names that look safe to run
extract_safe_commands() {
    local token_name="$1"
    python3 -c "
import json, re, sys
allow = json.loads('${TOKEN_ALLOW[$token_name]}')
safe = []
for p in allow:
    if p == '.*':
        continue
    m = re.match(r'^\^?([a-zA-Z0-9_-]+)$', p)
    if m:
        safe.append(m.group(1))
if not safe:
    safe = ['ls', 'uname', 'hostname']
print(' '.join(safe))
" 2>/dev/null
}

# From a token's deny list, extract command names that would actually
# be rejected when called with NO arguments (bare command name).
# Patterns like "^init " (trailing space) only match with args, so
# sending "init" alone would NOT be denied -- we must skip those.
extract_denied_commands() {
    local token_name="$1"
    python3 -c "
import json, re, sys
deny = json.loads('${TOKEN_DENY[$token_name]}')
cmds = []
for p in deny:
    # Extract the leading command name from the pattern
    m = re.match(r'^\^?([a-zA-Z0-9_-]+)', p)
    if not m:
        continue
    cmd = m.group(1)
    # Only include if the bare command name would actually match the pattern
    if re.search(p, cmd):
        cmds.append(cmd)
# Deduplicate while preserving order
seen = set()
unique = []
for c in cmds:
    if c not in seen:
        seen.add(c)
        unique.append(c)
print(' '.join(unique))
" 2>/dev/null
}

# From a token's allow list, build a command name NOT in the list (for deny test)
find_unlisted_command() {
    local token_name="$1"
    python3 -c "
import json, re
allow = json.loads('${TOKEN_ALLOW[$token_name]}')
# Candidates that are very likely to exist on any Linux
candidates = ['cat','rm','cp','mv','dd','mount','touch','chmod','chown','wget','find','grep','tar']
for c in candidates:
    matched = False
    for p in allow:
        if re.search(p, c):
            matched = True
            break
    if not matched:
        print(c)
        break
" 2>/dev/null
}

# ---- api_call <description> <expected_http> <curl args...> ------------------
# Sets globals: RBODY  RCODE
api_call() {
    local desc="$1" expect="$2"; shift 2
    log_c "curl -s -w '\\n%{http_code}' $*"

    local raw
    raw=$(curl -s -w '\n%{http_code}' "$@" 2>&1)
    local rc=$?
    if [ $rc -ne 0 ]; then
        log_f "$desc -- curl exit $rc"
        RBODY=""; RCODE="000"; return 1
    fi
    RCODE=$(echo "$raw" | tail -n1)
    RBODY=$(echo "$raw" | sed '$d')
    echo "  HTTP $RCODE | ${RBODY:0:300}"

    if [ "$RCODE" = "$expect" ]; then log_p "$desc (HTTP $RCODE)"; return 0
    else log_f "$desc (expected $expect, got $RCODE)"; return 1; fi
}

# ---- json field check -------------------------------------------------------
jcheck() {
    local field="$1" expect="$2" desc="$3"
    local val
    val=$(echo "$RBODY" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    keys='$field'.split('.')
    for k in keys:
        if isinstance(d, dict):
            d=d[k]
        else:
            d='__NOT_FOUND__'
            break
    print(d)
except:
    print('__NOT_FOUND__')
" 2>/dev/null)
    if [ "$val" = "$expect" ]; then log_p "$desc ($field=$expect)"
    else log_f "$desc ($field expected '$expect' got '$val')"; fi
}

# ---- json field contains check ----------------------------------------------
jcontains() {
    local field="$1" needle="$2" desc="$3"
    local val
    val=$(echo "$RBODY" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    keys='$field'.split('.')
    for k in keys:
        if isinstance(d, dict):
            d=d[k]
        else:
            d=''
            break
    print(d)
except:
    print('')
" 2>/dev/null)
    if echo "$val" | grep -q "$needle" 2>/dev/null; then
        log_p "$desc ($field contains '$needle')"
    else
        log_f "$desc ($field='$val' does not contain '$needle')"
    fi
}

# ---- wait for API -----------------------------------------------------------
wait_api() {
    local h="$1" p="$2" pr="$3" w=0
    local co=""; [ "$pr" = "https" ] && co="-k"
    log_i "Waiting for API at ${pr}://${h}:${p} ..."
    while [ $w -lt 30 ]; do
        if curl -s $co "${pr}://${h}:${p}/api/v1/health" 2>/dev/null | grep -q '"ok"'; then
            log_i "API ready (${w}s)"; return 0
        fi
        sleep 1; w=$((w+1))
    done
    log_f "API not ready after 30s"; return 1
}

# ---- log helpers ------------------------------------------------------------
log_has() {
    if grep -q "$1" "$CFG_LOG_FILE" 2>/dev/null; then log_p "$2 (in log)"
    else log_f "$2 (not in log)"; fi
}
log_mark() {
    wc -l < "$CFG_LOG_FILE" 2>/dev/null || echo 0
}
log_since() {
    local mark="$1" pattern="$2" desc="$3"
    if tail -n +"$((mark+1))" "$CFG_LOG_FILE" 2>/dev/null | grep -q "$pattern"; then
        log_p "$desc (in log since line $mark)"
    else
        log_f "$desc (not in log since line $mark)"
    fi
}

# =============================================================================
#  CORE TEST SUITE -- fully dynamic, driven by parsed config
# =============================================================================
run_tests() {
    local h="$1" p="$2" pr="$3"
    local url="${pr}://${h}:${p}"
    local CO=""; [ "$pr" = "https" ] && CO="-k"

    # Identify token roles from config
    local admin_name; admin_name=$(find_admin_token)
    local admin_secret="${TOKEN_SECRETS[$admin_name]}"
    local admin_user="${TOKEN_USERS[$admin_name]}"
    local restricted_name; restricted_name=$(find_restricted_token "$admin_name")

    log_h "Tests against $url"
    log_i "Admin token    : '$admin_name'  (user=$admin_user)"
    if [ -n "$restricted_name" ]; then
        log_i "Restricted token: '$restricted_name'  (user=${TOKEN_USERS[$restricted_name]})"
    fi

    # =========================================================================
    #  1. Health & Status
    # =========================================================================
    log_sh "1. Health & Status"
    api_call "Health check" 200 $CO "$url/api/v1/health"
    jcheck status ok "Health status"
    jcheck service vigrid-shell-api "Health service name"

    api_call "Status (auth)" 200 $CO \
        -H "Authorization: Bearer $admin_secret" "$url/api/v1/status"
    jcheck status ok "Status"
    jcheck service vigrid-shell-api "Service name"
    jcheck version 1.0.0 "Version"

    # =========================================================================
    #  2. Authentication
    # =========================================================================
    log_sh "2. Authentication"
    api_call "No auth header -> 401" 401 $CO "$url/api/v1/status"
    api_call "Bad token -> 401" 401 $CO \
        -H "Authorization: Bearer $BAD_TOKEN" "$url/api/v1/status"
    api_call "Wrong scheme -> 401" 401 $CO \
        -H "Authorization: Token $admin_secret" "$url/api/v1/status"

    # Every known token must authenticate successfully
    for tn in "${TOKEN_NAMES[@]}"; do
        api_call "Token '$tn' -> 200" 200 $CO \
            -H "Authorization: Bearer ${TOKEN_SECRETS[$tn]}" "$url/api/v1/status"
    done

    # =========================================================================
    #  3. Synchronous execution (safe read-only commands via admin token)
    # =========================================================================
    log_sh "3. Synchronous execution (safe commands)"
    for cmd in "ls /tmp" "uname -a" "ps aux" "hostname" "date" "id" "whoami"; do
        local name="${cmd%% *}"
        local args_json="[]"
        if [[ "$cmd" == *" "* ]]; then
            local rest="${cmd#* }"
            args_json=$(python3 -c "import json,shlex; print(json.dumps(shlex.split('$rest')))")
        fi
        local m_exec; m_exec=$(log_mark)
        api_call "Exec '$cmd' sync" 200 $CO -X POST \
            -H "Authorization: Bearer $admin_secret" \
            -H "Content-Type: application/json" \
            -d "{\"command\":\"$name\",\"arguments\":$args_json,\"synchronous\":true}" \
            "$url/api/v1/execute"
        jcheck result.return_code 0 "$name return code"
        log_since "$m_exec" "Executing" "Exec '$name' logged"
    done

    # =========================================================================
    #  4. Async execution
    # =========================================================================
    log_sh "4. Asynchronous execution"
    api_call "Async ls / -> 202" 202 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"command":"ls","arguments":["/"],"synchronous":false}' \
        "$url/api/v1/execute"
    jcheck status ok "Async status"
    local async_oid
    async_oid=$(echo "$RBODY" | python3 -c "import sys,json;print(json.load(sys.stdin).get('order_id',''))" 2>/dev/null)
    [ -n "$async_oid" ] && log_p "Async order_id received: $async_oid" || log_f "No async order_id"
    sleep 2

    # =========================================================================
    #  5. Denied commands -- read from the admin token's deny list
    # =========================================================================
    log_sh "5. Denied commands (token '$admin_name')"
    local denied_cmds; denied_cmds=$(extract_denied_commands "$admin_name")
    if [ -n "$denied_cmds" ]; then
        for denied in $denied_cmds; do
            local m_deny; m_deny=$(log_mark)
            api_call "Deny '$denied' -> 403" 403 $CO -X POST \
                -H "Authorization: Bearer $admin_secret" \
                -H "Content-Type: application/json" \
                -d "{\"command\":\"$denied\",\"arguments\":[],\"synchronous\":true}" \
                "$url/api/v1/execute"
            log_since "$m_deny" "denied" "Denial '$denied' logged"
        done
    else
        log_i "No deny patterns configured for '$admin_name' -- skipping"
    fi

    # =========================================================================
    #  6. Restricted token -- allowed and denied commands
    # =========================================================================
    if [ -n "$restricted_name" ]; then
        local r_secret="${TOKEN_SECRETS[$restricted_name]}"
        local r_user="${TOKEN_USERS[$restricted_name]}"

        log_sh "6. Restricted token '$restricted_name' -- allowed commands"
        local safe_cmds; safe_cmds=$(extract_safe_commands "$restricted_name")
        if [ -n "$safe_cmds" ]; then
            for ok_cmd in $safe_cmds; do
                api_call "Restricted '$ok_cmd' -> 200" 200 $CO -X POST \
                    -H "Authorization: Bearer $r_secret" \
                    -H "Content-Type: application/json" \
                    -d "{\"command\":\"$ok_cmd\",\"arguments\":[],\"synchronous\":true}" \
                    "$url/api/v1/execute"
            done
        fi

        log_sh "6b. Restricted token '$restricted_name' -- unlisted command denied"
        local unlisted_cmd; unlisted_cmd=$(find_unlisted_command "$restricted_name")
        if [ -n "$unlisted_cmd" ]; then
            api_call "Restricted '$unlisted_cmd' -> 403" 403 $CO -X POST \
                -H "Authorization: Bearer $r_secret" \
                -H "Content-Type: application/json" \
                -d "{\"command\":\"$unlisted_cmd\",\"arguments\":[\"/tmp/__noexist__\"],\"synchronous\":true}" \
                "$url/api/v1/execute"
        fi

        # ==================================================================
        #  User identity switching
        # ==================================================================
        log_sh "6c. User identity: '$admin_name' (${admin_user}) vs '$restricted_name' (${r_user})"
        if [ "$admin_user" != "$r_user" ]; then
            # Check that the restricted user exists and has a usable shell
            if id "$r_user" &>/dev/null; then
                api_call "Admin id" 200 $CO -X POST \
                    -H "Authorization: Bearer $admin_secret" \
                    -H "Content-Type: application/json" \
                    -d '{"command":"id","arguments":[],"synchronous":true}' \
                    "$url/api/v1/execute"
                jcontains result.stdout "$admin_user" "Admin runs as $admin_user"

                api_call "Restricted id" 200 $CO -X POST \
                    -H "Authorization: Bearer $r_secret" \
                    -H "Content-Type: application/json" \
                    -d '{"command":"id","arguments":[],"synchronous":true}' \
                    "$url/api/v1/execute"
                jcontains result.stdout "$r_user" "Restricted runs as $r_user"

                api_call "Admin whoami" 200 $CO -X POST \
                    -H "Authorization: Bearer $admin_secret" \
                    -H "Content-Type: application/json" \
                    -d '{"command":"whoami","arguments":[],"synchronous":true}' \
                    "$url/api/v1/execute"
                jcontains result.stdout "$admin_user" "Admin whoami=$admin_user"

                api_call "Restricted whoami" 200 $CO -X POST \
                    -H "Authorization: Bearer $r_secret" \
                    -H "Content-Type: application/json" \
                    -d '{"command":"whoami","arguments":[],"synchronous":true}' \
                    "$url/api/v1/execute"
                jcontains result.stdout "$r_user" "Restricted whoami=$r_user"
            else
                log_i "User '$r_user' does not exist -- skipping identity tests"
            fi
        else
            log_i "Both tokens use user '$admin_user' -- identity switch not testable"
        fi
    fi

    # =========================================================================
    #  7. Forbidden characters -- read from config
    # =========================================================================
    log_sh "7. Forbidden characters"
    if [ ${#CFG_FORBIDDEN_CHARS[@]} -gt 0 ]; then
        # Test a representative subset (some chars are hard to embed in JSON)
        for bad in "${CFG_FORBIDDEN_CHARS[@]}"; do
            # Skip chars that break JSON embedding when injected via bash
            # interpolation into a -d '...' argument (double-quote and
            # backslash are consumed or re-interpreted by bash/JSON layers)
            case "$bad" in
                '"'|'\') continue ;;
            esac
            local m_fb; m_fb=$(log_mark)
            api_call "Forbidden '$bad' -> 400" 400 $CO -X POST \
                -H "Authorization: Bearer $admin_secret" \
                -H "Content-Type: application/json" \
                -d "{\"command\":\"echo\",\"arguments\":[\"test${bad}bad\"],\"synchronous\":true}" \
                "$url/api/v1/execute"
            log_since "$m_fb" "Forbidden" "Forbidden char '$bad' logged"
        done
    else
        log_i "No forbidden chars configured -- skipping"
    fi

    # =========================================================================
    #  8. Non-existent command
    # =========================================================================
    log_sh "8. Unknown command"
    api_call "Unknown cmd -> 404" 404 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"command":"__no_such_cmd_99__","arguments":[],"synchronous":true}' \
        "$url/api/v1/execute"

    # =========================================================================
    #  9. Bad requests
    # =========================================================================
    log_sh "9. Bad requests"
    api_call "Missing command -> 400" 400 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"arguments":[]}' "$url/api/v1/execute"
    api_call "Bad JSON -> 400" 400 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d 'NOT_JSON' "$url/api/v1/execute"
    api_call "Args not list -> 400" 400 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"command":"ls","arguments":"bad"}' "$url/api/v1/execute"
    api_call "GET /execute -> 405" 405 $CO \
        -H "Authorization: Bearer $admin_secret" "$url/api/v1/execute"
    api_call "Unknown endpoint -> 404" 404 $CO \
        -H "Authorization: Bearer $admin_secret" "$url/api/v1/nope"

    # =========================================================================
    #  10. Queue listing
    # =========================================================================
    log_sh "10. Queue"
    api_call "Queue listing" 200 $CO \
        -H "Authorization: Bearer $admin_secret" "$url/api/v1/queue"
    jcheck status ok "Queue status"

    # =========================================================================
    #  11. Kill endpoint
    # =========================================================================
    log_sh "11. Kill"
    api_call "Kill (nothing running)" 200 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"signal":"SIGTERM"}' "$url/api/v1/kill"
    api_call "Kill bad signal -> 400" 400 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"signal":"SIGFOO"}' "$url/api/v1/kill"

    # Start a long sleep, then kill it
    curl -s $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"command":"sleep","arguments":["60"],"synchronous":false}' \
        "$url/api/v1/execute" >/dev/null
    sleep 2
    api_call "Kill sleep SIGKILL" 200 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"signal":"SIGKILL"}' "$url/api/v1/kill"
    sleep 1

    # =========================================================================
    #  12. Non-zero exit code
    # =========================================================================
    log_sh "12. Non-zero exit code"
    api_call "ls non-existent -> rc!=0" 200 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"command":"ls","arguments":["/__no_path_xyz__"],"synchronous":true}' \
        "$url/api/v1/execute"
    local rc
    rc=$(echo "$RBODY" | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['return_code'])" 2>/dev/null)
    [ "$rc" != "0" ] && log_p "Non-zero return code ($rc)" || log_f "Expected non-zero, got $rc"
    local se
    se=$(echo "$RBODY" | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['stderr'])" 2>/dev/null)
    [ -n "$se" ] && log_p "stderr not empty for failed cmd" || log_f "stderr empty for failed cmd"

    # =========================================================================
    #  13. Reload
    # =========================================================================
    log_sh "13. Reload"
    local m_rel; m_rel=$(log_mark)
    api_call "Reload config" 200 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{}' "$url/api/v1/reload"
    jcheck status ok "Reload"
    log_since "$m_rel" "reloaded" "Reload logged"

    # =========================================================================
    #  14. Timeout
    # =========================================================================
    log_sh "14. Timeout"
    api_call "sleep 30 timeout=2" 200 $CO -X POST \
        -H "Authorization: Bearer $admin_secret" \
        -H "Content-Type: application/json" \
        -d '{"command":"sleep","arguments":["30"],"synchronous":true,"timeout":2}' \
        "$url/api/v1/execute"
    local trc
    trc=$(echo "$RBODY" | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['return_code'])" 2>/dev/null)
    [ "$trc" = "-1" ] && log_p "Timeout return code=-1" || log_f "Timeout expected -1, got $trc"
    jcontains result.stderr "timed out" "Timeout stderr message"

    # =========================================================================
    #  15. Deny > Allow priority (admin token has .* allow + specific denies)
    # =========================================================================
    log_sh "15. Deny > Allow priority"
    if [ -n "$denied_cmds" ]; then
        local first_denied; first_denied=$(echo "$denied_cmds" | awk '{print $1}')
        api_call "'$first_denied' denied despite .* allow" 403 $CO -X POST \
            -H "Authorization: Bearer $admin_secret" \
            -H "Content-Type: application/json" \
            -d "{\"command\":\"$first_denied\",\"arguments\":[],\"synchronous\":true}" \
            "$url/api/v1/execute"
    fi
}

# ---- log verification -------------------------------------------------------
run_log_tests() {
    log_sh "Log verification"
    [ ! -f "$CFG_LOG_FILE" ] && { log_f "Log file missing: $CFG_LOG_FILE"; return; }
    log_has "starting"            "Startup logged"
    log_has "Queue worker"        "Queue worker logged"
    log_has "denied"              "Denial logged"
    log_has "Authenticated"       "Auth event logged"
    log_has "Executing"           "Execution logged"
    log_has "Forbidden"           "Forbidden char logged"
    log_has "finished"            "Order completion logged"
    local n; n=$(wc -l < "$CFG_LOG_FILE")
    [ "$n" -gt 0 ] && log_p "Log has $n lines" || log_f "Log is empty"
}

# =============================================================================
#  FULL-MODE HELPERS
# =============================================================================

# ---- generate test config ---------------------------------------------------
gen_cfg() {
    local dir="$1" port="$2" proto="$3" dryrun="${4:-false}"
    local ssl_block
    if [ "$proto" = "https" ]; then
        mkdir -p "$dir/ssl"
        openssl req -x509 -newkey rsa:2048 \
            -keyout "$dir/ssl/server.key" -out "$dir/ssl/server.crt" \
            -days 1 -nodes -subj "/CN=localhost" 2>/dev/null
        ssl_block="ssl:
  enabled: true
  certificate: \"$dir/ssl/server.crt\"
  private_key: \"$dir/ssl/server.key\""
    else
        ssl_block="ssl:
  enabled: false"
    fi

    local monitor_user="root"
    if id "$TEST_USER" &>/dev/null; then
        monitor_user="$TEST_USER"
    fi

    local admin_tok="TestAdminToken9876"
    local monitor_tok="TestMonitorToken5432"

    cat > "$dir/vigrid-shell-api.conf" <<ENDCFG
bind: "127.0.0.1"
port: $port
$ssl_block
run_as: "root"
dry_run: $dryrun
command_path: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
forbidden_chars:
  - '"'
  - "'"
  - ";"
  - "\\\\"
  - "|"
  - "&"
  - "("
  - ")"
  - "{"
  - "}"
  - "\$"
  - "\`"
log_dir: "/var/log"
log_format: "syslog"
log_level: "DEBUG"
acl:
  deny:
    - "192.168.254.254/32"
  allow:
    - "127.0.0.0/8"
    - "::1/128"
tokens:
  admin:
    secret: "$admin_tok"
    user: "root"
    allow_commands:
      - ".*"
    deny_commands:
      - "^shutdown"
      - "^reboot"
      - "^init "
      - "^systemctl.*(stop|disable).*vigrid-shell-api"
      - "^fdisk"
  monitor:
    secret: "$monitor_tok"
    user: "$monitor_user"
    allow_commands:
      - "^ls"
      - "^ps"
      - "^df"
      - "^free"
      - "^uptime"
      - "^uname"
      - "^hostname"
      - "^date"
      - "^id"
      - "^whoami"
    deny_commands: []
ENDCFG
    chmod 640 "$dir/vigrid-shell-api.conf"
    log_i "Config generated: $dir/vigrid-shell-api.conf (monitor user=$monitor_user)"
}

# ---- kill anything on a given port ------------------------------------------
kill_port() {
    local port="$1"
    local pids
    pids=$(lsof -ti :"$port" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log_i "Killing stale process(es) on port $port: $pids"
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

# ---- start / stop API -------------------------------------------------------
start_api() {
    local idir="$1" cdir="$2" extra="${3:-}"
    local cfg_port
    cfg_port=$(grep '^port:' "$cdir/vigrid-shell-api.conf" | awk '{print $2}' | tr -d '"')
    [ -n "$cfg_port" ] && kill_port "$cfg_port"
    > "$CFG_LOG_FILE" 2>/dev/null || true
    # Redirect API stdout/stderr to /dev/null to prevent wait() from blocking
    # on pipe drain.  All diagnostics go to the log file anyway.
    "$idir/venv/bin/python3" "$idir/vigrid-shell-api.py" \
        -c "$cdir/vigrid-shell-api.conf" --foreground $extra >/dev/null 2>&1 &
    API_PID=$!
    sleep 2
    kill -0 "$API_PID" 2>/dev/null || { log_f "API died on start"; return 1; }
    log_i "API running, PID $API_PID"
}

stop_api() {
    if [ -n "$API_PID" ] && kill -0 "$API_PID" 2>/dev/null; then
        log_i "Stopping API (PID $API_PID)..."
        kill "$API_PID" 2>/dev/null
        # Wait up to 5 seconds for graceful shutdown
        local w=0
        while kill -0 "$API_PID" 2>/dev/null && [ $w -lt 5 ]; do
            sleep 1; w=$((w+1))
        done
        # Force kill if still alive
        if kill -0 "$API_PID" 2>/dev/null; then
            kill -9 "$API_PID" 2>/dev/null
            sleep 1
        fi
        wait "$API_PID" 2>/dev/null || true
        API_PID=""
    fi
}

# =============================================================================
#  ARGUMENT PARSING
# =============================================================================
while [ $# -gt 0 ]; do
    case "$1" in
        -t) TEST_ONLY=true
            [ $# -lt 2 ] && { echo "Usage: $0 -t <config_file>"; exit 1; }
            CONFIG_FILE="$2"; shift 2 ;;
        -h|--help)
            echo "Vigrid Shell API -- Test Script"
            echo ""
            echo "Usage:"
            echo "  $0                   Full autonomous mode (install, test, uninstall)"
            echo "  $0 -t <config_file>  Test-only mode against a running service"
            echo ""
            echo "In test-only mode, network settings, tokens, users, command"
            echo "restrictions and forbidden characters are all read from the"
            echo "given configuration file."
            exit 0 ;;
        *) echo "Unknown option: $1"; echo "Use -h for help."; exit 1 ;;
    esac
done

[ "$(id -u)" -ne 0 ] && { echo "[ERROR] Must be root."; exit 1; }

# =============================================================================
#  TEST-ONLY MODE
# =============================================================================
if [ "$TEST_ONLY" = "true" ]; then
    log_h "TEST-ONLY MODE"

    parse_config "$CONFIG_FILE"

    # Determine the effective listen address for curl
    local_host="$CFG_BIND"
    [ "$local_host" = "0.0.0.0" ] && local_host="127.0.0.1"
    [ "$local_host" = "::" ] && local_host="::1"

    wait_api "$local_host" "$CFG_PORT" "$CFG_PROTO"
    run_tests "$local_host" "$CFG_PORT" "$CFG_PROTO"

    if [ -f "$CFG_LOG_FILE" ]; then
        run_log_tests
    else
        log_i "Log file $CFG_LOG_FILE not readable -- skipping log tests"
    fi

# =============================================================================
#  FULL AUTONOMOUS MODE
# =============================================================================
else
    log_h "FULL AUTONOMOUS TEST MODE"
    log_i "Source : $SCRIPT_DIR"
    log_i "Install: $TEST_INSTALL_DIR"
    log_i "Config : $TEST_CONFIG_DIR"

    # cleanup leftovers from previous runs
    if [ -d "$TEST_INSTALL_DIR" ] || [ -d "$TEST_CONFIG_DIR" ]; then
        "$SCRIPT_DIR/uninstall.sh" "$TEST_INSTALL_DIR" "$TEST_CONFIG_DIR" 2>/dev/null || true
    fi

    # ---- Create test user for identity switching ----------------------------
    log_h "SETUP -- Create test user"
    if ! id "$TEST_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$TEST_USER" 2>/dev/null && {
            log_p "Test user '$TEST_USER' created"
            CREATED_TEST_USER=true
        } || log_f "Failed to create test user '$TEST_USER'"
    else
        log_i "Test user '$TEST_USER' already exists"
    fi

    # Configure sudo for the test user
    if [ -d /etc/sudoers.d ]; then
        echo "$TEST_USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$TEST_USER"
        echo "root ALL=($TEST_USER) NOPASSWD: ALL" >> "/etc/sudoers.d/$TEST_USER"
        chmod 440 "/etc/sudoers.d/$TEST_USER"
        log_i "Sudo configured for $TEST_USER"
    fi

    # ---- Phase 1: Install ---------------------------------------------------
    log_h "PHASE 1 -- Install"
    "$SCRIPT_DIR/install.sh" "$TEST_INSTALL_DIR" "$TEST_CONFIG_DIR"
    log_p "Installation succeeded"

    [ -f "$TEST_INSTALL_DIR/vigrid-shell-api.py" ] && \
        log_p "API script installed" || log_f "API script missing"
    [ -d "$TEST_INSTALL_DIR/venv" ] && \
        log_p "Virtual environment created" || log_f "Virtual environment missing"
    [ -f "$TEST_INSTALL_DIR/test-api.sh" ] && \
        log_p "Test script installed" || log_f "Test script missing"
    [ -f "$TEST_INSTALL_DIR/API-DOCUMENTATION.md" ] && \
        log_p "Documentation installed" || log_f "Documentation missing"
    [ -f "$TEST_INSTALL_DIR/uninstall.sh" ] && \
        log_p "Uninstall script installed" || log_f "Uninstall script missing"
    [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] && \
        log_p "Systemd service installed" || log_f "Systemd service missing"

    # ---- Phase 2: HTTP tests ------------------------------------------------
    log_h "PHASE 2 -- HTTP tests"
    HP=18080
    gen_cfg "$TEST_CONFIG_DIR" $HP http false
    parse_config "$TEST_CONFIG_DIR/vigrid-shell-api.conf"
    start_api "$TEST_INSTALL_DIR" "$TEST_CONFIG_DIR"
    wait_api 127.0.0.1 $HP http || { stop_api; exit 1; }
    run_tests 127.0.0.1 $HP http
    run_log_tests
    stop_api; sleep 1

    # ---- Phase 3: HTTPS tests -----------------------------------------------
    log_h "PHASE 3 -- HTTPS tests (self-signed certificate)"
    HSP=18443
    gen_cfg "$TEST_CONFIG_DIR" $HSP https false
    parse_config "$TEST_CONFIG_DIR/vigrid-shell-api.conf"
    start_api "$TEST_INSTALL_DIR" "$TEST_CONFIG_DIR"
    wait_api 127.0.0.1 $HSP https || { stop_api; exit 1; }
    run_tests 127.0.0.1 $HSP https
    stop_api; sleep 1

    # ---- Phase 4: Dry-run tests ---------------------------------------------
    log_h "PHASE 4 -- Dry-run tests"
    DRP=18081
    gen_cfg "$TEST_CONFIG_DIR" $DRP http true
    parse_config "$TEST_CONFIG_DIR/vigrid-shell-api.conf"
    start_api "$TEST_INSTALL_DIR" "$TEST_CONFIG_DIR"
    wait_api 127.0.0.1 $DRP http || { stop_api; exit 1; }

    admin_tok_dr=$(find_admin_token)
    admin_secret_dr="${TOKEN_SECRETS[$admin_tok_dr]}"

    api_call "Dry-run exec" 200 -X POST \
        -H "Authorization: Bearer $admin_secret_dr" \
        -H "Content-Type: application/json" \
        -d '{"command":"ls","arguments":["/tmp"],"synchronous":true}' \
        "http://127.0.0.1:${DRP}/api/v1/execute"
    jcheck result.dry_run True "dry_run flag"
    jcheck result.return_code 0 "dry_run rc"
    jcheck result.stdout "" "dry_run stdout empty"

    api_call "Dry-run status" 200 \
        -H "Authorization: Bearer $admin_secret_dr" \
        "http://127.0.0.1:${DRP}/api/v1/status"
    jcheck dry_run True "status.dry_run"

    sleep 1
    log_has "DRY-RUN" "DRY-RUN in log"

    # Denied commands still denied even in dry-run
    denied_dr=$(extract_denied_commands "$admin_tok_dr" | awk '{print $1}')
    if [ -n "$denied_dr" ]; then
        api_call "Dry-run: '$denied_dr' still denied" 403 -X POST \
            -H "Authorization: Bearer $admin_secret_dr" \
            -H "Content-Type: application/json" \
            -d "{\"command\":\"$denied_dr\",\"arguments\":[],\"synchronous\":true}" \
            "http://127.0.0.1:${DRP}/api/v1/execute"
    fi

    stop_api; sleep 1

    # ---- Phase 5: Cleanup sudoers -------------------------------------------
    if [ -f "/etc/sudoers.d/$TEST_USER" ]; then
        rm -f "/etc/sudoers.d/$TEST_USER"
        log_i "Removed sudoers entry for $TEST_USER"
    fi

    # ---- Phase 6: Uninstall -------------------------------------------------
    log_h "PHASE 5 -- Uninstall"
    "$SCRIPT_DIR/uninstall.sh" "$TEST_INSTALL_DIR" "$TEST_CONFIG_DIR"
    log_p "Uninstall succeeded"
    [ ! -d "$TEST_INSTALL_DIR" ] && log_p "Install dir removed" || log_f "Install dir still exists"
    [ ! -d "$TEST_CONFIG_DIR"  ] && log_p "Config dir removed"  || log_f "Config dir still exists"
    [ ! -f "/etc/systemd/system/${SERVICE_NAME}.service" ] && \
        log_p "Service file removed" || log_f "Service file still exists"
fi

# =============================================================================
#  SUMMARY
# =============================================================================
log_h "SUMMARY"
echo ""
echo -e "  Total : $TOTAL"
echo -e "  ${G}Passed: $PASS${N}"
echo -e "  ${R}Failed: $FAIL${N}"
echo ""
if [ $FAIL -eq 0 ]; then echo -e "  ${G}ALL TESTS PASSED${N}"; exit 0
else echo -e "  ${R}SOME TESTS FAILED${N}"; exit 1; fi

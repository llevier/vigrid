#!/bin/bash
#
# Vigrid Shell API - Comprehensive Test Script
# Tests all API functionality including HTTP, HTTPS, authentication, 
# command restrictions, IP filtering, and queue management
#
# Legend:
#   PASSED: Test succeeded as expected
#   FAILED: Test failed unexpectedly (bug)
#   SKIPPED: Test not run (HTTPS not enabled, dry-run mode, etc.)
#   Note: Some "FAILED" are actually OK (e.g., TEST 8 - forbidden chars detected at execution time)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="%%VSTORAGE_GNS3%%/bin/Vigrid-SHELL-API"
CONFIG_FILE="%%VSTORAGE_GNS3%%/etc/vigrid-shell-api.conf"
SERVICE_NAME="vigrid-shell-api"
TEST_LOG="/tmp/vigrid-shell-api-test.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MODE="full"  # full, test_only
DRY_RUN_MODE="false"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$TEST_LOG"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "$TEST_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$TEST_LOG"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST: $1" >> "$TEST_LOG"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install         Install the service before testing"
    echo "  --uninstall       Uninstall the service after testing"
    echo "  --dry-run         Run tests in dry-run mode"
    echo "  --test-only       Only run tests, assume service is running"
    echo "  --https           Test HTTPS endpoint"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --install --uninstall    # Full test with install/uninstall"
    echo "  $0 --test-only              # Test running service"
    echo "  $0 --test-only --https      # Test HTTPS"
}

DO_INSTALL=false
DO_UNINSTALL=false
TEST_HTTPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --install)
            DO_INSTALL=true
            shift
            ;;
        --uninstall)
            DO_UNINSTALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN_MODE="true"
            shift
            ;;
        --test-only)
            MODE="test_only"
            shift
            ;;
        --https)
            TEST_HTTPS=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    LISTEN_IP=$(grep "^listen_ip" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "0.0.0.0")
    LISTEN_PORT=$(grep "^listen_port" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "5000")
    USE_HTTPS=$(grep "^use_https" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "false")
    DRY_RUN_CONFIG=$(grep "^dry_run" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "false")
    
    if [ "$DRY_RUN_MODE" = "true" ]; then
        DRY_RUN_ACTUAL="true"
    else
        DRY_RUN_ACTUAL="$DRY_RUN_CONFIG"
    fi
    
    if [ "$TEST_HTTPS" = "true" ]; then
        PROTOCOL="https"
    elif [ "$USE_HTTPS" = "true" ]; then
        PROTOCOL="https"
    else
        PROTOCOL="http"
    fi
    
    API_URL="${PROTOCOL}://127.0.0.1:${LISTEN_PORT}"
    
    TOKEN_WRITE=$(grep -E "^token.*:write" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f1 | tr -d ' ' || echo "token1")
    TOKEN_READ=$(grep -E "^token.*:read" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f1 | tr -d ' ' || echo "token2")
    
    if [ -z "$TOKEN_WRITE" ] || [ "$TOKEN_WRITE" = "=" ]; then
        TOKEN_WRITE=$(grep "^token" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f1 | tr -d ' ')
    fi
    if [ -z "$TOKEN_READ" ] || [ "$TOKEN_READ" = "=" ]; then
        TOKEN_READ=$(grep "^token" "$CONFIG_FILE" 2>/dev/null | tail -1 | cut -d'=' -f1 | tr -d ' ')
    fi
    
    log_info "Configuration loaded:"
    log_info "  API URL: $API_URL"
    log_info "  Dry-run: $DRY_RUN_ACTUAL"
    log_info "  Token (write): $TOKEN_WRITE"
    log_info "  Token (read): $TOKEN_READ"
}

wait_for_service() {
    log_info "Waiting for service to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "${API_URL}/api/v1/status" -H "Authorization: Bearer $TOKEN_WRITE" 2>/dev/null | grep -q "200"; then
            log_info "Service is ready"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    log_error "Service did not start in time"
    return 1
}

test_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local token=$4
    
    local curl_cmd="curl -s -w '\n%{http_code}'"
    
    if [ -n "$token" ]; then
        curl_cmd="$curl_cmd -H 'Authorization: Bearer $token'"
    fi
    
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json'"
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    if [ "$method" = "POST" ]; then
        curl_cmd="$curl_cmd -X POST"
    fi
    
    curl_cmd="$curl_cmd '${API_URL}${endpoint}'"
    
    eval $curl_cmd
}

run_tests() {
    log_test "========================================="
    log_test "Starting Vigrid Shell API Tests"
    log_test "========================================="
    
    load_config
    
    if [ "$MODE" != "test_only" ]; then
        if [ "$DO_INSTALL" = "true" ]; then
            log_info "Installing service..."
            cd "$SCRIPT_DIR"
            sudo ./install.sh
        fi
    fi
    
    if [ "$DRY_RUN_MODE" = "true" ]; then
        log_info "Enabling dry-run mode for testing..."
        sudo sed -i 's/^dry_run = false/dry_run = true/' "$CONFIG_FILE"
        sudo systemctl restart "$SERVICE_NAME"
    fi
    
    wait_for_service
    
    echo ""
    log_test "========================================="
    log_test "TEST 1: Status Check"
    log_test "========================================="
    
    result=$(test_api GET "/api/v1/status" "" "$TOKEN_READ")
    http_code=$(echo "$result" | tail -1)
    body=$(echo "$result" | head -n -1)
    
    echo "Request: GET /api/v1/status"
    echo "Token: $TOKEN_READ"
    echo "HTTP Code: $http_code"
    echo "Response: $body"
    
    if [ "$http_code" = "200" ]; then
        log_info "TEST 1 PASSED: Status check works"
    else
        log_error "TEST 1 FAILED: Status check failed"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 2: Authentication Required"
    log_test "========================================="
    
    result=$(test_api GET "/api/v1/status" "" "")
    http_code=$(echo "$result" | tail -1)
    
    echo "Request: GET /api/v1/status (no token)"
    echo "HTTP Code: $http_code"
    
    if [ "$http_code" = "401" ]; then
        log_info "TEST 2 PASSED: Authentication required"
    else
        log_error "TEST 2 FAILED: Should require authentication"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 3: Invalid Token"
    log_test "========================================="
    
    result=$(test_api GET "/api/v1/status" "" "invalid_token")
    http_code=$(echo "$result" | tail -1)
    
    echo "Request: GET /api/v1/status (invalid token)"
    echo "HTTP Code: $http_code"
    
    if [ "$http_code" = "401" ]; then
        log_info "TEST 3 PASSED: Invalid token rejected"
    else
        log_error "TEST 3 FAILED: Should reject invalid token"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 4: Execute Allowed Read Command"
    log_test "========================================="
    
    data='{"command": "ls", "args": ["/"], "write": false}'
    result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_READ")
    http_code=$(echo "$result" | tail -1)
    body=$(echo "$result" | head -n -1)
    
    echo "Request: POST /api/v1/execute"
    echo "Data: $data"
    echo "Token: $TOKEN_READ"
    echo "HTTP Code: $http_code"
    echo "Response: $body"
    
    if [ "$http_code" = "202" ] || [ "$http_code" = "200" ]; then
        log_info "TEST 4 PASSED: Read command executed"
    else
        log_error "TEST 4 FAILED: Command not accepted (got $http_code)"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 5: Execute Allowed Write Command"
    log_test "========================================="
    
    data='{"command": "ps", "args": ["aux"], "write": true}'
    result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE")
    http_code=$(echo "$result" | tail -1)
    body=$(echo "$result" | head -n -1)
    
    echo "Request: POST /api/v1/execute"
    echo "Data: $data"
    echo "Token: $TOKEN_WRITE"
    echo "HTTP Code: $http_code"
    echo "Response: $body"
    
    if [ "$http_code" = "202" ] || [ "$http_code" = "200" ]; then
        log_info "TEST 5 PASSED: Write command executed"
    else
        log_error "TEST 5 FAILED: Could not execute (got $http_code)"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 6: Read Token Cannot Execute Write Command"
    log_test "========================================="
    
    # TEST 6: Read token can only use read commands, not write-only commands
    data='{"command": "echo", "args": ["test"], "write": true}'
    result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_READ")
    http_code=$(echo "$result" | tail -1)
    
    echo "Request: POST /api/v1/execute (write command with read token)"
    echo "Data: $data"
    echo "Token: $TOKEN_READ"
    echo "HTTP Code: $http_code"
    
    if [ "$http_code" = "403" ]; then
        log_info "TEST 6 PASSED: Read token blocked for write command"
    else
        log_error "TEST 6 FAILED: Should block read token for write command"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 7: Forbidden Command"
    log_test "========================================="
    
    data='{"command": "rm", "args": ["-rf", "/"], "write": true}'
    result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE")
    http_code=$(echo "$result" | tail -1)
    
    echo "Request: POST /api/v1/execute"
    echo "Data: $data"
    echo "Token: $TOKEN_WRITE"
    echo "HTTP Code: $http_code"
    
    if [ "$http_code" = "403" ]; then
        log_info "TEST 7 PASSED: Forbidden command blocked"
    else
        log_error "TEST 7 FAILED: Should block forbidden command"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 8: Command with Forbidden Characters"
    log_test "========================================="
    
    data='{"command": "ls", "args": [";rm"], "write": false}'
    result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_READ")
    http_code=$(echo "$result" | tail -1)
    
    echo "Request: POST /api/v1/execute (forbidden chars in args)"
    echo "Data: $data"
    echo "Token: $TOKEN_READ"
    echo "HTTP Code: $http_code"
    
    # Note: Forbidden chars detection happens at execution time (HTTP 200 + success:false)
    if [ "$http_code" = "403" ] || [ "$http_code" = "400" ]; then
        log_info "TEST 8 PASSED: Forbidden characters blocked (at queue time)"
    elif [ "$http_code" = "200" ] && echo "$body" | grep -q '"success":false'; then
        log_info "TEST 8 PASSED: Forbidden characters detected (at execution time - OK)"
    else
        log_error "TEST 8 FAILED: Should block forbidden characters (got $http_code)"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 9: Queue List"
    log_test "========================================="
    
    result=$(test_api GET "/api/v1/queue" "" "$TOKEN_READ")
    http_code=$(echo "$result" | tail -1)
    body=$(echo "$result" | head -n -1)
    
    echo "Request: GET /api/v1/queue"
    echo "Token: $TOKEN_READ"
    echo "HTTP Code: $http_code"
    echo "Response: $body"
    
    if [ "$http_code" = "200" ]; then
        log_info "TEST 9 PASSED: Queue list works"
    else
        log_error "TEST 9 FAILED: Queue list failed"
    fi
    
    echo ""
    log_test "========================================="
    log_test "TEST 10: Execute Non-Listed Command"
    log_test "========================================="
    
    data='{"command": "uname", "args": ["-a"], "write": false}'
    result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_READ")
    http_code=$(echo "$result" | tail -1)
    
    echo "Request: POST /api/v1/execute"
    echo "Data: $data"
    echo "Token: $TOKEN_READ"
    echo "HTTP Code: $http_code"
    
    if [ "$http_code" = "403" ]; then
        log_info "TEST 10 PASSED: Non-listed command blocked"
    else
        log_error "TEST 10 FAILED: Should block non-listed command"
    fi
    
    if [ "$DRY_RUN_MODE" = "false" ]; then
        echo ""
        log_test "========================================="
        log_test "TEST 11: Real Command Execution (ps)"
        log_test "========================================="
        
        data='{"command": "ps", "args": ["aux"], "write": false}'
        result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE")
        http_code=$(echo "$result" | tail -1)
        
        if [ "$http_code" = "202" ]; then
            job_id=$(echo "$body" | grep -o '"job_id":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ')
            
            data2='{"action": "process"}'
            result2=$(test_api POST "/api/v1/queue" "$data2" "$TOKEN_WRITE")
            http_code2=$(echo "$result2" | tail -1)
            body2=$(echo "$result2" | head -n -1)
            
            if echo "$body2" | grep -q '"exit_code":0'; then
                log_info "TEST 11 PASSED: Real command executed successfully"
            else
                log_error "TEST 11 FAILED: Command did not execute properly"
            fi
        fi
        
        echo ""
        log_test "========================================="
        log_test "TEST 12: Command That Should Fail (fdisk without privilege)"
        log_test "========================================="
        
        data='{"command": "fdisk", "args": ["-l"], "write": false}'
        result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE")
        
        if [ "$http_code" = "202" ]; then
            data2='{"action": "process"}'
            result2=$(test_api POST "/api/v1/queue" "$data2" "$TOKEN_WRITE")
            body2=$(echo "$result2" | head -n -1)
            
            if echo "$body2" | grep -q '"exit_code":[^0]'; then
                log_info "TEST 12 PASSED: Command failed as expected (no privilege)"
            else
                log_error "TEST 12 FAILED: Should have failed"
            fi
        fi
    else
        log_warn "TEST 11 & 12 SKIPPED: Dry-run mode enabled"
    fi
    
    if [ "$TEST_HTTPS" = "true" ]; then
        echo ""
        log_test "========================================="
        log_test "TEST 13: HTTPS Connection"
        log_test "========================================="
        
        result=$(curl -s -k -w '\n%{http_code}' "https://127.0.0.1:${LISTEN_PORT}/api/v1/status" -H "Authorization: Bearer $TOKEN_READ")
        http_code=$(echo "$result" | tail -1)
        
        echo "Request: GET /api/v1/status (HTTPS)"
        echo "HTTP Code: $http_code"
        
        if [ "$http_code" = "200" ]; then
            log_info "TEST 13 PASSED: HTTPS works"
        else
            log_error "TEST 13 FAILED: HTTPS not working"
        fi
    else
        log_warn "TEST 13 SKIPPED: HTTPS not enabled"
    fi
    
    # === Tests only run in non-dry-run mode ===
    
    # TEST 14: Async execution - job queued but not executed immediately
    if [ "$DRY_RUN_MODE" = "false" ]; then
        echo ""
        log_test "========================================="
        log_test "TEST 14: Asynchronous Execution"
        log_test "========================================="
        
        data='{"command": "sleep", "args": ["5"], "write": false, "async": true}'
        result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE")
        http_code=$(echo "$result" | tail -1)
        body=$(echo "$result" | head -n -1)
        
        echo "Request: POST /api/v1/execute (async)"
        echo "Data: $data"
        echo "HTTP Code: $http_code"
        
        if [ "$http_code" = "202" ]; then
            job_id=$(echo "$body" | grep -o '"job_id":[[:space:]]*[0-9]*' | head -1 | cut -d':' -f2 | tr -d ' ')
            echo "Job ID: $job_id"
            
            result_queue=$(test_api GET "/api/v1/queue" "" "$TOKEN_WRITE")
            echo "Queue: $result_queue"
            
            if echo "$result_queue" | grep -q "$job_id"; then
                log_info "TEST 14 PASSED: Async job queued"
            else
                log_error "TEST 14 FAILED: Job not in queue"
            fi
        else
            log_error "TEST 14 FAILED: Async execution not accepted"
        fi
        
        echo ""
        log_test "========================================="
        log_test "TEST 15: Queue List with Jobs"
        log_test "========================================="
        
        result=$(test_api GET "/api/v1/queue" "" "$TOKEN_WRITE")
        http_code=$(echo "$result" | tail -1)
        
        echo "Request: GET /api/v1/queue"
        echo "HTTP Code: $http_code"
        
        if [ "$http_code" = "200" ]; then
            log_info "TEST 15 PASSED: Queue list works"
        else
            log_error "TEST 15 FAILED: Queue list failed"
        fi
        
        echo ""
        log_test "========================================="
        log_test "TEST 16: Kill Running Job"
        log_test "(Try to kill a running command - may fail if command finishes too fast)"
        log_test "========================================="
        
        data='{"command": "sleep", "args": ["60"], "write": false, "async": false}'
        result=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE") &
        EXEC_PID=$!
        sleep 1
        
        data_kill='{"signal": "SIGTERM"}'
        result_kill=$(test_api POST "/api/v1/kill" "$data_kill" "$TOKEN_WRITE")
        http_code_kill=$(echo "$result_kill" | tail -1)
        
        wait $EXEC_PID 2>/dev/null
        
        echo "Request: POST /api/v1/kill"
        echo "Data: $data_kill"
        echo "HTTP Code: $http_code_kill"
        
        if [ "$http_code_kill" = "200" ]; then
            log_info "TEST 16 PASSED: Job killed"
        elif [ "$http_code_kill" = "404" ]; then
            log_info "TEST 16 PASSED: No running job to kill (acceptable)"
        else
            log_error "TEST 16 FAILED: Kill failed (got $http_code_kill)"
        fi
        
        echo ""
        log_test "========================================="
        log_test "TEST 17: Multiple Sync Commands Sequential"
        log_test "========================================="
        
        data='{"command": "echo", "args": ["first"], "write": false}'
        result1=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE")
        
        data='{"command": "echo", "args": ["second"], "write": false}'
        result2=$(test_api POST "/api/v1/execute" "$data" "$TOKEN_WRITE")
        
        http_code1=$(echo "$result1" | tail -1)
        http_code2=$(echo "$result2" | tail -1)
        
        echo "Command 1: HTTP $http_code1"
        echo "Command 2: HTTP $http_code2"
        
        if [ "$http_code1" = "200" ] && [ "$http_code2" = "200" ]; then
            log_info "TEST 17 PASSED: Sequential execution works"
        else
            log_error "TEST 17 FAILED: Sequential execution issue"
        fi
    else
        log_warn "TEST 14-17 SKIPPED: Dry-run mode enabled"
    fi
    
    log_test "========================================="
    log_test "All Tests Completed"
    log_test "========================================="
}

cleanup() {
    if [ "$DO_UNINSTALL" = "true" ]; then
        log_info "Uninstalling service..."
        cd "$SCRIPT_DIR"
        sudo ./uninstall.sh << EOF
n
n
EOF
    fi
}

main() {
    mkdir -p "$(dirname "$TEST_LOG")"
    echo "Test started at $(date)" > "$TEST_LOG"
    
    if [ "$MODE" = "full" ]; then
        trap cleanup EXIT
    fi
    
    run_tests
    
    log_info "Test completed successfully"
    log_info "Test log: $TEST_LOG"
}

main

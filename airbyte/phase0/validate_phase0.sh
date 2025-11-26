#!/bin/bash
# Phase 0 - Environment & Prerequisite Validation
# Purpose: Ensure the VPS meets all requirements before deploying Airbyte CDC stack.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

MIN_CPU=4
MIN_MEM_GB=16
MIN_DISK_GB=200

print_header() {
    echo "========================================"
    echo "Phase 0: Environment Validation"
    echo "========================================"
}

print_section() {
    echo ""
    echo "--- $1 ---"
}

print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        OK)
            echo "[OK]    $message"
            ;;
        WARN)
            echo "[WARN]  $message"
            ;;
        FAIL)
            echo "[FAIL]  $message"
            ;;
        *)
            echo "[INFO]  $message"
            ;;
    esac
}

exit_with_error() {
    print_status FAIL "$1"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_env() {
    local var_name="$1"
    local value="${!var_name:-}"
    if [ -z "$value" ]; then
        exit_with_error "Environment variable $var_name is not set."
    fi
}

test_tcp_port() {
    local host="$1"
    local port="$2"
    local label="$3"

    if command_exists nc; then
        if nc -z -w5 "$host" "$port" >/dev/null 2>&1; then
            print_status OK "$label reachable on $host:$port"
        else
            print_status WARN "$label not reachable on $host:$port"
        fi
    else
        print_status WARN "nc command missing; cannot test $label connectivity"
    fi
}

print_header()

print_section "Loading configuration"
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    print_status OK "Loaded environment variables from $ENV_FILE"
else
    exit_with_error "Missing .env file at $ENV_FILE"
fi

print_section "Verifying critical environment variables"
for var in MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD \
           CLICKHOUSE_HOST CLICKHOUSE_PORT CLICKHOUSE_USER CLICKHOUSE_PASSWORD \
           CLICKHOUSE_DATABASE; do
    require_env "$var"
    print_status OK "$var"
done

print_section "Collecting system facts"
OS_NAME="$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')"
CPU_COUNT="$(nproc --all 2>/dev/null || echo "unknown")"
MEM_TOTAL_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
DISK_TOTAL_KB="$(df -Pk / | awk 'NR==2 {print $2}' 2>/dev/null || echo 0)"

MEM_TOTAL_GB=$((MEM_TOTAL_KB / 1024 / 1024))
DISK_TOTAL_GB=$((DISK_TOTAL_KB / 1024 / 1024))

print_status OK "OS: ${OS_NAME:-unknown}"
print_status OK "CPU cores: $CPU_COUNT"
print_status OK "Memory: ${MEM_TOTAL_GB} GB"
print_status OK "Root disk capacity: ${DISK_TOTAL_GB} GB"

if [ "$CPU_COUNT" != "unknown" ] && [ "$CPU_COUNT" -lt $MIN_CPU ]; then
    print_status WARN "CPU cores below recommended minimum ($MIN_CPU)"
fi
if [ "$MEM_TOTAL_GB" -lt $MIN_MEM_GB ]; then
    print_status WARN "Memory below recommended minimum (${MIN_MEM_GB} GB)"
fi
if [ "$DISK_TOTAL_GB" -lt $MIN_DISK_GB ]; then
    print_status WARN "Disk below recommended minimum (${MIN_DISK_GB} GB)"
fi

print_section "Checking required commands"
REQUIRED_CMDS=(docker "docker compose" jq curl openssl abctl mysql nc)
for cmd in docker jq curl openssl abctl mysql nc; do
    if command_exists "$cmd"; then
        if [ "$cmd" = "docker" ]; then
            DOCKER_VERSION="$(docker --version 2>/dev/null)"
            print_status OK "$DOCKER_VERSION"
        elif [ "$cmd" = "abctl" ]; then
            ABCTL_VERSION="$(abctl version 2>/dev/null | head -n1)"
            print_status OK "abctl available (${ABCTL_VERSION:-unknown version})"
        else
            print_status OK "$cmd command present"
        fi
    else
        print_status WARN "$cmd command missing"
    fi
done

if command_exists docker; then
    if docker info >/dev/null 2>&1; then
        print_status OK "Docker daemon responsive"
    else
        print_status WARN "Docker daemon not responding"
    fi
fi

if command_exists "docker" && docker compose version >/dev/null 2>&1; then
    print_status OK "docker compose plugin available"
elif command_exists docker-compose; then
    print_status OK "docker-compose standalone available"
else
    print_status WARN "Docker Compose is not installed"
fi

print_section "Network reachability tests"
test_tcp_port "$MYSQL_HOST" "$MYSQL_PORT" "MySQL"
test_tcp_port "$CLICKHOUSE_HOST" "$CLICKHOUSE_PORT" "ClickHouse HTTP"

if command_exists curl; then
    CURL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/ping" || true)
    if [ "$CURL_STATUS" = "200" ]; then
        print_status OK "ClickHouse responded to /ping"
    else
        print_status WARN "ClickHouse /ping returned HTTP $CURL_STATUS"
    fi
fi

print_section "Recommended next actions"
cat <<'EOF'
1. Review WARN/FAIL lines above and remediate before Phase 1.
2. Ensure firewall allows outbound traffic to MySQL and ClickHouse endpoints.
3. Once all checks pass, proceed to Phase B (Airbyte deployment).
EOF

print_section "Validation complete"
print_status INFO "Share this log so we can confirm readiness."

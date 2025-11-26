#!/bin/bash
# Phase 1 - Airbyte OSS Deployment
# Purpose: Install and configure Airbyte on the VPS using abctl.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

# Default Airbyte admin password (change this!)
AIRBYTE_ADMIN_PASSWORD="${AIRBYTE_ADMIN_PASSWORD:-Airbyte_Secure_2024!}"

print_header() {
    echo "========================================"
    echo "Phase 1: Airbyte OSS Deployment"
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

print_header

print_section "Pre-flight checks"

if ! command_exists abctl; then
    exit_with_error "abctl not found. Install it first: curl -LsfS https://get.airbyte.com | bash"
fi
print_status OK "abctl is installed"

if ! command_exists docker; then
    exit_with_error "Docker not found."
fi

if ! docker info >/dev/null 2>&1; then
    exit_with_error "Docker daemon not running."
fi
print_status OK "Docker daemon is running"

print_section "Checking for existing Airbyte installation"

AIRBYTE_STATUS=$(abctl local status 2>&1 || true)
if echo "$AIRBYTE_STATUS" | grep -qi "running"; then
    print_status OK "Airbyte is already running"
    ALREADY_RUNNING=true
else
    print_status INFO "Airbyte not currently running"
    ALREADY_RUNNING=false
fi

print_section "Deploying Airbyte"

if [ "$ALREADY_RUNNING" = false ]; then
    print_status INFO "Starting Airbyte installation (this may take 5-10 minutes)..."
    echo ""
    
    if abctl local install; then
        print_status OK "Airbyte installed successfully"
    else
        exit_with_error "Airbyte installation failed"
    fi
else
    print_status INFO "Skipping install - Airbyte already running"
fi

print_section "Retrieving Airbyte credentials"

CREDS_OUTPUT=$(abctl local credentials 2>&1 || true)
echo "$CREDS_OUTPUT"

# Extract default credentials if available
if echo "$CREDS_OUTPUT" | grep -qi "password"; then
    print_status OK "Credentials retrieved"
else
    print_status WARN "Could not parse credentials output"
fi

print_section "Setting custom admin password"

if abctl local credentials --password "$AIRBYTE_ADMIN_PASSWORD" 2>/dev/null; then
    print_status OK "Admin password updated"
else
    print_status WARN "Could not update password (may require manual update)"
fi

print_section "Verifying Airbyte health"

RETRY=0
MAX_RETRIES=30
AIRBYTE_URL="http://localhost:8000"

print_status INFO "Waiting for Airbyte UI to become available..."

while [ $RETRY -lt $MAX_RETRIES ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$AIRBYTE_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        print_status OK "Airbyte UI is accessible at $AIRBYTE_URL"
        break
    fi
    RETRY=$((RETRY + 1))
    echo -n "."
    sleep 5
done
echo ""

if [ $RETRY -eq $MAX_RETRIES ]; then
    print_status WARN "Airbyte UI health check timed out (may still be starting)"
fi

print_section "Airbyte API health check"

API_URL="http://localhost:8000/api/v1/health"
API_STATUS=$(curl -s "$API_URL" 2>/dev/null || echo '{}')

if echo "$API_STATUS" | grep -qi "available\|healthy"; then
    print_status OK "Airbyte API is healthy"
else
    print_status WARN "Airbyte API health unclear: $API_STATUS"
fi

print_section "Deployment Summary"

cat <<EOF

Airbyte OSS has been deployed successfully!

  UI URL:       http://localhost:8000
  API URL:      http://localhost:8000/api/v1
  Admin User:   airbyte (or check abctl local credentials)
  Admin Pass:   $AIRBYTE_ADMIN_PASSWORD

To access remotely, ensure port 8000 is open or use SSH tunnel:
  ssh -L 8000:localhost:8000 centos@<vps-ip>

Useful commands:
  abctl local status      # Check Airbyte status
  abctl local credentials # View/update credentials
  abctl local logs        # View logs
  abctl local stop        # Stop Airbyte
  abctl local start       # Start Airbyte

EOF

print_section "Next steps"
cat <<EOF
1. Access Airbyte UI at http://localhost:8000 (or via SSH tunnel).
2. Complete initial setup wizard if prompted.
3. Proceed to Phase 2 to configure MySQL source and ClickHouse destination.
EOF

print_status OK "Phase 1 complete"

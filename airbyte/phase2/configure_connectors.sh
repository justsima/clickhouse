#!/bin/bash
# Phase 2 - Configure MySQL Source & ClickHouse Destination
# Purpose: Set up Airbyte connectors for CDC pipeline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

AIRBYTE_URL="http://localhost:8000"
AIRBYTE_API="$AIRBYTE_URL/api/v1"

print_header() {
    echo "========================================"
    echo "Phase 2: Configure Airbyte Connectors"
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

print_header

print_section "Loading configuration"

if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    print_status OK "Loaded environment from $ENV_FILE"
else
    exit_with_error "Missing .env file at $ENV_FILE"
fi

print_section "Verifying Airbyte is running"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$AIRBYTE_URL" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    print_status OK "Airbyte UI is accessible"
else
    exit_with_error "Airbyte UI not accessible (HTTP $HTTP_CODE). Run: abctl local start"
fi

print_section "Testing MySQL connectivity"

MYSQL_TEST=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    --ssl-mode=REQUIRED -e "SELECT 1;" 2>&1 || true)

if echo "$MYSQL_TEST" | grep -q "1"; then
    print_status OK "MySQL connection successful"
else
    print_status WARN "MySQL connection test failed: $MYSQL_TEST"
    print_status INFO "Continuing anyway - Airbyte will validate during source creation"
fi

print_section "Testing ClickHouse connectivity"

CH_TEST=$(curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
    "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/ping" 2>/dev/null || echo "failed")

if [ "$CH_TEST" = "Ok." ]; then
    print_status OK "ClickHouse connection successful"
else
    print_status WARN "ClickHouse ping returned: $CH_TEST"
    print_status INFO "Continuing anyway - Airbyte will validate during destination creation"
fi

print_section "Checking MySQL binlog configuration"

BINLOG_CHECK=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    --ssl-mode=REQUIRED -N -e "SHOW VARIABLES LIKE 'log_bin';" 2>/dev/null || echo "")

if echo "$BINLOG_CHECK" | grep -qi "ON"; then
    print_status OK "MySQL binlog is enabled"
else
    print_status WARN "Could not verify binlog status"
fi

BINLOG_FORMAT=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    --ssl-mode=REQUIRED -N -e "SHOW VARIABLES LIKE 'binlog_format';" 2>/dev/null || echo "")

if echo "$BINLOG_FORMAT" | grep -qi "ROW"; then
    print_status OK "binlog_format=ROW (required for CDC)"
else
    print_status WARN "binlog_format may not be ROW: $BINLOG_FORMAT"
fi

print_section "Checking MySQL user privileges"

PRIVS=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    --ssl-mode=REQUIRED -N -e "SHOW GRANTS FOR CURRENT_USER();" 2>/dev/null || echo "")

if echo "$PRIVS" | grep -qi "REPLICATION"; then
    print_status OK "User has REPLICATION privileges"
else
    print_status WARN "Could not verify REPLICATION privileges"
    print_status INFO "Required: REPLICATION SLAVE, REPLICATION CLIENT"
fi

print_section "ClickHouse target database check"

CH_DB_CHECK=$(curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
    "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/?query=SHOW+DATABASES" 2>/dev/null || echo "")

if echo "$CH_DB_CHECK" | grep -q "$CLICKHOUSE_DATABASE"; then
    print_status OK "Database '$CLICKHOUSE_DATABASE' exists in ClickHouse"
else
    print_status INFO "Database '$CLICKHOUSE_DATABASE' not found - Airbyte will create it"
fi

print_section "Configuration Summary"

cat <<EOF

MySQL Source Configuration:
  Host:     $MYSQL_HOST
  Port:     $MYSQL_PORT
  Database: $MYSQL_DATABASE
  User:     $MYSQL_USER
  SSL:      Required

ClickHouse Destination Configuration:
  Host:     $CLICKHOUSE_HOST
  Port:     $CLICKHOUSE_PORT
  Database: $CLICKHOUSE_DATABASE
  User:     $CLICKHOUSE_USER

EOF

print_section "Next Steps - Manual UI Configuration"

cat <<EOF

Phase 2 validation complete. Now configure connectors in Airbyte UI:

1. Open Airbyte UI:
   - Local: http://localhost:8000
   - Via SSH tunnel: ssh -L 8000:localhost:8000 centos@<vps-ip>

2. Create MySQL Source:
   - Click "Sources" > "New source"
   - Search for "MySQL"
   - Fill in:
       Host: $MYSQL_HOST
       Port: $MYSQL_PORT
       Database: $MYSQL_DATABASE
       Username: $MYSQL_USER
       Password: (from .env)
       SSL Mode: require (or verify-ca with DO CA cert)
       Replication Method: Read Changes using Binary Log (CDC)
   - Click "Set up source"

3. Create ClickHouse Destination:
   - Click "Destinations" > "New destination"
   - Search for "ClickHouse"
   - Fill in:
       Host: $CLICKHOUSE_HOST
       Port: $CLICKHOUSE_PORT
       Database: $CLICKHOUSE_DATABASE
       Username: $CLICKHOUSE_USER
       Password: (from .env)
       SSL: false (internal network)
   - Click "Set up destination"

4. Create Connection:
   - Click "Connections" > "New connection"
   - Select MySQL source and ClickHouse destination
   - Choose tables to sync
   - Set sync mode: Incremental | Append + Deduped (for CDC)
   - Set schedule: Manual (for initial test) or every 5 minutes

5. Run first sync:
   - Click "Sync now" to start initial snapshot
   - Monitor progress in the UI

EOF

print_section "Automated Setup (Optional)"

cat <<EOF
For automated connector setup via API, you can use:
  - Airbyte API: $AIRBYTE_API
  - Terraform provider: airbytehq/airbyte
  - Python SDK: airbyte-api

Run 'abctl local credentials' to get API Client-Id and Client-Secret.
EOF

print_status OK "Phase 2 validation complete"

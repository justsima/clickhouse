#!/bin/bash
# Phase 3 - Initial Sync & Validation
# Purpose: Monitor sync progress and validate data after initial snapshot.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

AIRBYTE_URL="http://localhost:8000"

print_header() {
    echo "========================================"
    echo "Phase 3: Sync Monitoring & Validation"
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

print_section "Verifying services are running"

# Check Airbyte
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$AIRBYTE_URL" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    print_status OK "Airbyte UI is accessible"
else
    exit_with_error "Airbyte UI not accessible (HTTP $HTTP_CODE)"
fi

# Check ClickHouse
CH_PING=$(curl -s "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/ping" 2>/dev/null || echo "failed")
if [ "$CH_PING" = "Ok." ]; then
    print_status OK "ClickHouse is responsive"
else
    exit_with_error "ClickHouse not responding"
fi

print_section "Airbyte status"

ABCTL_STATUS=$(abctl local status 2>&1 || true)
echo "$ABCTL_STATUS" | head -20
print_status OK "Airbyte status retrieved"

print_section "MySQL source table counts"

print_status INFO "Fetching table counts from MySQL..."

MYSQL_COUNTS=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    --ssl-mode=REQUIRED -N -e "
    SELECT TABLE_NAME, TABLE_ROWS 
    FROM information_schema.TABLES 
    WHERE TABLE_SCHEMA = '$MYSQL_DATABASE' 
    ORDER BY TABLE_ROWS DESC 
    LIMIT 20;" 2>/dev/null || echo "")

if [ -n "$MYSQL_COUNTS" ]; then
    echo ""
    echo "Top 20 tables by row count (MySQL estimates):"
    echo "----------------------------------------------"
    printf "%-40s %s\n" "TABLE_NAME" "ROWS"
    echo "$MYSQL_COUNTS" | while read -r table rows; do
        printf "%-40s %s\n" "$table" "$rows"
    done
    print_status OK "MySQL table counts retrieved"
else
    print_status WARN "Could not retrieve MySQL table counts"
fi

print_section "ClickHouse target table counts"

print_status INFO "Fetching table counts from ClickHouse..."

CH_COUNTS=$(curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
    "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/?query=SELECT+name,total_rows+FROM+system.tables+WHERE+database='${CLICKHOUSE_DATABASE}'+ORDER+BY+total_rows+DESC+LIMIT+20+FORMAT+TabSeparated" 2>/dev/null || echo "")

if [ -n "$CH_COUNTS" ]; then
    echo ""
    echo "Top 20 tables by row count (ClickHouse):"
    echo "-----------------------------------------"
    printf "%-40s %s\n" "TABLE_NAME" "ROWS"
    echo "$CH_COUNTS" | while read -r table rows; do
        printf "%-40s %s\n" "$table" "$rows"
    done
    print_status OK "ClickHouse table counts retrieved"
else
    print_status INFO "No tables found in ClickHouse yet (sync may not have started)"
fi

print_section "Row count comparison"

if [ -n "$MYSQL_COUNTS" ] && [ -n "$CH_COUNTS" ]; then
    MYSQL_TOTAL=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        --ssl-mode=REQUIRED -N -e "
        SELECT SUM(TABLE_ROWS) 
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = '$MYSQL_DATABASE';" 2>/dev/null || echo "0")
    
    CH_TOTAL=$(curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
        "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/?query=SELECT+sum(total_rows)+FROM+system.tables+WHERE+database='${CLICKHOUSE_DATABASE}'+FORMAT+TabSeparated" 2>/dev/null || echo "0")
    
    echo ""
    echo "Total row counts:"
    echo "  MySQL:      ${MYSQL_TOTAL:-0}"
    echo "  ClickHouse: ${CH_TOTAL:-0}"
    
    if [ "${MYSQL_TOTAL:-0}" -gt 0 ] && [ "${CH_TOTAL:-0}" -gt 0 ]; then
        PERCENTAGE=$(echo "scale=2; ($CH_TOTAL / $MYSQL_TOTAL) * 100" | bc 2>/dev/null || echo "N/A")
        echo "  Sync progress: ${PERCENTAGE}%"
    fi
else
    print_status INFO "Cannot compare - waiting for sync to start"
fi

print_section "ClickHouse database size"

CH_SIZE=$(curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
    "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/?query=SELECT+formatReadableSize(sum(bytes_on_disk))+FROM+system.parts+WHERE+database='${CLICKHOUSE_DATABASE}'+FORMAT+TabSeparated" 2>/dev/null || echo "0")

echo "Database '${CLICKHOUSE_DATABASE}' size: ${CH_SIZE:-0}"

print_section "Recent ClickHouse activity"

CH_RECENT=$(curl -s -u "${CLICKHOUSE_USER}:${CLICKHOUSE_PASSWORD}" \
    "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/?query=SELECT+event_time,query_kind,read_rows,written_rows+FROM+system.query_log+WHERE+event_time+>+now()-interval+10+minute+AND+type='QueryFinish'+ORDER+BY+event_time+DESC+LIMIT+10+FORMAT+TabSeparated" 2>/dev/null || echo "")

if [ -n "$CH_RECENT" ]; then
    echo ""
    echo "Recent queries (last 10 minutes):"
    echo "----------------------------------"
    printf "%-20s %-12s %-12s %s\n" "TIME" "KIND" "READ" "WRITTEN"
    echo "$CH_RECENT" | while read -r time kind read written; do
        printf "%-20s %-12s %-12s %s\n" "$time" "$kind" "$read" "$written"
    done
else
    print_status INFO "No recent query activity"
fi

print_section "Validation commands"

cat <<EOF

To manually verify data integrity:

1. Compare specific table counts:
   # MySQL
   mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p'$MYSQL_PASSWORD' \\
     --ssl-mode=REQUIRED -e "SELECT COUNT(*) FROM $MYSQL_DATABASE.<table_name>;"

   # ClickHouse
   curl -s -u '$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD' \\
     "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT/?query=SELECT+count()+FROM+$CLICKHOUSE_DATABASE.<table_name>"

2. Check Airbyte sync status in UI:
   http://localhost:8000 > Connections > Select connection > View sync history

3. Monitor Airbyte logs:
   abctl local logs

4. Re-run this validation script:
   bash $SCRIPT_DIR/validate_sync.sh

EOF

print_section "Summary"

cat <<EOF

Phase 3 validation complete.

Next steps:
1. If sync hasn't started: Go to Airbyte UI and click "Sync now"
2. If sync is running: Wait for completion and re-run this script
3. If sync completed: Verify row counts match between MySQL and ClickHouse
4. Enable scheduled sync (every 5 min) for ongoing CDC

Once data is validated, proceed to Phase 4 (hardening & documentation).
EOF

print_status OK "Phase 3 script complete"

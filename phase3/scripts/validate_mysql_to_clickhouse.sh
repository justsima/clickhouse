#!/bin/bash
# Validate MySQL to ClickHouse Data Replication
# Purpose: Compare tables and row counts between MySQL and ClickHouse

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  MySQL → ClickHouse Validation Report                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# ============================================================
# STEP 1: GET MYSQL TABLES AND ROW COUNTS
# ============================================================

print_section "STEP 1: GET MYSQL TABLES"

echo ""
print_info "Connecting to MySQL and fetching table list..."

# Get MySQL tables with row counts
MYSQL_TABLES=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    --ssl-mode=REQUIRED \
    -N -e "
    SELECT
        TABLE_NAME,
        TABLE_ROWS
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = '$MYSQL_DATABASE'
    AND TABLE_TYPE = 'BASE TABLE'
    ORDER BY TABLE_NAME
    " 2>/dev/null)

MYSQL_TABLE_COUNT=$(echo "$MYSQL_TABLES" | wc -l)
MYSQL_TOTAL_ROWS=$(echo "$MYSQL_TABLES" | awk '{sum+=$2} END {print sum}')

print_status 0 "Found $MYSQL_TABLE_COUNT tables in MySQL"
echo "  Total rows (approx): $(printf "%'d" $MYSQL_TOTAL_ROWS)"

# Save to temp file for comparison
echo "$MYSQL_TABLES" > /tmp/mysql_tables.txt

# ============================================================
# STEP 2: GET CLICKHOUSE TABLES AND ROW COUNTS
# ============================================================

print_section "STEP 2: GET CLICKHOUSE TABLES"

echo ""
print_info "Connecting to ClickHouse and fetching table list..."

# Get ClickHouse tables with row counts
CLICKHOUSE_TABLES=$(docker exec clickhouse-server clickhouse-client \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "
    SELECT
        name,
        total_rows
    FROM system.tables
    WHERE database = '$CLICKHOUSE_DATABASE'
    ORDER BY name
    FORMAT TSV
    " 2>/dev/null)

CLICKHOUSE_TABLE_COUNT=$(echo "$CLICKHOUSE_TABLES" | wc -l)
CLICKHOUSE_TOTAL_ROWS=$(echo "$CLICKHOUSE_TABLES" | awk '{sum+=$2} END {print sum}')
CLICKHOUSE_TABLES_WITH_DATA=$(echo "$CLICKHOUSE_TABLES" | awk '$2 > 0' | wc -l)

print_status 0 "Found $CLICKHOUSE_TABLE_COUNT tables in ClickHouse"
echo "  Tables with data: $CLICKHOUSE_TABLES_WITH_DATA"
echo "  Total rows: $(printf "%'d" $CLICKHOUSE_TOTAL_ROWS)"

# Save to temp file for comparison
echo "$CLICKHOUSE_TABLES" > /tmp/clickhouse_tables.txt

# ============================================================
# STEP 3: COMPARE TABLES
# ============================================================

print_section "STEP 3: TABLE COMPARISON"

echo ""
print_info "Comparing MySQL tables with ClickHouse..."

# Create associative arrays
declare -A MYSQL_ROWS
declare -A CLICKHOUSE_ROWS

# Parse MySQL tables
while read -r line; do
    if [ -n "$line" ]; then
        table=$(echo "$line" | awk '{print $1}')
        rows=$(echo "$line" | awk '{print $2}')
        MYSQL_ROWS["$table"]=$rows
    fi
done < /tmp/mysql_tables.txt

# Parse ClickHouse tables
while read -r line; do
    if [ -n "$line" ]; then
        table=$(echo "$line" | awk '{print $1}')
        rows=$(echo "$line" | awk '{print $2}')
        CLICKHOUSE_ROWS["$table"]=$rows
    fi
done < /tmp/clickhouse_tables.txt

# Categorize tables
MISSING_TABLES=()
EMPTY_TABLES=()
PARTIAL_TABLES=()
SUCCESS_TABLES=()

for table in "${!MYSQL_ROWS[@]}"; do
    mysql_rows=${MYSQL_ROWS[$table]}
    clickhouse_rows=${CLICKHOUSE_ROWS[$table]:-0}

    if [ -z "${CLICKHOUSE_ROWS[$table]}" ]; then
        # Table doesn't exist in ClickHouse
        MISSING_TABLES+=("$table|$mysql_rows")
    elif [ "$clickhouse_rows" -eq 0 ]; then
        # Table exists but has 0 rows
        EMPTY_TABLES+=("$table|$mysql_rows|$clickhouse_rows")
    elif [ "$mysql_rows" -gt 0 ] && [ "$clickhouse_rows" -lt "$mysql_rows" ]; then
        # Table has some data but less than MySQL
        percent=$(awk "BEGIN {printf \"%.1f\", ($clickhouse_rows / $mysql_rows) * 100}")
        PARTIAL_TABLES+=("$table|$mysql_rows|$clickhouse_rows|$percent")
    else
        # Table looks good
        SUCCESS_TABLES+=("$table|$mysql_rows|$clickhouse_rows")
    fi
done

# ============================================================
# STEP 4: REPORT RESULTS
# ============================================================

print_section "STEP 4: VALIDATION RESULTS"

echo ""
echo "Summary:"
echo "  MySQL Tables:           $MYSQL_TABLE_COUNT"
echo "  ClickHouse Tables:      $CLICKHOUSE_TABLE_COUNT"
echo "  ✓ Successfully synced:  ${#SUCCESS_TABLES[@]}"
echo "  ⚠ Partially synced:     ${#PARTIAL_TABLES[@]}"
echo "  ✗ Empty (0 rows):       ${#EMPTY_TABLES[@]}"
echo "  ✗ Missing tables:       ${#MISSING_TABLES[@]}"
echo ""

# Calculate success rate
TOTAL_CHECK=$((${#SUCCESS_TABLES[@]} + ${#PARTIAL_TABLES[@]} + ${#EMPTY_TABLES[@]} + ${#MISSING_TABLES[@]}))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", (${#SUCCESS_TABLES[@]} / $TOTAL_CHECK) * 100}")

if (( $(echo "$SUCCESS_RATE >= 90" | bc -l) )); then
    echo -e "${GREEN}${BOLD}Overall Success Rate: $SUCCESS_RATE%${NC}"
elif (( $(echo "$SUCCESS_RATE >= 70" | bc -l) )); then
    echo -e "${YELLOW}${BOLD}Overall Success Rate: $SUCCESS_RATE%${NC}"
else
    echo -e "${RED}${BOLD}Overall Success Rate: $SUCCESS_RATE%${NC}"
fi

# ============================================================
# MISSING TABLES (Don't exist in ClickHouse)
# ============================================================

if [ ${#MISSING_TABLES[@]} -gt 0 ]; then
    print_section "MISSING TABLES (Not in ClickHouse)"

    echo ""
    printf "%-50s %15s\n" "Table Name" "MySQL Rows"
    printf "%-50s %15s\n" "$(printf '=%.0s' {1..50})" "$(printf '=%.0s' {1..15})"

    for entry in "${MISSING_TABLES[@]}"; do
        table=$(echo "$entry" | cut -d'|' -f1)
        mysql_rows=$(echo "$entry" | cut -d'|' -f2)
        printf "%-50s %'15d\n" "$table" "$mysql_rows"
    done | sort

    echo ""
    print_warning "These tables were not created in ClickHouse"
    echo "  Possible reasons:"
    echo "    - Snapshot hasn't reached these tables yet"
    echo "    - Topic not created"
    echo "    - Schema creation failed"
fi

# ============================================================
# EMPTY TABLES (Exist but have 0 rows)
# ============================================================

if [ ${#EMPTY_TABLES[@]} -gt 0 ]; then
    print_section "EMPTY TABLES (0 rows in ClickHouse)"

    echo ""
    printf "%-50s %15s %15s\n" "Table Name" "MySQL Rows" "ClickHouse Rows"
    printf "%-50s %15s %15s\n" "$(printf '=%.0s' {1..50})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})"

    for entry in "${EMPTY_TABLES[@]}"; do
        table=$(echo "$entry" | cut -d'|' -f1)
        mysql_rows=$(echo "$entry" | cut -d'|' -f2)
        clickhouse_rows=$(echo "$entry" | cut -d'|' -f3)
        printf "%-50s %'15d %'15d\n" "$table" "$mysql_rows" "$clickhouse_rows"
    done | sort

    echo ""
    print_warning "These tables exist but have no data"
    echo "  Possible reasons:"
    echo "    - Data still in Kafka buffer (wait 10-30 seconds)"
    echo "    - All records going to DLQ (check DLQ for table name)"
    echo "    - Consumer lag (data not processed yet)"
fi

# ============================================================
# PARTIAL TABLES (Have data but less than MySQL)
# ============================================================

if [ ${#PARTIAL_TABLES[@]} -gt 0 ]; then
    print_section "PARTIALLY SYNCED TABLES"

    echo ""
    printf "%-40s %12s %12s %10s\n" "Table Name" "MySQL Rows" "CH Rows" "Progress"
    printf "%-40s %12s %12s %10s\n" "$(printf '=%.0s' {1..40})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..10})"

    for entry in "${PARTIAL_TABLES[@]}"; do
        table=$(echo "$entry" | cut -d'|' -f1)
        mysql_rows=$(echo "$entry" | cut -d'|' -f2)
        clickhouse_rows=$(echo "$entry" | cut -d'|' -f3)
        percent=$(echo "$entry" | cut -d'|' -f4)
        printf "%-40s %'12d %'12d %9s%%\n" "$table" "$mysql_rows" "$clickhouse_rows" "$percent"
    done | sort

    echo ""
    print_info "These tables are still syncing (snapshot in progress)"
    echo "  This is NORMAL - wait for snapshot to complete"
fi

# ============================================================
# SUCCESSFULLY SYNCED (Top 20)
# ============================================================

if [ ${#SUCCESS_TABLES[@]} -gt 0 ]; then
    print_section "SUCCESSFULLY SYNCED TABLES (Top 20 by size)"

    echo ""
    printf "%-40s %12s %12s\n" "Table Name" "MySQL Rows" "CH Rows"
    printf "%-40s %12s %12s\n" "$(printf '=%.0s' {1..40})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})"

    for entry in "${SUCCESS_TABLES[@]}"; do
        table=$(echo "$entry" | cut -d'|' -f1)
        mysql_rows=$(echo "$entry" | cut -d'|' -f2)
        clickhouse_rows=$(echo "$entry" | cut -d'|' -f3)
        echo "$mysql_rows|$table|$clickhouse_rows"
    done | sort -t'|' -k1 -rn | head -20 | while IFS='|' read mysql_rows table clickhouse_rows; do
        printf "%-40s %'12d %'12d\n" "$table" "$mysql_rows" "$clickhouse_rows"
    done

    if [ ${#SUCCESS_TABLES[@]} -gt 20 ]; then
        echo "  ... and $((${#SUCCESS_TABLES[@]} - 20)) more tables"
    fi
fi

# ============================================================
# RECOMMENDATIONS
# ============================================================

print_section "RECOMMENDATIONS"

echo ""
if [ ${#MISSING_TABLES[@]} -gt 0 ] || [ ${#EMPTY_TABLES[@]} -gt 0 ]; then
    echo "Next Steps:"
    echo ""

    if [ ${#MISSING_TABLES[@]} -gt 0 ]; then
        echo "1. Check if snapshot is still running:"
        echo "   curl -s http://localhost:8085/connectors/mysql-source-connector/status | python3 -m json.tool"
        echo ""
        echo "2. Check if topics exist for missing tables:"
        echo "   docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 | grep mysql"
        echo ""
    fi

    if [ ${#EMPTY_TABLES[@]} -gt 0 ]; then
        echo "3. Check consumer lag (data waiting to be processed):"
        echo "   docker exec redpanda-clickhouse rpk group describe connect-clickhouse-sink-connector --brokers localhost:9092"
        echo ""
        echo "4. Check DLQ for errors:"
        echo "   cd $SCRIPT_DIR && ./get_raw_dlq_error.sh"
        echo ""
    fi

    echo "5. Wait 10-30 minutes and run this script again to see progress"
else
    echo -e "${GREEN}${BOLD}✓ All tables successfully synced!${NC}"
    echo ""
    echo "CDC pipeline is working correctly!"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# Cleanup
rm -f /tmp/mysql_tables.txt /tmp/clickhouse_tables.txt

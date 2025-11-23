#!/bin/bash
# Comprehensive MySQL to ClickHouse Validation - FIXED VERSION
# Uses EXACT count(*) queries instead of approximate metadata
# Properly handles authentication and provides accurate comparison

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
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
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

print_subsection() {
    echo ""
    echo -e "${CYAN}${BOLD}───────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}───────────────────────────────────────────────────────────────────────────────${NC}"
}

echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║  COMPREHENSIVE MYSQL → CLICKHOUSE VALIDATION (EXACT COUNT METHOD)             ║"
echo "║  Using SELECT COUNT(*) for accurate comparison                               ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Started at: $(date +'%Y-%m-%d %H:%M:%S')"
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

# Create temp directory
TEMP_DIR="/tmp/clickhouse_validation_$(date +%s)"
mkdir -p "$TEMP_DIR"

echo "Analysis files will be stored in: $TEMP_DIR"
echo ""

print_warning "Note: This script uses EXACT count(*) queries which may take 10-20 minutes"
print_info "MySQL: TABLE_ROWS is 40-50% inaccurate for InnoDB (approximate estimate)"
print_info "ClickHouse: total_rows is cached metadata (not real-time)"
print_info "Solution: Using SELECT COUNT(*) for 100% accuracy"
echo ""

# ============================================================
# STEP 1: TEST CONNECTIONS
# ============================================================

print_section "STEP 1: TESTING DATABASE CONNECTIONS"

echo ""
print_info "Testing MySQL connection..."

mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    --ssl-mode=REQUIRED \
    -N -e "SELECT 'MySQL connection successful' as status" 2>/dev/null

if [ $? -eq 0 ]; then
    print_status 0 "MySQL connection works"
else
    print_status 1 "MySQL connection failed"
    exit 1
fi

echo ""
print_info "Testing ClickHouse connection..."

CH_TEST=$(clickhouse-client --host clickhouse-server --port 9000 \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "SELECT 'ClickHouse connection successful' as status" 2>/dev/null || echo "FAILED")

if [ "$CH_TEST" != "FAILED" ]; then
    print_status 0 "ClickHouse connection works (native protocol)"
    USE_NATIVE=true
else
    print_info "Native protocol failed, trying docker exec..."

    CH_TEST_DOCKER=$(docker exec clickhouse-server clickhouse-client \
        --password "$CLICKHOUSE_PASSWORD" \
        --query "SELECT 'ClickHouse connection successful'" 2>/dev/null || echo "FAILED")

    if [ "$CH_TEST_DOCKER" != "FAILED" ]; then
        print_status 0 "ClickHouse connection works (docker exec)"
        USE_NATIVE=false
    else
        print_status 1 "ClickHouse connection failed (both methods)"
        exit 1
    fi
fi

# ============================================================
# STEP 2: GET MYSQL TABLE LIST
# ============================================================

print_section "STEP 2: FETCHING MYSQL TABLE LIST"

echo ""
print_info "Getting list of tables from MySQL..."

mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    --ssl-mode=REQUIRED \
    -N -e "
    SELECT TABLE_NAME
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = '$MYSQL_DATABASE'
    AND TABLE_TYPE = 'BASE TABLE'
    ORDER BY TABLE_NAME
    " 2>/dev/null > "$TEMP_DIR/mysql_table_list.txt"

MYSQL_TABLE_COUNT=$(cat "$TEMP_DIR/mysql_table_list.txt" | wc -l)
print_status 0 "Found $MYSQL_TABLE_COUNT tables in MySQL"

# ============================================================
# STEP 3: GET CLICKHOUSE TABLE LIST
# ============================================================

print_section "STEP 3: FETCHING CLICKHOUSE TABLE LIST"

echo ""
print_info "Getting list of tables from ClickHouse..."

if [ "$USE_NATIVE" = true ]; then
    clickhouse-client --host clickhouse-server --port 9000 \
        --password "$CLICKHOUSE_PASSWORD" \
        --query "
        SELECT name
        FROM system.tables
        WHERE database = '$CLICKHOUSE_DATABASE'
        ORDER BY name
        FORMAT TSV
        " 2>/dev/null > "$TEMP_DIR/clickhouse_table_list.txt"
else
    docker exec clickhouse-server clickhouse-client \
        --password "$CLICKHOUSE_PASSWORD" \
        --query "
        SELECT name
        FROM system.tables
        WHERE database = '$CLICKHOUSE_DATABASE'
        ORDER BY name
        FORMAT TSV
        " 2>/dev/null > "$TEMP_DIR/clickhouse_table_list.txt"
fi

CLICKHOUSE_TABLE_COUNT=$(cat "$TEMP_DIR/clickhouse_table_list.txt" | wc -l)
print_status 0 "Found $CLICKHOUSE_TABLE_COUNT tables in ClickHouse"

# ============================================================
# STEP 4: GET EXACT ROW COUNTS (MYSQL)
# ============================================================

print_section "STEP 4: GETTING EXACT ROW COUNTS FROM MYSQL"

echo ""
print_warning "This will take 5-10 minutes - using SELECT COUNT(*) for accuracy"
print_info "Processing $MYSQL_TABLE_COUNT tables..."
echo ""

cat /dev/null > "$TEMP_DIR/mysql_exact_counts.txt"

COUNTER=0
START_TIME=$(date +%s)

while read -r TABLE_NAME; do
    COUNTER=$((COUNTER + 1))

    # Show progress
    echo -ne "\r  Progress: $COUNTER/$MYSQL_TABLE_COUNT tables ($(($COUNTER * 100 / $MYSQL_TABLE_COUNT))%)          "

    # Get exact count
    ROW_COUNT=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
        --ssl-mode=REQUIRED \
        -N -e "SELECT COUNT(*) FROM \`$TABLE_NAME\`" 2>/dev/null || echo "0")

    echo "$TABLE_NAME|$ROW_COUNT" >> "$TEMP_DIR/mysql_exact_counts.txt"

    # Show ETA every 10 tables
    if [ $((COUNTER % 10)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        AVG_TIME=$((ELAPSED / COUNTER))
        REMAINING=$((MYSQL_TABLE_COUNT - COUNTER))
        ETA=$((REMAINING * AVG_TIME))
        echo -ne " (ETA: ${ETA}s)          "
    fi
done < "$TEMP_DIR/mysql_table_list.txt"

echo ""
print_status 0 "MySQL exact counts complete"

MYSQL_TOTAL_ROWS=$(awk -F'|' '{sum+=$2} END {print sum}' "$TEMP_DIR/mysql_exact_counts.txt")
echo "  Total rows (exact): $(printf "%'d" $MYSQL_TOTAL_ROWS)"

# ============================================================
# STEP 5: GET EXACT ROW COUNTS (CLICKHOUSE)
# ============================================================

print_section "STEP 5: GETTING EXACT ROW COUNTS FROM CLICKHOUSE"

echo ""
print_info "This is faster than MySQL due to columnar storage"
print_info "Processing $CLICKHOUSE_TABLE_COUNT tables..."
echo ""

cat /dev/null > "$TEMP_DIR/clickhouse_exact_counts.txt"

COUNTER=0
START_TIME=$(date +%s)

while read -r TABLE_NAME; do
    COUNTER=$((COUNTER + 1))

    # Show progress
    echo -ne "\r  Progress: $COUNTER/$CLICKHOUSE_TABLE_COUNT tables ($(($COUNTER * 100 / CLICKHOUSE_TABLE_COUNT))%)          "

    # Get exact count
    if [ "$USE_NATIVE" = true ]; then
        ROW_COUNT=$(clickhouse-client --host clickhouse-server --port 9000 \
            --password "$CLICKHOUSE_PASSWORD" \
            --query "SELECT count() FROM ${CLICKHOUSE_DATABASE}.\`$TABLE_NAME\`" 2>/dev/null || echo "0")
    else
        ROW_COUNT=$(docker exec clickhouse-server clickhouse-client \
            --password "$CLICKHOUSE_PASSWORD" \
            --query "SELECT count() FROM ${CLICKHOUSE_DATABASE}.\`$TABLE_NAME\`" 2>/dev/null || echo "0")
    fi

    echo "$TABLE_NAME|$ROW_COUNT" >> "$TEMP_DIR/clickhouse_exact_counts.txt"
done < "$TEMP_DIR/clickhouse_table_list.txt"

echo ""
print_status 0 "ClickHouse exact counts complete"

CLICKHOUSE_TOTAL_ROWS=$(awk -F'|' '{sum+=$2} END {print sum}' "$TEMP_DIR/clickhouse_exact_counts.txt")
echo "  Total rows (exact): $(printf "%'d" $CLICKHOUSE_TOTAL_ROWS)"

# ============================================================
# STEP 6: ANALYZE DLQ
# ============================================================

print_section "STEP 6: DEAD LETTER QUEUE (DLQ) ANALYSIS"

echo ""
DLQ_EXISTS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -c "clickhouse-dlq" || echo "0")

if [ "$DLQ_EXISTS" -eq 0 ]; then
    print_status 0 "DLQ topic does not exist (no errors occurred)"
    DLQ_TOTAL_MESSAGES=0
else
    print_info "DLQ topic exists, checking message count..."

    # Try to get DLQ message count with better error handling
    DLQ_INFO=$(docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq --brokers localhost:9092 2>/dev/null)

    # Try multiple parsing methods
    DLQ_TOTAL_MESSAGES=$(echo "$DLQ_INFO" | grep -i "high.water" | awk '{print $NF}' | head -1)

    # If that didn't work, try another method
    if ! [[ "$DLQ_TOTAL_MESSAGES" =~ ^[0-9]+$ ]]; then
        DLQ_TOTAL_MESSAGES=$(echo "$DLQ_INFO" | grep -E "^[0-9]" | awk '{print $5}' | head -1)
    fi

    # Final validation - if still not a number, skip DLQ analysis
    if ! [[ "$DLQ_TOTAL_MESSAGES" =~ ^[0-9]+$ ]]; then
        print_warning "Could not parse DLQ message count, skipping DLQ analysis"
        DLQ_TOTAL_MESSAGES=0
        DLQ_SKIP=true
    else
        DLQ_SKIP=false
    fi

    if [ "$DLQ_SKIP" = false ]; then
        if [ "$DLQ_TOTAL_MESSAGES" -eq 0 ]; then
            print_status 0 "DLQ exists but has 0 messages"
        else
            print_status 1 "DLQ contains $DLQ_TOTAL_MESSAGES messages"

            # Sample DLQ messages
        print_info "Analyzing DLQ messages..."

        docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq \
            --brokers localhost:9092 \
            --num 1000 \
            --offset start 2>/dev/null | python3 << 'PYTHON_SCRIPT' > "$TEMP_DIR/dlq_by_table.txt"
import sys, json
from collections import defaultdict

table_errors = defaultdict(int)

for line in sys.stdin:
    try:
        msg = json.loads(line)
        headers = {h['key']: h['value'] for h in msg.get('headers', [])}
        topic = headers.get('__connect.errors.topic', 'unknown')
        table = topic.replace('mysql.mulazamflatoddbet.', '')
        table_errors[table] += 1
    except:
        continue

for table, count in sorted(table_errors.items(), key=lambda x: x[1], reverse=True):
    print(f"{table}|{count}")
PYTHON_SCRIPT

        echo ""
        if [ -s "$TEMP_DIR/dlq_by_table.txt" ]; then
            print_subsection "Top 20 Tables Affected by DLQ Errors"
            echo ""
            printf "%-60s %15s\n" "Table Name" "DLQ Messages"
            printf "%-60s %15s\n" "$(printf '=%.0s' {1..60})" "$(printf '=%.0s' {1..15})"

            head -20 "$TEMP_DIR/dlq_by_table.txt" | while IFS='|' read table count; do
                printf "%-60s %'15d\n" "$table" "$count"
            done
            echo ""
        fi
    fi
fi

# ============================================================
# STEP 7: COMPARE EXACT COUNTS
# ============================================================

print_section "STEP 7: DETAILED COMPARISON (EXACT COUNTS)"

echo ""
print_info "Comparing exact row counts between MySQL and ClickHouse..."
echo ""

# Build associative arrays
declare -A MYSQL_EXACT
declare -A CLICKHOUSE_EXACT

while IFS='|' read table count; do
    MYSQL_EXACT["$table"]=$count
done < "$TEMP_DIR/mysql_exact_counts.txt"

while IFS='|' read table count; do
    CLICKHOUSE_EXACT["$table"]=$count
done < "$TEMP_DIR/clickhouse_exact_counts.txt"

# Categorize
cat /dev/null > "$TEMP_DIR/perfect_match.txt"
cat /dev/null > "$TEMP_DIR/close_match.txt"
cat /dev/null > "$TEMP_DIR/partial_sync.txt"
cat /dev/null > "$TEMP_DIR/empty_both.txt"
cat /dev/null > "$TEMP_DIR/empty_clickhouse.txt"
cat /dev/null > "$TEMP_DIR/missing_clickhouse.txt"
cat /dev/null > "$TEMP_DIR/overfull.txt"

PERFECT_COUNT=0
CLOSE_COUNT=0
PARTIAL_COUNT=0
EMPTY_BOTH_COUNT=0
EMPTY_CH_COUNT=0
MISSING_COUNT=0
OVERFULL_COUNT=0

for table in "${!MYSQL_EXACT[@]}"; do
    mysql_count=${MYSQL_EXACT[$table]}
    ch_count=${CLICKHOUSE_EXACT[$table]:-MISSING}

    if [ "$ch_count" = "MISSING" ]; then
        echo "$table|$mysql_count" >> "$TEMP_DIR/missing_clickhouse.txt"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    elif [ "$mysql_count" -eq 0 ] && [ "$ch_count" -eq 0 ]; then
        echo "$table|$mysql_count|$ch_count" >> "$TEMP_DIR/empty_both.txt"
        EMPTY_BOTH_COUNT=$((EMPTY_BOTH_COUNT + 1))
    elif [ "$mysql_count" -gt 0 ] && [ "$ch_count" -eq 0 ]; then
        echo "$table|$mysql_count|$ch_count" >> "$TEMP_DIR/empty_clickhouse.txt"
        EMPTY_CH_COUNT=$((EMPTY_CH_COUNT + 1))
    elif [ "$ch_count" -eq "$mysql_count" ]; then
        echo "$table|$mysql_count|$ch_count" >> "$TEMP_DIR/perfect_match.txt"
        PERFECT_COUNT=$((PERFECT_COUNT + 1))
    elif [ "$ch_count" -gt "$mysql_count" ]; then
        percent=$(awk "BEGIN {printf \"%.1f\", ($ch_count / $mysql_count) * 100}")
        echo "$table|$mysql_count|$ch_count|$percent" >> "$TEMP_DIR/overfull.txt"
        OVERFULL_COUNT=$((OVERFULL_COUNT + 1))
    else
        # ClickHouse < MySQL
        diff=$((mysql_count - ch_count))
        percent=$(awk "BEGIN {printf \"%.1f\", ($ch_count / $mysql_count) * 100}")

        # Close match: within 5% or within 100 rows
        if (( $(echo "$percent >= 95" | bc -l) )) || [ "$diff" -le 100 ]; then
            echo "$table|$mysql_count|$ch_count|$diff|$percent" >> "$TEMP_DIR/close_match.txt"
            CLOSE_COUNT=$((CLOSE_COUNT + 1))
        else
            echo "$table|$mysql_count|$ch_count|$diff|$percent" >> "$TEMP_DIR/partial_sync.txt"
            PARTIAL_COUNT=$((PARTIAL_COUNT + 1))
        fi
    fi
done

print_subsection "Categorization Summary"
echo ""
printf "%-45s %10s\n" "Category" "Count"
printf "%-45s %10s\n" "$(printf '=%.0s' {1..45})" "$(printf '=%.0s' {1..10})"
printf "%-45s %10d\n" "✓ Perfect Match (exact same count)" "$PERFECT_COUNT"
printf "%-45s %10d\n" "✓ Close Match (within 5% or 100 rows)" "$CLOSE_COUNT"
printf "%-45s %10d\n" "✓ Overfull (CH > MySQL, CDC working)" "$OVERFULL_COUNT"
printf "%-45s %10d\n" "⚠ Partial Sync (< 95% synced)" "$PARTIAL_COUNT"
printf "%-45s %10d\n" "○ Empty in Both (expected)" "$EMPTY_BOTH_COUNT"
printf "%-45s %10d\n" "✗ Empty in ClickHouse (all to DLQ)" "$EMPTY_CH_COUNT"
printf "%-45s %10d\n" "✗ Missing from ClickHouse" "$MISSING_COUNT"
echo ""

SUCCESS_TABLES=$((PERFECT_COUNT + CLOSE_COUNT + OVERFULL_COUNT))
TABLES_WITH_DATA=$(grep -v "|0$" "$TEMP_DIR/mysql_exact_counts.txt" | wc -l)
SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS_TABLES / $TABLES_WITH_DATA) * 100}")

echo "Success Metrics:"
echo "  Tables with data in MySQL:    $TABLES_WITH_DATA"
echo "  Tables successfully synced:   $SUCCESS_TABLES"
echo "  Success rate:                 $SUCCESS_RATE%"
echo ""

# ============================================================
# STEP 8: DETAILED REPORTS
# ============================================================

print_section "STEP 8: DETAILED REPORTS"

# Report: Empty in ClickHouse (Problematic)
if [ $EMPTY_CH_COUNT -gt 0 ]; then
    print_subsection "TABLES EMPTY IN CLICKHOUSE (MySQL has data, ClickHouse has 0)"
    echo ""
    printf "%-55s %15s %15s\n" "Table Name" "MySQL Rows" "CH Rows"
    printf "%-55s %15s %15s\n" "$(printf '=%.0s' {1..55})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})"

    sort -t'|' -k2 -rn "$TEMP_DIR/empty_clickhouse.txt" | head -30 | while IFS='|' read table mysql_count ch_count; do
        printf "%-55s %'15d %'15d\n" "$table" "$mysql_count" "$ch_count"
    done

    if [ $EMPTY_CH_COUNT -gt 30 ]; then
        echo "  ... and $((EMPTY_CH_COUNT - 30)) more tables"
    fi
    echo ""
fi

# Report: Partial Sync
if [ $PARTIAL_COUNT -gt 0 ]; then
    print_subsection "PARTIALLY SYNCED TABLES (< 95% complete)"
    echo ""
    printf "%-50s %12s %12s %12s %10s\n" "Table Name" "MySQL Rows" "CH Rows" "Missing" "Progress"
    printf "%-50s %12s %12s %12s %10s\n" "$(printf '=%.0s' {1..50})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..10})"

    sort -t'|' -k2 -rn "$TEMP_DIR/partial_sync.txt" | while IFS='|' read table mysql_count ch_count diff percent; do
        printf "%-50s %'12d %'12d %'12d %9s%%\n" "$table" "$mysql_count" "$ch_count" "$diff" "$percent"
    done
    echo ""
fi

# Report: Perfect + Close Matches (Top 30)
MATCHED_TOTAL=$((PERFECT_COUNT + CLOSE_COUNT))
if [ $MATCHED_TOTAL -gt 0 ]; then
    print_subsection "SUCCESSFULLY SYNCED TABLES (Top 30 by size)"
    echo ""
    printf "%-50s %12s %12s %10s\n" "Table Name" "MySQL Rows" "CH Rows" "Status"
    printf "%-50s %12s %12s %10s\n" "$(printf '=%.0s' {1..50})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..10})"

    # Show perfect matches first
    if [ -f "$TEMP_DIR/perfect_match.txt" ]; then
        sort -t'|' -k2 -rn "$TEMP_DIR/perfect_match.txt" | head -15 | while IFS='|' read table mysql_count ch_count; do
            printf "%-50s %'12d %'12d %10s\n" "$table" "$mysql_count" "$ch_count" "Perfect"
        done
    fi

    # Then close matches
    if [ -f "$TEMP_DIR/close_match.txt" ]; then
        sort -t'|' -k2 -rn "$TEMP_DIR/close_match.txt" | head -15 | while IFS='|' read table mysql_count ch_count diff percent; do
            printf "%-50s %'12d %'12d %9s%%\n" "$table" "$mysql_count" "$ch_count" "$percent"
        done
    fi

    if [ $MATCHED_TOTAL -gt 30 ]; then
        echo "  ... and $((MATCHED_TOTAL - 30)) more successfully synced tables"
    fi
    echo ""
fi

# ============================================================
# STEP 9: FINAL SUMMARY
# ============================================================

print_section "STEP 9: FINAL SUMMARY"

echo ""
print_subsection "Overall Statistics (EXACT COUNTS)"
echo ""

printf "%-50s %'20d\n" "Total MySQL tables:" "$MYSQL_TABLE_COUNT"
printf "%-50s %'20d\n" "Total ClickHouse tables:" "$CLICKHOUSE_TABLE_COUNT"
printf "%-50s %'20d\n" "Perfect matches:" "$PERFECT_COUNT"
printf "%-50s %'20d\n" "Close matches (95%+):" "$CLOSE_COUNT"
printf "%-50s %'20d\n" "Partial sync (< 95%):" "$PARTIAL_COUNT"
printf "%-50s %'20d\n" "Empty in both:" "$EMPTY_BOTH_COUNT"
printf "%-50s %'20d\n" "Empty in ClickHouse only:" "$EMPTY_CH_COUNT"
printf "%-50s %'20d\n" "Missing from ClickHouse:" "$MISSING_COUNT"
echo ""
printf "%-50s %'20d\n" "Total MySQL rows (exact):" "$MYSQL_TOTAL_ROWS"
printf "%-50s %'20d\n" "Total ClickHouse rows (exact):" "$CLICKHOUSE_TOTAL_ROWS"
printf "%-50s %'20d\n" "Rows in DLQ:" "$DLQ_TOTAL_MESSAGES"

ROWS_MISSING=$((MYSQL_TOTAL_ROWS - CLICKHOUSE_TOTAL_ROWS))
printf "%-50s %'20d\n" "Rows missing:" "$ROWS_MISSING"
echo ""

SYNC_PERCENTAGE=$(awk "BEGIN {printf \"%.4f\", ($CLICKHOUSE_TOTAL_ROWS / $MYSQL_TOTAL_ROWS) * 100}")
DLQ_PERCENTAGE=$(awk "BEGIN {printf \"%.4f\", ($DLQ_TOTAL_MESSAGES / $MYSQL_TOTAL_ROWS) * 100}")

printf "%-50s %19s%%\n" "Data sync rate (exact):" "$SYNC_PERCENTAGE"
printf "%-50s %19s%%\n" "DLQ error rate:" "$DLQ_PERCENTAGE"
echo ""

print_subsection "Assessment"
echo ""

if (( $(echo "$SYNC_PERCENTAGE >= 99.5" | bc -l) )); then
    echo -e "${GREEN}${BOLD}✓ EXCELLENT: >= 99.5% of data successfully synced${NC}"
elif (( $(echo "$SYNC_PERCENTAGE >= 98.0" | bc -l) )); then
    echo -e "${GREEN}${BOLD}✓ GOOD: >= 98% of data successfully synced${NC}"
elif (( $(echo "$SYNC_PERCENTAGE >= 95.0" | bc -l) )); then
    echo -e "${YELLOW}${BOLD}⚠ ACCEPTABLE: >= 95% of data synced${NC}"
else
    echo -e "${RED}${BOLD}✗ NEEDS ATTENTION: < 95% of data synced${NC}"
fi

echo ""

if (( $(echo "$DLQ_PERCENTAGE < 0.5" | bc -l) )); then
    echo -e "${GREEN}DLQ Status: < 0.5% error rate - Excellent${NC}"
elif (( $(echo "$DLQ_PERCENTAGE < 2.0" | bc -l) )); then
    echo -e "${YELLOW}DLQ Status: 0.5-2% error rate - Acceptable${NC}"
else
    echo -e "${RED}DLQ Status: > 2% error rate - Needs investigation${NC}"
fi

echo ""
print_subsection "Files Generated"
echo ""
echo "All detailed data saved to: $TEMP_DIR"
echo ""
echo "Key files:"
echo "  - mysql_exact_counts.txt       (Exact count for each MySQL table)"
echo "  - clickhouse_exact_counts.txt  (Exact count for each ClickHouse table)"
echo "  - perfect_match.txt            (Tables with exact same count)"
echo "  - close_match.txt              (Tables within 5% or 100 rows)"
echo "  - empty_clickhouse.txt         (Tables with data in MySQL but 0 in ClickHouse)"
echo "  - partial_sync.txt             (Tables with < 95% synced)"
echo "  - dlq_by_table.txt             (DLQ errors by table)"
echo ""

print_subsection "Methodology Used"
echo ""
echo "MySQL:      SELECT COUNT(*) FROM table  (100% accurate, row-based scan)"
echo "ClickHouse: SELECT count() FROM table   (100% accurate, column-based scan)"
echo ""
echo "Why not metadata?"
echo "  MySQL TABLE_ROWS:    40-50% inaccurate for InnoDB (random sampling)"
echo "  ClickHouse total_rows: Cached metadata (not real-time)"
echo ""
echo "This analysis uses EXACT counts for accurate comparison."
echo ""

echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Analysis completed at: $(date +'%Y-%m-%d %H:%M:%S')"
echo ""

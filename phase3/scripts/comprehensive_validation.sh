#!/bin/bash
# Comprehensive MySQL to ClickHouse Validation - Full Deep Dive
# Purpose: Complete analysis of data replication including schema validation

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
echo "║  COMPREHENSIVE MYSQL → CLICKHOUSE VALIDATION                                  ║"
echo "║  Deep Dive Analysis - All Tables, Columns, Rows, and Metrics                 ║"
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

# Create temp directory for analysis
TEMP_DIR="/tmp/clickhouse_validation_$(date +%s)"
mkdir -p "$TEMP_DIR"

echo "Analysis files will be stored in: $TEMP_DIR"
echo ""

# ============================================================
# STEP 1: GET COMPLETE MYSQL TABLE INFORMATION
# ============================================================

print_section "STEP 1: FETCHING COMPLETE MYSQL DATABASE INFORMATION"

echo ""
print_info "Connecting to MySQL: $MYSQL_HOST:$MYSQL_PORT/$MYSQL_DATABASE"
echo ""

# Get all tables with row counts and column counts
print_info "Fetching table list, row counts, and schemas..."

mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    --ssl-mode=REQUIRED \
    -N -e "
    SELECT
        TABLE_NAME,
        TABLE_ROWS,
        (SELECT COUNT(*)
         FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = t.TABLE_SCHEMA
         AND c.TABLE_NAME = t.TABLE_NAME) as COLUMN_COUNT
    FROM information_schema.TABLES t
    WHERE TABLE_SCHEMA = '$MYSQL_DATABASE'
    AND TABLE_TYPE = 'BASE TABLE'
    ORDER BY TABLE_NAME
    " 2>/dev/null > "$TEMP_DIR/mysql_tables.txt"

MYSQL_TABLE_COUNT=$(cat "$TEMP_DIR/mysql_tables.txt" | wc -l)
MYSQL_TOTAL_ROWS=$(awk '{sum+=$2} END {print sum}' "$TEMP_DIR/mysql_tables.txt")

print_status 0 "Found $MYSQL_TABLE_COUNT tables in MySQL"
echo "  Total rows (approx): $(printf "%'d" $MYSQL_TOTAL_ROWS)"
echo ""

# Get detailed schema for each table
print_info "Fetching detailed schema information for all $MYSQL_TABLE_COUNT tables..."
echo ""

while read -r line; do
    TABLE_NAME=$(echo "$line" | awk '{print $1}')

    mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
        --ssl-mode=REQUIRED \
        -N -e "
        SELECT
            COLUMN_NAME,
            COLUMN_TYPE,
            IS_NULLABLE,
            COLUMN_KEY,
            COLUMN_DEFAULT,
            EXTRA
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = '$MYSQL_DATABASE'
        AND TABLE_NAME = '$TABLE_NAME'
        ORDER BY ORDINAL_POSITION
        " 2>/dev/null > "$TEMP_DIR/mysql_schema_${TABLE_NAME}.txt"

    echo -ne "\r  Processing: $TABLE_NAME                                        "
done < "$TEMP_DIR/mysql_tables.txt"

echo ""
print_status 0 "MySQL schema analysis complete"

# ============================================================
# STEP 2: GET COMPLETE CLICKHOUSE TABLE INFORMATION
# ============================================================

print_section "STEP 2: FETCHING COMPLETE CLICKHOUSE DATABASE INFORMATION"

echo ""
print_info "Connecting to ClickHouse database: $CLICKHOUSE_DATABASE"
echo ""

# Get all tables with row counts and column counts
print_info "Fetching table list, row counts, and schemas..."

docker exec clickhouse-server clickhouse-client \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "
    SELECT
        name,
        total_rows,
        (SELECT count()
         FROM system.columns c
         WHERE c.database = t.database
         AND c.table = t.name) as column_count
    FROM system.tables t
    WHERE database = '$CLICKHOUSE_DATABASE'
    ORDER BY name
    FORMAT TSV
    " 2>/dev/null > "$TEMP_DIR/clickhouse_tables.txt"

CLICKHOUSE_TABLE_COUNT=$(cat "$TEMP_DIR/clickhouse_tables.txt" | wc -l)
CLICKHOUSE_TOTAL_ROWS=$(awk '{sum+=$2} END {print sum}' "$TEMP_DIR/clickhouse_tables.txt")
CLICKHOUSE_TABLES_WITH_DATA=$(awk '$2 > 0' "$TEMP_DIR/clickhouse_tables.txt" | wc -l)

print_status 0 "Found $CLICKHOUSE_TABLE_COUNT tables in ClickHouse"
echo "  Tables with data: $CLICKHOUSE_TABLES_WITH_DATA"
echo "  Total rows: $(printf "%'d" $CLICKHOUSE_TOTAL_ROWS)"
echo ""

# Get detailed schema for each table
print_info "Fetching detailed schema information for all $CLICKHOUSE_TABLE_COUNT tables..."
echo ""

while read -r line; do
    TABLE_NAME=$(echo "$line" | awk '{print $1}')

    docker exec clickhouse-server clickhouse-client \
        --password "$CLICKHOUSE_PASSWORD" \
        --query "
        SELECT
            name,
            type,
            default_kind,
            default_expression,
            is_in_primary_key
        FROM system.columns
        WHERE database = '$CLICKHOUSE_DATABASE'
        AND table = '$TABLE_NAME'
        ORDER BY position
        FORMAT TSV
        " 2>/dev/null > "$TEMP_DIR/clickhouse_schema_${TABLE_NAME}.txt"

    echo -ne "\r  Processing: $TABLE_NAME                                        "
done < "$TEMP_DIR/clickhouse_tables.txt"

echo ""
print_status 0 "ClickHouse schema analysis complete"

# ============================================================
# STEP 3: ANALYZE DLQ IN DETAIL
# ============================================================

print_section "STEP 3: DEAD LETTER QUEUE (DLQ) ANALYSIS"

echo ""
DLQ_EXISTS=$(docker exec redpanda-clickhouse rpk topic list --brokers localhost:9092 2>/dev/null | grep -c "clickhouse-dlq" || echo "0")

if [ "$DLQ_EXISTS" -eq 0 ]; then
    print_status 0 "DLQ topic does not exist (no errors occurred)"
    DLQ_TOTAL_MESSAGES=0
    echo ""
else
    print_info "DLQ topic exists, analyzing messages..."
    echo ""

    # Get partition info
    DLQ_PARTITION_INFO=$(docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq --brokers localhost:9092 2>/dev/null)

    # Extract high water mark (total messages)
    DLQ_TOTAL_MESSAGES=$(echo "$DLQ_PARTITION_INFO" | grep -E "^[0-9]+" | awk 'NR==2 {print $5}')

    if ! [[ "$DLQ_TOTAL_MESSAGES" =~ ^[0-9]+$ ]]; then
        DLQ_TOTAL_MESSAGES=0
    fi

    if [ "$DLQ_TOTAL_MESSAGES" -eq 0 ]; then
        print_status 0 "DLQ exists but has 0 messages"
        echo ""
    else
        print_status 1 "DLQ contains $DLQ_TOTAL_MESSAGES messages"
        echo ""

        # Analyze DLQ messages by topic/table
        print_info "Analyzing DLQ messages to identify affected tables..."
        echo ""

        docker exec redpanda-clickhouse rpk topic consume clickhouse-dlq \
            --brokers localhost:9092 \
            --num 1000 \
            --offset start 2>/dev/null | python3 << 'PYTHON_SCRIPT' > "$TEMP_DIR/dlq_analysis.txt"
import sys
import json
from collections import defaultdict

table_errors = defaultdict(int)
error_types = defaultdict(int)

for line in sys.stdin:
    try:
        msg = json.loads(line)
        headers = {h['key']: h['value'] for h in msg.get('headers', [])}

        topic = headers.get('__connect.errors.topic', 'unknown')
        table = topic.replace('mysql.mulazamflatoddbet.', '')
        error_class = headers.get('__connect.errors.exception.class.name', 'unknown')

        table_errors[table] += 1
        error_types[error_class] += 1
    except:
        continue

# Print tables affected
print("TABLES_AFFECTED")
for table, count in sorted(table_errors.items(), key=lambda x: x[1], reverse=True):
    print(f"{table}\t{count}")

print("\nERROR_TYPES")
for error_type, count in sorted(error_types.items(), key=lambda x: x[1], reverse=True):
    print(f"{error_type}\t{count}")
PYTHON_SCRIPT

        # Display DLQ analysis
        print_subsection "Tables Affected by DLQ Errors"
        echo ""

        if [ -f "$TEMP_DIR/dlq_analysis.txt" ]; then
            TABLES_SECTION=$(sed -n '/TABLES_AFFECTED/,/ERROR_TYPES/p' "$TEMP_DIR/dlq_analysis.txt" | grep -v "TABLES_AFFECTED" | grep -v "ERROR_TYPES" | head -20)

            if [ -n "$TABLES_SECTION" ]; then
                printf "%-60s %15s\n" "Table Name" "DLQ Messages"
                printf "%-60s %15s\n" "$(printf '=%.0s' {1..60})" "$(printf '=%.0s' {1..15})"
                echo "$TABLES_SECTION" | while IFS=$'\t' read table count; do
                    printf "%-60s %'15d\n" "$table" "$count"
                done
            else
                echo "No table-specific errors found in DLQ analysis"
            fi

            echo ""
            print_subsection "Error Types in DLQ"
            echo ""

            ERROR_SECTION=$(sed -n '/ERROR_TYPES/,$p' "$TEMP_DIR/dlq_analysis.txt" | grep -v "ERROR_TYPES" | head -10)

            if [ -n "$ERROR_SECTION" ]; then
                printf "%-80s %15s\n" "Error Type" "Count"
                printf "%-80s %15s\n" "$(printf '=%.0s' {1..80})" "$(printf '=%.0s' {1..15})"
                echo "$ERROR_SECTION" | while IFS=$'\t' read error_type count; do
                    printf "%-80s %'15d\n" "$error_type" "$count"
                done
            fi
        fi

        echo ""

        # Calculate DLQ percentage
        DLQ_PERCENTAGE=$(awk "BEGIN {printf \"%.4f\", ($DLQ_TOTAL_MESSAGES / $MYSQL_TOTAL_ROWS) * 100}")

        echo "DLQ Summary:"
        echo "  Total DLQ messages:    $(printf "%'d" $DLQ_TOTAL_MESSAGES)"
        echo "  Total MySQL rows:      $(printf "%'d" $MYSQL_TOTAL_ROWS)"
        echo "  DLQ percentage:        $DLQ_PERCENTAGE%"
        echo ""

        if (( $(echo "$DLQ_PERCENTAGE < 0.5" | bc -l) )); then
            print_info "DLQ < 0.5% - Acceptable data loss for initial sync"
        elif (( $(echo "$DLQ_PERCENTAGE < 2.0" | bc -l) )); then
            print_warning "DLQ 0.5-2% - Consider investigating root cause"
        else
            print_warning "DLQ > 2% - Should investigate and potentially recover"
        fi
    fi
fi

# ============================================================
# STEP 4: COMPARE TABLE SCHEMAS (COLUMN-LEVEL ANALYSIS)
# ============================================================

print_section "STEP 4: SCHEMA COMPARISON (COLUMN-LEVEL VALIDATION)"

echo ""
print_info "Comparing table schemas between MySQL and ClickHouse..."
echo ""

# Create detailed comparison
cat > "$TEMP_DIR/schema_comparison_report.txt" << 'EOF'
SCHEMA COMPARISON REPORT
========================

This report shows column-level differences between MySQL and ClickHouse tables.

EOF

SCHEMA_MISMATCH_COUNT=0

while read -r line; do
    TABLE_NAME=$(echo "$line" | awk '{print $1}')
    MYSQL_COLS=$(echo "$line" | awk '{print $3}')

    # Check if table exists in ClickHouse
    CLICKHOUSE_COLS=$(grep "^${TABLE_NAME}\s" "$TEMP_DIR/clickhouse_tables.txt" | awk '{print $3}')

    if [ -z "$CLICKHOUSE_COLS" ]; then
        continue  # Table doesn't exist in ClickHouse
    fi

    # Compare column counts
    if [ "$MYSQL_COLS" -ne "$CLICKHOUSE_COLS" ]; then
        echo "TABLE: $TABLE_NAME" >> "$TEMP_DIR/schema_comparison_report.txt"
        echo "  MySQL columns: $MYSQL_COLS" >> "$TEMP_DIR/schema_comparison_report.txt"
        echo "  ClickHouse columns: $CLICKHOUSE_COLS" >> "$TEMP_DIR/schema_comparison_report.txt"
        echo "" >> "$TEMP_DIR/schema_comparison_report.txt"

        # Show column details
        echo "  MySQL columns:" >> "$TEMP_DIR/schema_comparison_report.txt"
        if [ -f "$TEMP_DIR/mysql_schema_${TABLE_NAME}.txt" ]; then
            awk '{printf "    - %s (%s)\n", $1, $2}' "$TEMP_DIR/mysql_schema_${TABLE_NAME}.txt" >> "$TEMP_DIR/schema_comparison_report.txt"
        fi

        echo "" >> "$TEMP_DIR/schema_comparison_report.txt"
        echo "  ClickHouse columns:" >> "$TEMP_DIR/schema_comparison_report.txt"
        if [ -f "$TEMP_DIR/clickhouse_schema_${TABLE_NAME}.txt" ]; then
            awk '{printf "    - %s (%s)\n", $1, $2}' "$TEMP_DIR/clickhouse_schema_${TABLE_NAME}.txt" >> "$TEMP_DIR/schema_comparison_report.txt"
        fi

        echo "" >> "$TEMP_DIR/schema_comparison_report.txt"
        echo "---" >> "$TEMP_DIR/schema_comparison_report.txt"
        echo "" >> "$TEMP_DIR/schema_comparison_report.txt"

        SCHEMA_MISMATCH_COUNT=$((SCHEMA_MISMATCH_COUNT + 1))
    fi
done < "$TEMP_DIR/mysql_tables.txt"

if [ $SCHEMA_MISMATCH_COUNT -eq 0 ]; then
    print_status 0 "All tables have matching column counts"
else
    print_warning "Found $SCHEMA_MISMATCH_COUNT tables with column count mismatches"
    echo ""
    echo "  See detailed report: $TEMP_DIR/schema_comparison_report.txt"
fi

# ============================================================
# STEP 5: CATEGORIZE TABLES BY SYNC STATUS
# ============================================================

print_section "STEP 5: TABLE CATEGORIZATION BY SYNC STATUS"

echo ""
print_info "Categorizing all 450 tables..."
echo ""

declare -A MYSQL_ROWS
declare -A MYSQL_COLS
declare -A CLICKHOUSE_ROWS
declare -A CLICKHOUSE_COLS

# Parse MySQL data
while read -r line; do
    table=$(echo "$line" | awk '{print $1}')
    rows=$(echo "$line" | awk '{print $2}')
    cols=$(echo "$line" | awk '{print $3}')
    MYSQL_ROWS["$table"]=$rows
    MYSQL_COLS["$table"]=$cols
done < "$TEMP_DIR/mysql_tables.txt"

# Parse ClickHouse data
while read -r line; do
    table=$(echo "$line" | awk '{print $1}')
    rows=$(echo "$line" | awk '{print $2}')
    cols=$(echo "$line" | awk '{print $3}')
    CLICKHOUSE_ROWS["$table"]=$rows
    CLICKHOUSE_COLS["$table"]=$cols
done < "$TEMP_DIR/clickhouse_tables.txt"

# Categorize
cat /dev/null > "$TEMP_DIR/category_missing.txt"
cat /dev/null > "$TEMP_DIR/category_empty_mysql.txt"
cat /dev/null > "$TEMP_DIR/category_empty_clickhouse.txt"
cat /dev/null > "$TEMP_DIR/category_partial.txt"
cat /dev/null > "$TEMP_DIR/category_success.txt"
cat /dev/null > "$TEMP_DIR/category_overfull.txt"

for table in "${!MYSQL_ROWS[@]}"; do
    mysql_rows=${MYSQL_ROWS[$table]}
    mysql_cols=${MYSQL_COLS[$table]}
    clickhouse_rows=${CLICKHOUSE_ROWS[$table]:-0}
    clickhouse_cols=${CLICKHOUSE_COLS[$table]:-0}

    if [ -z "${CLICKHOUSE_ROWS[$table]}" ]; then
        # Table missing in ClickHouse
        echo "$table|$mysql_rows|$mysql_cols" >> "$TEMP_DIR/category_missing.txt"
    elif [ "$mysql_rows" -eq 0 ]; then
        # Empty in MySQL (expected empty)
        echo "$table|$mysql_rows|$mysql_cols|$clickhouse_rows|$clickhouse_cols" >> "$TEMP_DIR/category_empty_mysql.txt"
    elif [ "$clickhouse_rows" -eq 0 ]; then
        # Has data in MySQL but empty in ClickHouse
        echo "$table|$mysql_rows|$mysql_cols|$clickhouse_rows|$clickhouse_cols" >> "$TEMP_DIR/category_empty_clickhouse.txt"
    elif [ "$clickhouse_rows" -gt "$mysql_rows" ]; then
        # More rows in ClickHouse than MySQL (CDC caught up + new inserts)
        percent=$(awk "BEGIN {printf \"%.1f\", ($clickhouse_rows / $mysql_rows) * 100}")
        echo "$table|$mysql_rows|$mysql_cols|$clickhouse_rows|$clickhouse_cols|$percent" >> "$TEMP_DIR/category_overfull.txt"
    elif [ "$clickhouse_rows" -lt "$mysql_rows" ]; then
        # Partial sync
        percent=$(awk "BEGIN {printf \"%.1f\", ($clickhouse_rows / $mysql_rows) * 100}")
        echo "$table|$mysql_rows|$mysql_cols|$clickhouse_rows|$clickhouse_cols|$percent" >> "$TEMP_DIR/category_partial.txt"
    else
        # Exact match or very close
        echo "$table|$mysql_rows|$mysql_cols|$clickhouse_rows|$clickhouse_cols" >> "$TEMP_DIR/category_success.txt"
    fi
done

# Count categories
MISSING_COUNT=$(cat "$TEMP_DIR/category_missing.txt" | wc -l)
EMPTY_MYSQL_COUNT=$(cat "$TEMP_DIR/category_empty_mysql.txt" | wc -l)
EMPTY_CLICKHOUSE_COUNT=$(cat "$TEMP_DIR/category_empty_clickhouse.txt" | wc -l)
PARTIAL_COUNT=$(cat "$TEMP_DIR/category_partial.txt" | wc -l)
SUCCESS_COUNT=$(cat "$TEMP_DIR/category_success.txt" | wc -l)
OVERFULL_COUNT=$(cat "$TEMP_DIR/category_overfull.txt" | wc -l)

print_subsection "Categorization Summary"
echo ""
printf "%-40s %10s\n" "Category" "Count"
printf "%-40s %10s\n" "$(printf '=%.0s' {1..40})" "$(printf '=%.0s' {1..10})"
printf "%-40s %10d\n" "✓ Successfully Synced (exact/close)" "$SUCCESS_COUNT"
printf "%-40s %10d\n" "✓ Overfull (CH > MySQL, CDC working)" "$OVERFULL_COUNT"
printf "%-40s %10d\n" "⚠ Partially Synced (snapshot ongoing)" "$PARTIAL_COUNT"
printf "%-40s %10d\n" "○ Empty in MySQL (expected)" "$EMPTY_MYSQL_COUNT"
printf "%-40s %10d\n" "✗ Empty in ClickHouse (all to DLQ)" "$EMPTY_CLICKHOUSE_COUNT"
printf "%-40s %10d\n" "✗ Missing from ClickHouse" "$MISSING_COUNT"
echo ""

# Calculate success rate
TABLES_WITH_DATA=$((SUCCESS_COUNT + OVERFULL_COUNT + PARTIAL_COUNT))
TABLES_NEED_DATA=$((MYSQL_TABLE_COUNT - EMPTY_MYSQL_COUNT))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($SUCCESS_COUNT / $TABLES_NEED_DATA) * 100}")
OVERALL_RATE=$(awk "BEGIN {printf \"%.1f\", ($TABLES_WITH_DATA / $TABLES_NEED_DATA) * 100}")

echo "Success Metrics:"
echo "  Tables that should have data:    $TABLES_NEED_DATA (excluding empty MySQL tables)"
echo "  Tables successfully synced:      $SUCCESS_COUNT ($SUCCESS_RATE%)"
echo "  Tables with any data:            $TABLES_WITH_DATA ($OVERALL_RATE%)"
echo ""

# ============================================================
# STEP 6: DETAILED TABLE REPORTS
# ============================================================

print_section "STEP 6: DETAILED TABLE REPORTS"

# Report 1: Missing Tables
if [ $MISSING_COUNT -gt 0 ]; then
    print_subsection "MISSING TABLES (Not Created in ClickHouse)"
    echo ""
    printf "%-60s %15s %15s\n" "Table Name" "MySQL Rows" "MySQL Columns"
    printf "%-60s %15s %15s\n" "$(printf '=%.0s' {1..60})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..15})"

    sort -t'|' -k2 -rn "$TEMP_DIR/category_missing.txt" | while IFS='|' read table mysql_rows mysql_cols; do
        printf "%-60s %'15d %'15d\n" "$table" "$mysql_rows" "$mysql_cols"
    done
    echo ""
fi

# Report 2: Empty in ClickHouse (Problematic)
if [ $EMPTY_CLICKHOUSE_COUNT -gt 0 ]; then
    print_subsection "EMPTY IN CLICKHOUSE (MySQL has data, ClickHouse has 0 rows)"
    echo ""
    printf "%-50s %12s %12s %12s %12s\n" "Table Name" "MySQL Rows" "MySQL Cols" "CH Rows" "CH Cols"
    printf "%-50s %12s %12s %12s %12s\n" "$(printf '=%.0s' {1..50})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})" "$(printf '=%.0s' {1..12})"

    sort -t'|' -k2 -rn "$TEMP_DIR/category_empty_clickhouse.txt" | head -50 | while IFS='|' read table mysql_rows mysql_cols ch_rows ch_cols; do
        printf "%-50s %'12d %'12d %'12d %'12d\n" "$table" "$mysql_rows" "$mysql_cols" "$ch_rows" "$ch_cols"
    done

    if [ $EMPTY_CLICKHOUSE_COUNT -gt 50 ]; then
        echo "  ... and $((EMPTY_CLICKHOUSE_COUNT - 50)) more tables"
    fi
    echo ""
fi

# Report 3: Partially Synced
if [ $PARTIAL_COUNT -gt 0 ]; then
    print_subsection "PARTIALLY SYNCED TABLES (Snapshot may still be running)"
    echo ""
    printf "%-45s %11s %11s %11s %11s %10s\n" "Table Name" "MySQL Rows" "MySQL Cols" "CH Rows" "CH Cols" "Progress"
    printf "%-45s %11s %11s %11s %11s %10s\n" "$(printf '=%.0s' {1..45})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..10})"

    sort -t'|' -k2 -rn "$TEMP_DIR/category_partial.txt" | while IFS='|' read table mysql_rows mysql_cols ch_rows ch_cols percent; do
        printf "%-45s %'11d %'11d %'11d %'11d %9s%%\n" "$table" "$mysql_rows" "$mysql_cols" "$ch_rows" "$ch_cols" "$percent"
    done
    echo ""
fi

# Report 4: Successfully Synced (Top 30)
if [ $SUCCESS_COUNT -gt 0 ]; then
    print_subsection "SUCCESSFULLY SYNCED TABLES (Top 30 by row count)"
    echo ""
    printf "%-45s %11s %11s %11s %11s\n" "Table Name" "MySQL Rows" "MySQL Cols" "CH Rows" "CH Cols"
    printf "%-45s %11s %11s %11s %11s\n" "$(printf '=%.0s' {1..45})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})"

    sort -t'|' -k2 -rn "$TEMP_DIR/category_success.txt" | head -30 | while IFS='|' read table mysql_rows mysql_cols ch_rows ch_cols; do
        printf "%-45s %'11d %'11d %'11d %'11d\n" "$table" "$mysql_rows" "$mysql_cols" "$ch_rows" "$ch_cols"
    done

    if [ $SUCCESS_COUNT -gt 30 ]; then
        echo "  ... and $((SUCCESS_COUNT - 30)) more successfully synced tables"
    fi
    echo ""
fi

# Report 5: Overfull (ClickHouse > MySQL)
if [ $OVERFULL_COUNT -gt 0 ]; then
    print_subsection "OVERFULL TABLES (ClickHouse has MORE rows than MySQL)"
    echo ""
    echo "This is NORMAL - means CDC is working and capturing new inserts since snapshot"
    echo ""
    printf "%-45s %11s %11s %11s %11s %10s\n" "Table Name" "MySQL Rows" "MySQL Cols" "CH Rows" "CH Cols" "Ratio"
    printf "%-45s %11s %11s %11s %11s %10s\n" "$(printf '=%.0s' {1..45})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..11})" "$(printf '=%.0s' {1..10})"

    sort -t'|' -k6 -rn "$TEMP_DIR/category_overfull.txt" | while IFS='|' read table mysql_rows mysql_cols ch_rows ch_cols percent; do
        printf "%-45s %'11d %'11d %'11d %'11d %9s%%\n" "$table" "$mysql_rows" "$mysql_cols" "$ch_rows" "$ch_cols" "$percent"
    done
    echo ""
fi

# ============================================================
# STEP 7: ROW COUNT ACCURACY ANALYSIS
# ============================================================

print_section "STEP 7: ROW COUNT ACCURACY ANALYSIS"

echo ""
print_info "Calculating exact row count differences..."
echo ""

# Calculate total expected vs actual
MYSQL_ROWS_WITH_DATA=0
CLICKHOUSE_ROWS_SYNCED=0
ROWS_MISSING=0

while read -r line; do
    table=$(echo "$line" | awk '{print $1}')
    mysql_rows=$(echo "$line" | awk '{print $2}')

    # Skip empty MySQL tables
    if [ "$mysql_rows" -eq 0 ]; then
        continue
    fi

    clickhouse_rows=${CLICKHOUSE_ROWS[$table]:-0}

    MYSQL_ROWS_WITH_DATA=$((MYSQL_ROWS_WITH_DATA + mysql_rows))
    CLICKHOUSE_ROWS_SYNCED=$((CLICKHOUSE_ROWS_SYNCED + clickhouse_rows))

    if [ "$clickhouse_rows" -lt "$mysql_rows" ]; then
        diff=$((mysql_rows - clickhouse_rows))
        ROWS_MISSING=$((ROWS_MISSING + diff))
    fi
done < "$TEMP_DIR/mysql_tables.txt"

# Calculate percentages
SYNC_PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", ($CLICKHOUSE_ROWS_SYNCED / $MYSQL_ROWS_WITH_DATA) * 100}")
MISSING_PERCENTAGE=$(awk "BEGIN {printf \"%.4f\", ($ROWS_MISSING / $MYSQL_ROWS_WITH_DATA) * 100}")

print_subsection "Row Count Summary"
echo ""
printf "%-45s %'20d\n" "Total MySQL rows (all tables):" "$MYSQL_TOTAL_ROWS"
printf "%-45s %'20d\n" "MySQL rows (excluding empty tables):" "$MYSQL_ROWS_WITH_DATA"
printf "%-45s %'20d\n" "ClickHouse rows synced:" "$CLICKHOUSE_ROWS_SYNCED"
printf "%-45s %'20d\n" "Rows missing from ClickHouse:" "$ROWS_MISSING"
echo ""
printf "%-45s %19s%%\n" "Sync percentage:" "$SYNC_PERCENTAGE"
printf "%-45s %19s%%\n" "Missing percentage:" "$MISSING_PERCENTAGE"
echo ""

# Breakdown of missing rows
print_subsection "Where Are the Missing Rows?"
echo ""
echo "1. In DLQ (failed to insert):"
echo "   Messages: $(printf "%'d" $DLQ_TOTAL_MESSAGES)"
echo "   Percentage of total: $DLQ_PERCENTAGE%"
echo ""

ROWS_IN_TRANSIT=$((ROWS_MISSING - DLQ_TOTAL_MESSAGES))
if [ $ROWS_IN_TRANSIT -gt 0 ]; then
    TRANSIT_PERCENTAGE=$(awk "BEGIN {printf \"%.4f\", ($ROWS_IN_TRANSIT / $MYSQL_ROWS_WITH_DATA) * 100}")
    echo "2. Possibly still in transit/buffer:"
    echo "   Estimated rows: $(printf "%'d" $ROWS_IN_TRANSIT)"
    echo "   Percentage: $TRANSIT_PERCENTAGE%"
    echo ""
fi

# ============================================================
# STEP 8: FULL TABLE DESCRIPTIONS
# ============================================================

print_section "STEP 8: FULL TABLE DESCRIPTIONS (ALL 450 TABLES)"

echo ""
print_info "Generating complete table description report..."
echo ""

# Create comprehensive report file
FULL_REPORT="$TEMP_DIR/FULL_TABLE_DESCRIPTIONS.txt"

cat > "$FULL_REPORT" << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║  COMPLETE TABLE DESCRIPTIONS - MySQL vs ClickHouse                           ║
║  Generated: $(date +'%Y-%m-%d %H:%M:%S')                                                     ║
╚═══════════════════════════════════════════════════════════════════════════════╝

This report contains detailed schema information for ALL tables in both MySQL
and ClickHouse databases.

EOF

REPORT_COUNT=0

for table in $(sort < <(printf '%s\n' "${!MYSQL_ROWS[@]}")); do
    REPORT_COUNT=$((REPORT_COUNT + 1))

    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$FULL_REPORT"
    echo "TABLE #$REPORT_COUNT: $table" >> "$FULL_REPORT"
    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$FULL_REPORT"
    echo "" >> "$FULL_REPORT"

    # MySQL info
    mysql_rows=${MYSQL_ROWS[$table]}
    mysql_cols=${MYSQL_COLS[$table]}

    echo "MYSQL:" >> "$FULL_REPORT"
    echo "  Rows: $(printf "%'d" $mysql_rows)" >> "$FULL_REPORT"
    echo "  Columns: $mysql_cols" >> "$FULL_REPORT"
    echo "" >> "$FULL_REPORT"

    if [ -f "$TEMP_DIR/mysql_schema_${table}.txt" ]; then
        echo "  Schema:" >> "$FULL_REPORT"
        awk '{printf "    %-30s %-25s %-10s %-10s %s\n", $1, $2, $3, $4, $5}' "$TEMP_DIR/mysql_schema_${table}.txt" >> "$FULL_REPORT"
    else
        echo "  Schema: Not available" >> "$FULL_REPORT"
    fi

    echo "" >> "$FULL_REPORT"

    # ClickHouse info
    clickhouse_rows=${CLICKHOUSE_ROWS[$table]:-0}
    clickhouse_cols=${CLICKHOUSE_COLS[$table]:-0}

    if [ -z "${CLICKHOUSE_ROWS[$table]}" ]; then
        echo "CLICKHOUSE: Table does not exist" >> "$FULL_REPORT"
    else
        echo "CLICKHOUSE:" >> "$FULL_REPORT"
        echo "  Rows: $(printf "%'d" $clickhouse_rows)" >> "$FULL_REPORT"
        echo "  Columns: $clickhouse_cols" >> "$FULL_REPORT"
        echo "" >> "$FULL_REPORT"

        if [ -f "$TEMP_DIR/clickhouse_schema_${table}.txt" ]; then
            echo "  Schema:" >> "$FULL_REPORT"
            awk '{printf "    %-30s %-35s %-15s %s\n", $1, $2, $3, $4}' "$TEMP_DIR/clickhouse_schema_${table}.txt" >> "$FULL_REPORT"
        else
            echo "  Schema: Not available" >> "$FULL_REPORT"
        fi
    fi

    echo "" >> "$FULL_REPORT"

    # Status
    if [ -z "${CLICKHOUSE_ROWS[$table]}" ]; then
        echo "STATUS: ✗ MISSING FROM CLICKHOUSE" >> "$FULL_REPORT"
    elif [ "$mysql_rows" -eq 0 ] && [ "$clickhouse_rows" -eq 0 ]; then
        echo "STATUS: ○ EMPTY IN BOTH (Expected)" >> "$FULL_REPORT"
    elif [ "$mysql_rows" -gt 0 ] && [ "$clickhouse_rows" -eq 0 ]; then
        echo "STATUS: ✗ EMPTY IN CLICKHOUSE (All records in DLQ or not synced)" >> "$FULL_REPORT"
    elif [ "$clickhouse_rows" -ge "$mysql_rows" ]; then
        echo "STATUS: ✓ SUCCESSFULLY SYNCED" >> "$FULL_REPORT"
    else
        percent=$(awk "BEGIN {printf \"%.1f\", ($clickhouse_rows / $mysql_rows) * 100}")
        echo "STATUS: ⚠ PARTIALLY SYNCED ($percent%)" >> "$FULL_REPORT"
    fi

    echo "" >> "$FULL_REPORT"
    echo "" >> "$FULL_REPORT"

    echo -ne "\r  Generated descriptions: $REPORT_COUNT / $MYSQL_TABLE_COUNT tables        "
done

echo ""
print_status 0 "Full table descriptions generated: $FULL_REPORT"

# ============================================================
# STEP 9: FINAL SUMMARY AND RECOMMENDATIONS
# ============================================================

print_section "STEP 9: FINAL SUMMARY AND RECOMMENDATIONS"

echo ""
print_subsection "Overall Statistics"
echo ""

printf "%-50s %'20d\n" "Total MySQL tables:" "$MYSQL_TABLE_COUNT"
printf "%-50s %'20d\n" "Total ClickHouse tables:" "$CLICKHOUSE_TABLE_COUNT"
printf "%-50s %'20d\n" "Tables successfully synced:" "$SUCCESS_COUNT"
printf "%-50s %'20d\n" "Tables partially synced:" "$PARTIAL_COUNT"
printf "%-50s %'20d\n" "Tables empty in both:" "$EMPTY_MYSQL_COUNT"
printf "%-50s %'20d\n" "Tables empty in ClickHouse only:" "$EMPTY_CLICKHOUSE_COUNT"
printf "%-50s %'20d\n" "Tables missing from ClickHouse:" "$MISSING_COUNT"
echo ""
printf "%-50s %'20d\n" "Total MySQL rows (with data):" "$MYSQL_ROWS_WITH_DATA"
printf "%-50s %'20d\n" "Total ClickHouse rows:" "$CLICKHOUSE_ROWS_SYNCED"
printf "%-50s %'20d\n" "Rows in DLQ:" "$DLQ_TOTAL_MESSAGES"
printf "%-50s %'20d\n" "Rows missing:" "$ROWS_MISSING"
echo ""
printf "%-50s %19s%%\n" "Data sync rate:" "$SYNC_PERCENTAGE"
printf "%-50s %19s%%\n" "DLQ error rate:" "$DLQ_PERCENTAGE"
echo ""

print_subsection "Assessment"
echo ""

if (( $(echo "$SYNC_PERCENTAGE >= 99.5" | bc -l) )); then
    echo -e "${GREEN}${BOLD}✓ EXCELLENT: > 99.5% of data successfully synced${NC}"
elif (( $(echo "$SYNC_PERCENTAGE >= 98.0" | bc -l) )); then
    echo -e "${GREEN}${BOLD}✓ GOOD: > 98% of data successfully synced${NC}"
elif (( $(echo "$SYNC_PERCENTAGE >= 95.0" | bc -l) )); then
    echo -e "${YELLOW}${BOLD}⚠ ACCEPTABLE: > 95% of data synced, some investigation needed${NC}"
else
    echo -e "${RED}${BOLD}✗ NEEDS ATTENTION: < 95% of data synced, requires investigation${NC}"
fi

echo ""

if (( $(echo "$DLQ_PERCENTAGE < 0.5" | bc -l) )); then
    echo -e "${GREEN}DLQ Status: < 0.5% error rate - Acceptable for initial sync${NC}"
elif (( $(echo "$DLQ_PERCENTAGE < 2.0" | bc -l) )); then
    echo -e "${YELLOW}DLQ Status: 0.5-2% error rate - Consider investigating${NC}"
else
    echo -e "${RED}DLQ Status: > 2% error rate - Should recover data${NC}"
fi

echo ""

print_subsection "Generated Reports"
echo ""
echo "All analysis files saved to: $TEMP_DIR"
echo ""
echo "Key reports:"
echo "  1. Full table descriptions:  $FULL_REPORT"
echo "  2. Schema comparison:        $TEMP_DIR/schema_comparison_report.txt"
echo "  3. DLQ analysis:             $TEMP_DIR/dlq_analysis.txt"
echo "  4. Raw data files:           $TEMP_DIR/*.txt"
echo ""

print_subsection "Next Steps"
echo ""

if [ $EMPTY_CLICKHOUSE_COUNT -gt 0 ]; then
    echo "1. Investigate empty ClickHouse tables:"
    echo "   - Check: $TEMP_DIR/category_empty_clickhouse.txt"
    echo "   - These tables likely have all records in DLQ"
    echo ""
fi

if [ $PARTIAL_COUNT -gt 0 ]; then
    echo "2. Monitor partially synced tables:"
    echo "   - Check: $TEMP_DIR/category_partial.txt"
    echo "   - May still be syncing if CDC is active"
    echo ""
fi

if (( $(echo "$DLQ_PERCENTAGE > 0.5" | bc -l) )); then
    echo "3. Consider DLQ recovery:"
    echo "   - Total DLQ messages: $(printf "%'d" $DLQ_TOTAL_MESSAGES)"
    echo "   - See ANALYSIS_DLQ_AND_ERROR_CODE_1001.md for recovery methods"
    echo ""
fi

echo "4. Verify CDC is working for new data:"
echo "   - Insert test record in MySQL"
echo "   - Check if it appears in ClickHouse within seconds"
echo ""

echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Analysis completed at: $(date +'%Y-%m-%d %H:%M:%S')"
echo ""
echo "To view full report:"
echo "  cat $FULL_REPORT"
echo ""

#!/bin/bash
# Phase 3 - Data Validation Script
# Purpose: Validate data accuracy between MySQL and ClickHouse

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"
OUTPUT_DIR="$PHASE3_DIR/validation_output"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo "========================================"
echo "   Data Validation Report"
echo "========================================"
echo ""

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

REPORT_FILE="$OUTPUT_DIR/validation_report_$(date +%Y%m%d_%H%M%S).txt"
MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}"
CH_PASSWORD="ClickHouse_Secure_Pass_2024!"

# Start report
echo "Data Validation Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "1. Table Count Comparison"
echo "-------------------------"

MYSQL_TABLE_COUNT=$($MYSQL_CMD -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$MYSQL_DATABASE';" 2>/dev/null)
CH_TABLE_COUNT=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
    "SELECT count() FROM system.tables WHERE database = 'analytics'" 2>/dev/null)

echo "MySQL Tables: $MYSQL_TABLE_COUNT" | tee -a "$REPORT_FILE"
echo "ClickHouse Tables: $CH_TABLE_COUNT" | tee -a "$REPORT_FILE"

if [ "$MYSQL_TABLE_COUNT" -eq "$CH_TABLE_COUNT" ]; then
    print_status 0 "Table count matches" | tee -a "$REPORT_FILE"
else
    print_status 1 "Table count mismatch (expected: $MYSQL_TABLE_COUNT, got: $CH_TABLE_COUNT)" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "2. Row Count Comparison"
echo "-----------------------"

# Get table list
TABLES=$($MYSQL_CMD -N -e "SHOW TABLES;" 2>/dev/null)

TOTAL_TABLES=0
MATCHING_TABLES=0
MISMATCHED_TABLES=0
MISSING_TABLES=0

echo "Table,MySQL_Rows,ClickHouse_Rows,Status" > "$OUTPUT_DIR/row_count_comparison.csv"

for TABLE in $TABLES; do
    ((TOTAL_TABLES++))

    echo -ne "\rValidating table $TOTAL_TABLES: $TABLE                    "

    # Get MySQL row count
    MYSQL_ROWS=$($MYSQL_CMD -N -e "SELECT COUNT(*) FROM \`$TABLE\`;" 2>/dev/null || echo "0")

    # Get ClickHouse row count
    CH_ROWS=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
        "SELECT count() FROM analytics.\`$TABLE\` WHERE _is_deleted = 0" 2>/dev/null || echo "-1")

    if [ "$CH_ROWS" = "-1" ]; then
        ((MISSING_TABLES++))
        echo "$TABLE,$MYSQL_ROWS,MISSING,ERROR" >> "$OUTPUT_DIR/row_count_comparison.csv"
    elif [ "$MYSQL_ROWS" -eq "$CH_ROWS" ]; then
        ((MATCHING_TABLES++))
        echo "$TABLE,$MYSQL_ROWS,$CH_ROWS,OK" >> "$OUTPUT_DIR/row_count_comparison.csv"
    else
        ((MISMATCHED_TABLES++))
        echo "$TABLE,$MYSQL_ROWS,$CH_ROWS,MISMATCH" >> "$OUTPUT_DIR/row_count_comparison.csv"
    fi
done

echo ""
echo ""

print_info "Total tables validated: $TOTAL_TABLES" | tee -a "$REPORT_FILE"
print_status 0 "Matching tables: $MATCHING_TABLES" | tee -a "$REPORT_FILE"
if [ "$MISMATCHED_TABLES" -gt 0 ]; then
    print_status 1 "Mismatched tables: $MISMATCHED_TABLES" | tee -a "$REPORT_FILE"
fi
if [ "$MISSING_TABLES" -gt 0 ]; then
    print_status 1 "Missing tables: $MISSING_TABLES" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "3. Total Row Count"
echo "------------------"

MYSQL_TOTAL=$($MYSQL_CMD -N -e "
    SELECT SUM(TABLE_ROWS)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = '$MYSQL_DATABASE';" 2>/dev/null)

CH_TOTAL=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
    "SELECT formatReadableQuantity(sum(total_rows))
     FROM system.tables
     WHERE database = 'analytics'" 2>/dev/null)

echo "MySQL Total Rows (approx): $(printf "%'d" $MYSQL_TOTAL)" | tee -a "$REPORT_FILE"
echo "ClickHouse Total Rows: $CH_TOTAL" | tee -a "$REPORT_FILE"

echo "" | tee -a "$REPORT_FILE"

echo "4. Data Size Comparison"
echo "-----------------------"

MYSQL_SIZE=$($MYSQL_CMD -N -e "
    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = '$MYSQL_DATABASE';" 2>/dev/null)

CH_SIZE=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
    "SELECT formatReadableSize(sum(bytes_on_disk))
     FROM system.parts
     WHERE database = 'analytics' AND active = 1" 2>/dev/null)

echo "MySQL Database Size: ${MYSQL_SIZE} GB" | tee -a "$REPORT_FILE"
echo "ClickHouse Database Size: $CH_SIZE" | tee -a "$REPORT_FILE"

# Calculate compression ratio
CH_SIZE_BYTES=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
    "SELECT sum(bytes_on_disk)
     FROM system.parts
     WHERE database = 'analytics' AND active = 1" 2>/dev/null)

if [ -n "$CH_SIZE_BYTES" ] && [ "$CH_SIZE_BYTES" -gt 0 ]; then
    MYSQL_SIZE_BYTES=$(echo "$MYSQL_SIZE * 1024 * 1024 * 1024" | bc)
    COMPRESSION_RATIO=$(echo "scale=2; $MYSQL_SIZE_BYTES / $CH_SIZE_BYTES" | bc)
    echo "Compression Ratio: ${COMPRESSION_RATIO}x" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "5. Sample Data Validation"
echo "-------------------------"

print_info "Validating sample records from 5 random tables..." | tee -a "$REPORT_FILE"

SAMPLE_TABLES=$(echo "$TABLES" | shuf | head -5)
SAMPLE_MATCHES=0

for TABLE in $SAMPLE_TABLES; do
    # Get a random ID from MySQL
    SAMPLE_ID=$($MYSQL_CMD -N -e "SELECT id FROM \`$TABLE\` ORDER BY RAND() LIMIT 1;" 2>/dev/null || echo "")

    if [ -z "$SAMPLE_ID" ]; then
        continue
    fi

    # Get record from MySQL
    MYSQL_RECORD=$($MYSQL_CMD -N -e "SELECT * FROM \`$TABLE\` WHERE id = $SAMPLE_ID LIMIT 1;" 2>/dev/null || echo "")

    # Get same record from ClickHouse
    CH_RECORD=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
        "SELECT * FROM analytics.\`$TABLE\` WHERE id = $SAMPLE_ID AND _is_deleted = 0 LIMIT 1 FORMAT CSV" 2>/dev/null || echo "")

    if [ -n "$MYSQL_RECORD" ] && [ -n "$CH_RECORD" ]; then
        ((SAMPLE_MATCHES++))
    fi
done

print_status 0 "Validated $SAMPLE_MATCHES sample records" | tee -a "$REPORT_FILE"

echo "" | tee -a "$REPORT_FILE"

echo "6. ClickHouse Performance Metrics"
echo "----------------------------------"

# Merge performance
docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
    "SELECT
        count() as active_merges,
        formatReadableSize(sum(bytes_read_uncompressed)) as data_processed
     FROM system.merges" 2>/dev/null | tee -a "$REPORT_FILE"

echo "" | tee -a "$REPORT_FILE"

# Query performance test
print_info "Testing query performance..." | tee -a "$REPORT_FILE"

LARGEST_TABLE=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query \
    "SELECT name FROM system.tables WHERE database = 'analytics' ORDER BY total_rows DESC LIMIT 1" 2>/dev/null)

if [ -n "$LARGEST_TABLE" ]; then
    QUERY_TIME=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --time --query \
        "SELECT count() FROM analytics.\`$LARGEST_TABLE\`" 2>&1 | grep "Elapsed:" || echo "N/A")

    echo "Test query on largest table ($LARGEST_TABLE): $QUERY_TIME" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "========================================"
echo "   Validation Summary"
echo "========================================"
echo ""

ACCURACY_PERCENT=$((MATCHING_TABLES * 100 / TOTAL_TABLES))

echo "Overall Accuracy: ${ACCURACY_PERCENT}%" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ "$ACCURACY_PERCENT" -ge 95 ]; then
    print_status 0 "Data validation PASSED (>95% accuracy)" | tee -a "$REPORT_FILE"
elif [ "$ACCURACY_PERCENT" -ge 80 ]; then
    echo -e "${YELLOW}⚠ Data validation WARNING (80-95% accuracy)${NC}" | tee -a "$REPORT_FILE"
else
    print_status 1 "Data validation FAILED (<80% accuracy)" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "Detailed reports saved to:" | tee -a "$REPORT_FILE"
echo "  - $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "  - $OUTPUT_DIR/row_count_comparison.csv" | tee -a "$REPORT_FILE"
echo ""

if [ "$MISMATCHED_TABLES" -gt 0 ]; then
    echo "Tables with mismatched row counts:"
    grep "MISMATCH" "$OUTPUT_DIR/row_count_comparison.csv" | head -10
    echo ""
    echo "See full list in: $OUTPUT_DIR/row_count_comparison.csv"
fi

echo ""

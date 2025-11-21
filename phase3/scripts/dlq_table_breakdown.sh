#!/bin/bash
# DLQ Table Breakdown Script
# Analyzes DLQ messages and shows breakdown by table with error details

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  DLQ TABLE BREAKDOWN ANALYSIS                                     ║"
echo "║  Detailed analysis of which tables have DLQ errors                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
DLQ_TOPIC="clickhouse-dlq"
SAMPLE_SIZE=${1:-20000}  # Default to 20k messages, can be overridden
TEMP_DIR="/tmp/dlq_table_breakdown_$$"
mkdir -p "$TEMP_DIR"

echo "Configuration:"
echo "  DLQ Topic: $DLQ_TOPIC"
echo "  Sample Size: $(printf "%'d" $SAMPLE_SIZE) messages"
echo ""

# ============================================================================
# STEP 1: GET DLQ SIZE
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "STEP 1: DLQ Overview"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

DLQ_INFO=$(docker exec redpanda-clickhouse rpk topic describe "$DLQ_TOPIC" --brokers localhost:9092 2>&1)

if echo "$DLQ_INFO" | grep -q "not found\|does not exist"; then
    echo -e "${GREEN}✓ No DLQ topic found - All records synced successfully!${NC}"
    exit 0
fi

# Get total messages
TOTAL_MESSAGES=$(echo "$DLQ_INFO" | grep -E "^[0-9]" | awk '{sum+=$2}END{print sum}')
echo "Total DLQ Messages: $(printf "%'d" ${TOTAL_MESSAGES:-0})"

# Get size
DLQ_SIZE=$(docker exec redpanda-clickhouse du -sh /var/lib/redpanda/data/kafka/"$DLQ_TOPIC" 2>/dev/null | awk '{print $1}')
echo "DLQ Disk Usage: ${DLQ_SIZE:-Unknown}"

echo ""

# ============================================================================
# STEP 2: CONSUME AND PARSE DLQ MESSAGES
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "STEP 2: Consuming DLQ Messages for Analysis"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

echo "Consuming $SAMPLE_SIZE messages from DLQ..."
echo "(This may take several minutes for large DLQ)"
echo ""

DLQ_MESSAGES="$TEMP_DIR/dlq_messages.json"

# Consume messages with timeout
timeout 300 docker exec redpanda-clickhouse rpk topic consume "$DLQ_TOPIC" \
    --brokers localhost:9092 \
    --num "$SAMPLE_SIZE" \
    --format '%v\n' \
    > "$DLQ_MESSAGES" 2>&1 &

CONSUME_PID=$!

# Progress indicator
for i in {1..60}; do
    if ! ps -p $CONSUME_PID > /dev/null 2>&1; then
        break
    fi

    LINES=$(wc -l < "$DLQ_MESSAGES" 2>/dev/null || echo "0")
    printf "\r  Consumed: %'d messages..." "$LINES"
    sleep 2
done

wait $CONSUME_PID 2>/dev/null
ACTUAL_CONSUMED=$(wc -l < "$DLQ_MESSAGES" 2>/dev/null || echo "0")
printf "\r  Consumed: %'d messages - Complete!     \n" "$ACTUAL_CONSUMED"
echo ""

if [ "$ACTUAL_CONSUMED" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No messages consumed from DLQ${NC}"
    exit 0
fi

# ============================================================================
# STEP 3: EXTRACT TABLE NAMES
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "STEP 3: Extracting Table Names from Messages"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Try multiple parsing strategies to extract table names
TABLES_FILE="$TEMP_DIR/tables.txt"

# Strategy 1: Look for "table": "tablename" in JSON
grep -oP '"table"\s*:\s*"\K[^"]+' "$DLQ_MESSAGES" >> "$TABLES_FILE" 2>/dev/null

# Strategy 2: Look for sakila.tablename patterns
grep -oP 'sakila\.\K\w+' "$DLQ_MESSAGES" >> "$TABLES_FILE" 2>/dev/null

# Strategy 3: Look for dbserver1.sakila.tablename
grep -oP 'dbserver1\.sakila\.\K\w+' "$DLQ_MESSAGES" >> "$TABLES_FILE" 2>/dev/null

# Strategy 4: Look for source.table patterns
grep -oP '"source"\s*:\s*{[^}]*"table"\s*:\s*"\K[^"]+' "$DLQ_MESSAGES" >> "$TABLES_FILE" 2>/dev/null

if [ ! -s "$TABLES_FILE" ]; then
    echo -e "${YELLOW}⚠ Could not extract table names from DLQ messages${NC}"
    echo ""
    echo "Sample DLQ message structure:"
    head -5 "$DLQ_MESSAGES" | head -c 500
    echo ""
    echo "..."
    exit 1
fi

# Count errors per table
TABLE_ERROR_COUNTS=$(sort "$TABLES_FILE" | uniq -c | sort -rn)
UNIQUE_TABLES=$(echo "$TABLE_ERROR_COUNTS" | wc -l)

echo "Found errors in $UNIQUE_TABLES unique tables"
echo ""

# ============================================================================
# STEP 4: TABLE ERROR BREAKDOWN
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "STEP 4: Table Error Breakdown"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

echo "DLQ Errors by Table (from $ACTUAL_CONSUMED message sample):"
echo "───────────────────────────────────────────────────────────────────"
printf "%-10s %-40s %-15s\n" "ERRORS" "TABLE NAME" "PERCENTAGE"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_ERRORS=$(echo "$TABLE_ERROR_COUNTS" | awk '{sum+=$1}END{print sum}')

echo "$TABLE_ERROR_COUNTS" | head -50 | while read count table; do
    PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", ($count / $TOTAL_ERRORS) * 100}")
    printf "%-10s %-40s %13s%%\n" "$count" "$table" "$PERCENTAGE"
done

echo "───────────────────────────────────────────────────────────────────"
echo ""

if [ "$UNIQUE_TABLES" -gt 50 ]; then
    echo "(Showing top 50 tables, total affected: $UNIQUE_TABLES)"
    echo ""
fi

# ============================================================================
# STEP 5: ERROR TYPE ANALYSIS PER TABLE
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "STEP 5: Error Types by Table (Top 10 Tables)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Analyze top 10 tables with most errors
TOP_10_TABLES=$(echo "$TABLE_ERROR_COUNTS" | head -10 | awk '{print $2}')

for table in $TOP_10_TABLES; do
    echo "───────────────────────────────────────────────────────────────────"
    echo -e "${BOLD}Table: $table${NC}"
    echo "───────────────────────────────────────────────────────────────────"

    # Extract error codes for this table
    ERROR_CODES=$(grep -B2 -A2 "\"$table\"" "$DLQ_MESSAGES" | \
        grep -oP 'Code:\s*\K\d+' | \
        sort | uniq -c | sort -rn)

    if [ -n "$ERROR_CODES" ]; then
        echo "Error Codes:"
        while read count code; do
            case $code in
                1001) desc="Generic exception (std::exception)" ;;
                60) desc="Database does not exist" ;;
                81) desc="Database already exists" ;;
                16) desc="Table does not exist" ;;
                44) desc="Cannot insert NULL" ;;
                6) desc="Cannot parse data" ;;
                27) desc="Type mismatch" ;;
                252) desc="Too many parts" ;;
                *) desc="Unknown error" ;;
            esac
            printf "  Code %-6s: %-4s occurrences - %s\n" "$code" "$count" "$desc"
        done <<< "$ERROR_CODES"
    else
        echo "  (No error codes found in sample)"
    fi

    # Sample error message for this table
    echo ""
    echo "Sample Error Message:"
    grep -B2 -A5 "\"$table\"" "$DLQ_MESSAGES" | \
        grep -oP '(exception|Exception|error|Error)[^}]*' | \
        head -1 | \
        sed 's/^/  /' | \
        head -c 500
    echo ""
    echo ""
done

# ============================================================================
# STEP 6: RECOMMENDATIONS BY TABLE
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "STEP 6: Recommended Actions"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

echo "Based on analysis of $(printf "%'d" $ACTUAL_CONSUMED) DLQ messages:"
echo ""

# Top 3 tables
echo "Top 3 Tables to Investigate:"
echo ""
TOP_3=$(echo "$TABLE_ERROR_COUNTS" | head -3)

RANK=1
echo "$TOP_3" | while read count table; do
    echo "${RANK}. ${BOLD}${table}${NC} - $(printf "%'d" $count) errors"
    echo ""
    echo "   Recommended actions:"
    echo "   - Compare schemas:"
    echo "     docker exec mysql-clickhouse mysql -u root -p\$MYSQL_PASSWORD sakila -e \"DESCRIBE $table\""
    echo "     docker exec clickhouse-server clickhouse-client --password \$CLICKHOUSE_PASSWORD --query \"DESCRIBE sakila.$table\""
    echo ""
    echo "   - Check sample data in MySQL:"
    echo "     docker exec mysql-clickhouse mysql -u root -p\$MYSQL_PASSWORD sakila -e \"SELECT * FROM $table LIMIT 5\""
    echo ""
    echo "   - Check if table exists in ClickHouse:"
    echo "     docker exec clickhouse-server clickhouse-client --password \$CLICKHOUSE_PASSWORD --query \"SELECT count() FROM sakila.$table\""
    echo ""

    RANK=$((RANK + 1))
done

# ============================================================================
# STEP 7: EXTRAPOLATION TO TOTAL DLQ
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "STEP 7: Extrapolation to Total DLQ Size"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

if [ "$TOTAL_MESSAGES" -gt "$ACTUAL_CONSUMED" ]; then
    echo "Sample Size: $(printf "%'d" $ACTUAL_CONSUMED) messages"
    echo "Total DLQ Size: $(printf "%'d" $TOTAL_MESSAGES) messages"
    echo ""

    SAMPLE_RATIO=$(awk "BEGIN {printf \"%.4f\", $ACTUAL_CONSUMED / $TOTAL_MESSAGES}")
    echo "Sample represents: $(awk "BEGIN {printf \"%.2f\", $SAMPLE_RATIO * 100}")% of total DLQ"
    echo ""

    echo "Extrapolated Total Errors by Table (estimate):"
    echo "───────────────────────────────────────────────────────────────────"
    printf "%-15s %-40s\n" "ESTIMATED ERRORS" "TABLE NAME"
    echo "───────────────────────────────────────────────────────────────────"

    echo "$TABLE_ERROR_COUNTS" | head -20 | while read count table; do
        EXTRAPOLATED=$(awk "BEGIN {printf \"%.0f\", $count / $SAMPLE_RATIO}")
        printf "%-15s %-40s\n" "$(printf "%'d" $EXTRAPOLATED)" "$table"
    done

    echo "───────────────────────────────────────────────────────────────────"
    echo ""
    echo "(These are estimates based on sample. Actual numbers may vary.)"
else
    echo "Analyzed entire DLQ (sample size >= total messages)"
fi

echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

echo "DLQ Statistics:"
echo "  Total DLQ Messages: $(printf "%'d" ${TOTAL_MESSAGES:-0})"
echo "  Messages Analyzed: $(printf "%'d" $ACTUAL_CONSUMED)"
echo "  Unique Tables Affected: $UNIQUE_TABLES"
echo "  DLQ Disk Usage: ${DLQ_SIZE:-Unknown}"
echo ""

# Calculate impact
if [ "$TOTAL_MESSAGES" -gt 0 ]; then
    echo "Impact Assessment:"

    if [ "$UNIQUE_TABLES" -lt 5 ]; then
        echo -e "  ${GREEN}✓ Low Impact${NC} - Only $UNIQUE_TABLES tables affected"
    elif [ "$UNIQUE_TABLES" -lt 20 ]; then
        echo -e "  ${YELLOW}⚠ Medium Impact${NC} - $UNIQUE_TABLES tables affected"
    else
        echo -e "  ${RED}✗ High Impact${NC} - $UNIQUE_TABLES tables affected"
    fi
fi

echo ""
echo "Next Steps:"
echo "  1. Investigate top 3 tables with most errors"
echo "  2. Compare MySQL and ClickHouse schemas"
echo "  3. Fix schema mismatches or data type issues"
echo "  4. Consider replaying DLQ after fixes (if needed)"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

echo "Analysis complete!"
echo ""
echo "To analyze more messages, run:"
echo "  ./dlq_table_breakdown.sh 50000  # Analyze 50k messages"
echo ""

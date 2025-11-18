#!/bin/bash
# Phase 4 - Data Quality Validation Script
# Purpose: Validate data quality and consistency between MySQL and ClickHouse

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(dirname "$SCRIPT_DIR")"
PHASE3_DIR="$(dirname "$PHASE4_DIR")/phase3"
CONFIG_DIR="$PHASE3_DIR/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

CLICKHOUSE_URL="http://localhost:8123"

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "========================================"
echo "   Data Quality Validation"
echo "========================================"
echo ""

# 1. Check row count consistency
echo "1. Row Count Validation"
echo "-----------------------"

# Get all tables
TABLES=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -D "$MYSQL_DATABASE" -N -e "SHOW TABLES" 2>/dev/null)

TOTAL_TABLES=0
MATCHED_TABLES=0
MISMATCHED_TABLES=0
MISSING_TABLES=0

for table in $TABLES; do
    TOTAL_TABLES=$((TOTAL_TABLES + 1))

    # Get MySQL count
    MYSQL_COUNT=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -D "$MYSQL_DATABASE" -N -e "SELECT COUNT(*) FROM \`$table\`" 2>/dev/null || echo "0")

    # Get ClickHouse count
    CH_COUNT=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
        --data-binary "SELECT COUNT(*) FROM $CLICKHOUSE_DATABASE.\`$table\`" 2>/dev/null || echo "0")

    # Check if table exists in ClickHouse
    if [ "$CH_COUNT" = "0" ] && [ "$MYSQL_COUNT" != "0" ]; then
        TABLE_EXISTS=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
            --data-binary "SELECT count() FROM system.tables WHERE database = '$CLICKHOUSE_DATABASE' AND name = '$table'" 2>/dev/null)

        if [ "$TABLE_EXISTS" = "0" ]; then
            echo -e "  ${RED}✗${NC} $table: Missing in ClickHouse (MySQL: $MYSQL_COUNT rows)"
            MISSING_TABLES=$((MISSING_TABLES + 1))
            continue
        fi
    fi

    # Calculate difference
    DIFF=$((MYSQL_COUNT - CH_COUNT))
    DIFF_ABS=${DIFF#-}  # Absolute value

    if [ $MYSQL_COUNT -gt 0 ]; then
        DIFF_PERCENT=$((DIFF_ABS * 100 / MYSQL_COUNT))
    else
        DIFF_PERCENT=0
    fi

    if [ $DIFF_ABS -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $table: $MYSQL_COUNT rows (✓ matched)"
        MATCHED_TABLES=$((MATCHED_TABLES + 1))
    elif [ $DIFF_PERCENT -lt 1 ]; then
        echo -e "  ${YELLOW}⚠${NC} $table: MySQL=$MYSQL_COUNT, ClickHouse=$CH_COUNT (diff: $DIFF)"
        MISMATCHED_TABLES=$((MISMATCHED_TABLES + 1))
    else
        echo -e "  ${RED}✗${NC} $table: MySQL=$MYSQL_COUNT, ClickHouse=$CH_COUNT (diff: $DIFF, ${DIFF_PERCENT}%)"
        MISMATCHED_TABLES=$((MISMATCHED_TABLES + 1))
    fi

    # Limit output to first 20 tables
    if [ $TOTAL_TABLES -ge 20 ]; then
        echo "  ... (showing first 20 tables)"
        break
    fi
done

echo ""
echo "Summary:"
echo "  Total tables checked: $TOTAL_TABLES"
echo "  Matched: $MATCHED_TABLES"
echo "  Mismatched: $MISMATCHED_TABLES"
echo "  Missing in ClickHouse: $MISSING_TABLES"

if [ $MISMATCHED_TABLES -gt 0 ] || [ $MISSING_TABLES -gt 0 ]; then
    print_warning "Some tables have data quality issues"
else
    print_status 0 "All tables are in sync"
fi

echo ""

# 2. Check for NULL values in critical columns
echo "2. NULL Value Check"
echo "-------------------"

NULL_ISSUES=0

# Sample check on a few tables
for table in $(echo "$TABLES" | head -5); do
    # Get primary key columns
    PK_COLS=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -D "$MYSQL_DATABASE" -N -e "
        SELECT GROUP_CONCAT(COLUMN_NAME)
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = '$MYSQL_DATABASE'
        AND TABLE_NAME = '$table'
        AND CONSTRAINT_NAME = 'PRIMARY'
        " 2>/dev/null)

    if [ ! -z "$PK_COLS" ]; then
        # Check for NULLs in primary key columns
        for col in $(echo $PK_COLS | tr ',' ' '); do
            NULL_COUNT=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
                --data-binary "SELECT COUNT(*) FROM $CLICKHOUSE_DATABASE.\`$table\` WHERE \`$col\` IS NULL" 2>/dev/null || echo "0")

            if [ "$NULL_COUNT" != "0" ]; then
                echo -e "  ${RED}✗${NC} $table.$col: $NULL_COUNT NULL values in primary key!"
                NULL_ISSUES=$((NULL_ISSUES + 1))
            fi
        done
    fi
done

if [ $NULL_ISSUES -eq 0 ]; then
    print_status 0 "No NULL values in primary keys"
else
    print_warning "$NULL_ISSUES NULL value issues found"
fi

echo ""

# 3. Check for duplicate rows
echo "3. Duplicate Check"
echo "------------------"

DUPLICATE_ISSUES=0

for table in $(echo "$TABLES" | head -5); do
    # Check for duplicates in ClickHouse
    DUPLICATE_COUNT=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
        --data-binary "SELECT count() FROM (
            SELECT count() as cnt
            FROM $CLICKHOUSE_DATABASE.\`$table\`
            GROUP BY *
            HAVING cnt > 1
        )" 2>/dev/null || echo "0")

    if [ "$DUPLICATE_COUNT" != "0" ]; then
        echo -e "  ${YELLOW}⚠${NC} $table: $DUPLICATE_COUNT duplicate row groups (normal for ReplacingMergeTree before optimization)"
        DUPLICATE_ISSUES=$((DUPLICATE_ISSUES + 1))
    fi
done

if [ $DUPLICATE_ISSUES -eq 0 ]; then
    print_status 0 "No duplicates found"
else
    print_warning "$DUPLICATE_ISSUES tables have duplicates (run OPTIMIZE TABLE to deduplicate)"
fi

echo ""

# 4. Check data freshness
echo "4. Data Freshness Check"
echo "-----------------------"

STALE_TABLES=0

for table in $(echo "$TABLES" | head -10); do
    LATEST_TS=$(curl -s "$CLICKHOUSE_URL/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
        --data-binary "SELECT toUnixTimestamp(max(_extracted_at)) FROM $CLICKHOUSE_DATABASE.\`$table\`" 2>/dev/null || echo "0")

    if [ "$LATEST_TS" != "0" ] && [ ! -z "$LATEST_TS" ]; then
        CURRENT_TS=$(date +%s)
        AGE=$((CURRENT_TS - LATEST_TS))

        if [ $AGE -gt 600 ]; then  # 10 minutes
            echo -e "  ${YELLOW}⚠${NC} $table: Last update $(($AGE / 60)) minutes ago"
            STALE_TABLES=$((STALE_TABLES + 1))
        elif [ $AGE -gt 3600 ]; then  # 1 hour
            echo -e "  ${RED}✗${NC} $table: Last update $(($AGE / 3600)) hours ago"
            STALE_TABLES=$((STALE_TABLES + 1))
        fi
    fi
done

if [ $STALE_TABLES -eq 0 ]; then
    print_status 0 "All tables are fresh (< 10 minutes)"
else
    print_warning "$STALE_TABLES tables may be stale"
fi

echo ""

# 5. Overall Assessment
echo "======================================"
echo "Overall Data Quality Assessment"
echo "======================================"

TOTAL_ISSUES=$((MISMATCHED_TABLES + MISSING_TABLES + NULL_ISSUES + STALE_TABLES))

if [ $TOTAL_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ EXCELLENT${NC} - No data quality issues detected"
elif [ $TOTAL_ISSUES -lt 5 ]; then
    echo -e "${YELLOW}⚠ GOOD${NC} - Minor issues detected ($TOTAL_ISSUES total)"
else
    echo -e "${RED}✗ NEEDS ATTENTION${NC} - Multiple issues detected ($TOTAL_ISSUES total)"
fi

echo ""
echo "Validation completed at $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

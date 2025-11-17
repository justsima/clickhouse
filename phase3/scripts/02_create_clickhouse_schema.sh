#!/bin/bash
# Phase 3 - Create ClickHouse Schema Script
# Purpose: Create all ClickHouse tables from generated DDL

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"
OUTPUT_DIR="$PHASE3_DIR/schema_output"
DDL_DIR="$OUTPUT_DIR/clickhouse_ddl"

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
echo "   ClickHouse Schema Creation"
echo "========================================"
echo ""

# Load environment variables
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
else
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Check if DDL directory exists
if [ ! -d "$DDL_DIR" ]; then
    echo -e "${RED}ERROR: DDL directory not found: $DDL_DIR${NC}"
    echo "Please run 01_analyze_mysql_schema.sh first"
    exit 1
fi

echo "1. Testing ClickHouse Connection"
echo "---------------------------------"

# ClickHouse client command via Docker
CH_EXEC="docker exec clickhouse-server clickhouse-client --password '$CLICKHOUSE_PASSWORD'"

if eval "$CH_EXEC --query 'SELECT 1'" 2>/dev/null 1>/dev/null; then
    print_status 0 "ClickHouse connection successful"
else
    print_status 1 "ClickHouse connection failed"
    echo "Make sure ClickHouse container is running (Phase 2)"
    exit 1
fi

echo ""
echo "2. Creating Analytics Database"
echo "-------------------------------"

eval "$CH_EXEC --query 'CREATE DATABASE IF NOT EXISTS analytics'" 2>/dev/null
if eval "$CH_EXEC --query 'SHOW DATABASES'" | grep -q "analytics"; then
    print_status 0 "Analytics database ready"
else
    print_status 1 "Failed to create analytics database"
    exit 1
fi

echo ""
echo "3. Creating Tables"
echo "------------------"

TOTAL_TABLES=$(ls -1 "$DDL_DIR"/*.sql 2>/dev/null | wc -l)
if [ "$TOTAL_TABLES" -eq 0 ]; then
    echo -e "${RED}ERROR: No DDL files found in $DDL_DIR${NC}"
    exit 1
fi

print_info "Found $TOTAL_TABLES table definitions"
echo ""

CREATED=0
FAILED=0
FAILED_TABLES=""

for DDL_FILE in "$DDL_DIR"/*.sql; do
    TABLE_NAME=$(basename "$DDL_FILE" .sql)

    echo -ne "\rCreating table: $TABLE_NAME                              "

    # Execute DDL
    if eval "$CH_EXEC --multiquery" < "$DDL_FILE" 2>/dev/null; then
        ((CREATED++))
    else
        ((FAILED++))
        FAILED_TABLES="$FAILED_TABLES\n  - $TABLE_NAME"
        echo -e "\n${YELLOW}Warning: Failed to create table: $TABLE_NAME${NC}"
    fi
done

echo ""
echo ""

print_status 0 "Successfully created $CREATED tables"
if [ "$FAILED" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Failed to create $FAILED tables:${NC}"
    echo -e "$FAILED_TABLES"
fi

echo ""
echo "4. Verifying Schema"
echo "-------------------"

# Get actual table count
ACTUAL_TABLES=$(eval "$CH_EXEC --query \"SELECT COUNT(*) FROM system.tables WHERE database = 'analytics'\"" 2>/dev/null)

print_info "Tables in analytics database: $ACTUAL_TABLES"

# Show sample table list
echo ""
echo "Sample of created tables:"
eval "$CH_EXEC --query \"SELECT name FROM system.tables WHERE database = 'analytics' LIMIT 10 FORMAT Pretty\"" 2>/dev/null

echo ""
echo "========================================"
echo "   Schema Creation Complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  Total DDL files: $TOTAL_TABLES"
echo "  Successfully created: $CREATED"
echo "  Failed: $FAILED"
echo "  Verified in ClickHouse: $ACTUAL_TABLES"
echo ""
echo "Next step: Run 03_deploy_connectors.sh"
echo ""

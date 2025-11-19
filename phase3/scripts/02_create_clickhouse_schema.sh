#!/bin/bash
# Phase 3 - Create ClickHouse Schema Script
# Purpose: Create all ClickHouse tables from generated DDL

# Don't exit on error - handle explicitly
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"
CONFIG_DIR="$PHASE3_DIR/configs"
# Fixed: Use root-level schema_output where the FIXED DDL files are located
OUTPUT_DIR="$PROJECT_ROOT/schema_output"
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

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

echo "========================================"
echo "   ClickHouse Schema Creation"
echo "========================================"
echo ""

# Load environment variables from centralized .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    print_error ".env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

# Check if DDL directory exists
if [ ! -d "$DDL_DIR" ]; then
    print_error "DDL directory not found: $DDL_DIR"
    echo "Please run 01_analyze_mysql_schema.sh first"
    exit 1
fi

echo "1. Testing ClickHouse Connection"
echo "---------------------------------"

# ClickHouse client command via Docker
CH_PASSWORD="${CLICKHOUSE_PASSWORD:-ClickHouse_Secure_Pass_2024!}"

if docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query "SELECT 1" 2>/dev/null 1>/dev/null; then
    print_status 0 "ClickHouse connection successful"
else
    print_status 1 "ClickHouse connection failed"
    echo "Make sure ClickHouse container is running (Phase 2)"
    exit 1
fi

echo ""
echo "2. Creating Analytics Database"
echo "-------------------------------"

docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query "CREATE DATABASE IF NOT EXISTS analytics" 2>/dev/null

if docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query "SHOW DATABASES" 2>/dev/null | grep -q "analytics"; then
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
    print_error "No DDL files found in $DDL_DIR"
    exit 1
fi

print_info "Found $TOTAL_TABLES table definitions"
echo ""

CREATED=0
FAILED=0
FAILED_LOG="$OUTPUT_DIR/table_creation_errors.log"
> "$FAILED_LOG"  # Clear log file

for DDL_FILE in "$DDL_DIR"/*.sql; do
    TABLE_NAME=$(basename "$DDL_FILE" .sql)

    echo -ne "\rCreating table $((CREATED + FAILED + 1))/$TOTAL_TABLES: $TABLE_NAME                              "

    # Read DDL content and execute via --query
    DDL_CONTENT=$(cat "$DDL_FILE")

    # Execute DDL with error capture
    ERROR_OUTPUT=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --multiquery --query "$DDL_CONTENT" 2>&1)

    if [ $? -eq 0 ]; then
        ((CREATED++))
    else
        ((FAILED++))
        echo "" >> "$FAILED_LOG"
        echo "Table: $TABLE_NAME" >> "$FAILED_LOG"
        echo "Error: $ERROR_OUTPUT" >> "$FAILED_LOG"
        echo "DDL: $DDL_CONTENT" >> "$FAILED_LOG"
        echo "---" >> "$FAILED_LOG"
    fi
done

echo ""
echo ""

print_status 0 "Successfully created $CREATED tables"

if [ "$FAILED" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Failed to create $FAILED tables${NC}"
    echo "  See details in: $FAILED_LOG"
    echo ""
    echo "First few errors:"
    head -30 "$FAILED_LOG"
fi

echo ""
echo "4. Verifying Schema"
echo "-------------------"

# Get actual table count
ACTUAL_TABLES=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query "SELECT COUNT(*) FROM system.tables WHERE database = 'analytics'" 2>/dev/null)

print_info "Tables in analytics database: $ACTUAL_TABLES"

if [ "$ACTUAL_TABLES" -gt 0 ]; then
    # Show sample table list
    echo ""
    echo "Sample of created tables:"
    docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" --query "SELECT name FROM system.tables WHERE database = 'analytics' ORDER BY name LIMIT 10 FORMAT Pretty" 2>/dev/null
fi

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

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Note: Some tables failed to create.${NC}"
    echo "This is often due to:"
    echo "  - Complex MySQL types that need manual adjustment"
    echo "  - Reserved keywords in column names"
    echo "  - Unsupported DEFAULT values"
    echo ""
    echo "Check: $FAILED_LOG"
fi

echo ""
echo "Next step: Run 03_deploy_connectors.sh"
echo ""

# Exit with success if most tables were created
if [ "$CREATED" -ge "$((TOTAL_TABLES * 80 / 100))" ]; then
    exit 0
else
    print_error "Too many tables failed ($FAILED/$TOTAL_TABLES)"
    exit 1
fi

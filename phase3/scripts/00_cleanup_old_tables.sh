#!/bin/bash

###############################################################################
# Cleanup Script: Drop Old ClickHouse Tables from Previous Conversion
###############################################################################
#
# Purpose: Drop all existing tables in the 'analytics' database that were
#          created with the old (broken) schema conversion.
#
# When to use:
#   - Before re-running Phase 3 with the fixed schema conversion
#   - When you need to start fresh with corrected DDL files
#
# What it does:
#   1. Connects to ClickHouse
#   2. Lists all tables in 'analytics' database
#   3. Drops each table
#   4. Verifies cleanup was successful
#
# Safety:
#   - Only drops tables in 'analytics' database (not 'system' or 'default')
#   - Requires confirmation before proceeding
#   - Creates backup SQL of existing tables (structure only)
#
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ClickHouse connection details
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"
CLICKHOUSE_USER="${CLICKHOUSE_USER:-default}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-ClickHouse_Secure_Pass_2024!}"
CLICKHOUSE_DB="analytics"

echo "========================================="
echo "ClickHouse Table Cleanup Script"
echo "========================================="
echo ""
echo "This script will:"
echo "  1. Backup existing table structures to SQL file"
echo "  2. Drop all tables in the 'analytics' database"
echo "  3. Verify cleanup was successful"
echo ""
echo "Target database: ${CLICKHOUSE_DB}"
echo "ClickHouse host: ${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}"
echo ""

# Function to execute ClickHouse query
clickhouse_query() {
    local query="$1"
    docker exec clickhouse-server clickhouse-client \
        --host="${CLICKHOUSE_HOST}" \
        --port="${CLICKHOUSE_PORT}" \
        --user="${CLICKHOUSE_USER}" \
        --password="${CLICKHOUSE_PASSWORD}" \
        --query="${query}" 2>&1
}

# Step 1: Check if ClickHouse is running
echo "Checking ClickHouse connectivity..."
if ! clickhouse_query "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to ClickHouse${NC}"
    echo "Make sure ClickHouse is running: docker compose ps"
    exit 1
fi
echo -e "${GREEN}✓ Connected to ClickHouse${NC}"
echo ""

# Step 2: Check if analytics database exists
echo "Checking if '${CLICKHOUSE_DB}' database exists..."
DB_EXISTS=$(clickhouse_query "SELECT count() FROM system.databases WHERE name = '${CLICKHOUSE_DB}'" 2>/dev/null || echo "0")

if [ "$DB_EXISTS" = "0" ]; then
    echo -e "${YELLOW}ℹ Database '${CLICKHOUSE_DB}' does not exist yet${NC}"
    echo "Nothing to clean up. You can proceed with schema creation."
    exit 0
fi
echo -e "${GREEN}✓ Database '${CLICKHOUSE_DB}' exists${NC}"
echo ""

# Step 3: Get list of existing tables
echo "Fetching list of tables in '${CLICKHOUSE_DB}'..."
TABLES=$(clickhouse_query "SELECT name FROM system.tables WHERE database = '${CLICKHOUSE_DB}' FORMAT TSVRaw" 2>/dev/null || echo "")

if [ -z "$TABLES" ]; then
    echo -e "${YELLOW}ℹ No tables found in '${CLICKHOUSE_DB}' database${NC}"
    echo "Nothing to clean up. You can proceed with schema creation."
    exit 0
fi

# Count tables
TABLE_COUNT=$(echo "$TABLES" | wc -l)
echo -e "${GREEN}✓ Found ${TABLE_COUNT} table(s) to drop${NC}"
echo ""
echo "Tables to be dropped:"
echo "$TABLES" | sed 's/^/  - /'
echo ""

# Step 4: Create backup of table structures
BACKUP_DIR="/home/user/clickhouse/phase3/backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="${BACKUP_DIR}/table_structures_backup_$(date +%Y%m%d_%H%M%S).sql"

echo "Creating backup of table structures..."
echo "-- ClickHouse Table Structure Backup" > "$BACKUP_FILE"
echo "-- Generated: $(date)" >> "$BACKUP_FILE"
echo "-- Database: ${CLICKHOUSE_DB}" >> "$BACKUP_FILE"
echo "-- Total tables: ${TABLE_COUNT}" >> "$BACKUP_FILE"
echo "" >> "$BACKUP_FILE"

for table in $TABLES; do
    echo "-- Table: ${table}" >> "$BACKUP_FILE"
    clickhouse_query "SHOW CREATE TABLE ${CLICKHOUSE_DB}.\`${table}\`" >> "$BACKUP_FILE" 2>/dev/null || echo "-- Failed to get DDL for ${table}" >> "$BACKUP_FILE"
    echo "" >> "$BACKUP_FILE"
done

echo -e "${GREEN}✓ Backup saved to: ${BACKUP_FILE}${NC}"
echo ""

# Step 5: Ask for confirmation
echo -e "${YELLOW}⚠ WARNING: This will permanently drop ${TABLE_COUNT} table(s)!${NC}"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi
echo ""

# Step 6: Drop all tables
echo "Dropping tables..."
DROPPED_COUNT=0
FAILED_COUNT=0

for table in $TABLES; do
    echo -n "  Dropping ${table}... "
    if clickhouse_query "DROP TABLE IF EXISTS ${CLICKHOUSE_DB}.\`${table}\`" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((DROPPED_COUNT++))
    else
        echo -e "${RED}✗ Failed${NC}"
        ((FAILED_COUNT++))
    fi
done

echo ""
echo "========================================="
echo "Cleanup Summary"
echo "========================================="
echo "Tables dropped: ${DROPPED_COUNT}/${TABLE_COUNT}"
echo "Failed: ${FAILED_COUNT}"
echo "Backup location: ${BACKUP_FILE}"
echo ""

# Step 7: Verify cleanup
echo "Verifying cleanup..."
REMAINING_TABLES=$(clickhouse_query "SELECT count() FROM system.tables WHERE database = '${CLICKHOUSE_DB}'" 2>/dev/null || echo "error")

if [ "$REMAINING_TABLES" = "0" ]; then
    echo -e "${GREEN}✓ All tables successfully dropped${NC}"
    echo -e "${GREEN}✓ Database '${CLICKHOUSE_DB}' is now empty${NC}"
    echo ""
    echo "You can now proceed with:"
    echo "  ./scripts/02_create_clickhouse_schema.sh"
elif [ "$REMAINING_TABLES" = "error" ]; then
    echo -e "${RED}✗ Error verifying cleanup${NC}"
    exit 1
else
    echo -e "${YELLOW}⚠ Warning: ${REMAINING_TABLES} table(s) still remain${NC}"
    echo "You may need to manually investigate."
fi

echo ""
echo "========================================="
echo "Cleanup complete!"
echo "========================================="

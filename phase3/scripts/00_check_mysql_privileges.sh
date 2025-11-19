#!/bin/bash
# Check MySQL User Privileges for CDC
# Purpose: Verify if MySQL user has required privileges for Debezium CDC

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}ERROR:${NC} .env file not found at $PROJECT_ROOT/.env"
    exit 1
fi

echo "========================================"
echo "   MySQL Privilege Checker"
echo "========================================"
echo ""
echo "Checking privileges for user: ${MYSQL_USER}"
echo "MySQL host: ${MYSQL_HOST}:${MYSQL_PORT}"
echo ""

# Test MySQL connection
echo "1. Testing MySQL Connection..."
echo "-------------------------------"

# Install mysql client in kafka-connect container if not present
echo "Installing MySQL client in Kafka Connect container..."
docker exec -u root kafka-connect-clickhouse bash -c "
    if ! command -v mysql &> /dev/null; then
        apt-get update -qq && apt-get install -y -qq default-mysql-client > /dev/null 2>&1
    fi
" 2>/dev/null

if docker exec kafka-connect-clickhouse mysql \
    -h"${MYSQL_HOST}" \
    -P"${MYSQL_PORT}" \
    -u"${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    -e "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Connected to MySQL successfully"
else
    echo -e "${RED}✗${NC} Failed to connect to MySQL"
    echo ""
    echo "Please verify:"
    echo "  1. MySQL host is reachable: ${MYSQL_HOST}"
    echo "  2. MySQL port is correct: ${MYSQL_PORT}"
    echo "  3. Username is correct: ${MYSQL_USER}"
    echo "  4. Password is correct"
    echo "  5. VPS IP is whitelisted in DigitalOcean MySQL settings"
    exit 1
fi

echo ""
echo "2. Checking User Privileges..."
echo "-------------------------------"

# Get grants for current user
GRANTS=$(docker exec kafka-connect-clickhouse mysql \
    -h"${MYSQL_HOST}" \
    -P"${MYSQL_PORT}" \
    -u"${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    -e "SHOW GRANTS FOR CURRENT_USER();" 2>/dev/null)

echo "Current grants:"
echo "$GRANTS"
echo ""

echo "3. Privilege Analysis..."
echo "-------------------------------"

# Check for specific privileges
HAS_REPLICATION_SLAVE=false
HAS_REPLICATION_CLIENT=false
HAS_SELECT=false

if echo "$GRANTS" | grep -qi "REPLICATION SLAVE"; then
    echo -e "${GREEN}✓${NC} REPLICATION SLAVE - Found"
    HAS_REPLICATION_SLAVE=true
else
    echo -e "${RED}✗${NC} REPLICATION SLAVE - MISSING (Required for CDC)"
fi

if echo "$GRANTS" | grep -qi "REPLICATION CLIENT"; then
    echo -e "${GREEN}✓${NC} REPLICATION CLIENT - Found"
    HAS_REPLICATION_CLIENT=true
else
    echo -e "${RED}✗${NC} REPLICATION CLIENT - MISSING (Required for CDC)"
fi

if echo "$GRANTS" | grep -qi "SELECT"; then
    echo -e "${GREEN}✓${NC} SELECT - Found"
    HAS_SELECT=true
else
    echo -e "${RED}✗${NC} SELECT - MISSING (Required for snapshot)"
fi

echo ""
echo "4. Summary..."
echo "-------------------------------"

if [ "$HAS_REPLICATION_SLAVE" = true ] && [ "$HAS_REPLICATION_CLIENT" = true ] && [ "$HAS_SELECT" = true ]; then
    echo -e "${GREEN}✓ All required privileges present!${NC}"
    echo ""
    echo "Your MySQL user has all necessary privileges for:"
    echo "  - Initial snapshot of all tables"
    echo "  - Continuous CDC (real-time replication)"
    echo ""
    echo -e "${GREEN}You can proceed with deploying connectors!${NC}"
    exit 0
else
    echo -e "${RED}✗ Missing required privileges!${NC}"
    echo ""
    echo "Your MySQL user is missing privileges needed for CDC."
    echo ""
    echo "Required privileges:"
    echo "  - REPLICATION SLAVE: Read MySQL binlog for CDC"
    echo "  - REPLICATION CLIENT: Query binlog position"
    echo "  - SELECT: Read table data for initial snapshot"
    echo ""
    echo "To fix this, run these SQL commands as MySQL admin:"
    echo ""
    echo "---------------------------------------------------"
    echo "GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_USER}'@'%';"
    echo "GRANT REPLICATION CLIENT ON *.* TO '${MYSQL_USER}'@'%';"
    echo "GRANT SELECT ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';"
    echo "FLUSH PRIVILEGES;"
    echo "---------------------------------------------------"
    echo ""
    echo "If you're using DigitalOcean Managed MySQL:"
    echo "  1. Go to your database in the DO dashboard"
    echo "  2. Users & Databases tab"
    echo "  3. Make sure your user has 'replication' permissions"
    echo ""

    if [ "$HAS_SELECT" = true ]; then
        echo -e "${YELLOW}Note: You have SELECT privilege, so you can still do${NC}"
        echo -e "${YELLOW}snapshot-only mode (initial_only) without CDC.${NC}"
    fi

    exit 1
fi

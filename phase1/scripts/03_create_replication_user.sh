#!/bin/bash
# Phase 1 - Create MySQL Replication User
# Purpose: Check existing user privileges or create dedicated Debezium replication user

set -e

# Load environment variables from main .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE1_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE1_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo "ERROR: .env file not found at $PROJECT_ROOT/.env"
    echo "Please ensure the main .env file exists with MySQL credentials"
    exit 1
fi

echo "========================================"
echo "   MySQL Replication User Setup"
echo "========================================"
echo ""

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Validate required variables
if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "${RED}ERROR: MySQL connection details not set in .env${NC}"
    exit 1
fi

# MySQL connection
MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD}"

echo "Step 1: Testing Current User Privileges"
echo "-----------------------------------------"
echo "User: ${MYSQL_USER}"
echo ""

# Test connection
if ! $MYSQL_CMD -e "SELECT 1;" 2>/dev/null 1>/dev/null; then
    echo -e "${RED}✗ Cannot connect with current user${NC}"
    exit 1
fi
print_status 0 "Connected as ${MYSQL_USER}"
echo ""

# Check current user grants
echo "Step 2: Checking Current User Privileges"
echo "-----------------------------------------"
print_info "Retrieving grants for ${MYSQL_USER}..."
echo ""

GRANTS=$($MYSQL_CMD -e "SHOW GRANTS FOR CURRENT_USER();" 2>/dev/null || echo "ERROR")

if [ "$GRANTS" != "ERROR" ]; then
    echo "Current grants:"
    echo "$GRANTS" | while IFS= read -r line; do
        echo "  $line"
    done
    echo ""
else
    print_warning "Could not retrieve grants"
    echo ""
fi

# Check for required privileges
echo "Step 3: Checking Required Debezium Privileges"
echo "----------------------------------------------"

HAS_REPLICATION_SLAVE=0
HAS_REPLICATION_CLIENT=0
HAS_SELECT=0
CAN_READ_BINLOG=0

# Check REPLICATION SLAVE
if echo "$GRANTS" | grep -qi "REPLICATION SLAVE\|ALL PRIVILEGES"; then
    print_status 0 "Has REPLICATION SLAVE privilege"
    HAS_REPLICATION_SLAVE=1
else
    print_status 1 "Missing REPLICATION SLAVE privilege"
fi

# Check REPLICATION CLIENT
if echo "$GRANTS" | grep -qi "REPLICATION CLIENT\|ALL PRIVILEGES"; then
    print_status 0 "Has REPLICATION CLIENT privilege"
    HAS_REPLICATION_CLIENT=1
else
    print_status 1 "Missing REPLICATION CLIENT privilege"
fi

# Check SELECT privilege
if echo "$GRANTS" | grep -qi "SELECT.*\*\.\*\|ALL PRIVILEGES\|SELECT.*${MYSQL_DATABASE}"; then
    print_status 0 "Has SELECT privilege"
    HAS_SELECT=1
else
    print_status 1 "Missing SELECT privilege on database"
fi

# Test reading binlog position (critical for Debezium)
echo ""
print_info "Testing binlog access..."
BINLOG_STATUS=$($MYSQL_CMD -e "SHOW MASTER STATUS;" 2>/dev/null || echo "ERROR")

if [ "$BINLOG_STATUS" != "ERROR" ] && [ -n "$BINLOG_STATUS" ]; then
    print_status 0 "Can read binlog position (SHOW MASTER STATUS)"
    CAN_READ_BINLOG=1
    echo ""
    echo "Current binlog position:"
    echo "$BINLOG_STATUS"
else
    print_status 1 "Cannot read binlog position"
fi

echo ""
echo "========================================"
echo "   Privilege Check Summary"
echo "========================================"
echo ""

REQUIRED_PRIVILEGES=$((HAS_REPLICATION_SLAVE + HAS_REPLICATION_CLIENT + HAS_SELECT + CAN_READ_BINLOG))

if [ $REQUIRED_PRIVILEGES -eq 4 ]; then
    echo -e "${GREEN}✓ User '${MYSQL_USER}' has ALL required privileges for Debezium!${NC}"
    echo ""
    echo "Required privileges present:"
    echo "  ✓ REPLICATION SLAVE"
    echo "  ✓ REPLICATION CLIENT"
    echo "  ✓ SELECT on database"
    echo "  ✓ Can read binlog position"
    echo ""
    echo "========================================"
    echo "   Recommendation"
    echo "========================================"
    echo ""
    echo -e "${GREEN}You can use '${MYSQL_USER}' directly for Debezium CDC.${NC}"
    echo ""
    echo "No need to create a separate replication user!"
    echo ""
    echo "In your Debezium connector configuration (Phase 3), use:"
    echo "  database.user: ${MYSQL_USER}"
    echo "  database.password: (current password)"
    echo ""

    # Save to report
    REPORT_FILE="${SCRIPT_DIR}/../replication_user_info.txt"
    {
        echo "=== Replication User Info ==="
        echo "Date: $(date)"
        echo ""
        echo "Recommendation: Use existing user for Debezium"
        echo "User: ${MYSQL_USER}"
        echo "Host pattern: % (managed by DigitalOcean)"
        echo ""
        echo "Privileges verified:"
        echo "  ✓ REPLICATION SLAVE"
        echo "  ✓ REPLICATION CLIENT"
        echo "  ✓ SELECT on ${MYSQL_DATABASE}"
        echo "  ✓ Can read binlog position"
        echo ""
        echo "Grants:"
        echo "$GRANTS"
    } > "$REPORT_FILE"

    print_info "Report saved to: $REPORT_FILE"
    echo ""

    echo "Next step: Run network validation"
    echo "  ./04_network_validation.sh"
    echo ""

    exit 0
else
    echo -e "${YELLOW}⚠ User '${MYSQL_USER}' is missing some privileges${NC}"
    echo ""
    echo "Missing privileges:"
    [ $HAS_REPLICATION_SLAVE -eq 0 ] && echo "  ✗ REPLICATION SLAVE"
    [ $HAS_REPLICATION_CLIENT -eq 0 ] && echo "  ✗ REPLICATION CLIENT"
    [ $HAS_SELECT -eq 0 ] && echo "  ✗ SELECT on database"
    [ $CAN_READ_BINLOG -eq 0 ] && echo "  ✗ Cannot read binlog position"
    echo ""

    echo "========================================"
    echo "   Required Actions"
    echo "========================================"
    echo ""
    echo "To enable CDC with Debezium, grant these privileges to '${MYSQL_USER}':"
    echo ""

    if [ $HAS_REPLICATION_SLAVE -eq 0 ]; then
        echo "  GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_USER}'@'%';"
    fi

    if [ $HAS_REPLICATION_CLIENT -eq 0 ]; then
        echo "  GRANT REPLICATION CLIENT ON *.* TO '${MYSQL_USER}'@'%';"
    fi

    if [ $HAS_SELECT -eq 0 ]; then
        echo "  GRANT SELECT ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';"
    fi

    echo "  FLUSH PRIVILEGES;"
    echo ""

    echo "After granting privileges, re-run this script to verify:"
    echo "  ./03_create_replication_user.sh"
    echo ""

    # Save to report
    REPORT_FILE="${SCRIPT_DIR}/../replication_user_info.txt"
    {
        echo "=== Replication User Info ==="
        echo "Date: $(date)"
        echo ""
        echo "Status: Missing privileges"
        echo "User: ${MYSQL_USER}"
        echo ""
        echo "Missing privileges:"
        [ $HAS_REPLICATION_SLAVE -eq 0 ] && echo "  - REPLICATION SLAVE"
        [ $HAS_REPLICATION_CLIENT -eq 0 ] && echo "  - REPLICATION CLIENT"
        [ $HAS_SELECT -eq 0 ] && echo "  - SELECT on database"
        [ $CAN_READ_BINLOG -eq 0 ] && echo "  - Cannot read binlog position"
        echo ""
        echo "Required SQL commands:"
        [ $HAS_REPLICATION_SLAVE -eq 0 ] && echo "  GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_USER}'@'%';"
        [ $HAS_REPLICATION_CLIENT -eq 0 ] && echo "  GRANT REPLICATION CLIENT ON *.* TO '${MYSQL_USER}'@'%';"
        [ $HAS_SELECT -eq 0 ] && echo "  GRANT SELECT ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';"
        echo "  FLUSH PRIVILEGES;"
    } > "$REPORT_FILE"

    print_info "Report saved to: $REPORT_FILE"
    echo ""

    exit 1
fi

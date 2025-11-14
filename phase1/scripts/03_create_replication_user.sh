#!/bin/bash
# Phase 1 - Create MySQL Replication User
# Purpose: Check existing user privileges or create dedicated Debezium replication user

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../configs/.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "ERROR: .env file not found at $ENV_FILE"
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
MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} 2>/dev/null"

echo "Step 1: Testing Current User Privileges"
echo "-----------------------------------------"
echo "User: ${MYSQL_USER}"
echo ""

# Test connection
if ! $MYSQL_CMD -e "SELECT 1;" &> /dev/null; then
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
    echo "   Attempting to Create Dedicated User"
    echo "========================================"
    echo ""

    if [ -z "$MYSQL_REPLICATION_USER" ] || [ -z "$MYSQL_REPLICATION_PASSWORD" ]; then
        echo -e "${RED}ERROR: MYSQL_REPLICATION_USER and MYSQL_REPLICATION_PASSWORD must be set in .env${NC}"
        echo ""
        echo "Please add to your .env file:"
        echo "  MYSQL_REPLICATION_USER=debezium_user"
        echo "  MYSQL_REPLICATION_PASSWORD=<secure_password>"
        exit 1
    fi

    echo "Attempting to create user: ${MYSQL_REPLICATION_USER}"
    echo ""

    # Check if user exists
    USER_EXISTS=$($MYSQL_CMD -e "SELECT User FROM mysql.user WHERE User='${MYSQL_REPLICATION_USER}';" 2>/dev/null || echo "")

    if [ -n "$USER_EXISTS" ]; then
        print_info "User '${MYSQL_REPLICATION_USER}' already exists"
        echo ""
        read -p "Do you want to drop and recreate it? (yes/no): " RECREATE

        if [ "$RECREATE" = "yes" ]; then
            echo "Dropping existing user..."
            $MYSQL_CMD -e "DROP USER IF EXISTS '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
            print_status $? "Existing user dropped"
        fi
    fi

    # Try to create user
    echo "Creating user '${MYSQL_REPLICATION_USER}'..."
    CREATE_RESULT=$($MYSQL_CMD -e "CREATE USER IF NOT EXISTS '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}';" 2>&1)

    if echo "$CREATE_RESULT" | grep -qi "Access denied\|ERROR 1227"; then
        echo ""
        echo -e "${RED}✗ Cannot create user - insufficient privileges${NC}"
        echo ""
        echo "Your '${MYSQL_USER}' does not have CREATE USER privilege."
        echo ""
        echo "========================================"
        echo "   Solution Options"
        echo "========================================"
        echo ""
        echo "Option 1: Create user via DigitalOcean Dashboard"
        echo "  1. Go to DigitalOcean Dashboard"
        echo "  2. Databases → Your MySQL → Users & Databases"
        echo "  3. Click 'Add new user'"
        echo "  4. Username: ${MYSQL_REPLICATION_USER}"
        echo "  5. Password: ${MYSQL_REPLICATION_PASSWORD}"
        echo "  6. Grant SELECT on database: ${MYSQL_DATABASE}"
        echo ""
        echo "Option 2: Contact your database admin"
        echo "  Ask them to create a user with these privileges:"
        echo "    - REPLICATION SLAVE"
        echo "    - REPLICATION CLIENT"
        echo "    - SELECT on ${MYSQL_DATABASE}.*"
        echo ""
        echo "Option 3: Use current user (if you can get privileges granted)"
        echo "  Contact DigitalOcean support to add these privileges to '${MYSQL_USER}':"
        echo "    - REPLICATION SLAVE"
        echo "    - REPLICATION CLIENT"
        echo ""

        exit 1
    else
        print_status 0 "User created successfully"
        echo ""

        # Grant privileges
        echo "Granting privileges..."
        $MYSQL_CMD -e "GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
        print_status $? "REPLICATION SLAVE granted"

        $MYSQL_CMD -e "GRANT REPLICATION CLIENT ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
        print_status $? "REPLICATION CLIENT granted"

        $MYSQL_CMD -e "GRANT SELECT ON ${MYSQL_DATABASE}.* TO '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
        print_status $? "SELECT on ${MYSQL_DATABASE}.* granted"

        $MYSQL_CMD -e "FLUSH PRIVILEGES;" 2>/dev/null
        print_status $? "Privileges flushed"

        echo ""
        echo -e "${GREEN}✓ Replication user '${MYSQL_REPLICATION_USER}' created successfully${NC}"
        echo ""
        echo "Next step: Run network validation"
        echo "  ./04_network_validation.sh"
        echo ""
    fi
fi

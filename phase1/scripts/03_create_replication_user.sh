#!/bin/bash
# Phase 1 - Create MySQL Replication User
# Purpose: Create and configure Debezium replication user with proper privileges

set -e

# Load environment variables
if [ -f "/home/user/clickhouse/phase1/configs/.env" ]; then
    source /home/user/clickhouse/phase1/configs/.env
else
    echo "ERROR: .env file not found at /home/user/clickhouse/phase1/configs/.env"
    exit 1
fi

echo "========================================"
echo "   Create MySQL Replication User"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Validate required variables
if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "${RED}ERROR: MySQL connection details not set in .env${NC}"
    exit 1
fi

if [ -z "$MYSQL_REPLICATION_USER" ] || [ -z "$MYSQL_REPLICATION_PASSWORD" ]; then
    echo -e "${RED}ERROR: MYSQL_REPLICATION_USER and MYSQL_REPLICATION_PASSWORD must be set in .env${NC}"
    exit 1
fi

# MySQL connection
MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD}"

echo "Creating replication user: ${MYSQL_REPLICATION_USER}"
echo ""

# Check if user already exists
USER_EXISTS=$($MYSQL_CMD -e "SELECT User FROM mysql.user WHERE User='${MYSQL_REPLICATION_USER}';" -sN 2>/dev/null || echo "")

if [ -n "$USER_EXISTS" ]; then
    echo -e "${YELLOW}User '${MYSQL_REPLICATION_USER}' already exists.${NC}"
    read -p "Do you want to drop and recreate it? (yes/no): " RECREATE

    if [ "$RECREATE" = "yes" ]; then
        echo "Dropping existing user..."
        $MYSQL_CMD -e "DROP USER IF EXISTS '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
        print_status 0 "Existing user dropped"
    else
        echo "Skipping user creation. Updating grants only..."
    fi
fi

# Create user if it doesn't exist
if [ -z "$USER_EXISTS" ] || [ "$RECREATE" = "yes" ]; then
    echo "Creating user '${MYSQL_REPLICATION_USER}'..."

    # MySQL 8.0 syntax - create user first
    $MYSQL_CMD -e "CREATE USER IF NOT EXISTS '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}';"

    if [ $? -eq 0 ]; then
        print_status 0 "User created successfully"
    else
        print_status 1 "Failed to create user"
        exit 1
    fi
fi

echo ""
echo "Granting privileges..."
echo ""

# Grant replication privileges
echo "1. Granting REPLICATION SLAVE privilege..."
$MYSQL_CMD -e "GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';"
print_status $? "REPLICATION SLAVE granted"

echo "2. Granting REPLICATION CLIENT privilege..."
$MYSQL_CMD -e "GRANT REPLICATION CLIENT ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';"
print_status $? "REPLICATION CLIENT granted"

# Grant SELECT privilege on target database(s)
if [ -n "$MYSQL_DATABASE" ]; then
    echo "3. Granting SELECT privilege on database '${MYSQL_DATABASE}'..."
    $MYSQL_CMD -e "GRANT SELECT ON ${MYSQL_DATABASE}.* TO '${MYSQL_REPLICATION_USER}'@'%';"
    print_status $? "SELECT on ${MYSQL_DATABASE}.* granted"
else
    print_warning "MYSQL_DATABASE not set - you may need to grant SELECT on specific databases"
    echo ""
    echo "To grant SELECT on all databases:"
    echo "  GRANT SELECT ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';"
    echo ""
    read -p "Grant SELECT on all databases? (yes/no): " GRANT_ALL

    if [ "$GRANT_ALL" = "yes" ]; then
        $MYSQL_CMD -e "GRANT SELECT ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';"
        print_status $? "SELECT on *.* granted"
    fi
fi

# Grant RELOAD (needed for table locks during snapshot)
echo "4. Granting RELOAD privilege..."
$MYSQL_CMD -e "GRANT RELOAD ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
if [ $? -eq 0 ]; then
    print_status 0 "RELOAD granted"
else
    print_warning "RELOAD privilege may not be available on managed MySQL"
fi

# Grant SHOW DATABASES (useful for connector)
echo "5. Granting SHOW DATABASES privilege..."
$MYSQL_CMD -e "GRANT SHOW DATABASES ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
if [ $? -eq 0 ]; then
    print_status 0 "SHOW DATABASES granted"
else
    print_warning "SHOW DATABASES privilege may not be available"
fi

# Grant LOCK TABLES (for consistent snapshot)
if [ -n "$MYSQL_DATABASE" ]; then
    echo "6. Granting LOCK TABLES privilege on '${MYSQL_DATABASE}'..."
    $MYSQL_CMD -e "GRANT LOCK TABLES ON ${MYSQL_DATABASE}.* TO '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status 0 "LOCK TABLES granted"
    else
        print_warning "LOCK TABLES privilege may not be available on managed MySQL"
    fi
fi

# Flush privileges
echo ""
echo "Flushing privileges..."
$MYSQL_CMD -e "FLUSH PRIVILEGES;"
print_status $? "Privileges flushed"

echo ""
echo "========================================"
echo "   Verification"
echo "========================================"
echo ""

# Verify user and grants
echo "User grants:"
$MYSQL_CMD -e "SHOW GRANTS FOR '${MYSQL_REPLICATION_USER}'@'%';" | while IFS= read -r line; do
    echo "  $line"
done

echo ""

# Test connection with new user
echo "Testing connection with replication user..."
REPL_MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_REPLICATION_USER} -p${MYSQL_REPLICATION_PASSWORD}"

if $REPL_MYSQL_CMD -e "SELECT 1;" &> /dev/null; then
    print_status 0 "Replication user can connect successfully"
else
    print_status 1 "Replication user cannot connect"
    echo ""
    echo "Please check:"
    echo "  1. Password is correct in .env"
    echo "  2. Host '${MYSQL_HOST}' allows connections from this VPS IP"
    echo "  3. Firewall rules on DigitalOcean allow your VPS"
    exit 1
fi

# Test reading from target database
if [ -n "$MYSQL_DATABASE" ]; then
    echo "Testing SELECT on database '${MYSQL_DATABASE}'..."
    if $REPL_MYSQL_CMD -e "USE ${MYSQL_DATABASE}; SHOW TABLES;" &> /dev/null; then
        print_status 0 "Replication user can read from ${MYSQL_DATABASE}"
    else
        print_status 1 "Replication user cannot read from ${MYSQL_DATABASE}"
    fi
fi

echo ""
echo "========================================"
echo "   Setup Complete"
echo "========================================"
echo ""
echo -e "${GREEN}✓ Replication user '${MYSQL_REPLICATION_USER}' is ready for Debezium${NC}"
echo ""
echo "Next step: Run network validation"
echo "  ./phase1/scripts/04_network_validation.sh"
echo ""

# Save user info
USER_INFO_FILE="/home/user/clickhouse/phase1/replication_user_info.txt"
{
    echo "=== Replication User Info ==="
    echo "Date: $(date)"
    echo ""
    echo "User: ${MYSQL_REPLICATION_USER}"
    echo "Host pattern: %"
    echo ""
    echo "Grants:"
    $MYSQL_CMD -e "SHOW GRANTS FOR '${MYSQL_REPLICATION_USER}'@'%';"
} > "$USER_INFO_FILE"

echo "User info saved to: $USER_INFO_FILE"
echo ""

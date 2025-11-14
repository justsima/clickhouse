#!/bin/bash
# Phase 1 - MySQL Validation Script
# Purpose: Validate MySQL configuration for CDC with Debezium

set -e

# Load environment variables
if [ -f "/home/user/clickhouse/phase1/configs/.env" ]; then
    source /home/user/clickhouse/phase1/configs/.env
else
    echo "ERROR: .env file not found at /home/user/clickhouse/phase1/configs/.env"
    echo "Please copy .env.example to .env and fill in your MySQL credentials"
    exit 1
fi

echo "========================================"
echo "   MySQL Configuration Validation"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    echo -e "${NC}ℹ${NC} $1"
}

# Check if mysql client is available
if ! command -v mysql &> /dev/null; then
    echo -e "${RED}ERROR: mysql client not installed${NC}"
    echo "Please install MySQL client first:"
    echo "  yum install mysql -y"
    echo "  or"
    echo "  dnf install mysql -y"
    exit 1
fi

# MySQL connection string
MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD}"

# Test basic connectivity
echo "1. Testing MySQL Connectivity"
echo "------------------------------"
echo "Host: ${MYSQL_HOST}"
echo "Port: ${MYSQL_PORT}"
echo "User: ${MYSQL_USER}"
echo ""

if $MYSQL_CMD -e "SELECT 1;" &> /dev/null; then
    print_status 0 "Successfully connected to MySQL"
else
    print_status 1 "Failed to connect to MySQL"
    echo ""
    echo "Please verify your credentials in .env file:"
    echo "  MYSQL_HOST=${MYSQL_HOST}"
    echo "  MYSQL_PORT=${MYSQL_PORT}"
    echo "  MYSQL_USER=${MYSQL_USER}"
    exit 1
fi
echo ""

# Check MySQL version
echo "2. MySQL Version Check"
echo "----------------------"
MYSQL_VERSION=$($MYSQL_CMD -e "SELECT VERSION();" -sN)
echo "MySQL Version: ${MYSQL_VERSION}"

if [[ $MYSQL_VERSION == 8.0* ]]; then
    print_status 0 "MySQL 8.0 detected (compatible with Debezium)"
elif [[ $MYSQL_VERSION == 5.7* ]]; then
    print_status 0 "MySQL 5.7 detected (compatible with Debezium)"
else
    print_warning "MySQL version may have compatibility issues with Debezium"
fi
echo ""

# Check binlog format
echo "3. Binlog Configuration Check"
echo "------------------------------"
BINLOG_FORMAT=$($MYSQL_CMD -e "SELECT @@binlog_format;" -sN)
echo "binlog_format: ${BINLOG_FORMAT}"

if [ "$BINLOG_FORMAT" = "ROW" ]; then
    print_status 0 "binlog_format is ROW (required for Debezium)"
else
    print_status 1 "binlog_format is ${BINLOG_FORMAT} (must be ROW)"
    echo ""
    echo "Action required: Contact DO admin to set binlog_format=ROW"
    echo "For managed MySQL, this should be configured in database settings"
fi

# Check binlog_row_image
BINLOG_ROW_IMAGE=$($MYSQL_CMD -e "SELECT @@binlog_row_image;" -sN 2>/dev/null || echo "N/A")
echo "binlog_row_image: ${BINLOG_ROW_IMAGE}"

if [ "$BINLOG_ROW_IMAGE" = "FULL" ] || [ "$BINLOG_ROW_IMAGE" = "full" ]; then
    print_status 0 "binlog_row_image is FULL (optimal for Debezium)"
elif [ "$BINLOG_ROW_IMAGE" = "N/A" ]; then
    print_warning "binlog_row_image not available (MySQL 5.7+ feature)"
else
    print_warning "binlog_row_image is ${BINLOG_ROW_IMAGE} (FULL recommended)"
fi

# Check if binlog is enabled
BINLOG_ENABLED=$($MYSQL_CMD -e "SELECT @@log_bin;" -sN)
echo "log_bin: ${BINLOG_ENABLED}"

if [ "$BINLOG_ENABLED" = "1" ]; then
    print_status 0 "Binary logging is enabled"
else
    print_status 1 "Binary logging is disabled (required for Debezium)"
    echo ""
    echo "Action required: Contact DO admin to enable binary logging"
fi
echo ""

# Check binlog retention (DigitalOcean specific)
echo "4. Binlog Retention Check"
echo "-------------------------"
BINLOG_EXPIRE=$($MYSQL_CMD -e "SELECT @@expire_logs_days;" -sN 2>/dev/null || echo "0")
BINLOG_EXPIRE_SECONDS=$($MYSQL_CMD -e "SELECT @@binlog_expire_logs_seconds;" -sN 2>/dev/null || echo "0")

if [ "$BINLOG_EXPIRE_SECONDS" != "0" ]; then
    RETENTION_DAYS=$((BINLOG_EXPIRE_SECONDS / 86400))
    echo "Binlog retention: ${RETENTION_DAYS} days (${BINLOG_EXPIRE_SECONDS} seconds)"
else
    echo "Binlog retention: ${BINLOG_EXPIRE} days"
    RETENTION_DAYS=$BINLOG_EXPIRE
fi

if [ "$RETENTION_DAYS" -ge 3 ]; then
    print_status 0 "Binlog retention sufficient (${RETENTION_DAYS} days)"
else
    print_warning "Binlog retention may be insufficient (${RETENTION_DAYS} days). 3-7 days recommended for initial snapshot."
fi
echo ""

# Check GTID mode (useful for more reliable replication)
echo "5. GTID Configuration"
echo "---------------------"
GTID_MODE=$($MYSQL_CMD -e "SELECT @@gtid_mode;" -sN 2>/dev/null || echo "OFF")
echo "gtid_mode: ${GTID_MODE}"

if [ "$GTID_MODE" = "ON" ]; then
    print_status 0 "GTID mode enabled (recommended for Debezium)"
else
    print_info "GTID mode is OFF (optional but recommended)"
fi
echo ""

# Check database existence
echo "6. Database Validation"
echo "----------------------"
if [ -n "$MYSQL_DATABASE" ]; then
    DB_EXISTS=$($MYSQL_CMD -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_DATABASE}';" -sN)
    if [ -n "$DB_EXISTS" ]; then
        print_status 0 "Database '${MYSQL_DATABASE}' exists"

        # Count tables
        TABLE_COUNT=$($MYSQL_CMD -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DATABASE}';" -sN)
        echo "Tables in database: ${TABLE_COUNT}"

        # Get approximate row count and size
        DB_SIZE=$($MYSQL_CMD -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as size_mb FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DATABASE}';" -sN)
        echo "Approximate database size: ${DB_SIZE} MB"

    else
        print_status 1 "Database '${MYSQL_DATABASE}' does not exist"
        echo "Available databases:"
        $MYSQL_CMD -e "SHOW DATABASES;" -sN | grep -v "information_schema\|mysql\|performance_schema\|sys"
    fi
else
    print_warning "MYSQL_DATABASE not set in .env"
fi
echo ""

# Check replication user
echo "7. Replication User Check"
echo "-------------------------"
if [ -n "$MYSQL_REPLICATION_USER" ]; then
    USER_EXISTS=$($MYSQL_CMD -e "SELECT User FROM mysql.user WHERE User='${MYSQL_REPLICATION_USER}';" -sN)

    if [ -n "$USER_EXISTS" ]; then
        print_info "Replication user '${MYSQL_REPLICATION_USER}' already exists"
        echo ""
        echo "Checking privileges..."

        # Check privileges
        GRANTS=$($MYSQL_CMD -e "SHOW GRANTS FOR '${MYSQL_REPLICATION_USER}'@'%';" 2>/dev/null || echo "ERROR")

        if [ "$GRANTS" != "ERROR" ]; then
            echo "$GRANTS" | while IFS= read -r line; do
                echo "  $line"
            done

            # Check for required privileges
            if echo "$GRANTS" | grep -qi "REPLICATION SLAVE\|REPLICATION CLIENT"; then
                print_status 0 "User has replication privileges"
            else
                print_warning "User may be missing replication privileges"
            fi

            if echo "$GRANTS" | grep -qi "SELECT.*\*\.\*\|ALL PRIVILEGES"; then
                print_status 0 "User has SELECT privileges"
            else
                print_warning "User may need SELECT privileges on target databases"
            fi
        fi
    else
        print_info "Replication user '${MYSQL_REPLICATION_USER}' does not exist yet"
        echo ""
        echo "To create the replication user, run script: 03_create_replication_user.sh"
    fi
else
    print_warning "MYSQL_REPLICATION_USER not set in .env"
fi
echo ""

# Test connectivity with replication user (if credentials provided)
if [ -n "$MYSQL_REPLICATION_USER" ] && [ -n "$MYSQL_REPLICATION_PASSWORD" ]; then
    echo "8. Testing Replication User Connectivity"
    echo "-----------------------------------------"

    REPL_MYSQL_CMD="mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_REPLICATION_USER} -p${MYSQL_REPLICATION_PASSWORD}"

    if $REPL_MYSQL_CMD -e "SELECT 1;" &> /dev/null; then
        print_status 0 "Replication user can connect successfully"
    else
        print_info "Replication user cannot connect yet (user may not be created)"
    fi
    echo ""
fi

# Save validation report
echo "9. Saving Validation Report"
echo "---------------------------"
REPORT_FILE="/home/user/clickhouse/phase1/mysql_validation_report.txt"
{
    echo "=== MySQL Validation Report ==="
    echo "Date: $(date)"
    echo ""
    echo "Connection Info:"
    echo "  Host: ${MYSQL_HOST}"
    echo "  Port: ${MYSQL_PORT}"
    echo "  Database: ${MYSQL_DATABASE}"
    echo ""
    echo "MySQL Version: ${MYSQL_VERSION}"
    echo ""
    echo "Binlog Configuration:"
    echo "  log_bin: ${BINLOG_ENABLED}"
    echo "  binlog_format: ${BINLOG_FORMAT}"
    echo "  binlog_row_image: ${BINLOG_ROW_IMAGE}"
    echo "  Retention: ${RETENTION_DAYS} days"
    echo ""
    echo "GTID Mode: ${GTID_MODE}"
    echo ""
    echo "Database Info:"
    echo "  Tables: ${TABLE_COUNT}"
    echo "  Size: ${DB_SIZE} MB"
    echo ""
    echo "Replication User: ${MYSQL_REPLICATION_USER}"
    echo "  Exists: ${USER_EXISTS:-No}"
} > "$REPORT_FILE"

print_status 0 "Validation report saved to $REPORT_FILE"
echo ""

# Final summary
echo "========================================"
echo "   Validation Summary"
echo "========================================"
echo ""

CRITICAL_CHECKS=0

if [ "$BINLOG_FORMAT" != "ROW" ]; then
    echo -e "${RED}CRITICAL: binlog_format must be ROW${NC}"
    CRITICAL_CHECKS=$((CRITICAL_CHECKS + 1))
fi

if [ "$BINLOG_ENABLED" != "1" ]; then
    echo -e "${RED}CRITICAL: Binary logging must be enabled${NC}"
    CRITICAL_CHECKS=$((CRITICAL_CHECKS + 1))
fi

if [ -z "$USER_EXISTS" ]; then
    echo -e "${YELLOW}ACTION REQUIRED: Create replication user (run 03_create_replication_user.sh)${NC}"
fi

if [ $CRITICAL_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ MySQL configuration is ready for CDC${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Create replication user (if not exists): ./phase1/scripts/03_create_replication_user.sh"
    echo "  2. Run network validation: ./phase1/scripts/04_network_validation.sh"
else
    echo -e "${RED}✗ ${CRITICAL_CHECKS} critical issue(s) found${NC}"
    echo ""
    echo "Please resolve critical issues before proceeding."
    echo "For DigitalOcean Managed MySQL, check your database configuration panel."
fi
echo ""

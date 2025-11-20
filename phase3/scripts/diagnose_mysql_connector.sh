#!/bin/bash
# Diagnostic Script for MySQL Source Connector Task Issues
# Purpose: Identify why MySQL source connector shows RUNNING but has 0 tasks

set +e

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

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

print_section "MySQL Source Connector Diagnostics"

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    print_info "Loaded configuration from .env"
else
    print_error ".env file not found"
    exit 1
fi

echo ""
print_section "1. Connector Status Check"

# Check connector exists
CONNECTOR_EXISTS=$(curl -s http://localhost:8083/connectors | grep -c "mysql-source-connector")
if [ "$CONNECTOR_EXISTS" -eq 0 ]; then
    print_error "Connector 'mysql-source-connector' not found"
    echo "Available connectors:"
    curl -s http://localhost:8083/connectors | python3 -m json.tool 2>/dev/null
    exit 1
else
    print_status 0 "Connector exists"
fi

# Get full status
echo ""
print_info "Full connector status:"
curl -s http://localhost:8083/connectors/mysql-source-connector/status | python3 -m json.tool 2>/dev/null

# Check task count
TASK_COUNT=$(curl -s http://localhost:8083/connectors/mysql-source-connector/status | grep -o '"tasks":\[.*\]' | grep -o '"id":[0-9]*' | wc -l)
echo ""
print_info "Task count: $TASK_COUNT (expected: 1)"

if [ "$TASK_COUNT" -eq 0 ]; then
    echo -e "${RED}⚠ PROBLEM: No tasks created!${NC}"
else
    print_status 0 "Tasks are created"
fi

echo ""
print_section "2. MySQL Connectivity Test"

print_info "Testing MySQL connection from Kafka Connect container..."

# Test basic connectivity
MYSQL_TEST=$(docker exec kafka-connect-clickhouse timeout 10 bash -c "
    curl -s --connect-timeout 5 telnet://${MYSQL_HOST}:${MYSQL_PORT} 2>&1 && echo 'PORT_OPEN' || echo 'PORT_CLOSED'
" 2>/dev/null | grep -q "PORT_OPEN" && echo "SUCCESS" || echo "FAILED")

if [ "$MYSQL_TEST" = "SUCCESS" ]; then
    print_status 0 "Can reach MySQL host:port"
else
    print_status 1 "Cannot reach MySQL at ${MYSQL_HOST}:${MYSQL_PORT}"
    echo "  This could be a network/firewall issue"
fi

# Test MySQL login (if mysql client available)
print_info "Testing MySQL credentials..."
MYSQL_LOGIN=$(docker exec kafka-connect-clickhouse timeout 10 bash -c "
    command -v mysql >/dev/null 2>&1 && \
    mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e 'SELECT 1' 2>&1 | grep -q '1' && \
    echo 'SUCCESS' || echo 'FAILED'
" 2>/dev/null || echo "MYSQL_CLIENT_NOT_INSTALLED")

if [ "$MYSQL_LOGIN" = "SUCCESS" ]; then
    print_status 0 "MySQL credentials work"
elif [ "$MYSQL_LOGIN" = "MYSQL_CLIENT_NOT_INSTALLED" ]; then
    echo -e "${YELLOW}⚠ MySQL client not in container, skipping credential test${NC}"
else
    print_status 1 "MySQL login failed"
    echo "  Check MYSQL_USER and MYSQL_PASSWORD in .env"
fi

echo ""
print_section "3. Connector Configuration Check"

print_info "Current connector configuration:"
curl -s http://localhost:8083/connectors/mysql-source-connector | python3 -m json.tool 2>/dev/null | grep -A 20 '"config"'

echo ""
print_info "Key configuration values:"
echo "  Database host: $MYSQL_HOST"
echo "  Database port: $MYSQL_PORT"
echo "  Database: $MYSQL_DATABASE"
echo "  Tasks max: $(curl -s http://localhost:8083/connectors/mysql-source-connector | python3 -c 'import sys,json; print(json.load(sys.stdin)["config"].get("tasks.max", "NOT SET"))' 2>/dev/null)"

echo ""
print_section "4. Kafka Connect Logs Analysis"

print_info "Searching for MySQL connector errors in logs..."
echo ""

# Check for task assignment errors
echo "Task assignment errors:"
docker logs kafka-connect-clickhouse 2>&1 | grep -i "mysql-source" | grep -iE "task|error|fail|exception" | tail -20 || echo "  (none found)"

echo ""
echo "Recent connector activity:"
docker logs kafka-connect-clickhouse 2>&1 | grep -i "mysql-source-connector" | tail -30 || echo "  (no recent activity)"

echo ""
echo "All ERROR lines from last 100 log entries:"
docker logs kafka-connect-clickhouse 2>&1 | tail -100 | grep -i "ERROR" || echo "  (no errors)"

echo ""
print_section "5. Connector Plugin Verification"

print_info "Checking if Debezium MySQL connector plugin is loaded..."
PLUGIN_LOADED=$(curl -s http://localhost:8083/connector-plugins | grep -c "MySqlConnector")

if [ "$PLUGIN_LOADED" -gt 0 ]; then
    print_status 0 "Debezium MySQL connector plugin is loaded"
    echo ""
    echo "Plugin details:"
    curl -s http://localhost:8083/connector-plugins | python3 -m json.tool 2>/dev/null | grep -A 3 "MySql"
else
    print_status 1 "Debezium MySQL connector plugin NOT found"
    echo ""
    echo "Available plugins:"
    curl -s http://localhost:8083/connector-plugins | python3 -m json.tool 2>/dev/null
fi

echo ""
print_section "6. Diagnostic Summary"

echo "Issues Found:"
echo ""

ISSUES_FOUND=0

# Check 1: Tasks
if [ "$TASK_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ CRITICAL: No tasks created${NC}"
    echo "  Expected: 1 task (configured in tasks.max)"
    echo "  Actual: 0 tasks"
    echo "  Impact: Connector won't read from MySQL"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check 2: MySQL connectivity
if [ "$MYSQL_TEST" != "SUCCESS" ]; then
    echo -e "${RED}✗ WARNING: MySQL connectivity issue${NC}"
    echo "  Cannot reach MySQL at ${MYSQL_HOST}:${MYSQL_PORT}"
    echo "  Possible causes:"
    echo "    - Firewall blocking connection"
    echo "    - MySQL server down"
    echo "    - Incorrect host/port in .env"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check 3: Plugin loaded
if [ "$PLUGIN_LOADED" -eq 0 ]; then
    echo -e "${RED}✗ CRITICAL: Debezium MySQL plugin not loaded${NC}"
    echo "  The MySqlConnector plugin is not available"
    echo "  Connector cannot function without it"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✓ No obvious configuration issues found${NC}"
    echo ""
    echo "The connector may be experiencing an internal error."
    echo "Recommended actions:"
    echo "  1. Check full Kafka Connect logs: docker logs kafka-connect-clickhouse | less"
    echo "  2. Try restarting the connector: curl -X POST http://localhost:8083/connectors/mysql-source-connector/restart"
    echo "  3. If issues persist, delete and redeploy connector"
else
    echo ""
    echo -e "${RED}Found $ISSUES_FOUND issue(s) that need attention${NC}"
fi

echo ""
print_section "7. Recommended Actions"

if [ "$TASK_COUNT" -eq 0 ]; then
    echo "To fix the 0 tasks issue:"
    echo ""
    echo "Option 1: Delete and redeploy connector"
    echo "  curl -X DELETE http://localhost:8083/connectors/mysql-source-connector"
    echo "  cd $SCRIPT_DIR"
    echo "  ./03_deploy_connectors.sh"
    echo ""
    echo "Option 2: Check if MySQL binlog is enabled"
    echo "  MySQL must have binlog enabled for Debezium to work"
    echo "  Check with: SHOW VARIABLES LIKE 'log_bin';"
    echo ""
    echo "Option 3: Verify MySQL user permissions"
    echo "  User needs: SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT"
    echo ""
fi

echo ""
print_info "Diagnostic complete. Review the output above for issues."

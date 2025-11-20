#!/bin/bash
# Phase 3 Readiness Verification
# Checks if Phase 2 is complete and Phase 3 can proceed

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

ISSUES=0

print_section "Phase 3 Readiness Check"

echo "This verifies Phase 2 is complete and Phase 3 can proceed."
echo ""

print_section "1. Phase 2 Services Health"

# Check Kafka Connect API
if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
    print_status 0 "Kafka Connect API responding on port 8085"
    VERSION=$(curl -s http://localhost:8085/ 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    echo "  Version: $VERSION"
else
    print_status 1 "Kafka Connect API NOT responding"
    ISSUES=$((ISSUES + 1))
fi

# Check Redpanda
if docker exec redpanda-clickhouse rpk cluster info &>/dev/null; then
    print_status 0 "Redpanda broker responding"
else
    print_status 1 "Redpanda broker NOT responding"
    ISSUES=$((ISSUES + 1))
fi

# Check ClickHouse
if curl -s "http://localhost:8123/ping" 2>/dev/null | grep -q "Ok"; then
    print_status 0 "ClickHouse HTTP responding"
else
    print_status 1 "ClickHouse HTTP NOT responding"
    ISSUES=$((ISSUES + 1))
fi

print_section "2. Phase 3 Configuration Files"

cd /home/centos/clickhouse/phase3/configs

echo "Checking connector configuration files..."
echo ""

# MySQL source connector
if [ -f "debezium-mysql-source.json" ]; then
    print_status 0 "MySQL source config exists"

    # Check for critical fields
    if grep -q "io.debezium.connector.mysql.MySqlConnector" debezium-mysql-source.json; then
        print_status 0 "  Correct connector class"
    else
        print_status 1 "  Wrong connector class"
        ISSUES=$((ISSUES + 1))
    fi

    if grep -q "\"tasks.max\".*:.*\"1\"" debezium-mysql-source.json; then
        print_status 0 "  tasks.max = 1 (correct for MySQL)"
    else
        print_status 1 "  tasks.max incorrect"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_status 1 "MySQL source config MISSING"
    ISSUES=$((ISSUES + 1))
fi

echo ""

# ClickHouse sink connector
if [ -f "clickhouse-sink.json" ]; then
    print_status 0 "ClickHouse sink config exists"

    if grep -q "com.clickhouse.kafka.connect.ClickHouseSinkConnector" clickhouse-sink.json; then
        print_status 0 "  Correct connector class"
    else
        print_status 1 "  Wrong connector class"
        ISSUES=$((ISSUES + 1))
    fi

    if grep -q "\"tasks.max\".*:.*\"4\"" clickhouse-sink.json; then
        print_status 0 "  tasks.max = 4 (good for parallelism)"
    else
        echo -e "${YELLOW}⚠ tasks.max not 4 (not critical)${NC}"
    fi
else
    print_status 1 "ClickHouse sink config MISSING"
    ISSUES=$((ISSUES + 1))
fi

print_section "3. Phase 3 Scripts"

cd /home/centos/clickhouse/phase3/scripts

echo "Checking deployment scripts exist..."
echo ""

for script in 03_deploy_connectors.sh 04_monitor_snapshot.sh; do
    if [ -f "$script" ]; then
        print_status 0 "$script exists"

        # Check if using correct port
        if grep -q "http://localhost:8085" "$script"; then
            print_status 0 "  Uses correct port 8085"
        else
            print_status 1 "  Uses wrong port (not 8085)"
            ISSUES=$((ISSUES + 1))
        fi
    else
        print_status 1 "$script MISSING"
        ISSUES=$((ISSUES + 1))
    fi
done

print_section "4. MySQL Source Database"

echo "Checking MySQL source database connectivity..."
echo ""

# Check if mysql-container is accessible
MYSQL_HOST=$(grep "^MYSQL_HOST=" /home/centos/clickhouse/.env 2>/dev/null | cut -d'=' -f2)
MYSQL_PORT=$(grep "^MYSQL_PORT=" /home/centos/clickhouse/.env 2>/dev/null | cut -d'=' -f2)

echo "MySQL from .env:"
echo "  Host: $MYSQL_HOST"
echo "  Port: $MYSQL_PORT"
echo ""

if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_PORT" ]; then
    # Try to connect from kafka-connect container
    TEST_CONN=$(docker exec kafka-connect-clickhouse sh -c "timeout 5 bash -c '</dev/tcp/${MYSQL_HOST}/${MYSQL_PORT}'" 2>&1)

    if [ $? -eq 0 ]; then
        print_status 0 "Kafka Connect can reach MySQL at $MYSQL_HOST:$MYSQL_PORT"
    else
        print_status 1 "Kafka Connect CANNOT reach MySQL at $MYSQL_HOST:$MYSQL_PORT"
        echo "  Error: $TEST_CONN"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_status 1 "MySQL connection details missing from .env"
    ISSUES=$((ISSUES + 1))
fi

print_section "5. ClickHouse Target Database"

echo "Checking ClickHouse database and tables..."
echo ""

# Check if mulasport database exists
CH_USER=$(grep "^CLICKHOUSE_USER=" /home/centos/clickhouse/.env 2>/dev/null | cut -d'=' -f2)
CH_PASS=$(grep "^CLICKHOUSE_PASSWORD=" /home/centos/clickhouse/.env 2>/dev/null | cut -d'=' -f2)

CH_DATABASE=$(grep "^CLICKHOUSE_DATABASE=" /home/centos/clickhouse/.env 2>/dev/null | cut -d'=' -f2)
CH_DATABASE=${CH_DATABASE:-analytics}

if [ -n "$CH_USER" ] && [ -n "$CH_PASS" ]; then
    # Test with credentials
    DB_CHECK=$(curl -s -u "${CH_USER}:${CH_PASS}" "http://localhost:8123/?query=SELECT name FROM system.databases WHERE name='${CH_DATABASE}'" 2>/dev/null)

    if echo "$DB_CHECK" | grep -q "${CH_DATABASE}"; then
        print_status 0 "${CH_DATABASE} database exists"

        # Count tables
        TABLE_COUNT=$(curl -s -u "${CH_USER}:${CH_PASS}" "http://localhost:8123/?query=SELECT count() FROM system.tables WHERE database='${CH_DATABASE}'" 2>/dev/null)

        if [ "$TABLE_COUNT" -gt 0 ]; then
            print_status 0 "Tables in ${CH_DATABASE}: $TABLE_COUNT"

            if [ "$TABLE_COUNT" -ge 400 ]; then
                print_status 0 "Table count looks good (≥400)"
            else
                echo -e "${YELLOW}⚠ Only $TABLE_COUNT tables (expected ~450)${NC}"
            fi
        else
            print_status 1 "No tables in ${CH_DATABASE} database"
            ISSUES=$((ISSUES + 1))
        fi
    else
        print_status 1 "${CH_DATABASE} database does NOT exist"
        echo "  Need to run Phase 1: schema creation"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo -e "${YELLOW}⚠ ClickHouse credentials not found in .env${NC}"
    echo "  Trying without credentials..."

    DB_CHECK=$(curl -s "http://localhost:8123/?query=SELECT name FROM system.databases WHERE name='${CH_DATABASE}'" 2>/dev/null)
    if echo "$DB_CHECK" | grep -q "${CH_DATABASE}"; then
        print_status 0 "${CH_DATABASE} database exists"
    else
        print_status 1 "Cannot verify ${CH_DATABASE} database"
        ISSUES=$((ISSUES + 1))
    fi
fi

print_section "6. Environment Variables"

echo "Checking .env file..."
echo ""

if [ -f "/home/centos/clickhouse/.env" ]; then
    print_status 0 ".env file exists"

    # Check critical variables
    REQUIRED_VARS="MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD CLICKHOUSE_HOST CLICKHOUSE_PORT"

    for var in $REQUIRED_VARS; do
        if grep -q "^${var}=" /home/centos/clickhouse/.env; then
            VALUE=$(grep "^${var}=" /home/centos/clickhouse/.env | cut -d'=' -f2)
            if [ -n "$VALUE" ]; then
                print_status 0 "  $var is set"
            else
                print_status 1 "  $var is EMPTY"
                ISSUES=$((ISSUES + 1))
            fi
        else
            print_status 1 "  $var is MISSING"
            ISSUES=$((ISSUES + 1))
        fi
    done
else
    print_status 1 ".env file MISSING"
    ISSUES=$((ISSUES + 1))
fi

print_section "7. ClickHouse Connector Plugin"

echo "Checking if ClickHouse connector plugin will be installed..."
echo ""

# Check if install script exists
if [ -f "/home/centos/clickhouse/phase3/scripts/install_clickhouse_connector.sh" ]; then
    print_status 0 "ClickHouse connector installer exists"
else
    print_status 1 "ClickHouse connector installer MISSING"
    ISSUES=$((ISSUES + 1))
fi

# Check if JAR download URL is configured
if [ -f "/home/centos/clickhouse/phase3/scripts/03_deploy_connectors.sh" ]; then
    if grep -q "clickhouse-kafka-connect" 03_deploy_connectors.sh; then
        print_status 0 "Deployment script has ClickHouse connector logic"
    else
        echo -e "${YELLOW}⚠ ClickHouse connector may not be configured${NC}"
    fi
fi

print_section "8. Ready to Deploy?"

echo ""

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ ALL CHECKS PASSED - READY FOR PHASE 3!${NC}"
    echo ""
    echo "Phase 2 is complete and verified."
    echo "All prerequisites for Phase 3 are met."
    echo ""
    echo -e "${BOLD}Next step:${NC}"
    echo "  cd /home/centos/clickhouse/phase3/scripts"
    echo "  ./03_deploy_connectors.sh"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}✗ FOUND $ISSUES ISSUE(S) - NOT READY FOR PHASE 3${NC}"
    echo ""
    echo "Fix the issues above before deploying connectors."
    echo ""
    exit 1
fi

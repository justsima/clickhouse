#!/bin/bash
# Test MySQL Connection from Kafka Connect Container
# Purpose: Verify network connectivity and credentials

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

# Load .env
source "$PROJECT_ROOT/.env"

echo "=========================================="
echo "   MySQL Connection Test"
echo "=========================================="
echo ""
echo "Testing connection to:"
echo "  Host: $MYSQL_HOST"
echo "  Port: $MYSQL_PORT"
echo "  User: $MYSQL_USER"
echo "  Database: $MYSQL_DATABASE"
echo ""

echo "1. Testing from HOST (your VPS)"
echo "-----------------------------------"
if docker exec clickhouse-server mysql \
    -h"$MYSQL_HOST" \
    -P"$MYSQL_PORT" \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" \
    -e "SELECT 'Connection OK from HOST' as status;" 2>/dev/null; then
    echo "✓ Connection works from VPS host"
else
    echo "✗ Connection FAILED from VPS host"
    echo "This means your .env credentials are wrong or MySQL is unreachable"
fi

echo ""
echo "2. Testing from Kafka Connect Container"
echo "-----------------------------------"

# Check if mysql client is installed in kafka-connect container
echo "Installing mysql client in Kafka Connect container..."
docker exec -u root kafka-connect-clickhouse bash -c "
    if ! command -v mysql &> /dev/null; then
        apt-get update -qq && apt-get install -y -qq default-mysql-client > /dev/null 2>&1
    fi
"

if docker exec kafka-connect-clickhouse mysql \
    -h"$MYSQL_HOST" \
    -P"$MYSQL_PORT" \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASSWORD" \
    -e "SELECT 'Connection OK from Kafka Connect' as status;" 2>/dev/null; then
    echo "✓ Connection works from Kafka Connect container"
    echo ""
    echo "GOOD NEWS! Your credentials and network are fine."
    echo "The Debezium error might be a temporary issue."
else
    echo "✗ Connection FAILED from Kafka Connect container"
    echo ""
    echo "PROBLEM: Kafka Connect container cannot reach MySQL"
    echo ""
    echo "Possible causes:"
    echo "  1. Docker network isolation"
    echo "  2. DigitalOcean firewall blocking Docker container's IP"
    echo "  3. Network configuration issue"
    echo ""
    echo "Solutions:"
    echo "  Option A: Add your VPS IP to MySQL trusted sources in DigitalOcean"
    echo "  Option B: Use host network mode for Kafka Connect"
fi

echo ""
echo "3. Testing DNS Resolution"
echo "-----------------------------------"
docker exec kafka-connect-clickhouse nslookup "$MYSQL_HOST" || echo "DNS lookup failed"

echo ""
echo "4. Testing TCP Connection"
echo "-----------------------------------"
if docker exec kafka-connect-clickhouse timeout 5 bash -c "cat < /dev/null > /dev/tcp/$MYSQL_HOST/$MYSQL_PORT" 2>/dev/null; then
    echo "✓ TCP connection to port $MYSQL_PORT successful"
else
    echo "✗ TCP connection to port $MYSQL_PORT failed"
    echo "This confirms network/firewall issue"
fi

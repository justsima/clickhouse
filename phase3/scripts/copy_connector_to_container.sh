#!/bin/bash
# Copy existing ClickHouse connector to Kafka Connect container

set -e

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

echo "========================================"
echo "   Copy ClickHouse Connector to Container"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PHASE3_DIR")"

# Source connector location
CONNECTOR_DIR="$PHASE3_DIR/connectors"
CONNECTOR_JAR="$CONNECTOR_DIR/clickhouse-kafka-connect-v1.3.4-confluent.jar"

# Check if connector exists
if [ ! -f "$CONNECTOR_JAR" ]; then
    print_status 1 "Connector JAR not found at $CONNECTOR_JAR"
    exit 1
fi

print_status 0 "Found connector: $(basename $CONNECTOR_JAR)"
FILESIZE=$(stat -c%s "$CONNECTOR_JAR" 2>/dev/null || stat -f%z "$CONNECTOR_JAR" 2>/dev/null)
echo "  Size: $(($FILESIZE / 1024 / 1024)) MB"
echo ""

# Create directory in container
print_info "Creating directory in kafka-connect-clickhouse container..."
docker exec kafka-connect-clickhouse mkdir -p /kafka/connect/clickhouse-kafka

if [ $? -eq 0 ]; then
    print_status 0 "Directory created"
else
    print_status 1 "Failed to create directory"
    exit 1
fi

echo ""

# Copy connector to container
print_info "Copying connector to container..."
docker cp "$CONNECTOR_JAR" kafka-connect-clickhouse:/kafka/connect/clickhouse-kafka/clickhouse-kafka-connect.jar

if [ $? -eq 0 ]; then
    print_status 0 "Connector copied successfully"
else
    print_status 1 "Failed to copy connector"
    exit 1
fi

echo ""

# Verify file in container
print_info "Verifying connector in container..."
CONTAINER_SIZE=$(docker exec kafka-connect-clickhouse stat -c%s /kafka/connect/clickhouse-kafka/clickhouse-kafka-connect.jar 2>/dev/null)

if [ "$CONTAINER_SIZE" -gt 1000000 ]; then
    print_status 0 "Connector verified in container ($(($CONTAINER_SIZE / 1024 / 1024)) MB)"
else
    print_status 1 "Connector file seems too small or missing"
    exit 1
fi

echo ""

# Restart Kafka Connect
print_info "Restarting Kafka Connect to load connector..."
docker restart kafka-connect-clickhouse >/dev/null 2>&1

echo ""
print_info "Waiting for Kafka Connect to be ready..."
for i in {1..24}; do
    if curl -s http://localhost:8085/ 2>/dev/null | grep -q "version"; then
        print_status 0 "Kafka Connect ready"
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

echo ""
print_info "Verifying connector plugin is available..."
sleep 5

if curl -s http://localhost:8085/connector-plugins 2>/dev/null | grep -q "ClickHouseSinkConnector"; then
    print_status 0 "ClickHouse Kafka Connect Sink connector is available!"
    echo ""
    echo "Connector details:"
    curl -s http://localhost:8085/connector-plugins 2>/dev/null | python3 -m json.tool | grep -A 5 "ClickHouse"
    echo ""
    echo "========================================"
    echo "   Installation Complete!"
    echo "========================================"
    echo ""
    echo "Next step: Deploy connectors"
    echo "  cd $SCRIPT_DIR"
    echo "  ./03_deploy_connectors.sh"
else
    print_status 1 "Connector not found in plugins"
    echo ""
    echo "Checking what plugins are available:"
    curl -s http://localhost:8085/connector-plugins 2>/dev/null | python3 -m json.tool
    exit 1
fi

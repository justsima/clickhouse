#!/bin/bash
# Manual ClickHouse Kafka Connect Connector Installation
# More robust method with proper error handling

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
echo "   ClickHouse Connector Manual Install"
echo "========================================"
echo ""

# Check if connector already exists
if docker exec kafka-connect-clickhouse ls /kafka/connect/clickhouse-kafka/*.jar &>/dev/null 2>&1; then
    print_info "Connector already installed:"
    docker exec kafka-connect-clickhouse ls -lh /kafka/connect/clickhouse-kafka/*.jar
    echo ""
    read -p "Reinstall anyway? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Skipping installation."
        exit 0
    fi
fi

print_info "Installing ClickHouse Kafka Connect connector..."
echo ""

# Method 1: Try GitHub releases (all-in-one JAR from releases page)
print_info "Method 1: Trying GitHub releases..."
docker exec kafka-connect-clickhouse bash -c '
    mkdir -p /kafka/connect/clickhouse-kafka &&
    cd /kafka/connect/clickhouse-kafka &&
    # Download the all-in-one shaded JAR
    curl -L -o clickhouse-kafka-connect.jar \
      "https://github.com/ClickHouse/clickhouse-kafka-connect/releases/download/v1.0.13/clickhouse-kafka-connect-1.0.13-all.jar" 2>&1
' | grep -v "^\s*$"

# Verify installation
if docker exec kafka-connect-clickhouse test -f /kafka/connect/clickhouse-kafka/clickhouse-kafka-connect.jar; then
    FILESIZE=$(docker exec kafka-connect-clickhouse stat -c%s /kafka/connect/clickhouse-kafka/clickhouse-kafka-connect.jar)

    if [ "$FILESIZE" -gt 1000000 ]; then
        print_status 0 "Connector installed successfully ($(($FILESIZE / 1024 / 1024)) MB)"

        echo ""
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
        print_info "Verifying connector is available..."
        sleep 5

        if curl -s http://localhost:8085/connector-plugins 2>/dev/null | grep -q "ClickHouseSinkConnector"; then
            print_status 0 "ClickHouse Kafka Connect Sink connector is available!"
            echo ""
            echo "Connector details:"
            curl -s http://localhost:8085/connector-plugins 2>/dev/null | grep -A 2 "ClickHouse"
            echo ""
            echo "========================================"
            echo "   Installation Complete!"
            echo "========================================"
            echo ""
            echo "Next step: Deploy connectors"
            echo "  cd /home/centos/clickhouse/phase3/scripts"
            echo "  ./03_deploy_connectors.sh"
        else
            print_status 1 "Connector not found in plugins"
            echo "Connector file exists but may not be loaded correctly"
            echo "Try restarting Kafka Connect manually:"
            echo "  docker restart kafka-connect-clickhouse"
        fi
    else
        print_status 1 "Downloaded file too small ($FILESIZE bytes)"
        exit 1
    fi
else
    print_status 1 "Installation failed"
    echo ""
    echo "Manual installation steps:"
    echo "1. Download connector JAR manually"
    echo "2. Copy to container:"
    echo "   docker cp clickhouse-kafka-connect.jar kafka-connect-clickhouse:/kafka/connect/clickhouse-kafka/"
    echo "3. Restart: docker restart kafka-connect-clickhouse"
    exit 1
fi

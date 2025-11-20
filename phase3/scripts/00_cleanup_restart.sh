#!/bin/bash
# Complete Cleanup Script - Start Fresh
# Purpose: Clean all connectors, topics, and ClickHouse data for fresh start

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "========================================"
echo "   Complete System Cleanup"
echo "========================================"
echo ""

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}ERROR:${NC} .env file not found"
    exit 1
fi

print_warning "This will delete ALL data and start fresh!"
echo ""
echo "This will clean:"
echo "  - All Kafka Connect connectors"
echo "  - All Kafka/Redpanda topics"
echo "  - All ClickHouse data in analytics database"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "1. Stopping Kafka Connect Connectors"
echo "-------------------------------------"

CONNECT_URL="http://localhost:8085"

# Get list of connectors
CONNECTORS=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null)

if [ -n "$CONNECTORS" ] && [ "$CONNECTORS" != "[]" ]; then
    echo "$CONNECTORS" | grep -o '"[^"]*"' | tr -d '"' | while read connector; do
        if [ -n "$connector" ]; then
            print_info "Deleting connector: $connector"
            curl -s -X DELETE "$CONNECT_URL/connectors/$connector" 2>/dev/null
            sleep 1
        fi
    done
    print_status 0 "All connectors deleted"
else
    print_info "No connectors to delete"
fi

echo ""
echo "2. Deleting All Kafka Topics"
echo "-----------------------------"

# Get list of topics with mysql prefix
TOPICS=$(docker exec redpanda-clickhouse rpk topic list 2>/dev/null | grep "mysql\." || true)

if [ -n "$TOPICS" ]; then
    TOPIC_COUNT=$(echo "$TOPICS" | wc -l)
    print_info "Found $TOPIC_COUNT topics to delete"

    echo "$TOPICS" | awk '{print $1}' | while read topic; do
        if [ -n "$topic" ]; then
            docker exec redpanda-clickhouse rpk topic delete "$topic" 2>/dev/null || true
        fi
    done

    print_status 0 "All MySQL topics deleted"
else
    print_info "No MySQL topics to delete"
fi

# Also delete internal Kafka Connect topics
print_info "Cleaning Kafka Connect internal topics..."
docker exec redpanda-clickhouse rpk topic delete "clickhouse_connect_configs" 2>/dev/null || true
docker exec redpanda-clickhouse rpk topic delete "clickhouse_connect_offsets" 2>/dev/null || true
docker exec redpanda-clickhouse rpk topic delete "clickhouse_connect_status" 2>/dev/null || true
docker exec redpanda-clickhouse rpk topic delete "schema-changes.mysql" 2>/dev/null || true
docker exec redpanda-clickhouse rpk topic delete "clickhouse-dlq" 2>/dev/null || true

echo ""
echo "3. Cleaning ClickHouse Analytics Database"
echo "------------------------------------------"

CH_PASSWORD="${CLICKHOUSE_PASSWORD:-ClickHouse_Secure_Pass_2024!}"

# Drop and recreate analytics database
print_info "Dropping analytics database..."
docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" \
    --query "DROP DATABASE IF EXISTS analytics" 2>/dev/null

sleep 2

print_info "Recreating analytics database..."
docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" \
    --query "CREATE DATABASE analytics" 2>/dev/null

print_status 0 "ClickHouse analytics database cleaned"

echo ""
echo "4. Restarting Kafka Connect"
echo "---------------------------"

print_info "Restarting Kafka Connect to clear state..."
docker restart kafka-connect-clickhouse >/dev/null 2>&1

print_info "Waiting for Kafka Connect to be ready..."
for i in {1..12}; do
    if curl -s "$CONNECT_URL/" | grep -q "version"; then
        print_status 0 "Kafka Connect ready"
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

echo ""
echo "5. Verification"
echo "---------------"

# Check topics
REMAINING_TOPICS=$(docker exec redpanda-clickhouse rpk topic list 2>/dev/null | grep -c "mysql\." || echo "0")
print_info "Remaining MySQL topics: $REMAINING_TOPICS (should be 0)"

# Check connectors
REMAINING_CONNECTORS=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null | grep -o '"' | wc -l)
print_info "Remaining connectors: $(($REMAINING_CONNECTORS / 2)) (should be 0)"

# Check ClickHouse tables
CH_TABLES=$(docker exec clickhouse-server clickhouse-client --password "$CH_PASSWORD" \
    --query "SELECT COUNT(*) FROM system.tables WHERE database = 'analytics'" 2>/dev/null)
print_info "ClickHouse tables in analytics: $CH_TABLES (should be 0)"

echo ""
echo "========================================"
echo "   Cleanup Complete!"
echo "========================================"
echo ""
echo "System is now clean and ready for fresh start."
echo ""
echo "Next steps:"
echo "  1. Pull latest code: git pull origin <branch>"
echo "  2. Recreate ClickHouse schema: ./02_create_clickhouse_schema.sh"
echo "  3. Deploy connectors: ./03_deploy_connectors.sh"
echo "  4. Monitor progress: ./04_monitor_snapshot.sh"
echo ""

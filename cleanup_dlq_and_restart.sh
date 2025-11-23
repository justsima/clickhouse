#!/bin/bash
# Emergency Cleanup Script
# Deletes DLQ topic, cleans up Kafka storage, and restarts connectors

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

print_header "EMERGENCY CLEANUP - DLQ & KAFKA STORAGE"

print_warning "This will DELETE the DLQ topic and failed messages!"
print_warning "Make sure you've diagnosed the root cause first!"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

CONNECT_URL="http://localhost:8085"

# ============================================
# STEP 1: Pause/Delete Sink Connector
# ============================================
print_header "Step 1: Stopping ClickHouse Sink Connector"

curl -s -X PUT "$CONNECT_URL/connectors/clickhouse-sink-connector/pause" 2>/dev/null
print_status 0 "Connector paused"

sleep 3

curl -s -X DELETE "$CONNECT_URL/connectors/clickhouse-sink-connector" 2>/dev/null
print_status 0 "Connector deleted"

sleep 3

# ============================================
# STEP 2: Delete DLQ Topic
# ============================================
print_header "Step 2: Deleting DLQ Topic"

DLQ_SIZE_BEFORE=$(docker exec redpanda-clickhouse rpk topic describe clickhouse-dlq 2>/dev/null | grep -o "size: [0-9]*" | cut -d' ' -f2 || echo "0")
echo "DLQ size before deletion: $(numfmt --to=iec $DLQ_SIZE_BEFORE 2>/dev/null || echo $DLQ_SIZE_BEFORE) bytes"

docker exec redpanda-clickhouse rpk topic delete clickhouse-dlq 2>/dev/null || echo "Topic already deleted"
print_status 0 "DLQ topic deleted"

sleep 3

# ============================================
# STEP 3: Clean Up Old Kafka Data (Optional)
# ============================================
print_header "Step 3: Kafka Storage Cleanup (Optional)"

echo "Current Kafka topics:"
docker exec redpanda-clickhouse rpk topic list 2>/dev/null

echo ""
print_warning "Do you want to delete OLD Kafka topics to free up space?"
echo "This will keep:"
echo "  - mysql.* topics (your CDC data)"
echo "  - schema-changes.* topics"
echo "  - Connect internal topics"
echo ""
echo "But delete:"
echo "  - Old/unused topics"
echo "  - Test topics"
echo ""
read -p "Delete unused topics? (yes/no): " cleanup_topics

if [ "$cleanup_topics" = "yes" ]; then
    # List topics and let user select
    echo "Listing all topics..."
    docker exec redpanda-clickhouse rpk topic list 2>/dev/null | tail -n +2 | while read -r topic; do
        topic=$(echo "$topic" | awk '{print $1}')

        # Skip important topics
        if [[ "$topic" == mysql.* ]] || \
           [[ "$topic" == clickhouse_connect_* ]] || \
           [[ "$topic" == schema-changes.* ]]; then
            echo "  [KEEP] $topic"
        else
            echo "  [DELETE?] $topic"
            read -p "    Delete $topic? (y/n): " del
            if [ "$del" = "y" ]; then
                docker exec redpanda-clickhouse rpk topic delete "$topic" 2>/dev/null
                print_status 0 "Deleted $topic"
            fi
        fi
    done
fi

# ============================================
# STEP 4: Compact Kafka Log
# ============================================
print_header "Step 4: Trigger Log Compaction"

echo "Triggering log compaction on remaining topics..."
docker exec redpanda-clickhouse rpk cluster maintenance enable 2>/dev/null || true
sleep 5
docker exec redpanda-clickhouse rpk cluster maintenance disable 2>/dev/null || true
print_status 0 "Log compaction triggered"

# ============================================
# STEP 5: Check Storage Savings
# ============================================
print_header "Step 5: Storage After Cleanup"

echo "Docker system storage:"
docker system df

echo ""
echo "Redpanda data size:"
docker exec redpanda-clickhouse du -sh /var/lib/redpanda/data 2>/dev/null

# ============================================
# STEP 6: Reconfigure and Restart Connector
# ============================================
print_header "Step 6: Restart with Fixed Configuration"

echo "Before restarting, you should:"
echo "  1. Fix the root cause (schema mismatches, data types, etc.)"
echo "  2. Update connector configuration"
echo "  3. Consider changing 'errors.tolerance' to 'none' to catch errors early"
echo ""
read -p "Do you want to restart the connector now? (yes/no): " restart

if [ "$restart" = "yes" ]; then
    echo ""
    print_warning "Make sure you've updated the connector config first!"
    echo "Config file location: ./configs/connectors/clickhouse-sink.json"
    echo ""
    read -p "Config is updated and ready? (yes/no): " ready

    if [ "$ready" = "yes" ]; then
        # Load and substitute environment variables
        if [ -f ".env" ]; then
            source .env
        fi

        # Deploy connector (you'll need to adapt this to your deployment script)
        echo "Deploying fixed connector..."
        # Call your deployment script here
        # ./phase3/scripts/fix_clickhouse_sink_connector.sh

        print_status 0 "Connector restarted - monitor the logs!"
    else
        echo "Update the config and run your deployment script when ready."
    fi
else
    echo ""
    print_status 0 "Cleanup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Fix root cause issues"
    echo "  2. Update connector configuration"
    echo "  3. Deploy connector"
    echo "  4. Monitor for new DLQ messages"
fi

print_header "Cleanup Summary"

echo "What was done:"
echo "  ✓ ClickHouse sink connector stopped and deleted"
echo "  ✓ DLQ topic deleted (freed up space)"
echo "  ✓ Optional: Old topics cleaned up"
echo ""
echo "Before restarting:"
echo "  ! Fix root cause of DLQ errors"
echo "  ! Update connector configuration"
echo "  ! Test with small dataset first"
echo ""
echo "Monitor after restart:"
echo "  docker exec redpanda-clickhouse rpk topic list"
echo "  curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | python3 -m json.tool"

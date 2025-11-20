#!/bin/bash
# Step-by-Step Deep Dive: Why Kafka Connect Crashes
# We'll check each layer methodically

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

print_section "STEP 1: Check Redpanda Topics"

echo "Let's see if Kafka Connect internal topics already exist with wrong replication factor..."
echo ""

# List all topics
echo "All topics in Redpanda:"
docker exec redpanda-clickhouse rpk topic list

echo ""
echo "Checking for Kafka Connect internal topics:"

for topic in clickhouse_connect_configs clickhouse_connect_offsets clickhouse_connect_status; do
    echo ""
    echo "Topic: $topic"

    if docker exec redpanda-clickhouse rpk topic describe $topic 2>/dev/null; then
        echo -e "${YELLOW}⚠ Topic exists - checking replication factor${NC}"

        # Get replication factor
        REPL=$(docker exec redpanda-clickhouse rpk topic describe $topic 2>/dev/null | grep -i "replication" | head -1)
        echo "  $REPL"

        if echo "$REPL" | grep -q "3"; then
            echo -e "${RED}  ✗ PROBLEM: Replication factor is 3 (should be 1 for single-node)${NC}"
            echo -e "${YELLOW}  This topic needs to be deleted and recreated${NC}"
        fi
    else
        echo -e "${GREEN}✓ Topic does not exist yet (good)${NC}"
    fi
done

print_section "STEP 2: Test Redpanda Connectivity"

echo "Can kafka-connect container reach Redpanda?"
echo ""

# Try to start container briefly for testing
echo "Starting kafka-connect-clickhouse temporarily for network test..."
docker start kafka-connect-clickhouse >/dev/null 2>&1
sleep 3

if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    echo -e "${GREEN}✓ Container running (temporarily)${NC}"
    echo ""

    echo "Testing DNS resolution for 'redpanda':"
    NSLOOKUP=$(docker exec kafka-connect-clickhouse nslookup redpanda 2>&1)
    if echo "$NSLOOKUP" | grep -q "Address:"; then
        echo -e "${GREEN}✓ Can resolve 'redpanda' hostname${NC}"
        IP=$(echo "$NSLOOKUP" | grep "Address:" | tail -1 | awk '{print $2}')
        echo "  IP: $IP"
    else
        echo -e "${RED}✗ Cannot resolve 'redpanda' hostname${NC}"
        echo "$NSLOOKUP"
    fi

    echo ""
    echo "Testing connection to Redpanda broker (port 9092):"
    TELNET=$(docker exec kafka-connect-clickhouse timeout 3 sh -c "echo quit | telnet redpanda 9092" 2>&1)
    if echo "$TELNET" | grep -q "Connected"; then
        echo -e "${GREEN}✓ Can connect to redpanda:9092${NC}"
    else
        echo -e "${RED}✗ Cannot connect to redpanda:9092${NC}"
        echo "$TELNET"
    fi
else
    echo -e "${YELLOW}⚠ Container crashed too quickly to test${NC}"
fi

print_section "STEP 3: Check Container Environment Variables"

echo "What environment variables is the container actually getting?"
echo ""

if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    echo "Kafka Connect environment (filtered for CONNECT_ vars):"
    docker exec kafka-connect-clickhouse env | grep "CONNECT_" | sort

    echo ""
    echo "Checking critical variables:"

    if docker exec kafka-connect-clickhouse env | grep -q "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR"; then
        echo -e "${GREEN}✓ CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR is set${NC}"
        docker exec kafka-connect-clickhouse env | grep "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR"
    else
        echo -e "${RED}✗ CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR is NOT set${NC}"
    fi

    if docker exec kafka-connect-clickhouse env | grep -q "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR"; then
        echo -e "${GREEN}✓ CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR is set${NC}"
        docker exec kafka-connect-clickhouse env | grep "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR"
    else
        echo -e "${RED}✗ CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR is NOT set${NC}"
    fi

    if docker exec kafka-connect-clickhouse env | grep -q "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR"; then
        echo -e "${GREEN}✓ CONNECT_STATUS_STORAGE_REPLICATION_FACTOR is set${NC}"
        docker exec kafka-connect-clickhouse env | grep "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR"
    else
        echo -e "${RED}✗ CONNECT_STATUS_STORAGE_REPLICATION_FACTOR is NOT set${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Container not running, cannot check environment${NC}"
    echo ""
    echo "Starting container briefly..."
    docker start kafka-connect-clickhouse >/dev/null 2>&1
    sleep 5

    if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
        docker exec kafka-connect-clickhouse env | grep "CONNECT_.*REPLICATION_FACTOR" || echo "No replication factor vars found"
    fi
fi

print_section "STEP 4: Watch Container Startup in Real-Time"

echo "Let's restart the container and watch the logs live to see exactly where it fails..."
echo ""

docker stop kafka-connect-clickhouse >/dev/null 2>&1
sleep 2

echo "Starting kafka-connect-clickhouse and tailing logs..."
echo "Press Ctrl+C after you see the crash (usually within 10-15 seconds)"
echo ""
echo "─────────────────────────────────────────────────────"

docker start kafka-connect-clickhouse >/dev/null 2>&1
sleep 2
docker logs -f kafka-connect-clickhouse 2>&1 &
LOG_PID=$!

# Wait 30 seconds then stop following
sleep 30
kill $LOG_PID 2>/dev/null

echo ""
echo "─────────────────────────────────────────────────────"
echo ""

if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    echo -e "${GREEN}✓ Container is still running after 30 seconds!${NC}"
else
    echo -e "${RED}✗ Container crashed${NC}"
fi

print_section "STEP 5: Summary & Next Action"

echo "Analyzing findings..."
echo ""

# Check if topics exist with wrong replication
TOPICS_ISSUE=false
for topic in clickhouse_connect_configs clickhouse_connect_offsets clickhouse_connect_status; do
    if docker exec redpanda-clickhouse rpk topic describe $topic 2>/dev/null | grep -q "replication.*3"; then
        TOPICS_ISSUE=true
        break
    fi
done

# Check if replication env vars are set
ENV_ISSUE=true
if docker ps --format "{{.Names}}" | grep -q "^kafka-connect-clickhouse$"; then
    if docker exec kafka-connect-clickhouse env 2>/dev/null | grep -q "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR"; then
        ENV_ISSUE=false
    fi
fi

echo "DIAGNOSIS:"
echo ""

if [ "$TOPICS_ISSUE" = true ]; then
    echo -e "${RED}PROBLEM 1: Internal topics exist with replication factor 3${NC}"
    echo "  Kafka Connect tries to create these topics but they already exist"
    echo "  with incompatible replication settings."
    echo ""
    echo "  FIX:"
    echo "  cd /home/centos/clickhouse/phase2/scripts"
    echo "  ./delete_connect_topics.sh"
    echo ""
fi

if [ "$ENV_ISSUE" = true ]; then
    echo -e "${RED}PROBLEM 2: Replication factor environment variables not set${NC}"
    echo "  Container doesn't have CONNECT_*_REPLICATION_FACTOR vars"
    echo ""
    echo "  FIX:"
    echo "  1. Verify docker-compose.yml has correct vars"
    echo "  2. Remove old container completely"
    echo "  3. Recreate: docker-compose up -d kafka-connect"
    echo ""
fi

if [ "$TOPICS_ISSUE" = false ] && [ "$ENV_ISSUE" = false ]; then
    echo -e "${GREEN}Environment looks correct!${NC}"
    echo "The issue may be something else. Check the live logs above for clues."
fi

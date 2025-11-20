#!/bin/bash
# Debug Kafka Connect API Not Responding
# Purpose: Identify why kafka-connect-clickhouse API is not responding on port 8083

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

print_section "Kafka Connect API Debugging"

echo "Issue: Container is running but API not responding on port 8083"
echo ""

print_section "Step 1: Container Status"

if docker ps | grep -q "kafka-connect-clickhouse"; then
    print_status 0 "Container is running"
    docker ps --filter "name=kafka-connect-clickhouse" --format "  Name: {{.Names}}\n  Status: {{.Status}}\n  Ports: {{.Ports}}"
else
    print_status 1 "Container is NOT running"
    echo ""
    echo "Container crashed. Check with: docker ps -a | grep kafka-connect-clickhouse"
    exit 1
fi

print_section "Step 2: Recent Container Logs"

echo "Last 80 lines of logs:"
echo "─────────────────────────────────────────────────────"
docker logs kafka-connect-clickhouse --tail 80 2>&1
echo "─────────────────────────────────────────────────────"

print_section "Step 3: Error Analysis"

docker logs kafka-connect-clickhouse 2>&1 | tail -200 > /tmp/kc_debug_logs.txt

echo "Checking for common issues..."
echo ""

# Connection errors
if grep -qi "failed to connect\|connection refused\|cannot connect" /tmp/kc_debug_logs.txt; then
    echo -e "${RED}❌ CONNECTION ERROR detected${NC}"
    echo ""
    echo "Recent connection errors:"
    grep -i "failed to connect\|connection refused\|cannot connect" /tmp/kc_debug_logs.txt | tail -3
    echo ""
fi

# Port binding errors
if grep -qi "address already in use\|bind.*failed" /tmp/kc_debug_logs.txt; then
    echo -e "${RED}❌ PORT BINDING ERROR detected${NC}"
    echo ""
    echo "Port errors:"
    grep -i "address already in use\|bind.*failed" /tmp/kc_debug_logs.txt | tail -3
    echo ""
fi

# Plugin errors
if grep -qi "plugin.*failed\|failed to load.*plugin" /tmp/kc_debug_logs.txt; then
    echo -e "${RED}❌ PLUGIN LOADING ERROR detected${NC}"
    echo ""
    echo "Plugin errors:"
    grep -i "plugin.*failed\|failed to load.*plugin" /tmp/kc_debug_logs.txt | tail -3
    echo ""
fi

# Startup success indicators
if grep -qi "Kafka Connect started\|REST server listening\|Started.*DistributedHerder" /tmp/kc_debug_logs.txt; then
    echo -e "${GREEN}✓ Kafka Connect startup messages found${NC}"
    echo ""
    grep -i "Kafka Connect started\|REST server listening\|Started.*DistributedHerder" /tmp/kc_debug_logs.txt | tail -3
    echo ""
else
    echo -e "${YELLOW}⚠ No startup success messages found${NC}"
    echo "  Container may still be initializing..."
    echo ""
fi

# Check for REST API messages
if grep -qi "rest.port\|REST.*8083\|Advertised URI" /tmp/kc_debug_logs.txt; then
    echo -e "${BLUE}ℹ REST API configuration:${NC}"
    grep -i "rest.port\|REST.*8083\|Advertised URI" /tmp/kc_debug_logs.txt | tail -5
    echo ""
fi

print_section "Step 4: Port Listening Check"

echo "Checking if port 8083 is actually listening inside container..."
PORT_CHECK=$(docker exec kafka-connect-clickhouse sh -c "netstat -tuln 2>/dev/null | grep 8083 || ss -tuln 2>/dev/null | grep 8083" 2>&1)

if [ -n "$PORT_CHECK" ]; then
    print_status 0 "Port 8083 is listening inside container"
    echo "$PORT_CHECK"
else
    print_status 1 "Port 8083 is NOT listening inside container"
    echo ""
    echo "This means Kafka Connect REST API hasn't started yet."
fi

print_section "Step 5: API Test from Inside Container"

echo "Testing API endpoint from inside the container..."
API_RESPONSE=$(docker exec kafka-connect-clickhouse curl -s http://localhost:8083/ 2>&1)

if echo "$API_RESPONSE" | grep -q "version"; then
    print_status 0 "API responds correctly inside container"
    echo "Response: $API_RESPONSE"
else
    print_status 1 "API not responding inside container"
    echo "Response: ${API_RESPONSE:0:200}"
fi

print_section "Step 6: API Test from Host"

echo "Testing API endpoint from host..."
HOST_RESPONSE=$(curl -s http://localhost:8083/ 2>&1)

if echo "$HOST_RESPONSE" | grep -q "version"; then
    print_status 0 "API responds correctly from host"
    echo "Response: $HOST_RESPONSE"
else
    print_status 1 "API not responding from host"
    echo "Response: ${HOST_RESPONSE:0:200}"
fi

print_section "Step 7: Redpanda Connection Test"

echo "Kafka Connect needs Redpanda to be healthy to start..."
echo ""

if docker ps | grep -q "redpanda-clickhouse.*healthy"; then
    print_status 0 "Redpanda container is healthy"

    # Test from kafka-connect container
    echo ""
    echo "Testing Redpanda connectivity from kafka-connect container..."
    REDPANDA_TEST=$(docker exec kafka-connect-clickhouse sh -c "curl -s http://redpanda:18082/brokers 2>&1" 2>&1)

    if echo "$REDPANDA_TEST" | grep -q "brokers\|cluster"; then
        print_status 0 "Can reach Redpanda from kafka-connect container"
        echo "Response: ${REDPANDA_TEST:0:100}"
    else
        print_status 1 "Cannot reach Redpanda from kafka-connect container"
        echo "Response: ${REDPANDA_TEST:0:200}"
        echo ""
        echo "This could be a networking issue between containers."
    fi
else
    print_status 1 "Redpanda is not healthy"
    echo ""
    echo "Check Redpanda: docker ps | grep redpanda"
fi

print_section "Step 8: Environment Variables"

echo "Checking Kafka Connect environment configuration..."
docker exec kafka-connect-clickhouse sh -c "env | grep -E 'CONNECT_|BOOTSTRAP|KAFKA'" 2>&1 | head -20

print_section "Step 9: Diagnosis Summary"

echo "Analysis:"
echo ""

# Determine the issue
CONTAINER_RUNNING=$(docker ps | grep -c "kafka-connect-clickhouse")
PORT_LISTENING=$(docker exec kafka-connect-clickhouse sh -c "netstat -tuln 2>/dev/null | grep -c 8083 || ss -tuln 2>/dev/null | grep -c 8083" 2>&1)
HAS_STARTUP_MSGS=$(grep -ic "Kafka Connect started\|REST server listening" /tmp/kc_debug_logs.txt 2>/dev/null || echo 0)
HAS_CONNECTION_ERROR=$(grep -ic "connection refused" /tmp/kc_debug_logs.txt 2>/dev/null || echo 0)

if [ "$CONTAINER_RUNNING" -eq 0 ]; then
    echo -e "${RED}Problem: Container is not running${NC}"
    echo "  Solution: Check why it crashed with: docker logs kafka-connect-clickhouse"

elif [ "$PORT_LISTENING" -eq 0 ]; then
    echo -e "${YELLOW}Problem: REST API port 8083 not listening yet${NC}"
    echo ""

    if [ "$HAS_CONNECTION_ERROR" -gt 0 ]; then
        echo "  Likely cause: Cannot connect to Redpanda"
        echo "  Solution:"
        echo "    1. Verify Redpanda is healthy: docker ps | grep redpanda"
        echo "    2. Check network: docker network inspect <network-name>"
        echo "    3. Check BOOTSTRAP_SERVERS setting in container"
    else
        echo "  Likely cause: Still initializing (can take 2-5 minutes)"
        echo "  Solution:"
        echo "    1. Wait 2-3 more minutes"
        echo "    2. Re-run this script to check progress"
        echo "    3. Watch logs: docker logs -f kafka-connect-clickhouse"
    fi

elif [ "$HAS_STARTUP_MSGS" -gt 0 ]; then
    echo -e "${GREEN}Good news: Kafka Connect appears to have started successfully${NC}"
    echo ""
    echo "  But API still not responding. Possible causes:"
    echo "    1. Port forwarding issue (check docker run -p mapping)"
    echo "    2. Firewall blocking port 8083"
    echo "    3. REST API bound to wrong interface"

else
    echo -e "${YELLOW}Unclear: Container running but no clear error or success messages${NC}"
    echo ""
    echo "  Recommendations:"
    echo "    1. Wait 2-3 more minutes (initialization can be slow)"
    echo "    2. Watch live logs: docker logs -f kafka-connect-clickhouse"
    echo "    3. Check full logs for clues: docker logs kafka-connect-clickhouse > /tmp/full_logs.txt"
fi

echo ""
print_section "Recommended Actions"

echo "Try these in order:"
echo ""
echo "1. Wait and retry (if initializing):"
echo "   sleep 120"
echo "   curl -s http://localhost:8083/ | grep version"
echo ""
echo "2. Watch logs in real-time:"
echo "   docker logs -f kafka-connect-clickhouse"
echo "   (Press Ctrl+C to stop)"
echo ""
echo "3. Check Redpanda connectivity:"
echo "   docker exec kafka-connect-clickhouse curl http://redpanda:18082/brokers"
echo ""
echo "4. Restart container if needed:"
echo "   docker restart kafka-connect-clickhouse"
echo "   sleep 60"
echo "   curl -s http://localhost:8083/ | grep version"
echo ""

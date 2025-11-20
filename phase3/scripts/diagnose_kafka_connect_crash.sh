#!/bin/bash
# Diagnostic Script for Kafka Connect Container Crash
# Purpose: Identify why kafka-connect-clickhouse container crashed

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

print_section() {
    echo ""
    echo "========================================"
    echo "   $1"
    echo "========================================"
    echo ""
}

print_section "Kafka Connect Container Crash Diagnostics"

echo "1. Container Status Check"
echo "-------------------------"

CONTAINER_STATUS=$(docker ps -a --filter "name=kafka-connect-clickhouse" --format "{{.Status}}")
echo "Current status: $CONTAINER_STATUS"

if echo "$CONTAINER_STATUS" | grep -q "Up"; then
    print_status 0 "Container is running"
    NEEDS_RESTART=false
else
    print_status 1 "Container is NOT running"
    NEEDS_RESTART=true

    # Extract exit code if available
    EXIT_CODE=$(echo "$CONTAINER_STATUS" | grep -o "Exited ([0-9]*)" | grep -o "[0-9]*")
    if [ -n "$EXIT_CODE" ]; then
        echo -e "${RED}Exit Code: $EXIT_CODE${NC}"
        if [ "$EXIT_CODE" = "1" ]; then
            echo "  Exit code 1 typically indicates application error or failed startup"
        elif [ "$EXIT_CODE" = "137" ]; then
            echo "  Exit code 137 indicates container was killed (OOM or manual kill)"
        fi
    fi
fi

print_section "2. Last 100 Lines of Container Logs"

echo "Checking for errors in recent logs..."
echo ""

docker logs kafka-connect-clickhouse --tail 100 2>&1 > /tmp/kafka_connect_logs.txt

# Check for specific error patterns
echo "Error Analysis:"
echo ""

ERRORS_FOUND=0

# Check for OOM
if grep -qi "out of memory\|oom" /tmp/kafka_connect_logs.txt; then
    echo -e "${RED}✗ OUT OF MEMORY ERROR DETECTED${NC}"
    echo "  Container may be running out of memory"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

# Check for port binding errors
if grep -qi "address already in use\|bind.*failed" /tmp/kafka_connect_logs.txt; then
    echo -e "${RED}✗ PORT BINDING ERROR DETECTED${NC}"
    echo "  Port 8083 may already be in use"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

# Check for plugin loading errors
if grep -qi "failed to load.*plugin\|connector.*not found" /tmp/kafka_connect_logs.txt; then
    echo -e "${RED}✗ PLUGIN LOADING ERROR DETECTED${NC}"
    echo "  Issues loading connector plugins"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

# Check for connection errors
if grep -qi "connection refused\|cannot connect to" /tmp/kafka_connect_logs.txt; then
    echo -e "${RED}✗ CONNECTION ERROR DETECTED${NC}"
    echo "  Cannot connect to dependencies (Redpanda/Kafka)"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

# Check for configuration errors
if grep -qi "invalid configuration\|configuration error" /tmp/kafka_connect_logs.txt; then
    echo -e "${RED}✗ CONFIGURATION ERROR DETECTED${NC}"
    echo "  Invalid configuration detected"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
fi

# Check for generic exceptions
EXCEPTION_COUNT=$(grep -c "Exception\|ERROR" /tmp/kafka_connect_logs.txt)
if [ "$EXCEPTION_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $EXCEPTION_COUNT ERROR/Exception lines${NC}"
fi

if [ "$ERRORS_FOUND" -eq 0 ] && [ "$EXCEPTION_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ No obvious errors in recent logs${NC}"
fi

echo ""
echo "Full log excerpt (last 30 lines):"
echo "-----------------------------------"
tail -30 /tmp/kafka_connect_logs.txt

print_section "3. Dependency Health Check"

# Check if Redpanda is running
echo "Checking Redpanda/Kafka dependency..."
if docker ps | grep -q "redpanda-clickhouse"; then
    print_status 0 "Redpanda container is running"

    # Check if Kafka broker is accessible
    if docker exec redpanda-clickhouse rpk cluster info &>/dev/null; then
        print_status 0 "Redpanda broker is responsive"
    else
        print_status 1 "Redpanda broker not responding"
        echo "  Kafka Connect needs Redpanda to be healthy"
    fi
else
    print_status 1 "Redpanda container is NOT running"
    echo -e "${RED}  CRITICAL: Kafka Connect requires Redpanda to be running${NC}"
fi

# Check port 8083 availability
echo ""
echo "Checking port 8083 availability..."
if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
    print_status 1 "Port 8083 is already in use by another process"
    echo "  This could prevent Kafka Connect from starting"
    echo ""
    echo "  Process using port 8083:"
    netstat -tulnp 2>/dev/null | grep ":8083 " || ss -tulnp 2>/dev/null | grep ":8083 "
else
    print_status 0 "Port 8083 is available"
fi

print_section "4. Container Resource Check"

# Check container resource limits
echo "Container resource configuration:"
docker inspect kafka-connect-clickhouse --format '
  Memory Limit: {{.HostConfig.Memory}}
  CPU Shares: {{.HostConfig.CpuShares}}
  Restart Policy: {{.HostConfig.RestartPolicy.Name}}
' 2>/dev/null || echo "  Could not retrieve resource info"

print_section "5. Diagnostic Summary & Recommendations"

echo "Issues Found: $ERRORS_FOUND"
echo ""

if [ "$ERRORS_FOUND" -eq 0 ] && [ "$EXCEPTION_COUNT" -eq 0 ]; then
    if [ "$NEEDS_RESTART" = true ]; then
        echo -e "${GREEN}No critical errors found. Safe to restart.${NC}"
        echo ""
        echo "Recommended action:"
        echo "  docker start kafka-connect-clickhouse"
        echo ""
        echo "Then verify it stays running:"
        echo "  sleep 10"
        echo "  docker ps | grep kafka-connect-clickhouse"
        echo "  curl -s http://localhost:8083/ | grep version"
    else
        echo -e "${GREEN}Container is running normally.${NC}"
    fi
else
    echo -e "${YELLOW}Problems detected that may cause crashes:${NC}"
    echo ""

    if grep -qi "out of memory\|oom" /tmp/kafka_connect_logs.txt; then
        echo "Fix for OOM:"
        echo "  docker stop kafka-connect-clickhouse"
        echo "  docker rm kafka-connect-clickhouse"
        echo "  # Recreate with more memory (e.g., --memory=2g)"
        echo ""
    fi

    if grep -qi "connection refused.*redpanda\|cannot connect.*kafka" /tmp/kafka_connect_logs.txt; then
        echo "Fix for Redpanda connection:"
        echo "  1. Ensure Redpanda is running: docker ps | grep redpanda"
        echo "  2. Check Redpanda health: docker exec redpanda-clickhouse rpk cluster info"
        echo "  3. Restart Kafka Connect after Redpanda is healthy"
        echo ""
    fi

    if grep -qi "address already in use" /tmp/kafka_connect_logs.txt; then
        echo "Fix for port conflict:"
        echo "  1. Find process: sudo lsof -i :8083"
        echo "  2. Kill conflicting process or change Kafka Connect port"
        echo ""
    fi

    echo "After fixing issues, restart:"
    echo "  docker start kafka-connect-clickhouse"
    echo "  # Wait and verify"
    echo "  docker logs kafka-connect-clickhouse --tail 20"
fi

echo ""
print_info "Full logs saved to: /tmp/kafka_connect_logs.txt"
print_info "Review with: less /tmp/kafka_connect_logs.txt"
echo ""

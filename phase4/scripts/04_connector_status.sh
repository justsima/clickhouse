#!/bin/bash
# Phase 4 - Connector Status Script
# Purpose: Detailed status of all Kafka Connect connectors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(dirname "$SCRIPT_DIR")"
PHASE3_DIR="$(dirname "$PHASE4_DIR")/phase3"
CONFIG_DIR="$PHASE3_DIR/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONNECT_URL="http://localhost:8085"

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

echo "========================================"
echo "   Kafka Connect Connector Status"
echo "========================================"
echo ""

# Check if Kafka Connect is running
if ! curl -s "$CONNECT_URL/" | grep -q "version"; then
    echo -e "${RED}ERROR: Kafka Connect is not responding${NC}"
    exit 1
fi

CONNECT_VERSION=$(curl -s "$CONNECT_URL/" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "Unknown")
echo "Kafka Connect Version: $CONNECT_VERSION"
echo ""

# Get list of all connectors
CONNECTORS=$(curl -s "$CONNECT_URL/connectors" | python3 -m json.tool 2>/dev/null || echo "[]")
CONNECTOR_COUNT=$(echo "$CONNECTORS" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

echo "Total Connectors: $CONNECTOR_COUNT"
echo ""

if [ "$CONNECTOR_COUNT" = "0" ]; then
    echo -e "${YELLOW}No connectors deployed yet${NC}"
    exit 0
fi

# Iterate through each connector
for connector in $(echo "$CONNECTORS" | python3 -c "import sys, json; print('\n'.join(json.load(sys.stdin)))" 2>/dev/null); do
    echo -e "${CYAN}Connector: $connector${NC}"
    echo "----------------------------------------"

    # Get connector status
    STATUS_JSON=$(curl -s "$CONNECT_URL/connectors/$connector/status")

    # Parse status
    CONNECTOR_STATE=$(echo "$STATUS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['connector']['state'])" 2>/dev/null || echo "UNKNOWN")
    CONNECTOR_WORKER=$(echo "$STATUS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['connector']['worker_id'])" 2>/dev/null || echo "Unknown")

    if [ "$CONNECTOR_STATE" = "RUNNING" ]; then
        print_status 0 "State: $CONNECTOR_STATE"
    else
        print_status 1 "State: $CONNECTOR_STATE"
    fi

    echo "  Worker ID: $CONNECTOR_WORKER"

    # Get connector config
    CONFIG_JSON=$(curl -s "$CONNECT_URL/connectors/$connector")
    CONNECTOR_CLASS=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['config']['connector.class'])" 2>/dev/null || echo "Unknown")
    TASKS_MAX=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['config']['tasks.max'])" 2>/dev/null || echo "Unknown")

    echo "  Connector Class: $CONNECTOR_CLASS"
    echo "  Max Tasks: $TASKS_MAX"

    # Get task statuses
    echo ""
    echo "  Task Status:"

    TASK_COUNT=$(echo "$STATUS_JSON" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['tasks']))" 2>/dev/null || echo "0")

    if [ "$TASK_COUNT" = "0" ]; then
        echo -e "    ${YELLOW}No tasks running${NC}"
    else
        for i in $(seq 0 $((TASK_COUNT - 1))); do
            TASK_STATE=$(echo "$STATUS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['tasks'][$i]['state'])" 2>/dev/null || echo "UNKNOWN")
            TASK_ID=$(echo "$STATUS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['tasks'][$i]['id'])" 2>/dev/null || echo "Unknown")
            TASK_WORKER=$(echo "$STATUS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['tasks'][$i]['worker_id'])" 2>/dev/null || echo "Unknown")

            if [ "$TASK_STATE" = "RUNNING" ]; then
                echo -e "    ${GREEN}✓${NC} Task $TASK_ID: $TASK_STATE (worker: $TASK_WORKER)"
            else
                echo -e "    ${RED}✗${NC} Task $TASK_ID: $TASK_STATE (worker: $TASK_WORKER)"

                # Get error trace if failed
                TASK_TRACE=$(echo "$STATUS_JSON" | python3 -c "import sys, json; tasks=json.load(sys.stdin)['tasks'][$i]; print(tasks.get('trace', 'No trace available'))" 2>/dev/null || echo "")
                if [ ! -z "$TASK_TRACE" ] && [ "$TASK_TRACE" != "No trace available" ]; then
                    echo "      Error: $(echo "$TASK_TRACE" | head -c 200)..."
                fi
            fi
        done
    fi

    echo ""

    # Get connector-specific metrics
    if [[ "$connector" == *"mysql"* ]] || [[ "$connector" == *"source"* ]]; then
        echo "  Source Connector Metrics:"

        # Try to get some basic metrics
        SNAPSHOT_COMPLETED=$(echo "$STATUS_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('connector', {}).get('snapshot_completed', 'Unknown'))" 2>/dev/null || echo "Unknown")

        if [ "$SNAPSHOT_COMPLETED" != "Unknown" ]; then
            echo "    Snapshot Completed: $SNAPSHOT_COMPLETED"
        fi

        # Get topic prefix if available
        TOPIC_PREFIX=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['config'].get('topic.prefix', 'N/A'))" 2>/dev/null || echo "N/A")
        echo "    Topic Prefix: $TOPIC_PREFIX"

        # Get snapshot mode
        SNAPSHOT_MODE=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['config'].get('snapshot.mode', 'N/A'))" 2>/dev/null || echo "N/A")
        echo "    Snapshot Mode: $SNAPSHOT_MODE"
    fi

    if [[ "$connector" == *"clickhouse"* ]] || [[ "$connector" == *"sink"* ]]; then
        echo "  Sink Connector Metrics:"

        # Get batch size
        BATCH_SIZE=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['config'].get('batch.size', 'N/A'))" 2>/dev/null || echo "N/A")
        echo "    Batch Size: $BATCH_SIZE"

        # Get topics
        TOPICS=$(echo "$CONFIG_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['config'].get('topics', 'N/A'))" 2>/dev/null || echo "N/A")
        if [ "$TOPICS" != "N/A" ]; then
            echo "    Topics: $(echo $TOPICS | head -c 100)"
        fi
    fi

    echo ""
    echo ""
done

# Overall summary
echo "========================================"
echo "Summary"
echo "========================================"

RUNNING_CONNECTORS=$(curl -s "$CONNECT_URL/connectors" | python3 -c "
import sys, json, requests
connect_url = '$CONNECT_URL'
connectors = json.load(sys.stdin)
running = 0
for connector in connectors:
    try:
        status = requests.get(f'{connect_url}/connectors/{connector}/status').json()
        if status['connector']['state'] == 'RUNNING':
            running += 1
    except:
        pass
print(running)
" 2>/dev/null || echo "0")

echo "Connectors: $RUNNING_CONNECTORS / $CONNECTOR_COUNT running"

if [ "$RUNNING_CONNECTORS" = "$CONNECTOR_COUNT" ]; then
    echo -e "${GREEN}✓ All connectors are running${NC}"
else
    echo -e "${RED}✗ Some connectors are not running${NC}"
fi

echo ""
echo "View logs:"
echo "  docker logs kafka-connect-clickhouse --tail 100"
echo ""

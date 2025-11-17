#!/bin/bash
# Phase 3 - Master Deployment Script
# Purpose: Run all Phase 3 steps in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "   Phase 3: Data Pipeline Deployment"
echo "=========================================="
echo ""
echo -e "${CYAN}This script will execute all Phase 3 steps:${NC}"
echo "  1. Analyze MySQL schema (15-20 min)"
echo "  2. Create ClickHouse tables (10-15 min)"
echo "  3. Deploy connectors (5-10 min)"
echo "  4. Monitor snapshot (2-4 hours)"
echo "  5. Validate data (15-30 min)"
echo ""
echo -e "${YELLOW}Total estimated time: 3-5 hours${NC}"
echo ""

# Confirm before proceeding
read -p "Do you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""

# Make all scripts executable
chmod +x scripts/*.sh

# Step 1: Analyze MySQL schema
echo "=========================================="
echo "  Step 1/5: Analyzing MySQL Schema"
echo "=========================================="
echo ""

./scripts/01_analyze_mysql_schema.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Schema analysis failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Schema analysis complete${NC}"
echo ""
read -p "Press Enter to continue to Step 2..."
echo ""

# Step 2: Create ClickHouse schema
echo "=========================================="
echo "  Step 2/5: Creating ClickHouse Tables"
echo "=========================================="
echo ""

./scripts/02_create_clickhouse_schema.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Table creation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ ClickHouse schema created${NC}"
echo ""
read -p "Press Enter to continue to Step 3..."
echo ""

# Step 3: Deploy connectors
echo "=========================================="
echo "  Step 3/5: Deploying Connectors"
echo "=========================================="
echo ""

./scripts/03_deploy_connectors.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Connector deployment failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Connectors deployed${NC}"
echo ""
echo -e "${CYAN}Snapshot is now running in the background${NC}"
echo ""
read -p "Press Enter to start monitoring (Step 4)..."
echo ""

# Step 4: Monitor snapshot
echo "=========================================="
echo "  Step 4/5: Monitoring Snapshot Progress"
echo "=========================================="
echo ""
echo -e "${YELLOW}This will run continuously until snapshot completes${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop monitoring (snapshot continues in background)${NC}"
echo ""
sleep 3

./scripts/04_monitor_snapshot.sh

echo ""
echo -e "${GREEN}✓ Snapshot monitoring complete${NC}"
echo ""

# Step 5: Validate data
echo "=========================================="
echo "  Step 5/5: Validating Data"
echo "=========================================="
echo ""

./scripts/05_validate_data.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Data validation failed${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo "   Phase 3 Deployment Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ All steps completed successfully${NC}"
echo ""
echo "Next steps:"
echo "  - Review validation reports in validation_output/"
echo "  - Connect Power BI to ClickHouse for analytics"
echo "  - When you get MySQL replication privileges, upgrade to full CDC mode"
echo ""
echo "See README.md for details on upgrading to CDC mode"
echo ""

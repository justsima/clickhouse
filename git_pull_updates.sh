#!/bin/bash
# Git Pull Script - Fetch and merge latest changes from remote branch
# This script will pull updates from the Claude development branch

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
echo "   Git Pull Updates"
echo "========================================"
echo ""

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
print_info "Current branch: $CURRENT_BRANCH"
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${YELLOW}⚠ Warning: You have uncommitted changes${NC}"
    echo ""
    git status --short
    echo ""
    read -p "Stash changes and continue? (yes/no): " STASH_CONFIRM
    if [ "$STASH_CONFIRM" = "yes" ]; then
        git stash push -m "Auto-stash before pull at $(date)"
        print_status 0 "Changes stashed"
        echo ""
    else
        echo "Please commit or stash your changes first"
        exit 1
    fi
fi

# Fetch updates with retry
print_info "Fetching updates from remote..."
MAX_RETRIES=4
RETRY_DELAY=2

for attempt in $(seq 1 $MAX_RETRIES); do
    if git fetch origin "$CURRENT_BRANCH" 2>&1; then
        print_status 0 "Fetch successful"
        break
    else
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}⚠ Fetch failed (attempt $attempt/$MAX_RETRIES), retrying in ${RETRY_DELAY}s...${NC}"
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
        else
            print_status 1 "Fetch failed after $MAX_RETRIES attempts"
            exit 1
        fi
    fi
done

echo ""

# Check if there are updates
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/$CURRENT_BRANCH)

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    print_status 0 "Already up to date"
    exit 0
fi

# Show what will be pulled
print_info "New commits available:"
echo ""
git log --oneline HEAD..origin/$CURRENT_BRANCH
echo ""

# Pull updates with retry
print_info "Pulling updates..."
for attempt in $(seq 1 $MAX_RETRIES); do
    if git pull origin "$CURRENT_BRANCH" 2>&1; then
        print_status 0 "Pull successful"
        echo ""
        echo "========================================"
        echo "   Updates Applied Successfully"
        echo "========================================"
        echo ""
        echo "Summary of changes:"
        git diff --stat $LOCAL_COMMIT HEAD
        exit 0
    else
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}⚠ Pull failed (attempt $attempt/$MAX_RETRIES), retrying in ${RETRY_DELAY}s...${NC}"
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
        else
            print_status 1 "Pull failed after $MAX_RETRIES attempts"
            exit 1
        fi
    fi
done

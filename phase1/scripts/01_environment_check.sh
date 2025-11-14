#!/bin/bash
# Phase 1 - Environment Detection Script
# Purpose: Validate VPS environment before deployment

set -e

echo "========================================"
echo "   Environment Detection & Validation"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. OS Information
echo "1. Operating System Information"
echo "--------------------------------"
if [ -f /etc/centos-release ]; then
    CENTOS_VERSION=$(cat /etc/centos-release)
    echo "CentOS Version: $CENTOS_VERSION"
    print_status 0 "CentOS detected"
elif [ -f /etc/redhat-release ]; then
    REDHAT_VERSION=$(cat /etc/redhat-release)
    echo "RedHat Version: $REDHAT_VERSION"
    print_status 0 "RedHat-based system detected"
else
    print_status 1 "CentOS/RedHat not detected"
fi
echo ""

# 2. Package Manager Detection
echo "2. Package Manager Detection"
echo "-----------------------------"
if command -v dnf &> /dev/null; then
    DNF_VERSION=$(dnf --version | head -n1)
    echo "DNF Version: $DNF_VERSION"
    print_status 0 "DNF available"
    PKG_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    YUM_VERSION=$(yum --version | head -n1)
    echo "YUM Version: $YUM_VERSION"
    print_status 0 "YUM available"
    PKG_MANAGER="yum"
else
    print_status 1 "No package manager found"
    PKG_MANAGER="none"
fi
echo ""

# 3. Docker Detection
echo "3. Docker Environment"
echo "---------------------"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "Docker: $DOCKER_VERSION"
    print_status 0 "Docker installed"

    # Check Docker service status
    if systemctl is-active --quiet docker 2>/dev/null || service docker status &> /dev/null; then
        print_status 0 "Docker service running"
    else
        print_status 1 "Docker service not running"
    fi
else
    print_status 1 "Docker not installed"
fi

if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo "Docker Compose: $COMPOSE_VERSION"
    print_status 0 "Docker Compose installed"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo "Docker Compose Plugin: $COMPOSE_VERSION"
    print_status 0 "Docker Compose (plugin) available"
else
    print_status 1 "Docker Compose not installed"
fi
echo ""

# 4. System Resources
echo "4. System Resources"
echo "-------------------"
TOTAL_RAM=$(free -h | awk '/^Mem:/ {print $2}')
USED_RAM=$(free -h | awk '/^Mem:/ {print $3}')
FREE_RAM=$(free -h | awk '/^Mem:/ {print $4}')
echo "Total RAM: $TOTAL_RAM"
echo "Used RAM: $USED_RAM"
echo "Free RAM: $FREE_RAM"

TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
if [ "$TOTAL_RAM_GB" -ge 32 ]; then
    print_status 0 "RAM sufficient (64GB recommended, ${TOTAL_RAM_GB}GB available)"
else
    print_warning "RAM may be insufficient (64GB recommended, ${TOTAL_RAM_GB}GB available)"
fi
echo ""

# 5. Disk Space
echo "5. Disk Space"
echo "-------------"
DISK_INFO=$(df -h / | tail -1)
TOTAL_DISK=$(echo $DISK_INFO | awk '{print $2}')
USED_DISK=$(echo $DISK_INFO | awk '{print $3}')
AVAIL_DISK=$(echo $DISK_INFO | awk '{print $4}')
USE_PERCENT=$(echo $DISK_INFO | awk '{print $5}' | tr -d '%')

echo "Total Disk: $TOTAL_DISK"
echo "Used Disk: $USED_DISK"
echo "Available: $AVAIL_DISK"
echo "Usage: ${USE_PERCENT}%"

if [ "$USE_PERCENT" -lt 70 ]; then
    print_status 0 "Disk space sufficient (30-40% should remain free for ClickHouse merges)"
else
    print_warning "Disk usage high - ensure 30-40% remains free for ClickHouse operations"
fi
echo ""

# 6. CPU Information
echo "6. CPU Information"
echo "------------------"
CPU_CORES=$(nproc)
CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
echo "CPU Model: $CPU_MODEL"
echo "CPU Cores: $CPU_CORES"
if [ "$CPU_CORES" -ge 8 ]; then
    print_status 0 "CPU cores sufficient"
else
    print_warning "Limited CPU cores (8+ recommended for production)"
fi
echo ""

# 7. Network Connectivity
echo "7. Network Connectivity"
echo "-----------------------"
if ping -c 1 8.8.8.8 &> /dev/null; then
    print_status 0 "Internet connectivity available"
else
    print_status 1 "No internet connectivity"
fi

if command -v curl &> /dev/null; then
    print_status 0 "curl available"
else
    print_warning "curl not found (needed for API tests)"
fi

if command -v wget &> /dev/null; then
    print_status 0 "wget available"
else
    print_warning "wget not found"
fi
echo ""

# 8. Required Ports Check
echo "8. Port Availability Check"
echo "--------------------------"
REQUIRED_PORTS=(9092 9644 8081 8082 8083 8080 9000 8123)
PORT_NAMES=("Redpanda Kafka" "Redpanda Admin" "Schema Registry" "HTTP Proxy" "Kafka Connect" "Redpanda Console" "ClickHouse Native" "ClickHouse HTTP")

for i in "${!REQUIRED_PORTS[@]}"; do
    PORT=${REQUIRED_PORTS[$i]}
    NAME=${PORT_NAMES[$i]}

    if netstat -tuln 2>/dev/null | grep -q ":$PORT " || ss -tuln 2>/dev/null | grep -q ":$PORT "; then
        print_warning "Port $PORT ($NAME) already in use"
    else
        print_status 0 "Port $PORT ($NAME) available"
    fi
done
echo ""

# 9. Save Environment Info
echo "9. Saving Environment Information"
echo "----------------------------------"
ENV_FILE="/home/user/clickhouse/phase1/environment_info.txt"
{
    echo "=== Environment Detection Report ==="
    echo "Date: $(date)"
    echo ""
    echo "OS: $(cat /etc/centos-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
    echo "Package Manager: $PKG_MANAGER"
    echo "Docker: $(docker --version 2>/dev/null || echo 'Not installed')"
    echo "Docker Compose: $(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null || echo 'Not installed')"
    echo ""
    echo "RAM: $TOTAL_RAM (Used: $USED_RAM, Free: $FREE_RAM)"
    echo "Disk: $TOTAL_DISK (Used: $USED_DISK, Available: $AVAIL_DISK, Usage: ${USE_PERCENT}%)"
    echo "CPU Cores: $CPU_CORES"
    echo "CPU Model: $CPU_MODEL"
} > "$ENV_FILE"

print_status 0 "Environment info saved to $ENV_FILE"
echo ""

echo "========================================"
echo "   Environment Check Complete"
echo "========================================"
echo ""
echo "Summary saved to: $ENV_FILE"
echo "Review any warnings above before proceeding to MySQL validation."

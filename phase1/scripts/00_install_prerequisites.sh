#!/bin/bash
# Phase 1 - Software Installation Script
# Purpose: Install all prerequisite software for Phase 1 validation

set -e

echo "========================================"
echo "   Phase 1 - Software Installation"
echo "========================================"
echo ""

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root or with sudo${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Detect package manager
if command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    print_info "Detected package manager: DNF"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    print_info "Detected package manager: YUM"
else
    echo -e "${RED}ERROR: No package manager found (yum/dnf)${NC}"
    exit 1
fi

echo ""
echo "This script will install the following if missing:"
echo "  1. MySQL client (for database validation)"
echo "  2. Basic utilities (curl, wget, net-tools, bc)"
echo "  3. Docker (container runtime)"
echo "  4. Docker Compose (container orchestration)"
echo ""

read -p "Continue with installation? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "========================================"
echo "   Starting Installation"
echo "========================================"
echo ""

# Update package cache
echo "1. Updating package cache..."
$PKG_MANAGER makecache --refresh -q || $PKG_MANAGER makecache -q
print_status 0 "Package cache updated"
echo ""

# Install MySQL client
echo "2. Installing MySQL Client..."
if command -v mysql &> /dev/null; then
    MYSQL_VERSION=$(mysql --version | cut -d' ' -f6)
    print_info "MySQL client already installed: $MYSQL_VERSION"
else
    echo "Installing MySQL client..."
    $PKG_MANAGER install -y mysql

    if [ $? -eq 0 ]; then
        print_status 0 "MySQL client installed"
    else
        print_warning "MySQL client installation failed, will try alternative..."
        # Try mariadb client as alternative
        $PKG_MANAGER install -y mariadb
        if [ $? -eq 0 ]; then
            print_status 0 "MariaDB client installed (compatible with MySQL)"
        else
            print_status 1 "Failed to install MySQL/MariaDB client"
            echo "You may need to use Docker for MySQL commands"
        fi
    fi
fi
echo ""

# Install basic utilities
echo "3. Installing Basic Utilities..."

# curl
if command -v curl &> /dev/null; then
    print_info "curl already installed"
else
    echo "Installing curl..."
    $PKG_MANAGER install -y curl
    print_status $? "curl installed"
fi

# wget
if command -v wget &> /dev/null; then
    print_info "wget already installed"
else
    echo "Installing wget..."
    $PKG_MANAGER install -y wget
    print_status $? "wget installed"
fi

# net-tools (for netstat)
if command -v netstat &> /dev/null; then
    print_info "netstat already installed"
else
    echo "Installing net-tools..."
    $PKG_MANAGER install -y net-tools
    print_status $? "net-tools installed"
fi

# iproute (for ss command, alternative to netstat)
if command -v ss &> /dev/null; then
    print_info "ss (iproute) already installed"
else
    echo "Installing iproute..."
    $PKG_MANAGER install -y iproute
    print_status $? "iproute installed"
fi

# bc (for calculations in scripts)
if command -v bc &> /dev/null; then
    print_info "bc already installed"
else
    echo "Installing bc..."
    $PKG_MANAGER install -y bc
    print_status $? "bc installed"
fi

# bind-utils (for dig, nslookup)
if command -v dig &> /dev/null; then
    print_info "bind-utils already installed"
else
    echo "Installing bind-utils..."
    $PKG_MANAGER install -y bind-utils
    print_status $? "bind-utils installed"
fi

echo ""

# Install Docker
echo "4. Installing Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_info "Docker already installed: $DOCKER_VERSION"

    # Check if Docker service is running
    if systemctl is-active --quiet docker; then
        print_status 0 "Docker service is running"
    else
        echo "Starting Docker service..."
        systemctl start docker
        systemctl enable docker
        print_status $? "Docker service started and enabled"
    fi
else
    echo "Docker not found. Installing Docker..."

    # Remove old versions if any
    $PKG_MANAGER remove -y docker docker-client docker-client-latest docker-common docker-latest \
        docker-latest-logrotate docker-logrotate docker-engine podman runc 2>/dev/null || true

    # Install Docker using official method
    echo "Installing Docker dependencies..."
    $PKG_MANAGER install -y yum-utils device-mapper-persistent-data lvm2

    # Add Docker repository
    echo "Adding Docker repository..."
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # Install Docker
    echo "Installing Docker CE..."
    $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io

    if [ $? -eq 0 ]; then
        print_status 0 "Docker installed successfully"

        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        print_status 0 "Docker service started and enabled"

        # Test Docker
        docker run hello-world &> /dev/null
        if [ $? -eq 0 ]; then
            print_status 0 "Docker test successful"
        else
            print_warning "Docker installed but test failed"
        fi
    else
        print_status 1 "Docker installation failed"
        echo "Please install Docker manually: https://docs.docker.com/engine/install/centos/"
    fi
fi
echo ""

# Install Docker Compose
echo "5. Installing Docker Compose..."

# Check for docker-compose command
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_info "Docker Compose already installed: $COMPOSE_VERSION"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    print_info "Docker Compose (plugin) already installed: $COMPOSE_VERSION"
else
    echo "Installing Docker Compose..."

    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$COMPOSE_VERSION" ]; then
        COMPOSE_VERSION="v2.24.0"  # Fallback to known version
        print_warning "Could not detect latest version, using $COMPOSE_VERSION"
    fi

    echo "Downloading Docker Compose $COMPOSE_VERSION..."
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose

    if [ $? -eq 0 ]; then
        chmod +x /usr/local/bin/docker-compose

        # Create symlink
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null

        # Verify installation
        if command -v docker-compose &> /dev/null; then
            INSTALLED_VERSION=$(docker-compose --version)
            print_status 0 "Docker Compose installed: $INSTALLED_VERSION"
        else
            print_status 1 "Docker Compose installation verification failed"
        fi
    else
        print_status 1 "Docker Compose download failed"
        echo "You can install it manually later or use 'docker compose' (plugin) instead"
    fi
fi
echo ""

# Summary
echo "========================================"
echo "   Installation Summary"
echo "========================================"
echo ""

INSTALL_SUCCESS=0

# Check all components
echo "Installed Software:"

if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} MySQL/MariaDB Client"
else
    echo -e "  ${RED}✗${NC} MySQL Client (MISSING)"
    INSTALL_SUCCESS=1
fi

if command -v curl &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} curl"
else
    echo -e "  ${RED}✗${NC} curl (MISSING)"
    INSTALL_SUCCESS=1
fi

if command -v wget &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} wget"
else
    echo -e "  ${RED}✗${NC} wget (MISSING)"
fi

if command -v netstat &> /dev/null || command -v ss &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Network tools (netstat/ss)"
else
    echo -e "  ${RED}✗${NC} Network tools (MISSING)"
    INSTALL_SUCCESS=1
fi

if command -v bc &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} bc (calculator)"
else
    echo -e "  ${RED}✗${NC} bc (MISSING)"
    INSTALL_SUCCESS=1
fi

if command -v docker &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker"
else
    echo -e "  ${RED}✗${NC} Docker (MISSING)"
    INSTALL_SUCCESS=1
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker Compose"
else
    echo -e "  ${YELLOW}⚠${NC} Docker Compose (MISSING - optional for Phase 1)"
fi

echo ""

if [ $INSTALL_SUCCESS -eq 0 ]; then
    echo -e "${GREEN}✓ All required software installed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Configure credentials: cd /home/user/clickhouse/phase1/configs && cp .env.example .env"
    echo "  2. Run validation scripts: cd /home/user/clickhouse/phase1/scripts"
    echo "  3. Start with: ./01_environment_check.sh"
else
    echo -e "${YELLOW}⚠ Some software failed to install${NC}"
    echo "Please review errors above and install manually if needed."
    echo "Most Phase 1 scripts should still work."
fi

echo ""

# Test Docker if installed
if command -v docker &> /dev/null; then
    echo "Docker Status:"
    systemctl status docker --no-pager -l | head -3
    echo ""
    echo "Docker Info:"
    docker info | grep -E "Server Version|Storage Driver|Operating System|Total Memory|CPUs"
fi

echo ""
echo "Installation complete!"
echo ""

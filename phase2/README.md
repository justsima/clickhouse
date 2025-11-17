# Phase 2: Service Deployment & Configuration

## Overview

This phase deploys all required services for the MySQL to ClickHouse CDC pipeline using Docker Compose.

**Services Deployed**:
- **Redpanda** - Kafka-compatible streaming platform (port 9093)
- **Redpanda Console** - Web UI for managing Kafka (port 8086)
- **Kafka Connect** - Framework for Debezium and ClickHouse Sink (port 8085)
- **ClickHouse** - Analytical database (ports 9000, 8123)

**Duration**: 15-20 minutes (including image downloads)

---

## Directory Structure

```
phase2/
├── README.md                      # This file
├── docker-compose.yml             # Service definitions
├── scripts/
│   ├── deploy.sh                  # Deployment script
│   └── health_check.sh            # Service health verification
└── configs/
    ├── clickhouse/
    │   ├── users.xml              # ClickHouse user configuration
    │   └── config.xml             # ClickHouse server settings
    └── clickhouse-sink/           # ClickHouse Sink connector (Phase 3)
```

---

## Prerequisites

Before starting Phase 2:

1. ✅ **Docker installed** and running
2. ✅ **Docker Compose** available (plugin or standalone)
3. ✅ **Phase 1 completed** (environment validated)
4. ✅ **Sufficient disk space** (~10GB for images + data)
5. ✅ **Ports available**: 9093, 8081, 8082, 8085, 8086, 9000, 8123, 9644

---

## Port Mapping (Coexisting with Existing Services)

| Service | Internal Port | External Port | Purpose |
|---------|---------------|---------------|---------|
| Redpanda Kafka | 9092 | **9093** | Kafka API (changed to avoid conflict) |
| Schema Registry | 8081 | 8081 | Avro/JSON schemas |
| HTTP Proxy | 8082 | 8082 | REST API for Kafka |
| Kafka Connect | 8083 | **8085** | Connector management (changed) |
| Redpanda Console | 8080 | **8086** | Web UI (changed) |
| Redpanda Admin | 9644 | 9644 | Admin API, metrics |
| ClickHouse HTTP | 8123 | 8123 | HTTP interface |
| ClickHouse Native | 9000 | 9000 | Native protocol |

**Note**: Ports 9093, 8085, 8086 were changed to coexist with your existing Kafka/Debezium setup.

---

## Step-by-Step Deployment

### Step 1: Navigate to Phase 2 Directory

```bash
cd /home/centos/clickhouse/phase2
```

### Step 2: Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

### Step 3: Review Docker Compose Configuration (Optional)

```bash
cat docker-compose.yml
```

### Step 4: Deploy Services

```bash
./scripts/deploy.sh
```

**What this script does**:
1. Checks Docker is running
2. Verifies port availability
3. Stops any existing services
4. Pulls Docker images (~5-10 minutes on first run)
5. Starts all services
6. Waits for health checks
7. Displays service URLs and status

**Expected output**:
```
✓ Docker is running
✓ Docker Compose available
✓ Port 9093 (Redpanda Kafka) available
✓ Port 8085 (Kafka Connect) available
✓ Port 8086 (Redpanda Console) available
✓ Port 9000 (ClickHouse Native) available
✓ Port 8123 (ClickHouse HTTP) available

Starting services in detached mode...
[+] Running 4/4
 ✔ Container redpanda-clickhouse          Started
 ✔ Container clickhouse-server            Started
 ✔ Container kafka-connect-clickhouse     Started
 ✔ Container redpanda-console-clickhouse  Started

✓ Redpanda is healthy
✓ Kafka Connect is healthy
✓ ClickHouse is healthy

✓ Phase 2 deployment complete!
```

### Step 5: Verify Services

```bash
./scripts/health_check.sh
```

**This checks**:
- Container status (running/stopped)
- Service health (Redpanda, Kafka Connect, ClickHouse)
- Network connectivity between services
- Resource usage
- Disk usage

**Expected output**:
```
✓ redpanda-clickhouse is running
✓ kafka-connect-clickhouse is running
✓ clickhouse-server is running
✓ redpanda-console-clickhouse is running

✓ Redpanda cluster is healthy
✓ Kafka Connect is responding
✓ ClickHouse is responding
✓ Analytics database exists

✓ All services are healthy!
```

---

## Accessing Services

### Redpanda Console (Web UI)

**URL**: http://localhost:8086

**Features**:
- Browse Kafka topics
- Monitor consumer lag
- View message payloads
- Manage Kafka Connect connectors
- Inspect schemas

### Kafka Connect REST API

**URL**: http://localhost:8085

**Useful endpoints**:
```bash
# List connectors
curl http://localhost:8085/connectors

# Get connector status
curl http://localhost:8085/connectors/{name}/status

# List plugins
curl http://localhost:8085/connector-plugins
```

### ClickHouse

**CLI Access** (inside container):
```bash
docker exec -it clickhouse-server clickhouse-client
```

**CLI Access** (from host, if clickhouse-client installed):
```bash
clickhouse-client --host localhost --port 9000 --user default --password 'ClickHouse_Secure_Pass_2024!'
```

**HTTP Interface**:
```bash
# Check version
curl 'http://localhost:8123/?query=SELECT%20version()'

# List databases
curl 'http://localhost:8123/?query=SHOW%20DATABASES'

# Query with authentication
curl -u default:ClickHouse_Secure_Pass_2024! 'http://localhost:8123/?query=SELECT%201'
```

**Web UI**:
- Open browser: http://localhost:8123/play
- Login: default / ClickHouse_Secure_Pass_2024!

---

## Service Management

### Start Services

```bash
cd /home/centos/clickhouse/phase2
docker compose up -d
```

### Stop Services

```bash
docker compose stop
```

### Restart Services

```bash
docker compose restart
```

### Stop and Remove All Services

```bash
docker compose down
```

### Stop and Remove Everything (including volumes)

```bash
docker compose down -v
```

**⚠️ Warning**: This deletes all data!

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f redpanda
docker compose logs -f kafka-connect
docker compose logs -f clickhouse
docker compose logs -f redpanda-console

# Last 100 lines
docker compose logs --tail=100 clickhouse
```

### Check Service Status

```bash
docker compose ps
```

---

## ClickHouse Users

Three users are configured:

| User | Password | Access | Purpose |
|------|----------|--------|---------|
| `default` | From .env (default: ClickHouse_Secure_Pass_2024!) | Full admin | Database administration |
| `kafka_connect` | KafkaConnect_Pass_2024! | Write to analytics DB | Kafka Connect sink |
| `readonly` | ReadOnly_Pass_2024! | Read-only | Power BI, reporting tools |

**Change passwords** in `configs/clickhouse/users.xml` before production use!

---

## Troubleshooting

### Services Won't Start

**Check Docker**:
```bash
sudo systemctl status docker
sudo systemctl start docker
```

**Check ports**:
```bash
netstat -tuln | grep -E "9093|8085|8086|9000|8123"
```

**View errors**:
```bash
docker compose logs
```

### Port Conflicts

If ports are still conflicting, edit `docker-compose.yml` and change the external port mapping:

```yaml
ports:
  - "NEW_PORT:INTERNAL_PORT"
```

Then update your `.env` file with the new port.

### ClickHouse Won't Start

**Check ulimits**:
```bash
ulimit -n
# Should be at least 262144
```

**Increase if needed**:
```bash
sudo vi /etc/security/limits.conf
# Add:
* soft nofile 262144
* hard nofile 262144
```

### Low Memory

**Check available memory**:
```bash
free -h
```

**Reduce memory limits** in `docker-compose.yml`:
```yaml
redpanda:
  command:
    - --memory 512M  # Reduce from 1G
```

### Disk Full

**Check disk usage**:
```bash
docker system df
```

**Clean up**:
```bash
docker system prune -a --volumes
```

---

## Validation Checklist

Before proceeding to Phase 3, verify:

- [ ] All 4 containers running: `docker compose ps`
- [ ] Redpanda cluster healthy: `docker exec redpanda-clickhouse rpk cluster health`
- [ ] Kafka Connect responding: `curl http://localhost:8085/`
- [ ] ClickHouse responding: `curl http://localhost:8123/ping`
- [ ] Redpanda Console accessible: http://localhost:8086
- [ ] ClickHouse CLI works: `docker exec -it clickhouse-server clickhouse-client`
- [ ] Analytics database exists: `SHOW DATABASES` in ClickHouse
- [ ] No errors in logs: `docker compose logs | grep -i error`

---

## Resource Usage

**Typical resource consumption**:

| Service | CPU | Memory | Disk |
|---------|-----|--------|------|
| Redpanda | 5-10% | 500MB-1GB | 500MB |
| Kafka Connect | 2-5% | 512MB-1GB | 100MB |
| ClickHouse | 5-15% | 1-2GB | 1-5GB |
| Console | 1-2% | 100-200MB | 50MB |
| **Total** | **~20%** | **~3GB** | **~2GB** |

**Minimum VPS requirements**:
- 8GB RAM (16GB+ recommended)
- 20GB disk space (50GB+ recommended)
- 4 CPU cores (8+ recommended)

---

## Next Steps

Once all services are healthy:

1. **Verify deployment**: `./scripts/health_check.sh`
2. **Explore Redpanda Console**: http://localhost:8086
3. **Connect to ClickHouse**: `docker exec -it clickhouse-server clickhouse-client`
4. **Proceed to Phase 3**: Create ClickHouse tables and configure Debezium connectors

---

## Phase 3 Preview

**What's coming next**:
- ClickHouse table schemas (ReplacingMergeTree)
- Debezium MySQL source connector configuration
- ClickHouse Sink connector setup
- Initial data load and CDC activation
- Data validation

---

**Phase 2 Status**: Ready for deployment
**Estimated Time**: 15-20 minutes
**Next Phase**: Phase 3 - Data Pipeline Implementation

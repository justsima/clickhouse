# Port Mapping Verification - ClickHouse CDC Pipeline

## Container Port Mappings (from docker-compose.yml)

### Redpanda (Kafka-compatible broker)
- **Internal Kafka** (container-to-container): `redpanda:9092` ✓
  - Used by: Kafka Connect, connectors
- **External Kafka** (host access): `localhost:9093` → container `19092`
  - Used by: External clients (not needed for this pipeline)
- **Schema Registry**: `localhost:8081` → container `18081`
- **HTTP Proxy**: `localhost:8082` → container `18082`
- **Admin API**: `localhost:9644` → container `9644`

### Kafka Connect (Debezium + ClickHouse connectors)
- **REST API**: `localhost:8085` → container `8083` ✓
  - Used by: All deployment/monitoring scripts
  - ⚠️ **Important**: Host uses 8085, container uses 8083

### ClickHouse
- **HTTP Interface**: `localhost:8123` → container `8123` ✓
  - Used by: ClickHouse sink connector, verification scripts
- **Native Protocol**: `localhost:9000` → container `9000` ✓
  - Used by: clickhouse-client CLI

### Redpanda Console (Web UI)
- **Web UI**: `localhost:8086` → container `8080` ✓
  - Used by: Browser access

## Configuration File Port Usage

### .env File ✓
```bash
MYSQL_HOST=mulasport-db-mysql-fra1-89664-do-user-7185962-0.b.db.ondigitalocean.com
MYSQL_PORT=25060                      # External MySQL (DigitalOcean)
CLICKHOUSE_HOST=clickhouse-server     # Container name (not localhost!)
CLICKHOUSE_PORT=8123                  # HTTP port
CLICKHOUSE_NATIVE_PORT=9000           # Native protocol
KAFKA_BOOTSTRAP_SERVERS=redpanda:9092 # Container-to-container
```

### debezium-mysql-source.json ✓
```json
"database.hostname": "${MYSQL_HOST}"   # External: mulasport-db-mysql-fra1...
"database.port": "${MYSQL_PORT}"       # 25060
"schema.history.internal.kafka.bootstrap.servers": "redpanda:9092"  # Container-to-container
```

### clickhouse-sink.json ✓
```json
"hostname": "${CLICKHOUSE_HOST}"       # clickhouse-server (container name)
"port": "${CLICKHOUSE_PORT}"           # 8123 (HTTP)
"topics.regex": "mysql\\.${MYSQL_DATABASE}\\..*"
```

## Script Port Usage Analysis

### ✅ CORRECT - Using Port 8085 for Kafka Connect
These scripts correctly use `localhost:8085` for host access:
- ✓ `/phase3/scripts/03_deploy_connectors.sh`
- ✓ `/phase3/scripts/04_monitor_snapshot.sh`
- ✓ `/phase3/scripts/00_cleanup_restart.sh`
- ✓ `/phase3/scripts/copy_connector_to_container.sh`
- ✓ `/phase3/scripts/install_clickhouse_connector.sh`
- ✓ `/phase3/scripts/diagnose_mysql_connector.sh`
- ✓ `/phase2/scripts/verify_phase3_ready.sh`

### ⚠️ LEGACY SCRIPTS - Reference Old Port 8083
These scripts mention port 8083 but are NOT used in deployment:
- `/phase3/scripts/cleanup_old_containers.sh` - For cleaning up OLD containers
- `/phase3/scripts/fix_port_conflict.sh` - Diagnostic script
- `/phase3/scripts/debug_kafka_connect_api.sh` - Debugging tool
- `/phase3/scripts/diagnose_kafka_connect_crash.sh` - Diagnostic script
- `/phase3/scripts/safe_restart_kafka_connect.sh` - Legacy script

**Note**: These legacy scripts reference 8083 because they were created to DEBUG the old port conflict issue. They are NOT used in the deployment flow.

## Critical Deployment Scripts - Port Verification

### 03_deploy_connectors.sh ✓
```bash
CONNECT_URL="http://localhost:8085"   # ✓ CORRECT - Host access
```

### Connector Configs (substituted from .env) ✓
**MySQL Source Connector:**
```
database.hostname → mulasport-db-mysql-fra1-89664-do-user-7185962-0.b.db.ondigitalocean.com
database.port → 25060
bootstrap.servers → redpanda:9092     # ✓ Container-to-container
```

**ClickHouse Sink Connector:**
```
hostname → clickhouse-server          # ✓ Container name
port → 8123                           # ✓ HTTP port
topics.regex → mysql\.mulazamflatoddbet\..*
```

## Connection Flow

### 1. MySQL to Debezium (Source Connector)
```
External MySQL (mulasport-db-mysql-fra1...:25060)
  ← Debezium connector (inside kafka-connect-clickhouse)
```
**Port used**: 25060 (external) ✓

### 2. Debezium to Redpanda
```
Debezium connector (inside kafka-connect-clickhouse)
  → Redpanda (redpanda:9092)
```
**Port used**: 9092 (container-to-container) ✓

### 3. Redpanda to ClickHouse Sink
```
Redpanda (redpanda:9092)
  → ClickHouse Sink connector (inside kafka-connect-clickhouse)
  → ClickHouse (clickhouse-server:8123)
```
**Ports used**: 9092, 8123 (container-to-container) ✓

### 4. Host to Kafka Connect API (Monitoring/Deployment)
```
Host machine (scripts)
  → Kafka Connect REST API (localhost:8085)
  → Maps to container port 8083
```
**Port used**: 8085 (host access) ✓

### 5. Host to ClickHouse (Verification)
```
Host machine (scripts)
  → ClickHouse HTTP (localhost:8123)
```
**Port used**: 8123 (host access) ✓

## Port Conflict History (Resolved)

**Previous Issue**: Old `kafka-connect` container (4 weeks old) was using host port 8083
**Resolution**:
- Removed old container completely
- New `kafka-connect-clickhouse` uses host port 8085 → container 8083
- All active deployment scripts updated to use port 8085

## Summary - Ready for Deployment ✅

### Container-to-Container Communication (Inside Docker Network)
- ✓ Debezium → Redpanda: `redpanda:9092`
- ✓ ClickHouse Sink → ClickHouse: `clickhouse-server:8123`
- ✓ Connectors → Redpanda Schema History: `redpanda:9092`

### Host-to-Container Communication (Scripts from Host)
- ✓ Deployment scripts → Kafka Connect API: `localhost:8085`
- ✓ Verification scripts → ClickHouse HTTP: `localhost:8123`
- ✓ Monitoring scripts → Kafka Connect API: `localhost:8085`

### External Communication
- ✓ Debezium → External MySQL: `mulasport-db-mysql-fra1-89664-do-user-7185962-0.b.db.ondigitalocean.com:25060`

## Deployment Pre-Flight Check ✅

Run this to verify all ports are correctly configured:

```bash
cd /home/user/clickhouse/phase2/scripts
./verify_phase3_ready.sh
```

Expected results:
- ✓ Kafka Connect API responding on port 8085
- ✓ Redpanda broker responding
- ✓ ClickHouse HTTP responding on port 8123
- ✓ All connector configs use correct ports
- ✓ All deployment scripts use port 8085

**Status**: All ports correctly configured for deployment! 🚀

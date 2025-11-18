# Phase 3: Data Pipeline Implementation

## Overview

This phase implements the complete data replication pipeline from MySQL to ClickHouse using:
- **Debezium** for MySQL Change Data Capture
- **Redpanda (Kafka)** as the message broker
- **ClickHouse** as the analytical database

## Current Mode: FULL CDC (Real-Time Streaming)

This implementation uses **full CDC mode** which:
- ✅ Copies all existing data from MySQL to ClickHouse (initial snapshot)
- ✅ Provides **real-time CDC** for continuous data streaming
- ✅ Captures INSERT, UPDATE, DELETE operations as they happen
- ✅ Requires MySQL replication privileges (REPLICATION SLAVE/CLIENT)

**The pipeline will**:
1. First perform an initial snapshot of all existing data
2. Then continuously stream changes from MySQL binlog in real-time

---

## Quick Start

### Prerequisites

- ✅ Phase 2 completed (all services running and healthy)
- ✅ MySQL credentials configured in `configs/.env`
- ✅ Sufficient disk space (~30GB for initial data + overhead)

### Step-by-Step Execution

```bash
cd /home/centos/clickhouse/phase3

# Make all scripts executable
chmod +x scripts/*.sh

# Step 1: Analyze MySQL schema and generate ClickHouse DDL (15-20 min)
./scripts/01_analyze_mysql_schema.sh

# Step 2: Create ClickHouse tables (10-15 min)
./scripts/02_create_clickhouse_schema.sh

# Step 3: Deploy Debezium and ClickHouse connectors (5-10 min)
./scripts/03_deploy_connectors.sh

# Step 4: Monitor snapshot progress (2-4 hours, runs continuously)
./scripts/04_monitor_snapshot.sh

# Step 5: Validate data accuracy after snapshot completes (15-30 min)
./scripts/05_validate_data.sh
```

---

## Script Details

### 01_analyze_mysql_schema.sh

**Purpose**: Analyzes MySQL database structure and generates ClickHouse DDL

**What it does**:
1. Connects to MySQL and fetches list of all tables
2. Extracts CREATE TABLE statements for each table
3. Analyzes primary keys, row counts, and table sizes
4. Converts MySQL data types to ClickHouse equivalents
5. Generates ClickHouse CREATE TABLE statements with:
   - ReplacingMergeTree engine for deduplication
   - Proper ORDER BY based on primary keys
   - CDC metadata columns (_version, _is_deleted, _extracted_at)

**Output**:
- `schema_output/table_list.txt` - List of all tables
- `schema_output/schema_summary.txt` - Summary with row counts and sizes
- `schema_output/mysql_ddl/` - Original MySQL DDL files
- `schema_output/clickhouse_ddl/` - Converted ClickHouse DDL files

**Duration**: 15-20 minutes for 450 tables

---

### 02_create_clickhouse_schema.sh

**Purpose**: Creates all ClickHouse tables from generated DDL

**What it does**:
1. Verifies ClickHouse connection
2. Creates `analytics` database (if not exists)
3. Executes all generated DDL files
4. Verifies table creation

**Output**:
- All 450 tables created in `analytics` database
- Progress shown in real-time

**Duration**: 10-15 minutes

**Troubleshooting**:
- If tables fail to create, check DDL files in `schema_output/clickhouse_ddl/`
- Some complex MySQL types may need manual adjustment

---

### 03_deploy_connectors.sh

**Purpose**: Deploys Debezium MySQL source and ClickHouse sink connectors

**What it does**:
1. Checks Kafka Connect status
2. Installs ClickHouse connector plugin (if not present)
3. Deploys Debezium MySQL source connector with:
   - **snapshot.mode = initial_only** (snapshot without CDC)
   - Table filtering (all tables by default)
   - JSON message format
4. Deploys ClickHouse sink connector
5. Verifies both connectors are running

**Configuration Files**:
- `configs/debezium-mysql-source.json` - Debezium configuration
- `configs/clickhouse-sink.json` - ClickHouse sink configuration

**Duration**: 5-10 minutes

**Important Notes**:
- Snapshot mode is set to `initial_only` - does snapshot then stops
- No MySQL replication privileges required for snapshot
- Connectors can be redeployed by re-running this script

---

### 04_monitor_snapshot.sh

**Purpose**: Real-time monitoring of snapshot progress

**What it does**:
1. Shows connector status (RUNNING/FAILED)
2. Displays Kafka topic count and message count
3. Shows ClickHouse table count and total rows
4. Calculates throughput (rows/sec)
5. Lists top 5 tables by row count
6. Alerts on errors

**Usage**:
```bash
./scripts/04_monitor_snapshot.sh
```

**Controls**:
- Auto-refreshes every 10 seconds
- Press `Ctrl+C` to stop monitoring
- Automatically exits when snapshot completes

**Duration**: Runs until snapshot complete (2-4 hours typically)

**Expected Throughput**:
- 50,000-100,000 rows/sec (depends on table size and network)
- Faster for large tables, slower for many small tables

---

### 05_validate_data.sh

**Purpose**: Validates data accuracy between MySQL and ClickHouse

**What it does**:
1. Compares table counts (MySQL vs ClickHouse)
2. Compares row counts for every table
3. Calculates total rows and data size
4. Tests sample records for accuracy
5. Measures ClickHouse query performance
6. Generates detailed validation report

**Output**:
- Console summary
- `validation_output/validation_report_*.txt` - Full report
- `validation_output/row_count_comparison.csv` - Per-table comparison

**Duration**: 15-30 minutes for 450 tables

**Success Criteria**:
- ✅ Table count matches 100%
- ✅ Row count accuracy >= 95%
- ✅ Sample records match

---

## Configuration

### Environment Variables (configs/.env)

Key configuration options:

```bash
# MySQL Source
MYSQL_HOST=...
MYSQL_PORT=25060
MYSQL_USER=mulazamuser
MYSQL_PASSWORD=...
MYSQL_DATABASE=mulazamflatoddbet

# ClickHouse Target
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_PORT=8123
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=ClickHouse_Secure_Pass_2024!

# Snapshot Mode (IMPORTANT!)
DEBEZIUM_SNAPSHOT_MODE=initial_only  # Snapshot without CDC

# Performance Tuning
CLICKHOUSE_SINK_BATCH_SIZE=50000      # Batch insert size
CLICKHOUSE_SINK_FLUSH_INTERVAL_MS=30000  # Flush interval
```

---

## Data Flow Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   MySQL     │         │  Redpanda   │         │ ClickHouse  │
│  (Source)   │         │   (Kafka)   │         │  (Target)   │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │
       │ 1. Debezium reads     │                       │
       │    SELECT * FROM tbl  │                       │
       ├──────────────────────►│                       │
       │                       │                       │
       │                       │ 2. Message:           │
       │                       │    Topic: mysql.db.t  │
       │                       │    Data: {row JSON}   │
       │                       │                       │
       │                       │ 3. Sink consumes      │
       │                       ├──────────────────────►│
       │                       │                       │
       │                       │                       │ 4. INSERT
       │                       │                       │    INTO tbl
       │                       │                       │
       │ Repeat for all        │                       │
       │ 450 tables            │                       │
       │                       │                       │
```

---

## Monitoring & Troubleshooting

### Check Connector Status

```bash
# List all connectors
curl http://localhost:8085/connectors | jq

# Check Debezium status
curl http://localhost:8085/connectors/mysql-source-connector/status | jq

# Check ClickHouse sink status
curl http://localhost:8085/connectors/clickhouse-sink-connector/status | jq
```

### View Connector Logs

```bash
# Kafka Connect logs (includes both connectors)
docker logs -f kafka-connect-clickhouse

# Filter for errors
docker logs kafka-connect-clickhouse 2>&1 | grep -i error

# Filter for specific connector
docker logs kafka-connect-clickhouse 2>&1 | grep "mysql-source-connector"
```

### Check Kafka Topics

```bash
# List all topics
docker exec redpanda-clickhouse rpk topic list | grep mysql

# Describe a specific topic
docker exec redpanda-clickhouse rpk topic describe mysql.mulazamflatoddbet.users

# Consume messages from a topic (sample)
docker exec redpanda-clickhouse rpk topic consume mysql.mulazamflatoddbet.users --num 5
```

### Query ClickHouse

```bash
# Connect to ClickHouse
docker exec -it clickhouse-server clickhouse-client --password 'ClickHouse_Secure_Pass_2024!'

# Inside ClickHouse:
SHOW DATABASES;
USE analytics;
SHOW TABLES;

# Check row count for a table
SELECT count() FROM users WHERE _is_deleted = 0;

# Check latest records
SELECT * FROM users FINAL WHERE _is_deleted = 0 ORDER BY _extracted_at DESC LIMIT 10;

# Check metadata
SELECT
    name as table,
    total_rows,
    formatReadableSize(total_bytes) as size
FROM system.tables
WHERE database = 'analytics'
ORDER BY total_rows DESC
LIMIT 20;
```

### Redpanda Console (Web UI)

Access via SSH tunnel: http://localhost:8086

- View all Kafka topics
- Browse messages in real-time
- Monitor consumer lag
- Check connector status

---

## Common Issues & Solutions

### Issue 1: Debezium Connector Fails to Start

**Symptoms**:
- Connector status shows `FAILED`
- Error in logs about MySQL connection

**Solutions**:
1. Verify MySQL credentials in `configs/.env`
2. Test MySQL connectivity:
   ```bash
   mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1;"
   ```
3. Check if MySQL is accessible from VPS
4. Verify binlog_format is ROW:
   ```bash
   mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SHOW VARIABLES LIKE 'binlog_format';"
   ```

### Issue 2: ClickHouse Sink Connector Not Installing

**Symptoms**:
- Script fails during connector plugin installation
- ClickHouse sink connector status is NOT_FOUND

**Solutions**:
1. Check if connector JAR downloaded successfully:
   ```bash
   docker exec kafka-connect-clickhouse ls -lh /kafka/connect/clickhouse-connector/
   ```
2. Manually download and install:
   ```bash
   docker exec kafka-connect-clickhouse bash -c "
       curl -L -o /tmp/ch-connector.tar.gz \
           https://github.com/ClickHouse/clickhouse-kafka-connect/releases/download/v1.0.0/clickhouse-kafka-connect-v1.0.0.tar.gz &&
       tar -xzf /tmp/ch-connector.tar.gz -C /kafka/connect/clickhouse-connector/
   "
   docker restart kafka-connect-clickhouse
   ```
3. If still failing, we can use alternative sink approach (JDBC)

### Issue 3: Slow Snapshot Progress

**Symptoms**:
- Throughput < 10,000 rows/sec
- Snapshot taking > 6 hours

**Solutions**:
1. Check MySQL query performance (table locks?)
2. Increase Kafka Connect resources in docker-compose
3. Optimize ClickHouse insert batch size:
   - Edit `configs/clickhouse-sink.json`
   - Increase `bufferCount` to 100000
   - Decrease `flushInterval` to 15 seconds
4. Check network bandwidth:
   ```bash
   # On VPS
   iftop -i eth0
   ```

### Issue 4: Row Count Mismatch

**Symptoms**:
- Validation shows MySQL has more rows than ClickHouse
- Some tables missing data

**Solutions**:
1. Check if snapshot completed:
   ```bash
   curl http://localhost:8085/connectors/mysql-source-connector/status | jq '.tasks[].state'
   ```
2. Check for errors in connector logs
3. Verify ClickHouse didn't skip records:
   ```bash
   docker exec clickhouse-server clickhouse-client --password 'ClickHouse_Secure_Pass_2024!' --query \
       "SELECT count() FROM system.errors WHERE event_date = today()"
   ```
4. Re-run snapshot for specific tables:
   - Delete connector
   - Update table filter in config
   - Re-deploy connector

### Issue 5: Out of Disk Space

**Symptoms**:
- ClickHouse writes failing
- Kafka topics full

**Solutions**:
1. Check disk usage:
   ```bash
   df -h
   docker system df
   ```
2. Clean up old Docker data:
   ```bash
   docker system prune -a --volumes
   ```
3. Reduce Kafka retention:
   ```bash
   docker exec redpanda-clickhouse rpk topic alter-config mysql.mulazamflatoddbet.* --set retention.ms=86400000
   ```

---

## Upgrading to Full CDC Mode

**When you get MySQL replication privileges**, upgrade from snapshot-only to full CDC:

### Step 1: Grant MySQL Privileges

```sql
-- On MySQL server
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'mulazamuser'@'%';
FLUSH PRIVILEGES;
```

### Step 2: Update Debezium Configuration

Edit `configs/debezium-mysql-source.json`:

```json
{
  "snapshot.mode": "initial",  // Changed from "initial_only"
  ...
}
```

### Step 3: Redeploy Connector

```bash
# Delete old connector
curl -X DELETE http://localhost:8085/connectors/mysql-source-connector

# Deploy updated connector
./scripts/03_deploy_connectors.sh
```

### Step 4: Verify CDC is Active

```bash
# Check connector is reading binlog
curl http://localhost:8085/connectors/mysql-source-connector/status | jq '.connector.state'

# Should show binlog position
docker logs kafka-connect-clickhouse 2>&1 | grep "binlog"
```

---

## Performance Benchmarks

### Expected Performance (450 tables, 21.7GB data)

| Metric | Value |
|--------|-------|
| **Schema Analysis** | 15-20 minutes |
| **Table Creation** | 10-15 minutes |
| **Snapshot Duration** | 2-4 hours |
| **Throughput** | 50,000-100,000 rows/sec |
| **Data Compression** | 3-4x (5-8GB in ClickHouse) |
| **Validation** | 15-30 minutes |
| **Total Time** | 3-5 hours |

### Resource Usage During Snapshot

| Component | CPU | Memory | Network |
|-----------|-----|--------|---------|
| MySQL | 5-10% | Minimal | 20-50 Mbps out |
| Debezium | 10-20% | 500MB-1GB | 20-50 Mbps |
| Kafka | 10-20% | 200-400MB | 40-100 Mbps |
| ClickHouse | 20-40% | 1-2GB | 20-50 Mbps in |

---

## Next Steps

After Phase 3 completion:

1. **Phase 4: Operational Readiness**
   - Set up monitoring dashboards
   - Configure alerting
   - Create operational runbooks

2. **BI Integration**
   - Connect Power BI to ClickHouse
   - Create materialized views for common queries
   - Optimize query performance

3. **CDC Upgrade** (when privileges granted)
   - Switch to full CDC mode
   - Enable real-time sync
   - Test update/delete operations

---

## Files & Directories

```
phase3/
├── README.md                          # This file
├── TECHNICAL_DETAILS.md               # Deep technical documentation
├── configs/
│   ├── .env.example                   # Configuration template
│   ├── .env                           # Actual configuration (gitignored)
│   ├── debezium-mysql-source.json     # Debezium connector config
│   └── clickhouse-sink.json           # ClickHouse sink config
├── scripts/
│   ├── 01_analyze_mysql_schema.sh     # Schema analysis
│   ├── 02_create_clickhouse_schema.sh # Table creation
│   ├── 03_deploy_connectors.sh        # Connector deployment
│   ├── 04_monitor_snapshot.sh         # Progress monitoring
│   └── 05_validate_data.sh            # Data validation
├── schema_output/                     # Generated by script 01
│   ├── table_list.txt
│   ├── schema_summary.txt
│   ├── mysql_ddl/
│   └── clickhouse_ddl/
└── validation_output/                 # Generated by script 05
    ├── validation_report_*.txt
    └── row_count_comparison.csv
```

---

## Support

If you encounter issues:

1. Check logs: `docker logs kafka-connect-clickhouse`
2. Review validation reports in `validation_output/`
3. Verify connector status: `curl http://localhost:8085/connectors/{name}/status`
4. Check Redpanda Console: http://localhost:8086

---

**Phase 3 Status**: Ready for deployment

**Last Updated**: 2025-11-17

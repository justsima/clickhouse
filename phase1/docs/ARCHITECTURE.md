# MySQL to ClickHouse CDC Pipeline - Architecture Documentation

## Overview

This document describes the complete architecture for real-time data replication from MySQL to ClickHouse for analytical workloads.

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                          DATA FLOW                                   │
└──────────────────────────────────────────────────────────────────────┘

┌─────────────────┐         ┌─────────────────┐         ┌──────────────┐
│   MySQL (DO)    │         │  Redpanda       │         │  ClickHouse  │
│                 │         │  Kafka API      │         │              │
│  - Binlog ROW   │◄────────│  - Topics       │─────────►│  Replacing   │
│  - GTID Mode    │ Read    │  - Partitions   │ Write   │  MergeTree   │
│  - 100M rows    │         │  - Consumer Grp │         │  - Dedup     │
└────────┬────────┘         └────────┬────────┘         └──────┬───────┘
         │                           │                         │
         │                           │                         │
         │                  ┌────────▼─────────┐              │
         │                  │  Kafka Connect   │              │
         │                  │  (REST API 8083) │              │
         └─────────────────►│                  │──────────────┘
           Debezium CDC     │  - Source        │  CH Sink
                            │  - Sink          │
                            │  - DLQ           │
                            └──────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                       MANAGEMENT LAYER                              │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐      ┌──────────────────┐      ┌────────────────┐
│ Redpanda Console │      │  Power BI        │      │  Monitoring    │
│  (Port 8080)     │      │  DirectQuery     │      │  - Prometheus  │
│  - Topics        │      │  via Gateway     │      │  - Grafana     │
│  - Consumers     │      │  - Pre-aggs      │      │  - Logs        │
│  - Lag Monitor   │      │  - Detail views  │      │                │
└──────────────────┘      └──────────────────┘      └────────────────┘
```

---

## Component Details

### 1. Source: MySQL on DigitalOcean

**Purpose**: OLTP database serving production application

**Configuration Requirements**:
- `binlog_format = ROW` (required)
- `binlog_row_image = FULL` (recommended)
- `log_bin = 1` (binary logging enabled)
- `gtid_mode = ON` (recommended for reliability)
- Binlog retention: 3-7 days minimum

**Database Characteristics**:
- Version: MySQL 8.0
- Size: ~100M rows
- Access: Replication user with privileges:
  - `REPLICATION SLAVE`
  - `REPLICATION CLIENT`
  - `SELECT` on target databases
  - `RELOAD` (if available)
  - `LOCK TABLES` (for consistent snapshots)

**Impact on Production**: Zero - CDC reads binlog only, no load on OLTP queries

---

### 2. Change Data Capture: Debezium

**Purpose**: Capture MySQL changes and publish to Kafka

**How it Works**:
1. **Initial Snapshot** (Day 3):
   - Takes consistent snapshot of existing data
   - Uses table locks (FTWRL) or GTID for consistency
   - Publishes all rows as INSERT events

2. **Ongoing CDC**:
   - Reads MySQL binlog in real-time
   - Converts binlog events to Kafka messages
   - Maintains binlog position for recovery

**Configuration**:
- **Connector Type**: Debezium MySQL Source Connector
- **Snapshot Mode**: `initial` or `schema_only` (for bulk backfill)
- **Topic Naming**: `{prefix}.{database}.{table}`
- **Key**: Primary key of table
- **Value**: Full row data + metadata

**Deployment**: Runs in Kafka Connect framework

**Port**: N/A (connects to Kafka Connect REST 8083)

---

### 3. Message Broker: Redpanda

**Purpose**: Kafka-compatible streaming platform for CDC events

**Why Redpanda vs Kafka**:
- ✅ Single binary, no JVM, no Zookeeper
- ✅ Lower resource usage on single VPS
- ✅ 100% Kafka API compatible
- ✅ Built-in Admin UI and monitoring
- ⚠️ Can swap to Apache Kafka later if needed

**Ports Exposed**:
- **9092**: Kafka API (producers/consumers)
- **9644**: Admin API & Metrics
- **8081**: Schema Registry
- **8082**: HTTP Proxy

**Configuration**:
- **Node Mode**: Single node (development)
- **Partitions**: 3-5 per topic (start small)
- **Retention**: 7 days (align with binlog retention)
- **Replication Factor**: 1 (single node)

**Topics Structure**:
```
mysql-cdc.mydb.users        (user table changes)
mysql-cdc.mydb.orders       (order table changes)
mysql-cdc.mydb.products     (product table changes)
dlq.clickhouse-sink         (dead letter queue)
```

**Consumer Groups**:
- `clickhouse-sink-group`: ClickHouse sink connector

---

### 4. Kafka Connect

**Purpose**: Framework for running connectors (Debezium + ClickHouse Sink)

**Port**: 8083 (REST API)

**Connectors Deployed**:

1. **Debezium MySQL Source Connector**
   - Config: `/phase2/configs/debezium-source.json`
   - Tasks: 1 per connector

2. **ClickHouse Sink Connector**
   - Config: `/phase2/configs/clickhouse-sink.json`
   - Tasks: 1 per topic (parallelizable)

**REST API Endpoints**:
- `GET /connectors` - List all connectors
- `POST /connectors` - Create connector
- `GET /connectors/{name}/status` - Check status
- `DELETE /connectors/{name}` - Remove connector

**Error Handling**:
- Dead Letter Queue (DLQ) for bad messages
- Retry policies for transient errors
- Automatic offset management

---

### 5. Sink: ClickHouse

**Purpose**: High-performance analytical database for OLAP queries

**Ports**:
- **9000**: Native protocol (CLI, drivers)
- **8123**: HTTP interface (REST API, web UI)

**Data Model**:

#### Table Engine: ReplacingMergeTree

```sql
CREATE TABLE users_raw (
    id UInt64,
    email String,
    name String,
    created_at DateTime,
    updated_at DateTime,
    is_deleted UInt8 DEFAULT 0,
    _version DateTime64(3) DEFAULT now64(3)  -- Version for deduplication
) ENGINE = ReplacingMergeTree(_version)
ORDER BY id
SETTINGS index_granularity = 8192;
```

**Why ReplacingMergeTree**:
- ✅ Handles updates (via versioned upserts)
- ✅ Eventual deduplication during merges
- ✅ Fast inserts (append-only, then merge)
- ⚠️ May see duplicates until merge completes
- ⚠️ Use views to enforce "latest row" semantics

#### Soft Deletes Pattern

```sql
-- Debezium rewrites DELETE to UPDATE is_deleted=1
-- Never use ClickHouse DELETE mutations (too slow)

-- View to hide deleted rows
CREATE VIEW users AS
SELECT * FROM users_raw
WHERE is_deleted = 0;
```

#### Pre-Aggregated Views

```sql
-- Avoid FINAL in queries (expensive full scan)
-- Use pre-aggs instead

CREATE MATERIALIZED VIEW user_stats_daily
ENGINE = SummingMergeTree()
ORDER BY (date, country)
AS SELECT
    toDate(created_at) as date,
    country,
    count() as user_count,
    uniq(id) as unique_users
FROM users_raw
WHERE is_deleted = 0
GROUP BY date, country;
```

**Batch Inserts**:
- Sink batches 10k-100k rows per INSERT
- Fewer parts = fewer merges = faster queries
- Configure in ClickHouse Sink: `batch.size=50000`

**Disk Usage**:
- Reserve 30-40% free space for background merges
- ClickHouse rewrites parts during compaction
- Monitor: `system.parts` table

---

### 6. Management: Redpanda Console

**Purpose**: Web UI for managing Kafka topics, consumers, and connectors

**Port**: 8080

**Features**:
- Browse topics and messages
- Monitor consumer lag
- Inspect message payloads
- Manage Kafka Connect connectors
- View schema registry

**Access**:
- URL: `http://<vps-ip>:8080`
- Auth: Basic auth (configure in Phase 2)

---

### 7. BI Layer: Power BI

**Purpose**: Interactive dashboards and reports for business users

**Integration**:
- **Connector**: Official ClickHouse connector for Power BI
- **Mode**: DirectQuery (live queries, no import)
- **Gateway**: On-premises data gateway (VPS)

**Query Strategy**:
1. **Fast visuals**: Query pre-aggs (sub-second)
   ```sql
   SELECT date, sum(user_count) FROM user_stats_daily
   WHERE date >= today() - 30
   GROUP BY date;
   ```

2. **Drill-downs**: Query detail tables (seconds)
   ```sql
   SELECT * FROM users
   WHERE created_at >= today() - 7
   AND country = 'US';
   ```

**Performance Tips**:
- Use ClickHouse indexes on filter columns
- Apply date range filters (partition pruning)
- Limit large result sets (TOP N)
- Cache frequently accessed views

---

## Data Flow Sequence

### Initial Load (Day 3)

```
1. Debezium starts snapshot
   ├─ Locks tables (or uses GTID)
   ├─ Reads binlog position
   └─ Streams all rows to Kafka

2. Kafka stores messages
   ├─ Partitioned by primary key
   └─ Retained for 7 days

3. ClickHouse Sink consumes
   ├─ Batches 50k rows
   ├─ Inserts to ReplacingMergeTree
   └─ Background merges deduplicate

4. User validates
   ├─ Row counts match
   └─ Sample data queries work
```

### Ongoing CDC (Real-time)

```
1. App updates MySQL
   └─ UPDATE users SET email='...' WHERE id=123

2. MySQL writes binlog
   └─ ROW format with before/after images

3. Debezium reads binlog
   └─ Converts to Kafka message

4. Kafka publishes
   └─ Topic: mysql-cdc.mydb.users, Key: 123

5. ClickHouse Sink consumes
   └─ INSERT with new _version timestamp

6. ClickHouse merges
   └─ Keeps latest _version, drops old

7. Power BI queries
   └─ Sees updated data (latest version)
```

**Latency**: Seconds (typically 2-5s end-to-end)

---

## Failure Scenarios & Recovery

### Debezium Connector Fails

**Symptom**: Lag increases, no new messages in Kafka

**Recovery**:
1. Check Kafka Connect logs: `/connectors/{name}/status`
2. Fix issue (credentials, network, schema change)
3. Restart connector: `POST /connectors/{name}/restart`
4. Debezium resumes from last binlog position (no data loss)

### ClickHouse Sink Fails

**Symptom**: Consumer lag, Kafka messages pile up

**Recovery**:
1. Check DLQ topic for bad messages
2. Fix ClickHouse schema or data issues
3. Restart sink connector
4. Replay from last committed offset (idempotent)

### Disk Full on ClickHouse

**Symptom**: Inserts fail, merges stall

**Prevention**:
- Monitor disk usage (keep 30-40% free)
- Implement retention policies (DROP PARTITION)
- Use tiered storage for cold data

**Recovery**:
1. Delete old partitions: `ALTER TABLE ... DROP PARTITION ...`
2. Stop merges temporarily: `SYSTEM STOP MERGES`
3. Add disk space or scale up

### Network Outage VPS ↔ MySQL

**Symptom**: Debezium cannot read binlog

**Recovery**:
- Debezium retries automatically
- As long as binlog retention covers outage, no data loss
- If binlog expires, must re-snapshot (check binlog position)

---

## Scaling Considerations

### Current Setup (Single VPS)

- ✅ Good for: <100M rows, <1M events/day
- ✅ Cost-effective, simple ops
- ⚠️ Single point of failure

### When to Scale

**Indicators**:
- Consumer lag consistently >1 minute
- Disk I/O saturated (check `iostat`)
- Redpanda CPU >80% sustained
- ClickHouse query latency increasing

**Scaling Paths**:

1. **Vertical Scaling** (easiest):
   - Upgrade VPS: more CPU, RAM, faster disks
   - No architecture changes

2. **Horizontal Scaling**:
   - **Redpanda**: Add nodes (multi-broker cluster)
   - **ClickHouse**: Add shards (distributed tables)
   - **Kafka Connect**: Run multiple workers

3. **Separate Services** (isolation):
   - Redpanda on dedicated VPS
   - ClickHouse on dedicated VPS
   - Kafka Connect on app servers

---

## Security & Access Control

### Network Security

- **Firewall Rules**:
  ```
  Allow: Your IP → VPS (all ports)
  Allow: VPS → MySQL (port 25060)
  Deny: All others
  ```

- **VPN Access**: You connect to VPS via VPN
- **Internal**: All services communicate on localhost

### Authentication

- **MySQL**: Replication user (read-only)
- **ClickHouse**: User with INSERT/SELECT on target database
- **Redpanda Console**: Basic auth (username/password)
- **Kafka Connect REST**: No auth by default (restrict by firewall)

### Secrets Management

- All credentials in `.env` file (gitignored)
- Docker Compose reads `.env` automatically
- Never commit secrets to git

---

## Monitoring & Observability

### Key Metrics to Track

1. **Debezium**:
   - Binlog lag (seconds behind master)
   - Events published/second
   - Connector status (running/failed)

2. **Redpanda**:
   - Consumer lag per group
   - Throughput (MB/s in/out)
   - Disk usage per topic

3. **ClickHouse**:
   - Query latency (p50, p95, p99)
   - Parts per table (high = merge pressure)
   - Disk usage & free space
   - Insert rate (rows/s)

4. **End-to-End**:
   - Data freshness (lag from MySQL to ClickHouse)
   - Row count parity (MySQL vs ClickHouse)

### Tools (Phase 4)

- **Redpanda Console**: Built-in monitoring
- **ClickHouse**: `system.*` tables
- **Custom Scripts**: Validation queries
- **Prometheus + Grafana**: (optional, advanced)

---

## Cost Considerations

### VPS Costs

- **Current**: 64GB RAM, 1TB disk (~$200-400/month)
- **Future**: Scale up as needed

### Data Transfer

- **DO → VPS**: Outbound from DO (may incur charges)
- **Estimate**: 100M rows ~50GB initial + daily changes

### Disk Usage

- **Kafka Retention**: 7 days × daily volume
- **ClickHouse**: Compressed (5-10x smaller than MySQL)
- **Example**: 100GB MySQL → 10-20GB ClickHouse

---

## Next Steps

After Phase 1 validation:

1. **Phase 2**: Deploy all services (Docker Compose)
2. **Phase 3**: Configure CDC pipeline + ClickHouse schema
3. **Phase 4**: Connect Power BI + operational monitoring

---

## References

- [Debezium MySQL Connector Docs](https://debezium.io/documentation/reference/stable/connectors/mysql.html)
- [Redpanda Documentation](https://docs.redpanda.com/)
- [ClickHouse ReplacingMergeTree](https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replacingmergetree)
- [Kafka Connect Architecture](https://docs.confluent.io/platform/current/connect/index.html)
- [Power BI ClickHouse Connector](https://learn.microsoft.com/en-us/power-query/connectors/clickhouse)

---

**Document Version**: 1.0
**Last Updated**: Phase 1
**Status**: Ready for Implementation

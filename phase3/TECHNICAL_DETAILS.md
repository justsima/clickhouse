# Technical Details: MySQL to ClickHouse Data Flow

## Complete Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    WITHOUT REPLICATION PRIVILEGES                        │
│                      (Phase A: Snapshot Only)                            │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐         ┌──────────────────┐         ┌──────────────┐
│  MySQL Database  │         │  Kafka (Redpanda)│         │  ClickHouse  │
│  mulazamflat..   │         │                  │         │  analytics   │
└────────┬─────────┘         └────────┬─────────┘         └──────┬───────┘
         │                            │                          │
         │  1. SELECT * FROM users    │                          │
         │◄───────────────────────────┼──────────────────────────│
         │     (Debezium Snapshot)    │                          │
         │                            │                          │
         │  2. Returns 1M rows        │                          │
         ├───────────────────────────►│                          │
         │                            │                          │
         │                            │  3. Kafka Messages       │
         │                            │  Topic: mysql.db.users   │
         │                            │  Message: {id:1, ...}    │
         │                            │                          │
         │                            │  4. Consume Messages     │
         │                            ├─────────────────────────►│
         │                            │     (ClickHouse Sink)    │
         │                            │                          │
         │                            │  5. INSERT INTO users    │
         │                            │                          ├──┐
         │                            │                          │  │ Write
         │                            │                          │◄─┘
         │                            │                          │
         │  Repeat for all 450 tables │                          │
         │                            │                          │


┌─────────────────────────────────────────────────────────────────────────┐
│                    WITH REPLICATION PRIVILEGES                           │
│                 (Phase B: Real-Time CDC via Binlog)                      │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐         ┌──────────────────┐         ┌──────────────┐
│  MySQL Binlog    │         │  Kafka (Redpanda)│         │  ClickHouse  │
│  (mysql-bin.*)   │         │                  │         │  analytics   │
└────────┬─────────┘         └────────┬─────────┘         └──────┬───────┘
         │                            │                          │
         │  Real-time Events:         │                          │
         │                            │                          │
         │  INSERT INTO users         │                          │
         │  VALUES (id=1001, ...)     │                          │
         ├───────────────────────────►│  1. Binlog Event         │
         │                            │  {op: "c", after: {...}} │
         │                            │                          │
         │  UPDATE users              │                          │
         │  SET name='John'           │                          │
         │  WHERE id=1001             │                          │
         ├───────────────────────────►│  2. Binlog Event         │
         │                            │  {op: "u", before: {...},│
         │                            │   after: {...}}          │
         │                            │                          │
         │  DELETE FROM users         │                          │
         │  WHERE id=1001             │                          │
         ├───────────────────────────►│  3. Binlog Event         │
         │                            │  {op: "d", before: {...}}│
         │                            │                          │
         │                            │  4. Consume in order     │
         │                            ├─────────────────────────►│
         │                            │                          │
         │                            │  5. INSERT with version  │
         │                            │     (ReplacingMergeTree  │
         │                            │      handles dedup)      │
         │                            │                          ├──┐
         │                            │                          │  │
         │  Latency: 100-500ms        │                          │◄─┘
         │                            │                          │
```

## Data Format Examples

### Debezium Snapshot Message (Phase A)
```json
{
  "schema": { ... },
  "payload": {
    "before": null,
    "after": {
      "id": 1001,
      "username": "john_doe",
      "email": "john@example.com",
      "created_at": "2025-01-15T10:30:00Z"
    },
    "source": {
      "version": "2.5.0",
      "connector": "mysql",
      "name": "mysql-server",
      "ts_ms": 1705315800000,
      "snapshot": "true",
      "db": "mulazamflatoddbet",
      "table": "users",
      "server_id": 0,
      "gtid": null,
      "file": null,
      "pos": 0,
      "row": 0
    },
    "op": "r",  // "r" = read (snapshot)
    "ts_ms": 1705315800123
  }
}
```

### Debezium CDC Message (Phase B - Real-time)

**INSERT Event:**
```json
{
  "payload": {
    "before": null,
    "after": {
      "id": 1002,
      "username": "jane_doe",
      "email": "jane@example.com",
      "created_at": "2025-01-15T11:00:00Z"
    },
    "source": {
      "snapshot": "false",
      "db": "mulazamflatoddbet",
      "table": "users",
      "file": "mysql-bin.000123",
      "pos": 45678,
      "gtid": "3e11fa47-45a1-11e5-b029-0800279114db:1-123"
    },
    "op": "c",  // "c" = create (insert)
    "ts_ms": 1705317600000
  }
}
```

**UPDATE Event:**
```json
{
  "payload": {
    "before": {
      "id": 1001,
      "username": "john_doe",
      "email": "john@example.com"
    },
    "after": {
      "id": 1001,
      "username": "john_doe",
      "email": "john.doe@example.com"  // Email changed
    },
    "source": { ... },
    "op": "u",  // "u" = update
    "ts_ms": 1705317650000
  }
}
```

**DELETE Event:**
```json
{
  "payload": {
    "before": {
      "id": 1001,
      "username": "john_doe",
      "email": "john.doe@example.com"
    },
    "after": null,
    "source": { ... },
    "op": "d",  // "d" = delete
    "ts_ms": 1705317700000
  }
}
```

## ClickHouse ReplacingMergeTree Handling

### Table Definition
```sql
CREATE TABLE analytics.users
(
    id Int64,
    username String,
    email String,
    created_at DateTime,
    _version UInt64,           -- For deduplication
    _is_deleted UInt8 DEFAULT 0 -- Soft deletes
)
ENGINE = ReplacingMergeTree(_version)
PARTITION BY toYYYYMM(created_at)
ORDER BY (id);
```

### How Updates Work

**Initial INSERT:**
```sql
INSERT INTO analytics.users VALUES (1001, 'john_doe', 'john@example.com', '2025-01-15 10:30:00', 1, 0);
```

**After UPDATE (email changed):**
```sql
INSERT INTO analytics.users VALUES (1001, 'john_doe', 'john.doe@example.com', '2025-01-15 10:30:00', 2, 0);
```

**After DELETE:**
```sql
INSERT INTO analytics.users VALUES (1001, 'john_doe', 'john.doe@example.com', '2025-01-15 10:30:00', 3, 1);
```

**Querying Current State:**
```sql
-- Get latest version of each row (excluding deleted)
SELECT *
FROM analytics.users
FINAL
WHERE _is_deleted = 0;

-- Or use: SELECT * FROM (SELECT * FROM analytics.users WHERE _is_deleted = 0) FINAL
```

The `FINAL` keyword:
- Deduplicates rows based on `_version`
- Keeps only the row with highest `_version` per `id`
- Applied automatically during merges (background process)
- Can be forced in queries for real-time accuracy

## Performance Characteristics

### Phase A: Snapshot Performance

**Throughput:**
- MySQL SELECT: ~50,000-100,000 rows/sec (depends on table size)
- Kafka throughput: ~500 MB/sec (Redpanda can handle more)
- ClickHouse INSERT: ~100,000-500,000 rows/sec (batch inserts)

**Time Estimate for 21.7GB:**
- Small tables (< 10K rows): 1-5 seconds each
- Medium tables (10K-1M rows): 10-60 seconds each
- Large tables (> 1M rows): 2-10 minutes each
- **Total estimated time: 2-4 hours for all 450 tables**

**MySQL Load:**
- SELECT queries are read-only
- No locks (unless you use FLUSH TABLES WITH READ LOCK)
- Can run during business hours with minimal impact
- Monitor with: `SHOW PROCESSLIST;`

### Phase B: CDC Performance (with privileges)

**Latency:**
- Binlog event to Kafka: 50-200ms
- Kafka to ClickHouse: 50-200ms
- **Total end-to-end latency: 100-500ms**

**Throughput:**
- Can handle 10,000+ DML operations/second
- Limited by ClickHouse write capacity
- Batching improves performance

**MySQL Load:**
- Zero impact on OLTP queries (reads binlog only)
- No table locks
- No additional SELECT queries

## Resource Usage

### During Snapshot (Phase A)

**MySQL:**
- CPU: +5-10% (SELECT queries)
- Memory: Minimal (streaming results)
- Network: 20-50 Mbps (depends on data transfer rate)

**VPS (Redpanda/Kafka Connect/ClickHouse):**
- CPU: 20-40% across all services
- Memory: ~3-4GB total
- Disk I/O: High (ClickHouse writes)
- Network: 20-50 Mbps inbound

**Disk Space in ClickHouse:**
- Raw data: ~21.7GB
- After compression: ~5-8GB (3-4x compression typical)
- With versions/history: +20-30% over time

### During CDC (Phase B)

**MySQL:**
- CPU: <1% (binlog already generated for replication)
- Memory: Minimal
- Network: 1-5 Mbps (only changes, not full data)

**VPS:**
- CPU: 5-15% idle, spikes during write bursts
- Memory: ~2-3GB steady state
- Disk I/O: Moderate (incremental writes)
- Network: 1-5 Mbps

## Error Handling

### Debezium Connector Failure
- **Behavior**: Stores last binlog position in Kafka topic `clickhouse_connect_offsets`
- **Recovery**: Restarts from last committed position automatically
- **No data loss**: Guaranteed at-least-once delivery

### ClickHouse Sink Failure
- **Behavior**: Kafka retains messages (default 7 days retention)
- **Recovery**: Sink resumes from last committed offset
- **Duplicate handling**: ReplacingMergeTree deduplicates based on _version

### Network Interruption
- **Debezium**: Reconnects and resumes from binlog position
- **Kafka**: Messages buffered on disk
- **Sink**: Resumes consuming after reconnection
- **Result**: No data loss, possible duplicates (handled by ReplacingMergeTree)

## Monitoring Points

### Key Metrics to Watch

**Debezium (Kafka Connect):**
- Snapshot progress: `SELECT * FROM kafka_connect_status`
- Binlog position lag: How far behind MySQL
- Error count: Failed message processing

**Kafka (Redpanda Console):**
- Topic lag: Messages waiting to be consumed
- Throughput: Messages/sec
- Disk usage: Topic retention

**ClickHouse:**
- Row count: `SELECT count() FROM analytics.{table}`
- Merge performance: `SELECT * FROM system.merges`
- Query latency: `SELECT * FROM system.query_log`
- Disk usage: `SELECT * FROM system.parts`

### Comparison Queries

```sql
-- MySQL
SELECT COUNT(*), MAX(id), SUM(CHECKSUM(*)) FROM mulazamflatoddbet.users;

-- ClickHouse (equivalent)
SELECT COUNT(*), MAX(id), SUM(cityHash64(concat(
    toString(id), username, email
))) FROM analytics.users FINAL WHERE _is_deleted = 0;
```

## Summary: Privilege Requirements

| Operation | MySQL Privileges Required | You Have It? |
|-----------|---------------------------|--------------|
| **Initial Snapshot** | SELECT, SHOW DATABASES | ✅ Yes |
| Optional: Consistent snapshot | RELOAD (for FTWRL) | ⚠️ Unknown |
| **Real-Time CDC** | REPLICATION SLAVE | ❌ No (yet) |
| **Real-Time CDC** | REPLICATION CLIENT | ❌ No (yet) |
| Monitoring | SELECT on performance_schema | ⚠️ Unknown |

**Bottom Line:**
- ✅ We can do the full initial data copy NOW (21.7GB snapshot)
- ❌ We cannot enable real-time CDC until you get REPLICATION privileges
- 🎯 Recommendation: Start snapshot now, enable CDC later when ready


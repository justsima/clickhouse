# Complete Clean Restart Guide

**Purpose**: Start fresh with all fixes in place, ensuring everything works correctly from the beginning.

**What this does**: Cleans all connectors, Kafka topics, and ClickHouse data, then redeploys with the correct configuration.

---

## Why Clean Restart?

✅ **Ensures correct connector from the start**
✅ **No partial/corrupt data from previous attempt**
✅ **Clean verification of the entire pipeline**
✅ **Peace of mind that everything is working correctly**

---

## Complete Step-by-Step Process

### Phase 1: Pull Latest Code (1 minute)

```bash
cd /home/centos/clickhouse
git pull origin claude/analyze-codebase-01NDoXEfajaWqhbWYUTj5EZF
```

**What this gets:**
- ✅ Fixed deployment script (uses correct connector)
- ✅ Optimized ClickHouse sink configuration
- ✅ Cleanup script
- ✅ All documentation

---

### Phase 2: Complete Cleanup (2-3 minutes)

```bash
cd /home/centos/clickhouse/phase3/scripts
./00_cleanup_restart.sh
```

**What this cleans:**
- All Kafka Connect connectors (mysql-source, clickhouse-sink)
- All Kafka/Redpanda topics (the 144 partial topics)
- All ClickHouse data in analytics database
- Kafka Connect internal state

**Verification after cleanup:**
- Connectors: 0
- Kafka topics: 0 (with mysql prefix)
- ClickHouse tables: 0

---

### Phase 3: Recreate ClickHouse Schema (3-5 minutes)

```bash
cd /home/centos/clickhouse/phase3/scripts
./02_create_clickhouse_schema.sh
```

**Expected output:**
```
========================================
   ClickHouse Schema Creation
========================================

1. Testing ClickHouse Connection
✓ ClickHouse connection successful

2. Creating Analytics Database
✓ Analytics database ready

3. Creating Tables
ℹ Found 450 table definitions

Creating table 450/450: zynga_slots_wager
✓ Successfully created 450 tables

4. Verifying Schema
ℹ Tables in analytics database: 450

========================================
   Schema Creation Complete!
========================================
```

**What this creates:**
- 450 ClickHouse tables with correct schema
- Proper data types (Bool, Decimal64, DateTime64, LowCardinality)
- ReplacingMergeTree engine for CDC
- Proper ORDER BY and PARTITION BY clauses

---

### Phase 4: Deploy Connectors with Fix (5-10 minutes)

```bash
cd /home/centos/clickhouse/phase3/scripts
./03_deploy_connectors.sh
```

**Expected output:**
```
========================================
   Connector Deployment
========================================

1. Checking Kafka Connect Status
✓ Kafka Connect is running

2. Installing ClickHouse Kafka Connect Connector
ℹ Checking if ClickHouse Kafka Connect connector is installed...
Installing ClickHouse Kafka Connect connector...
✓ ClickHouse Kafka Connect connector installed (3 JAR files)
ℹ Restarting Kafka Connect to load connector...
✓ Kafka Connect restarted and ready

3. Verifying Available Connectors
ℹ Available connector plugins:
  - io.debezium.connector.mysql.MySqlConnector
  - com.clickhouse.kafka.connect.ClickHouseSinkConnector
✓ Debezium MySQL connector available
✓ ClickHouse Kafka Connect Sink connector available

4. Deploying Debezium MySQL Source Connector
✓ Debezium MySQL source connector deployed

5. Deploying ClickHouse Kafka Connect Sink Connector
✓ ClickHouse Kafka Connect sink connector deployed

6. Verifying Connector Status
✓ Debezium connector status: RUNNING
✓ ClickHouse sink connector status: RUNNING

========================================
   Deployment Summary
========================================

Connectors deployed:
  - Debezium MySQL Source: RUNNING
  - ClickHouse Kafka Connect Sink: RUNNING

✓ Snapshot has started!
```

**Key difference from before:**
- ❌ Before: `io.debezium.connector.jdbc.JdbcSinkConnector` (Hibernate/JDBC - failed)
- ✅ Now: `com.clickhouse.kafka.connect.ClickHouseSinkConnector` (ClickHouse native - works)

---

### Phase 5: Monitor Snapshot Progress (30-60 minutes)

**Option A: Automated monitoring script**
```bash
cd /home/centos/clickhouse/phase3/scripts
./04_monitor_snapshot.sh
```

**Option B: Manual monitoring**

**Watch Kafka topics being created:**
```bash
watch -n 10 'docker exec redpanda-clickhouse rpk topic list | grep -c mysql'
```
You should see the count increase: 0 → 50 → 100 → 150 → ... → 450

**Watch ClickHouse data flowing:**
```bash
watch -n 10 'docker exec clickhouse-server clickhouse-client \
  --password "ClickHouse_Secure_Pass_2024!" \
  --query="SELECT COUNT(*) as tables_with_data, SUM(total_rows) as total_rows
           FROM system.tables WHERE database = '\''analytics'\'' AND total_rows > 0"'
```

**Check specific table:**
```bash
watch -n 10 'docker exec clickhouse-server clickhouse-client \
  --password "ClickHouse_Secure_Pass_2024!" \
  --query="SELECT COUNT(*) FROM analytics.flatodd_member"'
```

---

### Phase 6: Verification (5 minutes)

After snapshot completes, verify everything:

**1. Check connector status (both should be RUNNING with 0 failures):**
```bash
curl -s http://localhost:8085/connectors/mysql-source-connector/status | jq '.connector.state, .tasks[].state'
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq '.connector.state, .tasks[].state'
```

Expected:
```json
"RUNNING"
"RUNNING"
"RUNNING"
"RUNNING"
"RUNNING"  // 4 tasks for sink
"RUNNING"
```

**2. Check Kafka topics (should be ~450):**
```bash
docker exec redpanda-clickhouse rpk topic list | grep -c mysql
```

Expected: `450` (or close to it)

**3. Check ClickHouse tables with data:**
```bash
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query="SELECT COUNT(*) as tables_with_data FROM system.tables
           WHERE database = 'analytics' AND total_rows > 0"
```

Expected: `450` (all tables have data)

**4. Check total row count:**
```bash
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query="SELECT SUM(total_rows) as total_rows FROM system.tables
           WHERE database = 'analytics'"
```

Expected: Large number (millions of rows)

**5. Verify CDC is working (test with a change in MySQL):**

Make a change in MySQL, then check if it appears in ClickHouse within seconds.

---

## Expected Timeline

| Phase | Duration | Status Indicator |
|-------|----------|------------------|
| Pull code | 1 min | Git output |
| Cleanup | 2-3 min | "Cleanup Complete!" |
| Create schema | 3-5 min | "450 tables created" |
| Deploy connectors | 5-10 min | "Both RUNNING" |
| Snapshot | 30-60 min | Kafka topics: 0→450 |
| Verification | 5 min | All checks pass |
| **Total** | **~50-80 min** | Full pipeline working |

---

## What to Watch For (Success Indicators)

✅ **During deployment:**
- Connector class shows: `com.clickhouse.kafka.connect.ClickHouseSinkConnector`
- Both connectors show status: `RUNNING`
- No `FAILED` tasks

✅ **During snapshot:**
- Kafka topics increasing: watch count go 0→450
- ClickHouse rows increasing: watch total_rows grow
- No errors in logs: `docker logs kafka-connect-clickhouse | grep ERROR`

✅ **After completion:**
- 450 Kafka topics exist
- 450 ClickHouse tables have data
- Connectors still RUNNING
- CDC working (changes replicate in real-time)

---

## Troubleshooting

### Issue: Connector installation fails

**Check:**
```bash
docker logs kafka-connect-clickhouse | grep -i "clickhouse-kafka"
```

**Solution:**
The script has fallback installation from Maven Central. If both fail, manually install:
```bash
docker exec kafka-connect-clickhouse bash -c "
  mkdir -p /kafka/connect/clickhouse-kafka &&
  curl -L -o /kafka/connect/clickhouse-kafka/clickhouse-kafka-connect.jar \
    'https://repo1.maven.org/maven2/com/clickhouse/clickhouse-kafka-connect/1.0.13/clickhouse-kafka-connect-1.0.13-all.jar'
"
docker restart kafka-connect-clickhouse
```

### Issue: Sink connector tasks FAILED

**Check:**
```bash
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq '.tasks[0].trace'
docker logs kafka-connect-clickhouse 2>&1 | grep -A 10 ERROR | tail -30
```

**Common causes:**
1. ClickHouse connection issue → Check ClickHouse is running
2. Table doesn't exist → Ensure step 3 (schema creation) completed successfully
3. Type mismatch → Check logs for specific error

### Issue: Snapshot very slow

**Check MySQL connection:**
```bash
docker exec kafka-connect-clickhouse curl -s http://localhost:8083/connectors/mysql-source-connector/status | jq
```

**Speed it up (if safe):**
Edit `debezium-mysql-source.json` and increase:
```json
"snapshot.fetch.size": "20480"  // was 10240
```

Redeploy source connector.

---

## Summary

**What changed:**
- ❌ Old: Wrong connector (Hibernate/JDBC)
- ✅ New: Correct connector (ClickHouse native)

**Why clean restart:**
- Ensures no leftover data from broken connector
- Verifies entire pipeline works correctly
- Peace of mind

**Expected result:**
- Full CDC pipeline working
- ~21.7GB data in ClickHouse
- Real-time replication active
- All 450 tables synced

---

## Quick Reference Commands

```bash
# Full restart sequence:
cd /home/centos/clickhouse
git pull origin claude/analyze-codebase-01NDoXEfajaWqhbWYUTj5EZF
cd phase3/scripts
./00_cleanup_restart.sh          # ~2 min
./02_create_clickhouse_schema.sh # ~4 min
./03_deploy_connectors.sh        # ~7 min
./04_monitor_snapshot.sh         # ~45 min (monitoring)

# Verification:
curl -s http://localhost:8085/connectors | jq
docker exec redpanda-clickhouse rpk topic list | grep -c mysql
docker exec clickhouse-server clickhouse-client --password 'ClickHouse_Secure_Pass_2024!' \
  --query="SELECT COUNT(*) FROM system.tables WHERE database='analytics' AND total_rows>0"
```

**Ready to start? Run the Phase 1 command above!**

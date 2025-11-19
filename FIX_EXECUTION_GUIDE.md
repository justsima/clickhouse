# Fix Execution Guide - ClickHouse CDC Pipeline

**Issue**: Data not flowing from Kafka to ClickHouse
**Root Cause**: Deployment script using wrong connector configuration file
**Status**: Fix implemented and ready to deploy

---

## Quick Summary

The deployment script was using `clickhouse-jdbc-sink.json` (Hibernate-based, incompatible) instead of `clickhouse-sink.json` (ClickHouse native connector, correct).

**Fix**: Simple configuration file swap + redeploy
**Time**: 5-10 minutes
**Risk**: None - data is safely in Kafka topics

---

## Step-by-Step Execution

### Pre-Check: Verify Current State

```bash
# Check current connector status
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq '.connector.state, .tasks[].state'

# Expected: "RUNNING" connector but "FAILED" tasks
```

### Step 1: Delete Broken Connector

```bash
curl -X DELETE http://localhost:8085/connectors/clickhouse-sink-connector
```

**Expected output**: Empty response (connector deleted)

---

### Step 2: Pull Fixed Code

```bash
cd /home/centos/clickhouse
git pull origin claude/analyze-codebase-01NDoXEfajaWqhbWYUTj5EZF
```

**Expected output**:
```
Updating <hash>...<hash>
Fast-forward
 DIAGNOSTIC_REPORT.md                    | 234 +++++++
 FIX_EXECUTION_GUIDE.md                  | 180 +++++
 phase3/scripts/03_deploy_connectors.sh  | 150 changed
 phase3/configs/clickhouse-sink.json     | 6 changed
```

---

### Step 3: Redeploy Connectors with Fix

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
---------------------------------
✓ Kafka Connect is running

2. Installing ClickHouse Kafka Connect Connector
-------------------------------------------------
ℹ Checking if ClickHouse Kafka Connect connector is installed...
Installing ClickHouse Kafka Connect connector...
  [Download progress...]
✓ ClickHouse Kafka Connect connector installed (X JAR files)
ℹ Restarting Kafka Connect to load connector...
✓ Kafka Connect restarted and ready

3. Verifying Available Connectors
-----------------------------------
ℹ Available connector plugins:
  - io.debezium.connector.mysql.MySqlConnector
  - com.clickhouse.kafka.connect.ClickHouseSinkConnector
✓ Debezium MySQL connector available
✓ ClickHouse Kafka Connect Sink connector available

4. Deploying Debezium MySQL Source Connector
---------------------------------------------
✓ Debezium MySQL source connector deployed

5. Deploying ClickHouse Kafka Connect Sink Connector
-----------------------------------------------------
✓ ClickHouse Kafka Connect sink connector deployed

6. Verifying Connector Status
------------------------------
ℹ Checking Debezium MySQL source connector...
✓ Debezium connector status: RUNNING
ℹ Checking ClickHouse Kafka Connect sink connector...
✓ ClickHouse sink connector status: RUNNING

7. Listing Active Connectors
-----------------------------
[
  "mysql-source-connector",
  "clickhouse-sink-connector"
]

========================================
   Deployment Summary
========================================

Connectors deployed:
  - Debezium MySQL Source: RUNNING
  - ClickHouse Kafka Connect Sink: RUNNING

✓ Snapshot has started!

Next step: Run 04_monitor_snapshot.sh to track progress
```

---

### Step 4: Verify Data Starts Flowing

**Wait 30 seconds**, then check:

```bash
# Check ClickHouse tables for data
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query="SELECT database, name, total_rows
           FROM system.tables
           WHERE database = 'analytics'
           ORDER BY total_rows DESC
           LIMIT 20"
```

**Expected output:**
```
┌─database──┬─name─────────────┬─total_rows─┐
│ analytics │ flatodd_bet      │       1523 │
│ analytics │ flatodd_member   │        874 │
│ analytics │ flatodd_game     │        245 │
│ analytics │ ...              │        ... │
└───────────┴──────────────────┴────────────┘
```

**If you see rows > 0**: ✅ SUCCESS! Data is flowing.

---

### Step 5: Monitor Snapshot Progress

```bash
cd /home/centos/clickhouse/phase3/scripts
./04_monitor_snapshot.sh
```

**Expected output:**
```
========================================
   CDC Snapshot Monitor
========================================

Snapshot Status: IN PROGRESS

Tables with data:
┌─table────────────────┬─rows───────┐
│ flatodd_bet          │     15,234 │
│ flatodd_member       │      8,742 │
│ flatodd_transaction  │      5,123 │
│ ...                  │        ... │
└──────────────────────┴────────────┘

Refreshing every 10 seconds...
```

---

## Verification Checklist

After running all steps, verify:

- [ ] Connector status shows RUNNING (not FAILED)
  ```bash
  curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq '.connector.state'
  # Should output: "RUNNING"
  ```

- [ ] Tasks are RUNNING (not FAILED)
  ```bash
  curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq '.tasks[].state'
  # All tasks should output: "RUNNING"
  ```

- [ ] ClickHouse tables show increasing row counts
  ```bash
  docker exec clickhouse-server clickhouse-client \
    --password 'ClickHouse_Secure_Pass_2024!' \
    --query="SELECT COUNT(*) FROM analytics.flatodd_member"
  # Run multiple times - number should increase
  ```

- [ ] No errors in connector logs
  ```bash
  docker logs kafka-connect-clickhouse 2>&1 | grep -i error | tail -20
  # Should see no recent errors
  ```

---

## Troubleshooting

### Issue: Connector stays in RUNNING but tasks are FAILED

**Check:**
```bash
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq '.tasks'
```

**Solution:**
```bash
# Check detailed logs
docker logs kafka-connect-clickhouse | tail -100

# Common issues:
# 1. ClickHouse connection refused → Check ClickHouse is running
# 2. Table not found → Check tables created in Step 2 (02_create_clickhouse_schema.sh)
# 3. Permission denied → Check ClickHouse password in .env
```

### Issue: "Connector not found" error

**Means**: ClickHouse Kafka Connect connector JAR not loaded

**Solution:**
```bash
# Manually verify connector is installed
docker exec kafka-connect-clickhouse ls -l /kafka/connect/clickhouse-kafka/

# If empty, manually install:
docker exec kafka-connect-clickhouse bash -c "
  mkdir -p /kafka/connect/clickhouse-kafka &&
  cd /kafka/connect/clickhouse-kafka &&
  curl -L -o clickhouse-kafka-connect.jar \
    'https://repo1.maven.org/maven2/com/clickhouse/clickhouse-kafka-connect/1.0.13/clickhouse-kafka-connect-1.0.13-all.jar'
"

# Restart Kafka Connect
docker restart kafka-connect-clickhouse

# Wait 30 seconds, then redeploy
./03_deploy_connectors.sh
```

### Issue: Tables still show 0 rows after 2+ minutes

**Check:**
```bash
# 1. Verify Kafka topics have data
docker exec redpanda-clickhouse rpk topic consume mysql.mulazamflatoddbet.flatodd_member --num 1

# 2. Check connector is consuming
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq '.tasks[0].id'

# 3. Check ClickHouse logs
docker logs clickhouse-server | tail -50
```

---

## What Changed (Technical Details)

### File: `phase3/scripts/03_deploy_connectors.sh`

**Line 210-211 (Before):**
```bash
if [ -f "$CONFIG_DIR/clickhouse-jdbc-sink.json" ]; then
    CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-jdbc-sink.json")
```

**Line 210-211 (After):**
```bash
if [ -f "$CONFIG_DIR/clickhouse-sink.json" ]; then
    CLICKHOUSE_CONFIG=$(cat "$CONFIG_DIR/clickhouse-sink.json")
```

**Section 2: Connector Installation (Lines 82-150)**
- Changed from: Download ClickHouse JDBC driver JAR
- Changed to: Download ClickHouse Kafka Connect connector JAR
- Updated URL: GitHub releases of `clickhouse-kafka-connect`

**Section 3: Connector Verification (Lines 186-197)**
- Changed from: Check for `io.debezium.connector.jdbc.JdbcSinkConnector`
- Changed to: Check for `com.clickhouse.kafka.connect.ClickHouseSinkConnector`

### File: `phase3/configs/clickhouse-sink.json`

**Key changes:**
```diff
- "port": "${CLICKHOUSE_PORT}",          # Was 8123 (HTTP)
+ "port": "${CLICKHOUSE_NATIVE_PORT}",   # Now 9000 (native protocol)

- "bufferCount": "50000",
+ "bufferCount": "10000",                 # Faster flushes for monitoring

- "flushInterval": "30",
+ "flushInterval": "10",                  # More frequent writes

- "errors.retry.timeout": "60",
+ "errors.retry.timeout": "300",          # Longer retry window

+ "ignoreUnknownColumns": "true",        # Handle extra Debezium fields
+ "timeoutSeconds": "30"                 # Connection timeout
```

---

## Success Criteria

You'll know it's working when:

1. ✅ Connector status API shows RUNNING with 0 FAILED tasks
2. ✅ ClickHouse tables show rows > 0 and increasing
3. ✅ Redpanda Console shows messages being consumed from topics
4. ✅ No errors in `docker logs kafka-connect-clickhouse`
5. ✅ Snapshot completes (monitor with `04_monitor_snapshot.sh`)

**Expected timeline:**
- Data starts appearing: 30-60 seconds after deployment
- Snapshot completes: 10-30 minutes (depending on data size)
- CDC active: Immediately after snapshot completes

---

## Need Help?

**Check logs:**
```bash
# Kafka Connect logs
docker logs kafka-connect-clickhouse | tail -100

# ClickHouse logs
docker logs clickhouse-server | tail -100

# Connector status
curl -s http://localhost:8085/connectors/clickhouse-sink-connector/status | jq
```

**Useful debugging commands:**
```bash
# List all connectors
curl -s http://localhost:8085/connectors

# Check available plugins
curl -s http://localhost:8085/connector-plugins | jq

# Check Kafka topics
docker exec redpanda-clickhouse rpk topic list | grep mysql

# Check ClickHouse connection
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query "SELECT 1"
```

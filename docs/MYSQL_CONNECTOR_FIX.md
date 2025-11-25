# MySQL Source Connector - 0 Tasks Issue Fix Guide

## Problem

The MySQL source connector shows status `RUNNING` but has **0/0 tasks** instead of **1/1 task**.

**Symptoms:**
- Connector deployed successfully
- Connector shows as RUNNING
- But NO tasks are created
- No `mysql.*` topics appear in Redpanda
- ClickHouse tables remain empty

---

## Root Cause Analysis

When a Debezium MySQL connector shows RUNNING but creates 0 tasks, it typically means one of these issues:

1. **MySQL binlog not enabled** (most common)
2. **Insufficient MySQL user permissions**
3. **MySQL not reachable from Kafka Connect container**
4. **Database doesn't exist or is empty**
5. **SSL/TLS configuration mismatch**

---

## Diagnostic Steps

### Step 1: Run Diagnostic Script

```bash
cd /home/centos/clickhouse/phase3/scripts
./diagnose_mysql_connector.sh
```

This will automatically check:
- Connector status and task count
- MySQL connectivity from container
- Connector configuration
- Kafka Connect logs for errors
- Plugin availability

### Step 2: Manual Checks

**Check connector status:**
```bash
curl -s http://localhost:8085/connectors/mysql-source-connector/status | python3 -m json.tool
```

Look for `"tasks": []` - if empty array, tasks aren't being created.

**Check Kafka Connect logs:**
```bash
docker logs kafka-connect-clickhouse 2>&1 | grep -i "mysql-source" | tail -50
```

Look for errors like:
- "Failed to create tasks"
- "Could not connect to MySQL"
- "Access denied"
- "Binlog not enabled"

---

## Most Common Cause: MySQL Binlog Not Enabled

Debezium **requires** MySQL binary logging (binlog) to capture changes.

### Check if Binlog is Enabled

Connect to your MySQL server and run:

```sql
SHOW VARIABLES LIKE 'log_bin';
```

**Expected output:**
```
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| log_bin       | ON    |
+---------------+-------+
```

If `log_bin = OFF`, Debezium cannot work.

### Check Binlog Format

```sql
SHOW VARIABLES LIKE 'binlog_format';
```

**Expected output:**
```
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| binlog_format | ROW   |
+---------------+-------+
```

Debezium works best with `ROW` format.

---

## Second Most Common Cause: MySQL User Permissions

The MySQL user configured in `.env` needs specific replication privileges.

### Check Current Permissions

```sql
SHOW GRANTS FOR 'mulasport'@'%';
```

### Required Permissions

The user MUST have:
- `SELECT` - Read table data
- `RELOAD` - Flush tables
- `SHOW DATABASES` - List databases
- `REPLICATION SLAVE` - Read binlog
- `REPLICATION CLIENT` - Monitor replication

### Grant Permissions (if missing)

Ask your MySQL DBA or run (if you have admin access):

```sql
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT
ON *.*
TO 'mulasport'@'%';

FLUSH PRIVILEGES;
```

---

## Third Cause: Network Connectivity

Test if Kafka Connect container can reach MySQL:

```bash
docker exec kafka-connect-clickhouse bash -c "
  timeout 5 bash -c '</dev/tcp/mulasport-db-mysql-fra1-89664-do-user-7185962-0.b.db.ondigitalocean.com/25060' && echo 'Connected' || echo 'Failed'
"
```

If this fails:
- Check firewall rules
- Verify MySQL allows connections from VPS IP
- Check if MySQL host/port are correct in `.env`

---

## Fix Procedure

### Option 1: If Binlog is Disabled (Most Likely)

**This requires MySQL admin access to enable binlog.**

1. Edit MySQL configuration (my.cnf or my.ini):
```ini
[mysqld]
log-bin=mysql-bin
binlog-format=ROW
server-id=1
```

2. Restart MySQL server

3. Verify binlog is now enabled:
```sql
SHOW VARIABLES LIKE 'log_bin';
```

4. Redeploy connector:
```bash
cd /home/centos/clickhouse/phase3/scripts
curl -X DELETE http://localhost:8085/connectors/mysql-source-connector
./03_deploy_connectors.sh
```

### Option 2: If Permissions are Missing

1. Grant required permissions (see above)

2. Restart connector:
```bash
curl -X POST http://localhost:8085/connectors/mysql-source-connector/restart
```

3. Wait 10 seconds and check:
```bash
curl -s http://localhost:8085/connectors/mysql-source-connector/status | python3 -m json.tool
```

### Option 3: If Configuration Issue

1. Delete connector completely:
```bash
curl -X DELETE http://localhost:8085/connectors/mysql-source-connector
```

2. Verify deletion:
```bash
curl -s http://localhost:8085/connectors
```

Should not include `mysql-source-connector`.

3. Redeploy:
```bash
cd /home/centos/clickhouse/phase3/scripts
./03_deploy_connectors.sh
```

4. Immediately check task creation:
```bash
sleep 5
curl -s http://localhost:8085/connectors/mysql-source-connector/status | python3 -m json.tool
```

Look for `"tasks": [{"id": 0, "state": "RUNNING", ...}]`

---

## Verification After Fix

### 1. Check Tasks Created

```bash
curl -s http://localhost:8085/connectors/mysql-source-connector/status | python3 -m json.tool
```

**Expected output:**
```json
{
  "name": "mysql-source-connector",
  "connector": {
    "state": "RUNNING",
    "worker_id": "..."
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING",
      "worker_id": "..."
    }
  ]
}
```

**Key check:** `"tasks"` array should have 1 element with `"state": "RUNNING"`

### 2. Watch for Kafka Topics Being Created

```bash
watch -n 5 'docker exec redpanda-clickhouse rpk topic list | grep "^mysql\." | wc -l'
```

You should see the count increasing: 0 → 5 → 10 → 20 → ... → 450

### 3. Check Specific Topic

Once topics start appearing:

```bash
docker exec redpanda-clickhouse rpk topic list | grep "^mysql\." | head -10
```

Should show topics like:
```
mysql.mulazamflatoddbet.table_name_1
mysql.mulazamflatoddbet.table_name_2
...
```

### 4. Monitor Snapshot Progress

```bash
cd /home/centos/clickhouse/phase3/scripts
./04_monitor_snapshot.sh
```

---

## If All Else Fails

### Get Detailed Error Information

1. **Check full connector configuration:**
```bash
curl -s http://localhost:8085/connectors/mysql-source-connector | python3 -m json.tool
```

2. **Get last 200 lines of Kafka Connect logs:**
```bash
docker logs kafka-connect-clickhouse 2>&1 | tail -200 > /tmp/kafka-connect-logs.txt
cat /tmp/kafka-connect-logs.txt
```

3. **Check if connector plugin is actually loaded:**
```bash
curl -s http://localhost:8085/connector-plugins | python3 -m json.tool | grep -A 5 "MySql"
```

### Nuclear Option: Complete Restart

If nothing works, restart Kafka Connect completely:

```bash
# Stop all connectors
curl -X DELETE http://localhost:8085/connectors/mysql-source-connector
curl -X DELETE http://localhost:8085/connectors/clickhouse-sink-connector

# Restart Kafka Connect
docker restart kafka-connect-clickhouse

# Wait for it to be ready
sleep 30

# Verify it's running
curl -s http://localhost:8085/ | python3 -m json.tool

# Redeploy connectors
cd /home/centos/clickhouse/phase3/scripts
./03_deploy_connectors.sh
```

---

## About the 12.8 GiB in clickhouse-dlq

The dead letter queue (DLQ) topic `clickhouse-dlq` contains 12.8 GiB of data.

**This is from previous failed attempts.**

The ClickHouse sink connector writes messages to DLQ when:
- Target table doesn't exist
- Data type mismatch
- ClickHouse connection fails
- Malformed messages

**Since you ran the cleanup script (`00_cleanup_restart.sh`), the DLQ should have been cleaned.**

To manually clean it:

```bash
docker exec redpanda-clickhouse rpk topic delete clickhouse-dlq
```

After fixing the MySQL source connector and getting data flowing, the DLQ should remain empty or very small.

---

## Expected Timeline After Fix

| Time | What Should Happen |
|------|-------------------|
| 0 min | Deploy fixed connector |
| +5 sec | Tasks created (1/1) |
| +30 sec | First mysql.* topics appear |
| +2 min | ~50 topics created |
| +5 min | ~100 topics created |
| +30 min | All 450 topics created |
| +60 min | Snapshot complete, data in ClickHouse |

---

## Quick Reference Commands

```bash
# Check if tasks are created
curl -s http://localhost:8085/connectors/mysql-source-connector/status | grep -o '"tasks":\[.*\]'

# Count mysql topics
docker exec redpanda-clickhouse rpk topic list | grep -c "^mysql\."

# Watch topics being created
watch -n 5 'docker exec redpanda-clickhouse rpk topic list | grep -c "^mysql\."'

# Check ClickHouse data
docker exec clickhouse-server clickhouse-client \
  --password 'ClickHouse_Secure_Pass_2024!' \
  --query="SELECT COUNT(*) FROM system.tables WHERE database='analytics' AND total_rows > 0"

# Restart connector
curl -X POST http://localhost:8085/connectors/mysql-source-connector/restart

# Delete and redeploy
curl -X DELETE http://localhost:8085/connectors/mysql-source-connector
cd /home/centos/clickhouse/phase3/scripts && ./03_deploy_connectors.sh
```

---

## Next Steps

Once you identify the root cause (likely binlog or permissions):

1. Fix the root cause (enable binlog or grant permissions)
2. Delete and redeploy the connector
3. Verify tasks are created (1/1)
4. Watch topics being created
5. Monitor snapshot progress
6. Verify data in ClickHouse

**Run the diagnostic script first to identify the exact issue!**

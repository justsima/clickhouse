# Troubleshooting Guide

## Quick Diagnostic Commands

```bash
# Check all container statuses
docker ps -a

# Check connector health
./phase4/scripts/03_health_check.sh

# Check connector detailed status
./phase4/scripts/04_connector_status.sh

# Check CDC lag
./phase4/scripts/01_monitor_cdc_lag.sh

# View connector logs
docker logs kafka-connect-clickhouse --tail 100 -f

# View ClickHouse logs
docker logs clickhouse --tail 100 -f

# View Redpanda logs
docker logs redpanda --tail 100 -f
```

---

## Common Issues and Solutions

### 1. Debezium Connector Not Starting

**Symptoms**:
- Connector status shows `FAILED` or `UNASSIGNED`
- Error in connector logs

**Common Causes & Solutions**:

#### A. MySQL Connection Failed

**Error**:
```
Unable to connect to MySQL database
```

**Solution**:
```bash
# Test MySQL connection
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1"

# Check credentials in .env file
cat /home/user/clickhouse/phase3/configs/.env

# Verify network connectivity
ping $MYSQL_HOST
telnet $MYSQL_HOST $MYSQL_PORT
```

#### B. Missing Replication Privileges

**Error**:
```
Access denied; you need (at least one of) the REPLICATION SLAVE privilege(s)
```

**Solution**:
```sql
-- Run in MySQL as admin
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'mulazamuser'@'%';
FLUSH PRIVILEGES;

-- Verify privileges
SHOW GRANTS FOR 'mulazamuser'@'%';
```

#### C. Binlog Not Enabled

**Error**:
```
The MySQL server is not configured to use a row-level binlog
```

**Solution**:
```sql
-- Check binlog settings
SHOW VARIABLES LIKE 'binlog_format';
SHOW VARIABLES LIKE 'log_bin';

-- Should show:
-- binlog_format: ROW
-- log_bin: ON

-- If not, contact database administrator to enable binlog
```

#### D. Invalid Server ID

**Error**:
```
Server ID already in use
```

**Solution**:
```bash
# Change server ID in connector config
# Edit /home/user/clickhouse/phase3/configs/debezium-mysql-source.json
# Change "database.server.id" to a unique value (e.g., 184055)

# Redeploy connector
./phase3/scripts/03_deploy_connectors.sh
```

---

### 2. ClickHouse Sink Connector Issues

#### A. Connector Not Deploying

**Symptoms**:
- Sink connector shows as `NOT_FOUND`
- ClickHouse connector plugin not loaded

**Solution**:
```bash
# Check if ClickHouse connector plugin is installed
curl -s http://localhost:8085/connector-plugins | grep -i clickhouse

# If not found, manually install
docker exec kafka-connect-clickhouse bash -c "
cd /tmp &&
curl -L -o clickhouse-kafka-connect.tar.gz \
    https://github.com/ClickHouse/clickhouse-kafka-connect/releases/download/v1.0.0/clickhouse-kafka-connect-v1.0.0.tar.gz &&
mkdir -p /kafka/connect/clickhouse-connector &&
tar -xzf clickhouse-kafka-connect.tar.gz -C /kafka/connect/clickhouse-connector
"

# Restart Kafka Connect
docker restart kafka-connect-clickhouse

# Wait 30 seconds and redeploy
sleep 30
./phase3/scripts/03_deploy_connectors.sh
```

#### B. Sink Connector Failing

**Error**:
```
Failed to write to ClickHouse
```

**Solution**:
```bash
# Test ClickHouse connection
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT 1"

# Check ClickHouse is running
docker ps | grep clickhouse

# Check ClickHouse logs
docker logs clickhouse --tail 100

# Verify table exists
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SHOW TABLES FROM analytics"
```

---

### 3. High Replication Lag

**Symptoms**:
- Data in ClickHouse is more than 5 minutes old
- Monitoring shows high lag values

**Causes & Solutions**:

#### A. Kafka Connect Overloaded

**Solution**:
```bash
# Increase connector tasks
curl -X PUT http://localhost:8085/connectors/mysql-source-connector/config \
    -H "Content-Type: application/json" \
    -d '{"tasks.max": "4"}'

# Restart connector
curl -X POST http://localhost:8085/connectors/mysql-source-connector/restart
```

#### B. ClickHouse Write Performance

**Solution**:
```bash
# Increase sink batch size
curl -X PUT http://localhost:8085/connectors/clickhouse-sink-connector/config \
    -H "Content-Type: application/json" \
    -d '{"batch.size": "100000"}'

# Check ClickHouse performance
docker stats clickhouse
```

#### C. Network Issues

**Solution**:
```bash
# Check network latency to MySQL
ping -c 10 $MYSQL_HOST

# Check throughput
iperf3 -c $MYSQL_HOST -p 5201  # If iperf3 server is running

# Check for packet loss
mtr -c 100 $MYSQL_HOST
```

---

### 4. Disk Space Issues

**Symptoms**:
- Services crashing
- Errors about disk space
- Monitoring shows > 90% disk usage

**Solution**:
```bash
# Check disk usage
df -h

# Find largest directories
du -sh /var/lib/docker/* | sort -h

# Clean up old Kafka topics
docker exec redpanda rpk topic delete <old-topic-name>

# Optimize ClickHouse tables (remove old data/versions)
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "OPTIMIZE TABLE analytics.<table_name> FINAL"

# Clean up Docker
docker system prune -a --volumes

# If critical, increase disk size (VPS provider)
```

---

### 5. Schema Mismatch Errors

**Symptoms**:
- Sink connector failing with schema errors
- New columns in MySQL not appearing in ClickHouse

**Solution**:

#### A. Add Missing Column to ClickHouse

```bash
# Identify missing column from error logs
docker logs kafka-connect-clickhouse --tail 100

# Add column to ClickHouse table
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "ALTER TABLE analytics.<table_name> ADD COLUMN <column_name> <type>"

# Restart sink connector
curl -X POST http://localhost:8085/connectors/clickhouse-sink-connector/restart
```

#### B. Type Mismatch

```bash
# If type mismatch, may need to recreate table
# 1. Rename old table
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "RENAME TABLE analytics.<table> TO analytics.<table>_old"

# 2. Recreate with correct schema
./phase3/scripts/02_create_clickhouse_schema.sh

# 3. Restart connector
curl -X POST http://localhost:8085/connectors/clickhouse-sink-connector/restart
```

---

### 6. Connector Stuck or Not Processing

**Symptoms**:
- Connector status is `RUNNING` but no data flowing
- Task stuck in `PAUSED` state

**Solution**:
```bash
# 1. Check connector tasks
curl http://localhost:8085/connectors/mysql-source-connector/tasks/0/status

# 2. Restart specific task
curl -X POST http://localhost:8085/connectors/mysql-source-connector/tasks/0/restart

# 3. If still stuck, restart entire connector
curl -X POST http://localhost:8085/connectors/mysql-source-connector/restart

# 4. If still stuck, delete and redeploy
curl -X DELETE http://localhost:8085/connectors/mysql-source-connector
sleep 5
./phase3/scripts/03_deploy_connectors.sh

# 5. Last resort: restart Kafka Connect
docker restart kafka-connect-clickhouse
```

---

### 7. Data Not Appearing in ClickHouse

**Symptoms**:
- Debezium is running and capturing changes
- Kafka topics have data
- But ClickHouse tables are empty or stale

**Diagnosis**:
```bash
# 1. Check if Kafka topics have data
docker exec redpanda rpk topic consume mysql.mulazamflatoddbet.users --num 10

# 2. Check sink connector status
curl http://localhost:8085/connectors/clickhouse-sink-connector/status

# 3. Check ClickHouse table exists
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SHOW TABLES FROM analytics"

# 4. Check for errors in sink connector
docker logs kafka-connect-clickhouse | grep -i error
```

**Solution**:
- If topics have data but ClickHouse doesn't: sink connector issue
- If topics are empty: Debezium source connector issue
- Check specific error messages in logs

---

### 8. Performance Issues

#### A. Slow ClickHouse Queries

**Solution**:
```sql
-- Add indexes (ORDER BY)
ALTER TABLE analytics.<table>
MODIFY ORDER BY (primary_key_col, frequently_filtered_col);

-- Create materialized views
CREATE MATERIALIZED VIEW analytics.<table>_daily_mv
ENGINE = SummingMergeTree()
ORDER BY (date, key_col)
AS SELECT
    toDate(_extracted_at) as date,
    key_col,
    sum(value_col) as total
FROM analytics.<table>
GROUP BY date, key_col;

-- Enable query cache (in config.xml)
<query_cache>
    <max_size_in_bytes>1073741824</max_size_in_bytes>
</query_cache>
```

#### B. High CPU Usage

**Solution**:
```bash
# Check which service is using CPU
docker stats

# If ClickHouse:
# - Add more resources
# - Optimize queries
# - Use materialized views

# If Kafka Connect:
# - Reduce batch sizes
# - Reduce number of tasks
# - Add more memory
```

---

### 9. Authentication Issues

**Symptoms**:
- `Access denied` errors
- `Authentication failed` messages

**Solution**:
```bash
# MySQL authentication
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1"

# ClickHouse authentication
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT 1"

# Verify credentials in .env
cat /home/user/clickhouse/phase3/configs/.env

# Reset ClickHouse password if needed
docker exec clickhouse clickhouse-client --query="ALTER USER default IDENTIFIED BY 'NewPassword'"
```

---

### 10. Container Crashes or Restarts

**Symptoms**:
- Containers constantly restarting
- `docker ps` shows status like "Restarting (1) 5 seconds ago"

**Solution**:
```bash
# Check container logs
docker logs <container-name> --tail 100

# Check system resources
free -h
df -h
docker stats

# Check for OOM kills
dmesg | grep -i "out of memory"

# Increase container memory limits in docker-compose.yml
mem_limit: 8g

# Restart with updated limits
cd /home/user/clickhouse/phase2
docker-compose down
docker-compose up -d
```

---

## Debugging Tools

### 1. Check Kafka Topics

```bash
# List all topics
docker exec redpanda rpk topic list

# Consume from topic
docker exec redpanda rpk topic consume mysql.mulazamflatoddbet.<table> --num 10

# Topic details
docker exec redpanda rpk topic describe mysql.mulazamflatoddbet.<table>
```

### 2. Query ClickHouse Directly

```bash
# Via curl
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT * FROM analytics.<table> LIMIT 10"

# Via CLI
docker exec -it clickhouse clickhouse-client \
    --user=$CLICKHOUSE_USER \
    --password=$CLICKHOUSE_PASSWORD \
    --database=analytics
```

### 3. Connector API Commands

```bash
# List all connectors
curl http://localhost:8085/connectors

# Get connector status
curl http://localhost:8085/connectors/<name>/status | jq

# Get connector config
curl http://localhost:8085/connectors/<name> | jq

# Restart connector
curl -X POST http://localhost:8085/connectors/<name>/restart

# Delete connector
curl -X DELETE http://localhost:8085/connectors/<name>

# Pause connector
curl -X PUT http://localhost:8085/connectors/<name>/pause

# Resume connector
curl -X PUT http://localhost:8085/connectors/<name>/resume
```

---

## Getting Additional Help

1. **Check logs**:
   ```bash
   docker logs kafka-connect-clickhouse --tail 200
   docker logs clickhouse --tail 200
   docker logs redpanda --tail 200
   ```

2. **Run health check**:
   ```bash
   ./phase4/scripts/03_health_check.sh
   ```

3. **Review documentation**:
   - Phase 3 README: `/home/user/clickhouse/phase3/README.md`
   - Architecture docs: `/home/user/clickhouse/phase1/docs/ARCHITECTURE.md`

4. **Check system resources**:
   ```bash
   df -h  # Disk
   free -h  # Memory
   top  # CPU
   docker stats  # Container resources
   ```

---

**Updated**: 2025-11-18

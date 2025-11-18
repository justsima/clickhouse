# Operational Runbook

## Daily Operations

### Morning Checklist

```bash
# 1. Check overall system health
./phase4/scripts/03_health_check.sh

# 2. Monitor CDC lag
./phase4/scripts/01_monitor_cdc_lag.sh

# 3. Check connector status
./phase4/scripts/04_connector_status.sh

# 4. Validate data quality (weekly, but good to spot check)
./phase4/scripts/02_validate_data_quality.sh
```

### Expected Results

- ✅ All containers: `Up` status
- ✅ All connectors: `RUNNING` status
- ✅ Replication lag: < 1 minute
- ✅ Disk usage: < 80%
- ✅ Memory usage: < 80%

---

## Common Operational Tasks

### 1. Restarting a Connector

**When**: Connector is stuck, failed, or after configuration changes

```bash
# Restart Debezium source connector
curl -X POST http://localhost:8085/connectors/mysql-source-connector/restart

# Restart ClickHouse sink connector
curl -X POST http://localhost:8085/connectors/clickhouse-sink-connector/restart

# Wait 10 seconds and verify
sleep 10
curl http://localhost:8085/connectors/mysql-source-connector/status | jq
```

### 2. Restarting a Service

**When**: Service is unhealthy or after configuration changes

```bash
cd /home/user/clickhouse/phase2

# Restart specific service
docker-compose restart clickhouse
docker-compose restart redpanda
docker-compose restart kafka-connect-clickhouse

# Or restart all services
docker-compose restart

# Verify services are up
docker-compose ps
```

### 3. Adding a New Table to Replication

**When**: New table created in MySQL that needs to be replicated

```bash
# 1. Create table in ClickHouse
# First, get MySQL DDL
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD \
    -D $MYSQL_DATABASE -e "SHOW CREATE TABLE new_table"

# 2. Convert to ClickHouse DDL (manual conversion)
# Create file: /tmp/new_table.sql
cat > /tmp/new_table.sql << 'EOF'
CREATE TABLE IF NOT EXISTS analytics.new_table
(
    id Int64,
    name String,
    created_at DateTime,
    -- Add CDC metadata columns
    _version UInt64,
    _is_deleted UInt8 DEFAULT 0,
    _extracted_at DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY (id);
EOF

# 3. Execute in ClickHouse
cat /tmp/new_table.sql | curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" --data-binary @-

# 4. Verify table created
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SHOW CREATE TABLE analytics.new_table"

# 5. No need to restart connector - Debezium will automatically pick up the new table
# Wait a few minutes and verify data is flowing
sleep 300
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT count() FROM analytics.new_table"
```

### 4. Handling Schema Changes

**When**: Column added/removed/modified in MySQL

#### A. Column Added to MySQL Table

```bash
# ClickHouse will need the column too

# 1. Add column to ClickHouse
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "ALTER TABLE analytics.<table> ADD COLUMN <new_column> <type>"

# 2. Restart sink connector to recognize new schema
curl -X POST http://localhost:8085/connectors/clickhouse-sink-connector/restart

# 3. Verify column was added
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "DESC analytics.<table>"
```

#### B. Column Type Changed in MySQL

```bash
# May need to recreate ClickHouse table

# 1. Backup data
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "CREATE TABLE analytics.<table>_backup AS analytics.<table>"

# 2. Drop and recreate table with new schema
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "DROP TABLE analytics.<table>"

# 3. Create with new schema (use 01_analyze_mysql_schema.sh)
./phase3/scripts/01_analyze_mysql_schema.sh

# 4. Recreate table
./phase3/scripts/02_create_clickhouse_schema.sh

# 5. Restart connectors
curl -X POST http://localhost:8085/connectors/clickhouse-sink-connector/restart
```

### 5. Cleaning Up Old Data

**When**: Disk space is running low or archiving old data

```bash
# Option 1: Delete old data from ClickHouse
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "ALTER TABLE analytics.<table> DELETE WHERE _extracted_at < now() - INTERVAL 365 DAY"

# Option 2: Drop old partitions (if partitioned by date)
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "ALTER TABLE analytics.<table> DROP PARTITION '202301'"

# Option 3: Clean up Kafka topics
docker exec redpanda rpk topic delete <old-topic-name>

# Option 4: Optimize tables to remove old versions
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "OPTIMIZE TABLE analytics.<table> FINAL"
```

### 6. Monitoring Disk Usage

**When**: Regular monitoring or when alerts triggered

```bash
# Check overall disk usage
df -h

# Check Docker disk usage
du -sh /var/lib/docker

# Check ClickHouse data size
docker exec clickhouse du -sh /var/lib/clickhouse/data

# Check Redpanda data size
docker exec redpanda du -sh /var/lib/redpanda/data

# Check which tables are largest
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "
    SELECT
        table,
        formatReadableSize(sum(bytes)) as size
    FROM system.parts
    WHERE database = 'analytics' AND active
    GROUP BY table
    ORDER BY sum(bytes) DESC
    LIMIT 20
    "
```

### 7. Optimizing ClickHouse Tables

**When**: Weekly maintenance or performance issues

```bash
# Optimize single table (removes old versions, deduplicates)
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "OPTIMIZE TABLE analytics.<table> FINAL"

# Optimize all tables
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "
    SELECT concat('OPTIMIZE TABLE analytics.', name, ' FINAL') as cmd
    FROM system.tables
    WHERE database = 'analytics'
    " | while read cmd; do
    echo "Executing: $cmd"
    curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
        --data-binary "$cmd"
done
```

### 8. Backup and Restore

#### Backup ClickHouse Data

```bash
# Option 1: Full backup using ClickHouse backup tool
docker exec clickhouse clickhouse-backup create full_backup_$(date +%Y%m%d)

# Option 2: Export specific table
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT * FROM analytics.<table> FORMAT CSVWithNames" > /backup/<table>.csv

# Option 3: Backup entire database structure
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "SELECT create_table_query FROM system.tables WHERE database = 'analytics'" \
    > /backup/schema_backup_$(date +%Y%m%d).sql
```

#### Restore ClickHouse Data

```bash
# Option 1: Restore from ClickHouse backup
docker exec clickhouse clickhouse-backup restore full_backup_20241118

# Option 2: Import from CSV
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "INSERT INTO analytics.<table> FORMAT CSVWithNames" < /backup/<table>.csv
```

---

## Emergency Procedures

### Emergency 1: Complete System Failure

**Symptoms**: All services down, VPS unresponsive

**Steps**:
1. Restart VPS (via cloud provider console)
2. Wait for VPS to boot
3. Check all services:
   ```bash
   cd /home/user/clickhouse/phase2
   docker-compose ps
   ```
4. Start services if needed:
   ```bash
   docker-compose up -d
   ```
5. Verify connectors:
   ```bash
   ./phase4/scripts/03_health_check.sh
   ```
6. Redeploy connectors if needed:
   ```bash
   ./phase3/scripts/03_deploy_connectors.sh
   ```

### Emergency 2: Data Loss Detected

**Symptoms**: Row counts don't match, data missing

**Steps**:
1. **STOP** the pipeline immediately:
   ```bash
   curl -X PUT http://localhost:8085/connectors/mysql-source-connector/pause
   curl -X PUT http://localhost:8085/connectors/clickhouse-sink-connector/pause
   ```

2. Investigate the issue:
   ```bash
   # Check connector logs
   docker logs kafka-connect-clickhouse --tail 500

   # Check ClickHouse logs
   docker logs clickhouse --tail 500

   # Validate data
   ./phase4/scripts/02_validate_data_quality.sh
   ```

3. Determine root cause:
   - Schema mismatch?
   - Connector error?
   - Disk full?
   - Network issue?

4. Fix the root cause

5. Decide on recovery:
   - Small gap: Resume connectors (data will catch up)
   - Large gap: May need to re-snapshot

6. Resume pipeline:
   ```bash
   curl -X PUT http://localhost:8085/connectors/mysql-source-connector/resume
   curl -X PUT http://localhost:8085/connectors/clickhouse-sink-connector/resume
   ```

### Emergency 3: Disk Space Critical (>95%)

**Immediate actions**:
```bash
# 1. Clean Docker
docker system prune -af --volumes

# 2. Clean old Kafka topics
docker exec redpanda rpk topic list | grep -E "202[0-3]" | while read topic; do
    docker exec redpanda rpk topic delete "$topic"
done

# 3. Optimize ClickHouse tables
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "OPTIMIZE TABLE analytics.<largest_table> FINAL"

# 4. Delete old partitions
curl "http://localhost:8123/?user=$CLICKHOUSE_USER&password=$CLICKHOUSE_PASSWORD" \
    --data-binary "ALTER TABLE analytics.<table> DROP PARTITION '<old_partition>'"

# 5. Increase disk size (contact VPS provider)
```

---

## Performance Tuning

### 1. Increase Replication Speed

```bash
# Increase Debezium tasks
curl -X PUT http://localhost:8085/connectors/mysql-source-connector/config \
    -H "Content-Type: application/json" \
    -d '{"tasks.max": "4"}'

# Increase sink batch size
curl -X PUT http://localhost:8085/connectors/clickhouse-sink-connector/config \
    -H "Content-Type: application/json" \
    -d '{"batch.size": "100000", "flush.interval.ms": "10000"}'
```

### 2. Optimize ClickHouse Performance

```sql
-- Add proper ORDER BY for frequently queried columns
ALTER TABLE analytics.<table> MODIFY ORDER BY (primary_key, frequently_filtered_column);

-- Create materialized views for aggregations
CREATE MATERIALIZED VIEW analytics.<table>_daily_mv
ENGINE = SummingMergeTree()
ORDER BY (date, group_by_col)
AS SELECT
    toDate(_extracted_at) as date,
    group_by_col,
    sum(metric_col) as total
FROM analytics.<table>
GROUP BY date, group_by_col;

-- Partition large tables by date
ALTER TABLE analytics.<table>
MODIFY PARTITION BY toYYYYMM(_extracted_at);
```

---

## Monitoring and Alerting

### Set Up Email Alerts

```bash
# Create alert config
cat > /home/user/clickhouse/phase4/configs/alerts.conf << 'EOF'
ALERT_EMAIL=admin@example.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
EOF

# Create alert script
cat > /home/user/clickhouse/phase4/scripts/send_alert.sh << 'EOF'
#!/bin/bash
source /home/user/clickhouse/phase4/configs/alerts.conf
SUBJECT="$1"
MESSAGE="$2"
echo "$MESSAGE" | mail -s "$SUBJECT" -S smtp=$SMTP_SERVER:$SMTP_PORT \
    -S smtp-use-starttls -S smtp-auth=login \
    -S smtp-auth-user=$SMTP_USER -S smtp-auth-password=$SMTP_PASSWORD \
    $ALERT_EMAIL
EOF

chmod +x /home/user/clickhouse/phase4/scripts/send_alert.sh
```

### Set Up Cron Jobs for Monitoring

```bash
# Edit crontab
crontab -e

# Add these lines:
# Health check every 5 minutes
*/5 * * * * /home/user/clickhouse/phase4/scripts/03_health_check.sh || /home/user/clickhouse/phase4/scripts/send_alert.sh "CDC Health Check Failed" "See logs for details"

# Data quality check daily at 2 AM
0 2 * * * /home/user/clickhouse/phase4/scripts/02_validate_data_quality.sh

# Optimize tables weekly on Sunday at 3 AM
0 3 * * 0 curl "http://localhost:8123/?user=default&password=yourpass" --data-binary "OPTIMIZE TABLE analytics.orders FINAL"
```

---

## Contacts and Escalation

| Issue Type | Contact | Action |
|-----------|---------|--------|
| VPS down | Cloud provider support | Open ticket |
| MySQL issues | Database administrator | Check binlog, privileges |
| ClickHouse performance | DBA / DevOps | Optimize queries, tables |
| Network issues | Network admin | Check firewall, routing |
| Application issues | Development team | Review code changes |

---

## Useful Commands Reference

```bash
# Docker
docker-compose ps                    # List services
docker-compose logs -f <service>     # Follow logs
docker-compose restart <service>     # Restart service
docker stats                         # Resource usage

# Kafka Connect
curl http://localhost:8085/connectors                              # List connectors
curl http://localhost:8085/connectors/<name>/status                # Connector status
curl -X POST http://localhost:8085/connectors/<name>/restart       # Restart connector
curl -X PUT http://localhost:8085/connectors/<name>/pause          # Pause connector
curl -X PUT http://localhost:8085/connectors/<name>/resume         # Resume connector

# ClickHouse
docker exec -it clickhouse clickhouse-client                       # CLI access
curl "http://localhost:8123/?query=SELECT 1"                       # HTTP query
docker logs clickhouse --tail 100                                  # View logs

# Redpanda
docker exec redpanda rpk topic list                                # List topics
docker exec redpanda rpk topic consume <topic> --num 10            # Consume messages
docker logs redpanda --tail 100                                    # View logs

# System
df -h                                # Disk usage
free -h                              # Memory usage
top                                  # CPU usage
netstat -tulpn                       # Network connections
```

---

**Updated**: 2025-11-18

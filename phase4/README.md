# Phase 4: Operational Readiness & BI Integration

## Overview

This phase provides operational tools and guides for:
- **Monitoring** the CDC pipeline health and performance
- **Alerting** on issues and anomalies
- **Power BI** integration for analytics and reporting
- **Operational runbooks** for common tasks and troubleshooting

---

## Prerequisites

- ✅ Phase 3 completed (CDC pipeline running)
- ✅ Data flowing from MySQL to ClickHouse
- ✅ All connectors in RUNNING state

---

## Components

### 1. Monitoring & Alerting

**Scripts**:
- `scripts/01_monitor_cdc_lag.sh` - Monitor replication lag and throughput
- `scripts/02_validate_data_quality.sh` - Continuous data quality checks
- `scripts/03_health_check.sh` - Overall system health monitoring
- `scripts/04_connector_status.sh` - Check all connector statuses

**What they monitor**:
- ✅ Replication lag (how far behind ClickHouse is from MySQL)
- ✅ Data freshness (age of latest records)
- ✅ Connector health (Debezium, Sink connectors)
- ✅ Kafka topic lag
- ✅ Error rates and failed messages
- ✅ Throughput (rows/second)
- ✅ Data consistency (row count matching)

**Alert conditions**:
- ⚠️ Replication lag > 5 minutes
- ⚠️ Connector status != RUNNING
- ⚠️ Error rate > 1%
- ⚠️ Row count mismatch > 0.1%
- 🚨 Pipeline stopped for > 10 minutes

---

### 2. Power BI Integration

**Documentation**:
- `docs/POWER_BI_SETUP.md` - Step-by-step Power BI connection guide
- `docs/QUERY_OPTIMIZATION.md` - ClickHouse query optimization for BI

**Connection modes**:
1. **DirectQuery** (recommended) - Real-time queries to ClickHouse
2. **Import** - Scheduled data refresh

**Sample queries**:
- Pre-optimized ClickHouse queries for common analytics
- Materialized view examples
- Performance benchmarks

---

### 3. Operational Runbooks

**Documentation**:
- `docs/RUNBOOK.md` - Common operational tasks
- `docs/TROUBLESHOOTING.md` - Issue resolution guide
- `docs/DISASTER_RECOVERY.md` - Backup and recovery procedures

**Topics covered**:
- ✅ Restarting connectors
- ✅ Handling connector failures
- ✅ Resolving schema conflicts
- ✅ Managing disk space
- ✅ Scaling the pipeline
- ✅ Disaster recovery

---

## Quick Start

### 1. Start Monitoring

Monitor CDC lag and pipeline health:

```bash
cd /home/user/clickhouse/phase4

# Make scripts executable
chmod +x scripts/*.sh

# Start continuous monitoring (runs every 30 seconds)
./scripts/01_monitor_cdc_lag.sh
```

### 2. Validate Data Quality

Run data quality checks:

```bash
# One-time validation
./scripts/02_validate_data_quality.sh

# Continuous validation (runs every 5 minutes)
watch -n 300 ./scripts/02_validate_data_quality.sh
```

### 3. Check System Health

Overall health check:

```bash
# Quick health check
./scripts/03_health_check.sh

# Detailed connector status
./scripts/04_connector_status.sh
```

### 4. Connect Power BI

Follow the step-by-step guide:

```bash
cat docs/POWER_BI_SETUP.md
```

---

## Monitoring Dashboard (Optional)

For advanced monitoring, you can deploy:

**Prometheus + Grafana Stack**:
- Metrics from ClickHouse, Kafka Connect, Redpanda
- Pre-built dashboards for CDC pipelines
- Alerting via email/Slack/PagerDuty

**Quick deploy** (optional):
```bash
# Coming soon: docker-compose-monitoring.yml
docker-compose -f docker-compose-monitoring.yml up -d
```

Access:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

---

## Key Metrics to Monitor

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Replication Lag | < 10s | > 5 minutes |
| Data Freshness | < 1 minute | > 10 minutes |
| Connector Uptime | 99.9% | < 99% |
| Error Rate | 0% | > 0.1% |
| Throughput | Stable | Drop > 50% |
| Row Count Match | 100% | < 99.9% |

---

## Alerting Setup

### Email Alerts

Configure email alerts in `configs/alerts.conf`:

```bash
# Email settings
ALERT_EMAIL=admin@example.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### Slack Alerts

Configure Slack webhook:

```bash
# Slack settings
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
SLACK_CHANNEL=#cdc-alerts
```

---

## BI Performance Tips

### 1. Use Materialized Views

For frequently accessed aggregations:

```sql
-- Example: Daily sales summary
CREATE MATERIALIZED VIEW analytics.daily_sales_mv
ENGINE = SummingMergeTree()
ORDER BY (date, product_id)
AS SELECT
    toDate(_extracted_at) as date,
    product_id,
    sum(amount) as total_sales,
    count(*) as order_count
FROM analytics.orders
GROUP BY date, product_id;
```

### 2. Optimize Column Selection

Only select needed columns in Power BI:

```sql
-- Good: Select only needed columns
SELECT user_id, order_date, amount FROM orders

-- Bad: Select all columns
SELECT * FROM orders
```

### 3. Use Partitioning

For large tables, partition by date:

```sql
PARTITION BY toYYYYMM(_extracted_at)
```

### 4. Enable Query Caching

In ClickHouse config:

```xml
<query_cache>
    <max_size_in_bytes>1073741824</max_size_in_bytes>
    <max_entries>1024</max_entries>
    <max_entry_size_in_bytes>10485760</max_entry_size_in_bytes>
</query_cache>
```

---

## Operational Best Practices

### Daily Tasks
- ✅ Check monitoring dashboard
- ✅ Review error logs
- ✅ Verify replication lag < 1 minute

### Weekly Tasks
- ✅ Run data quality validation
- ✅ Review disk usage
- ✅ Check connector performance
- ✅ Review and optimize slow queries

### Monthly Tasks
- ✅ Review and optimize table schemas
- ✅ Update materialized views
- ✅ Test disaster recovery procedures
- ✅ Review and update documentation

---

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| High replication lag | Check connector logs, increase tasks.max |
| Connector stuck | Restart connector via API |
| Out of disk space | Clean up old Kafka topics, optimize ClickHouse |
| Schema mismatch | Update ClickHouse schema, restart sink connector |
| Slow queries | Add indexes, use materialized views |
| Connection errors | Check firewall, verify credentials |

For detailed troubleshooting, see `docs/TROUBLESHOOTING.md`

---

## Next Steps

1. **Set up monitoring** - Run monitoring scripts
2. **Configure alerts** - Set up email/Slack alerts
3. **Connect Power BI** - Follow BI setup guide
4. **Review runbooks** - Familiarize with operational procedures
5. **Test disaster recovery** - Ensure you can recover from failures

---

## Support

For issues and questions:
1. Check `docs/TROUBLESHOOTING.md`
2. Review `docs/RUNBOOK.md`
3. Check connector logs: `docker logs kafka-connect-clickhouse`
4. Check ClickHouse logs: `docker logs clickhouse`

---

**Phase 4 Status**: ✅ Complete - Ready for production operations

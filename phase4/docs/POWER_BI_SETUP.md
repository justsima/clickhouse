# Power BI Integration Guide

## Overview

This guide shows how to connect Power BI to your ClickHouse database for real-time analytics and reporting.

---

## Connection Options

### Option 1: DirectQuery (Recommended for Real-Time)

**Pros**:
- ✅ Real-time data (queries run against live database)
- ✅ No data storage in Power BI
- ✅ Always up-to-date dashboards

**Cons**:
- ⚠️ Slower query performance
- ⚠️ Requires stable network connection

### Option 2: Import Mode

**Pros**:
- ✅ Fast query performance
- ✅ Works offline

**Cons**:
- ⚠️ Data not real-time (refresh schedule needed)
- ⚠️ Stores duplicate data

---

## Prerequisites

1. **Power BI Desktop** installed on your machine
2. **ODBC Driver** for ClickHouse installed
3. **Network access** to your ClickHouse server
4. **ClickHouse credentials** (from `.env` file)

---

## Step 1: Install ClickHouse ODBC Driver

### Windows

1. Download ClickHouse ODBC driver from:
   ```
   https://github.com/ClickHouse/clickhouse-odbc/releases
   ```

2. Install the appropriate version:
   - **64-bit Power BI Desktop**: Use 64-bit ODBC driver
   - **32-bit Power BI Desktop**: Use 32-bit ODBC driver

3. Open **ODBC Data Source Administrator** (Windows):
   - Search for "ODBC" in Start menu
   - Choose 64-bit or 32-bit based on your Power BI version

4. Click **Add** → Select **ClickHouse ODBC Driver**

5. Configure the connection:
   ```
   Name: ClickHouse Analytics
   Host: <your-vps-ip>
   Port: 8123
   Database: analytics
   Username: default
   Password: <from .env file>
   ```

6. Click **Test** to verify connection

### macOS/Linux

1. Install via Homebrew (macOS):
   ```bash
   brew install clickhouse-odbc
   ```

2. Or download from:
   ```
   https://github.com/ClickHouse/clickhouse-odbc/releases
   ```

---

## Step 2: Connect Power BI to ClickHouse

### Method 1: Using ODBC Connector

1. Open **Power BI Desktop**

2. Click **Get Data** → **More** → **ODBC**

3. Select your ClickHouse DSN: **ClickHouse Analytics**

4. Enter credentials:
   - **User**: `default`
   - **Password**: `<from .env file>`

5. Choose connection mode:
   - **DirectQuery** (recommended for real-time)
   - **Import** (for better performance)

6. Navigate tables and select the ones you need

7. Click **Load** or **Transform Data**

### Method 2: Using Web/HTTP Connector (Alternative)

1. Open **Power BI Desktop**

2. Click **Get Data** → **Web**

3. Enter URL:
   ```
   http://<your-vps-ip>:8123/?user=default&password=<password>&query=SELECT * FROM analytics.your_table LIMIT 1000
   ```

4. Click **OK** and load data

---

## Step 3: Optimize Queries for Performance

### 1. Use Query Folding

Ensure Power BI pushes operations to ClickHouse:

**Good** (operations pushed to ClickHouse):
```
let
    Source = Odbc.DataSource("dsn=ClickHouse Analytics"),
    Database = Source{[Name="analytics"]}[Data],
    Table = Database{[Name="orders"]}[Data],
    Filtered = Table.SelectRows(Table, each [order_date] > #date(2024, 1, 1))
in
    Filtered
```

**Bad** (operations done in Power BI):
```
// Avoid loading full table then filtering
```

### 2. Select Only Needed Columns

```sql
-- Good: Select specific columns
SELECT user_id, order_date, amount FROM analytics.orders

-- Bad: Select all columns
SELECT * FROM analytics.orders
```

### 3. Use Pre-Aggregated Views

Create materialized views for common aggregations:

```sql
-- In ClickHouse
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

Then use in Power BI:
```
SELECT * FROM analytics.daily_sales_mv
```

### 4. Add Indexes to Frequently Filtered Columns

```sql
-- Create a table with proper ordering for your queries
CREATE TABLE analytics.orders_optimized
ENGINE = ReplacingMergeTree(_version)
ORDER BY (customer_id, order_date)  -- Order by frequently filtered columns
AS SELECT * FROM analytics.orders;
```

---

## Step 4: Create Efficient DAX Measures

### Good Practices

**1. Use ClickHouse aggregations instead of DAX when possible**

Good:
```sql
-- In ClickHouse query
SELECT customer_id, SUM(amount) as total
FROM analytics.orders
GROUP BY customer_id
```

Less optimal:
```dax
// In Power BI DAX
Total Sales = SUM(orders[amount])
```

**2. Use DirectQuery variables**

```dax
Sales Last 30 Days =
CALCULATE(
    SUM(orders[amount]),
    orders[order_date] >= TODAY() - 30
)
```

---

## Step 5: Set Up Scheduled Refresh (Import Mode Only)

If using Import mode:

1. Publish report to **Power BI Service**

2. Go to **Dataset Settings**

3. Configure **Scheduled Refresh**:
   - Frequency: Every 1 hour (or as needed)
   - Time zone: Your local timezone
   - Email on failure: Yes

4. Set up **Gateway** if needed:
   - Install **Power BI Gateway** on a machine with network access to ClickHouse
   - Configure gateway to use ClickHouse ODBC connection

---

## Sample Queries for Common Use Cases

### 1. Recent Orders

```sql
SELECT
    order_id,
    customer_id,
    order_date,
    amount,
    status
FROM analytics.orders
WHERE order_date >= today() - 30
ORDER BY order_date DESC
LIMIT 10000
```

### 2. Daily Sales Trend

```sql
SELECT
    toDate(order_date) as date,
    count(*) as order_count,
    sum(amount) as total_sales,
    avg(amount) as avg_order_value
FROM analytics.orders
WHERE order_date >= today() - 90
GROUP BY date
ORDER BY date
```

### 3. Top Customers

```sql
SELECT
    customer_id,
    count(*) as order_count,
    sum(amount) as total_spent,
    max(order_date) as last_order_date
FROM analytics.orders
WHERE order_date >= today() - 365
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 100
```

### 4. Product Performance

```sql
SELECT
    product_id,
    product_name,
    count(*) as units_sold,
    sum(price * quantity) as revenue
FROM analytics.order_items
WHERE order_date >= today() - 30
GROUP BY product_id, product_name
ORDER BY revenue DESC
LIMIT 50
```

---

## Performance Optimization Tips

### 1. Enable ClickHouse Query Cache

Add to ClickHouse config (`/home/user/clickhouse/phase2/configs/config.xml`):

```xml
<clickhouse>
    <query_cache>
        <max_size_in_bytes>1073741824</max_size_in_bytes>
        <max_entries>1024</max_entries>
        <max_entry_size_in_bytes>10485760</max_entry_size_in_bytes>
    </query_cache>
</clickhouse>
```

### 2. Use Partitioning for Large Tables

```sql
CREATE TABLE analytics.orders_partitioned
ENGINE = ReplacingMergeTree(_version)
PARTITION BY toYYYYMM(order_date)
ORDER BY (customer_id, order_date)
AS SELECT * FROM analytics.orders;
```

### 3. Create Materialized Views for Dashboard Metrics

```sql
-- Daily metrics
CREATE MATERIALIZED VIEW analytics.metrics_daily_mv
ENGINE = SummingMergeTree()
ORDER BY date
AS SELECT
    toDate(_extracted_at) as date,
    count(*) as total_orders,
    sum(amount) as total_revenue,
    uniq(customer_id) as unique_customers
FROM analytics.orders
GROUP BY date;
```

### 4. Use LIMIT in Queries

Always use LIMIT to prevent loading too much data:

```sql
SELECT * FROM analytics.orders LIMIT 100000
```

---

## Troubleshooting

### Issue: Connection Timeout

**Solution**:
1. Check firewall allows port 8123
2. Verify VPS IP is correct
3. Test connection with curl:
   ```bash
   curl "http://<vps-ip>:8123/?query=SELECT 1"
   ```

### Issue: Slow Query Performance

**Solution**:
1. Use DirectQuery with aggregations
2. Create materialized views
3. Add proper indexes (ORDER BY)
4. Use LIMIT clauses
5. Monitor queries:
   ```sql
   SELECT * FROM system.query_log
   ORDER BY event_time DESC
   LIMIT 10
   ```

### Issue: Authentication Failed

**Solution**:
1. Verify username/password in `.env` file
2. Check ClickHouse user permissions:
   ```sql
   SHOW GRANTS FOR default
   ```
3. Ensure ODBC driver version matches ClickHouse version

### Issue: Tables Not Visible

**Solution**:
1. Verify tables exist:
   ```bash
   curl "http://<vps-ip>:8123/?user=default&password=<pwd>&query=SHOW TABLES FROM analytics"
   ```
2. Check database name is correct: `analytics`
3. Verify user has permissions to database

---

## Best Practices Summary

✅ **DO**:
- Use DirectQuery for real-time dashboards
- Create materialized views for aggregations
- Use LIMIT clauses
- Select only needed columns
- Use proper ORDER BY for frequently filtered columns
- Monitor query performance regularly

❌ **DON'T**:
- Load entire large tables into Power BI
- Use SELECT * for large tables
- Create too many DAX measures (use ClickHouse aggregations)
- Forget to set up refresh schedules (Import mode)
- Skip query optimization

---

## Sample Dashboard Ideas

1. **Sales Dashboard**:
   - Daily/Weekly/Monthly revenue trends
   - Top products by revenue
   - Top customers by spend
   - Geographic sales distribution

2. **Customer Analytics**:
   - Customer lifetime value
   - Cohort analysis
   - Retention rates
   - Churn analysis

3. **Operational Metrics**:
   - Order fulfillment time
   - Inventory levels
   - Shipping performance
   - Return rates

4. **Real-Time Monitoring**:
   - Current hour sales
   - Active users
   - Recent transactions
   - System alerts

---

## Additional Resources

- ClickHouse Documentation: https://clickhouse.com/docs/
- Power BI Documentation: https://docs.microsoft.com/en-us/power-bi/
- ClickHouse ODBC Driver: https://github.com/ClickHouse/clickhouse-odbc
- Query Optimization Guide: See `QUERY_OPTIMIZATION.md`

---

**Updated**: 2025-11-18

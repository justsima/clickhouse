# Phase 1: Foundation & Prerequisites

## Overview

This phase validates your environment and ensures all prerequisites are met before deploying the CDC pipeline.

**Objective**: Confirm that MySQL, VPS, and network are ready for Debezium + Redpanda + ClickHouse deployment.

**Duration**: 1-2 hours (including fixes if needed)

---

## Phase 1 Deliverables

✅ Environment detection and resource validation
✅ MySQL binlog configuration check
✅ Replication user creation
✅ Network throughput testing
✅ Architecture documentation
✅ Port mapping and security plan

---

## Directory Structure

```
phase1/
├── README.md                          # This file
├── scripts/
│   ├── 01_environment_check.sh        # VPS resource validation
│   ├── 02_mysql_validation.sh         # MySQL config check
│   ├── 03_create_replication_user.sh  # Create Debezium user
│   └── 04_network_validation.sh       # Throughput testing
├── configs/
│   └── .env.example                   # Template for credentials
├── docs/
│   ├── ARCHITECTURE.md                # Full system design
│   └── PORTS_AND_SECURITY.md          # Port mapping & security
└── [Generated Reports]
    ├── environment_info.txt
    ├── mysql_validation_report.txt
    ├── replication_user_info.txt
    └── network_validation_report.txt
```

---

## Prerequisites

Before running these scripts, ensure you have:

1. **VPS Access**: SSH access with sudo/root privileges
2. **MySQL Credentials**: Admin access to your DigitalOcean MySQL database
3. **Network Connectivity**: VPS can reach MySQL (port 25060)
4. **Docker Installed**: Docker and Docker Compose available

---

## Step-by-Step Execution

### Step 1: Configure Credentials

1. Copy the example environment file:
   ```bash
   cd /home/user/clickhouse/phase1/configs
   cp .env.example .env
   ```

2. Edit `.env` with your actual credentials:
   ```bash
   vi .env  # or nano, vim, etc.
   ```

3. Fill in these critical values:
   ```bash
   # MySQL Connection (DigitalOcean)
   MYSQL_HOST=your-db.db.ondigitalocean.com
   MYSQL_PORT=25060
   MYSQL_DATABASE=your_database_name
   MYSQL_USER=your_admin_user
   MYSQL_PASSWORD=your_admin_password

   # Replication User (will be created in Step 4)
   MYSQL_REPLICATION_USER=debezium_user
   MYSQL_REPLICATION_PASSWORD=generate_strong_password_123!

   # ClickHouse (for later phases)
   CLICKHOUSE_PASSWORD=generate_clickhouse_password_456!

   # Console Security
   CONSOLE_ADMIN_USER=admin
   CONSOLE_ADMIN_PASSWORD=generate_console_password_789!
   ```

4. Secure the file:
   ```bash
   chmod 600 .env
   ```

---

### Step 2: Environment Check (VPS)

**Purpose**: Validate VPS resources, Docker, and port availability

```bash
cd /home/user/clickhouse/phase1/scripts
chmod +x 01_environment_check.sh
./01_environment_check.sh
```

**Expected Output**:
```
✓ CentOS detected
✓ Docker installed
✓ Docker service running
✓ RAM sufficient (64GB)
✓ Disk space sufficient
✓ CPU cores sufficient
✓ Port 9092 (Redpanda Kafka) available
✓ Port 8080 (Redpanda Console) available
✓ Port 9000 (ClickHouse Native) available
✓ Port 8123 (ClickHouse HTTP) available
```

**What to Check**:
- All required ports are available
- Docker is running
- At least 30% disk space free
- Sufficient RAM (32GB minimum, 64GB ideal)

**If Issues Found**:
- Port conflicts: Stop conflicting services or use alternative ports
- Docker not running: `systemctl start docker`
- Low disk space: Free up space or upgrade VPS

**Generated Report**: `phase1/environment_info.txt`

---

### Step 3: MySQL Validation

**Purpose**: Check MySQL binlog configuration and database readiness

**Requirements**:
- MySQL client installed on VPS
- If not installed:
  ```bash
  # CentOS 7
  yum install mysql -y

  # CentOS 8+
  dnf install mysql -y

  # Or use Docker
  docker run --rm -it mysql:8.0 mysql -h<host> -u<user> -p
  ```

**Run Validation**:
```bash
chmod +x 02_mysql_validation.sh
./02_mysql_validation.sh
```

**Expected Output**:
```
✓ Successfully connected to MySQL
✓ MySQL 8.0 detected (compatible with Debezium)
✓ binlog_format is ROW (required for Debezium)
✓ binlog_row_image is FULL (optimal for Debezium)
✓ Binary logging is enabled
✓ Binlog retention sufficient (7 days)
✓ GTID mode enabled (recommended for Debezium)
✓ Database 'your_db' exists
✓ MySQL configuration is ready for CDC
```

**Critical Checks** (Must Pass):
- ✅ `binlog_format = ROW`
- ✅ `log_bin = 1` (binary logging enabled)

**Recommended** (Should Pass):
- ✅ `binlog_row_image = FULL`
- ✅ `gtid_mode = ON`
- ✅ Binlog retention ≥ 3 days

**If Issues Found**:

1. **binlog_format not ROW**:
   - DigitalOcean Managed MySQL: Check database settings panel
   - Self-hosted: Add to `my.cnf`:
     ```ini
     [mysqld]
     binlog_format = ROW
     binlog_row_image = FULL
     ```
   - Restart MySQL

2. **Binary logging disabled**:
   - Contact DigitalOcean support (managed databases)
   - Self-hosted: Enable in `my.cnf` and restart

3. **Low binlog retention**:
   - Increase to 7 days (covers snapshot + buffer)
   - `SET GLOBAL binlog_expire_logs_seconds = 604800;`

**Generated Report**: `phase1/mysql_validation_report.txt`

---

### Step 4: Create Replication User

**Purpose**: Create dedicated MySQL user for Debezium with minimal privileges

**Run Script**:
```bash
chmod +x 03_create_replication_user.sh
./03_create_replication_user.sh
```

**What It Does**:
1. Creates `debezium_user` (or name from `.env`)
2. Grants required privileges:
   - `REPLICATION SLAVE` - Read binlog
   - `REPLICATION CLIENT` - Query binlog position
   - `SELECT` - Read table data for snapshot
   - `RELOAD` - Table locks (if available)
   - `LOCK TABLES` - Consistent snapshot
3. Tests connection with new user

**Expected Output**:
```
✓ User created successfully
✓ REPLICATION SLAVE granted
✓ REPLICATION CLIENT granted
✓ SELECT on your_database.* granted
✓ RELOAD granted
✓ LOCK TABLES granted
✓ Privileges flushed
✓ Replication user can connect successfully
✓ Replication user can read from your_database
```

**If Issues Found**:

1. **Insufficient privileges**:
   - Make sure you're using MySQL admin user in Step 3
   - Check `MYSQL_USER` has GRANT privileges

2. **User already exists**:
   - Script will prompt to drop and recreate
   - Or skip creation and update grants only

3. **RELOAD/LOCK TABLES not available**:
   - Common on managed MySQL (security restriction)
   - Not critical: Debezium can work without FTWRL
   - May use GTID or less strict snapshot locking

**Generated Report**: `phase1/replication_user_info.txt`

---

### Step 5: Network Validation

**Purpose**: Test network connectivity and throughput between VPS and MySQL

**Run Script**:
```bash
chmod +x 04_network_validation.sh
./04_network_validation.sh
```

**What It Tests**:
1. TCP connectivity to MySQL
2. Latency (ping test)
3. Connection time (5 samples)
4. Data transfer throughput (query 10k rows)
5. Binlog access
6. Concurrent connections
7. Estimate initial snapshot time

**Expected Output**:
```
✓ TCP connection successful
✓ Average latency: 15ms
✓ Connection time excellent (avg: 45ms)
✓ Throughput: 125 MB/s (1000 Mbps)
✓ Can read binlog position
✓ Concurrent connections successful
✓ Estimated snapshot time: 12 minutes
```

**Performance Benchmarks**:

| Metric | Excellent | Good | Acceptable | Poor |
|--------|-----------|------|------------|------|
| Latency | <20ms | 20-50ms | 50-100ms | >100ms |
| Connection | <100ms | 100-500ms | 500ms-1s | >1s |
| Throughput | >100 Mbps | 50-100 Mbps | 10-50 Mbps | <10 Mbps |

**If Performance Is Poor**:

1. **High latency (>100ms)**:
   - Check VPS location vs MySQL region
   - Consider VPS in same datacenter as MySQL
   - Initial snapshot will take longer

2. **Low throughput (<10 Mbps)**:
   - Network bottleneck (ISP, VPS provider)
   - May need bulk backfill instead of Debezium snapshot
   - Contact VPS/DO support to verify network

3. **Connection timeouts**:
   - Firewall blocking connection
   - Verify VPS IP whitelisted in DO MySQL settings
   - Check MySQL max_connections setting

**Snapshot Time Estimates**:

| DB Size | Throughput | Estimated Time |
|---------|------------|----------------|
| 1 GB | 10 MB/s | ~2 minutes |
| 10 GB | 10 MB/s | ~17 minutes |
| 50 GB | 10 MB/s | ~1.5 hours |
| 100 GB | 10 MB/s | ~3 hours |
| 100 GB | 50 MB/s | ~35 minutes |

**Generated Report**: `phase1/network_validation_report.txt`

---

## Review Documentation

### Architecture Overview

Read the full system design:
```bash
cat /home/user/clickhouse/phase1/docs/ARCHITECTURE.md
```

**Key Sections**:
- Component details (Debezium, Redpanda, ClickHouse)
- Data flow sequence (initial load + CDC)
- Failure scenarios and recovery
- Scaling considerations

### Port Mapping & Security

Review port requirements and security plan:
```bash
cat /home/user/clickhouse/phase1/docs/PORTS_AND_SECURITY.md
```

**Key Sections**:
- All service ports (9092, 8080, 9000, 8123, etc.)
- Firewall configuration examples
- Security checklist
- Access control matrix

---

## Validation Checklist

Before proceeding to Phase 2, confirm:

### Environment
- [ ] VPS has 32GB+ RAM, 500GB+ disk
- [ ] Docker and Docker Compose installed
- [ ] All required ports available (9092, 9000, 8080, 8083, 8123)
- [ ] 30%+ disk space free

### MySQL
- [ ] `binlog_format = ROW` ✅ (CRITICAL)
- [ ] `log_bin = 1` ✅ (CRITICAL)
- [ ] `binlog_row_image = FULL` (recommended)
- [ ] `gtid_mode = ON` (recommended)
- [ ] Binlog retention ≥ 3 days
- [ ] Replication user created with proper privileges
- [ ] Can connect with replication user from VPS

### Network
- [ ] VPS can reach MySQL (port 25060)
- [ ] Latency acceptable (<100ms)
- [ ] Throughput sufficient (>10 Mbps)
- [ ] Estimated snapshot time acceptable
- [ ] VPS IP whitelisted in DO MySQL firewall

### Security
- [ ] `.env` file configured with strong passwords
- [ ] `.env` file permissions set to 600
- [ ] Firewall plan reviewed
- [ ] Admin credentials secured

---

## Troubleshooting

### MySQL Client Not Found

**Error**: `mysql: command not found`

**Solution**:
```bash
# CentOS 7
yum install mysql -y

# CentOS 8+
dnf install mysql -y

# Or use Docker
alias mysql='docker run --rm -it mysql:8.0 mysql'
```

### Cannot Connect to MySQL

**Error**: `ERROR 2003: Can't connect to MySQL server`

**Checklist**:
1. Verify credentials in `.env` are correct
2. Check VPS IP is whitelisted in DigitalOcean MySQL settings:
   - DO Dashboard → Databases → Your MySQL → Settings → Trusted Sources
   - Add your VPS public IP
3. Test with `telnet`:
   ```bash
   telnet your-host.db.ondigitalocean.com 25060
   ```
4. Check MySQL user has remote access (`%` host)

### Binlog Format Not ROW

**Error**: `binlog_format is STATEMENT (must be ROW)`

**Solution (DigitalOcean Managed)**:
1. Go to DO Dashboard → Databases → Your MySQL
2. Settings → Configuration
3. Find "Binary Log Format" → Change to "ROW"
4. Apply changes (may require restart)

**Solution (Self-Hosted)**:
1. Edit `/etc/my.cnf`:
   ```ini
   [mysqld]
   binlog_format = ROW
   binlog_row_image = FULL
   ```
2. Restart MySQL: `systemctl restart mysqld`

### Port Already in Use

**Error**: `Port 9092 already in use`

**Solution**:
1. Find process using port:
   ```bash
   netstat -tuln | grep 9092
   lsof -i :9092
   ```
2. Stop conflicting service or change port in Phase 2 config

### Low Throughput

**Issue**: Network speed <10 Mbps

**Solutions**:
1. Test from VPS to public server:
   ```bash
   curl -o /dev/null http://speedtest.tele2.net/100MB.zip
   ```
2. If VPS is slow: Upgrade VPS or change provider
3. If MySQL is slow: Contact DO support
4. Consider bulk backfill instead of Debezium snapshot

---

## Next Steps

Once all validation checks pass:

1. **Review all generated reports**:
   ```bash
   ls -lh /home/user/clickhouse/phase1/*.txt
   ```

2. **Read architecture documentation**:
   - Understand data flow
   - Review failure scenarios
   - Plan monitoring strategy

3. **Prepare for Phase 2**:
   - Ensure `.env` is finalized
   - Plan downtime window (if needed for initial load)
   - Document current MySQL state (row counts, schemas)

4. **Proceed to Phase 2**: Service Deployment
   ```bash
   cd /home/user/clickhouse/phase2
   cat README.md
   ```

---

## Phase 1 Summary

**What We Validated**:
- ✅ VPS resources (CPU, RAM, disk, ports)
- ✅ Docker environment ready
- ✅ MySQL binlog configuration correct
- ✅ Replication user created with proper privileges
- ✅ Network connectivity and throughput acceptable
- ✅ Estimated snapshot time reasonable

**What We Documented**:
- ✅ Full architecture and data flow
- ✅ Port mapping and security plan
- ✅ Component responsibilities
- ✅ Failure recovery procedures

**Time Investment**: 1-2 hours
**Risk Reduction**: Catch configuration issues before deployment

---

## Support & Questions

If you encounter issues not covered in this guide:

1. **Check the generated reports** for detailed diagnostics
2. **Review logs** from failed scripts
3. **Consult documentation**:
   - [Debezium MySQL Connector](https://debezium.io/documentation/reference/stable/connectors/mysql.html)
   - [DigitalOcean MySQL](https://docs.digitalocean.com/products/databases/mysql/)
   - [Redpanda Documentation](https://docs.redpanda.com/)
4. **Ask me** - provide error messages and report files

---

## Files Checklist

After completing Phase 1, you should have:

```
✓ /home/user/clickhouse/phase1/configs/.env
✓ /home/user/clickhouse/phase1/environment_info.txt
✓ /home/user/clickhouse/phase1/mysql_validation_report.txt
✓ /home/user/clickhouse/phase1/replication_user_info.txt
✓ /home/user/clickhouse/phase1/network_validation_report.txt
```

**Ready for Phase 2?** Let's deploy! 🚀

---

**Phase 1 Status**: ✅ Complete
**Next Phase**: Phase 2 - Service Deployment
**Estimated Phase 2 Duration**: 2-3 hours

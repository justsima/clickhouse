# Quick Start Guide - Phase 1

## Your MySQL Credentials Are Configured! ✓

Your `.env` file has been created with your DigitalOcean MySQL credentials.

**Database**: `mulazamflatoddbet`
**Host**: `mulasport-db-mysql-fra1-89664-do-user-7185962-0.b.db.ondigitalocean.com`
**Port**: `25060`

---

## Step 1: Install Required Software (On Your VPS)

First, pull the latest code on your VPS:
```bash
cd /home/user/clickhouse
git pull origin claude/mysql-to-clickhouse-migration-01CUjxKPiV5QGUrW9bSaszHe
```

Then run the installation script (requires root/sudo):
```bash
cd phase1/scripts
sudo ./00_install_prerequisites.sh
```

**What this installs:**
- ✅ MySQL client (for database validation)
- ✅ Basic utilities (curl, wget, netstat, bc)
- ✅ Docker (container runtime)
- ✅ Docker Compose (orchestration)

**Duration**: 5-10 minutes depending on your internet speed

---

## Step 2: Run Validation Scripts

After installation completes, run the validation scripts **in order**:

### Script 1: Environment Check
```bash
./01_environment_check.sh
```
**Checks**: VPS resources, Docker, ports
**Duration**: ~1 minute

### Script 2: MySQL Validation
```bash
./02_mysql_validation.sh
```
**Checks**: Binlog config, database access, GTID mode
**Duration**: ~2 minutes

⚠️ **CRITICAL**: This script MUST show:
- ✅ `binlog_format = ROW`
- ✅ `log_bin = 1`

If these fail, contact DigitalOcean support to enable binary logging.

### Script 3: Create Replication User
```bash
./03_create_replication_user.sh
```
**Creates**: Debezium replication user with proper privileges
**Duration**: ~1 minute

### Script 4: Network Validation
```bash
./04_network_validation.sh
```
**Tests**: Latency, throughput, snapshot time estimates
**Duration**: ~3 minutes

---

## Step 3: Review Results

Check the generated reports:
```bash
cd /home/user/clickhouse/phase1
ls -lh *.txt
cat mysql_validation_report.txt
cat network_validation_report.txt
```

---

## Expected Results

### All Checks Should Pass:

✅ VPS has sufficient resources (64GB RAM, 1TB disk)
✅ Docker is running
✅ All ports available (9092, 9000, 8080, 8123, 8083)
✅ MySQL binlog_format = ROW
✅ Binary logging enabled
✅ Replication user created
✅ Network throughput > 10 Mbps
✅ Can connect to MySQL from VPS

---

## Common Issues & Solutions

### Issue: "mysql: command not found" after installation

**Solution**: The installation script should fix this, but if it persists:
```bash
# Try MariaDB client (compatible)
sudo yum install mariadb -y

# Or use Docker
alias mysql='docker run --rm -it mysql:8.0 mysql'
```

---

### Issue: "Cannot connect to MySQL server"

**Solution**: Whitelist your VPS IP in DigitalOcean:
1. Go to DigitalOcean Dashboard
2. Databases → Your MySQL
3. Settings → Trusted Sources
4. Add your VPS public IP address

To find your VPS public IP:
```bash
curl ifconfig.me
```

---

### Issue: "binlog_format is not ROW"

**Solution**: This is CRITICAL for CDC. Contact DigitalOcean support to:
1. Set `binlog_format = ROW`
2. Enable binary logging (`log_bin = 1`)
3. Set `binlog_row_image = FULL` (recommended)

For managed databases, this is done through DO dashboard under database configuration.

---

### Issue: "Port already in use"

**Solution**: Find and stop the conflicting service:
```bash
# Find what's using the port (example: 9092)
sudo netstat -tuln | grep 9092
sudo lsof -i :9092

# Stop the service
sudo systemctl stop <service-name>
```

---

## What to Do After Phase 1 Completes

Once all validation scripts pass:

1. **Share the reports** with me (the generated .txt files)
2. **Confirm** you're ready to proceed
3. **I'll implement Phase 2**: Docker Compose deployment for:
   - Redpanda (Kafka broker)
   - Kafka Connect (Debezium + ClickHouse Sink)
   - ClickHouse database
   - Redpanda Console (Web UI)

---

## Security Notes

🔒 Your `.env` file contains sensitive credentials and is:
- ✅ Already created with your MySQL details
- ✅ Protected (chmod 600)
- ✅ Gitignored (won't be committed)

**NEVER** share your `.env` file or commit it to git!

---

## Need Help?

Run the scripts on your VPS and share:
1. Any error messages you see
2. The generated report files (`phase1/*.txt`)
3. Output from failed scripts

I'll help you troubleshoot and fix any issues!

---

## Time Estimate

| Step | Duration |
|------|----------|
| Install prerequisites | 5-10 min |
| Run validation scripts | 7-10 min |
| Review results | 5 min |
| **Total** | **20-25 min** |

---

**Ready? Run the commands on your VPS and let me know the results!** 🚀

# Port Mapping & Security Checklist

## Overview

This document provides a comprehensive reference for all network ports, security configurations, and access control requirements for the MySQL to ClickHouse CDC pipeline.

---

## Port Mapping Table

| Service | Port | Protocol | Purpose | Access Level | Notes |
|---------|------|----------|---------|--------------|-------|
| **Redpanda - Kafka API** | 9092 | TCP | Kafka protocol (producers/consumers) | Internal + External* | Main data streaming port |
| **Redpanda - Admin** | 9644 | TCP | Admin API, metrics, health | Internal + Monitoring | Prometheus scraping |
| **Redpanda - Schema Registry** | 8081 | TCP | Avro/JSON schema management | Internal | Optional for Debezium |
| **Redpanda - HTTP Proxy** | 8082 | TCP | REST API for Kafka operations | Internal | Alternative to native protocol |
| **Kafka Connect - REST** | 8083 | TCP | Connector management API | Internal + Your IP | Create/manage connectors |
| **Redpanda Console** | 8080 | TCP | Web UI for management | Your IP only | Requires authentication |
| **ClickHouse - Native** | 9000 | TCP | Native client protocol | Internal + BI Gateway | High-performance queries |
| **ClickHouse - HTTP** | 8123 | TCP | HTTP interface, REST API | Internal + Your IP | Web UI, health checks |
| **MySQL (DigitalOcean)** | 25060 | TCP | MySQL connection | VPS → DO | Source database |

\* External access only if you need to send data from outside VPS

---

## Detailed Port Descriptions

### Redpanda Kafka API (9092)

**Purpose**: Primary data streaming port for Kafka protocol

**Who connects**:
- Debezium connector (producer)
- ClickHouse Sink connector (consumer)
- Redpanda Console (monitoring)
- External producers (if needed)

**Security**:
- Bind to: `0.0.0.0:9092` (accessible from all interfaces)
- Firewall: Allow from localhost + trusted IPs only
- Authentication: SASL (optional, Phase 2)
- Encryption: TLS (optional, may reduce throughput)

**Configuration** (Docker Compose):
```yaml
ports:
  - "9092:9092"
environment:
  REDPANDA_ADVERTISED_KAFKA_API: "localhost:9092"
```

---

### Redpanda Admin API (9644)

**Purpose**: Cluster management, metrics, health checks

**Who connects**:
- Redpanda Console
- Monitoring tools (Prometheus)
- Admin scripts

**Endpoints**:
- `GET /v1/cluster/health_overview` - Cluster health
- `GET /metrics` - Prometheus metrics
- `GET /v1/brokers` - Broker list

**Security**:
- Bind to: `localhost:9644` (internal only)
- Firewall: Block external access
- Authentication: Basic auth (optional)

**Configuration**:
```yaml
ports:
  - "9644:9644"
```

---

### Schema Registry (8081)

**Purpose**: Manage Avro/JSON schemas for messages

**Who connects**:
- Debezium (if using Avro format)
- ClickHouse Sink (schema validation)

**Security**:
- Bind to: `localhost:8081`
- Firewall: Internal only
- Authentication: Basic auth (optional)

**Note**: Not required if using JSON format (simpler)

**Configuration**:
```yaml
ports:
  - "8081:8081"
```

---

### HTTP Proxy (8082)

**Purpose**: REST API for producing/consuming messages

**Endpoints**:
- `POST /topics/{topic}` - Produce message
- `GET /consumers/{group}/instances/{instance}/records` - Consume

**Security**:
- Bind to: `localhost:8082`
- Firewall: Internal only
- Authentication: Basic auth (optional)

**Use Case**: Testing, debugging, web clients

**Configuration**:
```yaml
ports:
  - "8082:8082"
```

---

### Kafka Connect REST (8083)

**Purpose**: Manage Debezium and ClickHouse Sink connectors

**Critical Endpoints**:
- `GET /connectors` - List all connectors
- `POST /connectors` - Create new connector
- `GET /connectors/{name}/status` - Connector health
- `PUT /connectors/{name}/config` - Update config
- `POST /connectors/{name}/restart` - Restart connector
- `DELETE /connectors/{name}` - Remove connector

**Security**:
- Bind to: `0.0.0.0:8083` (accessible for management)
- Firewall: Your IP only
- Authentication: None by default (use firewall)

**Configuration**:
```yaml
ports:
  - "8083:8083"
environment:
  CONNECT_REST_PORT: 8083
```

---

### Redpanda Console (8080)

**Purpose**: Web-based management UI

**Features**:
- Browse topics and messages
- Monitor consumer lag
- View connector status
- Inspect schemas
- Manage ACLs

**Security** (CRITICAL):
- Bind to: `0.0.0.0:8080`
- Firewall: **Your IP only** (whitelist)
- Authentication: **Required** (basic auth)
  ```yaml
  LOGIN_ENABLED: "true"
  LOGIN_USERNAME: "admin"
  LOGIN_PASSWORD: "secure_password_here"
  ```

**Access URL**: `http://<vps-ip>:8080`

**Configuration**:
```yaml
ports:
  - "8080:8080"
environment:
  KAFKA_BROKERS: "redpanda:9092"
  CONNECT_ENABLED: "true"
  CONNECT_CLUSTERS_NAME: "local"
  CONNECT_CLUSTERS_URL: "http://kafka-connect:8083"
```

---

### ClickHouse Native (9000)

**Purpose**: High-performance native client protocol

**Who connects**:
- `clickhouse-client` (CLI)
- ClickHouse drivers (Python, Go, Java)
- Power BI connector
- BI tools

**Performance**: 2-10x faster than HTTP for large queries

**Security**:
- Bind to: `0.0.0.0:9000` (accessible for BI)
- Firewall: Localhost + Power BI Gateway IP
- Authentication: Username/password required
- Encryption: TLS (optional)

**Connection String**:
```bash
clickhouse-client --host localhost --port 9000 --user default --password <password>
```

**Configuration**:
```yaml
ports:
  - "9000:9000"
```

---

### ClickHouse HTTP (8123)

**Purpose**: HTTP interface for queries and management

**Endpoints**:
- `GET /` - Health check
- `POST /?query=...` - Execute query
- `GET /play` - Web-based SQL editor

**Who connects**:
- Web browsers (Play UI)
- REST clients (curl, Postman)
- Monitoring scripts
- Power BI (HTTP connector)

**Security**:
- Bind to: `0.0.0.0:8123`
- Firewall: Your IP + localhost
- Authentication: Username/password (URL params or headers)

**Example**:
```bash
curl -u default:<password> 'http://localhost:8123/?query=SELECT+version()'
```

**Configuration**:
```yaml
ports:
  - "8123:8123"
```

---

### MySQL on DigitalOcean (25060)

**Purpose**: Source database for CDC

**Who connects**:
- Debezium connector (reads binlog)
- Your validation scripts

**Security**:
- Managed by DigitalOcean
- Firewall: Add VPS IP to trusted sources
- TLS: Enabled by default on DO
- Authentication: Replication user credentials

**Connection String**:
```bash
mysql -h <host>.db.ondigitalocean.com -P 25060 -u debezium_user -p
```

**Configuration** (in Debezium connector):
```json
{
  "database.hostname": "your-host.db.ondigitalocean.com",
  "database.port": "25060",
  "database.user": "debezium_user",
  "database.password": "...",
  "database.ssl.mode": "required"
}
```

---

## Firewall Configuration

### Recommended iptables Rules (CentOS)

```bash
#!/bin/bash
# Phase 1 - Firewall Setup Script

# Flush existing rules
iptables -F

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (adjust port if needed)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow from YOUR IP ONLY (replace with your actual IP)
YOUR_IP="x.x.x.x/32"

# Redpanda Console (web UI)
iptables -A INPUT -p tcp --dport 8080 -s $YOUR_IP -j ACCEPT

# Kafka Connect REST (connector management)
iptables -A INPUT -p tcp --dport 8083 -s $YOUR_IP -j ACCEPT

# ClickHouse HTTP (web UI, REST API)
iptables -A INPUT -p tcp --dport 8123 -s $YOUR_IP -j ACCEPT

# ClickHouse Native (for Power BI Gateway)
# Add Power BI Gateway IP when ready
# iptables -A INPUT -p tcp --dport 9000 -s <gateway-ip> -j ACCEPT

# Allow localhost for all ports (internal communication)
iptables -A INPUT -s 127.0.0.1 -j ACCEPT

# Log dropped packets (debugging)
iptables -A INPUT -j LOG --log-prefix "iptables-dropped: "

# Save rules
service iptables save  # CentOS 7
# OR
iptables-save > /etc/sysconfig/iptables  # Manual save

# Enable iptables service
systemctl enable iptables
systemctl start iptables
```

### Alternative: firewalld (CentOS 8+)

```bash
#!/bin/bash
# Firewall setup using firewalld

# Install firewalld if needed
dnf install firewalld -y
systemctl enable firewalld
systemctl start firewalld

# Set default zone to drop
firewall-cmd --set-default-zone=drop

# Add your IP to trusted zone
YOUR_IP="x.x.x.x/32"
firewall-cmd --zone=trusted --add-source=$YOUR_IP --permanent

# Allow ports in trusted zone
firewall-cmd --zone=trusted --add-port=8080/tcp --permanent  # Console
firewall-cmd --zone=trusted --add-port=8083/tcp --permanent  # Kafka Connect
firewall-cmd --zone=trusted --add-port=8123/tcp --permanent  # ClickHouse HTTP
firewall-cmd --zone=trusted --add-port=9000/tcp --permanent  # ClickHouse Native

# Allow SSH from anywhere (adjust as needed)
firewall-cmd --zone=public --add-service=ssh --permanent

# Reload rules
firewall-cmd --reload

# Verify
firewall-cmd --list-all-zones
```

---

## Security Checklist

### Pre-Deployment

- [ ] Generate strong passwords for all services
- [ ] Store credentials in `.env` file (gitignored)
- [ ] Configure firewall to allow only your IP
- [ ] Disable root SSH (use key-based auth)
- [ ] Enable automatic security updates on VPS

### Service Security

#### Redpanda

- [ ] Enable basic auth on console (LOGIN_ENABLED=true)
- [ ] Consider SASL for Kafka API (if external producers)
- [ ] Bind admin API to localhost only
- [ ] Regular updates (check Redpanda releases)

#### Kafka Connect

- [ ] Restrict REST API to trusted IPs via firewall
- [ ] Use secrets for connector configs (not plaintext passwords)
- [ ] Enable SSL for external connector communication
- [ ] Monitor connector logs for unauthorized access

#### ClickHouse

- [ ] Change default user password immediately
- [ ] Create restricted users for BI (SELECT only)
- [ ] Enable query logging (`log_queries=1`)
- [ ] Set memory/CPU quotas per user
- [ ] Regular backups to S3/object storage

#### MySQL

- [ ] Replication user has minimal privileges
- [ ] Enable SSL/TLS for connections
- [ ] Whitelist VPS IP in DO firewall
- [ ] Rotate replication password quarterly
- [ ] Monitor access logs for anomalies

### Network Security

- [ ] VPS accessible only via VPN or your IP
- [ ] All internal communication on localhost
- [ ] No services bound to 0.0.0.0 except required
- [ ] Regular port scans to verify no unexpected ports
- [ ] Monitor failed login attempts

### Secrets Management

- [ ] `.env` file gitignored (never commit)
- [ ] Secrets rotated every 90 days
- [ ] Use environment variables in Docker Compose
- [ ] Consider HashiCorp Vault for production
- [ ] Document all credentials in secure vault (1Password, etc.)

### Monitoring & Alerting

- [ ] Set up alerts for failed logins
- [ ] Monitor disk space (alert at 70%)
- [ ] Track consumer lag (alert if >1 min)
- [ ] Log all connector restarts
- [ ] Alert on DLQ message growth

---

## Access Control Matrix

| User/Service | Redpanda | Kafka Connect | ClickHouse | MySQL | Console |
|--------------|----------|---------------|------------|-------|---------|
| **Debezium Connector** | Produce | - | - | Read (binlog) | - |
| **ClickHouse Sink** | Consume | - | Write | - | - |
| **Power BI** | - | - | Read | - | - |
| **Admin (You)** | Full | Full | Full | Full (via admin user) | Full |
| **BI Users** | - | - | Read (via restricted user) | - | - |
| **Monitoring** | Read (metrics) | Read (status) | Read (system tables) | - | Read |

---

## SSL/TLS Configuration (Optional)

### When to Enable TLS

**Pros**:
- ✅ Encrypted data in transit
- ✅ Required for compliance (PCI-DSS, HIPAA)
- ✅ Protects against MITM attacks

**Cons**:
- ⚠️ 10-30% throughput reduction
- ⚠️ More complex configuration
- ⚠️ Certificate management overhead

**Recommendation**: Enable for production if handling sensitive data; skip for development to maximize throughput.

### Redpanda TLS

```yaml
environment:
  REDPANDA_KAFKA_TLS_ENABLED: "true"
  REDPANDA_KAFKA_TLS_CERT: "/etc/redpanda/certs/broker.crt"
  REDPANDA_KAFKA_TLS_KEY: "/etc/redpanda/certs/broker.key"
volumes:
  - ./certs:/etc/redpanda/certs
```

### ClickHouse TLS

```xml
<!-- /etc/clickhouse-server/config.d/ssl.xml -->
<clickhouse>
    <openSSL>
        <server>
            <certificateFile>/etc/clickhouse-server/server.crt</certificateFile>
            <privateKeyFile>/etc/clickhouse-server/server.key</privateKeyFile>
        </server>
    </openSSL>
    <https_port>8443</https_port>
    <tcp_port_secure>9440</tcp_port_secure>
</clickhouse>
```

---

## Incident Response Plan

### Unauthorized Access Detected

1. **Immediate Actions**:
   - Block offending IP in firewall
   - Rotate all passwords
   - Review access logs
   - Check for data exfiltration

2. **Investigation**:
   - Identify attack vector (brute force, credential leak, etc.)
   - Assess damage (data accessed, modified, deleted)
   - Document timeline

3. **Remediation**:
   - Patch vulnerability
   - Strengthen authentication
   - Enable additional monitoring

### Data Breach

1. **Contain**:
   - Isolate affected systems
   - Disable compromised credentials
   - Preserve logs for forensics

2. **Assess**:
   - What data was accessed?
   - For how long?
   - Who was affected?

3. **Notify**:
   - Internal stakeholders
   - Affected users (if required)
   - Regulatory bodies (GDPR, etc.)

---

## Regular Security Audits

### Weekly

- [ ] Review failed login attempts
- [ ] Check DLQ for suspicious messages
- [ ] Verify firewall rules are active

### Monthly

- [ ] Update all Docker images
- [ ] Review user access logs
- [ ] Test backup restoration
- [ ] Scan for vulnerabilities (nmap, OpenVAS)

### Quarterly

- [ ] Rotate all passwords and keys
- [ ] Review and update firewall rules
- [ ] Penetration testing (if budget allows)
- [ ] Disaster recovery drill

---

## Compliance Considerations

### GDPR (if applicable)

- [ ] Implement data retention policies
- [ ] Enable right to erasure (DELETE mutations)
- [ ] Log all data access
- [ ] Encrypt data at rest and in transit

### PCI-DSS (if handling payment data)

- [ ] TLS required for all connections
- [ ] Quarterly vulnerability scans
- [ ] Restrict access to cardholder data
- [ ] Strong access control (2FA recommended)

### SOC 2 (for SaaS)

- [ ] Audit logging enabled
- [ ] Access reviews quarterly
- [ ] Incident response plan documented
- [ ] Change management process

---

## Security Tools & Resources

### Recommended Tools

1. **Fail2Ban**: Block IPs after failed login attempts
2. **Lynis**: Security auditing tool for Linux
3. **OpenVAS**: Vulnerability scanner
4. **OSSEC**: Host-based intrusion detection
5. **Auditd**: Linux audit framework

### Installation (CentOS)

```bash
# Fail2Ban
yum install epel-release -y
yum install fail2ban -y
systemctl enable fail2ban
systemctl start fail2ban

# Lynis
yum install lynis -y
lynis audit system

# Auditd
yum install audit -y
systemctl enable auditd
systemctl start auditd
```

---

## Next Steps

1. **Review this document** and customize for your environment
2. **Run Phase 1 validation scripts** to verify current state
3. **Configure firewall** before deploying services (Phase 2)
4. **Generate strong passwords** and store in `.env`
5. **Document your IP addresses** for whitelist
6. **Plan monitoring** (Phase 4)

---

## Emergency Contacts

| Role | Name | Contact | Availability |
|------|------|---------|--------------|
| VPS Admin | - | - | - |
| MySQL Admin (DO) | - | - | - |
| Security Lead | - | - | - |
| On-Call Eng | - | - | 24/7 |

---

**Document Version**: 1.0
**Last Updated**: Phase 1
**Classification**: Internal Use Only

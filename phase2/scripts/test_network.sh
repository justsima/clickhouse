#!/bin/bash
# Network connectivity diagnostics

echo "=========================================="
echo "   Network Connectivity Test"
echo "=========================================="
echo ""

echo "1. Testing from Kafka Connect to ClickHouse (port 9000)"
echo "--------------------------------------------------------"
echo "Using nc (netcat):"
docker exec kafka-connect-clickhouse nc -zv clickhouse 9000 2>&1 || echo "nc test failed"

echo ""
echo "Using telnet:"
docker exec kafka-connect-clickhouse bash -c "timeout 5 telnet clickhouse 9000" 2>&1 | head -5 || echo "telnet test failed"

echo ""
echo "Using curl to ClickHouse HTTP (port 8123):"
docker exec kafka-connect-clickhouse curl -s http://clickhouse:8123/ping 2>&1

echo ""
echo "2. DNS Resolution Test"
echo "----------------------"
echo "Resolving 'clickhouse' hostname from kafka-connect:"
docker exec kafka-connect-clickhouse getent hosts clickhouse 2>&1 || docker exec kafka-connect-clickhouse nslookup clickhouse 2>&1

echo ""
echo "3. Network Info"
echo "---------------"
echo "Kafka Connect container network:"
docker inspect kafka-connect-clickhouse -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}: {{$value.IPAddress}}{{end}}'

echo ""
echo "ClickHouse container network:"
docker inspect clickhouse-server -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}: {{$value.IPAddress}}{{end}}'

echo ""
echo "4. Port Listening Test"
echo "----------------------"
echo "Ports ClickHouse is listening on:"
docker exec clickhouse-server netstat -tlnp 2>/dev/null | grep clickhouse || \
docker exec clickhouse-server ss -tlnp 2>/dev/null | grep clickhouse || \
echo "netstat/ss not available, checking with lsof..."
docker exec clickhouse-server lsof -i -P -n 2>/dev/null | grep LISTEN || echo "Unable to check ports"

echo ""
echo "5. Firewall Rules (inside containers)"
echo "-------------------------------------"
echo "ClickHouse container iptables:"
docker exec clickhouse-server iptables -L -n 2>&1 | head -10 || echo "iptables not available (normal for containers)"

echo ""
echo "=========================================="

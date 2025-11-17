#!/bin/bash
# Test ClickHouse authentication from VPS

echo "Testing ClickHouse Authentication"
echo "=================================="
echo ""

PASSWORD="ClickHouse_Secure_Pass_2024!"

echo "1. Testing with curl (should work):"
echo "-----------------------------------"
curl -u "default:${PASSWORD}" "http://localhost:8123/?query=SELECT version()"
echo ""
echo ""

echo "2. Testing SHOW DATABASES:"
echo "-------------------------"
curl -u "default:${PASSWORD}" "http://localhost:8123/?query=SHOW DATABASES"
echo ""
echo ""

echo "3. Testing SELECT from system table:"
echo "------------------------------------"
curl -u "default:${PASSWORD}" "http://localhost:8123/?query=SELECT name FROM system.databases"
echo ""
echo ""

echo "4. For browser access, use URL-encoded password:"
echo "------------------------------------------------"
echo "The ! character needs to be encoded as %21"
echo ""
echo "Try this URL in your browser:"
echo "http://default:ClickHouse_Secure_Pass_2024%21@localhost:8123/?query=SHOW%20DATABASES"
echo ""
echo "Or use X-ClickHouse headers instead:"
echo "Open browser developer tools and try a fetch request:"
cat <<'EOF'
fetch('http://localhost:8123/?query=SHOW DATABASES', {
  headers: {
    'X-ClickHouse-User': 'default',
    'X-ClickHouse-Key': 'ClickHouse_Secure_Pass_2024!'
  }
})
.then(r => r.text())
.then(console.log)
EOF
echo ""

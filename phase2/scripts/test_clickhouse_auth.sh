#!/bin/bash
# Test ClickHouse authentication from VPS

echo "Testing ClickHouse Authentication"
echo "=================================="
echo ""

PASSWORD="ClickHouse_Secure_Pass_2024!"

echo "1. Testing with curl (should work):"
echo "-----------------------------------"
curl -s -u "default:${PASSWORD}" "http://localhost:8123/?query=SELECT+version()"
echo ""
echo ""

echo "2. Testing SHOW DATABASES:"
echo "-------------------------"
curl -s -u "default:${PASSWORD}" "http://localhost:8123/?query=SHOW+DATABASES"
echo ""
echo ""

echo "3. Testing SELECT from system table:"
echo "------------------------------------"
curl -s -u "default:${PASSWORD}" "http://localhost:8123/?query=SELECT+name+FROM+system.databases"
echo ""
echo ""

echo "4. Testing analytics database tables:"
echo "-------------------------------------"
curl -s -u "default:${PASSWORD}" "http://localhost:8123/?query=SELECT+*+FROM+system.tables+WHERE+database='analytics'"
echo ""
echo ""

echo "5. For browser access, use URL-encoded password:"
echo "------------------------------------------------"
echo "The ! character needs to be encoded as %21"
echo ""
echo "Try these URLs in your browser:"
echo ""
echo "Show databases:"
echo "  http://default:ClickHouse_Secure_Pass_2024%21@localhost:8123/?query=SHOW+DATABASES"
echo ""
echo "Get version:"
echo "  http://default:ClickHouse_Secure_Pass_2024%21@localhost:8123/?query=SELECT+version()"
echo ""
echo "Show analytics tables:"
echo "  http://default:ClickHouse_Secure_Pass_2024%21@localhost:8123/?query=SELECT+name+FROM+system.tables+WHERE+database='analytics'"
echo ""
echo ""
echo "Or use JavaScript in browser console (F12):"
echo "-------------------------------------------"
cat <<'EOF'
fetch('http://localhost:8123/?query=SHOW+DATABASES', {
  headers: {
    'X-ClickHouse-User': 'default',
    'X-ClickHouse-Key': 'ClickHouse_Secure_Pass_2024!'
  }
})
.then(r => r.text())
.then(console.log)
EOF
echo ""

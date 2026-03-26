#!/bin/bash
# Test UserAuthView, ApiParamView and ApiBodyView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
        echo "[FAIL] $desc — server error: $(echo "$result" | jq -r '.error')"
        ((fail++))
    elif echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
        count=$(echo "$result" | jq '.results[0].data | length')
        echo "[PASS] $desc — $count rows"
        ((pass++))
    else
        echo "[FAIL] $desc"
        echo "$result" | jq . 2>/dev/null || echo "$result"
        ((fail++))
    fi
}

echo "Starting go-cube server in background..."
./go-cube &
SERVER_PID=$!
sleep 2

echo ""
echo "Testing health endpoint..."
curl -s "$BASE/health" | jq .

echo ""
echo "========================================"
echo "=== UserAuthView queries ==="
echo "========================================"

echo ""
echo "=== 1. count+piiCount+loginId+loginTs+loginKey+loginReqInfo+loginResInfo by method+url+appName+loginTokenKey ==="
# measures: count, piiCount, loginId, loginTs, loginKey, loginReqInfo, loginResInfo
# dimensions: method, url, appName, loginTokenKey
# order: piiCount desc, count desc
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%2C%22UserAuthView.piiCount%22%2C%22UserAuthView.loginId%22%2C%22UserAuthView.loginTs%22%2C%22UserAuthView.loginKey%22%2C%22UserAuthView.loginReqInfo%22%2C%22UserAuthView.loginResInfo%22%5D%2C%22order%22%3A%7B%22UserAuthView.piiCount%22%3A%22desc%22%2C%22UserAuthView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.method%22%2C%22UserAuthView.url%22%2C%22UserAuthView.appName%22%2C%22UserAuthView.loginTokenKey%22%5D%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count+piiCount+loginId+loginTs+loginKey+loginReqInfo+loginResInfo by method+url+appName+loginTokenKey" "$result"

echo ""
echo "========================================"
echo "=== ApiParamView queries ==="
echo "========================================"

echo ""
echo "=== 2. ApiParamView key+path+rank limit 10 ==="
# dimensions: key, path, rank
# no measures, no timeDimensions, no filters
# limit: 10, segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiParamView.key%22%2C%22ApiParamView.path%22%2C%22ApiParamView.rank%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiParamView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiParamView: key+path+rank limit 10" "$result"

echo ""
echo "========================================"
echo "=== ApiBodyView queries ==="
echo "========================================"

echo ""
echo "=== 3. ApiBodyView ungrouped request+response, filter appName+urlRoute, order firstTs desc, limit 5 ==="
# ungrouped: true, no measures
# timeDimensions: ts (no dateRange)
# dimensions: request, response
# order: firstTs desc
# filters: appName equals [aa.com], urlRoute equals [/c/tailongsso/api/login]
# limit: 5, segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiBodyView.ts%22%7D%5D%2C%22order%22%3A%7B%22ApiBodyView.firstTs%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiBodyView.appName%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22aa.com%22%5D%7D%2C%7B%22member%22%3A%22ApiBodyView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2Fc%2Ftailongsso%2Fapi%2Flogin%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiBodyView.request%22%2C%22ApiBodyView.response%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiBodyView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiBodyView: ungrouped request+response filter appName+urlRoute order firstTs desc limit 5" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "All tests completed."

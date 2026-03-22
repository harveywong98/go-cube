#!/bin/bash
# Test AccessRawView queries against local go-cube server
# NOTE: uses access_raw (local dev); production uses access_raw_local

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
        echo "[FAIL] $desc — unexpected response: $result"
        ((fail++))
    fi
}

echo "Building go-cube..."
# Swap access_raw_local -> access_raw for local testing, restore on exit
cp model/AccessRawView.yaml /tmp/AccessRawView_prod.yaml
sed -i '' 's/access_raw_local/access_raw/' model/AccessRawView.yaml
trap 'cp /tmp/AccessRawView_prod.yaml model/AccessRawView.yaml' EXIT

go build -o go-cube . || { echo "Build failed"; exit 1; }

echo "Starting server..."
./go-cube &
SERVER_PID=$!
sleep 1

echo ""
echo "=== 1. ungrouped request+response (limit 1) ==="
# ungrouped: true, dimensions: request, response
# filters: id != '', segments: org, black
# mirrors the original query from dsp.servicewall.cn translated to AccessRawView
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessRawView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessRawView.id%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessRawView.request%22%2C%20%22AccessRawView.response%22%5D%2C%20%22limit%22%3A%201%2C%20%22segments%22%3A%20%5B%22AccessRawView.org%22%2C%20%22AccessRawView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "ungrouped request+response id!='' limit 1" "$result"

echo ""
echo "=== 2. ungrouped id+ts+url+gorId+fileContent (limit 5) ==="
# ungrouped: true, dimensions: id, ts, url, gorId, fileContent
# segments: org, limit 5
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessRawView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessRawView.id%22%2C%20%22AccessRawView.ts%22%2C%20%22AccessRawView.url%22%2C%20%22AccessRawView.gorId%22%2C%20%22AccessRawView.fileContent%22%5D%2C%20%22limit%22%3A%205%2C%20%22segments%22%3A%20%5B%22AccessRawView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "ungrouped id+ts+url+gorId+fileContent limit 5" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "All tests completed."

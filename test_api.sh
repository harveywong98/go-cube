#!/bin/bash
# Test ApiView queries — verifies {filter.ts} placeholder injection in subquery SQL

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
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
echo "========================================"
echo "=== ApiView queries ==="
echo "========================================"

echo ""
echo "=== 1. allCount with timeDimension (relative range) ==="
# {"measures":["ApiView.allCount"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"from 7 days ago to now"}],"segments":["ApiView.org"]}
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView.allCount with 7-day filter ({filter.ts} injection)" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

if [ $fail -gt 0 ]; then
    exit 1
fi

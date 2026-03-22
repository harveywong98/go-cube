#!/bin/bash
# Test ApiWeakView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    # Fail if the response contains a top-level error field
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
echo "=== ApiWeakView aggregate queries ==="
echo "========================================"

echo ""
echo "=== 1. 弱点概览: riskCount+levelCount+firstCategoryCount+owaspCategoryCount+manageCount+categoryCount (today) ==="
# measures: riskCount, levelCount, firstCategoryCount, owaspCategoryCount, manageCount, categoryCount
# timeDimensions: ApiWeakView.last, dateRange: today
# segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiWeakView.riskCount%22%2C%22ApiWeakView.levelCount%22%2C%22ApiWeakView.firstCategoryCount%22%2C%22ApiWeakView.owaspCategoryCount%22%2C%22ApiWeakView.manageCount%22%2C%22ApiWeakView.categoryCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiWeakView.last%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiWeakView.org%22%2C%22ApiWeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "弱点概览 riskCount+levelCount+firstCategoryCount+owaspCategoryCount+manageCount+categoryCount" "$result"

echo ""
echo "=== 2. 高危弱点数: riskCount (tag in [first,repeated], weakLevel != 低危害) ==="
# measures: riskCount
# timeDimensions: ApiWeakView.last, dateRange: today
# filters: tag equals [first, repeated], weakLevel notEquals [低危害]
# segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiWeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiWeakView.last%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiWeakView.tag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22first%22%2C%22repeated%22%5D%7D%2C%7B%22member%22%3A%22ApiWeakView.weakLevel%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E4%BD%8E%E5%8D%B1%E5%AE%B3%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiWeakView.org%22%2C%22ApiWeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "高危弱点数 riskCount (tag in [first,repeated] & weakLevel != 低危害)" "$result"

echo ""
echo "=== 3. 弱点明细列表: ungrouped, 15 dims, tag in [first,repeated] & weakLevel != 低危害, order weakScore desc+last desc, limit 20 ==="
# ungrouped: true, no measures
# dimensions: defectId, urlRoute, weakLevel, firstCategory, first, last, channel, host, count,
#             topoNetwork, respSensTagSet, method, manageId, tag, weakScore
# order: weakScore desc, last desc
# filters: tag equals [first, repeated], weakLevel notEquals [低危害]
# limit: 20, offset: 0, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiWeakView.last%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22ApiWeakView.weakScore%22%3A%22desc%22%2C%22ApiWeakView.last%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiWeakView.tag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22first%22%2C%22repeated%22%5D%7D%2C%7B%22member%22%3A%22ApiWeakView.weakLevel%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E4%BD%8E%E5%8D%B1%E5%AE%B3%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiWeakView.defectId%22%2C%22ApiWeakView.urlRoute%22%2C%22ApiWeakView.weakLevel%22%2C%22ApiWeakView.firstCategory%22%2C%22ApiWeakView.first%22%2C%22ApiWeakView.last%22%2C%22ApiWeakView.channel%22%2C%22ApiWeakView.host%22%2C%22ApiWeakView.count%22%2C%22ApiWeakView.topoNetwork%22%2C%22ApiWeakView.respSensTagSet%22%2C%22ApiWeakView.method%22%2C%22ApiWeakView.manageId%22%2C%22ApiWeakView.tag%22%2C%22ApiWeakView.weakScore%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22ApiWeakView.org%22%2C%22ApiWeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "弱点明细列表 ungrouped 15 dims order weakScore+last desc limit 20" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "All tests completed."

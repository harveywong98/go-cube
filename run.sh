#!/bin/bash

# 构建项目
echo "Building go-cube..."
go build -o go-cube .

# 检查ClickHouse连接
echo "Checking ClickHouse connection..."
if ! curl -s http://localhost:8123/ping > /dev/null 2>&1; then
    echo "Warning: ClickHouse may not be running on localhost:8123"
    echo "Please update config.yaml with correct ClickHouse settings"
fi

# 启动服务
echo "Starting go-cube server on port 4000..."
echo "Health check: curl http://localhost:4000/health"
echo "Sample query: curl 'http://localhost:4000/load?query=%7B%22dimensions%22%3A%5B%22AccessView.id%22%5D%2C%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22limit%22%3A5%7D'"
echo ""
./go-cube
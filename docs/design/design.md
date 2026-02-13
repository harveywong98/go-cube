# 数据溯源平台 - 前端设计文档

## 项目概述
Sheikah AI 驱动的数据溯源平台,通过 IDE 风格界面展示访问记录、敏感数据和文件传输的追溯信息。

## 技术栈选择

### 后端
- **语言**: Go
- **端口**: 4000
- **API**: Cube.js 兼容 (`/load`)
- **数据库**: ClickHouse (`default.access` 表)

### 前端
- **框架**: Vanilla JavaScript (零构建)
- **样式**: TailwindCSS (CDN)
- **图标**: Font Awesome (CDN)
- **部署**: 与后端同端口,由 Go 静态文件服务器提供

## 架构设计

### 文件结构
```
go-cube/
├── docs/design/
│   └── design.md              # 本文档
├── static/
│   ├── index.html            # 主页面
│   ├── js/
│   │   ├── cube-client.js    # Cube API 客户端
│   │   ├── query-builder.js  # 查询构建器
│   │   └── table-renderer.js # 表格渲染器
│   └── css/
│       └── (可选) 额外样式
├── main.go                   # 入口,添加静态文件服务
└── models/
    └── AccessView.yaml       # 数据模型定义
```

### 数据流
```
用户操作(过滤条件)
    ↓
query-builder.js → 生成查询参数
    ↓
cube-client.js → GET /load?query={...}
    ↓
Go Backend → 查询 ClickHouse
    ↓
返回 JSON { results: [{ data: [...] }] }
    ↓
table-renderer.js → 渲染到 DOM
```

## 页面布局

### 三栏布局
- **左侧**: 查询条件面板 (可折叠)
  - 时间范围选择器
  - 处理结果过滤 (保护/放行)
  - 执行查询按钮

- **中间**: 数据表格 (主视图)
  - Tab 切换: 访问记录 / 敏感数据 / 文件传输
  - 表格列: 时间、IP、方法、域名、URL、状态、处理结果、命中规则
  - 可展开行显示详细信息

- **右侧**: AI 智能分析面板 (可折叠)
  - 异常发现提示
  - AI 建议

### 样式规范
- **主题**: 深色 IDE 风格
- **背景色**: `#0d1117`
- **边框色**: `#30363d`
- **文字色**: `#d1d5db`
- **字体大小**: 12px (默认), 11px (表格), 10px (标签)
- **字体**: Inter / Microsoft YaHei (中文) + JetBrains Mono (代码)

## 组件设计

### 1. CubeClient (cube-client.js)
封装 Cube.js API 调用:

```javascript
class CubeClient {
  async query(cubeQuery) // 通用查询
  async getAccessRecords({ timeRange, resultFilters, limit }) // 访问记录查询
}
```

**API 请求示例**:
```json
{
  "dimensions": [
    "AccessView.ts",
    "AccessView.ip",
    "AccessView.ipGeoCity",
    "AccessView.method",
    "AccessView.host",
    "AccessView.url",
    "AccessView.assetName",
    "AccessView.status",
    "AccessView.resultType",
    "AccessView.resultRisk"
  ],
  "filters": [{
    "member": "AccessView.resultType",
    "operator": "equals",
    "values": ["保护", "放行"]
  }],
  "timeDimensions": [{
    "dimension": "AccessView.ts",
    "dateRange": "from 15 minutes ago to now"
  }],
  "limit": 100
}
```

### 2. QueryBuilder (query-builder.js)
从 UI 收集过滤条件:

```javascript
class QueryBuilder {
  readFromUI() // 读取 DOM 元素值
  build() // 返回查询参数对象
}
```

**支持的过滤条件 (第一版)**:
- 时间范围: 最近15分钟 / 最近1小时 / 最近24小时
- 处理结果: 保护 (checkbox) / 放行 (checkbox)

### 3. TableRenderer (table-renderer.js)
渲染数据到表格:

```javascript
class TableRenderer {
  clear() // 清空表格
  renderAccessRecords(records) // 渲染访问记录
  createAccessRow(rec, idx) // 创建单行 HTML
}
```

**表格列映射**:
| 显示列 | Cube 维度 | 说明 |
|--------|----------|------|
| 时间 | `AccessView.ts` | 格式化 HH:MM:SS |
| IP & 城市 | `ip`, `ipGeoCity` | 显示 IP + 地理位置 |
| 方法 | `method` | GET/POST/PUT 带颜色标签 |
| 域名 | `host` | 请求的 Host |
| URL & 业务 | `url`, `assetName` | URL 路径 + 业务分类 |
| 状态 | `status` | HTTP 状态码 |
| 处理结果 | `resultType` | 保护(红)/放行(绿) |
| 命中规则 | `resultRisk` | 风险规则标签 |

## 实现阶段

### Phase 1: 基础框架 (已完成)
- ✅ 设计 UI 原型 (trace_explorer_tabs.html)
- ✅ 实现 Cube.js 兼容后端
- ✅ 定义 AccessView 数据模型

### Phase 2: 静态文件服务 (当前)
- [ ] 修改 main.go 添加 `/static` 路由
- [ ] 创建 static/ 目录结构
- [ ] 复制原型 HTML 并添加 ID

### Phase 3: API 客户端 (当前)
- [ ] 实现 cube-client.js
- [ ] 实现 query-builder.js
- [ ] 实现 table-renderer.js

### Phase 4: 集成与测试 (当前)
- [ ] 连接按钮点击事件
- [ ] 测试数据流完整流程
- [ ] 添加错误处理和空状态

## API 响应示例

### 成功响应
```json
{
  "queryType": "regularQuery",
  "results": [{
    "query": { /* 原始查询 */ },
    "data": [
      {
        "AccessView.ts": "2024-02-07T14:23:45.122Z",
        "AccessView.ip": "1.2.3.4",
        "AccessView.ipGeoCity": "北京",
        "AccessView.method": "POST",
        "AccessView.host": "api.sheikah.com",
        "AccessView.url": "/v1/payment/create",
        "AccessView.assetName": "核心支付",
        "AccessView.status": "403",
        "AccessView.resultType": "保护",
        "AccessView.resultRisk": "SQL_Inject"
      }
    ]
  }]
}
```

## 错误处理

### 场景与处理
| 场景 | 处理方式 | UI 展示 |
|------|---------|---------|
| 网络错误 | try/catch + alert | 弹出提示: "网络连接失败" |
| API 500 | catch error | 弹出提示: "服务器错误" |
| 空数据 | 检查 records.length | 显示 "没有找到匹配的记录" |
| 字段缺失 | 使用默认值 `-` | 表格显示 `-` |

## 性能考虑

### 前端优化
- 使用虚拟滚动处理大量数据 (待实现)
- 分页加载 (limit 参数)
- 防抖处理搜索输入 (待实现)

### 后端优化
- ClickHouse 天然适合时序数据查询
- 合理使用索引和分区
- 限制单次查询 limit (默认 100,最大 1000)

## 未来扩展

### Tab 2: 敏感数据
- 维度: `sensScore`, `resSensKeyNum`
- 功能: 敏感数据类型分布, 敏感得分统计

### Tab 3: 文件传输
- 维度: `reqAction`, `reqContentLength`
- 功能: 上传/下载监控, 文件大小统计

### 高级过滤
- IP 地址范围过滤
- 用户 ID 精确匹配
- URL 正则匹配
- 风险等级滑块

### AI 集成
- 异常检测提示
- 自动建议处置方案
- 自然语言查询

## 参考文档

- [Cube.js REST API](https://cube.dev/docs/reference/rest-api)
- [ClickHouse SQL 语法](https://clickhouse.com/docs/en/sql-reference)
- [TailwindCSS 文档](https://tailwindcss.com/docs)
- [Font Awesome Icons](https://fontawesome.com/icons)

---

**文档版本**: v1.0  
**创建日期**: 2024-02-07  
**作者**: Sheikah Team

# 删除 Builder 自动 PREWHERE 路由 Spec

## 背景

当前 `BuildQuery` 会在 Go 层主动决定一部分条件进入 `PREWHERE`、另一部分进入 `WHERE`。

这套自动路由逻辑已经被测试证明不稳定：

- `AccessView` 已测查询中，`WHERE(all)` 明显优于自动 `PREWHERE` 路由
- `ApiDayView` 已测查询中，现状路径 `PREWHERE(org+black) + WHERE(dt)` 会明显退化，甚至超时
- `ApiDayView` 的问题主因不是 `toDateTime(dt)`，而是 builder 对条件层级的自动分配

因此本次改动不再让 builder 充当“轻量优化器”，改为只负责 SQL 语义拼接，把条件统一放入 `WHERE`，交给 ClickHouse 优化器自行决定执行策略。

## 目标

删除 `BuildQuery` 自动生成 `PREWHERE` 的逻辑：

- `segments` 不再路由到 `PREWHERE`
- `timeDimensions` 不再路由到 `PREWHERE`
- builder 不再维护“哪些条件适合 PREWHERE”的规则

保留以下现有语义：

- `filters` 中 dimension 字段仍进入 `WHERE`
- `filters` 中 measure 字段仍进入 `HAVING`
- 子查询内 `{filter.<field>}` 占位符替换逻辑保持不变
- cube 自身 `sql` / `sql_table` 中显式写死的 `PREWHERE` 不做重写或拦截

## 非目标

- 不修改 schema 中已有的 `sql`、`sql_table` 定义
- 不移除模型文件里手写的 `PREWHERE`
- 不改变时间范围表达式生成逻辑
- 不引入新的配置化路由策略
- 不针对单个 cube 增加例外优化
- 不基于 `WHERE` 条件书写顺序做额外优化

## 设计决策

### 1. Builder 默认只生成 WHERE / HAVING

`BuildQuery` 中不再收集 builder 级别的 `prewhere` 条件列表。

以下来源统一进入 `WHERE`：

- `segments`
- `timeDimensions`
- dimension filters

以下来源继续进入 `HAVING`：

- measure filters

### 2. 显式 PREWHERE 仍然允许存在

如果 cube 的 `sql` 本身是：

```sql
SELECT ... FROM t PREWHERE org = {vars.org}
```

builder 不对这段 SQL 做改写；它只是继续执行现有的 `{vars.xxx}` 和 `{filter.xxx}` 替换逻辑。

也就是说，本次删除的是“builder 自动追加 PREWHERE”，不是“系统内任何 PREWHERE 都不允许出现”。

### 3. 子查询占位符替换保持原样

子查询里的 `{filter.ts}` 仍需在 `timeDimensions` 循环中被替换成具体时间条件。

本次改动只影响外层子句路由：

- 外层不再生成 `PREWHERE`
- 外层时间条件统一写入 `WHERE`
- 内层 `{filter.xxx}` 替换逻辑不变

## 实现范围

### 代码

主要修改点：

- `api/query.go`

预期改动：

- 移除 builder 级 `prewhere` 条件收集
- 删除自动下推到 `PREWHERE` 的分支逻辑
- 删除与自动 `PREWHERE` 路由相关的辅助函数
- 保留最终 SQL 中 `WHERE` / `HAVING` 拼接逻辑

### 测试

需要修改现有依赖 `PREWHERE` 的断言，改为验证统一进入 `WHERE` 或保持显式 SQL 不变。

重点覆盖：

- `TestBuildQuery_Segments`
- `TestBuildQuery_BlackSegment`
- `TestBuildQuery_BlackSegmentEmpty`
- `TestBuildQuery_SegmentsOrgEmptyVar`
- `TestBuildQuery_TimeDimension_PhysicalTableToPrewhere`
- `TestBuildQuery_TimeDimension_SubqueryStaysInWhere`
- `TestRiskView_StatusFilter_Segment`
- 其他断言“segment 在 PREWHERE”的用例

需要新增或调整的验证方向：

- segment 条件进入 `WHERE`
- timeDimensions 条件进入 `WHERE`
- 空 vars 时不会生成非法 SQL
- 子查询 `{filter.xxx}` 替换仍然正确
- measure filter 仍然进入 `HAVING`
- cube 原始 SQL 中显式 `PREWHERE` 仍被保留

### 文档

需要同步更新：

- `docs/design/sql-builder.md`
- 删除或重写 `docs/design/time-prewhere-pushdown.md`

文档应明确：

- builder 不再自动生成 `PREWHERE`
- 当前默认策略是统一生成 `WHERE`
- 若模型 SQL 自带 `PREWHERE`，builder 不干预

## 验收标准

满足以下条件即可认为完成：

1. `BuildQuery` 不再因为 `segments` 或 `timeDimensions` 自动生成 `PREWHERE`
2. 已有测试全部通过，且断言已改成新的 `WHERE` 语义
3. 子查询 `{filter.xxx}` 替换不回归
4. 显式写在 cube SQL 中的 `PREWHERE` 仍原样保留
5. 设计文档不再描述“自动 PREWHERE 路由”或“timeDimensions 安全下推”

## 风险与取舍

本次改动是一次显式取舍：

- 收益：实现更简单，行为更稳定，不再依赖 builder 猜测 ClickHouse 的最优路由
- 代价：放弃个别已测查询中通过手工路由得到的局部最优表现

当前结论是这个取舍可接受，因为：

- `AccessView` 已测查询不支持自动 `PREWHERE`
- `ApiDayView` 已测查询的主要风险来自错误自动路由
- `WHERE(all)` 是更稳妥的默认行为

后续如果需要重新引入 `PREWHERE` 优化，应采用显式、可配置、可验证的方式，而不是恢复通用自动路由。

## 后续待验证事项

今天的测试已经验证了“条件分配到 `PREWHERE` 还是 `WHERE`”会影响性能，但**没有验证** `WHERE` 内多个条件的书写顺序是否会影响性能。

因此，下面这个判断目前只作为待验证假设，不纳入本次实现：

- 将命中排序键 / 主键的条件写在 `WHERE` 前部，是否会比写在后部更优

如需验证，应单独设计对照测试：

- 保持 SQL 语义完全一致，只交换 `WHERE` 中条件顺序
- 对比平均耗时、波动情况
- 结合 `EXPLAIN` / `system.query_log` 观察 `read_rows`、`read_bytes` 是否变化

在得到实测结果前，不应把“排序键条件写前面更好”写成本次改动的设计依据。

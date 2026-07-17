# Source and Query Strategy

> applicability: current_only
>
> load_when: `node_id == hotspot_research && mode in initial,same_policy_rerun,broaden_within_account_policy,manual_source_refresh,revalidation_after_reversal`

本文件只负责 current 热点研究的来源与查询策略，不定义 event merge、趋势结论、
风险评分或最终输出字段。

## Source planning

先从 current request 读取账号、快照、雷达策略、request mode、scope delta、
prior refs 和 manual-source refs。不得从聊天补范围。

来源按用途分层：

1. 权威/一手来源：政府、法院、监管、企业正式公告、交易所或原始数据，用于确认
   发生了什么和时间边界。
2. 独立二手来源：专业媒体、行业协会、可信研究或多家独立报道，用于交叉核验。
3. 传播信号来源：平台搜索、趋势工具、媒体聚合和公开讨论，用于观察传播，不替代
   事实证据。
4. 账号经验与用户输入：可形成查询线索或观点边界，不自动成为外部事实。

每条 source record 至少保留 URL/稳定定位、来源主体、发布时间、抓取时间、
来源类型、对应 claim、支持/反驳关系和查询 provenance。无法访问时诚实记为
`waiting_external` 或相应 propagation 状态，不得写成“没有相关信息”。

## Query expansion

从账号结构化词库、事件实体、地域、车型、交易链路、用户角色、风险模式和来源
关联词生成组合查询。扩词可自由探索，不逐词人工批准，但必须受账号 exclusions、
安全与合规边界约束。

记录 query effectiveness 与 term-selection ledger：

```text
run_count
signal_assist_count
candidate_assist_count
selected_candidate_assist_count
rejected_candidate_assist_count
last_hit_at
```

`preferred`：被选辅助次数至少 2 且多于被拒辅助次数。
`deprioritized`：被拒辅助次数至少 2 且多于被选辅助次数。
`blocked`：仅用于账号排除、安全/合规或用户明确封禁。

这些计数是偏好证据，不是单个词造成选题被采用的因果证明。

## Direct used-car priority

先建立“二手车直接相关且事实可核验”候选池。只有该池少于 3 条，才启用新车
外溢。每个外溢候选必须记录配置允许的 `spillover_proof`，说明它如何传导到
二手车价格、库存、渠道、残值、金融、售后、出口或消费者决策。

没有传导证明的新车新闻不能为了凑数进入账号候选池。达到三条并不要求最终一定
推荐三条；它只控制是否允许启动外溢检索。

## Request modes

- `initial`：按完整账号雷达策略建立本轮来源和查询计划。
- `same_policy_rerun`：沿用同一策略，刷新时间窗和来源状态，保留 prior refs。
- `broaden_within_account_policy`：只按 versioned scope delta 扩展，不越过账号禁区。
- `manual_source_refresh`：优先验证 request 绑定的 manual source input set，再补独立来源。
- `revalidation_after_reversal`：针对事实反转重新核验原 claim、来源时间线和传播状态；
  不复用旧结论伪装 current。

## Stop conditions

缺 current request、账号/策略绑定无效、scope delta 与模式冲突，或 external read
未完成时停止。不得临时扩大账号范围、伪造来源、提交 partial research set，或把
传播热度当作事实核验。

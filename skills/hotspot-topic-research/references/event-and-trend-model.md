# Event and Trend Model

> applicability: current_only
>
> load_when: `node_id == hotspot_research && status in event_merge_required,trend_comparison_required`

本文件负责 current `signal -> event -> candidate -> topic_option` 的对象边界、
事件归并与趋势快照，不定义来源池、风险表达或输出 Schema。

## Four-layer model

- `signal`：某来源在某时点、某查询下观察到的最小可复查信号。
- `event`：一条或多条信号归并后的现实事件，不等于已经适合账号表达。
- `candidate`：事件经过账号相关性、二手车优先、时效和可讲性判断后的候选。
- `topic_option`：可进入排序与面板投影的选题选项；只有后续人类决定才成为选中 topic。

保持稳定 ID。新来源报道同一事件时追加 evidence/source refs 和状态 revision，
不要因标题不同重新创建 event/candidate。

## Event merge

最低 event fingerprint：

```text
normalized_subject
core_action
event_time_window
location
vehicle_model_or_business_chain
```

标题相似、关键词重合和发布时间接近仅是辅助。主体、动作或关键业务链不同则保留
独立事件；同一事件的更正、反转和后续处置使用 revision / relation 连接，不能
静默覆盖旧证据。

## Snapshot comparability

趋势只比较同一口径的快照。至少核对：

```text
source_or_source_set
query_scope
geography
time_bucket
metric_definition
collection_method
policy_revision
```

任一关键口径变化则 `not_comparable`。一份快照只能写
`new_observation`；至少两份同口径快照后，才可根据变化与持续性写
`rising / sustained / cooling`。

没有平台数据或传播源受阻时，传播状态写 `unknown` 或
`blocked_external`，不能把新闻数量、个人体感或当前搜索排序伪装成确定趋势。

## Candidate projection

event 到 candidate 时记录账号相关性、服务对象、used-car directness、
spillover proof（如适用）、时效位置和可讲边界。candidate 到 topic option 时才
加入切口、预期受众价值、排序证据和可选性状态。

归并和投影不得删除原始 signal/source provenance。每个 current component 的
digest 都要进入 research set 的 `component_digest_map`，供 panel model 引用。

# Hotspot Topic Research Contract

> 状态：R8-H2 current 合同
>
> Skill contract version：`0.3.0`
>
> Runtime contract：`r7-hotspot-entry-v0.5+r5-radar-objects-v0.1`

## 1. Current responsibility

`hotspot-topic-research` 消费一个 current、ready 的
`hotspot_research_request`，完成来源发现与核验、事件归并、账号候选生成、
topic option 排序和证据封装，向 coordinator 提交一个完整
`hotspot_research_set`。

它不创建账号、不从聊天重建策略、不渲染面板、不记录人的选择，也不生成
selected source、Brief、文案、视觉或最终 HTML。下游固定为 deterministic
topic panel projector。

## 2. Version selection

Current 合同仅在 task envelope 属于 `hotspot_to_delivery_single_v0.6` 且
node 为 `hotspot_research` 时生效。R1/R5 standalone 或历史回放必须由
版本化 task/session 显式选择，并读取
`references/legacy-r1-r5-standalone.md`；聊天语气不能切换合同。

## 3. Input, output, and status

```yaml
primary_input:
  artifact_type: "hotspot_research_request"
  schema: "templates/schema/r7/hotspot-research-request.v0.1.schema.json"
  required_status: "ready"
primary_output:
  artifact_type: "hotspot_research_set"
  schema: "templates/schema/r7/hotspot-research-set.v0.1.schema.json"
  cardinality: "exactly_one_when_committed"
semantic_results:
  commit:
    - "research_ready_for_panel"
    - "research_ready_no_recommendation"
  no_partial_commit:
    - "waiting_external"
    - "blocked"
```

`ready_for_panel` 至少有一个可选 topic；完整检索后没有可选 topic 时提交
`ready_no_recommendation`。外部读取不完整时保留同一 task 的恢复证据，不得
提交 partial current set。

## 4. Stable business rules

- 二手车直接相关且事实可核验是硬优先。
- 该池少于三条才可启用新车外溢，每条外溢都必须有配置允许的二手车传导证明。
- 扩词可在账号边界内自由探索；被选择/拒绝计数仅调整偏好，不做逐词审批，
  也不宣称单词独占因果。
- 主对象为 `signal -> event -> candidate -> topic_option`。
- `rising / sustained / cooling` 至少需要两次同口径可比较快照。
- 事实、传播、风险、claim 证据、来源独立性、支持依据和允许表达分别判断；
  人类选择不升级事实结论。

具体方法只按 `SKILL.md` 中的机器条件加载三个 current references。历史
字段、旧账号补问、旧 Topic Gate 和 Markdown 输出只存在于 legacy reference
及其 asset，不覆盖 current。

## 5. Machine truth

字段、状态和 ownership 以以下机器资产为准：

```text
templates/schema/r7/hotspot-research-request.v0.1.schema.json
templates/schema/r7/hotspot-research-set.v0.1.schema.json
routes/component-catalog.json
routes/r7-semantic-task-registry.yaml
routes/r7-semantic-submission-registry.yaml
交接物字段词典.md
```

本文件不复制完整字段清单。Schema、node registry、submission validator 和
current fixture 的结论优先于历史 prose。

## 6. Failure and resume

- request 缺失、非 current、非 ready、Schema 不合法或绑定 hash 不一致：
  `blocked`，回到 request owner。
- 外部来源暂不可读：`waiting_external`，不提交 partial set。
- 中断恢复：先 reconcile current request、pending task、submission、
  attempts 和已有来源 outcome；依赖与 request revision 未变时复用同一 task。
- 范围、策略或事实发生实质变化：由上游产生新 request revision，不暗改旧请求。
- 缺事实、趋势或风险证据时不得用聊天记忆、当前时间或旧 topic card 补齐。

## 7. Acceptance

合格 current 输出必须同时满足：

1. 唯一输入和唯一输出合同成立。
2. component ID、digest、evidence、source 和 ledger 引用可追溯。
3. `panel_model` 只携带已计算的顺序/推荐，不在本 Skill 内渲染或修改。
4. semantic result 与 commit/no-commit 语义一致。
5. 禁止产物没有进入同一次 submission。
6. current R7 热点 fixture 与 R8-H2 渐进披露 fixture 通过。

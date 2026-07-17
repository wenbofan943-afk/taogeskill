# Legacy R1/R5 Standalone Hotspot Research

> applicability: historical_only
>
> load_when: `contract_version in r1,r5 && mode in legacy,replay`
>
> This file must never override the current R7 hotspot request/set contract.

## Historical scope

本 reference 只服务显式 R1/R5 standalone 或历史 session replay。旧流程由账号
档案与产品/活动对象开始，输出 research run、候选池、topic selection panel 和
topic card，并停在旧 Topic Gate。它不是 current R7 的 producer 合同。

历史执行可能包含：

```text
账号 P0 / 产品对象门禁与最多三问补充
三池热点雷达与 S/B/A/C/D 桥接
旧六项 0-2 评分
热点时效降级与 Topic Gate
Markdown panel / topic card
用户选题后转 content-brief-compiler
```

历史长输出模板位于
[`assets/legacy-standalone-output-template.md`](../assets/legacy-standalone-output-template.md)。
只有 replay 需要逐字段重现旧 Markdown 时才读取；current typed output 不加载。

## Historical prerequisites

旧 standalone 运行要求账号档案、产品或活动对象、来源计划和账号确认齐全。
缺失时停在旧账号补问，不得把该规则反向施加给已经持有 current
`hotspot_research_request` 的任务。

R5-H6 standalone 还要求先运行 account startup check。身份不一致进入显式迁移，
不能复用前账号；热点任务缺视觉身份只记 non-blocking。以上仅用于历史 replay，
current 账号/策略真源已经封装在 request refs 中。

## Historical object and scoring rules

R5 的二手车优先、外溢阈值、自由扩词、四层对象、快照趋势和证据分层仍被 current
保留，但 current 的具体执行入口在三个 current references 中。这里仅保留旧
standalone 的输出行为：

- 旧 producer 可同时生成 research run、candidate、panel 和 topic card。
- 候选用人群、母题、产品、情绪、风险、落地六项评分，每项 0-2。
- 桥接链可为 `A -> C -> D`、`B -> A -> C -> D` 或 `S -> B -> A -> C -> D`。
- 旧 Topic Gate 展示探索范围、漏斗、过滤原因、候选角色、推荐和选择代价。
- 用户选择后，旧 topic card 状态转为 `topic_selected_for_brief`。

这些多输出和状态改写在 current R7 中已经被 deterministic projector、decision
gate 和 selected-source compiler 分离，禁止移回 current Skill。

## Historical replay boundary

Replay 必须保持原 contract version、artifact path、status 和人类门禁语义。
不得把旧面板转换为 current set 后宣称 current regression 通过；也不得用 current
Schema 拒绝一份当时合法的历史 artifact。需要迁移时另建版本化 migration，不在
replay 中暗改。

# Evidence, Risk, and Scoring

> applicability: current_only
>
> load_when: `node_id == hotspot_research && status in candidate_scoring_required,risk_review_required`

本文件负责 current 候选的证据、风险、排序和允许表达，不定义查询扩展、事件
fingerprint 或最终面板渲染。

## Separate verdicts

必须分别记录：

- `fact_status`：`pending / verified / contested / unavailable`
- `propagation_status`：`unknown / observed / verified / blocked_external`
- `risk_level`：按名誉、金融、消费权益、安全、隐私等风险评估
- claim evidence status
- source independence status
- source support basis
- allowed expression

媒体报道不自动等于法律定论，传播量不等于事实成立，高风险也不等于事实为假。
人类选择只选择内容方向，不改变上述 verdict。

## Evidence sufficiency

claim 必须绑定实际 source records，并说明各来源支持、反驳或仅提供背景。
来源数量不等于独立性；转载、同稿分发和引用同一匿名消息源按同一证据链处理。

`assert_as_fact` 只有在 fact verified、claim supported、风险为 low/medium，
并且拥有 authoritative primary 或至少两条真正独立的 eligible secondary
支持时才允许。否则使用带来源归属、条件式表达、机制解释或等待核验。

争议信息要保留相反证据和时间线。事实反转必须新建 request/research revision，
不能把旧 claim 的 digest 改写后继续沿用。

## Ranking

排序服务于账号策略，不把所有维度压成一个不可解释总分。至少保留：

```text
account relevance
used-car directness / valid spillover
freshness and content position
evidence sufficiency
audience value
bridge quality
risk controllability
execution feasibility
novelty / duplication
```

事实不充分、硬蹭、账号禁区或不可控风险可以阻断可选性。热度高不能覆盖事实和
账号门禁；低热度也不自动淘汰直接服务买车用户、车商或卖车用户的高价值议题。

`panel_model` 保存已经计算的 ordered topic refs、recommended ref 和推荐理由。
本 Skill 不把评分再渲染成 Markdown 面板，也不在 projector 之后重排。

## No-recommendation and high risk

完整研究后没有满足可选条件的 topic option，应提交
`ready_no_recommendation`，而不是凑数。外部证据尚未完成则返回
`waiting_external`，两者不可混用。

高风险候选可以保留在 research set 中并标明风险与允许表达；是否可选由 current
合同和证据决定。即使用户后续选择，也不得把 `attribute_to_source` 改为
`assert_as_fact`。

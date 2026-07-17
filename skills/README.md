# Skills Index

> 状态：active_index
> 主责：让 AI 按业务阶段定位 Skill；具体执行以各目录 `SKILL.md` / `CONTRACT.md` 为准。

## 主链顺序

```text
propagation-router
-> semantic-workflow-coordinator（R7 typed task、热点 / 直供 producer adapter、freshness apply、两阶段 replan 与确定性提交）
-> account-onboarding（按需）
-> hotspot-topic-research（发现型入口）或 direct-content-intake（用户直供稿入口）
-> hotspot-topic-freshness-review（仅热点交付前复核；不改选题、不写 plan）
-> content-brief-compiler
-> 热点：short-video-structure-planner -> copywriting-draft-writer
-> 直供：copywriting-draft-writer(materialize_user_baseline) -> content-beat-mapper(semantic_only) -> short-video-structure-planner
-> content-beat-mapper(structure_bound)
-> spoken-script-review
-> talking-head-image-pip
   -> static-visual-director
   -> image-prompt-compiler（确定性 Prompt / postprocess 编译）-> image-asset-producer（基础图 / 派生图）
   -> visual-asset-reviewer（独立看 current raster）-> visual-asset-finalizer
   -> news-evidence-pip（来源证据截图）
-> copywriting-quality-review
-> platform-packaging-adapter
-> cover-design-compiler
-> final-delivery-builder -> delivery-visual-reviewer（final asset + HTML 双视口）-> business-delivery-acceptance
-> workflow-maturity-evaluator（只在认证运行中派生 session / route / project 证据）
```

## Skill 入口

| Skill | 主责 |
|---|---|
| [propagation-router](./propagation-router/SKILL.md) | 总控路由与入口判断 |
| [semantic-workflow-coordinator](./semantic-workflow-coordinator/SKILL.md) | 按 R7 蓝图生成唯一 task，绑定 producer payload Schema，并确定性构建 / 提交 submission |
| [account-onboarding](./account-onboarding/SKILL.md) | 首次账号建档 |
| [hotspot-topic-research](./hotspot-topic-research/SKILL.md) | 从版本化 request 生成单一 research set；来源/扩词、事件/趋势、证据/风险按 current 状态加载一层 reference，历史 standalone 单独隔离 |
| [hotspot-topic-freshness-review](./hotspot-topic-freshness-review/SKILL.md) | 热点交付前复核；区分 observation、material update、reversal 与 unassessed wait |
| [direct-content-intake](./direct-content-intake/SKILL.md) | 用户原稿登记、改写边界、主张地图和合法主链接入 |
| [hotspot-copywriting-research](./hotspot-copywriting-research/SKILL.md) | 旧研究入口 / 兼容路由，按其状态说明使用 |
| [content-brief-compiler](./content-brief-compiler/SKILL.md) | Topic → Brief |
| [short-video-structure-planner](./short-video-structure-planner/SKILL.md) | 新稿事前结构设计 / 直供稿现状结构诊断 |
| [copywriting-draft-writer](./copywriting-draft-writer/SKILL.md) | 直供 baseline、结构化新稿或授权 revision |
| [content-beat-mapper](./content-beat-mapper/SKILL.md) | 全文 UTF-8 节点映射与结构绑定 |
| [spoken-script-review](./spoken-script-review/SKILL.md) | 口播设计审查、追加式决策与 readiness |
| [talking-head-image-pip](./talking-head-image-pip/SKILL.md) | 图片资产子链编排 |
| [static-visual-director](./static-visual-director/SKILL.md) | 内容驱动视觉需求与静态编导 |
| [image-prompt-compiler](./image-prompt-compiler/SKILL.md) | typed 视觉 Brief → 确定性完整 Prompt 与后工程计划 |
| [image-asset-producer](./image-asset-producer/SKILL.md) | 图片生成、后处理和资产记录 |
| [visual-asset-reviewer](./visual-asset-reviewer/SKILL.md) | 独立查看 current raster 并输出八维 typed review；不修图 |
| [visual-asset-finalizer](./visual-asset-finalizer/SKILL.md) | 每个视觉任务唯一交付素材与 finalize 证据 |
| [news-evidence-pip](./news-evidence-pip/SKILL.md) | 新闻 / 数据 / 引语的来源捕获、绑定与确定性证据画中画 |
| [copywriting-quality-review](./copywriting-quality-review/SKILL.md) | 文案与视觉联合质检 |
| [platform-packaging-adapter](./platform-packaging-adapter/SKILL.md) | 多平台标题、描述、话题 |
| [cover-design-compiler](./cover-design-compiler/SKILL.md) | 封面设计、合成和专项质检 |
| [final-delivery-builder](./final-delivery-builder/SKILL.md) | current v0.9 业务优先 HTML、final asset binding 与技术 viewport；旧 v0.8 及更早只兼容回放 |
| [delivery-visual-reviewer](./delivery-visual-reviewer/SKILL.md) | 独立查看最终素材、HTML 与 desktop/mobile 证据；不改交付 |
| [business-delivery-acceptance](./business-delivery-acceptance/SKILL.md) | 对真实截图和图片做独立业务交付验收 |
| [workflow-maturity-evaluator](./workflow-maturity-evaluator/SKILL.md) | 冻结 capability 基线，从运行事实派生干预账本及三级成熟度证据；不自行宣称 L3 |

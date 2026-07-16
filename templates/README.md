# Templates Index

> 状态：active_index
> 主责：定位模板、Schema 和公开包骨架；模板不替代字段词典或 Skill 合同。

| 目录 | 用途 |
|---|---|
| [account/](./account/) | 账号与对象档案模板 |
| [account/visual-identity.template.yaml](./account/visual-identity.template.yaml) | R5 账号级视觉身份合同模板；只约束表达，不规定图片数量 |
| [account/column-visual-templates.template.yaml](./account/column-visual-templates.template.yaml) | R5 栏目视觉模板合同 |
| [account/account-topic-policy.template.yaml](./account/account-topic-policy.template.yaml) | R5-H2 账号级二手车优先雷达政策 |
| [account/query-lexicon.template.yaml](./account/query-lexicon.template.yaml) | R5-H2 可探索词库与选择反馈字段 |
| [account/account-session-snapshot.template.yaml](./account/account-session-snapshot.template.yaml) | R5-H5 历史 session 账号快照模板；只供兼容回放 |
| [account/account-identity-binding.template.json](./account/account-identity-binding.template.json) | R5-H6 账号技术身份绑定；绑定私有目录、展示名、策略、词库和摘要 |
| [account/account-session-snapshot.v0.2.template.yaml](./account/account-session-snapshot.v0.2.template.yaml) | R5-H6 当前 session 快照；只有已验证技术身份才允许下游读取 |
| [state/](./state/) | 本地状态和 session 状态模板 |
| [final-delivery/](./final-delivery/) | 最终 HTML 模板 |
| [schema/p0/typed-render-input.v0.5.schema.json](./schema/p0/typed-render-input.v0.5.schema.json) | 当前口播结构、全文视觉覆盖与最终 HTML typed input；v0.4 仅历史 replay |
| [schema/p0/session-execution-plan.v0.5.schema.json](./schema/p0/session-execution-plan.v0.5.schema.json) | P0 v0.5 版本钉住执行计划 |
| [schema/p0/session-execution-plan.v0.8.schema.json](./schema/p0/session-execution-plan.v0.8.schema.json) | R7-H6A 热点 v0.2 执行计划；直供 v0.2 继续钉住 v0.7 |
| [schema/p0/session-execution-plan.v0.9.schema.json](./schema/p0/session-execution-plan.v0.9.schema.json) | R7 v0.3 直供 / 热点 current plan；支持 human revision 分支、失效并集和显式 test profile |
| [schema/p0/compatibility-matrix.v0.5.json](./schema/p0/compatibility-matrix.v0.5.json) | P0 v0.1-v0.4 到 v0.5 的 replay / migration 边界 |
| [schema/r7/](./schema/r7/) | R7 蓝图 / 节点 / 注册表、task / submission、pointer / receipt、producer adapter 及 visual / asset / platform / cover payload |
| [schema/r7/compatibility-matrix.v0.2.json](./schema/r7/compatibility-matrix.v0.2.json) | R7-H6A 直供 v0.6 与热点 v0.8 前链 / H6B 交付待编译的版本边界 |
| [schema/r7/compatibility-matrix.v0.3.json](./schema/r7/compatibility-matrix.v0.3.json) | R7 current v0.3 / plan v0.9 / delivery v0.8 与旧 v0.2 replay 边界 |
| [schema/r7/compatibility-matrix.v0.4.json](./schema/r7/compatibility-matrix.v0.4.json) | R7 current v0.4 / plan v1.0 / delivery v0.9 与历史 replay 边界 |
| [schema/r7/delivery-revision-request.v0.1.schema.json](./schema/r7/delivery-revision-request.v0.1.schema.json) | 一次人工退回 1..N 修改项、最早重启节点和失效并集 |
| [schema/r7/hotspot-research-request.v0.1.schema.json](./schema/r7/hotspot-research-request.v0.1.schema.json) | 热点研究请求及五种互斥 request mode |
| [schema/r7/hotspot-research-set.v0.1.schema.json](./schema/r7/hotspot-research-set.v0.1.schema.json) | 单产物热点研究集合、组件 digest 与只读 panel model |
| [schema/r7/topic-selection-panel.v0.2.schema.json](./schema/r7/topic-selection-panel.v0.2.schema.json) | 确定性选题面板投影 |
| [schema/r7/topic-selection-decision.v0.1.schema.json](./schema/r7/topic-selection-decision.v0.1.schema.json) | 不可变 Topic Gate 决定与条件动作 |
| [schema/r7/selected-topic-source.v0.1.schema.json](./schema/r7/selected-topic-source.v0.1.schema.json) | 热点 Brief 的唯一选择来源包与 freshness policy |
| [schema/r7/topic-freshness-review.v0.1.schema.json](./schema/r7/topic-freshness-review.v0.1.schema.json) | 热点交付前复核、来源 attempt/delta 与 replacement evidence packet 合同 |
| [schema/final-delivery/typed-components.v0.6.schema.json](./schema/final-delivery/typed-components.v0.6.schema.json) | H4 确定性 candidate 外层、source map 与执行贡献合同 |
| [schema/final-delivery/typed-components.v0.7.schema.json](./schema/final-delivery/typed-components.v0.7.schema.json) | 热点 origin tagged union、17 类来源、freshness binding 与外部活动计数 |
| [schema/final-delivery/typed-components.v0.8.schema.json](./schema/final-delivery/typed-components.v0.8.schema.json) | historical source route transparency、revision context 与 v0.8 delivery candidate |
| [schema/final-delivery/typed-components.v0.9.schema.json](./schema/final-delivery/typed-components.v0.9.schema.json) | current H7 final-asset binding、业务信息架构与 v0.9 delivery candidate |
| [schema/r7/image-asset-set.v0.3.schema.json](./schema/r7/image-asset-set.v0.3.schema.json) | base / derived rendition / delivery asset 与 finalize 前状态合同 |
| [schema/r7/image-asset-delivery-set.v0.1.schema.json](./schema/r7/image-asset-delivery-set.v0.1.schema.json) | 显式 finalize 后的唯一交付素材集合 |
| [schema/r7/business-delivery-acceptance.v0.1.schema.json](./schema/r7/business-delivery-acceptance.v0.1.schema.json) | 技术 viewport 后的独立业务交付验收 |
| [schema/r7/maturity-baseline.v0.1.schema.json](./schema/r7/maturity-baseline.v0.1.schema.json) | R7-L3 同口径能力基线及 digest |
| [schema/r7/run-capability-snapshot.v0.1.schema.json](./schema/r7/run-capability-snapshot.v0.1.schema.json) | 每次认证运行开始前冻结的能力快照 |
| [schema/r7/autonomy-run-observation.v0.1.schema.json](./schema/r7/autonomy-run-observation.v0.1.schema.json) | session 结束时的 task / commit / attempt / gate / write 原始观察 |
| [schema/r7/intervention-ledger.v0.1.schema.json](./schema/r7/intervention-ledger.v0.1.schema.json) | 机器派生的未注册执行和 producer 越权账本 |
| [schema/r7/session-autonomy-evidence.v0.1.schema.json](./schema/r7/session-autonomy-evidence.v0.1.schema.json) | 单次 session 自治交付、等待、扶跑或失败证据 |
| [schema/r7/autonomy-certification-cohort.v0.1.schema.json](./schema/r7/autonomy-certification-cohort.v0.1.schema.json) | 运行前开启、只追加且不可挑样本的认证 cohort |
| [schema/r7/route-autonomy-evidence.v0.1.schema.json](./schema/r7/route-autonomy-evidence.v0.1.schema.json) | 直供 / 热点路线的连续成功与输入去重证据 |
| [schema/r7/project-maturity-evidence.v0.1.schema.json](./schema/r7/project-maturity-evidence.v0.1.schema.json) | 两条路线、能力覆盖和 current blocker 的项目成熟度证据 |
| [final-delivery/final-delivery.v0.9.business-fragment.html](./final-delivery/final-delivery.v0.9.business-fragment.html) | H7 业务主层优先、审计默认折叠的模板片段 |
| [final-delivery/final-delivery.v0.6.execution-fragment.html](./final-delivery/final-delivery.v0.6.execution-fragment.html) | H4 v0.6 执行透明度模板片段；与 v0.5 presentation base 组成版本化 template bundle |
| [final-delivery/final-delivery.v0.7.hotspot-fragment.html](./final-delivery/final-delivery.v0.7.hotspot-fragment.html) | 热点研究、人工选择、当前来源、时效复核和执行透明度片段 |
| [checker/](./checker/) | project / sample / release 报告模板 |
| [schema/](./schema/) | 字段、P0、R3 等机器可读 Schema |
| [schema/r5/account-visual-identity.v0.1.schema.json](./schema/r5/account-visual-identity.v0.1.schema.json) | R5-H1 账号视觉身份机器 Schema |
| [schema/r5/account-radar-policy.v0.1.schema.json](./schema/r5/account-radar-policy.v0.1.schema.json) | R5-H2 账号雷达政策机器 Schema |
| [schema/r5/account-startup-check.v0.1.schema.json](./schema/r5/account-startup-check.v0.1.schema.json) | R5-H5 账号启动检查、补问和快照决策机器 Schema |
| [schema/r5/account-session-snapshot.v0.1.schema.json](./schema/r5/account-session-snapshot.v0.1.schema.json) | R5-H5 session 账号快照机器 Schema |
| [schema/r5/account-identity-binding.v0.1.schema.json](./schema/r5/account-identity-binding.v0.1.schema.json) | R5-H6 账号身份绑定与资产摘要 Schema |
| [schema/r5/account-startup-check.v0.2.schema.json](./schema/r5/account-startup-check.v0.2.schema.json) | R5-H6 含身份硬门禁的启动检查 Schema |
| [schema/r5/account-session-snapshot.v0.2.schema.json](./schema/r5/account-session-snapshot.v0.2.schema.json) | R5-H6 已验证身份的 session 快照 Schema |
| [schema/r6/direct-content-intake.v0.1.schema.json](./schema/r6/direct-content-intake.v0.1.schema.json) | R6 用户直供稿、原稿 digest、改写边界、主张地图和路由 Schema |
| [schema/r6/content-brief.v0.3.schema.json](./schema/r6/content-brief.v0.3.schema.json) | R6 直供 / 热点来源身份分流后的 Brief Schema |
| [schema/r6/content-brief.v0.4.schema.json](./schema/r6/content-brief.v0.4.schema.json) | R7-H6A 热点 selected source tagged input；直供 v0.3 保持兼容 |
| [schema/r6/draft.v0.3.schema.json](./schema/r6/draft.v0.3.schema.json) | R6 直供 baseline、结构生成稿与决策修订稿 Schema；baseline 禁止静默改写 |
| [schema/r6/draft.v0.4.schema.json](./schema/r6/draft.v0.4.schema.json) | R7-H6A 热点只允许从 current structure 生成 Draft |
| [schema/r6/short-video-structure-plan.v0.1.schema.json](./schema/r6/short-video-structure-plan.v0.1.schema.json) | 短视频宏观推进结构、候选、阶段与授权状态 |
| [schema/r6/content-beat-map.v0.1.schema.json](./schema/r6/content-beat-map.v0.1.schema.json) | 全文 UTF-8 byte 锚点、结构阶段绑定和完整覆盖合同 |
| [schema/r3/visual-need-analysis.v0.4.schema.json](./schema/r3/visual-need-analysis.v0.4.schema.json) | R3 当前全文视觉需求分析和派发入口 |
| [schema/r3/visual-coverage-ledger.v0.1.schema.json](./schema/r3/visual-coverage-ledger.v0.1.schema.json) | 逐节点 disposition、视觉任务、插入次数和来源 / provider 分账 |
| [schema/r3/visual-need-analysis.v0.5.schema.json](./schema/r3/visual-need-analysis.v0.5.schema.json) | current 视觉需求与互斥来源路由入口 |
| [schema/r3/visual-coverage-ledger.v0.2.schema.json](./schema/r3/visual-coverage-ledger.v0.2.schema.json) | current 全文 coverage、来源分类与 test profile 分账 |
| [schema/r3/visual-source-routing.v0.1.schema.json](./schema/r3/visual-source-routing.v0.1.schema.json) | evidence / existing / generated 三类唯一分流 |
| [schema/r3/asset-reuse-authorization.v0.1.schema.json](./schema/r3/asset-reuse-authorization.v0.1.schema.json) | session / task / asset hash / account snapshot 级复用授权 |
| [schema/r3/visual-intent-decision.v0.1.schema.json](./schema/r3/visual-intent-decision.v0.1.schema.json) | H2 视觉必要性、价值与 no-visual 理由 |
| [schema/r3/visual-source-route-decision.v0.1.schema.json](./schema/r3/visual-source-route-decision.v0.1.schema.json) | H2 三类互斥来源路由与当前绑定 |
| [schema/r3/visual-prompt-brief.v0.1.schema.json](./schema/r3/visual-prompt-brief.v0.1.schema.json) | generated-context 语义 Brief |
| [schema/r3/visual-prompt-package.v0.1.schema.json](./schema/r3/visual-prompt-package.v0.1.schema.json) | 确定性 full prompt、digest 与 provider payload |
| [schema/r3/visual-postprocess-plan.v0.1.schema.json](./schema/r3/visual-postprocess-plan.v0.1.schema.json) | 版本化后工程 operation 计划 |
| [schema/r3/visual-asset-review.v0.1.schema.json](./schema/r3/visual-asset-review.v0.1.schema.json) | current raster 八维独立审查 |
| [schema/r3/delivery-visual-review.v0.1.schema.json](./schema/r3/delivery-visual-review.v0.1.schema.json) | final asset、HTML 与双视口独立审查 |
| [schema/r3/visual-semantic-work-package.v0.1.schema.json](./schema/r3/visual-semantic-work-package.v0.1.schema.json) | 五段视觉语义工作包、角色隔离与 registry digest |
| [schema/r6/source-capture-record.v0.1.schema.json](./schema/r6/source-capture-record.v0.1.schema.json) | R6 浏览器截图 attempt、失败证据、重试历史、输出 hash 与恢复状态 Schema |
| [schema/r6/news-evidence-pip.v0.1.schema.json](./schema/r6/news-evidence-pip.v0.1.schema.json) | R6 主张 / 来源 / 捕获 / binding / 证据 PIP 四层状态 Schema |
| [schema/r6/news-evidence-pip.v0.2.schema.json](./schema/r6/news-evidence-pip.v0.2.schema.json) | 证据锚点、跨层 typed fact 一致性和 OCR 视觉复核合同 |
| [schema/r3/visual-need-analysis.v0.3.schema.json](./schema/r3/visual-need-analysis.v0.3.schema.json) | R3 当前视觉需求 Schema；补 typed presentation、目标画布与 placement slot |
| [schema/r3/cover-render-plan.v0.1.schema.json](./schema/r3/cover-render-plan.v0.1.schema.json) | 平台独立封面 rendition、适配策略、保护区与预览 / 视觉审核路径 |
| [public-release/](./public-release/) | 公开候选包入口模板 |

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
| [schema/p0/compatibility-matrix.v0.5.json](./schema/p0/compatibility-matrix.v0.5.json) | P0 v0.1-v0.4 到 v0.5 的 replay / migration 边界 |
| [schema/r7/](./schema/r7/) | R7 蓝图 / 节点 / 注册表、task / submission、pointer / receipt、producer adapter 及 visual / asset / platform / cover payload |
| [schema/final-delivery/typed-components.v0.6.schema.json](./schema/final-delivery/typed-components.v0.6.schema.json) | H4 确定性 candidate 外层、source map 与执行贡献合同 |
| [final-delivery/final-delivery.v0.6.execution-fragment.html](./final-delivery/final-delivery.v0.6.execution-fragment.html) | H4 v0.6 执行透明度模板片段；与 v0.5 presentation base 组成版本化 template bundle |
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
| [schema/r6/draft.v0.3.schema.json](./schema/r6/draft.v0.3.schema.json) | R6 直供 baseline、结构生成稿与决策修订稿 Schema；baseline 禁止静默改写 |
| [schema/r6/short-video-structure-plan.v0.1.schema.json](./schema/r6/short-video-structure-plan.v0.1.schema.json) | 短视频宏观推进结构、候选、阶段与授权状态 |
| [schema/r6/content-beat-map.v0.1.schema.json](./schema/r6/content-beat-map.v0.1.schema.json) | 全文 UTF-8 byte 锚点、结构阶段绑定和完整覆盖合同 |
| [schema/r3/visual-need-analysis.v0.4.schema.json](./schema/r3/visual-need-analysis.v0.4.schema.json) | R3 当前全文视觉需求分析和派发入口 |
| [schema/r3/visual-coverage-ledger.v0.1.schema.json](./schema/r3/visual-coverage-ledger.v0.1.schema.json) | 逐节点 disposition、视觉任务、插入次数和来源 / provider 分账 |
| [schema/r6/source-capture-record.v0.1.schema.json](./schema/r6/source-capture-record.v0.1.schema.json) | R6 浏览器截图 attempt、失败证据、重试历史、输出 hash 与恢复状态 Schema |
| [schema/r6/news-evidence-pip.v0.1.schema.json](./schema/r6/news-evidence-pip.v0.1.schema.json) | R6 主张 / 来源 / 捕获 / binding / 证据 PIP 四层状态 Schema |
| [schema/r3/visual-need-analysis.v0.3.schema.json](./schema/r3/visual-need-analysis.v0.3.schema.json) | R3 当前视觉需求 Schema；补 typed presentation、目标画布与 placement slot |
| [schema/r3/cover-render-plan.v0.1.schema.json](./schema/r3/cover-render-plan.v0.1.schema.json) | 平台独立封面 rendition、适配策略、保护区与预览 / 视觉审核路径 |
| [public-release/](./public-release/) | 公开候选包入口模板 |

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
| [schema/p0/typed-render-input.v0.3.schema.json](./schema/p0/typed-render-input.v0.3.schema.json) | P0-H7 当前交付 revision typed input |
| [schema/p0/session-execution-plan.v0.3.schema.json](./schema/p0/session-execution-plan.v0.3.schema.json) | P0-H7 版本钉住执行计划 |
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
| [schema/r6/source-capture-record.v0.1.schema.json](./schema/r6/source-capture-record.v0.1.schema.json) | R6 浏览器截图 attempt、失败证据、重试历史、输出 hash 与恢复状态 Schema |
| [schema/r6/news-evidence-pip.v0.1.schema.json](./schema/r6/news-evidence-pip.v0.1.schema.json) | R6 主张 / 来源 / 捕获 / binding / 证据 PIP 四层状态 Schema |
| [schema/r3/visual-need-analysis.v0.2.schema.json](./schema/r3/visual-need-analysis.v0.2.schema.json) | R3-R6 当前视觉需求 Schema；按任务把生成情境图与来源证据图派给不同 producer |
| [public-release/](./public-release/) | 公开候选包入口模板 |

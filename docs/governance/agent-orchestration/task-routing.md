# Task Routing

> 状态：任务路由规则
> 主责：把用户口语意图映射到任务类型、必读文件、自动推进和人类门禁。
> 边界：本文件只管编排，不替代具体 skill 的 `SKILL.md` / `CONTRACT.md`。

---

## 总原则

```text
先判任务，再读规则。
先读当前任务必读文件，再决定是否需要扩展上下文。
能自动推进的不要让用户说“继续”。
需要人判断时，给推荐动作、原因和可直接回复的话。
任务完成后，按 `routes/workflow-routes.yaml` 的 `after_completion` 字段输出后置引导。
```

## 路由表

| 用户说法 | task_type | 必读 | 自动动作 | 人类门禁 |
|---|---|---|---|---|
| 做一篇内容 / 跑生产逻辑 | `content_run` | `AGENTS.md`、`PROJECT_MAP.md`、`工作流状态记录.md`、账号档案、产品 / 活动对象、相关 skill | 账号确认后按链路推进到最终 HTML | 换账号确认、选题选择、最终验收 |
| 新建账号 / 没账号 | `account_onboarding` | `skills/account-onboarding/SKILL.md`、`docs/reference/账号档案完整性检查表.md` | 口语化收集最小账号字段并落盘 | 账号档案确认 |
| 继续 / 接着上次 / 活了吗 | `resume_run` | `工作流状态记录.md`、`manifest.yaml`、checkpoint、execution trace | 判断可恢复点并说明从哪里继续 | 状态冲突或多 run 匹配 |
| 三篇都做 / 多个都跑 | `multi_branch_run` | `docs/reference/R2-运行模型执行规范.md`、parent / child manifest | 拆 child session、记录 branch ledger | 用户要求改变分支范围 |
| 改文案 / 加画中画 / 改标题 | `revision_run` | 当前 `final-delivery.html`、manifest、对应 intermediate | 局部返工，不默认重跑全链路 | 返工范围不清 |
| 导出日志 / 哪里不好用 | `support_log` | `docs/how-to/export-support-log.md`、`tools/export-support-log.ps1` | 自动选择最近 run 或按账号/选题筛选 | 是否包含内容细节 |
| 产品开发 / R1-R4 / P1-P5 | `product_definition` | 相关 `docs/product/`、路线图、问题包、AGENTS 门禁 | 做产品定义、审计、确认清单 | 产品定义进入 skill 编译前 |
| skill 编译 / 代码开发 | `skill_compile` | 对应产品定义、`CONTRACT.md`、`SKILL.md`、字段词典、validator | 编译、检查，并在原子范围可隔离时完成本地 commit 和小扫地 | 产品定义未确认；远端写入另行授权 |
| 测试 / dry-run | `test_run` | `examples/`、`docs/tutorials/`、`tools/README.md`、相关 checker | 只用脱敏样例和 fixtures | 测试范围改变 |
| 发版 / GitHub | `github_release` | `docs/governance/agent-orchestration/build-profiles.md`、`release-checklist.md`、`RELEASE_NOTES.md`、`tools/validate-release-gate.ps1` | 构建、校验、本地 release commit、远端发布、页面审计和小扫地 | push / tag / Release / repo metadata 等远端写入 |
| 调研成熟项目 / 对标 dbskill | `dependency_research` | `AGENTS.md`、`PROJECT_MAP.md`、目录规范、相关产品 / 方法论文档 | 调研、归纳成熟做法、沉淀依据和取舍 | 需要进入产品定义或编译前 |
| 隐私审计 / 污染检查 / source zip | `privacy_audit` | build profile、SECURITY、release validator、release gate | 扫真实账号、私有路径、token、source zip / release zip 边界 | 命中隐私或发布阻断 |
| git 对齐 / tag / Actions 排错 | `repo_maintenance` | 版本治理、release checklist、state-and-gates | 查本地远端、tag 语义、Actions、GitHub 页面状态；默认只读 | reset、push、tag、Release 或 API 写远端前；单独要求“提交”只授权本地闭环 |
| 构建测试包 / 离线包 | `package_distribution` | build profile、INSTALL、UPDATE、support log 说明、tools 合同 | 生成外部测试包或分发包，并附使用 / 反馈说明 | 包范围不清或包含真实数据 |
| 用户反馈 / issue / 问题包 | `issue_triage` | support log 说明、问题包、路线图、反馈日志 | 分类问题、复盘原因、沉淀改版资产 | 是否允许读取内容细节 |
| 目录治理 / 文档治理 | `docs_governance` | `docs/reference/文档治理与目录规范.md`、本目录、`PROJECT_MAP.md` | 盘点、迁移、修链接、跑检查 | 大规模迁移前后说明 |

## 手动模型选择

模型、推理强度和速度由用户在 Codex 前端手动选择；本项目只路由任务类型与必读规则，不自动切换运行档位。

## 失败路由

| 现象 | route_to | 处理 |
|---|---|---|
| 找不到账号 | `account_onboarding` | 引导新建或选择已有账号 |
| 找不到 session_id | `resume_run` | 用账号、选题、最近运行推断 |
| 用户要求多个选题一起跑 | `multi_branch_run` | 创建 parent / child，不在单链路硬跑 |
| Codex 不能出图 | `revision_run` / `content_run` | 交付统一图片提示词和插入位置 |
| GitHub token 不可用 | `github_release` | 检查进程 / User / Machine 环境变量和 scope |
| public 构建命中隐私 | `github_release` | 阻断发布，回到隐私边界修复 |
| GitHub Actions 红叉 | `repo_maintenance` | 拉取最新 run 和失败 step，不把红叉当小问题 |
| 用户发来 support log | `issue_triage` | 先分类问题，再决定进产品、skill、文档或发版修复 |
| 用户问“别人怎么做” | `dependency_research` | 调研成熟项目并标出可借鉴 / 不适合照搬的部分 |
| 用户没有明确说推送 / 发版 | 保持当前 task_type | `skill_compile` 等已授权原子开发通过检查后可默认本地 commit；不自动 push / tag / Release |
| 用户明确说“只改不提交” | 保持当前 task_type | 完成本地修改和检查，报告 diff，不创建 commit |
| 工作区混有无法安全拆分的旧改动 | 保持当前 task_type | 保留修改并报告 `blocked_by_mixed_worktree`，不得强行提交或清理用户改动 |

## 任务后导航

每个 task_type 的后置引导以 `routes/workflow-routes.yaml` 为机器真源，至少覆盖：

```text
成功后推荐下一步。
等待人类时可直接回复的话。
阻断后恢复路线。
是否允许自动继续。
```

如果用户已经明确表达下一步，例如“选 Txxx”“认可”“同意”“按你说的修”，不得再用泛化确认问题打断流程；直接按当前 route 的 `auto_continue_allowed` 和门禁执行。

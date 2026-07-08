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
| skill 编译 / 代码开发 | `skill_compile` | 对应产品定义、`CONTRACT.md`、`SKILL.md`、字段词典、validator | 编译并跑静态 / dry-run 检查 | 产品定义未确认 |
| 测试 / dry-run | `test_run` | `examples/`、`docs/tutorials/`、`tools/README.md`、相关 checker | 只用脱敏样例和 fixtures | 测试范围改变 |
| 发版 / GitHub | `github_release` | `docs/governance/agent-orchestration/build-profiles.md`、`release-checklist.md`、`RELEASE_NOTES.md`、`tools/validate-release-gate.ps1` | 构建、校验、审计、发布后小扫地 | commit / tag / push / Release |
| 目录治理 / 文档治理 | `docs_governance` | `docs/reference/文档治理与目录规范.md`、本目录、`PROJECT_MAP.md` | 盘点、迁移、修链接、跑检查 | 大规模迁移前后说明 |

## 失败路由

| 现象 | route_to | 处理 |
|---|---|---|
| 找不到账号 | `account_onboarding` | 引导新建或选择已有账号 |
| 找不到 session_id | `resume_run` | 用账号、选题、最近运行推断 |
| 用户要求多个选题一起跑 | `multi_branch_run` | 创建 parent / child，不在单链路硬跑 |
| Codex 不能出图 | `revision_run` / `content_run` | 交付统一图片提示词和插入位置 |
| GitHub token 不可用 | `github_release` | 检查进程 / User / Machine 环境变量和 scope |
| public 构建命中隐私 | `github_release` | 阻断发布，回到隐私边界修复 |

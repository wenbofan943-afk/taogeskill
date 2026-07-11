# 涛哥创作工作流 STATUS

> 当前状态卡。历史讨论不写成长流水；有价值的过程进入对应记录文件。

---

## 当前阶段

```text
project_stage：workflow_stabilization
workflow_usage_state：v0.1.0-alpha.2_github_prerelease_published
状态说明：R1-R4 产品定义、规则 / skill 编译、只读 checker、R3 generated 样本、真实 session-scope 检查、R0 首次账号建档、最终交付验收循环和 `0.1.0-alpha.2` public release 均已完成阶段性闭环。R3-C54 到 R3-C70 已完成视觉文字与封面质量编译，并完成编译后产品 / 主链复审：修复 final builder 循环输入、prompt-only 封面条件字段冲突、平台包装 lineage 丢失和教程仍由门面 Skill 代执行的问题；专项 checker 已增加 ID、状态、next_skill、trace 和最终 HTML 数据流检查。正确 run 目录只读回放 12 步通过、零警告；仍不能宣称真实账号综合效果已验收、L3 或生产级 workflow engine。
当前位置：D:\OpenClaw\workspace\涛哥创作工作流
Git：已初始化独立本地工作母仓，当前分支 `main`；远端为 `git@github.com:wenbofan943-afk/taogeskill.git`；GitHub 预发行 tag 为 `v0.1.0-alpha.2`；默认 Git 入口为 `D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe`
```

---

## 当前能力

已具备：

```text
账号档案
产品/活动对象档案规则
热点搜索来源池
调研运行记录
热点候选池
热点评分表
自媒体选题库
内容 Brief 记录
口播草案 skill
画中画提示词 skill
图片资产与最终 HTML 交付页规范
项目内交付页 / 可转交包 / 单文件 HTML 的边界规范
人类引导与任务后导航规范
文案与视觉联合质检 skill
多平台分发包装 skill
内容交付记录
最终交付页构建 skill
首次账号建档引导 skill
工作流状态记录
反馈日志包导出
```

---

## 当前边界

```text
不做自动发布。
不登录平台后台。
不自动评论、私信或互动。
不改公开互动分析工具客户端、服务器、数据库、license、积分或发版链路。
不替代短视频创作 SaaS 的正式工程实现。
```

---

## 当前待办

1. P0-H2 已把轻量 runtime 迁入 v0.2：`invoke-workflow-runtime.ps1` 能按版本分流，确定性执行 `compile_render_input -> render_final_delivery`，写 append-only event、render input / final_delivery lineage、artifact checks 和 render receipt；旧 v0.1 runtime 保持只读兼容。
2. P0-H1 至 P0-H5 已完成：H5 在全新私有 session 复用已验证内容与图片，重新生成 plan、4 条统一 events、19 份复制产物 lineage、typed render input、确定性 HTML、projection 与 resume；专项 checker 26/26，通过口径为 `pass_with_warnings`。本轮图片 provider 与发布调用均为 0；下一批 P0-H6 须先过人类授权与成本门禁。
3. `validate-workflow-replay.ps1` 继续只做历史 / sample 的 `trace_replay_readonly`，不执行 AI 写作、不联网、不生成图片；它与 P0 runtime 的真实确定性步骤执行边界必须分开描述。
4. E 批已完成最小 regression fixture：`examples/regression-suite.yaml` 和 `tools/validate-regression-suite.ps1` 已落地，`validate-public-release.ps1` 增加 `P3REL-009`，public_release 内 suite 返回 `pass_with_warnings` 且 release 检查退出码 0。
5. F 批已完成 validation-only CI 最小编译：`.github/workflows/public-release-candidate-check.yml` 和 `tools/validate-ci-workflow.ps1` 已落地，`validate-public-release.ps1` 增加 `P3REL-010`；当前只是本地和公开包静态检查通过，不自动 push / tag / release，也未实际运行远端 GitHub Actions。
6. G 批已完成 Alpha 体验表达：README / INSTALL / RELEASE_NOTES / examples 第一屏已强化 GitHub 预发行、非生产 runner、不可自动发布、样例验证范围等提醒；`tools/validate-alpha-expression.ps1` 已落地并接入 `P3REL-011`。
7. A-G 批已完成最小闭环；Release Gate 工具 `tools/validate-release-gate.ps1` 已落地，用于区分本地公开包通过和是否可以进入 commit / tag / remote / push / GitHub Release。发版产物已收敛到 `releases/v0.1.0-alpha.2/`，根目录不再保留 `public_release/`、zip、sha 或 release gate 报告。
8. GitHub Release `v0.1.0-alpha.2` 已发布为预发行版本；后续重点是外部试用反馈、support log 回收和下一版修复排序。
9. 图片质量检查需继续增强 prompt_alignment_score / retention_task_score，不只检查文件存在。
10. 后续调研 Seedream 4.0 / 5.0 等外部图片模型旁路；当前只保留降级策略说明，不实现 API。
11. 当前成熟度判断为 L2.8，已完成 GitHub alpha 开源上线；不能宣称 L3、生产级自动化或完整产品化。
12. R3-C54 到 R3-C70 已完成 Skill 编译；下一步用一条真实内容做 Codex 图片 / 非 Codex prompt_only、视觉文字、封面和最终 HTML 的综合回归。
13. P0-H5 Phase 1 已完成真实回归：复制 9 个资产以闭合父资产 / sidecar 来源，其中 7 个进入最终交付卡片；原图和新副本 hash 一致，内容语义 digest 一致，强制保留 `content_reused_from_baseline / verified_images_reused / external_image_generation_not_tested / publishing_not_tested`。H6 预计需要 4 次新图片 provider 调用（1 张封面底图 + 3 张画中画底图），未获用户明确授权前不执行。

---

## 编排测试验收标准

一轮真实内容测试通过，必须同时满足：

```text
账号档案 P0 齐全。
产品/活动对象边界齐全。
调研运行记录有来源、时间、热度信号和风险说明。
选题卡通过 Topic Gate，并由涛哥选择。
Brief、口播草案、画中画方案、图片资产状态、联合质检、分发包装输入包、多平台分发包字段完整。
最终交付页 `deliverables/final-delivery.html` 能让人类直接阅读、复制文字、下载图片，并能跳转到 Markdown 追溯文件。
如果要转交给项目外的人，必须生成 `deliverables/export/{session_id}/` 或 `standalone_html`，不能把 `project_local` 页面单独当成可转交包。
research_run_id 没有断链。
内容交付记录给出清楚的人类处理选项。
工作流状态记录能让下一轮恢复。
没有把草案误写成已发布、最终验收通过或正式产品规则。
```


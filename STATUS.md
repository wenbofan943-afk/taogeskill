# 涛哥创作工作流 STATUS

> 当前状态卡。历史讨论不写成长流水；有价值的过程进入对应记录文件。

---

## 当前阶段

```text
project_stage：workflow_stabilization
workflow_usage_state：v0.1.0-alpha.2_github_prerelease_published
状态说明：R1-R4 产品定义、规则 / skill 编译、只读 checker、R3 generated 样本、真实 session-scope 检查、R0 首次账号建档、最终交付验收循环和 `0.1.0-alpha.2` public release 均已完成阶段性闭环。R3-C54 到 R3-C70 已完成视觉文字与封面质量编译，并完成编译后产品 / 主链复审：修复 final builder 循环输入、prompt-only 封面条件字段冲突、平台包装 lineage 丢失和教程仍由门面 Skill 代执行的问题；专项 checker 已增加 ID、状态、next_skill、trace 和最终 HTML 数据流检查。正确 run 目录只读回放 12 步通过、零警告；仍不能宣称真实账号综合效果已验收、L3 或生产级 workflow engine。
当前产品门禁：P0-H7-C01 到 C15 已完成 v0.3 Skill 编译与真实 H6→H7 重建。`PRIVATE-H6-H7-REGRESSION` 当前 revision 为 `DREV-PRIVATE-H6-H7-002`；20/20 跨产物语义检查通过，结果 `pass_with_warnings`。平台封面绑定、8 张 PIP 精确插入窗口、warning 并集、时长诚实性和五个同源视图已闭合；仍未实际发布，传播效果未测试。
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
2. P0-H1 至 P0-H7 已形成单篇确定性运行链。H6 在 `PRIVATE-H6-H7-REGRESSION` 产生 8 个 accepted、8 张 PIP 和 3 张派生封面；H7 复用这些已验证图片，按当前平台标题重新合成封面并建立唯一 delivery revision。脱敏 H7 fixture 10/10、真实语义检查 20/20；当前可作为人工发布前工作台，但不是自动发布或传播效果证明。
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
13. H6 证明了 `derived_visual_count=accepted_visual_tasks.length` 的真实执行链：8 个任务均有完整 prompt / digest、generation record、metadata / hash 和最终卡片；发布仍未执行，真实传播效果和当前 Image 2 运行模型档位仍为 `not_tested / not_observable`。H6E 又修复 completed prepare 状态回退风险、checker 修改 manifest、真实 8+3 被写入通用 checker、重复 prepare 累积 source ID、parser-only 漏运行错误和 layout smoke 退出码误判。
14. DOC-G1 文档图治理已完成：新增 `docs/README.md` 以及 product / reference / explanation / how-to / tutorials、skills、templates 和本地 objects 分区索引；6 份当前长文增加 AI 内部导航。`validate-doc-governance.ps1` 8/8 pass，本地 15 个入口齐全、直属文档覆盖缺口 0、链接 / anchor 断链 0、根目录散落 0；未跟踪用户研究稿不进入公开索引。

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


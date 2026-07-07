# 涛哥创作工作流 STATUS

> 当前状态卡。历史讨论不写成长流水；有价值的过程进入对应记录文件。

---

## 当前阶段

```text
project_stage：workflow_stabilization
workflow_usage_state：audit_batches_a_g_compiled_pending_release_gate
状态说明：R1-R4 产品定义、规则 / skill 编译、只读 checker、R3 generated 样本、真实 session-scope 检查、R0 首次账号建档、最终交付验收循环和 `0.1.0-alpha.1` public_release candidate 均已完成阶段性闭环。产品化 P1-P5 路线已写入 `docs/product/GitHub开源上线前Workflow修复路线图.md#815-产品化-p1-p5-路线`。P1 选题候选反馈产品化已完成产品定义和 skill 编译，`field_gate_status=pass`。P2 已按成熟项目入口体验二次优化：新增第一响应卡、sample-first、safe_start_mode、entry_preflight_status 和 output_location_hint，并同步字段词典、router skill、contract、README 和 public_release。P3 已从 validator 合同推进到最小脚本实现：`build-public-release.ps1`、`validate-public-release.ps1`、`validate-sample-run.ps1` 均已落地，并通过当前 public_release 和三个 sample 的本地检查。P4 已按成熟样例体系优化：三个 sample 增加 Sample Card、persona / type / level / estimated_time / prerequisites / run_mode / golden_path / failure / recovery / validator 元数据，并同步 `validate-sample-run.ps1` 的样例元数据检查；当前三份样例校验退出码均为 0。P5 已按成熟开源 release 结构优化：新增 `VERSION`、`public-manifest.yaml`、`release-checklist.md`、`CONTACT.md`、`LICENSE`、`CONTRIBUTING.md`、`SECURITY.md`、`CODE_OF_CONDUCT.md` 和 feature request 模板；README 已增加联系与反馈入口；`build-public-release.ps1` 现在把 `release-record.json` 写入 zip，且使用相对路径；`validate-public-release.ps1` 增加版本一致性和 release_state / publish_status 冲突检查。本轮已完成 P1-P5 整体 dry-run 与成熟 workflow 对标审计，并按 A-G 批完成最小修复：A 编译一致性快修、B final-delivery 模板合同、C schema validator、D `workflow_runner_lite v0.1` 只读回放脚本、E `sample-regression-suite v0.1` 多样例回归套件、F validation-only GitHub Actions workflow、G alpha 首屏表达和 checker。当前 public_release 检查退出码 0，`P3REL-009 / P3REL-010 / P3REL-011` 均通过；但尚未 push 到 GitHub、未创建远端、未打 tag、未实际运行远端 CI，仍不能宣称 L3、GitHub release ready 或完整 workflow engine。
当前位置：D:\OpenClaw\workspace\涛哥创作工作流
Git：已初始化独立本地工作母仓，当前分支 `main`，已有初始 commit `44778213963afdf22ab29e307d141a032bbc1380`；当前工作区包含本轮候选包和大量未提交修订，尚未创建 release commit、tag 或 remote；默认 Git 入口为 `D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe`
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

1. B 批已完成最小模板合同：`templates/final-delivery/final-delivery.template.html` 和 `tools/validate-final-delivery-template.ps1` 已落地，final-delivery-builder 已指向模板；下一步需要用真实或回归 session 验证 `html_builder_mode=skill_template_rendered`。
2. C 批已完成最小 schema validator：`templates/schema/field-schema.v0.1.json` 和 `tools/validate-field-schema.ps1` 已落地，并接入 `validate-public-release.ps1`；下一步可扩展到真实 session artifact schema。
3. D 批已完成最小 runner-lite：`tools/validate-workflow-replay.ps1` 只做 `trace_replay_readonly`，不执行 AI 写作、不联网、不生成图片；P4 三个 examples 和 R1-R4 integrated dry-run 均返回 `pass_with_warnings`、无 blocker。
4. E 批已完成最小 regression fixture：`examples/regression-suite.yaml` 和 `tools/validate-regression-suite.ps1` 已落地，`validate-public-release.ps1` 增加 `P3REL-009`，public_release 内 suite 返回 `pass_with_warnings` 且 release 检查退出码 0。
5. F 批已完成 validation-only CI 最小编译：`.github/workflows/public-release-candidate-check.yml` 和 `tools/validate-ci-workflow.ps1` 已落地，`validate-public-release.ps1` 增加 `P3REL-010`；当前只是本地和公开包静态检查通过，不自动 push / tag / release，也未实际运行远端 GitHub Actions。
6. G 批已完成 Alpha 体验表达：README / INSTALL / RELEASE_NOTES / examples 第一屏已强化 alpha 候选、非生产 runner、不可自动发布、未 GitHub Release、样例验证范围等提醒；`tools/validate-alpha-expression.ps1` 已落地并接入 `P3REL-011`。
7. A-G 批已完成最小闭环；Release Gate 工具 `tools/validate-release-gate.ps1` 已落地，用于区分本地候选包通过和是否可以进入 commit / tag / remote / push / GitHub Release。发版候选产物已收敛到 `releases/v0.1.0-alpha.1/`，根目录不再保留 `public_release/`、zip、sha 或 release gate 报告。当前 `release_gate_report.overall_result=blocked`，阻断项为工作区未收口；remote / tag / release 动作仍等待人工确认，不自动发版。
8. 人工复核 `public_release/`、`release-checklist.md`、`CONTACT.md` 和 `taoge-creative-workflow-0.1.0-alpha.1-public-release.zip`；如认可候选包，再单独确认是否创建 release commit、tag `v0.1.0-alpha.1` 和 GitHub remote。
9. 图片质量检查需继续增强 prompt_alignment_score / retention_task_score，不只检查文件存在。
10. 后续调研 Seedream 4.0 / 5.0 等外部图片模型旁路；当前只保留降级策略说明，不实现 API。
11. 当前成熟度判断为 L2.8，不能宣称 L3、GitHub 开源上线完成或完整产品化。

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

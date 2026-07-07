# R1-R4 综合 Dry-run 前置检查

> 状态：preflight_pass_integrated_sample_completed_with_warnings  
> 所属路线：GitHub 开源上线前 Workflow 修复路线图  
> 主责：在进入 R1-R4 综合样本 dry-run 前，检查 R1 内容链路、R2 运行模型、R3 图片资产链、R4 开源包装是否具备同跑条件。  
> 边界：本文件只做前置门禁检查，不生成真实内容，不生成 `public_release/`，不代表完整真实测试通过。

---

## 1. 检查目的

本次检查回答一个问题：

```text
R1-R4 是否已经具备做一次“脱敏、单题、最小闭环”的综合 dry-run 条件？
```

这里的综合 dry-run 不是正式生产测试，也不是 GitHub 发布包验收。它只验证：

```text
R1：单篇内容交接物能否按合同闭合。
R2：parent / child、checkpoint、run_lock、state_transition 和恢复报告能否承接运行过程。
R3：图片资产链在 pending_external / generated 两类路径下是否能诚实落盘。
R4：公开包所需入口、样例、manifest、净化规则和检查项是否能被生成或标记。
```

---

## 2. 本次读取的真源

| 层级 | 真源 | 本次判断 |
|---|---|---|
| R1 | `docs/product/R1-skill编译验收与sample-run清单.md` | 已具备单篇 sample run 清单和 R1CHK；仍需要新跑一条低风险单题样本 |
| R2 | `docs/reference/R2-运行模型执行规范.md`、`docs/tutorials/r2-dry-run-sample/README.md` | 已完成最小 dry-run 样本，运行模型可作为综合样本前置 |
| R3 | `docs/reference/R3-图片资产执行规范.md`、`docs/tutorials/r3-dry-run-sample/README.md`、`docs/product/R3-skill编译记录与审计.md` | pending_external 最小样本通过；真实 generated 图片路径未验证 |
| R4 | `docs/reference/GitHub开源上线检查清单.md`、`templates/public-release/README.md`、`examples/README.md` | 发布门禁和模板已编译；未生成真实 `public_release/`，License 和远端信息仍待人工决策 |
| 总控 | `AGENTS.md`、`STATUS.md`、`工作流状态记录.md` | 自动推进、人工门禁、目录边界和状态记录规则已明确 |

---

## 3. 前置检查结果

| 编号 | 检查项 | 结果 | 说明 |
|---|---|---|---|
| PF-001 | R1 合同与 R1CHK 是否存在 | pass | R1 已有 sample run 产物要求和最低检查项 |
| PF-002 | R1 是否已有本轮综合样本可复用 | warn | 不复用旧真实内容；综合 dry-run 应新建脱敏单题样本 |
| PF-003 | R2 多分支与恢复模型是否可接入 | pass | R2 dry-run sample 已验证 parent / child、checkpoint、state_transition、run_lock、resume_report |
| PF-004 | R3 图片资产链是否可接入 | pass_with_scope | pending_external 路径可接入；generated 路径需要后续图片能力验证 |
| PF-005 | R4 开源包装是否可接入 | pass_with_scope | 模板和检查清单可接入；真实公开包、License、远端和 tag 不在本次范围 |
| PF-006 | 跨层 ID 是否有贯穿规则 | pass | `research_run_id`、`session_id`、`content_run_id`、`artifact_id`、`image_asset_id` 均有承接位置 |
| PF-007 | 状态写入是否有唯一事实源 | pass | 内容 session 以 manifest / state_transition / checkpoint 为事实源，根索引只引用 |
| PF-008 | 人类门禁是否会错误打断自动链路 | pass | 选题确认后自动到底；只在账号对齐、Topic Gate、最终人工验收等必要处停 |
| PF-009 | 分支任务是否会污染内容生产 | pass | R2 branch_lock 和 task_context_type 已规定旁支任务写入边界 |
| PF-010 | 图片失败是否会冒充最终图 | pass | R3 要求 `image_status`、generation_record、sidecar、html_embed_manifest 诚实标记 |
| PF-011 | 最终产物是否人类可读 | pass | R1 / R3 / R4 均要求 final-delivery.html；Markdown 只作为追溯资产 |
| PF-012 | 开源上线边界是否阻断危险动作 | pass | R4 明确不接 API key、不自动发布、不带真实账号产物、不生成未净化公开包 |
| PF-013 | 文档状态是否存在旧口径误导 | fixed | 已修正 R2 产品确认清单和 R3 编译记录顶部状态 |

---

## 4. 结论

```yaml
preflight_result: pass_with_warnings
allowed_next_action: design_or_run_integrated_dry_run_sample
not_allowed_yet:
  - full_real_content_test
  - public_release_generation
  - github_release
  - external_image_provider_api_integration
```

当前判断：

```text
R1-R4 已具备进入“综合 dry-run 样本”的条件。
综合样本应使用脱敏 sample account、单一 topic、单一 content_run，先跑 pending_external 图片路径，再视环境验证 generated 图片路径。
本次不建议直接跑完整真实内容，因为 R3 generated 路径、R4 public_release 和 License 决策还没有闭合。
```

---

## 5. 建议的综合 Dry-run 形态

建议新增样本目录：

```text
docs/tutorials/r1-r4-integrated-dry-run-sample/
```

样本只做：

```text
sample_account
-> sample_product / sample_campaign
-> one sample topic_card
-> content_brief
-> draft
-> visual_plan
-> image_generation_record
-> image_asset_set
-> quality_review
-> platform_package_input
-> platform_package
-> content_delivery_record
-> final-delivery.html
-> public_release_precheck_report
```

样本必须包含：

| 文件 | 用途 |
|---|---|
| `README.md` | 人类入口，解释这是综合 dry-run，不是真实内容 |
| `accounts/sample-account/runs/SR1R4DR-001/manifest.yaml` | 样本事实源 |
| `intermediate/00-execution-trace.md` | 标记 skill_defined / agent_orchestrated / user_decision / environment_capability |
| `intermediate/state-transitions.md` | 记录阶段状态变化 |
| `intermediate/checkpoints/` | 记录恢复点 |
| `intermediate/trace-check-report.md` | R1 / R2 / R3 / R4 检查项汇总 |
| `assets/images/generation-records/` | 图片生成记录 |
| `assets/images/metadata/` | 图片 sidecar |
| `deliverables/final-delivery.html` | 人类验收页 |
| `deliverables/html-embed-manifest.json` | HTML 图片嵌入清单 |
| `public-release-precheck.md` | R4 公开包前置检查报告 |

---

## 6. 风险与取舍

| 风险 | 当前处理 |
|---|---|
| R1 旧测试样本曾暴露 agent 扶跑 | 不复用旧样本，综合 dry-run 必须新建脱敏样本并记录 execution trace |
| R3 真实出图质量不可控 | 第一轮综合样本允许 pending_external；generated 路径单独作为加测 |
| R4 License 未选 | 综合样本只生成 public_release_precheck，不生成真实公开包 |
| 任务过长导致断流 | R2 checkpoint 和 state_transition 必须每阶段落盘，允许分段续跑 |
| 人类看不懂一堆 Markdown | 最终验收入口必须是 HTML，Markdown 只做可追溯 sources |

---

## 7. 下一步建议

```text
1. 先创建 R1-R4 综合 dry-run 样本骨架，使用脱敏 sample account 和单题。
2. 按阶段跑到 final-delivery.html，但默认图片状态先用 pending_external，不冒充已生成。
3. 样本闭合后再决定是否加测 generated 图片路径和 public_release 打包路径。
```

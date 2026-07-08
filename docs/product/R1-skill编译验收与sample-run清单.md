# R1 Skill 编译验收与 Sample Run 清单

> 状态：R1 返修编译后验收清单  
> 目标：判断 R1 第一轮 `SKILL.md` 编译是否具备进入 sample run / 轻量真实样本验证的条件。  
> 边界：本文件不替代真实样本；只规定样本跑完后怎么判断是否接近 L3 candidate。

---

## 1. 静态编译验收

| 检查项 | 标准 | 当前状态 |
|---|---|---|
| 8 个核心 `CONTRACT.md` 已确认 | `status: confirmed`，含 `contract_set_version` | 已完成 |
| 8 个核心 `SKILL.md` 有 R1 Runtime | 顶部存在 `R1 Contract Runtime` | 已完成 |
| 旧入口降级 | `hotspot-copywriting-research` 只有 `R1 Compatibility Runtime` | 已完成 |
| reference 已反写 | 人类引导、执行透明度、目录/manifest 已吸收 R1 规则 | 已完成 |
| 统一交接块 | 每个核心 skill 输出必须带 `contract_set_version`、上游 ID、状态、路径、`next_skill`、`execution_trace_update` | 已完成 |
| 自动推进规则 | Brief / 质检 / 平台包通过后不再要求用户说继续 | 已完成 |
| 多选题保护 | R1 识别 `branch_request`，不硬跑多篇 | 已完成 |
| 渐进读取边界 | 长 skill 有测试前读取边界，不靠全文硬撑 | 已补强 |
| 新旧 session 边界 | R1 验收必须使用新 session，旧 session 只做参考 | 已补强 |
| 决策恢复字段 | decision_type 后必须更新 manifest / workflow_session_record | 已补强 |
| sample run 产物模板 | manifest、execution trace、trace check 和 preflight 有统一模板 | 已补强 |
| R1 返修项已编译 | prompt 完整度、视觉质检门、trace 自洽、恢复证据边界已进入对应 skill | 已完成 |

## 1.1 测试前硬闸门

以下任一项不满足，不开始 R1 sample run：

```text
8 个核心 CONTRACT.md 均为 confirmed。
8 个核心 SKILL.md 均有 R1 Contract Runtime 和 R1 交接块。
旧入口 hotspot-copywriting-research 只有 Compatibility Runtime。
reference 已反写 decision_type、branch_request、contract_set_version、trace_check。
新样本必须是新 session，不能复用旧 session。
manifest 模板必须含 contract_set_version、sample_run_type、legacy_session、trace_check。
必须先按 `docs/reference/R1-sample-run产物模板.md` 输出 r1_preflight。
长 skill 运行时必须先读 R1 Runtime / 交接块，再按需读细节章节。
talking-head-image-pip 必须执行 R1CHK-017。
copywriting-quality-review 必须执行 R1CHK-018。
final-delivery-builder 必须执行 R1CHK-019。
propagation-router 必须执行 R1CHK-020 / R1CHK-110。
```

硬闸门通过后，才能进入 sample run。

---

## 2. Sample Run 必须验证什么

R1 sample run 不验证 R2/R3/R4，只验证核心单篇链路。

必须跑通：

```text
account_profile
-> product_profile / campaign_profile
-> research_run_record
-> topic_card
-> content_brief
-> draft
-> visual_plan
-> quality_review
-> platform_package_input
-> platform_package
-> content_delivery_record
-> final_delivery
-> human_final_review
```

必须产生：

```text
manifest.yaml
intermediate/00-execution-trace.md
intermediate/01-research-run.md
intermediate/02-topic-card.md
intermediate/03-content-brief.md
intermediate/04-draft.md
intermediate/05-visual-plan.md
intermediate/06-quality-review.md
intermediate/07-platform-package-input.md
intermediate/08-platform-package-draft.md
deliverables/content-delivery-record.md
deliverables/final-delivery.html
```

---

## 3. R1 Trace Check 最低项

样本跑完后至少检查：

| check_id | 通过标准 |
|---|---|
| R1CHK-001 | `manifest.yaml` 存在 |
| R1CHK-002 | `intermediate/00-execution-trace.md` 存在 |
| R1CHK-003 | `current_artifact` 指向本 session 下文件 |
| R1CHK-004 | `contract_set_version = r1-contract-set-v0.1` |
| R1CHK-006 | `source_research_run_id` 贯穿到 `content_delivery_record` |
| R1CHK-007 | 选题确认后不问“是否生成 Brief / 是否继续写口播” |
| R1CHK-008 | `brief_pass` 后不问“继续写口播” |
| R1CHK-009 | `review_pass` 后不问“继续做分发包” |
| R1CHK-010 | 平台包完成后自动进入 `content_delivery_record` 和 final delivery |
| R1CHK-011 | 人类门禁只出现在允许节点 |
| R1CHK-013 | 未自动发布、登录、评论、私信或互动 |
| R1CHK-014 | 最终交付有 `final-delivery.html` 或明确 blocked 原因 |
| R1CHK-016 | 单 session 没混入多篇独立正文 |
| R1CHK-017 | `visual_plan` 中每张生成图片的 prompt 完整度通过，不得只有短关键词 |
| R1CHK-018 | `quality_review` 必须有视觉质检门；泛素材图或 prompt 不完整不得 `review_pass` |
| R1CHK-019 | manifest、execution_trace、image_asset_set（旧别名：image_asset_manifest）和实际图片文件对 imagegen / 图片状态记录一致 |
| R1CHK-020 | manifest + execution_trace + current_artifact 足以支持断流后的人工 / AI 恢复判断 |
| R1CHK-109 | R1 sample run 不得被表述为完整真实测试通过 |
| R1CHK-110 | R1 不得被表述为脚本级断点续跑；checkpoint / retry / lock 归 R2 |

---

## 4. 通过标准

```yaml
overall_result: pass / pass_with_warnings
agent_assist_level: low / medium
core_steps_agent_created_rule: 0
auto_next_wrong_stop: 0
forbidden_human_prompt_count: 0
publish_boundary_violation: 0
final_delivery_ready: yes
prompt_integrity_failed: 0
visual_quality_gate_failed: 0
trace_consistency_failed: 0
resume_scope_overclaim: 0
```

如果出现任一 BLOCKER fail：

```text
本轮不能进入 L3 candidate。
必须回到对应 skill / reference / 字段词典修订。
```

如果只有 WARN：

```text
可以记录为 pass_with_warnings。
允许进入下一轮小修，但不能直接宣称稳定开源。
```

---

## 5. 样本建议

建议下一轮用一个低风险单篇样本验证：

```text
账号：示例行业观察号 或 sample account。
产品 / 活动对象：观点对象或低产品露出对象。
选题数量：只选 1 个 topic_id。
图片：允许 generated / pending_external，但状态必须真实。
最终交付：必须生成 project_local final-delivery.html。
session：必须新建，不能复用旧 session。
manifest：必须写 contract_set_version: r1-contract-set-v0.1。
```

不要用“三篇都做”、跨账号、多平台导出包、Seedream 外部模型等复杂任务验证 R1；这些属于 R2/R3/R4。

R1 返修验证时，必须特别检查：

```text
05-visual-plan.md 是否保留完整 prompt 卡。
06-quality-review.md 是否包含 visual_quality_gate_status 和 prompt_integrity_status。
00-execution-trace.md 是否和 manifest / image-assets.md 对 imagegen 使用记录一致。
断流恢复时，router 是否只读恢复证据，不重跑已完成阶段。
```


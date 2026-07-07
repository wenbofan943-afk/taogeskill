# Skill 执行透明度与成熟度规范

> 状态：全局规则  
> 主责：区分“skill 自己完成了什么”和“agent 临场扶着完成了什么”，为未来发布 skill 做成熟度判断。  
> 边界：本规范只记录内容 workflow 的执行透明度，不改变客户端、服务器、平台账号或发布链路。

---

## 一、为什么要记录

跑通一条内容不等于 skill 已经成熟。

如果生产链路里大量动作靠 agent 临场补判断、补文件、补字段、补目录、补链接，那么这叫“agent 扶着 skill 跑通”，不能当成可发布 skill。

每轮真实运行必须让人看得出来：

```text
哪些是 skill 规则内产出。
哪些是 agent 临场判断。
哪些是用户明确决策。
哪些是环境能力，比如浏览、文件读写、image 生成。
哪些是流程缺口，被 agent 补上了。
哪些缺口需要反写到 skill，下一轮不能再靠临场发挥。
```

---

## 二、执行来源分类

| execution_source | 含义 | 能否算 skill 成熟能力 |
|---|---|---|
| skill_defined | skill 文档明确要求，agent 只是按步骤执行 | 可以 |
| skill_inferred | skill 有方向，但细节靠 agent 推断补齐 | 部分可以，需补规则 |
| agent_orchestrated | skill 没写清，agent 临场编排完成 | 不能直接算 |
| agent_created_rule | 运行中发现缺口，agent 新增规则后继续 | 不能算本轮原始 skill 能力 |
| user_decision | 用户做出的方向、采用、返工或确认 | 不是 skill 能力 |
| environment_capability | Codex / 浏览器 / image / 文件系统等环境能力 | 不是 skill 本身能力 |
| manual_fallback | 环境或 skill 不支持，agent 手工降级完成 | 不能算 |

---

## 三、成熟度等级

| maturity_level | 标准 |
|---|---|
| L0 手工脚本 | 主要靠 agent 判断，skill 只是方法论参考 |
| L1 可指导 | skill 能告诉 agent 怎么做，但输入输出还需要人扶 |
| L2 可复跑 | 按固定输入能稳定产出固定交接物，但仍需 agent 补少量边界 |
| L3 可发布候选 | 输入、输出、停顿点、状态、失败处理都明确，agent 只执行不补规则 |
| L4 可产品化 | 可跨账号、跨 session 稳定运行，有测试样例、失败用例和迁移说明 |

发布前最低要求：核心链路 skill 必须达到 L3；如果某个节点只有 L1/L2，README 必须写清限制。

---

## 四、每轮必须生成 execution trace

每个 session 必须有：

```text
accounts/{账号名}/runs/{session_id}/intermediate/00-execution-trace.md
```

最小格式：

```markdown
# Execution Trace

## 本轮摘要
- session_id：
- account：
- started_at：
- current_stage：
- trace_status：active / waiting_human / completed / blocked

## 执行动作表
| step | action | expected_skill | execution_source | evidence | agent_intervention | result |
|---|---|---|---|---|---|---|

## Skill 成熟度观察
| skill | maturity_level | 本轮表现 | 需要反写的规则 |
|---|---|---|---|

## Agent 扶跑清单
| 缺口 | agent 怎么补的 | 是否已反写到规则 | 下轮验收方式 |
|---|---|---|---|

## 发布风险
- 如果现在发布 skill，用户可能卡在哪里：
- 哪些步骤还依赖 Codex agent 临场判断：
- 哪些能力其实来自环境，不来自 skill：

## R1 Trace Check
- trace_check_id：
- contract_set_version：
- overall_result：pass / pass_with_warnings / fail
- blocking_issues：
- warnings：
- next_action：
```

R1 编译后的新样本必须记录：

```text
contract_set_version：r1-contract-set-v0.1
```

R2 编译后的样本必须记录：

```text
contract_set_version：r2-runtime-v0.1
task_context_type
content_run_id
parent_session_id
branch_request_id
branch_request_status
fan_out_status
fan_in_status
run_lock
latest_checkpoint
state_transition_id
resume_report
```

R3 编译后的样本必须记录：

```text
contract_set_version：r3-asset-runtime-v0.1
image_asset_set_id
image_assets_status
generation_records_dir
metadata_dir
html_embed_manifest_status
generated_image_count
pending_image_count
failed_image_count
manual_required_count
rejected_image_count
missing_sidecar_count
r3_sample_gate_status
```

每个动作行还应尽量记录：

```text
input_artifact
output_artifact
artifact_path
next_skill
check_ids
```

这样后续可以按 R1CHK 检查项复核，而不是只读流水账。

---

## 五、manifest 必填字段

每个 `manifest.yaml` 必须记录：

```yaml
contract_set_version:
execution_trace:
  path:
  trace_status:
  agent_assist_level: low / medium / high
  skill_maturity_summary:
trace_check:
  trace_check_id:
  overall_result: pass / pass_with_warnings / fail
  blocking_count:
  warning_count:
```

`agent_assist_level` 含义：

```text
low：agent 只按 skill 执行，未补规则。
medium：agent 补了少量文件、索引或边界，但主流程由 skill 驱动。
high：agent 大量补流程、补判断、补规则，本轮不能视为 skill 独立跑通。
```

---

## 六、反写规则

发现 agent 扶跑后，必须判断：

```text
是一次性项目治理问题 -> 写入 docs/reference 或 docs/explanation。
是某个 skill 缺规则 -> 反写到对应 SKILL.md。
是字段缺失 -> 反写到 交接物字段词典.md。
是目录 / 输出摆放问题 -> 反写到 文档治理与目录规范.md。
是用户引导问题 -> 反写到 人类引导与任务后导航规范.md。
```

反写后，下一轮真实内容必须验证：同样问题不能再靠 agent 临场补。

## 七、R1 检查项

R1 编译后的 sample run / 轻量真实样本，必须按 `docs/product/R1-trace-check注册表.md` 执行人工检查或后续 validator 检查。

最低必须覆盖：

```text
R1CHK-001 manifest 存在。
R1CHK-002 execution_trace 存在。
R1CHK-003 current_artifact 指向 session 内文件。
R1CHK-004 contract_set_version 存在。
R1CHK-006 source_research_run_id 贯穿。
R1CHK-007 到 R1CHK-010 自动推进未错停。
R1CHK-011 人类门禁在允许列表内。
R1CHK-013 没有自动发布 / 登录 / 评论 / 私信 / 互动。
R1CHK-014 最终交付不是只有 Markdown。
R1CHK-016 R1 单 session 没混入多篇独立内容。
```

任一 BLOCKER fail 时，本轮不能算 L3 候选通过。

### R1 测试前硬闸门

进入 R1 sample run 前必须先检查：

```text
8 个核心 CONTRACT.md 均为 status: confirmed。
8 个核心 SKILL.md 均有 R1 Contract Runtime 和 R1 交接块。
旧入口只有 R1 Compatibility Runtime，不承载新逻辑。
reference 已包含 decision_type、branch_request、contract_set_version、trace_check。
sample run 使用新 session，不使用 R1 编译前旧 session 作为验收样本。
manifest 模板含 contract_set_version 和 trace_check。
已读取 `docs/reference/R1-sample-run产物模板.md` 并通过 r1_preflight。
```

任一不满足，不能开始 sample run；先回到 R1 编译补强。

### 旧 Session 边界

R1 编译前产生的旧 session 只能用于：

```text
回归参考。
人工校准。
发现迁移问题。
```

不能用于：

```text
宣称 R1 sample run 通过。
宣称 L3 candidate。
替代新 session 验收。
```

旧 session 如果要恢复，必须在 trace 里记录：

```text
contract_migration_note:
legacy_session: yes
inferred_contract_set_version:
not_for_r1_acceptance: yes
```

---

## 八、R2 运行证据检查

R2 编译后，涉及多分支、恢复、长任务或最终交付收口的 session，必须额外检查：

```text
R2CHK-001 manifest 含 R2 runtime 字段。
R2CHK-002 intermediate/checkpoints/latest.md 存在，且指向最后可信节点。
R2CHK-003 state_transition 有 from_state / to_state / reason / timestamp。
R2CHK-004 branch-request-ledger.md 记录每个 branch_request 的状态和 child session。
R2CHK-005 parent session 不保存 child 正文，只保存拆分和 fan-in。
R2CHK-006 child session 拥有独立 manifest、trace、intermediate、deliverables。
R2CHK-007 run_lock 冲突时阻断，不继续写入。
R2CHK-008 resume_report 能说明已完成、阻断、可安全继续和不能自动重跑的动作。
R2CHK-009 final-delivery-builder 收口时写 checkpoint 并释放 run_lock。
R2CHK-010 产品设计 / 治理 / skill 编译任务的旁支请求只能 branch_request_deferred，不做内容 fan-out。
```

任一 BLOCKER fail 时，不能宣称 R2 运行模型可发布。

---

## 九、R3 图片资产检查

R3 编译后，涉及画中画、图片生成、图片降级或最终 HTML 展示的 session，必须额外检查：

```text
R3CHK-001 visual_budget 存在。
R3CHK-002 required_visuals 数量符合预算或有增减理由。
R3CHK-003 每张 required 图有 retention_task。
R3CHK-004 每张图有 insert_after_text / insert_before_text。
R3CHK-005 每张图有完整 prompt_card。
R3CHK-006 每次生成 / 降级有 image_generation_record。
R3CHK-007 generated 图片有 asset_path 且文件存在。
R3CHK-008 generated 图片有 metadata_sidecar_path。
R3CHK-009 pending / failed / manual 不被当成 generated 展示。
R3CHK-010 image_status 和 image_assets_status 不混用。
R3CHK-011 图片重做不覆盖旧 asset。
R3CHK-012 HTML 使用 html_embed_manifest 展示图片或占位。
R3CHK-013 多篇并行时每个 child session 独立 image_asset_set。
R3CHK-014 execution_trace 记录 image_generation / fallback 来源。
R3CHK-015 不调用外部图片 API，不保存 API key。
```

任一 BLOCKER fail 时，不能宣称 R3 图片资产链达到 L3 candidate。

---

## 十、对外发布判断

准备发布 skill 前，必须至少回答：

```text
这个 skill 离开当前 agent，能不能让另一个 AI 看懂怎么跑？
输入不完整时，它知道停在哪里吗？
用户说“认可 / 选题 / 确认采用”时，它知道自动进入哪里吗？
产物路径是否固定？
失败时是否有降级策略？
execution trace 是否显示 agent_assist_level 连续降低？
```

如果答案不清楚，不发布；先继续跑真实样本和修规则。

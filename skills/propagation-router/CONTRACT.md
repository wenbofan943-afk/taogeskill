# Propagation Router Contract

> 状态：confirmed_with_checker_runtime  
> contract_version：0.5.0
> contract_set_version：r1-r4-readonly-checker-v0.1  
> 对应 skill：`skills/propagation-router/SKILL.md`  
> 编译门禁：涛哥已确认 R2 运行模型，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: propagation-router
skill_name: 涛哥创作工作流总控路由
contract_version: 0.5.0
contract_set_version: r1-r4-readonly-checker-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-06
```

一句话职责：

```text
读取项目状态和当前交接物，判断本轮应该进入哪个专项 skill；只做路由、门禁、人类引导和任务后导航，不生产正文、不做发布、不改业务代码。
```

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 涛哥创作工作流
    - 热点 skill
    - 传播总控
    - 下一步
    - 使用涛哥创作工作流
    - 涛哥 skill
    - 帮我做一条内容
    - 这是我写的，按中间 Skill 跑
    - 不按热点逻辑，直接做交付
    - 新建账号
    - 先试一下
    - 跑个样例
    - 不想先建账号
    - 接着上次
    - 到哪了
    - 只读检查
    - 最终产物在哪里
    - 这个环境能不能出画中画
    - 不能出图怎么办
    - 帮我判断先做什么
    - 换账号做内容
    - 选题后怎么走
  upstream_artifact_status:
    - no_artifact
    - workflow_session_record_exists
    - user_supplied_draft
    - direct_content_ready
    - topic_selected_for_brief
    - brief_pass
    - draft_created
    - visual_plan_pass
    - review_pass
    - platform_package_pass
    - delivery_ready
    - cover_composition_ready
    - cover_prompt_only
    - cover_quality_pass
    - final_delivery_ready
  allowed_manual_commands:
    - 接着上次
    - 从头跑
    - 换账号
    - 选 T{topic_id}
    - 只改{局部}
    - 导出转交包
    - 记录发布结果
```

不得触发的情况：

```text
用户明确要求写正文、做图、质检或平台包装时，不由本 skill 临时生产内容，只能路由到对应专项 skill。
用户要求改公开互动分析工具客户端、服务器、数据库、license、积分或发版链路时，本 skill 必须拒绝在本项目内执行，并提示回到对应产品项目。
用户要求自动发布、登录平台、自动评论、私信或互动时，本 skill 必须拦截。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - README.md
    - AGENTS.md
    - STATUS.md
    - PROJECT_MAP.md
    - 工作流状态记录.md
    - 交接物字段词典.md
    - docs/reference/人类引导与任务后导航规范.md
    - docs/reference/skill执行透明度与成熟度规范.md
    - docs/reference/R2-运行模型执行规范.md
    - docs/reference/R1-R4只读checker执行规范.md
  required_fields:
    - project_stage
    - workflow_usage_state
    - current_stage
    - current_artifact
    - session_status
  required_paths:
    - accounts/{account_slug}/account_profile.md
    - accounts/{account_slug}/runs/{session_id}/manifest.yaml
  required_status:
    - project_stage != archived
```

如果当前没有 session，`manifest.yaml` 不是硬前置；此时必须先判断账号档案和产品 / 活动对象是否具备。

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - workflow_session_record
    - manifest.yaml
    - account_profile
    - product_profile
    - campaign_profile
    - topic_card
    - direct_content_intake
    - direct_content_card
    - content_brief
    - draft
    - visual_plan
    - quality_review
    - platform_package
    - content_delivery_record
    - final_delivery
    - workflow_check_report
    - entry_router_request
    - release_check_report
    - sample_check_report
  source_path:
    - 工作流状态记录.md
    - accounts/{account_slug}/runs/{session_id}/manifest.yaml
    - accounts/{account_slug}/runs/{session_id}/intermediate/
    - accounts/{account_slug}/runs/{session_id}/deliverables/
  required_fields:
    - account
    - account_slug
    - session_id
    - current_stage
    - current_artifact
    - artifact_ids
    - next_skill
    - session_status
  optional_fields:
    - product_profile_id
    - campaign_profile_id
    - research_run_id
    - direct_intent
    - revision_policy
    - blocked_reason
    - human_prompt
    - human_reply_examples
    - entry_intent
    - entry_case
    - entry_route
    - account_resolution_status
    - entry_confidence
    - entry_resolution_reason
    - entry_preflight_status
    - safe_start_mode
    - sample_run_offered
    - first_response_card_status
    - image_generation_capability_notice
    - next_visible_step
    - output_location_hint
  validation_rules:
    - current_artifact 必须优先指向账号 session 内文件
    - 路由判断必须以具体 session 产物优先，根目录汇总表只做辅助索引
    - 不得从聊天记忆里补事实字段
    - R1CHK-020：断流 / 接着上次时，必须用 manifest + execution_trace 做恢复证据判断
    - R1CHK-110：不得把 R1 描述为脚本级断点续跑；checkpoint / retry / lock 进入 R2
    - R2：多分支、checkpoint、run_lock、state_transition、branch ledger 必须按 R2 运行模型执行规范判断
    - checker：只读检查必须按 R1-R4 只读 checker 执行规范判断，不得自动修复
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type:
    - router_decision
    - human_prompt
    - task_after_navigation
    - workflow_session_record_update
    - execution_trace_update
    - workflow_check_report
    - entry_router_request
    - release_check_report
    - sample_check_report
  target_path:
    - chat_response
    - 工作流状态记录.md
    - accounts/{account_slug}/runs/{session_id}/intermediate/00-execution-trace.md
    - accounts/{account_slug}/runs/{session_id}/manifest.yaml
  required_fields:
    - current_stage
    - current_artifact
    - missing_artifacts
    - recommended_action
    - next_skill
    - auto_next_action
    - human_prompt
    - human_reply_examples
    - session_status
    - entry_intent
    - entry_case
    - entry_route
    - account_resolution_status
    - entry_confidence
    - entry_resolution_reason
    - entry_preflight_status
    - safe_start_mode
    - sample_run_offered
    - first_response_card_status
    - image_generation_capability_notice
    - next_visible_step
    - output_location_hint
    - recovery_evidence_status
    - resume_scope_note
    - r2_runtime_status
    - resume_report
    - branch_request_status
    - fan_out_status
  status_field:
    - session_status
  downstream_artifact:
    - next_skill 的输入交接物
```

路由输出不等于专项产出。  
本 skill 不得把自己输出的判断伪装成 `topic_card`、`content_brief`、`draft`、`visual_plan` 或 `platform_package`。

---

## 6. 路径合同

```yaml
path_contract:
  project_root: <PROJECT_ROOT>
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - 工作流状态记录.md
    - accounts/{account_slug}/account_profile.md
    - objects/products/{product_profile_id}.md
    - objects/campaigns/{campaign_profile_id}.md
    - accounts/{account_slug}/runs/{session_id}/manifest.yaml
  output_paths:
    - accounts/{account_slug}/runs/{session_id}/intermediate/00-execution-trace.md
    - 工作流状态记录.md
  index_paths:
    - indexes/all_runs.md
```

规则：

```text
无 session 时，只能做路由判断和前置检查；不得创建正文产物。
已有 session 时，优先读取 session manifest。
根目录汇总表和 session 产物冲突时，以 session 产物为准。
产品开发任务不得改生产 session。
内容生产任务不得改产品路线图。
```

### R2 运行模型合同

本 skill 是 R2 的总控入口。遇到多选、旁支、断流、恢复和状态重建时，必须读取：

```text
docs/reference/R2-运行模型执行规范.md
```

R2 必须使用以下状态命名空间：

```text
run_* / branch_request_* / fan_out_* / fan_in_*
```

禁止使用裸状态：

```text
planned / active / completed
```

禁止发明临时状态；具体原因写入：

```text
blocked_reason
```

用户说“三篇都做 / 都要 / 这几个都跑”时：

```text
1. 判断 task_context_type。
2. 内容生产任务：生成 human_decision_payload、branch_request、parent / child 规划。
3. 产品开发 / 文档治理 / 开源治理：写 branch_request_deferred，不启动内容生产。
4. 写入 parent manifest 和 intermediate/branch-request-ledger.md。
5. 每个 child session 只绑定一个 topic_id。
```

断流恢复时必须输出：

```yaml
resume_report:
  session_id:
  content_run_id:
  current_stage:
  last_completed_stage:
  latest_checkpoint:
  pending_human_interrupt:
  run_lock_status:
  recommended_resume_action:
  do_not_rerun:
  safe_to_rerun:
  blocked_reason:
```

### R1 恢复证据合同

用户说“活了吗 / 刚刚怎么断了 / 接着上次 / 到哪了”时，本 skill 必须：

```text
1. 先读 STATUS.md 和 工作流状态记录.md。
2. 再读 current_artifact 指向的 session manifest.yaml。
3. 再读 intermediate/00-execution-trace.md 的最后动作和 trace_check。
4. 判断当前 session 是 completed / waiting_human / blocked / needs_postcheck。
5. 只恢复未完成的下一步；不得盲目重跑已经完成的阶段。
```

R1 只提供恢复证据：

```text
manifest + execution_trace + current_artifact 足以让 AI / 人判断从哪里继续。
```

R1 不提供：

```text
自动 resume runner。
阶段级 checkpoint。
幂等重跑。
失败 retry。
run lock。
多分支恢复。
```

这些能力进入 R2 运行模型。

### R2 恢复读取顺序

用户说“活了吗 / 刚刚怎么断了 / 接着上次 / 到哪了”时，R2 编译后必须按以下顺序读取：

```text
STATUS.md
-> 工作流状态记录.md
-> current_artifact
-> session manifest.yaml
-> 最新 checkpoint
-> state_transitions
-> branch-request-ledger.md
-> execution_trace
-> 实际 intermediate / deliverables 文件
```

如果缺少 checkpoint，不得声称脚本级断点续跑，只能输出 `recovery_evidence_status=insufficient_checkpoint` 和最小恢复建议。

### R1-R4 只读 checker 合同

当用户要求 checker / 只读检查 / R1-R4 验收时，本 skill 必须读取：

```text
docs/reference/R1-R4只读checker执行规范.md
templates/checker/workflow-check-report.template.md
```

输入：

```yaml
checker_input:
  check_scope: project / session / sample
  target_path:
  readonly: true
```

输出：

```yaml
workflow_check_report:
  check_id:
  check_scope:
  target_path:
  overall_result:
  maturity_observed:
  blocking_count:
  warning_count:
  next_action:
  human_prompt:
```

禁止：

```text
自动修文件。
生成图片。
生成 public_release。
推 GitHub。
把检查通过说成 L3 或完整真实测试通过。
```

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - user_supplied_draft
    - direct_content_ready
    - topic_selected_for_brief
    - brief_pass
    - draft_created
    - visual_plan_pass
    - review_pass
    - platform_package_pass
    - delivery_ready
  next_skill:
    user_supplied_draft: direct-content-intake
    direct_content_ready: use direct_content_card.next_skill; content-brief-compiler or hotspot-topic-research
    topic_selected_for_brief: content-brief-compiler
    brief_pass: copywriting-draft-writer
    draft_created: talking-head-image-pip
    visual_plan_pass: copywriting-quality-review
    review_pass: platform-packaging-adapter
    platform_package_pass: cover-design-compiler
    delivery_ready: cover-design-compiler
    cover_composition_ready: copywriting-quality-review
    cover_prompt_only: copywriting-quality-review
    cover_quality_pass: final-delivery-builder
  next_artifact:
    - direct_content_intake
    - direct_content_card
    - content_brief
    - draft
    - visual_plan
    - quality_review
    - platform_package
    - cover_design_package
    - cover_composition
    - cover_quality_gate
    - final_delivery
  forbidden_human_prompt:
    - 是否继续？
    - 是否进入下一步？
    - 请回复继续写口播。
    - 是否生成 Brief？
    - 是否做画中画？
    - 是否继续做分发包？
```

自动推进时允许说明：

```text
这一步已经通过，我会自动进入 {下一环节}。如果你想打断，可以直接说“回到 {上一环节} 改 {具体部分}”。
```

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: account_profile_missing_or_incomplete
    trigger: 账号档案不存在或 P0 缺失
    reason: 不知道谁来说，会串账号、串语气和串禁区
    recommended_action: 用口语化问题补齐账号 P0
    human_reply_examples:
      - 这个号主要讲给本地经营者
      - 目标人群是准备做决策的新手用户
      - 禁区是不碰事故责任和平台灰产
    auto_next_after_reply: account_profile_quality_check

  - gate_id: account_profile_reconfirm_after_switch
    trigger: 本轮账号和上一轮不同，或用户说换账号
    reason: 账号实际情况可能变化，旧画像会导致选题、语气、产品露出和禁区偏移
    recommended_action: AI 摘要账号档案，用户回复认可 / 同意 / 没变化后继续
    human_reply_examples:
      - 认可
      - 同意
      - 没变化
      - 目标人群改一下
    auto_next_after_reply: product_profile_check

  - gate_id: product_or_campaign_unclear
    trigger: 产品 / 活动对象边界不清
    reason: 不知道这次说什么、不能怎么说、希望用户下一步做什么
    recommended_action: 选择已有对象或补对象边界
    human_reply_examples:
      - 用 P-public-interaction-tool
      - 这条只做账号观点，不带产品
      - 先补产品档案
    auto_next_after_reply: hotspot-topic-research

  - gate_id: account_startup_check
    trigger: 已识别账号，准备进入热点、选题、内容或视觉任务
    reason: 账号档案完整不等于本次平台、时长、受众优先级、风险口径和账号策略可直接使用；更不能让展示名、目录、策略、词库、视觉资产或旧快照跨账号串用。
    recommended_action: 运行 v0.2 确定性账号启动检查；先验证技术身份绑定、根目录和 binding digest，再只问当前任务缺失且相关的字段，每轮最多 3 问；用户确认后生成 session 账号快照。
    human_reply_examples:
      - 抖音为主，60 秒；买车人和车商优先；高风险就按核验和机制讲
      - 这次只做热点，不用问视觉身份
      - 先把账号策略补好再找
    auto_next_after_reply: account_identity_verified -> account_startup_check -> account_snapshot_ready -> task-specific router

  - gate_id: topic_gate
    trigger: 候选选题已生成，需要人选方向
    reason: 选题是内容方向判断，必须由人决定
    recommended_action: 给一个主推荐和备选，让用户直接回复选题 ID
    human_reply_examples:
      - 选 T20260706-001
      - 002
      - 三篇都做
      - 重找一轮
    auto_next_after_reply: content-brief-compiler 或 R2 fan_out

  - gate_id: r2_branch_confirm
    trigger: 用户提出多篇、多账号或旁支任务
    reason: 多分支需要拆 parent / child session，避免串台和重复跑
    recommended_action: 按 R2 fan-out 规划拆成多个 child session
    human_reply_examples:
      - 三篇都做
      - 这两个都跑
      - 取消多篇，只做 T001
    auto_next_after_reply: plan_fan_out / branch_request_deferred

  - gate_id: quality_blocked
    trigger: 质检不通过
    reason: 发布风险或质量风险未清
    recommended_action: 给最小返工路径
    human_reply_examples:
      - 按建议改口播
      - 重做首屏画中画
      - 降级成行业趋势
    auto_next_after_reply: copywriting-draft-writer 或 talking-head-image-pip

  - gate_id: final_delivery_review
    trigger: final-delivery.html 已生成
    reason: 人需要验收最终可读交付物是否满意
    recommended_action: 人工发布、局部返工、归档或导出转交包
    human_reply_examples:
      - 记录发布结果
      - 只改抖音标题
      - 回到口播改前 5 秒
      - 导出转交包
      - 归档今天不发
    auto_next_after_reply: publish_record / local_revision / export_bundle / archive
```

禁止把以下节点设成人类门禁：

```text
Brief 通过。
口播草案已生成且无风险。
画中画方案通过。
质检通过。
平台包完成。
content_delivery_record 完成。
```

---

## 9. 失败处理

```yaml
failure_modes:
  missing_input:
    symptom: 找不到必要交接物或 current_artifact 断链
    recovery_action: 先读 manifest.yaml；manifest 不存在时读 工作流状态记录.md；仍缺失则提示补上游，不新造事实
  invalid_field:
    symptom: 状态字段和词典冲突
    recovery_action: 以 交接物字段词典.md 为准，给出需修字段，不进入下一 skill
  broken_link:
    symptom: current_artifact 指向不存在文件
    recovery_action: 在 session 目录搜索同阶段产物，找到后修正索引；找不到则停在恢复状态
  interrupted_stream:
    symptom: 聊天流断开或用户问刚刚是否中断
    recovery_action: 读取 manifest + execution_trace，输出 recovery_evidence_status，不重跑已完成阶段
  overclaimed_resume:
    symptom: R1 被表述为脚本级断点续跑
    recovery_action: 标记 R1CHK-110 warn，说明 R1 只有恢复证据，checkpoint / retry / lock 属于 R2
  stale_hotspot:
    symptom: 热点时效超过窗口
    recovery_action: 路由回 hotspot-topic-research 做降级，不允许硬叫热点
  branch_conflict:
    symptom: 产品开发任务试图改生产 session，或内容生产任务试图改产品路线图
    recovery_action: 写入 branch_request_deferred，只改允许范围
  r2_missing_checkpoint:
    symptom: R2 恢复需要 checkpoint，但 session 没有 checkpoint
    recovery_action: 输出 recovery_evidence_status=insufficient_checkpoint，不重跑已完成阶段，生成 run_blocked + blocked_reason=manual_fix_required 建议
  r2_lock_conflict:
    symptom: run_lock 被其他任务占用
    recovery_action: 输出 run_blocked + blocked_reason=lock_conflict，等待人工恢复或 run_lock_conflict 判断
  quality_risk:
    symptom: 质检有 blocking_issues
    recovery_action: 路由回 draft 或 visual_plan 的最小返工点
```

失败时必须输出：

```text
卡在哪里。
为什么不能继续。
最小恢复动作。
用户如果需要回复，可以怎么说。
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  source_labels:
    - skill_defined
    - skill_inferred
    - agent_orchestrated
    - agent_created_rule
    - user_decision
    - environment_capability
    - manual_fallback
  agent_assist_level_rule:
    low: 只按 contract 路由，未补规则
    medium: 补了索引或路径修正，但没有改变路由规则
    high: 临场新增路由、门禁、字段或流程
  maturity_level_rule:
    L2: 能稳定路由，但仍需 agent 补少量边界
    L3: 输入、输出、停顿点、状态和失败处理都按合同执行
```

必须记录的动作：

```text
读了哪些入口。
判断当前阶段的依据。
恢复判断依据：manifest / execution_trace / current_artifact。
路由到哪个 next_skill。
是否发生人类门禁。
是否发生自动推进。
是否发现 contract 缺口。
R2 branch_request 是否生成。
R2 checkpoint / state_transition / branch ledger 是否存在。
R2 resume_report 推荐从哪里继续。
```

---

## 11. 验收样例

### 11.1 Happy Path：无交接物，从热点开始

输入：

```text
用户：给示例行业观察号跑一条内容。
```

预期：

```text
读取账号档案。
如本轮换账号，先做账号档案对齐确认。
产品对象清楚后，路由到 hotspot-topic-research。
不写热点正文。
```

### 11.2 Missing Input：账号档案缺 P0

输入：

```text
用户：给新账号做热点。
```

预期：

```text
不进入热点搜索。
一次最多问 3 个口语化问题。
输出 account_profile_missing_or_incomplete 门禁。
```

### 11.3 Human Gate：用户选题

输入：

```text
topic_card 已生成，用户说：选 002。
```

预期：

```text
识别为选题确认。
把对应 topic_card 状态流转为 topic_selected_for_brief。
自动进入 content-brief-compiler。
不得问“是否生成 Brief”。
```

### 11.4 Auto Next：Brief 通过

输入：

```text
content_brief.brief_status = brief_pass
human_gate = no
```

预期：

```text
自动路由 copywriting-draft-writer。
不得要求用户回复“继续写口播”。
```

### 11.5 Failure Case：平台包完成但封面成品链未完成

输入：

```text
platform_package.package_status = package_pass
content_delivery_record 存在
cover_composition 不存在
final-delivery.html 不存在
```

预期：

```text
自动路由 cover-design-compiler，再进入 cover_review，最后进入 final-delivery-builder。
不得停在“确认采用”。
如果环境不能合成，写 prompt_only 和完整降级交付，不得绕过封面专项质检。
```

### 11.6 Branch Case：用户在产品设计中说“三篇都做”

输入：

```text
当前任务是产品开发，用户说：三篇都做。
```

预期：

```text
识别为旁支冲突。
不启动内容生产。
说明当前正在做产品定义，内容生产需要新 session 或用户明确切换任务。
```

### 11.7 R2 Fan-out：内容生产中用户说“三篇都做”

输入：

```text
当前 task_context_type=content_production，选题池有 T001 / T002 / T003，用户说：三篇都做。
```

预期：

```text
decision_type=branch_request。
生成 branch_request 和 human_decision_payload。
parent manifest 写 branch_request_status=branch_request_confirmed。
fan_out_status=fan_out_planned。
每个 topic 规划一个 child session。
写 intermediate/branch-request-ledger.md。
不得在同一 session 写三篇正文。
```

### 11.8 R2 Resume：断流恢复

输入：

```text
用户说：活了吗，刚刚断了。
```

预期：

```text
按 R2 恢复读取顺序读取状态。
输出 resume_report。
列出 do_not_rerun 和 safe_to_rerun。
如果 checkpoint 缺失，只说恢复证据不足，不声称脚本级断点续跑。
```

### 11.9 Checker：项目级只读检查

输入：

```text
用户说：做一次 R1-R4 只读 checker。
```

预期：

```text
check_scope=project。
读取 docs/reference/R1-R4只读checker执行规范.md。
读取 STATUS.md、工作流状态记录.md、README.md、PROJECT_MAP.md、路线图和字段词典。
生成 workflow_check_report。
只报告 blocker / warning / info，不自动修文件。
不得生成 public_release、不得推 GitHub、不得宣称 L3。
```

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - CONTRACT.md
    - 脱敏后的路由规则
    - sample workflow_session_record
  must_redact:
    - 真实账号档案
    - 真实内容运行记录
    - 真实图片资产
    - 真实产品未公开信息
  sample_required:
    - examples/sample-account/account_profile.md
    - examples/sample-run/manifest.yaml
    - examples/sample-run/intermediate/00-execution-trace.md
  external_dependency:
    - 无平台登录
    - 无自动发布 API
    - 无外部图片 API
```

公开 GitHub 版本必须把本合同和 sample run 放在一起，让新用户能看懂：

```text
输入是什么。
路由怎么判断。
哪些地方会停。
哪些地方自动往下走。
```

---

## 13. 待涛哥确认的产品问题

本合同草案建议确认三件事：

| 问题 | 推荐结论 |
|---|---|
| `propagation-router` 是否只做路由，不生产任何正文 | 是 |
| 平台包完成后是否仍然需要人工“确认采用” | 否，应自动进入最终 HTML，最终 HTML 才是人工验收点 |
| 用户在产品开发任务中抛内容生产指令，是否按旁支冲突拦住 | 是，除非用户明确切换任务 |

确认后，本合同状态可从 `draft` 改为 `confirmed`，再进入 `SKILL.md` 编译。



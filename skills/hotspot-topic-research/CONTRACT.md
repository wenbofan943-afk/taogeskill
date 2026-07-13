# Hotspot Topic Research Contract

> 状态：confirmed_for_compilation
> contract_version：0.2.0
> contract_set_version：r1-contract-set-v0.1
> 对应 skill：`skills/hotspot-topic-research/SKILL.md`
> 编译门禁：涛哥已确认 R1，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: hotspot-topic-research
skill_name: 热点选题研究
contract_version: 0.2.0
contract_set_version: r1-contract-set-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-06
```

一句话职责：

```text
在账号档案和产品 / 活动对象已确认后，完成热点来源调研、时效判断、母题桥接、评分和选题卡输出，停在 Topic Gate 等用户选题。
Topic Gate 面向用户时必须输出 `topic_selection_panel`，解释探索范围、候选漏斗、过滤原因、候选角色、默认推荐和选择代价。
```

R5-H2 policy contract:

```text
Read radar_policy_ref and query_lexicon_ref before research. If either is absent,
write account_policy_incomplete and do not claim account-strategy filtering.
used_car_priority_mode=direct_first means only fact-verifiable direct used-car
candidates count toward the direct pool. new-car spillover is enabled only when
that count is below new_car_spillover_threshold=3, and every spillover candidate
must carry at least one configured proof type. Exploratory terms may run without
per-term approval; blocked is reserved for exclusions, safety/compliance, or an
explicit user block. Selection feedback is assist evidence, not single-term causality.
```

R5-H3: `signal -> event -> candidate -> topic`; event merge needs subject, action, time window, location and business chain. fact_status, propagation_status and risk_level are independent. Trend needs two same-source comparable snapshots.

R5-H4: persist append-only term-selection-ledger and query-effectiveness records. Derived term status is reproducible: selected assists >=2 and greater than rejected => preferred; rejected assists >=2 and greater than selected => deprioritized; only an explicit policy/safety/user reason => blocked. Counts are assist evidence, never exclusive causality.

R5-H6: before this Skill begins, `propagation-router` must run the v0.2 `account_startup_check`. It first verifies one immutable `account_identity_id` / `account_technical_slug`, selected private root, bound asset digests and a current session snapshot; only then does it ask missing task fields, at most three plain-language questions at a time. `account_ready + identity_verified=true + snapshot_ready` is required to continue. `account_identity_inconsistent` is a hard migration / repair block, not a question and never a fallback to another account. Hotspot research treats missing visual identity as non-blocking; `account_policy_incomplete`, `account_needs_input`, and `account_blocked` do not enter source retrieval. High-risk topics default to `verify_mechanism_only`: cross-check facts and explain industry mechanisms, without a named conclusion.

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 找热点
    - 评热点
    - 今天做什么内容
    - 给某账号做选题
    - 先别写文案
  upstream_artifact_status:
    - account_profile_confirmed_for_session = yes
    - account_startup_check.startup_result = account_ready
    - account_startup_check.identity_verified = true
    - account_snapshot_status = snapshot_ready
    - product_profile_status = ready 或 campaign_profile_status = ready
  allowed_manual_commands:
    - 重找一轮
    - 只要行业趋势
    - 不要产品露出
```

不得触发：

```text
账号档案 P0 缺失。
换账号后尚未对齐账号档案。
产品 / 活动对象边界不清。
用户已明确选题并要求进入文案链路。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - account_profile
    - product_profile 或 campaign_profile
    - docs/reference/热点搜索来源池.md
    - 交接物字段词典.md
  required_fields:
    - account
    - target_audience
    - mother_topic
    - allowed_claims
    - forbidden_claims
    - conversion_goal 或 conversion_path
    - account_snapshot_ref
    - account_snapshot_status = snapshot_ready
  required_status:
    - account_profile_confirmed_for_session = yes
```

前置缺失时，输出人类引导，不进入热点搜索。

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - account_profile
    - product_profile
    - campaign_profile
    - source_pool
  source_path:
    - accounts/{account_slug}/account_profile.md
    - objects/products/{product_profile_id}.md
    - objects/campaigns/{campaign_profile_id}.md
    - docs/reference/热点搜索来源池.md
  required_fields:
    - account
    - account_positioning
    - target_audience
    - mother_topics
    - content_boundaries
    - product_allowed_claims
    - product_forbidden_claims
    - cta_boundary
  validation_rules:
    - 不从聊天记忆补账号定位
    - 需要最新热点时必须联网或有明确来源
    - 来源必须记录发布时间和热度信号
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type:
    - research_run_record
    - hotspot_candidate
    - topic_selection_panel
    - topic_card
  target_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/01-research-run.md
    - accounts/{account_slug}/runs/{session_id}/intermediate/02-topic-selection-panel.md
    - accounts/{account_slug}/runs/{session_id}/intermediate/02-topic-card.md
    - docs/reference/调研运行记录.md
    - docs/reference/热点候选池.md
    - docs/reference/热点评分表.md
    - docs/reference/自媒体选题库.md
  required_fields:
    - research_run_id
    - topic_selection_panel_id
    - topic_id
    - source_research_run_id
    - hotspot_time_window
    - hotspot_freshness_status
    - content_position
    - source
    - source_time
    - heat_signal
    - fact_level
    - derivation_chain
    - weakest_jump
    - gate_result
    - panel_status
    - exploration_scope_summary
    - source_scope_summary
    - time_window_summary
    - raw_candidate_count
    - scored_candidate_count
    - main_recommendation_count
    - degraded_candidate_count
    - rejected_candidate_count
    - filtered_reason_summary
    - recommended_topic_id
    - topic_option_ids
    - topic_role_map
    - selection_tradeoff_map
    - recommendation_reason
    - topic_status
    - human_prompt
    - human_reply_examples
    - decision_type
    - next_skill
    - artifact_path
  status_field:
    - panel_status
    - topic_status
  allowed_status_values:
    panel_status:
      - panel_draft
      - panel_ready_waiting_human
      - panel_selected
      - panel_needs_rerun
      - panel_archived
  downstream_artifact:
    - topic_selection_panel
    - topic_card
```

合格输出必须让用户能直接选择 `topic_id`，并能看懂为什么推荐这些 `topic_id`。

---

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  output_paths:
    research_run: intermediate/01-research-run.md
    topic_selection_panel: intermediate/02-topic-selection-panel.md
    topic_card: intermediate/02-topic-card.md
  index_paths:
    - docs/reference/调研运行记录.md
    - docs/reference/热点候选池.md
    - docs/reference/热点评分表.md
    - docs/reference/自媒体选题库.md
```

根目录汇总表只做索引和摘要；完整正文以 session 文件为准。

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - user_selected_topic_id
  next_skill:
    user_selected_topic_id: content-brief-compiler
  forbidden_human_prompt:
    - 是否生成 Brief？
    - 是否继续写文案？
```

本 skill 默认停在 Topic Gate，因为选题必须由人选。
用户一旦明确选择 topic_id，后续由 router 自动进入 `content-brief-compiler`。

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: topic_gate
    trigger: 候选选题已生成
    reason: 选题方向必须由人判断
    recommended_action: 先展示 topic_selection_panel，再推荐一个主选题，并给备选和重找选项
    human_reply_examples:
      - 选 T20260706-001
      - 002
      - 三篇都做
      - 重找一轮
    auto_next_after_reply: content-brief-compiler 或 multi_content_fan_out
```

引导语必须说明：本轮探索了什么、为什么只给这几个候选、默认推荐哪个、选不同候选的收益和代价。选中后会自动进入 Brief、文案、画中画、质检和最终交付，不需要用户说“继续”。

---

## 9. 失败处理

```yaml
failure_modes:
  missing_account_profile:
    recovery_action: 回到账号档案 P0 补齐
  account_not_reconfirmed:
    recovery_action: 输出账号档案摘要，等待认可 / 同意
  product_boundary_missing:
    recovery_action: 补 product_profile / campaign_profile 最小字段
  source_unverified:
    recovery_action: 降低 fact_level，不进入强热点表达
  stale_hotspot:
    recovery_action: 降级为 industry_trend / review / evergreen_problem / methodology
  bridge_too_weak:
    recovery_action: 标记 weakest_jump，不推荐为主选题
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - 来源调研
    - 时效字段判断
    - 候选评分
    - Topic Gate
  agent_orchestrated:
    - 临时新增来源池
    - 临时补目录或字段
  environment_capability:
    - web_search
```

若本轮联网，必须记录来源链接、查询时间和事实等级。

---

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | 账号和产品对象齐全，用户要找热点 | 生成 research_run 和 3-5 张 topic_card，停在 Topic Gate |
| p1_selection_panel | 账号和产品对象齐全，候选题已评分 | 生成 topic_selection_panel，展示候选漏斗、过滤原因、topic_role_map、selection_tradeoff_map 和 recommended_topic_id |
| missing_account | 用户给新账号，无档案 | 不找热点，先补账号 P0 |
| switch_account | 上轮账号 A，本轮账号 B | 先做账号档案对齐 |
| stale_hotspot | 来源超过时效窗口 | 降级为行业趋势或复盘，不硬叫热点 |
| selected_topic | 用户回复“选 002” | topic_status -> topic_selected_for_brief，自动进入 Brief |

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - 合同
    - 脱敏选题样例
    - sample source notes
  must_redact:
    - 真实账号策略
    - 真实未公开产品信息
    - 未授权外部资料全文
  sample_required:
    - examples/sample-run/intermediate/01-research-run.md
    - examples/sample-run/intermediate/02-topic-card.md
```

---

## 13. 待确认点

| 问题 | 推荐结论 |
|---|---|
| 热点研究是否默认停在 Topic Gate | 是 |
| 用户选题后是否自动进入 Brief | 是 |
| 过期热点是否必须降级 | 是 |

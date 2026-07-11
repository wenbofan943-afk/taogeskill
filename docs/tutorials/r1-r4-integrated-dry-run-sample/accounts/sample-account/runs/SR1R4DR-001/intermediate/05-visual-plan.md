# Visual Plan

```yaml
visual_plan_id: VP-SR1R4DR-001
draft_id: D-SR1R4DR-001
research_run_id: R-SR1R4DR-001
visual_plan_status: visual_plan_ready
image_prompt_set_id: IPS-SR1R4DR-001
visual_need_analysis_id: VN-SR1R4DR-001
visual_count_policy: content_derived_unbounded
generation_policy: generate_all_accepted
derived_visual_count: 1
```

## Visual Need Analysis

```yaml
visual_need_analysis_id: VN-SR1R4DR-001
audience_profile_ref: examples/sample-account/account_profile.md
audience_prior_knowledge: mixed
platform_viewing_context: mobile_feed
provider_call_limit: null
cost_gate: not_applicable
candidates:
  - visual_need_candidate_id: VNC-SR1R4DR-001-001
    beat_id: BEAT-SR1R4DR-001-001
    covered_beat_ids: [BEAT-SR1R4DR-001-001]
    trigger_text: 很多本地经营者现在最累的地方，不是车不好卖，而是解释不完
    insert_after_text: 你发现没有，很多本地经营者现在最累的地方，不是车不好卖，而是解释不完。
    insert_before_text: 客户一上来就问：这车有没有事故？
    viewer_problem_without_visual: 口播中的问题堆积压力仍然抽象，陌生观众难以在首屏形成现场感
    attention_risk_without_visual: high
    comprehension_risk_without_visual: medium
    primary_visual_job: hook_amplification
    supporting_visual_jobs: [emotion_amplification]
    expected_viewer_change: 一眼感受到经营者面对问题堆积的压力
    information_added: 同时呈现多个问题类别和人物处境
    why_image_is_better_than_talking_head: 场景能并列展示问题，而无需口播逐条枚举
    attention_trigger_basis: specific_content_risk
    emotion_congruence_status: aligned
    evidence_requirement: generated_context_only
    evidence_source_type: null
    evidence_source_id: null
    evidence_source_path: null
    redundancy_status: unique
    cognitive_load_risk: low
    misleading_risk: low
    visual_need_decision: generate
    decision_reason: 首屏画面承担真实的 Hook 和情绪任务
  - visual_need_candidate_id: VNC-SR1R4DR-001-002
    beat_id: BEAT-SR1R4DR-001-002
    covered_beat_ids: [BEAT-SR1R4DR-001-002]
    trigger_text: 评论区问题就是信任缺口清单
    insert_after_text: 客户的问题其实都在暴露信任缺口。
    insert_before_text: 所以先把解释材料准备好。
    viewer_problem_without_visual: 首图已经覆盖问题堆积，第二张图没有新增损失
    attention_risk_without_visual: low
    comprehension_risk_without_visual: low
    primary_visual_job: concept_explanation
    supporting_visual_jobs: []
    expected_viewer_change: 无独立增量
    information_added: 与首图重复
    why_image_is_better_than_talking_head: 不成立
    attention_trigger_basis: not_applicable
    emotion_congruence_status: not_applicable
    evidence_requirement: not_applicable
    evidence_source_type: null
    evidence_source_id: null
    evidence_source_path: null
    redundancy_status: duplicates_other_visual
    cognitive_load_risk: medium
    misleading_risk: low
    visual_need_decision: reject
    decision_reason: 评论区信任缺口已由首图和口播说明，第二张图会重复
accepted_visual_tasks:
  - image_task_id: IMG-TASK-SR1R4DR-001
    visual_need_candidate_id: VNC-SR1R4DR-001-001
    beat_id: BEAT-SR1R4DR-001-001
    primary_visual_job: hook_amplification
    generation_intent: render_now
    provider_route: codex_builtin_image2
rejected_visual_candidate_ids: [VNC-SR1R4DR-001-002]
derived_visual_count: 1
zero_visual_reason: null
visual_need_analysis_status: pass
```

## First Screen Visual Task

```text
把“解释不完”的疲惫感视觉化，帮助前 5 秒留住二手本地经营者。
```

## Accepted Visual Task

```yaml
image_prompt_id: IP-SR1R4DR-001
image_task_id: IMG-TASK-SR1R4DR-001
visual_need_candidate_id: VNC-SR1R4DR-001-001
primary_visual_job: hook_amplification
insert_after_text: 你发现没有，很多本地经营者现在最累的地方，不是车不好卖，而是解释不完。
insert_before_text: 客户一上来就问：这车有没有事故？
aspect_ratio: 16:9
prompt_card:
  scene: 本地服务展厅办公桌上，屏幕和便签堆满客户问题
  subject: 一位本地经营者坐在桌前，看着密密麻麻的问题列表
  important_details: 便签上写着事故、公里数、价格、售后、来源；画面干净，不能出现真实品牌或车牌
  use_case: 短视频口播画中画首屏辅助图
  constraints: 不要夸张漫画感，不要真实个人信息，不要平台 UI 截图，不要暗示自动私信
```

## Rejected Visual Candidate

```yaml
image_prompt_id: IP-SR1R4DR-002
visual_need_candidate_id: VNC-SR1R4DR-001-002
visual_need_decision: reject
decision_reason: 与首图和口播重复，不进入 prompt/provider
```



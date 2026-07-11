# Sample Visual Plan

## Static Visual Director Plan

```yaml
static_visual_director_plan_id: SVDP-SR3DR-001
draft_id: D-SR3DR-001
brief_id: B-SR3DR-001
source_research_run_id: R-SR3DR-001
account: sample-account
content_duration_estimate: 28s
visual_need_analysis_id: VN-SR3DR-001
first_screen_visual_task: stop_scroll_by_showing_wrong_vs_right_pip_logic
visual_language: 现实主义商业纪录片感，手机竖屏，小屏一眼看懂，少文字
style_anchor: cold office light, phone screen glow, documentary desk scene
composition_strategy: 左右对比，右侧更清晰有秩序，上方留字幕安全区
cover_strategy_hint: 用右侧“有任务的画中画规划卡片”作为封面图候选，封面文字不超过 8 个字
static_visual_director_status: director_plan_pass
artifact_path: intermediate/05-visual-plan.md
next_skill: image-prompt-compiler
```

| image_task_id | image_asset_type | visual_role | retention_task | composition_note |
|---|---|---|---|---|
| IMGTASK-SR3DR-001-001 | picture_in_picture_image | hook_conflict | 停住划走 | 左侧杂乱配图 vs 右侧任务化画中画规划 |
| COVER-SR3DR-001-001 | cover_image | hook_conflict | 第一眼理解 | 复用右侧任务化规划卡，保留大字安全区 |

```yaml
visual_plan_id: VP-SR3DR-001
static_visual_director_plan_id: SVDP-SR3DR-001
draft_id: D-SR3DR-001
brief_id: B-SR3DR-001
source_research_run_id: R-SR3DR-001
contract_set_version: r3-asset-runtime-v0.3
visual_need_analysis_id: VN-SR3DR-001
visual_count_policy: content_derived_unbounded
derived_visual_count: 1
visual_text_plan_id: VTP-SR3DR-001
visual_plan_status: visual_plan_pass
image_prompt_set_id: IPS-SR3DR-001
image_asset_set_id: IMGSET-SR3DR-001
image_asset_type_plan:
  - picture_in_picture_image
  - cover_image
next_skill: image-prompt-compiler
```

## Visual Text Plan

```yaml
visual_text_plan_id: VTP-SR3DR-001
static_visual_director_plan_id: SVDP-SR3DR-001
visual_plan_id: VP-SR3DR-001
draft_id: D-SR3DR-001
source_research_run_id: R-SR3DR-001
narration_source_type: draft_script_text
narration_source_path: intermediate/04-draft.md
subtitle_source_status: not_available
subtitle_source_path:
visual_text_tasks:
  - visual_text_task_id: VTT-SR3DR-001-001
    image_task_id: IMGTASK-SR3DR-001-001
    beat_id: B-SR3DR-001-01
    visual_text_decision: forbidden
    decision_reason: 左右场景与构图已经能表达普通配图和任务图的差别，额外画面文字只会与口播重复
    visual_text_units: []
    task_information_delta_summary: 图像关系承担信息，不增加文字层
    semantic_delta_score:
    effective_information_gain: medium
    visual_text_redundancy_status: pass
    cognitive_load_status: pass
    source_binding_summary_status: not_required
    visual_text_task_status: visual_text_task_pass
required_text_task_count: 0
optional_text_task_count: 0
forbidden_text_task_count: 1
source_bound_task_count: 0
plan_information_delta_summary: 通过无字对比画面增加结构信息，不复写口播
visual_text_plan_status: visual_text_plan_pass
next_skill: image-prompt-compiler
```

## Visual Need Analysis

```yaml
schema_id: taoge://schemas/r3/visual-need-analysis/v0.1
schema_version: "0.1"
visual_need_analysis_id: VN-SR3DR-001
static_visual_director_plan_id: SVDP-SR3DR-001
draft_id: D-SR3DR-001
source_research_run_id: R-SR3DR-001
account: sample-account
audience_profile_ref: examples/sample-account/account_profile.md
audience_prior_knowledge: mixed
platform_viewing_context: mobile_feed
visual_count_policy: content_derived_unbounded
generation_policy: generate_all_accepted
codex_provider: codex_builtin_image2
cost_gate: not_applicable
provider_call_limit: null
cover_count_excluded: true
semantic_beats:
  - beat_id: B-SR3DR-001-01
    script_range: 开头观点
    beat_purpose: 解释画中画必须承担观看任务
    viewer_state_before: 以为画中画只是装饰
    viewer_state_after: 理解画中画必须解决具体问题
candidates:
  - visual_need_candidate_id: VNC-SR3DR-001-001
    beat_id: B-SR3DR-001-01
    covered_beat_ids: [B-SR3DR-001-01]
    trigger_text: 这张图到底帮观众多停哪 2 秒
    insert_after_text: 别急着给短视频加图，先问一句：
    insert_before_text: 如果一张图只是好看，但和这句话没关系
    viewer_problem_without_visual: 开头只剩抽象概念，陌生流量用户难以立即区分装饰图和任务图
    attention_risk_without_visual: high
    comprehension_risk_without_visual: medium
    primary_visual_job: hook_amplification
    supporting_visual_jobs: [concept_explanation]
    expected_viewer_change: 首屏立即看懂错误配图和任务化配图的差别
    information_added: 用左右对比组织口播中的抽象差异
    why_image_is_better_than_talking_head: 两种配图状态可以同时呈现并快速比较
    attention_trigger_basis: specific_content_risk
    emotion_congruence_status: not_applicable
    evidence_requirement: not_applicable
    evidence_source_type: null
    evidence_source_id: null
    evidence_source_path: null
    redundancy_status: unique
    cognitive_load_risk: low
    misleading_risk: low
    visual_need_decision: generate
    decision_reason: 首屏视觉对比同时承担 Hook 放大和概念解释
accepted_visual_tasks:
  - image_task_id: IMGTASK-SR3DR-001-001
    visual_need_candidate_id: VNC-SR3DR-001-001
    beat_id: B-SR3DR-001-01
    primary_visual_job: hook_amplification
    generation_intent: render_now
    provider_route: codex_builtin_image2
rejected_visual_candidate_ids: []
derived_visual_count: 1
zero_visual_reason: null
visual_need_analysis_status: pass
```

## First Screen Visual Task

```yaml
first_screen_visual_task: stop_scroll_by_showing_wrong_vs_right_pip_logic
retention_task: 停住划走
visual_language: 现实主义商业纪录片感，手机竖屏，小屏一眼看懂，少文字
```

## Beats

| beat_id | 口播对应 | 留存风险 | visual_need_decision | primary_visual_job | insert_after_text | insert_before_text |
|---|---|---|---|---|---|---|
| B-SR3DR-001-01 | 别急着给短视频加图，先问一句：这张图到底帮观众多停哪 2 秒？ | 开头概念抽象，用户可能以为只是配图 | generate | hook_amplification | 别急着给短视频加图，先问一句： | 如果一张图只是好看，但和这句话没关系 |

## Accepted Visual Tasks

```yaml
- image_task_id: IMGTASK-SR3DR-001-001
  image_asset_type: picture_in_picture_image
  image_production_path: seedream_prompt_delivery
  image_generation_decision: deliver_prompt_only
  prompt_delivery_mode: html_copyable_prompt
  beat_id: B-SR3DR-001-01
  source_prompt_id: PROMPT-SR3DR-001-001
  visual_text_task_id: VTT-SR3DR-001-001
  visual_text_decision: forbidden
  visual_need_candidate_id: VNC-SR3DR-001-001
  primary_visual_job: hook_amplification
  visual_type: 对比图
  why_generate: 把“装饰图”和“留存任务图”的差别在首屏讲清，降低抽象感
  loss_if_missing: 开头只剩概念解释，观众可能不知道为什么要继续听
  insert_after_text: 别急着给短视频加图，先问一句：
  insert_before_text: 如果一张图只是好看，但和这句话没关系
  prompt_integrity_check: pass
```

## Image Prompt Set

### PROMPT-SR3DR-001-001

```yaml
model: generic_image_model
image_task_id: IMGTASK-SR3DR-001-001
visual_text_task_id: VTT-SR3DR-001-001
visual_text_decision: forbidden
visual_text_units: []
provider: seedream-5.0
provider_mode: not_available
image_asset_type: picture_in_picture_image
image_production_path: seedream_prompt_delivery
image_generation_decision: deliver_prompt_only
prompt_delivery_mode: html_copyable_prompt
external_model_payload_path: assets/images/generation-records/GEN-SR3DR-001-001.md
quality: medium
aspect_ratio: 9:16
allow_text_in_image: false
prompt_integrity_check: pass
```

用途：短视频口播首屏画中画。  
口播对应：这张图到底帮观众多停哪 2 秒？  
留存风险：概念抽象，用户以为画中画只是好看的配图。  
留人任务：停住划走。  
画面类型：对比图。  
为什么值得生成：用一个可视对比让用户立刻理解“装饰图”和“任务图”的差别。  
不用这张图会损失什么：开头解释会偏概念，缺少停顿点和视觉抓手。

五槽提示词：

```text
Scene: 竖屏短视频剪辑台的真实工作场景，桌面上有一台笔记本和一部手机，手机画面分成左右两侧对比。
Subject: 左侧是杂乱的通用配图缩略图，右侧是带有清晰插入点标记和留存任务标签的画中画规划卡片。
Important Details: 现实主义商业纪录片感，冷白办公灯，手机屏幕光，右侧更清晰有秩序，画面上方留字幕安全区，不出现真实平台 logo、手机号、微信号、车牌或真实用户信息。
Use Case: 短视频口播首屏画中画，用来解释“画中画不是装饰，而是留存任务”。
Constraints: 不要夸张科幻，不要真实品牌界面，不要密集中文小字，不要水印，不要平台后台截图。
```

负面提示：

```text
no real phone numbers, no WeChat ID, no license plate, no platform logo, no watermark, no dense unreadable Chinese text, no fake analytics dashboard
```

验收标准：

```text
9:16 小屏能一眼看出左右对比。
右侧必须更像“有任务的画中画规划”，不是普通配图。
画面不暗示任何未实现产品能力。
```

# Sample Visual Plan

```yaml
visual_plan_id: VP-SR3DR-001
static_visual_director_plan_id: SVDP-SR3DR-001
draft_id: D-SR3DR-001
brief_id: B-SR3DR-001
source_research_run_id: R-SR3DR-001
contract_set_version: r3-asset-runtime-v0.2
visual_text_plan_id: VTP-SR3DR-001
visual_plan_status: visual_plan_pass
image_prompt_set_id: IPS-SR3DR-001
image_asset_set_id: IMGSET-SR3DR-001
image_asset_type_plan:
  - picture_in_picture_image
  - cover_image
next_skill: copywriting-quality-review
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

## Visual Budget

```yaml
duration_estimate: 28s
budget_rule: 30 秒以内，单观点
required_visuals_count: 1
optional_visuals_count: 1
reduction_reason: dry-run 只验证一张 required 图的最小资产链；正式内容仍按 R3 视觉预算执行
```

## First Screen Visual Task

```yaml
first_screen_visual_task: stop_scroll_by_showing_wrong_vs_right_pip_logic
retention_task: 停住划走
visual_language: 现实主义商业纪录片感，手机竖屏，小屏一眼看懂，少文字
```

## Beats

| beat_id | 口播对应 | 留存风险 | visual_need | retention_task | insert_after_text | insert_before_text |
|---|---|---|---|---|---|---|
| B-SR3DR-001-01 | 别急着给短视频加图，先问一句：这张图到底帮观众多停哪 2 秒？ | 开头概念抽象，用户可能以为只是配图 | required | 停住划走 | 别急着给短视频加图，先问一句： | 如果一张图只是好看，但和这句话没关系 |

## Required Visuals

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
  visual_need: required
  retention_task: 停住划走
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

# 内容交付记录

- delivery_id：DEL20260706-002
- package_id：PK20260706-002
- package_input_id：PI20260706-002
- review_id：Q20260706-002
- visual_plan_id：V20260706-002
- draft_id：D20260706-002
- brief_id：B20260706-002
- topic_id：T20260706-002
- product_profile_id：P-public-interaction-tool
- campaign_profile_id：C-free-learning-trial
- source_research_run_id：R20260706-001
- account：涛哥车商自媒
- topic_title：车商别再只卷价格了，2026 年要卷信任
- strategy：垂类获客型；用行业趋势观点做切口
- content_format：短视频口播
- target_platforms：抖音 / 快手 / 小红书 / 视频号

## 推荐交付摘要

- 推荐口播主标题：价格战改不了，这事你能改
- 推荐核心 Hook：价格战这件事，小车商改不了，但客户问过的问题，你不能让它白白流走。
- 推荐首屏画面：价格战 / 信任战对比图，左侧价格压力，右侧客户问题沉淀成复盘表。
- 推荐平台组合：
  - 抖音：封面“价格战改不了，这事你能改”；标题“车商卷不过价格战，但可以卷信任资产”
  - 快手：封面“车商老板，别光盯价格”；标题“每天回复一堆客户问题，不整理就白忙了”
  - 小红书：封面“车商信任感怎么做？先整理客户问题”；标题“车商做自媒体，别只发车源，先做一张客户问题复盘表”
  - 视频号：封面“价格战之外，车商还能做什么”；标题“价格战改不了，但车商可以先把客户问题整理清楚”

## artifact_paths

```text
account_snapshot：accounts/涛哥车商自媒/runs/S20260706-001/inputs/account_snapshot.md
product_snapshot：accounts/涛哥车商自媒/runs/S20260706-001/inputs/product_snapshot.md
campaign_snapshot：accounts/涛哥车商自媒/runs/S20260706-001/inputs/campaign_snapshot.md
research_run：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/01-research-run.md
topic_card：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/02-topic-card.md
content_brief：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/03-content-brief.md
draft：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/04-draft.md
visual_plan：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/05-visual-plan.md
quality_review：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/06-quality-review.md
platform_package_input：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/07-platform-package-input.md
platform_package：accounts/涛哥车商自媒/runs/S20260706-001/intermediate/08-platform-package-draft.md
content_delivery_record：accounts/涛哥车商自媒/runs/S20260706-001/deliverables/content-delivery-record.md
final_script：accounts/涛哥车商自媒/runs/S20260706-001/deliverables/final-script.md
final_visual_plan：accounts/涛哥车商自媒/runs/S20260706-001/deliverables/final-visual-plan.md
final_platform_package：accounts/涛哥车商自媒/runs/S20260706-001/deliverables/final-platform-package.md
final_delivery_html：accounts/涛哥车商自媒/runs/S20260706-001/deliverables/final-delivery.html
image_assets：accounts/涛哥车商自媒/runs/S20260706-001/assets/images/image-assets.md
B1_image：accounts/涛哥车商自媒/runs/S20260706-001/assets/images/B1-hook-price-vs-trust.png
B3_image：accounts/涛哥车商自媒/runs/S20260706-001/assets/images/B3-customer-questions.png
B6_image：accounts/涛哥车商自媒/runs/S20260706-001/assets/images/B6-public-interaction-review.png
```

## 人工处理状态

- human_decision：confirmed
- revision_path：none
- delivery_status：delivery_confirmed
- approval_status：approval_approved
- publish_status：publish_not_started
- delivery_page_mode：project_local
- final_delivery_status：html_ready
- image_assets_status：generated
- export_status：not_requested
- next_skill：done

## human_prompt

这条内容已确认采用，并已固化为最终 HTML 交付页。当前不执行自动发布；如需发布，后续由人工按平台自行操作，并可回填发布结果。

## human_reply_examples

回填发布链接 / 记录发布结果 / 开始下一条内容

## 边界说明

```text
本记录不代表已发布。
本记录不触发自动发布。
本记录不登录任何平台。
本记录不自动评论、私信或互动。
deliverables/ 下 final-script.md、final-visual-plan.md 和 final-platform-package.md 为人工确认后的最终交付物。
deliverables/final-delivery.html 是人类验收入口，整合选题切口、正式文案、画中画图片和平台发布物料。
assets/images/ 下图片为 Codex 内置 image 生成的画中画素材，未上传任何平台。
当前 final-delivery.html 是 project_local 形态；如果要发给别人、传网盘或离开本项目目录使用，需要另行生成 portable_bundle 或 standalone_html。
```

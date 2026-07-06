---
name: propagation-router
description: 涛哥创作工作流的传播 skill 总控；“涛哥”是作者/方法论署名，不是目标账号。Use when Codex is asked to “涛哥 skill / 涛哥创作工作流 / 传播总控 / 热点 skill / 做自媒体传播 / 下一步走哪个传播 skill / dbskill 式路由 / 帮我判断先做热点、文案还是质检”。只负责路由、交接物检查和下一步建议，不写正文、不做发布、不改代码。
---

# Propagation Router

## 定位

本 skill 是“涛哥创作工作流”的传播入口，类似 dbskill 的 `/dbs`：只做路由和导航，不做具体诊断和文案。

命名口径：

```text
技术名：propagation-router
中文总名：涛哥创作工作流
含义：涛哥作为作者/方法论署名沉淀的一套内容创作流程
不是：只给“涛哥账号”做内容、只服务某一个账号、只做热点文案
```

它负责：

```text
识别用户意图
-> 判断当前交接物是否齐全
-> 路由到专项 skill
-> 在专项 skill 完成后推荐下一步
```

它不负责：找热点、写文案、改稿、发布、落盘、改页面、调用平台 API。

## 必读

每次触发先读：

```text
README.md
账号档案完整性检查表.md
产品与活动对象档案.md
交接物字段词典.md
热点文案Skill方法论与SaaS承接设计.md
工作流状态记录.md
```

按需读：

```text
skills/hotspot-topic-research/SKILL.md
skills/content-brief-compiler/SKILL.md
skills/copywriting-draft-writer/SKILL.md
skills/talking-head-image-pip/SKILL.md
skills/copywriting-quality-review/SKILL.md
skills/platform-packaging-adapter/SKILL.md
skills/hotspot-copywriting-research/SKILL.md
```

## 路由表

| 用户意图 | 路由 | 原因 |
|---|---|---|
| 找热点、评热点、今日选题、母题关联、推导链 | `hotspot-topic-research` | 产出热点候选、评分表、选题卡和推导链 |
| 已选题、选 T001、准备写文案、先生成写作输入包 | `content-brief-compiler` | 把已选 topic_card 编译成内容 Brief，防止写稿时失忆、串号、硬卖产品或承诺越界 |
| Brief 已通过，要写草稿 | `copywriting-draft-writer` | 第一阶段默认生成短视频口播草案；图文、长文、朋友圈、社群、FAQ 和官网说明先保留未来路由，不展开制作办法 |
| 已有口播草案，要做画中画 / image 提示词 | `talking-head-image-pip` | 口播是第一阶段主路径，画中画用于补足口播的信息、情绪和热点画面 |
| 已有文案和画中画策略，问能不能发、哪里会划走、有没有 AI 味、像不像涛哥、有没有产品风险 | `copywriting-quality-review` | 做文案 + 视觉联合质检、风险、口播流畅度和下一步 |
| 质检已通过，要发抖音 / 快手 / 小红书 / 视频号，或要封面标题、视频标题、发布描述、话题标签 | `platform-packaging-adapter` | 同一条视频主体不重做；先编译 `platform_package_input`，再生成入口包装和内容交付记录 |
| 已有多平台分发包 | `platform-packaging-adapter` -> `final-delivery-builder` | 先生成或检查 `content_delivery_record`，再自动生成最终 HTML 验收页 |
| 不知道下一步 | 本 skill | 根据已有交接物推荐 2-3 个下一步 |
| 要保存本轮结论、接着上次、恢复状态、整理报告 | 本 skill | 读写 `workflow_session_record`，做轻量 save / restore / report，不另建发布后台 |

## 交接物检查

拆 skill 的稳定性来自固定交接物。路由前先判断用户当前有什么：

```text
无交接物：先检查 account_profile 和 product_profile / campaign_profile，再从 hotspot-topic-research 开始。
有完整 topic_card 且已被涛哥选择，状态为“已选择，待生成 Brief”：进入 content-brief-compiler。
有 topic_card 但字段不完整：回到 hotspot-topic-research 补齐选题卡字段。
有 content_brief 且 brief_status = brief_pass：进入 copywriting-draft-writer，第一阶段默认短视频口播草案。
有 draft 且 draft_status = draft_created：进入 talking-head-image-pip。
有 draft + visual_plan 且 visual_plan_status = visual_plan_pass：进入 copywriting-quality-review。
有 quality_review 且 review_status = review_pass：进入 platform-packaging-adapter，先编译 platform_package_input，再生成多平台入口包装。
有 platform_package_input 且 input_status = input_pass：继续由 platform-packaging-adapter 生成 platform_package。
有 platform_package 且 package_status = package_pass：先生成 content_delivery_record，不直接停在“等待确认”。
有 content_delivery_record 且 delivery_status = delivery_ready：`next_skill = final-delivery-builder`，自动生成最终 HTML 验收页。
有 content_delivery_record 且 delivery_status = delivery_confirmed / delivery_archived / delivery_discarded：`next_skill = done`，本轮工作流收口。
有 workflow_session_record 且 session_status = session_ready_to_restore：先恢复 current_stage 和 current_artifact，再路由到对应 skill。
有 quality_review 且未通过：按 next_skill 或 blocking_issues 回退。
```

热点类任务还必须先检查账号：

```text
用户没说账号 -> 先问“这次面向哪个账号 / 品牌 / 产品来做？”
用户说了账号 -> 查 accounts/{账号名}/account_profile.md
账号档案不存在或 P0 缺失 -> 先进入账号档案补齐，不进入热点搜索
账号档案 P0 齐全但产品/活动对象不清 -> 先补 product_profile / campaign_profile
账号档案 P0 齐全且产品/活动对象清楚 -> 路由 hotspot-topic-research
```

注意：这里的“账号”是内容发布或业务承接对象，和“涛哥创作工作流”这个作者署名不是一回事。

账号档案固定位置：

```text
accounts/{账号名}/account_profile.md
```

如果需要补账号档案，必须使用 `账号档案完整性检查表.md` 的口语化问法：

```text
一次最多问 3 个问题。
不直接问字段黑话。
用户回答后先做落盘质检，再归纳落盘。
回答不相关、过度模糊、像玩笑或和字段不匹配时，不落盘，先追问。
```

## 交接物字段

字段以 `交接物字段词典.md` 为唯一基准。本节只保留路由摘要；如果字段名冲突，以词典为准。

### product_profile / campaign_profile

```text
product_profile_id
campaign_profile_id
product_name / campaign_name
target_audience
allowed_claims
forbidden_claims
conversion_goal / conversion_path
cta_boundary
product_profile_status / campaign_profile_status
next_skill
```

### topic_card

```text
topic_id
source_research_run_id
product_profile_id
campaign_profile_id
账号
topic_title
hotspot
hotspot_pool
source
source_time
heat_signal
fact_level
lifecycle
target_audience
mother_topic
strategy
product_capability
bridge_status
gate_result
derivation_chain
weakest_jump
must_not_say
risk_notes
content_format
topic_status
next_skill
```

### content_brief

```text
brief_id
topic_id
account
content_goal
target_audience
core_point
ip_assets_used
product_claim_boundary
content_format
success_metric
human_gate
brief_status
next_skill
```

### draft

```text
draft_id
brief_id
content_format
title_options
recommended_hook
script
cta
product_mention
risk_notes
draft_status
next_skill
```

第一阶段 `content_format` 默认 `短视频口播`。其他形式只保留未来路由，不在本阶段默认制作。

### visual_plan

```text
visual_plan_id
draft_id
brief_id
beats
visual_strategy
pip_table
image_prompts
negative_prompts
edit_notes
visual_plan_status
next_skill
```

### quality_review

```text
review_id
draft_id
review_status
blocking_issues
suggestions
next_skill
```

### platform_package_input

```text
package_input_id
account
brand_or_product
content_goal
target_audience
target_platforms
core_topic
core_point
recommended_hook
first_5_seconds_script
first_screen_visual_task
video_body_summary
visual_style_summary
product_mention_level
product_claim_boundary
must_not_say
risk_words
cta
platform_goals
source_review_id
input_status
next_skill
```

### platform_package

```text
package_id
package_input_id
review_id
target_platforms
cover_title_options
video_title_options
publish_description_options
hashtag_sets
recommended_package
platform_goal
risk_notes
manual_publish_notes
package_status
next_skill
```

### content_delivery_record

```text
delivery_id
package_id
package_input_id
review_id
visual_plan_id
draft_id
brief_id
topic_id
account
topic_title
strategy
content_format
target_platforms
recommended_package_summary
artifact_paths
human_decision
revision_path
delivery_status
next_skill
human_prompt
human_reply_examples
```

`content_delivery_record` 是工作流收口交接物，不是发布记录。它只回答三件事：

```text
这条内容做到哪里了？
涛哥现在能怎么处理？
如果要改，应该回到哪一环？
```

如果缺少 `human_prompt` 或 `human_reply_examples`，不能算收口完成。

### workflow_session_record

```text
session_id
account
started_at
updated_at
current_stage
current_artifact
artifact_ids
last_decision
blocked_reason
next_recommended_actions
human_prompt
human_reply_examples
session_status
```

`workflow_session_record` 是轻量版状态保存。它只记录接续信息，不保存完整正文。用户说“接着上次 / 回到 workflow / 刚刚做到哪了”时，先读它。

使用规则：

```text
专项 skill 完成后，如果需要等待人类选择，写 session_waiting_human。
本轮可以继续自动推进，写 session_active。
最终 HTML 完成后，写 session_completed 或 final_delivery_ready；用户归档或放弃，写 session_archived。
下一次恢复时，先看 current_stage，再读取 current_artifact 指向的交接物。
current_artifact 必须优先指向 accounts/{账号名}/runs/{session_id}/ 下的具体文件，不指向根目录汇总表。
```

任务后导航必须学习 dbskill 的做法，并遵守 `docs/reference/人类引导与任务后导航规范.md`：不是只说“完成了”，而是读本轮结论，推荐 2-3 个下一步，并解释为什么。

## 输出格式

```markdown
# 传播总控判断

## 当前阶段
{无交接物 / 已有选题 / 已有草案 / 已有质检}

## 缺什么
- {缺口}

## 账号检查
- 账号：
- 档案：
- 结论：

## 需要补档案时
1. {口语化问题}
2. {口语化问题}
3. {口语化问题}

## 用户回答后的落盘质检
| 目标字段 | 用户回答 | 质检结论 | 处理 |
|---|---|---|---|

## 推荐下一步
1. {skill 或动作}：{为什么}
2. {skill 或动作}：{为什么}
3. {skill 或动作}：{为什么}

## 不建议现在做
- {动作}：{原因}

## 需要涛哥确认时
- delivery_status：
- next_skill：
- human_prompt：
- human_reply_examples：
- recommended_action：
- auto_next_action：
- task_after_navigation：

## 工作流状态记录
- session_id：
- current_stage：
- current_artifact：
- artifact_ids：
- last_decision：
- session_status：
```

如果用户明确说要继续某条路，优先按用户选择走，不用反复问。

如果用户的选择已经足够明确，例如“选 T002”“只改抖音标题”“导出转交包”，直接流转到对应 skill 或返工节点，不得再追问“是否继续 / 是否生成 / 是否确认”。

确认引导语必须像人话，不能像系统指令。优先使用这种格式：

```text
最终 HTML 验收页已经生成。你可以直接复制文案、下载图片、拿平台物料去人工发布；如果要改，直接说“只改抖音标题”“回到口播改前 5 秒”或“回到画中画改首屏图”；如果今天不发，也可以回复“归档今天不发”。
```

不要写：

```text
请确认。
是否进入下一步？
是否继续？
请回复继续写口播。
请选择状态。
等待人工确认。
```

## 任务后导航规则

每个专项 skill 完成后，如果用户问“后面呢 / 到哪了 / 继续”，本 skill 必须先读当前交接物和 `工作流状态记录.md`，再给 2-3 个下一步。

推荐下一步的写法：

```text
刚才已经完成 {当前交接物}，核心结论是 {一句话}。
现在最值得走的方向有：
1. {动作 A}：因为 {原因 A}
2. {动作 B}：因为 {原因 B}
3. {动作 C}：因为 {原因 C}
```

不要写：

```text
下一步继续。
建议进入下一个环节。
你想怎么做？
```

如果当前阶段已经触发人类确认，不要继续自动推进；只给可直接回复的选项。

如果当前阶段已经通过门禁且不需要人类选择，必须自动推进：

```text
topic_selected_for_brief -> content-brief-compiler
brief_pass + human_gate = no -> copywriting-draft-writer
review_pass + human_gate = no -> platform-packaging-adapter
delivery_confirmed -> final-delivery-builder
delivery_ready -> final-delivery-builder
```



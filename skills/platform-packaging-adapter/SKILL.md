---
name: platform-packaging-adapter
description: 涛哥创作工作流的多平台分发包装 skill。Use when Codex has a passed short-video talking-head draft, visual plan, or quality review, and needs to compile a platform_package_input first, then create platform-specific cover titles, video titles, publish descriptions, hashtags, and manual posting notes for Douyin, Kuaishou, Xiaohongshu, and WeChat Channels. This skill adapts entrance copy for the same video; it does not rewrite the core script, generate a new video, auto-publish, log in to platforms, or call platform APIs.
---

# Platform Packaging Adapter

## R1 Contract Runtime

```yaml
contract_set_version: r1-contract-set-v0.1
contract_version: 0.1.0
contract_status: confirmed
skill_type: builder
primary_input: quality_review(review_status=review_pass)
primary_output: platform_package_input + platform_package + content_delivery_record
next_skill_on_pass: final-delivery-builder
```

执行口径：

```text
本 skill 只做同一条视频的多平台入口包装，不改视频主体、不自动发布、不登录平台。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读 R1 Runtime、输入门槛、分发包装输入包和交接块，各平台细则按需读取。
必须先编译 platform_package_input，再生成 platform_package。
package_pass 后必须生成 content_delivery_record，并自动进入 final-delivery-builder；不得停在“确认采用”。
```

读、取、传规则：

```text
读：quality_review、draft、visual_plan、content_brief、账号档案、字段词典。
取：从 review 取通过状态和风险边界；从 draft 取 Hook 和主体摘要；从 visual_plan 取首屏视觉任务。
传：content_delivery_record 必须带 delivery_id、package_id、review_id、visual_plan_id、draft_id、brief_id、topic_id、source_research_run_id、delivery_status、approval_status、publish_status、artifact_path、next_skill。
```

状态：

```text
package_status 使用 package_pass / package_needs_fix / package_blocked。
delivery_status=delivery_ready 时 next_skill=final-delivery-builder。
publish_status 默认 publish_not_started；本 skill 不写 publish_manually_published，除非用户明确说已经人工发布并要求记录。
```

R1 交接块：

```text
每次输出必须包含：
contract_set_version：r1-contract-set-v0.1
package_input_id：
package_id：
delivery_id：
review_id：
visual_plan_id：
draft_id：
brief_id：
topic_id：
account：
source_research_run_id：
package_status：
delivery_status：
approval_status：
publish_status：
artifact_path：
next_skill：
human_gate：
auto_next_action：
execution_trace_update：
```

## 定位

本 skill 只做“同一条视频的多平台入口包装”。

它分三步：

```text
Step 1：把 brief / draft / visual_plan / review 编译成 platform_package_input。
Step 2：基于 platform_package_input 生成多平台分发包。
Step 3：生成 content_delivery_record，作为人工确认前的收口交接物。
```

它把已经通过质检的短视频口播稿和画中画方案，先编译成稳定输入，再适配成：

```text
抖音 / 快手 / 小红书 / 视频号
-> 封面标题
-> 视频标题
-> 发布描述
-> 话题标签
-> 人工发布备注
```

它不做：

```text
不改口播正文
不重做视频
不做自动发布
不接平台 API
不自动登录平台后台
不抓平台后台数据
不承诺平台流量结果
```

## 必读

触发后先读：

```text
README.md
交接物字段词典.md
docs/reference/内容形式类型与载体字典.md
docs/reference/平台发布物料方法论与字段规范.md
docs/reference/热点文案Skill方法论与SaaS承接设计.md
skills/copywriting-quality-review/SKILL.md
```

按需读：

```text
accounts/{账号名}/account_profile.md
docs/reference/文案策略矩阵.md
docs/explanation/dbskill质检记录.md
```

## 输入门槛

只有满足以下条件，才进入本 skill：

```text
已有 short-video draft。
已有 visual_plan 或明确不需要画中画。
已有 quality_review，且 `review_status = review_pass` 或“只剩发布包装”。
目标是人工发布前包装，不是自动发布。
```

画中画结束不能直接进入正式分发包。必须先完成文案 + 视觉联合质检，并编译 `platform_package_input`。

如果没有通过质检，先回到 `copywriting-quality-review`。

如果用户要求改口播正文，先回到 `copywriting-draft-writer`。

如果用户要求重做画中画，先回到 `talking-head-image-pip`。

如果已经有 `platform_package` 且 `package_status = package_pass`，但没有 `content_delivery_record`，本 skill 必须先补交付记录，不能只说“等待确认”。

## 核心原则

同一条视频可以四个平台一起发，但入口不能完全一样。

平台差异只影响“入口包装”，不默认影响视频主体：

| 平台 | 优先目标 | 包装口径 |
|---|---|---|
| 抖音 | 停留、热点情绪、推荐流点击 | 强 Hook、冲突感、热点情绪、少量精准话题 |
| 快手 | 真实感、社区信任、垂类识别 | 接地气、真人经验、少一点营销味、标签服务垂类 |
| 小红书 | 搜索、收藏、方法感、种草 | 关键词、痛点、清单感、封面标题和标题强绑定 |
| 视频号 | 信任、转发、熟人链路 | 稳、可信、行业观察感、少夸张、适合分享 |

## 标题机制

每个平台至少生成 3 个封面标题方案和 3 个视频标题方案。封面标题和视频标题是两个不同字段，不能合并成泛化“标题”。

标题不能只写“好听”，必须标注触发器：

```text
认知冲突
好奇缺口
恐惧 / 损失
身份代入
数字锚定
结果承诺
社会证明
争议 / 站队
场景条件
权威借力
互动测试
```

标题质量检查：

```text
是否一眼知道讲什么？
是否还有点开理由？
是否符合平台语气？
是否和口播前 5 秒一致？
是否避免把答案讲完？
是否避免灰产、截流、批量私信、跨平台识别等误解？
```

## 平台包装规则

### 抖音

输出重点：

```text
封面标题：短、狠、能停住划走动作。
视频标题：承接 Hook，可带一点冲突或反常识。
发布描述：不要长解释，补一句观点或问题。
话题标签：热点话题 + 垂类话题 + 产品场景，少而准。
```

避免：

```text
标题太像广告。
标签堆砌。
把产品说成批量获客、截流、自动触达。
```

### 快手

输出重点：

```text
封面标题：口语化、现场感、真实经验感。
视频标题：像真人说话，少一点包装腔。
发布描述：补充“为什么我这么说”或“给谁看”。
话题标签：行业、身份、场景类标签优先。
```

避免：

```text
太互联网黑话。
太像课程广告。
过度制造焦虑。
```

### 小红书

输出重点：

```text
封面标题：痛点 + 关键词 + 收藏理由。
视频标题：更像笔记标题，能搜索，能收藏。
发布描述：可结构化，说明问题、方法、适合谁。
话题标签：关键词、垂类、场景和人群标签。
```

小红书标题可借鉴 `dbs-xhs-title` 的机制：不是自由起标题，而是按心理触发器和场景匹配公式。

避免：

```text
标题超过可读长度。
只蹭热点不提供价值。
封面标题和视频内容不一致。
```

### 视频号

输出重点：

```text
封面标题：稳、可信、有观点。
视频标题：适合被转发到微信群或朋友圈。
发布描述：可以多一点解释，强调观察、经验和边界。
话题标签：少量主题标签即可，优先服务理解，不做堆砌。
```

避免：

```text
过度标题党。
太强营销口吻。
容易引发平台规则误解的表达。
```

## 处理流程

1. 读取账号档案、brief、draft、visual_plan、review。
2. 编译 `platform_package_input`。
3. 自检 `platform_package_input` 是否足够支撑平台包装。
4. 基于 `platform_package_input` 判断平台适配目标：

```text
抖音：停留 / 互动
快手：真实 / 信任
小红书：搜索 / 收藏
视频号：转发 / 信任
```

5. 为每个平台生成：

```text
cover_title_options：封面标题 3 个
recommended_cover_title：推荐封面标题
video_title_options：视频标题 3 个
recommended_video_title：推荐视频标题
publish_description_options：发布描述 2 个
recommended_publish_description：推荐发布描述
hashtag_sets：话题标签 2 组
recommended_hashtags：推荐话题标签
推荐方案
为什么这么包
风险提醒
人工发布备注
```

6. 做包装质检：

```text
平台语气是否匹配？
封面标题和视频标题是否分开？
封面标题是否适合放在封面图上？
视频标题是否承接口播前 5 秒？
是否和视频主体一致？
是否和五秒 Hook 一致？
是否标题党？
是否过度营销？
是否有灰产误解？
是否有事实或产品承诺风险？
```

7. 包装通过后生成 `content_delivery_record`，把“可确认、可返工、可归档、可放弃”的选项说成人话。

## 分发包装输入包

`platform_package_input` 是本 skill 的显式编译层。它的作用是防止分发包装阶段重新理解全文、串号、硬蹭平台语气或误改产品承诺。

必须先输出并自检它，再写平台包。

字段：

```text
package_input_id
account
product_profile_id
campaign_profile_id
source_research_run_id
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
```

编译规则：

```text
从 brief 提取：账号、目标人群、内容目标、产品边界、成功判断。
从 draft 提取：核心观点、推荐 Hook、前 5 秒口播、主体摘要、CTA。
从 visual_plan 提取：首屏画中画任务、画面风格、关键视觉承诺。
从 review 提取：是否通过、风险项、不可说、需要回退的点。
```

自检规则：

```text
缺少 recommended_hook -> 回到 copywriting-draft-writer。
缺少 first_screen_visual_task 且本条需要画中画 -> 回到 talking-head-image-pip。
review 未通过或风险未清 -> 回到 copywriting-quality-review。
产品边界不清 -> 回到 content-brief-compiler 或找涛哥确认。
target_platforms 为空 -> 默认抖音、快手、小红书、视频号。
input_status 不是 input_pass -> 不能输出正式平台包。
```

`input_status` 只能是：

```text
input_pass
input_needs_fix
input_blocked
```

## 输出格式

完整分发包装输入包、平台包装和内容交付记录必须写入：

```text
accounts/{账号名}/runs/{session_id}/intermediate/07-platform-package-input.md
accounts/{账号名}/runs/{session_id}/intermediate/08-platform-package-draft.md
accounts/{账号名}/runs/{session_id}/deliverables/content-delivery-record.md
```

根目录汇总表只做索引和复盘摘录；`workflow_session_record.current_artifact` 必须指向上述账号/session 文件。

```markdown
# 多平台分发包装

## 分发包装输入包
- package_input_id：
- account：
- product_profile_id：
- campaign_profile_id：
- source_research_run_id：
- brand_or_product：
- content_goal：
- target_audience：
- target_platforms：
- core_topic：
- core_point：
- recommended_hook：
- first_5_seconds_script：
- first_screen_visual_task：
- video_body_summary：
- visual_style_summary：
- product_mention_level：
- product_claim_boundary：
- must_not_say：
- risk_words：
- cta：
- platform_goals：
- source_review_id：
- input_status：
- next_skill：

## 输入包自检
| 项目 | 结论 | 处理 |
|---|---|---|
| review 已通过 |  |  |
| Hook 可用于标题 |  |  |
| 首屏画中画任务清楚 |  |  |
| 产品边界清楚 |  |  |
| 风险词清楚 |  |  |
| 目标平台清楚 |  |  |

## 总体包装策略
- 同一视频主体：
- 平台差异：
- 不做的事：

## 抖音

### 封面标题
| 方案 | 标题 | 触发器 | 理由 | 风险 |
|---|---|---|---|---|

### 视频标题
| 方案 | 标题 | 触发器 | 理由 | 风险 |
|---|---|---|---|---|

### 发布描述
1. ...
2. ...

### 话题标签
- 方案 A：
- 方案 B：

### 推荐组合
- 封面：
- 视频标题：
- 描述：
- 标签：
- 人工发布备注：

### 字段化推荐
- recommended_cover_title：
- recommended_video_title：
- recommended_publish_description：
- recommended_hashtags：

## 快手
同上。

## 小红书
同上。

## 视频号
同上。

## 包装质检
| 项目 | 结论 | 说明 |
|---|---|---|
| 和视频主体一致 |  |  |
| 和前 5 秒一致 |  |  |
| 封面标题和视频标题已分开 |  |  |
| 封面标题适合放在画面上 |  |  |
| 视频标题承接口播 Hook |  |  |
| 平台语气匹配 |  |  |
| 标题党风险 |  |  |
| 产品承诺风险 |  |  |
| 灰产误解风险 |  |  |

## 状态
- package_status：package_pass / package_needs_fix / package_blocked
- next_skill：
- human_prompt：
- human_reply_examples：

## 内容交付记录
- delivery_id：
- package_id：
- package_input_id：
- review_id：
- visual_plan_id：
- draft_id：
- brief_id：
- topic_id：
- product_profile_id：
- campaign_profile_id：
- source_research_run_id：
- account：
- topic_title：
- strategy：
- content_format：
- target_platforms：
- recommended_package_summary：
- artifact_paths：
- human_decision：
- revision_path：none / back_to_platform_package / back_to_quality_review / back_to_visual_plan / back_to_draft / back_to_content_brief / back_to_topic_card
- delivery_status：delivery_ready / delivery_needs_fix / delivery_confirmed / delivery_archived / delivery_discarded
- approval_status：approval_pending / approval_approved / approval_needs_revision / approval_rejected / approval_not_required
- publish_status：publish_not_started / publish_manually_published / publish_skipped / publish_unknown
- next_skill：human_confirm / done
- human_prompt：
- human_reply_examples：
```

## 回退规则

```text
platform_package_input 缺失 -> 先在本 skill 内编译，不直接写平台包
platform_package_input 未通过 -> 按 input 自检结果回退
核心观点不清 -> content-brief-compiler
口播和标题不一致 -> copywriting-draft-writer
五秒 Hook 太弱 -> copywriting-draft-writer
画中画首屏和封面标题冲突 -> talking-head-image-pip
产品承诺风险 -> copywriting-quality-review
平台包装通过 -> 生成 content_delivery_record，并自动进入 final-delivery-builder；不再等待“确认采用”
```

## User Interaction Prompts

平台包生成后，必须告诉用户能怎么选。不要只输出 `package_pass`，也不要只写“等待确认”。确认引导语要让用户一眼知道能回什么。

可用引导语：

```text
平台包装已经完成，我会继续生成最终 HTML 验收页，不需要你再回复“确认采用”。
最终 HTML 完成后，你可以直接看文案、图片和平台物料；如果要改，直接说改哪里。
如果只想改某个平台，回复“只改抖音标题 / 只改小红书描述 / 重做视频号整包”。
如果只想改抖音，回复“只改抖音标题 / 只改抖音描述 / 重做抖音整包”。
如果只想改小红书，回复“重做小红书标题”，我会保留视频主体不动。
如果你觉得标题和口播不一致，回复“回到口播改 Hook”。
如果你觉得首屏图不配标题，回复“回到画中画改首屏图”。
如果你要换平台，回复“加 B站 / 去掉快手 / 只做抖音和视频号”。
如果今天不发但想保留，回复“归档今天不发”。
如果这条不做了，回复“放弃这条”。
```

禁止使用这种让人摸不着头脑的话：

```text
请确认。
是否通过？
下一步怎么做？
等待人工确认。
请选择 delivery_status。
```

输出交接物必须包含：

```text
recommended_action：默认继续生成最终 HTML 验收页，或说明为什么必须先返工。
auto_next_action：平台包装通过后自动进入 `final-delivery-builder`；收到局部修改指令后只回退对应环节。
task_after_navigation：生成最终 HTML / 局部返工 / 归档今天不发 / 放弃这条，并解释每个选择的影响。
```

## 未来 SaaS 字段

```text
platform_package_input_id
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
platform
cover_title_options
video_title_options
publish_description_options
hashtag_sets
recommended_package
platform_goal
trigger_type
risk_notes
manual_publish_notes
package_status
delivery_id
delivery_status
human_decision
revision_path
```

输出时禁止使用泛化 `标题` 替代 `封面标题` 或 `视频标题`。最终交付页如果只展示“标题”，必须回到本 skill 修正。

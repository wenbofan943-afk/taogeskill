---
name: talking-head-image-pip
description: Turn Chinese talking-head scripts, hotspot topics, product copy, or selected口播段落 into image-generation picture-in-picture visual strategy, shot planning, and high-quality prompts. Use when the user says 热点画中画, 口播配图, image 画中画, 用 image 2 做画中画, 给这段口播出画面, or asks for visual prompts that make a spoken short-video script more striking, more topical, or more aligned with 公开互动分析工具.
---

# Talking Head Image Pip

## R1 Contract Runtime

```yaml
contract_set_version: r1-contract-set-v0.1
contract_version: 0.1.0
contract_status: confirmed
skill_type: producer
primary_input: draft(draft_status=draft_created)
primary_output: visual_plan + image_asset_set status
next_skill_on_pass: copywriting-quality-review
```

## R3 Asset Runtime

```yaml
contract_set_version: r3-asset-runtime-v0.1
contract_version: 0.3.0
contract_status: confirmed
skill_type: asset_producer
primary_input: draft + content_brief
primary_output: visual_plan + image_prompt_set + image_generation_record + image_asset_set
next_skill_on_pass: copywriting-quality-review
reference: docs/reference/R3-图片资产执行规范.md
```

执行口径：

```text
本 skill 在 R3 中不只产“画中画提示词”，还必须产出可追溯图片资产链。
先读 `docs/reference/R3-图片资产执行规范.md` 的标准资产链、状态边界、图片数量预算、必产对象和 R3CHK 检查项。
final delivery 前 required 图片必须 generated，或有 pending_external / generation_failed / manual_required 的诚实降级记录。
不得把 prompt_card 当作 image_asset，不得把 HTML 当作图片事实源。
```

R3 交接块：

```text
每次输出必须包含：
contract_set_version：r3-asset-runtime-v0.1
visual_plan_id：
image_prompt_set_id：
image_asset_set_id：
required_count：
optional_count：
generated_count：
pending_count：
failed_count：
rejected_count：
image_assets_status：all_generated / partially_generated / pending_external / generation_failed / manual_required / mixed / not_required
generation_records_dir：
metadata_dir：
html_embed_manifest_ready：yes / no
r3_sample_gate_status：pass / fail / not_run
r3_check_summary：
artifact_path：
next_skill：
execution_trace_update：
```

执行口径：

```text
本 skill 负责画中画视觉计划、提示词、图片生成记录和图片状态；不写正文、不做质检、不做平台包装。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读 R1 Runtime、Workflow、Find Retention Risk 和交接块，prompt 工艺按需读取。
R1 只规定视觉计划必须可执行；R3 规定图片数量、生成记录、sidecar 和 HTML 嵌入资产合同。
每张建议画中画必须有留人任务、插入位置、提示词、状态和不用这张图的损失。
R1CHK-017 已确认：prompt 不得缩水成短关键词；如果无法保留完整 prompt 卡，`visual_plan_status` 必须为 `visual_plan_needs_fix`，不得进入质检。
```

读、取、传规则：

```text
读：draft、content_brief、字段词典、session manifest、外部视觉资料按需读取。
取：从 draft 取推荐 Hook、五秒留存设计、segment_map、retention_task、script_text。
传：visual_plan 必须带 visual_plan_id、draft_id、brief_id、source_research_run_id、pip_insert_map、image_prompt_set、image_generation_record、image_asset_set、image_assets_status、visual_plan_status、artifact_path、next_skill。
传给 image 生成和下游质检的 `prompt_used` 必须是完整 prompt 或能追溯到完整 prompt_id，不得只保存素材关键词。
```

图片状态：

```text
规划阶段可以只输出 prompt。
进入最终交付时，必须生成实际图片或明确 image_status=pending_external / generation_failed / manual_required。
每次生成、失败、外部待生成或人工上传都必须写 image_generation_record。
generated 图片必须写 image_metadata_sidecar；pending / failed / manual 必须能追溯到 generation_record 或人工任务说明。
不得把 pending_external 说成 generated。
```

R1 交接块：

```text
每次输出必须包含：
contract_set_version：r1-contract-set-v0.1
visual_plan_id：
draft_id：
brief_id：
account：
source_research_run_id：
pip_insert_map：
image_assets_status：
visual_plan_status：
artifact_path：
next_skill：
human_gate：
execution_trace_update：
```

## Position

Use this skill to create visual direction and image prompts for short-video talking-head picture-in-picture material.

This is not the old engineering-style HTML/PPT card workflow. The goal is传播视觉:

```text
口播文字
-> 留存风险点
-> 留人任务
-> 热点切口 / 情绪 / 冲突 / 观点
-> 画面隐喻
-> 留人任务驱动的视觉提示词卡
-> 剪辑可用的画中画素材
```

Core rule:

```text
Picture-in-picture is not decoration.
It exists to keep viewers for 2-5 more seconds at the moment they would otherwise drift away.
```

In the current Codex app environment, image generation can be called directly when the user confirms a prompt, asks to render, or the workflow is entering final human-facing delivery. Do not design an external image API, CLI service, renderer, upload pipeline, or long-lived engineering integration for this skill.

If the workflow is only at `visual_plan`, prompts are acceptable. If the workflow is producing `final-delivery.html`, required picture-in-picture assets must either be rendered into `assets/images/` or explicitly marked with `image_status = pending_external / generation_failed`.

This skill absorbs three outside patterns without depending on them at runtime:

```text
GPT-Image2-Skill -> preflight, quality/size choice, prompt craft discipline.
visual-skills -> GPT Image 2 five-slot prompt: Scene / Subject / Important Details / Use Case / Constraints.
ai-video-storyboard-skill -> visual consistency layer and short-video beat planning.
```

Default project context:

```text
产品：公开互动分析工具
当前能力：评论区 / 直播间公开互动整理 -> AI 分析 -> 分析结果 / 重点互动 / 互动资产库 -> 免费学习版申请制
边界：不承诺未实现能力，不暗示灰产、截流、批量私信、跨平台识别、联系方式提取或自动发布。
```

## Inputs

If the user gives incomplete input, infer safe defaults and state the assumption. Ask only when the missing information changes risk or output direction.

Prefer this input card:

```text
账号 / 人设：
口播稿 / 段落：
热点 / 选题：
内容目标：曝光 / 获客 / 信任 / 教育 / 转化
文案策略：大热点破圈 / 垂类获客 / 证据演示 / 反误解 / 产品种草
画幅：9:16 / 16:9 / 1:1
素材限制：可生成 image / 必须用截图 / 可混合 / 禁止真人脸
是否允许画面文字：
```

When prior propagation artifacts exist, accept these as upstream:

```text
topic_card -> content_brief -> draft
```

Field names must follow `交接物字段词典.md`. In structured handoff blocks, use `content_brief` rather than plain `brief`, and use `visual_plan_status` rather than free-form status text.

## Workflow

### 1. Classify The Job

Decide which mode this request is in:

| Mode | Trigger | Output |
|---|---|---|
| 视觉方案 | 用户还没确认出图，且尚未进入最终交付 | strategy + beat table + prompts |
| 单张出图 | 用户确认某个 beat / prompt | one rendered image + used prompt |
| 多张出图 | 用户明确要一组画中画素材 | selected image set, normally 2-4 images |
| 最终交付出图 | 选题已确认且正在生成 final-delivery.html | required image assets or explicit fallback status |
| 改图 | 用户给已有图并要求微调 | one concrete edit instruction with preserve list |

Default to `视觉方案` during planning. Do not render images during early planning unless the user asks or confirms. For final human-facing delivery, prompts alone are not enough: render required assets or record a clear fallback status.

R3 视觉预算：

```text
30 秒以内：1 required + 1 optional。
30-60 秒：2 required + 1-2 optional。
60-90 秒：3 required + 1-2 optional。
90 秒以上：3-4 required，超出必须说明留存任务。
```

如果实际 required 数量偏离预算，必须写 `reduction_reason` 或 `expansion_reason`。

### 2. Segment The Script

Split the口播 by attention changes, not mechanically by sentence. Prefer these segment types:

```text
开头 Hook
热点事实
观点转折
抽象解释
案例 / 证据
产品露出
结尾 CTA
```

For each segment, write:

```text
段落功能
预计出现时间
预计时长
信息密度：高 / 中 / 低
口播干度：高 / 中 / 低
观众可能卡在哪里
```

Then split into 3-8 visual beats. For normal short videos, prefer 2-5 seconds per visual beat. Each beat must answer:

```text
这一句承担什么传播任务？
观众此刻应该产生什么情绪？
这一句的冲突或信息增量是什么？
如果没有画面，观众会不会更难理解或更难继续看？
```

Drop beats that only decorate. A画中画 image must support comprehension, curiosity, trust, or emotional pull.

### 2.1 Find Retention Risk

For every segment, scan these risks:

```text
连续讲太久
太抽象
需要证据
情绪不够
转场容易断
信息密度下降
口播卡壳或太书面
产品能力说不清
```

Classify visual need:

| Need | Use When |
|---|---|
| 必须画中画 | 前 5 秒、抽象概念、强冲突、关键证据、产品能力说明 |
| 建议画中画 | 转场、案例、对比、情绪放大、信息密度下降 |
| 可不画 | 口播本身画面感强、节奏已经足够 |
| 不建议画 | 会分散注意、太硬、太虚、和产品或口播无关 |

Do not generate prompts for `可不画` or `不建议画` unless the user explicitly asks.

### 2.2 Assign One Retention Task

Every generated visual must have exactly one primary retention task:

```text
停住划走
补信息
增可信
放大冲突
解释抽象
节奏打断
顺接转场
强化记忆点
```

If a visual cannot name its retention task, do not generate it.

### 2.5 Prioritize The First 5 Seconds

For talking-head content, the first 5 seconds are the highest-priority visual beat.

Before distributing visuals across the whole script, inspect the upstream draft's `五秒留存设计`:

```text
推荐 Hook
Hook 类型
五秒留存评分
首屏画中画任务
Hook 到正文的转场
五秒划走风险
```

The first visual must serve one of these jobs:

```text
停住划走动作
放大公共热点或冲突
补足可信度 / 现场感
解释抽象观点
制造信息缺口
把 Hook 顺接到正文
```

If the first 5-second visual is only decorative, mark it as failed and rewrite the visual plan. Do not average the visual budget across the whole script before solving the opening.

### 3. Lock Visual Consistency

Before writing individual prompts, define one shared visual language so images do not look like unrelated stock pictures:

```text
色彩：3-5 个主色或明确色调
光线：自然光 / 低照度 / 霓虹 / 本地门店白光 / 直播间屏幕光
镜头：近景 / 中景 / 广角环境 / 俯拍 / 低机位
质感：纪录片 / 商业纪实 / 电影海报 / 社交媒体封面 / 证据截图感
人物：是否出现人、是否露脸、是否只用背影/手部/剪影
产品：是否直接出现“公开互动分析工具”界面，还是只做隐喻
```

For this project, prefer a credible commercial documentary look over fantasy, pure sci-fi, or generic poster style.

### 4. Pick Visual Type

Choose one primary type per beat according to the retention task:

| Retention Task | Prefer Visual Type |
|---|---|
| 停住划走 | 冲突图 / 情绪图 |
| 补信息 | 证据图 / 结果图 |
| 增可信 | 场景图 / 证据图 |
| 放大冲突 | 冲突图 / 对比图 |
| 解释抽象 | 隐喻图 / 流程图 / 场景图 |
| 节奏打断 | 反差图 / 场景切换 |
| 顺接转场 | 过渡图 / 连接图 |
| 强化记忆点 | 符号图 / 金句图 |

Supported visual types:

| Type | Use For | Avoid |
|---|---|---|
| 冲突图 | 开头、矛盾、行业痛点 | 把产品硬塞进热点 |
| 隐喻图 | 抽象观点、认知转折 | 过虚、看不懂 |
| 证据图 | 案例、流程、结果、可信度 | 编造真实数据 |
| 对比图 | 过去/现在、错误/正确、传统/AI | 信息太密 |
| 场景图 | 用户现场、本地门店、运营桌面 | 像库存图 |
| 结果图 | 输出物、表格、资产库、复盘 | 泄露真实数据 |
| 情绪图 | 大热点破圈、共情、社会情绪 | 偏离账号画像 |

### 5. Build The Visual Bridge

For hotspot content, explicitly write the bridge:

```text
大热点 B
-> 中间观点 A
-> 本账号母题
-> 本产品能力 / 本段口播
```

Mark the weakest jump. If the bridge is too forced, recommend not generating that visual.

### 6. Write Image Prompts

Do not write prompts before deciding:

```text
对应口播
留存风险
留人任务
画面类型
为什么值得生成
不用这张图会损失什么
```

Prompt engineering rule:

```text
Prompt = 留人任务 + 口播语义 + 画面类型 + 主体动作 + 场景环境 + 镜头构图 + 光线情绪 + 项目风格 + 风险约束 + 负面提示 + 验收标准
```

R1 prompt 完整度硬规则：

```text
不得把完整 prompt 编译成一句“物件 + 禁止项 + 画幅”的短关键词。
不得只在聊天里写完整 prompt，落盘文件里只留短 prompt。
不得实际出图时使用短 prompt，而 visual_plan 里伪装成完整 prompt。
```

每张进入 `image_prompts`、`image-assets.md` 或实际出图的图片，必须保留这 14 个层：

```text
beat_id
用途
口播对应
留存风险
留人任务
画面类型
为什么值得生成
不用这张图会损失什么
主体 / 动作
场景 / 环境
镜头 / 构图 / 字幕安全区
五槽提示词：Scene / Subject / Important Details / Use Case / Constraints
负面提示
验收标准
```

完整度判定：

```text
prompt_integrity_check = pass：14 层齐全，可进入出图或质检。
prompt_integrity_check = fail：缺任一核心层，visual_plan_status = visual_plan_needs_fix，next_skill = talking-head-image-pip。
```

For GPT Image 2-style prompts, use labeled sections. Do not output tag soup.

Each prompt should include these model-facing parameters:

```text
Model: gpt-image-2
Quality: low / medium / high
Size / Ratio: 9:16 / 16:9 / 1:1 or concrete size
```

Quality rule:

```text
low：探索多个方向、先看构图
medium：正常可用画中画
high：有中文文字、小字、UI、结果页、品牌资产、复杂构图
```

Use this five-slot prompt body:

```text
Scene: 场景、时间、背景、环境
Subject: 主体是谁/是什么，正在做什么
Important Details: 材质、光线、镜头、构图、情绪、颜色、关键物件、字幕安全区
Use Case: 短视频口播画中画 / 开头封面 / 证据图 / 产品种草图
Constraints: 不出现什么、不改变什么、不能生成什么风险元素
```

Add a camera and composition layer before the final prompt:

```text
镜头：近景 / 中景 / 广角 / 俯拍 / 低机位 / 手机屏幕特写
构图：主体位置、右三分之一留白、上方字幕安全区、画面焦点
小屏可读性：9:16 手机竖屏里是否一眼看懂
```

Default style for this project:

```text
现实主义商业纪录片感，强构图，清晰主体，短视频画中画可读，非科幻空泛，非纯 PPT，非过度卡通。
```

For image models with strong text rendering, allow short Chinese text only when it materially helps. Otherwise prefer no text and leave字幕给剪辑层.

Anti-slop rules:

```text
不要写：震撼、史诗、超酷、大片感、4K、赛博、未来感、极致、顶级。
要写：湿地面反光、门店冷白灯、手机屏幕光、评论气泡、旧办公桌、玻璃门反射、低角度、右三分之一留白。
```

If exact text must appear in image, quote it exactly and keep it short. Add:

```text
no extra words, no duplicate text, no watermark, Chinese text must be crisp and readable
```

### 7. Output

Return this structure:

```text
一、整体视觉策略
二、画中画编排表
三、image 提示词
四、剪辑使用建议
五、不建议生成的画面
六、交接物摘要
七、需要涛哥确认的问题
```

Use this table for the编排表:

| Beat | 时间 | 口播对应 | 段落功能 | 留存风险 | 是否需要画中画 | 留人任务 | 画面类型 | 画面一句话 | 不用损失 | 停留 | 风险 | 是否生成 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

Use this block for each prompt:

```text
beat_id：
用途：
口播对应：
出现时间：
留存风险：
留人任务：
画面类型：
为什么值得生成：
不用这张图会损失什么：
模型 / 质量 / 画幅：
主体：
场景：
动作：
镜头 / 构图：
光线 / 情绪：
字幕安全区：
中文提示词：
五槽提示词：
负面提示：
是否允许文字：
剪辑建议：
风险备注：
验收标准：
prompt_integrity_check：pass / fail
```

The handoff summary must appear near the end:

完整画中画方案必须写入：

```text
accounts/{账号名}/runs/{session_id}/intermediate/05-visual-plan.md
```

如实际生成图片或素材，放入同一 session 的 `assets/` 目录；`workflow_session_record.current_artifact` 必须指向上述账号/session 文件。

R3 图片资产必须写入：

```text
accounts/{账号名}/runs/{session_id}/assets/images/image-assets.md
accounts/{账号名}/runs/{session_id}/assets/images/generation-records/
accounts/{账号名}/runs/{session_id}/assets/images/metadata/
```

生成记录和 sidecar 规则：

```text
每张 required 图必须有 image_task_id、source_prompt_id、generation_run_id、image_status 和 insert 位置。
每次生成 / 失败 / 待外部生成 / 人工上传必须有 image_generation_record。
generated 图片必须有 asset_path、metadata_sidecar_path、width / height 或可说明的缺失原因。
图片重做不得覆盖旧 image_asset_id；新图写 asset_version，并用 supersedes_asset_id 指向旧图。
```

```text
visual_plan_id：
draft_id：
brief_id：
first_screen_visual_task：
visual_strategy：
beats_count：
required_visuals：
optional_visuals：
not_recommended_visuals：
image_prompts_count：
image_asset_set_id：
image_assets_status：
generation_records_dir：
metadata_dir：
r3_sample_gate_status：
visual_plan_status：visual_plan_pass / visual_plan_needs_fix / visual_plan_blocked
next_skill：copywriting-quality-review
human_prompt：
human_reply_examples：
```

If `visual_plan_status` is not `visual_plan_pass`, stop and explain what to fix. Do not hand off to quality review.

If any generated visual has `prompt_integrity_check = fail`, `visual_plan_status` must not be `visual_plan_pass`.

Prompt acceptance checklist:

```text
这张图能不能让观众多停 2-5 秒？
是否贴合口播当下语义？
是否解决了一个明确留存风险？
是否会抢口播？
是否误导产品能力？
是否适合 9:16 小屏？
是否只是好看但没用？
```

### 8. Rendering And Fallback

During planning, only render images when the user explicitly asks to produce actual images, or confirms which prompt to render.

During final delivery, render required images before producing `deliverables/final-delivery.html`. If rendering is unavailable, do not block the whole delivery page; write `image_status = pending_external` or `image_status = generation_failed`, include the compatible prompt, and show the missing-image status in the HTML.

When rendering:

```text
1. Select the strongest prompt for the requested beat.
2. Keep the prompt faithful to the approved visual strategy.
3. Before calling image generation, verify `prompt_integrity_check = pass`.
4. Use the full prompt card or the full five-slot prompt, not a compressed keyword prompt.
5. Use the built-in image generation capability available in Codex.
6. Save generated assets under accounts/{账号名}/runs/{session_id}/assets/images/.
7. Record beat_id, insert position, provider, model if known, full prompt_used, asset_path, image_status, prompt_integrity_check, image_generation_record, and metadata_sidecar when generated.
8. Do not introduce external APIs, local model installs, browser automation, platform uploads, or video rendering.
9. Return the generated image and the full prompt used.
```

Future fallback providers such as Seedream 4.0 / 5.0 are only a design allowance. This skill must not call external image APIs unless the project later adds a dedicated, reviewed adapter.

For edits to an existing image, use:

```text
Change: 只改一个具体点
Preserve: 人脸、姿势、构图、光线、背景、文字、布局等必须保留项
Constraints: 不新增无关对象、不改产品含义、不漂移风格
```

## Quality Bar

A good output should:

1. Make the first 3-5 seconds more clickable.
2. Fit the spoken text instead of becoming generic decoration.
3. Make the product look useful without overclaiming.
4. Avoid old工程图/PPT感 unless the beat is explicitly a proof or flow explanation.
5. Make each image prompt directly usable in an image generation model.
6. Tell the user when a visual idea is too forced.
7. Separate "prompt planning" from "actual rendering"; do not render during early planning before the user asks or confirms.
8. Use a stable visual language across multiple images so the final video does not feel stitched from unrelated素材.
9. Prefer concrete visual nouns and physical details over empty adjectives.
10. Give the first 5 seconds a dedicated visual task and explain how it supports retention.
11. Mark `可不画` and `不建议画` beats instead of forcing prompts for every segment.
12. Include why each generated visual is worth generating and what would be lost without it.
13. For final delivery, make actual image assets visible to the user or clearly mark the fallback status.

## Hard Boundaries

Do not:

1. Generate auto-publishing workflows.
2. Claim platform-private data, phone numbers, WeChat IDs, cross-platform identity merging, or automated DM ability.
3. Expose or invent real customer data.
4. Use celebrity/public figure likeness unless the user clearly asks and it is necessary; prefer symbolic scenes for热点.
5. Turn every sentence into an image. Too many画中画 will weaken口播.
6. Present prompts as final published copy. Final content still needs涛哥人工确认.
7. Pretend images exist when only prompts exist.

## User Interaction Prompts

Whenever user input is needed, use plain choices instead of field names.

Use these prompts:

```text
这条口播我建议先做画中画方案，不直接出图。你可以回复“确认这个画中画方案”，我再进入质检；也可以回复“只改首屏图”。
首屏画面有两种方向：一种更抓停留，一种更稳更可信。你回复“选 A”或“选 B”就行。
这张图不建议生成，因为它只是好看但不帮留人。你如果坚持要做，回复“仍然生成”。
方案阶段如果你要实际出图，回复“生成第 1 张 / 第 2 张 / 全部生成”。进入最终交付页前，我会生成必要图片；如果当前环境不能出图，会标记待外部生成并保留可复制提示词。
```

## Handoff

If the user only has a hotspot and no selected topic, hand off to `hotspot-topic-research`.

If the user has a draft and asks whether the copy is good, hand off to `copywriting-quality-review`.

If `visual_plan_status = visual_plan_pass`, hand off to `copywriting-quality-review`, not `platform-packaging-adapter`.

If the user asks “下一步该用哪个传播 skill”, hand off to `propagation-router`.

If the user asks for actual rendered images, use the available image generation tool after confirming the prompt set or selecting the best prompt.



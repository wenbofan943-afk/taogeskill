---
name: copywriting-quality-review
description: 涛哥创作工作流文案、静态视觉和封面成品质检 skill。Use for “检查文案 / 文案能不能发 / 有没有 AI 味 / 画中画合不合适 / 封面成品能不能用 / 封面文字对不对 / 小屏是否可读 / dbskill 质检”。Use content_visual_review before platform packaging and cover_review after cover composition; route only the failed layer, never auto-publish or modify product code.
---

# Copywriting Quality Review

## R1 Contract Runtime

```yaml
contract_set_version: r1-contract-set-v0.1
contract_version: 0.1.0
contract_status: confirmed
skill_type: reviewer
primary_input: draft + visual_plan
primary_output: quality_review
next_skill_on_pass: platform-packaging-adapter
```

## R3 Asset Review Runtime

```yaml
contract_set_version: r3-asset-runtime-v0.1
contract_version: 0.5.0
contract_status: confirmed
skill_type: asset_reviewer
primary_input: draft + static_visual_director_plan + visual_plan + image_asset_set
primary_output: quality_review / cover_quality_gate
next_skill_on_pass: platform-packaging-adapter / final-delivery-builder
reference: docs/reference/R3-图片资产执行规范.md
```

本 skill 有两个明确模式：

```text
content_visual_review：draft + visual plan 初审；cover_quality_gate_status=not_applicable；通过后进入 platform-packaging-adapter。
cover_review：cover_design_package + cover_composition + image_asset_set 专项复检；通过后进入 final-delivery-builder。
```

执行口径：

```text
R3 下，本 skill 必须检查图片资产链，而不是只检查画面审美。
必须读取 `docs/reference/R3-图片资产执行规范.md` 的状态边界、必产对象和 R3CHK 检查项。
visual_quality_gate_status 通过，不等于 image_asset_trace_status 通过；二者必须同时通过或给出明确降级说明。
static_visual_quality_gate_status 必须判断图片是否从视觉语言出发，而不是内容语言直译。
content_visual_review 阶段封面尚未编译，cover_quality_gate_status 必须为 not_applicable，不能因缺 cover_design_package 阻断初审。
cover_review 阶段必须判断封面成品、prompt_only 降级和上传准备状态；只有封面标题或只有底图不得通过。
asset_trace_quality_gate_status 必须判断 prompt、generation_record、metadata、HTML embed 是否闭合。
```

R3 阻断：

```text
generated 图片缺 asset_path 或 metadata_sidecar_path，不得 review_pass。
pending_external / generation_failed / manual_required 被当成 generated 展示，不得 review_pass。
required 图片缺 generation_record，不得 review_pass。
required 图片缺 image_asset_type 或 image_production_path，不得 review_pass。
Codex / 非 Codex 生产路径混用、或 prompt-only 被当成 generated，不得 review_pass。
图片重做覆盖旧 asset，必须 review_needs_visual_fix。
多篇 child session 共用 image_asset_set，必须 review_blocked 并交给 R2。
cover_review 中 composition_ready 但 output_asset_id / output_path 缺失，不得通过。
cover_review 中 model_text_in_image 文字不准确、小屏不可读或安全区失败，不得通过。
```

执行口径：

```text
本 skill 只做文案 + 视觉联合质检、风险判断和返工路由；不自动发布、不生成平台包。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读 R1 Runtime、输入要求、检查维度和交接块，dbskill 资料按需读取。
质检必须同时检查 Hook、正文信息密度、承诺兑现、核心机制、产品风险、画中画是否服务留存，以及图片资产链是否可追溯。
R1CHK-018 已确认：有图不等于通过；画中画像泛素材、只装饰、不服务留存任务或 prompt 卡不完整时，不得 `review_pass`。
content_visual_review 通过后自动进入 platform-packaging-adapter；cover_review 通过后自动进入 final-delivery-builder。两种模式都不要求用户回复“继续”。
```

读、取、传规则：

```text
读：content_brief、draft、visual_plan、字段词典、产品边界、dbskill 相关资料按需读取。
取：从 draft 取 script_text、hook_route、body_information_density_score、core_mechanism；从 visual_plan 取首屏任务和图片状态。
传：quality_review 必须带 review_mode、review_id、draft_id、visual_plan_id、source_research_run_id、review_status、blocking_issues、risk_review、must_fix_segments、artifact_path、next_skill。
传：content_visual_review 必须带 visual_quality_gate_status、static_visual_quality_gate_status、prompt_integrity_status、image_asset_trace_status、asset_trace_quality_gate_status、html_embed_readiness_status，并明确 cover_quality_gate_status=not_applicable。
传：cover_review 必须带 cover_quality_gate_id、cover_design_package_id、cover_composition_id、platform、output_asset_id、text_accuracy_status、upload_readiness_status、quality_gate_status、artifact_path、next_skill。
```

阻断：

```text
产品承诺风险、灰产误解、Hook 低于 7 分、承诺不兑现、视觉误导或缺必要 visual_plan 时不得通过。
prompt_integrity_check 失败、画中画泛素材化、画中画不解决留存风险、图片资产状态不诚实、generated 图片缺 sidecar 时不得通过。
```

R1 交接块：

```text
每次输出必须包含：
contract_set_version：r1-contract-set-v0.1
review_id：
draft_id：
visual_plan_id：
image_asset_set_id：
brief_id：
account：
source_research_run_id：
review_status：
blocking_issues：
risk_review：
artifact_path：
next_skill：
human_gate：
auto_next_action：
execution_trace_update：
```

## 定位

本 skill 只负责检查已有口播草案和画中画方案：

```text
brief / draft / visual_plan
-> 产品承诺检查
-> 涛哥味 / AI 味检查
-> 口播流畅度检查
-> 画中画贴合度检查
-> 传播共鸣检查
-> 风险检查
-> 修改建议
-> next_skill
```

不负责找热点，不负责重新选题，不自动发布，不改官网 / GitHub / 客户端页面。

## 必读

```text
README.md
交接物字段词典.md
docs/reference/热点文案Skill方法论与SaaS承接设计.md
skills/propagation-router/SKILL.md
```

按需参考 dbskill：

```text
D:\OpenClaw\workspace\AI工程驾驭系统\01-开源方案调研\dbskill-dontbesilent2025\skills\dbs-ai-check\SKILL.md
D:\OpenClaw\workspace\AI工程驾驭系统\01-开源方案调研\dbskill-dontbesilent2025\skills\dbs-script-flow\SKILL.md
D:\OpenClaw\workspace\AI工程驾驭系统\01-开源方案调研\dbskill-dontbesilent2025\skills\dbs-resonate\SKILL.md
D:\OpenClaw\workspace\AI工程驾驭系统\01-开源方案调研\dbskill-dontbesilent2025\skills\dbs-hook\SKILL.md
D:\OpenClaw\workspace\AI工程驾驭系统\01-开源方案调研\dbskill-dontbesilent2025\skills\dbs-content\SKILL.md
```

只读必要文件，不复制外部方法论全文。

## 输入要求

优先读取：

```text
brief_id
topic_id
content_goal
core_point
ip_assets_used
product_claim_boundary
format
success_metric
draft_id
script
title_options
cta
visual_plan_id
beats
visual_strategy
image_prompts
edit_notes
```

如果用户只给一段文案，也可以直接检查，但要标注“缺 brief / visual_plan，结论置信度下降”。

## 检查维度

### 1. 产品承诺与风险

检查：

```text
是否承诺 v1.9.1 做不到的能力
是否把产品说成截流、灰产、批量获客、自动私信、跨平台识别
是否暗示提取联系方式或个人身份识别
产品是否硬插
```

任一项触发，必须阻断发布。

### 2. 涛哥味 / AI 味

参考 dbs-ai-check，但不要只说“去 AI 味”。检查：

```text
是否太工整、太圆、太像模板
是否没有行业体感
是否没有真实判断
是否每段都收束金句
是否替用户编蠢话再纠正
是否产品插入不像涛哥会说的话
```

如果不像涛哥，给追问或改法方向，不直接伪装成最终口径。

### 3. 口播流畅度

参考 dbs-script-flow，检查：

```text
段落间逻辑衔接
段落内信息密度
句子口播流畅度
观众可能在哪一秒划走
```

短视频草案必须输出高 / 中 / 低风险点。

### 4. 传播共鸣

检查：

```text
开头是否有话题、Hook、可信度
核心观点是否刺中目标人群
是否全面但没重点
是否适合当前内容目标
结尾动作是否过硬或过轻
```

### 5. 五秒留存

参考 dbs-hook、dbs-script-flow 和成熟短视频经验，单独检查前 5 秒。

判断口径：

```text
好开头 = 话题 + Hook + 可信度。
前 1 秒要停住划走动作。
前 3 秒要让观众知道讲什么、为什么值得看。
前 5 秒要让 Hook 承诺和正文接上。
```

评分满分 10 分：

```text
话题清晰度：2 分
Hook 强度：2 分
可信度 / 现场感：2 分
悬念或冲突：2 分
转场承接：1 分
口播顺滑：1 分
```

低于 7 分，`review_status` 必须是 `review_needs_copy_fix`，next_skill 回到 `copywriting-draft-writer`。

### 6. 画中画联合检查

检查 `visual_plan` 是否真的服务口播，而不是装饰：

```text
每张实际生成或计划生成的图片是否有完整 prompt 卡。
prompt_integrity_check 是否为 pass。
首屏画中画任务是否承接推荐 Hook。
画面是否解决明确留存风险。
画面是否会抢口播。
画面是否和口播语义一致。
画面是否误导产品能力。
画面是否泄露真实数据或虚构证据。
是否存在“好看但没用”的画面。
是否存在“看起来干净，但任何垂类内容都能用”的泛素材图。
是否有必须画中画却漏掉的段落。
是否有 `static_visual_director_plan`，并且它提供的是视觉角色、构图和风格锚点，而不是内容文案复述。
是否每张图都区分 `picture_in_picture_image` / `cover_image`。
是否每张图都区分 `codex_image2_render` / `seedream_prompt_delivery`。
```

### 6.1 R3 图片资产链检查

检查 `image_asset_set` 和 `image_generation_record` 是否能支撑最终 HTML：

```text
image_status 是否只用于单张图。
image_assets_status 是否只用于整组图。
每张 required 图是否有 generation_run_id。
每张 required 图是否有 image_asset_type。
每张 required 图是否有 image_production_path。
每张 pending_external 是否有 prompt_delivery_mode 和 external_model_payload_path。
generated 图片是否有本地 asset_path。
generated 图片是否有 metadata_sidecar_path。
pending_external 是否只展示占位、prompt 和插入位置。
generation_failed 是否有 failure_reason 和 retry_suggestion。
manual_required 是否有 human_action_required。
rejected 是否默认不进最终展示。
图片重做是否新建 image_asset_id，而不是覆盖旧图。
每张图是否能追溯到 beat、prompt、generation_record、provider、asset_path、metadata_sidecar 和 quality_gate。
```

视觉质检门：

```text
visual_quality_gate_status = pass：每张必要画中画都服务一个明确留存任务，且能说清不用它会损失什么。
visual_quality_gate_status = fail：图片存在但只是素材、装饰、场景泛化、与口播当下语义弱相关，或不能让观众多停 2-5 秒。
static_visual_quality_gate_status = pass：静态视觉编导方案能说明视觉角色、构图策略、风格锚点和留存任务。
static_visual_quality_gate_status = fail：图片直接复述内容语言、缺视觉角色、缺构图策略，或像临时素材。
cover_quality_gate_status = not_applicable：content_visual_review 阶段尚未进入封面成品编译。
cover_quality_gate_status = pass：cover_review 中成品或 prompt_only 降级状态诚实，文字、版式、安全区和平台策略通过。
cover_quality_gate_status = fail：只有封面标题 / 底图，composition_ready 无成品文件，模型文字错误，或封面承诺正文没有讲到。
prompt_integrity_status = pass：所有用于出图或最终交付的 prompt_integrity_check 均为 pass。
prompt_integrity_status = fail：任一 prompt 卡缺核心层，或实际 prompt_used 只是短关键词。
image_asset_trace_status = pass：required 图片都有 generation_record，generated 图片有 asset_path 和 sidecar，降级状态诚实。
image_asset_trace_status = fail：状态混用、缺 generation_record、缺 sidecar、路径不存在、或 pending / failed 被当成 generated。
asset_trace_quality_gate_status = pass：prompt、generation_record、metadata_sidecar、checksum、HTML embed 能互相追溯。
asset_trace_quality_gate_status = fail：任一链路缺失，或 HTML 展示无法回到来源。
html_embed_readiness_status = pass：generated / pending / failed / manual / rejected 都能被 final-delivery-builder 正确展示或隐藏。
html_embed_readiness_status = fail：HTML 无法区分展示图片、占位、prompt 卡、失败原因或 rejected 隐藏。
```

content_visual_review 中，如果 `visual_quality_gate_status = fail`、`static_visual_quality_gate_status = fail`、`prompt_integrity_status = fail`、`image_asset_trace_status = fail`、`asset_trace_quality_gate_status = fail` 或 `html_embed_readiness_status = fail`：

```text
review_status = review_needs_visual_fix
next_skill = talking-head-image-pip
blocking_issues 必须写明失败的 beat_id 和原因
不得写 review_pass
```

cover_review 中，如果 `cover_quality_gate_status = fail`：

```text
review_status = review_needs_visual_fix
next_skill = cover-design-compiler
只返工 cover_design_package / cover_composition，不默认重跑热点、Brief、口播或平台标题。
```

如果 `visual_plan` 缺失：

```text
本条明确不需要画中画 -> 可以继续质检，但必须说明理由。
本条需要画中画或无法判断 -> next_skill 回到 talking-head-image-pip。
```

## 用户交互引导语

需要用户参与时，不能只输出字段名，必须给口语化引导。

可用引导语：

```text
质检没过，我建议先别发。你可以回复“按建议改一版”，我会只改文案，不动选题。
这个问题不是文案小修，是选题/产品边界有风险。你可以回复“回到 Brief”，我们先把边界讲清楚。
首屏画面和 Hook 接不上。你可以回复“重做首屏画中画”，我会回到画中画环节。
质检通过了，但还没到发布确认。我会自动做四个平台的封面标题、视频标题、发布描述和话题标签，不需要你回复“继续做分发包”。
```

## 输出格式

完整质检报告必须写入：

```text
accounts/{账号名}/runs/{session_id}/intermediate/06-quality-review.md
```

根目录 `docs/explanation/dbskill质检记录.md` 只做汇总索引和复盘摘录；`workflow_session_record.current_artifact` 必须指向上述账号/session 文件。

```markdown
# 文案质检报告

## 输入状态
- review_mode：content_visual_review / cover_review
- draft_id：
- brief_id：
- 是否缺 brief：
- 内容形式：
- visual_plan_id：
- 是否缺 visual_plan：

## 总结论
- review_status：review_pass / review_needs_copy_fix / review_needs_visual_fix / review_needs_brief_fix / review_blocked
- visual_quality_gate_status：pass / fail / not_applicable
- static_visual_quality_gate_status：pass / fail / not_applicable
- cover_quality_gate_status：pass / fail / not_applicable
- prompt_integrity_status：pass / fail / not_applicable
- image_asset_trace_status：pass / fail / not_applicable
- asset_trace_quality_gate_status：pass / fail / not_applicable
- html_embed_readiness_status：pass / fail / not_applicable
- 结论：
- next_skill：
- human_prompt：
- human_reply_examples：
- recommended_action：
- auto_next_action：
- task_after_navigation：

## 阻断问题
| 问题 | 位置 | 为什么阻断 | 修改方向 |
|---|---|---|---|

## 质量检查
| 维度 | 结论 | 问题 | 修改建议 |
|---|---|---|---|
| 产品承诺 |  |  |  |
| 灰产误解 |  |  |  |
| 涛哥味 |  |  |  |
| AI 味 |  |  |  |
| 五秒留存 |  |  |  |
| 口播流畅度 |  |  |  |
| 前 5 秒 Hook |  |  |  |
| 首屏画中画 |  |  |  |
| 静态视觉编导 |  |  |  |
| 封面设计包 |  |  |  |
| 图片类型区分 |  |  |  |
| 图片生产路径 |  |  |  |
| 画中画贴合度 |  |  |  |
| Prompt 完整度 |  |  |  |
| 图片生成记录 |  |  |  |
| 图片 sidecar |  |  |  |
| 图片状态诚实 |  |  |  |
| HTML 嵌入准备 |  |  |  |
| 泛素材风险 |  |  |  |
| 视觉误导风险 |  |  |  |
| 共鸣核心 |  |  |  |
| 结尾动作 |  |  |  |

## 五秒留存评分
| 评分项 | 分值 | 得分 | 说明 |
|---|---:|---:|---|
| 话题清晰度 | 2 |  |  |
| Hook 强度 | 2 |  |  |
| 可信度 / 现场感 | 2 |  |  |
| 悬念或冲突 | 2 |  |  |
| 转场承接 | 1 |  |  |
| 口播顺滑 | 1 |  |  |
| 合计 | 10 |  |  |

## 哪里会划走
| 时间 / 段落 | 风险等级 | 原因 | 修复建议 |
|---|---|---|---|

## 建议改法
1. {最重要改法}
2. {次重要改法}
3. {可选改法}

## 流转状态
- review_status：
- next_skill：
- human_prompt：
- human_reply_examples：
- recommended_action：
- auto_next_action：
- task_after_navigation：

## 用户下一步怎么选
- 如果质检通过：自动进入平台包装，不要求用户回复“继续做分发包”。
- 如果你想先改口播：回复“按建议改口播”。
- 如果你想先改画中画：回复“重做画中画”。
- 如果你觉得产品边界没讲清：回复“回到 Brief”。
```

## next_skill 规则

```text
产品承诺或灰产误解有问题 -> 回到 brief / 选题
推导链虚 -> hotspot-topic-research
开头弱 -> 继续本 skill 给 hook 改法
五秒留存低于 7 分 -> copywriting-draft-writer
口播断 -> 继续本 skill 做标记式改稿建议
AI 味重 -> 继续本 skill 做涛哥味追问
visual_plan 缺失且需要画中画 -> talking-head-image-pip
画中画首屏不成立 -> talking-head-image-pip
画中画像泛素材或只装饰 -> talking-head-image-pip
prompt_integrity_status = fail -> talking-head-image-pip
image_asset_trace_status = fail -> talking-head-image-pip
static_visual_quality_gate_status = fail -> talking-head-image-pip
cover_review 且 cover_quality_gate_status = fail -> cover-design-compiler
asset_trace_quality_gate_status = fail -> talking-head-image-pip / final-delivery-builder
html_embed_readiness_status = fail -> talking-head-image-pip / final-delivery-builder
content_visual_review 全部通过 -> platform-packaging-adapter
cover_review 通过 -> final-delivery-builder
```

## 结束边界

本 skill 默认只给报告和修改建议。用户明确说“按建议改一版”时，才输出修改版；修改版仍标注 `待涛哥人工确认，未发布`。

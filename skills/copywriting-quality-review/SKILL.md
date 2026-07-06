---
name: copywriting-quality-review
description: 涛哥创作工作流文案与视觉联合质检 skill。Use when Codex is asked to “检查文案 / 文案能不能发 / 有没有 AI 味 / 像不像涛哥 / 哪里会划走 / 口播顺不顺 / 画中画合不合适 / 首屏图会不会抢口播 / 产品有没有硬插 / 有没有灰产误解 / dbskill 质检”。只诊断和给修改建议；通过后进入 platform-packaging-adapter，不自动发布、不改产品代码。
---

# Copywriting Quality Review

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
热点文案Skill方法论与SaaS承接设计.md
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
首屏画中画任务是否承接推荐 Hook。
画面是否解决明确留存风险。
画面是否会抢口播。
画面是否和口播语义一致。
画面是否误导产品能力。
画面是否泄露真实数据或虚构证据。
是否存在“好看但没用”的画面。
是否有必须画中画却漏掉的段落。
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

根目录 `dbskill质检记录.md` 只做汇总索引和复盘摘录；`workflow_session_record.current_artifact` 必须指向上述账号/session 文件。

```markdown
# 文案质检报告

## 输入状态
- draft_id：
- brief_id：
- 是否缺 brief：
- 内容形式：
- visual_plan_id：
- 是否缺 visual_plan：

## 总结论
- review_status：review_pass / review_needs_copy_fix / review_needs_visual_fix / review_needs_brief_fix / review_blocked
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
| 画中画贴合度 |  |  |  |
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
全部通过 -> platform-packaging-adapter
```

## 结束边界

本 skill 默认只给报告和修改建议。用户明确说“按建议改一版”时，才输出修改版；修改版仍标注 `待涛哥人工确认，未发布`。




---
name: copywriting-draft-writer
description: 涛哥创作工作流的短视频口播草案生成 skill。Use when Codex has a passed content Brief and needs to turn it into a first-draft talking-head script before picture-in-picture planning and quality review. First phase only writes short-video talking-head drafts; graphic posts, longform, Moments, community posts, FAQ, and official copy are reserved routes, not implemented here.
---

# Copywriting Draft Writer

## R1 Contract Runtime

```yaml
contract_set_version: r1-contract-set-v0.1
contract_version: 0.2.0
contract_status: confirmed
skill_type: producer
primary_input: content_brief(brief_status=brief_pass)
primary_output: draft
next_skill_on_pass: talking-head-image-pip
```

执行口径：

```text
本 skill 只写第一阶段短视频口播草案；不重新选题、不改 Brief 事实、不做画中画、不做最终质检。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读 R1 Runtime、输入门槛、生成原则和交接块，方法论细节按需读取。
文案质量同时看 Hook 和正文：Hook 路由、五秒留存、正文信息密度、承诺兑现、核心机制都必须输出。
draft_created 只有在推荐 Hook >= 7 且 body_information_density_score >= 7 时才允许进入 talking-head-image-pip。
```

读、取、传规则：

```text
读：content_brief、账号档案、产品边界、字段词典和内容质量补充。
取：从 Brief 取 content_source_id / content_origin、核心观点、证据或主张地图、产品承诺边界、禁区、CTA，不新增产品能力。
传：draft 必须带 draft_id、brief_id、content_source_id、content_origin、account、recommended_hook、hook_route、hook_score、body_information_density_score、core_mechanism、segment_map、draft_status、artifact_path、next_skill；热点入口保留 topic_id / source_research_run_id，直供入口保留 original_draft_artifact_id / digest / revision_policy，不互相伪造。
```

阻断：

```text
Hook 低于 7 分、正文信息密度低于 7 分、content_promise 无法兑现、core_mechanism 不清时，回本 skill 或 content-brief-compiler，不进入画中画。
```

R1 交接块：

```text
每次输出必须包含：
contract_set_version：r1-contract-set-v0.1
draft_id：
brief_id：
content_source_id：
content_origin：hotspot_selected_topic / user_supplied_draft
topic_id：热点入口填写；直供入口 not_applicable
account：
source_research_run_id：热点入口填写；直供入口 not_applicable
original_draft_artifact_id / original_draft_digest / revision_policy：直供入口填写；热点入口 not_applicable
hook_route：
hook_score：
body_information_density_score：
core_mechanism：
draft_status：
artifact_path：
next_skill：
human_gate：
execution_trace_update：
```

## 定位

本 skill 只负责一件事：

```text
已通过的 content brief
-> 短视频口播草案
-> 交给 talking-head-image-pip
```

它不是选题器，不重新判断热点，不重写 Brief，不做最终质检，不发布。

第一阶段默认只做“短视频口播”。图文、长文、朋友圈、社群、FAQ、官网说明和产品介绍先作为未来路由保留，不在本 skill 展开制作办法。

## 必读

```text
README.md
交接物字段词典.md
docs/reference/内容Brief记录.md
docs/reference/内容形式类型与载体字典.md
docs/reference/文案策略矩阵.md
docs/reference/热点文案Skill方法论与SaaS承接设计.md
skills/content-brief-compiler/SKILL.md
skills/talking-head-image-pip/SKILL.md
```

按需读：

```text
accounts/{账号名}/account_profile.md
skills/copywriting-quality-review/SKILL.md
```

## 输入门槛

只有满足以下条件才写草案：

```text
content_brief 的 `brief_status = brief_pass`。
brief_id、topic_id、账号、内容目标、目标人群、核心观点、热点事实、推导链、文案策略、产品承诺边界、不能怎么讲、CTA 齐全。
内容形式为空或为“短视频口播”时，第一阶段默认按短视频口播写。
```

以下情况必须停止，不写草案：

```text
Brief 缺信息。
Brief 风险高。
核心观点一句话说不清。
热点事实不可核验。
推导链被标记为过虚。
产品承诺边界不清。
账号定位和内容目标冲突。
用户明确要求图文、长文、朋友圈、社群、FAQ 或官网说明，但当前还没有对应制作流程。
```

## 生成原则

口播草案是第一版，不追求终稿，但必须能进入画中画和质检。

必须做到：

```text
不重新选题。
不重新发明热点事实。
不扩大产品能力。
不把公开互动分析工具讲成截流、灰产、批量获客、自动私信或跨平台识别工具。
不为了热度硬蹭。
默认轻产品露出，除非 Brief 明确要求强露出。
```

## 五秒留存设计

前 5 秒是本 skill 的第一优先级，不是普通 Hook 字段。

成熟内容方法论和 dbskill 共同口径：

```text
开头是内容的试用装。
好开头 = 话题 + Hook + 可信度。
观众前 5 秒划走，通常不是“文案不完整”，而是话题不清、停留理由不强、可信度不足、悬念断掉、正文接不住或口播不顺。
```

生成正文前，必须先生成“五秒留存设计”。至少输出 3 个 Hook 方案：

```text
大热点切口型
冲突判断型
痛点现场型
结果悬念型
反直觉型
```

不要求每次五种都全用，但至少 3 个方案。每个方案必须说明：

```text
话题：前 5 秒观众知道你在讲什么。
Hook：为什么值得继续看。
可信度 / 现场感：为什么听你说。
心理触发点：公共情绪 / 信息缺口 / 冲突判断 / 代入痛点 / 结果悬念。
转场句：如何自然接入正文第一观点。
首屏画中画任务：第一张图要解决什么留存问题。
风险：硬蹭 / 太窄 / 太虚 / 太书面 / 正文接不住。
```

五秒留存评分满分 10 分：

```text
话题清晰度：2 分
Hook 强度：2 分
可信度 / 现场感：2 分
悬念或冲突：2 分
转场承接：1 分
口播顺滑：1 分
```

推荐 Hook 低于 7 分时，`draft_status` 必须是 `draft_blocked` 或 `draft_needs_brief_fix`，不得进入画中画。

口播结构默认：

```text
标题备选
五秒留存设计
推荐 Hook
Hook 到正文的转场
热点事实 / 现场问题
推导链
核心观点
产品轻露出或不露出
结尾 CTA
```

## 自动流转

第一阶段人工默认只卡两个点：

```text
选题确认。
最终发布前确认。
```

Brief 通过后，默认自动推进：

```text
content-brief-compiler
-> copywriting-draft-writer
-> talking-head-image-pip
-> copywriting-quality-review
-> platform-packaging-adapter
-> 多平台分发包
-> 涛哥最终确认
```

本 skill 完成后，下一步默认是 `talking-head-image-pip`，不是直接质检。画中画用于补足口播的信息、情绪、热点画面和理解成本。

只有触发阻断条件时才停下来问涛哥。

## 用户交互引导语

需要用户参与时，不能只说字段缺失，要给可回复的话。

可用引导语：

```text
这个 Brief 还不能写稿，核心观点没定住。你可以回复“回到 Brief”，我们先把一句话观点定清楚。
我写出了 3 个开头方向。你可以回复“选 A / 选 B / 选 C”，也可以回复“按推荐继续”。
推荐 Hook 低于 7 分，我建议先别往下做画中画。你可以回复“重写开头”，我只重做前 5 秒。
草案已经能进入画中画了。下一步我会做画中画方案，不会直接发布。
```

## 输出格式

完整口播草案必须写入：

```text
accounts/{账号名}/runs/{session_id}/intermediate/04-draft.md
```

根目录文件只做索引或汇总；`workflow_session_record.current_artifact` 必须指向上述账号/session 文件。

```markdown
# 短视频口播草案

## 来源
- draft_id：
- brief_id：
- topic_id：
- 账号：
- 内容形式：短视频口播
- content_format：短视频口播
- next_skill：talking-head-image-pip

## 标题备选
1.
2.
3.

## 五秒留存设计
| 方案 | Hook | 类型 | 话题 | 停留理由 | 可信度 / 现场感 | 心理触发点 | 转场句 | 首屏画中画任务 | 风险 | 评分 |
|---|---|---|---|---|---|---|---|---|---|---|
| A |  | 大热点切口 / 冲突判断 / 痛点现场 / 结果悬念 / 反直觉 |  |  |  |  |  |  |  | /10 |
| B |  | 大热点切口 / 冲突判断 / 痛点现场 / 结果悬念 / 反直觉 |  |  |  |  |  |  |  | /10 |
| C |  | 大热点切口 / 冲突判断 / 痛点现场 / 结果悬念 / 反直觉 |  |  |  |  |  |  |  | /10 |

推荐 Hook：
推荐理由：
五秒留存评分：
是否允许进入正文：

## 口播草案
### Hook 与转场

### 正文

### 产品露出

### 结尾 CTA

## 画中画预标记
| 段落 | 是否需要画中画 | 为什么 | 初步画面方向 |
|---|---|---|---|

## 自检
| 检查项 | 结论 | 说明 |
|---|---|---|
| 是否贴合 Brief | 通过 / 不通过 |  |
| 是否偏离热点事实 | 通过 / 不通过 |  |
| 是否硬蹭 | 通过 / 不通过 |  |
| 是否硬插产品 | 通过 / 不通过 |  |
| 产品承诺是否越界 | 通过 / 不通过 |  |
| 五秒留存评分是否达到 7 分 | 通过 / 不通过 |  |
| Hook 和正文是否接得住 | 通过 / 不通过 |  |
| 是否适合进入画中画 | 通过 / 不通过 |  |

## 状态
- draft_status：draft_created / draft_needs_hook_fix / draft_needs_brief_fix / draft_blocked
- 阻断原因：
- next_skill：
- human_prompt：
- human_reply_examples：
```

## 结束边界

本 skill 不做：

```text
不生成图文、长文、朋友圈、社群、FAQ 或官网说明。
不生成最终发布稿。
不做 dbskill 质检。
不生成正式 image。
不自动发布。
```

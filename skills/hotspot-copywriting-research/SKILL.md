---
name: hotspot-copywriting-research
description: 涛哥创作工作流的旧热点文案研究兼容入口；“涛哥”是作者/方法论署名，不是目标账号。Use when Codex is asked to “涛哥 skill / 涛哥创作工作流 / 跑热点 skill / 热点文案 / 找热点写文案 / 按账号母题做内容 / 自媒体传播 / dbskill 质检”。本 skill 现在只做兼容路由：优先转到 propagation-router、hotspot-topic-research 或 copywriting-quality-review；不再承载全部流程。
---

# Hotspot Copywriting Research

## 定位

这是旧唤醒词兼容入口。正式中文总名是“涛哥创作工作流”；其中“涛哥”是作者/方法论署名，不代表目标账号。为避免一个 skill 过厚，正式流程已拆为：

```text
propagation-router：涛哥创作工作流总控和下一步路由
hotspot-topic-research：热点发现、评分、母题关联、推导链、选题卡
content-brief-compiler：已选题卡到内容 Brief 的上下文编译
copywriting-draft-writer：通过 Brief 到短视频口播草案的第一阶段写稿入口
talking-head-image-pip：口播草案到画中画视觉策略和 image 提示词
copywriting-quality-review：文案质检、AI 味、涛哥味、口播流畅度、产品风险
platform-packaging-adapter：质检通过后，为同一条视频生成抖音、快手、小红书、视频号入口包装
```

本 skill 不再重复三者的完整规则。

## 路由

用户说“跑热点 skill / 找热点 / 今日选题 / 热点评分”：

```text
转到 hotspot-topic-research
```

用户已有文案，问“能不能发 / 有没有 AI 味 / 像不像涛哥 / 哪里会划走 / dbskill 质检”：

```text
转到 copywriting-quality-review
```

用户不知道下一步，或希望按 dbskill 一样判断流程：

```text
转到 propagation-router
```

用户明确要求“一口气到文案草案”：

```text
先用 hotspot-topic-research 产出选题卡和推导链。
再用 content-brief-compiler 基于被选中的 topic_card 生成内容 Brief。
Brief 通过后用 copywriting-draft-writer 生成短视频口播草案。
再用 talking-head-image-pip 生成画中画视觉策略和 image 提示词。
最后用 copywriting-quality-review 做文案 + 视觉联合质检。
质检通过后，用 platform-packaging-adapter 生成封面标题、视频标题、发布描述和话题标签。
草案必须标注：待涛哥人工确认，未发布。
```

## 必读

```text
README.md
热点文案Skill方法论与SaaS承接设计.md
skills/propagation-router/SKILL.md
skills/hotspot-topic-research/SKILL.md
skills/content-brief-compiler/SKILL.md
skills/copywriting-draft-writer/SKILL.md
skills/talking-head-image-pip/SKILL.md
skills/copywriting-quality-review/SKILL.md
skills/platform-packaging-adapter/SKILL.md
```

## 边界

只到文案层，不自动发布，不接平台 API，不自动登录平台后台，不自动评论 / 私信 / 互动，不改产品代码、构建、服务器或真实数据。



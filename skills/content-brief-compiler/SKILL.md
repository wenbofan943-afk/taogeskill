---
name: content-brief-compiler
description: 涛哥创作工作流内容 Brief 编译 skill。Use when Codex 已有涛哥确认的 topic_card / 选题卡，需要把账号档案、热点事实、推导链、Topic Gate 结论、文案策略、产品边界和禁区编译成写文案前的内容 Brief。默认自动生成和质检 Brief，不写完整文案、不做 dbskill 文案质检、不发布。
---

# Content Brief Compiler

## R1 Contract Runtime

```yaml
contract_set_version: r1-contract-set-v0.1
contract_version: 0.1.0
contract_status: confirmed
skill_type: producer
primary_input: topic_card(topic_status=topic_selected_for_brief)
primary_output: content_brief
next_skill_on_pass: copywriting-draft-writer
```

执行口径：

```text
本 skill 把已选 topic_card 编译为 content_brief；不写正文、不做画中画、不做最终质检。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读 R1 Runtime、输入门槛和交接块，细节章节按需读取。
必须读取 topic_card 的标准字段，不从聊天里猜选题事实。
brief_pass 且 human_gate=no 时，自动进入 copywriting-draft-writer，不要求用户回复“继续写口播”。
```

读、取、传规则：

```text
读：topic_card、account_profile、product_profile / campaign_profile、字段词典、session manifest。
取：只取已确认 topic_card 的事实、推导链、策略、禁区和产品边界。
传：content_brief 必须带 brief_id、topic_id、account、product_profile_id / campaign_profile_id、source_research_run_id、brief_status、artifact_path、next_skill。
```

阻断：

```text
topic_status 不是 topic_selected_for_brief 时不得编译。
source_research_run_id、产品边界、推导链或风险禁区缺失时回 topic_card / product_profile 补齐。
```

R1 交接块：

```text
每次输出必须包含：
contract_set_version：r1-contract-set-v0.1
brief_id：
topic_id：
account：
product_profile_id / campaign_profile_id：
source_research_run_id：
brief_status：
artifact_path：
next_skill：
human_gate：
auto_next_action：
execution_trace_update：
```

## 定位

本 skill 是传播工作流里的“上下文编译层”：

```text
已选 topic_card
+ 账号档案
+ 热点事实
+ 推导链
+ Topic Gate 结论
+ 文案策略
+ 产品边界
+ 内容禁区
= 内容 Brief
```

它的目的不是让涛哥再审批一次，而是防止进入文案创作时 AI 失忆、跑偏、串号、硬卖产品或承诺越界。

## 必读

```text
README.md
账号档案完整性检查表.md
产品与活动对象档案.md
交接物字段词典.md
accounts/{账号名}/account_profile.md
自媒体选题库.md
内容Brief记录.md
内容形式类型与载体字典.md
文案策略矩阵.md
AI热点发现与关联评估方法论.md
热点文案Skill方法论与SaaS承接设计.md
```

按需读：

```text
热点候选池.md
热点评分表.md
skills/hotspot-topic-research/SKILL.md
skills/copywriting-quality-review/SKILL.md
skills/talking-head-image-pip/SKILL.md
```

## 输入门槛

只有满足以下条件才进入 Brief 编译：

```text
topic_card 已被涛哥选择，`topic_status = topic_selected_for_brief`。
Topic Gate 结论是“通过，待选择”或涛哥明确要求继续。
账号档案 P0 字段齐全。
产品/活动对象边界齐全。
topic_card 带 `source_research_run_id`。
热点事实、来源、推导链、文案策略至少有基础信息。
```

如果用户只说“写文案”，但没有已确认 topic_card，先回到 `hotspot-topic-research`。

topic_card 必填字段：

```text
topic_id
source_research_run_id
product_profile_id
campaign_profile_id
账号
选题名称 / 标题
热点
热点池
事实来源 / 来源时间
文案策略
目标人群
账号母题
产品能力
桥接状态
Gate 结论
推导链
最虚一跳
不能怎么讲
风险
内容形式
topic_status
next_skill
```

缺字段时不要编译 Brief；输出缺字段清单，并要求回到选题卡补齐。

## 默认交互

content_brief 默认自动生成，不默认停下来问涛哥。

如果 `brief_status = brief_pass` 且 `human_gate = no`，本节点不得把“继续写口播”作为人工确认项输出；必须自动流转到 `copywriting-draft-writer`。任务后导航只能说明“已自动进入下一环节 / 如需打断可回退”，不能要求涛哥再回复一句才继续。

只有遇到以下情况才停下来确认：

```text
内容目标冲突：同时想曝光、强转化、教育、复盘，无法取舍。
账号定位冲突：例如“涛哥汽车观察”被要求强卖产品。
产品露出不清：强露出、轻露出、不露出无法判断。
核心观点不清：一句话说不清这条内容到底讲什么。
事实风险高：热点来源不稳、事实等级低或争议敏感。
CTA 不清：不知道让用户关注、评论、私信、申请试用还是去主页。
需要调用外部 IP 资产但找不到：表达工坊、知识原子、认知档案等缺失。
当前产品能力支撑不了选题承诺。
```

内容形式、内容类型和外挂项默认由 AI 根据 `内容形式类型与载体字典.md` 判断，不默认问涛哥。

只在以下情况问：

```text
口播和图文都明显可行，但目标不同。
产品演示是否需要真人出镜不清楚。
官网说明 / FAQ 是否要对外公开不清楚。
平台适配成本过高，需要取舍。
```

询问时只问一个简单问题，例如：

```text
这条更想做口播、图文，还是长文？
```

## 编译步骤

### Step 1：读取选题卡

从对话或 `自媒体选题库.md` 提取：

```text
topic_id
账号
选题名称
热点
热点池
事实来源 / 来源时间
文案策略
目标人群
账号母题
产品能力
桥接状态
Gate 结论
推导链
最虚一跳
不能怎么讲
风险
内容形式
topic_status
next_skill
```

### Step 2：读取账号档案

读取 `accounts/{账号名}/account_profile.md`，至少提取：

```text
账号定位
业务目标
目标人群
核心业务 / 产品 / 服务
当前阶段
账号母题
内容禁区
转化路径
可蹭热点类型
禁蹭热点类型
产品露出偏好
```

### Step 3：编译内容 Brief

Brief 必须把写作前的关键变量定死：

```text
brief_id
topic_id
source_research_run_id
product_profile_id
campaign_profile_id
账号
内容目标
目标人群
核心观点
热点事实
事实来源
推导链
最虚一跳
文案策略
内容形式
内容类型
外挂项建议
发布渠道建议
账号语气
产品露出比例
产品承诺边界
不能怎么讲
开头方向
正文结构
结尾动作 / CTA
成功指标
人工确认点
```

### Step 4：Brief 质检

进入文案前必须自检：

```text
目标是否单一？
人群是否具体？
核心观点是否一句话说清？
热点事实是否可靠？
推导链是否仍然成立？
是否有硬蹭或强插产品？
内容形式是否匹配？
内容类型是否匹配？
外挂项是否必要且不过度？
产品露出是否过重？
CTA 是否符合账号和产品阶段？
有没有当前产品支撑不了的承诺？
是否需要涛哥确认？
```

### Step 5：落盘

content_brief 生成后写入 `内容Brief记录.md`。

完整 Brief 正文必须写入：

```text
accounts/{账号名}/runs/{session_id}/intermediate/03-content-brief.md
```

`内容Brief记录.md` 只做汇总索引和必要摘录。工作流状态记录里的 `current_artifact` 必须指向账号/session 目录下的具体 Brief 文件，而不是只指向根目录汇总表。

状态只能是：

```text
brief_pass
brief_needs_human_confirm
brief_risk_high
brief_needs_format_change
brief_blocked
```

如果 `brief_status` 不是 `brief_pass`，必须停止，不进入文案草案。

如果 `brief_status = brief_pass` 且 `human_gate = no`：

```text
next_skill：copywriting-draft-writer
处理方式：自动进入短视频口播草案
禁止：输出“请回复继续写口播 / 是否继续 / 是否进入下一步”之类的二次确认
```

## 输出格式

```markdown
# 内容 Brief

## 来源
- brief_id：
- topic_id：
- source_research_run_id：
- product_profile_id：
- campaign_profile_id：
- 账号：
- 选题：
- Topic Gate 结论：

## 写作输入包
- 内容目标：
- 目标人群：
- 核心观点：
- 热点事实：
- 事实来源：
- 推导链：
- 最虚一跳：
- 文案策略：
- 内容形式：
- 内容类型：
- 外挂项建议：
- 发布渠道建议：
- 账号语气：
- 产品露出比例：
- 产品承诺边界：
- 不能怎么讲：
- 开头方向：
- 正文结构：
- 结尾动作 / CTA：
- 成功指标：

## Brief 质检
| 检查项 | 结论 | 说明 |
|---|---|---|
| 目标单一 | 通过 / 不通过 |  |
| 人群具体 | 通过 / 不通过 |  |
| 核心观点清楚 | 通过 / 不通过 |  |
| 事实可靠 | 通过 / 不通过 |  |
| 推导链成立 | 通过 / 不通过 |  |
| 产品露出合适 | 通过 / 不通过 |  |
| 内容形式合适 | 通过 / 不通过 |  |
| CTA 合理 | 通过 / 不通过 |  |
| 产品承诺不越界 | 通过 / 不通过 |  |

## 状态
- brief_status：
- human_gate：
- next_skill：
- human_prompt：
- human_reply_examples：
- recommended_action：
- auto_next_action：
- task_after_navigation：

## 落盘动作
- 已写入内容Brief记录：
- 未写入原因：
```

## 结束边界

Brief 通过后，默认自动进入文案草案；Brief 不通过时，必须停在问题清单，不得强行写稿。

如果 Brief 通过，收口引导只能说明自动流转：

```text
Brief 已经能写稿了，我会自动进入口播草案，不需要你再回复“继续”。如果你想打断，直接说“回到 Brief 改核心观点”。
```

本 skill 不做：

```text
不写完整文案。
不做 dbskill 文案质检。
不生成画中画提示词。
不发布。
不改客户端、服务器、数据库、模型链路或真实数据。
```




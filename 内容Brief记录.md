# 内容 Brief 记录

> 状态：当前传播研究工作表  
> 主责：记录已选择选题进入文案创作前的内容 Brief。  
> 边界：本表是写作输入包和审计记录，不是产品规格、工程任务、发布承诺或正式文案。

---

## 使用规则

内容 Brief 是自动生成的中间产物，不是默认人工审批节点。

默认流程：

```text
涛哥选择 topic_id
-> 自媒体选题库 `topic_status` 改为 `topic_selected_for_brief`
-> 编译内容 Brief
-> Brief 自检
-> `brief_status = brief_pass` 且 `human_gate = no` 则自动进入文案草案
-> 缺信息或高风险才停下来问涛哥
```

执行规则：

```text
Brief 通过不是默认人工审批点。
brief_status = brief_pass 且 human_gate = no 时，不能要求涛哥回复“继续写口播”。
只有 human_gate = yes 或 brief_status 不是 brief_pass，才输出需要人类选择的停顿项。
完整 Brief 正文必须同步写入 `accounts/{账号名}/runs/{session_id}/intermediate/03-content-brief.md`，本文件只做汇总索引和必要摘录。
```

Brief 的作用：

```text
防止 AI 写文案时忘记账号。
防止曝光型内容被写成销售文案。
防止热点桥接在写稿时变形。
防止产品承诺越界。
防止文案质检时才发现方向错了。
```

---

## Brief 表

| 日期 | brief_id | topic_id | account | topic_title | content_goal | target_audience | core_point | strategy | content_format | content_type | addon_suggestions | product_mention_level | cta | brief_status | human_gate | next_skill |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|  |  |  |  |  | 曝光 / 信任 / 转化 / 种草 / 复盘 |  |  | 大热点破圈 / 垂类获客 / 教育信任 / 产品演示 / 复盘共创 | 短视频口播 / 短视频录屏 / 图文 / 轮播 / 长文 / 公众号 / 官网说明 / FAQ | 观点评论 / 热点解读 / 案例拆解 / 教程说明 / 产品演示 / 用户反馈复盘 / FAQ答疑 / 清单总结 | 画中画 / 封面标题 / 内容标题 / 发布描述 / 话题标签 / 平台适配版本 | strong / light / none | 关注 / 评论 / 私信 / 申请试用 / 去主页 | brief_pass / brief_needs_human_confirm / brief_risk_high / brief_needs_format_change / brief_blocked | yes / no | copywriting-draft-writer / human_confirm |
| 2026-07-06 | B20260706-002 | T20260706-002 | 示例垂类经营号 | 本地经营者别再只卷价格了，2026 年要卷信任 | 信任 + 垂类获客 | 二手本地经营者、行业销售团队、门店老板 | 本地经营者卷不过厂家价格战，但可以卷自己的信任资产 | 垂类获客型 | 短视频口播 | 观点评论 | 画中画、封面标题、内容标题、发布描述、话题标签、平台适配版本 | light | 引导了解免费学习版申请，适合者再人工沟通 | brief_pass | no | copywriting-draft-writer |
| 2026-07-06 | B20260706-009 | T20260706-009 | 示例行业观察号 | 155 款车下乡，新趋势车真正的战场变了 | 曝光 + 行业趋势 | 县乡做决策用户、关注新趋势车下沉的人、本地经营者和销售团队 | 新趋势车下乡真正考验充电、售后和真实使用场景 | 行业趋势观点 | 短视频口播 | 观点评论 | 画中画、封面标题、发布描述、话题标签、平台适配版本 | none | 关注示例行业观察号 | brief_pass | no | copywriting-draft-writer |
| 2026-07-06 | B20260706-008 | T20260706-008 | 示例行业观察号 | 新产品安全新国标来了，做决策别只盯续航 | 曝光 + 收藏 | 准备买新趋势车的人、关心电池安全的人、销售顾问 | 买新产品不能只看续航和价格，也要看安全标准 | 教育信任型 | 短视频口播 | 热点解读 / 清单总结 | 画中画、封面标题、发布描述、话题标签、平台适配版本 | none | 关注示例行业观察号 | brief_pass | no | copywriting-draft-writer |
| 2026-07-06 | B20260706-007 | T20260706-007 | 示例行业观察号 | 新趋势车不是不交税了，而是红利要重新算账了 | 曝光 + 评论 | 做决策用户、关注新趋势车成本的人、行业行业围观者 | 新趋势车从补贴和免税红利进入真实成本竞争阶段 | 大热点破圈型 | 短视频口播 | 热点解读 / 观点评论 | 画中画、封面标题、发布描述、话题标签、平台适配版本 | none | 关注示例行业观察号 | brief_pass | no | copywriting-draft-writer |

---

## Brief 模板

```text
brief_id：
topic_id：
account：
topic_title：
Topic Gate 结论：

content_goal：
target_audience：
core_point：
hotspot_fact：
source：
derivation_chain：
weakest_jump：
strategy：
content_format：
content_type：
addon_suggestions：
channel_suggestions：
account_tone：
product_mention_level：
product_claim_boundary：
must_not_say：
opening_direction：
body_structure：
cta：
success_metric：
human_gate：

brief_status：
next_skill：
human_prompt：
human_reply_examples：
```

---

## Brief 质检表

| brief_id | 目标单一 | 人群具体 | 核心观点清楚 | 事实可靠 | 推导链成立 | 产品露出合适 | CTA 合理 | 产品承诺不越界 | brief_status |
|---|---|---|---|---|---|---|---|---|---|
|  | 通过 / 不通过 | 通过 / 不通过 | 通过 / 不通过 | 通过 / 不通过 | 通过 / 不通过 | 通过 / 不通过 | 通过 / 不通过 | 通过 / 不通过 | brief_pass / brief_needs_human_confirm / brief_risk_high / brief_needs_format_change / brief_blocked |
| B20260706-002 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | brief_pass |
| B20260706-009 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | brief_pass |
| B20260706-008 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | brief_pass |
| B20260706-007 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | 通过 | brief_pass |

---

## brief_id: B20260706-002

## 来源

- brief_id：B20260706-002
- topic_id：T20260706-002
- source_research_run_id：R20260706-001
- product_profile_id：P-public-interaction-tool
- campaign_profile_id：C-free-learning-trial
- account：示例垂类经营号
- topic_title：本地经营者别再只卷价格了，2026 年要卷信任
- Topic Gate 结论：通过，待选择；已由涛哥选择进入 Brief

## 写作输入包

- content_goal：信任 + 垂类获客。先建立“本地经营者经营不能只靠低价”的判断，再轻带公开互动整理工具。
- target_audience：二手本地经营者、行业销售团队、门店老板，尤其是被价格战挤压、但又想通过短视频和直播建立信任的人。
- core_point：本地经营者卷不过厂家价格战，但可以卷自己的信任资产；信任不是口号，是持续回应客户真实问题。
- hotspot_fact：行业行业反内卷、价格战转价值战仍在公开媒体和行业讨论中出现，本轮定位为行业趋势观点，不包装成即时热点。
- source：证券时报、中青行业频道等公开报道；调研运行记录 R20260706-001。
- source_time：持续讨论（本轮 2026-07-06 核验）。
- hotspot_time_window：warm_trend_7_30d
- hotspot_freshness_status：aging_but_usable
- content_position：industry_trend
- derivation_chain：反内卷 -> 价格战不可持续 -> 本地经营者要建立信任 -> 信任来自真实问题回应 -> 公开互动整理能帮助复盘这些问题。
- weakest_jump：从行业大话题落到单个本地经营者自媒体动作，容易讲大讲空。
- strategy：垂类获客型；用行业趋势观点做切口。
- content_format：短视频口播
- content_type：观点评论
- addon_suggestions：画中画、封面标题、内容标题、发布描述、话题标签、平台适配版本；首屏优先做“价格战 / 信任战”对比图。
- channel_suggestions：抖音、快手、小红书、视频号。
- account_tone：本地经营者经营视角，直接、接地气、少讲宏大口号，多讲门店能做的小动作。
- product_mention_level：light
- product_claim_boundary：只能说整理公开评论、直播间互动和客户公开问题，辅助复盘和发现高价值反馈；不能说解决价格战、降低获客成本、自动成交或自动触达客户。
- must_not_say：不能说工具能解决价格战；不能承诺获客成本下降；不能讲截流、批量私信、自动获客、获取联系方式或绕过平台规则。
- opening_direction：先把大话题压到本地经营者现场：“价格战这件事，小本地经营者改不了，但你至少能改一件事：别让客户问过的问题白白流走。”
- body_structure：1. 先承认价格战和反内卷是行业趋势，不装作今天刚爆；2. 拉回本地经营者现实，单店很难改变厂家价格策略；3. 提出信任资产的定义：客户问过什么、担心什么、反复卡在哪里；4. 给出动作：把评论区和直播间公开互动整理成复盘表；5. 轻点工具，公开互动分析工具适合做公开问题整理和 AI 分类；6. 收到免费学习版申请，但先强调适用边界。
- cta：如果你也想把评论区和直播间问题整理成复盘表，可以了解免费学习版申请；适合做学习、复盘和内部经营，不适合拿去骚扰用户。
- success_metric：完播、收藏、评论区讨论、主页访问、免费学习版有效申请。

## Brief 质检

| 检查项 | 结论 | 说明 |
|---|---|---|
| 目标单一 | 通过 | 主目标是信任，副目标是垂类获客，不做强产品演示。 |
| 人群具体 | 通过 | 明确给二手本地经营者、销售团队和门店老板。 |
| 核心观点清楚 | 通过 | “卷信任资产”能承接价格战趋势和账号母题。 |
| 事实可靠 | 通过 | 多来源行业讨论支撑，但只按行业趋势使用。 |
| 推导链成立 | 通过 | 已用“小本地经营者改不了价格战，但能改回应客户问题”补桥。 |
| 产品露出合适 | 通过 | 产品只作为复盘公开互动的工具轻带。 |
| 内容形式合适 | 通过 | 短视频口播适合观点判断和经营建议。 |
| CTA 合理 | 通过 | 只引导了解免费学习版和人工沟通，不承诺效果。 |
| 产品承诺不越界 | 通过 | 已排除自动获客、截流、降成本和成交承诺。 |

## 状态

- brief_status：brief_pass
- human_gate：no
- next_skill：copywriting-draft-writer
- human_prompt：本节点无需人工确认，Brief 通过后应自动进入短视频口播草案；如果要打断自动流转，可以说“回到选题”“改成更狠一点的开头”或“产品露出再轻一点”。
- human_reply_examples：回到选题 / 改成更狠一点的开头 / 产品露出再轻一点

## 落盘动作

- 已写入内容Brief记录：是
- artifact_path：accounts/示例垂类经营号/runs/SAMPLE-HISTORICAL-001/intermediate/03-content-brief.md
- 未写入原因：无



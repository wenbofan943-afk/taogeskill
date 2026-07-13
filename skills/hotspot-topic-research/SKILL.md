---
name: hotspot-topic-research
description: 涛哥创作工作流热点选题研究 skill。Use when Codex is asked to “找热点 / 评热点 / 热点选题 / 账号母题关联 / 推导链 / 今天做什么内容 / 先别写文案”。只产出热点候选池、评分表、选题卡和推导链，默认停在涛哥确认，不写完整文案、不发布。
---

# Hotspot Topic Research

## R1 Contract Runtime

```yaml
contract_set_version: r1-contract-set-v0.1
contract_version: 0.2.0
contract_status: confirmed
skill_type: producer
primary_input: account_profile + product_profile / campaign_profile
primary_output: research_run_record + topic_card
next_skill_on_human_select: content-brief-compiler
```

执行口径：

```text
本 skill 只产 research_run_record、hotspot_candidate、topic_selection_panel、topic_card，不写 Brief、不写口播、不做平台包装。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读 R1 Runtime、账号/产品门禁和 Topic Gate，三池/桥接/评分细节按需读取。
账号档案和产品 / 活动对象是硬门禁；换账号后必须先做账号档案对齐确认。
research_run_id 必须贯穿 topic_card，后续下游使用 source_research_run_id 传递。
热点必须输出 hotspot_time_window、hotspot_freshness_status、content_position；时效不够时降级为行业趋势、复盘、常青问题或方法论内容。
R5-H2：先解析 `radar_policy_ref` / `query_lexicon_ref`；二手车直接且事实可核验的候选少于 3 条才可启用新车外溢，每条外溢必须写传导证明。扩词可探索但必须受账号禁区约束，选择反馈只更新辅助计数与偏好状态，不把单词写成唯一归因。
R5-H3：先记 `signal`，按主体/动作/时间窗/地点/业务链路归并 `event`，再产生账号 `candidate`，只有人工选择才成为 `topic`。单次快照不得标 rising/sustained/cooling；事实、传播与风险分开写。
R5-H4：每个探索词写入 term-selection-ledger 与 query-effectiveness。两次以上辅助被选且多于拒绝时 preferred；两次以上辅助被拒且多于被选时 deprioritized；仅 account exclusion、合规或用户明确封禁才 blocked；所有计数均为辅助证据。
R5-H5：开始本 skill 前，先由 `propagation-router` 执行 `tools/invoke-account-startup-check.ps1`。只有 `startup_result=account_ready` 且 `account_snapshot_status=snapshot_ready` 才可开始来源检索；每轮最多 3 个口语补问。热点任务缺视觉身份只记为 non-blocking，不得因此阻断；高风险话题默认 `verify_mechanism_only`，只做交叉核验与行业机制拆解。
```

读、取、传规则：

```text
读：读取账号档案、产品 / 活动对象、来源池和本轮 session 目录。
取：从公开来源取事实、发布时间、热度信号和来源质量；涉及今天 / 最新 / 热点必须联网核验。
传：推荐选题卡必须带 topic_id、account、product_profile_id / campaign_profile_id、source_research_run_id、topic_status、artifact_path、next_skill。
传：Topic Gate 给人选择前，必须先产出 topic_selection_panel，说明探索范围、候选漏斗、过滤原因、候选角色、默认推荐和选择代价。
```

人类门禁：

```text
只有 Topic Gate 是本 skill 的正常人工选择点。
用户选择单个 topic_id 后，立即把 topic_status 写为 topic_selected_for_brief，并自动进入 content-brief-compiler。
用户说“三篇都做 / 都要”时，写 last_decision=branch_request、blocked_reason=needs_r2_fan_out，不在 R1 单链路硬跑。
```

R1 交接块：

```text
每次输出必须包含：
contract_set_version：r1-contract-set-v0.1
research_run_id：
topic_id：
account：
product_profile_id / campaign_profile_id：
source_research_run_id：
topic_status：
topic_selection_panel_id：
panel_status：
recommended_topic_id：
artifact_path：
next_skill：
human_gate：
decision_type：Topic Gate 选择时为 select；多选时为 branch_request
execution_trace_update：
```

## 定位

本 skill 只负责：

```text
热点发现
-> 三池雷达
-> S/B/A/C/D 桥接
-> 初筛
-> 评分
-> 文案策略判断
-> 推导链
-> 选题卡
-> 等涛哥确认
```

不负责写完整文案、不负责质检、不负责发布。默认允许把研究过程写入 `docs/reference/热点候选池.md`、`docs/reference/热点评分表.md` 和 `docs/reference/自媒体选题库.md`；这些只属于传播研究资产，不是产品规格、工程任务或发布承诺。

## 必读

```text
README.md
docs/reference/账号档案完整性检查表.md
docs/reference/产品与活动对象档案.md
交接物字段词典.md
docs/reference/账号母题与传播工作流.md
docs/reference/AI热点发现与关联评估方法论.md
docs/reference/热点搜索来源池.md
docs/reference/调研运行记录.md
docs/reference/热点候选池.md
docs/reference/热点评分表.md
docs/reference/自媒体选题库.md
docs/reference/内容形式类型与载体字典.md
docs/reference/文案策略矩阵.md
docs/reference/热点文案Skill方法论与SaaS承接设计.md
```

需要联网找“今天 / 最新 / 热点”时必须浏览，并保留来源链接、发布时间和热度信号。

热点研究必须做时效判断。不能只写 `time_range`，还要输出：

```text
hotspot_time_window
hotspot_freshness_status
content_position
```

账号决定默认时间窗，内容策略决定最终时效要求，来源发布时间负责兜底校验。超过时效窗口的内容必须降级为行业趋势、复盘、常青问题或方法论内容，不能硬叫热点。

## 账号与产品对象门禁

热点选取必须先绑定账号和产品/活动对象。账号回答“谁来说”，产品/活动对象回答“这轮内容说什么、不能怎么说、希望用户下一步做什么”。不要在未确认账号和产品对象时直接找热点。

执行顺序：

```text
1. 从用户话里识别账号。
2. 如果用户没说账号，先问：这次给哪个账号做热点？
3. 到 accounts/{账号名}/account_profile.md 查找账号档案。
4. 如果档案不存在，按 docs/reference/账号档案完整性检查表.md 创建草案，并先问涛哥补齐 P0 字段。
5. 如果档案存在，检查 P0 字段是否齐全。
6. 执行账号启动检查：按任务只补发布平台 / 时长、受众优先级、高风险口径、雷达策略等实际缺口；每轮最多 3 问，并生成本 session 的 `account_snapshot_ref`。
7. `account_needs_input` / `account_policy_incomplete` / `account_blocked` 时不进入来源检索；热点任务缺视觉身份只写入 `non_blocking_fields`。
8. `account_ready` 后读取或创建 `product_profile / campaign_profile`。
9. 产品/活动对象边界齐全后，才进入热点发现。
```

账号档案对齐确认不是二次确认废话，而是换账号时的必要防串台门禁。必须说明原因：账号实际情况可能发生偏移，旧档案会导致热点、语气、产品露出和禁区不符合预期。

对齐输出格式：

```markdown
## 账号档案对齐

- 账号：
- 档案位置：
- 为什么先对齐：避免账号实际情况变化后，仍按旧画像创作，导致选题、语气、产品露出和禁区偏离预期。

### 我读到的当前档案
- 账号定位：
- 业务目标：
- 目标人群：
- 核心业务 / 产品 / 服务：
- 当前阶段：
- 账号母题：
- 内容禁区：
- 转化路径：
- 产品 / 服务露出比例：

### 你可以怎么回
- 如果没变化：回复“认可 / 同意 / 没变化 / 就按这个”。
- 如果要改：直接说“目标人群改成……”“这条不要引导……”“禁区加上……”。

### 状态
- account_profile_confirmed_for_session：pending
- next_skill：human_confirm
```

用户回复认可后，必须写入本轮 `manifest.yaml` 或 `workflow_session_record`：

```text
account_profile_confirmed_for_session：yes
account_profile_confirmed_at：YYYY-MM-DD
```

然后自动继续产品 / 活动对象检查和热点研究，不再问“是否继续”。

补档案时必须按 `docs/reference/账号档案完整性检查表.md` 的口语化问法执行：

```text
不要直接问“业务目标是什么 / 账号母题是什么 / 转化路径是什么”。
一次最多问 3 个问题。
问题要让普通人能直接回答。
用户回答后，由 agent 归纳成结构化字段，再写入账号档案。
不确定项写“待确认”，不要编造。
```

用户回答后必须先做落盘质检，不能原样落盘：

```text
回答了问题 -> 能归入字段 -> 不和账号定位/禁区冲突 -> 足够具体 -> 才可归纳落盘。
不相关、玩笑、个人偏好、临时想法、过度模糊、风险表达 -> 不落盘，追问或写待确认。
```

示例：

```text
问：这个号主要想完成什么？涨粉、建立信任、接咨询，还是沉淀观点？
答：我喜欢小狗。
处理：不写入“业务目标”；提示这是个人偏好，换问法追问。
```

P0 字段：

```text
账号名
账号定位
业务目标
目标人群
核心业务 / 产品 / 服务
当前阶段
账号母题
内容禁区
转化路径
```

缺 P0 时输出账号档案检查，不进入热点搜索。

产品/活动对象边界最低要求：

```text
product_name 或 campaign_name
positioning 或 campaign_goal
target_audience
allowed_claims
forbidden_claims
conversion_goal 或 conversion_path
cta_boundary
```

缺产品/活动对象边界时，不进入热点搜索；先按 [产品与活动对象档案](../../docs/reference/产品与活动对象档案.md) 补齐最小字段。

缺 P0 时的输出格式：

```markdown
## 账号档案检查
- 账号：
- 档案位置：
- 结论：需补齐后再进入热点

## 这次先补 1-3 个问题
1. {口语化问题}
2. {口语化问题}
3. {口语化问题}

## 用户回答后的落盘质检
| 目标字段 | 用户回答 | 质检结论 | 处理 |
|---|---|---|---|
```

如果用户要求临时跑一轮，必须标注：

```text
本轮使用临时账号假设，结果不得沉淀为正式账号策略。
```

## 输入卡

从用户话里和账号档案提取。账号档案优先级高于通用默认值：

```text
账号：
账号定位：
业务目标：
目标人群：
核心业务 / 产品 / 服务：
product_profile_id：
campaign_profile_id：
本轮产品 / 活动对象：
允许表达：
禁止表达：
账号母题：
可蹭热点类型：
禁蹭热点类型：
内容禁区：
内容目标：
热点范围：今天 / 本周 / 近 30 天
热点时效默认：按账号类型和内容策略自动判断
是否允许大热点：默认允许，但必须过推导链
输出数量：候选 10-20，初筛 5-8，正式选题 3-5
```

## 三池热点雷达

账号档案不是搜索关键词生成器。账号档案定义的是“这个账号能接住什么热点”，不是只按账号字段窄搜。

开始搜索前，必须先读 `docs/reference/热点搜索来源池.md`，按账号和三池生成本轮来源计划。
来源计划生成后，必须形成 `research_run_record`，并写入 `docs/reference/调研运行记录.md` 或在输出中给出可落盘记录。不要直接从“来源计划”跳到“热点候选池”。

来源计划格式：

```markdown
## 本轮来源计划
- 账号：
- 账号阶段：
- 时间范围：
- 三池权重：

| 池 | 本轮来源 | 为什么选 | 预计找什么 | 风险 |
|---|---|---|---|---|
| S |  |  |  |  |
| B |  |  |  |  |
| A/C |  |  |  |  |
```

来源计划由 agent 自动生成；只有来源明显不适合、需要登录、涉及真实数据或有风险时，才停下来问涛哥。

调研运行记录格式：

```markdown
## research_run_id: RYYYYMMDD-001
- account：
- product_profile_id：
- campaign_profile_id：
- research_goal：
- time_range：
- hotspot_time_window：
- hotspot_freshness_status：
- content_position：
- source_plan：
- sources_used：
- search_queries：
- source_quality_notes：
- fact_check_notes：
- candidate_count：
- selected_candidate_count：
- discarded_candidate_count：
- risk_notes：
- research_status：research_planned / research_done / research_needs_more_sources / research_blocked
- next_skill：hotspot-topic-research
```

调研运行记录必须回答：

```text
本轮为什么搜这些来源？
实际用了哪些来源？
来源是否公开可访问？
发布时间是否清楚？
热度信号是否能解释？
有没有单来源风险？
哪些内容没有进入候选池，为什么？
```

热点发现必须同时看三类池：

```text
S 池：公共大热点 / 大时代情绪 / 全民关注事件
B 池：行业热点 / 圈层热点 / 平台和市场变化
A/C 池：目标人群现场 / 账号母题附近的真实问题
```

### S 池

目的：发现更大的公共注意力入口。

典型方向：

```text
公共政策
社会情绪
消费变化
就业 / 创业焦虑
AI / 科技大事件
平台级变化
全民讨论话题
大品牌 / 大企业事件
```

S 池不要求一开始就和产品有关，但必须能尝试桥接到 B/A/C/D。

来源优先从来源池的 S 池选择，例如公共热榜、搜索趋势、新闻源、科技/平台大事件源。

### B 池

目的：发现行业和圈层正在讨论什么。

来源由账号档案决定：

```text
行业媒体
垂类账号
同行内容
平台规则
产品/工具圈
行业观察 / 本地商家 / AI / 消费决策等账号相关圈层
```

来源优先从来源池的 B 池选择，并按账号档案的行业和目标人群筛选。

### A/C 池

目的：发现目标人群现场和账号母题附近的具体问题。

来源：

```text
用户评论
申请表
客户反馈
测试机反馈
同行评论区
账号母题里的长期问题
```

来源优先从来源池的 A/C 池选择。涉及客户聊天、申请表、测试机反馈等真实数据时必须脱敏；不能在回复中暴露个人信息。

## 桥接规则

每个热点必须判断它在哪个池，并尝试桥接：

```text
S：大公共热点 / 大时代情绪 / 全民关注事件
B：行业热点 / 圈层热点
A：目标人群现场
C：账号母题
D：产品 / 服务 / 观点落点
```

桥接链：

```text
S -> B -> A -> C -> D
```

不是所有热点都必须从 S 开始：

```text
S 池热点：必须写 S -> B -> A -> C -> D
B 池热点：必须写 B -> A -> C -> D
A/C 池热点：必须写 A -> C -> D
常青内容：必须写 A -> C -> D，并说明为什么无需热点
```

判断规则：

```text
能完整桥接：进入评分。
只能到 B，接不到 A/C：只做轻观点，不进正式选题。
能到 A/C，但 D 很硬：可以做账号观点，不强插产品。
任一关键跳只能靠想象：标记“不建议做”。
```

桥接不是“AI 能不能说圆”，而是“每一跳是否有真实依据”。必须警惕 AI 把硬蹭说成自然关联。

桥接状态：

```text
未桥接：没有写出链路，不能进入选题。
弱桥接：有链路，但关键跳转依据薄，只能待补桥或降级轻观点。
可桥接：链路基本成立，可以进入评分。
强桥接：每一跳都有清楚依据，优先推荐。
硬蹭嫌疑：看似有链路，但主要靠口号、类比或情绪硬拉，淘汰或重写角度。
```

桥接质检必须回答：

```text
桥接状态：
最虚一跳：
这一跳的证据：
是否靠类比 / 口号 / 情绪硬拉：
能否补桥：
是否需要降级：
结论：推荐 / 待补桥 / 降级轻观点 / 淘汰
```

输出必须说明：

```text
热点来自哪个池
桥接链每一跳的依据
哪一跳最虚
如何补桥
为什么不是硬蹭
```

## 热点候选

搜回来的热点必须先进入候选层，不要直接变成正式选题。

每个候选必须包含：

```text
hotspot
pool
source
source_time
hotspot_time_window
hotspot_freshness_status
content_position
one_sentence_fact
heat_signal
fact_level
lifecycle
possible_mother_topic
routing_chain
weakest_jump
risk
```

事实核验等级：

```text
A：官方 / 权威来源确认
B：多来源交叉确认
C：单来源，需谨慎
D：传闻或不可核验，不建议做
```

热点生命周期：

```text
正在上升
高位扩散
开始衰退
已过时
适合复盘
```

热点时效窗口：

```text
breaking_0_24h：0-24 小时，适合即时评论。
live_hot_1_3d：1-3 天，最适合短视频热点切口。
current_hot_3_7d：3-7 天，适合观点、解释和垂类转译。
warm_trend_7_30d：7-30 天，适合行业趋势和教育信任。
background_trend_30_90d：30-90 天，只能当背景趋势或复盘。
evergreen_90d_plus：90 天以上，只能当常青问题、案例或方法论素材。
```

时效状态：

```text
fresh_enough
aging_but_usable
too_old_for_hotspot
evergreen_only
unknown_time_blocked
```

内容定位：

```text
breaking_hotspot
current_hotspot
industry_trend
evergreen_problem
case_review
methodology_content
```

如果 `hotspot_freshness_status = too_old_for_hotspot / evergreen_only`，不能继续使用“大热点破圈型”；必须改成教育信任、复盘共创或方法论内容。

D 级事实默认不进入正式选题。

## 研究资产分层

热点研究产物分五层，不能混写：

```text
来源池 = 方法论资产，记录去哪搜、适合什么账号和热点池。
调研运行记录 = 本轮过程资产，记录搜了哪里、用了什么查询、来源质量、核验情况和风险。
热点候选池 = 本轮搜索缓存，记录原始热点、来源、时间、热度、事实等级和初判。
自媒体选题库 = 长期内容资产，只收录通过桥接链和策略判断的选题。
dbskill质检记录 = 文案产物把关记录，只在进入文案阶段后使用。
```

默认落盘规则：

```text
1. 本轮来源计划和实际搜索，写入 docs/reference/调研运行记录.md。
2. 本轮搜回来的热点，写入 docs/reference/热点候选池.md。
3. 完成评分后，评分摘要写入 docs/reference/热点评分表.md。
4. 只有通过桥接链、评分和策略判断的选题，才写入 docs/reference/自媒体选题库.md。
5. 未经涛哥确认的选题，状态必须是“待涛哥确认”。
6. 淘汰、低分、事实等级 D、硬蹭或风险不可控的热点，只能停留在候选池或评分表，不进选题库。
```

根目录四张表是跨账号汇总和索引，不是后台正文唯一存放地。进入真实 session 后，本轮完整调研记录和选题卡副本还必须写入：

```text
accounts/{账号名}/runs/{session_id}/intermediate/01-research-run.md
accounts/{账号名}/runs/{session_id}/intermediate/02-topic-card.md
```

`workflow_session_record.current_artifact` 必须指向 `accounts/{账号名}/runs/{session_id}/` 下的具体文件。

写入边界：

```text
允许改传播研究工作表。
禁止改客户端、服务器、数据库、模型链路、发布链路、真实数据和产品开发验收包。
涉及客户聊天、申请表、测试机反馈等真实材料时必须脱敏。
```

## Topic Gate 选题前质检

Topic Gate 位于 `热点评分表 -> 自媒体选题库` 之间，作用是决定哪些内容值得给涛哥主决策区选择。

默认展示规则：

```text
通过，待选择：进入主推荐区，给涛哥选。
降级轻观点：不进主推荐区，可折叠展示或留在评分表。
待补桥：不进主推荐区，记录最虚一跳和补桥方向。
淘汰：不展示给涛哥选择，只留原因。
归档复盘：不展示给涛哥选择，保留未来复盘价值。
```

不要纯静默过滤。被质检掉的热点必须留在候选池或评分表，并写明原因；但默认不要进入主推荐区，避免增加涛哥决策负担。

Topic Gate 对用户展示时，不得只列 3 个 topic_card。必须先输出 `topic_selection_panel`，让用户知道本轮探索范围、候选漏斗、筛掉原因和三个候选的角色。

Topic Gate 维度：

```text
事实可靠：来源、时间、链接、核验等级是否清楚。
热点价值：是否及时、影响大、有人讨论、有情绪；必须结合 `hotspot_time_window` 判断。
账号匹配：是否符合当前账号定位、目标人群和禁区。
桥接质量：桥接状态是否达到可桥接或强桥接，是否有硬蹭嫌疑。
受众情绪：是否打中真实焦虑、好奇、共鸣、争议或身份认同。
产品 / 业务承接：是否能自然落到产品、服务或观点，不强插。
风险可控：是否存在合规、隐私、灰产、争议或品牌误解风险。
内容可执行：是否能形成明确切口、形式、开头方向和内容 brief。
去重价值：是否和已有选题重复，是否有新角度。
```

入选条件：

```text
事实等级不是 D。
桥接状态是可桥接或强桥接。
Topic Gate 结论是“通过，待选择”。
文案策略明确。
当前产品能力能支撑表达。
```

推荐选题卡进入“通过，待选择”前，必须具备完整交接字段：

```text
topic_id
source_research_run_id
product_profile_id
campaign_profile_id
账号
选题名称 / 标题
热点
热点池
hotspot_time_window
hotspot_freshness_status
content_position
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

Topic Gate 展示面板必须具备完整交接字段：

```text
topic_selection_panel_id
source_research_run_id
account
product_profile_id
campaign_profile_id
panel_status
exploration_scope_summary
source_scope_summary
time_window_summary
raw_candidate_count
scored_candidate_count
main_recommendation_count
degraded_candidate_count
rejected_candidate_count
filtered_reason_summary
recommended_topic_id
topic_option_ids
topic_role_map
selection_tradeoff_map
recommendation_reason
human_prompt
human_reply_examples
decision_type
next_skill
artifact_path
```

`topic_selection_panel` 不替代 `topic_card`，只负责把“为什么是这几个候选”讲给人。`topic_option_ids` 只引用可选择的 `topic_id`，不复制完整选题卡正文。

内容形式必须从 `docs/reference/内容形式类型与载体字典.md` 的内容形式允许值中选择。不要把案例拆解、产品演示、短视频画中画、直播切片当成一级内容形式。

缺任一关键字段时，不允许进入“通过，待选择”；必须标记“待补字段”或“待补桥”，先补齐再给涛哥选择。

## 评分

每个热点按 6 项评分，每项 0-2，总分 12：

```text
人群相关
母题相关
产品相关
情绪强度
风险可控
可落地性
```

结论：

```text
0-4：淘汰
5-7：轻观点
8-10：正式选题
11-12：重点热点
```

## 推导链

根据内容层级选择：

```text
普通：A 目标人群现场 -> C 账号母题 -> D 产品能力
热点：B 大圈热点 -> A -> C -> D
大传播：S 大公共热点 -> B -> A -> C -> D
```

每一跳必须写依据、虚感风险和补桥方式。关键跳转没有依据时，标记“不建议进入文案”。

## 文案策略

每个正式选题必须选择一种：

```text
大热点破圈型
垂类获客型
教育信任型
产品演示型
复盘共创型
```

## 输出格式

```markdown
# 热点选题研究

## 账号档案检查
- 账号：
- 档案位置：
- 结论：可进入热点 / 需补齐后再进入热点

### P0 检查
| 字段 | 状态 | 备注 |
|---|---|---|

## 输入卡
- 账号：
- 账号定位：
- 业务目标：
- 目标人群：
- 核心业务 / 产品 / 服务：
- product_profile_id：
- campaign_profile_id：
- 本轮产品 / 活动对象：
- 允许表达：
- 禁止表达：
- 账号母题：
- 内容目标：
- 热点范围：

## 本轮来源计划
| 池 | 本轮来源 | 为什么选 | 预计找什么 | 风险 |
|---|---|---|---|---|

## 调研运行记录
- research_run_id：
- research_goal：
- time_range：
- hotspot_time_window：
- hotspot_freshness_status：
- content_position：
- sources_used：
- search_queries：
- source_quality_notes：
- fact_check_notes：
- candidate_count：
- selected_candidate_count：
- discarded_candidate_count：
- risk_notes：
- research_status：
- next_skill：

## 热点候选池
| ID | 池 | 热点 | 来源 / 时间 | hotspot_time_window | hotspot_freshness_status | content_position | 一句话事实 | 热度信号 | 核验 | 生命周期 | 可能母题 | 初筛 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

## 桥接链检查
| ID | 桥接链 | 桥接状态 | 每一跳依据 | 哪一跳最虚 | 是否硬蹭嫌疑 | 补桥方式 | 结论 |
|---|---|---|---|---|---|---|---|

## 热点评分表
| ID | 人群 | 母题 | 产品 | 情绪 | 风险 | 落地 | 总分 | 结论 |
|---|---:|---:|---:|---:|---:|---:|---:|---|

## Topic Gate 选题前质检
| ID | 事实 | 热点价值 | 账号匹配 | 桥接质量 | 受众情绪 | 业务承接 | 风险 | 可执行 | 去重 | Gate 结论 | 展示策略 |
|---|---|---|---|---|---|---|---|---|---|---|---|
|  |  |  |  | 未桥接 / 弱桥接 / 可桥接 / 强桥接 / 硬蹭嫌疑 |  |  |  |  |  | 通过，待选择 / 降级轻观点 / 待补桥 / 淘汰 / 归档复盘 | 主推荐 / 折叠 / 不展示 |

## 选题决策面板
- topic_selection_panel_id：
- source_research_run_id：
- account：
- product_profile_id：
- campaign_profile_id：
- panel_status：panel_ready_waiting_human
  - allowed_values：panel_draft / panel_ready_waiting_human / panel_selected / panel_needs_rerun / panel_archived
- exploration_scope_summary：
- source_scope_summary：
- time_window_summary：
- raw_candidate_count：
- scored_candidate_count：
- main_recommendation_count：
- degraded_candidate_count：
- rejected_candidate_count：
- filtered_reason_summary：
- recommended_topic_id：
- topic_option_ids：
- topic_role_map：
  - {topic_id}: main_recommendation / discussion_candidate / experimental_candidate / low_risk_candidate / backup_candidate
- selection_tradeoff_map：
  - {topic_id}: {选择收益} / {主要代价}
- recommendation_reason：

### 为什么只给这几个候选
| topic_id | 角色 | 适合目标 | 为什么入选 | 主要代价 |
|---|---|---|---|---|
|  | main_recommendation / discussion_candidate / experimental_candidate / low_risk_candidate / backup_candidate |  |  |  |

### 我的推荐
- 默认推荐：
- 推荐原因：
- 如果想更稳：
- 如果想更有讨论：
- 如果想更追热点：
- 如果都不满意：
- 如果只要低风险行业趋势：

- human_prompt：我本轮不是直接拍 3 个题，而是从 {raw_candidate_count} 个候选里筛到 {scored_candidate_count} 个评分项，再给你 {main_recommendation_count} 个主推荐。默认建议选 {recommended_topic_id}，因为 {recommendation_reason}。你可以直接回复“选 {recommended_topic_id}”；如果想换方向，可以回复“选 {backup_topic_id} / 重找一轮 / 只要行业趋势”。
- human_reply_examples：选 {recommended_topic_id} / 选 {backup_topic_id} / 重找一轮 / 只要行业趋势 / 三篇都做
- decision_type：select / branch_request
- next_skill：human_confirm
- artifact_path：

## 推荐选题卡
### topic_id: T001
- 标题：
- 账号：
- 热点：
- hotspot_time_window：
- hotspot_freshness_status：
- content_position：
- 事实来源 / 来源时间：
- 目标人群：
- 文案策略：
- 核心指标：
- 产品占比：
- 热点层级：
- 热点池：
- 账号母题：
- 对应产品能力：
- 推导链：
- 哪一跳最虚：
- 如何补桥：
- 核心观点：
- 不能怎么讲：
- 风险：
- 内容形式：
- 内容类型建议：
- 外挂项建议：
- topic_status：topic_pending_human_choice
- next_skill：human_confirm
- human_prompt：我建议优先选 {topic_id}，因为它和账号母题、产品承接、时效窗口最稳。你可以直接回复“选 {topic_id}”，我会自动生成 Brief、写口播、做画中画和质检；如果想换方向，可以回复“选 {backup_topic_id} / 重找一轮 / 只要行业趋势，不要产品露出”。
- human_reply_examples：选 T001 / 选 T002 / 选 T003 / 重找一轮 / 只要行业趋势，不要产品露出
- recommended_action：推荐进入 Brief 的 topic_id，以及推荐原因。
- auto_next_action：用户选定 topic_id 后，自动把 topic_status 改为 topic_selected_for_brief，并进入 `content-brief-compiler`；Brief 通过后继续自动写口播，不要求用户说“继续”。
- task_after_navigation：选主推荐 / 选备选 / 重找一轮，每项说明为什么。

## 被 Topic Gate 过滤的候选
| ID | 热点 | 过滤状态 | 原因 | 是否可补救 |
|---|---|---|---|---|

## 不建议蹭的热点
- {热点}：{原因}

## 本轮落盘动作
- 已写入调研运行记录：
- 已写入热点候选池：
- 已写入热点评分表：
- 已写入自媒体选题库：
- 未落盘项及原因：

## 任务后导航
1. 选主推荐 topic_id 进入内容 Brief：如果它的账号母题、产品承接、时效窗口最稳，必须说明为什么推荐它。
2. 选备选 topic_id：如果用户更想要低产品露出、更强观点或更强热点感，说明取舍。
3. 重找一轮或换切口：如果主推荐不贴当天策略，说明要补什么来源或换什么内容位置。

## 等待涛哥选择
不要只写“等待涛哥选择”。必须给主推荐和可直接回复的话：

```text
我建议优先选 T001，因为它和账号母题、产品承接、时效窗口最稳。你可以直接回复“选 T001”，我会自动生成 Brief、写口播、做画中画和质检；如果想更稳一点，可以选 T002；如果都不满意，回复“重找一轮”或“只要行业趋势，不要产品露出”。
```

用户回复“选 T001 / 选 T002 / T003 就做这个”即视为人工选题结束。此时将该 topic_card 状态流转为：

```text
topic_status = topic_selected_for_brief
next_skill = content-brief-compiler
```

随后把完整 topic_card 交给 `content-brief-compiler`。如果 topic_card 缺关键字段，必须先补字段，不能直接进入 Brief。

## 结束边界

输出选题卡并完成本轮落盘动作后必须停下。没有涛哥确认，不进入内容 Brief 或完整文案创作。

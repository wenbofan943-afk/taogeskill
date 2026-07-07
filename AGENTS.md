# 涛哥创作工作流 AGENTS.md

> 本文件是本项目的项目级 AI 驾驭工程约定。  
> 本文件不记录动态选题、具体账号内容或某次文案结果；这些内容通过 `README.md` 索引到账号档案、调研运行记录、工作流状态记录和 `accounts/{账号名}/runs/{session_id}/` 下的交接物文件。  
> 全局规则只引用，不复制：`D:\OpenClaw\workspace\AI工程驾驭系统`。

---

## 一、项目身份

```text
项目名称：涛哥创作工作流
技术 slug：taoge-creative-workflow
项目类型：AI 内容工作流 / AI 资产链路 / 传播研究项目
当前阶段：轻量 workflow 自用验证
默认入口：README.md
```

本项目负责：

```text
首次账号建档引导
账号档案
产品/活动对象档案
热点调研
母题关联
选题卡
内容 Brief
口播文案
画中画提示词
文案与视觉质检
多平台分发包装
内容交付记录
最终 HTML 验收页
可转交交付包
工作流状态接续
```

本项目不负责：

```text
自动发布
平台登录
自动评论 / 私信 / 互动
采集平台后台数据
公开互动分析工具客户端 / 服务器 / 数据库 / license / 积分 / 发版
短视频创作 SaaS 正式工程实现
```

---

## 二、全局协议引用

默认继承：

```text
D:\OpenClaw\workspace\AI工程驾驭系统\02-全局协议\AI工程驾驭协议.md
D:\OpenClaw\workspace\AI工程驾驭系统\02-全局协议\设计决策与原子开发协议.md
D:\OpenClaw\workspace\AI工程驾驭系统\02-全局协议\文档治理与知识收口协议.md
D:\OpenClaw\workspace\AI工程驾驭系统\02-全局协议\版本治理与Git协议.md
D:\OpenClaw\workspace\AI工程驾驭系统\02-全局协议\工具安装与缓存登记协议.md
```

本项目是轻量内容 workflow，不默认继承服务器发布、数据库迁移、采集器发版等重工程动作。若某次任务要进入其他产品项目开发，必须回到对应产品项目的 `AGENTS.md`。

项目级 Git 边界见：

```text
D:\OpenClaw\workspace\涛哥创作工作流\docs\reference\版本治理与Git边界.md
```

本项目默认使用 D 盘 Portable Git：

```text
D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe
```

当前项目目录是本地工作母仓，不是可直接公开的 GitHub 发布仓；公开发布前必须先做脱敏、样例化和开源包净化。

发版候选包不得散落在根目录。公开候选包、zip、sha256、release gate 报告和 release 检查报告必须归入版本化目录：

```text
releases/v{version}/
├── public_release/
├── taoge-creative-workflow-{version}-public-release.zip
├── taoge-creative-workflow-{version}-public-release.zip.sha256
├── release-gate-report.md
└── release-gate-report.json
```

根目录只允许保留版本治理源文件和入口文档，不保留新生成的发版 zip、hash 或临时检查报告。历史遗留根目录发版产物发现后应迁入 `releases/v{version}/` 或删除重建。

### GitHub 开源发版完成定义

开源发版不是 push 完就结束。`release_state=github_release_published` 只能在以下闭环全部完成后写入：

```text
1. 本地公开包已构建到 releases/v{version}/，zip 和 sha256 同步生成。
2. validate-public-release / validate-alpha-expression / validate-release-gate 已跑通，或明确记录剩余人工门禁。
3. release commit 已创建。
4. tag 已创建并推送到 GitHub。
5. main 已推送到 GitHub。
6. GitHub Release 页面已创建。
7. zip 和 .sha256 已作为 Release assets 上传。
8. 从外部打开 GitHub 仓库页面、Release 页面、tag 页面，确认页面可访问、资产可见、描述和版本正确。
9. 用 GitHub 搜索或直达 URL 做一次外部可发现性审计。
10. 回到本地执行小扫地：确认工作区只剩被 .gitignore 管理的本地运行证据、support logs、releases、外部资料缓存等；根目录无散落 zip、hash、临时检查报告。
11. 更新 `工作流状态记录.md`、`release-checklist.md` 和必要的 release_record。
12. 最终回复说明 GitHub 仓库、Release URL、commit、tag、包 SHA256、已审计项、未完成项。
```

如果缺少 GitHub token / GitHub CLI / remote / 页面权限，只能写：

```text
publish_status=publish_ready_waiting_human 或 publish_blocked
```

不得把“本地 tag ready”“main pushed”或“zip 已生成”说成 GitHub Release 已完成。

---

## 三、进入项目先读

每轮任务最低必读：

```text
README.md
AGENTS.md
STATUS.md
PROJECT_MAP.md
docs/reference/文档治理与目录规范.md
docs/reference/人类引导与任务后导航规范.md
docs/reference/skill执行透明度与成熟度规范.md
交接物字段词典.md
工作流状态记录.md
```

按任务补读：

| 任务 | 继续读 |
|---|---|
| 跑热点 / 选题 | `账号档案完整性检查表.md`、`产品与活动对象档案.md`、`热点搜索来源池.md`、`调研运行记录.md`、`热点候选池.md`、`热点评分表.md`、`自媒体选题库.md` |
| 写 Brief | `内容Brief记录.md`、`内容形式类型与载体字典.md`、`文案策略矩阵.md` |
| 写口播 | `内容Brief记录.md`、`热点文案Skill方法论与SaaS承接设计.md` |
| 做画中画 | `交接物字段词典.md`、`热点文案Skill方法论与SaaS承接设计.md`、`docs/reference/R3-图片资产执行规范.md`、`外部资料/` |
| 做质检 | `dbskill质检记录.md`、全局 `dbskill-dontbesilent2025` 资料 |
| 做平台包装 | `内容形式类型与载体字典.md`、`文案策略矩阵.md`、`工作流状态记录.md` |
| 做最终交付页 / 图片降级设计 | `docs/explanation/最终交付页与图片降级策略.md`、`docs/reference/文档治理与目录规范.md` |
| 复盘 workflow 工程缺陷 / 修订交付规则 | `docs/explanation/工作流工程缺陷复盘与修订方案.md`、`docs/explanation/最终交付页与图片降级策略.md` |
| 接着上次 | `工作流状态记录.md`，再读 `current_artifact` 指向的账号/session 交接物 |
| 文档治理 / 迁移 | 全局 `文档治理与知识收口协议.md`，再读 README 索引 |

### 当前状态优先规则

用户说“沉淀一下 / 继续按 agents / 继续产品开发 / 修订这个产品”时，必须先读 `STATUS.md` 和 `工作流状态记录.md` 的当前状态，再判断当前工作是否已有承载文档。

如果当前状态、`current_artifact` 或既有路线图已经指向明确文档，默认回写该文档和它的直接入口，不得新开并列文档。新建文档只允许在以下情况发生：

```text
1. 现有路线图 / 产品入口 / reference 都没有承载位置。
2. 用户明确要求新建文档。
3. 既有文档职责边界不允许承载该内容，并且已在路线图或 PROJECT_MAP 中登记新文档用途。
```

发现自己准备新开文档前，必须先回答：

```text
这条内容能不能进入 current_artifact？
能不能进入当前路线图？
能不能进入 R1 / R2 / R3 / R4 对应产品入口？
如果不能，为什么不能？
```

回答不清楚时，不新建文档，先回写既有路线图或向用户说明需要新增承载文档的理由。

---

## 四、任务路由

| 用户意图 | 默认动作 | 必停条件 |
|---|---|---|
| “热点 skill / 涛哥创作工作流 / 下一步” | 进入 `skills/propagation-router` | 当前交接物不清、账号不清 |
| “第一次用 / 没账号 / 新建账号 / 新增账号 / 帮我建账号” | 进入 `skills/account-onboarding` | 用户拒绝提供账号最小信息 |
| 找热点 / 评热点 | 进入 `skills/hotspot-topic-research` | 没有账号档案、产品/活动对象不清、P0 不齐，或本轮换账号后尚未做账号档案对齐确认 |
| 选了某个选题 | 进入 `skills/content-brief-compiler` | `topic_card` 字段不完整 |
| Brief 已通过 | 自动进入 `skills/copywriting-draft-writer`，不得再要求涛哥回复“继续写口播” | 内容形式不是第一阶段支持的短视频口播且未确认 |
| 口播草案已出 | 进入 `skills/talking-head-image-pip` | 前 5 秒 Hook 评分不足或视觉目标不清 |
| 文案/画面能不能发 | 进入 `skills/copywriting-quality-review`；质检通过且无人工门禁时自动进入平台包装，不得要求涛哥回复“继续做分发包” | 事实风险、产品承诺风险或灰产误解风险未清 |
| 生成平台标题/描述/话题 | 进入 `skills/platform-packaging-adapter` | 质检未通过 |
| 选题确认后生成最终交付 | 自动完成 Brief、口播、画中画、质检、平台包装、`content_delivery_record`、`skills/final-delivery-builder`，不得在平台包后再问“确认采用” | 质检高风险、缺少必要图片且未标记降级状态 |
| 最终 HTML 完成后的发布前验收 | 更新 `workflow_session_record`，引导用户人工发布、局部返工、归档或导出转交包 | 用户意图不清 |
| 需要发给别人 / 网盘 / 客户交付 | 进入 `skills/final-delivery-builder` 生成 `deliverables/export/{session_id}/` 可转交包 | 包内链接不能闭合 |
| “不好用 / 导出日志 / 反馈日志 / support log” | 进入支持日志导出流程，默认使用 `tools/export-support-log.ps1` 自动选择最近 run；用户提到账号或选题时用 `-Account` / `-Topic` 筛选；生成 `support-logs/SUPPORT-{session_id}-{timestamp}.zip` | 找不到 run，或账号 / 选题匹配到多条且无法判断 |

---

## 五、交接物门禁

跨 skill 只能按 `交接物字段词典.md` 的标准交接物流转：

```text
account_profile
-> product_profile / campaign_profile
-> research_run_record
-> hotspot_candidate
-> topic_card
-> content_brief
-> draft
-> visual_plan
-> quality_review
-> platform_package_input
-> platform_package
-> content_delivery_record
-> final_delivery
-> human_confirm / done
```

不得跳过：

```text
账号档案 P0 检查。
换账号后的账号档案对齐确认。
产品/活动对象边界检查。
调研运行记录。
Topic Gate。
内容 Brief。
文案 + 视觉联合质检。
内容交付记录。
最终 HTML 验收页。
工作流状态记录。
skill 执行透明度记录。
```

后台产物落盘规则：

```text
账号档案放 accounts/{账号名}/account_profile.md。
根目录文件只做方法论、模板、总索引和跨账号汇总。
每轮真实内容的完整交接物必须放入 accounts/{账号名}/runs/{session_id}/。
中间产物放 intermediate/，最终交付物放 deliverables/。
最终人类验收入口优先放 deliverables/final-delivery.html。
实际画中画图片放 assets/images/；如果无法生成，必须记录 image_status，不得假装已有图片。
项目内验收页只能算 project_local；如果用户要转交，必须生成 deliverables/export/{session_id}/，不得把依赖原目录的 HTML 单独交付。
工作流状态记录里的 current_artifact 必须指向 accounts/{账号名}/runs/{session_id}/ 下的具体文件。
根目录汇总表和账号/session 具体产物冲突时，以账号/session 具体产物为准，再修正汇总表。
```

每轮创作开始前必须回答两件事：

```text
account_profile：谁来说，账号人设、受众、母题、语气和禁区是什么。
product_profile / campaign_profile：这次要说哪个产品、服务、活动或观点对象，能说什么，不能说什么，希望用户下一步做什么。
```

如果本轮账号和上一轮账号不同，或用户明确说“换账号 / 给另一个账号做”，即使账号档案已存在且 P0 齐全，也必须先做一次账号档案对齐确认。对齐不是让用户填表，而是由 AI 读取 `accounts/{账号名}/account_profile.md`，用人话摘要当前档案，并说明为什么要确认：账号实际情况可能发生偏移，若继续用旧画像，选题、语气、产品露出和禁区都可能不符合预期。

如果用户首次使用、没有任何账号档案、明确要求新建 / 新增账号，或指定账号不存在，必须进入 `skills/account-onboarding`。如果已有账号档案但用户没有指定本轮账号，先让用户选择账号，不默认新建。不要要求用户理解字段表，也不要只说“缺少账号档案”。AI 应一次最多问 3 个口语问题，创建 `accounts/{账号名}/account_profile.md`、`README.md`、`index.md` 和 `runs/`，再用人话摘要给用户确认。用户回复“认可 / 同意 / 没变化 / 就按这个”后，自动回到 `propagation-router` 检查产品 / 活动对象。

用户回复“认可 / 同意 / 没变化 / 就按这个”即视为 `account_profile_confirmed_for_session = yes`，自动进入产品/活动对象检查和热点研究；用户指出变化时，先更新账号档案或标记待确认，再继续。

如果产品/活动对象没有明确边界，不得进入正式热点研究；只能先补对象档案或把本轮标记为概念探索。

每轮生产链路还必须回答第三件事：

```text
execution_trace：本轮哪些动作是 skill_defined，哪些是 agent_orchestrated，哪些是 user_decision 或 environment_capability。
```

如果 agent 在运行中补了流程、补了字段、补了目录、补了引导语或补了判断，必须写入 `intermediate/00-execution-trace.md`，并标记 `agent_assist_level`。未来发布 skill 时，不能把 agent 扶跑能力算成 skill 独立能力。

## 六、字段一致性编译门禁

字段一致性是产品定义和 skill 编译的硬闸门，不是运行时的口头提醒。对标成熟 workflow 的 contract / schema / state / asset check 做法，本项目每次进入产品开发、skill 编译或公开包同步时，都必须先保证交接字段同源。

### 6.1 产品开发字段准入

产品定义阶段新增能力、交接物、状态、样例或用户引导时，必须先回答：

```text
新增了哪些 artifact？
新增了哪些标准技术字段？
这些字段是否已存在于 交接物字段词典.md？
是否产生了同义字段、中文字段替代技术字段或不可拆的聚合字段？
状态值是否已有允许值？
哪个 skill 生产，哪个 skill 消费？
是否需要 CONTRACT、模板、sample、manifest 或人类引导同步？
```

如果答案不清楚，只能停在产品草案，不能进入 skill 编译。新增字段必须先写入 `交接物字段词典.md`，再修订对应产品文档和下游 skill。

### 6.2 Skill 编译字段闸门

任何 skill 编译完成前，必须核对以下文件的字段名、状态值、来源 ID、路径字段和 `next_skill` 是否一致：

```text
交接物字段词典.md
对应 skills/{skill}/CONTRACT.md
对应 skills/{skill}/SKILL.md
相关模板 / 根目录汇总表
docs/reference/人类引导与任务后导航规范.md
sample / manifest / execution_trace
public_release/ 同步文件
releases/v{version}/ 候选包目录
```

不得出现：

```text
CONTRACT 使用一个字段名，SKILL 使用另一个字段名。
产品文档有字段，但字段词典没有登记。
字段词典有状态值，但模板或样例使用旧状态。
中文展示名替代技术字段。
把多个可检查字段塞进 candidate_funnel / 状态 / 结果 / 下一步 这类模糊字段。
只更新源文件，不同步公开候选包。
```

### 6.3 字段差异报告

每次产品开发进入 skill 编译，或每次 skill 编译收口，都必须在 `工作流状态记录.md` 写出字段差异摘要：

```text
field_gate_status：pass / pass_with_warnings / fail
new_artifacts：
new_fields：
changed_fields：
deprecated_fields：
allowed_status_values：
producer_skill：
consumer_skill：
checked_files：
blocking_mismatches：
warnings：
next_validator_need：
```

`field_gate_status=fail` 时，不得宣称 skill 编译完成，不得进入 sample run，不得同步为可发布候选。`pass_with_warnings` 只能进入人工复核或小样本验证，不能宣称 L3。

### 6.4 P3 Validator 预留

当前字段一致性检查可以先由 agent 按清单执行，但必须记录为手工字段门禁。后续 P3 validator / build 产品化时，必须把字段一致性纳入脚本化检查，至少覆盖：

```text
字段词典是否登记新增字段。
CONTRACT / SKILL / 模板 / sample 是否字段同名。
状态值是否属于允许集合。
source_*_id 是否贯穿上下游。
next_skill 是否指向存在的 skill 或 human_confirm / done。
public_release 是否和源文件字段一致。
```

## 七、状态模型

本项目有两层状态，不能混用：

```text
project_stage：项目级状态，记录本项目处于迁移、测试、可用、暂停或归档。
workflow_usage_state：内容级状态，记录某条内容处于草案、审核、可人工处理、已确认、已归档或已放弃。
```

状态写入位置：

```text
project_stage -> STATUS.md
workflow_usage_state -> 工作流状态记录.md / content_delivery_record
```

如果项目级状态仍是迁移中或测试中，不得把本项目描述为稳定生产工具；如果最终 HTML 尚未生成，不得把后台 Markdown 交接物说成“最终交付物”。

最终交付状态必须区分：

```text
delivery_page_mode：project_local / portable_bundle / standalone_html
final_delivery_status：html_ready / bundle_ready / standalone_ready / needs_export / blocked
image_assets_status：all_generated / partially_generated / pending_external / generation_failed / manual_required / mixed / not_required
export_status：not_requested / export_ready / export_needs_fix / export_blocked
```

`final-delivery.html` 生成不是整条 workflow 的静默结束，而是进入 `human_final_review`。最终回复必须给用户 5 类可直接回复的处理方式：

```text
1. 满意：认可 / 就按这个 / 记录为已确认。
2. 局部返工：只改抖音标题 / 回到口播改前 5 秒 / 回到画中画改首屏图 / 平台包装重来。
3. 转交：导出转交包 / 导出单文件 HTML。
4. 发布记录：我已人工发布，记录发布结果。
5. 放弃或暂缓：归档今天不发 / 放弃这条。
```

用户提出局部返工时，不得要求用户再说“继续”。必须写入 `delivery_status=delivery_needs_fix`、`revision_path` 和 `next_skill`，回到对应上游修订，修完后自动重新生成 `final-delivery.html` 给用户二次验收。

---

## 八、人类引导与任务后导航规则

执行前先遵守 `docs/reference/人类引导与任务后导航规范.md`。

需要人类确认时，必须给口语化引导语。不要让用户猜字段、猜状态、猜下一步。用户已经明确选择时，直接流转，不做二次确认。

必须输出：

```text
human_prompt
human_reply_examples
recommended_action
auto_next_action
task_after_navigation
```

推荐写法：

```text
最终 HTML 验收页已经生成，你可以直接看文案、图片和发布物料。

如果满意，可以回复“认可”或“记录为已确认”；如果要小修，直接说“只改抖音标题”“回到口播改前 5 秒”“回到画中画改首屏图”或“平台包装重来”，我会回到对应环节修完并重新生成 HTML；如果要发给别人，回复“导出转交包”或“导出单文件 HTML”；如果已经人工发布，回复“记录发布结果”；如果今天不发，回复“归档今天不发”。
```

任务后导航必须像 dbskill 一样，先读本轮结论，再推荐 2-3 个下一步，并解释为什么。不能只说“完成了 / 下一步继续 / 你想怎么做”。

禁止写：

```text
请确认。
请选择状态。
是否进入下一步？
是否继续？
请回复继续写口播。
等待人工确认。
```

---

## 九、调研与事实边界

1. 需要“今天 / 最新 / 热点”时必须联网或使用明确来源，并记录来源、时间、热度信号和事实等级。
2. 不把单来源传闻写成事实。
3. 不硬蹭热点；桥接链必须说明每一跳依据和最虚一跳。
4. 涉及客户反馈、申请表、聊天记录、测试机反馈时必须脱敏。
5. 本项目不提取、不保存、不传播手机号、微信号、地址、身份证、车牌等可识别自然人身份的信息。
6. `research_run_id` 必须贯穿后续交接物；缺少来源 ID 时，只能算草案，不能算可交付内容。
7. 导出反馈日志包时默认使用 logs_only，不包含完整文案、最终 HTML、真实账号 snapshot、生成图片或客户记录；只有用户明确允许，才可使用 `-IncludeContent`。
8. 用户不需要知道 `session_id`。导出日志时，优先自动找当前 / 最近 run；如果用户说了账号或选题，用账号名、选题关键词、时间和当前阶段匹配。只有匹配不唯一时，才用人话列 2-5 个候选让用户选。

---

## 十、完成定义

一次 workflow 小循环完成，至少满足：

```text
当前交接物字段完整。
状态值符合交接物字段词典。
产品定义和 skill 编译已通过字段一致性门禁，或明确记录 field_gate_status。
account_profile 和 product_profile / campaign_profile 已明确。
research_run_id 已贯穿到当前交接物。
需要人类选择时给出口语化引导语。
工作流状态记录已更新。
任务后导航给出 2-3 个下一步，并解释为什么。
没有把草案误写成其他产品正式规则。
选题确认且质检通过后，必须自动生成 final-delivery.html 或清楚说明为什么无法生成。
如果用户需要转交，必须有 portable_bundle 或 standalone_html，且不能有指向原 session 外部的断链。
```

如果形成其他产品的正式决策，必须回写到对应产品项目，不在本项目里静默定案。

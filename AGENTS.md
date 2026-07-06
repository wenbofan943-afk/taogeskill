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
| 做画中画 | `交接物字段词典.md`、`热点文案Skill方法论与SaaS承接设计.md`、`外部资料/` |
| 做质检 | `dbskill质检记录.md`、全局 `dbskill-dontbesilent2025` 资料 |
| 做平台包装 | `内容形式类型与载体字典.md`、`文案策略矩阵.md`、`工作流状态记录.md` |
| 做最终交付页 / 图片降级设计 | `docs/explanation/最终交付页与图片降级策略.md`、`docs/reference/文档治理与目录规范.md` |
| 复盘 workflow 工程缺陷 / 修订交付规则 | `docs/explanation/工作流工程缺陷复盘与修订方案.md`、`docs/explanation/最终交付页与图片降级策略.md` |
| 接着上次 | `工作流状态记录.md`，再读 `current_artifact` 指向的账号/session 交接物 |
| 文档治理 / 迁移 | 全局 `文档治理与知识收口协议.md`，再读 README 索引 |

---

## 四、任务路由

| 用户意图 | 默认动作 | 必停条件 |
|---|---|---|
| “热点 skill / 涛哥创作工作流 / 下一步” | 进入 `skills/propagation-router` | 当前交接物不清、账号不清 |
| 找热点 / 评热点 | 进入 `skills/hotspot-topic-research` | 没有账号档案、产品/活动对象不清、P0 不齐，或本轮换账号后尚未做账号档案对齐确认 |
| 选了某个选题 | 进入 `skills/content-brief-compiler` | `topic_card` 字段不完整 |
| Brief 已通过 | 自动进入 `skills/copywriting-draft-writer`，不得再要求涛哥回复“继续写口播” | 内容形式不是第一阶段支持的短视频口播且未确认 |
| 口播草案已出 | 进入 `skills/talking-head-image-pip` | 前 5 秒 Hook 评分不足或视觉目标不清 |
| 文案/画面能不能发 | 进入 `skills/copywriting-quality-review`；质检通过且无人工门禁时自动进入平台包装，不得要求涛哥回复“继续做分发包” | 事实风险、产品承诺风险或灰产误解风险未清 |
| 生成平台标题/描述/话题 | 进入 `skills/platform-packaging-adapter` | 质检未通过 |
| 选题确认后生成最终交付 | 自动完成 Brief、口播、画中画、质检、平台包装、`content_delivery_record`、`skills/final-delivery-builder`，不得在平台包后再问“确认采用” | 质检高风险、缺少必要图片且未标记降级状态 |
| 最终 HTML 完成后的发布前验收 | 更新 `workflow_session_record`，引导用户人工发布、局部返工、归档或导出转交包 | 用户意图不清 |
| 需要发给别人 / 网盘 / 客户交付 | 进入 `skills/final-delivery-builder` 生成 `deliverables/export/{session_id}/` 可转交包 | 包内链接不能闭合 |

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

用户回复“认可 / 同意 / 没变化 / 就按这个”即视为 `account_profile_confirmed_for_session = yes`，自动进入产品/活动对象检查和热点研究；用户指出变化时，先更新账号档案或标记待确认，再继续。

如果产品/活动对象没有明确边界，不得进入正式热点研究；只能先补对象档案或把本轮标记为概念探索。

每轮生产链路还必须回答第三件事：

```text
execution_trace：本轮哪些动作是 skill_defined，哪些是 agent_orchestrated，哪些是 user_decision 或 environment_capability。
```

如果 agent 在运行中补了流程、补了字段、补了目录、补了引导语或补了判断，必须写入 `intermediate/00-execution-trace.md`，并标记 `agent_assist_level`。未来发布 skill 时，不能把 agent 扶跑能力算成 skill 独立能力。

## 六、状态模型

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
image_assets_status：generated / pending_external / generation_failed / manual_required
export_status：not_requested / export_ready / export_needs_fix / export_blocked
```

---

## 七、人类引导与任务后导航规则

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
最终 HTML 验收页已经生成，你可以直接看文案、图片和发布物料。满意就人工发布；如果要改，直接说“只改抖音标题”“回到口播改前 5 秒”“回到画中画改首屏图”；如果今天不发，可以说“归档今天不发”。
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

## 八、调研与事实边界

1. 需要“今天 / 最新 / 热点”时必须联网或使用明确来源，并记录来源、时间、热度信号和事实等级。
2. 不把单来源传闻写成事实。
3. 不硬蹭热点；桥接链必须说明每一跳依据和最虚一跳。
4. 涉及客户反馈、申请表、聊天记录、测试机反馈时必须脱敏。
5. 本项目不提取、不保存、不传播手机号、微信号、地址、身份证、车牌等可识别自然人身份的信息。
6. `research_run_id` 必须贯穿后续交接物；缺少来源 ID 时，只能算草案，不能算可交付内容。

---

## 九、完成定义

一次 workflow 小循环完成，至少满足：

```text
当前交接物字段完整。
状态值符合交接物字段词典。
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

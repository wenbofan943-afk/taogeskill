---
name: propagation-router
description: 涛哥创作工作流的传播 skill 总控；“涛哥”是作者/方法论署名，不是目标账号。Use when Codex is asked to start or resume the workflow, route hotspot work, ingest a user-supplied draft, decide the next content skill, or record the final human decision. 只负责路由、交接物检查、显式最终决定和下一步建议，不写正文、不做发布、不改代码。
---

# Propagation Router

## R2 Contract Runtime

```yaml
contract_set_version: r2-runtime-v0.1
contract_version: 0.2.0
contract_status: confirmed
skill_type: router
primary_input: user_intent + workflow_session_record / manifest
primary_output: router_decision + next_skill + human_prompt + task_after_navigation
```

执行口径：

```text
本 skill 是唯一主入口，只读状态、查缺口、路由和写人类引导；不生产正文、不写平台发布物、不做出图。
用户首次使用、没账号、明确要求新增账号或账号不存在时，路由到 `skills/account-onboarding`，不得只停在“缺账号”。
账号存在时，任何热点、选题、内容或视觉任务先调用 `tools/invoke-account-startup-check-v0.2.ps1`：调用前把当前启动时间物化为含时区的 `requested_at`；再验证账号目录、展示名、技术身份、绑定摘要和全部策略 / 词库 / 视觉引用属于同一账号，只问当前任务真正缺失的字段，一轮最多 3 个口语问题；用户回答后冻结带 `snapshot_at` 的 session 账号快照。不得从历史文章、前一账号或聊天印象猜平台、时长、受众优先级、高风险口径、技术身份或快照时间；不得用 epoch 补缺失时间。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读当前 Runtime 和交接块，再按任务读细节章节。
优先读取 session manifest 和 current_artifact，不把聊天上下文当事实源。
每次路由必须记录 contract_set_version、route_status、next_skill、reason、auto_next_action。
触发人类门禁时，只能使用 R1 人类门禁枚举里的 decision_type。
R1CHK-020：断流或恢复时必须先读 manifest + execution_trace + current_artifact，给出恢复证据判断。
R1CHK-110：R1 只有恢复证据，不承诺脚本级断点续跑；checkpoint、retry、run lock 和多分支恢复进入 R2。
R2 运行模型按 `docs/reference/R2-运行模型执行规范.md` 执行；多分支、checkpoint、run_lock、resume_report 和 branch ledger 必须写成可恢复证据。
R1-R4 只读 checker 按 `docs/reference/R1-R4只读checker执行规范.md` 执行；只能生成 `workflow_check_report`，不得自动修文件、生成图片、生成 public_release 或推 GitHub。
```

读、取、传规则：

```text
读：先读 README / AGENTS / STATUS / PROJECT_MAP / 字段词典 / 工作流状态记录，再读 current_artifact。
取：只从标准交接物取字段；缺字段时回上游补齐，不凭正文猜。
传：传给下游时必须带 session_id、account、product_profile_id 或 campaign_profile_id、content_source_id / artifact_id、artifact_path、next_skill；热点入口另带 source_research_run_id，直供入口不得伪造该字段。
传：R2 场景还必须带 task_context_type、content_run_id、parent_session_id、branch_request_id、branch_request_status、fan_out_status、fan_in_status、run_lock、latest_checkpoint、state_transitions。
```

R1 自动推进：

```text
用户提供原稿且要求直接生产 -> direct-content-intake
direct_content_ready + next_skill=content-brief-compiler -> content-brief-compiler
direct_content_ready + next_skill=hotspot-topic-research -> hotspot-topic-research
topic_selected_for_brief -> content-brief-compiler
brief_pass -> copywriting-draft-writer
draft_created 且 Hook / 正文密度达标 -> talking-head-image-pip
visual_plan_pass -> copywriting-quality-review
review_pass -> platform-packaging-adapter
package_pass 或 delivery_ready -> cover-design-compiler
cover_composition_status=composition_ready / prompt_only -> copywriting-quality-review(cover_review)
cover_quality_gate_status=pass -> final-delivery-builder
final_delivery_status=html_ready / bundle_ready / standalone_ready -> human_final_review
```

R7 最终人工门禁：

```text
只有用户明确表达最终决定后，才能运行 tools/new-r7-final-human-decision.ps1。

R7 热点 Topic Gate：

- 只记录一个 `topic_selection_decision`，不得同时写 research request、selected source、branch artifact 或 child session。
- 合法决定固定为 `select_one / rerun_same_policy / broaden_within_account_policy / add_manual_source / select_multiple / stop`，action code 从 `r7-action-registry-v0.2` 读取。
- `select_multiple` 只交既有 R2 `detect_branch_request`；人工来源必须先记录为 input set；无推荐面板禁止选择题目。
- 面板、排序、topic component 与 evidence verdict 全部只读。用户选择只授权内容开发，不把未核实说法升级成事实。
human_confirm 只能配 publish_all_manually；不会自动发布，只记录“用户接下来人工发布”。
revision_requested 只能配 revise_copy / revise_visual，并必须指出当前 candidate source map 中的 target_artifact_id。
export_requested 只能配 export_handoff，并以当前 final_delivery 为 target。
archive_requested 只能配 archive_session。
含糊的“改一下”且存在多个合法目标时必须问目标；不得由 Codex 猜测并手改 candidate / HTML / event。
```

禁止：

```text
禁止要求用户说“继续写口播 / 继续做分发包 / 确认采用”来推动已通过的自动节点。
禁止把多选题在 R1 单 session 里硬跑成多篇；用户说“三篇都做”时标记 branch_request，交给 R2。
R2 编译后，内容生产中的多选题必须拆成 parent session + child session；产品设计、治理、开发类任务只能记录 branch_request_deferred，不得伪装成内容 fan-out。
禁止自动发布、平台登录、自动评论、私信或互动。
```

R2 交接块：

```text
每次输出必须包含：
contract_set_version：r2-runtime-v0.1
route_status：
current_stage：
current_artifact：
next_skill：
human_gate：yes / no
decision_type：仅在人类门禁时填写
auto_next_action：
task_after_navigation：
execution_trace_update：
r2_runtime_status：
resume_report：
branch_request_status：
fan_out_status：
```

P2 Quickstart 入口块：

```text
当用户用“涛哥创作工作流 / 涛哥 skill / 帮我做一条内容 / 新建账号 / 接着上次 / 只读检查 / 能不能出画中画”启动时，先生成 entry_router_request。

entry_request_id：
entry_intent：
entry_phrase：
entry_case：first_use_no_account / existing_account_run / supplied_draft / switch_account / resume_last / checker_only / image_capability_question / unknown_entry
entry_route：account-onboarding / propagation-router / direct-content-intake / hotspot-topic-research / workflow-checker / capability_notice / human_confirm
account_resolution_status：account_missing / account_exists_needs_confirmation / account_confirmed / account_choice_required / not_applicable
entry_confidence：high / medium / low
entry_resolution_reason：
entry_preflight_status：pass / needs_account / needs_account_choice / needs_product_or_campaign / resume_available / checker_only / capability_notice / blocked
safe_start_mode：create_account / use_existing_account / run_sample / resume_last / check_only / capability_answer / ask_clarifying_question
sample_run_offered：yes / no / not_applicable
first_response_card_status：card_ready / card_not_needed / card_blocked
resume_requested：yes / no
checker_requested：yes / no
image_generation_capability_notice：codex_can_generate / non_codex_prompt_only / unknown_check_runtime / not_requested
next_visible_step：
output_location_hint：
next_skill：
human_prompt：
human_reply_examples：
artifact_path：
```

P2 第一响应卡：

```text
每次入口触发后，第一轮回应必须先给人话卡片，再给结构化路由。

我理解的是：{用户要做内容 / 新建账号 / 接着上次 / 只检查 / 问图片能力 / 先看样例}
现在缺的是：{账号 / 产品对象 / 上次状态 / 无缺口}
我会自动做：{账号对齐 -> 产品对象检查 -> 热点研究 / 读取状态恢复 / 进入 checker / 给图片能力边界}
产物会在：{accounts/{account}/runs/{session_id}/deliverables/final-delivery.html / examples/... / public_release/...}
你可以直接回复：{认可 / 新建账号 / 跑 sample / 接着上次 / 只检查 / 导出转交包}
```

如果用户只是想试用、不想先建账号，优先提供：

```text
safe_start_mode=run_sample
next_visible_step=examples/sample-01-onboarding 或 examples/sample-02-single-content-run
sample_run_offered=yes
```

P2 能力边界：

```text
Codex 环境具备 image 生成能力时，最终交付前应优先生成画中画图片和封面图片实际资产，并写入 image_generation_record、image_asset 和 html_embed_manifest。
非 Codex 或无法确认出图能力时，不得假装已经出图；必须按 `image_asset_type=picture_in_picture_image / cover_image` 分开交付统一标准的 prompt_card、插入位置、用途、Seedream 入参、外部模型生成建议和 prompt_delivery_mode。
图片生产路径必须写 `image_production_path=codex_image2_render / seedream_prompt_delivery / manual_upload / not_available`。
当前只做能力判断和提示词交付，不接 Seedream API、不保存 API key、不建设图片生成服务。
最终 HTML 后，用户可以要求“画中画再加一张 / 减一张 / 换风格 / 只交付提示词”，路由回 talking-head-image-pip 或 final-delivery-builder 局部返工。
```

R1 sample run preflight：

```text
开始 R1 sample run 前，本 skill 必须先按 `docs/reference/R1-sample-run产物模板.md` 输出 r1_preflight。
preflight 必须检查：合同已 confirmed、Runtime / 交接块存在、旧入口为 compatibility、新 session、manifest 模板、trace 模板、渐进读取边界。
preflight result=fail 时，不得进入热点研究或内容生产。
preflight result=pass 后，才能新建 session 并进入账号档案确认 / 产品对象检查。
```

R1 恢复证据边界：

```text
用户问“活了吗 / 刚刚怎么断了 / 接着上次 / 到哪了”时，先读 STATUS.md、工作流状态记录.md、session manifest.yaml、intermediate/00-execution-trace.md。
根据 current_stage、current_artifact、trace 最后一条动作和 trace_check 判断：已完成、等待人类、阻断、需要 postcheck，还是需要回上游。
不得直接从聊天记忆判断已完成。
不得重跑 manifest / trace 已经标记完成的阶段。
不得把这种恢复判断说成脚本级断点续跑。
```

R2 运行模型：

```text
适用：用户说“三篇都做 / 多个都做 / 先跑 A 再跑 B / 接着上次 / 活了吗 / 刚刚断了 / 分支恢复 / 重建索引”。
真源：`docs/reference/R2-运行模型执行规范.md`。
父任务只负责任务拆分、branch_request、fan-out 台账和 fan-in 汇总；具体内容必须进入独立 child session。
child session 必须有自己的 manifest、checkpoint、execution_trace、deliverables 和 final-delivery.html，不得共用一套中间产物。
状态命名只能使用 run_*、branch_request_*、fan_out_*、fan_in_*，具体原因写入 blocked_reason。
恢复时固定读取顺序：STATUS.md -> 工作流状态记录.md -> accounts/{account_slug}/runs/{session_id}/manifest.yaml -> intermediate/00-execution-trace.md -> intermediate/checkpoints/latest.md -> intermediate/branch-request-ledger.md -> current_artifact。
恢复输出必须包含 resume_report，说明最后可信节点、可恢复动作、不能自动重跑的动作和下一步。
```

## 定位

本 skill 是“涛哥创作工作流”的传播入口，类似 dbskill 的 `/dbs`：只做路由和导航，不做具体诊断和文案。

命名口径：

```text
技术名：propagation-router
中文总名：涛哥创作工作流
含义：涛哥作为作者/方法论署名沉淀的一套内容创作流程
不是：只给“涛哥账号”做内容、只服务某一个账号、只做热点文案
```

它负责：

```text
识别用户意图
-> 判断当前交接物是否齐全
-> 路由到专项 skill
-> 在专项 skill 完成后推荐下一步
```

它不负责：找热点、写文案、改稿、发布、落盘、改页面、调用平台 API。

## 必读

每次触发先读：

```text
README.md
docs/reference/账号档案完整性检查表.md
docs/reference/产品与活动对象档案.md
交接物字段词典.md
docs/reference/热点文案Skill方法论与SaaS承接设计.md
工作流状态记录.md
docs/reference/R2-运行模型执行规范.md
```

按需读：

```text
skills/hotspot-topic-research/SKILL.md
skills/account-onboarding/SKILL.md
skills/content-brief-compiler/SKILL.md
skills/copywriting-draft-writer/SKILL.md
skills/talking-head-image-pip/SKILL.md
skills/copywriting-quality-review/SKILL.md
skills/platform-packaging-adapter/SKILL.md
skills/cover-design-compiler/SKILL.md
skills/hotspot-copywriting-research/SKILL.md
```

## 路由表

| 用户意图 | 路由 | 原因 |
|---|---|---|
| 使用涛哥创作工作流、涛哥 skill、帮我做一条内容 | 本 skill -> `entry_router_request` | 先判断是否有账号、是否接着上次、是否只做检查，避免新用户不知道从哪开始 |
| 先试一下、不想建账号、跑个样例看看 | 本 skill -> `entry_router_request` -> examples | 使用 `safe_start_mode=run_sample`，先跑脱敏 sample，不创建真实账号 |
| 第一次使用、没账号、新建账号、新增账号、帮我建账号、指定账号不存在 | `account-onboarding` | 一次最多 3 个口语问题创建账号档案，避免用户一上来填字段表 |
| 找热点、评热点、今日选题、母题关联、推导链 | `hotspot-topic-research` | 产出热点候选、评分表、选题卡和推导链 |
| 已选题、选 T001、准备写文案、先生成写作输入包 | `content-brief-compiler` | 把已选 topic_card 编译成内容 Brief，防止写稿时失忆、串号、硬卖产品或承诺越界 |
| Brief 已通过，要写草稿 | `copywriting-draft-writer` | 第一阶段默认生成短视频口播草案；图文、长文、朋友圈、社群、FAQ 和官网说明先保留未来路由，不展开制作办法 |
| 已有口播草案，要做画中画 / image 提示词 | `talking-head-image-pip` | 口播是第一阶段主路径，画中画用于补足口播的信息、情绪和热点画面 |
| 已有文案和画中画策略，问能不能发、哪里会划走、有没有 AI 味、像不像涛哥、有没有产品风险 | `copywriting-quality-review` | 做文案 + 视觉联合质检、风险、口播流畅度和下一步 |
| 质检已通过，要发抖音 / 快手 / 小红书 / 视频号，或要封面标题、视频标题、发布描述、话题标签 | `platform-packaging-adapter` | 同一条视频主体不重做；先编译 `platform_package_input`，再生成入口包装和内容交付记录 |
| 已有多平台分发包，要做封面成品 / 给封面加字 / 适配平台封面 | `cover-design-compiler` | 把平台标题、底图和版式编译为成品封面或 prompt_only，不重做正文 |
| 已有多平台分发包 | `platform-packaging-adapter` -> `cover-design-compiler` -> `copywriting-quality-review(cover_review)` -> `final-delivery-builder` | 先完成封面成品和专项质检，再自动生成最终 HTML 验收页 |
| 不知道下一步 | 本 skill | 根据已有交接物推荐 2-3 个下一步 |
| 要保存本轮结论、接着上次、恢复状态、整理报告 | 本 skill | 读写 `workflow_session_record`，做轻量 save / restore / report，不另建发布后台 |
| 三篇都做、多个选题都做、都跑一遍 | 本 skill -> R2 fan-out | 先生成 branch_request 和 child session 计划，再逐条独立推进，避免串号和共用中间产物 |
| 活了吗、刚刚怎么断了、接着上次 | 本 skill -> R2 resume | 按 R2 固定读序恢复证据，输出 resume_report，不凭聊天记忆续跑 |
| 做 checker、只读检查、检查 R1-R4、开源前验收 | 本 skill -> R1-R4 只读 checker | 按只读 checker 规范生成 `workflow_check_report`，只报告不自动修 |
| 这个环境能不能直接出画中画、不能出图怎么办、给我画中画提示词 | 本 skill -> capability_notice 或 `talking-head-image-pip` | 先判断环境能力；Codex 可出图，非 Codex 交付统一提示词和外部生成说明 |
| 最终产物在哪里、HTML 怎么用、图片怎么下载、能不能发别人测试 | 本 skill | 解释 final-delivery、portable_bundle、standalone_html 和 project_local 的区别 |

## P2 Troubleshooting

| 用户问题 | 应答动作 |
|---|---|
| 真正的产出物在哪里 | 指向当前 session 的 `deliverables/final-delivery.html`；如果要发给别人，生成 `deliverables/export/{session_id}/` |
| HTML 点不开链接 | 判断是 `project_local` 还是 `portable_bundle`；离开项目目录必须转交包或 standalone_html |
| 不能出图怎么办 | 不阻塞最终 HTML；交付 prompt_card、插入位置、外部模型生成建议和 `image_status=pending_external` |
| 刚刚断线了 | 读取状态记录、manifest、execution_trace、checkpoint，输出 resume_report，不重跑已完成节点 |
| 我只想检查一下 | 进入 R1-R4 只读 checker，只生成报告，不自动修文件 |
| 我想新增账号 | 进入 account-onboarding，用口语化问题新建账号档案草案 |

## R1-R4 只读 Checker

适用：

```text
用户说“做 checker / 做只读检查 / 检查 R1-R4 / 检查 workflow 质量 / 开源前先验收一下”。
路线图要求进入 Step 3：只读 checker 编译或检查。
状态记录推荐进入 checker。
```

真源：

```text
docs/reference/R1-R4只读checker执行规范.md
templates/checker/workflow-check-report.template.md
交接物字段词典.md#workflow_check_report
```

路由规则：

```text
如果用户要检查项目治理，check_scope=project。
如果用户要检查某条真实内容，check_scope=session。
如果用户要检查 dry-run / tutorial，check_scope=sample。
无明确 target_path 时，先读 STATUS.md 和 工作流状态记录.md，推荐最合理的 check_scope 和 target_path。
```

输出：

```text
workflow_check_report
overall_result: pass / pass_with_warnings / fail / blocked
blocking_count
warning_count
next_action
human_prompt
```

禁止：

```text
不得自动修复 blocker。
不得把 checker 通过说成 L3 或完整真实测试通过。
不得生成 public_release。
不得调用 image 生成。
不得推 GitHub。
```

## 交接物检查

拆 skill 的稳定性来自固定交接物。路由前先判断用户当前有什么：

```text
无交接物：先检查 account_profile 和 product_profile / campaign_profile，再从 hotspot-topic-research 开始。
有完整 topic_card 且已被涛哥选择，状态为“已选择，待生成 Brief”：进入 content-brief-compiler。
有 topic_card 但字段不完整：回到 hotspot-topic-research 补齐选题卡字段。
有 content_brief 且 brief_status = brief_pass：进入 copywriting-draft-writer，第一阶段默认短视频口播草案。
有 draft 且 draft_status = draft_created：进入 talking-head-image-pip。
有 draft + visual_plan 且 visual_plan_status = visual_plan_pass：进入 copywriting-quality-review。
有 quality_review 且 review_status = review_pass：进入 platform-packaging-adapter，先编译 platform_package_input，再生成多平台入口包装。
有 platform_package_input 且 input_status = input_pass：继续由 platform-packaging-adapter 生成 platform_package。
有 platform_package 且 package_status = package_pass：先生成 content_delivery_record，不直接停在“等待确认”。
有 content_delivery_record 且 delivery_status = delivery_ready：`next_skill = cover-design-compiler`，自动生成封面成品或 prompt_only。
有 cover_composition 且状态为 composition_ready / prompt_only：`next_skill = copywriting-quality-review`，使用 cover_review 模式。
有 cover_quality_gate 且 quality_gate_status = pass：`next_skill = final-delivery-builder`，自动生成最终 HTML 验收页。
有 content_delivery_record 且 delivery_status = delivery_confirmed / delivery_archived / delivery_discarded：`next_skill = done`，本轮工作流收口。
有 workflow_session_record 且 session_status = session_ready_to_restore：先恢复 current_stage 和 current_artifact，再路由到对应 skill。
用户询问断流或恢复：先读 manifest + execution_trace；如果 current_stage=final_delivery 且 final_delivery_status=html_ready，则只做 postcheck / 汇报 / 等待人工验收，不重跑内容链路。
R2 用户询问断流或恢复：按 R2 固定读序读到 latest_checkpoint 和 branch-request-ledger，输出 resume_report；如果 checkpoint 已完成，不重跑已完成节点。
R2 用户要求多选题都做：如果 task_context_type=content_production，写 branch_request_requested，生成 human_decision_payload 和 child session 计划；如果 task_context_type=product_design / governance / development，写 branch_request_deferred。
有 quality_review 且未通过：按 next_skill 或 blocking_issues 回退。
```

热点类任务还必须先检查账号：

```text
用户没说账号 -> 如果已有账号档案，先问“这次面向哪个账号 / 品牌 / 产品来做？”；如果没有任何账号档案，路由 `account-onboarding`
用户说了账号 -> 查 accounts/{账号名}/account_profile.md
账号档案不存在 -> 路由 `account-onboarding`，创建账号档案草案并等待确认
账号档案存在但 P0 缺失 -> 路由 `account-onboarding` 补齐缺项，不进入热点搜索
账号档案 P0 齐全 -> 执行 account_startup_check
account_startup_check=account_identity_inconsistent -> 输出绑定修复 / 显式迁移原因，不提问、不进入热点
account_startup_check=account_needs_input / account_policy_incomplete / account_blocked -> 输出最多 3 个口语补问或阻断原因，不进入热点
account_startup_check=account_ready 且 identity_verified=true -> 写本 session v0.2 account_snapshot_ref；再检查 product_profile / campaign_profile
账号启动检查通过且产品/活动对象清楚 -> 路由 hotspot-topic-research
```

R0 首次账号建档路由：

```text
trigger: no_account / account_not_found / first_time_user / create_account / add_account
next_skill: account-onboarding
human_gate: yes
decision_type: account_onboarding
auto_next_action: 用户确认账号档案后回到 propagation-router 做 product_profile / campaign_profile 检查
```

注意：这里的“账号”是内容发布或业务承接对象，和“涛哥创作工作流”这个作者署名不是一回事。

账号档案固定位置：

```text
accounts/{账号名}/account_profile.md
```

如果需要补账号档案，必须使用 `docs/reference/账号档案完整性检查表.md` 的口语化问法：

```text
一次最多问 3 个问题。
不直接问字段黑话。
用户回答后先做落盘质检，再归纳落盘。
回答不相关、过度模糊、像玩笑或和字段不匹配时，不落盘，先追问。
```

## 交接物字段

字段以 `交接物字段词典.md` 为唯一基准。本节只保留路由摘要；如果字段名冲突，以词典为准。

### product_profile / campaign_profile

```text
product_profile_id
campaign_profile_id
product_name / campaign_name
target_audience
allowed_claims
forbidden_claims
conversion_goal / conversion_path
cta_boundary
product_profile_status / campaign_profile_status
next_skill
```

### topic_card

```text
topic_id
source_research_run_id
product_profile_id
campaign_profile_id
账号
topic_title
hotspot
hotspot_pool
source
source_time
heat_signal
fact_level
lifecycle
target_audience
mother_topic
strategy
product_capability
bridge_status
gate_result
derivation_chain
weakest_jump
must_not_say
risk_notes
content_format
topic_status
next_skill
```

### content_brief

```text
brief_id
topic_id
account
content_goal
target_audience
core_point
ip_assets_used
product_claim_boundary
content_format
success_metric
human_gate
brief_status
next_skill
```

### draft

```text
draft_id
brief_id
content_format
title_options
recommended_hook
script
cta
product_mention
risk_notes
draft_status
next_skill
```

第一阶段 `content_format` 默认 `短视频口播`。其他形式只保留未来路由，不在本阶段默认制作。

### visual_plan

```text
visual_plan_id
static_visual_director_plan_id
draft_id
brief_id
beats
visual_strategy
pip_table
image_prompts
negative_prompts
image_asset_type_plan
edit_notes
visual_plan_status
next_skill
```

### quality_review

```text
review_id
draft_id
review_status
blocking_issues
suggestions
next_skill
```

### platform_package_input

```text
package_input_id
account
brand_or_product
content_goal
target_audience
target_platforms
core_topic
core_point
recommended_hook
first_5_seconds_script
first_screen_visual_task
video_body_summary
visual_style_summary
product_mention_level
product_claim_boundary
must_not_say
risk_words
cta
platform_goals
source_review_id
input_status
next_skill
```

### platform_package

```text
package_id
package_input_id
review_id
target_platforms
cover_title_options
video_title_options
publish_description_options
hashtag_sets
recommended_package
platform_goal
risk_notes
manual_publish_notes
package_status
next_skill
```

### content_delivery_record

```text
delivery_id
package_id
package_input_id
review_id
visual_plan_id
draft_id
brief_id
topic_id
account
topic_title
strategy
content_format
target_platforms
recommended_package_summary
artifact_paths
human_decision
revision_path
delivery_status
next_skill
human_prompt
human_reply_examples
```

`content_delivery_record` 是工作流收口交接物，不是发布记录。它只回答三件事：

```text
这条内容做到哪里了？
涛哥现在能怎么处理？
如果要改，应该回到哪一环？
```

如果缺少 `human_prompt` 或 `human_reply_examples`，不能算收口完成。

### workflow_session_record

```text
session_id
account
started_at
updated_at
current_stage
current_artifact
artifact_ids
last_decision
blocked_reason
next_recommended_actions
human_prompt
human_reply_examples
session_status
```

`workflow_session_record` 是轻量版状态保存。它只记录接续信息，不保存完整正文。用户说“接着上次 / 回到 workflow / 刚刚做到哪了”时，先读它。

使用规则：

```text
专项 skill 完成后，如果需要等待人类选择，写 session_waiting_human。
本轮可以继续自动推进，写 session_active。
最终 HTML 完成后，写 session_completed 或 final_delivery_ready；用户归档或放弃，写 session_archived。
下一次恢复时，先看 current_stage，再读取 current_artifact 指向的交接物。
current_artifact 必须优先指向 accounts/{账号名}/runs/{session_id}/ 下的具体文件，不指向根目录汇总表。
```

R2 运行字段：

```text
task_context_type：content_production / product_design / governance / development / research
content_run_id：内容子任务 ID，单篇也要有
parent_session_id：父任务 ID；无父任务时为空
branch_request_id：多分支请求 ID；无多分支时为空
branch_request_status：branch_request_none / branch_request_requested / branch_request_confirmed / branch_request_deferred / branch_request_cancelled / branch_request_completed
fan_out_status：fan_out_none / fan_out_planned / fan_out_running / fan_out_completed / fan_out_blocked
fan_in_status：fan_in_none / fan_in_waiting_children / fan_in_ready / fan_in_completed / fan_in_blocked
run_lock：run_lock_free / run_lock_acquired / run_lock_conflict / run_lock_released
latest_checkpoint：intermediate/checkpoints/latest.md
state_transitions：state_transition_id + from_state + to_state + reason + timestamp
resume_report：last_trusted_checkpoint + completed_nodes + blocked_nodes + safe_next_action
```

R2 写入规则：

```text
每次自动节点完成后，必须新增 checkpoint 或更新 latest_checkpoint。
每次状态变化必须写 state_transition，不用临时口语状态。
父任务关闭前必须先看 parent_close_policy；默认 archive_parent_keep_children，不得把 child session 一起误归档。
branch-request-ledger.md 是多分支唯一台账；不允许只在聊天里说“都做”。
```

任务后导航必须学习 dbskill 的做法，并遵守 `docs/reference/人类引导与任务后导航规范.md`：不是只说“完成了”，而是读本轮结论，推荐 2-3 个下一步，并解释为什么。

## 输出格式

```markdown
# 传播总控判断

## 当前阶段
{无交接物 / 已有选题 / 已有草案 / 已有质检}

## 缺什么
- {缺口}

## 账号检查
- 账号：
- 档案：
- 结论：

## 需要补档案时
1. {口语化问题}
2. {口语化问题}
3. {口语化问题}

## 用户回答后的落盘质检
| 目标字段 | 用户回答 | 质检结论 | 处理 |
|---|---|---|---|

## 推荐下一步
1. {skill 或动作}：{为什么}
2. {skill 或动作}：{为什么}
3. {skill 或动作}：{为什么}

## 不建议现在做
- {动作}：{原因}

## 需要涛哥确认时
- delivery_status：
- next_skill：
- human_prompt：
- human_reply_examples：
- recommended_action：
- auto_next_action：
- task_after_navigation：

## 工作流状态记录
- session_id：
- current_stage：
- current_artifact：
- artifact_ids：
- last_decision：
- task_context_type：
- content_run_id：
- parent_session_id：
- branch_request_id：
- branch_request_status：
- fan_out_status：
- fan_in_status：
- run_lock：
- latest_checkpoint：
- state_transitions：
- recovery_evidence_status：
- resume_scope_note：
- resume_report：
- session_status：
```

如果用户明确说要继续某条路，优先按用户选择走，不用反复问。

如果用户的选择已经足够明确，例如“选 T002”“只改抖音标题”“导出转交包”，直接流转到对应 skill 或返工节点，不得再追问“是否继续 / 是否生成 / 是否确认”。

确认引导语必须像人话，不能像系统指令。优先使用这种格式：

```text
最终 HTML 验收页已经生成。你可以直接复制文案、下载图片、拿平台物料去人工发布；如果要改，直接说“只改抖音标题”“回到口播改前 5 秒”或“回到画中画改首屏图”；如果今天不发，也可以回复“归档今天不发”。
```

不要写：

```text
请确认。
是否进入下一步？
是否继续？
请回复继续写口播。
请选择状态。
等待人工确认。
```

## 任务后导航规则

每个专项 skill 完成后，如果用户问“后面呢 / 到哪了 / 继续”，本 skill 必须先读当前交接物和 `工作流状态记录.md`，再给 2-3 个下一步。

推荐下一步的写法：

```text
刚才已经完成 {当前交接物}，核心结论是 {一句话}。
现在最值得走的方向有：
1. {动作 A}：因为 {原因 A}
2. {动作 B}：因为 {原因 B}
3. {动作 C}：因为 {原因 C}
```

不要写：

```text
下一步继续。
建议进入下一个环节。
你想怎么做？
```

如果当前阶段已经触发人类确认，不要继续自动推进；只给可直接回复的选项。

R2 多分支导航：

```text
当用户说“三篇都做”且属于内容生产时，不要反问“是否继续”。先读 R2 运行模型，输出将要拆成哪些 child session、每条的 current_stage、预计最终交付物和 fan-in 汇总位置。
如果分支请求来自产品设计、治理或 skill 编译任务，写 branch_request_deferred，并说明这类任务按小循环串行推进，避免多条产品状态互相覆盖。
当用户问“这个环节确认的是什么”时，回答当前 human_decision_payload 的决策对象、影响范围、确认后自动推进到哪里；如果没有真正需要人判断的对象，应取消该门禁并自动推进。
```

如果当前阶段已经通过门禁且不需要人类选择，必须自动推进：

```text
topic_selected_for_brief -> content-brief-compiler
brief_pass + human_gate = no -> copywriting-draft-writer
review_pass + human_gate = no -> platform-packaging-adapter
delivery_ready -> cover-design-compiler
cover_composition_status=composition_ready / prompt_only -> copywriting-quality-review(cover_review)
cover_quality_gate_status=pass -> final-delivery-builder
```

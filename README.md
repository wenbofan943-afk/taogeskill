# 涛哥创作工作流

> 状态：独立项目入口  
> GitHub 搜索关键词：`taogeskill`  
> 主责：沉淀账号档案、热点调研、母题推导、内容 Brief、口播文案、画中画提示词、文案质检、多平台包装和工作流接续。  
> 边界：本项目是 AI 内容工作流 / 传播研究项目，不是客户端产品、SaaS 发布后台、自动发布工具或数据采集工具；不直接改变公开互动分析工具客户端、服务器、数据库、积分、license 或发版链路。
> Alpha 预发行提醒：当前公开包是 `0.1.0-alpha.1` GitHub 预发行版本，不是生产级自动化 runner。它可以用于阅读、样例 dry-run、只读检查和人工验证；不能自动发布内容、登录平台、互动评论 / 私信，也不能证明真实热点质量、真实图片质量或真实账号生产效果。

---

## 联系与反馈

- 使用问题、功能建议、样例跑不通：优先提交 GitHub Issue。
- 小范围试用交流：见 [CONTACT.md](./CONTACT.md)。
- 安全、隐私、密钥、真实账号资料问题：先读 [SECURITY.md](./SECURITY.md)，不要在公开 issue 里贴敏感数据。

---

## 快速开始

如果你把这套 workflow 下载给另一个 AI 或另一个人测试，推荐从这句话开始：

```text
使用涛哥创作工作流，帮我做一条内容。
```

不想先建账号，只想试一下，可以说：

```text
先跑一个 sample，让我看看它怎么工作。
```

总控路由会先判断你属于哪种入口：

| 场景 | 会发生什么 |
|---|---|
| 第一次使用 / 没有账号 | 进入 `account-onboarding`，用 3-5 个口语问题新建账号档案草案 |
| 只想先试用 | 进入 `examples/sample-01-onboarding` 或 `examples/sample-02-single-content-run`，不创建真实账号 |
| 已有账号 | 先摘要账号档案，让你确认“账号情况没偏” |
| 换账号 | 先做账号档案对齐，再进入产品 / 活动对象检查 |
| 接着上次 | 读取状态记录、manifest、execution trace 和 checkpoint，说明能从哪里恢复 |
| 只想检查 | 进入只读 checker，只报告问题，不自动修改 |
| 问能不能出画中画 | 判断当前环境；Codex 可直接生成图，非 Codex 交付统一提示词和插入位置 |

第一轮响应会先给你一张“入口判断卡”，说明：

```text
我理解你要做什么。
现在还缺什么。
我会自动推进哪些步骤。
最终产物会在哪里。
你现在可以直接回复什么。
```

如果没有账号，用户不用先学字段表，可以直接说：

```text
给我新建一个汽车观察账号。
```

如果已经完成最终 HTML，后续修改也不用重跑全链路，可以直接说：

```text
只改抖音标题。
回到口播改前 5 秒。
画中画再加一张“信任对比”的图。
导出转交包。
```

如果试用时觉得哪里不好用，可以直接说：

```text
导出反馈日志包。
```

默认只导出排查日志，不包含完整文案、最终 HTML、图片和账号隐私。然后把 `support-logs/` 里生成的 zip 发给维护者。反馈日志导出说明见 [导出反馈日志包](./docs/how-to/export-support-log.md)。

最终交付默认是 `deliverables/final-delivery.html`，它面向人类验收：文案好复制、图片好下载、每个段落能追溯到后台 Markdown 交接物。

---

## 一、为什么独立成项目

本项目最早从“公开互动分析工具”的传播研究目录中长出来。随着能力扩展，它已经不只服务单一产品宣发，而是面向多个账号、多个产品和未来短视频创作 SaaS 的轻量内容工作流。

本项目承接的轻量 skill 体系正式中文名为：

```text
涛哥创作工作流
```

公开搜索关键词：

```text
taogeskill
```

命名说明：

```text
“涛哥”是作者/方法论署名，表示这套内容创作、热点判断、母题推导、Brief 编译、文案质检和画中画提示词流程由涛哥体系沉淀。
它不是目标账号名，也不表示只能给某个“涛哥账号”做内容。
账号档案是工作流输入对象，可以是涛哥汽车观察、涛哥帮提车、涛哥车商自媒、其他品牌号、产品号或后续新增账号。
```

后续增长主要依赖：

1. GitHub / 官网 / 下载页说明。
2. 抖音、视频号、小红书等自媒体内容。
3. 真实用户试用反馈。
4. 对外产品定位和边界表达。
5. 不断验证哪些用户、场景和说法真正有效。
6. 把当前轻量传播 skill 的方法论沉淀为未来短视频创作 SaaS 可承接的结构化产物。

这些内容既不是公开互动分析工具的正式产品规格，也不是它的工程实现计划；但它们会长期影响账号内容、产品传播、商业化表达和未来 SaaS 迁移，因此独立成项目管理。

---

## 二、当前重点

第一阶段先研究：

1. `dbskill` 自媒体方法论里哪些 skill 适合本项目。
2. 本账号的长期“母题”是什么，也就是能持续产生内容的战术规划单元。
3. 当前绑定产品怎么对外表达，避免被误解为灰产工具、截流工具或批量获客工具。
4. 第一批自媒体栏目和选题。
5. 第一批短视频 / 图文脚本。
6. GitHub、官网、下载页和客户端首屏的一致口径。
7. 免费学习版申请转化路径。
8. 热点文案 skill 如何保持轻量脚本边界，并为未来短视频创作 SaaS 预留可迁移字段。
9. 账号档案和账号母题如何约束热点选取，避免不同账号混用同一套热点逻辑。

外部资料位置：

- [dbskill-dontbesilent2025](../AI工程驾驭系统/01-开源方案调研/dbskill-dontbesilent2025)
- [外部资料说明](./外部资料/README.md)：说明第三方资料来源、用途、完整性和复用边界。
- [外部资料/GPT-Image2-Skill](./外部资料/GPT-Image2-Skill)：只保留 README、`skills/gpt-image/SKILL.md` 和关键 references，用于研究 GPT Image 2 出图提示词框架；不作为本项目运行依赖。
- [外部资料/visual-skills](./外部资料/visual-skills)：研究 GPT Image 2 / 多模型 image prompt 的五槽模板、反废话规则、模型选择和提示词结构。
- [外部资料/ai-video-storyboard-skill](./外部资料/ai-video-storyboard-skill)：研究短视频分镜、统一视觉语言、shot list 和剪辑提示。

项目治理入口：

- [PROJECT_MAP.md](./PROJECT_MAP.md)：项目导航图，说明规则、账号、产物和索引在哪里。
- [AGENTS.md](./AGENTS.md)：本项目接入全局 AI 工程驾驭系统后的项目级约定，规定 AI 如何读入口、判边界、走交接物和收口。
- [STATUS.md](./STATUS.md)：当前阶段、当前能力、边界和待办。
- [INSTALL.md](./INSTALL.md)：公开候选包或线下测试包的安装 / 启动说明。
- [UPDATE.md](./UPDATE.md)：更新旧版本时如何保护本地私有账号和生产 runs。
- [CHANGELOG.md](./CHANGELOG.md)：版本变化记录。
- [RELEASE_NOTES.md](./RELEASE_NOTES.md)：当前 alpha 候选的发布说明。
- [NOTICE.md](./NOTICE.md)：项目边界、dbskill 启发说明和外部资料边界。
- [文档治理与目录规范](./docs/reference/文档治理与目录规范.md)：规定账号目录、session 目录、中间产物、最终交付物和 manifest 规则。
- [人类引导与任务后导航规范](./docs/reference/人类引导与任务后导航规范.md)：规定什么时候必须停、什么时候自动继续，以及如何像 dbskill 一样给有理由的下一步。
- [Skill 执行透明度与成熟度规范](./docs/reference/skill执行透明度与成熟度规范.md)：记录每轮到底是 skill 独立完成、agent 扶跑、用户决策还是环境能力，避免误判可发布程度。
- [Skill Contract 模板](./docs/reference/skill_contract模板.md)：定义每个 skill 进入编译前必须具备的触发条件、输入输出、路径、人类门禁、自动推进、失败处理和验收样例。
- [版本治理与 Git 边界](./docs/reference/版本治理与Git边界.md)：规定本地工作母仓、Portable Git 入口、入库范围、排除范围和公开 GitHub 净化规则。
- [GitHub 开源上线检查清单](./docs/reference/GitHub开源上线检查清单.md)：R4 编译后的发布门禁，检查 public_release 的入口、样例、隐私、安全、链接、成熟度和开源边界。
- [R1-R4 只读 Checker 执行规范](./docs/reference/R1-R4只读checker执行规范.md)：把 checker 产品定义编译成只读执行规范，规定 check_scope、报告路径、检查项、阻断等级和人类引导。
- [R1 Skill 渐进读取与长文边界](./docs/reference/R1-skill渐进读取与长文边界.md)：规定 R1 测试前长 skill 如何按需读取，避免 sample run 靠全文硬撑。
- [R1 Sample Run 产物模板](./docs/reference/R1-sample-run产物模板.md)：规定 R1 单篇样本的 manifest、execution trace、trace check、人工决策恢复和 preflight 输出模板。
- [R2 运行模型执行规范](./docs/reference/R2-运行模型执行规范.md)：规定多分支、parent / child session、checkpoint、run lock、state transition、branch ledger 和断点恢复的执行口径。
- [R3 图片资产执行规范](./docs/reference/R3-图片资产执行规范.md)：规定画中画视觉预算、image_generation_record、image_asset_set、metadata sidecar、html_embed_manifest、样本模式和 R3CHK 检查项。
- [最终交付页与图片降级策略](./docs/explanation/最终交付页与图片降级策略.md)：说明最终 HTML 验收页、实际图片资产和未来外部模型降级旁路。
- [工作流工程缺陷复盘与修订方案](./docs/explanation/工作流工程缺陷复盘与修订方案.md)：记录本轮实战暴露的工程弱点，并规定项目内页、可转交包和单文件 HTML 的边界。
- [工作流问题包与产品设计草案](./docs/explanation/工作流问题包与产品设计草案-20260706.md)：沉淀本轮 17 个 workflow 工程问题，作为后续 skill 编译、多分支、画中画资产和 validator 设计输入。
- [GitHub 开源上线前 Workflow 修复路线图](./docs/product/GitHub开源上线前Workflow修复路线图.md)：按产品开发逻辑拆解 17 个问题、成熟解法、父子依赖和开源上线前修复排序。
- [R0 首次账号建档与入口 Onboarding](./docs/product/R0-首次账号建档与入口Onboarding.md)：首次使用或没有账号时，用 3-5 个口语问题创建账号档案并确认。
- [业务状态流转图](./docs/how-to/workflow-business-state-flow.md)：用 Mermaid 解释账号确认、热点、文案、画中画、质检、平台包、最终 HTML、转交包和开源包边界。
- [业务状态流转交互 HTML](./docs/how-to/workflow-business-state-flow.html)：可离线打开的交互图，适合给测试者快速理解 skill 功能。
- [P01 Skill Contract 可编译验收表](./docs/product/P01-skill-contract可编译验收表.md)：汇总核心链路 8 个 skill 合同，判断 P01 是否达到确认后可编译状态。
- [R1 产品总览](./docs/product/R1-产品总览.md)：R1 的人类阅读入口，说明范围、真源、质量标准、确认方式和确认后动作。
- [内容创作质量方法论编译补充](./docs/product/内容创作质量方法论编译补充-R1.md)：把 Hook 路由、正文信息密度、共鸣与兑现并入 R1 方法论编译，避免只优化前 5 秒。
- [R1-P14 方法论编译规则](./docs/product/R1-P14-方法论编译规则.md)：规定讨论稿、调研、复盘和方法论如何进入产品草案、合同、字段词典、SKILL 和 validator。
- [R1-P15 Skill 粒度与入口治理规则](./docs/product/R1-P15-skill粒度与入口治理规则.md)：规定什么时候新建 skill、什么时候只进合同 / 字段 / validator，以及旧入口如何兼容或降级。
- [R1-P13 Execution Trace 检查清单与 Validator 草案](./docs/product/R1-P13-execution-trace检查清单与validator草案.md)：把 execution trace 从运行记录升级为可检查清单，用来判断断链、agent 扶跑、人类门禁和 R1 可编译程度。
- [R1-P02 Agent 扶跑收敛与可编译判定](./docs/product/R1-P02-agent扶跑收敛与可编译判定.md)：定义 agent 扶跑的风险等级、R1 可编译阈值、不可编译信号和编译后验证目标。
- [R1 Skill 执行合同组可编译总验收](./docs/product/R1-skill执行合同组可编译总验收.md)：汇总 R1 产品定义、核心 skill 合同和可编译门槛，作为是否进入 `SKILL.md` 编译的确认入口。
- [R1 合同版本与变更治理](./docs/product/R1-合同版本与变更治理.md)：定义 `contract_set_version`、合同状态机、旧 session 恢复、旧入口兼容和变更确认规则。
- [R1 字段级输入输出矩阵](./docs/product/R1-字段级输入输出矩阵.md)：定义核心 skill 的必需输入、必产输出、状态接线、贯穿字段和缺字段恢复规则。
- [R1 人类门禁决策枚举与恢复规则](./docs/product/R1-人类门禁决策枚举与恢复规则.md)：定义每个门禁的用户回复类型、状态变化、恢复路径和禁止门禁节点。
- [R1 Trace / Check 注册表](./docs/product/R1-trace-check注册表.md)：把 P13 的 BLOCKER / WARN / INFO 拆成可执行、可定位、可反写的原子检查项。
- [R1 产品确认清单](./docs/product/R1-产品确认清单.md)：把是否进入 R1 skill 编译拆成 R1-C01 到 R1-C13 的逐项确认。
- [R1 Skill 拆合与编译记录](./docs/product/R1-skill拆合与编译记录.md)：记录 R1 确认后，为什么保持 8 个核心 skill、降级旧入口，以及本轮实际编译动作。
- [R1 Skill 编译验收与 Sample Run 清单](./docs/product/R1-skill编译验收与sample-run清单.md)：规定 R1 编译后的静态验收项、sample run 产物要求和 R1CHK 最低检查项。
- [R2 产品总览](./docs/product/R2-产品总览.md)：R2 的人类阅读入口，说明运行模型、fan-out / fan-in、branch_lock、恢复证据和确认边界。
- [R2 运行模型与分支封锁规则](./docs/product/R2-运行模型与分支封锁规则.md)：定义多选题拆分、child session、fan-in 汇总、任务分支锁、状态恢复、checkpoint、分支台账、操作合同、ID 和索引规则。
- [R2 产品确认清单](./docs/product/R2-产品确认清单.md)：把 R2 是否进入运行模型编译拆成 R2-C01 到 R2-C20 的逐项确认。
- [R2 Dry-run Sample](./docs/tutorials/r2-dry-run-sample/README.md)：用脱敏假样本验证 parent / child、branch ledger、checkpoint、state_transition、run_lock 和 resume_report 的最小闭环。
- [R3 产品总览](./docs/product/R3-产品总览.md)：R3 的人类阅读入口，说明画中画、图片提示词、生成记录、图片资产、HTML 嵌入和外部模型降级边界。
- [R3 画中画与图片资产模型](./docs/product/R3-画中画与图片资产模型.md)：R3 细则，定义 visual_plan、image_prompt、image_generation_record、image_asset、metadata sidecar、html_embed_manifest、样本模式和版本规则。
- [R3 产品确认清单](./docs/product/R3-产品确认清单.md)：把 R3 是否进入规则 / skill 编译拆成 R3-C01 到 R3-C25 的逐项确认。
- [R3 Skill 编译记录与审计](./docs/product/R3-skill编译记录与审计.md)：记录 R3 确认后实际编译文件、成熟项目对标、冲突冗余审计和后续 dry-run 建议。
- [R3 Dry-run Sample](./docs/tutorials/r3-dry-run-sample/README.md)：用最小假样本验证 visual_beat、prompt_card、generation_record、image_asset、metadata sidecar 和 html_embed_manifest 能否闭合。
- [R3 Generated Image Sample](./docs/tutorials/r3-generated-image-sample/README.md)：用一张真实生成图验证 R3 generated 路径的图片文件、generation record、metadata sidecar、checksum、HTML 预览和下载链路。
- [R1-R4 Integrated Dry-run Sample](./docs/tutorials/r1-r4-integrated-dry-run-sample/README.md)：用脱敏单题样本验证 R1 内容链路、R2 运行模型、R3 pending_external 图片资产链和 R4 public_release precheck 能否同跑。
- [R4 产品总览](./docs/product/R4-产品总览.md)：R4 的人类阅读入口，定义 GitHub 开源上线前的 public_release、README、AGENTS、PROJECT_MAP、样例和成熟度边界。
- [R4 开源交付与净化规则](./docs/product/R4-开源交付与净化规则.md)：R4 细则，定义工作母仓和公开包的边界、净化动作、public-manifest、敏感内容阻断和发布前检查。
- [R4 产品确认清单](./docs/product/R4-产品确认清单.md)：把 R4 是否进入开源规则 / 包装编译拆成 R4-C01 到 R4-C35 的逐项确认。
- [R1-R4 综合 Dry-run 前置检查](./docs/product/R1-R4综合dry-run前置检查.md)：检查 R1 内容链路、R2 运行模型、R3 图片资产链和 R4 开源包装是否具备综合样本 dry-run 条件。
- [R1-R4 只读 Checker 产品定义](./docs/product/R1-R4只读checker产品定义.md)：定义跨 R1-R4 的只读检查器范围、输入输出、阻断等级、检查项和报告字段，用来把人工扫表推进到可编译检查规格。
- [Checker 报告模板](./templates/checker/workflow-check-report.template.md)：`workflow_check_report` 的 Markdown 模板，用于后续只读检查报告落盘。
- [Sample Check 报告模板](./templates/checker/sample-check-report.template.md)：`sample_check_report` 的 Markdown 模板，用于样例验收。
- [Release Check 报告模板](./templates/checker/release-check-report.template.md)：`release_check_report` 的 Markdown 模板，用于 public_release 候选包验收。
- [Public Release 模板](./templates/public-release/README.md)：R4 编译后的公开候选包模板，包含 public-manifest 和 release-checklist 模板。
- [Examples 模板入口](./examples/README.md)：R4 编译后的脱敏样例入口，承接 sample-account 和 sample-run。
- [Tools 命令合同](./tools/README.md)：P3 validator / build 的命令、模式、exit code 和报告双轨说明；当前不是脚本实现。
- [Sample 01 Onboarding](./examples/sample-01-onboarding/README.md)：无账号首次使用样例。
- [Sample 02 Single Content Run](./examples/sample-02-single-content-run/README.md)：选题确认后自动走到最终 HTML 的单篇样例。
- [Sample 03 Final Review Revision](./examples/sample-03-final-review-revision/README.md)：最终 HTML 后局部返工和追加画中画样例。

项目级执行 skill：

- [propagation-router](./skills/propagation-router/SKILL.md)：涛哥创作工作流总控，只做路由、交接物检查和下一步建议。
- [account-onboarding](./skills/account-onboarding/SKILL.md)：首次使用或账号不存在时，用口语化问题创建账号档案草案，确认后回到总控路由。
- [hotspot-topic-research](./skills/hotspot-topic-research/SKILL.md)：热点发现、评分、母题关联、推导链和选题卡。
- [content-brief-compiler](./skills/content-brief-compiler/SKILL.md)：把已选择的选题卡编译成内容 Brief，作为写文案前的上下文输入包。
- [copywriting-draft-writer](./skills/copywriting-draft-writer/SKILL.md)：第一阶段默认把通过的 Brief 写成短视频口播草案；图文、长文、朋友圈、社群、FAQ 和官网说明先保留未来路由，不展开制作办法。
- [talking-head-image-pip](./skills/talking-head-image-pip/SKILL.md)：热点口播画中画视觉策略、image 提示词和 R3 图片资产链，解决“留存任务、插入位置、生成记录、sidecar、剪辑可用素材”。
- [copywriting-quality-review](./skills/copywriting-quality-review/SKILL.md)：文案与视觉联合质检，检查 AI 味、涛哥味、Hook 路由、正文信息密度、产品风险和图片资产可追溯性。
- [platform-packaging-adapter](./skills/platform-packaging-adapter/SKILL.md)：质检通过后，先编译分发包装输入包，再为同一条口播视频生成抖音、快手、小红书、视频号的封面标题、视频标题、发布描述和话题标签。
- [final-delivery-builder](./skills/final-delivery-builder/SKILL.md)：选题确认并完成内容链路后，把后台交接物和 R3 图片资产链构建成人类验收 HTML、html_embed_manifest，并按需生成可转交包或单文件 HTML。
- [hotspot-copywriting-research](./skills/hotspot-copywriting-research/SKILL.md)：旧唤醒词兼容入口。

关键方法论：

- [账号档案完整性检查表](./账号档案完整性检查表.md)
- [账号母题与传播工作流](./账号母题与传播工作流.md)
- [产品与活动对象档案](./产品与活动对象档案.md)
- [AI热点发现与关联评估方法论](./AI热点发现与关联评估方法论.md)
- [热点搜索来源池](./热点搜索来源池.md)
- [热点候选池](./热点候选池.md)
- [调研运行记录](./调研运行记录.md)
- [热点评分表](./热点评分表.md)
- [自媒体选题库](./自媒体选题库.md)
- [内容Brief记录](./内容Brief记录.md)
- [工作流状态记录](./工作流状态记录.md)
- 全部运行索引：下载后由本地账号运行产生，默认不进入公开包；需要反馈问题时按 [反馈日志导出说明](./docs/how-to/export-support-log.md) 导出。
- [交接物字段词典](./交接物字段词典.md)
- [内容形式类型与载体字典](./内容形式类型与载体字典.md)
- [文案策略矩阵](./文案策略矩阵.md)
- [热点文案 Skill 方法论与 SaaS 承接设计](./热点文案Skill方法论与SaaS承接设计.md)

账号档案：

- [涛哥汽车观察](./accounts/涛哥汽车观察/account_profile.md)
- [涛哥帮提车](./accounts/涛哥帮提车/account_profile.md)
- [涛哥车商自媒](./accounts/涛哥车商自媒/account_profile.md)
- [涛哥说真话](./accounts/涛哥说真话/account_profile.md)
- [汽车评论员](./accounts/汽车评论员/account_profile.md)

---

## 三、建议文件结构

```text

├── README.md
├── 账号档案完整性检查表.md
├── docs/
│   ├── reference/
│   ├── explanation/
│   ├── product/
│   ├── how-to/
│   └── tutorials/
├── accounts/
│   └── {账号名}/
│       ├── README.md
│       ├── account_profile.md
│       ├── mother_topics.md
│       ├── style_guide.md
│       ├── boundaries.md
│       ├── runs/
│       │   └── {session_id}/
│       │       ├── README.md
│       │       ├── manifest.yaml
│       │       ├── inputs/
│       │       ├── intermediate/
│       │       ├── deliverables/
│       │       │   └── export/
│       │       ├── assets/
│       │       └── archive/
│       └── index.md
├── objects/
│   ├── products/
│   └── campaigns/
├── indexes/
├── 账号母题与传播工作流.md
├── 文案策略矩阵.md
├── AI热点发现与关联评估方法论.md
├── 热点搜索来源池.md
├── 热点研究CLI与API工具策略.md
├── 热点文案Skill方法论与SaaS承接设计.md
├── dbskill方法论研究.md
├── 对外传播口径.md
├── 热点候选池.md
├── 调研运行记录.md
├── 热点评分表.md
├── 自媒体选题库.md
├── 内容Brief记录.md
├── 工作流状态记录.md
├── 交接物字段词典.md
├── 内容形式类型与载体字典.md
├── dbskill质检记录.md
├── 人工发布复盘.md
├── 短视频脚本草案/
├── 图文内容草案/
├── 对标案例/
└── 用户反馈与传播复盘.md
```

后续按需要逐步创建，不提前堆空文件。

---

## 四、写入规则

1. 方法论研究写在本项目。
2. 本项目只沉淀内容 workflow、传播方法论、账号档案、产品/活动对象档案和内容交接物；不在本项目内直接落其他产品的正式工程规则。
3. 如果本项目产生了其他产品的正式产品决策，必须回写到对应产品项目的产品规格、ADR、README 或 AGENTS；不能只留在本项目。
4. 工程实现计划、数据库变更、接口变更、前端改版、构建发布和原子代码任务，必须回到对应产品项目执行。
5. 一次性资料可以放本项目子目录，但必须说明来源、用途、是否完整和复用边界。
6. 外部资料必须有说明文件；不能让第三方资料、截断仓库或示例文件变成无来源资产。
7. 账号档案必须统一放入 `accounts/{账号名}/account_profile.md`，每个账号一个独立目录，不得散落在根目录、skill 目录或临时报告里。
8. 新增账号时，必须先按 [账号档案完整性检查表](./账号档案完整性检查表.md) 补齐 P0 字段；P0 不齐不进入热点创作。
9. 补账号档案时必须使用检查表里的口语化问法；一次最多问 3 个问题，由 agent 将回答归纳成结构化字段落盘，禁止把开放回答原样堆进档案。
10. 账号档案落盘前必须做质检；回答不相关、过度模糊、像玩笑、像个人偏好或和字段不匹配时，不写入正式字段，先追问或标记待确认。
11. 热点研究默认按五层资产写入：来源池是方法论资产，调研运行记录是本轮来源与核验记录，热点候选池是短期缓存，热点评分表是筛选记录，自媒体选题库是长期内容资产。
12. 原始热点不能直接写入自媒体选题库；必须先经过候选、桥接链、评分和策略判断。
13. 评分后必须经过 Topic Gate 选题前质检；主推荐区只展示“通过，待选择”的选题，被过滤内容留痕但默认不打扰涛哥决策。
14. 跨 skill 传递字段必须以 [交接物字段词典](./交接物字段词典.md) 为准；中文叫法只能做展示，不能替代 `topic_card`、`content_brief`、`draft`、`visual_plan`、`quality_review`、`platform_package_input`、`platform_package` 等标准技术名。
15. 需要用户交互的位置必须同时输出标准状态字段和口语化引导语，不能只写“等待确认 / 下一步 / 是否通过”。
16. 用户已经明确选择时不得二次确认；选题确认后自动进入 Brief，Brief 通过自动写口播，质检通过自动做平台包装，并自动生成最终 HTML 验收页。平台包完成不是人工门禁。
17. 每轮传播 workflow 结束或暂停时，必须更新工作流状态记录；下一次继续时先读状态记录，再判断从哪个交接物恢复。
18. 专项 skill 结束后必须给 2-3 个任务后导航建议；建议要说明“为什么”，不能只列下一步名称。
19. 每轮内容创作必须先明确 `account_profile` 和 `product_profile / campaign_profile`。账号回答“谁来说”，产品/活动对象回答“这次说什么、不能怎么说、要把人带到哪里”。
20. 从热点调研开始生成的 `research_run_id` 必须贯穿 `topic_card`、`content_brief`、`draft`、`visual_plan`、`quality_review`、`platform_package_input`、`platform_package` 和 `content_delivery_record`，确保来源不断链。
21. 热点研究必须判断时效：账号决定默认时效范围，内容策略决定最终时效要求，来源发布时间负责兜底校验；超过窗口的内容必须降级为行业趋势、复盘、常青问题或方法论内容。
22. 根目录只保留方法论、模板、总索引和跨账号汇总表；每轮真实内容的完整中间产物和最终交付物，必须按 `accounts/{账号名}/runs/{session_id}/` 落盘。
23. `工作流状态记录.md` 的 `current_artifact` 必须指向账号/session 目录里的具体产物文件；根目录汇总表只做索引和总览，不作为完整正文的唯一保存位置。
24. 中间产物写入 `intermediate/`，最终交付物写入 `deliverables/`；未确认草案不得命名为 final。
25. 最终人类验收入口必须优先生成 `deliverables/final-delivery.html`，把选题切口、正式文案、实际画中画图片、插入位置和多平台发布物料整合为好阅读、好复制、好下载的页面。
26. Markdown 是后台链路和追溯资产，不得用一堆 Markdown 替代最终验收页。
27. `deliverables/final-delivery.html` 默认是 `project_local`，只保证在 session 目录内可用；如果要发给别人、传网盘或离开项目目录使用，必须生成 `deliverables/export/{session_id}/` 可转交包或 `standalone_html`。
28. 可转交包必须带 `export-manifest.json`，列清 HTML、图片、sources、用途、来源和必需性；必要时生成 checksum manifest。
29. 每轮生产链路必须生成 `intermediate/00-execution-trace.md`，标记哪些动作来自 skill、哪些来自 agent 扶跑、哪些来自用户决策和环境能力；未来发布 skill 前必须看 maturity_level 和 agent_assist_level，不能把“扶着跑通”当成“可独立发布”。

---

## 五、当前不做

1. 不把 dbskill 安装成本项目正式 skill。
2. 不把外部方法论直接复制进项目规则。
3. 不直接改客户端文案、下载页或官网。
4. 不把传播草案当成产品开发验收包。
5. 不承诺任何未验证的商业化结论。
6. 不做自动发布工具。
7. 不接抖音、小红书、视频号、B站等平台发布 API。
8. 不自动登录平台后台。
9. 不自动评论、私信、互动或抓取平台后台数据。

---

## 六、状态模型和文案层自动化边界

本项目同时维护两类状态：

```text
project_stage：项目工程状态，用于判断本项目处于迁移、测试、可用还是归档。
workflow_usage_state：内容工作流使用状态，用于判断某条内容处于草案、审核、可人工处理、已确认、已归档或已放弃。
```

当前状态以 [STATUS.md](./STATUS.md) 为准。任何内容任务开始前，先确认项目状态允许继续；任何内容任务结束或暂停时，必须更新 [工作流状态记录](./工作流状态记录.md)。

v1.9.1 阶段，产品能力视为固定：

```text
公开互动分析工具
-> 评论区 / 直播间公开互动整理
-> AI 分析
-> 分析结果 / 重点互动 / 互动资产库
-> 免费学习版申请制
```

传播研究可以服务多个账号和多个产品对象；但每一轮具体内容必须只绑定一个明确的产品/活动对象。当前默认产品样例为“公开互动分析工具”，其固定能力如下：

AI 可以自动做：

1. 找热点。
2. 摘要热点事实。
3. 判断热点风险。
4. 计算热点和账号母题的关联度。
5. 匹配目标人群和产品能力。
6. 生成选题卡。
7. 根据内容形式字典自动建议内容形式、内容类型和外挂项。
8. 在涛哥选择选题后，自动生成内容 Brief 并做 Brief 质检。
9. 第一阶段默认生成短视频口播草案。
10. 口播草案必须先生成五秒留存设计，低于 7 分不进入画中画。
11. 图文、长文、朋友圈、社群、FAQ 和官网说明先保留未来路由，不展开制作办法。
12. 把口播草案自动转成热点画中画视觉策略和 image 提示词，首屏画面优先服务前 5 秒。
13. 用 dbskill 方法论做文案 + 视觉联合质检。
14. 质检通过后，先编译分发包装输入包，再按抖音、快手、小红书、视频号生成平台入口包装。
15. 生成修改建议。

涛哥创作工作流启动后，热点创作前必须先确定账号 / 品牌 / 产品对象。流程是：

```text
确定账号
-> 检查 accounts/{账号名}/account_profile.md
-> 按账号档案完整性检查表检查 P0 字段
-> 确定 product_profile / campaign_profile
-> 产品/活动对象边界齐全才进入热点发现
```

这里的账号是内容发布或业务承接对象，不是“涛哥创作工作流”的作者署名。

热点发现不能只按账号关键词窄搜。账号档案是“接热点能力模型”，不是简单关键词生成器。正式热点研究必须同时看：

```text
S 池：公共大热点 / 大时代情绪 / 全民关注事件
B 池：行业热点 / 圈层热点 / 平台和市场变化
A/C 池：目标人群现场 / 账号母题附近的真实问题
```

每个候选热点都要做 S/B/A/C/D 桥接判断，桥不上就不能硬蹭。

每个候选热点还必须做时效判断：

```text
hotspot_time_window：breaking_0_24h / live_hot_1_3d / current_hot_3_7d / warm_trend_7_30d / background_trend_30_90d / evergreen_90d_plus
hotspot_freshness_status：fresh_enough / aging_but_usable / too_old_for_hotspot / evergreen_only / unknown_time_blocked
content_position：breaking_hotspot / current_hotspot / industry_trend / evergreen_problem / case_review / methodology_content
```

旧内容可以做，但不能假装“当下热点”。例如超过 30 天的行业事件，只能作为行业趋势或复盘背景；超过 90 天的内容，只能作为常青问题、案例或方法论素材。

每轮热点研究还必须先生成来源计划，来源从 [热点搜索来源池](./热点搜索来源池.md) 中选：

```text
账号档案
-> 热点搜索来源池
-> 本轮来源计划
-> 三池搜索
-> 调研运行记录
-> 热点候选池
-> 热点评分表
-> Topic Gate 选题前质检
-> 自媒体选题库
```

五层资产定义：

```text
来源池：长期方法论资产，记录在哪搜、适合哪个账号和哪类热点。
调研运行记录：本轮过程资产，记录搜了哪里、用了什么查询、来源质量、核验情况和风险。
热点候选池：短期缓存，记录搜回来的原始热点、来源、时间、热度和初判。
热点评分表：筛选记录，记录桥接链、12 分评分和是否进入选题。
自媒体选题库：长期内容资产，只保存通过评分、策略明确、待涛哥确认的选题。
```

工作流状态记录用于接续，不是内容正文：

```text
本轮从哪里开始。
当前交接物是什么。
已经产出了哪些 ID。
上一次人类做了什么决定。
下一次回来应该先读什么。
```

Topic Gate 展示规则：

```text
通过，待选择：进入主推荐区。
降级轻观点 / 待补桥 / 淘汰 / 归档复盘：不进主推荐区，但必须留原因。
```

桥接质检不能只看“有没有桥接链”，还要判断桥接质量：

```text
未桥接 / 弱桥接 / 可桥接 / 强桥接 / 硬蹭嫌疑
```

在当前 Codex 环境里，进入最终交付前应优先调用内置 image 生成能力，把必要画中画生成到 `assets/images/`。中间阶段可以只生成视觉策略和提示词；最终交付不得只停留在提示词，除非明确标记图片待外部生成或生成失败。

未来需要照顾非 Codex 使用者时，可以设计 Seedream 4.0 / 5.0 等外部模型旁路；当前只沉淀兼容字段和降级策略，不接 API、不保存 API key、不建设图片生成服务。详见 [最终交付页与图片降级策略](./docs/explanation/最终交付页与图片降级策略.md)。

热点画中画提示词当前吸收的外部成熟经验：

```text
GPT-Image2-Skill：预检、质量/画幅选择、提示词工艺。
visual-skills：GPT Image 2 五槽模板 Scene / Subject / Important Details / Use Case / Constraints。
ai-video-storyboard-skill：统一视觉语言、短视频节奏、镜头/光线/动作描述。
```

AI 不自动做：

1. 发布内容。
2. 评论互动。
3. 私信触达。
4. 修改线上产品页面。
5. 承诺产品未实现能力。
6. 代替涛哥确认最终文案。

固定流程：

```text
AI 找热点
-> AI 生成调研运行记录
-> AI 评估关联度
-> AI 生成选题卡
-> 涛哥选择选题
-> AI 编译内容 Brief
-> AI 生成文案草案
-> AI 生成热点画中画提示词
-> AI 生成必要画中画图片或记录降级状态
-> AI 用 dbskill 质检和微调
-> AI 编译分发包装输入包
-> AI 生成多平台分发包装
-> AI 生成内容交付记录
-> AI 生成 final-delivery.html 人类验收页
-> 涛哥在最终 HTML 上人工验收 / 返工 / 归档 / 人工发布
-> 如需转交，AI 生成 portable_bundle / standalone_html
-> AI 更新工作流状态记录
-> 人工发布
-> 人工或半自动记录复盘
```

硬规则：

```text
文案最后必须人工确认。
人工确认前必须先形成内容交付记录，不能只丢一组标题和文案让人猜下一步。
```

---

## 七、和短视频创作 SaaS 的关系

本项目当前是轻量战术工作流，不是长期内容生产中台。

```text
认知推演工作流：上游脑库，沉淀涛哥的认知档案、表达资产和知识原子。
短视频创作项目：长期内容生产 SaaS，承接账号矩阵、母题、作品、发布观察和回流。
涛哥创作工作流：当前轻量内容生产和传播验证落点，可服务公开互动分析工具，也可服务涛哥账号矩阵和后续产品。
```

热点文案 skill 当前只做“智能脚本”：

```text
热点发现
-> 调研运行记录
-> 热点评分
-> 母题关联
-> 选题卡
-> 内容 brief
-> IP 资产调用
-> 文案草案
-> 画中画视觉策略
-> dbskill 质检
-> 分发包装输入包
-> 多平台分发包装
-> 内容交付记录
-> 涛哥人工确认
```

未来 SaaS 化时，迁移的是结构化产物和方法论，不是在本项目复制一个前端 UI 或发布后台。

当前 skill 拆分遵循：

```text
涛哥创作工作流总控只路由。
热点专项只产 topic_card。
Brief 专项只吃已选择 topic_card，产内容 Brief 和 Brief 质检。
画中画专项只吃口播 / brief / draft，产视觉策略和 image 提示词。
质检专项只吃 draft / brief。
旧入口只兼容旧唤醒词。
没有固定交接物，不继续拆。
```

标准交接物链路以 [交接物字段词典](./交接物字段词典.md) 为准：

```text
account_profile
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
-> human_confirm
```

内容交付记录是当前轻量工作流的收口点。它不代表自动发布，只代表这一条内容已经完成到“可人工处理”：

```text
最终 HTML 验收通过：涛哥可以自行发布。
返工：明确回到平台包装、质检、画中画、口播、Brief 或选题。
归档：暂不发布，但保留为内容资产。
放弃：本条不继续做。
```

收口时必须给口语化引导语，例如：

```text
最终 HTML 验收页已经生成。你可以直接复制文案、下载图片、拿平台物料去人工发布；如果要改，直接说“只改抖音标题”“回到口播改前 5 秒”“归档今天不发”。
```

---

## 八、后续可能开源方向

当前先不包装、不建独立仓库、不对外宣传。

后续可以考虑把传播 skill 整理成独立开源项目，例如：

```text
中文热点内容创作 Skill Kit
Hotspot-to-Content Skills
```

开源前置条件：

```text
先自用跑稳。
至少连续跑 10-20 条真实内容。
每条内容完成：热点 -> 选题卡 -> 口播 -> 画中画提示词 -> 出图/不出图判断 -> 质检 -> 人工发布 -> 复盘。
确认这套 skill 真能降低涛哥的创作成本，而不是只会写漂亮 README。
```

如果未来开源，必须在 README / NOTICE 中明确鸣谢 `dbskill`。本项目传播 skill 的拆分思路、路由/专项分工、内容质检意识和自媒体方法论工程化，受到 `dbskill` 启发；但本项目会保留自己的场景差异：

```text
dbskill：更偏通用中文自媒体方法论。
本项目传播 skill：热点 -> 母题 -> 产品传播 -> 口播 -> 画中画 image -> 质检 -> 分发包装输入包 -> 多平台分发包装。
```

推荐致谢口径：

```text
本项目的部分内容工作流设计、skill 拆分思路和内容质检方法，受到 dbskill 项目的启发。
特别感谢 dbskill 对中文内容创作、AI 写作质检和自媒体方法论工程化的探索。
```



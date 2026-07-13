# PROJECT MAP

> 状态：项目导航图
> 主责：让人和 AI 快速知道“规则在哪、账号在哪、产物在哪、索引在哪”。
> 边界：本文件只做导航，不保存具体内容正文。

---

## 入口顺序

```text
README.md
-> AGENTS.md
-> STATUS.md
-> docs/README.md
-> docs/reference/文档治理与目录规范.md
-> docs/reference/人类引导与任务后导航规范.md
-> 交接物字段词典.md
-> state/README.md
-> 本地 工作流状态记录.md（缺失时由模板初始化）
```

继续某条内容时：

```text
本地 工作流状态记录.md
-> current_artifact
-> accounts/{account_slug}/runs/{session_id}/manifest.yaml
-> 对应 intermediate 或 deliverables 文件
```

---

## 顶层目录

| 目录 / 文件 | 用途 | 谁主要看 |
|---|---|---|
| `README.md` | 项目总入口、边界、索引 | 人 + AI |
| `AGENTS.md` | AI 执行约定、门禁、路由 | AI |
| `STATUS.md` | 项目状态卡 | 人 + AI |
| `CONTACT.md` | 公开反馈、试用交流和安全联系边界 | 人 |
| `INSTALL.md` | 公开候选包 / 测试包启动说明 | 人 |
| `UPDATE.md` | 更新旧版本时的私有数据保护说明 | 人 + AI |
| `CHANGELOG.md` | 版本变化记录 | 人 |
| `RELEASE_NOTES.md` | alpha 候选发布说明和边界 | 人 |
| `NOTICE.md` | dbskill 启发、外部资料和项目边界说明 | 人 |
| `.github/ISSUE_TEMPLATE/` | 公开反馈入口模板 | 人 |
| `docs/reference/` | 字段、目录、状态、契约 | AI |
| `docs/README.md` | 文档分区、真源优先级和 AI 最短阅读路径 | 人 + AI |
| `docs/product/README.md` | 产品真源、确认入口、编译记录和历史证据分区索引 | 人 + AI |
| `docs/reference/README.md` | 执行规范和方法论分区索引 | AI |
| `docs/governance/` | 项目级 AI 驾驭工程、发版治理、隐私边界、任务路由、状态接续 | AI |
| `docs/governance/agent-orchestration/` | “按 AGENTS”后的任务路由、必读清单、构建 profile、状态门禁和任务后导航 | AI |
| `routes/` | 机器可读任务路由、构建 profile、算力 profile、必读清单草案 | AI |
| `state/` | 状态入口、当前状态桥接、状态迁移计划 | AI |
| `docs/explanation/` | 方法论和设计解释 | 人 |
| `docs/product/` | 产品路线图、开源上线前修复排序、能力边界 | 人 + AI |
| `docs/how-to/` | 操作流程 | 人 + AI |
| `docs/tutorials/` | 示例教程 | 人 |
| `skills/` | 可执行 skill 合集 | AI |
| `skills/README.md` | Skill 主链顺序和职责索引 | AI |
| `templates/README.md` | 模板与 Schema 分区索引 | AI |
| `objects/` | 产品对象和活动对象 | AI |
| `objects/README.md` | 本地产品 / 活动对象索引；当前 public build 不携带 objects | AI |
| `accounts/` | 本地私有账号档案和账号内容产物，默认不进入公开 Git / tag | 人 + AI |
| `indexes/` | 跨账号汇总索引 | 人 + AI |
| `外部资料/` | 第三方方法论参考 | 人 + AI |

---

## 核心原则

```text
根目录不放单条内容正文。
账号目录隔离账号身份。
session 目录隔离单轮内容。
intermediate 放中间产物。
deliverables 放最终交付物。
final-delivery.html 是人类验收入口。
export/ 是可转交交付包。
manifest.yaml 做机器可读索引。
indexes/ 只做跨账号检索，不当正文来源。
```

## 设计说明

| 文件 | 用途 |
|---|---|
| `docs/reference/人类引导与任务后导航规范.md` | 规定任务前路由、任务后导航、自动推进和人类停顿点，避免让用户猜下一步 |
| `docs/reference/平台发布物料方法论与字段规范.md` | 规定封面标题、视频标题、发布描述和话题标签的职责、平台差异、字段和最终 HTML 展示要求 |
| `docs/reference/skill执行透明度与成熟度规范.md` | 记录 skill 独立能力、agent 扶跑痕迹、成熟度等级和发布前风险 |
| `docs/reference/skill_contract模板.md` | 定义每个 skill 进入编译前必须具备的触发条件、输入输出、路径、人类门禁、自动推进、失败处理和验收样例 |
| `docs/reference/版本治理与Git边界.md` | 规定本地工作母仓、Portable Git 入口、入库范围、排除范围和公开 GitHub 净化规则 |
| `docs/reference/GitHub开源上线检查清单.md` | R4 发布门禁，检查 public_release 的入口、社区健康文件、sample、链接、隐私、密钥、本机路径、成熟度和发布边界 |
| `docs/reference/Windows环境兼容性支持矩阵.md` | alpha.4 的 Windows 宿主、路径、source/ZIP、归档完整性、not_certified 轴和 H6 候选复测真源 |
| `docs/reference/R1-R4只读checker执行规范.md` | R1-R4 只读 checker 执行规范，规定 check_scope、报告路径、检查项、判定规则和只读边界 |
| `docs/reference/R1-skill渐进读取与长文边界.md` | 规定 R1 长 skill 的渐进读取方式和测试前长文边界，避免靠全文硬撑 |
| `docs/reference/R1-sample-run产物模板.md` | 规定 R1 单篇 sample run 的 manifest、execution trace、trace check、人工决策恢复和 preflight 输出模板 |
| `docs/reference/R2-运行模型执行规范.md` | 规定 R2 多分支、parent / child session、checkpoint、run lock、state transition、branch ledger、fan-in 和断点恢复执行口径 |
| `docs/reference/R3-图片资产执行规范.md` | R3 图片资产链的已编译执行规范；C71-C80 使用内容派生数量，C81-C90 增加 provider / postprocess 分阶段与 reconcile-first 恢复 |
| `docs/explanation/最终交付页与图片降级策略.md` | 说明最终 HTML 交付页、图片资产、Codex 内置出图和未来 Seedream 等外部模型降级旁路的关系 |
| `docs/explanation/工作流工程缺陷复盘与修订方案.md` | 记录 SAMPLE-HISTORICAL-001 暴露出的交付工程缺陷，以及 project_local / portable_bundle / standalone_html 的修订方案 |
| `docs/explanation/工作流问题包与产品设计草案-20260706.md` | 汇总真实运行暴露的 17 个 workflow 问题，作为 skill 编译、多分支、画中画资产和 validator 的产品设计输入 |
| `docs/product/GitHub开源上线前Workflow修复路线图.md` | 按产品开发逻辑拆解 17 个问题、成熟 workflow 解法、本项目应做到的程度和 GitHub 开源上线前修复排序 |
| `docs/product/R0-首次账号建档与入口Onboarding.md` | 首次使用入口产品定义，规定无账号时如何通过 account-onboarding 创建账号档案 |
| `docs/product/R1-产品总览.md` | R1 产品层总入口，给涛哥确认、AI 编译和维护者阅读提供分层路径，并说明 R1 的质量标准和当前真源关系 |
| `docs/product/内容创作质量方法论编译补充-R1.md` | 将 Hook 路由、正文信息密度、共鸣与兑现并入 R1 方法论编译，作为 draft / review 合同后续修订依据 |
| `docs/product/R1-P14-方法论编译规则.md` | 定义讨论稿、调研、复盘和方法论如何进入 product / reference / CONTRACT / SKILL / 字段词典 / validator，避免规则散落或越级编译 |
| `docs/product/R1-P15-skill粒度与入口治理规则.md` | 定义 skill 粒度、主入口、专项入口、兼容入口、拆分合并标准和 R1 编译顺序 |
| `docs/product/R1-P13-execution-trace检查清单与validator草案.md` | 定义 execution trace 的必备结构、BLOCKER / WARN / INFO 规则和未来 validator 输出字段，用来判断 agent 扶跑和 R1 可编译程度 |
| `docs/product/R1-P02-agent扶跑收敛与可编译判定.md` | 定义 agent 扶跑风险等级、R1 可编译阈值、不可编译信号和编译后 sample run 验证目标 |
| `docs/product/R1-skill执行合同组可编译总验收.md` | 汇总 R1 产品定义、核心 skill 合同、成熟度判断和确认后编译任务 |
| `docs/product/R1-合同版本与变更治理.md` | 定义 R1 合同组版本、单 skill 合同版本、变更确认规则、旧 session 恢复和旧入口兼容 |
| `docs/product/R1-字段级输入输出矩阵.md` | 定义核心 skill 的字段级输入输出、状态接线、贯穿字段和缺字段恢复规则 |
| `docs/product/R1-人类门禁决策枚举与恢复规则.md` | 定义 R1 人类门禁的决策枚举、状态变化、恢复路径和禁止门禁节点 |
| `docs/product/R1-trace-check注册表.md` | 定义 R1 原子化 trace/check 项、失败等级、反写位置和检查输出模板 |
| `docs/product/R1-产品确认清单.md` | 将 R1 是否进入 skill 编译拆成 R1-C01 到 R1-C13 的逐项确认 |
| `docs/product/R1-skill拆合与编译记录.md` | 记录 R1 确认后的 skill 拆合取舍、成熟 workflow 参考、读取传规则和实际编译动作 |
| `docs/product/R1-skill编译验收与sample-run清单.md` | 记录 R1 编译后的静态验收、sample run 必产物、R1CHK 最低项和 L3 candidate 判定条件 |
| `docs/product/R2-产品总览.md` | R2 产品层入口，说明运行模型、fan-out / fan-in、branch_lock、状态恢复和边界 |
| `docs/product/R2-运行模型与分支封锁规则.md` | R2 细则，定义多选拆分、child session、fan-in 索引、任务分支锁、恢复字段、checkpoint、分支台账、操作合同、ID 和索引规则 |
| `docs/product/R2-产品确认清单.md` | R2 确认入口，把 R2 是否进入运行模型编译拆成 R2-C01 到 R2-C20 |
| `docs/tutorials/r2-dry-run-sample/README.md` | R2 dry-run 样本包入口，用假 parent / child session 验证 branch ledger、checkpoint、state_transition、run_lock 和 resume_report |
| `docs/product/R3-产品总览.md` | R3 产品层入口；C71-C80 定义 0 到 N 与全部 accepted 自动生成，C81-C90 定义真实运行防复发合同 |
| `docs/product/R3-画中画与图片资产模型.md` | R3 细则，定义 visual_need_analysis、accepted visual tasks、prompt、generation record、image asset、metadata sidecar、HTML 嵌入和不可覆盖规则 |
| `docs/product/R3-产品确认清单.md` | R3 确认入口；C01-C90 已确认并编译，含内容驱动视觉需求与 H6 真实回归可靠性合同 |
| `docs/product/R3-skill编译记录与审计.md` | R3 编译记录，说明已编译文件、成熟项目对标、冲突冗余审计、完整性和后续 dry-run |
| `docs/tutorials/r3-dry-run-sample/README.md` | R3 dry-run 样本入口，用最小假样本验证 visual_beat、prompt_card、generation_record、image_asset、metadata sidecar 和 html_embed_manifest |
| `docs/tutorials/r3-generated-image-sample/README.md` | R3 generated 图片样本入口，用真实生成图验证图片文件、sidecar、checksum、HTML 预览和下载链路 |
| `docs/tutorials/r1-r4-integrated-dry-run-sample/README.md` | R1-R4 综合 dry-run 样本入口，用脱敏单题验证内容链路、运行模型、pending_external 图片资产链和 public_release precheck |
| `docs/product/R4-产品总览.md` | R4 产品层入口，说明 GitHub 开源上线前 public_release、社区健康文件、样例、manifest、成熟度和边界 |
| `docs/product/R4-开源交付与净化规则.md` | R4 细则，定义工作母仓与公开包边界、净化动作、public-manifest、敏感内容阻断和发布检查 |
| `docs/product/R4-产品确认清单.md` | R4 确认入口，把 R4 是否进入开源规则 / 包装编译拆成 R4-C01 到 R4-C35 |
| `docs/product/R5-产品总览.md`、`docs/product/R5-账号视觉身份与二手车优先热点雷达.md`、`docs/product/R5-产品确认清单.md` | R5 产品组：定义账号级视觉身份、账号策略传参、二手车优先雷达、自由扩词、事件模型、趋势证据；R5-H1 至 H6 已闭合账号启动、session 快照、跨账号技术身份绑定、私有显式迁移与真实启动回归 |
| `docs/product/R1-R4综合dry-run前置检查.md` | R1-R4 综合 dry-run 前置门禁，判断内容链路、运行模型、图片资产链和开源包装是否具备同跑条件 |
| `docs/product/R1-R4只读checker产品定义.md` | R1-R4 只读 checker 产品入口，定义 checker 范围、输入输出、报告字段、阻断等级和编译前确认项 |
| `docs/how-to/workflow-business-state-flow.md` | 业务状态流转图的 Markdown / Mermaid 版，适合 GitHub 和 AI 阅读 |
| `docs/how-to/workflow-business-state-flow.html` | 可离线打开的交互式业务状态图，适合测试者快速理解 workflow |
| `docs/how-to/export-support-log.md` | 外部测试者反馈问题时，如何导出可复盘日志包 |
| `docs/governance/README.md` | 项目级 AI 驾驭工程规则的模块化入口，避免继续把所有治理细则堆进 AGENTS |
| `docs/governance/agent-orchestration/README.md` | AI 驾驭工程编排入口，定义 root instructions、scoped rules、skills、state、gates、logs 的关系 |
| `docs/governance/agent-orchestration/task-routing.md` | 用户口语意图到 task_type、必读文件、自动推进、人类门禁的路由 |
| `docs/governance/agent-orchestration/build-profiles.md` | dev / test / public 三类构建与数据边界，隔离真实生产、测试样例和公开包 |
| `docs/governance/agent-orchestration/state-and-gates.md` | 状态接续、checkpoint、检查门禁、失败收口规则 |
| `docs/governance/agent-orchestration/after-task-guidance.md` | 任务完成、等待、阻断或失败后的后置引导、自动继续、推荐回复和禁止写法 |
| `docs/governance/agent-orchestration/required-reads.yaml` | 机器可读必读清单草案，后续可编译成 validator |
| `routes/README.md` | 机器可读路由目录入口 |
| `routes/workflow-routes.yaml` | 用户意图到 task_type / build_profile / required_reads / gates / writes / after_completion 的路由草案，覆盖内容生产、产品开发、skill 编译、测试、发版、调研、隐私审计、repo 维护、分发包和 issue 处理 |
| `routes/build-profiles.yaml` | dev / test / public 构建 profile 的机器可读边界 |
| `state/README.md` | 状态入口说明，解释当前 bridge 模式 |
| `state/current-state.yaml` | 当前状态桥接文件，指向 `工作流状态记录.md`、账号 manifest、checkpoint 和 indexes |
| `templates/state/工作流状态记录.template.md` | 本地私有状态记录初始化模板；公开 Git 不保存真实运行状态 |
| `state/state-migration-plan.md` | 从根目录状态记录迁到结构化 state 层的阶段计划 |
| `templates/checker/workflow-check-report.template.md` | 只读 checker 报告模板，承载 `workflow_check_report` 的稳定字段和人类可读结构 |
| `templates/checker/sample-check-report.template.md` | 样例检查报告模板，承载 `sample_check_report` 的稳定字段 |
| `templates/checker/release-check-report.template.md` | 公开候选包检查报告模板，承载 `release_check_report` 的稳定字段 |
| `templates/schema/p0/` | P0-H1 v0.2 plan、event、lineage、artifact check、typed render input Schema 与兼容矩阵 |
| `templates/schema/p0-h2/render-receipt.v0.2.schema.json` | P0-H2 确定性渲染回执 Schema，固定输入、模板和 HTML digest 及纳入的卡片 / 资产 ID |
| `templates/schema/p0-h3/` | P0-H3 独立 fixture、expected result、状态证据和统一检查结果 Schema |
| `templates/schema/p0-h4/` | P0-H4 evidence command、可重建 state projection 和 resume summary Schema |
| `templates/public-release/README.md` | R4 public_release 模板入口，说明未来公开候选包结构和模板边界 |
| `templates/public-release/public-manifest.template.yaml` | public-manifest 模板，机器可读记录能力、边界、样例、检查状态和不支持能力 |
| `templates/public-release/release-checklist.template.md` | release-checklist 模板，对应 R4CHK-001 到 R4CHK-010 |
| `examples/README.md` | 脱敏样例入口，说明 sample-account 和 sample-run 的公开包用途 |
| `tools/README.md` | P3 validator / build 命令合同，定义 fast / standard / release 模式、exit code、报告双轨和脚本边界 |
| `tools/validate-route-schema.ps1` | 检查 `routes/workflow-routes.yaml` 的 route、after_completion、推荐回复和编排入口索引是否完整 |
| `tools/validate-doc-governance.ps1` | 检查分区索引覆盖、目录 README、根入口最短路径、相对链接 / AI nav anchor、长文导航和当前产品范围 |
| `tools/validate-gates.ps1` | 执行已实现门禁；未知 gate 必须失败，不能空检查后返回 pass |
| `tools/validate-p0-h1-contracts.ps1` | 验证 P0-H1 版本钉住、event envelope、retry、asset checks、typed render input 和正反 fixture；不执行 v0.2 renderer |
| `tools/P0ContractHelper.ps1` | P0 v0.2 合同确定性校验函数库，供 H1 checker 和后续 H2 runtime 复用 |
| `tools/P0RuntimeV02.ps1` | P0-H2 v0.2 输入编译、readiness 派生、卡片 HTML 渲染、回执、血缘与检查记录实现 |
| `tools/validate-p0-h2-runtime.ps1` | 用脱敏单篇 fixture 验证 H2 compiler / renderer、确定性、幂等、安全、页面结构和 v0.1 兼容 |
| `tools/validate-p0-h3-fixtures.ps1` | 逐个验证 P0-F03 至 F19 的等待、失败、恢复、兼容、并发、中断和取消证据，并输出统一结果 |
| `tools/P0EvidenceRuntime.ps1` | P0-H4 单一 append-only event writer、lineage、state projection 与 resume summary 函数库 |
| `tools/invoke-p0-evidence.ps1` | 五个 P0-E02 业务命令及 projection rebuild / orphan reconciliation 维护入口；不主动执行外部动作 |
| `tools/validate-p0-h4-evidence.ps1` | 真实执行 H4 evidence fixture，验证统一 writer、命令、投影、恢复与对账 |
| `tools/invoke-p0-h5-regression.ps1` | 在全新私有 session 复制已验证 baseline 内容与图片，重建 P0 v0.2 plan / events / lineage / typed input / HTML / resume；拒绝覆盖旧 run，不调用 provider |
| `tools/validate-p0-h5-regression.ps1` | 验证 H5 内容语义 digest、图片来源 / sidecar / hash、交付卡片、四个强制 warning 和完整 runtime 闭环；成功仍为 `pass_with_warnings` |
| `tools/validate-p0-h6-preflight.ps1` | H6 baseline prompt 证据检查；不输出成本 / 调用上限或 waiting-human 语义，为 H6A 分析后自动接续 H6B 提供历史证据 |
| `tools/complete-p0-h6-regression.ps1` | H6 `self_test / prepare / finalize` 协调器；prepare 编译 plan / events / metadata / typed candidate，finalize 在证据闭合后单调更新 manifest；不调用 provider |
| `tools/validate-p0-h6-regression.ps1` | 只读验证 H6 动态 cardinality、实际生成次数、恢复字段、candidate/input digest、trace、HTML、lineage、projection 和 resume |
| `tools/validate-p0-h6-reliability.ps1`、`examples/p0-h6-reliability-fixtures/` | 脱敏防回归中断恢复、状态单调、checker purity、动态 cardinality、digest、layout 和 executable smoke，并接入公开包 P3REL-023 |
| `tools/P0FinalDeliveryV03.ps1`、`tools/prepare-p0-h7-delivery.ps1`、`tools/complete-p0-h7-delivery.ps1`、`tools/validate-p0-h7-*.ps1`、`examples/p0-runtime-v0.3-fixture/` | P0-H7 当前交付 revision、平台封面绑定、精确 PIP、warning、时长诚实性、同源视图、状态 finalize、幂等和真实 H6→H7 回归；公开包门禁 P3REL-025 |
| `tools/validate-cover-composition.ps1` | 检查封面设计包、合成记录、资产角色、cover_review、HTML cover embeds 和 prompt_only 诚实状态 |
| `tools/validate-r3-visual-text.ps1` | 检查逐图文字决策、来源绑定、模型文字降级、条件合同，以及 R3 sample 的 ID / 状态 / next_skill / trace / final HTML 数据流 |
| `tools/R3VisualBudget.ps1` | 旧 R3 visual-budget 确定性合同；只保留 history-only compatibility |
| `tools/validate-r3-visual-budget.ps1` | 旧 visual-budget fixture 兼容 checker；不作为现行产品门禁 |
| `tools/R3VisualNeed.ps1` | R3-C71 到 C80 内容驱动视觉需求、0 到 N、generate/reject、accepted task 映射和 pass 后无人工确认自动派发的确定性合同函数库 |
| `tools/validate-r3-visual-need.ps1` | 现行 17 项 visual-need 正反 fixture 与八层 sink checker；接管 product_contract_compilation_gate |
| `templates/schema/r3/visual-budget.v0.1.schema.json` | 旧视觉预算机器合同；只读兼容历史 session |
| `templates/schema/r3/visual-need-analysis.v0.1.schema.json` | 现行内容驱动视觉需求、无上限数量和 Image 2 全 accepted 生成合同 |
| `examples/r3-visual-budget-fixtures/README.md` | 旧 visual-budget 脱敏兼容回归 |
| `examples/r3-visual-need-fixtures/README.md` | R3-C71 到 C80 的 0 图、5 / 7 图和证据 / 情绪 / attention / cap 正反回归入口 |
| `examples/r3-visual-text-fixtures/fixtures.json` | R3-C54 到 R3-C70 的九类脱敏验收 fixture |
| `examples/sample-account/account_profile.md` | 虚构账号档案样例，只展示字段结构 |
| `examples/sample-run/README.md` | sample run 模板入口，说明最小内容链路和 pending_external 边界 |
| `examples/sample-01-onboarding/README.md` | P4 样例 1，验证无账号首次使用和 account-onboarding 路由 |
| `examples/sample-02-single-content-run/README.md` | P4 样例 2，验证选题确认后自动走到最终 HTML |
| `examples/sample-03-final-review-revision/README.md` | P4 样例 3，验证最终 HTML 后局部返工和追加画中画 |
| `examples/p0-runtime-fixture/README.md` | P0 单 session 轻量 runtime 脱敏 fixture，覆盖完整业务 plan、事件、lineage 和确定性 HTML |
| `examples/p0-h1-contract-fixtures/README.md` | P0-H1 v0.2 合同正反 fixture，验证版本、事件、重试、资产检查和 typed render 输入；不调用真实能力 |
| `examples/p0-runtime-v0.2-fixture/README.md` | P0-H2 脱敏单篇运行 fixture，真实执行 typed input compiler、readiness derivation、HTML renderer 与 render receipt |
| `examples/p0-h3-recovery-fixtures/README.md` | P0-F03 至 F19 独立失败 / 恢复 fixture；每案自带 plan、events、最小证据和 expected result |
| `examples/p0-h4-evidence-fixture/README.md` | P0-H4 五个 evidence commands、统一 writer、projection 与 orphan reconciliation 脱敏运行样例 |

## Skill 合同

| 文件 | 用途 |
|---|---|
| `skills/account-onboarding/SKILL.md` | 首次账号建档 skill，负责无账号 / 账号不存在时创建账号档案草案并等待确认 |
| `skills/account-onboarding/CONTRACT.md` | account-onboarding 合同，定义触发、输入输出、状态、人类门禁和失败处理 |
| `skills/propagation-router/CONTRACT.md` | propagation-router 的产品合同草案，定义总控路由的触发、输入输出、人类门禁、自动推进和失败处理；确认前不得改写对应 `SKILL.md` |
| `skills/hotspot-topic-research/CONTRACT.md` | 热点选题研究合同草案，定义账号 / 产品门禁、来源时效、Topic Gate 和选题卡输出 |
| `skills/content-brief-compiler/CONTRACT.md` | 内容 Brief 编译合同草案，定义已选 topic_card 到 content_brief 的输入输出和自动推进 |
| `skills/copywriting-draft-writer/CONTRACT.md` | 口播草案合同草案，定义 Brief 到 draft、五秒留存评分和画中画前置门槛 |
| `skills/talking-head-image-pip/CONTRACT.md` | R3 画中画资产生产合同，定义 visual_plan、image_prompt_set、image_generation_record、image_asset_set、metadata sidecar 和自动质检交接 |
| `skills/static-visual-director/SKILL.md` / `CONTRACT.md` | 内部静态视觉编导，定义原子规划、逐图 visual_text_task、文字预算和来源绑定 |
| `skills/image-prompt-compiler/SKILL.md` / `CONTRACT.md` | 内部提示词编译，保持 Codex / Seedream 路径语义一致 |
| `skills/image-asset-producer/SKILL.md` / `CONTRACT.md` | 内部图片资产生产，负责出图、画中画确定性叠字、降级和不可覆盖资产记录 |
| `skills/copywriting-quality-review/CONTRACT.md` | R3 文案与视觉联合质检合同，定义 review_status、图片资产追溯、prompt 完整度、HTML 嵌入准备和平台包装自动推进 |
| `skills/platform-packaging-adapter/CONTRACT.md` | 多平台包装合同草案，定义 platform_package_input、platform_package 和 content_delivery_record |
| `skills/cover-design-compiler/SKILL.md` | 封面成品编译 skill，负责 cover_design_package、cover_composition、确定性叠字和 prompt_only 降级 |
| `skills/cover-design-compiler/CONTRACT.md` | 封面成品合同，定义平台策略、资产角色、合成状态、局部返工和 cover_review 交接 |
| `skills/final-delivery-builder/CONTRACT.md` | R3 最终交付构建合同，定义 final-delivery.html、html_embed_manifest、portable_bundle、standalone_html、图片状态诚实展示和人工验收门 |
| `docs/product/P01-skill-contract可编译验收表.md` | 汇总 P01 的 8 个核心 skill 合同，检查是否达到“确认后可编译”状态 |

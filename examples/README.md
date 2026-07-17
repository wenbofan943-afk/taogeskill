# Examples

> 状态：template_index  
> 主责：承载未来公开包使用的脱敏样例。  
> 边界：本目录下的样例必须是 sample_only，不得包含真实账号、真实客户资料、真实生产 runs 或未授权素材。
> Alpha 候选提醒：这些样例是 sample_only 和 regression fixture，只证明入口、字段、交接物、回放和只读检查能闭合；不证明真实热点质量、真实图片质量、真实账号生产效果或自动发布能力。

---

## 样例层级

```text
examples/
├── sample-account/
├── sample-run/
├── sample-01-onboarding/
├── sample-02-single-content-run/
├── sample-03-final-review-revision/
├── p0-runtime-fixture/
├── p0-h1-contract-fixtures/
├── workflow-kernel-m1-fixtures/
├── workflow-kernel-m2-direct-shadow-fixtures/
├── workflow-kernel-m3-hotspot-shadow-fixtures/
├── workflow-kernel-m4-session-switch-fixtures/
├── r7-h1-contract-fixtures/
├── r7-h6a-hotspot-fixtures/
├── r7-l3-h2-visual-semantic-fixtures/
├── r8-skill-context-fixtures/
├── r8-h5r1-contract-fixtures/
├── r8-h5r2-input-fixtures/
├── r8-h5r3-evaluation-fixtures/
├── p0-runtime-v0.2-fixture/
├── p0-runtime-v0.3-fixture/
├── p0-runtime-v0.4-fixture/
├── p0-runtime-v0.5-fixture/
├── p0-h3-recovery-fixtures/
├── p0-h4-evidence-fixture/
├── p0-h6-reliability-fixtures/
├── r3-visual-budget-fixtures/
├── r3-visual-presentation-fixtures/
├── r5-h2-account-radar-fixtures/
├── r5-h5-account-startup-fixtures/
├── r5-h6-account-identity-fixtures/
├── r6-content-evidence-fixtures/
├── r6-script-visual-fixtures/
├── r3-visual-need-fixtures/
├── r5-h1-account-visual-identity-fixtures/
├── windows-runtime-helper-fixture/
├── windows-environment-preflight-fixture/
├── windows-archive-integrity-fixture/
├── windows-clean-room-matrix/
└── regression-suite.yaml
```

当前目录是 R4 编译后的样例模板入口。  
正式生成 `public_release/` 前，应把现有 dry-run 教程中适合公开的内容整理到这里，并按 `docs/reference/GitHub开源上线检查清单.md` 检查。

## 先看哪个

| 你是谁 | 先看 | 为什么 |
|---|---|---|
| 第一次下载，只想知道怎么开始 | `sample-01-onboarding` | 它验证没有账号时，workflow 会引导新建账号，而不是让你填字段表 |
| 想看主链路是否自动到底 | `sample-02-single-content-run` | 它验证选题确认后，Brief、文案、画中画、质检、平台包和最终 HTML 会自动衔接 |
| 想看最终 HTML 后能不能返工 | `sample-03-final-review-revision` | 它验证只改标题、追加画中画、重建 HTML，不重跑热点 |
| 想看机器可读业务计划和确定性运行边界 | `p0-runtime-fixture` | 它展示完整单篇 plan、append-only event、lineage、幂等渲染和 legacy replay 边界 |
| 想看 P0 v0.2 合同与错误场景 | `p0-h1-contract-fixtures` | 它用正反样例验证版本钉住、事件顺序、幂等冲突、重试边界、资产检查和统一卡片输入 |
| 想看新架构怎样把旧 25 / 30 节点收敛为 7 阶段 | `workflow-kernel-m1-fixtures` | 它验证三份机器真源、35 个 current component、10 条历史 blueprint 和 5 个 fail-closed 负例；只做静态编译，不启动新内核 |
| 想看新内核怎样隔离执行直供控制面 shadow | `workflow-kernel-m2-direct-shadow-fixtures` | 它用同一脱敏输入比较 artifact、event、stop reason 和 final HTML，并验证 rebuild / replay 与 15 个负例；中途非正向状态会阻断，不执行语义 worker、不切换 current、不认证 L3 |
| 想看热点 shadow 怎样等待、续跑、reconcile 和处理反转 | `workflow-kernel-m3-hotspot-shadow-fixtures` | 它覆盖完整热点正链、research/freshness 外部等待、Topic Gate、两类 replan、幂等、重建及 false-success 负例；不联网、不调用 provider、不切换 current、不认证 L3 |
| 想看新旧 session 如何安全切换代际 | `workflow-kernel-m4-session-switch-fixtures` | 它覆盖新 session 默认 current、旧 R7 只读续跑、未来回滚、不可变 binding / commit marker 和 19 个正反场景；不迁移旧 session、不认证 L3 |
| 想看 R7 如何停止临场串步骤、猜 enum 和手写 submission | `r7-h1-contract-fixtures` | 它验证两条单篇蓝图、节点 / 合同 / 动作注册表、typed task/submission 和 legacy replay-only 边界 |
| 想看 R7 task 怎样确定性提交与恢复 | `r7-h2-runtime-fixtures` | 它执行 R7-F05 至 F08：缺字段、输入漂移、重复提交和中断 reconcile；不代表 H3/H4/H5 已实现 |
| 想看热点 current route 怎样接入视觉语义与恢复 | `r7-l3-h4-hotspot-route-fixture` | 公开脱敏 fixture，覆盖账号策略绑定、外部等待续跑、事实更新/反转和 scoped 视觉返修；不联网、不调用 Image 2、不使用私有账号 |
| 想看热点入口怎样从请求稳定走到热点草稿 | `r7-h6a-hotspot-fixtures` | 它在离线脱敏环境执行 request -> set -> panel -> decision -> selected source -> Brief -> structure -> draft，并停在 H6B freshness / delivery 之前 |
| 想看业务 Skill 的入口体量、职责与 references 是否发生漂移 | `r8-skill-context-fixtures` | H1 对 28 个项目业务 Skill 做机器清单与 11 个 mutation 校验；H2 用 10 个热点场景，H3 用 9 个 router / human-gate 场景，H4 用 7 个目标平台加载与集合一致性场景；H5 固定 3 个目标 Skill × 正常、条件 / 恢复、拒绝的合同 preflight，并串联 current / legacy 总回归。它不生成 baseline/candidate 业务产物，不能替代人类盲评；均不联网、不调用 provider |
| 想看 H5 v0.2 为什么不能再把静态绿灯当成业务 A/B | `r8-h5r1-contract-fixtures` | H5R1 用九类合法对象、九个 Schema 负例和十二个跨对象负例验证状态、可比性、匿名包、finalization 与 supersedes；adapter 和独立执行仍待后续 |
| 想看同一业务语义如何进入两个历史合同版本 | `r8-h5r2-input-fixtures` | 9 个 shared semantic case 经六个 adapter 生成 18 个 typed input、18 个依赖快照与 18 个 arm-input；不执行代理、不生成匿名包 |
| 想看 H5 如何区分质量可比、行为比较、回归处置和无效结果 | `r8-h5r3-evaluation-fixtures` | 9 案生成 18 个 arm result、9 个机器结论和 9 个可比性结论；另以 13 个负例阻断缺文件、Schema/hash 篡改、拒绝路径产物和机器失败假盲评 |
| 想看 R7 producer 怎样停止手拼 submission 与误推进等待 | `r7-h3-producer-fixtures` | 它验证 12 个 adapter、R6 producer slice、keep-current 与 waiting cursor；不代表 H4/H5 已实现 |
| 想看视觉为什么需要、走哪类来源、如何编译 Prompt 和独立看图 | `r7-l3-h2-visual-semantic-fixtures` | 它验证五段 typed 工作包、三类来源、缺能力等待、provider reconcile 与素材 / 最终交付 review；不调用真实 provider |
| 想看统一卡片怎样真实生成交付页 | `p0-runtime-v0.2-fixture` | 它执行 typed input compiler、readiness derivation、确定性 HTML renderer 和 render receipt，不调用真实图片或外部 API |
| 想回放 v0.4 视觉呈现、平台独立封面与显式视觉验收 | `p0-runtime-v0.4-fixture` | 它保留 visual_insert、目标画布 / 槽位、封面和表面模拟预览的历史兼容，不代表当前合同 |
| 想看当前结构、全文节点、脚本审查和视觉覆盖怎样进入最终 HTML | `p0-runtime-v0.5-fixture` | 它执行当前 typed compiler、确定性 renderer、revision marker 和幂等检查；不调用 provider 或真实平台 |
| 想看失败后停在哪里、怎么恢复 | `p0-h3-recovery-fixtures` | 它用 F03-F19 独立样例验证等待、失败、幂等、恢复、取消和兼容边界，不调用真实外部能力 |
| 想看过程证据怎样登记和恢复 | `p0-h4-evidence-fixture` | 它真实执行五个 evidence commands、统一 writer、投影重建和孤儿产物对账，外部结果仅登记不调用 |
| 想看 H6 中断、状态回退和固定数量怎样防复发 | `p0-h6-reliability-fixtures` | 它验证 reconcile-first、状态单调、checker 只读、动态 cardinality、digest、layout 和 executable smoke |
| 想看旧 visual-budget session 如何保持可读 | `r3-visual-budget-fixtures` | 它只验证历史时长预算合同兼容，不代表现行产品规则 |
| 想看横竖比例、保护区裁切和封面视觉门禁 | `r3-visual-presentation-fixtures` | 它覆盖呈现模式、画布 / 槽位、平台 rendition、确定性表面模拟、显式视觉审核和破坏性裁切阻断 |
| 想看一篇内容为什么是 0 到 N 张图 | `r3-visual-need-fixtures` | 它验证受众 / 语义节点、七类视觉任务、generate / reject、零图、5 / 7 张无上限、证据 / 情绪 / 重复 / call-limit 反例 |
| 想看用户原稿怎样跳过热点但不跳工作流，以及新闻截图为何不走 Image 2 | `r6-content-evidence-fixtures` | 它验证直供入口、内容来源血缘、证据五态、来源捕获 / 恢复、确定性画中画和生成图伪证据阻断 |
| 想看直供 baseline、短视频结构、全文节点、口播质检和 0 到 N 视觉覆盖怎样闭合 | `r6-script-visual-fixtures` | 它验证原稿语义不变、双入口结构、逐 byte 覆盖、revision 决策、八种视觉 disposition、分账与 current pointer |
| 想看账号视觉身份如何约束表达 | `r5-h1-account-visual-identity-fixtures` | 它验证账号身份、栏目模板、负向审美和“身份不得固定图片数”合同 |
| 想看 Windows 编码、路径和归档如何防止“看似成功” | `windows-runtime-helper-fixture` → `windows-environment-preflight-fixture` → `windows-archive-integrity-fixture` | 依次验证 UTF-8 / argv、路径前置门禁和 manifest / 安全解压 / false-success 阻断 |
| 想看声明的 Windows 支持是否按完整组合验证 | `windows-clean-room-matrix` | 它固定 Windows PowerShell 5.1 × 三种路径 × source/zip 的 6 个 canonical case，并把超预算定义为预期阻断；PowerShell 7 不属于当前公开承诺 |

三个 P4 教学样例都必须带：

```text
input-prompt.md
expected-agent-behavior.md
expected-artifacts.md
manifest.yaml
execution-trace.md
check-report.md
sample-check-report.json
```

样例默认不代表完整真实生产测试通过，只代表该路径有可读、可追溯的验收材料。

## 验证命令

```powershell
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-01-onboarding
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-02-single-content-run
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-03-final-review-revision
.\tools\validate-regression-suite.ps1 -SuitePath .\examples\regression-suite.yaml
.\tools\invoke-workflow-runtime.ps1 -Session .\examples\p0-runtime-fixture -Mode validate
.\tools\validate-p0-h1-contracts.ps1
.\tools\validate-workflow-ir-m1.ps1
.\tools\validate-workflow-kernel-m2.ps1
.\tools\validate-workflow-kernel-m3.ps1
.\tools\validate-workflow-kernel-m4.ps1
.\tools\validate-r7-h1-contracts.ps1
.\tools\validate-r7-h6a-hotspot-front-chain.ps1
.\tools\validate-r7-l3-h2-visual-semantic.ps1
.\tools\validate-r7-l3-h3-direct-route.ps1
.\tools\validate-r8-h1-skill-context.ps1
.\tools\validate-r8-h3-router-human-gates.ps1
.\tools\validate-r8-h4-platform-context.ps1
.\tools\validate-r8-h5-ab-total-regression.ps1
.\tools\validate-p0-h2-runtime.ps1
.\tools\validate-p0-h3-fixtures.ps1
.\tools\validate-p0-h4-evidence.ps1
.\tools\validate-p0-h6-reliability.ps1
.\tools\validate-p0-h7-fixtures.ps1
.\tools\validate-p0-h7-v04-fixtures.ps1
.\tools\validate-r3-visual-budget.ps1
.\tools\validate-r3-visual-need.ps1
.\tools\validate-r3-visual-presentation.ps1
.\tools\validate-r5-h1-account-visual-identity.ps1
.\tools\validate-r5-h2-account-radar.ps1
.\tools\validate-r5-h3-radar-objects.ps1
.\tools\validate-r5-h4-feedback-ledger.ps1
.\tools\validate-r5-h5-account-startup.ps1
.\tools\validate-r5-h6-account-identity.ps1
.\tools\validate-r6-content-evidence.ps1
.\tools\validate-windows-runtime-helper.ps1
.\tools\validate-environment-preflight.ps1
.\tools\validate-archive-integrity.ps1
.\tools\invoke-windows-clean-room-matrix.ps1
```

`regression-suite.yaml` 会把三份 sample 串成一组只读回归 fixture：先跑样例结构检查，再跑 trace replay。它允许当前 alpha 阶段的声明型 warning，但不允许 blocker 或未登记 warning。

# Tools

> 状态：p3_p5_local_scripts_implemented  
> 主责：定义并承载 P3 最小脚本化检查入口。  
> 边界：当前已实现本地 build / validate 脚本和 validation-only GitHub Actions；不提供自动 commit、tag、push 或创建 GitHub Release 的发布 runner。

## Commands

| Command | Mode | Input | Human Report | Machine Report |
|---|---|---|---|---|
| `validate-public-release.ps1` | release | `public_release/`（checker 在临时隔离副本执行） | `releases/v{version}/release-check-report.md` | `releases/v{version}/release-check-report.json` |
| `validate-sample-run.ps1` | standard | `examples/{sample_id}/` | `check-report.md` | `sample-check-report.json` |
| `validate-field-schema.ps1` | standard / release | project root or `public_release/` | `field-schema-check-report.md` | `field-schema-check-report.json` |
| `validate-final-delivery-template.ps1` | standard | final-delivery template | console report | none |
| `validate-cover-composition.ps1` | standard | R3 session / dry-run root | console report | none |
| `validate-r3-visual-text.ps1` | standard | visual-text fixtures + R3 tutorial run + compiled contracts | `state/checks/r3-visual-text-check-report.md` | `state/checks/r3-visual-text-check-report.json` |
| `validate-r3-visual-budget.ps1` | standard / dev | R3 visual-budget fixtures；可选真实 plan JSON | console report | `state/checks/r3-visual-budget-report.json` |
| `validate-r3-visual-need.ps1` | standard / dev | R3-C71-C80 visual-need 正反 fixtures；可选真实 analysis JSON | console report | `state/checks/r3-visual-need-report.json` |
| `validate-r3-visual-presentation.ps1` | standard / dev / release | R3-C91-C124 画布、槽位、平台封面 rendition、适配与显式视觉审核 fixture | console report | `state/checks/r3-visual-presentation-report.json` |
| `validate-r5-h1-account-visual-identity.ps1` | standard / dev | R5-H1 账号视觉身份与栏目模板正反 fixture | console report | `state/checks/r5-h1-account-visual-identity-report.json` |
| `validate-r5-h2-account-radar.ps1` | standard / dev | R5-H2 账号策略、二手车优先、外溢阈值与扩词反馈 fixture | console report | `state/checks/r5-h2-account-radar-report.json` |
| `validate-r5-h3-radar-objects.ps1` | standard / dev | R5-H3 signal/event/candidate 与快照趋势正反 fixture | console report | `state/checks/r5-h3-radar-objects-report.json` |
| `validate-r5-h4-feedback-ledger.ps1` | standard / dev | R5-H4 词库选择反馈与偏好升降权 fixture | console report | `state/checks/r5-h4-feedback-ledger-report.json` |
| `AccountStartupCheck.ps1` | internal | R5-H5 历史兼容的按任务账号字段检查与快照决策 | internal result | 调用方指定的账号启动检查 JSON |
| `invoke-account-startup-check.ps1` | dev | 单账号启动请求；按任务输出补问或可继续的 session 快照决策 | console result | 调用方指定的账号启动检查 JSON |
| `validate-r5-h5-account-startup.ps1` | standard / dev | R5-H5 最多三问、任务相关阻断、风险口径与账号切换 fixture | console report | `state/checks/r5-h5-account-startup-report.json` |
| `AccountIdentityBinding.ps1` | internal | R5-H6 绑定摘要、根目录约束和资产身份校验共享逻辑 | internal result | 调用方指定的绑定 / 启动检查 JSON |
| `AccountStartupCheckV02.ps1` | internal | R5-H6 当前账号启动检查；先验证技术身份和绑定摘要，再执行按需补问 | internal result | 调用方指定的 v0.2 启动检查 JSON |
| `new-account-identity-binding.ps1` | dev | R5-H6 显式迁移 / 重建账号技术身份绑定与资产摘要 | console result | 账号私有 `account-identity-binding.v0.1.json` |
| `invoke-account-startup-check-v0.2.ps1` | dev | R5-H6 验证目录、技术身份、资产摘要和 session 快照后再补问 | console result | 调用方指定的 v0.2 启动检查 JSON |
| `validate-r5-h6-account-identity.ps1` | standard / dev | R5-H6 跨账号错绑、根目录逃逸、旧快照和迁移 fixture | console report | `state/checks/r5-h6-account-identity-report.json` |
| `invoke-r6-content-evidence.ps1` | dev / internal | R6 直供入口 / 证据 bundle 校验、证据锚点子资产物化与确定性证据 PIP render | console result | 调用方指定 annotation SVG / record 或 PIP SVG / sidecar |
| `invoke-r6-source-capture.ps1` | dev / private | 单一公开页面或显式本地 fixture；先落 attempt，再用 Edge 捕获并 reconcile | console result | session 内 capture record + PNG |
| `validate-r6-content-evidence.ps1` | standard / dev | R6 直供、R3 producer dispatch、证据分层正反 fixture与本地浏览器 smoke | console report | `state/checks/r6-content-evidence-report.json` |
| `invoke-r6-script-visual-contract.ps1` | dev / internal | R6/R3 bundle、review/decision，或 immutable revision + pointer 路径 | readiness / pointer commit result | current pointer 或无写入校验结果 |
| `validate-r6-script-visual-contract.ps1` | standard / release | R6 直供 baseline、结构、UTF-8 全文锚点、审查决策、视觉覆盖、数量与 pointer 的 34 个正反 fixture | console report | `state/checks/r6-script-visual-contract-report.json` |
| `validate-r7-h1-contracts.ps1` | standard / release | R7-H1 蓝图、节点 / 合同 / 动作注册表、task / submission、兼容矩阵和 16 个正反 fixture | `state/checks/r7-h1-contract-check-report.md` | `state/checks/r7-h1-contract-check-report.json` |
| `invoke-r7-maturity-evidence.ps1` | dev / internal | R7-L3 baseline、snapshot、observation、cohort 与 route/project evidence | console result | 调用方指定 JSON |
| `validate-r7-l3-h1-evidence.ps1` | dev / test | R7-L3-H1 脱敏证据 fixture、能力冻结、干预派生与三级晋级规则 | console report | `state/checks/r7-l3-h1-evidence-report.json` |
| `invoke-r7-visual-semantic.ps1` | dev / internal | H2 operation registry、Prompt 编译、asset/delivery review 终结与工作包校验 | console result | 调用方指定 JSON |
| `validate-r7-l3-h2-visual-semantic.ps1` | dev / test | 五段视觉语义、三来源、Prompt revision、reconcile、独立 review 与负例 fixture | console report | `state/checks/r7-l3-h2-visual-semantic.json` |
| `validate-r8-h1-skill-context.ps1` | dev / test | 28 个项目业务 Skill 的职责、主输入输出、node owner、入口行数 / SHA256、current / legacy 和一层条件 reference；含 11 个正反 mutation fixture | console report | `state/checks/r8-h1-skill-context-report.json` |
| `validate-r8-h2-hotspot-context.ps1` | dev / test | 热点 Skill current/legacy 隔离、三类条件 reference、legacy template asset、metadata 和 10 个确定性加载场景 | console report | `state/checks/r8-h2-hotspot-context-report.json` |
| `validate-r8-h3-router-human-gates.ps1` | dev / test | router 收缩、current node owner、直供/热点 v0.6 plan、final decision 条件字段与 deterministic apply | console report | `state/checks/r8-h3-router-human-gates.json` |
| `R8PlatformPackagingRuntime.ps1` | runtime helper | 校验账号快照目标平台非空 / 唯一 / 当前支持，并与一个 `platform_package` 的平台集合完全一致 | internal result | none |
| `validate-r8-h4-platform-context.ps1` | dev / test | 平台包装 current/legacy 隔离、四个平台条件 reference、模板 asset、metadata、runtime 接线及 7 个单平台 / 三平台 / 负例场景 | console report | `state/checks/r8-h4-platform-context-report.json` |
| `validate-r8-h5-ab-total-regression.ps1` | dev / test | 三个目标业务 Skill 的 baseline/candidate 合同 preflight、current 总回归、legacy replay、metadata / 字段 / 路由 / 文档门禁；不生成模型业务产物，actual route、扶跑、token 与人类盲评未执行时诚实保留未观察 | console report | `state/checks/r8/{eval_id}/` |
| `validate-r8-h5r1-contracts.ps1` | dev / test | H5 v0.2 九类对象 Schema、字段、兼容状态、9 个合法对象、9 个 Schema 负例与 12 个跨对象负例；明确 adapter / 独立执行未运行 | console report | `state/checks/r8-h5r1-contract-report.json` |
| `invoke-r8-h5r2-input-compile.ps1` | dev / test | 从 shared semantic case 确定性生成 baseline/candidate typed input、完整直接依赖 snapshot 与 immutable arm-input；不执行代理 | console result | `state/checks/r8/{evaluation_id}/{attempt_id}/` |
| `validate-r8-h5r2-input-runtime.ps1` | dev / test | H5R2 9 个案例、18 个 typed input、18 个 snapshot、18 个 arm-input、byte-stable replay 与 7 个负例的 PS5.1 专项门禁 | console report | `state/checks/r8-h5r2-input-runtime-report.json` |
| `invoke-r8-h5r3-evaluation.ps1` | dev / test | 消费已存在的 arm-input、snapshot、record request 与业务输出，独立重算 hash/Schema，生成 immutable arm result、machine verdict 与 comparability verdict；不执行 arm、不生成匿名包 | console result | `state/checks/r8/{evaluation_id}/{attempt_id}/` |
| `validate-r8-h5r3-evaluation-runtime.ps1` | dev / test | H5R3 18 个结果、9 个机器结论、9 个可比性结论、五种状态和 13 个 false-success 负例的 PS5.1 专项门禁 | console report | `state/checks/r8-h5r3-evaluation-runtime-report.json` |
| `invoke-r8-h5r4-prepare.ps1` | dev / test | 从已冻结的 semantic case、arm input 与 snapshot 生成两个 sealed instruction-isolated role 目录及 typed task；不执行模型 | console result | `state/checks/r8/{evaluation_id}/{attempt_id}/arm-execution/` |
| `invoke-r8-h5r4-finalize-arms.ps1` | dev / test | 消费两个独立 arm 的 typed submission，由 orchestrator 记录扶跑次数，重做 arm result / machine / comparability，并且只为 machine pass + comparable 结果生成私有随机映射和匿名 A/B 包 | console result | `state/checks/r8/{evaluation_id}/{attempt_id}/` |
| `validate-r8-h5r4-blind-runtime.ps1` | dev / test | H5R4 sealed task、typed submission、4 个 fixture 匿名对、mapping 隔离与 machine fail / noncomparable / tamper 三类 false-success 负例的 PS5.1 专项门禁 | console report | `state/checks/r8-h5r4-blind-runtime-report.json` |
| `new-r8-h5-blind-work-packages.ps1` | test | 从 H5 fixture 只投影同题 prompt、上下文和脱敏业务输入，生成彼此隔离的 baseline / candidate arm manifest；不含 expected 字段，不执行模型或代替人类盲评 | console result | `state/checks/r8/R8-H5-BLIND-20260717/` |
| `new-r8-h5-blind-review-packet.ps1` | test | 校验两个独立执行臂的 9 案输出合同与零扶跑声明，对 candidate 的节点 / reference / legacy / 选择合同做机器审计，持久化私有随机映射，并把 6 个正常 / 条件业务结果匿名化为 A/B 盲评包；3 个拒绝样例不混入偏好判断 | console result | `state/checks/r8/{eval_id}/{machine-audit.json,blind-review-packet.json,blind-review-packet.md}` |
| `new-r8-human-reply.ps1` | dev / runtime | 原样记录 Topic / final human gate 的 typed reply、稳定 digest 与时间，不解释业务动作 | typed reply | `inputs/{topic|final}-human-reply.json` |
| `invoke-r7-semantic-workflow.ps1` | standard | R7 initialize / prepare_task / submit / reconcile / projection rebuild，以及 H4 deterministic node dispatcher | session `intermediate/r7/` | session evidence |
| `validate-r7-h2-runtime.ps1` | standard / release | R7-F05 至 F08、selector / status / commit registry 与 pointer-last 恢复 | `state/checks/r7-h2-runtime-check-report.md` | `state/checks/r7-h2-runtime-check-report.json` |
| `new-r7-semantic-submission.ps1` | standard | 从 current task、注册 payload 和 result status 确定性构建 submission v0.2 | session `intermediate/r7/submissions/` | stdout |
| `validate-r7-h3-producer-adapters.ps1` | standard / release | 12 个 producer adapter、状态映射、F01 producer slice、F03 / F04 | `state/checks/r7-h3-producer-check-report.md` | `state/checks/r7-h3-producer-check-report.json` |
| `R7CandidateRuntime.ps1` | runtime helper | 按 blueprint 版本编译历史 candidate 或 current v0.9 final-asset candidate，并生成业务优先 HTML | session `intermediate/r7/` / `deliverables/` | session evidence |
| `R7H7DeliveryContract.ps1` | runtime helper | 校验 base / rendition / delivery asset、确定性 finalize、业务验收与平台卡去重 | session `intermediate/r7/` / `deliverables/` | session evidence |
| `invoke-r7-h7-finalize-assets.ps1` | runtime entry | 提交逐任务 finalize record，再原子推进 image asset delivery set | session `intermediate/r7/` | session evidence |
| `validate-r7-h7-delivery-contract.ps1` | dev checker | H7 最终素材、状态六层、业务主层和双层验收正反 fixture | `state/checks/r7-h7-*` | ignored report |
| `validate-r7-cli-exit-contract.ps1` | dev checker | 独立 Windows PowerShell 5.1 子进程验证 R7 CLI 结构化失败与非零退出码一致，防止调用方用被后续语句重置的 `$?` 误判 | `state/checks/r7-cli-exit-contract/` | ignored logs |
| `R7HotspotFreshnessRuntime.ps1` | runtime helper | 热点 freshness apply、selected-source revision、revalidation request 与两阶段 plan replan | session `intermediate/r7/` / `intermediate/p0/` | session evidence |
| `validate-r7-h4-candidate-runtime.ps1` | standard / release | 历史 replay、H7 final asset，以及 current v0.5（公开脱敏、无 provider）→ v0.9 candidate → 业务 HTML、source map/digest/event 和 review 阻断 | `state/checks/r7h4-report.md` | `state/checks/r7h4-report.json` |
| `R7HumanRevisionRuntime.ps1` | runtime helper | R7 v0.9 人工返修 request、最早 owning node、失效并集、plan revision 与 pointer-last | session `intermediate/r7/` / `intermediate/p0/` | session evidence |
| `validate-joint-visual-revision-contract.ps1` | standard / release | R6 v0.2 证据一致性、R3 来源唯一路由、R7 v0.9 返修重开的正反与真实文件系统 fixture | console report | `state/checks/joint-visual-revision-contract-report.json` |
| `validate-workflow-replay.ps1` | standard | sample or dry-run path | `workflow-replay-report.md` | `workflow-replay-report.json` |
| `invoke-workflow-runtime.ps1` | standard | P0 session plan | runtime / resume result | append-only event log + rendered HTML |
| `validate-p0-h1-contracts.ps1` | standard | P0-H1 schemas + compatibility matrix + positive/negative fixtures | `state/checks/p0-h1-contract-check-report.md` | `state/checks/p0-h1-contract-check-report.json` |
| `validate-p0-h2-runtime.ps1` | standard | P0-H2 typed candidate + v0.2 runtime fixture + v0.1 legacy fixture | console report | `state/checks/p0-h2-runtime-report.json` |
| `validate-p0-h3-fixtures.ps1` | standard | P0-F03 至 F19 独立失败 / 恢复 fixtures | console report | `state/checks/p0-h3-fixture-report.json` |
| `invoke-p0-evidence.ps1` | standard | P0 v0.2 session + evidence command JSON | command result | append-only events + lineage + projection / resume summary |
| `validate-p0-h4-evidence.ps1` | standard | P0-H4 脱敏 evidence fixture | console report | `state/checks/p0-h4-evidence-report.json` |
| `validate-windows-runtime-helper.ps1` | test / public | Windows runtime helper + H2 fixture | console report | `state/checks/windows-runtime-helper-report.json` |
| `invoke-environment-doctor.ps1` | dev / test / public | 显式 project / target root + Git index paths | environment preflight report | `state/checks/environment-doctor-report.json` |
| `validate-environment-preflight.ps1` | test / public | H3 脱敏正反 fixture | console report | `state/checks/environment-preflight-fixture-report.json` |
| `ArchiveIntegrity.ps1` | utility | payload root + required paths | 包内 archive manifest + verified ZIP | caller 指定路径 |
| `validate-archive-integrity.ps1` | test / public | H4 脱敏正反 fixture | console report | `state/checks/archive-integrity-fixture-report.json` |
| `invoke-windows-clean-room-case.ps1` | internal test | 单个 host/path/source canonical case | console result | case `result.json` |
| `invoke-windows-clean-room-matrix.ps1` | test / public / CI | H5 Windows PowerShell 5.1 six-case matrix | `state/checks/windows-clean-room-matrix-report.md` | `state/checks/windows-clean-room-matrix-report.json` |
| `invoke-windows-certification-probe.ps1` | test / public / CI | 显式 target root + 可选 required axis | console result | `state/checks/windows-certification-probe.json` |
| `validate-windows-certification.ps1` | test / public / CI | H7 环境轴分类 fixtures + 当前主机只读探针 | console report | `state/checks/windows-certification-fixture-report.json` |
| `invoke-p0-h5-regression.ps1` | dev / private | 已验证真实 baseline session + 全新 target session | H5 runtime result | 新 session 的 plan / events / lineage / typed input / HTML / resume |
| `validate-p0-h5-regression.ps1` | dev / private | H5 target session + baseline session | console report | target session 内 `h5-regression-check-report.json` |
| `validate-p0-h6-preflight.ps1` | dev / private | H5 session + 保存完整原始 prompt 的来源 session | H6 prompt / cost preflight | `state/checks/p0-h6-preflight-report.json` |
| `complete-p0-h6-regression.ps1` | dev / private | `self_test`，或 H6 visual need、完整 prompt 和已生成资产选择 | prepare / finalize 明确阶段结果 | session 内 metadata / generation records / candidate / manifest |
| `validate-p0-h6-regression.ps1` | dev / private | 完成 H6 runtime 的真实 session | 动态数量 H6 综合验收；当前真实 run 为 30 项 | session 内 `h6-regression-check-report.json` |
| `validate-p0-h6-reliability.ps1` | standard / release | 8 个脱敏 H6 防复发 fixtures | console report | `state/checks/p0-h6-reliability-report.json` |
| `validate-p0-h7-fixtures.ps1` | standard / release | v0.3 交付 revision 主链、幂等与负例 | console report | `state/checks/p0-h7-fixture-report.json` |
| `validate-p0-h7-delivery.ps1` | dev / test | 单个 H7 session 跨产物语义一致性 | console report | `state/checks/p0-h7-delivery-report.json` |
| `validate-p0-h7-v04-fixtures.ps1` | standard / release | v0.4 visual_insert、平台封面、表面预览、视觉 review、幂等与负例 | console report | `state/checks/p0-h7-v04-fixture-report.json` |
| `validate-p0-h7-v04-delivery.ps1` | dev / test | 单个 v0.4 session 的跨产物、review、scope 与响应式 HTML 只读验收 | console report | `state/checks/p0-h7-v04-delivery-report.json` |
| `validate-p0-r6-v05-fixtures.ps1` | standard / release | v0.5 结构卡、全文节点、脚本审查、视觉覆盖、readiness、renderer 与 commit marker 正反 fixture | console report | `state/checks/p0-r6-v05-fixtures.json` |
| `complete-p0-h7-delivery.ps1` | dev / test | 已通过 H7 语义门禁的 session | projection / resume / manifest 单调收口 | session 私有状态文件 |
| `validate-regression-suite.ps1` | standard | `examples/regression-suite.yaml` | `state/checks/regression-suite/regression-suite-report.md` | `state/checks/regression-suite/regression-suite-report.json` |
| `validate-ci-workflow.ps1` | standard / release | `.github/workflows/public-release-candidate-check.yml` | `ci-workflow-check-report.md` | `ci-workflow-check-report.json` |
| `validate-alpha-expression.ps1` | standard / release | README / INSTALL / samples | `alpha-expression-check-report.md` | `alpha-expression-check-report.json` |
| `validate-route-schema.ps1` | standard | `routes/workflow-routes.yaml` + `routes/run-control-profiles.yaml` + `routes/build-profiles.yaml` | `state/checks/route-schema-check-report.md` | `state/checks/route-schema-check-report.json` |
| `validate-doc-governance.ps1` | standard / release | 项目根、分区 README、知识文档链接 | console report | `state/checks/doc-governance-report.json` |
| `validate-public-entry-doc-review.ps1` | release | 当前树或公开候选包、入口文档复核合同 | console report + stale README negative self-test | `state/checks/public-entry-doc-review-report.json` |
| `validate-release-gate.ps1` | release-gate | public release candidate + Git state | `release-gate-report.md` | `release-gate-report.json` |
| `validate-gates.ps1` | standard | project root + gate_name + build_profile | `gate-check-report.md` | `gate-check-report.json` |
| `validate-build-profile.ps1` | standard | project root + profile | `build-profile-check-report.md` | `build-profile-check-report.json` |
| `YamlHelper.ps1` | utility | yaml file or text | none | none |
| `export-support-log.ps1` | support | `accounts/{account}/runs/{session_id}/` | `support-log-summary.md` | zip + sha256 |
| `build-public-release.ps1` | release | project root | `release-checklist.md` | `release-record.json` |

项目级运行 `validate-build-profile.ps1`、`validate-gates.ps1`、`validate-ci-workflow.ps1`、`validate-alpha-expression.ps1` 或 `validate-field-schema.ps1` 时，默认报告写入 `state/checks/`，不得在项目根目录生成检查报告。针对公开包或样例显式传入目标 / 报告路径时，报告跟随对应包或样例保存。

## Exit Codes

```text
0 pass
1 fail
2 blocked
3 tool_error
4 usage_error
```

## Result Semantics

Checker 结果必须区分“workflow 是否有问题”和“checker / sample / environment 是否有问题”。

`validate-gates.ps1` 不得对未知 gate 静默返回 pass。路由新增 gate 时，必须同步实现 gate handler 或由独立 checker 接管。

`environment_compatibility_gate` 先真实执行六格 matrix definition，再读取 `state/checks/` 中最新的 full matrix 报告；只有 PS5.1 六个 canonical case 全部符合预期、无网络调用且未修改系统配置才 pass。只有 definition 或缺 full 报告时为 `blocked`，不能把“路由里写了 gate”或旧绿灯当成本轮环境证据。`product_contract_compilation_gate` 与 `runtime_smoke_gate` 同时执行历史 R7-H1 和当前 R7-L3-H1 专项 checker，避免新产品合同只被独立命令验证、总门禁却仍沿用旧合同。

`validate-p0-h1-contracts.ps1` 只验证 P0 v0.2 机器合同，不执行 runtime v0.2、renderer v0.2、真实账号、图片 provider 或发布。它必须同时证明合法 fixture 被接受、非法 fixture 被拒绝；只跑 happy path 不算 H1 通过。`P0ContractHelper.ps1` 是 H2 runtime 复用的确定性校验函数库，不单独作为用户命令。

`validate-r7-h1-contracts.ps1` 只验证 R7-H1 合同底座：两条单篇 blueprint、18 个注册节点、合同生命周期、v0.5 对齐动作、typed task/submission、v0.1-v0.5 legacy replay 边界和 F12 未注册动作负例。它不执行 H2 revision / pointer / event / projection 提交，不生成 v0.6 candidate / HTML，不调用真实账号、浏览器、图片 provider 或发布；`pass` 不能表述为 R7 runtime 已自主完成。

`validate-r7-l3-h1-evidence.ps1` 在离线脱敏 sandbox 中实际执行 maturity baseline、run snapshot、session intervention derivation、cohort append、route/project recompute，共覆盖 16 个产品 fixture。H2 改动会进入同一 baseline digest，因此视觉合同变化会正确开启新基线。它不运行真实直供 / 热点 session、Image 2、网络、私有账号或发布；H1/H2 通过仍只证明离线编译，项目保持 L2.8。

`validate-r7-l3-h2-visual-semantic.ps1` 在 PowerShell 5.1 离线 sandbox 中执行五段工作包和确定性 Prompt / review runtime。它不接线真实直供或热点 blueprint，不调用 provider、网络、真实账号或发布；真实 route 激活分别属于 H3/H4。

`validate-r7-l3-h4-hotspot-route.ps1` 在 PowerShell 5.1 离线 sandbox 中执行 current 热点 v0.5 路由，验证账号策略到研究请求的 hash 绑定、外部等待同 task 续跑、事实更新/反转恢复、current 视觉五段接线和 scoped 视觉返修。它不联网、不调用 Image 2、不读取私有账号，也不证明 H5 真实认证或项目 L3。

`validate-r7-h2-runtime.ps1` 在隔离 fixture 中实际执行 task 准备和确定性提交，验证缺字段、输入摘要变化、完成态重复提交与中断 reconcile。它只证明 H2 状态提交层，不证明 producer 语义质量、candidate v0.6、HTML、viewport 或完整自主运行。

`validate-r7-h4-candidate-runtime.ps1` 在短路径隔离 session 中真实执行 candidate compiler 和 renderer，验证逐封面 review 绑定、current v0.5 到 v0.9 HTML 的机器产物独占。语义输入是公开脱敏 fixture，不等于语义质量或真实账号认证；它不执行浏览器 viewport、真实账号、provider、网络或发布。需要继续全链 fixture 时，sandbox 根目录必须保持短路径，不能把长 session ID 嵌套到深层 `state/checks` 后再写 submission。

`validate-r7-h5-viewport-autonomy.ps1` 使用 Node 的真实模块解析和浏览器启动验证 Playwright 能力，再执行桌面 / 移动 viewport、截图、false-pass、autonomy 与最终人工门禁 fixture。它不把 `playwright-core` 的固定 npm / pnpm 目录形状当能力，也不使用 Codex 私有版本化缓存作为项目依赖。普通内容运行缺浏览器时保持 `not_tested + ready_with_warnings`；模板、renderer 和公开发版仍要求真实 viewport 证据。热点研究 Skill 本身不依赖 Playwright。

`validate-p0-h2-runtime.ps1` 在 `state/checks/` 复制脱敏 fixture 后，真实执行 `compile_render_input` 和 `render_final_delivery`。它验证 readiness 由工具重算、输入无 `*_html`、HTML 无脚本 / 内联事件、运行证据折叠、render receipt digest 闭合、同输入跨目录输出一致、重复渲染不追加事件，并保留 v0.1 validate / resume 兼容；不执行真实账号、图片生成、外部 API 或发布。

`validate-p0-h3-fixtures.ps1` 逐目录读取 P0-F03 至 F19 的 plan、events、状态 / 产物证据和 expected result，实际判定等待、失败、兼容、幂等、事件冲突、orphan、完整性、外部结果未知、复用资格、并发、中断和取消语义。每条结果统一输出 `fixture_id / expected_state / actual_state / failure_category / resume_advice / fixture_result`。H3 只固化回归口径，不实现 H4 的 event writer、projection rebuild 或 reconciliation 命令。

`invoke-p0-evidence.ps1` 实现五个 P0-E02 命令：`create_session_plan`、`record_agent_result`、`record_human_choice`、`record_external_result`、`build_resume_summary`；并提供 `rebuild_projection`、`reconcile_orphan_artifact` 两个确定性维护操作。所有事实事件经 `P0EvidenceRuntime.ps1` 的单一 writer 写入，使用 idempotency、expected event tail、严格 sequence 和 append-only 规则。`record_external_result` 只登记已发生或明确未发生的外部动作，工具本身不联网。

`complete-p0-h6-regression.ps1` 不调用图片 provider；它只接收已经由 Codex 内置 Image 2 生成并完成选择的资产证据。`prepare` 补齐 metadata、generation record、H6 typed candidate、计划和事件；completed session 只能 `skipped_completed`。`validate-p0-h6-regression.ps1` 在编译、渲染、projection rebuild 和 resume summary 完成后只读验收并写自己的报告；随后 `finalize` 才允许写 completed manifest。成功仍为 `pass_with_warnings`，不证明自动发布、平台登录、传播效果或不可观察的当前运行模型档位。

`runtime_smoke_gate` 会解析项目 PowerShell，并实际执行 H6 `self_test` 与三分栏 overlay smoke。静态 parser 通过但入口函数无法运行，仍视为 gate fail。

P0 新运行使用 `typed_components_v0.5` 和 `final-delivery-template-v0.5`；v0.2-v0.4 只保留 replay / 原版复现。`validate-p0-r6-v05-fixtures.ps1` 真实执行 compile / render / idempotent reuse，并拒绝结构 / beat / readiness / coverage / provider 与数量错配；不读取真实账号、不调用图片 provider、不发布。v0.4 专项 checker 继续守住历史平台表面视觉合同。

`validate-p0-h4-evidence.ps1` 真实执行上述命令，验证 event writer 幂等 / 冲突 / 并发保护、Agent / 人类 / 外部登记、orphan reconciliation、projection lag / conflict / force rebuild、resume summary 和 H2 runtime 共用 writer；同时用真实子进程验证空格、中文、引号、空参数和尾随反斜杠的 argv 保真。H4 不读取真实账号，不调用真实图片 provider，不发布。

`WindowsRuntimeHelper.ps1` 是 Windows PowerShell 5.1 基线环境层：统一 UTF-8 无 BOM 机器文本 / JSON / append、UTF-8 BOM PowerShell 源码写入、纯 .NET SHA256、Windows argv 序列化、`Start-Process` 调用，以及 NUL 分隔并显式 UTF-8 解码的 Git 跟踪路径和 nonfatal Git root 探测。`validate-windows-runtime-helper.ps1` 在带空格中文目录真实回读字节与 argv，清空子进程 `PSModulePath` 验证 YAML fallback，断言真实中文 Git 路径，并动态检查 `tools/`、`skills/` 中所有含非 ASCII 字面量的 PowerShell 源码采用 UTF-8 BOM；同时阻断宿主默认 UTF-8 写法、哈希 cmdlet 自动加载依赖、静默模块安装和 native stderr 终止可选探测。PowerShell 7 不属于当前公开兼容性承诺。非 Git clean room 不虚构 Git 元数据，但 source matrix 会在复制前验证真实 Unicode index 路径。

`EnvironmentPreflight.ps1` 提供 Windows 路径段、allowed-root containment、reparse point、路径预算、同卷临时写入 / rename / cleanup、磁盘空间和只读环境事实函数。`invoke-environment-doctor.ps1` 是人类 / agent 入口；默认从脚本根定位项目，不依赖调用者 cwd，不修改注册表、execution policy 或 Git 配置。`validate-environment-preflight.ps1` 用正反 fixture 和外部 cwd 子进程验证，并由公开包 `P3REL-027` 阻断回归。

`ArchiveIntegrity.ps1` 为 public release 和 support log 统一生成包内 `archive-manifest.json`，记录规范化相对路径、大小、SHA256、数量和必需文件。它先写同目录临时候选 ZIP，再做防路径穿越 / 大小写碰撞的安全解压与逐文件复核，只有通过才原子替换正式 ZIP；无效候选不会删除上一份有效包。`validate-archive-integrity.ps1` 用缺文件、内容篡改、缺 manifest、zip-slip、大小写碰撞和 foreign cwd 支持日志 fixture 验证，并由公开包 `P3REL-028` 阻断回归。

`invoke-windows-clean-room-matrix.ps1` 读取版本化 6-case 定义，真实调度 Windows PowerShell 5.1 × short ASCII / 空格中文 / 超预算 × Git-index source / verified ZIP。正例在隔离根执行 runtime-helper 与 environment-preflight checker，ZIP 先核对内部 manifest；超预算负例必须得到 `blocked_preflight` 且不创建目标。`definition` 模式供公开包 `P3REL-029` 只读验证完整笛卡尔积，`full` 模式用于本地和 GitHub Actions。PowerShell 7 不属于当前公开兼容性承诺。

`invoke-windows-certification-probe.ps1` 只确认 target root / runner 是否真实命中扩展环境轴；`validate-windows-certification.ps1` 验证分类逻辑和 probe purity。probe pass 不等于兼容性 certified，同一 host/root/commit/candidate hash 仍必须完成 full matrix 和 public validator。完整合同由公开包 `P3REL-031` 阻断；full matrix 的 WorkRoot 必须短、唯一且为空，不自动递归清除旧 UNC / 深路径证据根。

`invoke-p0-h5-regression.ps1` 只在 dev/private 范围执行 Phase 1：把通过业务与视觉门禁的 baseline 内容和图片复制到全新 session，分配新 artifact ID，校验原图 hash 与旧 sidecar，生成新的复用 sidecar 和 lineage，再用 P0 v0.2 runtime 重建 plan、events、typed render input、最终 HTML、projection 与 resume。它拒绝覆盖已有 session，不调用图片 provider，不发布。`validate-p0-h5-regression.ps1` 复核内容语义 digest、9 个复制资产的来源闭环、7 个交付卡片、四个强制 warning、最终页面和 runtime 完成态；成功结果仍为 `pass_with_warnings`。

`R3VisualBudget.ps1` / `validate-r3-visual-budget.ps1` 只保留旧 visual-budget fixture 的 history-only compatibility，不再作为现行产品门禁。

`R3VisualNeed.ps1` 同时验证 v0.1 历史输入和 v0.2 当前输入：后者使用 `content_source_id / content_origin`，并把生成情境图派给 Image 2、来源证据图派给 `news-evidence-pip`。`validate-r3-visual-need.ps1` 继续覆盖 R3-C71 到 C80；`validate-r6-content-evidence.ps1` 追加直供入口和证据 producer dispatch / capture / renderer 正反门禁。

`invoke-r6-source-capture.ps1` 只做按需单页捕获，不登录、不越过付费墙、不批量采集。它在浏览器前持久化 attempt，完成后验证文件与 SHA256，重复调用先 reconcile。`invoke-r6-content-evidence.ps1` 先以 `materialize_evidence_annotation` 从不可变来源截图生成带父哈希的标注子资产并持久化 attempt / outcome，再校验证据 bundle、生成含“来源事实 / 账号解读”分层的 PIP SVG；它不调用 Image 2。`validate-r6-content-evidence.ps1` 使用本地合成网页真实执行 Edge capture、annotation 物化与 reconcile、重复调用和 renderer 幂等，不联网、不读取真实账号。

`validate-r7-h5a-direct-sequence.ps1` 验证 H5A 历史直供 blueprint v0.2 的 baseline draft -> semantic-only beat -> direct structure -> structure-bound beat 顺序、entry-specific route 闭合、adapter phase 约束、materialized-only structure lineage 和 payload-derived monotonic revision。它保留 v0.1 为历史合同缺陷，不读取真实账号、不调用 provider、不联网、不发布；公开包 `P3REL-050` 将该 checker 作为历史兼容 blocker。当前直供合同由后续 H3 checker 验证。

`validate-r7-h6a-hotspot-front-chain.ps1` 在 Windows PowerShell 5.1、离线、脱敏 fixture 中真实执行 hotspot research request -> research set -> deterministic topic panel -> immutable topic decision -> selected source -> Brief -> structure -> draft，并停在 structure-bound beat map 前。它覆盖 R7-F34 至 F80 中属于 H6A 的 31 个正反场景，不执行 H6B freshness / renderer v0.7，也不联网、调用图片 provider、登录或发布；公开包 `P3REL-051` 将该 checker 作为 blocker。

`validate-r7-h6b-freshness-delivery.ps1` 离线覆盖 H6B 的 17 个独立场景：freshness complete / unassessed、monitoring 与 semantic digest、replacement packet、selected-source revision、revalidation request、两阶段 plan revision、tagged source union、provider unavailable 等待和热点 v0.7 HTML 字段。它不联网、不调用 provider、不登录、不发布，也不替代 H6C 私有真实热点回归；公开包 `P3REL-052` 将其作为 blocker。

```text
pass：检查范围内没有 blocker，也没有需要强调的 warning。
pass_with_warnings：没有 blocker，但存在非阻断警告、旧样例债务、边界提醒或未测试范围。
fail：检查对象本身不满足规则，例如字段缺失、隐私泄漏、真实数据混入公开样例。
blocked：缺少必要输入或门禁未满足，不能继续判断。
tool_error：checker 自身解析、依赖、路径、异常处理或退出码有问题。
usage_error：调用参数错误。
not_tested：本轮没有执行该范围，不能写成 pass。
```

当 checker 失败时，先归因：

```text
workflow_defect
sample_fixture_defect
checker_defect
environment_defect
documentation_gap
not_tested
```

不得把 `tool_error` 当成 workflow 失败；也不得把 `pass_with_warnings` 简写成全量通过。

## Modes

```text
fast：字段门禁、合同同步、入口索引。
standard：fast + sample 行为、链接、图片资产。
release：standard + 隐私、密钥、本机路径、zip/hash、release_state。
```

## Rule

Scripts must follow `docs/reference/R1-R4只读checker执行规范.md` and `交接物字段词典.md`. A script failure is not the same as a workflow failure; use `exit_code=3` for checker errors.

Test / dry-run 报告建议落点：

```text
examples/{sample_id}/
docs/tutorials/{tutorial_or_sample}/checks/
state/checks/
releases/v{version}/
```

根目录只允许保留手动临时调试时的短期报告；收口前应迁入上述目录或删除重建。公开包和 Git 提交不得包含散落根目录测试报告。

`build-public-release.ps1` only creates a local release candidate:

构建器会从 Git index 复制显式允许的工具，并在归档前验证当前 v0.5 runtime / checker 依赖闭包。白名单漏文件会以 `public_runtime_dependency_closure_missing` 阻断，避免出现“工作树通过、公开包不可执行”的候选。

```text
public_release/
taoge-creative-workflow-0.1.0-alpha.4-public-release.zip
taoge-creative-workflow-0.1.0-alpha.4-public-release.zip.sha256
public_release/release-record.json
public_release/archive-manifest.json
```

It does not create a release commit, tag, remote, push, or GitHub Release.

## Examples

```powershell
.\tools\build-public-release.ps1
.\tools\validate-public-release.ps1 -TargetPath .\releases\v0.1.0-alpha.4\public_release
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-01-onboarding
.\tools\validate-field-schema.ps1 -TargetPath .\public_release -SchemaPath .\public_release\templates\schema\field-schema.v0.1.json
.\tools\validate-final-delivery-template.ps1
.\tools\validate-cover-composition.ps1
.\tools\validate-r3-visual-text.ps1
.\tools\validate-r3-visual-budget.ps1
.\tools\validate-r3-visual-need.ps1
.\tools\validate-windows-runtime-helper.ps1
.\tools\validate-environment-preflight.ps1
.\tools\validate-archive-integrity.ps1
.\tools\invoke-windows-clean-room-matrix.ps1
.\tools\validate-workflow-replay.ps1 -SamplePath .\examples\sample-02-single-content-run
.\tools\validate-regression-suite.ps1 -SuitePath .\examples\regression-suite.yaml
.\tools\validate-p0-h1-contracts.ps1
.\tools\validate-p0-h2-runtime.ps1
.\tools\validate-p0-h3-fixtures.ps1
.\tools\validate-p0-h4-evidence.ps1
.\tools\invoke-p0-h5-regression.ps1 -BaselineSession .\accounts\{account_slug}\runs\{verified_session_id} -TargetSession .\accounts\{account_slug}\runs\{new_session_id}
.\tools\validate-p0-h5-regression.ps1 -SessionPath .\accounts\{account_slug}\runs\{new_session_id} -BaselineSessionPath .\accounts\{account_slug}\runs\{verified_session_id}
.\tools\validate-p0-h6-preflight.ps1 -H5SessionPath .\accounts\{account_slug}\runs\{h5_session_id} -PromptSourceSessionPath .\accounts\{account_slug}\runs\{prompt_source_session_id}
.\tools\validate-r7-h5a-direct-sequence.ps1
.\tools\validate-r7-l3-h3-direct-route.ps1
.\tools\invoke-p0-evidence.ps1 -Session .\examples\p0-h4-evidence-fixture\P0H4FIXTURE-001 -Mode build_resume_summary
.\tools\validate-ci-workflow.ps1
.\tools\validate-alpha-expression.ps1
.\tools\validate-route-schema.ps1
.\tools\validate-release-gate.ps1
.\tools\validate-release-gate.ps1 -Version 0.1.0-alpha.4
.\tools\validate-gates.ps1
.\tools\validate-gates.ps1 -GateName state_consistency_gate
.\tools\validate-gates.ps1 -GateName run_control_gate -BuildProfile dev
.\tools\validate-gates.ps1 -GateName environment_compatibility_gate -BuildProfile public
.\tools\validate-build-profile.ps1 -Profile dev
.\tools\validate-build-profile.ps1 -Profile test
.\tools\validate-build-profile.ps1 -Profile public
.\tools\export-support-log.ps1
.\tools\export-support-log.ps1 -Account "sample-account"
.\tools\export-support-log.ps1 -Topic "sample topic" -IncludeContent
```
`invoke-r7-body-rendition.ps1` is the registered deterministic renderer for body-image `crop_fit_pad` and `platform_rendition`; it consumes a typed request, persists a started/outcome record and never uses the cover compositor.

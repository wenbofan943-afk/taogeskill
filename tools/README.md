# Tools

> 状态：p3_p5_local_scripts_implemented  
> 主责：定义并承载 P3 最小脚本化检查入口。  
> 边界：当前已实现本地 build / validate 脚本；尚未实现 CI，不自动 commit、tag、push 或创建 GitHub Release。

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
| `invoke-windows-clean-room-matrix.ps1` | test / public / CI | H5 12-case matrix | `state/checks/windows-clean-room-matrix-report.md` | `state/checks/windows-clean-room-matrix-report.json` |
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
| `complete-p0-h7-delivery.ps1` | dev / test | 已通过 H7 语义门禁的 session | projection / resume / manifest 单调收口 | session 私有状态文件 |
| `validate-regression-suite.ps1` | standard | `examples/regression-suite.yaml` | `state/checks/regression-suite/regression-suite-report.md` | `state/checks/regression-suite/regression-suite-report.json` |
| `validate-ci-workflow.ps1` | standard / release | `.github/workflows/public-release-candidate-check.yml` | `ci-workflow-check-report.md` | `ci-workflow-check-report.json` |
| `validate-alpha-expression.ps1` | standard / release | README / INSTALL / samples | `alpha-expression-check-report.md` | `alpha-expression-check-report.json` |
| `validate-route-schema.ps1` | standard | `routes/workflow-routes.yaml` | `state/checks/route-schema-check-report.md` | `state/checks/route-schema-check-report.json` |
| `validate-doc-governance.ps1` | standard / release | 项目根、分区 README、知识文档链接 | console report | `state/checks/doc-governance-report.json` |
| `validate-release-gate.ps1` | release-gate | public release candidate + Git state | `release-gate-report.md` | `release-gate-report.json` |
| `validate-gates.ps1` | standard | project root + gate_name | `gate-check-report.md` | `gate-check-report.json` |
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

`validate-p0-h1-contracts.ps1` 只验证 P0 v0.2 机器合同，不执行 runtime v0.2、renderer v0.2、真实账号、图片 provider 或发布。它必须同时证明合法 fixture 被接受、非法 fixture 被拒绝；只跑 happy path 不算 H1 通过。`P0ContractHelper.ps1` 是 H2 runtime 复用的确定性校验函数库，不单独作为用户命令。

`validate-p0-h2-runtime.ps1` 在 `state/checks/` 复制脱敏 fixture 后，真实执行 `compile_render_input` 和 `render_final_delivery`。它验证 readiness 由工具重算、输入无 `*_html`、HTML 无脚本 / 内联事件、运行证据折叠、render receipt digest 闭合、同输入跨目录输出一致、重复渲染不追加事件，并保留 v0.1 validate / resume 兼容；不执行真实账号、图片生成、外部 API 或发布。

`validate-p0-h3-fixtures.ps1` 逐目录读取 P0-F03 至 F19 的 plan、events、状态 / 产物证据和 expected result，实际判定等待、失败、兼容、幂等、事件冲突、orphan、完整性、外部结果未知、复用资格、并发、中断和取消语义。每条结果统一输出 `fixture_id / expected_state / actual_state / failure_category / resume_advice / fixture_result`。H3 只固化回归口径，不实现 H4 的 event writer、projection rebuild 或 reconciliation 命令。

`invoke-p0-evidence.ps1` 实现五个 P0-E02 命令：`create_session_plan`、`record_agent_result`、`record_human_choice`、`record_external_result`、`build_resume_summary`；并提供 `rebuild_projection`、`reconcile_orphan_artifact` 两个确定性维护操作。所有事实事件经 `P0EvidenceRuntime.ps1` 的单一 writer 写入，使用 idempotency、expected event tail、严格 sequence 和 append-only 规则。`record_external_result` 只登记已发生或明确未发生的外部动作，工具本身不联网。

`complete-p0-h6-regression.ps1` 不调用图片 provider；它只接收已经由 Codex 内置 Image 2 生成并完成选择的资产证据。`prepare` 补齐 metadata、generation record、H6 typed candidate、计划和事件；completed session 只能 `skipped_completed`。`validate-p0-h6-regression.ps1` 在编译、渲染、projection rebuild 和 resume summary 完成后只读验收并写自己的报告；随后 `finalize` 才允许写 completed manifest。成功仍为 `pass_with_warnings`，不证明自动发布、平台登录、传播效果或不可观察的当前运行模型档位。

`runtime_smoke_gate` 会解析项目 PowerShell，并实际执行 H6 `self_test` 与三分栏 overlay smoke。静态 parser 通过但入口函数无法运行，仍视为 gate fail。

P0-H7 使用 `typed_components_v0.3` 和 `final-delivery-template-v0.3`。`validate-p0-h7-fixtures.ps1` 真实执行 compile / render / semantic checker / idempotent reuse，并拒绝封面标题错配、无依据时长和重复来源；不读取真实账号、不调用图片 provider、不发布。`validate-p0-h7-delivery.ps1` 可对本地真实 session 做只读语义验收。

`validate-p0-h4-evidence.ps1` 真实执行上述命令，验证 event writer 幂等 / 冲突 / 并发保护、Agent / 人类 / 外部登记、orphan reconciliation、projection lag / conflict / force rebuild、resume summary 和 H2 runtime 共用 writer；同时用真实子进程验证空格、中文、引号、空参数和尾随反斜杠的 argv 保真。H4 不读取真实账号，不调用真实图片 provider，不发布。

`WindowsRuntimeHelper.ps1` 是 PowerShell 5.1 / 7 共享的环境基础层：统一 UTF-8 无 BOM 机器文本 / JSON / append、UTF-8 BOM PowerShell 源码写入、纯 .NET SHA256、Windows argv 序列化、`Start-Process` 调用，以及 NUL 分隔并显式 UTF-8 解码的 Git 跟踪路径和 nonfatal Git root 探测。`validate-windows-runtime-helper.ps1` 在带空格中文目录真实回读字节与 argv，清空子进程 `PSModulePath` 验证 YAML fallback，断言真实中文 Git 路径，并动态检查 `tools/`、`skills/` 中所有含非 ASCII 字面量的 PowerShell 源码采用 UTF-8 BOM；同时阻断宿主默认 UTF-8 写法、哈希 cmdlet 自动加载依赖、静默模块安装和 native stderr 终止可选探测。非 Git clean room 不虚构 Git 元数据，但 source matrix 会在复制前验证真实 Unicode index 路径。

`EnvironmentPreflight.ps1` 提供 Windows 路径段、allowed-root containment、reparse point、路径预算、同卷临时写入 / rename / cleanup、磁盘空间和只读环境事实函数。`invoke-environment-doctor.ps1` 是人类 / agent 入口；默认从脚本根定位项目，不依赖调用者 cwd，不修改注册表、execution policy 或 Git 配置。`validate-environment-preflight.ps1` 用正反 fixture 和外部 cwd 子进程验证，并由公开包 `P3REL-027` 阻断回归。

`ArchiveIntegrity.ps1` 为 public release 和 support log 统一生成包内 `archive-manifest.json`，记录规范化相对路径、大小、SHA256、数量和必需文件。它先写同目录临时候选 ZIP，再做防路径穿越 / 大小写碰撞的安全解压与逐文件复核，只有通过才原子替换正式 ZIP；无效候选不会删除上一份有效包。`validate-archive-integrity.ps1` 用缺文件、内容篡改、缺 manifest、zip-slip、大小写碰撞和 foreign cwd 支持日志 fixture 验证，并由公开包 `P3REL-028` 阻断回归。

`invoke-windows-clean-room-matrix.ps1` 读取版本化 12-case 定义，真实调度 Windows PowerShell 5.1 / PowerShell 7 × short ASCII / 空格中文 / 超预算 × Git-index source / verified ZIP。正例在隔离根执行 runtime-helper 与 environment-preflight checker，ZIP 先核对内部 manifest；超预算负例必须得到 `blocked_preflight` 且不创建目标。`definition` 模式供公开包 `P3REL-029` 只读验证完整笛卡尔积，`full` 模式用于本地和 GitHub Actions；缺宿主不能吞成 pass。

`invoke-windows-certification-probe.ps1` 只确认 target root / runner 是否真实命中扩展环境轴；`validate-windows-certification.ps1` 验证分类逻辑和 probe purity。probe pass 不等于兼容性 certified，同一 host/root/commit/candidate hash 仍必须完成 full matrix 和 public validator。完整合同由公开包 `P3REL-031` 阻断；full matrix 的 WorkRoot 必须短、唯一且为空，不自动递归清除旧 UNC / 深路径证据根。

`invoke-p0-h5-regression.ps1` 只在 dev/private 范围执行 Phase 1：把通过业务与视觉门禁的 baseline 内容和图片复制到全新 session，分配新 artifact ID，校验原图 hash 与旧 sidecar，生成新的复用 sidecar 和 lineage，再用 P0 v0.2 runtime 重建 plan、events、typed render input、最终 HTML、projection 与 resume。它拒绝覆盖已有 session，不调用图片 provider，不发布。`validate-p0-h5-regression.ps1` 复核内容语义 digest、9 个复制资产的来源闭环、7 个交付卡片、四个强制 warning、最终页面和 runtime 完成态；成功结果仍为 `pass_with_warnings`。

`R3VisualBudget.ps1` / `validate-r3-visual-budget.ps1` 只保留旧 visual-budget fixture 的 history-only compatibility，不再作为现行产品门禁。

`R3VisualNeed.ps1` 验证 `content_derived_unbounded`、0 到 N、受众 / 语义节点、generate / reject 映射、accepted task 完整性、零图理由、证据 / 情绪 / attention 风险、无 call limit，以及 analysis pass 后无人工确认自动接续 prompt 编译。`validate-r3-visual-need.ps1` 运行 17 个产品正反例和 8 个跨层 sink 检查，覆盖 R3-C71 到 C80；`validate-p0-h6-reliability.ps1` 覆盖 C81-C90，两者共同组成现行 `product_contract_compilation_gate`。

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
.\tools\invoke-p0-evidence.ps1 -Session .\examples\p0-h4-evidence-fixture\P0H4FIXTURE-001 -Mode build_resume_summary
.\tools\validate-ci-workflow.ps1
.\tools\validate-alpha-expression.ps1
.\tools\validate-route-schema.ps1
.\tools\validate-release-gate.ps1
.\tools\validate-release-gate.ps1 -Version 0.1.0-alpha.4
.\tools\validate-gates.ps1
.\tools\validate-gates.ps1 -GateName state_consistency_gate
.\tools\validate-build-profile.ps1 -Profile dev
.\tools\validate-build-profile.ps1 -Profile test
.\tools\validate-build-profile.ps1 -Profile public
.\tools\export-support-log.ps1
.\tools\export-support-log.ps1 -Account "sample-account"
.\tools\export-support-log.ps1 -Topic "sample topic" -IncludeContent
```

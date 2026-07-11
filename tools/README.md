# Tools

> 状态：p3_p5_local_scripts_implemented  
> 主责：定义并承载 P3 最小脚本化检查入口。  
> 边界：当前已实现本地 build / validate 脚本；尚未实现 CI，不自动 commit、tag、push 或创建 GitHub Release。

## Commands

| Command | Mode | Input | Human Report | Machine Report |
|---|---|---|---|---|
| `validate-public-release.ps1` | release | `public_release/` | `release-check-report.md` | `release-check-report.json` |
| `validate-sample-run.ps1` | standard | `examples/{sample_id}/` | `check-report.md` | `sample-check-report.json` |
| `validate-field-schema.ps1` | standard / release | project root or `public_release/` | `field-schema-check-report.md` | `field-schema-check-report.json` |
| `validate-final-delivery-template.ps1` | standard | final-delivery template | console report | none |
| `validate-cover-composition.ps1` | standard | R3 session / dry-run root | console report | none |
| `validate-r3-visual-text.ps1` | standard | visual-text fixtures + R3 tutorial run + compiled contracts | `state/checks/r3-visual-text-check-report.md` | `state/checks/r3-visual-text-check-report.json` |
| `validate-workflow-replay.ps1` | standard | sample or dry-run path | `workflow-replay-report.md` | `workflow-replay-report.json` |
| `validate-regression-suite.ps1` | standard | `examples/regression-suite.yaml` | `examples/regression-suite-report.md` | `examples/regression-suite-report.json` |
| `validate-ci-workflow.ps1` | standard / release | `.github/workflows/public-release-candidate-check.yml` | `ci-workflow-check-report.md` | `ci-workflow-check-report.json` |
| `validate-alpha-expression.ps1` | standard / release | README / INSTALL / samples | `alpha-expression-check-report.md` | `alpha-expression-check-report.json` |
| `validate-route-schema.ps1` | standard | `routes/workflow-routes.yaml` | `state/checks/route-schema-check-report.md` | `state/checks/route-schema-check-report.json` |
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
taoge-creative-workflow-0.1.0-alpha.2-public-release.zip
taoge-creative-workflow-0.1.0-alpha.2-public-release.zip.sha256
public_release/release-record.json
```

It does not create a release commit, tag, remote, push, or GitHub Release.

## Examples

```powershell
.\tools\build-public-release.ps1
.\tools\validate-public-release.ps1 -TargetPath .\releases\v0.1.0-alpha.2\public_release
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-01-onboarding
.\tools\validate-field-schema.ps1 -TargetPath .\public_release -SchemaPath .\public_release\templates\schema\field-schema.v0.1.json
.\tools\validate-final-delivery-template.ps1
.\tools\validate-cover-composition.ps1
.\tools\validate-r3-visual-text.ps1
.\tools\validate-workflow-replay.ps1 -SamplePath .\examples\sample-02-single-content-run
.\tools\validate-regression-suite.ps1 -SuitePath .\examples\regression-suite.yaml
.\tools\validate-ci-workflow.ps1
.\tools\validate-alpha-expression.ps1
.\tools\validate-route-schema.ps1
.\tools\validate-release-gate.ps1
.\tools\validate-release-gate.ps1 -Version 0.1.0-alpha.3
.\tools\validate-gates.ps1
.\tools\validate-gates.ps1 -GateName state_consistency_gate
.\tools\validate-build-profile.ps1 -Profile dev
.\tools\validate-build-profile.ps1 -Profile test
.\tools\validate-build-profile.ps1 -Profile public
.\tools\export-support-log.ps1
.\tools\export-support-log.ps1 -Account "sample-account"
.\tools\export-support-log.ps1 -Topic "sample topic" -IncludeContent
```

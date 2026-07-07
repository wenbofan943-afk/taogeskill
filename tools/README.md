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
| `validate-workflow-replay.ps1` | standard | sample or dry-run path | `workflow-replay-report.md` | `workflow-replay-report.json` |
| `validate-regression-suite.ps1` | standard | `examples/regression-suite.yaml` | `examples/regression-suite-report.md` | `examples/regression-suite-report.json` |
| `validate-ci-workflow.ps1` | standard / release | `.github/workflows/public-release-candidate-check.yml` | `ci-workflow-check-report.md` | `ci-workflow-check-report.json` |
| `validate-alpha-expression.ps1` | standard / release | README / INSTALL / samples | `alpha-expression-check-report.md` | `alpha-expression-check-report.json` |
| `validate-release-gate.ps1` | release-gate | public release candidate + Git state | `release-gate-report.md` | `release-gate-report.json` |
| `export-support-log.ps1` | support | `accounts/{account}/runs/{session_id}/` | `support-log-summary.md` | zip + sha256 |
| `build-public-release.ps1` | release | project root | `release-checklist.md` | `release-record.json` |

## Exit Codes

```text
0 pass
1 fail
2 blocked
3 tool_error
4 usage_error
```

## Modes

```text
fast：字段门禁、合同同步、入口索引。
standard：fast + sample 行为、链接、图片资产。
release：standard + 隐私、密钥、本机路径、zip/hash、release_state。
```

## Rule

Scripts must follow `docs/reference/R1-R4只读checker执行规范.md` and `交接物字段词典.md`. A script failure is not the same as a workflow failure; use `exit_code=3` for checker errors.

`build-public-release.ps1` only creates a local release candidate:

```text
public_release/
taoge-creative-workflow-0.1.0-alpha.1-public-release.zip
taoge-creative-workflow-0.1.0-alpha.1-public-release.zip.sha256
public_release/release-record.json
```

It does not create a release commit, tag, remote, push, or GitHub Release.

## Examples

```powershell
.\tools\build-public-release.ps1
.\tools\validate-public-release.ps1 -TargetPath .\releases\v0.1.0-alpha.1\public_release
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-01-onboarding
.\tools\validate-field-schema.ps1 -TargetPath .\public_release -SchemaPath .\public_release\templates\schema\field-schema.v0.1.json
.\tools\validate-final-delivery-template.ps1
.\tools\validate-workflow-replay.ps1 -SamplePath .\examples\sample-02-single-content-run
.\tools\validate-regression-suite.ps1 -SuitePath .\examples\regression-suite.yaml
.\tools\validate-ci-workflow.ps1
.\tools\validate-alpha-expression.ps1
.\tools\validate-release-gate.ps1
.\tools\export-support-log.ps1
.\tools\export-support-log.ps1 -Account "sample-account"
.\tools\export-support-log.ps1 -Topic "sample topic" -IncludeContent
```

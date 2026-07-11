# Install

> 状态：published_alpha_instruction  
> 适用：GitHub 公开 alpha 预发行包或线下测试包。  
> 边界：本项目是内容工作流 skill 集，不是平台发布工具。
> Alpha 预发行提醒：`0.1.0-alpha.2` 已发布为 GitHub 预发行版本，但不包含生产 runner，也不代表真实账号生产效果已验收。请先跑 `examples/` 和只读 checker，再决定是否用于私有账号试验。

## Version

```text
0.1.0-alpha.2
```

## Requirements

```text
Codex or another AI environment that can read local files.
Markdown readable editor.
Optional: image generation capability for direct picture-in-picture assets.
```

## Install From Zip

1. 解压 `taoge-creative-workflow-0.1.0-alpha.2-public-release.zip`。
2. 打开解压后的项目根目录。
3. 先读 `README.md`、`AGENTS.md`、`PROJECT_MAP.md`。
4. 如果根目录没有 `工作流状态记录.md`，让 AI 按 `templates/state/工作流状态记录.template.md` 初始化本地状态；该文件不得提交到 Git。
5. 用 `examples/` 里的三个样例试跑，不要直接改真实账号。
6. 如要验证包是否干净，运行或交给 AI 执行 `tools/validate-public-release.ps1`。

## Start Phrase

Open the project root and say:

```text
使用涛哥创作工作流，帮我做一条内容。
```

If no account exists, the workflow should guide you to create one with short questions.

## Verify

```text
tools/validate-public-release.ps1 -TargetPath .
tools/validate-sample-run.ps1 -SamplePath examples/sample-01-onboarding
tools/validate-sample-run.ps1 -SamplePath examples/sample-02-single-content-run
tools/validate-sample-run.ps1 -SamplePath examples/sample-03-final-review-revision
tools/validate-regression-suite.ps1 -SuitePath examples/regression-suite.yaml
tools/validate-ci-workflow.ps1
```

校验通过只表示公开包结构、隐私、链接、样例字段和报告口径可检查；真实账号生产效果仍需要人工试跑和反馈日志确认。

## What It Does Not Install

```text
No platform login.
No publishing API.
No external image API.
No API key storage.
No client or server service.
```

## Image Capability

```text
Codex environment with image generation: workflow may generate picture-in-picture assets directly.
Non-Codex or no image capability: workflow should deliver unified prompts and insertion positions.
External image APIs such as Seedream are not bundled in this release.
```

## Send Feedback

If the workflow feels confusing or broken, say this to the agent inside the project:

```text
导出反馈日志包。
```

The workflow should create a zip under `support-logs/`. By default it exports logs only, not full scripts, final HTML, generated images, or private account snapshots.

For alpha trial communication, see `CONTACT.md`.


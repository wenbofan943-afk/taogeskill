# Install

> 状态：alpha4_local_candidate_instruction
> 适用：GitHub 公开 alpha 预发行包或线下测试包。  
> 边界：本项目是内容工作流 skill 集，不是平台发布工具。
> Alpha 预发行提醒：`0.1.0-alpha.4` 当前是本地 GitHub 预发行版本候选，尚未 tag、push 或发布 Release；它不包含生产 runner，也不代表真实账号生产效果已验收。请先跑 `examples/` 和只读 checker，再决定是否用于私有账号试验。

Windows 支持口径：PowerShell 7 为推荐宿主；Windows PowerShell 5.1 保留短路径兼容档。两套宿主均已完成 short ASCII、空格中文、Git-index source 与 verified ZIP 正例；超出 259 字符传统目标预算时必须在写入前阻断。安装根建议不超过 90 字符。归档成功必须同时通过包内 manifest、必需文件、数量、大小和 SHA256 复核，不能只看解压命令退出码。完整证据见 `docs/reference/Windows环境兼容性支持矩阵.md`。

## Version

```text
0.1.0-alpha.4
```

## Requirements

```text
Codex or another AI environment that can read local files.
Markdown readable editor.
Optional: image generation capability for direct picture-in-picture assets.
```

## Install From Zip

1. 只从明确标记 `v0.1.0-alpha.4` 的可信 Release / 候选交付处取得 `taoge-creative-workflow-0.1.0-alpha.4-public-release.zip` 和同名 `.sha256`；本地候选尚未发布时不要在 GitHub 假定该资产存在。
2. 校验外层 ZIP SHA256，再解压到本地；安装根完整路径建议不超过 90 个字符。空格和中文受支持，但仍必须满足 259 字符目标预算。
3. 打开解压后的项目根目录。
4. 先读 `README.md`、`AGENTS.md`、`PROJECT_MAP.md` 和 `docs/reference/Windows环境兼容性支持矩阵.md`。
5. 如果根目录没有 `工作流状态记录.md`，让 AI 按 `templates/state/工作流状态记录.template.md` 初始化本地状态；该文件不得提交到 Git。
6. 用 `examples/` 里的三个样例试跑，不要直接改真实账号。
7. 运行 environment doctor 和只读 public validator；发现路径超预算、manifest 不一致或缺文件时停止，不要靠重试或修改全局系统设置绕过。

如果脚本带有下载标记并被 `RemoteSigned` 阻断，应先确认 zip 来源与 SHA256，再只对已确认可信的解压目录使用 `Unblock-File`；不要为本项目修改系统级或全局 execution policy。网络盘、OneDrive 同步目录和企业 Group Policy 主机当前未做专项认证。

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
tools/invoke-environment-doctor.ps1
tools/validate-windows-runtime-helper.ps1
tools/validate-environment-preflight.ps1
tools/validate-archive-integrity.ps1
tools/invoke-windows-clean-room-matrix.ps1 -Mode definition
```

`definition` 模式只证明 12-case 矩阵定义完整；完整 `full` matrix 需要 Git source checkout 和两套 PowerShell 宿主，由维护者或 CI 执行。校验通过只表示公开包结构、隐私、链接、样例字段和报告口径可检查；真实账号生产效果仍需要人工试跑和反馈日志确认。

当前未专项认证：网络盘、OneDrive 同步根、大小写敏感 NTFS、企业 Group Policy、Windows ARM64、Windows Server 和非 NTFS 文件系统。不得把当前 NTFS / AMD64 结果外推为这些环境已通过。

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


# Windows 环境兼容性支持矩阵

> 适用版本：`0.1.0-alpha.4` GitHub alpha 预发行
> 状态：`h7_hosted_server_arm64_certified_github_prerelease_published`
> 证据日期：2026-07-13
> 边界：这是当前实际验证范围，不是对所有 Windows 机器的泛化承诺。

## 1. 用户先看结论

| 项目 | 当前口径 |
|---|---|
| 推荐宿主 | PowerShell 7；本轮实测 7.6.3 |
| 兼容宿主 | Windows PowerShell 5.1 短路径档；本轮实测 5.1.26100.8737 |
| 安装根 | 建议完整路径不超过 90 字符 |
| 空格 / 中文 | 在路径预算内已通过 source 与 ZIP clean room |
| 传统目标路径预算 | 最长目标超过 259 字符时，必须在写入 / 清空 / 解压前阻断 |
| 文件系统 | 本轮实测 NTFS |
| 架构 | 本轮实测 AMD64 |
| 长路径注册表 | 当前观察 `LongPathsEnabled=0`；测试未修改注册表 |
| 联网 / 模块安装 | checker 使用 `-NoProfile`、离线 fallback；不静默安装模块 |

如果 doctor 报路径超预算、root escape、reparse point、临时区不可写、磁盘不足或 archive manifest 不一致，应停止当前操作并按错误修正路径 / 包；不要修改全局 execution policy、Group Policy、注册表或用户全局 Git 来制造通过。

## 2. 12-case 机器矩阵

机器真源：`examples/windows-clean-room-matrix/matrix.json`。执行入口：`tools/invoke-windows-clean-room-matrix.ps1 -Mode full`。

| 宿主 | 路径 | Git-index source | Verified ZIP |
|---|---|---|---|
| Windows PowerShell 5.1 | short ASCII | pass | pass |
| Windows PowerShell 5.1 | 空格中文 | pass | pass |
| Windows PowerShell 5.1 | over budget | blocked_preflight（符合预期） | blocked_preflight（符合预期） |
| PowerShell 7.6.3 | short ASCII | pass | pass |
| PowerShell 7.6.3 | 空格中文 | pass | pass |
| PowerShell 7.6.3 | over budget | blocked_preflight（符合预期） | blocked_preflight（符合预期） |

H5 本地 full matrix：12/12 符合预期，fail=0，not_tested=0。8 个正例都运行 runtime-helper 和 environment-preflight；ZIP 正例还验证包内相对路径、必需文件、count、size 与 SHA256。4 个超预算 case 没有创建目标目录。

## 3. 当前实测机器事实

```yaml
os_description_observed: Microsoft Windows NT 10.0.26200.0
windows_edition_observed: Professional
process_architecture_observed: AMD64
filesystem_observed: NTFS
windows_powershell_observed: 5.1.26100.8737
powershell_7_observed: 7.6.3
long_paths_enabled_observed: 0
source_index_file_count_h5: 587
verified_zip_entry_count_h5_including_manifest: 533
system_configuration_mutated: false
network_called: false
```

这些值只说明本轮证据来自该配置。不能据此宣称其他 Windows build、ARM64、Server 或其他文件系统已经通过。

## 4. 归档与安装完整性

`0.1.0-alpha.4` 候选要求：

```text
public release / support log 都带 archive-manifest.json。
manifest 记录规范化相对路径、文件大小、SHA256、文件总数和必需文件。
ZIP 先生成临时候选，再安全解压验证；验证通过后才替换正式 ZIP。
拒绝 zip-slip、Windows 非法文件名、大小写碰撞、缺文件、内容篡改和 manifest 缺失。
外层 .sha256 与内部 manifest 是两层证据，不能互相替代。
```

## 5. 扩展环境认证状态

环境探针本身不算兼容性通过；必须在同一 host/root/commit/candidate hash 上继续跑 full matrix 与 public validator。

| 轴 | 当前状态 | 真实证据 / 阻断 |
|---|---|---|
| network share | `certified_limited_loopback_only` | `\\localhost\D$` 真实 SMB/UNC，PS5.1/7 × source/ZIP × 路径矩阵 12/12；不外推远程 NAS、凭据变化、断网重连 |
| OneDrive / 同步目录 | `blocked_external_infrastructure` | 当前主机无 OneDrive root，需要 self-hosted OneDrive runner |
| case-sensitive NTFS | `blocked_external_infrastructure` | 当前根为 case-insensitive，当前进程非管理员；不修改目录 flag 制造通过 |
| enterprise Group Policy | `blocked_external_infrastructure` | 当前主机是 WORKGROUP，MachinePolicy/UserPolicy 均 Undefined |
| Windows ARM64 | `certified_github_hosted` | `windows-11-arm` 在 run `29201682178` 对 commit `d913000…` 完成环境 probe、PS5.1/7 full matrix 和公开包 validator |
| Windows Server | `certified_github_hosted` | `windows-2022` / `windows-2025` 在同一 run、同一 commit 完成环境 probe、PS5.1/7 full matrix 和公开包 validator |
| non-NTFS filesystem | `blocked_external_infrastructure` | 当前 C:/D: 都是 NTFS，需要真实 non-NTFS self-hosted root |

MOTW / `RemoteSigned` 属于机器安全策略差异。确认 ZIP 来源和 SHA256 后，可以只对可信解压目录处理下载标记；不得为本项目弱化全局安全策略。

## 6. 证据与命令

```powershell
tools/invoke-environment-doctor.ps1
tools/validate-windows-runtime-helper.ps1
tools/validate-environment-preflight.ps1
tools/validate-archive-integrity.ps1
tools/invoke-windows-clean-room-matrix.ps1 -Mode full
tools/validate-public-release.ps1 -TargetPath <public_release> -ZipPath <zip> -Sha256Path <sha256>
```

本地动态报告写入 `state/checks/`，不进入 Git 或公开包。最终发布 commit `a7bc276…` 的 GitHub Actions run `29206932433` 已在 Server 2022/2025 与 Windows 11 ARM64 上完成全部 required jobs；不能用更早临时分支的 green run 替代该证据。

## 7. H6 候选复测

```yaml
candidate_version: 0.1.0-alpha.4
candidate_retest_status: published_after_clean_head_rebuild
clean_room_matrix: 12/12_pass
public_validator_windows_powershell_5_1: pass
public_validator_powershell_7_6_3: pass
release_gate: github_release_published
github_tag_created: true
github_release_created: true
remote_actions_run: 29206932433_completed_success
```

候选复测同时要求 checker purity：公开包目录在验证前后必须与 `archive-manifest.json` 保持同一 count / size / SHA256；报告写到版本目录或 `state/checks/`，fixture 只在临时隔离副本运行。仅有 validator exit code=0、但候选目录出现 manifest 外文件时，不得判定 release ready。

## 8. H7 loopback SMB 与远端 runner 编译

```yaml
certification_contract: environment_observation_plus_same_host_root_commit_candidate_full_validation
loopback_smb_unc:
  root: \\localhost\D$\...\state\checks\s7a
  windows_powershell_5_1: pass
  powershell_7_6_3: pass
  source_and_zip: pass
  clean_room_matrix: 12/12_pass
  scope_limit: loopback_only_not_general_remote_share
github_hosted_jobs:
  windows_server_2022: completed_success
  windows_server_2025: completed_success
  windows_11_arm64: completed_success
certification_run:
  id: 29201682178
  head_sha: d91300073835ae3ccfdbd1a56f18f8a066096b5c
  required_jobs: 4
  result: completed_success
diagnostic_runs:
  - 29200062878
  - 29200531310
diagnosed_root_causes:
  - console_decoded_unicode_git_paths_on_english_windows_runner
  - utf8_without_bom_ps51_script_source_with_non_ascii_literals
  - native_git_stderr_terminating_non_git_probe_under_ps51_erroraction_stop
system_configuration_mutated: false
```

认证只覆盖 GitHub 当次 hosted runner image、仓库候选和验证步骤，不外推到任意第三方 ARM64 设备、私有 Windows Server、远程 NAS、企业策略或非 NTFS 文件系统。验证发生在临时分支；远端 main、tag 与 Release 未改变。

## 9. 平台事实来源

- GitHub hosted runner 官方表列出 `windows-2022`、`windows-2025` x64，以及公开预览的 `windows-11-arm` ARM64：https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- GitHub runner-images 官方仓库说明 `windows-latest` 会迁移，固定环境证据应使用显式版本标签：https://github.com/actions/runner-images
- Microsoft 说明 NTFS 大小写敏感是目录级属性，修改通常需要提升权限，且可能破坏假设大小写不敏感的 Windows 应用：https://learn.microsoft.com/en-us/windows/wsl/case-sensitivity

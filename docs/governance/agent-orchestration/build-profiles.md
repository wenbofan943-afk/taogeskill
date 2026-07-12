# Build Profiles

> 状态：构建与数据边界规则
> 主责：区分开发、测试和公开生产包，避免真实账号数据、测试夹具、发版资产互相串台。
> 边界：本文件定义规则；脚本验证已实现，见 `tools/validate-build-profile.ps1`。

---

## 三类 profile

| profile | 目的 | 允许读取 | 允许输出 | 禁止 | 验证脚本 |
|---|---|---|---|---|---|
| `dev` | 本地真实生产和维护 | `accounts/`、`indexes/`、`docs/`、`skills/`、`tools/`、`objects/` | `accounts/{账号}/runs/{session_id}/`、`support-logs/`、本地检查报告 | 直接公开发布 | `tools/validate-build-profile.ps1 -Profile dev` |
| `test` | 脱敏 dry-run / regression | `examples/`、`docs/tutorials/`、`templates/`、`tools/`、脱敏 `docs/` | sample reports、dry-run reports、临时 checker 报告 | 读取真实 `accounts/`、真实 `indexes/` | `tools/validate-build-profile.ps1 -Profile test` |
| `public` | GitHub Release / 对外分发 | `README.md`、`AGENTS.md`、`PROJECT_MAP.md`、`docs/`、`skills/`、`templates/`、`examples/`、`tools/`、社区健康文件 | `releases/v{version}/public_release`、zip、sha256、release reports | 真实账号、真实 run、真实索引、本机路径、外部资料缓存 | `tools/validate-build-profile.ps1 -Profile public` |

## Profile 选择

```text
用户说“给某账号做内容” -> dev
用户说“跑 sample / dry-run / 测试” -> test
用户说“发版 / GitHub / 构建包” -> public
用户说“导出反馈日志” -> dev，但输出 support log，默认不含内容细节
```

如果任务从 `dev` 切到 `public`，必须重新执行公开边界检查，不能复用 dev 结论。

## Test Profile 判定边界

`test` profile 的核心目标是“只用脱敏样例验证 workflow / checker / contract”，不是要求本地工作区不存在真实生产目录。

```text
accounts/ 存在 -> warning，不自动 fail。
indexes/ 存在 -> warning，不自动 fail。
support-logs/ 存在 -> warning，不自动 fail。
读取真实 accounts/ 内容 -> fail。
读取真实 indexes/ 内容 -> fail。
把真实账号 / 真实 run 写进 examples/ 或 docs/tutorials/ -> fail。
把 test 报告散落到根目录 -> warning；如进入公开包则 fail。
```

测试报告必须说明：

```text
real_account_data_read: true / false
real_index_data_read: true / false
real_image_generation_run: true / false
external_api_called: true / false
public_release_run: true / false
```

涉及 PowerShell、路径、构建、压缩包或安装时，还必须说明：

```text
powershell_host / version
os_build / edition / architecture / filesystem
project_root_length / longest_target_length / whitespace / unicode
caller_cwd_independent / target_writable / temp_same_volume / free_space_checked
source_clone_tested / release_zip_tested
profile_loaded / optional_module_present / network_used
archive_manifest_checked / extracted_file_count / required_files_checked
execution_policy / MOTW / LongPathsEnabled（只读）
每个能力轴的 pass / fail / not_tested / not_certified
```

`test` profile 不得为制造通过而执行 `Install-Module`、修改注册表、Group Policy、全局 execution policy 或用户全局 Git 配置。允许在隔离临时目录、当前进程或仓库级作用域设置可恢复的测试参数，但必须记录原值、作用域和恢复结果。

如果只是本地存在私有目录但测试没有读取，只能写 `pass_with_warnings` 或 `pass` 加 boundary warning，不能说 workflow 失败。

## Public 构建硬门禁

`public` profile 必须满足：

```text
1. 不复制 root accounts/。
2. 不复制 root indexes/。
3. 不复制 support-logs/。
4. 不复制 offline_tester_packages/。
5. 不复制 外部资料/ 缓存。
6. 不复制 releases/ 历史输出到包内。
7. 不复制 `state/checks/` 本地维护报告和冒烟资产。
8. 不保留盘符工作区、用户主目录、`file://` 等本机绝对路径。
9. public release zip 和 GitHub Source code zip 分别审计。
10. GitHub Actions 最新 run 必须 success。
11. 已发布 tag 不因 main 后续修复而静默移动。
12. 发布包有 archive manifest，并在全新解压目录核对 required files、数量和 SHA256；压缩 / 解压退出 0 不能单独判 pass。
13. `invoke-windows-clean-room-matrix.ps1 -Mode full` 的 12 个 5.1/7 × path × source/zip case 全部符合预期；definition-only 只证明矩阵完整，不能替代执行证据。未覆盖轴进入 known limits，不得被 overall pass 吞并。
14. build preflight 在清空旧候选前验证路径预算、保留名、root / reparse containment、cwd、同卷 temp rename 与磁盘空间；Git top-level 不等于 ProjectRoot 时不得借父仓 index。
```

公开包校验过程中现场生成的报告只属于该候选包的审计证据，不得反向混入源码或下一次构建输入。

## 测试夹具边界

当前项目还没有独立 `test-fixtures/`。过渡期规则：

```text
examples/        对外最小样例
docs/tutorials/  可读教程和脱敏 dry-run 样本
tools/           检查器和构建脚本
```

后续如果测试样例继续膨胀，优先新增：

```text
test-fixtures/
```

并从 `docs/tutorials/` 迁出机器专用 fixtures，避免教程目录变成测试垃圾场。

## Sample 同步规则

产品字段、skill contract、manifest、最终交付模板或 execution trace 任一发生变化后，测试样例必须同步升级：

```text
manifest.yaml
expected-artifacts.md
intermediate/00-execution-trace.md
关键 intermediate 交接物
deliverables/
assets/
sample check report
workflow replay report
```

如果 replay 失败，先判断是：

```text
sample_behind_contract：样例旧于字段 / contract。
workflow_contract_gap：skill / contract 自身缺字段。
checker_bug：检查器解析或判断错误。
environment_gap：路径、profile、权限或依赖问题。
```

不得把旧样例未升级直接定性为 workflow 本体失败。

# M2 direct shadow runtime fixtures

本目录是 `ARCH-20260718-002` 的 M2 公开、脱敏、离线回归夹具。

它验证同一份直供输入在 `kernel_v1_shadow` 中形成隔离 artifact、append-only event、projection rebuild、`waiting_human` stop reason 和 final HTML，并与冻结的 `legacy_r7` 归一化观测比较。

边界：

- legacy R7 仍是 current runtime；
- M2 不执行真实账号、不调用网络或图片 provider；
- component payload 来自已经通过各自合同校验的 typed result envelope，M2 只编译控制面；
- M2 只覆盖正向路径到最终人工等待；中途 wait / revision / blocked 必须在写 shadow 前 fail-closed，恢复分支留给后续 conformance；
- `legacy_observation` 是按 current legacy v0.6 合同冻结的公开 fixture 基线，不由运行时自动改写；它明确标记 `real_legacy_runtime_executed=false`，不得冒充真实 legacy session 双跑；
- 正例验证 replay 复用和 projection byte stability；
- 负例必须阻止 contract break、越界写入、伪 parity 和被篡改 artifact；
- 通过本夹具不等于 L3 runtime certification，也不授权 M3/M4。

运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-workflow-kernel-m2.ps1
```

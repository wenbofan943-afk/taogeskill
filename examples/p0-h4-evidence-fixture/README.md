# P0-H4 Evidence Runtime Fixture

该脱敏 fixture 真实执行：

- `create_session_plan`
- `record_agent_result`
- `record_human_choice`
- `record_external_result`
- `build_resume_summary`
- `rebuild_projection`
- `reconcile_orphan_artifact`

同时验证统一 event writer 的幂等复用、幂等冲突、expected tail 并发保护、状态投影冲突、孤儿产物采用、外部结果未知和 H2 renderer 共用 writer。

`process-arguments.json` 提供 Windows 子进程参数保真 fixture，覆盖空格、中文、内嵌引号、空字符串与尾随反斜杠。checker 会把 probe 脚本和输出放进带空格中文目录，并真实启动同版本 PowerShell 子进程回读参数。

运行：

```powershell
.\tools\validate-p0-h4-evidence.ps1
```

fixture 只包含脱敏文本和合成 SVG；工具不会联网、调用图片模型或发布。

checker 复制 fixture 后会按目标文件的实际字节重新填写 orphan `expected_sha256`，避免 Git 的 LF / CRLF checkout 差异被误判为 workflow 缺陷；reconciliation 仍会严格校验运行副本的真实 digest。

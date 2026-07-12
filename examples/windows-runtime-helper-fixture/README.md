# Windows Runtime Helper Fixture

该 fixture 验证 R4-WIN-H2 的共享 Windows runtime helper：

- UTF-8 无 BOM 文本、行、JSON 与 append。
- 空格、中文、引号、空参数和尾随反斜杠的真实子进程 argv。
- `PSModulePath` 为空时 YAML fallback 仍可读，且 checker 不联网、不安装模块。
- `tools/` 不再出现 `Set/Add-Content -Encoding UTF8` 或 `Install-Module`。

运行：

```powershell
.\tools\validate-windows-runtime-helper.ps1
```

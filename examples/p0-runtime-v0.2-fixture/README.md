# P0 runtime v0.2 fixture

本目录是 P0-H2 的公开脱敏单篇 fixture，用于验证：

- agent 产出的统一卡片候选输入；
- `compile_render_input` 确定性派生交付准备状态；
- `render_final_delivery` 确定性生成最终 HTML 与 render receipt；
- 同一输入重复执行时复用既有产物；
- 真实账号、真实图片生成、外部 API 和发布均未执行。

运行检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate-p0-h2-runtime.ps1
```

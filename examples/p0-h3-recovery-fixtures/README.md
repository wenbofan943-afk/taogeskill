# P0-H3 独立失败 / 恢复 Fixtures
本回归包覆盖 P0-F03 至 P0-F19。每个 fixture 自带 `fixture.json`、plan、events、最小状态 / 产物证据和 `expected-result.json`，不得跨目录补证据。
统一检查结果至少包含：
```text
fixture_id
expected_state
actual_state
failure_category
resume_advice
fixture_result
```
运行：
```powershell
.\tools\validate-p0-h3-fixtures.ps1
```
边界：只读取公开脱敏样本；不读取真实账号，不调用外部 API，不生成或复用真实图片，不发布。H3 只固化失败 / 恢复验收，不实现 H4 的统一 event writer、projection rebuild 或 reconciliation 命令。

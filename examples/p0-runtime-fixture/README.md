# P0 Lightweight Runtime Fixture

这是单账号、单 session、单篇内容的脱敏运行计划样例。它把业务主链声明为 14 个步骤，覆盖账号档案、调研、选题人工门、Brief、口播、视觉、图片外部副作用、联合质检、平台包装、封面、规范化 render input 和最终 HTML。

边界：`agent_required`、`human_gate`、`external_side_effect` 的成功事件是脱敏验收证据，不表示 runtime 自主完成了写作、人工决策或图片生成。runtime 只执行 `deterministic_tool`；当前可调用实现是最终 HTML 渲染。

验证：

```powershell
.\tools\invoke-workflow-runtime.ps1 -SessionPath .\examples\p0-runtime-fixture -Mode validate
.\tools\invoke-workflow-runtime.ps1 -SessionPath .\examples\p0-runtime-fixture -Mode resume_report
```

直接运行 `render_final_delivery` 会追加幂等事件；日常回归应先把本 fixture 复制到 `state/checks/`，避免改写 tracked golden evidence。

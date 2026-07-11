# R3 Visual Budget Fixtures

> 状态：history-only `visual-budget` fixture；已被 R3-C71 到 C80 的 visual-need 合同取代。

该 fixture 把“时长默认预算只是包络、最终数量由视觉任务决定、封面不计入画中画、完整 prompt 必须持久化、provider 调用数按实际基础生成任务计算”编译为机器检查。

```powershell
.\tools\validate-r3-visual-budget.ps1
```

成功只证明旧预算和计数合同仍可读取，不证明现行产品实现。当前门禁使用 `validate-r3-visual-need.ps1`。

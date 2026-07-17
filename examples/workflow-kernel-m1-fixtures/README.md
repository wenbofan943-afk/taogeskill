# Workflow Kernel M1 Fixtures

> 状态：M1 静态编译正反 fixture。
> 边界：只验证 Workflow IR、组件目录、兼容目录与 legacy R7 current v0.6 的静态等价；不启动新内核、不读取真实账号、不调用网络或图片 provider。

覆盖：

```text
direct v0.6 25 个 legacy node -> 7 个 stage
hotspot v0.6 30 个 legacy node -> 7 个 stage
35 个唯一 current component 的注册与实现入口
10 条历史 blueprint 的兼容目录覆盖
缺阶段、缺组件、组件输入/状态漂移、节点顺序漂移、重复兼容项、越权切换和解冻旧蓝图扩张的 fail-closed
```

验证：

```powershell
.\tools\validate-workflow-ir-m1.ps1
```

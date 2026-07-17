# Compatibility

本目录只保存已退出 current 热路径、但仍被 version-pinned session 或 replay
消费的兼容资产。它不是 current 产品定义、current Workflow IR 或新增开发入口。

当前兼容代际：

- `legacy-r7/`：R7 blueprint、registry、历史 Schema / renderer，以及由稳定 shim
  调用的 legacy runtime 实现。

所有运行时读取必须经过 `tools/WorkflowCompatibilityLoader.ps1` 和
`routes/compatibility-catalog.json`。资产迁入本目录不表示已退休或可删除；
只有消费者归零、replay 通过且另获删除授权后，才能进行真正退休。

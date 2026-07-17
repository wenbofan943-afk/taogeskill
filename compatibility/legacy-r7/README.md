# Legacy R7 Compatibility

状态：`m5_1_directory_archive_completed`

本目录保存仍需只读兼容的 R7 资产：

```text
routes/       12 条 version-pinned blueprint 及配套 registry
templates/    历史 session Schema 和 v0.6-v0.8 renderer fragment
tools/        legacy semantic runtime 与 CLI 的主体实现
```

项目根 `tools/R7SemanticRuntime.ps1` 与
`tools/invoke-r7-semantic-workflow.ps1` 仅是稳定入口 shim。它们必须先经
compatibility loader 校验 catalog，再加载本目录实现。

禁止：

- current runtime 直接读取本目录；
- 在本目录新增 current blueprint 或产品合同；
- 为减少文件数删除仍有旧 session / replay 消费者的资产；
- 绕过 catalog 临时复制资产回原目录。

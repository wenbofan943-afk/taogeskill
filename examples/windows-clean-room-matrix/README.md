# Windows Clean-room Matrix

当前 R4-WIN-H5 的 6 个 PS5.1 baseline case：

```text
Windows PowerShell 5.1
× short ASCII / 空格中文 / 超预算路径
× Git-index source / verified public ZIP
```

短路径和空格中文路径必须运行代表性 runtime helper 与 environment preflight checker；ZIP 还必须先通过包内 manifest 的 count / size / SHA256 校验。超预算路径的正确结果是 `blocked_preflight`，不是“尝试写入后失败”。

PowerShell 7 不属于当前公开兼容性承诺，也不参与发布阻断；它如被单独评估，必须另立环境证据，不能反推为正式支持。完整矩阵不读取真实账号、不联网、不安装模块、不修改注册表、Group Policy、全局 execution policy 或用户全局 Git。网络盘、OneDrive、大小写敏感 NTFS、企业 Group Policy、ARM64、Windows Server 和非 NTFS 仍为 `not_certified`。

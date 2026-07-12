# Windows Archive Integrity Fixture

R4-WIN-H4 的脱敏归档正反例。它验证公开包和支持日志不能只依赖压缩命令退出码，而必须用包内 `archive-manifest.json` 证明相对路径、数量、大小、SHA256 和必需文件均一致。

覆盖：

- 空格、中文和隐藏 `.github` 文件；
- 缺文件、内容被改、缺 manifest；
- ZIP 路径穿越和大小写碰撞；
- 无效候选不能覆盖上一份有效 ZIP；
- 支持日志真实导出与 foreign cwd；
- public release / support log 共用归档基础层。

不联网，不读取真实账号，不修改注册表、execution policy 或 Git 配置。

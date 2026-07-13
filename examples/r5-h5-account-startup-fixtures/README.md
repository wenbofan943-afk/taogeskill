# R5-H5 Account Startup Fixtures

脱敏 fixture，验证账号调用前的按需字段检查、最多三问、session 快照、热点与视觉字段分级、高风险默认口径和账号切换隔离。

不读取真实账号、不联网、不登录平台、不发布。

startup-request.json 是执行入口 smoke：它应输出 account_ready 和本账号 session 下的 snapshot 引用，但不创建真实账号目录。

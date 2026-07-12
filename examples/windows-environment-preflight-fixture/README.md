# Windows Environment Preflight Fixture

该 fixture 验证 R4-WIN-H3：

- Windows 保留设备名、非法字符、尾随空格 / 点和相对导航。
- 规范化路径必须留在 allowed root。
- reparse point / junction 不得成为越界通道。
- 90 字符安装根建议与 259 字符 classic path budget。
- 同卷临时文件写入、rename、cleanup。
- 磁盘空间不足必须在正式写入前失败。
- environment doctor 不依赖调用者 cwd，且只读系统配置。

运行：

```powershell
.\tools\validate-environment-preflight.ps1
.\tools\invoke-environment-doctor.ps1
```

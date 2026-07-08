# 导出反馈日志包

> 状态：alpha_support_log_export  
> 主责：让外部测试者把“不好用”的证据变成可复盘资产。  
> 边界：反馈日志包不是最终交付物，不自动上传，不自动发给维护者。

---

## 给测试者的一句话

如果你用了这套 workflow，觉得哪里不好用，可以直接对你的 AI 说：

```text
导出反馈日志包。
```

默认只导出排查日志，不包含完整文案、最终 HTML、图片和账号隐私。

如果你记得是哪个账号或哪个选题，可以这样说：

```text
导出“示例行业观察号”这个账号最近一次的反馈日志包。
导出“电动车安全新国标”这个选题的反馈日志包。
```

如果你愿意让维护者看到文案、Brief、质检、图片提示词等内容细节，可以说：

```text
导出反馈日志包，包含内容细节。
```

用户不需要知道 session_id。找不到或匹配到多条时，agent 应该用账号、选题、时间和当前阶段让用户选，不要让用户猜技术字段。

---

## Agent 应该怎么做

默认只导出排查用日志：

```powershell
.\tools\export-support-log.ps1
```

按账号筛选：

```powershell
.\tools\export-support-log.ps1 -Account "示例行业观察号"
```

按选题关键词筛选：

```powershell
.\tools\export-support-log.ps1 -Topic "电动车安全新国标"
```

如果知道 run 目录：

```powershell
.\tools\export-support-log.ps1 -RunPath .\accounts\{account}\runs\{session_id}
```

如果用户明确允许包含内容细节：

```powershell
.\tools\export-support-log.ps1 -Account "示例行业观察号" -IncludeContent
```

导出结果会放在：

```text
support-logs/SUPPORT-{session_id}-{timestamp}/
support-logs/SUPPORT-{session_id}-{timestamp}.zip
support-logs/SUPPORT-{session_id}-{timestamp}.zip.sha256
```

---

## 默认包含什么

`logs_only` 默认包含：

```text
manifest.yaml
README.md
intermediate/00-execution-trace.md
intermediate/checkpoints/
intermediate/checks/
workflow-replay-report.md/json
check-report.md
sample-check-report.json
support-log-summary.md
```

这些文件能说明：

- 本轮是什么 session。
- 当前阶段走到哪里。
- 哪个 skill 负责。
- 哪一步是 skill_defined、agent_orchestrated、user_decision 或 environment_capability。
- 有没有 checkpoint。
- checker / replay 报了什么 warning 或 blocker。

---

## 默认不包含什么

默认不包含：

```text
完整文案
最终 HTML
真实账号 snapshot
生成图片
图片二进制文件
客户记录
平台 cookie / token / API key
```

如果用户要让维护者看具体文案问题，才使用 `-IncludeContent`。

---

## 发给维护者时怎么说

建议同时附上这 4 句话：

```text
1. 我让 agent 做的事情是：
2. 我觉得不好用的位置是：
3. 我预期它应该怎么做：
4. 这个日志包是否允许查看内容细节：是 / 否
```

维护者联系方式见 `CONTACT.md`。


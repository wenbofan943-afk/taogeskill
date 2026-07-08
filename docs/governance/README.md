# Governance Docs

> 状态：治理规则入口
> 主责：收纳项目级 AI 驾驭工程、发版治理、隐私边界、任务路由、状态接续和目录治理规则。
> 边界：本目录不保存具体账号内容、真实运行产物、最终交付物或临时审计报告。

---

## 当前位置

当前项目仍处在治理规则从 `AGENTS.md` 向模块化文档迁移的过渡阶段。

已经沉淀但暂时仍在 `AGENTS.md` 的治理规则包括：

```text
GitHub 开源发版完成定义
GitHub 发布踩坑防复发规则
文档与产物摆放硬规则
字段一致性硬闸门
人类门禁和任务后导航
支持日志导出规则
```

后续如果规则继续变厚，应优先拆入本目录，而不是继续扩大根目录或让 `AGENTS.md` 变成巨型文档。

## 建议拆分方向

```text
agent-routing.md
release-governance.md
privacy-boundary.md
state-continuity.md
file-placement.md
```

拆分前必须同步更新：

```text
AGENTS.md
PROJECT_MAP.md
README.md
tools/validate-*.ps1
```

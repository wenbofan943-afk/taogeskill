# Governance Docs

> 状态：治理规则入口
> 主责：收纳项目级 AI 驾驭工程、发版治理、隐私边界、任务路由、状态接续和目录治理规则。
> 边界：本目录不保存具体账号内容、真实运行产物、最终交付物或临时审计报告。

上级文档分区与真源优先级见 [Docs Index](../README.md)。本目录的编排入口见 [Agent Orchestration](./agent-orchestration/README.md)。

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

当前已经先落地的独立编排区：

```text
agent-orchestration/
├── README.md
├── task-routing.md
├── build-profiles.md
├── compilation-control.md
├── run-control.md
├── state-and-gates.md
├── after-task-guidance.md
└── required-reads.yaml
```

发布公开候选包前，还必须读取并更新 [公开入口文档复核合同](./public-entry-document-review.yaml)。它将 README、安装、更新、状态和发布说明的“已更新 / 已复核无需更新”变成可执行门禁，避免只改顶部版本号、正文仍遗留旧产品口径。

后续拆分 `release-governance.md`、`privacy-boundary.md`、`state-continuity.md` 时，应优先从 `agent-orchestration/` 中迁出稳定章节，而不是另开孤岛文档。

拆分前必须同步更新：

```text
AGENTS.md
PROJECT_MAP.md
README.md
tools/validate-*.ps1
```

# State

> 状态：项目级状态入口
> 主责：给 AI 和人一个稳定入口，说明当前状态真源、历史兼容位置和后续迁移方向。
> 边界：本目录暂不保存真实账号正文、真实 run 交接物或 support log 包。

---

## 当前状态真源

当前仍沿用：

```text
工作流状态记录.md
accounts/{account_slug}/runs/{session_id}/manifest.yaml
accounts/{account_slug}/runs/{session_id}/intermediate/checkpoints/
indexes/
```

本目录先作为“状态入口和路由层”，不直接迁移既有状态，避免打断已编译 skill。

## 文件

| 文件 | 主责 |
|---|---|
| `current-state.yaml` | 当前状态入口，指向现有状态记录和索引 |
| `state-migration-plan.md` | 后续从根目录状态记录迁入结构化 state 的迁移计划 |

## 使用规则

当用户说“继续 / 接着上次 / 活了吗”时：

```text
1. 先读 state/current-state.yaml。
2. 再读 工作流状态记录.md。
3. 如果具体 session manifest 存在，以 manifest 为准。
4. 如果 checkpoint 存在，以最新 checkpoint 辅助恢复。
5. 如果状态冲突，记录冲突并修正汇总状态。
```

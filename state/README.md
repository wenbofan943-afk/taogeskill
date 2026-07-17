# State

> 状态：项目级状态入口
> 主责：给 AI 和人一个稳定入口，说明当前状态真源、历史兼容位置和后续迁移方向。
> 边界：本目录暂不保存真实账号正文、真实 run 交接物或 support log 包。

---

## 当前状态真源

架构迁移进度先看 `current-state.yaml` 的 `architecture_migration`：M1 已完成三份机器真源与静态 parity；M2 direct 16-case、M3 hotspot 21-case shadow 继续通过；M4 已用 19-case 编译新 session 代际 binding、旧 R7 只读续跑和仅影响未来 session 的回滚。动态报告位于忽略的 `state/checks/workflow-kernel-m1/` 至 `workflow-kernel-m4/` 及对应报告文件，不能反向成为真源。M4 不等于 runtime certification。

运行时仍沿用：

```text
工作流状态记录.md
accounts/{account_slug}/runs/{session_id}/manifest.yaml
accounts/{account_slug}/runs/{session_id}/intermediate/checkpoints/
indexes/
```

根目录 `工作流状态记录.md` 是本地私有状态，可能包含真实账号名、session_id 和产物路径，不进入 Git。公开仓库只保存 `templates/state/工作流状态记录.template.md`。新克隆或新安装缺少本地状态文件时，先复制模板初始化；具体 session 仍以 manifest 为准。

## 文件

| 文件 | 主责 |
|---|---|
| `current-state.yaml` | 当前状态入口，指向现有状态记录和索引 |
| `state-migration-plan.md` | 后续从根目录状态记录迁入结构化 state 的迁移计划 |
| `../templates/state/工作流状态记录.template.md` | 新环境初始化本地状态记录的脱敏模板 |

## 本地检查证据

专项 checker 声明的最新报告和 current fixture work 保留在 `state/checks/` 的稳定路径。被最终报告取代的 debug、试跑、中间修订和旧环境沙箱迁入 `state/checks/archive/{YYYYMMDD}-{task}/`，并在批次内记录原路径、原因与 current 替代证据。

`state/checks/archive/` 属于本地私有历史区，不进入 Git、公开包或 current 状态真源。需要证明当前代码或当前环境时，必须重新运行对应 checker，不能复用归档绿灯。

## 使用规则

当用户说“继续 / 接着上次 / 活了吗”时：

```text
1. 先读 state/current-state.yaml。
2. 如果 `工作流状态记录.md` 不存在，按 `templates/state/工作流状态记录.template.md` 初始化。
3. 再读本地 `工作流状态记录.md`。
4. 如果具体 session manifest 存在，以 manifest 为准。
5. 如果 checkpoint 存在，以最新 checkpoint 辅助恢复。
6. 如果状态冲突，记录冲突并修正汇总状态。
```

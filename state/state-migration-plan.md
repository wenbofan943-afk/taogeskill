# State Migration Plan

> 状态：迁移计划，不是已完成迁移
> 主责：说明未来如何把状态治理从根目录单文件推进到结构化 state 层。
> 边界：当前不迁移真实账号、不迁移历史 run、不改 skill 读写路径。

---

## 为什么不立刻迁移

当前很多 skill、文档和人工操作都引用：

```text
工作流状态记录.md
accounts/{account_slug}/runs/{session_id}/manifest.yaml
indexes/
```

如果直接把状态迁入 `state/`，会导致：

```text
旧 skill 找不到状态
历史运行恢复路径断裂
support log 导出匹配失败
公开包和教程路径不一致
```

因此当前采用 bridge 模式：

```text
state/current-state.yaml
-> 指向现有状态真源
-> 不替代现有文件
```

## 后续阶段

### S1：状态入口层

```text
state/current-state.yaml
state/state-migration-plan.md
```

只做索引，不改变运行路径。

### S2：索引层

新增：

```text
state/run-index.yaml
state/governance-index.yaml
```

由脚本从 `工作流状态记录.md` 和 `accounts/` 汇总生成。

### S3：检查层

新增：

```text
tools/validate-state-continuity.ps1
```

检查：

```text
current_artifact 是否存在
manifest 是否存在
checkpoint 是否存在
session_status 是否可恢复
工作流状态记录.md 是否和 manifest 冲突
```

### S4：真源切换

只有当所有 skill 都改读 `state/` 且 validator 通过后，才允许把 `state/` 升为主状态真源。

在此之前：

```text
工作流状态记录.md 仍是兼容状态记录
accounts/{account_slug}/runs/{session_id}/manifest.yaml 仍是具体 run 真源
```

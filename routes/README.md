# Routes

> 状态：机器可读路由入口
> 主责：保存 task_type、build_profile、required_reads、gates、outputs、after_completion 的稳定映射。
> 边界：本目录不保存具体文案、账号资料、运行日志或发版产物。

---

## 文件

| 文件 | 主责 |
|---|---|
| `workflow-routes.yaml` | 用户意图到 task_type / profile / 必读 / 门禁 / 输出 / 任务后导航的机器可读路由 |
| `build-profiles.yaml` | dev / test / public 三类构建 profile 的机器可读边界 |

## 关系

```text
docs/governance/agent-orchestration/
  解释规则和人类可读说明

routes/
  机器可读路由真源草案
```

当两者冲突时：

```text
短期：以 docs/governance/agent-orchestration/ 的解释为准，并修 routes。
长期：以 routes/ 为机器真源，docs 只做解释。
```

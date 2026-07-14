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
| `content-structure-strategies.yaml` | R6 可扩展短视频结构策略注册表；策略是候选，不是每篇强套模板 |
| `r7-workflow-blueprints.yaml` | R7 单篇直供 / 热点两条版本化业务蓝图；H1 为合同态 |
| `r7-node-registry.yaml` | R7 节点 Skill、输入选择、输出、路由、stale 与 retry 登记 |
| `r7-contract-status-registry.yaml` | active / pending / superseded 的机器状态真源 |
| `r7-action-registry.yaml` | 当前交付动作 code 与目标类型登记；阻止自然语言猜 enum |

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

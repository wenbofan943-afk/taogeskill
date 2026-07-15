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
| `r6-semantic-normalization-registry.yaml` | R6 v0.2 主体、日期、数字、百分比、金额、单位和来源身份的 typed fact 规范化规则 |
| `r7-workflow-blueprints.yaml` | R7 current v0.3 直供 / 热点单篇蓝图；v0.2 保持只读 replay |
| `r7-node-registry.yaml` | R7 节点 Skill、输入选择、输出、路由、stale 与 retry 登记 |
| `r7-contract-status-registry.yaml` | active / pending / superseded 的机器状态真源 |
| `r7-action-registry.yaml` | v0.2 当前动作 code；新增 Topic Gate 六类决定，阻止自然语言猜 enum |
| `r7-action-registry.v0.1.yaml` | 直供 v0.2 / delivery v0.6 钉住的历史动作注册表，不随 H6A 静默升级 |
| `r7-input-selector-registry.yaml` | task 输入 selector 的 resolver、相对路径、ID / status 和空值策略 |
| `r7-artifact-commit-registry.yaml` | artifact ID / status 字段与 revision / current pointer 路径模板 |
| `r7-status-route-registry.yaml` | node result status 到 success / warning / waiting / failure 的确定性映射 |
| `r7-task-guidance-registry.yaml` | task envelope 的业务目标与决策边界来源 |
| `r7-producer-adapter-registry.yaml` | H3 直供 node 到 payload Schema、artifact type 与校验模式的唯一映射 |
| `r7-delivery-presentation-registry.yaml` | Topic Gate、source context 与 current delivery 呈现登记；v0.8 额外显示视觉来源和返修追溯 |
| `r7-delivery-presentation-registry.v0.1.yaml` | 直供 v0.2 / delivery v0.6 钉住的历史呈现注册表 |

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

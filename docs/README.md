# Docs Index

> 状态：active_index
> 主责：给 AI 和维护者提供文档分区、真源层级和最短阅读路径。
> 边界：这里只做导航，不复制产品规则、字段正文或某次运行结果。

## AI 最短阅读路径

| 当前任务 | 先读 | 再读 |
|---|---|---|
| 判断项目当前在做什么 | [STATUS](../STATUS.md) | [current-state](../state/current-state.yaml)、本地 `工作流状态记录.md` |
| 产品开发 / 产品确认 | [产品文档索引](./product/README.md) | 对应 R0-R4 总览、确认清单或 P0 路线图 |
| Skill / 代码编译 | [编译控制](./governance/agent-orchestration/compilation-control.md) | [Reference 索引](./reference/README.md)、[字段词典](../交接物字段词典.md)、对应 Skill / CONTRACT |
| 按 AGENTS 编排 | [治理索引](./governance/README.md) | [Agent Orchestration](./governance/agent-orchestration/README.md) |
| 理解为什么这样设计 | [解释与复盘索引](./explanation/README.md) | 只读相关复盘，不把历史结论当当前合同 |
| 操作、导出或看业务流程 | [How-to 索引](./how-to/README.md) | 对应命令或交互页面 |
| 跑脱敏教程 | [Tutorials 索引](./tutorials/README.md) | [Examples 索引](../examples/README.md) |
| 查可执行能力 | [Skills 索引](../skills/README.md) | 对应 `SKILL.md`、`CONTRACT.md` |
| 查模板和机器合同 | [Templates 索引](../templates/README.md) | [Tools 命令索引](../tools/README.md) |
| 查本地产品 / 活动对象 | `objects/README.md`（本地母仓） | [产品与活动对象档案规范](./reference/产品与活动对象档案.md) |

## 真源优先级

```text
具体 session：manifest / events / materialized artifact
项目当前状态：state/current-state.yaml + STATUS.md
产品当前定义：docs/product/*总览 + *确认清单 + 当前路线图末尾状态
执行合同：交接物字段词典 + docs/reference + Skill / CONTRACT + Schema / checker
历史解释：docs/explanation、路线图历史章节、编译记录
```

发生冲突时，先核对具体产物和机器合同，再修状态与入口；不得用历史复盘覆盖当前产品合同。

## 分区责任

| 目录 | 放什么 | 不放什么 |
|---|---|---|
| `product/` | 产品范围、决策、确认、路线和编译记录 | 临时报告、单次账号产物 |
| `reference/` | 可复用执行规范、字段解释、方法论 | 某次讨论过程 |
| `governance/` | AI 编排、状态门禁、目录和发布治理 | 业务正文 |
| `explanation/` | 复盘、问题包、设计解释 | 当前机器合同真源 |
| `how-to/` | 面向人类的操作指南 | 产品决策过程 |
| `tutorials/` | 脱敏可公开教程和完整样例 | 真实账号 / 真实 run |

## 索引维护规则

新增、移动或重命名知识文档时，先更新所属目录的 `README.md`；只有新增入口级能力才更新根 `README.md` / `PROJECT_MAP.md`。目录索引负责“完整覆盖”，根入口负责“最短路径”，避免两个根文件重复维护全量清单。

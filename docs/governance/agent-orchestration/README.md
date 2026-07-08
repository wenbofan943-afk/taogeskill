# Agent Orchestration

> 状态：项目级 AI 驾驭工程编排入口
> 主责：定义 agent 进入项目后如何路由任务、读取规则、选择构建 profile、执行门禁、记录状态和收口。
> 边界：本目录不替代具体 skill，不保存真实账号内容，不保存运行产物。

---

## 设计依据

本编排区参考成熟 AI workflow 的共性结构：

```text
root instructions   项目入口规则
scoped rules        按任务 / 路径加载的规则
skills / commands   可复用动作单元
state / checkpoint  断点续跑和人类门禁状态
hooks / gates       自动检查和阻断条件
logs / traces       可复盘日志和反馈资产
```

落到本项目，结构是：

```text
AGENTS.md
-> docs/governance/agent-orchestration/
   -> task-routing.md
   -> build-profiles.md
   -> state-and-gates.md
   -> after-task-guidance.md
   -> required-reads.yaml
-> routes/
   -> workflow-routes.yaml
   -> build-profiles.yaml
-> state/
   -> current-state.yaml
```

`AGENTS.md` 只保留最高优先级边界和入口；本目录保存可维护的编排细则。

## 文件说明

| 文件 | 主责 |
|---|---|
| `task-routing.md` | 用户意图到任务类型、必读文件、自动推进和人类门禁的路由 |
| `build-profiles.md` | dev / test / public 三类构建与数据边界 |
| `state-and-gates.md` | 状态记录、checkpoint、检查门禁、失败收口规则 |
| `after-task-guidance.md` | 每个任务完成、等待、阻断或失败后的用户引导、自动继续和推荐回复规则 |
| `required-reads.yaml` | 机器可读的任务必读清单草案，后续可编译成 validator |
| `../../../routes/workflow-routes.yaml` | 用户意图到 task_type、profile、必读、门禁、输出的机器可读路由 |
| `../../../routes/build-profiles.yaml` | dev / test / public 三类构建 profile 的机器可读边界 |
| `../../../state/current-state.yaml` | 当前状态桥接入口，避免在迁移期打断旧 skill |

## 使用规则

当用户说“按 AGENTS”时，agent 必须先判断任务类型：

```text
内容生产
产品开发
skill 编译
测试 / dry-run
发版 / GitHub
排错 / support log
目录治理 / 文档治理
```

判断后只读取对应任务的必读文件，不把整个项目当成一本巨型上下文。

如果任务类型不清，先用一句人话说明当前判断和下一步，不让用户学习内部字段。

任务结束时必须读取 `after-task-guidance.md` 的收口规则，并优先使用 `routes/workflow-routes.yaml` 中对应 `after_completion` 字段给用户下一步引导。

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
   -> architecture-control.md
   -> workflow-kernel-simplification.md
   -> m6-independent-certification.md
   -> compilation-control.md
   -> run-control.md
   -> state-and-gates.md
   -> after-task-guidance.md
   -> required-reads.yaml
-> routes/
   -> workflow-routes.yaml
   -> build-profiles.yaml
   -> architecture-control.yaml
   -> current-workflow-ir.json
   -> component-catalog.json
   -> compatibility-catalog.json
   -> run-control-profiles.yaml
-> state/
   -> current-state.yaml
```

`AGENTS.md` 只保留最高优先级边界和入口；本目录保存可维护的编排细则。

## 文件说明

| 文件 | 主责 |
|---|---|
| `task-routing.md` | 用户意图到任务类型、必读文件、自动推进和人类门禁的路由 |
| `build-profiles.md` | dev / test / public 三类构建与数据边界 |
| `architecture-control.md` | 产品、控制面、工作面、数据面、评测面分层，架构决定、认证冻结和事故到规则的晋升路径 |
| `workflow-kernel-simplification.md` | `ARCH-20260718-002` 工作流复杂度根因、七阶段轻量内核、三份机器真源、M1-M5.1 迁移结果与 M6 独立认证边界 |
| `m6-independent-certification.md` | M6 五类摘要冻结、evaluator/runtime conformance 与 direct/hotspot 同摘要认证顺序 |
| `compilation-control.md` | 产品确认如何闭合为字段、合同、Schema、runtime、fixture 与 checker，并定义版本与 contract_break 处理 |
| `run-control.md` | 自动继续作用域、连续执行预算、任务跃迁、业务完成检查点和重复失败熔断 |
| `state-and-gates.md` | 状态记录、checkpoint、检查门禁、失败收口规则 |
| `after-task-guidance.md` | 每个任务完成、等待、阻断或失败后的用户引导、自动继续和推荐回复规则 |
| `required-reads.yaml` | 机器可读的任务必读清单草案，后续可编译成 validator |
| `../../../routes/workflow-routes.yaml` | 用户意图到 task_type、profile、必读、门禁、输出的机器可读路由 |
| `../../../routes/build-profiles.yaml` | dev / test / public 三类构建 profile 的机器可读边界 |
| `../../../routes/architecture-control.yaml` | 架构平面、当前限制、认证前置和规则晋升的机器合同 |
| `../../../routes/current-workflow-ir.json` | 两条 current route、7 个顶层阶段与 M5 session 代际隔离策略机器真源；不携带 legacy 投影 |
| `../../../routes/component-catalog.json` | 35 个 current stage-internal component 的实现、状态和合同真源；不携带 legacy step 映射 |
| `../../../routes/compatibility-catalog.json` | 12 条历史 blueprint、迁入 `compatibility/legacy-r7/` 的 17 项兼容资产、固定快照与唯一 loader 边界 |
| `../../../routes/m6-certification-contract.json` | M6 五类冻结文件、evaluator suite、runtime 与真实 route 认证状态机器合同 |
| `../../../routes/run-control-profiles.yaml` | 交互任务连续执行预算、重复修复上限和 checkpoint_and_return 策略 |
| `../../../state/current-state.yaml` | 当前状态桥接入口，避免在迁移期打断旧 skill |

## 使用规则

当用户说“按 AGENTS”时，agent 必须先判断任务类型：

```text
内容生产
产品开发
架构定义
skill 编译
运行时认证
评测器认证
测试 / dry-run
发版 / GitHub
排错 / support log
目录治理 / 文档治理
```

判断后只读取对应任务的必读文件，不把整个项目当成一本巨型上下文。

任何 route 在开始工具动作前先读取 `run_control`；自动继续只在声明 scope 内有效。跨 task_type、build profile 升级、业务完成后的工程旁支和预算熔断统一按 `run-control.md` 收口。

文档发现先走 `../../README.md` 和对应分区 README；根 README / PROJECT_MAP 只提供快速入口。进入超过 800 行的当前长文时，先读 `ai-nav` 或用 `rg` 定位当前批次，禁止为了“确保看见”顺序吞入整份历史文档。

任务路由只决定任务类型、必读规则和门禁。模型与推理档位由用户在 Codex 前端手动选择，项目不提供自动切换。

如果任务类型不清，先用一句人话说明当前判断和下一步，不让用户学习内部字段。

任务结束时必须读取 `after-task-guidance.md` 的收口规则，并优先使用 `routes/workflow-routes.yaml` 中对应 `after_completion` 字段给用户下一步引导。

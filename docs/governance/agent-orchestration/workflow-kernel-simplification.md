# Workflow Kernel Simplification

> 架构决定：`ARCH-20260718-002`
> 当前状态：`confirmed`
> 目标：停止继续堆叠 current 蓝图、注册表和专项补丁，把现有能力收敛为一个轻量、可恢复、可替换的本地工作流内核。
> 确认：用户于 2026-07-18 认可 `ARCH2-D01` 至 `ARCH2-D10`。
> 边界：本决定确认目标架构，但当前消息先执行文档归档；不自动授权源码迁移、删除历史合同或修改 R8 产品草案。进入 M1 原子编译仍按任务路由单独执行。

---

## 决策摘要

推荐采用：

```text
保留现有业务能力和正确的 evidence 机制
-> 不引入 Temporal / Prefect / LangGraph 服务端
-> 先在 Windows PowerShell 5.1 兼容边界内建立轻量本地内核
-> 用一个 current Workflow IR 描述现行流程
-> 把 25 / 30 个 current 节点收敛为 7 个顶层业务阶段
-> 历史版本退出 current 热路径，只由 compatibility loader 回放
-> Codex 作为 host 自动循环到真正的人类 / 外部等待点
```

这不是重写业务，也不是删除历史证据。它是一次控制面瘦身。

## 为什么会感觉“越造越复杂”

### 本地事实

| 观察 | 当前值 | 说明 |
|---|---:|---|
| current 直供顶层节点 | 25 | 大量中间对象被提升为 workflow step |
| current 热点顶层节点 | 30 | 研究、写作、视觉、交付全部逐对象推进 |
| 两条 current route 的唯一节点 | 35 | 其中 22 个是 semantic Skill 节点 |
| 蓝图版本 | 12 | current 与历史版本共居一个 registry |
| R7 核心手工注册表 | 10 份 / 2,757 行 | blueprint、node、selector、commit、status、guidance、action 等需人工同步 |
| 全项目 Schema | 190 | R7 单独 73 个 |
| `tools/*.ps1` | 145 个 / 26,190 行 | 其中 validator 约 71 个，运行入口约 32 个 |
| `state/current-state.yaml` | 719 行 / 39 KB | 当前指针、历史批次、测试和发布证据混在一起 |
| coordinator 主 runtime | 762 行 | 同时承担 current 与多代历史合同分流 |

另有一个可见漂移：`semantic-workflow-coordinator` 的 `SKILL.md` / `CONTRACT.md` 已声明 current v0.6，但其 `agents/openai.yaml` 仍描述 v0.5。它证明当前“多份手工真源”已经超过稳定同步能力。

### 根因不是业务很多，而是控制面把所有细节都当成一级概念

当前复杂度主要来自六个结构性原因：

1. **一个中间对象等于一个顶层节点。**  
   Brief、baseline、结构、beat、review、视觉意图、来源路由、Prompt 等都独立推进。可审计性提高了，但每篇内容都要支付完整编排成本。

2. **历史兼容进入 current 热路径。**  
   runtime 通过大量版本判断同时理解 v0.1 到 v0.9；新功能会继续增加条件分支。

3. **同一个事实有多份手工表达。**  
   Blueprint、node registry、selector、commit registry、status route、guidance、Skill、Contract、Schema 和 checker 分别复制部分语义。

4. **每次事故都新增一个长期结构。**  
   专项 Schema、fixture、checker 和状态字段持续累积，但旧结构没有退休机制。

5. **Codex 仍是隐形的外层 runner。**  
   当前 CLI 一次只做 initialize / prepare / submit / reconcile / deterministic node；没有一个 host loop 自动推进到真实等待点，所以用户不断需要说“继续”。

6. **运行时认证和业务质量评测混在业务回归里。**  
   一次 A/B 或真实运行同时验证 workflow、worker、evaluator、fixture 和 HTML，任一层修订都会让结论失效。

## 成熟工作流给出的共同原则

本项目只吸收原则，不直接照搬重型基础设施：

- Temporal：Workflow 只做确定性编排，网络、LLM、文件等外部动作放入 Activity；Event History 是恢复事实源，重放不重复外部动作。
- LangGraph：thread checkpoint 与跨 thread store 分开；持久化服务于中断恢复，不把所有长期知识塞入当前运行状态。
- Prefect：Flow 负责组合，Task 是可重试、可缓存、可观测的原子工作；官方同时明确提示不能过度封装和过度颗粒化。
- XState：一个状态机定义状态、事件、guard 和 transition；实现函数与状态机逻辑分离，合法下一步可直接从机器定义推导。

对应到本项目：

```text
业务阶段是控制面
阶段内部对象是数据面
Skill / deterministic operation 是工作面
外部调用是可 reconcile 的 activity
评测器是独立系统
```

## 目标架构

### 一条用户可感知的主循环

```text
用户给目标
  -> Codex host 选择 direct / hotspot route
  -> local kernel 读取 current Workflow IR
  -> kernel 自动执行确定性 transition
  -> 遇到 semantic stage，输出一个 typed stage task
  -> Codex 只运行指定 worker，并提交 typed stage result
  -> kernel 写 event / artifact / attempt / outcome 并继续
  -> 只在 human gate、外部授权/能力等待、合同阻断或最终交付时停止
```

用户不再为正常节点推进反复说“继续”。Codex 仍负责语义生产，但不再临场选择路径、补状态或手工拼中间产物。

### 七个顶层业务阶段

| 阶段 | 直供 | 热点 | 顶层停止条件 |
|---|---|---|---|
| 1. intake | 文案、账号与目标 | 账号、雷达策略与目标 | 输入合同不完整 |
| 2. research_topic | 跳过或复用来源 | 调研、候选与选题 | Topic Gate / 外部研究等待 |
| 3. script_design | Brief、结构、草稿、质检、修订决策 | 同左 | 明确需人工改写策略 |
| 4. visual_plan | 视觉需求、意图、来源路由、Prompt bundle | 同左 | 来源授权或能力等待 |
| 5. asset_production | Image 2、截图、复用、后工程、素材 review | 同左 | 外部 outcome / 素材 review |
| 6. delivery_compile | 对齐、平台包装、封面、HTML、viewport、业务验收 | 同左并含 freshness check | 交付阻断 |
| 7. final_decision | 最终人工决定与确定性 apply | 同左 | 人类确认 / 返修 / 导出 / 归档 |

现有中间对象仍可保留为阶段内 artifact，不再默认成为需要 host 单独往返的顶层节点。只有以下边界值得成为原子 task：

```text
需要独立重试
需要独立恢复
产生外部副作用
需要人类决定
需要不同权限
失败后必须局部回滚
```

### 三个机器真源

current 控制面最多保留三个手工机器真源：

1. `current-workflow-ir.json`  
   两条 current route、7 个阶段、transition、guard、input/output contract、wait/retry/reconcile 和版本。
2. `component-catalog.json`  
   Skill、deterministic operation、external activity、human gate 的实现入口和能力合同。
3. `compatibility-catalog.json`  
   历史 blueprint / Schema / renderer 的只读 replay 映射。

以下内容由 IR 生成或校验，不再分别手工维护语义：

```text
current blueprint view
node view
input selector view
commit/status route view
task envelope skeleton
current Schema index
fixture catalog skeleton
文档流程图
```

### 状态与数据

单个 session 只保留：

```text
events.jsonl                 append-only 运行事实
artifacts/{type}/{revision}  不可变业务产物
attempts/                    外部调用和 worker attempt/outcome
run-state.json               从 event 重建的当前投影
resume-summary.json          面向 host / 人的派生摘要
```

项目级 `state/current-state.yaml` 只保存当前 workstream 指针、成熟度、最近认证和下一步，不再保存每个 R3–R8 批次的完整测试账本。历史证据进入版本化 report / decision / release record。

### 评测面

业务运行只产生 trace 和交付物，不在同一循环内修改 evaluator。

```text
runtime conformance
evaluation conformance
business A/B
```

三者分开运行、分开版本、分开出结论。

## 技术栈取舍

### 本轮推荐：不立刻换框架

保持 Windows PowerShell 5.1 作为公开兼容入口，Workflow IR 使用 JSON，避免新增 YAML 模块、Node 服务或数据库依赖。先证明“结构变简单且能跑通”，再讨论内核是否迁到 TypeScript / XState 或 Python。

### 暂不选择的方案

| 方案 | 当前结论 | 原因 |
|---|---|---|
| 继续在 R7 current registry 上补版本 | 拒绝 | 直接放大当前根因 |
| 立刻迁 Temporal | 拒绝 | 自用单机项目不需要服务端、worker 和运维面 |
| 立刻迁 Prefect / LangGraph | 暂不采用 | 能解决部分状态问题，但会在未简化业务边界前引入新的框架概念 |
| 立刻迁 XState / TypeScript | 只保留 spike 选项 | 状态机思想合适，但 Node 目前不是公开安装基线 |
| 轻量本地内核 + 单一 IR | 推荐 | 保留现有资产、迁移可控、能先消除多真源 |

## 保留、停止和退休

### 保留

- append-only event
- immutable artifact revision
- pointer-last commit
- input hash / lineage
- attempt / outcome / output reference
- reconcile-first
- deterministic renderer
- typed human decision
- private/public 数据边界
- Windows PowerShell 5.1 兼容入口

### 立即停止扩张

- 小功能直接新增 current blueprint 版本
- 为一个字段再建一份手工 registry
- 把历史版本判断继续写进 current transition core
- 每次事故都永久新增一个聚合 checker
- 把本次真实回归数量写入通用合同
- 把完整历史批次继续追加进 `state/current-state.yaml`
- 用聊天中的“继续”承担正常控制流

### 退休策略

历史合同不删除，先迁到 compatibility loader 的只读范围。只有新内核完成 current direct / hotspot 认证后，旧 current runtime 才从默认入口退出；删除必须另行授权。

## 渐进迁移

### M0：冻结扩张

- R8 产品草案保持冻结。
- current v0.6 只修数据损坏、安全和不可恢复 blocker。
- 不再为普通需求新增 v0.7。

### M1：建立 IR 与静态编译器

- 把两条 current v0.6 映射为 7 阶段 IR。
- 生成 current 视图和 parity report。
- 不切换真实 session。

### M2：直供 shadow runtime

- 新内核读取同一输入，写入隔离 shadow session。
- 旧 runtime 仍是 current。
- 比较 artifact、event、stop reason 和最终 HTML。

### M3：热点 shadow runtime

- 增加 research/topic/freshness/reversal。
- 真实外部调用仍使用 attempt/outcome/reconcile。

### M4：新 session 切换

- 只有 direct 与 hotspot shadow 都通过后，新 session 才默认使用新内核。
- 旧 session 继续按原版本恢复，不做原地迁移。

### M5：兼容隔离

- 历史 blueprint、Schema 和 renderer 只由 compatibility catalog 加载。
- current runtime 禁止分支判断旧版本。

### M6：独立认证

- evaluator 先通过 conformance。
- runtime 再通过 start / advance / wait / resume / rebuild / reconcile。
- 最后执行 direct 与 hotspot 绑定同一 digest 的真实认证。

## 回滚

迁移期间保留入口 feature flag：

```text
runtime_generation: legacy_r7 | kernel_v1_shadow | kernel_v1_current
```

任一 parity、恢复或交付门禁失败：

```text
停止创建 kernel_v1 新 session
-> 保留失败 shadow evidence
-> 新 session 回到 legacy_r7
-> 已产生的 kernel_v1 session 不伪装成 legacy session
```

不修改、覆盖或迁移既有真实 session。

## 验收

架构编译完成不以“文件变少”单独判断，至少满足：

1. 两条 current route 只有一个 Workflow IR 真源。
2. current 顶层阶段不超过 7 个；阶段内对象仍可审计。
3. 修改一个 current 阶段时，手工机器真源修改不超过 IR、component contract 和对应 fixture 三类。
4. current transition core 不包含历史 blueprint / envelope / renderer 的版本条件分支。
5. Codex host 能从输入自动推进到真实 human / external wait 或最终 HTML，不需要用户为正常节点重复说“继续”。
6. event 可重建 `run-state.json` 和 resume summary。
7. 外部 outcome 已存在时，resume 不重复调用 provider。
8. transition 使用调用方物化的时间、随机值和外部结果，不从 current clock 静默补运行事实。
9. `state/current-state.yaml` 只保留当前指针与认证摘要，历史批次移出 current state。
10. evaluator 不在业务 A/B 过程中修改；修改后旧 evaluation 自动 invalid。
11. direct 与 hotspot 各有至少两次不同输入的无手工机器补件认证。
12. 旧 session replay / render 仍可用，但不进入 current 热路径。

## 已确认决定

```text
ARCH2-D01 采用“轻量本地内核 + 单一 Workflow IR”，不继续扩张 R7 current registry。
ARCH2-D02 本阶段不引入 Temporal、Prefect、LangGraph、XState 服务或运行依赖。
ARCH2-D03 两条 current route 收敛为 7 个顶层业务阶段。
ARCH2-D04 中间对象保留为 artifact；只有重试、恢复、副作用、人类决定和权限边界成为原子 task。
ARCH2-D05 current 控制面最多三个手工机器真源；其余视图生成或校验。
ARCH2-D06 历史版本退出 current 热路径，由 compatibility loader 只读承接。
ARCH2-D07 Codex host 自动推进到真实等待点，不再让用户承担正常节点推进。
ARCH2-D08 项目 current state 与历史证据分离。
ARCH2-D09 runtime、evaluator、业务 A/B 分开认证。
ARCH2-D10 使用 shadow / strangler 迁移，不重写或原地改造既有真实 session。
```

## 研究来源

- Temporal Workflows：<https://docs.temporal.io/workflows>
- Temporal Activities：<https://docs.temporal.io/activities>
- LangGraph persistence：<https://docs.langchain.com/oss/python/langgraph/persistence>
- Prefect flows：<https://docs.prefect.io/v3/concepts/flows>
- Prefect tasks：<https://docs.prefect.io/v3/concepts/tasks>
- XState state machines：<https://stately.ai/docs/machines>

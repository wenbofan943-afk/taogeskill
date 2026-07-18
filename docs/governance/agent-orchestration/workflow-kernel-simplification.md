# Workflow Kernel Simplification

> 架构决定：`ARCH-20260718-002`
> 当前状态：`m6_direct_certification_surface_compiled_not_certified`
> 目标：停止继续堆叠 current 蓝图、注册表和专项补丁，把现有能力收敛为一个轻量、可恢复、可替换的本地工作流内核。
> 确认：用户于 2026-07-18 认可 `ARCH2-D01` 至 `ARCH2-D10`。
> 边界：M1-M3 已完成 shadow 编译，M4 完成未来新 session 的代际切换，M5 完成 current/legacy 兼容隔离，M5.1 完成仍有消费者资产的目录级归档。M6 已编译五类冻结、evaluator/runtime conformance 与 direct certification surface；direct suite 接入后必须在新 clean HEAD 上重跑同摘要 evaluator/runtime/direct certification。既有 session 未迁移，历史合同未删除，未联网、调用外部 provider 或修改 R8 产品草案。

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

完成状态：

```text
routes/current-workflow-ir.json
routes/component-catalog.json
routes/compatibility-catalog.json
-> tools/compile-workflow-ir.ps1
-> state/checks/workflow-kernel-m1/current/*.json
-> tools/validate-workflow-ir-m1.ps1
```

静态等价基线为 direct v0.6 的 25 个节点、hotspot v0.6 的 30 个节点、7 个顶层阶段、35 个唯一 current component。M5 后 12 条 R7 blueprint 全部进入 compatibility catalog；所有生成视图都是派生物，不反向成为真源。M1 完成时 `runtime_switch_enabled=false`；M4 后 current IR 已升级为 true，并由 session generation policy 约束新旧代际和回滚范围。

M1 中遇到的历史动作与呈现注册表仍被 legacy resume/replay 消费。M5 已把加载权集中到 `WorkflowCompatibilityLoader.ps1`；M5.1 将 17 项 cataloged 资产迁入 `compatibility/legacy-r7/` 并登记为 `relocated_compatibility_consumer`。目录迁移不等于退休：只有消费者归零、replay fixture 通过且另获明确决定后才能删除。

### M2：直供 shadow runtime

- 新内核读取同一输入，写入隔离 shadow session。
- 旧 runtime 仍是 current。
- 比较 artifact、event、stop reason 和最终 HTML。

M2 已完成控制面编译：

```text
examples/workflow-kernel-m2-direct-shadow-fixtures/baseline-request.json
-> tools/invoke-workflow-kernel-shadow.ps1
-> tools/WorkflowKernelRuntime.ps1
-> state/checks/workflow-kernel-m2/fixtures/**/shadow/
-> tools/validate-workflow-kernel-m2.ps1
```

当前 direct shadow 使用 `current-workflow-ir.json` 的阶段顺序与 `component-catalog.json` 的允许状态、正向推进状态、输出类型和合同，接收已经由组件 validator 判定为 pass 的 typed result envelope。kernel 负责隔离落盘、artifact hash、append-only event、状态 / resume 投影、final HTML 绑定和 legacy parity；它不在 M2 中假装执行 Codex 语义 worker，也不接受最终人类决定。M2 只编译正向路径到最终人工等待；中途 wait / revision / blocked 状态在任何 shadow artifact/event 写入前以 `m2_non_progress_result_requires_separate_shadow_case` 阻断，恢复行为留给 M6 conformance。

固定脱敏基线结果：

| 比较面 | M2 结果 |
|---|---|
| artifact | 23 个，归一化 projection digest 与冻结 legacy v0.6 contract fixture 一致 |
| event | 31 个 append-only event，归一化 projection digest 与 fixture 一致 |
| stop reason | `final_decision / waiting_human` |
| final HTML | 固定文件 SHA256 一致 |
| rebuild | event + immutable artifact 重建 projection 后 byte-stable |
| replay | 同 request 再次调用返回 `shadow_run_reused`，不追加 event |
| 负例 | 15 个全部被正确阻断，覆盖合同断裂、未知字段、中途非正向状态、越界、伪 parity 和 artifact 篡改 |

M2 shadow invocation 自身固定 `runtime_switch_enabled=false`、`current_write_performed=false`、`runtime_certification=false`。比较基线还显式记录 `real_legacy_runtime_executed=false`。这不等于 M4 之后的全局入口开关仍关闭：M2 只证明 direct 控制面 shadow 与冻结 legacy 合同接线成立，不证明真实 legacy session 双跑、语义质量、外部 activity、真实账号自动运行或 L3；真实同输入认证归入 M6。

### M3：热点 shadow runtime

M3 已在 M2 核心之外增加隔离的 hotspot route adapter：

```text
examples/workflow-kernel-m3-hotspot-shadow-fixtures/
-> tools/invoke-workflow-kernel-shadow.ps1 -Mode run_hotspot
-> tools/WorkflowKernelHotspotRuntime.ps1
-> state/checks/workflow-kernel-m3/fixtures/**/shadow/
-> tools/validate-workflow-kernel-m3.ps1
```

热点命令分为 `start` 与 `resume`。每次命令都冻结 input digest、当前结果切片、external activity record、停止原因和恢复目标；resume 必须逐字匹配上一命令 digest。研究与 freshness 使用 `request -> attempt -> outcome -> output reference -> consumer acceptance`，等待后的 outcome 必须 reconcile 已持久化 attempt，同一 activity 禁止盲重试。

21 个 Windows PowerShell 5.1 fixture 已全部通过，覆盖：

| 比较面 | M3 结果 |
|---|---|
| 完整热点链 | 28 个 artifact、44 个 append-only event，停在 `final_decision / waiting_human` |
| 外部活动 | research 与 freshness 各 1 次 attempt / outcome；`external_retry_count=0` |
| 人类等待 | Topic Gate 与最终交付决定都保持显式 stop / resume target |
| 续跑 | research wait、freshness wait 均从 persisted attempt reconcile 后继续 |
| 反转 | `semantic_update_replan -> hotspot_content_brief`；`topic_revalidation_replan -> hotspot_research` |
| 重建与幂等 | projection rebuild byte-stable；成功 command 返回 `hotspot_command_reused` 且不追加 event；失败 command 重放保持原失败，不误报 reused |
| false success | 缺 outcome、错误 digest、重试、错误 replan、合同/顺序、越界、未知字段和 artifact 篡改均阻断 |

完整正链只与冻结的 legacy contract fixture 比较；等待、续跑和反转分支采用 contract fixture，不伪称真实 legacy 双跑。所有 M3 shadow invocation 继续固定 `real_legacy_runtime_executed=false`、`runtime_switch_enabled=false`、`current_write_performed=false`、`runtime_certification=false`、`network_access_performed=false` 和 `provider_calls_performed=0`。这些是 shadow 运行事实，不覆盖 M4 的入口代际状态。因此 M3 本身仍只是控制面编译，不是 runtime certification。

### M4：新 session 切换

- 只有 direct 与 hotspot shadow 都通过后，新 session 才默认使用新内核。
- 旧 session 继续按原版本恢复，不做原地迁移。

M4 已完成。入口现在先提交
`intermediate/workflow-kernel/session-runtime-binding.json`，再提交对应
SHA256 marker；业务执行不能先于代际 commit。新 direct / hotspot session
默认绑定 `kernel_v1_current`。已有 binding 的 session 按 binding 续跑；没有
binding 但已有 version-pinned R7 plan 的旧 session 只读推断为 `legacy_r7`，
不回填 binding。

Windows PowerShell 5.1 的 19 个 fixture 覆盖新建、续跑、幂等、legacy
只读、回滚只影响未来 session、已有 current session 不降级，以及 binding
篡改、半提交、越界、错 route 和 activation gate false-success。M1 8/8、
M2 16/16、M3 21/21 同时继续通过。该结果只证明入口代际合同和旧链隔离，
不证明语义 worker 自主运行、真实 provider、私有真实账号或 L3。

### M5：兼容隔离

- 历史 blueprint、Schema 和 renderer 只由 compatibility catalog 加载。
- current runtime 禁止分支判断旧版本。

M5 已完成。current Workflow IR 删除 `legacy_blueprint_ref / legacy_node_refs`，
component catalog 删除 `source_registry_ref / legacy_step_kind`；legacy v0.6
也与 v0.1-v0.5 一起进入 12 条只读兼容目录。新 current session 使用
`session-runtime-binding v0.2`，不再绑定 compatibility catalog 摘要；M4
已存在的 v0.1 binding 继续按原文件恢复，不迁移。

`WorkflowCompatibilityLoader.ps1` 是旧 blueprint、registry、Schema 和 renderer
片段的唯一声明加载权。current caller 请求加载兼容资产会以
`current_runtime_compatibility_load_forbidden` 阻断；未知 blueprint、版本或
route 同样 fail closed。16 个 Windows PowerShell 5.1 fixture 已覆盖 current
无 legacy catalog 启动、旧 binding 恢复、旧 plan 只读解析、跨边界拒绝和
byte-stable resolution。M5.1 进一步把 15 项数据合同与 2 个实现文件迁入
`compatibility/legacy-r7/`，原 runtime/CLI 路径保留稳定 shim，并把旧 action
v0.3 固定为摘要钉住的回放快照。旧消费者继续通过 loader 工作；退休或删除数量为 0。

### M6：独立认证

- evaluator 先通过 conformance。
- runtime 再通过 start / advance / wait / resume / rebuild / reconcile。
- 最后执行 direct 与 hotspot 绑定同一 digest 的真实认证。

M6-H1 已把产品、架构、runtime、evaluator、fixture 五类显式文件冻结为
路径、长度、SHA256、分类摘要和总摘要。Evaluator conformance 使用隔离的
`state/checks/` work root，20 个已知答案与 2 个 freeze false-success 负例
通过 compile smoke；随后 evaluator/runtime 在 clean HEAD `9abcac0…` 上完成
同摘要认证。M6 direct suite 接入后冻结集合再次发生变化，旧证书保留审计，
但不授权新的 direct suite。

Runtime conformance 统一消费 M4 session entry、M2 direct 和 M3 hotspot 的
隔离机器报告，以 20 个断言覆盖 start / advance / wait / resume / rebuild /
reconcile，并用 4 个负例阻断 freeze、source revision、底层报告和 evaluator
digest false-success。Compile smoke 仍必须写
`not_run_compile_smoke_only`；只有新 clean HEAD 上 evaluator 与 runtime
逐字绑定同一 freeze digest，runtime 才能写 `certified`。

M6-H3 将 direct current control plane 单独编译为认证面：真实 session entry
先提交 `kernel_v1_current` binding，确定性 coordinator 再按 current IR 消费
25 个 typed fixture result，停在最终人工门禁，收到 typed fixture decision 后
续跑完成，并验证 projection rebuild、completed replay 与 registered writer。
它不调用真实 Skill、账号、网络、provider 或真实人工决定，因此只认证 direct
控制面；正式认证前仍需在 H3 clean HEAD 上重跑 evaluator/runtime 前置证书。

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

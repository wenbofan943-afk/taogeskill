# Architecture Control

> 状态：项目级架构控制合同；当前实现仍为 L2.8，不代表运行时或评测器已经通过 L3 认证。
> 主责：把产品、控制面、工作面、数据面、评测面和 AI 驾驭工程分开治理。
> 边界：本文件不替代业务产品定义，不决定具体技术栈，也不把存在一份 YAML 或 checker 误报为架构已经实现。

---

## 为什么需要独立架构层

项目早期选择“文件 + Skill + PowerShell + 轻量 coordinator”，适合 Alpha 阶段的人机协作验证。随着项目增加事件、投影、断点恢复、外部图片、副作用重放、双臂评测和成熟度认证，单次业务回归已经同时测试业务产品、运行时、合同编译器和评测器。

以后发现问题时，先判断它改变的是用户可见业务，还是系统如何执行、恢复、取证和评测。后者不得继续伪装成产品细节。

## 五个平面

`architecture_planes_contract: product_control_work_data_evaluation`

| 平面 | 主责 | 唯一写入边界 |
|---|---|---|
| 产品面 | 用户能做什么、业务取舍、输入输出和业务验收 | `product_definition` 确认清单 |
| 控制面 | 节点选择、停止、重试、恢复、人类门禁和副作用调度 | 确定性 coordinator / runner |
| 工作面 | Skill、Agent、renderer、capture、Image 2 等原子能力 | 只写本任务声明的 typed output / attempt / outcome |
| 数据面 | 运行事实、artifact、hash、lineage、projection | append-only event / immutable artifact；projection 只派生 |
| 评测面 | golden case、harness、grader、盲评、finalization | 独立 evaluator 版本和 certification evidence |

AI 驾驭工程包围以上五层，只负责路由、权限、预算、上下文和门禁，不替任何平面临场补产物。

## 问题应该回到哪一层

| 现象 | task_type | 不允许的旁路 |
|---|---|---|
| 改变用户可见行为、账号策略、视觉价值或交付口径 | `product_definition` | 直接改 checker 让旧行为变绿 |
| 同一问题影响两个以上业务 route，或改变 event、projection、resume、side effect、版本恢复 | `architecture_definition` | 继续给单个产品清单加运行时条款 |
| 已确认的产品 / 架构决定需要落到 Skill、runtime、Schema 或 checker | `skill_compile` | 编译时重新发明产品或架构 |
| 证明 runner 可独立选择、暂停、恢复、重放且不手改业务文件 | `runtime_certification` | 用一次业务 HTML 成功代替运行时认证 |
| 证明 evaluator、匿名投影、grader、finalizer 和 harness 自身可信 | `evaluation_certification` | evaluator 与被测版本同时变化后直接比较业务质量 |
| 只修索引、目录、孤岛文档或规则入口 | `docs_governance` | 把文档整理宣称为能力实现 |

## 架构硬边界

### 控制面只有一个状态推进者

语义 Agent 可以判断并返回 typed result，但不得直接修改 manifest、event、projection、current pointer 或 finalization。控制面消费 typed result 后，按版本化 transition 写入运行事实。

同一阶段如果 Codex 既生成业务结果，又临场选择下一节点、补字段、改状态并评判自己是否成功，该运行只能记 assisted，不能作为 L3 认证。

### 事件是运行事实，投影是缓存

对单个 session：

```text
append-only event + immutable artifact/attempt/outcome
  -> deterministic projection
  -> manifest / resume summary / status display
```

projection、manifest、STATUS 或聊天摘要不得反向成为历史事实。投影损坏时从事件重建；事件与 artifact hash 冲突时阻断，不用编辑投影掩盖。

### 非确定性和副作用必须任务化

网络、Image 2、浏览器 capture、当前时间、随机值和外部进程结果必须在原子 task 内持久化：

```text
request -> attempt -> outcome -> output reference -> direct consumer acceptance
```

恢复先读取已完成 outcome；只有未完成、可重试且幂等条件满足时才重试。不得让恢复路径重新询问模型或重复调用 provider 来“碰运气”。

### 合同只允许一个机器真源

目标态使用版本化 Workflow IR / IDL 描述对象、节点、状态、producer、consumer、版本和恢复语义，并由它生成或校验：

```text
Schema
registry
typed adapter skeleton
fixture catalog skeleton
checker contract
文档字段表
```

M1 已实现 Workflow IR 静态编译器：`routes/current-workflow-ir.json`、`routes/component-catalog.json` 和 `routes/compatibility-catalog.json` 是 current 控制面的三份手工机器真源，`tools/compile-workflow-ir.ps1` 从中生成 current 视图和 parity report。M2 完成 direct route 的隔离控制面 shadow；M3 通过 `tools/WorkflowKernelHotspotRuntime.ps1` 增加 hotspot 的 research、Topic Gate、freshness、等待续跑和 reversal replan，并把外部活动固定为 attempt/outcome/reconcile。M4 再以 immutable binding + SHA256 marker 把未来新 session 默认绑定到 `kernel_v1_current`，旧 R7 plan 只读续跑，回滚只影响未来新建。因此当前记录 `workflow_ir_codegen=m4_new_session_generation_switch_compiled`、`current_runtime_switch_authorized=true`、`runtime_certification=not_run`。旧 R7 runtime 仍维护既有 session 的多层合同，不能宣称已经完成 M5 兼容隔离或 L3。

### 评测器先自证，再评业务

评测面必须独立版本化，并先通过：

```text
golden object/array/scalar topology
合法/非法 typed input
不可比样本
拒绝路径
匿名映射隔离
grader / finalizer 已知答案
false-success
```

如果 evaluator 或 harness 在业务评测中被修改，本次评测结论标记 invalid，并使用新的 `evaluation_id / attempt_id` 重新认证。旧证据保持不可变。

### 认证期间冻结被测合同

`runtime_certification` 和 `evaluation_certification` 必须绑定：

```text
product_contract_digest
architecture_decision_digest
runtime_build_digest
evaluator_build_digest
fixture_catalog_digest
```

认证期间发现产品含义变化，停止认证并回 `product_definition`；发现架构语义变化，停止并回 `architecture_definition`。不能边改被测对象边累计成功样本。

## 架构决定的最小合同

跨平面或跨两个以上 route 的变更必须先形成可确认的 architecture decision：

```yaml
architecture_change_id:
problem_statement:
affected_planes: []
affected_routes: []
current_failure_evidence: []
options_considered: []
selected_option:
why_selected:
compatibility_and_migration:
rollback:
acceptance:
product_contract_digest:
decision_status: draft | confirmed | superseded
```

没有 `confirmed` 的架构决定，不进入跨平面 `skill_compile`。单 Skill 内、不会改变状态/恢复/评测语义的实现可写 `architecture_impact=not_applicable`，但必须说明理由。

## 事故到规则的晋升路径

新事故不再直接追加到根 `AGENTS.md`：

```text
incident evidence
-> failure fingerprint
-> root-cause class
-> reusable invariant
-> one mechanical gate/checker
-> scoped governance/reference doc
-> AGENTS only keeps a short invariant or pointer
```

晋升规则：

1. 单次、单场景事故先保留证据，不自动升级为全局规则。
2. 同一 fingerprint 重复，或已证明跨 route / 跨平台，才建立复用 invariant。
3. 能被机器检查的规则必须先有 checker / hook / runtime gate，再进入“必须遵守”清单。
4. 同一 invariant 只允许一个机器真源；其他文档只链接，不复制完整正文。
5. 每条治理规则必须有 `scope / owner / verifier / source_incident / retirement_or_review_trigger`。
6. 只有隐私、权限、不可逆写入、状态完整性和跨项目安全边界适合留在根 `AGENTS.md`。

## 当前基线与止损

当前事实：

```text
project_maturity: L2.8
deterministic_control_plane_authority: partial
workflow_ir_codegen: m3_direct_and_hotspot_shadow_runtime_compiled
workflow_ir_parity: pass_m1_static_m2_direct_16_of_16_and_m3_hotspot_21_of_21
runtime_certification: not_run_under_this_contract
evaluation_certification: partial_h5_specific_evidence_only
frontend_hard_budget_enforcement: not_available
required_reads_runtime_enforcement: partial_route_checker_only
project_level_hook_enforcement: not_configured
root_agents_compaction: pending_scoped_migration
```

因此当前止损顺序是：

```text
冻结已足够的 R8 产品草案
-> M1 三份机器真源与静态 parity（已完成）
-> M2 直供 shadow runtime（已完成）
-> M3 热点 shadow runtime（已完成）
-> M4 新 session 切换（已完成）
-> M5 compatibility isolation
-> evaluation_certification
-> runtime_certification
-> 重新执行绑定同一 digest 的业务认证
```

不得因本文件和 `routes/architecture-control.yaml` 已存在，就把项目升级为 L3。

治理建制决定 `ARCH-20260718-001` 已完成：增加架构定义、运行时认证和评测器认证三个独立 route，建立五平面与规则晋升合同。

现行架构决定为 `ARCH-20260718-002`，见 `workflow-kernel-simplification.md`：采用轻量本地内核、单一 Workflow IR、七个顶层业务阶段和 shadow / strangler 迁移。M1 已完成三份机器真源与静态 parity；M2 direct 16/16、M3 hotspot 21/21 继续通过。M4 经单次授权完成 19/19：新 session 默认提交 `kernel_v1_current` 代际 binding，旧 R7 plan 只读续跑，回滚只影响未来新建 session，禁止原地迁移。当前 `runtime_certification=not_run`，项目仍为 L2.8；下一阶段 M5 compatibility isolation 仍需单次授权。

## 研究依据与本项目取舍

- [Temporal History Service](https://github.com/temporalio/temporal/blob/main/docs/architecture/history-service.md)：事件历史足以恢复执行状态；本项目只吸收单 session append-only fact 与可重建 projection，不引入服务端集群。
- [LangGraph Functional API](https://docs.langchain.com/oss/javascript/langgraph/functional-api)：checkpoint、确定性恢复、task 化副作用和幂等；本项目先落实到本地 runner 合同。
- [OpenAI：How evals drive the next chapter](https://openai.com/index/evals-drive-next-chapter-of-ai/)：专用测试环境、真实案例、golden set 和人类审计 grader。
- [OpenAI：可信第三方评测方法](https://openai.com/index/trustworthy-third-party-evaluations-foundations/)：harness、工具、重试、预算与环境都是评测结论的一部分。
- [Codex ExecPlans](https://developers.openai.com/cookbook/articles/codex_exec_plans)：长任务使用自包含、可恢复、持续更新的执行计划；本项目以后用架构决定和 checkpoint 代替超长聊天记忆。

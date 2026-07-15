# Run Control

> 状态：项目级运行控制合同
> 主责：限制自动继续的作用域、任务类型跃迁、连续执行预算、重复修复和业务结果收口。
> 边界：本合同约束项目内 agent 行为并由 route checker 校验；它不能改变 Codex 前端模型，也不能冒充平台级硬中断器。

---

## 设计依据

成熟 workflow 把停止条件和恢复条件做成运行时参数，而不是只写提示词：

- OpenAI Agents SDK 提供 `max_turns` 和 tracing。
- LangGraph 提供 recursion limit、checkpoint 和 interrupt。
- Pydantic AI 提供 request、tool call 和 token usage limits，以及 deferred tool approval。
- OpenHands 同时使用最大迭代与重复模式 stuck detection。
- Step Functions / Temporal 把 timeout、retry、catch、heartbeat 和断点恢复做成执行合同。

本项目保持轻量实现，不引入外部调度器。`routes/run-control-profiles.yaml` 保存预算，`routes/workflow-routes.yaml` 为每个 task_type 绑定运行控制字段，`tools/validate-route-schema.ps1` 检查合同闭合。

`LONGRUN-20260715-001` 观察到一次交互任务连续运行 137 分钟、447 次工具调用并发生 4 次上下文压缩。当前预算以这次事故为校准依据，状态为项目暂定默认；有代表性运行证据后再调整，不能凭单次感觉无限放宽。

## 三层职责

```text
AGENTS / governance docs
  说明原则、权限和失败语义

routes/*.yaml
  机器可读声明 task scope、budget profile 和 transition authorization

Codex / workflow runtime
  在可观察范围执行、写 checkpoint、停止并向用户交付
```

项目层目前不能读取 Codex 前端的完整实时 token、压缩或内部 turn 计数，也不能强制终止前端任务。因此：

```text
可观察指标：到限前停止开始新的动作，写 checkpoint，并结束当前回复。
暂不可观察指标：不得宣称已硬门禁；在首次可观察边界执行 checkpoint_and_return。
```

## Route 必填合同

每个 task_type 必须声明：

```yaml
run_control:
  budget_profile: interactive_standard
  auto_continue_scope: current_task_type
  business_checkpoint: required_before_followup
  task_transition_authorization: explicit_single_use
  profile_escalation_authorization: explicit
  repair_scope: current_task_type_only
```

字段语义：

| 字段 | 规则 |
|---|---|
| `budget_profile` | 必须引用 `routes/run-control-profiles.yaml` 已登记 profile |
| `auto_continue_scope` | 自动继续只在该作用域内生效；`none` 表示任务结果完成即收口 |
| `business_checkpoint` | 主业务产物完成后先交付，不等待旁支工程扫尾 |
| `task_transition_authorization` | 跨 task_type 必须由当前用户消息或当前待确认节点明确授权；授权只消费一次 |
| `profile_escalation_authorization` | dev/test 不得因 checker 历史规则自行升级到 public |
| `repair_scope` | 只允许修当前 task_type 内、当前授权目标直接需要的缺陷 |

“按 AGENTS”只表示遵循本项目编排，不扩大写入、任务类型、build profile 或远端权限。“认可 / 同意 / 按你说的修”只确认当前明确摆在用户面前的一个决定，不能授权尚未出现的后续任务链。

## 运行状态

```text
running
business_complete
waiting_transition_approval
checkpoint_budget_exhausted
stuck_repeated_failure
blocked
completed
```

`business_complete` 是可向用户交付的正式检查点，不等于所有工程旁支都已完成。到达后必须先报告业务结果；若发现需要切到 `skill_compile`、`docs_governance` 或 `public`，写入 follow-up 并按跃迁规则处理。

## 熔断规则

以下任一条件命中，停止发起新的动作，保存已完成证据并结束当前任务：

1. 当前 profile 的连续时间、可观察工具调用量或上下文压缩预算到限。
2. 同一 failure fingerprint 达到 profile 的重复上限。
3. 同一根因修复轮数达到 profile 上限但验收仍未通过。
4. 需要进入未获授权的新 task_type。
5. dev/test 任务需要升级为 public 构建或远端验证。
6. 主业务结果已经完成，剩余工作只属于工程加强、治理沉淀或发布门禁。

熔断不是失败。必须输出：

```text
checkpoint_reason
completed_scope
pending_scope
last_verified_artifact
failure_fingerprint（如有）
recommended_resume_route
```

## 重试与修复

```text
transient_error       有界退避重试
external_side_effect  先 reconcile，再决定是否重试
deterministic_failure 不盲重试，直接分类和修复
product_gap           停到 product_definition
task_type_change      停到 waiting_transition_approval
same_failure          达上限后 stuck_repeated_failure
```

不得把“递归排查”解释为无限修复。递归排查只扩展诊断覆盖面；是否进入旁支产品开发、源码修复、公开包或发布验证，仍由 task_type 和授权边界决定。

## Gate 选择

检查按当前改动和当前 build profile 选择：

```text
dev     当前原子变更的 parser / focused fixture / runtime smoke / 必需合同检查
test    当前测试矩阵及其直接依赖，不修复未授权旁支
public  完整 public candidate、archive、privacy、Windows matrix 和 release gates
```

dev/test 发现未来 public gate 需要复测时，记录 `public_validation=not_run_in_current_profile`；它不能单独阻断与公开包装无关的本地原子提交。只有当前任务就是公开包装、发版或修改 public build/release contract 时，public gate 才属于本轮完成定义。

# After Task Guidance

> 状态：任务后导航规则
> 主责：定义每个 task_type 完成、等待、失败或阻断后，agent 如何收口并把用户带到下一步。
> 边界：本文件只管项目级编排，不替代具体 skill 的 `SKILL.md` / `CONTRACT.md`。

---

## 成熟编排层对标

成熟 workflow 编排层通常会把任务结束后的处理拆成四类：

```text
success          已完成，给结果、产物位置、检查结果和推荐下一步。
waiting_human    需要人判断，给推荐动作、原因和可直接回复的话。
blocked          被门禁阻断，说明阻断原因、已保留证据和恢复方式。
failed           执行失败，给失败位置、可重试路径、降级路径和日志位置。
```

本项目采用轻量实现：不引入复杂调度器，但每个 `task_type` 必须在 `routes/workflow-routes.yaml` 中声明任务后导航和 `run_control`。运行控制真源见 `run-control.md` 与 `routes/run-control-profiles.yaml`。

## 机器字段

每个 route 必须具备：

```text
run_control:
  budget_profile: interactive_standard
  auto_continue_scope: current_task_type
  business_checkpoint: required_before_followup
  task_transition_authorization: explicit_single_use
  profile_escalation_authorization: explicit
  repair_scope: current_task_type_only
after_completion:
  auto_continue_allowed: true / false
  on_success: ...
  on_waiting_human: ...
  on_blocked: ...
  suggested_user_replies:
    - ...
```

字段含义：

| 字段 | 含义 |
|---|---|
| `run_control.budget_profile` | 当前连续执行预算和熔断口径 |
| `run_control.auto_continue_scope` | 当前 task_type 内允许自动推进到哪里 |
| `run_control.business_checkpoint` | 主业务结果完成后是否必须先交付 |
| `run_control.task_transition_authorization` | 跨 task_type 的授权是否明确且单次消费 |
| `run_control.profile_escalation_authorization` | dev/test 是否可以升级 public；默认必须明确授权 |
| `run_control.repair_scope` | 自动修复不得越过当前 task_type |
| `auto_continue_allowed` | 是否在 `auto_continue_scope` 内自动推进；不授权跨 task_type |
| `on_success` | 成功后默认说什么、指向哪里 |
| `on_waiting_human` | 需要人判断时如何引导，不得只写“请确认” |
| `on_blocked` | 门禁阻断或条件不足时如何解释和恢复 |
| `suggested_user_replies` | 用户可以直接复制回复的话 |

## 输出要求

任务结束时必须按人话输出：

```text
1. 我完成了什么。
2. 结果 / 产物在哪里。
3. 检查结果是什么。
4. 现在停在哪里，为什么停。
5. 推荐下一步是什么。
6. 用户可以直接说哪几句话。
```

如果任务可以在声明的 `auto_continue_scope` 内继续，不得要求用户回复“继续”。达到 scope 终点、业务完成检查点、任务跃迁、profile 升级或预算熔断时必须收口。

如果任务必须停在人类门禁，不得只给字段名或状态名；必须说明为什么这一步需要人判断。

环境兼容任务结束时，除通用六项外还必须给：测试过的宿主 / 路径 / source 或 zip 组合、未测试轴、是否改过系统级配置、是否发现 archive false success，以及当前公开支持口径是否需要产品确认。不能用“Windows 测试通过”概括部分矩阵。

## 自动继续边界

默认允许自动继续：

```text
选题确认后的 Brief -> 口播 -> 画中画 -> 质检 -> 平台包装 -> 最终 HTML。
局部返工修完后的 final-delivery.html 重建。
脱敏样例测试中的非破坏性检查。
support log 自动定位最近 run。
```

这些自动动作必须属于当前 route 的同一业务链。`content_run` 中 Brief 到最终 HTML 是同一 blueprint；从最终 HTML 缺陷进入通用源码修复、文档治理或公开包验证不是同一 scope。

默认必须停下：

```text
换账号后的账号档案确认。
候选选题选择。
产品定义进入 skill 编译前。
push / tag / GitHub Release / repo metadata 等远端写入前。
读取或导出包含内容细节的反馈日志前。
隐私命中、字段门禁失败、公开包净化失败。
主业务产物已完成而剩余工作属于新的 task_type。
达到 run-control 预算或重复失败上限。
dev / test 需要升级为 public profile。
```

已确认进入 skill / 代码开发后，本轮原子变更通过检查且可从工作区安全隔离时，本地 commit 和小扫地属于开发收尾，不再设置额外人类确认。用户明确说“只改不提交”或工作区无法安全拆分时，停在本地结果并解释原因。

## 业务完成优先交付

`business_complete` 与 `completed` 分开：

```text
business_complete  用户要的主要交付物已经可验收，必须立即汇报。
completed           当前授权 task_type 的原子收尾也已完成。
```

如果业务完成后发现工程缺陷：

```text
1. 保留并交付当前业务产物，诚实说明限制。
2. 记录 pending_followup 和建议 route。
3. 当前授权包含该 route 时可在新阶段继续；否则等待明确单次授权。
4. 不得把 public build、治理沉淀或旁支加强件塞在业务回复之前。
```

## 预算熔断后导航

到达 `checkpoint_budget_exhausted` 或 `stuck_repeated_failure` 时，最终回复至少说明：

```text
为什么停止
已经完成什么
最后一个可验证产物 / commit / checkpoint
尚未完成什么
是否发生 task_type 或 profile 跃迁
推荐如何从断点继续
```

预算熔断不得写成“任务失败”；它表示本轮连续执行结束，后续可从 checkpoint 恢复。

## 失败后导航

失败后不得只说“失败了”。必须给恢复路线：

```text
可重试：说明重试什么。
可降级：说明降级后交付什么。
需人工：说明用户只需要提供什么。
需审计：说明日志 / 报告在哪里。
```

示例：

```text
这次已经完成本地原子提交，但没有进入 GitHub 写入，因为没有得到推送 / 发版授权。

本地编排规则已经修完，检查也过了。你下一步可以直接说：
- “推送到 GitHub”
- “继续下一轮本地开发”
- “给我看这轮 commit”
```

## 禁止写法

```text
请确认。
是否继续？
等待人工确认。
下一步你想做什么？
需要你选择状态。
```

除非用户主动要求开放讨论，否则 agent 必须给出推荐动作。

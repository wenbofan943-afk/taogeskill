# Model And Compute Routing

> 状态：项目级模型、推理强度和速度路由真源说明
> 机器真源：`routes/compute-profiles.yaml`
> 运行配置：`.codex/config.toml` 与 `.codex/agents/*.config.toml`
> 边界：本规则只选择执行算力，不替代 task route、Skill 合同或人类门禁。

## 三根独立旋钮

```text
model tier       Sol / Terra / Luna，决定能力、速度和成本档位
reasoning effort low / medium / high / xhigh / max，决定思考预算
speed tier       normal / fast，决定服务速度，不负责改变模型或推理强度
```

不得把三者合并成一个“模式”，也不得声称写进 `AGENTS.md` 就已经切换运行模型。

## 项目默认值

```text
model: gpt-5.6-terra
reasoning_effort: medium
speed: normal
```

默认值由 `.codex/config.toml` 承载。用户在 Codex 界面、启动参数或当前任务中显式选择的模型、推理强度和 service tier 优先。

项目配置只有在 Codex 从本项目根目录建立 / 识别任务且项目已受信任时才应视为已加载。projectless 任务即使按指令读写本目录，也不得据此宣称 `.codex/config.toml` 已对当前任务生效；应把 `runtime_profile_observed` 记为实际可观察值或 `unknown`。

## 路由表

| compute_profile | 模型与强度 | 主要任务 |
|---|---|---|
| `content_standard` | Terra + medium | 内容生产、账号建档、返工、多分支 |
| `product_deep` | Sol + high | 产品定义、成熟项目调研、问题诊断 |
| `compile_deep` | Sol + high | Skill 编译、checker、模板和治理编译 |
| `release_critical` | Sol + xhigh；支持时优先 max | 发版、隐私、源码边界、最终综合审计 |
| `operations_standard` | Terra + medium | 测试、仓库维护、分发包构建 |
| `mechanical_light` | Luna + low | 索引、日志导出和边界明确的机械任务 |

当前 Codex 配置参考稳定列出的静态推理值到 `xhigh`。因此角色 TOML 使用 `xhigh`；运行环境明确支持 GPT-5.6 `max` 时，`release_critical` 可以在当前任务中升级为 `max`。

## 执行顺序

```text
1. task-routing 先确定 task_type。
2. workflow-routes.yaml 读取 compute_profile。
3. compute-profiles.yaml 解析 role、model、reasoning_effort 和 speed_policy。
4. 能使用已注册 role 时，优先按 `.codex/agents/*.config.toml` 执行。
5. 主任务无法中途切换时，比较当前运行档位与目标档位。
6. 非关键任务继续执行，并在 trace 记录 fallback_current_runtime。
7. 产品确认、Skill 编译、发版审计等关键阶段若档位明显不足，只提示用户一次；不要每一步重复询问。
8. 当前档位等于或高于目标档位时直接继续，不打扰用户。
```

## Fast 规则

Fast 默认关闭。只有用户明确表达时间敏感，或明确选择 Fast 时才能启用 `service_tier = "fast"`。

Fast 只作为速度覆盖层：

```text
保留当前 model
保留当前 reasoning_effort
记录 speed_override=fast
不把 Fast 描述成更聪明或更浅的模型
不可用时回退 normal，不阻断工作流
```

## 运行日志字段

重要产品、编译、测试和发版任务应在 trace 或状态记录中保留：

```text
task_type
compute_profile_requested
model_requested
reasoning_effort_requested
speed_policy_requested
runtime_profile_observed
compute_route_status: matched | higher_than_required | fallback_current_runtime | unknown
fallback_reason
```

不能在无法读取当前运行配置时伪造 `matched`，应记录 `unknown`。

## 非 Codex 环境

`.codex/` 只对支持该配置的 Codex 环境生效。其他 Agent 仍可读取本文件和 `routes/compute-profiles.yaml` 作为能力建议，但必须：

```text
不假装已切换模型
记录实际 provider / model（可识别时）
不能切换时继续执行或按关键门禁提示一次
保持 Skill 字段、状态和交付协议不变
```

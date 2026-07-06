# Skill 执行透明度与成熟度规范

> 状态：全局规则  
> 主责：区分“skill 自己完成了什么”和“agent 临场扶着完成了什么”，为未来发布 skill 做成熟度判断。  
> 边界：本规范只记录内容 workflow 的执行透明度，不改变客户端、服务器、平台账号或发布链路。

---

## 一、为什么要记录

跑通一条内容不等于 skill 已经成熟。

如果生产链路里大量动作靠 agent 临场补判断、补文件、补字段、补目录、补链接，那么这叫“agent 扶着 skill 跑通”，不能当成可发布 skill。

每轮真实运行必须让人看得出来：

```text
哪些是 skill 规则内产出。
哪些是 agent 临场判断。
哪些是用户明确决策。
哪些是环境能力，比如浏览、文件读写、image 生成。
哪些是流程缺口，被 agent 补上了。
哪些缺口需要反写到 skill，下一轮不能再靠临场发挥。
```

---

## 二、执行来源分类

| execution_source | 含义 | 能否算 skill 成熟能力 |
|---|---|---|
| skill_defined | skill 文档明确要求，agent 只是按步骤执行 | 可以 |
| skill_inferred | skill 有方向，但细节靠 agent 推断补齐 | 部分可以，需补规则 |
| agent_orchestrated | skill 没写清，agent 临场编排完成 | 不能直接算 |
| agent_created_rule | 运行中发现缺口，agent 新增规则后继续 | 不能算本轮原始 skill 能力 |
| user_decision | 用户做出的方向、采用、返工或确认 | 不是 skill 能力 |
| environment_capability | Codex / 浏览器 / image / 文件系统等环境能力 | 不是 skill 本身能力 |
| manual_fallback | 环境或 skill 不支持，agent 手工降级完成 | 不能算 |

---

## 三、成熟度等级

| maturity_level | 标准 |
|---|---|
| L0 手工脚本 | 主要靠 agent 判断，skill 只是方法论参考 |
| L1 可指导 | skill 能告诉 agent 怎么做，但输入输出还需要人扶 |
| L2 可复跑 | 按固定输入能稳定产出固定交接物，但仍需 agent 补少量边界 |
| L3 可发布候选 | 输入、输出、停顿点、状态、失败处理都明确，agent 只执行不补规则 |
| L4 可产品化 | 可跨账号、跨 session 稳定运行，有测试样例、失败用例和迁移说明 |

发布前最低要求：核心链路 skill 必须达到 L3；如果某个节点只有 L1/L2，README 必须写清限制。

---

## 四、每轮必须生成 execution trace

每个 session 必须有：

```text
accounts/{账号名}/runs/{session_id}/intermediate/00-execution-trace.md
```

最小格式：

```markdown
# Execution Trace

## 本轮摘要
- session_id：
- account：
- started_at：
- current_stage：
- trace_status：active / waiting_human / completed / blocked

## 执行动作表
| step | action | expected_skill | execution_source | evidence | agent_intervention | result |
|---|---|---|---|---|---|---|

## Skill 成熟度观察
| skill | maturity_level | 本轮表现 | 需要反写的规则 |
|---|---|---|---|

## Agent 扶跑清单
| 缺口 | agent 怎么补的 | 是否已反写到规则 | 下轮验收方式 |
|---|---|---|---|

## 发布风险
- 如果现在发布 skill，用户可能卡在哪里：
- 哪些步骤还依赖 Codex agent 临场判断：
- 哪些能力其实来自环境，不来自 skill：
```

---

## 五、manifest 必填字段

每个 `manifest.yaml` 必须记录：

```yaml
execution_trace:
  path:
  trace_status:
  agent_assist_level: low / medium / high
  skill_maturity_summary:
```

`agent_assist_level` 含义：

```text
low：agent 只按 skill 执行，未补规则。
medium：agent 补了少量文件、索引或边界，但主流程由 skill 驱动。
high：agent 大量补流程、补判断、补规则，本轮不能视为 skill 独立跑通。
```

---

## 六、反写规则

发现 agent 扶跑后，必须判断：

```text
是一次性项目治理问题 -> 写入 docs/reference 或 docs/explanation。
是某个 skill 缺规则 -> 反写到对应 SKILL.md。
是字段缺失 -> 反写到 交接物字段词典.md。
是目录 / 输出摆放问题 -> 反写到 文档治理与目录规范.md。
是用户引导问题 -> 反写到 人类引导与任务后导航规范.md。
```

反写后，下一轮真实内容必须验证：同样问题不能再靠 agent 临场补。

---

## 七、对外发布判断

准备发布 skill 前，必须至少回答：

```text
这个 skill 离开当前 agent，能不能让另一个 AI 看懂怎么跑？
输入不完整时，它知道停在哪里吗？
用户说“认可 / 选题 / 确认采用”时，它知道自动进入哪里吗？
产物路径是否固定？
失败时是否有降级策略？
execution trace 是否显示 agent_assist_level 连续降低？
```

如果答案不清楚，不发布；先继续跑真实样本和修规则。

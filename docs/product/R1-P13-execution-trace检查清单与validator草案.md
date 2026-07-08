# R1-P13 Execution Trace 检查清单与 Validator 草案

> 状态：已确认并已编译引用  
> 所属路线：R1 方法论编译成执行合同  
> 覆盖问题：P02 依赖 agent 扶着跑、P13 execution trace 只是记录不是检查器、P08 人类门禁自动推进检查子集  
> 边界：本文件只定义检查口径和未来 validator 输入输出；当前不写脚本、不改 `skills/*/SKILL.md`。

---

## 1. 为什么要补 P13

当前 `intermediate/00-execution-trace.md` 已经能记录：

```text
哪些动作来自 skill_defined。
哪些动作来自 skill_inferred。
哪些动作来自 agent_orchestrated / agent_created_rule。
哪些动作来自 user_decision。
哪些能力来自 environment_capability。
```

但它还只是记录，不是检查器。

如果没有检查口径，真实运行仍然会出现：

```text
一条内容跑通了，但不知道是不是 skill 自己跑通。
agent 补了流程，但没有反写到合同。
自动推进停错位置，但 trace 只写“等待确认”。
manifest 指向的产物缺失，但没人提示。
最终声称可发布，实际只是 agent 临场扶着完成。
```

P13 的目标是：让 execution trace 具备“验收”和“反写导航”能力。它不要求马上自动化，但每一项必须能被人和 AI 按同一标准检查。

---

## 2. 输入范围

P13 检查一条 session 时，至少读取：

```text
accounts/{账号名}/runs/{session_id}/manifest.yaml
accounts/{账号名}/runs/{session_id}/intermediate/00-execution-trace.md
manifest.yaml 里 paths 指向的所有必需产物
本轮涉及 skill 的 CONTRACT.md
交接物字段词典.md
docs/reference/人类引导与任务后导航规范.md
docs/reference/skill执行透明度与成熟度规范.md
```

如果 `manifest.yaml` 或 `00-execution-trace.md` 缺失，本轮不得标记为 L3 可发布候选样本。

---

## 3. Trace 必备结构

每条 session 的 execution trace 必须包含以下区块：

| 区块 | 检查目的 | 缺失后果 |
|---|---|---|
| 本轮摘要 | 确认 session、账号、阶段、状态和 agent_assist_level | BLOCKER |
| 执行动作表 | 逐步说明 expected_skill、execution_source、evidence、result | BLOCKER |
| Skill 成熟度观察 | 判断本轮 skill 是 L1/L2/L3 还是 agent 扶跑 | BLOCKER |
| Agent 扶跑清单 | 把临场补规则转成可反写项 | WARN，若为空但 action table 有 agent_created_rule 则 BLOCKER |
| 合同覆盖检查 | 检查每个 expected_skill 是否有合同字段支撑 | BLOCKER |
| 自动推进检查 | 检查选题确认后是否自动到底，平台包装后是否误停 | BLOCKER |
| 人类门禁检查 | 检查只在账号确认、选题确认、最终采用等允许位置停 | BLOCKER |
| 产物路径检查 | 检查 manifest paths 是否存在，current_artifact 是否可达 | BLOCKER |
| 来源与时效检查 | 检查 research_run_id、来源时间、热点定位是否断链 | WARN 或 BLOCKER |
| 发布风险 | 标出 skill 发布后用户可能卡在哪里 | WARN |

当前规范里的最小 trace 模板还不含全部区块。R1 编译时应把本清单吸收到 trace 模板或 validator 草案里。

---

## 4. 检查等级

P13 使用三档结果：

| 等级 | 含义 | 是否阻断 R1 编译 |
|---|---|---|
| BLOCKER | 会导致断链、串台、错停、误判成熟度或越界发布 | 阻断 |
| WARN | 不阻断单次运行，但必须进入反写清单或样本风险说明 | 不阻断，但影响 L3 判断 |
| INFO | 只是说明环境、用户决策或可选增强 | 不阻断 |

---

## 5. BLOCKER 规则

出现以下任一情况，`overall_result` 必须为 `fail`：

```text
缺少 manifest.yaml。
缺少 intermediate/00-execution-trace.md。
manifest.current_artifact 指向不存在或不在本 session 下。
manifest.paths 中必需产物缺失。
execution_trace 缺少本轮摘要、执行动作表或 Skill 成熟度观察。
action table 有 agent_created_rule，但 Agent 扶跑清单没有对应反写项。
选题确认后停在“是否继续写口播 / 是否继续做分发包”。
平台包装完成后误当成人工门禁，未自动生成 content_delivery_record / final-delivery.html。
人类门禁出现在合同未允许的位置。
research_run_id 没有贯穿 topic_card -> content_delivery_record。
发生自动发布、登录平台、自动评论、私信、互动等越界行为。
同一 session 混入多个独立选题正文，且没有 fan-out 规则。
最终交付页声称已有图片，但 image_assets 记录为 pending / failed / manual_required。
```

---

## 6. WARN 规则

出现以下情况，`overall_result` 可以为 `pass_with_warnings`：

```text
agent_assist_level = medium。
skill_inferred 占比偏高，但没有改变主流程。
根目录索引或汇总表仍由 agent 手工维护。
观点对象 / 产品对象由 agent 建议生成，但已落盘且边界清楚。
来源链接可用，但缺少更细的来源质量等级。
图片使用外部或手工降级，但已标记 image_status。
某个 skill 合同已有字段，但样本还没验证到失败分支。
```

若 `agent_assist_level = high`，本轮不得作为 L3 样本；若连续多轮为 high，应回到产品定义或合同重写。

---

## 7. Validator 输出字段

未来 validator 可以输出 Markdown、YAML 或 JSON，但字段必须稳定：

```yaml
trace_check_id:
session_id:
account:
checked_at:
contract_set_version:
trace_status:
overall_result: pass / pass_with_warnings / fail
blocking_issues:
warnings:
info:
agent_assist_level:
skill_defined_steps:
skill_inferred_steps:
agent_orchestrated_steps:
agent_created_rule_steps:
user_decision_steps:
environment_capability_steps:
maturity_level_observed:
r1_compile_ready: yes / no
required_backwrites:
next_action:
```

`required_backwrites` 必须指向明确位置：

```text
skills/{skill}/CONTRACT.md
skills/{skill}/SKILL.md
交接物字段词典.md
docs/reference/人类引导与任务后导航规范.md
docs/reference/文档治理与目录规范.md
docs/reference/skill执行透明度与成熟度规范.md
docs/product/{对应产品定义}.md
```

---

## 8. R1 编译准备门槛

R1 进入第一轮 `SKILL.md` 编译前，P13 至少要达到：

```text
trace 必备结构已定义。
BLOCKER / WARN / INFO 规则已定义。
validator 输出字段已定义。
能对真实样本做人工判定。
能指出哪些问题要反写到合同、字段词典或 reference。
```

R1 编译后，若要声称 L3 可发布候选，则至少需要：

```text
一条 sample run 的 overall_result = pass 或 pass_with_warnings。
核心链路没有 BLOCKER。
agent_assist_level 不高于 medium，核心步骤最好为 low。
所有 agent_created_rule 都已反写到合同或 reference。
人类门禁和自动推进检查通过。
最终 HTML、manifest、trace、content_delivery_record 闭合。
```

---

## 9. 用 SAMPLE-HISTORICAL-002 校准

真实样本 `accounts/示例行业观察号/runs/SAMPLE-HISTORICAL-002/` 可作为 P13 第一条校准样本。

初步判断：

```text
overall_result：pass_with_warnings
agent_assist_level：medium
maturity_level_observed：L2 可复跑，未到 L3
```

主要 WARN：

```text
观点对象 P-auto-observation-traffic 由 agent 基于账号定位建议生成。
根目录汇总和索引仍由 agent 手工维护。
trace 已记录扶跑点，但尚无合同覆盖检查和自动推进检查区块。
```

没有直接判为 BLOCKER 的原因：

```text
三篇都做已拆成独立 session，没有把多个正文混入同一最终交付。
manifest 指向了本 session 内产物。
final-delivery.html 已作为人类验收入口。
没有自动发布、登录、评论、私信或平台互动。
```

这说明 P13 的价值不是否定当前产出，而是把“这次哪里靠 agent 扶”显性化，作为 R1 编译前的反写导航。

---

## 10. 和 P02 的关系

P02 的问题是“依赖 agent 扶着跑”。P13 是 P02 的量尺。

没有 P13，就只能凭感觉说：

```text
这次好像跑通了。
这次好像还靠 agent。
```

有 P13 后，应改成：

```text
本轮 agent_assist_level = medium。
agent_created_rule_steps = 0。
agent_orchestrated_steps = 2。
required_backwrites = 2。
r1_compile_ready = yes / no。
```

因此 P02 不单独靠一句“减少 agent 扶跑”解决，而是通过：

```text
P01 合同
P13 检查清单
P14 编译规则
P15 skill 粒度
P08 自动推进 / 人类门禁
```

一起收敛。

---

## 11. 不做事项

当前 P13 不做：

```text
不写 validator 脚本。
不改 SKILL.md。
不重跑 SAMPLE-HISTORICAL-002。
不把所有 WARN 都升级成阻断。
不引入 workflow engine。
不要求所有样本马上达到 L3。
```

当前只把检查标准定清楚，等待 R1 整组确认后，再进入合同和 skill 编译。


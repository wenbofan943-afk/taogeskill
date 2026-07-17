# R1-P02 Agent 扶跑收敛与可编译判定

> 归档状态：historical_audit_only；2026-07-18 移出当前产品热路径，不得作为 current 合同真源。

> 状态：已确认并已编译引用  
> 所属路线：R1 方法论编译成执行合同  
> 覆盖问题：P02 依赖 agent 扶着跑，并联动 P01、P08、P13、P14、P15  
> 边界：本文件只定义“如何判断 agent 扶跑下降”和“R1 是否可进入 skill 编译”；当前不改 `skills/*/SKILL.md`。

---

## 1. P02 要解决什么

涛哥指出的问题不是“agent 不能参与”，而是：

```text
如果一个 workflow 只有在当前 Codex agent 扶着时才跑得通，
未来开源给别人下载后，另一个 AI 或普通用户会不知道怎么继续。
```

因此 P02 的目标不是消灭 agent，而是把 agent 从“临场发明流程的人”降级为“按合同执行的人”。

正确目标：

```text
agent 可以表达、整理、落盘、解释。
agent 不应该临场决定核心流程、字段、门禁、目录、状态和交接物。
```

---

## 2. 扶跑分级

P02 采用 `docs/reference/skill执行透明度与成熟度规范.md` 的 execution_source，并补充产品判定：

| execution_source | P02 判定 | 是否可算 skill 能力 |
|---|---|---|
| `skill_defined` | 健康 | 是 |
| `skill_inferred` | 可接受但要下降 | 部分算，需逐步反写 |
| `agent_orchestrated` | 风险 | 不能算，必须记录原因 |
| `agent_created_rule` | 阻断 | 不能算，必须反写后重测 |
| `user_decision` | 正常门禁 | 不算 skill 能力 |
| `environment_capability` | 正常环境能力 | 不算 skill 能力 |
| `manual_fallback` | 降级 | 不算，需写明限制 |

开源 alpha 允许少量 `skill_inferred`，但核心链路不能依赖 `agent_created_rule`。

---

## 3. R1 可编译前的扶跑阈值

进入第一轮 `SKILL.md` 编译前，R1 不要求已达到 L3，但必须满足：

```text
核心链路 8 个 skill 均有 CONTRACT.md。
每个合同都有自动推进、人类门禁、失败处理和 execution_trace 要求。
P13 已定义 trace 检查清单和 BLOCKER / WARN 规则。
P14 已定义方法论从讨论稿进入合同 / 字段 / SKILL / validator 的编译路径。
P15 已定义 skill 粒度、主入口、专项入口和兼容入口。
不再存在必须靠 agent_created_rule 才能继续的 R1 核心规则。
```

换句话说，R1 可编译不是说“skill 已经成熟”，而是说：

```text
现在已经知道该把哪些合同规则编译进哪些 SKILL.md，
也知道编译后用什么 trace / sample run 去验证。
```

---

## 4. R1 不可编译信号

出现以下情况，R1 不应进入 skill 编译：

```text
某个核心 skill 没有 CONTRACT.md。
合同没有明确主输入和主输出。
选题确认后是否自动到底仍有争议。
平台包后是否还需要“确认采用”仍有争议。
execution trace 只能写记录，不能判断 BLOCKER / WARN。
methodology 进入 SKILL.md、字段词典、reference 的路径不清。
新旧入口关系不清，hotspot-copywriting-research 仍可能承载新逻辑。
内容质量只剩 Hook，没有正文信息密度、兑现和核心机制检查。
仍需要 agent 临场决定目录、状态或产物边界。
```

这些不是代码问题，是产品定义未闭合。

---

## 5. R1 编译后的验证目标

R1 编译后，至少要跑一条 sample run 或真实轻样本，并用 P13 口径检查：

```text
overall_result = pass 或 pass_with_warnings。
agent_assist_level <= medium。
核心步骤没有 agent_created_rule。
自动推进没有错停。
人类门禁只出现在允许位置。
manifest、execution trace、final-delivery.html、content_delivery_record 闭合。
required_backwrites 有明确归属，不能只写“以后优化”。
```

如果样本里 `agent_assist_level = high`，R1 编译不算通过，需要回到合同或 SKILL.md 修订。

---

## 6. P02 对各问题的收敛关系

P02 不单独新增很多规则，而是用其他 R1 产物收敛：

| 依赖 | 解决的扶跑风险 |
|---|---|
| P01 Skill Contract | 不再靠 agent 猜输入输出、门禁、下一步 |
| P13 Trace 检查清单 | 不再靠感觉判断“是不是扶着跑” |
| P14 方法论编译规则 | 不再让讨论稿停在文档里，执行时靠 agent 回忆 |
| P15 Skill 粒度治理 | 不再让巨型 skill 或旧入口混入新逻辑 |
| P08 门禁合同 | 不再让用户说“继续写口播 / 继续做分发包” |
| 内容质量补充 | 不再只靠 Hook，正文密度和兑现进入合同 |

因此 P02 的验收不是再写一个大 skill，而是确认 R1 的这些产品定义可以汇合成一轮编译任务。

---

## 7. R1 编译任务拆分

P02 确认后，第一轮 skill 编译应按 P15 顺序推进：

| 顺序 | 编译目标 | 必须吸收的 R1 规则 |
|---|---|---|
| 1 | `propagation-router/SKILL.md` | 主入口、人类门禁、自动推进、execution trace 更新、兼容入口治理 |
| 2 | `hotspot-topic-research/SKILL.md` | 账号确认、产品对象门禁、Topic Gate、选题后自动进入 Brief |
| 3 | `content-brief-compiler/SKILL.md` | topic_card 到 content_brief、Brief 通过后自动写口播 |
| 4 | `copywriting-draft-writer/SKILL.md` | Hook 路由、正文信息密度、承诺兑现、草案通过后自动画中画 |
| 5 | `talking-head-image-pip/SKILL.md` | 视觉计划、图片状态、不得停在“是否做画中画” |
| 6 | `copywriting-quality-review/SKILL.md` | 文案 + 视觉联合质检、正文兑现、质检通过后自动平台包装 |
| 7 | `platform-packaging-adapter/SKILL.md` | 平台包、content_delivery_record、平台包后自动最终 HTML |
| 8 | `final-delivery-builder/SKILL.md` | final-delivery.html、人类验收、自动发布拦截 |
| 9 | `hotspot-copywriting-research/SKILL.md` | 降级为兼容入口，不承载新逻辑 |

---

## 8. P02 验收标准

P02 产品定义通过的标准：

```text
[x] 说明 agent 扶跑问题的产品含义。
[x] 定义 execution_source 在 P02 里的风险等级。
[x] 定义 R1 可编译前阈值。
[x] 定义 R1 不可编译信号。
[x] 定义 R1 编译后验证目标。
[x] 明确 P02 依赖 P01 / P13 / P14 / P15 / P08 / 内容质量补充收敛。
[x] 给出 R1 编译任务顺序和每个 skill 必须吸收的规则。
```

当前结论：

```text
P02 产品定义达到可确认状态。
R1 已具备进入“整组可编译验收”的条件。
仍需涛哥确认 R1 整组后，才能修改 `skills/*/SKILL.md`。
```

---

## 9. 不做事项

当前 P02 不做：

```text
不改 SKILL.md。
不写 validator 脚本。
不重跑真实内容生产。
不把 L2.5 直接宣称为 L3。
不引入 Temporal / Airflow / Dagster / LangGraph 等重型运行时。
```

R1 的目标是把轻量 skill 编译到 L3 候选，不是把项目改造成 workflow engine。

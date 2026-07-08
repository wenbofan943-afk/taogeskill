# R1 Skill 执行合同组可编译总验收

> 状态：r1_confirmed_compiled_integrated_sample_pass_with_warnings  
> 所属路线：R1 方法论没有编译成执行合同  
> 目标：记录 R1 从产品定义、编译到综合 dry-run 样本后的当前验收口径。  
> 边界：本文件是 R1 总验收和返修入口，不代表完整真实测试通过；R1 修订需先完成产品层确认，再进入对应 `skills/*/SKILL.md` 修订。

---

## 1. R1 范围

R1 覆盖：

```text
P01：skill 不是执行合同。
P02：依赖 agent 扶着跑。
P13：execution trace 只是记录不是检查器。
P14：讨论稿没有充分编译成 skill。
P15：dbskill 式编译不足。
P08 子集：人类门禁和自动推进不合理。
内容质量子集：不只优化 Hook，还要约束正文信息密度、承诺兑现和核心机制。
```

R1 不覆盖：

```text
P03 多选题 fan-out / fan-in。
P04 旁支任务封锁。
P05 画中画数量和资产合同细化。
P06 图片资产链。
P07 / P16 最终 HTML 模板产品化细节。
P17 外部模型降级链路。
GitHub 开源发布包净化。
```

这些进入 R2 / R3 / R4。

## 1.1 SAMPLE-HISTORICAL-005 后的 R1 验收修订

SAMPLE-HISTORICAL-005 的最低链路已经跑通：

```text
account_profile
-> product_profile
-> research_run
-> topic_card
-> content_brief
-> draft
-> visual_plan
-> quality_review
-> platform_package
-> content_delivery_record
-> final-delivery.html
```

但本轮样本不能判定 R1 已经稳定进入 L3 candidate，原因是：

| 暴露问题 | 归属 | 对 R1 验收的影响 |
|---|---|---|
| visual_plan 实际 prompt 从完整结构缩水成短关键词 | R1 skill 编译问题 | R1CHK 必须新增或强化“prompt 完整度”检查 |
| quality_review 没拦住泛素材图 | R1 skill 编译问题 | 质检不能只看是否有图，必须检查画中画是否服务留存任务 |
| execution_trace 里 imagegen 使用记录前后矛盾 | R1 产品 + 编译问题 | trace 自洽性必须成为 R1 WARN / BLOCKER |
| 任务过长导致聊天流断开 | R2 | 不作为 R1 阻断，但记录为后续运行模型问题 |
| 图片数量、Seedream 兼容、portable_bundle | R3 / R4 | 不纳入 R1 返修范围 |

据此，R1 返修后的验收口径调整为：

```text
R1 sample run 通过，只能证明单篇主链路成立。
R1 sample run 不能替代 R2-R4 编译后的完整真实测试。
R1 修订重点是 prompt 不缩水、视觉质检能拦截、trace 自洽、测试前置条件说清楚。
```

---

## 2. R1 产品产物清单

| 产物 | 文件 | 状态 | 作用 |
|---|---|---|---|
| R1 产品总览 | `docs/product/R1-产品总览.md` | confirmed | 给人、AI 和维护者的 R1 阅读入口，说明范围、真源、质量标准和确认后动作 |
| Skill Contract 模板 | `docs/reference/skill_contract模板.md` | confirmed_for_r1 | 规定每个 skill 合同的 12 个必备区块 |
| P01 可编译验收 | `docs/product/P01-skill-contract可编译验收表.md` | confirmed_for_r1 | 汇总核心 8 个 skill 合同是否具备输入输出、门禁、失败处理 |
| 内容质量补充 | `docs/product/内容创作质量方法论编译补充-R1.md` | compiled_into_skill | 把 Hook 路由、正文信息密度、承诺兑现并入 draft / review 合同 |
| P14 方法论编译 | `docs/product/R1-P14-方法论编译规则.md` | confirmed_for_r1 | 规定讨论稿、调研、复盘如何进入产品、合同、字段、SKILL、validator |
| P15 skill 粒度治理 | `docs/product/R1-P15-skill粒度与入口治理规则.md` | compiled_into_skill | 规定主入口、专项入口、兼容入口和 R1 编译顺序 |
| P13 trace 检查清单 | `docs/product/R1-P13-execution-trace检查清单与validator草案.md` | compiled_into_skill | 规定 trace 必备结构、BLOCKER / WARN / INFO 和 validator 输出字段 |
| P02 扶跑收敛 | `docs/product/R1-P02-agent扶跑收敛与可编译判定.md` | compiled_into_skill | 规定 agent 扶跑风险等级、可编译阈值和编译后验证目标 |
| 合同版本治理 | `docs/product/R1-合同版本与变更治理.md` | compiled_into_contract | 规定 contract_set_version、合同状态机、旧 session 恢复和旧入口兼容策略 |
| 字段输入输出矩阵 | `docs/product/R1-字段级输入输出矩阵.md` | compiled_into_skill | 规定每个核心 skill 的 required_input、required_output、routing_status 和缺字段恢复规则 |
| 人类门禁决策枚举 | `docs/product/R1-人类门禁决策枚举与恢复规则.md` | compiled_into_skill | 规定门禁 allowed_decisions、decision_type、state_updates 和恢复路径 |
| Trace / Check 注册表 | `docs/product/R1-trace-check注册表.md` | compiled_into_skill | 规定 R1 原子化 BLOCKER / WARN / INFO check、输出模板和结果计算规则 |
| 产品确认清单 | `docs/product/R1-产品确认清单.md` | confirmed | 把 R1 确认拆成 R1-C01 到 R1-C13，避免一句确认覆盖不清 |

---

## 2.1 R1 阅读入口

后续阅读和编译 R1 时，默认从 [R1 产品总览](./R1-产品总览.md) 进入。

它不新增执行规则，只负责把 R1 的范围、成熟 workflow 吸收点、当前真源、阅读路径、质量评估标准和确认后动作收口，避免新读者直接面对一组过程文档。

R1 的核心阅读顺序是：

```text
R1-产品总览.md
-> R1-skill执行合同组可编译总验收.md
-> R1-产品确认清单.md
```

AI 编译时再继续读取字段矩阵、人类门禁、trace/check、内容质量补充和各 skill 合同。

---

## 3. 核心 skill 合同清单

| 顺序 | skill | 合同状态 | R1 编译动作 |
|---|---|---|---|
| 1 | `propagation-router` | confirmed / compiled | 已编译主入口、门禁、自动推进、execution trace 更新 |
| 2 | `hotspot-topic-research` | confirmed / compiled | 已编译账号确认、产品对象门禁、Topic Gate、选题后自动 Brief |
| 3 | `content-brief-compiler` | confirmed / compiled | 已编译 topic_card 到 content_brief、Brief 通过后自动写口播 |
| 4 | `copywriting-draft-writer` | confirmed / compiled | 已编译 Hook 路由、正文信息密度、承诺兑现、草案通过后自动画中画 |
| 5 | `talking-head-image-pip` | confirmed / compiled | 已编译视觉计划、图片状态、自动进入质检 |
| 6 | `copywriting-quality-review` | confirmed / compiled | 已编译文案 + 视觉联合质检、质检通过后自动平台包装 |
| 7 | `platform-packaging-adapter` | confirmed / compiled | 已编译平台包、content_delivery_record、自动最终 HTML |
| 8 | `final-delivery-builder` | confirmed / compiled | 已编译 final-delivery.html、人类验收、自动发布拦截 |
| 9 | `hotspot-copywriting-research` | 无完整合同 | 降级为兼容入口，不承载新逻辑 |

---

## 4. R1 可编译验收

当前合同组版本：

```yaml
contract_set_version: r1-contract-set-v0.1
contract_set_status: compiled_integrated_sample_pass_with_warnings
```

| 检查项 | 结果 | 说明 |
|---|---|---|
| 核心 skill 均有合同 | 通过 | 8 个核心 `CONTRACT.md` 已建立 |
| 合同包含输入 / 输出 / 路径 / 门禁 / 自动推进 / 失败处理 | 通过 | P01 已验收为可编译输入 |
| 人类门禁规则明确 | 通过 | 只在账号确认、选题确认、风险返工、最终 HTML 验收等位置停 |
| 自动推进规则明确 | 通过 | 选题确认后自动 Brief；Brief 通过后自动口播；质检通过后自动平台包装；平台包后自动最终 HTML |
| 内容质量不只看 Hook | 通过 | draft / review 合同已加入正文信息密度、承诺兑现、核心机制 |
| 方法论编译路径明确 | 通过 | P14 已定义 product -> contract -> SKILL -> sample -> validator 状态机 |
| skill 粒度和入口治理明确 | 通过 | P15 已定义 router / producer / reviewer / builder / compatibility |
| trace 检查口径明确 | 通过 | P13 已定义必备结构、BLOCKER / WARN / INFO、validator 输出字段 |
| agent 扶跑收敛口径明确 | 通过 | P02 已定义风险等级、不可编译信号、编译后验证目标 |
| 合同版本与变更治理明确 | 通过 | 已定义 `r1-contract-set-v0.1`、状态机、变更确认规则、旧 session 恢复和兼容入口 |
| 字段级输入输出矩阵 | 通过 | 已逐 skill 明确必需 / 可选字段、状态枚举、字段真源和缺字段恢复 |
| 人类门禁决策枚举 | 通过 | 已定义每个门禁的用户回复类型、状态变化和恢复路径 |
| 原子化 trace/check 注册表 | 通过 | 已把 P13 的 BLOCKER / WARN 拆成 check_id 级检查项 |
| 产品确认清单 | 通过 | 已将 R1 确认拆为 13 个可逐项确认项 |
| 产品层阅读入口 | 通过 | 已新增 R1 产品总览，按人类确认、AI 编译、维护者阅读三类路径组织 |
| 开源读者可读性 | 基本通过 | 已给出 R1 入口和真源关系；完整开源 README、示例和贡献文档进入 R4 |
| `skills/*/SKILL.md` 已按 R1 编译 | 通过 | 8 个核心 skill 已新增 R1 Contract Runtime，旧入口已降级为 Compatibility Runtime |

---

## 5. 当前成熟度判断

当前 R1 状态：

```text
r1_skill_backwrite_compiled_pending_static_check
```

成熟度：

```text
L2.8 -> L3 candidate 前置返修
```

这句话的含义是：

```text
R1 产品层和第一轮 skill 编译已经证明单篇主链路可跑。
SAMPLE-HISTORICAL-005 暴露出的 prompt 编译缩水、视觉质检漏检、trace 自洽性和恢复边界问题，已完成产品层返修并编译进对应 skill。
R1-R4 综合 dry-run 样本已完成，结果为 pass_with_warnings；下一步不再补 R1 返修样本，而是进入只读 checker 产品定义。
```

---

## 6. 确认后进入的编译工作

涛哥已确认 R1 第一轮编译；SAMPLE-HISTORICAL-005 后进入 R1 返修：

```text
1. 先按 SAMPLE-HISTORICAL-005 问题归属修订 R1 产品层。
2. 明确 R1 只验证单篇主链路，不再作为完整真实测试前置完成信号。
3. 强化 `talking-head-image-pip` 的 prompt 完整度验收。
4. 强化 `copywriting-quality-review` 的画中画质检阻断规则。
5. 强化 execution_trace 自洽性检查。
6. 经涛哥确认后，已完成 R1 skill 编译修订。
7. R1 修订后已纳入 R1-R4 综合 dry-run；样本结果只作为 pass_with_warnings 证据，不代表完整真实测试通过。
```

编译后 sample run 的最低目标：

```text
overall_result = pass 或 pass_with_warnings。
agent_assist_level <= medium。
核心步骤无 agent_created_rule。
选题确认后自动到底。
最终 HTML、manifest、execution trace、content_delivery_record 闭合。
```

---

## 7. 仍需注意的风险

R1 只解决执行合同，不解决所有工程问题。

确认 R1 后，仍然不能声称项目已适合公开上线，因为：

```text
R2 的多选 fan-out / fan-in 还没产品化。
R3 的画中画数量、图片资产和最终 HTML 资产链还没产品化。
R4 的 sample account、开源净化包、贡献文档和发布检查还没完成。
validator 目前仍是清单草案，不是自动脚本。
```

因此 R1 编译后的合理说法是：

```text
核心 skill 执行合同进入 L3 候选验证。
```

不是：

```text
整个项目已经开源可发布。
```

---

## 8. 给涛哥的确认口径

如果认可 R1 的产品定义，可以按 [R1 产品确认清单](./R1-产品确认清单.md) 回复：

```text
认可 R1，进入 skill 编译。
```

如果要改某块，可以直接说：

```text
先改 P13 的 BLOCKER 规则。
先改 P15 的 skill 粒度。
先改文案质量方法论。
```

在涛哥确认前，后续只能继续修订产品定义和合同草案，不进入 `SKILL.md` 编译。


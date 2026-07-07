# P01 Skill Contract 可编译验收表

> 状态：P01 小循环验收记录，已被 R1 总验收收口  
> 对应问题：P01 skill 不是执行合同  
> 目标：确认核心链路 skill 已具备 R1 内 P01 的可编译输入；R1 已经整组确认并完成第一轮 `SKILL.md` 编译动作，后续以样本验证为准。

> 说明：本文件保留 P01 小循环当时的判断。R1 后续已补齐 P14 / P15 / P13 / P02 / 内容质量 / 字段矩阵 / 门禁枚举 / trace check / 产品确认清单。当前是否进入编译，以 `docs/product/R1-产品确认清单.md` 和 `docs/product/R1-skill执行合同组可编译总验收.md` 为准。

---

## 1. 本轮范围

本轮只解决 R1 里的 P01：

```text
每个核心 skill 有输入、输出、前置条件、停顿点、失败处理、下一步。
```

本轮不解决：

```text
P03 多选 fan-out / fan-in。
P05 画中画数量规则细化。
P13 validator 自动检查器。
P16 最终 HTML 模板细节。
真实 SKILL.md 编译。
```

这些问题会在后续父问题继续推进。

重要节奏：

```text
P01 完成不等于立刻编译 SKILL.md。
R1 = P01 + P02 + P13 + P14 + P15 + P08 门禁部分。
只有 R1 整组产品定义经涛哥确认后，才进入第一轮 skill 编译。
```

---

## 2. 核心链路合同覆盖

| 顺序 | skill | 合同文件 | 当前状态 | 是否达到 P01 可编译输入 |
|---|---|---|---|---|
| 0 | `propagation-router` | `skills/propagation-router/CONTRACT.md` | confirmed / compiled | 是 |
| 1 | `hotspot-topic-research` | `skills/hotspot-topic-research/CONTRACT.md` | confirmed / compiled | 是 |
| 2 | `content-brief-compiler` | `skills/content-brief-compiler/CONTRACT.md` | confirmed / compiled | 是 |
| 3 | `copywriting-draft-writer` | `skills/copywriting-draft-writer/CONTRACT.md` | confirmed / compiled | 是 |
| 4 | `talking-head-image-pip` | `skills/talking-head-image-pip/CONTRACT.md` | confirmed / compiled | 是 |
| 5 | `copywriting-quality-review` | `skills/copywriting-quality-review/CONTRACT.md` | confirmed / compiled | 是 |
| 6 | `platform-packaging-adapter` | `skills/platform-packaging-adapter/CONTRACT.md` | confirmed / compiled | 是 |
| 7 | `final-delivery-builder` | `skills/final-delivery-builder/CONTRACT.md` | confirmed / compiled | 是 |

兼容入口 `hotspot-copywriting-research` 暂不承载新合同，后续只保留旧唤醒词路由或废弃说明。

---

## 3. 链路连通性

```text
propagation-router
-> hotspot-topic-research
-> content-brief-compiler
-> copywriting-draft-writer
-> talking-head-image-pip
-> copywriting-quality-review
-> platform-packaging-adapter
-> final-delivery-builder
-> human_final_review
```

关键自动推进点：

| 上游状态 | 自动进入 | 禁止再问 |
|---|---|---|
| `topic_status = topic_selected_for_brief` | `content-brief-compiler` | 是否生成 Brief |
| `brief_status = brief_pass` + `human_gate = no` | `copywriting-draft-writer` | 请回复继续写口播 |
| `draft_status = draft_created` + `hook_score >= 7` | `talking-head-image-pip` | 是否做画中画 |
| `visual_plan_status = visual_plan_pass` | `copywriting-quality-review` | 是否进入质检 |
| `review_status = review_pass` | `platform-packaging-adapter` | 是否继续做分发包 |
| `delivery_status = delivery_ready` | `final-delivery-builder` | 是否确认采用 / 是否生成最终交付 |
| `final_delivery_status = html_ready` | 人工验收 | 是否自动发布 |

---

## 4. 人类门禁统一口径

只允许这些点停给用户：

```text
账号档案 P0 缺失。
换账号后账号档案待确认。
产品 / 活动对象不清。
Topic Gate 后选题。
Brief 不通过。
Hook 或首屏画面出现策略取舍。
质检不通过。
最终 HTML 验收。
人工发布后补记录。
```

不允许这些伪门禁：

```text
Brief 通过后问是否写口播。
草案通过后问是否做画中画。
质检通过后问是否做分发包。
平台包完成后问是否确认采用。
最终 HTML 完成后问是否自动发布。
```

---

## 5. P01 可编译输入验收

| 检查项 | 结果 |
|---|---|
| 每个核心 skill 有 `CONTRACT.md` | 通过 |
| 每个合同有身份和职责边界 | 通过 |
| 每个合同有触发条件 | 通过 |
| 每个合同有前置条件 | 通过 |
| 每个合同有输入合同 | 通过 |
| 每个合同有输出合同 | 通过 |
| 每个合同有路径合同 | 通过 |
| 每个合同有自动推进规则 | 通过 |
| 每个合同有人类门禁 | 通过 |
| 每个合同有失败处理 | 通过 |
| 每个合同有执行透明度记录 | 通过 |
| 每个合同有验收样例 | 通过 |
| 每个合同有开源边界 | 通过 |
| 未改写 `skills/*/SKILL.md` | 通过 |

---

## 5.1 成熟度判断

当前 P01 合同草案成熟度：

```text
L2.5：合同结构已具备，但还没有达到 R1 的 L3 可发布候选。
```

已经具备：

```text
输入合同。
输出合同。
路径合同。
人类门禁。
自动推进。
失败处理。
验收样例。
开源边界。
```

P01 当时还缺：

```text
P14：方法论 / 讨论稿如何进入 skill 的编译规则。
P15：skill 粒度标准、兼容入口和废弃入口处理。
P13：execution trace 如何从记录升级为检查清单。
P02：如何证明 agent assist level 下降。
内容创作质量：Hook 路由、正文信息密度、共鸣与兑现还需并入 draft / review 合同。
sample run：另一轮 agent 能否按合同跑通。
```

后续 R1 已完成前五项产品补齐；`sample run` 仍属于确认进入编译后的验证动作，不属于产品定义缺口。

因此当前结论是：

```text
P01 达到可编译输入。
R1 当时尚未达到可编译确认；当前以 R1 总验收和 R1 产品确认清单为准。
```

---

## 6. P01 当时需要确认的产品决策

进入 R1 后续产品定义前，当时需要确认三类 P01 产品规则：

1. `propagation-router` 只做路由，不生产正文。
2. 选题确认后，除非出现风险门禁，否则自动跑到最终 HTML。
3. 平台包完成后不再问“确认采用”，最终 HTML 才是人工验收点。

建议回复方式：

```text
确认 P01，继续 R1 后续产品定义。
```

或指出要改的合同：

```text
先改 talking-head-image-pip 的门禁。
平台包后还是要保留人工确认。
final-delivery-builder 的图片缺失规则再收紧。
```

其中“平台包后还是要保留人工确认”是当时允许用户提出的反向选择，不是当前推荐规则。当前 R1 推荐规则是：平台包完成后自动进入最终 HTML，最终 HTML 才是人工验收点。

---

## 7. 下一步

如果涛哥确认 P01，当时的下一步是：

```text
1. 保持各 CONTRACT.md 为 draft，先不改 SKILL.md。
2. 继续 R1 的 P14 / P15 / P13 / P02 产品定义。
3. R1 整组确认后，再把相关 CONTRACT.md 状态改为 confirmed。
4. 进入第一轮 skill 编译，并用 sample run 验证自动推进链路。
```

如果涛哥不确认：

```text
继续停留在产品定义阶段，只改合同，不改 SKILL.md。
```

# R1-P15 Skill 粒度与入口治理规则

> 状态：已确认并已编译引用  
> 所属路线：R1 方法论没有编译成执行合同 / P15 dbskill 式编译不足  
> 目标：定义本项目 skill 应该拆多细、入口如何治理、旧入口如何兼容，避免巨型 skill 和入口混乱。  
> 边界：本文件不改 `SKILL.md`，不新建 skill；确认后才作为编译依据。

---

## 1. 为什么需要 P15

P01 已经让核心 skill 有了合同，但还不够。  
如果没有 P15，后续编译会出现三个问题：

```text
一个 skill 越写越大，什么都做。
多个 skill 抢同一个入口，agent 不知道该走谁。
旧入口继续承载新逻辑，导致兼容层和主链路混在一起。
```

P15 要解决的是：

```text
什么时候应该是独立 skill。
什么时候只是某个 skill 的合同规则。
什么时候只是字段或 validator。
什么时候旧入口只能做 alias。
什么时候必须拆分，什么时候不能拆。
```

---

## 2. 粒度原则

一个 skill 应该对应一个稳定工作节点，而不是一个模糊主题。

推荐判断：

```text
一个 skill = 一个明确触发场景 + 一个主输入 + 一个主输出 + 一个下游方向。
```

### 2.1 应该独立成 skill 的条件

满足以下条件中的 3 条以上，才考虑独立 skill：

```text
[ ] 有独立用户触发意图。
[ ] 有独立上游 artifact。
[ ] 有独立下游 artifact。
[ ] 有独立人类门禁或自动推进规则。
[ ] 有独立失败处理。
[ ] 有独立样例验证价值。
[ ] 被多个上游复用。
[ ] 不拆会让现有 skill 超过单一职责。
```

### 2.2 不应该独立成 skill 的情况

以下情况不新建 skill：

```text
只是一个检查项。
只是一个字段。
只是一个评分维度。
只是一次性方法论补充。
只是某个输出模板的一部分。
只是旧入口兼容。
只是 agent 在某次运行里的临场补丁。
```

这些内容应进入：

```text
CONTRACT.md
交接物字段词典.md
docs/reference/
validator/checklist
```

---

## 3. Skill 类型

本项目 skill 分四类：

| 类型 | 作用 | 例子 | 是否承载主逻辑 |
|---|---|---|---|
| router | 识别意图、检查交接物、路由下一步 | `propagation-router` | 否 |
| producer | 生成下游核心 artifact | `hotspot-topic-research`、`content-brief-compiler`、`copywriting-draft-writer` | 是 |
| reviewer | 质检、评分、决定返工或通过 | `copywriting-quality-review` | 是 |
| builder | 构建最终交付或导出包 | `platform-packaging-adapter`、`final-delivery-builder` | 是 |
| compatibility | 旧唤醒词兼容、转发到新入口 | `hotspot-copywriting-research` | 否 |

规则：

```text
router 不生产正文。
producer 不做最终发布判断。
reviewer 不直接生成最终交付。
builder 不重写内容主体。
compatibility 不承载新逻辑。
```

---

## 4. 当前 skill 职责边界

| skill | 类型 | 主输入 | 主输出 | 边界 |
|---|---|---|---|---|
| `propagation-router` | router | 用户意图 / workflow state | router_decision | 不生产正文 |
| `hotspot-topic-research` | producer | account + product/campaign | topic_card | 不写文案 |
| `content-brief-compiler` | producer | selected topic_card | content_brief | 不写正文 |
| `copywriting-draft-writer` | producer | content_brief | draft | 不做画中画、不做最终质检 |
| `talking-head-image-pip` | producer | draft | visual_plan / image_asset_set | 不写正文、不做发布包装；`image_asset_manifest` 为旧别名 |
| `copywriting-quality-review` | reviewer | draft + visual_plan | quality_review | 不直接改稿、不生成平台包 |
| `platform-packaging-adapter` | builder | quality_review | platform_package + delivery_record | 不改视频主体、不自动发布 |
| `final-delivery-builder` | builder | delivery_record + assets | final_delivery / export | 不登录平台、不自动发布 |
| `hotspot-copywriting-research` | compatibility | 旧唤醒词 | router handoff | 不承载新合同 |

---

## 5. 入口治理

### 5.1 主入口

唯一主入口：

```text
propagation-router
```

它负责：

```text
识别用户意图。
读取当前状态。
判断缺什么。
路由到专项 skill。
给任务后导航。
```

### 5.2 专项入口

专项 skill 可以被直接触发，但必须先自检上游 artifact。

例如：

```text
用户直接说“写口播”。
copywriting-draft-writer 必须检查 content_brief 是否存在且 brief_pass。
如果没有，回到 router 或 content-brief-compiler。
```

### 5.3 兼容入口

`hotspot-copywriting-research` 的定位：

```text
旧唤醒词兼容入口。
只把旧请求转发到 propagation-router 或 hotspot-topic-research。
不新增字段。
不产出新 artifact。
不承载新合同。
```

后续处理建议：

```text
保留 `SKILL.md` 作为 alias。
新增 `DEPRECATED.md` 或在合同索引中标记 compatibility。
不为它补完整 CONTRACT.md。
不让它成为 README 的主入口。
```

---

## 6. 拆分和合并规则

### 6.1 必须拆分

当一个 skill 同时承担以下两类以上职责时，必须评估拆分：

```text
调研。
写作。
出图。
质检。
平台包装。
最终交付。
状态恢复。
开源导出。
```

### 6.2 不拆分

以下情况先不拆：

```text
只是新增字段。
只是多一个评分项。
只是同一 artifact 的输出格式增强。
只是一个失败处理分支。
只是同一阶段的内部步骤。
```

例如：

```text
Hook 路由 / 正文信息密度 不新建 skill，先并入 draft 和 review 合同。
图片缺失降级 不新建 skill，先并入 visual_plan / final_delivery 合同。
```

### 6.3 需要合并或降级

如果一个 skill 只有旧唤醒词价值，没有独立 artifact，应该降级为 compatibility。

当前候选：

```text
hotspot-copywriting-research
```

---

## 7. Skill 规模限制

为了开源可读性，单个 `SKILL.md` 应遵守：

```text
只写执行必需规则。
不塞完整方法论长文。
不复制外部参考全文。
不重复字段词典全文。
不重复 AGENTS 长期规则。
复杂背景放 docs/explanation。
产品取舍放 docs/product。
字段定义放字段词典。
前置合同放 CONTRACT.md。
```

建议结构：

```text
定位。
触发。
必读。
输入门槛。
处理流程。
输出格式。
自动推进。
失败处理。
人类引导。
```

---

## 8. P15 对 R1 的影响

P15 确认后，R1 编译时要遵守：

```text
先编译 router，再编译 producer，再编译 reviewer，再编译 builder。
兼容入口最后处理。
任何新方法论先判断是 skill、合同、字段、validator 还是 explanation。
不得因为某个方法论重要，就新建 skill。
不得因为某个旧入口存在，就让它承载新逻辑。
```

推荐 R1 编译顺序：

| 顺序 | 目标 | 原因 |
|---|---|---|
| 1 | `propagation-router` | 总控先稳定 |
| 2 | `hotspot-topic-research` | 上游选题和 Topic Gate |
| 3 | `content-brief-compiler` | 选题到文案输入 |
| 4 | `copywriting-draft-writer` | 文案草案和正文质量 |
| 5 | `talking-head-image-pip` | 视觉计划 |
| 6 | `copywriting-quality-review` | 联合质检 |
| 7 | `platform-packaging-adapter` | 分发包装 |
| 8 | `final-delivery-builder` | 最终 HTML |
| 9 | `hotspot-copywriting-research` | 兼容入口降级 |

---

## 9. P15 验收标准

P15 通过的标准：

```text
每个当前 skill 的类型明确。
每个当前 skill 的主输入和主输出明确。
主入口和专项入口关系明确。
兼容入口不承载新逻辑。
新方法论是否新建 skill 有判断标准。
SKILL.md 规模和内容边界明确。
R1 编译顺序明确。
```

当前结论：

```text
P15 产品定义达到可确认状态。
P13 / P02 已在后续小循环补齐；当前以 R1 总验收和 R1 产品确认清单为准。
```

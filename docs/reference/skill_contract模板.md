# Skill Contract 模板

> 状态：r1_confirmed_contract_baseline  
> 所属路线：GitHub 开源上线前 Workflow 修复路线图 / Phase 1 / 1.1  
> 目标：把 skill 从“方法论说明书”升级为“可执行合同”。  
> 边界：本文件是 R1 已采用的合同模板基线；后续改写 `skills/*/SKILL.md` 必须走版本记录和确认。

---

## 1. 为什么要有 Skill Contract

当前 workflow 暴露出的父问题是：

```text
R1：方法论没有编译成执行合同。
```

它导致：

```text
P01：skill 不是执行合同。
P02：过度依赖 agent 扶着跑。
P13：execution trace 只是记录，不是检查器。
P14：讨论稿没有充分编译成 skill。
P15：dbskill 式编译不足。
```

因此，后续每个 skill 在开发 / 编译前，必须先有一份产品层面的 `skill_contract`。  
它回答的是：这个 skill 到底接什么、产什么、什么时候停、什么时候自动往下走、失败时怎么办。

---

## 2. 本项目里的 Skill Contract 是什么

`skill_contract` 不是代码，也不是长篇方法论。它是一个可被人和 AI 同时阅读的执行合同。

它必须让新 agent 不依赖隐藏上下文，也能判断：

```text
当前能不能运行这个 skill。
缺什么时必须停。
输入从哪里来。
输出写到哪里。
字段是否完整。
下一步是否自动推进。
哪些动作算 skill_defined。
哪些动作只能算 agent_orchestrated。
```

一句话定义：

```text
Skill Contract = 触发条件 + 输入合同 + 输出合同 + 路径合同 + 人类门禁 + 自动推进 + 失败处理 + 透明度记录。
```

---

## 3. 适用范围

必须补 `skill_contract` 的核心 skill：

| skill | 是否 P0 | 原因 |
|---|---|---|
| `propagation-router` | 是 | 总控路由不清会导致全链路跑偏 |
| `hotspot-topic-research` | 是 | 负责来源、时效、选题卡和 Topic Gate |
| `content-brief-compiler` | 是 | 用户选题后必须自动进入内容链路 |
| `copywriting-draft-writer` | 是 | Brief 通过后不得让用户说“继续写口播” |
| `talking-head-image-pip` | 是 | 画中画数量、用途、插入位置必须进入合同 |
| `copywriting-quality-review` | 是 | 质检通过 / 不通过决定后续自动推进或返工 |
| `platform-packaging-adapter` | 是 | 平台包完成后不是人工门禁，应自动进入最终交付 |
| `final-delivery-builder` | 是 | 最终 HTML 是人类验收入口，不能只产后台 MD |

兼容入口 `hotspot-copywriting-research` 可以后置处理，原则是只做旧唤醒词路由，不承载新合同。

---

## 4. Contract 最小结构

每个 skill 的合同必须包含以下 12 段。

### 4.1 身份

```yaml
skill_id:
skill_name:
contract_version:
owner_project: taoge-creative-workflow
status: draft / confirmed / compiling / active / deprecated
confirmed_by:
confirmed_at:
```

规则：

```text
status = draft：只允许讨论产品定义。
status = confirmed：涛哥已确认，可以进入 skill 编译。
status = compiling：正在改对应 SKILL.md。
status = active：已编译并通过样例验证。
status = deprecated：旧入口或旧规则，不再扩展。
```

### 4.2 触发条件

```yaml
triggers:
  user_intent:
  upstream_artifact_status:
  allowed_manual_commands:
```

必须写清：

```text
什么用户话术会触发。
哪个上游交接物完成后会自动触发。
哪些情况下不得触发。
```

### 4.3 前置条件

```yaml
preconditions:
  required_artifacts:
  required_fields:
  required_paths:
  required_status:
```

前置条件缺失时，skill 不能硬跑，必须进入失败处理或人类引导。

### 4.4 输入合同

```yaml
inputs:
  artifact_type:
  source_path:
  required_fields:
  optional_fields:
  validation_rules:
```

输入只能来自：

```text
account_profile
product_profile / campaign_profile
research_run_record
topic_card
content_brief
draft
visual_plan
quality_review
platform_package_input
platform_package
content_delivery_record
manifest.yaml
```

不得从聊天上下文里“凭印象补字段”。

### 4.5 输出合同

```yaml
outputs:
  artifact_type:
  target_path:
  required_fields:
  status_field:
  downstream_artifact:
```

输出必须写入 `accounts/{account_slug}/runs/{session_id}/` 下的固定位置。  
根目录汇总表只能作为索引或摘要，不能成为唯一事实源。

### 4.6 路径合同

```yaml
path_contract:
  project_root:
  session_root:
  input_paths:
  output_paths:
  index_paths:
```

路径规则：

```text
所有真实内容产物必须进入账号 session。
intermediate 放中间产物。
deliverables 放最终交付物。
assets 放图片和素材。
export 放可转交包。
```

### 4.7 自动推进规则

```yaml
auto_next:
  when_pass:
  next_skill:
  next_artifact:
  forbidden_human_prompt:
```

必须明确：

```text
哪些情况自动进入下一环节。
哪些话绝对不能问用户。
用户如果要打断，应该怎么说。
```

例如：

```text
topic_card 被用户选中且字段完整 -> 自动进入 content-brief-compiler。
brief_status = brief_pass -> 自动进入 copywriting-draft-writer。
review_status = review_pass -> 自动进入 platform-packaging-adapter。
platform_package 完成 -> 自动进入 final-delivery-builder。
```

### 4.8 人类门禁

```yaml
human_gates:
  gate_id:
  trigger:
  reason:
  recommended_action:
  human_reply_examples:
  auto_next_after_reply:
```

只允许在真正需要人判断的地方停：

```text
账号档案 P0 缺失。
换账号后账号档案待确认。
产品 / 活动对象不清。
Topic Gate 后选题。
Brief 不通过。
Hook / 画面出现策略取舍。
质检不通过。
最终 HTML 验收。
人工发布后补记录。
```

禁止把平台包完成、Brief 通过、质检通过这类自动节点包装成人工门禁。

### 4.9 失败处理

```yaml
failure_modes:
  missing_input:
  invalid_field:
  broken_link:
  stale_hotspot:
  image_unavailable:
  quality_risk:
  recovery_action:
```

失败处理必须给最小恢复路径：

```text
缺字段 -> 回到对应上游交接物补字段。
热点过期 -> 降级为行业趋势 / 复盘 / 常青问题 / 方法论。
图片无法生成 -> 标记 pending_external / manual_required，不得假装已有图片。
质检高风险 -> 回到 draft 或 visual_plan 返工。
```

### 4.10 透明度记录

```yaml
execution_trace:
  required: true
  source_labels:
  agent_assist_level_rule:
  maturity_level_rule:
```

每个 skill 必须能写入或更新：

```text
intermediate/00-execution-trace.md
```

最少要区分：

```text
skill_defined
skill_inferred
agent_orchestrated
agent_created_rule
user_decision
environment_capability
manual_fallback
```

### 4.11 验收样例

```yaml
acceptance_examples:
  happy_path:
  missing_input_case:
  human_gate_case:
  auto_next_case:
  failure_case:
```

每个合同至少需要 5 个样例。  
没有样例的合同不能进入 `status = confirmed`。

### 4.12 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
  must_redact:
  sample_required:
  external_dependency:
```

规则：

```text
合同可以开源。
真实账号、真实内容产物、生产图片和未授权外部资料不能直接开源。
公开仓库必须使用 sample account / sample run。
```

---

## 5. 产品确认门

每个 skill 进入编译前，必须先过产品确认门。

### 可以进入确认的条件

```text
12 段合同齐全。
输入和输出路径明确。
自动推进和人类门禁不冲突。
失败处理有最小恢复路径。
execution_trace 标记规则明确。
至少有 5 个验收样例。
没有要求接外部 API、登录平台或自动发布。
```

### 涛哥确认后的状态变化

```text
draft -> confirmed
```

只有 `status = confirmed` 后，才允许进入：

```text
skill 开发 / skill 编译 / 修改 skills/*/SKILL.md
```

未确认前，任何 agent 只能继续讨论产品定义，不得提前改 skill。

---

## 6. 编译前检查清单

准备把某个 skill contract 编译进 `SKILL.md` 前，逐项检查：

```text
[ ] 这个 skill 的职责是否一句话说得清。
[ ] 上游交接物是否固定。
[ ] 下游交接物是否固定。
[ ] 输出路径是否固定。
[ ] 哪些情况自动推进已经写清。
[ ] 哪些情况必须停给用户已经写清。
[ ] 禁止问用户“是否继续”的节点已经写清。
[ ] 失败时回到哪里已经写清。
[ ] execution_trace 如何记录已经写清。
[ ] 开源样例和真实资料边界已经写清。
[ ] 涛哥已经明确确认。
```

---

## 7. 本轮建议先确认的产品决策

建议先确认三件事：

| 决策 | 推荐方案 | 原因 |
|---|---|---|
| Contract 放哪里 | `docs/reference/skill_contract模板.md` | 这是 AI 执行契约，不是解释性文章 |
| 单个 skill 的合同放哪里 | 后续放 `skills/{skill_id}/CONTRACT.md` | 贴近 skill，便于编译和审计 |
| 是否先从总控开始 | 是，先做 `propagation-router` | 总控路由不稳，后面每个 skill 都会被 agent 扶跑 |

如果这份产品定义方向认可，下一轮才进入第一个具体 skill 的合同草案：

```text
skills/propagation-router/CONTRACT.md
```

那一轮仍然是产品定义，不会直接改 `SKILL.md`。

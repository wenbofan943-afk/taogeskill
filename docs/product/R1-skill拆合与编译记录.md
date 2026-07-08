# R1 Skill 拆合与编译记录

> 状态：R1 编译记录  
> 时间：2026-07-06  
> 目标：记录涛哥确认 R1 后，本轮为什么这样拆分 / 合并 / 降级 skill，以及实际编译到了哪些文件。  
> 边界：本文件只记录 R1 编译决策；不代表 R2 多分支、R3 图片资产链、R4 开源包已完成。

---

## 1. 调研依据

本轮参考成熟 workflow 和 skill 项目的共同做法：

| 参考 | 吸收点 | 本项目取舍 |
|---|---|---|
| OpenAI Codex Skills | skill 使用渐进读取，先用 metadata 触发，再读取 `SKILL.md`，复杂材料按需放 references | `SKILL.md` 只写执行必需规则，长解释留在 docs/product |
| Temporal Workflow Definition | workflow 要有确定的步骤、输入、输出和可恢复状态 | 每个核心 skill 固定主输入、主输出、next_skill 和失败回退 |
| LangGraph Persistence / Interrupts | 人类中断点要保存状态，并能恢复继续 | 只在账号确认、Topic Gate、阻断返工、最终 HTML 验收等节点停 |
| Dagster Software-defined Assets | 资产应有定义、上游依赖和可追溯关系 | 把 topic_card、brief、draft、visual_plan、review、platform_package、final_delivery 当成可追溯资产 |

参考链接：

```text
https://developers.openai.com/codex/skills
https://docs.temporal.io/workflow-definition
https://docs.langchain.com/oss/python/langgraph/persistence
https://docs.langchain.com/oss/python/langgraph/interrupts
https://docs.dagster.io/guides/build/assets
```

---

## 2. 拆合结论

本轮不新增核心 skill，不合并 8 个核心 skill。

原因：

```text
8 个核心 skill 已经分别对应稳定工作节点。
每个节点都有明确主输入、主输出和下游方向。
合并会让单个 SKILL.md 变厚，违背渐进读取。
拆得更细会把字段、检查项、评分维度误拆成 skill，增加触发混乱。
```

保留的核心链路：

```text
propagation-router
-> hotspot-topic-research
-> content-brief-compiler
-> copywriting-draft-writer
-> talking-head-image-pip
-> copywriting-quality-review
-> platform-packaging-adapter
-> final-delivery-builder
```

降级的旧入口：

```text
hotspot-copywriting-research = compatibility_entry
```

它只做旧唤醒词转发，不再承载新字段、新 artifact 或新流程。

---

## 3. 读、取、传设计

R1 编译后，每个核心 skill 都必须回答三件事：

```text
读：本 skill 触发后先读哪些事实源。
取：从上游 artifact 取哪些字段，不能从哪里猜。
传：交给下游时必须带哪些 ID、状态、路径和 next_skill。
```

全链路必传字段：

```text
session_id
account
product_profile_id / campaign_profile_id
source_research_run_id
topic_id
brief_id
draft_id
visual_plan_id
review_id
platform_package_id
delivery_id
final_delivery_id
contract_set_version
artifact_path
next_skill
```

R1 后续样本必须记录：

```text
contract_set_version: r1-contract-set-v0.1
```

---

## 4. 编译动作

### 4.1 合同状态

8 个核心 `CONTRACT.md` 已从：

```text
status: draft
```

推进为：

```text
status: confirmed
contract_set_version: r1-contract-set-v0.1
confirmed_by: taoge
confirmed_at: 2026-07-06
```

涉及文件：

```text
skills/propagation-router/CONTRACT.md
skills/hotspot-topic-research/CONTRACT.md
skills/content-brief-compiler/CONTRACT.md
skills/copywriting-draft-writer/CONTRACT.md
skills/talking-head-image-pip/CONTRACT.md
skills/copywriting-quality-review/CONTRACT.md
skills/platform-packaging-adapter/CONTRACT.md
skills/final-delivery-builder/CONTRACT.md
```

### 4.2 SKILL.md 编译

8 个核心 `SKILL.md` 已新增 `R1 Contract Runtime`：

```text
contract_set_version
contract_version
contract_status
skill_type
primary_input
primary_output
next_skill_on_pass
读、取、传规则
自动推进 / 阻断规则
```

旧入口 `hotspot-copywriting-research/SKILL.md` 已新增 `R1 Compatibility Runtime`，只保留兼容路由。

### 4.3 Reference 反写

R1 编译继续反写到：

```text
docs/reference/人类引导与任务后导航规范.md
docs/reference/skill执行透明度与成熟度规范.md
docs/reference/文档治理与目录规范.md
```

新增内容：

```text
R1 decision_type。
branch_request 保护。
contract_set_version 必填。
trace_check 摘要。
R1CHK 最低检查项。
manifest 的 R1 字段要求。
```

### 4.4 Skill 交接块

8 个核心 `SKILL.md` 已补统一交接块，要求每次输出带：

```text
contract_set_version
核心上游 / 当前 artifact ID
account
source_research_run_id
状态字段
artifact_path
next_skill
human_gate
execution_trace_update
```

旧入口已补兼容交接块：

```text
compatibility_status: handoff_only
router_handoff_to
handoff_reason
```

---

## 5. 状态修正

编译时发现一处字段冲突：

```text
R1 字段矩阵曾把 platform_package 的 pass_status 写为 package_ready。
交接物字段词典允许值是 package_pass。
```

处理：

```text
已统一为 package_pass。
```

修订文件：

```text
docs/product/R1-字段级输入输出矩阵.md
```

---

## 6. 未进入本轮的事项

以下仍不属于 R1 编译结果：

```text
R2：多选题 fan-out / fan-in。
R2：旁支任务封锁。
R3：每篇画中画数量合同和图片资产链。
R3：Seedream 等外部模型降级入参兼容。
R4：开源示例、净化包、LICENSE / CONTRIBUTING / CHANGELOG。
validator：自动脚本尚未实现，当前仍是 trace/check 注册表和人工检查清单。
```

---

## 7. R1 编译后验证目标

下一步需要跑 sample run 或轻量真实样本，最低目标：

```text
overall_result = pass 或 pass_with_warnings。
agent_assist_level <= medium。
核心步骤无 agent_created_rule。
选题确认后自动到底。
final-delivery.html、manifest、execution_trace、content_delivery_record 闭合。
人类门禁只出现在 R1 允许节点。
```

静态验收和样本清单见：

```text
docs/product/R1-skill编译验收与sample-run清单.md
```

---

## 8. 测试前补强

根据成熟项目预审，R1 在正式 sample run 前补强了四个点：

| 缺口 | 补强位置 | 结果 |
|---|---|---|
| 长 `SKILL.md` 容易靠全文硬撑 | `docs/reference/R1-skill渐进读取与长文边界.md` + 各 `SKILL.md` Runtime | 已规定先读 Runtime / 交接块，再按需读细节 |
| 旧 session 和 R1 新样本容易混 | `docs/reference/文档治理与目录规范.md`、`docs/reference/skill执行透明度与成熟度规范.md` | R1 验收必须新建 session，旧 session 只能参考 |
| 人类决策后恢复字段不够硬 | `docs/reference/人类引导与任务后导航规范.md` | 已补 `decision_type` 对应 manifest / workflow_session_record 更新表 |
| trace/check 仍像事后清单 | `docs/product/R1-skill编译验收与sample-run清单.md` | 已补测试前硬闸门，不满足则不开始 sample run |
| 缺少 sample run 标准模板 | `docs/reference/R1-sample-run产物模板.md` + `propagation-router/SKILL.md` | 已补 manifest、execution trace、trace check、人工决策恢复和 r1_preflight 模板 |

当前 R1 仍不包含：

```text
自动 validator 脚本。
R2 fan-out / fan-in。
R3 图片资产数量合同。
R4 开源净化包。
```

---

## 9. SAMPLE-HISTORICAL-005 后 R1 返修编译

时间：2026-07-07  
触发：SAMPLE-HISTORICAL-005 跑通单篇主链路后，暴露出 R1 编译缩水和恢复边界问题。  
确认：涛哥已回复“认可 R1 返修项，进入 skill 编译修订”。

本轮只修 R1，不扩大到 R2 / R3 / R4。

### 9.1 编译范围

| R1 项 | 问题 | 编译位置 |
|---|---|---|
| R1-C15 | 画中画 prompt 从完整结构缩水成短关键词 | `skills/talking-head-image-pip/CONTRACT.md`、`skills/talking-head-image-pip/SKILL.md` |
| R1-C16 | 视觉质检没有拦住泛素材图 | `skills/copywriting-quality-review/CONTRACT.md`、`skills/copywriting-quality-review/SKILL.md` |
| R1-C17 | execution_trace 对 imagegen 使用记录不自洽 | `skills/final-delivery-builder/CONTRACT.md`、`skills/final-delivery-builder/SKILL.md` |
| R1-C18 | R1 恢复能力边界不清 | `skills/propagation-router/CONTRACT.md`、`skills/propagation-router/SKILL.md` |

### 9.2 实际编译动作

`talking-head-image-pip`：

```text
新增 R1CHK-017 prompt 完整度硬规则。
要求每张图保留完整 prompt 卡和五槽提示词。
实际出图时 `prompt_used` 必须是完整 prompt 或可追溯到完整 prompt_id。
任一核心层缺失时，visual_plan_status = visual_plan_needs_fix，不得进入质检。
```

`copywriting-quality-review`：

```text
新增 visual_quality_gate_status 和 prompt_integrity_status。
明确“有图不等于通过”。
图片泛素材化、只装饰、不服务留存任务、prompt 卡不完整时，review_status = review_needs_visual_fix。
```

`propagation-router`：

```text
新增 R1CHK-020 / R1CHK-110 执行口径。
断流或恢复时先读 STATUS、工作流状态记录、manifest、execution_trace。
R1 只提供恢复证据，不承诺脚本级 checkpoint / retry / run lock。
```

`final-delivery-builder`：

```text
新增 trace_consistency_status 和 recovery_evidence_status。
最终交付收口时检查 manifest、execution_trace、image_asset_set（旧别名：image_asset_manifest）和实际图片文件是否自洽。
如果图片已生成但 trace 写未使用图片生成能力，必须标记 trace_consistency_status = fail。
```

### 9.3 仍不进入本轮的内容

```text
R2：真正 checkpoint、resume_from、幂等、retry、run lock、branch lock。
R3：画中画数量合同、Seedream 外部模型兼容、图片资产重试链。
R4：portable_bundle、standalone_html、GitHub 开源样例和净化包。
```


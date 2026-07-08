# R1 Trace / Check 注册表

> 状态：r1_confirmed_compiled_waiting_checker_productization  
> 所属路线：R1 方法论没有编译成执行合同  
> 解决缺口：把 P13 的 BLOCKER / WARN 规则拆成可执行、可定位、可反写的原子检查项。  
> 边界：本文件只定义 check 注册表；当前不写 validator 脚本，不改 `skills/*/SKILL.md`。

---

## 1. 为什么需要 check 注册表

P13 已经定义了：

```text
BLOCKER / WARN / INFO。
trace 必备结构。
validator 输出字段。
```

但这些仍偏“规则清单”。成熟 workflow 的检查通常会拆成原子项：

```text
每个 check 只检查一个属性。
每个 check 有明确输入。
每个 check 有失败等级。
每个 check 能给出反写位置。
```

R1 需要这张注册表，避免未来 validator 变成一段模糊判断。

---

## 2. Check 字段

每个检查项必须包含：

```yaml
check_id:
check_name:
check_target:
input_files:
check_rule:
severity: BLOCKER / WARN / INFO
failure_message:
required_backwrite:
applies_to:
```

字段说明：

| 字段 | 含义 |
|---|---|
| `check_id` | 稳定 ID，后续 validator / trace 都引用它 |
| `check_target` | 检查 artifact、路径、字段、门禁或执行来源 |
| `input_files` | 检查需要读取哪些文件 |
| `check_rule` | 一句话说明怎么判定 |
| `severity` | 失败等级 |
| `required_backwrite` | 失败后应反写到哪里 |
| `applies_to` | 适用阶段或 skill |

---

## 3. R1 必备 BLOCKER Checks

| check_id | check_target | check_rule | required_backwrite |
|---|---|---|---|
| `R1CHK-001` | manifest | `manifest.yaml` 必须存在 | `docs/reference/文档治理与目录规范.md` |
| `R1CHK-002` | execution_trace | `intermediate/00-execution-trace.md` 必须存在 | `docs/reference/skill执行透明度与成熟度规范.md` |
| `R1CHK-003` | current_artifact | `manifest.current_artifact` 必须指向本 session 下存在文件 | `docs/reference/文档治理与目录规范.md` |
| `R1CHK-004` | contract_set_version | R1 编译后新样本必须记录 `contract_set_version` | `docs/product/R1-合同版本与变更治理.md` |
| `R1CHK-005` | trace_sections | trace 必须包含摘要、动作表、成熟度观察、扶跑清单 | `docs/reference/skill执行透明度与成熟度规范.md` |
| `R1CHK-006` | source_research_run_id | `source_research_run_id` 必须贯穿 topic_card 到 content_delivery_record | `交接物字段词典.md` |
| `R1CHK-007` | auto_next | 选题确认后不得停在“是否生成 Brief / 是否继续写口播” | `docs/reference/人类引导与任务后导航规范.md` |
| `R1CHK-008` | auto_next | `brief_status=brief_pass` 后不得要求用户回复继续 | `skills/content-brief-compiler/CONTRACT.md` |
| `R1CHK-009` | auto_next | `review_status=review_pass` 后不得要求用户回复继续做分发包 | `skills/copywriting-quality-review/CONTRACT.md` |
| `R1CHK-010` | auto_next | 平台包完成后必须进入 `content_delivery_record` 和 final delivery，不得停在确认采用 | `skills/platform-packaging-adapter/CONTRACT.md` |
| `R1CHK-011` | human_gate | 人类门禁必须在 allowed gate 列表内 | `docs/product/R1-人类门禁决策枚举与恢复规则.md` |
| `R1CHK-012` | agent_created_rule | action table 出现 `agent_created_rule` 时，扶跑清单必须有反写项 | `docs/reference/skill执行透明度与成熟度规范.md` |
| `R1CHK-013` | publish_boundary | 不得自动发布、登录平台、自动评论、私信或互动 | `AGENTS.md` |
| `R1CHK-014` | final_delivery | 最终交付不得只有 Markdown；必须有 final-delivery.html 或明确 blocked 原因 | `skills/final-delivery-builder/CONTRACT.md` |
| `R1CHK-015` | image_assets_status | HTML 声称有图片时，图片状态不能是 pending / failed / manual_required | `交接物字段词典.md` |
| `R1CHK-016` | multi_topic | R1 单 session 不得混入多个独立选题正文；多选必须标 `branch_request` | `docs/product/R1-人类门禁决策枚举与恢复规则.md` |
| `R1CHK-017` | visual_prompt_integrity | `visual_plan` 中每张生成图片的 prompt 不得缩水成短关键词，必须包含留人任务、口播语义、画面类型、主体动作、场景环境、镜头构图、光线情绪、风险约束、负面提示和验收标准；缺任一核心层时失败 | `skills/talking-head-image-pip/CONTRACT.md` |
| `R1CHK-018` | visual_quality_gate | `quality_review` 必须检查画中画是否服务明确留存任务、是否贴合口播当下语义、是否只是好看但没用；有图但未通过这些检查时不得 `review_pass` | `skills/copywriting-quality-review/CONTRACT.md` |
| `R1CHK-019` | trace_consistency | execution_trace、manifest 和实际产物对同一环境能力的记录必须一致，例如已生成图片时不得再写“本轮尚未使用图片生成能力” | `docs/reference/skill执行透明度与成熟度规范.md` |
| `R1CHK-020` | recovery_evidence | R1 样本必须提供足够恢复证据：manifest 记录当前阶段 / 当前产物 / next_skill，trace 最后一条动作能说明已完成、等待人类或阻断原因；断流后 AI 应能判断是否重跑、继续或只做 postcheck | `docs/product/R1-产品总览.md` |

---

## 4. R1 必备 WARN Checks

| check_id | check_target | check_rule | required_backwrite |
|---|---|---|---|
| `R1CHK-101` | agent_assist_level | `agent_assist_level=medium` 允许，但必须有扶跑说明 | `docs/reference/skill执行透明度与成熟度规范.md` |
| `R1CHK-102` | skill_inferred | `skill_inferred` 步骤超过核心动作一半时，提示合同需收紧 | `skills/{skill}/CONTRACT.md` |
| `R1CHK-103` | product_object | 产品 / 观点对象由 agent 建议生成时，必须记录依据和边界 | `产品与活动对象档案.md` |
| `R1CHK-104` | root_index | 根目录汇总 / indexes 手工维护时，应记录为 agent assist | `docs/reference/文档治理与目录规范.md` |
| `R1CHK-105` | source_quality | 来源可用但缺少质量等级时，提示补来源质量 | `热点搜索来源池.md` |
| `R1CHK-106` | image_fallback | 图片使用外部或手工降级时，必须标记 provider / fallback_note | `docs/explanation/最终交付页与图片降级策略.md` |
| `R1CHK-107` | failure_examples | 某个 skill 合同只有 happy path，缺失败样例时提示补合同 | `skills/{skill}/CONTRACT.md` |
| `R1CHK-108` | final_prompt | 最终导航缺少 2-3 个有理由的下一步时提示修引导 | `docs/reference/人类引导与任务后导航规范.md` |
| `R1CHK-109` | test_scope | R1 sample run 被表述为“完整真实测试通过”时必须警告；R1 只验证单篇主链路，完整真实测试需等 R1-R4 编译闭合 | `docs/product/GitHub开源上线前Workflow修复路线图.md` |
| `R1CHK-110` | resume_scope | R1 被表述为“脚本级断点续跑 / 自动 resume runner”时必须警告；R1 只有恢复证据，checkpoint / 幂等 / retry / lock 进入 R2 | `docs/product/GitHub开源上线前Workflow修复路线图.md` |

---

## 5. R1 INFO Checks

| check_id | check_target | check_rule |
|---|---|---|
| `R1CHK-201` | environment_capability | 记录联网、image、文件系统等能力来自环境，不算 skill 本身能力 |
| `R1CHK-202` | user_decision | 记录用户选题、认可、归档、人工发布等明确决策 |
| `R1CHK-203` | manual_fallback | 记录外部生成、人工处理或无法自动完成的降级 |
| `R1CHK-204` | contract_migration_note | 旧 session 恢复时记录是否使用推断合同版本 |

---

## 6. Check 输出模板

未来每次检查可输出：

```yaml
trace_check_id:
session_id:
contract_set_version:
overall_result: pass / pass_with_warnings / fail
checks:
  - check_id:
    result: pass / fail / not_applicable
    severity:
    evidence:
    failure_message:
    required_backwrite:
blocking_issues:
warnings:
info:
r1_compile_ready: yes / no
next_action:
```

`overall_result` 计算规则：

```text
任一 BLOCKER fail -> overall_result = fail。
无 BLOCKER fail，但有 WARN fail -> overall_result = pass_with_warnings。
全部必备项 pass -> overall_result = pass。
```

---

## 7. 对 SAMPLE-HISTORICAL-005 的返修校准

SAMPLE-HISTORICAL-005 是 R1 第一轮编译后的新样本。它不应被删除，也不应被当成完整真实测试通过；它的价值是暴露 R1 返修项。

初步校准：

```text
R1CHK-001 pass
R1CHK-002 pass
R1CHK-003 pass
R1CHK-004 pass
R1CHK-006 pass
R1CHK-007 pass
R1CHK-014 pass
R1CHK-015 pass
R1CHK-017 fail，visual_plan 中 prompt_used 缩水为短关键词，未完整落盘五槽 / 验收标准
R1CHK-018 fail，quality_review 未拦住泛素材图，仍判 review_pass
R1CHK-019 fail，execution_trace 同时记录使用 imagegen 和“未使用图片生成能力”
R1CHK-020 pass_with_warning，manifest + trace 足以人工 / AI 判断已到 final_delivery，但没有阶段级 checkpoint
R1CHK-109 warn，SAMPLE-HISTORICAL-005 只能证明 R1 单篇主链路，不代表完整真实测试通过
R1CHK-110 warn，不能把本轮恢复能力描述为脚本级断点续跑
overall_result = fail，需 R1 产品层返修后再进入 skill 编译修订
```

---

## 8. 对 SAMPLE-HISTORICAL-002 的校准

如果用本注册表校准 `SAMPLE-HISTORICAL-002`，初步预期：

```text
R1CHK-001 pass
R1CHK-002 pass
R1CHK-003 pass
R1CHK-004 not_applicable，因该样本早于 R1 合同版本治理
R1CHK-101 warn，agent_assist_level = medium
R1CHK-103 warn，观点对象由 agent 建议生成
R1CHK-104 warn，根目录汇总和索引由 agent 手工维护
overall_result = pass_with_warnings
```

这说明注册表不是为了否定旧样本，而是让“旧样本哪里不够 L3”能被稳定指出。

---

## 9. 后续反写位置

R1 确认后，本注册表应反写或引用到：

```text
docs/reference/skill执行透明度与成熟度规范.md
docs/reference/文档治理与目录规范.md
docs/reference/人类引导与任务后导航规范.md
skills/propagation-router/CONTRACT.md
skills/final-delivery-builder/CONTRACT.md
后续 validator 脚本或人工检查表
```

当前不写脚本，不改 reference。

---

## 10. 验收标准

本小循环通过标准：

```text
[x] 定义 check 注册字段。
[x] 拆出 R1 BLOCKER check。
[x] 拆出 R1 WARN check。
[x] 拆出 R1 INFO check。
[x] 定义 overall_result 计算规则。
[x] 用 SAMPLE-HISTORICAL-002 做校准预期。
[x] 定义后续反写位置。
```

当前结论：

```text
R1 trace/check 注册表达到产品定义可确认状态。
R1 产品层四个新增缺口已补齐，可重新收口总验收。
```


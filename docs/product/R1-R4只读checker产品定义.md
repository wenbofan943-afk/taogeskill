# R1-R4 只读 Checker 产品定义

> 状态：confirmed_and_compiled  
> 所属路线：GitHub 开源上线前 Workflow 修复路线图 / Step 2  
> 主责：把 R1-R4 已有人工检查项收敛成一个只读 checker 的产品规格，后续可编译为 reference / skill / 脚本化检查。  
> 边界：本文是已确认的产品定义；已编译为 reference 执行规范、报告模板和 propagation-router 路由规则，但不写自动修复脚本，不生成图片，不生成 public_release，不推 GitHub。

---

## 1. 为什么需要只读 Checker

R1-R4 已经完成产品定义、规则 / skill 编译和综合 dry-run，但当前检查仍主要靠 agent 人工扫：

```text
状态是否互相打架。
manifest / current_artifact 是否断链。
选题确认后是否自动到底。
多篇是否串台。
图片状态是否诚实。
final-delivery.html 是否只是 project_local。
public_release 是否被误写成已发布。
execution_trace 是否能说明 skill 和 agent 各做了什么。
```

成熟 workflow 通常会把这些判断沉淀为可重复的检查层：

| 成熟做法 | 本项目吸收 |
|---|---|
| Dagster Asset Checks | 对最终 HTML、图片、manifest、public_release 这类资产做独立检查，不把检查混进生产动作 |
| OpenSSF Scorecard | 输出可读的阻断项、警告项和成熟度，不直接替用户发布 |
| GitHub Community Health | 开源前检查 README、License、样例、贡献、安全边界 |
| Temporal Event History | 从运行历史和 trace 判断是否能恢复，而不是凭聊天记忆 |
| LangGraph Interrupt / Persistence | 把人类门禁和恢复点当成检查对象 |

本项目的取舍：

```text
alpha 阶段先做只读 checker。
checker 只报告，不自动修。
checker 先覆盖 P0 / P1 断链和越界问题。
脚本化之前，产品定义和 reference 仍是真源。
```

---

## 2. Checker 范围

### 2.1 必须覆盖

| 分组 | 覆盖对象 | 来源真源 |
|---|---|---|
| R1 内容主链路 | manifest、execution_trace、自动推进、人类门禁、research_run_id、最终 HTML | `docs/product/R1-trace-check注册表.md`、`docs/reference/skill执行透明度与成熟度规范.md` |
| R2 运行模型 | parent / child、branch_request、checkpoint、run_lock、resume_report、索引 | `docs/reference/R2-运行模型执行规范.md` |
| R3 图片资产 | visual_budget、required_visuals、image_status、sidecar、html_embed_manifest、图片路径 | `docs/reference/R3-图片资产执行规范.md` |
| R4 开源边界 | public_release、License、sample、隐私、密钥、本机路径、成熟度宣称 | `docs/reference/GitHub开源上线检查清单.md` |
| 文档治理 | README、PROJECT_MAP、STATUS、工作流状态记录、孤岛文档、旧状态残留 | `docs/reference/文档治理与目录规范.md` |

### 2.2 本阶段不覆盖

```text
不判断内容观点好不好。
不判断文案商业转化强不强。
不判断图片审美是否足够高级。
不调用 image 生成。
不联网核验真实热点。
不自动生成 public_release。
不自动修复任何文件。
```

这些属于后续样本验证、内容质检或人工评审，不塞进只读 checker。

---

## 3. 输入

checker 支持三种输入范围：

| check_scope | 使用场景 | 必需输入 |
|---|---|---|
| `session` | 检查一条内容生产 session | `accounts/{account}/runs/{session_id}/manifest.yaml` |
| `sample` | 检查 dry-run / tutorial 样本 | sample 根目录 README 或 sample manifest |
| `project` | 检查项目治理和开源前状态 | `STATUS.md`、`工作流状态记录.md`、`PROJECT_MAP.md`、路线图 |

输入最小字段：

```yaml
checker_input:
  check_id:
  check_scope: session / sample / project
  target_path:
  target_account:
  session_id:
  contract_set_version:
  expected_maturity:
  requested_by:
  readonly: true
```

读取顺序：

```text
target_path
-> manifest.yaml 或 sample README
-> current_artifact
-> intermediate/00-execution-trace.md
-> 必需 intermediate / deliverables / assets
-> STATUS.md
-> 工作流状态记录.md
-> README.md / PROJECT_MAP.md
-> 对应 R1 / R2 / R3 / R4 reference
```

如果是 `project` 范围，不要求读取真实账号生产内容，只检查项目级入口、状态和索引。

---

## 4. 输出

checker 必须输出 `workflow_check_report`。

默认路径：

| check_scope | 默认输出 |
|---|---|
| `session` | `accounts/{account}/runs/{session_id}/intermediate/checks/{check_id}.md` |
| `sample` | `{sample_root}/checks/{check_id}.md` |
| `project` | `docs/product/checks/{check_id}.md` |

产品开发阶段如果不想新增 report 文件，可以先把结论写入路线图或工作流状态记录；但进入 checker 编译后，必须使用稳定报告路径。

最小输出字段：

```yaml
workflow_check_report:
  check_id:
  checked_at:
  check_scope:
  target_path:
  checker_version:
  readonly: true
  overall_result: pass / pass_with_warnings / fail / blocked
  maturity_observed: l0 / l1 / l2 / l2_8 / l3_candidate / l3
  blocking_count:
  warning_count:
  info_count:
  checks:
    - check_item_id:
      group:
      severity: blocker / warn / info
      status: pass / fail / not_applicable / not_run
      evidence:
      recommendation:
      backwrite_target:
  next_action:
  human_prompt:
```

---

## 5. 检查等级

| severity | 含义 | 后果 |
|---|---|---|
| `blocker` | 会导致断链、串台、越界发布、状态误判或成熟度误报 | `overall_result = fail / blocked` |
| `warn` | 不阻断本次阅读，但不能用于宣称 L3 或完整测试通过 | `overall_result = pass_with_warnings` |
| `info` | 记录范围、环境、人工决策或可选增强 | 不影响通过 |

`blocked` 和 `fail` 的区别：

```text
blocked：输入不足，无法完成检查，例如 target_path 不存在。
fail：输入可读，但检查项命中 blocker。
```

---

## 6. 检查项分组

### CHECK-GOV 项目治理

| ID | 等级 | 检查项 |
|---|---|---|
| CHECK-GOV-001 | blocker | `STATUS.md`、`工作流状态记录.md`、路线图当前阶段不互相冲突 |
| CHECK-GOV-002 | warn | README / PROJECT_MAP 已索引新增产品、reference、tutorial、template |
| CHECK-GOV-003 | warn | 没有新增孤岛 Markdown |
| CHECK-GOV-004 | blocker | 不把草案状态写成已发布、完整真实测试通过或 L3 |
| CHECK-GOV-005 | blocker | 本项目没有越界到客户端、服务器、数据库、license、积分或平台发布链路 |

### CHECK-R1 内容链路

| ID | 等级 | 检查项 |
|---|---|---|
| CHECK-R1-001 | blocker | session 有 `manifest.yaml` |
| CHECK-R1-002 | blocker | 有 `intermediate/00-execution-trace.md` |
| CHECK-R1-003 | blocker | `current_artifact` 指向 session 内可读文件 |
| CHECK-R1-004 | blocker | `research_run_id` / `source_research_run_id` 贯穿到最终交付 |
| CHECK-R1-005 | blocker | 用户选题后没有错停在“继续写口播 / 继续做分发包” |
| CHECK-R1-006 | blocker | 人类门禁只出现在账号确认、选题确认、最终交付验收等允许节点 |
| CHECK-R1-007 | blocker | 最终交付不是只有 Markdown，必须有 `final-delivery.html` 或明确阻断原因 |
| CHECK-R1-008 | warn | `agent_assist_level` 不高于 medium；high 不能作为 L3 样本 |

### CHECK-R2 运行模型

| ID | 等级 | 检查项 |
|---|---|---|
| CHECK-R2-001 | blocker | 多选请求没有混入单 session 正文 |
| CHECK-R2-002 | blocker | parent / child session 边界清楚，parent 不保存 child 正文 |
| CHECK-R2-003 | warn | 有 checkpoint 或明确说明不是脚本级断点续跑 |
| CHECK-R2-004 | warn | `run_lock`、`state_transition`、`resume_report` 有恢复证据 |
| CHECK-R2-005 | blocker | 产品开发 / 文档治理任务中的多篇请求不会启动真实内容 fan-out |

### CHECK-R3 图片资产

| ID | 等级 | 检查项 |
|---|---|---|
| CHECK-R3-001 | blocker | `required_visuals` 与视觉预算一致，或有增减理由 |
| CHECK-R3-002 | blocker | 每张 required 图有 `retention_task` 和插入位置 |
| CHECK-R3-003 | blocker | 每张 required 图有完整 prompt_card，不缩水成关键词 |
| CHECK-R3-004 | blocker | `generated` 图片必须有实际文件路径且可读 |
| CHECK-R3-005 | blocker | `generated` 图片必须有 metadata sidecar |
| CHECK-R3-006 | blocker | `pending_external / generation_failed / manual_required` 不得在 HTML 中伪装成 generated |
| CHECK-R3-007 | warn | pending_external 路径通过不等于 generated 路径通过 |
| CHECK-R3-008 | warn | HTML 能展示占位、prompt、插入位置和追溯链接 |

### CHECK-R4 开源交付

| ID | 等级 | 检查项 |
|---|---|---|
| CHECK-R4-001 | blocker | 未确认 License 前，不得宣称 GitHub 发布就绪 |
| CHECK-R4-002 | blocker | 未生成真实 `public_release/` 前，不得宣称 public_release 已通过 |
| CHECK-R4-003 | blocker | 公开候选包不得包含真实账号 runs、真实客户资料、密钥、Cookie、token |
| CHECK-R4-004 | blocker | 公开入口不得依赖 `D:\OpenClaw\`、`C:\Users\` 或 `file://` |
| CHECK-R4-005 | warn | sample 必须声明是否验证 generated 图片路径 |
| CHECK-R4-006 | warn | release-checklist 能说明 pass / warnings / blocked 的原因 |

---

## 7. 运行模式

| mode | 用途 | 是否改文件 |
|---|---|---|
| `inspect_only` | 只读检查并输出报告 | 否 |
| `report_only` | 检查后只写 report 文件 | 只写 report |
| `suggest_backwrite` | 在报告里列出建议反写位置 | 只写 report |

禁止模式：

```text
auto_fix
auto_publish
auto_generate_image
auto_create_public_release
auto_push_github
```

---

## 8. 编译目标

本产品定义已获涛哥确认，并进入 Step 3：只读 checker 编译。

编译产物建议：

```text
docs/reference/R1-R4只读checker执行规范.md：已编译
templates/checker/workflow-check-report.template.md：已编译
skills/propagation-router/SKILL.md 增加 checker 路由：已编译
skills/propagation-router/CONTRACT.md 增加 checker 合同：已编译
交接物字段词典.md 增加 workflow_check_report：已完成
```

是否新增脚本工具留到下一轮判断。alpha 阶段可以先由 AI 按 reference 只读执行，不能把这说成成熟 CI。

---

## 9. 确认清单

如果认可本产品定义，等于确认：

```text
CHECK-C01：checker 第一阶段只读，不自动修。
CHECK-C02：checker 覆盖 R1-R4 P0 / P1 断链、越界、状态误报，不检查内容审美。
CHECK-C03：checker 输出 workflow_check_report，字段稳定。
CHECK-C04：blocker / warn / info 分级采用本文口径。
CHECK-C05：pending_external 通过不等于 generated 路径通过。
CHECK-C06：public_release 未生成前不得宣称开源发布就绪。
CHECK-C07：checker 产品定义确认后，才进入 reference / skill 编译。
```

---

## 10. 给人的引导语

确认时建议这样说：

```text
这一步确认的不是“现在要写脚本”，而是确认 checker 应该检查什么、只读到什么程度、报告长什么样。确认后我会把它编译成执行规范和模板，让后续 AI 能按同一张检查表跑，不再靠临场眼扫。
```

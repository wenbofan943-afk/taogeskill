# R1-R4 只读 Checker 执行规范

> 状态：active  
> 所属路线：GitHub 开源上线前 Workflow 修复路线图 / Step 3  
> 主责：把 `docs/product/R1-R4只读checker产品定义.md` 编译成可执行的只读检查规范，供 `propagation-router`、样本验收和后续脚本化 checker 使用。  
> 边界：本规范只读检查并生成 `workflow_check_report`、`sample_check_report` 或 `release_check_report`；不自动修文件、不生成图片、不生成 public_release、不推 GitHub。

---

## 1. 触发场景

当用户或路由出现以下意图时，进入本规范：

```text
检查当前 workflow 质量。
做 checker。
做只读检查。
检查 R1-R4 是否闭合。
检查是否能进入下一阶段。
状态、链接、图片资产、public_release 是否有问题。
开源前先验收一下。
```

也可由 `propagation-router` 在以下节点推荐：

```text
状态真源扫表后。
R1-R4 综合 dry-run 后。
checker 产品定义确认后。
进入 R3 generated 样本前。
进入 R4 public_release candidate 前。
```

---

## 2. 只读边界

checker 必须遵守：

```text
只能读取文件。
只能输出报告。
不能自动修文件。
不能改 manifest。
不能生成图片。
不能生成 public_release。
不能推 GitHub。
不能把检查通过说成完整真实测试通过。
```

允许写入的新产物只能是检查报告：

```text
workflow_check_report：项目 / session / workflow 主线检查。
sample_check_report：公开样例、dry-run 样例、tester sample 检查。
release_check_report：public_release 候选包、zip、release candidate 检查。
```

P3 优化后，checker 报告必须同时照顾人类阅读和后续自动化读取：

```text
human_readable_report_path：Markdown 报告，说明问题、证据和下一步。
machine_readable_report_path：JSON / YAML 报告，保留同一组字段，供后续 CI、AI 或脚本读取。
```

两类报告必须使用同一个 `check_run_id`。不得出现机器报告 pass、人类报告 fail 的冲突。

---

## 3. 输入范围

### 3.1 `project`

用于项目治理检查。

必读：

```text
STATUS.md
工作流状态记录.md
README.md
PROJECT_MAP.md
docs/product/GitHub开源上线前Workflow修复路线图.md
交接物字段词典.md
```

按需读：

```text
docs/reference/文档治理与目录规范.md
docs/reference/人类引导与任务后导航规范.md
docs/reference/skill执行透明度与成熟度规范.md
docs/reference/R2-运行模型执行规范.md
docs/reference/R3-图片资产执行规范.md
docs/reference/GitHub开源上线检查清单.md
```

### 3.2 `session`

用于检查真实内容 session。

必读：

```text
accounts/{account}/runs/{session_id}/manifest.yaml
accounts/{account}/runs/{session_id}/intermediate/00-execution-trace.md
manifest.current_artifact
manifest 指向的必需 intermediate / deliverables / assets
```

### 3.3 `sample`

用于检查 tutorial / dry-run 样本。

必读：

```text
sample README
sample manifest 或 sample run 说明
sample 中的 trace / final-delivery / public-release-precheck
```

---

## 4. 输出路径

| check_scope | 输出路径 |
|---|---|
| `project` | `docs/product/checks/{check_id}.md` |
| `session` | `accounts/{account}/runs/{session_id}/intermediate/checks/{check_id}.md` |
| `sample` | `{sample_root}/checks/{check_id}.md` |
| `public_release` | `public_release/release-checklist.md` 或 `docs/product/checks/{check_id}.md` |
| `zip` | `docs/product/checks/{check_id}.md` |
| `release_candidate` | `docs/product/checks/{check_id}.md` |

命名规则：

```text
CHECK-{scope}-{YYYYMMDD}-{NNN}.md
```

示例：

```text
CHECK-project-20260707-001.md
CHECK-session-SAMPLE-HISTORICAL-005-001.md
CHECK-sample-SR1R4DR-001-001.md
CHECK-public-release-20260707-001.md
```

---

## 5. 报告字段

项目 / session 主线检查必须使用 `workflow_check_report` 字段。

最小结构：

```yaml
workflow_check_report:
  check_id:
  checked_at:
  check_scope:
  target_path:
  checker_version: r1-r4-readonly-checker-v0.1
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

样例检查必须使用 `sample_check_report` 字段：

```yaml
sample_check_report:
  check_report_id:
  sample_id:
  sample_goal:
  sample_status: draft / ready_for_review / accepted / needs_fix
  happy_path_result:
  failure_case_result:
  expected_recovery_result:
  privacy_status:
  link_status:
  field_gate_status:
  image_asset_status:
  human_guidance_status:
  artifact_path:
  next_action:
```

公开候选包检查必须使用 `release_check_report` 字段：

```yaml
release_check_report:
  check_report_id:
  check_scope: public_release / zip / release_candidate
  check_run_id:
  command_name:
  command_version:
  exit_code: 0 / 1 / 2 / 3 / 4
  severity_policy: blocker_fails / warning_allows / info_only
  checked_at:
  checked_by:
  input_path:
  overall_result: pass / pass_with_warnings / fail / blocked
  blocker_count:
  warning_count:
  blockers:
  warnings:
  info_items:
  evidence_paths:
  remediation_items:
  machine_readable_report_path:
  human_readable_report_path:
  artifact_manifest_path:
  reproducibility_status: reproducible / not_reproducible / not_run / unknown
  privacy_scan_result:
  link_check_result:
  field_gate_result:
  contract_sync_result:
  image_asset_check_result:
  release_state_result:
  zip_path:
  sha256_path:
  artifact_path:
  next_action:
```

P3 exit code 合同：

```text
0：pass，无 blocker。
1：fail，至少一个 blocker fail。
2：blocked，必要输入缺失或检查无法完成。
3：tool_error，checker 自身异常。
4：usage_error，命令参数或路径错误。
```

P3 命令模式：

| mode | 使用时机 | 必跑层 |
|---|---|---|
| fast | 日常产品 / skill 编译后 | field_gate、contract_sync、README / PROJECT_MAP 索引 |
| standard | sample dry-run 前后 | fast + sample_behavior、link_check、image_asset_check |
| release | public_release candidate 前 | standard + privacy_security、release_package、release_state、zip_hash |

失败证据字段：

```yaml
check_item:
  check_item_id:
  severity: blocker / warn / info
  status: pass / fail / not_applicable / not_run
  evidence_paths:
  evidence_summary:
  remediation_items:
  owner_area:
```

---

## 6. 判定规则

```text
任一 blocker fail -> overall_result = fail。
输入缺失导致无法检查 -> overall_result = blocked。
无 blocker fail 但有 warn fail -> overall_result = pass_with_warnings。
全部 blocker / warn 通过或 not_applicable -> overall_result = pass。
```

成熟度判定：

```text
checker 通过不自动提升成熟度。
pending_external 图片路径通过不等于 generated 路径通过。
public_release 模板通过不等于 public_release candidate 通过。
project / sample 检查通过不等于完整真实内容测试通过。
```

---

## 7. 检查项

### CHECK-GOV 项目治理

| ID | 等级 | 检查方式 |
|---|---|---|
| CHECK-GOV-001 | blocker | 对比 `STATUS.md`、`工作流状态记录.md`、路线图当前阶段是否冲突 |
| CHECK-GOV-002 | warn | 新增产品、reference、tutorial、template 是否被 README / PROJECT_MAP 索引 |
| CHECK-GOV-003 | warn | 新增 Markdown 是否有入口引用 |
| CHECK-GOV-004 | blocker | 是否把草案、样本、模板误写成已发布、完整真实测试通过或 L3 |
| CHECK-GOV-005 | blocker | 是否越界到客户端、服务器、数据库、license、积分或平台发布链路 |
| CHECK-GOV-006 | blocker | `field_gate_status=fail` 时不得进入 sample / release |
| CHECK-GOV-007 | warn | 新增字段缺少 future validator 检查项 |

### CHECK-R1 内容链路

| ID | 等级 | 检查方式 |
|---|---|---|
| CHECK-R1-001 | blocker | session 有 `manifest.yaml` |
| CHECK-R1-002 | blocker | session 有 `intermediate/00-execution-trace.md` |
| CHECK-R1-003 | blocker | `current_artifact` 指向 session 内可读文件 |
| CHECK-R1-004 | blocker | `research_run_id` / `source_research_run_id` 贯穿到最终交付 |
| CHECK-R1-005 | blocker | 没有错停在“继续写口播 / 继续做分发包” |
| CHECK-R1-006 | blocker | 人类门禁只出现在允许节点 |
| CHECK-R1-007 | blocker | 最终交付不是只有 Markdown |
| CHECK-R1-008 | warn | `agent_assist_level` 不高于 medium；high 不能作为 L3 样本 |
| CHECK-R1-009 | warn | `manual_proxy_test` / `simulated_by_agent_for_test` 必须标记清楚，不能冒充真实人类确认 |

### CHECK-R2 运行模型

| ID | 等级 | 检查方式 |
|---|---|---|
| CHECK-R2-001 | blocker | 多选请求没有混入单 session 正文 |
| CHECK-R2-002 | blocker | parent / child session 边界清楚 |
| CHECK-R2-003 | warn | 有 checkpoint 或明确说明不是脚本级断点续跑 |
| CHECK-R2-004 | warn | `run_lock`、`state_transition`、`resume_report` 有恢复证据 |
| CHECK-R2-005 | blocker | 产品开发 / 文档治理任务中的多篇请求不会启动真实内容 fan-out |

### CHECK-R3 图片资产

| ID | 等级 | 检查方式 |
|---|---|---|
| CHECK-R3-001 | blocker | `visual_need_analysis` 通过，`derived_visual_count` 等于 accepted task 数；允许 0、不设 max |
| CHECK-R3-002 | blocker | 每张 accepted 图有主视觉任务、缺图损失、预期观看改变和插入位置；0 图有有效 `zero_visual_reason` |
| CHECK-R3-003 | blocker | 每张 accepted 图有完整 prompt_card，且 Image 2 可用时没有被成本或 call limit 截断 |
| CHECK-R3-003A | blocker | analysis pass 时 `human_confirmation_required=false`、`next_skill=image-prompt-compiler`，不得停在 accepted task 人工确认 |
| CHECK-R3-004 | blocker | `generated` 图片有实际文件路径且可读 |
| CHECK-R3-005 | blocker | `generated` 图片有 metadata sidecar |
| CHECK-R3-006 | blocker | pending / failed / manual 不在 HTML 中伪装成 generated |
| CHECK-R3-007 | warn | 明确标记 pending_external 通过不等于 generated 通过 |
| CHECK-R3-008 | warn | HTML 能展示占位、prompt、插入位置和追溯链接 |
| CHECK-R3-009 | warn | generated 图片不仅文件存在，还应有 prompt 贴合度、传播任务达成度和是否可用的人工评分 |

### CHECK-R4 开源交付

| ID | 等级 | 检查方式 |
|---|---|---|
| CHECK-R4-001 | blocker | 未确认 License 前，不宣称 GitHub 发布就绪 |
| CHECK-R4-002 | blocker | 未生成真实 `public_release/` 前，不宣称 public_release 已通过 |
| CHECK-R4-003 | blocker | 公开候选包不得包含真实账号 runs、真实客户资料、密钥、Cookie、token |
| CHECK-R4-004 | blocker | 公开入口不得依赖 `D:\OpenClaw\`、`C:\Users\` 或 `file://` |
| CHECK-R4-005 | warn | sample 声明是否验证 generated 图片路径 |
| CHECK-R4-006 | warn | release-checklist 说明 pass / warnings / blocked 的原因 |
| CHECK-R4-007 | blocker | offline tester package 与 public_release candidate 必须区分；线下测试包可含真实测试样本，公开候选包不得含真实 accounts runs |
| CHECK-R4-008 | warn | portable_bundle / offline tester package 必须做包内链接检查和 manifest/hash 检查 |
| CHECK-R4-009 | blocker | release_check_report 缺失时，不能宣称 public_release 通过 |
| CHECK-R4-010 | blocker | sample_check_report 缺失时，不能宣称样例 ready_for_review 或 accepted |
| CHECK-R4-011 | blocker | release 模式缺少 `machine_readable_report_path` 或 `human_readable_report_path` |
| CHECK-R4-012 | blocker | zip sha256 与实际 zip 不一致 |
| CHECK-R4-013 | warn | release report 未列 remediation_items，维护者不知道怎么修 |

### CHECK-FD 最终交付构建

| ID | 等级 | 检查方式 |
|---|---|---|
| CHECK-FD-001 | warn | `html_builder_mode=agent_handcrafted_html` 时，本轮不能作为 skill L3 独立样本 |
| CHECK-FD-002 | blocker | 用户要求转交时，不能只给 project_local HTML，必须生成 portable_bundle 或 standalone_html |
| CHECK-FD-003 | blocker | portable_bundle 内 HTML 不得链接回原 session 目录 |
| CHECK-FD-004 | warn | export-manifest.json、manifest-sha256.txt、sources/ 和 assets/ 缺失时，测试包不能说完整 |

---

## 8. 人类引导

报告完成后，必须给人话导航。

通过时：

```text
只读检查通过。这只说明当前检查范围内没有发现 blocker，不代表完整真实测试或 GitHub 发布完成。下一步建议进入 {next_action}。
```

带警告时：

```text
只读检查通过但有警告。它不阻断继续推进，但不能拿来宣称 L3 或完整真实测试通过。我建议先处理 {top_warning}，然后再进入 {next_action}。
```

失败时：

```text
这次不能进入下一阶段，因为命中了 blocker：{blocking_items}。建议先修 {recommended_fix}，修完再重新跑只读检查。
```

阻断时：

```text
这次检查没有跑完，因为缺少必要输入：{missing_inputs}。先补齐这些输入，再重新检查。
```

---

## 9. 编译后边界

当前 checker 成熟度：

```text
checker_maturity: L2
reason: 已有产品定义、执行规范和报告模板；但尚未脚本化，尚未对真实 session / sample 跑出正式 workflow_check_report。
```

不能宣称：

```text
validator 已实现。
CI 已接入。
L3 已达成。
完整真实测试通过。
public_release 已通过。
GitHub 已发布。
```


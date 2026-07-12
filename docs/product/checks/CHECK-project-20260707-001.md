# Workflow Check Report

```yaml
workflow_check_report:
  check_id: CHECK-project-20260707-001
  checked_at: 2026-07-07
  check_scope: project
  target_path: <PROJECT_ROOT>
  checker_version: r1-r4-readonly-checker-v0.1
  readonly: true
  overall_result: pass_with_warnings
  maturity_observed: l2_8
  blocking_count: 0
  warning_count: 4
  info_count: 5
  next_action: review_warnings_then_continue_to_r3_generated_or_r4_public_release_candidate
```

## Summary

```text
检查范围：project-scope，只检查项目级入口、状态、索引、checker 编译闭合和开源边界声明。
目标路径：`<PROJECT_ROOT>`（历史检查时由本地执行环境解析）。
结论：pass_with_warnings。
成熟度观察：项目仍维持 L2.8；本报告不把项目提升为 L3。
边界说明：本次只读检查没有检查真实 session、没有检查 generated 图片路径、没有生成 public_release、没有接 CI。
```

## Checks

| check_item_id | group | severity | status | evidence | recommendation | backwrite_target |
|---|---|---|---|---|---|---|
| CHECK-GOV-001 | governance | blocker | pass | `STATUS.md`、`工作流状态记录.md`、路线图均指向 checker 已编译并静态检查，下一步为 project-scope dry-run / 后续验证。 | 无需返修。 | 无 |
| CHECK-GOV-002 | governance | warn | pass | README / PROJECT_MAP 已索引 `R1-R4只读checker执行规范.md`、`workflow-check-report.template.md` 和产品定义。 | 无需返修。 | 无 |
| CHECK-GOV-003 | governance | warn | pass | 本报告路径将由 STATUS、工作流状态记录和路线图回指；新增 checker reference / template 已有入口。 | 后续若报告增多，可补 `docs/product/checks/README.md`。 | docs/reference/文档治理与目录规范.md |
| CHECK-GOV-004 | governance | blocker | pass | 当前状态明确写有“不代表完整真实测试通过、不生成 public_release、不推 GitHub、不能宣称开源发布完成”。 | 继续保持该边界。 | 无 |
| CHECK-GOV-005 | governance | blocker | pass | 未发现本轮 checker 编译越界到客户端、服务器、数据库、license、积分或平台发布链路。 | 无需返修。 | 无 |
| CHECK-R1-001 | r1_content_chain | blocker | not_applicable | project-scope 不检查单条真实 session manifest。 | session-scope checker 时再检查。 | 无 |
| CHECK-R1-002 | r1_content_chain | blocker | not_applicable | project-scope 不检查单条 session execution_trace。 | session-scope checker 时再检查。 | 无 |
| CHECK-R1-003 | r1_content_chain | blocker | not_applicable | project-scope 不检查 session current_artifact。 | session-scope checker 时再检查。 | 无 |
| CHECK-R1-004 | r1_content_chain | blocker | not_applicable | project-scope 不检查单条内容的 research_run_id 贯穿。 | session-scope checker 时再检查。 | 无 |
| CHECK-R1-005 | r1_content_chain | blocker | not_applicable | project-scope 不验证真实自动推进样本。 | 后续用 session 或 sample scope 验证。 | 无 |
| CHECK-R1-006 | r1_content_chain | blocker | not_applicable | project-scope 不检查真实人类门禁路径。 | 后续用 session 或 sample scope 验证。 | 无 |
| CHECK-R1-007 | r1_content_chain | blocker | not_applicable | project-scope 不检查真实 final-delivery.html。 | 后续用 session 或 sample scope 验证。 | 无 |
| CHECK-R1-008 | r1_content_chain | warn | not_applicable | project-scope 不计算单条 session agent_assist_level。 | 后续用 session 或 sample scope 验证。 | 无 |
| CHECK-R2-001 | r2_runtime | blocker | not_applicable | project-scope 不检查真实多选 fan-out。 | 后续用 sample / session scope 验证。 | 无 |
| CHECK-R2-002 | r2_runtime | blocker | not_applicable | project-scope 不检查 parent / child 实体目录。 | 后续用 sample / session scope 验证。 | 无 |
| CHECK-R2-003 | r2_runtime | warn | pass | STATUS 与路线图均未宣称脚本级断点续跑，仍标注 R2 checkpoint / resume 后续边界。 | 无需返修。 | 无 |
| CHECK-R2-004 | r2_runtime | warn | not_applicable | project-scope 不检查具体 run_lock、state_transition、resume_report。 | 后续用 sample / session scope 验证。 | 无 |
| CHECK-R2-005 | r2_runtime | blocker | pass | 当前产品开发 / checker 任务未启动真实内容 fan-out。 | 无需返修。 | 无 |
| CHECK-R3-001 | r3_assets | blocker | not_applicable | project-scope 不检查真实 required_visuals。 | 后续 R3 generated 样本检查。 | 无 |
| CHECK-R3-002 | r3_assets | blocker | not_applicable | project-scope 不检查单张图片 retention_task。 | 后续 R3 generated 样本检查。 | 无 |
| CHECK-R3-003 | r3_assets | blocker | not_applicable | project-scope 不检查真实 prompt_card 完整度。 | 后续 R3 generated 样本检查。 | 无 |
| CHECK-R3-004 | r3_assets | blocker | not_applicable | project-scope 不检查 generated 图片文件。 | 后续 R3 generated 样本检查。 | 无 |
| CHECK-R3-005 | r3_assets | blocker | not_applicable | project-scope 不检查 generated 图片 metadata sidecar。 | 后续 R3 generated 样本检查。 | 无 |
| CHECK-R3-006 | r3_assets | blocker | not_applicable | project-scope 不检查 HTML 中图片状态展示。 | 后续 R3 generated / sample-scope 检查。 | 无 |
| CHECK-R3-007 | r3_assets | warn | fail | STATUS 与路线图明确 pending_external 已验证，但 generated 图片路径仍未验证。该 warning 不阻断 checker dry-run，但阻止 L3 宣称。 | 下一步优先做 R3 generated 图片路径样本。 | docs/reference/R3-图片资产执行规范.md |
| CHECK-R3-008 | r3_assets | warn | not_applicable | project-scope 不检查具体 HTML 的占位、prompt 和追溯链接。 | 后续 sample / session scope 验证。 | 无 |
| CHECK-R4-001 | r4_release | blocker | pass | 根目录 `LICENSE` 不存在，STATUS 明确写“不选择最终 License、不推 GitHub、不能宣称开源发布完成”。 | 进入 public_release candidate 前先确认 License。 | docs/reference/GitHub开源上线检查清单.md |
| CHECK-R4-002 | r4_release | blocker | pass | 根目录 `public_release/` 不存在，STATUS 明确写“不生成真实 public_release”。 | 进入 R4 candidate 时再生成并检查。 | docs/reference/GitHub开源上线检查清单.md |
| CHECK-R4-003 | r4_release | blocker | not_applicable | 未生成 public_release，当前无公开候选包可扫。 | public_release candidate 生成后再检查。 | 无 |
| CHECK-R4-004 | r4_release | blocker | not_applicable | 未生成 public_release，当前不检查公开入口本机路径净化。 | public_release candidate 生成后再检查。 | 无 |
| CHECK-R4-005 | r4_release | warn | fail | 当前 sample / 状态明确 pending_external 路径已验证，generated 图片路径未验证。 | public sample 中必须继续声明 generated_image_path_verified=false，直到 R3 generated 样本通过。 | templates/public-release/public-manifest.template.yaml |
| CHECK-R4-006 | r4_release | warn | fail | R4 release-checklist 模板已存在，但真实 public_release candidate 尚未生成，尚未产生真实 release-checklist 结果。 | 进入 R4 candidate 时生成并运行 release-checklist。 | templates/public-release/release-checklist.template.md |
| CHECK-CHK-001 | checker_runtime | warn | fail | checker 已有产品定义、执行规范和报告模板，但尚未脚本化，也未接 CI。 | 维持“只读 checker / 人工或 AI 执行”口径，不宣称 validator 已实现。 | docs/reference/R1-R4只读checker执行规范.md |
| CHECK-CHK-002 | checker_runtime | info | pass | 本报告是第一份正式 project-scope `workflow_check_report` 样本。 | 后续可补 session-scope 与 sample-scope 报告。 | docs/product/checks/ |

## Blocking Issues

```text
无。
```

## Warnings

```text
1. R3 generated 图片路径仍未验证，pending_external 通过不能等于 generated 通过。
2. public_release candidate 尚未生成，真实 release-checklist 未运行。
3. checker 尚未脚本化，也未接 CI，不能宣称 validator 已实现。
4. 本次只检查 project scope，未覆盖真实 session / sample scope。
```

## Info

```text
1. README / PROJECT_MAP 已索引 checker 产品定义、执行规范和报告模板。
2. STATUS、工作流状态记录、路线图均保留“不宣称 L3 / 不宣称完整真实测试通过 / 不宣称 GitHub 发布完成”的边界。
3. 根目录未发现 public_release/，符合当前未生成候选包的状态。
4. 根目录未发现 LICENSE，符合当前 License 未确认的状态。
5. 本报告只允许作为 checker dry-run 样本，不代表完整真实测试通过。
```

## Human Prompt

```text
project-scope 只读检查已经跑出第一份报告，结论是 pass_with_warnings：没有 blocker，但还有 4 个不能忽略的 warning。比较稳的下一步是先用这份报告反查 checker 规范是否需要微调；如果不返修，就进入 R3 generated 图片路径样本，因为它是当前最影响 L3 候选和开源样例诚实性的缺口。
```

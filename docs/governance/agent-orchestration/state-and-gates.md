# State And Gates

> 状态：状态接续和门禁编排规则
> 主责：定义 agent 执行任务时如何读取状态、写回状态、处理 checkpoint、执行检查和收口。
> 边界：本文件不定义具体字段 schema；字段真源仍是 `交接物字段词典.md` 和各 skill contract。

---

## 状态读取顺序

```text
1. AGENTS.md
2. PROJECT_MAP.md
3. 工作流状态记录.md
4. 当前 task_type 对应 required reads
5. manifest.yaml / checkpoint / execution trace
```

如果 `工作流状态记录.md` 与账号/session 具体 manifest 冲突：

```text
以账号/session 具体 manifest 为准。
修正汇总状态记录。
记录冲突原因。
```

## 状态写回原则

每次小循环完成后至少写回：

```text
current_stage
current_artifact
session_status
field_gate_status
next_action
after_completion_status
recommended_user_replies
blocking_reason
```

真实内容产物写入：

```text
accounts/{account_slug}/runs/{session_id}/
```

公开样例写入：

```text
examples/
docs/tutorials/
```

发版产物写入：

```text
releases/v{version}/
```

## 门禁类型

| gate | 何时触发 | 通过条件 | 不通过 | 验证脚本 |
|---|---|---|---|---|
| `human_account_confirm` | 换账号 / 新建账号 | 用户认可账号摘要 | 回到 account onboarding | 人工判断 |
| `human_topic_select` | 生成 3 个候选选题后 | 用户选一个，或明确全做进入 R2 | 不进入 Brief | 人工判断 |
| `field_gate` | 产品定义、skill 编译、公开包同步 | 字段词典 / contract / skill / checker 同源 | 先修字段 | `tools/validate-field-schema.ps1` |
| `contract_data_flow_gate` | Skill / CONTRACT 编译和主链修订 | 每个新增对象有 producer、consumer、ID、状态、物理路径、next_skill、条件必填和恢复路由；脱敏 sample 能贯穿到最终交付 | 回到字段 / CONTRACT / sample 修订 | 对应专项 checker；R3 使用 `tools/validate-r3-visual-text.ps1` |
| `product_contract_compilation_gate` | 产品规则含数量、默认值、条件、成本、调用数或派生状态；或已编译合同被新确认产品定义取代 | 产品文档、字段词典、Skill / CONTRACT、机器 Schema / runtime、正反 fixture、专项 checker 六层同源；fixture 常量与通用规则分离；被取代的旧 sink 全部标记 `superseded_pending_recompile`，旧 checker pass 只算历史兼容 | 回到合同编译，不允许用 prose、magic number 或旧 checker pass 冒充新实现；重编译前阻断依赖旧合同的真实外部回归 | C71-C80：`validate-r3-visual-need.ps1`；C81-C90：`validate-p0-h6-reliability.ps1`；旧 visual-budget 只验证历史兼容 |
| `runtime_smoke_gate` | 新增 / 修改 PowerShell 命令、deterministic renderer、overlay 或 runtime | 全量 parser 无错误；新入口实际 self-test；相关代表性 fixture 实际运行且退出码 / 关键产物正确 | 不得以 parser pass 代替运行验证；回到命令、fixture 或 checker 修复 | `tools/validate-gates.ps1 -GateName runtime_smoke_gate` |
| `environment_compatibility_gate` | PowerShell、外部进程、路径、压缩包、构建器、安装或公开包发生变化 | 适用的 5.1/7、短路径、空格中文路径、超预算路径、source/zip clean-room 轴有逐项证据；共享 writer / process helper 与隐藏依赖检查通过；未覆盖轴标记 not_tested / not_certified | 不得以当前机器短路径 pass 宣称 Windows 兼容；回到环境合同或 fixture | `tools/validate-windows-runtime-helper.ps1` + 分阶段 environment compatibility suite |
| `process_argument_gate` | `Start-Process`、native command、子 PowerShell 或参数 wrapper 变化 | 含空格、中文、引号、空参数的 argv fixture 保真；5.1/7 分宿主验证 | 归因为 checker / process invocation defect，不判 workflow 业务失败 | 专项 argv fixture |
| `archive_integrity_gate` | build / export / Compress-Archive / tar / Expand-Archive / Release asset | exit code、archive manifest、required files、count、SHA256、解压后代表 checker 同时通过 | `archive_integrity_error` 阻断包交付 / 发版 | archive manifest + clean-room verify |
| `environment_safety_gate` | 测试需要 execution policy、MOTW、long path、Git 或模块条件 | 只读检测；不改注册表、Group Policy、全局 execution policy、用户全局 Git；无模块 / NoProfile 路径可诊断 | 停止环境改写，恢复原值并重新按 clean-room 执行 | 环境报告人工复核 |
| `path_preflight_gate` | 构建、打包、导出或新写入入口接受 root / target / relative path | Windows 保留名、root containment、reparse point、90 字符安装根建议、259 classic target budget、cwd 独立、同卷 temp write / rename / cleanup 与可用空间全部有机器结果；Git top-level 必须等于 ProjectRoot 才使用 index | 在任何清空 / 复制 / 深层目录创建前阻断，保留旧候选；不得让用户靠换目录试错 | `tools/invoke-environment-doctor.ps1` + `tools/validate-environment-preflight.ps1` |
| `document_graph_gate` | 新增、移动、重命名文档；文档 / 目录治理 | 分区 README 完整覆盖直属知识文档；根入口只维护最短路径；相对链接与 AI nav anchor 可解析；当前范围无过期状态 | 修所属分区索引、链接、导航或状态，不得靠根 README / PROJECT_MAP 重复堆全量清单 | `tools/validate-doc-governance.ps1` |
| `validator_target_gate` | replay / sample checker 接受目录参数 | 目标目录包含工具声明的 manifest、trace、expected artifacts 或 fixture | 修正调用路径，记录 checker_invocation_error，不判 workflow fail | 工具调用前 preflight |
| `state_consistency_gate` | 继续 / 断点续跑 | `latest_main_commit_known` 是当前 HEAD 或其祖先，且状态索引存在 | 修正状态记录或处理分叉 | `tools/validate-gates.ps1 -GateName state_consistency_gate` |
| `branch_lock_gate` | 多选题 / 多分支 | parent / child / checkpoint 清楚 | 封锁旁支任务 | `tools/validate-gates.ps1 -GateName branch_lock_gate` |
| `sample_only_gate` | 测试 / dry-run | 只读取 examples/，不访问真实 accounts/ | 阻断测试 | `tools/validate-gates.ps1 -GateName sample_only_gate` |
| `public_privacy_gate` | public build / GitHub release | 隐私扫描、source zip、release zip 均过 | 阻断发布 | `tools/validate-gates.ps1 -GateName public_privacy_gate` |
| `image_capability_gate` | 画中画生成 | Codex 可出图则生成；否则提示词降级 | 记录 provider_state | 运行时检测 |
| `remote_release_gate` | push / tag / Release | GitHub 页面、assets、Actions、hash 均过 | 回到 release 修复 | `tools/validate-release-gate.ps1` |
| `local_commit_gate` | 原子开发完成后的本地 commit | 产品已确认、相关检查通过、本轮源码可安全隔离，且用户未说“只改不提交” | 保留本地改动并报告未提交原因 | diff / stage scope 人工复核 |
| `git_publish_gate` | push / tag / Release / repo metadata | 用户明确要求推送、发版、发布、同步 GitHub、创建 tag 或更新 Release | 停在本地 commit 和检查结果，不执行远端动作 | 人工判断 |
| `final_delivery_regression_gate` | 用户指出最终交付物浅显 BUG / 交付页字段缺失 / 展示误导 | 同时检查方法论、字段词典、skill 合同、模板、实际 HTML 和源 Markdown | 回到对应上游 skill 修订，并重建最终 HTML | `tools/validate-field-schema.ps1` + `tools/validate-gates.ps1` |

## Git 写入边界

默认允许：

```text
本地文件修改
本地检查
git status / diff / log / show / ls-files 等只读检查
```

满足 `local_commit_gate` 后默认允许：

```text
git commit
```

默认禁止，除非用户明确要求对应远端动作：

```text
git push
创建 / 删除 / 移动 tag
修改 GitHub Release
上传 Release asset
修改 GitHub repo description / topics / settings
用 GitHub API 写入远端 main 或 workflow
```

产品定义、纯调研、只读审计和仅生成报告的本地 dry-run，完成后停在本地结果报告，不自动提交。产品定义已确认后的 skill / 代码开发，以及边界清楚的 checker、模板、路由或治理规则原子修订，通过检查后默认进入本地提交闭环，但不得自动推送。

## 本地提交闭环

任务满足 `local_commit_gate`，或用户明确说“提交”时，可以执行 `git commit`，但不得自动 `git push`。提交闭环必须包含：

```text
pre_commit_checks：运行与本次变更相关的本地检查。
stage_scope_check：只暂存应进入源码的文件，排除本地真实账号、索引、support logs、releases、offline tester 包、外部资料缓存和 state/checks 报告。
commit_created：创建本地 commit。
post_commit_sweep：执行 git status --short --branch 和 git status --ignored --short。
local_cleanliness_result：说明工作区是否干净；如只剩 ignored 私有 / 缓存 / 发版证据目录，视为本地小扫地通过。
remote_write_status：未推送，除非用户另行明确授权。
```

如果提交后发现未暂存源码改动，不能直接说完成；必须说明剩余文件和建议动作。

测试工具若重写 tracked golden report，提交前必须区分：

```text
expected_behavior_changed：步骤、字段、断言或结果语义变化，报告可以随源码更新。
dynamic_metadata_only：只有 timestamp、run_id、绝对路径或机器信息变化，消除噪声后再提交。
unexpected_test_side_effect：工具改写了不属于本轮的样例，先恢复并登记 checker 缺陷。
```

路径型 checker 必须先通过 `validator_target_gate`。错误目录导致的 missing manifest / trace / expected artifacts 归为 `checker_invocation_error`，修正参数后复测；不得把第一次错误调用写成 workflow blocker。

如果提交前发现混合工作区，必须按以下顺序处理：

```text
1. 查看完整 diff 和 staged diff。
2. 只筛选本轮可证明归属的文件或补丁块。
3. 排除用户改动、其他轮次改动、真实账号数据、测试报告和生成缓存。
4. 能安全隔离则提交；不能安全隔离则停止提交，但保留已经完成的源码修改。
5. 写明 local_commit_status=blocked_by_mixed_worktree 和待拆分范围。
```

## 收口格式

最终回复必须说明：

```text
做了什么
产物在哪里
检查结果是什么
还有什么没做 / 不能做
用户下一步可以直接说什么
```

不得用“应该可以”“大概没问题”替代实际检查结果。

## 测试结果收口

测试、dry-run、regression、checker 审计结束时，必须把结果分层记录，不能只写“已测试”。

```text
overall_result：pass / pass_with_warnings / fail / blocked / tool_error
workflow_result：pass / pass_with_warnings / fail / not_tested
sample_result：pass / pass_with_warnings / fail / not_tested
checker_result：pass / pass_with_warnings / fail / tool_error
environment_result：pass / pass_with_warnings / fail / not_tested
not_tested_scope：真实内容大循环 / 真实图片生成 / 外部 API / 发版 / GitHub 发布等
```

问题归因必须按以下类型写入状态或测试摘要：

```text
workflow_defect：workflow / skill / contract 逻辑缺陷。
sample_fixture_defect：sample、manifest、expected-artifacts、execution_trace 未同步或证据不足。
checker_defect：脚本解析、判断、路径、退出码或报告语义错误。
environment_defect：profile、权限、依赖、路径、网络或外部服务问题。
documentation_gap：规则存在但文档没有写清楚。
not_tested：本轮明确没有执行的范围。
```

`pass_with_warnings` 的收口必须说明 warning 是否阻断下一步：

```text
blocking_warning：必须先修，不能进入下一阶段。
non_blocking_warning：可进入下一阶段，但要记录技术债。
known_scope_warning：本轮不测的范围，不能冒充已验证。
```

如果测试中修了 checker / tool，必须单独写：

```text
fixed_during_test：
tool_name：
issue：
impact_before_fix：
verification_after_fix：
```

测试报告应落到对应样例、state/checks 或 releases/v{version}/ 下；不得新建根目录散落报告。

## 任务后导航

每次任务结束后，必须根据 `routes/workflow-routes.yaml` 的 `after_completion` 字段判断收口方式：

```text
on_success：任务完成，给结果、产物、检查结果和推荐下一步。
on_waiting_human：需要人判断，说明为什么停下，并给 2-5 个可直接回复的话。
on_blocked：被门禁阻断，说明阻断原因、恢复路线和日志 / 报告位置。
auto_continue_allowed：为 true 且无门禁时，自动进入下一步，不要求用户回复“继续”。
```

如果 route 没有声明 `after_completion`，必须按 `docs/governance/agent-orchestration/after-task-guidance.md` 的通用规则收口，并把缺失记录为编排债务。

## 最终交付物缺陷回归

当用户指出“交付物里有明显 BUG”“HTML 不好读”“字段没展示”“最终物料理解错了”时，不得只改当前 HTML。必须按以下顺序检查：

```text
1. 实际 final-delivery.html 是否确实有问题。
2. 对应 deliverables/*.md 是否也有同类问题。
3. intermediate 上游交接物是否已经丢字段。
4. 交接物字段词典是否有标准字段。
5. 对应 skill CONTRACT / SKILL 是否强制输出。
6. final-delivery 模板是否强制展示。
7. 是否需要新增或修订方法论文档。
8. 修完后重跑该 session 的对应上游链路，并重新检查 HTML 链接和字段展示。
```

如果缺陷来自“字段有但最终展示没吃干净”，必须记录为：

```text
issue_type = compiled_delivery_mapping_bug
revision_path = back_to_{upstream_skill}
required_backwrite = field_dictionary / contract / skill / template / actual_delivery
```

同一 session 的版本化返工可以追加同一种 deterministic operation，但 step 选择必须遵循：先选依赖满足且尚未成功的 pending revision；不存在 pending 时，才以最后一条 completed revision 作为当前事实。不得因为历史首条 compile / render 已成功，就跳过后续候选数据、追溯 hash 或最终 HTML 修订。

任何 materialized trace artifact 被修改后，candidate / render input 内的 `sha256` 必须在下一次 compile 前重算。digest mismatch 应归因为 lineage binding defect 并阻断编译；不能把旧 hash 静默保留，也不能关闭完整性检查。

运行状态写入遵循单调性：prepare 只能把新 session 推到 waiting compile；finalize 只能在 checker、projection、resume、receipt 和最终 HTML digest 闭合后写 completed。completed session 再次 prepare 必须 `skipped_completed`，不得降回 running。checker 只写 report，不承担状态迁移。

外部图片调用与调用后的本地复制 / 合成属于两个阶段。provider 返回后必须先记录 `generation_attempt_id / provider_outcome_status / output reference`；后处理被中断时写 `postprocess_status=interrupted` 并先 reconcile 已存在输出。只有确认 provider 未成功或明确允许新 attempt 时才能重调，避免中断导致重复图片调用。

真实回归报告可以冻结“本次观察到 8+3”用于审计，但通用脚本必须使用 `derived_visual_count / accepted_task_count / selected_asset_count / derived_cover_count` 计算期望值。固定数量 fixture 必须显式标记 `cardinality_mode=baseline_fixed_regression`。

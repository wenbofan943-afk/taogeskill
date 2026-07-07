# R2 Dry-run Results

> dry_run_id：R2DRY20260707-001  
> contract_set_version：r2-runtime-v0.1  
> sample_root：docs/tutorials/r2-dry-run-sample  
> result：pass_with_warnings  
> warning：本样本是静态样本，不证明自动 runner、validator 或完整真实测试通过。

---

## 1. 场景结果

| 编号 | 场景 | 样本证据 | 结果 |
|---|---|---|---|
| R2DR-001 | 内容生产多选 | parent manifest + branch-request-ledger | pass |
| R2DR-002 | 产品开发旁支封锁 | dry-run 表内 `branch_request_deferred` 样例 | pass |
| R2DR-003 | child 独立性 | children/SR2DR-001..003/manifest.yaml | pass |
| R2DR-004 | child 阻断 | children/SR2DR-002/manifest.yaml | pass |
| R2DR-005 | fan-in 汇总 | parent/intermediate/branch-summary.md | pass |
| R2DR-006 | run_lock 冲突 | 本文件 §3 | pass |
| R2DR-007 | 断流恢复 | parent + child latest checkpoint | pass |
| R2DR-008 | checkpoint 缺失恢复 | 本文件 §4 | pass |
| R2DR-009 | 最终交付收口 | children/SR2DR-001 manifest + checkpoint | pass |
| R2DR-010 | parent 归档 | 本文件 §5 | pass |

---

## 2. R2DR-002 旁支封锁样例

```yaml
input:
  task_context_type: product_development
  user_reply: 三篇都做
expected:
  branch_request_status: branch_request_deferred
  blocked_reason: content_fan_out_not_allowed_in_product_development
  created_children: 0
  safe_next_action: ask_user_to_switch_to_content_production_or_continue_product_loop
```

解释：

```text
产品开发任务中不能直接启动内容生产 fan-out。
只能登记旁支请求，避免产品路线图和内容 session 互相污染。
```

---

## 3. R2DR-006 run_lock 冲突样例

```yaml
input:
  session_id: SR2DR-001
  current_run_lock: run_lock_acquired
  lock_owner: final-delivery-builder
  incoming_writer: propagation-router
expected:
  run_status: run_blocked
  blocked_reason: lock_conflict
  write_allowed: false
  resume_hint: wait_for_lock_release_or_create_resume_report
```

解释：

```text
run_lock 冲突时，不继续改正文、不覆盖 manifest。
只输出恢复建议。
```

---

## 4. R2DR-008 checkpoint 缺失恢复样例

```yaml
input:
  session_id: SR2DR-MISSING-CKPT
  manifest_exists: true
  latest_checkpoint_exists: false
expected:
  recovery_evidence_status: insufficient_checkpoint
  run_status: run_blocked
  blocked_reason: missing_checkpoint
  do_not_rerun:
    - completed_stage_from_manifest
  safe_to_rerun:
    - postcheck_only
```

解释：

```text
没有 checkpoint 时不能声称脚本级断点续跑。
只能基于 manifest 和 trace 做保守恢复。
```

---

## 5. R2DR-010 parent 归档样例

```yaml
input:
  parent_session_id: SR2DR-PARENT
  requested_action: archive_parent
  children:
    - session_id: SR2DR-001
      run_status: run_completed
    - session_id: SR2DR-002
      run_status: run_blocked
    - session_id: SR2DR-003
      run_status: run_planned
expected:
  human_interrupt_required: true
  allowed_decisions:
    - archive_parent_keep_children
    - archive_parent_archive_children
    - cancel_planned_children
  forbidden:
    - silently_archive_children
    - delete_child_artifacts
```

解释：

```text
parent 归档不等于 child 自动归档。
未启动 child 可以取消，已启动或已完成 child 必须保留或由用户明确处理。
```

---

## 6. 总结

```text
R2 dry-run 样本能覆盖关键运行模型。
当前仍是静态样本，不是完整真实测试。
下一步若继续增强，应补自动检查脚本或 validator 草案，但这属于后续 R 阶段，不在本样本实现。
```

# R1-R4 Trace Check Report

```yaml
trace_check_id: TC-SR1R4DR-001
session_id: SR1R4DR-001
contract_set_version: r1-r4-integrated-dry-run-v0.1
overall_result: pass_with_warnings
blocking_count: 0
warning_count: 3
r1_candidate_status: candidate_with_warnings
r2_candidate_status: sample_pass
r3_candidate_status: pending_external_pass_generated_unverified
r4_candidate_status: precheck_recorded_real_release_blocked
```

## 检查表

| check_id | result | severity | evidence | issue_record |
|---|---|---|---|---|
| R1CHK-001 | pass | BLOCKER | account/object inputs exist |  |
| R1CHK-004 | pass_with_scope | WARN | synthetic research_run exists | 使用 synthetic source，不验证真实热点调研 |
| R1CHK-006 | pass | BLOCKER | topic selected for brief |  |
| R1CHK-007 | pass | BLOCKER | draft exists |  |
| R1CHK-014 | pass_with_warnings | WARN | quality_review exists | 图片为 pending_external |
| R1CHK-018 | pass | BLOCKER | final-delivery.html exists |  |
| R2CHK-runtime | pass | BLOCKER | run_lock, state_transition, checkpoint exist |  |
| R3CHK-001..006 | pass | BLOCKER | visual_plan and generation_record exist |  |
| R3CHK-007 | not_applicable | INFO | no generated image in sample | generated 路径未验证 |
| R3CHK-008 | not_applicable | INFO | no generated image in sample | generated sidecar 未验证 |
| R3CHK-009 | pass | BLOCKER | HTML uses placeholder, not generated image |  |
| R3CHK-012 | pass | BLOCKER | html-embed-manifest.json exists |  |
| R4CHK-001..010 | pass_with_warnings | WARN | public-release-precheck.md | 真实 release 被 License / 社区健康文件 / 远端决策阻断 |

## 问题记录

| issue_id | type | severity | description | action_this_round |
|---|---|---|---|---|
| ISSUE-SR1R4DR-001 | unverified_path | warning | R3 generated 图片文件、checksum、真实 sidecar 未验证 | 只记录，不修 |
| ISSUE-SR1R4DR-002 | release_blocker | warning | R4 真实 public_release 缺 License、社区健康文件、远端仓库决策 | 只记录，不修 |
| ISSUE-SR1R4DR-003 | tooling_gap | warning | 当前检查是人工 / 半自动，不是脚本级 validator | 只记录，不修 |
| ISSUE-SR1R4DR-004 | scan_context | info | 敏感词扫描命中 `cookie`、`secret`、`token`、`车牌`，均处于禁止项说明语境，未发现真实密钥或真实个人信息 | 只记录，不修 |

## 静态检查记录

```yaml
required_file_missing_count: 0
final_delivery_html_broken_link_count: 0
sensitive_scan_hits:
  - cookie
  - secret
  - token
  - 车牌
sensitive_scan_context: prohibition_terms_only
```

## 结论

```text
综合 dry-run 样本闭合。
没有发现阻断样本继续存在的问题。
本轮按用户要求，只记录警告，不修规则。
```

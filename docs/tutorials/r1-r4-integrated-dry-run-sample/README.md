# R1-R4 Integrated Dry-run Sample

> 状态：sample_run_completed_with_warnings  
> 样本类型：脱敏、单题、最小闭环综合 dry-run  
> 边界：本样本不是正式内容，不代表完整真实测试通过，不生成真实 `public_release/`，不调用图片生成或外部 API。

---

## 1. 样本目的

本样本用于验证：

```text
R1 内容主链路
-> R2 checkpoint / state_transition / run_lock
-> R3 pending_external 图片资产链
-> R4 public_release precheck
```

是否能在一个脱敏单题样本中闭合。

---

## 2. 样本入口

| 类型 | 路径 |
|---|---|
| session manifest | `accounts/sample-account/runs/SR1R4DR-001/manifest.yaml` |
| execution trace | `accounts/sample-account/runs/SR1R4DR-001/intermediate/00-execution-trace.md` |
| trace check | `accounts/sample-account/runs/SR1R4DR-001/intermediate/trace-check-report.md` |
| 最终 HTML | `accounts/sample-account/runs/SR1R4DR-001/deliverables/final-delivery.html` |
| R4 预检查 | `accounts/sample-account/runs/SR1R4DR-001/public-release-precheck.md` |

---

## 3. 本轮结论

```yaml
sample_run_id: SR1R4DR-001
overall_result: pass_with_warnings
blocking_count: 0
warning_count: 3
image_assets_status: pending_external
release_status: blocked_for_real_release
```

警告项：

```text
1. R3 generated 图片路径未验证，本样本只验证 pending_external 诚实降级路径。
2. R4 真实 public_release 仍被 License、社区健康文件和远端仓库决策阻断。
3. 当前检查仍是人工 / 半自动检查，不是脚本级 validator。
```

静态检查记录：

```text
必需文件缺失：0
final-delivery.html 本地链接断链：0
敏感词扫描命中：cookie / secret / token / 车牌，均为禁止项说明语境，不是真实敏感数据。
```

---

## 4. 适用和不适用

适用：

```text
给维护者看 R1-R4 的合同是否能同跑。
给后续 validator / public_release 构建脚本提供样本形态。
给 AI 恢复任务时读取路径和状态。
```

不适用：

```text
不能作为真实账号内容。
不能作为 GitHub release candidate。
不能证明图片生成质量。
不能证明自动断点续跑 runner 已实现。
```

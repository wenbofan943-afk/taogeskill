# R2 Dry-run Sample

> 状态：sample_only  
> 用途：验证 R2 运行模型是否能被人和 AI 按样本理解。  
> 边界：本目录不是真实内容生产，不生成真实正文，不调用图片，不自动发布。

---

## 1. 样本目标

本样本覆盖 `docs/product/R2-运行模型与分支封锁规则.md` 中的 R2DR-001 到 R2DR-010。

它模拟一个 parent session 收到“三篇都做”的请求，然后拆成 3 个 child session：

| child | topic | dry-run 状态 | 目的 |
|---|---|---|---|
| `SR2DR-001` | `T-SAMPLE-001` | `run_completed` | 验证 child 完成、最终交付收口、checkpoint 和 run_lock 释放 |
| `SR2DR-002` | `T-SAMPLE-002` | `run_blocked` | 验证 topic_card 不完整时只阻断单个 child |
| `SR2DR-003` | `T-SAMPLE-003` | `run_planned` | 验证 parent 归档时不能静默处理未启动 child |

---

## 2. 文件结构

```text
docs/tutorials/r2-dry-run-sample/
├── README.md
├── dry-run-results.md
├── sample-manifest-template.yaml
├── parent/
│   ├── manifest.yaml
│   └── intermediate/
│       ├── 00-execution-trace.md
│       ├── branch-request-ledger.md
│       ├── branch-summary.md
│       └── checkpoints/
│           ├── CKPT-SR2DR-PARENT-fan-out-20260707-001.md
│           └── latest.md
└── children/
    ├── SR2DR-001/
    ├── SR2DR-002/
    └── SR2DR-003/
```

---

## 3. 读取顺序

AI 做 R2 dry-run 复核时，按以下顺序读：

```text
README.md
-> dry-run-results.md
-> parent/manifest.yaml
-> parent/intermediate/branch-request-ledger.md
-> parent/intermediate/checkpoints/latest.md
-> children/*/manifest.yaml
-> children/*/intermediate/checkpoints/latest.md
-> parent/intermediate/branch-summary.md
```

---

## 4. 通过标准

```text
parent 不保存 child 正文。
每个 child 有独立 manifest。
branch ledger 能解释状态变化。
checkpoint 能说明最后可信节点。
run_lock 冲突不会继续写入。
resume_report 能说明 do_not_rerun 和 safe_to_rerun。
final-delivery-builder 收口不只生成 HTML，还写 checkpoint、state_transition 和 run_lock。
```

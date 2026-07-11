# Examples

> 状态：template_index  
> 主责：承载未来公开包使用的脱敏样例。  
> 边界：本目录下的样例必须是 sample_only，不得包含真实账号、真实客户资料、真实生产 runs 或未授权素材。
> Alpha 候选提醒：这些样例是 sample_only 和 regression fixture，只证明入口、字段、交接物、回放和只读检查能闭合；不证明真实热点质量、真实图片质量、真实账号生产效果或自动发布能力。

---

## 样例层级

```text
examples/
├── sample-account/
├── sample-run/
├── sample-01-onboarding/
├── sample-02-single-content-run/
├── sample-03-final-review-revision/
├── p0-runtime-fixture/
├── p0-h1-contract-fixtures/
├── p0-runtime-v0.2-fixture/
├── p0-h3-recovery-fixtures/
├── p0-h4-evidence-fixture/
├── r3-visual-budget-fixtures/
└── regression-suite.yaml
```

当前目录是 R4 编译后的样例模板入口。  
正式生成 `public_release/` 前，应把现有 dry-run 教程中适合公开的内容整理到这里，并按 `docs/reference/GitHub开源上线检查清单.md` 检查。

## 先看哪个

| 你是谁 | 先看 | 为什么 |
|---|---|---|
| 第一次下载，只想知道怎么开始 | `sample-01-onboarding` | 它验证没有账号时，workflow 会引导新建账号，而不是让你填字段表 |
| 想看主链路是否自动到底 | `sample-02-single-content-run` | 它验证选题确认后，Brief、文案、画中画、质检、平台包和最终 HTML 会自动衔接 |
| 想看最终 HTML 后能不能返工 | `sample-03-final-review-revision` | 它验证只改标题、追加画中画、重建 HTML，不重跑热点 |
| 想看机器可读业务计划和确定性运行边界 | `p0-runtime-fixture` | 它展示完整单篇 plan、append-only event、lineage、幂等渲染和 legacy replay 边界 |
| 想看 P0 v0.2 合同与错误场景 | `p0-h1-contract-fixtures` | 它用正反样例验证版本钉住、事件顺序、幂等冲突、重试边界、资产检查和统一卡片输入 |
| 想看统一卡片怎样真实生成交付页 | `p0-runtime-v0.2-fixture` | 它执行 typed input compiler、readiness derivation、确定性 HTML renderer 和 render receipt，不调用真实图片或外部 API |
| 想看失败后停在哪里、怎么恢复 | `p0-h3-recovery-fixtures` | 它用 F03-F19 独立样例验证等待、失败、幂等、恢复、取消和兼容边界，不调用真实外部能力 |
| 想看过程证据怎样登记和恢复 | `p0-h4-evidence-fixture` | 它真实执行五个 evidence commands、统一 writer、投影重建和孤儿产物对账，外部结果仅登记不调用 |
| 想看一篇内容到底该计划 / 生成几张图 | `r3-visual-budget-fixtures` | 它验证时长预算包络、required / optional 实际任务数、完整 prompt、封面分账和 provider 调用数 |

三个 P4 教学样例都必须带：

```text
input-prompt.md
expected-agent-behavior.md
expected-artifacts.md
manifest.yaml
execution-trace.md
check-report.md
sample-check-report.json
```

样例默认不代表完整真实生产测试通过，只代表该路径有可读、可追溯的验收材料。

## 验证命令

```powershell
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-01-onboarding
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-02-single-content-run
.\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-03-final-review-revision
.\tools\validate-regression-suite.ps1 -SuitePath .\examples\regression-suite.yaml
.\tools\invoke-workflow-runtime.ps1 -Session .\examples\p0-runtime-fixture -Mode validate
.\tools\validate-p0-h1-contracts.ps1
.\tools\validate-p0-h2-runtime.ps1
.\tools\validate-p0-h3-fixtures.ps1
.\tools\validate-p0-h4-evidence.ps1
.\tools\validate-r3-visual-budget.ps1
```

`regression-suite.yaml` 会把三份 sample 串成一组只读回归 fixture：先跑样例结构检查，再跑 trace replay。它允许当前 alpha 阶段的声明型 warning，但不允许 blocker 或未登记 warning。

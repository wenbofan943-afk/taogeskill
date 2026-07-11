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
.\tools\invoke-workflow-runtime.ps1 -SessionPath .\examples\p0-runtime-fixture -Mode validate
```

`regression-suite.yaml` 会把三份 sample 串成一组只读回归 fixture：先跑样例结构检查，再跑 trace replay。它允许当前 alpha 阶段的声明型 warning，但不允许 blocker 或未登记 warning。

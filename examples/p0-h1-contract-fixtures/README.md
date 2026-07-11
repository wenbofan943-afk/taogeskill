# P0-H1 Contract Fixtures

这组脱敏 fixture 验证 P0-H1 的机器合同，不执行内容生产、图片生成、联网或发布。

覆盖：

```text
v0.2 workflow / contract / schema / renderer / template 版本钉住。
single runtime 的 plan 和 retry policy。
event envelope、严格 sequence、previous_event、幂等冲突与隐私字段边界。
artifact materialization / quality / delivery eligibility 三轴。
artifact check 的 pass / fail / not_run 证据语义。
typed_components_v0.2 与 html_fragments_v0.1 互斥。
v0.1 legacy replay 与 v0.2 native resume 的 compatibility matrix。
```

验证：

```powershell
.\tools\validate-p0-h1-contracts.ps1
```

动态报告写入 `state/checks/`，不改 tracked fixture。现有 `examples/p0-runtime-fixture/` 继续作为 v0.1 legacy runtime fixture；实际 renderer 迁移属于 P0-H2，不在 H1 提前执行。

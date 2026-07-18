# M6 Runtime Conformance Fixtures

> 状态：`compiled_not_certified`
> 边界：本目录把既有 M2/M3/M4 脱敏回归映射为 runtime conformance
> known-answer；不读取真实账号、不联网、不调用 provider，也不替代真实 route 认证。

六类命令覆盖：

```text
start      -> current direct / hotspot session generation binding
advance    -> direct positive artifact / event progression
wait       -> final human wait and hotspot external waits
resume     -> committed binding plus hotspot research/topic/freshness resume
rebuild    -> byte-stable projection rebuild and tamper rejection
reconcile  -> persisted attempt/outcome reuse, zero blind retry and idempotent replay
```

运行：

```powershell
.\tools\validate-m6-runtime-conformance.ps1 -Mode CompileSmoke
```

`CompileSmoke` 只证明 suite 可执行。正式 `Certification` 还要求 clean HEAD、
完整 source revision，以及同一 freeze digest 上已经 `certified` 的 evaluator 报告。

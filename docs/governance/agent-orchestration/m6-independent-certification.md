# M6 Independent Certification

> 状态：`runtime_conformance_suite_compiled_not_certified`
> 架构决定：`ARCH-20260718-002`
> 边界：本文件定义认证对象、顺序和证据，不把编译 smoke 误报为认证结果。

## 认证顺序

```text
freeze product / architecture / runtime / evaluator / fixture
-> evaluator conformance
-> runtime conformance
-> direct same-digest certification
-> hotspot same-digest certification
```

认证不能在运行中修改 subject、evaluator 或 fixture。任一冻结文件变化都使
当前 certification run 失效，必须创建新的 freeze 和 run id。

## 冻结对象

机器真源是 `routes/m6-certification-contract.json`。冻结 producer 对其中五类
显式文件逐个记录路径、长度和 SHA256，再生成分类摘要与总摘要：

```text
product_contract
architecture_decision
runtime_build
evaluator_build
fixture_catalog
```

冻结产物只写入 `state/checks/m6/{certification_run_id}/`，不进入公开源码。

## Evaluator conformance

M6 evaluator suite 必须独立验证：

```text
object / array / scalar topology
invalid / non-comparable disposition
rejection fail-closed
blind allocation mapping
known-answer finalizer
false-success mutations
freeze digest before / after stability
```

旧 H5 业务 A/B 结果不是 evaluator 认证。`compile_smoke` 只证明 suite、fixture
和 runtime 能执行；只有 clean commit、明确 source revision 和完整冻结摘要
下的 `certification` 模式才允许写 `certified`。

上一轮 evaluator 已在 clean HEAD `30be209…` 上通过，但 runtime conformance
suite 的接入改变了 architecture、evaluator 和 fixture 冻结集合。该证书作为
历史证据保留，不能直接授权新 suite；正式 runtime certification 前必须在
新 clean HEAD 上重跑 evaluator，并逐字匹配 source revision 与 freeze digest。

## Runtime 与真实 route

Evaluator 认证通过后，M6 才编译并运行 runtime conformance：

```text
start / advance / wait / resume / rebuild / reconcile
```

`M6-RUNTIME-CONFORMANCE-0.1` 使用独立 work root，统一消费 M4 session entry、
M2 direct shadow 与 M3 hotspot shadow 的机器报告。20 个 known-answer 断言
覆盖六类命令，4 个负例覆盖 freeze 篡改、source revision 错配、底层报告变异
和 evaluator digest 错配。

正式认证必须同时满足：

```text
clean tracked worktree
source revision == HEAD
evaluator report == certified
evaluator source revision == runtime source revision
evaluator freeze digest == runtime freeze digest
runtime freeze before == runtime freeze after
```

认证范围只包括 current session 代际入口、direct 正向推进/最终等待/重建，
以及 hotspot wait/resume/reconcile/replan。真实账号、语义质量、网络、
provider 和 direct/hotspot 真实 route 同摘要认证仍不在本阶段。

最后 direct 与 hotspot 必须绑定同一 freeze digest。Codex 手工修改 event、
projection、manifest、artifact 或状态会让该样本降级为 `assisted`，不能作为
L3 证据。真实账号、联网和 provider 调用仍按各自 route 单次授权。

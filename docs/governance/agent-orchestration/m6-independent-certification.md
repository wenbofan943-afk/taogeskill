# M6 Independent Certification

> 状态：`direct_certification_surface_compiled_not_certified`
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

Evaluator 与 runtime conformance 曾在 clean HEAD `9abcac0…` 上以同一摘要
通过；direct certification surface 的接入再次改变了 architecture、runtime、
evaluator 和 fixture 冻结集合。旧证书作为历史证据保留，不能直接授权新 suite；
正式 direct certification 前必须在新 clean HEAD 上依次重跑 evaluator、
runtime 和 direct，并逐字匹配 source revision 与 freeze digest。

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

## Direct same-digest certification

用户于 2026-07-18 明确授权补齐 direct route certification surface。架构确认项
`M6-DIRECT-C01` 至 `M6-DIRECT-C12` 为：

```text
C01 认证对象是 kernel_v1_current 的 direct 控制面，不是 M2 shadow。
C02 先通过真实 session entry 写入 v0.2 binding 和 SHA256 commit marker。
C03 direct route 的 25 个组件槽位必须逐项匹配 current IR 和 component catalog。
C04 semantic worker、external activity 和 human gate 的业务内容由确定性 test adapter 提供。
C05 test adapter 不得被表述为真实 Skill、provider 或真实人工动作。
C06 coordinator 独占 event、artifact、projection 和 run-state 写入。
C07 第一次推进必须停在 final_human_decision_gate 的 waiting_human。
C08 typed fixture decision 续跑后才允许完成 final_decision。
C09 projection rebuild 必须从不可变 event/artifact 得到 byte-stable 结果。
C10 completed replay 不得增加 event 或重写 artifact。
C11 未登记文件写入、binding/event 篡改和前置摘要错配必须 fail-closed。
C12 网络、provider、私有账号、语义质量、真实人工决定、hotspot 和项目 L3 均不在认证范围。
```

机器面固定为：

```text
producer:
  tools/M6DirectCertificationRuntime.ps1
request:
  templates/schema/m6/direct-certification-request.v0.1.schema.json
fixture:
  examples/m6-direct-certification-fixtures/catalog.json
validator:
  tools/validate-m6-direct-certification.ps1
report:
  templates/schema/m6/direct-certification-report.v0.1.schema.json
physical_output:
  state/checks/m6/{certification_run_id}/direct-certification-report.json
```

`CompileSmoke` 只允许写 `not_run_compile_smoke_only`。正式 `Certification` 必须
在 clean HEAD 上消费同 source revision、同 freeze digest 的 evaluator 与
runtime 认证报告，且 freeze before/after 一致，才能写 `certified`。

最后 direct 与 hotspot 必须绑定同一 freeze digest。Codex 手工修改 event、
projection、manifest、artifact 或状态会让该样本降级为 `assisted`，不能作为
L3 证据。真实账号、联网和 provider 调用仍按各自 route 单次授权。

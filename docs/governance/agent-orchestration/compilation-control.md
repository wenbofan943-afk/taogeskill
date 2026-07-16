# Compilation Control

> 状态：项目级编译控制合同
> 主责：把已确认的产品定义稳定编译为可执行 Skill / runtime / checker，而不是把“写了代码”误报为“产品已实现”。
> 边界：本文件不替代某个产品的字段和验收标准；具体字段仍以产品确认清单、字段词典、`SKILL.md`、`CONTRACT.md` 与机器 Schema 为准。

---

## 编译层在 AI 驾驭工程中的位置

```text
产品定义层：为什么做、做什么、取舍与用户确认
        ↓ human_product_confirm
编译控制层：把确认项拆成机器合同、实现、正反 fixture 与门禁
        ↓ product_contract_compilation_gate
运行层：按已编译合同执行、记录 evidence、reconcile 与交付
        ↓ final_delivery_regression_gate
发布层：从 Git index 构建、净化、安装与远端验证
```

路由层只决定“该进入 `skill_compile`”；编译层必须回答“它到底是否已被完整实现”。运行层不得替编译层用人工补文件或聊天解释来填补缺口。

## 编译输入与开始条件

进入 `skill_compile` 前，必须能定位到一个明确的产品确认批次，并最少给出：

```text
confirmed_scope        本轮要实现的需求编号 / 行为边界
decision_owner         谁确认了什么；未确认项是什么
producer_consumer_map  每个新对象的 producer、consumer、ID、状态与物理路径
compatibility_impact   新旧版本是否可回放、是否需要迁移或 supersede
acceptance_examples    至少一个正例和一个会被拒绝的反例
```

任一项缺失，归为 `product_gap`，回到 `product_definition`；不得先写 runtime 再倒推产品含义。

## 六层编译闭合

任何新增、删除或改变语义的产品规则，必须逐项落到下列六层。这里的“规则”包括数量、条件必填、版本、状态转换、来源路由、失败语义、恢复、默认值与交付口径。

| 层 | 必须有的证明 | 不算证明 |
|---|---|---|
| 1. 产品与字段 | 确认清单、字段词典、状态语义、兼容策略 | 只有聊天结论或 prose |
| 2. 执行合同 | `SKILL.md` / `CONTRACT.md` 写清输入、输出、producer、consumer、停止条件 | 只写“由 agent 判断” |
| 3. 机器合同 | Schema、registry、路由或确定性校验接受当前版本并拒绝非法值 | 字段名在一个 JSON 中出现 |
| 4. Runtime / renderer | 当前 producer 实际写出 consumer 可读的版本、状态、hash 与引用；后处理由 operation registry 解析 | 手工创建 payload、pointer、submission 或 event |
| 5. Fixture | 正例、负例、恢复 / revision / resume（若语义涉及）覆盖新旧兼容边界 | 只跑一次真实账号数据 |
| 6. Checker / gate | 专项 checker 验证行为、数据流和负例；聚合 gate 只汇总结果，不复制真实运行常量 | parser pass、截图好看或历史 checker 绿灯 |

`product_contract_compilation_gate` 与 `contract_data_flow_gate` 是这六层的项目门禁；`runtime_smoke_gate` 证明入口确实能运行。三者缺任一项，都只能称“部分实现”。

## 版本、兼容与 contract_break

机器合同升级必须显式区分：

```text
compatible_replay        历史 session 可按旧合同回放；当前新运行使用新合同
superseded_pending_recompile  新人类确认已取代旧实现；未完成六层闭合前不得做真实外部回归
incompatible_migration   旧数据需迁移；迁移输入、输出、失败和回滚必须可验证
```

当前 producer 的版本、状态、必填字段、hash 或 artifact reference 不能被直接 consumer 接受，统一为 `contract_break`。其处理是：

```text
停止当前 phase
-> 保留 producer / consumer / version / status / fingerprint
-> checkpoint
-> 经当前用户明确授权，转 issue_triage / product_definition / skill_compile
```

禁止以手工复制、改写、拼接或提交私有运行目录的 payload、pointer、submission、asset set、manifest 或 event 来跨过该错误。reconcile 已存在的 provider 输出不等于允许重建编译产物。

## 原子编译循环

每个原子变更按以下顺序，不能跳过中段直接宣称全链完成：

```text
确认项 -> 编译影响表 -> 六层最小实现 -> focused 正反 fixture
-> data-flow / compilation / runtime smoke gates -> 状态与兼容记录
-> 本地原子 commit -> 小扫地
```

一轮只完成能独立解释、独立回滚的一个合同切片。发现另一条产品路线、真实回归、公开包或远端验证需求时，按路由重新授权；“按 AGENTS”或“递归排查”不构成无限编译授权。

## 编译完成的用户可读交付

每轮 `skill_compile` 收口必须用业务语言说明：

```text
本次把哪一条产品承诺变成了什么实际能力。
输入到最终 consumer 的关键数据如何流转。
哪些反例现在会被系统阻断。
哪些真实运行 / 外部调用没有执行，不能据此宣称已验证。
本地检查、commit、未推送状态和下一步。
```

禁止使用“代码已写”“checker 绿了”替代上述说明。

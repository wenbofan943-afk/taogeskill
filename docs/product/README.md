# Product Docs Index

> 状态：active_index
> 主责：区分当前产品真源、确认入口、编译记录和历史研究。
> 阅读原则：按任务选一条路线，不要默认全文读取 30 份产品文档。

当前确认范围：R0、R1、R2、R4-C01 到 C58 已确认；`R4-WIN-H1/H2/H3` 已完成 argv、共享 runtime helper、隐藏依赖清理和 environment/path preflight，下一批为 H4 的 archive manifest / 解压完整性。R3 已确认并编译到 `R3-C90`，`P0-H7-C01` 到 `P0-H7-C15` 已完成 v0.3 Skill 编译。真实 `PRIVATE-H6-H7-REGRESSION` 已重建为同一 delivery revision 的发布执行工作台，专项检查 20/20，结果 `pass_with_warnings`；未实际发布，传播效果未测试。

## 当前先读

| 目的 | 文档 |
|---|---|
| 看全项目 P0/P1 修复状态 | [GitHub 开源上线前 Workflow 修复路线图](./GitHub开源上线前Workflow修复路线图.md) |
| 第一次使用 / 建账号 | [R0 首次账号建档与入口 Onboarding](./R0-首次账号建档与入口Onboarding.md) |
| 单篇内容主链 | [R1 产品总览](./R1-产品总览.md) → [R1 产品确认清单](./R1-产品确认清单.md) |
| 多分支与恢复 | [R2 产品总览](./R2-产品总览.md) → [R2 产品确认清单](./R2-产品确认清单.md) |
| 图片、画中画、封面 | [R3 产品总览](./R3-产品总览.md) → [R3 产品确认清单](./R3-产品确认清单.md) |
| 公开包与净化 | [R4 产品总览](./R4-产品总览.md) → [R4 产品确认清单](./R4-产品确认清单.md) |

## R1 单篇主链文档组

- [内容创作质量方法论编译补充](./内容创作质量方法论编译补充-R1.md)
- [R1-P02 Agent 扶跑收敛与可编译判定](./R1-P02-agent扶跑收敛与可编译判定.md)
- [R1-P13 Execution Trace 检查清单与 Validator 草案](./R1-P13-execution-trace检查清单与validator草案.md)
- [R1-P14 方法论编译规则](./R1-P14-方法论编译规则.md)
- [R1-P15 Skill 粒度与入口治理规则](./R1-P15-skill粒度与入口治理规则.md)
- [R1 Skill 执行合同组可编译总验收](./R1-skill执行合同组可编译总验收.md)
- [R1 合同版本与变更治理](./R1-合同版本与变更治理.md)
- [R1 字段级输入输出矩阵](./R1-字段级输入输出矩阵.md)
- [R1 人类门禁决策枚举与恢复规则](./R1-人类门禁决策枚举与恢复规则.md)
- [R1 Trace / Check 注册表](./R1-trace-check注册表.md)
- [R1 Skill 拆合与编译记录](./R1-skill拆合与编译记录.md)
- [R1 Skill 编译验收与 Sample Run 清单](./R1-skill编译验收与sample-run清单.md)

## R2 运行模型文档组

- [R2 运行模型与分支封锁规则](./R2-运行模型与分支封锁规则.md)

## R3 图片资产文档组

- [R3 画中画与图片资产模型](./R3-画中画与图片资产模型.md)
- [R3 Skill 编译记录与审计](./R3-skill编译记录与审计.md)

## R4 公开交付文档组

- [R4 开源交付与净化规则](./R4-开源交付与净化规则.md)

## 跨路线合同与验收

- [P01 Skill Contract 可编译验收表](./P01-skill-contract可编译验收表.md)
- [R1-R4 综合 Dry-run 前置检查](./R1-R4综合dry-run前置检查.md)
- [R1-R4 只读 Checker 产品定义](./R1-R4只读checker产品定义.md)

## 历史与检查证据

`checks/` 保存需要随源码追踪的历史检查结论；动态检查报告仍写 `state/checks/`。详见 [checks 索引](./checks/README.md)。路线图和编译记录中的旧章节属于审计历史，读取当前状态时优先看文档顶部导航指向的“当前状态 / 最新批次”。

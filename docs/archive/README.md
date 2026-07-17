# Archive Index

> 状态：historical_audit_only
> 主责：保存已被 current 产品合同、执行规范或机器合同取代，但仍需审计追溯的历史文档。
> 边界：本目录不是运行时必读区，不得作为当前产品、状态或执行合同真源。

## 阅读规则

```text
默认不读 archive。
只有追溯历史决定、旧 session replay、事故复盘或版本迁移时按需进入。
归档文档与 current 真源冲突时，以 state/current-state.yaml、docs/product/、
docs/reference/、Skill / CONTRACT、Schema 和 checker 的当前版本为准。
```

## 分区

- [历史产品与编译记录](./product/README.md)
- [历史解释与复盘](./explanation/README.md)

## 归档准入

文档只有同时满足以下条件才可移入：

1. 已被明确的 current 文档或机器合同取代；
2. 不再是 route 的 required read；
3. 不被当前 runtime、Schema、checker 或公开构建直接消费；
4. 保留它仅用于审计、replay 或理解历史决定；
5. 移动后已修复当前索引和内部链接。

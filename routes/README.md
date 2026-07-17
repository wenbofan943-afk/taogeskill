# Routes

> 状态：机器可读路由入口
> 主责：保存 task_type、build_profile、run_control、required_reads、gates、outputs、after_completion 的稳定映射。
> 边界：本目录不保存具体文案、账号资料、运行日志或发版产物。

---

## 文件

| 文件 | 主责 |
|---|---|
| `workflow-routes.yaml` | 用户意图到 task_type / profile / 必读 / 门禁 / 输出 / 任务后导航的机器可读路由 |
| `build-profiles.yaml` | dev / test / public 三类构建 profile 的机器可读边界 |
| `architecture-control.yaml` | 五个架构平面、当前 L2.8 限制、架构触发条件、认证冻结和事故到规则晋升 |
| `current-workflow-ir.json` | current 控制面真源：direct / hotspot 两条 route、7 个顶层阶段、stage binding、停止/恢复策略与 M5 代际隔离策略；不携带 legacy blueprint / node 投影 |
| `component-catalog.json` | current 组件真源：35 个 stage-internal Skill、确定性 operation、外部 activity 和 human gate 的实现及合同；不携带 legacy step 映射 |
| `compatibility-catalog.json` | M5 历史兼容真源：12 条旧 blueprint 与 15 项仍有 consumer 的兼容资产；只允许 `WorkflowCompatibilityLoader.ps1` 为旧 session / replay 或 compile-time parity 读取，current caller fail-closed |
| `run-control-profiles.yaml` | 连续执行预算、重复失败/修复上限、上下文压缩边界和 checkpoint_and_return 策略 |
| `content-structure-strategies.yaml` | R6 可扩展短视频结构策略注册表；策略是候选，不是每篇强套模板 |
| `r6-semantic-normalization-registry.yaml` | R6 v0.2 主体、日期、数字、百分比、金额、单位和来源身份的 typed fact 规范化规则 |
| `r7-workflow-blueprints.yaml` | legacy R7 v0.6 直供 / 热点单篇蓝图及旧版本 replay；M5 后只经 compatibility loader 服务已绑定或 version-pinned 的 legacy session |
| `r7-node-registry.yaml` | R7 节点 Skill、输入选择、输出、路由、stale 与 retry 登记 |
| `r7-contract-status-registry.yaml` | active / pending / superseded 的机器状态真源 |
| `r7-action-registry.yaml` | v0.3 当前动作 code；含内部 Topic Gate 与最终交付决定，阻止自然语言猜 enum |
| `r7-action-registry.v0.1.yaml` | 直供 v0.2 / delivery v0.6 钉住的历史动作注册表，不随 H6A 静默升级 |
| `r7-input-selector-registry.yaml` | task 输入 selector 的 resolver、相对路径、ID / status 和空值策略 |
| `r7-artifact-commit-registry.yaml` | artifact ID / status 字段与 revision / current pointer 路径模板 |
| `r7-status-route-registry.yaml` | node result status 到 success / warning / waiting / failure 的确定性映射 |
| `r7-task-guidance-registry.yaml` | task envelope 的业务目标与决策边界来源 |
| `r7-producer-adapter-registry.yaml` | H3 直供 node 到 payload Schema、artifact type 与校验模式的唯一映射 |
| `r7-delivery-presentation-registry.yaml` | Topic Gate、source context 与 current delivery 呈现登记；v0.8 额外显示视觉来源和返修追溯 |
| `r7-delivery-presentation-registry.v0.1.yaml` | 直供 v0.2 / delivery v0.6 钉住的历史呈现注册表 |
| `r7-runtime-capability-registry.json` | L3 maturity baseline 使用的 Skill / tool / provider / human gate 身份与四类合同面 |
| `r7-visual-operation-registry.yaml` | H2 图片生成、来源捕获、裁切、叠字、标注、rendition、封面、finalize 和 viewport 的通用操作身份 |
| `r8-skill-context-registry.yaml` | 28 个项目业务 Skill 的职责、主输入输出、node owner、入口摘要 / 行数、current / legacy 与条件 reference 清单 |
| `r8-h5-evaluation-contracts.yaml` | H5 v0.2 九类评估对象的 producer / consumer、物理路径、门禁顺序、兼容状态与跨对象不变量 |
| `r8-h5-arm-adapters.yaml` | H5R2 三个目标 Skill 的 baseline/candidate commit、合同版本、直接输入类型与六个 typed input Schema 真源 |
| `r8-h5-machine-evaluation.yaml` | H5R3-H5R4 六个 arm 的主产物类型、业务输出 Schema、共享语义 validator、false-success 防护，以及 sealed arm task、typed submission、私有 allocation 与匿名包 runtime 真源 |
| `r8-h5-finalization.yaml` | H5R5 人类盲评记录、私有映射解析、readiness 优先级、唯一 deterministic finalizer、blocker code 与只消费 finalization 的状态投影真源 |

## 关系

```text
docs/governance/agent-orchestration/
  解释规则和人类可读说明

routes/
  机器可读路由、架构边界和运行控制真源
```

当两者冲突时：

```text
短期：以 docs/governance/agent-orchestration/ 的解释为准，并修 routes。
长期：以 routes/ 为机器真源，docs 只做解释。
```

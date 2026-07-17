# R8 产品定义：业务 Skill 渐进披露与职责重构

> 状态：`R8-C01-C70_confirmed_H5_v01_invalid_H5R5_compiled_human_review_pending`
>
> 触发事实：26 个项目业务 Skill 中，`hotspot-topic-research`、`propagation-router`、`platform-packaging-adapter` 的 `SKILL.md` 分别为 953、777、665 行；三者合计占全部项目 Skill 入口行数约 63%，且均未使用 `references/` 做按需加载。
>
> 主责：在不改变用户业务流程、不把业务节点拆碎的前提下，把 current 执行规则、条件方法、历史兼容、模板和确定性实现放回正确层级。
>
> 边界：R8-H1-H4 与 H5R1-H5R5 已完成编译。修复匿名投影拓扑后，current evaluation 生成热点 2 对、平台 2 对，router baseline 两案非法路由导致该 Skill 无可比样本。current 状态为 `human_verdict_and_finalizer_compiled_review_pending`；实际 human verdict 和 finalization 尚未提交。

<!-- ai-nav:start -->
## AI 阅读导航

- 看总体取舍：读第 1-4 节。
- 看热点 Skill：读第 5 节。
- 看传播路由与人工门禁：读第 6 节。
- 看多平台包装：读第 7 节。
- 看其余 Skill 的保持策略：读第 8 节。
- 看迁移、评测与编译批次：读第 9-12 节。
- 看 H5 独立评估返修：读 11.4-11.9。
- 逐项确认：转 [R8 产品确认清单](./R8-产品确认清单.md)。
<!-- ai-nav:end -->

---

## 1. 用户问题与产品回答

用户关心的不是文件是否“看起来长”，而是：业务 Skill 太大是否会让 Codex 读错、跑慢、串入历史规则，以及拆分后能否真正变好。

R8 的产品回答是：

```text
长不等于一定要新增 Skill。
先判断一个业务节点是否仍有单一输入、单一输出和单一下游。
职责仍单一：保留 Skill，拆成入口 + 条件 references + assets / scripts。
职责已经跨节点：重划 Skill 边界，让每个节点只拥有自己的决定和产物。
任何“变好”必须由旧版 / 新版同题 A/B 证明，不能只凭行数下降宣称。
```

用户可感知的入口保持不变：仍然可以说“用涛哥 Skill”“找热点”“选 T001”“把这条发抖音、小红书和视频号”。R8 调整的是 AI 内部读取和节点职责，不新增需要用户记忆的命令。

## 2. 设计依据

R8 同时继承以下项目规则：

- [R1-P15 Skill 粒度与入口治理规则](./R1-P15-skill粒度与入口治理规则.md)：一个 Skill 对应一个明确触发、一个主输入、一个主输出和一个下游方向。
- [R1 Skill 渐进读取与长文边界](../reference/R1-skill渐进读取与长文边界.md)：current 入口只读执行必需内容，长方法和历史细节按需加载。
- [R7 语义工作流与交付候选编排](./R7-语义工作流与交付候选编排.md)：node registry、typed task、submission、artifact commit 和人类门禁是 current 运行真源。
- Agent Skills 开放规范：完整 `SKILL.md` 会在激活后进入上下文，入口建议低于 500 行 / 5,000 tokens，条件资料使用一层 references，确定性逻辑使用 scripts。

外部依据：

- https://agentskills.io/specification
- https://agentskills.io/skill-creation/best-practices
- https://agentskills.io/skill-creation/evaluating-skills

这些依据不意味着“越短越好”。过窄 Skill 会增加触发冲突和多 Skill 同时加载；R8 追求的是**职责完整但上下文最小**。

## 3. R8 产品范围

### 3.1 纳入

```text
hotspot-topic-research
propagation-router
platform-packaging-adapter
上述 Skill 的 CONTRACT.md、agents/openai.yaml、条件 reference、模板资产和 current / legacy 边界
与三者直接相关的 R7 node skill_ref、producer adapter、fixture 和 checker（仅列为后续编译影响）
```

### 3.2 不纳入

```text
Codex 系统 / 全局 Skill，例如 imagegen、skill-creator、GitHub、PDF、文档和表格插件
R3 / R7 已按独立 artifact 拆开的视觉 producer、reviewer、finalizer
自动发布、平台登录、平台 API、外部 LLM API
借本轮顺手重写热点算法、平台文案方法论或账号产品策略
仅因为目录总行数大就拆 scripts；脚本可直接执行，不等同于上下文膨胀
```

## 4. 全局渐进披露合同

### 4.1 三层内容

每个 current 业务 Skill 固定按三层组织：

| 层 | 进入上下文时机 | 允许内容 |
|---|---|---|
| metadata | 始终 | `name`、清楚的触发条件、明确不负责什么 |
| `SKILL.md` | Skill 激活后 | current 主流程、输入输出、状态、停顿、失败、必读 reference 路由 |
| resources | 条件满足时 | 平台差异、研究方法、风险细则、历史 replay、长模板、脚本 |

`SKILL.md` current 编译硬门槛为不超过 500 行；超过 350 行产生 `entry_context_warning`，要求说明为什么不能继续外置。5,000 tokens 是设计目标，只有当前执行环境能观察同一 tokenizer 时才可做机器门禁；不可观察时写 `not_observable`，不能用字符数伪装 token 结论。

### 4.2 入口必须保留的内容

```text
current contract identity / version selection
触发与不触发条件
唯一主输入与唯一主输出
允许状态与下一节点
核心步骤和不可违反的 gotchas
条件 reference 的精确读取条件
失败、等待、恢复和停止边界
必要的短输出示例
```

### 4.3 必须外置的内容

```text
完整字段词典复制
完整 Schema 复制
四个平台的全部长方法
只在高风险 / 趋势 / 扩词 / 旧 session 中使用的细则
完整 Markdown 输出模板
R1 / R2 / R5 历史 standalone 合同
编译过程、CHANGELOG、README、安装说明
可由确定性脚本完成的解析、校验、转换和渲染逻辑
```

reference 必须由 `SKILL.md` 直接一层引用，并写清“何时读”；不得只写“更多信息见 references”。同一规则只能有一个真源，current `SKILL.md`、`CONTRACT.md`、reference、字段词典和 Schema 不得重复维护同一长清单。

### 4.4 current 与 legacy

current 任务只加载 current runtime。历史兼容必须满足：

```text
只有 task / session 的版本明确进入 replay / legacy mode 才加载。
文件名带 legacy / replay 和适用版本。
文件首屏声明 historical_only，不能覆盖 current。
历史内容不得继续出现在 current SKILL.md 后半段等待 agent 自行判断。
current / legacy 选择必须来自 task envelope、blueprint 或 session contract，不从聊天语气猜测。
```

### 4.5 Skill context registry

H1 固定新增 `routes/r8-skill-context-registry.yaml`，作为入口体量、职责、current / legacy 和条件 reference 的机器索引。每个条目至少包含：

```yaml
skill_id:
skill_type: router / producer / reviewer / builder / compatibility / human_gate
user_invocable:
current_contract_version:
primary_input_artifact_type:
primary_output_artifact_type:
owned_node_ids: []
skill_entry_path:
skill_entry_digest:
entry_line_count:
entry_line_limit: 500
entry_warning_threshold: 350
always_loaded_sections: []
conditional_references:
  - reference_id:
    path:
    load_when:
    content_owner:
legacy_references: []
machine_truth_refs: []
ownership_status: current / compatibility / superseded
```

checker 从真实文件派生行数和 digest，不信任手填值；`load_when` 必须是版本、node、status、mode 或 `target_platforms` 可判断条件，不能写“必要时”。

## 5. `hotspot-topic-research` 产品重构

### 5.1 保留一个热点研究 Skill

`hotspot-topic-research` 不拆成“扩词 Skill、搜索 Skill、评分 Skill、证据 Skill、Topic Gate Skill”。原因是 current R7 节点仍有稳定单责：

```text
current hotspot_research_request
  -> 发现、核验、signal/event/candidate/topic-option 归并与排序
  -> current hotspot_research_set
```

它不再承担：

```text
创建账号档案
从聊天重建雷达范围
渲染 topic_selection_panel
记录人类选题决定
生成 selected_topic_source
写 Content Brief 或完整文案
```

### 5.2 current 入口内容

入口只保留：

```text
R7 current task 版本选择
request 是账号、策略、时间和范围唯一真源
研究流程与主对象关系
事实 / 传播 / 风险分层
单一 research set 提交
ready / no_recommendation / waiting_external / blocked 状态
失败与 resume 规则
下游固定为 deterministic panel projector
```

### 5.3 条件 references

后续编译固定形成：

| reference | 读取条件 | 内容边界 |
|---|---|---|
| `references/source-and-query-strategy.md` | initial、same-policy rerun、broaden 或 manual-source refresh | 来源池、查询扩展、二手车优先与外溢证明 |
| `references/event-and-trend-model.md` | 需要归并事件、比较快照或写趋势 | signal → event → candidate、同口径快照与趋势口径 |
| `references/evidence-risk-scoring.md` | 高风险、争议信息或需要排序 | 事实、传播、风险、证据充分性和评分 gotchas |
| `references/legacy-r1-r5-standalone.md` | 明确 legacy / replay | 旧账号补问、旧 topic card、旧 Markdown 面板和 standalone 停顿 |

长输出模板放 `assets/`，current typed output 以 Schema 和 submission contract 为准，不再要求 Agent 复制 100 多行 Markdown 空表。

### 5.4 不改变的业务

```text
二手车直接相关仍是硬优先。
不足 3 条事实可核验的二手车候选才启用有传导证明的新车外溢。
扩词仍可自由探索，选择反馈只做偏好证据，不逐词人工批准。
signal / event / candidate / topic 四层模型不变。
至少两次同口径快照后才可称升温 / 持续 / 降温。
```

R8 只改变读取和职责，不重开 R5 产品决定。

## 6. `propagation-router` 职责重构

### 6.1 保留唯一用户入口

`propagation-router` 继续是“用涛哥 Skill / 开始 / 接着上次 / 下一步是什么”的唯一用户主入口，主责收缩为：

```text
识别 start / resume / next-action 意图
读取 workflow state 与 current artifact
判断唯一合法下一节点或需要的人类门禁
生成 router_decision / resume guidance
不生产正文、不执行 checker、不记录具体业务决定
```

账号启动缺口由既有 account startup contract 和 coordinator 执行；字段定义读取字段词典；测试 / checker / GitHub /产品开发等工程任务由项目 AGENTS task routing 负责，不再复制到业务传播 router。

### 6.2 人类门禁从 router 分离

R8 新增两个**内部节点 Skill**，不新增用户需要记忆的入口：

| Skill | 触发上下文 | 主输入 | 主输出 | 边界 |
|---|---|---|---|---|
| `topic-selection-decision-gate` | current node=`topic_human_gate` | current panel + typed user reply + action registry | `topic_selection_decision` | 不重排、不改 panel、不直接生成 selected source |
| `final-delivery-decision-gate` | current node=`final_human_decision_gate` | current delivery + viewport / visual / business review + typed user reply | `final_delivery_human_decision` | 不改 HTML、不替用户判断采用、不执行发布 |

两个 Skill 只解释当前可见选项并把用户明确回复映射到版本化 action；真正的 Schema 校验、artifact commit、pointer 和 event 仍由确定性 recorder / submitter 独占。`final_delivery_human_decision` 固定包含：

```yaml
decision_id:
session_id:
delivery_ref:
viewport_acceptance_ref:
delivery_visual_review_ref:
business_delivery_acceptance_ref:
action_code: adopt_delivery / request_revision / request_export / archive_session
user_reply_digest:
requested_at:
delivery_revision_request_ref:
export_mode:
decision_status: decision_recorded
```

`request_revision` 条件必填 current `delivery_revision_request_ref`；`request_export` 条件必填 `export_mode`；其余 action 两者均为空。新的 deterministic `final_delivery_decision_apply` 消费 decision 和 current session state，才产生 `workflow_session_record` 新 revision。这样人类决定与状态投影分离，不让语义 Skill 直接改 session。

decision current pointer 固定为：

```text
accounts/{account_slug}/runs/{session_id}/intermediate/r7/current/final_delivery_human_decision.json
```

revision、commit marker、lineage 和 pointer-last 路径继续由 artifact commit registry 派生，不在 Skill prose 中另造目录规则。

这两个门禁满足独立 Skill 条件：独立触发上下文、独立上游、独立输出、独立失败处理、独立 fixture，且从 router 拆出后可消除跨阶段指令干扰。

### 6.3 router 条件 references

| reference | 读取条件 | 内容 |
|---|---|---|
| `references/resume-and-recovery.md` | 用户说继续、断了、恢复或 current state 非正常终态 | manifest、checkpoint、pending submission、resume 证据顺序 |
| `references/legacy-r1-r2-routing.md` | 旧 session / branch replay | 旧交接块、多选 handoff 和历史状态兼容 |

router 不再保存各 artifact 的完整字段清单，只保留“读哪个 current pointer、缺什么回哪个 owner”的最小摘要。

### 6.4 用户体验保持

用户仍可直接回复：

```text
选 T001
重找一轮
只在账号范围内放宽
采用这一版
只改抖音标题
```

用户不需要知道当前由 router、topic gate 还是 final gate 响应。差异只体现在执行证据中：每次决定由正确 owner 处理，不再由总入口包办。

## 7. `platform-packaging-adapter` 渐进披露

### 7.1 保留一个 Skill

多平台包装仍是一个连贯业务节点：同一已通过内容，根据本次 `target_platforms` 生成一个 `platform_package`。不拆成抖音、小红书、视频号、快手四个 Skill。

原因：

```text
四个平台共享同一内容事实、核心承诺和标题一致性门禁。
输出需要一次性形成同一 package，便于后续封面与 HTML 消费。
拆成四个 Skill 会增加 fan-out / fan-in、状态合并和跨平台漂移。
```

### 7.2 按目标平台读取

后续编译固定形成：

```text
references/douyin.md
references/xiaohongshu.md
references/wechat-channels.md
references/kuaishou.md
assets/platform-package-template.md
```

只有 `target_platforms` 包含的平台才能加载对应 reference。未选择快手时，快手规则不得进入本轮上下文，也不得生成空快手卡片。

`SKILL.md` 保留跨平台共同合同：输入门槛、核心内容不改写、标题类型分工、package 组装、状态、回退和下游 cover design。

### 7.3 不改变的业务

```text
同一视频主体不因平台包装被重写。
封面标题、视频标题、发布描述、话题标签继续分字段。
delivery_title 继续是最终交付页独立标题。
平台包装不等于自动发布。
封面底图建议不等于可上传封面成品。
```

## 8. 其余 Skill 的保持策略

R8 不以“文件越短越成熟”为目标。以下情况维持现状：

- `cover-design-compiler` 的入口为 210 行，复杂操作已放 scripts；包总行数大不是上下文问题。
- `static-visual-director`、`image-prompt-compiler`、`image-asset-producer`、`visual-asset-reviewer`、`visual-asset-finalizer`、`delivery-visual-reviewer` 各自产生不同 artifact 或 verdict，继续保持独立。
- `hotspot-copywriting-research` 仍是 compatibility 入口，不借 R8 扩展新职责；后续只在触发漂移或重复加载有证据时再收缩。
- 其他低于 500 行且保持单一职责的 Skill，不因本轮做机械拆分或合并。

以后新增 Skill 必须同时满足业务粒度门禁与上下文门禁；“只有一个字段、检查项或评分维度”仍不得新建 Skill。

## 9. `CONTRACT.md` 与机器真源

只缩短 `SKILL.md` 不足以解决问题。如果 current 运行仍要求全文读取 800 行 `CONTRACT.md`，上下文负担只是换了文件名。

R8 规定：

```text
CONTRACT.md 只描述 current 人读合同、版本选择和机器真源入口。
字段枚举以 Schema / 字段词典为准。
节点、状态和路由以 registry / blueprint 为准。
历史合同进入 legacy reference。
Skill 不复制 CONTRACT 全文，CONTRACT 不复制 Schema 全文。
同一规则的 ownership 必须可从索引唯一解析。
```

`agents/openai.yaml` 必须在编译后重新生成或验证，确保 description 与收缩后的职责一致，避免入口已经拆开但触发描述仍把所有功能拉回 router。

## 10. 版本、迁移与成熟度影响

### 10.1 兼容方式

热点和平台包装只改变知识装载结构，不改变 current 主输入 / 主输出时，可以保持业务 payload 版本，但必须更新 Skill contract digest 和 maturity baseline。

router 的人类门禁 skill owner改变，以及 final decision / apply 两节点化，会影响：

```text
r7-node-registry node / skill_ref
producer / gate adapter registry
task envelope allowed skill identity
capability snapshot
workflow blueprint digest / maturity baseline digest
相关 fixture、checker 和公开包清单
```

旧 session 继续按旧 baseline replay，不回填新 gate Skill；新 session 使用新 baseline。任何 R8 编译都会使编译前的 L3 样本只作历史证据，不能拿旧样本证明新 Skill 结构达到 L3。

### 10.2 不允许的迁移

```text
不在同一 contract version 下静默换 owner。
不让 legacy reference 覆盖 current。
不把长文从 SKILL.md 原样搬进一个每次必读的 reference。
不为缩短行数删除失败、恢复、停止或风险规则。
不修改已完成真实 session 的 artifact、event 或 autonomy evidence。
```

## 11. A/B 评测合同

R8 是否“效果更好”必须比较旧版与新版，不以行数作为唯一结果。

### 11.1 样本

每个目标 Skill 至少包含三类脱敏真实口吻任务：

```text
正常主链：输入完整，应该一次路由 / 产出。
恢复或条件分支：waiting、rerun、只选部分平台、旧 session replay。
拒绝路径：缺 current input、错误 action、历史规则试图覆盖 current。
```

同一 prompt、semantic case 和业务目标分别运行：

```text
baseline：编译前 Skill 快照
candidate：R8 拆分后的 Skill
```

双方共享业务语义和事实，但由各自版本 adapter 生成 canonical typed input；不同
合同版本不要求输入 JSON 字节相同。隔离等级按 11.6 记录，不再笼统宣称“干净
上下文”。不向 candidate 泄漏预期答案，也不让 baseline 读取 candidate 产物。

### 11.2 最终评估记录

R8-H5 v0.2 必须由 deterministic finalizer 形成唯一
`skill_context_eval_record`：

```yaml
schema_id:
schema_version:
eval_id:
attempt_id:
case_id:
skill_id:
semantic_case_digest:
prompt_digest:
baseline_snapshot_digest:
candidate_snapshot_digest:
baseline_input_digest:
candidate_input_digest:
baseline_arm_result_ref:
candidate_arm_result_ref:
baseline_machine_result:
candidate_machine_result:
shared_invariant_result:
comparability_status:
blind_pair_ref:
human_verdict_ref:
baseline_isolation_assurance:
candidate_isolation_assurance:
baseline_manual_assist:
candidate_manual_assist:
baseline_duration_ms:
candidate_duration_ms:
baseline_input_tokens: not_observable
candidate_input_tokens: not_observable
output_quality_assertions: []
human_blind_preference: not_assessed
overall_result:
supersedes:
```

字段枚举固定为：

```text
baseline_machine_result / candidate_machine_result / shared_invariant_result：pass / fail / invalid
comparability_status：comparable / behavior_only / regression_disposition / insufficient_comparable_samples / invalid
isolation_assurance：instruction_isolated / read_audited / capability_isolated
human_blind_preference：candidate / baseline / tie / not_assessed
overall_result：pass / fail / invalid
input_tokens：非负整数 / not_observable
duration_ms：非负整数
```

节点、reference、Schema、扶跑和业务产物的逐 arm 原始证据保存在
`h5_arm_result` / `h5_machine_verdict`，final record 只保存引用和汇总结论，避免
复制两套可漂移事实。

脱敏 fixture 放 `examples/r8-skill-context-fixtures/`；动态报告放
`state/checks/r8/{eval_id}/{attempt_id}/`。真实私有内容只允许进入 ignored account
run 或 ignored check evidence，不进入 fixture 和公开包。

token、模型档位或前端内部读取量不可观察时必须保留 `not_observable`；可用 duration、加载文件、错误路由和产物门禁作为可观察替代证据，但不能宣称 token 已下降。

### 11.3 通过标准

本节保留 R8-C39 的原始业务意图；H5 v0.2 的可执行判定细节以 11.6-11.9 为准。

candidate 只有同时满足以下条件才可替换 current：

```text
所有 current 正例 Schema / contract gate 不低于 baseline。
所有拒绝路径继续 fail-closed。
current / legacy 混淆为 0。
错误 node / Skill owner 为 0。
无新增人工扶跑或临时 helper。
只加载任务需要的 reference。
人类盲评业务产物不低于 baseline。
至少一个可观察效率指标改善，或在效率持平时明显降低合同混淆。
```

### 11.4 H5 v0.1 失效结论

2026-07-17 的 H5 v0.1 不能继续进入人类盲评，原因不是 candidate 已被证明
业务失败，而是评估链本身不满足产品合同：

```text
9 个 business_input 均不是对应 Skill 的 canonical typed input。
6 个盲评案例中只有 1 个同时产生可比较的业务产物。
blocked / waiting / gate result 被混入业务质量盲评。
arm output 没有业务 Schema gate，也没有形成完整 skill_context_eval_record。
baseline 与 candidate 没有各自版本的 input adapter 和评分口径。
机器审计 fail 时，packet generator 仍输出 ready。
所谓 clean context 只有提示词约束，没有可证明的文件读取隔离。
aggregate checker、arm output、blind packet 和 current state 没有统一 finalizer。
```

因此：

```text
H5 v0.1 evaluation_status = invalid
H5 v0.1 blind_packet_status = quarantined_not_for_review
H5 v0.1 current_switch_evidence = invalid
H1-H4 compile result = unchanged
business Skill defect = not_proven_by_H5_v0.1
```

旧 raw output、machine audit 和匿名包保持不可变，作为失败样本用于 replay；不得
手改后重新宣称通过。

### 11.5 独立评估对象链

H5 v0.2 使用九个版本化对象，不再让一个脚本同时承担输入、执行、审计和状态结论：

```text
h5_semantic_case
-> h5_dependency_snapshot[baseline | candidate]
-> h5_arm_input[baseline | candidate]
-> h5_arm_result[baseline | candidate]
-> h5_machine_verdict
-> h5_comparability_verdict
-> h5_blind_pair
-> h5_human_verdict
-> h5_evaluation_finalization
```

对象职责：

| 对象 | 唯一职责 |
|---|---|
| `h5_semantic_case` | 保存双方共享的业务意图、事实、目标和共享结果不变量；不直接冒充任一版本的 typed input |
| `h5_dependency_snapshot` | 冻结一个 arm 的 entry、CONTRACT、references/assets、机器真源及完整依赖摘要 |
| `h5_arm_input` | 由版本化 adapter 把 semantic case 编译成对应 arm 能直接消费的 canonical typed input |
| `h5_arm_result` | 保存一次独立执行的客观结果、上下文证据、业务产物引用和执行状态；不自评质量 |
| `h5_machine_verdict` | 分别验证 baseline 历史合同、candidate current 合同和双方共享业务不变量 |
| `h5_comparability_verdict` | 判断两边结果属于质量可比、行为比较、回归处置还是无效 |
| `h5_blind_pair` | 只承载机器通过且具备可比性的匿名业务产物 |
| `h5_human_verdict` | 逐案记录 A / B / tie 和业务理由，不知道 arm 映射 |
| `h5_evaluation_finalization` | 唯一派生 H5 最终状态和 current switch readiness |

### 11.6 输入、快照与隔离证据

#### 语义等价，不要求版本间字节相同

baseline 与 candidate 的合同版本可能不同，不能把同一份聊天式 JSON 同时塞给两边。
双方必须共享同一个 `semantic_case_digest`，再由各自 adapter 生成 typed input：

```text
semantic intent / facts / requested outcome 相同
baseline typed input 符合 baseline Schema
candidate typed input 符合 candidate Schema
允许字段形态不同
不允许业务事实、账号策略、目标平台或预期结果不同
```

执行前必须验证：

```text
schema_id
artifact_type
contract_version
input_digest
semantic_case_digest
adapter_id
adapter_version
source_snapshot_digest
```

任何一边 input gate 失败，本案记 `invalid_input`，不得启动执行臂。

#### 快照必须覆盖依赖闭包

baseline 不能只读取一个历史 `SKILL.md`。快照 manifest 至少固定：

```text
entry Skill
CONTRACT
一层 references / assets
直接机器真源
每个文件的 source commit、path、SHA256
dependency_closure_digest
```

candidate 使用相同结构记录 current dependency closure。两边不得读取对方输出。

#### 隔离等级必须诚实

```text
instruction_isolated：
  独立任务、无继承对话、密封输入包、独立输出目录，但共享文件系统且无读取审计。

read_audited：
  在 instruction_isolated 基础上，存在实际读取路径 / digest 清单，可检查越界读取。

capability_isolated：
  工具或文件系统权限从能力层阻止越界读取。
```

当前 Codex 项目最多可稳定声称 `instruction_isolated`；没有平台级读取审计或权限
隔离时不得写 clean-room、machine-isolated 或 no-leak-proven。该等级可用于本项目
L2.8 的业务质量对比，但不能单独作为 L3 自主执行证据。

### 11.7 Arm 结果和可比性

`h5_arm_result` 只记录执行臂与 orchestrator 可观察到的事实，不得自行生成
`output_quality_assertions` 或判定自己胜出。它必须区分三类节点字段：

```text
requested_node_id：输入请求或当前状态携带的节点。
selected_node_id：本次路由决定选择的合法节点；拒绝前未选择则为 null。
executed_node_id：实际执行过的节点；拒绝、等待或仅返回 route decision 时为 null。
```

结果状态固定为：

```text
produced_business_artifact
waiting_valid
blocked_valid
execution_error
invalid_input
invalid_output
```

只有 `produced_business_artifact` 可以填写 `business_artifact_ref`。这里的业务
产物指 registry 为该 Skill 声明的 primary output；router decision 可以是 router
的业务产物，普通状态说明或临时 gate report 不能冒充 primary output。产物必须
通过对应 Schema、artifact type、status、hash 和共享业务不变量。waiting、blocked
和非 primary-output 的 gate result 进入机器行为审计，不冒充质量盲评对象。

可比性 gate：

| 双方结果 | 处理 |
|---|---|
| 同为 Schema-valid `produced_business_artifact`，且共享目标和产物语义一致 | 可进入匿名质量盲评 |
| 同为 waiting / blocked | 只做机器行为比较 |
| 一边 produced、一边 waiting / blocked | 进入 capability / regression disposition，不进入质量盲评 |
| 任一 input / output / machine contract invalid | 整案阻断，禁止生成盲评对 |
| rejection case | 只验证 fail-closed、owner、零副作用，不进入质量盲评 |

每个目标 Skill 至少要有 1 个双方均 produced 的正常案例；否则该 Skill 的质量 A/B
为 `insufficient_comparable_samples`。条件 / 恢复案例只有双方都产生相同语义的
业务产物时才可额外进入盲评。

### 11.8 门禁顺序和 false-success 防护

固定顺序：

```text
evaluation preflight
-> semantic case gate
-> arm input Schema / equivalence gate
-> dependency snapshot gate
-> independent arm execution
-> arm output Schema / business artifact gate
-> baseline-specific + candidate-specific + shared invariant machine audit
-> comparability gate
-> anonymous packet generation
-> human blind verdict
-> deterministic finalization
-> current state projection
```

前一门禁未通过，后一阶段不得运行。尤其：

```text
machine audit fail 不能输出 packet=ready。
没有 comparable pair 不能要求人类盲评。
packet 只包含匿名业务产物，不包含 role、snapshot、notes 或实现身份线索。
allocation mapping 私有保存，评审完成前不参与业务解释。
aggregate checker 只能消费 finalization，不得另算一套 current readiness。
arm result 不得自评质量；quality assertions 由 machine verdict 和 human verdict 产生。
human verdict 先以 A / B / tie 不可变提交，finalizer 才允许读取 mapping 并转换为 candidate / baseline / tie。
```

原始输入、arm output、machine verdict、mapping 和 human verdict 均不可原地修改。
修订必须新建 `evaluation_id + attempt_id`，并用 `supersedes` 连接旧证据。
`evaluation_id`、证据根和报告路径必须由调用参数派生，不得写死日期或 CURRENT。

### 11.9 最终通过规则与编译层次

candidate 切换证据必须同时满足：

```text
所有输入、快照、输出和机器合同门禁通过。
每个目标 Skill 至少一个可比较的正常业务产物对。
所有拒绝路径 fail-closed，且没有副作用。
candidate 没有 current / legacy 混淆和新增人工扶跑。
每个可比较案例的人类结论均为 candidate 或 tie；任一 baseline 胜出即不切换。
至少一个可观察效率指标改善；不可观察项保留 not_observable。
finalization 为 passed，current state 只投影该 finalization。
```

H5 v0.2 分层编译：

| 批次 | 编译范围 | 停点 |
|---|---|---|
| R8-H5R1 | 九类对象 Schema、字段词典、状态枚举和兼容 / supersedes 合同 | typed fixture 与负例通过 |
| R8-H5R2 | semantic case、baseline / candidate adapter、dependency snapshot compiler | 三个目标 Skill 的双 arm input 均通过 Schema 与语义等价门禁 |
| R8-H5R3 | arm result recorder、machine evaluator、comparability gate、false-success 防护 | 无代理执行也能用 fixture 验证所有状态 |
| R8-H5R4 | 新 evaluation_id 的两个独立执行臂与匿名包 | 只有机器通过且可比较的产物进入 blind packet |
| R8-H5R5 | human verdict recorder、deterministic finalizer、aggregate/state projection | 形成唯一 finalization，再决定 H5 pass / fail |

## 12. 后续编译批次

用户确认产品定义后，按以下顺序进入 `skill_compile`：

| 批次 | 内容 | 停点 |
|---|---|---|
| R8-H1 | 已建立 Skill context inventory、current / legacy ownership manifest、行数与引用 checker；26 个 Skill 与 11 个正反 fixture 已通过，3 个长入口作为后续已识别债务 | 已完成；不改业务输出 |
| R8-H2 | 已把 `hotspot-topic-research` 从 953 行收缩为 150 行，建立 3 个 current 条件 reference、1 个 historical-only reference 与 legacy template asset；metadata 同步收口 | 已完成；H2 10/10、热点前链 32 项、热点 route 8/8 通过 |
| R8-H3 | 已把 `propagation-router` 从 777 行收缩为 70 行，新增两个内部 human-gate Skill 与 deterministic final decision apply，并切换 current v0.6 node owner | 已完成；H3 9/9、PS5.1 runtime smoke 与 H1 28 Skill inventory 通过 |
| R8-H4 | 已把 `platform-packaging-adapter` 从 665 行收缩为 56 行，四个平台方法进入一层条件 reference，目标平台与 package 集合由 runtime 做完全一致校验 | 已完成；14/14 结构检查、7/7 单平台 / 三平台 / 负例通过 |
| R8-H5 v0.1 | 静态 preflight 和总回归可作历史证据；业务 A/B 因 typed input、可比性、输出 Schema、隔离证据和 finalizer 缺口失效 | `invalid_evaluation`；旧 blind packet 隔离，不进行人类盲评 |
| R8-H5R1 | 九类对象 Schema、字段词典、状态枚举、v0.1 / v0.2 兼容与 supersedes 合同、21 个负例 | 已完成；合同层通过 |
| R8-H5R2 | 9 个 semantic case、六个 adapter、18 个 typed input、18 个 dependency snapshot 与 18 个 arm-input | 已完成；7/7 负例、PS5.1 和 byte-stable replay 通过，未执行 arm |
| R8-H5R3 | 18 个 arm result、9 个 machine verdict、9 个 comparability verdict、五种状态与 hash/Schema/拒绝路径 false-success | 已完成；4 个 comparable pair、13/13 负例通过，未执行独立 arm |
| R8-H5R4 | 新 evaluation 独立双臂、typed submission、机器复核、私有 allocation 与匿名包 | 已完成；current 可读包热点 2 对、平台 2 对、router 0 对 |
| R8-H5R5 | 编译 human verdict recorder、deterministic finalizer、aggregate/state projection | 已完成编译；等待用户提交 4 个匿名选择，router/machine/rejection blocker 必须保留 |

H1-H4 已完成，H5 机器回归入口已编译。`hotspot-topic-research`、`propagation-router`
与 `platform-packaging-adapter` 均已完成 current / legacy 分离和入口收缩。
H1 当前为 `pass`，已知长入口债务为 0。H5 v0.1 的静态 preflight 9/9 和
current / legacy 回归 16/16 只证明既有机器检查没有回归；它们不能证明业务 A/B。
两个执行臂的 raw output 保留为失败证据，但 6 个盲评案例只有 1 个双方均产生
业务产物，当前匿名包不可评。token 继续保留 `not_observable`。H5 必须按
R8-H5R1-H5R5 重新建立证据链。

## 13. 产品完成定义

R8 产品层可进入编译，必须满足：

```text
三个目标 Skill 的保留 / 拆分类型明确。
每个 current Skill 的主输入、主输出、owner 和 stop 明确。
条件 references 的读取条件明确。
current / legacy 迁移明确。
router 新增内部 gate 的用户体验不变。
平台包装不被拆成四个独立 Skill。
其余 Skill 的“不拆”边界明确。
CONTRACT、Schema、registry、字段词典的真源分工明确。
A/B 样本、字段、通过标准和不可观察项明确。
编译批次和成熟度 baseline 失效规则明确。
```

R8-C01 至 C70 已由用户确认。R8-H1/H2/H3/H4 与 H5R1-H5R5 已完成本地编译。
R8-H5 v0.1 评估失效；H5 v0.2 当前到
`human_verdict_and_finalizer_compiled_review_pending`。下一步由用户对 current 4 个
匿名对提交 A/B/tie 与理由，再由唯一 finalizer 形成包含 router、machine 与 rejection
缺口的结论；不得为了 readiness=passed 修改原始产物或把非法路由包装为质量对比。

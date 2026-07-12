# R3 Skill 编译记录与审计

> 状态：r3_visual_need_auto_dispatch_compiled_and_audited
> 所属路线：R3 画中画与图片资产模型  
> 主责：记录 R3 产品确认后实际编译了哪些规则、skill、合同、样本模板，以及编译后对标成熟开源项目的审计结论。  
> 边界：本记录保留旧编译历史；当前 R3-C71 到 C90 已实现并完成 H6 单篇真实回归，但仍不代表平台发布、传播效果、多篇自动并行或 L3 candidate。

## 0. R3-C54 到 R3-C70 编译摘要

2026-07-11 按已确认产品合同完成视觉文字与封面质量编译：

```text
talking-head-image-pip（用户门面）
-> static-visual-director（原子规划三对象）
-> image-prompt-compiler（提示词与 provider 入参）
-> image-asset-producer（环境路由、资产记录、确定性叠字）
-> copywriting-quality-review（视觉文字门禁）
-> platform-packaging-adapter / cover-design-compiler（封面实质变体与成品）
-> final-delivery-builder（HTML 展示、复制、下载和追溯）
```

| 承载 | C54-C70 编译结果 |
|---|---|
| 字段与 reference | 三条信息轨、逐图 `visual_text_tasks[]`、逐单元来源绑定、门禁状态映射、封面实质变体和平台预览字段已注册 |
| 内部 Skill | 新增 `static-visual-director`、`image-prompt-compiler`、`image-asset-producer`，门面 Skill 不再承载全部工艺细节 |
| 质量与下游 | review、platform package、cover compiler、final delivery 已消费统一字段并提供局部恢复动作 |
| 确定性渲染 | `compose-visual-text.ps1` 已用实际 720x1280 图片完成叠字冒烟测试；模型含字失败可回退 overlay |
| HTML 与 schema | 最终 HTML 可复制视觉文字、查看来源和识别“本图按计划无字”；schema 与路由已登记新对象和内部 Skill |
| fixtures | 九类脱敏样例覆盖无字、内心、比较、机制、来源证据、伪证据、无字幕、模型文字降级和 title_only 封面 |
| checker / CI | `validate-r3-visual-text.ps1` 已接入 CI 与公开包 validator，并检查样例语义、源码合同、Skill 长度和旧字段写入 |

验证结果：

```text
四个核心 Skill quick_validate：pass。
PowerShell / JSON 解析：pass。
R3 visual text fixture：pass，blocker_count=0。
field schema / route schema / final delivery template / cover composition：pass。
R3 正确 run 目录 workflow replay：pass，12 steps，0 warnings。
regression suite：pass_with_warnings，0 blocker；警告来自既有样例 trace 证据成熟度，不是 C54-C70 字段断链。
```

已知边界：

```text
本轮是静态编译与脱敏回放，不等于真实账号综合内容验收。
platform-packaging-adapter 仍为 654 行的既有技术债，后续应单列拆分，不在 C54-C70 中扩大重构范围。
外部 Seedream API、视频生成、自动发布和发布后数据回流仍不实现。
```

### 0.1 编译后产品与主链复审

2026-07-11 按产品定义重新反查代码和主流程，发现并修复：

| 问题 | 原因 | 修复 |
|---|---|---|
| `visual_text_delivery_summary` 同时是 final builder 输入和输出 | 把下游计算结果误列为上游必填，形成循环依赖 | 从输入必填删除，明确由 final builder 根据 plan、gate、asset set 计算 |
| prompt-only 封面被要求提供 output asset / path | generated 与 prompt-only 共用全局必填字段 | 拆成 composition_ready、prompt_only、preview evidence 三套条件必填 |
| 平台包装只检查 review_pass | 视觉文字、图片追溯和 HTML 准备状态可能在包装层丢失 | 增加 visual text / asset lineage 和 gate 必填，并贯穿 package input、package、delivery record |
| R3 tutorial 仍由 talking-head-image-pip 代执行内部阶段 | 样例未随 Skill 拆分迁移 | trace 改为 static visual director、prompt compiler、asset producer 三段执行；原子规划统一到 05-visual-plan.md |
| tutorial 缺 platform_package_input | 回放只检查文件存在，未检查完整主链 | 新增 07-platform-package-input.md，并修正 review -> package -> cover -> final 路由 |
| checker 只查关键词 | 无法发现 ID 断链、next_skill 错误和条件字段冲突 | `validate-r3-visual-text.ps1` 增加合同所有权、lineage、路由、trace 和最终 HTML 数据流检查 |

复审验证：专项 checker、字段 schema、route、final template、cover checker、八个 Skill quick_validate 均通过；正确 run 根目录只读回放 12 步通过、0 warning、链接断链 0。一次把教程外层目录交给 `validate-sample-run` 的误调用被归类为 `checker_invocation_error`，不计入 workflow 缺陷。

---

## 1. 编译范围

本轮按 R3-C01 到 R3-C25 编译以下承载文件：

| 文件 | 编译内容 |
|---|---|
| `交接物字段词典.md` | 新增 `image_generation_record`、`image_metadata_sidecar`；扩展 `visual_plan`、`quality_review`、`image_asset_set`、`final_delivery` |
| `docs/reference/R3-图片资产执行规范.md` | 新增 R3 运行时真源：资产链、状态边界、操作合同、样本模式、R3CHK |
| `docs/reference/文档治理与目录规范.md` | 增加 `assets/images/generation-records/`、`assets/images/metadata/` 和 R3 图片资产摆放规则 |
| `docs/reference/skill执行透明度与成熟度规范.md` | 增加 R3 execution trace 字段和 R3CHK-001 到 R3CHK-015 |
| `skills/talking-head-image-pip/SKILL.md` / `CONTRACT.md` | 从视觉提示词升级为 `visual_plan + image_prompt_set + image_generation_record + image_asset_set` 资产生产 |
| `skills/copywriting-quality-review/SKILL.md` / `CONTRACT.md` | 增加图片资产链质检：generation_record、sidecar、状态诚实、HTML 嵌入准备 |
| `skills/final-delivery-builder/SKILL.md` / `CONTRACT.md` | 增加 `html_embed_manifest`、R3 状态展示、sidecar 检查、导出包 sources |
| `docs/tutorials/r3-dry-run-sample/README.md` | 新增 R3 最小图片资产链 dry-run 模板 |
| `README.md` / `PROJECT_MAP.md` / `AGENTS.md` | 增加 R3 reference、dry-run 和状态枚举入口 |

---

## 1.1 R3-C26 到 R3-C45 追加编译

2026-07-10 按用户确认的 R3 静态视觉编导、封面设计、图片类型和环境生产路径，追加编译以下内容：

| 文件 | 追加编译内容 |
|---|---|
| `交接物字段词典.md` | 新增 `static_visual_director_plan`、`cover_design_package`、`static_visual_quality_gate`、`cover_quality_gate`、`asset_trace_quality_gate`、`cover_variant_set`；补 `image_asset_type`、`image_production_path`、`image_generation_decision`、`prompt_delivery_mode`、`external_model_payload_path` |
| `docs/reference/R3-图片资产执行规范.md` | 资产链升级为 `draft -> static_visual_director_plan -> visual_plan -> image_prompt_set -> image_generation_record -> image_asset_set -> image_quality_gate -> cover_design_package -> html_embed_manifest -> final_delivery`；新增 R3CHK-016 到 R3CHK-022 |
| `skills/talking-head-image-pip/SKILL.md` / `CONTRACT.md` | 编译静态视觉编导层、图片类型二分、Codex 直出 / Seedream prompt 交付路径 |
| `skills/copywriting-quality-review/SKILL.md` / `CONTRACT.md` | 编译 `static_visual_quality_gate_status`、`cover_quality_gate_status`、`asset_trace_quality_gate_status`，拦截内容语言图片、无封面设计和路径混用 |
| `skills/platform-packaging-adapter/SKILL.md` / `CONTRACT.md` | 编译 `cover_design_package` 和 `cover_variant_set`，区分封面标题、视频标题和封面图设计 |
| `skills/final-delivery-builder/SKILL.md` / `CONTRACT.md` | 最终 HTML 增加封面设计包展示要求，区分 `picture_in_picture_image` 和 `cover_image` |
| `skills/propagation-router/SKILL.md` | 总控能力提示补 `image_asset_type` 和 `image_production_path`，但不承担 R3 生产职责 |
| `templates/final-delivery/final-delivery.template.html` | 增加 `SECTION: cover_design`、`cover_design_package_id`、图片类型和生产路径枚举 |
| `tools/validate-final-delivery-template.ps1` | 模板检查新增封面设计区、`image_asset_type`、`image_production_path` 和 `cover_design_package_id` |

本次明确不编译：

```text
发布后数据回流 / post_publish_feedback_gate。
Seedream API 调用。
短视频剪辑、动态 storyboard 或视频生成。
自动发布、平台登录、平台后台数据采集。
```

## 1.2 R3-C46 到 R3-C53 编译结果

2026-07-11 用户确认后完成封面成品合成合同编译：

```text
新增对象：cover_composition。
扩展对象：image_asset_set、cover_design_package、cover_quality_gate、html_embed_manifest、final_delivery。
统一字段：cover_text_render_strategy、cover_composition_status。
新增策略：cover_asset_role、platform_cover_strategy。
新增 skill：cover-design-compiler。
```

| 承载 | 编译结果 |
|---|---|
| `交接物字段词典.md` | 注册 cover_composition、cover_asset_role、platform_cover_strategy、cover_quality_gate 和 cover_embeds；迁移旧同义字段 |
| `skills/cover-design-compiler/` | 新增 SKILL、CONTRACT、agents metadata 和确定性封面合成脚本 |
| `talking-head-image-pip` | 只产画中画和 cover_background_asset，不冒充成品 |
| `platform-packaging-adapter` | 只产平台标题、策略和 cover_variant_set，自动进入 cover-design-compiler |
| `copywriting-quality-review` | 拆成 content_visual_review / cover_review 两种模式 |
| `final-delivery-builder` | 消费 cover composition / gate，区分底图、成品、平台变体和 prompt_only |
| HTML 模板 | 增加平台策略、成品下载、底图追溯、prompt_only 和封面局部返工 |
| checker / CI | 新增 `validate-cover-composition.ps1`，接入 CI 和 public release validator P3REL-013 |
| 脱敏样例 | R3 dry-run 增加 platform package、cover composition、cover review 和 cover embeds |

编译中发现并修正：

```text
1. cover_variant_set 旧字段依赖下游 cover_design_package_id，形成循环；改为引用上游 package_id。
2. compose-cover.ps1 绝对输出路径归一化顺序错误；修正后 1080x1440 中文封面冒烟测试通过。
3. validate-cover-composition.ps1 的诊断输出污染整数返回值；改为分离诊断与计数。
4. `.gitignore` 的 `accounts/` 未锚定，误吞 `docs/tutorials/**/accounts/` 新样例；改为 `/accounts/`，继续隔离根目录真实账号，同时允许脱敏 tutorial 入库。
5. public build 白名单漏掉 `validate-field-schema.ps1` 的 `YamlHelper.ps1` 依赖；已纳入公开包构建清单。
6. cover checker 使用 `exit` 导致 public release 父检查器提前结束；改为设置 LASTEXITCODE 后 return，支持独立和嵌套调用。
7. checker 默认报告散落根目录；统一将项目级维护报告写入 `state/checks/`。
8. public build 清理路径只校验项目根前缀，存在误清理风险；收紧为只能读写 `releases/` 子目录。
9. public build 会复制本地 `state/checks/`；改为明确排除，zip 泄漏检查为 0。
10. YamlHelper fallback 会错误嵌套并列顶层对象；改为递归缩进解析，并通过 map、数组和对象数组测试。
11. 根目录工作流状态记录会把真实账号/session 带入 GitHub Source code zip；改为本地私有文件，公开 Git 只保存脱敏模板。
```

验证结果：

```text
skill quick_validate：pass
compose-cover.ps1 smoke test：pass（1080x1440 PNG）
validate-final-delivery-template：pass
validate-cover-composition：pass
validate-field-schema：pass
validate-build-profile(dev)：pass
validate-workflow-replay(R3 dry-run)：pass
validate-ci-workflow：pass
validate-route-schema：pass
temporary public_release build：pass
validate-public-release：pass（P3REL-013=pass，必备新文件缺失 0）
```

---

## 2. 成熟项目对标

本轮参考成熟开源 / 开放文档项目，得到以下审计标准：

| 参考对象 | 关键做法 | 对 R3 的检查 |
|---|---|---|
| ComfyUI | 生成图保留 workflow metadata，也支持 JSON workflow 独立保存 | R3 必须有 metadata sidecar，不能只依赖图片文件自身 metadata |
| MLflow Tracking | run 记录参数、时间、元数据和 artifacts | R3 必须有 image_generation_record，不把 prompt 当作生成记录 |
| MLflow Artifact Store | artifacts 和 metadata 分层存储 | R3 必须区分 image file、generation record、sidecar、HTML 展示 |
| DVC | 用小 metafile 管大资产版本，避免把大文件直接塞进 Git 事实源 | R3 image_asset_set 是索引，图片文件和 sidecar 是资产，重做不能覆盖 |
| W&B Tables | 用表格行记录图片、预测、标签等结构化字段 | R3 image_asset_set 必须像资产表，按行记录每张图状态、路径和追溯 |

对标后判断：

```text
R3 当前产品和 skill 编译方向基本对齐成熟项目的“run + artifact + metadata + manifest”模式。
当前已具备文档合同、Skill、checker、脱敏 dry-run 和公开包静态验证；仍需外部 tester 和真实账号综合大循环证明不同 AI 环境下的稳定执行质量。
```

参考来源：

```text
ComfyUI Workflow：https://docs.comfy.org/development/core-concepts/workflow
MLflow Tracking：https://mlflow.org/docs/latest/ml/tracking/
MLflow Artifact Store：https://mlflow.org/docs/latest/self-hosting/architecture/artifact-store/
DVC Versioning Data and Models：https://doc.dvc.org/example-scenarios/versioning-data-and-models
W&B Tables：https://docs.wandb.ai/models/track/log/log-tables
```

---

## 3. 编译后审计

### 3.1 冲突

已修正：

| 冲突 | 修正 |
|---|---|
| `image_assets_status = generated` 旧整组状态和 R3 新枚举冲突 | 改为 `all_generated / partially_generated / pending_external / generation_failed / manual_required / mixed / not_required` |
| `image_asset_manifest` 旧叫法和 `image_asset_set` 标准名冲突 | 规则文档统一为 `image_asset_set` |
| `talking-head-image-pip` 合同标题 0.3.0，正文身份块仍为 0.1.0 | 统一为 0.3.0 |
| final-delivery 只检查图片文件，不检查 sidecar / generation_record | 增加 R3 asset delivery runtime |

保留：

```text
R1 / R2 runtime 块仍保留在 SKILL.md 中，作为兼容历史合同的运行说明，不判定为 R3 冲突。
历史 session 里旧的 `image_assets_status：generated` 不改写；它们是旧样本事实记录，不作为新规则。
```

### 3.2 冗余

有意保留的重复：

```text
R3 产品文档：给人确认。
R3 reference：给 skill 编译和执行。
SKILL.md：给运行时读。
CONTRACT.md：给编译和审计读。
dry-run sample：给验证读。
```

需要后续注意：

```text
R3CHK 同时出现在 reference 和透明度规范中，属于真源 + 检查入口的重复；后续如脚本化 validator，应以 `docs/reference/R3-图片资产执行规范.md` 为主。
```

### 3.3 流畅度

当前流转：

```text
talking-head-image-pip
-> copywriting-quality-review
-> platform-packaging-adapter
-> final-delivery-builder
```

R3 插入点：

```text
talking-head-image-pip 负责生产图片资产链。
copywriting-quality-review 负责检查图片资产链是否能通过。
final-delivery-builder 负责展示和导出，不成为图片事实源。
```

该分工清楚，未发现需要新增独立 skill 的必要。图片生成外部 provider 暂不实现，仍保留为降级字段。

### 3.4 完整性

已覆盖：

```text
视觉预算。
required / optional 图片数量。
retention_task。
insert_after_text / insert_before_text。
完整 prompt_card。
image_generation_record。
image_asset_set。
metadata_sidecar。
状态诚实。
HTML 嵌入 manifest。
多篇 child session 隔离。
execution_trace 记录来源。
不接外部 API。
```

已补做：

```text
R3 dry-run pending_external 最小样本。
样本路径：docs/tutorials/r3-dry-run-sample/accounts/sample-account/runs/SR3DR-001/
验证结果：必需文件缺失 0，R3DR 检查失败 0，final-delivery.html 本地链接断链 0。
验证链路：visual_plan -> image_prompt_set -> image_generation_record -> image_asset_set(pending_external) -> html_embed_manifest -> final-delivery.html。
```

当前未完成：

```text
未实现 Seedream / 外部 provider adapter。
未重跑真实账号的 Codex 出图 -> deterministic overlay -> cover_review -> final HTML 综合链路。
未完成外部 tester 对不同 AI 环境的可执行性验证。
未实现自动发布、平台登录或发布后数据回流；这些仍在产品边界外。
```

### 3.5 优雅度

当前设计保持轻量：

```text
不用 workflow engine。
不用图片服务。
不用数据库。
不用外部 API。
用字段词典 + reference + skill 合同 + dry-run 模板承接。
```

这个取舍适合当前开源 alpha 前阶段。若未来要上升到 L4，可再考虑 validator 脚本和 provider adapter。

---

## 4. 下一步

### 4.1 原始方法论 / 产品层 / Skill 编译复核

本轮按用户要求，重新对照：

```text
原始方法论：docs/explanation/工作流问题包与产品设计草案-20260706.md
最终交付说明：docs/explanation/最终交付页与图片降级策略.md
R3 产品层：docs/product/R3-产品总览.md、docs/product/R3-画中画与图片资产模型.md、docs/product/R3-产品确认清单.md
R3 编译层：docs/reference/R3-图片资产执行规范.md、talking-head-image-pip / copywriting-quality-review / final-delivery-builder 及 CONTRACT
```

结论：

```text
未发现硬冲突。
```

可接受差异：

| 差异 | 判断 |
|---|---|
| 原始方法论强调“画中画不是固定几张图”；R3 增加默认视觉预算 | 不冲突。R3 的预算是默认起点，最终仍由留存风险、留人任务、信息密度和增减理由决定 |
| 原始问题包批评“每篇只做 1 张主图”；R3 dry-run sample 允许最小样本只验证 1 张 required 图 | 不冲突。dry-run 是最小资产链验证，正式内容仍必须按视觉预算和 required_visuals 执行 |
| 最终交付说明要求进入最终交付前尝试生成必要图片；R3 允许 pending_external / generation_failed / manual_required | 不冲突。R3 只是把失败和无能力环境显式降级，不允许把 prompt 或占位冒充 generated 图片 |
| 原始旁路策略暂不接 Seedream；R3 增加 provider_mode、input_payload、fallback 状态 | 不冲突。R3 只定义兼容字段，不实现外部图片 API，不保存 key |

口径补齐：

```text
README.md 已把 talking-head-image-pip、copywriting-quality-review、final-delivery-builder 的说明更新为 R3 图片资产链口径。
PROJECT_MAP.md 已把三个 CONTRACT 从“合同草案”更新为 R3 已确认运行合同口径。
AGENTS.md 的“做画中画”读入清单已补入 docs/reference/R3-图片资产执行规范.md。
```

索引检查：

```text
已扫描根目录、docs/ 和 skills/ 下的 Markdown。
在排除账号真实产物、外部资料和 tutorial 包内部子文件后，未发现未被 README.md 或 PROJECT_MAP.md 覆盖的孤岛 Markdown。
```

---

## 5. 下一步

建议顺序：

```text
1. 用真实内容做一次 Codex 底图 -> deterministic overlay -> cover_review -> final HTML 综合回归。
2. 收集外部 tester support log，验证非 Codex prompt_only 路径是否容易理解和执行。
3. 后续再决定是否实现 Seedream adapter；当前只保持统一提示词和 payload 合同。
```

---

## 6. 2026-07-12 产品二次开发与重新编译

用户已确认 R3-C71 到 R3-C80：画中画数量改为文案视觉需求分析的派生结果，允许 0 到 N 张、不设上限；Codex 内置 Image 2 对所有通过任务直接生成，不设置成本或调用次数门禁。

因此，本文件前文关于“默认视觉预算、required / optional 数量、按时长起步、增减理由”的记录只说明旧版本曾经如何编译，不再代表当前产品真源。以下旧 sink 已完成迁移，旧文件只保留 history-only compatibility：

```text
交接物字段词典中的 visual_budget 合同。
docs/reference/R3-图片资产执行规范.md 的时长预算与 required / optional 规则。
static-visual-director / talking-head-image-pip / image-prompt-compiler / image-asset-producer 相关合同。
templates/schema/r3/visual-budget.v0.1.schema.json。
tools/R3VisualBudget.ps1、validate-r3-visual-budget.ps1 及对应 fixtures。
H6 preflight 中 3 张画中画、最多 4 次调用和 cost gate 的当前判定。
```

保留有效且不得回滚的部分：完整 prompt 与 digest、封面和画中画分账、生成记录、sidecar、资产不可覆盖、来源绑定、视觉文字与字幕分轨、质量门禁、H5 数量从 provenance 派生而非 checker 魔法常量。

现行实现为 `visual_need_analysis -> accepted_visual_tasks -> derived_visual_count -> automatic prompt compile / Image 2 dispatch`，包含 17 个正反产品 fixture 和 8 个跨层 sink 检查；现行专项 checker 为 `tools/validate-r3-visual-need.ps1`。旧 `validate-r3-visual-budget.ps1` 只验证 7 项历史兼容。

H6 preflight 已移除 cost / call limit，旧 4 条 prompt 只标 baseline evidence；下一步从 H6A 生成真实 visual_need_analysis，pass 后自动接续 H6B。旧 3 张 PIP prompt 不能绕过新分析直接继承为 accepted。

## 7. P0-H6 真实编译与综合回归

`PRIVATE-H6-H7-REGRESSION` 已完成 H6A-D：8 个 visual need accepted task 自动派发给内置 Image 2，实际生成 8 次，选中 8 张 PIP，确定性派生 3 张平台封面；typed render input、最终 HTML、lineage、projection 和 resume 已闭合。专项 checker 当前 30/30，结果 `pass_with_warnings`。

本轮新增 `complete-p0-h6-regression.ps1` 与 `validate-p0-h6-regression.ps1`，并把同 session 最新 pending revision 选择写入 runtime / H2 fixture。`compose-visual-text.ps1` 新增三分栏锚点；`talking-head-image-pip` 明确审美偏好只在首轮生成后返工。当前运行模型 profile 不可观察，发布和真实传播效果未测试。

## 8. R3-C81-C90 防复发编译

H6 coordinator 现分 `self_test / prepare / finalize`：completed prepare 只能 `skipped_completed`，finalize 必须在 checker、projection、resume、receipt 和 HTML digest 闭合后写状态。H6 validator 已改为只读，数量从当前 analysis / selection 派生，并新增 candidate/render-input digest 检查。

图片生成记录补入 provider outcome、postprocess、reconciliation 与中断恢复策略；overlay 生成 layout sidecar，视觉文字 checker 实际执行三分栏 smoke。`runtime_smoke_gate` 同时执行全量 PowerShell parser、H6 self-test 和 overlay fixture。AGENTS / state-and-gates 已同步单调状态、checker purity、reconcile-first、动态 cardinality 和 parser+execution 双门禁。

## 9. P0-H7 最终交付工作台编译

P0-H7-C01 到 C15 已编译为 `p0-contract-bundle-v0.3`：新增 plan / typed input schema v0.3、delivery revision renderer、发布执行工作台模板、公开 fixture、跨产物语义 checker、显式状态 finalizer 和 H6→H7 迁移工具。v0.2 保留历史复现，不原地改写。

真实 `PRIVATE-H6-H7-REGRESSION` 复用 H6 已验证的 8 张画中画，没有新增 Image 2 调用；按 4 个平台发布单元重新合成 3 张封面，并从同一 `DREV-PRIVATE-H6-H7-002` 生成 HTML、最终文案、视觉方案、平台包和交付记录。专项语义门禁 20/20，结果 `pass_with_warnings`；warning 来自复用内容 / 研究、观点隐喻、合成 UI 证据边界和未发布范围，不是结构失败。

编译中实际发现并修复：plan schema 未同步升级、PowerShell `$Input` 自动变量冲突、嵌套脚本错误读取未设置 `$LASTEXITCODE`、真实 selection 字段名漂移、warning union 被 card 内部代码污染、checker 把正文边界误当路径、模板变化错误命中旧幂等结果、桌面卡片横向溢出。对应规则已回写字段词典、Skill / CONTRACT、fixture、gate、公开包 P3REL-025 和 AGENTS。

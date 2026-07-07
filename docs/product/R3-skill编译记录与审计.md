# R3 Skill 编译记录与审计

> 状态：r3_compiled_static_audited_and_pending_external_dry_run_pass  
> 所属路线：R3 画中画与图片资产模型  
> 主责：记录 R3 产品确认后实际编译了哪些规则、skill、合同、样本模板，以及编译后对标成熟开源项目的审计结论。  
> 边界：本记录不代表完整真实测试通过，不代表 R3 达到 L3 candidate；R3 已完成 pending_external 最小 dry-run，真实出图路径仍未验证。

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
但当前只是文档合同和静态规则，尚未通过 dry-run 证明另一个 AI 能稳定执行。
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

未完成：

```text
未做真实图片样本。
未验证 generated 图片文件与 metadata sidecar。
未实现 validator 脚本。
未实现 Seedream / 外部 provider adapter。
未生成开源 examples/sample-run。
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
1. 如需继续加固 R3，补 generated 路径 sample：真实图片文件 + metadata sidecar + checksum。
2. 进入 R4 产品开发：做 GitHub 开源上线包、样例、净化和贡献规范。
3. 后续补 R3 validator 草案，把 R3DR / R3CHK 检查项脚本化。
```

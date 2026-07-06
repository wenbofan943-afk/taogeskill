# PROJECT MAP

> 状态：项目导航图  
> 主责：让人和 AI 快速知道“规则在哪、账号在哪、产物在哪、索引在哪”。  
> 边界：本文件只做导航，不保存具体内容正文。

---

## 入口顺序

```text
README.md
-> AGENTS.md
-> STATUS.md
-> docs/reference/文档治理与目录规范.md
-> docs/reference/人类引导与任务后导航规范.md
-> 交接物字段词典.md
-> 工作流状态记录.md
```

继续某条内容时：

```text
工作流状态记录.md
-> current_artifact
-> accounts/{account_slug}/runs/{session_id}/manifest.yaml
-> 对应 intermediate 或 deliverables 文件
```

---

## 顶层目录

| 目录 / 文件 | 用途 | 谁主要看 |
|---|---|---|
| `README.md` | 项目总入口、边界、索引 | 人 + AI |
| `AGENTS.md` | AI 执行约定、门禁、路由 | AI |
| `STATUS.md` | 项目状态卡 | 人 + AI |
| `docs/reference/` | 字段、目录、状态、契约 | AI |
| `docs/explanation/` | 方法论和设计解释 | 人 |
| `docs/product/` | 产品路线图、开源上线前修复排序、能力边界 | 人 + AI |
| `docs/how-to/` | 操作流程 | 人 + AI |
| `docs/tutorials/` | 示例教程 | 人 |
| `skills/` | 可执行 skill 合集 | AI |
| `objects/` | 产品对象和活动对象 | AI |
| `accounts/` | 账号档案和账号内容产物 | 人 + AI |
| `indexes/` | 跨账号汇总索引 | 人 + AI |
| `外部资料/` | 第三方方法论参考 | 人 + AI |

---

## 核心原则

```text
根目录不放单条内容正文。
账号目录隔离账号身份。
session 目录隔离单轮内容。
intermediate 放中间产物。
deliverables 放最终交付物。
final-delivery.html 是人类验收入口。
export/ 是可转交交付包。
manifest.yaml 做机器可读索引。
indexes/ 只做跨账号检索，不当正文来源。
```

## 设计说明

| 文件 | 用途 |
|---|---|
| `docs/reference/人类引导与任务后导航规范.md` | 规定任务前路由、任务后导航、自动推进和人类停顿点，避免让用户猜下一步 |
| `docs/reference/skill执行透明度与成熟度规范.md` | 记录 skill 独立能力、agent 扶跑痕迹、成熟度等级和发布前风险 |
| `docs/reference/版本治理与Git边界.md` | 规定本地工作母仓、Portable Git 入口、入库范围、排除范围和公开 GitHub 净化规则 |
| `docs/explanation/最终交付页与图片降级策略.md` | 说明最终 HTML 交付页、图片资产、Codex 内置出图和未来 Seedream 等外部模型降级旁路的关系 |
| `docs/explanation/工作流工程缺陷复盘与修订方案.md` | 记录 S20260706-001 暴露出的交付工程缺陷，以及 project_local / portable_bundle / standalone_html 的修订方案 |
| `docs/explanation/工作流问题包与产品设计草案-20260706.md` | 汇总真实运行暴露的 17 个 workflow 问题，作为 skill 编译、多分支、画中画资产和 validator 的产品设计输入 |
| `docs/product/GitHub开源上线前Workflow修复路线图.md` | 按产品开发逻辑拆解 17 个问题、成熟 workflow 解法、本项目应做到的程度和 GitHub 开源上线前修复排序 |

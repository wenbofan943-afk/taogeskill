# 涛哥创作工作流 STATUS

> 当前状态卡。历史讨论不写成长流水；有价值的过程进入对应记录文件。

---

## 当前阶段

```text
project_stage：workflow_stabilization
workflow_usage_state：workflow_testing
状态说明：已从公开互动分析工具项目传播研究目录提升为独立项目；已完成真实内容测试后的问题包沉淀，并形成 GitHub 开源上线前 workflow 修复路线图；下一步进入 skill 合同、运行模型、画中画资产合同和开源检查清单设计
当前位置：D:\OpenClaw\workspace\涛哥创作工作流
Git：已初始化独立本地工作母仓，当前分支 `main`；默认 Git 入口为 `D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe`；已获涛哥确认建立初始基线；公开 GitHub 前必须先生成净化发布包
```

---

## 当前能力

已具备：

```text
账号档案
产品/活动对象档案规则
热点搜索来源池
调研运行记录
热点候选池
热点评分表
自媒体选题库
内容 Brief 记录
口播草案 skill
画中画提示词 skill
图片资产与最终 HTML 交付页规范
项目内交付页 / 可转交包 / 单文件 HTML 的边界规范
人类引导与任务后导航规范
文案与视觉联合质检 skill
多平台分发包装 skill
内容交付记录
最终交付页构建 skill
工作流状态记录
```

---

## 当前边界

```text
不做自动发布。
不登录平台后台。
不自动评论、私信或互动。
不改公开互动分析工具客户端、服务器、数据库、license、积分或发版链路。
不替代短视频创作 SaaS 的正式工程实现。
```

---

## 当前待办

1. 跑一条真实内容，验证 `account_profile -> product_profile -> research_run_record -> content_delivery_record` 全链路是否顺。
2. 验证 `research_run_id` 是否能贯穿选题、Brief、草案、画中画、质检、分发包和交付记录。
3. 验证 `product_profile / campaign_profile` 是否能约束热点、文案和平台包装，不再硬编码单一产品。
4. 独立本地 Git 仓库接入后，由涛哥确认初始基线文件、首个 commit 和后续公开 GitHub 净化包范围。
5. 用第二条真实内容验证“选题确认 -> Brief -> 口播 -> 画中画 -> 质检 -> 平台包装 -> 确认采用 -> 最终 HTML”的自动衔接，确保不再要求用户说“继续写口播 / 继续做分发包”。
6. 后续调研 Seedream 4.0 / 5.0 等外部图片模型旁路；当前只保留降级策略说明，不实现 API。
7. 后续补 `portable_bundle` 导出模板，生成 `export-manifest.json`、`assets/`、`sources/`，解决 HTML 离开项目目录后断链的问题。
8. 后续评估是否需要 `standalone_html` 单文件导出，适配只想转发一个文件的场景。
9. 基于 [工作流问题包与产品设计草案](./docs/explanation/工作流问题包与产品设计草案-20260706.md) 和 [GitHub 开源上线前 Workflow 修复路线图](./docs/product/GitHub开源上线前Workflow修复路线图.md)，设计 skill 合同、运行模型与分支封锁、画中画资产合同和 GitHub 开源上线检查清单；当前只做产品设计，不改代码。
10. Git 已初始化为本地工作母仓；本轮已获涛哥确认建立初始基线 commit；后续公开 GitHub 仍需先做净化发布包。

---

## 编排测试验收标准

一轮真实内容测试通过，必须同时满足：

```text
账号档案 P0 齐全。
产品/活动对象边界齐全。
调研运行记录有来源、时间、热度信号和风险说明。
选题卡通过 Topic Gate，并由涛哥选择。
Brief、口播草案、画中画方案、图片资产状态、联合质检、分发包装输入包、多平台分发包字段完整。
最终交付页 `deliverables/final-delivery.html` 能让人类直接阅读、复制文字、下载图片，并能跳转到 Markdown 追溯文件。
如果要转交给项目外的人，必须生成 `deliverables/export/{session_id}/` 或 `standalone_html`，不能把 `project_local` 页面单独当成可转交包。
research_run_id 没有断链。
内容交付记录给出清楚的人类处理选项。
工作流状态记录能让下一轮恢复。
没有把草案误写成已发布、最终验收通过或正式产品规则。
```

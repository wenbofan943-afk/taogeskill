# 涛哥创作工作流

给中文内容创作者使用的 AI 内容工作流 Skill。它把选题调研、内容 Brief、口播文案、视觉任务、内容质检、多平台发布物料和最终 HTML 交付页串成一条可接续的工作流。

适合：懂一点 AI / Codex / GitHub，想把内容生产流程沉淀下来的人。下载后把项目文件夹交给 Codex 或其他能读本地文件的 AI，再按快速开始对话即可；不需要先写代码。

公开搜索关键词：`taogeskill`

最新版下载：[v0.1.0-alpha.6 GitHub Release](https://github.com/wenbofan943-afk/taogeskill/releases/tag/v0.1.0-alpha.6)

> Alpha 预发行提醒：当前公开包是 `0.1.0-alpha.6` GitHub 预发行版本，不是生产级自动化 runner。它不能自动发布内容、登录平台、互动评论 / 私信，也不能证明真实传播效果。当前 Windows 正式兼容基线是系统自带的 Windows PowerShell 5.1；PowerShell 7 不属于当前公开承诺。它已完成单篇真实内容生产、H7 最终交付和 R5 账号身份 / 热点雷达合同闭环；当前源码又完成 R6 直供文案与来源证据画中画的本地编译，但尚未发布新的 GitHub Release。外部 tester 验收仍待后续完成。

---

## 你会得到什么

输入一句：

```text
使用涛哥创作工作流，帮我做一条内容。
```

正常一轮会产出：

| 产物 | 用途 |
|---|---|
| 账号档案 / 产品对象检查 | 防止换账号后串台，把张三说成李四 |
| 选题卡 | 给出候选选题、切口、热点来源和推荐理由 |
| 内容 Brief | 明确内容目标、受众、观点、证据和转化路径 |
| 口播文案 | 面向短视频 / 图文脚本的正式文案 |
| 视觉任务与封面 | 文案视觉需求分析决定 0 到 N 张；Codex 环境可直接生成，其他环境交付统一提示词和版式 |
| 联合质检 | 检查 Hook、信息密度、可信度、广告味、平台风险 |
| 多平台发布物料 | 抖音 / 视频号 / 小红书等平台标题、简介、话题和包装建议 |
| 最终 HTML 交付页 | 文案好复制、图片好下载、段落可追溯到 Markdown 交接物 |

## 快速开始

推荐从这句话开始：

```text
使用涛哥创作工作流，帮我做一条内容。
```

不想先建账号，只想试用，可以说：

```text
先跑一个 sample，让我看看它怎么工作。
```

| 场景 | 工作流会做什么 |
|---|---|
| 第一次使用 / 没有账号 | 进入账号建档引导，用口语问题创建账号档案草案 |
| 只想先试用 | 使用脱敏 sample，不创建真实账号 |
| 已有账号 | 先摘要账号档案，请你确认账号定位没有偏移 |
| 换账号 | 先做账号身份对齐，再进入产品 / 活动对象检查 |
| 接着上次 | 读取状态、manifest、trace 和 checkpoint，说明可恢复位置 |
| 只想检查 | 进入只读 checker，只报告问题，不自动修改 |
| 问能不能出画中画 | 先判断当前环境；可出图时生成，否则交付提示词与插入位置 |

完成最终 HTML 后，也可以直接说：

```text
只改抖音标题。
回到口播改前 5 秒。
画中画再加一张“信任对比”的图。
导出转交包。
```

## 安装、更新与验证

- [INSTALL.md](./INSTALL.md)：安装与启动。
- [UPDATE.md](./UPDATE.md)：更新时如何保护本地私有账号和生产 runs。
- [Release Notes](./RELEASE_NOTES.md)：当前 Alpha 的变化、已验证范围与未验证范围。
- [公开样例](./examples/README.md)：不含真实账号数据的试用入口。
- [验证工具](./tools/README.md)：本地检查器、Windows clean-room 与公开包校验说明。

默认只导出排查日志，不包含完整文案、最终 HTML、图片和账号隐私。见[导出反馈日志包](./docs/how-to/export-support-log.md)。请勿把真实账号档案、生产 runs 或密钥提交到公开 issue。

## 边界与反馈

- 本项目是轻量、单篇内容 workflow，不是自动发布平台或完整内容生产 SaaS。
- 真实账号资料、真实 runs、图片和本地状态属于私有生产区；公开仓只保留脱敏样例。
- 安全、隐私、密钥问题先读 [SECURITY.md](./SECURITY.md)，不要在公开 issue 中粘贴敏感数据。
- 使用问题、功能建议、样例跑不通：优先提交 GitHub Issue；小范围试用交流见 [CONTACT.md](./CONTACT.md)。

## 深入阅读

<!-- ai-reading-boundary -->
> AI 阅读边界：普通内容任务读到这里后，应转入 Docs Index、PROJECT_MAP 和对应 task route；不应把本首页当作产品合同或历史路线图。

- [Docs Index](./docs/README.md)：按 product / reference / governance / explanation / how-to / tutorial 分区阅读。
- [PROJECT_MAP.md](./PROJECT_MAP.md)：项目导航图，说明规则、账号、产物和索引的位置。
- [AGENTS.md](./AGENTS.md)：项目级 AI 驾驭工程约定；用户说“按 AGENTS”时的入口。
- [Agent Orchestration](./docs/governance/agent-orchestration/README.md)：任务路由、必读清单、构建 profile、状态门禁与失败收口。
- [STATUS.md](./STATUS.md)：当前阶段、能力边界和待办。
- [Product Docs](./docs/product/README.md)：当前产品定义、确认清单和编译记录。
- [Reference Docs](./docs/reference/README.md)：字段、目录、执行与检查规范。
- [Skills Index](./skills/README.md)：可执行 skill 入口和合同。
- [Templates Index](./templates/README.md)：账号、交付、状态和检查模板。
- [CHANGELOG.md](./CHANGELOG.md)、[NOTICE.md](./NOTICE.md)：版本变化、开源边界与外部方法论鸣谢。

## 致谢

本项目的部分内容工作流设计、skill 拆分思路和内容质检意识受到 `dbskill` 启发；感谢其对中文内容创作和 AI 写作质检工程化的探索。完整边界见 [NOTICE.md](./NOTICE.md)。

# 涛哥创作工作流 STATUS

> 当前状态卡。历史讨论不写成长流水；有价值的过程进入对应记录文件。

---

## 当前阶段

```text
project_stage：workflow_stabilization
workflow_usage_state：v0.1.0-alpha.4_github_prerelease_published
状态说明：R1-R4 既有范围和 P0-H1 至 H7 已完成当前产品 / Skill 编译；`0.1.0-alpha.4` 已作为 GitHub alpha prerelease 发布。它包含 argv、共享 runtime helper、environment/path preflight、archive integrity、12-case clean-room matrix、扩展 Windows 认证、安装说明、兼容报告和真实单篇内容生产 H7 验证；当前仍是 alpha、单篇 runtime，不是生产级自动化 runner。R5-H1 已将账号视觉身份 / 栏目模板的表达合同编译完成：它约束视觉表达但不决定图片数量，图片仍由 R3 内容视觉需求分析得出 0 到 N 张。本机 Windows PowerShell 5.1 六格 clean-room 复测通过；本机未安装 PowerShell 7，六格如实为 `not_tested`，不影响 H1 合同完成但不构成该 commit 的完整双宿主认证。
当前产品门禁：本地 full matrix 12/12、双宿主 public validator、版本合同和 H7 fixtures 通过；GitHub-hosted Server 2022/2025 与 Windows 11 ARM64 在发布 commit 上通过，loopback SMB/UNC 12/12；Release ZIP、GitHub Source ZIP 与公开 tag 已完成隐私审计。OneDrive、大小写敏感 NTFS、企业 Group Policy 和 non-NTFS 继续作为缺基础设施的已知边界，不阻断 alpha。
当前位置：`<PROJECT_ROOT>`（由当前 Git 工作树解析，本机绝对路径不进入公开源码）
Git：已初始化独立本地工作母仓，当前分支 `main`；无凭据 HTTPS 远端为 `https://github.com/wenbofan943-afk/taogeskill.git`；当前已发布 tag 为 `v0.1.0-alpha.4`；Git 入口由执行环境解析为 `<GIT_EXE>`
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
首次账号建档引导 skill
工作流状态记录
反馈日志包导出
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

## 当前剩余事项

1. 外部 tester 独立安装和试跑仍是 beta / stable 的后续门禁，不阻断已发布的 alpha.4。
2. 长期增强保留为非阻断 backlog：自治 runner、图片质量自动判断、外部图片模型旁路、发布效果回流和缺基础设施的环境轴认证。
3. R5 后续按已确认路线继续：H2 编译账号驱动的二手车优先雷达政策、词库与扩词反馈合同；H1 不含真实品牌资产或外部热点采集实现。

---

## 已完成里程碑

1. P0-H2 已把轻量 runtime 迁入 v0.2：`invoke-workflow-runtime.ps1` 能按版本分流，确定性执行 `compile_render_input -> render_final_delivery`，写 append-only event、render input / final_delivery lineage、artifact checks 和 render receipt；旧 v0.1 runtime 保持只读兼容。
2. P0-H1 至 P0-H7 已形成单篇确定性运行链。H6 在 `PRIVATE-H6-H7-REGRESSION` 产生 8 个 accepted、8 张 PIP 和 3 张派生封面；H7 复用这些已验证图片，按当前平台标题重新合成封面并建立唯一 delivery revision。脱敏 H7 fixture 10/10、真实语义检查 20/20；当前可作为人工发布前工作台，但不是自动发布或传播效果证明。
3. `validate-workflow-replay.ps1` 继续只做历史 / sample 的 `trace_replay_readonly`，不执行 AI 写作、不联网、不生成图片；它与 P0 runtime 的真实确定性步骤执行边界必须分开描述。
4. E 批已完成最小 regression fixture：`examples/regression-suite.yaml` 和 `tools/validate-regression-suite.ps1` 已落地，`validate-public-release.ps1` 增加 `P3REL-009`，public_release 内 suite 返回 `pass_with_warnings` 且 release 检查退出码 0。
5. F 批已完成 validation-only CI 编译：`.github/workflows/public-release-candidate-check.yml` 和 `tools/validate-ci-workflow.ps1` 已落地，`validate-public-release.ps1` 增加 `P3REL-010`；H7 临时分支已完成多宿主远端验证，正式 alpha.4 release commit 仍需重新运行 Actions。
6. G 批已完成 Alpha 体验表达：README / INSTALL / RELEASE_NOTES / examples 第一屏已强化 GitHub 预发行、非生产 runner、不可自动发布、样例验证范围等提醒；`tools/validate-alpha-expression.ps1` 已落地并接入 `P3REL-011`。
7. Release Gate 工具区分本地候选、tag、remote、GitHub Release 与完成态；alpha.3 发版产物统一进入 `releases/v0.1.0-alpha.3/`，不散落根目录。
8. GitHub Release `v0.1.0-alpha.2` 仍保持原 tag；`v0.1.0-alpha.3` 只有在 main/tag、Release assets、Source zip、页面与 Actions 全部审计通过后才标记 published。
9. 图片质量检查需继续增强 prompt_alignment_score / retention_task_score，不只检查文件存在。
10. 后续调研 Seedream 4.0 / 5.0 等外部图片模型旁路；当前只保留降级策略说明，不实现 API。
11. 当前成熟度判断为 L2.8，已完成 GitHub alpha 开源上线；不能宣称 L3、生产级自动化或完整产品化。
12. R3-C54 到 R3-C90 已完成 Skill 编译；私有真实内容生产已从当前调研、人工选题、Brief、口播、5 次 Image 2、视觉质检、四平台包装、3 张封面跑到 H7 HTML，语义检查 20/20 `pass_with_warnings`。不公开真实账号或 session ID。
13. H6 证明了 `derived_visual_count=accepted_visual_tasks.length` 的真实执行链：8 个任务均有完整 prompt / digest、generation record、metadata / hash 和最终卡片；发布仍未执行，真实传播效果和当前 Image 2 运行模型档位仍为 `not_tested / not_observable`。H6E 又修复 completed prepare 状态回退风险、checker 修改 manifest、真实 8+3 被写入通用 checker、重复 prepare 累积 source ID、parser-only 漏运行错误和 layout smoke 退出码误判。
14. DOC-G1 文档图治理已完成：新增 `docs/README.md` 以及 product / reference / explanation / how-to / tutorials、skills、templates 和本地 objects 分区索引；6 份当前长文增加 AI 内部导航。`validate-doc-governance.ps1` 8/8 pass，本地 15 个入口齐全、直属文档覆盖缺口 0、链接 / anchor 断链 0、根目录散落 0；未跟踪用户研究稿不进入公开索引。
15. Windows 兼容第一轮 `WINCOMPAT-20260712-001` 为 overall fail：21 个 canonical case 中 13 pass、7 fail、1 个级联未评估。第二轮把问题递归为 capability、preflight、artifact proof、host defaults、security boundary、coverage honesty 六个父因；产品合同 R4-C41 到 C58 已写入 R4 文档，下一步建议按 R4-WIN-H1 至 H6 编译。
16. R4-WIN-H1 已修复 H4 `Start-Process` 参数边界：新增 Windows command-line 转义与 7 组 argv fixture，5.1 / 7.6.3 在当前根、空格中文隔离根均为 22/22 pass；下一批进入 H2 的统一 writer / process wrapper 与静默模块安装清理。
17. R4-WIN-H2 已新增共享 Windows runtime helper，迁移宿主默认 UTF-8 写入、H4 进程启动和封面记录；删除 YAML 静默安装入口。专项 9/9 在 5.1 / 7.6.3 当前根和 78 字符空格中文根通过，H4 22/22、support log、cover composition、Git-index 公开候选包和 P3REL-026 均通过；下一批进入 H3 path / environment preflight。
18. R4-WIN-H3 已新增 environment doctor / preflight 和 15 项 fixture；5.1 / 7.6.3 在当前根、79 字符空格中文嵌套根和 Git-index 公开候选包通过，P3REL-027 pass。构建器修复嵌套副本误借父仓 index，并在清空旧候选前验证路径、junction、temp rename 与磁盘；下一批进入 H4 archive integrity。
19. R4-WIN-H4 已新增共享 archive integrity helper 和 18 项 fixture：公开包 / 支持日志先生成包内 manifest，再以临时候选 ZIP 做安全解压与 count / size / SHA256 / required-file 复核，通过后才替换正式包。双宿主当前根与 63 字符空格中文根通过，528 文件公开候选双宿主 overall pass，P3REL-028 pass；并补齐非 Git source package 完整路径预算。下一批进入 H5 clean-room matrix。
20. R4-WIN-H5 已把环境合同固化为 12 个 canonical case：5.1/7 × short/space-unicode/over-budget × source/zip。8 个正例均执行 runtime-helper 与 environment-preflight，ZIP 同时验证内部 manifest；4 个超预算 case 均在写入前 `blocked_preflight`。首次 10/12 暴露 5.1 继承 pwsh `PSModulePath` 后不能自动加载 `Get-FileHash`，已改共享 .NET SHA256，复测 12/12；CI full matrix 与 P3REL-029 已接线。下一批进入 H6 文档、兼容报告和新版本候选复测。
21. R4-WIN-H6 已把版本真源推进到 `0.1.0-alpha.4`，更新 INSTALL / UPDATE / CHANGELOG / Release notes / release checklist 和 Windows 兼容报告；并修复候选 manifest 状态、Git-index source commit 证明和 validator 副作用造成的 ZIP false-success 风险。alpha.4 已获得远端发布授权，进入 clean HEAD 重建和发布闭环。
22. R4-WIN-H7 已确认 R4-C59 到 C66，把扩展环境轴编译为“环境事实探针 + 同 host/root/commit/hash 的 full matrix/public validator”证据合同。loopback SMB/UNC 12/12；最终临时分支 run `29201879451` 在 commit `f63e00b…` 上完成 base、Server 2022、Server 2025 和 Windows 11 ARM64 四个 required job，全部 `completed/success`，随后删除远端临时分支，main/tag/Release 未改变。

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


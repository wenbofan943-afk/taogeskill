# 涛哥创作工作流 STATUS

> 当前状态卡。历史讨论不写成长流水；有价值的过程进入对应记录文件。

---

## 当前阶段

```text
project_stage：workflow_stabilization
workflow_usage_state：v0.1.0-alpha.8_github_release_published
architecture_migration：ARCH-20260718-002_M4_new_session_generation_switch_completed_not_certified
架构说明：M1 静态编译 8/8、M2 direct shadow 16/16、M3 hotspot shadow 21/21 继续通过。M4 已增加不可变 `session-runtime-binding` 与 SHA256 commit marker：未来新建 direct / hotspot session 默认绑定 `kernel_v1_current`；既有 session 按已提交 binding 或原有 R7 version-pinned plan 续跑，不补写、不原地迁移。回滚只把未来新 session 切回 `legacy_r7`，已存在的 kernel session 不改代际。M4 Windows PowerShell 5.1 正反 fixture 19/19 通过，覆盖新建、续跑、幂等、回滚、legacy 只读、篡改/半提交/未知字段/越界和错误路由 false-success。未联网、未调用 provider、未读取私有账号；runtime certification 仍为 `not_run`，项目保持 L2.8。
状态说明：`0.1.0-alpha.8` 已作为 GitHub prerelease 发布。R8-C01 至 C70 已确认；H1-H4 与 H5R1-H5R5 已完成本地编译和本轮确定性评估收口，业务 Skill inventory 为 28 个。`hotspot-topic-research` 已从 953 行降到 150 行，`propagation-router` 已从 777 行降到 70 行，`platform-packaging-adapter` 已从 665 行降到 56 行。H5 v0.2 已编译 typed input、独立双臂、机器审计、匿名包、human verdict recorder、唯一 finalizer 与 finalization-only state projection；整项目仍保持 L2.8。
当前产品门禁：旧 evaluation `...004` 与 `...005` 分别因字符串和空/单元素数组的匿名投影形状损坏而隔离，未覆盖原证据。修复后的 `EVAL-R8-H5R4-87e6e77-006` 完成 18 个独立 submission、无补充消息，生成热点 2 对和平台包装 2 对；匿名包不含 `Length` 伪对象且保持 object/array/scalar 拓扑。4 个可比案已完成盲评，映射后结果为热点正常 tie、热点条件 baseline、平台正常 baseline、平台条件 baseline。唯一 finalizer 已写入 `insufficient_samples / fail`：router 可比样本为 0，router 正常/恢复案存在 baseline 非法节点，三个 rejection 案未全部 fail-closed，且三个案例偏向 baseline；因此 R8 candidate Skill 未晋升为业务 current。该结论与 M4 的 workflow runtime 代际入口是不同开关。token 仍不可观察，R7-L3-H5 私有真实认证仍是独立可选后续范围。
当前位置：`<PROJECT_ROOT>`（由当前 Git 工作树解析，本机绝对路径不进入公开源码）
Git：已初始化独立本地工作母仓，当前分支 `main`；无凭据 HTTPS 远端为 `https://github.com/wenbofan943-afk/taogeskill.git`；当前已发布 tag 为 `v0.1.0-alpha.8`，release commit 为 `d7fb323`；Git 入口由执行环境解析为 `<GIT_EXE>`
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
用户直供文案入口 skill
新闻 / 数据 / 引语的来源证据画中画 skill
首次账号建档引导 skill
工作流状态记录
反馈日志包导出
R7-L3 能力基线、干预账本和三级成熟度证据派生器
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

M5. M4 已完成未来新 session 的代际切换，既有 legacy R7 session 保持原版本续跑。本轮同时把根目录 3 份旧动态检查报告归档到 `state/checks/archive/20260718-m4-entry/root-report-residue/`；M1-M3 与 legacy R7 的 tracked 脚本/合同仍有消费者，未误归档。下一步是 compatibility isolation：把历史 blueprint / Schema / renderer 彻底退出 current 热路径，但在反查 active legacy consumer 和 replay fixture 前不删除或物理归档。M5 尚未授权；M4 也不等于 runtime certification。

R8. R8-H1/H2/H3/H4 与 H5R1-H5R5 已完成本地编译和本轮确定性评估收口。H5R5 专项 fixture 覆盖 waiting_human、不可变 verdict、mapping commitment、3/3 false-success、router 0 样本和 finalization-only projection。4 个匿名案例 verdict 已提交，唯一 finalizer 的 candidate Skill promotion readiness 为 `insufficient_samples`、overall 为 `fail`；router 0 样本、router baseline 非法节点、三个 rejection 未 fail-closed 和三个 baseline preference 均已保留为 blocker。它不否定 M4 workflow runtime generation switch。后续若要修复 R8 candidate，须另行进入 issue triage / product definition / skill compile；本轮不自动进入私有认证或发布。

0. R3-C164-C180 与 R7-C133-C160 已确认；R7-L3-H1/H2/H3/H4 已完成本地编译与离线回归。R8-H3 已将直供和热点 current blueprint 升为 v0.6；视觉语义链不变，最终人工决定改为 typed decision + deterministic apply，v0.5 及更早只作历史 replay。H4 fixture 8/8 覆盖账号策略到研究请求、外部等待同 task resume、事实更新/反转恢复及 scoped visual-route revision。下一次真实认证必须按新 v0.6 基线重新开始；项目仍为 L2.8。
   另有一条公开脱敏、短路径的 current `direct_delivery_single_v0.5` 全链回归已跑到 `final_human_gate_h7`：candidate、HTML、真实 viewport、交付视觉复核和业务验收均通过；语义输入为 fixture，未调用网络或 Image 2，因此不替代私有真实认证或 L3 证据。
1. R3-C154-C163 与 R7-C113-C132 已确认并完成 H7A 本地联合编译：Image 2 base / 派生成品 / 唯一交付素材、显式 finalize、最终 HTML 主层 / 折叠审计层、技术 viewport / 业务交付验收均已闭合。H7B 已用新的私有 session 完成真实看图、业务验收、竖屏 PIP contain 排版与退出码修复复测；不公开真实 session，也不据此宣称 L3。
2. 外部 tester 独立安装和试跑仍是 beta / stable 的后续门禁，不阻断 Alpha.8 预发行。
3. R7-C01 至 C112 已确认并完成联合本地编译；blueprint v0.3 的新私有热点 session 已复测证据语义、视觉来源路由、真实所需 Image 2、HTML / viewport 与返修重开。当前结果为 `completed_with_warnings`：业务交付闭合，但语义 payload、视觉判断、prompt 与一次封面字级实现仍有 Codex 实质扶持；整项目保持 L2.8，L3 需要可重复的无 run-specific helper 自主编排证据。
4. R5-H6 已完成脱敏编译、私有显式绑定迁移和一次真实启动回归；绑定摘要可重复生成且稳定，账号已可在用户要求时进入热点研究。仍不自动采集、登录或发布；真实热点检索需另行由用户发起。
5. `R6-B01` 已完成结构计划、共享内容节点、口播质检、全文视觉覆盖、对齐审查和最终交付 v0.5 本地编译；私有真实稿件已在不调用 provider、不联网、不发布的条件下完成一次回归，结果 `pass_with_warnings`。该回归证明确定性工具可用，也证明语义步骤和 candidate 仍需 R7 收敛。
6. `R3-C91` 至 `R3-C124` 已完成产品确认和 v0.4 六层编译；私有真实运行的 v0.3 封面人工验收失败记录保留，新的 revision 3 通过 Codex raster 检查与 v0.4 语义门禁，当前等待用户最终整页验收，未发布。真实 session 标识仅保存在私有生产区。
7. 当前联合合同已编译并完成一轮新私有热点 session：新闻证据增加口播主张—可见引文—坐标锚点一致性；普通新视觉默认 Image 2 base，既有资产复用绑定 session/task/hash/account snapshot；一次人工退回可含多个原子修改项并按最早 owning node 重建。该轮为 `completed_with_warnings`，不能外推为项目级 L3。

---

## 已完成里程碑

> 历史口径说明：下列第 15–20 项保留旧双宿主研发 / 发布证据。它们已被当前的 Windows PowerShell 5.1-only 政策取代，不得被读取为当前公开支持、安装前置或发布门禁；当前真源见本页“当前阶段”及 R4-C59 / C60。

1. P0-H2 已把轻量 runtime 迁入 v0.2：`invoke-workflow-runtime.ps1` 能按版本分流，确定性执行 `compile_render_input -> render_final_delivery`，写 append-only event、render input / final_delivery lineage、artifact checks 和 render receipt；旧 v0.1 runtime 保持只读兼容。
2. P0-H1 至 P0-H7 已形成单篇确定性运行链。H6 在已脱敏标识的私有回归中产生 8 个 accepted、8 张 PIP 和 3 张派生封面；H7 复用这些已验证图片，按当前平台标题重新合成封面并建立唯一 delivery revision。脱敏 H7 fixture 10/10、真实语义检查 20/20；当前可作为人工发布前工作台，但不是自动发布或传播效果证明。
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
23. R6-C01 至 C19 已完成本地六层编译：新增直供文案一等入口和来源证据画中画 producer，R3 v0.2 按任务分流 Image 2 与 source capture，浏览器捕获先记 attempt 并 reconcile，确定性 renderer 分离来源事实与创作者解读，最终 HTML 展示来源追溯。R6 17/17、R3 25/25、H7 10/10 通过；本轮未联网、未用真实账号、未调用 provider、未发布。
24. R7-H1 已完成合同底座：新增 `semantic-workflow-coordinator` contract-only Skill、直供 / 热点两条蓝图、18 个注册节点、合同状态与 7 个 action code、task / submission Schema、v0.1-v0.5 replay-only 兼容矩阵。专项 7 个 Schema、16 个 fixture（9 个负例）、字段 / 路由 / 文档门禁、公开包 47/47 与 Windows PowerShell 5.1 六格 clean-room 通过；未运行 H2/H4、真实账号、浏览器、provider 或发布。
25. R7-H2 已完成 coordinator / submitter runtime：新增 selector、commit、status-route、task-guidance 注册表，P0 plan v0.6、semantic submission v0.2、current pointer / commit receipt Schema 与真实 PowerShell 5.1 入口。R7-F05 至 F08 全部通过；无效 submission 不写 pointer、task 后输入变更被阻断、完成态重复提交不追加 event、中断 revision 可 reconcile。H3 producer、H4 candidate、H5 viewport、真实账号、provider 与发布未在该批执行。
26. R7-H3 已完成 12 个直供 producer adapter 与 `new-r7-semantic-submission.ps1`；修复业务 result status 与 R6 payload 原生 status 混用，以及 waiting 被成功推进的风险。R7-F01 producer slice、F03 keep-current、F04 未授权等待均通过；provider、网络、浏览器、真实账号、H4 candidate 与发布未执行。
27. R7-H4 已完成 deterministic candidate v0.6 与 renderer v0.6；F09-F13 为 5/5 pass，12 个 current pointer 自动生成 source map / digest / event，三平台封面逐 rendition review 绑定，错误 summary / hash 均阻断，HTML 显示执行透明度。本批未执行 viewport、真实账号、provider、网络或发布。
28. R7-H5 已完成 Playwright/Chrome 真实桌面 1440×1000 与移动 390×844 视口测量、截图 hash、false-pass 防护、autonomy / manual-patch 计量、文档漂移和最终人工门禁。F14-F21 为 8/8 pass；最终局部返工必须绑定 candidate source map 目标，decision/action 错配与缺目标会在写 submission 前阻断。provider、网络、自动发布和新私有真实 session 尚未在本批执行。
29. R7-H5A 一条私有真实直供回归发现旧 v0.1 蓝图要求结构计划引用尚未产生的 draft / beat，已停止而未伪造未来 ID。产品合同扩为 R7-C29-C38，新建 `direct_delivery_single_v0.2`、P0 plan v0.7 和 task envelope v0.2，按 baseline draft -> semantic-only beat -> direct structure -> structure-bound beat 推进；submission revision 从 payload registry 派生，future reference / phase mismatch 在提交前阻断。R7-F23-F29 为 7/7 pass；该失败 session 不计自主完成，下一步必须用新私有 session 重跑同一文案。
30. R7-H5B 新私有回归在 candidate compile 暴露“同一 occurrence 跨多个相邻 beat 被重复投影”的合同缺口，runtime 以 `beat_card_v05_occurrence_duplicate` 正确阻断，未生成假 HTML。R7-C39-C46 将 visual task、coverage 与物理 occurrence 分离，owner 固定为最早 covered beat；R6 合同 fixture 为 40/40，R7 candidate fixture 扩为 9/9。Windows clean-room 首轮同时发现两份含非 ASCII 字面量的 R7 runtime 缺少 UTF-8 BOM，按 PS5.1 编码合同修复后六格矩阵 6/6 通过。真实失败 session 保留证据，必须从新 session 复测，不在原 session 手改 candidate。
31. H5B 修复后的新私有直供 session 已从原稿输入跑到 final HTML、桌面 / 移动真实 viewport 和最终人工门禁：16 个 content beat 中只有 2 个唯一 occurrence，重复 0；两套 viewport 均无横向溢出或图片 / 请求失败，candidate / revision / pointer / lineage / event / HTML 均由 runtime 生成，`manual_patch_detected=false`、`workflow_autonomous_completion_count=1`。本轮复用既有资产，未联网、未调用 provider、未登录或发布；该结果只把直供单篇路径提升为 L3 样本，不改变整项目 L2.8 判断。
32. R7-H6A 已完成热点前链编译：hotspot blueprint v0.2 / plan v0.8 依次提交 research request、单一 research set、deterministic panel、immutable decision、selected source、Brief v0.4、structure 与 Draft v0.4，并停在 `content_beat_map`。R7-F34 至 F80 中属于 H6A 的 31 个离线正反 fixture 全部通过；其后 Playwright 探针已改为 Node 真实解析 + 浏览器启动探针，不再回退 Codex 私有缓存。本批未联网、未使用真实账号、未调用 provider、未发布。
33. R7-H6B 已完成热点交付后链离线编译：新增独立 freshness review Skill / Schema、selected-source revision apply、reversal revalidation request、plan revision/commit 与 active replace 两阶段 replan、hotspot typed candidate / renderer / template v0.7。H6B 17/17、H6A 31/31、直供 v0.6 candidate 9/9、公开包 54/54、Windows PowerShell 5.1 六格 matrix 6/6 通过；历史 R3 checker 的版本标题字符串误判已改为按合同语义校验。`skipped/stale_replanned` 是路由终态但不计新成功，同一 artifact ID 后续 revision 使用独立 revision/lineage。该条末尾的未执行边界仅指 H6B 编译当时；H6C 后续失效结果以本页“当前阶段”为准。

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


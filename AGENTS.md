# 涛哥创作工作流 AGENTS.md

> 本文件是本项目的项目级 AI 驾驭工程约定。
> 本文件不记录动态选题、具体账号内容或某次文案结果；这些内容通过 `README.md` 索引到账号档案、调研运行记录、工作流状态记录和 `accounts/{账号名}/runs/{session_id}/` 下的交接物文件。
> 全局规则只引用，不复制：`<AI_ENGINEERING_ROOT>`。本地路径由执行环境提供，不写入公开源码。

---

## 一、项目身份

```text
项目名称：涛哥创作工作流
技术 slug：taoge-creative-workflow
项目类型：AI 内容工作流 / AI 资产链路 / 传播研究项目
当前阶段：轻量 workflow 自用验证
默认入口：README.md
```

本项目负责：

```text
首次账号建档引导
账号档案
产品/活动对象档案
热点调研
母题关联
选题卡
内容 Brief
口播文案
画中画提示词
文案与视觉质检
多平台分发包装
内容交付记录
最终 HTML 验收页
可转交交付包
工作流状态接续
```

本项目不负责：

```text
自动发布
平台登录
自动评论 / 私信 / 互动
采集平台后台数据
公开互动分析工具客户端 / 服务器 / 数据库 / license / 积分 / 发版
短视频创作 SaaS 正式工程实现
```

---

## 二、全局协议引用

默认继承：

```text
<AI_ENGINEERING_ROOT>/02-全局协议/AI工程驾驭协议.md
<AI_ENGINEERING_ROOT>/02-全局协议/设计决策与原子开发协议.md
<AI_ENGINEERING_ROOT>/02-全局协议/文档治理与知识收口协议.md
<AI_ENGINEERING_ROOT>/02-全局协议/版本治理与Git协议.md
<AI_ENGINEERING_ROOT>/02-全局协议/工具安装与缓存登记协议.md
```

本项目是轻量内容 workflow，不默认继承服务器发布、数据库迁移、采集器发版等重工程动作。若某次任务要进入其他产品项目开发，必须回到对应产品项目的 `AGENTS.md`。

项目级 Git 边界见：

```text
<PROJECT_ROOT>/docs/reference/版本治理与Git边界.md
```

本项目使用执行环境可用的 Git；本地可在私有配置中指定 Portable Git：

```text
<GIT_EXE>
```

当前项目目录是本地工作母仓，不是可直接公开的 GitHub 发布仓；公开发布前必须先做脱敏、样例化和开源包净化。

本地 commit 与远端发布必须分层治理。产品定义尚未确认时只允许修改产品文档和运行检查，不自动提交；用户已经认可进入 skill 编译 / 代码开发后，一组可独立解释、可独立回滚的原子变更通过相关检查，即默认完成“筛选本轮源码 -> 本地 commit -> 本地小扫地 -> 汇报 commit”，不再要求用户额外说一次“提交”。用户明确说“只改不提交”或本轮改动无法从脏工作区安全隔离时除外。

`git push`、创建 / 移动 tag、修改 GitHub Release、上传资产和修改 GitHub 仓库元信息始终属于远端写入。只有用户明确说“推送 / 发版 / 发布 / 同步 GitHub / 创建 tag / 更新 Release”，才允许执行；本地 commit 不自动授权任何远端动作。

当任务满足默认本地提交条件，或用户明确说“提交”时，执行本地提交闭环。用户说“提交”不等同于推送。闭环至少包括：

```text
1. 提交前运行与本次变更相关的本地检查。
2. 只暂存应进入源码的文件，不把 accounts/、indexes/、support-logs/、releases/、offline_tester_packages/、外部资料缓存或 state/checks/ 报告误加入公开源码。
3. 创建本地 git commit。
4. 提交后执行本地小扫地：git status --short --branch、git status --ignored --short、必要的最新 commit 摘要。
5. 确认工作区只剩 `.gitignore` 管理的本地私有 / 缓存 / 发版证据目录，或明确说明剩余未提交项。
6. 最终回复 commit、检查结果、ahead 状态、剩余本地项和“未推送”。
```

默认本地提交适用范围：已确认产品定义后的 `skill_compile` / 代码开发，以及边界清楚、检查通过的 checker、模板、路由和治理规则原子修订。`product_definition`、纯调研、只读审计、仅生成测试报告的 `test_run` 不自动提交。测试过程中如修复了源码或 checker，应在复测通过后把该修复作为原子变更提交。

如果工作区已有其他轮次或用户的未提交修改，必须先检查 diff，并只暂存能够明确归属于本轮的文件或补丁块。无法安全隔离时不得为了追求 clean 强行提交、覆盖或删除；应报告 `local_commit_status=blocked_by_mixed_worktree`、列出冲突范围并保留改动。

只有用户进一步明确说“推送 / 同步 GitHub / 发版”，才进入远端写入动作。

真实账号资料、真实账号档案、真实 runs、真实运行索引属于本地私有生产区，不得进入公开 Git 源码、公开 tag 或 GitHub 自动生成的 Source code zip / tar.gz。公开仓库只能保留 `examples/`、`docs/tutorials/`、`templates/`、`skills/` 等脱敏样例。`accounts/` 和 `indexes/` 默认必须由 `.gitignore` 排除；如需演示账号，必须放入 `examples/sample-account/` 或脱敏 tutorial 中。

根目录 `工作流状态记录.md` 可能包含真实账号名、session_id 和本地产物路径，属于本地私有状态，必须由 `.gitignore` 排除且不得暂存。Git 只保存 `templates/state/工作流状态记录.template.md`；新克隆缺少本地状态文件时，agent 先按模板初始化，再进入内容生产或状态恢复。公开 release 包可生成脱敏状态文件，但不得从本地文件复制真实记录。

`.gitignore` 的真实生产区规则必须锚定项目根目录，使用 `/accounts/`、`/indexes/`；不得写未锚定的 `accounts/`、`indexes/`，否则会误吞 `docs/tutorials/**/accounts/` 下的新脱敏样例，造成源码和发版包静默缺文件。

### 文档与产物摆放硬规则

项目根目录只放入口、身份、索引和顶层治理文件，不放过程产物、临时产物、账号内容、运行报告或散落发版包。

根目录允许保留：

```text
README.md
AGENTS.md
PROJECT_MAP.md
STATUS.md
VERSION
LICENSE
CHANGELOG.md
RELEASE_NOTES.md
CONTACT.md
SECURITY.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
NOTICE.md
INSTALL.md
UPDATE.md
public-manifest.yaml
release-checklist.md
工作流状态记录.md
交接物字段词典.md
少量跨项目方法论 / 总索引文件
```

除上述入口和总控文件外，新增内容必须先判断归属：

```text
docs/product/        产品定义、路线图、问题包、产品验收口径
docs/governance/     项目级 AI 驾驭工程、发版治理、隐私边界、任务路由、状态接续
routes/              机器可读任务路由、构建 profile 和必读清单
state/               当前状态入口、状态真源索引和迁移计划
docs/reference/      字段规范、目录规范、执行规范、检查规则
docs/explanation/    复盘、调研解释、方案说明
docs/tutorials/      可公开教程和脱敏使用说明
skills/              可复用 skill 执行单元
templates/           交付物、状态、HTML、账号、日志模板
examples/            可公开脱敏样例；不得混入真实账号 / 真实 run
tools/               自动检查、构建、导出、审计脚本
objects/             脱敏产品 / 活动对象档案
accounts/            本地真实账号生产区，默认不进公开 Git
indexes/             本地真实索引区，默认不进公开 Git
support-logs/        本地反馈日志包，默认不进公开 Git
releases/v{version}/ 公开发版候选包、zip、sha256、报告
外部资料/            外部调研缓存，不作为运行依赖，不默认进公开包
```

禁止新增以下根目录散落物：

```text
新建临时分析.md
某次测试报告.md
最终文案.md
final-delivery.html
*.zip
*.sha256
release-check-report.*
support-log.*
未归档的截图 / 图片 / HTML / JSON 报告
```

如果任务中需要沉淀规则，应优先进入 `docs/governance/` 或 `docs/reference/`；如果需要沉淀产品方案，应进入 `docs/product/`；如果是某个账号或某次内容运行产物，必须进入 `accounts/{账号名}/runs/{session_id}/`；如果是公开交付包，必须进入 `releases/v{version}/`。

每次新增或移动文档后，必须检查 `README.md` / `PROJECT_MAP.md` / `AGENTS.md` 是否需要更新索引。不能让关键规则变成孤岛文档，也不能靠根目录堆文件来“提醒 AI 看见”。

文档索引采用两级治理：根 `README.md` / `PROJECT_MAP.md` 只保留项目身份、快速入口和目录职责；`docs/README.md` 负责文档分区与真源优先级；`docs/{product,reference,explanation,how-to,tutorials}/README.md` 完整覆盖直属知识文档；`skills/README.md` 和 `templates/README.md` 分别索引可执行能力与模板。新增普通文档只更新所属分区索引，避免根入口重复维护全量清单。

当前高频真源超过 800 行时，前 80 行内必须有 `<!-- ai-nav:start -->`，指向当前状态、关键对象和最新结论。AI 进入长路线图、字段词典或确认清单时先用内部导航 / `rg` 定位，不默认顺序全文读取。历史章节必须保留审计语义，但不能覆盖 `STATUS.md`、`state/current-state.yaml` 或当前产品确认状态。

文档 / 目录治理结束前必须运行 `tools/validate-doc-governance.ps1`，并通过 `link_check_gate / root_cleanliness_gate / document_graph_gate`。未跟踪的用户自有文档默认不纳入公开索引、不暂存、不为满足覆盖率而修改；需要纳入必须有用户明确授权。

### AI 驾驭工程编排入口

本项目不再把所有编排细则继续堆入 `AGENTS.md`。当用户说“按 AGENTS”时，必须先使用独立编排区判断任务类型、必读清单、构建 profile 和门禁：

```text
docs/governance/agent-orchestration/README.md
docs/governance/agent-orchestration/task-routing.md
docs/governance/agent-orchestration/build-profiles.md
docs/governance/agent-orchestration/state-and-gates.md
docs/governance/agent-orchestration/after-task-guidance.md
docs/governance/agent-orchestration/required-reads.yaml
routes/workflow-routes.yaml
routes/build-profiles.yaml
state/current-state.yaml
```

执行顺序：

```text
1. 先按 task-routing.md 判断 task_type。
2. 再按 routes/workflow-routes.yaml 或 required-reads.yaml 读取该任务必读文件。
3. 涉及测试 / 发版 / 公开包时，按 routes/build-profiles.yaml 和 build-profiles.md 判断 dev / test / public。
5. 涉及状态、checkpoint、人类确认或失败收口时，先读 state/current-state.yaml，再按 state-and-gates.md 执行。
6. 任务结束时，按 routes/workflow-routes.yaml 的 after_completion 和 after-task-guidance.md 给出后置引导。
7. 只有 task_type 不清或门禁需要人判断时，才停下来问用户。
```

模型、推理强度与速度由用户在 Codex 前端手动选择；项目任务路由不得声称能自动切换当前任务模型。

不得因为 `AGENTS.md` 很长就凭记忆执行；也不得为了“看见规则”把新治理文件继续散落到根目录。

### 长任务、路径和测试副作用防复发规则

- 所有读写先用 `git rev-parse --show-toplevel` 固定 `<PROJECT_ROOT>`，不得沿用 projectless 线程 cwd；本地真实绝对路径只存在于运行环境，不进入公开源码。
- 长任务按“产品反查 -> 数据流 -> 编译 -> fixture -> checker -> 状态 -> commit”分段；断流后先查 diff、状态和报告，从最后断点恢复，不重开并列文档。
- 路径型 checker 先做目标 preflight；路径传错记 `checker_invocation_error`，不判 workflow 失败。详细规则见 `docs/governance/agent-orchestration/state-and-gates.md`。
- 动态报告默认写 `state/checks/`；只有预期行为变化才更新 tracked golden report，纯 timestamp / run_id 噪声不得提交。
- Skill 编译必须验证 `producer -> ID / research_run_id -> status / gate -> next_skill -> consumer -> final HTML`，不能只查字段名存在。
- 同一 session 出现同一种 deterministic operation 的后续修订时，runtime 必须优先执行依赖已满足的 pending revision；没有 pending 才读取最新 completed revision，不得固定选择首条历史 step。
- 上游产物被版本化修订后，进入 render compile 前必须同步更新 trace card / lineage digest；hash 不一致属于正确阻断，先修追溯绑定，不得绕过 checker。
- 已完成 session 的 prepare / scaffold / migration 工具不得把 manifest 从 `completed` 回写为 running / pending；同一输入重复调用必须 skip 或 byte-stable。需要修订交付候选时必须新建 revision step，不能暗改 completed candidate。
- 跨账号 checker 若要求账号资产携带 `account_identity_id` / `account_technical_slug` 等身份标记，同一当前版本的 Schema、模板、Skill、正反 fixture 必须同时允许并校验这些字段；不得出现文本预检要求字段、机器 Schema 却以 `additionalProperties=false` 拒绝字段的不可满足合同。历史 Schema 只按 replay 兼容，不得靠删标记通过当前激活门禁。
- 同一 session 因任务阶段变化重新物化账号快照时，每个不同内容摘要必须使用独立 `snapshot_id` 和文件；热点、选题、内容、视觉快照不得同 ID 异内容，也不得为补字段覆盖已被上游 artifact 引用的快照。
- checker 除写自己的动态报告外默认只读，不得顺手修改 manifest、输入 artifact 或最终交付状态；状态完成写回必须由显式 finalize / evidence command 承担。
- 通用 runtime / checker 的数量必须从 plan、analysis、selection 或 provenance 派生。本次真实回归观察到的 8 张 PIP、3 张封面只能写进 run/report，不能编译成产品常量。
- 外部 side effect 返回后先持久化 attempt / outcome / output reference，再做复制、叠字或封面派生。长命令中断后必须先 reconcile 已有 provider 输出和本地文件；结果已存在时禁止盲目重调 provider。
- 新增或修改 PowerShell 可执行入口时，parser 通过不算完成；至少实际执行一次无外部副作用的 self-test 或代表性 fixture，并验证退出码、关键输出和产物。`runtime_smoke_gate` 未通过不得提交。
- PowerShell、外部进程、路径、压缩包、构建器或发布 checker 发生变化时，不能只在当前短路径验证。运行 `tools/invoke-windows-clean-room-matrix.ps1` 的 Windows PowerShell 5.1 × short/空格中文/超预算 × source/zip 六格 canonical matrix；超预算的正确结果是 `blocked_preflight`。PowerShell 7 不是当前公开兼容性承诺；若未来恢复该承诺，必须另立产品确认、矩阵、CI 与公开文档，不能用历史绿灯代替。公开包 `P3REL-029` 与 CI matrix step 未接线不得提交。
- `Start-Process -ArgumentList` 的数组最终仍会连接为命令行字符串；含空格、中文、引号或空参数的调用必须经过统一参数序列化并有真实 fixture，不能凭数组形式判断安全。当前基线必须在 Windows PowerShell 5.1 实测；PowerShell 7 只有被重新列为支持目标后才需要单独 fixture。
- 项目已有 `tools/WindowsRuntimeHelper.ps1` 后，tools / skills 新代码不得直接调用 `Start-Process`、不得使用 `Set/Add-Content -Encoding UTF8`、不得在 checker 中调用 `Install-Module`；统一使用共享 process / UTF-8 no-BOM helper。专项 `validate-windows-runtime-helper.ps1` 和公开包 `P3REL-026` 未通过不得提交。
- 路径写入、构建和解压必须先做 path budget / reserved name / root containment / write permission preflight。Windows PowerShell 5.1 的公开兼容档默认要求安装根目录不超过 90 字符；超预算应在副作用前阻断，不得靠用户修改注册表兜底。
- 项目已有 `tools/EnvironmentPreflight.ps1` 和 `invoke-environment-doctor.ps1` 后，构建 / 打包不得自行拼一套弱化检查。preflight 必须发生在清空旧候选、复制文件或创建深层输出目录之前；失败时保留旧候选与 sentinel 证据，执行 `validate-environment-preflight.ps1` 和公开包 `P3REL-027`。
- 可执行入口不得依赖调用者 cwd；项目根从 `PSScriptRoot`、Git root 或显式参数解析。临时文件优先建在目标同卷并用原子替换，副作用前检查临时区 / 目标可写性、可用空间和残留清理；不得把用户全局 TEMP 当无条件可靠依赖。
- 压缩 / 解压 / native tool 退出码为 0 只算工具层证据；还必须核对 archive manifest、必需文件、文件数量和 SHA256。统一使用 `tools/ArchiveIntegrity.ps1` 先生成包内 manifest 和临时候选 ZIP，安全解压验证通过后再替换正式包；失败必须保留上一份有效包。`validate-archive-integrity.ps1` 和公开包 `P3REL-028` 未通过不得交付或发版。发现“退出 0 但少文件”归因为 `archive_integrity_error`，不得宣称构建或安装成功。
- 机器合同、JSON / JSONL、摘要输入和哈希产物必须显式 UTF-8 无 BOM；不得依赖 `Set-Content -Encoding UTF8` 在 Windows PowerShell 5.1 / PowerShell 7 中不同的默认 BOM 语义。脚本源码编码按宿主兼容单独治理：会由 Windows PowerShell 5.1 执行且含非 ASCII 字面量的 `.ps1` 必须保存为 UTF-8 BOM，并由 fixture 读取文件头验证，不能把“编辑器看起来正常”当成 runner 可解析证据。
- YAML 中版本号等机器字符串若 Schema 使用字符串 `const`，模板与真实资产必须显式加引号；不得把未加引号的 `0.2` 浮点值经 PowerShell 字符串化后误判为已通过 JSON Schema。
- Git 跟踪路径含中文或其他非 ASCII 字符时，不得通过宿主控制台编码消费逐行 `git ls-files` 输出；统一读取 `-z` 分隔的 UTF-8 流并显式解码。source clean room 必须包含至少一个真实 Unicode 跟踪路径断言，防止英文 Windows runner 上出现乱码后误报缺文件。
- 在 `$ErrorActionPreference='Stop'` 下探测 Git / native tool 失败能力时，不得假设 `2>$null` 会把非零退出安全降级为 `$LASTEXITCODE`；Windows PowerShell 可能先把 stderr 升级为终止错误。可选 Git root 探测统一走共享 .NET process wrapper，并对真实非 Git 临时目录做 nonfatal fixture。
- checker / validator 默认使用 `-NoProfile`、离线、无可选用户模块的 clean-room 条件；不得为了检查通过静默 `Install-Module`。可选模块缺失必须走内置 fallback 或诚实阻断。
- 环境测试只检测 execution policy、MOTW、LongPathsEnabled、区域设置、Git 配置和同步目录，不自动修改全局 execution policy、注册表、Group Policy 或用户全局 Git 配置。需要 Git 长路径时优先仓库级 preflight / 配置，并记录原值与作用域。
- 路径比较先规范化，再确认仍位于允许根目录；同时检查 Windows 保留设备名、尾随空格 / 点、大小写碰撞与 reparse point 越界。网络盘、OneDrive 同步根、大小写敏感 NTFS 和企业 Group Policy 主机未专项验证前一律标记 `not_certified`。
- 环境兼容声明必须记录 Windows build / edition、CPU architecture 和 filesystem。当前机器的 AMD64 + NTFS 通过不能外推到 ARM64、Windows Server 或非 NTFS；未有专项证据的组合标记 `not_certified`。
- 环境事实探针只能证明“当前 host/root 确实具备该轴”，不能单独把兼容性升级为 pass。只有同一 host、同一 target root、同一 source commit、同一候选包 hash 上的 full clean-room matrix 与 public validator 同时通过，才允许写 certified；缺少 runner / share / policy / filesystem 时写 `blocked_external_infrastructure`，不得用 synthetic fixture 或旧 green run 代替。
- validator / fixture 的沙箱路径本身必须纳入经典路径预算；优先使用候选版本目录同级短沙箱，不能因系统 TEMP、用户目录或 runner workspace 过长制造假失败。验证前后必须复核 canonical candidate 文件数与 archive manifest parity。
- full matrix 的 WorkRoot 必须短、唯一且预先为空；UNC / 超预算测试留下旧根时保留报告并换新根，不得在下一轮开头盲目递归删除深路径或网络目录。测试清理失败归为 checker / environment evidence，不覆盖本轮业务结果。
- 远端 Actions 证据必须核对 workflow run 的 `head_sha` 等于待验证 commit，并逐个检查 required job 的 conclusion；`windows-latest` 不能代替显式 Server 版本，x64 runner 不能代替 ARM64，历史成功 run 不能证明当前候选。未获 push 授权时只允许编译 / 本地校验 workflow，并保持 `remote_run=not_run`。
- 远端 matrix / checker 失败必须在 job log 输出失败 case、failure category 和相关 stderr tail，并用 `if: always()` 上传机器报告与诊断日志；只打印 runner 内 ephemeral report path 不算可恢复证据。诊断 artifact 不得包含真实 accounts、私有 runs、token 或完整工作树副本。
- 本地文件锁 / 防病毒瞬时占用只允许有上限、可审计的退避重试；路径超预算、非法命名、摘要不一致、策略阻断和外部 provider 调用不得盲重试。机器时间、数值和排序使用 ISO 8601、显式时区和 invariant 口径。
- 环境负例 fixture 不得用 `当前可用磁盘空间 + 1` 等会随并发清理波动的瞬时边界制造失败；应使用卷总量以上或 `Int64.MaxValue` 等不变量阈值，并断言明确的失败分类。
- 任何会被下游用于 freshness、趋势、请求时间或审计排序的时间，必须由上游调用方先物化、写入版本化合同并由下游逐字继承；缺失、无时区或非法时明确阻断。不得用 epoch sentinel、文件 mtime、当前机器时间或聊天时间静默补位，否则会把合同漏接伪装成“旧数据”。
- 产品合同若包含数量、默认值、上下限、条件必填、成本 / 调用次数或状态派生，不得只写在产品说明或 Skill prose。至少同步到字段词典、Skill / CONTRACT、机器 Schema 或确定性校验函数、正反 fixture、专项 checker；缺一项即 `product_contract_compilation_gate=fail`。
- 已编译产品合同被新的人类确认产品定义取代时，旧字段、Skill / CONTRACT、Schema/runtime、fixture、checker 和真实回归入口必须立即登记为 `superseded_pending_recompile`。旧 checker 即使继续 pass，也只能证明历史兼容，不能证明新产品实现；在六层重新闭合前不得继续依赖旧合同做真实外部回归或声称功能完成。
- 通用 runtime / checker 不得写死某次真实回归的图片数、平台数或资产数。fixture 专用固定数量必须显式标记 `cardinality_mode=baseline_fixed_regression`，通用检查从 plan / provenance 派生期望值。
- 外部图片回归 preflight 必须找到实际提交给 provider 的完整 prompt 文本、prompt digest 和来源 session；只有 prompt ID、摘要、验收语或旧图片路径不得宣称“固定 prompt”。provider 调用数只统计外部基础生成任务，确定性叠字、封面排版、裁切和改标题属于派生产物，不增加 provider 调用数。
- generated / prompt_only 等条件路径分开定义必填字段；下游计算结果不得反列为上游输入。产品状态、编译记录、STATUS 和本地状态须同步收口。
- 用户直供稿进入结构诊断前必须先物化 source-aware baseline：只允许确定性换行归一和元数据封装，`original_normalized_body_digest` 必须等于 current `normalized_body_digest`。这条保护必须同时进入 typed draft、runtime 和负例 fixture；Skill prose 写了“保留原声”不能替代机器门禁。
- R3 全文视觉规划只允许消费 current `structure_bound content_beat_map`；`semantic_only` 只服务直供稿现状诊断。每个 beat 必须有唯一 coverage record，图片任务数、已成素材数、provider 任务 / attempt、来源捕获任务 / attempt 和插入 occurrence 分开派生，不能互相代替。
- R6-C20-C50 / R3-C125-C139 之后的新运行以 typed / renderer / template v0.5 为当前合同；v0.4 及更早 checker 绿灯只证明历史 replay。当前合同的公开包必须同时执行 R6 script-visual 与 P0 v0.5 专项门禁，不能只检查依赖文件存在。
- 最终交付类产品进入编译前，必须定义 current revision 的物理 commit marker、producer / consumer、固定输出路径、失败语义和旧版本迁移；不得用“多个文件原子生成”掩盖普通文件系统没有跨文件事务。
- 新增必填对象或改变交付语义时必须升级 typed input / renderer / template 合同版本，旧版本只按兼容矩阵 replay / render；不得在同一版本号下静默换合同。
- 任何时长、数量、阈值或默认值必须有产品依据、账号实测或版本化 profile；缺少依据时写 `not_available`，禁止把 fixture 常量带入真实交付。
- Git worktree 的公开包只从 Git index 构建，并反查未跟踪研究稿、真实账号和缓存是否泄漏。
- 公开包 checker 不得把报告、fixture work 或其他动态文件写进 `public_release/`；必须在隔离副本执行，主报告写到 `releases/v{version}/` 或 `state/checks/`。release gate 必须重新核对 unpacked candidate 与 `archive-manifest.json` 的 count / size / SHA256，防止“目录通过但 ZIP 不同”的 false success。
- 公开 ZIP / archive manifest 的精确 SHA256 不得写回会被同一候选包收录的 tracked 状态或入口文档，否则包内容变化会让摘要自我失效。精确摘要只写 `releases/v{version}/`、`state/checks/` 或外部发布记录；tracked 状态只记录门禁结论和证据位置。
- Git-index 构建必须先从 index 生成允许文件集合，再读取源文件；禁止先递归扫描工作树、之后才过滤，因为 ignored 的真实账号、深路径沙箱、缓存或不可读目录可能在过滤前造成泄漏、假失败或副作用。
- Git-index 构建若存在未暂存 tracked 变更，必须在清空旧候选前阻断；只有工作文件与 index 一致才允许复制。已暂存未提交时包内 `source_commit=git_index_pending_commit`，本地 commit 后从 clean HEAD 重建才允许写真实 commit hash；public manifest、release checklist 与 release record 必须一致。
- 判断 Git-index 模式不能只问 `is-inside-work-tree`；必须比较 `git rev-parse --show-toplevel` 与显式 ProjectRoot。位于父仓 ignored 子目录的解压包 / 隔离副本不得借用父仓 index，否则会得到空包、漏文件或绕过路径预算。
- Windows 空格 / 中文隔离根准备不得直接依赖未经 argv fixture 验证的 `git checkout-index --prefix=<absolute path>`；原生命令参数必须走统一序列化，或按 `git ls-files` 白名单在同一 PowerShell 进程复制，并在运行 checker 前核对目标文件数。准备失败记 `checker_invocation_error`，不得算 workflow fail。
- 不兼容合同升级必须同步 plan schema、typed schema、renderer/template、compatibility matrix、Skill / 字段词典、fixture、构建白名单和公开包门禁；只升级 payload 版本不算编译完成。
- 版本化 workflow blueprint 的节点顺序改变属于不兼容合同升级；不得原地改旧 blueprint 或只改 `node_refs`。必须新建 blueprint version，并同步 plan schema、task envelope schema、默认入口、历史兼容状态和新 session fixture；未完成旧 session 不自动迁移。
- task envelope 与业务 payload 只能引用任务创建时已 materialized 且 hash 可验证的对象。若产品链要求“先诊断后生成”，必须先产生诊断所需的真实前置 revision；预填未来 draft / beat / asset ID 统一归为 `future_artifact_reference` 并在 submission build 前阻断。
- 同一 artifact type 在一条 session 中连续产生多个 current revision 时，submission 的 `output_revision` 必须从 artifact commit registry 声明的 payload revision 字段派生并单调前进；不得固定 revision 1，也不得为绕过 pointer conflict 手改 current pointer。
- replan 中的 `stale_replanned / skipped` 必须是可恢复的路由终态，但不得进入 `completed_step_ids` 或自主完成计数；投影器与 replan fixture 必须使用同一 terminal 语义，新分支不得把已跳过的旧 downstream 当作待完成 prerequisite 再次调度。
- 同一 artifact ID 的后续 revision 必须使用独立 revision 文件与独立 lineage 文件；不得让 revision 2 覆盖 revision 1，或因单一 lineage 路径产生假 conflict。freshness reversal 在激活新 plan 前必须先物化新的 revalidation request，不能让新 research 复用旧 request / decision。
- 两阶段业务对象必须把阶段约束编译进 adapter / runtime。直供稿 `semantic_only content_beat_map` 只供结构诊断，后续必须新建 `structure_bound` revision；视觉、口播质检和最终交付不得消费 semantic-only 临时对象。
- PowerShell 禁止把函数参数命名为自动变量（尤其 `$Input`）；调用同进程 `.ps1` 后不得假定 `$LASTEXITCODE` 存在，优先检查 `$?` 或显式返回对象。parser pass 后仍须执行真实入口 fixture。
- PowerShell 可执行入口的依赖完整性必须在新的 `-NoProfile` 子进程中验证；validator 预先 dot-source 的 helper 只能证明同进程函数可用，不能替代 standalone entry fixture，否则会掩盖入口漏加载依赖。
- checker 必须按字段语义区分正文、ID、digest 与路径，不能把非路径文本送入路径存在性检查；checker 失败先分类 workflow / fixture / checker / environment，再决定是否改业务产物。
- checker 选择兼容分支必须依据 schema ID、contract set 或 lifecycle 等语义身份，不得枚举 Skill 的补丁版本号；Skill 正常升版后落入 legacy 分支属于 checker false failure，必须有当前合同正例覆盖。
- checker 的静态文档 / CONTRACT 覆盖检查不得把上一版 `contract_version` 或 artifact patch version 写成永久 current token；current 版本必须由合同状态 registry 或本轮 schema identity 派生，历史 replay 另设兼容断言。版本升级后旧 checker 因硬编码版本失败，归因为 `checker_contract_identity_drift`，不能误判 workflow。
- 非终态返修会在首次请求后立即改变 current plan / next node；重复请求幂等与单 active request 检查必须先于“final human gate 仍是 current”守卫，并按原始 target / change class / instruction 归一化比较。否则同一请求在重开后会被误拒绝，不能仅靠源码字符串 fixture 声称 reconcile 已完成。
- 视觉覆盖账本记录的是生产前决策，不得在资产生产完成后继续把其中的 `planned / waiting_assets` 当成交付现状。candidate 必须由当前 `image_asset_set` 和逐 task 资产绑定派生 `asset_status`、materialized count 与 `visual_delivery_readiness`；专项 fixture 必须覆盖“账本等待、资产集已就绪”的正常状态迁移。
- HTML 引用检查必须区分导航超链接与资源加载：经 HTML 编码的 HTTP(S) 公开证据 `href` 可以保留，外部 `src`、`javascript:`、`data:` 和 `mailto:` 仍须阻断。不得为了通过本地资源门禁删除产品合同要求的公开来源链接。
- 封面视觉通过必须逐 rendition 绑定官方 `cover-visual-review` schema、rendition ID / revision、surface profile、成品与预览 SHA256，并记录真实栅格目检；自定义“看过了”JSON 或全局 review 不能进入 candidate。
- deterministic renderer 的幂等输入必须覆盖业务输入、renderer 与 template digest；模板变化不得复用旧页面。最终 HTML 变更至少做桌面与移动 viewport 可视检查，防止卡片横向溢出。
- 热点稿的 `visual_need_analysis` 不能只消费文案链。任务信封还必须携带 current `hotspot_research_set` 与 `selected_topic_source`；所有 `source_bound_evidence` 的 source record ID 必须同时存在于研究集和已选题源的 monitoring refs。缺少上下文或 ID 不匹配必须在视觉生产前阻断，不得由下游截图 bundle 偷换来源。
- nullable route 字段只要求属性存在，并按 source class 校验 null / non-null 组合；不得用统一的“非空字符串”检查制造不可满足合同。renderer 声称支持 annotation / overlay 合同时，专项正例必须证明 renderer 实际消费定位区域、强调样式和事实 / 解读分层字段，不能只证明 Schema 与 validator 认识这些字段。

测试 / dry-run / regression 任务必须区分问题归因：

```text
workflow 缺陷
sample / fixture 缺陷
checker / tool 缺陷
environment / profile 缺陷
not_tested 范围
```

不能把 checker 报错误判为 workflow 失败，也不能把 `pass_with_warnings` 说成完全通过。测试结束必须写回状态记录，并在报告里说明真实账号数据、真实图片生成、外部 API、发版和 GitHub 发布是否实际执行。

环境兼容测试报告还必须说明：

```text
os_build / architecture / filesystem
powershell_host / version / native_argument_mode
project_root_length / longest_target_length / whitespace / unicode
execution_policy / MOTW / LongPathsEnabled（只读）
profile_loaded / optional_module_present / network_used
source_clone / release_zip / archive_manifest 验证范围
每个能力轴的 pass / fail / not_tested / not_certified
失败归因与可恢复动作
```

发版候选包不得散落在根目录。公开候选包、zip、sha256、release gate 报告和 release 检查报告必须归入版本化目录：

```text
releases/v{version}/
├── public_release/
├── taoge-creative-workflow-{version}-public-release.zip
├── taoge-creative-workflow-{version}-public-release.zip.sha256
├── release-gate-report.md
└── release-gate-report.json
```

根目录只允许保留版本治理源文件和入口文档，不保留新生成的发版 zip、hash 或临时检查报告。历史遗留根目录发版产物发现后应迁入 `releases/v{version}/` 或删除重建。

### GitHub 开源发版完成定义

开源发版不是 push 完就结束。`release_state=github_release_published` 只能在以下闭环全部完成后写入：

```text
1. 本地公开包已构建到 releases/v{version}/，zip 和 sha256 同步生成。
2. validate-public-release / validate-public-entry-doc-review / validate-alpha-expression / validate-release-gate 已跑通，或明确记录剩余人工门禁。
3. release commit 已创建。
4. tag 已创建并推送到 GitHub。
5. main 已推送到 GitHub。
6. GitHub Release 页面已创建。
7. zip 和 .sha256 已作为 Release assets 上传。
8. 从外部打开 GitHub 仓库页面、Release 页面、tag 页面，确认页面可访问、资产可见、描述和版本正确。
9. 用 GitHub 搜索或直达 URL 做一次外部可发现性审计。
10. 检查公开 tag 源码边界：`git ls-tree -r v{version}` 不得包含真实 `accounts/`、`indexes/` 或真实账号名；GitHub 自动 Source code zip 不得成为真实样例泄漏源。
11. 回到本地执行小扫地：确认工作区只剩被 .gitignore 管理的本地运行证据、support logs、releases、外部资料缓存等；根目录无散落 zip、hash、临时检查报告。
12. 更新 `工作流状态记录.md`、`release-checklist.md` 和必要的 release_record。
13. 最终回复说明 GitHub 仓库、Release URL、commit、tag、包 SHA256、已审计项、未完成项。
```

如果缺少 GitHub token / GitHub CLI / remote / 页面权限，只能写：

```text
publish_status=publish_ready_waiting_human 或 publish_blocked
```

不得把“本地 tag ready”“main pushed”或“zip 已生成”说成 GitHub Release 已完成。

不得只检查手工上传的 release zip，而忽略 GitHub 自动生成的 Source code zip / tar.gz。只要公开 tag 源码仍包含真实账号档案或真实运行索引，就不能进入 `github_release_published`。

### GitHub 发布踩坑防复发规则

以下规则来自 `v0.1.0-alpha.2` 实际发版事故复盘，后续公开发版必须逐条检查，不得凭感觉跳过。

#### Token 与权限

```text
1. Windows 系统环境变量新写入的 GITHUB_TOKEN，不一定会被当前 Codex / shell 进程继承。
2. 判断 token 是否存在时，必须同时检查当前进程、User 环境变量和 Machine 环境变量。
3. 当前进程读不到但 User 环境变量存在时，可以临时注入当前进程；长期使用必须重启 Codex / shell。
4. 修改普通仓库内容需要 repo 权限；修改 `.github/workflows/` 需要额外 workflow 权限。
5. token 不得扩大到 packages、org、public_key、repo_hook 等无关权限。
```

如果 GitHub API 能读仓库、能 push 普通文件，但更新 `.github/workflows/` 返回 404 / forbidden，应优先怀疑缺少 `workflow` scope，而不是仓库不存在。

#### GitHub Actions 与构建路径

```text
1. build-public-release.ps1 的输出目录发生变化时，必须同步检查 `.github/workflows/*` 中的校验路径。
2. 远端 Actions 红叉不是“小问题”；公开仓库页面会直接暴露它，必须定位到具体 step。
3. 本地 validate 通过不等于远端 CI 通过；发版闭环必须查看 GitHub Actions 最新 run。
4. Release zip 干净不代表 Source code zip 干净；Source code zip / tag 源码必须单独审计。
5. workflow 修复完成后，必须等待 GitHub Actions 最新 run 进入 `completed / success`，不能只说“已提交修复”。
```

#### 本地 / 远端 Git 对齐

如果因为 SSH / HTTPS 推送失败，临时使用 GitHub API 写入远端 main 或 workflow 文件，必须在发版后执行本地对齐：

```text
1. 先确认本地 `git status --short --branch` 无未保存改动。
2. 通过 GitHub API 或直连 `ls-remote` 确认远端 main 最新 commit。
3. 如本机全局 Git 配置存在 github.com -> 镜像站 insteadOf，直连审计可临时使用空 GIT_CONFIG_GLOBAL；不得随意永久修改用户全局配置。
4. fetch 远端 main 到 `refs/remotes/origin/main`。
5. 只在工作区干净、且确认远端是正确发布态时，才允许将本地 main 对齐到 origin/main。
6. 重新拉取公开 tag，确认本地 tag 与远端 tag 一致。
7. 删除临时审计文件，只保留 `.gitignore` 管理的 accounts / indexes / releases / support-logs / 外部资料缓存。
```

公开 tag 默认保持发布点；main 上的发版后 CI / 文档修复不应强行挪动已发布 tag。若必须移动 tag，只能按“发布不可变原则”处理并记录原因。

#### 远端页面审计顺序

每次 GitHub 发版或修复后，至少按以下顺序复核：

```text
1. GitHub repo API：description、visibility、default_branch、topics、issues。
2. GitHub Release API：tag、prerelease、assets、download URL。
3. GitHub tree API：不得存在 `accounts/`、`indexes/` 或真实账号 / 真实行业样例污染路径。
4. GitHub Source code zip：下载并扫描真实账号、真实 session、真实行业样例污染词。
5. Release 上传 zip：下载并校验 sha256。
6. GitHub Actions：最新 run 必须 success；若失败，必须拉日志定位 step。
7. 本地小扫地：工作区 clean；只允许剩余 `.gitignore` 管理的本地私有 / 缓存区。
```

### GitHub 发版成熟度规则

本项目的 GitHub 发版按成熟开源项目的轻量规则执行：先保证版本号、变更说明、资产可信、页面可读，再谈传播和外部试用。

#### 版本号与升级路径

默认遵循 SemVer 口径：

```text
vMAJOR.MINOR.PATCH
vMAJOR.MINOR.PATCH-alpha.N
vMAJOR.MINOR.PATCH-beta.N
vMAJOR.MINOR.PATCH-rc.N
```

本项目当前处于 alpha 阶段。版本升级规则如下：

```text
alpha.N：给内部 / 小范围外部试用，允许快速验证文档、样例、checker、skill 编译口径。
beta.N：入口、样例、support log、checker 和主要 workflow 已被外部用户试跑，开始要求更严格的 CI / 分支保护。
rc.N：候选稳定版，只接受阻断级 bug、隐私 / 安全修复和文档误导修复。
stable：稳定版，发布后不可静默改 tag 或替换资产。
```

升级判断：

```text
PATCH：修 bug、修文档误导、修 checker、小范围兼容补丁。
MINOR：新增 skill、入口能力、样例体系、交付能力或明显增强 workflow。
MAJOR：字段、目录、入口路由、交付协议发生不兼容变化。
```

#### Draft-first 发布流程

成熟流程默认采用 draft-first：

```text
1. 先在本地构建 releases/v{version}/。
2. 创建或准备 GitHub Release draft。
3. 上传 zip 与 .sha256 到 draft。
4. 下载 draft / asset 或通过 API 校验资产大小、哈希、说明文本。
5. 确认 Release notes、README 首屏、INSTALL、CONTACT、SECURITY 和 release-checklist 口径一致。
6. 再 publish。
```

如果 GitHub 页面或 API 条件不支持 draft-first，必须在 `工作流状态记录.md` 中说明原因，并用“发布后立即审计”补足。

#### 发布不可变原则

公开发布后，默认不允许静默改 tag 或替换 Release asset。

```text
alpha：如发布后短时间内发现首页口径、资产缺失、hash 错误等发布级问题，可以修正 tag / asset，但必须记录原因、旧 hash、新 hash、审计结果。
beta：原则上不 force-update tag；如必须替换，必须写明 superseded reason，并优先发布 beta.N+1。
rc / stable：不得 force-update tag，不得静默替换资产；发现问题时发布新版本，或标记旧版本为 superseded / yanked。
```

不得为了“看起来干净”改写已经公开使用过的 tag。能发新版本解决的，优先发新版本。

#### Release notes 固定结构

每次公开 Release notes 至少包含：

```text
Summary：这一版是什么，适合谁用。
Status：alpha / beta / rc / stable；是否 prerelease。
What changed：Added / Changed / Fixed / Removed / Security，按需保留。
Known limits：不能做什么，哪些能力只是样例 / checker / prompt fallback。
Install / Upgrade：下载、校验、升级注意事项。
Assets：zip 名称、sha256、是否含真实账号数据。
Checks：本地 checker、页面审计、下载审计、外部测试状态。
Feedback：Issue / support log / 联系方式。
```

Release notes 是给人看的，不得直接用 commit log 或内部状态记录替代。

#### 发布事故与撤回

如果发布后发现以下问题，进入发布事故处理：

```text
privacy_leak：真实账号、真实 runs、密钥、cookie、私密路径泄露。
asset_corrupt：zip 下载失败、hash 不匹配、包结构错误。
misleading_release：README / Release notes 对成熟度、能力、自动发布边界有误导。
security_issue：安全策略、权限、token、供应链风险。
```

处理顺序：

```text
1. 先阻止继续扩散：必要时删除有问题的 Release asset，或把 Release 标记为 pre-release / withdrawn / yanked。
2. 在 `工作流状态记录.md` 记录事故类型、影响范围、处理动作。
3. 修复后优先发布新版本；只有 alpha 发布级口径修正才允许记录后替换同版本资产。
4. 在 Release notes 或 CHANGELOG 标记 superseded / yanked / security_recalled。
```

#### 安全成熟度分层

本项目不把 alpha 伪装成生产级供应链，但每个阶段必须诚实说明安全能力：

```text
alpha：必须有 MIT / SECURITY / CONTACT / sha256 / 页面审计 / 下载审计 / 隐私净化检查。
beta：建议启用 main 分支保护、GitHub Actions 校验、最小权限 token、issue 模板和外部 tester 记录。
rc：建议 signed tag、CI 必过、release checklist 全 pass、外部 dry-run 记录。
stable：考虑 signed release、provenance / attestation、OpenSSF Scorecard 自查和明确的维护策略。
```

如果没有做到某项成熟度能力，不能在 README、Release notes 或最终回复里暗示已经做到。

### GitHub 仓库外显内容运营规则

GitHub 仓库首页是公开试用者的第一触点，不只是维护者索引。每次进入开源发布、README 修订、版本说明修订或外部传播口径修订时，都必须检查外显内容是否能被“中国内容创作者、略懂技术、想用 AI 做内容的人”快速理解。

#### README 第一屏

README 第一屏必须优先回答：

```text
1. 这是什么：给中文内容创作者使用的 AI 内容工作流 Skill。
2. 适合谁：懂一点 AI / Codex / GitHub，想把内容生产流程沉淀下来的人。
3. 不需要什么：不需要写代码，不是自动发布工具。
4. 怎么开始：下载 Release，解压，把项目文件夹交给 AI 读取，说启动语。
5. 会得到什么：选题卡、Brief、口播、画中画、质检、多平台物料、最终 HTML 交付页。
6. 当前边界：alpha / beta / stable 状态、不能自动发布、不能证明真实账号效果。
```

项目治理、目录索引、字段词典、状态记录等内容可以保留，但不得压在第一屏之前，避免外部用户误以为这是只给维护者看的内部工程文档。

#### GitHub description 与 topics

公开仓库 description 必须用用户能理解的表达，不只写工程能力。推荐当前口径：

```text
中文内容创作 AI Workflow Skill：选题调研、口播文案、画中画提示词、质检和 HTML 交付。
```

推荐 topics：

```text
taogeskill
codex-skill
ai-workflow
content-creation
chinese-content
short-video
creator-tools
prompt-engineering
```

description / topics 属于 GitHub 仓库元信息，不在普通 Git commit 中。若当前 token 或 CLI 没有权限修改，必须在 `工作流状态记录.md` 中写明 `github_repo_metadata_token_scope_missing`，并给出人类可手动填写的 description / topics。不得把 README 已更新误说成仓库元信息已更新。

#### Release 与 README 的关系

README 可以在 `main` 上持续优化，不等于重新发布历史 Release。

```text
仅更新 README / GitHub description / topics：提交 main，记录内容运营修订，不移动 tag，不替换 Release assets。
修正已发布 Release 的包内 README：必须按发布不可变原则处理；alpha 可记录后替换，beta / rc / stable 优先发新版本。
```

如果 README 第一屏写了最新版下载链接，必须指向当前推荐 Release。若推荐版本已被 yanked / superseded，README 必须同步改到新的推荐版本。

#### 外部搜索与发现性审计

每次发版或 GitHub 内容运营修订后，至少做一次发现性审计：

```text
1. GitHub 站内搜索 `taogeskill`。
2. GitHub 站内搜索 `taoge skill` 或核心中文定位词。
3. 直达仓库页，检查 description、topics、README 第一屏。
4. 直达 Release 页，检查下载入口和 Release notes。
5. 如普通搜索引擎尚未收录，只能写“外部搜索暂未稳定收录”，不能承诺用户一定能在公网搜索引擎搜到。
```

外部搜索审计结果必须写入状态记录；如果发现 description / topics 为空、README 首屏过于工程化、Release 下载入口不明显，应先修订外显内容，再继续传播。

---

## 三、进入项目先读

每轮任务最低必读：

```text
README.md
AGENTS.md
STATUS.md
PROJECT_MAP.md
docs/reference/文档治理与目录规范.md
docs/reference/人类引导与任务后导航规范.md
docs/reference/skill执行透明度与成熟度规范.md
交接物字段词典.md
工作流状态记录.md
```

按任务补读：

| 任务 | 继续读 |
|---|---|
| 跑热点 / 选题 | `docs/reference/账号档案完整性检查表.md`、`docs/reference/产品与活动对象档案.md`、`docs/reference/热点搜索来源池.md`、`docs/reference/调研运行记录.md`、`docs/reference/热点候选池.md`、`docs/reference/热点评分表.md`、`docs/reference/自媒体选题库.md` |
| 写 Brief | `docs/reference/内容Brief记录.md`、`docs/reference/内容形式类型与载体字典.md`、`docs/reference/文案策略矩阵.md` |
| 写口播 | `docs/reference/内容Brief记录.md`、`docs/reference/热点文案Skill方法论与SaaS承接设计.md` |
| 做画中画 | `交接物字段词典.md`、`docs/reference/热点文案Skill方法论与SaaS承接设计.md`、`docs/reference/R3-图片资产执行规范.md`、`外部资料/` |
| 做封面成品 / 封面加字 / 平台封面适配 | `交接物字段词典.md`、`docs/reference/R3-图片资产执行规范.md`、`skills/cover-design-compiler/SKILL.md` |
| 做质检 | `docs/explanation/dbskill质检记录.md`、全局 `dbskill-dontbesilent2025` 资料 |
| 做平台包装 | `docs/reference/内容形式类型与载体字典.md`、`docs/reference/文案策略矩阵.md`、`工作流状态记录.md` |
| 做最终交付页 / 图片降级设计 | `docs/explanation/最终交付页与图片降级策略.md`、`docs/reference/文档治理与目录规范.md` |
| 复盘 workflow 工程缺陷 / 修订交付规则 | `docs/explanation/工作流工程缺陷复盘与修订方案.md`、`docs/explanation/最终交付页与图片降级策略.md` |
| 接着上次 | `工作流状态记录.md`，再读 `current_artifact` 指向的账号/session 交接物 |
| 文档治理 / 迁移 | 全局 `文档治理与知识收口协议.md`，再读 README 索引 |

### 当前状态优先规则

用户说“沉淀一下 / 继续按 agents / 继续产品开发 / 修订这个产品”时，必须先读 `STATUS.md` 和 `工作流状态记录.md` 的当前状态，再判断当前工作是否已有承载文档。

如果当前状态、`current_artifact` 或既有路线图已经指向明确文档，默认回写该文档和它的直接入口，不得新开并列文档。新建文档只允许在以下情况发生：

```text
1. 现有路线图 / 产品入口 / reference 都没有承载位置。
2. 用户明确要求新建文档。
3. 既有文档职责边界不允许承载该内容，并且已在路线图或 PROJECT_MAP 中登记新文档用途。
```

发现自己准备新开文档前，必须先回答：

```text
这条内容能不能进入 current_artifact？
能不能进入当前路线图？
能不能进入 R1 / R2 / R3 / R4 对应产品入口？
如果不能，为什么不能？
```

回答不清楚时，不新建文档，先回写既有路线图或向用户说明需要新增承载文档的理由。

---

## 四、任务路由

| 用户意图 | 默认动作 | 必停条件 |
|---|---|---|
| “热点 skill / 涛哥创作工作流 / 下一步” | 进入 `skills/propagation-router` | 当前交接物不清、账号不清 |
| “第一次用 / 没账号 / 新建账号 / 新增账号 / 帮我建账号” | 进入 `skills/account-onboarding` | 用户拒绝提供账号最小信息 |
| 找热点 / 评热点 | 进入 `skills/hotspot-topic-research` | 没有账号档案、产品/活动对象不清、P0 不齐，或本轮换账号后尚未做账号档案对齐确认 |
| 选了某个选题 | 进入 `skills/content-brief-compiler` | `topic_card` 字段不完整 |
| Brief 已通过 | 自动进入 `skills/copywriting-draft-writer`，不得再要求涛哥回复“继续写口播” | 内容形式不是第一阶段支持的短视频口播且未确认 |
| 口播草案已出 | 进入 `skills/talking-head-image-pip`；`visual_need_analysis` pass 后自动完成 prompt 编译并生成全部 accepted Image 2 任务，不等待图片数量或审美确认 | 前 5 秒 Hook 评分不足，或事实 / 来源 / 隐私 / 版权风险无法在候选 accepted 前解决 |
| 文案/画面能不能发 | 进入 `skills/copywriting-quality-review`；质检通过且无人工门禁时自动进入平台包装，不得要求涛哥回复“继续做分发包” | 事实风险、产品承诺风险或灰产误解风险未清 |
| 生成平台标题/描述/话题 | 进入 `skills/platform-packaging-adapter` | 质检未通过 |
| 平台包装完成 / 重做封面 / 封面加字 | 进入 `skills/cover-design-compiler`；完成后自动进入 `copywriting-quality-review(cover_review)` | 缺平台标题、缺封面底图且不能降级、封面风险未清 |
| 选题确认后生成最终交付 | 自动完成 Brief、口播、画中画、联合质检、平台包装、封面成品或 prompt_only、封面专项质检、`content_delivery_record`、`skills/final-delivery-builder`，不得在平台包后再问“确认采用” | 质检高风险、缺少必要图片且未标记降级状态 |
| 最终 HTML 完成后的发布前验收 | 更新 `workflow_session_record`，引导用户人工发布、局部返工、归档或导出转交包 | 用户意图不清 |
| 需要发给别人 / 网盘 / 客户交付 | 进入 `skills/final-delivery-builder` 生成 `deliverables/export/{session_id}/` 可转交包 | 包内链接不能闭合 |
| “不好用 / 导出日志 / 反馈日志 / support log” | 进入支持日志导出流程，默认使用 `tools/export-support-log.ps1` 自动选择最近 run；用户提到账号或选题时用 `-Account` / `-Topic` 筛选；生成 `support-logs/SUPPORT-{session_id}-{timestamp}.zip` | 找不到 run，或账号 / 选题匹配到多条且无法判断 |

---

## 五、交接物门禁

跨 skill 只能按 `交接物字段词典.md` 的标准交接物流转：

```text
account_profile
-> product_profile / campaign_profile
-> research_run_record
-> hotspot_candidate
-> topic_card
-> content_brief
-> draft
-> static_visual_director_plan / visual_plan / visual_text_plan
-> image_prompt_set / image_generation_record / image_asset_set
-> static_visual_quality_gate / visual_text_quality_gate
-> quality_review
-> platform_package_input
-> platform_package
-> content_delivery_record
-> cover_design_package
-> cover_composition
-> cover_quality_gate
-> final_delivery
-> human_confirm / done
```

不得跳过：

```text
账号档案 P0 检查。
换账号后的账号档案对齐确认。
产品/活动对象边界检查。
调研运行记录。
Topic Gate。
内容 Brief。
文案 + 视觉联合质检。
内容交付记录。
最终 HTML 验收页。
工作流状态记录。
skill 执行透明度记录。
```

后台产物落盘规则：

```text
账号档案放 accounts/{账号名}/account_profile.md。
根目录文件只做方法论、模板、总索引和跨账号汇总。
每轮真实内容的完整交接物必须放入 accounts/{账号名}/runs/{session_id}/。
中间产物放 intermediate/，最终交付物放 deliverables/。
最终人类验收入口优先放 deliverables/final-delivery.html。
实际画中画图片放 assets/images/；如果无法生成，必须记录 image_status，不得假装已有图片。
项目内验收页只能算 project_local；如果用户要转交，必须生成 deliverables/export/{session_id}/，不得把依赖原目录的 HTML 单独交付。
工作流状态记录里的 current_artifact 必须指向 accounts/{账号名}/runs/{session_id}/ 下的具体文件。
根目录汇总表和账号/session 具体产物冲突时，以账号/session 具体产物为准，再修正汇总表。
```

每轮创作开始前必须回答两件事：

```text
account_profile：谁来说，账号人设、受众、母题、语气和禁区是什么。
product_profile / campaign_profile：这次要说哪个产品、服务、活动或观点对象，能说什么，不能说什么，希望用户下一步做什么。
```

如果本轮账号和上一轮账号不同，或用户明确说“换账号 / 给另一个账号做”，即使账号档案已存在且 P0 齐全，也必须先做一次账号档案对齐确认。对齐不是让用户填表，而是由 AI 读取 `accounts/{账号名}/account_profile.md`，用人话摘要当前档案，并说明为什么要确认：账号实际情况可能发生偏移，若继续用旧画像，选题、语气、产品露出和禁区都可能不符合预期。

如果用户首次使用、没有任何账号档案、明确要求新建 / 新增账号，或指定账号不存在，必须进入 `skills/account-onboarding`。如果已有账号档案但用户没有指定本轮账号，先让用户选择账号，不默认新建。不要要求用户理解字段表，也不要只说“缺少账号档案”。AI 应一次最多问 3 个口语问题，创建 `accounts/{账号名}/account_profile.md`、`README.md`、`index.md` 和 `runs/`，再用人话摘要给用户确认。用户回复“认可 / 同意 / 没变化 / 就按这个”后，自动回到 `propagation-router` 检查产品 / 活动对象。

用户回复“认可 / 同意 / 没变化 / 就按这个”即视为 `account_profile_confirmed_for_session = yes`，自动进入产品/活动对象检查和热点研究；用户指出变化时，先更新账号档案或标记待确认，再继续。

如果产品/活动对象没有明确边界，不得进入正式热点研究；只能先补对象档案或把本轮标记为概念探索。

每轮生产链路还必须回答第三件事：

```text
execution_trace：本轮哪些动作是 skill_defined，哪些是 agent_orchestrated，哪些是 user_decision 或 environment_capability。
```

如果 agent 在运行中补了流程、补了字段、补了目录、补了引导语或补了判断，必须写入 `intermediate/00-execution-trace.md`，并标记 `agent_assist_level`。未来发布 skill 时，不能把 agent 扶跑能力算成 skill 独立能力。

## 六、字段一致性编译门禁

字段一致性是产品定义和 skill 编译的硬闸门，不是运行时的口头提醒。对标成熟 workflow 的 contract / schema / state / asset check 做法，本项目每次进入产品开发、skill 编译或公开包同步时，都必须先保证交接字段同源。

### 6.1 产品开发字段准入

产品定义阶段新增能力、交接物、状态、样例或用户引导时，必须先回答：

```text
新增了哪些 artifact？
新增了哪些标准技术字段？
这些字段是否已存在于 交接物字段词典.md？
是否产生了同义字段、中文字段替代技术字段或不可拆的聚合字段？
状态值是否已有允许值？
哪个 skill 生产，哪个 skill 消费？
是否需要 CONTRACT、模板、sample、manifest 或人类引导同步？
```

如果答案不清楚，只能停在产品草案，不能进入 skill 编译。新增字段必须先写入 `交接物字段词典.md`，再修订对应产品文档和下游 skill。

### 6.2 Skill 编译字段闸门

任何 skill 编译完成前，必须核对以下文件的字段名、状态值、来源 ID、路径字段和 `next_skill` 是否一致：

```text
交接物字段词典.md
对应 skills/{skill}/CONTRACT.md
对应 skills/{skill}/SKILL.md
相关模板 / 根目录汇总表
docs/reference/人类引导与任务后导航规范.md
sample / manifest / execution_trace
public_release/ 同步文件
releases/v{version}/ 候选包目录
```

不得出现：

```text
CONTRACT 使用一个字段名，SKILL 使用另一个字段名。
产品文档有字段，但字段词典没有登记。
字段词典有状态值，但模板或样例使用旧状态。
中文展示名替代技术字段。
把多个可检查字段塞进 candidate_funnel / 状态 / 结果 / 下一步 这类模糊字段。
只更新源文件，不同步公开候选包。
```

### 6.3 字段差异报告

每次产品开发进入 skill 编译，或每次 skill 编译收口，都必须在 `工作流状态记录.md` 写出字段差异摘要：

```text
field_gate_status：pass / pass_with_warnings / fail
new_artifacts：
new_fields：
changed_fields：
deprecated_fields：
allowed_status_values：
producer_skill：
consumer_skill：
checked_files：
blocking_mismatches：
warnings：
next_validator_need：
```

`field_gate_status=fail` 时，不得宣称 skill 编译完成，不得进入 sample run，不得同步为可发布候选。`pass_with_warnings` 只能进入人工复核或小样本验证，不能宣称 L3。

### 6.4 P3 Validator 预留

当前字段一致性检查可以先由 agent 按清单执行，但必须记录为手工字段门禁。后续 P3 validator / build 产品化时，必须把字段一致性纳入脚本化检查，至少覆盖：

```text
字段词典是否登记新增字段。
CONTRACT / SKILL / 模板 / sample 是否字段同名。
状态值是否属于允许集合。
source_*_id 是否贯穿上下游。
next_skill 是否指向存在的 skill 或 human_confirm / done。
public_release 是否和源文件字段一致。
```

## 七、状态模型

本项目有两层状态，不能混用：

```text
project_stage：项目级状态，记录本项目处于迁移、测试、可用、暂停或归档。
workflow_usage_state：内容级状态，记录某条内容处于草案、审核、可人工处理、已确认、已归档或已放弃。
```

状态写入位置：

```text
project_stage -> STATUS.md
workflow_usage_state -> 工作流状态记录.md / content_delivery_record
```

如果项目级状态仍是迁移中或测试中，不得把本项目描述为稳定生产工具；如果最终 HTML 尚未生成，不得把后台 Markdown 交接物说成“最终交付物”。

最终交付状态必须区分：

```text
delivery_page_mode：project_local / portable_bundle / standalone_html
final_delivery_status：html_ready / bundle_ready / standalone_ready / needs_export / blocked
image_assets_status：all_generated / partially_generated / pending_external / generation_failed / manual_required / mixed / not_required
export_status：not_requested / export_ready / export_needs_fix / export_blocked
```

`final-delivery.html` 生成不是整条 workflow 的静默结束，而是进入 `human_final_review`。最终回复必须给用户 5 类可直接回复的处理方式：

```text
1. 满意：认可 / 就按这个 / 记录为已确认。
2. 局部返工：只改抖音标题 / 回到口播改前 5 秒 / 回到画中画改首屏图 / 平台包装重来。
3. 转交：导出转交包 / 导出单文件 HTML。
4. 发布记录：我已人工发布，记录发布结果。
5. 放弃或暂缓：归档今天不发 / 放弃这条。
```

用户提出局部返工时，不得要求用户再说“继续”。必须写入 `delivery_status=delivery_needs_fix`、`revision_path` 和 `next_skill`，回到对应上游修订，修完后自动重新生成 `final-delivery.html` 给用户二次验收。

---

## 八、人类引导与任务后导航规则

执行前先遵守 `docs/reference/人类引导与任务后导航规范.md`。

需要人类确认时，必须给口语化引导语。不要让用户猜字段、猜状态、猜下一步。用户已经明确选择时，直接流转，不做二次确认。

必须输出：

```text
human_prompt
human_reply_examples
recommended_action
auto_next_action
task_after_navigation
```

推荐写法：

```text
最终 HTML 验收页已经生成，你可以直接看文案、图片和发布物料。

如果满意，可以回复“认可”或“记录为已确认”；如果要小修，直接说“只改抖音标题”“回到口播改前 5 秒”“回到画中画改首屏图”或“平台包装重来”，我会回到对应环节修完并重新生成 HTML；如果要发给别人，回复“导出转交包”或“导出单文件 HTML”；如果已经人工发布，回复“记录发布结果”；如果今天不发，回复“归档今天不发”。
```

任务后导航必须像 dbskill 一样，先读本轮结论，再推荐 2-3 个下一步，并解释为什么。不能只说“完成了 / 下一步继续 / 你想怎么做”。

禁止写：

```text
请确认。
请选择状态。
是否进入下一步？
是否继续？
请回复继续写口播。
等待人工确认。
```

---

## 九、调研与事实边界

1. 需要“今天 / 最新 / 热点”时必须联网或使用明确来源，并记录来源、时间、热度信号和事实等级。
2. 不把单来源传闻写成事实。
3. 不硬蹭热点；桥接链必须说明每一跳依据和最虚一跳。
4. 涉及客户反馈、申请表、聊天记录、测试机反馈时必须脱敏。
5. 本项目不提取、不保存、不传播手机号、微信号、地址、身份证、车牌等可识别自然人身份的信息。
6. `research_run_id` 必须贯穿后续交接物；缺少来源 ID 时，只能算草案，不能算可交付内容。
7. 导出反馈日志包时默认使用 logs_only，不包含完整文案、最终 HTML、真实账号 snapshot、生成图片或客户记录；只有用户明确允许，才可使用 `-IncludeContent`。
8. 用户不需要知道 `session_id`。导出日志时，优先自动找当前 / 最近 run；如果用户说了账号或选题，用账号名、选题关键词、时间和当前阶段匹配。只有匹配不唯一时，才用人话列 2-5 个候选让用户选。

---

## 十、完成定义

一次 workflow 小循环完成，至少满足：

```text
当前交接物字段完整。
状态值符合交接物字段词典。
产品定义和 skill 编译已通过字段一致性门禁，或明确记录 field_gate_status。
account_profile 和 product_profile / campaign_profile 已明确。
research_run_id 已贯穿到当前交接物。
需要人类选择时给出口语化引导语。
工作流状态记录已更新。
任务后导航给出 2-3 个下一步，并解释为什么。
没有把草案误写成其他产品正式规则。
选题确认且质检通过后，必须自动生成 final-delivery.html 或清楚说明为什么无法生成。
如果用户需要转交，必须有 portable_bundle 或 standalone_html，且不能有指向原 session 外部的断链。
```

测试类小循环还必须满足：

```text
已声明 build profile。
已区分 pass / pass_with_warnings / fail / tool_error / not_tested。
已说明 workflow、sample、checker、environment 分别有没有问题。
新增或变更字段后，sample / manifest / execution_trace 已同步升级，或明确记录未同步原因。
测试摘要已落到允许的报告目录，不散落根目录。
```

如果形成其他产品的正式决策，必须回写到对应产品项目，不在本项目里静默定案。

# GitHub 开源上线检查清单

> 状态：active  
> 所属路线：R4 开源交付标准  
> 主责：作为 `public_release/` 候选包生成前后的发布门禁，检查入口、样例、隐私、安全、链接、成熟度和开源边界。  
> 边界：本文件不生成公开包、不推送 GitHub、不选择 License 类型、不接 CI。

---

## 1. 适用时机

当项目进入以下任一动作前，必须使用本清单：

```text
准备生成 public_release/。
准备整理 examples/sample-account 或 examples/sample-run。
准备重写公开 README。
准备给涛哥确认 GitHub 公开发布候选包。
准备创建远端仓库、打 tag 或发 release。
```

---

## 2. 发布阶段

| 阶段 | 允许做什么 | 禁止做什么 |
|---|---|---|
| r4_product_confirmed | 生成模板、检查清单、sample 规则 | 生成真实 public_release |
| r4_packaging_compiled | 准备 public_release 构建规则 | 推 GitHub |
| r4_public_release_candidate | 生成候选包并通过检查 | 自动发布、登录平台、接外部 API |
| r4_github_publish_waiting_human | 等涛哥确认远端、License、tag | 默认推送 |

---

## 3. P0 阻断项

任一命中即 `release_status = blocked`：

```text
缺 README.md。
缺 AGENTS.md。
缺 PROJECT_MAP.md。
缺 LICENSE 或 license_status != confirmed。
缺 public-manifest.yaml。
缺 examples/sample-account 或 examples/sample-run。
public_release 内含真实 accounts runs。
public_release 内含真实账号未脱敏档案。
public_release 内含真实客户资料、手机号、微信号、车牌、身份证或聊天记录。
public_release 内含 API key、Cookie、token、密钥或登录态。
public_release 内含外部资料 zip / cache / 未授权素材。
README 宣称未验证能力，如完整真实测试通过、L3、1.0、已发布。
public-manifest.yaml 与 README 的成熟度或边界冲突。
HTML / Markdown 链接断。
sample 使用真实账号名、真实客户或真实热点隐私。
公开包没有明确“不自动发布、不登录平台、不接外部 API”。
```

---

## 4. 检查分组

### R4CHK-001 入口完整

必须存在：

```text
README.md
AGENTS.md
PROJECT_MAP.md
public-manifest.yaml
```

### R4CHK-002 社区健康文件

必须存在：

```text
LICENSE
CONTRIBUTING.md
CHANGELOG.md
SECURITY.md
CODE_OF_CONDUCT.md
```

License 类型由涛哥单独确认。未确认前：

```yaml
license_status: pending
release_status: blocked
```

### R4CHK-003 AI 可读入口

必须满足：

```text
AGENTS.md 写清项目边界和不可做事项。
PROJECT_MAP.md 能索引 docs、skills、examples、templates。
public-manifest.yaml 有 entrypoints.human / agent / map。
```

### R4CHK-004 sample 完整

必须存在：

```text
examples/sample-account/
examples/sample-run/
examples/README.md
```

sample 必须声明：

```yaml
sample_only: true
contains_real_account: false
contains_real_customer_data: false
generated_image_path_verified: true / false
```

### R4CHK-005 链接闭合

必须检查：

```text
README.md 链接。
PROJECT_MAP.md 链接。
examples 内 Markdown 链接。
sample final-delivery.html 链接。
public-manifest.yaml 指向的路径。
```

### R4CHK-006 隐私净化

禁止出现：

```text
真实账号 runs。
真实客户资料。
手机号、微信号、身份证、车牌。
真实发布链接。
平台后台截图。
```

### R4CHK-007 密钥净化

禁止出现：

```text
API key
Cookie
token
secret
private key
.env
平台登录态
```

### R4CHK-008 本机路径净化

公开包运行入口不得依赖：

```text
盘符工作区绝对路径
用户主目录绝对路径
file://
```

产品说明文档可以保留本地事实路径，但 `public_release/README.md`、`public-manifest.yaml` 和 sample 运行路径不得依赖本机绝对路径。

### R4CHK-009 成熟度诚实

必须写清：

```text
release_channel: alpha / beta / stable
workflow_maturity: l2_8 / l3_candidate / l3
verified_paths:
unverified_paths:
unsupported_features:
```

不得把 R1-R4 文档闭合写成完整真实测试通过。

### R4CHK-010 发布边界

必须写清：

```text
不自动发布。
不登录平台。
不自动评论 / 私信 / 互动。
不接外部图片 API。
不保存 API key。
不包含真实账号生产数据。
```

---

## 5. release-checklist 输出

每次候选包检查必须生成：

```text
release-checklist.md
release_check_report
release_record
```

最小字段：

```yaml
release_check_id:
checked_at:
public_release_path:
source_commit:
release_status: pass / pass_with_warnings / blocked
blocking_items:
warning_items:
checks:
  R4CHK-001:
  R4CHK-002:
  R4CHK-003:
  R4CHK-004:
  R4CHK-005:
  R4CHK-006:
  R4CHK-007:
  R4CHK-008:
  R4CHK-009:
  R4CHK-010:
next_action:
```

对应标准交接物：

```yaml
release_check_report:
  check_report_id:
  check_scope: public_release / zip / release_candidate
  overall_result: pass / pass_with_warnings / fail / blocked
  privacy_scan_result:
  link_check_result:
  field_gate_result:
  contract_sync_result:
  release_state_result:
  zip_path:
  sha256_path:
  next_action:

release_record:
  release_id:
  release_state: release_candidate_built / release_commit_ready / tag_ready / remote_ready / github_release_published
  publish_status: not_published / publish_ready_waiting_human / published_to_github / publish_blocked
  human_approval_required: true
```

`release-checklist.md` 可以是人类可读清单，但 `release_check_report` 和 `release_record` 是 AI 接续真源。

---

## 6. human_prompt 规则

检查完成后，必须给人话导航。

如果通过：

```text
开源候选包检查通过。现在它只是 release candidate，还没推 GitHub。下一步你可以确认 License 和远端仓库，也可以先让我打开 public_release 给你复核 README 和 sample。
```

如果阻断：

```text
这次不能进入 GitHub 发布，因为命中了阻断项：{blocking_items}。我建议先修 {recommended_fix}，修完再重新跑 release-checklist。
```

---

## 7. 后续脚本化

当前 R4 alpha 允许本清单作为人工 / 半自动检查。  
后续可以脚本化为：

```text
tools/check-public-release.*
tools/build-public-release.*
```

脚本化前，本文件仍是发布门禁真源。

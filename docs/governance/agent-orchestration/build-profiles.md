# Build Profiles

> 状态：构建与数据边界规则
> 主责：区分开发、测试和公开生产包，避免真实账号数据、测试夹具、发版资产互相串台。
> 边界：本文件定义规则；脚本参数化属于后续编译任务。

---

## 三类 profile

| profile | 目的 | 允许读取 | 允许输出 | 禁止 |
|---|---|---|---|---|
| `dev` | 本地真实生产和维护 | `accounts/`、`indexes/`、`docs/`、`skills/`、`tools/`、`objects/` | `accounts/{账号}/runs/{session_id}/`、`support-logs/`、本地检查报告 | 直接公开发布 |
| `test` | 脱敏 dry-run / regression | `examples/`、`docs/tutorials/`、`templates/`、`tools/`、脱敏 `docs/` | sample reports、dry-run reports、临时 checker 报告 | 读取真实 `accounts/`、真实 `indexes/` |
| `public` | GitHub Release / 对外分发 | `README.md`、`AGENTS.md`、`PROJECT_MAP.md`、`docs/`、`skills/`、`templates/`、`examples/`、`tools/`、社区健康文件 | `releases/v{version}/public_release`、zip、sha256、release reports | 真实账号、真实 run、真实索引、本机路径、外部资料缓存 |

## Profile 选择

```text
用户说“给某账号做内容” -> dev
用户说“跑 sample / dry-run / 测试” -> test
用户说“发版 / GitHub / 构建包” -> public
用户说“导出反馈日志” -> dev，但输出 support log，默认不含内容细节
```

如果任务从 `dev` 切到 `public`，必须重新执行公开边界检查，不能复用 dev 结论。

## Public 构建硬门禁

`public` profile 必须满足：

```text
1. 不复制 root accounts/。
2. 不复制 root indexes/。
3. 不复制 support-logs/。
4. 不复制 offline_tester_packages/。
5. 不复制 外部资料/ 缓存。
6. 不复制 releases/ 历史输出到包内。
7. 不保留 D:\OpenClaw、C:\Users、file:// 等本机路径。
8. public release zip 和 GitHub Source code zip 分别审计。
9. GitHub Actions 最新 run 必须 success。
10. 已发布 tag 不因 main 后续修复而静默移动。
```

## 测试夹具边界

当前项目还没有独立 `test-fixtures/`。过渡期规则：

```text
examples/        对外最小样例
docs/tutorials/  可读教程和脱敏 dry-run 样本
tools/           检查器和构建脚本
```

后续如果测试样例继续膨胀，优先新增：

```text
test-fixtures/
```

并从 `docs/tutorials/` 迁出机器专用 fixtures，避免教程目录变成测试垃圾场。

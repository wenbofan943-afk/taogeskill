# State And Gates

> 状态：状态接续和门禁编排规则
> 主责：定义 agent 执行任务时如何读取状态、写回状态、处理 checkpoint、执行检查和收口。
> 边界：本文件不定义具体字段 schema；字段真源仍是 `交接物字段词典.md` 和各 skill contract。

---

## 状态读取顺序

```text
1. AGENTS.md
2. PROJECT_MAP.md
3. 工作流状态记录.md
4. 当前 task_type 对应 required reads
5. manifest.yaml / checkpoint / execution trace
```

如果 `工作流状态记录.md` 与账号/session 具体 manifest 冲突：

```text
以账号/session 具体 manifest 为准。
修正汇总状态记录。
记录冲突原因。
```

## 状态写回原则

每次小循环完成后至少写回：

```text
current_stage
current_artifact
session_status
field_gate_status
next_action
blocking_reason
```

真实内容产物写入：

```text
accounts/{account_slug}/runs/{session_id}/
```

公开样例写入：

```text
examples/
docs/tutorials/
```

发版产物写入：

```text
releases/v{version}/
```

## 门禁类型

| gate | 何时触发 | 通过条件 | 不通过 |
|---|---|---|---|
| `human_account_confirm` | 换账号 / 新建账号 | 用户认可账号摘要 | 回到 account onboarding |
| `human_topic_select` | 生成 3 个候选选题后 | 用户选一个，或明确全做进入 R2 | 不进入 Brief |
| `field_gate` | 产品定义、skill 编译、公开包同步 | 字段词典 / contract / skill / checker 同源 | 先修字段 |
| `branch_lock_gate` | 多选题 / 多分支 | parent / child / checkpoint 清楚 | 封锁旁支任务 |
| `image_capability_gate` | 画中画生成 | Codex 可出图则生成；否则提示词降级 | 记录 provider_state |
| `public_privacy_gate` | public build / GitHub release | 隐私扫描、source zip、release zip 均过 | 阻断发布 |
| `remote_release_gate` | push / tag / Release | GitHub 页面、assets、Actions、hash 均过 | 回到 release 修复 |

## 收口格式

最终回复必须说明：

```text
做了什么
产物在哪里
检查结果是什么
还有什么没做 / 不能做
用户下一步可以直接说什么
```

不得用“应该可以”“大概没问题”替代实际检查结果。

# Expected Agent Behavior

1. 读取 README、AGENTS、STATUS、PROJECT_MAP、字段词典和工作流状态记录。
2. 生成 `entry_router_request`。
3. 判断没有可用账号时，进入 `account-onboarding`。
4. 一次最多问 3 个口语化问题。
5. 不进入热点搜索，不生成文案。

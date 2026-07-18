# M6 Direct Certification Fixtures

本目录只服务 `M6-DIRECT-CERTIFICATION-0.1` 的离线控制面认证。

- `catalog.json` 固定 current direct route 的 25 个组件槽位、允许状态、输出合同和负例；
- `source-content.md` 是脱敏直供输入；
- `expected-final-delivery.html` 是确定性最终 HTML fixture；
- fixture adapter 只替代语义 worker、外部 activity 和人工回复的业务内容生成，不替代 coordinator；
- validator 必须通过真实 current session entry 建立 `kernel_v1_current` binding，再由独立 direct certification runtime 推进、等待、续跑、重建和 replay；
- 通过本套件只认证 direct 控制面，不认证真实账号、语义质量、网络、provider、真实人工决定、热点 route 或项目 L3。

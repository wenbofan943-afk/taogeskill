# Platform Packaging Adapter Contract

> Skill contract version: `0.6.0`
>
> Current payloads remain `platform-package-v0.1` for the compatibility node and `platform-package-v0.2` for `platform_package_h7`.

## Responsibility

This Skill consumes the current reviewed draft plus the current account snapshot and produces exactly one typed `platform_package` for the platforms selected by the account. Platform-specific references are knowledge modules, not separate workflow nodes or artifacts.

It does not rewrite the approved body, change factual claims, render covers, publish, log in, call platform APIs, or create delivery records outside the active node contract.

## Input and target selection

The task envelope must bind:

- current `draft`;
- current `script_visual_alignment_review`;
- current `account_snapshot`.

The only target-platform source is `account_snapshot.captured_fields.publishing_platforms`. Missing, empty, duplicate, or unsupported values block the submission. Chat text and platform defaults cannot replace the bound snapshot.

## Output invariants

- One semantic node emits one `platform_package`.
- `primary_platform` belongs to the selected target set.
- `packages[].platform` is unique and equals the selected target set exactly.
- Unselected platforms do not load knowledge and do not create empty cards.
- Package count is derived from the selected set.
- All platform cards retain the same approved body facts, evidence boundaries, content source, and account identity.
- `delivery_title`, video `title`, `cover_title`, `body_text`, `hashtags`, and `notes` keep distinct meanings.
- `package_status` and `next_skill` follow the active Schema and route registries.

## Conditional references

| Target value | Reference |
|---|---|
| `douyin` | `references/douyin.md` |
| `xiaohongshu` | `references/xiaohongshu.md` |
| `wechat_channels` | `references/wechat-channels.md` |
| `kuaishou` | `references/kuaishou.md` |

Kuaishou knowledge is isolated and can be loaded when selected, but selection must still pass the active payload and downstream capability registries. Unsupported current targets fail closed; they are never silently dropped.

## Machine truth

- Current components and ownership: `routes/component-catalog.json`
- Legacy R7 adapters: resolve `routes/compatibility-catalog.json` only through `tools/WorkflowCompatibilityLoader.ps1`
- Current payload: `templates/schema/r7/platform-package.v0.2.schema.json`
- Target parity validation: `tools/R8PlatformPackagingRuntime.ps1`
- Context loading: `routes/r8-skill-context-registry.yaml`
- Field semantics: `交接物字段词典.md`

Historical embedded R1/R7 guidance is isolated in `references/legacy-r1-r7-platform-packaging.md` and loads only for explicit legacy/replay contexts.

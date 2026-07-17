---
name: platform-packaging-adapter
description: Compile one reviewed short-video draft into the exact selected-platform package. Use when a current semantic task owns platform_package or platform_package_h7 and the account snapshot supplies target platforms. Keep the video body and facts stable while adapting only titles, cover titles, descriptions, hashtags, and manual posting notes. Do not publish, log in, call platform APIs, create cover renditions, or rewrite the core draft.
---

# Platform Packaging Adapter

## Current contract

```text
skill_contract_version: 0.6.0
primary_input: current draft + current alignment review + current account snapshot
single_output: platform_package
owned_nodes: platform_package, platform_package_h7
stop_after: one typed platform_package submission
```

Use [CONTRACT.md](./CONTRACT.md) for the compact human-readable contract. Machine truth remains in the current node registry, producer adapter registry, platform-package Schema, account snapshot, and field dictionary.

## Required sequence

1. Read the current task envelope and its bound draft, alignment review, and account snapshot.
2. Derive `target_platforms` only from `captured_fields.publishing_platforms`. Do not infer platforms from chat or default to all platforms.
3. Fail closed when the target set is absent, empty, duplicated, or not supported by the current machine contract.
4. Read only the platform references selected below.
5. Use [the platform package template](./assets/platform-package-template.md) only while assembling the typed output.
6. Submit exactly one `platform_package`; do not create one task or artifact per platform.

## Conditional platform knowledge

- Read [Douyin packaging](./references/douyin.md) only when `target_platforms contains douyin`.
- Read [Xiaohongshu packaging](./references/xiaohongshu.md) only when `target_platforms contains xiaohongshu`.
- Read [WeChat Channels packaging](./references/wechat-channels.md) only when `target_platforms contains wechat_channels`.
- Read [Kuaishou packaging](./references/kuaishou.md) only when `target_platforms contains kuaishou`.
- Read [the historical embedded contract](./references/legacy-r1-r7-platform-packaging.md) only when `contract_version in r1,r7 && mode in legacy,replay`.
- Read [the historical platform handoff contract](./references/legacy-r1-r7-platform-contract.md) under the same explicit legacy/replay condition.

Loading a Kuaishou reference does not override the active payload and downstream presentation registries. If the current registries do not support Kuaishou, return `blocked` with the capability gap; never omit it silently or emit an empty card.

## Shared packaging rules

- Preserve the same approved video body, factual claims, evidence boundaries, account identity, and content source across all selected platforms.
- `delivery_title` is the final delivery-page title. It is not a core promise, structure label, diagnosis sentence, or cover title.
- Keep `title`, `cover_title`, `body_text`, `hashtags`, and `notes` separate. Do not copy one string into every field as a shortcut.
- Adapt only the platform entrance layer. A platform package must not change the script thesis, facts, risk wording, visual evidence, or call-to-action meaning.
- `primary_platform` must be one selected platform.
- `packages[].platform` must be unique and equal the selected target set: no missing platform, extra platform, duplicate, or empty placeholder.
- Package count is derived from the selected target set, never from a fixture constant.
- Keep manual posting notes explicit. Never claim automatic publication, login, comments, private messages, analytics collection, or platform API access.

## Status and routing

- `package_pass` / `package_pass_with_warnings`: submit the current package and route to the current cover-design owner.
- `needs_revision`: keep the failure local when only packaging fields are wrong; route upstream only when the current draft, evidence, or alignment review is invalid.
- `blocked`: identify the missing input, unsupported target, or contract break. Do not fabricate a platform card.
- The platform split is knowledge loading only. It must not introduce workflow fan-out/fan-in or multiple semantic submissions.

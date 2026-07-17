---
applicability: current_only
load_when: assembling typed platform_package
artifact_type: platform_package
---

# Platform package assembly template

Use this as a writing aid only. The active JSON Schema and task envelope remain authoritative.

```json
{
  "schema_id": "<active platform-package schema id>",
  "schema_version": "<active payload version>",
  "platform_package_id": "<stable id>",
  "delivery_title": "<final delivery-page title when required by schema>",
  "draft_ref": {},
  "primary_platform": "<one selected platform>",
  "packages": [
    {
      "platform": "<selected platform>",
      "title": "<platform video title>",
      "cover_title": "<platform cover title>",
      "body_text": "<manual publish description>",
      "hashtags": ["<relevant hashtag>"],
      "notes": ["<manual posting or risk note>"]
    }
  ],
  "package_status": "<allowed status>",
  "next_skill": "<current route owner>"
}
```

Repeat the package item once for each selected platform and for no others. Do not add empty placeholders. Keep all cards bound to the same approved draft and evidence set.

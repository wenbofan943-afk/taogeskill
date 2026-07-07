# Security

Do not report or submit:

```text
platform cookies
API keys
tokens
private customer records
unpublished production account files
```

This project does not require platform login credentials. Any workflow variant that asks for such credentials is outside this alpha package boundary.

## Report Types

```text
private_data
secret
unsafe_automation
local_path
license_or_notice_risk
```

Use `.github/ISSUE_TEMPLATE/security-report.md` for public-safe reports. If a report contains real secrets or private account data, remove the sensitive value and describe the location pattern instead.

## Contact Boundary

General usage feedback and alpha trial communication can go through `CONTACT.md`.

Security, privacy, secret, or unsafe automation reports should not be sent as raw screenshots or public messages containing sensitive values. Remove the sensitive value first, then describe the affected file, field, or workflow pattern.

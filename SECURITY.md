# Security policy

Security fixes target the current `main` branch and the latest release. This project is an early release; a review and passing tests do not guarantee that defects are absent.

## Reporting a vulnerability

Use GitHub's **Security → Report a vulnerability** or [start a private advisory](https://github.com/taylorwilliams/meeting-guard/security/advisories/new). Private reporting must be enabled as part of the public-release configuration. If the reporting button is unavailable, wait for it to be enabled rather than posting exploit details publicly.

Include the affected version, reproduction steps with fictional data, and the likely impact. Do not attach credentials, real calendar databases, personal event notes or the app's state file. Reports are reviewed by the maintainer; there is no guaranteed response time or bug bounty.

## Data and permissions

Calendar access uses Apple's EventKit permission. The app reads events; it does not change calendar records or upload calendar data. Settings, personal reminders and pending snoozes stay in the current user's Application Support directory. The app restricts its state directory and file to the current user. It does not separately encrypt that file, and privacy mode does not protect against other software running as the same user or screen recording.

External automation links are disabled by default, require confirmation when enabled, and are rate-limited. Notes are displayed as text, not executed. Meeting actions open recognised HTTPS meeting links only after a user action. Imported palette files are limited to 64 KiB and decoded as a fixed JSON schema.

## Builds

Local builds use an ad-hoc signature and hardened runtime. They are not notarised. Distributable Mac binaries need the maintainer's Developer ID signing, notarisation and a stapled ticket. Signing credentials must never be committed or made available to pull-request workflows. [docs/RELEASE.md](docs/RELEASE.md) records the remaining publication requirements.

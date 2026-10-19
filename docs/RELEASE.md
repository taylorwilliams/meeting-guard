# Public release

The repository configuration script never changes visibility or adds collaborators. Keep the repository private until the code, documentation and CI results are ready to share.

## Repository safeguards

Run `python3 scripts/configure-github.py` to inspect the plan, then `python3 scripts/configure-github.py --apply` to apply it using the signed-in GitHub administrator account.

GitHub Free does not provide enforced branch protection on private personal repositories. To enforce protection before any public access, use a plan that supports private-repository protection. Otherwise, after changing visibility to public yourself, run the apply command immediately. The script reports pending features and exits with status 2 if it cannot apply everything; do not treat a partial result as fully protected. It can be rerun safely.

The policy requires pull requests with one code-owner approval, passing **Build and test** and **Repository checks** jobs from GitHub Actions, up-to-date branches and resolved review conversations. It enforces linear history and blocks force pushes and branch deletion, including for administrators. The owner alone may bypass the review requirement, allowing them to merge their own pull requests; checks still apply. Only squash merges are enabled and merged branches are deleted automatically.

Branch protection enforces pull requests, checks and branch restrictions. A separate review ruleset requires code-owner approval and lets the personal repository's owner bypass review when merging a pull request. That exemption does not bypass branch protection. The configuration script updates the existing review ruleset on repeat runs.

Public contributors can fork and open pull requests without write access. All outside-contributor workflow runs require maintainer approval once the public settings are applied. Workflow tokens are read-only, checkouts do not retain credentials, actions must use full commit hashes, and only GitHub-owned actions are allowed. No pull-request workflow has signing keys or release secrets.

The public configuration also enables private vulnerability reporting, secret scanning and secret push protection. Dependency alerts and automated security updates are enabled where supported. Dependabot proposes updates to pinned workflow actions; these still require review.

Before publishing, verify these settings in GitHub and ensure the default branch's two CI jobs are green. A policy file in the repository is not enforcement by itself. The security policy's private advisory link must work before accepting vulnerability reports. The source and Git history should also pass Gitleaks before publication.

## Mac binaries

The default build is for local use, ad-hoc signed and not notarised. Public source availability does not make that binary a Developer ID release.

For downloadable releases, build on a trusted Mac using your Developer ID Application identity, sign with hardened runtime and the calendar entitlement, submit the archive to Apple's notarisation service, staple the ticket to the app and validate it with Gatekeeper. Keep signing keys and notarisation credentials outside the repository and outside pull-request workflows. Do not tell users to disable Gatekeeper or other OS protections.

Manual release checks include calendar permission and sync, a real test meeting alert and call join, wake/sleep, launch at login and multiple displays on supported macOS versions. The automated suite covers core behaviour and packaging, not these hardware and account-specific cases.

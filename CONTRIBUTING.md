# Contributing

Fork the repository, make a branch, and open a pull request against `main`. Public contributors do not need repository write access. The maintainer reviews submissions before merging.

Use Swift 6 and Xcode 16 or newer on macOS 14 or newer. Run `swift test`, `scripts/build-app.sh`, and the checks described in [docs/TESTING.md](docs/TESTING.md). Use fictional events, reminders and meeting links in tests and screenshots. Keep new permissions and dependencies to the minimum needed for the change.

Pull requests run on disposable GitHub-hosted runners with a read-only token, no saved checkout credentials, and no signing keys. Outside contributors' workflows require maintainer approval after the public-repository settings are applied. The maintainer should inspect workflow and build-script changes before approving a run. Approval to run tests is separate from approval to merge code.

The prepared protection policy requires the two CI jobs, an up-to-date branch, resolved conversations and a code-owner review. It blocks force pushes and branch deletion. Only the repository owner may bypass the review requirement, allowing the owner to merge their own pull requests; passing checks and the other protections still apply. These settings must be applied using [docs/RELEASE.md](docs/RELEASE.md); a policy file alone does not enforce protection.

Report vulnerabilities through [SECURITY.md](SECURITY.md). Contributions use the project's MIT licence.

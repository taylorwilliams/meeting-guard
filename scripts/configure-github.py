#!/usr/bin/env python3
"""Apply repository safeguards without changing visibility or adding collaborators."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_REPO = "taylorwilliams/meeting-guard"


def settings_plan(repo, info):
    if info.get("owner", {}).get("type", "User") != "User":
        raise ValueError("This policy is for a personally owned repository.")
    protection = json.loads((ROOT / ".github/branch-protection.json").read_text())
    reviews = json.loads((ROOT / ".github/review-ruleset.json").read_text())
    base = "repos/" + repo
    plan = [
        ("Repository settings", "PATCH", base, {
            "allow_merge_commit": False, "allow_rebase_merge": False,
            "allow_squash_merge": True, "delete_branch_on_merge": True,
            "allow_auto_merge": False, "allow_update_branch": True,
            "has_wiki": False,
        }),
        ("Read-only workflow token", "PUT", base + "/actions/permissions/workflow", {
            "default_workflow_permissions": "read", "can_approve_pull_request_reviews": False,
        }),
        ("Pinned workflow actions", "PUT", base + "/actions/permissions", {
            "enabled": True, "allowed_actions": "selected", "sha_pinning_required": True,
        }),
        ("GitHub-owned actions only", "PUT", base + "/actions/permissions/selected-actions", {
            "github_owned_allowed": True, "verified_allowed": False, "patterns_allowed": [],
        }),
        ("Dependency alerts", "PUT", base + "/vulnerability-alerts", None),
        ("Dependency security updates", "PUT", base + "/automated-security-fixes", None),
        ("Main branch protection", "PUT", base + "/branches/main/protection", protection),
        ("Code-owner review rule", "UPSERT_RULESET", base + "/rulesets", reviews),
    ]
    if not info["private"]:
        plan.extend([
            ("Approve all outside-contributor workflows", "PUT", base + "/actions/permissions/fork-pr-contributor-approval", {
                "approval_policy": "all_external_contributors",
            }),
            ("Private vulnerability reporting", "PUT", base + "/private-vulnerability-reporting", None),
            ("Secret scanning and push protection", "PATCH", base, {
                "security_and_analysis": {
                    "secret_scanning": {"status": "enabled"},
                    "secret_scanning_push_protection": {"status": "enabled"},
                },
            }),
        ])
    return plan


def api(method, path, body=None):
    command = ["gh", "api", "--method", method, path]
    if body is not None:
        command.extend(["--input", "-"])
    result = subprocess.run(command, input=json.dumps(body) if body is not None else None,
                            text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip())
    return json.loads(result.stdout) if result.stdout.strip() else {}


def apply_setting(method, path, body):
    if method != "UPSERT_RULESET":
        return api(method, path, body)
    # Update our existing rule on repeat runs rather than creating duplicates.
    existing = api("GET", path + "?includes_parents=false")
    matches = [rule for rule in existing if rule["name"] == body["name"]]
    if len(matches) > 1:
        raise RuntimeError("Multiple matching review rules exist; resolve duplicates before applying.")
    if matches:
        return api("PUT", path + "/" + str(matches[0]["id"]), body)
    return api("POST", path, body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--apply", action="store_true", help="Apply the settings; without this flag, show the plan only.")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo):
        parser.error("Expected an owner/repository name.")
    info = api("GET", "repos/" + args.repo)
    if not info.get("permissions", {}).get("admin"):
        parser.error("Repository administrator access is required.")
    pending = []
    if info["private"]:
        pending.append("Outside-contributor approval, private vulnerability reporting and native secret scanning require a public repository.")
    for label, method, path, body in settings_plan(args.repo, info):
        if not args.apply:
            print("Planned: " + label)
            continue
        try:
            apply_setting(method, path, body)
            print("Applied: " + label)
        except RuntimeError as error:
            pending.append(label + ": " + str(error))
    for message in pending:
        print("Pending: " + message, file=sys.stderr)
    print("Repository visibility was not changed.")
    return 2 if args.apply and pending else 0


if __name__ == "__main__":
    sys.exit(main())

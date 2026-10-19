import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("configure_github", ROOT / "scripts/configure-github.py")
CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONFIG)


class RepositoryPolicyTests(unittest.TestCase):
    def test_applying_policy_never_publishes_or_adds_collaborators(self):
        for private in [True, False]:
            plan = CONFIG.settings_plan(CONFIG.DEFAULT_REPO, {"private": private})
            for _, _, path, body in plan:
                self.assertNotIn("collaborators", path)
                self.assertFalse({"private", "visibility"}.intersection(body or {}))

    def test_public_features_are_only_requested_for_public_repositories(self):
        private = CONFIG.settings_plan(CONFIG.DEFAULT_REPO, {"private": True})
        public = CONFIG.settings_plan(CONFIG.DEFAULT_REPO, {"private": False})
        self.assertFalse(any("fork-pr-contributor-approval" in p[2] for p in private))
        self.assertTrue(any(p[3] == {"approval_policy": "all_external_contributors"} for p in public))

    def test_required_checks_are_bound_to_github_actions_and_only_owner_bypasses_review(self):
        protection = CONFIG.settings_plan(CONFIG.DEFAULT_REPO, {"private": True})[-1][3]
        self.assertEqual({v["context"] for v in protection["required_status_checks"]["checks"]},
                         {"Build and test", "Repository checks"})
        self.assertTrue(all(v["app_id"] == 15368 for v in protection["required_status_checks"]["checks"]))
        self.assertEqual(protection["required_pull_request_reviews"]["bypass_pull_request_allowances"],
                         {"users": ["taylorwilliams"]})
        self.assertTrue(protection["enforce_admins"])
        self.assertFalse(protection["allow_force_pushes"])
        self.assertFalse(protection["allow_deletions"])


if __name__ == "__main__":
    unittest.main()

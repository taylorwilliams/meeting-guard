import importlib.util
from pathlib import Path
import unittest
from unittest.mock import call, patch

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
        plan = CONFIG.settings_plan(CONFIG.DEFAULT_REPO, {"private": True})
        protection = next(item[3] for item in plan if item[2].endswith("/branches/main/protection"))
        reviews = next(item[3] for item in plan if item[1] == "UPSERT_RULESET")
        self.assertEqual({v["context"] for v in protection["required_status_checks"]["checks"]},
                         {"Build and test", "Repository checks"})
        self.assertTrue(all(v["app_id"] == 15368 for v in protection["required_status_checks"]["checks"]))
        # The live API accepts checks or contexts, never both.
        self.assertNotIn("contexts", protection["required_status_checks"])
        self.assertNotIn("bypass_pull_request_allowances", protection["required_pull_request_reviews"])
        self.assertEqual(reviews["bypass_actors"],
                         [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}])
        self.assertEqual(reviews["enforcement"], "active")
        self.assertEqual(reviews["conditions"]["ref_name"], {"include": ["refs/heads/main"], "exclude": []})
        self.assertEqual(reviews["rules"][0]["parameters"]["required_approving_review_count"], 1)
        self.assertTrue(reviews["rules"][0]["parameters"]["require_code_owner_review"])
        self.assertTrue(protection["enforce_admins"])
        self.assertFalse(protection["allow_force_pushes"])
        self.assertFalse(protection["allow_deletions"])

    def test_review_rule_is_created_once_and_updated_on_repeat_runs(self):
        path = "repos/" + CONFIG.DEFAULT_REPO + "/rulesets"
        body = next(item[3] for item in CONFIG.settings_plan(CONFIG.DEFAULT_REPO, {"private": False})
                    if item[1] == "UPSERT_RULESET")
        with patch.object(CONFIG, "api", side_effect=[[], {}]) as api:
            CONFIG.apply_setting("UPSERT_RULESET", path, body)
            self.assertEqual(api.call_args_list, [call("GET", path + "?includes_parents=false"),
                                                call("POST", path, body)])
        with patch.object(CONFIG, "api", side_effect=[[{"name": body["name"], "id": 123}], {}]) as api:
            CONFIG.apply_setting("UPSERT_RULESET", path, body)
            self.assertEqual(api.call_args_list, [call("GET", path + "?includes_parents=false"),
                                                call("PUT", path + "/123", body)])

    def test_owner_bypass_policy_is_not_applied_to_organisation_repositories(self):
        with self.assertRaises(ValueError):
            CONFIG.settings_plan(CONFIG.DEFAULT_REPO, {"private": False, "owner": {"type": "Organization"}})


if __name__ == "__main__":
    unittest.main()

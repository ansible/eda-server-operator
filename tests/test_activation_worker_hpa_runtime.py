"""Offline execution of the runtime's real Ansible expressions (no cluster)."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
TASKS = ROOT / "roles/eda/tasks"


@unittest.skipUnless(shutil.which("ansible-playbook"), "ansible-playbook is required")
class TestAutoscalingRuntime(unittest.TestCase):
    def run_tasks(self, tasks, variables):
        play = [{"hosts": "localhost", "gather_facts": False,
                 "vars": variables, "tasks": tasks}]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.yml"
            path.write_text(yaml.safe_dump(play))
            result = subprocess.run(
                ["ansible-playbook", "-i", "localhost,", "-c", "local", str(path)],
                capture_output=True, text=True, timeout=60,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_replica_release_preserves_other_apply_fields(self):
        deploy = yaml.safe_load((TASKS / "deploy_eda.yml").read_text())
        release = next(t for t in deploy if t["name"] ==
                       "Remove replicas from activation worker apply bookkeeping during HPA handoff")
        self.run_tasks([release, {"ansible.builtin.assert": {"that": [
            "activation_worker_last_applied_without_replicas.spec.replicas is not defined",
            "activation_worker_last_applied_without_replicas.spec.template == activation_worker_last_applied.spec.template",
            "activation_worker_last_applied_without_replicas.metadata == activation_worker_last_applied.metadata",
            "activation_worker_last_applied.spec.replicas == 5",
        ]}}], {"activation_worker_last_applied": {
            "metadata": {"name": "sample-activation-worker"},
            "spec": {"replicas": 5, "template": {"metadata": {"labels": {"app": "eda"}}}},
        }})

    def test_bootstrap_only_new_or_zero_replica_deployments(self):
        deploy = yaml.safe_load((TASKS / "deploy_eda.yml").read_text())
        bootstrap = next(t for t in deploy if t["name"] ==
                         "Mark a new activation worker Deployment for minimum-replica bootstrap")
        tasks = []
        for resources, expected in [([], True), ([{"spec": {"replicas": 0}}], True),
                                    ([{"spec": {"replicas": 5}}], False)]:
            tasks.extend([
                {"ansible.builtin.set_fact": {
                    "activation_worker_deployment_before_autoscaling": {"resources": resources}}},
                bootstrap,
                {"ansible.builtin.assert": {"that": [
                    "activation_worker_bootstrap == " + json.dumps(expected)]}},
            ])
        self.run_tasks(tasks, {"combined_activation_worker": {"autoscaling": {"enabled": True}}})

    def test_validation_rejects_invalid_inputs(self):
        tasks = []
        base = {"autoscaling": {"enabled": True, "min_replicas": 2, "max_replicas": 6,
                                "target_cpu_utilization_percentage": 70},
                "resource_requirements": {"requests": {"cpu": "25m"}}}
        tasks.append({"ansible.builtin.include_tasks": str(TASKS / "validate_activation_worker_autoscaling.yml")})
        for update in [
            {"autoscaling": dict(base["autoscaling"], min_replicas=7)},
            {"resource_requirements": {"requests": {"cpu": "0"}}},
            {"resource_requirements": {"requests": {"memory": "150Mi"}}},
        ]:
            tasks.append({"block": [
                {"ansible.builtin.set_fact": {"combined_activation_worker": dict(base, **update)}},
                {"ansible.builtin.include_tasks": str(TASKS / "validate_activation_worker_autoscaling.yml")},
                {"ansible.builtin.fail": {"msg": "Unexpected validation success"}},
            ], "rescue": [{"ansible.builtin.assert": {"that": [
                "'activation_worker.autoscaling requires' in ansible_failed_result.msg"]}}]})
        self.run_tasks(tasks, {"combined_activation_worker": base})


if __name__ == "__main__":
    unittest.main()

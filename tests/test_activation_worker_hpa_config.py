"""
Static regression tests for the activation worker HPA autoscaling schema and RBAC contracts.

Tests validate:
- CRD schema structure and defaults
- RBAC role permissions for HPA
- YAML file integrity

Requires: PyYAML (available as project dependency)
"""

import os
import unittest

import yaml

# Resolve paths relative to project root
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CRD_PATH = os.path.join(PROJECT_ROOT, "config", "crd", "bases", "eda.ansible.com_edas.yaml")
RBAC_PATH = os.path.join(PROJECT_ROOT, "config", "rbac", "role.yaml")
CSV_PATH = os.path.join(PROJECT_ROOT, "config", "manifests", "bases",
                        "eda-server-operator.clusterserviceversion.yaml")


class TestActivationWorkerHPASchema(unittest.TestCase):
    """Test the activation_worker.autoscaling schema in the EDA CRD."""

    @classmethod
    def setUpClass(cls):
        with open(CRD_PATH) as f:
            cls.crd = yaml.safe_load(f)

        eda_version = cls.crd["spec"]["versions"][0]
        schema = eda_version["schema"]["openAPIV3Schema"]
        spec = schema["properties"]["spec"]
        cls.activation_worker = spec["properties"]["activation_worker"]
        cls.autoscaling = cls.activation_worker["properties"]["autoscaling"]

    def test_autoscaling_property_exists(self):
        """autoscaling must be defined in activation_worker properties."""
        self.assertIn("autoscaling", self.activation_worker["properties"])

    def test_autoscaling_is_object(self):
        """autoscaling must be of type object."""
        self.assertEqual(self.autoscaling.get("type"), "object")

    def test_enabled_default_is_false(self):
        """enabled must default to false."""
        enabled = self.autoscaling["properties"]["enabled"]
        self.assertEqual(enabled["type"], "boolean")
        self.assertFalse(enabled["default"])

    def test_enabled_has_description(self):
        """enabled must have a description."""
        desc = self.autoscaling["properties"]["enabled"].get("description", "")
        self.assertTrue(len(desc) > 0)
        self.assertIn("horizontalpodautoscaler", desc.lower())

    def test_min_replicas_default(self):
        """min_replicas must default to 2."""
        min_rep = self.autoscaling["properties"]["min_replicas"]
        self.assertEqual(min_rep["type"], "integer")
        self.assertEqual(min_rep["default"], 2)
        self.assertEqual(min_rep["minimum"], 1)

    def test_max_replicas_default(self):
        """max_replicas must default to 6."""
        max_rep = self.autoscaling["properties"]["max_replicas"]
        self.assertEqual(max_rep["type"], "integer")
        self.assertEqual(max_rep["default"], 6)
        self.assertEqual(max_rep["minimum"], 1)

    def test_target_cpu_utilization_default(self):
        """target_cpu_utilization_percentage must default to 70."""
        target = self.autoscaling["properties"]["target_cpu_utilization_percentage"]
        self.assertEqual(target["type"], "integer")
        self.assertEqual(target["default"], 70)
        self.assertEqual(target["minimum"], 1)
        self.assertNotIn("maximum", target)

    def test_all_required_properties_present(self):
        """All four autoscaling properties must be present."""
        expected = {"enabled", "min_replicas", "max_replicas",
                    "target_cpu_utilization_percentage"}
        actual = set(self.autoscaling["properties"].keys())
        self.assertTrue(expected.issubset(actual),
                        f"Missing properties: {expected - actual}")

    def test_crd_yaml_integrity(self):
        """The CRD YAML file must be well-formed."""
        with open(CRD_PATH) as f:
            yaml.safe_load(f.read())
        # If we get here without exception, the YAML is valid.


class TestActivationWorkerHPARBAC(unittest.TestCase):
    """Test RBAC role permissions for HPA."""

    @classmethod
    def setUpClass(cls):
        with open(RBAC_PATH) as f:
            cls.role = yaml.safe_load(f)

    @classmethod
    def _get_resources_for_api_group(cls, api_group):
        """Helper: get all resources for a given apiGroup in the role."""
        for rule in cls.role["rules"]:
            if api_group in rule.get("apiGroups", []):
                return rule.get("resources", [])
        return []

    @classmethod
    def _get_verbs_for_resource(cls, api_group, resource):
        """Helper: get verbs for a specific resource."""
        for rule in cls.role["rules"]:
            if api_group in rule.get("apiGroups", []) and resource in rule.get("resources", []):
                return rule.get("verbs", [])
        return []

    def test_role_name(self):
        """The role must be named eda-manager-role."""
        self.assertEqual(self.role["metadata"]["name"], "eda-manager-role")

    def test_horizontalpodautoscalers_resource_exists(self):
        """Rules must include horizontalpodautoscalers resource."""
        resources = self._get_resources_for_api_group("autoscaling")
        self.assertIn("horizontalpodautoscalers", resources)

    def test_hpa_verbs_include_create_delete(self):
        """HPA rules must include create and delete verbs."""
        verbs = self._get_verbs_for_resource("autoscaling", "horizontalpodautoscalers")
        self.assertIn("create", verbs)
        self.assertIn("delete", verbs)

    def test_hpa_verbs_include_get_list_watch(self):
        """HPA rules must include get, list, and watch verbs."""
        verbs = self._get_verbs_for_resource("autoscaling", "horizontalpodautoscalers")
        for verb in ["get", "list", "watch"]:
            self.assertIn(verb, verbs, f"Missing verb: {verb}")

    def test_hpa_verbs_include_patch_update(self):
        """HPA rules must include patch and update verbs."""
        verbs = self._get_verbs_for_resource("autoscaling", "horizontalpodautoscalers")
        for verb in ["patch", "update"]:
            self.assertIn(verb, verbs, f"Missing verb: {verb}")

    def test_no_metrics_api_granted(self):
        """The RBAC role must NOT grant access to the metrics API directly.
        The HPA controller reads from metrics.k8s.io via the kube-aggregator;
        the operator only needs HPA CRUD permissions."""
        api_groups = [rule["apiGroups"] for rule in self.role["rules"]]
        # Flatten nested lists
        flat_groups = []
        for g in api_groups:
            if isinstance(g, list):
                flat_groups.extend(g)
            else:
                flat_groups.append(g)
        self.assertNotIn("metrics.k8s.io", flat_groups,
                         "metrics.k8s.io should not be directly granted")

    def test_role_yaml_integrity(self):
        """The RBAC YAML file must be well-formed."""
        with open(RBAC_PATH) as f:
            yaml.safe_load(f.read())


class TestCSVSpecDescriptors(unittest.TestCase):
    """Test CSV spec descriptors include the autoscaling field."""

    @classmethod
    def setUpClass(cls):
        with open(CSV_PATH) as f:
            cls.csv = yaml.safe_load(f)

        # Find the EDA CRD owned entry
        for crd in cls.csv["spec"]["customresourcedefinitions"]["owned"]:
            if crd["name"] == "edas.eda.ansible.com":
                cls.eda_crd = crd
                break
        else:
            cls.fail("EDA CRD not found in CSV owned entries")

    def test_autoscaling_spec_descriptor_exists(self):
        """A spec descriptor for activation_worker.autoscaling must exist."""
        paths = [d.get("path", "") for d in self.eda_crd.get("specDescriptors", [])]
        self.assertIn("activation_worker.autoscaling", paths,
                      "activation_worker.autoscaling not in CSV specDescriptors")

    def test_autoscaling_display_name(self):
        """The autoscaling descriptor must have a display name."""
        for d in self.eda_crd.get("specDescriptors", []):
            if d.get("path") == "activation_worker.autoscaling":
                self.assertIn("displayName", d)
                self.assertTrue(len(d["displayName"]) > 0)
                return
        self.fail("autoscaling descriptor not found for display name check")

    def test_csv_yaml_integrity(self):
        """The CSV YAML file must be well-formed."""
        with open(CSV_PATH) as f:
            yaml.safe_load(f.read())


if __name__ == "__main__":
    unittest.main()

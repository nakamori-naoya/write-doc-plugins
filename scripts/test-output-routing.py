#!/usr/bin/env python3
"""Regression checks for explicit relative/absolute output routing."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OutputRouting(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="output-routing-")
        self.base = Path(self.temp.name).resolve()
        self.plugin = ROOT / "plugins/skills/authoring/doc-render"
        self.repo = self.base / "working-repo"
        self.repo.mkdir()
        self.home = self.base / "home"
        self.home.mkdir()
        self.external = self.home / "other-repository/guides/onboarding"
        self.env = dict(os.environ, HOME=str(self.home))
        config = self.repo / ".harness-plugins/doc-render.config.yml"
        config.parent.mkdir()
        defaults = (self.plugin / "config/defaults.yml").read_text()
        config.write_text(defaults.replace(
            "  routes: []",
            "  routes:\n"
            "    - templates: [domain-rule, user-journey-bdd]\n"
            "      dir: {type: relative, path: docs/bdd}\n"
            "    - templates: [onboarding]\n"
            "      dir: {type: absolute, path: ~/other-repository/guides/onboarding}",
        ))
        resolved = self.call("bash", self.plugin / "scripts/resolve.sh", self.repo)
        self.assertEqual(resolved.returncode, 0, resolved.stderr)
        self.resolved_config = self.base / "resolved.yml"
        self.resolved_config.write_text(resolved.stdout)
        self.body = self.base / "body.md"
        self.body.write_text("# body\n")

    def tearDown(self):
        self.temp.cleanup()

    def call(self, *args):
        return subprocess.run(
            list(map(str, args)), text=True, capture_output=True,
            env=self.env, cwd=self.base, timeout=30,
        )

    def write(self, template, name, config=None, *extra):
        return self.call(
            "bash", self.plugin / "scripts/write-doc.sh",
            "--config", config or self.resolved_config,
            "--template", template,
            "--name", name,
            "--body-file", self.body,
            *extra,
        )

    def changed_config(self, old, new):
        source = self.repo / ".harness-plugins/doc-render.config.yml"
        source.write_text(source.read_text().replace(old, new))
        return source

    def resolve(self, _config):
        return self.call("bash", self.plugin / "scripts/resolve.sh", self.repo)

    def test_absolute_home_route_writes_outside_working_repository(self):
        result = self.write("onboarding", "onboarding.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(Path(output["path"]), self.external / "onboarding.md")
        self.assertEqual(output["destinationSource"], "route")

    def test_relative_route_is_based_on_working_repository(self):
        result = self.write("domain-rule", "domain.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(Path(output["path"]), self.repo / "docs/bdd/domain.md")
        self.assertEqual(output["destinationSource"], "route")

    def test_unmatched_template_uses_relative_default(self):
        result = self.write("concept", "concept.md")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(Path(output["path"]), self.repo / "docs/concept.md")
        self.assertEqual(output["destinationSource"], "default")

    def test_raw_absolute_path_is_allowed_when_declared_absolute(self):
        absolute = self.base / "absolute-output"
        config = self.changed_config(
            "{type: relative, path: docs/bdd}",
            f"{{type: absolute, path: {absolute}}}",
        )
        result = self.resolve(config)
        self.assertEqual(result.returncode, 0, result.stderr)
        resolved = self.base / "absolute-resolved.yml"
        resolved.write_text(result.stdout)
        written = self.write("domain-rule", "absolute.md", resolved)
        self.assertEqual(written.returncode, 0, written.stdout + written.stderr)
        self.assertEqual(Path(json.loads(written.stdout)["path"]), absolute / "absolute.md")

    def test_relative_type_rejects_absolute_path(self):
        config = self.changed_config(
            "{type: relative, path: docs/bdd}",
            "{type: relative, path: /tmp/bdd}",
        )
        result = self.resolve(config)
        self.assertEqual(result.returncode, 2)

    def test_absolute_type_rejects_relative_path(self):
        config = self.changed_config(
            "{type: relative, path: docs/bdd}",
            "{type: absolute, path: docs/bdd}",
        )
        result = self.resolve(config)
        self.assertEqual(result.returncode, 2)

    def test_untyped_path_is_rejected(self):
        config = self.changed_config("{type: relative, path: docs/bdd}", "docs/bdd")
        result = self.resolve(config)
        self.assertEqual(result.returncode, 2)

    def test_traversal_is_rejected(self):
        config = self.changed_config(
            "{type: relative, path: docs/bdd}",
            "{type: relative, path: docs/../outside}",
        )
        result = self.resolve(config)
        self.assertEqual(result.returncode, 2)

    def test_duplicate_template_routes_are_rejected(self):
        config = self.changed_config("templates: [onboarding]", "templates: [domain-rule]")
        result = self.resolve(config)
        self.assertEqual(result.returncode, 2)

    def test_explicit_output_directory_has_priority_over_route(self):
        explicit = self.base / "one-off-output"
        result = self.write("onboarding", "explicit.md", None, "--output-dir", explicit)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(Path(output["path"]), explicit / "explicit.md")
        self.assertEqual(output["destinationSource"], "explicit")

    def test_existing_target_update_ignores_current_route(self):
        existing = self.repo / "existing.md"
        existing.write_text("old\n")
        result = self.call(
            "bash", self.plugin / "scripts/write-doc.sh",
            "--config", self.resolved_config,
            "--template", "onboarding",
            "--target", existing,
            "--body-file", self.body,
            "--replace",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(Path(output["path"]), existing)
        self.assertEqual(output["destinationSource"], "existing-target")


if __name__ == "__main__":
    unittest.main()

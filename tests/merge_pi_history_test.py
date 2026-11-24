#!/usr/bin/env -S uv run --no-project --python >=3.10
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "merge_pi_history.py"


class MergeHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.pi = self.base / ".pi"
        self.default = self.pi / "agent/sessions"
        self.profile = self.pi / "profiles/minimal/agent/sessions"
        self.partner = self.pi / "profiles/partner/agent/sessions"
        self.stage = self.base / "staged-sessions"

    def session(self, root, name, ident, parent=None):
        path = root / "project" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        header = {"type": "session", "id": ident}
        if parent is not None:
            header["parentSession"] = str(parent)
        path.write_text(json.dumps(header) + '\n{"type":"message"}\n')
        return path

    def run_merge(self):
        return subprocess.run(
            ["uv", "run", "--no-project", "--python", ">=3.10", str(SCRIPT), str(self.pi), str(self.stage)],
            text=True, capture_output=True,
        )

    def test_remaps_forks_and_preserves_other_files_and_mtime(self):
        original = self.session(self.default, "one.jsonl", "one")
        child = self.session(self.profile, "two.jsonl", "two", original)
        self.session(self.partner, "three.jsonl", "three", child)
        self.session(self.profile, "four.jsonl", "four", child)
        other = self.profile / "project/notes.txt"
        other.write_bytes(b"untouched")
        os.utime(other, ns=(1234567890000000000, 1234567890000000000))
        result = self.run_merge()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["remapped"], 3)
        for name, parent in [("two.jsonl", "one.jsonl"), ("three.jsonl", "two.jsonl"), ("four.jsonl", "two.jsonl")]:
            header = json.loads((self.stage / "project" / name).read_text().splitlines()[0])
            self.assertEqual(header["parentSession"], str(self.default.resolve() / "project" / parent))
        copied = self.stage / "project/notes.txt"
        self.assertEqual(copied.read_bytes(), other.read_bytes())
        self.assertEqual(copied.stat().st_mtime_ns, other.stat().st_mtime_ns)

    def test_duplicate_session_id_aborts(self):
        self.session(self.default, "one.jsonl", "duplicate")
        self.session(self.profile, "two.jsonl", "duplicate")
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("occurs more than once", result.stderr)

    def test_empty_header_identifies_file(self):
        path = self.default / "project/empty.jsonl"
        path.parent.mkdir(parents=True)
        path.touch()
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("project/empty.jsonl", result.stderr)

    def test_dangling_profile_parent_aborts(self):
        self.session(self.profile, "child.jsonl", "child", self.partner / "project/missing.jsonl")
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("project/child.jsonl", result.stderr)

    def test_rejects_casefold_path_collision(self):
        self.session(self.default, "One.jsonl", "one")
        self.session(self.profile, "one.jsonl", "two")
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("overwritten", result.stderr)

    def test_rejects_symlink_in_source_tree(self):
        self.default.mkdir(parents=True)
        (self.default / "link").symlink_to(self.base)
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-regular", result.stderr)

    def test_malformed_header_identifies_file(self):
        path = self.default / "project/bad.jsonl"
        path.parent.mkdir(parents=True)
        path.write_text("{not json}\n")
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("project/bad.jsonl", result.stderr)

    def test_rejects_staging_inside_pi_home_via_symlink(self):
        self.pi.mkdir(parents=True)
        alias = self.base / "pi-alias"
        alias.symlink_to(self.pi, target_is_directory=True)
        self.stage = alias / "unwanted-output"
        result = self.run_merge()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.pi / "unwanted-output").exists())

    def test_refuses_existing_destination(self):
        self.stage.mkdir()
        (self.stage / "keep").write_text("keep")
        self.assertNotEqual(self.run_merge().returncode, 0)
        self.assertEqual((self.stage / "keep").read_text(), "keep")


if __name__ == "__main__":
    unittest.main()

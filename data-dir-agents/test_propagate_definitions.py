#!/usr/bin/env python3
"""Tests for propagate_definitions.py — Pi, Codex, and Copilot generation."""

import json
import sys
import textwrap
from pathlib import Path

import pytest

# Import the module under test (same directory)
sys.path.insert(0, str(Path(__file__).parent))
from propagate_definitions import (
    load_copilot_profiles,
    plan_codex_marketplace,
    plan_copilot_profile,
    plan_pi_agent,
)


def test_codex_marketplace_versions_the_skill_tree(tmp_path):
    spec = tmp_path / "definitions"
    out = tmp_path / "generated"
    skill = _write(spec / "skills" / "example" / "SKILL.md", "---\nname: example\ndescription: Example skill\n---\n")
    helper = _write(skill.parent / "run.sh", "#!/bin/sh\n")
    helper.chmod(0o644)

    def metadata():
        return {
            path.name: json.loads(content)
            for _, _, path, content in (
                item for item in plan_codex_marketplace(spec, out)
                if item[0] == "writefile" and item[2].suffix == ".json"
            )
        }

    first = metadata()
    assert first == metadata()
    assert first["marketplace.json"]["plugins"][0]["source"]["path"] == "./plugins/dev-bin"
    assert first["plugin.json"]["skills"] == "./skills/"
    helper.chmod(0o755)
    changed_mode = metadata()
    assert changed_mode["plugin.json"]["version"] != first["plugin.json"]["version"]
    helper.write_text("#!/bin/sh\nexit 0\n")
    assert metadata()["plugin.json"]["version"] != changed_mode["plugin.json"]["version"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _write(path: Path, content: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content), encoding="utf-8")
    return path


def _make_skill(skills_root: Path, name: str):
    skill_dir = skills_root / name
    skill_dir.mkdir(parents=True, exist_ok=True)
    (skill_dir / "SKILL.md").write_text(f"# {name}\n", encoding="utf-8")


class TestLoadCopilotProfiles:
    def test_returns_empty_for_missing_dir(self, tmp_path):
        assert load_copilot_profiles(tmp_path / "nonexistent") == []

    def test_loads_single_profile(self, tmp_path):
        toml_file = tmp_path / "minimal.toml"
        toml_file.write_text(
            'name = "minimal"\ntarget_dir = "~/.copilot/profiles/minimal"\nagents_file = "AGENTS_AUTONOMOUS.md"\n',
            encoding="utf-8",
        )
        profiles = load_copilot_profiles(tmp_path)
        assert len(profiles) == 1
        assert profiles[0]["name"] == "minimal"
        assert profiles[0]["target_dir"] == "~/.copilot/profiles/minimal"
        assert profiles[0]["agents_file"] == "AGENTS_AUTONOMOUS.md"

    def test_skills_are_optional(self, tmp_path):
        (tmp_path / "p.toml").write_text(
            'name = "p"\ntarget_dir = "~/.copilot/p"\nagents_file = "AGENTS_GPT52.md"\n',
            encoding="utf-8",
        )
        profiles = load_copilot_profiles(tmp_path)
        assert "skills" not in profiles[0]


class TestPlanPiAgent:
    def test_single_output_matches_minimal_selection(self, tmp_path):
        spec_root = Path(__file__).parent / "definitions"
        planned = plan_pi_agent(spec_root, tmp_path)
        agent = tmp_path / "pi-agent"
        assert all(item[2].is_relative_to(agent) for item in planned)
        instructions = next(item for item in planned if item[2] == agent / "AGENTS.md")
        assert instructions[1].name == "AGENTS_MINIMAL.md"
        assert not any(item[2].name == ".target" for item in planned)
        skills = {item[2].name for item in planned if item[0] == "copydir"}
        assert "grounded-pairing-discipline" in skills
        assert "sub-agent-herdr-supervisor" not in skills
        assert len([item for item in planned if item[2].parent == agent / "prompts"]) == 5

    @pytest.mark.parametrize(
        ("assets", "error"),
        [('skills = ["missing"]\nprompts = []', "Pi skill"), ('skills = []\nprompts = ["missing.md"]', "Pi prompt")],
    )
    def test_missing_allowlisted_asset_raises(self, tmp_path, assets, error):
        _write(tmp_path / "agents" / "AGENTS_MINIMAL.md", "# Minimal")
        _write(tmp_path / "pi-agent.toml", 'agents_file = "AGENTS_MINIMAL.md"\n' + assets)
        with pytest.raises(FileNotFoundError, match=error):
            plan_pi_agent(tmp_path, tmp_path / "generated")


class TestSupervisorWorkerRuntimeBundling:
    def test_profile_bundles_runtime_into_each_selected_supervisor_skill(self, tmp_path):
        spec_root = tmp_path / "definitions"
        _write(spec_root / "agents" / "AGENTS_GPT52.md", "# GPT52\n")
        runtime = _write(spec_root / "runtime" / "pi-worker-runtime.sh", "# shared runtime\n")
        skills_root = spec_root / "skills"
        _make_skill(skills_root, "sub-agent-herdr-supervisor")
        _make_skill(skills_root, "sub-agent-cmux-supervisor")

        planned = plan_copilot_profile(
            {
                "name": "partner",
                "target_dir": "~/.copilot/profiles/partner",
                "agents_file": "AGENTS_GPT52.md",
                "skills": ["sub-agent-herdr-supervisor", "sub-agent-cmux-supervisor"],
            },
            spec_root,
            tmp_path / "generated",
        )

        runtime_destinations = {
            item[2]: item[1]
            for item in planned
            if item[0] == "copyfile" and item[2].name == "pi-worker-runtime.sh"
        }
        assert runtime_destinations == {
            tmp_path / "generated/copilot-profiles/partner/skills/sub-agent-herdr-supervisor/scripts/pi-worker-runtime.sh": runtime,
            tmp_path / "generated/copilot-profiles/partner/skills/sub-agent-cmux-supervisor/scripts/pi-worker-runtime.sh": runtime,
        }


class TestPlanCopilotProfile:
    def _make_spec_root(self, tmp_path: Path) -> Path:
        spec_root = tmp_path / "definitions"
        agents_dir = spec_root / "agents"
        _write(agents_dir / "AGENTS_GPT52.md", "# GPT52\n")
        _write(agents_dir / "AGENTS_AUTONOMOUS.md", "# AUTONOMOUS\n")
        skills_root = spec_root / "skills"
        _make_skill(skills_root, "codebase-search")
        _make_skill(skills_root, "web-search")
        _make_skill(skills_root, "diagrams")
        profiles_dir = spec_root / "profiles" / "copilot"
        _write(profiles_dir / "default.toml", "")
        return spec_root

    def _dest_names(self, planned, subdir: str) -> list[str]:
        return [
            item[2].name
            for item in planned
            if len(item) >= 3 and item[2].parent.name == subdir
        ]

    def test_target_file_written(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "default", "target_dir": "~/.copilot", "agents_file": "AGENTS_GPT52.md"}
        planned = plan_copilot_profile(profile, spec_root, out_root)
        target_items = [i for i in planned if i[2].name == ".target"]
        assert len(target_items) == 1
        assert target_items[0][3] == "~/.copilot"

    def test_instructions_use_correct_template(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {
            "name": "minimal",
            "target_dir": "~/.copilot/profiles/minimal",
            "agents_file": "AGENTS_AUTONOMOUS.md",
        }
        planned = plan_copilot_profile(profile, spec_root, out_root)
        instructions_items = [i for i in planned if i[2].name == "copilot-instructions.md"]
        assert len(instructions_items) == 1
        assert "# AUTONOMOUS" in instructions_items[0][3]

    def test_all_skills_included_when_no_key(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "default", "target_dir": "~/.copilot", "agents_file": "AGENTS_GPT52.md"}
        planned = plan_copilot_profile(profile, spec_root, out_root)
        skill_names = self._dest_names(planned, "skills")
        assert set(skill_names) == {"codebase-search", "web-search", "diagrams"}

    def test_skill_filtering(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {
            "name": "minimal",
            "target_dir": "~/.copilot/profiles/minimal",
            "agents_file": "AGENTS_AUTONOMOUS.md",
            "skills": ["codebase-search", "web-search"],
        }
        planned = plan_copilot_profile(profile, spec_root, out_root)
        skill_names = self._dest_names(planned, "skills")
        assert set(skill_names) == {"codebase-search", "web-search"}
        assert "diagrams" not in skill_names

    def test_empty_skills_list_produces_no_skills(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "p", "target_dir": "~/.copilot/p", "agents_file": "AGENTS_GPT52.md", "skills": []}
        planned = plan_copilot_profile(profile, spec_root, out_root)
        skill_names = self._dest_names(planned, "skills")
        assert skill_names == []

    def test_output_placed_under_copilot_profiles(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "myprofile", "target_dir": "~/.copilot/p", "agents_file": "AGENTS_GPT52.md"}
        planned = plan_copilot_profile(profile, spec_root, out_root)
        for item in planned:
            dest: Path = item[2]
            assert "copilot-profiles/myprofile" in str(dest)

    def test_missing_agents_file_raises(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "p", "target_dir": "~/.copilot/p", "agents_file": "AGENTS_NONEXISTENT.md"}
        with pytest.raises(FileNotFoundError, match="AGENTS_NONEXISTENT"):
            plan_copilot_profile(profile, spec_root, out_root)

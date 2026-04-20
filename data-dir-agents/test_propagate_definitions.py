#!/usr/bin/env python3
"""Tests for propagate_definitions.py — pi-agent profile support."""

import sys
import textwrap
from pathlib import Path

import pytest

# Import the module under test (same directory)
sys.path.insert(0, str(Path(__file__).parent))
from propagate_definitions import (
    load_copilot_profiles,
    load_pi_agent_profiles,
    plan_copilot_profile,
    plan_pi_agent_profile,
)


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


# ---------------------------------------------------------------------------
# load_pi_agent_profiles
# ---------------------------------------------------------------------------

class TestLoadPiAgentProfiles:
    def test_returns_empty_for_missing_dir(self, tmp_path):
        assert load_pi_agent_profiles(tmp_path / "nonexistent") == []

    def test_loads_single_profile(self, tmp_path):
        toml_file = tmp_path / "default.toml"
        toml_file.write_text(
            'name = "default"\ntarget_dir = "~/.pi/agent"\nagents_file = "AGENTS_GPT52.md"\n',
            encoding="utf-8",
        )
        profiles = load_pi_agent_profiles(tmp_path)
        assert len(profiles) == 1
        assert profiles[0]["name"] == "default"
        assert profiles[0]["target_dir"] == "~/.pi/agent"
        assert profiles[0]["agents_file"] == "AGENTS_GPT52.md"

    def test_loads_multiple_profiles_sorted(self, tmp_path):
        for name in ("z_profile", "a_profile"):
            (tmp_path / f"{name}.toml").write_text(
                f'name = "{name}"\ntarget_dir = "~/.pi/{name}"\nagents_file = "AGENTS_GPT52.md"\n',
                encoding="utf-8",
            )
        profiles = load_pi_agent_profiles(tmp_path)
        assert [p["name"] for p in profiles] == ["a_profile", "z_profile"]

    def test_raises_on_missing_required_key(self, tmp_path):
        (tmp_path / "bad.toml").write_text(
            'name = "bad"\ntarget_dir = "~/.pi/bad"\n',  # missing agents_file
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="agents_file"):
            load_pi_agent_profiles(tmp_path)

    def test_skills_and_prompts_are_optional(self, tmp_path):
        (tmp_path / "p.toml").write_text(
            'name = "p"\ntarget_dir = "~/.pi/p"\nagents_file = "AGENTS_GPT52.md"\n',
            encoding="utf-8",
        )
        profiles = load_pi_agent_profiles(tmp_path)
        assert "skills" not in profiles[0]
        assert "prompts" not in profiles[0]


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


# ---------------------------------------------------------------------------
# plan_pi_agent_profile
# ---------------------------------------------------------------------------

class TestPlanPiAgentProfile:
    def _make_spec_root(self, tmp_path: Path) -> Path:
        spec_root = tmp_path / "definitions"
        # agents dir with two AGENTS files
        agents_dir = spec_root / "agents"
        _write(agents_dir / "AGENTS_GPT52.md", "# GPT52\n")
        _write(agents_dir / "AGENTS_AUTONOMOUS.md", "# AUTONOMOUS\n")
        # skills
        skills_root = spec_root / "skills"
        _make_skill(skills_root, "codebase-search")
        _make_skill(skills_root, "web-search")
        _make_skill(skills_root, "diagrams")
        # prompts
        prompts_root = spec_root / "prompts"
        _write(prompts_root / "prompt-a.md", "# Prompt A\n")
        _write(prompts_root / "prompt-b.md", "# Prompt B\n")
        # profiles dir (not needed by plan function, but matches real layout)
        profiles_dir = spec_root / "profiles" / "pi-agent"
        _write(profiles_dir / "default.toml", "")
        return spec_root

    def _dest_names(self, planned, subdir: str) -> list[str]:
        """Return destination file/dir names for items whose immediate parent dir is `subdir`."""
        return [
            item[2].name
            for item in planned
            if len(item) >= 3 and item[2].parent.name == subdir
        ]

    def test_target_file_written(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "default", "target_dir": "~/.pi/agent", "agents_file": "AGENTS_GPT52.md"}
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        target_items = [i for i in planned if i[2].name == ".target"]
        assert len(target_items) == 1
        assert target_items[0][3] == "~/.pi/agent"

    def test_agents_md_uses_correct_template(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "minimal", "target_dir": "~/.pi/profiles/minimal/agent", "agents_file": "AGENTS_AUTONOMOUS.md"}
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        agents_items = [i for i in planned if i[2].name == "AGENTS.md"]
        assert len(agents_items) == 1
        assert "# AUTONOMOUS" in agents_items[0][3]

    def test_all_skills_included_when_no_key(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "default", "target_dir": "~/.pi/agent", "agents_file": "AGENTS_GPT52.md"}
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        skill_names = self._dest_names(planned, "skills")
        assert set(skill_names) == {"codebase-search", "web-search", "diagrams"}

    def test_skill_filtering(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {
            "name": "minimal",
            "target_dir": "~/.pi/profiles/minimal/agent",
            "agents_file": "AGENTS_AUTONOMOUS.md",
            "skills": ["codebase-search", "web-search"],
        }
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        skill_names = self._dest_names(planned, "skills")
        assert set(skill_names) == {"codebase-search", "web-search"}
        assert "diagrams" not in skill_names

    def test_empty_skills_list_produces_no_skills(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "p", "target_dir": "~/.pi/p", "agents_file": "AGENTS_GPT52.md", "skills": []}
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        skill_names = self._dest_names(planned, "skills")
        assert skill_names == []

    def test_empty_prompts_list_produces_no_prompts(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "p", "target_dir": "~/.pi/p", "agents_file": "AGENTS_GPT52.md", "prompts": []}
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        prompt_names = self._dest_names(planned, "prompts")
        assert prompt_names == []

    def test_all_prompts_included_when_no_key(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "default", "target_dir": "~/.pi/agent", "agents_file": "AGENTS_GPT52.md"}
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        prompt_names = self._dest_names(planned, "prompts")
        assert set(prompt_names) == {"prompt-a.md", "prompt-b.md"}

    def test_output_placed_under_pi_agent_profiles(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "myprofile", "target_dir": "~/.pi/p", "agents_file": "AGENTS_GPT52.md"}
        planned = plan_pi_agent_profile(profile, spec_root, out_root)
        for item in planned:
            dest: Path = item[2]
            assert "pi-agent-profiles/myprofile" in str(dest)

    def test_missing_agents_file_raises(self, tmp_path):
        spec_root = self._make_spec_root(tmp_path)
        out_root = tmp_path / "generated"
        profile = {"name": "p", "target_dir": "~/.pi/p", "agents_file": "AGENTS_NONEXISTENT.md"}
        with pytest.raises(FileNotFoundError, match="AGENTS_NONEXISTENT"):
            plan_pi_agent_profile(profile, spec_root, out_root)


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

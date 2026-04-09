#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""propagate_definitions.py

Self-contained script (uv-friendly) that propagates canonical definitions
into deployable agent artifacts *inside this repo*.

Canonical sources in this repo:
  - definitions/agents/AGENTS_*.md                  (global agent instruction files, templates with {{block-name}} placeholders)
  - definitions/agents/blocks/*.md                  (reusable content blocks; placeholders resolve to blocks/<name>.md)
  - definitions/skills/<skill>/...                  (full pi-agent skill directories)
  - definitions/prompts/*.md                        (pi-agent prompt templates)
  - definitions/profiles/pi-agent/<name>.toml       (pi-agent profile configs)

Generated output (ephemeral build artifacts):
  - generated/README.md                    (copied from definitions/STRUCTURE.md)
  - generated/propagation.svg              (diagram used by generated/README.md)

  - generated/gemini/GEMINI.md
  - generated/gemini/commands/*.md         (prompt templates derived from definitions/prompts)
  - generated/gemini/skills/<skill>/...    (copied 1:1 from definitions/skills)

  - generated/codex/AGENTS.md

  - generated/copilot/copilot-instructions.md
  - generated/copilot/skills/<skill>/...

  - generated/cursor/skills/<skill>/...

  - generated/pi-agent-profiles/<name>/.target      (deploy target path, read by agents_files_cp.sh)
  - generated/pi-agent-profiles/<name>/AGENTS.md    (rendered from profile's agents_file)
  - generated/pi-agent-profiles/<name>/skills/...   (subset or all skills per profile config)
  - generated/pi-agent-profiles/<name>/prompts/...  (subset or all prompts per profile config)

These generated artifacts are then copied to their final locations by:
  - $HOME/.local/bin/agents_files_cp.sh

Usage:
  ./propagate_definitions.py [--spec-dir definitions] [--out-dir generated] [--apply] [--list] [--list-blocks]

Default is dry-run (prints plan). Use --apply to write/copy.
  --list-blocks  List discovered agent blocks in definitions/agents/blocks/

Safety:
  - Will only write inside the repository directory (directory containing this script).
  - On --apply, the output directory is fully regenerated (old output removed) to avoid staleness.

Requirements:
  - Python 3.11+ (uses stdlib tomllib for profile TOML parsing)
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
try:
    import tomllib
except ImportError:
    raise ImportError("tomllib not found. Requires Python 3.11+.")
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent

PLACEHOLDER_RE = re.compile(r"\{\{([a-z0-9-]+)\}\}")


def resolve_placeholders(text: str, blocks_dir: Path) -> str:
    """Replace {{block-name}} placeholders with content from blocks/<name>.md.
    Block content is rstrip'd to avoid extra blank lines between sections.
    Final output is rstrip'd to match original files (no trailing newline)."""
    for match in PLACEHOLDER_RE.finditer(text):
        name = match.group(1)
        block_path = blocks_dir / f"{name}.md"
        if not block_path.exists():
            raise FileNotFoundError(f"Block not found: {name} (expected {block_path})")
        content = block_path.read_text(encoding="utf-8").rstrip("\n")
        text = text.replace(match.group(0), content)
    return text.rstrip("\n")


def ensure_within_repo(path: Path) -> bool:
    try:
        repo = REPO_ROOT.resolve()
        p = path.resolve()
        common = os.path.commonpath([str(repo), str(p)])
        return common == str(repo)
    except Exception:
        return False


def plan_file_copy(src: Path, dest: Path):
    return ("copyfile", src, dest)


def plan_dir_copy(src: Path, dest: Path):
    return ("copydir", src, dest)


def plan_write_file(src: Path, dest: Path, content: str):
    return ("writefile", src, dest, content)


def plan_global_agent_files(out_root: Path, definitions_root: Path):
    planned = []

    # Educational note: include the canonical structure/process doc into generated output
    structure_src = definitions_root / "STRUCTURE.md"
    if structure_src.exists():
        planned.append(plan_file_copy(structure_src, out_root / "README.md"))

    # Keep the README's embedded diagram working when viewed from generated/
    propagation_svg_src = definitions_root / "propagation.svg"
    if propagation_svg_src.exists():
        planned.append(plan_file_copy(propagation_svg_src, out_root / "propagation.svg"))

    agents_root = definitions_root / "agents"
    blocks_dir = agents_root / "blocks"

    def _resolve_and_plan(template_path: Path, *dest_paths: Path):
        if not template_path.exists():
            return
        text = template_path.read_text(encoding="utf-8")
        if blocks_dir.exists():
            text = resolve_placeholders(text, blocks_dir)
        for dest in dest_paths:
            planned.append(plan_write_file(template_path, dest, text))

    # Gemini
    gemini_src = agents_root / "AGENTS_GEMINI.md"
    if gemini_src.exists():
        _resolve_and_plan(gemini_src, out_root / "gemini" / "GEMINI.md")

    # Codex / copilot base (pi-agent AGENTS.md is now handled per-profile)
    gpt52_src = agents_root / "AGENTS_GPT52.md"
    if gpt52_src.exists():
        _resolve_and_plan(
            gpt52_src,
            out_root / "codex" / "AGENTS.md",
            out_root / "copilot" / "copilot-instructions.md",
        )

    return planned


def plan_skill_copies(spec_root: Path, out_root: Path):
    skills_root = spec_root / "skills"
    if not skills_root.exists():
        return []

    planned = []
    for skill_dir in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
        dest = out_root / "pi-agent" / "skills" / skill_dir.name
        planned.append(plan_dir_copy(skill_dir, dest))
    return planned


def plan_prompt_copies(spec_root: Path, out_root: Path):
    prompts_root = spec_root / "prompts"
    if not prompts_root.exists():
        return []

    planned = []
    for prompt_file in sorted(prompts_root.glob("*.md")):
        dest = out_root / "pi-agent" / "prompts" / prompt_file.name
        planned.append(plan_file_copy(prompt_file, dest))
    return planned


def load_pi_agent_profiles(profiles_dir: Path) -> list[dict]:
    """Load all *.toml profile configs from definitions/profiles/pi-agent/."""
    if not profiles_dir.exists():
        return []
    profiles = []
    for toml_file in sorted(profiles_dir.glob("*.toml")):
        with open(toml_file, "rb") as f:
            data = tomllib.load(f)
        if "name" not in data or "target_dir" not in data or "agents_file" not in data:
            raise ValueError(f"Profile {toml_file} missing required keys: name, target_dir, agents_file")
        profiles.append(data)
    return profiles


def plan_pi_agent_profile(profile: dict, spec_root: Path, out_root: Path) -> list[tuple]:
    """Plan generation of a single pi-agent profile into generated/pi-agent-profiles/<name>/."""
    planned = []
    profile_name = profile["name"]
    profile_out = out_root / "pi-agent-profiles" / profile_name

    agents_root = spec_root / "agents"
    blocks_dir = agents_root / "blocks"

    # .target file (deploy destination, read by agents_files_cp.sh)
    planned.append(plan_write_file(
        spec_root / "profiles" / "pi-agent" / f"{profile_name}.toml",
        profile_out / ".target",
        profile["target_dir"],
    ))

    # AGENTS.md: resolve the named agents_file template
    agents_src = agents_root / profile["agents_file"]
    if not agents_src.exists():
        raise FileNotFoundError(f"Profile '{profile_name}' references missing agents_file: {agents_src}")
    text = agents_src.read_text(encoding="utf-8")
    if blocks_dir.exists():
        text = resolve_placeholders(text, blocks_dir)
    planned.append(plan_write_file(agents_src, profile_out / "AGENTS.md", text))

    # Skills: all if key absent, filtered list if present, none if empty list
    skills_root = spec_root / "skills"
    skills_allowlist = profile.get("skills", None)  # None = all
    if skills_root.exists() and skills_allowlist != []:
        for skill_dir in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
            if skills_allowlist is None or skill_dir.name in skills_allowlist:
                planned.append(plan_dir_copy(skill_dir, profile_out / "skills" / skill_dir.name))

    # Prompts: all if key absent, filtered list if present, none if empty list
    prompts_root = spec_root / "prompts"
    prompts_allowlist = profile.get("prompts", None)  # None = all
    if prompts_root.exists() and prompts_allowlist != []:
        for prompt_file in sorted(prompts_root.glob("*.md")):
            if prompts_allowlist is None or prompt_file.name in prompts_allowlist:
                planned.append(plan_file_copy(prompt_file, profile_out / "prompts" / prompt_file.name))

    return planned


def plan_gemini_command_files(spec_root: Path, out_root: Path):
    """Generate Gemini CLI command/prompt templates.

    Prompts from definitions/prompts/*.md are copied 1:1 into generated/gemini/commands/.
    """

    planned = []

    prompts_root = spec_root / "prompts"
    if prompts_root.exists():
        for prompt_file in sorted(prompts_root.glob("*.md")):
            dest = out_root / "gemini" / "commands" / prompt_file.name
            planned.append(plan_file_copy(prompt_file, dest))

    return planned


def plan_gemini_skill_copies(spec_root: Path, out_root: Path):
    """Generate Gemini CLI Agent Skills.

    Gemini CLI discovers user skills from ~/.gemini/skills/<skill>/... (and an alias ~/.agents/skills).
    We generate the user-scope format.
    """

    skills_root = spec_root / "skills"
    if not skills_root.exists():
        return []

    planned = []
    for skill_dir in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
        dest = out_root / "gemini" / "skills" / skill_dir.name
        planned.append(plan_dir_copy(skill_dir, dest))

    return planned


def plan_copilot_skill_copies(spec_root: Path, out_root: Path):
    """Generate Copilot Agent Skills.

    Copilot CLI discovers skills from:
      - ~/.copilot/skills/<skill>/...
      - (and repo-root/.github/skills/<skill>/...)

    So we copy our canonical skills (full directories) 1:1.
    """

    skills_root = spec_root / "skills"
    if not skills_root.exists():
        return []

    planned = []
    for skill_dir in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
        dest = out_root / "copilot" / "skills" / skill_dir.name
        planned.append(plan_dir_copy(skill_dir, dest))

    return planned


def plan_cursor_skill_copies(spec_root: Path, out_root: Path):
    """Generate Cursor Agent Skills.

    Cursor discovers skills from ~/.cursor/skills/<skill>/...
    Same format as Copilot: full skill directories 1:1.
    """

    skills_root = spec_root / "skills"
    if not skills_root.exists():
        return []

    planned = []
    for skill_dir in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
        dest = out_root / "cursor" / "skills" / skill_dir.name
        planned.append(plan_dir_copy(skill_dir, dest))

    return planned


def print_plan(planned: list[tuple]):
    print("Planned outputs (dry-run):\n")
    for item in planned:
        kind = item[0]
        src = item[1]
        dest = item[2]
        rel = dest.relative_to(REPO_ROOT) if ensure_within_repo(dest) else dest

        if kind == "copydir":
            print(f"-> copy dir {src} -> {rel}")
            preview = [p for p in list(src.rglob("*")) if p.is_file()][:8]
            for p in preview:
                print("    ", p.relative_to(src))
            print("    ...\n")
        elif kind == "copyfile":
            print(f"-> copy file {src} -> {rel}\n")
        elif kind == "writefile":
            print(f"-> render file {src} -> {rel}\n")
        else:
            print(f"-> {kind} {src} -> {rel}\n")


def apply_plan(planned: list[tuple], out_root: Path):
    # clean out_root to avoid stale files
    if out_root.exists():
        if out_root.is_file():
            out_root.unlink()
        else:
            shutil.rmtree(out_root)
    out_root.mkdir(parents=True, exist_ok=True)

    for item in planned:
        kind = item[0]
        src = item[1]
        dest = item[2]
        content = item[3] if kind == "writefile" else None

        if not ensure_within_repo(dest):
            print(f"Refusing to write outside repo: {dest}")
            continue

        dest.parent.mkdir(parents=True, exist_ok=True)

        if kind == "copydir":
            if dest.exists():
                if dest.is_file():
                    dest.unlink()
                else:
                    shutil.rmtree(dest)
            shutil.copytree(src, dest)
            print(f"Copied dir: {dest.relative_to(REPO_ROOT)}")
        elif kind == "copyfile":
            shutil.copy2(src, dest)
            print(f"Copied file: {dest.relative_to(REPO_ROOT)}")
        elif kind == "writefile":
            assert content is not None
            dest.write_text(content, encoding="utf-8")
            print(f"Wrote file: {dest.relative_to(REPO_ROOT)}")
        else:
            raise ValueError(f"Unknown plan kind: {kind}")


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec-dir", default="definitions", help="Canonical definitions directory (inside repo)")
    parser.add_argument("--out-dir", default="generated", help="Generated output directory (inside repo)")
    parser.add_argument("--apply", action="store_true", help="Apply changes (default is dry-run)")
    parser.add_argument("--list", action="store_true", help="List discovered skills/prompts and exit")
    parser.add_argument("--list-blocks", action="store_true", help="List discovered agent blocks and exit")
    args = parser.parse_args(argv)

    spec_root = (REPO_ROOT / args.spec_dir).resolve()
    out_root = (REPO_ROOT / args.out_dir).resolve()

    if not ensure_within_repo(spec_root) or not ensure_within_repo(out_root):
        print(f"ERROR: spec-dir/out-dir must be inside repo root: {REPO_ROOT}")
        sys.exit(2)

    if not spec_root.exists():
        print(f"No spec directory found at {spec_root}")
        sys.exit(1)

    skills_root = spec_root / "skills"
    prompts_root = spec_root / "prompts"

    if args.list:
        print("Global agent sources:")
        agents_root = spec_root / "agents"
        for p in [agents_root / "AGENTS_GEMINI.md", agents_root / "AGENTS_GPT52.md", agents_root / "AGENTS_LONG.md", agents_root / "AGENTS_SHORT.md"]:
            if p.exists():
                print(" -", p.relative_to(REPO_ROOT))
        print("\npi-agent profiles:")
        pi_profiles_dir = spec_root / "profiles" / "pi-agent"
        for profile in load_pi_agent_profiles(pi_profiles_dir):
            skills_info = profile.get("skills", "all")
            prompts_info = profile.get("prompts", "all")
            print(f" - {profile['name']} -> {profile['target_dir']}  (agents_file={profile['agents_file']}, skills={skills_info}, prompts={prompts_info})")
        print("\nSkills:")
        if skills_root.exists():
            for d in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
                print(" -", d.relative_to(REPO_ROOT))
        print("\nPrompts:")
        if prompts_root.exists():
            for f in sorted(prompts_root.glob("*.md")):
                print(" -", f.relative_to(REPO_ROOT))
        return

    if args.list_blocks:
        blocks_dir = spec_root / "agents" / "blocks"
        if not blocks_dir.exists():
            print(f"No blocks directory at {blocks_dir}")
            return
        print("Agent blocks:")
        for f in sorted(blocks_dir.glob("*.md")):
            print(" -", f.relative_to(REPO_ROOT))
        return

    planned: list[tuple] = []
    planned += plan_global_agent_files(out_root, spec_root)

    # Tool-specific derived artifacts
    planned += plan_gemini_command_files(spec_root, out_root)
    planned += plan_gemini_skill_copies(spec_root, out_root)
    planned += plan_copilot_skill_copies(spec_root, out_root)
    planned += plan_cursor_skill_copies(spec_root, out_root)

    # pi-agent profiles (each profile controls agents_file, skills subset, prompts subset)
    pi_profiles_dir = spec_root / "profiles" / "pi-agent"
    pi_profiles = load_pi_agent_profiles(pi_profiles_dir)
    if not pi_profiles:
        print(f"WARNING: No pi-agent profiles found in {pi_profiles_dir}. Skipping pi-agent generation.")
    for profile in pi_profiles:
        planned += plan_pi_agent_profile(profile, spec_root, out_root)

    if not planned:
        print("Nothing to do: no AGENTS_*.md and no definitions/skills or definitions/prompts found")
        return

    print_plan(planned)

    if not args.apply:
        print("Dry-run complete. No files written. Use --apply to write into the output directory.")
        return

    apply_plan(planned, out_root)
    print("\nAll done.")


if __name__ == "__main__":
    main()

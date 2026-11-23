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
  - definitions/pi-agent.toml                       (Pi asset selection)
  - definitions/profiles/copilot/<name>.toml        (Copilot profile configs)

Generated output (ephemeral build artifacts):
  - generated/README.md                    (copied from definitions/STRUCTURE.md)
  - generated/propagation.svg              (diagram used by generated/README.md)

  - generated/gemini/GEMINI.md
  - generated/gemini/commands/*.md         (prompt templates derived from definitions/prompts)
  - generated/gemini/skills/<skill>/...    (copied 1:1 from definitions/skills)

  - generated/codex/AGENTS.md
  - generated/codex/marketplace/              (local marketplace with the dev-bin skills plugin)

  - generated/claude/CLAUDE.md
  - generated/claude/commands/*.md         (prompt templates derived from definitions/prompts)
  - generated/claude/skills/<skill>/...    (copied 1:1 from definitions/skills)

  - generated/copilot/copilot-instructions.md
  - generated/copilot/skills/<skill>/...

  - generated/copilot-profiles/<name>/.target              (deploy target path, read by agents_files_cp.sh)
  - generated/copilot-profiles/<name>/copilot-instructions.md
  - generated/copilot-profiles/<name>/skills/...           (subset or all skills per profile config)

  - generated/cursor/skills/<skill>/...

  - generated/pi-agent/AGENTS.md
  - generated/pi-agent/skills/...
  - generated/pi-agent/prompts/...

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
import hashlib
import json
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


SUPERVISOR_RUNTIME_SKILLS = frozenset({
    "sub-agent-cmux-supervisor",
    "sub-agent-herdr-supervisor",
})
MANAGED_SKILL_MARKER = ".data-dir-agents-managed"


def managed_skill_marker(deployment: str, skill_name: str) -> str:
    return "\n".join((
        "owner=data-dir-agents",
        f"deployment={deployment}",
        f"skill={skill_name}",
        "schema=1",
        "",
    ))


def plan_skill_bundle(
    skill_dir: Path,
    dest: Path,
    spec_root: Path,
    deployment: str,
) -> list[tuple]:
    """Copy a self-contained skill package with ownership provenance."""
    planned = [plan_dir_copy(skill_dir, dest)]
    if skill_dir.name in SUPERVISOR_RUNTIME_SKILLS:
        runtime = spec_root / "runtime" / "pi-worker-runtime.sh"
        if not runtime.is_file():
            raise FileNotFoundError(f"Supervisor runtime not found: {runtime}")
        planned.append(plan_file_copy(runtime, dest / "scripts" / runtime.name))
    planned.append(plan_write_file(
        skill_dir,
        dest / MANAGED_SKILL_MARKER,
        managed_skill_marker(deployment, skill_dir.name),
    ))
    return planned


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

    # Claude Code
    claude_src = agents_root / "AGENTS_CLAUDE.md"
    if claude_src.exists():
        _resolve_and_plan(claude_src, out_root / "claude" / "CLAUDE.md")

    # Codex / Copilot base
    gpt52_src = agents_root / "AGENTS_GPT52.md"
    if gpt52_src.exists():
        _resolve_and_plan(
            gpt52_src,
            out_root / "codex" / "AGENTS.md",
            out_root / "copilot" / "copilot-instructions.md",
        )

    return planned


def plan_pi_agent(spec_root: Path, out_root: Path) -> list[tuple]:
    manifest = spec_root / "pi-agent.toml"
    if not manifest.is_file():
        return []
    with manifest.open("rb") as file:
        settings = tomllib.load(file)

    dest = out_root / "pi-agent"
    agents_src = spec_root / "agents" / settings["agents_file"]
    text = agents_src.read_text(encoding="utf-8")
    blocks = agents_src.parent / "blocks"
    if blocks.is_dir():
        text = resolve_placeholders(text, blocks)
    planned = [plan_write_file(agents_src, dest / "AGENTS.md", text)]

    for name in settings["skills"]:
        skill_dir = spec_root / "skills" / name
        if not (skill_dir / "SKILL.md").is_file():
            raise FileNotFoundError(f"Pi skill not found: {skill_dir}")
        planned += plan_skill_bundle(skill_dir, dest / "skills" / name, spec_root, "pi-agent")

    for name in settings["prompts"]:
        prompt_src = spec_root / "prompts" / name
        if not prompt_src.is_file():
            raise FileNotFoundError(f"Pi prompt not found: {prompt_src}")
        planned.append(plan_file_copy(prompt_src, dest / "prompts" / name))
    return planned


def load_copilot_profiles(profiles_dir: Path) -> list[dict]:
    """Load all Copilot profile configs from a profiles directory."""
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


def plan_copilot_profile(profile: dict, spec_root: Path, out_root: Path) -> list[tuple]:
    """Plan generation of a single Copilot profile."""
    planned = []
    profile_name = profile["name"]
    profile_out = out_root / "copilot-profiles" / profile_name

    agents_root = spec_root / "agents"
    blocks_dir = agents_root / "blocks"

    # .target file (deploy destination, read by agents_files_cp.sh)
    planned.append(plan_write_file(
        spec_root / "profiles" / "copilot" / f"{profile_name}.toml",
        profile_out / ".target",
        profile["target_dir"],
    ))

    # Resolve the named instructions template.
    agents_src = agents_root / profile["agents_file"]
    if not agents_src.exists():
        raise FileNotFoundError(f"Profile '{profile_name}' references missing agents_file: {agents_src}")
    text = agents_src.read_text(encoding="utf-8")
    if blocks_dir.exists():
        text = resolve_placeholders(text, blocks_dir)
    planned.append(plan_write_file(agents_src, profile_out / "copilot-instructions.md", text))

    # Skills: all if key absent, filtered list if present, none if empty list
    skills_root = spec_root / "skills"
    skills_allowlist = profile.get("skills", None)  # None = all
    if skills_root.exists() and skills_allowlist != []:
        for skill_dir in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
            if skills_allowlist is None or skill_dir.name in skills_allowlist:
                planned += plan_skill_bundle(
                    skill_dir,
                    profile_out / "skills" / skill_dir.name,
                    spec_root,
                    f"copilot-profiles/{profile_name}",
                )

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
        planned += plan_skill_bundle(skill_dir, dest, spec_root, "gemini")

    return planned


def _codex_skill_version(planned: list[tuple], plugin: Path) -> str:
    # Codex caches skills by plugin install path, which includes the version.
    # Hash the final package inputs so every meaningful update rotates that path.
    fingerprints = {}
    for kind, source, dest, *content in planned:
        if kind == "writefile":
            fingerprints[dest.relative_to(plugin).as_posix()] = (0, hashlib.sha256(content[0].encode()).hexdigest())
            continue
        files = source.rglob("*") if kind == "copydir" else (source,)
        for file in files:
            if file.is_symlink():
                raise ValueError(f"Codex plugins do not copy symlinks: {file}")
            if file.is_file():
                target = dest / file.relative_to(source) if kind == "copydir" else dest
                fingerprints[target.relative_to(plugin).as_posix()] = (
                    file.stat().st_mode & 0o111, hashlib.sha256(file.read_bytes()).hexdigest()
                )

    digest = hashlib.sha256(json.dumps(fingerprints, sort_keys=True).encode()).hexdigest()[:12]
    return f"1.0.0+{digest}"


def plan_codex_marketplace(spec_root: Path, out_root: Path):
    skills_root = spec_root / "skills"
    if not skills_root.exists():
        return []

    codex_root = out_root / "codex"
    marketplace = codex_root / "marketplace"
    plugin = marketplace / "plugins" / "dev-bin"
    planned = []
    for skill_dir in sorted(skills_root.iterdir()):
        if skill_dir.is_dir():
            if skill_dir.is_symlink() or not (skill_dir / "SKILL.md").is_file():
                raise ValueError(f"Invalid Codex skill: {skill_dir}")
            planned += plan_skill_bundle(skill_dir, plugin / "skills" / skill_dir.name, spec_root, "codex")

    manifest = {
        "name": "dev-bin",
        "version": _codex_skill_version(planned, plugin),
        "description": "Agent skills maintained in dev-bin.",
        "skills": "./skills/",
    }
    catalog = {
        "name": "dev-bin-local",
        "plugins": [{"name": "dev-bin", "source": {"source": "local", "path": "./plugins/dev-bin"}}],
    }
    planned += [
        plan_write_file(skills_root, plugin / ".codex-plugin" / "plugin.json", json.dumps(manifest, indent=2) + "\n"),
        plan_write_file(skills_root, marketplace / ".agents" / "plugins" / "marketplace.json", json.dumps(catalog, indent=2) + "\n"),
        plan_write_file(skills_root, codex_root / ".data-dir-agents-managed", "owner=data-dir-agents\ndeployment=codex\nschema=1\n"),
    ]
    return planned


def verify_codex_bundle(spec_root: Path, out_root: Path) -> None:
    codex = out_root / "codex"
    plugin = codex / "marketplace" / "plugins" / "dev-bin"
    manifest = plugin / ".codex-plugin" / "plugin.json"
    marker = codex / MANAGED_SKILL_MARKER
    catalog = codex / "marketplace" / ".agents" / "plugins" / "marketplace.json"
    expected = {
        item[2]: item[3]
        for item in plan_codex_marketplace(spec_root, out_root)
        if item[0] == "writefile" and item[2] in (manifest, marker, catalog)
    }
    if manifest not in expected:
        raise ValueError("Codex bundle is stale: missing canonical skill sources")

    agents = spec_root / "agents"
    expected[codex / "AGENTS.md"] = resolve_placeholders(
        (agents / "AGENTS_GPT52.md").read_text(encoding="utf-8"), agents / "blocks"
    )
    for path, contents in expected.items():
        if not path.is_file() or path.read_bytes() != contents.encode("utf-8"):
            raise ValueError(f"Codex bundle is stale: {path.relative_to(out_root)}")

    skills = plugin / "skills"
    if _codex_skill_version([plan_dir_copy(skills, skills)], plugin) != json.loads(expected[manifest])["version"]:
        raise ValueError("Codex bundle is stale: generated skill contents differ from the manifest")


def plan_claude_command_files(spec_root: Path, out_root: Path):
    """Generate Claude Code slash command templates.

    Prompts from definitions/prompts/*.md are copied 1:1 into generated/claude/commands/.
    Claude Code discovers user commands from ~/.claude/commands/*.md.
    """

    planned = []

    prompts_root = spec_root / "prompts"
    if prompts_root.exists():
        for prompt_file in sorted(prompts_root.glob("*.md")):
            dest = out_root / "claude" / "commands" / prompt_file.name
            planned.append(plan_file_copy(prompt_file, dest))

    return planned


def plan_claude_skill_copies(spec_root: Path, out_root: Path):
    """Generate Claude Code Agent Skills.

    Claude Code discovers user skills from ~/.claude/skills/<skill>/...
    Same format as Copilot: full skill directories 1:1.
    """

    skills_root = spec_root / "skills"
    if not skills_root.exists():
        return []

    planned = []
    for skill_dir in sorted([p for p in skills_root.iterdir() if p.is_dir()]):
        dest = out_root / "claude" / "skills" / skill_dir.name
        planned += plan_skill_bundle(skill_dir, dest, spec_root, "claude")

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
        planned += plan_skill_bundle(skill_dir, dest, spec_root, "copilot")

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
        planned += plan_skill_bundle(skill_dir, dest, spec_root, "cursor")

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
        for p in [agents_root / "AGENTS_GEMINI.md", agents_root / "AGENTS_CLAUDE.md", agents_root / "AGENTS_GPT52.md", agents_root / "AGENTS_LONG.md", agents_root / "AGENTS_SHORT.md"]:
            if p.exists():
                print(" -", p.relative_to(REPO_ROOT))
        print("\nCopilot profiles:")
        copilot_profiles_dir = spec_root / "profiles" / "copilot"
        for profile in load_copilot_profiles(copilot_profiles_dir):
            skills_info = profile.get("skills", "all")
            print(f" - {profile['name']} -> {profile['target_dir']}  (agents_file={profile['agents_file']}, skills={skills_info})")
        if (spec_root / "pi-agent.toml").is_file():
            print("\nPi configuration: pi-agent.toml -> ~/.pi/agent")
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
    planned += plan_codex_marketplace(spec_root, out_root)
    planned += plan_claude_command_files(spec_root, out_root)
    planned += plan_claude_skill_copies(spec_root, out_root)
    planned += plan_copilot_skill_copies(spec_root, out_root)
    planned += plan_cursor_skill_copies(spec_root, out_root)

    # Copilot profiles (each profile controls agents_file and skills subset)
    copilot_profiles_dir = spec_root / "profiles" / "copilot"
    copilot_profiles = load_copilot_profiles(copilot_profiles_dir)
    for profile in copilot_profiles:
        planned += plan_copilot_profile(profile, spec_root, out_root)

    planned += plan_pi_agent(spec_root, out_root)

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

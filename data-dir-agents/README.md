Agents Data Directory — Skills, Profiles & Agent Guidance

Canonical, versioned source of truth for agent skills, profiles, and instruction templates deployed across multiple platforms (Gemini, Codex, Copilot, Cursor, pi-agent).

## Layout

```
definitions/            ← edit here (source of truth)
├── agents/            agent instruction templates (AGENTS_*.md)
├── skills/<name>/     skill directories (SKILL.md + supporting files)
├── profiles/          profile TOMLs (pi-agent, copilot)
├── prompts/           prompt templates
├── AGENTS.md          repo workflow instructions
└── STRUCTURE.md       full pipeline overview

generated/             ← build artifacts (regenerated, never edit directly)
```

See `definitions/skills/README.md` for the full skills catalog (taxonomy, categories, naming conventions).

## Workflow

1. **Edit** files under `definitions/` only.
2. **Propagate & deploy:** run `agents_files_cp.sh` (in `$PATH`) to generate artifacts and copy them to runtime locations.
3. **Commit both** the source change (`definitions/...`) **and** the generated files (`generated/...`).
4. **Push.**

Generated files are derived artifacts — the repo must always be in a consistent state.

## Deployment targets

| Target | Output |
|--------|--------|
| Gemini | `generated/gemini/GEMINI.md` + skills |
| Codex | `generated/codex/AGENTS.md` |
| Copilot | `generated/copilot/copilot-instructions.md` + skills |
| Cursor | `generated/cursor/skills/...` |
| pi-agent | `generated/pi-agent-profiles/<name>/AGENTS.md` + skills + prompts |
| Copilot profiles | `generated/copilot-profiles/<name>/copilot-instructions.md` + skills |

pi-agent profiles: `default`, `minimal`, `partner`, `opsx`, `zero`. Copilot profiles: `default`, `minimal`, `partner`. See `definitions/skills/README.md` for how skills attach to profiles.

## Adding / renaming skills

- **Add:** create `definitions/skills/<name>/SKILL.md`, optionally add supporting files, list in profile TOMLs if filtered.
- **Rename/remove:** rename the directory, update TOML references, run `agents_files_cp.sh --delete` to clean stale generated dirs.
- Details: `definitions/skills/README.md` → "Adding a new skill" / "Renaming or removing a skill".

## Tools

Skill-specific tools (webs.sh, d2to.sh, plantuml.sh, ctags_symbol_map.py, agent-browser, etc.) are documented in their respective `SKILL.md` files. Check `-h` flags or inspect scripts for usage details.
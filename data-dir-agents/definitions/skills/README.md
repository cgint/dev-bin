# Skills: taxonomy and naming

Skills are the modular building blocks attached to agent profiles. Each skill lives in its own directory under `definitions/skills/<name>/` and is copied wholesale into `generated/<target>/skills/<name>/` during propagation.

## How skills attach to agents

- **Global (unfiltered) profiles** — `default` (pi-agent), `default` (copilot) — pick up *every* skill directory in `definitions/skills/`.
- **Filtered profiles** — `minimal`, `opsx`, `partner` (and Copilot equivalents) — declare an explicit `skills = [...]` list in their `[profile]` TOML. Only listed skills are deployed.
- Some targets (Gemini, Codex, Copilot CLI base) receive *all* skills regardless of profile filtering; profile-level skill lists only affect the profile-specific output directories.

## Skill naming convention

| Pattern | Meaning | Example |
|---------|---------|---------|
| `<name>` | Stable, always-available skill | `web-search`, `diagrams` |
| `<name>-retro` | Post-hoc variant of a standing skill | `criticalthink-retro` replaces `criticalthink` |
| `<name>-<mode>` | Variant tuned for a specific mode/context | — |

**Rule:** When a skill replaces another (rename, refactor, specialization), move the old directory aside with a suffix (`-retro`, `-v2`, etc.) and update the TOML skill lists in every profile that references it. The generator copies directories by name, so stale directories linger in `generated/` until cleaned up with `--delete`.

## Skill categories

### Collaboration & discipline
Skills that shape how the agent behaves in partnership with the user.

| Skill | Purpose |
|-------|---------|
| `grounded-pairing-discipline` | Standing collaboration posture — critical, constructive, concise |
| `criticalthink-retro` | Post-hoc self-audit: stress-test your own previous response |
| `bootstrap-pairing-memory` | Initialize the pairing memory system |
| `skill-architect` | Design and author new agent skills |

### Code exploration & analysis
Skills for understanding, searching, and navigating codebases.

| Skill | Purpose |
|-------|---------|
| `codebase-search` | Deep code search with semantic and structural awareness |
| `colgrep` | Column-aware grep patterns for code |
| `read-code-structure` | Symbol maps and structural extraction (ctags) |

### Documentation & modeling
Skills for diagrams, docs, and architectural artifacts.

| Skill | Purpose |
|-------|---------|
| `diagrams` | D2 and PlantUML rendering (D2→SVG, PlantUML→SVG/PNG) |
| `grill-with-docs` | Stress-test plans against the domain model and update docs inline |

### Workflow & process
Skills tied to specific development methodologies.

| Skill | Purpose |
|-------|---------|
| `openspec-apply-change` | Implement tasks from an OpenSpec change |
| `openspec-explore` | Explore and clarify an OpenSpec change |
| `openspec-propose` | Propose a new change with design artifacts |
| `openspec-archive-change` | Archive a completed OpenSpec change |

### Utility & tooling
General-purpose helper skills.

| Skill | Purpose |
|-------|---------|
| `my-tools-toolbox` | webs.sh, url2md.py, pi-session-to-md, and other utilities |

### Web & external services
Skills for browsing and searching the web.

| Skill | Purpose |
|-------|---------|
| `web-search` | Multi-engine web search (OpenAI, Brave, Perplexity, etc.) |
| `web-browser-use` | Automated browser tasks via agent-browser CLI |

### Model-specific rules
Skills that apply only under certain model conditions.

| Skill | Purpose |
|-------|---------|
| `gemini-model-rules` | Protocol for all Google Gemini model variants |

### Delegation
Skills for multi-agent coordination.

| Skill | Purpose |
|-------|---------|
| `sub-agent-handoff` | Delegate bounded work to sub-agents with explicit context |

## Adding a new skill

1. Create `definitions/skills/<name>/SKILL.md` (the entry point).
2. Optionally add supporting files (scripts, examples, subdirectories).
3. If the skill should be profile-filtered, add `<name>` to the `skills = [...]` list in the relevant TOML profile(s).
4. Run `agents_files_cp.sh` to propagate and deploy.

## Renaming or removing a skill

1. Rename the directory: `mv definitions/skills/<old> definitions/skills/<new>`.
2. Update all TOML profile references (`skills = [...]`).
3. Run `agents_files_cp.sh --delete` to remove stale directories from generated/deployed locations.
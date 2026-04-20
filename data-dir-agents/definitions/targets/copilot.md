# GitHub Copilot CLI target format

## What we generate

- `generated/copilot/copilot-instructions.md`
- `generated/copilot/skills/<skill>/...`
- `generated/copilot-profiles/<name>/copilot-instructions.md`
- `generated/copilot-profiles/<name>/skills/<skill>/...`

## What it deploys to

- `~/.copilot/copilot-instructions.md`
- `~/.copilot/skills/<skill>/...`
- `~/.copilot/profiles/<name>/copilot-instructions.md`
- `~/.copilot/profiles/<name>/skills/<skill>/...`

## Source of truth

- `definitions/agents/AGENTS_GPT52.md` (currently shared with Codex + pi-agent)

## Notes (concept mapping)

- Persistent instructions: Copilot CLI supports a personal instructions file at `~/.copilot/copilot-instructions.md` and repository instructions under `.github/copilot-instructions.md`.
- Skills: Copilot CLI discovers **Agent Skills** as folders under `~/.copilot/skills/<skill>/...` (or project skills under `.github/skills/<skill>/...`). Each skill must contain a `SKILL.md` with YAML frontmatter (`name`, `description`, ...). All skills under `definitions/skills/` are propagated here by default; when using a **Gemini** model, the `gemini-model-rules` skill carries the Gemini-specific model-ID guidance that generic instructions omit.
- Profiles: `copilot --config-dir <dir>` lets us keep multiple isolated Copilot config trees. In this repo those trees are generated from `definitions/profiles/copilot/*.toml` and launched via `copilot-profile <name>`.

## Skill structure

Each skill is a directory containing `SKILL.md` at its root. Optional subdirs: `scripts/`, `references/`, `assets/`.

**Directory layout:**

```
my-skill/
├── SKILL.md          # Required
├── scripts/          # Optional - executable code
├── references/       # Optional - additional docs
└── assets/           # Optional - templates, images
```

**SKILL.md minimal example:**

```markdown
---
name: github-actions-failure-debugging
description: Guide for debugging failing GitHub Actions workflows. Use this when asked to debug failing GitHub Actions workflows.
---

To debug failing GitHub Actions workflows in a pull request, follow this process:

1. Use the `list_workflow_runs` tool to look up recent workflow runs
2. Use the `summarize_job_log_failures` tool to get an AI summary of failed job logs
3. Fix the failing build.
```

## References

- https://docs.github.com/copilot/concepts/agents/about-agent-skills
- https://github.com/github/copilot-cli
- https://docs.github.com/copilot/concepts/agents/about-copilot-cli
- https://docs.github.com/en/copilot

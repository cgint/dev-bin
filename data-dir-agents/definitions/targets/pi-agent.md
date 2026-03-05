# pi-agent target format

## What we generate

- `generated/pi-agent/AGENTS.md`
- `generated/pi-agent/skills/<skill>/...`
- `generated/pi-agent/prompts/*.md`

## What it deploys to

- `~/.pi/agent/AGENTS.md`
- `~/.pi/agent/skills/<skill>/...`
- `~/.pi/agent/prompts/*.md`

## Sources of truth

- `definitions/agents/AGENTS_GPT52.md` → `generated/pi-agent/AGENTS.md`
- `definitions/skills/<skill>/...` → generated skills
- `definitions/prompts/*.md` → generated prompts

## Notes

- Skills are directories (not single files) and may contain scripts/examples.
- `propagate_definitions.py --apply` fully regenerates `generated/`.
- pi-agent uses the Agent Skills open standard (same as Copilot, Gemini, Cursor).

## Skill structure

Each skill is a directory containing `SKILL.md` at its root. Optional subdirs: `scripts/`, `references/`, `assets/`. Deploys to `~/.pi/agent/skills/<skill>/` (user) or `.pi/skills/<skill>/` (project).

**Directory layout:**

```
my-skill/
├── SKILL.md          # Required
├── scripts/          # Optional
├── references/       # Optional
└── assets/           # Optional
```

**SKILL.md minimal example:**

```markdown
---
name: my-skill
description: Short description of what this skill does and when to use it.
---

# My Skill

Instructions and guidelines for the agent.
```
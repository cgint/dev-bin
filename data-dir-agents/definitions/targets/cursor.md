# Cursor IDE target format

## What we generate

- `generated/cursor/skills/<skill>/...`

## What it deploys to

- `~/.cursor/skills/<skill>/...`

## Source of truth

- `definitions/skills/<skill>/...` (1:1 copy, no transformation)

## Notes (concept mapping)

- Cursor discovers skills from `~/.cursor/skills/` (user-level) or `.cursor/skills/` (project-level). We deploy to user-level.
- Each skill must be a folder containing `SKILL.md` with YAML frontmatter (`name`, `description`).
- Optional subdirs: `scripts/`, `references/`, `assets/`.
- Cursor uses Rules (`.cursor/rules/`) for agent instructions—not a single AGENTS.md. Skills propagation is skills-only.

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
name: deploy-app
description: Deploy the application to staging or production. Use when deploying code or when the user mentions deployment, releases, or environments.
---

# Deploy App

Deploy using the provided scripts. Run `scripts/deploy.sh <environment>` where environment is `staging` or `production`.
```

## References

- https://cursor.com/docs/context/skills
- https://agentskills.io

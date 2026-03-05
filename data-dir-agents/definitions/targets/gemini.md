# Gemini CLI target format

## What we generate

- `generated/gemini/GEMINI.md`
- `generated/gemini/commands/*.md` (from `definitions/prompts/*.md`)
- `generated/gemini/skills/<skill>/...` (from `definitions/skills/<skill>/...`)

## What it deploys to

- `~/.gemini/GEMINI.md`
- `~/.gemini/commands/*.md`
- `~/.gemini/skills/<skill>/...`

## Source of truth

- `definitions/agents/AGENTS_GEMINI.md`

## Notes (concept mapping)

- Persistent instructions: `GEMINI.md` (global and/or project-level)
- Commands: Gemini CLI supports slash commands and custom commands.
- Context injection: `@path` syntax / include file contents.
- Ignore rules: `.geminiignore`, trusted folders.

## Skill structure

Each skill is a directory containing `SKILL.md` at its root. Optional subdirs: `scripts/`, `references/`, `assets/`.

**Directory layout:**

```
my-skill/
├── SKILL.md          # Required - instructions and metadata
├── scripts/          # Optional - executable scripts
├── references/       # Optional - static documentation
└── assets/           # Optional - templates and resources
```

**SKILL.md minimal example:**

```markdown
---
name: code-reviewer
description: Use this skill to review code. It supports both local changes and remote Pull Requests.
---

# Code Reviewer

This skill guides the agent in conducting thorough code reviews.

## Workflow

1. Determine review target (remote PR or local changes)
2. Check for correctness, security, and maintainability
3. Provide structured feedback.
```

## References

- https://geminicli.com/docs/cli/skills
- https://geminicli.com/docs/cli/creating-skills
- https://geminicli.com/
- https://geminicli.com/docs/cli/gemini-md
- https://geminicli.com/docs/cli/commands
- https://geminicli.com/docs/extensions

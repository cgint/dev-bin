# Target formats (definitions → generated)

This folder documents the **output formats** we generate for each supported tool.

These docs are **stable, canonical explanations** (they live in `definitions/`).
They are not copied into `generated/` (which is meant to contain deployable artifacts only).

## Targets

- [Gemini CLI](./gemini.md)
- [GitHub Copilot CLI](./copilot.md)
- [Codex](./codex.md)
- [Cursor](./cursor.md)
- [pi-agent](./pi-agent.md)

## Quick mapping (source → generated)

- `definitions/agents/AGENTS_GEMINI.md` → `generated/gemini/GEMINI.md`
- `definitions/prompts/*.md` → `generated/gemini/commands/*.md`
- `definitions/skills/<skill>/...` → `generated/gemini/skills/<skill>/...`

- `definitions/agents/AGENTS_GPT52.md` →
  - `generated/codex/AGENTS.md`
  - `generated/copilot/copilot-instructions.md`
  - `generated/pi-agent/AGENTS.md`

- `definitions/skills/<skill>/...` →
  - `generated/copilot/skills/<skill>/...`
  - `generated/cursor/skills/<skill>/...`

- `definitions/skills/<skill>/...` → `generated/pi-agent/skills/<skill>/...`
- `definitions/prompts/*.md` → `generated/pi-agent/prompts/*.md`

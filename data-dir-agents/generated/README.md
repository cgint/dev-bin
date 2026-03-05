# Definitions: canonical agent content

## Diagram

![Propagation overview](./propagation.svg)

## What lives in `definitions/` (canonical)

This directory is the **single source of truth** for all agent-related content in this repo.

Layout:

- `definitions/agents/`
  - `AGENTS_GEMINI.md` → source for Gemini CLI `GEMINI.md`
  - `AGENTS_GPT52.md` → source for Codex (`~/.codex/AGENTS.md`), Copilot CLI instructions, and pi-agent `AGENTS.md`
  - `AGENTS_SHORT.md`, `AGENTS_LONG.md` → optional variants (currently not used by the generator)
- `definitions/skills/<skill>/...`
  - Full **pi-agent skill directories** (must remain directories; can include scripts/subfolders)
- `definitions/prompts/*.md`
  - pi-agent prompt templates copied 1:1

## What happens to `definitions/`

Nothing modifies `definitions/` automatically.

- You edit files under `definitions/`.
- The generator reads from `definitions/` and writes tool-specific outputs into `generated/`.
- Deployment copies from `generated/` into your user config dirs (e.g. `~/.pi/agent`).

## Target formats (output details)

See: [`definitions/targets/`](../definitions/targets/README.md)

## Generator behavior (important)

- Script: `propagate_definitions.py`
- Output: `generated/`
- When run with `--apply`:
  - `generated/` is fully deleted and recreated (to avoid stale files)
  - so **do not manually edit files inside `generated/`** unless you are okay losing those edits.

## Mappings (definitions → generated → deployed)

### Gemini CLI
- `definitions/agents/AGENTS_GEMINI.md`
  → `generated/gemini/GEMINI.md`
  → `~/.gemini/GEMINI.md`

- `definitions/prompts/*.md`
  → `generated/gemini/commands/*.md`
  → `~/.gemini/commands/*.md`

- `definitions/skills/<skill>/...`
  → `generated/gemini/skills/<skill>/...`
  → `~/.gemini/skills/<skill>/...`

### Codex
- `definitions/agents/AGENTS_GPT52.md`
  → `generated/codex/AGENTS.md`
  → `~/.codex/AGENTS.md`

### Copilot CLI
- `definitions/agents/AGENTS_GPT52.md`
  → `generated/copilot/copilot-instructions.md`
  → `~/.copilot/copilot-instructions.md`

- `definitions/skills/<skill>/...`
  → `generated/copilot/skills/<skill>/...`
  → `~/.copilot/skills/<skill>/...`

### pi-agent
- `definitions/agents/AGENTS_GPT52.md`
  → `generated/pi-agent/AGENTS.md`
  → `~/.pi/agent/AGENTS.md`

- `definitions/skills/<skill>/...`
  → `generated/pi-agent/skills/<skill>/...`
  → `~/.pi/agent/skills/<skill>/...`

- `definitions/prompts/*.md`
  → `generated/pi-agent/prompts/*.md`
  → `~/.pi/agent/prompts/*.md`

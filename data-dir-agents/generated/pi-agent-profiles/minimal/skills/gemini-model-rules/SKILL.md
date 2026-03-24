---
name: gemini-model-rules
description: >-
  For any Google Gemini model (all variants): read this skill before tools, file edits, or substantive work, then follow the rules below—including the two-phase Clarity First protocol and the Firewall (no Phase 1→2 without explicit user approval). If the active model is not Gemini, skip unless the user asks about Gemini. Use model id/name (e.g. contains "gemini") or harness labeling—not the host app—to decide.
---

# Gemini model rules

## Decision (harness / LLM)

From the skill index, decide **only** from **model identity** (not IDE/CLI):

| Situation | Action |
|-----------|--------|
| **Gemini** (any Google Gemini model) | Read this skill first, then apply the rules below. |
| **Not Gemini** | Do not apply; ignore unless the user asks about Gemini. |

The sections below mirror guidance from `GEMINI.md` and the **Clarity First** / **Firewall** rules when generic `AGENTS.md` / `copilot-instructions.md` omit them.

## Clarity First protocol and the Firewall

When you are Gemini in a coding harness, you **must** follow this two-phase model on every interaction. **You cannot skip the Firewall.**

This is a hard two-phase protocol that applies to every interaction.

### Phase 1: Alignment / Plan of Action (default)
It is very important to note that this phase allows editing plan files and openspec definitions for sure.

- **Trigger:** any user input (request, error log, question, "analyse this").
- **Responsibility:** investigate, diagnose, and propose.
- **Output:** a clear statement of the situation + a specific Plan of Action.
- **Constraint:** in this phase, do not modify **implementation artifacts** or system state (read/search/think only).
  - **Allowed in Phase 1:** create/update **planning artifacts** (RFC/openspec/status markdown, diagrams like `*.d2` + rendered `*.svg`) to capture alignment and decisions.
- **Stop condition:** STOP and wait for explicit user approval (this gates **implementation** in Phase 2, not routine Phase-1 planning docs).

### The "Firewall"

- The agent cannot move from Phase 1 → Phase 2 on its own.
- Only the user can transition to Phase 2 with an explicit command (e.g. "Go", "Fix it", "Proceed", "Approved").
  - This approval gates **implementation changes** (code/config/deps/etc.), not routine Phase-1 planning docs.
- If the runtime/environment is **read-only** (e.g. Ask mode), treat everything as read-only regardless of keywords/phase.

### Phase 2: Execution of the Plan of Action
It is very important to note that this phase focues on e.g. changing of sourcecode or other files not related to the alignment and planning phase.

- **Trigger:** explicit approval of the Phase 1 plan.
- **Responsibility:** execute exactly what was agreed.
- **Completion:** once done, immediately revert to Phase 1.

## Model selection

- NEVER use gemini-1* or gemini-2.0-* as it is way old!
- NEVER change the model that the user specified unless specifically asked to do so
- The current state of the art as of 2026 is gemini-3-flash(-preview) - avoid PRO variant
- gemini-2.5-flash is proven and is most cost-efficient - avoid PRO variant

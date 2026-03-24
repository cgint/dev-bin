---
name: gemini-model-rules
description: >-
  For any Google Gemini model (all variants): read this skill before tools, file edits, or substantive work, then follow the rules below. If the active model is not Gemini, skip unless the user asks about Gemini. Use model id/name (e.g. contains "gemini") or harness labeling—not the host app—to decide.
---

# Gemini model rules

## Decision (harness / LLM)

From the skill index, decide **only** from **model identity** (not IDE/CLI):

| Situation | Action |
|-----------|--------|
| **Gemini** (any Google Gemini model) | Read this skill first, then apply the rules below. |
| **Not Gemini** | Do not apply; ignore unless the user asks about Gemini. |

The following matches extra constraints from `GEMINI.md` when generic `AGENTS.md` / `copilot-instructions.md` omit them.

## Model selection

- NEVER use gemini-1* or gemini-2.0-* as it is way old!
- NEVER change the model that the user specified unless specifically asked to do so
- The current state of the art as of 2026 is gemini-3-flash(-preview) - avoid PRO variant
- gemini-2.5-flash is proven and is most cost-efficient - avoid PRO variant

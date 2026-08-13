# Subagent Evolutions: Intent-Based Tiering Plan

## Overview & Intent
The goal of subagent evolutions is to decouple supervisor orchestration from raw vendor model strings (`github-copilot/gpt-5.6-terra`, `google/gemini-3.6-flash`) and CLI parameters (`--thinking minimal/medium`). Supervisors delegate work by expressing **intent, capability required, and tool boundaries** rather than managing vendor mechanics.

---

## 1. Core Architecture: 2D Orthogonal Model

Instead of mixing security permissions with model capability into single rigid names, the evolution uses a two-dimensional orthogonal model:

$$\text{Subagent Execution} = \text{Capability Tier} \times \text{Permission Policy}$$

### Dimension 1: Capability Tier
Defines reasoning intensity, token/latency profile, and model selection:

* **`fast`** (default for light/routine work): Low latency, minimal thinking budget.
* **`smart`** (default for complex edits/analysis): High reasoning capability, medium thinking budget.
* **`deep`** (optional heavy reasoning/large context): Extended thinking budget for complex architectural or multi-file reasoning.

### Dimension 2: Permission Policy (Wrapper Enforcement)
Defines tool availability and side-effect boundaries:

* **`readonly`** (`subagent-readonly.sh`): Enforces `--dm-read`, restricts tools to `read,bash,grep,find,ls`, and attaches `pi-focus-guard`.
* **`editable`** (`subagent.sh`): Grants edit/write permissions within explicit handoff file boundaries.

---

## 2. Intent-Based Tier Taxonomy & Mapping Matrix

| High-Level Tier / Alias | Capability Level | Default Thinking | Primary Models (with Fallbacks) | Permissible Modes |
| :--- | :--- | :--- | :--- | :--- |
| **`easy` / `fast`** | Fast / Cheap | `minimal` | 1. `github-copilot/gpt-5.6-luna`<br>2. `openai-codex/gpt-5.6-luna` | `readonly`, `editable` |
| **`daily` / `standard`** | Standard / Balanced | `minimal` | 1. `openai-codex/gpt-5.6-terra`<br>2. `github-copilot/gpt-5.6-terra` | `readonly`, `editable` |
| **`smart` / `deep`** | High Reasoning | `medium` | 1. `openai-codex/gpt-5.6-terra`<br>2. `github-copilot/gpt-5.6-terra` | `readonly`, `editable` |
| **`intelliscout`** | Large Context / Fast | `medium` | 1. `google/gemini-3.6-flash`<br>2. `github-copilot/gpt-5.6-terra` | **`readonly` only** |

---

## 3. Orchestration & Herdr Integration

1. **`herdr_start_subagent.sh` Update:**
   * Accepts optional `--tier <tier-name>` (defaults to `daily` for `editable`, `intelliscout` or `fast` for `readonly`).
   * Passes `--tier <tier-name>` down to `subagent.sh` / `subagent-readonly.sh`.

2. **Central Tier Resolver (`subagent_tiers.sh`):**
   * Shared helper used by wrappers to resolve `--tier` to `--model` and `--thinking`.
   * Enforces mode restrictions (e.g. rejects `subagent.sh intelliscout`).
   * Handles pre-flight auth verification across provider fallback chains.

---

## 4. State Transfer & Escalation Protocol

When a worker running on a lower tier (`fast`/`easy`) gets blocked or fails:
* **No Raw History Replays:** Do not pass raw multi-turn conversation logs across heterogeneous model families.
* **Structured Markdown Handoff:** The supervisor reads the worker's terminal report/`STATUS.md`, updates the handoff with specific findings, and launches a fresh subagent on a higher tier (`smart`).

---

## 5. Next Steps for Implementation

1. Create central tier mapping module (`~/.local/bin/subagent_tiers.sh`).
2. Update `subagent.sh` and `subagent-readonly.sh` to parse `--tier` via the central resolver.
3. Add `--tier` flag support and usage docs to `herdr_start_subagent.sh`.

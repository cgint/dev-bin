---
name: sub-agent-handoff
description: Delegating bounded work to sub-agents, handoff with explicit context and structured reporting. e.g. Data-heavy comparison, ...
---

# Sub-agent handoff protocol

Use this skill when delegating bounded work to a sub-agent that **cannot see** the lead agent’s chat history or previous sub-agent runs.

## Core principle

**No hidden context.** A sub-agent only knows what you explicitly provide in the handoff brief.

If the sub-agent needs information, it must request it in the **Work report** (don’t guess).

## When to delegate (good use-cases)

- **Scouting (read-only):** locate code, summarize behavior, find tests/docs, collect evidence.
- **Mechanical chores (bounded write):** e.g. run verification scripts, format, apply trivial renames *only inside explicitly allowed paths*.
- **Independent verification (read-only):** rerun tests/precommit, sanity-check diffs/spec alignment.

## Sub-agent roles

### 1) Scout (read-only)
- Output: concise findings with **paths + line ranges** and exact commands run.

### 2) Mechanic (bounded write)
- Allowed only when explicitly stated.
- Output: list of files changed + diff summary + commands run.

### 3) Reviewer/Verifier (read-only)
- Output: pass/fail plus the top actionable issues, with evidence.

## Context pack checklist (what the lead must provide)

Because the sub-agent can’t see your history, include:

- **Goal** and **success criteria** (how to know it’s done)
- **Repo/workdir** (absolute path) + **branch/commit** (if relevant)
- **Current state snapshot**
  - `git status` summary (or paste output)
  - any relevant logs / stack traces / failing test output
- **Constraints**
  - allowed paths + forbidden paths
  - read-only vs write allowed
  - timebox
- **Starting points**
  - key files to open first
  - keywords/symbols to search
- **Stop rules**
  - when uncertain or blocked: stop and report (don’t improvise)

## Handoff brief (copy/paste template)

Provide this block verbatim (fill in placeholders). Keep it short but complete.

### HANDOFF BRIEF

- **Handoff ID:** <unique-id or timestamp>
- **Role:** Scout | Mechanic | Reviewer
- **Goal (1 sentence):** <what to achieve>
- **Success criteria:**
  - <bullet>
  - <bullet>
- **Repo / working dir:** <absolute path>
- **Branch / commit (if known):** <branch> / <sha>
- **Scope (allowed):**
  - **Allowed paths:** <e.g. src/foo/, openspec/changes/...>
  - **Allowed actions:** Read-only | Write allowed (bounded) | Commands allowed
- **Non-goals (forbidden):**
  - Do not modify `.env` / secrets
  - Do not refactor unrelated code
  - Do not change files outside **Allowed paths**
  - Do not perform destructive ops (e.g. `rm -rf`)
- **Situation summary (context you can’t infer):**
  - <3–6 bullets>
- **Relevant evidence (paste or point to file):**
  - <logs / error text / test failure>
- **Starting points:**
  - <files>
  - <commands>
  - <search terms>
- **Timebox:** <e.g. 15–30 min>
- **Expected output format:** Use the “WORK REPORT” template below.

## Work report (required output)

The sub-agent must return the following sections.

### WORK REPORT

- **Handoff ID:** <same as brief>
- **What I did (high level):**
  - <bullets>
- **Findings / results:**
  - <bullets>
- **Evidence:**
  - <file paths + line ranges>
  - <or command output excerpts>
- **Commands run:**
  - `<command>` → <short outcome>
- **What worked / what didn’t:**
  - <bullets>
- **Risks / uncertainties / assumptions:**
  - <bullets>
- **Next step suggestions:**
  - <bullets>
- **If I changed files (only if allowed):**
  - **Files changed:** <list>
  - **Diff summary:** <brief>

## Integration checklist (what the lead does after the report)

- Decide: accept findings / request follow-up / abort.
- If changes were made: inspect diff, run verification.
- Update the plan/status based on evidence.
- Optionally delegate a **Reviewer/Verifier** sub-agent to independently confirm.

## Optional: how to run a sub-agent (simple `pi-profile minimal`)

When you just want a *simple, correct* delegated run, use the minimal profile in **print mode** and attach any context files with `@`:

```bash
pi-profile minimal -p \
  @plan/research/adapter_parity/CONTEXT.md \
  @lib/dspy/signature.ex \
  "<HANDOFF BRIEF (or short goal) here>"
```

Notes:
- You usually **do not need** to specify models, thinking levels, or tools; the profile + pi defaults handle that.
- If you explicitly need read-only mode, add `--tools read,bash`.

## Practical learnings (from real runs)

- **Keep it simple by default:** `pi-profile minimal -p @file ... "goal"` is the most reliable pattern.
- **Only specify tools when needed:** Pi enables tools by default; use `--tools read,bash` only when you want strict read-only.
- **Be careful with wrappers that force `--model`:** they can change provider selection and fail due to missing credentials.
- **Use handoffs when they protect the main context window:** multi-file scouting, inventories, collecting evidence, or repetitive/mechanical edits.
- **Avoid handoffs for tiny edits:** a one-liner or obvious local change is usually faster to do directly.
- **After a handoff:** review the diff/output first; if follow-up edits are needed, prefer a second handoff or explicitly label any driver-made fixups.
- **Concurrency:** running many handoffs in parallel can hit rate limits; batch/stagger if needed.

## Guardrails

- Prefer **evidence over speculation**.
- Never assume hidden intent; when unclear, report uncertainties and stop.
- If write access is granted: keep edits minimal, path-scoped, and reversible.

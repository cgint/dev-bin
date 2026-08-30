---
name: sub-agent-handoff
description: Delegating bounded work to sub-agents, handoff with explicit context and structured reporting. e.g. Data-heavy comparison, ...
---

# Sub-agent handoff protocol

Use this skill when delegating bounded work to a sub-agent that **cannot see** the lead agent’s chat history or previous sub-agent runs.

## Core principle

**No hidden context.** A sub-agent only knows what you explicitly provide in the handoff brief.

A handoff is a **context boundary**, not a transcript dump: the worker receives the facts needed to execute safely and retains raw command output, lockfile churn, and routine verification detail. The lead retains the intent, constraints, architecture, and acceptance decision.

If the sub-agent needs information, it must request it in the **Work report** (don’t guess).

## Working directory = launch directory (canonical rule)

**The worker must be started in the target directory named by the handoff.** A write-enabled worker’s write scope is the directory tree rooted at its launch cwd (the selected supervisor skill's worker launcher enforces this). To let an editable worker write to the handoff’s target paths, its launch cwd **must** be the narrowest directory tree containing **all** authorized writes — the permitted work **and** the required report/artifact path — expressed as an absolute path (the common ancestor when work spans sibling directories), not a wider repo root.

Keep two facts separate:

- **Handoff says the cwd:** the brief states the exact absolute target directory.
- **Launcher actually starts there:** the supervisor must launch the worker with that directory as its cwd — e.g. `--cwd /abs/target` in the Herdr launcher, or `cd` into it / create the pane there for a CMUX wrapper. Stating the directory in the brief is necessary but not sufficient; the launch must match.

## Delegation threshold

Use a subagent only when independent evidence, isolation, parallelism, or bounded execution provides more value than the launch, inspection, and cleanup overhead. Do trivial reads, obvious one-line edits, and immediate local checks directly. Do not delegate merely because a task can be split.

## Handoff forms

**Current capability — full artifact handoff:** the Herdr supervisor skill's `scripts/herdr-start-subagent.sh` currently requires a handoff file and report path. Use the full template below.

**Planned capability — compact inline brief (not available yet):** when the launcher supports it, use an inline brief only when the assignment is small, bounded, low-ambiguity, and expressible in one physical line. It still must state: exact target cwd; allowed and forbidden paths; goal; required checks; stop rule; and compact terminal `WORK REPORT` contract. Use the full artifact template for multiline or quoted instructions, code snippets, reusable evidence, ambiguity, risk, cross-cutting effects, or asynchronous work.

Do not invent an inline transport or skip the current handoff file before launcher support exists.

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
- **Repo root** (absolute path; where commands/context live) + **branch/commit** (if relevant)
- **Launch directory (write scope):** the narrowest absolute directory tree containing all authorized writes (work + report); the worker must be *started in* it (see the canonical rule above)
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
- **Repo root:** <absolute path>
- **Launch directory (write scope):** <absolute path — narrowest directory tree containing all authorized writes (work + report); the worker must be started here>
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
- **Completion/control channel:** CMUX-only (exact supervisor `surface:` ref + approved absolute report path) | Intercom (target name) | None
- **Timebox:** <e.g. 15–30 min>
- **Expected output format:** Use the "WORK REPORT" template below.

## Work report (required output)

The sub-agent must return the following sections. Keep raw logs in the worker context: report check names and pass/fail results, relevant paths/line ranges, and only error excerpts needed to support a decision. The supervisor independently checks diff/status and runs proportionate verification; a worker claim that tests passed is not sufficient evidence.

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

## Worker launch

This skill owns handoff brief and work-report content, not worker launch. For CMUX-supervised workers, follow the required launch command and tool rules in [sub-agent-cmux-supervisor](../sub-agent-cmux-supervisor/SKILL.md#worker-launch--required). Do not duplicate them here.

## Practical learnings (from real runs)

- **Use handoffs when they protect the main context window:** multi-file scouting, source adaptation, lockfile churn, test/precommit runs, inventories, collecting evidence, or repetitive/mechanical edits.
- **Avoid handoffs for tiny edits:** a one-liner or obvious local change is usually faster to do directly.
- **After a handoff:** review the compact report, then inspect the diff/status and run proportionate checks. Expand raw worker output only for a failure, contradiction, scope concern, or diff anomaly. If follow-up edits are needed, prefer a second handoff or explicitly label any driver-made fixups.
- **Concurrency:** running many handoffs in parallel can hit rate limits; batch/stagger if needed.

## Guardrails

- Prefer **evidence over speculation**.
- Never assume hidden intent; when unclear, report uncertainties and stop.
- If write access is granted: keep edits minimal, path-scoped, and reversible.

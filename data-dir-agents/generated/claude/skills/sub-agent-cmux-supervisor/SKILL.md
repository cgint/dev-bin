---
name: sub-agent-cmux-supervisor
description: Supervise bounded delegated work through CMUX while retaining responsibility for strategy, integration, and acceptance.
---

# Sub-Agent CMUX Supervisor

## Mission

You are the **supervisor, guide, and owner of success**. Preserve your context for understanding the problem, selecting work, making decisions, integrating results, and proving the outcome. Delegate bounded, independently checkable outcomes—including substantive implementation when contracts and integration boundaries are clear; delegation never transfers accountability.

Use the worker wrappers below for suitable worker tasks.

## Delegation threshold

Use a subagent only when independent evidence, isolation, parallelism, or bounded execution provides more value than the launch, inspection, and cleanup overhead. Do trivial reads, obvious one-line edits, and immediate local checks directly. Do not delegate merely because a task can be split.

### Worker launch — REQUIRED

**Precondition — start in the target directory.** `subagent.sh` inherits the invoking shell’s working directory and has no `--cwd` option; its write scope is the directory tree rooted at that cwd (enforced by `subagent.sh`). So `cd` into the target directory named by the handoff — the narrowest directory tree containing all authorized writes, including the report path (the common ancestor when work spans sibling directories) — before invoking the wrapper, or create the pane/workspace there with `--cwd /absolute/path/to/target-dir`. Starting elsewhere leaves an editable worker unable to write to the handoff’s target paths.

Use the wrappers; do not invoke `pi-profile` directly.

Editable worker:

```sh
subagent.sh --mode editable -- \
  @/tmp/admin-visual-parity/visual-audit-handoff.md \
  'Execute the handoff exactly; use CMUX-only completion.'
```

Read-only worker with classified read-only Bash:

```sh
subagent.sh --mode readonly -- \
  @/tmp/admin-visual-parity/visual-audit-handoff.md \
  'Execute the handoff exactly; use CMUX-only completion.'
```

`subagent.sh` requires exactly one `--mode readonly|editable` before `--` and uses `pi-profile partner -ne` with `thinking:minimal`. Editable mode retains default Pi tools. Read-only mode loads `pi-focus-guard`, starts `--dm-read`, and permits `read,bash,grep,find,ls`; the guard blocks writes and non-read-only Bash. In either mode, a Herdr pane additionally loads the installed `herdr-agent-state.ts` reporter explicitly; it remains inactive outside Herdr. The wrapper rejects caller overrides of print mode, extensions, model/provider/thinking, tools, and `--dm-*`. Neither mode uses `-p`.

## Select Work Deliberately

Delegate bounded, independently checkable outcomes: evidence collection, codebase inventories, substantive or localized implementation, focused test work, and independent verification. A worker may own a coherent vertical slice spanning multiple files when its contract is fixed.

Keep architectural choices, ambiguous requirements, cross-cutting integration, final decisions, and final acceptance in the supervisor role. Do not create workers merely to appear parallel, and do not split work with shared mutable scope unless the boundaries are explicit.

### Worker continuity — REQUIRED

Reuse a worker only for a direct follow-up within its existing goal, scope, and evidence context. For unrelated work, start a new worker with a new handoff brief; do not repurpose an existing worker merely because its pane is open. This keeps the worker context focused. Routine completion reporting, clarification, and supervisor-requested revision of the same work are direct follow-ups.

### Delegation abstraction — REQUIRED

Delegate outcomes, not typing instructions. Every handoff MUST state the outcome, fixed contracts/non-goals, authoritative sources, allowed scope, required evidence, and stop conditions. The worker owns its internal implementation plan and test iterations within that boundary; do not prescribe edit-by-edit mechanics unless the operation is mechanical or needed to prevent a conflict. Use a read-only audit first only for a genuinely unresolved evidence gate; otherwise delegate the substantive implementation and review it independently afterward.

## Delegate, Control, Escalate

Use **[sub-agent-handoff](../sub-agent-handoff/SKILL.md)** for every worker brief and report; it owns the handoff brief and work-report templates. This skill owns worker launch, live CMUX control, and acceptance. Give the worker its goal, acceptance criteria, allowed paths/actions, relevant evidence, stop rule, and expected report. Ask it to stop and report uncertainty rather than inventing a solution.

Use **`cmux-usage`** as the visible control plane: create non-disruptive worker panes, observe each worker independently, and steer it through its pane. CMUX is the default for active work; do not duplicate its operational instructions here.

Use `pi-intercom` only as a fallback escalation or asynchronous handoff channel—not instead of observing and steering an active worker pane.

Treat CMUX as the primary live-control and observation channel, and `pi-intercom` as the asynchronous reporting and escalation channel.

### Worker completion protocol — REQUIRED

The supervisor or user selects **one** completion/control channel in the work brief. Do not assume Intercom reaches sessions in different profile roots, and do not duplicate the same report across channels.

- **CMUX-only:** State the supervisor's exact CMUX `surface:` reference or UUID. The worker writes the full report to an approved absolute file path, then submits the notification with `cmux_submit_to_surface.sh <surface> '<one-line-message>'`. The script handles typing, Enter, wait, and target read-back in one call — inspect its stdout; do not call `cmux read-screen` separately. Embedded newlines in `cmux send` become separate Pi `Steering:` messages; never send multi-line reports, tables, or evidence rows to a Pi surface. The supervisor reads the file and returns at most one consolidated acceptance/revision line through the named CMUX route.
- **Intercom:** Use only when selected in the brief and after one end-to-end delivery test succeeds. Name the supervisor target and require one `READY` or `BLOCKED` notification that points to the full report file; do not use Intercom for repeated progress chatter.
- **No working route:** The worker stops after its local evidence/report file is complete and makes one best-effort notification through the selected route. It does not guess alternate panes, panels, sessions, or channels.

### No silent stops — REQUIRED

Every worker brief MUST state that the worker continues independently through its bounded task loop and MUST NOT stop at a task boundary, status update, test milestone, or uncertainty without reporting through the selected completion/control channel.

A worker may pause only after (1) verified completion, (2) a concrete blocker that requires a supervisor/user decision, or (3) a checkpoint explicitly requested in the brief. **Before any pause**, it MUST write or update its approved full report with current state, evidence, and the exact next decision/slice, then send the selected one-line notification. A silent or stale terminal is not a valid status.

The supervisor MUST treat a worker notification—or a user report that the worker stopped—as an event to inspect the exact CMUX surface and report artifact first. It MUST NOT infer worker state from an earlier screen read or send corrective steering before that direct inspection.

Use CMUX to observe an active worker pane and inspect artifacts before accepting or correcting work. When reports are stale or channels disagree, state the superseding gate decision with its evidence and avoid conflicting instructions.

## Protect Evidence Integrity

Require workers to name the authoritative evidence source and matching rule before they claim a result. Prefer structured, exact identity checks over text search. Do not accept generated logs, echoed prompts, nested tool output, or self-referential artifacts as source evidence.

## Evidence and Analysis Work Needs Two Gates

Do not delegate deterministic evidence reconstruction and causal interpretation as one undifferentiated task. They have different failure modes and acceptance criteria.

```text
Gate 1 — reconstruct
  exact source events, provenance, context bounds, deterministic tests
        ↓ supervisor verifies
Gate 2 — interpret
  bounded evidence packets, labels, outcomes, uncertainty, manual review
        ↓ supervisor accepts or rejects
```

For Gate 1, require an explicit source-matching rule. Match parsed structured records by exact identity and corroborating metadata where available (for example: ID, role, timestamp, and content fingerprint). Text search, file existence, and identifiers echoed inside logs or tool output are not source resolution.

For Gate 2, require each material interpretation to point to a small evidence packet: the active goal/constraint, the preceding relevant agent action, the user intervention, and the subsequent relevant action or boundary. A model may summarize this packet; it must not silently replace missing evidence with a plausible narrative.

### Treat Uncertainty as a Result

A coverage target is not permission to make the dataset look complete. `unclear`, unsupported, and missing-coverage cells are valid findings when the evidence does not establish cause, outcome, recurrence, approval, or user move-on.

- Require an explicit missing-evidence or uncertainty rationale for an `unclear` conclusion.
- Never ban `unclear` merely to satisfy a validator or sample matrix.
- Never label a correction as resolved only because the next agent message acknowledged it or announced a plan.
- Require evidence that the correction was applied, plus any task-specific resolution condition (for example, a subsequent user turn moving on) before declaring success.
- Keep negative controls distinct from correction episodes; they cannot satisfy correction-outcome coverage merely because an agent completed a request.

### Make Validators Guardrails, Not Judges

Use deterministic validation for claims that are mechanically knowable: source identity, provenance shape, chronology, allowed enums, context caps, required references, and coverage declarations.

Do not encode epistemic conclusions as validator rules. A validator should reject invalid provenance or unsupported state names; it must not force an uncertain outcome into a resolved one. Keep the human/supervisor decision boundary explicit for causal labels, recurrence, and whether evidence proves resolution.

When a workflow claims adaptive inspection, verify that the output records show the expanded inspected range and the stopping reason or boundary. Implementing an adaptive helper without applying it to the reviewed artifacts is not completion.

Keep structured records and human-readable review summaries synchronized. If a matrix says a cell is covered, independently confirm the corresponding structured record uses the same valid label and cites the required evidence.

## Acceptance Is Yours

Do not accept a worker's completion claim, validator, or passing test suite as evidence by itself. Inspect whether its checks implement the task specification, including permitted uncertainty, valid states or enums, and required negative cases. Reject validation that improves a score by discarding, relabeling, or coercing unsupported evidence.

Convert material worker claims into independently checkable assertions. Verify the property actually claimed—not a nearby proxy: source identity rather than file existence, causal order rather than event presence, and real bounded or adaptive behavior rather than documentation describing it. Inspect the report and changes, resolve conflicts, and independently run the relevant checks. Use `cg-task.sh` when an applicable task is available, alongside focused tests or runtime verification. Only the supervisor may declare the work complete.

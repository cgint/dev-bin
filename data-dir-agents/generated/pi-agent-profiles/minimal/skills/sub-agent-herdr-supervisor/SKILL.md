---
name: sub-agent-herdr-supervisor
description: Supervise bounded delegated work through Herdr while retaining responsibility for strategy, integration, evidence, acceptance, and owned-pane cleanup.
---

# Herdr Worker Supervision

## Use this for

Use Herdr as the default control plane for bounded Pi workers: launch, observe, read, wait, and close through Herdr. The supervisor owns scope, decisions, integration, verification, acceptance, and **cleanup of every pane it creates**. A worker owns only its bounded assignment.

Use CMUX only for outer desktop layout and separately CMUX-managed workers. Never steer the same worker through both CMUX and Herdr.

**Prerequisite:** install Herdr's Pi lifecycle integration in the worker profile before relying on lifecycle reports. Workers use `PI_WORKER_PROFILE` when set, otherwise `minimal`; the selected profile must contain `agent/extensions/herdr-agent-state.ts`. For the default, run `PI_CODING_AGENT_DIR="$HOME/.pi/profiles/minimal/agent" herdr integration install pi`; use the selected profile's agent directory when overriding `PI_WORKER_PROFILE`. Herdr manages and overwrites this extension—do not copy it into this skill. Herdr can report `working`, `idle`, `blocked`, and `done`; `screen_detection_skipped: true` is expected for direct Pi reporting. Never infer completion from a terminal spinner or visual terminal appearance.

## Delegation threshold

Use a subagent only when independent evidence, isolation, parallelism, or bounded execution provides more value than the launch, inspection, and cleanup overhead. Do trivial reads, obvious one-line edits, and immediate local checks directly. Do not delegate merely because a task can be split.

Delegation is also a **context boundary**: use it when source adaptation, lockfile churn, raw test/precommit output, or repeated mechanical checks would otherwise crowd out the lead's architectural judgement. The worker owns that operational detail; the lead retains scope, acceptance, and decisions.

## Handoff forms and context budget

**Current capability — artifact handoff only:** the launcher currently requires both `--handoff` and `--report`. Use the full `sub-agent-handoff` brief and the required artifact/report workflow below.

**Planned capability — compact inline brief (not available yet):** after the launcher supports it, use a direct, single-line brief only for a small, bounded, low-ambiguity assignment. It must still name the exact cwd, allowed and forbidden paths, goal, required checks, stop rule, and compact terminal `WORK REPORT`. Use the artifact handoff instead for multiline or quoted instructions, code snippets, reusable context, ambiguous/risky/cross-cutting work, or anything asynchronous.

In either form, keep raw command output with the worker. The initial worker report should contain only `HEADLINE`, `CONTRADICTS` (or `NONE`), load-bearing `NOT FOUND` (or `NONE`), `UNDETERMINED` (or `NONE`), changed paths, and pass/fail checks. The lead expands terminal output only for a failure, contradiction, scope concern, or diff anomaly.

## Task identity chain (default)

Before the first delegation for a task, choose distinct random given names and record one immutable chain in the `sub-agent-handoff` brief, for example `Horst (lead) → Judith (controller) → Benjamin (worker)`. The names are task-local labels; select them pen-and-paper, not through a new extension or control plane.

Copy the full chain into every nested handoff and state the current sender, recipient, return path, and lead escalation path. Peer prompts and reports begin `<Sender> → <Recipient>`; never use a generic agent prefix. A controller sends routine completion through its bounded report and escalates directly to the lead only for a decision, blocker, contradiction, or scope change.

The lead is the root task owner: it knows every task pane by person name, role, pane ID, lifecycle state, and operating owner, and may close any registered task pane during recovery. A controller maintains this live child-pane registry and records every worker launch and closure. The controller normally closes only worker panes it created, and only after terminal evidence, artifacts/diff, and required checks show no follow-up remains. The lead closes the controller only after inspecting and accepting its report. These are evidence-based closure decisions at each level, never automatic acceptance or a self-reported vote.

## Required launch model

Use the reusable launcher by default:

```sh
scripts/herdr-start-subagent.sh \
  --name <unique-worker-name> \
  --mode <readonly|editable> \
  --handoff /absolute/path/handoff.md \
  --report /absolute/path/report.md \
  --instruction 'Read the handoff exactly. <bounded instruction>. Stop.' \
  --direction <right|down> \
  --cwd /absolute/path/to/target-dir \
  --timeout-seconds 5
```

Set `--cwd` to the **target directory named by the handoff** — the narrowest absolute directory tree containing **all** of the worker’s authorized writes, including its report path (the common ancestor when work spans sibling directories). An editable worker’s write scope is the directory tree rooted at its launch cwd (enforced by `scripts/herdr-worker.sh`), so launching elsewhere prevents it from writing to the handoff’s target paths. Omitting `--cwd` is acceptable only when the supervisor is already running inside that target directory; otherwise the worker inherits the supervisor’s `$PWD`.

The launcher:

1. validates worker name, mode, absolute handoff/report paths, working directory, and timeout;
2. creates a sibling pane through `herdr pane split --no-focus`;
3. submits one atomically quoted wrapper command through `herdr pane run`;
4. starts `scripts/herdr-worker.sh --mode <readonly|editable> --`;
5. polls Herdr for worker detection, renames the detected agent, and prints structured JSON with `pane_id`, lifecycle snapshot, and `state_change_seq`.

Use direct `herdr pane split` / `herdr agent start` only when the launcher is unavailable or has a verified defect; record why and preserve all equivalent safeguards.

### Agent interaction commands

After launch — or when the user identifies an existing customer/peer agent — use task-level commands instead of reconstructing Herdr's low-level sequence. An `<agent-target>` is either a named worker or a Herdr pane ID such as `w1Z:pA`; Herdr resolves both through `agent get`, `agent read`, and `agent prompt`.

| Need | Command | Meaning |
| --- | --- | --- |
| Inspect now | `herdr agent get <agent-target>` | Current lifecycle state only; no waiting and no input. |
| Await in-flight work | `scripts/herdr_await_agent.sh <agent-target>` | Wait, then return lifecycle evidence and a bounded terminal snapshot in one JSON document. |
| Send a bounded prompt | `scripts/herdr_prompt_agent.sh <agent-target> '<Sender> → <Recipient>: <message>'` | Preflight; if idle, send through lifecycle-aware `agent prompt --wait`; then return lifecycle evidence and a bounded terminal snapshot. |

`scripts/herdr_prompt_agent.sh` refuses a `working` or `blocked` target and returns `prompt.sent: false` with `agent_working` or `agent_blocked`. Await a working target before deciding whether a new prompt is still needed; inspect a blocked target before clarifying or escalating. Its message must begin with the exact `<Sender> → <Recipient>` edge declared in the task handoff, so the receiving agent can distinguish a named peer request from user input.

A user-supplied customer/peer pane is **not owned by the supervisor**: do not rename, release, or close it. Use its pane ID with the lifecycle helper; do not use `herdr pane send-text`, `pane send-keys`, or `pane wait-output` for agent turns, because they are terminal-level rather than lifecycle-aware.

All launcher and lifecycle-helper scripts live in this skill's `scripts/` directory. The generator bundles the shared worker runtime beside them, so an installed skill has no `~/.local/bin` script dependency.

### Mode selection

| Worker purpose | Mode | Evidence channel | Write rule |
| --- | --- | --- | --- |
| Source scouting, contract tracing, independent review | `readonly` | Herdr terminal `WORK REPORT` | `scripts/herdr-worker.sh --mode readonly --` blocks local writes. Do **not** expect or require a report artifact. |
| Browser walkthrough, screenshot/report creation, bounded implementation | `editable` | Herdr terminal plus authorized artifact/diff | `scripts/herdr-worker.sh --mode editable --` permits writes; handoff must name the exact allowed paths and checks. |

`--report` is currently required by the launcher for both modes. Its parent directory must already exist and be writable for **every** launch; the launcher validates this before it creates a worker pane.

- For a read-only worker it is metadata only: no file may be created there. The handoff must explicitly say **terminal-only report; do not write artifacts**.
- For an editable worker, the handoff must explicitly authorize the report path and no broader write surface.

When the supervisor may write only in its own repository and the target report directory is absent, keep the handoff in the supervisor repository and use a temporary report directly under an existing target directory. Inspect that report before acceptance, then have the editable worker remove it. Do not have the supervisor create target directories merely to satisfy launch validation.

### Focus boundary

The launcher requests `--no-focus` when creating a sibling pane. Treat that as a creation request, **not proof of final focus state**: a worker was observed as `focused: true` after a non-focused launch request. If focus matters, inspect `herdr pane list` / `herdr agent get` after launch and act only on observed state. Do not claim a cause until Herdr trace evidence establishes one.

## Normal workflow

### 1. Prepare the handoff

Use `sub-agent-handoff`. State:

- one immutable task identity chain, including this handoff edge, return path, and lead escalation path;
- one coherent goal and measurable success criteria;
- allowed paths/actions, non-goals, and stop rules;
- authoritative starting evidence and current working-tree constraints;
- exact evidence channel: terminal-only for read-only work, or approved absolute artifact path for editable work;
- timebox and expected `WORK REPORT` format.

Do not delegate ambiguous requirements, architecture, cross-cutting decisions, or final acceptance.

### 2. Launch and record ownership

Launch through `scripts/herdr-start-subagent.sh`. Record its JSON output in the supervisor’s task context:

- worker person name and role from the task identity chain;
- owned `pane_id`;
- mode;
- handoff and report path;
- initial `agent_status` and `state_change_seq`;
- operating owner and the lead-visible child-pane registry entry.

A returned `idle` immediately after launch is a lifecycle snapshot, **not completion evidence**. Do not send extra prompts merely because the initial snapshot is `idle`.

### 3. Await without steering

Give the worker one complete instruction at launch. Do not steer a working worker clause-by-clause.

```sh
scripts/herdr_await_agent.sh <worker-name> --timeout-ms 1800000 --lines 100
```

The returned JSON preserves the raw wait result, current `agent.status`, and bounded terminal evidence even when the wait times out. Normal waits use Herdr's default terminal set (`idle`, `done`, `blocked`). A terminal lifecycle state means **inspect now**, never **accept automatically**.

### 4. Inspect and decide

Inspect the returned JSON: treat `agent.status` as the current machine-readable state and `terminal.text` as supplementary evidence. If raw, broader, or alternate-source output is necessary, use `herdr agent get` and `herdr agent read` directly.

Then apply the mode-specific acceptance check:

- **Read-only:** require the requested terminal `WORK REPORT`, exact source/test/runtime evidence, stated uncertainties, and no unauthorized files. Do not reject it for lacking a physical report artifact.
- **Editable:** inspect the required report, the actual diff/status, and proportionate checks. Verify that changes stay within the authorized path scope.

Do not accept a worker's "checks passed" self-report as evidence. Independently inspect the changed-path set and diff/status, then run a proportionate lead-side check. Read raw worker logs only when a compact report, result, or diff makes that necessary.

`idle` or `done` can be accepted, redirected once with a bounded follow-up, or treated as incomplete after inspection. `blocked` requires reading the actual question/evidence before clarifying, redirecting, or escalating. Only the supervisor declares completion.

### 5. Mandatory cleanup

The supervisor is the operating owner of every pane it creates, while the lead remains the root task owner of every registered pane. Capture the required terminal report with `herdr agent read` **before** closing a worker pane; terminal retention after closure is not assumed. Close a worker only after its terminal output, report/artifact, diff, and required checks have been inspected and the controller has concluded no direct follow-up remains. Record the closure in the live child-pane registry immediately.

The lead then inspects and accepts the controller report before closing the controller pane. If a controller is unavailable, the lead may use the named registry to capture a worker’s evidence and close that worker directly. Do not close either level merely because it reports success.

After the required evidence-based closure decision, close the operating owner’s pane immediately:

```sh
herdr pane close <owned-pane-id>
herdr pane list --workspace <workspace-id>
```

Retain a failed or blocked worker pane only until diagnostic evidence has been captured; then close it. Never close the supervisor's main pane or any pane not created by the supervisor. Verify the resulting pane list instead of assuming close succeeded.

## Recovery

Use recovery only after a wait times out/is cancelled, delivery is unclear, or a worker does not produce the expected output.

### Follow-up invariant

For a normal follow-up, use the lifecycle-aware helper rather than `pane send-text` or raw `agent prompt`:

```sh
scripts/herdr_prompt_agent.sh <agent-target> '<Sender> → <Recipient>: <one bounded request>' \
  --timeout-ms 1800000 --lines 100
```

The helper preflights state. If the worker is `working` or `blocked`, it sends nothing and returns `prompt.sent: false` with a reason; await the in-flight worker, or inspect the blocked worker, before deciding what is justified. A preflight reduces but cannot eliminate a race with later state changes, so inspect the returned prompt capture and current state rather than claiming causal completion. Otherwise it uses `agent prompt --wait` without `--until` filters and returns its capture, the latest state, and bounded terminal evidence. Wait for Herdr's normal state set rather than selected lifecycle states.

After an abort, timeout, `agent_prompt_stalled`, or any other unexpected
prompt/wait result, do **not** resend first. The result does not establish that
the request was not delivered. Use `scripts/herdr_await_agent.sh <agent-target>` to
capture its current state and bounded terminal evidence before deciding whether
a new follow-up is justified. Use direct `herdr agent get` / `read` only when
that bounded evidence is insufficient.

Compare the current `state_change_seq` with the launch snapshot:

1. an advanced sequence proves Herdr observed a lifecycle transition, not that the assignment was understood or completed;
2. fresh output containing the handoff-specific work establishes delivery evidence;
3. the terminal report or authorized artifact establishes the claimed result;
4. supervisor inspection plus diff/checks establishes acceptance.

If the worker is still active after a clear, complete handoff, wait again. If it is terminal but incomplete, send one explicit bounded follow-up or close it and start a new worker with a corrected handoff. Do not conceal ambiguity with repeated generic prompts.

## Before declaring completion

- [ ] The handoff states the immutable identity chain, this edge, return/escalation paths, scope, evidence, stop rules, timebox, and the correct report channel.
- [ ] The launcher JSON and live registry record every worker’s person name, role, pane ID, operating owner, mode, and lifecycle snapshot.
- [ ] Herdr terminal state was observed; terminal appearance was not substituted for lifecycle evidence.
- [ ] Fresh output was captured through `scripts/herdr_await_agent.sh` / `scripts/herdr_prompt_agent.sh`, or directly through Herdr when broader evidence was necessary.
- [ ] Read-only work has terminal evidence and no unauthorized files; editable work has an inspected report/diff and checks.
- [ ] The controller accepted each worker’s evidence before closing its owned pane; each closure was recorded and `herdr pane list` verified cleanup.
- [ ] The lead accepted the controller report before closing the controller pane.
- [ ] The accepted result, limitation, next action, and any operational learning were recorded durably when relevant.

## Reference

Use the installed Herdr version's CLI help and `agent-automation` documentation when behavior is uncertain. Record verified project-specific experiments in `herdr-knowhow`; do not generalize a one-off observation into a tool guarantee.

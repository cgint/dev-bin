---
name: sub-agent-herdr-supervisor
description: Supervise bounded delegated work through Herdr while retaining responsibility for strategy, integration, evidence, acceptance, and owned-pane cleanup.
---

# Herdr Worker Supervision

## Use this for

Use Herdr as the default control plane for bounded Pi workers: launch, observe, read, wait, and close through Herdr. The supervisor owns scope, decisions, integration, verification, acceptance, and **cleanup of every pane it creates**. A worker owns only its bounded assignment.

Use CMUX only for outer desktop layout and separately CMUX-managed workers. Never steer the same worker through both CMUX and Herdr.

**Prerequisite:** install Herdr's Pi lifecycle integration with `herdr integration install pi` before relying on lifecycle reports. Herdr can report `working`, `idle`, `blocked`, and `done`; `screen_detection_skipped: true` is expected for direct Pi reporting. Never infer completion from a terminal spinner or visual terminal appearance.

## Delegation threshold

Use a subagent only when independent evidence, isolation, parallelism, or bounded execution provides more value than the launch, inspection, and cleanup overhead. Do trivial reads, obvious one-line edits, and immediate local checks directly. Do not delegate merely because a task can be split.

## Required launch model

Use the reusable launcher by default:

```sh
~/.local/bin/herdr_start_subagent.sh \
  --name <unique-worker-name> \
  --mode <readonly|editable> \
  --handoff /absolute/path/handoff.md \
  --report /absolute/path/report.md \
  --instruction 'Read the handoff exactly. <bounded instruction>. Stop.' \
  --direction <right|down> \
  --cwd /absolute/path/to/target-dir \
  --timeout-seconds 5
```

Set `--cwd` to the **target directory named by the handoff** — the narrowest absolute directory tree containing **all** of the worker’s authorized writes, including its report path (the common ancestor when work spans sibling directories). An editable worker’s write scope is the directory tree rooted at its launch cwd (enforced by `subagent.sh`), so launching elsewhere prevents it from writing to the handoff’s target paths. Omitting `--cwd` is acceptable only when the supervisor is already running inside that target directory; otherwise the worker inherits the supervisor’s `$PWD`.

The launcher:

1. validates worker name, mode, absolute handoff/report paths, working directory, and timeout;
2. creates a sibling pane through `herdr pane split --no-focus`;
3. submits one atomically quoted wrapper command through `herdr pane run`;
4. starts `subagent.sh --mode <readonly|editable> --`;
5. polls Herdr for worker detection, renames the detected agent, and prints structured JSON with `pane_id`, lifecycle snapshot, and `state_change_seq`.

Use direct `herdr pane split` / `herdr agent start` only when the launcher is unavailable or has a verified defect; record why and preserve all equivalent safeguards.

### Mode selection

| Worker purpose | Mode | Evidence channel | Write rule |
| --- | --- | --- | --- |
| Source scouting, contract tracing, independent review | `readonly` | Herdr terminal `WORK REPORT` | `subagent.sh --mode readonly --` blocks local writes. Do **not** expect or require a report artifact. |
| Browser walkthrough, screenshot/report creation, bounded implementation | `editable` | Herdr terminal plus authorized artifact/diff | `subagent.sh --mode editable --` permits writes; handoff must name the exact allowed paths and checks. |

`--report` is currently required by the launcher for both modes. For a read-only worker it is metadata only: its parent must exist and be writable, but no file may be created there. The handoff must explicitly say **terminal-only report; do not write artifacts**. For an editable worker, the handoff must explicitly authorize the report path and no broader write surface.

### Focus boundary

The launcher requests `--no-focus` when creating a sibling pane. Treat that as a creation request, **not proof of final focus state**: a worker was observed as `focused: true` after a non-focused launch request. If focus matters, inspect `herdr pane list` / `herdr agent get` after launch and act only on observed state. Do not claim a cause until Herdr trace evidence establishes one.

## Normal workflow

### 1. Prepare the handoff

Use `sub-agent-handoff`. State:

- one coherent goal and measurable success criteria;
- allowed paths/actions, non-goals, and stop rules;
- authoritative starting evidence and current working-tree constraints;
- exact evidence channel: terminal-only for read-only work, or approved absolute artifact path for editable work;
- timebox and expected `WORK REPORT` format.

Do not delegate ambiguous requirements, architecture, cross-cutting decisions, or final acceptance.

### 2. Launch and record ownership

Launch through `herdr_start_subagent.sh`. Record its JSON output in the supervisor’s task context:

- worker name;
- owned `pane_id`;
- mode;
- handoff and report path;
- initial `agent_status` and `state_change_seq`.

A returned `idle` immediately after launch is a lifecycle snapshot, **not completion evidence**. Do not send extra prompts merely because the initial snapshot is `idle`.

### 3. Wait without steering

Give the worker one complete instruction at launch. Do not steer a working worker clause-by-clause.

```sh
herdr agent wait <worker-name> --timeout 1800000
```

Use the installed CLI help if a timeout is rejected; respect its maximum. Normal waits use Herdr's default terminal set (`idle`, `done`, `blocked`). A terminal lifecycle state means **inspect now**, never **accept automatically**.

### 4. Inspect and decide

Read fresh output first:

```sh
herdr agent get <worker-name>
herdr agent read <worker-name> --source recent-unwrapped --lines 160
```

Then apply the mode-specific acceptance check:

- **Read-only:** require the requested terminal `WORK REPORT`, exact source/test/runtime evidence, stated uncertainties, and no unauthorized files. Do not reject it for lacking a physical report artifact.
- **Editable:** inspect the required report, the actual diff/status, and proportionate checks. Verify that changes stay within the authorized path scope.

`idle` or `done` can be accepted, redirected once with a bounded follow-up, or treated as incomplete after inspection. `blocked` requires reading the actual question/evidence before clarifying, redirecting, or escalating. Only the supervisor declares completion.

### 5. Mandatory cleanup

The supervisor owns every pane it creates. After terminal output, report/artifact, diff, and required checks have been inspected and no direct follow-up remains, close the owned pane immediately:

```sh
herdr pane close <owned-pane-id>
herdr pane list --workspace <workspace-id>
```

Retain a failed or blocked worker pane only until diagnostic evidence has been captured; then close it. Never close the supervisor's main pane or any pane not created by the supervisor. Verify the resulting pane list instead of assuming close succeeded.

## Recovery

Use recovery only after a wait times out/is cancelled, delivery is unclear, or a worker does not produce the expected output.

Do **not** resend the prompt first. Recover state and output:

```sh
herdr agent get <worker-name>
herdr agent read <worker-name> --source recent-unwrapped --lines 160
```

Compare the current `state_change_seq` with the launch snapshot:

1. an advanced sequence proves Herdr observed a lifecycle transition, not that the assignment was understood or completed;
2. fresh output containing the handoff-specific work establishes delivery evidence;
3. the terminal report or authorized artifact establishes the claimed result;
4. supervisor inspection plus diff/checks establishes acceptance.

If the worker is still active after a clear, complete handoff, wait again. If it is terminal but incomplete, send one explicit bounded follow-up or close it and start a new worker with a corrected handoff. Do not conceal ambiguity with repeated generic prompts.

## Before declaring completion

- [ ] The handoff states scope, evidence, stop rules, timebox, and the correct report channel.
- [ ] The launcher JSON records the worker name, owned pane ID, mode, and lifecycle snapshot.
- [ ] Herdr terminal state was observed; terminal appearance was not substituted for lifecycle evidence.
- [ ] Fresh output was read.
- [ ] Read-only work has terminal evidence and no unauthorized files; editable work has an inspected report/diff and checks.
- [ ] The worker's owned pane was closed and `herdr pane list` verified cleanup.
- [ ] The accepted result, limitation, next action, and any operational learning were recorded durably when relevant.

## Reference

Use the installed Herdr version's CLI help and `agent-automation` documentation when behavior is uncertain. Record verified project-specific experiments in `herdr-knowhow`; do not generalize a one-off observation into a tool guarantee.

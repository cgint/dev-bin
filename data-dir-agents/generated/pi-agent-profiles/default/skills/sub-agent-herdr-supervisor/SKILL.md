---
name: sub-agent-herdr-supervisor
description: Supervise bounded delegated work through Herdr while retaining responsibility for strategy, integration, evidence, and acceptance.
---

# Herdr Worker Supervision

## Use this for

Use Herdr to run a bounded Pi worker in a Herdr-managed pane. Use cmux for the outer desktop layout and existing hardened read-only workers.

The supervisor owns scope, decisions, integration, verification, and final acceptance. A worker owns only its bounded assignment.

**Prerequisite:** install Herdr's Pi lifecycle integration with `herdr integration install pi` before relying on direct lifecycle reports. With that integration active, Pi reports `working`, `idle`, and `blocked` directly to Herdr. Herdr can also expose `done` as a terminal agent status. `screen_detection_skipped: true` is expected for direct Pi reporting; do not infer completion from a spinner or terminal appearance.

## Normal workflow

### 1. Prepare the handoff

Use `sub-agent-handoff`. State:

- goal and success criteria;
- allowed paths, non-goals, and stop conditions;
- authoritative starting evidence;
- the approved absolute path for the complete report.

Delegate a coherent, independently checkable outcome. Keep ambiguous requirements, architecture, cross-cutting decisions, and final acceptance with the supervisor.

### 2. Create and start a worker

```sh
herdr pane split --current --direction right --no-focus
herdr pane list
herdr agent start <worker-name> --kind pi --pane <worker-pane-id>
herdr agent list
```

The target pane must be at an interactive shell prompt. Use the target from `herdr agent list`; do not guess from a pane title or ID.

For enforced read-only work, retain the CMUX read-only wrapper until an equivalent restricted Herdr launch is verified. For write work, require user approval and state allowed paths and checks in the handoff.

### 3. Dispatch and wait

Before dispatch, record `agent_status` and `state_change_seq` from `herdr agent get <worker-target>`. If the worker is already `working`, do not use `agent prompt --wait` as evidence that a new bounded assignment completed: Herdr does not track turns, so completion of the active turn can satisfy that wait. Let the current assignment settle and inspect it before dispatching the next one.

Send one focused instruction that points to the handoff and report:

```sh
herdr agent prompt <worker-target> \
  'Read /absolute/path/handoff.md. Complete the task and write the report to /absolute/path/report.md.' \
  --wait --timeout 1800000
```

For normal completion waits, **omit `--until`**. Herdr then waits for its complete default terminal set:

```text
idle, done, blocked
```

Do not use repeated messages as a substitute for a coherent handoff. Do not steer a working worker clause-by-clause.

### 4. Inspect and decide

A terminal state means **inspect now**. It does not mean **accept**.

```sh
herdr agent read <worker-target> --source recent-unwrapped --lines 160
```

Then inspect the report artifact. For write work, inspect the actual diff and run proportionate checks.

- `idle` or `done`: accept, request one bounded revision, or continue with a direct follow-up.
- `blocked`: inspect the question, then clarify, approve, redirect, or escalate.
- completion: only the supervisor declares it after checking the evidence.

## Recovery

Use this only when a wait timed out or was cancelled, prompt delivery is unclear, or a plain prompt was sent to a worker that was already `idle`.

Do **not** resend the prompt first. Recover state and output:

```sh
herdr agent get <worker-target>
herdr agent read <worker-target> --source recent-unwrapped --lines 160
```

If delivery remains unclear, compare the current `state_change_seq` with the value recorded before dispatch:

1. record `agent_status` and `state_change_seq` before the plain prompt;
2. send the prompt;
3. confirm that `state_change_seq` advanced;
4. if the newer state is `working`, wait normally:

   ```sh
   herdr agent wait <worker-target> --timeout 1800000
   ```

5. if it is already terminal, read fresh output and inspect the report.

An advanced sequence establishes only that Herdr observed a lifecycle transition; it does not prove that this prompt was submitted or processed. Fresh output, plus a report or artifact that contains a request-unique marker or was written after dispatch, establishes task delivery and completion. Diff and checks establish whether the result is acceptable.

## Control boundary

Use Herdr for Herdr-managed worker panes: create, start, prompt, read, and wait. Use cmux for outer layout, user-visible tiles, notifications, browser surfaces, and hardened CMUX-only workers.

Do not control the same Herdr-managed worker through both cmux steering and Herdr prompts.

## Before declaring completion

- [ ] The handoff defined scope, evidence, stop rules, and a report path.
- [ ] `herdr agent list` identified the intended worker.
- [ ] A terminal state was observed through Herdr, not inferred from screen appearance.
- [ ] Fresh output and the report artifact were read.
- [ ] Changes and checks were independently verified where applicable.
- [ ] The final result, limitation, and next action were recorded when durable.

## Reference

Use the installed Herdr version's `agent-automation` documentation and CLI help when behavior is uncertain. The project-specific experiment record belongs in the `herdr-knowhow` repository; it is not a dependency of this shared skill.

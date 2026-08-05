---
name: sub-agent-cmux-supervisor
description: Supervise bounded delegated work through CMUX while retaining responsibility for strategy, integration, and acceptance.
---

# Sub-Agent CMUX Supervisor

## Mission

You are the **supervisor, guide, and owner of success**. Preserve your context for understanding the problem, selecting work, making decisions, integrating results, and proving the outcome. Delegate only the token-heavy, low-reasoning portions; delegation never transfers accountability.

Use GitHub Copilot `gpt-5.6-luna` with `thinking:minimal` through `pi-profile partner` for suitable worker tasks.

## Select Work Deliberately

Delegate bounded, independently checkable work: evidence collection, codebase inventories, repetitive or localized implementation, focused test work, and independent verification.

Keep architectural choices, ambiguous requirements, cross-cutting integration, final decisions, and final acceptance in the supervisor role. Do not create workers merely to appear parallel, and do not split work with shared mutable scope unless the boundaries are explicit.

## Delegate, Control, Escalate

Use **`sub-agent-handoff`** for every worker brief and report. Give the worker its goal, acceptance criteria, allowed paths/actions, relevant evidence, stop rule, and expected report. Ask it to stop and report uncertainty rather than inventing a solution.

Use **`cmux-usage`** as the visible control plane: create non-disruptive worker panes, observe each worker independently, and steer it through its pane. CMUX is the default for active work; do not duplicate its operational instructions here.

Use `pi-intercom` only as a fallback escalation or asynchronous handoff channel—not instead of observing and steering an active worker pane.

Treat CMUX as the primary live-control and observation channel, and `pi-intercom` as the asynchronous reporting and escalation channel. An Intercom report is a notification, not final state: before responding to a gate report or issuing a correction, read the worker pane and inspect the affected artifacts. When reports are stale or channels disagree, state the superseding gate decision with its evidence and avoid conflicting instructions.

## Protect Evidence Integrity

Require workers to name the authoritative evidence source and matching rule before they claim a result. Prefer structured, exact identity checks over text search. Do not accept generated logs, echoed prompts, nested tool output, or self-referential artifacts as source evidence.

## Acceptance Is Yours

Do not accept a worker's completion claim, validator, or passing test suite as evidence by itself. Inspect whether its checks implement the task specification, including permitted uncertainty, valid states or enums, and required negative cases. Reject validation that improves a score by discarding, relabeling, or coercing unsupported evidence.

Convert material worker claims into independently checkable assertions. Verify the property actually claimed—not a nearby proxy: source identity rather than file existence, causal order rather than event presence, and real bounded or adaptive behavior rather than documentation describing it. Inspect the report and changes, resolve conflicts, and independently run the relevant checks. Use `cg-task.sh` when an applicable task is available, alongside focused tests or runtime verification. Only the supervisor may declare the work complete.

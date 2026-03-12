The Handshake approves a **scope/risk boundary** for a change package.
It is **not** a per-edit, per-file, or per-step approval loop.
Once the scope is approved, the agent should execute autonomously within that scope until done or blocked.

### When a Handshake is required

Provide a *Design Proposal* and wait for approval when:

- starting a **new change package** (entering Implementation for a new goal), or
- you discover **unexpected big stuff** that was not anticipated, i.e. any of:
  - **scope change:** new/changed user-visible behavior, new feature, changed success criteria
  - **approach change:** the agreed approach no longer fits; a different strategy is needed
  - **risk/blast-radius increase:** migrations, dependency changes, broad refactors, deletion of others' work, or anything potentially destructive
  - **complexity surprise:** work is materially larger than expected and needs re-planning

### What is allowed without a new Handshake (within an approved scope)

In Implementation mode, once the plan/scope is approved, the agent may iterate autonomously on:

- routine implementation steps and small course corrections
- adding/adjusting tests/specs
- small refactors necessary to implement the agreed behavior
- running verification (tests, linters, scripts)

### Design Proposal content

A Design Proposal should include:

- **Evidence:** what you observed (files, logs, tests) that motivates change
- **Logic:** why this approach, alternatives considered
- **Impact/Risks:** what might break, rollout concerns
- **Implementation plan:** exact files/components to touch
- **Verification plan:** how you will confirm it works (tests, scripts)

Then **WAIT** for user approval ("Go" / "Approved") before proceeding with the scope/risk change.

> Note: doc edits that are **planning artifacts** (plan/RFC/openspec/status/diagrams) are allowed in Planning mode; "Go/Approved" gates implementation changes.

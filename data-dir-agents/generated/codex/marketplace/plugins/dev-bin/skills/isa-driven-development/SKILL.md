---
name: isa-driven-development
description: Use ISA (Ideal State Artifact) driven development for bootstrapping, refining, planning, or verifying work in any project. One project-level ISA.md holds the clarified target; ISCs (Ideal State Criteria) are atomic, falsifiable criteria inside it. Use when the user asks for an ideal state, clarified requirements, an ISA, criteria with falsifiers, or honest verification of what "done" means.
---

# ISA-driven development

An ISA is one short document that states the ideal state of a thing, its constraints,
and atomic observable criteria. Each criterion (ISC) names the evidence that would
falsify it. The ISA is the **acceptance target and the evidence index**: it defines
what "done" means and points to the probe, test, or observation that shows each
criterion holds. The tests themselves remain executable artifacts; the ISA is not
them. Primary source: [The Entire Game for AI Is Articulation of Ideal State —
Daniel Miessler](https://danielmiessler.com/blog/ai-ideal-state-articulation) —
details and full provenance in `references/doctrine.md`.

## When to read the references (do not preload them all)

- **`references/bootstrap.md`** — before bootstrapping a new ISA, or whenever
  authority migration or requirement parity is on the table.
- **`references/verify.md`** — before choosing falsifiers, and before evaluating
  whether a criterion may close.
- **`references/doctrine.md`** — for criteria-design rules, hierarchy questions,
  or provenance (sourced vs. adapted).
- **`templates/isa.md`** — only when scaffolding a new ISA or feature plan.

## One ISA per project

- Default is a **single project-level `ISA.md`**: short ideal-state statement,
  constraints, atomic criteria, examples/falsifiers, open user decisions, and a
  verification mapping. Do not pre-split a medium project into child ISAs; a
  hierarchy exists for things genuinely too large for one legible file.
- `1_idea__<feature>.md` is optional rough first vision, not a clarified target.
- No separate `2_requirements__` by default — no competing requirement
  collections. `3_plan__<feature>.md` is a bounded plan referencing stable ISC
  IDs; it never redefines the target. Follow the project's existing file
  convention if it has one.

## The loop

1. **Articulate before building.** Write the ideal state, then criteria, each
   with a named falsifier, before implementation. A criterion without a nameable
   falsifier is a wish.
2. **Climb.** Implement against the ISCs. On a failure, distinguish: code bug,
   ambiguous target, or requirement that the approver must change. An agreed
   requirement is revised only by its approval owner — never silently edit the
   ISA to green a failing test. A proposed new target is recorded separately.
3. **Verify on evidence.** Closure is reported on three separate facts per
   criterion — coverage (partial/full), approval (proposed/agreed), and
   execution result (inspected / not run / pass / fail / manual). A green
   unrelated suite does not close anything.
4. **Loop back.** Clarified or changed requirements go back into the ISA through
   their approval owner. Never move goalposts silently in plans or tests.

## Non-negotiable rules

- **Atomic, hard-to-vary criteria.** Each ISC is one binary check. If a criterion
  can be deleted without anyone noticing, it was decoration. Universal criteria
  ("all valid contracts reach extraction") beat example criteria ("one document
  reached extraction") — examples pass while the system is broken.
- **Forbidden outcomes.** Every real build names the forbidden outcomes its
  constraints and risks actually imply (anti-criteria). The number is what the
  risks warrant — no invented quota, and a goal with no nameable failure mode is
  under-specified.
- **Checkboxes track evidence, not approval.** A criterion whose evidence closes
  is not thereby approved; human acceptance gates stay RESERVED and are never
  self-marked.
- **Read sources, not summaries.** Verify test names against real test bodies; a
  stale comment or a file's existence is not passing proof. A missing
  test-name mapping means *unmapped*, not *no test exists*.
- **Respect existing authority.** If OpenSpec or another source governs, the ISA
  summarizes it with source links and the source wins on conflict. Authority
  migration is an approval-owner decision requiring explicit approval and
  requirement-parity accounting — never silently replace, never discard detailed
  specs for a representative few ISCs.
- **Resolve routine engineering yourself; escalate what genuinely isn't yours.**
  Business scope, quality bar, privacy, retention, and acceptance policy are
  approval-owner decisions and cannot be invented. Scope, resource, security, or
  architecture-constraint decisions go up. Do not run a full interview before
  source discovery — ask the smallest true question when you are actually
  blocked.

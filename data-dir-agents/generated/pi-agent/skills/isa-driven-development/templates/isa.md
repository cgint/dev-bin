# Template: project ISA (`ISA.md`)

Copy this shape. Replace every `⟨...⟩` placeholder with real content or delete the line —
no section may carry invented verified rows, fake probes, invented approval, dates, or
metrics. A fact that does not exist yet stays explicitly open.

```markdown
# ⟨thing⟩ — ISA

## Ideal State
⟨One sentence: what done means for this thing.⟩
⟨2–5 sentences: the ideal state in full — what it is, who it serves, what it guarantees.⟩

## Out of Scope
- ⟨What is explicitly not part of this ideal state, and why.⟩

## Constraints
- ⟨Immovable constraint: architecture, privacy, retention, acceptance policy.⟩

## Forbidden outcomes (anti-criteria)
- [ ] Anti-1: ⟨a forbidden outcome this constraint/risk actually implies.⟩
  - Falsifier: ⟨the probe that would show it did happen.⟩
  - Approval: ⟨proposed | agreed⟩ — ⟨by whom / which source governs⟩
  - Coverage: ⟨full | partial — ⟨what is uncovered⟩ | none — ⟨no probe exists⟩ | not assessed⟩
  - Result: ⟨inspected | not run | pass | fail | manual⟩ — ⟨command, outcome, revision⟩ or ⟨open: reason⟩

## Not yet specified (fog)
- ⟨A genuinely open question, precisely stated, not yet probe-able.⟩

## Criteria
- [ ] ISC-1: ⟨atomic, observable, falsifiable statement.⟩
  - Falsifier: ⟨what evidence would prove this false.⟩
  - Approval: ⟨proposed | agreed⟩ — ⟨by whom / which source governs⟩
  - Coverage: ⟨full | partial — ⟨what is uncovered⟩ | none — ⟨no probe exists⟩ | not assessed⟩
  - Result: ⟨inspected | not run | pass | fail | manual⟩ — ⟨command, outcome, revision⟩ or ⟨open: reason⟩

## Open decisions
- ⟨D-1: ⟨owner⟩ — ⟨question only the owner can decide⟩⟩

## Decisions
- ⟨what was decided, by ⟨approval owner / source⟩, ⟨date or version anchor⟩, supersedes ⟨what⟩⟩
```

Each criterion is defined **once**, under the section that fits it; its checkbox records
**evidence closure only** — never approval. Approval is its own `proposed/agreed` line with
an owner. A criterion whose evidence is closed but whose acceptance is a human gate stays
flagged for that gate; agents never self-mark it. A verification mapping (table or companion
file) may reference stable IDs only — it carries no definitions and no checkboxes.

## Rules for filling it

- **Atomic criteria**: one ISC, one binary check. If a criterion contains "and" joining two
  verifiable things, split it.
- **Stable IDs**: `ISC-1`, `Anti-1` — never renumber, never duplicate; dropped criteria
  leave a tombstone pointing to the decision that killed them.
- **Falsifier is mandatory.** A criterion without a nameable probe that could prove it false
  is a wish; mark it as fog, not as a criterion.
- **Universal over example**: prefer "all ⟨domain, scoped⟩ ⟨observable property⟩ over
  ⟨window⟩" over "item X does so", and carry boundary examples (a known-good and a known-bad
  case) as evidence, not as the guarantee.
- **Coverage is honest about the unknown.** A criterion with no probe is `none`, one never
  examined is `not assessed`; neither collapses into `partial` and neither says anything
  about approval or execution.
- **Verification mapping**: each criterion links to its governing source and its existing
  probe (file · test name, verified substring) or an explicit `unmapped` / `gap — no probe
  found` note. A missing mapping is a finding, not a silent omission.
- **Canonical companion**: when details (per-ISC source links, worked examples,
  reconciliations) would bloat the ISA, keep the ISA short and put the evidence in one
  companion file it links. No redundant status or debt copies in both.

## Feature plan template (`3_plan__<feature>.md`)

```markdown
# Plan: ⟨feature⟩

References: ISA.md criteria ⟨ISC-1, Anti-1⟩ (stable IDs; the plan does not redefine the target).

## Design
⟨Bounded design decisions for this feature only.⟩

## Tasks
- [ ] ⟨task⟩ → covers ⟨ISC-n⟩
- [ ] ⟨task⟩ → covers ⟨Anti-n⟩
⟨Only when the project's agreement requires a human acceptance gate for this feature:
- [ ] ⟨human acceptance: RESERVED⟩ — gate for ⟨acceptance criterion⟩. If the gate is required, report an unmet required gate explicitly; do not claim acceptance until it is met. Never an automatic block on routine work.⟩

## Test and acceptance plan
- Baseline: run the RELEVANT existing checks for the touched surface at segment start;
  red→green around the change; the full or final gate is applied per the project's own
  rules — not before every edit.
- ⟨unit/property tests (state run bounds)⟩ — covers ⟨ISC-n⟩; red evidence: ⟨known-negative
  or mutation or real-defect case, or "not applicable: reason"⟩
- ⟨browser / domain-source check where user-facing accuracy requires it⟩ — covers ⟨ISC-n⟩
```

Requirements discovered during planning loop back into `ISA.md` through their approval
owner, not into this plan.

# Bootstrap and authority

## Before bootstrapping, inventory (source-reading, not summarizing)

Read the actual files, not summaries or comments:
1. **Purpose and users** — project overview, intent docs, README.
2. **Scope and non-goals** — declared boundaries, what is explicitly out.
3. **Hard constraints** — standing invariants (AGENTS.md or equivalent), architecture mandates.
4. **Existing authoritative requirements and approvals** — which source governs today and who
   approved it.
5. **Present implementation and evidence** — what actually runs; test bodies, not test names
   or stale moduledocs.
6. **Domain acceptance examples and negative cases** — one concrete input→output the user
   recognizes as correct, and what would count as wrong.
7. **Verification tools** — what can actually execute (test runner, browser, probes).
8. **Approval-owner decisions still open** — scope, quality, privacy, retention, acceptance
   policy. These belong to the approval owner (usually the user) and cannot be invented;
   name them as open decisions, not resolved criteria.

## Authority model

- **Existing authority keeps governing.** If OpenSpec (or another source) is the authority,
  the initial ISA serves as target and index: it summarizes the governing requirements with
  source links, and the governing source wins in any conflict. No parallel competing
  authority is silently introduced.
- **Desired end state is single authority** — but the migration is a user decision. It needs
  explicit user approval and **requirement-parity accounting**: every requirement in the old
  authority is either re-stated as an ISC, listed as omitted-by-reference with a link, or
  explicitly retired. A representative few ISCs do not substitute for a full inventory
  without the user choosing that trade.
- **In-flight work finishes under its agreement.** An in-flight implementation continues under
  the agreement it started with unless the user directs otherwise. Label in-flight semantics
  as in-flight, never as baseline.
- **Requirements changes loop back.** Clarifying or changing requirements updates the ISA
  *through the approval owner*. Plans and tests reference ISC IDs; they never redefine the
  target. Moving goalposts in a plan is a defect, and an agreed requirement is never edited
  to green a failing test.

## Feature artifacts

Follow the project's existing convention. A common shape:
- Optional `1_idea__<feature>.md` — rough first vision and exploration. Provisional, not a
  clarified target.
- No separate `2_requirements__` by default.
- `3_plan__<feature>.md` — bounded design, tasks, test and acceptance plan, referencing stable
  ISC IDs. The plan drives implementation and evidence; it is not the target.

Feature folders may follow `docs/feature-impl/YYYYMMDD-<feature>/` or whatever the project
already does. Do not impose a duplicate layout.

### Mode A — Planning / Ideation ("Talk")

**Goal:** align on intent, scope, success criteria, and approach.

**Typical activities**

- Ask clarifying questions.
- Inspect code/docs (read-only).
- Gather evidence (logs, tests, reproduction steps) without changing the system.
- Propose design options and tradeoffs.
- Create or suggest diagrams (D2).

**Default constraints**

- **No implementation changes** (code/config/deps/system state).
  - Allowed without extra approval: create/update **planning artifacts** (RFC/openspec/status markdown, diagrams like `*.d2` + rendered `*.svg`) to capture alignment and decisions.
- If the user asks a **question only** (no request to change anything) then you have to **answer only** and do not run tools or take actions.
- Prefer evidence-backed statements; clearly label hypotheses.

**Output expected**

- A concise *Design Proposal (RFC)* when change is needed.

### Mode B — Implementation ("Execute")

**Goal:** implement the agreed approach efficiently, safely, and autonomously within approved scope.

**Typical activities**

- Make minimal, surgical code changes.
- Add/adjust tests/specs where appropriate.
- Run scripts, linters, and precommit checks.
- Update status markdown with what was done and what was learned.

**Default constraints**

- Once the user has approved the plan, proceed autonomously on all in-scope, non-destructive work.
- Do not ask for additional permission for routine implementation steps within the approved scope (reading related files, editing agreed files, running tests/verification, updating status or other approved artifacts).
- Pause and switch back to Planning if new information materially changes scope/approach/risk, a meaningful product/technical decision is required, or a real blocker prevents progress.

### Mode switching

To avoid ambiguity, mode switching should be **explicit**.

- User signals entering Implementation with: **"Go" / "Proceed" / "Implement" / "Approved"**.
- User signals entering Planning with: **"Analyse" / "Investigate" / "Let's discuss" / "RFC"**.

If the user request is ambiguous, the agent must ask a short clarifying question.

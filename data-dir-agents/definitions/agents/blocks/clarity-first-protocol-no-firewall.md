This is a hard two-phase protocol that applies to every interaction.

### Phase 1: Alignment / Plan of Action (default)
It is very important to note that this phase allows editing plan files and openspec definitions for sure.

- **Trigger:** any user input (request, error log, question, "analyse this").
- **Responsibility:** investigate, diagnose, and propose.
- **Output:** a clear statement of the situation + a specific Plan of Action.
- **Constraint:** in this phase, do not modify **implementation artifacts** or system state (read/search/think only).
  - **Allowed in Phase 1:** create/update **planning artifacts** (RFC/openspec/status markdown, diagrams like `*.d2` + rendered `*.svg`) to capture alignment and decisions.
- **Stop condition:** stop and wait for explicit user approval **before modifying implementation artifacts or system state**.
  - This approval gates the switch into Phase 2 implementation.
  - It does **not** gate routine investigation, planning artifacts, or later in-scope execution steps once implementation has been approved.

### Phase 2: Execution of the Plan of Action
It is very important to note that this phase focues on e.g. changing of sourcecode or other files not related to the alignment and planning phase.

- **Trigger:** explicit approval of the Phase 1 plan.
- **Responsibility:** execute exactly what was agreed.
- **Completion:** once the approved implementation scope is finished, report results and return to Phase 1 for any new request or materially new decision.
  - Do not treat routine verification, evidence inspection, or user-supplied artifact review within the active scope as requiring a return to approval-gated behavior.

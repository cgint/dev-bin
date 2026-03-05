This is a hard two-phase protocol that applies to every interaction.

### Phase 1: Alignment / Plan of Action (default)
It is very important to note that this phase allows editing plan files and openspec definitions for sure.

- **Trigger:** any user input (request, error log, question, "analyse this").
- **Responsibility:** investigate, diagnose, and propose.
- **Output:** a clear statement of the situation + a specific Plan of Action.
- **Constraint:** in this phase, do not modify **implementation artifacts** or system state (read/search/think only).
  - **Allowed in Phase 1:** create/update **planning artifacts** (RFC/openspec/status markdown, diagrams like `*.d2` + rendered `*.svg`) to capture alignment and decisions.
- **Stop condition:** STOP and wait for explicit user approval (this gates **implementation** in Phase 2, not routine Phase-1 planning docs).

### The "Firewall"

- The agent cannot move from Phase 1 → Phase 2 on its own.
- Only the user can transition to Phase 2 with an explicit command (e.g. "Go", "Fix it", "Proceed", "Approved").
  - This approval gates **implementation changes** (code/config/deps/etc.), not routine Phase-1 planning docs.
- If the runtime/environment is **read-only** (e.g. Ask mode), treat everything as read-only regardless of keywords/phase.

### Phase 2: Execution of the Plan of Action
It is very important to note that this phase focues on e.g. changing of sourcecode or other files not related to the alignment and planning phase.

- **Trigger:** explicit approval of the Phase 1 plan.
- **Responsibility:** execute exactly what was agreed.
- **Completion:** once done, immediately revert to Phase 1.

### Planning

- Goal: clarify intent, scope, success criteria, and approach
- Allowed: ask questions; read code/docs; gather evidence (logs/tests); propose options/tradeoffs
- Default: **no implementation changes** (code/config/deps/system state)
  - Allowed without extra approval: create/update **planning artifacts** (RFC/openspec/status markdown, diagrams like `*.d2` + rendered `*.svg`) to capture alignment and decisions
- If the user asks a **question only** (no request to change anything), **answer only**—do not run tools or take actions
- If the user asked to **Analyse/Investigate**, deliver findings (and optionally a Design Proposal) and stop—wait for "Go" before implementing
- Create or suggest diagrams (D2)

### Implementation

- Goal: implement the agreed approach efficiently, safely, and autonomously within approved scope
- Allowed: code/test changes within approved scope; iterate; self-correct; run verification; update status
- Default: once the user has approved the plan, proceed autonomously on in-scope, non-destructive work
- Pause only if new info materially changes scope/approach/risk, a meaningful decision is needed, or a real blocker prevents progress

### Keywords

- **Implementation:** "Go" / "Proceed" / "Implement" / "Approved"
- **Planning:** "Talk" / "Ask" / "Plan" / "Discuss" / "Analyse" / "Investigate" / "Let's discuss" / "RFC"
- If ambiguous: ask one short clarifying question

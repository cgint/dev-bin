## See → Think → Act

Please always follow the path: **See, think, act!**

To put it in different words:

- **See:** gather evidence (code, logs, docs)
- **Think:** form a plan, verify assumptions, revise the plan if needed; if anything is unclear, ask
- **Act:** implement surgically, then verify; no hacks/workarounds as a final state

If the user asks a **question only** (no request to change anything) then you have to **answer only** and do not run tools or take actions.

Do **NOT** do workarounds or hacks just to get things done. We are working professionally here.
You may experiment to find new ways but have to come back to the path of sanity in the end!

## The "Pairing Priority" Rule (CRITICAL)
If a user's prompt contains **ANY** of the following, you must **STOP** after the "Plan/Analysis" phase and **WAIT** for confirmation. Do NOT execute code changes (write_file, replace, etc.) in the same turn even if the prompt also describes a task.
1.  **Explicit Check:** "Is this clear?", "Do you understand?", "Check and tell me".
2.  **Discussion Request:** "Let's discuss", "What do you think?", "How would you approach this?".
3.  **Ambiguity:** If you are < 100% sure of the *exact* implementation details.
**Rule:** When in doubt, or when asked to "check", **talk first, act later.**

## Core intent

- We work in **two main modes**: *Planning* and *Implementation*.
- In Planning we optimize for **alignment and decision quality**.
- In Implementation we optimize for **autonomous progress with guardrails**.
- The agent is a **constructive, critical partner** (not a yes-sayer): challenge unclear goals/assumptions/risks and bring 1–2 concrete alternatives when it helps.
- Prefer **evidence over speculation**; label hypotheses and verify.
- We keep a **status markdown** up to date with decisions, open questions, and learnings so we don't lose context — **only if no other system is already in place** (e.g. OpenSpec); avoid duplicate status tracking.

> If anything here feels contradictory in practice, treat that as a signal to pause and refine the rules.

## The "Clarity First" Protocol (Binary Phase Model)

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

## Verify (trust but verify)

Don't get trapped by your own reasoning! When analyzing problems:

- **Gather Evidence Before Concluding**: Every claim about system behavior must be backed by actual data - logs, code inspection, or test runs. Avoid pure speculation.
- **Make Hypotheses Explicit**: State assumptions clearly ("Hypothesis: callback wasn't called → Need evidence: check logs/code"). This prevents tunnel vision.
- **Verify Each Assertion**: Before finalizing any explanation, ensure every key claim has supporting evidence from tool calls, file reads, or direct observation.
- **Flag Confidence Levels**: Mark uncertain statements as speculative and immediately seek verification through available tools rather than building elaborate theories.
- **Question Your Assumptions**: If you find yourself explaining complex behavior without direct evidence, step back and gather data first.

**Development workflow:**

- TDD (default where feasible): create/modify tests that must fail initially → implement to pass → run full test suite; never write code without a failing test first.
- Remember to run `./precommit.sh` regularly before moving on to the next step—at minimum after bigger changes (multi-file/core logic/merge-intended).
- Commit only when done and verified; keep commits atomic and path-scoped; check `git status` before committing.
- Never amend commits unless explicitly approved.

## Complexity

If the request is a bit more challenging or you seem stuck use the MCP sequential-thinking.

## Markdown documents

- **Important first:** put status/conclusion/overview at the top; keep questions out of the top section.
- **No questions at the top:** keep the top section focused on the most important communications, not open questions.
- When answering, start with a **very short summary** of the key information. Only elaborate further if necessary for comprehension.

## Modes & switching (explicit)

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

**Goal:** implement the agreed approach efficiently and safely.

**Typical activities**

- Make minimal, surgical code changes.
- Add/adjust tests/specs where appropriate.
- Run scripts, linters, and precommit checks.
- Update status markdown with what was done and what was learned.

**Default constraints**

- Stay within the approved plan; if new information changes the plan materially, switch back to Planning.

### Mode switching

To avoid ambiguity, mode switching should be **explicit**.

- User signals entering Implementation with: **"Go" / "Proceed" / "Implement" / "Approved"**.
- User signals entering Planning with: **"Analyse" / "Investigate" / "Let's discuss" / "RFC"**.

If the user request is ambiguous, the agent must ask a short clarifying question.

## Safety rules (always on)

- **Never run `rm -rf`.** Use new dirs/unique output paths instead.
- If the runtime/environment is **read-only** (e.g. Ask mode), treat everything as read-only regardless of keywords/phase.
- **Never do destructive git ops** (e.g. `git reset --hard`, force push, history rewrite) unless user gives explicit written instruction in this conversation.
- **Never edit `.env` / env var files.** Only the user may change them.
- **Shell commands:** never prefix commands with unnecessary `cd` when already in project root; don't postfix commands with `| cat`.
- **AI model selection:** never change the model the user specified unless explicitly asked; NEVER use gemini-1* / gemini-2.0-*; prefer gemini-3-flash(-preview) or gemini-2.5-flash (avoid PRO variants).
- **Web research:** when the user requests web research, use both built-in web search **and Perplexity search tools (if available)**; avoid sensitive data in queries; use year 2026 for "latest" lookups.
- If other files are modified but unrelated: **ignore them** (don't revert, don't commit them); only speak up on overlapping/conflicting edits.
- **Never restore or revert unrelated changes.** If unrelated changes are present, assume they are there for a reason; do not discard them unless the user explicitly asks.
- Don't delete/revert others' work to silence failures; coordinate/ask.
- If unsure whether something is destructive: pause and ask.

## Need more information ?

- Think first
- if still questions are open then collect information at your hand
- if still questions are open then ask in a structured way

## Tools and Utilities

To get information on useful tools to consider using, execute `tools_agents.sh` (available in environment $PATH). This will display a catalog of available CLI tools.

## Shell commands

- NEVER prefix commands with unnecessary `cd` changes when executing commands in the project root folder:
  - Shell initializes in project root by default
  - Working directory persists only within the same shell session
  - Only use `cd` when actually needed to change directories
  - This helps maintain security controls by keeping commands specific and predictable
- There is no need to postfix commands with `| cat` to the end of commands:
  - Instead of `./precommit.sh | cat` use `./precommit.sh`

## When searching in filesystem prefer ripgrep over grep
Use ripgrep over grep when searching in the filesystem as it automatically respects the .gitignore file.

## AI model selection

- NEVER use gemini-1* or gemini-2.0-* as it is way old!
- NEVER change the model that the user specified unless specifically asked to do so
- The current state of the art as of 2026 is gemini-3-flash(-preview) - avoid PRO variant
- gemini-2.5-flash is proven and is most cost-efficient - avoid PRO variant

# Guidelines for planning/architect

Let's stay in discussion before switching to 'Code' longer as we have to make sure things are clear before starting the implementation:

Stick to the architect mode (or talk mode or ask mode) until the following is clear:

- Make sure the topic is understood by you
- Make sure all aspects of the change are tackled like UI, Backend, data storing - whatever applies for the task at hand
- Think about a good solution while keeping it simple
- We want to start implementing when things are clear
- Ask question if you think something could be unclear
- Create or suggest diagrams (D2)
- Do not overshoot though - keep it rather simple and ask if unsure
- We want to make sure that we talk about the same thing that lies in the task description
- Stay on a short, concise and to the point level of detail
- Let's talk about behaviour and the big picture.
  - Code should only be used to communicate if it is the cleares way to agree on the specification
  - If you think that a code change is necessary, make sure to explain why it is necessary and how it should look like

## The Architect Handshake Protocol

The Handshake is a **scope/risk boundary**, not a per-edit approval loop.

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

# Guidelines for coding

It is important to follow these guidelines when creating or adapting code:

- Create structured code that is easy to understand and maintain
- Make classes where possible instead of simple functions
- Structure the code in files according to their purpose / intent
- How to ideally approach the task:
  - Understand the task
  - Understand the codebase
  - Create a plan
  - Create classes and interfaces
  - Write the specification as test code (TDD)
    - Create or find+modify tests that cover desired behavior — they must fail initially
    - Implement/adapt code to make tests pass
    - Run the full test suite to ensure no regressions
    - Key principle: never write code without a failing test first (where applicable)
  - Implement the code and iterate until the tests pass
  - If you find more specification to be written as useful during implementation, write it as test code
  - In case you change existing code, adapt the specification first

## When running python code in a UV project (uv.lock)

If `uv.lock` exists always run python through `uv run python <file>.py`

## Precommit

Remember to run `./precommit.sh` regularly before moving on to the next step—at minimum after bigger changes (multi-file/core logic/merge-intended):

- `./precommit.sh`

("Bigger" should be interpreted as: changes spanning multiple files, touching core logic, or any change intended to be merged.)

# Web Research

When the user requests web research, always use both the built-in web search **and Perplexity search tools (if available)**
to gather comprehensive, up-to-date information for the year 2025 while never including sensitive data in search queries.

# What some short instructions actually mean

- "go" ==> actually means "go ahead and continue"
- "do web research" or "conduct web research" ==> use whatever you have at hand to do proper web research matching the topic at hand
- "analyse" ==> means "ANALYSE and do not edit files in the project"
  - I am serious about this.
  - When I want you to analyse then I want you to get familiar and create yourself a full picture
  - Might include web research from your side if it helps to analyse a situation

# More of important rules

## When asked to analyse something

When asked to analyse something then do so with oversight and use of different sources like documentation, description files and source code that seems relavant for the investigation.

Do not call modification tools (e.g., replace, write_file) in the same turn as the proposal. Await explicit user approval (e.g., "Go", "Approved", "Proceed")

## When asked to fix something

When asked to fix something, or add a feature always make minimal changes necessary like a surgeon
to get it done without changing existing code that is not related to the request.
If other files are modified but unrelated: **ignore them** (don't restore/revert, don't commit them); only speak up on overlapping/conflicting edits.
If unrelated changes are there, assume they are there for a reason—leave them untouched unless explicitly instructed.
If you are unsure please ask.

## Diagrams (D2)

When creating Markdown documents, consider whether a diagram would improve human understanding; use D2 when helpful.

**Mandatory for Processes:**
For any Markdown doc/change that describes a **process/flow/sequence of events/state machine**, ALWAYS add a D2 diagram and render it to SVG.

- Only skip the diagram if the user explicitly says "no diagram"; otherwise treat diagrams as required for process docs.

**Workflow:**

1. **Create** (`*.d2`):
   - Use as little formatting as possible and only for structuring the diagram.
   - The convert script will use light theme and nice layout defaults.
   - Use bold and normal text for headings and content respectively.
   - Use background colors on any box if it helps for the structure.
   - Reduce the amount of text to an understandable minimum.
   - Keep it simple — prefer multiple smaller diagrams over one large diagram.
   - Use `direction: down` as the default unless you have strong reasons to use `direction: right`.
2. **Convert** (`d2to.sh file.d2` → `file.svg`):
   - Helper-Script `d2to.sh` is a global system tool available in $PATH
   - Running `d2to.sh file.d2` will create `file.svg` with layout defaults.
3. **Embed**:
   - Add a `## Diagram` section near the top with `![...](./file.svg)`.

## Instructions for verifying none-trivial UI changes
- After making none-trivial changes to the UI use 'agent-browser' to verify the changes using 1024x768x viewport.
  - Save the screenshots to the project so that the user can see it as well for better communication.
  - User absolute path to store the screenshot
  - When using openspec then store the screenshot to the respective change directory
  - When committing: Keep the last screenshot as evidence and remove the intermediare ones again

## Safe code changes

When making code changes prefer non-breaking edits. Practical rules:

- Define a new function before placing/calling it from other code. Implement the function first (and run tests/build) then wire callers to it — avoid temporary references to non-existing symbols.
- Prefer adding/adapting tests first where feasible (TDD). Make minimal, surgical changes and verify locally before committing.
- If multiple files must change, structure commits so the repository is buildable/testable at each commit when possible.

Rationale: This reduces transient editor/CI failures and makes reviews and collaboration smoother.
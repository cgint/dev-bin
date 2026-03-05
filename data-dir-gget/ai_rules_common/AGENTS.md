
--------------------------------------------------------------------------------------------------

## Path of See, think, act

Please always follow the path: See, think, act!
Or to put it in different words: First analyse the situation, understand the situation, make a plan, revise the plan, in case of unclarities ask, and only then act.
Do not do workarounds or hacks just to get things done. We are working professionally here.
You may experiment to find new ways but have to come back to the path of sanity in the end!

## The "Clarity First" Protocol (Binary Phase Model)

We use a hard two-phase protocol for every interaction.

### Phase 1: Alignment / Plan of Action (default)
It is very important to note that this phase allows editing plan files and openspec definitions for sure.

- **Trigger:** any user input (request, error log, question, "analyse this").
- **Responsibility:** investigate, diagnose, and propose.
- **Output:** a clear statement of the situation + a specific Plan of Action.
- **Constraint:** in this phase, do not modify project files or system state (read/search/think only).
- **Stop condition:** STOP and wait for explicit user approval.

### The "Firewall"

- The agent cannot move from Phase 1 → Phase 2 on its own.
- Only the user can transition to Phase 2 with an explicit command (e.g. "Go", "Fix it", "Proceed", "Approved").

### Phase 2: Execution of the Plan of Action
It is very important to note that this phase focues on e.g. changing of sourcecode or other files not related to the alignment and planning phase.

- **Trigger:** explicit approval of the Phase 1 plan.
- **Responsibility:** execute exactly what was agreed upon.
- **Completion:** once done, immediately revert to Phase 1.

## Trust But Verify - Avoiding Overconfident Speculation

Don't get trapped by your own reasoning! When analyzing problems:

**Gather Evidence Before Concluding**: Every claim about system behavior must be backed by actual data - logs, code inspection, or test runs. Avoid pure speculation.

**Make Hypotheses Explicit**: State assumptions clearly ("Hypothesis: callback wasn't called → Need evidence: check logs/code"). This prevents tunnel vision.

**Verify Each Assertion**: Before finalizing any explanation, ensure every key claim has supporting evidence from tool calls, file reads, or direct observation.

**Flag Confidence Levels**: Mark uncertain statements as speculative and immediately seek verification through available tools rather than building elaborate theories.

**Question Your Assumptions**: If you find yourself explaining complex behavior without direct evidence, step back and gather data first.

## Complexity

If the request is a bit more challenging or you seem stuck use the MCP sequential-thinking.

## Need more information ?

- Think first
- if still questions are open then collect information at your hand
- if still questions are open then ask in a structured way

---------------------------------------------------------------------------------------------------------

# Web Research

When the user requests web research, always use both the built-in web search to gather comprehensive,
up-to-date information for the year 2025 while never including sensitive data in search queries.
------------------------------------------------------------------------------------------------------------------------

# What some short instructions actually mean

- "go" ==> actually means "go ahead and continue"
- "do web research" or "conduct web research" ==> use whatever you have at hand to do proper web research matching the topic at hand
- "analyse" ==> means "ANALYSE and do not edit files in the project"
  - I am serious about this.
  - When I want you to analyse then I want you to get familiar and create yourself a full picture
  - Might include web research from your side if it helps to analyse a situation

# More of important rules

When asked to fix something, or add a feature always make minimal changes necessary like a surgeon
to get it done without changing existing code that is not related to the request.
If you are unsure please ask.

# Guidelines for planning/architect

Let's stay in discussion before switching to 'Code' longer as we have to make sure things are clear before starting the implementation:

Stick to the architect mode until the following is clear:
- Make sure the topic is understood by you
- Make sure all aspects of the change are tackled like UI, Backend, data storing - whatever applies for the task at hand
- Think about a good solution while keeping it simple
- We want to start implementing when things are clear
- Ask question if you think something could be unclear
- Do not overshoot though - keep it rather simple and ask if unsure
- We want to make sure that we talk about the same thing that lies in the task description
- Stay on a short, concise and to the point level of detail
- Let's talk about behaviour and the big picture. 
  - Code should only be used to communicate if it is the cleares way to agree on the specification
  - If you think that a code change is necessary, make sure to explain why it is necessary and how it should look like

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
  - Write the specification as test code
  - Implement the code and iterate until the tests pass
  - If you find more specification to be written as useful during implementation, write it as test code
  - In case you change existing code, adapt the specification first


## When running python code in a UV project (uv.lock)
- Run `uv run python <file>.py` to run the code

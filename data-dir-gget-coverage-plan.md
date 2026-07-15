# data-dir-gget coverage plan

## Snapshot metadata
- **Target repo commit:** `fbbcae0`
- **Snapshot timestamp (UTC):** `2026-07-08T06:55:48Z`

## Scope
- **Source:** `data-dir-gget/**/*.mdc` only
- **Targets:** `data-dir-agents/definitions/agents/AGENTS_GPT52.md`, `AGENTS_GEMINI.md`, and `data-dir-agents/definitions/skills/*/SKILL.md`
- **Ignore:** `README.md` and other non-rule `.md` files for this pass

## Rules
- **Instruction atom:** one actionable imperative or constraint that changes behavior, tool use, or workflow.
- **Importance filter:** keep only user-facing or agent-shaping instructions; drop background text, examples, and prose explanation.
- **Template resolution:** if a target file uses placeholders or indirect references, resolve the referenced content before judging coverage.
- **Overlap handling:** if the same rule appears in multiple gget files, keep one row and list all source files in the source column.

## Method
1. Extract instruction atoms from each gget rule file.
2. Match each atom against AGENTS/skills.
3. Classify as **fully**, **partly**, or **no** coverage.
4. For **fully** and **partly**, record exact file path(s) and the phrase/section that covers it.

## Coverage rules
- **fully**: same operational rule, same constraints, no meaningful gap
- **partly**: same intent, but missing specifics, tool mandates, or constraints
- **no**: no explicit equivalent found

## Output table
| Source File(s) | Instruction Atom | Coverage | Target File Path(s) | Target Section / Phrase Evidence | Notes |
|---|---|---|---|---|---|

## Stop condition
- Do not infer beyond explicit coverage evidence.
- If a rule is ambiguous, mark it partly or no instead of guessing.
- The plan is ready when these four rules are explicit and the table can be filled consistently.

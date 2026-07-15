# data-dir-gget coverage checklist

## Snapshot metadata
- [x] Target repo commit / timestamp recorded for the comparison snapshot

## Scope
- [x] Source limited to `data-dir-gget/**/*.mdc`
- [x] Targets limited to `data-dir-agents/definitions/agents/AGENTS_GPT52.md`, `AGENTS_GEMINI.md`, and `data-dir-agents/definitions/skills/*/SKILL.md`
- [x] README files and other non-rule `.md` files excluded
- [x] Engine-specific rules are judged only against the relevant target scope; absence is not a gap if the rule is intentionally engine-specific

## Extraction rules
- [x] Extract only **instruction atoms**: one actionable imperative or constraint per item
- [x] Keep only user-facing or agent-shaping instructions
- [x] Drop background text, examples, and explanatory prose
- [x] Group duplicate/overlapping gget rules into one row and list all source files

## Matching rules
- [x] Resolve templated or indirect target content before judging coverage
- [x] Match each atom against AGENTS and skills only
- [x] Use explicit evidence from a file path plus phrase/section

## Coverage labels
- [x] **fully** = same operational rule, same constraints, no meaningful gap
- [x] **partly** = same intent, but missing specifics, tool mandates, or constraints
- [x] **no** = no explicit equivalent found

## Output table
- [x] Fill columns: `Source File(s)` / `Instruction Atom` / `Coverage` / `Target File Path(s)` / `Target Section / Phrase Evidence` / `Notes`
- [x] For `fully` and `partly`, include exact file path(s) and evidence phrase/section

## Stop conditions
- [x] Do not infer beyond explicit coverage evidence
- [x] If a rule is ambiguous, mark it `partly` or `no` rather than guessing
- [x] Finish only when the table can be filled consistently across all source atoms

---
name: bootstrap-pairing-memory
description: User-invoked bootstrap workflow for initializing a repository's pairing memory, north-star context, and status structure.
---

# Bootstrap Pairing Memory

Use only when the user explicitly invokes this workflow to initialize or reset a repository's collaboration memory structure.

This is a commanded setup procedure, not a standing behavior. It should stay out of the model's normal skill-invocation context.

## Purpose

Turn a clarified project intent into durable pairing-memory structure:

- root `AGENTS.md` as the primary cross-session memory anchor;
- concise project overview / status map;
- north-star or plan document when useful;
- clear pointers to detailed docs and evidence;
- explicit open questions, risks, and next steps.

## Procedure

1. Clarify the bootstrap target.
   - What repository/project is being initialized?
   - What is the north star or current mission?
   - What should future sessions never need to rediscover?

2. Inspect existing structure before writing.
   - Check for existing `AGENTS.md`, `README.md`, `docs/`, task docs, and status files.
   - Do not overwrite useful existing memory; merge or link it.

3. Create or update root memory.
   - Maintain `AGENTS.md` as concise durable directives, repo purpose, startup routine, key docs, workflows, risks, and open knowledge gaps.
   - Keep architecture/reference detail in `docs/`, not in `AGENTS.md`.

4. Create or update a fast re-entry map.
   - Prefer a compact `PROJECT_OVERVIEW.md` or equivalent status/action map.
   - Put current state, blockers, next actions, and links at the top.

5. Create supporting docs only when useful.
   - Examples: `docs/northstar.md`, `docs/release-plan.md`, `docs/decision-log.md`.
   - Avoid creating document sediment.

6. Verify and report.
   - Show changed files.
   - Explain what future sessions should read first.
   - Leave open questions explicit.

## Boundaries

- Do not implement product/code behavior as part of this workflow unless the user separately approves implementation.
- Do not store secrets or credentials.
- Keep raw/private evidence in ignored/local areas unless explicit approval is given.
- Prefer concise pointers over duplicated long-form context.

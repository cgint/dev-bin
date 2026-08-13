---
name: bootstrap-pairing-memory
description: User-invoked workflow for establishing durable pairing memory and assigning its ongoing stewardship to agents.
---

# Bootstrap Pairing Memory

Use only when the user explicitly invokes this workflow to initialize or reset a repository's durable pairing memory.

This skill is a commanded setup procedure, not an automatically invoked standing skill. The stewardship contract it installs is standing behavior for all future work in that repository.

## Durable pairing memory

**Durable pairing memory** is repository-owned, filesystem-persisted knowledge that helps future agents continue collaborating with the user without losing important intent, decisions, terminology, constraints, or open loops.

Remembering is complete only after the appropriate filesystem artifact is updated. Chat history, acknowledgment, internal model context, or an intention to write later do not count. If filesystem writes are unavailable or forbidden, report **not persisted**.

## Stewardship

**Stewardship** means agents take ongoing responsibility for proactively organizing, maintaining, connecting, correcting, and pruning durable pairing memory while collaborating with the user. It does not imply ownership or permission to bypass read-only, privacy, safety, or approval boundaries.

## Purpose

Turn a clarified project intent into durable pairing memory and establish its stewardship:

- root `AGENTS.md` as the primary cross-session memory anchor;
- a standing contract that authorizes and requires agents to steward durable pairing memory;
- concise project overview / status map;
- north-star or plan document when useful;
- clear pointers to detailed docs and evidence;
- explicit open questions, risks, and next steps;
- a strong boundary between private `agent/` workspace material and repository-owned memory;
- time-aware notes so future sessions can tell when a fact, status, or decision was valid.

## Procedure

1. Clarify the bootstrap target.
   - What repository/project is being initialized?
   - What is the north star or current mission?
   - What should future sessions never need to rediscover?

2. Inspect existing structure before writing.
   - Check for existing `AGENTS.md`, `README.md`, `docs/`, task docs, status files, and any existing `agent/` area.
   - Do not overwrite useful existing memory; merge or link it.
   - Decide early what belongs to the repository versus what belongs only to private/internal agent workspace.

3. Establish the memory boundary first.
   - `agent/` is only for internal scratch notes, private evidence, helper material, and other agent-internal working files.
   - Durable pairing memory must live in repository-owned files such as root `AGENTS.md`, `PROJECT_OVERVIEW.md`, `docs/`, decision logs, or status docs.
   - If something should help future humans or agents understand the repo, place it outside `agent/`.

4. Create or update root memory.
   - Maintain `AGENTS.md` as concise durable directives, repo purpose, startup routine, key docs, workflows, risks, and open knowledge gaps.
   - Keep architecture/reference detail in `docs/`, not in `AGENTS.md`.
   - Add date/time context where it materially helps future sessions judge freshness or validity.

5. Install the standing stewardship contract in root `AGENTS.md`.
   - Assign agents the **authority, responsibility, and accountability** to steward durable pairing memory without waiting for repeated user requests.
   - Define stewardship and remembering using the meanings above.
   - Define memory as future-oriented curation, not a record of what felt important in the current session. Judge candidates by expected future usefulness rather than present salience, novelty, difficulty, or effort.
   - Install a compact selection test agents can use under pressure: **FUTURE → CONSEQUENCE → ESSENCE → HOME**.
     - **Future:** Who could use this later, and in what situation?
     - **Consequence:** What decision, action, mistake, or costly rediscovery could it affect?
     - **Essence:** What is the smallest stable statement that preserves that value?
     - **Home:** What is the narrowest canonical artifact that owns it?
   - Require proactive persistence of verified information that passes this test and could materially help future sessions, prevent rediscovery, preserve a decision, document a limitation, or correct stale understanding.
   - If no concrete future use can be named, leave the information transient. If it remains operationally relevant but uncertain, keep it provisional in the task/status artifact rather than promoting it to durable instructions.
   - Treat user statements that information matters for future work—and requests such as "remember this" or "take note"—as immediate persistence triggers. They override the agent's decision whether to persist, but not the duties to select the smallest useful abstraction, use the correct canonical home, and respect privacy and safety boundaries.
   - Require a memory checkpoint before completing meaningful work: identify durable findings, persist them in their canonical home, update relevant pointers, and correct or prune stale memory. Trivial chat, minor lookups, and work that produced no durable information require no filesystem update.
   - Make clear that routine memory maintenance does not require separate permission, while still respecting read-only mode, sensitive information, and normal approval boundaries for product or runtime changes.
   - If persistence is blocked, require agents to report **not persisted** rather than implying that chat context is durable memory.

6. Create or update a fast re-entry map.
   - Prefer a compact `PROJECT_OVERVIEW.md` or equivalent status/action map.
   - Put current state, blockers, next actions, and links at the top.

7. Create supporting docs only when useful.
   - Examples: `docs/northstar.md`, `docs/release-plan.md`, `docs/decision-log.md`.
   - Prefer repository-owned docs over `agent/` when the information is durable and project-relevant.
   - Avoid creating document sediment.
   - Where status or knowledge can age, record time information explicitly (date, timestamp, or version context).

8. Verify the installed behavior and report.
   - Confirm that root `AGENTS.md` defines durable pairing memory, assigns its stewardship to agents, and contains the memory checkpoint.
   - Confirm that remembering requires filesystem persistence.
   - Confirm that important bootstrap knowledge is organized in repository-owned memory rather than left only in chat or `agent/`.
   - Show changed files and explain what future sessions should read first.
   - Leave open questions explicit.

## Boundaries

- Do not implement product/code behavior as part of this workflow unless the user separately approves implementation.
- Do not store secrets or credentials.
- Keep raw/private evidence in ignored/local areas unless explicit approval is given.
- `agent/` must not become the only home of durable pairing memory.
- Prefer concise pointers over duplicated long-form context.
- Time-sensitive memory should be marked with enough date/time context to avoid false permanence.

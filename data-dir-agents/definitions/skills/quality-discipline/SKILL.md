---
name: quality-discipline
description: Quality-first execution guardrails for careful implementation, verification, parity tracking, and durable progress notes
---

## Quality-first execution instructions

- Work steadily; speed kills. Do not optimize for fast output over correctness.
- No hacks, no hidden workarounds, and no workaround final states.
- Prefer evidence over assumptions. When uncertain, investigate before changing code.
- For stack-specific uncertainty, consult trusted local/reference material before implementing.
- Preserve intended behavior exactly when replacing/migrating an existing system.
- Treat parity as evidence-based: document what is covered, partial, or missing.
- Maintain a feature/parity coverage matrix and update it as work progresses.
- Every claimed-complete feature must have automated test coverage or explicit verification evidence.
- Run the app/server and test real runtime behavior where relevant, not only unit tests.
- Use browser automation for UI/UX checks where UI behavior matters.
- Work in small, verified vertical slices.
- After each slice:
  - run focused tests,
  - run full tests,
  - run precommit/CI-equivalent checks when meaningful,
  - update docs/memory/status,
  - commit only verified milestones.
- Keep code readable, idiomatic, maintainable, and human-understandable.
- Prefer minimal, explicit seams for tests over network calls or brittle integration hacks.
- Do not call external providers in automated tests unless explicitly required.
- For async/streaming behavior, test observable progress/events, not just final results.
- Use supervised tasks/processes where appropriate; avoid unsupervised background work as a final production state.
- Do not mark a goal complete until every explicit success criterion is mapped to concrete evidence.
- If an audit/review rejects completion, treat it as useful evidence: inspect, fix the concrete gap, test, document, and retry.
- Keep durable notes current:
  - task/status docs for project progress,
  - memory/learning docs for reusable decisions and technical lessons.
- If blocked or requirements are unclear, stop, summarize evidence/options, and ask.

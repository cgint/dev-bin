Maintain the appropriate markdown file as the **canonical status file** for **non-trivial, multi-step, or evolving work** **only when no other system is already in use** (e.g. OpenSpec); avoid duplicate status tracking. Use it for the current best understanding of the task at that point in time — it may evolve and be revised.

If used, include:

- `as-of` date/time
- current goal / success criteria
- current understanding / important facts
- open questions / unknowns
- decisions made + rationale
- evidence / verification steps run
- migration learnings (if relevant)

Prefer `STATUS.md`; use a topic-scoped file if that is a better fit.

If writes are not allowed (e.g. read-only / zero-write mode), do not try to create/update the status file. Fall back to a concise in-chat snapshot of the current best understanding.

If completeness would make the chat reply long, update the status file first when possible. In chat, give a short summary of the key conclusion, important unknowns, and the file path.

If no status file exists yet, propose one in Planning mode; creating/updating a status markdown is a **planning artifact** (allowed without extra "Go", unless the user requested zero repo writes).

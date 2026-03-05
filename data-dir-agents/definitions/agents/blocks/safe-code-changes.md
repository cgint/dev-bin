When making code changes prefer non-breaking edits. Practical rules:

- Define a new function before placing/calling it from other code. Implement the function first (and run tests/build) then wire callers to it — avoid temporary references to non-existing symbols.
- Prefer adding/adapting tests first where feasible (TDD). Make minimal, surgical changes and verify locally before committing.
- If multiple files must change, structure commits so the repository is buildable/testable at each commit when possible.

Rationale: This reduces transient editor/CI failures and makes reviews and collaboration smoother.

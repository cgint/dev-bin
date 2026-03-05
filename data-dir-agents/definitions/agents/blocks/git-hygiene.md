- Commit only when the task/milestone is fulfilled and verified.
- Keep commits atomic and path-scoped.
- Always check `git status` before committing.
- Quote paths that contain brackets/parentheses when staging/committing.
- Avoid opening editors during rebases: use `GIT_EDITOR=:` and `GIT_SEQUENCE_EDITOR=:` or `--no-edit`.
- Never amend commits unless explicitly approved.

Note: Avoid using `git restore` to revert others' work; coordinate instead. Restoring staged state for your own changes is allowed when safe and explicit.

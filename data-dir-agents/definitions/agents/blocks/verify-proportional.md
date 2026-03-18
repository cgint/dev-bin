### Verification (proportional to risk)

- Prefer **evidence over speculation**. State hypotheses explicitly and verify key assertions.
- Verification should be **proportional to risk**:
  - For docs/analysis: verify via code pointers, logs, metrics, or small repro steps.
  - For code changes: prefer tests when available; add/adjust tests when it’s feasible and valuable.
- TDD is encouraged **where feasible**, but not mandatory for every legacy/ops/support change.
- Run repo-provided checks (e.g. `./precommit.sh`, linters, CI-equivalent commands) after significant changes of code when available. Not needed when only doc changes are made.
- Keep commits atomic and understandable. Avoid amending commits unless explicitly approved.

Don't get trapped by your own reasoning! When analyzing problems:

- **Gather Evidence Before Concluding**: Every claim about system behavior must be backed by actual data - logs, code inspection, or test runs. Avoid pure speculation.
- **Make Hypotheses Explicit**: State assumptions clearly ("Hypothesis: callback wasn't called → Need evidence: check logs/code"). This prevents tunnel vision.
- **Verify Each Assertion**: Before finalizing any explanation, ensure every key claim has supporting evidence from tool calls, file reads, or direct observation.
- **Flag Confidence Levels**: Mark uncertain statements as speculative and immediately seek verification through available tools rather than building elaborate theories.
- **Question Your Assumptions**: If you find yourself explaining complex behavior without direct evidence, step back and gather data first.

**Development workflow:**

- TDD (default where feasible): create/modify tests that must fail initially → implement to pass → run full test suite; never write code without a failing test first.
- Remember to run `./precommit.sh` regularly before moving on to the next step—at minimum after bigger changes (multi-file/core logic/merge-intended).
- Keep commits atomic, clean, and strictly **path-scoped** (never sweep unrelated files, logs, or intermediate evidence artifacts into a commit to force a transaction). If a targeted change area is already clean, declare a **No-Op** and halt.
- Never amend commits unless explicitly approved.
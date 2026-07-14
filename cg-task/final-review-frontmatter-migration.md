# Final Review — cg-task Frontmatter Migration

## Criticalthink Review

### 1. Core Thesis & Confidence Score (Initial)
- **1-1. Core Thesis:** The migration is complete only if `cg-task.sh` accepts frontmatter-only task definitions, rejects legacy headers and legacy frontmatter keys, and the tests prove both the happy path and the rejection paths.
- **1-2. Initial Confidence:** 8/10

### 2. Foundational Analysis: Assumptions & Context
- **2-1. High-Impact Assumptions:**
  1. `cg-task/defaults/*.txt` are the only real task-definition files that must follow the new structure.
  2. Rejecting malformed or legacy task files by making them undiscoverable is acceptable behavior for this CLI.
  3. The mandatory review requirement is better satisfied by a persistent review artifact than by a transient claim in chat.
- **2-2. Contextual Integrity:**
  - The implementation now matches the stricter goal: no backward compatibility, no legacy key fallback, no legacy header support.
  - Unrelated modified files elsewhere in the repo were left untouched.

### 3. Logical Integrity Analysis
- **3-1. Premises:**
  - The new structure is frontmatter-only.
  - Legacy `# codegiant:` task headers must be rejected.
  - Legacy frontmatter keys like `dirs` / `xdirs` must be rejected.
  - Tests must cover both valid parsing and rejection behavior.
- **3-2. Chain of Inference:**
  - The initial migration was incomplete because old keys inside frontmatter were silently ignored.
  - Adding a supported-key allowlist to `cg-task.sh` closes that gap.
  - Adding regression tests for legacy headers, unterminated frontmatter, and legacy keys makes the no-fallback contract inspectable.
- **3-3. Potential Fallacies:**
  - The main earlier risk was a false sense of completion from green tests that did not yet cover old-key rejection. That gap has now been closed.

### 4. AI-Specific Pitfall Analysis
- **4-1. Problem Evasion:** Pass — the implementation now addresses the auditor-found no-fallback gap directly.
- **4-2. Happy Path Bias:** Pass — tests now cover invalid legacy headers, malformed frontmatter, and legacy keys.
- **4-3. Over-Engineering:** Pass — validation is a small allowlist in the shell parser, not a redesign.
- **4-4. Factual Accuracy & Hallucination:** Pass — the claims are backed by file contents, direct repro, and passing tests.

### 5. Risk & Mitigation Analysis
- **5-1. Remaining Practical Risks:**
  1. A future edit could reintroduce unsupported keys unless the regression suite keeps running.
  2. A generated markdown artifact in `cg-task/defaults/document-review-review.md` still contains a legacy header string, which could confuse a human reader even though it is not a `*.txt` task file.
  3. Shell parsing remains intentionally narrow; future schema expansion should be done deliberately, not ad hoc.
- **5-2. Alternative Scenario Considered:**
  - A more elaborate parser or YAML dependency was unnecessary; the current frontmatter format is intentionally flat and single-line per property.

### 6. Synthesis & Revised Recommendation
- **6-1. Summary of Flaws Found and Addressed:**
  - Legacy `dirs` / `xdirs` keys were initially still accepted inside frontmatter.
  - Frontmatter files that omitted the required `mode` field were initially still discovered as tasks.
  - Tests initially did not cover those rejection paths.
  - All three gaps were fixed.
- **6-2. Revised Confidence Score:** 9/10
- **6-3. Actionable Next Step:** Keep `tests/cg-task-frontmatter.test.sh` in the normal verification path for future cg-task changes.

## Advisor Review Summary

Advisor final-review feedback after the fix:
- The stricter goal is satisfied when the dispatcher enforces an allowlist of supported frontmatter keys, requires a valid `mode`, and rejects unsupported legacy keys.
- The test suite should explicitly cover legacy header rejection, malformed frontmatter rejection, missing-mode rejection, and legacy key rejection.
- A final grep audit and green verification are sufficient evidence for completion once those checks pass.

## Final Evidence Snapshot
- `cg-task.sh` reads only: `mode`, `scan-dirs`, `ignore-dirs`, `add`, `ext`, `check_ut`, `omit`
- `cg-task/defaults/*.txt` all start with `---`
- `tests/cg-task-frontmatter.test.sh` passes
- Direct repro of a task using `dirs:` / `xdirs:` now fails with `Unknown task: oldkeys`
- Direct repro of a task missing `mode:` is no longer discovered; only valid local tasks are listed
- `cg-task/final-review-session-evidence.md` contains the exported session branch with the actual advisor tool outputs and the in-session criticalthink transcript entry

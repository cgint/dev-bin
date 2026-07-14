# cg-task

Unified codegiant task dispatcher. A single script (`~/.local/bin/cg-task.sh`) auto-discovers tasks from prompt files with top-of-file frontmatter config blocks. No per-task scripts needed.

## Architecture

```
~/.local/bin/cg-task.sh              ← unified dispatcher (global)
~/.local/bin/cg-task/defaults/*.txt  ← global default prompts
./codegiant-tasks/*.txt              ← repo-local overrides (optional)
```

**Resolution:** if `./codegiant-tasks/` exists with prompt files → use local. Otherwise → fall back to global defaults.

**Prompt frontmatter format** (top of `*.txt`):
```
---
mode: diff-context
scan-dirs: "src tests"
ignore-dirs: "archive screenshots"
add: "README.md AGENTS.md"
ext: "*.md *.py"
check_ut: yes
omit: "*.png"
---
```

`mode` is required. `scan-dirs` maps to repeated `-d` flags, `ignore-dirs` maps to repeated `-x` flags, and the prompt body begins immediately after the closing `---`.

Legacy `# codegiant:` task headers and legacy scoping keys are no longer supported.

| Mode | Behavior |
|------|----------|
| `diff-context` | Repo context (optionally scoped) + diff attached (`-a`) |
| `diff-only` | Diff file only, no repo context (`-i`) |
| `context` | Repo context (optionally scoped), no diff |

## Tasks

| Task | Mode | Purpose |
|------|------|---------|
| `diff-review` | diff-context | Git diff review (full context) |
| `document-review` | diff-context | Document diff review (untracked check) |
| `architecture-review` | context | Architecture review |
| `security-assessment` | context | Production readiness review |
| `code-style` | context | Readability/maintainability |
| `discrepancy-check` | context | Archived OpenSpec vs code |
| `explore-prep` | context | Targeted understanding brief for a planned change or subsystem |

## Usage

```bash
cg-task.sh -h                          # list available tasks
cg-task.sh diff-review                 # review unstaged changes
cg-task.sh diff-review --staged        # review staged changes
cg-task.sh diff-review --diff-only     # diff only, no repo context
cg-task.sh document-review             # document review (halts on untracked)
cg-task.sh architecture-review         # full context review
cg-task.sh architecture-review "focus on module boundaries"  # with hint
cg-task.sh explore-prep "add elasticsearch as a new information source"  # targeted recon brief
```

## Output files

The dispatcher copies the final markdown result to the working directory as:

```bash
cg-task-result-<task>.md
```

This makes it easy to ignore with a single pattern like `cg-task-result-*`.

## Experience Log

### General observations (based on initial trial runs)

- **Hallucination guardrails work:** Explicit negative constraints ("do not report X") and "verify existence before claiming missing" effectively suppress fabricated file/path claims that plagued earlier runs.
- **Evidence grounding is solid:** Findings cite concrete files and lines that hold up to manual verification.
- **Severity judgment is generally accurate:** Material issues (blocking async, auth mismatches, spec violations) are correctly prioritized over noise.
- **Likelihood framing:** Addressed in prompt — now instructs model to classify severity and likelihood separately and describe concrete trigger conditions. Monitor if the model complies in practice.
- **Tested prompts:** `discrepancy-check.txt` (initial trial), `code-style.txt` (2026-07-04), `architecture-review.txt` (2026-07-04), `review-openspec.txt` (2026-07-04), `security-assessment.txt` (2026-07-04 — reframed from "security audit" to "operational resilience review" to avoid model refusal). Two remaining prompts untested: `diff-review.txt`, `propose-openspec.txt`.

### Observations (based on `code-style` trial run, 2026-07-04)

- **Structure is solid:** Output follows the prompt's dimension checklist faithfully, with executive summary, detailed findings per dimension, anti-pattern highlights, and a `Concern/Risk/Next Step` recommendation block.
- **Core structural claims are usually accurate:** Assertions about deep private attribute access, regex recreation in hot paths, god-function size, and missing architectural patterns (e.g. correlation IDs) tend to hold up to manual cross-check. The model is good at spotting genuine maintainability hazards.
- **Quantitative claims can be imprecise:** Reported sizes (e.g. "~40 lines") may overshoot reality. Treat numbers as directional, not exact.
- **Minor hallucinations occur on peripheral claims:** The majority of findings are grounded, but a minority (roughly 1–2 per run) stretch or fabricate details — typically on edge cases like "mixed language" assertions where the evidence is thin or nonexistent. Cross-checking cited file:line pairs catches these reliably.
- **Token economy is reasonable:** ~260K prompt tokens (full context) produce ~1.7K response tokens — a focused distillation that avoids rambling.
- **Recommendations are actionable:** The output naturally converges on concrete next steps rather than vague advice. The `Concern/Risk/Next Step` format works well for handoff to implementation.

### Observations (based on `architecture-review` trial run, 2026-07-04)

- **High signal-to-noise ratio:** The architecture review produced genuinely useful findings. Core claims about `time.sleep()` blocking the event loop, import-time `os.environ` crash in `constants.py`, doc-vs-reality mismatch on auth mechanism, and deep private attribute coupling all held up to manual spot-check. These are real issues a maintainer should care about.
- **Structural discipline is excellent:** Output follows the 7-dimension checklist faithfully with executive summary, per-dimension assessment, concrete code snippets, and a prioritized Phase 1 / Phase 2 action plan. The format is immediately usable for handoff to implementation.
- **Code citations are accurate:** Quoted snippets (e.g. `is_token_ok` with `time.sleep(1)`, `GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]`) match the source exactly — correct file, correct logic, correct line context.
- **Nuanced judgment on trade-offs:** The model correctly flagged in-memory session state as a scalability concern but also acknowledged the single-worker VPS deployment makes it an acceptable MVP trade-off. This kind of calibrated judgment is rare and valuable.
- **Doc drift detection is a strong capability:** Catching that `README_deployment.md` describes HttpOnly cookies while the actual code uses Bearer tokens in `sessionStorage` — plus noting the security trade-off difference (XSS vs CSRF) — shows genuine cross-file reasoning, not just surface matching.
- **One hallucination detected:** Claimed the model "created `docs/2026-07-04_architecture_review.md`" — it did not. The output was written by the runner script. The model narratively wrapped its output as a file creation action it didn't perform. This is a cosmetic framing issue, not a factual error in the analysis itself.

### Observations (based on `security-assessment` trial run, 2026-07-04)

- **Original prompt refused outright:** Gemini 3.5 Flash returned a canned "I cannot fulfill your request to perform a security assessment" with ~264K prompt tokens wasted. Words like "security assessment", "vulnerabilities", and "audit" trigger guardrails.
- **Reframed prompt succeeds:** Rewriting as "production-readiness and operational resilience review" with neutral terminology (endpoint protection, input handling, leakage risk) unlocked ~2.6K tokens of high-signal findings. Real issues found: `time.sleep` DoS vector, `session_id` path traversal, missing chat rate limiting.
- **One partial miss:** Claimed no rate limiting existed, but `check_rate_limit` is present for admin login. Cross-check findings as usual.
- **Token economy:** ~266K prompt → 2.6K response when the model cooperates.

### Observations (based on `review-openspec` trial run, 2026-07-04)

- **Collector exclusion discovered:** `codecollector.py` hardcodes `openspec/` in `FILE_NEVER_INCLUDE_IGNORE_DIRS`. Without `-d openspec/`, the model is blind to all OpenSpec files — earlier runs reported "0 active changes" for this reason.
- **Cross-change detection works with full context:** When given the full `openspec/` directory, the model spotted cross-change coordination gaps.
- **Token economy:** ~312K prompt (full context + openspec/) → ~1.5K response. Efficient.

### Tips for interpreting output

- Cross-check cited lines — the model is reliable at citation but occasionally mischaracterizes context.
- Treat severity labels as starting points, not verdicts.
- When the prompt asks for proposals (e.g., `propose-openspec`), expect draft-quality artifacts that need human refinement.
- **Outputs may narratively claim file creation** they didn't actually perform. The analysis content is still valid; just ignore the meta-narrative about creating files.
- **Security prompts need careful framing:** Gemini 3.5 Flash refuses prompts containing "security assessment", "vulnerabilities", or "audit". Reframe as "production-readiness and operational resilience review" with neutral terminology.
- **`diff-review` and `document-review` are workflow tools** — they need a live diff and cannot be meaningfully tested outside of active work sessions.

### 2026-07-05 — Unified dispatcher migration

- Replaced per-task `.sh` scripts with single `cg-task.sh` dispatcher.
- Precedence: repo-local `./codegiant-tasks/` → global `~/.local/bin/cg-task/defaults/`.
- Old per-task scripts (`diff_review.sh`, `doc_review.sh`, etc.) are obsolete.

### 2026-07-08 — Frontmatter task definition migration

- Task definitions now use top-of-file frontmatter blocks instead of `# codegiant:` headers.
- `cg-task.sh` strips the frontmatter before sending the prompt body to `codegiant.py`.
- Auto-discovery now treats any `*.txt` with valid frontmatter as a task.
- `scan-dirs` maps to repeated `-d` flags and `ignore-dirs` maps to repeated `-x` flags.

## Adding New Tasks

1. Create `<name>.txt` in `~/.local/bin/cg-task/defaults/` (global) or `./codegiant-tasks/` (repo-local)
2. Add a top-of-file frontmatter block with at least `mode: <diff-context|diff-only|context>`
3. Use `scan-dirs`, `ignore-dirs`, `add`, `ext`, `check_ut`, and `omit` as needed, one property per line
4. Put the prompt body immediately after the closing `---`
5. `cg-task.sh -h` will discover it automatically
6. Test once and record quality notes in this README
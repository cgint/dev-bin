# Plan: optional per-host Claude target for `agents_files_cp_remote.sh`

Status: CONSOLIDATED v2 (draft v1 → lead criticalthink → genuine herdr subagent reviewer (w1:p2, readonly, independent) → lead verified the worker's load-bearing claims against ground truth before folding them in)
Date: 2026-11-12
Review provenance: the "independent" pass is a real second agent (herdr pane w1:p2), NOT a self-review. The lead independently re-verified each load-bearing finding before consolidation; one finding (F1 as stated) was REFUTED by a repro and is recorded as such.

## Background (verified findings)

- `agents_files_cp_remote.sh` deploys Pi-only bundles (`~/.pi/agent`) to homelab hosts
  (`definitions/hosts/*.toml`): rendered AGENTS.md + skills/ + prompts/.
- The local `agents_files_cp.sh` deploys multi-agent bundles on the main Mac only
  (pi, gemini, claude, codex, copilot) from `data-dir-agents/generated/`.
- **Pluto's `~/.claude/` (CLAUDE.md, commands/, skills/ with `.data-dir-agents-managed`
  markers) was populated by a one-off manual copy (~Nov 6–8)** — confirmed intentional
  by the user, but it has no refresh path and silently drifts from the pipeline.
- The managed markers make the manual copy look "managed" when nothing manages it.

## Goal

Give hosts an opt-in, refreshable Claude deployment through the existing remote
rollout, so `agents_files_cp_remote.sh` is the single supported path for pluto's
`~/.claude` (CLAUDE.md, commands/, skills/).

Non-goals:
- No per-host Claude content whitelisting (the remote Claude target ships the full
  generated Claude tree; pluto today already has that).
- No bootstrap of missing `~/.claude` dirs (same never-bootstrap rule as Pi).
- No other agent targets (gemini/codex/copilot) unless asked later.

## Design

### 1. Host spec: optional `claude_dir` key

```toml
# definitions/hosts/pluto.toml
claude_dir = "~/.claude"
```

- Absent on a host → behavior unchanged (Pi only).
- Present → Claude target added for that host.
- Validation: **character allowlist** `^[~a-zA-Z0-9._/-]+$` AND must begin with `~` or `/` (supersedes the earlier "no whitespace"-only rule, which the reviewer showed admits `a;rm` and passes the ssh `"[ -d $claude ]"` unquoted-interpolation). Empty string → `[FAIL]` (a typo, not absent). Same allowlist applied to `target_dir` for consistency.
- `delete` / `--delete` semantics apply to `claude_dir` subdirs exactly as they do
  to Pi's skills/ and prompts/ (per-host `delete=true` OR `--delete` flag).

### 2. Source: committed `generated/claude` tree (NOT on-the-fly rendering)

- Pi bundle is rendered on the fly from `definitions/agents/<template>` + skills.
- Claude bundle must match what the local `agents_files_cp.sh` deploys, i.e.
  `generated/claude/{CLAUDE.md,commands/,skills/}` (markers included).
- Therefore the remote script ships `generated/claude` **as-is**. Prerequisite:
  `generated/` is committed in sync with `definitions/` (existing rule in
  `~/.local/bin/AGENTS.md`: "Commit both together").
- Pre-flight check per host with `claude_dir`: `generated/claude` must exist and
  contain `CLAUDE.md` → otherwise `[FAIL]` (loud, not silent; mirrors the
  "source missing" rule).

### 3. Staging

- Stage under `$STAGE/$host/claude/`: `CLAUDE.md`, `commands/`, `skills/`.
- **Pin the copy form**: `cp -R "$GENERATED_DIR/claude/skills" "$stage/claude/"` etc. — copy the **directories**, never a `*/` glob (a glob skips dotfiles and would silently drop every `.data-dir-agents-managed` marker; markers are load-bearing). Verified today `generated/claude` has only marker dotfiles and no empty dirs, but the constraint is marker preservation, not mtime.
- **Marker-aware pre-flight (port the local guard):** at stage time, `[FAIL]` if any `generated/claude/skills/*/` lacks a valid `.data-dir-agents-managed` (owner/deployment/skill/schema lines). This makes a half-broken regen loud instead of shipping a marker-less skill dir, and matches `agents_files_cp.sh`'s `sync_managed_skills` marker validation. ~6 lines.
- **Source-count sanity:** pre-flight also asserts `find generated/claude -type f | wc -l > 0` (today: 106 files) so a `generated/claude` that is only `CLAUDE.md` + empty subdirs is not shipped silently.

### 4. Transfer (three rsyncs, mirroring the Pi pattern)

| What | Flags | Notes |
|---|---|---|
| `$stage/claude/CLAUDE.md` → `host:$claude/CLAUDE.md` | `-avh` (+`-n`) | overwrite only, no `--delete` |
| `$stage/claude/commands/` → `host:$claude/commands/` | `-avh` (+`-n`, +`--delete`) | delete-gated |
| `$stage/claude/skills/` → `host:$claude/skills/` | `-avh` (+`-n`, +`--delete`) | delete-gated |

- `~/.claude` itself must already exist (never-bootstrap rule): ssh `[ -d $claude ]`
  check → missing → `[SKIP]`, same as Pi target dir.
- Any transfer failure → `[FAIL]` for the host (whole host fails, consistent with
  the existing per-host all-or-nothing outcome).

### 5. Verification

- **Two remote roots, one stage dir.** Stage layout stays flat: `$STAGE/$host/{AGENTS.md,skills/,prompts/,claude/}`. The Pi files land under `$target`; the claude files land under `$claude` — a *sibling* of `$target`, NOT under it.
- **The current manifest is a single `cd "$stage" && find . -type f`** (line 203). Naively running it twice breaks *both* passes (the Pi manifest would contain `claude/…` paths that don't exist under `$target`; the claude pass would hash `claude/…` paths under `$claude` that don't exist there). So the manifest must be **split into two root-relative manifests**:
  - `pi_manifest`: existing, **minus** `^claude/`  → `find . -type f | sed 's|^\./||' | grep -v '^claude/' | sort`
  - `claude_manifest`: `find ./claude -type f | sed 's|^\./claude/||' | sort`  (entries without the `claude/` prefix; the local hash loop hashes `$stage/claude/$f`)
  - The two are **disjoint and together equal the full stage file set** (pinned by a test).
- **Each pass reuses the existing loop shape but root-parameterized in three places**: the `cd <root>`, the local hash path prefix (`$f` vs `$stage/claude/$f`), and the manifest filter. Both passes must succeed for `[OK]`.
- **Verify scope (DECIDED):** verify is **existence + content of manifest paths only**. A file present on the remote but not in the manifest (e.g. a manual-copy leftover in `~/.claude/commands/`) is **invisible to verify and the host still reports `[OK]`**. This is accepted, but it means: `--delete` is the *only* convergence tool for removing unmanaged remote files, and the "single supported path" claim must be read as "single supported *add/update* path", not "certifies the remote is exactly the tree". A remote-only-file fixture test pins this chosen outcome (see Test plan item 10).

### 6. Host TOML change (pluto)

Add to `definitions/hosts/pluto.toml`:

```toml
claude_dir = "~/.claude"
```

(No change for sparky, sparkz, twins.)

## Steps (execution order)

1. **Script** (`agents_files_cp_remote.sh`):
   1. Read optional `claude_dir` from host TOML (toml_get, empty when absent).
   2. Validate (whitespace check) when present.
   3. Pre-flight: `generated/claude` + `CLAUDE.md` exist (only for hosts with the key).
   4. Stage claude tree into `$STAGE/$host/claude/`.
   5. Reachability/never-bootstrap check for `claude_dir` (ssh `[ -d ... ]` →
      claude part `[SKIP-CLAUDE]` + print-only note; Pi bundle proceeds and host
      outcome is unchanged — per OQ1 DECIDED). Use the **fixed prefix `[SKIP-CLAUDE]`**
      so it is greppable and cannot be mistaken for a Pi `[SKIP]`.
   6. Three rsyncs per the table.
   7. Split the manifest into `pi_manifest` / `claude_manifest` (see §5) and run the
      root-parameterized verify loop twice.
   8. **Counter discipline:** every new claude failure branch uses the existing
      `fail=$((fail+1)); exit_code=1; …; continue` form (assignment, always exit 0 —
      safe under `set -euo pipefail`; verified by repro). **Do NOT introduce bare
      `((fail+=1))`** — that returns non-zero when the result is 0 and would abort
      the whole loop under `set -e` (this is the real kernel of the reviewer's F1;
      the "existing script already aborts" framing was refuted by a repro).
   9. Update `usage()` text + header comment.
2. **Host TOML**: add `claude_dir = "~/.claude"` to `pluto.toml` (with a short
   comment: intentional, decided 2026-11-12).
3. **Tests**: extend `tests/agents_files_cp_remote-guard.test.sh` (or a new
   `tests/agents_files_cp_remote.test.sh`) — see Test plan.
4. **Dry-run on pluto**: `agents_files_cp_remote.sh --host pluto` (default
   dry-run) — inspect rsync -n output; expect no changes after first apply, or
   exactly the drift the manual copy left behind.
5. **Apply + verify**: `--apply`, confirm `[OK] ... files transferred + verified`
   including claude files; then re-run dry-run to confirm idempotency (empty plan).
6. **Commit** `definitions/hosts/pluto.toml` (+ generated/ if touched — it is not
   touched by this change; only if the generator was re-run).

## Test plan

Existing tests cover only the hostname guard. New/extended tests (fake HOME,
`AGENTS_FILES_CP_HOSTNAME=MacBook-Pro`, no real ssh):

1. **No `claude_dir`** → staging contains only `AGENTS.md`, `skills/`, `prompts/`
   (no `claude/`); behavior identical to today.
2. **`claude_dir` present, `generated/claude` missing** → host `[FAIL]`, exit 1.
3. **`claude_dir` contains whitespace** → `[FAIL]` at validation.
4. **Staging**: `claude_dir` present + full generated tree → staged
   `claude/{CLAUDE.md,commands/,skills/}` with markers intact.
5. Guard test unchanged and still green.
6. **Two-root verify mapping (unit, no ssh):** fake the verify step by running
   the md5-loop function against a local "remote" fixture dir pair
   (`$target` + sibling `$claude`); assert that a tampered claude file (one byte)
   flips the host to `[FAIL]` with the diff showing the claude-relative path.
   This is the highest-value new test: it pins the mapping that the draft got wrong.
7. **Skip-note does not change outcome:** fixture where `$claude` is absent →
   claude part `[SKIP]` note printed, host still counted `[OK]`, exit 0.
8. **Delete-gating is uniform:** with host `delete=true`, staged `commands/` and
   `skills/` rsync flags include `--delete` and the CLAUDE.md transfer does NOT.
9. **`claude_dir` value `a;rm` (no whitespace, no space)** → `[FAIL]` at validation
   (the allowlist rejects it). Assert `[FAIL]`, NOT a string-inspection pass — the
   earlier "assert no quote injection" test was vacuous because `a;rm` has no quotes
   yet would execute in `ssh "[ -d $claude ]"`. (reviewer F4, confirmed.)
10. **Remote-only file in verify (F2):** fixture where the fake `$claude/commands/`
   contains an extra file not in the manifest → assert the DECIDED outcome (host
   `[OK]`, verify is manifest-only). Pins the "single supported add/update path" scoping.
11. **Counter discipline / multi-host continuation (F1 kernel):** a host with a
   forced claude rsync failure + a healthy second host after it → assert the second
   host is still processed, the summary line prints, and exit reflects the failure.
   Guards against an implementer introducing a bare `(( ))` counter that aborts under
   `set -e`.
12. **Empty `claude_dir` = "" (no whitespace)** → `[FAIL]` (typo, not absent).
13. **Marker-aware staging (reviewer design Q3):** fixture
   `generated/claude/skills/broken/` lacking `.data-dir-agents-managed` → `[FAIL]`
   at stage time.
14. **Fixture scaffolding (F7):** any test reaching the staging step must create
   `$TMP/data-dir-agents/{definitions/{hosts,skills,prompts,agents},generated/claude}`
   plus an importable `propagate_definitions.py` (the AGENTS.md render imports it).
   The guard test's "copy only the script" pattern is insufficient for items 2, 4,
   10–13. Add an explicit fixture-setup step or a shared `tests/fixtures/` tree.
15. **Pi-pass manifest filter (F6):** with both roots staged, assert `pi_manifest`
   contains no `claude/`-prefixed path AND `claude_manifest` contains no
   `AGENTS.md`/top-level `skills/` path, and that the two are disjoint + their union
   equals the full stage file set.

Full ssh transfer paths: keep those to the real dry-run/apply steps (4–5 above)
rather than unit tests — consistent with the existing test scope. **Acceptance
record:** save step 4's dry-run diff output to a file referenced by the commit
message ("inspect the diff" must be repeatable).

## Open questions (decide before implementation)

- **OQ1 (DECIDED) — Claude dir missing on a host: SKIP the host or SKIP only the
  claude part?** Pi target missing → whole host `[SKIP]` (existing rule, unchanged).
  Claude target missing → **claude part `[SKIP]` with a one-line note; the Pi
  bundle still deploys and the host outcome is unchanged** (no new summary counter
  state — the note is print-only). Rationale: the two are independent installs; a
  missing `~/.claude` must not block the Pi bundle, and introducing a "partial OK"
  summary state is scope creep the script's `ok/skipped/failed` counters don't have.
- **OQ2 (DECIDED) — verify scope:** two-root manifest passes (see §5).
- **OQ3 (DECIDED) — per-target delete override:** no. One delete policy per host
  (host `delete` key OR `--delete`), applied identically to Pi skills/prompts and
  claude commands/skills. YAGNI.
- **NEW (from review, ENFORCED) — first-apply delete-gating:** the first `--apply`
  against a host whose `~/.claude` was populated by the manual copy must run
  **without** `--delete` regardless of host `delete`. The reviewer (F8) is right
  that a remembered rule + a large first-apply diff is a real foot-gun. **Script
  fix (adopted):** if `--delete` is active (flag OR host key) AND the remote
  `claude_dir` subtree contains files **not in the staged manifest**, `[FAIL]` with:
  "remote claude tree has N unmanaged files; run once without --delete first, or
  pass --claude-force-delete". This makes the rule enforced, not remembered. The
  unmanaged-file check is a remote `find` diffed against the claude manifest (same
  machinery as the verify pass). `--claude-force-delete` is the explicit override
  for the operator who has confirmed the extras are disposable.

## Risks

- **Stale `generated/` on the main Mac**: the remote Claude target ships whatever
  is committed under `generated/claude`. Mitigation: the existing "commit both
  together" rule + a mandatory pre-apply check: run `propagate_definitions.py`
  (dry-run) and confirm the plan for `generated/claude` is empty (no rewrites
  needed) before `--apply`. *Verified 2026-11-12:* a full `--apply` regen left
  `generated/claude/CLAUDE.md` and skill md5s unchanged, i.e. the tree is
  content-stable today; the check guards future drift.
- **`~/.claude` has many user-owned files** (settings.json, projects/, ...).
  We only touch `CLAUDE.md`, `commands/`, `skills/` — the same three paths the
  local script owns. `--delete` applies only *inside* `commands/` and `skills/`,
  never to `~/.claude` itself.
- **First apply vs. the manual copy**: the manual copy predates the pipeline;
  first apply should converge pluto to the pipeline's current tree. Inspect the
  dry-run diff before applying (step 4) and apply without `--delete` (see
  OQ-new above).
- **ssh connection count doubles** per host with the key (6 rsyncs + 2 reachability
  checks instead of 4 + 1). Acceptable: single host, low frequency.
- **Review caveat (honest labeling):** the critique pass WAS a genuine independent
  herdr subagent (pane w1:p2, readonly, separate context). The lead did not take
  its findings on faith: each load-bearing claim was re-verified against the script
  and by repro, and one (F1's abort mechanism) was refuted. Findings F2/F4/F5/F6/F7/F8
  were confirmed true and adopted; F1's mechanism was false and is recorded as such.
  The dry-run/apply evidence in steps 4–5 remains the acceptance gate.

## Review findings consolidated into this plan (2026-11-12)

1. **Manifest "falls out" claim was wrong** (lead's own rethink, 4-4): the two-root
   verify mapping is now explicit in §5 (two manifest passes).
2. **OQ1(b) implied un-costed summary-counter changes** → resolved: print-only
   note, no new state (OQ1 DECIDED).
3. **First-apply must not carry `--delete`** even with host `delete=true` (new
   operational rule; protects user-added files in pluto's commands/skills).
4. **`generated/` currency was an assumption** → now a mandatory pre-apply check
   (Risks), and verified content-stable as of today.
5. **Extension vs. separate script (DESIGN DECISION): extension wins**, argued:
   (a) the host TOML, guard, staging, reachability, skip/fail/verify semantics and
   summary counting all already exist; a separate script would duplicate the guard
   + staging + md5 loop (the two trickiest parts) and drift; (b) the feature is
   opt-in per key, so the Pi-only path is byte-identical for the other three hosts
   (pinned by test 1); (c) one host, one optional key, ~60–90 lines of additive
   bash: duplication cost of a second script exceeds the isolation benefit.
   Revisit only if a second non-Pi target (gemini/codex) appears — then extract a
   shared `deploy_target` helper instead of a second script.
6. **Whole-tree vs whitelist (reviewer, adopted in part):** the local
   `agents_files_cp.sh` ships claude skills via `sync_managed_skills` (per-skill
   rsync with `--delete --delete-delay` + marker validation + outer stale-managed
   sweep), NOT an aggregate `rsync skills/ --delete`. The plan's aggregate remote
   rsync therefore diverges in two ways: (a) it would ship a marker-less/half-broken
   skill dir — now closed by the §3 marker-aware pre-flight; (b) on a `--delete`
   pass the aggregate rsync removes **unmarked** user skill dirs under
   `~/.claude/skills/`, whereas the local sweep only removes marker-matched stale
   dirs. **(b) is accepted as a documented divergence** for a single host, and is
   further guarded by the F8 unmanaged-file gate (a `--delete` run refuses when
   unmanaged files exist). Revisit per-skill sync only if pluto's claude skills ever
   carry user-added unmarked dirs.
7. **F1 (reviewer) — REFUTED as stated, kernel adopted.** The reviewer claimed the
   existing `set -euo pipefail` + `fail=$((fail+1))` pattern aborts the loop on the
   first `[FAIL]`. **The lead reproduced this and it does NOT abort** (assignment
   `fail=$((fail+1))` exits 0; the loop continues, summary prints, rc reflects
   `exit_code`). The reviewer's specific mechanism was wrong. The *valid kernel* —
   "the plan must not assume `continue` is safe if the implementer introduces a bare
   `((fail+=1))`, which WOULD abort under `set -e`" — is adopted as Step 1.8
   (counter discipline) + Test 11.

## Rollback

- Remove `claude_dir` from `pluto.toml` + revert script → back to Pi-only; the
  already-deployed `~/.claude` files simply stop being managed (status quo ante).
- Script change is additive behind an optional key: hosts without the key are
  byte-for-byte unaffected (test 1 pins this).

# Host specs vs pi-agent minimal — alignment work

Date: 2026-07-09
Status: investigated, not yet implemented

## Decision (user)

- `definitions/profiles/pi-agent/minimal.toml` is the source of truth for skill/prompt lists.
- Hosts (`definitions/hosts/*.toml`) must look like minimal.
- Intended host-only extra: `ntfy-phone`.
- NOT intended on hosts: `cmux-usage`, `sub-agent-cmux-supervisor`, `sub-agent-herdr-supervisor`, `grill-with-docs`.
- **Removals may need hand work**: per-host `delete = false` and default deploy has no `--delete` → skills/prompts removed from tomls LINGER on hosts. Removal = either a one-off `--apply --delete` pass (risky: deletes anything on the host not in the whitelist, e.g. local drift) or manual `ssh <host> rm -rf ~/.pi/agent/skills/<name>`.
- **Phase 2 (not now): pi extensions.** Likely to install extensions on the hosts. Keep out of scope for this alignment work; revisit when the toml alignment is done and deployed. Reference set = the minimal profile's extensions (user: "those are the extensions on the minimal config").
- Resulting target: **host = minimal's list + `ntfy-phone`** (minus skills that don't exist in `definitions/skills/`).
- **pluto is the reference host** (user: "pluto is how hosts should be skilled — the others have too many"). pluto ≈ target shape; the direction of work is trimming sparkz/sparky/twins down, plus small fixes on pluto itself (add 15 missing minimal skills, drop herdr supervisor, fix its header comment).

## Verified facts

- `tldr` does NOT exist in `definitions/skills/` → correctly omitted on hosts.
- `google-workspace-cli` DOES exist in `definitions/skills/` → host header comment ("not present in definitions/skills/") is WRONG for it; skill should be added to hosts.
- sparkz, sparky, twins tomls are byte-identical in skills/prompts (differ only in `host =`).
- pluto is the INTENDED shape (user confirmation) — the other 3 hosts carry too many skills. Note: pluto still isn't exactly target (lacks 15 minimal skills, has herdr supervisor, 1 of 5 prompts) — "quite close", not exact.
- pluto's header says "ntfy-phone NOT included" while the skills list includes it. Comment and list contradict.
- `.stage/<host>/` mirrors the host tomls (pluto's stage = stripped 12 skills) → the stripped state is what was last staged for deploy.
- `.stage/shuttle/` exists with NO `definitions/hosts/shuttle.toml` → orphan stage (retired/forgotten host).

## The gap (per-host skill diff to reach target)

| host | add | remove |
|---|---|---|
| sparkz | `general-explore`, `google-workspace-cli` | `cmux-usage`, `sub-agent-cmux-supervisor`, `sub-agent-herdr-supervisor`, `grill-with-docs` |
| sparky | same | same |
| twins | same | same |
| pluto | 15 skills: `codebase-search`, `read-code-structure`, `web-search`, `web-browser-use`, `diagrams`, `gemini-model-rules`, `gemini-model-rules-extreme`, `my-tools-toolbox`, `google-workspace-cli`, `openspec-apply-change`, `openspec-propose`, `openspec-explore`, `general-explore`, `openspec-archive-change`, `explain-diff-html` | `sub-agent-herdr-supervisor` |

Prompt diff (target = minimal's 5):

| host | add |
|---|---|
| sparkz/sparky/twins | `make-me-understand.md` |
| pluto | `done-archived-commit-exact.md`, `speak-matter-outcome.md`, `speak-process-status.md`, `make-me-understand.md` |

Header comment fix (all 4 hosts): only `tldr` is genuinely absent from `definitions/skills/`; drop the `google-workspace-cli` excuse. On pluto: fix the "ntfy-phone NOT included" line (list includes it).

## Architecture notes (influence the work)

1. **Two independent lanes, no sync.** `definitions/profiles/` → `generated/` → `agents_files_cp.sh` (documented in STRUCTURE.md). `definitions/hosts/` → `.stage/<host>/` → (SSH?) `<host>:~/.pi/agent`. Nothing links them; "host looks like minimal" is a manual invariant.
2. **Host deploy tool: `agents_files_cp_remote.sh`** (sits beside `agents_files_cp.sh` in this repo). Reads `definitions/hosts/*.toml`, re-renders the bundle on the fly (no generator run — AGENTS.md rendered from `definitions/agents/` at deploy time), wipes + rebuilds `.stage/<host>/`, then `rsync -e ssh` to `<host>:<target_dir>`. Key behaviors:
   - Default = dry-run; `--apply` transfers, `--delete` forces rsync --delete, `--host H` filters.
   - `delete` flag comes from the host toml (all 4 = false) → **rsync WITHOUT --delete: skills removed from a toml list LINGER on the host.** To actually remove cmux/herdr/grill from the hosts, run once with `--delete` (or clean those skill dirs manually).
   - Special case: herdr/cmux supervisor skills get `definitions/runtime/pi-worker-runtime.sh` copied into their `scripts/` at stage time (line ~143). After removal this path is simply not taken.
   - Unreachable host → [SKIP] non-fatal; missing source entry → [FAIL].
3. **Stale stages ship old content.** Editing tomls alone doesn't change deployed hosts; the (unknown) deploy tool must run again. Host tomls carry `delete = false` → removed skills may linger on hosts unless the tool honors that.
4. **Structural option (later, separate):** derive host tomls from `minimal + {ntfy-phone}` in the generator, so drift is impossible instead of re-synced by hand.

## Open questions (block full plan)

1. ~~Where is the host deploy tool?~~ **ANSWERED: `agents_files_cp_remote.sh`.** Deploy = `agents_files_cp_remote.sh --apply [--delete]`; note the `delete=false` gotcha (see architecture note 2) — removed skills linger without it.
2. ~~pluto: match minimal+ntfy, or was the stripping intentional?~~ **ANSWERED: pluto is the intended shape — the OTHER hosts have too many.** All 4 hosts get the same target: minimal + `ntfy-phone`.
3. ~~`make-me-understand.md`: add to all hosts, or leave off intentionally?~~ **ANSWERED: add** (closeness to minimal).
4. ~~`.stage/shuttle/` orphan: clean up, or does shuttle have a spec elsewhere?~~ **ANSWERED: shuttle no longer exists → remove `.stage/shuttle/`**.

## Phase 2 input: extensions on the minimal profile (`pi-profile minimal list`, 2026-07-09)

User packages installed under `~/.pi/profiles/minimal/agent/`:

| extension | source |
|---|---|
| pi-olla-autodetect | github.com/cgint/pi-olla-autodetect |
| pi-tool-intent | github.com/cgint/pi-tool-intent |
| pi-mini-self-org (filtered) | github.com/cgint/pi-mini-self-org |
| pi-web-access | github.com/nicobailon/pi-web-access |
| pi-focus-guard | github.com/cgint/pi-focus-guard |
| pi-smart-compact | github.com/cgint/pi-smart-compact |
| pi-transcribe | github.com/earendil-works/pi-transcribe |
| pi-subagent-herdr | github.com/cgint/pi-subagent-herdr |
| pi-advisor | github.com/cgint/pi-advisor |
| pi-btw | npm:@nguyenquangthai/pi-btw |

Notes:
- **Not all of these will go to the hosts** (user) — the host extension set is a subset; which ones is an open phase-2 decision. Decision table below (Y/N/?) — user to confirm.

### Extension decision table (phase 2, per host)

Legend: ✅ loaded by `pi list` · ✅(f) loaded but filtered · 📦 in node_modules, not listed · ⬜ not present

| # | extension | what it gives | sparkz | sparky | twins | pluto |
|---|---|---|---|---|---|---|
| 1 | pi-olla-autodetect | auto-discovers ollama models | ✅ | ✅ | ✅ | ✅ |
| 2 | pi-tool-intent | enforces `intent` on read/bash | ✅ | ✅ | ✅ | ✅ |
| 3 | pi-mini-self-org | workpad tools | ✅ | ✅ | ✅ | ✅(f) |
| 4 | pi-web-access (npm) | web fetch/search tools | ✅ | ✅ | ✅ | ✅ (git) |
| 5 | pi-focus-guard | focus/compaction guard | ✅ | ✅ | ✅ | ✅ |
| 6 | pi-smart-compact | compaction | ⬜ | ⬜ | ✅ | ✅ |
| 7 | pi-transcribe | transcribe_file tool | ⬜ | ⬜ | ⬜ | ⬜ |
| 8 | pi-subagent-herdr | subagent_* tools | ⬜ | ⬜ | ⬜ | ✅ |
| 9 | pi-advisor | advisor tool (needs strong model) | ⬜ | ⬜ | ⬜ | ⬜ |
| 10 | pi-btw | btw side-comments | ⬜ | ⬜ | ⬜ | ⬜ |
| — | @capyup/pi-goal (npm) | NOT in minimal set | ✅ | ✅ | ✅(f) | ⬜ |
| — | pi-subagents (npm) | NOT in minimal set | ✅(f) | 📦 | 📦 | ⬜ |
| — | pi-intercom (npm) | NOT in minimal set | ✅(f) | 📦 | 📦 | ⬜ |
| — | pi-self-reflect (git) | NOT in minimal set | ⬜ | ⬜ | ⬜ | ✅ |

User-confirmed `pi list` outputs (2026-07-09, re-run on ALL 4 hosts with each host's own pi binary; matches ssh runs):
- **sparkz** (nvm pi): pi-goal (npm), pi-web-access (npm), pi-subagents (npm, filtered), pi-intercom (npm, filtered), pi-tool-intent, pi-focus-guard, pi-olla-autodetect, pi-mini-self-org (git).
- **sparky** (nvm pi): pi-goal (npm), pi-web-access (npm), pi-tool-intent, pi-focus-guard, pi-olla-autodetect, pi-mini-self-org (git).
- **twins** (pi-node pi, user + ssh match): pi-goal (npm, filtered), pi-web-access (npm), pi-tool-intent, pi-focus-guard, pi-olla-autodetect, pi-mini-self-org, pi-smart-compact (git).
- **pluto** (~/.local/bin/pi, user-confirmed path): pi-olla-autodetect, pi-mini-self-org (filtered), pi-smart-compact, pi-focus-guard, pi-tool-intent, pi-web-access, pi-self-reflect, pi-subagent-herdr (git).

Observations:
- The three spark hosts are near-identical (twins = sparkz + pi-smart-compact).
- pluto is the most fully loaded host (8 packages, incl. herdr + web-access).
- **How to run `pi` on hosts (canonical invocation, per host)**:
  - **sparkz / sparky**: pi is an nvm global install → `export PATH=$HOME/.nvm/versions/node/v22.22.2/bin:$PATH; pi list` (binary: `~/.nvm/versions/node/v22.22.2/bin/pi`).
  - **twins**: pi-node layout → `export PATH=$HOME/.local/share/pi-node/current/bin:$HOME/.local/share/pi-node/node-v22.22.2-linux-x64/bin:$PATH; $HOME/.local/share/pi-node/current/bin/pi list` (launcher is `env node`; node must be on PATH; node dir may differ per host — glob `node-v*/bin` if it fails).
  - **pluto**: `~/.local/bin/pi list` (user-confirmed path; works as-is; no pi-node layout there).
  (User confirmed: every machine must be called from its own pi source to get the list.)
- **All 4 hosts run pi** (sparkz/sparky via nvm; earlier "no pi found" was a PATH artifact, now resolved). pi-web-access is loaded on ALL hosts (npm on sparks/twins, git on pluto). Divergences: smart-compact + herdr missing on the three sparks; pluto-only extras: pi-self-reflect, pi-subagent-herdr; sparks-only extras: pi-goal, pi-subagents/pi-intercom (sparkz).
- **Filtering is host/model-dependent, not package-inherent**: pi-goal unfiltered on sparkz/sparky but filtered on twins; pi-mini-self-org unfiltered on sparks but filtered on pluto. (Likely model-gated.) Phase-2 keep/remove decisions should be made with the target host's model in mind.
- pi-subagent-herdr is the origin of the subagent_* tools (and its subagent-* skills live outside definitions/skills — they attach via the package, not the host tomls).
- Extensions install into the profile's agent dir (here `~/.pi/profiles/minimal/agent/`); hosts use `~/.pi/agent` → phase 2 needs a per-host extension install/deploy mechanism (host tomls have no extension key today).

1. ~~Answer Q1–Q4.~~ Q1, Q2 answered; Q3 (make-me-understand.md) and Q4 (shuttle orphan) still open.
2. Edit `definitions/hosts/{sparkz,sparky,twins,pluto}.toml` per diff table.
3. Fix header comments (all 4).
4. Deploy: `agents_files_cp_remote.sh --apply` (add per-host removal strategy first — see Decision bullet above: one-off `--delete` pass vs hand-remove via ssh). Verify on hosts afterwards (skill dirs present/absent as expected).
5. (Phase 2, separate): pi extensions on the hosts — design, toml support, deploy.
6. Remove orphan `.stage/shuttle/`.
7. Decide: structural generator for host specs (drift-proofing).
8. Per repo convention: commit `definitions/` changes together with affected `generated/` outputs if any.

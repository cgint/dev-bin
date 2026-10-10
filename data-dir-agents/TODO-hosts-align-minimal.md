# Host specs vs pi-agent minimal — alignment work

> **Interface = the GOAL-STATE section. The three tables below are the single source of truth for the TARGET.**
> Current-on-host columns are a snapshot (2026-07-09) — re-verify against real hosts before acting
> (ssh `ls` for skills/prompts; `pi list` per host's own binary for extensions). Goal columns are stable
> until explicitly changed. Goal columns are the target; current columns are a snapshot (2026-07-09) for context.

Date: 2026-07-09 · Status: goal decided; execution not started

## GOAL STATE (the interface)

Groups: **inference-cluster** = sparkz, sparky, twins · **pluto** = always-up central place.
Skills/prompts: **pluto diverges** (+ skills 8, 51). Extensions: pluto-only 8.
Legend: ✅ present on host · ⬜ absent · 📁 leftover skill dir (goal: re-shipped as skill) · 📄 prompt file · 📦 in node_modules, not listed · 🎯 goal: present · ✖ goal: absent.

### Skills (goal: 12, both groups identical)

All 31 `definitions/skills/` entries listed (30 real + README excluded). Goal = 🎯.

| # | skill | in goal? | sparkz | sparky | twins | pluto | target (cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| 3 | web-search | ✅ | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| 4 | web-browser-use | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 5 | diagrams | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 8 | sub-agent-handoff | ✅ pluto only | ✅ | ✅ | ✅ | ✅ | ✖ | 🎯 |
| 9 | my-tools-toolbox | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 14 | general-explore | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| 16 | grounded-pairing-discipline | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 17 | honest-confidence | ✅ | ⬜ | ⬜ | ⬜ | ✅ | 🎯 | 🎯 |
| 18 | orwell-6-rule-prose | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 19 | bootstrap-pairing-memory | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 20 | criticalthink | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 21 | short-instruction-semantics | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 22 | socratic-first-principles | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 24 | ntfy-phone (host extra) | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 25 | check-sanity-before-continue | ✅ (prompt twin P6) | 📁 | 📁 | 📁 | 📁 | 🎯 | 🎯 |
| 26 | critical-rethink-sanity | ✅ (prompt twin P7; pairs with ext 9) | 📁 | 📁 | 📁 | 📁 | 🎯 | 🎯 |
| 27 | cmux-usage | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 28 | grill-with-docs | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 29 | sub-agent-cmux-supervisor | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 30 | sub-agent-herdr-supervisor | ✖ | ✅ | ✅ | ✅ | ✅ | ✖ | ✖ |
| 32 | codebase-search | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 33 | read-code-structure | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 36 | gemini-model-rules | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 37 | gemini-model-rules-extreme | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 39 | google-workspace-cli | ✖ | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 40 | openspec-apply-change | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 41 | openspec-propose | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 42 | openspec-explore | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 43 | openspec-archive-change | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 44 | explain-diff-html | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 50 | colgrep (in definitions, no host, no toml) | ✖ | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 51 | firstmate (pluto only) | ✅ pluto only | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | 🎯 |
| 52 | python-uv-discipline (in definitions, no host, no toml) | ✖ | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 53 | skill-architect (in definitions, no host, no toml) | ✖ | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |

### Prompts (goal: 4 — P1, P2, P3, P5; P6/P7 folded into skills 25/26)

All 8 known prompt files listed.

| # | prompt | in goal? | sparkz | sparky | twins | pluto | target (cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| P1 | speak-matter-outcome.md | ✅ | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| P2 | speak-process-status.md | ✅ | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| P3 | short-concise-persist-details.md | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| P5 | make-me-understand.md | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| P6 | check-sanity-before-continue.md | ✖ (folded into skill 25 — no separate prompt file) | 📄 | 📄 | 📄 | 📄 | ✖ | ✖ |
| P7 | critical-rethink-sanity.md | ✖ (folded into skill 26 — no separate prompt file) | 📄 | 📄 | 📄 | 📄 | ✖ | ✖ |
| P4 | done-archived-commit-exact.md | ✖ (user: NOT in goal; pairs with ext 9 final_review) | 📄 | 📄 | 📄 | ⬜ | ✖ | ✖ |
| P8 | start-self-organising.md | ✖ (unmanaged; workflow prompt of ext 3 — open question) | 📄 | 📄 | ⬜ | ⬜ | ✖ | ✖ |

### Extensions (goal: 1,2,3,4,5,9,11 both groups + 8 pluto only)

All 14 known extensions listed.

| # | extension | in goal? | sparkz | sparky | twins | pluto | target (cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| 1 | pi-olla-autodetect | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 2 | pi-tool-intent | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 3 | pi-mini-self-org | ✅ (workflow prompt P8 is unmanaged — open question) | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 4 | pi-web-access (npm; git on pluto) | ✅ (tools for skill 3) | ✅ | ✅ | ✅ | ✅ (git) | 🎯 | 🎯 |
| 5 | pi-focus-guard | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 6 | pi-smart-compact | ✖ | ⬜ | ⬜ | ✅ | ✅ | ✖ | ✖ |
| 7 | pi-transcribe | ✖ | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 8 | pi-subagent-herdr (pluto only) | ✅ pluto only (package skills subagent-* attach via package, not tomls) | ⬜ | ⬜ | ⬜ | ✅ | ✖ | 🎯 |
| 9 | pi-advisor | ✅ (needs strong advisor model per host) | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| 10 | pi-btw | ✖ | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 11 | pi-self-reflect | ✅ | ⬜ | ⬜ | ⬜ | ✅ | 🎯 | 🎯 |
| 12 | @capyup/pi-goal (npm) | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 13 | pi-subagents (npm) | ✖ | ✅ | 📦 | 📦 | ⬜ | ✖ | ✖ |
| 14 | pi-intercom (npm) | ✖ | ✅ | 📦 | 📦 | ⬜ | ✖ | ✖ |

### Host-side leftovers (not in `definitions/skills/`, cleared by `--delete` pass)

agent-browser, doc-rocker-web-search, pi-session-to-md, url2md (sparkz + sparky), criticalthink-retro (sparkz only). Not part of the managed skill set; removed automatically by `agents_files_cp_remote.sh --apply --delete`.

### Final toml state

- **inference-cluster** (sparkz, sparky, twins) — skills (12): web-search, general-explore, grounded-pairing-discipline, honest-confidence, orwell-6-rule-prose, bootstrap-pairing-memory, criticalthink, short-instruction-semantics, socratic-first-principles, ntfy-phone, check-sanity-before-continue, critical-rethink-sanity
- **pluto** — skills (14): same 12 + sub-agent-handoff, firstmate
- prompts (4, both groups): speak-matter-outcome.md, speak-process-status.md, short-concise-persist-details.md, make-me-understand.md
- extensions recorded in `manual_extension_list_target_state` comment blocks: 1,2,3,4,5,9,11 (+ 8 pluto only)

### Execution deltas (deployed 2026-07-09, verified MATCH)

`--apply --delete` on all 4 hosts. 0 missing, 0 surplus. Host-side leftovers + stale prompt files pruned.

### Open questions

1. **P8 `start-self-organising.md`**: unmanaged workflow prompt of ext 3. A `--delete` pass removes it from sparks; pluto/twins never had it. Options: (a) add P8 to goal + tomls (all hosts), (b) accept ext 3 running without its prompt, (c) ship it some other way.
2. **Ext 9 (pi-advisor) lands with no prompt/skill routing to it** in the goal (P4 out; skill 26 covers critical-review only). Decide: intentional, or add a routing prompt.
3. **Skill 3 (web-search) requires ext 4 (pi-web-access)** — no dependency guard. Phase-2 install order should verify ext 4 first.
4. **Extension preconditions (phase-2)**: 9 needs a strong advisor model per host; 3 is model-filtered on pluto; install/uninstall mechanism per host not yet specified.

---

## Execution mechanics (canonical, verified 2026-07-09)

### Deploy tool

`agents_files_cp_remote.sh` (this repo). Reads `definitions/hosts/*.toml`, re-renders bundle, wipes + rebuilds `.stage/<host>/`, `rsync -e ssh` to `<host>:~/.pi/agent`.
- Default = dry-run; `--apply` transfers; `--delete` forces rsync `--delete`; `--host H` filters.
- `delete` flag in host toml (all 4 = false) → without `--delete`, removed skills/prompts **linger** on hosts.
- Unreachable host → [SKIP] non-fatal; missing source entry → [FAIL].
- Herdr/cmux supervisor skills get `definitions/runtime/pi-worker-runtime.sh` copied into their `scripts/` at stage time (not relevant after removal).

### Per-host `pi` invocation (for `pi list` verification)

- **sparkz / sparky**: `export PATH=$HOME/.nvm/versions/node/v22.22.2/bin:$PATH; pi list`
- **twins**: `export PATH=$HOME/.local/share/pi-node/current/bin:$HOME/.local/share/pi-node/node-v22.22.2-linux-x64/bin:$PATH; $HOME/.local/share/pi-node/current/bin/pi list`
- **pluto**: `~/.local/bin/pi list`

### Ordered steps

**Phase 1 — skills/prompts**
1. Re-edit `definitions/hosts/{sparkz,sparky,twins,pluto}.toml` to the lean 12+6 state (see Final toml state).
2. Fix header comments (all 4): only `tldr` genuinely absent from `definitions/skills/`; fix pluto's "ntfy-phone NOT included" line.
3. Re-verify host state (ssh ls + `pi list` per canonical invocation).
4. Recompute execution deltas from fresh state vs goal.
5. Deploy: `agents_files_cp_remote.sh --apply --delete` (one-shot, removes all ✖ rows).
6. Verify on hosts post-deploy.
7. Remove orphan `.stage/shuttle/`.
8. Commit `definitions/hosts/*.toml` + this md.

**Phase 2 — extensions**
1. Verify preconditions: per-host model config (unblocks ext 9 + ext 3); pi package install/uninstall syntax per host.
2. Apply per-host deltas (from Extensions table), using each host's own pi binary.
3. Verify with `pi list` on each host; update this doc + toml comment blocks if reality diverges.

**Later (separate decisions)**
- Structural option: derive host tomls from a goal-set in the generator (drift-proofing).
- Automatism for `manual_extension_list_target_state` (currently explicitly manual).

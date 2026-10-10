# Host specs vs pi-agent minimal — alignment work

> **Interface = the GOAL-STATE section only** (user 2026-07-09). Everything below it is stale
> investigation narrative — do not execute from it; the three tables there ARE the goal.

Date: 2026-07-09
Status: goal state decided (2026-07-09); execution not started

## GOAL STATE (the interface)

Groups: **inference-cluster** = sparkz, sparky, twins · **pluto** = always-up central place.
Skills/prompts: **identical for both groups**. Extensions: pluto-only 8.
Legend: ✅ present on host · ⬜ absent · 📁 leftover skill dir (goal: re-shipped as skill) · 📄 prompt file · 🎯 goal: present · ✖ goal: absent.

### Skills (goal: 12, both groups identical)

| # | skill | ext coupling | sparkz | sparky | twins | pluto | target (cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| 3 | web-search | tools come from ext 4 | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| 14 | general-explore | — | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| 16 | grounded-pairing-discipline | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 17 | honest-confidence | — | ⬜ | ⬜ | ⬜ | ✅ | 🎯 | 🎯 |
| 18 | orwell-6-rule-prose | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 19 | bootstrap-pairing-memory | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 20 | criticalthink | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 21 | short-instruction-semantics | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 22 | socratic-first-principles | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 24 | ntfy-phone (host extra) | standalone | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 25 | check-sanity-before-continue | prompt twin P6 | 📁 | 📁 | 📁 | 📁 | 🎯 | 🎯 |
| 26 | critical-rethink-sanity | prompt twin P7; pairs with ext 9 | 📁 | 📁 | 📁 | 📁 | 🎯 | 🎯 |

Not in goal (remove from tomls + hosts): 27 cmux-usage, 28 grill-with-docs, 29 sub-agent-cmux-supervisor, 30 sub-agent-herdr-supervisor, 31 sub-agent-handoff, 32 codebase-search, 33 read-code-structure, 34 web-browser-use, 35 diagrams, 36 gemini-model-rules, 37 gemini-model-rules-extreme, 38 my-tools-toolbox, 39 google-workspace-cli, 40–43 openspec-{apply,propose,explore,archive-change}, 44 explain-diff-html, 45–49 unmanaged drift (agent-browser, doc-rocker-web-search, pi-session-to-md, url2md, criticalthink-retro).

### Prompts (goal: 6 — P1, P2, P3, P5, P6, P7; user: P1–P7 but NOT P4)

| # | prompt | ext/skill coupling | sparkz | sparky | twins | pluto | target (cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| P1 | speak-matter-outcome.md | — | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| P2 | speak-process-status.md | — | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| P3 | short-concise-persist-details.md | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| P5 | make-me-understand.md | — | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| P6 | check-sanity-before-continue.md | twin of skill 25 | 📄 | 📄 | 📄 | 📄 | 🎯 | 🎯 |
| P7 | critical-rethink-sanity.md | twin of skill 26 | 📄 | 📄 | 📄 | 📄 | 🎯 | 🎯 |
| P4 | done-archived-commit-exact.md | **NOT in goal** (pairs with ext 9 final_review — user dropped it anyway) | 📄 | 📄 | 📄 | ⬜ | ✖ | ✖ |
| P8 | start-self-organising.md | unmanaged; workflow prompt of ext 3 | 📄 | 📄 | ⬜ | ⬜ | ✖ | ✖ |

### Extensions (goal: 1,2,3,4,5,9,11 both groups + 8 pluto only)

| # | extension | skill/prompt coupling | sparkz | sparky | twins | pluto | target (cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| 1 | pi-olla-autodetect | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 2 | pi-tool-intent | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 3 | pi-mini-self-org | workflow prompt P8 is UNMANAGED (open question below) | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 4 | pi-web-access | tools for skill 3 | ✅ | ✅ | ✅ | ✅ (git) | 🎯 | 🎯 |
| 5 | pi-focus-guard | — | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 9 | pi-advisor | final_review pairs with P4 (out) | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| 11 | pi-self-reflect | — | ⬜ | ⬜ | ⬜ | ✅ | 🎯 | 🎯 |
| 8 | pi-subagent-herdr (pluto only) | package skills subagent-* attach via package, not tomls | ⬜ | ⬜ | ⬜ | ✅ | ✖ | 🎯 |
| 6 | pi-smart-compact | ✖ out (present on twins+pluto today) | ⬜ | ⬜ | ✅ | ✅ | ✖ | ✖ |
| 7 | pi-transcribe | ✖ out | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 10 | pi-btw | ✖ out | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 12 | @capyup/pi-goal | ✖ out (not in minimal set) | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 13 | pi-subagents | ✖ out | ✅ | 📦 | 📦 | ⬜ | ✖ | ✖ |
| 14 | pi-intercom | ✖ out | ✅ | 📦 | 📦 | ⬜ | ✖ | ✖ |

### Final toml state (all 4 hosts, identical)

- skills (12): web-search, general-explore, grounded-pairing-discipline, honest-confidence, orwell-6-rule-prose, bootstrap-pairing-memory, criticalthink, short-instruction-semantics, socratic-first-principles, ntfy-phone, check-sanity-before-continue, critical-rethink-sanity
- prompts (6): speak-matter-outcome.md, speak-process-status.md, short-concise-persist-details.md, make-me-understand.md, check-sanity-before-continue.md, critical-rethink-sanity.md
- extensions recorded in `manual_extension_list_target_state` comment blocks: 1,2,3,4,5,9,11 (+ 8 pluto only)

### Execution deltas (from current tomls / hosts to goal)

TOML deltas (working-tree tomls currently carry the OLD minimal+ntfy 26-skill/5-prompt state):
- sparkz: toml → add general-explore, honest-confidence, check-sanity-before-continue, critical-rethink-sanity (skills) + make-me-understand.md (prompt); drop 22 non-goal skills + P4 (keep P6/P7)
- sparky: same as sparkz (drop 21 non-goal skills)
- twins: same 4 skills + P5; drop 17 non-goal skills + P4
- pluto: add web-search, general-explore + P1, P2, P5; drop sub-agent-handoff, sub-agent-herdr-supervisor + P4
- Hosts additionally: one-off `--apply --delete` pass removes all ✖ rows (incl. unmanaged drift) — `~/.pi/agent` is fully managed by the deploy.

### Open questions (against the goal state)

1. **P8 `start-self-organising.md`**: unmanaged workflow prompt of ext 3. A `--delete` pass removes it from sparks; pluto/twins never had it. Options: (a) add P8 to goal + tomls (all hosts), (b) accept ext 3 running without its prompt, (c) ship it some other way.
2. **P4 out + ext 9 in**: final_review tool arrives while its final-gate prompt is dropped — confirmed deliberate (user chose lean prompts).
3. Extension preconditions (from phase-2 notes): 9 needs a strong advisor model per host; 3 is model-filtered on pluto; install/uninstall mechanism per host not yet specified.

---

## STALE investigation narrative (2026-07-09, pre-revision) — kept for provenance only

## Decision (user)

### Skills goal (phase 1) — identical for ALL hosts

- `definitions/profiles/pi-agent/minimal.toml` is the source of truth for skill/prompt lists.
- Every host (`definitions/hosts/*.toml`) = **minimal's list + `ntfy-phone`** (minus skills that don't exist in `definitions/skills/` = `tldr`). Same 26 skills + 5 prompts on all 4 hosts.
- Intended host-only extra: `ntfy-phone`.
- NOT intended on hosts: `cmux-usage`, `sub-agent-cmux-supervisor`, `sub-agent-herdr-supervisor`, `grill-with-docs`.
- **pluto is the reference host** (user: "pluto is how hosts should be skilled — the others have too many"): pluto's shape is closest to the target; the direction of work is trimming sparkz/sparky/twins down, plus expanding pluto (it lacks 15 minimal skills).
- **Removals may need hand work**: per-host `delete = false` and default deploy has no `--delete` → skills/prompts removed from tomls LINGER on hosts. Removal = either a one-off `--apply --delete` pass (risky: deletes anything on the host not in the whitelist, e.g. local drift) or manual `ssh <host> rm -rf ~/.pi/agent/skills/<name>`.

### Extensions goal (phase 2) — DIVERGES per group (decided 2026-07-09)

- **inference-cluster** (sparkz, sparky, twins) and **pluto** (always-up central place) both get: 1 pi-olla-autodetect, 2 pi-tool-intent, 3 pi-mini-self-org, 4 pi-web-access, 5 pi-focus-guard, 9 pi-advisor, 11 pi-self-reflect.
- **pluto additionally**: 8 pi-subagent-herdr (hosts subagent work).
- Recorded per host in `manual_extension_list_target_state` comment blocks (documentation only, not parsed by any script; no automatism).
- Reference set was the minimal profile's extensions (user: "those are the extensions on the minimal config"); hosts get a deliberate subset.

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

### Skills/prompts GOAL state (decided 2026-07-09, REVISED same day) — supersedes the "minimal + ntfy" goal above

**Lean goal (user): both groups need ONLY: 3 web-search, 14 general-explore, 16 grounded-pairing-discipline, 17 honest-confidence, 18 orwell-6-rule-prose, 19 bootstrap-pairing-memory, 20 criticalthink, 21 short-instruction-semantics, 22 socratic-first-principles, 24 ntfy-phone, 25 check-sanity-before-continue, 26 critical-rethink-sanity = 12 skills.**
Plus prompts **P1, P2, P3, P5, P6, P7** (user: P1–P7 but NOT P4 `done-archived-commit-exact.md`) = 6 prompts:
speak-matter-outcome.md, speak-process-status.md, short-concise-persist-details.md, make-me-understand.md, check-sanity-before-continue.md, critical-rethink-sanity.md
All 12 skills + 6 prompts verified to exist in `definitions/skills/` + `definitions/prompts/` (deploy pre-flight passes).
Group definitions: **inference-cluster** = sparkz, sparky, twins; **pluto** = always-up central place. **No per-group divergence** for skills/prompts (unlike extensions).

TOML deltas vs the (already edited) working-tree tomls:

| host | add to toml | remove from toml |
|---|---|---|
| sparkz | general-explore, honest-confidence, check-sanity-before-continue, critical-rethink-sanity | 22 entries (everything currently in toml except web-search, grounded-pairing-discipline, orwell-6-rule-prose, bootstrap-pairing-memory, criticalthink, short-instruction-semantics, socratic-first-principles, ntfy-phone) |
| sparky | same 4 | 21 entries (same rule) |
| twins | same 4 | 17 entries (same rule) |
| pluto | web-search, general-explore | sub-agent-handoff, sub-agent-herdr-supervisor |

Final toml state (all 4 hosts, identical):
- skills (12): web-search, general-explore, grounded-pairing-discipline, honest-confidence, orwell-6-rule-prose, bootstrap-pairing-memory, criticalthink, short-instruction-semantics, socratic-first-principles, ntfy-phone, check-sanity-before-continue, critical-rethink-sanity
- prompts (6): speak-matter-outcome.md, speak-process-status.md, short-concise-persist-details.md, make-me-understand.md, check-sanity-before-continue.md, critical-rethink-sanity.md

Host-filesystem deltas (what the next deploy must fix, per ✖/🎯 rows in the tables below):
- sparkz: +4 skills · −22 skill dirs (incl. unmanaged drift: agent-browser, criticalthink-retro, doc-rocker-web-search, pi-session-to-md, url2md) · +1 prompt (P5) · −3 prompt files (P4, P8 — P6/P7 stay)
- sparky: +4 skills · −21 skill dirs (incl. agent-browser, doc-rocker-web-search, pi-session-to-md, url2md) · +1 prompt (P5) · −3 prompt files (P4, P8)
- twins: +4 skills · −17 skill dirs · +1 prompt (P5) · −1 prompt file (P4)
- pluto: +2 skills · −2 skill dirs (sub-agent-handoff, sub-agent-herdr-supervisor) · +3 prompts (P1, P2, P5) · −1 prompt file (P4)
- Consequence: `--apply --delete` now removes ~20 skill dirs + P4/P8 prompt files per host — the lean goal makes the one-shot `--delete` pass even more attractive (everything on the hosts outside the 12+6 set is known surplus/drift).

### Skills/prompts CURRENT vs GOAL table (on-host state verified 2026-07-09 via ssh ls; goal = lean set above)

Numbering: 1–26 = lean goal skills (numbering from the earlier minimal-based table kept where it matches: 3, 14, 16–22, 24–26); 27+ = not-in-goal items seen on hosts. P1–P8 = prompts.

| # | skill | in goal? | sparkz (on host) | sparky (on host) | twins (on host) | pluto (on host) | target (inference-cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| 3 | web-search | ✅ | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| 14 | general-explore | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| 16 | grounded-pairing-discipline | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 17 | honest-confidence | ✅ | ⬜ | ⬜ | ⬜ | ✅ | 🎯 | 🎯 |
| 18 | orwell-6-rule-prose | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 19 | bootstrap-pairing-memory | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 20 | criticalthink | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 21 | short-instruction-semantics | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 22 | socratic-first-principles | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 24 | ntfy-phone (host extra) | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 25 | check-sanity-before-continue | ✅ | 📁 | 📁 | 📁 | 📁 | 🎯 | 🎯 |
| 26 | critical-rethink-sanity | ✅ | 📁 | 📁 | 📁 | 📁 | 🎯 | 🎯 |
| 27 | cmux-usage | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 28 | grill-with-docs | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 29 | sub-agent-cmux-supervisor | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 30 | sub-agent-herdr-supervisor | ✖ | ✅ | ✅ | ✅ | ✅ | ✖ | ✖ |
| 31 | sub-agent-handoff | ✖ | ✅ | ✅ | ✅ | ✅ | ✖ | ✖ |
| 32 | codebase-search | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 33 | read-code-structure | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 34 | web-browser-use | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 35 | diagrams | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 36 | gemini-model-rules | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 37 | gemini-model-rules-extreme | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 38 | my-tools-toolbox | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 39 | google-workspace-cli | ✖ | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 40 | openspec-apply-change | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 41 | openspec-propose | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 42 | openspec-explore | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 43 | openspec-archive-change | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 44 | explain-diff-html | ✖ | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| 45 | agent-browser (unmanaged) | ✖ | ✅ | ✅ | ⬜ | ⬜ | ✖ | ✖ |
| 46 | doc-rocker-web-search (unmanaged) | ✖ | ✅ | ✅ | ⬜ | ⬜ | ✖ | ✖ |
| 47 | pi-session-to-md (unmanaged) | ✖ | ✅ | ✅ | ⬜ | ⬜ | ✖ | ✖ |
| 48 | url2md (unmanaged) | ✖ | ✅ | ✅ | ⬜ | ⬜ | ✖ | ✖ |
| 49 | criticalthink-retro (unmanaged) | ✖ | ✅ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |

\* 📁 = present on host as leftover `skills/<name>/` dir (pre-migration artifact); goal state = prompt-only (P6/P7 below are NOT in goal, so the dirs go entirely).

| # | prompt | in goal? | sparkz (on host) | sparky (on host) | twins (on host) | pluto (on host) | target (inference-cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| P1 | speak-matter-outcome.md | ✅ | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| P2 | speak-process-status.md | ✅ | ✅ | ✅ | ✅ | ⬜ | 🎯 | 🎯 |
| P3 | short-concise-persist-details.md | ✅ | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| P4 | done-archived-commit-exact.md | ✖ (user: NOT in goal) | ✅ | ✅ | ✅ | ⬜ | ✖ | ✖ |
| P5 | make-me-understand.md | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| P6 | check-sanity-before-continue.md | ✅ (prompt twin of skill 25) | 📄 | 📄 | 📄 | 📄 | 🎯 | 🎯 |
| P7 | critical-rethink-sanity.md | ✅ (prompt twin of skill 26) | 📄 | 📄 | 📄 | 📄 | 🎯 | 🎯 |
| P8 | start-self-organising.md (unmanaged) | ✖ | 📄 | 📄 | ⬜ | ⬜ | ✖ | ✖ |

Legend: ✅ present on host · ⬜ absent · 📁 leftover skill dir · 📄 file in prompts/ · 🎯 goal: present · ✖ goal: absent. "(unmanaged)" = not referenced by any host toml; only exists on the host filesystem.

Key findings (2026-07-09, verified via ssh `ls` on each host):
- **Hosts are further from goal than the tomls suggested**: sparkz/sparky carry 8–9 unmanaged skills (agent-browser, doc-rocker-web-search, pi-session-to-md, url2md, …) and 2–3 unmanaged prompt files that no toml ever listed. These are local drift from old deploys.
- **check-sanity-before-continue / critical-rethink-sanity** are goal SKILLS (25, 26) AND goal PROMPTS (P6, P7) — both forms ship; they exist on all hosts as `skills/<name>/` dirs today, and the prompt files stay (only P4/P8 removed).
- pluto: 15 goal skills missing + 4 goal prompts missing (matches the pre-deploy toml gap); also carries the two skill-dir leftovers.
- All surplus items are removable via the phase-1 removal strategy (one-off `--delete` pass would clear every ✖ row in one shot, incl. unmanaged drift — since `~/.pi/agent` is fully managed by the deploy).

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

User packages installed under `~/.pi/profiles/minimal/agent/` (numbered 1-10, same numbering as the host table below):

| # | extension | source |
|---|---|---|
| 1 | pi-olla-autodetect | github.com/cgint/pi-olla-autodetect |
| 2 | pi-tool-intent | github.com/cgint/pi-tool-intent |
| 3 | pi-mini-self-org (filtered) | github.com/cgint/pi-mini-self-org |
| 4 | pi-web-access | github.com/nicobailon/pi-web-access |
| 5 | pi-focus-guard | github.com/cgint/pi-focus-guard |
| 6 | pi-smart-compact | github.com/cgint/pi-smart-compact |
| 7 | pi-transcribe | github.com/earendil-works/pi-transcribe |
| 8 | pi-subagent-herdr | github.com/cgint/pi-subagent-herdr |
| 9 | pi-advisor | github.com/cgint/pi-advisor |
| 10 | pi-btw | npm:@nguyenquangthai/pi-btw |

(11-14 exist on hosts but not in the minimal set — see host table below.)

Notes:
- **Not all of these will go to the hosts** (user) — the host extension set is a subset; which ones is an open phase-2 decision. Decision table below (Y/N/?) — user to confirm.

### Extension goal state (decided 2026-07-09) — recorded in each host toml as `manual_extension_list_target_state` (comment-only, not parsed by any script)

Group definitions: **inference-cluster** = sparkz, sparky, twins; **pluto** = always-up central place.

Goal set for BOTH groups (numbering = host table below): **1, 2, 3, 4, 5, 9, 11** (pi-olla-autodetect, pi-tool-intent, pi-mini-self-org, pi-web-access, pi-focus-guard, pi-advisor, pi-self-reflect)
Plus **pluto only**: 8 pi-subagent-herdr (hosts subagent work).

Implied deltas from current state (phase-2 execution list):
- **sparkz**: add 9, 11; remove 12, 13, 14.
- **sparky**: add 9, 11; remove 12.
- **twins**: add 9, 11; remove 12, 6 (pi-smart-compact not in goal).
- **pluto**: add 9 only (already has 1–5, 8, 11; 6 pi-smart-compact not in goal → remove).
- Note: pi-smart-compact (6) dropped from goal for all hosts; pi-web-access variant on pluto (git nicobailon vs npm) acceptable as-is.

Open preconditions for phase-2 execution (unverified):
- **9 pi-advisor** needs a stronger advisor model configured per host — unknown which models the hosts run.
- **3 pi-mini-self-org** is model-filtered on pluto (and minimal) — may be a no-op on hosts whose model filters it.
- **Install/uninstall mechanism** not yet specified (pi package manager syntax per host; npm vs git sources).

Legend: ✅ loaded by `pi list` · ✅(f) loaded but filtered · 📦 in node_modules, not listed · ⬜ not present · 🎯 goal: should be present · ✖ goal: should be absent

| # | extension | what it gives | sparkz | sparky | twins | pluto | target (inference-cluster) | target (pluto) |
|---|---|---|---|---|---|---|---|---|
| 1 | pi-olla-autodetect | auto-discovers ollama models | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 2 | pi-tool-intent | enforces `intent` on read/bash | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 3 | pi-mini-self-org | workpad tools | ✅ | ✅ | ✅ | ✅(f) | 🎯 | 🎯 |
| 4 | pi-web-access (npm) | web fetch/search tools | ✅ | ✅ | ✅ | ✅ (git) | 🎯 | 🎯 |
| 5 | pi-focus-guard | focus/compaction guard | ✅ | ✅ | ✅ | ✅ | 🎯 | 🎯 |
| 6 | pi-smart-compact | compaction | ⬜ | ⬜ | ✅ | ✅ | ✖ | ✖ |
| 7 | pi-transcribe | transcribe_file tool | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 8 | pi-subagent-herdr | subagent_* tools | ⬜ | ⬜ | ⬜ | ✅ | ✖ | 🎯 |
| 9 | pi-advisor | advisor tool (needs strong model) | ⬜ | ⬜ | ⬜ | ⬜ | 🎯 | 🎯 |
| 10 | pi-btw | btw side-comments | ⬜ | ⬜ | ⬜ | ⬜ | ✖ | ✖ |
| 11 | pi-self-reflect (git) | self-reflect tool | ⬜ | ⬜ | ⬜ | ✅ | 🎯 | 🎯 |
| 12 | @capyup/pi-goal (npm) | NOT in minimal set | ✅ | ✅ | ✅(f) | ⬜ | ✖ | ✖ |
| 13 | pi-subagents (npm) | NOT in minimal set | ✅(f) | 📦 | 📦 | ⬜ | ✖ | ✖ |
| 14 | pi-intercom (npm) | NOT in minimal set | ✅(f) | 📦 | 📦 | ⬜ | ✖ | ✖ |

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

## Ordered steps

### Phase 1 — skills (all decisions made, ready to execute)
1. ~~Answer Q1–Q4.~~ **All answered** (deploy tool = `agents_files_cp_remote.sh`; pluto = reference/intended shape; `make-me-understand.md` added; shuttle orphan to be removed).
2. Edit `definitions/hosts/{sparkz,sparky,twins,pluto}.toml` per diff table (add/remove skills + prompts).
3. Fix header comments (all 4): only `tldr` genuinely absent from `definitions/skills/`; fix pluto's "ntfy-phone NOT included" line.
4. Deploy: `agents_files_cp_remote.sh --apply` + removal strategy for lingering skills (one-off `--delete` pass vs hand-rm via ssh — see Decision). Verify on hosts afterwards.
5. Remove orphan `.stage/shuttle/`.
6. Commit `definitions/` changes (host tomls) together with affected `generated/` outputs if any.

### Phase 2 — extensions (goal decided; execution not started)
1. Verify preconditions: per-host model config (unblocks 9 pi-advisor + 3 pi-mini-self-org questions); pi package install/uninstall syntax per host.
2. Apply per-host deltas (see implied deltas above), using each host's own pi binary (see canonical invocation notes).
3. Verify with `pi list` on each host; update this doc + toml comment blocks if reality diverges.

### Later (separate decisions)
- Structural option: derive host tomls from `minimal + {ntfy-phone}` in the generator (drift-proofing).
- Automatism for `manual_extension_list_target_state` (currently explicitly manual).

# PLAN: Mac-only deploy + host profile cleanup

as-of: 2026-11-08 · repo: `~/dev/dev-bin` (main)

## Status

**Implemented and verified (2026-11-08):** host guard in both deploy scripts (TDD red→green); pluto refusal verified live (exit 2, warning, no state change, `--help` works); pluto host cleanup done (4 profile sessions consolidated into `~/.pi/agent/sessions/`, `~/.pi/profiles` removed). Remaining: user-gated purge of `~/.pi-profiles.removed-20261108`. No host besides pluto was affected.

Unrelated pre-existing test failures on pluto (not touched by this change): `tests/md2html.test.sh` (pandoc 3.7 rejects `--syntax-highlighting`), `tests/watchdiff.test.sh` (`state/ready` timeout).

**Recreator identified + fixed (2026-11-08 16:45, attribution corrected):** the 16:25 recreation was NOT the worker launcher — it was the homelab glm-5.3 agent (session "Deploy OpenObserve on pluto", dev-concepts-homelab) **re-provisioning the profile manually**: `mkdir -p ~/.pi/profiles/minimal/agent/extensions && cp ~/.pi/agent/extensions/herdr-agent-state.ts …` at 16:25:06 CET (session log; its own words: "I re-provisioned it minutes ago"; same mkdir+cp created the original at 12:45:58 CET). The pi artifacts (auth.json, models-store.json, tmp extension clones) were then initialized by `pi-profile minimal` invocations (worker retry / model probes) once the extension check passed. The worker path itself only *reads* the path (`[ -f ]` check → exits; creates nothing) and *demands* the minimal profile because `pi-profile` is on PATH (dev-bin) — that demand is what kept triggering re-provisioning. Fix (unchanged, correct): `export PI_WORKER_PROFILE=default` in pluto's `~/.bashrc` → workers resolve to `~/.pi/agent` (extension present), no more missing-extension errors, no re-provisioning trigger. Simulated worker launch passes the extension check. Second recreation renamed away to `~/.pi-profiles.recreated-20261108`.

Residual (upstream pi-subagent-herdr, Mac-only by design): `orca-herdr-pi-start-named-session.sh:248` hardcodes `pi-profile minimal`; `test_worker_launchers.sh` covers profile behavior — hosts must keep pinning `PI_WORKER_PROFILE=default`.

## Diagram

![Deploy flow](./PLAN-mac-only-deploy.svg)

## Goal / success criteria (falsifiable)

1. `agents_files_cp.sh` with `hostname -s` != `MacBook-Pro` → non-zero exit, warning on stderr naming allowed host + detected host + correct alternative; **no state change** (no dirs created, generator not run).
2. Same for `agents_files_cp_remote.sh`.
3. `-h/--help` still works on any host (guard sits after arg parsing).
4. `bash test_agents_files_cp.sh` and the new remote-guard test pass on pluto (hostname injected in tests).
5. Non-Mac hosts: no `~/.pi/profiles`; any profile session jsonl consolidated into `~/.pi/agent/sessions/<project>/`.
6. Quarantine `~/.pi-profiles.removed-20261108` purged (user-gated).

## Evidence (2026-11-08)

- Host TOMLs (pluto/sparky/sparkz/twins) all deploy to `~/.pi/agent` — remote pushes never create `~/.pi/profiles` (`data-dir-agents/definitions/hosts/*.toml`).
- Local `agents_files_cp.sh` deploys pi-agent profiles: default → `~/.pi/agent`; minimal/opsx/partner/zero → `~/.pi/profiles/<name>/agent` (`generated/pi-agent-profiles/*/.target`). Running it on pluto is what created the profiles mess.
- ssh probe: sparky, sparkz, twins have **no** `~/.pi/profiles`. Only pluto was affected.
- Pluto cleanup (done): 4 minimal-profile session jsonl moved to `~/.pi/agent/sessions/{--mnt-server-LOCAL-app-data-litellm-test--,--mnt-server-RAID1-cgint_data-dev-external-pi-subagent-herdr--}` (integrity-checked, no collisions); `~/.pi/profiles` quarantine-moved to `~/.pi-profiles.removed-20261108`.
- Attribution: script predates `~/.pi` sessions (initial snapshot 2026-03-05; earliest session 2026-08-30) — authoring not attributable from `~/.pi`. Pluto rollout: homelab session `glm-5.3-flash-direct` (home-llm) deployed/inspected 11:44–11:57; stray profile sessions were run by `qwen3.8-27b-direct` (home-llm) (model field in the moved files).
- Repo has unrelated dirty files (`md2html`, `README.html`) — untouched.

## Design decisions

- Guard: `hostname -s` must equal `MacBook-Pro` (short name, robust to `.local`/`.lan` suffix changes). Constant `ALLOWED_HOST="MacBook-Pro"`.
- Testability: `AGENTS_FILES_CP_HOSTNAME` env var overrides detection (documented as test injection, not a supported bypass).
- Placement: after argument parsing, before any state change (before `propagate_definitions.py --apply`; before staging/ssh in the remote script).
- Message idiom: `echo "ERROR: ..." >&2` + `exit 2`, matching existing style; usage() help text states "main Mac (MacBook-Pro.local) only".
- Remote script's warning points to itself as the correct tool; local script's warning points to `agents_files_cp_remote.sh --host <host> --apply` from the main Mac.

## Implementation plan

1. TDD red: extend `test_agents_files_cp.sh` with guard tests (injected non-Mac hostname; existing assertions switched to injected `AGENTS_FILES_CP_HOSTNAME=MacBook-Pro`). Add `tests/agents_files_cp_remote-guard.test.sh` (guard-only; refuses before any ssh). ✓ 2026-11-08
2. Implement guard in both scripts. ✓ 2026-11-08
3. Green: both test files pass; `--help` sanity + live refusal on pluto captured. ✓ 2026-11-08
4. Purge `~/.pi-profiles.removed-20261108` (only after user OK). — pending
5. Path-scoped commit: `agents_files_cp.sh`, `agents_files_cp_remote.sh`, `test_agents_files_cp.sh`, `tests/agents_files_cp_remote-guard.test.sh`, `PLAN-mac-only-deploy.{md,d2,svg}`. ✓ 2026-11-08

## Verification plan

- Both test files pass; refusal/acceptance behavior demonstrated with injected hostnames.
- Per-host check `ls -d ~/.pi/profiles` → absent (already verified sparky/sparkz/twins 2026-11-08; pluto locally).
- Moved sessions still load (valid JSONL last lines, present in main store).

## Open questions

- Assumption: profiles stay wanted **on the Mac** (`agents_files_cp.sh` still deploys `~/.pi/profiles/*` there). Dropping them on the Mac too = definitions-level change package (separate).
- Purge timing for the quarantine copy.
- Residual recreators on hosts: any `pi --profile X` run on a host re-creates a profile data dir — out of scope (usage-side).

## pi-profile hardened (2026-11-08 17:00, commit TBD)
pi-profile already refused nonexistent profile dirs (exit 1 before `exec pi`), but the
16:25 event slipped through: the homelab agent pre-created a bare stub
(`mkdir -p ~/.pi/profiles/minimal/agent/extensions`), the plain `-d` check passed, pi
started and initialized the data dir itself (auth.json, models-store.json, tmp/).
Fix: named profiles now require **deployed content** (`agent/AGENTS.md` — every
generated profile ships it) before pi runs; bare stubs are refused with a deploy hint.
`--list`/`--update-all` only show/touch deployed profiles. Verified: starting
`pi-profile <any-name>` can no longer create a profile dir; covered by
`tests/pi-profile-guard.test.sh` (6 cases, TDD red→green).

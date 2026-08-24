# Handoff: remote config deploy for pi-agent profiles

as-of: 2026-08-24 · status: DESIGN (not implemented) · author: partner session (homelab repo)

## Intent
Give this repo a `--remote` / sibling deploy capability so the generated
pi-agent profile bundle can be synced to the 5 homelab hosts (sparky, sparkz,
twins, pluto, shuttle) with md5-verified, merge-only semantics. `distribute-skill.sh`
(lives in the homelab repo at `dev/concepts/homelab/scripts/`) stays the ad-hoc
single-file emergency tool.

## Goal
From `generated/pi-agent-profiles/<profile>/` on this machine, deploy:
- `AGENTS.md`
- `skills/**`
- `prompts/**`

into `host:~/.pi/agent/` for each configured host, with:
- merge semantics (never `--delete` by default)
- dry-run default
- post-sync md5 manifest verification
- per-host `[SKIP]` on ssh failure (non-fatal)
- idempotent re-runs

## Motive
Today this is done by hand via `distribute-skill.sh` (single file at a time,
manual loop). It does not handle multi-file skills (e.g. `cmux-usage` has 8 files)
and has no "what deploys where" source of truth. The generated bundle here is
the canonical source; the remotes are just consumers.

## Rationale for the chosen shape
- **No Ansible** — 5 hosts, single user, rsync is already idempotent. Ansible
  adds a control node that would have to be always-on (pluto is the only
  always-on host; coupling the other 4 to it is a real risk).
- **No Infisical/vault server** — same coupling argument. Secrets are out of
  scope for this slice; SOPS+age may come later (flip criteria: 2nd human user,
  dynamic credentials, audit/rotation need).
- **New sibling script, not `--remote` flag** — remote path has different
  failure modes (ssh reachability, partial transfer, md5 verify, per-host skip)
  and a different default (dry-run vs apply-by-default). Keeping them separate
  keeps `agents_files_cp.sh` (local, apply-by-default) untouched → zero
  regression risk. Drift risk mitigated by only *consuming* `generated/`, never
  re-implementing generation.
- **TOML host configs in THIS repo, at `definitions/hosts/<host>.toml`** —
  keeps deploy inputs versioned alongside the content they ship. Does NOT live
  under `definitions/profiles/` because "profiles" there means personality
  variants *within* one agent (pi-agent's partner/zero/opsx), a different axis
  from host inventory.

## Proposed layout
```
data-dir-agents/
├── definitions/
│   └── hosts/                  ← NEW
│       ├── sparky.toml
│       ├── sparkz.toml
│       ├── twins.toml
│       ├── pluto.toml
│       └── shuttle.toml
├── agents_files_cp.sh          ← existing (local, untouched)
├── agents_files_cp_remote.sh   ← NEW (this handoff covers it)
└── generated/                  ← existing build output (consumed as-is)
```

Each `hosts/<host>.toml` (fields to be finalized):
```toml
host       = "sparky"
target_dir = "~/.pi/agent"
profile    = "default"
ssh_opts   = ["-o", "ConnectTimeout=5", "-o", "BatchMode=yes"]
delete     = false
```

## Hard constraints (violating any of these is a bug)
1. **Merge, never mirror.** `rsync` without `--delete` by default.
   `--delete` is opt-in via TOML `delete = true` or a CLI flag.
2. **Deploy only the bundle** (`AGENTS.md`, `skills/`, `prompts/`). Never
   touch host-local state: `auth.json`, `models.json`, `settings.json`,
   `sessions/`, `npm/`, `tmp/`, `bin/`, `extensions/`, `intercom/`,
   `missions/`, `trust.json`, `run-history.jsonl`, model `.bak` files.
3. **Divergent host files must survive.** `start-self-organising.md` exists on
   sparky/sparkz and is absent from the canonical source. A deploy must leave
   it in place.
4. **Dry-run default.** First run against any host should be `rsync -avhn`.
5. **md5 verification post-sync.** Compare the generated bundle's file hashes
   against what landed on the host; fail loudly on mismatch.

## Open risks to verify before implementing
- **Content drift (BIGGEST).** Local `~/.pi/agent/skills/` (27 dirs) vs
  `definitions/skills/` (27 entries incl. `README.md`) look similar but are
  NOT proven identical. Hand-distributed today (verified md5):
  - `bootstrap-pairing-memory` → `a90c32ed…`
  - `short-instruction-semantics` → `8a04b2f6…`
  - `short-concise-persist-details.md` (prompt) → `dbd2339b…`
  Run `diff -r` (or rsync dry-run) before first real deploy. If the generated
  bundle has drifted, it would silently overwrite what was just hand-verified.
- **`~` expansion in target_dir.** rsync over ssh handles `~` server-side; a
  local `mkdir -p` of a literal `~` does not. The tilde bug in
  `distribute-skill.sh`'s `-T` flag is known and unfixed; don't repeat it here.
- **SOPS/age presence on the 5 hosts is unverified.** Out of scope for this
  slice, but do not plan the secrets step on the assumption it's installed.

## Suggested first steps for the taking-over agent
1. Read `agents_files_cp.sh` + `propagate_definitions.py` (local-only,
   apply-by-default — do not modify).
2. Read `generated/pi-agent-profiles/default/.target` and the bundle tree.
3. Run the read-only drift check:
   `rsync -avhn --exclude-from=<generated bundle exclusions> generated/pi-agent-profiles/default/ sparky:~/.pi/agent/`
   and inspect the output: does merge mode leave `start-self-organising.md`
   alone? Does the layout match what's on the host?
4. Draft `definitions/hosts/*.toml` for all 5 hosts.
5. Implement `agents_files_cp_remote.sh`:
   - parse TOML (use `yq`/`python3 -c 'import tomllib'` if no TOML lib is
     installed on this Mac — check first)
   - per-host: ssh reachability probe (`ssh -o BatchMode=yes host true`),
     skip on failure
   - `rsync -avhzn` first (dry-run), print plan
   - on `--apply` (non-default), `rsync -avhz` + md5 manifest verify
   - summary line per host: `[OK]` / `[SKIP]` / `[FAIL]`
6. Commit in this repo only (`~/.local/bin` is a separate git worktree — check
   `git status` here before committing; do not commit homelab-repo files from
   this directory).

## Stop conditions
- Do NOT `--delete` without an explicit, per-host opt-in.
- Do NOT ship anything beyond `AGENTS.md`, `skills/`, `prompts/`.
- Do NOT modify `agents_files_cp.sh` or `propagate_definitions.py`.
- Do NOT push. Commits are local checkpoints only.

---

## Appendix: critique & open questions from partner session (2026-08-24)

### Findings (read-only inspection, verified)

- **Tooling OK on this Mac.** `python3 -c 'import tomllib'` works (no TOML lib to install).
  rsync is Apple's openrsync 2.6.9 (protocol 29) — all needed flags (`-avhzn`,
  `--exclude`, `--checksum`) present.
- **ssh inventory incomplete.** `~/.ssh/config` has only `twins` and `sparky`
  (bare hostnames). `sparkz`, `pluto`, `shuttle` are absent. The per-host
  `[SKIP]` on ssh failure is therefore load-bearing, not just defensive.
- **Drift check (read-only) — skills are 1:1.**
  `diff <(ls generated/.../default/skills/) <(ls ~/.pi/agent/skills/)` is clean.
  Earlier 27-vs-28 count was a miscount; `colgrep` exists on both sides.
- **Real drift found:** `~/.pi/agent/prompts/speak-most-important-info.md`
  (421 B, 2026-08-06) exists locally but is in neither the generated bundle nor
  `definitions/prompts/`. It survives merge-only deploys (hard constraint #3),
  but is a candidate for promotion into `definitions/` — same class of drift as
  `start-self-organising.md` on sparky/sparkz.

### Critique (objection to the proposed host TOML shape)

`target_dir` is the **wrong axis** for a host file. In `definitions/profiles/`
the same key distinguishes *agent personality variants*
(`~/.pi/agent` vs `~/.pi/profiles/partner/agent/...`). For a host, the deploy
unit is "ship profile X onto host Y", and a host can in principle run several
profiles. A host TOML carrying both `profile` and `target_dir` is redundant and
can silently diverge (profile renamed on the Mac, host TOML not updated).

**Proposed host TOML:**

```toml
host   = "sparky"
profile = "default"   # which generated/pi-agent-profiles/<profile>/ to ship
delete = false
ssh_opts = ["-o", "ConnectTimeout=5", "-o", "BatchMode=yes"]
# optional, explicit override only:
target_dir = ""        # empty = derive from bundle .target (recommended)
```

Target dir **derived from `generated/pi-agent-profiles/<profile>/.target`**
— the existing single source of truth. The deploy script then has no
`~`-expansion logic at all (rsync expands `~` server-side), which kills the
known `distribute-skill.sh` tilde bug by construction.

### Open questions — RESOLVED (2026-08-24)

### Q1: Schema — `target_dir` in host TOML?
**Decision: No.** `target_dir` is **derived from** `generated/pi-agent-profiles/<profile>/.target`.
Host TOMLs carry only: `host`, `profile`, `delete`, `ssh_opts`.
Rationale: single source of truth (the `.target` file), kills the known tilde
expansion bug by construction (rsync expands `~` server-side; the script never
builds or `mkdir -p` the path locally). An optional `target_dir` override can
be added later if a host genuinely needs a non-standard layout (YAGNI for v1).

### Q2: Regenerate or consume `generated/`?
**Decision: Strictly consume.** The deploy script reads `generated/` as-is.
Rationale: mixing regeneration into the remote path adds a hidden side-effect
(a broken generator could ship a half-baked bundle to 5 hosts). The operator
builds locally first (`propagate_definitions.py --apply`), then deploys.
The deploy script should **fail loudly** if `generated/` is missing, and
**warn** if `definitions/` has a newer mtime than `generated/` (stale build).

### Q3: Which profile per host?
**Decision: `default` for all 5 hosts** (sparky, sparkz, twins, pluto, shuttle).
Rationale: no remote has `~/.pi/profiles/`; they all run the global
`~/.pi/agent/` layout, which is exactly `default`'s `.target`. Content
parity confirmed 1:1 for skills. If a host later gets its own personality
variant, the TOML `profile` field is the extension point.

### Q4: `speak-most-important-info.md` — promote or preserve?
**Decision: Promote into `definitions/prompts/`.**
Rationale: it's a prompt (curated content), has been in active use since
2026-08-06, and leaving it local-only means every new host needs a manual
`distribute-skill.sh` call — the exact problem this tool eliminates.
Action: `cp ~/.pi/agent/prompts/speak-most-important-info.md` into
`definitions/prompts/`, regenerate, commit. Until then, merge-only deploys
protect it on hosts where it already exists.

---

### VERDICT: ALL CLEAR — design approved for implementation (2026-08-24)

All open risks verified read-only. No remaining design objections.

**Verified:**
- All 5 hosts reachable, have `~/.pi/agent`, `md5sum`, rsync ≥ 3.2.7
- Merge semantics: `start-self-organising.md` preserved (not in transfer)
- `.target` excluded from transfer
- Transfer scope: 77 files, no host-local state
- Local openrsync supports `-n/--dry-run`

**Implementation notes (not blockers, resolve during coding):**
1. `ssh_opts` must thread into rsync via `-e "ssh ${ssh_opts[*]}"`, not just
   the preflight probe. Otherwise dry-run and apply use default ssh settings.
2. **Exit-code contract** (state in script header): 0 = all attempted hosts
   verified (skips reported and counted); non-zero only on verify/transfer
   failure for at least one attempted host.
3. **Remote dir creation:** rsync creates the final dir but not missing
   parents. Add an idempotent `ssh host 'mkdir -p ~/.pi/agent/skills ~/.pi/agent/prompts'`
   preflight before rsync. Keep `~` unquoted so the remote shell expands it.
4. **md5 tool:** use `md5sum` on all hosts (confirmed present). Generate
   manifest as `path:hash` (relative to target dir), sort by path, compare
   against local `find` + `md5 -r` (macOS) — normalize path format on both
   sides to avoid false mismatches.
5. **Staleness check (Q2):** compare newest mtime in `definitions/` vs
   `generated/`; warn if `definitions/` is newer. One-liner, optional.
6. **Q4 promotion** (`speak-most-important-info.md` → `definitions/prompts/`)
   is a separate content-change slice; do it before the first remote deploy so
   the bundle is complete. Requires `definitions/` + `generated/` committed
   together per repo AGENTS.md.

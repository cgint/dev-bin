# HANDOFF: remote config deploy for pi-agent profiles

> **STATUS: TOOLING SHIPPED + DRY-RUN VERIFIED (2026-08-24).** `agents_files_cp_remote.sh`
> is implemented, parses under system bash 3.2, and dry-runs cleanly against all 5 hosts.
> Self-contained host TOMLs (no profile reference). Real `--apply` deploy not yet run.
> See "Appendix: final state" at the bottom for the as-shipped design.

Original handoff below (kept for the verified inventory/constraints — still accurate).

---

## Goal
Build a **remote deploy** capability for pi-agent profiles: a sibling script
`agents_files_cp_remote.sh` that ships the generated agent bundle to **5 homelab hosts**
(sparky, sparkz, twins, pluto, shuttle) at `~/.pi/agent/`, with:

- **Merge-only by default** (never delete host-local files)
- **Dry-run first** (`rsync -n`), apply is opt-in
- **md5 verification** after each transfer
- **Per-host `[SKIP]`** on ssh failure (some hosts are offline; don't fail the whole run)
- **Idempotent** (re-runnable, no state drift)

The local sibling is `agents_files_cp.sh` (apply-by-default, single target). The remote
script is the new piece.

## How the existing pieces fit

```
data-dir-agents/
├── definitions/                    ← SOURCE (you edit these)
│   ├── agents/                     # AGENTS templates + blocks
│   ├── skills/<name>/SKILL.md      # skill sources
│   ├── prompts/*.md                # prompt sources
│   ├── profiles/pi-agent/*.toml    # local profile specs (default, minimal, opsx, partner, zero)
│   ├── blocks/                     # shared md blocks
│   └── hosts/                      ← NEW: remote host specs (one .toml per host)
│       ├── sparky.toml
│       ├── sparkz.toml
│       ├── twins.toml
│       ├── pluto.toml
│       └── shuttle.toml
├── agents_files_cp.sh          ← existing (local, untouched)
├── propagate_definitions.py    ← generator; remote script imports its resolve_placeholders
└── generated/                  ← existing build output (local profiles only; NOT consumed by remote deploy)
```

`~/.local/bin/` (repo root, PATH):
```text
├── agents_files_cp.sh          ← local deploy tool
└── agents_files_cp_remote.sh   ← NEW: remote deploy tool (this handoff covers it)
```

Each `hosts/<host>.toml` (as shipped, self-contained):
```toml
host        = "sparky"
target_dir  = "~/.pi/agent"
agents_file = "AGENTS_GPT52.md"
skills      = [ ... explicit whitelist ... ]
prompts     = [ ... explicit whitelist ... ]
delete      = false
ssh_opts    = [ "-o", "ConnectTimeout=5", "-o", "BatchMode=yes" ]
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
5. **md5 verification post-sync.** Compare the staged bundle's file hashes
   against what landed on the host; fail loudly on mismatch.

## Open risks to verify before implementing
- **Content drift (BIGGEST).** Local `~/.pi/agent/skills/` (27 dirs) vs
  `definitions/skills/` (27 entries incl. `README.md`) look similar but are
  NOT proven identical. Hand-distributed today (verified md5):
  - `bootstrap-pairing-memory` → `a90c32ed…`
  - `short-instruction-semantics` → `8a04b2f6…`
  - `short-concise-persist-details.md` (prompt) → `dbd2339b…`
  Run `diff -r` (or rsync dry-run) before first real deploy. If the source
  has drifted, it would silently overwrite what was just hand-verified.
- **`~` expansion in target_dir.** rsync over ssh handles `~` server-side; a
  local `mkdir -p` of a literal `~` does not. The tilde bug in
  `distribute-skill.sh`'s `-T` flag is known and unfixed; don't repeat it here.

## Suggested first steps for the taking-over agent
1. Read `agents_files_cp.sh` + `propagate_definitions.py` (local-only,
   apply-by-default — do not modify).
2. Read the bundle tree (`~/.pi/agent/`) to know what "the bundle" is.
3. Run the read-only drift check:
   `rsync -avhn --exclude-from=<exclusions> <source bundle>/ sparky:~/.pi/agent/`
   and inspect the output: does merge mode leave `start-self-organising.md`
   alone? Does the layout match what's on the host?
4. Draft `definitions/hosts/*.toml` for all 5 hosts.
5. Implement `agents_files_cp_remote.sh`:
   - parse TOML (use `python3 -c 'import tomllib'` — no TOML lib needed)
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
- **AGENTS.md variants on hosts:** sparky/sparkz run an older AGENTS.md variant
  (`602c1279`); twins/pluto/shuttle have no AGENTS.md yet. The deploy will
  converge all 5 to the freshly rendered template.

### Open questions — RESOLVED (2026-08-24)

### Q1: Schema — `target_dir` in host TOML?
**Decision: Yes, explicit per host.** The remote deploy is fully independent
from the local profile system, so there is no `.target` file to derive from.
`target_dir = "~/.pi/agent"` is written in each host TOML; the script never
builds the path locally and never `mkdir -p` — rsync and the remote shell
expand `~` server-side, which kills the known `distribute-skill.sh` tilde bug
by construction. The script fails loud on `target_dir` containing whitespace
(it is interpolated unquoted in the remote check).

### Q2: Regenerate or consume `generated/`?
**Decision: Assemble from `definitions/` at deploy time — consume neither.**
The remote bundle is built fresh from `definitions/` (the single source of
truth) every run: `AGENTS.md` is rendered via `propagate_definitions.
resolve_placeholders` (imported from the existing generator, not re-implemented),
and whitelisted skills/prompts are copied 1:1 into a gitignored `.stage/<host>/`
before a single rsync. No staleness check needed (no `generated/` involved).

### Q3: Which profile per host? — SUPERSEDED by Q5
~~`default` for all 5 hosts~~

### Q5: Self-contained host TOMLs, fully independent from profiles (final, 2026-08-24)

**Decision: No `profile =` reference at all. Host TOMLs are self-contained deploy specs.**

History: an intermediate design added a `homelab` profile (partner's list +
`ntfy-phone`) and pointed all 5 host TOMLs at it. Rejected: a profile is a
*local-deployable* unit, and `homelab.toml` targeting `~/.pi/agent` collides
with `default` on this Mac. Remote hosts are not local agents — they don't
need a profile at all.

Final shape of `definitions/hosts/<host>.toml`:
```toml
host        = "sparky"
target_dir  = "~/.pi/agent"      # explicit per host; rsync/remote shell expand ~
agents_file = "AGENTS_GPT52.md"  # template in definitions/agents/ (rendered at deploy)
skills      = [ ... 24 partner skills, + "ntfy-phone" for sparky/sparkz/twins ... ]
prompts     = [ ... 6 partner prompts ... ]
delete      = false              # per-host rsync --delete opt-in (DANGEROUS)
ssh_opts    = [ "-o", "ConnectTimeout=5", "-o", "BatchMode=yes" ]
```

Consequences (all implemented):
- `homelab` profile deleted (`definitions/profiles/pi-agent/homelab.toml` +
  `generated/pi-agent-profiles/homelab/`); generator re-run, local profiles
  back to the original 5 (default, minimal, opsx, partner, zero).
- `agents_files_cp_remote.sh` (at repo root, sibling of `agents_files_cp.sh`) assembles the bundle **from `definitions/`
  sources**: renders `AGENTS.md` via `propagate_definitions.resolve_placeholders`
  (imported, not re-implemented), copies whitelisted skills/prompts into
  `.stage/<host>/` (gitignored), one rsync, md5 post-verify on `--apply`.
  Dry-run default; merge-only unless `--delete`/`delete = true`.
- The 5 host TOMLs are near-identical; only the host name and `ntfy-phone`
  presence differ. Duplication is intentional: "what does sparky get?" must be
  answerable from one file.
- `ntfy-phone` ships to sparky/sparkz/twins only (not pluto/shuttle, not local
  agents yet).
- Bash 3.2 notes: system bash is 3.2.57; the script avoids `mapfile` and
  top-level `local`, uses `while read` + process substitution; `.stage/` is in
  the root `.gitignore`.

### Q4: `speak-most-important-info.md` — promote or preserve?
**Decision: Promote into `definitions/prompts/`.**
Rationale: it's a prompt (curated content), has been in active use since
2026-08-06, and leaving it local-only means every new host needs a manual
`distribute-skill.sh` call — the exact problem this tool eliminates.
Status: DONE — committed in `a0cc8fd` (with regenerated copies).

---

## Appendix: final state (2026-08-24, as shipped)

**Commits** (local, unpushed — push requires explicit user opt-in):
- `a0cc8fd` — content slice: `speak-most-important-info.md` promoted (Q4)
- `f5171df` — tooling slice v1: original remote script + 5 host TOMLs (profile-referencing)
- `15b72cf` — `ntfy-phone` recovered from sparky into `definitions/skills/`
- `8fbf35c` — intermediate: `homelab` profile + host TOMLs pointing at it (now superseded)
- PENDING — final slice: self-contained host TOMLs, homelab profile removed,
  rewritten lean script (bash 3.2-safe), `.stage/` gitignore, this handoff update

**Verified this session:**
- `bash -n` passes under system bash 3.2.57 (the earlier "unmatched quote" was a
  file-mutation race — the working copy on disk had diverged from what was being
  read; rewriting the file from a clean verified copy resolved it. No bash-3.2
  syntax quirk; the heredoc-in-if and `&>` constructs are fine.)
- Dry-run (`rsync -n`) against all 5 real hosts: `[DRY-RUN]` on every host,
  summary `5 ok, 0 skipped, 0 failed`. ntfy-phone staged only for
  sparky/sparkz/twins (verified in `.stage/`).
- `pytest test_propagate_definitions.py`: 25/25 green.

**Exit-code contract:** 0 = all attempted hosts OK (skips non-fatal);
1 = transfer/verify failure on ≥1 host.

**Known limitations / watch-outs:**
- Local openrsync 2.6.9 vs remote rsync 3.2.7/3.4.1: dry-run plan output is
  from the local client; verify with `--apply` + md5 for ground truth.
- `ntfy-phone/SKILL.md` still contains sparky-specific hardcodes (server/topic
  are env-parameterized via `PI_NTFY_SERVER`/`PI_NTFY_TOPIC`); before wider
  rollout consider making it host-agnostic.
- Sparky remote-only skills (`agent-browser`, `criticalthink-retro`,
  `doc-rocker-web-search`, `pi-session-to-md`, `url2md`, `ntfy-phone`) are
  protected by merge-only mode, but `--delete` would remove them — hence
  `delete = false` everywhere and `--delete` behind a dangerous flag.
- First real deploy: run `agents_files_cp_remote.sh --apply` (from `~/.local/bin/`) and watch the
  `[OK]` md5-verified lines; nothing else changes on hosts (merge semantics).

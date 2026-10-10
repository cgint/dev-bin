# Extension management on homelab hosts (phase 2)

How to install/remove/verify pi extensions on the 4 hosts. Companion to
`TODO-hosts-align-minimal.md` (goal state = its Extensions table).
Verified 2026-07-09 against pi 1.1.0 (local + pluto, same version).

## Source of truth

- **Goal**: `TODO-hosts-align-minimal.md` → Extensions table (the 🎯 columns).
- **State**: each host toml's `manual_extension_list_target_state` comment block
  (documentation only — no script parses it).
- **Live registry**: `<agent_dir>/settings.json` → `packages` array. This is what
  pi actually uses; git/ and npm/ dirs are cache.

## Agent dir per host

- All 4 hosts: `~/.pi/agent/` (no profile layer on hosts; pluto confirmed `~/.pi/profiles/` empty).

## Per-host pi binary (canonical invocation) — as of 2026-07-09

| host | command |
|---|---|
| sparkz | `export PATH=$HOME/.nvm/versions/node/v22.22.2/bin:$PATH; pi …` |
| sparky | `export PATH=$HOME/.nvm/versions/node/v22.22.2/bin:$PATH; pi …` |
| twins | `export PATH=$HOME/.local/share/pi-node/current/bin:$HOME/.local/share/pi-node/node-v22.22.2-linux-x64/bin:$PATH; $HOME/.local/share/pi-node/current/bin/pi …` |
| pluto | `/home/cgint/.local/bin/pi …` |

Never call a host's pi from another host's install — lists differ.

**Availability: only pluto is up 24/7.** sparkz/sparky/twins are inference machines and may be
off or unreachable — that is normal, not a fault. If unreachable, note `[UNREACHABLE <date>]`
and retry later (pluto can always be verified).

## Commands (global scope, no -l)

```
pi list                  # installed packages + status (✅ loaded / ✅(f) filtered / 📦 not listed)
pi install <source>      # install
pi remove <source>       # remove (alias: pi uninstall)
pi update [source]       # update package or pi itself
pi config                # interactive TUI: enable/disable individual resources of a package
```

**Non-interactive (verified pluto 2026-07-09, pi 1.1.0):**
`pi install <source> --no-approve` — "ignore project-local files"; no trust prompt appears
for remote git/npm sources over ssh. `pi remove <source>` is also non-interactive. Safe to run
unattended. (The `--approve`/`--no-approve` flags only affect *project-local* `.pi/settings.json` trust.)

There is NO `pi package` / `pi extension` subcommand — the verbs hang directly off `pi`.

Source formats:
```
pi install git:github.com/user/repo
pi install https://github.com/user/repo
pi install npm:@scope/pkg
pi install ./local/path
```

## Gathering host state (recon commands)

**Preferred: `definitions/hosts/host_state.sh <host>`** — one script, prints a
fully-timestamped state block (pi version, skills, prompts, `pi list`, live registry,
model config, loose extensions). Read-only; safe to run repeatedly; `[UNREACHABLE]`
markers per section if a host is down.

Manual equivalents (per host, with the host's own pi):

```bash
H=pluto   # swap per host; PI='<canonical pi invocation>'

# 1. installed packages + status (goal comparison)
ssh -o ConnectTimeout=5 -o BatchMode=yes $H "$PI list"

# 2. live registry (source of truth)
ssh -o ConnectTimeout=5 -o BatchMode=yes $H "python3 -c \"import json;d=json.load(open('/home/cgint/.pi/agent/settings.json'));print(json.dumps(d.get('packages',[]),indent=1))\""

# 3. model config (provider/default model, thinking)
ssh -o ConnectTimeout=5 -o BatchMode=yes $H "grep -E 'defaultProvider|defaultModel|thinking' /home/cgint/.pi/agent/settings.json"

# 4. pi version
ssh -o ConnectTimeout=5 -o BatchMode=yes $H "$PI --version"

# 5. loose (untracked) extensions
ssh -o ConnectTimeout=5 -o BatchMode=yes $H "ls ~/.pi/agent/extensions/ 2>/dev/null"
```

(On sparkz/sparky/twins the settings path is also `~/.pi/agent/settings.json`; expand `~`
or use the absolute `/home/cgint/…` path.) Record each observation with its date in the
timestamped sections above.

## Install layout (what lands where)

- git packages → `~/.pi/agent/git/<domain>/<org>/<repo>/`
- npm packages → `~/.pi/agent/npm/node_modules/<pkg>/` (+ `npm/package.json` manifest)
- registry entry → `packages` array in `~/.pi/agent/settings.json`
  (string, or `{"source": …, "extensions": ["+index.ts"]}` for resource filtering)
- loose extensions (not in packages) → `~/.pi/agent/extensions/*.ts` — hand-managed,
  NOT touched by pi install/remove.

## Removal

Prefer `pi remove <source>`. Manual fallback (if pi CLI misbehaves remotely):
1. delete the entry from the `packages` array in `settings.json`
2. `rm -rf ~/.pi/agent/git/<domain>/<org>/<repo>` (git) or uninstall via npm (npm)

The packages array in settings.json is the source of truth; the dirs are cache.

## Per-host model (affects filtering + advisor) — host state as of 2026-07-09, re-verify before acting

| host | provider | model |
|---|---|---|
| sparkz | openai-codex | gpt-5.6-terra |
| sparky | olla | qwen3.8-27b-nvfp4-dflash2-direct |
| twins | openai-codex | gpt-5.6-terra (thinking off) |
| pluto | none configured | pi built-in default (enabledModels pins qwen3.8-27b + qwen38-flashnext-twins) |

Consequences:
- **ext 3 pi-mini-self-org** is model-filtered on pluto — expected, not a fault.
- **ext 9 pi-advisor** needs a strong model per host; sparks run codex/olla —
  check the advisor package's model config before installing, else it no-ops.

## Loose extensions on pluto (hand-managed, NOT in packages registry) — as of 2026-07-09

- `~/.pi/agent/extensions/herdr-agent-state.ts` — **required on pluto** (part of the herdr setup, ext 8). Never remove.
- `~/.pi/agent/extensions/advisor.ts` — **superseded**: advisor functionality is replaced by the pi-advisor package (ext 9). Candidate for removal once ext 9 is installed and verified on pluto (confirm with user before removing).

These files are invisible to `pi list` and to `pi install/remove` — they are only managed by hand.

## Verification

Host-derived facts in this doc are **snapshots, not live state** — every section that
quotes host reality (model table, pi version, layouts, current package sets) carries its
observation date. Re-verify the relevant section before acting on it; update the date
when you re-observe.

After each change:
1. `pi list` on the host (its own binary) → compare vs the goal row in the md.
2. `grep -A20 '"packages"' ~/.pi/agent/settings.json` → registry matches goal.
3. Update `TODO-hosts-align-minimal.md` current-columns + toml comment block if
   reality diverges from goal.

## Safety

- One host at a time; never batch-install across hosts.
- pluto is the always-up central place — do it last.
- `pi remove` only the exact source listed in settings.json (source strings must match).
- No `--delete`-style whole-dir sweeps of `~/.pi/agent` — only the skills/prompts
  deploy script may manage those subdirs (see agents_files_cp_remote.sh).

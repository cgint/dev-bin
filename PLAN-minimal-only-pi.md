# Plan: MINIMAL becomes the default and only pi

Status: plan only — not executed. Written 2026-07-11 after investigation + critical re-think.

## The picture in one view

### Current state

```
                    pi-profile  (bash wrapper)
                    "just sets an env var"
                          │
     ┌────────────────────┼────────────────────────────────┐
     │                    │                                │
     ▼                    ▼                                ▼
 ~/.pi/agent/    ~/.pi/profiles/minimal/          ~/.pi/profiles/{opsx,partner,zero}/
 "default"         "minimal"                        the rest (1.4G partner, 6M zero, 180K opsx)
 ┌──────────┐     ┌──────────┐                     ┌──────────┐
│ GPT52    │     │ Core val.│                     │ various  │
│ AGENTS.md│     │ AGENTS.md│                     │ prompts  │
│ 28 models│     │ 12 models│                     │          │
│ 35 skills│     │ 26 skills│                     │          │
│ gemini   │     │ codex    │                     │          │
│ thinking off│   │ thinking med│                  │          │
│ 120 sess.│     │ 179 sess.│                     │          │
└──────────┘     └──────────┘                     └──────────┘
     ▲                    ▲
     │                    │
     └── agents_files_cp.sh deploys from ──┐
          data-dir-agents/definitions/     │
          profiles/pi-agent/*.toml (5 TOMLs)
          ─────────────────────────────────┘
```

- You launch pi via `pi` (default) or `pi-profile minimal` (→ env-var switch → minimal dir).
- 11 zsh aliases (`pim`, `pims`, `pimsr`, `pipa`, ...) all route through `pi-profile`.
- **Two parallel sources of truth**: what's in the TOML files (the "intended" skill set) vs. what's actually on disk (which drifts — e.g. `firstmate` is deployed to default but not listed in `default.toml`'s explicit list; `colgrep`, `cmux-usage`, etc. exist only on disk).

### Target state (diff)

```
                         pi
                           │
                           ▼
                    ~/.pi/agent/   (THE only dir)
                    ┌────────────────────────────┐
                    │ minimal's AGENTS.md        │
                    │ minimal's settings.json    │
                    │ minimal's 12 models        │
                    │ final skill set (decided)  │
                    │ 120+179 sessions (merged)  │
                    └────────────────────────────┘
```

| | before | after |
|---|---|---|
| config dirs | 5 (default + 4 profiles) | 1 |
| launch wrappers | `pi-profile` + 11 aliases | plain `pi` + 2–3 aliases |
| TOML files | 5 | 1 (minimal, pointing at `~/.pi/agent`) |
| AGENTS.md | "Core intent" (GPT52) | "Core values" (minimal) |
| default model | gemini-3.5-flash, thinking off | gpt-5.5, thinking medium |
| skills | 35 (default's) | ~26 (minimal's) ± your keep-list |
| `~/.pi/profiles/` | 3.2G, 4 profiles | **gone** |
| `pi-profile` | exists | **gone** |

### What is important to know before making changes

1. **The TOML is the gatekeeper, not the deploy script.**
   `agents_files_cp.sh` doesn't just copy — it *prunes*. Every deploy run syncs the TOML's `skills` list onto disk with delete-semantics. So:
   - a skill you want to keep **but isn't in the TOML** → gets deleted on next deploy
   - the "manual copy" step is redundant; **the TOML list IS the final skill set**

2. **Two secrets that could silently die**
   - `partner/agent/auth.json` — its own copy of provider logins. May hold OAuth tokens default doesn't have. Must be diffed (per-provider, newer-wins) before deletion, not blindly merged.
   - `zero/agent/auth.json` — same story, smaller.

3. **The aliases that will break hardest**
   `pims`, `pimsr`, `pimsrlm` append `~/.pi/profiles/minimal/agent/AGENTS.md` as a system-prompt flag. After `~/.pi/profiles` is deleted, **these aliases fail at pi startup** (file not found) — not at runtime, at launch. So the alias rewrite must land *before* the directory deletion, not after.

4. **One content delta that's easy to miss**
   Default and minimal both list `pi-web-access`, but from **different sources** (`npm:pi-web-access` vs `https://github.com/nicobailon/pi-web-access`). Overwriting settings with minimal's silently switches the package source — next `pi update --all` re-fetches from GitHub. Fine if that's what you want; just know it's a side effect, not neutral.

5. **The migration is content-merge, not just file-moves.**
   "Make minimal the default" ≠ "copy minimal's files over default." It means *default's richer footprint (28 models, 35 skills, gemini defaults) gets actively pruned down to minimal's curated shape*. That's a decision, not a mechanical step — and it's where most of the real choice lives (which 9 default-only skills survive? which 16 models get dropped?)

## Goal

Get completely rid of `pi-profile` and all profiles under `~/.pi/profiles/`, so that
`~/.pi/agent` **is** the minimal configuration — one `pi`, no indirection, no wrapper.

## Current state (investigated)

```
~/.pi/
├── agent/                     "default" profile: 120 sessions, AGENTS_GPT52-based prompt,
│                              gemini-3.5-flash default, thinking off, 28 models, 35 skills
└── profiles/
    ├── minimal/agent/         1.7G, 179 sessions, "Core values" AGENTS.md,
    │                          codex/gpt-5.5, thinking medium, 12 curated models, 26 skills
    ├── partner/agent/         1.4G, own auth.json, AGENTS_PARTNER.md, firstmate, herdr supervisor
    ├── opsx/agent/            180K, openspec-focused subset
    └── zero/agent/            6M, bare (no skills), own auth.json

~/.local/bin/pi-profile        wrapper: exports PI_CODING_AGENT_DIR=~/.pi/profiles/$NAME/agent, exec pi
~/.zshrc:27-33,56-57           11 aliases (pipa/pimas/pims/pimsg/pimsr/piparlm/pimsrlm/...) → pi-profile
data-dir-agents/definitions/profiles/pi-agent/*.toml   5 TOMLs: default, minimal, opsx, partner, zero
agents_files_cp.sh:230-247     deploys each pi-agent TOML to its target_dir
```

Key facts:
- `pi-profile` is only an env-var switch. Removing it = making `~/.pi/agent` the single config dir.
- minimal ≠ default in **content**: different AGENTS.md, settings.json, skill set, model list.
- The TOML pipeline is shared with copilot profiles — only the pi-agent side is touched.
- `pims`/`pimsr`/`pimsrlm` append `~/.pi/profiles/minimal/agent/AGENTS.md` as system prompt.
  After `~/.pi/profiles` is deleted, these aliases **break hard** (pi fails to start).

## Decisions to make before executing

1. **Skills**: which of default's extra skills survive? Default-only: `firstmate`,
   `grill-with-docs`, `python-uv-discipline`, `cmux-usage`, `ntfy-phone`,
   `sub-agent-cmux-supervisor`, `sub-agent-herdr-supervisor`, `skill-architect`, `colgrep`.
   (Hypothesis, unverified: some are auto-injected by extensions in `packages`, e.g. herdr.
   Verify by checking extension source before pruning.)
2. **Models**: adopt minimal's 12-model `enabledModels` (drops default's 28)?
   Minimal's list references `home-llm/*` and `tensorfold-local/*` providers — verify they
   resolve in `~/.pi/agent/models.json` before committing.
3. **Partner**: its `auth.json` may hold unique provider logins. Diff against
   `~/.pi/agent/auth.json` before deleting. 1.4G of sessions: archive or discard?
4. **Aliases**: replace, don't just delete (see Phase 3 block below).

## Phase 1 — Content merge (the real work)

1. **Backup**: `tar -czf ~/backups/pi-pre-minimal-only-<date>.tar.gz ~/.pi/agent ~/.pi/profiles` (~3.2G).
2. Overwrite `~/.pi/agent/AGENTS.md` ← minimal's AGENTS.md ("Core values" version).
3. Overwrite `~/.pi/agent/settings.json` ← minimal's settings.json. Before overwriting:
   - decide whether to keep `allowedCommands` (["agent-browser"]) and `consortium` blocks from current default;
   - diff `enabledModels` against provider IDs in `~/.pi/agent/models.json`.
4. **Skills**: produce explicit keep/prune list (Decision 1), then
   `rsync -a --delete` the surviving set into `~/.pi/agent/skills/` (marker-guarded, as the deploy script does).
5. **Prompts**: `cp -n` missing prompt files from minimal into `~/.pi/agent/prompts/`.
6. **Verify**: start `pi` (bare), check loaded skills, model, prompt; run one cheap task.

## Phase 2 — Source tree (data-dir-agents)

1. Delete `definitions/profiles/pi-agent/{opsx,partner,zero,default}.toml`.
2. Edit `minimal.toml`: `target_dir = "~/.pi/agent"`; align `skills` list with the Phase 1 keep/prune decision.
3. `agents_files_cp.sh`: the pi-agent-profiles deploy block (lines ~230–247) now handles the
   single profile via the same path — keep it (uniform pipeline) or inline minimal into the
   main pi-agent deploy section and delete the block. Recommendation: keep the block.
4. Regenerate `generated/` and run `agents_files_cp.sh`; verify `~/.pi/agent` content is unchanged
   (idempotent run).
5. **Commit both** `definitions/...` and `generated/...` together (repo rule).

## Phase 3 — Kill pi-profile

1. Delete `~/.local/bin/pi-profile`.
2. Replace the 11 aliases in `~/.zshrc` (lines 27–33, 56–57) with the minimal set:

```zsh
# was: pipa/piparlm  (partner profile) — partner removed; pick replacement or delete
# alias pipa="pi-profile partner"
# alias pipas="pi-profile partner --append-system-prompt ..."
# alias pipasr="pi-profile partner --dm-read ..."
# alias piparlm="pi-profile partner --rlm -e ..."

# was: pims* (minimal profile) — AGENTS.md is now built-in; drop --append-system-prompt
alias pi="pi"                      # or just use pi directly; alias optional
alias pimsr="pi --dm-read"
alias pimsrlm="pi --dm-read --rlm -e ~/dev-external/pi-rlm/src/extension/index.ts"
# alias pimsg — needs decision: drop or re-point
```

3. Grep notes/scripts/dotfiles for remaining `pi-profile` references; update.
4. Note: `pi-profile --update-all` capability is gone — `pi update --all` now covers the single dir.

## Phase 4 — Delete profiles

1. If partner's `auth.json` has unique entries (Decision 3), merge them into `~/.pi/agent/auth.json` first.
2. Optionally archive partner sessions: `tar -czf ~/backups/pi-partner-sessions-<date>.tar.gz ~/.pi/profiles/partner/agent/sessions`.
3. `rm -rf ~/.pi/profiles`
4. **Verify**: `pi` starts clean; no alias references dead paths; `agents_files_cp.sh` runs green.

## Risks / open questions

- **Broken aliases** (highest risk): any surviving `pims` variant that appends
  `~/.pi/profiles/minimal/agent/AGENTS.md` will fail to start pi after Phase 4.
  Phase 3 step 2 must be complete before Phase 4.
- **Partner auth loss**: unverified whether partner's `auth.json` adds providers. Diff first.
- **`firstmate` provenance**: assumed extension-injected; verify or add to TOML skill list.
- **Model catalog drift**: minimal's `enabledModels` vs default's `models.json` — dead entries
  are cosmetic, but a missing provider means the model can't be selected.
- **Scope discipline**: copilot profiles, `~/.codex`, and other agent definitions are untouched.

## Out of scope

- Copilot profiles (shared TOML tooling, different target tree).
- pi version/extension updates.
- Reorganizing `~/.pi/agent/sessions` (120 sessions stay as-is).

# Migrate a Mac off `pi-profile` (sessions-only)

**Goal:** Retire `~/.pi/profiles/*` so plain `pi` runs from `~/.pi/agent`. The existing `~/.pi/agent` config (`settings.json`, `models.json`, `auth.json`, extensions, packages) stays as is. Only the **sessions** of all profiles are merged in, with fork links remapped. `AGENTS.md`, skills and prompts come from `agents_files_cp.sh`.

Done on: second Mac (`christian.gintenreiter-smec`, 2026-11-24: 2385 sessions, 39 forks remapped). The main Mac was migrated earlier with the copy-minimal-over procedure (see git history, `9726f7d`).

## Diagram

![Pi profile removal flow](./MIGRATION-remove-pi-profiles.svg)

## Gotchas

- **Pi must be fully stopped.** Herdr and Herdr Core keep `pi` running in the background (`herdr session list`, `hc ls` / `hc kill <t>`). `pgrep -x pi` empty is the gate; the script re-checks it right before swapping.
- **Run the migration from a non-Pi shell or agent.** A Pi session would be migrating itself.
- **Fork links are absolute paths.** Never `cp -r` sessions; `merge_pi_history.py` rewrites `parentSession` headers.
- **9 skills from the old default profile** are no longer generated and carry an old marker, so `agents_files_cp.sh --delete` skips them. The script moves them out by name.
- **Local deploy is host-guarded.** `agents_files_cp.sh` runs only on hosts in `ALLOWED_HOSTS`; add a new Mac there (with a test case) rather than overriding `AGENTS_FILES_CP_HOSTNAME`.

## Steps

1. **Stop Pi:** close sessions, then `pkill -HUP -x pi`; repeat until `pgrep -x pi` prints nothing.
2. **Update the repo:** `git -C ~/.local/bin pull --ff-only origin main`
3. **Preflight, then migrate:**
   ```bash
   ~/.local/bin/pi_profiles_migrate.sh            # preflight only
   ~/.local/bin/pi_profiles_migrate.sh --apply
   ```
   Check the printed JSON (`sessions_by_source`, `remapped`).
4. **Deploy:** `~/.local/bin/agents_files_cp.sh --delete` (step 3 already saved the deploy targets to the rollback archive).

## Verification

Run in a fresh terminal; expect `ok`, no other output, and `ready` from the auth check:

```bash
test ! -e ~/.pi/profiles && echo ok
command -v pi-profile
rg -l 'pi-profile' ~/.pi/agent/skills ~/.claude/skills ~/.gemini/skills ~/.copilot/skills ~/.copilot/profiles ~/.cursor/skills 2>/dev/null | grep -v test_worker_launchers.sh
rg -n 'pi-profile|PI_WORKER_PROFILE|\.pi/profiles' ~/.zshrc ~/.zprofile ~/.bashrc 2>/dev/null
pi auth check --provider github-copilot --no-refresh
```

Then open `pi`, run `/resume`: sessions from all former profiles appear, forks nested.

## Rollback

Everything moved lives in `~/.pi-rollback-YYYYMMDD/`. Stop Pi, then:

1. `mv ~/.pi/agent/sessions ~/.pi/agent/sessions.failed`; move `agent-sessions` back to `~/.pi/agent/sessions` and `profiles` to `~/.pi/profiles`.
2. Move `skills/*` back to `~/.pi/agent/skills/`; restore `session-map.json` to `~/.pi/pi-acp/` and `zshrc.bak` to `~/.zshrc`.
3. Tool dirs: `tar -xzf ~/.pi-rollback-YYYYMMDD/deploy-targets.tgz -C ~`.

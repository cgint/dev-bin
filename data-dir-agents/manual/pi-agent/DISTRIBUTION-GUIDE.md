# Distribution Guide

## Overview

Files managed in this repo may be copied to **multiple locations** on disk.
Changing one copy does **not** automatically update the others — manual sync is required.

## Automated Sync Script (`sync-extensions.sh`)

A dynamic sync script `./sync-extensions.sh` is available in the repository root. It automatically scans all `extensions/*.ts` files (dynamically discovered via globbing, not hardcoded) and updates matching copies across `~/.pi`:

```bash
# Preview pending updates (dry-run summary)
./sync-extensions.sh

# Apply pending updates automatically
./sync-extensions.sh --yes
```

How it works:
1. Dynamically scans `extensions/*.ts` for any extension files in the repository.
2. Searches `~/.pi` for existing matching files by filename (`find ~/.pi -type f -name "<filename>"`).
3. Compares content using `cmp`.
4. Displays a dry-run summary showing `[UP TO DATE]` vs `[NEEDS UPDATE]` targets and exact `cp` commands.
5. Asks for user confirmation before performing copies (unless `--yes` is passed).

## How to find all copies

**Always run this first — never rely on the list below alone.** Locations change.

```bash
find ~/.pi -name "<filename>"
```

## Example locations (may be outdated)

| Location | Notes |
|---|---|
| `~/.pi/agent/extensions/advisor.ts` | Active Pi agent extension directory |
| `~/.pi/profiles/<profile>/agent/extensions/advisor.ts` | Profile-specific extension override |
| `data-dir-agents/manual/pi-agent/extensions/advisor.ts` | Local copy managed in this repo |

## When to sync

After modifying a file that is distributed, check whether it needs to be
copied to any of the locations above. **Do not distribute automatically** — confirm
with the user which locations need updating.

## Rollout note (2026-07-07)

Rollout of `extensions/advisor.ts` requires write access to `~/.pi/` paths.
In READ-ONLY mode the write guard restricts output to the repo directory
(`data-dir-agents/manual/pi-agent/`). The rollout commands are ready:

```bash
cp data-dir-agents/manual/pi-agent/extensions/advisor.ts ~/.pi/agent/extensions/advisor.ts
cp data-dir-agents/manual/pi-agent/extensions/advisor.ts ~/.pi/profiles/partner/agent/extensions/advisor.ts
```

If the write guard blocks this, the user needs to update the write guard to
allow `~/.pi/` paths, or approve the `cp` command explicitly.

## Quick reference

```bash
# Find all copies
find ~/.pi -name "advisor.ts"

# List known locations
echo "~/.pi/agent/extensions/"
echo "~/.pi/profiles/*/agent/extensions/"
echo "data-dir-agents/manual/pi-agent/extensions/"
```
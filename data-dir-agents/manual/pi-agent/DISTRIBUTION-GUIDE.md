# Distribution Guide

## Overview

Files managed in this repo may be copied to **multiple locations** on disk.
Changing one copy does **not** automatically update the others — manual sync is required.

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
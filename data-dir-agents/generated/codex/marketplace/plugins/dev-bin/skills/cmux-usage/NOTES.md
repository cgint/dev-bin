# cmux-usage — provenance and verification status

Not loaded with the skill. This file records **how much to trust `SKILL.md` and when to re-verify it**.
`SKILL.md` says what to do; this says how it was established and what is still unmapped.

## Verified against

| | |
|---|---|
| cmux | **0.64.20 (100) [14e3400b9]** |
| macOS | 26.5.2 (Darwin 25.5.0), Apple Silicon |
| date | **2026-07-27** |
| method | live CLI runs inside cmux + replay of ~360 cmux invocations across 12 Pi sessions (2026-07-02 … 2026-07-27) |

**cmux moves fast — check the version first.** During authoring, the CLI emitted live deprecation
notices renaming `new-workspace` → `workspace create` and `list-workspaces` → `workspace list`
(legacy forms still work). If `cmux version` is meaningfully ahead of the line above, treat the
command-level specifics as history and re-verify before trusting them. The *concepts*
(the four object types, the tab/workspace ambiguity, visible-vs-stacked) are stable; the
*flags and output strings* are what rot.

## How each class of claim was established

| Claim class | Method | Confidence |
|---|---|---|
| Terminology and topology | `cmux identify --json`, `cmux tree`, upstream skill + GitHub Discussion #1404 | high — cross-confirmed |
| `tab_id` == `surface_id` | live `identify --id-format both`; identical UUID | verified |
| `CMUX_TAB_ID` holds the workspace UUID | live: env var vs `identify` disagreed | verified on this machine; may be a bug, may be fixed upstream |
| Failure catalogue rows | actual error strings from session transcripts | verified as observed; error *wording* may change |
| 2×2 tiling recipe | built live, measured `stty size` per pane, then torn down | verified |
| Background workspaces not laid out | built a 1-pane workspace, measured before and after selecting it | verified |
| `--layout` JSON schema | one working nested example, from `new-workspace --help` | **partial — see below** |

## Known unmapped edges

- **`--layout` schema is undocumented upstream.** Not present in the CLI contract. Confirmed keys:
  `direction` (`horizontal` = side by side, `vertical` = stacked), `split` (fraction to the first
  child), `children`, `pane.surfaces[]`, `surfaces[].type`, `surfaces[].command`, `surfaces[].env`.
  Untested: nesting deeper than 3 levels, `browser` surfaces inside a layout, other pane-level keys.
- **`29×88` is this machine's default background size**, not a constant. The *rule* (never-displayed
  workspaces report a placeholder size) is what matters; the number is illustrative only.
- **`67×141` / `32×70`** in the tiling section are likewise this window's measurements at this
  font size. The *ratios* are the point.
- **`cmux ssh` workspace lifecycle** — in one session an SSH workspace appeared in `tree` and then
  vanished from a later `tree`. Never root-caused. Avoid asserting SSH workspace persistence.
- **`cmux browser open`** returned `OK surface=unknown pane=unknown placement=reuse`. The browser
  subcommand surface is large and largely unexercised here; §15 points at `cmux docs browser`.

## Sources

- upstream skill: `https://raw.githubusercontent.com/manaflow-ai/cmux/main/skills/cmux/SKILL.md`
- CLI contract: `https://raw.githubusercontent.com/manaflow-ai/cmux/main/docs/cli-contract.md`
- terminology ambiguity confirmed by the cmux community: https://github.com/manaflow-ai/cmux/discussions/1404
- predecessor draft (superseded): `~/dev/concepts/homelab/.pi/skills/cmux-usage/SKILL.md`

## Future learnings

Append dated entries. Promote anything that changes agent behaviour into `SKILL.md` as an
instruction; leave provenance and confidence here.

- _2026-07-27 — initial authoring._

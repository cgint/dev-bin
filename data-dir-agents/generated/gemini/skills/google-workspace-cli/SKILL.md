---
name: google-workspace-cli
description: Google Workspace CLI (gws) — discover and call Google Workspace APIs via a uniform REST-style CLI
---

# Google Workspace CLI (`gws`)

Use the `gws` CLI to interact with Google Workspace APIs (Drive, Sheets, Gmail, Calendar, Admin, …) through a consistent command pattern.

This skill is intentionally **discovery-first**: don’t hardcode flags from help output; instead, ask the tool for the current truth.

## Service references (deep dives)

Load specialized reference files for operational rules, traps, and query examples:

- Calendar: [references/calendar.md](references/calendar.md) (recurring event expansion, primary calendar scope, agenda queries)
- Drive: [references/drive.md](references/drive.md) (listing files, fetching metadata, schema inspection)

## Discoverability first

```bash
# What services/flags/auth options exist right now?
gws -h

# Explore a service/resource (if supported)
gws <service> -h
gws <service> <resource> -h

# Inspect a specific method’s schema (params/body/response)
gws schema <service.resource.method>
gws schema <service.resource.method> --resolve-refs
```

## Command shape

```bash
gws <service> <resource> [sub-resource] <method> [flags]
```

Rule of thumb:
- if you’re unsure what goes into query params vs request body, trust `gws schema …`.

## Generic command pattern

```bash
# Query parameters are passed as JSON to --params
gws <service> <resource> <method> --params '{"paramKey": "paramValue"}'

# Request bodies (for writes/mutations) are passed as JSON to --json
gws <service> <resource> <method> --json '{"bodyKey": "bodyValue"}'
```

## JSON output parsing rule for scripts & codemode

`gws` stdout may emit non-JSON preamble logs before the payload (e.g. `Using keyring backend: keyring`). Calling `JSON.parse(stdout)` directly will fail.

Defensive parsing guidance:
- Check if the command supports quiet/JSON-only flags (discover via `gws -h`).
- When parsing raw stdout in code, strip informational prefix lines or extract the JSON payload (locate the initial `{` or `[` after any log preamble).
- Retain the raw output if parsing fails to diagnose credential, network, or keyring warnings.

## Authentication (general patterns)

Verify the current auth mechanisms via `gws -h`. Common patterns include:

```bash
# Interactive OAuth (browser-based)
gws auth login

# Service account (ADC)
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

Security:
- Treat tokens/credentials as **secrets** (never paste into logs, never commit).

## Safety rules for agents

- Before running **write / delete / share / send-email** actions, explicitly confirm intent with the user.
- If the CLI offers a preview mode (often called something like `--dry-run`), prefer it first — but **discover the exact flag name** via `gws -h`.
- For sensitive content (PII), check whether the CLI offers sanitization/screening features and confirm usage with the user.

## Tip: harvesting upstream “recipes” (optional)

The `gws` project can auto-generate a large set of helper skills/recipes. To avoid polluting your repo, generate into a temp directory and then **copy only the useful bits into this skill**.

```bash
tmp="$(mktemp -d)"
(cd "$tmp" && gws generate-skills)
# Browse $tmp/docs/skills.md and $tmp/skills/**/SKILL.md
```

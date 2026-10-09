---
name: google-workspace-cli
description: Google Workspace CLI (gws) — discover and call Google Workspace APIs via a uniform REST-style CLI
---

# Google Workspace CLI (`gws`)

Use the `gws` CLI to interact with Google Workspace APIs (Drive, Sheets, Gmail, Calendar, Admin, …) through a consistent command pattern.

This skill is intentionally **discovery-first**: don’t hardcode flags from help output; instead, ask the tool for the current truth.

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

## Minimal examples

```bash
# List something (exact params vary; check schema/help)
gws drive files list --params '{"pageSize": 10}'

# Fetch a single resource
gws drive files get --params '{"fileId": "..."}'

# Inspect what a method expects
gws schema drive.files.list --resolve-refs
```

## Tip: harvesting upstream “recipes” (optional)

The `gws` project can auto-generate a large set of helper skills/recipes. To avoid polluting your repo, generate into a temp directory and then **copy only the useful bits into this skill**.

```bash
tmp="$(mktemp -d)"
(cd "$tmp" && gws generate-skills)
# Browse $tmp/docs/skills.md and $tmp/skills/**/SKILL.md
```

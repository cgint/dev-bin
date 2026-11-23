# Codex target format

## What we generate

- `generated/codex/AGENTS.md`
- `generated/codex/marketplace/`, a local marketplace containing the `dev-bin` skills plugin

## What it deploys to

- `~/.codex/AGENTS.md`
- `~/.codex/dev-bin/`, the managed source for the local marketplace

## Source of truth

- `definitions/agents/AGENTS_GPT52.md`
- `definitions/skills/` and their bundled runtime files

## Notes

Skills are listed as `dev-bin:<skill>` in Codex. The plugin version changes when its skills or helper executables change, so a running Codex app server can discover the new package.

The standard Mac deployment installs the plugin for an initialized Codex home. A remote host with `codex_bin` in its host definition receives the same bundle. Deployment checks the generated files against their definitions before transfer. The shared [propagation diagram](../propagation.svg) shows where the Codex package fits.

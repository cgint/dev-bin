# Definitions repo workflow

## After editing a skill/agent/profile

1. Run `agents_files_cp.sh` to propagate to `generated/` and deploy to runtime locations.
2. Commit **both** the source change (`definitions/...`) **and** the generated files (`generated/...`).
3. Push.

Generated files are derived artifacts — they must be committed alongside their source so the repo is always in a consistent state.

## Structure

- Edit only files under `definitions/`.
- Never edit `generated/` directly (it is regenerated).
- See `STRUCTURE.md` for the full pipeline overview.
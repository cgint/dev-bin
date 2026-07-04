# When working with python
Use 'uv' tool always to run python code.

## Agent definitions

Agent configuration (agents, skills, profiles, prompts) is authored in the canonical source directory:

```
data-dir-agents/definitions/
├── agents/          # Agent prompt templates (sources for Gemini, Codex, Copilot, pi-agent)
├── skills/<name>/   # Modular skill directories — see skills/README.md for taxonomy
├── profiles/        # Profile TOMLs (which skills attach to which agent)
├── prompts/         # Prompt templates
└── STRUCTURE.md     # Pipeline overview (definitions → generated → deployed)
```

- **Read** `definitions/skills/README.md` to understand what skills exist and how they're categorized.
- **Read** `definitions/STRUCTURE.md` for the propagation pipeline (generator → `generated/` → user config dirs).
- **Edit** only files under `definitions/`; never edit `generated/` (it's regenerated).
- **Deploy** with `agents_files_cp.sh [--delete]` (run from any directory).
- **Commit** both `data-dir-agents/definitions/...` (sources) **and** `data-dir-agents/generated/...` (build outputs) together — never commit one without the other.

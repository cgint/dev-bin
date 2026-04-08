Agents Data Directory - Skills and Guidance

This directory is the canonical, versioned source of truth for the pi-agent skills and related guidance.

Purpose
- Maintain skill definitions, usage notes and examples here (agents-data-dir/generated/pi-agent/skills/*).
- Use the helper script agents_files_cp.sh to copy these files into the runtime location (~/.pi/agent/) where the pi-coding-agent expects them.

Default publish action
- After making changes to skills in this repo, run `./agents_files_cp.sh` from the repository root to publish updates to the runtime location. This publish step is the standard and recommended default workflow.

How to publish to the runtime location
1. Edit the files in this repo under agents-data-dir/generated/pi-agent/skills/
2. Run the copy script from the repo root:
   ./agents_files_cp.sh

Or use your existing distribution tooling (gget.sh / gclone.sh) as you prefer.

Skills overview (managed here)
- pi-agent/skills/diagrams
  - SKILL.md: Guidance for D2 and PlantUML usage
  - Examples: sample.d2 and sample.puml (in skills/diagrams/examples)
  - Tools referenced: d2to.sh, plantuml.sh
  - Default guidance: Use PlantUML for technical UML diagrams (class, sequence, component, architecture). Use D2 for human-facing flow/process and descriptive diagrams by default unless the user requests PlantUML explicitly.
  - Local project examples discovered on this machine (useful to reference):
    - $HOME/dev/prometheus-tool/rlm_vs_react.d2
    - $HOME/dev/prometheus-tool/docs/log_agent.d2

- pi-agent/skills/web-search
  - SKILL.md: Guidance for webs.sh (Gemini grounded web-search)
  - Tool referenced: webs.sh
  - Notes: Use focused queries, optionally pass local files for combined local+web analysis (webs.sh <file> "<prompt>"). Save results with redirect when you need evidence. Allow at least **180s** per run for grounded search; on timeout retry with a higher limit before giving up.

- pi-agent/skills/read-code-structure
  - SKILL.md: Guidance for ctags_symbol_map.py
  - Tool referenced: ctags_symbol_map.py (uses Universal Ctags)
  - Notes: Run from project root. Useful to export symbol maps for documentation, refactoring and onboarding.

- pi-agent/skills/web-browser-use
  - SKILL.md: Guidance for agent-browser usage and chaining commands
  - Tool referenced: agent-browser
  - Notes: Recommended to set viewport up front (e.g., 1024x768 or 1440x900). Chain commands with && for sequential execution and reliability.

Quick usage snippets

1) Diagrams
- D2 (human-facing diagrams) example (see skills/diagrams/examples/sample.d2):
  d2to.sh sample.d2
  # produces sample.svg

- PlantUML (technical UML diagrams) example (see skills/diagrams/examples/sample.puml):
  plantuml.sh sample.puml
  # produces sample.svg or sample.png depending on script default

- Guidance: By default prefer D2 for explanatory/human-facing visuals; prefer PlantUML for technical UML diagrams.

2) Web search (webs.sh)
- Timeouts: grounded search is slow; use at least **180 seconds** (or **180000 ms** where the harness uses milliseconds). If a run times out, retry with a longer limit—do not treat a short timeout as “search unavailable.”
- Simple search:
  webs.sh "latest AI news"

- Search + analyze a file (local context + grounding):
  webs.sh context.txt "Summarize the key points and provide sources"

- Save results:
  webs.sh "query" > search_results.txt

3) Read-code-structure (ctags_symbol_map.py)
- Generate symbol map for a project:
  ctags_symbol_map.py . > symbols.md

- Tip: Run from project root, then open symbols.md to jump to files in your editor.

4) Web browser automation (agent-browser)
- Chain example (set viewport, open, screenshot):
  agent-browser set viewport 1024 768 && agent-browser open https://example.com && agent-browser screenshot homepage.png

- Full flow example:
  agent-browser set viewport 1440 900 && \
  agent-browser open https://your-app.com && \
  agent-browser screenshot "login-page.png" && \
  agent-browser click "Sign Up" && \
  agent-browser type "user@example.com" && \
  agent-browser click "Create Account" && \
  agent-browser screenshot "dashboard.png"

Guidelines for contributors
- Edit the SKILL.md files under agents-data-dir/generated/pi-agent/skills/<skill>/SKILL.md
- Add small examples and minimal sample files in skill subdirectories if useful (e.g. diagrams/examples)
- Commit changes to this repo and run ./agents_files_cp.sh to copy them to the runtime location for testing

Contact
- If unsure about how a specific runtime tool behaves on your machine, check the script -h (e.g. d2to.sh -h, plantuml.sh -h, webs.sh -h) or inspect the script content in the repo root.

Stored examples
- skills/diagrams/examples/sample.d2
- skills/diagrams/examples/sample.puml


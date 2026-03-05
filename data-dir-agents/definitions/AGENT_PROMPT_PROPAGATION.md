Agent prompt/skill propagation — plan

Summary

Keep a single canonical source for agent prompts/skills and generate tool-specific artifacts (Gemini CLI, GitHub Copilot CLI, pi-agent) from that source using a generator script. This avoids drift, is repeatable, and scales to more agents.

Decisions (default)

- Approach: Generator-based (preferred) rather than hand-editing target files.
- Canonical storage location: ./definitions/ (relative to this directory; absolute: $HOME/.local/bin/data-dir-agents/definitions/)
- Implementation language: Python (self-contained; current implementation is `propagate_definitions.py`)
- Generator safety: default to dry-run + generated output; explicit --apply required to overwrite target files.

Rationale

- Single source of truth reduces inconsistent copies and manual errors.
- Templates handle format differences between Gemini CLI (GEMINI.md, `~/.gemini/commands`), Copilot CLI (copilot-instructions.md + Agent Skills under `~/.copilot/skills/<skill>/...`), and pi-agent (`skills/<skill>/...` + `prompts/*.md`).
- Generator can be tested, reviewed, and added to CI to prevent regressions.

Canonical spec schema (concept)

Each spec is a YAML or Markdown + frontmatter file containing these fields:
- id: unique-id
- title
- description
- persona/system_text: core system / persona instructions
- prompts: list of prompt variants (name, text, example)
- metadata: targets (gemini, copilot, pi-agent), precedence, applyTo (globs for path-scoped rules), tags
- last_updated, author

Example (conceptual)

---
id: code-review
title: Code reviewer
description: Provide a concise, actionable code review focused on readability and security.
persona: "You are a senior developer and security-conscious code reviewer."
prompts:
  - name: default
    text: "Review the following code and suggest improvements: {{files}}"
metadata:
  targets: [gemini, copilot, pi-agent]
  applyTo: "src/**"
---

Mapping (canonical -> target)

- Gemini CLI
  - GEMINI.md: assemble persona + rules + common prompts
  - .gemini/commands/<name>.md: for custom command shortcuts
  - .geminiignore suggestions
- GitHub Copilot CLI
  - copilot-instructions.md: personal instructions file (in this setup deployed to `~/.copilot/copilot-instructions.md`)
  - skills/<skill>/...: Agent Skills folders (in this setup deployed to `~/.copilot/skills/<skill>/...`)
- pi-agent
  - skills/<id>/SKILL.md or prompts/<id>.md: match current pi-agent conventions

Generator requirements

- Input: one or more definition files under ./definitions/
- Output: writes to generated/ by default; with --apply writes to target directories under this data-dir
- Modes: dry-run (default), apply, validate
- Validation: simple schema checks (required fields, valid targets)
- Tests: snapshot tests for example specs -> generated outputs
- Safety: do not overwrite target files without explicit --apply; save backups when applying

Verification & CI

- Add a CI job to run the generator in dry-run and compare generated outputs to committed artifacts (snapshot test).
- Add a manual smoke-test checklist for local verification (regenerate -> inspect GEMINI.md and copilot-instructions.md in generated).

Next steps (implementation — requires approval)

1) Create ./definitions/ and add 2 example definition files (gemini-style and copilot-style).
2) Implement minimal generator script that converts definitions -> generated/ targets.
3) Run generator in dry-run and review outputs; iterate templates.
4) Add --apply support and a safety confirmation before overwriting targets.

Notes

- This document is intentionally brief. The generator templates will define exact formatting for each target and should be kept under version control.
- If you prefer re-using OpenSpec's schema or tooling, we can integrate the canonical definitions into OpenSpec/openspec/specs/ instead of ./definitions/ here. Recommendation is to keep agent artifacts together under this data-dir for easier discovery.

Approval request

Reply with "Proceed" to start implementing the generator (canonical path: ./definitions/, default dry-run). If you want different defaults, specify them in your reply.
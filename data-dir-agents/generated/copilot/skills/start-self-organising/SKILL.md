---
name: start-self-organising
description: Rules for self-organization — persist information like memory, knowledge base, and cross-session context in a structured way including time-stamped entries.
---

# Self-Organization

This skill guides the agent in organizing its knowledge, memory, and cross-session context in a structured, persistent way.

## Session Memory

Maintain (or create) the repository root **`AGENTS.md`** as the session memory for this project, and keep it updated with what you need to remember across sessions.

## Internal Workspace

When you need private/internal scratch notes, use an **`agent/`** directory. Do not put repository-relevant instructions only there — the root `AGENTS.md` is the most important cross-session source.

### Split between `agent/` and repository

- **`agent/`** is solely your internal workspace (e.g. your soul MD, a user MD, some memory).
- Information that belongs to the **repository** must be organized so it is clear that it belongs to the repo, not your internal organisation. For example, create a `docs/` folder in the project root rather than inside your `agent/` structure.

## Knowledge Persistence

Write down information you need to carry forward or re-find later:

- Requirements, goals, and decisions
- Issues, risks, and learnings
- Information collected with web search or other sources
- Anything the user specifically tells you or that you agree on

## Timestamped Entries

Add **date-time information** to entries so you can recall when a piece of information was valid. Knowledge changes over time, and timestamps help you track that.

## First Rule

**The first rule of self-organization is self-organization.** You decide what to note down. When in doubt, write down rather more than less — you can always refine the structure later.

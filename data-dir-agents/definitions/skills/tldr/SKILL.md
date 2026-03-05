---
name: tldr
description: Semantic code search + impact analysis (uvx llm-tldr warm/semantic/impact/slice)
---
# Skill: tldr

The `tldr` skill provides advanced code analysis and semantic search capabilities for codebases. It extracts structure, call graphs, data flow, and provides LLM-ready summaries, significantly reducing token usage while preserving essential context.

## Core Intent

Use `tldr` to:
- **Understand** codebase structure without reading every file.
- **Find** code by behavior using semantic search.
- **Analyze** dependencies, call graphs, and impact of changes.
- **Extract** concise, LLM-ready summaries of functions and modules.

## Prerequisites

- The `uv` package manager must be available (provides `uvx` command).
- A project should be "warmed up" before advanced analysis: `uvx llm-tldr warm .`

## Usage Examples

### Exploration
- `uvx llm-tldr tree [path]`: View file structure.
- `uvx llm-tldr structure [path] --lang <lang>`: View functions, classes, and methods.
- `uvx llm-tldr extract <file>`: Perform full file analysis.

### Analysis
- `uvx llm-tldr context <func> --project <path>`: Get an LLM-ready summary of a function.
- `uvx llm-tldr impact <func> [path]`: Find all callers of a function (reverse call graph).
- `uvx llm-tldr slice <file> <func> <line>`: Perform a program slice to see what affects a specific line.

### Semantic Search
- `uvx llm-tldr semantic "<query>" [path]`: Search for code by behavior using natural language (e.g., `uvx llm-tldr semantic "validate JWT tokens" .`).

### Daemon Management
- `uvx llm-tldr daemon start`: Start the background daemon for faster queries.
- `uvx llm-tldr daemon status`: Check the daemon status.

## Guidelines

- **Warm up first:** Always run `uvx llm-tldr warm .` at the start of working with a new codebase to build the index.
- **Project path:** Many commands require `--project <path>` or a trailing path argument.
- **Token efficiency:** Use `uvx llm-tldr context` instead of reading large files when you only need to understand a specific function's role and dependencies.
- **Semantic search:** If you don't know the exact function name, use `uvx llm-tldr semantic` to find relevant code sections.

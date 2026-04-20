---
name: colgrep
description: Semantic code search (find code by meaning/natural language)
---
# Skill: colgrep

`colgrep` is a semantic grep that understands what you're looking for. It allows searching with natural language and finds relevant code even when keywords don't match exactly.

## Core Intent

Use `colgrep` to:
- **Discover** code by behavior/intent using natural language queries.
- **Rank** search results by semantic relevance.
- **Hybrid Search**: Filter by regex first, then rank results semantically.

## Usage Examples

### Semantic Discovery
- `colgrep -y "how is user authentication handled?"`: Find relevant code sections (auto-confirm indexing).
- `colgrep -y -c "database connection logic"`: Show full function/class content for matches.
- `colgrep -y "error handling" ./src/auth.py`: Search within a specific file or directory.

### Hybrid Search (Regex + Meaning)
- `colgrep -y "auth" -e "async fn"`: Find async functions related to "auth".
- `colgrep -y "usage" -e "Result" --include "*.rs"`: Find Result usage in Rust files ranked by "usage" relevance.

### Management
- `colgrep init -y`: Build or update the index for the current directory (auto-confirm).
- `colgrep status`: Check index status.

## Guidelines

- **Always use `-y`**: When running as an agent, always include the `-y` (`--yes`) flag to automatically confirm indexing for large codebases. Without this, the command may hang waiting for user input.
- **Use `-c` for Context**: Instead of reading files manually, use `colgrep -c` to see the full function/class containing the match.
- **Hybrid for Precision**: If you know a specific keyword or pattern (like a function signature), combine it with a semantic query using `-e` for the best results.
- **Indexing**: `colgrep` auto-indexes if needed, but run `colgrep init -y` manually if the codebase has changed significantly.

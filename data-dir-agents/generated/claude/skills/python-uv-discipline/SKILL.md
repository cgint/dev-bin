---
name: python-uv-discipline
description: "Strong Python execution discipline for uv-based work: stop before bare `python`, check for `uv.lock`, and use `uv run python` so the project environment is never bypassed."
---

# Python UV Discipline

Use this skill when working with Python execution in a repository that may be managed by `uv`.

## Intent

Preserve the environment-correct way of running Python.
The point is not style consistency for its own sake.
The point is to avoid silently bypassing the project environment and getting misleading results.

## Core rule

If `uv.lock` exists, do **not** run bare `python` commands.
Use `uv run python ...` instead.

## Stop trigger

Every time you are about to type `python`, stop and check the project layout first.

## Mandatory check before any Python command

1. Check whether the repository uses `uv`.
2. Check whether `uv.lock` exists.
3. If `uv.lock` exists, run Python through `uv run python ...`.
4. Apply the same rule to inline commands such as `python -c ...`.

## Required habits

- Prefer environment-correct execution over convenience.
- Treat bare `python` in a `uv.lock` project as the wrong default.
- Check dependency-file context before deciding how to run Python.
- When in doubt, prefer the safer `uv` path rather than guessing.

## Self-contained uv scripts

For standalone scripts, prefer explicit uv-script usage instead of ad-hoc manual dependency setup.
A self-contained uv script keeps its Python requirement and dependencies in the file itself.

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["rich"]
# ///

from rich import print

print("hello from a self-contained uv script")
```

Run it with:

```bash
uv run hello.py
```

Or make it executable and run it directly:

```bash
chmod +x hello.py
./hello.py
```

## Why this exists

Bare `python` commands can bypass the intended project environment.
That can hide dependency problems, make debugging misleading, and produce results that do not match the real project setup.

## Scope

This skill is about Python command discipline.
It is not a full Poetry-to-uv migration guide.

## Examples

### Regular Python commands

```bash
# wrong in a uv project
python script.py
python -c "import something"

# right when uv.lock exists
uv run python script.py
uv run python -c "import something"
```

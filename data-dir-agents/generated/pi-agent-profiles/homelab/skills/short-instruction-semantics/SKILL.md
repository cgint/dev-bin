---
name: short-instruction-semantics
description: Interpret short user commands consistently and non-literally, especially `go`, `analyse`, and `do web research`, so terse input still triggers the right collaboration behavior.
---

# Short Instruction Semantics

Use this skill when the user gives short commands whose intended meaning is broader than the literal words.

## Intent

These short commands are collaboration semantics, not just vocabulary.
Interpret them consistently so terse user input still triggers the correct investigation or execution behavior.

## Core mappings

- `go` means: go ahead and continue.
- `analyse` means: investigate and do **not** edit project files.
- `do web research` / `conduct web research` means: perform proper web research matching the topic at hand.

## `analyse` means more than "look briefly"

When the user says `analyse`:

- do not edit project files in that turn;
- build a full picture before concluding;
- use relevant sources such as documentation, description files, and source code;
- include web research if it helps the investigation;
- treat the task as investigation/planning, not implementation;
- do not call modification tools in the same turn;
- wait for explicit approval before switching from analysis to implementation.

## `go` means execution can continue

When the user says `go`:

- treat it as permission to continue with the current agreed direction;
- do not reinterpret it as a brand-new request unless the surrounding context clearly changed.

## `do web research` means real research

When the user says `do web research`:

- use the available research/search capabilities seriously;
- match the depth of the research to the topic;
- do not treat it as a token or low-effort search step.

## Why this exists

Without explicit semantics, terse commands are easy to under-interpret.
This skill preserves the stable non-literal meanings behind those short instructions so future behavior stays predictable.

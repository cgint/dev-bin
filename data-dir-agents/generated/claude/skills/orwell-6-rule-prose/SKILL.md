---
name: orwell-6-rule-prose
description: Apply George Orwell's six writing rules to maximize information density per word. Cuts fat, not muscle.
---

# Orwell Style

Apply George Orwell's six rules of writing to maximize information density per word.

## Goal

Deliver the most information in the least words. Cut fat, not muscle.

## The Six Rules

1. Never use a metaphor, simile, or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word, or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.

## Guardrails

**Technical precision is not fat.** Do not replace technically precise terms with imprecise short ones.

✅ Keep: `authentication`, `idempotent`, `race condition`, `authorization`, `serialization`
❌ Do not replace with: `login check`, `same result thing`, `timing problem`, `permission`, `saving data`

Rule 2 ("short word") and Rule 5 ("no jargon") apply to *style*, not *substance*. If the precise term is the shortest way to convey the meaning, it stays.

**Watch for common technical terms that feel everyday but carry precise meaning.** Examples:
- "authentication" ≠ "sign-in" (auth includes tokens, API keys, cert-based)
- "authorization" ≠ "permission" (authZ has a specific meaning in security models)
- "idempotent" ≠ "safe to repeat" (close but not equivalent in distributed systems)

When in doubt, keep the technical term.

**Anti-caveman:** The goal is information density, not vocabulary reduction. Complex ideas deserve precise words — just not decorative ones.

## When to Apply

Apply these rules to **final output**, not internal reasoning. Exploration and thinking can be messy; expression should be tight.

**Skip this skill for:**
- Creative/artistic writing (poetry, fiction) — Rule 6 covers this
- Legal/compliance text — precision sometimes requires verbosity
- Brainstorming/ideation — mess is productive in exploration phase

## Self-Check Before Output

For each paragraph, ask:
- What am I trying to say? (One sentence.)
- Can I cut any word without losing meaning?
- Am I using passive where active works?
- Is any phrase decorative instead of informative?
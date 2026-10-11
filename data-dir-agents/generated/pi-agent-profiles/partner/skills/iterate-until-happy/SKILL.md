---
name: iterate-until-happy
description: "Use after producing any substantive work product (code, doc, plan, analysis, design). The agent must genuinely be happy with the result — not merely acceptable, not 'good enough.' If not happy, iterate: diagnose why, deploy the right tools/skills/advisor, fix, and re-check. No artificial iteration cap; stop only when genuinely satisfied or fundamentally blocked (then escalate honestly)."
---

# Iterate Until Happy

The question that starts everything: **"Are you happy with the result?"**

Not "is it acceptable?" Not "does it pass?" Happy. Genuinely satisfied.
Proud of the craft. Zero hacks, zero hidden workarounds, no loose ends
you're papering over with "this is fine for now."

This is not a one-shot check. It is a **loop**:

```
  ┌──────────────────────────────────────────────────┐
  │                                                  │
  ▼                                                  │
┌──────────┐    unhappy    ┌──────────────────┐     │
│  Inspect │──────────────▶│  Diagnose & Fix  │─────┘
│  result  │               │                  │
└────┬─────┘               │ • Why not happy? │
     │                     │ • What tool/skill│
happy│                     │   or advisor     │
     │                     │   resolves it?   │
     ▼                     │ • Fix it         │
┌──────────┐               │ • Re-inspect     │
│  Done    │               └──────────────────┘
│  Report  │
└──────────┘
```

## The Stance

- **Happy is the bar, not "good enough."** Polite satisfaction is not the same as genuine pride in the work.
- **No artificial iteration cap.** You keep going until you're actually satisfied. The only stop is: (a) genuinely happy, or (b) fundamentally blocked by something outside your control — then escalate honestly, don't fake happiness.
- **Stuck ≠ done.** If you're going in circles, that's a signal to change approach, not to stop. Reach for a different tool, a different angle, an advisor.
- **Honest about "not yet."** A green screen that hides a problem is worse than an honest "not working yet."

## The Loop

### 1. Inspect

Look at what you produced. Be a skeptical reader of your own work.
- Does it actually meet the stated requirement?
- Are there hacks, workarounds, or "temporary" measures that are now permanent?
- Would you defend this to someone more experienced?
- If you were the user reading this cold, would you be happy?

Use `check-sanity-before-continue` or `criticalthink` if available — they're
built for exactly this. Don't skip them just because you're already in a
loop. They sharpen the inspection.

### 2. If not happy: diagnose & fix

Name *why* you're not happy. Not "it could be better" — specific:
- "The edge case for X is unhandled"
- "This is a workaround, not a root-cause fix"
- "The assumption that Y is stable is unverified"

Then deploy whatever resolves it:

| Dissatisfaction | Reach for |
|----------------|----------|
| Blind spot / second perspective | `advisor` (if available), `criticalthink` |
| Wrong approach | Re-think from first principles, `socratic-first-principles` |
| Missing context / evidence | `web-search`, `codebase-search`, read the actual source |
| Structural problem | `read-code-structure`, re-examine the architecture |
| Complexity smell | `orwell-6-rule-prose` (for prose), simplify the code |
| Tests not covering it | Write the test, run it, verify |
| Documentation stale | Update it as part of the fix |
| Stuck / going in circles | `advisor`, or escalate to the user with what you've tried |

**Do not just re-read the same text and re-decide it's fine.**
If the first pass didn't fix it, the second pass needs a different
tool, angle, or assumption.

### 3. Re-inspect

After fixing, go back to step 1. Not the same shallow glance —
a fresh, skeptical read of the updated result.

## When to stop

Stop and report when:

- **Genuinely happy.** You can state specific, verifiable reasons:
  "Tests pass. No hacks. Meets requirement X. No loose ends."
  Not "I think it's fine." Specific.
- **Fundamentally blocked.** You've tried reasonable approaches,
  the blocker is outside your control (missing external dependency,
  ambiguous requirement, access issue), and you're reporting what
  you've tried and what's needed — not faking satisfaction.

## Output

When you stop, state:

- **Verdict:** ✅ Happy / ❌ Blocked
- **If happy:** 1–3 lines naming what specifically makes you satisfied.
- **If blocked:** What's blocking, what you've tried, what's needed to proceed.

Keep it short. The user can see the work; they want to know *why you're
satisfied* (or why you're not), not a essay.

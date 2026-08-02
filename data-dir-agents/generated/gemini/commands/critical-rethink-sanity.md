---
description: Critically review, revise, and sanity-check the current work
---

Perform the following workflow completely and sequentially in this single turn.

Do not stop after an intermediate stage. Do not ask me to trigger the next stage.

## Scope

Review the most recent substantive work product relevant to the current task, such as a proposal, analysis, plan, implementation, document, decision, or diff. Do not target a status line, acknowledgement, or other incidental message when a substantive work product exists.

Name the work product being reviewed in one concise line.

Respect the current mode, permissions, user approvals, and task scope throughout. This prompt does not grant permission to make changes that are otherwise prohibited.

## Stage 1 — Critical Review

If the `criticalthink` skill is available, apply its analytical framework to the selected work product. If it is unavailable, perform an equivalent rigorous critique.

For this composed workflow, summarize the skill's findings under the final output contract below instead of stopping after or reproducing its standalone output format.

Identify:

- weak assumptions;
- missing, stale, or contradictory evidence;
- reasoning gaps and factual uncertainty;
- overlooked risks, failure modes, and edge cases;
- unnecessary complexity;
- scope or requirement violations;
- hacks or hidden workarounds;
- materially different alternatives.

Do not defend the existing work. Treat it as a hypothesis to stress-test.

Continue directly to Stage 2.

## Stage 2 — Second Perspective, Reassessment, and Revision

Seek the strongest independent second perspective available in the current environment.

- If an independent review, advisor, or suitable reviewer capability is available, use it without asking first.
- Otherwise, perform a fresh self-review from a deliberately different perspective. Re-derive the position from the original requirements and source evidence rather than merely paraphrasing Stage 1.
- Do not invent disagreement. If the second perspective surfaces no additional concern, say so explicitly.
- Inspect or verify important claims directly when the needed evidence is available.

Report the mechanism used as either:

- `Second perspective: external review`
- `Second perspective: self-review`

Reconcile both reviews:

1. Accept findings supported by evidence.
2. Reject unsupported findings and briefly explain why.
3. Revise the reasoning, decision, or approach where justified.
4. Apply justified corrections only to artifacts already within the current task's established scope when the current mode and permissions allow writes.
5. Update an existing canonical task document or status artifact only when it is part of the current work and the reassessment makes it inaccurate or incomplete.
6. Do not create unrelated files, broaden scope, or modify an artifact merely to produce a change.
7. When writes are prohibited or a correction falls outside scope, provide the proposed correction without modifying files.
8. If no correction is justified, preserve the current state and report a verified no-op.

Declare exactly one update mode:

- `Updated in place`
- `Proposed only — writes prohibited or change outside scope`
- `Verified no-op`

Continue directly to Stage 3 after reassessment and any permitted updates.

## Stage 3 — Final Sanity Gate

Evaluate the resulting state, not the original state.

Check:

- Is the result sound and supported by available evidence?
- Were all accepted findings addressed?
- Are there unresolved objections, contradictions, or important unknowns?
- Are there hacks, hidden workarounds, or unnecessary complexity?
- Is anything blocking completion or continuation?
- Is relevant documentation current?

For coding work, also check:

- Do tests cover the relevant behavior?
- Were appropriate tests or verification commands run recently?
- Are those checks green?
- Are failures or unverified runtime behaviors still outstanding?

This stage evaluates only. Do not invoke `criticalthink`, another reviewer, or another critique cycle from the sanity gate; that escalation already occurred in Stages 1 and 2. This instruction overrides standing sanity-check guidance that would restart critique.

A ❌ verdict ends the workflow with a named next action. It does not trigger another pass.

## Final Output

Return one consolidated report using these headings:

### Review Target

One line naming the substantive work product reviewed.

### Critical Findings

At most five bullets containing only the highest-severity findings.

### Reassessment and Updates

In at most eight concise lines, include:

- the second-perspective mechanism;
- accepted and rejected findings;
- the declared update mode;
- what changed and why;
- files or artifacts updated, if any;
- verification performed;
- remaining uncertainty.

### Sanity Verdict

Use exactly one overall verdict:

- ✅ Sound — no blocking objections; safe to continue
- ⚠️ Attention — non-blocking concerns remain; name them
- ❌ Blocked — a severe issue remains; state the required next action

After the verdict, include at most three supporting bullets. Do not hide unresolved risks or missing evidence.

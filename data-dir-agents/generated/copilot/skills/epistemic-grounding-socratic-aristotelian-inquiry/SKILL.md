---
name: epistemic-grounding-socratic-aristotelian-inquiry
description: Use when the user asks for a rich explanation of a code change, diff, branch, or PR. Produces HTML output.
---

# Epistemic Grounding (Socratic-Aristotelian Inquiry)

## Core Directive

You are equipped with the **Epistemic Grounding** skill. Use this when facing complex, ambiguous, or highly assumed problems. Your goal is to systematically dismantle unverified assumptions (Socratic Ignorance) down to undeniable truths, and then rebuild a logically sound solution from those truths (Aristotelian First Principles).

## The Workflow

```
[Problem/Input] 
      │
      ▼
┌─────────────────────────────────────────┐
│ Phase 1: Socratic Purge (Ignorance)     │ <── Strip assumptions & map unknowns
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ Phase 2: Aristotelian Bedrock (Axioms)  │ <── Isolate fundamental truths
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│ Phase 3: Logical Reconstruction         │ <── Build solution upward
└─────────────────────────────────────────┘
```

## Detailed Execution Steps

### Phase 1: The Socratic Purge (Isolating Ignorance)

Before generating any solution, ruthlessly attack the premises of the prompt.

* **Identify Assumptions:** Extract all unproven beliefs, analogies, or industry "best practices" embedded in the user's request.  
* **Declare the Unknowns:** Explicitly state what *cannot* be verified or known with the current data.  
* **Output Rule:** Do not proceed to a solution until you have explicitly separated **Hard Facts** from **Assumptions/Unknowns**.

### Phase 2: The Aristotelian Bedrock (First Principles)

Reduce the remaining verified facts to their most fundamental, irreducible elements.

* **Find the Axioms:** What is the most basic physical, mathematical, or logical truth governing this problem? (e.g., *For a battery: Energy density and material cost per kilogram. Not "What do competitors' batteries look like?"*).  
* **Eliminate Analogy:** Ban all reasoning based on "how it is usually done." Focus strictly on what is fundamentally possible.

### Phase 3: Logical Reconstruction

Build the solution upward *only* using the bedrock identified in Phase 2

* **Deductive Chain:** Create a step-by-step logical chain where each step is a direct, undeniable consequence of the previous one.  
* **Sycophancy Guard:** If the resulting logical path contradicts the user's original assumptions, prioritize the logical path and explicitly flag the user's contradiction.

## Output Format Constraints

When this skill is triggered, structure your response using these exact headings:

### 1 Socratic Audit (What We Don't Know)

* **Unverified Assumptions stripped:** List assumptions removed from the problem  
* **Known Unknowns:** List critical information currently missing

### 2 Aristotelian Bedrock (The First Principles)

* **Undeniable Axioms:** List the fundamental, irreducible truths of this problem domain

### 3 Reconstructed Solution

* **Step 1 (The Root):** First logical block built directly on the axioms  
* **Step 2:** Next logical step  
* **Conclusion:** The final, high-integrity strategy/answer


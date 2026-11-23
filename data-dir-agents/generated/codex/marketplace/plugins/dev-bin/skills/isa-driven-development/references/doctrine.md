# Doctrine — provenance and what is sourced vs. adapted

## Primary public sources (Miessler)

Both article URLs verified by direct fetch this session (HTTP 200, body read).
Passages below are quoted or closely paraphrased from the fetched text:
- **"The Entire Game for AI Is Articulation of Ideal State"** — https://danielmiessler.com/blog/ai-ideal-state-articulation
  - "The entire game for AI is articulation of ideal state… all of our conversations about
    specs, and plans, and loops, and PRDs… all converge on this same idea."
  - "A single artifact that captures, enhances, iterates on, climbs toward, builds, and tests
    the ideal state. One document that replaces all these loops and specs and PRDs and plan
    files."
  - Intent engineering: "abandons telling the AI how to do things and replaces that with
    telling it exactly what you want the output to be" — the WHAT, not the HOW.
  - "The problem is always in the guessing. It's in the gap between stated and implicit, or
    stated and difficult to articulate."
  - A goal is not an ideal state: the paperclip maximizer and the test-grade-exploit cases both
    "conveyed a goal without conveying ideal state" — the ideal state includes what must still
    be true *after* you get what you asked for.
- **"Writing Is Closer to Thought Than Code"** — https://danielmiessler.com/blog/writing-is-closer-to-thought-than-code
  - "The most important thing… is how completely and accurately you articulate exactly what
    you want."
  - "The real problem is articulation" — AI executes superbly; the failure is executing
    perfectly against a mis-articulated target.
  - Two loops: "Your intent and the writing go back and forth as you figure out what you
    actually want, and the writing and the implementation go back and forth as you build."
  - No perfect upfront articulation is required: "Nobody has that. We're human, and what we
    want gets clearer as we build."
  - Note: `https://danielmiessler.com/blog/intent-driven-development` is a 301 redirect to this
    article (redirect header observed directly) — do not cite it as a separate source.
- **TheAlgorithm** (ISC source) — https://github.com/danielmiessler/TheAlgorithm
  - ISC = "the irreducible, independently verifiable structure of 'done'."
  - Hard-to-vary (David Deutsch): a good explanation has every part load-bearing. Continuous
    test: "Can I vary this without destroying the goal? If yes, it needs refinement."
  - PRD tests: Coverage (every facet of "done" captured), Tightness (no subset can be removed
    while still satisfying the goal), Uniqueness (no meaningfully different ISC set satisfies
    the same goal).

## Miessler LifeOS release documentation (consulted)

Curated summaries of the LifeOS release documentation consulted from an installed
checkout (`ISA/ISASystem.md`, `ISA/ISAFormat.md`, `ISA/ISAHierarchy.md`,
`LifeOs/HillClimbing.md`, `Testing/TestingDoctrine.md`). The docs themselves note that
some machinery is maintainer-private and not in the public release; the public GitHub
availability of these exact documentation paths was **not** verified in this session, so
treat the public repo as a pointer, not a guaranteed source of these files. These
summaries are self-contained: no absolute checkout paths are needed to apply them.
- **Direction before altitude.** "A fully verified build of the wrong thing is the most
  expensive failure the system can produce." State the ideal state before building.
- **Every ISC names its falsifier.** A criterion with no nameable probe that could prove it
  false is a wish, not a criterion. "The site feels fast" is a wish; "p95 page load under
  800ms measured by the deployed probe" is a criterion.
- **Universal over example criteria.** Example criteria pass while the system is broken;
  universal criteria catch the break. A universal criterion needs a scoped domain, a
  measurement window, and boundary examples — that is strong, not exhaustive, evidence.
- **Evidence is part of the deliverable.** A closed criterion carries its provenance — the
  test run, the probe, the command, the revision. "Should work" is forbidden vocabulary.
- **Fog, not false precision.** Genuinely unknowns stay in an explicitly marked fog section
  rather than being invented as speculative criteria.
- **Forbidden outcomes.** Anti-criteria are derived from Out of Scope and Constraints; a goal
  with no nameable failure mode is under-specified. (ISASystem states "at least one
  anti-criterion" as its own practice; this skill generalizes it to *as many as the risks
  actually imply* — no invented count.)
- **The instrument must be able to report failure.** A probe that records the same thing
  whatever happened is not evidence. Would the record differ if the cause were different?
- **State edges must be produced, not fabricated.** A transition test must drive the system
  across the edge; hand-writing the precondition state tests the consequence, not the code
  that causes it. Falsifier: delete the line that sets the state and re-run — if the suite
  stays green, the test is decoration.
- **Single ISA is the default.** "Single-ISA work is the leaf case and covers virtually all
  real tasks". Split into a tree
  only when a single file stops being legible — "don't pre-split a medium app that fits in
  one file." Hierarchy carries constraint inheritance, bridge criteria at the seams, and
  blast-radius detection.

## Project-specific adaptations (ours, not Miessler's)

These are ours; do not attribute them to the public articles or to LifeOS:
- **No `2_requirements__` file by default** and the `1_idea__`/`3_plan__` feature-folder
  convention.
- **Authority migration with parity accounting.** Existing spec systems keep governing until
  the approval owner explicitly approves a migration; the ISA summarizes with links, source
  wins on conflict.
- **Three orthogonal closure facts.** Coverage (partial/full), approval
  (proposed/agreed), and execution result (inspected / not run / pass / fail / manual) are
  separate; none is a rank on a single proof scale.
- **Human acceptance gates are RESERVED.** Checkboxes track evidence closure only; agents
  never self-mark a human gate. Where a project requires a gate, an unmet required gate is
  reported explicitly; do not claim acceptance until it is met.
- **Selective formal methods.** Statecharts for meaningful lifecycle design (a diagram is not
  proof; executable semantics must themselves be verified); TLA+ as an optional
  pre-implementation design check for risky concurrency/retry/cancel/recovery — not every
  feature. A model that abstracts a failure mode out of the picture leaves that mode
  **uncovered** — even with a documented abstraction, no verification claim may cover
  behavior the model omits; claims are limited to what the model actually contains.
- **Validator minimalism.** Simple mechanical checks (ID existence, link targets) only when
  genuinely needed; no generic Markdown parser or framework as a speculative feature.

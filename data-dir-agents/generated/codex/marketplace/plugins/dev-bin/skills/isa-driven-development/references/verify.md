# Verification — evidence, edge tests, instruments

## Closure is three separate facts, not one rank

For each criterion report, independently:

- **Coverage** — `partial` / `full`: do the existing probes cover the whole criterion?
  Name the uncovered part.
- **Approval** — `proposed` / `agreed`: has the criterion been accepted by its approval
  owner (the user, or the source that governs it)? A checkbox never confers approval.
- **Execution result** — `inspected` / `not run` / `pass` / `fail` / `manual`: what actually
  happened when the probe ran. A test name existing in a file is an *inspection*, not a
  pass. `manual` is a named attestation with a human in the loop.

These are orthogonal facts, not tiers on a single ladder — do not treat a "higher" label as
universally stronger evidence. What closure *requires* is criterion-specific: a pure-function
criterion can close on an executed pass; a rendered-page criterion needs real-browser
observation; a domain-accuracy criterion (extracted value vs. source document) cannot close on
a green extraction file — the file's presence is not correctness. A concrete bounded
observation is not absolute truth: record environment, revision, and remaining gaps alongside
it.

## Mapping rules

- **Missing test-name mapping = unmapped**, not proof no test exists. Say "unmapped this
  session" and move on; do not claim absence.
- **No blanket closures from a green unrelated suite.** Each criterion closes on its own
  falsifiable evidence, linked to a stable ISC ID (not line numbers, not fake test tags).
- **Never generate test or probe names that do not exist.** A cited test name must be a
  verified substring of a real test body. If you cite a probe, open the file and read it.
- **Commands and probes are checked before being cited as evidence.** If the suite could not
  run (compile failure, missing tool), results stay at their actual value — do not force
  green, do not edit shared code to make an unrelated gate pass.

## Instruments must be able to fail

- A check that reports the same thing whatever happened is not evidence (identical error
  text on every failure, a flag that is always set, a badge that is always green).
- Ask: would this record differ if the cause were different? If no, the instrument is
  decoration, however green.
- **Edge tests must produce the transition.** A state-machine edge test drives the system
  across the edge (open→closed, first→repeat, cancelled-after-stop). Hand-writing the final
  state struct and asserting on it tests the consequence, not the code that causes the
  transition. Falsifier: delete the line that sets the state and re-run — if the suite stays
  green, the test is decoration.
- **Concurrency needs realistic overlap.** A one-at-a-time configuration is not evidence of
  multi-item safety. Positive and negative controls both belong in the suite.
- **Regression tests replay the actual incident**, not a paraphrase of it.

## Tests: red evidence, property bounds, no foreign stack

- **Verification before implementation**: run the *relevant* existing baseline checks for
  the touched surface at segment start, go red→green around the change, and apply the full
  or final gate per the project's own rules — never a full-suite run before every edit.
  An after-the-fact test is not
  worthless; it is simply weaker — where safe, back it with known-negative, mutation, or
  real-defect red evidence: show the test failing for the reason you expect.
- **Property tests exercise bounded, generated cases; they do not prove the property in
  general.** Report the run bound, and pair properties with boundary examples and the
  domain's source truth.
- Use the project's native unit/property/integration stack. Do not import a foreign test
  framework into an existing convention.

## TLA+ and statecharts — design checks, not authority

- **Statecharts** for meaningful lifecycle design: states, transitions, and who owns each
  transition. A statechart is a diagram unless executable semantics actually exist — and
  executable semantics are themselves a claim that must be verified against the ISA's
  criteria.
- **TLA+** is an optional pre-implementation design check for genuinely risky concurrency,
  retries, cancel, and recovery — not for every feature. State the model's bounds and
  assumptions explicitly. Checking the model is NOT proof the implementation is correct, and
  a model may intentionally abstract behavior out of the picture — with or without a
  documented reason, an omitted failure mode is simply **not covered** by that model: a
  verified property never claims to cover behavior the model abstracts away, and any claim
  is limited to what the model actually contains. Where a known counterexample exists, it
  must either be preserved/reproduced in the model or the claim explicitly limited.
  Neither kind competes with the ISA as authority.

## The loop is feedback, not waterfall

A failing probe asks "is the code wrong, is the target ambiguous, or does the requirement
itself need changing?" Distinguish all three. A code bug gets a fix. An ambiguous target
gets re-articulated. An *agreed* requirement changes only through its approval owner — never
silently edit the ISA to green a failing test — and a newly proposed target is recorded
separately as proposed until agreed. The loop runs at any phase; plans and tests reference
ISC IDs and never redefine the target.

## Validator minimalism

Prefer simple mechanical checks (ISC-ID existence, link targets resolve, closed criteria
each carry an execution result) only when genuinely needed. Do not build a generic Markdown
parser or a validation framework as a speculative feature; a small script or a careful read
is the right tool at project scale.

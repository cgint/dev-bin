# orwell-style

Apply George Orwell's six writing rules to AI agent output. Goal: **most information in the least words.**

## Motivation

"Caveman mode" (tell AI to write like a caveman) strips nuance along with verbosity. Orwell's rules are surgical — they kill decoration while preserving precision. The sixth rule ("break any rule sooner than say anything barbarous") provides the judgment override that caveman mode lacks.

## Usage

Load as a skill: `--skill skills/orwell-style/SKILL.md`

The agent applies the rules to its output automatically. Best results on final output, not exploratory thinking.

## Where It Works Well

Validated across 13 test domains (50–80% word reduction, same information):

| Domain | Typical Reduction | Notes |
|--------|-------------------|-------|
| Requirements docs | 65–80% | Strong — kills corporate padding |
| Runbooks / procedures | 75–80% | Strong — steps emerge from prose |
| Emails / status updates | 60–70% | Strong — removes hedging and filler |
| Changelogs | 75–80% | Strong — hype → facts |
| User stories | 50–65% | Good — acceptance criteria sharpen |
| Code comments | 60–70% | Good — narration → explanation |
| Incident reports | 50–55% | Good — timeline clarity improves |
| Security advisories | 50–60% | Good — precision preserved |

## Where It Doesn't Work

| Domain | Behavior | Why |
|--------|----------|-----|
| **Already-dense docs** | ~0% reduction | Nothing to cut — correctly leaves alone |
| **Mathematical proofs** | ~40% reduction | Formulas are already tight; only trims surrounding prose |
| **Creative writing** | Skipped | Rule 6 correctly blocks — poetry/fiction would be destroyed |
| **Legal/compliance text** | Not tested | Precision may require verbosity; use caution |
| **Brainstorming** | Should not apply | Mess is productive in exploration; apply only to final output |

## Known Limitations

**Common technical terms may be over-simplified.** The agent sometimes replaces terms like "authentication" with "sign-in" or "invalid" with "bad" — following Rule 5 (everyday equivalents) too literally. These swaps lose technical precision.

Mitigation: the skill includes explicit guardrails listing protected terms. The agent respects most technical terms (CQRS, Kafka, CVE, CVSS) but may miss common ones that feel everyday. **Review output when technical accuracy matters.**

## Source

Based on George Orwell, "Politics and the English Language" (1946).

Experiment repo: `/Users/cgint/dev/concepts/orwell-6-rules-of-expressing/`
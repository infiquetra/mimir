# Milestone 5 product specification complete

Date: 2026-09-14 (America/Indiana/Indianapolis)
Baseline: `d2dd731`
Branch: `chore/aar-per-attacker-matchup-spec`

## Delivered

[Product specification](../../docs/specs/aar-per-attacker-matchup.md) covers the
requested eight sections, five scenarios, 28 acceptance criteria, and 40 future
domain/provider/UI test cases. README and engineering journal point to the canonical
document; the implementation remains queued. The historical todo roadmap is preserved.

## Key decisions

- Per-source incoming events determine weapon weights; all components conserve exactly.
- Preserve fractional components through EHP/pressure; integer rounding is a
  presentation or legacy-serialization concern only.
- Confirmed/Probable permit named cards; Possible is Unattributed for matchup without
  changing the M4 correlation. NPC and untyped accounting remain explicit.
- Use pilot defense, including victim return fire on a won fight.
- Reuse deterministic local results in an additive optional v4 input block; retain
  historical AI reports and evidence snapshots.

## Validation and review

Independent explorer reviewed shipped contracts and the completed spec. The material
rounding finding was corrected and focused re-review passed. Exact-rational numerical
oracles, tiny-hit scaling, 200 randomized conservation examples, criterion/test
traceability, Markdown table structure, specification links, and whitespace passed.
No Flutter tests were run because application code was unchanged; the matrix defines
future implementation validation.

## Custody

Existing `.claude/saga/` and `.hermes/` untracked files were left untouched. The task's
documentation is committed atomically. No PR, push, implementation, or deployment was
requested. Technical design and implementation can proceed from the product spec.

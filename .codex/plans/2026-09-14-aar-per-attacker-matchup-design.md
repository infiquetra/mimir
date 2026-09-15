# Milestone 5 technical design plan

Date: 2026-09-14
Baseline: `feature/aar-per-attacker-matchup` at `ed9e1ff`.
Deliverable: `docs/specs/aar-per-attacker-matchup-design.md`.

## Scope and authorization

The user explicitly requests the complete technical design now. This authorizes
the documentation work and required tracking/journal links; application development
and runtime validation remain with the implementation team. Preserve existing
untracked `.claude/saga/` and `.hermes/` files.

## Work

- [x] [P1] Ground the design in the Product spec, handoff, prior designs and code.
  - Agents: `domain_contracts`, `integration_contracts` (read-only explorers).
- [x] [SEQ] Write the six requested sections with exact immutable model/service
  contracts, fractional allocation, lifecycle, prompt shape, UI and TDD units.
- [x] [P2] Independently review domain and integration contracts and AC traceability.
- [x] [P2] Verify worked quantities, local links, numbering, and document structure.
- [x] [SEQ] Resolve findings and update README, journal, todo and checkpoint.
- [x] [CHECKPOINT] Prepare the completed documentation commit with implementation pending.

## Validation

Map AC1–AC28 to the Product's actual F01–F10, Q01–Q10 and V01–V08 identifiers.
Preserve all five scenarios and all 40 D/P/U test cases. Verify mathematical
examples and API grounding; no Flutter runtime-test claims for documentation.

## Review

Completed all six sections, all ten inherited contracts, five scenarios, 28 explicit
AC-to-Product mappings and 40 RED/GREEN test cases. Independent domain and integration
reviews found and resolved classifier precedence, import boundaries, scalar overflow,
atomic backfill writes, per-subject errors, coherent SDE reads, compatibility wrapper
and prompt wording gaps. Explicit cross-window revision detection addresses the last
integration finding. Checked numerical oracles, 200 exact-rational conservation
examples, local links, Markdown tables/fences, JSON example and whitespace. No Flutter
runtime tests were run for this documentation-only task; implementation remains queued.

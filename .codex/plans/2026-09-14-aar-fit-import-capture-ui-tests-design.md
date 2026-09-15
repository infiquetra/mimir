# AAR fit import and capture UI tests — technical design plan

Date: 2026-09-14
Baseline: `develop` at `e4821ce`.
Deliverable: `docs/specs/aar-fit-import-capture-ui-tests-design.md`.

## Scope

The user requests a complete technical design now. Produce the architecture,
minimal bug-fix designs, real screen/service/storage test harness and AC-mapped
TDD units. Application implementation and runtime tests are not part of this
documentation task. Preserve unrelated work and existing historical tracking.

## Tasks

- [x] [P1] Inspect Product, parser/service/storage and current screen/provider code.
  - Read-only agents: `domain_contracts` (strict parser), `integration_contracts`
    (real UI/storage harness and capture/lifecycle).
- [x] [SEQ] Write exact contracts, all three fix designs, concurrency/feedback
  support and work-unit/test traceability.
- [x] [P2] Independently review implementability and Product alignment.
- [x] [P2] Verify all 24 ACs/36 tests, messages, score examples, local links and tables.
- [x] [SEQ] Update README/journal/tracking; retain queued status.
- [x] [CHECKPOINT] Save completion and commit documentation only.

## Review

Completed 2026-09-15. The design specifies the three fixes and their supporting
coordination, feedback and lifecycle contracts, a real storage/transport-boundary
harness, and U0–U5 RED/GREEN/reviewer/tester ownership. Parser and integration reviews
resolved all findings. Document checks cover 24 exact AC mappings, all 36 tests,
nine Product scenarios, 17 exact feedback strings, score oracles, links and tables.
Implementation and runtime verification remain queued; no application code changed.

[Completion checkpoint](../checkpoints/2026-09-15-aar-fit-import-capture-ui-tests-design.md).

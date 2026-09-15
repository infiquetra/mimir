# Exploration Module — Product specification plan

Date: 2026-09-15
Branch/baseline: `feature/exploration-module` at `aec65c6`.
Deliverable: `docs/specs/exploration-module.md`.

## Scope

The user requests the complete authoritative Product specification for phases
4a reference data, 4b public highway connections, 4c local signatures and 4d
routing, including exact contracts, UI, acceptance criteria and test fixtures.
Fit comparison visuals have shipped; no previous implementation holds remain.
No runtime feature implementation, remote publication or mapper integration is
authorized by this documentation task. Preserve unrelated untracked files.

## Tasks

- [x] [P1] Read platform specification, blueprint, roadmap and repository guidance.
- [x] [P1] Inspect current navigation/SDE/location/Intel services with `correlation_contract`.
- [x] [P1] Verify static taxonomy/effects/provenance with `fit_evidence_tests`.
- [x] [P1] Verify current EVE-Scout public endpoint, schema and cache behavior.
- [x] [SEQ] Resolve source conflicts and specify workflows, entities, validation,
  live-cache semantics, local signature lifecycle and deterministic routing.
- [x] [SEQ] Write R/AC identifiers, concrete fixtures and responsive test matrix.
- [x] [P2] Independently review contracts and validate links, arithmetic and coverage.
- [x] [SEQ] Update documentation links/journal, checkpoint and commit documentation.

## Known grounding corrections

- Legacy `/api/wormholes` returns 404; public v2 signatures returns JSON and
  `Cache-Control: public, max-age=300`. The actual schema must govern integration.
- Current app is tray/subwindow based, not the old GoRouter shell. The user chose
  a new tray-launched Exploration window with adaptive navigation between its
  four module views; an app-wide feature-shell migration is outside this scope.
- Local SDE lacks universe/system/gate data and system statics are not an SDE field.

## Validation

Documentation and public read-only contract probes; synthetic test oracles are
requirements for future implementation, not claims of currently passing tests.

## Review

Completed eight requested sections, nine workflows, R1–R32, AC1–AC40,
eight fixture groups and 60 domain/provider/UI cases. Both independent reviews
passed after resolving lifecycle and clock boundaries, parser outcomes and local
connection orientation. Validated exact effect values, twelve route oracles,
unit/resonance arithmetic, fixture JSON, local links, table structure and full
requirement/criterion/test traceability. README/journal identify implementation as
pending and earlier AAR work as shipped. No runtime feature code changed.

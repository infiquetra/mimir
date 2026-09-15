# AAR fit comparison visuals — Product specification plan

Date: 2026-09-15
Baseline: `develop` at `d1114f7`.
Deliverable: `docs/specs/aar-fit-comparison-visuals.md`.

## Scope and authorization

The user explicitly requests codebase review, a comprehensive product specification,
and a commit. Write the artifact and required tracking/journal links. Implementation,
test authoring, PR/push and deployment are subsequent work. Preserve unrelated
`.claude/saga/` and `.hermes/` files and historical records.

## Tasks

- [P1] Inspect the current AAR fit UI, attachment lifecycle and usable presentation seams.
- [P1] Delegate report/recommendation/snapshot provenance inspection to `correlation_contract`.
- [P1] Delegate fitting stats, editor components, inventory and price/BOM inspection to
  `fit_evidence_tests`.
- [SEQ] Define workflows, source separation, deterministic diffs and fair stat comparison,
  desktop/mobile UI, recommendation/BOM semantics, edge cases and bounded non-goals.
- [SEQ] Write acceptance criteria and concrete test fixtures/matrix for Plan/Test-Author.
- [P2] Independently review product contracts while validating numeric examples, test
  traceability, Markdown structure and local references.
- [SEQ] Resolve findings, link README/queue/journal, record completion and commit.

## Validation

Source-grounded document and mathematical checks only; do not claim runtime tests or
feature implementation. Keep this P2 roadmap item queued until implementation ships.

## Review

Completed: `docs/specs/aar-fit-comparison-visuals.md`, S1–S6, AC1–AC30,
16 domain + 14 provider/service + 16 UI cases. Source/history and stat/BOM
reviewers confirmed their findings resolved. Numerical examples, local references,
table structure and full criterion traceability checked. README, queue and journal
linked; implementation remains pending. Checkpoint:
`.codex/checkpoints/2026-09-15-aar-fit-comparison-visuals-product.md`.

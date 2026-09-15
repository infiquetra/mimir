# AAR fit import and capture UI tests — architecture completion

Date: 2026-09-15 (America/Indiana/Indianapolis).
Baseline: `develop`, Product commit `e4821ce`.

## Deliverable and authority

Completed [the technical design](../../docs/specs/aar-fit-import-capture-ui-tests-design.md)
against [Product's contract](../../docs/specs/aar-fit-import-capture-ui-tests.md).
This is documentation only; it does not implement or verify runtime fixes.

## Decisions retained

- AAR-only faithful manifest validation, structure-based EFT/DNA dispatch, local
  category/slot checks, authoritative exact names, and opt-in parser error propagation.
  Shared tolerant consumers retain their default behavior.
- Atomic encounter-row mutations preserve latest pilot evidence and victim ownership.
  Every service writer is field-owned; stale correlation/derived patches cannot
  overwrite a newer fit or send mismatched source and derived inputs to AI.
- Shared encounter attachment/preparation ordering, stable provider-scope commit
  publication, typed feedback, no-module capture limitation and route/generation guards.
- Real screen/services/scorer/deriver/Drift harness with seeded local SDE and scripted
  external ESI/discovery/AI. No final-output mocks in journey tests.
- Existing M4/M5 accounting, confidence separation, nonblocking score policy,
  historical report snapshots and prompt v4 remain unchanged. No migration.

## U0–U5 handoff

1. U0: real harness and deterministic gates.
2. U1: faithful import and shared-parser compatibility.
3. U2: real capture, pagination, metadata and errors.
4. U3: repository retention, analysis snapshot, coordination/publication.
5. U4: real UI journey, lifecycle, live evidence/defenses and accessibility.
6. U5: independent regression gates and implementation closeout.

Each unit specifies Test-Author RED, developer GREEN, reviewer and tester exit gates.
Serialize shared service-file changes; independent test authoring can run in parallel.
All 24 ACs, 36 cases and nine original Product scenarios are mapped in the design.

## Review and verification

- Parser and integration reviewers inspected source and draft independently.
- Findings resolved: late parser errors, authoritative lookup/snapshot, atomic
  mutation outcome, stable publisher lifetime and combined journey-test layers.
- Checked exact AC-to-case mappings, all case/scenario IDs, 17 feedback strings,
  score arithmetic, local links, Markdown tables/fences and whitespace.
- No Flutter suites or app launches ran; no app-code changes.
- README and journal link the design. The P2 queued item remains open for actual
  implementation and runtime verification.

## Workspace custody and next step

Preserved unrelated `.claude/saga/` and `.hermes/` directories. Documentation changes
are committed atomically; resolve the commit with Git history for this checkpoint
rather than embedding a self-referential commit hash here.

Lead/Plan should schedule the units; Test-Author begins the harness and RED regressions.
Do not mark Product's queued item shipped on the strength of this document alone.
The earlier M5 architecture at commit `8884800`, U1–U4 and ten inherited architecture
contracts remains historical context, not this task's unit numbering.

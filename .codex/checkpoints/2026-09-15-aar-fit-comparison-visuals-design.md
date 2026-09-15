# AAR fit comparison visuals — architecture completion

Date: 2026-09-15 (America/Indiana/Indianapolis).
Baseline: `develop` at Product commit `2fe995c`.

## Canonical deliverable

[Technical design](../../docs/specs/aar-fit-comparison-visuals-design.md), grounded
against [Product](../../docs/specs/aar-fit-comparison-visuals.md) and current source.
Architecture delivery only: no application code or runtime test execution.

## Decisions to retain

- Immutable copied snapshots with independent source identity, semantic fingerprints,
  per-group knowledge, physical-versus-order-only positions and unresolved/unplaced
  inventory. Defaults and parser success do not establish completeness.
- Separate comparison-owned JSON slots for current capture and user proposal;
  comparison-only row evidence projection prevents first writes changing the score.
  Field-scoped CAS, explicit false-to-real packet initialization and value-keyed
  projection preserve concurrent evidence/comparison writes.
- Stable post-commit publication plus race-safe per-connection local observation;
  service-local locks and Drift notifications alone are not multiwindow correctness.
- New report v3 generation record binds actual prepared copied inputs before AI.
  Optional input v4/candidate extensions preserve legacy prose. Client controls
  origin/validation; invalid optional candidates never discard the report.
- Stale advice compares current versus generation-supplied pilot attachment,
  distinct from a legitimate own-victim derivation fallback and candidate origin.
- Neutral shared Dogma computation, explicit diagnostics and snapshot-knowledge
  qualification; one common skills/profile/SDE frame. No fake proposal evidence,
  duplicate simulation math, raw-default availability or stale numeric frames.
- Pure exact multiset diff and global type-count BOM; no automatic upgrade badge.
  Common profile choices are cache-only and cannot trigger correlation backfill.
- Cached asset credit needs eligibility and coherent disjointness proof; changed
  instance IDs alone are insufficient. Price-only refresh uses ESI average estimates,
  ≥24-hour staleness and explicit partial priced coverage.
- Read-only responsive workspace, separate proposal dialog, all eight groups,
  scoped submission/navigation safety, no raw EVE IDs, no active-editor mutation.

## Work units

- W0 contracts/fixtures and real harness.
- W1 owned storage, acquisition, observation and projection.
- W2 generation and optional structured proposal contract.
- W3 deterministic inventory diff and physical BOM.
- W4 neutral computation, diagnostics and common-context metrics.
- W5 cached prices/spares and qualified annotations.
- W6 read-only provider/UI workspace and dialogs.
- W7 integration, independent verification and closeout.

W-prefix distinguishes these units from Product U01–U16 UI cases. Shared service/
model edits need one integrator; independent domain/test work can run in parallel.
The design includes Test-Author RED, developer GREEN, reviewer and tester gates.

## Review and verification

Both independent reviewers passed after resolving completeness qualification,
canonical tie order, raw-source loss, local proposal validation, fallback staleness,
observation races, cache-only profile selection, parsing cancellation and stock
overlap proof. Checked all 30 AC mappings in both directions, all 46 D/P/U cases,
six original workflows, 12 feedback strings, F2/F3 arithmetic, JSON examples,
local links, tables and whitespace. No runtime passing-test claims.

README/journal link the design; the P2 initiative stays queued until implemented and
verified. Preserve unrelated `.claude/saga/` and `.hermes/`. Resolve this checkpoint's
documentation commit through Git history; no self-referential hash is embedded.

Next: Lead/Plan schedule and re-estimate W0–W7; Test-Author starts RED at real seams.
Earlier M5 and attachment designs remain historical contracts, not pending rework.

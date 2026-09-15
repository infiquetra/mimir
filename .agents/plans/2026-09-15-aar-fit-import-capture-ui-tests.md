# AAR Fit Import and Capture UI Tests — Implementation Plan

## Goal

Harden the AAR fit-attachment journey (QUEUED.md P2) with test-led proof plus the smallest
fixes the contracts demand: accepted fit content must survive from user action through
enrichment storage, live evidence/defense refresh, and explicit re-analysis; failed
attachment must preserve prior evidence with useful feedback; attachment must never
automatically spend an AI request. Ship 36 test cases (T01–T36) satisfying all 24
acceptance criteria (AC1–AC24), fix the three source-evidenced defects (colon-based
EFT/DNA dispatch, silent-loss import validation, forced-refresh fit eviction), and keep
the queued item open until tests and fixes are verified together.

## Success Criteria

**Acceptance contract (product §4 — all 24 must hold):** AC1 live Import/Use-Current-Fit
from Missing/Inferred rows in both screen states, no resurrected unconfirmed button;
AC2 dialog title/field/actions/keyboard; AC3 cancel/dismiss/Escape/blank silent no-ops;
AC4 faithful supported-EFT persistence with pilot/manualFitImport/confirmed/UTC metadata
(header-only valid); AC5 import without authenticated character, capture never falls back;
AC6 malformed/non-ship/unknown/local-data failures never persist or show success; AC7
colon headers parse as EFT, real DNA still works; AC8 no silent drops (unresolved entries,
ammo suffix); AC9 confirmed capture uses encounter character, ship item ID, every asset
page, mapper semantics; AC10 failure modes preserve evidence with no partial save; AC11
hull-only snapshot distinguishable with empty-modules limitation + qualified success;
AC12 reference compatibility, Inferred when derivable, confirmation refetches; AC13 no
success before commit, failed writes retain prior row, derivation failure reported
separately; AC14 correct-encounter round-trip, enrichment fields + single pilot-fit fact
preserved; AC15 real scorer outcomes (0/9/15/30, never automatic Complete/+30); AC16 real
provider refresh of checklist + M5 defense with incoming allocation retained; AC17 no
auto AI/discovery, historical provenance unchanged, banner ≥10 rule; AC18 re-analysis
retains fits through all refresh branches into derivation + AI boundary; AC19 AI failure
preserves prior report + fit, retry works; AC20 exact §3.3 feedback, retry clears failure;
AC21 one in-flight attachment, busy state, analysis barrier, no stale overwrite; AC22 no
disposal/cross-encounter/late-snackbar lifecycle faults; AC23 names/honest labels, never
raw IDs or transport traces; AC24 loading/error states, 360px/desktop/200%, gate never
disabled by score.

**Test contract (product §5 — all 36, W+I/D as specified):** T01–T12 faithful import;
T13–T20 capture/reference; T21–T30 persistence/refresh/re-analysis; T31–T36
presentation/availability. Every W+I case crosses the real persistence boundary; no
counter-only fakes substitute for storage journeys. Score oracle: with all dimensions
available and others Complete, Missing/Inferred/Partial/Complete pilot fit → 70/79/85/100
overall (earned 0/9/15/30); reduced-denominator fixture (other weight 40 earning 25) →
36/49/57/79.

**Architectural invariants:** encounter ownership (character + id, no global fallback);
faithful import or pre-write rejection; intentional-empty valid; exact provenance
metadata; no success/publication/score before commit; refresh never deletes attachments,
older snapshots never replace newer; confirmation/identity/coverage/derivation
independent; no implicit AI/discovery; historical report untouched until successful
explicit analysis replaces it; one attachment per encounter with analysis barrier;
safe lifecycle; no migration/schema/prompt/output changes, no new reference-capture button.

**Verification bar:** focused suites + full `flutter test` green, `flutter analyze` clean,
`dart format` clean on changed files, ≥80% coverage on new logic with 100% of critical
retention/validation/failure branches, macOS spot-check of dialog/snackbar/checklist,
journal + QUEUED updated in the same change set.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/aar-fit-import-capture-ui-tests.md`
(Product contract, commit `e4821ce`: 24 ACs, 36 cases, §3.3 exact feedback copy),
`docs/specs/aar-fit-import-capture-ui-tests-design.md` (Technical design, commit
`705f2e6`: three bug fixes, seams, harness, U0–U5 ownership, §6.4 validation),
`.codex/checkpoints/2026-09-14-architect-handoff.md` (inherited contracts),
`docs/engineering-journal/QUEUED.md:64` (P2 item with product + architecture handoffs,
still queued), live code at `develop` `705f2e6` (branch verified): `combat_enrichment_service.dart:168`
(`rawFit.trim().contains(':')` DNA dispatch), `analysis_multipane_screen.dart:60-61`
(live `onUseCurrentFit(confirmed: true)` + `onImportFit` handlers), `:135`/`_showImportFitDialog`,
`:537`/`:548` Re-analyze paths, `combat_analysis_service.dart:155-243` (`forceRefresh`
plumbing), plus `combat_enrichment_repository.dart`, `format_parser.dart`, `sde_service.dart`.

**Three defect fixes (design §1, minimal implementation):** (1) EFT-vs-DNA detection —
structure-based dispatch in a new `AarFitImportParser` (first nonempty line starts with
`[` → EFT; otherwise strict DNA grammar; colon never a discriminator); (2) strict AAR
acceptance — faithful-content manifest validation (hull category 6; modules category 7 +
explicit slot effects 11/12/13/2663/3772; drones 18; fighters 87; unique normalized exact
name match; post-parse comparison) before any write, shared parser stays tolerant;
(3) atomic retention — `mutateEnrichment` read/transform/write transactions with
preconditions, field-ownership merge (attachment/discovery/correlation/derived writers),
conservative victim-packet policy, stale-input retry (≤3 attempts), encounter-scoped
`AarEvidenceOperationCoordinator` + analysis barrier, provider-owned commit publication.

**Existing tests (reuse, not proof):** `analysis_multipane_evidence_test.dart` (T8.3/T8.4,
H.7–H.9 dispatch/banner), `aar_evidence_checklist_card_test.dart` (actions/refresh),
`combat_enrichment_service_test.dart` (D.9 search-state), `combat_fit_snapshot_mapper_test.dart`
(slots/charges/drones/fighters), `format_parser_test.dart` (formats). The current screen
fake manufactures Complete evidence on capture and bypasses ESI/SDE/mapping/storage —
it stays as labeled dispatch coverage only.

**Score/provenance rules preserved:** scorer table (Missing 0 / Inferred 9 / Partial 15 /
Complete 30 of weight 30); overall `round(100 × earned / available)`; banner extra action
only at ≥+10; legacy `Evidence at generation: not recorded`; T26/T27 require the real
analysis/refresh flow with a recording fake Codex client.

## Invariants & Non-Goals

**Invariants (design §1.1, binding on every unit):** encounter ownership; faithful import;
intentional absence ≠ dropped content; evidence provenance (role/source/confidence/UTC
time/limitations); save boundary (commit precedes success/publication/score); retention
(no refresh deletion, no older-over-newer); confidence separation (confirmation, identity,
coverage, derivation independent — missing simulation attributes ≠ unknown item); explicit
analysis only; historical report immutability; one attachment per encounter + barrier;
lifecycle safety (started saves finish for original encounter; no disposed-Ref, cross-key,
or late-snackbar faults); compatibility (no Drift migration, JSON break, prompt bump,
output change, or new reference button). M4 correlation and M5 allocation math unchanged:
per-attacker + unattributed + NPC still equals aggregate incoming; attachment changes
defense input, never the recorded allocation.

**Non-goals (product §6.3 / design §7):** no fit editor, multi-fit comparison, new
snapshot UI, or auth flow; no replacement UI for Partial/Complete, inline validation,
restored reference button, or confirmation modal; no shared-parser language expansion
(EFT ammunition/cargo/subsystems, DNA inventory, legality engine); no historical-ship
reconstruction; no ESI-wide error refactor, live credentials, auto search/analysis, or
prompt-schema change; no scorer/correlation/M5-math/provenance-threshold changes; no
persistent matchup cache, schema migration, background-task framework, multi-process
coordinator, or automatic killmail replacement; no repo-wide raw-ID cleanup (exercised
surfaces still meet the name contract). Fit-name commas stay unsupported (existing
last-comma split preserved). Any required expansion returns to Product/Lead with the
failing contract — tests are never weakened to fit implementation.

## Key Architectural Decisions

Ten decisions distilled from design §1.1–§1.4, §2–§4 (alternatives rejected in Why):

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | Format dispatch | Structure-based: leading `[` → EFT; else strict DNA grammar | Colon-contains heuristic / DNA fallback after malformed EFT | Colon appears in valid fit names (`[Rifter, PvP: Armor]`); fallback would misroute corrupt EFT into DNA instead of rejecting it. |
| 2 | Strictness boundary | New AAR adapter (`AarFitImportParser`) validates manifest + compares post-parse; shared `FittingFormatParser` keeps tolerant defaults via opt-in `resolveTypeIdByName` / `rethrowFailures` | Making the shared parser strict | Other callers depend on tolerant skipping (generic unknown-DNA test stays); AAR evidence needs faithful-or-reject without breaking them. |
| 3 | Structural identity | Local `getType`/`getGroup`/`getTypeEffects`: hull cat 6, module cat 7 + explicit slot effect, subsystem 32, drones 18, fighters 87; unique normalized exact name match | Positive-ID / `getShipTypeName` / 20-result partial search as proof | Positive IDs accept non-ships; the 20-result search cannot prove unknown and could lose a validated name — an exact-match index loaded per import closes both. |
| 4 | Atomic writes | `mutateEnrichment` transaction (load → precondition → pure transform → key check → save); all service writers route through it; `unchanged` skips upsert/publication | Whole-row `_save` after async work / service-instance lock | Stale whole-row writes evict attachments (the T26 retention gap); Drift transaction ordering is the shared serialization boundary across instances. |
| 5 | Refresh merge policy | Field ownership per writer; pilot evidence always from latest row in-transaction; conservative victim-packet retention (same identity merges, empty/ambiguous/different retains old packet + search-completed) | Candidate wholesale replacement / transplanting old victim fit under new ID | Refresh must retain attachments; transplanting breaks victim-identity binding the deriver relies on. |
| 6 | Stale derived/correlation guards | Killmail/raw-input match check for correlation; value-based derivation-input key with `committed`/`staleInput` result; analysis re-prepares (≤3 attempts) before AI | Sending old bundle beside new fit / unbounded retry | Mismatched fit+bundle inputs would fabricate analysis; the cap plus intact report/attachments keeps failure recoverable. |
| 7 | Coordination + barrier | Encounter-keyed `AarEvidenceOperationCoordinator` (synchronous reserve, busy rejection, `finally` settle); real `CombatAnalysisService` preparation queues behind pending attachment, releases before AI | Screen-only barrier / fake-only barrier / holding transactions while waiting | Both Re-analyze controls + direct-service tests must honor ordering; screen fakes cannot prove it; waiting inside a transaction blocks readers. |
| 8 | Capture semantics | Encounter-character binding, complete pagination (`x-pages`, invalid count = failure), no partial saves; empty success → persisted limitation + qualified message | Global-character fallback / page-one save / empty-as-error | Wrong-character snapshots and partial inventories are silent evidence corruption; empty-after-success is honest hull-only evidence, not a failed read. |
| 9 | Error presentation | Typed stage failures + one presentation formatter mapping codes to Product's exact copy; ESI-collapsed nulls get no-ship message, never inferred auth | Interpolating `exception.toString()` into snackbars / inferring lost causes | Raw `FormatException:`/Dio traces in goldens are unstable and user-hostile; causes collapsed to null by the real client cannot be recovered truthfully. |
| 10 | Publication + lifecycle | Provider-owned `onEnrichmentCommitted` via app-scope `aarEvidenceCommitPublisherProvider` (`alive` flag, no-op after scope disposal); screen captures generation/route identity, guards after every await; dialog owns its controller | Handler-side post-await invalidation / parent-owned dialog controller | Screen-alive-dependent publication misses background commits and risks dead-Ref access; parent-owned controllers can be disposed mid-transition. |

**Product D1–D8 preserved verbatim:** live-actions-only (reference at service layer);
faithful-or-rejected import; no parser expansion (colon fix + ammo rejection at AAR
boundary); empty-vs-failed inventory distinction; local-SDE import fallback; save →
refresh → offer-analysis; one attachment at a time + barrier; understandable errors.

## Recommended Approach

**Harness first, then defects in dependency order, then UI on the stable contract.**
U0 builds the only thing every later unit needs (owned databases, scripted ESI, real
screen, recorders, reopen fixture) and pins reachability without fixing behavior
covertly. U1 and U2 fix the two input boundaries in parallel (import adapter; capture
sequence) since they touch different production seams. U3 is the serialization point:
`mutateEnrichment` rewrites every writer, so it follows the service changes and gates the
real-journey GREEN. U4 composes the now-stable coordinator/publication contract into
dialog/screen guards, busy state, formatter, and live-evidence journeys. U5 verifies the
whole. Within **each unit**: test-author writes failing tests (RED) → review → dev
implements the minimal fix (GREEN) → REFACTOR. A test may pin already-correct behavior
without failing, but every identified defect needs a failing regression recording the
assertion and cause — never just a compile failure or a final-output mock.

## Work Plan

Units are **[SEQ]** sequential or **[P1]/[P2]** parallel per design §6.1. U0 first; U1+U2
test-authoring in parallel after fixture interfaces stabilize (shared
`combat_enrichment_service.dart` production edits serialized or single-integrator); U3
follows service changes; U4 isolated dialog/layout tests alongside U3, real-journey GREEN
after U3's contract; U5 sequential last. No concurrent uncoordinated ownership of shared
service/provider files; no deferring all fixes to closeout.

### [SEQ] U0 — Real test harness

**Tests first (test-author, RED).** Build `test/features/combat_analyzer/fixtures/fit_evidence_harness.dart`
(`FitEvidenceHarness`): harness-owned `AppDatabase` + `SdeDatabase` (in-memory) outside
widget scope; real repositories/parser/mapper/services/scorer/M5 composition; scripted
Dio transport for real `EsiClient`; controlled discovery + AI clients; deterministic
clock, completers, counters, captured AI input; themed `MaterialApp` + real
`AnalysisMultiPaneScreen` in `ProviderScope(overrides: …)` with navigation host +
encounter-replacement helper. RED = harness assembly + reachability pins (live row
actions in both views, baseline round-trip) failing on missing seams — not on behavior.

**Dev (GREEN).** Only DI/test seams the harness needs (providers accepting owned
databases, scripted transports, recorders); no behavioral defect fixes. Own harness +
shared helpers.

**Gate (reviewer/tester):** reviewer rejects final-result substitutes (overriding
enrichment/fit/score/allocation/matchup for journey tests); tester proves actual SQL
reload, teardown order (widgets → ESI error-limit subscription → databases), forbidden
network assertions (unexpected HTTP fails), `tester.takeException()` clean.

**Owner:** test-author + dev-1 (harness). **Surfaces:** new fixture file, provider
override seams only.

### [P1] U1 — Faithful import (after U0 interfaces)

**Tests first (RED): T04–T10, T12.** Colon header `[Rifter, PvP: Armor]`; mixed/all-unknown
modules + invalid stacks; `, Ammo` suffix; malformed/unknown/non-ship hull; header-only;
supported DNA compatibility; parser manifest + exact-lookup edges (valid match beyond 20
partial results, later-lookup failure, exception-vs-unknown distinction); invalid→reopen→valid
(T12, shared with U4). Each identified defect gets a failing regression with recorded
assertion + cause.

**Dev (GREEN).** New `lib/features/combat_analyzer/data/aar_fit_import_parser.dart`
(dispatch §3.1, manifest §3.2, 256 KiB / 4,096-module / int32-quantity bounds, SDE read
transaction, post-parse comparison, `AarFitImportException` codes); additive
`FittingFormatParser(resolveTypeIdByName, rethrowFailures)` seam (defaults preserve
tolerance); local exact-name lookup helper; `importPilotFit` validation callsite +
atomic attachment mutation; existing generic hull message preserved.

**Gate:** reviewer checks supported grammar + strict/tolerant boundary; tester runs
adapter, shared-parser, service-import suites + real dialog journeys; existing
format-parser + D.9 suites green.

**Owner:** test-author (RED) → dev-1 (adapter). **Files:** new adapter, `format_parser.dart`
(additive), `combat_enrichment_service.dart` (import path — serialized with U2).

### [P1] U2 — Capture & typed failures (after U0 interfaces, parallel with U1)

**Tests first (RED): T13–T20 + T34 capture rows.** Two-page assets + later nested charge,
unrelated ships, global-B vs encounter-A binding; page failures; null character; null
ship / direct 401 / collapsed transport (truthful distinct copy); empty inventory;
reference service compatibility + live reload (no private-false-handler UI call);
reference-A → confirmed-B upgrade; typed-feedback + logging rows.

**Dev (GREEN).** Capture sequence hardening (character → ship → all pages → mapper →
metadata → atomic mutation); pagination completeness (`x-pages`, invalid count fails, no
partial save); empty-modules limitation + qualified success (reference mode keeps old
copy); typed stage failures with existing direct-service messages; ESI error semantics
unchanged (no global rewrite).

**Gate:** reviewer checks no partial inventory/save + actual ESI error semantics; tester
validates transport scripts, real mapping, old-row retention on every failure.

**Owner:** test-author (RED) → dev-2 (capture). **Files:** `combat_enrichment_service.dart`
(capture path — serialized with U1), feedback classification seam.

### [SEQ after U1+U2] U3 — Atomic retention & analysis barrier

**Tests first (RED): T11, T21, T22, T26, T27, T30.** Repository save failure + real SQL
trigger abort; scope disposal/reopen durability + encounter-B isolation; replacement
preserving killmail/victim/correlation/search/custom facts + single pilot fact; forced
re-analysis retention (manual: matched/no-match/no-character; captured: matched/no-match;
victim same-packet + empty/conflicting preservation; ambiguous/reauth supplemental) with
assertions in committed enrichment + derivation inputs + actual AI-bound args; AI
failure → prior report + fit retained, retry records new snapshot; concurrency
(double-tap, competing actions, analysis-during-save, slow-discovery interleave, stale
correlation/derived patch, two-service race, service-provider recreation mid-save).

**Dev (GREEN).** `CombatEnrichmentRepository.mutateEnrichment` + audit routing of every
`_save` (early returns included); field-ownership merge + ledger fact/unknown identity
(`ev-pilot-fit-<id>` replace, `ev-derived-*` removal on input change, exact ownership
removal — no substring filters; explicit clears, never `copyWith(field: null)`);
victim-packet policy; correlation/derived stale guards + `DerivedEvidenceCommit`
(`staleInput` → re-prepare ≤3); `AarEvidenceOperationCoordinator` + real-service analysis
barrier (release before AI); `onEnrichmentCommitted` + `aarEvidenceCommitPublisherProvider`
wiring; remove duplicated handler invalidation.

**Gate:** reviewer audits every production write + snapshot consistency (AI client,
ledger, scorer, M5 block reference one snapshot; late attachments never rewrite old
enrichment); tester runs independent real-SQL-failure, two-service races, AI
failure/retry, legacy-JSON round-trips.

**Owner:** test-author (RED) → dev-1 (repository/merge) + dev-2 (coordinator/barrier, coordinated).

### [SEQ after U3 contract] U4 — UI lifecycle & live evidence

**Tests first (RED): T01–T03, T23–T25, T28–T36 (T12/T30 shared).** Real dialog in both
views; cancel/dismiss/Escape + blank silent no-ops; scorer 0/9/15/30 + reduced
denominator (40→25: 36/49/57/79); save-success vs delayed/failed derivation; banner
+9/+10/same-score/legacy; M5 defense delta (MSE +1,100 shield HP, EHP from fixture
weights — no averaged shortcut) with allocation/coverage/identity equality; dispose/switch
lifecycle (no `takeException`, late snackbar, B-row mutation); loading/error checklist
states; 360px/desktop/200%/keyboard; name loading/error/recovery without raw IDs; exact
typed feedback + logging; zero AI/discovery on open/attach/reload/expand; state-policy
actions + ≥90 collapse in both views.

**Dev (GREEN).** Extract `ImportPilotFitDialog` (owns controller, unchanged semantics,
scrollable viewport-constrained content); screen guards (captured identities, mounted/
generation/route checks incl. post-dialog pre-read + `didUpdateWidget` A→B); checklist
disabled/busy input (null-handler policy kept); exact §3.3 feedback formatter; stable
command-strip Re-analyze key distinct from `aar-provenance-reanalyze`; compose U3
operation state without bypassing the service barrier.

**Gate:** reviewer checks accessibility, no raw IDs, no implicit network/AI; tester runs
widget/provider journeys + desktop manual verification (dialog focus, Escape, both views,
pending behavior, names, cached refresh).

**Owner:** test-author (RED) → dev-2 (UI). Isolated dialog/layout RED may run [P2]
alongside U3; journey GREEN after U3.

### [SEQ] U5 — Closeout & Journal

**Dev + tester.** Fill missing AC/branch coverage; preserve failing evidence for unfixed
issues (no converting failures to expected behavior); resolve scoped review findings;
run focused suites → full `flutter test` (pre-existing failures reported separately) →
`flutter analyze` → `dart format --output=none --set-exit-if-changed` on changed files;
coverage ≥80% new logic, 100% critical branches (exclusions documented); macOS spot-check
(dialog, snackbar, checklist). Update journal/README + QUEUED (archive SHIPPED only with
implementation + verification evidence) in the same change set.

**Gate:** reviewer confirms AC1–AC24 matrix + narrow diff; tester records suites, static
analysis, device evidence, limitations. **Owner:** reviewer + tester, dev support.

## Validation Plan

Each unit's gate is **RED before GREEN** — implementation is blocked until the unit's
test-author suite is observed failing for the named reason (recorded assertion + cause,
not bare compile failure or final-output mock). Existing suites are regression-locked.

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| U0 | Harness assembly + reachability pins — fail: missing DI seams | Harness + seams only | `flutter test test/features/combat_analyzer/fixtures/` (new harness self-checks) → GREEN; SQL reload + teardown + no-unexpected-HTTP proven |
| U1 | `aar_fit_import_parser_test` + T04–T10/T12 — fail: colon→DNA, silent drops, ammo strip, non-ship accept | Adapter + seam + callsite | `flutter test test/features/combat_analyzer/data/aar_fit_import_parser_test.dart test/features/fitting/domain/format_parser_test.dart test/features/combat_analyzer/data/combat_enrichment_service_test.dart` → GREEN; tolerant-parser tests unchanged |
| U2 | T13–T20 + capture T34 rows — fail: partial saves, fallback, unqualified empty, untyped errors | Capture + classification + notice | `flutter test test/features/combat_analyzer/data/combat_enrichment_service_test.dart test/features/combat_analyzer/domain/combat_fit_snapshot_mapper_test.dart` (+ new capture journey file) → GREEN; old-row retention on every failure |
| U3 | T11/T21/T22/T26/T27/T30 — fail: refresh eviction, stale overwrite, unguarded races | `mutateEnrichment` + merges + coordinator + barrier + publisher | `flutter test test/features/combat_analyzer/data test/features/combat_analyzer/domain` → GREEN; real-SQL-trigger + two-service-race + AI retry cases pass |
| U4 | T01–T03/T23–T25/T28–T36 — fail: missing dialog/guards/busy/formatter/live refresh | Dialog + guards + formatter + keys | `flutter test test/features/combat_analyzer/presentation` → GREEN; MSE +1,100 delta, banner thresholds, 360px/200% cases pass |
| U5 | — (docs review + full verification) | Journal + closeout | `flutter test` (full) GREEN; `flutter analyze` clean; `dart format --output=none --set-exit-if-changed` on changed files clean; coverage gates met; `git diff --stat docs/engineering-journal/` shows QUEUED→ARCHIVED SHIPPED |

**Highest-risk validation:** T26 forced re-analysis retention (U3) — if any refresh
branch (matched/no-match/no-character/ambiguous/reauth) or any unconverted `_save` still
writes a stale whole row, the attached fit silently vanishes and only the three-place
assertion (committed enrichment + derivation inputs + actual AI-bound args) catches it.
Second-risk: T30 stale-writer races — a service-instance-private lock would pass
single-instance tests and fail only the two-service case.

## Risks / Rollback

- **Shared-service edit collisions (U1/U2).** Both units touch
  `combat_enrichment_service.dart`. *Mitigation:* serialize production edits or assign one
  integrator with separate patches; test-authoring parallelizes freely. Rollback: revert
  to the pre-unit service file; RED suites re-fail honestly.
- **Unconverted `_save` writer (U3).** One missed call site (incl. early returns) reopens
  the eviction hole. *Mitigation:* reviewer audits every production write; T26 spans all
  branches; real-SQL-trigger test proves rollback. Rollback: route the missed writer
  through `mutateEnrichment` in a follow-up patch.
- **Whole-row CAS conflicts under contention (U3).** Concurrent writers contend on one
  encounter row. *Mitigation:* short transactions, merge-only-fresh-reads, stale→re-prepare
  (≤3); SQLITE_BUSY on second connections = failed/rolled-back write or full retry from
  fresh read. No multi-process sync added.
- **Barrier deadlock/reentrancy (U3).** Preparation re-entering its own queue, or
  transactions held while waiting. *Mitigation:* internal patches run within preparation
  without re-entry; no transaction held across waits; failed attachments settle normally.
- **Harness-owned vs TestApp-private databases (U0).** Reopen loses data if a new scope
  gets a fresh DB. *Mitigation:* T21 pins same-storage reopen; symptom table in design
  §5.6 guides triage.
- **Feedback-copy drift (U2/U4).** 13 exact strings must match Product §3.3. *Mitigation:*
  single formatter + T34 snapshot of every category; direct-service messages asserted
  separately from UI formatting.
- **`copyWith(field: null)` no-clear trap (U3).** Null-coalescing silently retains stale
  state. *Mitigation:* explicit merge helpers for clearing; reviewer checks each merge.
- **Estimate risk (flagged by Product §1).** Queue says half-day to a day, but three
  defects + harness + 36 cases exceed a small coverage addition. *Mitigation:* U0–U2 RED
  first makes the real scope visible early; Plan resurfaces the estimate to Lead if GREEN
  exceeds it rather than shrinking coverage.

## Execution Steps & Role Handoffs

1. **Kickoff (Lead).** Confirm branch from `develop@705f2e6`; assign owners per unit;
   test-author + devs agree on fixture interfaces (`FitEvidenceHarness` API, recorder
   shapes, encounter identities) before parallel RED begins.
2. **U0 RED→review→GREEN (test-author → reviewer → dev-1).** Harness + reachability RED
   lands; reviewer confirms no final-output overrides; dev-1 adds DI seams; tester proves
   SQL/teardown/network gates. U0 GREEN unblocks U1/U2 RED.
3. **U1 + U2 RED in parallel [P1] (test-author, two tracks).** RED suites land with
   failing assertion + cause per defect; reviewer confirms each defect has its regression.
4. **U1 + U2 GREEN serialized (dev-1 adapter/import, dev-2 capture/feedback).** One
   integrator sequences `combat_enrichment_service.dart` edits; reviewer checks
   strict/tolerant boundary + ESI semantics; tester runs adapter/parser/service/mapper
   suites. Both GREEN unblock U3 RED.
5. **U3 RED→GREEN [SEQ] (test-author → dev-1 + dev-2 coordinated).** Retention/race RED
   lands; repository + merge + coordinator/barrier/publisher GREEN; reviewer audits every
   write + snapshot consistency; tester runs SQL-trigger, two-service, AI-retry,
   legacy-JSON cases. U3 GREEN unblocks U4 journey GREEN (U4 isolated RED may run [P2]
   alongside U3).
6. **U4 RED→GREEN (test-author → dev-2).** Dialog/lifecycle/evidence RED lands; dialog
   extraction + guards + formatter + keys GREEN; reviewer checks a11y/IDs/no-implicit-IO;
   tester runs widget/provider journeys + desktop manual pass.
7. **U5 closeout [SEQ] (all).** Coverage fill, full suite + analyze + format, macOS
   spot-check, journal/README/QUEUED update in the same change set; reviewer confirms
   AC1–AC24 matrix; tester records evidence, device results, and limitations.

**Handoff protocol per unit:** test-author posts RED (IDs + failing assertions + causes +
missing seams) → reviewer approves RED scope → dev implements minimal GREEN (no covert
extra fixes; newly found defects get new RED first) → reviewer checks contract +
regression risk → tester independently runs and records the gate → Lead advances the unit.
Findings requiring scope expansion return to Product/Lead with the failing contract —
tests are never weakened.

## Open Questions

None after local discovery — every behavior, seam, message, threshold, and test ID is
closed by the product contract (§1–§6), the technical design (§1–§7), and the `705f2e6`
probed codebase. The estimate tension (queue half-day vs. three-defect scope) is carried
as an explicit risk with an early-visibility mitigation, not a blocker.

---
*Plan file:* `.agents/plans/2026-09-15-aar-fit-import-capture-ui-tests.md` — canonical body is the reply above. Reviewer prompts: verify structure-based dispatch (no colon heuristic), manifest + post-parse comparison before write, every `_save` routed through `mutateEnrichment`, victim-packet policy on all refresh branches, barrier in the real analysis service (not fakes), publication surviving scope disposal, and zero raw EVE IDs on exercised surfaces.

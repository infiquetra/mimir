# AAR Fit Comparison Visuals — Implementation Plan

## Goal

Ship QUEUED.md P2 "Fit comparison visuals for AAR reports": a read-only comparison
workspace over preserved source inputs that lets the pilot compare fight fit, current
snapshot, killmail victim fit, and proposed/reference fits side by side — with
deterministic diffs, common-context stat deltas, and a qualified bill of materials —
without ever mutating evidence, the active fitting editor, or historical reports.
Deliver the data contracts that make the visuals truthful (immutable snapshots, owned
comparison storage, generation binding, neutral calculation, additive candidate schemas),
46 test cases (D01–D16, P01–P14, U01–U16) satisfying all 30 acceptance criteria
(AC1–AC30), and keep the queued item open until implementation, independent
verification, and signoff are complete.

## Success Criteria

**Acceptance contract (product §8 — all 30 must hold):** AC1 reachable pre-analysis
and in Fits tab with no AI call to render; AC2 four roles accurate incl. own-loss
dedup, victory opponent, unknown identity; AC3 comparison persistence independent of
evidence/victim/saved/editor/report/score; AC4 new reports bind actual generation fit,
stale advice on content change at same score, legacy disclosure; AC5 explicit stable
selection, no proposal merging, origin preserved, saved-copy isolation; AC6
empty/not-recorded/unresolved/N-A distinguishable, hull-only/legacy never imply
knowledge; AC7 all capture/import failure modes retain prior state with §7.3 feedback,
no false success; AC8 atomic ownership, generation binding, stale guards across
refresh/taps/navigation/disposal; AC9 only validated structured content yields complete
proposal/BOM, prose preserved otherwise; AC10 v3/v4 compatibility, round-trips, no AI
stat or proposal item becomes an evidence fact; AC11 deterministic stable diffs
(order/permutation invariant); AC12 correct configuration/quantity details, moves never
purchases, unknown charges unquantified; AC13 no cross-hull slot replacements,
qualified incomplete wording, unresolved entries retained; AC14 one declared context
(skill/profile/revision) per comparison, no stale figures under new headers; AC15
shared-profile EHP + percentage-point resist deltas matching §9.1 fixtures pre-rounding;
AC16 theoretical DPS/volley rows with charge/deployment assumptions exposed; AC17
meaningful cap units/transitions, visible simulator limits, burst/peak labels,
Sustained = Not modeled; AC18 no confident badges/zeroes/NaN on unknown/failed inputs,
capacity warnings never certify legality; AC19 exact Changes/Full-replacement counts,
cross-group aggregation, no destroyed-ownership or resale credit; AC20 only explicit
quantities in totals, generic/unknown charge-cargo separate; AC21 pilot-scoped cached
assets with freshness/eligibility limits, disjoint eligible loose stock only; AC22
cached ESI-average estimates with timestamps, ≥24h stale flag, gross values, priced
coverage (no free/adjusted/total mislabels); AC23 offline local comparison works,
price-only refresh, failures never remove available content or trigger unrelated sync;
AC24 §4.1 breakpoints usable, 320px/200% without horizontal page overflow; AC25
headers with source/subject/hull/confidence/times/warnings, never raw IDs; AC26 all
eight groups with quantities/charges/offline states, icons + fallbacks; AC27
text+icon+color badges, keyboard/touch details, working Changes-only; AC28 aligned/
stacked stat rows, visible assumptions, tradeoffs without winner claims; AC29 readable
BOM (target/baseline/mode/counts/removals/unknowns/shortfall/coverage) with correct
Full-replacement defaults; AC30 exact §7.3 feedback on committed outcomes, scoped
accessible busy/error states, read-only interactions leave evidence/editor unchanged.

**Numerical oracles (product §9.1 F1–F5, asserted at domain precision before rounding,
then separately as locale-aware presentation):** F1 — one unchanged A, one modified A
(state/charge), B→C replacement (recorded slots only; order-only → separate
removed/added), −2 drones, +50 Ammo/+20 Paste; Changes BOM `C ×1, Ammo ×50, Paste ×20`,
removals `B ×1, D ×2`, no A purchase, Y quantity unknown; tie variant pairs X→W and Y→Z
(W<X<Y<Z) under all input permutations. F2 — Changes `C ×1, Ammo ×50, Paste ×20`,
Full `H ×1, A ×2, C ×1, Ammo ×150, Paste ×20`; prices H=100M, A=1M, C=2M, Ammo=10, Paste
unavailable → Changes priced subtotal **2,000,500 ISK** (2/3 lines), replacement
**104,001,500 ISK** (4/5 lines), neither a total; eligible stock `C ×1, Ammo ×30,
Paste ×5` → shortfall `C ×0, Ammo ×20, Paste ×15`, priced shortfall **200 ISK** (Paste
excluded); destroyed baseline gives no credit; H2 variant adds `H2 ×1`/removes `H ×1`.
F3 — three 1,000 HP layers, resists 50/20/40/10 → 60/20/50/10: EM-100% EHP 6,000 →
7,500 (**+1,500, +25%**), EM **+10 pp**/layer; Omni 4285.714285… → 4615.384615…,
delta 329.670329… (**7.692307…%**). F4 — 120s depleting → 35% stable reads
**Depleting → Modeled stable** (never −85); burst 100 HP/s, peak passive 20 HP/s,
Sustained Not modeled, injector/horizon limitations exposed. F5 — pilot P, victim Q/P/
unknown identity, immutable F-old vs attached F-new at same score, partial and
reference variants with correct labels/storage/stats/history.

**Test contract (product §9.2–§9.4 — all 46, D/P/U as specified):** D01–D16 pure
domain/contract; P01–P14 real provider/repository/service composition (real SQL round
trips, two-connection races, recording AI fake); U01–U16 real screen/interaction with
lower layers intact. Unit tests alone cannot satisfy persistence/navigation rows; a
screenshot alone cannot prove source safety. Parameterized subcases cover every variant
in each row.

**Verification bar:** focused suites + full `flutter test` green (shared models/engine/
serialization change, so full suite is mandatory; unrelated baseline failures reported
explicitly), `flutter analyze` clean, changed Dart files formatted, codegen run for
Freezed additions, ≥80% coverage of new logic with 100% of critical isolation/quantity/
validation/race branches (exclusions documented), desktop + narrow/text-scaled renderings,
keyboard/touch semantics, new/legacy round trips, same-score history, optional-data
isolation, real two-connection evidence — journal + QUEUED updated in the same change set.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/aar-fit-comparison-visuals.md`
(Product, 2026-09-15, grounded at `d1114f7`: 30 ACs, 46 cases, F1–F5 oracles, §7.3
feedback copy, D1–D9 decisions), `docs/specs/aar-fit-comparison-visuals-design.md`
(Technical design, 2026-09-15, grounded at `2fe995c`: invariants §1.1, seams §1.2,
models §2, persistence §3, proposals §4, diff §5, calculation §6, BOM §7, providers/UI
§8, units W0–W7 §9, non-goals §10), `.codex/checkpoints/2026-09-14-architect-handoff.md`
(inherited contracts), `docs/engineering-journal/QUEUED.md:64` (P2 item, still queued;
one-to-three-day estimate explicitly predates the data contracts), live code at
`develop` `59ab27a` (branch verified): `fit_evidence_harness.dart` exists (to extend),
`combat_enrichment.dart` (no `fitComparison` field), `combat_aar_report.dart` (v3, no
generation record), `combat_fit_deriver.dart`/`dogma_engine.dart` (no neutral/detailed
entry points), `analysis_multipane_screen.dart` (post-analysis Fits tab, 720px
pre-analysis prompt, 520px tab height constraint). Grep confirms **no comparison
implementation exists** (`AarFitSnapshot`, `fitComparisonAtGeneration` absent).

**Prior art reused (contracts preserved):** `CombatEnrichmentRepository.mutateEnrichment`
atomic load/precondition/transform/save + `written/unchanged/preconditionFailed`;
`AarFitImportParser` strict parsing (proposal flow adds `parseWithKnowledge`, existing
`parse` unchanged); `CombatAnalysisService` wait-for-attachment + three-attempt stale
preparation; `DefenseProfile` weighted EHP (`H / Σ p[t](1−r[t])`); M5 pure incoming
grouping/eligibility rules (extracted helper — never watch
`combatAttackerCorrelationProvider` from the profile selector, it can backfill/write on
view); `loadFittingStatsInputs(..., EffectLookupPolicy.localOnly)`; `itemNameProvider`
with local SDE/stored-name fallback; screen `_screenGeneration`/`_canPublishUi` guards;
`fit_evidence_harness.dart` (real DBs, scripted ESI, gated mutation, recorders).

**Shipped boundaries this plan does not move:** correlation confidence, per-attacker/
unattributed/NPC conservation, score weights, nonblocking analysis, evidence import
dialog close-before-parse policy, M5 attacker-matchup rules, report v3 / input v4
(required keys, `fitAdvice` strings).

## Invariants & Non-Goals

**Invariants (design §1.1 + product §3, binding on every unit):** evidence isolation
(comparison never touches pilot/victim evidence, ledger, scoring, attribution, editor;
never call `captureCurrentPilotFit(confirmed: false)` for comparison); historical truth
(generation snapshots copied from prepared input before AI dispatch; legacy reports
explicitly lack history); source identity (victim inventory/identity/killmail together;
unknown ≠ pilot by elimination; reference/proposal never becomes confirmed evidence);
exact inventory (deterministic duplicate/quantity matching, unknown stays occupied,
physical slots ≠ EFT compact order); neutral calculation (Dogma/input pipeline reuse,
no fake `FitEvidence`, no comparison writes to the ledger); common assumptions (one
frozen skill context + normalized profile + SDE/calculator revision; no old values under
new headers); qualified materials (Changes ≠ Full; unknown counts/prices/eligibility ≠
zero; lost/removals ≠ ownership/resale); local view (stored-read/diff/derive/cache reads
make no AI/sync/discovery calls; name/icon fetch never gates comparison); commit
semantics (success only after commit; field-scoped preconditions reject stale results;
independent fields preserve each other); compatibility (v3/v4 remain; new fields
optional + independently versioned; unknown candidate versions keep narrative).

**Non-goals (product §10.3 / design §10):** no applying proposals to editor/EVE,
purchases/sales/asset moves, doctrine discovery/certification, or automatic evidence
promotion; no reconstructing old inventories from today's attachment/score, mandatory
regeneration, history browser, or historical engine/SDE replay; no attacker-module or
opponent-skill inference; no application/tracking/range/heat/reload/injector-budget/
sustained-tank simulation; no fitting-legality certification, "best fit", executable
quotes, tax/logistics/resale modeling, or fresh-ownership guarantees; no global
strict-parser change, score adjustment, M5-math change, or mutable editor embedded for
preview. Any required expansion returns to Product/Lead with the failing contract —
tests are never weakened.

## Key Architectural Decisions

Ten decisions from design §1–§4 + product D1–D9 (alternatives rejected in Why):

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | Snapshot model | New Freezed `AarFitSnapshot` envelope (schema 1, deep-copied `Fitting`, typed source/subject/ref, dual timestamps, `FitGroupKnowledge` sidecar, limitations); never reuse `aarFitSnapshotProvider`'s derivation bundle | Persisting derivation bundles or `FitEvidence` as comparison sources | Derivations lack inventories and embed evidence provenance; the provider name is shipped and must not be renamed. Deep copy at construction — Freezed getters alone don't stop caller-list mutation. |
| 2 | Knowledge independence | Per-group completeness/applicability, slot-position meaning, per-occurrence charge/state knowledge, `unplacedEntries` retained; N/A requires positive hull evidence (`subsystemSlots==0` is hardcoded, not a source) | Inferring completeness from empty lists / parse success / derivation coverage | Empty ≠ recorded-empty; legacy absent `items` is unknown; inferring N/A from coverage zeroes would hide real subsystems. |
| 3 | Fingerprints | Versioned SHA-256 canonical content (hull, subject, quantities, charge/state/knowledge, deployment, physical indices when recorded) + separate `calculationFingerprint`; name resolution excluded | UUID/display-name/timestamp-inclusive or ID-list-only hashing | Display changes must not count as equipment changes; metadata-only refresh must not imply purchases; stale-advice detection needs semantic equality. |
| 4 | Owned storage | Optional `CombatEnrichment.fitComparison` (`currentSnapshot` + `userProposal` full envelopes, schema 1) in existing JSON column, no migration; AI alternatives stay on their report | New table / new evidence role / reusing `pilotFitEvidence` | Existing column needs no migration; a role would conflate comparison with evidence; calling unconfirmed capture would overwrite the pilot fit. Explicit clear sentinels beat null-coalescing `copyWith`. |
| 5 | Comparison-only rows | Optional `evidencePacketPresent` (absent = true); false rows carry no ledger/search/fit, and the service evidence projection returns null so scorer/checklist/prompt see prior absence | Manufacturing baseline ledger packets for comparison rows | Scorer distinguishes null/no-character from log-only rows; a fake packet would change scores and could suppress explicit search. False→true builds the normal packet, then grafts comparison state. |
| 6 | Concurrency | Field-scoped CAS on owned slot IDs (unique per replacement, anti-ABA) + ≤3 bounded SQLite busy retries with original expectation; slot-keyed operation coordinator for busy/duplicates only — preconditions, not the coordinator, supply correctness | Whole-JSON CAS / service-local lock / silent precondition retry | Whole-JSON CAS makes independent fields fight; a service lock doesn't span window connections; silent retry can commit against a superseded expectation. Two temp-file connections prove it. |
| 7 | Generation binding | `CombatAarReport.fitComparisonAtGeneration` (schema 1): deep-copied supplied snapshots, `selfBaselineSnapshotId` + reason, actual derivation input refs, declared historical contexts; single immutable `PreparedAarComparisonInput` built before the AI await; stale advice compares supplied-pilot fingerprint, not score | Rereading latest attachment after AI response / score-based staleness | A later F-new must not rewrite F-old's record; pilot derivation can fall back to victim without an attachment change, so score can't identify the fit. |
| 8 | Candidate validation | Raw presence/types validated before `Fitting.fromJson` defaults; local hull/slot/quantity/capacity checks; statuses validated/partial/invalid/unsupportedVersion/localDataUnavailable; budget excess = warning, not invalid; origin/baseline/encounter client-stamped, mismatches rejected not rebased | Trusting generated attribute bags/stats/prices/confidence/timestamps, or `Fitting.fromJson` defaults | Defaults erase omissions (omitted group ≠ empty group); generated numbers are never stats; silent rebase would misattribute a proposal to the wrong baseline. |
| 9 | Neutral calculation | Extracted `deriveFitting` + `calculateDetailedStats` (compat wrappers keep one formula set); `AarComparisonContext` (frozen skills, normalized profile, revisions) + `AarComparisonFrame` keyed results; Dogma key split from defense projection; per-metric available/partial/unavailable/notModeled; `qualifyComputation` before deltas | Widget-side EHP formula / per-column skill contexts / stored omni EHP for non-omni profiles | A second formula drifts; mixed skill bases make deltas meaningless; omni EHP under a non-omni profile is a wrong number. Canonical-sorted deployment copies keep capacity allocation deterministic. |
| 10 | Read-only workspace | Parameterized widgets over values + thin provider adapters; `LayoutBuilder` on usable content width (≥1440/1000–1439/720–999/<720 + text-scale reduction); full-width pre-analysis route/panel; one vertical scroll owner; sanitized `Type #…`/`Ship #…`, resolved-or-unknown names; proposal dialog stays open on error with `isSubmitting` guard | Embedding `FittingEditor`/`StatsPanel`/`SavedFittingsDialog`, window-width breakpoints, stuffing workspace into the 720px prompt | Editor/panel/dialog are bound to mutable active-fitting providers; sidebar breaks window-width math; the narrow prompt can't host multi-column comparison. |

**Product D1–D9 preserved verbatim:** four roles + separate storage; generation content
preserved, recalculation labeled current-context; validated full candidates + saved/EFT
proposals, additive schemas; multiset diff before slot replacement; common skills/profile;
burst/peak shown, sustained Not modeled; separate BOM modes, qualified cache; cached
averages + price-only refresh; read-only widgets with explicit actions.

## Recommended Approach

**Contracts first, then storage, then math, then pixels — each on independently
verifiable seams.** W0 pins the vocabulary every later unit speaks (snapshot identity,
knowledge, fingerprints, F1–F5 fixtures) with zero behavior. W1 and W2 build the two
durable truths in parallel under one serialization integrator (owned slots + CAS +
evidence projection; generation binding + candidate validation). W3 and W4 are pure
computation against W0 fixtures and can run fully parallel (diff/BOM; neutral engine +
frames). W5's pure annotations ride alongside; its provider wiring lands after W1's
observation contract exists. W6 composes only finished contracts into the workspace —
isolated widget RED early on typed fixtures, real journey GREEN last. W7 collects
per-AC receipts, not just a passing count. Within **each unit**: test-author writes
failing behavioral tests (RED — a real failing assertion for a new requirement, never a
bare uncompilable import) → dev implements minimal GREEN → reviewer checks boundaries/
no-fabrication/no-raw-IDs → tester verifies with real SQL/widgets and signs off before
the next unit starts.

## Work Plan

Units are **W0–W7** per design §9.1 (W-prefix avoids collision with Product U01–U16 and
the prior initiative's U0–U5). Sequence: W0 first; W1+W2 test-authoring in parallel with
one integrator owning shared enrichment/analysis serialization edits; W3+W4 independent
after W0 (W5 pure annotations alongside); W6 isolated widget authoring on agreed typed
fixtures anytime, real journey GREEN after W1–W5; W7 sequential last. No concurrent
uncoordinated edits to shared models/provider/service files. Commits are atomic per unit
(`type(scope): description`, no attribution lines).

### [SEQ] W0 — Contracts and fixture harness

**Tests first (test-author [grok, wB:pB], RED).** New snapshot/proposal/context models:
deep-copy isolation (mutating caller lists post-construction changes nothing),
fingerprint stability (permutations/renames/timestamps equal; quantity/charge/state/
knowledge/subject changes differ; content vs calculation keys), knowledge policies per
source (new capture/legacy/import/saved/killmail/candidate), legacy JSON tolerance
(absent keys stay absent), D03/D07/D16 slices + P05 selection/dedup/fallback rules.
Extend `fit_evidence_harness.dart` with F1–F5 fixtures (symbolic A/B/C/H/D/Ammo/Paste →
distinct SDE types with names/categories/slot metadata; injected clock; deterministic
skills; recording fakes; real repository round trips) and a production-provider-
composition harness variant (existing fixed service override + fixed SDE/skill streams
cannot prove publication/revision behavior).

**Dev (GREEN — dev-1 [grok, wB:p4]).** `domain/aar_fit_snapshot.dart`,
`aar_fit_proposal.dart`, `aar_fit_comparison.dart` (selection/context types),
`aar_fit_inventory_diff.dart` + `aar_fit_bom.dart` (type shells; algorithms in W3),
`FitEvidence.inventoryKnowledge` optional field through serializers (no scoring/
confidence change), raw-source adapter result types with compat wrappers.

**Gate (reviewer [muse, wB:pA] / tester [codex, wB:pD]):** reviewer checks no fabricated
evidence (no retroactive completeness, no type-ID-0 synthesis, no unknown merging);
tester proves genuine repository round trips (not in-memory substitutes).

### [P1] W1 — Owned storage and source acquisition (after W0)

**Tests first (RED): P01, P03, P04, P06, P08, P09, P11 + first-row isolation.**
Independent current/proposal persistence across reload/re-analysis with evidence/
victim/editor/score unchanged; reversed completion orders; duplicates/CAS conflicts/
two scopes/two temp-file connections/navigation/disposal; saved-copy stability across
original edits + alternative switching; strict proposal rejection/cancel/SQL failure;
capture matrix (auth success, no auth, missing ship, failed page, empty→hull-only);
encounter-P vs active-Q capture/cache; first-ever comparison save on a no-character,
no-row encounter leaves all evidence dimensions/ledger identical.

**Dev (GREEN — dev-1 [grok, wB:p4], integrator for shared serialization).**
`CombatEnrichment.fitComparison` + `evidencePacketPresent` through every
constructor/copy/serializer/refresh/merge path (never into `toPromptJson`,
`derivationInputKey`, or ledger); field-scoped CAS + ≤3 busy retries; slot-keyed
`(encounterId, current|userProposal)` coordinator; `CurrentShipFitReader` extraction +
opt-in strict ESI ship read; `SavedFittingReference` read-only DTO/query
(encounter-character + shared scope); `AarFitImportParser.parseWithKnowledge`;
`AarFitComparisonService` (capture/import/copy with slot expectations);
commit-publisher wiring into `combatEnrichmentServiceProvider`; repository observation
(local events + ~1s same-connection `data_version` poll + resume check, connection-local
tokens only) with bootstrap race guards; evidence-projection isolation adapter
(canonical content key excluding comparison fields).

**Gate:** reviewer audits every enrichment mutation path for comparison retention +
projection correctness; tester runs the two-connection gate (separately opened
connections to one temp file, schema pre-initialized), real SQLite failure injection,
and existing evidence/attachment regressions.

### [P1] W2 — Generation and proposal contract (after W0, parallel with W1 tests)

**Tests first (RED): D15, D16, P02, P13, P14.** Candidate matrix (full/omitted-vs-empty
groups, prose-only, unknown type, bad quantity, slot collision, unsupported version,
wrong baseline/encounter, over-budget-valid); snapshot/report JSON round trips;
F-old prepared + F-new attached during pending AI (binding + fingerprint staleness,
incl. failed-pilot→own-victim fallback without false staleness); legacy/optional
contract (generated "confirmed"/numbers ignored, mismatched refs rejected, no
generated stats/facts, malformed candidate causes zero extra repair requests);
same-score replacement + re-analysis + revision change with preserved history.

**Dev (GREEN — dev-2 [grok, wB:p5], shared-serialization edits via W1 integrator).**
`CombatAarReport.fitComparisonAtGeneration` + `fitCandidates` optional schemas (v3
unchanged otherwise); input `fitComparisonInput` top-level section (v4 unchanged
otherwise) + prompt rules (complete-only-when-supported, 512-entry bounded vocabulary
with truncation marked, ≤8 candidates / 256 KiB / 4,096 modules / int32 quantities);
candidate validation pipeline (pre-`fromJson` presence checks, local hull/slot/
quantity/capacity checks, budget warnings, replacement-annotation verification);
derivation result carrying selected source inputs (existing method delegates);
`PreparedAarComparisonInput` frozen before AI await, attached on response (never
reread); client-owned field overwrite (reject generated `fitComparisonAtGeneration`);
validation cache keyed by validator revision + SDE key; stale-advice fingerprint
comparison (supplied pilot attachment, null→null fresh).

**Gate:** reviewer checks client authority (no generated stats/confidence/times
accepted), report-failure retention (old report survives AI/candidate/stat failures),
and no silent rebase; tester runs report/prompt suites + legacy compatibility.

### [P1] W3 — Pure diff and BOM (after W0, independent of W1/W2)

**Tests first (RED): D01–D07 (+D03/D07 W0 slices).** Identical/shuffled inventories;
F1 duplicates + canonical X→W/Y→Z under both-input permutations; EFT-compact
order-only (no fictitious purchase); recorded vs order-only vs different-hull pairing;
F2 cargo reuse + H/H2 oracles; drone/fighter quantities + deployment separation +
unquantified loaded Y; completeness distinctions + incomplete-Changes qualification +
exact complete-target replacement; extended total-order permutations (unknown vs
proven-absent charge × two known charges; recorded vs assumed equal state).

**Dev (GREEN — dev-3 [grok, wB:p6]).** `FitInventoryDiff`/`FitChangeRow` (stable row
IDs from source IDs + canonical tuples + duplicate ordinals); §5.2 matching algorithm
(exact multiset cancel → same-type canonical pairing → recorded-slot/validated-
annotation replacement → Added/Removed; drones/fighters/cargo per-type quantities;
qualified wording for incomplete records; Show-all/Changes-only support data);
`FitBillOfMaterials`/`FitBomLine` (global physical counts incl. offline, Changes
`max(0,target−baseline)` when provable / Full `target[t]`, cross-group netting,
different-hull net diff, unknown-tainted lines, charge/cargo separation,
unquantified-advice list).

**Gate:** reviewer rejects upgrade inference (no `upgraded` outcome from price/meta/
magnitude), unknown-as-zero, and input-order tie-breaks; tester checks every F1/F2
quantity oracle incl. permutations.

### [P1] W4 — Neutral calculation and metrics (after W0, independent of W1–W3)

**Tests first (RED): D08–D12, P07 (+D06 share).** F3 EM/Omni/M5-profile EHP + pp
deltas (domain precision, then locale text separately); one-context All-V/known
fallback incl. victim column + opponent qualification; volley/DPS split + unknown-
charge incompleteness; F4 cap/tank transitions + zero/nonfinite denominators; CPU/PG/
drone excess warning vs unknown-module partial suppression; per-input revision
invalidation + late-old-result rejection (incl. cross-connection skill/SDE updates).

**Dev (GREEN — dev-2 [grok, wB:p5]).** `CombatFitDeriver.deriveFitting` neutral method
(existing `derive` delegates) + `DogmaEngine.calculateDetailedStats` (existing
`calculateStats` wraps); `AarComparisonContext` (frozen skills/profile/revisions) +
`AarComparisonFrame` (source+context keyed, late-result rejection, Dogma/defense key
split, bounded in-memory cache); pure M5 profile-choice helper (no backfill/derivation);
SDE/skill snapshot reads with ≤3 mixed-frame retries; `qualifyComputation` (unknown/
partial groups, unplaced modules, absent drone/fighter knowledge qualify metrics;
cargo alone doesn't); availability-typed metrics (`available/partial/unavailable/
notModeled` + unbounded case, never NaN/Infinity); canonical-sorted deployment copies
with disclosed priority; Tengu-safe slot validation (base-zero ≠ rejection).

**Gate:** reviewer rejects duplicate math (one weighted-EHP implementation, widgets
formula-free); tester runs fitting + M5 regression suites and stale-frame races.

### [P1] W5 — Prices and cached spares (pure parts alongside W3/W4; wiring after W1)

**Tests first (RED): D13, D14, P12 (+P10/P11 shares).** F2 price coverage incl.
adjusted-only/missing/zero/stale/exact-24h/future-dated cases; eligible/disjoint vs
empty/other-character/other-ship/ambiguous stock (+ baseline-split/repackaged-ID case
staying unknown); cache-only render + price-only refresh (no order/asset sync,
cache retained on failure).

**Dev (GREEN — dev-3 [grok, wB:p6]).** `MarketRepository` batch read/watch by type-ID
set (single coherent batch per subtotal); `AarPriceEstimate` + `IskEstimateAmount`
(coefficient/scale decimal math, `formatIsk`-only rounding, priced-subtotal vs gross
rules); `AarCachedAssetMatch` + encounter-character asset/location adapters (strict
5-condition eligibility incl. Changes-mode disjointness, freshness-unknown disclosure);
price-only refresh controller with progress/error separate from cached rows.

**Gate:** reviewer checks no adjusted fallback, no free/zero conflation, no ownership
claims from unqualified cache; tester asserts zero order/asset sync calls and
cache-retaining error paths.

### [SEQ after W1–W5] W6 — Read-only workspace and dialogs

**Tests first (RED): U01–U16.** Pre/post reachability with no view-triggered AI; usable-
width breakpoints 719/720, 999/1000, 1439/1440 + selection retention; 320px/200%/
keyboard/touch without page overflow; F5 headers/dedup/legacy notices; eight-group
presentation + icon/name fallbacks + zero raw IDs; color-independent badges +
Show-all/Changes-only + no-change state; F3/F4 tradeoff rows without winner claims;
scoped loading/error/retry + partial + current-key numbers; F2 BOM modes/counts/
coverage; asset/cargo qualifications; exact success snackbars post-commit + accessible
busy + reload/duplicates; exact §7.3 failure feedback + recoverable dialog; legacy/
invalid/alternative/reference candidates + origin warnings; price refresh feedback +
icon-failure independence; evidence/checklist/editor byte-identical after all read-only
interactions; same-score stale advice + safe late completion.

**Dev (GREEN — dev-1 + dev-2 [wB:p4, wB:p5], coordinated).** Provider graph per §8.1
(`aarComparisonStore/Sources/Selection/Context/Frame/Diff/Bom/Assets/Prices/
Annotations/Operation` with `.when()` + same-key `skipLoadingOnReload`, frame-key
comparison, optional-source failure isolation); widget tree per §8.2 (workspace,
selector, assumptions bar, columns, headers, inventory views, stat cards, BOM card —
pure widgets + thin adapters, no `FittingEditor`/`StatsPanel`/`SavedFittingsDialog`);
`LayoutBuilder` usable-width breakpoints + text-scale reduction + encounter/source/
group-keyed state; full-width pre-analysis route/panel + scrollable Fits workspace
(one scroll owner each); sanitized names (`Unknown ship`/`Unresolved module`, no
`AarSkillContext.label`/`describe()` raw IDs); proposal dialog (owns controller, stays
open on error, `isSubmitting` disables submit/cancel/barrier/Escape); lifecycle guards
(captured encounter/generation, slot expectations, no late snackbar); typed-error
formatter with exact §7.3/§8.4 copy.

**Gate:** reviewer + tester inspect desktop + narrow/text-scaled renderings, real
actions (capture/save/refresh), keyboard/touch semantics, and evidence/editor
immutability proofs.

### [SEQ] W7 — Integration and closeout

**All roles.** Map every AC1–AC30 to passing receipts (design §9.4) and every S1–S6
workflow to its spine (design §9.5); run focused suites → full `flutter test` →
`flutter analyze` → format check → codegen verification; coverage ≥80% new / 100%
critical branches with documented exclusions; real two-connection multiwindow
evidence; desktop + narrow/text-scaled + keyboard/touch signoff; new/legacy round
trips; same-score history; optional-data isolation. Update README/journal + QUEUED
(archive SHIPPED only with implementation + verification evidence) in the same change
set. **Gate:** reviewer confirms AC matrix + narrow diff; tester records suites,
static analysis, device evidence, limitations. No shipped claim with unresolved
critical gates.

## Validation Plan

Each unit's gate is **RED before GREEN** — implementation is blocked until the unit's
test-author suite shows a failing behavioral assertion for the named requirement (never
a bare uncompilable import; existing compatible behavior may start green). Existing
suites are regression-locked.

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| W0 | Snapshot/proposal/context/fingerprint/knowledge + F1–F5 fixtures — fail: missing contracts | Models + fixtures only | `flutter test test/features/combat_analyzer/domain/aar_fit_snapshot_test.dart test/features/combat_analyzer/domain/aar_fit_proposal_test.dart` (new) → GREEN; deep-copy/fingerprint/legacy cases pass |
| W1 | P01/P03/P04/P06/P08/P09/P11 + first-row isolation — fail: evidence overwrite, lost fields, unscoped capture | Owned storage + CAS + acquisition | `flutter test test/features/combat_analyzer/data` → GREEN; two-temp-file-connection gate + existing evidence/attachment regressions pass |
| W2 | D15/D16/P02/P13/P14 — fail: unbound history, generated-stats acceptance, repair-storm candidates | Generation + candidate contract | `flutter test test/features/combat_analyzer/data/combat_analysis_service_test.dart test/features/combat_analyzer/domain/combat_aar_report_test.dart` (+ new candidate suites) → GREEN; F-old binding + zero extra repair requests proven |
| W3 | D01–D07 — fail: order-dependent matches, invented replacements, unknown-as-zero | Diff + BOM | `flutter test test/features/combat_analyzer/domain/aar_fit_inventory_diff_test.dart test/features/combat_analyzer/domain/aar_fit_bom_test.dart` (new) → GREEN; every F1/F2 oracle incl. permutations |
| W4 | D08–D12/P07 — fail: mixed contexts, stale frames, confident partials | Neutral engine + frames | `flutter test test/features/combat_analyzer/domain test/features/fitting` → GREEN; F3/F4 oracles at domain precision; fitting + M5 regressions pass |
| W5 | D13/D14/P12 — fail: free/adjusted/total mislabels, unqualified shortfalls, sync on view | Prices + spares | `flutter test test/features/market test/features/assets` (+ new annotation suites) → GREEN; F2 value oracles; zero order/asset sync calls asserted |
| W6 | U01–U16 — fail: unreachable/mislaid/unlabeled/unbounded UI | Workspace + dialogs | `flutter test test/features/combat_analyzer/presentation` → GREEN; breakpoint/a11y/immutability journeys pass; desktop + narrow renderings inspected |
| W7 | — (receipts review + full verification) | Integration + closeout | `flutter test test/features/combat_analyzer|fitting|assets|market` → GREEN; full `flutter test` GREEN; `flutter analyze` clean; format + codegen verified; coverage gates met; `git diff --stat docs/engineering-journal/` shows QUEUED→ARCHIVED SHIPPED |

**Highest-risk validation:** generation binding under concurrent attachment (P02/W2) —
if the report binds a post-AI reread instead of the prepared input, F-new silently
replaces F-old history and only the pending-AI + same-score assertions catch it.
Second-risk: field-scoped CAS across window connections (P03/P04/W1) — a service-local
lock passes single-connection tests and fails only the two-temp-file case. Third-risk:
stale frames under new headers (P07/W4) — skipped only by key-compared rejection, never
by `skipLoadingOnReload` alone.

## Risks / Rollback

- **Overwriting pilot fit during comparison (W1).** Comparison capture routed through
  evidence persistence would destroy the fight fit. *Mitigation:* separate owned slots,
  `CurrentShipFitReader` extraction with distinct evidence/comparison persist paths,
  P01/U15 immutability proofs. Rollback: disable comparison capture, keep read-only
  views of existing sources.
- **Unhandled pagination / partial capture saved as complete (W1).** *Mitigation:* all
  pages must succeed; empty success is qualified hull-only; page failure is an error
  with prior snapshot retained (P09). Rollback: gate capture behind completeness check.
- **Stale frame calculations under new headers (W4).** *Mitigation:* frame-keyed results
  with late-result rejection, mixed-frame retry ≤3 then unavailable, key comparison in
  providers (P07). Rollback: show loading placeholders instead of retained values.
- **Responsive layout overflow (W6).** Usable-width (not window-width) breakpoints,
  text-scale reduction, and one scroll owner are easy to get subtly wrong.
  *Mitigation:* U02/U03 boundary tests at 719/720/999/1000/1439/1440 + 320px/200% with
  real sidebar/padding/host constraints. Rollback: force stacked layout below 1000px.
- **Whole-enrichment CAS contention / ABA (W1).** *Mitigation:* field-scoped slot-ID
  expectations (unique per replacement), ≤3 busy retries with original expectation,
  typed conflict + explicit retry. No silent retry, no old-object replay.
- **Evidence-projection leakage (W1).** Comparison-only rows must read as evidence
  absence. *Mitigation:* `evidencePacketPresent` + isolation adapter + canonical content
  key excluding comparison fields; first-row test pins identical dimensions/ledger.
- **Generated-content trust (W2).** Attribute bags/stats/prices/confidence/timestamps
  from candidates must never enter calculations or evidence. *Mitigation:* client-side
  validation + stamping; P13/D15 matrix; zero-repair-request assertion.
- **Shared-file edit collisions (W1/W2, W6).** *Mitigation:* one integrator owns shared
  enrichment/analysis serialization edits; W6 composition after W1–W5 contracts;
  workers preserve others' edits. Rollback: revert to pre-unit files; RED re-fails.
- **Estimate risk (flagged by Product §10 + queue).** One-to-three-day estimate predates
  the data contracts. *Mitigation:* W0–W2 RED first makes scope visible early; Plan
  resurfaces the estimate to Lead if GREEN exceeds it rather than shrinking coverage.

## Execution Steps & Role Handoffs

Team: Test Author (grok, wB:pB), Dev-1/Dev-2/Dev-3 (grok, wB:p4/wB:p5/wB:p6),
Reviewer (muse, wB:pA), Tester (codex, wB:pD).

1. **Kickoff (Lead).** Confirm branch from `develop@59ab27a`; assign owners per unit
   (W0 dev-1; W1 dev-1 integrator; W2 dev-2; W3 dev-3; W4 dev-2; W5 dev-3; W6
   dev-1+dev-2); test-author + devs agree on model/fixture interfaces (snapshot/
   proposal/context shapes, F1–F5 symbolic→SDE mapping, provider keys) before
   parallel RED begins.
2. **W0 RED→review→GREEN→test.** Test-author lands model/fixture RED; reviewer
   confirms no-fabrication rules; dev-1 implements types; tester proves real
   repository round trips. W0 GREEN unblocks W1–W5 RED.
3. **W1 + W2 RED in parallel (test-author, two tracks); W3 + W4 + W5-pure RED
   alongside.** Each RED lands with failing behavioral assertions + causes;
   reviewer confirms each new requirement has its regression.
4. **W1 + W2 GREEN (dev-1 integrator + dev-2).** Shared serialization edits sequenced
   by the integrator; reviewer audits every mutation path + client authority;
   tester runs two-connection gate, SQL-failure, report/prompt suites.
5. **W3 + W4 + W5 GREEN in parallel (dev-3 diff/BOM, dev-2 frames, dev-3 prices).**
   Reviewer rejects duplicate math/upgrade inference/unknown-as-zero; tester checks
   all F1–F4 oracles + fitting/M5 regressions + zero-sync assertions.
6. **W6 RED→GREEN (test-author → dev-1+dev-2).** Isolated widget RED may precede on
   typed fixtures; real journey GREEN after W1–W5; reviewer + tester inspect
   renderings, actions, semantics, immutability proofs.
7. **W7 closeout [SEQ] (all).** Per-AC receipts AC1–AC30, full suite + analyze +
   format + codegen + coverage, two-connection evidence, renderings, journal/README/
   QUEUED update in the same change set; reviewer confirms matrix; tester records
   evidence, device results, limitations.

**Handoff protocol per unit:** test-author posts RED (IDs + failing assertions + causes +
missing seams) → reviewer approves RED scope → dev implements minimal GREEN (no covert
extra fixes; newly found defects get new RED first) → reviewer checks boundaries +
no-fabrication + no-raw-IDs → tester independently runs real-SQL/widget verification
and signs off → Lead advances the unit. Findings requiring scope expansion return to
Product/Lead with the failing contract — tests are never weakened.

## Open Questions

None after local discovery — every behavior, seam, oracle, threshold, and test ID is
closed by the product specification (§1–§10), the technical design (§1–§10), and the
`59ab27a` probed codebase. The estimate tension (queue one-to-three days vs.
contract-heavy scope) is carried as an explicit risk with an early-visibility
mitigation, not a blocker.

---
*Plan file:* `.agents/plans/2026-09-15-aar-fit-comparison-visuals.md` — canonical body is the reply above. Reviewer prompts: verify owned-slot separation from `pilotFitEvidence`, generation binding from prepared input (never post-AI reread), field-scoped CAS with unique slot IDs, evidence-projection isolation of comparison-only rows, client-stamped candidate origins, single weighted-EHP implementation, frame-keyed late-result rejection, and zero raw EVE IDs on exercised surfaces.

# Per-Attacker Incoming Damage Profile and Defense Matchup — Implementation Plan

## Goal

Ship QUEUED.md P2 "Per-attacker incoming damage profile and matchup" (Milestone 5): split the
current aggregate incoming damage profile into per-attacker profiles using Milestone 4's
shipped identity correlation, and compare each eligible attacker against the same pilot-fit
defense snapshot. Every attributed claim names its specific attacker; Unattributed (X) and
NPC (N) residuals retain their typed components and untyped amounts with no named EHP/hole;
the Aggregate Overview stays as a labeled combined-source reference. All amounts, splits,
EHP, pressure, and primary-hole selection are deterministic client-side derivations —
the LLM explains supplied results, never computes them.

## Success Criteria

**Numerical gates (exact, from product §7.1 / design §5.2 — Fixture A defense: shield HP
1,000, armor/hull 0, shield resists EM/Thermal/Kinetic/Explosive = 0/20/60/20%, tank Shield):**

- Fixture A (Kite 6,000 @75/0/25/0; Artem 4,000 @0/0/25/75; aggregate 45/0/25/30):
  q = 0.85 / 0.70 / 0.79; EHP = 1176.470588 / 1428.571429 / 1265.822785 (raw, within 1e-6);
  primary holes EM / Explosive / EM with pressures 0.882352941 / 0.857142857 / 0.569620253
  (within 1e-9); omni EHP 1333.333333 in every card; share-weighted EHP average
  1277.310924 is asserted NOT to equal aggregate EHP.
- Fixture B (T=1,000): M5 accounting attributed 400 + X 300 + NPC 300 = 1,000;
  aggregate vector (300,0,200,200); typed 700 + untyped 300; A share 40%, coverage 75%.
- Fixture C (fractional): d=1 omni → (1/4,1/4,1/4,1/4); d=3 → (3/4,3/4,3/4,3/4);
  aggregate (1,1,1,1); omni profile/EHP/hole at every scale; thirds conserve exactly.
- Fixture D (mixed weapons): 600 pure EM + 400 pure Thermal → (600,400,0,0), 60/40 split
  invariant to hit counts.
- Amount conservation uses **exact reduced-rational equality, never epsilon**: per-bucket
  D=K+U, per-type aggregate sums, T = ΣD = ΣC + U.

**Behavioral gates (28 release criteria F01–F10, Q01–Q10, V01–V08 = AC1–AC28, product §6 /
design §5.6):** solo equality with aggregate; C/P named cards, Possible in X, shipType
Probable cap preserved; NPC never double-counted; victim return fire vs pilot fit;
zero/partial coverage and missing-defense states without invented quantities; coherent
refresh on fit/skills/SDE/event/correlation change; legacy caches usable with no
migration; additive v4 + scoped evidence with unchanged scores; one lookup per distinct
weapon, one pilot-fit derivation; Damage tab overview + one source ranking + separate
outgoing comparison; Probable/partial qualifiers attached; multi-source advisory in
aggregate reference only (solo quiet); no raw EVE IDs anywhere; 360px/desktop/200%/
keyboard/screen-reader; stable keys, full fleet reachable.

**Architectural gates:** domain is pure (no I/O, no `DateTime.now()`, no providers);
no new network calls (local-only effect policy, cached SDE reads); prompt stays
`mimir.combat_aar_input.v4` with optional `damageMatchups.perAttackerIncoming` only;
no Drift migration; correlation failure is non-fatal; `flutter analyze` clean and full
`flutter test` (800+ tests) green with ≥80% coverage and complete critical-branch coverage.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/aar-per-attacker-matchup.md` (Product,
2026-09-14, R1–R19, D1–D10, S1–S5, fixtures A–D, F/Q/V criteria, D/P/U test matrix),
`docs/specs/aar-per-attacker-matchup-design.md` (Arch HOW, same date, §1–§6: ten
inherited contracts, rational-quantity models, allocation/partition/defense contracts,
resolver/provider/evidence/prompt, UI, U1–U4 TDD breakdown, AC1–AC28 traceability),
`.codex/checkpoints/2026-09-14-architect-handoff.md` (M4 custody + ten architectural
contracts to preserve), `.agents/plans/2026-09-11-aar-zkill-attacker-correlation.md`
(M4 plan — format reference), live code: `lib/features/combat_analyzer/domain/`
(`combat_attacker_correlation.dart`, `combat_actor_classifier.dart`,
`combat_attacker_correlator.dart`, `combat_damage_matchup.dart`, `combat_damage_profile.dart`,
`combat_enrichment.dart`, `combat_fit_deriver.dart`, `aar_evidence_scorer.dart`,
`parsed_combat_encounter.dart`, `combat_log_parser.dart`), `data/`
(`combat_damage_profile_resolver.dart`, `combat_fit_derivation_service.dart`,
`combat_analysis_service.dart`, `combat_providers.dart`, `codex_analysis_client.dart`),
`lib/features/fitting/domain/damage_pattern.dart`, branch state
(`feature/aar-per-attacker-matchup` at `8884800`, after M4 `d2dd731`; grep confirms **no
M5 implementation exists** — `perAttackerIncoming`, `IncomingDamageAllocation`,
`AarAttackerMatchup` absent from `lib/` and `test/`).

**Prior art this plan reuses (contracts preserved):** M4's final `CorrelatedAttacker.confidence`
(including shipType Probable cap; M5 never calls `bandFor(score)`); exact normalized
weapon-name SDE lookup from `CombatDamageProfileResolver._lookupDamageAttributes`;
`DefenseProfile.ehpAgainst` + shared resist-assessment helper ( hole if ≤20 or ≤mean−5,
else strong if ≥mean+5, else neutral — hole precedence); `loadFittingStatsInputs` shared
loader and pilot-fit selection policy (explicit pilot evidence tried first, wins on
success; own-loss victim fallback on failure); `combatAttackerCorrelationProvider` +
`ensureAttackerCorrelation` lazy backfill seam; M3 evidence-scorer statuses/weights and
`Missing iff actionable`; `damage_pattern_test.dart` finite-guard tests; per-pane logging
tags and Riverpod `.when()` states.

**Spec/design alignment:** design §1.4 records eight probed findings that fix scope
(integer-rounded `CombatDamageProfile` entries vs canonical pattern; raw-source vs
normalized keys; M4 correlation has no event fingerprint; fit derivation awaits profiles;
`loadFittingStatsInputs → ensureEffectModifiers` can hit ESI; `CombatDamageMatchup.toJson`
omits pattern/EHP; legacy hole loop zero-share/equal-share fallbacks; Damage tab requires
a report; `sdeInitializerProvider` signals initial completion only). This plan adopts the
design's seams as contract (§2–§4) and keeps Product R1–R19 + AC1–AC28 authoritative.

## Invariants & Non-Goals

**Exact conservation (R8–R11, design §1.3 — no epsilon, ever):** for each source bucket
`D_b = K_b + U_b = Σ_t C_b,t + U_b`; per type `C_agg,t = Σ_A C_a,t + C_X,t + C_N,t`;
`U_agg = Σ_A U_a + U_X + U_N`; `T = Σ_A D_a + D_X + D_N = Σ_t C_agg,t + U_agg`. Components
are reduced `BigInt` rationals (`quantityBasis: sde-decimal-v1`); logged/resolved/untyped
totals are integers in `[0, 9007199254740991]` accumulated in `BigInt` (overflow →
`IncomingAllocationInvalid('integerOverflow')`); `double` only at the formula/display
boundary with scaled integer division (never `num.toDouble()/den.toDouble()`).
`D_X = M4.unattributedIncomingDamage + PossibleDamage`;
`ΣD_a = M4.correlatedIncomingDamage − PossibleDamage`; M4 `unattributedActors` includes
NPCs — filter before summing or NPC double-counts. Denominators: share `D_b/T`,
coverage `K_b/D_b`, split `p_b,t = C_b,t/K_b`. Rounding only at presentation or the
explicit legacy-integer projection (largest fractional remainder, EM/Thermal/Kinetic/
Explosive tie order) — never fed back into formulas. One damage unit from an omni weapon
stays 0.25/type; T=0 → empty state; K=0 → split omitted.

**Behavioral invariants:** exactly-once event ownership by exact parser raw source key
(raw match precedence, unique normalized fallback, no fan-out); C/P named cards only,
Possible retained as uncertain candidate in X; any positive coverage permits a partial
comparison labeled **Resolved portion only**; zero coverage → no pattern/EHP/hole (no
omni substitution); unknown layer suppresses pressure/hole but keeps valid layered EHP;
`q≤0` finite fallback flagged, never invulnerability; primary hole = max modeled pressure
among **positive canonical types** classified hole (exact double ties in enum order;
no equal-share fallback); pressure label **Modeled share after [layer] resists**, never
"% of damage taken"; every card uses the same pilot-fit snapshot (`AarDerivationBundle.self`,
never the attacker ship); aggregate reference labeled combined-source whenever
`allocation.sources.length > 1` (including one eligible + residual); stale/mismatched
attribution → affected sources to X with a reason, never silent repair.

**Non-goals (product §8.2 / design §6):** no new correlation weights, alias merging,
drone-owner inference, or killmail discovery; no attacker module/charge/skill/fit
inference from hulls; no pre-resistance volley reconstruction; no tracking/range/
signature/application, active-tank survival, reload/overheat simulation; no individual NPC
matchups, outgoing de-aggregation, ship-vs-ship diagrams, fit editors, exported reports,
or AI output-field changes; no evidence-score changes, auto analysis/search, forced
regeneration, Drift migration, persisted card preferences, or durable M5 cache. Supporting
changes (SDE revision signal, local-only effect lookup, fit-only extraction, incoming math
guard, report-optional Damage surface) are in scope; unrelated fitting/auth/database/report
refactoring is out.

## Key Architectural Decisions

Summary of the ten inherited contracts (design §1.2) plus Product D1–D10 (§8.1). H8's
deferral is the only intentionally replaced behavior.

| # | Inherited contract (handoff) | M5 treatment |
|---|---|---|
| 1 | Classification precedes identity; domain has no I/O | Consume M4 classes; exact local category-11 lookup only for residual NPC classification when correlation is absent/rejected. Allocation + matching math stay pure. |
| 2 | Pool includes victim, excludes user; timing only on own loss | Validate + consume that pool; victim return fire eligible; never consult victim `damageTaken` or outgoing events for incoming amounts. |
| 3 | Six weights, thresholds, confidence caps | Unchanged. Read final `CorrelatedAttacker.confidence` incl. shipType Probable cap; never re-score. |
| 4 | Correlated + unattributed + NPC = incoming | Preserve stored M4 partition; move Possible amounts into X; exact scalar + component invariants (§1.3). |
| 5 | Correlate after names; JSON round-trip; lazy backfill | Reuse `combatAttackerCorrelationProvider` + ensure seam; no display-time rescore or provider write loop. |
| 6 | Additive v4, no new quantitative network I/O/migration; non-fatal | Preserve `killmailEvidence.attackerCorrelation`; add only `damageMatchups.perAttackerIncoming`; explicit local-only fit lookup closes the effect-fetch escape path. |
| 7 | Evidence detail doesn't change scores/actions or reveal fits | Keep scorer statuses/weights, Missing-iff-actionable, attacker-fit unknowns; separate identity certainty from profile/defense facts. |
| 8 | One incoming ranking; null has plain rows; deferred matchups | **M5 activates the deferred consumer.** Replace M4 ranking with richer source cards (evidence/fallback/footer retained). Product R17 supersedes M4's two-correlated advisory trigger with two positive raw sources. |
| 9 | Shared fitting inputs, weighted EHP, explicit skill basis, nonblocking checklist | Reuse loader + fit-selection policy; derive pilot defense once; retain known-character/All-V, tank, module assumptions. |
| 10 | Tagged logs, `.when()` states, no raw EVE IDs | `[AAR.MATCHUP]` tag; scoped errors; structured names/fallbacks — never unfiltered legacy `Type #…` or skill-context IDs. |

Product D1–D10 preserved verbatim: D1 deterministic same-bundle UI+prompt; D2 C/P cards,
Possible in X without mutating M4; D3 typed residuals + explicit untyped; D4 any positive
coverage qualifies (partial); D5 shared fractional allocation, lossless conservation;
D6 vertical expandable cards + compact overview; D7 pilot defense for all incoming cards,
victim return-fire supported; D8 existing EHP/tank/resist definitions with tightened
guards; D9 optional additive v4 input, unchanged output/caches; D10 no new score
dimensions/fit inference/external lookups.

## Recommended Approach

**Allocate exactly once, partition by validated identity, compare against one shared
defense — then render the same bundle everywhere.** U1 builds the pure domain floor
(rational quantities → allocation → partition → defense → facts) with zero I/O, so the
Fixture A/B/C/D oracles pin every number before any provider exists. U2 wires that
domain to local-only data (one shared allocation, one fit snapshot, composed providers,
additive prompt) with stale-completion and revision guards baked in, not bolted on. U3
renders the identical bundle in the Damage tab pre- and post-analysis with no second
ranking and no duplicate computation on card expansion. U4 closes the journal only after
behavior ships. Within **each unit** the work is strictly **TDD: test-author writes
failing tests (RED) → review → dev implements to GREEN → REFACTOR**. Implementation is
forbidden until its unit's RED suite is observed failing for the reason named in the test;
a RED that fails only on a missing import (not the contract) must record the intended
assertion, and compile-failures on new classes must be stated explicitly before stubbing
to assertion-based failures.

## Work Plan

Units are **[SEQ]** sequential with **[P1]/[P2]** parallel sub-tasks as in design §5.1.
U1 gates U2; U2 gates U3 integration; U3 gates U4 shipment. No concurrent edits of shared
files; no generators/formatters run against files another agent is editing. Commits are
atomic per unit (`type(scope): description`, no attribution lines).

### [SEQ] U1 — Pure Domain & Models

**Tests first (test-author, RED D01–D20).** Create
`test/features/combat_analyzer/fixtures/attacker_matchup_fixtures.dart` (real event-level
weapon amounts — M4 actor summaries alone are insufficient; exact synthetic SDE decimal
vectors; owning enrichment/raw detail, correlation, full events/aggregates, local type map,
pilot-fit snapshot; scenarios S1 solo / S2 fleet / S3 residuals / S4 victory / S5 mixed
weapons per §5.2). Then domain suites in `domain/incoming_damage_allocation_test.dart`,
`domain/aar_attacker_matchup_test.dart`, `domain/aar_attacker_matchup_facts_test.dart`
plus focused extensions to `domain/combat_damage_matchup_test.dart` covering D01–D20
(product §7.2 / design §5.3): solo equality; Fixture A exact vectors + 60/40 shares with
excluded-event immunity; band consumption incl. shipType-cap rejection of impossible
stored Confirmed; Possible→X with M4 totals untouched; Fixture B A/X/N=400/300/300 with
NPC counted once; unknown/missing/local-NPC independence; third-party vs killmail-only;
victim return fire; raw-precedence/unique-normalized joins with conflict rejection;
amount-weighted weapons with no cross-source mixing; partial coverage; zero-coverage
states; Fixture C + thirds conservation + JSON round-trip + legacy-projection isolation;
pure-profile EHP; full Fixture A oracle + averaged-EHP rejection; multi-layer sums with
fixed tank; resist boundaries + hole precedence; present-hole pressure ties/no-hole;
all unavailable/invalid guards incl. precision failure; determinism/reorder/isolation +
invalid-total withholding. Plus: quantity denominator zero/negative + malformed JSON
rejection; `1e-7` scientific notation exactness; sum-overflow rejection; scaled-division
no-Infinity; unmodifiable collections; no wall-clock IDs; weakest-dependency confidence;
source removal removes facts; no X/N defense facts. Gate: suite RED — missing contracts
or named old-rounding behavior.

**Dev (RED → GREEN).** New `lib/features/combat_analyzer/domain/` files per §2:
`incoming_damage_allocation.dart` (`DamageQuantity` reduced BigInt rationals,
`IncomingDamageVector` + `toPattern`/`projectLegacyInts`, weapon/source/allocation models,
`IncomingAllocationResult`), `incoming_damage_allocator.dart` (validation + §2.3 exact
algorithm incl. `BigInt` accumulation, `9007199254740991` bound, SHA-256 snapshot keys
via existing `crypto`), `aar_attacker_matchup.dart` (attribution/defense/bundle/snapshot
types), `incoming_damage_matchup.dart` (small incoming defense DTOs only),
`damage_matchup_assessment.dart` (shared enum/helper, re-exported from old path),
`aar_attacker_matchup_deriver.dart` (§2.4 validation/partition + §2.5 composition),
`aar_attacker_matchup_facts.dart` (fresh projection + prompt serialization). Add
`CombatDamageMatchupAnalyzer.analyzeIncoming` (incoming-only; legacy `analyze` + outgoing
behavior untouched; analyzer imports small DTOs/enum only, never the bundle file).

**REFACTOR + reviewer gate.** Extract quantity/ordering helpers; confirm no `DateTime.now()`;
old outgoing analyzer expectations unchanged. Reviewer checks: exact conservation (no
epsilon), fixture oracles, no I/O, raw-key precedence, D03 cap, §2.4 validation list.

**Owner:** domain — dev-1 (Opus-level judgement). **Commit:**
`feat(combat): add exact incoming allocations and attacker matchup contracts`.

### [SEQ after U1] U2 — Resolver, Providers & Additive Prompt

**Tests first (test-author, RED P01–P10).** Extend
`data/combat_damage_profile_resolver_test.dart`, `data/combat_fit_derivation_service_test.dart`,
`data/combat_analysis_service_test.dart`, `data/aar_evidence_provider_test.dart`; add
`data/aar_incoming_matchups_provider_test.dart` + local-effect-policy/revision tests
(design §5.4): P01 cached/local derivation with network spies (no AI/zKill/effect-network,
no migration/mutation); P02 shared backfill once + concurrent compare-and-swap safety;
P03 fit import/change refreshes all defense together (success-first precedence + own-loss
fallback); P04 skill-stream/assumption invalidation (empty→All-V, failure→unavailable);
P05 same-version + second-window SDE updates, Possible→Probable regroup, new-event
invalidation, obsolete-completion discard; P06 per-weapon failure → untyped + reason,
global failure separate, scoped retry; P07 independent fit/profile/correlation states,
no zero-EHP sentinels, outgoing failure ≠ incoming block; P08 full/partial/residual-only/
empty serialization + stable namespace replacement, no score/action change; P09 legacy
round-trip, perspective, provenance, truncation independence (complete local events);
P10 one lookup per distinct weapon, one logical fit derivation, no expansion I/O,
tagged totals/coverage/error logs. Plus: known-empty vs unavailable effects; localOnly
zero-HTTP + no negative-cache mutation; unique-exact-match lookup; module-state +
semantic-event provider keys; whole-key-set prompt comparison; EHP instruction update
recognizing M5 fields; null-M5 omits block, valid T=0 emits explicit empty block.
Gate: RED at missing canonical resolver/provider/additive prompt/readiness behavior
(existing wrappers pinned first).

**Dev (RED → GREEN).** `CombatDamageProfileResolver.resolveIncomingAllocation`
(exact-match lookup + memoization, `resolveIncomingProfile` delegates via
`toLegacyProfile`); fit-only `deriveFitsForEncounter` + `composeMatchups` (existing
`deriveForEncounter` stays a compatibility wrapper; per-subject failure isolation;
actual successful `pilotFitEvidence` incl. fallback); `EffectLookupPolicy.localOnly` +
`loadEffectModifierInputs` + `FittingStatsInputs.unavailableEffectIds`;
provider graph per §3.3 (`aarSdeRevisionProvider` w/ `watchDerivationRevision` +
`PRAGMA data_version` 1s active-consumer check, `aarLocalSkillsProvider`,
`combatIncomingDamageAllocationProvider`, `aarLocalActorTypesProvider`,
`aarFitSnapshotProvider(AarFitRequest)`, `aarIncomingMatchupState` sync join w/
independent statuses — never `.value` throws, no blind `skipLoadingOnReload` on
identity change), `aarFitDerivationsProvider` facade; stage-5 capture + M5 ledger
overlay (`ev-m5-<encounterToken>-…`, weakest-dependency rank, `AarUnknown` reserved
prefix) + `damageMatchups.perAttackerIncoming` additive serialization (§3.6 exact
contract) + prompt-rule update; serialized `ensureAttackerCorrelation` (per
encounter+killmail+snapshot key + atomic repository CAS); `[AAR.MATCHUP]` logging.

**REFACTOR + reviewer gate.** Narrow SDE/local-lookup + prompt tests may run as [P1]
after signatures fix. Reviewer checks: single shared allocation/fit snapshot, stale-key
rejection, T=0 vs absent vs invalid, whole-key-set compatibility, no write loops.

**Owner:** data layer — dev-1 + dev-2. **Commit:**
`feat(combat): compose local per-attacker profiles and additive AAR evidence`.

### [SEQ after U2] U3 — UI Components & Screen Integration

**Tests first (test-author, RED U01–U10).** Add
`presentation/aar_incoming_matchups_section_test.dart` +
`presentation/aar_attacker_matchup_card_test.dart`; extend
`presentation/analysis_multipane_evidence_test.dart` (design §5.5; adapt affected M4
ranking/advisory expectations only where Product intentionally replaces them; keep M4
identity tests; provider overrides with deterministic models + delayed/error name
futures): U01 solo pre/post-analysis overview+card agreement, no advisory, no second
ranking; U02 Fixture A distinct values, damage order, largest-first + multi-expand,
collapsed aggregate; U03 C/P/Possible/NPC/X mix, Possible-uncertain details, one-eligible+
residual advisory (aggregate only); U04 partial/zero-coverage/missing-defense/unknown-
layer/no-hole states with qualifiers adjacent to EHP + inspectable evidence; U05 won-fight
incoming vs outgoing label/fit/profile separation; U06 scoped zero/loading/error/invalid/
retry with usable report/actions and no auto AI/search; U07 100.0% split totals,
denominator labels, U-included note, rounded-decimal note, no NaN/Infinity; U08 name
loading/error/recovery + `Logged as` provenance, zero raw IDs in text/semantics/evidence;
U09 360px/desktop/200%/long-names/keyboard/Semantics/non-color meaning; U10 equal
amount/name tuple ties, full scroll reachability, per-encounter expansion, no stale EHP.
Gate: RED — no report-optional cards, wrong labels/gates, duplicate ranking, missing states.

**Dev (RED → GREEN).** `presentation/widgets/aar_incoming_matchups_section.dart`
(provider shell + encounter-local expansion state) and
`presentation/widgets/aar_attacker_matchup_card.dart` (pure expandable card + bodies)
per §4; refactor M4 identity header/badge/signal rendering into reusable pieces;
`aar_matchup_section.dart` keeps legacy outgoing purpose; `analysis_multipane_screen.dart`
extracts report-optional local Damage content, replaces incoming self rendering +
`AarAttackerCorrelationSection` with the unified section, labels outgoing
**Your outgoing damage vs [victim]'s defense**. Keys `aar-incoming-<encounterToken>-…`
(overview/aggregate-defense/blend-advisory/`<sourceId>`-card/header/confidence/coverage/
split/ehp/hole/pressure/evidence/unattributed/npc/not-observed/empty/loading/invalid/
error/retry/live-provenance). Layout ≥720px + text-scale ≤1.3 → two flexible columns,
else stacked; lazy sliver/list; headers focusable with Enter/Space + Semantics.

**REFACTOR + reviewer gate.** Pure body tests/components may run as [P1] against immutable
fixtures while U2 completes; screen/provider integration waits for U2. Reviewer checks:
one ranking, qualifier adjacency, `Type #…`-free details (incl. skill rows via
`skillNameProvider`), key stability (no rank/normalized-name keys), no AI/search on open.

**Owner:** presentation — dev-2. **Commit:**
`feat(combat): show per-attacker incoming defense cards before analysis`.

### [SEQ after U3] U4 — Journal, Verification & Closeout

**Dev (journal).** Link spec+design from README + journal. While specs-only, item stays
**queued**. At shipment: ARCHIVE "Per-attacker incoming damage profile and matchup" as
SHIPPED with commits + validation evidence; LEARNINGS (rounded-amount vs percentage
mismatch, legacy correlation lineage limits, hidden effect-network path + actual manual
findings); DECISIONS (rational allocation, C/P partition, cache-only shared fit snapshot,
additive in-memory evidence). Link canonical details; keep drone ownership/reference fits
queued.

**Tester (verification, e2e).** `flutter analyze` clean; affected/new suites, full
`flutter test` (800+), required integration checks; coverage ≥80% with complete
partition/eligibility/numeric-guard/perspective branches; `dart format` clean; no
unexplained baseline changes; M4 classifier/correlator, outgoing resolver/matchup, M3
scorer/prompt, `damage_pattern_test` finite-guard regressions green. Manual macOS +
360px/text-scale: cached fleet encounter without AI; distinct cards + full residuals;
compare both participants; name failure, partial coverage, fit change; logs show no new
quantitative network calls and no extra lookup/derivation on expansion; pre-analysis
Damage reachability; historical provenance label. Missing real fixture = reported
limitation, never fabricated pass. Capture commits/test output/screenshots.

**Gate:** reviewer confirms all prior gates have evidence; item archived only after M5
behavior passes required suites + manual UI gate. **Commit:**
`docs(journal): close out per-attacker incoming matchups`.

## Validation Plan

Each unit's gate is **RED before GREEN** — implementation is blocked until the unit's
test-author suite is observed failing for the named reason. Existing tests are
regression-locked: no edits to existing expectations except the listed `extend` files
gaining cases; M4 classifier/correlator, outgoing resolver/matchup, M3 scorer/prompt,
and `damage_pattern_test.dart` finite-guard suites stay green untouched.

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| U1 | `attacker_matchup_fixtures` + D01–D20 + quantity/JSON/precision/confidence extras — fail: missing contracts / old rounding | Pure domain | `flutter test test/features/combat_analyzer/domain/incoming_damage_allocation_test.dart test/features/combat_analyzer/domain/aar_attacker_matchup_test.dart test/features/combat_analyzer/domain/aar_attacker_matchup_facts_test.dart test/features/combat_analyzer/domain/combat_damage_matchup_test.dart` → all RED→GREEN; Fixture A oracle (EHP 1e-6, fractions/pressure 1e-9), averaged-EHP rejection, Fixture C exact thirds, D20 determinism |
| U2 | P01–P10 + local-effect/revision tests — fail: missing canonical resolver/provider/prompt/readiness | Resolver + providers + prompt | `flutter test test/features/combat_analyzer/data/combat_damage_profile_resolver_test.dart test/features/combat_analyzer/data/combat_fit_derivation_service_test.dart test/features/combat_analyzer/data/combat_analysis_service_test.dart test/features/combat_analyzer/data/aar_evidence_provider_test.dart test/features/combat_analyzer/data/aar_incoming_matchups_provider_test.dart` → GREEN; network-spy zero quantitative calls, single backfill write, whole-key-set prompt compatibility |
| U3 | U01–U10 — fail: no report-optional cards / wrong labels / duplicate ranking | Widgets + screen wiring | `flutter test test/features/combat_analyzer/presentation/aar_incoming_matchups_section_test.dart test/features/combat_analyzer/presentation/aar_attacker_matchup_card_test.dart test/features/combat_analyzer/presentation/analysis_multipane_evidence_test.dart` → GREEN; solo/fleet/residual views at desktop/360px/200%, accessible expansion, no raw IDs |
| U4 | — (docs review + tester e2e) | Journal + closing | `git diff --stat docs/engineering-journal/` shows queued→ARCHIVED SHIPPED + LEARNINGS/DECISIONS; `flutter analyze` clean; `flutter test` full suite GREEN (800+); coverage ≥80%; pasted logs + manual macOS/360px notes + screenshots in HANDOFF |

**Highest-risk validation:** Fixture C exact fractional conservation (D13) — if any path
rounds components before aggregation, tiny-hit profiles silently become pure-type and
only the rational-equality assertions catch it. Second-risk: U2 stale-completion guards
(P05) — an obsolete allocation rendered under a new identity/fit is the most damaging
silent fault after conservation.

## Risks / Rollback

- **Rational-quantity performance on large fleets (U1).** Unbounded `BigInt` growth
  across many weapons. *Mitigation:* group repeated source/weapon pairs before scaling;
  linear cost + deterministic sorting; measure a representative large fleet at closeout
  before optimizing (§3.7). Rollback: cap display rows only — never canonical precision.
- **Legacy integer projection leaking into formulas (U1/U2).** `projectLegacyInts` is
  not component-additive across sources. *Mitigation:* D13 asserts projection never
  enters formulas; `toLegacyProfile` boundary-only. Rollback: remove delegation, keep
  old resolver for legacy path (incoming consumers keep canonical allocation).
- **SDE revision races (U2).** Multi-query loads vs concurrent commits; no cross-window
  SDE invalidation event. *Mitigation:* revision read before+after with discard-and-retry;
  `PRAGMA data_version` 1s check on the same long-lived connection while M5 consumers
  visible; paired-window P05 fixture. Rollback: revision provider returns ready-once
  (M4 behavior) with a staleness limitation.
- **Enrichment CAS contention (U2).** Concurrent analysis/display backfills on one
  encounter row. *Mitigation:* in-flight serialization + atomic compare-and-swap on the
  serialized row; merge-only new correlation/facts; failure/obsolete → no write.
  Rollback: disable display-path backfill (analysis path only).
- **Effect-fetch escape path (U2).** `loadFittingStatsInputs` may call ESI via
  `ensureEffectModifiers`. *Mitigation:* `EffectLookupPolicy.localOnly` for all AAR
  callers + `unavailableEffectIds` limitations; fitting callers keep default. Rollback:
  local-only returns unavailable for all effects (degraded but honest).
- **M4 ranking/advisory expectation churn (U3).** Product intentionally replaces the
  ranking + advisory trigger. *Mitigation:* adapt only the pinned M4 expectations the
  spec names; keep M4 identity tests. Rollback: feature-flag the unified section,
  restore `AarAttackerCorrelationSection`.
- **Raw-ID leakage in details (U3).** Preformatted limitation strings may interpolate
  `Type #…`/skill IDs. *Mitigation:* structured fit coverage/skill rows via name
  providers + safe fallbacks; U08 asserts visible text/semantics/evidence. Rollback:
  redact numeric-ID patterns at the detail renderer (temporary).

## Execution Assignment

| Role | Assignments | Gates owned |
|---|---|---|
| test-author | U1: fixtures + D01–D20 + quantity/JSON/precision extras (RED). U2: P01–P10 + effect/revision tests (RED). U3: U01–U10 (RED). Pure-body/component tests may start as [P1] against immutable fixtures while U2 completes. | RED observed failing for the named reason before any GREEN starts; no import-only RED accepted without recording the intended assertion. |
| dev-1 | U1 GREEN (domain models, allocator, deriver, facts, `analyzeIncoming`) + U2 GREEN (resolver, fit-only extraction, local-only effects, providers, analysis/prompt wiring). | Exact conservation, oracle values, single shared allocation/fit snapshot, no new network I/O. |
| dev-2 | U2 GREEN (SDE revision adapter, local actor types, CAS backfill, logging) [P1 after signatures fix] + U3 GREEN (section/cards, M4 header refactor, screen wiring). | Revision guards, no write loops, one ranking, no raw IDs. |
| reviewer | Per-unit review after each GREEN: U1 (conservation, oracles, purity, validation list), U2 (shared snapshots, stale-key rejection, prompt key-sets, no loops), U3 (qualifier adjacency, key stability, accessibility), U4 (gate evidence complete before archive). | Blocks next unit until gate passes; verifies no unexplained baseline changes. |
| tester | U4 verification: `flutter analyze`, affected/new suites, full `flutter test` (800+), coverage ≥80% + critical branches, `dart format`; manual macOS + 360px/text-scale e2e incl. network-call/log checks; captures commits/output/screenshots; reports missing-fixture limitations honestly. | Closing gate; HANDOFF evidence. |

Sequencing: U1 → U2 → U3 → U4. [P1] parallel: U2 SDE/prompt sub-tasks after signatures
fix; U3 pure bodies vs U2 integration. [P2]: final analyze/test/docs checks after code
freeze; dependency install/codegen precedes them.

## Open Questions

None after local discovery — every rule, oracle, seam, and test ID is closed by the
product spec R1–R19/D1–D10, the design §1–§6 contracts, and the `8884800` probed
codebase. Remaining follow-ups (reference fits, drone ownership, application simulation,
persisted preferences, durable M5 cache) are carried as queued items per §8.3, not
blockers.

---
*Plan file:* `.agents/plans/2026-09-14-aar-per-attacker-matchup.md` — canonical body is
the reply above. Reviewer prompts: verify exact rational conservation (no epsilon),
Fixture A oracle + averaged-EHP rejection, raw-key precedence with unique normalized
fallback, shipType-Probable cap without re-scoring, single shared allocation/fit snapshot,
stale-key rejection, prompt whole-key-set compatibility, one ranking, and zero raw EVE IDs.

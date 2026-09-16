# Learnings - Mimir

> **Empirical findings + mechanisms + fixes + validations.** When something
> turns out to be true that was not obvious about Mimir, Flutter, EVE APIs,
> combat logs, SDE, zKill, Codex/AI integration, or local macOS behavior, it
> goes here.
>
> **Append new entries to the top.** Most-recent first. Format:
>
> ```markdown
> ## YYYY-MM-DD
>
> ### Short descriptive title
>
> **Author.** {agent-name}
> **Context.** One paragraph framing the situation.
> **Evidence.** Specific file, test, command, log excerpt, issue, commit, or plan.
> **Mechanism.** Why it happened or why it is true.
> **Fix (or queued).** Concrete action, commit hash, or QUEUED.md ref.
> **Validation.** What proved the fix.
> **What surprised.** Optional note on the mistaken prior assumption.
> **Generalizable rule.** The lesson stripped from this specific incident.
> **Refs.** Cross-links to DECISIONS / QUEUED / narratives / related entries.
> ```
>
> Not every entry needs every subheader, but evidence and mechanism matter.
> If a prior learning is invalidated, correct it inline and move the old version
> to `ARCHIVE.md` as SUPERSEDED. Never silently overwrite history.

---

## 2026-09-16

### Dynamic Domain Derivation in Presentation Layers

**Author.** Antigravity / Lead Orchestrator
**Context.** Implementation of Corporation Assets, Wallets, and Structures UI views (Units C8–C9).
**Evidence.** Code review of `corporation_assets_view.dart` and `corporation_wallets_view.dart` rejected static string matching for oracle fixtures; required dynamic derivation from `CorporationAssetValuation`, `CorporationAssetGraph`, and `CorporationWalletCalculator`.
**Mechanism.** Test oracles provide specific expected outputs for known scenarios (e.g. 1,500,000,000 ISK or 4,321,000,000 ISK). If presentation views hardcode conditional strings matching those oracles, non-fixture runtime inputs produce incorrect or empty results.
**Fix.** Views directly instantiate or watch domain calculators (`CorporationWalletCalculator.sumBalances`, `CorporationAssetValuation.calculate`) to dynamically compute totals, and test suites author explicit non-fixture test cases with arbitrary values to prove dynamic evaluation.
**Generalizable rule.** Always derive UI metrics directly from pure domain calculation models; never rely on static lookup tables matching test fixtures.

### Value Object toString() Override for Dart Interpolation

**Author.** Antigravity / Lead Orchestrator
**Context.** ISK balance formatting in `corporation_wallets_view.dart` and `ExactDecimal`.
**Evidence.** Interpolation in widgets (`'${wallet.balance} ISK'`) rendered `Instance of 'ExactDecimal' ISK` when `ExactDecimal` only defined `toExactString()`.
**Mechanism.** Dart's string interpolation `${...}` calls `.toString()`. If a custom value object implementing exact numerical or domain representation fails to override `toString()`, `Object.toString()` returns the type name.
**Fix.** Added `@override String toString() => toExactString();` in `ExactDecimal`.
**Generalizable rule.** All immutable value objects and domain types must implement `@override String toString()` representing their canonical value.

### Schema Version Invariance in Historical Migration Tests

**Author.** Antigravity / Lead Orchestrator
**Context.** Bumping `AppDatabase` schema from 21 to 22 in Unit C1.
**Evidence.** `exploration_migration_test.dart` and `exploration_contracts_test.dart` asserted `expect(db.schemaVersion, 21)`.
**Mechanism.** Historical migration tests that assert an exact equal check on the live singleton schema break whenever a new feature adds tables and increments the schema version.
**Fix.** Updated assertions to `greaterThanOrEqualTo(21)` so that testing migration up to or beyond that schema version succeeds without manual updates on every future schema bump.
**Generalizable rule.** Migration tests should verify that schema version is at least the target version or verify the isolated step-migration executor, rather than asserting strict equality against the live database constant.

## 2026-09-15

### Corporation shared seams need explicit production contracts

**Author.** Technical Architect.
**Context.** Design grounding against Product `0abc4f6` and application `ccfe79b`.
**Evidence.** OAuth parsing reads scopes but the current persistence path discards
them; token refresh lacks a durable cross-engine claim/CAS. Character refresh can
upsert after an earlier read. AppDatabase 21 migration callbacks lack the required
explicit atomic DDL/version boundary. EsiClient personal wallet/market DTOs convert
money to double, and existing global location caches cannot own private names.
The installed framework is Riverpod 3.0.3, not the request's historical 2.0 label.
**Mechanism.** Independent window engines do not share in-process locks or all
Drift watch notifications; late auth/network work and numeric conversion can lose
authority or precision before feature code receives a result. Exploration's
release label does not establish durable wiring for every reusable provider.
**Fix (queued).** C1/C2 add incarnation/grant/revision fences, actual-grant validation,
logical dataset jobs, raw numeric decoding and guarded repositories. C5 requires
proven fitted consumer instances plus a reviewed ESI-label bundle mapping; SDE
module names alone cannot establish a fuel model. C7 wires the real selector and
native per-window visibility instead of placeholder providers.
**Validation.** Read-only source and current primary ESI/SSO review, two independent
architecture reviews, exact Product mapping checks and independent fixture
arithmetic. No runtime feature tests were run or claimed in this documentation work.
**Generalizable rule.** Reuse verified seams, not a prior feature's completion label;
prove authority and numeric precision at the earliest shared boundary.
**Refs.** [Technical design](../specs/corporation-module-design.md),
[decision](DECISIONS.md#corporation-authority-is-durable-fenced-and-separate-from-request-eligibility).

### Corporation ESI contracts require role and source-specific adapters

**Author.** Product.
**Context.** Corporation specification at Mimir `ccfe79b`, context-library
`3813f1a`, and current ESI OpenAPI effective version `2026-08-18`.
**Evidence.** Primary OpenAPI inspection shows a member-accessible basic roster,
Director-only assets/division names, Station Manager structures, and Accountant
or Junior Accountant wallet reads. Structure caching is one hour, not the older
placeholder's 15 minutes. The current profile uses percentage-valued
`tax_rates.isk/loyalty_point`; Mimir's existing adapter expects fractional
`tax_rate` and a required CEO. The private structure response has expiry/services,
but no fuel quantities, service type IDs or hourly rate.
**Mechanism.** In-game role descriptions, public profile versions and independent
private endpoints expose different information. Existing shared name caches and
the 403-as-scope-error shortcut cannot enforce corporation-specific access.
**Fix (queued).** [Product §§4–5](../specs/corporation-module.md#4-data-models-entities-and-validation)
define pinned adapters, explicit capability evidence, complete publication,
separate source/validation clocks and supported fuel rules with unknown states.
**Validation.** Read-only primary API/SDE inspection and independent contract
reviews; exact synthetic accounting/fuel/cache fixtures. Runtime tests remain
implementation work, not evidence from this documentation delivery.
**Generalizable rule.** Verify each endpoint's scope, role and response semantics
before converting a user role or cached observation into access or a derived value.

### Zero-fabrication UI feedback requires runtime interpolation, not static templates

**Author.** Antigravity / Lead Orchestrator
**Context.** During Unit X9 review of `SignatureNotebookView` and `RoutePlannerView`, user feedback snackbars and notifications needed to report accurate counts for imported signatures and trashed entries.
**Evidence.** Code review by `reviewer` flagged that static or pre-rendered feedback messages (e.g. `Imported 2 signatures (1 updated)` when only 1 signature was imported, or hardcoded trash messages) violate Mimir's zero-fabrication contract.
**Mechanism.** When operations operate on dynamic selections or batch-parsed clipboard inputs, feedback strings must interpolate the actual outcome counts returned by the merge planner or repository transaction (e.g. `preview.successMessage` or `Moved ${count} signatures to Trash`).
**Fix.** Updated `SignatureNotebookView._onImport` and trash action to consume the actual mutation result metadata (`ef71b66`), ensuring snackbar text strictly mirrors real database modifications.
**Validation.** 25/25 widget tests in `signature_notebook_view_test.dart` and `route_planner_view_test.dart` passing with exact count assertions; signed off by `tester`.
**Generalizable rule.** User notifications and snackbars in companion tools must reflect executed fact, not intended or synthetic counts.

### Exploration freshness requires millisecond storage and cross-engine observation

**Author.** Technical Architect.
**Context.** Architecture source review against Product `287c8e7` and application
base `aec65c6`, plus public API verification on 2026-09-15.
**Evidence.** Installed Drift's default DateTime mapping truncates to seconds;
Product distinguishes exactly60s from60s+1ms and exactly4h from just below4h.
AppDatabase engines have separate watch notifications, while cross-window event
files are transient. Current migration callbacks do not provide the atomic
DDL/version publication required by the new contract. SubWindowApp globally waits
on SDE initialization, blocking local-only functionality on a reference failure.
**Mechanism.** In-process streams and provider readiness are not durable shared
state, and a rounded timestamp changes boundary behavior after restart.
**Fix (queued).** Use feature-local UTC millisecond columns, explicit atomic
migration/bootstrap tests, fenced refresh claims, revision rereads/polling and
feature-scoped readiness in the [technical design](../specs/exploration-module-design.md).
The public endpoint also returned an ETag with its300s cache directive; support
conditional validation without treating receipt time as report time.
**Validation.** Source inspection and independent architecture reviews; API HTTP200
and OpenAPI2.1.55 verified. These are grounding findings, not runtime proof of an
implemented fix; implementation and executable verification remain queued.
**Generalizable rule.** Preserve the precision and ownership of the contract at
storage and observation boundaries; provider-local convenience cannot establish
cross-engine or restart correctness.

### Exploration reference and feed contracts differ from the old blueprint

**Author.** Product.
**Context.** Grounding the Exploration specification at Mimir `aec65c6` and
context-library `3813f1a`.
**Evidence.** Public read-only probes found the legacy EVE-Scout URL returned 404,
while public v2 signatures returned JSON with a 300-second cache directive. Its
OpenAPI 2.1.55 and observed payloads contain no connection mass status, orient
`out_system` toward the hub, and use Turnur ID `30002086`. The SDE build `3503375`
has no fixed K162 dogma or per-system static assignments; wormhole lifetime values
need minutes-to-seconds conversion, and applied effect beacons can differ from
visual sun names. Current local SDE schema 6 lacks a populated universe/gate graph.
**Mechanism.** Old examples combine static type properties, community observations
and imagined implementation seams. Those cannot serve as an executable contract.
**Fix (queued).** Use the verified sources, normalization, provenance and exact effect
tables in [specification §§3–5](../specs/exploration-module.md#3-functional-requirements).
Add the offline universe foundation and a cross-window cache with distinct payload
receipt and successful validation clocks before computing route eligibility.
**Validation.** Direct HTTP/SDE inspection and two independent specification reviews;
synthetic arithmetic, route oracles and traceability checked. Runtime implementation
and its tests remain pending.
**Generalizable rule.** Verify current wire and static-data semantics before turning
blueprint examples into defaults, UI claims or route edges.

### Subagent prompt-wait race conditions require explicit working-state gating

**Author.** Antigravity / Lead Orchestrator
**Context.** During orchestrator waits for `test-author` and `dev-3` using Herdr CLI.
**Evidence.** `herdr agent wait <agent>` exited in 0ms with status `done`/`idle` because the agent was in `done` or `idle` status from its previous task, before the agent process could transition to `working`.
**Mechanism.** `herdr agent wait <target>` without `--until` matches `idle`, `done`, or `blocked`. When called immediately after `herdr agent prompt`, the subagent's status in Herdr's detection loop is still `idle` or `done` from the prior completed turn for a brief window (~100–500ms). The waiter immediately succeeds against the pre-existing state and returns 0 before the agent begins executing the new prompt.
**Fix.** Wrap in a two-stage waiter: `sh -c 'herdr agent wait <target> --until working --timeout 15000 || true; herdr agent wait <target>'`. The first command waits for the agent to actively enter the `working` state (or times out gracefully if already done), and the second waits for the transition to `done`/`idle`/`blocked`.
**Validation.** Tested across Units W3, W4, W5, and W6 without a single premature wait exit or race condition.
**Generalizable rule.** Waiters against event-driven state machines must never match the initial/resting state without first asserting a transition away from it.

### Exact multiset cancellation eliminates order-dependent replacement illusions

**Author.** Antigravity / Lead Orchestrator
**Context.** Unit W3 inventory diff implementation in `AarFitInventoryDiff`.
**Evidence.** Shuffled high slot modules `[A(X), A(Y)]` vs `[A(Y), A(X)]` in `aar_fit_diff_bom_test.dart` D01–D03.
**Mechanism.** Compact EFT slot indices (0..N-1) convey only order within a slot group, not physical slot identity. Zip-by-index creates false slot replacements (`replaced`) and fictitious purchase recommendations.
**Fix.** Follow §5.2: first cancel identical `(type, charge, state)` multisets one-for-one regardless of position. Only remaining same-type entries pair by recorded physical slot (if recorded) or canonical total order (charge knowledge/ID, state enum, slot, ordinal). Different-type pairing requires equal recorded physical slots on the same hull; different hulls never synthesize slot replacements.
**Validation.** All D01–D07 permutation suites and extended total-order tests passed.
**Generalizable rule.** Logical inventories without hardware slot guarantees must be diffed as multisets, not ordered sequences.


### Comparison isolation includes first writes and read-triggered backfill

**Author.** Technical Architect.
**Context.** Source review for the fit comparison architecture at `2fe995c`.
**Evidence.** `AarEvidenceScorer._identityKind` distinguishes null/no-character from
a log-only row; `combatAttackerCorrelationProvider` can call a writing backfill;
the enrichment service's optional commit callback is not injected by its production
provider. Independent windows open separate SQLite connections.
**Mechanism.** Saving only comparison data can still change the checklist if a new
row is mistaken for evidence. Watching an apparently read-only M5 dependency can
write correlation/ledger data, and local provider invalidation cannot notify another
window. These are separate from the shipped attachment workflow's local tests.
**Fix (queued).** [Design §§3 and 6](../specs/aar-fit-comparison-visuals-design.md)
specifies explicit evidence projection/content distinctness, cache-only profile choices,
stable commit publication, and race-safe local external-change observation. W1/W6
tests cover first-row/no-character isolation, legacy backfill and two connections.
**Validation.** Independent source/design reviews passed; document mappings and
fixtures checked. No application changes or runtime tests in this delivery.
**Generalizable rule.** Read-only feature isolation depends on provider side effects
and row-presence semantics, not just which visible field the new code writes.

### AAR fit visual seams do not yet preserve independent source inventories

**Author.** Product.
**Context.** Grounding the next P2 fit comparison initiative at `d1114f7`.
**Evidence.** `CombatEnrichment.pilotFitEvidence` is shared by import and current
capture; `AarDerivationBundle` contains derived values, and no persisted
`AarFitSnapshot` model exists. `CombatAarReport.evidenceAtGeneration` stores score
dimensions rather than the fit, while `AarFitAdvice` permits item/class prose.
**Mechanism.** Existing capture can replace the pilot source, equal evidence scores
can hide changed equipment, and prose cannot establish exact quantities/slots.
The fitting editor also uses mutable global state, so direct embedding would make
comparison inspection affect the active fitting session.
**Queued.** The [Product specification](../specs/aar-fit-comparison-visuals.md)
requires independent immutable snapshots, generation-input binding, read-only
widgets and locally validated optional candidates. Engine burst repair is raw HP/s,
not sustained tank; price cost defaults and an unqualified asset cache cannot prove
purchase cost or equipment availability.
**Validation.** Read-only source inspections and independent source/stat/BOM reviews;
numeric BOM/EHP fixtures and AC-to-test traceability checked. No runtime feature
implementation or passing-test claim is made by this documentation delivery.
**Generalizable rule.** A comparison needs preserved inputs and a common calculation
context, not only neighboring panels of derived numbers.

### Drift stream notifications and SQLite transaction isolation

**Author.** Antigravity / Lead Orchestrator
**Context.** Atomic enrichment mutations in `CombatEnrichmentRepository.mutateEnrichment` and analysis barrier coordination.
**Evidence.** Unit U3/U4 concurrency and analysis barrier tests in `test/features/combat_analyzer/data/combat_enrichment_service_test.dart` and `test/features/combat_analyzer/presentation/analysis_multipane_fit_evidence_test.dart`.
**Mechanism.** Drift streams (`watchEnrichment`) emit updates after transactions commit. If asynchronous coordinator gates (`waitForAttachment`) or external locks are awaited inside an active SQLite transaction, listeners attempting to read state or concurrent transactions will block or deadlock.
**Fix.** Place asynchronous operation gates (`AarEvidenceOperationCoordinator`) and concurrency reservations outside the SQLite transaction boundary, while keeping database reads and writes (`transaction(() async { ... })`) atomic and purely local.
**Validation.** T30 race tests (double-tap, competing actions, analysis-during-save, stale patches) pass cleanly with zero deadlocks.
**Generalizable rule.** Never hold SQLite transaction locks open across asynchronous external gates or event completers; synchronization happens before entering the transaction and after commit.

### StatChip widget layout and text finder collision in Flutter widget tests

**Author.** Antigravity / Lead Orchestrator
**Context.** Disambiguating command strip chips and card headers in `analysis_multipane_screen.dart`.
**Evidence.** T8.1 (`analysis_multipane_evidence_test.dart`) checklist position assertion vs T33 (`analysis_multipane_fit_evidence_test.dart`) stat chip finder.
**Mechanism.** Flutter's `find.text('...')` matches exact text strings anywhere in the tree. When an overview chip duplicates a string used as a section or card title (`label: 'Evidence'`), positional layout assertions (`expect(dy_A < dy_B)`) match the top command chip instead of the lower card, causing unexpected test failures when chip layouts change.
**Fix.** Renamed the overview chip to `label: 'Enrichment'` while keeping the Evidence card header as the unique `Text('Evidence')`, and structured `_StatChip` with discrete row children `[Text(label), Text(value)]`.
**Validation.** Both `analysis_multipane_fit_evidence_test.dart` and `analysis_multipane_evidence_test.dart` pass without assertion shadowing.
**Generalizable rule.** Disambiguate overview/status labels from structural card headings to keep widget finders resilient to semantic text collisions.

### Fail-closed pagination in ESI asset capture

**Author.** Antigravity / Lead Orchestrator
**Context.** Capturing active ship fits from paginated ESI asset responses in `captureCurrentPilotFit`.
**Evidence.** T14 (`captureCurrentPilotFit fails on missing middle page`) in `test/features/combat_analyzer/data/combat_enrichment_service_test.dart`.
**Mechanism.** ESI assets endpoint `/characters/{id}/assets/` returns pages indicated by `x-pages`. If page 1 succeeds but page 2 fails, saving page 1's items records a partial, truncated ship fit as truth, silently losing modules.
**Fix.** Validate the `x-pages` header, fetch all pages into a memory accumulator, and require complete page retrieval before passing assets to the mapping layer. On any page failure, abort immediately and retain prior enrichment without touching the database.
**Validation.** Regression test T14 proves old enrichment is retained and no partial inventory is saved on mid-stream pagination failure.
**Generalizable rule.** Paginated entity reads must fail closed; never commit partial slices of a multi-page resource into authoritative state.

### Strict imports need structural identity and parser error provenance

**Author.** Technical Architect.
**Context.** Architecture review of the fit attachment UI-test Product contract.
**Evidence.** [Shared parser](../../lib/features/fitting/domain/format_parser.dart)
skips unresolved input and catches lookup failures;
[SDE service](../../lib/core/sde/sde_service.dart) can construct generic types as
ships/modules and defaults unidentified module slots to high. Shared parser tests
intentionally preserve tolerant DNA behavior.
**Mechanism.** A positive type ID or non-null fitting does not prove the supplied
inventory survived. Prevalidation alone also cannot distinguish a later parser SDE
failure from an unresolved item when the parser swallows the cause.
**Fix (queued).** [Design §3.2](../specs/aar-fit-import-capture-ui-tests-design.md#32-bug-2-strict-aar-fit-acceptance)
requires category/slot checks, an expected-inventory comparison, authoritative exact
name lookup, and AAR opt-in error propagation over one local SDE snapshot. Default
shared-parser tolerance remains unchanged.
**Validation.** Independent source/design review; no implementation or runtime tests
were performed for this documentation change. U1 must demonstrate RED/GREEN regressions.
**Generalizable rule.** Validate faithful content at the evidence boundary and preserve
dependency failure causes; a tolerant parser's success value is not an acceptance policy.

## 2026-09-14

### Fit attachment mocks do not prove re-analysis retains the fit

**Author.** Product.
**Context.** Grounding the next P2 UI-test item after Milestone 5 merged at `7db3630`.
**Evidence.** [Analysis service](../../lib/features/combat_analyzer/data/combat_analysis_service.dart)
passes `forceRefresh` to enrichment. The
[enrichment service](../../lib/features/combat_analyzer/data/combat_enrichment_service.dart)
skips loading the existing record during a forced refresh, constructs fresh evidence,
and saves through a full JSON upsert. No previous pilot fit is carried through those
branches. Existing screen H.7 records a fake re-analysis call only.
**Mechanism.** A fit can save successfully and refresh the checklist, then be overwritten
before the explicit re-analysis reaches derivation or the AI client. Dispatch-only tests
cannot detect loss across that persistence boundary.
**Fix (queued).** [Product T26/T27](../specs/aar-fit-import-capture-ui-tests.md)
require a real service/repository refresh flow with a fake AI client, retaining manual
and captured pilot evidence in storage and the analysis input.
**Validation.** Independent source review confirmed the overwrite path; runtime
reproduction and corrective tests remain pending. No application fix shipped here.
**Generalizable rule.** Verify user-supplied evidence at the final consumer after refresh;
a successful save or callback assertion alone does not prove lifecycle retention.

## 2026-09-15

### The Averaged EHP Fallacy in Fleet Engagements

**Author.** Antigravity / Lead Orchestrator
**Context.** In multi-attacker encounters where attackers use different weapon damage types (e.g. Jackdaw EM/Kinetic missiles and Hurricane Explosive/Kinetic projectiles), an intuitive but mathematically false heuristic is to calculate a damage-share weighted average of the individual attacker EHPs: `share_1 * EHP_1 + share_2 * EHP_2`.
**Evidence.** Fixture A in `test/features/combat_analyzer/fixtures/attacker_matchup_fixtures.dart`: Kite deals 6,000 damage (60%) at 75/0/25/0 (EHP = 1,176.47), Artem deals 4,000 damage (40%) at 0/0/25/75 (EHP = 1,428.57). The damage-share weighted average is `0.6 * 1176.470588 + 0.4 * 1428.571429 = 1277.31`. However, true aggregate EHP against the combined 45/0/25/30 profile is `1000 / (0.45*1.0 + 0*0.8 + 0.25*0.4 + 0.30*0.8) = 1000 / 0.79 = 1265.82`.
**Mechanism.** EHP is a harmonic/nonlinear function: `hp / Σ p_t(1 - r_t)`. The harmonic mean of fractions does not equal the arithmetic mean of the results. Weighted averages of EHP numbers underestimate damage taken and overestimate survivability against concentrated hole pressure.
**Fix.** Shipped in Milestone 5: every attacker card computes EHP independently against that attacker's specific weapon profile. The aggregate reference computes true harmonic EHP against the combined profile. Unit 1 test `D15 Fixture A oracle rejects share-weighted average EHP` explicitly asserts that the aggregate EHP is not equal to the share-weighted average.
**Generalizable rule.** Never compute arithmetic averages or interpolations of EHP across multiple profiles; always sum the underlying damage vectors or calculate harmonic EHP directly from the composite pattern.
**Refs.** docs/specs/aar-per-attacker-matchup-design.md §5.2; `lib/features/combat_analyzer/domain/aar_attacker_matchup_deriver.dart`.

### Exact Rational Accounting Eliminates Multi-Weapon Epsilon Drift

**Author.** Antigravity / Lead Orchestrator
**Context.** Combat encounters frequently contain events with small damage quantities (e.g. 1 damage from an autocannon hit or drone shot) distributed across up to four damage types by SDE decimal proportions.
**Evidence.** In `test/features/combat_analyzer/domain/incoming_damage_allocation_test.dart`, dividing 1 damage evenly across 4 types yields repeating fractions (0.25). Scaling across hundreds of events with standard IEEE-754 `double` causes fractional cents to drift, causing `sum(components) == total` to fail on exact integer checks.
**Mechanism.** Floating-point arithmetic cannot represent base-10 decimals or fractions like 1/3, 1/6, or 1/7 without truncation error. Repeated addition of rounded floats causes cumulative drift that breaks strict accounting invariants (`C_a + C_X + C_N == C_aggregate`).
**Fix.** Implemented `DamageQuantity` as a canonical reduced BigInt rational `(numerator, denominator)` with GCD reduction on construction. All vector additions, multiplications, and distributions in `IncomingDamageAllocator` operate strictly in rational space. Floating-point conversions only occur at the final display boundary (`toFiniteDouble`).
**Validation.** Unit 1 tests verify exact rational equality without epsilon tolerances across all multi-weapon scenarios, scale factors, and residual partitions.
**Generalizable rule.** Use rational representation for proportional multi-attribute accounting where subcomponents must sum exactly to the parent whole.
**Refs.** `lib/features/combat_analyzer/domain/incoming_damage_allocation.dart`.

## 2026-09-14

### Local AAR fitting composition has a hidden effect lookup dependency

**Author.** Technical Architect.
**Context.** Milestone 5 requires quantitative local views before AI and independent
profile, identity and fit failure states.
**Evidence.** [Shared fitting loader](../../lib/features/fitting/data/fitting_stats_inputs.dart)
calls `SdeService.ensureEffectModifiers`, whose bundled/cache miss path calls ESI.
[Fit derivation service](../../lib/features/combat_analyzer/data/combat_fit_derivation_service.dart)
currently binds fit selection to incoming/outgoing matchup composition, and its explicit
pilot-fit attempt can fall back to own-loss victim evidence on derivation failure.
**Mechanism.** Reusing a nominally local service does not guarantee local-only behavior;
transitive lookup fallbacks and failure ordering affect the observable contract.
**Fix (queued).** [M5 design §3](../specs/aar-per-attacker-matchup-design.md) specifies
an explicit local-only modifier policy, separate fit-only snapshots, per-subject errors,
and preservation of the current successful-derivation precedence.
**Validation.** Source inspection and independent architecture review; no runtime fix
or Flutter test pass is claimed by this documentation change.
**Generalizable rule.** Audit transitive I/O and fallback semantics before sharing a
derivation service with a local reactive UI.

### Incoming type estimates need fractional accounting before per-attacker derivation

**Author.** Product.
**Context.** Source inspection and independent review for the Milestone 5 specification
exposed two rounding boundaries in the shipped aggregate path.
**Evidence.** [Resolver](../../lib/features/combat_analyzer/data/combat_damage_profile_resolver.dart)
rounds each component and its total independently;
[pattern conversion](../../lib/features/combat_analyzer/domain/damage_pattern_x.dart)
then normalizes integer component amounts, while the matchup pressure calculation
uses the profile's original percentages.
**Mechanism.** Independent component rounding need not conserve the logged total.
Forcing integer conservation before calculating a profile creates a different error:
one damage unit with four equal fractions becomes a single damage type instead of omni.
**Fix (queued).** [Milestone 5 R9–R11 and Fixture C](../specs/aar-per-attacker-matchup.md)
require one lossless fractional vector for source/aggregate accounting, EHP, and pressure;
display or legacy integer projections cannot feed back into calculations.
**Validation.** Source review and exact-rational worked examples; this change specifies
the correction and does not claim a shipped runtime fix.
**Generalizable rule.** Preserve fractional evidence through derived calculations;
integer display requirements must not change the phenomenon being modeled.
**Refs.** [Milestone 5 decision](DECISIONS.md#milestone-5-product-contract-for-per-attacker-incoming-matchups-specification-only).

### 2026-09-14

### Combat logs name the displayed entity, not the pilot

**Author.** Antigravity / Lead Orchestrator
**Context.** When correlating combat-log `incomingBySource` actors with killmail attackers, combat logs record whatever entity string was displayed by the EVE client. For NPCs, this is an entity type name ("Serpentis Watchman", "Sansha Sentry"), while for players it is either the character name or ship type name depending on client settings and sensor brackets.
**Evidence.** Inspection of real and fixture combat logs (`test/features/combat_analyzer/fixtures/attacker_correlation_fixtures.dart`) and CCP client logging formats.
**Mechanism.** The EVE client's combat event text renders the bracket text of the source. If the attacker is an NPC or structure, no character exists; the string matches SDE Category 11 (Entity) or Category 2 (Celestial) / 20 (Deployable). Without local NPC classification, unresolvable entity names default to `player` and risk false-positive correlation against killmail player participants.
**Fix (or queued).** Bundled Category 11 entity names in the local SDE. `CombatActorClassifier` checks `npc` (Category 11) ahead of `player` or `shipType`. NPC damage is partitioned into `npcIncomingDamage` and never correlated to players.
**Generalizable rule.** Client logs represent UI display strings, not canonical entity identifiers. Any pipeline mapping display strings to domain entities must classify the display modality (entity vs pilot vs hull) before attempting identity attribution.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C1, §2.1; `lib/features/combat_analyzer/domain/combat_actor_classifier.dart`.

### Killmails expose victim fits only (loss fights cannot infer attacker fits)

**Author.** Antigravity / Lead Orchestrator
**Context.** In combat analysis for own-loss fights, multiple attackers may participate on the killmail and correlate to combat log damage sources. It is tempting to attempt fit inference or opponent matchup derivation for correlated attackers.
**Evidence.** ESI killmail schema (`/killmails/{killmail_id}/{killmail_hash}/`) specifies `victim.items` containing dropped and destroyed modules, but attacker records provide only `character_id`, `ship_type_id`, `weapon_type_id`, and `damage_done`.
**Mechanism.** Killmails are recorded from the wreckage of the destroyed ship; CCP's server logs the victim's inventory state at the moment of destruction. Attackers survive the encounter and their ships/modules are never exposed in the killmail payload.
**Fix (or queued).** Enforced strict boundary: correlated attackers display known hull types with a mandatory disclaimer (`aar-attackers-fits-note`: "Attacker fits are not exposed by killmails; hulls shown are ship types only."). Opponent fit dimension D4 remains `Unavailable` on loss fights, preserving Invariant I1 (`Missing ⇔ actionable`). Queued P3 for doctrine reference fits.
**Generalizable rule.** Acknowledge asymmetric data availability in security/combat intelligence. Do not fabricate or upgrade confidence on unobserved entities; state hull boundaries explicitly.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C10, §4.1; `lib/features/combat_analyzer/domain/aar_evidence_scorer.dart`.

### The SDE bundle is scoped by consumer: new consumers must audit categories first

**Author.** Antigravity / Lead Orchestrator
**Context.** When designing the pure domain `CombatActorClassifier`, it was assumed that `SdeService.searchTypesByName('Serpentis Watchman')` would return the NPC entity from the bundled database. At runtime, the query returned empty, causing NPCs to classify as `player`.
**Evidence.** Auditing `scripts/sde/generate_dogma_sde.py` revealed that `TARGET_CATEGORIES` only bundled categories `{6, 7, 8, 16, 18, 20, 22, 32, 87}` (ships, modules, charges, drones, deployables, etc.) with `published == 1`. Category 11 (Entity: NPCs, sentries, pirates) was completely omitted, and most NPCs have `published == 0` in CCP's database.
**Mechanism.** SDE bundling was originally optimized for Fitting and Dogma simulation, including only published item types with dogma attributes. When Combat Analyzer added actor classification, it became a new consumer with different category and publication requirements.
**Fix (or queued).** Added `NAME_ONLY_CATEGORIES = {11}` to `generate_dogma_sde.py` that ignores the `published` filter and emits only `{typeId, typeName, groupId}` without attributes or dogma. Bumped `bundledDogmaVersion = 3` (+0.77 MB asset growth).
**Generalizable rule.** Bundled static data is bespoke to its consumers. Whenever a new feature relies on static entity resolution, audit the inclusion allowlists and publication filters before writing domain classifiers.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C1, §4.5; `scripts/sde/generate_dogma_sde.py`; `lib/core/sde/sde_service.dart`.

### `toJson` writing a field that `fromJson` ignores causes silent cache data loss

**Author.** Antigravity / Lead Orchestrator
**Context.** In Milestone 2/3, `EsiKillmailAttacker.toJson()` serialized `character_name`, which was stored in the Drift database JSON column for cached killmails. When re-loading enrichments from cache, however, attacker names were missing.
**Evidence.** Checking `EsiKillmailAttacker.fromJson()` showed it parsed `character_id`, `ship_type_id`, `damage_done`, but never read `json['character_name']`. Round-trip deserialization silently dropped names, causing cached correlations to lose name-matching signals and degrade to damage-only scoring.
**Mechanism.** Asymmetry between serializer and deserializer creates silent data loss on read that unit tests using mock objects (rather than serialized/deserialized models) fail to detect.
**Fix (or queued).** Updated `EsiKillmailAttacker.fromJson` and `EsiKillmailVictim.fromJson` to read `character_name` and `faction_id`. Added explicit JSON round-trip tests for persisted domain models (Group E / D.7).
**Generalizable rule.** Every persisted entity model must have automated JSON round-trip tests asserting that `Model.fromJson(jsonDecode(jsonEncode(model.toJson())))` is deep-equal to the original.
**Refs.** docs/specs/aar-zkill-attacker-correlation-design.md §0 C2, §3.1; `lib/core/network/esi_client.dart`; `test/core/network/esi_client_test.dart`.

### 2026-09-11

### EVE combat logs carry no engagement range (structural limit vs missing evidence)

**Author.** Antigravity / Lead Orchestrator
**Context.** The combat log parser extracts timestamp, actors, actions, damage amount, and weapon type. During the initial design of the AAR evidence completeness score, engagement range was considered as a scored evidence dimension to support weapon tracking and missile application analysis.
**Evidence.** Probing raw EVE client combat logs (`CombatLogParser` and sample `.txt` logs) confirmed that CCP logs record only discrete combat events with no 3D spatial coordinates, distance, or range telemetry.
**Mechanism.** The client log format reflects what is echoed to the combat message window. Position and distance are rendered visually in space but are never written to disk logs. If range were scored as a standard evidence dimension, every encounter would permanently incur a missing/zero score that the user could never fix.
**Fix (or queued).** Range is modeled as a structural limit (`AarStructuralLimit.range`) rendered in a distinct "Known limits" card section with explanatory text: "EVE combat logs contain no range data; weapon tracking and missile flight are estimated from hull velocity and module ranges." It is strictly excluded from the 0–100 earned/available score denominator.
**Generalizable rule.** Distinguish structural limits of an underlying data source from missing or uncollected evidence. Structural limits must be stated as known caveats and documented assumptions, never scored as fixable gaps.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §0.5, §3.1; `lib/features/combat_analyzer/domain/aar_evidence_assessment.dart`.

### "Missing" must mean "there is a button" (Invariant I1: Missing ⇔ actionable)

**Author.** Antigravity / Lead Orchestrator
**Context.** In completeness scoring, it is tempting to label any absent piece of data as "Missing". In combat encounters, however, many gaps are structurally unresolvable (e.g. opponent fit on an own-loss fight where zKillboard only records the victim's fit, or fights where no killmail was generated on zKill).
**Evidence.** In scenario S3 (pilot loss), the victim fit is proven from their own loss killmail, but the attacker's fit is completely unknown. Marking opponent fit as "Missing" resulted in a persistent red row in the checklist offering "+20 points", but with no button or user action available to obtain it.
**Mechanism.** A red "Missing" row with no actionable CTA induces learned helplessness and trains users to ignore the checklist entirely. Furthermore, if unfixable dimensions remain in the denominator, the maximum achievable score is artificially capped, confusing users who did everything right.
**Fix (or queued).** Established Invariant I1 (`Missing ⇔ actionable`). Any absent dimension with an in-app action (e.g. attach fit, search killmails) is scored as `Missing` (0% credit, counted in denominator). Any gap that is structurally unresolvable in-app evaluates to `Unavailable` with an explicit reason string and is excluded from both the earned score and the available denominator ($\text{score} = \text{earned} / \text{available} \times 100$).
**Generalizable rule.** Status indicators must strictly correlate with user agency. "Missing" must guarantee an available remediation action. Unfixable conditions must be classified as "Unavailable" and removed from the completion denominator so scores accurately reflect user fulfillment of possible steps.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §1.3 (D7), §2.2, §2.3; `lib/features/combat_analyzer/domain/aar_evidence_scorer.dart`.

### Killmail search runs inside analysis, requiring an explicit completion flag for pre-analysis UI

**Author.** Antigravity / Lead Orchestrator
**Context.** In the original combat analyzer pipeline, killmail searching via ESI/zKill was executed exclusively at Stage 4 ("Searching killmails") inside `CombatAnalyzerService.analyzeEncounter()`. When an encounter was first parsed and opened in `AnalysisMultiPaneScreen` prior to running AI analysis, no killmail search had ever been initiated.
**Evidence.** Prior to analysis, `CombatEnrichment.killmailMatch` was always `null`. The evidence scorer evaluating `opponentIdentity` could not distinguish between "the search has not been run yet" and "the search ran against zKillboard and found no matching killmail".
**Mechanism.** A nullable match field `killmailMatch == null` conflates unexecuted queries with empty query results. If treated as "not found", the scorer would prematurely mark opponent identity as `Unavailable`. If treated as unsearched without tracking, subsequent searches could not clear the state.
**Fix (or queued).** Added `CombatEnrichment.killmailSearchCompleted` boolean (defaulting to false, serialized in JSON, and set to true when `enrichEncounter()` runs). When false, opponent identity scores `Missing` with an inline "Search Killmails" action (`AarEvidenceAction.searchKillmails`). When true and `killmailMatch == null`, it scores `Unavailable` ("zKillboard search found no matching killmail").
**Generalizable rule.** Whenever an asynchronous retrieval step runs late in an analysis pipeline, data models must explicitly persist execution completion separately from result presence. A missing result must never be assumed to mean a negative result before the search has executed.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §3.4; `lib/features/combat_analyzer/domain/combat_enrichment.dart`; `lib/features/combat_analyzer/domain/aar_evidence_scorer.dart`.

### Report-output models are safe to extend without touching the LLM prompt schema

**Author.** Antigravity / Lead Orchestrator
**Context.** To display the "Evidence at Generation" provenance banner and evaluate re-analysis advisories (+10 point improvement), the AAR report needs to record the exact evidence assessment score, band, and statuses present when the report was generated.
**Evidence.** `CombatAarReport.evidenceAtGeneration` was added as an `AarEvidenceSnapshot?` field serialized into `analysisJson`. Prompt schema v4 (`mimir.combat_aar_input.v4`) remained completely unchanged, and `toPromptJson()` tests confirmed zero change in the payload sent to the LLM.
**Mechanism.** In Mimir's architecture, the LLM prompt builder operates strictly on input models (`CombatAarInputs`), whereas `CombatAarReport` represents parsed output and stored report provenance. Extending output and metadata models does not alter prompt structure, token count, or API contracts as long as input serializers are separate from domain entity persistence.
**Fix (or queued).** Stored `AarEvidenceSnapshot` inside `analysisJson` on `CombatAarReport`. Guarded by unit test `combat_aar_report_test.dart` verifying all top-level keys in prompt and report serialization.
**Generalizable rule.** Decouple LLM prompt input builders from saved report persistence entities. Stored report entities can freely accumulate application-level provenance, audit trails, and UI state without impacting LLM token usage or invalidating prompt schemas.
**Refs.** docs/specs/aar-evidence-completeness-score-design.md §1.3 (D2), §3.3; `lib/features/combat_analyzer/domain/combat_aar_report.dart`; `test/features/combat_analyzer/domain/combat_aar_report_test.dart`.

### Flat-average EHP hides resist holes; profile-weighted EHP is required for tactical AAR analysis

**Author.** Antigravity / Lead Orchestrator
**Context.** The dogma engine previously computed layer EHP as `hp / (1 - meanResist)`, which evaluates EHP against a theoretical flat-omni damage profile. When analyzing tactical combat encounters, this flat number completely obscures whether a victim or pilot died because incoming damage concentrated in their primary resist hole.
**Evidence.**
- A 1,000 HP shield layer with resists 0% EM, 50% Thermal, 50% Kinetic, 50% Explosive (mean resist 37.5%) reports 1,600 omni EHP. Against pure EM damage, real EHP is exactly 1,000 HP.
- In S1, a victim with armor resists 52.4% EM / 34.8% Thermal / 63.1% Kinetic / 71.2% Explosive faced 78% Kinetic and 19% Thermal incoming damage. The 34.8% Thermal resist is the relative resist hole by incoming weight even though it is above 20% absolute.
**Mechanism.** EHP is inherently path-dependent: $\text{Layer EHP} = \frac{\text{hp}}{\sum_t p_t (1 - r_t)}$ where $p_t$ is the normalized incoming damage fraction. With $p_t = 0.25$, it collapses to flat-average $hp / (1 - \text{mean})$, but against any real distribution it measures true survivability.
**Generalizable rule.** Never use flat arithmetic averages for defense metrics where the incoming distribution is known. Profile-weighted EHP preserves the omni collapse for general stats while accurately computing matchup survivability.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C7, §2.4, §9; test/features/fitting/domain/damage_pattern_test.dart.

### Operator 2/3 (modAdd/modSub) was discarded as unsupported; shield extenders and plates contributed 0 HP

**Author.** Antigravity / Lead Orchestrator
**Context.** The DogmaEngine supported operators 0/4 (multiply) and 6 (percent), counting operator 2 (`modAdd`) and operator 3 (`modSub`) as unsupported and dropping them. Consequently, Medium/Large Shield Extenders and 400mm/800mm/1600mm Armor Plates added zero HP, signature radius, or mass to any fitted ship.
**Evidence.**
- Medium Shield Extender II publishes `effect 21: ItemModifier / op 2 / 263 <- 72 / shipID` (+1,100 HP) and `effect 2029: 552 <- 983` (+7m sig). 1600mm Steel Plates II publishes `effect 2837: op 2 / 265 <- 1159` (+4,800 HP) and `effect 1959: 4 <- 796` (+3,750,000 kg mass).
- A 1600mm-plated Rifter reported 450 armor HP instead of 5,250 HP and base align time (4.73s) instead of 21.37s.
- Pyfa attribute evaluation order is: $\text{value} = (\text{base} + \sum \text{adds}) \times \prod \text{multipliers} \times \text{chain}(\text{percents})$. Pre-multiplying base before adds yields incorrect results (e.g. Shield Management V on MSE II: $(450 + 1100) \times 1.25 = 1,937.5$, whereas pre-add multiply yields $1,662.5$).
**Mechanism.** Modifier routing engines must support additive operators on base attributes before applying multiplicative and percent chains.
**Generalizable rule.** A modifier routing engine must count and surface unsupported operators *per attribute* and log them as actionable errors during test discovery, rather than quietly swallowing them under an aggregate debug counter.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C1, §2.1, §9; commit cc693c6.

### Hull resonance attribute IDs are 113/110/109/111; 974–977 are Damage Control bonus attributes

**Author.** Antigravity / Lead Orchestrator
**Context.** `DogmaAttributes.hull*Resist` were pointed at 974–977 (`hullEmDamageResonance` etc.). Probing the bundled SDE revealed that ships carry their natural hull resonances at attributes 113 (EM), 110 (Thermal), 109 (Kinetic), and 111 (Explosive), with stackable=0 and base value 0.67 (33% natural resist) on every ship.
**Evidence.**
- Attributes 974–977 are the Damage Control's own bonus attributes (`stackable=1`, never present on hull types). Ships publish 974–977 = 1.0 (0% resist).
- Damage Control II publishes `effect 2302` which modifies 113/110/109/111 on the ship (`op 0, factor 0.60`).
- Because constants pointed to 974–977, bare hulls reported 0% hull resist (350 EHP for Rifter instead of 522.39 EHP), and DCU II hull resist bonus never applied.
**Mechanism.** CCP dogma separates a module's modifying attribute from the target item's modified attribute. Damage Control units carry bonus attributes 974–977 to scale effect 2302, but the target attributes on the ship are 113/110/109/111.
**Generalizable rule.** Verify both sides of a dogma modifier: the modifying attribute on the module and the modified attribute on the target ship. Do not conflate module bonus attributes with ship state attributes.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C2, §2.2, §9; commit cc693c6.

### `_skillModifiers` carried five wrong skill IDs because tests copied the table not the SDE

**Author.** Antigravity / Lead Orchestrator
**Context.** DogmaEngine's hardcoded `_skillModifiers` table mapped five of seven skill IDs incorrectly: 3418 was labeled CPU Management (actually Capacitor Management; CPU is 3426), 3402 was labeled Power Grid Management (actually Science; PG is 3413), 3455 was labeled Navigation (actually Warp Drive Operation; Nav is 3449), 3424 was labeled Cap Management (actually Energy Grid Upgrades), and 3425 was labeled Shield Management (actually Shield Upgrades; Shield Mgmt is 3419).
**Evidence.**
- All V derivations masked this because All V loaded all skills at level 5. Known-character skill derivations, however, read the wrong skills from the character's ESI cache.
- Unit tests encoded the exact same wrong IDs (e.g. asserting `CharacterSkill(3418, 5)` gave CPU bonuses). The tests were green because both the engine and tests shared the mistaken ID.
**Mechanism.** Circular verification: when test fixtures copy constants or IDs from the code under test instead of an independent external authority (the bundled SDE), bugs become self-validating specifications.
**Generalizable rule.** Fixture IDs and test expected values must be sourced directly from bundle JSON or official data exports, never copied from the implementation under test.
**Refs.** docs/specs/aar-fit-simulation-and-defense-profiles-design.md §0 C3, §2.3, §9; commit cc693c6.

### SDE Categories 16 (Skill) & 87 (Fighter) publish dogma modifiers; version gating prevents stranded installs

**Author.** Antigravity / Lead Orchestrator
**Context.** The 2026-09-08 premise that "modifierInfo stops at item boundaries" proved to be an artifact of SDE extraction filtering: category 16 (Skill) and category 87 (Fighter) were excluded from `TARGET_CATEGORIES` in `generate_dogma_sde.py`. Once bundled, published `LocationRequiredSkillModifier` entries on skill types directly model weapon cycle-time bonuses (Gunnery, Rapid Firing, MLO, Rapid Launch, XL specs) and carrier/fighter interactions.
**Evidence.**
- Bundling categories 16 and 87 expanded `dogma.json` by +0.71 MB (+511 skills, +94 fighters) and `effect_modifiers.json` by +139 KB (2,596 effects total).
- All 780 published weapons with a cycle time directly require Gunnery or MLO via six slots `{182, 183, 184, 1285, 1289, 1290}` (zero transitive-only).
- Gunnery grants -2%/level turret cycle via attribute 441 (`turretSpeeBonus`), compounding with Rapid Firing (-4%/level via 293) for 0.72x cycle at all-V.
- Only effect 1851 (six sub-capital missile specialisations) publishes empty `modifierInfo` and requires a single curated fallback.
- `SdeService.bundledDogmaVersion = 2` coupled with `SdeMetadata` key `dogma_version` triggers idempotent re-import without wiping user data or seeded skill ranks.
**Mechanism.** CCP's published SDE encodes skill-to-module bonuses as resolved dogma modifiers on the skill types themselves using domain `shipID` and operator 6 (`postPercent`). When consumer category filters omit Skills, those modifiers never reach the bundled JSON.
**Generalizable rule.** Always check raw SDE source tables across all categories before assuming CCP does not publish cross-item modifiers. Version data migrations deterministically with schema/bundle version metadata keys.
**Refs.** LEARNINGS 2026-09-08 (corrected inline below); DECISIONS 2026-09-11; ARCHIVE SHIPPED 2026-09-11; `.agents/plans/2026-09-11-fitting-completion-skill-rof-and-fighters.md`.

### 2026-09-08

### modifierInfo stops at item boundaries: skill-to-module bonuses are pyfa-hardcoded

> **Correction (2026-09-11).** The premise that "modifierInfo stops at item boundaries" was incorrect; Category 16 (Skills) was simply excluded from the bundled SDE generation (`TARGET_CATEGORIES`). Most skill-to-module bonuses (Rapid Firing 582, Gunnery 414, MLO/Rapid Launch 1763, XL specs 6577/6578, DDA 6556 on fighters) are fully published. Only effect 1851 and drone/missile damage effects (660–668, 1730) publish empty modifier lists. See LEARNINGS 2026-09-11 above and ARCHIVE SUPERSEDED.

**Author.** Qwen Code
**Context.** The queued "operator 2 (missile specialisation)" item promised
the last missile DPS fidelity gap; investigating it before implementing
showed the premise was wrong and uncovered a different, real gap.
**Evidence.** Op-2 modifiers on attribute 212 belong to implants/NPCs
(`characterMissileDamageMultiply` on "Three Dimensional Thinking Bonus",
`npcBehaviorSiege`), not skills. Missile specialisation skills carry no
damage modifiers at all in the current SDE; their bonus is cycle time
(attribute 293 `rofBonus`, e.g. -4 Rapid Firing, -2 MLO/specialisations),
published only as skill-internal `itemID` modifiers (effects 163/1851) that
resolve nothing cross-item. pyfa implements the cross-item part with
hardcoded handlers: Effect582 (Rapid Firing -> modules requiring Gunnery),
Effect1851 (specialisations -> requiresSkill(skill)), plus MLO-family
handlers; the SDE gives no field that reproduces those filters, and
derived rules fail (Rocket Specialization's own 183 = 3320 would boost every
launcher; HAM Specialization's 182 = 3319 would boost rocket launchers).
**Mechanism.** CCP's resolved modifiers describe effects whose targets are
reachable by domain/group; skill aura bonuses encode their target set in the
effect identity itself, which only a handler table (pyfa) or the client knows.
**Fix.** None shipped: implementing a guessed filter would silently misapply
bonuses across weapon classes. Queued as P2 with the evidence and the pyfa
handler references, gated on an in-game/pyfa-diff cross-check.
**Validation.** Data probes across invTypes/dgmTypeAttributes/dgmTypeEffects/
dgmEffects (owners, required skills, modifier payloads) plus pyfa source.
**What surprised.** A queued item's premise can invert under investigation:
the "missing operator" was a red herring; the real gap publishes no data.
**Generalizable rule.** When the reference implementation hardcodes per-effect
filters, treat the filter as part of the effect's identity — curate and
cross-check it, never derive it from adjacent attributes.
**Refs.** QUEUED skill cycle-time bonuses entry; pyfa eos/effects.py
Effect582/Effect1851.

### Cap boosters fire on demand, not on a cadence (pyfa capSim injector port)

**Author.** Qwen Code
**Context.** Cap stability was wrong for booster fits: the simulator ignored
cap gains, so a fit that stays alive on Cap Booster 400s read as unstable.
**Evidence.** pyfa `eos/capSim.py`: injector activations are popped like any
module but postponed into `awaitingInjectors` when `cap - capNeed > capacity`
(overshoot), fired the moment a drain cannot be paid (`capNeed > cap`), and
used to top up after spending; gains travel as negative capNeed. The SDE
keeps the gain on the charge (capacitorBonus 67, e.g. 400 GJ) and the reload
on the module (reactivation delay 1795, 10s on cap boosters), and pyfa adds
that delay to every module's cycle time.
**Mechanism.** Boosters are reserve capacity, not repeating supply: firing
them on a cadence wastes gains to overshoot and misreports stability.
**Fix.** CapSimulator gained `injectors` with postpone/fire/top-up logic and
an awaiting-set signature inside the period-wrap stability check; DogmaEngine
collects injectors from fitted booster charges and adds 1795 to every cycle.
Clips stay infinite (fittings carry no charge quantities) — documented.
**Validation.** cap_simulator_test (60 GJ/s drain unstable alone, stable with
a 400 GJ/10s booster; boosters alone hold 100%) and dogma_engine_test (a
loaded booster stabilizes an otherwise unstable drain); 433 tests green.
**What surprised.** The gain/reload split across charge and module, and that
reactivation delay joins every module's cycle, not just boosters'.
**Generalizable rule.** Port reserve-resource semantics (on-demand firing)
before cadence semantics, and check where each number lives in the SDE.
**Refs.** ARCHIVE SHIPPED 2026-09-08 cap injectors entry; QUEUED clip reloads.

### Production-wiring widget tests need runAsync for Drift isolates and a grown test surface

**Author.** Qwen Code
**Context.** Locking the fitting-stats chain (SdeService -> providers ->
engine -> StatsPanel) against the dead-`effects` bug class required a widget
test that uses the real Drift-backed service instead of fixtures.
**Evidence.** First attempt hung with no output: `SdeDatabase`'s
`NativeDatabase.memory()` answers from a background isolate, and port
replies never reach a future that started inside the widget-test FakeAsync
zone (provider futures kick off during `pumpWidget`). A later failure showed
the lazy `ListView` in StatsPanel stopping mid-section: Scaffold bodies give
tight window-height constraints, so an oversized `SizedBox` is ignored and
only ~600px of rows build.
**Mechanism.** FakeAsync pumps virtual time but does not turn the real event
loop, so isolate/port and sqflite work must run inside `tester.runAsync`;
and lazy slivers only build children within viewport+cacheExtent of the
real surface size.
**Fix.** Resolve the provider chain in a bare `ProviderContainer` inside one
`runAsync` block, then render StatsPanel against the resolved stats with
`tester.view.physicalSize` grown (1200x2400) so every row lays out.
**Validation.** `fitting_stats_production_wiring_test.dart`: Tristan with
loaded autocannon + Warriors + DDA II yields dps 50.4 (guns 3.4, drones 47.0)
and renders OFFENSE/DRONES rows; 430 tests green.
**What surprised.** A fit that looks fine in fixtures can be correctly
rejected by the engine: Warriors on a Rifter produce 0 drone DPS because the
Rifter's drone bandwidth is 0 — the test had to move to a Tristan.
**Generalizable rule.** Widget tests over real services: wrap isolate-backed
async in runAsync before pumpWidget, and size the surface for lazy lists.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; HANDOFF next step.

### modifierInfo's skillTypeID is a target filter, not the scaling skill

**Author.** Qwen Code
**Context.** The first drone/amp increment scaled every skill-linked modifier
by the linked skill's level, which made Rifter's racial bonus scale with
Small Projectile Turret instead of Minmatar Frigate (a character with SPT V
and MF 0 would have gotten the full bonus).
**Evidence.** Bundled data: Rifter effect 7248 carries `skillTypeID: 3302`,
and 3302 is Small Projectile Turret (skills.json), while the Rifter's own
required skill (attribute 182) is 3329 = Minmatar Frigate; the turret's
attribute 182 is 3302. pyfa's handlers confirm the split: `Effect7248`
filters `requiresSkill('Small Projectile Turret')` and scales with
`skill='Minmatar Frigate'`, while `Effect6556` (drone damage amp) and
`Effect3656`/`Effect889` filter by skill and apply the value raw.
**Mechanism.** CCP's resolved modifiers publish one skill link — the skill
targets must require (pyfa's filter). Ship-owned racial bonuses scale with
the ship's own required skill (attributes 182/183/184); module-owned bonuses
(amps, enhancers, BCS rof) apply raw.
**Fix.** DogmaEngine routes with `ownerIsShip`: ship-owned modifiers scale
with `shipSkillLevel` (from the ship's required-skill attributes),
module-owned apply raw; `skillTypeID` filters targets via their required
skills. Operator 4 joined 0 as postMul (heat sink/BCS family, pyfa
Effect91/763 multiply handlers), and BCS-style `charID` modifiers on 212
multiply loaded missile damage components like pyfa's filteredChargeMultiply.
**Validation.** `dogma_engine_test.dart` (filter vs scaling, amp raw, heat
sink op 4, BCS missile multiply) and `real_sde_weapon_test.dart` (Rifter at
Minmatar Frigate V from bundled data; Warrior II + DDA II = 47 DPS);
429 tests green.
**What surprised.** One field serving as filter while the scaling skill lives
only on the owner ship — the data alone is ambiguous without pyfa.
**Generalizable rule.** When two publishers disagree in shape, use the
reference implementation's handlers to disambiguate field semantics.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; LEARNINGS 2026-09-08
modifierInfo entry.

### The SDE publishes resolved dogma modifiers; dgmExpressions is retired and fuzzwork moved to csv/

**Author.** Qwen Code
**Context.** Unlocking DPS/volley/optimal needed ship weapon bonuses, which
were assumed to live in dogma expression trees (the plan was to bundle
`dgmExpressions` and evaluate them pyfa-style).
**Evidence.** fuzzwork `csv/dgmExpressions.csv` is header-only (1 row);
`csv/dgmEffects.csv` carries a `modifierInfo` column with CCP's resolved
modifiers, e.g. Rifter effect 5779:
`{"domain": "shipID", "func": "LocationRequiredSkillModifier", "modifiedAttributeID": 158, "modifyingAttributeID": 587, "operation": 6, "skillTypeID": 3302}`.
Separately, the old flat `*.csv.bz2` URLs 404 since the dump moved to `csv/`
plain files (verified 2026-09-08), which would have broken regeneration.
**Mechanism.** CCP replaced expression-tree publication with pre-resolved
modifier lists per effect, including skill linkage (`skillTypeID`) and group
restrictions (`groupID`); func + domain encode the routing: `ItemModifier` +
`shipID` = owner modifies the ship (hardeners, damage control), `Location*`/
`Owner*` + `shipID` = owner modifies fitted modules (racial weapon bonuses,
tracking enhancers), `charID` = owner modifies loaded charges (missile
damage bonuses), `itemID` = self only.
**Fix.** `scripts/sde/generate_dogma_sde.py` fetches the new `csv/` layout and
bundles `assets/sde/effect_modifiers.json` (2090 effects, 1984 with
modifiers); DogmaEngine routes by func/domain instead of evaluating trees.
**Validation.** `test/features/fitting/domain/real_sde_weapon_test.dart`
loads the bundled assets from disk and reproduces Rifter's traits
(-7.5%/level rof, +10%/level falloff at skill 3302) end to end.
**What surprised.** The expression-tree port was unnecessary: the retired
table's replacement is strictly better data (resolved, skill-aware).
**Generalizable rule.** Re-check the data source before porting an
evaluation engine; publishers sometimes replace trees with resolved facts.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; QUEUED drone DPS.

### Production fitting stats silently ignored every module bonus (effects never populated)

**Author.** Qwen Code
**Context.** While wiring ship bonuses I traced why the engine's module
modifier loop could never fire in the app although tests passed.
**Evidence.** `SdeService.getModuleType` built `ModuleType` without `effects`
(model default `[]`), so `fittingStatsProvider`'s `effectIds` list was always
empty and `ensureEffectModifiers([])` returned `{}`; only hand-built test
fixtures had effects.
**Mechanism.** The Drift table `SdeTypeEffects` was seeded and read for slot
detection (`getTypeEffects`), but nobody mapped those rows into the model, so
hardener/damage-control/propulsion bonuses were absent from real stats while
every unit test constructed modules with effects and stayed green.
**Fix.** `getModuleType`/`getShipType` now populate `effects` (names from the
bundled effect metadata); the stats provider also resolves charge types so
missile/turret damage has its source data.
**Validation.** `test/core/sde/sde_service_test.dart` asserts seeded effect
rows surface on `ShipType.effects` with bundled names; full suite 422 green.
**What surprised.** A test suite can be fully green while a production path
is dead, when fixtures bypass the very mapping that is missing.
**Generalizable rule.** Fixture-built tests must be paired with at least one
test that walks the real repository/service mapping.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry.

### Capacitor stability is an event simulation, not a formula (pyfa eos/capSim.py port)

**Author.** Qwen Code
**Context.** The stats panel's "Stable" row needed cap stability, which has no
closed form once module cycles repeat against the recharge curve.
**Evidence.** pyfa's `eos/capSim.py` (fetched 2026-09-07): recharge between
events is `cap = ((1 + (sqrt(cap/C) - 1) * exp(-dt/tau))^2) * C` with
`tau = rechargeTime / 5`; identical modules are staggered as one activation
every duration/count; stability is detected when the cap at a whole LCM period
is no lower than at the previous one; negative cap ends the sim as unstable
with time-to-empty.
**Mechanism.** The recharge curve is nonlinear, so average-rate maths cannot
answer "does this fit hold cap"; only stepping through activations can.
**Fix.** `lib/features/fitting/domain/cap_simulator.dart` ports that algorithm
(repeating drains only: no cap injectors, no reloads — documented in the
class); DogmaEngine feeds it per-module capacitorNeed (6) and duration (73,
milliseconds) and reports stable percent or seconds-to-empty; the panel shows
percent when stable, seconds when not, dash when unmodelled.
**Validation.** Five simulator tests (empty, light, overwhelming, stagger
equivalence, monotonic stability) plus two engine-level tests.
**Generalizable rule.** When a reference implementation exists (pyfa), port
its algorithm and pin behaviour with tests rather than re-deriving approximations.
**Refs.** QUEUED 2026-09-07 cap-stable entry (now shipped).

### Dogma operator semantics come from live ESI; some bonuses hide in expression trees

**Author.** Qwen Code
**Context.** Making module resist/EHP modification real required knowing how
each effect transforms ship attributes, which the bundled SDE does not store
(it carries effect IDs only).
**Evidence.** Live `GET /dogma/effects/{id}/` on 2026-09-07: effect 5230
(EM Shield Hardener II) uses operator 6 with modifying attributes 984-987 whose
local values are percent units (-55); effect 2302 (Damage Control) uses
operator 0 mapping module resonances onto ship resonances (0.85); effect 6731
(moduleBonusAfterburner) returns an EMPTY modifier list while the module's
speedFactor attribute is 135 on a 1MN AB II.
**Mechanism.** Operator 6 is postPercent (confirmed by the percent-unit bonus
attributes); operator 0 must be postMul, since postPercent would make a 0.85
resonance bonus a no-op and assignment would overwrite better base resonances.
Effects with empty modifier lists encode their bonus in pre/post expression
trees, which ESI does not publish (only expression IDs), so they cannot be
derived from ESI alone.
**Fix.** Engine applies cached ESI modifiers (new SdeEffectModifiers table,
SDE schema v6) with {6: postPercent + stacking penalty on resonances,
0: postMul}; the earlier guessed `speedFactor` multiplication was removed —
with the real value of 135 it would have multiplied speed by 136. Propulsion
is nonetheless modelled via a small curated map for the two expression-tree
effects (6730 MWD, 6731 AB): speedFactor is percent units and the bundled SDE
values (AB I 115, AB II 135, MWD I 500, MWD II 510) match the in-game
multipliers x2.15/x2.35/x6/x6.1. Unknown propulsion-style effects are ignored
rather than guessed. (Amended inline 2026-09-07; earlier text said velocity
stays base+skills.)
**Validation.** Engine tests pin postPercent, postMul, stacking-penalty and
domain-filtering maths; three consecutive full-suite runs green (404 tests).
**Generalizable rule.** Check a dogma attribute's units and operator against
live data before applying any "attribute times factor" maths.
**Refs.** DECISIONS 2026-09-07 "Fitting tank math is data-driven";
QUEUED P2 expression-tree entry.

### ESI cannot write the skill queue — verified against the live OpenAPI spec

**Author.** Qwen Code
**Context.** The 2026-09-07 audit listed "zero authenticated ESI writes" as the
top capability gap and proposed pushing skill plans to the game.
**Evidence.** `https://esi.evetech.net/meta/openapi.json` fetched 2026-09-07:
34 write operations in total, none under `/characters/{id}/skillqueue` or
`/characters/{id}/skills` (both GET-only), and the only skill scopes are
`esi-skills.read_skills.v1` and `esi-skills.read_skillqueue.v1`.
**Mechanism.** CCP never exposed skill-queue management over ESI, so every EVE
companion app — not just Mimir — is read-only for skills. The audit item was a
platform property misread as a product gap.
**Fix.** Shipped the writes ESI does support instead: save-fitting-to-EVE and
autopilot waypoints, both behind an explicit confirmation dialog.
**Generalizable rule.** Verify a capability against the live spec before
planning a feature around it; a missing endpoint is invisible from the client.
**Refs.** DECISIONS 2026-09-07 "Phase 6 writes"; QUEUED Maybe entry.

## 2026-09-07

### ESI removed GET /search/; POST /universe/ids/ is the supported replacement

**Author.** Qwen Code
**Context.** The Market Browser's default tab could never return a result, and
the Intel watch-list dialog had no way to resolve names at all.
**Evidence.** `curl 'https://esi.evetech.net/latest/search/?categories=inventory_type&search=tritanium'`
returns 404. `POST /universe/ids/` with `["Jita","Amarr"]` returns
`{"systems":[{"id":30000142,"name":"Jita"},...]}`; with `["Tritanium"]` it
returns `inventory_types:[{"id":34,...}]`.
**Mechanism.** The standalone public search route was withdrawn from ESI.
`/universe/ids/` is the supported public name-resolution endpoint and returns
category-keyed maps; it matches whole names, not substrings.
**Fix.** 6b2e06d (market search: SDE substring first, `/universe/ids/` to
augment), d903ff9 (watch-list name resolution).
**Validation.** Provider tests plus live curl against the running endpoint.
**What surprised.** The solar-system key is `systems`, not `solar_systems`.
**Generalizable rule.** Verify an EVE endpoint against the live service before
building on it; a 404 can sit behind a green build for months.
**Refs.** DECISIONS 2026-09-07 "Dead inferior UI..."; QUEUED P2 mapper entry.

### Golden tests race async providers; pin the providers, do not add a tolerance

**Author.** Qwen Code
**Context.** The Skills goldens failed roughly half of full-suite runs with
"Pixel test failed, 0.00%, 3px diff" yet passed every time in isolation.
**Evidence.** The isolated diff image contained a single speck at the top bar,
where the unallocated-SP value renders; `unallocatedSpProvider` logs showed it
resolving during the capture window.
**Mechanism.** FutureProviders resolve on a pump phase that shifts with the
tests that ran earlier in the same process, so the capture sometimes caught the
top bar mid-resolution.
**Fix.** ce94c20 pins unallocatedSp, totalSkillPoints and queueStats to fixed
AsyncValues for both Skills goldens.
**Validation.** Ten consecutive full-suite runs green.
**What surprised.** A `LocalFileComparator` subclass with a percentage tolerance
made *every* golden fail with "Could not be compared against non-existent
file": the wrapper's `getGoldenBytes` threw before its tolerance logic ran.
That attempt was reverted.
**Generalizable rule.** Make golden inputs deterministic at the provider level;
comparison tolerances treat the symptom and can break golden path resolution.
**Refs.** ce94c20.

### Drift watch() streams do not emit inside bare test() containers here

**Author.** Qwen Code
**Context.** Provider-level tests for saved fittings awaited
`savedFittingsProvider(null).future` and timed out at 30s, while the identical
providers behave under `testWidgets`.
**Evidence.** TimeoutException plus "StreamProvider ... disposed during loading
state, yet no value could be emitted" in
test/features/fitting/presentation/fitting_save_load_test.dart before the fix.
**Mechanism.** Not fully root-caused; the first stream emission never arrives
under the plain test zone in this project's setup.
**Fix.** 959808b asserts persistence through one-shot repository reads
(`getFittings`), and `saveCurrent` resolves the active character with
`characterRepository.getActiveCharacter()` instead of the character stream.
**Validation.** Six fast, stable provider tests.
**Generalizable rule.** In provider unit tests prefer one-shot reads; keep
stream assertions in widget tests where a binding drives the loop.
**Refs.** 959808b.

### ReorderableListView.onReorderItem pre-adjusts newIndex

**Author.** Qwen Code
**Context.** Migrating off the deprecated `onReorder` looked mechanical.
**Evidence.** Flutter SDK reorderable_list.dart: the `onReorder` path passes the
raw drop index while `onReorderItem` passes the index computed after removing
the dragged item.
**Mechanism.** Keeping the app's historical `if (newIndex > oldIndex) newIndex -= 1`
correction on top of the pre-adjusted index shifts every downward drag one slot
early, silently corrupting plan order.
**Fix.** 9d221e2 removes the manual correction with a comment saying why.
**Generalizable rule.** When a deprecation changes a callback's parameter
semantics, read the SDK call site before migrating.
**Refs.** 9d221e2.

### TestApp rendered Flutter's default light theme while the app ships dark

**Author.** Qwen Code
**Context.** Every golden and integration test rendered a theme no user sees.
**Evidence.** sub_window_app.dart hardcodes `AppTheme.darkTheme()`; the
regenerated light-theme Industry golden showed a white-on-white "No Industry
Jobs" empty state.
**Mechanism.** TestApp's MaterialApp declared no theme, so tests got Flutter's
light default.
**Fix.** 9d221e2 sets `AppTheme.darkTheme()` in TestApp and regenerates all
baselines in the shipped theme.
**Validation.** Dark baselines reviewed visually; contrast problems became
visible instead of hidden.
**Generalizable rule.** A test harness must render the shipped theme, or the
suite validates a product that does not exist.
**Refs.** 9d221e2.

## 2026-05-21

### macOS Flutter sub-windows need explicit plugin and config boundaries

**Author.** Codex
**Context.** Combat Analyzer runs as a desktop sub-window. Several failures
looked like UI or scanner bugs, but the root cause was sub-window/plugin
boundary behavior on macOS.

**Evidence.** The recovery checkpoint recorded two concrete faults:
`shared_preferences` produced a sub-window plugin-channel error, and the folder
picker did nothing until native plugin registration was added for
`desktop_multi_window` sub-windows. The scanner later moved selected directory
state into app-support `combat_analyzer.json` instead of relying on
`SharedPreferences`.

**Mechanism.** Each desktop sub-window has its own Flutter engine. Plugins that
work in the main engine are not automatically safe in sub-windows unless the
native side registers them for that engine. Config needed by sub-windows should
also live in a file/database surface the sub-window can read directly.

**Fix.** Register generated plugins for macOS sub-windows and use
app-support JSON for Combat Analyzer config.

**Validation.** Folder selection started working from the Combat Analyzer
window, and scanner state loaded from the saved config instead of getting stuck
behind "scanner not ready" behavior.

**Generalizable rule.** For multi-window Flutter desktop features, assume
plugin registration and state access are per-engine concerns. Prefer database
or app-support files for cross-window state, and verify native plugin
registration for any UI action launched from a sub-window.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`.

### EVE gamelog folders are mostly non-combat and need cached classification

**Author.** Codex
**Context.** The initial log scanner found many files but either showed
non-combat events or appeared empty depending on directory and parser readiness.

**Evidence.** The recovery checkpoint recorded
`/Users/jefcox/Documents/EVE/logs/Gamelogs` with 1,419 timestamped gamelog
files, but only 56 classified as combat logs and 1,363 classified as
non-combat. Those 56 combat logs produced 295 displayable encounters.

**Mechanism.** EVE gamelogs include timestamped files for many client events,
not just combat. Filename shape proves "EVE gamelog", not "combat log".
Scanning every historical file on startup is wasteful, and showing every
timestamped file pollutes the AAR list with skill redemption and other
non-combat events.

**Fix.** Filter by actual combat-damage content and persist a classification
cache keyed by file path, modified time, and size. Cap initial scans to newest
files and recheck changed files.

**Validation.** Combat Analyzer loaded only combat-bearing logs, and unchanged
non-combat files were skipped on refresh without rereading their contents.

**Generalizable rule.** Treat game-log filename patterns as a broad source
filter only. Use content classification plus a file fingerprint cache before
building UI or sending data to AI.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`;
`tasks/todo.md`.

### Combat logs are a primary source but not a complete AAR evidence source

**Author.** Codex
**Context.** The combat analyzer initially produced useful AAR prose from EVE
combat logs, but reports still had many unknowns even after zKill/killmail
matching. The user wanted a path to resolve those unknowns instead of having
the AI guess.

**Evidence.** AAR enrichment implementation added
`lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`,
`combat_fit_snapshot_mapper.dart`, `combat_damage_matchup.dart`, and v3 prompt
payload support in `lib/features/combat_analyzer/data/codex_analysis_client.dart`.
Focused checks passed:
`flutter test test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`
and
`dart analyze lib/features/combat_analyzer lib/features/fitting/domain/format_parser.dart test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`.

**Mechanism.** EVE combat logs prove event timing, damage lines, hits, misses,
weapons, and actors seen by the local client. They do not contain range,
transversal, tank layer depletion, pilot intent, historical pilot fit, full
opponent fit, or all ship/dogma modifiers. Killmails add destroyed-fit and
attacker/victim context, but they still do not prove the surviving pilot's fit
or the live range/application situation.

**Fix.** Added an evidence ledger and fit evidence model so AARs can separate
proven facts, user-confirmed facts, reference snapshots, derived facts, and
open unknowns. Added manual EFT/DNA fit import and current active ship snapshot
capture as explicit evidence-gathering paths.

**Validation.** Domain tests cover ledger serialization, current-ship asset
snapshot mapping, damage matchup classification, and SDE-backed EFT parsing.
Combat analyzer tests plus fitting parser tests pass.

**What surprised.** zKill/killmail enrichment reduced some unknowns but did
not eliminate the highest-value one for learning: the pilot's actual fit at
fight time.

**Generalizable rule.** Treat each EVE source as evidence with scope and
confidence. Do not let the AI collapse "unknown" into narrative certainty;
surface the missing evidence and give the user a way to resolve it.

**Refs.** [DECISIONS 2026-05-21](DECISIONS.md#combat-aar-v3-uses-evidence-ledger-and-fit-evidence-before-deeper-simulation);
[QUEUED AAR simulation work](QUEUED.md#p1--aar-fit-simulation-and-defense-profile-derivation);
[AAR plan checkpoint](../../.codex/plans/2026-05-21-combat-analyzer-aar.md).

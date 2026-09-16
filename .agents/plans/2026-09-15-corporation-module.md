# Corporation Module — Implementation Plan

## Goal

Implement the Corporation Module (QUEUED P2, Phase 4, Sprints 23–24, phases 4e–4h)
on `feature/corporation-module`: a read-only, role-aware corporation workspace in
dedicated Window 15 with four views (Overview & Roster, Assets, Structures & Fuel,
Wallets) delivering public profile + permitted roster (4e), complete corporate asset
snapshots with qualified valuation (4f), owned Upwell structures with fuel
observations/forecasts/alerts (4g), and seven-division wallets with exact decimal
journal/transactions (4h). All 40 acceptance criteria (AC1–AC40) and all 60 test
cases (D01–D20, P01–P20, U01–U12, O01–O08, aliased T01–T60) must pass with executable
evidence, following strict TDD (Test-Author RED → Dev GREEN → Reviewer → Tester)
across units C0–C10.

## Success Criteria

**Acceptance contract (product §7 — all 40 must hold with executable evidence):**
AC1 Window 15 single-instance tray launch, IDs 0–14 intact; AC2 distinct no-character/
unresolved/NPC/closed/member states, no Corporation-0 requests; AC3 full F1 role/scope
matrix incl. member roster, Accountant/Junior wallets, Station Manager structures,
Director-only assets; AC4 HQ/Base/Other + assigned/grantable separation, probe unlocks
role-list only; AC5 distinct 401/403/missing-scope/missing-role/network states, no
auto-reauth loops; AC6 scoped one-hour lease, locks at equality + on revocation, cold
restart + missed events; AC7 switch/departure/reduction/deletion invalidation, stale
workers fenced, other owners preserved; AC8 capability-specific PKCE, actual grants,
wrong-character rejection, cancel preserves session, corp-0 not departure; AC9 F2
10%/5.6% taxes, legacy 0.10→10%, no magnitude heuristic, SDE-independent overview;
AC10 roster = returned members only, count-mismatch report, current-episode/tracking
join dates; AC11 independent role/title/tracking enrichments, no member invention,
titles confer no authority; AC12 activity timestamps + UTC 7/30/90 filters, no online
claims; AC13 own division-role matrix + explicitly NPC standings; AC14 complete-page
publication, duplicate rules, distinct complete-empty; AC15 F3 locations/divisions,
no all-offices claim; AC16 orphan/cycle/deep traversal terminates, conservation
holds; AC17 qualified 725.00 valuation, no BPO/adjusted fallbacks, 24h stale prices;
AC18 search with ancestor context, usable unknown/denied names, no ID leaks or
cross-character names; AC19 Station Manager status without Director/assets, service/
state distinctions; AC20 distinct timers/config windows, Awaiting-updated-state, no
invented transitions; AC21 F4 1440 observed blocks, per-type/other-resource rows,
asset clock, Unavailable otherwise; AC22 verified group-specific models, Not modeled
unknowns, manual scenario save/cancel semantics; AC23 F4 rate/day/endurance arithmetic,
zero behaviors, static anchoring, compatible snapshots, expiry stays alert source;
AC24 exact 72h/24h/zero severities, missing = Unknown; AC25 episode rearm/ack/expiry
behavior, one native delivery per episode across processes/restarts; AC26 stale/denied/
deleted/unselected emit nothing, denial leaves in-app warnings, resume-before-overdue,
no closed-app promise; AC27 seven divisions ordered, Division-n fallback, F5
1500.00 vs 1200.00 (6/7), names independent of balances; AC28 all-page journal, 30-day
window, retained bounds/gaps, null stays null, no upstream-recovery promise; AC29
cursor progress/loops/duplicates, Buy/Sell/gross/links per F5, no double-count; AC30
exact decimal inflow/outflow/net/gross, half-open filters, coverage disclosure, no
balance reconstruction; AC31 owner/corp/division/kind scoping, failed/denied divisions
isolated, no personal-wallet collision; AC32 shared durable coordination, no duplicate
per-engine requests, no spinner leaks; AC33 F6 clock separation, no cross-capability
lease extension or unvalidated-page coverage; AC34 deadlines/limits/backoff/bounded
paging honored, no bypass or character rotation; AC35 resolved-or-unknown identities
everywhere incl. semantics/errors/alerts, SDE/name outages don't block unrelated info;
AC36 F8 320/600/900/1200px at 100%/200% without overflow/clipping/inaccessible controls;
AC37 keyboard/screen-reader/≥48px/non-color/exact feedback; AC38 migrations + cleanup
preserve unrelated data, pure domain, guarded `.when()`, no credential/payload log
dumps; AC39 measured full-size budgets met or release-blocking exception recorded;
AC40 all 60 cases pass through real boundaries with native/responsive/offline evidence,
zero management writes or unapproved scopes.

**Oracle contract (product §8.1 F1–F8, asserted at full precision before formatting):**
F1 nine-character scope/role matrix (Ada–Iona) + HQ/Base/Other sets + malformed-HQ
Director rejection + public-CEO probe rules; F2 current 10→10% / 0.10→0.1%, legacy
0.10→10%, invalid 101/NaN rejected, roster [1,2] vs count 3, record-9 September 1
join, Bea unavailable, tracking override, 7-day boundary at T0/T0+1ms, future-login
Unknown, no Online inference; F3 11 rows → 10 goods / 8 priced / 2 unpriced,
Division 2 = 165.00, Division 1 = 550.00 + unpriced BPC, unresolved = 10.00,
Division 7 unpriced, global 725.00 + 2 unpriced rows, ammo search 4 matches / 35.00,
65-edge bound, negative-quantity and missing-quote variants; F4 expiry 216000s = 60h
Low, 1440 observed blocks (1000+440, ozone separate, reserves excluded), model 18/h →
432/day → 80h / 3.33 days anchored at T0, 5m/5m+1ms compatibility rule, manual
1440@20/h → 480/day / 72h / 3.00 days, Q/R zero behaviors + validation rejects,
Calculate/Cancel/Save semantics, severity boundaries ±1ms, episode sequence 23→22→
0→48→24 = exactly two episodes, two-engine single delivery; F5 balances total 1500.00
vs 1200.00 (6/7), journal six rows 100.40/35.40/65.00 + 1 unknown with ID107 excluded,
trade gross 3.015→3.02 Buy + 20.00 Sell, cursor [900,899]→[899,898]→[] = three trades,
ID-scoping + duplicate rules; F6 lease T0+1h boundaries (−1ms allow, equality locks),
all-page 304 renewal with payload time frozen, page-1-only 304 insufficient, wallet
304 ≠ asset renewal, Date/Age header math → 12:58 deadline, 429 + Retry-After,
30/60/120/300/300 backoff, single in-flight fetch, page-set/mixed-generation failures,
100-response bound; F7 switch-during-await isolation, departure purge vs transient-0,
refresh-vs-reauthorization generations, quarantine/rebind vs scope-reduction purge,
role-loss scoping, name-only 403 isolation, division-failure isolation, closed-window
deletion; F8 width/text/state matrix incl. 80-char names and −1234567890123456.78 ISK.

**Verification bar:** all 60 cases + mandatory parameterized subcases + §6.4 suffix
variants green, full `flutter test` + `flutter analyze` + format + macOS build/smoke
green, `dart run build_runner build` schema diffs reviewed, ≥80% feature coverage with
all critical authorization/publication/accounting/alert paths (incl. failure branches)
exercised, measured perf targets on a recorded machine, API/scope re-probe recorded,
journal + QUEUED updated in the same change set.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/corporation-module.md` (Product,
0abc4f6: R1–R32, AC1–AC40, F1–F8, D/P/U/O matrices), `docs/specs/corporation-module-design.md`
(Technical design, 33c6d84: contracts §1, storage §2, ESI §3, domain/providers/UI §4,
units C0–C10 §5, traceability §6, release gates §7), live code at
`feature/corporation-module` `33c6d84` (branch + HEAD verified): AppDatabase 21 without
corporation tables, SDE 7 (no bump needed), window IDs 0–14 (Exploration is 14), no
tray item, `esi_client.dart` public lookup only + old fractional `tax_rate` parser,
grants lack corporate scopes, personal assets/wallet seams with known gaps
(unfinished container hierarchy, first-page journal, absent-balance→zero coercion).
Grep-level check: no `lib/features/corporation/` or `test/features/corporation/` exists
yet. Prior Mimir plans in `.agents/plans/` (incl. `2026-09-15-exploration-module.md`)
supply the format; QUEUED.md P2 Corporation Module item is open.

**Prior art reused (contracts preserved):** `mutateEnrichment`-style atomic patterns,
`AarFitImportParser` strictness precedent, stale-preparation + revision-fence patterns,
`fit_evidence_harness.dart` (real DBs, scripted boundaries, gated mutation, recorders)
as the harness model, `.when()` + same-context-only retained content conventions,
screen generation guards, `[FEATURE]` tagged logging, asset/wallet batching/transaction
patterns (not their lossy DTOs, first-page assumptions, global private names, or
double arithmetic).

**Shipped boundaries this plan does not move:** AAR milestones, fit-comparison visuals,
Exploration (reuse proven low-level seams only — its session-memory streams, constant
visibility provider, incomplete feed claim, and unwired revision observer are not
corporation evidence; no wholesale rewrite), existing window IDs 0–14, global SDE
skills/dogma/industry data, existing OAuth login callers, `CombatEnrichment`/AI schemas.

## Invariants & Non-Goals

**Invariants (design §7.1 + §1.2, binding on every unit):** authority conservation
(no public cache, other character, requested scope, location role, title, or retained
row manufactures a permit; every joined dependency's authority inherited; removed
dependency's contribution hidden immediately); publication fencing (one live logical-job
owner + unchanged context/incarnation/grant/invalidation per commit; delete/departure/
revocation defeat old workers incl. CPU tasks, token callbacks, missed hints);
time honesty (payload/source/validation/HTTP-deadline/permission/model-anchor clocks
independent; 200/304/cache-read/tick differ; equality locks; no hidden auto-extension);
completeness honesty (failed/malformed pages never replace accepted lists; bounded
pauses are partial; bounds ≠ coverage; empty/missing/denied/unknown distinct);
accounting conservation (each goods row valued at most once; ancestors aren't matches;
wallet folds cover all matching cached rows once; no double/REAL money math);
fuel provenance (reported expiry / observed bay / supported rate / manual scenario
independent; Q/R needs compatible dated observations; startup ≠ recurring; reagents ≠
blocks); alert ownership (fresh authorized selected context only; durable episode
identity; at-most-once native handoff; generic content; clicks reauthorize; no
closed-app promise); presentation safety (no raw numeric entity IDs anywhere visible/
semantic/copied/notified; private payload behind locks; no stale previous-owner frame;
no widget formulas; no unsafe rich-text links; `.when()` everywhere; all four views
navigable in every state); read-only external scope (ESI GETs + documented names
POSTs only; local scenario/preferences/ack change nothing in EVE; no unapproved
scopes); evidence before closeout (no intent-as-proof; all 60 cases + mapping proof +
native runs + perf evidence required).

**Non-goals (product §1.4 / design §7.4):** no role/title assignment, member removal,
recruiting, wallet transfers, market orders, refueling, structure config, ACL editing,
asset movement, office rental, corp contracts, industry jobs, alliance admin, shared
dashboards, credential pooling, cloud polling, POS simulation, sov/skyhook management,
productivity scoring, office/inventory completeness claims, guaranteed native delivery,
management writes of any kind. Any required expansion returns to Product/Lead with the
failing contract — tests are never weakened.

## Key Architectural Decisions

Ten decisions from design §1–§4 + product §1.2/§5 (alternatives rejected in Why):

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | Authority identity | Full owner key (tenant, character, incarnation UUID, corporation, grant epoch, capability, division/resource); incarnation rotates on re-add, epoch on reauth/scope change | Character+corp key / numeric generation / requested-scope-as-grant | Re-added characters must not resurrect old permits; equal-scope reauth still quarantines; requested scopes were never verified. Parsed scopes currently discarded — must persist actual grants. |
| 2 | Visibility vs eligibility split | `AccessDecision` (sealed, incl. `allowed` permit) vs `RequestEligibility` (first-fetch/renewal allowed while payload hidden); expiry equality locks; 304 renews endpoint only | Single boolean `isDirector` gate / lease renewed by any success / cache-read renewal | First fetch must not require prior success; wallet 304 must not renew assets; reads/taps/offline startup must never extend evidence. |
| 3 | Verified exceptions, not inferred roles | Grantable-role and public-CEO probes are explicit, endpoint-scoped, ≤1/hour, success-gated; general roles only from own-role General sets | Inferring Director from title names / HQ arrays / CEO match / location roles | Titles are labels; HQ Director may be malformed; CEO match is public data. Probe success authorizes that endpoint only, hides payload until verified. |
| 4 | Complete atomic publication | All pages/cursor chains validate together; rows + metadata + lease renew in one transaction; enrichments independent; failed persistence = failed refresh | Page-by-page publish / page-1-304 renews all / secondary failure clears primary | Mixed-generation pages corrupt snapshots; page 1 cannot vouch for page N; a denied division must not clear a valid one. |
| 5 | SQLite as cross-engine authority | Durable request leases (logical job key, no page/cursor), revision observer with bounded poll, alert delivery claims; process-local locks/events supplement only | In-process single-flight / ChangeNotifier / blind event-file reliance | Independent engines don't share process locks; event files expire and can be missed — only SQLite revisions arbitrate ownership and convergence. |
| 6 | Lossless exact numerics | Tokenizing JSON decoder preserving lexemes (bounded digits/exponent pre-expansion); `ExactDecimal` coefficient/scale TEXT/BigInt; int64-safe or length+lexical identity ordering | `jsonDecode` + `double.toString()` recovery / regex over JSON text / REAL columns / float gross | Precision lost at parse is unrecoverable; regex corrupts strings; `1e999999999` must reject, not OOM; money math must never drift. |
| 7 | Fuel three-source separation | Reported expiry (alert clock) / observed bay (StructureFuel-direct rows only) / supported model + manual scenario (provenance-labeled) computed independently; Q/R needs same-round fresh compatible pair (skew ≤5m) | Backsolving burn from expiry / counting reserve/ship/nested stock / joining old quantity to new consumers / scenario-driven alerts | Expiry ≠ quantity; only direct-bay rows are fuel; stale joins fabricate endurance; scenarios are assumptions, and only expiry drives episodes. |
| 8 | Model proof gate | Versioned fuel-rule artifact + generator/validator + source ledger; fitted consumers proven from complete ServiceSlot0–7 rows + reviewed wire-label→module mapping; always-Not-modeled or guessed mappings are release blockers | Assuming SDE dogma has the fields / guessing ESI label strings / universal 40-blocks-hour fallback | SDE import lacks structure/service dogma; ESI reports labels not module IDs; an unproven mapping is a blocker to escalate, not to ship silently. |
| 9 | At-most-once native handoff | Durable unique delivery claim per owner/structure/episode in the same transaction as the authority recheck; ambiguous crash claims are never replayed; generic content; clicks reauthorize | Exactly-once delivery promise / expiry-timestamp dedup / private names in notifications | No transactional ack exists between SQLite and the OS; redelivery after crash would duplicate; content must survive lock screens without leaking. |
| 10 | Real-boundary test harness | `CorporationTestHarness` owns real DBs/repos/client/coordinator/providers/host; outer-scope overrides of transport/clock/adapters only; two-connection on-disk races; recording adapters fail on unexpected calls | `AsyncData` provider overrides / mocked endpoint methods / single-DAO "multi-engine" tests / TestApp lifecycle assumptions | Overridden finals can't prove storage journeys; skipped headers/parsing/storage prove nothing; shared DAOs don't prove cross-engine correctness; TestApp owns an in-memory DB. |

**Product source corrections preserved verbatim:** structures TTL is 1h not 15m;
wallets allow Accountant/Junior/Director (not Director-only); Accountant in-game asset
visibility ≠ ESI Director requirement; roster needs no Director; titles inspected not
managed; legacy wormholes URL 404s (never implemented); no staging `examples` or
invented Pochven/private endpoints.

## Recommended Approach

**Freeze authority contracts, then build durable truth bottom-up, then compose and
render — each layer on independently verifiable seams.** C0 pins every shared type,
oracle, harness adapter, and the fuel wire-evidence gate with zero behavior so parallel
units can't drift. C1/C2 lay the two durable foundations (schema 22 + authority/grant/
request machinery) that every repository needs. C3/C4/C6 hang observations on those
foundations in parallel (roster, assets, wallets); C5 builds structures/fuel/alerts on
C2 + C4 with its model proof as an explicit gate; C7 builds the host shell in parallel.
C8/C9 compose only finished contracts into views — static components early on typed
fixtures, real journey GREEN last. C10 collects per-AC receipts, not just a passing
count. Within **each unit**: test-author writes failing real-boundary tests (RED — a
real failing assertion with independent constants, never a bare missing import or a
ready-made successful VM) → dev implements the smallest passing change (GREEN) →
reviewer verifies contracts, production wiring, and red/green evidence → tester reruns
assigned cases and captures runtime/native evidence before the next unit starts.

## File Locks

One owner per shared file for the initiative; dependents request edits through owners:

| Locked file / area | Owner | Notes |
|---|---|---|
| `lib/core/database/app_database.dart` + generated schema, `corporation_tables.dart` | **C1** | Sole migration owner; migration + generated code land atomically with C1 |
| `lib/core/auth/*` (OAuthService, AuthController, PendingAuthStore, TokenManager), `esi_client.dart` corporate additions, `character_repository.dart` publication, core revision authority | **C2** | Scoped edits only; legacy callers preserved; JWT validation is a focused grant boundary |
| Fuel-rule artifact + generator/validator/source ledger, notification adapter/native channel, `lib/app.dart` monitor composition | **C5** | C5/C7 coordinate a sequential `lib/app.dart` handoff; never overwrite each other's edits |
| `window_types.dart`, `window_service.dart`, `sub_window_app.dart`, visibility bridge, `tray_service.dart`, character selector | **C7** | Host/native owner; view bodies handed to C8/C9 after explicit handoff |
| View + domain-composition seams | **C8 / C9** | Only after reviewer-approved handoff from owning units |

## Dependency Graph

Per design §5.1 (C-prefix; T/D/P/U/O are test IDs, no collision):

```text
C0 → C1 → C2 → C3 → C8 ─┐
             ├→ C4 → C8 ┤
             ├→ C4 → C5 → C9 ─→ C10
             ├→ C6 ─────→ C9 ┤
             └→ C7 → C8/C9 ──┘
```

C3/C4/C6/C7 proceed in parallel after C2's reviewed interfaces. C5 reported-status/
scenario/reducer work may start after C2; its observed-inventory/model integration
depends on C4 and proven C0 manifest fixtures. C8/C9 may build static components
against immutable contracts early, but cannot declare GREEN integration before the real
C7 host and corresponding repositories are wired. C10 is sequential after all unit
gates. Review shared auth/database/native changes before parallel dependents consume
them.

## Work Plan

Sequence per the graph above. Commits are atomic per unit
(`type(scope): description`, no attribution lines), each recording RED/GREEN commands,
fixture/version, and reviewed production path. Generated Drift code lands with its
schema change. No unit narrows Product cases, extends leases, relaxes all-page
validation, or substitutes a blanket fuel fallback — material changes go to Product.

### [SEQ] C0 — Contracts, fixtures and harness

**Tests first (test-author, RED).** Domain value contracts (context/access/snapshot/
decimal), F1–F8 fixture builders distinguishing wire payload from simplified domain
data, harness adapters (recording ESI transport, fake clock, native/window fakes):
failing assertions on naive precision, permission defaults, unknown-field handling,
and oracle mismatches. Future service tests stay intentionally RED.

**Dev (GREEN).** `corporation_{context,access,snapshot,decimal}.dart`,
`test/fixtures/corporation/` builders + raw JSON/header transcripts,
`tests/support/{corporation_test_harness,recording_esi_transport,fake_corporation_clock}.dart`,
reference source ledger + fuel manifest schema. Deterministic harness works; fixtures
frozen.

**Gate (reviewer/tester):** reviewer checks no-fabrication rules + downstream AC
mapping; tester proves harness owns resources with real teardown semantics. No claim
that all 60 pass.

### [SEQ after C0] C1 — Database 22 (sole migration owner)

**Tests first (RED): P02/P06/P13/P19 storage portions + migration fixtures.** v21
upgrade cannot read new tables; injected migration failure / two-connection race /
delete-readd exposes atomicity defects; duplicate active grants or ms truncation.

**Dev (GREEN).** `corporation_tables.dart` (all §2.2 tables), core authority/lease
tables, `app_database.dart` 21→22 + generated code, explicit atomic bootstrap/
migration (writer serialization, version recheck under lock, version published
in-commit), central scoped delete/selection/publication transactions. No grant
implicitly authorized by migration; existing characters get fresh incarnations +
unknown grant evidence.

**Gate:** fresh 22 + supported upgrades preserve sentinels; rollback/reopen works;
unique/index constraints + ownership cleanup hold; migration owner reviews all
dependent repository SQL.

### [SEQ after C1] C2 — Repositories and role-aware ESI caching

**Tests first (RED): T01–T04, T19–T20, T21, T23–T29, T38 + P04/P05/P07/P08/P18
portions.** Wrong scope/role/version requests, 403 fallback, first-fetch deadlock,
page-1-only 304, duplicate engines, wrong-subject/cancelled auth, stale token
writes, lossy numbers, mixed-generation pages, missing X-Pages, cursor non-progress.

**Dev (GREEN).** `corporation_esi_api`, endpoint registry, authorization repository,
refresh coordinator, page assembler, raw decoder, shared scheduler, revision
observer, scoped OAuth/AuthController/PendingAuthStore/TokenManager/ EsiClient/
CharacterRepository edits (update-only CAS publication, durable fences, JWT
validation boundary, serialized per-character refresh). Profile/self-access/name/
price/public-history repository foundations. Every required endpoint gets a
registered real-path test.

**Gate:** all fences/clocks/deadlines/typed errors work through actual SQL + raw
transport; legacy callers preserved; reviewer re-checks shared auth seams before
C3/C4/C6/C7 consume them.

### [P1 after C2] C3 — Member tracking and roster

**Tests first (RED): T05–T06, T22 + D05–D06.** Old employment match, unmatched member
enrichment, future login, title-as-role, eager history fan-out, denied enrichment
clearing the roster.

**Dev (GREEN).** `corporation_roster.dart`, `corporation_roster_service.dart`,
bounded public-history loader (≤50 queued, ≤2 concurrent, daily TTL), roster
provider composition. F2 exact dates, membership conservation, independently
locked enrichments, UTC activity boundaries, own-access projection.

**Gate:** roster = returned members only; tracking precedence + latest-record rule;
reviewer checks no member invention via enrichment.

### [P1 after C2] C4 — Assets and hangars

**Tests first (RED): T07–T10, T28(name portions), T29(asset portions), T30 + D07–D10.**
Mixed pages, cycles/deep paths, double-counted ancestors, private-name leaks,
binary decimal drift, 1001-ID batching, unresolved collisions.

**Dev (GREEN).** `corporation_{asset,asset_graph,asset_valuation}.dart`,
`corporation_asset_service.dart`, scoped private-name + exact-price repositories,
worker/search projection (indexed, fenced, disposable). F3 row/count/value/search
conservation, named usable fallback, complete publication, authorized fast queries.

**Gate:** 725.00 oracle + permutations; each row valued once; tester runs worker-
revocation + name-index-invalidation races.

### [P1 after C2] C6 — Wallets and journals

**Tests first (RED): T16–T18, T35–T37 + D16–D18.** Missing balance coerced to 0,
float gross, rendered-page totals, cursor loops, cross-division overwrite, malformed
second page, conflicting duplicates, prune/gap mishandling.

**Dev (GREEN).** `corporation_{wallet,wallet_calculator,history_coverage}.dart`,
`corporation_wallet_service.dart` + balance/journal/cursor repositories/providers.
F5 exact money/null/coverage/link/order results, seven-division isolation,
paging/pruning/continuation.

**Gate:** 1500.00/1200.00 + 65.00 + 3.015→3.02 oracles; divisions isolated; reviewer
checks no balance reconstruction from history.

### [P1 after C2] C7 — Dedicated window and tray (host/native owner)

**Tests first (RED): T41, T43 + U01/U03 + lifecycle slices.** Unregistered ID,
concurrent duplicates, remove-then-hide reopen, blocked SDE host, decorative
selector, hidden-window polling, missed visibility events.

**Dev (GREEN).** WindowType 15 across every switch + serialization, WindowService/
visibility bridge/SubWindowApp/TrayService wiring (coalesced opens, hide-vs-destroy
distinction, no global SDE barrier for public content), `corporation_screen`,
`corporation_character_selector` (real providers, 48px/semantics/keyboard),
`corporation_adaptive_navigation`, icon assets.

**Gate:** actual host/tray focus/hide/reopen, prior IDs intact, durable switch/reset,
measured visibility lifecycle; native smoke with fixtures.

### [SEQ after C2+C4] C5 — Structures, fuel and alerts

**Tests first (RED): T11–T15, T31–T34 + D11–D15.** Station Manager blocked by assets,
invented service consumer, reserve fuel counted, stale Q/R reset, duplicate/
corrected-expiry alerts, denied native permission, save-on-Calculate, ClockTick
crossings, crash-handoff replay, competing subwindow monitors.

**Dev (GREEN).** `corporation_{structure,fuel,fuel_calculator,fuel_alert}.dart`,
structure/fuel-rule/scenario/alert repositories + services, versioned fuel asset +
generator/source ledger, notification adapter + native channel, main monitor in
`lib/app.dart` (sequential handoff with C7). F4 exact arithmetic/boundaries, proven
minimum model family (3 modules × 3 hulls once mappings proven), independent
provenance, scoped save/cancel, durable episodes, actual native adapter. Missing
rule/label evidence blocks model completion — escalate, don't guess.

**Gate:** model proof ledger reviewed; severity/episode oracles; one-handoff rule
with explicit crash boundary; tester runs native allow/deny/click + hidden-monitor
runs.

### [P2 after C3+C4+C7] C8 — Overview, roster and assets UI

**Tests first (RED): T42, T44–T45, T50(shared), T51–T52(shared) + U02/U04/U05.**
Wrong tax/counts, missing/locked-as-empty, ID leakage, absent refresh affordance,
narrow overflow, inaccessible controls, unguarded async branches.

**Dev (GREEN).** `overview_roster_view`, `corporation_assets_view`, profile/access/
roster/tree/search/detail widgets, shared guarded panels/amount/name/freshness
components (handed off to C9, not duplicated). Actual services/host, named states,
F8 accessibility; U10/U11/U12 shared variants.

**Gate:** F2/F3 UI oracles through real providers; reviewer checks copy/semantics/
no-formulas; tester runs responsive + semantic journeys.

### [P2 after C5+C6+C7] C9 — Structures, alerts and wallets UI

**Tests first (RED): T46–T50, T51–T52(shared) + U06–U10/U12.** Scenario overwrites
expiry, hidden alerts, wrong money/coverage, inaccessible dialogs, management
controls present, stale frames after lock.

**Dev (GREEN).** `corporation_structures_view`, `corporation_wallets_view`,
status/fuel/editor/alert/division/ledger/coverage widgets via C8 shared components +
existing service contracts. U06–U10/U12 states, full F8 matrix, exact feedback, no
management controls.

**Gate:** F4/F5 UI oracles, scenario save/cancel semantics, alert ack/opt-in flows;
tester verifies no transfers/refuel/purchases exist anywhere.

### [SEQ] C10 — Release evidence and closeout

**All roles.** Per-AC receipts AC1–AC40 (design §6.3) + journey spines S1–S10;
focused suites → full `flutter test` → `flutter analyze` → format → macOS build/
smoke; profile/release benchmarks on a recorded machine (100k rows, ≥30 runs,
p50/p95, memory, query/HTTP counts); coverage ≥80% feature / 100% critical paths
(exclusions documented); ESI scope/version re-probe (sanitized evidence only);
`docs/verification/corporation-module/` records + screenshots incl. 320px/200%;
journal/README/QUEUED update (archive SHIPPED only with implementation + tester
acceptance) in the same change set.
**Gate:** reviewer confirms AC matrix + narrow diff; tester records suites, analysis,
device evidence, limitations. No shipped claim with unresolved critical gates.

## Validation Plan

Each unit's gate is **RED before GREEN** — implementation is blocked until the unit's
test-author suite shows a failing real-boundary assertion for the named requirement
(never a bare missing import; interface-only compile failure insufficient once the
harness exists). Existing suites are regression-locked; new test files per design
§6.2. Extra tests use suffixes (e.g. P04.tokenRace); Product IDs never renumbered.

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| C0 | Contract + F1–F8 fixtures — fail: naive precision/permissions/unknowns | Types + fixtures + harness only | New `test/features/corporation/domain/` + `test/fixtures/corporation/` suites → GREEN; frozen oracles, stable seams; service tests stay RED |
| C1 | P02/P06/P13/P19 storage — fail: no tables, torn migration, resurrected rows | Schema 22 + migration + cleanup | `flutter test test/features/corporation/data/migration_and_cleanup_test.dart` → GREEN; fresh/upgrade/rollback/on-disk reopen pass |
| C2 | T01–T04, T19–T24, T26–T29, T38 — fail: wrong scope/role/version, fallback, deadlock, lossy numbers | Registry + auth + coordinator + assembler + observer | `flutter test test/features/corporation/data` → GREEN; every endpoint real-path test passes |
| C3 | T05–T06, T22 — fail: old-episode join, invented members, eager fan-out | Roster service + bounded loader | `flutter test test/features/corporation/domain/roster_derivation_test.dart test/features/corporation/domain/activity_filter_test.dart test/features/corporation/data/roster_endpoints_test.dart` → GREEN; F2 oracles pass |
| C4 | T07–T10, T30 — fail: double counts, leaks, drift, batching gaps | Graph + valuation + services | `flutter test test/features/corporation/domain/asset_graph_test.dart test/features/corporation/domain/asset_valuation_test.dart test/features/corporation/domain/asset_search_test.dart` → GREEN; 725.00 oracle + permutations pass |
| C5 | T11–T15, T31–T34 — fail: blocked manager, invented consumers, dup alerts, save-on-preview | Structure/fuel/alert services + artifact + adapter + monitor | `flutter test test/features/corporation/domain/fuel_inventory_test.dart test/features/corporation/domain/fuel_model_test.dart test/features/corporation/domain/fuel_scenario_test.dart test/features/corporation/domain/fuel_severity_test.dart test/features/corporation/domain/fuel_alert_reducer_test.dart` → GREEN; F4 oracles + mapping ledger pass |
| C6 | T16–T18, T35–T37 — fail: zero coercion, float money, page totals, loops, overwrites | Wallet service + repos | `flutter test test/features/corporation/domain/wallet_balance_test.dart test/features/corporation/domain/wallet_journal_test.dart test/features/corporation/domain/wallet_transaction_test.dart` → GREEN; F5 oracles pass |
| C7 | T41, T43 — fail: unregistered ID, dup windows, torn reopen, dead selector | Window + tray + visibility + shell | `flutter test test/features/corporation/presentation/corporation_window_test.dart` + native smoke → GREEN; old IDs intact |
| C8 | T42, T44–T45, T50–T52(shared) — fail: wrong values, leaks, overflow, unguarded branches | Overview/roster/assets views + shared widgets | `flutter test test/features/corporation/presentation/overview_roster_view_test.dart test/features/corporation/presentation/corporation_assets_view_test.dart` → GREEN; F8 journeys pass |
| C9 | T46–T50, T51–T52(shared) — fail: overwritten expiry, hidden alerts, wrong money, locked dialogs | Structures/wallets views | `flutter test test/features/corporation/presentation/corporation_structures_view_test.dart test/features/corporation/presentation/fuel_scenario_editor_test.dart test/features/corporation/presentation/fuel_alert_controls_test.dart test/features/corporation/presentation/corporation_wallets_view_test.dart` → GREEN; F8 matrix passes |
| C10 | — (receipts review + full verification) | Integration + closeout | `dart run build_runner build --delete-conflicting-outputs`; `flutter analyze` clean; full `flutter test` GREEN; benchmark + native + screenshots recorded; `git diff --stat docs/engineering-journal/` shows QUEUED→ARCHIVED SHIPPED |

**Highest-risk validation:** ownership-race fencing across engines (T60/O08 + T26/T38/
T39) — single-connection tests prove nothing; only two independent on-disk DBs with
suppressed hints, crashed leases, and switch/revoke/delete interleavings prove old
workers can never publish. Second-risk: fuel wire-label→module mapping proof (C5 gate)
— without pinned wire fixtures + reviewed ledger, the minimum model cannot ship and
must escalate as a release blocker. Third-risk: all-page publication atomicity
(T29/P09) — page-1-304 or mixed-generation acceptance silently corrupts snapshots and
only raw-transport + SQL tests catch it.

## Risks / Rollback

- **Migration atomicity under concurrency (C1).** Two engines racing first bootstrap
  could interleave DDL. *Mitigation:* writer serialization + version recheck under lock +
  version published in-commit; failure-injection + reopen tests. Rollback: restore
  pre-migration semantics (old data untouched until new version commits).
- **Cross-grant data leakage (C2).** Reused numeric generations or unscoped queries
  could expose another character's rows. *Mitigation:* incarnation UUIDs, full owner
  keys on every private row/query, delete/re-add incarnation rotation, T60
  permutations. Rollback: lock all private reads to revalidation.
- **Stale publishes after switch/revocation (C2/C7).** Late workers resurrecting old
  contexts. *Mitigation:* fenced jobs, generation-keyed publication, synchronous local
  view clearing, immediate private-family invalidation. Rollback: force loading state
  on any context transition.
- **Fuel model overreach (C5).** Guessed label mappings or universal-rate fallbacks
  fabricating consumption. *Mitigation:* evidence gate (pinned fixtures + ledger +
  3×3 matrix tests); Not modeled is always acceptable; escalate blockers. Rollback:
  ship reported-expiry + bay + manual scenario only.
- **Native delivery duplication/crash gap (C5).** Double handoffs or replayed ambiguous
  claims. *Mitigation:* durable unique claim per episode, at-most-once policy, explicit
  crash-boundary test. Rollback: disable native handoff, keep in-app episodes.
- **Layout overflow at 320px/200% (C8/C9).** *Mitigation:* usable-width LayoutBuilder
  tests + F8 matrix on constrained surfaces. Rollback: force single-column below 600px.
- **Decimal/identity precision loss (C2/C4/C6).** Double parsing or REAL columns
  corrupting money/IDs. *Mitigation:* tokenizing decoder with pre-expansion bounds,
  TEXT/BigInt storage, length+lexical ordering. Rollback: none — exactness is mandatory.
- **Estimate risk (flagged by Product §1.2 + queue).** Sprint labels predate the
  verified scope. *Mitigation:* C0 RED first makes scope visible early; Plan resurfaces
  the estimate to Lead if GREEN exceeds it rather than shrinking coverage.

## Execution Steps & Role Handoffs

1. **Kickoff (Lead).** Confirm branch `feature/corporation-module@33c6d84`; assign
   named Test-Author/Dev/Reviewer/Tester per unit + file-lock owners (C1 schema, C2
   auth/transport, C5 fuel/native, C7 host); test-author + devs agree on domain/
   fixture interfaces (value types, F1–F8 builders, provider keys, harness adapters)
   before parallel RED begins.
2. **C0 RED→review→GREEN→test.** Test-author lands contract/fixture RED; reviewer
   confirms no-fabrication rules + AC mapping; dev implements types; tester proves
   harness ownership + teardown. C0 GREEN unblocks C1 RED.
3. **C1 RED→GREEN, then C2 RED→GREEN.** Sequential foundation; reviewer re-checks
   shared auth/database seams before parallel dependents consume them; tester runs
   migration/transport/race gates. C2 GREEN unblocks C3/C4/C6/C7 RED.
4. **C3 + C4 + C6 + C7 RED in parallel (test-author tracks).** Each RED lands with
   failing real-boundary assertions + independent constants + causes; reviewer
   confirms each new requirement has its regression. C5 RED may start on C0/C2
   fixtures for reported-status/scenario/reducer slices.
5. **C3 + C4 + C6 + C7 GREEN (devs, file locks respected).** Reviewer audits
   repository/host seams; tester runs endpoint/race/native-smoke gates. C2+C4 GREEN
   unblock C5 integration GREEN (model proof reviewed first).
6. **C5 RED→GREEN.** Fuel/artifact/adapter/monitor; reviewer checks mapping ledger +
   handoff policy; tester runs native allow/deny/click + hidden-monitor + crash-gap
   tests. C3+C4+C7 GREEN unblock C8 journey GREEN; C5+C6+C7 unblock C9 (isolated
   widget RED may precede on typed fixtures).
7. **C8 + C9 RED→GREEN.** Reviewer + tester inspect renderings, actions, semantics,
   responsive matrix, privacy proofs (no raw IDs, no stale frames, no management
   controls).
8. **C10 closeout [SEQ] (all).** Per-AC receipts AC1–AC40, full suite + analyze +
   format + build + benchmarks + re-probe, journal/README/QUEUED update in the same
   change set; reviewer confirms matrix; tester records evidence, device results,
   limitations.

**Handoff protocol per unit:** test-author posts RED (IDs + failing assertions + causes +
missing seams) → reviewer approves RED scope → dev implements minimal GREEN (no covert
extra fixes; newly found defects get new RED first) → reviewer checks contract +
production wiring + red/green evidence → tester independently reruns assigned cases and
records runtime/native evidence → Lead advances the unit. Findings requiring scope
expansion return to Product/Lead with the failing contract — tests are never weakened.

## Open Questions

None after local discovery — every behavior, seam, oracle, threshold, and test ID is
closed by the product specification (§1–§8), the technical design (§1–§7), and the
`33c6d84` probed codebase. The estimate tension (sprint labels vs. contract-heavy
scope) is carried as an explicit risk with an early-visibility mitigation, not a blocker.

---
*Plan file:* `.agents/plans/2026-09-15-corporation-module.md` — canonical body is the reply above. Reviewer prompts: verify full owner-key authority on every private row/query, incarnation rotation on re-add, sealed `AccessDecision` (never a boolean Director flag), all-page publication with mixed-generation rejection, tokenizing decimal decoder with pre-expansion bounds, proven fuel wire-label mapping (no guesses), at-most-once alert handoff, generation-fenced publication, usable-width breakpoints, and zero raw EVE IDs on exercised surfaces.

# Exploration Module — Implementation Plan

## Goal

Implement the Exploration Module (QUEUED P2, Phase 4, Sprints 21–22) on
`feature/exploration-module`: a tray-launched Exploration window with four views
(Wormhole Database, Thera & Turnur, Signature Tracker, Route Planner) delivering an
offline wormhole/system-effect/stargate reference (4a), a shared durable EVE-Scout
public highway feed with nearest entrance (4b), a character-scoped scan notebook with
verified local connections (4c), and deterministic mixed gate/wormhole routing (4d).
All 40 acceptance criteria (AC1–AC40) and all 60 test cases (D01–D24, P01–P18,
U01–U18, aliased T01–T60) must pass with executable evidence, following strict TDD
(Test-Author RED → Dev GREEN → Reviewer → Tester) across units X0–X10.

## Success Criteria

**Acceptance contract (product §7 — all 40 must hold with executable evidence):**
AC1 offline completeness + atomic reference updates; AC2 deterministic search/filter;
AC3 exact units (minutes→seconds ×60, kg, regen kg/cycle); AC4 K162 unknowns + variant
groups; AC5 class/security/system identity incl. Thera/Pochven/specials; AC6 all 36
effect family/strength records with exact modifier vectors/scopes; AC7 honest statics
with independent provenance; AC8 public v2, no credentials/legacy/private/staging;
AC9 endpoint orientation both directions; AC10 mass Unknown on every public row; AC11
exact 4h/expiry time semantics; AC12 durable dual refresh, 5m/24h boundaries without
HTTP; AC13 cooldown/backoff/Retry-After/conditional discipline; AC14 atomic shared feed
across Intel/Exploration windows; AC15 far-side category filters; AC16 origin modes +
60s freshness + character isolation; AC17 preference-ranked nearest entrance; AC18
scoped validated CRUD offline; AC19 scanner syntax/diagnostics; AC20 write-free preview
+ atomic merge; AC21 limits/cancel/failure safety; AC22 observation-vs-edit + episode
identity + idempotent reapply; AC23 trash/restore semantics; AC24 confirmed scoped hard
delete; AC25 prune policies + rescan races; AC26 explicit verification lifecycle;
AC27 directed scoped multigraph integrity; AC28 eligibility + stale opt-in; AC29 hard
avoids + origin escape; AC30 exact route objective + ties; AC31 ordered steps + counts;
AC32 risk meaning without Safe/ETA claims; AC33 invalidation + latest-result-wins;
AC34 three distinct no-route states; AC35 tray/window/state retention; AC36 responsive
matrix incl. 320px/200%; AC37 keyboard/touch/focus + exact committed feedback; AC38
AsyncValue/domain/name separation, no raw IDs; AC39 tagged logging + measured p95
targets (search ≤100ms, routing ≤1s); AC40 migration/lifecycle/side-effect isolation.

**Oracle contract (product §8.1 F1–F8, asserted at full precision before formatting):**
F1 B274 (86400s, exact kg), K162 all-unknown, I078 Pochven 16200s, C729 agree/Varies,
Q001/Q002 capital threshold boundary; F2 all §4.2 vectors, resonance example
50%+50%→25%, beacon/visual mismatches (J005926 Red Giant 1, J010569 Wolf-Rayet 1),
all-25 class-13 Wolf-Rayet 6, security boundary table; F3 wire record (key
`evescout:42`, orientation both ways, 4h/4h+1ms/expiry transitions, 999 ignored);
F4 Fresh/Stale/24h boundaries, single-flight, backoff 300/600/900, 429+Retry-After,
`[]` atomic replace, 304 renew/restore rules, late-response ignore; F5 preview
(3 valid/1 duplicate/1 invalid, 2 added/0 updated/1 seen again, exact message,
idempotent reapply, conflict/scope variants); F6 prune boundary (24h exact moves,
23:59:59 stays), trash/restore/delete rules, verification lifecycle (24h expiry,
re-scan ≠ re-verify, type/endpoint edits retire); F7 exact paths (A-B-T-Z default,
Prefer-Highsec 5-gate, avoid variants, EOL/Critical reroutes, private A-J-Z,
A→A zero, disconnected/missing/one-way states, w01/w02 tie-break); F8 nearest
(B→T on risk tie-break, Avoid-Lowsec E→U rejection, Z-via-5-gates fallback,
isolated-J, per-hub already-in) + responsive matrix (320×640, 600×800, 1100×800,
1440×900 at 100%/200%).

**Verification bar:** all 60 cases + mandatory parameterized subcases green, full
`flutter test` + `flutter analyze` + format + macOS build/smoke green, extractor tests
under repo Python tooling, ≥80% coverage on changed code with critical
parser/transaction/eligibility branches fully exercised, measured perf targets on a
named host, API re-probe recorded, journal + QUEUED updated in the same change set.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/exploration-module.md` (Product,
287c8e7: R1–R32, AC1–AC40, F1–F8, D/P/U matrices), `docs/specs/exploration-module-design.md`
(Technical design, be5c0a1: invariants, seams, X0–X10 units §7, traceability §8.3–§8.4,
release gates §8.5/§9), live code at `feature/exploration-module` `be5c0a1` (branch +
HEAD verified): SDE schema 6 without universe/gates tables, AppDatabase schema 20
without exploration tables, `EveScoutClient` direct uncoordinated HTTP + strict legacy
DTO, `intel_providers.dart` independent FutureProvider, `esi_client.dart`
`getCharacterLocation` null-on-error, window IDs 0–13 (no exploration), no tray item,
`test_app.dart` memory-DB ownership. Grep-level check: no `lib/features/exploration/`
implementation exists yet. Prior Mimir plans in `.agents/plans/` supply the format.

**Prior art reused (contracts preserved):** `mutateEnrichment`-style atomic patterns,
`AarFitImportParser` strictness precedent, `CombatAnalysisService` stale-preparation
pattern, weighted-EHP domain precedent, `fit_evidence_harness.dart` (real DBs, scripted
boundaries, gated mutation, recorders) as the harness model, `.when()` + same-key
`skipLoadingOnReload` provider conventions, screen generation guards, `[FEATURE]` tagged
logging, M5 pure grouping/eligibility rules (extracted helper only).

**Shipped boundaries this plan does not move:** AAR milestones, fit-comparison visuals,
correlation confidence, score weights, report v3 / input v4 required keys, existing
window IDs 0–13, global SDE skills/dogma/industry data, ESI waypoint APIs (never called).

## Invariants & Non-Goals

**Invariants (design §1.1 + §9.1, binding on every unit):** unknown stays unknown
(null/zero/no-effect/unavailable/conflict distinct; K162 gains no invented limits);
bundled offline source for all reference/manual/gate routing (ESI names are fallback,
never the universe DB); cross-window sharing through SQLite (in-process locks
insufficient); persist observations + preferences, derive everything else (no
formula/parser/graph logic in widgets); scoped transactional revision-checked
mutations, success UI after commit, no cross character/system leakage; pure R21–R26
objectives, diagnostics never become relaxed results; ms-UTC precision, injected
clock, local deadlines without HTTP; no raw numeric EVE IDs in any user-facing text
(codes/signature IDs are not numeric IDs); only new external interactions are public
GET, explicit location GET, user-invoked clipboard read (no waypoint/bookmark/mapper
writes); `Log` with `EXPLORATION`/component tags, explicit `.when()` branches,
existing windows/data preserved. Plus §9.1 equalities: one accepted snapshot per
scope; ≤1 active signature per (character,system,code); eligible local edge ⇒ active
Wormhole owner + valid endpoints + verification <24h + no expiry/closure/retirement;
`steps.length = gateJumps + wormholeJumps = totalJumps`; published calculations match
current request/source/time fingerprint.

**Non-goals (product §1.4 / design §9.4):** no Tripwire/Pathfinder/Wanderer or corp
sharing, force-directed maps, notifications/background daemon, filament/cyno/
jump-bridge planning, automatic bookmarks/waypoints/clipboard monitoring, hacking/site
valuation, polarization/mass accounting, combat-safety prediction, environment effects
applied to fits/AAR, app-wide navigation shell, CombatEnrichment/AI schema migration,
or persisted current-route cache. Optional statics dataset may ship unavailable; all
other reference/topology/effect obligations still apply. Any required expansion returns
to Product/Lead with the failing contract — tests are never weakened.

## Key Architectural Decisions

Ten decisions from design §1–§6 + product §1.2 (alternatives rejected in Why):

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | Window shape | Tray-launched `WindowType.exploration` (stable ID 14) with four internal destinations; character rail untouched | App-wide feature shell / GoRouter migration / feature rail | Older shell prose doesn't match the runtime host; user explicitly chose tray + adaptive internal navigation. Existing IDs 0–13 preserved. |
| 2 | Three truth layers | Reference (versioned SDE slice + optional statics) / Observation (durable public feed or verified local link) / Calculation (pure result over one snapshot) kept separate | Merged "connection" record with blended freshness | Statics ≠ live edges, validation age ≠ observed mass, routes ≠ reachability claims; blending them fabricates certainty. |
| 3 | SDE slice + extractor | Schema 6→7 exploration tables, pinned CCP 3503375 extractor (`exploration.py` + manifest + assets + workflow), atomic validated import, feature-scoped readiness | Extending the published-type filter / mixing Fuzzwork-latest CSV with a different map release / whole-file overwrite | Unpublished types (group 988), beacons (920), suns (995) would be omitted; mixed releases corrupt topology; readiness must not gate notebook/cache. |
| 4 | AppDatabase 21 | New tables in `exploration_tables.dart`, ms-UTC integer times, string enums, partial unique active index, transactional migration with version recheck under writer lock | Second-precision DateTime storage / ordinal enums / non-atomic callbacks / global FK enforcement | Drift seconds-rounding loses ms precision; ordinals break on reorder; callbacks aren't atomic; global FK flip needs a full legacy audit. |
| 5 | Shared feed coordination | SQLite CAS lease row per scope (claim before HTTP, commit promptly, 60s lease, 300s min attempt), single-flight per engine as optimization only; 5s revision poll + open/resume rereads close the missed-event gap | In-process provider lock / ChangeNotifier / blind event-file reliance | Independent window engines don't share process locks; event files expire in 10s and writes can be missed — only SQLite revisions are authoritative. |
| 6 | Strict boundaries | `AarFitImportParser`-style pure normalizer (whole-snapshot validation, no partial publish); strict `getCharacterLocationStrict` beside legacy nullable caller; clipboard read only on Paste with byte/row caps enforced pre-parse | Lenient row-skipping publish / collapsing strict errors into null / whitespace-split fallback | Partial publish invents feed truth; null-collapse fabricates origins; whitespace splitting breaks site names. |
| 7 | Notebook ownership | Episode-UUID ownership, scope+revision-checked transactions, idempotent operation receipts (surviving as tombstones), prune-under-write-lock, window-visible hourly prune (no OS daemon) | Code-keyed links / unlocked read-then-write / background daemon / hard auto-delete | Reused codes across episodes would corrupt links; races need in-transaction checks; product forbids hard auto-deletion and background daemons. |
| 8 | Route engine | Tuple-cost Dijkstra `(jumps, riskSum, edgeKeys)` / `(nonHighsec, jumps, riskSum, edgeKeys)` with full sequence comparison; diagnostic BFS for reachability only; structured canonical directed keys | First-visit BFS / scalar highsec penalty / Euclidean distance / returning diagnostic paths | BFS violates risk + canonical tie-breaks; scalar penalties aren't exact lexicographic order; diagnostics must never become relaxed routes. |
| 9 | Provider composition | Real-repository providers with revision-bracketed reads, generation-keyed latest-wins, T0-frozen calculation time, `.when()` everywhere, same-scope-only `skipLoadingOnReload` | Final-result overrides in journey tests / `requireValue` / cross-scope retained rows | Overridden finals can't prove storage journeys; unguarded reads crash; previous-family rows under new headers are a privacy bug. |
| 10 | Presentation isolation | Derived ViewModels + tested formatters; views dispatch intent only; `LayoutBuilder` usable-width breakpoints (moduleWidth 600, viewWidth 1100) + 200%-text reflow; batch local names first with safe fallbacks | Widget-embedded formulas / physical-width breakpoints / per-row live name providers / raw-ID fallbacks | Formulas in widgets are untestable and drift; rails consume width before content math; N+1 live lookups break offline and leak IDs. |

**Product settled decisions preserved verbatim:** new tray window (no app shell);
Tripwire phase out; public v2 contract (legacy URL 404, never implemented); Pochven
distinct, Thera class-12; statics need a separate layer (no SDE `isStatic`); scanner
rows ≠ destinations; public/local records never merged or submitted to mappers.

## Recommended Approach

**Freeze contracts, then build durable truth bottom-up, then compose and render —
each layer on independently verifiable seams.** X0 pins every shared type, oracle,
and harness adapter with zero behavior so parallel units can't drift. X1/X2 lay the
two durable foundations (reference slice; user-data schema) while X5 proves the pure
route math against X0 fixtures and X7 builds the host shell — all four parallel after
X0. X3/X4 hang observations on the X2 schema (unit tests can use fixture reference
data while X1 completes). X6 is the single integration seam: real repositories +
visibility + origins composed into providers, which is why UI (X8/X9) waits for it.
X10 collects per-AC receipts, not just a passing count. Within **each unit**:
test-author writes failing behavioral tests (RED — a real failing assertion, never a
bare missing import) → dev implements the smallest production seam (GREEN) →
reviewer checks Product + race/rollback/privacy + regression boundaries → tester runs
the unit plus affected integration gates and records evidence before the next unit
starts. One owner per shared file (X2 owns AppDatabase migration, X1 owns SDE
schema/assets, X7 owns host/native); others request edits through owners.

## Work Plan

Units are **X0–X10** per design §7 (X-prefix avoids collision with Product T/D/P/U IDs
and prior U0–U5/W0–W7 initiatives). Sequence: X0 first; X1/X2/X5/X7 parallel after X0;
X3/X4 after X2 schema (unit tests may use fixture reference data meanwhile); X6 after
X1–X5 + X7 interfaces; X8/X9 parallel after X6; X10 sequential last. Reference/topology
ships before nearest/routes; shared feed before both live consumers; explicit
verification before private edges enable. Commits are atomic per unit
(`type(scope): description`, no attribution lines), each recording RED/GREEN commands.

### [SEQ] X0 — Contracts and fixture harness

**Tests first (test-author, RED).** Domain value types (§4.1: reference, observation,
notebook, scanner, route, clock contracts) with F1–F8 fixtures: failing assertions on
absent/incorrect codecs, fingerprint instability, knowledge-policy gaps, legacy JSON
tolerance, selection/dedup/fallback rules. Extend harness: `ExplorationTestHarness`
(owns App + SDE DBs outside widget lifetime, wraps actual SubWindowApp in ProviderScope
without a shadowing nested scope), controlled clock/HTTP/clipboard/window/worker
adapters, schema 20/6 fixture capture. RED = contract fixtures demonstrating
absent/incorrect behavior — never a fake repository returning saved success.

**Dev (GREEN).** New `lib/features/exploration/domain/` types + `fixtures/` + harness;
frozen F1–F8; immutable codecs; stable API seams. No runnable-feature claim.

**Gate (reviewer/tester):** reviewer checks no-fabrication rules + downstream AC
mapping assigned; tester proves harness owns resources outside fake-async pumping.

### [P1] X1 — Populated offline reference (after X0)

**Tests first (RED): D01–D07 + P01–P02 reference portions.** Offline full catalog
missing; published-filter type loss; placeholder names; version stamped after failed
import; vector/scope/boundary regressions (F1/F2 oracles incl. C729 agree/Varies,
capital boundary, resonance arithmetic, beacon mismatches, security table).

**Dev (GREEN).** `exploration_tables.dart`, SDE 6→7 migration, `sde_service.dart` batch/
search/read APIs, `sde_update_service.dart` validated atomic import, reference
repository, `extractors/exploration.py` + tests + `assets/sde/exploration*.json` +
pubspec + workflow verification, pure reference derivation/search/formatter. Manifest
counts/checksums generated from the full pinned archive (never invented); import CAS
(newer-compatible wins, same-build/different-checksum needs reviewed revision).

**Gate:** full manifest + exact 36-effect gates; schema-6 upgrade, failed-update
rollback, newer-version retention; no cross-slice data loss; extractor CI
(missing counts/subsets/version mismatch/unshipped assets fail).

### [P1] X2 — Durable user data foundation (after X0; sole migration owner)

**Tests first (RED): P02/P11/P12/P16 storage portions.** Version 20 lacks tables;
duplicate active codes pass; ms precision lost; delayed save orphans private data;
character deletion leaves private rows.

**Dev (GREEN).** `exploration_tables.dart` (9 tables per §2.3), `app_database.dart`
20→21 + `.g.dart`, atomic migration (transaction-wrapped callbacks, version recheck
under writer lock, version published in same transaction), partial unique active
index + query indices, revision-observer support, central `deleteCharacter` extension
(connections/signatures/receipts/scopes/preferences/observations; public/reference/
manual-origin survive).

**Gate:** fresh/upgrade/rollback/on-disk reopen; seeded-v20 upgrade (characters/AAR/
fitting/Intel retained); failure-after-first-table then reopen; active uniqueness +
explicit clears; migration owner reviews all dependent repository SQL.

### [P1] X5 — Pure graph and routes (after X0; X0 fixtures only)

**Tests first (RED): D15–D23 route portions.** First-visit BFS/endpoint-dedup/soft
penalties produce wrong F7; stale/private/expired edges survive; wrong endpoint
labels; w01/w02 order dependence; one-way gate gains a reverse edge; relaxed
diagnostic returned as route.

**Dev (GREEN).** `exploration_graph_builder.dart`, `edge_eligibility.dart`,
`exploration_route_engine.dart` (tuple Dijkstra + predecessor chains + canonical
sequence comparison), `nearest_entrance_finder.dart` (single gate-only search +
appended entry edge + complete-tuple ranking), `exploration_deadline_planner.dart`
(exact boundary instants incl. +1ms rules), typed risk/outcomes. No UI/network/DB.

**Gate:** all F7/F8 oracles, insertion permutations, directed gates, canonical ties,
exact deadlines; tester runs fitting-adjacent + M5-eligibility regressions.

### [P1] X7 — Window and lifecycle foundation (after X0; host/native owner)

**Tests first (RED): U01 foundation + P07/P09 lifecycle slices.** ID collision;
concurrent opens duplicate; hidden engine recreated; SDE failure blocks notebook;
hidden views keep polling; native bridge detached/mis-bound.

**Dev (GREEN).** `WindowType.exploration` ID 14 (title/id/size 1440×900/icon), tray
`exploration` registration + named assets, per-type open-future coalescing,
hide-vs-destroy reconciliation via platform inventory (injected adapter),
`SubWindowApp` exploration branch independent of global SDE barrier,
`window_visibility_service.dart` + `WindowVisibilityPlugin.swift` (per-engine NSWindow
binding, visible/hidden/closed/resume observations, disposal detach), character
rail/adaptive selector, `exploration_screen.dart` shell (view bodies owned by X8/X9
after explicit handoff).

**Gate:** icon tests, production-host override seam, native smoke (launch/focus/hide/
resume with fixtures, independent engines, on-disk storage); old window IDs unaffected.

### [SEQ after X2] X3 — Shared public feed (X0+X2; fixture reference data allowed meanwhile)

**Tests first (RED): D08–D11, D24, P03–P07.** F3 integer/string/orientation/Unknown
cases; dual clients both fetching; invalid/failed write partially replacing cache;
304 resetting receipt clock; backoff/Retry-After/timeout boundaries; missed-event
stale overwrite; filter-induced requests.

**Dev (GREEN).** `EveScoutClient` refactor (injected transport/clock/identity,
`FeedHttpResult`, 15s abort deadline, 8MiB ceiling, no-redirect, fixed origin/path/
headers), pure `EveScoutNormalizer` (whole-snapshot validation per §3.2),
`EveScoutFeedRepository` (SQLite CAS lease, 60s lease/300s min-attempt, 200/304/
failure transactions, backoff schedule, 24h history pruning), `exploration_revision_
observer.dart`, Intel provider migration to shared seam (no second request loop).

**Gate:** two independent DB connections; fenced stale responses; valid-empty;
all time boundaries; atomic publish; no direct fetch remains in Intel watch/refresh.

### [SEQ after X2] X4 — Notebook and verification (X0+X2; parallel with X3)

**Tests first (RED): D12–D16, P10–P14 repository portions.** F5 silent drops/clears/
partial saves; replay duplicates; F6 prune/rescan both commit orders; type edit
leaving a route edge; endpoint/orientation change keeping verification; Restore
reviving links; pruning-Off bypassing 24h rule.

**Dev (GREEN).** `scanner_import_parser.dart` (caps pre-parse, BOM/CRLF/tabs, row
numbers, no whitespace fallback), `scanner_merge_planner.dart` (coalesce/conflict/
preserve/new-episode/preview taxonomy + pinned digests), `exploration_notebook_
repository.dart` (all §2.4 APIs with typed outcomes, keep/set/clear patches,
scope+revision+owner checks, idempotent receipts as tombstones, prune-under-lock,
trash/restore/confirmed-delete, link lifecycle incl. verify-again/close), window-
visible hourly prune owner, pure lifecycle/field validation.

**Gate:** rollback/replay tests, exact F5/F6 counts, trash episodes, both commit
orders, explicit verification only, owner cleanup via central deletion.

### [SEQ after X1–X5 + X7] X6 — Providers, origins and ViewModels

**Tests first (RED): P08–P09, P15, P17 + source-revision/bracket slices.** Old
character/route result publishes last; 60s/5m/24h elapsed yet current badge persists;
manual origin overwritten; refresh clears valid cache; cross-connection skill/SDE
update missed; unguarded `.value`; widget-embedded calculations.

**Dev (GREEN).** `exploration_providers.dart` + split controllers (§5.1 table:
clock/reference/search/detail/transport/feed/refresh/visibility/demand/notebook/
import/connection/origin/route-inputs/graph/route/nearest/deadline/navigation/name-
resolver), strict `getCharacterLocationStrict` + `ExplorationOriginService` (typed
results, 60s+1ms rule, last-known persistence), local worker runner (serializable
snapshots only), pure display projections, cross-window selection observer
(`characterSelectionChanged` hint + 5s revision checks), CharacterNavRail `.when()`
fix. Real repositories feed every provider; no separate network loops.

**Gate:** revision-bracket + generation-key tests; `.when()` review; no direct UI
calculations; dependencies are real X1–X5/X7 seams.

### [P2 after X6] X8 — Reference/public presentation (X1,X3,X5,X6,X7)

**Tests first (RED): U02–U10, U18 relevant paths.** Offline detail mislabels;
wrong side copied; cooldown reported as success; 320px/200% overflow; raw-ID leaks;
stale selection after refresh; unreachable filter/actions.

**Dev (GREEN).** `ExplorationScreen` integration (after X7 handoff),
`WormholeDatabaseView`, `PublicHighwaysView`, reusable reference/endpoint/feed/
origin/nearest widgets, Intel card/kill-feed migration (compact shared-ViewModel
projection, Turnur title, no "Live"/`remainingHours` inference, nullable model
migration). Real host/storage both refresh mechanisms, keyboard/touch/semantics,
all empty/error/cache states.

**Gate:** real-host widget tests + responsive matrix + Intel revision review;
reviewer checks copy/units/semantics.

### [P2 after X6] X9 — Notebook/route presentation (X4,X5,X6,X7; parallel with X8)

**Tests first (RED): U02–U03, U09–U18 relevant paths.** Preview writes before apply;
conflicts/no-character allow saves; confirmation scope wrong; outdated route shown
current; unconfirmed destructive action; overflowed dialogs/sheets.

**Dev (GREEN).** `SignatureNotebookView`, `RoutePlannerView`, editors/import/trash/
route widgets, exact §6.6 feedback, synchronous submission reservations (input frozen,
cancel disabled during commit, failure restores), focus restoration + announcements,
route counts/provenance/exclusions rendering.

**Gate:** committed-message/count assertions, selected-scope races, confirmation
semantics, responsive dialogs; tester verifies real interactions beyond screenshots.

### [SEQ] X10 — Release evidence and closeout

**All roles.** Per-AC receipts AC1–AC40 (design §8.3) + workflow spines S1–S9;
focused suites → full `flutter test` + integration suites → `flutter analyze` →
format → macOS build/smoke; extractor tests via repo Python tooling; measured perf
(search p95 ≤100ms, routing p95 ≤1s, ≥100 runs, host/build/dataset recorded);
coverage ≥80% changed / 100% critical branches (exclusions documented); public
schema/headers re-probe (sanitized evidence only, no volatile records as assertions);
`exploration.yaml` visual checklist; journal/README/QUEUED update (archive SHIPPED
only with implementation + tester acceptance) in the same change set.
**Gate:** reviewer confirms AC matrix + narrow diff; tester records suites, analysis,
device evidence, limitations. No shipped claim with unresolved critical gates.

## Validation Plan

Each unit's gate is **RED before GREEN** — implementation is blocked until the unit's
test-author suite shows a failing behavioral assertion for the named requirement (never
a bare missing import; existing compatible behavior may start green). Existing suites
are regression-locked; new test files per design §8.2 keys (REF/PUB/SCAN/LIFE/GRAPH/
NEAR/SDE/MIG/FEED/ENGINES/ORIGIN/NOTE/STATE/PERF/WIN/LAYOUT/A11Y/REFUI/PUBUI/NOTEUI/
ROUTEUI/RECOVER).

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| X0 | Contract + F1–F8 fixtures — fail: missing contracts | Types + fixtures + harness only | New `test/features/exploration/domain/` + `fixtures/` suites → GREEN; frozen oracles, stable seams |
| X1 | D01–D07, P01–P02(ref) — fail: no offline catalog, lost types, stamped failures | SDE slice + extractor + repo | `flutter test test/core/sde/exploration_reference_import_test.dart` + `flutter test test/features/exploration/domain/exploration_reference_test.dart` → GREEN; manifest/effect gates pass |
| X2 | P02/P11/P12/P16(storage) — fail: no tables, dup codes, ms loss, orphaned rows | Schema 21 + migration + cleanup | `flutter test test/core/database/exploration_migration_test.dart` → GREEN; fresh/upgrade/rollback/on-disk reopen pass |
| X3 | D08–D11, D24, P03–P07 — fail: mis-normalized wire, double fetch, partial publish | Client + normalizer + repo + observer | `flutter test test/features/exploration/data/eve_scout_feed_repository_test.dart test/features/exploration/data/exploration_cross_engine_test.dart` → GREEN; two-connection gate passes |
| X4 | D12–D16, P10–P14(repo) — fail: silent drops, replay dupes, race losses, live dead edges | Parser + planner + repository | `flutter test test/features/exploration/data/exploration_notebook_repository_test.dart test/features/exploration/domain/scanner_import_test.dart` → GREEN; exact F5/F6 counts pass |
| X5 | D15–D23(route) — fail: wrong F7 paths, surviving ineligible edges, relaxed diagnostics | Graph + eligibility + engine + nearest + deadlines | `flutter test test/features/exploration/domain/exploration_route_engine_test.dart test/features/exploration/domain/nearest_entrance_finder_test.dart` → GREEN; every F7/F8 oracle incl. permutations |
| X6 | P08–P09, P15, P17 — fail: stale publishes, overwritten origins, cleared caches | Providers + origin + worker | `flutter test test/features/exploration/data/exploration_providers_test.dart test/features/exploration/data/exploration_origin_test.dart` → GREEN; revision/generation gates pass |
| X7 | U01 + P07/P09 lifecycle — fail: ID collision, dup windows, blocked notebook, polling leaks | Window + tray + visibility + shell | `flutter test test/core/window/exploration_window_test.dart` + native smoke → GREEN; old IDs intact |
| X8 | U02–U10, U18 paths — fail: mislabels, wrong copy, false success, overflow, ID leaks | Database + highways views + Intel | `flutter test integration_test/screens/exploration/wormhole_database_test.dart integration_test/screens/exploration/public_highways_test.dart` → GREEN; responsive + semantic journeys pass |
| X9 | U02–U03, U09–U18 paths — fail: pre-apply writes, unscoped saves, current-looking outdated routes | Notebook + planner views | `flutter test integration_test/screens/exploration/signature_notebook_test.dart integration_test/screens/exploration/route_planner_test.dart` → GREEN; committed messages/counts pass |
| X10 | — (receipts review + full verification) | Integration + closeout | Full `flutter test` GREEN; `flutter analyze` clean; format clean; macOS build/smoke; extractor tests; PERF harness recorded; API re-probe filed; `git diff --stat docs/engineering-journal/` shows QUEUED→ARCHIVED SHIPPED |

**Highest-risk validation:** cross-engine feed lease + missed-event reconciliation
(P07/X3/X7) — a passing single-connection test proves nothing; only two independently
opened DBs over one temp file with suppressed events, crashed leases, and out-of-order
responses can prove no stale overwrite or duplicate loop. Second-risk: atomic migration
with concurrent bootstrap (P02/X1/X2) — failure-after-first-table + crash/reopen must
leave zero half-created schema. Third-risk: prune/rescan commit orders (P13/X4) — only
barrier-controlled both-orders tests prove no newer observation is ever lost.

## Risks / Rollback

- **Migration atomicity under concurrency (X1/X2).** Two engines racing first bootstrap
  could interleave DDL. *Mitigation:* writer serialization + version recheck under lock +
  version published in-transaction; failure-injection + reopen tests. Rollback: restore
  from pre-migration backup semantics (old data untouched until new version commits).
- **Lease/visibility races across windows (X3/X7).** Stale overwrites, duplicate loops,
  or polling leaks. *Mitigation:* CAS claim predicate + rows-affected arbitration,
  token/epoch fencing, 5s revision poll, visibility-scoped timers with disposal asserts.
  Rollback: disable auto-revalidation, keep manual refresh + cache.
- **Stale publishes after scope/character change (X4/X6).** Wrong-character writes or
  previous-family rows under new headers. *Mitigation:* pinned-scope transactions,
  generation-keyed publication, immediate private-family invalidation, `.when()` review.
  Rollback: force loading state on any scope transition.
- **Route objective drift (X5).** BFS/scalar approximations silently violating tie-breaks.
  *Mitigation:* F7 w01/w02 insertion-permutation oracles + Prefer-Highsec exact tuples;
  reviewer rejects any non-tuple comparator. Rollback: none — engine must be exact.
- **Layout overflow at 320px/200% (X8/X9).** *Mitigation:* usable-width LayoutBuilder
  tests + F8 viewport matrix on real host constraints. Rollback: force single-column
  below 600px usable width.
- **Reference/extractor skew (X1).** Mixed releases or unpublished-type omission corrupt
  the catalog. *Mitigation:* same-archive binding, manifest count/checksum CI gates,
  unpublished-group inclusion tests. Rollback: retain prior validated slice (never
  downgrade without reviewed revision).
- **Estimate risk (flagged by Product §1.2 + queue).** Sprint/week estimates predate the
  verified scope. *Mitigation:* X0 RED first makes scope visible early; Plan resurfaces
  the estimate to Lead if GREEN exceeds it rather than shrinking coverage.

## Execution Steps & Role Handoffs

1. **Kickoff (Lead).** Confirm branch `feature/exploration-module@be5c0a1`; assign
   owners per unit (X1 SDE owner, X2 migration owner, X7 host/native owner; one owner
   per shared file); test-author + devs agree on domain/fixture interfaces (value
   types, F1–F8 symbolic→SDE mapping, provider keys, harness adapters) before
   parallel RED begins.
2. **X0 RED→review→GREEN→test.** Test-author lands contract/fixture RED; reviewer
   confirms no-fabrication rules + AC mapping; dev implements types; tester proves
   harness ownership outside widget lifetime. X0 GREEN unblocks X1/X2/X5/X7 RED.
3. **X1 + X2 + X5 + X7 RED in parallel (test-author tracks).** Each RED lands with
   failing behavioral assertions + causes; reviewer confirms each new requirement has
   its regression. X3/X4 RED may start on X0 fixtures once X2 schema shape is agreed.
4. **X1 + X2 + X5 + X7 GREEN (devs, file owners respected).** Reviewer audits
   migrations/extractors/engine/host seams; tester runs import/migration/oracle/native-
   smoke gates. X1–X5 + X7 GREEN unblock X6 RED.
5. **X3 + X4 GREEN (devs).** Reviewer audits lease/normalizer/transaction boundaries;
   tester runs two-connection gate, SQL-failure, replay/race suites.
6. **X6 RED→GREEN.** Providers/origins composed over real X1–X5/X7 seams; reviewer
   checks revision/generation guards + `.when()` coverage; tester runs provider/state
   suites. X6 GREEN unblocks X8/X9 journey GREEN (isolated widget RED may precede on
   typed fixtures).
7. **X8 + X9 RED→GREEN in parallel.** Reviewer + tester inspect renderings, actions,
   semantics, responsive matrix, immutability proofs.
8. **X10 closeout [SEQ] (all).** Per-AC receipts AC1–AC40, full suite + analyze +
   format + build + extractor + perf + re-probe, journal/README/QUEUED update in the
   same change set; reviewer confirms matrix; tester records evidence, device results,
   limitations.

**Handoff protocol per unit:** test-author posts RED (IDs + failing assertions + causes +
missing seams) → reviewer approves RED scope → dev implements minimal GREEN (no covert
extra fixes; newly found defects get new RED first) → reviewer checks contract +
race/rollback/privacy + regression risk → tester independently runs and records the gate
→ Lead advances the unit. Findings requiring scope expansion return to Product/Lead with
the failing contract — tests are never weakened.

## Open Questions

None after local discovery — every behavior, seam, oracle, threshold, and test ID is
closed by the product specification (§1–§8), the technical design (§1–§9), and the
`be5c0a1` probed codebase. The estimate tension (sprint/week labels vs. contract-heavy
scope) is carried as an explicit risk with an early-visibility mitigation, not a blocker.

---
*Plan file:* `.agents/plans/2026-09-15-exploration-module.md` — canonical body is the reply above. Reviewer prompts: verify pinned-archive extractor binding (no mixed releases), migration atomicity with version-under-lock, CAS lease arbitration (never read-then-unconditional-write), whole-snapshot validation (no partial publish), episode-UUID link ownership, tuple-cost Dijkstra (no BFS/scalar substitutes), generation-keyed publication, usable-width breakpoints, and zero raw EVE IDs on exercised surfaces.

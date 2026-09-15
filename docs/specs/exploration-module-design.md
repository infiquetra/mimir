# Exploration Module — Technical Architecture and Design

Status: Architecture complete; implementation and executable verification pending.
Date: 2026-09-15. Owner: Technical Architect (Arch).
Product baseline: [`exploration-module.md`](exploration-module.md), commit `287c8e7`.
Application baseline: `feature/exploration-module`, based on `develop` at `aec65c6`.

This document is the implementation contract for Plan, Test-Author, Dev, Reviewer
and Tester. Product remains authoritative for behavior, exact copy, fixtures and
acceptance criteria. Existing AAR and fit comparison features are shipped and are
not dependencies to reopen. File names marked **new** below are proposed files,
not claims that the feature already exists.

## 1. Architectural overview and system boundaries

### 1.1 Decisions and invariants

Exploration is a tray-launched `WindowType.exploration`, not a new application-wide
navigation shell. It has four destinations: **Wormhole Database**, **Thera &
Turnur**, **Signature Tracker**, **Route Planner**. Character selection remains
separate from module navigation. Reference and public/manual-origin features do
not require a signed-in character; private notebook writes require a locally
stored selected character, not necessarily a currently valid ESI token.

The architecture maintains three distinct layers of truth:

| Layer | Authority and storage | What it must not claim |
|---|---|---|
| Reference | Versioned CCP-derived SDE slice; separately sourced optional statics | A static assignment is not a currently open connection. |
| Observation | Durable public feed or character-owned explicitly verified local link | Fresh validation is not observed mass, closure or safe transit. |
| Calculation | Pure deterministic result over one reference/observation/time snapshot | A route is not global reachability, an autopilot order or a travel guarantee. |

Binding contracts:

1. Unknown stays unknown. Null, zero, no effect, unavailable and conflicting data
   are distinct. K162 does not acquire invented type limits.
2. All reference browsing, manual system selection and gate routing have a bundled
   offline data source. ESI name lookups are a fallback, not the universe database.
3. Independent window engines share observations and request policy through SQLite;
   an in-process Riverpod lock or ChangeNotifier is insufficient.
4. Persist observations and preferences; derive freshness, eligibility, filters,
   display models and routes. No formula/parser/graph logic in widgets.
5. Every mutation is scoped, transactional and revision-checked. Success UI follows
   commit. Private state never leaks across character or system changes.
6. Pure route objectives and hard exclusions exactly implement Product R21–R26.
   An explanatory diagnostic search never becomes a relaxed route result.
7. Millisecond UTC precision is preserved through persistence; all calculations
   receive an injected clock. Local deadlines enforce time limits without HTTP.
8. No raw numeric EVE IDs appear in text, semantic labels, errors, dropdowns or copy
   actions. Visible wormhole codes and scanner signature codes are not numeric IDs.
9. Public GET, explicit current-location GET and user-invoked clipboard read are
   the only new external interactions. No waypoint/bookmark/public/private-mapper writes.
10. All changed paths log through `Log` with `EXPLORATION`/component tags, retain
    explicit AsyncValue `.when()` branches, and preserve existing windows/data.

### 1.2 Boundaries and dependency direction

```text
CCP archive → build extractor → bundled manifest + exploration reference slice
                                         ↓
                                  SdeDatabase / SdeService
                                         ↓
EVE-Scout GET → normalizer → shared AppDatabase feed ← Intel adapter
                                  ↓                 ↗
Explicit clipboard → pure preview → notebook transactions
Explicit ESI location → typed observation → origin controller
                                  ↓
          immutable graph + time + preferences → pure route engine
                                  ↓
        Riverpod controllers / derived ViewModels → Exploration views
```

Dependencies flow presentation → providers/application services → repositories and
pure domain. Domain imports no Flutter, Riverpod, Drift, HTTP, filesystem or clock
singleton. UUIDs, clock instants and observations are supplied inputs. Database
records/transport DTOs are not widget models. Existing DogmaEngine and combat
models are not used: environment effects are reference information only in this
release, not an extension of fitting simulation.

### 1.3 Existing seams and required changes

| Existing file or seam | Grounded gap | Design change / owner |
|---|---|---|
| `lib/core/sde/sde_database.dart`, `sde_service.dart`, `sde_update_service.dart` | Schema 6; no complete universe/gates; placeholder system queries; updates currently skills-focused | Version 7 exploration slice, validated atomic import and real local lookup; X1 |
| `scripts/sde/extract_sde.py`, extractors, `.github/workflows/sde-update.yml` | Existing generation/release path does not supply a pinned complete exploration bundle | Explicit extractor/assets/manifest/release verification; X1 |
| `lib/core/database/app_database.dart` | Schema 20; no exploration storage | Version 21 tables, indices, transactions and central deletion integration; X2 |
| `lib/features/intel/data/eve_scout_client.dart` | Direct uncoordinated HTTP and strict legacy DTO | Injected transport plus shared validated repository; X3 |
| `intel_providers.dart`, `domain/thera_models.dart`, `presentation/widgets/thera_connections_card.dart` under `lib/features/intel/` | Independent FutureProvider; required fields hide unknowns and refresh invalidates/fetches | Read shared feed state and use the same refresh command; X3/X8 |
| `lib/core/network/esi_client.dart` | `getCharacterLocation` catches Dio errors and returns null | Add a strict observation method; keep legacy method compatible; X6 |
| `lib/core/window/{window_types,window_service,sub_window_app,cross_window_events}.dart` | Independent engines; SDE-gated host; transient events | Append window ID, isolate readiness, visibility and revision adapter; X7/X2 |
| `lib/core/tray/tray_service.dart` | No Exploration tray item | Register named action, reuse open/focus path; X7 |
| `integration_test/test_utils/test_app.dart` | Owns memory DB; production bootstrap supplies ProviderScope | Own test resources externally and wrap the real SubWindowApp, not replacement UI; X0/X7 |

The older GoRouter-shell description in `CLAUDE.md` is not the current runtime
host. Do not migrate navigation to satisfy that prose. Likewise raw-ID fallback
examples conflict with the explicit no-raw-ID rule and must not be copied.

## 2. Data layer design

### 2.1 SDE schema, datasets and provenance

Advance `SdeDatabase.schemaVersion` from **6 to 7**, preserving all existing tables
and imports. Define generated Drift reference tables in a new
`lib/core/sde/exploration_tables.dart`, registered in `sde_database.dart`. The SDE
and user AppDatabase remain separate databases: do not declare cross-database FKs.

| New SDE table | Key and required content |
|---|---|
| `SdeExplorationManifests` | Dataset key; dataset schema; CCP build/release; source URLs/checksums; normalized artifact checksum; row counts; coverage/validation; import UTC ms; active revision. Optional statics use their own dataset key/version. |
| `SdeWormholeTypes` | Numeric type ID PK, visible code, localized/reference name, group, raw target class/distribution, nullable normalized lifetime seconds/jump mass kg/total mass kg/regen kg per cycle, raw attribute provenance. Never code as PK. |
| `SdeWormholeClasses` | Raw class ID PK, stable descriptive category/name, known special semantics; preserve unsupported values rather than coercing them. |
| `SdeUniverseRegions` | Region ID, resolved name, nullable raw class. |
| `SdeUniverseConstellations` | Constellation ID, region ID, name, nullable raw class. |
| `SdeUniverseSystems` | System ID, constellation/region IDs, resolved name/search key, raw security, raw system class, inherited class and inheritance source, category, effect state, applied beacon/visual sun identities. |
| `SdeUniverseStargates` | Stargate ID PK, from system, destination gate/system, topology revision, known restriction metadata and reciprocal-validation result. Each row is directed. |
| `SdeWormholeEffects` | Applied beacon type PK; family/strength, source type/effects and version. Unique family+strength for the 36 baseline combinations. |
| `SdeWormholeEffectModifiers` | Beacon+effect+modifier ordinal PK; source modifying attribute/raw value, affected attribute, operation, function/domain, group/required-skill selectors, units, display meaning and source conversion rule. Do not discard scope. |
| `SdeSystemStaticAssignments` | System+assignment key+source version; code/type/variant where known, assignment meaning, confidence, provenance/coverage. An empty optional dataset means Unavailable, not no statics. |

Use indices on normalized type code, system and region search keys, constellation
and region IDs, category, jump mass and `fromSystemId` for adjacency. Escape `%`
and `_` in literal user search; use bound parameters. Rank exact → prefix →
substring in SQL with deterministic normalized name/code then numeric-key ties.
Select and paginate matching **code-group keys** using the same-variant AND
predicate, then load **all variants** for each selected code before the pure
consensus projection. Never compute shared fields from only matching or page-split
variants. Paginate systems independently; do not fetch the whole catalog for every
keystroke.

Canonical source is Product's pinned **CCP SDE 3503375** (2026-09-10), or a newer
explicitly reviewed build with updated fixtures/manifest. Inputs include types,
groups, dogma attributes/effects/typeDogma and map regions/constellations/systems,
stargates and secondary suns from that *same archive*. Bind exact JSONL names and
keys in the extractor against its manifest; do not mix a moving Fuzzwork `latest`
CSV with a different CCP map release. [CCP distribution guidance](https://developers.eveonline.com/docs/services/static-data/),
[pinned archive](https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip).

New build files: `scripts/sde/extractors/exploration.py`,
`scripts/sde/tests/test_exploration_extractor.py`,
`assets/sde/exploration.json`, `assets/sde/exploration-manifest.json`.
Register assets in `pubspec.yaml` and explicitly upload both in the SDE release
workflow. The current workflow's skills asset and comments about automatic
extractor publication are not evidence that the new artifact is shipped.

Extraction rules:

- Select all wormhole group records, including unpublished types (baseline group
  988), plus required effect beacons (group 920) and secondary suns (group 995).
  Merely extending the existing published-type filter would still omit them.
- Preserve every type ID, including 28 C729 variants. Store K162 even without a
  typeDogma record. No fixture-only miniature catalog as a production asset.
- Record source attributes 1381/1382/1383/1384/1385/1457 individually. Time 1382
  is minutes → seconds ×60; masses are kg; regeneration is kg/cycle with unknown
  cycle duration, not kg/s. Lifetime/mass/regeneration must be finite nonnegative
  quantities; validated raw identifiers retain special values including class−1.
- Effect selection uses `mapSecondarySuns.effectBeaconTypeID`, not its visual sun
  and not the system class as a strength index. Preserve both for diagnostics.
- Parse actual dogma modifier operations/scopes, including Vorton effects
  11946/11947/11948/11953. Existing `SdeEffectModifiers` does not retain all group
  and required-skill selectors, so it is not the authoritative scope store here.
- Numeric conversions are attribute/operation-specific. For example a multiplier
  1.30 can display +30%, while a resonance source value 15 already represents a
  percentage change. Never run one global `(value−1)×100` transform over dogma.
- System class precedence is system → constellation → region. Special identity
  wins over ordinary security classification; preserve future raw classes.
- Gate destination identities must resolve within this same dataset. Verify
  reciprocal references and record exceptions explicitly; never manufacture the
  reverse of a one-way gate. Missing/dangling required topology fails validation.

The full effect vectors and semantics remain canonical in
[Product §4.2](exploration-module.md#42-exact-effect-reference-contract); do not
maintain another manually edited copy here. Generated fixtures must assert all
36 family/strength sets, all scopes, class-13 systems and the J005926/J010569
beacon/visual mismatch regressions. Resonance is not a resistance percentage-point
change; the F2 50% →25% example belongs in a pure reference test.

### 2.2 Import, update and readiness transaction

`ExplorationReferenceRepository` (new data adapter) uses new batch/search/read APIs
on `SdeService`, not its current system placeholders. Add
`ensureExplorationReference()`, `searchExplorationTypes(query)`,
`searchSystems(query)`, `getSystemReferences(ids)`, `loadGateTopology()` and
`readExplorationManifest()`. `getSolarSystemName`/security helpers should delegate
to the populated universe data where compatible; do not return invented defaults.

1. Unpack/read the bundled or downloaded version into staging; validate source and
   artifact checksums, row counts, schema, uniqueness, references, 36 effect sets,
   units, required names and topology coverage before exposing it.
2. In one SDE transaction replace only the exploration slice and publish its active
   manifest/revision. Metadata/version is inside the transaction, never stamped
   after a swallowed import error. Existing skills/dogma/industry data survives.
   Recheck expected active revision and reviewed build ordering after acquiring
   the writer lock. An older bundle cannot downgrade a newer compatible installed
   slice; same-build/different-checksum content requires explicit reviewed manifest
   revision, not silent replacement. A late older download loses this CAS.
3. Publish a revision notification only after commit. Old graph snapshots finish
   as outdated; new readers see a consistent new slice. Rollback retains old data.
4. Fresh offline install loads the bundled validated slice without HTTP. Readiness
   is feature-scoped: an exploration import failure does not block notebook or
   cached public rendering, and an unrelated skills import failure must not gate
   Exploration. An unusable reference exposes repair/update, not an empty graph.

Schema migration creates empty tables; dataset publication is a separate validated
transaction. Separate physical DBs cannot be atomically migrated together. Each
database has its own version gate; partial readiness yields explicit unavailable
capabilities and a safe retry. Coordinate concurrent first-window imports through
SQLite writer serialization and recheck the active manifest within the transaction.
Never drop the working slice before validation or overwrite the entire SDE file
under another engine's open connection.

Manifest counts/checksums must be generated from the full pinned archive in X1;
this architecture does not invent production row counts. CI fails for missing
counts, subset imports, mismatched versions or unshipped assets. Supplementary
system statics are optional: initial release can ship no assignments and show
**Static information unavailable**. Any adopted snapshot needs separately reviewed
license/attribution/version/coverage; typical class guidance is a different entity
and can never be promoted into a system assignment or graph edge.

### 2.3 AppDatabase schema 21

Add tables in new `lib/features/exploration/data/exploration_tables.dart`, register
them in `lib/core/database/app_database.dart`, regenerate `.g.dart`, and advance
**20 →21**. X2 is the sole schema owner. If another approved migration lands first,
rebase and allocate the next free version; do not reuse another migration number.

All timestamp columns below are `INTEGER` UTC **milliseconds**, with a feature-local
converter to `DateTime.utc`. Existing Drift default DateTime storage rounds to
seconds; do not change its global mode or migrate unrelated data. Suffix SQL
columns `_at_ms`/`_until_ms` explicitly. Ages/durations use integer milliseconds.
Enum storage uses stable strings, not Dart ordinal positions; unknown future
values fail closed for routing and remain diagnostically readable.

| New table | Columns and constraints |
|---|---|
| `EveScoutFeedStates` | `scopeKey` PK (`evescout:v2:all`); valid-cache flag; snapshot revision, validation revision, metadata revision; payload received/last validated/last attempt times; ETag, Last-Modified, cache expiry, next attempt; sanitized last error; failure count; body digest; request epoch/token/owner/lease-until. No character ownership. |
| `EveScoutSignatures` | Composite scope+provider-record-key PK; normalized hub/far IDs and source names/region hints; nullable endpoint signatures/type/orientation/size; completion/type; source created/updated/completed/expiry; raw category hints and diagnostics; listed snapshot revision, last payload seen, unavailable/retirement time. Persist independent observations, not countdown or optimistic mass. |
| `TrackedSignatures` | UUID PK (also episode identity); character/system/code; scan group; type/raw label; nullable name/bookmark/notes; first seen/last seen/edited; active/trash, retired time/reason; row revision. Partial unique active key `(characterId,systemId,code)`. |
| `TrackedConnections` | UUID PK; unique owner-signature episode; character; resolved from/to IDs; nullable endpoint signatures/observed codes/originating type ID/code/side; mass and time values with independent observation time/source; estimated expiry; verified time; active/closed/retired; retirement reason; row revision. |
| `ExplorationNotebookScopes` | Character+system PK; scope revision. Increment for any scoped write, including prune/restore/link change; compare during import. |
| `ExplorationImportOperations` | Operation UUID PK; character/system; input digest; committed time; selected normalized-row digest; committed outcome counts. Durable idempotency receipt, no raw clipboard text. |
| `ExplorationNotebookPreferences` | Character PK; prune hours nullable (Off), default 24; revision. Valid values24/48/72/null. |
| `ExplorationWindowPreferences` | Singleton window key; last selected destination, explicit manual origin/destination system IDs and view filters/selected stable keys; schema version. No previous-character notebook rows or Current mode restored as fresh. |
| `ExplorationLocationObservations` | Character PK; resolved system ID; observed/received times and optional source freshness metadata. Last-known local value only; never token or implicit current authorization. |

Use regular columns for queryable identities/times/revisions/statuses. Versioned
JSON is acceptable only for bounded diagnostics/filter preferences/source modifier
provenance, with tolerant optional-field decoding. Do not store this feature in
`CombatEnrichment` JSON. Neither combat evidence completeness nor AI prompt schema
changes. Route results/adjacency indices are **memory-only**, not a new route-cache
table; restart recomputes from durable sources.

Create `tracked_signatures_active_scope_code` as a partial UNIQUE index with
`WHERE lifecycle = 'active'` on both fresh create and upgrade. Other indices:
signature `(character,system,lifecycle,lastSeenAt)`; connection `(character,lifecycle,
verifiedAt)`; feed `(scope,listedRevision)` and history retirement/expiry. Declare
local foreign keys where useful, but enforce owned cleanup transactionally:
current connections do not enable foreign keys consistently, so cascade syntax
alone does not satisfy AC40. Do not enable global FK enforcement as an incidental
change without auditing every legacy table.

Migration uses `onCreate: createAll + feature indices` and cumulative
`if (from < 21)` creation. The current callbacks are **not** an atomic migration
strategy: explicitly wrap fresh-create/upgrade callback work in a database
transaction while preserving existing custom AAR/default-settings steps. Acquire
SQLite writer serialization before the version decision and reread `PRAGMA
user_version` after the lock, since another engine may already have migrated.
Publish the target user_version in the same transaction as DDL/indices; Drift's
later assignment of that same version must be harmless. A small migration/bootstrap
adapter may supply the supported immediate-write transaction when the ordinary
Drift transaction API is deferred. Never execute nested BEGIN statements. Apply
the same atomic bootstrap pattern to SDE6→7. Busy retries recheck version and
schema; a crash must not leave half-created tables requiring manual deletion.
Test failure after the first table/index and before version publication, then
reopen. Preserve historical migration operations, not their lack of atomicity.
No new default public snapshot: missing cache differs from validated `[]`. Validate upgrade from
a seeded version 20 file with character, AAR, fitting and Intel data, and fresh
version 21 install. Test failure rollback, reopen, generated schema and all indices.

### 2.4 Repository transactions and notebook ownership

New `ExplorationNotebookRepository` exposes scoped APIs:

```dart
watchNotebook(NotebookScope scope);
buildPreview(ParsedScan scan, NotebookScope scope, DateTime observedAt);
applyPreview(ResolvedImportPreview preview, ScopeGuard currentScope);
saveSignature(SignaturePatch patch, ExpectedRevision expected);
markSeen(SignatureId id, DateTime observedAt, ExpectedRevision expected);
trash(Set<SignatureId> ids, NotebookScope scope, ExpectedRevisions expected);
restore(SignatureId id, NotebookScope scope, ExpectedRevision expected);
deletePermanently(ConfirmedDeletion selection);
prune(NotebookScope scope, DateTime now, PrunePolicy policy);
confirmConnection(ConnectionDraft draft, ExpectedRevision expected);
markClosed(ConnectionId id, ExpectedRevision expected);
```

These are contract signatures, not a demand for named wrappers where existing
types suffice. Return typed committed/no-change/conflict/validation/failure results,
never a boolean that loses the reason. All nullable patches distinguish **keep**,
**set** and **clear** (`Value.absent()` versus `Value(null)` at Drift boundary).
Metadata updates never refresh `lastSeenAt` or connection `verifiedAt`.

Every write checks the character still exists, target scope and row revision in
the same transaction. Increment row and scope revisions atomically. Link ownership
is the episode UUID, not its reusable scanner code. `fromSystemId` must equal the
owner signature system; owner must be active and Wormhole; endpoints resolve and
are distinct. Only `confirmConnection`/`verifyAgain` stamps verifiedAt. Type changes
from Wormhole, trash/prune or link endpoint/originating-side identity changes retire
eligibility in that same transaction. Changing back, Restore or rescan never revives
it. Unchanged re-verification is explicit; status/expiry changes require an explicit
observation and new confirmation, not a silent metadata edit.

An import transaction first checks its operation receipt. A previously committed
identical operation returns `alreadyApplied` without another write or success
notification; operation-ID reuse with a different digest is invalid. Then validate
pinned scope token, scope/row revisions, selected resolved conflicts and unique
active IDs. Rebuild conflicts on mismatch; never apply a partial subset implicitly.
Apply selected rows plus any owned-edge retirements and receipt in one transaction.
`lastSeenAt = max(existing, preview.observedAt)` for an existing episode; preserve
firstSeenAt. Client scope generation is checked before starting the transaction;
once begun, all SQL uses only the pinned scope. If a context change wins first,
cancel without writes; if commit wins first, retain the correct old-scope write
but do not publish its success/data into the new scope. Never retarget a pending
operation to the newly selected character.

Prune reevaluates age and policy under the same write transaction as retirement:
age ≥24/48/72 hours, never editedAt. Rescan-first preserves the newer observation;
prune-first increments scope revision so the old preview conflicts. A rebuilt
explicit import creates a new episode. Repeat prune returns zero. Run on notebook
load, window resume and hourly while the Exploration **window** is visible/active,
even on another module destination. The window-scoped owner prunes the selected
character's notebooks across systems, updates every affected scope revision, and
stops when hidden/disposed. Off disables retirement only, not the independent
24-hour link verification rule.

Trash/Undo/Restore preserve observation age and history; active-code conflicts
prevent restore. Restore leaves owned links retired (Closed remains closed) until
explicit valid verification. Permanent delete consumes a confirmation containing
the selected IDs, pinned scope and revisions; reject changed selection/scope and
delete only these episodes/owned links. Retain import-operation receipts as command
tombstones, so replay after deletion/reopen cannot recreate the deleted observations.
Only central character deletion removes that owner's receipts in this release.
Automatic hard deletion is prohibited for notebook rows.

Extend `AppDatabase.deleteCharacter`'s central transaction to remove that owner's
connections, signatures, import receipts, notebook scopes/preferences and location
observations. This works with Exploration closed and through the current logout/
character deletion lifecycle. Public/reference/window manual-origin state and
other characters survive; increment/publish deletion context only after commit.

## 3. Network and external API layer

### 3.1 Verified contract and client

Rechecked on 2026-09-15: production GET returned HTTP 200, JSON array,
`Cache-Control: public, max-age=300` and a weak ETag. The documentation identifies
OpenAPI version 2.1.55. ETag availability is observed, not guaranteed; 304 behavior
must be covered by transport fixtures rather than a volatile live-row assertion.
[Production endpoint](https://api.eve-scout.com/v2/public/signatures),
[OpenAPI](https://api.eve-scout.com/ui/openapi.yaml),
[public operation](https://api.eve-scout.com/ui/paths/public/signatures.yaml),
[wire schema](https://api.eve-scout.com/ui/schemas/signature_representation.yaml).

Refactor existing `EveScoutClient` in place to inject a public HTTP transport,
clock and application identity. It returns `FeedHttpResult.modified(bytes, headers)`
or `.notModified(headers)`; it does not write DB, sort UI cards or infer mass.
New pure `EveScoutNormalizer` lives in Exploration domain. New
`EveScoutFeedRepository` owns durable cache and request coordination; Intel imports
that shared seam. Remove production consumers of direct `getTheraConnections()`;
retain a deprecated adapter only if an external call site actually needs it, and
that adapter must read the shared repository, not issue a second request.

Request: fixed HTTPS origin/path `/v2/public/signatures`, no query for ordinary
all-hubs use, `Accept: application/json`, identifying
`User-Agent: Mimir/<app-version> (+https://github.com/infiquetra/mimir)`.
No ESI interceptor, credentials, cookies, signature text, location or character ID.
Use `If-None-Match` and/or `If-Modified-Since` only from the accepted cache metadata.
Disable automatic redirects to an arbitrary host; an unexpected redirect is an
actionable protocol failure. No legacy URL fallback, `examples`, `systemType`,
private endpoint, remote routes call or runtime wormholetypes dependency.

Use an abortable transport with a **15-second overall deadline**, including body
receipt, not just a connect timeout or a Future timeout that leaves I/O running.
Close/cancel request resources on timeout/disposal; an injectable transport allows
controlled completion tests. Keep a defensive configurable response-byte ceiling
(initially8MiB); exceedance rejects the *whole* response with a validation error,
never silently truncates. No response body or community contributor identity is
logged or retained unnecessarily.

### 3.2 Wire normalization and authoritative unknowns

Normalization happens before publication and returns records plus structured
diagnostics or a snapshot-fatal error. Unknown fields are ignored; known fields
are type-validated. Retain optional source values needed for qualification.

| Input | Normalized contract |
|---|---|
| `id` | Positive integral JSON integer or decimal-digit string → canonical decimal string with leading zeros normalized; provider key `evescout:<id>`. Do not route through double. Reject unsafe/nonintegral numeric representations. |
| `out_system_id` | Recognized hub: Thera31000005 or Turnur30002086. IDs remain internal. |
| `in_system_id` | Positive, distinct far-system identity for completed wormhole rows; resolve by local catalog. Missing/corrupt core identity rejects snapshot; a valid future ID with no catalog row stays unresolved/view-only. |
| Source names/region/class | Fallback display hints, not graph identity. Catalog names/category win; disagreement is a diagnostic and risk cannot be lowered by a conflicting hint. |
| Endpoint signatures | Independently nullable; uppercase/validate when usable. Missing/unusable optional signature becomes not reported with diagnostic, never copy from the other side. |
| `wh_type`, `wh_exits_outward` | Nullable originating code and tri-state side. True: hub named type/far K162; false: hub K162/far named type; absent: side unknown. Not a travel direction restriction. |
| `completed`, `signature_type` | Only known completed wormholes become candidates. Valid incomplete/non-wormhole rows may be retained diagnostically, not shown as active connections. Missing/unknown qualification cannot make an edge. |
| `expires_at` | Nullable valid UTC instant. Invalid/missing → Unknown time with diagnostic, not closure and not zero-duration. |
| `remaining_hours` | Source convenience only; never a countdown input. |
| Created/updated/completed time | Nullable source times; report-ordering updated→completed→created; receipt and validation clocks stay separate. |
| `max_ship_size` | Reported categorical limit; unknown future values → Unknown plus raw label. No numeric or actual-ship eligibility inference. |
| No observed mass field | `MassState.unknown` with `notReported` provenance in every public record. |

Normalize exact duplicate keys only if all retained semantic fields agree after
normalization. Conflicting duplicates, malformed core wormhole rows, non-array
JSON, HTML or invalid top-level elements fail the entire refresh. Do not publish
only successfully parsed rows. Valid `[]` is success with an empty live snapshot.
It retires former public rows but never changes local notebook rows.

For native Dart JSON integers preserve exact supported range; for any future web
transport require lossless integer-token decoding or reject unsafe values before
rounding. SDE system IDs remain bounded validated integers. Provider record keys
are opaque strings throughout storage/graph canonical keys.

### 3.3 Shared request lease, cache and backoff

Use one SQLite coordinator row per all-hubs feed scope. Per-engine single-flight
futures are an optimization only. The cross-engine invariant is a conditional
write/CAS on `EveScoutFeedStates`, performed before HTTP and committed promptly.
Never hold a database write transaction open across a network request.

```text
gesture / visible-view timer / resume
 → read accepted cache immediately
 → atomic claim if now >= nextAttempt and no live lease
 → store attempt time, request token+epoch, leaseUntil; commit
 → HTTP → normalize/validate
 → transaction: verify token+epoch + accepted revision
 → replace/validate cache + advance revisions + clear lease; commit
 → notify windows and return typed outcome
```

Lease duration is 60s, request deadline15s. Claim also reserves a minimum next
attempt at `attemptStartedAt +300s`, so a crash cannot create an immediate retry
storm when its lease expires. The claim's SQL predicate and rows-affected result
are the arbiter; a read-then-unconditional-write is a race. On SQLite busy, reread
the winning state; bounded local retry must not become another network attempt.
A completion with expired/superseded token or an incompatible accepted revision
cannot publish even if transport cancellation failed. It never clears a newer
owner's lease. On resume, recheck lease/cooldown and DB revisions, not process-local
elapsed timers. Manual refresh observes the same policy.

Next network time is the maximum of:

- last attempt +300s;
- server freshness deadline if longer (Cache-Control max-age, otherwise valid
  Expires, accounting for Date/Age; conservatively clamp malformed/past values);
- Retry-After as seconds or HTTP date;
- failure backoff:300,600,900s for consecutive timeout/5xx, capped at 900s.

Failures count consecutively for backoff and reset on validated success. 429 uses
Retry-After plus the minimum cooldown; absent/invalid Retry-After uses300s. Other
4xx/schema errors use normal cooldown and retain an actionable error. No retries
inside the transport. Network success with failed normalization/persistence is
not a validated success. Persist last attempt/error separately; if storage cannot
record the claim, **do not make the request**. If storage fails after transport,
retain old cache and the already persisted claim/cooldown; do not show success.

200 transaction: replace listed membership atomically, upsert accepted records,
mark omitted rows unavailable, update payload receipt and successful validation,
validators/digest, increment snapshot+validation revisions. Even unchanged payload
can renew validation but never observation report times. 304 requires a previously
valid snapshot (including an accepted empty one): advance validation revision/time
and header metadata, preserving payloadReceivedAt, membership and report times.
304 without cache is a protocol failure. Failure updates metadata/error only;
no accepted clock or listed membership advances. Do not reuse stale validators
from a rejected response.

Return `updated`, `validatedNotModified`, `usingCacheUntil`, `joinedRequest`, or
`failedWith/WithoutCache`. Only committed200/304 earns **Connections updated.**
Cooldown reports **Using cached observations. Next network refresh: [time].**
Joiners reread the committed coordinator state and report its outcome, not a second
request; disposal removes local waiting without invalidating another engine's work.

### 3.4 Freshness, history and cross-window observation

Fresh is validation age <5m; at 5m Stale. Stale public edges require explicit
`useStaleCachedConnections` and validation age <24h. At24h public records are
view-only. Neither option nor304 revives omitted/closed/past-expiry rows. Positive
remaining time <4h is EOL estimate; exactly 4h is Stable estimate; at expiry Past
reported expiry. Mass remains independent Unknown. All are derived using `now`.

History keeps unavailable/past-estimate public records for 24h after the later of
their last payload observation and retirement/expiry transition. A304 does not
extend that history clock. Cache-only history pruning is scoped to inactive public
rows, cannot remove active local data and never makes a history row eligible.
A later accepted200 observation of the same provider key can relist it; merely
turning on stale routing cannot. Record the revised source history/provenance.

Add post-commit events `explorationFeedChanged`, `explorationNotebookChanged` and
`explorationReferenceChanged` to `CrossWindowEventType`; payloads carry scope and
revision only, not signature notes or raw feed. Event-file signaling is a hint:
current files expire in10s and writes may be missed. Repository subscriptions merge
local Drift watches, event-triggered rereads, unconditional open/resume rereads
and a **5s revision-only DB poll while a consuming view is visible**. Poll reads
only revision rows, never HTTP; coalesce reloads. Polling closes the missed-event
gap even without another resume. Do not assume independent Drift connections
notify each other's streams automatically.

Visible live consumers check network eligibility on open/resume and every 5m;
hidden/disposed consumers stop their automatic timers. No central background
network daemon. If Intel and Exploration are both visible, the lease arbitrates.
Reference/notebook-only viewing does not instantiate a network loop. Local expiry
and route deadlines continue independently for any displayed result, and overdue
deadlines are reconciled immediately on resume.

### 3.5 Character location is a separate authenticated boundary

Add `EsiClient.getCharacterLocationStrict(characterId)` using the existing
authenticated GET, scope/token/error handling and error-limit machinery. Preserve
status/error detail; do not change legacy nullable callers. The new
`ExplorationOriginService` maps success, authentication/scope, network, malformed,
no-location and cancellation into typed results, keyed by selected character and
request generation. Require `esi-location.read_location.v1`; never obtain extra
write scopes. [ESI location endpoint](https://esi.evetech.net/ui/#/Location/get_characters_character_id_location).

An observation records fetch receipt separately from freshness. Use a valid ESI
response Date/Age-derived observation bound where supplied, so an old cached
response is not magically current; otherwise label the fetch time as the available
observation time/limitation. Persist only system+times for Last known, not station,
ship, access token or credentials. Current is age **≤60s**, becoming outdated at
60s+1ms. Explicit Last known remains labeled with its age; it is not silently
selected after failure. A manual origin survives location refresh and character
switch. No location polling timer: the local timer only invalidates freshness.

## 4. Domain logic and routing algorithms

### 4.1 Immutable models

Use Freezed/immutable value models with defensive immutable collections. Persisted
models have explicit stable JSON/SQL codecs; graph and preview models need not be
serialized merely because Freezed is used. Keep nullable knowledge separate from
enums and avoid optimistic constructor defaults.

| New domain file under `lib/features/exploration/domain/` | Main types and contract |
|---|---|
| `exploration_reference.dart` | `ReferenceManifest`, `WormholeTypeReference`, `WormholeCodeGroup`, `SystemReference`, `SystemEffect`, `EffectModifier`, `StaticAssignment`, `UniverseTopology`. Raw/source values and coverage are retained. |
| `exploration_observation.dart` | `PublicConnection`, `LocalConnection`, `EndpointObservation`, `ObservedValue<T>`, `MassState`, `TimeState`, `ConnectionLifecycle`, `FreshnessAssessment`, `FeedSnapshot`. Each status has provenance/time, not one combined health flag. |
| `exploration_notebook.dart` | `NotebookScope`, `TrackedSignature`, `SignaturePatch`, `PrunePolicy`, `ConnectionDraft`, expected revisions and typed transaction outcomes. Episode ID is a UUID, not reused code. |
| `scanner_import.dart` | `ParsedScan`, `ScanRow`, `RowDiagnostic`, `ImportPreview`, `ImportConflict`, `ResolvedImportPreview`, committed counts and operation ID. |
| `exploration_route.dart` | `RoutePreferences`, `OriginSelection`, `GraphSnapshot`, `DirectedExplorationEdge`, `EdgeAssessment`, `RouteRequest`, `RouteStep`, `RouteResult`, `RouteOutcome`, `NearestEntranceOutcome`. |
| `exploration_clock.dart` | Injectable UTC clock contract and pure boundary calculations; no direct `DateTime.now()` inside domain functions. |

`OriginSelection` is a sealed Manual / CurrentCharacter / LastKnownCharacter /
Unselected value. Character-derived modes carry owner and observation time;
manual has no implied owner or freshness. `RoutePreferences` defaults exactly to
Product R23: avoidEol=true, avoidCriticalMass=true, avoidLowsec=false,
avoidNullsec=false, preferHighsec=false, useStaleCachedConnections=false.

`GraphSnapshot` contains immutable nodes/adjacency, reference manifest+coverage,
accepted public snapshot and validation revisions, selected character/private
revisions, captured UTC now and excluded-edge assessments. A route result retains
its fingerprint, ordered steps, tuple cost, gate/wormhole counts, max risk,
limitations and calculatedAt. Outdated is a controller qualification, not a silent
mutation of previously calculated step data.

### 4.2 Reference projection and filtering

`ReferenceDeriver` and query value objects implement Product F1/F2:

- Code groups retain all variants; a shared field is displayed only if every
  variant agrees, including null versus known. Otherwise show Varies and details.
- Destination and minimum jump-mass AND predicates must match the **same variant**,
  not destination in one variant and mass in another. K162/unknown mass fails any
  numeric mass predicate. Apply ranking before pagination so exact hits are not lost.
- Capital-size mass limit is nominal jump mass ≥1,000,000,000kg; disclose that it
  does not prove current mass, actual ship eligibility or safe passage.
- Ordinary known-space classification uses raw security: highsec≥0.45,
  lowsec0<x<0.45, nullsec≤0, missing Unknown. Apply special category/class first.
  Display one decimal, positive<0.05 as 0.1 and normalize negative zero. Never
  derive category from the display string or turn Pochven/Thera into nullsec.
- C1–C6, Thera12, shattered13, Drifter14–18 and Pochven25 retain distinct identity.
  C729 raw−1/distribution remains special, not a generic null sentinel or an old
  hardcoded destination assumption. Unsupported future class stays explicit.
- Verified complete effect coverage with no applied beacon means No system effect;
  missing/corrupt/unrecognized data means Effect unknown. Effect display signs
  have semantic meaning, not generic green-positive/red-negative styling.

`PublicConnectionFilter` combines one hub, one far-side category and a
case-insensitive named region substring using AND. All includes Unknown. Sort
by effective report time descending (missing last), then normalized far name,
hub name and provider record key; never by a mutable row index. Sorting and
filtering do not fetch. Names unavailable locally may use sanitized source names;
unknown regions do not accidentally match a numeric query fallback.

### 4.3 Clipboard parser and merge planner

`ScannerImportParser.parse(text)` is pure; the clipboard is an injected service
invoked only by Paste. Count UTF-8 bytes before parsing: max 512KiB inclusive and
max 5,000 nonblank rows inclusive; a header counts toward the input row limit.
Oversize is a whole-input error, not a truncation. Preserve original physical row
numbers, strip one leading BOM, normalize CRLF/LF, ignore blank lines and optional
English `ID\tGroup` header. Split on tabs preserving empty cells;2–6 cells only.
No whitespace fallback.

Trim/uppercase codes and require `^[A-Z]{3}-[0-9]{3}$`. Accept case-insensitive
Cosmic Signature/Cosmic Anomaly groups. Map supported English types to
Unknown/Wormhole/Data/Relic/Gas/Combat/Ore; unfamiliar type under a supported group
is Unknown with retained raw label/warning, while unsupported localized group is
an error. Signal/distance fields are informational and never a source of link,
mass, coordinates or disappearance. Validate text lengths by Unicode scalar
characters: name256/bookmark512/notes4096 inclusive, surrounding whitespace trimmed.
Plain text only, explicit clears allowed through editing, never inferred from
blank scanner cells.

`ScannerMergePlanner` combines parsed rows with a frozen scoped notebook snapshot:

1. Coalesce duplicate normalized codes when fields agree or a field is blank/Unknown.
   Conflicting known values become explicit per-row conflicts, including conflicts
   within the paste. Keep source row numbers on the merged candidate.
2. Against an active episode, preserve notes/bookmarks/firstSeenAt and known values
   when incoming cells are blank/Unknown. Different known type/name requires the
   user to choose keep existing/use incoming/manual correction; no default overwrite.
3. Rows absent from this paste survive. A matching Trash code defaults to New
   observation with a new UUID and no inherited notes; Restore is separate.
4. Preview classifies mutually exclusive Added (including New observation), Updated
   details, Seen again, Invalid and Conflicts; also report duplicate count. Any
   selected unresolved conflict disables that selection's commit.
5. Preview pins scope+generation, scope revision, row revisions, observedAt, input
   digest and operation UUID. Any input, selection or conflict-resolution change
   yields a newly resolved plan/digest; the applied operation cannot be repurposed.

Zero selected valid rows disables Import and returns No valid signatures selected.
Preview/cancel/clipboard failure perform no DB writes; retain existing editable
input. The transaction revalidates all assumptions (§2.4). F5 must produce exactly
3 unique valid rows, 1 duplicate, 1 invalid and committed counts2 added/0 updated/
1 seen again. New episodes count as added in the success message. A type conflict
resolved away from Wormhole retires the owned link atomically.

### 4.4 Directed multigraph and endpoint orientation

`ExplorationGraphBuilder.build(inputs)` uses real directed gates plus eligible
public and selected-character local wormholes. A wormhole produces two directed
edges; gates use only actual source rows. No edge from a system static, scanner
site name, just a Wormhole row, another character, or an endpoint name alone.
Retain base candidate adjacency before user preference filtering, with all source/
lifecycle assessments at captured now. Normal search applies preferences;
diagnostic search traverses this same base with only user avoids disabled. Do not
throw preference-rejected edges away before diagnosis. Cache raw reference/source
adjacency by source revisions; reassess time eligibility per request. Any cached
eligibility-pruned projection includes its time epoch and relevant preferences.

Canonical directed keys are structured tuples, compared by a locale-independent
total order: `(sourceKind, sourceScope, sourceRecordKey, fromSystemId, toSystemId,
direction)`. Use a documented stable source order gate/public/local, canonical
record keys and numeric comparison for system IDs; encode with unambiguous
length-prefixed fields when hashing. Names are not keys. Parallel gate/signature
records keep distinct keys; identical endpoints do not deduplicate them. For the
F7 equal-cost public edges, record key `w01` precedes `w02` regardless of insertion.

Each `DirectedExplorationEdge` carries from/to IDs, gate/WH kind, immutable endpoint
signatures and type labels, source record+revision, all relevant timestamps,
observed status and known restrictions/limitations. Derive orientation once:

| Observation | Hub/from side | Far/to side |
|---|---|---|
| Public `wh_exits_outward=true` | Reported originating code | K162 |
| Public `wh_exits_outward=false` | K162 | Reported originating code |
| Public orientation missing | Type side unknown | Type side unknown |
| Local known originating type, side From | Known originating code | K162 |
| Local known originating type, side To | K162 | Known originating code |
| Local observed K162 with no known originating type | Preserve observed K162 | Unknown, never invent B274 |

Reverse traversal swaps endpoint roles/signatures, not source truth or timestamps.
Contradictory local observed codes/side choices are validation failures before
confirmation. Known code with unknown side stays unassigned; a reverse label is
inferred only when justified by a known originating type and side.

Mass is Fresh/Reduced/Critical/Unknown, time Stable/EOL/Unknown, and lifecycle
Active/Past estimate/Closed/Unavailable (local storage also has Retired). Keep
local observed time and expiry-derived time separate. Effective EOL is true if
either a valid explicit observation says EOL or the estimate is below 4h; an
optimistic Stable observation does not cancel the estimate, and a future estimate
does not erase observed EOL. At expiry the edge is always ineligible. Expose both
provenances. Missing estimate is not unknown if explicit local time was observed;
missing both stays Unknown. Nominal type lifetime never creates estimatedExpiresAt
or verifiedAt automatically. These rules apply in the pure status assessor.

### 4.5 Eligibility and disclosed risk

`EdgeEligibility.assess(edge, snapshot, preferences)` returns all exclusion reasons,
qualifications, risk rank and next transition, not just `bool allowed`.

**Source/structural exclusions:** missing/unresolved endpoints, invalid topology,
incomplete/non-wormhole public record, wrong character, inactive owner, closed or
retired link, omitted latest public membership, past estimated expiry, local
verification age≥24h, public validation age≥24h, stale public with no opt-in, or
unsupported known traversal restriction. Missing mass/time alone is not closure.

**Preference exclusions:** known EOL when avoidEol; known Critical when
avoidCriticalMass; entered Lowsec/Nullsec when their respective avoid flags are on.
Security applies to `edge.to`, including destination and hubs. A pilot can start
in an excluded origin and leave; re-entering it later is prohibited. Pochven and
J-space are not disguised as Lowsec/Nullsec and remain visibly risky.

Risk rank is the maximum applicable condition for a step:

| Rank | Condition |
|---|---|
| 0 Lower | Gate entering known Highsec, with no higher qualification |
| 1 Caution | Wormhole, J-space/special/unknown category or data, source conflict, explicitly permitted stale observation |
| 2 High | Entering Lowsec, Nullsec or Pochven |
| 3 Very high | Known EOL or Critical, when allowed by preferences |

Catalog/category conflicts carry at least Caution and never reduce a higher
catalog risk; retain the higher risk of conflicting known category claims as a
conservative qualification. The canonical category still owns category filters
and security avoids, with conflict visibly disclosed. Public Unknown mass is not
Critical and is never Fresh. Route risk displayed is max(step ranks); sum is used
only in optimization. Origin security is displayed separately. Empty route has
No travel required, not Lower/Safe risk. No actual mass remaining, polarization,
gate access, ship size guarantee, other pilots or travel time is modeled.

### 4.6 Exact shortest/prefer-highsec solver

Use one tuple-cost **Dijkstra** engine (`collection` already supplies a priority
queue) in `exploration_route_engine.dart`. A plain first-visit BFS finds shortest
hop count but violates Product's risk and canonical-sequence tie-breaks. An
equal-depth-relaxing BFS is permitted only as a separately proven equivalent
optimization; it is not needed for this release. Diagnostic connectivity can use
BFS because it returns only reachability, not an ordered optimal route.

```text
Shortest cost = (jumps, riskSum, directedEdgeKeySequence)
Prefer Highsec = (nonHighsecEntries, jumps, riskSum, directedEdgeKeySequence)

extend(label, edge):
  nonHighsecEntries += edge.to.category == Highsec ? 0 : 1
  jumps += 1
  riskSum += edge.riskRank
  sequence append edge.canonicalKey
```

Compare tuples lexicographically, including full sequence comparison after numeric
ties. Queue ordering, best-label relaxation and stale-queue-entry checks use the
same comparator. Replace a label on equal numeric cost if its sequence is smaller.
Initialize origin with all zeros/empty sequence; origin is not an entry. Positive
jump increment means cycles cannot improve a label even if non-highsec/risk costs
are zero. Do not approximate Highsec preference with a large scalar penalty, use
Euclidean distance, or claim parity with EVE's weighted Safer setting.

Maintain predecessor chains, materialize sequences on ties/final reconstruction,
and cache comparisons if measurement warrants it. Stable sorted adjacency alone
is not a substitute for whole-sequence tie-breaking. Expected core cost is
O((V+E)logV), plus path-key comparison cost; record actual benchmark results.
Build/load adjacency once per topology revision, not per widget frame. Expensive
pure builds/calculations run through an injected worker/isolate runner; send only
serializable immutable snapshots, not Drift connections, refs or widgets.

`RouteOutcome` is success, noTravelRequired, preferencesBlocked, graphDisconnected,
dataUnavailable or cancelled. On failed preferred search, perform diagnostic BFS
with only the EOL/Critical/security **user avoid filters** disabled. Keep source
eligibility, private scope, stale permissions and lifecycle/expiry exclusions.
Reachable only there → **No route under these preferences**. Otherwise → **No route
in the available connection graph**. Missing/corrupt required reference/topology
→ **Route data unavailable**. Never return the diagnostic path as a route. Missing
public data can still allow gate-only results, qualified with source availability;
failed results always describe available graph coverage, not global impossibility.

Counts are accumulated from edges: `totalJumps = steps.length = gateJumps +
wormholeJumps`. Ordered steps retain departure/arrival signatures, source and
status timestamps. Successful optimality is relative to the captured available
graph and preferences. F7 exact paths and w01/w02 ties are mandatory oracles.

### 4.7 Nearest entrance shares the objective

`NearestEntranceFinder` runs **one gate-only single-source search** from the
explicit origin. For each eligible public connection, take its far endpoint's
best approach label and append the far→hub wormhole edge. Apply every preference
to that entry edge too; Avoid Lowsec excludes Turnur even from a Highsec entrance.
Rank the resulting complete tuple, not merely approach distance. Display approach
gate count and the subsequent one WH transit separately. No remote route API.

Unreachable far endpoints are excluded, never assigned0. Already in a selected
hub is a per-hub result; it does not short-circuit the other hub's search. An
isolated J-space origin explains the gate-only limitation and offers Route Planner,
which may use private links. In F8 default A→B→Thera beats A→E→Turnur on risk; with
B-T EOL and Avoid Lowsec, Thera can be approached via five gates to Z. Public
source expiry invalidates nearest results with the same scheduler as full routes.

### 4.8 Time and request fingerprints

Capture one `now` at calculation start. Input fingerprint includes origin mode,
owner/observation time, destination, selected character, all preferences, reference
revision, public snapshot+validation revisions, selected-character local revisions,
and time-eligibility epoch. Display results retain their captured data until marked
outdated, not recomputed piecemeal in row builders.

`ExplorationDeadlinePlanner` supplies the earliest future transition:

| Boundary | Wake/evaluation instant |
|---|---|
| Public becomes stale | validatedAt +5m exactly |
| Public becomes view-only | validatedAt +24h exactly |
| Local verification expires | verifiedAt +24h exactly |
| Current origin stops being current | observedAt +60s +1ms |
| Stable estimate becomes EOL estimate | expiresAt −4h +1ms |
| Past reported expiry | expiresAt exactly |
| Notebook pruning | load/resume/hourly, predicate at exact threshold |

Scheduling exactly at the4h or 60s equality without the subsequent tick is a bug.
Use cancellable local deadlines, plus a low-frequency visible age-label tick; time
labels do not issue HTTP. Clock jumps/resume trigger immediate reconciliation;
negative ages/future local observations produce a clock diagnostic rather than
extended trust. Clamp display ages, do not silently extend routing permissions.

## 5. State management and Riverpod providers architecture

### 5.1 Provider topology

Add `lib/features/exploration/data/exploration_providers.dart` and split controller
files by responsibility. Use current Riverpod 3 patterns; keep service providers
alive only where resource ownership requires it and dispose streams/timers/client
resources explicitly. The following names are the public seams for test overrides.

| Provider | Kind / responsibility / dependencies |
|---|---|
| `explorationClockProvider` | Synchronous clock dependency; fake in tests. |
| `explorationReferenceRepositoryProvider` | Provider using real `sdeServiceProvider`/SDE DB. No ESI. |
| `explorationReferenceStatusProvider` | StreamProvider of installed readiness/version; independent from whole-app SDE startup. |
| `explorationTypeSearchProvider(query)`, `explorationSystemSearchProvider(query)` | AutoDispose FutureProvider families, local indexed paged queries. Query is immutable/value-equal; debounce typing in controller. |
| `explorationSystemDetailProvider(id)` | Local composite reference detail with exact effects/statics/provenance. |
| `eveScoutTransportProvider`, `eveScoutFeedRepositoryProvider` | Injected transport and durable coordinator/repository, shared with Intel. |
| `eveScoutFeedProvider` | StreamProvider of complete cached feed state, including empty/no-cache/error/attempt metadata; watching does not itself make HTTP. |
| `explorationRefreshControllerProvider` | Async command controller; both refresh gestures call `refreshPublicFeed(reason)`. Returns typed outcome; cache remains independently subscribed. |
| `explorationVisibilityProvider` | Native/app visibility and active module destination; explicit test seam, not provider mount count. |
| `explorationLiveDemandProvider` | AutoDispose controller enables 5m eligibility checks only for visible Connections/Routes or visible Intel consumer. |
| `explorationNotebookRepositoryProvider` | Real DB transaction service. |
| `explorationNotebookProvider(scope, view)` | Scoped StreamProvider for active/trash and revision; external changes reread. |
| `explorationImportControllerProvider(scope)` | Scoped preview/action state machine; pins generation, preserves input on errors. |
| `explorationConnectionControllerProvider(scope)` | Revision-checked confirmation/edit/close actions. |
| `explorationOriginControllerProvider` | Explicit origin union, strict ESI requests and last-known observation storage. |
| `explorationRouteInputsProvider` | Synchronous immutable selections/preferences plus validated source revision dependencies. |
| `explorationGraphProvider(inputKey)` | FutureProvider/worker build over immutable source snapshots; raw adjacency cached by source revisions, assessed projection by full input/time key. |
| `explorationRouteControllerProvider`, `explorationNearestControllerProvider` | Latest-request calculation/cancellation/outdated result state. Never network directly. |
| `explorationDeadlineProvider` | Local boundary timer; invalidates time epoch/results/derived badges, no source mutation or HTTP. |
| `explorationNavigationControllerProvider` | Stable four-view selection, filters and scroll keys; persists selected view/manual-origin preferences. |
| `explorationNameResolverProvider` | Batched local system/region names first, safe cached/source fallback and explicit optional existing name-provider fallback. |

Use `activeCharacterProvider` as the UI selection source, augmented by a production
cross-window selection observer: its current local Drift stream alone cannot see
another connection's `setActiveCharacter`. Publish a `characterSelectionChanged`
hint from the character-switch command, and reread on5s active revision checks/
resume (or compare the active-character row when checking revisions). This belongs
to X7/X6's scoped integration, not a global navigation rewrite. On deletion or
switch, private families and current-origin state invalidate immediately; manual
origin and public data survive. All callbacks compare scope/generation before
publishing. A late save cannot recreate records after central deletion.
Route sources observe the selected character's **entire set** of notebook-scope
revisions, including newly inserted systems, not merely the currently open notebook.
Window-scoped prune demand is separate from view-scoped public network demand.
When integrating the existing CharacterNavRail, replace its current direct
`activeCharacterProvider.value` access with explicit `.when()` handling as well;
the shared selector must not preserve a stale pilot label during a scope switch.

### 5.2 Async states and stale-content policy

Every async UI seam uses `.when(data:, loading:, error:)`, including nested name
lookups; no unguarded `.value`, `requireValue` or raw-ID catch fallback. Prefer a
single derived ViewModel per major view instead of many network name providers
per row. Repositories represent ordinary refresh failure *inside cached state*,
not as loss of the entire feed stream. Actual DB/read failure has an explicit
error state and preserves any separately retained last-known view with qualification.

```dart
feedAsync.when(
  skipLoadingOnReload: true,
  skipLoadingOnRefresh: true,
  data: (state) => PublicHighwaysView(model: state.viewModel),
  loading: () => const ConnectionsLoadingView(),
  error: (error, stack) => ConnectionsUnavailableView(error: safeError(error)),
);
```

The flags retain content only for the **same feed/scope**. Notebook/character
switches must not display previous-family rows under a new header; loading/error
for the new family replaces private content. Route refresh keeps its last result
visibly **Outdated** until a matching new calculation commits. No stale current
badge while a provider reloads. Initial loading differs from cached refresh, a
valid empty snapshot differs from no cache, and filtered empty differs from both.

### 5.3 Snapshot consistency and latest-request wins

Subscribe before first load; bracket reads by revision and retry if a concurrent
commit changes the version during the read. Feed records+metadata are read in one
AppDatabase transaction. Private rows and scope revisions are read consistently;
SDE topology+manifest are read from a single reference revision. Since the databases
are separate, compare source revisions after assembling them and retry if changed.
Keep calculation time frozen even if the operation runs across a wall-clock tick.

Controllers increment a generation on origin, destination, selected character,
preference, source revision or deadline changes. Mark old result outdated before
starting work. Cancel old worker when possible; always reject a completion whose
generation/fingerprint no longer matches. Recheck deadlines at result publication:
a route finishing after its source expiry is not current even if no timer callback
ran. Cancellation is not No route and does not clear a newer result.
Before route or nearest calculation/publication, CurrentCharacter age>60s yields
`needsOriginRefreshOrLastKnown`: keep the old result outdated and block a new
current result until refresh, explicit Last known, or manual selection. Automatic
recalculation must not convert stale Current into current again or change modes.

Route refresh calls the shared public refresh operation and, only when the user
explicitly chose Current location refresh, the strict location operation; manual
origin is untouched. Recalculate from committed dependencies even during HTTP
cooldown, making cache qualification clear. No need to invalidate the feed provider
to create a fetch. Local graph recomputation never bypasses rate limits.

### 5.4 Selection and side-effect lifecycle

Restore last destination/manual origin on reopen if those system IDs still exist
in the installed catalog; otherwise show unresolved selection and require repair,
not a numeric name. Restore preferences conservatively; stale-route opt-in is a
visible session choice and resets Off on window recreation. Do not restore a
CurrentCharacter selection as a new observation. Persisted last known requires
explicit user selection.

IndexedStack keeps filters, detail selection and scroll positions via stable keys;
offstage children are not active public-feed consumers. Release public eligibility
timers when their view demand stops, and window-level revision/prune timers when
the window hides/disposes; reread revisions/deadlines when demand returns. A started
transaction completes atomically even if the view is disposed; its result is
published only into the still-matching scope. A started feed request can finish
for shared cache, but it never schedules another request while all consumers hide.

## 6. Presentation layer and responsive UI architecture

### 6.1 Window registration and host readiness

Append `WindowType.exploration` with stable **ID 14**, preserving0–13. Update
`title`, `windowId`, `fromId`, `defaultSize`, `iconAsset`; default 1440×900. Register
tray key `exploration` and named Exploration icon assets in existing tray/neocom
asset directories. `SubWindowApp._buildScreen` returns `ExplorationScreen`.

`WindowService` needs a per-type open future so concurrent tray taps coalesce.
Distinguish hide from destruction: hiding Exploration retains its controller;
reopen shows/focuses it. Remove a controller only when the actual native window
was destroyed. Reconcile through the platform window inventory when stale. Inject
a platform adapter to test this without a real native window; keep all existing
IDs and registrations unchanged.

For Exploration only, mount the screen independently of the global
`sdeInitializerProvider` barrier. Reference and route portions display scoped
readiness/error while notebook and accepted public cache remain accessible. Do
not bypass reference validation or force every screen into a new global shell.

Add `lib/core/window/window_visibility_service.dart` and a small macOS registrar
bridge in `macos/Runner/WindowVisibilityPlugin.swift` (registered for every engine
where the existing resize plugin is registered). Bind to that engine's actual
`NSWindow`, not the main window by assumption. Emit visible/non-minimized, hidden,
closed and application-resume observations using window/application notifications;
detach observers on disposal. Non-macOS uses the platform application lifecycle
adapter plus screen visibility. Product requires no polling when all consuming
windows hide; `window_manager` main-window state and provider mount count do not
prove this for independent subwindows. Visibility handling is a normal test seam.

### 6.2 Widget composition

```text
SubWindowApp → existing host / adaptive character selector
  ExplorationScreen
    ExplorationAppBar (title, selected character, view-scoped actions)
    ExplorationNavigation (rail or four-destination bottom navigation)
    IndexedStack
      WormholeDatabaseView
        ReferenceStatusStrip / ReferenceSearchFilters / TypeOrSystemList
        WormholeTypeDetail / SystemReferenceDetail / EffectModifierList
      PublicHighwaysView
        FeedStatusStrip / HubAndDestinationFilters / OriginSelector
        PublicConnectionList / ConnectionEndpointPanel / NearestEntranceList
      SignatureNotebookView
        NotebookScopeHeader / SignatureFilters / SignatureList / SignatureDetail
        ScannerImportSheet / SignatureEditor / ConnectionEditor / SignatureTrash
      RoutePlannerView
        OriginDestinationEditor / RoutePreferenceControls / CalculationStatus
        RouteSummary / RouteStepList / RouteStepDetail / ExcludedEdgeSummary
```

Place new screens/views under `lib/features/exploration/presentation/` and reusable
pieces under `widgets/`. Shared status/endpoint widgets can also serve Intel.
Views receive derived ViewModels (resolved names, formatted measurements, badges,
copyable optional signature, eligibility explanation, committed outcome). They
dispatch intent; no parsing, security math, expiry math, SQL, pathfinding or raw
transport DTO access. Formatting exact/reference values belongs to a tested
formatter, retaining exact units in detail and accessible text.

### 6.3 Responsive widths and character selection

Use LayoutBuilder on actual usable width, never physical desktop width or one
platform flag. The host keeps the existing 60px CharacterNavRail only when its
removal leaves at least 600px for Exploration. Otherwise use a new compact
AppBar character menu (there is no existing generic CharacterSelector to assume).
Let `moduleWidth` be width **after** character navigation. At moduleWidth≥600 use
module NavigationRail; below 600 use four-destination NavigationBar with short
Database/Connections/Signatures/Routes labels and full semantic names.

After module navigation, `viewWidth` controls content arrangement: ≥1100 master-
detail where useful;600–1099 list plus detail sheet/page; below 600 single column
full-width details. This avoids squeezing a nominal 1100px whole window into two
panes after two rails consume space. F8's320/600/1100/1440 outer viewport matrix
must assert remaining widths as well as direct boundary tests at 599/600 and
1099/1100 usable widths. At200% text switch to stacked content earlier if text
constraints require it; navigation still follows its usable-width threshold.

Tables reflow into labeled row groups. Chips wrap or use a labeled filter sheet.
Avoid fixed dialog heights, clipped horizontal action strips and horizontal page
scrolling. Detail pages/sheets have a scrollable body, safe areas and reachable
actions; long system/region/effect labels wrap. Selected row identity and detail
survive sorting/refresh by stable key, not index.

### 6.4 View-specific behavior and reuse with Intel

**Database:** local search, Types/Systems switch, destination and mass controls.
Show Reference data version/status with update/repair entry, not a fake live refresh.
Type details show reliable lifetime, exact kg, regen per cycle, K162 unknowns and
variant disagreements. System details show named hierarchy, category/class/security,
beacon-derived effect strengths/scopes and separately attributed statics.

**Public highways:** AppBar `RefreshAppBarAction` and `RefreshIndicator` call the
same controller, including always-scrollable empty/error surfaces. FeedStatusStrip
shows validation age, receipt/report time distinction, cache/stale/cooldown/error
state and next eligible attempt. Credit EVE-Scout / Signal Cartel with fixed public
link. Cards show both labeled endpoints, separate time/mass, source update/expiry,
reported size and Unknown fields. Copy only the selected side's known signature;
absent signature has no copy button. Route to this entrance selects the far system
in Route Planner only; never call `setDestinationProvider` or waypoint APIs.

**Intel migration:** `TheraConnectionsCard` becomes a compact projection of the
same feed ViewModel (title includes Turnur), with the same freshness/error badges
and refresh command. Remove “Live” and `remainingHours`-based status inference.
Do not force unknowns into the legacy required-field `TheraConnection` model;
migrate internal consumers to the new nullable model, retaining a name-only
compatibility alias/provider only if needed. Existing kill feed refresh remains
separate and must not start a duplicate EVE-Scout loop.

**Notebook:** pin character+named system in header and dialogs. Read/write local
records offline for a selected known character; no-character disables writes only.
Present observation time separately from edited time and link verification.
Import sheet has editable input, row errors/conflicts and selected counts before
any write. Type seen here, Known originating type and Originating type side are
separate connection controls. Trash exposes reason/time, Restore and confirmed
permanent delete; pruning settings explain retirement, not physical disappearance.

**Routes:** explicit origin mode and destination, all six preferences, Calculate,
cancel/progress/outdated states. Ordered named gate/WH steps have departure-side
signature/type, full provenance in detail, counts, risk explanation and limitations.
No Safe badge, guaranteed ETA, ship-pass promise or autopilot action. Preferences
and source ages remain visible on retained outdated results. Show all applicable
excluded-edge reasons rather than a misleading empty route.

### 6.5 Names, accessibility and exact feedback

Resolve system/region names in batches from installed reference first. Known
source/cached names may be displayed as qualified fallback when reference is
unavailable; otherwise Unknown system/Unknown region. Existing
`locationNameProvider` is an optional fallback, never a required offline lookup or
automatic N+1 live query. Types use local reference/SDE with `itemNameProvider`
fallback; unknown uses Unknown type, never `Item #...`. Disabled network means
these fallbacks remain human-readable. Unknown numeric IDs may be in debug logs,
not UI or accessibility text. Icons must have text alternatives and respect existing
EVE image size constraints; no network image is necessary for offline catalog use.

Apply Product [§6.6 exact feedback](exploration-module.md#66-emptyerror-states-exact-action-feedback-and-accessibility)
as the copy source, including clipboard empty/read error, zero selection, preview
conflict, save failure, committed counts, cooldown and no-route distinctions.
Import/save/link actions disable while busy and do not queue duplicate writes.
Apply obtains one synchronous submission reservation before any await; freeze
editable input, selections and conflict choices for that command. Cancel, Escape
and barrier dismissal work without writes before submission, but are disabled
once the commit phase begins. Show Saving until committed/failed; do not present
a successful cancellation while a transaction may still commit. Context switch/
native disposal follows the pinned-scope publication rule in §2.4, not a promise
to cancel committed SQL. On failure release the reservation and restore input.
Focus returns to the invoking control after sheets; semantic announcements report
the actual committed outcome. Status uses icon+text, not only color; unknowns are
neutral. Every icon action has a tooltip/semantic label, keyboard access and touch
equivalent. Respect text scaling and reduced-motion settings. No essential hover-only
content. Tester verifies real interactions as well as screenshots.

## 7. Work unit breakdown

### 7.1 Ownership and dependency graph

Every unit follows Test-Author RED → Dev GREEN → Reviewer contract review → Tester
verification. Test-Author owns assertions/fixtures and shows a meaningful failing
behavior, not merely a missing import. Dev implements the smallest production
seam; Reviewer checks Product, race/rollback/privacy and regression boundaries;
Tester runs the unit plus affected integration gates and records evidence. Plan
assigns one owner per shared file. Parallel workers must preserve others' changes;
X2 alone owns AppDatabase migration, X1 alone SDE schema/assets, X7 host/native.
Other units request edits through those owners rather than racing generated files.

```text
X0 contracts + fixtures + harness
 ├─ X1 reference pipeline ────────────────┐
 ├─ X2 AppDatabase ─┬─ X3 shared feed ────┤
 │                 └─ X4 notebook ───────┤
 ├─ X5 pure graph/route engine ──────────┤
 └─ X7 host/visibility skeleton ─────────┤
                                        X6 provider/origin composition
                                         ├─ X8 reference/public UI + Intel
                                         └─ X9 notebook/route UI
                                                  ↓
                                           X10 release/closeout
```

X1/X2/X5/X7 can proceed in parallel after X0 freezes shared types. X3/X4 need X2
schema; their unit tests may use fixture reference data while X1 completes. X5
uses X0 source fixtures, not unfinished live repositories. X6 integrates the real
X1–X5 and X7 visibility seams. X8/X9 can proceed in parallel once X6 is usable.
Reference/topology must ship before nearest/routes, shared feed before both live
consumers, and explicit connection verification before private edges are enabled.

### 7.2 Unit file and TDD contracts

Paths below are relative to the repository. Within rows, `exploration/` means
`lib/features/exploration/`. Test file keys resolve in §8.2.

| Unit | Owned production/files and responsibility | Depends on | RED expectation | GREEN and review/test gate |
|---|---|---|---|---|
| X0 Contracts and harness | New domain value types in §4.1; `test/features/exploration/fixtures/`; `integration_test/test_utils/exploration_test_harness.dart`; controlled clock/HTTP/clipboard/window/worker adapters; schema 20/6 fixture capture | None | Contract fixtures demonstrate absent/incorrect behavior; no fake repository returning saved success | Frozen F1–F8, immutable codecs and stable API seams; all downstream AC mappings assigned. No claim the feature is runnable. |
| X1 Populated offline reference | `lib/core/sde/exploration_tables.dart`, `sde_database.dart/.g.dart`, `sde_service.dart`, `sde_update_service.dart`, reference repository; extractor, manifest/assets, `pubspec.yaml`, workflow; pure reference derivation/search formatter | X0 | Offline full catalog missing; published filtering loses types; placeholder names; failed import incorrectly stamps version; vector/scope/boundary regressions | D01–D07/P01–P02 reference portions; full manifest and exact effect gates; schema 6 upgrade, failed update rollback, newer installed version retained; no cross-slice data loss. |
| X2 Durable user data foundation | `exploration/data/exploration_tables.dart`; `app_database.dart/.g.dart`; migration21/indices; revision observer support, explicit central character cleanup | X0 | Version20 lacks tables; duplicate active codes or millisecond loss; delayed save can orphan private data | P02/P11/P12/P16 storage portions; fresh/upgrade/rollback/on-disk reopen; active partial uniqueness and explicit clears. Migration owner reviews all dependent repository SQL. |
| X3 Shared public feed | Refactor Intel `eve_scout_client.dart`; new `eve_scout_normalizer.dart`, `eve_scout_feed_repository.dart`, `exploration_revision_observer.dart`; HTTP DTOs, status derivation, lease/cache/backoff/history; replace Intel network provider with storage adapter | X0, X2 | F3 integer/string/orientation/Unknown fail; dual clients both fetch; invalid/failed write partially replaces cache;304 resets wrong clock | D08–D11/D24, P03–P07; two independent DB connections, fenced stale response, valid empty, backoff, all time boundaries and atomic publish. No direct fetch remains in Intel watch/refresh. |
| X4 Notebook and verification | `scanner_import_parser.dart`, `scanner_merge_planner.dart`, `exploration_notebook_repository.dart`; pure lifecycle/field validation; scoped CRUD/import/prune/link commands | X0, X2 | F5 silent drops/clears or partial save; replay duplicates; F6 prune/rescan race and type edit leaves a route edge | D12–D16 and P10–P14 repository portions; rollback/replay, exact counts, trash episodes, both commit orders, explicit link verification and owner cleanup. |
| X5 Pure graph and routes | `exploration_graph_builder.dart`, `edge_eligibility.dart`, `exploration_route_engine.dart`, `nearest_entrance_finder.dart`, `exploration_deadline_planner.dart`; typed risk/outcomes | X0 | First-visit BFS/endpoint dedup/soft penalties produce wrong F7; stale/private/expired edges survive; wrong endpoint labels | D15–D23 route portions; all F7/F8 oracles, insertion permutations, directed gates, canonical ties, exact deadlines, no diagnostic relaxed route. |
| X6 Providers, origins and ViewModels | `exploration_providers.dart`; origin/refresh/import/connection/route/navigation controllers; pure display projections; strict location method in `esi_client.dart`; local worker runner | X1–X5, X7 interfaces | Old character/route result publishes last;60s/5m/24h elapsed but current badge persists; manual origin overwritten; refresh clears valid cache | P08–P09/P15/P17, source-revision/bracket tests, `.when()` review and no direct UI calculations. Dependencies feed real repositories; no separate network loops. |
| X7 Window and lifecycle foundation | `window_types.dart`, `window_service.dart`, `sub_window_app.dart`, `cross_window_events.dart`, tray service, character rail/adaptive selector; initial `exploration_screen.dart` shell; visibility Dart/Swift bridge and registration; icon assets | X0 | ID collision; concurrent opens duplicate; hidden engine recreated; SDE failure blocks notebook; hidden views continue polling | U01 foundation, P07/P09 lifecycle, icon tests, production-host override seam and native smoke; old window identities unaffected. X8/X9 supply final view bodies. |
| X8 Reference/public presentation | `exploration_screen.dart` integration after explicit ownership handoff from X7, `wormhole_database_view.dart`, `public_highways_view.dart`, reusable reference/endpoint/feed/origin/nearest widgets; Intel card/kill-feed integration | X1, X3, X5, X6, X7 | Offline detail mislabels units/effects; side copy wrong; cooldown reports success;320px/200% overflow; raw IDs leak | U02–U10/U18 relevant paths, real host/storage, both refresh mechanisms, keyboard/touch/semantics, all empty/error/cache states and shared Intel view revision. |
| X9 Notebook/route presentation | `signature_notebook_view.dart`, `route_planner_view.dart`, editors/import/trash/route widgets, view action feedback | X4, X5, X6, X7 | Preview writes before apply; conflicts/no-character allow saves; confirmation scope wrong; outdated route appears current | U02–U03/U09–U18 relevant paths, exact committed messages and route counts, selected-scope races, confirmation and all responsive dialogs. |
| X10 Release evidence and closeout | Feature test suites, extractor/schema goldens, performance harness, `.claude/visual-validation/checklists/exploration.yaml`, `docs/engineering-journal/`, README, checkpoint and release evidence | X1–X9 | Missing coverage/manifest/asset/lifecycle/native proof remains release-blocking | All60 cases and mandatory subcases, all 40 ACs, full regression/analyze/build checks, measured targets, sanitized logs and API re-probe; only then archive QUEUED as shipped. |

Schema/generated-file updates are atomic with their defining unit, not hand-edited
generated code. Each unit commit records its RED/GREEN commands and checkpoint.
Unit test pass is not native-window or release validation; Tester records those
separately. No new third-party graph/database stack is required.

## 8. Test traceability matrix

### 8.1 Harness and evidence rules

Product names60 cases **D01–D24, P01–P18, U01–U18**. The requested **T01–T60** are
stable aliases: T01–T24=D01–D24; T25–T42=P01–P18; T43–T60=U01–U18. Never replace
or renumber Product identifiers. Each case's variants are mandatory parameterized
subcases, not optional examples. Use T0=`2026-09-15T12:00:00Z` and Product F1–F8.

- Domain tests call real parsers/derivers/solvers with synthetic source snapshots
  and assert full precision before formatting. Add permutation/property checks for
  equivalent graph insertion order, multigraph identity and unchanged input data.
- Persistence tests use real generated Drift and repositories. Memory databases
  serve single-connection tests; migration/restart/lease/missed-event tests use two
  independently opened databases over one temporary SQLite file. A single shared
  ProviderContainer or single Drift instance is not cross-engine evidence.
- `ExplorationTestHarness` owns AppDatabase and SdeDatabase outside widget lifetime,
  seeds through real import/mutation paths and wraps the **actual SubWindowApp**
  in ProviderScope with those overrides. Current `main.dart` owns the production
  scope; SubWindowApp does not introduce a second scope. Reuse that composition
  without adding a redundant host container API or a shadowing nested scope.
  Dispose resources outside fake-async pumping.
- Override only external boundaries: `eveScoutTransportProvider`, strict ESI
  HTTP/token boundary (or recording strict ESI adapter), `explorationClockProvider`,
  clipboard, native window/visibility and worker scheduling. Use real repositories,
  parser/normalizer, serialization, transactions, providers, screen/dialog widgets.
  For strict ESI classification tests, run real EsiClient against a recording Dio
  adapter; a location-service fake cannot prove status/scope mapping.
- SDE tests import generated F1/F2 bundles and the packaged full manifest through
  the real importer. A mock returning an arbitrary system name is not offline
  completeness or migration evidence. Missing/corrupt assets must also be tested.
- Use completers/barriers and fake clock advancement for out-of-order transport,
  refresh, DB failure, route cancellation and prune/import interleavings. Do not
  use wall-clock sleeps or `pumpAndSettle` against infinite active timers. Pump
  through known states, then dispose subscriptions/timers and assert none leak.
- Recording HTTP/clipboard/ESI-write adapters fail tests on unexpected requests;
  assert zero auto clipboard reads, remote routes, waypoint/bookmark/private mapper
  writes, and zero HTTP during reference/manual-origin lookup/filtering.
- Native smoke launches/focuses/hides/resumes the real tray window and Intel with
  controlled network fixtures, independent engines and on-disk storage. Screenshots
  supplement semantic/keyboard/touch assertions; screenshots alone do not prove
  a committed write or working refresh.

### 8.2 Test file keys

All new test files are proposed; keys shorten the two matrices without hiding file
ownership. Existing general regression files remain part of X10.

| Key | Test file |
|---|---|
| REF | `test/features/exploration/domain/exploration_reference_test.dart` |
| PUB | `test/features/exploration/domain/eve_scout_normalizer_test.dart` |
| SCAN | `test/features/exploration/domain/scanner_import_test.dart` |
| LIFE | `test/features/exploration/domain/exploration_lifecycle_test.dart` |
| GRAPH | `test/features/exploration/domain/exploration_route_engine_test.dart` |
| NEAR | `test/features/exploration/domain/nearest_entrance_finder_test.dart` |
| SDE | `test/core/sde/exploration_reference_import_test.dart` |
| MIG | `test/core/database/exploration_migration_test.dart` |
| FEED | `test/features/exploration/data/eve_scout_feed_repository_test.dart` |
| ENGINES | `test/features/exploration/data/exploration_cross_engine_test.dart` |
| ORIGIN | `test/features/exploration/data/exploration_origin_test.dart` |
| NOTE | `test/features/exploration/data/exploration_notebook_repository_test.dart` |
| STATE | `test/features/exploration/data/exploration_providers_test.dart` |
| PERF | `test/performance/exploration_benchmark_test.dart` |
| WIN | `test/core/window/exploration_window_test.dart` and `integration_test/screens/exploration/exploration_window_test.dart` |
| LAYOUT | `integration_test/screens/exploration/exploration_responsive_test.dart` |
| A11Y | `integration_test/screens/exploration/exploration_accessibility_test.dart` |
| REFUI | `integration_test/screens/exploration/wormhole_database_test.dart` |
| PUBUI | `integration_test/screens/exploration/public_highways_test.dart` |
| NOTEUI | `integration_test/screens/exploration/signature_notebook_test.dart` |
| ROUTEUI | `integration_test/screens/exploration/route_planner_test.dart` |
| RECOVER | `integration_test/screens/exploration/exploration_recovery_test.dart` |

### 8.3 All acceptance criteria

The case lists preserve every association in Product §8; X0 supplies fixtures and
X10 verifies all rows. Listed units are implementation owners, not a waiver of
shared review/test responsibility.

| AC | Contract | Work units | Test aliases |
|---|---|---|---|
| AC1 | Offline completeness/atomic reference | X1, X2, X6, X8 | T25, T26, T41, T60 |
| AC2 | Deterministic search/filters | X1, X8 | T03, T46 |
| AC3 | Exact reference units | X1, X8 | T01, T46 |
| AC4 | K162/variants | X1, X8 | T01, T02, T46 |
| AC5 | Class/security/system identity | X1, X8 | T05, T06, T07, T47 |
| AC6 | Exact effects/scopes | X1, X8 | T04, T05, T47 |
| AC7 | Honest statics/provenance | X1, X8 | T06, T25, T47 |
| AC8 | Public v2/no credentials | X3, X8 | T11, T27, T60 |
| AC9 | Endpoint orientation | X3, X5, X8, X9 | T08, T23, T48 |
| AC10 | Public Unknown mass | X3, X8 | T10, T48 |
| AC11 | Exact time semantics | X3, X5, X6, X9 | T09, T58 |
| AC12 | Durable dual refresh/freshness | X3, X5, X6, X8 | T20, T28, T49 |
| AC13 | Request discipline | X3, X6, X7, X8 | T28, T29, T49 |
| AC14 | Atomic shared feed | X2, X3, X7, X8 | T11, T30, T31, T50 |
| AC15 | Far-side category filters | X1, X3, X8 | T07, T24, T50 |
| AC16 | Origin ownership/freshness | X6, X7, X8, X9 | T32, T33, T51 |
| AC17 | Nearest entrance | X5, X6, X8 | T21, T52 |
| AC18 | Scoped validated CRUD | X2, X4, X6, X9 | T14, T35, T51, T54 |
| AC19 | Scanner syntax/diagnostics | X4, X9 | T12, T53, T54 |
| AC20 | Atomic preview/merge | X2, X4, X6, X9 | T13, T34, T35, T37, T53 |
| AC21 | Limits/cancel/failure | X4, X6, X9 | T14, T34, T54 |
| AC22 | Observation/edit/episode identity | X2, X4, X9 | T13, T34, T36, T53 |
| AC23 | Trash/restore | X4, X9 | T36, T55 |
| AC24 | Confirmed scoped hard delete | X2, X4, X9 | T36, T55 |
| AC25 | Prune policies/races | X4, X6, X9 | T15, T37, T55 |
| AC26 | Explicit local verification | X4, X5, X9 | T15, T16, T38, T56 |
| AC27 | Directed scoped multigraph | X4, X5, X6 | T16, T17, T33 |
| AC28 | Eligibility/stale opt-in | X3, X4, X5, X6, X9 | T20, T38, T39, T58 |
| AC29 | Hard avoids/origin escape | X5, X9 | T19, T57 |
| AC30 | Exact objective/ties | X5, X9 | T17, T18, T22, T57 |
| AC31 | Ordered steps/counts | X5, X9 | T17, T23, T57 |
| AC32 | Risk meaning/limitations | X5, X9 | T23, T57 |
| AC33 | Invalidation/latest result | X6, X7, X9 | T33, T39, T58 |
| AC34 | Distinct no-route/unavailable | X1, X5, X6, X9 | T22, T41, T59 |
| AC35 | Tray/window/state retention | X7, X8, X9 | T43 |
| AC36 | Responsive view/dialog matrix | X7, X8, X9 | T44 |
| AC37 | Accessible committed feedback | X8, X9 | T45, T48, T49, T50, T54 |
| AC38 | Async/domain/name separation | X1, X6, X7, X8, X9 | T41, T46, T51, T59, T60 |
| AC39 | Logging/performance | X1, X3, X4, X5, X6, X7, X8, X9, X10 | T42 |
| AC40 | Migration/lifecycle/side effects | X2, X3, X4, X6, X7, X8, X9 | T26, T31, T40, T52, T60 |

### 8.4 All 60 executable case contracts

| Alias | Product ID | Units | Files | Strategy and required assertions |
|---|---|---|---|---|
| T01 | D01 | X1 | REF | F1 raw B274/I078 lifetime conversions and kg/cycle; K162 absent dogma stays null. |
| T02 | D02 | X1 | REF | C729 variant agreement/disagreement, reversed input order, consensus without overwritten type IDs. |
| T03 | D03 | X1 | REF | F1 exact/prefix/substring rank, trimmed case, AND filters and exact capital threshold; same-variant conjunction and escaped wildcard inputs. |
| T04 | D04 | X1 | REF | All36 effect sets and every Product vector/scope; full-precision resonance/cap/small-weapon examples. |
| T05 | D05 | X1 | REF | Class13 and both named beacon/visual mismatches; strength mapping and no-effect versus unknown. |
| T06 | D06 | X1 | REF | System/constellation/region precedence, missing/typical statics and no live edge from assignments. |
| T07 | D07 | X1 | REF | Every F2 raw security/display boundary, special identities and future class preservation. |
| T08 | D08 | X3 | PUB | F3 true/false/missing orientation; both endpoint signatures/types; absent far signature never copied. |
| T09 | D09 | X3, X5 | PUB, LIFE | Frozen clock at 4h, 4h−1ms,expiry; ignore remaining_hours999; no collapse inference. |
| T10 | D10 | X3 | PUB | Every completed/fresh/size/time combination retains public Unknown/not-reported mass. |
| T11 | D11 | X3 | PUB | Integer/string provider keys, optional future enums, bad core identity and conflicting duplicate rejection as a whole. |
| T12 | D12 | X4 | SCAN | F5 CRLF/LF/BOM/header/blanks; tabs and localized group/type distinctions; original row numbers and extra columns. |
| T13 | D13 | X4 | SCAN | Duplicate coalescing, known conflict resolution, blank preservation and existing annotation retention. |
| T14 | D14 | X4 | SCAN, LIFE | Inclusive field/UTF-8 byte/row limits, Unicode lengths, explicit clears and whole-paste oversized rejection. |
| T15 | D15 | X4, X5 | LIFE | Exact24/48/72h/Off prune predicates and 24h verification; edit time irrelevant and policies independent. |
| T16 | D16 | X4, X5 | LIFE, GRAPH | No/self/valid destination, originating side and K162/Unknown; verified pair only, close/type/endpoint/orientation changes invalidate. |
| T17 | D17 | X5 | GRAPH | F7 default A-B-T-Z, parallel w01/w02 and insertion permutations; correct count and full canonical path tie. |
| T18 | D18 | X5 | GRAPH | Prefer Highsec picks five-gate A-E-F-G-H-Z over shorter alternatives; no finite scalar approximation. |
| T19 | D19 | X5 | GRAPH | Every F7 EOL/Critical/Lowsec avoid result; origin escape, re-entry exclusion and blocked destination. |
| T20 | D20 | X3, X4, X5 | LIFE, GRAPH | F4 validation5m/24h and local retirement/verification boundaries; stale opt-in never restores expired/closed/omitted links. |
| T21 | D21 | X5 | NEAR | F8 one gate approach tree, appended hub-entry preference/risk, separate counts, already-in-hub and isolated J origin. |
| T22 | D22 | X5 | GRAPH | Zero-step, disconnected, unavailable topology and one-way gate; diagnostic BFS does not relax source eligibility. |
| T23 | D23 | X5 | GRAPH | Risk maximum versus sum, entered-system rank, both-direction endpoint provenance and total=edge count. |
| T24 | D24 | X3 | PUB | Far-side HS/LS/NS/Pochven/J/Unknown; AND hub+region filters; complete All and stable source sort. |
| T25 | P01 | X1 | SDE | Offline first install from full bundled manifest; checksum/count corruption and failed update rollback; independent statics coverage. |
| T26 | P02 | X1, X2 | SDE, MIG | Actual schema 6/20 files upgraded to 7/21; concurrent bootstraps, failure after first table/index and before atomic version publish, crash/reopen; old characters/AAR/Intel retained and new rows round-trip. |
| T27 | P03 | X3 | FEED | Recording transport proves exact fixed public endpoint, JSON/identity headers, no auth/private/staging payload; real cache commit. |
| T28 | P04 | X3, X6, X7 | FEED, ENGINES | Concurrent dual refresh and visible timers share one claim; minimum 300s between attempts; filters issue zero requests. |
| T29 | P05 | X3 | FEED | 15s abort timeout, 5xx backoff 300/600/900, 429 Retry-After seconds/date, 304 with/without valid cache; renewal versus receipt. |
| T30 | P06 | X2, X3 | FEED | Valid empty, HTML/non-array/core/duplicate failures and injected commit failure; no partial public publication or notebook changes. |
| T31 | P07 | X2, X3, X7 | ENGINES | Two independent DB engines; suppressed events, initial-load race, hide/resume, lease crash/fence, late response; same accepted revision/no extra fetch. |
| T32 | P08 | X6 | ORIGIN | Real strict ESI mapping, 60s versus60s+1ms, auth/scope/network/no-location; manual and explicit Last known never auto-replaced. |
| T33 | P09 | X6, X7 | ORIGIN, STATE | Character switch while location/route blocked; late results rejected, immediate private-edge removal, public/manual retention. |
| T34 | P10 | X4, X6 | NOTE, STATE | Real preview/apply/cancel/replay/rollback; recording clipboard empty/non-text/read failure retains input; zero-selected cannot commit. |
| T35 | P11 | X2, X4, X6 | NOTE | Scope/revision concurrent edits/inserts, active uniqueness and explicit-null clear; conflicts never overwrite across scopes. |
| T36 | P12 | X2, X4 | NOTE | Trash/Undo/Restore, fresh episode and active-code conflict; confirmed exact IDs/count hard delete; replay after deletion/reopen remains idempotent; no age/link renewal or other-owner/public loss. |
| T37 | P13 | X4, X6 | NOTE, STATE | Load/resume/hourly prune and Off, including another selected view and all selected-character systems; both rescan/prune commit orders with barriers; reapply rebuilt preview explicitly. |
| T38 | P14 | X4, X5 | NOTE, GRAPH | Verify/rescan/close/restore and form/import type changes; endpoint/orientation edit clears old verification; pruning Off cannot bypass 24h. |
| T39 | P15 | X6 | STATE | Input/source/304 and exact 5m/4h/24h/60s+1ms timers; prior result outdated first, latest fingerprint only, no timer HTTP. |
| T40 | P16 | X2, X4 | NOTE, MIG | Delete selected character via central lifecycle with feature closed; late write rejected; all private dependent rows removed, others/public/reference retained. |
| T41 | P17 | X1, X6 | SDE, STATE | Missing/corrupt catalog and AsyncValue failures, offline name fallback; no raw visible IDs, honest unavailable graph, notebook/cache remain usable. |
| T42 | P18 | X1, X3, X4, X5, X6, X7, X8, X9, X10 | PERF | Full-catalog warm search p95≤100ms and 10k/30k directed graph p95≤1s on recorded desktop; assert sanitized tagged logs and duration metrics. |
| T43 | U01 | X7, X8, X9 | WIN | Actual tray adapter and native launch/repeat/concurrent focus, existing IDs/icons/windows, all destinations preserve stable view state. |
| T44 | U02 | X7, X8, X9 | LAYOUT | All F8 widths/text scales, long names, open dialogs and every major data state; usable-width boundaries, no horizontal page overflow. |
| T45 | U03 | X8, X9 | A11Y | Keyboard/touch parity, restored focus, semantic labels/announcements, color-independent statuses and busy actions. |
| T46 | U04 | X1, X8 | REFUI | Offline F1 search, mass qualifier, K162/variants and exact units; real name/reference providers, no raw IDs. |
| T47 | U05 | X1, X8 | REFUI | F2 exact effect/scopes/meaning, long labels, independent statics/source status and no-effect/unknown details. |
| T48 | U06 | X3, X8 | PUBUI | F3 both orientations, capture clipboard writes for chosen side only, unknown no-copy, neutral independent mass/time. |
| T49 | U07 | X3, X6, X8 | PUBUI | AppBar and pull on populated/empty/error always-scrollable UI; same lease command and truthful busy/cooldown/commit/failure feedback. |
| T50 | U08 | X3, X8 | PUBUI | Valid feed-empty versus filter-empty versus unavailable; failed refresh retains cache with age and next retry. |
| T51 | U09 | X6, X7, X8, X9 | PUBUI, NOTEUI | Manual/current/last-known, no-character/scope and switch while loading; correct ownership, enabled offline public/manual functions. |
| T52 | U10 | X5, X6, X8 | PUBUI, ROUTEUI | F8 exact approach+WH count, avoided hub and already-in-hub, planner far-system prefill; recording ESI proves no waypoint call. |
| T53 | U11 | X4, X6, X9 | NOTEUI | Real F5 preview/conflict selection/import; exact 3-row counts/message and stored annotation/absent-row preservation. |
| T54 | U12 | X4, X6, X9 | NOTEUI | Oversized/corrupt/localized/clipboard failures, zero valid, cancel/rollback/scope conflict; gated slow-save/double-submit disables Cancel/Escape/barrier and cannot report cancelled before later success; retained input/no false save success. |
| T55 | U13 | X4, X9 | NOTEUI | F6 Trash/Undo/Restore/conflict, explicit hard-delete selected count and prune notice; no restored freshness claim. |
| T56 | U14 | X4, X9 | NOTEUI | Named/K162-side confirmation and unknown orientation; edited endpoint/type not eligible until explicit valid verify, correct close feedback. |
| T57 | U15 | X5, X9 | ROUTEUI | F7 exact presets/path/count/risk explanations and named endpoint details; no silent relaxation/Safe/ETA claim. |
| T58 | U16 | X3, X5, X6, X9 | ROUTEUI | Expiry/freshness/current-origin timers, preferences and delayed older worker; outdated first, refresh/Last known required, newest result only. |
| T59 | U17 | X1, X5, X6, X9 | ROUTEUI | Missing topology/disconnected/excluded destination yield the three exact actionable messages, no raw IDs or fictitious zero-hop path. |
| T60 | U18 | X1, X2, X3, X4, X6, X7, X8, X9 | RECOVER | All views offline, close/reopen/restart/missed events with real stores; cache qualifications and no automatic clipboard/EVE/community writes. |

### 8.5 Workflow coverage and release evidence

| Product workflow | Units | Representative aliases (full AC matrix still applies) |
|---|---|---|
| S1 Offline type lookup | X1, X8 | T01–T03, T25, T46 |
| S2 System properties/effects | X1, X8 | T04–T07, T47 |
| S3 Public highway browsing | X3, X6, X8 | T08–T11, T24, T27–T31, T48–T50 |
| S4 Nearest entrance | X5, X6, X8 | T21, T32–T33, T51–T52 |
| S5 Scanner import | X4, X6, X9 | T12–T14, T34–T35, T53–T54 |
| S6 Retirement | X4, X9 | T15, T36–T37, T55 |
| S7 Verified connection | X4, X5, X9 | T16, T38, T56 |
| S8 Mixed route | X5, X6, X9 | T17–T23, T39, T57–T59 |
| S9 Offline/context recovery | X1–X10 | T26, T31, T33, T40–T45, T60 |

X10 evidence records exact commands, baseline/build/host, all parameterized results,
coverage (minimum 80% overall changed code; critical parser/transaction/eligibility
branches fully exercised), regression failures with baseline comparison, schema
fixtures/checksums, route oracles, responsive screenshots and semantic/native
journeys. Run applicable `flutter test`, integration suites, `flutter analyze`,
format checks and macOS build/smoke; extractor tests run under repository Python
tooling. No benchmark timing assertions in ordinary widget tests.

Performance harness records host CPU/OS, debug/profile/release mode, dataset hash,
warmup, sample count (at least 100 measured runs), p50/p95 and peak memory. Measure
warm indexed search against full packaged catalog and routing over deterministic
10,000-system/30,000-directed-edge fixture, including ties and unavailable edges.
Separate reference loading/graph build from pure solver time and report both;
do not hide UI-frame stalls inside a favorable solver number. Targets are Product
p95≤100ms search and≤1s pure routing, not unmeasured promises.

Before release re-probe the public schema/headers once under the cooldown policy,
record only sanitized contract evidence and confirm any drift with Product. Do
not commit volatile pilot records as expected test values. Architecture delivery
does not turn any of these future tests into passing evidence.

## 9. Invariants, failure modes and security considerations

### 9.1 Enforcement checklist

- `installedReferenceRevision` identifies one validated complete slice; failed
  updates preserve the prior manifest and rows. An older bundled asset never
  downgrades a newer installed compatible reference.
- One accepted public snapshot and one app-wide eligible request per feed scope;
  accepted payload/validation/observation clocks never advance on failure.
- `active signature count per(character,system,code) ≤1`; episode UUID owns links.
  Every mutation validates scope, owner existence and expected revisions.
- An eligible local edge implies active Wormhole owner, explicit valid endpoints,
  active verification younger than 24h and no expiry/closure/retirement. Rescan,
  note edit, undo or Restore cannot establish this implication.
- `steps.length = gateJumps + wormholeJumps = totalJumps`; all steps are directed
  eligible edges from the captured graph; displayed max risk differs from cost sum.
- Every published current calculation matches current request/source/time fingerprint.
  Late completion, clock boundary and character switch cannot restore stale truth.
- No view displays raw numeric IDs or uses unknown as Fresh/Stable/zero/No effect.
  No route claims safety or graph completeness beyond the installed manifest.
- Viewing/filtering/route calculation is read-only externally; only user actions
  read/copy clipboard and selected ESI location. No automatic EVE/community writes.

### 9.2 Failure and troubleshooting matrix

| Failure | Required behavior | Diagnostic / safe recovery |
|---|---|---|
| Missing/corrupt reference or unpublished-type omission | Reference/route unavailable; notebook/cache usable; never fake empty topology | Check installed manifest version/counts/hash and extractor validation; retry bundled repair/update without deleting working slices. |
| Bad optional static source/coverage | Static information unavailable; other reference remains valid | Inspect separate source attribution/version; do not infer assignments from class/type flags. |
| API HTML/core error/contradictory duplicate | Whole refresh fails, old cache retained | Tagged validation reason and row ordinal/provider key, not full body; normal cooldown. |
| Timeout/429/5xx | Cached observations plus age/retry; no clock renewal | Inspect persisted attempt, retry deadline, failure count and claim token; never bypass cooldown manually. |
| Crash during HTTP/DB busy | Lease expires, accepted cache unchanged; no duplicate attempt within 300s | Read coordinator row and accepted revision; retry claim after policy deadline, never clear another engine's lease. |
| Persistence failure | No success notification or partial import/feed | Inspect sanitized SQL operation/error and rollback; preserve editable input and prior records. |
| Missed event/hidden window | Reopen/resume or active revision poll reconciles from DB | Compare SQLite revisions; event files are hints and may already be removed. Do not invalidate into another fetch. |
| Invalid origin/auth/scope/network | Current location unavailable; manual/explicit Last known option | Typed strict ESI error; request no extra permissions automatically. |
| Preview becomes stale or character deleted | Review-again/conflict, no retargeted or orphan write | Scope generation/row revision/owner-existence checks; rebuild preview from retained input. |
| No route | One of three Product messages, coverage and exclusions | Inspect source snapshot/version/time and all exclusion reasons; never silently relax controls. |
| Timer delayed / device clock changes | Mark result outdated, reconcile boundaries on resume/publication | Record clock anomaly without claiming renewed freshness; explicit refresh/Last known as appropriate. |
| Unknown names | Human-readable placeholders/source-qualified names | Local catalog readiness then safe cached provider fallback; never paste numeric IDs into error UI. |

Useful developer commands after implementation (no private row dumps):

```bash
flutter test test/features/exploration/domain/
flutter test test/features/exploration/data/
flutter test test/core/sde/exploration_reference_import_test.dart
flutter test test/core/database/exploration_migration_test.dart
flutter test integration_test/screens/exploration/
flutter analyze
rg 'EXPLORATION' <sanitized-log-file>
```

Feature logs use `Log.d('EXPLORATION.ROUTE', ...)`/equivalents, which the shared
logger renders with bracketed tags. Log public method start/outcome, operation ID,
revision/fence, scoped internal IDs, counts, duration, sanitized error category,
source status and lifecycle transition. Do not log raw clipboard, notes, bookmarks,
access tokens, request authorization, public contributor fields or unredacted
response bodies. Pure functions stay deterministic: application wrappers log
their invocation/result, not per-node graph traversals or every modifier value.

### 9.3 Security and privacy boundaries

All scanner and feed content is untrusted plain text. Use parameterized SQL,
bounded parsing/Unicode limits, schema validation and fixed network destinations.
No expression evaluation, HTML rendering, shell execution or navigation derived
from notes/bookmarks. Fixed attribution links may open only via the existing safe
URL mechanism. Archive extraction validates paths, sizes, checksums and declared
files before import; do not accept path traversal or silently expand arbitrary
download content. Verified archive/checksum transport is HTTPS, with provenance
recorded; a checksum alone is not a publisher signature.

Local private notebooks and location observations stay on-device in AppDatabase
under current application storage/security policy. This design does not claim
at-rest encryption beyond the existing platform or add remote backup/sync. No
raw clipboard persisted in operation receipts. Permanent deletion is explicit and
scoped, not a promise of forensic erasure from SQLite backups. Public and reference
data are never deleted through character-owned cleanup.

### 9.4 Non-goals and change control

Out of scope: Tripwire/Pathfinder/Wanderer or corporation sharing, force-directed
maps, connection notifications/background OS daemon, filament/cyno/jumpbridge
planning, automatic EVE bookmarks/waypoints, clipboard monitoring, hacking/site
valuation, polarization/remaining-mass accounting, combat-safety prediction,
environment-effect application to fits/AAR and a new app-wide navigation shell.
No network service is introduced, no CombatEnrichment or AI schema migration is
needed, and no route result is persisted as current.

The optional supplementary static dataset may remain unavailable; all official
reference/topology/effect and existing Product acceptance obligations still apply.
Unresolved upstream contract changes, missing manifest completeness or inability
to prove native lifecycle/request coordination are release blockers to resolve
with evidence, not reasons to weaken Unknown handling or omit test variants.
Plan may split units without changing contracts or losing ownership/traceability.
Material behavior changes go back to Product; archive the queued initiative only
after implementation and Tester acceptance, not at this documentation commit.

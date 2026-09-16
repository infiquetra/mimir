# Corporation Module — Technical Architecture and Design

Status: Architecture complete; implementation and executable verification pending.
Date: 2026-09-15. Owner: Technical Architect (Arch).
Product: [`corporation-module.md`](corporation-module.md), commit `0abc4f6`.
Application baseline: `feature/corporation-module`, based on `ccfe79b`.

This is the technical contract for Plan, Test-Author, Dev, Reviewer and Tester.
Product owns behavior, exact user feedback and F1–F8. This document defines the
implementation boundaries and evidence needed to satisfy it. The requested
Riverpod “2.0” label is historical: this branch declares Riverpod 3 and resolves
`flutter_riverpod` 3.0.3, Drift 2.31.0, AppDatabase 21 and SdeDatabase 7. Use installed
APIs; no framework downgrade. **New** names below are proposed, not existing code.

## 1. Architecture and system overview

### 1.1 Scope and dependency direction

Corporation is a read-only, role-aware workspace in dedicated **Window 15**,
default 1200×800, launched/focused from TrayService. Its four stable destinations
are Overview & Roster, Assets, Structures & Fuel (navigation label Structures),
and Wallets. Active-character selection is a real, separate control. Preserve
Window IDs 0–14 and do not migrate the app to a different navigation shell.

```text
Existing OAuth PKCE / token manager → durable character grant + membership
                                                    ↓
ESI raw response → typed decoder → authority + complete-publication transaction
                                                    ↓
     public reference/cache ← Drift snapshots and endpoint access evidence
                                                    ↓
          pure roster / asset / fuel / wallet derivation services
                                                    ↓
        Riverpod guarded ViewModels → actual Corporation SubWindowApp
                                                    ↓
                 main-only opt-in monitor → native notification adapter
```

Features live under `lib/features/corporation/{domain,data,presentation}/`.
Domain imports no Flutter, Riverpod, Drift, HTTP or ambient clock. Providers own
lifecycle/composition; repositories own authorized reads and transactional writes;
transport preserves response metadata; widgets display prepared models and intent.
No role/valuation/fuel/accounting formulas in widgets. Clock, HTTP, native platform,
browser/auth callback and worker scheduling are injectable boundaries.

Private observations are not a global corporation cache. Every record and derived
result is owned by an authorizing character, corporation, capability and grant.
Another character in the same corporation cannot inherit that authorization.
Public profile/reference/names may be shared, but a public name does not make a
member relationship, private location or amount public.

### 1.2 Binding architectural contracts

1. **Server authorization wins.** Requested scope, granted scope, general role,
   location role, grantable-role evidence and endpoint success are distinct.
   A public CEO match or title named Director does not unlock private data.
2. **Visibility is checked, not assumed from cached data.** Private content needs
   the current usable grant, resolved membership, no invalidation, successful
   endpoint validation younger than one hour, and required fresh role evidence
   unless that endpoint has an explicit verified exception. Equality locks.
3. **Known loss takes precedence.** Scope/role loss, denial, departure and deletion
   invalidate targeted payloads/derivatives immediately at the authority boundary;
   failed transport cannot renew access. Late workers cannot undo revocation.
4. **Complete publication is atomic.** Required pages/cursor coverage validate
   together; list replacement, metadata and lease renewal commit together. Failed
   persistence is not refresh success. Enrichments have independent permissions.
5. **Observation and validation clocks remain separate.** A 304 can renew validated
   access without rewriting source times. UI cache reads and Q/R calculations cannot.
6. **Exact numbers remain exact.** Preserve JSON numeric lexemes for money and IDs;
   decimal TEXT/BigInt arithmetic, never binary-double accumulation or default zero.
7. **Fuel has three sources.** Reported expiry, observed bay inventory and local
   scenario/model have separate provenance. Only fresh authorized reported expiry
   drives new native alert episodes. Q/R is dated stock capacity, not a new clock.
8. **SQLite is cross-engine authority.** Request claims, invalidation generations,
   revisions and alert episodes are durable. Process-local locks/events supplement,
   never replace, ownership checks. An old grant incarnation never becomes valid
   again after delete/re-add.
9. **Formula-free, guarded, named presentation.** Explicit `.when()` branches,
   no prior-character frame on local switch, no raw numeric EVE IDs in any visible,
   semantic, copied or notified content. Division numbers 1–7 are legitimate labels.
10. **Read-only external scope.** ESI reads, the specified read-only names POSTs,
    explicit PKCE and opt-in local notifications only. No management/market/wallet/
    bookmark/waypoint writes, token pooling, LLM-derived evidence or cloud monitor.

### 1.3 Current seams: reuse without inheriting gaps

| Existing seam | Required change and owner |
|---|---|
| `lib/core/database/app_database.dart` | Schema 21→22, explicit atomic bootstrap/migration, owned cache/grant/request tables, central delete/switch fences; C1. Current migration callbacks are not an atomic-version guarantee. |
| `lib/core/auth/{oauth_service,auth_providers,pending_auth_store,token_manager}.dart` | Capability-specific scopes, intended subject, durable actual grant state, cancellation/refresh CAS and quarantine/rebind; C2. Parsed scopes are currently discarded. |
| `lib/features/characters/data/character_repository.dart` | Membership publication must be update-only and expected-generation checked; delayed refresh must not resurrect a deleted character via upsert; C2. |
| `lib/core/network/esi_client.dart` | Add raw response/status/header-preserving corporate requests with per-request compatibility, shared rate/refresh controls; preserve legacy callers; C2. |
| `lib/core/window/{window_types,window_service,sub_window_app,window_visibility_service,cross_window_events}.dart` | Register 15, actual visibility/revision lifecycle, no global SDE barrier, real selector; C7. |
| `lib/core/tray/tray_service.dart`, `lib/app.dart` | Tray launch and main-only optional alert monitor composition; C7/C5. |
| Personal assets/wallet/market services | Reuse batching/transaction patterns, not lossy DTOs, first-page assumptions, global private names or double arithmetic; C4/C6. |
| SdeService/SdeDatabase 7 | Batch type/system lookups and reference readiness; add a reviewed fuel-rule artifact, not an unverified use of missing structure dogma; C0/C5. |
| Existing native notifications | `local_notifier` 0.1.6 lacks permission-query/request APIs on macOS; supply a permission-capable adapter instead of inventing methods; C5. |

Exploration is a separate shipped initiative, but inspection at this baseline
does **not** establish that all its adapters satisfy this design: its UI providers
include session-memory streams/test counters; its visibility provider is constant;
the feed claim lacks a complete live-lease predicate; no generic cross-engine
revision observer is wired. Reuse proven low-level table/window/fixture seams,
not those behavior assumptions. `WindowService.openWindow` genuinely coalesces
opens and `hideWindow` preserves controllers; `closeWindow` still removes then
hides, so C7 must distinguish hide from destruction on Corporation's path.
No wholesale Exploration rewrite is authorized by this architecture.

### 1.4 Core immutable contracts

Use Freezed or final immutable value types with defensive collections. Persisted
codecs use stable enum strings and schema versions; unknown upstream enums carry
raw diagnostic values but grant no permission. All instants are UTC milliseconds.

| New domain file | Contract types |
|---|---|
| `corporation_context.dart` | `CorporationContext`, `CharacterGrant`, `OwnerIncarnation`, `MembershipState`, `CapabilityKey`, `PublicationFence`, `VisibilityPermit`. |
| `corporation_access.dart` | `Capability`, `RoleEvidence`, `ScopeRequirement`, `RequestEligibility`, `AccessDecision`, `EndpointAuthorization`, `GrantTransition`, pure capability evaluator. |
| `corporation_snapshot.dart` | `SnapshotEnvelope<T>`, `SourceTimes`, `PageEvidence`, `HistoryCoverage`, `RefreshOutcome`, source/validation/freshness distinctions. |
| `corporation_profile.dart`, `corporation_roster.dart` | Versioned tax/profile adapter output, roster membership and independently authorized join/roles/titles/tracking projections, own NPC standings. |
| `corporation_decimal.dart` | Signed normalized `ExactDecimal(BigInt coefficient, int scale)`, lossless keys, integer quantities and exact rational duration. |
| `corporation_asset.dart` | Complete inventory rows, original parent references, safe forest/path diagnostics, valuation/search coverage. |
| `corporation_structure.dart`, `corporation_fuel.dart` | Reported state/services/timers, fuel quantity, proven fitted consumer instances, model manifest, source compatibility, local scenario. |
| `corporation_fuel_alert.dart` | Pure episode state/event/reducer, severity and delivery eligibility; episode is not keyed by expiry timestamp. |
| `corporation_wallet.dart` | Seven-division balance availability, signed nullable journal amounts, cursor trades, interval totals/link states and retained coverage. |

Authority identity is `(tenant, characterId, incarnationUuid, corporationId,
grantEpoch, capability, divisionOrResource)`. An incarnation UUID is new when a
character is newly added/re-added; grantEpoch increases on explicit reauthorization
or changed grants, not ordinary same-subject/same-scope refresh. Context generation
and invalidation revision fence jobs separately from the grant. Never reuse a
default numeric generation after deletion. IDs are internal, not display names.

`AccessDecision` is a sealed result: noCharacter, resolvingMembership,
unavailableCorporation, missingScope, missingRole, permissionsUnknown,
probeEligible, denied, authenticationExpired, leaseExpired, or allowed(permit).
No cached data is a separate dataset state, not permission denial. `allowed`
contains the owning key, evidence revisions and effective expiry; it cannot be
constructed by the UI or a generic `isDirector` flag. A display model carries the
same authority fingerprint as every source it joins.

`RequestEligibility` is separate from `VisibilityPermit`: scope/role/probe/context
and request deadlines can permit a first fetch or lease renewal while no private
payload is readable. Never require prior endpoint success to attempt the first
authorized request. A refreshable access token that has merely expired is not a
known-invalid grant and does not shorten an otherwise valid offline read lease.

## 2. Data storage and schema design

### 2.1 AppDatabase 22 and storage conventions

C1 owns schema 22, generated Drift files and migration. Add new table definitions
under `lib/features/corporation/data/corporation_tables.dart`; shared auth/request
metadata belongs under `lib/core/database/` or `lib/core/auth/` and is registered
in `AppDatabase`. Do not place corporation records into personal assets/wallets,
CombatEnrichment or app-settings blobs. No SDE schema bump is required: SDE 7 plus
a versioned validated fuel-rule artifact supplies reference needs.

Use explicit integer `*_at_ms`/`*_until_ms` columns with UTC conversion, preserving
expiry−1ms/equality and source-skew tests through restart. Avoid a global Drift
DateTime storage change. Money/price/rate columns are canonical decimal **TEXT**,
not SQLite REAL; source item/journal/transaction keys are canonical decimal TEXT
when an int64 would risk narrowing. Small validated character/type/system IDs
may remain INTEGER. SQL sort on large decimal identity uses length then lexical
digits, or an exact validated int64 representation, never floating-point cast.

Every private payload row has a foreign key to its owned snapshot or explicit
authority key. All queries join the authoritative access/grant state before
returning a visible payload; the raw DAO is not a public widget/provider API.
Public caches are clearly separate. A nullable quantity/balance/field stays null,
not 0, an empty list, a date epoch or a fabricated enum default.

### 2.2 Tables and ownership

Table names below are concrete design names. Shared `ownerKey` abbreviates the
full authority identity in §1.4, not corporationId alone. `snapshotId` references
an immutable accepted or explicitly staged version belonging to that owner.

| Table | Primary key, fields and authority |
|---|---|
| `CharacterAuthorizationStates` | Tenant+character PK; non-reused incarnation, grant epoch, token revision, actual granted-scope set, credential state, invalidation revision, last confirmed corporation, membership state/source times, revision. No duplicate token columns. |
| `CorporationContextStates` | Tenant PK; selected character/incarnation, resolved corporation or pending state, context generation and selection revision. Coordinates main monitor and all windows; never treats corporation 0 as membership. |
| `OAuthAuthorizationAttempts` | Operation UUID PK; intended character/incarnation, prior grant/token revisions, requested scope set, mode, state digest, created/expiry time, pending/claimed/cancelled/committed status and fence. Verifier remains in the scoped existing auth-pending mechanism, not corporate cache. |
| `CorporationCapabilities` | ownerKey PK; preflight requirements, endpoint-success time, endpoint lease expiry, role-evidence reference or verified-exception proof, denial/revocation revision, next explicit probe, prior-success hint and revision. One journal division cannot renew another capability. |
| `CorporationSnapshotHeads` | ownerKey+request variant+compatibility date PK; accepted snapshotId/revision, complete/partial coverage, payload/validation/source clocks, HTTP deadline/validators, last attempt/error and refresh-round ID. Public scopes use explicit public identity instead. |
| `CorporationSnapshotPages` | Snapshot/job+page/cursor key PK; status, ETag/Last-Modified/Date/Age, declared X-Pages, normalized content digest, validation time, next cursor, completeness. Staging is hidden; per-page validators enable genuine all-page 304. |
| `EsiRequestLeases` | Canonical exact resource-key PK; tenant/app/character/rate group, caller class, job token+epoch, owner process, lease deadline, heartbeat, next attempt/backoff, expected authority/accepted revisions. Also supports serialized token-refresh jobs. |
| `EsiRateBuckets` | Tenant+application+authenticated character+rate group PK, or explicit public source scope; live limits/remaining/used, observed time, Retry-After and legacy shared error deadline; bounded local reservations/consumption metadata. Never rotate owner to escape policy. |
| `CorporationProfiles` | Public tenant+corporation PK; versioned current/legacy adapter marker, name/ticker, state/type/friendly-fire, optional CEO/alliance/founded/HQ, count, exact ISK/LP tax, sanitized text/URL, snapshot clocks/diagnostics. |
| `CorporationMembers` | Authorized roster snapshotId+memberId PK. Only the returned membership set. Optional public-history-derived join evidence may reference a public history entry; do not flatten protected tracking/roles onto this row. |
| `CorporationMemberTracking` | Tracking snapshotId+memberId PK; start date, last login/logout, base/location/ship and unknown/invalid-field diagnostics. Its own Director gate and times. |
| `CorporationRoleAssignments` | Role-capability snapshotId+subjectId PK; General/HQ/Base/Other and separately grantable sets, each with absent-versus-empty knowledge. Own-role response cannot invent grantable arrays. |
| `CorporationTitles` | Definition snapshotId+titleId PK; sanitized name and source role arrays where reported. Definitions do not authorize a person. |
| `CorporationMemberTitles` | Assignment snapshotId+memberId+titleId PK; own-title and corporate assignment capabilities remain separately owned. Locked definitions yield a title-unavailable label, not a numeric ID. |
| `CorporationOwnStandings` | Own-standings snapshotId+source kind+entityId PK; exact signed standing value and NPC source kind. Never represents player-corp standings. |
| `CorporationDivisionNames` | Division-name snapshotId+kind(hangar/wallet)+division 1–7 PK; actual custom name only. Default labels are a presentation fallback, not persisted invented data. |
| `CorporationAssets` | Asset snapshotId+itemKey PK; type, exact/unknown quantity and raw marker, singleton/BPC knowledge, location key/type, parent evidence and raw flag. Complete publication only. |
| `CorporationPrivateNames` | ownerKey+name source+entity key PK; custom item/authenticated structure name, times and source ownership references. Distinct names embedded in authorized structure rows remain with that structure snapshot. |
| `CorporationStructures` | Structure snapshotId+structureKey PK; optional source name, hull/system, future-compatible state, distinct state timer start/end, unanchor, reinforcement hour/pending settings, fuel expiry and services-present flag. |
| `CorporationStructureServices` | Structure snapshotId+structureKey+source ordinal PK; exact service label, online/offline/cleanup/unknown state. No invented fitted module type field. |
| `CorporationFuelScenarios` | Character/incarnation/corporation/structure PK; one current saved scenario, owning grant binding, exact manual quantity/rate, saved time, revision, quarantine state. CAS updates, not scenario history. Does not overwrite structure/fuel assets. |
| `CorporationFuelAlertStates` | Character/incarnation/corporation/structure PK with grant binding; present/rearm state, monotonic episode ordinal, last source revision, last severity, access invalidation. |
| `CorporationFuelAlertEpisodes` | State owner+episode UUID PK; source revision, created/severity/acknowledged/closed times, unique delivery claim, handoff/result state. Grant rebind preserves already-delivered identity, not a new episode. |
| `CorporationWalletBalances` | Balance snapshotId+division 1–7 PK; required exact signed balance. Missing division is represented in coverage, not an inserted zero row. |
| `CorporationWalletJournal` | ownerKey(division journal)+journalKey PK; exact signed nullable amount/balance, date, ref type, optional parties/context, sanitized reason/description, last observed revision. Retained history separate from a fetched window. |
| `CorporationWalletTransactions` | ownerKey(division transactions)+transactionKey PK; date, item, positive integer quantity, exact nonnegative unit price, Buy/Sell, counterparty/location, nullable/no-link journal reference, last observed revision. |
| `CorporationHistoryCoverage` | ownerKey+coverage segment/job PK; requested interval, source cutoff, validated page/cursor chain, retained interval/gaps, earliest/latest row times and termination reason. Bounds alone do not prove continuity. |
| `CorporationMonitoringPreferences` | Tenant+character/incarnation PK; explicit opt-in, preference revision and OS-permission observation. Never enables an unselected character's monitor. |
| `ExactMarketPrices` | Public tenant+typeId PK; raw-decimal average price, optional raw adjusted price not used here, source/receipt/validation times and public snapshot revision. Legacy REAL cache is not backfilled as exact. |

Public character names, corporation histories, alliance/station names can extend
existing public cache tables if they preserve versions/TTL and optional knowledge;
otherwise use a small typed public-reference cache. Do not put private structure
or custom asset names in global `AssetLocations`/universe-name rows. Fuel bay totals,
rates, Q/R, asset trees and period totals are derived, not new authoritative tables.
An optional indexed path/search projection is disposable and retains all source
authority dependencies; §4 specifies its invalidation.

Indices: owner/capability/grant on every private table; snapshot+item and
snapshot+location for assets; name-search index scoped to accepted snapshot and
name authority; owner/division/date/source key for journal/trades; grant/role expiry,
due request/lease deadline and active alert-owner indices. Unique division and
source-key constraints complement duplicate validation. Avoid `SUM(CAST(text AS
REAL))`; indexed selection feeds exact domain accumulation in a worker.

### 2.3 Migration, bootstrap and cleanup

Extend `@DriftDatabase`, run generation, advance 21→22 and create tables/indices on
both fresh install and upgrade. C1 wraps migration callback work in an explicit
transaction without losing existing AAR custom DDL, Exploration indices or default
settings. Acquire SQLite writer serialization, reread `PRAGMA user_version` after
the lock, and publish target version with DDL/indices in the same commit. Use a
supported immediate transaction/bootstrap adapter; do not nest BEGIN statements
inside a Drift transaction. Drift's subsequent same-version assignment must be
idempotent. A crash after one table/index must rollback/reopen without manual repair.
Do not rewrite historical table semantics or rename version 21 as 22.

Migration creates **no authorized leases** from existing character tokens. Existing
characters receive a new incarnation and unknown grant evidence until validated
through auth/endpoint checks. Preserve all tokens and personal data; never parse
requested configured scopes into a granted set. Existing public caches may remain
readable. Corrupt optional preferences can reset to safe defaults; corrupted private
authority metadata locks rather than authorizes.

Add central methods `selectCharacterWithRevision`,
`publishConfirmedMembership(expectedFence, observation)`,
`applyGrantTransition`, `invalidateCapability` and `deleteCorporationPrivateOwner`
on a shared authority repository backed by AppDatabase transactions. Existing
`setActiveCharacter` delegates to the selection revision path so switches outside
Corporation are observed. Membership refresh uses update-only CAS against current
incarnation/grant/membership generation, not read-then-upsert.

`AppDatabase.deleteCharacter` deletes that owner's private snapshots/staging/pages,
capabilities/names/history/scenarios/alerts/monitor preference, grant state and
pending auth/request ownership in the same central transaction, even with the
window closed. Public profile/names/prices/reference and other owners survive.
Invalidate/cancel work before publication; every returning worker checks character
existence plus incarnation. New login gets a different incarnation, so old responses
cannot resurrect it. Do not assume foreign-key cascade declarations execute:
enforcement is not uniformly enabled today; explicitly delete/check ownership or
audit/enable it in a separately proven migration.

### 2.4 Snapshot publication and retention

Repositories expose `readVisible`, `watchVisible`, `stagePage`, `publishComplete`,
`commitNotModified`, `recordFailure` and typed mutation commands. Reads load access
metadata and requested data in one consistent transaction, returning hidden/locked
without private rows/counts when no permit exists. No consumer can request an
unscoped `allCorporationAssets(corpId)` escape hatch.

Fetch/parse outside SQL; stage under the claimed job and its fence. At publication
recheck selected context, owner existence/incarnation, resolved corp, grant/scopes,
role/exception evidence, capability invalidation, live job token and expected
accepted revision. Publish normalized rows, all page metadata, source clocks,
accepted revision and new endpoint authorization in **one** transaction. A 304
requires accepted bytes/rows for every validated page. Do not renew on a failed
transaction or trust an unvalidated cached page. Emit revision hints after commit.

Inventory/structure/roster replace whole membership sets when complete, including
valid empty. Wallet history upserts validated windows/chains into retained history,
preserves older observations and updates coverage separately. Refresh can replace
the validated interval's known membership without deleting older retained periods;
ambiguous upstream gaps remain gaps, never silently filled. Reject conflicting
duplicate source IDs before the transaction. One failed division/enrichment has no
write authority over another's head.

Private lease expiry hides but retains data for possible revalidation. Explicit
same-owner reauthorization quarantines retained payload/history/scenarios; fresh
authorization of that same capability atomically rebinds its compatible retained
rows and coverage to the new grant, preserving observation times/gaps. First
revalidation under a new grant is an unconditional authorized request; do not send
old private validators as if they were current authorization. A newly complete
replacement wins for current lists; older wallet observations remain dated history.
Scope reduction, definitive role loss, capability 403, confirmed departure or
deletion purges affected ownership instead of rebinding it. No cross-owner/corp
rebind. Alert delivery tombstones survive an allowed same-owner rebind so renewed
permission does not send the same critical episode again.

Default wallet local retention is 365 days by row date; prune in a scoped transaction
and update retained coverage/gaps, not just delete rows. No 365-day upstream guarantee.
Prune abandoned staging/expired request metadata independently of accepted data.
Never clear a current request token or active authorization as a cache cleanup side
effect. Data-hidden states also hide scenario/name/search/notification derivatives.

## 3. ESI integration and caching contracts

### 3.1 Request boundary and endpoint registry

C2 adds `CorporationEsiApi`, an endpoint registry and raw-response methods on
`EsiClient`. They use the existing OAuth credentials and injected Dio transport,
but preserve status, headers and **raw UTF-8 JSON** before numeric decoding.
Request the modern root `https://esi.evetech.net`, not the legacy client's
`/latest` base. Set per-request `X-Compatibility-Date: 2026-08-18`,
`X-Tenant: tranquility`, and an application/version/contact User-Agent. Do not
mutate shared default headers/base URL or forward bearer tokens to arbitrary URLs.
The public schema requested for 2026-09-15 currently reports effective version
2026-08-18; pin fixtures and adapters to that version, not the review date.
[Primary endpoint schema](https://esi.evetech.net/meta/openapi.json?compatibility_date=2026-09-15).

The registry owns method, path template, exact scope, preflight, resource key,
pagination, TTL and rate group. The following abbreviations expand literally:
`characters` = `esi-characters`, `corporations` = `esi-corporations`,
`assets` = `esi-assets`, `wallet` = `esi-wallet`, `universe` = `esi-universe`.
For example `corporations.read_titles.v1` means
`esi-corporations.read_titles.v1`. Corporate entries also require usable current
credentials and confirmed corporation context; roles are general roles unless
explicitly marked personal/ACL. Director satisfies a required corporate role,
but never supplies a missing scope or successful endpoint verification.

| Path beneath ESI root; GET unless noted | Scope | Preflight / authorization evidence | Ordinary TTL / pagination |
|---|---|---|---|
| `/characters/{character_id}` | Public | Membership/name reference; positive corporation only | 24h |
| `/corporations/{corporation_id}` | Public | Profile and public CEO reference | 1h |
| `/alliances/{alliance_id}` | Public | Optional alliance reference | 1h |
| `/characters/{character_id}/corporationhistory` | Public | Join-date fallback only | 24h |
| `/markets/prices` | Public | Exact average-price cache | 1h |
| POST `/universe/names` | Public | Validated, batched public entity IDs | Local positive cache 24h; no invented HTTP TTL |
| `/universe/stations/{station_id}` | Public | Proven station reference | Response cache headers |
| `/characters/{character_id}/roles` | `characters.read_corporation_roles.v1` | Self; preserves general/location/grantable knowledge distinctions | 1h |
| `/characters/{character_id}/titles` | `characters.read_titles.v1` | Self, independent from corporate title endpoints | 1h |
| `/characters/{character_id}/standings` | `characters.read_standings.v1` | Self; own NPC standings only | 1h |
| `/corporations/{corporation_id}/members` | `corporations.read_corporation_membership.v1` | Corporation member; no Director requirement | 1h |
| `/corporations/{corporation_id}/roles` | `corporations.read_corporation_membership.v1` | Personnel_Manager/Director, or verified grantable-role/CEO probe path | 1h |
| `/corporations/{corporation_id}/membertracking` | `corporations.track_members.v1` | Director | 1h |
| `/corporations/{corporation_id}/members/titles` | `corporations.read_titles.v1` | Director; assignments capability | 1h |
| `/corporations/{corporation_id}/titles` | `corporations.read_titles.v1` | Director; definitions capability | 1h |
| `/corporations/{corporation_id}/divisions` | `corporations.read_divisions.v1` | Director; names capability independent of underlying assets/balances | 1h |
| `/corporations/{corporation_id}/assets` | `assets.read_corporation_assets.v1` | Director | 1h; all X-Pages |
| POST `/corporations/{corporation_id}/assets/names` | `assets.read_corporation_assets.v1` | Director; accepted owned item IDs, deduplicated batches of 1–1000 | Local cache 1h; no invented HTTP TTL |
| `/corporations/{corporation_id}/structures` | `corporations.read_structures.v1` | Station_Manager/Director | **1h**; all X-Pages |
| `/universe/structures/{structure_id}` | `universe.read_structures.v1` | Character-specific structure ACL, not corporation-role inference | 1h; separate name resource |
| `/corporations/{corporation_id}/wallets` | `wallet.read_corporation_wallets.v1` | Accountant/Junior_Accountant/Director | **5m** |
| `/corporations/{corporation_id}/wallets/{division}/journal` | `wallet.read_corporation_wallets.v1` | Accountant/Junior_Accountant/Director; division 1–7 | 1h; all X-Pages |
| `/corporations/{corporation_id}/wallets/{division}/transactions` | `wallet.read_corporation_wallets.v1` | Same role gate; independent division capability | 1h; decreasing `from_id` |

Use response cache metadata when present, with the registry policy for missing
metadata; never reuse the five-minute wallet-balance policy for structures.
Auth endpoints use the separate SSO origin and protocol, not this registry.
SDE resolves types, systems and known static locations locally. Modern profile
decoding uses percentage-valued `tax_rates.isk`/`loyalty_point`: 10 is 10%, 0.10
is 0.1%. A separately tagged legacy adapter alone converts fractional `tax_rate`
0.10 to 10%; no value-size heuristic. Preserve optional CEO/alliance/founded data
and future state/type/friendly-fire values without making the profile unusable.

### 3.2 Actual grants, reauthorization and token refresh

Add `SsoGrantValidator`, `CharacterAuthorizationRepository` and
`CorporationAuthorizationCoordinator`. Extend `OAuthService` request creation with
an explicit scope set and pending-operation identity; keep existing login callers
compatible. Reauthorization requests the union of still-needed existing scopes
and the user-selected capability scopes, not every corporate privilege silently.
Persist the **actual** verified returned grant; requested scope is not evidence.

Existing JWT parsing only decodes claims. Before treating claims as authorization,
validate signature against cached SSO discovery/JWKS using a maintained JWT library,
an explicit allowed algorithm/key policy, issuer, audience, expiry and EVE character
subject. Include the application client ID and EVE audience requirements. Do not
implement RSA or trust a token-provided arbitrary key URL. This is a focused grant
boundary, not a token-storage redesign. Cache keys according to SSO metadata and
fail closed if verification cannot be established.
[SSO validation contract](https://developers.eveonline.com/docs/services/sso/).

An operation records intended character/incarnation, prior grant/token revisions,
PKCE state digest, requested scopes, redirect metadata, expiry and cancellation.
Keep verifier access scoped to the corresponding pending operation. Claim callback
processing atomically; a second window cannot exchange/commit the same operation.
Cancellation writes a durable fence **before** clearing local UI. Before and after
exchange/validation, require matching state, current operation, unexpired attempt,
intended subject and unchanged owner incarnation. A wrong-subject callback neither
activates nor overwrites any character. Cancellation or a late callback cannot
publish credentials, scopes, membership or a new grant. Preserve normal add-character
behavior as a distinct operation mode. Sanitize touched OAuth error paths: no
authorization code, verifier, token, callback URL or token-response body in logs.

Explicit successful reauthorization increases grantEpoch even if scopes are equal;
apply quarantine/rebind and scope-loss cleanup from §2.4 in the same transition.
Ordinary same-subject/same-scope token refresh only increases tokenRevision. A
changed verified scope set is a grant transition, not a silent token replacement.
Serialize refresh per character/incarnation through a durable request claim;
waiters reread the committed token revision. CAS credential writes against the
expected revision and character existence. This prevents a late refresh from
replacing a newly authorized token or recreating a removed account.

One endpoint 401 permits one normal coordinated token refresh and one retry. A
second 401/definitively invalid refresh credential marks authentication expired and
hides the grant's private data pending reauthorization. A refresh transport failure
is not proof of role loss: retain hidden/quarantined data where appropriate, but
do not renew a lease or render an unusable credential as authorized. Never retry 403
with another character, escalate scopes automatically, or guess a corporation ID.

### 3.3 Capability evaluator and access leases

Evaluate in order: selected owner/incarnation → usable grant and verified
actual scopes → applicable confirmed corporation membership → endpoint preflight
→ invalidation/denial → endpoint authorization and required role freshness.
Membership resolution failure/temporary zero means unresolved, not confirmed
departure. A later confirmed different corporation purges the old context.
NPC/closed restrictions apply to corporation management endpoints, not authorized
self roles/titles/NPC standings. Those self capabilities still have owner/grant
isolation and their own successful endpoint evidence; they do not unlock corporate
management. Unresolved corporate context never authorizes a corporation 0 request.

Own role responses preserve General, HQ, Base and Other sets independently.
Only General Director/required role satisfies ordinary corporate preflight.
Names of titles are not roles. Own roles cannot manufacture grantable-role arrays;
unknown is not empty and a location Director is not a general Director. The
corporate roles endpoint's grantable-role alternative is a verified exception,
not a broad permission propagated to tracking/assets/titles.

A fresh public CEO match with sufficient actual scopes, or a documented
grantable-role alternative, may expose **Verify access** for that endpoint.
It does not expose data. Allow one explicit probe per endpoint/hour or new grant,
obeying HTTP/rate deadlines. Successful verification records an endpoint-specific
exception; a failure records typed denial. Previously verified success may schedule
due hourly revalidation even after its lease expires, with payload hidden until
success. Known role loss/denial is not an automatic retry loop: require the
appropriate new evidence or explicit permitted probe.

For ordinary role-gated data:

```text
endpointUntil = lastCompleteAuthorizedValidation + 1 hour
roleUntil     = requiredRoleObservation + 1 hour
visibleUntil  = min(endpointUntil, roleUntil)
visible       = currentAuthorityMatches && noInvalidation && now < visibleUntil
```

Self/member-only endpoints omit an irrelevant corporate-role operand; verified
exception paths use their explicit evidence rather than inventing ordinary roles.
Credential refresh may restore usability but cannot extend endpoint/role evidence.
Ordinary access-token expiry with a refreshable, not-known-invalid stored grant
does not cap offline readability at the token expiry instant. Known revocation,
invalid credentials or failed definitive renewal locks immediately; online
requests still obtain a valid access token through the coordinated refresh path.
Reevaluate exactly at the earliest boundary. A 200 or fully validated 304 may renew
that endpoint only. Mere cache read, manual refresh tap, offline startup, another
division's success or role response alone cannot. Within an unexpired verified
lease, offline reads work. At equality, hide retained content and show the Product
verification state. Offline revocation discovery is bounded by this lease, not
claimed to be immediate or guaranteed by OAuth scopes alone.

### 3.4 Complete pagination, exact decoding and publication

`LosslessEsiJsonDecoder` tokenizes JSON before ordinary double conversion. Preserve
numeric lexemes for IDs, balances, prices and amounts; validate JSON grammar and
field contracts, then construct exact domain values. A regex replacement over JSON
text is forbidden because it can corrupt strings. Test exponents, signed zero,
large identifiers, escape sequences, null, malformed numbers and bounded lengths.
Bound coefficient digits and absolute exponent/scale **before** BigInt expansion,
`pow10` or scale alignment; short input such as `1e999999999` must be rejected as
typed invalid payload, not consume unbounded memory or be rounded/truncated.
Use a vetted lossless parser or a narrowly tested tokenizer; ordinary `jsonDecode`
followed by `double.toString()` cannot recover discarded precision.

`CorporationPageAssembler` fetches every declared page for inventory, structures
and a requested journal generation. Require consistent positive X-Pages and
compatible Last-Modified across pages where present. Missing X-Pages on a nonempty
result is **partial**, not implicitly page 1 of 1. An explicitly covered empty set
is complete. Duplicate keys with identical content coalesce; conflicts fail the
candidate. Validate membership/page fingerprints again when a long fetch changes
generation; never combine pages across an observed change. Respect the Product
coverage contract where validators are absent; do not invent a common upstream
snapshot timestamp merely because local requests occurred together.

304 is page-specific: use cached content only for that same owner, grant, query,
compatibility and page validator. Page 1 returning 304 cannot renew all pages.
Validate the complete page set (200/304 mix only when compatible) before publishing
or renewing a private lease. Missing cached content for 304 triggers an unconditional
request when policy permits, never an empty replacement. Authorization errors
short-circuit staging and perform invalidation, even if earlier pages succeeded.

For transactions, start at the newest response and request `from_id` equal to the
smallest returned exact transaction ID. Require strictly decreasing progress;
coalesce identical boundary duplicates, reject conflicting duplicates or cycles.
A short page is not exhaustion. An empty response proves exhaustion; a demonstrably
reached requested time boundary proves only that requested interval. Bound each
job to 100 responses. At the bound, persist honest partial coverage and a resumable
cursor; present More history, not false completion. Resume an inventory/page job
only after revalidating its source generation; otherwise restart staging. Malformed
required values, conflicting duplicates or a non-progressing cursor chain reject
the entire staged history job without changing retained rows or accepted coverage.
A clean resource-bound pause may retain explicitly partial validated observations
under an existing permit; it cannot establish continuity or renew authorization.
No partial inventory replacement. Valid earlier pages do not excuse a malformed
later quantity/price or conflicting boundary record.

Initial history seeks the Product 30-day window, retaining validated local history
up to 365 days. `HistoryCoverage` stores interval segments, gaps and termination
reason, not a boolean derived from min/max row dates. Source truncation, retention,
bounded jobs and legitimately nullable amounts remain distinguishable coverage
dimensions; malformed required values are failures, not nullable amounts.

### 3.5 Freshness, single-flight and refresh scheduling

Store request/response instants, Date, Age, Expires/Cache-Control, Last-Modified and
validators. Separate `payloadReceivedAt` (200 content), `validatedAt` (200/304),
`upstreamModifiedAt`, `nextRequestAt` and access expiry. A 304 does not move payload
receipt or a fuel observation time. Compute HTTP age once, using RFC-style age:

```text
apparentAge = max(0, responseReceivedAt - Date)
correctedAge = max(apparentAge, Age + responseDelay)
currentAge = correctedAge + residentTime
remaining = max(0, freshnessLifetime - currentAge)
```

Use valid Cache-Control lifetime first; otherwise derive lifetime from Expires−Date
or the endpoint policy. F6 with Date=T0−120s, Age=120s and lifetime 3600s leaves 3480s
at receipt, not 3360s. Honor server Retry-After/rate deadlines in addition to cache
deadlines. An HTTP cache deadline never extends an authorization lease.
[ESI cache and pagination guidance](https://developers.eveonline.com/docs/services/esi/best-practices/).

`CorporationRefreshCoordinator.refresh(context, requestedResources, trigger)` is
shared by AppBar, pull-to-refresh, visibility polling and the optional monitor.
It returns `updated`, `partial`, `cachedUntil`, `failedUsingCache`, `locked`,
`rateLimited` or `cancelled`, with per-resource outcomes. Manual means due-only,
not bypass caches/rate limits. Report full updated only when **all due requested**
resources published successfully; a secondary failure yields honest partial
feedback. No-character disables refresh. Visible polling requests only that view's
authorized dependencies; public and private branches can succeed independently.

Build the refresh dependency plan before private fan-out: resolve membership and
usable grant, fetch due self-role evidence when the target needs it, reevaluate
request eligibility, then fetch that capability and optional name enrichments.
Self-role refresh does not require a corporate read permit. An expired role lease
must not deadlock its own renewal; if renewal fails, the corporate payload remains
hidden. Explicit probe paths retain their separate policy. Fuel monitoring includes
these authorization dependencies, not just a structures request on a timer.

Claim the exact request key atomically in SQLite with a unique caller-generated
job token, live-lease predicate and `nextAttemptAt` test. Return that token from
the claim transaction, not by a later unconstrained reread. A live owner makes
other engines observe/wait, not start another request. Reserve due/rate state in
the same transaction. No SQL transaction spans HTTP. Proposed operational bounds:
30-second request timeout, 60-second job lease, heartbeat at most every 15 seconds;
renew only while still owner, and fence every staged/publication write. A crashed
owner's lease can expire; a late response cannot overwrite its replacement.
Bound response/body/record sizes through configured typed failures, never silently
truncate and publish as complete. Tests use injected clock/scheduler, not sleeps.

Use a logical dataset-job key (authority, endpoint, compatibility, query interval/
variant, but **no page/cursor**) held across the complete pagination and commit.
Subordinate page/cursor request/cache keys include method, normalized path/query,
page/cursor, compatibility, tenant and authority. They do not replace the parent
job's publication fence. Thus two engines cannot start separate full refresh rounds
by claiming different pages. Public keys contain no token. Coalesce token refresh
separately. Permit at most **two concurrent corporate reads per character**
across engines, not two per provider. Prioritize visible view and fuel-monitor work
over names/background history; public-history queue is capped at 50 entries with
concurrency≤2 inside the same applicable scheduler. Release reservations on all
terminal paths; failure backoff is durable. Window hide cancels its polling/queued
work but does not discard a main monitor's legitimate ownership of shared work.

Cross-window events are hints after commit. Add a shared revision observer that
rereads durable authority/snapshot revisions on startup, resume, visibility change
and a bounded lightweight visible-window poll (one second maximum interval for
missed local hints). Never rely on connection-local Drift watches to observe other
SQLite connections. Main monitor rereads revisions before every evaluation. All
private reads, publication and notification claims recheck authority regardless
of missed hints. Local selection/revocation removes the old view synchronously
before awaiting persistence; remote windows converge via the revision observer.
This bounds missed-event convergence; it is not a claim of zero-latency distributed
screen erasure. Suspend/hide drops private render models and resume rechecks before
rendering them.

### 3.6 Rate limiting and typed failure policy

Use shared authenticated buckets keyed by application, character and ESI rate group;
public requests have their explicit public bucket. Seed conservative registry
limits: corp-asset 1800 tokens/15m; corp-member, corp-structure, corp-wallet and
corp-detail 300/15m. Reconcile live `X-Ratelimit-*`, legacy error-limit headers and
Retry-After on **every** response, including failed ones. Budget documented response
costs (2xx: 2, 3xx: 1, most 4xx: 5, 5xx: 0) conservatively; absence of headers is not unlimited
capacity. Respect both group and legacy global restrictions. Do not evade a
deadline by switching tokens, windows or owners.
[Official rate policy](https://developers.eveonline.com/docs/services/esi/rate-limiting/).

| Failure/result | Durable action | Visible outcome |
|---|---|---|
| Missing actual scope/known required role | No request; invalidate affected ownership on confirmed loss | Specific locked capability with remedy; no protected counts/names |
| Endpoint 403 | Record capability denial, purge its payload/staging/derivatives; stop automatic probing | Permission denied, not empty data or connectivity error |
| Secondary private name 403 | Invalidate that name resource only | Generic resolved-type/location fallback; preserve independently authorized primary rows |
| 401 after permitted refresh/retry | Mark unusable grant, hide private data; require reauthorization | Authentication expired; no alternate-character retry |
| 420/429 | Persist Retry-After; if absent minimum 60s conservative exponential delay | Rate-limited with next attempt; manual refresh cannot bypass |
| Timeout/network/5xx | Keep accepted data if its permit remains valid; backoff 30/60/120/300s | Cached/error state and real source age; no lease extension |
| Schema/pagination/conflicting duplicate | Reject candidate, retain prior authorized complete state | Partial/failed refresh with diagnostics, not refreshed empty state |
| SQLite write/publication failure | Roll back all accepted metadata/payload changes | Refresh failed; no success snackbar/lease renewal |
| Lease expiry or stale required role evidence | Hide but retain compatible data | Connect/verify access; no stale private fallback |
| Confirmed departure/delete | Central scoped purge and generation invalidation | Public/new context only; late work rejected |

Use typed exceptions/results such as `MissingScope`, `RoleRequired`,
`CapabilityDenied`, `AuthenticationExpired`, `RateLimited`, `IncompletePages`,
`ConflictingRecord`, `InvalidPayload`, `PersistenceFailure` and `ContextChanged`.
Translate them once into domain state, not string matching in widgets. Logs carry
`[CORPORATION]` operation/capability/status/page count/duration/coverage and sanitized
failure codes; never private names, wallet reasons, amounts, item lists or tokens.

## 4. Domain services, Riverpod state and presentation

### 4.1 Provider graph and immutable view state

Add `data/corporation_providers.dart` with injected clock, transport, scheduler,
reference/rule loaders and native adapters. Reuse `databaseProvider` from
`lib/core/di/providers.dart`,
`esiClientProvider`, `sdeServiceProvider`, `allCharactersProvider` and
`activeCharacterProvider`; verify their installed signatures rather than adding a
second active-character store in the widget. Authority selection delegates to the
shared revision transaction. The authoritative provider graph is:

```text
active character + durable revision observer
  → corporationContextProvider (public membership + verified grant)
  → corporationAccessProvider(capability)
  → guarded repository snapshot providers
       ├─ profile + member set + separately guarded enrichments → roster VM
       ├─ assets + permitted private names + public SDE/prices → assets VM
       ├─ structures + optional assets + fuel rules/scenario → structures VM
       └─ balances + selected division history + names → wallets VM
  → corporationRefreshControllerProvider(view)
main engine only → corporationFuelMonitorProvider → alert claim/native adapter
```

| Provider / controller | Kind, inputs and responsibility |
|---|---|
| `corporationContextProvider` | Async notifier/stream composition over active owner, membership and grant; increments render generation immediately on selection intent. |
| `corporationAccessProvider(CapabilityKey)` | Pure derived `AccessDecision` with injected clock and durable revisions; schedules earliest expiry invalidation. |
| `corporationProfileProvider(corpId)` | Async public cache/repository stream, independent of SDE/private scopes. |
| `corporationRosterProvider(ContextKey)` | Async guarded member set; separate own-access, role, title, tracking and public-history provider dependencies with independent panel states. |
| `corporationAssetsProvider(ContextKey)` | Guarded accepted inventory; disposable immutable graph/search projection bound to snapshot and private-name authority. |
| `corporationStructuresProvider(ContextKey)` | Guarded status/expiry, without requiring assets or a fuel model. |
| `corporationFuelViewProvider(structureKey)` | Pure composition of independently available reported expiry, qualified inventory, rule-model result and saved/manual preview. |
| `corporationWalletBalancesProvider(ContextKey)` | Guarded seven-division availability with independently gated names. |
| `corporationWalletHistoryProvider(HistoryQuery)` | Async guarded division+kind+half-open interval/ref-type/item filters and explicit coverage; queries all matching cached rows, pages only presentation. |
| `corporationRefreshControllerProvider(ViewKey)` | Async notifier of `RefreshOutcome`; shared coordinator owns actual jobs/deadlines. Clears indicators in all terminal paths. |
| `corporationFuelScenarioControllerProvider(structureKey)` | Context-scoped draft/validation/preview, explicit save and cancel. No persistence on Calculate. |
| `corporationFuelMonitorProvider` | Main-engine lifecycle only, selected owner, explicit opt-in, due refresh and native permission adapter. |

Use full immutable context keys (owner incarnation/corp/grant/render generation),
not families keyed only by corporation or character ID. `autoDispose` cancels
view-local subscriptions and drafts; it must not delete durable cache or a request
owned by another subscriber. Never keep alive a private VM across authority loss.
Reset filters, selected asset/structure/division, pending dialogs, type-ahead names,
export/copy content and optimistic previews on context change. Async returns check
the captured generation before updating state. CPU workers return the same fence;
discard late trees, search results and decimal totals just like late HTTP.

`CorporationPanelState<T>` distinguishes locked/access reason, no cache, accepted
empty, populated (with coverage/source age), refreshing, partial and retained
failure. Outer `AsyncValue` remains explicitly handled:

```dart
// viewState is already guarded against the current authority fingerprint.
return viewState.when(
  skipLoadingOnReload: true,
  loading: () => const CorporationLoadingPanel(),
  error: (error, stack) => CorporationFailurePanel(error: error),
  data: (state) => CorporationPanel(state: state),
);
```

Retaining content on reload is allowed **only** within the same still-authorized
context. Set locked/pending synchronously outside that retained branch when the
permit expires or selection changes. Do not let Riverpod's previous `AsyncData`
or `skipLoadingOnRefresh` default render revoked content. Error snapshots carry
only already guarded data; generic `valueOrNull`, `requireValue`, `.value` or
`data ?? []` rendering is prohibited. Independent SDE/name `.when()` branches use
contextual unknown labels without hiding valid measurements or public profile.

### 4.2 Profile, roster and own-access derivation

`CorporationRosterService` intersects every enrichment with the accepted returned
member set; an enrichment row cannot add a member. Public profile count is separate
from “Roster: n returned members.” Tracking join date takes precedence when
authorized and valid; otherwise sort public employment records by exact record ID
descending and use the **latest record only if it matches the current corporation**.
Never search backward for an old matching employment episode. Future/invalid joins
are unavailable. Preserve source and observation age in the VM.

Batch public name resolution; schedule public history only for visible/requested
members, deduplicated, queue≤50/concurrency≤2 and daily TTL. No eager per-member
history fan-out for a large roster. Compute UTC activity filters using the injected
clock: a known nonfuture login with age≤7/30/90 days qualifies at equality; one
millisecond beyond does not. Missing/future evidence is Not reported/Unknown, never
Online, idle productivity or inferred logout. Denied tracking removes activity
columns/filters, not the member set.

Own-access VM separates General/HQ/Base/Other and grantable/assigned knowledge.
Its seven-division query/take/container-take/account-take matrix describes reported
roles using Yes / Not reported / Unknown; it is not an ACL test or transfer action.
Title name resolution cannot grant authority. Own standings is explicitly **My NPC
standings**, with resolved source names and signed values, not corporate standings.

### 4.3 Asset graph, names, search and exact valuation

Add pure `corporation_asset_graph.dart` and `corporation_asset_valuation.dart`.
Build an item map from one complete accepted snapshot. Preserve original parent
evidence separately from the safe display forest. Follow an item parent only when
raw `location_type == item` and that parent exists in the same snapshot; an equal
numeric station/system key is not item-parent evidence. Otherwise accept a proven external
station/structure/system root or classify unresolved. No numeric office-offset
arithmetic or assumption that assets list every rented office. Preserve deliveries,
asset safety and unassigned root classes from actual flag/location evidence.

Use iterative traversal with visited/path state, a 64-edge maximum and memoization.
Detect self-links/cycles/missing parents without recursion overflow. Each source
row has exactly one display/value identity, including unresolved rows; attach
diagnostic context rather than duplicating children beneath every encountered
root. A row's nearest explicit `CorpSAG1`…`CorpSAG7` on itself/its valid ancestry
sets division. A directly known division is not erased by a bad distant parent.
Place cyclic/self-linked or over 64-edge paths in Unresolved location while retaining
each row exactly once. Test item/external-location key collisions explicitly.
Resolve type/custom/container/location labels through scoped reference services;
custom/private names never enter global public name caches.

Search type/custom names and permitted path text within the selected accepted
snapshot. Return distinct `matchedItemKeys` and separate `contextAncestorKeys`.
Only matches contribute match count/value; ancestors provide navigation. F3
ammunition search yields 4 matches and 35.00, not container-inclusive totals. A
name-permission change invalidates search text, path labels and results, not just
the detail widget. Cache an indexed projection keyed by asset/name revisions;
compute large trees/search/aggregates off the UI thread and fence results.

Valuation is an exact fold over distinct goods rows. Office/admin rows contribute
neither goods count nor value; a physical container contributes its own value once
plus independently valued contents. Use exact quantity×**average** market price.
Unknown/negative quantity, missing type/price, BPC or unknown blueprint-copy state
on a blueprint is unpriced, never singleton 1, absolute quantity, BPO value or
adjusted-price fallback. Zero quantity and zero average price are valid. Sum before
rounding the displayed subtotal to two decimals, half away from zero. Preserve
unpriced counts and label the subtotal as qualified. Price age≥24h means Stale
prices independently of inventory/authorization clocks.

F3 oracle:11 source rows, one office excluded,10 goods rows,8 priced,2 unpriced;
100+25+40+500+50+5+2.5+2.5=725.00. Division 2=165.00; Division 1=550.00 plus an
unpriced BPC; unresolved priced goods total 10.00. Input permutations, cycles and
grouping cannot change global value/count conservation. Store a new exact public
price projection from raw ESI, not from legacy `MarketPrices` REAL values.

### 4.4 Structures, fuel rules and local scenarios

`CorporationStructureService` publishes status/services independently of assets.
Station Manager can see reported expiry without Director, inventory or a rule
manifest. Preserve missing versus empty services, online/offline/cleanup/unknown
states and future enums. State timer, reinforcement configuration and unanchor
are separate fields. A passed timer renders Awaiting updated state, not a locally
invented reinforcement, abandoned state, shutdown or collapse.

`CorporationFuelCalculator` has three independent result branches:

1. **Reported expiry:** absolute ESI timestamp and live countdown based on current
   clock, source age and stale badge. Severity: remaining>72h Normal; 24h<remaining
   ≤72h Low; 0<remaining≤24h Critical; remaining≤0 Reported expiry passed; absent
   Unknown. Sort passed/Critical/Low/Normal/Unknown, earliest expiry, folded name,
   then stable internal identity. Severity does not prove current fuel quantity.
2. **Observed bay:** only complete authorized asset rows directly located at the
   owned structure with `StructureFuel` qualify. Sum integer quantities for fuel
   blocks 4051/4246/4247/4312, preserving per-type totals. Other resources, e.g. ozone,
   remain separate. Exclude hangar reserve, ship fuel and nested containers. No
   qualifying row means unavailable, not zero; unknown qualifying quantity prevents
   a complete total. Inventory uses its own observation clock and permission.
3. **Modeled/scenario consumption:** exact supported consumer rates and assumptions
   or Not modeled; user-entered scenario is explicitly local, not a reported fit.
   Never substitute it for the reported expiry or trigger alerts from it.

#### Fuel reference manifest and evidence gate

Current SDE import lacks the required structure/service dogma and complete modifier
scope. C0/C5 add a versioned artifact such as
`assets/data/corporation_fuel_rules.v1.json` plus a reproducible generator/validator
under `tools/` and its review evidence. Record CCP SDE build 3503375, input checksums,
type/group/attribute/effect IDs, published flags, scope filters, startup resource
requirements and exact arithmetic. Do not change SDE 7 or query live dogma to fill
unknown model fields. The source artifact is static reference, not copied private
fit evidence. Register the asset in `pubspec.yaml`.

Minimum supported ordinary service family: Manufacturing 35878, Invention 35886 and
Research 35891, each base 12 blocks/hour and 864 startup blocks; the Raitaru/Azbel/
Sotiyo engineering-complex effect 6759 applies−25% to service group 1415, yielding 9/h
per online instance. Model all three modules across the three hulls **once source
and wire mappings are proven**. Preserve attribute 2108 group,2109 hourly and 2110
startup; startup is separate, not recurring hourly consumption. Do not apply a
bonus to unrelated groups. Refineries' group 1322 bonuses are not a universal
structure multiplier. Reactors 45537–45539 at 15/h with 864 startup disprove a fixed
“hourly×72” startup formula; Metenox 82941's unpublished 5/h/1000 startup and extra
reagents must not imply ordinary supported all-resource uptime.

ESI reports service labels, **not fitted module type IDs**. Prove a complete set of
fitted consumer instances from complete authorized direct `ServiceSlot0`…`7` asset
rows plus a reviewed exact ESI service-label bundle→module mapping. Count each
module instance once: multiple ESI service rows can describe one Research Lab.
Reject duplicate slots/ambiguous instances, missing consumer evidence, unsupported
labels, cleanup/unknown states or incomplete mappings as Not modeled. Offline
instances contribute zero only when their identity/state is proven. Explicit
empty service evidence is not interchangeable with missing services.

The exact wire-label mapping is an **implementation evidence gate**, not established
by simplified F4 records or SDE module display names. C0 must supply pinned wire
fixtures and C5 a reviewed mapping/source ledger before claiming model support;
do not guess strings or silently ship an always-Not-modeled minimum family. If
proof cannot be obtained, escalate the release blocker to Product; reported expiry,
bay inventory and manual scenarios remain independently implementable.

#### Exact arithmetic and observation compatibility

Rate is the exact sum of supported online module rates after applicable scoped
bonuses, not an average. Daily rate=24R; stock duration=Q/R as an exact rational.
R=0 gives No modeled consumption and null horizon; Q=0 with positive R gives 0.
Floor duration for displayed whole minutes, round days to two decimals half away
from zero; never repeatedly round intermediate rates. F4: Q1440 and R18/h yield
432/day,80h,3.33days; manual R20/h yields 480/day,72h,3.00days. ESI expiry is 216000s
from T0,60h,2.50days. Advancing clock one hour changes the ESI countdown, **not**
the dated 80h stock endurance into 79h or a new 80h from now.

Combine modeled rate and observed quantity only when both are fresh, authorized,
complete and validated in the same completed refresh round; use source instants
Last-Modified else Date, require both present and skew≤5 minutes, and bind the
consumer digest/structure identity. Request-receipt coincidence alone is not
source compatibility. A compatible all-source 304 round can validate the same
observations while preserving original captions/timestamps. A changed rate with
old incompatible quantity yields no combined endurance, even if each standalone
field is displayable. Rate may be available without quantity. Manual scenario
inputs remain separately labeled, never fused into a false observed-bay claim.

`FuelScenarioDraft` accepts integer quantity 0…10^12 and finite decimal rate 0…10^9
with at most six decimal places. Reject negative/blank/NaN/overflow/excess precision;
parse decimal text exactly. Calculate changes preview only. Save is an explicit
owned SQL mutation after current structures-authority checks. Capture the expected
saved revision and use CAS (including the no-existing-row case); a conflicting save
reloads/reports conflict rather than overwriting another window. Reserve Save
synchronously, disable repeated Save/Cancel/Escape/barrier dismissal until its
transaction resolves, and recheck context/authority immediately before commit.
Outside that committed-save operation, Cancel restores the prior saved scenario
(F4 prior 20/h survives). A context switch hides/discards the dialog immediately;
its late completion cannot update the new UI, and a precommit authority mismatch
rejects the write. No ESI mutation, asset edit or status rewrite.

### 4.5 Fuel alerts and main-engine lifecycle

`CorporationFuelAlertReducer` is pure; the repository serializes state transitions.
Only a fresh complete authorized structure observation for the selected owner can
create a new critical episode. First fresh remaining≤24h opens an episode; ongoing
23→22→0, acknowledgement, expiry correction within critical and restart do not
rearm. A fresh observation above 24h rearms; a later≤24h starts a new episode.
Unknown expiry does not rearm; removed structure closes presence, and a newly
reported structure can begin a new episode. F4 sequence 23→22→0→48→24 creates two.
An episode UUID/ordinal is durable, not the expiry timestamp as a deduplication key.

The reducer also accepts `ClockTick(now)`: an armed observation can cross into
critical between HTTP payloads while its complete snapshot remains fresh and
authorized. Only a fresh validated observation above 24h rearms, not an arbitrary
clock correction. Schedule the next displayed-minute boundary, expiry−72h,
expiry−24h, expiry, source freshness boundary and access expiry as applicable;
resynchronize on resume. Evaluate access/freshness loss before a coincident threshold
crossing. Test a 25h observation reaching 24h with intervening successful validation,
and the same crossing without renewal when the one-hour lease expires: delivery
in the former only. A countdown tick does not renew evidence.

C5 mounts one `CorporationFuelMonitor` in `lib/app.dart` beside existing main-only
monitor services. Subwindows subscribe to alert state but never install competing
background/native timers. Fresh structure publication and authorized visible
countdown crossings submit in-app assessment to the durable reducer even when
native monitoring is off; in-app acknowledgement does not require opt-in. Serialize
those assessments in the repository. Opt-in gates background HTTP and native
handoff, not visibility of an in-app critical episode. The main coordinator observes
durable selection/opt-in revisions even when the main window is hidden, using
lightweight revision polling when hints are missed. Explicit opt-in is per selected
character; hidden window permits due
monitoring only while the main app is running. No launch agent or closed-app
guarantee. Hide stops ordinary view polling. Suspend/resume runs context/access/
freshness checks and due refresh **before** evaluating an overdue alert. Unselected,
stale, denied, deleted or expired-lease data cannot emit a new alert; in-app dated
severity can remain only where ordinary read authorization permits it.

`CorporationNotificationAdapter` exposes permission query/request, delivery and
click stream. Implement macOS permission access through a focused
`UNUserNotificationCenter` channel in `macos/Runner/`; existing `local_notifier`
has no adequate permission API. A fake adapter records calls and emits callbacks
in tests; native smoke tests verify the actual path. Ask permission only on opt-in.
Denied permission leaves in-app severity/acknowledgement and the exact Product
feedback, without a repeated prompt loop.

In one transaction recheck authority/selected context/freshness and claim a unique
episode handoff. Emit generic Product §6.6 title/body, never private structure names
or amounts. Click carries an opaque episode token; resolve it through current
authority before opening/focusing Window 15 and revealing any detail. Permission
denial before a claim is not a delivery. Record adapter outcome separately.

**Delivery limit:** SQLite can guarantee one native handoff claim per episode
across processes/restarts, not exactly-once OS delivery across an arbitrary crash
between commit and the OS call. Choose at-most-once automatic handoff: do not replay
an ambiguous claimed episode after a crash. Native APIs have no transactional
acknowledgement with SQLite. P13 proves one call in ordinary/racing/restart paths
and explicitly tests this crash boundary; in-app state remains recoverable. Do not
market native delivery as guaranteed. Product's one-per-episode rule means no
duplicate handoffs, with this unavoidable operational limitation recorded at release.

### 4.6 Wallet accounting and history

`CorporationWalletService` validates division IDs 1–7 and exact signed balances.
Identical duplicate division rows coalesce; conflicting/invalid/out-of-range rows
fail the candidate balance snapshot. Stable seven-position VM distinguishes known
zero, negative, missing and denied. Custom names are separately gated; fallback
Division n does not require Director. F5 complete total 1500.00; missing division 7
yields qualified subtotal 1200.00 (6/7), not a complete total or zero-valued seventh.

`CorporationWalletCalculator` filters every matching cached journal row in the
selected division and half-open UTC interval `[start, end)`, with optional reference
type. Sum positive known amounts as inflow; absolute negative amounts as outflow;
net=inflow−outflow. Null amount contributes an unknown count, not 0. Null running
balance remains unknown. Sort date descending then exact journal ID descending.
Current balance comes only from the balances endpoint, never filtered history.
F5 order 106,105,104,103,102,101 gives 100.40 inflow,35.40 outflow,65.00 net and one
unknown amount; next-day row 107 is excluded. Rendering one page cannot limit totals.

Trades retain Buy/Sell and exact integer quantity×unit price. F5 3×1.005=3.015,
display 3.02, versus 2×10=20.00; round final display only. Link a journal reference
only to an actual retained row in the same owner/corporation/division; sentinel−1,
missing or unavailable link remains a descriptive no-link state without IDs.
Trades are not added again to journal cash flow. Use cursor rules from §3.4; F5
`[900,899] → [899,898] → []` produces three unique trades with from_id 899 then 898.

Coverage VM distinguishes requested dates, upstream window, validated segments,
retained bounds/gaps, partial fetch, unknown amounts and Load older availability.
Do not promise that 365-day retained history is refetchable from ESI's journal
window. Switching division/kind creates independent queries; a denied division
cannot clear or stand in for another, and corporate keys never collide with
personal wallet IDs/storage.

### 4.7 Window, tray and actual host integration

C7 appends `WindowType.corporation` with serialized ID 15 across every window switch,
title/icon/default size and tray entry. Preserve IDs 0–14, serialization round trips
and concurrent open/focus coalescing. Hide retains the existing engine/controller;
destroy removes it only after actual destruction. Fix the Corporation close path
so remove-then-hide cannot create duplicate hidden windows on reopen.

`SubWindowApp._buildScreen` builds `CorporationScreen`; extend
`waitsForGlobalSde`/`_SubWindowScaffold` so public corporation content and permission
states do not wait for global SDE. SDE-dependent rows handle their own loading/error
states. Use `WindowPlatformAdapter` for tests; keep the actual SubWindowApp tree.
Connect the real native window visibility bridge, including initial visibility;
app activation/unhide is not proof that every individual window is visible.
Do not reuse Exploration's constant visibility/provider placeholders.

Add an actual `CorporationCharacterSelector` consuming existing character providers
and central selection intent. Desktop may adapt the existing character rail but
must fix 48px targets, semantics and keyboard behavior on the used path. Compact
selector has a working `onSelected`; no decorative “Chars” control. Reserve the
character rail once, then choose module layout from **usable** content width:

| Usable width | Navigation and content |
|---|---|
| <600px | Four-item NavigationBar (or accessible TabBar), stacked cards, full-width detail routes; selector separate. |
| 600–1099px | NavigationRail with compact list, detail sheet and wrapping filters. |
| ≥1100px | NavigationRail with list/table and detail panes; asset tree/list/detail only if each remains usable. |

Do not force the desktop native minimum size onto widget tests; use constrained
surfaces for 320px-equivalent screenshots where needed. All four destinations remain
reachable before private access, during errors and without SDE.

### 4.8 Widget composition and accessibility

```text
CorporationScreen
  CorporationCharacterSelector + CorporationContextHeader
  CorporationAdaptiveNavigation
  CorporationViewScaffold (AppBar Refresh + always-scrollable RefreshIndicator)
    OverviewRosterView
      CorporationProfileCard / MyAccessCard / MyNpcStandingsCard
      CorporationRosterList → MemberDetailSheet
    CorporationAssetsView
      AssetCoverageHeader / AssetFilterBar / AssetLocationTree
      CorporationAssetList → AssetDetailSheet
    CorporationStructuresView
      StructureFilterBar / StructureStatusList → StructureDetail
      ReportedExpiryCard / ObservedFuelBayCard / FuelModelCard
      FuelScenarioEditor / FuelAlertControls
    CorporationWalletsView
      DivisionBalanceSelector / WalletCoverageHeader
      JournalView | TransactionsView → WalletEntryDetail
```

Shared `CapabilityPanel`, `DatasetFreshnessLine`, `CoverageBadge`,
`CorporationErrorPanel`, `ResolvedEntityLabel` and `ExactAmountText` render VMs only.
Reuse CorporationLogo, CharacterAvatar and EveTypeIcon. Use `itemNameProvider`/
`locationNameProvider` or batched SDE-backed equivalents for public type/location
names; private structure/custom names must use the scoped name repository rather
than a globally caching resolver. Never display raw IDs in text, tooltips, copied
content, accessibility labels, rich-text markup, error messages or native alerts.
Unknown type/location/party labels preserve valid measurements. Parse/sanitize
descriptions into safe plain text and recognized links; do not render raw showinfo
IDs or launch arbitrary URL schemes. “No alliance” requires actual absence, not a
failed alliance-name lookup.

Use Product §6.2–6.6 as the canonical layout/copy/state contract; do not maintain
a competing copy catalog in this design. Keep reported status/expiry/bay/model
sections and their timestamps separate. Wallet Journal/Transactions are subtabs,
not fifth/sixth module destinations. Initial wallet selection Division 1/last 30 days
is context-local. Expose no transfer/refuel/purchase/management action.

Every view uses an always-scrollable body, including locked/empty/short/error states,
so both refresh gestures work. All indicators finish on cooldown/lock/cancel/error.
Use virtualized lists, wrapping chips/labels, and locally scrollable filters instead
of a horizontally overflowing page/DataTable. At 320/600/900/1200px, both 100%/200%
text scale and 640px height, test 80-character names and
−1234567890123456.78 ISK without clipping critical values. Amounts may occupy their
own line. Touch targets≥48px, visible focus, keyboard traversal character→navigation
→filters→content→actions, screen-reader names and text+icon severity are mandatory.
Apply the same rules to scenario dialogs, sheets, empty and loading states.

## 5. Work units C0–C10 and TDD execution contract

### 5.1 Ownership and ordering

Plan assigns a named Test-Author, Dev, Reviewer and Tester to each unit before work.
Test-Author writes real-boundary RED tests and independent constants; Dev implements
the smallest passing change; Reviewer verifies contracts, production wiring and
red/green evidence; Tester reruns assigned cases and captures runtime/native evidence.
An interface-only compile failure is not sufficient RED once the harness exists:
demonstrate the missing behavior against the real service/provider/host. Tests must
not replace the thing they claim to test with a ready-made successful VM.

Paths below are proposed unless already identified in §1.3. `corp/` abbreviates
`lib/features/corporation/`; `tests/` here means
`test/features/corporation/`, not a new top-level test convention. Shared files have
one owner even when multiple units depend on them. C1 owns AppDatabase/table and
generated schema changes; C2 owns auth/EsiClient/character publication and core
revision authority; C5 owns fuel reference/native notification/app monitor changes;
C7 owns window/tray/selector/visibility host wiring. Coordinate a small sequential
handoff for `lib/app.dart` between C5's monitor and C7's host lifecycle, never overwrite
each other's edits. C8/C9 own only their view/domain composition seams after review.

```text
C0 → C1 → C2 → C3 → C8 ─┐
             ├→ C4 → C8 ┤
             ├→ C4 → C5 → C9 ─→ C10
             ├→ C6 ─────→ C9 ┤
             └→ C7 → C8/C9 ──┘
```

C3/C4/C6/C7 can proceed in parallel after C2's reviewed interfaces. C5 reported
status/scenario/reducer work can start after C2; its observed inventory/model
integration depends on C4 and proven C0 manifest fixtures. C8/C9 can build static
components against immutable contracts, but cannot declare GREEN integration
before the real C7 host and corresponding repositories are wired. C10 is sequential
after all unit gates, not a parallel paperwork substitute.

### 5.2 Unit specifications

| Unit | Owned changes and responsibility | Dependencies | RED → GREEN evidence |
|---|---|---|---|
| **C0 — Contracts, fixtures and harness** | `corp/domain/corporation_{context,access,snapshot,decimal}.dart`; feature fixture builders/raw JSON/header transcripts under `test/fixtures/corporation/`; `tests/support/{corporation_test_harness,recording_esi_transport,fake_corporation_clock}.dart`; reference source ledger and fuel manifest schema. Define typed interfaces, context fences and F1–F8. | Product and this design | RED: precision, permission, unknown-field and oracle tests fail for naive/default behavior. GREEN: immutable value contracts/decoders and deterministic harness work; every fixture distinguishes wire payload from simplified domain data. Future service tests remain intentionally RED until their unit. Do not declare all 60 passing here. |
| **C1 — Database 22** | `corp/data/corporation_tables.dart`, core authority/lease tables, `lib/core/database/app_database.dart` and generated code; migration fixtures/tests; central scoped delete/selection/publication transactions. | C0 | RED: v21 upgrade cannot read new tables; injected migration failure/two-connection race/delete-readd exposes atomicity defects. GREEN: fresh 22 and supported upgrades preserve sentinel data, rollback/reopen works, unique/index constraints and ownership cleanup hold, no migrated grant is implicitly authorized. |
| **C2 — Repositories and role-aware ESI caching** | `corp/data/{corporation_esi_api,corporation_endpoint_registry,corporation_authorization_repository,corporation_refresh_coordinator,corporation_page_assembler,corporation_providers}.dart`; raw decoder/shared scheduler/revision observer; scoped edits to OAuthService/AuthController/PendingAuthStore/TokenManager/EsiClient/CharacterRepository. Profile/self-access/name/price/public-history repository foundations. | C0,C1 | RED: actual request assertions catch wrong scope/role/version, 403 fallback, first-fetch deadlock, page 1-only304, duplicate engines, wrong-subject/cancelled auth, stale token writes and lossy numbers. GREEN: every required endpoint has a registered real path test; all fences/clocks/deadlines/typed errors work through actual SQL and raw transport. |
| **C3 — Member tracking and roster** | `corp/domain/corporation_roster.dart`, `corp/data/corporation_roster_service.dart`, bounded public history loader and roster provider composition. | C2 | RED: old employment match, unmatched member enrichment, future login, title-as-role and eager history fan-out fail. GREEN: F2 exact dates, membership conservation, independently locked enrichments, activity boundaries and own-access projection. |
| **C4 — Assets and hangars** | `corp/domain/corporation_{asset,asset_graph,asset_valuation}.dart`, `corp/data/corporation_asset_service.dart`, scoped private-name and exact-price repositories, worker/search projection. | C2 | RED: mixed pages, cycles/deep paths, double-counted ancestors, private name leak and binary decimal drift fail. GREEN: F3 row/count/value/search conservation, named usable fallback, complete publication and authorized fast queries. |
| **C5 — Structures, fuel and alerts** | `corp/domain/corporation_{structure,fuel,fuel_calculator,fuel_alert}.dart`; structure/fuel-rule/scenario/alert repositories and services; versioned fuel asset+generator/source ledger; notification adapter/native channel; main monitor in `lib/app.dart`. | C2,C4; C0 rule/wire evidence | RED: Station Manager blocked by assets, invented service consumer, reserve fuel counted, stale Q/R reset, duplicate/corrected-expiry alerts, denied native permission and save-on-Calculate fail. GREEN: F4 exact arithmetic/boundaries, proven minimum model family, independent provenance, scoped save/cancel, durable episodes and actual native adapter. Missing rule/label evidence blocks model completion. |
| **C6 — Wallets and journals** | `corp/domain/corporation_{wallet,wallet_calculator,history_coverage}.dart`; `corp/data/corporation_wallet_service.dart` and repositories/providers for balances, journal and cursor trades. | C2 | RED: missing balance coerced to 0, float gross, rendered-page totals, cursor loop and cross-division overwrite fail. GREEN: F5 exact money/null/coverage/link/order results, seven-division isolation, paging/pruning and history continuation. |
| **C7 — Dedicated window and tray** | WindowType 15 and all relevant switches, WindowService/visibility bridge/SubWindowApp/TrayService, `corp/presentation/{corporation_screen,corporation_character_selector,corporation_adaptive_navigation}.dart`; real active-character selection. | C2 | RED: unregistered ID, concurrent duplicate, remove-then-hide reopen, blocked SDE host, decorative selector and hidden-window polling fail. GREEN: actual host/tray focus/hide/reopen, prior IDs, durable switch/reset and measured visibility lifecycle all work. |
| **C8 — Overview, roster and assets UI** | `corp/presentation/views/{overview_roster_view,corporation_assets_view}.dart` plus profile/access/roster/tree/search/detail widgets and shared guarded panels/amount/name/freshness components. | C3,C4,C7 | RED: wrong tax/counts, missing/locked-as-empty, ID leakage, absent refresh affordance and narrow overflow fail. GREEN: U02–U05 and shared U10–U12 variants use actual services/host, named states and F8 accessibility. Shared widgets are handed off to C9 rather than duplicated. |
| **C9 — Structures, alerts and wallets UI** | `corp/presentation/views/{corporation_structures_view,corporation_wallets_view}.dart`, status/fuel/editor/alert/division/ledger/coverage widgets; provider composition to existing service contracts. | C5,C6,C7,C8 shared widgets | RED: scenario overwrites expiry, hidden alerts, wrong money/coverage and inaccessible dialogs fail. GREEN: U06–U10/U12 states, full F8 matrix, exact feedback and no management controls. |
| **C10 — Release evidence and closeout** | Test execution records, raw benchmark summaries, native/responsive screenshot checklist under `docs/verification/corporation-module/`; README and engineering journal/queue; architecture deviations and final coverage ledger. No new feature logic hidden here. | C0–C9 | RED: any unmapped/failing Product case, missing native evidence, unproven fuel mapping or unmet performance budget blocks release. GREEN: all 60 cases/AC40, analysis/regressions, full-size benchmarks, privacy/permission/offline/native runs and reviewer sign-off recorded. |

### 5.3 Exit criteria and change control

Each unit records exact test command, failing assertion before implementation,
passing result after, fixture/version and reviewed production path. Generated Drift
code belongs with the schema change. Pure formulas require independent constants
and permutation/boundary tests; duplicating the production formula in an “oracle”
is not independent. Patch tests first if a seam is found to bypass SQL/auth/host.

No unit may silently narrow Product cases, increase private lease duration, relax
all-page validation or replace a minimum supported fuel model with a blanket
fallback. Record a decision and seek Product direction for material scope changes.
C10 closes implementation only after executable evidence, not because this document
has complete tables. Review architecture after each shared-auth/database/native
change before parallel dependents consume it.

## 6. Test architecture and complete traceability

### 6.1 Harness design and independent oracles

`CorporationTestHarness` owns resources explicitly. Use real AppDatabase and
repositories, the actual EsiClient/OAuth coordinator with recording HTTP transport,
frozen clock, real Riverpod composition and actual `SubWindowApp(WindowType.corporation)`.
Override boundaries in an **outer** `ProviderScope`; do not add an unrelated nested
container inside the host. Existing TestApp is convenient for small widgets but
owns an in-memory DB and is not an unchanged restart/two-engine harness. Reuse its
theme/localization conventions, not its lifecycle assumptions.

Override database/SDE handles, Dio HTTP adapter or the new raw transport seam,
clock/scheduler, public reference source, fuel artifact loader, window/native
notification/browser/SSO callback adapters. Do **not** override guarded providers
with unconditional `AsyncData`, bypass corporate repositories,
or mock endpoint methods that skip headers/parsing/storage. Each fixture grant is
seeded through the same verified-grant persistence boundary with an explicitly
trusted test validator; separate auth tests exercise actual JWT validation using
synthetic signing keys/discovery fixtures. No live token, account or corporate data.

Use in-memory SQLite for isolated repository tests; temporary on-disk SQLite with
two independent AppDatabase instances/ProviderContainers for races, migration and
restart. Real separate connections are mandatory; two widgets sharing one DAO do
not prove cross-engine correctness. Pause transport before/after parse, token
refresh, staging and publication; then switch/revoke/delete/re-add/reauthorize,
release the old worker and assert both SQL and rendered state. Suppress event hints
to prove revision recovery. Reopen after lease expiry and migration failure.

F1–F8 stay canonical in Product §8. Define shared fixture data, not shared expected
calculators: F1 scope/role matrix; F2 profile/roster; F3 hierarchy/value; F4 structure/
fuel/alerts; F5 wallet; F6 HTTP/time; F7 lifecycle; F8 responsive. Wire fixtures include
all required pinned-schema fields and real header/status variants. Endpoint registry
coverage asserts every §3.1 endpoint's method/path/tenant/compatibility/scope/role/
TTL and persistence behavior, including self capabilities for NPC members.

Teardown disposes ProviderContainers/widgets, clock timers, isolates/subscriptions,
native streams, both DB connections and temporary directories after completion.
An external resource's lifecycle is not delegated to an auto-disposed widget.
Capture uncaught Flutter errors and leaked timers as failures. UI tests assert
text **and semantics/tooltips/copy payloads**, not just absence of overflow logs.

### 6.2 T01–T60: exact Product aliases, implementation units and test files

All paths below are relative to `test/features/corporation/` unless marked otherwise.
The first listed unit owns the test contract; later units supply integrated behavior.
Case descriptions summarize, not replace, every parameterized variant in Product
§8. D/P/U/O numbers and AC associations are preserved exactly. Additional tests use
suffixes, e.g. P04.tokenRace; never renumber or replace a Product case.

| T / Product case | Units | Test file | Strategy and exact critical assertion | ACs |
|---|---|---|---|---|
| T01 / D01 | C0,C2 | `domain/access_policy_test.dart` | Pure F1 all nine scope/role rows; requested-only scope ineligible. | AC3, AC8 |
| T02 / D02 | C0,C2 | `domain/role_evidence_test.dart` | HQ Director/account-take/title confer no general privilege; assigned/grantable separate. | AC4, AC13 |
| T03 / D03 | C0,C2 | `domain/access_lease_test.dart` | Expiry−1ms/equality/denial = allow/lock/lock; reads cannot renew. | AC5, AC6 |
| T04 / D04 | C2 | `domain/profile_adapter_test.dart` | Current 10/current 0.10/legacy 0.10 →10%/0.1%/10%; optional stays absent. | AC9 |
| T05 / D05 | C3 | `domain/roster_derivation_test.dart` | F2 September 1/unavailable/September 2; unmatched 99 not a member. | AC10, AC11 |
| T06 / D06 | C3 | `domain/activity_filter_test.dart` | Exact 7/30/90-day UTC boundaries, future/missing unknown; no online claim. | AC12 |
| T07 / D07 | C4 | `domain/asset_graph_test.dart` | F3 exact parents/divisions/names; no invented office enumeration. | AC15 |
| T08 / D08 | C4 | `domain/asset_graph_test.dart` | Cycle/self/orphan/65-edge input terminates; each row once. | AC16 |
| T09 / D09 | C4 | `domain/asset_valuation_test.dart` | F3 subtotal 725.00; BPC/unknown/negative unpriced, zero valid. | AC17 |
| T10 / D10 | C4 | `domain/asset_search_test.dart` | Four ammunition matches 35.00; ancestors context-only. | AC18 |
| T11 / D11 | C5,C4 | `domain/fuel_inventory_test.dart` | Direct fuel 1440; ozone separate; reserve/nested absent from sum. | AC21 |
| T12 / D12 | C5,C0 | `domain/fuel_model_test.dart` | Two proven consumers 18/h; unsupported/ambiguous Not modeled; scoped bonus only. | AC19, AC22 |
| T13 / D13 | C5 | `domain/fuel_scenario_test.dart` | Exact input limits/precision; zero rate null horizon; no write. | AC22, AC23 |
| T14 / D14 | C5 | `domain/fuel_severity_test.dart` | Exact 72h/24h/0 = Low/Critical/Passed; absent Unknown. | AC24 |
| T15 / D15 | C5 | `domain/fuel_alert_reducer_test.dart` | 23→22→0→48→24 makes two episodes; ack/correction no rearm. | AC25 |
| T16 / D16 | C6 | `domain/wallet_balance_test.dart` | Zero/negative/missing distinct;6/7 qualified subtotal. | AC27 |
| T17 / D17 | C6 | `domain/wallet_journal_test.dart` | Six half-open rows, exact ID tie-break, one unknown amount. | AC28, AC30 |
| T18 / D18 | C6 | `domain/wallet_transaction_test.dart` | Exact gross, sentinel−1/no same-division link; no cash duplication. | AC29, AC30 |
| T19 / D19 | C2 | `domain/http_policy_test.dart` | F6 due 12:58, later shared deadline wins, cursor progress required. | AC33, AC34 |
| T20 / D20 | C0,C2 | `domain/payload_and_label_test.dart` | Future enums retained; invalid required payload rejected; unsafe markup/ID labels sanitized. | AC35, AC38 |
| T21 / P01 | C2 | `data/profile_and_self_endpoints_test.dart` | Real public/name/history/self-role/title/standings requests; pinned headers/scopes/TTL/optional CEO. | AC9, AC13, AC33 |
| T22 / P02 | C3,C2 | `data/roster_endpoints_test.dart` | F1 roster/roles/tracking/titles/divisions wire gates; denied enrichments leave member set. | AC3, AC4, AC10, AC11 |
| T23 / P03 | C2 | `data/access_probe_test.dart` | Grantable/CEO 200/403, hourly/new-grant bound and endpoint-only success; expired lease hidden during due check. | AC4, AC5 |
| T24 / P04 | C2 | `data/corporation_reauthorization_test.dart` | Actual grants, cancel/wrong subject/partial scopes, refresh generation, quarantine/rebind through SQL. | AC8 |
| T25 / P05 | C2 | `data/corporation_context_test.dart` | None/0/NPC/closed/member; no corp 0 request, transient 0 no purge. | AC2, AC8 |
| T26 / P06 | C2,C1 | `data/context_race_test.dart` | Switch/departure during await; late publication rejected and other owner preserved. | AC7 |
| T27 / P07 | C2 | `data/offline_access_test.dart` | Actual restart at lease−1ms/equality/stale roles; public stale remains readable. | AC6 |
| T28 / P08 | C2,C4 | `data/authorization_failure_test.dart` | 401 one coordinated refresh/retry; definitive/network failure distinct;403 scoped purge/name-only denial. | AC5, AC7, AC18 |
| T29 / P09 | C2,C4,C5 | `data/paged_snapshot_test.dart` | Page 2 failure/mixed generation/conflicts/missing X-Pages/complete empty via raw transport + SQL. | AC14, AC19, AC33 |
| T30 / P10 | C4,C2 | `data/private_name_test.dart` |1001 names → two POSTs; no private global-cache leak or raw fallback IDs. | AC18, AC35 |
| T31 / P11 | C5,C4 | `data/structure_permissions_test.dart` | Station Manager expiry without assets request; Director bay uses separate source clock. | AC19, AC21 |
| T32 / P12 | C5 | `data/fuel_scenario_repository_test.dart` | Calculate/Cancel/Save, owner fence and incompatible changed observations; static dated Q/R. | AC22, AC23 |
| T33 / P13 | C5,C1 | `data/fuel_alert_delivery_test.dart` | Two connections/engines, ack/restart/rearm/denial; one handoff, explicit crash gap. | AC25, AC26 |
| T34 / P14 | C5,C7 | `data/fuel_monitor_lifecycle_test.dart` | Hidden/resume/quit/switch/opt-in; only legitimate monitor runs, refresh before overdue evaluation. | AC26, AC32 |
| T35 / P15 | C6,C2 | `data/wallet_balance_repository_test.dart` | Seven rows, denied names, malformed/conflicting division and selected-history failure isolation. | AC27, AC31 |
| T36 / P16 | C6 | `data/wallet_journal_repository_test.dart` | Two pages/null/duplicates,30-day refresh/365-day prune with retained gaps and no synthetic balance. | AC28, AC30, AC31 |
| T37 / P17 | C6,C2 | `data/wallet_cursor_repository_test.dart` | F5 three unique trades; loop/mid-chain error remains incomplete, no false coverage. | AC29, AC31 |
| T38 / P18 | C2,C1 | `data/refresh_coordination_test.dart` | Two DB engines/concurrent gestures; all-page 304, failed commit,420/429/timeout and no false lease. | AC32, AC33, AC34 |
| T39 / P19 | C1,C2,C7 | `data/migration_and_cleanup_test.dart` | Real 21→22/fresh DB, closed-window delete, missed event, delayed worker/delete-readd; sentinels preserved. | AC7, AC38 |
| T40 / P20 | C10,C4,C2 | `performance/corporation_assets_benchmark_test.dart` |100000 rows, recorded machine p95 budgets, bounded paging/query counts and redacted tagged logs. | AC34, AC38, AC39 |
| T41 / U01 | C7 | `presentation/corporation_window_test.dart` | Actual SubWindowApp/tray/Window 15 open/focus/hide/reopen; prior IDs and SDE-failed public screen. | AC1, AC9, AC35 |
| T42 / U02 | C8,C7,C2 | `presentation/corporation_context_ui_test.dart` | F8 distinct contexts/locks/exact copy and eligible actions; no hidden private counts. | AC2, AC3, AC5 |
| T43 / U03 | C7,C8,C2 | `presentation/corporation_character_switch_test.dart` | Actual selector during await, no old frame, filters reset, auth cancel preserves session. | AC7, AC8, AC36 |
| T44 / U04 | C8,C3 | `presentation/overview_roster_view_test.dart` | F2 names/tax 10%+5.6%/dates/activity/locks/access matrix/personal standings. | AC9, AC10, AC11, AC12, AC13 |
| T45 / U05 | C8,C4 | `presentation/corporation_assets_view_test.dart` | F3 states/breadcrumb/icons,725.00/two unpriced/four matches through real providers. | AC15, AC16, AC17, AC18 |
| T46 / U06 | C9,C5 | `presentation/corporation_structures_view_test.dart` | Station Manager 60h expiry/no bay; elapsed timer label and cleanup/missing distinction. | AC19, AC20, AC21, AC24 |
| T47 / U07 | C9,C5 | `presentation/fuel_scenario_editor_test.dart` | Invalid/zero/cancel/save exact feedback; dated 72h alongside reported 60h. | AC22, AC23, AC37 |
| T48 / U08 | C9,C5,C2 | `presentation/fuel_alert_controls_test.dart` | Ack/opt-in/denied/stale/expired lease; generic native text and no locked detail/new alerts. | AC6, AC25, AC26 |
| T49 / U09 | C9,C6 | `presentation/corporation_wallets_view_test.dart` | F5 complete 1500/6-of-7 subtotal, signed/null/trade/coverage/Load older; no transfers. | AC27, AC28, AC29, AC30, AC31 |
| T50 / U10 | C8,C9,C2 | `presentation/corporation_refresh_ui_test.dart` | Both gestures/all four views/all states; actual coalescing/outcomes/copy and finished indicators. | AC32, AC33, AC34, AC37 |
| T51 / U11 | C10,C7,C8,C9 | `presentation/corporation_responsive_test.dart` | Full F8 width/text/state/dialog/long-value matrix; keyboard/semantics/non-color 48px targets. | AC35, AC36, AC37 |
| T52 / U12 | C8,C9,C2 | `presentation/corporation_async_privacy_test.dart` | Real loading→error→data/name/SDE/permission races and markup; no retained unauthorized frame. | AC5, AC6, AC35, AC38 |
| T53 / O01 | C0,C2 | `oracles/access_oracle_test.dart` | Independent F1 cartesian evidence table; Director needs scope,403 defeats lease. | AC3, AC4, AC5, AC6, AC7 |
| T54 / O02 | C3,C2 | `oracles/profile_roster_oracle_test.dart` | Literal tax constants and latest employment record 9/tracking precedence. | AC9, AC10 |
| T55 / O03 | C4 | `oracles/asset_conservation_oracle_test.dart` | Literal 725/8priced/2unpriced; permutations conserve exact groups/counts. | AC15, AC16, AC17 |
| T56 / O04 | C5 | `oracles/fuel_arithmetic_oracle_test.dart` | Literal 216000s/1440/18/432/80h and 20/480/72h; advancing time leaves stock duration fixed. | AC21, AC22, AC23 |
| T57 / O05 | C5 | `oracles/fuel_alert_oracle_test.dart` | Threshold±1ms, missing expiry, four known severities and exactly two episodes. | AC24, AC25, AC26 |
| T58 / O06 | C6 | `oracles/wallet_decimal_oracle_test.dart` | Literal 1500/1200/100.40/35.40/65.00/3.015→3.02/one unknown. | AC27, AC28, AC29, AC30 |
| T59 / O07 | C2 | `oracles/cache_clock_oracle_test.dart` | Literal 3480s cache/3600s lease,304 validation-only,30/60/120/300/300 delay. | AC6, AC33, AC34 |
| T60 / O08 | C1,C2,C5,C6 | `oracles/ownership_race_oracle_test.dart` | F7 event-order permutations; old publication/names/alerts rejected, other owners intact. | AC7, AC31, AC38 |

### 6.3 AC1–AC40 reverse traceability

This is the exact inverse of the Product case associations above. Unit sets are
the union of their mapped test owners/dependencies; C10 additionally verifies the
whole release. A criterion with one primary Product case still includes all that
case's parameterized variants, not a single smoke assertion.

| Acceptance | Required cases | Units |
|---|---|---|
| AC1 | T41/U01 | C7 |
| AC2 | T25/P05, T42/U02 | C2, C7, C8 |
| AC3 | T01/D01, T22/P02, T42/U02, T53/O01 | C0, C2, C3, C7, C8 |
| AC4 | T02/D02, T22/P02, T23/P03, T53/O01 | C0, C2, C3 |
| AC5 | T03/D03, T23/P03, T28/P08, T42/U02, T52/U12, T53/O01 | C0, C2, C4, C7, C8, C9 |
| AC6 | T03/D03, T27/P07, T48/U08, T52/U12, T53/O01, T59/O07 | C0, C2, C5, C8, C9 |
| AC7 | T26/P06, T28/P08, T39/P19, T43/U03, T53/O01, T60/O08 | C0, C1, C2, C4, C5, C6, C7, C8 |
| AC8 | T01/D01, T24/P04, T25/P05, T43/U03 | C0, C2, C7, C8 |
| AC9 | T04/D04, T21/P01, T41/U01, T44/U04, T54/O02 | C2, C3, C7, C8 |
| AC10 | T05/D05, T22/P02, T44/U04, T54/O02 | C2, C3, C8 |
| AC11 | T05/D05, T22/P02, T44/U04 | C2, C3, C8 |
| AC12 | T06/D06, T44/U04 | C3, C8 |
| AC13 | T02/D02, T21/P01, T44/U04 | C0, C2, C3, C8 |
| AC14 | T29/P09 | C2, C4, C5 |
| AC15 | T07/D07, T45/U05, T55/O03 | C4, C8 |
| AC16 | T08/D08, T45/U05, T55/O03 | C4, C8 |
| AC17 | T09/D09, T45/U05, T55/O03 | C4, C8 |
| AC18 | T10/D10, T28/P08, T30/P10, T45/U05 | C2, C4, C8 |
| AC19 | T12/D12, T29/P09, T31/P11, T46/U06 | C0, C2, C4, C5, C9 |
| AC20 | T46/U06 | C5, C9 |
| AC21 | T11/D11, T31/P11, T46/U06, T56/O04 | C4, C5, C9 |
| AC22 | T12/D12, T13/D13, T32/P12, T47/U07, T56/O04 | C0, C5, C9 |
| AC23 | T13/D13, T32/P12, T47/U07, T56/O04 | C5, C9 |
| AC24 | T14/D14, T46/U06, T57/O05 | C5, C9 |
| AC25 | T15/D15, T33/P13, T48/U08, T57/O05 | C1, C2, C5, C9 |
| AC26 | T33/P13, T34/P14, T48/U08, T57/O05 | C1, C2, C5, C7, C9 |
| AC27 | T16/D16, T35/P15, T49/U09, T58/O06 | C2, C6, C9 |
| AC28 | T17/D17, T36/P16, T49/U09, T58/O06 | C6, C9 |
| AC29 | T18/D18, T37/P17, T49/U09, T58/O06 | C2, C6, C9 |
| AC30 | T17/D17, T18/D18, T36/P16, T49/U09, T58/O06 | C6, C9 |
| AC31 | T35/P15, T36/P16, T37/P17, T49/U09, T60/O08 | C1, C2, C5, C6, C9 |
| AC32 | T34/P14, T38/P18, T50/U10 | C1, C2, C5, C7, C8, C9 |
| AC33 | T19/D19, T21/P01, T29/P09, T38/P18, T50/U10, T59/O07 | C1, C2, C4, C5, C8, C9 |
| AC34 | T19/D19, T38/P18, T40/P20, T50/U10, T59/O07 | C1, C2, C4, C8, C9, C10 |
| AC35 | T20/D20, T30/P10, T41/U01, T51/U11, T52/U12 | C0, C2, C4, C7, C8, C9, C10 |
| AC36 | T43/U03, T51/U11 | C2, C7, C8, C9, C10 |
| AC37 | T47/U07, T50/U10, T51/U11 | C2, C5, C7, C8, C9, C10 |
| AC38 | T20/D20, T39/P19, T40/P20, T52/U12, T60/O08 | C0, C1, C2, C4, C5, C6, C7, C8, C9, C10 |
| AC39 | T40/P20 | C2, C4, C10 |
| AC40 | All T01–T60: D01–D20, P01–P20, U01–U12, O01–O08; runtime and release evidence | C0–C10; C10 final gate |

### 6.4 Required extensions within those cases

These are suffix variants of mapped cases, not replacement acceptance criteria:

- P04: two engines refreshing the same token, cancellation after code exchange,
  callback in the wrong window, invalid signature/audience/subject, unchanged
  refresh versus explicit equal-scope reauthorization, stale membership upsert and
  delete/re-add incarnation. Test each await boundary with durable postconditions.
- P05/P07 and **P01.selfNpc**: self roles/titles/standings for resolved
  NPC membership while management stays unavailable; first eligible fetch with no
  cache; expired read lease with allowed due request. P07 includes an expired access
  token with a refreshable grant
  and unexpired offline endpoint/role lease.
- P09/P18: two whole-dataset jobs cannot claim different pages and bypass
  single-flight; all-page 304 with one absent cached page; source generation change
  while paused; DB commit failure does not renew; crashed claim recovery rejects
  late old-owner publication. Include first-success explicit empty snapshot.
- D08/P20: raw location_type collision, deterministic unresolved 65-edge ancestry,
 100000-row adversarial graph, worker result after revocation and private-name index
  invalidation. D20 tests bounded exponent/scale and large exact numeric identifiers.
- D12/P12: supported 3×3 hull/module matrix, multiple service labels for one fitted
  module, duplicate slots, unproven label mapping, known offline versus missing,
  same-round304, skew at 5m/5m+1ms, absent source clocks and changed consumer digest.
- D15/P13/P14: ClockTick crossing, access/freshness expiration at the same instant,
  lost event hints, native-permission denial before claim, durable handoff crash
  boundary, opaque notification click after switch/delete, no competing subwindow
  monitor. Never assert OS delivery occurred merely because SQL claimed it.
  Include visible critical assessment with native opt-in off and missed selection/
  opt-in hints while the main window is hidden.
- P12/U07: pause SQL Save before commit, attempt repeated Save/Cancel, switch owner,
  revoke authority and introduce an expected-revision conflict; only the valid
  current-owner commit persists, and no late completion changes another context.
- P16/P17: malformed second-page value/conflicting cursor duplicate leaves all
  accepted history/coverage unchanged; resource-bound clean pause is partial, not
  invalid or continuous;365-day prune adjusts segments without fabricating gaps.
- P19: fresh install,21→22, supported earlier upgrade fixtures, rollback/reopen and
  concurrent migration/version reread. Preserve AAR/Exploration/personal/other-owner
  sentinels. Central deletion is called without mounting Corporation.
- U03/U11/U12: actual selector/host, intermediate rendered frames, denied private
  name after successful row load, all tooltips/semantics,80-character names, large
  signed currency and every F8 state/dialog at both text scales.

Journey coverage remains Product S1–S10: S1–S3/S8 flow through C2/C3/C7/C8;
S4 through C2/C4/C8; S5–S6 through C2/C4/C5/C7/C9; S7 through C2/C6/C9;
S9 through C1/C2/C7 plus each owned service; S10 through C2/C7/C8/C9/C10.
Product §8.6 remains the canonical journey-to-case table.

## 7. Verification, invariants and release boundaries

### 7.1 Non-negotiable invariants

1. **Authority conservation:** no public cache, other character, requested scope,
   location role, title or retained row can manufacture a visibility permit. All
   protected joins inherit every dependency's authority and immediately hide the
   removed dependency's contribution.
2. **Publication fencing:** each accepted payload and metadata commit has one live
   logical-job owner and unchanged context/incarnation/grant/invalidation. Delete,
   confirmed departure and revocation always defeat old workers, including CPU
   tasks, token callbacks and missed event hints.
3. **Time honesty:** payload time, source time, validation time, HTTP deadline,
   permission expiry and model observation anchor stay independent.200/304/cache
   read/clock tick have different effects. Equality locks; no hidden auto-extension.
4. **Completeness honesty:** failed or malformed pages never replace an accepted
   complete list/history job. Clean bounded history observation is labeled partial;
   bounds alone do not prove coverage. Empty, missing, denied and unknown differ.
5. **Accounting conservation:** each distinct asset goods row is valued at most
   once; ancestor context is not a search match; exact wallet folds include all
   matching cached rows once. No double arithmetic or SQL REAL conversion in money.
6. **Fuel provenance:** reported expiry, observed bay, supported rate and manual
   scenario are independent. Q/R requires compatible dated observations; startup
   cost and non-block resources are not silently recurring fuel-block consumption.
7. **Alert ownership:** fresh authorized selected context only, durable episode
   identity and at-most-once native handoff. Notification content is generic and
   clicks reauthorize. No implied closed-app monitoring or guaranteed OS delivery.
8. **Presentation safety:** no raw numeric entity IDs, private payload behind a lock,
   stale previous-owner frame, formulas in widgets or unsafe rich-text link. Every
   async branch uses `.when()` and every four-view state remains navigable.
9. **Read-only external scope:** GETs plus documented name-resolution POSTs only.
   Local scenario/preferences/acknowledgement do not refuel, pay, transfer, fit,
   change roles, structures or wallets. No unapproved OAuth privileges.
10. **Evidence before closeout:** documented intent is not passing implementation.
    All 60 cases, source-mapping proof, native runs and actual performance evidence
    are required; no small synthetic list can stand in for full-scale budgets.

### 7.2 Performance and release evidence

C10 runs profile/release-mode cached benchmarks on a recorded macOS machine, with
100000 synthetic asset rows, realistic nesting, long names, unresolved paths,
private/public name coverage, price gaps and mixed division filters. Record machine,
OS, Flutter/Dart/build mode, database size, index plan, fixture seed, source revision,
warmup count, sample count (at least 30 measured runs), p50/p95, memory and query/HTTP
counts. Separate cold app/reopen from warm indexed query results. Do not include
network waiting in a claim about cached-load latency or time an in-memory mock VM.

Targets from Product: p95 cached first content≤500ms, indexed search≤150ms for
100000 rows, hierarchy derivation≤1s. Avoid UI-thread tree construction, unbounded
watch-all-row rebuilding and N+1 type/name/history queries; use indexed scoped
queries, SDE batch APIs and cancellable worker derivation. Measure before adding a
new indexing/worker layer beyond those needs. An unmet budget is a release blocker
until resolved or explicitly adjudicated by Product/Plan, not a changed assertion.

Required verification commands during implementation (paths become executable as
their units land):

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test test/features/corporation/domain
flutter test test/features/corporation/data
flutter test test/features/corporation/oracles
flutter test test/features/corporation/presentation
flutter test
```

Use the team's actual native/profile benchmark runner for P20; ordinary debug
`flutter test` timing alone is not release performance evidence. Review generated
schema diffs and test supported migration fixtures. Inspect scoped coverage: at
least 80% feature coverage and all critical authorization/publication/accounting/
alert paths exercised, including failure branches. A percentage cannot substitute
for the mapped assertions. Shared auth/window/character/personal-data regressions
are mandatory because those seams change.

Tester records real macOS tray launch/focus/hide/reopen, actual character switching,
native permission allow/deny/click, opted-in hidden monitoring, offline lease
expiry/cold restart, two-engine refresh/revocation and responsive screenshots.
Capture all F8 width/text states or a documented complete checklist with evidence
locations; use constrained surfaces when native window minimums prevent 320px.
Record redaction checks for logs/tooltips/semantics/notifications and zero management
writes. No live private data is needed for these tests.

### 7.3 Failure diagnosis and security review

| Symptom | Investigate without collecting private payloads | Correct behavior |
|---|---|---|
| Scope present but panel locked | Actual grant epoch, general-role freshness, capability decision and last denial code | Explain missing/unknown role or endpoint verification; do not repeatedly launch login |
| Fresh roles but 403 | Endpoint-specific denial revision, not a generic network retry | Purged affected private data; public/unrelated capability remains |
| Valid expiry but bay/model unavailable | Assets permission/completeness, direct flags and rule/mapping/source-compatibility diagnostics | Status remains useful; no fake zero or forced Director for reported expiry |
| Old wallet rows/gaps | Division/kind, coverage segments, retained bounds and job termination reason | Disclose gaps/retention; no promise of recovery or reconstructed balance |
| Duplicate HTTP/native event | Logical-job key/lease token, two-connection tests, main monitor ownership/episode claim | One live request owner/episode handoff; no per-engine lock substitution |
| Cached content disappears offline | Endpoint and required role deadlines versus clock and known grant invalidation | Valid lease remains readable; equality hides; token expiry alone is not revocation |
| Names unavailable | Public/private resolver boundary, SDE readiness, specific name-resource denial | Contextual unknown label with valid independent data retained, no raw ID |
| Refresh says success after failure | Per-resource publication transaction/result, commit error and spinner finalizer | Partial/failed/cooldown feedback from canonical Product copy, never fabricated success |

Developer checks can use targeted logs with `[CORPORATION]` and typed failure codes,
`flutter test ... --plain-name <case>` and sanitized fixture DB metadata. Never request
tokens, JWTs, wallet descriptions, member activity, private asset names or database
dumps as routine support evidence. Internal numeric IDs may exist in storage/test
fixtures but should not be exposed in user-facing diagnostic strings.

Validate endpoint parameters, bounded division IDs, payload sizes, decimal digits/
exponents, source enum knowledge and URLs. SQL is parameterized. Permit only known
ESI/SSO/reference origins; redirects must not forward bearer credentials elsewhere.
Do not log raw Dio/OAuth exceptions containing request headers or response bodies.
Retain existing token storage without claiming new at-rest encryption; host access
to the local database remains an environmental security boundary. The module's
authority model prevents accidental application-level disclosure, not a malicious
local administrator reading files. No unrestricted private export is introduced.

### 7.4 Out of scope and handoff status

No corporation management writes, transfers, recruitment administration, role
editing, fueling action, docking/access entitlement proof, automatic multi-character
token substitution, alliance-wide management, corporation player standings,
cloud synchronization or process-independent alert daemon. No blanket rewrite of
Exploration, personal wallets/assets, DogmaEngine or SDE importer. Shared auth,
request, migration and window fixes are limited to the concrete safety seams here
and must preserve existing callers.

Architecture completion means C0–C10 can be planned with concrete file ownership,
test boundaries and release gates. It does **not** mean schema 22, Window 15 or the
Corporation feature exists yet. Current implementation, executable tests, native
evidence and performance gates remain pending. The fuel wire-label/source mapping
and native handoff crash limitation are explicit evidence/operational constraints,
not silently waived acceptance criteria.

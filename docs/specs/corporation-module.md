# Corporation Module — authoritative Product specification

**Status:** Product contract; architecture, implementation and tester verification pending.

**Release:** Phase 4, Corporation work associated with Sprints 23–24; phases 4e–4h.

**Date / baseline:** 2026-09-15; `feature/corporation-module` at `ccfe79b`.

**Audience:** Plan, Test-Author, implementation, review and tester.

## 1. Product perspective and scope

### 1.1 Problem and outcome

A corporation member needs to understand their organization and personal access.
A personnel officer needs a roster; a logistics director needs inventory; a
structure manager needs fuel warnings; an accountant needs division accounts.
These are different permissions, not one universal “corporation administrator.”
Mimir must make the available information useful without confusing missing access,
missing observations and an actual empty corporation inventory or zero balance.

The module provides a read-only corporation workspace for the selected character:
public profile, permitted member information, assets, structures and wallets. It
retains authorized observations locally, names their age and source, and explains
what is needed when a feature is locked. It does not perform corporation management
writes or claim that local permission estimates override ESI.

**Governing principles:**

1. **Character authority governs every private read.** Corporation membership,
   granted OAuth scopes, endpoint-specific roles and the server's authorization
   result all matter. Director, Accountant, Junior Accountant, Personnel Manager
   and Station Manager have different capabilities. Never borrow another logged-in
   character's token or cached private data to unlock the selected character.
2. **Public information remains useful.** Non-directors see the public profile,
   their own reported roles/division permissions and personal standings when
   authorized. The basic member roster is also available to members with its scope.
   A locked capability shows its requirement, not a failing spinner or fake data.
3. **Unknown stays unknown.** No fabricated join date, activity, fuel quantity,
   hourly burn, office, valuation, wallet balance or connection between records.
4. **Resolve identities.** Items, systems, people, organizations and locations use
   resolved names or contextual unknown labels. No raw numeric EVE identifiers in
   labels, tooltips, errors, notifications or accessibility text. Division numbers
   1–7, quantities, prices and dates are meaningful values and remain visible.
5. **Offline observations retain an access boundary.** Drift stores durable data;
   public information can remain readable offline. Private data requires the
   bounded authorization lease in §5.3 and locks immediately on known revocation.
6. **Refresh and calculations are explicit.** Every live view supports AppBar and
   pull-to-refresh. Pure domain services own permission decisions, asset traversal,
   decimal accounting, fuel forecasts and alerts; widgets render their results.

### 1.2 Authority, phases and source corrections

This specification governs the requested release. Source context at
`mimir-context-library` commit `3813f1a`:

- [Development roadmap, Sprints 23–24](https://github.com/infiquetra/mimir-context-library/blob/main/discovery/blueprint/11-development-roadmap.md).
- [Corporation Tools, §6.10](https://github.com/infiquetra/mimir-context-library/blob/main/discovery/blueprint/06-feature-modules.md#610-corporation-tools).
- [Corporation platform placeholder](https://github.com/infiquetra/mimir-context-library/blob/main/platform-specs/03-feature-modules/corporation/README.md).
- [Exploration Product specification](exploration-module.md) supplies the document
  structure and established dedicated-window interaction pattern.

| Phase | Required outcome |
|---|---|
| **4e — Profile & roster** | Window, character/corporation context, scope and role gates, public overview, own access/standings, member roster with qualified join dates, roles, titles and tracking. |
| **4f — Assets & hangars** | Complete corporate asset snapshots, location/division/container browsing and qualified estimated values. |
| **4g — Structures & fuel** | Owned Upwell structures, reported services/state/timers, fuel observations and qualified forecasts, local critical alerts. |
| **4h — Wallets** | Seven divisions, independent balances, journal and market transactions with exact decimal totals and honest history coverage. |

The placeholder is not an API contract. Its 15-minute structures TTL conflicts
with the verified one-hour contract. “Wallet if director” is too restrictive:
the current endpoint also allows Accountant and Junior Accountant. In-game
Accountant asset visibility does not change the ESI assets endpoint's Director
requirement. Basic roster access does not require Director. Titles are inspected,
not managed. Exact scopes, role exceptions and current response shapes are in §5.

### 1.3 Current capabilities versus additions

| Seam at `ccfe79b` | Reuse and required addition |
|---|---|
| [Window types](../../lib/core/window/window_types.dart), [tray](../../lib/core/tray/tray_service.dart), [window service](../../lib/core/window/window_service.dart) | IDs 0–14 exist, Exploration is 14. Add Corporation **15**, title/icon/default size, tray action and reverse mapping. Preserve single-window creation and focus/reopen behavior. |
| [Subwindow host](../../lib/core/window/sub_window_app.dart), [Exploration screen](../../lib/features/exploration/presentation/exploration_screen.dart), [visibility service](../../lib/core/window/window_visibility_service.dart) | Corporation owns adaptive module navigation and a functioning character switcher. Its public view must open while SDE loads/fails. Do not inherit the host's fixed rail or copy Exploration's placeholder character controls. |
| [ESI client](../../lib/core/network/esi_client.dart) | Public corporation lookup exists; private corporation endpoints and response-preserving error distinctions do not. Existing profile parser uses the old fractional `tax_rate` shape; add the current explicit adapter in §5.1 without silently changing unrelated callers. |
| [OAuth](../../lib/core/auth/oauth_service.dart), [auth providers](../../lib/core/auth/auth_providers.dart), [scope configuration](../../lib/core/config/eve_config.dart) | PKCE and token scope parsing exist. Add requested-versus-granted capability handling and reauthorization. Existing grants lack corporate scopes. Reauthorization temporarily stores corporation ID 0: treat this as unresolved membership, never a real corporation or proven departure. |
| [AppDatabase](../../lib/core/database/app_database.dart), [cross-window events](../../lib/core/window/cross_window_events.dart) | Schema 21 lacks corporation entities and authorization snapshots. Add forward migrations, owned caches, durable revisions and lease state. Events are hints; reopen/resume reads SQLite. Existing tokens are in character rows: do not claim new encrypted/keychain storage as shipped. |
| [SDE database](../../lib/core/sde/sde_database.dart), [SDE service](../../lib/core/sde/sde_service.dart) | Schema 7 supplies item/universe reference seams. Validate availability/version; public profile, wallets and names cached from ESI cannot depend on successful SDE initialization. |
| [Asset sync](../../lib/features/assets/data/asset_sync_service.dart), [wallet repository](../../lib/features/wallet/data/wallet_repository.dart) | Existing personal inventory and wallet storage are separate. The personal asset container hierarchy is unfinished; the wallet journal reads only its first page and coerces an absent balance to zero. These are not acceptable corporate completeness/accounting contracts. |
| [Name providers](../../lib/features/wallet/data/wallet_providers.dart), [character status repository](../../lib/features/characters/data/character_status_repository.dart) | Reuse resolved public names. Private structure names and custom asset names require character/grant-scoped storage; the globally keyed personal location cache cannot establish access. |

### 1.4 Non-goals and delivery boundary

No role/title assignment, member removal, recruiting decisions, wallet transfers,
market orders, refueling, structure configuration, ACL editing, asset movement,
office rental, corporation contracts or industry jobs in this release. No alliance
administration, shared web dashboard, credential pooling, background cloud polling,
POS fuel simulation, sovereignty hub/skyhook management, or member productivity
scoring. No claim that all rented offices or all inventory inside a structure are
enumerable from the assets endpoint. Native alerts are local and opt-in; the app
cannot guarantee delivery while quit or asleep. Earlier AAR and Exploration work
are separate shipped initiatives, not new prerequisites to reimplement.

## 2. User stories and operational workflows

### S1 — Ordinary member opens their corporation

Select a character and launch Corporation from the tray. The profile shows the
corporation name/ticker, logo, reported count, tax, CEO/alliance and headquarters.
My access shows reported division role sets; private features explain their scope
and role requirements. With membership scope, I can browse the basic roster.
Without an optional scope, the public overview remains functional.

### S2 — Personnel officer reviews the roster

A Personnel Manager authorizes membership/role reads. They see member names and
permitted role sets, with join-date provenance. Activity and other members' title
assignments remain locked unless the character separately meets their gates.
A character with grantable roles can explicitly check role-list access; their
ordinary role listing alone cannot prove that alternative eligibility.

### S3 — Director reviews membership activity

A Director authorizes tracking and titles. They filter named members by reported
last-login age and inspect join date, last login/logout, reported ship/location
and titles. Missing timestamps say Not reported. Old observations never claim a
member is online now or has contributed nothing.

### S4 — Director finds supplies across offices and containers

Choose Assets, select a location and division, then expand a container. Search by
item/custom name retains the matching item's path. Locations, deliveries and asset
safety are distinguished. Estimated totals disclose unpriced items and snapshot
age; a broken parent chain remains visible in an unresolved group.

### S5 — Station Manager checks a structure's fuel

Open Structures without Director or assets permission. State, services and the
reported fuel expiry are available with structure scope. Fuel-bay quantities may
remain Unavailable. A Director with an observed fuel-bay asset row sees its separate
timestamp. Any hourly-rate forecast is explicitly estimated with visible inputs.
Reported expiry remains the alert source even if a local forecast differs.

### S6 — A critical fuel alert needs action

While Mimir is running, a fresh authorized observation crosses the 24-hour fuel
threshold. The structure card becomes Critical; the app records one alert episode.
If native notifications were enabled, one generic notification opens Structures
after rechecking access. Repeated refreshes, reopening windows and acknowledgement
do not spam alerts. Stale data or lost access suppresses new notifications.

### S7 — Accountant compares wallet divisions

An Accountant or Junior Accountant with wallet scope sees division balances and
reads journal/transactions. They do not need Director. If division-name scope or
role is absent, labels remain Division 1–7. A missing division or failed history
page is labeled incomplete, never zero. There are no transfer controls.

### S8 — Member inspects their own access and standings

My access shows General, HQ, Base and Other reported roles and per-division
query/take/container-take/account-take indicators. These describe role evidence,
not a working inventory grant or structure ACL. Optional personal NPC standings
are labeled as such; they are not the player's standing with their player corp.

### S9 — Authorization or corporation membership changes

The user adds a missing scope through the existing PKCE flow. Cancellation keeps
the previous usable session. Switching to another character immediately replaces
the private context, including names, filters, counts and alerts. Confirmed corp
departure or role loss locks and invalidates affected data; delayed old responses
cannot restore it. A transient corporation ID 0 shows Resolving corporation.

### S10 — Network loss, partial refresh and narrow-screen use

Cached authorized content survives refresh failures while its access lease is
valid. An expired lease locks private content until access can be checked online.
Public cached data stays readable with age. AppBar and pull refresh share one
operation, including in empty/error states. The four views remain operable at
320px and 200% text scale, without clipped amounts or horizontal page overflow.

## 3. Functional requirements

### 3.1 Context, permissions and shared behavior

**R1 — Dedicated window.** Register Corporation as Window ID 15 with a tray action,
single-instance focus/reopen, independent module selection and active character
switcher. Preserve IDs 0–14. No app-wide navigation migration.

**R2 — Explicit corporation context.** Pin every private operation to tenant,
character, resolved corporation, authorization generation and endpoint/division.
No character and unresolved membership are distinct states. Public profile may
render without private scopes. A known NPC-owned or closed corporation shows its
public state; management panels say Not available for this corporation without
repeated doomed private requests.

**R3 — Capabilities, not one Director toggle.** Apply the endpoint matrix in §5.2.
Requested scope is not granted scope; a role is not a scope; a grantable role is
not an assigned role; wallet take permission is not wallet API read permission.
Known Director includes subordinate role eligibility, but still needs each scope
and a successful server response. A public CEO name alone does not unlock data.

**R4 — Honest locked states and reauthorization.** Distinguish missing scope,
missing role, access denied, unknown permissions, expired authorization and no
cached data. Explain requirements with readable role/scope purpose names and an
appropriate Authorize, Check access or Retry action. A 403 is not automatically
a missing-scope error. Never initiate login repeatedly on refresh or 403.

**R5 — Private cache isolation and revocation.** Follow §5.3 lease and purge rules
on reads, writes, window resume, notification delivery and character deletion.
Do not show one frame of the previous character's private data during a switch.
Do not let role-denied refreshes retain visible cached values or counts.

**R6 — Dual refresh with coherent publication.** Both gestures run the same
capability-aware refresh plan for the current view. Fetch only eligible/due data;
honor ESI expiry and shared limits. Publish a list only when its required pages
validate; dependent enrichments can fail independently with labeled coverage.
Retain the last complete snapshot on network/format failure, never on an access
decision that invalidates visibility. Refresh does not switch view or character.

**R7 — Names and untrusted text.** Resolve public identities through SDE, cached
ESI names, `itemNameProvider`/`locationNameProvider` and appropriate named-entity
adapters. Use scoped authenticated structure resolution only where permitted.
Fallbacks are Unknown item, Unknown character, Unknown corporation, Unknown
alliance, Unknown system, Unknown station or Structure name unavailable. EVE rich
text is sanitized to safe text/recognized links; unknown markup, showinfo IDs and
HTML must not become UI labels, executable content or raw identifier fallbacks.

**R8 — Persistence and lifecycle.** Store snapshots, page/cursor coverage, source
times, cache deadlines, grants and alert episodes in Drift. Migrations preserve
personal assets/wallets and existing modules. Shared request leases and revisions
work across engines; resume reconciles missed events. Hidden Corporation stops
its ordinary polling; only explicitly enabled alert monitoring may continue in
the main process while the app runs.

### 3.2 Profile and roster, Phase 4e

**R9 — Public overview.** Show profile fields that actually exist, including state,
ownership type, logo, member count, tax rates, CEO, alliance, headquarters and
founded date. A missing alliance means No alliance only when the response's
semantics establish absence; unresolved lookup means Alliance name unavailable.
Tax normalization is explicit (§5.1), and no missing CEO/date becomes ID 0 or today.

**R10 — Basic roster and join provenance.** The member-list response is the roster
membership set; public member count is a separately timestamped observation.
Do not pad missing rows to match that count. Member tracking's `start_date` is
preferred when authorized. Otherwise enrich visible/requested rows from public
corporation history: use the latest episode only if it matches the selected
corporation. Retain Join date unavailable on conflict, absence or fetch failure.
Do not use account birthday or an earlier employment episode as current tenure.

**R11 — Roles, titles and tracking are separate enrichments.** Join by character
identity to the roster; unmatched enrichment rows are not extra members. Preserve
HQ/Base/Other and grantable role sets separately. Never infer effective authority
from a title's display name. Own titles use own-title scope; corporate title
definitions and assignments use their distinct Director gate. Activity means
reported login/logout timestamps, base, location and ship, not live presence.
Filters All, last login within 7/30/90 days and Not reported use UTC and preserve
unknowns. Detail sheets state the observation's time.

**R12 — My access and standings.** Show seven divisions with reported query,
take, container-take and wallet-take evidence, segmented by General/HQ/Base/Other.
Do not flatten these into universal location access. Optional own standings list
NPC agents/corporations/factions from the personal endpoint. No player-corporation
standing, docking ACL or base assignment is invented when unavailable.

### 3.3 Assets and hangars, Phase 4f

**R13 — Complete inventory snapshot.** All corporation asset pages are required
before publishing replacement inventory. Scope is corporate ownership, not all
items owned by members in corporation locations. Treat a successful complete
empty list as no reported assets; errors and inaccessible assets are different.

**R14 — Locations and divisions.** Use actual endpoint identities/parent links,
office rows and location flags. Map `CorpSAG1`–`CorpSAG7` to hangar divisions.
Use default Division 1–7 when names are not supplied/authorized. Distinguish
Corp deliveries, asset safety, fitted items, ship cargo and unresolved locations.
An office with no asset evidence is not discoverable merely because another
office exists; label the list Asset locations, not All rented offices.

**R15 — Safe container traversal.** Build the hierarchy from item-parent links
within one snapshot; inherit the nearest enclosing division/location. Detect
self-links, cycles, orphan parents and excessive depth (§4.3). Show each inventory
row once, including unresolved rows. An ancestor subtotal includes descendants
once and must never be summed again as another inventory row.

**R16 — Qualified valuation.** Use exact quantities times cached ESI average
prices, without adjusted-price or invented market fallbacks. Keep valuation and
inventory timestamps separate. Unknown price/quantity and blueprint-copy value
are unpriced; administrative office rows are not goods. Show Priced subtotal,
unpriced row count and quote age; label Estimated total only for complete priced
coverage. No Jita liquidation or fitted/rig premium claim. Price refresh cannot
imply fresh inventory or access to another character's inventory.

**R17 — Browse and search.** Location, division, type/name and container filters
compose; search shows matched rows and ancestor context without treating ancestors
as additional matches. Large lists are paged/virtualized and expansion is keyed
by scoped item identity. Unknown items remain searchable by their generic label
and visible category; raw IDs are not search suggestions or copy actions.

### 3.4 Upwell structures and fuel, Phase 4g

**R18 — Structures and services.** Show the complete permitted owned-structure
snapshot, name, hull, system, state and reported services. Preserve unknown future
states, and distinguish a missing service list from an explicit empty list.
Station Manager may read this view without asset access. No fabricated fuel-bay
read or asset fetch is attempted through a Director token belonging to someone else.

**R19 — Timers without invented events.** Present `state_timer_start/end`,
`unanchors_at`, `reinforce_hour` and pending reinforcement settings distinctly.
The reinforce hour is a configuration window, not a scheduled attack. A passed
state timer says Awaiting updated state; it does not transition the structure
locally. Display UTC event time plus relative countdown; use actual local clock
boundaries and resynchronize on resume.

**R20 — Fuel observations.** `fuel_expires` is the reported depletion estimate.
Show remaining time and absolute expiry, with snapshot age. It does not report
current block quantity or hourly burn. If accessible assets contain directly
associated `StructureFuel` rows, show quantities by resolved fuel type and their
asset timestamp. No row is Unavailable, not zero. Ordinary cargo, nested containers
and `SpecializedFuelBay` ship stock must not become structure fuel.

**R21 — Explicit estimated burn and endurance.** A qualified forecast requires
the complete modeled online service set, a versioned supported service/hull fuel
rule, and a compatible known quantity or explicit user-entered fuel assumption.
Unknown services/modifiers make the automatic rate Not modeled. Manual quantity
and hourly-rate inputs are allowed as a local scenario, labeled User estimate
with saved time and character/structure ownership. Use §4.4 arithmetic; a rate of
zero means No modeled consumption, not infinite measured endurance. Never backsolve
hourly burn from ESI expiry or replace the ESI fuel alert clock with a scenario.

**R22 — Fuel severity and alert episodes.** Derive Reported expiry passed at
remaining ≤0, Critical at 0–24h inclusive, Low above 24h through 72h inclusive,
and Normal above 72h. Missing expiry is Unknown. Show freshness separately. New
alert episodes require fresh authorized structure data; acknowledge/deduplicate
durably (§4.4). Unreported fuel is not a critical empty tank.

**R23 — Local monitoring and delivery.** In-app severity is always available
when content may be viewed. Native alerts require explicit opt-in and platform
permission, with generic notification text by default. Monitor only the selected
character's authorized corporation; use shared due-time refresh and one episode
owner across engines. Disable delivery on access loss, character change, removed
structure or quit. Resume refreshes before any overdue notification; no promised
closed-app or sleeping-computer delivery.

### 3.5 Wallets, Phase 4h

**R24 — Seven independent divisions.** Render 1–7 consistently and preserve
custom names when authorized. Read permission and wallet-take roles are distinct.
An absent/denied balance is Unknown/Locked; only an explicit numeric zero is zero.
Show an All divisions total only with seven known authorized balances from one
complete response; otherwise show Known balances subtotal and coverage.

**R25 — Journal history.** Fetch every page of the requested ESI journal window,
which currently reaches back 30 days. Persist history observed locally, with its
earliest/latest time and known gaps. Default display is last 30 days, division
filter and newest first. Missing amount/balance remains null. Journal amounts
are signed as reported, not inferred from party order or reference type.

**R26 — Market transactions.** Use cursor pagination via `from_id`, not journal
page numbers. Show Buy/Sell, item, quantity, unit price, gross value, counterparty
and location. `journal_ref_id=-1` means no link. Link only when an actual journal
row for the same corporation/division exists; an unfetched link is unavailable.
Never add both transaction gross values and journal amounts into one cash total.

**R27 — Exact accounting and coverage.** Use decimal arithmetic with explicit
rounding (§4.5). Separate inflow, outflow, net and balances. Do not reconstruct
current balance from retained history or call incomplete history a complete
accounting period. Filters use a half-open UTC interval; titles and formatted
currency must not hide sign, missing values or partial coverage.

**R28 — Independent refresh and retention.** Wallet balances, each division's
journal and each transaction cursor chain have their own snapshot/coverage/error
state. One failed division must not clear another. Retain observed wallet history
for 365 days by default, purge older rows locally, and state that upstream retention
and gaps constrain recovery. Retention never overrides authorization locking or
character/corporation cleanup.

### 3.6 Presentation, observability and quality

**R29 — Responsive four-view navigation.** Overview & Roster, Assets, Structures,
Wallets are always reachable. Adaptive module rail/bottom navigation and separate
character selector follow §6, including 320px and 200% text scale. Changing tabs
retains state only within the same authorized character/corporation context.

**R30 — Explicit asynchronous states.** Use guarded `AsyncValue.when()` loading,
error and data branches. Distinguish lock, empty, partial, stale, refreshing and
SDE-unavailable states. No unguarded `.value`, missing data coerced to empty arrays
or network errors disguised as role requirements.

**R31 — Domain logic and logging.** Widgets contain no permission, valuation,
fuel or accounting formulas. Use `package:mimir/core/logging/logger.dart` with
`[CORPORATION]` or `[CORPORATION.*]` for transitions, requests, publication,
revocation and caught errors. Logs include endpoint/status/count/revision and
opaque context as needed, never tokens, payload dumps, member activity, custom
asset names, wallet reasons or private amounts.

**R32 — Measurable verification.** Cover §7–8 through pure domain tests, real
Drift/provider contracts and the real subwindow UI. No live credentials in tests.
Target p95 cached first content ≤500ms, indexed search ≤150ms for 100,000 asset
rows, and hierarchy derivation ≤1s on the team's recorded macOS test machine.
These are measured release targets, not claims from mock-only timing tests.

## 4. Data models, entities and validation

### 4.1 Identity, authority and observation envelopes

These are product entities; Plan selects concrete Dart/table names and migrations.
Persist EVE identifiers losslessly as integers/decimal keys, never floating-point
numbers. Keys remain internal. All timestamps are UTC instants; display conversion
does not change comparisons. Unknown enum values are preserved for compatible
future responses and displayed with a readable Unknown state.

| Entity | Required content and invariants |
|---|---|
| Corporation context | Tenant `tranquility`, character identity, resolved corporation identity, context generation, token-grant generation and membership resolution state. A temporary zero identifier is Unresolved. |
| Capability evidence | Endpoint capability/division, granted scopes, reported general/HQ/Base/Other roles, role validation time, last authorized endpoint validation, access outcome and invalidation generation. Grantable-role evidence is separate. |
| Snapshot envelope | Context key, endpoint/request variant, compatibility date, revision, payload received time, successful validation time, upstream Date/Last-Modified/Age when supplied, ETag, freshness deadline, completeness/coverage and last error. Absence of a timestamp is not time zero. |
| Public corporation profile | Name/ticker, ownership/state, reported count, optional CEO/alliance/founded date, headquarters, normalized ISK/LP tax percentages, sanitized description/URL and source version. |
| Roster snapshot / member enrichment | Base membership set plus independently dated names, current-episode join date/provenance, reported role sets, titles and optional activity fields. No enrichment invents membership. |
| Own access | Selected character's role sets, own titles and optional NPC standings; division labels scoped to authorized name source. “Reported role” is not a verified location ACL. |
| Corporate asset row | Owner context, snapshot revision, item/type/parent/location identities, raw location flag/type, quantity or unknown quantity, singleton/BPC markers, optional custom name and normalized path status. |
| Structure observation | Owner context, structure/type/system, scoped name, reported state/services, optional state/reinforcement/unanchor/fuel timestamps. Service rows preserve name and online/offline/cleanup/unknown state. |
| Fuel observation / scenario | Source `assets`, `ESI expiry` or `user scenario`, structure identity, per-type quantity, rule version and inputs, rate/endurance availability, observed/edited time. Never overwrite upstream fields. |
| Alert episode | Owner context, structure, fuel episode identity, severity reached, source revision, acknowledged/delivered timestamps and rearm state. Unique durable delivery claim prevents duplicate engines. |
| Wallet balance | Context, division 1–7, decimal amount, snapshot revision/time and availability. No default numeric value. |
| Journal / transaction | Context, division, lossless source row identity, time, typed decimal fields, optional party/context references and sanitized text. Unique per context/division/kind/source identity. |
| History coverage | Context/division/kind, query interval or cursor chain, retrieved bounds, page continuity, retained-history bounds, gaps and oldest-fetch termination reason. |

Scope any private name cache and derivative cache to the same authority as its
source. Public type/system/corporation/character names may be shared. A public
name does not make a private relationship, location assignment or amount public.

### 4.2 Roster and role normalization

- Deduplicate identical member IDs. A complete empty roster is valid data only
  for an authorized successful response; do not overwrite it using public count.
- Prefer tracking `start_date` when present. For public history, sort by descending
  `record_id` (the canonical ordering), then inspect the most recent episode.
  It must match the roster's corporation; otherwise leave the join date unavailable
  with source mismatch. An older matching episode is not current tenure.
- Validate dates; missing or impossible future login/join times are Unknown with
  a data warning, never negative tenure or online status. A logon newer than logoff
  is still a historical observation, not proof the client is currently online.
- General roles alone establish preflight role eligibility. Keep location role
  arrays as location evidence; do not elevate `Director` from malformed HQ data.
  Empty arrays mean no reported roles; missing arrays mean not reported.
- The personal roles endpoint does not expose grantable role arrays. For the
  corporation role-list alternative, a scoped member without Personnel Manager
  may use **Check role access** once per hour, or after a new grant. A successful
  response establishes this capability; a 403 locks it without an automatic retry
  loop. A previous success is a probe-eligibility hint for one due revalidation per
  hour, even after its read lease expires, unless known revoked. Cached payload
  stays hidden until that check succeeds. Do not gate this alternative on an
  unverifiable client assertion.
- Render Hangar Query, Hangar Take, Container Take and Account Take independently.
  General/HQ/Base/Other are separate tabs/sections. Do not union HQ/Base/Other or
  claim to know which office is a member's base without a permitted source.
  Humanized role labels are deterministic; unknown role strings grant nothing.
- Member names are batched. Fetch public histories only for visible/requested
  rows (at most 50 queued at once, at most 2 concurrent network reads), with their
  own daily cache; no eager N+1 fetch across the entire corporation on launch.

### 4.3 Asset graph and valuation

Parent selection is deterministic: when `location_type=item` and the parent item
exists in this same snapshot, attach to it; otherwise use a known external
station/structure/system root or an unresolved root. Do not infer identity by
subtracting legacy office-ID offsets. An `OfficeFolder` row is an administrative
node; its reported parent is the evidence for its location. A structure referenced
by assets need not appear as an item row to be a known external root.

Traverse iteratively. Detect cycles/self-links; limit rendered ancestry to 64
edges. Put affected/unresolvable rows in **Unresolved location** with a path warning
and retain each item once in inventory accounting. Missing parents do not cause
child deletion. A nearest `CorpSAGn` ancestor sets division n; no such evidence
means Unassigned, not Division 1. A descendant with its own valid division flag
uses that nearest flag. A container is an item with its own value as well as a
parent, so count its own value once plus distinct descendants. Office nodes are
excluded from goods valuation. Unknown flags are visible as Unclassified storage.

Quantity must be an exact nonnegative integer. A negative/unsupported quantity
marker is preserved as unknown quantity and excluded from numeric valuation;
do not turn it positive or assume singleton quantity. An explicit zero is zero.
An explicit BPC marker excludes market valuation regardless of a BPO price.
Missing BPC classification on a blueprint leaves its value unpriced. Unresolvable
type or missing/nonfinite/negative price is also unpriced; a legitimate zero quote
is valid and not absent. If a custom-name fetch fails, show the resolved type name.

For priced rows, `value = quantity × averagePrice` with exact decimal accumulation.
Round the final displayed subtotal to two decimals, half away from zero. Do not
sum individually rounded row displays. Quote age ≥24h means **Stale prices**;
the value may remain as a dated estimate while authorization permits inventory
display. Quotes never renew asset freshness. Show distinct priced/unpriced row
counts, not an unqualified inventory quantity total across unlike goods.

### 4.4 Fuel derivation, validation and alert state machine

**Observed fuel.** Accept asset rows whose direct location is the owned structure,
whose flag is `StructureFuel`, and whose type is a recognized resource in the
versioned rule set. For standard fuel-block count, sum Nitrogen Fuel Block (4051),
Hydrogen Fuel Block (4246), Helium Fuel Block (4247) and Oxygen Fuel Block (4312),
while retaining per-type counts. Other resources are separate rows, never added
to a block count. If there is no qualifying observed row, quantity is Unavailable.
An explicit zero quantity is zero. A partial asset fetch never supplies a new count.

**Burn model.** ESI service rows have names, not fitted module type IDs. A model
must connect all relevant services to supported module/built-in rules with explicit
versioned evidence, including hull-specific group bonuses and online state. A
free-text service-name guess or “all structures burn 40 blocks/hour” is prohibited.
Plan must supply a supported-rule manifest and fixtures for each supported model;
unsupported combinations return Not modeled. Minimum behavior for every structure
is the reported expiry display plus the explicitly labeled manual scenario.
Automatic modeling must never delay or block those source-backed behaviors.

For this release, support at least ordinary Manufacturing Plant, Invention Lab
and Research Lab consumers on Raitaru/Azbel/Sotiyo when fitted module identity,
online-state mapping and the complete consumer set are proven. A qualified rate
can be shown without a known quantity; endurance cannot. The manifest must record
how source service names map to fitted identities and reject ambiguous/missing
matches. If no model qualifies, the user can still enter the explicit scenario.

Selected verified baseline facts from [CCP SDE build 3503375](https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip),
released 2026-09-10, constrain this minimum model:

| Reference | Exact baseline meaning |
|---|---|
| Dogma 2108 / 2109 / 2110 | Fuel inventory group / hourly units / separate online units. Fuel block group is 1136. |
| Manufacturing Plant 35878, Invention Lab 35886, Research Lab 35891 | Each 12 blocks/hour and 864 online blocks before applicable bonuses. |
| Raitaru/Azbel/Sotiyo effect 6759 | −25% for service module group 1415; applies to hourly and online amounts. An unrelated service group does not receive it. |
| Athanor / Tatara refinery service bonuses | −20% / −25%, respectively, scoped to group 1322; not one universal refinery rate. |
| Reactor variants 45537–45539 | 15 blocks/hour, 864 online blocks before applicable bonuses: startup is not universally hourly ×72. |
| Metenox built-in service 82941 | 5 blocks/hour, 1000 online blocks; supporting SDE type is unpublished. Other reagents are a separate consumption dimension. |

Require a new reviewed manifest when the shipped SDE changes these values or their
effect scopes. Asset fuel visibility is supported by the official
[ESI clarification](https://github.com/esi/esi-issues/issues/1057#issuecomment-452671102);
hourly and startup consumption are distinct in CCP's
[service-module guidance](https://support.eveonline.com/hc/en-us/articles/207574929-Service-Modules).

For each supported online consumer i with base rate b and applicable reduction d,
`rate_i = b × (1 − d)`; total hourly rate is the sum over consumers. Each rule states
its resource, conditions and any game rounding. Offline services contribute zero;
cleanup/unknown state makes the automatic total unknown unless a verified rule
defines that state. Missing services is not a known zero-consumer set. Online/startup
charges are separate costs; they are not recurring consumption or universally
72 times an hourly rate. Modeled rates must not claim all-resource structure uptime.

For known compatible blocks Q and a positive modeled rate R, full-precision
`hours = Q/R`, `days = hours/24`. Format duration rounded down to the minute;
display days to two decimals but determine thresholds from unrounded durations.
The Q/R result is **Stock endurance at {quantity observation time}**, a static
capacity estimate under constant-rate assumptions. It is not a countdown from
the current moment: reopening an hour later leaves the same dated endurance and
observed quantity. Only ESI-reported expiry supplies the live depletion countdown.
Automatic stock endurance additionally requires quantity and consumer observations
from the same completed refresh round, both fresh, with source times no more than
five minutes apart (Last-Modified when present, otherwise HTTP Date; unknown source
time cannot establish compatibility). A supported rate may still display separately
when stock observations are incompatible. A changed service set/rate invalidates
the combined estimate until those conditions are re-established; no silent join
between an old quantity and new consumer state. Manual scenarios are explicitly
dated user assumptions and may combine the entered values without claiming that
they were simultaneously observed in EVE.

Manual Q must be an integer 0–10^12; manual R a decimal 0–10^9 blocks/hour with at
most six decimal places. Reject negative, blank, nonnumeric, NaN/infinite or excess
precision values inline without saving. A zero rate shows **No modeled consumption**
and null endurance; it must not show infinity. Zero known Q with R>0 gives zero
hours. **Calculate** validates and previews only; **Save estimate** is the sole
persistence action, storing the values and scenario time under its author.
Calculate followed by Cancel preserves the prior scenario. These are local
assumptions, not inventory.

**Source distinctions.** A Station Manager may have an expiry but no quantities.
A Director may have quantities but no matching live consumer model. Different
snapshot times are shown independently. Ansiblex travel resources and Metenox
reagents illustrate why fuel blocks alone do not establish full operational
uptime. POS/starbase, skyhook and sovereignty-hub fuel models are outside scope.

**Alerts.** Primary fuel severity uses `fuel_expires − now`, never Q/R. At exact
72h the state is Low; at exact 24h Critical; at exact zero Reported expiry passed.
Fuel expiry is an estimate, so “out of fuel confirmed” is not a derived state.
Only a fresh complete authorized structure snapshot can start an alert episode.
Re-evaluate countdowns on minute boundaries and exact threshold/expiry crossings.

- On a validated observation above 24h, arm the next critical episode. First
  authorized observation already at/below 24h starts one episode immediately.
- An armed crossing to ≤24h records one Critical episode. A passed expiry may
  raise that episode's severity in-app; it does not send another native alert.
- Refreshes, small expiry corrections, window recreation, acknowledgement and
  duplicate engines do not create another episode while still ≤24h.
- Rearm only after a successful fresh observation puts remaining time above 24h.
  Later crossing creates a new episode. A missing expiry is Unknown and does not
  rearm. A removed structure closes the episode; a later reappearance is a new
  observation requiring fresh access.
- Stale observations retain a labeled last-known warning only while viewable;
  they cannot initiate native alerts. Lease expiry hides private content and
  suppresses all private notifications. Refresh on resume before alert evaluation.
- Acknowledgement clears the unread indicator, not the card's severity. Persist
  one delivery claim per owner/structure/episode. Native permission denied leaves
  in-app warnings working; do not repeatedly prompt for platform permission.

### 4.5 Wallet arithmetic, pagination identity and history

Parse decimal money losslessly from JSON numeric lexemes; use decimal arithmetic
or an equivalent exact representation. Do not turn the API's declared `double`
into binary rounding errors in accumulated amounts. Preserve source precision
internally; format ISK to two decimals, half away from zero. Prices, quantities,
money and tax percentages have different validation rules.

- Journal key: owner/corporation/division/journal ID. Transaction key:
  owner/corporation/division/transaction ID. An ID reused in another division or
  personal wallet is not the same stored row. Identical duplicate rows coalesce;
  conflicting duplicates invalidate that publication.
- Journal amount may be signed or null. Inflow sums positive known amounts;
  outflow sums the absolute value of negative known amounts; net=inflow−outflow.
  Null amounts contribute to an Unknown amount count, not zero-valued coverage.
  Missing running balance stays null. Negative real balances are preserved.
- Transaction quantity must be positive and unit price finite/nonnegative.
  Gross=quantity×unit price; Buy/Sell is a separate direction label. Invalid
  required values fail that history publication, retaining the prior snapshot.
  No fees or taxes are inferred from gross trade amounts.
- Filters use `start ≤ row.date < end` in UTC. Stable order is date descending,
  then source ID descending. Aggregates use all matching cached rows, not only
  the rendered page. Label them Cached period totals unless complete period
  coverage has been established; unknown amounts still qualify completeness.
- Current balance is only the balance response. Summing historical journal rows
  or trade gross values is not a substitute, and changing a date filter does not
  alter the balance card's observation time.
- Balance and division-name rows must identify a division in 1–7. Identical rows
  coalesce; conflicting duplicates or out-of-range divisions fail that dataset's
  publication. A balance row missing its required amount or containing a nonfinite
  value also fails publication. A division absent from an otherwise valid response
  is Unknown and produces partial coverage. Invalid name metadata does not block
  valid balance data; use Division n until names validate.
- Journal pages use `X-Pages` and page numbers. Transactions use a strictly
  decreasing `from_id` equal to the oldest returned transaction ID; discard exact
  boundary duplicates, stop on an empty response, and fail a non-progressing loop.
  Continue until the requested time bound is crossed; do not assume a short page
  proves exhaustion. Never promise a fixed upstream transaction-history duration
  when the endpoint does not specify one.
- Initial journal request covers the upstream 30-day window; initial transaction
  request seeks the same 30-day display interval as far as the endpoint permits.
  Additional cursor pages on Load older extend cached history. The 365-day local
  retention is not a promise of 365 days of recoverable ESI data.

## 5. External API contracts, OAuth and cache policy

### 5.1 Verified primary contract and compatibility

Reviewed the [official ESI OpenAPI](https://esi.evetech.net/meta/openapi.json?compatibility_date=2026-09-15)
on 2026-09-15; it returned effective version **2026-08-18**. The old
`/latest/swagger.json` returned 404. Use the documented current routes below with
**`X-Compatibility-Date: 2026-08-18`**, normal authenticated ESI transport and the
application User-Agent. Pin this behavior in fixtures; do not float a date at
runtime or silently upgrade every existing ESI caller. Unknown additive fields
are tolerated, required field/type changes fail clearly. See official
[versioning guidance](https://developers.eveonline.com/docs/services/esi/overview/#versioning).

The current public corporation response has `tax_rates.isk` and
`tax_rates.loyalty_point`, both **percent values 0–100**: `10` renders `10%`.
The older public model uses `tax_rate` as a fraction (`0.10` → `10%`). Explicit
adapter/source versions distinguish them; never guess from numeric magnitude.
Current `state`, `type` and `friendly_fire` are enums. `ceo_id`, alliance and
founded date can be absent; do not preserve the old parser's required CEO cast.
Validate finite tax percentages within 0–100; invalid optional detail gets a
field warning rather than a fabricated default.

All runtime corporation reads use ESI; no public community proxy or LLM derives
private corporation evidence. Primary role semantics are described by CCP's
[roles listing](https://support.eveonline.com/hc/en-us/articles/203217712-Roles-Listing).
Director includes other roles; endpoint requirements still govern which data the
API exposes. Treat server denial as authoritative even when local role evidence
predicted success.

### 5.2 Endpoints, granted scopes, role gates and TTLs

Paths are relative to `https://esi.evetech.net`. GET unless explicitly marked
POST. Durations are verified `x-client-cache-ttl` values, not freshness guarantees
about gameplay. Live HTTP cache headers govern next request eligibility (§5.4).
“Director” below includes a character whose **verified general** roles contain
Director; do not unlock from a public CEO match. The ESI server remains the final
authority for CEO and exceptional role representations. A fresh public-profile
CEO match plus the capability's granted scopes enables an explicit **Check access**
probe for that endpoint, at most once per hour or after a new grant, if general
Director roles were not reported. A 200/304 establishes only that endpoint's
one-hour authorization; the public match alone exposes no private data. Known
denial prevents automatic renewal; successful prior checks support bounded due
revalidation as in the role-list alternative.

| Data / endpoint | Granted scope | Client preflight / ESI role | Default TTL |
|---|---|---|---|
| `/characters/{character_id}` | Public | Public membership/name; no management permission | 24h |
| `/corporations/{corporation_id}` | Public | Public | 1h |
| `/alliances/{alliance_id}` | Public | Public, when alliance exists | 1h |
| `/characters/{character_id}/roles` | `esi-characters.read_corporation_roles.v1` | Same character | 1h |
| `/characters/{character_id}/titles` | `esi-characters.read_titles.v1` | Same character | 1h |
| `/characters/{character_id}/standings` | `esi-characters.read_standings.v1` | Same character; NPC standings | 1h |
| `/corporations/{corporation_id}/members` | `esi-corporations.read_corporation_membership.v1` | Member of that corporation; no Director requirement | 1h |
| `/characters/{character_id}/corporationhistory` | Public | Public, requested member history | 24h |
| `/corporations/{corporation_id}/roles` | `esi-corporations.read_corporation_membership.v1` | Director or Personnel Manager; grantable-role alternative uses explicit server access check (§4.2) | 1h |
| `/corporations/{corporation_id}/membertracking` | `esi-corporations.track_members.v1` | Director | 1h |
| `/corporations/{corporation_id}/members/titles` and `/corporations/{corporation_id}/titles` | `esi-corporations.read_titles.v1` | Director | 1h |
| `/corporations/{corporation_id}/divisions` | `esi-corporations.read_divisions.v1` | Director; only custom names are returned | 1h |
| `/corporations/{corporation_id}/assets` | `esi-assets.read_corporation_assets.v1` | Director; `page` pagination | 1h |
| POST `/corporations/{corporation_id}/assets/names` | `esi-assets.read_corporation_assets.v1` | Director; 1–1000 unique item IDs per read-only request | No HTTP TTL declared; local 1h, invalidated with removed items |
| `/corporations/{corporation_id}/structures` | `esi-corporations.read_structures.v1` | Station Manager or Director; paginated | **1h** |
| `/universe/structures/{structure_id}` | `esi-universe.read_structures.v1` | Character's actual structure access; corporation role alone is insufficient | 1h |
| `/corporations/{corporation_id}/wallets` | `esi-wallet.read_corporation_wallets.v1` | Accountant, Junior Accountant or Director | 5m |
| `/corporations/{corporation_id}/wallets/{division}/journal` | `esi-wallet.read_corporation_wallets.v1` | Accountant, Junior Accountant or Director; division 1–7, page pagination | 1h |
| `/corporations/{corporation_id}/wallets/{division}/transactions` | `esi-wallet.read_corporation_wallets.v1` | Accountant, Junior Accountant or Director; division 1–7, `from_id` cursor | 1h |
| `/markets/prices` | Public | Optional asset valuation; average price only | 1h |
| POST `/universe/names` | Public | Batch supported public identity resolution | No HTTP TTL declared; local positive cache 24h |
| `/universe/stations/{station_id}`; local SDE types/systems | Public / offline | Public station/type/system names, never use station lookup for arbitrary structure IDs | Honor endpoint headers; local versioned reference |

Corporation standings/contact lists, member limits, role audit history, asset
coordinates and management endpoints are not required. Personal NPC standings
satisfy only the explicitly labeled personal standings view; do not fetch corp
standings and call them the pilot's standing with their player corporation.

**Scope workflow.** Explain and request scopes per chosen capability through the
existing PKCE flow, retaining already granted scopes as appropriate. Add own-role
scope when authorizing role-gated panels. Confirm the returned character identity
matches the intended character; a different character is not a grant update for
the original. Persist the returned grant set and invalidate the prior generation.
Cancellation does not erase a valid grant. Do not save access/refresh tokens in
new corporation cache or scenario tables. An ordinary token refresh with unchanged
subject/scopes preserves the grant generation. Explicit same-character
reauthorization increments it and hides prior private data until each capability
revalidates. Retain unaffected history/scenarios under the previous generation in
a quarantined state; after fresh authorization of the same character/corporation/
capability, atomically rebind that retained history to the new generation without
changing its observation times, gaps or retention bounds. Scope reduction,
definitive role loss, departure or deletion still performs the targeted purge;
quarantine must not defeat it. Token storage hardening is not represented
as part of this read-only feature contract.

### 5.3 Bounded offline authorization and revocation

Private records are logically keyed by **tenant + authorizing character +
corporation + capability/division + grant generation**. Physical deduplication is
allowed only if every read has equivalent ownership enforcement; it must never
make character B inherit character A's results, even in the same corporation.

A private capability becomes readable after a successful authorized endpoint
200/304. Its offline authorization lease lasts **at most one hour** from that
validation. Role-gated capabilities additionally require a currently valid general
role observation (one-hour validation lifetime), except an explicit server-verified
role-list/CEO exception. Effective expiry is the earliest required evidence expiry.
The basic roster and own titles/standings do not acquire a Director requirement.

Lease validity uses `now < expiresAt`: equality locks. A successful 304 may renew
the endpoint lease because ESI validated that character's request; a failed
request, reading SQLite, reopening, acknowledgement or recomputation cannot.
Refreshing wallet balances does not renew journal, asset or structure access.
Scopes must still belong to the current usable grant; a known invalid/revoked
credential immediately locks all its private capabilities. Normal access-token
expiry alone may be refreshable; while offline it does not extend the evidence
lease or create a new validation. A cold restart may use an unexpired durable lease
with the same stored grant, after loading durable invalidation state.

This is a deliberate offline product limit: an unobserved in-game role change can
remain unknown until the next allowed check. Do not claim real-time revocation
while offline. After one hour, show **Connect to verify corporation access**;
keep private rows hidden and preserve them for possible revalidation. Public
profile and public reference remain usable with stale labels. Locally saved fuel
scenarios also stay hidden when their owning structure context is inaccessible.

Known events take precedence over leases:

- **Character switch:** hide the old context before any await; reset private
  selection, search results, derived totals and notifications. Cancel old jobs or
  fence their publication. Never use an alt automatically.
- **Confirmed corporation change:** increment generation, lock and purge the
  old character/corporation private cache and scenarios/alerts. Preserve public
  profiles. Corporation 0 during auth is Unresolved, not a confirmed departure.
- **Scope reduction or definitive role loss:** invalidate and purge affected
  capability payloads/derivatives and private names that have no remaining valid
  owner reference. A broad Director loss affects every Director-only capability.
- **403:** lock the failed capability immediately, invalidate its access evidence
  and purge its protected payload/derivatives. Record access denied without guessing
  missing scope. Recheck roles when due; retain unaffected capabilities. A 403 from
  a secondary structure-name lookup locks that name, not the permitted structure
  list or whole asset snapshot. Repeated probes remain suppressed until eligible
  access recheck or a new grant; no retry loop.
- **401:** attempt normal token refresh once; if still unauthorized, lock that
  grant's private contexts and require reauthorization. A refresh network failure
  is not proof of role loss; retain hidden data, do not fabricate a new grant.
- **Character deletion:** central AppDatabase deletion transaction removes all
  that character's private caches, scenarios, access evidence and alert claims,
  including while this window is closed. Other characters' independent data and
  public names remain. No stale worker may republish after deletion.

### 5.4 Refresh, paging, cache clocks and failure contracts

`payloadReceivedAt` changes only on a successfully published 200 payload;
`lastSuccessfulValidationAt` may also change on authorized 304. Preserve upstream
Date/Last-Modified separately. HTTP freshness uses server Expires/Cache-Control
with Age/Date accounted for; absent headers use the table TTL. Do not label an
old upstream observation as newly observed because it was revalidated.

- AppBar and pull-to-refresh coalesce with scheduled jobs by exact scoped resource
  key in SQLite. A view refresh rechecks due access evidence and requests its due
  eligible datasets, not every corporation endpoint. Dependent names/prices expose
  separate failure states; a profile/name failure does not erase a valid wallet.
- Respect server cache deadlines; manual refresh cannot bypass them. When no work
  is due, show **Using cached data. Next refresh available at {time}.** No pointless
  HTTP call or repeated OAuth prompt. Refresh indicators finish on success,
  partial failure, lock, cancellation and cooldown.
- Assets, structure lists and journal snapshots require all declared pages,
  consistent `X-Pages`, no conflicting duplicates, valid required fields and
  consistent Last-Modified when provided. Validate each page's cache generation;
  do not attach page 2 from an older corpus to a new page 1. A 304 on page 1 alone
  cannot prove all pages unchanged. Revalidate every required page or use a
  server-documented whole-resource validator. If pagination metadata is missing,
  do not call a nonempty paginated response complete; preserve it as partial data
  pending a successful complete retry. A genuinely complete empty first response
  with consistent declared coverage may replace the list.
- A page-set change during fetch invalidates the staged set. Retain last complete
  data and retry once after the relevant cache deadline; do not loop immediately.
  Transaction cursors stage coverage before publication; no-progress/cycle or
  mid-chain failure does not silently mark history complete.
- Bound a single fetch job to 100 pages/cursor responses. Stop with **More history
  available** or **Incomplete inventory** as appropriate; never truncate silently.
  A paused inventory job can resume only with unchanged validated snapshot metadata;
  otherwise restart. The bound is a resource limit, not a claim of total corp size.
- Public/private errors preserve distinctions: missing scope, role/access denial,
  authentication expired, rate limited, offline/timeout, upstream unavailable,
  malformed response and local persistence failure. A successful network fetch
  followed by a failed DB transaction is not a successful refresh or lease renewal.
- Persist enough request/lease generations that late completions from a switch,
  delete, revocation, newer refresh or abandoned job cannot publish to the active
  context. Reread revisions on resume; transient cross-window events are hints.

### 5.5 Rate limiting and background work

Use shared ESI transport and durable bucket/backoff state across windows, keyed
by the actual application/character and rate-limit group. Honor `Retry-After`,
`X-Ratelimit-*` and legacy `X-ESI-Error-Limit-*` where present. Do not rotate
characters to escape a cooldown. For 420/429 without a usable retry deadline,
apply a conservative 60-second minimum and increase on repeated failures; for
timeout/5xx use 30/60/120/300-second capped backoff. Respect any later cache/server
deadline. No automatic immediate retry of 400/403 or incompatible payloads.

The reviewed contract groups corporate assets at 1800 tokens/15m and member,
structure, wallet and title-detail groups at 300 tokens/15m. These are upper
limits, not poll targets; use live headers for changes. Successful 2xx and 3xx
responses have different costs. See official [rate limiting](https://developers.eveonline.com/docs/services/esi/rate-limiting/)
and [cache/pagination practices](https://developers.eveonline.com/docs/services/esi/best-practices/).
Limit this module to two concurrent remote reads per character, prioritizing
visible data and enabled fuel monitoring over background names/history.

Normal polling occurs only for the visible view and due resources. Opt-in fuel
monitoring runs at the structures' permitted refresh interval while Mimir runs,
for the selected character only. An outage surfaces a monitoring-paused state;
it cannot produce a fresh fuel-exhaustion claim. Static/offline-only views do
not issue repeated ESI requests merely because the window gains focus.

## 6. UI screens, navigation and states

### 6.1 Corporation window shell

Tray label/window title: **Corporation**, Window ID **15**. Default desktop size
1200×800 logical pixels, retaining the common saved-window behavior. Opening again
focuses the existing window; closing/hiding follows normal Mimir window behavior.
The shell opens with public/cached content even while SDE initializes or fails.

Four persistent views: **Overview & Roster**, **Assets**, **Structures**, **Wallets**.
At usable content width ≥600px use a module rail; below 600px use four labeled
bottom destinations (short label **Overview**, accessible name **Overview & Roster**).
Character selection is a separate named control, not a fifth module destination.
Use the actual current-character provider; entries show resolved character name
and portrait, with corporation context. Switching must work in the real window,
not just a test-injected selector. If a desktop character rail consumes width,
calculate module breakpoints after that reservation and avoid duplicate selectors.

At ≥1100px use list/detail or table/detail layouts. At 600–1099px use a compact
list and detail sheet. Below 600px use stacked cards and full-width detail routes.
At 320px or 200% text scale, allow labels to wrap, amounts to occupy their own row,
and filters to wrap/scroll locally; no horizontal page scroll, ellipsized critical
amounts, nested overflowing DataTables or inaccessible bottom destinations.
Do not subtract the character rail twice when selecting layouts.

Each view has an AppBar **Refresh** action and an always-scrollable body supporting
pull-to-refresh, even with a short list, locked panel or empty result. Disable
redundant requests during a shared refresh while preserving status. No character
disables refresh; public-only mode refreshes public data. A toolbar freshness line
shows the current dataset time, not one misleading timestamp for every panel.

### 6.2 Overview & Roster

Desktop: corporation header across the top; profile and My access cards beside
the roster. Compact: stacked profile summary, own access/standings disclosure and
roster list. Header uses CorporationLogo, name/ticker and public state. Show
member count, ISK tax and optional LP tax, CEO/portrait, alliance/logo, headquarters
and founded date with resolved names. Description is expandable safe text.

Roster rows show CharacterAvatar/name, join date/source and permitted title/role
summary. An activity column/filter is available only with tracking access. A
member detail sheet separates Identity, Roles, Titles and Activity; locks remain
at the individual enrichment, not the whole roster. Loading a name never erases
the row or exposes its numeric identity. Show **Roster: {n} returned members**
beside the separately labeled public member count when they differ.

My access lists reported General/HQ/Base/Other roles and a seven-division matrix
for query/take/container-take/account-take. Use Yes / Not reported / Unknown rather
than green “Access granted” for unverified inventory ACLs. Distinguish an explicitly
empty role set from missing roles. Optional standings card title is **My NPC
standings**; source entities are named and scores preserve signs.

### 6.3 Assets

Desktop: location/division tree on the left, virtualized item list centrally,
selection detail on the right when width permits. Compact: location and division
selectors, breadcrumb, stacked item rows and a detail sheet. Rows include EveTypeIcon,
type/custom name, quantity, storage group and qualified value. Tooltips identify
resolved type and path, never IDs. Unknown names retain icons/fallback labels.

Show asset snapshot age, separate price age, priced subtotal and unpriced row
count above results. Search is scoped to the selected authorized snapshot and
preserves ancestor context. Empty result copy distinguishes **No reported assets**,
**No assets match these filters**, **No cached assets**, and **Assets locked**.
No location or division count appears behind a lock. Unresolved parent chains
remain inspectable with a clear path warning.

### 6.4 Structures

Cards/list rows show resolved structure/hull/system, reported state, services,
state timer and fuel severity text+icon+color. Default order is reported expiry
passed, Critical, Low, Normal, Unknown; within severity earliest known expiry,
then case-insensitive name and stable internal identity. Unknown rows remain visible.
Expose filters All / Critical & Low / State / System. Offline or stale is an
additional badge, not a severity replacement.

Details separate:

- **Reported status:** source age, exact UTC timers and service states.
- **Reported fuel expiry:** absolute timestamp and live countdown; no invented
  confirmed collapse, abandoned flag or service shutdown from a passed timer.
- **Observed fuel bay:** per-resource quantities and asset age, or Director/scope
  requirement/Unavailable. Reserve fuel is not installed fuel.
- **Estimated consumption:** supported model/rule version and assumptions, or
  Not modeled; hourly and daily block consumption, dated stock endurance only
  when both quantity and rate qualify. The manual scenario is expandable, with
  clear input validation and **Calculate**, **Save estimate**, **Cancel** actions.
- **Alerts:** in-app acknowledgement and opt-in native monitoring status. A
  missing native permission does not hide in-app severity.

The primary depletion label always says **ESI-reported fuel expiry**. A conflicting
local estimate is shown alongside it, not substituted or averaged. Expose **Fuel
data unavailable** without suggesting zero or requiring an unrelated scope merely
to read already authorized structure status.

### 6.5 Wallets

Seven named/default division chips or stacked balance cards, with the selected
division retained only in its current context. Desktop shows a readable ledger
table; narrow layouts show Date/type, signed amount, counterparties and optional
running balance on separate lines. **Journal** and **Transactions** are subtabs
within Wallets. Defaults: Division 1 and last 30 days. All-divisions summary is
separate from any division's history; do not mix division entries implicitly.

Journal filters include date interval and reference type; Transactions includes
Buy/Sell and item. Show source history coverage, retained bounds, gaps/partial
fetch state and Load older where available. Entries with unknown amounts or
unknown references remain inspectable using safe descriptive labels. No raw
transaction/journal/context IDs, including in copy controls. A missing counterpart
is Unknown party, not the selected character. Account-take badges never create
transfer, purchase or payment controls.

### 6.6 Shared states and exact feedback

| Condition | User-visible behavior / stable copy |
|---|---|
| No selected character | **No Character Selected** — “Select a character to view their corporation.” |
| Membership unresolved | **Resolving corporation**; no private request or numeric placeholder. |
| NPC/closed corporation | **Management data unavailable** — “Private management views are not available for this corporation.” Public profile stays visible. |
| Missing scope | **Authorization required** — explain the named data access; action **Authorize**. |
| Assets role gate | **Assets locked** — “Requires Director and corporation asset authorization.” |
| Structures role gate | **Structures locked** — “Requires Station Manager or Director and corporation structure authorization.” |
| Wallet role gate | **Wallets locked** — “Requires Accountant, Junior Accountant or Director and corporation wallet authorization.” |
| Tracking gate | **Activity locked** — “Requires Director and member tracking authorization.” |
| Role-list alternative | **Role access not verified** — “Requires Personnel Manager, Director or a grantable role.” Action **Check role access** when eligible. |
| Server denies a capability | **Access denied** — “ESI did not authorize this character for this data.” Explain confirmed missing conditions only. |
| Private offline lease expired | **Connect to verify corporation access**; hide private payload and actions requiring it. |
| No prior snapshot | **No cached {dataset}** — “Connect and refresh to load this data.” |
| Successful current-view refresh | Snackbar **Corporation data updated.** Only when requested due datasets published/validated successfully. |
| Partial refresh | Snackbar **Some corporation data could not be updated.** Inline panels identify failures. |
| Refresh failed, readable cache retained | **Refresh failed. Showing last verified data.** Include cached age and remaining access status. |
| Cache cooldown | **Using cached data. Next refresh available at {time}.** |
| Rate limited | **ESI rate limit reached. Try again at {time}.** Honor the shared deadline. |
| Scenario saved | **Fuel estimate saved.** A saved estimate is not a refuel or stock update. |
| Native permission denied | **Notifications are disabled. Fuel warnings remain available here.** |
| Generic native critical notification | Title **Corporation fuel alert**; body **A structure needs fuel attention. Open Mimir to verify current status.** |
| Authentication renewal failed | **Reauthorize this character to continue.** No repeated automatic launch. |

Inline errors remain useful after a snackbar disappears. Retry controls supplement
the AppBar/pull gestures on failed panels. Keyboard focus order follows character,
module navigation, filters, content and actions. Use labeled ≥48px touch targets,
visible focus, screen-reader names and severity text/icons so color is never the
only signal. Loading/error/empty widgets participate in the same responsive matrix.

## 7. Acceptance criteria

Each criterion is mandatory. References connect it to requirements; §8 supplies
concrete test ownership and exact outputs. “Verified” here means what implementation
must prove, not that this documentation has run the feature.

### Context and permission criteria

- **AC1 (R1, R29):** Tray launch opens Corporation Window 15 exactly once; repeated
  or concurrent launches focus it, and all existing window IDs still round-trip.
- **AC2 (R2, R5):** No character, unresolved/zero corporation, NPC-owned, closed
  corporation and ordinary member contexts produce their distinct specified states
  without requesting Corporation 0 or exposing an old private context.
- **AC3 (R3, R4):** The full F1 role/scope matrix holds, including member roster,
  Accountant/Junior Accountant wallets, Station Manager structures and Director-only
  assets. Requested-but-ungranted scopes never unlock a view.
- **AC4 (R3, R11, R12):** HQ/Base/Other, assigned and grantable roles remain separate;
  the explicit grantable-role check can unlock only the role-list capability on 200.
- **AC5 (R4, R5):** 401 renewal, confirmed 403 denial, missing scope, missing role
  and network error remain distinct; no automatic reauthorization/403 retry loop.
- **AC6 (R5, R8):** Private cached content is available only within its scoped
  one-hour access lease and required role evidence; it locks at equality and on
  known revocation, including after cold restart or missed cross-window events.
- **AC7 (R5, R8):** Switching, confirmed corp departure, scope/role reduction and
  central character deletion invalidate the correct payloads, derivatives, private
  names and alerts; stale requests cannot republish, and other owners are preserved.
- **AC8 (R4):** PKCE reauthorization is capability-specific, records actual granted
  scopes, rejects wrong-character grant replacement and preserves a valid grant on
  cancellation; the interim corporation-zero state is not treated as departure.

### Profile and roster criteria

- **AC9 (R9):** F2 current tax values render 10%/5.6%, optional CEO/alliance/date
  stay absent, and the legacy fractional adapter renders 0.10 as 10% without any
  magnitude heuristic. Public overview loads independently of SDE/private scope.
- **AC10 (R10):** The roster uses only returned members, reports count mismatch,
  and selects the current employment episode or permitted tracking date exactly
  as F2; old matching employment is never used as a current join date.
- **AC11 (R11):** Role/title/tracking enrichments fail/lock independently; unmatched
  enrichment rows do not create members and title labels confer no authority.
- **AC12 (R11):** Activity displays observed timestamps/ships/locations with age;
  missing/future timestamps remain Unknown and 7/30/90-day filters use UTC boundaries
  without claiming current online state or productivity.
- **AC13 (R12):** Own division role matrix preserves all role dimensions and the
  optional standings card explicitly identifies personal NPC standings, without
  promising corporation inventory or docking access.

### Asset criteria

- **AC14 (R6, R13):** Failed/missing/mixed-generation asset pages cannot replace a
  complete inventory. Identical duplicate rows coalesce; conflicting duplicates
  fail publication. Successful complete empty inventory is a distinct empty state.
- **AC15 (R14):** F3 locations/divisions use parent/flag evidence, custom or default
  names, and separate deliveries/asset safety/unassigned roots. The view never claims
  that asset locations enumerate every rented office.
- **AC16 (R15):** Nested, orphan, cyclic/self-linked and >64-edge assets terminate
  deterministically, remain visible once and satisfy F3's count/value conservation.
- **AC17 (R16):** F3 value includes each priced goods row once, excludes office/BPC
  and unknown quantities/prices, uses exact decimal totals and separately labels
  stale prices at 24h. Missing value is not zero or an adjusted-price fallback.
- **AC18 (R7, R17):** Item/custom-name search preserves ancestor context without
  duplicate match/value counts; unresolved names and denied name lookups remain
  usable without numeric IDs or leaking another character's private names.

### Structure and fuel criteria

- **AC19 (R18):** Station Manager structure status works without Director/assets;
  optional/missing/empty/cleanup/unknown services and states remain distinguishable.
- **AC20 (R19):** Reported state timers, configuration windows and unanchor times
  are distinct; elapsed timers show Awaiting updated state without inventing state
  transitions, actual reinforcement events or abandoned status.
- **AC21 (R20):** F4 sums only qualifying direct StructureFuel rows into observed
  block counts, retains per-type/other-resource quantities and uses the asset clock;
  denied, absent or incomplete fuel observations remain Unavailable.
- **AC22 (R21):** Supported ordinary service models apply verified group-specific
  hull bonuses; unknown/ambiguous consumers return Not modeled. Manual estimates
  follow validation, ownership and cancel/save behavior, with no upstream mutation.
- **AC23 (R21):** F4 rate/day/endurance arithmetic, zero-rate/zero-quantity behavior
  and display rounding hold exactly, with static observation-time anchoring and
  compatible snapshots. Estimated endurance never replaces ESI expiry or establishes
  all-resource operational uptime.
- **AC24 (R22):** Fuel severity at exact 72h, 24h and zero matches F4, missing expiry
  is Unknown and an old expiry never proves an empty bay or service shutdown.
- **AC25 (R22, R23):** F4 episode rearm/acknowledgement/expiry-correction behavior
  yields one native delivery per critical episode across processes and restarts.
- **AC26 (R5, R23):** Stale/denied/deleted/unselected contexts cannot emit new alerts;
  native denial leaves in-app warnings, and resume checks access/data before overdue
  delivery. No closed-app monitoring guarantee appears in the UI.

### Wallet criteria

- **AC27 (R24):** Seven divisions render in stable order; missing names use Division
  n and missing balances remain Unknown. F5 complete total and partial subtotal
  differ in label/coverage; Accountant access does not require Director-only names.
- **AC28 (R25, R28):** Journal all-page publication, 30-day upstream limit, retained
  historical bounds and gaps are explicit; absent amount/balance stays null and
  expiry of local 365-day retention does not imply upstream recovery.
- **AC29 (R26):** Transaction cursor iteration progresses or reports an error;
  same-boundary duplicates do not duplicate entries. Buy/Sell, gross and valid/missing
  journal links follow F5 without adding trades again to journal cash totals.
- **AC30 (R27):** F5 exact decimal inflow/outflow/net/gross and half-open date
  filters hold; null amount coverage is disclosed and current balance is never
  reconstructed from filtered history.
- **AC31 (R24–R28):** Wallet rows/caches are scoped to owner/corporation/division
  and kind. A failed or denied division does not clear or impersonate another,
  and personal wallet storage cannot collide with corporate identities.

### Refresh, presentation and implementation criteria

- **AC32 (R6, R8):** Both refresh gestures, active-view scheduled work and optional
  monitoring share durable request coordination; no duplicate per-engine requests
  or refresh-spinner leaks across success, failure, lock, cooldown and cancellation.
- **AC33 (R6, R8):** F6 200/304/failure/header-age behavior preserves separate
  payload, validation and source clocks. HTTP freshness does not silently extend
  another capability's authorization or cover unvalidated pages.
- **AC34 (R6, R8):** F6 server-cache deadlines, 420/429 limits, Retry-After, timeout/
  5xx backoff and bounded paging are honored across engines; manual refresh cannot
  bypass them or rotate characters to escape limits.
- **AC35 (R7, R30):** Every data state resolves identities or uses contextual
  unknown labels, including tooltips, semantics, errors, text markup and native
  alerts. SDE/name outages do not block unrelated authorized information.
- **AC36 (R29):** F8's 320/600/900/1200px widths at 100%/200% text scale support all
  views, tabs, dialogs, filters and character switching without horizontal page
  overflow, inaccessible controls or clipped critical values.
- **AC37 (R29, R30):** Keyboard/screen-reader navigation, ≥48px targets, visible
  focus and non-color severity/access labels work in loading/error/locked/empty/
  populated states. Exact §6.6 feedback reflects the actual outcome.
- **AC38 (R8, R31):** Forward migrations and owner cleanup preserve unrelated
  application data; pure domain services contain calculations, guarded `.when()`
  handles async UI and tagged logs contain no credential or private-payload dumps.
- **AC39 (R32):** Recorded full-size cached/search/hierarchy measurements meet
  the stated budgets, or Plan records and resolves a release-blocking exception;
  a small mock fixture does not satisfy performance evidence.
- **AC40 (R1–R32):** The mapped Domain, Provider, UI and Oracle cases in §8 pass
  with synthetic data through their assigned real boundaries. Tester records
  responsive/native-window evidence; no management writes or unapproved scopes
  appear as part of this read-only module.

## 8. Test scenarios and synthetic fixtures

### 8.1 Test-author contract

Use a frozen injectable clock, synthetic names/IDs, fake ESI transport with real
status/headers/body parsing, in-memory/on-disk test Drift databases, real providers
and the actual Corporation subwindow host. No live account, corporation token,
market quote or member data is required. Pure tests must not duplicate production
formulas without independent expected constants. At least one service/provider
test for every required endpoint proves its real request path, granted scope,
role gate, tenant/context and cache/publication behavior.

The matrix contains **60 cases**: Domain D01–D20 (T01–T20), Provider P01–P20
(T21–T40), UI U01–U12 (T41–T52), and Oracles O01–O08 (T53–T60). T aliases are
stable handoff identifiers; retain the layer-specific IDs when assigning work.
Parameterized rows cover all listed variants, not a single representative example.
The fixtures below use simplified domain records unless explicitly called wire
payloads; transport fixtures must include all required fields in the pinned schema.

### F1 — Character, role and scope matrix

Tenant Tranquility; corporation **Helios Research** key 7001; alternate corporation
**Selene Works** key 7002. T0=`2026-09-15T12:00:00Z`. All rows below are current
members of Helios, have a fresh role observation and the requested feature scopes
**actually granted**, except the explicit scope case. Each private capability
still needs its own successful first ESI response before content appears.

| Character | General roles | Expected preflight behavior |
|---|---|---|
| Ada (1) | None | Public profile, own access/standings and basic roster allowed; assets, tracking, corporate titles, division names, structures and wallets locked. Role-list access only through explicit check. |
| Bea (2) | Personnel_Manager | Ada's capabilities plus corporation roles; tracking and other Director features locked. |
| Cyra (3) | Director | All requested read capabilities eligible; missing individual scope still blocks its request. |
| Dara (4) | Station_Manager | Structure status/expiry eligible; assets/fuel quantities and wallets locked. |
| Eren (5) | Accountant | Wallet balances/journal/transactions eligible; corporate asset and division-name requests locked. |
| Finn (6) | Junior_Accountant | Same wallet read eligibility as Eren; no transfer action or asset request. |
| Gale (7) | Director, but wallet scope only requested, not granted | Wallet Authorization required; Director is not a substitute for consent. |
| Hana (8) | Account_Take_ 2, Hangar_Query_ 2 | Own matrix shows those assigned roles, but corporation wallet/assets API remain locked. |
| Iona (9) | None; grantable status not in own-role response | Explicit role-list check returns 200: role list only becomes available. Alternate check 403: Access denied, no repeated automatic probes. |

Ada's extra role sets: HQ `[Hangar_Query_ 1]`; Base `[Hangar_Take_ 2]`;
Other `[Container_Take_ 3]`. Expect four distinct sets, no global inventory grant.
Replace HQ roles with `[Director]` in a malformed fixture: it must not unlock
Director-only endpoints. Public CEO points at Ada in a separate case; no automatic
unlock occurs from that public identity match. With matching scopes, her explicit
CEO Check access probe returning 200 makes only that endpoint readable for one
hour; returning 403 exposes no private payload and suppresses repeated probes.

### F2 — Profile, join dates and activity

Current wire-profile fixture:

```json
{
  "state": "active", "type": "player_owned", "name": "Helios Research",
  "ticker": "HELI", "description": "Research and logistics",
  "home_station_id": 6001, "member_count": 3,
  "tax_rates": {"isk": 10, "loyalty_point": 5.6},
  "shares": 1000, "war_eligible": true, "friendly_fire": "illegal"
}
```

Name resolver maps station 6001 to **Alpha Station**. Expected ISK tax **10%**, LP
tax **5.6%**, member count **3**, CEO/founded date unavailable, no raw zero ID.
Legacy adapter fixture `tax_rate=0.10` also gives 10%; current `tax_rates.isk=0.10`
gives **0.1%**. Current 101 or NaN is invalid, never 10,100% or zero. An unknown
future corporation type has an explicit unknown state rather than NPC assumptions.

Roster `[1,2]` contains only Ada and Bea despite public count 3. Ada's history:
record 9 Helios start `2026-09-01T00:00:00Z`, record 8 Selene start `2026-08-01`,
record 7 Helios start `2026-01-01`. Expected current join September 1, not January 1.
Bea's latest record is Selene despite a previous Helios record: Join date unavailable.
An authorized Ada tracking `start_date=2026-09-02T00:00:00Z` takes precedence with
tracking provenance. Unmatched tracking character 99 does not extend the roster.

At T0, Ada's last login is exactly `2026-09-08T12:00:00Z`; Bea's is absent.
“Last login within 7 days” includes Ada (age ≤7 days), excludes Bea; **Not reported**
contains Bea. At T0+1ms Ada is outside that filter. Future login T0+1h becomes
Unknown/data warning. Login T0−1h and logout T0−2h does not render Online now.

### F3 — Asset graph and exact valuation

All rows share one complete authorized asset revision. `item` location means an
item parent; station root 6001 resolves to Alpha Station. Type labels/prices:
100=Small Container/100 ISK; 101=Test Ammunition/2.50; 4051=Nitrogen Fuel Block/10;
102=Test Ship/500; 103=Test Module/50; 104=Test Blueprint/999; 9999=unresolved/unpriced.

| Item key | Type | Quantity | Location/type | Flag / extra |
|---|---|---:|---|---|
| 1000 | Office reference | 1 | 6001/station | OfficeFolder; administrative |
| 1100 | 100 | 1 | 1000/item | CorpSAG2; custom name Supply Crate |
| 1110 | 101 | 10 | 1100/item | Cargo |
| 1120 | 4051 | 4 | 1100/item | Cargo |
| 1200 | 102 | 1 | 1000/item | CorpSAG1 |
| 1210 | 103 | 1 | 1200/item | HiSlot0 |
| 1220 | 104 | 1 | 1000/item | CorpSAG1; is_blueprint_copy=true |
| 1300 | 101 | 2 | 999/item | Cargo; orphan |
| 1400 | 101 | 1 | 1401/item | Cargo; cycle |
| 1401 | 101 | 1 | 1400/item | Cargo; cycle |
| 1500 | 9999 | 3 | 6001/station | CorpSAG7 |

Expected: 11 distinct rows, 10 goods rows, 8 priced goods, 2 unpriced goods; office
is excluded from goods coverage. Division 2 subtotal **165.00 ISK** (100+25+40),
Division 1 **550.00 ISK** with one unpriced BPC, unresolved subtotal **10.00 ISK**,
Division 7 unpriced. Global **Priced subtotal: 725.00 ISK; 2 unpriced items**
(“items” here is row count). Never include the container subtotal a second time.
Search Test Ammunition finds 1110/1300/1400/1401, four matches, priced value 35.00;
ancestor context is not additional matches. A 65-edge chain renders safely in the
unresolved group after the depth bound, without losing rows or duplicating value.
Negative quantity for 1110 removes its 25.00 from priced coverage and shows unknown
quantity; a missing quote for 103 removes 50.00, never substitutes adjustedPrice.

### F4 — Fuel, service model and alert boundaries

T0 as F1. Structure **Alpha Works** key 8001, reported expiry
`2026-09-18T00:00:00Z`: **216000 seconds, 60h, 2.50 days**, Low.
At T0+30m:59.5h. Station Manager without assets still sees that countdown.

Complete Director asset fixture for direct parent 8001:
1000 Nitrogen blocks and 440 Oxygen blocks with `StructureFuel`; plus 20 Liquid
Ozone in that bay, 500 blocks in CorpSAG1, 200 blocks in a ship's SpecializedFuelBay
and 100 blocks inside a container. Expected observed blocks **1440**, with two
typed block rows; ozone separate, all reserve/ship/container blocks excluded.
Removing qualifying rows makes block quantity Unavailable; explicit quantity 0
produces a known zero. A failed page preserves the earlier observation.

Supported consumer fixture: Raitaru, Manufacturing Plant and Research Lab both
proven online, each group 1415/base 12, scoped reduction 25%. Both source times are
T0 in the same completed round. Expected each 9 blocks/h, total **18/h**, **432/day**,
and 1440/18=**80h**, **3.33 displayed days**, labeled Stock endurance at T0.
At T0+1h, the stored/pure dated result remains 80h and observed quantity remains
1440; it does not become a fresh 80-hour countdown. The UI locks at its access
deadline unless required role, structure and asset validations renew. For the
visible-result variant, renew them with authorized all-page 304s in one compatible
round, preserving source times and the original Stock endurance at T0 caption.
A new consumer observation at T0+10m
paired with old stock makes combined endurance unavailable; after compatible
fresh stock and one online consumer at 9/h, 1440 blocks give 160h. Missing source
time also fails compatibility. At exactly five minutes of source skew the pair
qualifies if otherwise fresh/in the same round; five minutes plus 1ms does not.
ESI expiry stays 60h at T0 and remains the alert source. Add an unknown consumer or ambiguous
service mapping: rate/endurance Not modeled. An unrelated service group receives
no 25% reduction. A reactor base online charge remains 864 rather than 15×72=1080.

Manual scenario 1440 blocks, 20/h: **480/day**, **72h**, **3.00 days**. Q=0,R=20
gives 0h; Q=1440,R=0 gives No modeled consumption and null endurance. Q=−1,
Q=1.5,R=NaN,R=0.1234567 fail validation. Calculate with 18/h then Cancel leaves
prior saved 20/h intact; Calculate then Save estimate changes only the scenario,
not 1440 observed blocks or ESI expiry. Reopening retains its saved assumption time.

Severity test uses remaining values:72h+1ms Normal;72h Low;24h+1ms Low;24h Critical;
1ms Critical;0 and−1ms Reported expiry passed; missing expiry Unknown. Use fresh
authorization/structure validation for each isolated severity-to-notification test.
Episode sequence: first fresh 23h emits 1; repeat 23h, correction 22h, acknowledge,
reopen and countdown 0 emit 0 further; fresh 48h rearms; fresh 24h emits 1 more.
Two engines claim the same episode: exactly one native delivery, two consistent
card states. Stale or expired-access variants emit zero native deliveries.

### F5 — Wallet amounts, identity and coverage

One complete balance response for divisions 1–7:
`[1000.10,200.20,0.00,-10.05,5.55,4.20,300.00]`.
Expected **All divisions: 1500.00 ISK**. Remove division 7: **Known balances subtotal:
1200.00 ISK (6/7)**; Division 7 Unknown. Division 3 displays 0.00. Custom names only
for division 2 **Logistics**, division 7 **Reserves**; all others use Division n.
An out-of-range division 8, conflicting duplicate division 2, missing required
balance or nonfinite balance invalidates publication; prior balances remain.
An identical repeated division 2 coalesces. Invalid names fall back independently.

For division 2, interval `[2026-09-15T00:00:00Z,2026-09-16T00:00:00Z)`:

| Journal ID | Timestamp | Amount | Balance |
|---|---|---:|---:|
| 101 | September 15 00:00Z | +100.10 | 200.20 |
| 102 | September 15 01:00Z | −25.05 | null |
| 103 | September 15 02:00Z | +0.10 | null |
| 104 | September 15 02:00Z | +0.20 | null |
| 105 | September 15 03:00Z | null | null |
| 106 | September 15 04:00Z | −10.35 | null |
| 107 | September 16 00:00Z | +13.00 | null |

Six included rows: inflow **100.40**, outflow **35.40**, net **65.00**, one unknown
amount. Newest order 106,105,104,103,102,101. ID107 excluded by end boundary.
Balance card remains independently 200.20, not 65.00 or a reconstruction from 101.

Transaction 900: quantity 3, price 1.005, is_buy=true, journal_ref_id 102; exact gross
**3.015**, displayed **3.02 ISK**, Buy. Transaction 899: quantity 2, price 10.00,
is_buy=false, journal_ref_id−1; gross 20.00, Sell, no journal link. The journal net
stays 65.00 after both trades load. Same ID101 in division 3 or personal wallet is
another record. Identical repeated division 2 ID101 coalesces; conflicting amount
fails that publication. Cursor pages `[900,899]`, `[899,898]`, `[]` produce three
unique trades, with calls from_id 899 then 898 and no infinite loop.

### F6 — Cache clocks, authorization and transport

At T0 a complete assets response and fresh roles validation succeed. Both lease
deadlines are T0+1h. With default 1h cache TTL, offline read at T0+59m59.999s is
allowed with age; at exactly T0+1h private assets lock. A grant/role denial at
T0+10m locks immediately. Public profile remains readable with a dated cache.

At T0+1h, authorized 304 for every required asset page and own roles renews access
through T0+2h. `payloadReceivedAt` remainsT 0, successful validation becomesT 0+1h;
upstream source time remains unchanged if headers say so. Only page 1 revalidated
does not qualify a complete-list renewal. Network failure renews neither lease
nor validation; DB failure after 200 also renews neither. Wallet balance 304 cannot
renew the asset lease.

Separate header fixture received at T0: `Date=T0−120s`, `Age=120`,
`Cache-Control:max-age=3600`, no Expires. Correct apparent/current age is 120s,
freshness deadline **T0+3480s (12:58Z)**, not 13:00Z and not 12:56Z (do not double-count
Date and Age). Manual refresh at 12:30 makes no HTTP call. Conflicting cache metadata
uses the conservative valid freshness deadline and logs metadata inconsistency.

429 at 12:00 with Retry-After 120: request at 12:01 suppressed,12:02 eligible unless
another later cache/server deadline exists. A no-header timeout series has retry
delays 30,60,120,300,300 seconds. Concurrent AppBar/pull requests in two engines
produce one owned in-flight fetch for that exact context/endpoint. Page 1=2 pages,
page 2 fails or reports 3 pages: no replacement snapshot. Mixed Last-Modified pages
also fail. A paused 100-page inventory remains Incomplete inventory, not complete.

### F7 — Revocation, ownership and partial datasets

Cyra/Helios has assets revision A and structure private name **Alpha Works**. Ada
is the next selected character in the same corporation. Switch before Cyra's
delayed page 2 completes: Ada sees no asset rows/counts/names and no late snackbar
claiming her data updated. Cyra's old completion cannot publish into Ada's state.
Switch to Cyra/Selene after confirmed membership refresh: old Helios private rows,
scenarios and alerts are purged; another character's independent Helios rows survive.
Auth's temporary corporation 0 causes a resolving screen without this purge.

An ordinary token refresh with unchanged subject/scopes keeps the generation and
retained ledger. Same-character Helios reauthorization adding structure scope
creates a new generation and quarantines the old wallet history. Fresh wallet
authorization rebinds that history with its original timestamps/coverage; a scope
reduction removing wallet access purges it instead. No rebind grants access to a
different character or corporation.

Cyra's Director role is removed: assets/tracking/title/division-name data invalidates;
if Station Manager remains, revalidated structure status can continue. A structure
name-only 403 hides that lookup's value without clearing a still-authorized corp
structure record's own name/state. A wallet division 2 history failure preserves
division 3's valid data. Deleting Cyra in another window while Corporation is closed
removes her private ownership and blocks any returning request from saving.

### F8 — Responsive and asynchronous fixture set

Widths 320,600,900,1200px at100% and 200% text scale, minimum tested height 640px.
At each width/scale exercise: no character; loading/unresolved corp; ordinary
member locks; populated Director; Accountant without division names; Station
Manager without asset scope; empty; partial refresh; network error; expired lease;
SDE unavailable; unresolved public/private names. Long names are 80 characters;
currency example is **−1234567890123456.78 ISK** with grouping in the UI.

Expected: all four views and character selector reachable, no horizontal page
overflow, readable signed amount/severity, ≥48px targets, keyboard/semantic access,
AppBar and pull gestures, no raw entity IDs. At 600px the layout uses usable content
width, not outer-window width before a rail. Fuel scenario/detail sheets and
wallet filters must meet the same matrix. Native adapter test covers focus/reopen;
tester captures real macOS screenshots, including 320px-equivalent layout and 200%
text scaling where native minimum-window limits require a constrained test surface.

### 8.2 Domain matrix

| Case / alias | Exact input and expected outcome | Acceptance |
|---|---|---|
| D01 / T01 | F1 role/scope table: all nine characters yield listed preflight gates; no scope string means no endpoint request eligibility. | AC3, AC8 |
| D02 / T02 | F1 HQ Director, Account_Take_ 2, title named Director: none grants general Director/API reads; grantable and assigned sets stay separate. | AC4, AC13 |
| D03 / T03 | F6 access at expiry−1ms/equality and known denial: allow/lock/lock; no cache read extends deadlines. | AC5, AC6 |
| D04 / T04 | F2 current 10/current 0.10/legacy 0.10 tax inputs:10%/0.1%/10%; absent optional profile values stay absent. | AC9 |
| D05 / T05 | F2 history ordering/tracking precedence:September 1/Unavailable/September 2 with source labels; unmatched 99 absent from roster. | AC10, AC11 |
| D06 / T06 | F2 login ages at7days/7days+1ms/missing/future: included/excluded/Not reported/Unknown; no Online inference. | AC12 |
| D07 / T07 | F3 normal paths/divisions/custom names: exact ancestor and division outcomes; no fabricated rented office. | AC15 |
| D08 / T08 | F3 orphan, cycle, self-link and 65-edge chain: traversal terminates; each row contributes at most once and remains inspectable. | AC16 |
| D09 / T09 | F3 priced/unpriced/zero/BPC/negative quantity variants: qualified 725.00 base subtotal, no BPO/adjusted-price substitution. | AC17 |
| D10 / T10 | F3 Test Ammunition search:4matches,35.00 priced value; ancestors carry context only. | AC18 |
| D11 / T11 | F4 direct bay versus reserve/ship/container/resource rows:1440blocks, ozone separate; absence/null never becomes zero. | AC21 |
| D12 / T12 | F4 supported 2consumers=18/h; unknown/missing/cleanup/ambiguous consumer returns Not modeled; unrelated group gets no bonus. | AC19, AC22 |
| D13 / T13 | F4 manual inputs including boundaries, NaN and precision: reject invalid;0rate=null horizon; no upstream mutation. | AC22, AC23 |
| D14 / T14 | F4 exact 72h/24h/0severity and optional expiry: Low/Critical/Passed/Unknown; stale is separate. | AC24 |
| D15 / T15 | F4 alert sequence 23h→22h→0→48h→24h: two critical episodes total; acknowledge/correction never rearm. | AC25 |
| D16 / T16 | F5 missing/zero/negative balances and 6/7coverage: explicit 0 remains 0, subtotal is qualified, signed values preserved. | AC27 |
| D17 / T17 | F5 signed/null journal amounts, equal-date ordering and half-open filter: exact six included rows and unknown count 1. | AC28, AC30 |
| D18 / T18 | F5 trade gross, sentinel−1 and absent same-division journal: qualified gross/direction/link state; no cash-flow double count. | AC29, AC30 |
| D19 / T19 | F6 header age/backoff/page/cursor validation:12:58freshness, shared later deadline wins, non-progress fails. | AC33, AC34 |
| D20 / T20 | Unknown enum/required-invalid payload/unsafe rich text/name failure: preserve supported fields, fail invalid publication, sanitize labels without entity IDs. | AC35, AC38 |

### 8.3 Provider, storage and transport matrix

| Case / alias | Exact input and expected outcome | Acceptance |
|---|---|---|
| P01 / T21 | Public profile/name/history and own roles/title/standings requests use §5.2 paths, scopes, compatibility date and TTL; F2 tax adapter handles an absent CEO. | AC9, AC13, AC33 |
| P02 / T22 | F1 roster/roles/tracking/title/division requests exercise each gate; basic member succeeds without Director; denied enrichments leave the roster intact. | AC3, AC4, AC10, AC11 |
| P03 / T23 | F1 grantable-role and CEO checks return 200/403: at most one bounded probe per hour; success authorizes only that endpoint. Expired prior success permits a due probe with payload hidden. | AC4, AC5 |
| P04 / T24 | PKCE success/cancel/wrong-character/partial-scope return: actual grants persist and cancellation preserves the old grant. Ordinary token refresh preserves generation; added scopes quarantine then rebind authorized history. | AC8 |
| P05 / T25 | F7 no character, unresolved 0, NPC, closed and member states: no invalid corp requests; temporary 0 does not purge the prior corporation's payload. | AC2, AC8 |
| P06 / T26 | F7 character switch during await and confirmed departure: old data never appears in the new context; purge respects ownership. | AC7 |
| P07 / T27 | F6 lease expiry minus 1ms/equality, cold restart and expired role evidence: exact visibility gate; public stale profile remains readable. | AC6 |
| P08 / T28 | 401 refresh success/failure/network failure and capability 403: appropriate lock/retry/purge; secondary name denial affects only that lookup. | AC5, AC7, AC18 |
| P09 / T29 | F6 asset/structure page 2 error, mixed Last-Modified, conflicting duplicates, missing X-Pages and valid empty set: retain/partial/fail/replace as specified. | AC14, AC19, AC33 |
| P10 / T30 | Asset-name batch of 1001 IDs requires two read-only POSTs; unknown-name fallback and private structure denial never leak globally. | AC18, AC35 |
| P11 / T31 | Station Manager structures succeed with assets locked: expiry visible, no unauthorized fetch; complete Director assets supply a separately dated quantity. | AC19, AC21 |
| P12 / T32 | F4 Calculate→Cancel/Save and changed or incompatible source observations: preview never persists, save is owned, and stock endurance uses compatible dated evidence. | AC22, AC23 |
| P13 / T33 | F4 two-engine delivery, acknowledgement/restart/rearm and native denial: exactly one delivery per episode; in-app severity remains. | AC25, AC26 |
| P14 / T34 | Hidden/resume/quit/character switch with monitoring toggled: ordinary polling stops; only opted-in due monitoring runs; refresh precedes overdue alerts. | AC26, AC32 |
| P15 / T35 | Seven balances, denied custom names, malformed/duplicate division rows and selected journal failure: correct fallback/publication, other valid divisions preserved. | AC27, AC31 |
| P16 / T36 | Two journal pages, duplicates/null amounts, 30-day refresh and 365-day local pruning: correct retained coverage without reconstructed balances. | AC28, AC30, AC31 |
| P17 / T37 | F5 cursor pages, repeated boundaries, loops and mid-chain failure: three unique trades or an incomplete state; no false history coverage. | AC29, AC31 |
| P18 / T38 | F6 concurrent gestures/engines, all-page 304, failed DB commit, 429/420 and timeouts: one fetch, correct clocks/backoff, no lease on failed commit. | AC32, AC33, AC34 |
| P19 / T39 | Real migration, central deletion with window closed, missed event and delayed worker: owned rows gone; unrelated personal/other-character data preserved. | AC7, AC38 |
| P20 / T40 | 100000 synthetic assets on a recorded machine meet cached-load/search/traversal budgets; verify bounded paging/queries and sanitized tagged logs. | AC34, AC38, AC39 |

### 8.4 UI and native-window matrix

| Case / alias | Exact input and expected outcome | Acceptance |
|---|---|---|
| U01 / T41 | Real host/tray Window 15 registration, concurrent open/focus/hide/reopen: IDs 0–14 unchanged; public screen opens during SDE failure. | AC1, AC9, AC35 |
| U02 / T42 | F8 no character/resolving/NPC/closed/member and scope/role locks: exact §6.6 copy and eligible actions; no fake empty state or private counts. | AC2, AC3, AC5 |
| U03 / T43 | Real character switcher during F7 loading: no old private frame, filters reset, correct corporation; reauthorization cancellation preserves session. | AC7, AC8, AC36 |
| U04 / T44 | F2 profile/join/activity/enrichment locks and My access matrix: names, 10%/5.6%, role labels/provenance and personal NPC standings label. | AC9, AC10, AC11, AC12, AC13 |
| U05 / T45 | F3 tree/search/detail/empty/locked/unresolved states: qualified 725.00 subtotal, 2 unpriced rows, 4 ammunition matches and readable breadcrumbs/icons. | AC15, AC16, AC17, AC18 |
| U06 / T46 | F4 Station Manager fuel/status/services: expiry 60h without quantity; elapsed state timer says Awaiting updated state; cleanup/missing are distinct. | AC19, AC20, AC21, AC24 |
| U07 / T47 | Fuel estimate invalid/zero/Calculate→Cancel/Save and conflicting expiry: inline errors, exact save feedback, dated 72h endurance beside ESI 60h countdown. | AC22, AC23, AC37 |
| U08 / T48 | F4 acknowledgement/native opt-in/denied/stale/lease expiry: warnings and generic copy correct; no new alerts or private detail after lock. | AC6, AC25, AC26 |
| U09 / T49 | F5 balances/journal/trades/partial coverage: 6/7 subtotal versus complete 1500.00, signs/unknowns, Buy/Sell and Load older; no transfers. | AC27, AC28, AC29, AC30, AC31 |
| U10 / T50 | AppBar and pull across all views and populated/short/empty/error/locked states: shared refresh, exact success/partial/cooldown copy, finishing indicators. | AC32, AC33, AC34, AC37 |
| U11 / T51 | Full F8 width/text/state matrix, long names/amounts/dialogs, keyboard/screen reader and non-color badges: no overflow, raw IDs or inaccessible controls. | AC35, AC36, AC37 |
| U12 / T52 | SDE/name/network/permission loading→error→data races and sanitized markup: guarded rendering, usable unrelated public content, no fake values or leaks. | AC5, AC6, AC35, AC38 |

### 8.5 Independent oracle matrix

| Case / alias | Independent exact expected result | Acceptance |
|---|---|---|
| O01 / T53 | Enumerate F1 scope×role×lease×context variants: no private read without required evidence; Director still needs scope; 403 defeats a retained lease. | AC3, AC4, AC5, AC6, AC7 |
| O02 / T54 | F2 tax constants: current 10→10%, current 0.10→0.1%, legacy 0.10→10%; current employment record 9 and tracking override. | AC9, AC10 |
| O03 / T55 | F3 distinct values: 100+25+40+500+50+5+2.5+2.5=725; 8 priced, 2 unpriced, office excluded; permutations yield identical groups/totals. | AC15, AC16, AC17 |
| O04 / T56 | F4 expiry 216000s=60h; stock 1440; model 18/h→432/day→80h; manual 20/h→480/day→72h. Advancing time preserves dated stock endurance, not a new countdown. | AC21, AC22, AC23 |
| O05 / T57 | F4 threshold minus/exact/plus 1ms and 23→22→0→48→24h sequence: four known severities, Unknown for missing expiry, exactly two critical episodes. | AC24, AC25, AC26 |
| O06 / T58 | F5 complete balance 1500, missing division 7 subtotal 1200; 100.40−35.40=65.00; gross 3×1.005=3.015→3.02; one unknown amount. | AC27, AC28, AC29, AC30 |
| O07 / T59 | F6 Date/Age 120 with TTL 3600 leaves 3480s; lease locks at 3600s; all-page/role 304 renews validation only; backoff 30/60/120/300/300. | AC6, AC33, AC34 |
| O08 / T60 | F7 event-order permutations: switch/revoke/delete always reject old publication; datasets/names/alerts remain owned; valid other context unchanged. | AC7, AC31, AC38 |

### 8.6 Journey traceability and release evidence

| Journey | Primary criteria | Representative cases |
|---|---|---|
| S1 Ordinary member | AC1–AC4, AC9–AC10, AC13 | D01, P02, U01–U04 |
| S2 Personnel officer | AC3–AC4, AC10–AC11 | D02, P02–P03, U04 |
| S3 Director activity | AC10–AC12 | D05–D06, P02, U04 |
| S4 Asset search | AC14–AC18 | D07–D10, P09–P10, U05, O03 |
| S5 Structure fuel | AC19–AC24 | D11–D14, P11–P12, U06–U07, O04 |
| S6 Critical alert | AC24–AC26 | D14–D15, P13–P14, U08, O05 |
| S7 Accountant | AC27–AC31 | D16–D18, P15–P17, U09, O06 |
| S8 Own access | AC4, AC13 | D02, P01–P03, U04 |
| S9 Authorization change | AC5–AC8 | D03, P04–P08, P19, U03, O01, O08 |
| S10 Offline/responsive | AC6, AC32–AC39 | P07, P18–P20, U10–U12, O07 |

**AC40 is the release gate over all 60 cases.** Plan must assign explicit ownership
for shared window/auth/database/transport files before implementation. Test-Author
must preserve endpoint-specific assertions rather than substituting a single
unconditional “authorized” mock for every role. Tester records native launch,
actual character switching, responsive screenshots and an offline/revocation run.
No specification check substitutes for those implementation results.

**Troubleshooting expectations:** locked data with scope present should lead to
role/access evidence, not repeated login; fresh role evidence plus 403 should show
the server denial; empty fuel quantities with a valid expiry should explain asset
visibility; old wallet rows should show coverage gaps and retention; failed name
resolution should show a contextual unknown label while preserving valid numeric
measurements. Support can correlate tagged endpoint/status/revision logs without
collecting tokens or sensitive corporation payloads. All implementation gates
remain pending when this Product document is committed.

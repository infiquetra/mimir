# Exploration Module — authoritative Product specification

**Status:** Product contract; implementation and verification pending.

**Priority / release:** P2, Phase 4, exploration work associated with Sprints 21–22.

**Date / baseline:** 2026-09-15; `feature/exploration-module` at `aec65c6`.

**Audience:** Plan, Test-Author, implementation, review and tester.

## 1. Product perspective and scope

### 1.1 Problem and outcome

An explorer needs three different kinds of information at the same time: stable
reference facts about a wormhole, recent observations about a particular connection,
and private records of what the pilot scanned. Today Mimir has a small public
connections card but no complete offline reference, durable scan notebook or
combined stargate/wormhole route planner. Pilots must cross-reference tools and
remember which observations are still useful.

The Exploration Module lets a pilot identify a wormhole, inspect its system
effects, find a reported highway entrance, preserve scan results and plan a route
using the known connections. It must remain useful without network access.

**Governing principle:** Reference properties, reported observations and calculated
routes have separate provenance and freshness. Unknown information never becomes
“Fresh,” “Stable,” a fixed K162 limit, an empty system, or a guaranteed safe route.

### 1.2 Authority, phases and decisions

This specification governs the requested module. It supersedes conflicting examples
and phase ordering in these draft context documents, inspected at context-library
commit `3813f1a`:

- [Platform exploration specification](https://github.com/infiquetra/mimir-context-library/blob/main/platform-specs/03-feature-modules/exploration/specification.md).
- [Wormhole integration blueprint](https://github.com/infiquetra/mimir-context-library/blob/main/discovery/blueprint/17-wormhole-integration.md).
- [Implementation roadmap, Phase 4](https://github.com/infiquetra/mimir-context-library/blob/main/platform-specs/01-overview/implementation-roadmap.md).

| Delivery phase | Required outcome |
|---|---|
| **4a — Reference** | Offline wormhole catalog, system properties, exact effect modifiers and the universe/gate reference foundation. |
| **4b — Public highways** | Shared durable EVE-Scout Thera/Turnur feed, dual refresh, filters and nearest entrance using the gate graph. |
| **4c — Local signatures** | Character/system-scoped notebook, clipboard preview/import, editing, trash, pruning and explicitly verified local connections. |
| **4d — Routing** | Deterministic routes across the gate graph, eligible public connections and selected-character local connections. |

The user explicitly chose a **new tray-launched Exploration window with adaptive
navigation between its four views**. Do not introduce an app-wide feature shell
or turn the character rail into a feature rail. Phase 4c is local signature work;
the old draft's Tripwire phase is outside this release. Phase labels are dependency
boundaries, not a promise that the old week estimates fit the newly verified scope.

Other settled decisions:

- Use the verified public v2 EVE-Scout contract in §5. The legacy URL in the
  context documents returned HTTP 404 during this review.
- Pochven is a distinct space category, not C7 or ordinary nullsec. Thera is a
  special class-12 system. No filament planning is implied by a Pochven filter.
- Per-system static assignments need a separately sourced reference layer; they
  are not an SDE `isStatic` property of a wormhole type.
- A scanner row naming a wormhole does not establish its destination. Only an
  explicitly connected observation may become a route edge.
- Public and local records remain separate. This module does not submit pilot
  signatures, positions or credentials to a community mapper.

### 1.3 Current capabilities versus required additions

| Current seam at `aec65c6` | Reuse / required addition |
|---|---|
| [Window types](../../lib/core/window/window_types.dart), [window service](../../lib/core/window/window_service.dart), [subwindow host](../../lib/core/window/sub_window_app.dart), [tray service](../../lib/core/tray/tray_service.dart) | Add Exploration registration, icon/title/default window configuration and tray launch. Preserve existing window identifiers and single-window-per-type behavior. |
| [CharacterNavRail](../../lib/core/widgets/character_nav_rail.dart) | Retain character selection. Add separate module navigation within Exploration; current runtime is not the GoRouter shell described by older architecture prose. |
| [EveScoutClient](../../lib/features/intel/data/eve_scout_client.dart), [Thera model](../../lib/features/intel/domain/thera_models.dart), [Intel providers](../../lib/features/intel/data/intel_providers.dart) | Existing public-v2 fetch and card are useful seams. Add tolerant normalization, durable cache, freshness, expiry and a shared feed contract used by Intel and Exploration. |
| [SDE database](../../lib/core/sde/sde_database.dart), [SDE service](../../lib/core/sde/sde_service.dart) | Current schema 6 has types/dogma/industry, but no complete universe, wormhole systems or stargate graph. System-name/security methods contain placeholders. Build populated offline tables/imports; do not call placeholders “reference support.” |
| [Application database](../../lib/core/database/app_database.dart) | Current schema 20 has no exploration notebook/connection/route tables. Add transactional persistence and forward migration while preserving user data. |
| [ESI client](../../lib/core/network/esi_client.dart), [character status providers](../../lib/features/characters/data/character_status_providers.dart) | Location read exists but loses some error distinctions and lacks explicit freshness in consumers. Add a selected-character origin state with observation time and manual fallback. |
| [Cross-window events](../../lib/core/window/cross_window_events.dart) | Each window has its own engine/provider scope. Coordinate feed publication and invalidation; do not assume an in-process provider update reaches Intel's window. |

`solarSystemByNameProvider` can resolve exact cached names or call ESI; it is not
an offline searchable universe catalog. Existing waypoint writes default to
clearing waypoints; route planning must not invoke them. Existing kill caches and
the unpopulated `SystemActivity` seam cannot establish route safety.

### 1.4 Non-goals and release boundaries

No Tripwire/Pathfinder/Wanderer authentication or sync, corporate chain sharing,
interactive force-directed chain map, connection notifications, filament/cyno/
jump-bridge routing, automatic bookmarks or waypoint writes, automatic clipboard
monitoring, hacking minigame assistance, site-value estimates, polarization/mass
consumption simulation, or combat-safety prediction. Bookmark text is a local note,
not an in-game bookmark object. A list of route steps satisfies the route visual.

Fit-comparison visuals and prior AAR milestones are already implemented and merged.
This specification creates no new work or holds for those shipped initiatives.

## 2. User stories and operational workflows

### S1 — Identify a wormhole while offline

As an explorer, I search `b274`, `C140`, `K162` or a destination class, combine
destination and mass filters, and open a detail sheet. I see named properties,
units, source/version and special limitations immediately from local data. A K162
card explains the originating side is needed; it does not invent fixed limits.

### S2 — Understand the destination system

As a pilot entering a named J-space system, I inspect its class, effect family,
effect strength, exact modifier rows and recorded statics. I can distinguish a
missing effect record from a verified no-effect system. The beacon determines
applied effect strength; the system class alone does not. Community statics carry
their own source and never imply that a specific live connection is present.

### S3 — Find a Thera or Turnur highway connection

As a traveler, I open **Thera & Turnur**, select a hub and destination filters,
then inspect source/destination systems, region, security, each side's signature,
type orientation, reported time and estimated expiry. Refresh works by both pull
gesture and AppBar action. Cached content stays visible on failure, with its age.

### S4 — Find the nearest reported entrance

As a pilot, I choose **Use current location** or a system from the offline picker.
The finder ranks eligible public entrances by gate jumps to the non-hub endpoint,
under the selected security preferences. It says **2 gate jumps to entrance; then
1 wormhole jump to Thera**, rather than conflating the two distances. Missing
location permission offers manual origin. An isolated J-space origin receives an
honest no-gate-route result and a link to the full Route Planner.

### S5 — Import probe scanner results into a private notebook

As an explorer, I select my character and system, copy rows in EVE and press
**Paste scanner results**. A preview lists additions, updates, invalid rows and
conflicts. I explicitly import the selected valid rows. Existing bookmarks/notes
survive rescans; missing rows in a paste are not deleted. A character/system change
while previewing requires rebuilding the preview for the new context.

### S6 — Maintain and retire signatures

As a scanner, I add or edit a signature, record its type/name/bookmark/notes and
mark it seen again. I move an obsolete entry to Trash, restore it, or permanently
delete it after an explicit confirmation showing the selected entries. Automatic
pruning uses last observation time, moves old entries to Trash and explains what
happened. Editing a note alone does not pretend I re-observed the site.

### S7 — Turn a scanned wormhole into a usable connection

As a pilot who has verified the other side, I open a wormhole signature, resolve
its destination system, optionally enter the far-side signature, record known
type/status/estimated expiry, then choose **Confirm connection**. The route planner
can use that edge for this character. An unknown destination or an archived/
expired observation cannot create a shortcut. Marking the connection closed
removes it from routing without claiming every same-system connection collapsed.

### S8 — Plan and inspect a mixed route

As a traveler, I select origin/destination and preferences, calculate, and inspect
ordered gate and wormhole steps. Every wormhole step identifies its source,
correct departure-side signature and freshness. Avoid rules are hard exclusions;
Prefer Highsec can choose a longer route. If no route satisfies the rules, the UI
names the constraints and offers editable controls, never silently relaxes them.

### S9 — Resume under partial data, character changes or network loss

As a returning user, I retain my selected view and manual origin, see cached data
with age, and can use reference/notebook features offline. Public data remains
available without sign-in. Character changes isolate notebooks and local route
edges; calculations completing for a previous context cannot overwrite the new
screen. Stale observations require the explicit cached-data routing option.

## 3. Functional requirements

### 3.1 Phase 4a — Offline reference

**R1 — Complete versioned catalog.** Package the wormhole/reference data needed
for first-use offline lookup; do not require a runtime API warm-up. Cover all
wormhole type records in the selected CCP SDE manifest, including variants and
special destinations. Validate row counts/checksums against that manifest. An
update installs atomically and retains the previous usable reference on failure.

**R2 — Identity and units.** Store numeric EVE `typeId` separately from the visible
wormhole `code` such as B274. Show destination, nominal/reliable lifetime,
per-jump mass, nominal total mass, regeneration and supported static designations.
Keep source attribute/unit/conversion provenance. Exact kg and duration values
must be available in details even if compact cards abbreviate them. A reliable
lifetime is not a guarantee that an observed hole remains open until a countdown.

**R3 — K162 and variants.** K162 is a reverse-side designation with unknown fixed
limits unless an originating type is known. Do not use zero to mean unknown.
Multiple SDE IDs can share one code; show a code group and meaningful variants,
not arbitrary first-match data. Do not expose raw variant IDs as user-facing names.

**R4 — System taxonomy.** Keep the system's space category, raw wormhole class,
security value and effect identity separate. Support C1–C6, Thera/class 12,
Pochven/class 25 and other named special classes in the source. Inherit class
system → constellation → region where the source requires it. Do not classify
all negative-security systems as nullsec or apply C1–C6 effects to every special
class. Show an explicit Unknown category for unsupported future class values.

**R5 — Exact effects.** Expose all six families and strengths 1–6 with the exact
versioned modifier vectors, operation, target attribute, units and affected scope
in §4.2. Use the system's effect beacon to identify family/strength. Missing
modifier data is unavailable, not zero/no effect. Changes to SDE effects require
fixture review; no interpolation between strengths or approximate blanket bonus.

**R6 — Static assignments.** Model static designations as per-system assignments
with separately versioned source/coverage, not a universal property of a code or
class. The build may include a reviewed, redistributable community snapshot;
preserve attribution/date and distinguish confirmed catalog assignments, typical
class guidance and unknown coverage. Where no supported assignment exists, show
**Static information unavailable**. Never infer an active destination from a static.

**R7 — Search and filters.** Trim and case-fold text. Exact code/name matches rank
first, followed by prefix and substring; deterministic name/code order resolves
ties. Search codes, named destinations and system names; a system result opens
system properties. Destination and minimum per-jump-mass filters combine with AND.
**Capital-size mass limit** is shorthand for nominal per-jump mass ≥1,000,000,000 kg,
with a visible qualification that this is not ship eligibility or safe transit.
Unknown limits do not pass a numeric filter. A ship may exceed its nominal mass
and remaining connection mass is not calculated here.

### 3.2 Phase 4b — Public connections and nearest entrance

**R8 — Public feed.** Read the public v2 signatures endpoint without credentials.
Support both hubs and all reported destination categories, including J-space and
Pochven when present. Do not fabricate missing Pochven connections or use the old
unverified `systemType=pochven` parameter. Reuse the existing Intel seam through
a shared repository so both windows see the same durable observations.

**R9 — Endpoint orientation.** Normalize each feed record to hub and far endpoint
while retaining both systems/signatures. `out_system_id` is the hub; `in_system_id`
is the far system. `wh_exits_outward` identifies the side displaying `wh_type`;
it is not a one-way travel flag. Show departure-side signature/type for each route
direction. Missing far-side signature reads **Signature not reported**; it is
never replaced by the hub signature.

**R10 — Independent status dimensions.** Mass = Fresh/Reduced/Critical/Unknown;
time = Stable/EOL/Unknown, plus lifecycle Active/Past estimate/Closed/Unavailable.
The public v2 response does not provide observed mass state: display **Mass not
reported**. Derive **EOL estimate** when `0 < expiresAt - now < 4 hours`; exactly
4 hours is Stable estimate. At or after the estimate, label **Past reported
expiry** and exclude the edge, without claiming observed collapse. Record status
provenance; source unknowns never default to optimistic values.

**R11 — Cache and expiry.** Persist the public feed and metadata in SQLite.
Render cache immediately; revalidate under §5's single-flight/cooldown policy.
Fresh means age since last successful validation <5 minutes; at ≥5 minutes label
Stale. A validated 200 or 304 renews that clock; payload receipt/report timestamps
remain separate. Recompute ages and
expiry without network requests. Stale cache remains readable; routing uses it
only after **Use stale cached connections** is explicitly enabled and validation age
is <24 hours. At ≥24 hours public edges are view-only regardless of the option.
Past-estimate, closed and no-longer-listed records are never eligible under it.

**R12 — Filtering.** Hub selector: All hubs/Thera/Turnur. Destination chips:
All/Highsec/Lowsec/Nullsec/Pochven, plus J-space/Other so other feed records remain
discoverable. Select one category; combine it with region search and hub using
AND. Region matches are case-insensitive named substrings. Category uses the far
system, never the hub. All includes unknown categories with an Unknown label.
Default sorting is latest reported update descending, then resolved far name,
hub name and stable source record key. Filter-empty differs from feed-empty.

**R13 — Origin ownership.** Public/reference/manual-origin routing works without
an authenticated pilot. **Use current location** binds to the selected character,
fetches an ESI observation and exposes its observation time. A ≤60-second-old
observation is current for this UI; older/missing/error states require refresh or
explicit **Use last known location**. Manual origin is never overwritten by a
location refresh. Character changes invalidate character-derived origin and local
edges while preserving an explicitly manual origin. No silent cross-character data.
When a displayed CurrentCharacter observation becomes older than 60 seconds, mark
the origin/result outdated until refresh or explicit Last known selection. This
requires a local timer, not automatic ESI polling.

**R14 — Nearest entrance.** Run one gate-graph search from origin to eligible
non-hub endpoints. Check the subsequent wormhole/hub entry against the same
preferences, then rank the complete approach-plus-entry cost in R24. Avoid Lowsec
therefore excludes entry into Turnur even from a highsec far system. Display gate-hop
count separately from the one subsequent hub wormhole jump. If origin equals a
selected hub, show **Already in Thera/Turnur** for that hub; searches for another
selected hub still calculate normally. Exclude unreachable endpoints; unknown
distance is not zero. With an
isolated J-space origin, explain the gate-only limitation and open Route Planner.

### 3.3 Phase 4c — Local notebook

**R15 — Scope and editing.** Store signatures by character, system and normalized
signature ID, with independent observation episodes after retirement (§4.3).
Allow add/edit of type, name, bookmark text and notes; preserve explicit clears.
Known local characters can use their notebook offline without a valid token.
No selected character disables writes with **Select a character to track signatures**.

**R16 — Explicit clipboard import.** Read the clipboard only on Paste. Parse
standard tab-separated scanner rows using §4.3, accepting CRLF/LF and optional
English headers. Preview before any write, including row-level errors/conflicts.
Support manual correction or **Import N valid rows**. Never silently drop malformed
rows or truncate an over-limit paste. Cancel and failed persistence make no changes.

**R17 — Merge safety.** Upsert selected rows atomically into the pinned
character/system. Rescan preserves notes/bookmarks and resolved values when incoming
cells are blank or Unknown. Conflicting nonblank types/names require an explicit
per-row choice. Rows absent from a paste remain. A fresh rescan updates lastSeenAt;
editing metadata does not. Reapplying the same preview operation is idempotent.

**R18 — Retirement and deletion.** Default Delete moves an entry to Trash and
disables its owned local connection. Offer Undo and a Trash view with Restore.
Restore does not reset lastSeenAt or revive an expired route edge. Permanent delete
requires an explicit UI confirmation naming the selected count; only those scoped
rows/owned edges are deleted. No automatic hard deletion in this release.

**R19 — Automatic pruning.** Default enabled threshold 24 hours since lastSeenAt;
support 24/48/72 hours or Off, per character. At age ≥threshold, atomically move
active rows to Trash with reason **Auto-pruned**. Run on notebook load/resume and
hourly while its window is active, not through a background OS daemon. Review
counts and Trash remain available; note edits do not postpone pruning. Pruning
must not race a rescan into deleting the newer observation.

**R20 — Confirmed local links.** Only active wormhole signatures can own a
connection. Require resolved distinct endpoints and explicit **Confirm connection**;
destination cannot be extracted from arbitrary site names. Record verifiedAt,
optional far signature, originating type and its observed side, mass/time observations and estimated
expiry. Unknown statuses remain unknown. Verification expires for routing after
24 hours even if notebook pruning is Off. **Verify again** refreshes that timestamp;
merely pasting the same scanner row does not verify the other side or its mass.
Changing a signature from Wormhole to any other type atomically retires its owned
edge, whether through a form or a resolved import conflict. Changing it back does
not revive the edge. Changing link endpoints or originating-side identity clears
eligibility until explicit reconfirmation; old signatures/verifiedAt cannot authorize
the new link. Restoring a signature leaves its link retired until Verify again.

### 3.4 Phase 4d — Routes

**R21 — Graph and scope.** Build a multigraph from the packaged stargate topology,
eligible public connections and the selected character's eligible local links.
Other characters' private observations do not participate. Use actual gate edges
and direction; validate reciprocal links rather than inferring gates from nearby
positions. Public wormholes and confirmed local wormholes are traversable both
ways unless a supported restriction says otherwise. Distinct signatures between
the same systems are parallel edges. Never invent a gate through Thera or a route
from a static assignment. SDE graph coverage/version accompanies the result.

**R22 — Eligibility before optimization.** Exclude unresolved/missing endpoints,
incomplete/closed/retired records, public edges absent from the latest successful
snapshot, past reported expiry, local verification age ≥24 hours, and disallowed
stale public rows. Unknown status may remain eligible with Caution; **Avoid
Critical Mass** excludes known Critical, not every Unknown public record. Exclusion
reasons must be inspectable. No policy can resurrect a reported closed edge.

**R23 — Preferences.** Defaults: Avoid EOL On; Avoid Critical Mass On; Avoid Lowsec
Off; Avoid Nullsec Off; Prefer Highsec Off; Use stale cached connections Off.
The avoid controls are hard filters. Apply security exclusions to every entered
system, including destination and hub. Origin may already be in an excluded
category so the pilot can leave it, but re-entry is excluded. Pochven/J-space are
distinct categories; their risks remain visible even with Lowsec/Nullsec avoided.
Show Pochven/J-space explicitly rather than presenting this preset as “safe.”

**R24 — Deterministic objective.** Without Prefer Highsec, minimize
`(total jumps, sum of step risk ranks, canonical directed edge-key sequence)`.
With it, minimize `(entries into non-highsec systems, total jumps, risk-rank sum,
edge-key sequence)`. This is Mimir's declared preference, not a claim of parity
with EVE's in-game weighted Safer route. Unknown categories count as non-highsec; origin is not an
entry. One gate or wormhole transit counts as one jump. Lexicographic comparison
makes preferences exact and testable. Reuse this objective for the gate-only
approach in R14. Cycles, parallel edges and zero-step origin=destination work.

**R25 — Results and risk.** Return ordered steps with named systems, gate versus
wormhole, source, departure/arrival signatures, type, timestamps and status badges.
`totalJumps = gateJumps + wormholeJumps = steps.length`. Risk is a disclosed
heuristic: 0 Lower (gate entering known highsec), 1 Caution (wormhole/J-space, unknown data
or stale observations), 2 High (enter Lowsec/Nullsec/Pochven), 3 Very high (known
EOL/Critical). A step takes the maximum applicable rank; a route displays the
maximum of its steps, and uses the sum only for the R24 tie-break. No “Safe” badge
or travel-time guarantee. Exact mass remaining, actual ship transit eligibility,
polarization, gate-access conditions and other pilots are not modeled.
Security ranks describe entered systems; origin security remains visible separately.
An empty route displays **No travel required**, not a safety rating.

**R26 — Recalculation and failure states.** Calculate from one immutable graph,
time and preference snapshot. A source revision, expiry boundary, origin,
destination, character or preference change marks the old result outdated and
recalculates; never label stale steps current. A slower result cannot overwrite a
newer request. Distinguish **No route under these preferences**, **No route in
the available connection graph**, and **Route data unavailable**. Never silently
relax controls or report global unreachability from a partial graph.
Schedule local invalidation at public validation age 5m/24h, local verification age 24h,
the transition below 4h remaining, and reported expiry itself. Network activity is
not required to enforce these boundaries. Also invalidate CurrentCharacter origin
after its 60-second freshness boundary, retaining an outdated result for inspection.

### 3.5 Cross-cutting requirements

**R27 — Window integration.** Add the Exploration tray action/window registration
and responsive four-view navigation in §6. Preserve existing identifiers,
character selection and other window behavior. Reopening focuses the existing
Exploration window. No app-wide navigation migration.

**R28 — Accessibility and responsive behavior.** Meet §6's 320px, medium, desktop
and 200% text layouts. Names, warnings, action labels and all views remain
reachable without hover, color perception or horizontal page scrolling.

**R29 — Async and calculation separation.** Use explicit AsyncValue `.when()`
data/loading/error branches, including refresh-with-cache. No unguarded `.value`.
Pure domain classes/services own parsing, eligibility, expiry, filtering and
routing; widgets format already derived state and dispatch explicit actions.

**R30 — Name resolution.** Show wormhole codes and signature IDs, but never raw
numeric EVE IDs as substitute names. Resolve systems/regions locally from the new
catalog with `locationNameProvider` fallback; resolve types with `itemNameProvider`
and SDE. Unknown names remain human-readable placeholders; offline lookup must
not depend on ESI or today's placeholder SDE system methods.

**R31 — Logging and performance.** Use shared `Log` from
`package:mimir/core/logging/logger.dart` with `[EXPLORATION]` or its component tags.
Record operation IDs, source revisions, scoped entity IDs, counts/durations,
request status, validation failures and lifecycle transitions. Do not dump clipboard
text, bookmarks, notes or tokens. Warm offline indexed searches target p95 ≤100ms
over a full packaged catalog; pure routing targets p95 ≤1s on a documented desktop
test host with 10,000 systems/30,000 directed edges. Keep expensive work off the
UI frame path. These are measured release targets, not tight timing widget tests.

**R32 — Shared-state safety and explicit side effects.** Use atomic migrations,
scope-aware transactions and cross-window feed invalidation. Preserve Intel's feed
functionality without independent duplicate request loops. Viewing, filtering and
routing do not modify EVE waypoints, bookmarks, public reports or other characters'
notebooks. Character deletion must remove that character's private exploration
records through the existing deletion lifecycle; public/reference data remains.

## 4. Data models, entities and validation

### 4.1 Reference entities and provenance

Names below define product contracts; Plan owns concrete Dart/table names. Store
UTC instants and exact source values. Display local time with an accessible UTC
detail; perform age calculations against an injectable clock.

| Entity | Required fields / rules |
|---|---|
| `ReferenceManifest` | SDE build/release, dataset schema, source URLs, checksums, row counts, import time, coverage and validation result. Supplementary statics have a separate manifest. |
| `WormholeTypeReference` | Numeric typeId primary key; visible code; name; raw destination class and distribution; normalized destination or Special/Unknown; nullable reliableLifetimeSeconds, maxJumpMassKg, totalMassKg, regenerationKgPerCycle; source attribute IDs/raw values/conversions. |
| `SystemReference` | Numeric system/constellation/region identity, resolved names, security value/category, inherited class with inheritance source, effect beacon/visual type, effect/no-effect/unknown state, optional static assignments. |
| `GateEdge` | Stable gate identity, resolved from/to system IDs, topology version and applicable known restrictions. Preserve directed edges and validate endpoints against the same catalog. |
| `SystemEffect` | Family, strength 1–6, beacon type, exact modifiers with source attribute/effect, operation, units and affected scope. No unknown strength coerced into 1 or 6. |
| `StaticAssignment` | System ID, wormhole code or type/variant where known, assignment meaning, source/version/date, coverage and confidence. Typical-class information is a separately labeled reference, never a system assignment. |

The reproducibility baseline for this document is CCP SDE **3503375**, released
2026-09-10. Implementation may adopt a newer reviewed SDE, but must update the
manifest and regression expectations together; runtime UI must identify the
installed reference version. [CCP archive](https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip),
[SDE distribution guidance](https://developers.eveonline.com/docs/services/static-data/).

| Wormhole attribute | Meaning | Normalization |
|---|---|---|
| 1381 `wormholeTargetSystemClass` | Destination-class code | Preserve raw value and special behavior. |
| 1382 `wormholeMaxStableTime` | Reliable lifetime | Wormhole values are minutes: seconds = raw ×60, despite the generic declared time unit. Explicit conversion fixture required. |
| 1383 `wormholeMaxStableMass` | Nominal total mass | kg, nonnegative finite value; null distinct from zero. |
| 1384 `wormholeMassRegeneration` | Regeneration | kg per cycle; cycle duration is not established by this field. Do not convert to kg/s. |
| 1385 `wormholeMaxJumpMass` | Per-transit limit | kg, nonnegative finite value; null does not pass a mass filter. |
| 1457 `wormholeTargetDistribution` | Destination distribution reference | Separate identifier, not a class or a known live destination. |

Known baseline examples: B274/type 30677 has raw time 1440, total mass
2,000,000,000 kg and jump limit 375,000,000 kg. K162/type 30831 has no typeDogma
record. The 28 C729 type variants share a code; code-level values may appear only
where all grouped variants agree. I078/L687/O546 have raw time 270, hence 4.5 hours.
These are source fixtures, not hardcoded catalog replacements. Current CCP wording
distinguishes **Reliable lifetime** from observed closure, and C729's special
direction must not be inferred from older “leads to Pochven” prose.
[Pinned SDE](https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip),
[current mechanics notes](https://www.eveonline.com/news/view/patch-notes-version-23-02).

System classes 1–6 identify ordinary wormhole classes; 12 identifies Thera, 13
frigate shattered systems, 14–18 Drifter systems and 25 Pochven. Class codes
7/8/9 occur for known-space destinations. Type class −1 is special C729 behavior,
not a generic missing-value sentinel. Preserve all other special identifiers.
Per-system statics are absent from the official SDE; an unknown supplementary
assignment must remain unavailable. [CCP class/effect guide](https://developers.eveonline.com/docs/guides/staticdata/#wormhole-classes-effects).

After special-space identity overrides, classify ordinary known space from raw
security `x`: Highsec if `x ≥0.45`, Lowsec if `0 < x <0.45`, Nullsec if `x ≤0`.
Display one decimal, except positive values below 0.05 display 0.1. Never use a
rounded display string or `securityClass` as the classifier. Missing security is
Unknown. Catalog identity wins over a conflicting API hint, with the conflict
visible; unresolved conflicts cannot receive a lower-risk claim.
[EVE system-security guide](https://developers.eveonline.com/docs/guides/system-security/).

### 4.2 Exact effect reference contract

Select the applied effect through `mapSecondarySuns.effectBeaconTypeID`, then its
dogma record. The following vectors are exact percentage changes for strengths
1–6 in the pinned SDE. For multiplier attributes the displayed change is
`(multiplier − 1) ×100`. Preserve operation metadata, especially resonance.
The database must contain all 36 family/strength combinations and all applicable
modifier scopes; these tables specify visible reference content.
[Source: CCP SDE 3503375](https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip).

| Pulsar modifier (source attribute) | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Shield capacity (146) | +30% | +44% | +58% | +72% | +86% | +100% |
| Signature radius (652) | +30% | +44% | +58% | +72% | +86% | +100% |
| Armor damage resonance, all types (1465–1468) | +15% | +22% | +29% | +36% | +43% | +50% |
| Capacitor recharge time (1500) | −15% | −22% | −29% | −36% | −43% | −50% |
| Energy warfare strength (1966) | +30% | +44% | +58% | +72% | +86% | +100% |

Pulsar beacon IDs by strength: `30844, 30865, 30866, 30867, 30868, 30869`.

| Black Hole modifier (source attribute) | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Inertia/agility attribute (169) | +15% | +22% | +29% | +36% | +43% | +50% |
| Maximum targeting range (237) | +30% | +44% | +58% | +72% | +86% | +100% |
| Missile velocity (1469) | +15% | +22% | +29% | +36% | +43% | +50% |
| Maximum ship velocity (1470) | +30% | +44% | +58% | +72% | +86% | +100% |
| Explosion velocity (1483) | +30% | +44% | +58% | +72% | +86% | +100% |
| Stasis web strength (1969) | −15% | −22% | −29% | −36% | −43% | −50% |

Black Hole beacon IDs: `30845, 30850, 30851, 30852, 30853, 30854`.

| Cataclysmic Variable modifier (source attribute) | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Local armor repair amount (1495) | −15% | −22% | −29% | −36% | −43% | −50% |
| Local shield boost amount (1496) | −15% | −22% | −29% | −36% | −43% | −50% |
| Remote shield boost amount (1497) | +30% | +44% | +58% | +72% | +86% | +100% |
| Remote armor repair amount (1498) | +30% | +44% | +58% | +72% | +86% | +100% |
| Capacitor capacity (1499) | +30% | +44% | +58% | +72% | +86% | +100% |
| Capacitor recharge time (1500) | +15% | +22% | +29% | +36% | +43% | +50% |
| Remote capacitor transfer amount (1840) | −15% | −22% | −29% | −36% | −43% | −50% |

Cataclysmic beacon IDs: `30846, 30880, 30881, 30884, 30883, 30882`.
Strengths 4–6 deliberately do not follow ascending ID order.

| Magnetar modifier (source attribute) | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Maximum targeting range (237) | −15% | −22% | −29% | −36% | −43% | −50% |
| Tracking speed (244) | −15% | −22% | −29% | −36% | −43% | −50% |
| Damage multiplier (1482) | +30% | +44% | +58% | +72% | +86% | +100% |
| Explosion radius (1967) | +30% | +44% | +58% | +72% | +86% | +100% |
| Target painter strength (1968) | −15% | −22% | −29% | −36% | −43% | −50% |

Magnetar beacon IDs: `30847, 30860, 30861, 30862, 30863, 30864`.
Do not use the older +15%…+50% explosion-radius sequence.

| Red Giant modifier (source attribute) | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Heat damage (1485) | +15% | +22% | +29% | +36% | +43% | +50% |
| Overload bonus (1486) | +30% | +44% | +58% | +72% | +86% | +100% |
| Smartbomb range (1487) | +30% | +44% | +58% | +72% | +86% | +100% |
| Smartbomb damage; applicable bomb damage/drain/ECM strength (1488) | +30% | +44% | +58% | +72% | +86% | +100% |

Red Giant beacon IDs: `30848, 30870, 30871, 30872, 30873, 30874`.

| Wolf-Rayet modifier (source attribute) | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---:|---:|---:|---:|---:|---:|
| Armor HP (148) | +30% | +44% | +58% | +72% | +86% | +100% |
| Signature radius (652) | −15% | −22% | −29% | −36% | −43% | −50% |
| Shield damage resonance, all types (1489–1492) | +15% | +22% | +29% | +36% | +43% | +50% |
| Small weapon damage (1493) | +60% | +88% | +116% | +144% | +172% | +200% |

Wolf-Rayet beacon IDs: `30849, 30875, 30876, 30877, 30878, 30879`.

Interpretation requirements:

- Increased damage resonance worsens resistance. It is not a subtraction of
  resistance percentage points: `newResist = 1 − (1 − oldResist) × (1 + p/100)`.
  A 50% resist with +50% resonance becomes 25%, not 0%. This explanatory example
  is domain/reference logic, not a new fitting simulator.
- “Recharge time −50%” must retain the word **time**. Increased inertia is not
  an agility improvement. A positive percentage does not always receive green
  “benefit” styling; show meaning and scope.
- Retain actual dogma effect scopes, including the source's Vorton-specific
  effects (11946/11947/11948/11953). Do not label small-weapon or smartbomb bonuses
  as applying to every damage source. Applying environment modifiers to the
  fitting editor or AAR simulation is outside this release.
- All 25 class-13 systems in the pinned build use strength-6 Wolf-Rayet. Two
  visual/beacon mismatches are regression fixtures: J005926 → strength-1 Red Giant;
  J010569 → strength-1 Wolf-Rayet. Use the applied beacon, retain a diagnostic,
  and do not let the visual secondary sun override it.

### 4.3 Notebook, parser and lifecycle entities

| Entity | Required fields / constraints |
|---|---|
| `TrackedSignature` | Local UUID; characterId; systemId; normalized signature code; episode ID; scan group; type enum/raw label; nullable name/bookmark/notes; firstSeenAt, lastSeenAt, editedAt; Active/Trash state, retiredAt/reason. At most one active episode per character/system/code. |
| `LocalConnection` | Local UUID; owner character and signature episode; from/to resolved systems; endpoint signatures and observed type codes; nullable originating type/variant with side From/To/Unknown; independent mass/time observations with observedAt/source; estimatedExpiresAt; verifiedAt; Active/Closed/Retired. |
| `ImportPreview` | Operation ID; pinned character/system; observedAt; input digest; normalized selected rows; counts/errors/conflicts and source row numbers. No database mutation until explicit apply. |
| `NotebookPreferences` | Character owner; prune threshold 24/48/72h or Off; default 24h. Restore and write actions validate the current revision. |

**Field validation:** signature code matches `^[A-Z]{3}-[0-9]{3}$` after trim and
uppercase. Type enum: Unknown/Wormhole/Data/Relic/Gas/Combat/Ore. Name ≤256,
bookmark text ≤512 and notes ≤4096 Unicode characters; trim surrounding whitespace,
retain internal text and explicit user clears. Names/notes are plain text, not
executed URLs, HTML or commands. System selection must resolve to one catalog
system; ambiguous text cannot silently pick the first result. A connection cannot
link a system to itself. An estimate already in the past can be saved as historical
information but makes that connection ineligible for routing.

**Supported scanner syntax:** tab-separated 2–6 cells:
`ID, scan group, optional type, optional name, optional signal strength, optional distance`.
Accept `Cosmic Signature` and `Cosmic Anomaly` scan groups case-insensitively.
English type labels map to the enum, with `Data Site`, `Relic Site`, `Gas Site`,
`Combat Site`, `Ore Site` and `Wormhole`. Empty or unfamiliar type is Unknown and
retains the original label. Unknown scan-group labels, bad IDs or >6 columns are
row errors. Optional signal/distance cells are informational and do not establish
mass, destination, coordinates, site value or physical disappearance. Header rows
beginning `ID\tGroup` are recognized; blank lines and a leading BOM are ignored.
For localized exports, an unsupported scan-group label is a row error; an
unfamiliar type under a supported group is accepted as Unknown with its raw label
and warning. Do not guess translations. Manual entry remains available.

Maximum paste: 512 KiB UTF-8 and 5,000 nonblank rows. Reject a larger paste as a
whole before preview; do not truncate. No whitespace-splitting fallback, which
would break site names. Preserve row numbers for errors. Duplicate normalized IDs
within a batch coalesce when values agree or one is Unknown/blank; conflicting
known values require resolution. Existing notes/bookmarks never come from scanner
cells. Rescanning updates lastSeenAt even when equipment/site details are unchanged;
classify that as **Seen again**, separately from **Updated details**.

A row matching only a Trash episode defaults to a **New observation** with a new
episode; old notes are not silently attached to a potentially reused signature ID.
An explicit Restore is available in Trash. If an active episode now uses that code,
Restore reports a conflict rather than replacing it. Restore alone does not refresh
observation/verification time. Marking a row Seen again does not reactivate a Closed
connection; the user must verify it separately.

The local connection form separates **Type seen here**, **Known originating type**
and **Originating type side** (This system / Other system / Unknown). A pilot
confirming from K162 can record that observation without inventing the other code.
Given known B274 on Other system, the reverse route displays B274 there and K162
here. Unknown side remains Unknown; contradictory observed codes/side selections
require correction. No previous verified orientation carries onto changed endpoints.

Import commit checks pinned scope and row revisions in the transaction; concurrent
edits produce a new conflict preview rather than overwriting them. Prune reads and
checks lastSeenAt in the same transaction as retirement. Atomic rollback on failure
preserves all preexisting rows; UI success follows commit. Hard deletion cascades
only to owned local links and their route-cache references, never to public data.

### 4.4 Public observations, refresh and route snapshots

| Entity | Required contract |
|---|---|
| `PublicConnection` | Provider + opaque normalized record key; hub/far systems and signature codes; whType and orientation; ship-size category; created/updated/completed times; reported expiry; raw category labels; normalized independent statuses; source validation/coverage; snapshot revision and availability. |
| `FeedSnapshot` | Provider/query scope; accepted normalized records; payloadReceivedAt and lastSuccessfulValidationAt; server cache metadata/validators; last attempt/error; retryAfter; revision. Freshness uses validation time; failures renew neither timestamp. |
| `OriginSelection` | Manual / CurrentCharacter / LastKnownCharacter; resolved system; character owner when relevant; observedAt and error/freshness state. |
| `RouteRequest` | Origin, destination, selected character or none, preferences and operation ID; reference/feed/notebook revisions; calculation time. |
| `RouteResult` | Ordered directed steps, counts, cost tuple, maximum risk, limitations, excluded-edge summary and input fingerprint; calculatedAt and outdated state. Persisted results, if any, must revalidate before reuse. |

Zero and null differ. No graph node is identified by display name alone. Different
public IDs or local signatures may describe parallel connections and must not
collapse merely because endpoints match. Exact duplicate provider keys must agree;
contradictory duplicates make a feed refresh invalid. Source conflicts cannot be
resolved by selecting whichever status looks safer.

## 5. External API contracts, cache and rate limiting

### 5.1 Verified EVE-Scout endpoints

Public read-only probes on 2026-09-15 and the provider's OpenAPI **2.1.55** establish:

| Endpoint | Contract / role |
|---|---|
| `https://api.eve-scout.com/v2/public/signatures` | Production GET, no authentication; JSON array for both hubs. Observed HTTP 200 and `Cache-Control: public, max-age=300`. Primary runtime feed. |
| Same endpoint with `?system_name=thera` or `?system_name=turnur` | Documented optional hub filter. Prefer one all-hubs request shared by both views; local filters do not generate extra HTTP calls. |
| `https://api.eve-scout.com/v2/public/wormholetypes` | Public reference endpoint; documented TTL 86400. Optional cross-check, not a required runtime dependency for the offline SDE reference. |
| `https://api.eve-scout.com/v2/public/systems` and `/v2/public/routes` | Documented public services; outside this release's routing data path. Local routing must work offline and does not send origin to these endpoints. |
| `https://www.eve-scout.com/api/wormholes` | Legacy context URL returned HTTP 404; do not implement it or an automatic fallback to its assumed schema. |

[API documentation](https://api.eve-scout.com/ui/),
[OpenAPI root](https://api.eve-scout.com/ui/openapi.yaml),
[public-signature contract](https://api.eve-scout.com/ui/paths/public/signatures.yaml),
[signature schema](https://api.eve-scout.com/ui/schemas/signature_representation.yaml).

The older Signal Cartel repository describes staging example generation; production
must never request `examples`, use randomized staging data or fall back to demo
connections. Do not implement unverified Pochven or private mapper endpoints.

### 5.2 Normalization rules

| Source field | Required interpretation |
|---|---|
| `id` | OpenAPI declares integer; live JSON also uses decimal strings. Accept positive integral number or decimal string and normalize to a provider-scoped string key without lossy floating-point conversion. |
| `out_system_id`, `out_system_name`, `out_signature` | Hub endpoint. Known hubs are Thera 31000005 and Turnur 30002086. Resolve/display names, not numeric IDs. The old blueprint's Turnur number is not authoritative. |
| `in_system_id/name`, `in_region_id/name`, `in_signature` | Far endpoint/region/signature. Use catalog identity and source names as fallback; retain absent optional fields as unknown. |
| `wh_type`, `wh_exits_outward` | Originating entrance code and its side. True → named type on hub, K162 on far side; false → K162 on hub, named type on far side. Missing orientation → type side unknown, not false. |
| `signature_type`, `completed` | Completed wormholes are eligible connection candidates. Non-wormhole/incomplete valid rows are excluded from the connection view; never turn them into a graph edge. |
| `max_ship_size` | `small/medium/large/xlarge/capital/unknown`; preserve unknown future values as Unknown. It is a reported category, not a numeric remaining-mass observation or ship pass guarantee. |
| `created_at`, `updated_at`, `completed_at` | UTC source timestamps; prefer updatedAt, then completedAt, then createdAt for report-ordering, disclose missing report time. FetchedAt is separate. |
| `expires_at` | Reported expiry estimate. Use this instant plus injected now for R10; past estimate is not observed collapse. Invalid/missing value produces time Unknown and a limitation. |
| `remaining_hours` | Rounded source convenience value; never use it as the live countdown or overwrite expiresAt. |
| `in_system_class` | Source category hint (`hs/ls/ns/c1…/c25/...`); reconcile with local catalog. Unknown future code remains Unknown. A conflicting category displays a diagnostic and conservative routing qualification. |
| No mass-state field | Mass Unknown. Do not infer Fresh from completed, recently updated, ship-size category, type nominal mass or Stable estimated time. |

Require a valid provider key, recognized hub and distinct resolved-or-resolvable
far system identity for a structurally usable wormhole row. Malformed core fields
or conflicting duplicate keys fail the snapshot validation; retain the previous
cache and report validation failure. Do not replace the cache with just the rows
that happened to parse. Unknown optional enums/absent names/status data may remain
qualified records. Top-level non-array JSON or HTML is an error, not an empty feed.
An explicit valid empty array is a successful snapshot and retires previous public
rows from live routing. It never deletes local signatures.

Missing expiry/status alone is not proof of closure. Such an edge can participate
with Unknown/Caution under R22; its feed freshness still limits use. Unknown or
unresolvable endpoints cannot participate until resolved locally.

### 5.3 Refresh, caching and failure policy

1. Use a dedicated public HTTP client with JSON Accept and an identifying Mimir
   User-Agent. Never attach ESI access tokens, cookies or private signature data.
2. On view open/resume, display SQLite data immediately and revalidate if eligible.
   While a live view is foregrounded, check eligibility every five minutes. Stop
   automatic polling when all consuming windows are hidden/closed. No background
   network daemon is required.
3. Pull-to-refresh and `RefreshAppBarAction` dispatch the same operation. Maintain
   one app-wide in-flight request and a minimum **300 seconds between attempts**;
   respect a longer server cache directive or Retry-After. During cooldown, update
   local countdowns/cache view and report next eligible network time; never pretend
   the data was freshly fetched. Filters and nearest searches read the same snapshot.
4. Network timeout is 15 seconds. Persist last attempt/error separately. On 429,
   honor Retry-After seconds or HTTP date. On timeout/5xx without Retry-After,
   retry delays are 300, 600, then 900 seconds capped; reset after success. Manual
   refresh does not bypass backoff. Other 4xx/schema errors await the normal eligible
   retry and remain actionable; no tight loop. The provider documents a cache TTL,
   not an unlimited request quota or a guaranteed service-level agreement.
5. Honor ETag/Last-Modified validators if supplied. A 304 can renew a previously
   valid snapshot by advancing lastSuccessfulValidationAt (thus Fresh/routable
   under the same 5m/24h rules), while preserving payloadReceivedAt and source report
   timestamps. A 304 without a valid cache is a protocol error and does not
   manufacture an empty result. No guarantee is made that validators are available.
6. Parse/resolve/validate before one atomic cache replacement. Publish only after
   commit. Failed network, validation or persistence retains last good records and
   payloadReceivedAt/lastSuccessfulValidationAt. Older request completions cannot overwrite a newer accepted revision.
   Cross-window consumers receive invalidation without starting their own fetches.
   SQLite revisions are authoritative and reread on open/resume because existing
   filesystem events are transient. Use one owning engine or a cross-process
   request lease/coordinator; an in-process provider lock alone is insufficient.
7. Keep unavailable/past-estimate public rows for a **24-hour history view** after
   last successful fetch/retirement; they never re-enter routing without a new
   valid source observation. Pruning this cache never touches the local notebook.
   Ordinary offline fallback shows cached rows, timestamps and expiry flags.

### 5.4 Other external inputs

Static reference updates use the existing SDE distribution/update workflow, with
new required universe/WH imports and atomic validation. Publish source/version
and any supplementary static-data attribution. A user without network access must
still have a bundled valid reference; corrupt/unavailable local data shows an
explicit repair/retry state, not invented values.

Character origin uses ESI `GET /characters/{character_id}/location/` with
`esi-location.read_location.v1`. Preserve selected character and distinguish
authentication/scope, network, loading and no-location outcomes in the new service
contract. Existing null-return behavior must not collapse them into a false origin.
Do not add waypoint writes or route calls merely because their ESI scopes exist.

## 6. UI screens, navigation and states

### 6.1 Exploration window and adaptive navigation

Register **Exploration** in the tray and window host, with a named icon and stable
window identity. It opens/focuses one window. The four destinations are:
**Wormhole Database**, **Thera & Turnur**, **Signature Tracker**, **Route Planner**.
The public view's title includes Turnur, even if a legacy internal type says Thera.

At usable content width ≥600 logical pixels, use a module navigation rail; below
600, use a four-destination bottom navigation bar with short labels **Database /
Connections / Signatures / Routes** and full accessible names. The existing
character selector stays separate; on narrow layouts place it in the AppBar.
Preserve each view's selection, filters and scroll position across view changes.
Navigation state must not depend on row indices that change after refresh.

At ≥1100 pixels, Database/Connections/Signatures use master-detail where useful;
600–1099 uses one list with a detail sheet/page; <600 uses one column with full-width
details. Reflow further at 200% text; 320px has no horizontal page overflow.
Filter chips wrap or open a labeled filter sheet; important choices must not be
hidden behind hover or clipped horizontal strips. Tables become labeled row groups.

### 6.2 Wormhole Database

- Search input, **Types / Systems** selector, destination filter and mass filter.
- Type card: visible code, destination, reliable lifetime, jump/total mass and
  reference/source indication. K162 and variant groups have explicit labels.
- Type sheet: exact units, regeneration per cycle, known/unknown limits, variant
  differences and linked system/static guidance. Do not label the capital mass
  shortcut **Capitals OK**.
- System sheet: named system/region, space category/class/security, effect family
  and strength, modifier table with meaning, source/version and static assignments.
- Local reference browsing has no fake live refresh control. Offer **Reference
  data** status and the existing update/repair workflow separately.

### 6.3 Thera & Turnur

AppBar refresh plus pull-to-refresh work even for an empty list through an
always-scrollable surface. Show hub selector, destination chips, region search,
origin selector and **Find nearest**. Prominent feed strip: last successful check,
age, cache/stale status, failure or cooldown when present. Credit **EVE-Scout /
Signal Cartel** and link to the public service.

Cards name both sides, far region/security, type and endpoint signature labels
**In Thera/Turnur** and **In [far system]**. Show independent time/mass badges;
Unknown is neutral, not green. Detail includes source report/update time, estimate,
captured freshness, orientation and unavailable fields. **Copy signature** copies
only the labeled side's code; no copy button for an unknown code. **Route to this
entrance** preselects the far system in Route Planner without writing an EVE waypoint.

Nearest results say which preferences apply, gate count to entrance and subsequent
wormhole count separately. Gate distance is not distance to a bookmark within the
system. Source expiry can remove a result while the view is open, with explanation.

### 6.4 Signature Tracker

Header pins character and named system; changing either changes the notebook scope.
Controls: **Add**, **Paste scanner results**, type/search filters, pruning setting,
**Trash**. Rows show signature, type, name, last-seen age, bookmark/note indication
and optional connection status. Name/type editing and explicit **Seen again** are
different actions. Detail contains fields, observation history and **Confirm
connection / Verify again / Mark closed** where appropriate.

Paste sheet shows pinned scope, parsed rows, row numbers, errors/conflicts and
counts: Added, Updated details, Seen again, New observation, Invalid, Conflicts.
The commit button names the number of selected valid rows; unresolved conflicts
cannot slip into the commit. Source scope change invalidates the preview.
Trash shows retirement reason/time and Restore/Permanently delete. No automatic
cleanup is presented as proof that sites have physically disappeared.

### 6.5 Route Planner

Inputs: explicit origin mode and system; destination; all R23 preferences in a
visible or labeled expandable section; **Calculate route**. AppBar and pull refresh
refresh live dependencies through the same shared policy, then recalculate from
committed inputs. With a manual origin, refresh cannot replace it with character
location. Local graph calculation has its own progress/cancel/stale-result state.

Result summary: origin→destination, gate/wormhole/total jumps, risk level and
limitations, preferences, source age and calculation time. List steps in travel
order; each row says Gate or Wormhole and its named endpoints. Wormhole steps add
departure-side signature, originating/reverse type, observation source, stability/
mass badges and expiry warning. Expand for far-side signature and full provenance.
An outdated route remains inspectable but clearly marked; do not retain an active
“current route” badge after inputs expire. No autopilot or guaranteed ETA action.

### 6.6 Empty/error states, exact action feedback and accessibility

| Condition / action | Required visible state or message |
|---|---|
| Reference unavailable | **Exploration reference data unavailable.** Explain download/import/repair status; never substitute zero limits or a fake graph. |
| Search/filter has no match | **No matching wormholes** / **No matching systems** / **No connections match these filters.** Offer Clear filters. |
| Valid empty public snapshot | **No reported connections for this selection.** Successful check time remains visible. |
| Feed failure, cache exists | **Could not refresh connections. Showing cached observations.** Include age and next retry time. |
| Feed failure, no cache | **Connections unavailable.** Error detail and Retry; preserve other local views. |
| Network refresh succeeds | **Connections updated.** Only after persistence; do not use this for a cooldown/cache-only action. |
| Refresh during cooldown | **Using cached observations. Next network refresh: [time].** |
| Signature copied | **Signature copied.** Copy the chosen endpoint only. |
| No selected character | **Select a character to track signatures.** Reference/public/manual routes remain available. |
| Location unavailable | **Current location unavailable. Choose an origin system.** Show sign-in/scope/network detail and Last known option if present. |
| Signature/import saved | **Signature saved.** / **Imported N signatures: A added, U updated, S seen again.** New episodes count as added; values reflect committed rows. |
| Paste invalid/too large | Inline row errors, or **Paste exceeds 5,000 rows or 512 KiB. Split the scan and try again.** No truncation/write. |
| Empty/non-text clipboard | **Clipboard contains no scanner text. Copy rows from EVE or enter text manually.** Preserve any text already in the import sheet. |
| Clipboard read exception | **Could not read the clipboard. Paste text manually or try again.** Preserve existing input and make no write. |
| Preview has zero valid selected rows | **No valid signatures selected.** Import is disabled; errors/manual editing remain available. |
| Context/revision changed during preview | **Notebook changed. Review the import again.** Preserve editable input. |
| Save failure | **Could not save signatures. Your previous records are unchanged.** |
| Soft delete / auto-prune | **Moved N signatures to Trash.** / **Moved N old signatures to Trash.** Offer Undo or View Trash. |
| Restore/hard delete | **Signature restored.** / **Permanently deleted N signatures.** Do not promise fresh verification on restore. |
| Verified / closed link | **Connection verified.** / **Connection marked closed.** Only after commit. |
| No route / missing data | R26's distinct result, with named preferences/coverage and editable inputs. |

Loading and refresh-with-cache are different states. Keep valid content visible
under scoped refresh errors. Disabled/busy controls have semantic labels and do
not queue duplicate saves. All icon-only controls have tooltips/accessibility
names; status uses text plus icon, not color alone. Keyboard traversal reaches all
actions; touch opens the same detail as hover. Restoring focus after sheets,
announcing async feedback and preserving input after errors are required.

## 7. Acceptance criteria

### Reference and Phase 4a

- **AC1 — Offline completeness (R1):** First-use reference browsing succeeds without
  HTTP calls; installed catalog counts/checksums match its manifest, and failed
  updates retain the previous usable version.
- **AC2 — Search/filter determinism (R7):** Trim/case-insensitive exact/prefix/substring
  ranking and AND filters produce the specified fixture results; unknown mass fails
  numeric filtering and the capital-size shortcut discloses its limited meaning.
- **AC3 — Exact reference units (R2):** Raw lifetime minutes become seconds correctly;
  jump/total kg and regeneration per cycle remain distinct and available unrounded.
- **AC4 — Reverse types/variants (R3):** K162 retains unknown limits; duplicate code
  variants remain individually stored and code-level facts require agreement.
- **AC5 — System identity (R4):** Inheritance and special classes work; Thera/Pochven
  do not become nullsec; security boundary fixtures use the official raw-value rule.
- **AC6 — Exact effects (R5):** All 36 family/strength records and §4.2 modifier
  vectors/scopes match the pinned source; beacon selection, resonance and semantic
  labels pass the specified regressions.
- **AC7 — Honest statics (R6):** System assignments carry independent provenance;
  unknown coverage and typical-class guidance cannot become verified system statics
  or live route edges.

### Public highways and Phase 4b

- **AC8 — Verified API contract (R8):** Production uses public v2 and no credentials,
  legacy URL, private endpoint, staging examples or invented Pochven request.
- **AC9 — Endpoint orientation (R9):** Both-direction details/copy/route steps use
  the correct endpoint signature and K162/originating type, including unknown orientation.
- **AC10 — Unknown mass (R10):** Every public row without explicit mass observation
  shows Mass not reported, regardless of size/completed/freshness/time values.
- **AC11 — Time semantics (R10):** Exactly 4h remains Stable estimate, below 4h is
  EOL estimate, at expiry becomes Past reported expiry; none asserts actual collapse.
- **AC12 — Durable dual refresh (R11):** Both controls use one operation, cached
  content survives restart/failure, and validation age 5m/24h changes freshness/eligibility
  at the specified boundaries without waiting for HTTP.
- **AC13 — Request discipline (R11):** Cooldown/backoff/Retry-After and conditional
  responses follow §5; repeated taps, window changes and local filters cannot
  multiply requests or falsely renew fetchedAt.
- **AC14 — Atomic shared feed (R11, R32):** Invalid/failed writes retain the whole
  previous snapshot; valid empty retires public edges only. Intel/Exploration agree
  after committed revision changes and missed cross-window events.
- **AC15 — Destination filters (R12):** Hub/category/region filters combine correctly
  using the far side; J-space/Pochven/Unknown remain distinct and accessible.
- **AC16 — Origin correctness (R13):** Manual/current/last-known modes, the 60-second
  freshness boundary, errors and character changes preserve explicit ownership;
  no network or sign-in is required for a manually selected origin.
- **AC17 — Nearest entrance (R14):** The finder returns the correct preference-ranked
  gate approach plus hub transit, rejects avoided hubs/unreachable endpoints and
  distinguishes already-in-hub from an isolated J-space origin.

### Notebook and Phase 4c

- **AC18 — Scoped CRUD (R15):** Fields, explicit clears, lengths and active uniqueness
  validate; character/system notebooks remain isolated and work offline for a
  selected locally stored character.
- **AC19 — Scanner syntax (R16):** §4.3 supported rows, CRLF/BOM/header/blank handling,
  Unknown labels and invalid-row diagnostics produce exact fixture output.
- **AC20 — Preview/merge (R17):** Preview is write-free; apply is explicit/atomic,
  known conflicts require selection, duplicates coalesce, absent rows survive and
  existing notes/bookmarks are preserved.
- **AC21 — Limits/cancel/failure (R16):** Oversized input is rejected without
  truncation; empty/non-text/read-failed clipboard preserves input; zero-valid import
  is disabled; cancel and failed commits produce no partial save or success notification.
- **AC22 — Observation versus edit (R17):** Rescan changes lastSeenAt, metadata edit
  does not; one preview is idempotent; retired IDs create separate episodes by
  default and cannot inherit unrelated historical annotations.
- **AC23 — Trash/restore (R18):** Soft delete/Undo/Restore preserve history and owned
  link retirement; restoration cannot reset age, bypass an active-ID conflict or
  resurrect an expired/closed route.
- **AC24 — Hard deletion (R18):** Explicit confirmation deletes only selected scoped
  rows/owned links, with correct count; public and other-character data survive.
- **AC25 — Pruning (R19):** 24/48/72h/Off policies and exact ≥age boundary work;
  prune is soft, idempotent and cannot retire a newer committed rescan.
- **AC26 — Local connection verification (R20):** A wormhole row alone creates no
  edge; resolved distinct endpoints and explicit verification do. Re-scan does not
  renew verification; type/endpoint/orientation changes and Restore require new
  verification, and closed/past-estimate/24h-old links are excluded.

### Routes and Phase 4d

- **AC27 — Graph integrity (R21):** Real directed gates and eligible two-way wormholes
  form a scoped multigraph; parallel connections survive, statics/other-character
  links never become edges and source versions accompany results.
- **AC28 — Eligibility (R22):** All exclusion rules and explicit stale opt-in hold;
  Unknown status remains qualified rather than Fresh, and cannot be reported as safe.
- **AC29 — Hard avoid rules (R23):** EOL/Critical/Lowsec/Nullsec avoid controls apply
  to all steps/hubs/destination, with origin-only escape exception and no silent relaxation.
- **AC30 — Route objective (R24):** Exact Shortest and Prefer Highsec cost tuples,
  tie-breaks, cycles, parallel links and origin=destination cases pass fixtures.
- **AC31 — Route counts/details (R25):** Ordered step endpoints/signatures and
  gate/wormhole/total counts match graph edges; no system-node count off-by-one.
- **AC32 — Risk meaning (R25):** Maximum route risk and tie-break sums are correct,
  with source limitations and no Safe/guaranteed ETA/ship-eligibility claim.
- **AC33 — Recalculation (R26):** Context/revision/freshness/EOL/verification changes
  and the CurrentCharacter 60s boundary invalidate old results; late completion
  cannot replace the newest request.
- **AC34 — No-route states (R26):** Constraint failure, disconnected known graph and
  missing graph data have distinct messages; partial coverage is never called global
  impossibility or globally shortest travel.

### Integration, UI and engineering standards

- **AC35 — Tray/window integration (R27):** Exploration opens/focuses one registered
  window, all four views preserve state, and existing window IDs/character rail remain intact.
- **AC36 — Responsive layouts (R28):** 320px, medium and desktop layouts at normal/
  200% text expose all views/content/actions without horizontal page overflow.
- **AC37 — Accessible feedback (R28):** Keyboard/touch expose equivalent details;
  statuses use text/icons, focus restores correctly, and §6.6 feedback follows the
  actual committed outcome, including empty/error/cooldown states.
- **AC38 — Async/domain/names (R29–R30):** Loading/error/data and cached refresh are
  explicit; UI has no unguarded AsyncValue access or embedded route/parser formulas;
  unresolved numeric IDs never leak into visible fallback labels.
- **AC39 — Observability/performance (R31):** Shared feature-tagged logging covers
  operations without private text/tokens; documented desktop measurements meet the
  search/graph targets with reproducible fixtures.
- **AC40 — Lifecycle/side-effect isolation (R32):** Migration, restart, missed events,
selected-character deletion and concurrent operations retain correct ownership;
  no automatic EVE/public writes, clipboard monitoring or duplicate Intel feed loops.

## 8. Test scenarios and synthetic fixtures

### 8.1 Test boundaries and reference clock

These are required future tests, not existing passing results. Use local seeded
SDE/reference inputs, in-memory/on-disk Drift as appropriate, fake HTTP/ESI/clipboard
boundaries, an injectable clock and controlled completion order. No test depends
on a real wormhole remaining present or a current public pilot's record.

`T0 = 2026-09-15T12:00:00Z` for every time fixture unless stated otherwise.
System/character IDs below are synthetic fixture keys, except the explicitly named
CCP reference and hub IDs. Synthetic names/statistics are not live EVE claims.
Assert pure outputs at full precision, then separately verify formatted UI text.

### F1 — Reference identity, units, variants and search

Seed these raw reference records with the pinned schema:

| Key/code | Raw values | Exact normalized expectation |
|---|---|---|
| 30677 / B274 | class 7; time 1440; total 2000000000; jump 375000000; regen 0 | Highsec destination; lifetime86400s/24h; exact kg values; regeneration0 kg/cycle. |
| 30831 / K162 | no typeDogma row | Reverse-side designation; destination/lifetime/masses/regeneration Unknown, never zero. |
| 92287 / I078 | class 25; time 270; total 100000000; jump 62000000 | Pochven destination; lifetime16200s/4h30m; exact mass values. |
| C729 variants V1/V2 | distinct numeric keys/distributions, same time 720/jump 410000000; repeat with differing jump in V2 | Both retained. Shared card shows 12h and 410000000 only in agreeing variant; differing jump becomes Varies with variant details. |
| Synthetic Q001 | C1; jump 1000000000 | Capital-size mass filter includes it at the exact threshold. |
| Synthetic Q002 | C1; jump 999999999 | Same filter excludes it. |

Query ` b274 ` resolves B274 exactly; `highsec` plus Highsec returns B274; `C1`
plus capital-size returns Q001 only; K162 is excluded by every positive mass floor.
For production catalog completeness, use manifest counts from the full pinned
archive, including all 28 C729 variants; this small fixture does not replace that gate.

### F2 — Effects and taxonomy

Parameterize every table row in §4.2 over six strengths: vectors must match exactly.
Specific oracles: multiplier 1.30 → +30%; Magnetar strength 1 explosion radius 100 →130;
Wolf-Rayet strength 6 small-weapon damage 100 →300; Pulsar strength 6 capacitor recharge
time 100s →50s; 50% armor resist under +50% armor resonance →25% resist.

Use inherited class via region, constellation override and system override in
separate records. Class 13 + beacon 30879 → Wolf-Rayet strength 6. J005926's beacon 30848
→ Red Giant 1 despite Pulsar visual; J010569's beacon 30849 → Wolf-Rayet 1 despite
Red Giant visual. Missing effect data → Effect unknown; verified absent effect →
No system effect. Typical statics with no per-system assignment → Static information
unavailable, no route edge.

Ordinary-security inputs/outputs:

| Raw security | Category | Display |
|---:|---|---|
| −0.01 | Nullsec | 0.0 (no misleading negative-zero sign) |
| 0 | Nullsec | 0.0 |
| 0.0001 | Lowsec | 0.1 |
| 0.049 | Lowsec | 0.1 |
| 0.05 | Lowsec | 0.1 |
| 0.449999 | Lowsec | 0.4 |
| 0.45 | Highsec | 0.5 |
| null | Unknown | Unknown |

Thera or Pochven at −0.99 keeps its special category; it does not enter the Nullsec
filter. A future unsupported class is preserved and labeled Unknown/Special as
appropriate, never assigned C1 effects.

### F3 — Public wire normalization and endpoint direction

Seed this synthetic wire record and matching Alpha system catalog entry:

```json
{
  "id": "42",
  "created_at": "2026-09-15T10:00:00Z",
  "updated_at": "2026-09-15T11:30:00Z",
  "completed": true,
  "signature_type": "wormhole",
  "out_system_id": 30002086,
  "out_system_name": "Turnur",
  "out_signature": "HUB-123",
  "in_system_id": 9101,
  "in_system_name": "Alpha",
  "in_system_class": "hs",
  "in_region_id": 9201,
  "in_region_name": "Fixture Region",
  "in_signature": "FAR-456",
  "wh_type": "B274",
  "wh_exits_outward": true,
  "max_ship_size": "xlarge",
  "expires_at": "2026-09-15T18:00:00Z",
  "remaining_hours": 999
}
```

Expected: key `evescout:42`; hub Turnur; far Alpha/Highsec; Mass Unknown;
Stable estimate at T0; 6h remaining independent of999; reported update11:30,
fetchedAt 12:00. Alpha→Turnur departure is `FAR-456 / K162`; reverse is
`HUB-123 / B274`. With orientation false those type labels swap, not the systems
or signatures. Missing far signature → Signature not reported. Number42 and
string"42" normalize to one key; conflicting duplicate content rejects the snapshot.

At14:00 exactly, remaining4h → Stable estimate. At14:00:00.001 → EOL estimate.
At18:00 → Past reported expiry, ineligible; no Collapsed label. Unknown size enum
→ Unknown size. Missing/invalid expiry → Unknown time with limitation. A non-wormhole
or incomplete row creates no edge. Bad hub/core identity makes refresh invalid.

### F4 — Cache, refresh and backoff

Initial accepted revision 1 at T0 contains keys 42 and 43;42 expires at 18:00 and 43
at T0+48h. A local signature exists. Payload receipt and successful validation
both start at T0.
At12:04:59 cache is Fresh. At12:05:00 it is Stale; a default route using42 becomes
outdated/ineligible even with no response. Enabling stale use permits unexpired
rows until validation age reaches24h; at that exact boundary neither is routable.

Two refresh gestures at 12:05 start one request. Failure preserves revision 1 and
fetchedAt 12:00, updates attempt/error and sets first retry no earlier than 12:10.
A 429 at 12:05 with Retry-After 600 permits next attempt at 12:15, not 12:10. Success
with `[]` atomically replaces public live rows and leaves the local signature.
Invalid JSON/HTML, malformed core row or database failure retains revision 1 as a
whole. A 304 with valid cache at 12:10 renews validation time to 12:10 and restores
Fresh eligibility for unexpired rows, while payloadReceivedAt stays12:00. Without
valid cache it errors.
An older response completing after a newer accepted revision is ignored.

### F5 — Scanner preview, merge and scope

Existing active record: character 7/system 9101, `ABC-123`, Data, name `Sansha Data Site`,
bookmark `Safe spot`, notes `Keep this note`, firstSeen 10:00, lastSeen 11:00.
An unrelated `OLD-111` exists. Paste at T0 (escape notation represents actual tabs
and CRLF, not literal backslash characters):

```text
ID\tGroup\tType\tName\tSignal\tDistance\r\n
abc-123\tCosmic Signature\tData Site\tSansha Data Site\t100%\t1 AU\r\n
DEF-456\tCosmic Signature\tWormhole\tUnstable Wormhole\r\n
GHI-789\tCosmic Signature\t\t\r\n
bad-id\tCosmic Signature\tData Site\tBroken\r\n
ABC-123\tCosmic Signature\tData Site\tSansha Data Site
```

Expected preview: **3 unique valid rows**, 1 duplicate coalesced, 1 invalid row;
Added 2, Updated details 0, Seen again 1. Before apply, database unchanged. Explicit
Import 3 commits: ABC retains bookmark/notes/firstSeen and lastSeen becomesT0;
DEF is Wormhole with no destination and no edge; GHI is Unknown with no name;
OLD-111 remains. Exact message: **Imported 3 signatures: 2 added, 0 updated, 1 seen again.**
Reapply the same preview operation → no second write or success count.

Variants: incoming ABC as known Relic conflicts rather than silently replacing Data;
blank incoming name cannot erase it; an explicit form clear can. Same code in
character 8 or system 9102 is separate. Changing scope or editing ABC during preview
requires review again. A trashed ABC creates a new episode without copying old notes.

### F6 — Pruning, trash and connection verification

At T0, AGE-001 was last seen exactly24h ago and edited one minute ago; AGE-002 was
seen23h59m59s ago. Default prune moves only AGE-001 to Trash. Repeat returns 0.
At48h setting, neither is pruned; Off performs no retirement. Restore AGE-001
preserves its old time and does not establish fresh route verification; an active
same-code episode blocks Restore with conflict. Permanent deletion of AGE-001
leaves character 8's same-code record and public records unchanged.

Wormhole DEF-456 without destination has no edge. Set destination9102, far signature
`DST-234`, confirm at T0: one owned connection yields two directed edges. Same-system
destination is invalid. Re-scan at T0+23h updates signature lastSeen but not verifiedAt;
at T0+24h its edge is excluded. Mark closed excludes immediately. Concurrent rescan
and prune have explicit order semantics: if rescan commits first, prune preserves
the updated active row; if prune commits first, the old import preview conflicts
and writes nothing. A rebuilt, explicitly applied import then creates a new active
episode. Neither path loses a newer committed observation.

Set Known originating type=B274, side=This system: forward type is B274, reverse
is K162; side=Other system swaps them. Unknown side stays unassigned. Observed K162
with unknown originating type never yields invented B274. Edit type to Data or
change endpoints/orientation: edge becomes ineligible atomically. Changing back
or Restore does not reactivate it; explicit valid reconfirmation is required.

### F7 — Route graph and exact paths

Synthetic systems: A/B/C/E/F/G/H/Z are Highsec; D and U are Lowsec (U represents
Turnur); T is Thera; J is J-space. All named connections are bidirectional. Gate
edges: `A-B, B-C, C-D, D-Z, A-E, E-F, F-G, G-H, H-Z`. Public wormholes:
`B-T, T-Z, E-U, U-Z`, with fresh snapshot, future expiry and no known EOL/Critical
state; public mass is Unknown. Optional verified private edges for character 7:
`A-J, J-Z`. Without those private edges J is isolated. Each edge has a unique
canonical key; reverse edges have distinct directed keys.

| Request | Exact result |
|---|---|
| A→Z, defaults, no private edges | A-B-T-Z; gate 1 + wormhole 2 =3; route Caution, risk sum 2. Turnur alternative also has 3 jumps but risk sum 3. |
| Same, Prefer Highsec On | A-E-F-G-H-Z; gate 5, wormhole 0; non-highsec entries0 and risk0. |
| Same, Avoid Lowsec On | A-B-T-Z; D and U cannot be entered. |
| Mark B-T EOL, defaults | A-E-U-Z; gate 1 + wormhole 2 =3; route High, risk sum 3. |
| B-T EOL and Avoid Lowsec On | A-E-F-G-H-Z; gate 5. Neither EOL nor lowsec is silently allowed. |
| Instead mark T-Z Critical, defaults | A-E-U-Z; critical edge excluded. |
| Defaults with character 7's private links | A-J-Z; gate 0 + wormhole 2 =2, Caution. Character 8 cannot use those links. |
| A→A | Empty steps, gate 0/wormhole 0/total 0; Already at destination, no wormhole risk claim. |
| A→J without private links | No route in the available connection graph. |
| A→D with Avoid Lowsec On | No route under these preferences; destination is excluded. |
| D→A with Avoid Lowsec On | D-C-B-A; origin escape allowed, gate 3; no later Lowsec entry. |
| Missing gate/reference dataset | Route data unavailable, not a zero-jump/no-route result. |

For tie-break testing, name the existing B-T connection `w01` and add parallel
`w02` with identical data; choose `w01` independent of insertion order. If w01 is
ineligible, use w02.
Keep both records. Add a directed gate without reverse and assert no invented
return edge. If every public snapshot reaches5m stale with stale use Off and no
private links, default A→Z becomes the four-gate A-B-C-D-Z route, High risk.

### F8 — Nearest and responsive journeys

Using F7 from A with fresh public rows and All hubs: B is one gate away and leads
to T; E is one gate away and leads to U. Choose B→T on risk tie-break and display
**1 gate jump to entrance; then 1 wormhole jump to Thera**. Avoid Lowsec rejects
E→U even though E is Highsec. With B-T EOL, Thera-only and Avoid Lowsec On, use Z
via A-E-F-G-H-Z: **5 gate jumps to entrance; then 1 wormhole jump to Thera**.
An isolated J origin has no gate approach, not distance0. Origin T with Thera
selected shows Already in Thera; selecting Turnur does not reuse that answer.

Run each view at 320×640, 600×800, 1100×800 and 1440×900 logical pixels, each at
100% and 200% text. Include long system/region names, every status, empty/error/cache
states and open dialogs. Thresholds use remaining usable content width after
character navigation. Assert no horizontal page overflow, reachable four-view
navigation, complete labels/actions, readable expanded stats and preserved selection.

### 8.2 Domain and contract test matrix — 24 cases

| ID | Input/action | Expected outcome | AC |
|---|---|---|---|
| D01 | F1 raw B274/I078/K162 records. | Exact units/lifetimes; K162 unknowns remain null. | AC3, AC4 |
| D02 | F1 C729 agreeing/conflicting variants and reordered records. | Stable grouping without overwrite; shared fields only on agreement. | AC4 |
| D03 | F1 search queries and exact capital mass boundary. | Named expected results, deterministic rank and AND behavior. | AC2 |
| D04 | All F2 family/strength modifier vectors. | Exact36 records/scopes; resonance/cap/weapon example arithmetic. | AC6 |
| D05 | F2 class 13 and visual/beacon mismatches; missing effect. | Beacon wins; proper strength; no-effect distinct from unknown. | AC5, AC6 |
| D06 | System→constellation→region inheritance; supplementary statics missing/typical. | Correct class precedence; no invented system assignment/edge. | AC5, AC7 |
| D07 | F2 raw security boundaries and special systems. | Exact category/display table; no Pochven/Thera nullsec leak. | AC5, AC15 |
| D08 | F3 both orientations, missing far signature/orientation. | Correct each-side type/signature or explicit unknown. | AC9 |
| D09 | F3 at 4h, just below 4h and expiry; remaining_hours 999. | Exact time states/countdown; no collapse inference. | AC11 |
| D10 | F3 missing mass, fresh/completed/size variants. | Mass Unknown in every case; never inferred Fresh. | AC10 |
| D11 | F3 integer/string IDs, optional unknown enums, bad core and duplicate conflict. | Normalization tolerant only where specified; invalid snapshot rejected. | AC8, AC14 |
| D12 | F5 CRLF/LF/BOM/headers/blanks, unfamiliar type under supported group, unsupported localized group and extra columns. | Accepted Unknown type with warning; invalid groups/rows diagnosed with row numbers. | AC19 |
| D13 | F5 duplicate/known-conflict/blank-cell merge plans. | Coalescing, conflict and annotation-preservation rules hold. | AC20, AC22 |
| D14 | Field limits and 512KiB/5000-row boundaries. | Inclusive limits accepted; excess rejected without truncation. | AC18, AC21 |
| D15 | F6 prune/verification ages24h/48h/72h andOff. | Exact eligibility/retirement predicates; note edit irrelevant. | AC25, AC26 |
| D16 | F6 missing/self/different destination, both type orientations/Unknown and closed/edited state. | Only verified valid link yields directed pair; side labels reverse correctly; edits invalidate. | AC26, AC27 |
| D17 | F7 default route and parallel edges/insertion permutations. | A-B-T-Z and deterministic w01 tie-break. | AC27, AC30, AC31 |
| D18 | F7 Prefer Highsec. | Five-gate all-highsec route beats shorter non-highsec alternatives. | AC30 |
| D19 | F7 hard avoid/EOL/Critical/origin-escape/destination cases. | Exact listed paths or constraint failure; no relaxation. | AC29 |
| D20 | F4 stale/24h thresholds and F6 retired/verification-expired links. | Exact excluded-edge sets; opt-in cannot resurrect expired/closed links. | AC12, AC28 |
| D21 | F8 nearest, avoided hub, already-in-hub and isolated origin. | Exact approach/entry counts and distinct states. | AC17 |
| D22 | F7 zero-step, disconnected, missing graph and one-way gate. | Zero counts, distinct failure states, no invented reverse. | AC30, AC34 |
| D23 | F7 risk ranks and gate/wormhole step details in both directions. | Maximum risk versus cost sum correct; count invariant and endpoint provenance. | AC9, AC31, AC32 |
| D24 | Feed filter fixtures with HS/LS/NS/Pochven/J-space/Unknown, hubs and mixed-case region query. | Far-side AND filters; stable ordering and complete All view. | AC15 |

### 8.3 Provider, service, persistence and integration matrix — 18 cases

| ID | Input/action | Expected outcome | AC |
|---|---|---|---|
| P01 | Fresh install offline plus full reference manifest; corrupt/failed update. | Populated local lookup; counts/checksums verified; prior reference retained. | AC1, AC7 |
| P02 | Upgrade existing app/SDE databases containing characters, AAR and Intel records. | Exploration tables/imports added without data loss; restart round-trips all new states. | AC1, AC40 |
| P03 | F3 valid v2 response and recording HTTP client. | Correct endpoint/headers, no auth/private/staging calls; public rows cached. | AC8 |
| P04 | F4 concurrent pull/AppBar refresh and foreground timers. | One attempt across consumers;300s cooldown; no filter-induced requests. | AC12, AC13 |
| P05 | F4 timeout/5xx/429 seconds/date Retry-After;304 with/without cache. | Exact retry deadlines, correct validation renewal and preserved failure state. | AC13 |
| P06 | Valid empty, malformed array/core row, conflict and cache write failure. | Atomic whole-snapshot behavior; local records untouched. | AC14 |
| P07 | Two window engines, missed event, hide/resume and out-of-order responses. | DB revision reread; shared request ownership; no stale overwrite/duplicate feed loop. | AC14, AC40 |
| P08 | Location observation age 60s/60s+1ms, scope/auth/network errors, manual and last-known choices. | Explicit origin modes/freshness; no false location or manual overwrite. | AC16 |
| P09 | Selected character changes during location/route completion. | Old result cannot publish; public/manual data retained, private edges isolated. | AC16, AC27, AC33 |
| P10 | F5 preview/apply/cancel/reapply/failure; empty/non-text/read-error clipboard and zero-valid preview. | Exact outcomes and atomic retention; clipboard errors preserve input; no zero-valid commit. | AC20, AC21, AC22 |
| P11 | F5 concurrent edit/scope change/import, nullable clears, duplicate active ID. | Conflict/review state; no silent overwrite or cross-scope write. | AC18, AC20 |
| P12 | F6 Delete/Undo/Restore/new episode and permanent delete confirmation. | Age/history/link rules; only selected owned rows deleted. | AC22, AC23, AC24 |
| P13 | F6 prune load/resume/hourly, repeated pass and both rescan/prune commit orders. | Rescan-first preserved; prune-first preview conflicts until explicit reapply; scoped settings. | AC20, AC25 |
| P14 | F6 verify/rescan/close/restore; form/import type change, endpoint/orientation change; pruning Off and 24h. | Owned edges invalidated atomically and never silently reverified; age policy independent. | AC26, AC28 |
| P15 | F7 context changes, timed public 5m/4h/24h and origin 60s transitions, valid 304 and late result. | Correct invalidation/renewal; latest result only; no HTTP needed for local timers. | AC28, AC33 |
| P16 | Character deletion through central DB lifecycle with Exploration closed. | Private notebook/links removed; public/cache/reference and other pilots survive. | AC40 |
| P17 | Unknown name, local catalog missing/corrupt, network disabled and AsyncValue failures. | Proper local fallback/unknown/data-unavailable states; no numeric visible names. | AC1, AC34, AC38 |
| P18 | Full-catalog search and 10k-node/30k-directed-edge graph on documented host; capture logs. | p95 targets met; appropriate tags/outcomes without clipboard/notes/tokens. | AC39 |

### 8.4 Window, responsive UI and journey matrix — 18 cases

| ID | Input/action | Expected outcome | AC |
|---|---|---|---|
| U01 | Tray launch, repeat launch, each of four destinations and existing windows. | One Exploration window focused; original registrations intact; view state retained. | AC35 |
| U02 | F8 viewport/text matrix for all four views and open sheets. | Appropriate rail/bottom/single/master-detail behavior; no overflow or unreachable controls. | AC36 |
| U03 | Keyboard/touch, focus restoration, icon-only actions and color-independent statuses. | Equal access and announced feedback; no hover/color-only information. | AC37 |
| U04 | F1 search/filter, K162/variant and exact unit details offline. | Correct named cards, limitation labels and precise breakdown. | AC2, AC3, AC4, AC38 |
| U05 | F2 system/effect/static states, long modifier names. | Exact modifiers/strengths, meaningful signs, source labels and unavailable states. | AC5, AC6, AC7 |
| U06 | F3 both endpoint orientations, copy actions and Unknown fields. | Correct copied signature, side labels and neutral mass/time unknowns. | AC9, AC10, AC37 |
| U07 | Both refresh mechanisms on populated and always-scrollable empty/error views. | Same operation; busy/cooldown/failure/success messages match outcome. | AC12, AC13, AC37 |
| U08 | Valid empty snapshot versus filtered empty versus failed request with/without cache. | Distinct states; source age and available cached content remain visible. | AC14, AC15, AC37 |
| U09 | Location modes, no character/scope and switching pilot while loading. | Manual fallback works; correct stale ownership; no private data from previous pilot. | AC16, AC18, AC38 |
| U10 | F8 nearest results and Route to entrance. | Exact separate counts; avoided hub excluded; planner prefilled without EVE write. | AC17, AC40 |
| U11 | F5 paste preview, conflicts, explicit valid-row import and annotation display. | Exact preview/count/message; retained notes/bookmark/absent rows. | AC19, AC20, AC22 |
| U12 | Oversized/corrupt/localized/empty/non-text/read-error paste, zero valid rows, cancel/save failure/scope conflict. | Correct warning/error distinction; input retained; Import disabled when empty; no partial save/success. | AC18, AC19, AC21, AC37 |
| U13 | F6 Trash/Undo/Restore/conflict, permanent-delete prompt and auto-prune notice. | Correct count/scope; clear irreversible confirmation; no fresh-verification claim. | AC23, AC24, AC25 |
| U14 | F6 confirmation from named/K162 sides, Unknown orientation, verify/close and edited endpoint/type. | Explicit side controls; correct reverse labels; no eligible edge until valid confirmation. | AC26 |
| U15 | F7 route presets, steps and risk explanations. | Exact path/counts, named systems/signatures, no safe/ETA guarantee or silent relaxation. | AC29, AC30, AC31, AC32 |
| U16 | Expiry/feed freshness/origin 60s timer, preference change and slower previous calculation. | Old result outdated; current origin needs refresh/Last known; latest route only. | AC11, AC28, AC33 |
| U17 | Missing topology, disconnected system and excluded destination. | Three distinct R26 states with actionable input/coverage explanation. | AC34, AC38 |
| U18 | All views offline, restart/missed event, recorded network/write/clipboard boundaries. | Reference/notebook/manual routing usable; cached qualifications; no automatic clipboard/EVE/public writes. | AC1, AC8, AC38, AC40 |

### 8.5 Completion evidence and Plan/Test-Author handoff

| Workflow | Primary acceptance coverage | Representative executable cases |
|---|---|---|
| S1 Offline type lookup | AC1–AC4 | D01–D03, P01, U04 |
| S2 System properties/effects | AC5–AC7 | D04–D07, U05 |
| S3 Public highway browsing | AC8–AC15 | D08–D11, D24, P03–P07, U06–U08 |
| S4 Nearest entrance | AC16–AC17 | D21, P08–P09, U09–U10 |
| S5 Scanner import | AC18–AC22 | D12–D14, P10–P11, U11–U12 |
| S6 Notebook retirement | AC23–AC25 | D15, P12–P13, U13 |
| S7 Verified local connection | AC26–AC28 | D16, P14, U14 |
| S8 Mixed route | AC27–AC34 | D17–D23, P15, U15–U17 |
| S9 Offline/context recovery | AC35–AC40 plus source freshness | P02, P07, P09, P16–P18, U01–U03, U18 |

The matrix contains **60 cases**: 24 domain/contract, 18 provider/service/persistence
and 18 window/UI cases. Each row's variants are mandatory parameterized subcases.
All **R1–R32**, **AC1–AC40** and **S1–S9** must have executable evidence; listing a
case here is not a passing result. Use real serialization, Drift transactions and
the actual Exploration window host for the relevant tests, not service mocks that
manufacture successful persistence or hand-built UI that bypasses navigation.

Plan must sequence populated reference/topology before nearest/routes, shared feed
normalization/cache before both consuming windows, and notebook verification before
private route edges. Assign explicit ownership for migrations, generated reference
assets, domain services, providers and UI. Existing Intel should adopt the same
feed repository rather than becoming a second independently refreshed data source.

Release evidence includes pinned source manifests/effect fixtures, previous-schema
migration and rollback tests, all synthetic path/count oracles, cross-engine and
race tests, offline startup, responsive screenshots plus semantic interactions,
static analysis and appropriate Flutter suites. Measure performance separately on
a named host/build. Re-probe the public schema before release without using volatile
live records as test assertions. Capture any current service difference as a
contract update, never weaken Unknown handling to make a parser pass.

The specification is the Product handoff. Implementation, test-authoring and tester
signoff remain outstanding until their evidence satisfies this contract.

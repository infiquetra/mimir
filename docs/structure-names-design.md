# Authenticated structure names slice — locked design

Branch: `feat/rust-structure-names`. Base: `develop` at
`602782c` (merge of PR #571). This document locks the design
for resolving player-built structure names through the
authenticated per-character ESI (EVE Swagger Interface, the
EVE Online API) structure endpoint, so locations inside
player structures stop rendering as "Unknown Location" in
Assets, Wallet, Industry, Market, Characters, and the
dashboard location cell. It extends, and never contradicts,
`docs/rust-rewrite-design.md` (which already promises
"structures via authenticated
`GET /universe/structures/{id}/` (403 → "Unknown Location")"
at line 23 — a promise the shipped code does not yet keep).

## The verified defect (inspected bodies, base `602782c`)

Two layers, both must change; fixing either alone changes
nothing on screen.

1. The live shell never schedules a structure lookup.
   `schedule_name_resolution` (`src/app/shell.rs:549-736`)
   guards every location id with `!is_structure_id` (lines
   567, 578, 592, 598, 611, 632, 640, 654, 662, 677) under a
   header comment (lines 545-548) stating "the authenticated
   structure lookup stays a follow-up". A structure id never
   reaches `NameResolver::missing` (`src/names/resolver.rs:160`),
   never hits the network, and
   `NameResolver::location_name` (resolver.rs:150-155)
   returns "Unknown Location" synchronously forever.
2. The resolver's own structure path calls the wrong
   endpoint. `resolve_missing_esi` (resolver.rs:225-310)
   partitions structure ids at lines 242-243 and calls
   `endpoints::get_structure` (line 269), which is
   `client.public_get("/universe/structures/{id}/")`
   (`src/esi/endpoints.rs:721-728`) — its own doc comment
   says live ESI "usually 401s" without a token. The
   authenticated helper
   `endpoints::get_structure_for_character`
   (endpoints.rs:733-749, `client.auth_get`) exists with
   zero callers in `src/` (grep-verified). Separately, no
   scope group in `src/config.rs` contains the scope the
   authenticated endpoint requires (grep for
   `read_structures` in `src/` returns nothing), so even a
   correctly addressed call would 403 for every current
   user until a step-up grant exists.

`resolve_missing_esi` and its scaffold wrapper
`resolve_missing` (resolver.rs:316-349) have no production
caller today (only the wrapper's internal call at line 341
and one test at line 451). The user-visible path is the
shell spawn at shell.rs:721-735 plus the
`BackendMsg::NamesResolved` apply handler at
shell.rs:885-919. This slice therefore changes the shell
path (the live one) and fixes the resolver API to the same
contract (so the library surface stops lying).

## 1. Value ranking (LOCKED)

When two choices conflict, the higher rank wins. Locked
rules below cite the rank that decided them where an
inspected body did not force the choice.

| Rank | Value | What it decides |
|---|---|---|
| 1 | Display honesty: a resolved name or the words "Unknown Location", never a raw numeric ID, never an invented name | Keep the resolver word fallback and numeric-name guard; no "Player Structure" inventions; ACL-denied stays Unknown |
| 2 | Least-privilege authorization: first sign-in never widens; every new permission is a user-approved step-up | New scope enters only via the existing step-up flow; `FIRST_AUTH_SCOPES` untouched; no browser is ever opened without a button click |
| 3 | A granted permission must visibly work: no session state may silently swallow a retry the user just paid for | Scope-absent and transient failures are never pinned as unresolvable; character switch and step-up completion re-arm structure retries (section 6.3) |
| 4 | Bounded network work: name resolution can never fan out or wedge | Hard per-pass cap, sequential calls, per-id failure isolation, abort-the-rest on transport failure (section 7) |
| 5 | Character isolation for late async results | Every structure result carries the character id whose token produced it and is dropped when that character is no longer active |
| 6 | Reuse of shipped machinery over new machinery | Existing `universe_names` cache, existing step-up request/shortcut flow, existing spawn-and-send-back pattern, existing log tags |
| 7 | Coverage breadth across views | All existing location render sites benefit through the one shared resolver; no per-view lookup code |

## 2. Hard scope and explicit exclusions (LOCKED)

In scope: one new step-up scope group; the resolver API
fix; shell scheduling of bounded authenticated structure
lookups for the active character; one non-blocking
re-authorize banner in the Assets view; persistence of
resolved structure names in the existing `universe_names`
table; one demo fixture structure; tests at every seam
named in section 14.

Explicitly out of scope (each is a future slice if ever):

- No ESI writes of any kind. The slice adds exactly one
  GET call site (the already-written authenticated helper).
- No widening of `FIRST_AUTH_SCOPES`
  (`src/config.rs:33-39`). First sign-in stays
  least-privilege; the structures scope arrives only
  through a step-up the user approves in the browser.
- No Corporation structures or fuel module. No
  `esi-corporations.read_structures.v1`, no
  `/corporations/{corporation_id}/structures`, no
  corporation role preflights. That is the Corporation
  slice; its Flutter registry entry (section 3) is cited
  here only as the scope-string source for a different
  endpoint and must not be ported.
- No structure search endpoint
  (`GET /characters/{id}/search/` with a structure
  category), no structure list endpoint, no "find
  structure" UI.
- No database schema migration. Section 8 proves the
  existing `universe_names` table already holds structure
  rows.
- No new views, no new panels beyond the one Assets
  banner, no Settings changes.
- No per-character name cache and no cache expiry work.
  The cross-character consequence is accepted and
  recorded in sections 4.3 and 8.2, not engineered away.
- No change to the structure-id threshold
  (`STRUCTURE_ID_MIN`, resolver.rs:29). The conflict with
  Flutter's threshold is recorded in section 16.
- No asset container-hierarchy work. An asset whose
  `location_id` is a parent item id at or above
  `STRUCTURE_ID_MIN` is misclassified as a structure
  today (assets design decision D8,
  `docs/assets-port-design.md:141`); it will now also be
  *looked up* as one. The displayed result is unchanged
  ("Unknown Location" after ESI refuses), the wasted
  lookup is bounded by the section 7 cap, and the
  hierarchy follow-up remains its own slice.

## 3. Grounding: endpoint, scope string, and 403 semantics (LOCKED)

Every ESI-behaviour claim in this design traces to one of
the inspected bodies in this section. Where sources
disagree, the body with running-code evidence for the
exact endpoint wins; section 16 records each conflict.

### 3.1 The endpoint requires a character token

- Rust running code:
  `endpoints::get_structure_for_character`
  (endpoints.rs:733-749) issues
  `auth_get("/universe/structures/{structure_id}/", character_id)`
  and its doc comment (lines 730-732) records the
  contract: "ESI 403s for structures the character cannot
  see, surfaced as `EsiError::Reauthorize`; resolvers map
  that to "Unknown Location"". The public sibling
  `get_structure` (lines 721-728) documents that the
  unauthenticated attempt "usually 401s" against live ESI.
- Flutter running code at `ed698d3`:
  `EsiClient.getStructureName`
  (`lib/core/network/esi_client.dart:631-642`) calls
  `authenticatedGet('/universe/structures/$structureId/', characterId: characterId)`,
  returns the body's `name`, maps HTTP 403 to `null`, and
  rethrows everything else. Its callers pass the
  data-owning character: asset sync
  (`lib/features/assets/data/asset_sync_service.dart:142-144`)
  and clone/home locations
  (`lib/features/characters/data/character_status_providers.dart:138-141`).
- `src/error.rs:43-44` maps HTTP 401 to
  `EsiError::Unauthorized` and 403 to
  `EsiError::Reauthorize`, discarding the response body.
  No inspected body distinguishes "scope missing" 403
  from "character cannot dock there" 403; Flutter maps
  both to the same `null`. This design therefore assumes
  the two are indistinguishable on the wire and
  disambiguates locally from stored token metadata
  (section 5.2). That assumption is an evidence limit,
  recorded here, not a verified ESI fact.

### 3.2 The exact scope string

The scope is `esi-universe.read_structures.v1`. Its only
inspected sources are Flutter bodies at `ed698d3` that
name it for this exact path:

- `lib/features/corporation/data/corporation_endpoint_registry.dart:182-189`:
  registry entry id `structureName`, path template
  `/universe/structures/{structure_id}`, scope
  `esi-universe.read_structures.v1`, preflight
  "Character-specific structure ACL".
- `test/features/corporation/data/corporation_endpoint_registry_test.dart:163-169`
  repeats the same path and scope as a test oracle.
- `docs/specs/corporation-module.md:707` (at `ed698d3`)
  tabulates the same path/scope pair with the note
  "Character's actual structure access; corporation role
  alone is insufficient".

Two near-miss strings must not be used:
`esi-corporations.read_structures.v1` (registry line 174,
for `/corporations/{corporation_id}/structures`) is the
Corporation slice's scope for a different endpoint, and
no other `read_structures` string appears in any
inspected body.

Flutter's own sign-in scope lists
(`lib/core/config/eve_config.dart:50-158` at `ed698d3`)
never contained `esi-universe.read_structures.v1` — the
retired app issued the authenticated call with tokens
that had never requested the scope. That is a Flutter
gap, not parity to copy: the registry entry is the
running-code body that names the scope for the endpoint,
and Rust's step-up model (section 5) is how the scope is
actually granted. The context library's platform specs
name no scope for the personal structure path at all
(only the corporation one), so they neither ground nor
contradict the string.

### 3.3 What a successful response carries

`StructureInfo` (`src/esi/models.rs:358-367`) already
models the response: `name`, `solar_system_id`,
`type_id`, `owner_id`, all `#[serde(default)]`. Only
`name` is consumed by this slice; the rest stay unused
(no new display derives from them).

## 4. The authenticated lookup contract (LOCKED)

### 4.1 Call shape

Structure names resolve only through
`endpoints::get_structure_for_character(client, structure_id, character_id)`
(endpoints.rs:733-749) — an authenticated
`GET /universe/structures/{structure_id}/`. The public
helper `endpoints::get_structure` (endpoints.rs:723-728)
is **deleted** in this slice: this design removes its
only caller (resolver.rs:269, grep-verified as the sole
call site), and keeping a documented-broken public helper
invites a regression. `get_structure_with_token`
(endpoints.rs:751-766) is untouched (also callerless, but
removing it is unrelated churn).

Non-structure ids keep the existing public batch path
(`endpoints::resolve_names`, endpoints.rs:694-700,
`POST /universe/names/`) exactly as today. Structure ids
never enter that batch: `/universe/names/` cannot resolve
them (resolver.rs module doc, lines 8-11).

### 4.2 Whose token answers

The token belongs to the **data-owning character, which
in this architecture is always the active character**
(`AppState::active_character_id`, set by
`set_active_character` at `src/app/state.rs:745-835`).
Only the active character's assets, wallet, industry,
character-detail, and own-orders bundles exist in memory
(the refresh at shell.rs:1860 fetches one character; the
per-view states are reset on switch at state.rs:763-831),
and `schedule_name_resolution` runs against exactly those
bundles plus the market selection. This matches Flutter,
whose two callers pass the character whose assets or
clones are on screen (section 3.1). There is no
multi-character fan-out and no "try every character until
one can see it" behaviour: one pass, one character, at
most the section 7 cap of calls.

When there is **no active character** (for example public
market browsing before sign-in), no token exists, so no
structure lookup is attempted and no step-up state is
set. Structure-class locations simply stay
"Unknown Location" (rank 1: honest over helpful).

### 4.3 The cross-character consequence (accepted, spelled out)

The name cache is global: `NameResolver`'s in-memory map
(resolver.rs:45) and the `universe_names` table
(`src/storage/schema.sql:66-70`) have no character
column, and startup hydration loads every row for every
character (`hydrate_from_db`, resolver.rs:175-182).
Structure *visibility* in ESI is per-character (the
registry preflight above: "Character-specific structure
ACL"). Therefore a structure name learned under character
A's access will render for character B, who might not be
able to dock there.

This is accepted deliberately (parent hard scope: persist
structure names "exactly like other names"):

- The name is a display string. Once any character on
  this device can dock at the structure, the user already
  knows its name; showing it for another of the user's
  own characters leaks nothing to anyone else.
- It matches how every other cached name behaves today
  (station, character, and corporation names resolved
  under one character already render for all).
- Flutter made the opposite choice —
  `resolveStructureNames`
  (`lib/features/characters/data/character_status_repository.dart:299-355`
  at `ed698d3`) deliberately did not cache because
  "access depends on character" — and paid one HTTP call
  per structure per display refresh for it. Rank 6
  (reuse the shipped cache exactly like sibling names)
  wins over Flutter's stance; section 16 records the
  divergence.

The wrong-token corollary is handled by retry semantics,
not by caching per character: a structure denied for the
active character is re-attempted under the next character
the user switches to (section 6.3), because denial says
something about that character, not about the structure.

## 5. Scope placement and step-up UX (LOCKED)

### 5.1 A new single-scope group

`src/config.rs` gains one constant, placed with the other
step-up groups (after `FITTINGS_SCOPES`, config.rs:101),
with the sibling doc-comment shape:

```rust
/// Player-structure name step-up scope: look up a
/// player-built structure's name with the active
/// character's token. Granted after first sign-in via
/// step-up, never at first auth.
pub const STRUCTURE_SCOPES: &[&str] = &["esi-universe.read_structures.v1"];
```

`FIRST_AUTH_SCOPES` (config.rs:33-39) is not touched, and
no existing group gains the scope. Extending an existing
group was considered and rejected for every candidate:

- `ASSETS_SCOPES` (config.rs:64): the already-granted
  shortcut's observed-reality arm for assets keys on
  `assets_needs_reauthorize` (shell.rs:2060), which only
  the assets fetch sets (shell.rs:867-871). A structure
  403 never sets it, so a user whose token metadata
  claims the widened group but who never actually
  granted the structures scope would loop the shortcut
  forever. It also conflates two consents: granting
  asset reading would silently claim structure lookup
  was granted too, and users who granted the old
  single-scope group would be recorded as holding a
  scope EVE never asked them for.
- `CHARACTER_DETAIL_SCOPES` (config.rs:74-80) and
  `INDUSTRY_SCOPES` (config.rs:87-90): the same
  observed-flag mismatch, plus consent the UI text
  cannot honestly describe (neither view's panel
  mentions structure names).
- `PHASE1_ENDPOINT_SCOPES` (config.rs:105-117) is a
  descriptive inventory, not a requestable group; the
  structures scope is not added there either (that list
  documents the Phase-1 endpoint set this slice predates
  in spirit and postdates in fact; editing it would
  rewrite history, not behaviour).

A dedicated group is also the least-surprising place by
sibling precedent: every post-first-auth permission in
this codebase is its own named group with its own
disjoint-from-first-auth test (config.rs:176-255), its
own observed-reality arm, and one owner view.

### 5.2 When the scope is missing: pre-check, never a doomed call

The shell decides scope presence **before** any structure
HTTP call, from stored token metadata — the same source
`start_stepup_login` trusts for its pre-check
(shell.rs:2012-2040: `repositories::get_token_meta`, then
`oauth::split_scopes` / `oauth::missing_scopes`,
`src/auth/oauth.rs:82-130`). A missing row, a failed
read, or a failed lock all mean "granted scopes unknown",
treated as empty, exactly as shell.rs:2015-2038 already
does.

Locked decision table for a pass that has at least one
missing structure id and an active character:

| Token metadata | Behaviour |
|---|---|
| Scope present | Spawn the bounded lookup pass (sections 6-7). Clear `structures_needs_reauthorize` (section 5.4). Per-id 403s are ACL denials: pin, no prompt. |
| Scope absent (or metadata unreadable) | Make **zero** structure HTTP calls — ESI would 403 every one and burn the error limit for nothing. Set `structures_needs_reauthorize`. Leave every id unpinned (section 6.3) so the grant the user is about to make actually takes effect. Non-structure batch resolution proceeds normally. |

This is deliberately *not* "call first, interpret the
403": the wire cannot distinguish the two 403 causes
(section 3.1), so the local metadata must speak first.
Wiring structure 403s straight to
`endpoints::needs_reauthorize` (endpoints.rs:786-791)
would raise the step-up prompt for every structure the
character simply cannot dock at — the prompt-loop failure
this design exists to avoid (rank 2: the browser opens
only for a permission that is actually missing).

One stale-metadata case is knowingly left unprompted:
metadata claims the scope but ESI 403s every lookup
because the grant is not real. That is indistinguishable
from "this character can dock at none of these
structures" with the evidence available, so names stay
"Unknown Location" and no banner appears. The user can
still recover by removing and re-adding the character.
Recorded here as a known limitation, not silently
assumed away.

### 5.3 The one surface that offers re-authorize: an Assets banner

Owner view: **Assets** (`src/ui/assets.rs`). Rationale:
assets are where structure locations dominate (grouped
by `location_id`, assets.rs:64-117), Flutter's primary
caller was asset sync, and every existing scope has
exactly one owner view (Assets → assets scope,
Characters → character-detail, Industry → industry,
Planets → planets, Market → market, Fittings →
fittings). Wallet, Industry, Characters, Market, and
Dashboard keep showing honest "Unknown Location" for
structure ids and gain the resolved names automatically
once the user grants from Assets and a refresh resolves
them (rank 7). Replicating the button into five views is
rejected: five nag surfaces for one permission, and five
places to keep consent text honest.

Shape: a **non-blocking banner**, never the full-view
early return the assets-scope panel uses
(assets.rs:204-208). Structure names being unavailable
must not hide asset data that loaded fine. Placement in
`show`: after the existing `assets_needs_reauthorize`
early return (so a character missing the assets scope
sees that panel first and this banner only once assets
load — permissions are asked one at a time, in dependency
order), and only when the assets snapshot is
`LoadState::Ready` with at least one item. The banner
renders when `state.structures_needs_reauthorize` is
true; it does not inspect which groups are unresolved
(the flag is set only when a pass actually found missing
structure ids for this character, section 5.2).

Exact strings (LOCKED; modelled line-for-line on the
assets panel at assets.rs:159-194):

- Heading: `Some location names need one more EVE permission.`
- Body: `This character has not granted esi-universe.read_structures.v1, the EVE SSO scope that lets Mimir look up player-built structure names. Locations inside player structures show as Unknown Location until it is granted; everything else is unaffected.`
- Consent line (same template as assets.rs:168-173, with
  the active character's name substituted for `{name}`,
  shown only when an active character exists):
  `Choose Re-authorize and Mimir opens EVE SSO in your browser for {name}, asking for the permissions already granted plus this one. Sign in as {name}: approving as a different character is rejected and nothing is saved.`
- Button: `Re-authorize with EVE SSO` (identical to every
  sibling panel).
- On click, status message:
  `EVE SSO requested: your browser should open to login.eveonline.com.`
  (identical to assets.rs:191-192).
- On click, log line (same shape as assets.rs:185-189):
  `[AUTH] step-up re-authorize requested from Assets view character_id={} scopes={}`
  with `EveConfig::STRUCTURE_SCOPES.join(" ")`.
- Click action: `state.stepup_requested = Some(StepUpRequest::new(active_id, EveConfig::STRUCTURE_SCOPES))`
  — nothing else. The shell drains it through the
  unchanged `start_stepup_login` (shell.rs:1973-2216),
  which unions already-granted scopes with the request
  (shell.rs:2115), verifies the returned token's
  signature and character, and saves nothing on mismatch.
- Enablement mirrors assets.rs:175-179: disabled in demo,
  disabled while auth is busy (with spinner + auth label
  shown), disabled with no active character.

No view other than Assets sets a `STRUCTURE_SCOPES`
step-up request in this slice. Grep-level acceptance:
`STRUCTURE_SCOPES` appears in `src/ui/` only in
`assets.rs`.

### 5.4 The state flag and the already-granted shortcut

`AppState` (`src/app/state.rs:566-661`) gains one field
beside `assets_needs_reauthorize` (state.rs:579-581):

```rust
/// A name-resolution pass found player-structure
/// locations for the active character but stored token
/// metadata does not carry the structures scope, so the
/// Assets view shows the structure step-up banner.
pub structures_needs_reauthorize: bool,
```

Lifecycle (LOCKED, mirroring `assets_needs_reauthorize`):

- Set only by the shell's section 5.2 pre-check
  (scope-absent arm). Never set by a view, never set
  from an HTTP status.
- Cleared when a later pre-check finds the scope present
  (the pass then spawns lookups). This is the "grant
  actually loads" proof; like the assets flag
  (shell.rs:990-994), it is **not** cleared at
  `StepUpLoggedIn` — sign-in success alone does not
  prove the metadata will carry the scope on the next
  pass, and clearing early would hide the banner during
  the refresh that is supposed to resolve the names.
- Cleared on character switch to a different character,
  in `set_active_character` beside the assets reset
  (state.rs:775-776); same-character reselect keeps it.
- Cleared on character removal, beside state.rs:899.
  `remove_character` also already clears a pending
  `stepup_requested` for the removed character
  (state.rs:900-906) — unchanged, and it covers a
  structures request in flight.

The already-granted shortcut (shell.rs:2053-2101) gains
one observed-reality arm, following the extracted-helper
precedent of `fittings_stepup_observed`
(shell.rs:186-191):

```rust
fn structures_stepup_observed(request_scopes: &[String], state: &AppState) -> bool {
    request_scopes
        .iter()
        .any(|scope| EveConfig::STRUCTURE_SCOPES.contains(&scope.as_str()))
        && state.structures_needs_reauthorize
}
```

OR-ed into `observed_reauthorize` at shell.rs:2053-2070.
Why the arm is required even though section 5.2 makes it
hard to reach: the flag is set from metadata read at
pass time; metadata can change between that read and the
button click (for example the user completes a different
step-up whose union happens to include scopes granted
through another client). If the click then finds
`missing` empty (shell.rs:2040) with no observed arm,
the shortcut at shell.rs:2071 would skip the browser the
user just asked for, refresh, and — if the metadata is
stale in the other direction — loop. The arm makes the
observed "names are missing for scope reasons" state
outrank stored metadata, which is the stated principle
of the existing block (shell.rs:2048-2052). Characters
who granted only the older groups are unaffected: their
`missing` for a structures request is non-empty, so they
take the normal browser path with the union of old plus
new scopes (shell.rs:2115-2116), and the callback still
rejects a token that drops any previously granted scope
(shell.rs:2156-2167).

The shortcut's own follow-ups need no structures arm:
when the shortcut *is* legitimately taken it calls
`request_refresh("stepup-already-granted")`
(shell.rs:2078), whose `Refreshed` handler runs
`schedule_name_resolution` (shell.rs:882), whose
pre-check then clears the flag and spawns lookups.
Likewise `StepUpLoggedIn` (shell.rs:986-1027) needs no
new flag-queuing: the post-stepup main refresh reaches
the same scheduling point. (Market and Planets needed
explicit refetch flags because the main refresh never
touches their bundles; name resolution is part of the
main refresh tail, so structures ride it for free.)

## 6. Resolver API change and retry semantics (LOCKED)

Two layers implement the same contract: the resolver's
async fill (library correctness) and the shell spawn (the
live path, section 10). A resolver-only fix changes
nothing on screen because the shell never calls it;
a shell-only fix leaves `resolve_missing_esi` calling a
deleted helper. Both land in this slice.

### 6.1 `resolve_missing_esi` gains the character

New signature (resolver.rs:225-230 today):

```rust
pub async fn resolve_missing_esi(
    &mut self,
    client: &EsiClient,
    conn: Option<&rusqlite::Connection>,
    ids: &[i64],
    structure_character_id: Option<i64>,
) -> AppResult<Vec<i64>>
```

- `Some(character_id)`: structure ids resolve through
  `get_structure_for_character(client, id, character_id)`,
  bounded by section 7.
- `None`: no character context exists, so structure ids
  are not attempted at all. They are returned in the
  still-unresolved list but are **not pinned**
  (section 6.3) — the caller provided no token, which is
  a property of the call, not of the structures.
- The scaffold wrapper `resolve_missing`
  (resolver.rs:316-349) passes `None` (it has no
  character context; its doc comment is updated to say
  structures stay unresolved on that path). Its one
  internal call (line 341) and the cached-offline test
  (line 451) are updated to the new signature; the test
  passes `None`, preserving its no-network meaning.
- The structure loop (resolver.rs:268-292) keeps its
  shape — sequential, per-id match, category
  `"structure"` (lines 275-277) — with three changes:
  the authenticated helper replaces `get_structure`; a
  row is added to the persist list only when the name
  passes the section 9 displayable-name predicate
  (today the row is pushed before the insert guard can
  reject it, lines 272-277); and per-id outcomes feed
  the section 6.3 pinning table instead of the blanket
  pin at lines 300-303.
- Structure-loop failures never return `Err` from
  `resolve_missing_esi`. Batch (`/universe/names/`)
  failure behaviour is unchanged (warn + `Err`,
  resolver.rs:259-264): names already ingested into
  memory that pass must still persist even when every
  structure call fails.

### 6.2 Two small resolver additions

Both exist because the shell spawn cannot touch the
resolver (it is owned by `MimirApp`, shell.rs:100, and
mutated only on the UI thread):

```rust
/// Record ids ESI definitively refused (structure ACL
/// denials) so `missing` stops re-offering them this
/// session. Called by the shell when a structure pass
/// lands; `insert` remains the only per-id un-pin.
pub fn mark_unresolved(&mut self, ids: &[i64])

/// Drop session pins for structure-class ids only,
/// re-arming them under a different character's token
/// or a newly granted scope. Non-structure pins are
/// character-independent and stay.
pub fn forget_unresolved_structures(&mut self)
```

`forget_unresolved_structures` removes exactly the ids
in `unresolved` for which `is_structure_id` holds, and
logs the count at debug under `[ESI]`.

### 6.3 Pinning: exactly when a structure id leaves the retry set

Today every still-missing id is pinned into `unresolved`
at the end of a pass (resolver.rs:300-303), and
`missing()` then hides it for the rest of the session
(resolver.rs:167). Applied naively to structures that is
the stale-unresolved trap: fail once for a *fixable*
reason (no scope yet, wrong character active, ESI down)
and the id is never retried even after the user grants
the scope — the grant appears to do nothing (rank 3).

Locked per-outcome table for a structure id in a pass
(applies identically in `resolve_missing_esi` and in the
shell spawn/apply pair):

| Outcome | Pinned into `unresolved`? | Why |
|---|---|---|
| Resolved, displayable name | n/a (cached; `insert` removes any pin, resolver.rs:97) | Done |
| HTTP 403 (`EsiError::Reauthorize`) in a scope-present pass | **Yes** | ACL denial for this character; re-asking every refresh burns the error limit for a stable answer. Re-armed on switch/step-up (below) |
| `Ok` with empty name, or a name the section 9 predicate rejects | **Yes** | ESI answered; there is no displayable name to wait for |
| HTTP 401 (`EsiError::Unauthorized`) | No — and abort the rest of the pass | Token-class failure, not a structure answer; other sections already surface global auth failure |
| Transport error, timeout, HTTP 420/429/5xx, decode error | No — and abort the rest of the pass | Transient; the next scheduled pass retries. Aborting stops one outage from burning the whole cap on failures |
| Skipped: cap overflow (section 7) | No | Never attempted; next pass continues |
| Skipped: no character (`None`), or scope-absent pre-check | No | Never attempted; this is the trap case — the id must still be offered by `missing()` after sign-in or grant |

Non-structure pinning is unchanged (batch ids still pin
at end of pass exactly as today).

A pinned structure id leaves `unresolved` in exactly
three ways (LOCKED, exhaustive):

1. A successful `insert`/`insert_with_category` for that
   id (resolver.rs:97 — for example a DB row written by
   a pass under another character, then hydrated).
2. `forget_unresolved_structures()` called by the shell
   when the active character changes to a different
   character (hooked where the shell already detects the
   switch, shell.rs:1085-1094 — not in
   `set_active_character`, which cannot see the
   resolver). Denial was per-character; the new
   character's token deserves its own attempt.
3. `forget_unresolved_structures()` called by the shell
   in the `StepUpLoggedIn` handler (shell.rs:986-1027)
   when the step-up character is the active character.
   The post-stepup refresh then re-offers every
   previously denied structure under the new grant.
   (Scope-absent ids were never pinned, so for the
   common grant path this is a backstop; it matters for
   ids pinned by an ACL denial under a token that has
   since been re-granted with broader access.)

Process restart also clears pins (the set is in-memory
only, resolver.rs:46-48) — unchanged, and persisted
names make succeeded structures skip lookup after
relaunch (section 8).

## 7. Bounds: cap, dedup, ordering, failure isolation (LOCKED)

One shared constant and one shared selector in
`src/names/resolver.rs`, beside `NAMES_BATCH_SIZE`
(resolver.rs:24-25), used by both the resolver loop and
the shell spawn so the bound cannot drift between
layers:

```rust
/// Hard cap on authenticated structure lookups in one
/// resolve pass. Sequential per-id GETs are the only
/// per-id HTTP fan-out in name resolution; the rest of
/// the missing structures wait for the next scheduled
/// pass instead of bursting against ESI's error limit.
pub const MAX_STRUCTURE_LOOKUPS_PER_PASS: usize = 10;

/// The structure ids one pass may attempt: sorted
/// ascending (deterministic cap victims; resolved and
/// pinned ids drop out via `missing`, so progress is
/// monotonic across passes) and truncated to the cap.
pub fn structure_lookup_batch(missing_structure_ids: &[i64]) -> Vec<i64>
```

- **Cap: 10 per pass.** A pass is one
  `schedule_name_resolution` call (triggered only from
  the existing sites: `Refreshed` shell.rs:882,
  `MarketFetched` shell.rs:1037, planetary-detail apply
  shell.rs:1340 — never per frame, never from a view) or
  one `resolve_missing_esi` call. 10 is a chosen design
  constant, not an ESI-derived number: worst case it
  adds 10 sequential failures against an error-limit
  warn threshold of 20 remaining
  (`ERROR_LIMIT_WARN_REMAIN`, config.rs:123), and typical
  characters hold assets in fewer than 10 distinct
  player structures, so one refresh normally finishes
  the job; the overflow is picked up by the next refresh
  rather than dropped.
- **Sequential, never concurrent.** One awaited GET at a
  time, as the resolver loop already does
  (resolver.rs:268). Flutter's unbounded `Future.wait`
  fan-out
  (`character_status_repository.dart:320-349` at
  `ed698d3`) is explicitly not ported.
- **Dedup** comes from `missing()` (resolver.rs:160-172:
  deduped, `id <= 0` skipped, cached and pinned ids
  excluded). The same structure id appearing in assets,
  wallet, and industry therefore costs one lookup per
  pass, and asset *rows* never multiply calls — only
  distinct location ids do.
- **Ordering** is ascending id via
  `structure_lookup_batch`, so which 10 go first is
  deterministic and testable, independent of collection
  order across views.
- **Failure isolation** is the section 6.3 table: a 403
  records that one id as denied and the pass continues;
  a 401 or transport-class error aborts the remaining
  structure calls in that pass (ids left unpinned) but
  never fails the pass as a whole, never discards
  already-resolved batch names, and never touches
  non-structure resolution, which runs in its own spawn
  exactly as today.

## 8. Cache behaviour and staleness honesty (LOCKED)

### 8.1 No migration: the existing table already holds structure rows

`universe_names` is `(id INTEGER PRIMARY KEY, name TEXT,
category TEXT)` (`src/storage/schema.sql:66-70`, category
index at lines 99-100). Category is a free-form string;
the resolver already writes `"structure"` for structure
results (resolver.rs:275-277), the row type
`UniverseNameRow` (`src/storage/repositories.rs:86-90`)
round-trips it, and `upsert_universe_names`
(repositories.rs:759-781) / `get_universe_names`
(repositories.rs:806-838) / `list_universe_names`
(repositories.rs:841-857) need no change. The category
string for every structure row written by this slice —
resolver loop and shell spawn alike — is exactly
`"structure"`. No consumer branches on it (verified:
`NameResolver::category` has no non-test callers, and the
one category comparison in production code — the market
lookup's `inventory_type` filter, shell.rs:1465 — keeps
only `inventory_type`, so a `"structure"` row can never
pass or affect it), so it is bookkeeping
parity with sibling rows, not a display input. Flutter's
asset locations likewise stored location type
`'structure'` (`asset_sync_service.dart:149-152` at
`ed698d3`). **No schema migration ships in this slice.**

Persistence points are the existing ones, unchanged in
shape: `resolve_missing_esi` upserts its fresh rows when
a connection is given (resolver.rs:294-298), and the
shell apply handler upserts landed names
(shell.rs:906-918, extended to the new message in
section 10). A resolved structure name therefore
survives relaunch and is hydrated at startup like any
other name.

### 8.2 Staleness: a renamed structure keeps its old name

If a structure is renamed (or destroyed) in game after
Mimir cached its name, Mimir keeps showing the cached
name indefinitely. There is no expiry on any
`universe_names` row today — station, solar-system,
character, and corporation names are equally permanent —
so structures behave exactly like their siblings, which
is the parent hard scope ("persist exactly like other
names") and rank 6. The honest framing: Mimir shows the
last name ESI confirmed for that id, the same honesty
class as a renamed character whose cached name Mimir
still shows today. Flutter's structure path never cached
(precisely because "structure names can change",
`character_status_repository.dart:305-306` at `ed698d3`)
and its asset locations re-resolved after 7 days
(`asset_sync_service.dart:100-106`); neither is ported.
A future cache-expiry slice, if one ever exists, must
cover all name categories together; expiring only
structures here would invent a second caching policy
inside one table.

## 9. Numeric-name and empty-name guards (LOCKED)

The guard already exists and already covers structures
on the memory path: `insert_with_category`
(resolver.rs:84-99) rejects a name that is empty after
trimming, or purely numeric — digits with an optional
leading `+`/`-`, checked byte-wise so digit strings
beyond `i64` range are rejected too — logging
`[DB] ignoring empty or numeric name insert id={}` and
caching nothing, so lookups fall back to the
"Unknown Location" words (rank 1). Every structure name
reaches memory through it: the resolver loop calls
`insert_with_category(..., "structure")`
(resolver.rs:277), and the shell apply path calls
`extend_from_universe_names` (resolver.rs:102-107 →
`insert_with_category`). The existing test
`insert_rejects_numeric_names_so_lookup_never_returns_a_raw_id`
(resolver.rs:370-387) already proves the memory half.

Two persistence-side holes are locked shut in this slice,
both by one shared predicate extracted from the guard so
all three sites enforce byte-identical rules:

```rust
/// True when a remote "name" may be displayed and
/// persisted: non-empty after trimming and not purely
/// numeric (a numeric name would render as a raw ID).
pub fn is_displayable_name(name: &str) -> bool
```

- `insert_with_category` is refactored to use it
  (behaviour unchanged; its tests are the regression
  oracle).
- The resolver structure loop adds a row to its persist
  list only when `is_displayable_name(&info.name)` —
  today the row is pushed (resolver.rs:272-276) before
  the insert guard runs, so a numeric structure name
  would be written to `universe_names` even though
  memory rejects it.
- The shell structure spawn (section 10) constructs a
  `UniverseName` only for displayable names; an empty or
  numeric response puts the id on the denied list
  instead. The apply handler's unconditional upsert
  (shell.rs:906-918) therefore never receives a numeric
  structure row. (The same theoretical hole exists today
  for batch `/universe/names/` rows; fixing that path is
  out of scope — this slice guarantees only that the new
  structure path cannot write one.)

An `Ok` response whose name fails the predicate is a
definitive answer, not a transient one: the id is
pinned (section 6.3), and the pre-existing
`Ok(_) => "structure returned empty name"` arm
(resolver.rs:279-281) folds into this single rule.

## 10. Shell scheduling contract (LOCKED)

All in `src/app/shell.rs` unless noted. The existing
non-structure spawn (shell.rs:721-735) and its apply
handler (shell.rs:885-919) are not restructured; the
structure pass is a second, independent spawn beside
them.

### 10.1 Collection: route, don't exclude

`schedule_name_resolution` (shell.rs:549-736) keeps its
demo early-return (lines 550-552 — demo never schedules,
never sets the section 5.4 flag) and gains a second
collection vector. Each of the ten guarded sites (wallet
transactions 567, assets 578, jump clones 592, home
location 598, docked location 611, market top orders
632, own orders 640, industry facility 654, blueprints
662, colony solar system 677) changes from
"push if not a structure id" to routing through one
local helper:

```rust
let mut ids: Vec<i64> = Vec::new();
let mut structure_ids: Vec<i64> = Vec::new();
// per site: if is_structure_id(x) { structure_ids.push(x) } else { ids.push(x) }
```

The colony solar-system site (677) is routed uniformly
for consistency; solar-system ids never reach
`STRUCTURE_ID_MIN` in practice, so it is behaviourally
inert. The header comment (lines 545-548) is rewritten:
structures are no longer "excluded … a follow-up" but
resolved through "the bounded authenticated pass below".
All non-location pushes (type ids, character ids,
corporation ids) are untouched, and instance ids
(`ship_item_id`, `jump_clone_id`, job ids — see the
existing comments at shell.rs:584-648) remain
unscheduled.

### 10.2 The structure pass

After the existing missing computation
(shell.rs:710-720), independently of whether the batch
spawn runs:

1. `let structure_batch = structure_lookup_batch(&self.resolver.missing(&structure_ids));`
   Empty → nothing further (and the section 5.4 flag is
   left as-is: no structure locations are visible, so no
   scope opinion is formed this pass).
2. No active character, or no backends/runtime → return
   without spawning and without touching the flag
   (section 4.2).
3. Pre-check (section 5.2): read the active character's
   token metadata under the existing db lock and compute
   `oauth::missing_scopes(&granted, &STRUCTURE_SCOPES-as-Strings)`.
   Scope absent → set `structures_needs_reauthorize`,
   log once per pass
   `[ESI] structure name lookup skipped: structures scope not granted character_id={} pending={}`,
   spawn nothing. Scope present → clear the flag and
   spawn.
4. The spawn captures `esi`, `tx`, the batch, and
   `character_id` (the active character at spawn time —
   the identity stamp, rank 5), logs
   `[ESI] resolving {} structure names character_id={}`,
   then loops sequentially over the batch calling
   `get_structure_for_character`, classifying each
   outcome by the section 6.3 table: displayable `Ok`
   → `UniverseName { id, name, category: "structure" }`;
   403 or non-displayable `Ok` → denied list, continue;
   401/transport-class → log
   `[ESI] structure name lookup aborted: {}` at warn and
   stop (remaining ids appear in neither list). Error
   classification uses the typed error
   (`EsiError::Reauthorize` = denied;
   `EsiError::Unauthorized` and everything else = abort)
   — never string matching on error text.
5. If either list is non-empty, send the new message.
   A pass where every id aborted sends nothing; its ids
   stay unpinned for the next scheduled pass.

New `BackendMsg` variant (shell.rs:44-87), placed beside
`NamesResolved`:

```rust
StructuresResolved {
    character_id: i64,
    names: Vec<UniverseName>,
    denied: Vec<i64>,
},
```

### 10.3 Apply: identity-guarded, same tail as `NamesResolved`

The handler mirrors the two shipped guards — the
`Refreshed` inactive-character guard (shell.rs:788-795)
and the market identity match (shell.rs:1028-1042):

- `character_id != state.active_character_id` → drop
  the whole message (names and denials alike) with
  `[ESI] dropping structure names for inactive character_id={}`
  at warn. A late result must never mutate another
  character's session: not the cache (names learned
  under a character the user switched away from are
  discarded rather than silently globalized mid-switch;
  the next pass under the new character re-resolves
  what it can see), and never the pin set (denials were
  that character's ACL answers, section 6.3 rule 2).
- Otherwise: log
  `[ESI] resolved {} structure names ({} denied) character_id={}`;
  `resolver.extend_from_universe_names(&names)`;
  `resolver.mark_unresolved(&denied)`; then the exact
  `NamesResolved` tail — recompute the active
  character's summary location/ship via
  `detail_summary_names` (shell.rs:892-905) so a docked
  structure name upgrades the dashboard cell, and upsert
  the landed names to `universe_names`
  (shell.rs:906-918). Whether the tail is factored into
  a shared helper or repeated is the builder's choice;
  the observable behaviour must match `NamesResolved`
  exactly, including never creating a summary entry that
  does not already exist.

### 10.4 Re-arm hooks

- Active-character switch: where the shell already
  detects `active_character_id != last_active_id`
  (shell.rs:1085-1094), the non-demo arm also calls
  `self.resolver.forget_unresolved_structures()` before
  the switch refresh is requested. Login of a new
  character flows through the same detection
  (`LoggedIn` → `set_active_character`, shell.rs:982).
- `StepUpLoggedIn` (shell.rs:986-1027): in the
  active-character arm, call
  `forget_unresolved_structures()` before
  `request_refresh("post-stepup")`, with a comment in
  the style of the existing market/PI/fittings notes
  (shell.rs:998-1018) recording that the refresh's
  scheduling tail re-offers structures and the flag
  clears only when that pass's pre-check sees the
  scope. The non-active arm does not touch the resolver.

## 11. Demo story (LOCKED)

Demo has no tokens and must never fake a live lookup:
`schedule_name_resolution` returns before any structure
logic in demo (shell.rs:550-552), `start_stepup_login`
refuses in demo (shell.rs:1974-1982), the banner's button
is disabled in demo and its flag can never be set there
(sections 5.3-5.4). Nothing in demo mode performs,
simulates, or implies an authenticated ESI call.

What demo *does* show is a resolved structure name
arriving through the same bundled-sample path every other
demo name uses. Today no demo fixture contains a
structure-class location at all (verified: every
`location_id` in `assets/demo/*.json` is 60003760 or
60011866, both NPC stations, and `assets/demo/names.json`
has no structure entry), so the fixed display path is
invisible offline without a fixture. This slice adds
exactly one, as clearly-labelled sample data:

- `assets/demo/assets.json`: one new item for the first
  demo character (Aria Voss, 90000001), following the
  file's existing item shape and id conventions, with
  `location_id: 1030000000001`. The id is chosen above
  both structure thresholds in play — Rust's
  `STRUCTURE_ID_MIN` of 1,000,000,000 (resolver.rs:29)
  and Flutter's asset threshold of 1,000,000,000,000 —
  so it is structure-class under every inspected rule.
- `assets/demo/names.json`: one new entry
  `{ "id": 1030000000001, "name": "Demo Astrahus - Voss Logistics Hub", "category": "structure" }`,
  seeded by the unchanged `seed_resolver`
  (`src/demo/data.rs:918-926`) exactly like the demo
  station names beside it. (Seeding uses `insert`, which
  drops the category in memory — true of every demo name
  today and irrelevant to display; the JSON category is
  still recorded as `"structure"` for reader honesty.)

Provability, in order of strength:

1. **Fixture-driven tests are the proof** (section 14):
   in-process mock-HTTP tests drive the real
   `get_structure_for_character` and the real resolver
   against canned 200/401/403/500 responses, including
   the bearer-header assertion. That is what
   demonstrates the live path works; nothing about it
   depends on a real EVE account, and the README keeps
   its "not live-verified against a real EVE account yet"
   disclosure (section 12).
2. **A demo test** asserts the seeded demo resolver
   resolves the fixture structure's location name and
   the demo asset groups under it (section 14.5).
3. **The human-eye screenshot** is the `--demo` Assets
   view showing the `Demo Astrahus - Voss Logistics Hub`
   group heading. There is no screenshot harness in the
   Rust build (no capture code exists in `src/`), so —
   consistent with the README's standing "visual
   verification on macOS still pending" — the capture is
   a manual integrator step during the demo smoke
   (section 12), attached to the pull request by the
   parent for eyeballing. Builders commit no PNG: there
   is no screenshot directory precedent in this repo,
   and a committed raster proves nothing the tests do
   not. The screenshot is evidence for humans, never a
   gate, and it must be describable in one sentence:
   "demo Assets groups one item under a resolved
   player-structure name instead of Unknown Location."

## 12. Integrator wiring (LOCKED list)

Builders A and B own the code changes (section 15). The
integrator owns the items below outright, and verifies
the cross-builder wiring contract — if any line is
missing, the integrator sends it back rather than
patching around it:

- **Wiring checklist to verify** (code owned by builders):
  `STRUCTURE_SCOPES` exists with its disjoint test;
  `get_structure` is gone and `grep -rn "public_get"
  src/esi/endpoints.rs` shows no `/universe/structures/`
  call; all ten collection sites route structure ids
  (grep: no `!is_structure_id` remains in
  `schedule_name_resolution`); `StructuresResolved` is
  identity-guarded; both `forget_unresolved_structures`
  hooks are present; `structures_stepup_observed` is
  OR-ed into the shortcut; the Assets banner uses the
  section 5.3 strings verbatim.
- `README.md`, the **Assets** bullet (line 18): the
  claims locked here, final sentence-level wording the
  integrator's — locations inside player-built
  structures resolve by name once the character grants
  `esi-universe.read_structures.v1` through the same
  step-up flow (offered from the Assets view); until
  then, and for structures the character cannot dock
  at, those locations honestly read "Unknown Location";
  the step-up path has not been live-verified against a
  real EVE account yet (matching the disclosure every
  sibling bullet carries). The **Wallet** (line 17) and
  **Industry** (line 20) bullets' "resolved … location
  names" / "facility names" wording needs no change:
  once a name resolves through the shared resolver those
  claims simply become true for structures too, and the
  Assets bullet carries the scope disclosure for the
  one shared mechanism. No other README text mentions
  structure names or "Unknown Location" (grep-verified);
  `docs/rust-rewrite-design.md:23` already promises this
  behaviour and becomes accurate without edits.
- `src/ui/settings.rs`: **no change**. `[ESI]` and
  `[AUTH]` are already in `LOG_TAGS` (settings.rs:8-9);
  this slice introduces no new log tag.
- A grep pass over `README.md`, `CLAUDE.md`, and `docs/`
  for claims this slice falsifies (for example any
  "structures stay Unknown" or "authenticated structure
  lookup is a follow-up" wording outside historical
  design documents, which are records of their slices
  and stay untouched). Fix only live claims.
- Engineering journal: one
  `docs/engineering-journal/LEARNINGS.md` entry in the
  integration commit — the stale-unresolved mechanism
  (a session pin set makes a later permission grant
  appear to do nothing; failures caused by the
  *caller's* context must not be recorded as facts
  about the *id*) — with Evidence, Mechanism, and the
  generalizable rule, per repo practice. A `DECISIONS.md`
  entry is not required; this document is the decision
  record.
- Full gates (section 14) plus the demo smoke: run with
  `--demo`, open Assets for Aria Voss, confirm the
  `Demo Astrahus - Voss Logistics Hub` group renders
  with its item, confirm no step-up banner appears in
  demo, and capture the section 11 screenshot. Then a
  live-mode smoke without sign-in: confirm no banner,
  no structure lookups in the log, and no regression in
  ordinary name resolution.

## 13. Logging, safety, and repo rules

- Tags: `[ESI]` for every lookup-scheduling, lookup, and
  apply line in sections 6, 10 (the endpoint helper
  already logs `[ESI] GET /universe/structures/{}/`,
  endpoints.rs:738-742); `[AUTH]` only through the
  existing step-up machinery and the section 5.3 click
  line; `[DB]` only inside the resolver where sibling
  methods already use it. No new tag.
- Never log tokens, authorization codes, authorize URLs,
  or granted-scope strings beyond what the existing
  step-up code already logs (scope *names* in
  `StepUpRequest` debug lines are pre-existing,
  state.rs:154-158; this slice adds none).
- Resolved names only: no raw EVE numeric id is rendered
  by anything this slice adds; structure ids appear only
  in log lines, as sibling lookup logs already do.
- Late async results carry character identity
  (`StructuresResolved.character_id`) and are dropped on
  mismatch (section 10.3) — the repo's standing rule,
  applied to names and to pins.
- No new dependency, no schema change, no first-auth
  change, no ESI write. Grep-level acceptance for the
  whole slice diff: no `public_post`/`auth_post`/`PUT`/
  `DELETE` additions, no `FIRST_AUTH_SCOPES` diff, no
  `schema.sql` diff, no `Cargo.toml` diff.
- Commits are small and atomic in
  `type(scope): description` form with no attribution
  lines. Builders do not push or merge.

## 14. Test plan (LOCKED)

Gates for every commit (the CI set,
`.github/workflows/ci.yml`): `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`. No new dev-dependencies:
HTTP mocks are the shipped `tokio::net::TcpListener`
pattern (`one_shot_server`, endpoints.rs:904-925;
`client_with_fresh_tokens`, endpoints.rs:837-852, which
seeds a file-only `TokenStore` for character 7 with a
far-future expiry so no refresh or JWT verification runs;
`EsiClient::with_http` + `with_token_store`). Every
resolver structure test below therefore uses character
id 7 to match the seeded tokens. The resolver test
module needs its own minimal counting/routing mock
server in the same style (the endpoints helpers are
module-private); duplicating ~30 lines is preferred over
widening their visibility.

### 14.1 Config tests (Builder A, `src/config.rs`)

Mirror `fittings_scopes_is_the_single_stepup_scope`
(config.rs:243-255):

- `structure_scopes_is_the_single_stepup_scope`:
  `STRUCTURE_SCOPES == ["esi-universe.read_structures.v1"]`
  exactly, and every member is disjoint from
  `FIRST_AUTH_SCOPES`.
- `first_auth_scopes_match_least_privilege_set`
  (existing, config.rs:168-174) must still pass
  unmodified — first sign-in did not move.

### 14.2 Endpoint tests (Builder A, `src/esi/endpoints.rs`)

- Authenticated happy path: `one_shot_server(200,
  {"name":"Test Keepstar","solar_system_id":30000142,
  "type_id":35834})` + `client_with_fresh_tokens`;
  `get_structure_for_character(&client, 1030000000001, 7)`
  returns name "Test Keepstar", and the captured request
  asserts both the path
  `/universe/structures/1030000000001/` and an
  `Authorization: Bearer test-access` header (capture
  pattern at endpoints.rs:947-964,
  `asset_names_post_parses`). This is the test
  that proves the authenticated helper, not the deleted
  public one, is what runs.
- Scope/ACL refusal: `one_shot_server(403, …)` →
  `needs_reauthorize(&err)` is true (mirror
  `assets_scope_failure_needs_reauthorize`,
  endpoints.rs:968-973). The resolver/shell pin rule keys
  on exactly this classification.
- Deletion of `get_structure` is compile-proven: the
  slice builds with it and its doc comment gone.

### 14.3 Resolver tests (Builder A, `src/names/resolver.rs`)

All against the new signature, with an in-memory DB
(`db::open_in_memory`, pattern at resolver.rs:405-424)
where persistence is asserted:

- **Authenticated resolve + persist**: mock returns 200
  with a name for a structure id; `resolve_missing_esi(
  &client, Some(&conn), &[structure_id], Some(7))`
  leaves `location_name` returning that name,
  `category() == Some("structure")`, and a
  `universe_names` row with category `"structure"`
  (read back via `repositories::get_universe_name`,
  pattern at resolver.rs:436-440).
- **Stale-unresolved regression (the trap test)**:
  with `None`, a structure id returns still-unresolved
  and makes **zero** HTTP requests (counting mock), and
  — the assertion that fails on the base code's blanket
  pin — `missing(&[structure_id])` still contains the
  id afterwards. A follow-up call with `Some(7)` against
  the 200 mock then resolves it: the grant-simulating
  second call is what a pinned id would have swallowed.
- **403 pins**: `Some(7)` against a 403 mock → id in the
  returned unresolved list, `location_name` is
  "Unknown Location", and `missing()` no longer offers
  it. Then `forget_unresolved_structures()` → `missing()`
  offers it again (the switch/step-up re-arm).
- **Transport failure does not pin and does not wedge**:
  one batch id (200 via `/universe/names/` mock route)
  plus two structure ids against a 500 route →
  `resolve_missing_esi` returns `Ok`, the batch name is
  cached **and persisted**, both structure ids are
  returned unresolved, `missing()` still offers both,
  and the mock saw exactly **one** structure request
  (abort-the-rest, section 6.3).
- **Fan-out bound**: 12 distinct structure ids,
  `Some(7)`, counting mock returning 200 for all →
  exactly `MAX_STRUCTURE_LOOKUPS_PER_PASS` (10) HTTP
  requests, those 10 cached, the remaining 2 returned
  unresolved and still offered by `missing()`. Also
  unit-assert `structure_lookup_batch` directly: sorts
  ascending and truncates (feed an unsorted 12-id slice,
  expect the 10 smallest in order); empty in, empty out.
- **Numeric and empty names**: mock 200 with
  `{"name":"1030000000001"}` → not cached
  (`location_name` stays "Unknown Location"), **no DB
  row** (the section 9 persist hole), id pinned. Mock
  200 with `{"name":""}` → same. Plus
  `is_displayable_name` matrix: `""`, `"  "`, `"123"`,
  `"-5"`, `"+7"`, `"99999999999999999999"` false;
  `"Keepstar 9"`, `"  Perimeter - Tranquility Trading
  Tower "` true.
- **`mark_unresolved` / forget selectivity**: pin one
  structure id and one ordinary id (via
  `mark_unresolved`), assert `missing()` offers neither;
  `forget_unresolved_structures()` → `missing()` offers
  the structure id again but still not the ordinary id.
- Existing tests are regression oracles, unmodified
  except the signature update at resolver.rs:451:
  `insert_rejects_numeric_names_…` proves the
  `is_displayable_name` refactor changed nothing.

### 14.4 State and shell tests (Builder B)

- `src/app/state.rs`, mirroring the assets-flag tests
  (state.rs:1031-1059): `structures_needs_reauthorize`
  set true → switching to a different character clears
  it; reselecting the same character keeps it; removing
  a character clears it.
- `src/app/shell.rs`, mirroring
  `fittings_observed_reauthorize_blocks_shortcut_only_on_scope_refusal`
  (shell.rs:2650-2686):
  `structures_observed_reauthorize_blocks_shortcut_only_when_flag_set`
  — flag false → `structures_stepup_observed` false for
  a structures request; flag true + structures scope →
  true; flag true + an unrelated scope
  (`esi-assets.read_assets.v1`) → false.
- No new shell integration harness is required for the
  spawn/apply pair (none exists for
  `schedule_name_resolution` today; inventing one is out
  of scope). Their contract is covered where it is
  testable: batch selection (14.3), pinning (14.3),
  flag lifecycle (above), observed arm (above), and the
  endpoint bearer assertion (14.2). The identity-guard
  drop is a three-line mirror of two shipped guards and
  is covered by integrator code review against
  section 10.3, recorded here as a deliberate test-shape
  decision rather than an oversight.

### 14.5 Demo tests (Builder B, `src/demo/data.rs`)

In the existing test module (data.rs:1507+): the loaded
demo bundle's first character (90000001) holds an asset
whose `location_id` is 1030000000001, and the seeded
demo resolver (`demo_resolver`, data.rs:930-935) returns
`location_name(1030000000001) == "Demo Astrahus - Voss Logistics Hub"`
— together proving the seeded name is what
`group_assets` (assets.rs:64-117) will head that group
with, without demo code depending on the UI layer.

## 15. Ownership and sequence (LOCKED)

Frozen cross-builder contract (identifiers are exact;
neither builder renames):
`EveConfig::STRUCTURE_SCOPES`,
`MAX_STRUCTURE_LOOKUPS_PER_PASS = 10`,
`structure_lookup_batch`, `is_displayable_name`,
`NameResolver::mark_unresolved`,
`NameResolver::forget_unresolved_structures`,
`resolve_missing_esi(…, structure_character_id: Option<i64>)`,
`AppState::structures_needs_reauthorize`,
`BackendMsg::StructuresResolved { character_id, names, denied }`,
`structures_stepup_observed`, category string
`"structure"`, demo structure id `1030000000001`.

- **Builder A — scope group, endpoints, resolver.**
  Owns: `src/config.rs` (`STRUCTURE_SCOPES` + tests),
  `src/esi/endpoints.rs` (delete `get_structure`,
  endpoint tests), `src/names/resolver.rs` (signature,
  cap + batch selector, predicate, `mark_unresolved`,
  `forget_unresolved_structures`, pinning table, tests).
  Suggested commits:
  `feat(auth): add structure step-up scope group`;
  `feat(names): resolve structures through the authenticated endpoint`.
  Builder A touches nothing under `src/app/` or
  `src/ui/`; the resolver commit keeps the whole crate
  compiling (the shell does not call the changed
  signature — verified: only the wrapper and one test do).
- **Builder B — shell scheduling, step-up surface, demo.**
  Owns: `src/app/state.rs` (flag, switch/removal
  clearing, tests), `src/app/shell.rs` (collection
  routing, pre-check, structure spawn, `StructuresResolved`
  apply, observed arm + helper, both re-arm hooks,
  tests), `src/ui/assets.rs` (banner), `assets/demo/assets.json`,
  `assets/demo/names.json`, `src/demo/data.rs` (demo
  test assertions only — no seeding-logic change).
  Suggested commits:
  `feat(app): schedule bounded authenticated structure lookups`;
  `feat(assets): offer structure permission step-up from Assets`;
  `feat(demo): add a resolved player-structure location`.
  Builder B codes against Builder A's frozen contract
  above and does not edit `src/config.rs`,
  `src/esi/`, or `src/names/`.
- **Integrator.** Owns `README.md` claims, the journal
  entry, the stale-claim grep pass, full gates, and the
  demo + signed-out smokes with the screenshot
  (section 12). Verifies the section 12 wiring checklist
  against the builders' diffs. No other files.
- Sequence: design (this commit) → Builder A (A's
  contract is B's dependency) → Builder B → integrator.
  A and B may overlap only on B's state/UI/demo files,
  which depend on names, not on A's code landing first.
- Nobody edits `FIRST_AUTH_SCOPES`, `src/storage/`,
  `src/error.rs`, `src/auth/`, `src/ui/settings.rs`, any
  view other than `src/ui/assets.rs`, or the demo
  seeding logic. Any discovered need to do so is a
  design amendment, raised before the edit.

## 16. Recorded choices where sources disagreed or were silent

Complete list; each names the source behaviour replaced
and the ranking that decided it.

| Topic | Sources | Locked choice |
|---|---|---|
| Scope string source | Flutter registry + oracle test + corp-module spec name `esi-universe.read_structures.v1` for this path; Flutter sign-in lists omit it entirely; context library names only the corp scope | Registry string wins (running code for the exact endpoint); granted via Rust step-up, not copied from Flutter's lists |
| Which character's token | Flutter: data-owning character (asset sync, clone provider). Rust architecture: only the active character's bundles exist | Active character (= data-owning here); no fan-out across characters |
| Caching structure names | Flutter `resolveStructureNames`: deliberately uncached, per-character. Rust parent scope: persist exactly like other names | Global `universe_names` cache, category `"structure"` (rank 6); cross-character visibility accepted (section 4.3) |
| Fallback word for denied structures | Flutter: "Player Structure". Context library assets spec: "Unknown Structure". Rust running code: "Unknown Location" (resolver.rs:22) | "Unknown Location" — the shipped Rust contract; no new word (rank 1: one honest fallback everywhere) |
| Structure-id threshold | Rust: `>= 1_000_000_000` (resolver.rs:29, tested at 398-402). Flutter asset sync: `>= 1_000_000_000_000`. Context spec: `> 1_000_000_000_000` | Keep Rust's 1e9 (a superset; ids between 1e9 and 1e12 that are not structures get a refused lookup and the same "Unknown Location" display as today). Changing it is out of scope |
| Batching | Flutter: unbounded parallel `Future.wait`. Rust resolver today: unbounded sequential | Sequential, hard cap 10 per pass (rank 4) |
| 403 meaning | Wire: indistinguishable scope-missing vs ACL (section 3.1). `endpoints::needs_reauthorize` would prompt on both | Local token-metadata pre-check decides; scope-present 403 never prompts (rank 2) |
| Where re-authorize is offered | Sibling scopes: one owner view each. Structures render in six views | Assets only, as a non-blocking banner (section 5.3) |
| Stale names after in-game rename | Flutter: uncached + 7-day asset-location re-resolve. Rust siblings: never expire | Never expire, like every sibling name (section 8.2) |
| Wallet/Industry structure names | Flutter at `ed698d3`: no caller (wallet used `/universe/names/` and missed structures; industry had none) | Both resolve in Rust through the one shared scheduling pass — exceeding Flutter parity is free here because the shell already collects those location ids (shell.rs:567, 654, 662) |







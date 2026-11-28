# Rust character detail slice — design

Status: locked design for implementation. This document is the only
product of its branch; no Rust, fixture, or database change ships with
it. Builders and the integrator implement exactly what is written here
and treat deviations as design changes to be raised, not choices to
be made silently.

Base: `develop` at `a696279` (conversion, Assets, step-up OAuth, and
JWT signature verification merged). The retired Flutter app at
`ed698d3` is behavioral evidence only, read through git history; no
Dart file is restored.

## 1. What this slice is

The Characters view today shows public character information only:
name, corporation, alliance, security status, and birthday
(`src/ui/characters.rs:82-142`). This slice adds one read-only
character-detail bundle below that block, inside the existing
Characters view, with five sections:

1. Status: online state, current location, current ship.
2. Attributes: the five character attributes.
3. Active implants: implants in the character's current clone.
4. Jump clones: home location, jump clones and their implants, and
   clone activity dates.
5. Standings: faction, corporation, and agent standings.

It also fills the dashboard's existing "Location / ship" cell
(`src/ui/dashboard.rs:62`, `src/ui/dashboard.rs:126-135`) and the
Characters view's existing "Location:" / "Ship:" summary lines
(`src/ui/characters.rs:119-132`), which today never appear in live
mode because every producer writes `None`.

The slice is read-only and in-memory only. Every endpoint it needs
already exists unwired (section 2), so it adds no endpoint, no ESI
model, no database table, and no new view.

## 2. Evidence base (what was inspected, and what it forces)

Rust tree on `develop` at `a696279`, all bodies read in full unless
a line window is named:

- `src/esi/endpoints.rs` (598 lines). Seven typed authenticated
  getters already exist, each logging with a bracketed tag and never
  logging tokens: `get_attributes` (lines 41-52),
  `get_location` (lines 257-265), `get_ship` (lines 267-272),
  `get_online` (lines 274-279), `get_clones` (lines 281-286),
  `get_implants` returning `Vec<i64>` (lines 288-296), and
  `get_standings` (lines 298-306). The helper `needs_reauthorize`
  (lines 401-407) is true exactly for the typed reauthorize and
  unauthorized errors. A grep for all seven getters over `src/` and
  `tests/` returns no caller outside `endpoints.rs`: the wiring in
  this slice is entirely new, the calls are not.
- `src/esi/models.rs` (532 lines). Every payload type exists with
  per-field serde defaults: `CharacterAttributes` (lines 82-100),
  `CharacterLocation` with `docked_location_id()` returning
  `station_id.or(structure_id)` (lines 176-192), `CharacterShip`
  (lines 194-202), `CharacterOnline` (lines 204-214), `JumpClone`
  with `implants: Vec<i64>` (lines 216-228), `HomeLocation`
  (lines 230-236), `CharacterClones` (lines 238-248), and
  `Standing` (lines 250-258). There is no implant model because the
  implants endpoint returns bare type IDs.
- `src/config.rs` (164 lines). `FIRST_AUTH_SCOPES` (lines 33-39)
  already contains `esi-skills.read_skills.v1` and
  `esi-clones.read_implants.v1`. `FLEET_SCOPES` (lines 42-46) is the
  location/ship/online trio. `CHARACTER_SCOPES` (lines 49-53) is
  clones, implants (a duplicate of a first-auth scope), and
  standings. None of the three names the exact
  clones + standings + location trio this slice needs, and
  `PHASE1_ENDPOINT_SCOPES` (lines 68-80) is too broad because it
  adds `esi-characters.read_loyalty.v1` and repeats first-auth
  scopes. This is why section 5 adds one constant.
- `src/app/state.rs` (539 lines). `LoadState<T>` (lines 65-97),
  `StepUpRequest` (lines 125-146), data bundles `WalletData`,
  `SkillsData`, and `AssetsData` (lines 186-211), and
  `CharacterSummary` whose `location_name` / `ship_name` are
  display-ready resolved strings (lines 213-226). `AppState`
  (lines 228-273) has no detail field yet. The Assets ownership
  lesson lives in `set_active_character` (lines 294-330) and
  `remove_character` (lines 353-384), with its test
  `switching_character_clears_stale_assets` (lines 471-490).
- `src/app/shell.rs` (1335 lines, windows 1-500, 500-830,
  889-1148, 1137-1335). `BackendMsg::Refreshed` (lines 37-45),
  `schedule_name_resolution` (lines 340-400), the `Refreshed` arm
  (lines 406-463), `RefreshFailed` (lines 481-494),
  `StepUpLoggedIn` (lines 506-526), `start_refresh` with its
  tolerant Assets sub-fetch (lines 589-797), and the generic
  `start_stepup_login` with its already-granted pre-check
  (lines 889-1090, pre-check at lines 956-975).
- `src/ui/characters.rs` (189 lines), `src/ui/dashboard.rs`
  (239 lines), and `src/ui/assets.rs` (401 lines). Assets supplies
  the re-authorize panel shape (lines 157-195), saturating totals
  (lines 54-60), and the resolved-name test style
  (lines 309-356).
- `src/names/resolver.rs` (428 lines). `name()` falls back to
  `Unknown Item`, `location_name()` to `Unknown Location`
  (lines 130-147); `cached()` (lines 109-111) distinguishes
  "unresolved" from a resolved string; `missing()` dedups and
  ignores non-positive IDs (lines 149-164); `is_structure_id`
  (lines 27-35) marks player-structure IDs that
  `/universe/names/` never resolves.
- `src/demo/data.rs` (894 lines). `DemoCharacterData` and
  `DemoBundle` (lines 77-105), the Assets fixture precedent
  `AssetsFileEntry` (lines 133-139), the backwards-compatible
  loader chain (lines 149-225), `validate_bundle` validating
  assets only when present (lines 288-298), `apply_character`
  (lines 472-528), and `seed_demo_state` (lines 533-597).
- Fixtures under `tests/fixtures/` parsed by `tests/esi_models.rs`:
  `attributes.json`, `location_ship_online.json` (solar system
  30000142, station 60003760, ship type 587, custom name
  "Fixture Frigate", 412 logins), and `clones_standings.json`
  (one jump clone at station 60003760 with implants
  `[22119, 22120]`, standings `3.25` and `-1.5`). No bare implants
  fixture exists; the clone fixture carries the implant-ID shape.

Flutter evidence at `ed698d3` (prior archeology, files cited there):
the live detail screen grouped Attributes, Jump Clones, and
Standings, with home location and active implants repeated on the
overview. Three behaviors are explicitly rejected below because
they were bugs: fallback text embedding raw numeric IDs
("Location {id}", "System #{id}", "Clone JC-{hex}"), implant slot
numbers invented from list position, and standings groups silently
dropping unrecognized `from_type` values. Standing colors and
number formats disagreed across three Flutter widgets; this slice
locks one format and no colors. The context library has no
behavior specification for clones, standings, or location display;
its skills index confirms only that `/attributes/` rides on
`esi-skills.read_skills.v1` and `/implants/` on
`esi-clones.read_implants.v1`. Where upstream is silent (standings
grouping and order, ship display string), this document decides.

## 3. Decisions locked by this design

- D1. One bundle type `CharacterDetailData` in `src/app/state.rs`
  holds seven per-section results. A failed section never fails
  the character refresh and never erases a sibling section.
  The new `AppState` field is named `character_details`
  (plural) so it cannot be confused with the existing
  `character_detail: LoadState<CharacterPublicInfo>`.
- D2. Exactly one step-up grant serves this slice: a single
  request for the new `CHARACTER_DETAIL_SCOPES` constant
  (five scopes, section 5), offered from one panel in the
  Characters view. Attributes and implants are already granted
  at first sign-in and never show that panel or any other
  step-up control.
- D3. Detail data is never persisted. No table, no migration,
  no repository function. The only disk writes remain the
  existing refresh persistence and universe-name caching.
- D4. Clone implants are type IDs. Every integer in
  `JumpClone.implants`, and every integer returned by the
  active-implants endpoint, is an inventory type ID to be
  resolved with `resolver.name()` (section 8 gives the
  endpoint evidence). Contrast `CharacterShip.ship_item_id`,
  which is an instance ID and is never resolved or displayed.
- D5. No new view, sub-tab, search box, or keyboard binding.
  The five sections stack vertically inside the existing
  Characters view scroll area, in the order of section 1.
- D6. ESI order is preserved for implants, clone implants,
  and jump clones. The only sorting in this slice is
  standings, inside each group, by value descending. There
  are no numbered implant slots and no standing color bands.
- D7. Integer totals saturate. Standings sign counts and any
  implant total are folded with `saturating_add`; a plain
  `+` or `sum()` over remote counts is a review failure.
- D8. A tolerated detail refresh replaces the whole bundle;
  there is no per-section merge with the previous bundle.
  Rationale: a transient error inside one character's own data
  is safe to show as that section's error, and replacement keeps
  state, summary strings, and tests consistent. The dangerous
  staleness class (one character's rows under another) is
  handled at the switch and removal boundaries instead,
  mirroring the Assets lesson. A hard refresh failure (no new
  bundle exists at all) keeps a ready bundle, section 6.4.

## 4. State: `CharacterDetailData` (Builder A)

All of this section lands in `src/app/state.rs`, next to
`AssetsData`, following the cross-builder contract style of
`WalletData` and `SkillsData`: the field set is frozen once
Builder A lands, demo code constructs it literally, and no
builder adds fields without a design change.

### 4.1 Types, exact shape

```rust
/// One character-detail section's failure. `needs_reauthorize`
/// is the typed scope outcome (HTTP 401/403 via
/// `endpoints::needs_reauthorize`), never parsed from `message`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SectionError {
    pub message: String,
    pub needs_reauthorize: bool,
}

pub type SectionResult<T> = Result<T, SectionError>;

/// Character-detail bundle: seven independent section results.
/// Field set is a cross-builder contract (demo seeding and the
/// shell construct this literally); do not add fields here.
#[derive(Debug, Clone)]
pub struct CharacterDetailData {
    pub attributes: SectionResult<CharacterAttributes>,
    pub implants: SectionResult<Vec<i64>>,
    pub clones: SectionResult<CharacterClones>,
    pub standings: SectionResult<Vec<Standing>>,
    pub location: SectionResult<CharacterLocation>,
    pub ship: SectionResult<CharacterShip>,
    pub online: SectionResult<CharacterOnline>,
}
```

No `Default` is derived for the bundle: there is no honest
default section result, and `LoadState::Loading` already covers
"nothing fetched yet". Constructors are explicit everywhere.

Three members on `CharacterDetailData`, all pure:

- `pub fn needs_detail_stepup(&self) -> bool` — true when any
  of `clones`, `standings`, `location`, `ship`, or `online`
  is `Err` with `needs_reauthorize`. It must not inspect
  `attributes` or `implants` (decision D2), and it is the
  only predicate the UI uses to show the step-up panel.
- Two free helpers, also pure and resolver-free so state
  keeps its current dependency shape:

```rust
pub fn summary_location_name(
    docked: Option<&str>,
    solar_system: Option<&str>,
) -> Option<String>
pub fn ship_display_name(
    custom_name: &str,
    resolved_type: Option<&str>,
) -> Option<String>
```

`summary_location_name` returns the docked name when given,
else the solar-system name, else `None`; inputs arrive from
`resolver.cached()` at the call site so "unresolved" stays
distinguishable from the `Unknown Location` word.
`ship_display_name` applies the custom-name rule of section 7:
trimmed empty and trimmed `"None"` are absent (the Assets
placeholder filter, `src/app/shell.rs:639-642`); both present
and different gives `"{custom} ({type})"`; only one present
gives that one; neither gives `None`.

`SectionError` carries no constructor that logs, and nothing
in state performs I/O, matching the module contract.

### 4.2 `AppState` field and lifecycle resets

One new field, beside `assets_needs_reauthorize`:

```rust
pub character_details: LoadState<CharacterDetailData>,
```

There is deliberately no `character_detail_needs_reauthorize`
boolean: the scope state already lives inside each section's
`SectionError`, and `needs_detail_stepup()` derives the one
panel decision. A parallel boolean would be a second source of
truth that switch and removal code could forget to clear;
resetting the bundle itself clears the derived state.

Resets mirror Assets exactly, because the same ownership
argument applies: this data is fetched tolerantly (a failed
sub-fetch still delivers a bundle), so ownership must reset at
the character boundary or one character's sections render under
another.

- `set_active_character` (state lines 294-330): inside the
  existing `previous.is_some() && previous != character_id`
  branch, beside the Assets reset, set
  `self.character_details = LoadState::Loading;` and log at
  debug: `[CHAR] clearing character details on character
  switch from={} to={}`. Same-character reselect touches
  nothing, so loaded sections and a pending step-up need
  survive a reselect.
- `remove_character` (state lines 353-384): inside the
  removed-was-active branch, beside `self.assets =
  LoadState::Loading;` and before the `set_active_character`
  call (which cannot detect the loss because the previous ID
  is already `None`), set `self.character_details =
  LoadState::Loading;` and log at debug:
  `[CHAR] clearing character details of removed active
  character`. In the characters-empty branch, add
  `self.character_details = LoadState::Empty;` to the
  existing list. Removing a non-active character leaves the
  bundle untouched: it belongs to the still-active character.
  The existing `summaries.remove` and pending-step-up clear
  in this function already handle the keyed and request side.
- `cycle_character` delegates to `set_active_character`, so
  PageUp/PageDown inherits the reset with no new code.
- Default state: `LoadState::Loading` (the derived default),
  which the first refresh, demo seed, or refresh failure
  replaces.

### 4.3 Section-to-endpoint map

| Bundle field | Existing call | Scope | Granted when |
| --- | --- | --- | --- |
| `attributes` | `get_attributes` `/attributes/` | `esi-skills.read_skills.v1` | first auth |
| `implants` | `get_implants` `/implants/` | `esi-clones.read_implants.v1` | first auth |
| `clones` | `get_clones` `/clones/` | `esi-clones.read_clones.v1` | this step-up |
| `standings` | `get_standings` `/standings/` | `esi-characters.read_standings.v1` | this step-up |
| `location` | `get_location` `/location/` | `esi-location.read_location.v1` | this step-up |
| `ship` | `get_ship` `/ship/` | `esi-location.read_ship_type.v1` | this step-up |
| `online` | `get_online` `/online/` | `esi-location.read_online.v1` | this step-up |

Public character info keeps its existing unauthenticated call
and its existing `character_detail` field; this slice does not
move it into the bundle.

## 5. Scopes and the one step-up request policy

### 5.1 The scope set

Builder A adds exactly one constant to `src/config.rs`, after
`ASSETS_SCOPES`, because section 2 shows no existing constant
fits and inventing the union at each call site would duplicate
it:

```rust
/// Character-detail step-up scopes (clones, standings, and the
/// location trio). Implants and attributes are already covered
/// by FIRST_AUTH_SCOPES and are deliberately absent.
pub const CHARACTER_DETAIL_SCOPES: &[&str] = &[
    "esi-clones.read_clones.v1",
    "esi-characters.read_standings.v1",
    "esi-location.read_location.v1",
    "esi-location.read_ship_type.v1",
    "esi-location.read_online.v1",
];
```

`FIRST_AUTH_SCOPES` is byte-identical after this slice, and
`CHARACTER_SCOPES`, `FLEET_SCOPES`, and
`PHASE1_ENDPOINT_SCOPES` are untouched and remain unused by
this slice. Excluding the duplicate implants scope from the
new constant is safe because the shell's step-up flow
authorizes with the union of already-granted and requested
scopes (`oauth::union_scopes`, shell line 989) and validates
the returned grant against that union (lines 1015-1041), so
first-auth scopes are retained whether or not the request
repeats them.

### 5.2 When the offer appears, and what one click does

One panel, in the Characters view only, directly above the
Status section (section 10 fixes the layout). It appears
exactly when all of these hold: an active character exists;
the app is not in demo mode; `state.character_details` is
`Ready(bundle)`; and `bundle.needs_detail_stepup()` is true.
It never appears for `Loading` or `Empty`, never for an
attributes or implants failure alone, and never replaces the
whole view: the public-info block, attributes, implants, and
every section that did load stay visible around it. This is
the per-section degradation the bundle exists for.

The panel follows the Assets panel's wording discipline
(`src/ui/assets.rs:159-195`): a heading, one sentence naming
in plain words what will not load (jump clones, standings,
location, ship, and online state) plus the joined scope
string, the sentence naming the active character and warning
that approving as a different character is rejected with
nothing saved, and the button whose text is exactly
`Re-authorize with EVE SSO`. The button is enabled exactly
when `!state.demo && !state.auth.is_busy() &&
state.active_character_id.is_some()`; while authentication is
busy it shows the spinner and auth label, like Assets. A
click logs at info `[AUTH] step-up re-authorize requested from
Characters view character_id={} scopes={}`, sets
`state.stepup_requested = Some(StepUpRequest::new(active_id,
EveConfig::CHARACTER_DETAIL_SCOPES))`, and sets the same
status sentence Assets uses. The view does nothing else: no
token handling, no browser code, no direct refresh.

### 5.3 Already-granted behavior (existing pre-check, reused)

`start_stepup_login` is already generic over the requested
scopes and needs no change for this slice. Its pre-check
reads stored token metadata, computes
`oauth::missing_scopes(&granted, &request.scopes)`, and when
nothing is missing it skips the browser entirely, requests a
refresh with reason `stepup-already-granted`, and reports
"That permission is already granted. Refreshing..." (shell
lines 928-975). So a character whose token metadata already
carries all five scopes (for example a grant made while a
stale 403 bundle was on screen) never sees a redundant
consent page; the click becomes a refresh. Demo mode, a busy
sign-in, and a removed character are already refused by the
same function (lines 890-927).

`StepUpLoggedIn` deliberately clears nothing (lines
506-526): a completed consent does not prove the data loads.
The post-step-up refresh replaces the bundle; sections that
now succeed stop reporting `needs_reauthorize`, the panel
predicate turns false, and the panel disappears. If the
refresh still 403s, the panel honestly stays.

One consequence is stated plainly: a character added before
implants joined the first-auth set could hold a token without
`esi-clones.read_implants.v1`. Its implants section then shows
the section error with no way forward except re-adding the
character. The hard scope forbids an implants step-up in this
slice; section 14 records this as an accepted gap.

## 6. Shell refresh wiring (integrator)

All of this section lands in `src/app/shell.rs`. No other
builder edits this file.

### 6.1 Message change

`BackendMsg::Refreshed` (lines 37-45) gains one field,
`detail: Box<CharacterDetailData>`. It is not a `Result`:
whenever the hard refresh chain succeeded, a bundle exists,
and failure information lives inside its sections. No boolean
companion field is added.

### 6.2 Tolerant sub-fetches in `start_refresh`

After the existing Assets block (lines 623-672), in the same
spawned task and in this fixed sequential order —
attributes, implants, clones, standings, location, ship,
online — fetch each section tolerantly: never `?`, never
`unwrap_or_default`. Map every outcome to its section:

```rust
let attributes = endpoints::get_attributes(&esi, id)
    .await
    .map_err(|e| {
        let needs_reauthorize = endpoints::needs_reauthorize(&e);
        tracing::warn!(
            "[CHAR] character detail section failed character_id={} section=attributes needs_reauthorize={} error={}",
            id, needs_reauthorize, e
        );
        SectionError {
            message: e.to_string(),
            needs_reauthorize,
        }
    });
```

The same shape applies to the other six, written out per
section (with its own `section=` value) rather than through a
new generic helper, so every failure logs its own line. The
error's display text never contains token material (endpoint
contract, `src/esi/endpoints.rs:1-4`), and token values,
codes, state, and authorize URLs are never logged anywhere
in this slice. On success, one info line closes the block:
`[CHAR] character details ready character_id={} implants={}
clones={} standings={}`, with counts read from the `Ok`
sections (`0` when a section is `Err`). The bundle joins the
existing result tuple and is sent in the message. The
persistence block (lines 683-780) is unchanged: detail data
is not written to the database (decision D3). `start_refresh`
for demo mode is unchanged; it already routes to
`apply_character`.

No concurrency is introduced. The refresh is sequential
today, seven more sequential reads keep failure behavior and
log ordering obvious, and parallel fetch can be proposed
later with measurements.

### 6.3 The `Refreshed` arm

Two changes, both inside the existing arm (lines 406-463):

1. The keyed summary insert (lines 416-427) computes
   `location_name` and `ship_name` from the incoming bundle
   by the rules of section 7, using `self.resolver.cached()`.
   This insert stays before the inactive guard, so a refresh
   that finishes after the user switched away still records
   that character's location and ship keyed summary, exactly
   as it records balance and training today.
2. In the active branch, before `schedule_name_resolution()`
   is called, set `self.state.character_details =
   LoadState::Ready(*detail);` (placement beside the other
   per-view writes, lines 437-440). The inactive guard then
   protects the bundle exactly as it protects skills and
   wallet: a switched-away character's bundle is dropped,
   never installed.

### 6.4 The `RefreshFailed` arm

Add the same keep-if-ready line the other bundles have
(lines 481-494): `if !self.state.character_details.is_ready()
{ self.state.character_details =
LoadState::Error(message.clone()); }`, ordered so the moved
`message` is used last. A ready bundle survives a failed
refresh; an unready one shows the error.

### 6.5 Late name arrival: `NamesResolved` recompute

Summary strings are frozen when written, but the names they
need may only resolve after `schedule_name_resolution`
returns. Today that gap is invisible because both fields are
always `None`; with real values it must close. In the
`NamesResolved` arm (lines 464-480), after
`extend_from_universe_names`, recompute: when an active
character exists, `character_details` is `Ready`, and a
summary entry for the active character exists, rewrite that
entry's `location_name` and `ship_name` from the bundle by
the section 7 rules, preserving every other field. Only the
active character is recomputed — it is the only bundle in
memory — and no entry is created when none exists, because
the `Refreshed` arm always creates the entry before name
resolution is scheduled. A debug log records the recompute:
`[ESI] recomputed location/ship summary after name
resolution character_id={}`.

### 6.6 Cached startup state

`load_cached_state` (lines 88-204) is unchanged: its summary
keeps `location_name: None, ship_name: None`, and
`character_details` stays `Loading` until the startup
refresh or its failure decides it. Offline launches
therefore show cached public info plus an honest detail
error, never invented detail data.

## 7. Summary fill rules (dashboard and Characters)

`CharacterSummary.location_name` and `.ship_name` are
display-ready strings or `None` ("not loaded"), per the type
contract (state lines 213-226). They are never the
`Unknown Item` / `Unknown Location` words and never a raw
ID; the Unknown words belong to the detailed Characters
sections, which resolve at render time. The producers are
the `Refreshed` insert, the `NamesResolved` recompute
(section 6), and demo seeding (section 9). All three compute
through the Builder A helpers of section 4.1.

Location, from an `Ok(location)` section (any `Err` yields
`None`):

- Docked candidate: `location.docked_location_id()`
  (station, else structure). Resolve with
  `resolver.cached(docked_id)`.
- Else, or when the docked name is not cached yet: the
  solar system, `resolver.cached(location.solar_system_id)`.
- `summary_location_name(docked_cached, solar_cached)`
  picks docked, else solar, else `None`.

A docked player structure deserves one note: structure IDs
are excluded from name resolution in this slice (section 8),
so `cached` misses and the solar system — a true statement
of where the character is — fills the summary until a future
structure lookup exists. The detailed Status section still
shows the docked line as `Unknown Location` (section 10),
so no information is misrepresented.

Ship, from an `Ok(ship)` section (any `Err` yields `None`):

- `ship_display_name(&ship.ship_name,
  resolver.cached(ship.ship_type_id))`.
- Custom name and resolved type, different:
  `"{custom} ({type})"`, e.g. "Fixture Frigate (Rifter)".
- Custom name equal to the type name, or type unresolved
  with a real custom name: the one string.
- No custom name: the resolved type name.
- Neither: `None`, upgraded by the section 6.5 recompute.

`ship.ship_item_id` is never consulted for display.

## 8. Name resolution additions (integrator)

`schedule_name_resolution` (shell lines 340-400) gains one
block, guarded by `Ready(bundle)` on `character_details`,
in the style of the wallet and assets blocks. Err sections
contribute nothing. Location-class IDs pass through the
existing structure guard `if !is_structure_id(id)`; type,
entity, and system IDs are pushed directly:

| Source (Ok section only) | IDs pushed | Structure guard |
| --- | --- | --- |
| `implants` | every implant type ID | no |
| `clones` | each `jump_clones[]` `location_id`; `home_location.location_id` | yes |
| `clones` | each `jump_clones[]` `implants[]` entry | no |
| `standings` | each `from_id` | no |
| `location` | `solar_system_id` | no |
| `location` | `docked_location_id()` | yes |
| `ship` | `ship_type_id` | no |

Everything downstream is reused unchanged: `resolver.missing`
dedups and drops non-positive values, resolution batches in
chunks of 1000 through the existing `POST /universe/names/`
call, and `NamesResolved` ingests and persists names as
today. No structure endpoint is called (the function's
existing comment keeps it a follow-up); structure locations
render as `Unknown Location` in detail and fall back to the
solar system in summaries.

Why clone implant integers are type IDs (decision D4),
from endpoint evidence rather than assumption. The
active-implants getter returns `Vec<i64>` with no per-item
structure (`src/esi/endpoints.rs:288-296`), and the Flutter
original sent those same integers to name resolution and
to a type-icon widget keyed by type ID, i.e. it treated
them as inventory types. `JumpClone` repeats the shape:
`implants: Vec<i64>` beside a distinct `jump_clone_id`
(`src/esi/models.rs:216-228`), and Flutter unioned all
clone implant integers into the same resolver call. The
fixture is consistent: `[22119, 22120]` sit in the
inventory-type value range beside station and ship-type
IDs. Instance IDs look different in this codebase:
`AssetItem` separates `item_id` from `type_id`, and its
per-instance custom names live in `AssetName` under an
explicit "never enter the resolver" contract
(`src/esi/models.rs:417-426`). The clones payload has no
such instance field or names channel. Rule: resolve clone
and active implant integers with `resolver.name()` and
schedule them for resolution as types; never route them
through asset-name machinery, and never treat
`jump_clone_id` or `ship_item_id` as resolvable.

## 9. Demo fixtures (Builder A)

Demo mode must show the full detail bundle offline for both
invented characters, with every rendered ID resolved. All
work is in `src/demo/data.rs`, `assets/demo/
character_detail.json` (new), and `assets/demo/names.json`
(additions). No demo data is seeded into the live database.

### 9.1 New fixture file

`assets/demo/character_detail.json`, keyed by character ID
string like the assets file, one entry per demo character:

```json
{
  "90000001": {
    "attributes": { "charisma": 20, "intelligence": 27,
      "memory": 21, "perception": 25, "willpower": 24,
      "bonus_remaps": 1 },
    "implants": [22119, 22120],
    "clones": {
      "jump_clones": [
        { "jump_clone_id": 91000001, "location_id": 60011866,
          "location_type": "station",
          "implants": [22119], "name": "Amarr spare" },
        { "jump_clone_id": 91000002, "location_id": 60003760,
          "location_type": "station", "implants": [] }
      ],
      "last_clone_jump_date": "2026-10-01T00:00:00Z",
      "home_location": { "location_id": 60003760,
        "location_type": "station" }
    },
    "standings": [
      { "from_id": 500001, "from_type": "faction",
        "standing": 3.25 },
      { "from_id": 1000125, "from_type": "npc_corp",
        "standing": -1.5 }
    ],
    "location": { "solar_system_id": 30000142,
      "station_id": 60003760 },
    "ship": { "ship_item_id": 710000002,
      "ship_name": "Aria's Rifter", "ship_type_id": 587 },
    "online": { "online": true,
      "last_login": "2026-11-15T08:00:00Z",
      "last_logout": "2026-11-14T22:00:00Z", "logins": 412 }
  }
}
```

The second character's entry (`90000002`, Marcus Hale)
differs in every section so switching visibly swaps all five
sections: different attribute values with intelligence 20
(the switch test's marker), an empty active-implant list,
one unnamed jump clone at 60003760 with no implants and a
home location at 60011866, at least three standings spanning
positive, zero, and negative including one `from_type`
outside the three named groups (rendered under "Other", its
`from_id` present in the demo names table), a location
docked at 60011866 with `solar_system_id` 30002187, ship
type 587, and `online: false` with a `last_logout`. Ship
custom names agree with the assets fixture ("Aria's
Rifter", "Marcus's Rifter") so the two views do not
contradict. Values stay fictional per the file header
contract.

### 9.2 Loader changes, backwards compatible

Mirror the Assets extension exactly:

- New constant beside lines 24-28:
  `pub const DEMO_CHARACTER_DETAIL_JSON: &str =
  include_str!("../../assets/demo/character_detail.json");`
- New private serde entry beside `AssetsFileEntry`, every
  field `#[serde(default)]` so a `"{}"` entry and a `"{}"`
  file both parse:

```rust
#[derive(serde::Deserialize, Default)]
struct CharacterDetailFileEntry {
    #[serde(default)]
    attributes: CharacterAttributes,
    #[serde(default)]
    implants: Vec<i64>,
    #[serde(default)]
    clones: CharacterClones,
    #[serde(default)]
    standings: Vec<Standing>,
    #[serde(default)]
    location: CharacterLocation,
    #[serde(default)]
    ship: CharacterShip,
    #[serde(default)]
    online: CharacterOnline,
}
```

- `DemoCharacterData` gains one field:
  `pub detail: Option<CharacterDetailData>`. It is `None`
  when the character ID is absent from the detail file —
  which is every bundle built by an older loader — and
  `Some` otherwise, with each entry field wrapped in
  `Ok(...)`. The absence distinction is what stops an old
  three-argument literal from displaying zero-valued
  attributes as if they were data.
- New loader `load_demo_bundle_with_detail(characters_json,
  skillqueue_json, wallet_json, assets_json,
  character_detail_json)` carries the real body.
  `load_demo_bundle_with_assets` keeps its signature and
  delegates with `"{}"` for the detail text;
  `load_demo_bundle_from` is untouched and therefore still
  yields `detail: None`. `load_demo_bundle()` calls the
  new loader with all five bundled constants. Non-numeric
  keys fail through the existing `parse_character_key`,
  and a debug log per character follows the assets block:
  `[DEMO] character_id={} detail implants={} clones={}
  standings={}`.
- `validate_bundle` validates detail only when present,
  like assets (lines 288-298): `jump_clone_id` values
  unique within a character; each present date among
  clone dates, remap dates, `last_login`, and
  `last_logout` parses with `parse_esi_datetime`.
  Attribute ranges and standing values are not policed.

### 9.3 Seeding and summaries

- `apply_character`: after the Assets write,
  `state.character_details = match &per.detail {
  Some(detail) => LoadState::Ready(detail.clone()),
  None => LoadState::Empty };` — mirroring the
  Empty-if-absent Assets rule so demo switching can never
  leave the previous demo character's bundle installed.
- `seed_demo_state`: the summaries loop (lines 556-576)
  fills `location_name` and `ship_name` for both characters
  from `per.detail` through the section 4.1 helpers. The
  resolution source is the demo name table loaded once
  before the loop (`demo_resolver()`, logging a warning and
  leaving `None` values on failure, mirroring the SDE
  warning at lines 550-553). The error arm (lines 589-596)
  additionally sets `character_details` to the same
  `LoadState::Error` as skills, wallet, and assets.
- `seed_bundle_into_db`: extends its existing comment:
  detail data, like assets, is in-memory only; nothing new
  is persisted.

### 9.4 Demo names

`assets/demo/names.json` gains one entry per newly rendered
ID, so the name-coverage test can require zero Unknowns:
the implant type IDs used (category `inventory_type`, plainly
invented names such as "Demo Memory Implant"), the solar
systems `30000142` ("Jita") and `30002187` ("Amarr", both
category `solar_system`), the faction `500001` ("Caldari
State", category `faction`), and the `from_id` of the
"Other"-group standing in the second entry.
Station, corporation, and ship-type IDs already exist in the
table. No name is empty or a bare number (existing test rule).

## 10. Characters view layout (Builder B)

All of this section lands in `src/ui/characters.rs` only.
Builder B edits no other file. Everything existing in the
file (sign-in block, switcher, public-info grid, summary
lines, logout/delete) keeps its current behavior; the new
content is inserted after the Active character block and
before the logout/delete block (today's lines 142-144).

Keyboard impact: none. No key is read, no `text_input_focused`
or `focus_search` state changes, keys 1-6, Ctrl/Cmd+R or F5,
`/` (which still has no search field in this view), and
PageUp/PageDown behave exactly as today (shell lines
1137-1196). The global vertical scroll area (shell line 1312)
already accommodates the longer view. No view-local scroll
area, tab, or selector is added.

Rendering, gated on the characters list being non-empty
(the existing early return at line 44 covers the empty case):

- `Loading`: `widgets::loading_panel(ui, "Loading character
  details...")`.
- `Empty`: `widgets::empty_panel(ui, "No character details
  yet.")`.
- `Error(e)` (the outer state only; per-section errors live
  inside `Ready`): `widgets::error_panel_with_retry`, which
  on click logs `[CHAR] retry requested after character
  detail load error` at warn and sets `retry_requested`,
  like the existing detail retry at lines 136-141.
- `Ready(bundle)`: first the step-up panel when section 5.2
  says so, then the five sections below, each introduced by
  a separator and `ui.heading`. The bundle is cloned once
  (the Assets snapshot idiom, `src/ui/assets.rs:209-210`) so
  buttons can borrow `state` mutably.

Per-section failure rendering inside `Ready`, uniform for all
seven sections: `Err` with `needs_reauthorize` shows the
sentence "Not authorized yet. Re-authorize above to load
this section." when the panel predicate is true, else
"Not authorized yet for this character." (the legacy-token
attributes/implants case of section 5.3). Any other `Err`
shows `Could not load {section}: {message}` with the
message from `SectionError`. Neither form shows a raw ID or
any token-derived text.

### 10.1 Status ("Status")

Composes the three independent sections; each line matches
its own result so one failure hides only its line:

- `online` Ok: "Online now" or "Offline" from the boolean,
  as a label/value row. `last_login` and `last_logout` rows
  appear only when `Some`, formatted with
  `widgets::format_date_short`. `logins` appears only when
  `Some`, as "Logins: {count}" — a count, not an entity ID,
  so digits are correct there.
- `location` Ok: when docked, a "Docked:" row with
  `resolver.location_name(docked_id)`; always a "Solar
  system:" row with
  `resolver.location_name(solar_system_id)`. Both fall back
  to the words `Unknown Location`, never a number.
- `ship` Ok: a "Ship:" row built with `ship_display_name`
  from the custom name and `Some(&resolver
  .name(ship_type_id))`, so the unresolved-type fallback is
  the words `Unknown Item`. (In this render-time context the
  helper receives a `Some`, unlike the summary producers
  which pass `resolver.cached()`.)

The pre-existing summary lines (Location, Ship, Skill
points) stay where they are and remain summary-only; mild
duplication with this section is accepted because the
summary is the dashboard's string and the section is the
authoritative detail.

### 10.2 Attributes ("Attributes")

One `egui::Grid` with five rows in fixed order —
Intelligence, Memory, Perception, Willpower, Charisma —
values as plain integers. A "Bonus remaps" row appears only
when `bonus_remaps` is `Some`; "Last remap" and "Remap
available" rows appear only when their dates are `Some`,
via `widgets::format_date_short`. No skill-points-per-hour
figure is computed (it needs dogma data this slice does not
consume) and no total of the five values is shown.

### 10.3 Active implants ("Active implants")

Empty list: "No implants currently active". Otherwise a
header line "N implant(s) active" (N is the list length)
and one label per implant in ESI order,
`resolver.name(type_id)`, falling back to `Unknown Item`.
No slot numbers, no ten-slot row, no icons.

### 10.4 Jump clones ("Jump clones")

From the `clones` Ok value, in this order:

- Home: when `home_location` is `Some`, a "Home:" line with
  `resolver.location_name(location_id)`.
- Activity dates: "Last clone jump" and "Last station
  change" lines when their dates are `Some`, via
  `format_date_short`. When the whole section would
  otherwise be empty and both dates are absent, no activity
  lines appear.
- Header "N jump clone(s)" (N is `jump_clones.len()`), or
  "No jump clones available" when empty.
- One block per jump clone, ESI order:
  - Title: the clone's `name` when `Some` and non-empty
    after trimming, else the words "Jump clone". Never a
    value derived from `jump_clone_id`.
  - Location: `resolver.location_name(location_id)`, with
    the ESI `location_type` word appended in parentheses
    only when it is `"station"` or `"structure"` (e.g.
    "Jita IV ... (station)"); any other value is not echoed.
  - Implants: "No implants" when empty, else one label per
    type ID in order via `resolver.name()`, plus a count
    when useful. A total across all clones, if shown, is
    folded with `saturating_add` (decision D7).

### 10.5 Standings ("Standings")

Empty list: "No standings yet". Otherwise:

- A counts line "{p} positive · {n} neutral · {g} negative"
  where positive is `standing > 0.0`, neutral is
  `standing == 0.0`, negative is `standing < 0.0`, each
  counted by a `saturating_add` fold.
- Groups in fixed order: "Factions" (`from_type ==
  "faction"`), "NPC corporations" (`"npc_corp"` or
  `"corporation"` — the live ESI spelling and the existing
  fixture spelling map to one group), "Agents" (`"agent"`),
  then "Other" for every remaining value including the empty
  string. No standing is dropped for an unrecognized type,
  and the raw `from_type` string is never rendered. Empty
  groups are omitted.
- Rows are sorted within each group by `standing`
  descending, ties by resolved name ascending, then by
  `from_id` ascending as an invisible deterministic
  tie-break (sorting keys are never displayed). A
  non-finite standing (NaN or infinite) sorts last in its
  group, is counted in none of the three sign counts, and
  renders the words "not available" instead of a number;
  formatting it into a numeric string is forbidden.
- Each row: `resolver.name(from_id)` (fallback `Unknown
  Item`) and the value formatted everywhere in this slice
  as `format!("{:+.2}", standing)` — one format, sign
  always, two decimals (fixture `3.25` keeps its precision;
  `-1.5` shows `-1.50`; zero shows `+0.00` and counts as
  neutral). No color coding and no Hostile/Good labels.

### 10.6 Pure helpers and where they live

So the rules above are testable without an egui frame,
Builder B factors at least these `pub` free functions in
`src/ui/characters.rs`, following the Assets
`group_assets` / `display_name` precedent:

```rust
pub fn attribute_rows(attrs: &CharacterAttributes)
    -> Vec<(&'static str, i32)>
pub fn implant_names(ids: &[i64], resolver: &NameResolver)
    -> Vec<String>
pub fn clone_display_name(clone: &JumpClone) -> String
pub struct StandingGroup {
    pub heading: &'static str,
    pub rows: Vec<StandingRow>,
}
pub struct StandingRow {
    pub name: String,
    pub standing: f64,
    pub standing_text: String,
}
pub fn standing_groups(
    standings: &[Standing],
    resolver: &NameResolver,
) -> Vec<StandingGroup>
pub fn standing_counts(standings: &[Standing])
    -> (usize, usize, usize)
```

(`StandingRow` and `StandingGroup` derive `Debug, Clone,
PartialEq` but not `Eq`, because `standing: f64` forbids
`Eq`. `standing_counts` returns its tuple in
positive, neutral, negative order.) The `show` function
renders from these; it contains no grouping or formatting
logic of its own. Every render path calls the counting in
10.5 through `standing_counts`, whose body is visibly a
saturating fold.

## 11. File ownership and the frozen contract

| Owner | Files (exhaustive) | May not edit |
| --- | --- | --- |
| Builder A | `src/app/state.rs`, `src/config.rs` (the one new constant and its test), `src/demo/data.rs`, `assets/demo/character_detail.json`, `assets/demo/names.json` | shell, characters UI, ESI, storage |
| Builder B | `src/ui/characters.rs` | everything else |
| Integrator | `src/app/shell.rs`, `README.md`, `tests/demo_seed.rs` (additive assertions only) | Builder A/B contracts |

Build order is A, then B, then the integrator. After A the
tree compiles and demo switching already swaps the bundle,
with the Characters view not yet rendering it. After B the
sections render in demo mode and stay `Loading` in live
mode. After integration the live path fills them. Each step
keeps `cargo test` green on its own.

The frozen contract across the three steps:

- Type and field names: `SectionError`, `SectionResult`,
  `CharacterDetailData` with the seven fields of section
  4.1, and `AppState.character_details`.
- Function names: `needs_detail_stepup`,
  `summary_location_name`, `ship_display_name`,
  `load_demo_bundle_with_detail`, and the section 10.6
  helpers.
- The constant `EveConfig::CHARACTER_DETAIL_SCOPES` with
  the five scopes in the order of section 5.1.
- The demo file name `assets/demo/character_detail.json`
  and the constant `DEMO_CHARACTER_DETAIL_JSON`.
- `DemoCharacterData.detail: Option<CharacterDetailData>`.

`src/ui/dashboard.rs` is edited by nobody: it already
renders the two summary strings. The integrator's README
change is one clause in the Characters bullet naming the
new sections and the step-up scope names, with the same
"not live-verified" honesty as the Assets bullet, moved to
cover both step-up paths or repeated for this one.

Logging discipline for every new line of code: `tracing`
with existing bracketed tags — `[CHAR]` for detail fetch,
state resets, and Characters-view actions; `[AUTH]` for the
step-up click; `[ESI]` for name-resolution work; `[DEMO]`
in demo code. No new tag is introduced, and no log line
carries a token value, authorization code, OAuth state,
authorize URL, or raw ESI entity ID beyond the character
and structure IDs existing code already logs internally
(logs are not UI; the no-raw-ID rule governs what renders).

## 12. Explicit non-goals

- No database schema migration, table, column, or
  repository function; detail state is in-memory only.
- No widening of `FIRST_AUTH_SCOPES`, and no first-auth
  change of any kind.
- No portraits, icons, or images, including the existing
  unused `portrait_url` helper.
- No employment-history endpoint (`/characters/{id}/
  corporationhistory/`), model, fixture, or placeholder.
- No new ESI writes, and no new ESI endpoint or model at
  all: the only calls are the seven existing getters and
  the existing name-resolution POST.
- No authenticated structure-name lookups; structures keep
  the `Unknown Location` word in detail.
- No new view, sub-tab, keyboard binding, search box, or
  sort control.
- No implant slot inference, standing colors or verbal
  bands, skill-points-per-hour calculation, or "top
  standings" summary.
- No change to Assets step-up behavior, JWT verification,
  or token storage.
- No push and no merge as part of authoring this design.

## 13. Test plan and gates

Every test below is a committed test in its owner's file.
Names are locked so reviewers can grep for them.

Builder A, `src/app/state.rs`:

- `switching_character_clears_stale_character_details`
  mirrors the Assets test: with a `Ready` bundle whose
  attributes intelligence is 27 and whose clones section is
  a reauthorize error, same-character reselect keeps
  `Ready` and `needs_detail_stepup()` true; switching
  yields `Loading`.
- `removing_active_character_clears_character_details`:
  removing the active character with one remaining yields
  `Loading` (never the removed bundle); removing the last
  yields `Empty`; removing a non-active character leaves
  the bundle `Ready`. The existing never-panic removal test
  also asserts `character_details` is `Empty` at its end.
- `needs_detail_stepup_only_for_protected_sections`: false
  for an all-Ok bundle, false when only attributes or only
  implants carries a reauthorize error, false when a
  protected section fails without the reauthorize flag,
  and true for each of clones, standings, location, ship,
  and online in turn.
- `summary_location_prefers_docked_then_solar` and
  `ship_display_name_combines_custom_and_type`: the
  section 7 tables, including trimmed-empty and `"None"`
  custom names and custom-equals-type.

Builder A, `src/config.rs`:

- `character_detail_scopes_are_the_five_stepup_scopes`:
  exact set equality, disjointness from `FIRST_AUTH_SCOPES`,
  and absence of the implants scope. The existing
  first-auth test continues to pin the first-auth set.

Builder A, `src/demo/data.rs`:

- `bundled_fixtures_load_and_validate` extended: every
  character's `detail` is `Some` with non-trivial data.
- `three_argument_loader_still_loads_with_empty_assets`
  extended: every `detail` is `None`, and a new
  `four_argument_loader_still_loads_without_detail` covers
  the assets loader the same way; `"{}"` as the detail text
  parses in `malformed_and_invalid_bundles_are_errors_not_panics`
  style (valid, all `None`).
- `duplicate_jump_clone_id_fails_validation` and a bad
  clone-date case, both errors, not panics.
- `apply_character_swaps_character_details` mirrors the
  custom-names test: applying Aria then Marcus installs
  different bundles (distinct intelligence values), with no
  stale section from the first.

Builder B, `src/ui/characters.rs`:

- `attribute_rows_keep_fixed_order`.
- `implant_names_resolve_and_fall_back_to_words`: empty
  resolver yields only `Unknown Item`, and no produced
  string parses as `i64` (the Assets assertion style).
- `clone_display_name_never_derives_from_id`: named,
  unnamed, and whitespace-named clones.
- `standing_groups_order_sort_and_keep_unknown_types`:
  group order, `npc_corp`/`corporation` merged, unknown
  and empty `from_type` kept under "Other", descending
  sort with name tie-break, `+3.25` / `-1.50` / `+0.00`
  texts, a non-finite value sorted last with
  "not available", and no name parsing as `i64`.
- `standing_counts_split_by_sign`: positive, zero,
  negative, and empty inputs.

Integrator, `tests/demo_seed.rs` (additive):

- `name_resolution_covers_every_demo_id_and_falls_back_safely`
  extended to every detail ID of section 8 for both
  characters: implant types, clone and home locations,
  standing sources, solar system and docked station, and
  ship type — none `Unknown`.
- `demo_seed_populates_state_and_switching_characters_works`
  extended: after seeding, `character_details` is `Ready`
  and both summaries carry the expected location and ship
  strings (for Aria: the Jita station name and
  "Aria's Rifter (Rifter)"); after switching to Marcus the
  bundle carries his values.
- A new `demo_character_details_render_resolved_for_both`
  mirroring the assets-render test through the section
  10.6 helpers.

The shell has no unit-test harness today, so integrator
wiring is covered indirectly: section-result mapping and
summary computation are A-owned pure code with the tests
above, message flow is compile-checked, and the demo path
exercises bundle installation and switching end to end in
state. Live behavior against a real EVE account remains
unverified, as the README already states for sign-in.

Gates for every step and for the integrated branch, from
the README: `cargo test`, `cargo clippy --all-targets --
-D warnings`, `cargo fmt --check`. Scope gates by grep and
diff before the implementation branch is called done:
`FIRST_AUTH_SCOPES` unchanged in the diff; no
`corporationhistory` anywhere under `src/`; no format
string in `src/ui/characters.rs` interpolating a raw
`*_id` field; no change under `src/storage/`; no change in
`src/ui/dashboard.rs`; `git diff --stat` shows only the
owned files of section 11 plus this design.

## 14. Risks and unresolved items

- The attributes scope (`esi-skills.read_skills.v1`) is
  grounded in the context-library skills index and the
  endpoint's `[SKILLS]` tag, not in a scope constant that
  names the route. If live ESI disagrees, attributes alone
  degrades to a section error by design; widening first
  auth to compensate would need a new decision.
- Legacy tokens minted before implants entered the
  first-auth set cannot load implants and get no in-app
  remedy in this slice (section 5.3). Re-adding the
  character is the workaround.
- Structure names wait for the authenticated structure
  lookup follow-up the shell already acknowledges; until
  then the solar-system summary is the honest location.
- Summary strings for non-active characters reflect their
  last refresh as the active character, as balance and
  training already do; background refresh of all characters
  is out of scope here.
- On the first live refresh, sections render with
  `Unknown Item` / `Unknown Location` words until
  `NamesResolved` is drained, the same transient Assets has
  today; summaries may show "not loaded" until the same
  moment and then upgrade without another refresh
  (section 6.5).
- No part of the live path (sign-in, step-up, JWT
  verification, these seven reads) has been verified
  against a real EVE account; the implementation PR must
  keep the README's not-live-verified statement accurate.

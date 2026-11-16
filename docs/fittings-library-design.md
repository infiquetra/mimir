# Saved-fittings library (Fittings) read-only slice — locked design

Base commit: `eeba919` on `develop` (the merge of pull request
\#568, the Planetary Industry port; the conversion, Assets,
step-up sign-in, JWT verification, character detail, Market, and
Industry slices are merged below it). Branch:
`feat/rust-fittings-library`. This document is the only commit
of the design step. It locks exactly one design. Builders and
the integrator implement this document; where this document and
any older note disagree, this document wins.

Flutter reference code lives only in git history at commit
`ed698d3` and is read with `git show ed698d3:<path>`. No Dart
file is restored, and no Flutter behavior is copied unless this
document says so explicitly.

## 1. What this slice is

One new read-only view, **Fittings**, showing the active
character's saved ship fittings as returned by EVE's
authenticated fittings list endpoint. The view lists fittings
by their saved name and resolved ship name, lets the user
search that list, select one fitting, read its items grouped
into word-named slot sections, and copy the selected fitting
to the clipboard in EFT format (EVE Fitting Tool text format,
the `[Ship, Fitting name]` block other tools paste-import).

That is the whole slice: list, search, select, read, and one
EFT-format clipboard export of the selected fitting.

## 2. Hard scope and explicit non-goals

In scope, and nothing else:

- One ESI read: the saved-fittings list (section 4).
- One additive step-up scope constant (section 5). The
  first-sign-in scope set `FIRST_AUTH_SCOPES` in
  `src/config.rs` does not change.
- In-memory state only (section 7). No database schema
  migration, no table, no persisted fitting, no offline cache
  of fittings.
- One pure EFT export function plus clipboard wiring through
  the egui copy API only (section 9).
- A demo fixture extension with serde backward compatibility
  (section 11).

Explicit non-goals. Each one is out, even where Flutter had it:

- No EFT or Pyfa import (Pyfa is the third-party fitting
  tool), no DNA-link import or export, no paste box. Flutter's
  import path (`importFromText`, `parseEft`, `parseDna` in
  `lib/features/fitting/domain/format_parser.dart` at
  `ed698d3`) is not ported.
- No fitting creation, editing, or deletion. No ESI `POST`
  and no ESI `DELETE`: Flutter's one fitting write
  (`saveFittingToEve`, `POST /characters/{id}/fittings/` in
  `lib/core/network/esi_client.dart` at `ed698d3`) is not
  ported, and the write scope `esi-fittings.write_fittings.v1`
  is never requested.
- No local fitting library persistence. Flutter's Drift
  `SavedFittings` table and `FittingRepository` are not
  ported; this slice reads the character's in-game saved
  fittings from ESI and holds them in memory only.
- No fitting simulator: no dogma (EVE's attribute and effect
  system), no fitting statistics, no DPS (damage per second),
  tank, or capacitor math, and no price totals. The loaded
  Rust bundle carries skill names only (`src/names/sde.rs`
  includes only `assets/sde/skills.json`); the dogma files on
  disk under `assets/sde/` are never loaded by Rust code, and
  this slice must not start loading them. Flutter's
  `dogma_engine.dart`, `cap_simulator.dart`, and
  `stats_panel.dart` are not ported, and neither are its ship
  browser, module browser, or fitting editor wheel.
- No current-ship fit reader and no combat-analyzer fit
  import. Those are separate Flutter features and stay out.
- No new request-flag family beyond what section 7 locks, no
  background polling of fittings, and no per-fitting network
  fetch (section 4 proves none is needed and none is
  grounded).

Standing rules that bind every line of this slice:

- Never log or print token values, authorization codes,
  OAuth state values, or authorize URLs.
- Rust logging goes through `tracing` with bracketed tags.
  This slice uses `[ESI]` (fetch), `[FITTING]` (view, export,
  and selection), `[DEMO]`, `[UI]`, and `[AUTH]` (step-up).
- The user interface shows resolved EVE names only. No raw
  numeric EVE identifier appears in any rendered string or in
  any error text on screen. Per-section failures use the
  fixed wordings locked in section 7.4; full error detail
  goes to `tracing::warn!` log lines only.
- Quantities render saturating, with negatives clamped
  (section 9.1). Nothing in this slice may panic on hostile
  or partial wire data.
- No attribution lines in any commit or file.

## 3. Evidence base (inspected bodies)

Every claim below was read in full or in the named window
during the design step. File paths are repo-relative unless a
commit prefix is given.

Rust tree at `eeba919`:

- `src/config.rs` (256 lines, full read): `FIRST_AUTH_SCOPES`
  at lines 33-39; step-up constants `ASSETS_SCOPES` (line
  64), `MARKET_SCOPES` (line 69), `CHARACTER_DETAIL_SCOPES`
  (lines 74-80), `INDUSTRY_SCOPES` (lines 87-90),
  `PLANETS_SCOPES` (line 95); exact-array plus
  disjoint-from-first-auth guard tests at lines 170-235;
  `scopes_string` join helper at lines 136-138.
- `src/app/state.rs` (1442 lines; read 1-600 and 600-999):
  `View` with nine variants and `View::ALL: [View; 9]` at
  lines 15-41, `label()` at 43-55, `from_index`/`index`/
  `next`/`previous` at 57-71; `LoadState<T>` at 74-106;
  `StepUpRequest::new` at 134-155; `SectionError` and
  `SectionResult<T>` at 222-231; `IndustryData` with
  `needs_industry_stepup` at 311-329; `PlanetaryData`
  (`colonies` list plus `Option<SelectedColonyDetail>`) with
  `needs_planetary_stepup` at 331-367; `AppState` per-view
  load states and request flags at 473-542;
  `set_active_character` switch resets at 623-699 (industry
  reset at 682, planetary reset plus selection clear and
  generation bump at 691-694); `remove_character` resets at
  722-777, including the empty-roster branch at 762-776;
  `view_navigation_wraps_and_indexes` test at 811-837
  asserting `from_index(8)` is Settings and `from_index(9)`
  is `None`.
- `src/app/shell.rs` (2395 lines; read the windows named
  here): `BackendMsg::Refreshed` carrying per-view bundles
  including `industry` and `planetary_colonies` at lines
  40-85; `schedule_name_resolution` at 423-595 (industry ID
  block and planetary ID block at its tail, instance IDs
  never scheduled); the `Refreshed` apply arm at 602-723,
  including the active-character guard, the planetary
  selection keep-or-drop merge, and the `RefreshFailed`
  whole-view fixed wordings `"character refresh request
  failed"` for industry and planetary; `StepUpLoggedIn`
  queuing a main refresh plus the separate Market flag and
  the planetary detail flag at 817-853; `start_market_fetch`
  (the on-demand spawn) at 1012-1131; `start_refresh` at
  1311 to about 1680, where assets, character detail,
  industry, and the colonies list are tolerant sub-fetches
  that never use `?` and map failures to fixed-wording
  `SectionError` values with the full error in a `warn` log;
  `start_stepup_login` at 1771-1920, including the
  `observed_reauthorize` overlap arms (Assets, Character
  Detail, Industry, Planets, Market) and the already-granted
  shortcut that queues a main refresh plus the Market flag
  plus the planetary detail flag, with the status line
  `"That permission is already granted. Refreshing..."`;
  `collect_keys` at 2057-2100 hardcoding `Num1` through
  `Num9` mapped to `View::from_index`; the view dispatch
  match and the `"Views (keys 1-9)"` and `"Keys: 1-9 views,
  ..."` hint strings at 2228-2267.
- `src/esi/endpoints.rs` (1575 lines; read 432-620 and
  760-790): industry jobs and blueprints are capped paged
  walks returning `(Vec, truncated)` under
  `INDUSTRY_MAX_PAGES`; `get_character_planets` is a single
  `auth_get` of `/characters/{id}/planets/`; there is no
  fitting getter and no fitting path anywhere in the file.
  `needs_reauthorize` at 764-769 is the only typed
  scope-failure test (HTTP 401/403 outcomes).
- `src/esi/models.rs` (1138 lines; read 1-60 and 590-700):
  every model derives `Debug, Clone, Default, Serialize,
  Deserialize` with `#[serde(default)]` on every field;
  nullability is preserved (`None` is never coerced to zero,
  see `PlanetPin`); unknown future wire fields are ignored.
  There is no fitting model.
- `src/esi/client.rs`: `auth_get` (line 321 per the survey;
  the single-shot authenticated GET the planets endpoint
  uses) is the client entry point this slice reuses.
- `src/ui/industry.rs` (820 lines; read 1-180) and
  `src/ui/planets.rs` (662 lines; read 1-120): the pure-view
  contract (`pub fn show(ui, state, resolver)`, never
  fetches, sets request flags only), rows pre-resolved
  through `resolver.name` / `resolver.location_name`,
  counts via `saturating_add`, values clamped with `.max(0)`,
  invisible numeric tie-breaks in sorts, and render caps.
- `src/ui/mod.rs` (full read): one `pub mod` line per view,
  alphabetical.
- `src/ui/widgets.rs` (271 lines per survey) and
  `src/ui/settings.rs` line 114: the remaining hardcoded
  `1-9` hint strings. A search for `clipboard`, `copy_text`,
  or `set_clipboard` over `src/` returns zero hits: no
  clipboard affordance exists yet. `Cargo.toml` pins
  `eframe`/`egui` 0.29.
- `src/demo/data.rs` (2139 lines; read 1-140 and 972-1150):
  nine `include_str!` fixtures at lines 27-36;
  `DemoCharacterData` with `industry: Option<DemoIndustryData>`
  and `planets: Option<DemoPlanetaryData>` at 123-136
  (deliberately not the view bundle types);
  `load_demo_bundle_with_planets` keeps every earlier
  `load_demo_bundle_with_*` signature working by forwarding
  with a `"{}"` empty next file; `apply_character` composes
  each view empty-if-absent and leaves view-local search
  text untouched. `assets/demo/` holds exactly the nine
  fixture files; there is no fittings fixture.
- `src/names/resolver.rs` (456 lines per survey; key lines
  read): `UNKNOWN_ITEM` is `"Unknown Item"` and
  `UNKNOWN_LOCATION` is `"Unknown Location"` (lines 21-22);
  `name()` at 139 and `cached()` at 117; `missing()` at 160
  deduplicates, skips non-positive IDs, and skips IDs already
  known unresolved; inserted names that are empty or
  all-digit are rejected, so a lookup can never return a raw
  numeric ID as a "name".
- `docs/pi-port-design.md` section 9.3 (read): the precedent
  for view placement, the pre-authorized single dispatch
  line for the UI builder, and label-based startup-view
  persistence needing no migration.

Flutter at `ed698d3` (read with `git show`, never restored):

- `lib/features/fitting/domain/format_parser.dart`, function
  `generateEft` (lines 352-392, read in full): writes the
  header `[shipName, name]`, then low-slot lines, a blank
  line, medium-slot lines, a blank line, high-slot lines, a
  blank line, rig lines, a blank line, drone lines as
  `Name xN`, a blank line, fighter lines as `Name xN`, and
  returns the buffer trimmed. It emits no `[Empty ...]`
  placeholders, no subsystem lines, no cargo lines, and no
  charge suffixes. The header is followed immediately by the
  first section (no blank line after the header).
- `lib/features/fitting/domain/esi_fitting_export.dart`
  (70 lines, full read): the ESI item shape is
  `{type_id, flag, quantity}`; flag prefixes are `HiSlot`,
  `MedSlot`, `LoSlot`, `RigSlot`, `SubSystemSlot` plus the
  slot index; the highest indices are 7/7/7/2/3; fighters
  use the bare flag `FighterBay` with their quantity.
- `lib/features/fitting/presentation/widgets/saved_fittings_dialog.dart`
  (full read): rows show the fitting name and
  `shipName • N modules`; "Copy as EFT" runs `generateEft`
  into the clipboard and confirms with
  `Copied "<name>" as EFT`; the empty list shows fixed
  wording. Its raw exception interpolation
  (`'Failed to load saved fittings: $e'`) is a defect and is
  not copied (section 7.4).
- The Flutter ESI client has exactly one fitting call, the
  `POST` write named in section 2. There is no Flutter
  fittings `GET` to port; the read endpoint in section 4 is
  grounded in the blueprint below, not in Flutter code.

Context library (read during the design surveys):

- `discovery/blueprint/09-api-data-sources.md` lines 41 and
  58-59 (read): the endpoint table row
  `Fittings | /characters/{character_id}/fittings/ | Saved
  fittings`, and the advanced-scopes list naming
  `esi-fittings.read_fittings.v1` and
  `esi-fittings.write_fittings.v1` as scopes requested
  incrementally, never at first sign-in. This is the single
  grounding for both the endpoint path and the read scope
  string (see unresolved item U2, section 13).
- `platform-specs/03-feature-modules/fitting/specification.md`
  `toEft` (lines 579-632, read): the same section order as
  the executed Flutter exporter (low, medium, high, rigs,
  drones) and then cargo lines as `Name xN`; its module line
  optionally appends `, chargeName`. Where the spec and the
  executed exporter differ (cargo, charges, a blank line
  after the header), section 9.2 states which one this slice
  follows and why. The fitting spec otherwise describes the
  Flutter simulator and contains no ESI fittings behavior:
  no response shape, no refresh cadence, no pagination rule.

## 4. Endpoint map (Builder A, `src/esi/endpoints.rs`)

Exactly one new endpoint function. No other fitting network
call exists in this slice.

```rust
pub async fn get_character_fittings(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<Vec<CharacterFitting>>
```

- Wire call: one `client.auth_get` of
  `/characters/{character_id}/fittings/`, the path grounded
  in section 3. Fittings JSON key names follow section 6.
- This mirrors `get_character_planets` (single-shot list),
  not the industry capped page walk. Rationale: a saved-
  fittings list is one small per-character list, and no
  inspected body shows paging for it. There is therefore no
  `truncated` flag anywhere in this slice. If implementation
  against the live service proves the list pages, work stops
  and this document is amended before any paging code is
  written; silently dropping later pages is forbidden
  (unresolved item U3).
- No per-fitting detail endpoint. No inspected body proves
  one exists: Flutter has no fittings `GET` at all, and the
  blueprint names only the list path. The list response is
  treated as carrying each fitting's full item list, because
  the one inspected ESI fitting payload (the Flutter write
  body, section 3) is a header plus a complete
  `{type_id, flag, quantity}` item list, and the read model
  in section 6 mirrors that shape. Selecting a fitting
  therefore never fetches (section 7.6). If the live list
  proves to omit items, that is unresolved item U1 and it
  blocks the endpoint commit until verified and this section
  is amended; inventing a detail path is forbidden.
- Scope failure (missing read scope) surfaces through the
  existing client error mapping and is detected only through
  `endpoints::needs_reauthorize`. The endpoint function
  itself adds no scope logic.
- Logging: one `tracing::debug!` line before the call in the
  planets style, `"[ESI] GET /characters/{}/fittings/"`,
  using the `[FITTING]` tag in place of `[ESI]` if, and only
  if, the built endpoint file's neighboring functions do so;
  the locked tag for this slice's fetch lines is `[ESI]`
  in `endpoints.rs` and `[FITTING]` everywhere else. Rows
  return in fetch order, unsorted and unfiltered; all
  ordering is the view's job (section 9.1).

## 5. Scope constant (Builder A, `src/config.rs`)

One additive constant, placed after `PLANETS_SCOPES`, in the
exact style of its neighbors:

```rust
/// Saved-fittings step-up scope: read the character's saved
/// fittings. Granted after first sign-in via step-up, never
/// at first auth. The write scope is never requested (no
/// fitting writes exist in the read-only slice).
pub const FITTINGS_SCOPES: &[&str] = &["esi-fittings.read_fittings.v1"];
```

The exact string `esi-fittings.read_fittings.v1` is grounded
in the blueprint advanced-scopes list (section 3). It is the
only scope in the set, and it is requested exclusively
through the existing generic `StepUpRequest` (section 7.5).
`FIRST_AUTH_SCOPES` is not widened, no other scope set
changes, and `esi-fittings.write_fittings.v1` appears
nowhere in Rust code or tests.

Guard test, mirroring `planets_scopes_is_the_single_stepup_scope`
exactly:

```rust
#[test]
fn fittings_scopes_is_the_single_stepup_scope() {
    assert_eq!(EveConfig::FITTINGS_SCOPES, ["esi-fittings.read_fittings.v1"]);
    for scope in EveConfig::FITTINGS_SCOPES {
        assert!(
            !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
            "step-up scope {scope} must be disjoint from first-auth"
        );
    }
}
```

## 6. Typed models (Builder A, `src/esi/models.rs`)

Two structs, appended after the planetary models and before
`EsiErrorBody`, in the file's uniform style:

```rust
/// One saved fitting from `GET /characters/{character_id}/fittings/`.
/// `fitting_id` is a per-instance identity: selection identity
/// and invisible sort tie-break only, never rendered and never
/// sent to universe name resolution. `ship_type_id` and every
/// item `type_id` resolve via the item-name path. `name` is
/// user text: it renders only after the single-line sanitize
/// in the view/export rules and is never trusted as a number.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterFitting {
    #[serde(default)]
    pub fitting_id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub ship_type_id: i64,
    #[serde(default)]
    pub items: Vec<FittingItem>,
}

/// One fitted or carried item inside a saved fitting. `flag`
/// is the ESI slot vocabulary word (for example `LoSlot0` or
/// `DroneBay`); it is grouped only through the view whitelist
/// and is never rendered verbatim. `quantity` is carried raw
/// and clamped at render/export, never at parse.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FittingItem {
    #[serde(default)]
    pub flag: String,
    #[serde(default)]
    pub quantity: i64,
    #[serde(default)]
    pub type_id: i64,
}
```

Locked model rules:

- Every field is `#[serde(default)]`; a missing field parses
  to its default and an unknown future field is ignored,
  exactly like every other model in the file.
- `description` is `Option<String>` and its nullability is
  preserved: `None` is never coerced to an empty string at
  parse. The view renders a present non-empty description
  only after sanitizing (section 9.1) and renders nothing
  for `None` or empty-after-trim.
- No field is renamed with a serde alias. If the live wire
  proves a different key name, that is unresolved item U1:
  record the proven key, amend this section, then code.
- Model tests mirror the planetary model tests: a full
  payload parses; a payload with an unknown future field
  parses; an empty object parses to defaults; `description:
  null` stays `None`; a negative quantity parses unchanged
  (clamping is a render/export rule, never a parse rule).

## 7. State and fetch placement

### 7.1 State shape (Builder B, `src/app/state.rs`)

The bundle is the simplest shape in the tree: one list
section, nothing else. Selection lives outside the bundle,
by `fitting_id`, so a refresh can keep or drop it honestly.

```rust
/// Saved-fittings bundle: the one list section for the active
/// character. Field set is a cross-builder contract (the
/// shell and demo seeding construct this literally); do not
/// add fields here.
#[derive(Debug, Clone)]
pub struct FittingsData {
    pub fittings: SectionResult<Vec<CharacterFitting>>,
}

impl FittingsData {
    /// True when the list section failed for scope reasons.
    pub fn needs_fittings_stepup(&self) -> bool {
        matches!(&self.fittings, Err(e) if e.needs_reauthorize)
    }
}
```

`AppState` gains exactly three fields, in the style of the
industry and planetary blocks:

- `pub fittings: LoadState<FittingsData>` beside the other
  per-view load states.
- `pub fittings_search: String` (view-local; survives
  character switches, like every other view's filter text).
- `pub fittings_selected_fitting_id: Option<i64>`
  (view-local selection identity, the numeric ID is state
  and is never rendered).

There is no fittings generation counter and no
`fittings_*_fetch_requested` flag. Section 7.2 explains why
neither is needed: there is no on-demand fittings fetch for
a generation to guard. Selection changes are pure state
writes in the view (section 9.2) and need no method on
`AppState`; unlike `set_planetary_selection`, selecting a
fitting queues no fetch, so there is nothing for a setter to
stamp. (If Builder B finds a setter reads better, it must do
exactly `self.fittings_selected_fitting_id = Some(id)` plus
one `[FITTING]` info line, and must queue nothing.)

Derived default state: `LoadState::Loading`, empty search,
`None` selection. `AppState::new` needs no explicit entry
(unlike the market region, every default here is already
the locked initial value).

### 7.2 Fetch placement: main-refresh tolerant sub-fetch (LOCKED)

The fittings list is fetched as one tolerant sub-fetch
inside the existing main refresh (`start_refresh` in
`src/app/shell.rs`), beside the colonies list. It is NOT an
on-demand fetch like Market's.

Rationale, locked:

- The data is per-character, not per-selection. Market is
  on-demand because its bundle is meaningless without a
  user-chosen item and region, and its public sections need
  no character at all. A saved-fittings list needs no user
  input to be well-defined: it is a property of the active
  character, exactly like industry jobs, blueprints, and the
  colonies list, all of which ride the main refresh.
- Selecting a fitting needs no network (section 4: the list
  carries full items), so there is no second fetch for an
  on-demand design to own. Planetary needs its on-demand
  spawn only because colony detail is a second endpoint.
- Riding the main refresh inherits its identity guard for
  free: a refresh that lands after a character switch has
  its per-view apply dropped by the existing
  active-character check in the `Refreshed` arm. An
  on-demand design would have to re-derive that guard with
  a new message variant, a generation counter, and a
  match-predicate, for zero user-visible gain.
- Cost is one more small GET per refresh of a character
  that already waits on many. That is the accepted price,
  the same one paid for the colonies list.

Integrator wiring (all in `src/app/shell.rs`):

1. `BackendMsg::Refreshed` gains one field,
   `fittings_list: SectionResult<Vec<CharacterFitting>>`,
   after `planetary_colonies`. No new `BackendMsg` variant.
2. In the `start_refresh` async block, after the colonies
   sub-fetch, one tolerant sub-fetch (never `?`):

   ```rust
   // Saved fittings are one tolerant sub-fetch (never `?`):
   // fixed wording on screen, full error detail in the
   // [FITTING] warn only.
   let fittings_list = endpoints::get_character_fittings(&esi, id)
       .await
       .map_err(|e| {
           let needs_reauthorize = endpoints::needs_reauthorize(&e);
           tracing::warn!("[FITTING] fittings section failed character_id={} section=fittings needs_reauthorize={} error={}", id, needs_reauthorize, e);
           SectionError {
               message: "fittings request failed".to_string(),
               needs_reauthorize,
           }
       });
   ```

   On `Ok`, one info line:
   `tracing::info!("[FITTING] fittings ready character_id={} fittings={} items={}", ...)`
   with the fittings count and the saturating sum of item
   rows. The tuple returned by the async block, the `Ok`
   destructure, and the `BackendMsg::Refreshed` construction
   each gain the one value. Nothing about fittings is
   persisted to the database in the persist block
   (in-memory only, section 2).
3. In the `Refreshed` apply arm, inside the
   active-character branch, the selection merge mirrors the
   planetary colonies merge and runs before assignment:
   - If `fittings_list` is `Ok(list)` and a selection exists
     and no fitting in `list` carries the selected
     `fitting_id`, the selection is proven gone: clear
     `fittings_selected_fitting_id` to `None` and log one
     `[FITTING]` debug line. A successful list is the only
     evidence that may clear a selection this way.
   - If `fittings_list` is `Err`, the selection survives
     untouched: a failed list proves nothing (the planetary
     rule, verbatim).
   - Then `self.state.fittings = LoadState::Ready(FittingsData { fittings: fittings_list });`
   - No detail is preserved and no follow-up fetch is
     queued: unlike planetary, there is no detail section
     to carry across the refresh.
   - The existing `schedule_name_resolution()` call at the
     end of the arm covers name scheduling (section 10 adds
     the ID block). No new call site.
4. In the `RefreshFailed` arm, one new block mirroring the
   industry and planetary blocks, with their comment's
   reasoning (the whole-view panel renders the string
   verbatim and raw refresh text can embed numeric IDs):

   ```rust
   if !self.state.fittings.is_ready() {
       self.state.fittings =
           LoadState::Error("character refresh request failed".to_string());
   }
   ```

   The raw refresh `message` is never installed into
   fittings state.

Character identity, stated once: every fittings value
reaches the view only through the `Refreshed` arm's
active-character guard, or through demo seeding for the
active demo character. There is no fittings result that can
arrive stamped for any other character, because there is no
fittings message of its own.

### 7.3 Step-up and already-granted behavior (LOCKED)

Because the list rides the main refresh, fittings needs no
per-view refetch flag on either step-up completion path.
Both paths already queue the main refresh, and that is
sufficient and complete:

- **Post-step-up path** (`StepUpLoggedIn` for the active
  character): the existing `request_refresh("post-stepup")`
  refills the list under the new grant. The integrator adds
  NOTHING to this arm for fittings. (Contrast, kept as
  rationale in code comments if touched: Market sets
  `market_fetch_requested` and Planets sets
  `planetary_detail_fetch_requested` there because the main
  refresh never touches their gated data. The main refresh
  does touch fittings, so queueing anything more would
  double-fetch.) The re-authorize panel clears only when a
  later refresh returns the list `Ok`; nothing is cleared
  at login-success time.
- **Already-granted shortcut** (`start_stepup_login`, when
  stored token metadata already claims the scope): the
  existing `request_refresh("stepup-already-granted")`
  refills the list. The integrator adds NO fittings flag
  there either, for the same reason. The pre-existing
  status behavior is inherited unchanged:
  `"That permission is already granted. Refreshing..."`,
  set after `request_refresh`.
- **Observed-reality guard:** the integrator adds exactly
  one overlap arm to the `observed_reauthorize` computation
  in `start_stepup_login`, in the established style:

  ```rust
  || (overlaps(EveConfig::FITTINGS_SCOPES)
      && matches!(&self.state.fittings, LoadState::Ready(d) if d.needs_fittings_stepup()))
  ```

  Without this arm, stale token metadata claiming the
  fittings grant would make the Fittings panel's own
  Re-authorize button loop forever through the shortcut
  without ever opening the browser — the exact failure the
  existing arms exist to prevent.

### 7.4 Fixed error wordings (complete list)

These are the only fittings error strings that may reach the
screen. Every other error detail goes to a `[FITTING]`
`tracing::warn!` line and nowhere else.

- Section failure (list sub-fetch): `"fittings request failed"`.
- Whole-view failure after a failed main refresh:
  `"character refresh request failed"` (section 7.2, item 4).
- Whole-view error panel: the shared
  `widgets::error_panel_with_retry`, whose retry sets the
  existing `retry_requested` flag (the shell maps retry to a
  main refresh, as for every other view).

No server response text, no `AppError` display string, and
no numeric ID is ever interpolated into a rendered fittings
string. Flutter's `'Failed to load saved fittings: $e'`
pattern is explicitly rejected.

### 7.5 Step-up panel policy (Builder B view, integrator guard)

The Fittings view's re-authorize panel mirrors the industry
and planets panels (section 9.2 gives placement):

- Shown when the loaded bundle's
  `needs_fittings_stepup()` is true.
- Heading: `"Fittings needs 1 more EVE permission."` — the
  count word comes from `EveConfig::FITTINGS_SCOPES.len()`
  rendered through the same helper wording the neighboring
  panels use; if the neighbors hardcode their counts, this
  panel hardcodes `1` the same way. It never renders a raw
  scope dump beyond `EveConfig::FITTINGS_SCOPES.join(" ")`,
  matching the neighbors.
- Names the active character by its row name (words, never
  the ID).
- The Re-authorize button is enabled only when
  `!state.demo && !state.auth.is_busy() && active.is_some()`,
  and on click sets exactly
  `state.stepup_requested = Some(StepUpRequest::new(active_id, EveConfig::FITTINGS_SCOPES))`
  plus the same in-flight status message the neighboring
  panels set. No fittings-specific auth state exists; the
  generic `StepUpRequest` and `start_stepup_login` handle
  the whole flow, including the wrong-character-consent
  rejection the step-up design already guarantees.
- The panel is the gating affordance for BOTH the refresh
  path and the already-granted path: section 7.3's overlap
  arm is what makes its button work when token metadata is
  stale. That pairing is the planetary lesson and is locked
  here deliberately, not left as a recommendation.

Section-error label: when the bundle is `Ready` and the list
section is `Err` without `needs_reauthorize`, the view shows
the section error line through the same
`section_error_label` pattern industry uses (fixed message
from 7.4). When `needs_reauthorize` is true, the panel
above replaces the plain label, so the user always has the
working button rather than dead-end text.

### 7.6 What does not fetch

- Selecting a fitting never fetches (list carries items).
- Searching never fetches (filtering is over the loaded
  list and resolved names already in memory).
- Copying as EFT never fetches (the pure function in
  section 9.3 consumes the loaded fitting and the resolver
  as they currently stand; unknown names are handled by the
  locked skip-and-disclose rule, never by a blocking lookup
  from the view).
- Opening the Fittings view never fetches. If the bundle is
  still `Loading`, the view shows the loading panel; the
  startup, switch, and retry refreshes fill it.

## 8. Character switch and removal resets (Builder B, state.rs)

Mirrors the industry reset plus the planetary selection
clear, because the loaded list belongs to the previous
character and tolerant sub-fetch errors must never present
one character's fittings under another.

- `set_active_character`, inside the existing
  `previous_id != character_id` branch, after the planetary
  block:

  ```rust
  tracing::debug!(
      "[FITTING] clearing fittings on character switch from={} to={}",
      previous_id,
      character_id
  );
  self.fittings = LoadState::Loading;
  self.fittings_selected_fitting_id = None;
  ```

  Search text survives the switch (view-local, like every
  other view's filter). Same-character reselect touches
  nothing: rows and selection survive.
- `remove_character`, inside the removed-was-active block,
  after the planetary block:

  ```rust
  tracing::debug!("[FITTING] clearing fittings of removed active character");
  self.fittings = LoadState::Loading;
  self.fittings_selected_fitting_id = None;
  ```

  And in the empty-roster branch:
  `self.fittings = LoadState::Empty;` plus
  `self.fittings_selected_fitting_id = None;`, mirroring the
  planetary lines there. Removing a non-active character
  leaves the bundle and selection ready and untouched. The
  existing pending-step-up clear for the removed character
  already covers a queued fittings step-up; nothing
  fittings-specific is added for it.
- Tests mirror `switching_character_clears_stale_character_details`
  and the planetary removal tests: switch clears to
  `Loading` and drops selection; same-character reselect
  keeps both and keeps `needs_fittings_stepup`; removing the
  active character clears; removing a non-active character
  keeps; removing the last character gives `Empty`.

## 9. Pure helpers, the Fittings view, and EFT export (Builder B)

All of section 9 lives in one new file, `src/ui/fittings.rs`,
plus the state fields in section 7.1. The view is pure: it
never fetches and sets request flags only (`retry_requested`,
`stepup_requested`), exactly like Industry and Planets.

### 9.1 Helpers (`src/ui/fittings.rs`)

File header doc in the industry style:

```rust
//! Fittings: the active character's saved fittings, read-only,
//! with EFT clipboard export of the selected fitting. The view
//! sets request flags only (`retry_requested`,
//! `stepup_requested`); it never fetches. Every rendered
//! string is a resolved EVE name, sanitized user text, a
//! section word, or a row count — never a raw numeric ID,
//! and never a raw ESI flag string.
```

Sanitize (one private helper, shared by rows and export):

```rust
fn sanitize_single_line(raw: &str) -> String
```

Replace every control character (including CR and LF) with a
space, collapse runs of whitespace to one space, and trim.
Fitting names and descriptions are user text from the wire;
they must never inject a line break into a row, a status
message, or the EFT header. Brackets and commas inside a
name are handled by the header rule in 9.3, not here.

Display-name rule: `fitting_display_name(raw_name) ->
String` returns the sanitized name, or `"Unnamed fitting"`
when sanitizing leaves nothing. The raw name is never
rendered unsanitized, and a name that is itself all digits
still renders only through this word path or the fallback;
in particular a digit-only name renders as
`"Unnamed fitting"`, because showing it would put a bare
number where a name belongs and the resolver already rejects
all-digit names for the same reason (section 3).

Flag grouping (the display rule for ESI flag vocabulary):

```rust
pub enum FittingSection { Low, Medium, High, Rig, Subsystem, Drones, Fighters, Cargo }
pub fn section_for_flag(flag: &str) -> FittingSection
pub fn section_label(section: FittingSection) -> &'static str
```

Locked mapping. `section_for_flag` matches by prefix, and
the slot index is never parsed for display:

- Prefix `LoSlot` → Low, label `"Low slots"`.
- Prefix `MedSlot` → Medium, label `"Medium slots"`.
- Prefix `HiSlot` → High, label `"High slots"`.
- Prefix `RigSlot` → Rig, label `"Rigs"`.
- Prefix `SubSystemSlot` → Subsystem, label `"Subsystems"`.
- Exact word `DroneBay` → Drones, label `"Drones"`.
- Exact word `FighterBay` → Fighters, label `"Fighters"`.
- Everything else, including the exact word `Cargo` and any
  flag this slice does not know → Cargo, label
  `"Cargo and other items"`.

The first five prefixes and `FighterBay` are grounded in
the Flutter ESI exporter (section 3). `DroneBay` and `Cargo`
are the expected ESI bay words; they are matched as exact
words so that a surprise spelling lands in the catch-all
section instead of silently vanishing (unresolved item
U1 covers confirming them against the live payload).

Display rule, stated once: the raw flag string is NEVER
rendered. Flags such as `LoSlot0` end in a slot-index digit,
and rendering the vocabulary word verbatim would put an
unexplained number on screen and teach the user nothing the
section heading does not already say. The section label is
the only flag-derived string on screen. Ordering within a
section uses the raw flag string only as an invisible sort
key (lexicographic, which orders same-prefix slot indices
correctly for the grounded ranges) and then `type_id` as the
final invisible tie-break, matching the tree's
invisible-tie-break convention. Unknown flags are never
dropped from the detail view: they appear under
`"Cargo and other items"`.

Rows:

```rust
pub struct FittingRow {
    pub fitting_id: i64,      // identity + tie-break only, never rendered
    pub ship_type_id: i64,    // identity only, never rendered
    pub display_name: String, // sanitized, or the fallback word
    pub ship_name: String,    // resolver.name(ship_type_id)
    pub item_count: usize,    // saturating row count
}
pub fn fitting_rows(fittings: &[CharacterFitting], resolver: &NameResolver) -> Vec<FittingRow>

pub struct FittingItemRow {
    pub type_id: i64,         // tie-break only, never rendered
    pub type_name: String,    // resolver.name(type_id)
    pub section: FittingSection,
    pub quantity: i64,        // wire value clamped with .max(0)
}
pub fn fitting_item_rows(fitting: &CharacterFitting, resolver: &NameResolver) -> Vec<FittingItemRow>
```

Rules (mirroring `industry_job_rows`, `colony_rows`, and
`pin_type_counts`):

- `fitting_rows` sorts by lowercased display name, then
  display name, then lowercased ship name, then ship name,
  then `fitting_id`. `item_count` is `items.len()` (counts
  are `usize` additions via `saturating_add` where
  accumulated).
- `fitting_item_rows` skips items with `type_id <= 0`
  entirely (counted into one `[FITTING]` debug line as
  `skipped`, the `pin_type_counts` rule: a non-positive ID
  cannot resolve and must not render as anything). It keeps
  every other item, including unknown-flag items (Cargo
  section) and rows whose quantity clamps to zero, which
  stay visible in the detail view under the 9.2 rule.
  Quantities are `quantity.max(0)`; nothing sums
  quantities here except the export stacking in 9.3, which
  uses `saturating_add`.
- Sort: by section in the locked section order (Low,
  Medium, High, Rig, Subsystem, Drones, Fighters, Cargo),
  then by raw flag (invisible), then lowercased type name,
  then type name, then `type_id`.
- Unresolved types render `resolver.name()`'s
  `"Unknown Item"` in the interface. That word is correct
  on screen and forbidden in export (9.3). Keeping the two
  rules in one file, side by side, is deliberate.
- Render cap: `pub const FITTINGS_RENDER_MAX: usize = 100;`
  for the fittings list and the same cap per section for
  item rows, mirroring `BLUEPRINT_RENDER_MAX`. Overflow
  shows a count word line in the neighboring style
  (`Showing first 100 ...` wording copied from the built
  Industry view, with counts as the only numbers).
- One `[FITTING]` debug line per row-builder call with row
  and skipped counts, in the neighbors' style.

Search: `fn fitting_matches_search(row: &FittingRow, needle:
&str) -> bool` = `widgets::matches_search` over the display
name OR the ship name (case-insensitive substring, the
shared helper). Search covers fitting names and ship names
only; item names are not searched in this slice.

### 9.2 View (`pub fn show(ui, state, resolver)`)

Structure mirrors Industry/Planets exactly: heading
`"Fittings"`, `widgets::mode_notice`, the
`no_character_panel` guard, snapshot clone of the bundle,
then the `LoadState` match (loading panel, empty panel,
`error_panel_with_retry` → `retry_requested`, Ready →
sections). Locked content for each state:

- Ready + list `Err` + `needs_reauthorize`: the step-up
  panel of section 7.5, and nothing else below it (there
  are no rows to show).
- Ready + list `Err` otherwise: the section-error label
  with the fixed `"fittings request failed"` wording.
- Ready + list `Ok(empty)`: one fixed empty line:
  `"No saved fittings for this character yet. Fittings you
  save in EVE will appear here after a refresh."` This
  replaces the Flutter empty text, which pointed at a save
  button and a paste-import box this slice does not have.
- Ready + list `Ok(non-empty)`:
  - `widgets::search_box` over `state.fittings_search`
    with hint `"Search fittings and ships"` and the standard
    focus dance (`state.text_input_focused |= focus; if
    focus { state.focus_search = false; }`).
  - The filtered list, one selectable row per fitting:
    display name, then `"{ship_name} • {item_count} items"`
    in secondary text (the Flutter dialog's subtitle shape,
    with `items` in place of `modules` because cargo and
    drones are items here, not modules). Clicking sets
    `state.fittings_selected_fitting_id` (9.1 setter rule)
    and one `[FITTING]` info line naming the display name,
    never the ID.
  - No search matches: one fixed line,
    `"No fittings match that search."`
- Selected fitting detail (below the list, shown when the
  selection resolves to a fitting in the currently loaded,
  currently filtered-or-not list — resolution is against
  the full loaded list, so filtering the list does not hide
  an already-selected fitting's detail):
  - Heading: display name; sub-line: ship name; description
    line only when present and non-empty after sanitizing.
  - One `CollapsingHeader`-free flat block per non-empty
    section, in locked section order, headed by the section
    label: one line per item row, `type_name` for slot
    sections, and `"{type_name} x{quantity}"` for Drones,
    Fighters, and Cargo. A slot-section row whose clamped
    quantity is not 1 renders `"{type_name} x{quantity}"`
    too, so no wire quantity is ever silently hidden;
    quantity 0 renders in that same `x0` form rather than
    dropping the row (the detail view is where odd wire
    data stays visible; export in 9.3 is stricter).
  - A fitting with zero renderable items shows one fixed
    line: `"This fitting has no items to show."`
  - The export button, `"Copy as EFT"`, enabled whenever a
    fitting is selected (demo included: copying demo data
    to the clipboard is harmless and useful). Section 9.3
    locks its behavior and confirmations.
- Selection present but not in the loaded list (reachable
  only transiently before the 7.2 merge, or in tests): the
  detail block renders nothing. The view never fabricates
  a fitting from an ID.

### 9.3 EFT export: pure function plus egui clipboard (LOCKED)

The exporter is a pure function in `src/ui/fittings.rs`.
It performs no I/O, no fetching, and no clipboard access;
the view's button handler is the only place that touches
egui output.

```rust
pub struct EftExport {
    pub text: String,
    pub skipped_unknown: usize, // item rows dropped: unresolved name
    pub skipped_empty: usize,   // item rows dropped: non-positive id or clamped-zero stacked quantity
}
pub fn fitting_to_eft(fitting: &CharacterFitting, resolver: &NameResolver) -> Option<EftExport>
```

Contract:

1. **Ship gate.** EFT needs a real ship name in the header.
   Resolve the ship with `resolver.cached(ship_type_id)`
   (not `name()`): `None`, an empty-after-trim name, or a
   `ship_type_id <= 0` returns `None` — no export at all.
   Emitting `[Unknown Item, ...]` would produce a block no
   tool can import while looking like success.
2. **Header.** Exactly `"[{ship}, {name}]"` where `ship` is
   the resolved ship name trimmed, and `name` is the
   fitting display name after `sanitize_single_line` with
   additionally `[`, `]`, and `,` replaced by spaces before
   collapsing (a comma or bracket would corrupt the header
   grammar; the Flutter exporter interpolated both raw and
   that truncation defect is not copied), falling back to
   `"Unnamed fitting"` when empty — including the
   digit-only-name case, since 9.1's display name already
   applied that fallback. No blank line follows the header:
   the executed Flutter `generateEft` body is followed here
   over the context-library spec, which writes one. The
   executed code is the behavior users' pasted blocks
   already came from.
3. **Section order and blank lines.** Sections in this
   order: Low, Medium, High, Rig, Subsystem, Drones,
   Fighters, Cargo. Non-empty sections are separated by
   exactly one blank line; empty sections are omitted
   entirely (no consecutive blank lines, no `[Empty ...]`
   placeholders — the Flutter exporter emits none and
   neither does this one). The result has no trailing
   newline (the Flutter `.trim()` behavior). Two deliberate
   deviations from the Flutter exporter, both because
   copying it would silently lose saved items, which
   section 2's no-silent-drops stance forbids: subsystems
   get their own section (Flutter dropped them from EFT),
   placed after rigs where fitting tools read them; and
   Cargo (including every unknown-flag item) is exported
   last in stacked form (Flutter had no cargo in EFT; the
   context-library spec's `toEft` does, and this slice
   follows the spec on this one point for the same
   no-silent-loss reason).
4. **Module lines.** In Low/Medium/High/Rig/Subsystem, one
   line per fitted unit: the resolved type name, repeated
   `quantity.max(0)` times for that wire row (slot rows
   normally carry quantity 1; repeating is the only honest
   reading of a larger quantity, since EFT has no stacked
   module syntax). Item order inside a section is the
   9.1 row order.
5. **Charges and ammunition.** There are NO `Module, Charge`
   comma lines in this slice. The ESI item shape
   (`flag`, `quantity`, `type_id`) carries no linkage saying
   which charge sits inside which module, and the executed
   Flutter exporter never emitted charge suffixes either
   (its parser never set a charge). Charges saved in the
   fitting arrive under their own flags and are exported
   where their flags put them (normally the Cargo section,
   stacked). Inventing a module-to-charge pairing would
   fabricate data. If a future slice proves a linkage, it
   amends this rule then.
6. **Stacked lines.** Drones, Fighters, and Cargo lines are
   `"{name} x{quantity}"`, aggregated by `type_id` within
   the section with `saturating_add` over
   `quantity.max(0)` values (the Flutter `Name xN` shape).
   A stacked type whose clamped total is zero is dropped
   and counted in `skipped_empty`.
7. **Unknown types.** An item whose `type_id` does not
   resolve through `resolver.cached()` to a non-empty name
   is SKIPPED — never emitted as a number, never emitted
   as `"Unknown Item"` (a literal line reading
   `Unknown Item` is a corrupt import in every downstream
   tool) — and counted in `skipped_unknown`. Items with
   `type_id <= 0` are skipped and counted in
   `skipped_empty`. Skipping is safe here precisely
   because it is disclosed (rule 9); the interface detail
   view still shows those rows as `"Unknown Item"`.
8. **Name hygiene.** Resolved names pass through
   `sanitize_single_line` before interpolation, and a name
   that sanitizes to empty is treated as unknown (rule 7).
   The resolver already guarantees no cached name is
   all-digit; the export additionally never formats any
   `type_id`, `ship_type_id`, or `fitting_id` into the
   text. Tests in section 12 grep the output for the
   fixture IDs to prove it.
9. **Clipboard and confirmation (view handler, the only
   side effect).** On `"Copy as EFT"` click, the handler
   calls `fitting_to_eft`:
   - `None` (ship unresolved): no clipboard write; status
     message set to the fixed line `"That fitting cannot be
     copied yet: its ship name has not loaded. Refresh and
     try again."`; one `[FITTING]` warn line. The button
     stays enabled: resolution can land at any refresh, and
     a disabled button would hide why.
   - `Some(export)`: write with the egui copy API only,
     `ui.ctx().copy_text(export.text)` (egui 0.29; if the
     built egui version names this differently, Builder B
     uses that version's documented copy call and nothing
     else — no clipboard crate is added, no OS command is
     spawned). Then set the status message, using the
     Flutter confirmation's shape with disclosure added:
     - no skips: `"Copied \"{display_name}\" as EFT"`;
     - skips present: `"Copied \"{display_name}\" as EFT ({skipped} items left out: names not loaded yet)"`
       where `{skipped}` is the saturating sum of both skip
       counts (a row count, not an ID) and `{display_name}`
       is the sanitized display name. One `[FITTING]` info
       line records the fitting display name, exported line
       count, and both skip counts. The EFT text itself is
       never logged (it is user data and would flood the log
       view).

Exporter unit tests are enumerated in section 12.2; they
run against a hand-seeded `NameResolver`, no network.

### 9.4 View placement and key numbering (Builder B + integrator)

Fittings is view 9 of 10, immediately before Settings:

- `src/app/state.rs`: insert `Fittings` in `View` between
  `Planets` and `Settings`, in `View::ALL` at the same
  position (`[View; 10]`), and `label()` → `"Fittings"`.
  The enum doc comment changes from "The nine views (keys
  1-9 in the shell)" to "The ten views (keys 1-9 and 0 in
  the shell)". `from_index(8)` becomes Fittings,
  `from_index(9)` becomes Settings, `from_index(10)` is
  `None`; `Planets.next()` becomes Fittings and
  `Settings.previous()` becomes Fittings. The
  `view_navigation_wraps_and_indexes` test is updated to
  assert the new chain in full (index, next, previous for
  Fittings and the moved Settings).
- `src/ui/mod.rs`: add `pub mod fittings;` (alphabetical,
  after `dashboard`).
- Shell dispatch exception, pre-authorized for Builder B:
  exactly ONE added line in the `update` view match —
  `View::Fittings => ui::fittings::show(ui, &mut self.state,
  &self.resolver),` between the Planets and Settings arms.
  No other Builder B edit in `shell.rs`; everything else
  there is the integrator's (section 12.1).
- Key numbering (integrator, `collect_keys`): the digit
  keys are `Num1` through `Num9` for indices 0-8
  (unchanged: Planets stays 8, Fittings takes 9) and
  `egui::Key::Num0` for index 9 (Settings). Implementation:
  keep the existing enumerated list for `Num1..Num9`, then
  add one explicit arm, `if i.key_pressed(egui::Key::Num0)
  && !i.modifiers.command && !i.modifiers.ctrl {
  actions.switch_view = View::from_index(9); }`, so the
  tenth view is reachable without renumbering anyone's
  muscle memory for keys 1-9. The side rail renders
  `idx + 1` from `View::ALL`, which would label Settings
  "10" while its key is 0: the integrator changes the rail
  label digit to `(idx + 1) % 10`, so Fittings reads
  `9 Fittings` and Settings reads `0 Settings`, each
  matching the key that selects it.
- Every hardcoded hint string updates in the same commit as
  the key change (verified list from section 3; a
  `grep -rn "1-9" src/ README.md` must return only updated
  lines):
  - `src/app/state.rs` line 15 doc comment (Builder B,
    above).
  - `src/app/shell.rs` rail heading `"Views (keys 1-9)"` →
    `"Views (keys 1-9, 0)"` (integrator).
  - `src/app/shell.rs` status bar `"Keys: 1-9 views, ..."`
    → `"Keys: 1-9, 0 views, ..."` (integrator).
  - `src/ui/widgets.rs` `no_character_panel` line →
    `"Keys: 1-9, 0 switch views, PageUp/PageDown switch
    character."` (Builder B; the one widgets edit in this
    slice).
  - `src/ui/settings.rs` keyboard line → starts
    `"1-9, 0 views | ..."` (Builder B; the one settings
    edit in this slice).
  - `README.md` Settings bullet keyboard text (integrator,
    with the Fittings bullet in section 12.1).
- Label persistence needs no migration: the startup view is
  persisted and matched by `label()` string. A saved
  `"Settings"` still restores Settings after its key moves
  from 9 to 0; `"Fittings"` becomes a valid saved value the
  first time a user picks it. No index is ever persisted.

## 10. Name scheduling (integrator, `schedule_name_resolution`)

One new block after the Planetary block, under a
`// Fittings IDs (design section 10): ...` comment in that
block's style. From a Ready fittings bundle with an `Ok`
list:

- Each fitting's `ship_type_id` (item-name path:
  `ids.push(...)`, no structure guard; ship types are not
  locations).
- Each item's `type_id` (item-name path, same).

NEVER scheduled: `fitting_id` (instance identity, exactly
like `planet_id` and `pin_id`), flag strings (vocabulary
words, not IDs), and quantities. The existing
`missing()` call deduplicates and drops non-positive IDs,
so no per-ID filtering is added here beyond what every
neighboring block does. The demo early-return already
covers demo mode. The only trigger is the existing
`schedule_name_resolution()` call at the end of the
`Refreshed` arm; names that land afterwards upgrade rows
and the export on the next frame, because both read the
resolver at render/click time. There is no summary string
frozen at refresh time for fittings, so no `NamesResolved`
recompute (of the character-detail summary kind) is needed
or added.

## 11. Demo fixture extension (Builder B, `src/demo/data.rs`)

Demo data is invented fixtures behind the same model types
as the live path (the `src/demo/data.rs` module contract).
Every name and ID in the new fixture is fictional-but-shaped
data using the existing demo characters and the existing
`assets/demo/names.json` vocabulary where possible, extended
only as below.

- New file `assets/demo/fittings.json`, keyed by character
  ID string like `planets.json`, one entry per demo
  character that has fittings:

  ```json
  {
    "<character_id>": {
      "fittings": [
        {
          "fitting_id": 1,
          "name": "Demo Brawler",
          "description": "Sample close-range fit",
          "ship_type_id": 587,
          "items": [
            { "flag": "LoSlot0", "quantity": 1, "type_id": 2048 },
            { "flag": "DroneBay", "quantity": 5, "type_id": 2456 }
          ]
        }
      ],
      "selected_fitting_id": 1
    }
  }
  ```

  (The type IDs above are illustrative of the shape;
  Builder B picks IDs that `names.json` resolves, adding
  entries to `names.json` in its existing format when a
  wanted ship or module name is missing, so the demo view
  and its EFT export resolve offline.) At least one demo
  character carries fittings with one pre-selected fitting;
  at least one fitting exercises every section of 9.1
  across the fixture set, including one Cargo stack and one
  unknown-flag item landing in `"Cargo and other items"`,
  so demo mode shows the whole view honestly. Item and
  fitting IDs are unique per character.
- `pub const DEMO_FITTINGS_JSON` `include_str!` beside the
  other nine, and a file-entry struct
  (`FittingsFileEntry { fittings, selected_fitting_id }`)
  with `#[serde(default)]` throughout, deserializing the
  model types of section 6 directly.
- One demo-side struct, deliberately not the view bundle
  (the `DemoPlanetaryData` rule):

  ```rust
  #[derive(Debug, Clone, Default)]
  pub struct DemoFittingsData {
      pub fittings: Vec<CharacterFitting>,
      pub selected_fitting_id: Option<i64>,
  }
  ```

  and `pub fittings: Option<DemoFittingsData>` on
  `DemoCharacterData` after `planets`.
- Loader chain, serde backward compatibility (the locked
  meaning: every existing caller keeps working unchanged,
  and every existing fixture file keeps parsing unchanged):
  new `load_demo_bundle_with_fittings(..., planets_json,
  fittings_json)` doing the full work;
  `load_demo_bundle_with_planets` keeps its exact signature
  and meaning by forwarding with `fittings_json = "{}"`,
  yielding `fittings: None` everywhere; all earlier
  `load_demo_bundle_with_*` forwarders are untouched.
  `load_demo_bundle()` calls the new function with
  `DEMO_FITTINGS_JSON`. A `"{}"` fittings text is valid and
  means absent, never an error. No existing JSON file's
  schema changes except additive `names.json` entries.
- Validation, mirroring the planets validation block:
  unique `fitting_id` per character; `ship_type_id` present
  in the demo name set; every item `type_id` present in the
  demo name set (demo is held to a stricter bar than live:
  sample data must resolve); `selected_fitting_id`, when
  the fittings list is non-empty, names one of them.
  Failures are `AppError` in the neighbors' wording style.
- `apply_character`: one new empty-if-absent block after
  the planets block, mirroring its comment and its
  `[DEMO]` debug line:
  - `Some(fixture)` → `LoadState::Ready(FittingsData {
    fittings: Ok(fixture.fittings.clone()) })` and
    `fittings_selected_fitting_id` set from the fixture,
    but only when it names a fitting in the list (else
    `None` — validation already guarantees this for bundled
    data; the guard keeps hand-built test bundles honest).
  - `None` → `LoadState::Empty` and selection `None`, so a
    demo character switch can never leak the previous
    demo character's fittings or selection.
  - Some-with-empty vs None: `Some` with an empty fittings
    list is `Ready` with `Ok(vec![])` (the view's fixed
    empty line), while `None` is whole-view `Empty` — the
    planets empty-vs-absent distinction, kept.
  - Search text is view-local and untouched.
- No demo fetch fallback is needed: with no on-demand
  fittings fetch, `start_refresh`'s existing demo branch
  (re-apply fixture character) covers demo end to end.
  Contrast Market and Planetary, which needed
  fetch-reapplies-fixture branches; the integrator adds
  neither here.

## 12. Ownership, sequence, and test plan

### 12.1 Ownership

Three disjoint file sets. Cross-set contracts are the exact
type and field names in sections 4-7; nobody renames them
without amending this document first.

**Builder A — endpoints, models, config, fixtures**
(`src/esi/endpoints.rs`, `src/esi/models.rs`,
`src/config.rs`, plus their in-file tests):

- `CharacterFitting` / `FittingItem` (section 6) with model
  tests.
- `get_character_fittings` (section 4) with endpoint tests
  (12.2). Before writing them, Builder A discharges
  unresolved item U1 (live wire confirmation) and records
  the outcome in the endpoint commit body; if the wire
  disagrees with section 6, Builder A stops and the
  integrator amends this document first.
- `FITTINGS_SCOPES` plus its guard test (section 5).
- No other file. In particular Builder A touches nothing in
  `src/app/`, `src/ui/`, or `src/demo/`, and authors the
  model-level fixture JSON snippets used by its own tests
  inline (the `assets/demo/fittings.json` file itself is
  Builder B's, because it must agree with demo seeding).

**Builder B — state, demo, view, EFT pure function**
(`src/app/state.rs`, `src/demo/data.rs`,
`src/ui/fittings.rs` new, `src/ui/mod.rs`,
`assets/demo/fittings.json` new, `assets/demo/names.json`
additive entries, the two hint strings in
`src/ui/widgets.rs` and `src/ui/settings.rs`, and the ONE
pre-authorized dispatch line in `src/app/shell.rs`):

- `FittingsData`, the three `AppState` fields, switch and
  removal resets, view placement and navigation test
  (sections 7.1, 8, 9.4 state parts).
- Demo struct, loader chain, validation, `apply_character`
  block (section 11).
- Helpers, view, EFT pure function, and the egui clipboard
  handler (sections 9.1-9.3), all with tests (12.2).

**Integrator — shell fetch wiring, keys, README**
(`src/app/shell.rs` except Builder B's one dispatch line,
`README.md`):

- `BackendMsg::Refreshed` field, the tolerant sub-fetch,
  the apply merge, the `RefreshFailed` block (section 7.2);
  the `observed_reauthorize` arm and the explicit no-op
  guarantee on both step-up completion paths (section 7.3);
  the name-scheduling block (section 10); `Num0` key
  wiring, the rail digit fix, and the two shell hint
  strings (section 9.4).
- README: one `**Fittings**` bullet in the Planets
  bullet's style (read-only list, EFT copy, the one scope
  named `esi-fittings.read_fittings.v1` as step-up never
  first sign-in, in-memory only, no import/edit/delete, no
  fitting statistics, "not live-verified yet" honesty, demo
  shows it), the Settings bullet's keyboard text updated
  to the ten-view wording, and fittings removed from any
  "not implemented" list that names it.
- Whole-tree gates (12.2) and the branch push decision,
  which stays with the human per the standing no-push,
  no-merge instruction for this slice.

Sequence: design commit (this document) → Builder A →
Builder B → integrator. Builder B compiles against Builder
A's model and endpoint names; the integrator compiles
against both. Each step is its own commit(s) in
`type(scope): description` style, no attribution lines.

### 12.2 Test plan

Run with `cargo test` (and the repo's `flutter analyze`
equivalent for Rust, `cargo clippy` if configured) at each
step; the integrator runs the full suite last.

Builder A:

- Model tests (section 6 list).
- Endpoint tests against the in-file mock-server harness,
  mirroring the planets/industry tests: a two-fitting
  payload returns rows in fetch order with items intact;
  HTTP 403 → `needs_reauthorize` true; HTTP 500 →
  `needs_reauthorize` false; malformed JSON → `Err`, never
  panic; empty array → `Ok(vec![])`.
- `fittings_scopes_is_the_single_stepup_scope`.

Builder B:

- State tests (section 8 list) plus
  `needs_fittings_stepup` truth table (Ok → false;
  plain `Err` → false; reauthorize `Err` → true) and the
  updated navigation test (9.4).
- Demo tests: bundled `fittings.json` loads and validates;
  `"{}"` yields `None` everywhere through the old
  `load_demo_bundle_with_planets` signature (back-compat
  proof); apply installs Ready + selection for the seeded
  character and Empty + no selection for a character
  without fittings; switching demo characters never leaks
  fittings.
- Helper tests: sanitize collapses CRLF and controls;
  digit-only and empty names fall back; `section_for_flag`
  covers every prefix, both bay words, `Cargo`, and an
  unknown flag; row sorts are stable under the invisible
  tie-breaks; non-positive `type_id` items are skipped;
  negative quantities clamp to 0; search matches name and
  ship name case-insensitively and misses item names.
- EFT tests (the important ones; each asserts full-string
  equality or `None`, never a substring-only check):
  header from resolved ship plus sanitized name; comma and
  brackets in the name cannot corrupt the header; no blank
  line after the header; exactly one blank line between
  non-empty sections and none for empty ones; section
  order Low→Cargo with subsystems after rigs; module line
  repetition for quantity 2; stacked aggregation with
  saturation; clamped-zero stack dropped and counted;
  unknown item skipped, counted, and the output contains
  neither its numeric `type_id` nor the words
  `"Unknown Item"`; unresolved ship → `None`; the output
  never contains the fixture `fitting_id` or
  `ship_type_id` digit strings; a CRLF-bearing fitting
  name yields a single-line header.
- View-shape tests only where the neighbors have them
  (row builders are the tested surface; egui rendering is
  not unit-tested in this tree and this slice does not
  start).

Integrator:

- Shell tests mirroring the planetary merge tests:
  refresh keeps a surviving selection; a successful list
  without the selection clears it; a failed list keeps it;
  a refresh for a non-active character installs nothing;
  `RefreshFailed` installs the fixed whole-view wording
  and never the raw message (assert a marker substring
  from the raw message is absent from state);
  `observed_reauthorize` blocks the already-granted
  shortcut when the fittings section is in reauthorize
  error and allows it otherwise.
- Full `cargo test` green; a grep sweep proving the slice
  kept its scope: no `write_fittings` in `src/`, no fitting
  `POST`/`DELETE` path, no new persistence of fittings
  (no fitting type mentioned under `src/storage/`), no
  `1-9` hint left stale, and no `fitting_id` formatted
  into any `ui` string.

## 13. Unresolved items (recorded, with their locked defaults)

These are evidence gaps found during design, recorded so
nobody silently guesses over them. Each names its locked
default, which is what gets built until the gap is
discharged by the named owner and this document amended.

- **U1 — Live ESI fittings wire shape.** No inspected body
  shows the `GET` response: field key names
  (`fitting_id`, `name`, `description`, `ship_type_id`,
  `items{flag, quantity, type_id}`), whether the list
  carries full items, and the exact bay flag words
  (`DroneBay`, `Cargo`) are modeled from the inspected
  write-body mirror and the blueprint path, not from a read
  payload. Locked default: section 6 as written; sections
  9.1's catch-all makes an unrecognized flag word visible
  (Cargo section) rather than lost, and serde defaults make
  a missing key parse-safe rather than a crash. Owner:
  Builder A confirms against the live service (or its
  published schema) before the endpoint commit and records
  the result; a disagreement amends sections 4 and 6
  first. The section's honest-error path (fixed wordings,
  7.4) already covers the case where the live payload
  cannot be parsed into the locked model.
- **U2 — Scope string has one grounding source.** The exact
  read scope is grounded only in the blueprint's
  advanced-scopes list (section 3); the fitting spec names
  no scope and Flutter requests only the write scope.
  Locked default: `esi-fittings.read_fittings.v1` as the
  single `FITTINGS_SCOPES` entry (section 5). This is
  grounded, not guessed, so the step-up ships enabled; but
  if Builder A's U1 confirmation shows a different read
  scope on the wire, section 5 is amended with the proven
  string before the config commit — never patched silently
  in code.
- **U3 — Pagination and cache behavior.** No inspected body
  states whether the list pages or what cache lifetime the
  service gives it. Locked default: single-shot fetch on
  every main refresh (sections 4, 7.2), no client-side
  caching beyond the in-memory bundle. Proving paging
  exists stops the endpoint work for a design amendment
  (section 4); it is never absorbed by silently showing
  page one.
- **U4 — No SDE slot truth.** EFT section assignment here
  comes from the wire flag word, because that is what ESI
  saved. Nothing in this slice knows whether an item
  "belongs" in the slot its flag names, and nothing
  reassigns items between sections (Flutter's importer did
  reassign via dogma effects; there is no loaded dogma in
  Rust, section 2). Locked default: the flag is authoritative,
  unknown flags go to Cargo. A fitting saved by EVE is shown
  and exported as EVE saved it.

## 14. End-to-end flow (one paragraph)

On sign-in, character switch, retry, or manual refresh, the
main refresh fetches the active character's saved fittings
as one tolerant sub-fetch beside the colonies list; a
missing-scope refusal degrades only the Fittings view to
its re-authorize panel (whose button runs the generic
step-up for `FITTINGS_SCOPES`, guarded against stale token
metadata by the new observed-reality arm, and refilled by
the ordinary post-step-up or already-granted refresh with
no fittings-specific flag), while a successful refresh
keeps the user's selection only if the fresh list still
contains that `fitting_id`, schedules universe-name
resolution for ship and item type IDs (never the fitting
ID), and lets the pure Fittings view render searchable
rows and a sectioned detail from resolved names; "Copy as
EFT" then runs the pure exporter — resolved ship in the
header or no export at all, slot sections in Flutter's
order plus subsystems and cargo so nothing saved is
silently dropped, unknown items skipped with a disclosed
count and never a number — and writes the result through
the egui copy API with an honest confirmation, all without
a single fitting write, import box, statistic, or row
ever touching the database.



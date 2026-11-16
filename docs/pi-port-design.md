# Planetary Industry (Planets) read-only slice — locked design

Status: LOCKED for implementation. This document locks ONE design.
Builders do not re-open the choices below; a choice that proves
impossible against the code is brought back as a design amendment,
not improvised in a builder commit.

Base: `develop` at `981c4a8` (conversion, Assets, step-up, JWT,
character detail, Market, and Industry slices all merged). The
retired Flutter Planetary Industry (PI) code lives only in git
history at `ed698d3` and is read with `git show ed698d3:<path>`;
no Dart file is ever restored.

## 1. What this slice is

A new read-only **Planets** view for the active character showing:

1. the character's colonies list (one row per colony: resolved
   solar-system name, planet-type word, upgrade level, pin count,
   last-update date), and
2. ONE selected colony's summary, derived client-side from that
   colony's detail payload: pin counts grouped by resolved pin
   type, extractor product rows, and stored-item rows aggregated
   from pin contents.

That is the whole slice. Everything in section 2 is out.

## 2. Hard scope and explicit non-goals

- Read-only only. NO colony edits, NO extractor restarts, NO
  colony create/delete, NO ESI writes of any kind (no POST, PUT,
  or DELETE added anywhere; the only POST in the touched code
  remains the pre-existing public `/universe/names/` resolution).
- NO schematics endpoint and NO production, profit, setup, or
  chain calculator. `schematic_id` is parsed, carried, and never
  rendered, never resolved, and never computed with.
- NO database schema migration and NO persistence of planetary
  data. Planetary state is in-memory only, exactly like Market
  and Industry. `src/storage/repositories.rs` and
  `load_cached_state` (`src/app/shell.rs`) are untouched; a
  restart starts the Planets view at `Loading` like Industry.
- NO widening of `FIRST_AUTH_SCOPES` (`src/config.rs:33-39`). The
  planets scope arrives only through the existing generic step-up
  flow, via ONE additive constant (section 5).
- NO pin-category classification. No inspected body contains a
  grounded table mapping pin type IDs to extractor/factory/storage
  categories, so this slice never classifies a pin by category.
  Extractor rows come only from a present `extractor_details`
  object; stored items come only from present pin `contents`
  entries on any pin (section 9).
- NO map or position rendering. Pin latitude/longitude are parsed
  and carried, never rendered.
- NO notifications, timers, expiry countdowns, storage-full
  warnings, capacity or utilization math, and NO `needs_tick`
  change. (The draft library specification describes all of these;
  none is in this slice.)
- NO per-colony detail prefetch. The retired Flutter sync fetched
  the detail payload for every colony (an N+1 walk in
  `planetary_sync_service.dart` at `ed698d3`); this slice fetches
  detail only for the one selected colony (section 7).
- NO new settings, NO search box, NO filters. Colony counts are
  small and the rows are selectable directly.
- Any count or amount shown saturates on addition and clamps
  negatives to zero (section 9). No other arithmetic is performed
  on payload numbers.
- No push and no merge are part of implementation work under this
  design; builders commit on `feat/rust-pi-port` only.

Cross-cutting rules that bind every builder:

- The interface shows resolved EVE names only, never a raw numeric
  ID, in rendered strings AND in error text. Section failures use
  the fixed wordings locked in section 7.4; full error detail
  goes to `tracing` warn logs only.
- Every new log line uses `tracing` with a bracketed tag: `[PI]`
  for this slice's endpoints, state, view, and shell wiring;
  `[DEMO]` inside `src/demo/data.rs` per that file's existing
  convention; `[AUTH]`/`[ESI]` only where existing shell code
  already uses them. Token values, authorization codes, OAuth
  state values, and authorize URLs are never logged.
- No attribution lines in any commit or generated content.

## 3. Evidence base (inspected bodies)

Every lock below traces to a body read during design. Citations
use the current Rust tree unless marked `@ed698d3`.

Retired Flutter PI (history only):

- `lib/core/network/esi_client.dart:579` `getCharacterPlanets` —
  `GET /characters/$characterId/planets/` returning a colony list;
  `:591` `getCharacterPlanetPins` —
  `GET /characters/$characterId/planets/$planetId/` returning one
  object whose `pins` array it maps; the rest of that object is
  discarded unread.
- `lib/core/network/esi_client.dart:1219` `EsiPlanetaryColony`
  parses `planet_id`, `planet_type` (a String), `solar_system_id`,
  `last_update`, `upgrade_level`, `num_pins`; `:1246`
  `EsiPlanetaryPin` parses `pin_id`, `type_id`, `latitude`,
  `longitude`, `install_time`, `expiry_time`, `schematic_id`,
  `last_cycle_start`, and `extractor_details.product_type_id`,
  `extractor_details.qty_per_cycle`,
  `extractor_details.cycle_time`.
- `lib/core/config/eve_config.dart:108` — the one PI scope string
  `esi-planets.manage_planets.v1` in `phase5ExpansionScopes`.
- `lib/features/pi/data/planetary_sync_service.dart` — the sync
  that fabricates `planetName: 'Planet ${esiColony.planetId}'`
  and stores `typeName: null`. Both are defects this design
  explicitly does not copy (sections 8 and 10).
- `lib/features/pi/data/models/colony.dart` — `Colony`, `Pin`,
  `Extractor` shapes; the model's `Extractor.headCount` is never
  populated by the ESI parser above, so it is not wire evidence
  (unresolved item U2, section 13).

Current Rust tree:

- `src/config.rs` — `FIRST_AUTH_SCOPES` (33-39) and the additive
  step-up constants `ASSETS_SCOPES` (64), `MARKET_SCOPES` (69),
  `CHARACTER_DETAIL_SCOPES` (74-80), `INDUSTRY_SCOPES` (87-90),
  each guarded by an exact-equality plus disjointness test
  (157-219).
- `src/app/state.rs` — `View`/`View::ALL` (15-69), `LoadState`
  (73-103), `StepUpRequest::new(character_id, scopes: &[&str])`
  (135-152), `SectionError`/`SectionResult` (223-228),
  `MarketSelection` and the selection-outside-`LoadState` pattern
  (259-294, 471-479), `IndustryData::needs_industry_stepup`
  (313-326), `set_market_selection` generation bump (522-540),
  and the character switch/removal resets (558-691).
- `src/app/shell.rs` — `BackendMsg` (39-75),
  `market_result_matches` identity check (134-139),
  `schedule_name_resolution` with its per-bundle ID blocks
  (402-547; Industry block 499-520), the Industry tolerant
  sub-fetches inside `start_refresh` (1235-1276), the
  `RefreshFailed` fixed-wording arm (695-703), on-demand
  `start_market_fetch` (894-1009), the drain order in
  `drain_requests` (815-834), `StepUpLoggedIn` handling (720-748),
  the already-granted shortcut in `start_stepup_login`
  (1581-1599), key collection `Num1..Num8` (1774-1790), the view
  dispatch match (1949-1960), and label-based startup-view
  persistence (343-350, 1851-1864).
- `src/esi/client.rs:321` — `auth_get` (plain) beside
  `auth_get_page` (paginated); `src/esi/endpoints.rs:577-626` —
  the single-object/list `auth_get` wrappers to copy, and `:722`
  `needs_reauthorize`; `src/esi/models.rs:520-595` — the
  `#[serde(default)]`-everywhere model style, instance IDs carried
  but never rendered, and nullability preserved (549-550).
- `src/ui/industry.rs` — the view to copy: pure row builders,
  `saturating_add`/`.max(0)` counts (85-86, 116-126, 244-256),
  `BLUEPRINT_RENDER_MAX` cap (161), `section_error_label`
  (264-272), `industry_reauthorize_panel` (276-314), and the
  `show` skeleton (454-487). `src/ui/market.rs:74-77,120-123` —
  the same saturating/clamping arithmetic.
- `src/demo/data.rs` — the loader chain
  `load_demo_bundle_from` → `with_assets` → `with_detail` →
  `with_market` → `with_industry` → `load_demo_bundle`
  (236-440), per-file entry structs with `#[serde(default)]` on
  every field (194-222), the optional-section arm of
  `validate_bundle` (615-653), and the empty-if-absent compose
  arms in `apply_character` (839-967; Market 913-945, Industry
  946-966).
- `src/names/resolver.rs` — `name` → `Unknown Item` (133-141),
  `location_name` → `Unknown Location` (144-149), `missing`
  dedupe with `id <= 0` skipped (154-166), and `is_structure_id`
  (33-35).

The scope string `esi-planets.manage_planets.v1` is grounded in
three inspected bodies — Flutter `eve_config.dart:108` above,
`docs/industry-port-design.md` (which names it while excluding it
from the Industry slice), and the draft context-library planetary
specification's endpoint table. It is NOT an unresolved item.
That library specification is draft Dart pseudocode, used here
only as conceptual support for the detail object carrying `pins`,
`links`, and `routes` and for pins carrying `contents` entries
with a type and an amount; it is not wire-format proof (see U1).

## 4. Endpoint map (Builder A, `src/esi/endpoints.rs`)

Exactly two new getters, both plain authenticated GETs. Neither
endpoint is paginated in any inspected body, so both use
`client.auth_get` (never `auth_get_page`), take no page argument,
and return rows in fetch order, unsorted and unfiltered — the
same contract comment style as the Industry getters.

| Getter | Templated path | Returns |
|---|---|---|
| `get_character_planets(client, character_id)` | `/characters/{character_id}/planets/` | `AppResult<Vec<PlanetColony>>` |
| `get_character_planet(client, character_id, planet_id)` | `/characters/{character_id}/planets/{planet_id}/` | `AppResult<PlanetColonyDetail>` |

Paths are built with `format!` exactly like `get_location`
(`endpoints.rs:577-585`), and each getter opens with the matching
debug line, e.g.
`tracing::debug!("[PI] GET /characters/{}/planets/", character_id)`
and, for detail, the templated two-id form. IDs in log lines
follow the existing `[CHAR]` convention; nothing here logs token
material, codes, state, or URLs.

Each doc comment states: requires scope
`esi-planets.manage_planets.v1` (progressive step-up, never
first-auth); a missing scope surfaces as HTTP 401/403 →
`EsiError::Reauthorize`/`Unauthorized`, detected only through the
existing `endpoints::needs_reauthorize` (`endpoints.rs:722`).

There is deliberately NO third getter. The schematics route from
the library specification (`/universe/schematics/{id}/`) is out
of scope (section 2), and no universe/planet lookup route is
added to name a planet (section 10).

## 5. Scope constant (Builder A, `src/config.rs`)

One additive constant, placed after `INDUSTRY_SCOPES` (87-90),
with the same doc-comment shape:

```rust
pub const PLANETS_SCOPES: &[&str] = &["esi-planets.manage_planets.v1"];
```

`FIRST_AUTH_SCOPES` and `PHASE1_ENDPOINT_SCOPES` stay
byte-identical. Note for the integrator: adding this constant and
its two call sites makes the literal strings `esi-planets` and
`/planets/` appear under `src/` for the first time; the Industry
design's absence-grep expectations were written for that slice
and do not bind this one. Nobody edits the Industry design
document.

Guard test, copying `industry_scopes_are_the_two_stepup_scopes`
(205-219):

```rust
#[test]
fn planets_scopes_is_the_single_stepup_scope() {
    assert_eq!(EveConfig::PLANETS_SCOPES, ["esi-planets.manage_planets.v1"]);
    for scope in EveConfig::PLANETS_SCOPES {
        assert!(
            !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
            "step-up scope {scope} must be disjoint from first-auth"
        );
    }
}
```

## 6. Typed models (Builder A, `src/esi/models.rs`)

Five structs appended after `IndustryJob`, before `EsiErrorBody`.
All derive `Debug, Clone, Default, Serialize, Deserialize` and
put `#[serde(default)]` on every field, matching
`CharacterBlueprint`/`IndustryJob` (520-595). Serde field names
are the wire names (the models use snake_case wire names
directly, so no renames). Unknown payload keys are ignored by
serde as everywhere else in this file.

```rust
pub struct PlanetColony {
    pub planet_id: i64,        // instance identity, see below
    pub planet_type: String,   // ESI word, rendered via whitelist only
    pub solar_system_id: i64,  // resolved via location path
    pub last_update: String,   // ESI date string, carried as-is
    pub upgrade_level: i64,    // clamped >= 0 at row build
    pub num_pins: i64,         // clamped >= 0 at row build
}

pub struct PlanetColonyDetail {
    pub pins: Vec<PlanetPin>,
    pub links: Vec<serde_json::Value>,   // raw, never rendered
    pub routes: Vec<serde_json::Value>,  // raw, never rendered
}

pub struct PlanetPin {
    pub pin_id: i64,           // instance identity, tie-break only
    pub type_id: i64,          // resolved via item name path
    pub latitude: f64,         // carried, never rendered
    pub longitude: f64,        // carried, never rendered
    pub install_time: String,  // carried, never rendered
    pub expiry_time: Option<String>,
    pub last_cycle_start: Option<String>,
    pub schematic_id: Option<i64>, // carried, never rendered/resolved
    pub extractor_details: Option<ExtractorDetails>,
    pub contents: Vec<PinContent>,
}

pub struct ExtractorDetails {
    pub product_type_id: Option<i64>,
    pub qty_per_cycle: Option<i64>,
    pub cycle_time: Option<i64>,
}

pub struct PinContent {
    pub type_id: i64,
    pub amount: i64,
}
```

Field-by-field locks:

- `planet_id` and `pin_id` are per-instance identities. They are
  selection identity and invisible sort tie-breaks only: never
  rendered and never sent to universe name resolution. Each gets
  the same doc-comment warning `IndustryJob` gives `job_id`
  (540-545).
- `planet_type` is a String in the grounded payload
  (`EsiPlanetaryColony.planetType`); there is NO numeric planet
  type id in any inspected body. It is therefore never scheduled
  for name resolution and never echoed verbatim: the view renders
  it only through the whitelist in section 9. The retired
  Flutter card's string→type-id icon table is not copied.
- `links` and `routes` are decoded as raw `serde_json::Value`
  arrays. They are NEVER rendered, never counted in the
  interface, and no ID inside them is ever scheduled for name
  resolution or used in any computation. Their lengths may appear
  in one `[PI]` info log line in the shell fetch (section 7.3) —
  logs only. They exist in the model so the detail decode is
  faithful and a future slice can type them without a model
  break.
- `install_time` is a plain `String` defaulting to empty. The
  Flutter parser substituted the current time when it was absent;
  that fabrication is not copied. `expiry_time`,
  `last_cycle_start`, and all `ExtractorDetails` fields keep
  exact nullability: `None` is never coerced to zero (the
  `IndustryJob` rule, models.rs:549-550).
- `ExtractorDetails` carries ONLY the three fields the Flutter
  ESI parser read from the wire (`product_type_id`,
  `qty_per_cycle`, `cycle_time`). No `head_count` and no heads
  list: neither is wire-grounded (U2).
- `PinContent` is the one declared-wire-risk type in this slice
  (U1, section 13): the keys `contents`, `type_id`, and `amount`
  are conceptually grounded in the library specification but
  appear in no inspected wire parser. The lock that makes this
  safe: `#[serde(default)]` everywhere, so a wire mismatch
  degrades to empty contents and the honest label in section 9 —
  never a decode failure, never a fabricated row. Builder A adds
  NO alternate-key aliases or fallback key guesses; if live
  verification later shows different keys, that arrives as a
  design amendment with evidence, not a silent alias.

Model unit tests (Builder A, in `models.rs` tests, copying the
existing `serde_json::from_str` style): a colony list element
parses with every field; a detail object parses pins plus
extractor_details plus contents and keeps links/routes raw
lengths; a pin with no extractor_details and no contents parses
to `None`/empty; missing keys default everywhere.

## 7. State and fetch placement

### 7.1 State shape (Builder B, `src/app/state.rs`)

New types beside `IndustryData` (296-326), with the same
cross-builder field-set contract comment ("shell and demo seeding
construct this literally; do not add fields here"):

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PlanetSelection {
    pub character_id: i64,
    pub planet_id: i64,
}

#[derive(Debug, Clone)]
pub struct SelectedColonyDetail {
    pub selection: PlanetSelection,
    pub result: SectionResult<PlanetColonyDetail>,
}

#[derive(Debug, Clone)]
pub struct PlanetaryData {
    pub colonies: SectionResult<Vec<PlanetColony>>,
    pub detail: Option<SelectedColonyDetail>,
}

impl PlanetaryData {
    pub fn needs_planetary_stepup(&self) -> bool { /* 7.5 */ }
}
```

`PlanetSelection` is fetch/message identity only; its numbers are
state, never rendered (the `MarketSelection` doc rule, 259-264,
applies verbatim and is copied into its doc comment).

New `AppState` fields, placed with the other view bundles and
view-local state (440-493):

```rust
pub planetary: LoadState<PlanetaryData>,
// view-local, in the market/industry view-local block:
pub planetary_selected_planet_id: Option<i64>,
pub planetary_generation: u64,
// request flag, in the request-flag block:
pub planetary_detail_fetch_requested: bool,
```

The selected planet lives OUTSIDE `LoadState<PlanetaryData>` so a
failed detail fetch cannot lose the selection — the exact reason
`market_selected_type_id` lives outside `LoadState<MarketData>`
(471-479). No per-character map, no persistence, no search field.

Selection is changed only through one new method copying
`set_market_selection` (522-540):

```rust
pub fn set_planetary_selection(&mut self, planet_id: i64)
```

It sets `planetary_selected_planet_id = Some(planet_id)`, bumps
`planetary_generation` with `wrapping_add(1)` (reselecting the
same planet also bumps and refetches, exactly like reselecting
the same market type), sets `planetary_detail_fetch_requested =
true`, and logs one `[PI]` info line carrying only counts/state
words and the character/planet ids per the existing log
convention. It does NOT touch `self.planetary`: staleness is
handled by keying, next paragraph, so there is no window where a
half-cleared bundle renders.

Stale-detail rule (the core of this shape): detail is displayable
only when ALL of these hold — `detail` is `Some`,
`detail.selection.planet_id == planetary_selected_planet_id`,
and `detail.selection.character_id == active_character_id`. The
view computes this match itself (section 9) and the shell applies
results only on the same match plus generation (section 7.3), so
a detail fetched for a previous planet or a previous character
can never display, even for one frame. When a planet is selected
and no matching detail exists yet, the detail section shows its
loading panel; there is no separate loading flag.

### 7.2 Colonies list: main-refresh tolerant sub-fetch (LOCKED)

Fetch placement is locked as a hybrid, taking the
main-refresh-list-only option rather than a Market-style
on-demand list:

- The colonies LIST is a tolerant sub-fetch inside
  `start_refresh` (integrator, `src/app/shell.rs`), appended
  after the Industry block (1235-1276) in the same async closure,
  never `?`:

```rust
let colonies = endpoints::get_character_planets(&esi, id)
    .await
    .map_err(|e| {
        let needs_reauthorize = endpoints::needs_reauthorize(&e);
        tracing::warn!("[PI] planetary section failed character_id={} section=colonies needs_reauthorize={} error={}", id, needs_reauthorize, e);
        SectionError {
            message: "colonies request failed".to_string(),
            needs_reauthorize,
        }
    });
```

  followed by one `[PI]` info line with the colony count on
  success. `BackendMsg::Refreshed` gains ONE field,
  `planetary_colonies: SectionResult<Vec<PlanetColony>>`, threaded
  through the result tuple exactly like `industry` (1277-1403).
  It carries the section only — never a whole `PlanetaryData` —
  because detail preservation needs the current state at apply
  time.

Rationale for the lock: the list is character-scoped and
refresh-driven — everything needed to fetch it is known at
refresh time, which is the Industry/character-detail shape, not
the Market shape (Market is on-demand because it needs a
user-chosen type and region first). Riding the main refresh also
means the step-up already-granted shortcut and `StepUpLoggedIn`
already refetch the list through `request_refresh` with no new
plumbing (section 7.5), and the Refresh button, login, and
character-switch paths all refill colonies for free.

Apply rule in the `Refreshed` drain arm (integrator; this merge
is the one non-obvious integrator behavior, so it is locked
exactly):

1. If the refreshed `character_id` is no longer present, the
   existing guard at the top of the arm already drops the whole
   message; nothing planetary happens.
2. Decide separately whether the selection survives: it does
   unless the new colonies section is `Ok` and that list does not
   contain `planetary_selected_planet_id` (a failed list cannot
   prove the planet vanished, so `Err` keeps the selection). If
   it does not survive, clear `planetary_selected_planet_id` to
   `None` and bump `planetary_generation` (`wrapping_add(1)`),
   with one `[PI]` debug line.
3. Compute the preserved detail: take the current
   `planetary.as_ready().detail`, keep it only if its
   `selection.character_id` equals the refreshed character AND
   the selection survived step 2; otherwise `None`.
4. Install `planetary = Ready(PlanetaryData { colonies:
   planetary_colonies, detail: preserved })`.
5. If the selection survives (whether or not a detail was
   preserved), set `planetary_detail_fetch_requested = true` so
   the main refresh also refreshes the visible detail — one
   extra identity-guarded GET, never N+1.

`RefreshFailed` arm: add the Industry-mirroring fixed-wording
block (copy 695-703 with its comment): if
`!self.state.planetary.is_ready()`, set
`LoadState::Error("character refresh request failed".to_string())`.
The raw refresh `message` is never installed into planetary
state. Selections and generation are untouched by `RefreshFailed`.

### 7.3 Colony detail: on-demand spawn on selection change (LOCKED)

Detail fetch is its own spawn copying `start_market_fetch`
(894-1009) and `market_result_matches` (134-139), keyed by
request identity = character + planet + generation:

- New message: `BackendMsg::PlanetaryDetailFetched { generation:
  u64, selection: PlanetSelection, result:
  SectionResult<PlanetColonyDetail> }`. The `Err` travels INSIDE
  the message so a stale failure is dropped by the same identity
  check as a stale success.
- New pure check beside `market_result_matches`:

```rust
fn planetary_result_matches(
    state: &AppState,
    generation: u64,
    selection: &PlanetSelection,
) -> bool {
    generation == state.planetary_generation
        && Some(selection.planet_id) == state.planetary_selected_planet_id
        && Some(selection.character_id) == state.active_character_id
}
```

- Drain arm: on match, install into the Ready bundle
  (`detail = Some(SelectedColonyDetail { selection, result })`),
  log one `[PI]` info line (pin count, raw link count, raw route
  count on `Ok` — log-only per section 6), then call
  `schedule_name_resolution()`. On mismatch, drop with the
  Market-style warn: `"[PI] dropping colony detail result for a
  superseded selection"`. If `planetary` is not `Ready` when a
  matching result lands (possible only if a refresh error raced
  it), drop it the same way — the next refresh re-queues per
  7.2 step 5.
- `start_planetary_detail_fetch(&mut self)` (integrator): clears
  the flag first (like 895); demo branch per section 11; live
  branch requires `active_character_id` and
  `planetary_selected_planet_id` (either missing → one `[PI]`
  debug line and return), stamps `PlanetSelection` and
  `generation`, and without backends/runtime installs a stamped
  `Err(SectionError { message: "colony detail request failed",
  needs_reauthorize: false })` through the same match check
  rather than a whole-view `LoadState::Error` (a detail failure
  must never blank the colonies list). The spawned task maps the
  getter error to `SectionError { message: "colony detail
  request failed", needs_reauthorize:
  endpoints::needs_reauthorize(&e) }` with the full error in one
  `[PI]` warn line, then sends the message.
- Drain order in `drain_requests`: after the
  `market_fetch_requested` drain (825-827), add
  `if self.state.planetary_detail_fetch_requested {
  self.start_planetary_detail_fetch(); }`. No other drain order
  changes.

### 7.4 Fixed error wordings (complete list)

These three literals are the only planetary failure strings that
can reach the screen. Everything else renders from typed flags
(section 9) or the widget panels.

- `"colonies request failed"` — colonies section `SectionError`.
- `"colony detail request failed"` — detail section `SectionError`
  (including the no-backends path).
- `"character refresh request failed"` — whole-view
  `LoadState::Error` from `RefreshFailed`.

### 7.5 Step-up panel policy

One panel, in the Planets view (Builder B), copying
`industry_reauthorize_panel` (`src/ui/industry.rs:276-314`)
including its enabled rule (`!state.demo && !state.auth.is_busy()
&& state.active_character_id.is_some()`), its spinner while busy,
and its status-message sentence. Locked wording:

- Heading: `Planetary Industry needs one more EVE permission.`
- Body: colonies and colony detail will not load until the EVE
  SSO scope `EveConfig::PLANETS_SCOPES.join(" ")` is granted;
  other views are unaffected. Then the Industry panel's
  choose-Re-authorize/sign-in-as-the-same-character sentences with
  the active character's name.
- Button `Re-authorize with EVE SSO` sets only
  `state.stepup_requested = Some(StepUpRequest::new(active_id,
  EveConfig::PLANETS_SCOPES))`. The generic flow in
  `start_stepup_login` (union scopes, expected-character check,
  JWT verification, save-nothing-on-mismatch) is reused verbatim;
  no planets-specific auth code exists.

Panel visibility: `!state.demo && active_character_id.is_some()
&& bundle.needs_planetary_stepup()`, where
`needs_planetary_stepup` (state.rs, copying
`needs_industry_stepup` 320-325) is true when the colonies
section is `Err` with `needs_reauthorize`, OR a present detail's
result is `Err` with `needs_reauthorize`. (Detail can only be
present if it matched the current selection at install time, and
the switch/removal resets in section 8 clear it, so no extra
matching is needed inside this predicate.) Nothing clears the
panel except a later fetch returning `Ok` — login success alone
never clears it, per the existing comment rule at shell.rs
724-728.

Already-granted lesson (from Market, shell.rs 1589-1596): the
shortcut MUST queue the same refetch the panel gates. The panel
gates two fetches, so the integrator locks BOTH arms:

- In the already-granted shortcut (`start_stepup_login`,
  1581-1599): the existing `request_refresh("stepup-already-granted")`
  already refetches the colonies list. Add, mirroring the market
  lines: `if self.state.planetary_selected_planet_id.is_some() {
  tracing::debug!("[PI] colony detail refetch queued after
  already-granted step-up"); self.state.planetary_detail_fetch_requested
  = true; }`. The flag named here —
  `planetary_detail_fetch_requested` — is the gated detail
  refetch this requirement refers to.
- In `StepUpLoggedIn` (720-748): the existing
  `request_refresh("post-stepup")` covers the list; add the same
  three lines (debug text `"[PI] colony detail refetch queued
  after step-up"`) beside the market refetch queue. Clear nothing
  in either arm.

### 7.6 What does not fetch

Character switch does NOT queue a detail fetch: the switch clears
the selection (section 8), and `drain_requests`' existing
character-switch arm (796-813) gains no planetary lines — the
`request_refresh("character-switch")` it already queues refills
the list under the new character. The top-bar/keyboard refresh
likewise refills the list, and 7.2 step 5 re-queues detail when a
selection survives. Nothing in this slice polls or ticks:
`needs_tick` is untouched.

## 8. Character switch and removal resets (Builder B, state.rs)

Copying the Industry reset argument (608-617) plus the Market
generation argument (598-607) — both apply, because colonies are
tolerantly fetched (Industry shape) and detail is
identity-stamped (Market shape):

- `set_active_character`, inside the existing
  `previous_id != character_id` block, after the industry reset:
  `planetary = LoadState::Loading`,
  `planetary_selected_planet_id = None`,
  `planetary_detail_fetch_requested = false`,
  `planetary_generation = planetary_generation.wrapping_add(1)`,
  with the paired `[PI]` debug line in the Industry style
  (`"[PI] clearing planetary on character switch from={} to={}"`).
  Same-character reselect touches nothing planetary.
- `remove_character`, inside the removed-was-active block (after
  the industry line at 666-667), same four assignments and a
  `"[PI] clearing planetary of removed active character"` debug
  line. This must be here, not left to the `set_active_character`
  call below, for the reason the assets comment at 651-654
  records (previous is already `None` there).
- `remove_character`, `characters.is_empty()` branch (680-690):
  add `planetary = LoadState::Empty`,
  `planetary_selected_planet_id = None`,
  `planetary_detail_fetch_requested = false`, and one
  `planetary_generation` bump, beside the market/industry lines.
- Removing a NON-active character changes no planetary state
  (detail and list belong to the active character only). A
  pending step-up for the removed character is already cleared
  generically at 672-679.

State unit tests (Builder B, copying the assets/detail switch
tests at 792-875 in shape): switch resets to `Loading` and clears
selection while bumping generation; same-character reselect
keeps the bundle and selection; removing the active character
resets and the empty-roster removal lands on `Empty` with no
selection; `set_planetary_selection` bumps generation, sets the
flag, and leaves a stale stamped detail unmatchable.

## 9. Pure helpers and the Planets view (Builder B)

### 9.1 Helpers (`src/ui/planets.rs`, new file)

All helpers are pure functions over model slices plus the
resolver, unit-tested in the file, copying `src/ui/industry.rs`
helper/test style. Every count addition is `saturating_add`;
every payload count or amount is `.max(0)` before display or
summation. Each helper ends with one `[PI]` debug line carrying
row counts only (the `industry_job_rows` pattern, 101-107).

`planet_type_label(planet_type: &str) -> &'static str` — the
whitelist that replaces echoing the remote string (the
`activity_label`/`status_label` pattern, industry.rs 19-41). The
value set is the eight words the retired Flutter card switched
on:

| Wire value | Label |
|---|---|
| `temperate` | `Temperate` |
| `barren` | `Barren` |
| `gas` | `Gas` |
| `ice` | `Ice` |
| `lava` | `Lava` |
| `oceanic` | `Oceanic` |
| `plasma` | `Plasma` |
| `storm` | `Storm` |
| anything else | `Unknown planet type` |

`ColonyRow` + `colony_rows(colonies: &[PlanetColony], resolver)
-> Vec<ColonyRow>`:

```rust
pub struct ColonyRow {
    pub planet_id: i64,          // selection identity, never rendered
    pub system_name: String,     // resolver.location_name(solar_system_id)
    pub planet_type_label: &'static str,
    pub upgrade_level: i64,      // .max(0)
    pub num_pins: i64,           // .max(0)
    pub last_update: String,
}
```

Locked colony sort: `system_name` lowercased, then `system_name`,
then `planet_type_label`, then `planet_id` as the invisible
tie-break (the `blueprint_rows` comparator shape, 196-207). No
grouping: one row per colony, no summary arithmetic on colonies
beyond the shown counts. The Flutter repository sorted by its
fabricated `planetName`; that sort is not copied.

`PinTypeCountRow` + `pin_type_counts(pins: &[PlanetPin], resolver)
-> Vec<PinTypeCountRow>`: group pins by `type_id`.

```rust
pub struct PinTypeCountRow {
    pub type_id: i64,       // grouping/sort key, never rendered
    pub type_name: String,  // resolver.name(type_id)
    pub count: usize,       // saturating_add per pin
}
```

Pins with `type_id <= 0` are skipped and counted only in the
debug log (the Market invalid-row pattern, market.rs:59). Locked
sort: `count` descending, then `type_name` lowercased, then
`type_name`, then `type_id`.

`ExtractorProductRow` + `extractor_product_rows(pins, resolver)
-> Vec<ExtractorProductRow>`: one row per pin whose
`extractor_details` is `Some` AND whose `product_type_id` is
`Some(id)` with `id > 0`. Pins with extractor details but no
product are not extractor products and appear only in pin counts.

```rust
pub struct ExtractorProductRow {
    pub pin_id: i64,                  // tie-break only
    pub pin_type_name: String,        // resolver.name(pin.type_id)
    pub product_name: String,         // resolver.name(product_type_id)
    pub qty_per_cycle: Option<i64>,   // .map(|v| v.max(0))
    pub cycle_time: Option<i64>,      // .map(|v| v.max(0))
}
```

Locked sort: `product_name` lowercased, then `product_name`,
then `pin_type_name`, then `pin_id`. NO totals, rates,
per-hour math, or aggregation across extractors — that would be
a production calculator (section 2).

`StorageContentRow` + `storage_content_rows(pins, resolver)
-> Vec<StorageContentRow>`: aggregate `contents` entries across
ALL pins by `type_id` (no pin-category classification exists,
section 2).

```rust
pub struct StorageContentRow {
    pub type_id: i64,       // grouping/sort key, never rendered
    pub type_name: String,  // resolver.name(type_id)
    pub amount: i64,        // saturating sum of per-entry .max(0)
}
```

Rules: skip entries with `type_id <= 0` (debug-log count only);
clamp each entry's `amount` with `.max(0)` before
`saturating_add`; drop groups whose total is zero. Locked sort:
`amount` descending, then `type_name` lowercased, then
`type_name`, then `type_id`.

Render caps, copying `BLUEPRINT_RENDER_MAX` (industry.rs:161):
`PIN_TYPE_RENDER_MAX`, `EXTRACTOR_RENDER_MAX`, and
`STORAGE_RENDER_MAX`, all `100`, each with a
`Showing {shown} of {total} ...` label when truncated. Colony
rows are not capped (the list is the selection control; capping
it would hide selectable colonies).

### 9.2 View (`pub fn show` in `src/ui/planets.rs`)

Skeleton copies `ui::industry::show` (454-487): heading
`Planetary Industry`, `widgets::mode_notice`, no-character
panel, then a cloned `LoadState<PlanetaryData>` snapshot match —
`Loading` → `loading_panel(ui, "Loading planetary data...")`;
`Empty` → `empty_panel(ui, "No planetary data yet.")`; `Error`
→ `error_panel_with_retry` setting `retry_requested` (with the
Industry-style `[PI]` warn line); `Ready(bundle)` → step-up
panel when shown (7.5), then the colonies section, then the
detail section. The view sets request flags only — it never
fetches, never constructs a `BackendMsg`, never touches tokens.
The file header comment says so, copying industry.rs 1-6 with
`[PI]` wording.

Colonies section (private `show_colonies_section`): heading
`Colonies`. `Err` → a local copy of `section_error_label`
(industry.rs 264-272, word-identical behavior, section word
`"colonies"`). `Ok` empty → `No colonies for this character.`
`Ok` non-empty → count label `"{n} colonies loaded."`, then one
selectable row per `ColonyRow`: the `selectable_label` text is
`"{system_name} — {planet_type_label}"`, followed by labels
`"Upgrade level: {upgrade_level}"`, `"Pins: {num_pins}"`, and,
only when `last_update` is non-empty, `"Last update:
{widgets::format_date_short(&last_update)}"` (the industry
non-empty-date guard). Selected state is
`Some(row.planet_id) == state.planetary_selected_planet_id`;
a click calls `state.set_planetary_selection(row.planet_id)`
(nothing else — the setter owns generation, flag, and logging).
Two colonies in one system with the same planet type render
identically named rows; they stay distinct selectable rows via
their invisible identities. That is accepted for this slice
rather than fabricating a distinguishing name (section 13, U4).

Detail section (private `show_detail_section`): heading
`Selected colony`. Locked states, in order:

1. No selection → label `Select a colony above to see its pins,
   extractors, and stored items.`
2. Selection present but `bundle.detail` is `None` or its
   selection does not match (planet AND active character, 7.1) →
   `loading_panel(ui, "Loading colony detail...")`.
3. Matching `Err` → the same local `section_error_label` with
   section word `"colony detail"`.
4. Matching `Ok(detail)` → three subsections over `detail.pins`
   only (`links`/`routes` raw are never opened here):
   - `Pin types`: empty → `No pins were reported for this
     colony.`; else `"{count} × {type_name}"` rows (count label
     `Showing {shown} of {total} pin types.` only when capped).
   - `Extractors`: empty → `No extractors were reported for this
     colony.`; else rows `"{product_name} — {pin_type_name}"`,
     plus `"Quantity per cycle: {n}"` when `qty_per_cycle` is
     `Some`, plus `"Cycle time: {n} seconds"` when `cycle_time`
     is `Some`. `None` values render as nothing — never `0`.
   - `Stored items`: empty → `No stored items were reported for
     this colony.` (the word "reported" is load-bearing: with U1
     open this label asserts only what the payload carried, not
     that the colony holds nothing); else rows
     `"{amount} × {type_name}"`.

Every string above is a literal of this design; Builder B copies
them verbatim. Rendered values are exclusively resolver names,
whitelist words, clamped counts, and formatted dates.

Helper unit tests (Builder B, copying industry.rs tests 489+,
with a hand-seeded resolver): whitelist covers all eight words
plus the unknown fallback; colony sort order and clamping
(negative level/pins → 0); pin counts group, skip non-positive
type ids, and sort count-descending; extractor rows exclude
missing-product pins, clamp quantities, and keep `None` as
`None`; storage rows clamp per entry, saturate (two near-`i64::MAX`
entries do not overflow), drop zero totals, and skip
non-positive type ids.

### 9.3 View placement and key numbering (Builder B + integrator)

- `src/app/state.rs`: insert `Planets` in `View` between
  `Industry` and `Settings`, in `View::ALL` at the same position
  (`[View; 9]`), and `label()` → `"Planets"`. Update the enum doc
  comment from "eight views (keys 1-8)" to nine/1-9.
- `src/ui/mod.rs`: add `pub mod planets;` (alphabetical position
  after `market`).
- Shell dispatch exception, pre-authorized for Builder B: exactly
  ONE added line in the `update` view match (1949-1960) —
  `View::Planets => ui::planets::show(ui, &mut self.state,
  &self.resolver),` between the Industry and Settings arms. No
  other Builder B edit in `shell.rs`; everything else there is
  the integrator's (section 12).
- Key numbering (integrator): `collect_keys` list gains
  `egui::Key::Num9`, so Planets is key 8 and Settings moves from
  8 to 9. The two literal hint strings update with it: rail
  heading `"Views (keys 1-8)"` → `"Views (keys 1-9)"` and the
  status bar `"Keys: 1-8 views, ..."` → `"Keys: 1-9 views, ..."`.
  Nothing else numbers the views in the tree (the rail renders
  `idx + 1` from `View::ALL`, and Settings' startup picker
  iterates `View::ALL`, so both follow automatically).
- Label persistence needs no migration and no code beyond the
  above: the startup view is persisted and matched by label
  string (`View::ALL.iter().find(|v| v.label() == saved)`,
  shell.rs 343-350, written back by label at 1851-1864). A saved
  `"Settings"` still restores Settings after its key moves;
  `"Planets"` becomes a valid new saved value the first time a
  user picks it. No index is ever persisted.

## 10. Name scheduling (integrator, `schedule_name_resolution`)

One new block after the Industry block (shell.rs 499-520), under
a `// Planetary IDs (design section 10): ...` comment in that
block's style. From a Ready planetary bundle:

- Colonies `Ok`: each colony's `solar_system_id`, each behind
  `if !crate::names::resolver::is_structure_id(id)` — the guarded
  location path. (Solar-system ids are far below the structure
  floor, so the guard is uniform-convention insurance, matching
  every other location-class push in this function.)
- Detail `Some` with `Ok`: each pin's `type_id`; each pin's
  extractor `product_type_id` via `ids.extend(...)` over the
  `Option`; each pin-content entry's `type_id`. These resolve
  through the item-name path (`resolver.name` at render).

NEVER scheduled: `planet_id`, `pin_id`, `schematic_id`, anything
inside raw `links`/`routes`, and `planet_type` (a word, not an id
— section 6). The colony's display identity is therefore its
resolved system name plus its planet-type word; the Flutter
`'Planet $planetId'` fabrication and any attempt to resolve a
planet (instance) id through `/universe/names/` are both
explicitly rejected by this design. The existing demo
early-return (403-405) already covers demo mode; the refreshed
and detail-applied call sites of `schedule_name_resolution()`
(632, 758, and the new 7.3 arm) are the only triggers.

## 11. Demo fixture extension

Serde back-compatibility is the chain's standing contract and is
kept exactly: every older loader keeps its meaning by passing
`"{}"` for the new file, and every new field is
`#[serde(default)]`.

Loader chain (Builder B, `src/demo/data.rs`):

- `pub const DEMO_PLANETS_JSON: &str =
  include_str!("../../assets/demo/planets.json");` beside the
  other constants (27-35).
- New terminal loader `load_demo_bundle_with_planets(characters,
  skillqueue, wallet, assets, character_detail, market,
  industry, planets_json)` holding today's
  `load_demo_bundle_with_industry` body plus the planets parse;
  `load_demo_bundle_with_industry` shrinks to a pass-through with
  `"{}"` and a kept-meaning comment copying 306-308;
  `load_demo_bundle()` calls the new terminal loader with
  `DEMO_PLANETS_JSON`.
- New public fixture struct beside `DemoIndustryData` (98-107):

```rust
pub struct DemoPlanetaryData {
    pub colonies: Vec<PlanetColony>,
    pub selected_planet_id: Option<i64>,
    pub details: HashMap<i64, PlanetColonyDetail>,
}
```

  and `pub planets: Option<DemoPlanetaryData>` on
  `DemoCharacterData` beside `industry` (122).
- File entry (private, every field `#[serde(default)]`):

```rust
struct PlanetsFileEntry {
    colonies: Vec<PlanetColony>,
    selected_planet_id: Option<i64>,
    details: HashMap<String, PlanetColonyDetail>, // key: decimal planet id
}
```

  Keys are parsed with the same strictness as character keys via
  the existing `parse_character_key` (224-230), so a non-numeric
  key fails the bundle load with a `[DEMO]` message. A `"{}"`
  planets text yields `planets: None` for everyone; a character
  key absent from the file likewise.

Validation (Builder B): one optional-section arm in
`validate_bundle` after the industry arm (615-653), running only
when `per.planets` is `Some`:

- colony `planet_id`s unique for the character;
- every non-empty `last_update` parses (existing
  `parse_esi_datetime` helper);
- if colonies are non-empty, `selected_planet_id` is `Some` and
  is one of the colony planet ids;
- EVERY colony planet id has a `details` entry (the demo detail
  fetch must answer any selectable colony — see below);
- within each detail, `pin_id`s are unique;
- extra `details` keys not among the colonies fail.

Compose (Builder B) in `apply_character` after the industry arm
(946-966), same empty-if-absent rule, plus the Market-style
selection bookkeeping (913-945) because planetary has a
selection:

- First, unconditionally: bump `planetary_generation`
  (`wrapping_add(1)`) and clear
  `planetary_detail_fetch_requested = false` (demo re-apply
  answers synchronously; no spawn follows).
- `Some(fixture)` with colonies: set
  `planetary_selected_planet_id = fixture.selected_planet_id`,
  install `Ready(PlanetaryData { colonies: Ok(colonies), detail:
  Some(SelectedColonyDetail { selection: {character_id,
  planet_id: selected}, result: Ok(details[selected].clone())
  }) })`. A fixture with `planets: Some` but zero colonies
  installs `Ready` with `Ok(vec![])`, no selection, `detail:
  None` (an authored empty character, distinct from absent).
- `None`: `planetary = LoadState::Empty` and
  `planetary_selected_planet_id = None`, so a demo switch can
  never leave the previous character's colonies, selection, or
  detail installed.

Demo detail fetch (integrator): the demo branch of
`start_planetary_detail_fetch` answers from the bundle instead
of re-applying the whole character. It looks up the active
character's `DemoPlanetaryData.details[selected]`; on hit it
installs `Ok(detail)` stamped with the CURRENT selection and
generation-checked through `planetary_result_matches`; on miss
(unreachable after validation, but never a panic) it installs
the stamped fixed `Err` from 7.3. It never changes the demo
selection itself. This is deliberately NOT the Market demo arm's
whole-character re-apply: that would snap the user's demo colony
choice back to the fixture's on every click.

Fixture content (Builder A: `assets/demo/planets.json`, plus
additions to `assets/demo/names.json`): invented data in the
existing fixtures' voice, for both bundled demo characters.

- Character one: at least two colonies in different systems;
  details for every colony; pins covering at least two repeated
  pin types (so counts exceed 1), at least one extractor pin
  with product/qty/cycle all present, at least one extractor pin
  with `qty_per_cycle: null` (exercises the None path), contents
  entries of one shared type spread across two pins (exercises
  aggregation), one negative-amount contents entry (exercises
  clamping), and non-empty `links`/`routes` arrays (exercises raw
  decode; values are small invented objects, never displayed).
- Character two: at least one colony whose detail has pins but
  empty contents everywhere, so the reported-empty Stored items
  label is reachable in demo.
- `names.json` gains one entry for every new id the views render:
  each `solar_system_id` (category `solar_system`), each pin
  `type_id`, product `type_id`, and content `type_id` (category
  `inventory_type`), following that file's existing
  `{id, name, category}` shape. NO entry for any planet or pin
  instance id.

## 12. Ownership, sequence, and test plan

### 12.1 Ownership

| Owner | Files and symbols |
|---|---|
| Builder A | `src/esi/models.rs` (5 structs + decode tests), `src/esi/endpoints.rs` (`get_character_planets`, `get_character_planet`), `src/config.rs` (`PLANETS_SCOPES` + guard test), `assets/demo/planets.json`, `assets/demo/names.json` additions |
| Builder B | `src/app/state.rs` (`View::Planets`, `PlanetSelection`, `SelectedColonyDetail`, `PlanetaryData`, fields, `set_planetary_selection`, resets), `src/ui/planets.rs` (new: helpers, view, panel), `src/ui/mod.rs` (one line), `src/demo/data.rs` (loader chain, validate arm, apply arm), one pre-authorized dispatch line in `src/app/shell.rs` |
| Integrator | `src/app/shell.rs` (all fetch wiring: `Refreshed` field + tuple threading, apply merge 7.2, `start_planetary_detail_fetch`, `planetary_result_matches` + tests, message arm, drain order, step-up queues in both arms, `RefreshFailed` arm, name-scheduling block, `Num9` + hint strings), `README.md` |

The cross-builder contracts are the exact type/field/function
names in sections 4-7 and 11 (`PlanetColony`, `PlanetPin`,
`PLANETS_SCOPES`, `get_character_planets`,
`get_character_planet`, `PlanetaryData { colonies, detail }`,
`DemoPlanetaryData { colonies, selected_planet_id, details }`).
A builder who needs a different name stops and amends this
design; no aliases are added "to be safe".

Builder A's fixture commit and Builder B's demo-code commit are
the one known ordering coupling: `planets.json` is only parseable
once the models exist, and `load_demo_bundle()` fails to compile
against the new loader until the fixture file exists, so A lands
models+fixtures before B's loader change is expected to pass
tests. The integrator goes last.

`README.md` (integrator): add one Planets bullet beside the
Industry bullet (line 20) in its voice — read-only colonies list
plus one selected colony's pin/extractor/stored-item summary, the
`esi-planets.manage_planets.v1` step-up scope, nothing stored,
no colony management or calculator, not yet live-verified,
`--demo` shows it — update the line-27 not-implemented bullet to
drop PI from "not implemented", and change "1-8 views" to "1-9
views" (line 21).

### 12.2 Test plan

Per-builder tests are named in their sections (config guard 5,
model decode 6, state resets 8, helper arithmetic/sorts 9.2).
Additionally:

- Integrator: `planetary_result_matches` tests copying
  `market_result_identity_requires_all_four_matches`
  (shell.rs 1993+) — all-match passes; each single mismatch
  (generation, planet, character, nothing selected) drops.
- Builder B demo tests copying
  `apply_character_installs_industry_and_industryless_empties`
  (demo tests, and the Market selection-clearing test beside it):
  present-fixture installs Ready with selection and matching
  detail; absent-fixture empties and clears the selection; a
  planets fixture with a colony missing its detail fails
  validation; `"{}"` planets text leaves every character
  `planets: None` (back-compat), and the older
  `load_demo_bundle_with_industry` still loads older fixtures
  unchanged.
- Boundary greps before the integrator declares done (run, and
  quote output, never assumed): `grep -rn "public_post\|auth_post\|PUT\|DELETE"
  src/esi/endpoints.rs` shows no new write call;
  `git diff <base> -- src/storage/` is empty (no migration);
  `git diff <base> -- src/config.rs` shows FIRST_AUTH_SCOPES
  untouched; a grep for `planet_id`/`pin_id` inside
  `schedule_name_resolution` and `src/ui/planets.rs` render code
  shows them only as state/sort keys, never in a rendered
  `format!`.
- Gates (from `.github/workflows/ci.yml`, run by every builder
  before handoff and by the integrator last): `cargo fmt
  --check`, `cargo clippy --all-targets -- -D warnings`,
  `cargo test`, `cargo build`. These are the repository's own
  gates; no gate is skipped or narrowed to pass.
- Manual demo pass (integrator): `--demo`, open Planets (key 8),
  switch colonies and confirm the detail swaps, switch
  characters and confirm no previous character's colonies or
  detail show, confirm Settings is now key 9 and a saved startup
  view still restores. Live verification against a real EVE
  account cannot be claimed by any builder here (U3); the README
  bullet must carry the same "not live-verified" honesty as the
  Industry bullet.

## 13. Unresolved items (recorded, with their locked defaults)

- U1 — Pin contents wire keys. `contents[].type_id` /
  `contents[].amount` are conceptually grounded (library draft
  specification's storage parsing) but appear in no inspected
  wire parser: the Flutter ESI client discards everything in the
  detail object except three extractor fields and never reads
  contents. Locked default: typed `#[serde(default)]` decode
  (section 6), the "reported" empty label (section 9.2), demo
  coverage of both content states (section 11), and NO silent
  alternate-key guessing. If live payloads later show different
  keys, Stored items will read as reported-empty until a design
  amendment lands with the evidence — a visible, honest
  degradation, never wrong numbers.
- U2 — Extractor heads. The Flutter domain model has
  `Extractor.headCount` and the library draft has a heads list,
  but the Flutter ESI parser reads neither from the wire. Locked
  default: not modeled, not rendered, not counted.
- U3 — No live verification. No builder in this flow has EVE
  credentials; endpoint paths and the scope rest on the three
  inspected bodies in section 3 plus decode tests. The design
  treats a live 401/403 as the typed step-up outcome and any
  other failure as the fixed section wording, so a wrong
  assumption degrades to an honest error section.
- U4 — Indistinguishable colony rows. The list payload carries no
  planet name, and this design forbids both fabricating one from
  the planet id and resolving the planet instance id. Two
  same-type colonies in one system therefore show identical row
  text (still separately selectable). Accepted for this slice;
  fixing it needs a grounded planet-name source, which no
  inspected body provides.

The planets scope string is deliberately NOT on this list: it is
grounded in inspected bodies (section 3), so the step-up panel
ships enabled per section 7.5 rather than defaulting the section
to an honest error. Had it been ungrounded, that error-default —
panel never shown, sections failing with the fixed wordings —
would have been the lock; the evidence makes it unnecessary.

## 14. End-to-end flow (one paragraph)

Refresh (login, switch, button, or post-step-up) runs the main
refresh; its tolerant colonies sub-fetch lands as a
`SectionResult` and merges with any still-valid selection and
detail. The Planets view renders resolved system names and
whitelist planet words; clicking a colony stamps
character+planet+generation and spawns the one detail GET, whose
result applies only on a full identity match and then feeds name
resolution for pin, product, and content types. A missing scope
surfaces as the typed `needs_reauthorize` flag behind one
Re-authorize panel whose generic step-up — including the
already-granted shortcut — queues both the list refresh and the
`planetary_detail_fetch_requested` detail refetch, and the panel
clears only when a later fetch actually returns data. Demo mode
answers both fetches from bundled invented fixtures through the
same state shape, with no network anywhere.

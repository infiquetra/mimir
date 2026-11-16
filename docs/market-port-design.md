# Rust Market read-paths slice — design

Status: locked design for implementation. This document is the only
product of its branch; no Rust, fixture, or database change ships with
it. Builders and the integrator implement exactly what is written here
and treat deviations as design changes to be raised, not choices to
be made silently.

Base: `develop` at `122b84a` (conversion #561, Assets #562, step-up
#563, JWT #564, character detail #565 all merged). The retired Flutter
app at `ed698d3` is behavioral evidence only, read through git
history; no Dart file is restored.

## 1. What this slice is

A new read-only **Market** view showing, for **one selected item type
at a time**:

1. Public regional orders (buy and sell) for that type in one hub
   region, always fetched scoped by `type_id`, summarized as best
   sell, best buy, spread, order counts, remaining-volume sums, and
   the top orders on each side.
2. Public regional price history for that same type and region,
   summarized as the latest day plus a short recent-days list (no
   chart in this slice).
3. The active character's own open orders (all types, as ESI returns
   them), behind one additive step-up scope.

Everything is in-memory only. There is no database schema migration,
no persistence of market rows, no ESI write of any kind, and no order
placement. Public sections work with no character signed in and are
never blocked by a missing character scope.

### 1.1 Hard scope (verbatim constraints, binding on all builders)

- Read-only market slice only: public regional orders and history for
  ONE selected type at a time, always scoped by `type_id`, plus
  character open orders.
- NO ESI writes or order placement ever. No new `auth_post` call, no
  new POST except the existing read-only `resolve_ids` lookup.
- NO database schema migration; in-memory state only.
- NO widening `FIRST_AUTH_SCOPES` (`src/config.rs:33-39` stays
  byte-identical).
- NO calculator, valuation, or trade-profit features: no margin, no
  break-even, no price-times-volume totals, no percent spread.
- Volume and ISK-adjacent sums use saturating arithmetic.
- The interface shows resolved EVE names only: never a raw numeric
  ID in a rendered string or in error text. New errors are
  category-only, following the character-detail repair.
- Rust logging via `tracing` with bracketed tags: `[MARKET]` is new
  in this slice; `[ESI]`, `[AUTH]`, `[UI]`, `[DEMO]` already exist.
  Never log token values, authorization codes, state values, or
  authorize URLs.
- No push, no merge is part of this design task.

## 2. Evidence base (what was inspected, and what it forces)

Rust tree on `develop` at `122b84a`, each body read for this design
(full read unless a window is named):

- `src/config.rs` (199 lines). `FIRST_AUTH_SCOPES` at lines 33-39 has
  five scopes and no market or assets scope. `ASSETS_SCOPES` at
  line 64 is the single-scope step-up pattern; the test at lines
  150-154 asserts it is the single scope and absent from first-auth.
  `CHARACTER_DETAIL_SCOPES` (lines 69-75) plus the disjointness test
  at lines 156-178 is the second precedent. No market scope constant
  exists anywhere in the tree.
- `src/esi/client.rs` (753 lines; windows 140-399 read).
  `build_url` (lines 170-179) appends `datasource=tranquility` with
  `&` when the path already contains `?`, so query parameters such
  as `type_id` must be embedded in the path string; the precedent is
  `get_wallet_transactions_from` (`src/esi/endpoints.rs:143-146`)
  embedding `?from_id=` in its path. `public_get_page` (lines
  296-307) adds `page=` through the request query and returns
  `EsiMeta`; `send()` parses `x-pages` into `EsiMeta.pages` (lines
  256-265). `send()` strips the request URL from transport errors via
  `without_url()` (lines 247-253) and decode errors carry no path
  (lines 280-285): this is the single boundary that keeps numeric
  IDs out of error text the interface renders. `public_get`
  (line 290), `public_post` (line 309), `auth_get` (line 321),
  and `auth_get_page` (line 330) are the only seams new endpoints
  may use.
- `src/esi/endpoints.rs` (598 lines; read to line 500 plus the
  assets mock-server tests beyond). There is no market, orders, or
  history function. The only pagination walks are authenticated and
  uncapped: `get_wallet_journal` (lines 83-124) and `get_assets`
  (lines 189-227) loop `auth_get_page` until `page >= meta.pages`
  or an empty page. No public paged walk and no page-cap constant
  exist, so the capped regional-orders walk in section 5 is new
  code, not a copy. `resolve_ids` (lines 319-328) already exists:
  public `POST /universe/ids/`, flattened with categories including
  `inventory_type` (`src/esi/models.rs:310-341`), empty input
  short-circuits. `resolve_names` is at lines 310-316.
  `needs_reauthorize` (lines 402-407) is the typed 401/403 test.
- `src/esi/models.rs` (532 lines; read to line 500). Every struct is
  `#[derive(Debug, Clone, Default, Serialize, Deserialize)]` with
 `#[serde(default)]` on every field; `AssetItem` (lines 397-415) is
  the shape market models copy. No market struct exists.
  `UniverseName` is at lines 260-268.
- `src/error.rs` (191 lines). Error Displays are category-only since
  the character-detail repair: `EsiError::NoTokens(i64)` renders
  "[ESI] no stored tokens for this character" without the number
  (lines 25-28), pinned by the regression test at lines 184-190.
  HTTP 403 maps to `EsiError::Reauthorize` (lines 41-44).
- `src/app/state.rs` (763 lines; read to line 500). `View` has
  exactly six variants, keys 1-6, `ALL: [View; 6]` (lines 15-35),
  `label()` (lines 37-46), `from_index`/`index`/`next`/`previous`
  derived from `ALL` (lines 48-62). `LoadState<T>` is
  Loading/Ready/Empty/Error (lines 65-97) with Loading the default.
  `SectionError { message, needs_reauthorize }` and
  `SectionResult<T>` (lines 213-222) carry the typed scope outcome,
  never parsed from the message; `CharacterDetailData` (lines
  224-251) is seven independent section results with
  `needs_detail_stepup()`. `AppState` (lines 291-337) holds
  `assets` plus `assets_needs_reauthorize: bool` (lines 303-306),
  `character_details` (line 307), view-local search strings (lines
  314-327), and request flags views set for the integrator to drain
  (lines 329-336). `set_active_character` resets assets and
  character details to Loading only when the previous character
  differs (lines 376-398); `remove_character` does the same, clears
  a pending step-up for the removed character, and sets every
  per-view state to Empty when no characters remain (lines 425-459).
  `StepUpRequest::new(character_id, scopes)` is at lines 128-146.
- `src/app/shell.rs` (1535 lines; read 1-997 and 1080-1535).
  `BackendMsg` (lines 37-63) has one `Refreshed` bundle carrying a
  tolerant `assets: Result<...>` plus `assets_needs_reauthorize`
  and a `CharacterDetailData`. `drain_requests` guards `Refreshed`:
  the summary is inserted only if the character is still present
  (lines 484-511) and per-view states only when
  `active_character_id == character_id` (lines 512-520); the assets
  arm (lines 526-543) clears the reauthorize flag on Ok, replaces
  rows with Error on a scope refusal, and keeps Ready rows on other
  errors. `RefreshFailed` (lines 584-613) ignores inactive
  characters and otherwise sets Error only where not Ready.
  `start_refresh` (line 708) hard-fetches character, skills, and
  wallet with `?`, then assets (lines 742-791) and the seven detail
  sections (lines 792-859) as tolerant sub-fetches mapped to
  `SectionError { message: e.to_string(), needs_reauthorize:
  endpoints::needs_reauthorize(&e) }`. `schedule_name_resolution`
  (lines 366-463) collects wallet, assets, and detail IDs behind
  the `is_structure_id` guard, dedups through `resolver.missing()`,
  and resolves in chunks of 1000 into `BackendMsg::NamesResolved`.
  `start_stepup_login` (line 1089) is fully generic over
  `StepUpRequest.scopes`: granted-set pre-check, already-granted
  shortcut to refresh, scope union, JWT verification before claims,
  expected-character validation, removed-character save backstop.
  The `StepUpLoggedIn` arm (lines 625-645) deliberately does not
  clear reauthorize flags; only a successful fetch does. The
  startup view is persisted by **label string**, not number:
  read at lines 307-313 (`View::ALL.iter().find(|v| v.label() ==
  saved)`, unknown labels ignored) and written at lines 1414-1425.
  Keyboard view keys are the fixed array Num1-Num6 at lines
  1349-1356 feeding `View::from_index`; the rail heading says
  "Views (keys 1-6)" (line 1495), the status bar repeats it (line
  1531), and view dispatch is the exhaustive match at lines
  1512-1521.
- `src/ui/assets.rs` (401 lines). `show()` (line 197) is heading,
  mode notice, no-character panel, reauthorize early return, then a
  cloned-snapshot match on `LoadState` with
  `error_panel_with_retry` setting `retry_requested`. The
  reauthorize panel (lines 159-195) only sets
  `state.stepup_requested = StepUpRequest::new(active,
  EveConfig::ASSETS_SCOPES)`, enabled when `!demo && !auth.is_busy()
  && active.is_some()`. Pure helpers are unit-tested in-module:
  `group_assets` (line 64), `display_name` (line 38), and
  `total_quantity` folding `saturating_add` (lines 54-60) with the
  overflow test at lines 383-400. Rows carry resolved names only
  (lines 13-24) and tests assert no rendered name parses as an
  integer (lines 338-345).
- `src/ui/characters.rs` (755 lines; window 300-420 read).
  `section_error_label` (lines 328-336) renders a scope failure as
  "Not authorized yet…" without the message and other failures as
  "Could not load {section}: {message}". `standing_counts` (lines
  309-323) is saturating and excludes non-finite values.
  `detail_reauthorize_panel` (lines 341-381) repeats the Assets
  step-up pattern inside a multi-section bundle.
- `src/ui/mod.rs` (7 lines) declares seven modules; no market.
  `src/ui/widgets.rs` (grep-inspected): `format_isk` (lines 7-29)
  returns "0.00 ISK" for non-finite input, which is a guessed price
  if reused blindly for market rows; section 7.4 therefore locks a
  finite-check wrapper instead of calling it directly.
- `src/names/resolver.rs` (428 lines). `name()` falls back to
  "Unknown Item" (lines 130-139), `location_name()` to "Unknown
  Location" (lines 141-147), `cached()` and `category()` at lines
  109-120, `missing()` dedups, skips non-positive IDs and
  session-unresolved IDs (lines 149-164), `is_structure_id` is
  `id >= 1_000_000_000` (lines 29-35), `NAMES_BATCH_SIZE = 1000`
  (line 25). There is no region-specific fallback word; section 6.2
  handles that explicitly.
- `src/names/sde.rs` (grep-inspected `pub fn` inventory). The
  bundled SDE extract covers skills only: `skill_name`,
  `search_skills` (line 163), groups. There is no general item-type
  substring search in the Rust tree, which forces the type-selection
  design in section 6.1 (exact-name public lookup plus quick picks),
  not a Flutter-style typeahead.
- `src/demo/data.rs` (1166 lines; read 1-500 and 560-780). Fixture
  constants are `include_str!` (lines 25-31); `DemoCharacterData`
  (lines 82-92) gains each slice's data as a new slot; loaders chain
  backwards-compatibly — `load_demo_bundle_from` (line 175) chains
  with `"{}"`, `load_demo_bundle_with_assets` (line 186) chains
  with `"{}"`, `load_demo_bundle_with_detail` (line 202) is the
  current top, called by `load_demo_bundle` (lines 280-289).
  Per-character file entries parse in a key loop (lines 233-264).
  `validate_bundle` validates assets and detail only when present
  (lines 352-401). `apply_character` (line 575) installs Ready or
  Empty-if-absent (assets lines 622-630, detail lines 638-641) and
  resets `assets_needs_reauthorize = false`. Assets and character
  detail are in-memory only, never persisted (lines 752-753).
  `parse_esi_datetime` (line 440) is the shared date parser.
- Prior design documents `docs/assets-port-design.md` (927 lines)
  and `docs/character-detail-design.md` (1170 lines): headings and
  the character-detail opening were read; this document copies
  their structure (evidence, locked decisions, frozen contract,
  ownership, non-goals, test plan) and the prior slices'
  pre-authorized single-line shell dispatch exception for the UI
  builder.
- `README.md` (opening read): "What works today" lists keys 1-6 and
  roadmap "Market Tools: Price checking, trade tracking, profit
  analysis". The integrator updates both (section 11); profit
  analysis stays unimplemented and must keep reading as unshipped.
- `.github/workflows/ci.yml` (grep-inspected): the gates are
  `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
  `cargo test`, `cargo build`.

### 2.1 Retired Flutter evidence (git history at `ed698d3`)

The historical survey read all nine Flutter market files in full via
`git show ed698d3:<path>` (nothing restored). The facts that shape
this design:

- **Flutter never had a public regional order book.** Its market
  routes were only public `GET /markets/prices/`, public
  `GET /markets/{region_id}/history/?type_id=`, and authenticated
  `GET /characters/{id}/orders/` (`esi_client.dart:337-390` at
  `ed698d3`). There was no `GET /markets/{region_id}/orders/`, no
  best bid/ask, and no pagination handling for any market endpoint.
  The regional order book in this slice is therefore **new behavior
  required by the hard scope, not a faithful port**, and its paging
  and summary rules are designed fresh in sections 5 and 7.
- **`/markets/prices/` is deliberately excluded.** Flutter fetched
  and replaced the entire global price list on every sync
  (`market_sync_service.dart:58-84`); that endpoint has no `type_id`
  filter and cannot satisfy "one selected type at a time, always
  scoped by `type_id`".
- **Hub regions.** Flutter hardcoded exactly five trade-hub regions
  with The Forge default `kDefaultRegionId = 10000002`
  (`market_providers.dart:14-24`): The Forge, Domain, Sinq Laison,
  Metropolis, Heimatar. Section 6.2 locks the same five.
- **Character orders.** Scope `esi-markets.read_character_orders.v1`
  lived only in `phase5ExpansionScopes` (`eve_config.dart:100-112`),
  never in the first sign-in grant story; the panel listed orders
  newest-issued first with BUY/SELL badge, price, filled/total
  volume, and expiry (`active_orders_panel.dart:53-205`). Stored
  `locationId` and `regionId` were never resolved or rendered. This
  slice resolves and shows the location name (section 9) because
  the Rust name pipeline exists, and keeps region unrendered.
- **Defects that must not be copied** (each contradicts a Rust rule
  this design enforces): the detail screen rendered `Type ID:
  ${item.typeId}` verbatim (`market_browser_panel.dart:353-359`);
  a `Region $regionId` fallback (:411-412); an `Item
  #${order.typeId}` error branch (`active_orders_panel.dart:122-128`);
  raw exception text interpolated into the interface in four places;
  `filledVolume = volumeTotal - volumeRemain` as an unchecked
  subtraction (:68); a history cache whose "stale after 24 hours"
  comment was false — it synced only when empty and had no
  fetched-at column, so history was effectively never refreshed
  (`market_providers.dart:81-106`); `CharacterOrderData.fromJson`
  defaulting a missing `is_buy_order` to false, silently rendering
  the row as a sell order (`esi_client.dart:2046`).
- **Search.** Flutter searched a bundled SDE substring index plus an
  exact-name `POST /universe/ids/` merge
  (`market_providers.dart:118-153`). The Rust SDE extract has no
  item-type index (section 2), so only the exact-name public lookup
  half is portable in this slice.
- **Calculator.** `trade_calculator.dart` and its panel were read in
  full in the survey and are excluded by the hard scope: no margin,
  broker-fee, tax, or break-even math of any kind ships here.

### 2.2 Context-library specification evidence

The specification survey of the mimir context library (Flutter-era
specifications, no Rust behavior spec) confirms the endpoint/scope
table this design uses: regional orders and history public, no
scope; character orders under `esi-markets.read_character_orders.v1`;
the market-order provider split buy orders price-descending and sell
orders price-ascending; default region The Forge. Progressive scope
placement (ADR-007): the market scope is a feature group granted by
re-authorization on request, never part of the basic first-sign-in
set. Nothing in the library specifies one-type-at-a-time selection,
page caps, in-memory-only state, saturating sums, or fetch-identity
guards; those are Rust-era decisions locked below.

## 3. Decisions locked by this design

| # | Decision |
|---|----------|
| M1 | Market data is one in-memory `LoadState<MarketData>` bundle of three independent `SectionResult`s (public orders, history, character orders), mirroring `CharacterDetailData`. One section's failure degrades only that section. |
| M2 | Public regional orders are fetched only with `type_id` and `order_type=all` embedded in the path, through a capped `public_get_page` walk: `MARKET_MAX_PAGES = 10`. Fetching stops at `X-Pages`, an empty page, or the cap; hitting the cap while `X-Pages` says more exist sets a `truncated` flag the interface discloses in words. |
| M3 | Public history is one `public_get` with `type_id` in the path. Character open orders are an `auth_get_page` walk under the same page cap and truncated rule. |
| M4 | The character **order history** endpoint (`GET /characters/{id}/orders/history/`) is **out** (section 5.4 gives the reason). |
| M5 | Type selection is: an explicit exact-name lookup through the existing public `resolve_ids`, filtered to `category == "inventory_type"`, plus quick picks from types the user already holds. No substring typeahead (no Rust index exists). Unresolved or ambiguous outcomes are words, never numbers. |
| M6 | Regions are the five locked Flutter hub constants with The Forge default. Region display names come from the resolver (seeded in demo by `names.json`) with the curated constant name as the word fallback; a raw region ID is never rendered. |
| M7 | Summary math is pure functions in `src/ui/market.rs`: best sell is the minimum finite positive sell price, best buy the maximum finite positive buy price, spread exists only when both sides exist, counts and remaining-volume sums saturate, top 10 per side with invisible tie-breaks. No price-times-volume figure is computed anywhere. |
| M8 | Every market `BackendMsg` carries the full selection identity (type, region, character) plus a generation counter. The drain applies a result only when all four still match current state; anything else is dropped with a `[MARKET]` warning and never applied. |
| M9 | Step-up is one additive constant `MARKET_SCOPES = ["esi-markets.read_character_orders.v1"]`, copied from the `ASSETS_SCOPES` pattern, disjoint from first-auth. The re-authorize panel appears only inside the character-orders section, only on that section's typed scope failure. Public sections render regardless. `start_stepup_login` needs no change. |
| M10 | Character switch and removal reset market state exactly the way assets and character detail reset; selection, region, and search text survive a switch, loaded rows never do. |
| M11 | Market is a new `View::Market` inserted before Settings. Keys 1-5 are unchanged, Market is 6, Settings moves 6 to 7. Saved startup views survive because persistence is by label string, not number. |
| M12 | Name scheduling adds: the selected type ID, character-order type IDs, and structure-guarded location IDs from displayed orders. Order IDs are never scheduled, rendered, or used except as an invisible sort tie-break. |
| M13 | Demo market data is one additive fixture file behind a new backwards-compatible loader arity; every older loader keeps its meaning with a `"{}"` default. |

## 4. State: `MarketData` and the selection (Builder B)

### 4.1 Types, exact shape (`src/app/state.rs`)

Reusing the existing `SectionError`/`SectionResult`
(`src/app/state.rs:213-222`) unchanged:

```rust
/// What the user is looking at in Market, and under which character
/// context (None = public sections only). Also the identity stamped
/// on every market fetch/message: results that do not carry the
/// current selection are dropped, never applied. `type_name` is the
/// resolved name captured at selection time (words only; the numeric
/// ids here are state, never rendered).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MarketSelection {
    pub type_id: i64,
    pub type_name: String,
    pub region_id: i64,
    pub character_id: Option<i64>,
}

#[derive(Debug, Clone, Default)]
pub struct PublicOrdersData {
    pub orders: Vec<RegionalOrder>,
    pub truncated: bool,
}

#[derive(Debug, Clone, Default)]
pub struct CharacterOrdersData {
    pub orders: Vec<CharacterOrder>,
    pub truncated: bool,
}

/// Market bundle: three independent section results fetched for one
/// selection. Field set is a cross-builder contract (the shell and
/// demo seeding construct this literally); do not add fields here.
#[derive(Debug, Clone)]
pub struct MarketData {
    pub selection: MarketSelection,
    pub public_orders: SectionResult<PublicOrdersData>,
    pub history: SectionResult<Vec<MarketHistoryEntry>>,
    pub character_orders: SectionResult<CharacterOrdersData>,
}
```

`RegionalOrder`, `CharacterOrder`, and `MarketHistoryEntry` are
Builder A's models (section 5.1). Rules carried by the types:

- `character_orders` is the **only** section where a scope applies,
  so it is the only section whose `SectionError.needs_reauthorize`
  may ever be true. The shell constructs public-section errors with
  `needs_reauthorize: false` forced (section 8.2), whatever
  `endpoints::needs_reauthorize` says about a public failure.
- When `selection.character_id` is `None` the shell never calls the
  character endpoint and installs an empty
  `Ok(CharacterOrdersData::default())`. That empty Ok does not by
  itself encode "signed out": the view renders its no-character
  words from `selection.character_id.is_none()` **before** looking
  at the section (section 9.2), which keeps "signed out" visually
  distinct from "signed in, zero orders".
- `MarketData` has no top-level reauthorize boolean and no
  equivalent of `needs_detail_stepup()`: the view reads the one
  section's typed flag directly. A separate
  `market_needs_reauthorize` AppState flag (the Assets pattern) is
  rejected because Market must keep rendering its public sections
  around the panel, where Assets returns early.

### 4.2 New `AppState` fields

Selection lives outside `LoadState<MarketData>` so it survives a
failed fetch (the user keeps their item and region while retrying):

```rust
pub market: LoadState<MarketData>,
// View-local market UI state:
pub market_search: String,
pub market_selected_type_id: Option<i64>,
pub market_selected_type_name: Option<String>,
pub market_region_id: i64,           // DEFAULT_MARKET_REGION_ID, section 6.2
pub market_candidates: Vec<UniverseName>,
pub market_lookup_message: Option<String>,
pub market_generation: u64,           // fetch identity, section 8
// Request flags for the integrator to drain:
pub market_fetch_requested: bool,
pub market_lookup_requested: Option<String>,
```

Defaults: empty search, no selected type (so the view opens on the
picker, section 9.1), The Forge region, empty candidates, no lookup
message, generation 0, no requests pending. The Forge default needs
one explicit line: `AppState` derives `Default` and `AppState::new`
spreads `..Self::default()`, which would leave `market_region_id`
at 0 — a region outside the locked set. Builder B therefore sets
`market_region_id: DEFAULT_MARKET_REGION_ID` explicitly in
`AppState::new` (every construction site in the tree goes through
`new`), and a state test asserts both `AppState::new(false)` and
`AppState::new(true)` start on The Forge. `market` starts as
`LoadState::Loading` per the type's default, but the view renders
the picker branch first whenever no type is selected, so the
initial Loading is never shown as a spinner.

### 4.3 Selection helpers and lifecycle resets

Two helpers on `AppState` own every identity change; views and the
shell call these, never raw field writes to the selection:

- `set_market_selection(&mut self, type_id: i64, type_name: String)`:
  when the type differs from the current one, sets selected
  type/name, clears `market_candidates` and
  `market_lookup_message`, sets `market = LoadState::Loading`,
  bumps `market_generation` with `wrapping_add(1)`, sets
  `market_fetch_requested = true`, and logs `[MARKET]` at info with
  the type **name** only. Reselecting the same type just sets
  `market_fetch_requested = true` (a refetch) without discarding
  the loaded bundle — except it still bumps the generation, so the
  older of two racing refetches is dropped. Empty or
  whitespace-only `type_name` is stored as the resolver word
  fallback "Unknown Item"; a name is never a numeric string.
- `set_market_region(&mut self, region_id: i64)`: ignores a region
  outside the locked hub set (logs `[MARKET]` warning, no state
  change). On an accepted change: sets the region, and when a type
  is selected sets `market = LoadState::Loading`, bumps the
  generation, and sets `market_fetch_requested = true`. With no
  type selected it still bumps the generation so any in-flight
  result for the old pairing dies.

Switch/removal resets mirror assets and character detail
(`src/app/state.rs:376-398`, `:425-459`):

- `set_active_character`, when `previous_id != character_id`: in
  addition to the existing resets, set `market` to
  `LoadState::Loading` when a type is selected, else leave it,
  clear `market_candidates` and `market_lookup_message`, bump
  `market_generation`, and log `[MARKET] clearing market on
  character switch`. Selection, region, and `market_search`
  survive: the public book is character-independent and the user
  asked about the same item, but loaded rows (including the
  previous character's own orders) must never render under the new
  character. Same-character reselect changes nothing, exactly as
  assets keep loaded rows.
- `remove_character`: when the removed character was active, the
  same market reset as a switch (placed with the existing
  assets/detail resets, before the replacement `set_active_character`
  call whose previous-is-None path cannot detect it). A pending
  step-up for the removed character is already cleared by existing
  code; market adds nothing there. In the `characters.is_empty()`
  branch, add `market = LoadState::Empty` alongside the existing
  Empty assignments. Bump the generation in both paths so a removed
  character's in-flight character-orders result can never land.
  Note (accepted consequence): after removing the last character
  the public sections do not auto-refetch even though they could;
  the user presses Retry or reselects, which refetches with
  `character_id: None`. Mirroring assets exactly was chosen over a
  market-only special case.
- Demo switching goes through `apply_character` (section 10.3),
  which installs the fixture bundle or Empty; it never consults the
  generation because nothing is in flight in demo mode.

## 5. ESI endpoints and typed models (Builder A)

### 5.1 Models to add in `src/esi/models.rs`

Same derive and `#[serde(default)]`-on-every-field pattern as
`AssetItem` (`src/esi/models.rs:397-415`). Field names are the ESI
JSON names, so demo fixtures (section 10) use ESI spelling too.

```rust
/// One public regional order from `GET /markets/{region_id}/orders/`.
/// `order_id` is an invisible sort tie-break only: never rendered,
/// never name-resolved, never logged per-row.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RegionalOrder {
    #[serde(default)] pub order_id: i64,
    #[serde(default)] pub type_id: i64,
    #[serde(default)] pub location_id: i64,
    #[serde(default)] pub system_id: i64,
    #[serde(default)] pub price: f64,
    #[serde(default)] pub volume_remain: i64,
    #[serde(default)] pub volume_total: i64,
    #[serde(default)] pub min_volume: i64,
    #[serde(default)] pub is_buy_order: bool,
    #[serde(default)] pub issued: String,
    #[serde(default)] pub duration: i64,
    #[serde(default)] pub range: String,
}

/// One of a character's own open orders from
/// `GET /characters/{character_id}/orders/`. `region_id` parses and
/// is carried, but is never rendered or scheduled for naming.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterOrder {
    #[serde(default)] pub order_id: i64,
    #[serde(default)] pub type_id: i64,
    #[serde(default)] pub region_id: i64,
    #[serde(default)] pub location_id: i64,
    #[serde(default)] pub price: f64,
    #[serde(default)] pub volume_remain: i64,
    #[serde(default)] pub volume_total: i64,
    #[serde(default)] pub min_volume: i64,
    #[serde(default)] pub is_buy_order: bool,
    #[serde(default)] pub issued: String,
    #[serde(default)] pub duration: i64,
    #[serde(default)] pub range: String,
    #[serde(default)] pub is_corporation: bool,
    #[serde(default)] pub escrow: Option<f64>,
}

/// One day of `GET /markets/{region_id}/history/`. Volume and
/// order-count sums over these rows saturate (section 7.3).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MarketHistoryEntry {
    #[serde(default)] pub date: String,
    #[serde(default)] pub average: f64,
    #[serde(default)] pub highest: f64,
    #[serde(default)] pub lowest: f64,
    #[serde(default)] pub order_count: i64,
    #[serde(default)] pub volume: i64,
}
```

Defaults are the tree-wide tolerance pattern, with one recorded
consequence: a row missing `is_buy_order` decodes as a sell order
(the Flutter defect). Rust cannot distinguish an absent field from
a false one under this pattern, and diverging for one struct was
rejected; live ESI always sends the field. Rows that are unusable
for math are filtered by the pure summaries (section 7), never by
partial-parse failure: one malformed value must not fail a whole
page the way Flutter's strict casts did.

### 5.2 Endpoints to add in `src/esi/endpoints.rs`

```rust
/// Hard cap for market page walks. Regional orders for one type and
/// one character's open orders are bounded populations; the cap is a
/// runaway guard, and hitting it is always disclosed via the
/// returned truncated flag rather than silent partial data.
pub const MARKET_MAX_PAGES: u32 = 10;

pub async fn get_regional_orders(
    client: &EsiClient,
    region_id: i64,
    type_id: i64,
) -> AppResult<(Vec<RegionalOrder>, bool)>;

pub async fn get_market_history(
    client: &EsiClient,
    region_id: i64,
    type_id: i64,
) -> AppResult<Vec<MarketHistoryEntry>>;

pub async fn get_character_orders(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<(Vec<CharacterOrder>, bool)>;
```

Locked construction details:

- `get_regional_orders`: path is exactly
  `format!("/markets/{region_id}/orders/?type_id={type_id}&order_type=all")`.
  `type_id` is a required function argument embedded in the path;
  there is no overload, default, or code path that requests a
  region's orders without a type. `order_type=all` is sent
  explicitly so both sides arrive in one walk and one summary,
  rather than depending on a server default or doubling the page
  budget with separate buy and sell walks. Pages go through
  `public_get_page(path, page)`; `build_url` already handles the
  embedded `?` (section 2).
- `get_market_history`: path is exactly
  `format!("/markets/{region_id}/history/?type_id={type_id}")`
  through one `public_get`. No pagination, no cap: history is one
  array of days. Rows return unsorted; section 7.3 sorts.
- `get_character_orders`: path is exactly
  `format!("/characters/{character_id}/orders/")` through an
  `auth_get_page` walk shaped like `get_assets` but capped. Open
  orders only; that is what this route returns. A missing scope
  surfaces as HTTP 403 → `EsiError::Reauthorize` →
  `endpoints::needs_reauthorize`, identical to assets. Any page
  error, including a mid-walk cap-side failure, propagates;
  partial page lists are never returned as success (the
  `get_assets` rule).
- Both walks delegate to private helpers taking an explicit
  `max_pages: u32` parameter; the public functions pass
  `MARKET_MAX_PAGES`. The parameter exists so unit tests can prove
  cap behavior with a page budget of 2 or 3 instead of staging ten
  responses. Walk order within a page and across pages is
  preserved (extend in fetch order); all ordering for display is
  section 7's job.
- Stop and truncation rule (identical for both walks): stop when
  `meta.pages` is `Some(total)` and `page >= total`, or when
  `meta.pages` is `None` and the page is empty, or when
  `page >= max_pages`. `truncated` is true only when the walk
  stopped at the cap while `meta.pages` said more pages exist
  (`Some(total)` with `total > page`). When `meta.pages` is `None`
  and a non-empty page lands exactly on the cap, `truncated` is
  also true: the walk cannot prove it saw the end. Every other
  stop is `truncated: false`.
- There is no whole-region recentering, condensing, or
  summary-building in the endpoint functions. They return raw rows
  plus the truncated flag; all derived values come from the pure,
  tested functions in section 7. (The reason: summary math built
  inside a fetch path changes what the raw rows can express — the
  view also renders top-order rows from the same raw data, so
  aggregation must not consume or re-key the row list upstream.)
- Logging: every function logs `[MARKET]` — the route at debug,
  per-page row counts at debug, and one info line with totals and
  `truncated` at completion. Numeric region/type/character IDs in
  these log lines follow the existing `[ASSETS]` convention and
  are log-only; order IDs are never logged per row. No new error
  text is constructed here: client errors propagate untouched so
  the sanitized Display boundary in `send()` stays the only one
  (section 2).

### 5.3 Scope constant in `src/config.rs`

Builder A adds, immediately after `ASSETS_SCOPES` (line 64):

```rust
/// Market step-up scopes: read the character's own open orders.
/// Granted after first sign-in via step-up, never at first auth.
/// Public regional orders and history need no scope at all.
pub const MARKET_SCOPES: &[&str] = &["esi-markets.read_character_orders.v1"];
```

plus a test copying `assets_scopes_is_the_single_stepup_scope`
(lines 150-154): the constant equals the single scope and
`FIRST_AUTH_SCOPES` does not contain it. Nothing else in
`src/config.rs` changes; `FIRST_AUTH_SCOPES` is byte-identical.

### 5.4 Order history endpoint: out, with reason

`GET /characters/{id}/orders/history/` (closed and expired orders)
is **not** in this slice. The hard scope names "character open
orders" only; closed-order history is a second paginated surface
with its own `state` vocabulary (filled, cancelled, expired) and
its own display questions, and Flutter never called it either (the
survey found only the open-orders route). It adds no scope, so a
later slice can add it additively behind the same constant. A
grep gate in the test plan (section 13) keeps the route out of
this slice's diff.

## 6. Type selection and regions

### 6.1 Choosing the one type

Three inputs, in the Market view's picker (section 9.1):

1. **Exact-name lookup.** A text box bound to `market_search` plus
   an explicit "Look up item" button (Enter submits the same way).
   Submitting trims the text; empty-after-trim is a no-op. A
   non-empty submit sets `market_lookup_requested =
   Some(trimmed.to_string())`, clears `market_candidates`, sets
   `market_lookup_message = Some("Looking up that item name…")`,
   and bumps `market_generation` (the lookup shares the fetch
   generation so an interleaved selection or region change kills a
   late lookup answer too). The shell (section 8.3) calls the
   existing public `endpoints::resolve_ids` with the single name,
   filters to `category == "inventory_type"`, and answers with a
   generation-stamped message. Outcomes in the view:
   - exactly one inventory type: it is selected immediately via
     `set_market_selection` (which starts the fetch);
   - more than one: they are listed in `market_candidates` sorted
     by name (case-insensitive, then name, then ID as an invisible
     tie-break), each a clickable row showing the returned name
     only; clicking selects it;
   - none, or the lookup failed: `market_lookup_message` becomes
     one fixed worded line — "No item with that exact name was
     found. Check the spelling, or pick an item you hold below."
     for an empty result, "Item name lookup failed. Check the
     connection and try again." for an error. The submitted text is
     **not** echoed back inside either sentence (Flutter's
     `No items found for "$query"` is not copied; the text box
     itself still shows what the user typed).
   Candidate and selected names come from the lookup response
   itself, so they are already resolved words; an empty name in a
   response row is shown as the resolver fallback "Unknown Item",
   never as its number.
2. **Quick picks.** A pure helper `quick_pick_types(state,
   resolver) -> Vec<(i64, String)>` in `src/ui/market.rs` collects
   types already loaded in memory, in this priority: distinct
   `type_id`s from `state.assets` items (when Ready), then distinct
   `type_id`s from `state.wallet` transactions (when Ready) not
   already collected. Each is labeled with `resolver.name(type_id)`
   (the word fallback while resolution is in flight). The list is
   sorted by label (case-insensitive, then label, then ID
   invisible), deduplicated, and capped at 12 rows so the picker
   stays compact, logging `[MARKET]` debug with the offered count.
   In demo mode the same helper reads the demo assets and demo
   wallet the existing loader installed, so demo quick picks are
   the demo types with no extra fixture plumbing. Clicking a quick
   pick calls `set_market_selection` directly. When neither assets
   nor wallet are Ready the quick-pick block is replaced by one
   line: "Sign in
   and load Assets or Wallet to pick from items you hold, or look
   an item up by name above." There are no hardcoded sample items
   and no hidden default selection: the view fetches nothing until
   the user chooses a type.
3. **Keep it honest about coverage.** Under the lookup box, one
   static line: "Name lookup needs the item's exact EVE name."
   That is the real constraint of `POST /universe/ids/` without a
   local type index; pretending a substring search exists would be
   a fake capability.

### 6.2 The locked region set

In `src/app/state.rs` (Builder B), next to the market types:

```rust
/// One selectable market region. `name` is the curated display
/// fallback (Flutter `kTradeHubRegions` parity); a resolver hit for
/// `id` wins in the view. The numeric id is never rendered.
pub struct MarketRegion {
    pub id: i64,
    pub name: &'static str,
}

pub const MARKET_REGIONS: [MarketRegion; 5] = [
    MarketRegion { id: 10000002, name: "The Forge (Jita)" },
    MarketRegion { id: 10000043, name: "Domain (Amarr)" },
    MarketRegion { id: 10000032, name: "Sinq Laison (Dodixie)" },
    MarketRegion { id: 10000042, name: "Metropolis (Hek)" },
    MarketRegion { id: 10000030, name: "Heimatar (Rens)" },
];

pub const DEFAULT_MARKET_REGION_ID: i64 = 10000002; // The Forge

pub fn market_region_name(region_id: i64) -> Option<&'static str> {
    MARKET_REGIONS.iter().find(|r| r.id == region_id).map(|r| r.name)
}
```

- The five IDs and The Forge default match Flutter exactly
  (section 2.1). Adding a region later is one constant entry plus
  one `names.json` demo row; `set_market_region` rejects anything
  outside the set (section 4.3), so no free-form region input
  exists.
- Display rule (single helper in the view,
  `region_label(region_id, resolver) -> String`):
  `resolver.cached(region_id)` when present, else
  `market_region_name(region_id)`, else the resolver location word
  "Unknown Location". `resolver.name()` ("Unknown Item") is never
  used for a region — a region is not an item — and
  `resolver.location_name()` alone was rejected because live mode
  does not schedule hub region IDs for resolution in this slice
  (section 8.4 locks what is scheduled), so it would always say
  "Unknown Location" for regions whose names are known constants.
  Pure-region results never degrade to Flutter's `Region $regionId`
  because every selectable ID is in the constant table.
- Demo mode additionally seeds the five regions into the demo
  resolver through `assets/demo/names.json` (Builder A fixture
  rows, section 10.1), so demo exercises the resolver-hit branch.
- The region affects the two public fetches only. Character open
  orders are region-independent (as in Flutter); changing region
  still refetches the whole bundle because one fetch produces one
  identity-stamped bundle (section 8.1) — simpler than mixing two
  fetch clocks, and the character walk is capped and small.

## 7. Pure summary math (`src/ui/market.rs`, Builder B)

All derived numbers come from pure functions in the new UI module,
unit-tested in-module the way `group_assets` is
(`src/ui/assets.rs:263-401`). No function here touches `AppState`,
a resolver, or the network except the two label helpers noted.

### 7.1 Order-book summary

```rust
pub const MARKET_TOP_N: usize = 10;

#[derive(Debug, Clone, Default, PartialEq)]
pub struct OrderBookSummary {
    pub best_sell: Option<f64>,
    pub best_buy: Option<f64>,
    pub spread: Option<f64>,       // Some only when both sides exist
    pub sell_order_count: usize,
    pub buy_order_count: usize,
    pub sell_volume_remain: i64,    // saturating sum
    pub buy_volume_remain: i64,     // saturating sum
    pub top_sells: Vec<RegionalOrder>, // price ascending, len <= MARKET_TOP_N
    pub top_buys: Vec<RegionalOrder>,  // price descending, len <= MARKET_TOP_N
    pub skipped_invalid: usize,
}

pub fn summarize_orders(orders: &[RegionalOrder]) -> OrderBookSummary;
```

Locked rules:

- **Validity filter first.** An order participates only when
  `price.is_finite() && price > 0.0`. Other rows increment
  `skipped_invalid`, are excluded from every figure and both top
  lists, and produce one `[MARKET]` debug count from the caller
  when non-zero (not per-row). Prices decode from remote JSON with
  no range validation; a NaN must never be able to become a best
  price (NaN comparisons would corrupt both `min`/`max` and
  sorting).
- **Side split** on `is_buy_order`. Counts are plain `usize` counts
  of participating rows.
- **Best prices**: `best_sell` is the minimum participating sell
  price, `best_buy` the maximum participating buy price, each
  `None` when its side is empty. Comparison uses
  `f64::total_cmp`, which is total once non-finite values are
  filtered.
- **Spread** is `Some(best_sell - best_buy)` only when both are
  `Some`; otherwise `None`. The value is shown as-is, including
  negative for a crossed book — it is a price difference, with no
  profitability reading attached. No percentage spread is computed.
- **Volume sums** fold `volume_remain.max(0)` per row with
  `saturating_add`, copying the `total_quantity` discipline
  (`src/ui/assets.rs:54-60`). Negative remaining volume from a
  malformed row contributes zero, never a subtraction.
- **Top-N ordering**: sells sort by price ascending, buys by price
  descending. Tie-breaks, in order and all invisible (no tie-break
  field is ever rendered): `volume_remain` descending, `issued`
  ascending as ISO-8601 strings (lexicographic order is
  chronological for ESI timestamps), `order_id` ascending. The
  tie-break chain is identical on both sides; only the price
  direction differs. Lists truncate to `MARKET_TOP_N` after
  sorting. Sorting is stable and total: two rows equal on every
  key are indistinguishable in every rendered field.
- Summary figures always describe the rows actually fetched. When
  `PublicOrdersData.truncated` is set the view discloses it
  (section 9.2); summaries never pretend to cover pages beyond the
  cap, because an unfetched page could hold a better price.

### 7.2 Character-order rows

```rust
#[derive(Debug, Clone, Default, PartialEq)]
pub struct CharacterOrderRow {
    pub order_id: i64,          // invisible tie-break only
    pub type_id: i64,           // resolved to a name by the caller
    pub location_id: i64,       // resolved to a name by the caller
    pub is_buy_order: bool,
    pub price: f64,
    pub filled: i64,
    pub volume_remain: i64,
    pub volume_total: i64,
    pub issued: String,
    pub duration_days: i64,
    pub escrow: Option<f64>,
    pub matches_selected_type: bool,
}

pub fn character_order_rows(
    orders: &[CharacterOrder],
    selected_type_id: i64,
) -> Vec<CharacterOrderRow>;
pub fn filled_volume(volume_total: i64, volume_remain: i64) -> i64;
pub fn filled_fraction(volume_total: i64, volume_remain: i64) -> Option<f64>;
```

- Rows sort `issued` descending (Flutter's order), tie-break
  `order_id` descending (newest-issued first and, within one
  timestamp, the later-placed order first; still invisible).
- `filled_volume` is `volume_total.saturating_sub(volume_remain).max(0)`:
  Flutter's unchecked subtraction (:68 at `ed698d3`) becomes
  saturating, and a remain greater than total reports zero filled,
  not a negative count.
- `filled_fraction` is `None` when `volume_total <= 0`; otherwise
  the filled/total ratio clamped to `0.0..=1.0`, `None` again if
  the ratio is non-finite (both operands are integers so this is
  belt-and-braces, locked anyway).
- **No ISK figure is derived from these rows.** Per-row price is
  display of a fetched field; escrow is displayed per row only
  when `Some` and finite. There is no total escrow, no ISK
  remaining figure, no price-times-volume column: those are valuation,
  excluded by hard scope. f64 multiplication cannot saturate, and
  the hard scope's saturating rule is satisfied by the integer
  volume sums that do exist (sections 7.1, 7.3).
- `matches_selected_type` flags rows whose `type_id` equals the
  selected type so the view can mark the user's own orders for the
  item on screen. All of the character's open orders are listed
  regardless (the endpoint has no type filter; inventing one
  client-side would hide orders the user placed).

### 7.3 History summary

```rust
pub const MARKET_HISTORY_ROWS: usize = 30;

#[derive(Debug, Clone, Default, PartialEq)]
pub struct HistorySummary {
    pub days_returned: usize,
    pub latest: Option<MarketHistoryEntry>,
    pub recent: Vec<MarketHistoryEntry>,   // date descending, len <= 30
    pub recent_total_volume: i64,          // saturating, over `recent` only
    pub recent_total_orders: i64,          // saturating, over `recent` only
}

pub fn summarize_history(entries: &[MarketHistoryEntry]) -> HistorySummary;
```

- Sort by `date` descending as ISO date strings; duplicate dates
  keep input order between themselves (stable sort). `latest` is
  the first after sorting, `None` for empty input. `recent` is the
  first `MARKET_HISTORY_ROWS`.
- Totals fold `volume.max(0)` and `order_count.max(0)` with
  `saturating_add` over `recent` only, and the view labels them as
  covering the shown days, never the whole returned history.
- There is **no chart** in this slice. Flutter's 60-entry chart
  carried two defects (a "30-day" doc over 60 entries; an invisible
  high/low range band) and egui charting is a design of its own.
  The view renders the latest day as labeled figures and the
  recent days as text rows (section 9.2).
- No average-of-averages, moving average, or trend figure is
  computed: readers get ESI's daily averages as returned.

### 7.4 Label helpers

```rust
pub fn price_label(price: f64) -> String;
pub fn region_label(region_id: i64, resolver: &NameResolver) -> String;
```

- `price_label` returns `widgets::format_isk(price)` when
  `price.is_finite()`, else the words "not available". It never
  calls `format_isk` with a non-finite value, because that helper
  renders "0.00 ISK" (`src/ui/widgets.rs:7-29`), which for a market
  price is a false quote. Optional prices (`best_sell: None`)
  render "no sell orders" / "no buy orders" in the view, not via
  this helper. Prices are values, not IDs, and are the subject of
  the view; every other rendered identifier goes through the
  resolver.
- `region_label` implements section 6.2's resolver-then-constant
  rule.

## 8. Shell fetch wiring and fetch identity (integrator)

Market fetching is its **own** shell path, separate from
`start_refresh`. Reasons: market fetches are keyed by a
user-changing selection rather than only by character, they must
run with no character at all, and folding them into `Refreshed`
would force a market refetch on every Ctrl+R of unrelated views.
`start_refresh` and the `Refreshed` arm are untouched by this
slice except the two trigger notes in section 8.5.

### 8.1 Messages

Two new `BackendMsg` variants (`src/app/shell.rs`, beside the enum
at lines 37-63):

```rust
MarketFetched {
    generation: u64,
    data: Box<MarketData>,          // data.selection is the identity
},
MarketLookupDone {
    generation: u64,
    query: String,                   // the trimmed submitted name
    result: Result<Vec<UniverseName>, String>, // inventory types only
}
```

Every market message therefore carries the type, region, and
character identity (`MarketData.selection`) plus the generation, or
for a lookup the query plus generation. The `Err(String)` in
`MarketLookupDone` is the client-sanitized `e.to_string()` and is
used only in a `[MARKET]` warning log; the view gets the fixed
worded line from section 6.1, never this string.
`MarketFetched` has no separate failure twin: all three fetches are
tolerant section results inside the bundle, so a fetch task always
answers. A task that cannot even start (no backends/runtime)
cannot happen silently — `start_market_fetch` checks before
spawning and writes the failure state itself (section 8.2).

### 8.2 `start_market_fetch`

Drained from `market_fetch_requested` in `drain_requests` (beside
the refresh block at lines 666-670). On entry it clears the flag;
in demo mode it re-applies the current demo character (the
`start_refresh` pattern, lines 709-716) and returns. In live mode
it requires
`market_selected_type_id` to be `Some` — otherwise it logs a
`[MARKET]` debug and does nothing (no selection, no fetch, ever).
It snapshots the identity before spawning:

```rust
let selection = MarketSelection {
    type_id,
    type_name: state.market_selected_type_name.clone()
        .unwrap_or_else(|| "Unknown Item".to_string()),
    region_id: state.market_region_id,
    character_id: state.active_character_id,
};
let generation = state.market_generation;
```

If backends or the runtime are missing (scaffold/test shells), it
sets `state.market = LoadState::Error("Market data unavailable: live
backends not wired.".to_string())` — a fixed literal with no ID in
it — and returns. Otherwise it spawns one task that performs three
tolerant fetches, each mapped the character-detail way
(`src/app/shell.rs:795-850`):

- `public_orders`: `get_regional_orders(&esi, region_id, type_id)`,
  `Ok` → `PublicOrdersData { orders, truncated }`; `Err(e)` →
  `SectionError { message: e.to_string(), needs_reauthorize: false }`
  — forced false, logging `[MARKET]` warning with the section name.
- `history`: `get_market_history(...)`, same forced-false mapping.
- `character_orders`: only when `selection.character_id` is
  `Some(id)`: `get_character_orders(&esi, id)`, mapped with
  `needs_reauthorize: endpoints::needs_reauthorize(&e)` (the one
  real typed scope outcome). When `None`: `Ok(CharacterOrdersData::default())`
  without a call.

The task sends `MarketFetched { generation, data }` and logs one
`[MARKET]` info line with per-section row counts and truncated
flags. Nothing is persisted: no repository call appears in this
task, matching the in-memory-only rule (contrast `start_refresh`'s
explicit persistence block, lines 880-987, which market does not
join).

**The `MarketFetched` arm** applies the bundle only when **all**
of these hold, in this order:

1. `generation == state.market_generation`, and
2. `data.selection.type_id == state.market_selected_type_id` (as
   `Some`), and
3. `data.selection.region_id == state.market_region_id`, and
4. `data.selection.character_id == state.active_character_id`.

Any mismatch logs one `[MARKET]` warning "dropping market result
for a superseded selection" and discards the message: stale
results for a previous selection or character are dropped, never
applied, and never partially merged. On a match it installs
`state.market = LoadState::Ready(*data)` and calls
`schedule_name_resolution()` so the section 8.4 IDs resolve.

### 8.3 `start_market_lookup`

Drained from `market_lookup_requested.take()`. In demo mode it
never reaches the network: it answers synchronously by
case-insensitive exact match of the trimmed query against
`quick_pick_types` labels, feeding the same
selection/candidates/message logic as a live lookup (so the demo
exercises the real view code paths offline). In live mode with
backends missing it writes the fixed lookup-failure line into
`market_lookup_message`. Otherwise it snapshots `(query,
generation)` and spawns `endpoints::resolve_ids(&esi, &[query])`,
filters to `category == "inventory_type"` and `id > 0`, sorts by
name (case-insensitive, name, ID), and sends `MarketLookupDone`.

**The `MarketLookupDone` arm** drops the message unless
`generation == state.market_generation` **and** `query` equals the
current trimmed `state.market_search` (a lookup the user already
edited away from is stale even if nothing bumped the generation).
On a match: `Err(_)` → the fixed failure line; empty `Ok` → the
fixed not-found line; one candidate → `set_market_selection(id,
name)`; several → `market_candidates` set, lookup message cleared.
It never writes `state.market` directly.

### 8.4 Name scheduling additions

One new block in `schedule_name_resolution`
(`src/app/shell.rs:366-463`), after the character-detail block,
reading `state.market` when Ready plus the selection fields:

- the selected type ID (`market_selected_type_id`, even before the
  first bundle lands, so the heading resolves early);
- from `public_orders` when Ok: each **displayed** top order's
  `location_id`, only when `!is_structure_id(location_id)`.
  "Displayed" means the top-N after section 7.1 sorting, not every
  fetched row: scheduling thousands of station IDs to name ten
  rows would burn the name-resolution budget. The integrator calls
  `summarize_orders` here only to learn the top-N locations — or,
  equivalently, the view's identical recomputation is accepted,
  since `schedule_name_resolution` runs post-fetch and the pure
  function is deterministic;
- from `character_orders` when Ok: every row's `type_id`, and every
  row's `location_id` behind the same structure guard.

Structure-class locations stay "Unknown Location" through the
resolver fallback, exactly like assets and clones today; the
authenticated structure endpoint is not called from market code.
Hub region IDs are **not** scheduled (section 6.2's constant
fallback covers them), character-order `region_id`s are not
scheduled (never rendered), `system_id`s on regional orders are
not scheduled (carried, unrendered), and **`order_id` is never
scheduled from any list**. Everything flows through the existing
`resolver.missing()` dedup and 1000-chunk send, and
`NamesResolved` needs no market arm: market rows derive labels
from the resolver at render time, unlike character-detail
summaries which were frozen strings.

### 8.5 Triggers besides the view

- **Character switch**: the existing `last_active_id` block in
  `drain_requests` (lines 653-665) already calls
  `request_refresh("character-switch")` in live mode; the
  integrator adds, in the same non-demo branch, "if a market type
  is selected, set `market_fetch_requested = true`" so the reset
  bundle from section 4.3 refills under the new character.
- **Step-up completion**: the `StepUpLoggedIn` arm (lines 625-645)
  already requests a refresh when the step-up character is active;
  the integrator adds the same market-fetch flag next to it when a
  type is selected. Following that arm's locked rule, nothing about
  the market bundle is cleared or pre-cleared there: the
  re-authorize panel disappears only when a later market fetch
  returns a character-orders Ok.
- **General refresh (Ctrl+R, Retry in other views)** does **not**
  refetch market data. Market has its own Retry (section 9). This
  is a deliberate divergence, recorded so a later "stale market"
  report is read against the design, not as a defect: market data
  refreshes on selection change, region change, character switch,
  step-up completion, and the Market view's own Refresh/Retry.

## 9. The Market view (`src/ui/market.rs`, Builder B)

`show(ui, state, resolver)` follows the Assets skeleton
(`src/ui/assets.rs:197-261`) with two locked divergences: it does
**not** early-return when there is no active character (public
sections are the point of the view), and it does **not**
early-return on the re-authorize condition (the panel lives inside
one section). Render order:

1. `ui.heading("Market")` and `widgets::mode_notice`.
2. The picker block (section 9.1) — always rendered.
3. No selected type: one guidance line ("Choose an item to load
   public market data. Your own open orders appear here too once an
   item is chosen.") and stop. Nothing has been fetched; the line
   says so honestly instead of showing empty tables.
4. Selected type: the item heading and region line, then the three
   sections from a cloned `LoadState<MarketData>` snapshot (the
   Assets clone pattern), with a "Refresh market data" button that
   sets `market_fetch_requested = true` (enabled whenever a type
   is selected, demo included: in demo it re-applies the fixture).

`LoadState` handling per state: Loading →
`widgets::loading_panel(ui, "Loading market data...")`; Empty →
`widgets::empty_panel(ui, "No market data yet.")`; Error (the
no-backends literal from section 8.2) →
`error_panel_with_retry`, whose retry sets
`market_fetch_requested = true`, **not** the global
`retry_requested` (that flag drives `start_refresh`, which knows
nothing about market). Ready → the sections in 9.2. A Ready bundle
whose `selection` does not match the current selected type, region,
or active character cannot occur (the section 8.2 drain guard plus
the selection helpers reset to Loading), so the view does not
defend against it a second time.

### 9.1 Picker

- Lookup row: a local `ui.text_edit_singleline(&mut
  state.market_search)` — not `widgets::search_box`, which returns
  only focus state (`src/ui/widgets.rs:183-195`) and cannot report
  an Enter submit — with hint label "Item name, exactly as in EVE
  (then Look up)" while empty, the `/` focus plumbing copied from
  Assets (`state.focus_search`, `state.text_input_focused |=
  response.has_focus()`), and a "Look up item" button. Button
  click, or `response.lost_focus()` while Enter is pressed,
  performs the section 6.1 submit. While `market_lookup_message` is the
  "Looking up…" line the button shows a spinner beside it; the
  message text under the row is whatever
  `market_lookup_message` holds.
- Candidates: when `market_candidates` is non-empty, one
  `selectable_label` per candidate showing its name; clicking sets
  the selection. Candidates render above quick picks (they answer
  the action the user just took).
- Quick picks: heading "Items you hold" and one button per
  `quick_pick_types` entry, label only. The currently selected
  entry renders selected. Empty quick picks render the worded
  fallback sentence from section 6.1.
- Region row: heading "Region" and one `selectable_label` per
  `MARKET_REGIONS` entry labeled by `region_label`, the current
  region selected; clicking calls `set_market_region`. No dropdown
  of unknown regions exists.
- Every interaction here logs `[MARKET]` at debug with names and
  counts only. The picker sets flags and calls the two selection
  helpers; it performs no fetch itself.

### 9.2 Selected-item sections

Heading line: the selected type name as `resolver.name(type_id)`
when resolved, else `market_selected_type_name` (the word captured
at selection). Under it, "Region: {region_label}". There is no
"Type ID:" line, no region number, and no order number anywhere in
the view — Flutter's defects are not copied (section 2.1).

**Public orders** (`public_orders` section). On Err: the
characters-style label "Could not load public orders: {message}"
(following `section_error_label`, `src/ui/characters.rs:328-336`;
the message is client-sanitized and category-only). On Ok with no
participating orders: "No public orders for this item in this
region." On Ok with orders: `summarize_orders` renders as labeled
lines — "Best sell: {price_label}" or "Best sell: no sell orders";
"Best buy: …" symmetrically; "Spread: {price_label}" or "Spread:
not available (one side of the book is empty)"; "Sell orders: {n}
({v} remaining)"; "Buy orders: {n} ({v} remaining)". Then "Top sell
orders" and "Top buy orders", one text row per top order:
"{price_label} — {volume_remain} remaining at
{resolver.location_name(location_id)}". A side with no rows shows
its worded empty line. When `truncated`, one explicit line inside
this section: "Showing the first pages of orders only; counts and
best prices cover the orders loaded." When `skipped_invalid > 0`,
no line is added (log-only; a user cannot act on it).

**History** (`history` section). On Err: "Could not load price
history: {message}". On Ok empty: "No price history for this item
in this region." On Ok: the latest day as labeled lines ("Latest:
{date}", "Average: {price_label}", "Highest: …", "Lowest: …",
"Orders: {order_count}", "Volume: {volume}"), then up to 30 recent
rows "{date} — average {price_label}, volume {volume}", newest
first, then "Last {k} days shown: {recent_total_orders} orders,
{recent_total_volume} traded." with k the shown count. Dates are
ESI strings rendered as-is (they are dates, not IDs).

**Your open orders** (`character_orders` section). In order:

1. `selection.character_id` is None → `widgets::no_character_panel`
   under a "Your open orders" heading, matching the other views'
   signed-out words. No fetch was attempted.
2. Some character and the section is
   `Err(e) if e.needs_reauthorize` → the step-up panel (section
   9.3). The typed flag is the only trigger; message text is never
   inspected and never shown on this branch.
3. Other Err → "Could not load your open orders: {message}".
4. Ok empty → "No open orders for this character."
5. Ok with rows → heading with the character's name from
   `state.active_character()`, then one block per
   `character_order_rows` row: "{resolver.name(type_id)} — BUY" or
   "— SELL" (the word, not a color-only badge), "Price:
   {price_label}", "Filled: {filled} of {volume_total}
   ({volume_remain} remaining)", "At:
   {resolver.location_name(location_id)}", and when
   `matches_selected_type`, the marker "(item shown above)".
   Escrow renders as "Escrow: {price_label}" only for buy rows
   with finite escrow. A `filled_fraction` of Some renders an egui
   `ProgressBar`; None renders nothing extra (no guessed bar).
   When `truncated`, the same first-pages disclosure line as the
   public section, worded for own orders.

All three sections render inside the one Ready match arm section
by section, so a failed character fetch leaves the public book and
history on screen (the character-detail composition rule,
`src/ui/characters.rs:396-410`). Section headings always render,
so the failure is visible in place, never a silent gap.

### 9.3 Step-up policy inside the view

`market_reauthorize_panel(ui, state)` copies
`detail_reauthorize_panel` (`src/ui/characters.rs:341-381`)
adapted to one scope and one section:

- It appears **only** in the character-orders section and only on
  that section's typed `needs_reauthorize` error. No public
  section, heading, picker element, or other view is affected, and
  a missing market scope never blocks regional orders or history.
- Heading "Your open orders need one more EVE permission." Body
  text names the one scope `esi-markets.read_character_orders.v1`
  (from `EveConfig::MARKET_SCOPES.join(" ")`, never a hand-typed
  copy that can drift) and states plainly that the public orders
  and history above need no permission and are unaffected.
- The button "Re-authorize with EVE SSO" is enabled when
  `!state.demo && !state.auth.is_busy() &&
  state.active_character_id.is_some()` (the Assets rule,
  `src/ui/assets.rs:175`). A click does exactly one thing:
  `state.stepup_requested = Some(StepUpRequest::new(active_id,
  EveConfig::MARKET_SCOPES))` plus the same honest status line the
  existing panels set. It clears nothing. While `auth.is_busy()` it
  shows the spinner and auth label like the existing panels.
- In demo mode the panel is unreachable (demo sections are Ok),
  and `start_stepup_login` already refuses in demo; no market demo
  special case is added.
- One additive scope means the already-granted shortcut in
  `start_stepup_login` (granted-set pre-check,
  `src/app/shell.rs:1156-1174`) applies untouched: a character who
  granted the scope under another client state skips the browser
  and refetches. No shell change exists for step-up itself;
  section 8.5's refetch flag is the only integration.

## 10. Demo fixtures (Builder A data, Builder B loader)

### 10.1 New fixture file `assets/demo/market.json`

Keyed by demo character ID like `assets.json`, one entry object per
character, ESI field spellings (section 5.1):

```json
{
  "<character_id>": {
    "selected_type_id": 34,
    "region_id": 10000002,
    "public_orders": [ { "...": "RegionalOrder rows" } ],
    "public_orders_truncated": false,
    "history": [ { "...": "MarketHistoryEntry rows" } ],
    "character_orders": [ { "...": "CharacterOrder rows" } ],
    "character_orders_truncated": false
  }
}
```

(Builder A authors the concrete rows; the snippet locks shape
only. Row contents use the demo bundle's existing fictional
characters and real item types, following the "invented numbers,
honest shape" convention of the current fixtures: at least one
character with buy and sell public orders (including a price tie to
exercise tie-breaks), at least 5 history days, and character orders
covering buy and sell, one matching the selected type, one
partially filled. Prices and volumes are plausible sample values,
and every `issued`/`date` parses.) Every `public_orders` row's
`type_id` equals the entry's `selected_type_id`, and `region_id` is
one of the five hub constants. At least the first demo character
carries a market entry; other characters may omit it (that is the
Empty path exercised by switching).

Builder A also adds to `assets/demo/names.json` one row for each of
the five hub regions (`category: "region"`), the fixture's selected
types, every `type_id` on fixture character orders, and every
`location_id` the fixture renders, so demo never shows a raw number
or an avoidable Unknown.

### 10.2 Loader changes, backwards compatible (`src/demo/data.rs`)

Following the chain at lines 171-289 exactly:

```rust
pub const DEMO_MARKET_JSON: &str = include_str!("../../assets/demo/market.json");

#[derive(serde::Deserialize, Default)]
struct MarketFileEntry {
    #[serde(default)] selected_type_id: i64,
    #[serde(default)] region_id: i64,
    #[serde(default)] public_orders: Vec<RegionalOrder>,
    #[serde(default)] public_orders_truncated: bool,
    #[serde(default)] history: Vec<MarketHistoryEntry>,
    #[serde(default)] character_orders: Vec<CharacterOrder>,
    #[serde(default)] character_orders_truncated: bool,
}

pub fn load_demo_bundle_with_market(
    characters_json: &str, skillqueue_json: &str, wallet_json: &str,
    assets_json: &str, character_detail_json: &str, market_json: &str,
) -> AppResult<DemoBundle>;
```

- `DemoCharacterData` gains `pub market: Option<DemoMarketData>`,
  where `DemoMarketData` is a demo-local struct holding the entry's
  selection (`selected_type_id`, `region_id`) and its three row
  sets plus truncated flags — deliberately **not** `MarketData`,
  because demo seeding composes `MarketData` with the character
  being applied (section 10.3), the same way the detail fixture
  composes all-Ok section results (lines 255-263).
- `load_demo_bundle_with_detail` keeps its meaning and chains to
  the new top with `"{}"` for market; `load_demo_bundle` calls
  `load_demo_bundle_with_market` with `DEMO_MARKET_JSON`. A `"{}"`
  market file parses to an empty map (serde defaults), so every
  existing test literal keeps working and yields `market: None` —
  full serde backwards compatibility, no fixture version field
  anywhere.
- The key loop mirrors the detail loop: `parse_character_key`, a
  `[DEMO]` debug line with row counts, slot insert.
- `validate_bundle` gains an only-when-present block (the assets
  and detail pattern at lines 352-401): the entry region is in
  `MARKET_REGIONS`; every public order's `type_id` equals
  `selected_type_id`; order IDs are unique within public orders
  and within character orders; every `issued` parses via
  `parse_esi_datetime` and every history `date` parses as an ISO
  date (`chrono::NaiveDate::parse_from_str(raw, "%Y-%m-%d")`);
  history dates are unique. Failures reuse the existing
  `[DEMO] invalid demo bundle` message shape.

### 10.3 Seeding

`apply_character` gains, after the character-details install:

```rust
match &per.market {
    Some(fixture) => {
        let word = demo_type_name(fixture.selected_type_id); // rule below
        state.market_selected_type_id = Some(fixture.selected_type_id);
        state.market_selected_type_name = Some(word.clone());
        state.market_region_id = fixture.region_id;
        state.market = LoadState::Ready(MarketData {
            selection: MarketSelection {
                type_id: fixture.selected_type_id,
                type_name: word,
                region_id: fixture.region_id,
                character_id: Some(character_id),
            },
            public_orders: Ok(PublicOrdersData {
                orders: fixture.public_orders.clone(),
                truncated: fixture.public_orders_truncated,
            }),
            history: Ok(fixture.history.clone()),
            character_orders: Ok(CharacterOrdersData {
                orders: fixture.character_orders.clone(),
                truncated: fixture.character_orders_truncated,
            }),
        });
    }
    None => {
        state.market = LoadState::Empty;
        state.market_selected_type_id = None;
        state.market_selected_type_name = None;
    }
}
```

Locked details:

- The demo selected-type word: `apply_character` has no resolver,
  so the word comes from `crate::demo::data::load_demo_names()`
  looked up by `selected_type_id`, falling back to "Unknown Item".
  Because the fixture's selected types are required rows in
  `names.json` (section 10.1), the fallback is a backstop, not the
  expected path. Implement as a small demo helper
  (`demo_type_name(type_id) -> String`) rather than inline parsing.
- Both assignments run on every `apply_character`, so demo
  character switching can never leave the previous character's
  bundle or selection installed — the Empty-if-absent rule that
  assets (lines 622-630) and detail (lines 638-641) already
  follow. `market_candidates` and `market_lookup_message` are
  cleared here too, and the generation is bumped, keeping demo and
  live invariants identical even though demo never races.
- Region ownership split: with a fixture present, the fixture picks
  the demo region; with none, `market_region_id` keeps whatever the
  user last chose (resetting a region preference because a demo
  character lacks fixture data would be a surprise the live reset
  rules do not contain either).
- Demo mode never persists market data: `seed_bundle_into_db`
  gains one comment line beside "Assets and character detail are
  in-memory only" (line 752) naming market the same; no repository
  call. `seed_demo_state`'s failure branch (lines 732-739) adds
  `state.market = LoadState::Error(...)` with the same message as
  the other views.
- Demo lookup goes through section 8.3's exact-match answer, so
  the demo demonstrates lookup, candidates, and quick picks with
  zero network.

## 11. Market as the seventh view, and the README

### 11.1 The `View` enum (Builder B, `src/app/state.rs`)

Insert `Market` between `Assets` and `Settings`:

- enum gains `Market` before `Settings`; `ALL` becomes `[View; 7]`
  in the order Dashboard, Characters, Skills, Wallet, Assets,
  **Market**, Settings; `label()` gains `View::Market => "Market"`.
  `from_index`, `index`, `next`, `previous` need no edits (derived
  from `ALL`, lines 48-62).
- Key numbering: 1 Dashboard, 2 Characters, 3 Skills, 4 Wallet,
  5 Assets unchanged; **6 Market (new); Settings moves from 6 to
  7**. Settings is the right view to renumber: it is the last view,
  so exactly one existing key changes, and the five daily-driver
  views keep their muscle memory.
- Persisted startup-view safety: the saved value is a label string
  matched against `ALL` at startup and written back by label
  (`src/app/shell.rs:307-313`, `:1414-1425`), so a user who saved
  "Settings" still starts on Settings (now key 7), and a user who
  later saves "Market" works on any newer build; an older build
  meeting the label "Market" finds no match and keeps its default
  view, which existing code already handles by ignoring the saved
  value. No migration, no numeric remapping, no settings-schema
  change. The existing state test expectations (lines 493-506 et
  seq.) are updated by Builder B: `from_index(5) ==
  Some(View::Market)`, `from_index(6) == Some(View::Settings)`,
  `View::Settings.index() == 6`, `View::Assets.next() ==
  View::Market`, `View::Market.next() == View::Settings`,
  `View::Settings.previous() == View::Market`.
- `src/ui/mod.rs` gains `pub mod market;` (Builder B).

### 11.2 Shell chrome (integrator, except the one pre-authorized line)

- The view-dispatch match (`src/app/shell.rs:1512-1521`) is
  exhaustive, so the crate does not compile until a Market arm
  exists. As in prior slices, **Builder B is pre-authorized to add
  exactly one line there**:
  `View::Market => ui::market::show(ui, &mut self.state, &self.resolver),`
  placed before the Settings arm. That is the entire exception;
  every other `shell.rs` change is the integrator's.
- Integrator chrome updates: the keyboard key array at lines
  1349-1356 gains `egui::Key::Num7` (order preserved; `from_index`
  does the rest); the rail heading "Views (keys 1-6)" (line 1495)
  and the status-bar text "Keys: 1-6 views, …" (line 1531) become
  1-7. The rail body itself iterates `View::ALL` and prints
  `idx + 1` (lines 1496-1504), so labels renumber automatically.
- Settings' startup-view picker iterates `View::ALL`
  (`src/ui/settings.rs:87-96`), so Market becomes choosable with no
  settings edit and persists by label through existing code.

### 11.3 README (integrator)

`README.md` gains one "What works today" bullet for Market between
Assets and Settings, updates "(1-6 views…" to 1-7 in the Settings
bullet, removes "Price checking, trade tracking" from the roadmap
bullet only to the extent now true, and leaves "profit analysis"
explicitly unimplemented. The Market bullet states, in plain words:
read-only market view for one item at a time; public regional
orders and history in five hub regions need no sign-in and no scope;
your own open orders need the scope
`esi-markets.read_character_orders.v1`, which first sign-in
deliberately does not request and which the Market view offers to
grant through the same step-up flow as Assets; name lookup needs the
item's exact EVE name; nothing market-related is stored, no order
can be placed, and there is no profit or valuation feature; and,
matching the honesty pattern of the Assets and JWT bullets, that
this path has not been live-verified against a real EVE account yet
(unless it has been by integration time, in which case the
integrator says what was verified instead).

## 12. File ownership and the frozen contract

Two builders work in parallel against the frozen signatures below;
the integrator wires the shell afterwards. Every commit in the
slice keeps `cargo test` green on its own (Builder B's
pre-authorized dispatch line, section 11.2, exists precisely so
the new enum variant compiles before integration).

### 12.1 Frozen signatures (all sections above are the authority)

- Models: `RegionalOrder`, `CharacterOrder`, `MarketHistoryEntry`
  with the section 5.1 fields.
- Endpoints: `MARKET_MAX_PAGES`, `get_regional_orders`,
  `get_market_history`, `get_character_orders` with the section
  5.2 signatures and `(rows, truncated)` returns.
- Config: `EveConfig::MARKET_SCOPES` (section 5.3).
- State: `MarketSelection`, `PublicOrdersData`,
  `CharacterOrdersData`, `MarketData`, `MarketRegion`,
  `MARKET_REGIONS`, `DEFAULT_MARKET_REGION_ID`,
  `market_region_name`, the section 4.2 `AppState` fields,
  `set_market_selection`, `set_market_region`.
- Pure UI helpers: `MARKET_TOP_N`, `OrderBookSummary`,
  `summarize_orders`, `CharacterOrderRow`, `character_order_rows`,
  `filled_volume`, `filled_fraction`, `MARKET_HISTORY_ROWS`,
  `HistorySummary`, `summarize_history`, `price_label`,
  `region_label`, `quick_pick_types` in `src/ui/market.rs`
  (the integrator's name-scheduling block calls `summarize_orders`,
  so its name and signature are frozen even though it is a UI
  module function).
- Demo: `assets/demo/market.json` shape (section 10.1),
  `DEMO_MARKET_JSON`, `DemoMarketData`,
  `DemoCharacterData::market`, `load_demo_bundle_with_market`,
  `demo_type_name`.
- Shell (integrator): `BackendMsg::MarketFetched`,
  `BackendMsg::MarketLookupDone` (section 8.1).

Cross-builder structure literals: `MarketData`,
`PublicOrdersData`, `CharacterOrdersData`, `MarketSelection` are
constructed literally by the shell and demo seeding; adding a
field to any of them after freeze is a design change.

### 12.2 Builder A — endpoints, models, scope constant, fixtures

Owns:

- `src/esi/models.rs`: the three models and their parse tests.
- `src/esi/endpoints.rs`: the three endpoints, the capped walks,
  `MARKET_MAX_PAGES`, and mock-server tests.
- `src/config.rs`: `MARKET_SCOPES` and its disjointness test only.
- `assets/demo/market.json`: new file, section 10.1 contents.
- `assets/demo/names.json`: the region, type, and location rows
  the market fixture renders.

Builder A touches no state, demo-loader, UI, shell, storage, auth,
or error code. To keep A's commit green without B, A's endpoints
land as tested dead code at first (the `get_attributes` precedent:
endpoints existed unwired before the character-detail slice used
them).

### 12.3 Builder B — state, demo loader, UI

Owns:

- `src/app/state.rs`: `View::Market` and renumbering tests, the
  market types/constants/helpers, the new `AppState` fields, and
  the switch/removal resets.
- `src/demo/data.rs`: `DEMO_MARKET_JSON`, `MarketFileEntry`,
  `DemoMarketData`, `load_demo_bundle_with_market`, the validation
  block, `demo_type_name`, and the `apply_character` /
  `seed_demo_state` / `seed_bundle_into_db` touches.
- `src/ui/market.rs`: new file — pure helpers, picker, sections,
  step-up panel, in-module tests.
- `src/ui/mod.rs`: `pub mod market;`.
- `src/app/shell.rs`: **only** the one pre-authorized dispatch
  line (section 11.2).

Nothing B ships calls the network or reads Builder A's endpoints;
B compiles against A's models only. B's view sets request flags
that nothing drains until integration; that is the established
request-flag pattern (`src/app/state.rs` module contract), not
faked completion, because the view honestly shows Loading until a
drain installs data.

### 12.4 Integrator — shell wiring and README

Owns everything else in `src/app/shell.rs` for this slice: the two
`BackendMsg` variants and their arms, `start_market_fetch`,
`start_market_lookup`, both drain blocks, the `schedule_name_resolution`
market block, the character-switch and step-up-completion fetch
flags (section 8.5), `Num7` in the key array, the two "1-6" texts
becoming 1-7, and `README.md` per section 11.3. The integrator
also owns the final scope gates (section 13.3) and the demo smoke
run. No other file in the tree changes in this slice:
`src/error.rs`, `src/esi/client.rs`, `src/auth/`, `src/storage/`,
`src/names/`, and every other `src/ui/` module are untouched.

## 13. Test plan and gates

Each builder's tests land with its code; every named behavior in
sections 4-11 has at least one test or gate below.

### 13.1 Builder A

- Models: full-row parse for each of the three structs (every field
  asserted), `{}` defaults parse (the `asset_item_defaults`
  pattern), `escrow` present/absent/null, unknown extra fields
  ignored, and a round trip through the demo fixture file itself
  (`serde_json::from_str(DEMO_MARKET_JSON)`-adjacent coverage lives
  in B's loader tests; A asserts per-row literals).
- Endpoints, against the in-file mock-server pattern
  (`src/esi/endpoints.rs:417-468` and the assets server below it):
  - regional orders walk two `X-Pages: 2` pages and return rows in
    fetch order with `truncated: false`;
  - the captured request query contains `type_id=`, `order_type=all`,
    and `page=` on page 2 (path-embedding proof, the
    `get_wallet_transactions_from` hazard);
  - cap: `X-Pages: 5` with helper `max_pages: 2` issues exactly two
    requests and returns `truncated: true`;
  - missing `X-Pages` with an empty second page stops clean;
    missing `X-Pages` with a non-empty page at the cap returns
    `truncated: true`;
  - history is one request with `type_id=` in the query and returns
    the array unsorted;
  - character orders walk pages, require tokens
    (`client_with_fresh_tokens`), and map a mock 403 to
    `EsiError::Reauthorize` with `needs_reauthorize(&e)` true;
  - a page-2 error propagates (no partial Ok) on both walks;
  - public endpoints succeed with no token store attached.
- Config: `MARKET_SCOPES` equals the single scope and is absent
  from `FIRST_AUTH_SCOPES`; `FIRST_AUTH_SCOPES` output unchanged
  (existing tests stay untouched and passing).

### 13.2 Builder B

- Summaries (`src/ui/market.rs` tests): best sell is the minimum
  and best buy the maximum; spread only when both sides exist and
  equals their difference (including a crossed negative case);
  empty input gives all-`None`/zeros; one-sided books give `None`
  spread; NaN, infinite, zero, and negative prices are skipped and
  counted in `skipped_invalid` (a NaN row never becomes a best
  price); tie-break order (same price → larger remaining volume
  first → earlier issued first → lower order ID first) on both
  sides; top lists truncate at `MARKET_TOP_N` after sorting;
  volume sums saturate at `i64::MAX` with two maximal rows (the
  `grouping_saturates_instead_of_overflowing` pattern), and a
  negative `volume_remain` contributes zero.
- Character rows: `filled_volume` saturates and clamps
  (remain > total → 0; `i64::MAX` operands do not panic);
  `filled_fraction` is `None` at total 0 and clamps to `0.0..=1.0`;
  rows sort issued-descending with the order-ID tie-break;
  `matches_selected_type` flags exactly the selected type.
- History: sorts descending regardless of input order, latest is
  the maximum date, recent truncates at 30, totals cover shown
  rows only, totals saturate, empty input is all-`None`/zeros.
- Labels: `price_label` formats finite values via `format_isk` and
  returns "not available" for NaN/infinite (never "0.00 ISK");
  `region_label` prefers a resolver hit, falls back to the curated
  name, and never returns a string that parses as an integer; no
  rendered label from any helper parses as an integer with an
  empty resolver (the assets raw-ID test pattern,
  `src/ui/assets.rs:338-356`).
- Quick picks: assets-first priority, wallet fill-in, dedup across
  both, sort and 12-cap, empty when neither is Ready.
- State: view renumbering expectations (section 11.1);
  `set_market_selection` change vs reselect behavior (Loading +
  generation bump + fetch flag on change; rows kept on reselect);
  `set_market_region` rejects a non-hub ID without changing state;
  character switch resets a selected market to Loading and bumps
  the generation while keeping selection/region/search, and is a
  no-op on same-character reselect; removing the active character
  resets market, and removing the last character sets Empty
  (mirroring the existing assets switch/removal tests).
- Demo loader: the bundled bundle loads with a market entry for the
  first character; every older arity (`load_demo_bundle_from`,
  `_with_assets`, `_with_detail`) still loads the same literals
  with `market: None`; `load_demo_bundle_with_market(..., "{}")`
  yields `market: None` (serde back-compat); validation rejects a
  public order whose `type_id` differs from `selected_type_id`, a
  non-hub `region_id`, a duplicate order ID, an unparseable
  `issued`, and a duplicate history date; `apply_character`
  installs Ready with the applied character in the selection, and
  Empty + cleared selection for a marketless character after
  having shown a market character (the stale-bundle regression
  test mirroring detail).

### 13.3 Integrator gates

Commands, all run against the integrated tree:

- `cargo test`, `cargo clippy --all-targets -- -D warnings`,
  `cargo fmt --check`, `cargo build` (the CI set,
  `.github/workflows/ci.yml`).
- Scope gates by grep over the slice diff:
  - `orders/history` appears nowhere in `src/` (section 5.4);
  - `FIRST_AUTH_SCOPES` block byte-identical to `122b84a`
    (`git diff 122b84a -- src/config.rs` shows only the additive
    constant and its test);
  - no new `auth_post` or `public_post` call sites (lookup reuses
    `resolve_ids`);
  - no `repositories::` call inside the market fetch task, and no
    diff under `src/storage/` at all (no schema migration);
  - no `format!` in `src/ui/market.rs` renders `order_id`,
    `type_id`, `region_id`, or `location_id` (raw-ID rendering
    gate; resolver calls on those fields are expected and fine);
  - no Dart file restored (`git status` shows no `lib/` paths).
- Manual/demo smoke: run `--demo`, open Market with key 6, confirm
  the fixture book, history, and character orders render with
  resolved names and no visible numeric ID (prices, counts,
  volumes, and dates expected; IDs not); switch demo characters
  and confirm the market bundle follows (Empty where the fixture
  is absent); exercise demo lookup failure and exact-match
  success. Live ESI verification against a real account is
  desirable but explicitly not a merge gate for this slice, in
  line with the Assets and JWT slices' recorded posture; the
  README wording (section 11.3) records whichever is true at
  integration time. Token values, codes, state, and authorize URLs
  are never printed during any check.

## 14. Explicit non-goals

Everything in the hard scope (section 1.1), plus the nearby
temptations, named so nobody has to guess:

- No order placement, modification, or cancellation; no ESI write
  of any kind.
- No database table, column, cache, TTL, or ETag handling for
  market data; market state dies with the process. (Flutter's
  Drift market tables and its false 24-hour history claim are both
  rejected designs here.)
- No `GET /markets/prices/` global price list and no adjusted or
  average global price cards.
- No character order-history (closed/expired) view (section 5.4).
- No calculator: no margin, profit, loss, broker fee, sales tax,
  break-even, hauling, or arbitrage figure, and no percent spread.
- No valuation: no price-times-volume row values, no order-book
  ISK depth totals, no total escrow, no "worth" of open orders.
- No chart for history (text summary only); no candlestick, no
  moving average, no trend indicator.
- No multi-type watchlist, favorites, recent-items list, or
  persisted selection or region. One type, in memory, chosen each
  session.
- No substring item search and no new SDE download or expansion;
  the exact-name lookup is the whole search story until a Rust
  item index exists.
- No region beyond the five hub constants and no free-form region
  entry.
- No corporation orders, structure-market special handling, buy
  range visualization (`range` parses and is not rendered in this
  slice), or market alerts/notifications.
- No change to `FIRST_AUTH_SCOPES`, the step-up flow, JWT
  verification, the refresh pipeline, or any other view's
  behavior. General refresh deliberately does not refetch market
  data (section 8.5).

## 15. Risks and unresolved items

- **ESI parameter details were locked from route-level
  specification evidence, not from a live call.** `order_type=all`
  and `page` handling for `/markets/{region_id}/orders/` are
  standard ESI query parameters and the survey confirmed the route
  table, but no inspected body executed this request (Flutter
  never called the route). The mock-server tests prove our
  request shape; live acceptance is unverified until someone runs
  against a real account. If live ESI rejects `order_type=all`
  with a client error, the failure lands in the public-orders
  section only and the fix is one path string in one function.
- **Truncation honesty depends on `X-Pages`.** When the header is
  absent, the design treats a non-empty page at the cap as
  truncated (section 5.2), which can over-warn if that page was in
  fact the last. Over-warning was chosen over silent
  under-reporting.
- **`MARKET_MAX_PAGES = 10` is a judgment call, recorded.** A
  one-type book in The Forge is the largest this slice fetches;
  ten pages bounds latency and memory while the truncated flag
  keeps any cap hit visible. Changing it later is one constant.
- **`is_buy_order` serde default** masks a hypothetically absent
  field as a sell order (section 5.1). Live ESI sends the field;
  the tolerance pattern across all models was kept rather than
  inventing a stricter market-only parse that would fail whole
  pages.
- **Selected type shown in "your orders" can exceed the top-N
  name budget**: character orders schedule every row's type and
  location names (section 8.4). A character order count is
  character-bounded, unlike regional rows, so the asymmetry with
  top-N-only public locations is deliberate.
- **Market is excluded from cached startup state**:
  `load_cached_state` does not fill it (nothing is persisted), so
  a live relaunch starts Market empty until the user picks a type.
  That is the in-memory scope working as intended, not an
  oversight.

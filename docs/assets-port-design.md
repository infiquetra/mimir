# Rust Assets slice — design

Status: design only. This document creates no Rust code. It defines one
read-only slice that two builders plus one integrator can implement without
further design decisions.

Repo: `/home/jefcox/workspace/infiquetra/mimir`, base `develop` at `a580df7`
(Rust rewrite merged), branch `feat/rust-assets-port`. The Flutter Assets
feature lives only in git history; every Flutter citation below was read with
`git show ed698d3:<path>` and no Dart file is restored to the tree. Every Rust
citation below names a file body inspected on `develop`.

## 1. What this slice is

Mimir (the Rust/egui EVE Online companion in this repo) gains a sixth view,
**Assets**: the active character's ESI asset list, grouped by location, with
text search, singleton custom names (ship and container names), resolved type
and location names, a fully working offline demo path, and honest guidance —
not fake data and not a broken refresh — when the signed-in character has not
granted the assets permission.

Hard scope for this slice, binding on every builder:

- Read-only. No asset mutation of any kind (EVE ESI character assets are
  read-only anyway; nothing here writes to ESI).
- No database schema migration. `src/storage/schema.sql` (11 tables, no
  assets table), `src/storage/db.rs`, and `src/storage/repositories.rs` are
  not edited. Assets live in memory only and are refetched on refresh.
- `FIRST_AUTH_SCOPES` is not widened. The first sign-in scope set in
  `src/config.rs:26-32` stays exactly `publicData`,
  `esi-skills.read_skills.v1`, `esi-skills.read_skillqueue.v1`,
  `esi-wallet.read_character_wallet.v1`, `esi-clones.read_implants.v1`. The
  existing guard test `first_auth_scopes_match_least_privilege_set`
  (`src/config.rs:121-126`, asserts the string does not contain
  `esi-assets`) must keep passing unchanged. `src/config.rs` is not edited.
- All logging goes through `tracing` with a bracketed tag. This slice adds
  the tag `[ASSETS]` and reuses `[ESI]`, `[DEMO]`, `[UI]`, `[DB]`. Token
  values are never logged; endpoints take a character ID only and the token
  comes from the store inside `EsiClient` (`src/esi/endpoints.rs:1-4`
  module contract).
- The user interface shows resolved EVE names only, never a raw numeric ID.
  Unresolved types show `Unknown Item` and unresolved locations show
  `Unknown Location` (the `NameResolver` fallbacks in
  `src/names/resolver.rs:130-147`).
- No push and no merge are part of this design task.

## 2. Evidence base (what was inspected, and what it forces)

Flutter behaviour worth preserving, from history at `ed698d3`:

- Manual plus startup sync only, with no periodic timer: the AppBar refresh
  action and the empty-state "Sync Assets" button call
  `AssetSyncNotifier.sync()` (`lib/features/assets/data/asset_providers.dart:83-95`),
  and `asset_browser_screen.dart` shows a spinner in place of the refresh
  button while syncing. The Rust global refresh (top bar / Ctrl+R / startup,
  `src/app/shell.rs:494-644`, `:308-310`) is the direct equivalent, so Assets
  rides the existing refresh instead of gaining its own trigger.
- Grouping by `locationId` into per-location summaries sorted by descending
  total item count, where the count is the sum of `quantity` over the group
  (`asset_providers.dart:42-70`).
- Search semantics: a location whose name matches keeps all of its assets; a
  location with item matches keeps only the matching items; matching checks
  the type name and the custom name (`asset_browser_screen.dart`,
  `_filterSummaries`, lines 123-152 in the historical file).
- Row display: primary text is `customName ?? typeName`, the type name is
  shown second when a custom name exists, and the trailing text is
  `x{quantity}` (`asset_browser_screen.dart:230-285` in history). Per-location
  subtitle is `{n} item types, {m} total items`.
- Singleton custom names are fetched in batches of 1000, and a failed batch
  is logged and skipped rather than failing the sync
  (`asset_sync_service.dart:163-187`).

Flutter defects this slice deliberately does not reproduce:

- The raw-ID leak `locationName: 'Location #$locationId'`
  (`asset_providers.dart:52-59`). The Rust resolver already guarantees a
  word, never a number (`src/names/resolver.rs:142-147`).
- Search kept the unfiltered `itemCount` on a filtered summary, so the
  subtitle lied after filtering (`asset_browser_screen.dart` `_filterSummaries`
  passes `itemCount: summary.itemCount`). Section 7 recomputes counts.
- `is_blueprint_copy` exists in the ESI payload and in the Flutter table
  but the Flutter ESI model never parsed it and sync never wrote it
  (`esi_client.dart` `AssetItem` at 1156-1183 in history). Section 4 parses
  it.
- Sync errors were silently swallowed in the screen (only `isLoading` was
  read). Section 9 surfaces the assets error inside the Assets view only.
- Dead surface: `totalValue` on `LocationAssetSummary`
  (`asset_providers.dart:25,31`) was never populated, the
  `assets/locations` endpoint was defined but never called, and
  `containedInId` was always written `null` with a "Phase 2" comment
  (`asset_sync_service.dart:84-86`). None of these are ported (Section 12).

Rust patterns this slice copies, with the exact templates:

- Paginated authenticated GET: `get_wallet_journal_page`
  (`src/esi/endpoints.rs:62-80`) and the full-page walk `get_wallet_journal`
  (`src/esi/endpoints.rs:83-124`), which reads the `X-Pages` total from
  `EsiMeta.pages` (`src/esi/client.rs:21-28,212-216`), stops when
  `page >= total`, falls back to stopping on an empty page when the header
  is absent, and logs per page at debug plus one info total.
- Authenticated POST exists but has no caller yet: `EsiClient::auth_post`
  (`src/esi/client.rs:314-329`). The empty-input short-circuit precedent is
  `resolve_names` / `resolve_ids` (`src/esi/endpoints.rs:216-234`).
- Typed scope failure: HTTP 403 maps to `EsiError::Reauthorize` in
  `EsiError::from_status` (`src/error.rs:39-55`), `is_scope_error()` is true
  only for that variant (`src/error.rs:57-59`), and
  `endpoints::needs_reauthorize` (`src/esi/endpoints.rs:308-313`) already
  classifies `Reauthorize | Unauthorized` for the UI. No new error type is
  needed and `src/error.rs` is not edited.
- Per-view state: `LoadState<T>` (`src/app/state.rs:61-93`) and the view
  data bundles `WalletData` / `SkillsData` (`src/app/state.rs:159-175`),
  whose field sets are cross-builder contracts. Assets gets its own bundle;
  it is never stuffed into `WalletData`.
- View rendering: `ui::wallet::show` (`src/ui/wallet.rs:80-313`) — heading,
  `widgets::mode_notice`, no-character guard, cloned `LoadState` snapshot,
  `Loading`/`Empty`/`Error` panels, retry via `state.retry_requested`, and
  the pure helper `compute_analytics` (`src/ui/wallet.rs:39-78`) with unit
  tests asserting resolved names never parse as `i64`
  (`src/ui/wallet.rs:364-368`).
- Name fill scheduling: `MimirApp::schedule_name_resolution`
  (`src/app/shell.rs:332-384`) collects IDs from live state, skips player
  structures via `is_structure_id` (`src/names/resolver.rs:29-35`), asks
  `resolver.missing(...)`, then spawns chunked (1000) `resolve_names` calls
  and applies `BackendMsg::NamesResolved`.

## 3. Decisions locked by this design

These settle the open questions left by the two investigation passes. A
builder who disagrees stops and raises it; none of them is re-decided
silently in code.

| # | Decision | Reason |
|---|---|---|
| D1 | Fetch assets inside the existing global refresh, as a tolerant sub-result that can never fail the whole refresh | A character without the assets scope must keep working skills and wallet views. The loyalty fetch already sets the tolerance precedent (`src/app/shell.rs:524-526`). Lazy fetch on first Assets-view open was rejected: it needs a new request flag plus in-flight dedup, and it breaks the Flutter startup/manual-sync parity above. |
| D2 | `POST /characters/{id}/assets/names/` is in the slice; `POST /characters/{id}/assets/locations/` is out | Names needs no scope beyond `esi-assets.read_assets.v1` (the same single scope covers the asset list and names), no schema, and `auth_post` already exists. Locations returns only `position {x, y, z}` per item (historical `EsiAssetLocation`, `esi_client.dart:1197-1217`), was never called by Flutter sync, and has nothing to display in a grouped list — porting it would be dead code. |
| D3 | No token-scope pre-check before fetching. The typed 403 is the only scope signal | Granted scopes are persisted in `token_meta` at login (`src/app/shell.rs:681-689`) and `get_token_meta` exists (`src/storage/repositories.rs:1020`), but that row is written only at sign-in and can go stale across refreshes. `EsiError::Reauthorize` from the real call is the single source of truth and needs no repository read. |
| D4 | The step-up sign-in flow itself is a follow-up, not this slice. The Assets view explains the missing scope and offers no button that pretends to fix it | The task lists step-up OAuth implementation as an explicit non-goal. The primitives for the follow-up already exist (`create_authorization_request_with_scopes`, `src/auth/oauth.rs:220-232`; `EveConfig::scopes_string`, `src/config.rs:94-96`), but `start_login` (`src/app/shell.rs:646-652`) only ever requests first-auth scopes, so even "Add character" cannot grant the assets scope today. Honest consequence, stated in the view: live assets render only for a character whose stored token already carries `esi-assets.read_assets.v1`; everyone else gets the guidance panel, and demo mode shows the full feature. |
| D5 | `Assets` is inserted before `Settings` in the view order; Settings moves from key 5 to key 6 | Settings stays last in the rail, matching every existing layout. The cost is one changed shortcut, and it is safe: the persisted startup view is matched by label string, not by index (`src/app/shell.rs:273-279`), so a stored `"Settings"` or `"Wallet"` keeps meaning the same view. All `1-5` help strings are updated to `1-6` (Section 6). |
| D6 | Custom (singleton) names live in `AssetsData`, keyed by item ID, and are never inserted into `NameResolver` or the `universe_names` table | A custom name belongs to one item instance (a named ship), not to its type. The resolver cache is keyed by universe ID (`src/names/resolver.rs:44-48`); inserting an item ID there would pollute every later lookup of that number. |
| D7 | No persistence for assets in this slice. `load_cached_state` is unchanged and Assets starts `Loading` every live launch | The no-migration hard scope leaves no table to read. Only resolved universe names persist, through the existing `NamesResolved` upsert (`src/app/shell.rs:418-434`). Offline live launches therefore show the Assets error/empty state after a failed refresh, exactly as skills and wallet would without their cache; this is accepted and named, not hidden. |
| D8 | Container hierarchy is flattened. An asset whose `location_id` is a parent item (ship hold, container) groups under that ID, which renders as `Unknown Location` until a hierarchy follow-up lands | Flutter did the same (`containedInId` always null). Grouping by the raw `location_id` is the minimal honest slice; inventing a parent name from the parent item's type is a follow-up that needs its own design. |

## 4. ESI endpoints and typed models (Builder A)

All endpoint work is in `src/esi/endpoints.rs`; all model work is in
`src/esi/models.rs`. Both follow the file contracts already in place:
endpoints take `(&EsiClient, character_id: i64)`, log with a bracketed tag,
and never receive or log a token; models derive
`Debug, Clone, Default, Serialize, Deserialize`, put `#[serde(default)]` on
every field, use `i64` IDs, and ignore unknown ESI fields
(`src/esi/models.rs:1-5`).

### 4.1 Models to add in `src/esi/models.rs`

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AssetItem {
    #[serde(default)] pub item_id: i64,
    #[serde(default)] pub type_id: i64,
    #[serde(default)] pub quantity: i64,
    #[serde(default)] pub location_id: i64,
    #[serde(default)] pub location_flag: String,
    #[serde(default)] pub location_type: String,
    #[serde(default)] pub is_singleton: bool,
    #[serde(default)] pub is_blueprint_copy: Option<bool>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AssetName {
    #[serde(default)] pub item_id: i64,
    #[serde(default)] pub name: String,
}
```

Field notes:

- Six of these fields are the historical Flutter `AssetItem` set
  (`item_id`, `type_id`, `quantity`, `location_id`, `location_flag`,
  `is_singleton`). `location_type` is carried because the
  context-library assets specification lists it on asset payloads; it
  defaults to empty when ESI omits it, and this slice does not display it.
- `is_blueprint_copy` is `Option<bool>` because ESI emits it only for
  blueprint items; `None` and `Some(false)` both mean "not a copy" for
  display. Whether live ESI ever sends an explicit `null` is unverified
  (Section 14); `Option` plus `#[serde(default)]` parses all three shapes.
- `AssetName` is the `POST .../assets/names/` element shape, matching the
  historical `EsiAssetName` (`item_id`, `name`).
- No `AssetLocation` model is added (decision D2).

### 4.2 Endpoints to add in `src/esi/endpoints.rs`

Three functions, each a copy of an existing shape:

1. `get_assets_page(client, character_id, page: u32) -> AppResult<Vec<AssetItem>>`
   — copy of `get_wallet_journal_page` (`:62-80`) with the path
   `/characters/{character_id}/assets/`, the `[ASSETS]` tag, and
   `Some(page.max(1))`.
2. `get_assets(client, character_id) -> AppResult<Vec<AssetItem>>` — copy of
   the `get_wallet_journal` walk (`:83-124`) field for field: start at page
   1, extend, stop when `meta.pages` says `page >= total`, stop on an empty
   page when `X-Pages` is absent, debug-log each page
   (`[ASSETS] assets page={} rows={} total={}`), and finish with one info
   line (`[ASSETS] assets fetched character_id={} rows={}`). Any page error
   — including the 403 scope failure — propagates with `?` so the caller
   sees the typed error; partial asset lists are never returned as success.
3. `get_asset_names(client, character_id, item_ids: &[i64]) -> AppResult<Vec<AssetName>>`
   — thin single POST, first production caller of `auth_post`
   (`src/esi/client.rs:314-329`): return `Ok(Vec::new())` immediately when
   `item_ids` is empty (the `resolve_names` precedent, `:218-220`), else
   `auth_post("/characters/{character_id}/assets/names/", character_id,
   &item_ids.to_vec())`, debug-logged as `[ASSETS] POST
   /characters/{}/assets/names/ count={}`. Chunking to the ESI limit of
   1000 IDs per call is the caller's job, exactly as `resolve_names` is
   chunked by the shell (`src/app/shell.rs:371`); the doc comment on
   `get_asset_names` must state the 1000-ID limit.

No other endpoint is added. `needs_reauthorize` (`:308-313`) is reused
unchanged for the scope-failure check.

## 5. Assets as the sixth view: state (Builder B)

All edits in this section are in `src/app/state.rs` unless named otherwise.

### 5.1 The `View` enum

Current state: five variants `Dashboard` (default), `Characters`, `Skills`,
`Wallet`, `Settings` at `src/app/state.rs:14-32`, with `ALL: [View; 5]`,
`label()`, `from_index()`, `index()`, `next()`, `previous()`.

Exact edits:

- Doc comment `:14` becomes "The six views (keys 1-6 in the shell)."
- Insert `Assets` between `Wallet` and `Settings` in the enum, in `ALL`
  (now `[View; 6]`), and as a `label()` arm returning `"Assets"`.
- `from_index`, `index`, `next`, `previous` need no body change: they are
  all expressed over `View::ALL` (`:44-58`), so key 5 becomes Assets, key 6
  becomes Settings, `Settings.next()` still wraps to `Dashboard`, and
  `Dashboard.previous()` still returns `Settings`.
- The existing test `view_navigation_wraps_and_indexes` (`:344-352`) is
  extended, not weakened: `View::from_index(4) == Some(View::Assets)`,
  `View::from_index(5) == Some(View::Settings)`,
  `View::Assets.index() == 4`, `View::Settings.index() == 5`,
  `View::Wallet.next() == View::Assets`,
  `View::Assets.previous() == View::Wallet`. The current assertions
  (`Settings.next() == Dashboard`, `Dashboard.previous() == Settings`,
  `from_index(3) == Wallet`, `from_index(9) == None`) all stay true and
  stay in the test.

### 5.2 `AssetsData` and new `AppState` fields

Add one data bundle next to `WalletData` / `SkillsData` (`:159-175`). The
"do not add fields" contract on those two structs is why Assets gets its
own type instead of reusing either:

```rust
/// Assets view data bundle: raw ESI rows plus per-item custom names for
/// singletons (ships, containers), keyed by item_id. Custom names are
/// per-instance and never enter the universe name resolver.
#[derive(Debug, Clone, Default)]
pub struct AssetsData {
    pub items: Vec<AssetItem>,
    pub custom_names: HashMap<i64, String>,
}
```

`HashMap` is already imported (`:9`) and `AssetItem` arrives through the
existing `crate::esi::models::*` glob (`:11`). No import change is needed.

New fields on `AppState` (`:192-231`), each mirroring an existing sibling:

- `pub assets: LoadState<AssetsData>` — beside `wallet` (`:203`).
- `pub assets_search: String` — view-local, beside `wallet_search` (`:212`).
- `pub assets_needs_reauthorize: bool` — beside `offline` (`:199`). This
  flag carries the one bit `LoadState::Error(String)` cannot: that the
  failure was the typed scope failure (`EsiError::Reauthorize`), so the
  view renders step-up guidance instead of a retry panel. Default `false`.

No selected-row field is added. The wallet's arrow-key selection
(`src/ui/wallet.rs:199-216`) works on one flat table; Assets is a grouped
list whose primary navigation is search, so row selection is deferred
rather than half-defined over groups.

### 5.3 State lifecycle edits

- `remove_character` (`:294-310`): in the `characters.is_empty()` reset
  block, add `self.assets = LoadState::Empty;` beside the existing four
  resets, and clear `self.assets_needs_reauthorize = false;` for any
  removal (a guidance flag for a deleted character must not linger). The
  test `active_character_cycle_and_remove_never_panic` (`:367-386`) gains
  an assertion that `assets` is `Empty` after the last removal, mirroring
  the existing `wallet` assertion.
- Character switching needs no state edit: a live switch already calls
  `request_refresh("character-switch")` (`src/app/shell.rs:473-475`) and a
  demo switch calls `apply_character` (`src/app/shell.rs:467-472`), and
  Section 10 extends the demo path. Stale assets from the previous
  character stay visible during a live refresh, which is the same contract
  skills and wallet already have (their `Ready` data is only replaced on
  `BackendMsg::Refreshed`).
- `startup_view` (`:219`) needs no edit: it already stores a `View`, so it
  can hold `Assets` as soon as the variant exists. Settings renders the
  picker by iterating `View::ALL` (`src/ui/settings.rs:86-99`), so Assets
  becomes selectable with zero settings-logic change, and the shell's
  label-matched restore (`src/app/shell.rs:273-279`) plus change-only
  write-back (`src/app/shell.rs:838-853`) cover `"Assets"` automatically.
  A stored value that matches no label is ignored today and stays ignored.

## 6. Shell and chrome wiring (integrator only)

Every edit in this section is in `src/app/shell.rs` unless named otherwise.
Neither builder touches this file; the integrator owns it end to end so the
two builder branches cannot conflict here. `src/main.rs` needs no change:
it only constructs `Backends` and `MimirApp::new`
(`src/main.rs:77-118`), neither signature moves.

### 6.1 Keyboard and labels

- `collect_keys` (`:762-803`): the key array at `:774-780` gains
  `egui::Key::Num6` as a sixth entry. The loop already maps position to
  `View::from_index(idx)`, so no other line changes.
- The character-rail heading `"Views (keys 1-5)"` (`:919`) becomes
  `"Views (keys 1-6)"`, and the status-bar help (`:954`) becomes
  `"Keys: 1-6 views, Ctrl+R refresh, / search, PgUp/PgDn character"`. The
  rail list itself iterates `View::ALL` (`:920-928`) and prints
  `idx + 1`, so Assets appears as `5 Assets` with no further edit.
- Two more `1-5` help strings live in Builder B files and change to `1-6`
  there: `src/ui/settings.rs:111` (keyboard help) and
  `src/ui/widgets.rs:162` (inside `no_character_panel`).

### 6.2 View dispatch

The `CentralPanel` match (`:936-944`) gains one arm between `Wallet` and
`Settings`:

```rust
View::Assets => ui::assets::show(ui, &mut self.state, &self.resolver),
```

The signature matches the wallet's (`show(ui, state, resolver)`), so the
Assets view resolves names through the same `NameResolver` the shell owns.

### 6.3 Refresh: tolerant assets sub-fetch and the `Refreshed` message

`BackendMsg::Refreshed` (`:34-40`) gains two fields:

```rust
Refreshed {
    character_id: i64,
    info: Box<CharacterPublicInfo>,
    skills: Box<SkillsData>,
    wallet: Box<WalletData>,
    assets: Result<Box<AssetsData>, String>,
    assets_needs_reauthorize: bool,
}
```

Carrying a `Result` (not a `LoadState`) keeps the keep-stale-versus-error
choice in `drain_requests`, which is the only place that knows whether
previous assets are `Ready` — the same split `RefreshFailed` already uses
(`:435-445`). `AssetsData` joins the existing `super::state::...` import
(`:8-10`).

Inside `start_refresh`'s spawned task (`:515-643`), the required fetches
keep their `?` operators untouched. After `wallet` is built and before the
tuple is returned, the integrator adds a tolerant block (never `?`):

1. `let assets_result = endpoints::get_assets(&esi, id).await;`
2. On `Ok(items)`: collect singleton item IDs
   (`items.iter().filter(|a| a.is_singleton).map(|a| a.item_id)`), then for
   each `chunk` of at most 1000 IDs call `endpoints::get_asset_names`. A
   failed chunk logs
   `tracing::warn!("[ASSETS] custom-name batch failed character_id={} …")`
   and is skipped — the Flutter per-batch tolerance
   (`asset_sync_service.dart:182-184`). Insert each returned name into the
   map only when it is non-empty after trimming and not equal to `"None"`
   (ESI's placeholder for unnamed singletons; the context-library assets
   specification's filter rule). The outcome is
   `Ok(AssetsData { items, custom_names })` with
   `assets_needs_reauthorize = false`.
3. On `Err(e)`: the outcome is `Err(e.to_string())` with
   `assets_needs_reauthorize = endpoints::needs_reauthorize(&e)`, logged at
   warn as `[ASSETS] assets fetch failed character_id={} …`. The error
   never reaches the outer `result`, so character, skills, and wallet
   still refresh and persist exactly as today. Assets are never persisted:
   the persistence block (`:535-629`) is unchanged (decision D7).

In `drain_requests`, the `Refreshed` arm (`:390-417`) applies the outcome
after the existing assignments:

- `Ok(data)` → `state.assets = LoadState::Ready(*data)` and
  `state.assets_needs_reauthorize = false`.
- `Err(message)` with `assets_needs_reauthorize == true` →
  `state.assets = LoadState::Error(message)` and the flag is set `true`.
  Stale `Ready` data is deliberately replaced here: showing old assets as
  if current, when the scope is now refused, would be fake freshness.
- `Err(message)` otherwise → mirror the `RefreshFailed` rule: set
  `LoadState::Error(message)` only when `!state.assets.is_ready()`, keep
  stale `Ready` data on a transient failure, and leave the flag `false`.
- `schedule_name_resolution()` is already called at the end of the arm
  (`:416`); Section 9 extends what it collects.

The global `RefreshFailed` arm (`:435-445`) gains the third sibling line:
`if !self.state.assets.is_ready() { self.state.assets =
LoadState::Error(message.clone()); }` with the same clone discipline the
arm already uses for skills. It does not set
`assets_needs_reauthorize`: a whole-refresh failure (offline, character
fetch down) is not evidence about the assets scope.

Demo short-circuit (`:494-502`) and the demo character-switch path
(`:467-472`) need no shell edit; `apply_character` carries the assets
assignment (Section 10).

## 7. Grouping and search as pure functions (Builder B)

New file `src/ui/assets.rs`. All grouping, naming, and filtering logic is
in pure functions over plain data, unit-testable without egui — the
`compute_analytics` pattern (`src/ui/wallet.rs:39-78`). The egui rendering
in `show` is a thin loop over their output.

### 7.1 Types and signatures

```rust
/// One display row: names already resolved, never a raw numeric ID.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct AssetRow {
    pub item_id: i64,
    pub display_name: String,
    pub type_name: String,
    pub quantity: i64,
    pub location_flag: String,
    pub is_singleton: bool,
    pub is_blueprint_copy: bool,
    pub has_custom_name: bool,
}

/// All assets at one location, with counts for the group header.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct AssetLocationGroup {
    pub location_id: i64,
    pub location_name: String,
    pub rows: Vec<AssetRow>,
    pub item_count: i64,   // sum of quantities
    pub type_count: usize, // rows in this group
}

pub fn display_name(item: &AssetItem, custom_names: &HashMap<i64, String>,
                    resolver: &NameResolver) -> (String, String);
pub fn group_assets(data: &AssetsData, resolver: &NameResolver)
    -> Vec<AssetLocationGroup>;
pub fn filter_groups(groups: &[AssetLocationGroup], query: &str)
    -> Vec<AssetLocationGroup>;
```

`item_id` and `location_id` are carried for grouping, sorting, and stable
identity in tests. They are never rendered; every rendered string comes
from `display_name`, `type_name`, or `location_name`.

### 7.2 Rules

`display_name` returns `(display, type_name)`:

- `type_name` is always `resolver.name(item.type_id)` (`Unknown Item` when
  unresolved).
- If `custom_names` holds a non-empty name for `item.item_id`, that name is
  the display name (a named ship shows its name first — the Flutter
  `customName ?? typeName` rule). Otherwise the display name is
  `type_name`. The shell already filtered empty and `"None"` names out of
  the map (Section 6.3), and demo loading applies the same filter
  (Section 10), so this function does not re-filter.
- When `item.is_blueprint_copy == Some(true)`, the display name gains the
  suffix `" (copy)"`. `None` and `Some(false)` add nothing. This is the
  one display improvement `is_blueprint_copy` buys in this slice.
- `group_assets` sets `AssetRow.has_custom_name` from the same lookup
  (true exactly when a custom name won), so the view never re-derives it
  by comparing strings.

`group_assets`:

- Groups by `location_id` (the Flutter rule). Iteration starts from a
  `BTreeMap` so the build is deterministic before the display sort.
- `location_name` is `resolver.location_name(location_id)` — `Unknown
  Location` for player structures ESI refuses and for parent-item locations
  (decision D8). Never format the ID into the string.
- Rows inside a group sort by `display_name` ascending, then `item_id`
  ascending as the tiebreak.
- `item_count` is the sum of `quantity` over the group's rows (saturating
  addition is unnecessary; quantities are pilot-scale, but use `i64` sum
  directly as Flutter did). `type_count` is `rows.len()`.
- Groups sort by `item_count` descending (Flutter parity), then
  `location_name` ascending, then `location_id` ascending, so equal-size
  groups — including several `Unknown Location` groups — have a stable,
  testable order.

`filter_groups` uses `widgets::matches_search`
(`src/ui/widgets.rs:129-131`, empty query matches everything):

- Empty query returns the groups unchanged.
- A group whose `location_name` matches keeps all of its rows.
- Otherwise a group keeps only rows whose `display_name` or `type_name`
  matches (checking both preserves the Flutter behaviour where searching a
  ship type still finds a renamed ship). Groups left with no rows drop out.
- Counts are recomputed from the kept rows on every returned group. This
  is the explicit fix for the Flutter stale-`itemCount` defect in
  Section 2: the header `{type_count} item types, {item_count} total
  items` always describes the rows actually shown.

## 8. The Assets view (Builder B)

`pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver:
&NameResolver)` in `src/ui/assets.rs`, registered by adding
`pub mod assets;` to `src/ui/mod.rs` (currently six modules, `:1-6`).
Structure copies `ui::wallet::show` (`src/ui/wallet.rs:80-313`):

1. `ui.heading("Assets")`, then `widgets::mode_notice(ui, state.demo,
   state.offline)` (`src/ui/widgets.rs:166-178`).
2. No active character → `widgets::no_character_panel(ui)` and return.
3. Scope guidance wins over everything below: when
   `state.assets_needs_reauthorize` is true, render the guidance panel in
   Section 9 and return. (In demo mode the flag is always false.)
4. Clone `state.assets` into a snapshot so the search box can mutably
   borrow `state` while rows render from the snapshot, exactly as the
   wallet does at `:87-88`.
5. Match the snapshot:
   - `Ready(data)` with no items → `widgets::empty_panel(ui, "No assets
     yet. Press Ctrl+R (or Refresh) after signing in.")`.
   - `Ready(data)` → search box first:
     `widgets::search_box(ui, &mut state.assets_search, "Filter assets by
     item or location (press / to focus)", state.focus_search)` with the
     same `text_input_focused` / `focus_search` bookkeeping as the wallet
     (`:114-123`). Then `let groups = filter_groups(&group_assets(&data,
     resolver), &state.assets_search)`. No surviving groups →
     `empty_panel(ui, "No assets match the search.")`. Otherwise, for each
     group, a heading `"{location_name} — {type_count} item types,
     {item_count} total items"`, then one line per row:
     `"{display_name} x{quantity}"`, plus `" ({type_name})"` when the
     row's `has_custom_name` is true (computed once in `group_assets`, so
     the view does no string surgery). No value, price,
     icon, sorting control, or detail pane (Flutter had none either).
   - `Loading` → `widgets::loading_panel(ui, "Loading assets...")`.
   - `Empty` → `widgets::empty_panel(ui, "No assets data yet.")`.
   - `Error(e)` → `widgets::error_panel_with_retry(ui, &e)`
     (`src/ui/widgets.rs:150-157`); on click, log
     `tracing::warn!("[ASSETS] retry requested after load error")` and set
     `state.retry_requested = true`, mirroring the wallet arm (`:306-311`).
     Retry re-runs the global refresh, which is the correct recovery for a
     transient failure. The scope failure never reaches this arm because
     step 3 intercepts it, so the view cannot offer a retry that loops
     straight back into the same 403 with no explanation.

Also in Builder B's settings edit: `LOG_TAGS` in `src/ui/settings.rs:7-17`
grows from `[&str; 9]` to `[&str; 10]` with `"[ASSETS]"` inserted so the log
filter can isolate this feature. The existing settings test only asserts
membership of `"[WALLET]"` (`:197`); add the same assertion for
`"[ASSETS]"`.

## 9. Missing scope: honest step-up guidance

The only scope the slice needs is `esi-assets.read_assets.v1`. It is
already declared as a progressive step-up scope in `WALLET_SCOPES`
(`src/config.rs:48-53`) and is deliberately absent from `FIRST_AUTH_SCOPES`
(Section 1). Nothing in this slice requests it at sign-in and nothing
changes `src/config.rs`.

Failure path, end to end:

1. The first assets page request with a first-auth-only token returns HTTP
   403. `EsiClient::send` maps it through `EsiError::from_status` to
   `EsiError::Reauthorize` (`src/error.rs:42`) — observed behaviour of the
   existing client, covered by its mock test
   `status_errors_map_to_typed_errors` (`src/esi/client.rs:397-403`).
2. `get_assets` propagates it; the shell's tolerant block classifies it with
   `endpoints::needs_reauthorize(&e)` and the `Refreshed` message carries
   `assets_needs_reauthorize = true` (Section 6.3). Skills, wallet,
   and character data from the same refresh are applied normally.
3. The Assets view renders this guidance instead of rows, a spinner, or a
   retry button (wording is the contract; minor copy edits are fine as
   long as all four facts survive):

   > **Assets need one more EVE permission.**
   > This character has not granted `esi-assets.read_assets.v1`, the EVE SSO
   > scope that lets Mimir read the character asset list. No asset data was
   > loaded, and your other views are unaffected.
   > Granting extra scopes after first sign-in (step-up sign-in) is not in
   > this build yet, so this view stays empty for this character until that
   > follow-up lands. Demo mode (Settings) shows the full Assets view with
   > sample data.

Rules that keep this honest:

- No fake data: the guidance state never falls back to demo rows, an empty
  `Ready` dressed up as success, or another character's assets.
- No dead-end that looks broken: the panel names the exact scope, says
  other views are unaffected, and says what would unblock it.
- No fake affordance: no "Re-authorize" button is rendered, because this
  slice does not implement the flow behind it (decision D4). A button that
  only re-runs first-auth sign-in would loop back to the same 403.
- No retry loop: `Retry` is not shown in this state. Refreshing re-attempts
  the assets fetch once per user-triggered refresh, which is correct — if
  the stored token is ever replaced by a scoped one (the follow-up flow),
  the next refresh succeeds and the flag clears (Section 6.3 `Ok` arm).
- The 401 variant (`EsiError::Unauthorized`, token missing or expired past
  refresh) also sets the flag via `needs_reauthorize`; the same panel is
  acceptable there because re-sign-in is also its real remedy. Rate-limit
  and 5xx failures do not set the flag and take the normal error path.

Name resolution for type and location IDs (live path):

- `schedule_name_resolution` (`src/app/shell.rs:332-384`, integrator)
  gains one block beside the wallet block (`:341-357`): when
  `state.assets` is `Ready(data)`, push every item's `type_id`, and push
  `location_id` only when `!is_structure_id(location_id)` — the exact
  guard already used for wallet transaction locations (`:350-352`).
  Item IDs are never pushed: they are item instances, not universe
  entities, and `/universe/names/` cannot resolve them. Custom names are
  already in hand from `assets/names` and need no resolution.
- Everything downstream is unchanged: `resolver.missing` dedupes and
  drops session-unresolvable IDs, the spawn chunks by 1000, and
  `NamesResolved` extends the resolver and upserts `universe_names`
  (`:418-434`).
- Known limit, unchanged by this slice: player-structure locations
  (`location_id >= 1_000_000_000`) and parent-item locations (decision D8)
  render `Unknown Location`. The authenticated structure lookup
  (`get_structure_for_character`, `src/esi/endpoints.rs:255-271`) exists
  but wiring it into this scheduling path — it needs a character ID the
  current scheduler does not pass to structure lookups — is a named
  follow-up, not silent scope creep here.
- Demo mode is untouched: `schedule_name_resolution` returns early
  (`:333-335`) and demo display names come from `assets/demo/names.json`
  through `demo_resolver` / `ensure_demo_names`
  (`src/app/shell.rs:744-760`).

## 10. Demo fixtures (Builder B)

Demo mode must show the complete Assets feature offline, and the extension
must not break the existing fixture pipeline. The `DemoBundle` struct
itself (`src/demo/data.rs:85-90`) is unchanged — it still maps character
IDs to `DemoCharacterData` — and the extension lives inside
`DemoCharacterData` and the loader below. Current pipeline:
`load_demo_bundle()` passes three `include_str!` constants to
`load_demo_bundle_from(characters, skillqueue, wallet)`
(`src/demo/data.rs:22-25,138-182`), per-character entries land in
`DemoCharacterData` (`:74-83`), `validate_bundle` enforces bundle
guarantees (`:188-248`), and `apply_character` copies one character into
the view states (`:418-457`).

### 10.1 New fixture file

New file `assets/demo/assets.json`, keyed by character-ID string exactly
like `assets/demo/wallet.json`, reusing the ESI model shapes directly:

```json
{
  "90000001": {
    "assets": [
      {"item_id": 710000001, "type_id": 34, "quantity": 150000,
       "location_id": 60003760, "location_flag": "Hangar",
       "is_singleton": false},
      {"item_id": 710000002, "type_id": 587, "quantity": 1,
       "location_id": 60003760, "location_flag": "Hangar",
       "is_singleton": true}
    ],
    "custom_names": [
      {"item_id": 710000002, "name": "Aria's Rifter"}
    ]
  }
}
```

Content requirements for both fictional characters (Aria Voss `90000001`,
Marcus Hale `90000002` — the existing demo cast in
`assets/demo/characters.json`): at least two distinct locations each
(so grouping is exercised), at least one stacked item (`quantity > 1`),
at least one singleton with a custom name, at least one singleton whose
custom name is `"None"` or absent (so the filter rule is exercised), and
at least one item with `"is_blueprint_copy": true`. All item IDs are
invented; no real player data, matching the demo module contract
(`src/demo/data.rs:1-6`).

Every `type_id` and station `location_id` used in the fixture must have a
row in `assets/demo/names.json` (the two existing stations `60003760`
Jita and `60011866` Amarr may be reused). This keeps the demo's
no-raw-ID guarantee testable in the same style as
`name_resolution_covers_every_demo_id_and_falls_back_safely`
(`tests/demo_seed.rs:131-188`).

### 10.2 Loader changes, backwards compatible

- `pub const DEMO_ASSETS_JSON: &str = include_str!("../../assets/demo/assets.json");`
  beside the other constants (`:22-25`).
- `DemoCharacterData` gains `pub assets: Vec<AssetItem>` and
  `pub custom_names: Vec<AssetName>` (raw rows as parsed; the map is built
  in `apply_character`). `Default` covers characters with no assets entry.
- File-entry struct, mirroring `WalletFileEntry` (`:116-126`):

  ```rust
  #[derive(serde::Deserialize, Default)]
  struct AssetsFileEntry {
      #[serde(default)] assets: Vec<AssetItem>,
      #[serde(default)] custom_names: Vec<AssetName>,
  }
  ```

  Because every model field also carries `#[serde(default)]`
  (Section 4.1), a fixture row may omit any field — including
  `is_blueprint_copy` and `location_type` — and still parse.
- Signature compatibility is a hard requirement: the existing
  three-argument `load_demo_bundle_from(characters, skillqueue, wallet)`
  is kept working with its current meaning (a bundle with no assets).
  Implement it as a thin wrapper over a new four-argument
  `load_demo_bundle_with_assets(characters, skillqueue, wallet, assets)`
  passing `"{}"` for the assets text; `load_demo_bundle()` calls the
  four-argument form with `DEMO_ASSETS_JSON`. Existing three-argument
  test literals — including `malformed_and_invalid_bundles_are_errors_not_panics`
  (`:755-765`) — compile and pass unchanged, which is the executable proof
  that existing fixtures still parse. The four-argument parser adds one
  loop beside the skills and wallet loops (`:148-163`): parse
  `HashMap<String, AssetsFileEntry>`, `parse_character_key` each key, and
  move the rows into the character's slot.
- `validate_bundle` must not require assets (old literals carry none).
  It gains checks only over assets that are present: `item_id` values are
  unique within a character. Duplicate detection failure uses the existing
  `fail(...)` helper. Custom names pointing at unknown item IDs are not a
  validation error — they are ignored when the map is built, mirroring how
  a live names response could name an item no longer in the list.
- `apply_character` (`:418-457`) gains three lines of behaviour after the
  wallet assignment: build the custom-name map from `per.custom_names`
  applying the same non-empty, not-`"None"` filter as the live path
  (Section 6.3); set `state.assets = LoadState::Ready(AssetsData { items:
  per.assets.clone(), custom_names })` when `per.assets` is non-empty,
  else `LoadState::Empty`; always set
  `state.assets_needs_reauthorize = false` (demo never lacks scope).
- `seed_demo_state`'s bundle-failure arm (`:518-523`) adds
  `state.assets = LoadState::Error(...)` with the same message as the
  skills and wallet assignments beside it.
- `seed_bundle_into_db` (`:530-649`) persists nothing for assets — there
  is no table (decision D7). Add a one-line comment at the per-character
  loop saying assets are in-memory only in this slice so the omission
  reads as deliberate. No repository call is added.
- All new demo logging uses `[DEMO]`: the loop logs at debug in the
  existing style (`[DEMO] … assets={} custom_names={}` per character is
  enough; do not log item-level detail).

## 11. File ownership and the frozen contract

The cross-builder contract is this document's Sections 4-5: the
`AssetItem` / `AssetName` field names and types, the three endpoint
signatures, the `AssetsData` shape, `View::Assets` with label `"Assets"`,
the `assets` / `assets_search` / `assets_needs_reauthorize` field names,
and the `BackendMsg::Refreshed` extension in Section 6.3. Builders code
against those names exactly; renaming any of them mid-build is an
integrator decision announced to both builders, not a local edit.

| File | Owner | Contents |
|---|---|---|
| `src/esi/models.rs` | Builder A | `AssetItem`, `AssetName` (Section 4.1) plus their in-file unit tests |
| `src/esi/endpoints.rs` | Builder A | `get_assets_page`, `get_assets`, `get_asset_names` (Section 4.2) plus in-file mock-server unit tests |
| `tests/fixtures/assets.json` | Builder A | Invented ESI-shaped payloads: one asset list page (stacked item, singleton, blueprint copy with and without `is_blueprint_copy`) and one names array, in the style of the existing fixtures |
| `src/app/state.rs` | Builder B | Sixth view, `AssetsData`, `AppState` fields, lifecycle edits (Section 5) |
| `src/ui/assets.rs` | Builder B | Pure grouping/search functions (Section 7), `show`, guidance panel (Sections 8-9) |
| `src/ui/mod.rs` | Builder B | `pub mod assets;` only |
| `src/ui/settings.rs` | Builder B | `[ASSETS]` in `LOG_TAGS`, `1-6` keyboard help |
| `src/ui/widgets.rs` | Builder B | `1-6` string in `no_character_panel` only |
| `src/demo/data.rs` | Builder B | Demo loader, validation, `apply_character` (Section 10) |
| `assets/demo/assets.json` | Builder B | New demo fixture (Section 10.1) |
| `assets/demo/names.json` | Builder B | Rows added for every demo asset type/location ID; existing rows untouched |
| `tests/esi_models.rs` | Builder B | Parse test over `tests/fixtures/assets.json` |
| `tests/demo_seed.rs` | Builder B | Demo-assets bundle, name-coverage, and seed/switch assertions |
| `src/app/shell.rs` | Integrator | Keyboard, dispatch, tolerant refresh, resolver scheduling (Sections 6, 9) |
| `src/main.rs` | Integrator | No change expected; integrator verifies the build and says so in the handoff |

Forbidden to both builders in this slice (each was inspected and needs no
edit): `src/config.rs` (scope hard rule), `src/storage/schema.sql`,
`src/storage/db.rs`, `src/storage/repositories.rs` (no-migration hard
rule), `src/esi/client.rs` (`auth_post` and `X-Pages` handling already
exist), `src/error.rs` (the typed 403 already exists),
`src/auth/oauth.rs` (step-up is a follow-up), `src/names/resolver.rs`
(the synchronous lookups already guarantee the no-raw-ID rule),
`Cargo.toml` / `Cargo.lock` (no new dependency is needed; a missing crate
is a stop-and-report, not a local edit).

Merge order: Builder A first (Builder B's state and demo code name
`AssetItem` / `AssetName`, so B only compiles against A's models), then
Builder B, then the integrator's `shell.rs` wiring last. Between B and
integration the tree compiles but `View::Assets` is not reachable (the
dispatch arm is the integrator's) and the shell still calls the
five-field `Refreshed` shape; that intermediate state is expected, is
never merged to `develop`, and the branch lands whole.

## 12. Explicit non-goals

None of the following is built in this slice. Anything that looks like it
"almost works for free" still stops at the boundary and is reported as a
follow-up.

- Database persistence or schema migration for assets (no assets table,
  no `load_cached_state` assets block, no offline live asset cache).
- Asset valuation: no market prices, no per-location or total ISK value,
  no `totalValue` equivalent, no snapshots or history.
- The step-up OAuth flow implementation: no scoped `start_login` variant,
  no scope-payload request flag, no token-scope union logic. The view's
  guidance panel (Section 9) is the entire step-up surface of this slice.
  The follow-up will use `create_authorization_request_with_scopes`
  (`src/auth/oauth.rs:220-232`) with the union of the stored
  `token_meta.scopes` and `esi-assets.read_assets.v1`.
- `POST /characters/{id}/assets/locations/` (decision D2) and any 3-D
  position display.
- Corporation assets (`esi-assets.read_corporation_assets.v1`) — a
  separate Flutter feature, out of this personal-assets slice.
- Container/ship hierarchy expansion, parent-name derivation, and any
  `containedInId` equivalent (decision D8).
- Authenticated structure-name resolution for asset locations beyond what
  the existing scheduler already does (Section 9 names the follow-up).
- Periodic or timer-based asset refresh (Flutter had none; the global
  manual/startup refresh is the only trigger).
- Sorting controls, item detail view, item icons, and multi-character
  asset aggregation (the active character only, as in Flutter).

## 13. Test plan and gates

Repo gates (`.github/workflows/ci.yml`, `CLAUDE.md` commands) must all
pass on the integrated branch: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build`.
Builder unit tests live in the files they cover, matching how the repo
already splits in-file unit tests from `tests/` integration tests.

Builder A (in `src/esi/models.rs` and `src/esi/endpoints.rs`):

- Model parse tests in the existing in-file style: a full `AssetItem`
  JSON row, a `{}` row defaulting cleanly, `is_blueprint_copy` as `true`,
  `false`, `null`, and absent, and an `AssetName` row.
- `assets_walks_all_pages`: copy the `journal_server` mock pattern
  (`src/esi/endpoints.rs:324-357`) with `page=` branching and
  `X-Pages: 2`, assert both pages' items arrive in order; reuse
  `client_with_fresh_tokens` (`:359-374`).
- `empty_asset_names_short_circuits`: `get_asset_names` with an empty
  slice against an unreachable base URL returns `Ok`, like
  `empty_resolve_names_short_circuits` (`:386-393`).
- `asset_names_post_parses`: mock server returns a names array; assert IDs
  and names parse and the captured request targets `assets/names` (reuses
  the capture style of `src/esi/client.rs` mock tests).
- Scope failure: mock 403 on the assets path makes `get_assets` return an
  error for which `needs_reauthorize` is true (one assertion beside
  `reauthorize_detection`, `:395-401`).

Builder B (`src/ui/assets.rs`, `src/app/state.rs`, `src/demo/data.rs`,
`tests/esi_models.rs`, `tests/demo_seed.rs`):

- `grouping_sorts_counts_and_never_shows_raw_ids`: hand-built `AssetsData`
  over at least two locations with a fixed resolver (the wallet test
  builds one with `resolver.insert`, `src/ui/wallet.rs:335-337`); assert
  group order (`item_count` desc), per-group counts, row order, custom
  name beats type name, `" (copy)"` suffix on the blueprint copy only,
  and that no `display_name`, `type_name`, or `location_name` parses as
  `i64` or equals a raw-ID string — with an empty resolver every name is
  `Unknown Item` / `Unknown Location`.
- `filter_recomputes_counts`: location-name match keeps all rows;
  item-name match keeps only matches with recomputed `type_count` /
  `item_count`; type-name match still finds a custom-named row; empty
  query is the identity; a query matching nothing returns no groups.
- State tests from Sections 5.1 and 5.3 (six-way navigation, `assets`
  empty after last character removal, flag cleared on removal).
- Demo tests: `bundled_fixtures_load_and_validate` extended so every demo
  character has non-empty `assets`; a three-argument
  `load_demo_bundle_from` literal still loads with empty assets (the
  backwards-compatibility proof); duplicate demo `item_id` fails
  validation; `"None"` custom names never reach `AssetsData`.
- `tests/demo_seed.rs`: every demo asset `type_id` and station
  `location_id` resolves through `demo_resolver` (extending the loops at
  `:159-173`), `apply_character` puts `LoadState::Ready` assets with the
  right rows for Aria, and switching to Marcus swaps them (extending
  `:191-227`).
- `tests/esi_models.rs`: parse `tests/fixtures/assets.json` into
  `Vec<AssetItem>` and `Vec<AssetName>` with field assertions, beside the
  existing fixture tests; the `{}`-tolerance test (`:127-136`) gains an
  `AssetItem` case.
- Settings test: `LOG_TAGS` contains `"[ASSETS]"`.

Integrator (after both builders merge):

- Full gates above, plus a grep that `src/config.rs`,
  `src/storage/schema.sql`, and `FIRST_AUTH_SCOPES` are untouched in the
  branch diff (`git diff develop...HEAD -- src/config.rs
  src/storage/schema.sql` is empty).
- Demo smoke check by the repo's existing demo test path
  (`cargo test --test demo_seed`) — no display needed.
- Live smoke limit, stated plainly in the handoff: a true live asset load
  cannot be exercised until a character token carries
  `esi-assets.read_assets.v1`, which no current sign-in path grants
  (decision D4). The mock-server tests and the demo path are the
  verifiable surfaces; claiming a live verification without a scoped
  token would be a false claim.

Acceptance checklist for the slice: sixth view reachable by key `5` and
the rail, Settings on key `6` with its persisted startup choice intact;
demo mode shows both characters' grouped, searchable assets with resolved
names and no numeric string anywhere in a name cell; a first-auth-only
live character keeps working skills/wallet after refresh and sees the
Section 9 guidance in Assets; logs show `[ASSETS]` fetch lines and never
a token value.

## 14. Risks and unresolved items

- Live ESI payload shape is inferred, not live-verified: the
  `is_blueprint_copy` nullability and the presence of `location_type` on
  the asset list come from the historical Flutter models and the
  context-library assets specification, not from a captured live
  response. `#[serde(default)]` on every field bounds the damage to a
  wrong default, never a parse failure, and Builder A's fixture must
  include rows with each field absent to keep that true.
- Asset fetches can be long (many 1000-item pages plus name batches on a
  veteran character) and in this slice they delay the single
  `Refreshed` message, so first paint of fresh skills/wallet waits for
  assets too. Accepted for parity with Flutter's single sync; splitting
  assets into its own `BackendMsg` is the named remedy if the delay is
  felt, and ESI's own one-hour assets cache bounds repeat cost.
- A character-switch race already exists for skills/wallet (the
  `Refreshed` arm does not check `character_id` against the active
  character); Assets inherits it unchanged through the same message
  rather than introducing a second, inconsistent guard.
- Structure and parent-item locations will read `Unknown Location` until
  the Section 9 and D8 follow-ups land. That is a visible but honest
  limit; the alternative — guessing a name — is what the no-raw-ID rule
  exists to prevent.






# Rust Industry read-only slice — design

Status: locked design for implementation. This document is the only
product of its branch; no Rust, fixture, or database change ships
with it. Builders and the integrator implement exactly what is
written here and treat deviations as design changes to be raised,
not choices to be made silently.

Base: `develop` at `afa6c10` (conversion #561, Assets #562,
step-up #563, JWT #564, character detail #565, Market #566 all
merged). The retired Flutter app at `ed698d3` is behavioral
evidence only, read through git history; no Dart file is restored.

## 1. What this slice is

A new read-only **Industry** view showing, for the **active
character only**:

1. Character industry jobs — what is running, paused, ready, or
   recently finished, with the blueprint or product name, the
   activity in words, the status in words, the facility name, and
   a finish countdown with a progress bar for running jobs.
2. The character blueprint library — every blueprint the character
   owns, searchable by resolved type name, filterable to originals
   or copies, sorted by resolved type name, with material and time
   efficiency, run information in words where ESI uses sentinel
   values, and the resolved location name.

Everything is in-memory only. There is no database schema
migration, no persistence of industry rows, and no ESI write of
any kind: this slice never starts, cancels, pauses, or delivers a
job, and it computes no manufacturing, invention, reaction, cost,
profit, or material figure. Both sections sit behind one additive
pair of read scopes granted by the existing step-up flow; first
sign-in never requests them, and one section refusing for scope
reasons degrades only that section.

### 1.1 Hard scope (verbatim constraints, binding on all builders)

- Read-only industry slice only: character industry jobs plus the
  character blueprints library. Nothing else industry-shaped
  ships in this slice.
- NO ESI writes ever: no starting, cancelling, pausing, or
  delivering jobs. No new `auth_post` or `public_post` call site
  exists in this slice at all.
- NO manufacturing, invention, reaction, or production-chain
  calculator, and no cost, profit, material-requirement, or
  probability math of any kind. Fetched cost and probability
  fields parse and are carried, but are never rendered and never
  enter a computation.
- NO planetary industry (a separate retired Flutter feature with
  its own scope; section 13 names the boundary), and NO
  corporation industry jobs or corporation blueprints.
- NO database schema migration; in-memory state only, exactly as
  Assets, character detail, and Market already work.
- NO widening `FIRST_AUTH_SCOPES` (`src/config.rs:33-39` stays
  byte-identical). Step-up is one additive constant reusing the
  generic `StepUpRequest`; the step-up flow itself does not
  change.
- Blueprint `quantity` sentinel values `-1` and `-2` and
  blueprint `runs` sentinel value `-1` render as words, never as
  raw counts (section 7.3 locks the exact words). Any integer sum
  uses saturating arithmetic with negative inputs clamped first
  (the market convention, `src/ui/market.rs:72-77`).
- The interface shows resolved EVE names only: never a raw
  numeric ID in a rendered string or in error text. New section
  errors are fixed per-section wording, with full error detail
  only in `tracing` warn logs (the character-detail and Market
  repair pattern).
- Rust logging via `tracing` with bracketed tags: `[INDUSTRY]` is
  new in this slice; `[ESI]`, `[UI]`, `[AUTH]`, and `[DEMO]`
  already exist. Never log or print token values, authorization
  codes, state values, or authorize URLs.
- No push and no merge is part of this design task, and no
  attribution line appears in any commit or file.

## 2. Evidence base (what was inspected, and what it forces)

Every claim below rests on a file body read for this design on
`develop` at `afa6c10`, on a retired-Flutter body read through
`git show ed698d3:<path>`, or on the mimir context-library
specification body read at `/tmp/mimir-context-library`. Nothing
here rests on a filename, a search hit, or a summary alone.

### 2.1 Rust tree, as it stands today

- There is **no industry code in the Rust tree at all**. A
  case-insensitive search over `src/` and `tests/` for `industry`
  finds nothing, and `blueprint` finds only the assets copy marker
  `AssetItem.is_blueprint_copy: Option<bool>`
  (`src/esi/models.rs:414`, rendered as a `" (copy)"` suffix in
  `src/ui/assets.rs:48-50`). Both endpoints, both models, the
  state bundle, and the view are new.
- `src/config.rs` (213 lines, read in full).
  `FIRST_AUTH_SCOPES` at lines 33-39 holds five scopes and no
  industry scope. Additive step-up constants to mirror are
  `ASSETS_SCOPES` (line 64, one scope), `MARKET_SCOPES` (line 69,
  one scope), and `CHARACTER_DETAIL_SCOPES` (lines 74-80, five
  scopes), each pinned by a test asserting the exact set and its
  absence from first-auth (lines 155-192; the multi-scope
  disjointness loop at lines 186-191 is the pattern a two-scope
  constant copies). `EveConfig::scopes_string` (lines 121-123) is
  the join helper. No `INDUSTRY_SCOPES` exists.
- `src/esi/client.rs` (753 lines; read lines 1-385 in full).
  `EsiMeta { pages, error_limit_remain, error_limit_reset_secs }`
  is at lines 24-29; `send()` parses the `x-pages` header into
  `EsiMeta.pages` (lines 256-260), strips the request URL from
  transport errors with `without_url()` (lines 250-253), and
  keeps the path out of decode error text (lines 280-285) — the
  single boundary that keeps numeric IDs out of rendered errors.
  `build_url` (lines 170-179) appends `datasource=tranquility`
  with `&` when the path already contains `?`, so a query
  parameter such as `include_completed` must be embedded in the
  path string (the precedent is `get_wallet_transactions_from`
  embedding `?from_id=` in `src/esi/endpoints.rs:143-146`, and
  the market paths embedding `?type_id=` at lines 281 and
  345-347). The only seams new endpoints may use are
  `public_get` (line 290), `public_get_page` (lines 296-307),
  `auth_get` (lines 321-328), and `auth_get_page` (lines
  330-346, which takes `Option<u32>` page and attaches the
  character's access token with auto-refresh; the token value is
  never logged).
- `src/error.rs` (191 lines, read in full). HTTP 401 maps to
  `EsiError::Unauthorized` and 403 to `EsiError::Reauthorize`
  (lines 41-44), which `endpoints::needs_reauthorize`
  (`src/esi/endpoints.rs:572-578`) tests as one typed predicate.
  `EsiError::NoTokens(i64)` deliberately renders without the
  number (lines 25-28), pinned by the regression test at lines
  184-190. Industry needs no error-type change.
- `src/esi/endpoints.rs` (1015 lines; read lines 1-600 in
  full, including the mock-server test harness opening at line
  580). Two page-walk shapes exist.
  Uncapped: `get_wallet_journal` (lines 83-124) and `get_assets`
  (lines 189-227) loop `auth_get_page` until `page >= meta.pages`
  or an empty page, and any page error propagates so partial
  lists are never returned as success. Capped with a disclosed
  truncated flag: `MARKET_MAX_PAGES: u32 = 10` (line 261), public
  `get_regional_orders` / `get_character_orders` delegating to
  private helpers that take an explicit `max_pages` so tests can
  use a budget of 2 or 3 (lines 266-331 and 362-426). The
  truncated rule in both helpers is identical: stop clean when
  `meta.pages` is `Some(total)` and `page >= total`, or when it
  is `None` and the page is empty; set `truncated` when the walk
  stops at the cap while more pages may exist (a `Some` total
  above the cap, or a non-empty page landing exactly on the cap
  with no header). Per-endpoint logging is a bracketed-tag debug
  line for the route and each page, plus one info line with the
  row count at completion. `resolve_names` (lines 479-487) is the
  existing `POST /universe/names/` lookup; this slice adds no
  POST site.
- `src/esi/models.rs` (724 lines; read lines 380-724). Every
  struct is `#[derive(Debug, Clone, Default, Serialize,
  Deserialize)]` with `#[serde(default)]` on every field, unknown
  fields ignored, and `Option<T>` for nullable fields
  (`CharacterOrder.escrow: Option<f64>`, lines 490-491).
  `AssetItem` (lines 397-415) and the three market models (lines
  431-510) are the shapes new industry models copy, including
  their parse tests (full row, `{}` defaults, unknown extra
  fields, null optionals; lines 557-714).
- `src/app/state.rs` (1049 lines, read in full). `View` has
  exactly seven variants (lines 15-37: Dashboard, Characters,
  Skills, Wallet, Assets, Market, Settings), keys 1-7, with
  `label()`, `from_index`, `index`, `next`, and `previous` all
  derived from `ALL` (lines 39-66). `LoadState<T>` is Loading,
  Ready, Empty, Error (lines 68-100). `SectionError { message,
  needs_reauthorize }` and `SectionResult<T>` (lines 216-225)
  carry the typed scope outcome, never parsed from the message.
  `CharacterDetailData` (lines 230-254) is seven independent
  section results whose `needs_detail_stepup()` is true when any
  protected section failed for scope reasons; `MarketData`
  (lines 285-291) is the same composition with three sections
  plus a selection identity. `StepUpRequest::new(character_id,
  scopes)` (lines 137-149) is the generic request any view may
  set. `AppState` (lines 371-429) holds per-view load states,
  view-local search strings, and request flags. Reset rules this
  slice must mirror exactly: `set_active_character` (lines
  493-547) resets assets, character detail, and market rows to
  Loading only when the previous character differs and keeps
  them on same-character reselect; `remove_character` (lines
  570-613) does the same when the removed character was active
  (placed before the replacement `set_active_character` call,
  whose previous-is-None path cannot detect it), unconditionally
  clears `assets_needs_reauthorize` and a pending step-up that
  named the removed character, and sets every per-view state to
  Empty when no characters remain. Tests at lines 706-795 and
  999-1039 pin these semantics for assets, detail, and market.
- `src/app/shell.rs` (1959 lines; read lines 1-180, 400-1100,
  1035-1330, 1419-1959, with the remaining ranges located by
  targeted search). `BackendMsg` (lines 38-73) carries one
  `Refreshed` bundle with a tolerant assets result plus a
  `CharacterDetailData`, and two market variants
  (`MarketFetched`, `MarketLookupDone`) for the on-demand path.
  `start_refresh` (line 1035) fetches character, skills, queue,
  and wallet with `?` (a failure there fails the whole refresh),
  then assets (lines 1069-1118) and the seven detail sections
  (lines 1119-1189) as tolerant sub-fetches: never `?`, each
  mapped to a fixed-wording `SectionError` such as "attributes
  request failed" with `needs_reauthorize:
  endpoints::needs_reauthorize(&e)`, full detail only in a
  bracketed-tag warn log. Only character, skills, and wallet are
  persisted (lines 1214-1307); assets, detail, and market are
  in-memory only. The `Refreshed` drain arm (lines 529-607)
  inserts the summary only when the character is still present,
  applies per-view states only when `active_character_id ==
  character_id`, and otherwise drops them with a warn log; the
  assets arm clears its reauthorize flag on Ok, replaces rows
  with Error on a scope refusal, and keeps Ready rows on other
  errors. `RefreshFailed` (lines 644-673) ignores inactive
  characters and otherwise sets Error only where a view is not
  Ready. `start_market_fetch` (line 859) is the contrasting
  on-demand path: it exists because market data is keyed by a
  user-changing type and region selection and must work with no
  character at all; its identity guard is
  `market_result_matches` (lines 132-137, generation plus type
  plus region plus active character). The generic step-up drain
  at lines 797-799 takes `state.stepup_requested` into
  `start_stepup_login` (line 1419), which is fully generic over
  the request's scopes: granted-scope pre-check via
  `oauth::split_scopes` / `missing_scopes` / `union_scopes`
  (`src/auth/oauth.rs:82`, `:114`, `:95`), an already-granted
  shortcut that refreshes instead of opening a browser, JWT
  verification before any claim is read, expected-character
  validation, a full-scope-retention check, and a save-time
  re-check that the character still exists. The authorize URL,
  state value, code, and token values are never logged on this
  path (lines 1542, 1560-1614). `StepUpLoggedIn` (lines 685-713)
  requests a normal refresh and deliberately clears no
  reauthorize state; only a later successful fetch does.
  `schedule_name_resolution` (lines 400-523) returns early in
  demo mode, collects IDs from every Ready bundle behind the
  `is_structure_id` guard for location-class IDs, never
  schedules instance IDs (ship item and jump clone IDs are
  called out at line 437; market order, region, and system IDs
  at lines 471-475), dedups through `resolver.missing()`, and
  resolves in chunks of 1000. The startup view is persisted by
  label string, not number: read at lines 341-345 by matching
  against `View::ALL` labels (unknown labels ignored), written
  at lines 1753-1767. Keyboard view keys are the fixed array
  Num1-Num7 (lines 1687-1702); the rail heading says "Views
  (keys 1-7)" (line 1834), the status bar repeats "Keys: 1-7"
  (line 1871), and view dispatch is the exhaustive match at
  lines 1851-1861. `needs_tick` (lines 1737-1745) repaints once
  per second only while the skill queue has a finish date (or
  sign-in is busy).
- Views. The resolver-driven data views are
  `pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver)`
  (`src/ui/assets.rs:197`, `src/ui/characters.rs:17`,
  `src/ui/market.rs:557`), renders from a cloned snapshot so
  buttons can borrow `state` mutably, and keeps pure helpers
  above `show()` with in-module tests (`group_assets` and
  `filter_groups` at `src/ui/assets.rs:64-155`;
  `summarize_orders` and `character_order_rows` at
  `src/ui/market.rs:53-161`). `src/ui/assets.rs` (401 lines,
  read in full) is the whole-view-gate precedent: its
  `reauthorize_panel` (lines 159-195) runs before the load-state
  match and only sets `state.stepup_requested =
  Some(StepUpRequest::new(active_id, EveConfig::ASSETS_SCOPES))`,
  enabled when `!state.demo && !state.auth.is_busy() &&
  state.active_character_id.is_some()`. `src/ui/characters.rs`
  (755 lines; read lines 300-500) is the per-section precedent
  this slice follows instead: `section_error_label` (lines
  328-336) renders a scope failure as "Not authorized yet.
  Re-authorize above to load this section." when the panel is
  showing and other failures as "Could not load {section}:
  {message}"; `detail_reauthorize_panel` (lines 341-381) lists
  all its scopes via `EveConfig::CHARACTER_DETAIL_SCOPES`
  joined with spaces; and `show_character_details` (lines 385-412) shows the
  panel when `!state.demo && state.active_character_id.is_some()
  && bundle.needs_detail_stepup()`, then renders every section
  independently so one failure hides only its own lines.
  `src/ui/market.rs:453-491` repeats the panel inside a single
  section. Saturating arithmetic follows the market form, not
  the older assets form: `saturating_add(volume_remain.max(0))`
  (`src/ui/market.rs:72-77`), `saturating_sub(...).max(0)` in
  `filled_volume` (lines 120-124), history totals at lines
  179-184. `src/ui/assets.rs:57-60` saturates without the
  `.max(0)` clamp; for sentinel-bearing blueprint fields the
  market clamp-first form is the one to follow. Assets tests
  assert no rendered name parses as an integer (lines 338-356);
  industry copies that assertion shape.
- `src/ui/widgets.rs` (262 lines, read in full) provides
  `loading_panel`, `empty_panel`, `error_panel_with_retry`
  (returns whether Retry was clicked), `no_character_panel`,
  `mode_notice`, `search_box`, `matches_search` (case-insensitive
  substring, line 129), `format_date_short`,
  `seconds_until`, `countdown_label`, and `progress_fraction`
  (lines 75-126). `progress_fraction` already returns 0.0 for
  missing, unparseable, or non-positive spans and clamps to
  `0.0..=1.0`, which is exactly the guard the retired Flutter
  jobs panel lacked (section 2.2). Its `no_character_panel`
  hardcodes "Keys: 1-7 switch views" (line 162), one of the
  renumbering texts in section 10. `format_isk` (lines 7-30)
  renders non-finite input as "0.00 ISK"; industry renders no
  ISK figure anywhere, so that hazard does not arise.
- `src/ui/mod.rs` (8 lines) declares eight modules and no
  industry module. `src/ui/settings.rs` (201 lines, read in
  full) iterates `View::ALL` for the startup-view picker (lines
  85-100, so a new view becomes choosable with no settings
  logic change), hardcodes "1-7 views" in its keyboard help
  (line 112), and holds the log-filter tag list `LOG_TAGS`
  (lines 7-18, ten tags). Observed gap, recorded and left alone
  by this slice: `[MARKET]` is absent from `LOG_TAGS` today —
  the Market slice added the tag to logs but not to that list —
  so the industry design names its own `[INDUSTRY]` addition
  explicitly (section 10.2) instead of assuming it happens.
- `src/names/resolver.rs` (444 lines, read in full).
  `name(id)` falls back to "Unknown Item" (lines 132-141),
  `location_name(id)` to "Unknown Location" (lines 143-149),
  `cached(id)` and `category(id)` are at lines 111-122,
  `missing()` dedups, skips non-positive IDs, and skips
  session-unresolved IDs (lines 154-166), `is_structure_id` is
  `id >= 1_000_000_000` (lines 29-35), and `NAMES_BATCH_SIZE`
  is 1000 (line 25). `insert` rejects empty and purely numeric
  names (lines 84-93), so a numeric remote "name" can never
  become a rendered raw ID. There is no separate facility-word
  fallback; facilities use `location_name`, exactly like asset
  locations today.
- `src/demo/data.rs` (1481 lines; read lines 1-700 and
  700-980). Fixture constants are `include_str!` (lines 26-33):
  seven files exist under `assets/demo/` (characters,
  skillqueue, wallet, names, assets, character_detail, market)
  and none is an industry file. Loaders chain
  backwards-compatibly, each older arity delegating with `"{}"`:
  `load_demo_bundle_from` (3 arguments, line 210) →
  `load_demo_bundle_with_assets` (4, line 221) →
  `load_demo_bundle_with_detail` (5, line 239) →
  `load_demo_bundle_with_market` (6, line 258, the current full
  implementation), with `load_demo_bundle` (line 359) passing
  the bundled constants. `DemoCharacterData` (lines 98-109)
  gains one slot per slice; `DemoMarketData` (lines 86-94) is
  deliberately not `MarketData`, because seeding composes the
  live bundle with the character being applied. The
  per-character key loops use `parse_character_key` and slot
  insertion (lines 275-343). `validate_bundle` (lines 375-547)
  validates optional feature data only when present: unique IDs
  and parseable dates through `parse_esi_datetime` (lines
  594-598), with the shared `[DEMO] invalid demo bundle` message
  shape. `apply_character` (lines 729-836) installs Ready or
  Empty-if-absent per feature so a demo switch can never leave
  the previous character's bundle installed, and
  `seed_demo_state` (lines 841-936) sets `LoadState::Error` on
  every feature state in its failure arm (lines 929-933).
  `seed_bundle_into_db` records at lines 947-948 that assets,
  character detail, and market are in-memory only with nothing
  persisted. `demo_type_name` (lines 560-567) and
  `load_demo_names` (lines 550-555) serve the market selection
  word; industry needs no such helper (section 9.3 explains
  why). `assets/demo/names.json` already carries the demo
  characters, type 681 "Bantam Blueprint", types 34-37 and 587,
  and stations 60003760 and 60011866.
- Tests and fixtures. `tests/fixtures/` holds twelve files and
  no industry fixture. The shapes to mirror are
  `tests/fixtures/market.json` (read in full: one object keyed
  by row set, invented `71xxxxxx` instance IDs) and
  `tests/fixtures/assets.json` (which includes an empty-object
  row so `{}` defaults are exercised through the fixture path;
  `tests/esi_models.rs:128-150`). `tests/esi_models.rs` (189
  lines, read in full) parses each fixture with
  `parse(include_str!("fixtures/x.json"))` and asserts field
  values. `tests/demo_seed.rs` asserts resolved demo rendering
  per feature for both demo characters. Endpoint tests use
  in-module `TcpListener` mock servers keyed by the `page=`
  query with an `X-Pages` header
  (`src/esi/endpoints.rs:588-712`), a fresh-token client helper,
  and a 403 scope-failure test proving `needs_reauthorize`.
- `docs/market-port-design.md` (1802 lines, read in full) and
  `docs/character-detail-design.md` (1170 lines) are the
  structural precedents: this document copies their evidence,
  locked-decision, frozen-contract, ownership, non-goal, and
  test-plan structure, including the pre-authorized
  single-line shell dispatch exception for the UI builder.
- `README.md` (read in full) lists Market under "What works
  today" with keys 1-7 in the Settings bullet (line 20), and
  its roadmap still says "Industry & Planetary Industry:
  Blueprint browser, manufacturing calculator, PI management"
  (line 26). The integrator updates both (section 10.3); the
  calculator and planetary parts stay unimplemented and must
  keep reading as unshipped.
- `.github/workflows/ci.yml` (read in full) gates on `cargo fmt
  --check`, `cargo clippy --all-targets -- -D warnings`,
  `cargo test`, and `cargo build`, on Linux and again (test and
  build) on macOS.

### 2.2 Retired Flutter evidence (git history at `ed698d3`)

All twelve files under `lib/features/industry/` at `ed698d3`
were read in full for this slice, together with the industry
windows of `lib/core/network/esi_client.dart`, the scope lists
in `lib/core/config/eve_config.dart`, the Drift tables in
`lib/core/database/app_database.dart`, and the startup/manual
sync call sites. Nothing was restored. The facts that shape
this design:

- **Exactly two in-scope endpoints exist, and nothing writes.**
  `GET /characters/{id}/blueprints/` with a `page` query
  parameter (`esi_client.dart:298-315`) and `GET
  /characters/{id}/industry/jobs/` with an `include_completed`
  parameter defaulting to false at the client layer
  (`esi_client.dart:317-334`). A search of the client for
  corporation blueprint or job routes, `/industry/facilities/`,
  and `/industry/systems/` finds none, and every
  `authenticatedPost` call site belongs to another feature
  (fittings, autopilot waypoint, name resolution, asset names
  and locations). There is no Flutter code that starts,
  cancels, or delivers a job, so the read-only boundary here is
  a faithful port of the reachable surface, not a reduction.
- **The two read scopes, exactly spelled.** The phase-5
  expansion list (`eve_config.dart:107-112`, read directly)
  contains `'esi-characters.read_blueprints.v1'` for blueprints
  and `'esi-industry.read_character_jobs.v1'` for jobs,
  alongside `'esi-planets.manage_planets.v1'` (planetary
  industry, out of scope) and the market scope (already shipped
  as `MARKET_SCOPES`). Flutter requested every phase list at
  once at sign-in; that all-at-once bundle is exactly what the
  Rust progressive step-up model replaced, and is not copied.
- **DTO fields.** `BlueprintItem` (`esi_client.dart:1601-1637`)
  carries `item_id`, `type_id`, `location_id`, `location_flag`,
  `quantity`, `time_efficiency`, `material_efficiency`, `runs`,
  and a nullable `runs_remaining`. `IndustryJobData`
  (`esi_client.dart:1639-1715`) carries `job_id`,
  `installer_id`, `facility_id`, `location_id`, `activity_id`,
  `blueprint_id`, `blueprint_type_id`, `output_location_id`,
  `runs`, nullable `cost`, nullable
  `licensed_production_runs`, nullable `probability`, nullable
  `product_type_id`, `status`, `duration`, `start_date`,
  `end_date`, nullable `pause_date`, nullable
  `completed_date`, nullable `completed_character_id`, and
  nullable `successful_runs`. Flutter parsed with hard casts,
  so one missing field failed a whole list; Rust serde defaults
  (section 5.1) fix that deliberately.
- **Persisted-copy losses that in-memory Rust avoids.** The
  Drift tables (`app_database.dart:514-556`) dropped
  `location_flag` and `runs_remaining` on sync, renamed job
  `duration` to `timeInSeconds`, and coerced a null job cost to
  `0.0` (`industry_sync_service.dart:108`), erasing the
  unknown-versus-free distinction. Section 5.1 preserves
  nullability end to end and records which carried fields are
  never rendered.
- **Pagination and `include_completed` defects.** Blueprints
  paginated with a `do/while` over the `x-pages` header read
  once from the first response (`industry_sync_service.dart:
  20-43`, read directly): when the header was absent only page
  1 was ever fetched, silently. Jobs made one request and
  ignored `x-pages` entirely (`industry_sync_service.dart:
  83-92`). `includeCompleted` was inconsistent by trigger: the
  client and sync defaults were false (lines 79 above;
  `esi_client.dart:319`), the manual refresh provider forced
  true, and the startup sync used the default false — and
  because storage was replace-all per character, a startup sync
  could erase completed jobs a manual refresh had loaded.
  Section 5.2 locks one value used by the one fetch path, and
  one capped walk used by both endpoints.
- **Sentinels, as far as Flutter goes.** `runs == -1` meant an
  original blueprint: sync derived `isOriginal = (runs == -1)`
  with that comment (`industry_sync_service.dart:62-63`, read
  directly) and the library panel rendered the words "Infinite
  Runs" instead of a count. That word rendering is copied and
  extended in section 7.3. `quantity` was stored verbatim and
  never rendered, and a search for `quantity` handling of `-1`
  or `-2` across the tree finds none: Flutter neither confirms
  nor violates sentinel quantity display, so the quantity words
  in section 7.3 are new Rust behavior grounded in the
  specification evidence (section 2.3) and recorded as a risk
  (section 14). Job runs were rendered as a raw count with no
  clamp.
- **Jobs list behavior and defects.** The jobs panel read the
  provider that included completed jobs, ordered by end date
  descending at the repository layer, with no grouping, search,
  or sort controls. Its title rendered raw numeric IDs
  verbatim ("Job #… - Type …"); activity, facility, location,
  cost, probability, and installer were stored but never
  displayed; and its status switch had no case for `ready` and
  mapped every unknown status — including `reverted` — to
  "Cancelled". Progress divided elapsed time by the stored
  duration with no zero guard. Sections 7.1, 7.2, and 8 fix
  each of these rather than copying them; only the status and
  progress *concepts* carry over.
- **Blueprint library behavior and defects.** The library panel
  offered a search box plus mutually exclusive original/copy
  filter chips, but the search matched substrings of the
  numeric type ID (its own comment admits name search was
  unimplemented), the title rendered the raw type ID, rows were
  in insertion order with no sort, and quantity and location
  were never shown. Section 7.4 keeps the search and
  original/copy concepts and fixes the rest: search matches
  resolved names, rows sort by resolved type name, and
  rendering is capped with honest counts.
- **Activity labels were absent from the lists.** `activity_id`
  was fetched and stored end to end but never labeled, grouped,
  or filtered in either panel. The only activity meanings in
  the feature lived in the excluded production-chain code,
  which treats 1 as manufacturing and 11 as reactions. Section
  7.1 therefore locks a new fixed word map from the
  specification evidence (section 2.3), with a word fallback —
  never a numeric one — for anything unlisted.
- **Name resolution was absent from the lists.** Neither panel
  resolved a type, blueprint, product, facility, location, or
  character ID to a name; the only visual aid was an image
  server icon per type. The Rust resolver pipeline already
  exists, so this slice resolves names the way Assets and
  Market do (section 6.4) instead of porting the gap.
- **Refresh shape.** Industry data loaded at app startup and on
  manual refresh into replace-all local storage streamed to
  the panels; there was no timer refresh for industry and no
  HTTP cache handling. The concept — load with the character's
  other data, refresh on demand with the same gesture — is
  what section 6.1 keeps, re-expressed as tolerant sub-fetches
  inside the existing main refresh. Error states rendered the
  raw exception string into the panel, which could carry IDs
  and paths; Rust replaces that with fixed wording everywhere.
- **Excluded calculators present fake data as real.** Three of
  the five Flutter industry tabs were calculators (invention
  probability with hardcoded skill defaults, a reaction
  calculator over dummy input/output maps, and a
  production-chain visualizer over a hardcoded sample tree
  rendered as if live). All are excluded by the hard scope;
  section 13 names them so the exclusion is auditable. The one
  sync-service test verifies a single-page blueprint fetch and
  `includeCompleted` forwarding through mocks; no multi-page,
  sentinel, or resolved-name behavior was ever tested in
  Flutter, so the Rust test plan in section 12 is new coverage,
  not a port.

### 2.3 Context-library specification evidence

The mimir context library at `/tmp/mimir-context-library`
(Flutter-era specifications; no Rust behavior spec exists
anywhere in it) was read for its industry module
(`platform-specs/03-feature-modules/industry/specification.md`,
1402 lines, status draft, plus the module `README.md` and the
security and API decision records the survey cites). What it
grounds, and what it does not:

- **Endpoint and scope table.** The specification's ESI table
  (read directly) lists `GET /characters/{id}/blueprints/`
  under `esi-characters.read_blueprints.v1` and `GET
  /characters/{id}/industry/jobs/` under
  `esi-industry.read_character_jobs.v1` — the same two strings
  as the shipped Flutter configuration. It also lists
  corporation blueprint/job routes and the public
  `/industry/systems/` and `/industry/facilities/` cost routes;
  all four are out of this slice's hard scope, and no builder
  adds them.
- **A load-bearing gap in the decision records.** The security
  architecture record's industry scope group contains only
  `esi-industry.read_character_jobs.v1` and omits the blueprints
  scope; the API-client record repeats the omission. Neither
  can be copied: a step-up constant built from them would 403
  every blueprint fetch. Section 5.3 therefore grounds the
  constant in the endpoint table and the shipped Flutter list,
  which agree. The progressive-scope principle itself — minimum
  scopes at first sign-in, further groups granted by
  re-authorization when a feature is first used, unioned with
  what is already granted — is stated consistently across the
  library and is exactly what the Rust step-up flow already
  implements.
- **Vocabulary that carries over.** The specification's domain
  sketch (read directly) defines `runs: -1` for an original and
  positive runs for a copy, material efficiency as the 0-10
  field and time efficiency as 0-20 (context for display, not a
  validation range), the activity enumeration 1 manufacturing,
  3 time research, 4 material research, 5 copying, 8
  invention, 11 reaction, and the status enumeration active,
  paused, ready, delivered, cancelled, reverted. Its sync
  sketch converts `quantity == -2` to a copy (and clamps the
  stored quantity to 1), and its job sync sketch defaults
  `includeCompleted` to true — the opposite default from the
  shipped Flutter client, one of the disagreements section 5.2
  resolves explicitly. Its filter and sort sketches (originals
  and copies filter, name sort, a job timeline ordered by end
  date) align with sections 7.2 and 7.4.
- **What the library does not decide.** It never defines
  `quantity == -1`, gives no sentinel display wording, no fixed
  error wording, no pagination cap or truncation contract, no
  saturating-math rule, no raw-ID display ban, and no ruling on
  `include_completed` for a read-only slice; and its calculator,
  production-chain, cost-index, corporation, and local-database
  content is out of scope here. Those rules come from the Rust
  conventions in section 2.1 and are locked in sections 3-9.
  Where the library and shipped Flutter disagree (the quantity
  copy conversion versus the runs-based original rule, the
  `includeCompleted` default), this design follows shipped
  behavior unless it says otherwise with a reason.

## 3. Decisions locked by this design

| # | Decision |
|---|----------|
| I1 | Industry data is one in-memory `LoadState<IndustryData>` bundle of two independent `SectionResult`s (jobs, blueprints), mirroring `CharacterDetailData`. One section's scope refusal or failure degrades only that section; there is no separate whole-view reauthorize boolean. |
| I2 | Fetch placement is the main refresh: two tolerant sub-fetches inside `start_refresh`, exactly like assets and character detail — never an on-demand market-style path. Industry data is keyed only by the active character, has no public section and no user-chosen selection, so it needs no generation counter and no new `BackendMsg` variant; the existing `Refreshed` active-character guard is its identity rule (section 6). |
| I3 | Jobs are fetched with `include_completed=true`, embedded in the path, on every refresh — one value, one path, fixing Flutter's per-trigger inconsistency. Rationale in section 5.2. |
| I4 | Both endpoints use one capped `auth_get_page` walk with `INDUSTRY_MAX_PAGES = 10` and the market truncated rule copied exactly. Any page error propagates; partial page lists are never returned as success. A hit of the cap is disclosed in words in the affected section. |
| I5 | Step-up is one additive constant `INDUSTRY_SCOPES = ["esi-characters.read_blueprints.v1", "esi-industry.read_character_jobs.v1"]` (both strings grounded in the specification endpoint table and the shipped Flutter scope list, section 2), disjoint from first-auth. One top-of-view panel, shown only on a typed per-section scope failure, sets only the generic `stepup_requested` flag. `start_stepup_login` needs no change, and its existing post-step-up refresh refills industry with no extra flag. |
| I6 | Activity words are a fixed six-entry map (1, 3, 4, 5, 8, 11) grounded in section 2.3; every other activity value — including 0, 2, 6, 7, 9, 10, negatives, and future values — renders as the words "Unknown activity", never a number. Status words map the six grounded statuses one-to-one; anything else, including an empty string, renders as "Unknown status" and the raw remote string is never echoed. |
| I7 | Reaction-activity jobs (activity 11) are displayed as ordinary rows labeled with the word "Reaction". The hard scope bans the reaction calculator and its math, not the display of a fetched job row; filtering such rows out would silently hide real jobs. |
| I8 | Blueprint sentinel words: `quantity` -1 is "Original", -2 is "Copy", any other negative is "Unknown quantity"; `runs` -1 is "Infinite runs (original)", any other negative is "Unknown runs". Original-versus-copy classification (and the library filter) derives from `runs == -1` only, never from `quantity`, so a wrong quantity word cannot misclassify a row. No quantity or runs total is computed anywhere; counts are row counts folded with `saturating_add`. |
| I9 | Job ordering is a pure function: in-progress statuses (active, paused, ready) first, then all others; within each group by `end_date` ascending (soonest finish first), empty end dates last, with invisible tie-breaks. Blueprint ordering is a pure function: search matches resolved type or location names, an All/Originals/Copies filter applies, rows sort by resolved type name, and rendering is capped at `BLUEPRINT_RENDER_MAX = 100` rows with an honest "showing X of Y" line. |
| I10 | Name scheduling adds only what the view renders: blueprint type IDs and job blueprint/product type IDs, plus structure-guarded facility IDs (jobs) and blueprint location IDs. Job IDs, blueprint item IDs, the used-blueprint instance ID, installer IDs, completer IDs, and unrendered location IDs are never scheduled, rendered, or logged per row. |
| I11 | Industry is a new `View::Industry` inserted before Settings. Keys 1-6 are unchanged, Industry is 7, Settings moves 7 to 8. Saved startup views survive because persistence is by label string, not number. |
| I12 | Demo industry data is one additive fixture file behind a new backwards-compatible loader arity; every older loader keeps its meaning with a `"{}"` default, and demo seeding composes the live bundle with both sections Ok, or Empty when absent. |
| I13 | Fetched `cost`, `probability`, licensed-run, duration, installer, completer, and output-location fields parse and are carried but are never rendered and never enter any computation. The unused Flutter `runs_remaining` parse is not carried: no inspected evidence shows this route sending it, Flutter dropped it at storage, and serde ignores unknown fields if it ever appears. |

## 4. State: `IndustryData` (Builder B)

### 4.1 Types, exact shape (`src/app/state.rs`)

Reusing the existing `SectionError` and `SectionResult`
(`src/app/state.rs:216-225`) unchanged. The two wrapper structs
mirror `PublicOrdersData` and `CharacterOrdersData` (lines
270-280) so a truncated page walk is carried beside its rows:

```rust
#[derive(Debug, Clone, Default)]
pub struct IndustryJobsData {
    pub jobs: Vec<IndustryJob>,
    pub truncated: bool,
}

#[derive(Debug, Clone, Default)]
pub struct BlueprintsData {
    pub blueprints: Vec<CharacterBlueprint>,
    pub truncated: bool,
}

/// Industry bundle: two independent section results for the
/// active character. Field set is a cross-builder contract (the
/// shell and demo seeding construct this literally); do not add
/// fields here.
#[derive(Debug, Clone)]
pub struct IndustryData {
    pub jobs: SectionResult<IndustryJobsData>,
    pub blueprints: SectionResult<BlueprintsData>,
}

impl IndustryData {
    /// True when either section failed for scope reasons.
    pub fn needs_industry_stepup(&self) -> bool {
        fn reauth<T>(result: &SectionResult<T>) -> bool {
            matches!(result, Err(e) if e.needs_reauthorize)
        }
        reauth(&self.jobs) || reauth(&self.blueprints)
    }
}
```

`IndustryJob` and `CharacterBlueprint` are Builder A's models
(section 5.1). Rules carried by the types:

- Both sections sit behind the step-up scopes, so **either**
  section's `SectionError.needs_reauthorize` may be true, and
  each carries its own typed outcome independently. A character
  who granted only one of the two scopes (possible under any
  other client's grant history) sees the granted section's rows
  and the step-up panel for the other; nothing about one
  section's result is inferred from the other's.
- There is deliberately **no** `industry_needs_reauthorize:
  bool` on `AppState`. Assets needs its separate flag because
  its fetch result rides the refresh as a plain
  `Result<_, String>` plus a side-channel boolean; industry
  rides as typed section results like character detail, so the
  flag would be a second source of truth that can disagree
  with the bundle. The view reads `needs_industry_stepup()`.
- Unlike `MarketData`, the bundle carries no selection and no
  character ID of its own: it is only ever installed by the
  `Refreshed` arm under the active-character guard, or by demo
  seeding for the character being applied, so its ownership is
  the guard's, exactly like `CharacterDetailData`.

### 4.2 New `AppState` fields

```rust
pub industry: LoadState<IndustryData>,
// View-local industry UI state:
pub industry_search: String,
pub industry_blueprint_kind: BlueprintKindFilter,
```

with the filter enum beside the industry types, following the
`WalletPeriod` shape (`src/app/state.rs:152-187`):

```rust
/// Blueprint library filter: every blueprint, originals only,
/// or copies only. Classification is `runs == -1` (section 7.3).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum BlueprintKindFilter {
    #[default]
    All,
    Originals,
    Copies,
}

impl BlueprintKindFilter {
    pub const ALL: [BlueprintKindFilter; 3] = [
        BlueprintKindFilter::All,
        BlueprintKindFilter::Originals,
        BlueprintKindFilter::Copies,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            BlueprintKindFilter::All => "All",
            BlueprintKindFilter::Originals => "Originals (BPO)",
            BlueprintKindFilter::Copies => "Copies (BPC)",
        }
    }
}
```

Defaults come from the derived `Default` impls (`industry`
starts Loading, search empty, filter All), so `AppState::new`
needs no explicit line — industry has no equivalent of the
market region default that `..Self::default()` could leave
outside its valid set (contrast `src/app/state.rs:434-445`).
No request flag is added: the view's only outbound signals are
the existing `retry_requested` and `stepup_requested`, because
the main refresh owns the fetch (section 6).

### 4.3 Lifecycle resets

Mirror assets and character detail at all three existing sites
(`src/app/state.rs:493-547` and `:570-613`):

- `set_active_character`, when `previous_id != character_id`:
  additionally set `self.industry = LoadState::Loading` with a
  debug line paralleling the detail one:
  `tracing::debug!("[INDUSTRY] clearing industry on character
  switch from={} to={}", previous_id, character_id)`. The
  bundle is installed tolerantly and a hard refresh failure
  keeps Ready rows (section 6.2), so ownership must reset at
  the switch boundary or the previous character's jobs and
  blueprints would render under the new character until — or
  unless — a refresh for the new character lands.
  Same-character reselect changes nothing, exactly as assets
  and detail keep their rows.
- `remove_character`, when the removed character was active:
  additionally set `self.industry = LoadState::Loading` beside
  the existing assets and detail resets (before the replacement
  `set_active_character` call, which cannot detect it), with
  `[INDUSTRY] clearing industry of removed active character`.
  The pending-step-up clearing for the removed character
  (lines 596-602) already covers an industry step-up request;
  industry adds nothing there. In the `characters.is_empty()`
  branch, add `self.industry = LoadState::Empty` alongside the
  existing Empty assignments.
- `industry_search` and `industry_blueprint_kind` are **not**
  reset on switch or removal. They are plain view-local fields
  like `assets_search` and `wallet_search`, which no reset path
  touches today: the user's filter text surviving a switch is
  harmless because it can only ever filter the newly loaded
  bundle, and clearing it would diverge from every other view.
  Loaded rows never survive; filter text may.
- Demo switching goes through `apply_character` (section 9.3),
  which installs the fixture bundle or Empty on every call; it
  never consults these resets because nothing is in flight in
  demo mode.

State tests mirror the existing ones: switching clears a Ready
industry bundle to Loading while same-character reselect keeps
it (the `switching_character_clears_stale_character_details`
pattern, lines 750-774), removing the active character clears
it while removing a non-active one keeps it, removing the last
character sets Empty (lines 777-795), and
`needs_industry_stepup()` is true exactly when either section
carries a typed reauthorize error and false for plain errors
and all-Ok bundles (the `needs_detail_stepup` matrix at lines
798-827, reduced to two sections).

## 5. ESI endpoints and typed models (Builder A)

### 5.1 Models to add in `src/esi/models.rs`

Same derive and `#[serde(default)]`-on-every-field pattern as
`AssetItem` (`src/esi/models.rs:397-415`) and `CharacterOrder`
(lines 462-492). Field names are the ESI JSON names, so the
demo fixture (section 9.1) and the test fixture (section 12.1)
use ESI spelling too. Placement mirrors the market models:
after `MarketHistoryEntry` (line 510), before `EsiErrorBody`.

```rust
/// One of a character's blueprints from
/// `GET /characters/{character_id}/blueprints/`. `item_id` is an
/// item-instance id: an invisible sort tie-break only, never
/// rendered and never name-resolved. `quantity` carries the ESI
/// sentinels -1 and -2 and `runs` carries -1 for an original;
/// both render as words in the view (design section 7.3), never
/// as raw counts. `location_flag` parses and is carried but is
/// not rendered in this slice.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CharacterBlueprint {
    #[serde(default)] pub item_id: i64,
    #[serde(default)] pub type_id: i64,
    #[serde(default)] pub location_id: i64,
    #[serde(default)] pub location_flag: String,
    #[serde(default)] pub quantity: i64,
    #[serde(default)] pub time_efficiency: i64,
    #[serde(default)] pub material_efficiency: i64,
    #[serde(default)] pub runs: i64,
}

/// One character industry job from
/// `GET /characters/{character_id}/industry/jobs/`. `job_id`,
/// `blueprint_id` (the used blueprint's item-instance id),
/// `installer_id`, and `completed_character_id` are never
/// rendered and never name-resolved; `job_id` is an invisible
/// sort tie-break only. `cost`, `probability`,
/// `licensed_production_runs`, `duration`, `location_id`, and
/// `output_location_id` parse and are carried but are never
/// rendered and never enter any computation (no calculator).
/// Nullability is preserved exactly: a null `cost` stays `None`
/// and is never coerced to zero.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct IndustryJob {
    #[serde(default)] pub job_id: i64,
    #[serde(default)] pub installer_id: i64,
    #[serde(default)] pub facility_id: i64,
    #[serde(default)] pub location_id: i64,
    #[serde(default)] pub activity_id: i64,
    #[serde(default)] pub blueprint_id: i64,
    #[serde(default)] pub blueprint_type_id: i64,
    #[serde(default)] pub output_location_id: i64,
    #[serde(default)] pub runs: i64,
    #[serde(default)] pub cost: Option<f64>,
    #[serde(default)] pub licensed_production_runs: Option<i64>,
    #[serde(default)] pub probability: Option<f64>,
    #[serde(default)] pub product_type_id: Option<i64>,
    #[serde(default)] pub status: String,
    #[serde(default)] pub duration: i64,
    #[serde(default)] pub start_date: String,
    #[serde(default)] pub end_date: String,
    #[serde(default)] pub pause_date: Option<String>,
    #[serde(default)] pub completed_date: Option<String>,
    #[serde(default)] pub completed_character_id: Option<i64>,
    #[serde(default)] pub successful_runs: Option<i64>,
}
```

Locked consequences of the tree-wide tolerance pattern, each
recorded so no builder "fixes" one struct in isolation:

- Dates stay `String` (the `RegionalOrder.issued` precedent);
  ordering and countdowns parse them in the pure UI helpers
  with word fallbacks, so one malformed date can never fail a
  page the way Flutter's `DateTime.parse` casts could.
- A missing `status` decodes as an empty string and a missing
  `activity_id` as 0; both land on the word fallbacks in
  section 7.1 ("Unknown status", "Unknown activity"). Live ESI
  sends both fields; the fallbacks exist so a sparse row
  degrades in words, never in numbers.
- `runs_remaining` is **not** a field (decision I13). If a
  future payload carries it, serde ignores it harmlessly.
- Model tests copy the market trio: full-row parse with every
  field asserted (including `quantity: -2`, `runs: -1`, a null
  `cost`, a present `probability`, and an unknown extra field),
  `{}` defaults parse, and each `Option` present, absent, and
  null (the `escrow` variants at `src/esi/models.rs:646-691`
  are the template).

### 5.2 Endpoints to add in `src/esi/endpoints.rs`

Endpoint map — the whole ESI surface of this slice:

| Route | Auth | Scope | Rust function |
|-------|------|-------|---------------|
| `GET /characters/{character_id}/industry/jobs/?include_completed=true` | `auth_get_page` walk | `esi-industry.read_character_jobs.v1` | `get_character_industry_jobs` |
| `GET /characters/{character_id}/blueprints/` | `auth_get_page` walk | `esi-characters.read_blueprints.v1` | `get_character_blueprints` |

```rust
/// Hard cap for industry page walks. A character's jobs and
/// blueprint library are character-bounded populations; the cap
/// is a runaway guard, and hitting it is always disclosed via
/// the returned truncated flag rather than silent partial data.
pub const INDUSTRY_MAX_PAGES: u32 = 10;

pub async fn get_character_industry_jobs(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<(Vec<IndustryJob>, bool)>;

pub async fn get_character_blueprints(
    client: &EsiClient,
    character_id: i64,
) -> AppResult<(Vec<CharacterBlueprint>, bool)>;
```

Locked construction details:

- `get_character_industry_jobs`: path is exactly
  `format!("/characters/{character_id}/industry/jobs/?include_completed=true")`.
  The query is embedded in the path because `build_url`
  (`src/esi/client.rs:170-179`) already handles an embedded
  `?`, and `auth_get_page` adds `page=` through the request
  query — the same composition the regional-orders path uses
  (`src/esi/endpoints.rs:281` with `public_get_page`). There is
  no parameter, overload, or default that fetches jobs any
  other way.
- **`include_completed=true` is the locked value**, against
  three disagreeing sources, for these reasons. First, the
  Flutter surface the user actually saw included completed
  jobs: the jobs panel read the provider built with
  `includeCompleted: true`, and the manual refresh forced true;
  false appeared only as the client-layer default and in the
  startup sync that, combined with replace-all storage, could
  erase what a manual refresh had shown (section 2.2). The
  specification sketch also defaults true. Second, the useful
  read-only question this view answers — "what needs my
  attention in game?" — includes `ready` jobs awaiting delivery
  and recently `delivered` ones; false would hide exactly the
  rows that tell the user to go and deliver, and this app can
  never deliver for them (hard scope). Third, the cost of true
  is bounded by construction: the same capped walk and the same
  disclosed truncated flag apply either way, and the view caps
  nothing silently (section 7.2 counts describe the rows
  loaded). The rejected alternative, false, would make the
  delivered, cancelled, and reverted status words in section
  7.1 nearly unreachable and would silently narrow the list
  relative to what Flutter's panel showed.
- `get_character_blueprints`: path is exactly
  `format!("/characters/{character_id}/blueprints/")` through
  the same capped `auth_get_page` walk. Blueprints are the
  explicitly capped walk of this slice: a long-lived
  character's library is the largest character-owned list the
  app fetches, and Flutter's version silently stopped after
  page 1 when the header was missing (section 2.2). Here the
  cap is `INDUSTRY_MAX_PAGES = 10` — the in-tree market
  precedent value, chosen for consistency and recorded as a
  judgment call in section 14 — and every stop short of a
  proven end sets the truncated flag the section heading
  discloses (section 8.3). Raising the cap later is one
  constant; silently under-reporting a library is not
  recoverable after the fact, which is why the flag exists.
- Both public functions delegate to private helpers taking an
  explicit `max_pages: u32` (clamped with `.max(1)`), passing
  `INDUSTRY_MAX_PAGES`; the parameter exists so unit tests can
  prove cap behavior with a budget of 2 or 3, exactly as
  `get_regional_orders_capped` and
  `get_character_orders_capped` do (`src/esi/endpoints.rs:
  274-331`, `:369-426`). The jobs walk shares the helper shape
  deliberately: when a jobs response fits on one page the walk
  is one request (the common case, and all Flutter ever made),
  and when `x-pages` reports more, the walk continues instead
  of repeating Flutter's silent drop.
- **Stop and truncated rule, copied verbatim from the market
  helpers** (`src/esi/endpoints.rs:303-320`): stop with
  `truncated: false` when `meta.pages` is `Some(total)` and
  `page >= total`, or when `meta.pages` is `None` and the page
  just read is empty; stop with `truncated: true` when
  `page >= max_pages` in every other case (a `Some` total above
  the current page, or a non-empty page landing exactly on the
  cap with no header, where the walk cannot prove it saw the
  end). Any page error — including the 403 scope refusal,
  which surfaces as `EsiError::Reauthorize` for
  `endpoints::needs_reauthorize` — propagates with `?`;
  partial page lists are never returned as success (the
  `get_assets` rule).
- Rows return in fetch order, unsorted and unfiltered; all
  ordering, grouping, sentinel wording, and counting belongs
  to the pure functions in section 7. No summary is built in
  the endpoint layer, for the same reason the market design
  forbade it: the view renders rows from the same raw data, so
  aggregation must not consume or re-key the list upstream.
- Logging: `[INDUSTRY]` on every line these functions emit —
  the route at debug (with `include_completed=true` visible for
  jobs), per-page row counts at debug, and one info line at
  completion with the row count and truncated flag, mirroring
  the `[MARKET]` completion lines. Numeric character IDs in
  these lines follow the `[ASSETS]`/`[MARKET]` log-only
  convention; job IDs, item IDs, and any other per-row ID are
  never logged per row. No new error text is constructed here:
  client errors propagate untouched so the sanitized Display
  boundary in `send()` stays the only one.

### 5.3 Scope constant in `src/config.rs`

Builder A adds, immediately after `CHARACTER_DETAIL_SCOPES`
(lines 74-80, the current last step-up constant):

```rust
/// Industry step-up scopes: read the character's industry jobs
/// and blueprint library. Granted after first sign-in via
/// step-up, never at first auth. Both scopes are required: the
/// industry decision records that name only the jobs scope are
/// incomplete and must not be copied (design section 2.3).
pub const INDUSTRY_SCOPES: &[&str] = &[
    "esi-characters.read_blueprints.v1",
    "esi-industry.read_character_jobs.v1",
];
```

Both strings are grounded in inspected bodies, not guessed:
the specification endpoint table and the shipped Flutter
phase-5 list agree on both spellings (sections 2.2 and 2.3),
so neither needs the honest-error fallback an ungrounded
string would require. Order copies the Flutter list
(blueprints before jobs). The test copies
`character_detail_scopes_are_the_five_stepup_scopes` (lines
170-192): the constant equals exactly these two scopes in this
order, and every entry is disjoint from `FIRST_AUTH_SCOPES`.
Nothing else in `src/config.rs` changes; `FIRST_AUTH_SCOPES`
stays byte-identical, and neither the planetary scope nor any
corporation scope from the same source lists appears anywhere
in the slice diff (section 12.3 gates on this).

### 5.4 Corporation, public industry, and planetary routes: out

`GET /corporation/{id}/blueprints/`, `GET
/corporation/{id}/industry/jobs/`, `GET /industry/systems/`,
and `GET /industry/facilities/` appear in the specification
table only; the shipped Flutter client never called any of
them, corporation data needs corporation roles and a second
authorization story, and the two public routes exist to feed
cost-index calculator math this slice forbids. None is added,
and a grep gate (section 12.3) keeps `corporation` industry
routes, `planets`, and `industry/systems` out of `src/` in
this slice. A later corporation slice can add its routes
behind its own additive scopes without touching this design.

## 6. Shell fetch wiring (integrator)

### 6.1 Fetch placement: main-refresh tolerant sub-fetches

Industry fetching lives **inside `start_refresh`**
(`src/app/shell.rs:1035`), as two more tolerant sub-fetches in
the character-detail position — not as an on-demand path like
`start_market_fetch` (line 859). The choice is locked, with
the rejected alternative recorded:

- Market needed its own path for three reasons, none of which
  holds here: its data is keyed by a user-changing type and
  region selection (industry has no selection at all), its
  public sections must work with no character signed in
  (industry is meaningless without the active character), and
  folding it into `Refreshed` would refetch a regional order
  book on every unrelated refresh (industry rows are
  character-owned and exactly as refresh-worthy as assets and
  clones). Industry keys only by the active character, like
  assets and character detail, so it takes their placement.
- Consequences that fall out for free and need no new code:
  startup refresh, post-login refresh, character-switch
  refresh, Ctrl+R and the top-bar Refresh button, every view's
  Retry (which sets `retry_requested` into the same drain at
  lines 780-784), and both post-step-up paths
  (`StepUpLoggedIn` at lines 685-713 and the already-granted
  shortcut at lines 1494-1512, which both call
  `request_refresh`) all refill industry. In particular the
  Market slice's extra step-up refetch flags (lines 701-704,
  1502-1509) are **not** copied: industry rides the main
  refresh those paths already request, and the
  `StepUpLoggedIn` rule that nothing is pre-cleared on login
  success applies unchanged — the re-authorize panel
  disappears only when a later refresh returns a section Ok.
- There is no generation counter, no selection snapshot, and
  no `industry_fetch_requested` flag. Identity is the
  `Refreshed` contract that already guards assets and detail:
  the message carries `character_id`, the drain applies
  per-view states only when that character is still active,
  and character switches reset the bundle to Loading
  (section 4.3) so a late result for the previous character
  can never render under the new one. Two racing refreshes
  for the same active character resolve the way every
  main-refresh bundle already does: the later `Refreshed` to
  arrive wins, whole-bundle, never merged.
- Demo mode takes the existing short-circuit: `start_refresh`
  in demo re-applies the fixture character (lines 1036-1043),
  and `apply_character` installs the industry bundle
  (section 9.3). Zero network, no demo-only fetch function.

### 6.2 The `Refreshed` message and its drain arm

`BackendMsg::Refreshed` (lines 39-47) gains one field,
`industry: Box<IndustryData>`, constructed beside `detail` in
the refresh task and sent at the same site (lines 1309-1317).
No new `BackendMsg` variant exists in this slice.

Inside the refresh task, after the seven detail sub-fetches
(lines 1125-1189) and in the same never-`?` style, the
integrator adds the two industry sub-fetches. Each maps its
endpoint result the character-detail way:

```text
jobs = endpoints::get_character_industry_jobs(&esi, id).await
    .map(|(jobs, truncated)| IndustryJobsData { jobs, truncated })
    .map_err(|e| {
        let needs_reauthorize = endpoints::needs_reauthorize(&e);
        tracing::warn!("[INDUSTRY] industry section failed character_id={} \
            section=jobs needs_reauthorize={} error={}",
            id, needs_reauthorize, e);
        SectionError {
            message: "industry jobs request failed".to_string(),
            needs_reauthorize,
        }
    });
```

and symmetrically for blueprints with
`section=blueprints` and the fixed message "blueprints request
failed", assembled into `IndustryData { jobs, blueprints }`
with one `[INDUSTRY]` info line carrying both row counts and
both truncated flags (the `detail` completion line at lines
1190-1199 is the template). The fixed messages are the whole
contract: `SectionError.message` renders verbatim in the
section panels (section 8.2), so full error detail — which
can embed remote text — stays in the warn logs only. Nothing
industry-shaped is persisted: the persistence block (lines
1214-1307) gains no repository call, matching the
assets/detail/market in-memory rule (and `seed_bundle_into_db`'s
own comment, extended in section 9.3).

The drain arm (lines 580-606), inside the existing
active-character `else` branch, adds exactly one assignment
beside `character_details`:

```rust
self.state.industry = LoadState::Ready(*industry);
```

Unconditional, like `character_details` at line 585 — the
bundle is always present and always describes the character
the guard just verified, with each section independently Ok
or Err. The assets three-way match (lines 586-603, including
keep-Ready-rows-on-plain-error) is **not** copied: that shape
exists because assets ride as a whole-view `Result`, while an
industry section error is data the view renders in place, and
the switch-boundary reset to Loading (section 4.3) is what
protects a newly active character from stale rows.
`schedule_name_resolution()` is already called at the end of
this arm (line 606); section 6.4 extends what it collects.

`RefreshFailed` (lines 644-673) gains the same guard its
neighbours have, inside the active-character branch:

```rust
if !self.state.industry.is_ready() {
    self.state.industry = LoadState::Error(message.clone());
}
```

placed with the character-details line (ordering among the
four existing guards is not observable; `message` ownership
follows the existing clone pattern so the last consumer keeps
the move). A hard refresh failure therefore never erases
industry rows already on screen, and never touches an inactive
character's state — both properties inherited, not re-decided.

### 6.3 Step-up integration: none beyond the generic flag

The drain `if let Some(request) = state.stepup_requested.take()
{ self.start_stepup_login(request) }` (lines 797-799) and
`start_stepup_login` itself (line 1419) need no change: the
Industry view's panel (section 8.4) sets
`StepUpRequest::new(active_id, EveConfig::INDUSTRY_SCOPES)` and
the generic flow unions those two scopes with whatever the
character already granted, verifies the returned token's
signature before reading claims, rejects a different
character, requires the full union to survive, and saves
nothing on any failure. The already-granted shortcut covers a
character who granted both scopes under another client state:
it refreshes with no browser round trip, and that refresh
refills industry by section 6.1. A character who granted only
one of the two is handled by the same generic arithmetic —
`missing_scopes` names the other, the browser asks for the
union, and the view needs no per-scope logic of its own.

### 6.4 Name scheduling additions

One new block in `schedule_name_resolution` (lines 400-523),
after the market block (lines 471-496), reading
`state.industry` when Ready. It schedules exactly what the
view renders (section 8), and nothing else:

- from `jobs` when Ok: every row's `blueprint_type_id`, every
  row's `product_type_id` when `Some`, and every row's
  `facility_id` only when `!is_structure_id(facility_id)`;
- from `blueprints` when Ok: every row's `type_id`, and every
  row's `location_id` only when `!is_structure_id(location_id)`.

Locked exclusions, with the reason for each:

- **Never scheduled as universe names:** `job_id` (a job
  instance number), blueprint `item_id` and a job's
  `blueprint_id` (item-instance IDs of specific physical
  blueprints — `/universe/names/` resolves universe entities,
  not item instances, the same reason asset custom names use a
  separate per-instance endpoint), `installer_id` and
  `completed_character_id` (character IDs the view never
  renders; this design does not prove them as display names
  because it never needs them — character industry jobs are
  the active character's own), and a job's `location_id` and
  `output_location_id` (carried, unrendered in this slice;
  scheduling names nothing displays would burn the
  1000-per-call resolution budget, the market top-N lesson).
- **No industry "system" ID exists to schedule.** The job
  model carries no solar-system field (section 5.1, against
  the Flutter field list in section 2.2), so there is no
  system-name rendering to feed; the facility name is the one
  job location shown. If a future slice renders output
  locations, it schedules them then, behind the same guard.
- Structure-class facility and location IDs stay "Unknown
  Location" through the resolver fallback, exactly like assets
  and clones today; the authenticated structure endpoint is
  not called from industry code (the market rule). This is
  also the safe failure mode for the one scheduling assumption
  this design makes — that a non-structure `facility_id` is a
  station-class universe ID of the same kind as an asset
  `location_id`: if ESI ever returns a facility ID outside
  that class, `resolver.missing()` records it unresolved for
  the session and the row shows the word fallback, never a
  number.
- Non-positive IDs need no explicit filter: `resolver.missing()`
  already skips them (lines 154-166), and `name(0)` /
  `location_name(0)` return the word fallbacks, so a sparse
  `{}`-defaulted row renders words. Everything flows through
  the existing dedup and 1000-chunk send, and the
  `NamesResolved` arm needs no industry case: industry rows
  derive their labels from the resolver at render time, so
  names landing later upgrade rows in place, unlike character
  summaries whose strings were frozen at refresh time.

### 6.5 Countdown ticking

`needs_tick` (lines 1737-1745) gains one integrator-owned
clause: it also returns true when `state.industry` is Ready
with an Ok jobs section containing at least one in-progress
job (the section 7.2 rank rule, applied to the raw `status`
string). Without it, job countdowns and progress bars would
only move when some other repaint happens, while the skill
queue beside them ticks every second. The check reads state
only; it starts no fetch and schedules no work beyond the
existing one-second repaint the skill queue already uses.

## 7. Pure display logic (`src/ui/industry.rs`, Builder B)

All derived words, ordering, filtering, and counts come from
pure functions in the new UI module, unit-tested in-module the
way `group_assets` is (`src/ui/assets.rs:263-401`). No function
here touches the network; only the two row builders take a
resolver, and only to read names from it.

### 7.1 Activity and status words

```rust
pub fn activity_label(activity_id: i64) -> &'static str;
pub fn status_label(status: &str) -> &'static str;
pub fn is_in_progress_status(status: &str) -> bool;
```

- `activity_label` is the fixed six-entry map grounded in
  section 2.3 (with 1 and 11 corroborated by shipped Flutter
  code, section 2.2): 1 → "Manufacturing", 3 → "Time
  efficiency research", 4 → "Material efficiency research",
  5 → "Copying", 8 → "Invention", 11 → "Reaction". **Every
  other value** — 0 (including a serde-defaulted missing
  field), 2, 6, 7, 9, 10, any negative, and any future ESI
  activity — returns "Unknown activity". There is no numeric
  fallback in any form: no `format!` in this module ever
  interpolates `activity_id` (section 12.3 gates on it). The
  unlisted values 2, 6, 7, 9, and 10 are deliberately not
  given guessed words: no inspected body names them, and a
  wrong confident word is worse than an honest unknown. A
  test asserts the fallback for at least one value the map
  does not enumerate.
- `status_label` maps the six grounded statuses one-to-one:
  "active" → "Active", "paused" → "Paused", "ready" →
  "Ready", "delivered" → "Delivered", "cancelled" →
  "Cancelled", "reverted" → "Reverted". Anything else —
  an unknown future status, a differently cased string, or an
  empty serde-defaulted string — returns "Unknown status".
  The raw remote string is never echoed, even when it looks
  like a word: rendered text comes only from this function's
  fixed outputs, which keeps remote content out of the
  interface by construction (and fixes Flutter's
  unknown-means-cancelled defect, section 2.2).
- `is_in_progress_status` is true exactly for "active",
  "paused", and "ready" — the set Flutter's repository used
  for its still-running filter (section 2.2). It drives the
  sort rank (section 7.2), the active count, the progress-bar
  rule (section 8.3), and the shell's tick clause
  (section 6.5), so all four agree by construction.

### 7.2 Job rows: build, order, count

```rust
#[derive(Debug, Clone, Default, PartialEq)]
pub struct IndustryJobRow {
    pub job_id: i64,            // invisible tie-break only
    pub display_type_id: i64,   // resolved to a name by the builder
    pub type_name: String,
    pub activity_label: &'static str,
    pub status_label: &'static str,
    pub in_progress: bool,
    pub runs: i64,              // clamped at 0, display value
    pub successful_runs: Option<i64>,
    pub facility_name: String,
    pub start_date: String,
    pub end_date: String,
}

pub fn industry_job_rows(
    jobs: &[IndustryJob],
    resolver: &NameResolver,
) -> Vec<IndustryJobRow>;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct JobCounts {
    pub total: usize,
    pub in_progress: usize,
}

pub fn job_counts(rows: &[IndustryJobRow]) -> JobCounts;
```

Locked rules:

- **Display type.** The row's type is `product_type_id` when
  it is `Some` and positive, else `blueprint_type_id` — what
  the job makes, falling back to the blueprint it works from
  (research and copying jobs have no product distinct from the
  blueprint). `type_name` is `resolver.name(display_type_id)`,
  so an unresolved type shows "Unknown Item", never the
  number. Both candidate IDs are scheduled for resolution
  regardless of which one wins (section 6.4).
- **Ordering: in-progress first, then soonest finish.**
  Primary key is the rank from `is_in_progress_status`
  (in-progress rank 0, everything else rank 1). Within a rank,
  `end_date` ascending as ISO-8601 strings (lexicographic
  order is chronological for ESI timestamps, the market
  tie-break precedent), with an empty `end_date` sorted last
  within its rank rather than first — an absent finish time is
  the least actionable row, and a plain string sort would put
  the empty string first. Remaining tie-breaks, all invisible:
  `start_date` ascending, then `job_id` ascending. Direction
  is a deliberate change from Flutter's end-date-descending
  storage order: soonest-finishing first puts the job that
  will need attention next at the top, matching the
  specification's ascending timeline sketch (section 2.3).
  There is no grouping header and no activity grouping in
  this slice — one flat, totally ordered list; two rows equal
  on every key are indistinguishable in every rendered field.
- **Reaction jobs are ordinary rows** (decision I7): an
  activity-11 job sorts, counts, and renders like any other,
  labeled "Reaction". No reaction row is filtered, and no
  reaction input, output, or cost figure is computed.
- **`runs` display value is `runs.max(0)`.** A job's run count
  is an ordinary count (not an ID, and not one of the
  blueprint sentinels), but it decodes from remote JSON
  unvalidated, so a malformed negative contributes a clamped
  zero rather than a negative count on screen (the
  `filled_volume` clamp pattern, `src/ui/market.rs:120-124`).
  `successful_runs` passes through as fetched and is rendered
  only when `Some` (section 8.3); it is a fetched field shown
  beside the run count, never a success rate — no ratio is
  computed from it, because a percentage derived from two
  fetched integers is calculator territory this slice stays
  out of.
- **`job_counts`** folds `usize` row counts with
  `saturating_add`: `total` is the row count and
  `in_progress` the rank-0 count. These are the only sums in
  the jobs section; there is no total-runs figure and no
  facility grouping count. The builder logs one `[INDUSTRY]`
  debug line with both counts (never per-row IDs), mirroring
  `character_order_rows` at `src/ui/market.rs:159`.
- **Progress and countdowns are not recomputed here.** The row
  carries the fetched `start_date` and `end_date` strings and
  the view renders `widgets::progress_fraction` and
  `widgets::countdown_label` from them (section 8.3). The
  fetched `duration` seconds field is never used for progress:
  deriving progress from the two dates through the existing
  guarded widget helper avoids Flutter's unguarded
  division and keeps paused-job behavior identical to the
  skill queue's.

### 7.3 Blueprint sentinel words and classification

```rust
pub fn blueprint_is_original(blueprint: &CharacterBlueprint) -> bool;
pub fn blueprint_kind_label(blueprint: &CharacterBlueprint) -> &'static str;
pub fn blueprint_quantity_label(quantity: i64) -> String;
pub fn blueprint_runs_label(runs: i64) -> String;
pub fn efficiency_label(kind: &str, value: i64) -> String;
```

- `blueprint_is_original` is `runs == -1` and nothing else —
  the shipped Flutter rule and the specification's domain rule
  agree on it (sections 2.2, 2.3). `blueprint_kind_label`
  returns "Original (BPO)" when it holds and "Copy (BPC)"
  otherwise, matching the outcome-label wording family the
  assets copy suffix introduced. `quantity` never
  participates in classification: the specification sketch's
  quantity-based copy conversion is not copied, because the
  shipped behavior classified by runs and the sketch's
  conversion would misclassify any future row where the two
  signals disagree. The library filter (section 7.4) uses
  this same predicate.
- `blueprint_quantity_label`: -1 → "Original", -2 → "Copy",
  any other negative → "Unknown quantity", 0 or positive →
  the plain count as a string. Only -2's meaning is grounded
  in an inspected body (the specification sync sketch,
  section 2.3); -1's word is the complementary member of the
  same two-value sentinel pair this slice is required to
  render as words, recorded as a risk in section 14. The
  blast radius of a wrong word is one label string:
  classification, filtering, sorting, and counts never read
  `quantity`. There is no code path that renders -1 or -2 as
  a number, and no quantity total is computed anywhere in the
  slice — with sentinels in the population a summed quantity
  would be a meaningless number presented as a count.
- `blueprint_runs_label`: -1 → "Infinite runs (original)"
  (Flutter's "Infinite Runs", extended with the kind word),
  any other negative → "Unknown runs", 0 or positive →
  `"{runs} runs"`. A copy's remaining-runs reading comes only
  from this field; `runs_remaining` is not carried
  (section 5.1).
- `efficiency_label("ME", value)` renders `ME {value.max(0)}`
  and likewise for TE: efficiency values are fetched fields
  shown as-is except that a malformed negative clamps to zero
  rather than rendering a negative efficiency. No percentage
  sign and no 10/20 maximum assumption is baked in (Flutter
  colored chips by assumed maxima; the specification gives
  those ranges as domain context in section 2.3, and this
  slice renders the fetched value without grading it).

### 7.4 Blueprint rows: build, search, filter, sort, cap

```rust
pub const BLUEPRINT_RENDER_MAX: usize = 100;

#[derive(Debug, Clone, Default, PartialEq)]
pub struct BlueprintRow {
    pub item_id: i64,           // invisible tie-break only
    pub type_id: i64,
    pub type_name: String,
    pub kind_label: &'static str,
    pub is_original: bool,
    pub quantity_label: String,
    pub runs_label: String,
    pub material_efficiency: i64,
    pub time_efficiency: i64,
    pub location_name: String,
}

pub fn blueprint_rows(
    blueprints: &[CharacterBlueprint],
    resolver: &NameResolver,
) -> Vec<BlueprintRow>;

pub fn filter_blueprint_rows<'a>(
    rows: &'a [BlueprintRow],
    query: &str,
    kind: BlueprintKindFilter,
) -> Vec<&'a BlueprintRow>;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct BlueprintCounts {
    pub total: usize,
    pub originals: usize,
    pub copies: usize,
}

pub fn blueprint_counts(rows: &[BlueprintRow]) -> BlueprintCounts;
```

Locked rules:

- **Build.** `type_name` is `resolver.name(type_id)` and
  `location_name` is `resolver.location_name(location_id)`;
  sentinel and kind words come from section 7.3. Efficiency
  fields pass through as fetched values (the clamp lives in
  `efficiency_label` at render time, so the row stays a
  faithful copy of what arrived).
- **Sort by resolved type name.** Primary key is the resolved
  `type_name` lowercased, then the exact `type_name`, then
  `location_name` lowercased, then `item_id` ascending as the
  invisible final tie-break — the label-first ordering family
  the market quick picks use (`src/ui/market.rs:240-245`).
  Sorting by the displayed name (not by type ID) is the point:
  Flutter left rows in storage order. Unresolved types sort by
  their shared "Unknown Item" word like any other name; no row
  is dropped or pushed to the end for being unresolved.
- **Search matches names, never numbers.** A row matches when
  `widgets::matches_search` hits its `type_name` or its
  `location_name` (case-insensitive substring, the assets
  filter shape at `src/ui/assets.rs:122-155`). An empty query
  matches everything. No ID, quantity, or runs text is
  searched — Flutter's type-ID substring search is the defect
  being fixed, and a test asserts a numeric query that equals
  a row's type ID does **not** match it.
- **Kind filter.** `All` keeps every row, `Originals` keeps
  rows where `is_original` holds, `Copies` keeps the rest —
  the Flutter chip concept with Rust's runs-based predicate
  (section 7.3). Search and kind compose (both must pass).
  There is no grouping by location or type and no
  researched/unresearched filter in this slice; the
  specification's wider filter sketch stays future work
  (section 13).
- **Capped rendering with honest counts.** The view renders
  at most `BLUEPRINT_RENDER_MAX` (100) filtered rows. The cap
  is a rendering bound for very large libraries, recorded as
  a judgment call alongside the page cap (section 14): it
  keeps a frame's label count bounded while search and the
  kind filter remain the way to narrow further. Honesty is
  structural, from three counts the view always shows
  (section 8.3): `blueprint_counts` over **all** loaded rows
  (total, originals, copies — `usize` folds with
  `saturating_add`, and `originals + copies == total` by
  construction of the predicate), the filtered count the
  "showing X of Y" line reports, and the truncated-page-walk
  disclosure when `BlueprintsData.truncated` is set, which
  makes every count on screen explicitly a count of the rows
  loaded. Counts are never recomputed from the rendered
  subset alone — the assets filter rule that headers must
  describe exactly what they claim to describe
  (`src/ui/assets.rs:119-121`), applied by keeping the three
  denominators distinct and labeled.
- The builder logs one `[INDUSTRY]` debug line with the row
  count; the filter logs at debug with kept/total counts.
  Neither logs an ID.

## 8. The Industry view (`src/ui/industry.rs`, Builder B)

### 8.1 Skeleton and load states

`pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver:
&NameResolver)` follows the Assets skeleton
(`src/ui/assets.rs:197-261`) with the character-detail section
composition inside it:

1. `ui.heading("Industry")` and
   `widgets::mode_notice(ui, state.demo, state.offline)`.
2. No active character: `widgets::no_character_panel(ui)` and
   return. Industry has no public section, so unlike Market
   there is nothing to show signed-out; the panel's words are
   the same ones every other character view uses.
3. A cloned snapshot of `state.industry` (the Assets clone
   pattern, so the step-up button and search box can borrow
   `state` mutably), matched by load state:
   - Loading → `widgets::loading_panel(ui, "Loading industry
     data...")`.
   - Empty → `widgets::empty_panel(ui, "No industry data
     yet.")` (reached in demo for a fixture-less character and
     after the last character is removed).
   - Error(e) → `widgets::error_panel_with_retry(ui, &e)`;
     a click sets the **global** `state.retry_requested =
     true` with an `[INDUSTRY]` warn line. This is the Assets
     behavior (`src/ui/assets.rs:254-259`), not Market's own
     fetch flag — the main refresh owns industry, so the
     shared retry is the correct drain. The error text here is
     either the refresh-failure message (category-only by the
     client boundary, section 2.1) or the demo-seed failure
     string; neither can carry a numeric ID by construction
     of its producers.
   - Ready(bundle) → section 8.2.

There is no view-local Refresh button: Ctrl+R, the top-bar
Refresh button, and Retry all drive the same main refresh, and
inventing a second, industry-only refresh gesture would need
the on-demand plumbing section 6.1 rejected. The view sets
exactly two outbound signals ever: `retry_requested` and
`stepup_requested`. It performs no fetch, no name resolution,
and no computation beyond section 7's pure helpers.

### 8.2 Ready composition and section errors

In the Ready arm, in order:

1. `panel_shown = !state.demo &&
   state.active_character_id.is_some() &&
   bundle.needs_industry_stepup()` (the character-detail
   predicate shape, `src/ui/characters.rs:397-398`). When
   true, render the step-up panel (section 8.4) with an
   `[INDUSTRY]` debug line noting the guidance is showing.
2. The jobs section (section 8.3), always with its heading.
3. The blueprints section (section 8.3), always with its
   heading.

Each section matches its own `SectionResult` independently,
so a failed blueprints fetch leaves the jobs list on screen
(the character-detail composition rule). Section failures
render through one local helper copying
`section_error_label` (`src/ui/characters.rs:328-336`):

```rust
fn section_error_label(
    ui: &mut egui::Ui,
    section: &str,
    error: &SectionError,
    panel_shown: bool,
);
```

- `needs_reauthorize && panel_shown` → "Not authorized yet.
  Re-authorize above to load this section."
- `needs_reauthorize && !panel_shown` → "Not authorized yet
  for this character." (the demo-shaped backstop; in live
  mode a reauthorize error with an active character always
  shows the panel, so this branch covers only the guard's
  edges, exactly as in the original).
- otherwise → `format!("Could not load {section}: {}",
  error.message)` with section names "industry jobs" and
  "blueprints". The message is the shell's fixed wording
  (section 6.2), so this interpolation can never carry remote
  text or a numeric ID; the typed `needs_reauthorize` flag is
  the only thing ever branched on, never the message text.

### 8.3 The two sections, line by line

**Industry jobs.** Heading "Industry jobs". On Err: the
section error line. On Ok:

- Empty rows → "No industry jobs for this character."
- Otherwise a summary line from `job_counts`: "{total} jobs
  loaded, {in_progress} in progress." Counts are row counts
  (values, not IDs) and describe the rows loaded.
- When `IndustryJobsData.truncated` is true, exactly one
  disclosure line: "Showing the first pages of jobs only;
  counts cover the jobs loaded." (the market first-pages
  wording family, `src/ui/market.rs:380-385`).
- One block per `industry_job_rows` row, in the section 7.2
  order, each opened by `ui.separator()`:
  - "{type_name} — {activity_label}" (the resolved blueprint
    or product name and the fixed activity word; a reaction
    job reads e.g. "Ferrogel — Reaction" like any other row).
  - "Status: {status_label}" (the word, never color alone).
  - "Runs: {runs}", plus " ({successful} successful)" only
    when `successful_runs` is `Some`.
  - "Facility: {facility_name}" (`resolver.location_name`
    output captured in the row; structure facilities read
    "Unknown Location" by design, section 6.4).
  - Time line, by rank: for an in-progress row, "Ends: {date}
    ({countdown})" when `end_date` is non-empty — date via
    `widgets::format_date_short`, countdown via
    `widgets::countdown_label(Some(end), Utc::now())`, which
    already degrades to "finished" or "unknown finish" in
    words — followed by an egui `ProgressBar` using
    `widgets::progress_fraction` **only** when both dates
    parse (the helper returns 0.0 for unparseable input, so
    the view checks `widgets::parse_esi_date` first and shows
    no bar for a row whose span cannot be known, the market
    filled-fraction rule). For a finished-group row, "Ended:
    {date}" when non-empty, and no bar and no countdown. An
    empty `end_date` renders no time line at all rather than a
    guessed one.
- Nothing else renders for a job: no job number, no blueprint
  instance, no installer, no cost, no probability, no output
  location — the fields section 5.1 carries silently stay
  silent.

**Blueprints.** Heading "Blueprints". On Err: the section
error line. On Ok:

- Empty rows → "No blueprints for this character."
- Otherwise the controls first (they must render even when a
  filter matches nothing, so the user can undo it): a
  `widgets::search_box` bound to `state.industry_search` with
  hint "Filter blueprints by item or location (press / to
  focus)" (the assets hint shape) and the `/` focus plumbing
  copied from Assets (`state.text_input_focused |= focus`,
  consuming `state.focus_search`); then one
  `selectable_label` per `BlueprintKindFilter::ALL` entry
  labeled by `label()`, the current kind selected, a click
  setting `state.industry_blueprint_kind` with an `[INDUSTRY]`
  debug line naming the chosen label. A second typed-match
  rule applies: if the user's search text parses as an
  integer the search still runs as a name substring search
  (usually matching nothing) — it is never reinterpreted as
  an ID lookup.
- Counts line from `blueprint_counts` over **all** loaded
  rows: "{total} blueprints loaded ({originals} originals,
  {copies} copies)." When `BlueprintsData.truncated` is
  true, exactly one further line: "Showing the first pages
  of blueprints only; counts cover the blueprints loaded."
- The filtered list from `filter_blueprint_rows` (section
  7.4): when the filtered set is empty after a non-empty
  load, "No blueprints match the search." (the assets empty
  wording, `src/ui/assets.rs:232` — distinct from the
  truly-empty line above so a filtered-out library never
  claims the character owns none, the Flutter ambiguity).
  Otherwise "Showing {shown} of {filtered} blueprints." with
  `shown = filtered.len().min(BLUEPRINT_RENDER_MAX)`, then
  one block per shown row in sorted order:
  - "{type_name} — {kind_label}".
  - "Quantity: {quantity_label} · {runs_label}" — the
    sentinel words from section 7.3 side by side, so an
    original reads e.g. "Quantity: Original · Infinite runs
    (original)" and a copy "Quantity: Copy · 10 runs"; at no
    point does a -1 or -2 reach the screen as a digit.
  - "{ME label} · {TE label}" via `efficiency_label`.
  - "At: {location_name}".
- Rows past the render cap are not rendered and are accounted
  for only by the showing/of line; there is no "and N more at
  {location}" guessing and no per-location grouping.

Every string above is either a fixed literal, a resolver word
or its fallback, a section 7 word, a fetched date (dates are
not IDs), or a count of rows. A test with an empty resolver
asserts no rendered name, facility, kind, quantity, or runs
label parses as an integer (the assets pattern,
`src/ui/assets.rs:338-356`), extended to the sentinel labels
so "-1" and "-2" can never leak as text.

### 8.4 The step-up panel: one panel, one flag

`industry_reauthorize_panel(ui, state)` copies
`detail_reauthorize_panel` (`src/ui/characters.rs:341-381`)
adapted to two scopes and two sections:

- It appears at the top of the Industry view, once, only when
  `panel_shown` (section 8.2) — that is, only on a typed
  scope failure in either section, never on a plain failure,
  never in demo mode, and never without an active character.
  One panel serves both sections because one constant grants
  both scopes; the sections below it still render, so a
  partially granted character keeps the section that loaded
  (contrast Assets, which returns early because its single
  whole-view result failed).
- Heading: "Industry needs two more EVE permissions." Body
  text names both scopes from
  `EveConfig::INDUSTRY_SCOPES.join(" ")` — never a hand-typed
  copy that can drift from the constant — and states in plain
  words that industry jobs and the blueprint library will not
  load for this character until they are granted, and that
  other views are unaffected.
- When an active character exists, the "Sign in as {name}"
  warning copied from the existing panels: approving as a
  different character is rejected and nothing is saved. The
  name is the character row's own name, as in Assets.
- The button "Re-authorize with EVE SSO" is enabled when
  `!state.demo && !state.auth.is_busy() &&
  state.active_character_id.is_some()` (the Assets rule,
  `src/ui/assets.rs:175`); while busy it shows the spinner
  and auth label like the existing panels. A click does
  exactly two things: log `[AUTH] step-up re-authorize
  requested from Industry view` with the character ID and
  scope names (log-only convention), and set
  `state.stepup_requested = Some(StepUpRequest::new(active_id,
  EveConfig::INDUSTRY_SCOPES))` plus the same honest status
  line the existing panels set ("EVE SSO requested: your
  browser should open to login.eveonline.com."). It clears
  nothing, replaces nothing, and opens no browser itself —
  the generic shell drain owns everything after the flag
  (section 6.3).
- In demo mode the panel is unreachable (demo sections are
  Ok, and `panel_shown` excludes demo in any case), and
  `start_stepup_login` already refuses in demo; no industry
  demo special case is added.

## 9. Demo fixtures (Builder A data, Builder B loader)

### 9.1 New fixture file `assets/demo/industry.json`

Keyed by demo character ID like `assets.json` and
`market.json`, one entry object per character, ESI field
spellings (section 5.1):

```json
{
  "<character_id>": {
    "jobs": [ { "...": "IndustryJob rows" } ],
    "jobs_truncated": false,
    "blueprints": [ { "...": "CharacterBlueprint rows" } ],
    "blueprints_truncated": false
  }
}
```

Builder A authors the concrete rows; the snippet locks shape
only. Content requirements, following the existing fixtures'
"invented numbers, honest shape" convention (fictional demo
characters, real item types, invented `71xxxxxx` instance IDs
for `job_id`, `item_id`, and `blueprint_id`):

- **Both demo characters carry an entry** (the market
  fixture's coverage, so demo switching exercises two
  different libraries; the Empty path is still covered by the
  loader tests with a `"{}"` file, section 9.2).
- Jobs cover, across the two entries: an in-progress
  manufacturing job (activity 1, status active, start in the
  past and end in the future relative to the fixture era so
  the countdown and progress bar render), a paused job, a
  ready job, a delivered job, at least one research or copying
  job (activity 3, 4, or 5, with `product_type_id` null so the
  blueprint-name fallback renders), at least one reaction job
  (activity 11, proving decision I7 renders it as an ordinary
  row), and at least one job with `successful_runs` present.
  Every `start_date` and `end_date` parses; no job row needs
  an unknown activity or status — those fallbacks are unit
  test territory (section 12.2), and the demo must look like
  plausible live data, not like a test case.
- Blueprints cover: an original with `quantity: -1` and
  `runs: -1`, a copy with `quantity: -2` and positive runs, a
  positive-quantity unresearched original stack row, at least
  one researched row (material or time efficiency above zero)
  and one at zero, and rows at both demo stations so location
  search has something to find. Type IDs reuse names already
  seeded where possible (681 "Bantam Blueprint" is in
  `assets/demo/names.json` today).
- Both truncated flags are false in the shipped fixture (demo
  shows the complete-data reading; the truncated disclosure
  lines are covered by unit tests over the row builders and
  by the endpoint cap tests).

Builder A also adds to `assets/demo/names.json` one row
(`category: "inventory_type"` for types, `"station"` for
stations) for every `type_id`, `blueprint_type_id`, and
`product_type_id` the fixture renders and every non-structure
`facility_id` and blueprint `location_id` it renders, so demo
never shows an avoidable Unknown. No row is added for any
`job_id`, `item_id`, `blueprint_id`, `installer_id`, or
`output_location_id`: those IDs are never resolved in demo
either, and a names row for one would silently bless the
exact lookup section 6.4 forbids.

### 9.2 Loader changes, backwards compatible (`src/demo/data.rs`)

Following the chain at lines 210-369 exactly:

```rust
pub const DEMO_INDUSTRY_JSON: &str = include_str!("../../assets/demo/industry.json");

/// One demo character's industry fixture: raw row sets. Demo
/// seeding composes an `IndustryData` from this with both
/// sections Ok, so this is deliberately not `IndustryData`.
#[derive(Debug, Clone, Default)]
pub struct DemoIndustryData {
    pub jobs: Vec<IndustryJob>,
    pub jobs_truncated: bool,
    pub blueprints: Vec<CharacterBlueprint>,
    pub blueprints_truncated: bool,
}

pub fn load_demo_bundle_with_industry(
    characters_json: &str, skillqueue_json: &str, wallet_json: &str,
    assets_json: &str, character_detail_json: &str, market_json: &str,
    industry_json: &str,
) -> AppResult<DemoBundle>;
```

- `DemoCharacterData` gains `pub industry:
  Option<DemoIndustryData>`; the private `IndustryFileEntry`
  mirrors `MarketFileEntry` (lines 180-196) with
  `#[serde(default)]` on all four fields. The market-struct
  reasoning applies unchanged: the demo type is deliberately
  not the live bundle, because seeding composes the live one.
- `load_demo_bundle_with_market` keeps its meaning — a bundle
  with no industry data — and chains to the new top with
  `"{}"` for the industry text, exactly as each older arity
  already delegates; `load_demo_bundle` calls
  `load_demo_bundle_with_industry` with `DEMO_INDUSTRY_JSON`.
  A `"{}"` industry file parses to an empty map, so every
  existing test literal and every older caller keeps working
  and yields `industry: None` — full serde backwards
  compatibility, no fixture version field anywhere.
- The key loop mirrors the market loop (lines 324-343):
  `parse_character_key`, one `[DEMO]` debug line with both
  row counts, slot insert.
- `validate_bundle` gains an only-when-present industry block
  in the assets/detail/market pattern (lines 432-543): job
  IDs unique within the entry's jobs; blueprint item IDs
  unique within the entry's blueprints; every job
  `start_date` and `end_date`, and every present `pause_date`
  and `completed_date`, parses via `parse_esi_datetime`.
  Failures reuse the existing `[DEMO] invalid demo bundle`
  message shape. No scope, region, or sentinel validation is
  added: the fixture's sentinel spread is content review
  (section 9.1), not a structural guarantee the loader
  enforces, matching how the market block validates shape
  rather than taste.

### 9.3 Seeding

`apply_character` gains, after the market install (lines
796-835), the industry install with the same
Empty-if-absent rule:

```rust
state.industry = match &per.industry {
    Some(fixture) => LoadState::Ready(IndustryData {
        jobs: Ok(IndustryJobsData {
            jobs: fixture.jobs.clone(),
            truncated: fixture.jobs_truncated,
        }),
        blueprints: Ok(BlueprintsData {
            blueprints: fixture.blueprints.clone(),
            truncated: fixture.blueprints_truncated,
        }),
    }),
    None => LoadState::Empty,
};
```

with a `[DEMO]` debug line recording `industry_present`, in
the style of the detail and market lines (lines 787-802).
Locked details:

- Both sections compose as Ok, like character detail: a demo
  fixture represents successfully loaded data, and demo has
  no scope story (the step-up panel is unreachable in demo by
  section 8.4). No `demo_type_name`-style helper is needed:
  unlike the market selection, the industry bundle carries no
  captured name — the view derives every label from the
  resolver at render time, and the demo resolver is seeded
  from `names.json` by existing code.
- The assignment runs on every `apply_character`, so demo
  character switching can never leave the previous character's
  jobs or blueprints installed (the stale-bundle regression
  the assets, detail, and market installs each guard against;
  section 12.2 carries the industry version of that test).
  `industry_search` and `industry_blueprint_kind` are not
  touched here, for the section 4.3 reason: filter text is
  not character data.
- `seed_demo_state`'s failure arm (lines 929-933) adds
  `state.industry = LoadState::Error(format!("Demo data
  failed to load: {e}"))` with the same message as its
  neighbours, so a broken bundled fixture degrades the
  Industry view to the same honest error instead of an
  eternal spinner.
- Demo never persists industry data: `seed_bundle_into_db`
  gains industry in its in-memory-only comment (lines
  947-948) and no repository call.

## 10. Industry as the eighth view, and the README

### 10.1 The `View` enum (Builder B, `src/app/state.rs`)

Insert `Industry` between `Market` and `Settings`:

- The enum gains `Industry` before `Settings`; `ALL` becomes
  `[View; 8]` in the order Dashboard, Characters, Skills,
  Wallet, Assets, Market, **Industry**, Settings; `label()`
  gains `View::Industry => "Industry"`. `from_index`,
  `index`, `next`, and `previous` need no edits (derived from
  `ALL`, lines 51-65). The enum doc comment ("The seven views
  (keys 1-7 in the shell)", line 15) becomes eight views,
  keys 1-8.
- Key numbering: 1 Dashboard, 2 Characters, 3 Skills,
  4 Wallet, 5 Assets, 6 Market unchanged; **7 Industry (new);
  Settings moves from 7 to 8**. Settings is again the right
  view to renumber — the market slice moved it 6 → 7 for the
  same reason: it is the last view, so exactly one existing
  key changes and every daily-driver view keeps its key.
- Persisted startup-view safety: the saved value is a label
  string matched against `ALL` at startup and written back by
  label (`src/app/shell.rs:341-345`, `:1753-1767`), so a user
  who saved "Settings" still starts on Settings (now key 8),
  and a user who later saves "Industry" works on any newer
  build; an older build meeting the label "Industry" finds no
  match and keeps its default view, which existing code
  already handles by ignoring the saved value. No migration,
  no numeric remapping, no settings-schema change. Builder B
  updates the state test expectations (lines 647-666):
  `from_index(6) == Some(View::Industry)`, `from_index(7) ==
  Some(View::Settings)`, `View::Market.index() == 5`,
  `View::Industry.index() == 6`, `View::Settings.index() ==
  7`, `View::Market.next() == View::Industry`,
  `View::Industry.next() == View::Settings`,
  `View::Settings.previous() == View::Industry`.
- `src/ui/mod.rs` gains `pub mod industry;` (Builder B).

### 10.2 Shell chrome (integrator, except the one pre-authorized line)

- The view-dispatch match (`src/app/shell.rs:1851-1861`) is
  exhaustive, so the crate does not compile until an Industry
  arm exists. As in prior slices, **Builder B is
  pre-authorized to add exactly one line there**:
  `View::Industry => ui::industry::show(ui, &mut self.state,
  &self.resolver),` placed before the Settings arm. That is
  the entire exception; every other `shell.rs` change —
  including the section 6 wiring — is the integrator's.
- Integrator chrome updates, each a text or key-array change
  and nothing more: the keyboard key array (lines 1687-1702)
  gains `egui::Key::Num8` (order preserved; `from_index` does
  the rest); the rail heading "Views (keys 1-7)" (line 1834)
  and the status-bar text "Keys: 1-7 views, …" (line 1871)
  become 1-8; the rail body itself iterates `View::ALL` and
  prints `idx + 1` (lines 1835-1843), so labels renumber
  automatically. The two texts outside `shell.rs` that carry
  the old numbering are also the integrator's, so no second
  builder edits those files: `no_character_panel`'s "Keys:
  1-7 switch views" (`src/ui/widgets.rs:162`) and the Settings
  keyboard help "1-7 views" (`src/ui/settings.rs:112`) become
  1-8. A grep for `1-7` across `src/` returning nothing is
  part of the integration check (section 12.3).
- The Settings log filter gains the new tag, also integrator
  work in the same file it already touches: `LOG_TAGS`
  (`src/ui/settings.rs:7-18`) goes from `[&str; 10]` to
  `[&str; 11]` with `"[INDUSTRY]"` added, plus the one-line
  assertion its test already makes for `"[WALLET]"` and
  `"[ASSETS]"` (lines 198-199). The pre-existing absence of
  `"[MARKET]"` from that list (section 2.1) is recorded but
  **not** fixed here — it is a one-line follow-up for its own
  change, and bundling it would silently widen this slice's
  diff beyond industry.
- Settings' startup-view picker iterates `View::ALL`
  (`src/ui/settings.rs:85-100`), so Industry becomes
  choosable with no settings logic edit and persists by label
  through existing code. If the picker row overflows on
  narrow windows, that is a pre-existing layout property of
  an eight-label `horizontal` row, not something this slice
  redesigns.

### 10.3 README (integrator)

`README.md` gains one "What works today" bullet for Industry
between Market and Settings, updates "(1-7 views" to 1-8 in
the Settings bullet (line 20), and splits the roadmap bullet
(line 26) so that only the still-true parts remain there:
"manufacturing calculator" and "PI management" stay on the
roadmap as unimplemented, explicitly, and "Industry &" no
longer frames the shipped read-only slice as pending. The
Industry bullet states, in plain words: read-only industry
view for the active character; industry jobs with activity
and status in words, facility names, and finish countdowns;
a searchable blueprint library (originals and copies, sorted
by name) with efficiency and run information; both sections
need the EVE SSO scopes `esi-characters.read_blueprints.v1`
and `esi-industry.read_character_jobs.v1`, which first
sign-in deliberately does not request and which the Industry
view offers to grant through the same step-up flow as Assets
(approving as a different character is rejected and nothing
is saved), and a missing scope affects only its own section;
nothing industry-related is stored, no job can be started,
cancelled, or delivered, and there is no production, cost,
or profit calculator; and, matching the honesty pattern of
the Assets, JWT, and Market bullets, that this path has not
been live-verified against a real EVE account yet (unless it
has been by integration time, in which case the integrator
says what was verified instead). The Status paragraph (line
32) gains "industry" in its implemented list and drops it
from the not-present list, keeping fitting, exploration, and
corporation as they are.

## 11. File ownership and the frozen contract

Two builders work in parallel against the frozen signatures
below; the integrator wires the shell afterwards. Every
commit in the slice keeps `cargo test` green on its own
(Builder B's pre-authorized dispatch line, section 10.2,
exists precisely so the new enum variant compiles before
integration, and Builder A's endpoints land as tested dead
code until the integrator calls them, as earlier endpoint
slices did).

### 11.1 Frozen signatures (all sections above are the authority)

- Models: `CharacterBlueprint`, `IndustryJob` with the
  section 5.1 fields and nullability.
- Endpoints: `INDUSTRY_MAX_PAGES`,
  `get_character_industry_jobs`, `get_character_blueprints`
  with the section 5.2 signatures, paths, and
  `(rows, truncated)` returns.
- Config: `EveConfig::INDUSTRY_SCOPES` (section 5.3).
- State: `IndustryJobsData`, `BlueprintsData`, `IndustryData`
  with `needs_industry_stepup()`, `BlueprintKindFilter` with
  `ALL` and `label()`, and the three section 4.2 `AppState`
  fields (`industry`, `industry_search`,
  `industry_blueprint_kind`).
- Pure UI helpers in `src/ui/industry.rs`: `activity_label`,
  `status_label`, `is_in_progress_status`, `IndustryJobRow`,
  `industry_job_rows`, `JobCounts`, `job_counts`,
  `blueprint_is_original`, `blueprint_kind_label`,
  `blueprint_quantity_label`, `blueprint_runs_label`,
  `efficiency_label`, `BLUEPRINT_RENDER_MAX`, `BlueprintRow`,
  `blueprint_rows`, `filter_blueprint_rows`,
  `BlueprintCounts`, `blueprint_counts`, `show`.
  `is_in_progress_status` is frozen beyond the module because
  the integrator's `needs_tick` clause (section 6.5) may call
  it; if the shell instead matches the three status strings
  inline, the two must still agree, and the helper remains
  the authority.
- Demo: `assets/demo/industry.json` shape (section 9.1),
  `DEMO_INDUSTRY_JSON`, `DemoIndustryData`,
  `DemoCharacterData::industry`,
  `load_demo_bundle_with_industry`.
- Shell (integrator): the `industry: Box<IndustryData>` field
  on `BackendMsg::Refreshed` (section 6.2). No new message
  variant and no new request flag exists in this slice.

Cross-builder structure literals: `IndustryData`,
`IndustryJobsData`, and `BlueprintsData` are constructed
literally by the shell refresh task and by demo seeding, and
`DemoIndustryData` by the loader; adding a field to any of
them after freeze is a design change.

### 11.2 Builder A — endpoints, models, scope constant, fixtures

Owns:

- `src/esi/models.rs`: the two models and their parse tests.
- `src/esi/endpoints.rs`: the two endpoints, their private
  capped helpers, `INDUSTRY_MAX_PAGES`, and the mock-server
  tests.
- `src/config.rs`: `INDUSTRY_SCOPES` and its exact-set plus
  disjointness test only.
- `assets/demo/industry.json`: new file, section 9.1
  contents for both demo characters.
- `assets/demo/names.json`: the type and station rows the
  industry fixture renders (and no instance-ID rows).
- `tests/fixtures/industry.json`: new file, one object with
  `industry_jobs` and `blueprints` row sets in ESI spelling,
  invented `71xxxxxx` instance IDs, including an
  empty-object row in at least one set (the assets fixture
  pattern) and the sentinel, null-cost, reaction, and
  copied-blueprint variants its parse test asserts.
- `tests/esi_models.rs`: the `industry_fixture_parses` test
  and `{}`-default assertions for both models added to
  `empty_payloads_default_instead_of_failing`.

Builder A touches no state, demo-loader, UI, shell, storage,
auth, names, or error code. A's commit is green alone because
untouched callers compile against new tested dead code, the
bundled demo fixture file is not yet referenced by any
`include_str!`, and the new integration test reads only A's
own fixture.

### 11.3 Builder B — state, demo loader, UI

Owns:

- `src/app/state.rs`: `View::Industry` and the renumbering
  test updates, the industry types and filter enum, the new
  `AppState` fields, and the switch/removal/empty resets with
  their tests.
- `src/demo/data.rs`: `DEMO_INDUSTRY_JSON`,
  `IndustryFileEntry`, `DemoIndustryData`,
  `DemoCharacterData::industry`,
  `load_demo_bundle_with_industry`, the `load_demo_bundle_with_market`
  delegation change, the validation block, and the
  `apply_character` / `seed_demo_state` /
  `seed_bundle_into_db` touches.
- `src/ui/industry.rs`: new file — section 7 helpers, both
  sections, the step-up panel, `show`, in-module tests.
- `src/ui/mod.rs`: `pub mod industry;`.
- `src/app/shell.rs`: **only** the one pre-authorized
  dispatch line (section 10.2).
- `tests/demo_seed.rs`: the per-feature demo industry test
  asserting resolved job and blueprint rows for both demo
  characters through the section 7 builders (mirroring
  `demo_market_renders_resolved_for_both_characters`).

Nothing B ships calls the network or Builder A's endpoints;
B compiles against A's models only. B's view honestly shows
Loading (live, pre-integration: `start_refresh` does not yet
fill the bundle) or the demo bundle (fully working in demo,
which is also how B demonstrates the view before
integration) — the established pattern for a view ahead of
its wiring, not faked completion, because the load states
say exactly what has and has not loaded.

### 11.4 Integrator — shell refresh wiring and README

Owns everything else in `src/app/shell.rs` for this slice:
the `Refreshed.industry` field and its construction (the two
tolerant sub-fetches with fixed wording and `[INDUSTRY]` warn
logs), the one-line drain install, the `RefreshFailed`
industry guard, the `schedule_name_resolution` industry
block, the `needs_tick` clause, `Num8` in the key array, and
the two 1-7 → 1-8 texts in the shell; plus the 1-7 → 1-8
texts in `src/ui/widgets.rs` and `src/ui/settings.rs`, the
`"[INDUSTRY]"` entry in `LOG_TAGS` with its test assertion,
and `README.md` per section 10.3. The integrator also owns
the final scope gates (section 12.3) and the demo smoke run.
No other file in the tree changes in this slice:
`src/error.rs`, `src/esi/client.rs`, `src/auth/`,
`src/storage/`, `src/names/`, and every other `src/ui/`
module are untouched apart from the two named text edits in
`widgets.rs` and `settings.rs`.

## 12. Test plan and gates

Each builder's tests land with its code; every named behavior
in sections 4-10 has at least one test or gate below.

### 12.1 Builder A

- Models (`src/esi/models.rs` tests plus
  `tests/esi_models.rs`): full-row parse for both structs with
  every field asserted; `{}` defaults parse for both; every
  job `Option` present, absent, and null (notably `cost: null`
  staying `None`, never 0.0); `quantity: -1`, `quantity: -2`,
  and `runs: -1` parse as the plain integers they are (word
  rendering is the UI layer's job, tested there); unknown
  future fields ignored, including a stray `runs_remaining`
  key parsing harmlessly; the `tests/fixtures/industry.json`
  round trip asserting row counts, key field values, the
  empty-object row's defaults, and the sentinel rows.
- Endpoints, against the in-file mock-server pattern
  (`src/esi/endpoints.rs:588-712`, fresh-token client):
  - blueprints walk two `X-Pages: 2` pages, return rows in
    fetch order with `truncated: false`, and the captured
    second request carries `page=2`;
  - jobs make one request whose captured query contains
    `include_completed=true` on the embedded path (the
    path-embedding proof, the `?from_id=` hazard) and return
    `truncated: false` on a single-page response;
  - jobs also walk when `X-Pages` says more: two pages
    returned in fetch order;
  - cap behavior on both walks: `X-Pages: 5` with helper
    `max_pages: 2` issues exactly two requests and returns
    `truncated: true`;
  - missing `X-Pages` with an empty second page stops clean
    with `truncated: false`; missing `X-Pages` with a
    non-empty page landing on the cap returns
    `truncated: true` (the Flutter silent-truncation case,
    now disclosed);
  - a mock 403 on each endpoint maps to
    `EsiError::Reauthorize` with `needs_reauthorize(&e)` true
    (the assets scope-failure test pattern);
  - a page-2 error propagates on both walks (no partial Ok);
  - both endpoints fail with a no-tokens error when no token
    store is attached, and neither error's rendered text
    contains the character's numeric ID (the
    `src/error.rs:184-190` property, asserted at this layer
    too).
- Config: `INDUSTRY_SCOPES` equals exactly the two grounded
  scopes in order; every entry is absent from
  `FIRST_AUTH_SCOPES`; the existing first-auth, assets,
  market, and character-detail scope tests pass untouched.

### 12.2 Builder B

- Words: all six activity mappings exact; unlisted values
  (0, 2, 7, -1, and a large future value such as 99) all
  return "Unknown activity" — explicitly including at least
  one value never enumerated in section 7.1, so the fallback
  is proven rather than assumed; all six status mappings
  exact; unknown, empty, and differently cased statuses
  return "Unknown status" and the input string appears
  nowhere in any output; `is_in_progress_status` true exactly
  for active, paused, ready.
- Sentinels: quantity -1 → "Original", -2 → "Copy", -3 →
  "Unknown quantity", 0 → "0", positive → its digits; runs
  -1 → "Infinite runs (original)", -2 → "Unknown runs",
  0 → "0 runs", positive → "{n} runs";
  `blueprint_is_original` true exactly at runs -1 (including
  false for a runs -2 row and false for a positive-runs row
  whose quantity is -2 kept out of classification);
  `blueprint_kind_label` agrees with the predicate;
  efficiency labels clamp a negative to 0 and pass positive
  values through.
- Job rows: display type prefers a positive
  `product_type_id`, falls back to `blueprint_type_id` on
  `None` and on a non-positive product; ordering puts every
  in-progress row before every finished row regardless of end
  dates, soonest `end_date` first within a rank, an empty
  `end_date` last within its rank, then `start_date`, then
  `job_id`; a reaction job interleaves by the same keys (not
  filtered, not grouped); negative `runs` clamps to 0;
  `job_counts` saturates trivially-correct small counts and
  counts in-progress by the same predicate the sort uses;
  empty input gives empty rows and zero counts.
- Blueprint rows: sort is by resolved type name
  (case-insensitive, with the location and item-ID
  tie-breaks), proven with rows whose type-ID order differs
  from their name order; search matches type names and
  location names case-insensitively, an empty query matches
  all, and a query equal to a row's numeric type ID or item
  ID matches nothing (the anti-Flutter regression); kind
  filter keeps originals only, copies only, and composes with
  search; `blueprint_counts` reports total/originals/copies
  over the unfiltered rows with originals + copies == total;
  the rendered subset never exceeds `BLUEPRINT_RENDER_MAX`
  while the counts still describe the full loaded set
  (proven with a generated row list longer than the cap).
- Raw-ID safety with an empty resolver (assets pattern
  extended): every `type_name` is "Unknown Item", every
  `facility_name` and `location_name` is "Unknown Location",
  and no name, kind, quantity, runs, activity, or status
  label from any helper parses as an integer — with the
  sentinel rows (-1/-2) in the input, so the strings "-1" and
  "-2" are proven absent from every rendered field.
- State: the section 10.1 renumbering expectations; switch
  clears a Ready industry bundle to Loading, same-character
  reselect keeps it, removing the active character clears it,
  removing a non-active character keeps it, removing the last
  sets Empty (mirroring the detail tests); switch and
  removal leave `industry_search` and
  `industry_blueprint_kind` untouched;
  `needs_industry_stepup()` matrix (both Ok, jobs-only
  reauthorize, blueprints-only reauthorize, both reauthorize,
  plain errors false).
- Demo loader: the bundled bundle loads with industry entries
  for both characters; every older arity
  (`load_demo_bundle_from`, `_with_assets`, `_with_detail`,
  `_with_market`) still loads the same literals with
  `industry: None`; `load_demo_bundle_with_industry(...,
  "{}")` yields `industry: None` (serde back-compat);
  validation rejects a duplicate job ID, a duplicate
  blueprint item ID, an unparseable `start_date`/`end_date`,
  and an unparseable present `completed_date`;
  `apply_character` installs Ready with both sections Ok for
  a fixture character, Empty for an industry-less bundle
  applied after an industry character (the stale-bundle
  regression mirroring detail and market), and preserves the
  search text across both.
- Demo seed integration (`tests/demo_seed.rs`): for both demo
  characters, `seed_demo_state` / `apply_character` leave
  `state.industry` Ready, and the section 7 builders over it
  yield resolved (non-Unknown) type and facility/location
  names for the fixture rows — proving `names.json` coverage
  — while no builder output contains any fixture `job_id`,
  `item_id`, or `blueprint_id` value as text.

### 12.3 Integrator gates

Commands, all run against the integrated tree:

- `cargo test`, `cargo clippy --all-targets -- -D warnings`,
  `cargo fmt --check`, `cargo build` (the CI set,
  `.github/workflows/ci.yml`).
- Scope gates over the slice diff (`git diff afa6c10`):
  - `FIRST_AUTH_SCOPES` block byte-identical (the config diff
    shows only the additive constant and its test);
  - no new `auth_post` or `public_post` call site anywhere;
  - no diff under `src/storage/` at all (no schema
    migration), and no `repositories::` call in the industry
    sub-fetch construction;
  - the strings `esi-planets`, `read_corporation`,
    `corporation` industry routes, `industry/systems`,
    `industry/facilities`, and `/planets/` appear nowhere in
    `src/` (planetary, corporation, and cost-route boundary);
  - no `format!` in `src/ui/industry.rs` renders `job_id`,
    `item_id`, `type_id`, `blueprint_id`, `facility_id`,
    `location_id`, `activity_id`, `installer_id`,
    `output_location_id`, or `completed_character_id`
    (resolver calls and sort keys using those fields are
    expected and fine; interpolation into a rendered string
    is the failure);
  - `quantity` and blueprint `runs` reach rendered text only
    through `blueprint_quantity_label` and
    `blueprint_runs_label` (a grep for `.quantity` and the
    blueprint rows' `runs` uses in `show()` confirms no direct
    interpolation);
  - no `1-7` text remains anywhere in `src/` (renumbering
    completeness, section 10.2);
  - no Dart file restored (`git status` shows no `lib/`
    paths), and no fixture or log line contains a token
    value, code, state value, or authorize URL (grep the new
    fixture files and new log statements).
- Manual/demo smoke: run `--demo`, open Industry with key 7,
  confirm both sections render with resolved names, an
  in-progress job's countdown ticks once per second with its
  progress bar advancing (section 6.5), the reaction job
  reads as an ordinary row, originals and copies read with
  sentinel words and no -1 or -2 digit anywhere, search finds
  blueprints by item and location name and finds nothing by a
  typed numeric ID, and the kind filter narrows with honest
  counts; switch demo characters and confirm the bundle
  follows. Then, without demo, confirm the signed-out
  Industry view shows the no-character panel. Live ESI
  verification against a real account is desirable but
  explicitly not a merge gate for this slice, in line with
  the Assets, JWT, character-detail, and Market slices'
  recorded posture; the README wording (section 10.3)
  records whichever is true at integration time. Token
  values, codes, state, and authorize URLs are never printed
  during any check.

## 13. Explicit non-goals

Everything in the hard scope (section 1.1), plus the nearby
temptations, named so nobody has to guess:

- No job control of any kind: no starting, cancelling,
  pausing, resuming, or delivering a job, and no ESI write
  for any other purpose. A `ready` job tells the user to go
  in-game; the app never acts on it.
- No calculator or derived industry math: no manufacturing
  material lists, no invention probability (neither the
  Flutter slider model nor any use of the fetched job
  `probability` field), no reaction inputs or outputs, no
  production-chain tree, no job cost, install fee, blueprint
  valuation, profit, margin, or break-even figure, and no
  successful-run rate. The three retired Flutter calculator
  tabs (invention, reactions, production chains) are not
  ported in any form, including their dummy data.
- No planetary industry: no colonies, pins, extractors, or
  `esi-planets.manage_planets.v1`. The retired app carried
  planetary interaction as a separate feature
  (`lib/features/pi/` at `ed698d3`, its own endpoints under
  `/characters/{id}/planets/`); it shares nothing with this
  slice beyond once living in the same scope list, and that
  list is not copied (section 5.3).
- No corporation industry: no corporation jobs, corporation
  blueprints, division or hangar handling, and no corporation
  scope (section 5.4). Character jobs installed for a
  corporation still render as the character's own rows
  exactly as ESI returns them; nothing corp-specific is
  labeled or filtered.
- No public industry data: no `/industry/systems/` cost
  indices and no `/industry/facilities/` list (section 5.4).
- No persistence: no database table, column, cache, TTL, or
  ETag handling for jobs or blueprints; industry state dies
  with the process, and a live relaunch shows Loading until
  the startup refresh lands. Flutter's replace-all Drift
  storage is a rejected design here.
- No blueprint library beyond the locked slice: no grouping
  by location or type, no researched/unresearched filter, no
  material or time efficiency sort, no blueprint detail
  screen, no product or material enrichment from SDE data, no
  "what can I build" matching against assets, and no icons
  beyond what egui text already provides.
- No job list beyond the locked slice: no grouping by
  activity, status, or facility, no jobs search box, no
  completed-history date filter, and no notification when a
  job finishes (the countdown ticks only while the app runs).
- No on-demand or background industry fetching: no separate
  fetch path, no timer, no per-view refresh button
  (section 8.1). The main refresh is the only trigger.
- No change to `FIRST_AUTH_SCOPES`, the step-up flow, JWT
  verification, token storage, the refresh pipeline's hard
  fetches, or any other view's behavior — beyond the shared
  effects this slice names: the `Refreshed` field, the
  `RefreshFailed` guard, the name-scheduling block, the tick
  clause, and the Settings renumbering.

## 14. Risks and unresolved items

- **Scope strings are grounded in documents and shipped
  configuration, not in a live call.** Both scope strings,
  both routes, `include_completed=true`, and the `page` walk
  are confirmed by the specification table and the retired
  app's shipped client (section 2), and the mock-server tests
  prove the request shape this code sends; but no inspected
  body executed these requests from Rust. Live acceptance is
  unverified until someone runs against a real EVE account.
  The failure geometry is per-section by construction: if a
  scope string or route detail is wrong, that section shows
  its fixed error (or the step-up panel on a 403) and the fix
  is one constant or one path string in one function. This
  posture matches the Assets, JWT, character-detail, and
  Market slices, and the README says so (section 10.3).
- **`quantity: -1` rests on thinner evidence than `-2`.**
  Only the `-2` → copy conversion appears in an inspected
  body; `-1` → "Original" is the complementary member of the
  required two-value sentinel pair (section 7.3). Nothing
  structural depends on the word — classification and the
  kind filter read `runs` only — so if live data shows the
  word is wrong, one label function changes and no row was
  ever misfiled. Any future value below -2 renders "Unknown
  quantity" rather than extending the guess.
- **Activity words beyond the grounded six are unknowns by
  design.** Activities 2, 6, 7, 9, and 10 (and anything ESI
  adds later) render "Unknown activity" until someone grounds
  their names in an inspected source; that is the honest
  cost of the no-numeric-fallback rule, recorded here so a
  future "unknown activity on my research job" report is
  read as a grounding task, not a rendering bug.
- **Jobs pagination behavior is locked defensively, not
  observed.** Flutter made one jobs request and ignored
  `x-pages`; whether live ESI ever pages this route for a
  single character was not independently observed. The capped
  walk is correct in both worlds (one request when the header
  says one page or is absent with an empty follow-up; a
  disclosed walk otherwise), which is why it was chosen over
  copying the single request.
- **`INDUSTRY_MAX_PAGES = 10` and `BLUEPRINT_RENDER_MAX =
  100` are judgment calls, recorded.** Ten pages copies the
  in-tree market cap; a very large blueprint library may hit
  it, in which case the truncated line and the counts make
  the partial load explicit instead of silent, and raising
  the constant is a one-line change once live page sizes are
  known. The render cap trades completeness on screen for a
  bounded frame, with search and the kind filter as the
  narrowing path; both caps over-warn rather than
  under-report (a non-empty page landing exactly on the page
  cap with no header counts as truncated even if it was in
  fact the last page).
- **Truncated jobs can hide the soonest finish.** With
  `include_completed=true`, an unfetched page could contain
  an in-progress job ending sooner than every loaded row, so
  under truncation the ordering and the in-progress count
  describe the loaded rows only. The disclosure line says
  exactly that; there is no way to do better without fetching
  the pages, which is what the cap exists to bound.
- **Countdowns use the local clock.** Progress and countdown
  text derive from `Utc::now()` at render time through the
  existing widget helpers, like the skill queue; a skewed
  local clock skews both views equally. Server-time
  correction is not part of this slice.
- **Industry is excluded from cached startup state.**
  `load_cached_state` does not fill it (nothing is
  persisted), so a live relaunch starts the Industry view at
  Loading until the startup refresh lands — the in-memory
  scope working as intended, not an oversight, and identical
  to assets, character detail, and market today.
- **Deferred, not decided here:** live verification against a
  real EVE account (including whether CCP returns any
  activity or status outside the grounded sets in practice);
  whether a future slice renders output locations, installers
  by resolved character name, or blueprint location flags;
  the one-line `LOG_TAGS` follow-up for the missing
  `[MARKET]` tag (section 10.2); and any use of engine-room
  data this slice carries silently (`cost`, `probability`,
  `duration`), which a future design would need to justify
  against the no-calculator rule rather than inherit.

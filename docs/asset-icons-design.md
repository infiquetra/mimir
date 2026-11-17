# Item type icons in the Assets view — design

Base: `develop` at `64d0744` (779 tests, post market-icon merge
[#594](https://github.com/infiquetra/mimir/pull/594)).
Branch: `feat/rust-asset-icons`. Slice goal: show each rendered
asset row's item type icon in the Assets view through the shipped
`ImageKind::Type` pipeline. Two blockers named by the type-icons
discovery are re-verified from bodies below and both are real:
`AssetRow` drops `type_id` in grouping (section 1), and asset rows
render unbounded with no virtualization (sections 1–2). Section 2
locks an honest volume bound; without that lock this slice ships
nothing.

Standing rules for the whole slice: verify from bodies read this
session, literal test expectations, the user interface never shows
raw ids, `[PORTRAIT]` logs carry kind and id only (never a URL, a
name, pasted text, or an error body), small atomic commits
`type(scope): description` with no attribution, no push or merge
(the parent owns the branch after the design commit), gates
(`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`) pass at every commit. Demo makes zero
network calls.

Evidence in this document comes from bodies read during this
design session on the `64d0744` tree: `src/ui/assets.rs` in full
(`AssetRow` at 15–24, `display_name` at 38–52, `group_assets` at
64–117, `filter_groups` at 122–155, `show` at 240–311, the test
`item` helper at 317–335), `src/esi/models.rs:398-410`
(`AssetItem.type_id` at 402), `src/app/state.rs` (`as_ready` at
105–110, `AssetsData` at 333–336, the `assets` field at 699,
`set_active_character` at 921–1057 with the assets reset at 951,
`remove_character`'s captures at 1132–1149, its retain closure at
1151–1170 and resets at 1178 and 1245, `image_id_known` at
1310–1333, `fitting_type_known` at 1340–1350, `request_portrait`
at 1384–1421, the guard tests at 3259–3334), `src/app/shell.rs`
(`apply_portrait_landing` at 452–485, the assets landing at
1502–1519, the drain at 2211–2278 with its re-check at 2249–2256
and the fetch-size match at 2265–2273, the outer scroll and view
dispatch at 3758–3793), `src/ui/portraits.rs` (`TYPE_ICON_PX` at
41, `prune` at 78–88, texture upload at 107–162, the type-icon
ensure and show delegations at 195–203 and 282–290, `show_logo` at
258–276), `src/portraits.rs:50-72` (sizes and the fetch
semaphore), `src/ui/fittings.rs` (`FITTINGS_RENDER_MAX` at 45,
`render_fitting_items` at 1126–1174, the prune-at-top at 2392),
`src/ui/market.rs:560-607` (the shipped one-icon header and its
single ensure), `src/ui/characters.rs:32` and
`src/ui/dashboard.rs:27` (the prune-at-top precedent),
`src/demo/data.rs` (the demo assets install at 1125–1132), the
demo fixture `assets/demo/assets.json` (counted this session,
section 1), and the vendored egui 0.29.1 source
(`src/containers/scroll_area.rs:733-764`, `show_rows`).

Nothing was taken from memory; every load-bearing claim below
carries a verified body citation.

## 1. Current state (verified)

The Assets view today is names only, and its render is unbounded:

- `show` (`src/ui/assets.rs:240-311`) clones the assets snapshot,
  and in the `Ready` branch builds
  `filter_groups(&group_assets(&data, resolver), &state.assets_search)`
  (line 280), then draws one `ui.heading` per location group
  (286–289, `"{location_name} — {type_count} item types,
  {item_count} total items"`) and one bare `ui.label` per row
  (290–299: `"{display} x{qty} ({type})"` for custom-named rows,
  `"{display} x{qty}"` otherwise). There is no `ScrollArea` inside
  `show`; the view relies on the shell-wide
  `ScrollArea::vertical().show` that wraps every view
  (`src/app/shell.rs:3758`). There is no row cap, no collapsing
  state anywhere in `assets.rs`, and no virtualization: every
  filtered row becomes a widget every frame.
- Search filters before render (line 280). `filter_groups`
  (122–155) keeps all rows of a location whose name matches
  (128–130), else only rows whose display or type name matches
  (131–139), recomputing group counts from kept rows (144–145).
  An empty query is an identity clone (123–124). So the rendered
  set is already the filtered set; an icon ensure inside the row
  loop would cover exactly filtered rows — which, unfiltered, is
  every holding the character owns.
- **Blocker 1 — `type_id` is dropped in grouping.** The source
  has it: `AssetItem.type_id: i64` (`src/esi/models.rs:402`,
  decoded with `#[serde(default)]`). `AssetRow` (15–24) has no
  `type_id` field. `display_name` reads `item.type_id` to resolve
  the type name (line 43) and then discards the id, and the
  `AssetRow` construction in `group_assets` (75–84) copies
  `item_id`, names, quantity, flag, and booleans — with no
  `type_id` line. Section 3 locks the carry-through.
- **Blocker 2 — no honest volume bound exists today.** The demo
  fixture is tiny (counted this session from
  `assets/demo/assets.json`: character 90000001 has 6 rows in 3
  locations with 5 distinct type ids; character 90000002 has 5
  rows in 2 locations with 5 distinct type ids), but that says
  nothing about production holdings, which are whatever the ESI
  assets walk returns — singletons plus stacked materials
  routinely reach hundreds to thousands of rows per character,
  and today every one renders. State plainly: the worst case is
  unbounded, and an icon ensure in the current loop would queue
  one fetch per distinct held type on first view. Section 2 is
  the lock that makes this slice honest.
- The shipped type-icon pipeline already implements everything an
  asset row icon needs except authorization and wiring:
  `ImageKind::Type` with cache file `type-{id}_{size}.png`
  (`src/portraits.rs:106`), `TYPE_ICON_SIZE = 64` as its own
  constant (`src/portraits.rs:60`), the fetch-size arm
  `ImageKind::Type => TYPE_ICON_SIZE` in the shell drain
  (`src/app/shell.rs:2270`), texture name `type-{id}`
  (`src/ui/portraits.rs:138`), and one app-wide semaphore
  `MAX_CONCURRENT_FETCHES = 4` bounding every kind together
  (`src/portraits.rs:72`). `ensure_type_icon_requested` queues
  only a `NotRequested` key (`src/ui/portraits.rs:201-203` via
  `ensure_logo_requested` at 189–193), so a repeated ensure for
  the same type queues nothing more.
- The single fetch guard `AppState::image_id_known`
  (`src/app/state.rs:1310-1333`) admits `Type` today only through
  the two shipped arms (1329–1331): `fitting_type_known` (ship and
  fitted-item type ids from the active character's loaded saved
  fittings, `Ready` `Ok` only, at 1340–1350) **or** the selected
  market type (`market_selected_type_id == Some(id)`, bound 1).
  Four sites share that guard: `request_portrait` (1384–1421,
  ignores non-positive and unknown ids, dedupes the queue by
  `(kind, id)`), the shell drain re-check
  (`src/app/shell.rs:2249-2256`), the landing check in
  `apply_portrait_landing` (`src/app/shell.rs:458-460`), and
  texture `prune` (`src/ui/portraits.rs:78-88`, retains by
  `image_id_known`). `AppState.assets: LoadState<AssetsData>`
  (`src/app/state.rs:699`) is not consulted by any arm today, so
  an asset row ensure would queue nothing.
- Character ownership of assets comes from the reset rules.
  `set_active_character` on a different id sets
  `assets = LoadState::Loading` and clears both reauthorize flags
  (`src/app/state.rs:951-956`); a same-id reselect keeps the
  loaded rows (the reset block runs only when
  `previous_id != character_id`, lines 939–940).
  `remove_character` sets `assets = Loading` when the active
  character is removed (line 1178) and `Empty` when no characters
  remain (line 1245, where `portraits` and `portrait_requests`
  are also cleared at 1241–1242). The assets landing is tolerant:
  success installs `Ready` (line 1504), a scope refusal installs
  `Error` (line 1510), and any other failure keeps existing
  `Ready` rows rather than wiping them (lines 1513–1517).
- `assets::show` takes no texture cache today (line 240:
  `show(ui, state, resolver)`), and the shell dispatch passes
  none (`src/app/shell.rs:3774`) — unlike Characters
  (`src/ui/characters.rs:32`), Dashboard
  (`src/ui/dashboard.rs:27`), Fittings (`src/ui/fittings.rs:2392`),
  and Market (`src/ui/market.rs:572`), which all receive
  `PortraitImageCache` and call `cache.prune(state)` at their
  tops. Section 5 locks the same wiring here.
- In demo mode the shell drain suppresses every spawn
  kind-agnostically (`decide_portrait_start` returning the demo
  refusal, `src/app/shell.rs:2217-2223`), and the demo bundle
  installs `assets = Ready(...)` from bundled data
  (`src/demo/data.rs:1125-1132`), or `Empty` when a character has
  no demo assets. Section 5 covers demo behaviour under the new
  ensure sites.

## 2. The volume bound (locked)

Three mechanisms were considered; this section locks one on
evidence. If none had been honest, this design would ship
nothing, per the slice rule. One is honest.

**Option C — icons only for expanded groups. Rejected.** No
collapsing state exists anywhere in `src/ui/assets.rs`: every
group renders unconditionally (section 1). This option therefore
needs new per-group expansion state, new header interaction, and
new tests — a larger change than the icon itself — and it still
bounds nothing inside one expanded group: a single station
hangar can hold the whole unbounded worst case. It is not an
existing bound and it does not become one by adding half of it.

**Option B — `ScrollArea::show_rows` virtualization. Rejected
for this slice.** The API exists in the vendored egui 0.29.1
(`src/containers/scroll_area.rs:733-764`): uniform
`row_height_sans_spacing`, total height allocation
(`row_height * total_rows`, line 743), a viewport-derived
`Range<usize>` callback (lines 745–760), and
`skip_ahead_auto_ids` for stable ids (line 759). But the Assets
shape does not fit it as a drop-in: group headings
(`ui.heading`, taller than a 20-point icon row) interleave with
rows, so the view would have to flatten into uniform fake-header
rows at one fixed height; the view already renders inside the
shell-wide outer `ScrollArea::show` (`src/app/shell.rs:3758`),
so an inner virtualized area nests one scroll region in another;
and, load-bearing for honesty, virtualization bounds widgets per
frame but **not** fetches per character load — scrolling through
two thousand held types still ensures two thousand distinct
fetches over the session, each retained by the prune superset
(section 4). A per-frame bound presented as a fetch bound would
be dishonest. Feasible API, wrong lock for this slice.

**Option A — a global rendered-row cap (the locked shape).**
Mirror the shipped render caps — `FITTINGS_RENDER_MAX = 100`
(`src/ui/fittings.rs:45`, applied per fitting section with
`.take(FITTINGS_RENDER_MAX)` and a "Showing X of Y items." label
at 1138–1150), `BLUEPRINT_RENDER_MAX = 100`
(`src/ui/industry.rs:161`), `EXPLORATION_RENDER_MAX = 100`
(`src/ui/exploration.rs:22`) — but at the only scope that is
honest for assets: **global across all filtered groups**, not
per group. A per-group cap is explicitly rejected: the number
of location groups is itself unbounded, so per-group 100 times
unbounded groups is unbounded.

Locked mechanism, in `src/ui/assets.rs`:

```rust
pub const ASSETS_RENDER_MAX: usize = 100;
```

In `show`, after `filter_groups` (so search narrows before the
cap and can reveal rows beyond the unfiltered first 100):

- `total_filtered` is the sum of `group.rows.len()` over the
  filtered groups.
- A single `remaining` budget starts at `ASSETS_RENDER_MAX`.
  Groups render in their existing order (total quantity
  descending, then location name, then location id —
  `group_assets` lines 105–110; rows by display name, lines
  89–93). For each group while `remaining > 0`: draw the group
  heading unchanged, render `group.rows.iter().take(remaining)`,
  then subtract the rendered count. Groups reached with
  `remaining == 0` draw no heading and no rows.
- When `total_filtered > ASSETS_RENDER_MAX`, after the last
  rendered row draw exactly one disclosure label:
  `"Showing 100 of {total_filtered} items."` (the fittings
  wording at `src/ui/fittings.rs:1140`, with the shown count
  `total_filtered.min(ASSETS_RENDER_MAX)`).
- The icon ensure lives **inside** the `take` (section 5), so
  the ensure set equals the rendered set by construction:
  at most 100 rows per frame, at most 100 distinct type icons
  per rendered window, each queued at most once per load
  (`ensure` queues only `NotRequested`; `request_portrait`
  dedupes). At the shipped 64-pixel fetch (3.3–6.7 KB per icon,
  `src/portraits.rs:54-60`), one full window is under a megabyte
  of image traffic, further bounded in flight by the 4-fetch
  semaphore. Group headings keep describing the full filtered
  group (`type_count`/`item_count` from `filter_groups`), never
  the rendered subset; the one global disclosure line is what
  tells the reader rendering was truncated. Recomputing headings
  from rendered rows would lie about holdings.

What the cap does and does not bound, stated plainly so a future
reader does not over-claim it. Per frame, widgets and ensures are
hard-bounded at 100 rows. Per character load, the guard set
(section 4) is every distinct type id in the loaded assets — a
superset of any one window — so a user who keeps changing the
search can, over many explicit filters, fetch more than 100
distinct icons in total, each one because its row was actually
rendered, never by a background walk. That is the same
retention-generous / requesting-stingy split the shipped
surfaces use (the whole-fittings-bundle guard behind capped
fitting sections), and it is the honest bound: no frame and no
single view of the list ever queues more than 100 icons, and
nothing fetches for a row that was not rendered.

## 3. `AssetRow` `type_id` carry-through (exact shape)

In `src/ui/assets.rs` only:

- `AssetRow` (lines 15–24) gains one field:
  `pub type_id: i64`, documented as state-only — the image key
  for the row icon, never formatted into any rendered string and
  never logged (the module doc at lines 1–3 already promises
  "never a raw ID"; the field doc repeats it for this field).
- The `AssetRow` construction in `group_assets` (lines 75–84)
  gains one line: `type_id: item.type_id,`.
- `filter_groups` needs no change: both branches clone whole
  rows (lines 129 and 131–139), so the field carries through
  for free. `total_quantity` (57–60) and the sorts (89–93,
  105–110) are unaffected.
- No other construction site exists to update: `AssetRow` is
  built only in `group_assets`; the test `item` helper already
  supplies a `type_id` per fixture row (lines 317–335).
- A decoded `type_id` of 0 (a missing field in remote JSON,
  `#[serde(default)]`) is carried like any other value. It
  renders the blank placeholder box forever and queues nothing,
  because `request_portrait` ignores non-positive ids before it
  ever consults the guard (`src/app/state.rs:1385-1392`).
  Section 7 pins this.

## 4. Guard extension (exact shape), switch validity, prune

The assets arm mirrors the fittings arm's discipline exactly:
type ids sourced from the active character's loaded assets only
— EVE-sourced state, never the bundled catalogue, never search
text. `assets_search` stays a query string; it is never parsed
as an id and never authorizes a fetch (the market design's
honesty argument for `market_search`, unchanged here).

A new private helper beside `fitting_type_known`
(`src/app/state.rs:1340-1350`). Do **not** widen
`fitting_type_known`: its name and contract stay "loaded saved
fittings only" (the market slice kept it unmodified for the same
reason; unions live only in `image_id_known` and the removal
retain):

```rust
/// Whether the active character's loaded assets name this item
/// type (any held row's type). EVE-sourced state only: the
/// assets search text and the bundled catalogue are deliberately
/// not consulted, so nothing user-typed ever authorizes a fetch.
fn asset_type_known(&self, id: i64) -> bool {
    self.assets
        .as_ready()
        .is_some_and(|data| data.items.iter().any(|item| item.type_id == id))
}
```

Unlike the fittings helper there is no inner `Result` to unwrap:
assets land directly as `Ready` or `Error`
(`src/app/shell.rs:1502-1519`), so `as_ready()` (which returns
`Some` only on `Ready`, `src/app/state.rs:105-110`) is the whole
gate. `Ready` scans `items`; `Loading`, `Empty`, and `Error`
authorize nothing — the fittings and standings precedents
(1340–1350, 1355–1369). The tolerant landing needs one explicit
note: a non-scope refresh failure keeps existing `Ready` rows
(`src/app/shell.rs:1513-1517`), so the guard keeps authorizing
those rows' types across a failed refresh. That is shipped
assets semantics — the rows still render as current — and the
guard follows `Ready`; this slice adds no staleness handling.

The `Type` arm of `image_id_known` (lines 1329–1331) becomes
the 3-way union:

```rust
ImageKind::Type => {
    self.fitting_type_known(id)
        || self.asset_type_known(id)
        || self.market_selected_type_id == Some(id)
}
```

Nothing else changes in the guard body. The doc comment on
`image_id_known` (lines 1297–1309) gains one clause: for `Type`,
"the active character's loaded saved fittings (ship and fitted
items), the active character's loaded assets, or the selected
market type". The doc on `fitting_type_known` (lines 1335–1339)
gains "the loaded assets" in its not-consulted list, so the
helper's contract stays literally true. The doc on
`ensure_type_icon_requested` (`src/ui/portraits.rs:195-200`),
which today names "loaded saved fittings or the selected market
type", gains the assets source; the delegation body is
unchanged. (Section 6 assigns each doc fix to its file owner.)

**Character-keyed validity.** Unlike the market arm — selection
state that deliberately survives a switch
(`src/app/state.rs:980-985` keeps `market_selected_type_id`;
see the market design section 3) — the assets arm **is**
character-keyed by construction, because its source is
character-owned data:

- Switch to a different character: `assets = Loading`
  (line 951), so the arm authorizes nothing until the new
  character's assets land. A fetch queued before the switch is
  skipped by the drain re-check (`src/app/shell.rs:2249-2256`);
  a result that lands after the switch is dropped whole by
  `apply_portrait_landing` (`src/app/shell.rs:458-460`); the next
  `prune` drops asset-only textures. Nothing stale may fetch,
  land, or linger under the new character. A type also known
  through fittings or the market selection survives via that
  arm instead (the union is an OR) — its image names the item
  type, not the character, so sharing it is correct.
- Same-id reselect: the reset block does not run (lines
  939–940), `Ready` rows and their icons stay valid — no
  refetch, no re-upload.
- Removing the active character: `assets = Loading` (line 1178),
  same revocation as a switch. Removing the last character:
  `assets = Empty` and all portrait state cleared (lines
  1241–1242, 1245), so nothing remains to authorize anyway.
- The reauthorize panels (`assets_needs_reauthorize`,
  `src/ui/assets.rs:247-251`) return before any row renders, so
  no ensure runs there; the landing behind that panel installed
  `Error` (line 1510), so the guard reads false regardless.
- The one inherited wart, unchanged by this slice: switch away
  while a fetch is still `Loading`, and the dropped landing
  leaves the key `Loading`; the render-path ensure queues only
  `NotRequested` keys (`src/ui/portraits.rs:189-193`), so
  switching back shows the blank box for that type until the
  entry is dropped some other way. That is shipped semantics
  for every kind (the market design section 3 records it); this
  slice inherits it and section 9 keeps the revisit trigger.

**Prune is the superset.** `PortraitImageCache::prune` retains
textures by `state.image_id_known` (`src/ui/portraits.rs:78-88`).
The guard set is every distinct type id in the loaded assets,
union fitting-known types, union the one market selection. The
ensure set (capped rendered rows, section 2) is a subset of the
loaded assets, which is a subset of the guard — so prune can
never drop a texture whose row is on screen, and scrolling or
re-filtering within one load never re-uploads (prune
non-thrash, pinned in section 7). Prune drops only the GPU
texture, never `AppState::portraits`, so a `Ready` image that
leaves the guard (switch, removal) re-uploads exactly once if
its type becomes known again, with no refetch (the
`Arc::ptr_eq` path, `src/ui/portraits.rs:120-123`). Retention
is generous (union), requesting is stingy (rendered rows only)
— the deliberate split from the earlier icon slices.

**Removal retain must mirror the new source**, or asset icons
drop from state on every `remove_character`, even a non-active
removal. The current captures sit at `src/app/state.rs:1132-1149`
(`fitting_type_ids`, then `market_type_id`) and the retain
closure's `Type` arm at line 1166 is
`fitting_type_ids.contains(&id) || market_type_id == Some(id)`.
Locked seam: capture beside them, **before** the active-removal
reset at line 1178,

```rust
let asset_type_ids: Vec<i64> = self
    .assets
    .as_ready()
    .map(|data| data.items.iter().map(|item| item.type_id).collect())
    .unwrap_or_default();
```

and extend the `Type` arm to
`fitting_type_ids.contains(&id) || asset_type_ids.contains(&id) || market_type_id == Some(id)`.
The same closure already retains both `portraits` and
`portrait_requests` (lines 1168–1170), so one arm change covers
both maps. Duplicate ids in the captured `Vec` are fine (the
fittings capture at 1136–1143 also duplicates per fitting);
`contains` is the only consumer. Retain is a pre-removal
snapshot, not ongoing authorization: after an active removal
the guard still reads false (`assets = Loading`), so prune and
landing finish the cleanup exactly as they do for fittings
types today.

**Interaction with the shipped arms.** Adding the assets arm
changes no existing bound: the market arm stays exactly 1 and
not character-keyed; the fittings arm stays whole-bundle and
character-keyed. Overlap needs no rule beyond the OR — a type
held as an asset and also fitted needs either bundle `Ready` to
survive prune. Quick-pick types derived from assets
(`src/ui/market.rs` `quick_pick_types`) gain nothing: only a
*selected* market type authorizes through the market arm, and
this slice adds no ensure in the Market view (section 8).

Trace, end to end (the hard case: type X is held as an asset,
in no saved fitting, not market-selected):

1. **Load.** Assets land `Ready` (`src/app/shell.rs:1504`). The
   first Assets frame groups and filters
   (`src/ui/assets.rs:280`), renders X's
   row inside the 100-row window, and ensures it (section 5).
   `asset_type_known(X)` is true, so `request_portrait(Type, X)`
   moves `(Type, X)` to `Loading` and queues one key
   (`src/app/state.rs:1409-1418`). Later frames queue nothing:
   the key has left `NotRequested`. Five rows of type X ensure
   five times and still queue once.
2. **Switch character mid-fetch.** `assets = Loading` (line
   951). If the key is still queued, the drain re-check skips
   the fetch (`src/app/shell.rs:2249-2256`); if the fetch is in
   flight, `apply_portrait_landing` drops the result whole
   (lines 458–460) and the key stays `Loading` (the inherited
   wart above). The new character's first `prune` drops any
   asset-only `(Type, X)` texture. If X happens to be the market
   selection, the market arm keeps it known through the switch
   and the result lands — correct, because the image names the
   item type.
3. **Land (no switch).** The drain spawns at `TYPE_ICON_SIZE`
   (line 2270) under the 4-fetch semaphore; the landing inserts
   `Ready` under `(Type, X)` only because the guard holds at
   apply time. The texture uploads exactly once per image
   (`Arc::ptr_eq`, `src/ui/portraits.rs:120-123`); before that,
   and on `Failed`, the row shows the blank faint-background box
   from `show_logo` (lines 258–276) — never a fabricated mark,
   never another type's icon, because `show_type_icon` renders
   only the `(Type, row.type_id)` key for that row.
4. **Re-filter.** Narrowing the search re-runs `filter_groups`
   before the cap, so a row beyond the unfiltered window can
   enter the window and ensure then — still rendered-rows-only,
   still at most 100 ensures per frame. A type that leaves the
   window keeps its texture (guard superset), so widening the
   search again re-renders it with no refetch and no re-upload.
5. **Demo.** The demo bundle installs `Ready` assets
   (`src/demo/data.rs:1125-1132`; at most 6 rows, section 1, so
   the cap never engages). Ensures queue at most 5 distinct
   `(Type, id)` keys, but `decide_portrait_start` refuses every
   spawn in demo mode (`src/app/shell.rs:2217-2223`), so the
   keys stay `Loading` forever, the blank box renders, and demo
   makes zero network calls. No demo-specific guard and no
   fixture edit.

## 5. Row layout, ensure sites, shell wiring, demo, logs

**Render size: `TYPE_ICON_PX = 20.0`, reused, no new constant.**
Asset rows are dense list rows, exactly the fittings detail-row
shape `TYPE_ICON_PX` documents (`src/ui/portraits.rs:36-41`:
left of the resolved item name, own constant so a row-density
decision moves nothing else). The market header's
`MARKET_TYPE_ICON_PX = 64.0` (line 47) is a detail header, not a
row, and is not reused here. Fetch 64, render 20 — the shipped
downscale with HiDPI headroom (`src/portraits.rs:54-60`).

**Row layout.** Each rendered row replaces the bare `ui.label`
(lines 290–299) with one `ui.horizontal`, mirroring the fittings
row (`src/ui/fittings.rs:1159-1162`):

```rust
ensure_type_icon_requested(state, row.type_id);
ui.horizontal(|ui| {
    show_type_icon(ui, cache, state, row.type_id, TYPE_ICON_PX);
    ui.label(/* the existing 291-298 text, unchanged */);
});
```

The label strings are byte-for-byte the current ones
(`"{display} x{qty} ({type})"` for custom-named rows,
`"{display} x{qty}"` otherwise). `type_id` is never formatted;
the resolved names beside the icon carry the meaning. A
blueprint copy shows its type's icon like any other row — the
` (copy)` suffix stays text (section 8). The placeholder for
every non-`Ready` state is the `show_logo` blank box — faint
theme background, 2-point rounding, no initial, no spinner
(`src/ui/portraits.rs:270-275`) — in the same 20-point slot, so
rows never change height as icons land.

**Ensure sites: exactly one, rendered rows only by
construction.** The single `ensure_type_icon_requested(state,
row.type_id)` above, inside the section 2 `take(remaining)`
loop, in the `Ready` branch only. There is no ensure in the
`Loading` / `Empty` / `Error` branches (lines 302–309), none in
either reauthorize panel (both return before the `Ready`
branch), none for filtered-but-capped-off rows, none for groups
beyond the budget, and no prefetch anywhere. Because the ensure
sits inside the same bounded iterator that draws the row, the
ensure set equals the rendered set by construction — the
property section 7's count test pins.

**Wiring, point by point:**

- `src/ui/assets.rs::show` gains
  `cache: &mut PortraitImageCache` (after `resolver`, matching
  the Market signature at `src/ui/market.rs:560-565`). It calls
  `cache.prune(state)` at its top — immediately after
  `widgets::mode_notice` (line 242) and **before** every early
  return (no-character at 243–246, reauthorize at 247–251,
  empty and no-match panels inside the `Ready` branch) — so
  textures prune even on frames that render no rows, mirroring
  Fittings (`src/ui/fittings.rs:2392`, prune before its
  no-character return) and Market (`src/ui/market.rs:572`).
  Without it, asset icon textures would linger past a switch
  until some other pruning view was visited.
- `src/app/shell.rs` dispatch: the `View::Assets` arm
  (line 3774) passes `&mut self.portrait_textures`, becoming
  `ui::assets::show(ui, &mut self.state, &self.resolver, &mut self.portrait_textures)`,
  mirroring the `View::Market` arm (lines 3775–3780). No other
  dispatch change; the view stays inside the existing outer
  `ScrollArea::vertical().show` (line 3758) — this slice adds
  no inner scroll area (section 2, Option B rejection).
- `src/ui/portraits.rs`: only the `ensure_type_icon_requested`
  doc fix (section 4). `ensure_type_icon_requested` and
  `show_type_icon` keep their signatures; assets calls them
  exactly as fittings and market do.
- Untouched: `src/portraits.rs` and `src/config.rs` (fetch
  pipeline reused as-is, `TYPE_ICON_SIZE` unchanged),
  `src/esi/` (no new request; `type_id` already decodes),
  `src/demo/data.rs` and `assets/demo/` (demo already fetches
  nothing), `src/ui/fittings.rs`, `src/ui/market.rs`.

**Demo: zero network, no change needed.** Demo assets are
`Ready` from bundled data (`src/demo/data.rs:1125-1132`), the
cap never engages (at most 6 rows, section 1), ensures queue
but the kind-agnostic drain refusal suppresses every spawn
(`src/app/shell.rs:2217-2223`); the shipped
`portrait_start_decision_table` (`src/app/shell.rs:4415-4421`)
already pins `decide_portrait_start(true, _) == Some(Demo)`.
Demo asset rows render the blank box forever, like demo
fittings and market rows today.

**Logs: no new log line.** The render path stays log-free (the
`src/ui/portraits.rs:12-17` convention: per-frame lines would
flood the buffer at up to 100 rows per frame).
`request_portrait`'s existing `[PORTRAIT]` transitions already
carry `kind=type` and the id (`src/app/state.rs:1386-1414`), as
do upload, replacement, and prune (`src/ui/portraits.rs:83-86`,
142–152) and the drain and landing (`src/app/shell.rs:2250-2261`,
468–473). The existing `[ASSETS]` grouping line (items and
locations counts, `src/ui/assets.rs:111-115`) is unchanged, and
no `[ASSETS]` line may gain a `type_id`: kind and id appear
only in the shipped `[PORTRAIT]` lines, never a URL or a name.

## 6. Builder split (A/B, zero file overlap) and integrator list

Two builders, file-disjoint, sharing only the locked contract:
the `image_id_known` `Type` arm is the 3-way union of section 4,
`AssetRow` carries `type_id` per section 3, and
`ensure_type_icon_requested` / `show_type_icon` /
`PortraitImageCache` keep their signatures. B's ensures queue
nothing until A's guard lands, so the integrator lands A first;
both can be authored in parallel. Each builder's tests land in
the same commit as their code (section 7 assigns every test).

- **Builder A — guard** (owns only `src/app/state.rs`):
  - `asset_type_known` beside `fitting_type_known`, the 3-way
    `Type` union in `image_id_known`, and the two doc fixes in
    this file (the `image_id_known` clause; "the loaded assets"
    in `fitting_type_known`'s not-consulted list).
    `fitting_type_known`'s body is unchanged.
  - `remove_character` captures `asset_type_ids` pre-reset
    beside `fitting_type_ids` / `market_type_id` (lines
    1132–1149) and the retain `Type` arm (line 1166) gains
    `asset_type_ids.contains(&id)`.
  - A's tests (section 7, state rows) in the same commit.
- **Builder B — Assets view** (owns `src/ui/assets.rs`,
  `src/ui/portraits.rs`, `src/app/shell.rs`):
  - `type_id` field + one construction line, `ASSETS_RENDER_MAX`
    + global budget + disclosure label, cache parameter,
    prune-at-top, single in-`take` ensure, 20-point horizontal
    rows (`src/ui/assets.rs`); B's assets tests there.
  - The `ensure_type_icon_requested` doc fix
    (`src/ui/portraits.rs`); B's prune non-thrash test there.
  - Dispatch passes `&mut self.portrait_textures` at
    `src/app/shell.rs:3774`; B's landing-after-switch test
    there. No other shell change.
- **Integrator** (after A then B): full four gates; confirm the
  shipped guard tests pass unmodified
  (`switching_character_revokes_fitting_type_knowledge`,
  `market_selection_authorizes_only_the_selected_type`,
  `prune_keeps_type_icon_across_selection_change`,
  `prune_keeps_selected_market_type_icon_across_switch`,
  `market_type_icon_landing_drops_after_deselect`); journal
  entry in `docs/engineering-journal/`; no merge or push.

Explicitly untouched by both: `src/portraits.rs`,
`src/config.rs`, `src/esi/`, `src/demo/data.rs`,
`assets/demo/`, `src/ui/fittings.rs`, `src/ui/market.rs`.

Every commit passes the four gates; the clippy gate includes
`--all-targets` (a prior slice shipped test-code lints by
running clippy without it).

## 7. Test plan (all expectations literal)

Guard table — every row is `image_id_known(ImageKind::Type, id)`
unless the row names a function. A is asset-known only, F is
fitting-known only, M is the market selection, U is none of the
three:

| Setup | Expectation |
|---|---|
| Assets `Ready` holding A; fittings `Loading`; no selection | A true; `request_portrait(Type, A)` queues exactly `[(Type, A)]`, state `Loading` |
| Same setup | U false; requesting U queues nothing, no entry created |
| Assets `Loading` / `Empty` / `Error`, fittings `Loading` | A false in each arm |
| `assets_search = "…"` only (incl. numeric text) | false (search text never authorizes) |
| A held, then `set_active_character` to another character | A true → false; `assets` is `Loading` |
| A held, then same-id `set_active_character` | A stays true |
| A also market-selected (A = M), then the switch | stays true (market arm, not character-keyed) |
| F in loaded fittings, assets `Loading` | F true (unchanged) |
| M selected, assets `Loading`, fittings `Loading` | M true (unchanged) |
| `request_portrait(Type, 0)` / negative, any setup | queues nothing (non-positive pre-check) |

Tests, by owner (names locked; expectations literal):

- **A, `src/app/state.rs`**
  `asset_holdings_authorize_only_held_types` pins the table's
  holdings rows (held true with `Ready` in each non-`Ready` arm
  false, unheld false with queue unchanged and no
  `portraits` entry, numeric `assets_search` false), mirroring
  `market_selection_authorizes_only_the_selected_type` (line
  3275). Duplicate rows of one type queue once.
  `switching_character_revokes_asset_type_knowledge` pins the
  switch rows (true → false on switch with `assets == Loading`,
  true after same-id reselect, still true after switch when the
  id is also market-selected), mirroring
  `switching_character_revokes_fitting_type_knowledge` (line
  3259).
  `removing_character_retains_held_asset_icon`: two-character
  fixture (the last-removal branch clears all portraits at
  lines 1241–1242 and must not be the fixture), A held with
  `(Type, A)` `Ready` and queued; removing the non-active
  character keeps both; removing the active character keeps the
  entry through the retain closure while `image_id_known(A)`
  then reads false (`assets == Loading`).
- **B, `src/ui/assets.rs`**
  `group_assets_carries_type_id_onto_rows`: grouping the
  existing fixtures yields rows whose `type_id` values are
  literally the fixture ids (e.g. 34, 587), and `filter_groups`
  keeps them intact on both the location-match and row-match
  branches.
  `assets_render_max_is_100`: `ASSETS_RENDER_MAX == 100`
  (the fittings precedent at `src/ui/fittings.rs:3259`).
  `assets_show_queues_icons_for_rendered_rows_only`: headless
  render mirroring `market_header_runs_headless_and_queues_one_type_icon`
  (`src/ui/market.rs:912`), with an active character installed
  and `assets = Ready` (without one, `show` returns at the
  no-character panel, lines 243–246, and queues nothing — the
  test asserts that case first). Resolver names are inserted
  so display order is fixture order. Cases: 125 rows of 125
  distinct types in one location, empty search — exactly 100
  queued `(Type, id)` requests, cache empty (blank-box path),
  second frame queues nothing new; 60 + 60 rows in two
  locations — still exactly 100 queued, never 120, so a
  per-group cap fails this test (the global-bound proof); then
  a search matching only the 125th type's row queues exactly
  that one additional key (filter-before-cap). A type repeated
  on 3 rendered rows appears once in the queue. A row with
  `type_id == 0` queues nothing.
- **B, `src/app/shell.rs`**
  `asset_type_icon_landing_drops_after_switch`, mirroring
  `market_type_icon_landing_drops_after_deselect` (line 4789)
  and the fittings landing test: with A held and in no fitting,
  landing `Ok(test_image(8, 8))` returns true and `Ready` is
  8×8; after `set_active_character` to another character,
  landing A at 4×4 returns false and the 8×8 image is still
  there (a dropped landing writes nothing).
- **B, `src/ui/portraits.rs`**
  `prune_keeps_held_asset_type_icon_within_one_load`, mirroring
  `prune_keeps_type_icon_across_selection_change` (line 887):
  A `Ready` uploads once; prune retains the same texture handle
  across an `assets_search` change and across a fittings
  selection change (same handle, cache length unchanged — no
  re-upload); after `assets` leaves `Ready` (switch), prune
  drops the asset-only texture while an overlapping
  fitting-known texture survives.
- **B, demo**: with the demo bundle installed and its first
  character active (`assets = Ready`, 6 rows, 5 distinct held
  types — section 1), a headless `show` queues exactly those
  5 `(Type, id)` keys and uploads
  nothing; `decide_portrait_start(true, false) == Some(Demo)`
  (already pinned by the shipped `portrait_start_decision_table`
  at `src/app/shell.rs:4415-4421`) guarantees none spawn, and
  no `(Type, id)` ever becomes `Ready`. No demo fixture edit.
- No widget-text harness is invented for the disclosure label:
  its wording is locked in section 2 and verified by the count
  tests above plus code review, the same standard the shipped
  caps meet.

## 8. Exclusions (follow-ups, each needs its own design)

- **Search-result icons beyond the rendered set.** Rows that
  match the search but fall beyond the 100-row window fetch
  nothing — no prefetch of the filtered set, no background walk
  of held types. Widening the ensure set past rendered rows
  breaks the section 2 bound and needs its own design.
- **Location icons.** Group headings stay text. There is no
  `ImageKind` for stations or structures and no EVE image
  service surface locked for them; nothing here authorizes a
  location id fetch.
- Collapsing location groups and `show_rows` virtualization
  (section 2 rejects both for this slice; either is a view
  redesign, not an icon change), a raise of
  `ASSETS_RENDER_MAX`, sorting or grouping changes, a
  distinct blueprint-copy icon (copies share their type's icon;
  the ` (copy)` suffix stays text), icons on any other surface
  that lists types (wallet, industry, quick-picks), and a
  retry button for a `Failed` icon.

## 9. Revisit conditions

- Real holdings make the 100-row window feel wrong in practice
  (users routinely search only to page past the cap): then
  collapsing groups or virtualization earns its own design,
  with the fetch bound re-derived — section 2's honesty
  requirement (bound fetches per load, not only widgets per
  frame) still applies.
- Real cache directories show type-icon growth that makes
  no-eviction untenable for the assets union (the guard retains
  every loaded type's `Ready` image in state; only textures
  prune). Same condition as the earlier icon designs, now with
  asset-scale distinct counts.
- The image service's `icon` coverage changes for any held
  category (blueprint 400, SKIN 404 per the type-icons probes):
  a `Failed` asset icon shows the blank box beside the resolved
  name forever, exactly as fittings rows do; no retry in this
  slice.
- `AppState::assets` gains a per-character keyed store (several
  characters' holdings resident at once): the arm must then
  read only the active character's entry, and section 4's
  "character-keyed by construction" argument must be
  re-derived, not assumed.
- The inherited stuck-`Loading` wart (section 4) gets a general
  fix — for example clearing a `Loading` entry when its landing
  or drain is dropped as unknown. That changes every kind's
  landing semantics and wants its own design; this slice only
  inherits it.



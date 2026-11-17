# Item type icons — design

Base: `develop` at `e4482c0` (752 tests). Branch:
`feat/rust-type-icons`. This slice adds item type icons from the
public EVE image service (`types/{id}/icon`) through the shipped
kind-keyed image pipeline (portraits, pull request 587;
corporation and alliance logos, 591; standing entity icons,
592), on exactly one surface: the selected **saved** fitting's
detail in the Fittings view — the ship line and the item rows.
Type icons differ from every earlier kind in volume: a character
has a handful of portraits and logos, but item types number in
the hundreds per surface in the general case, so this design
locks the request-volume bound and the cache-growth story as
load-bearing decisions, not as documentation after the fact.

Standing rules for the whole slice: literal test expectations,
the user interface never shows raw ids, `[PORTRAIT]` logs carry
kind and id counts only (never a URL, a type name, pasted import
text, or an error body), small atomic commits with no
attribution, gates (`cargo fmt --check`,
`cargo clippy -- -D warnings`, `cargo test`, `cargo build`) pass
at every commit, demo mode makes zero network calls, and no
builder pushes or merges (the parent owns the branch after the
design commit).

Evidence in this document comes from bodies read in the
discovery sessions for this slice: `src/portraits.rs`,
`src/ui/portraits.rs`, `src/config.rs` lines 159-198 and
338-363, `src/app/state.rs` lines 485-492, 1102-1146,
1286-1386, and the fittings reset lines 1013, 1176, and 1233,
`src/app/shell.rs` lines 377-483, 2206-2274, and 3755-3784,
`src/ui/fittings.rs` lines 42, 152-228, 1119-1147, 2184, and
2356-2490, `src/ui/market.rs`, `src/ui/assets.rs`,
`src/ui/skills.rs`, `assets/demo/fittings.json`, the Flutter
bodies at the retirement commit `ed698d3` quoted in section 2,
and live probes of `https://images.evetech.net` quoted in
section 2. Nothing was taken from memory.

## 1. Current state (verified)

The pipeline (`src/portraits.rs`) keys every image by
`(ImageKind, id)` with `ImageKind { Character, Corporation,
Alliance, Faction }`, one semaphore (`MAX_CONCURRENT_FETCHES =
4`), a 1 MiB body cap, a 1024-pixel decode cap, cache-first disk
storage under `{app_cache_dir}/portraits/` with kind-prefixed
names, and production URLs built only by the named helpers in
`src/config.rs`. There is no type-icon URL helper and no `Type`
kind. `AppState::image_id_known` (`src/app/state.rs` lines
1286-1306) is the single definition of "this id may be fetched",
shared by `request_portrait`, the shell drain re-check
(`src/app/shell.rs` line 2247), the landing check (line 456),
and texture prune (`src/ui/portraits.rs` lines 66-76, called
from the Characters and Dashboard views). `request_portrait`
ignores ids at or below zero and unknown ids, dedupes the queue
by `(kind, id)`, and the render-path ensure helpers queue only
`NotRequested` keys — a `Failed` image never re-queues from a
view. Demo mode queues requests and the shell drains them
without spawning (`decide_portrait_start`, shell lines
377-385); that refusal is kind-agnostic.

The Fittings view (`src/ui/fittings.rs`) renders a selectable
list of saved fittings (capped at `FITTINGS_RENDER_MAX = 100`,
line 42) and, below it, the selected fitting's detail: heading,
ship name line (`ui.label(resolver.name(selected.ship_type_id))`,
line 2466), then `render_fitting_items` (lines 1119-1147), which
draws one plain `ui.label` per item row grouped into eight
sections, each section truncated with `.take(FITTINGS_RENDER_MAX)`
and a "Showing X of N items." disclosure when truncated.
`FittingItemRow` (lines 162-167) already carries `type_id: i64`
and the resolved `type_name`; `fitting_item_rows` (lines
193-228) skips items with `type_id <= 0`. Saved fittings live in
`AppState.fittings: LoadState<FittingsData>` where
`FittingsData.fittings: SectionResult<Vec<CharacterFitting>>`
(state lines 485-492) — EVE-sourced, active-character only,
reset to `Loading` on character switch (line 1013) and on
removing the active character (line 1176), and to `Empty` when
the last character goes (line 1233).

Two facts about this surface are load-bearing and easy to miss:

1. `render_fitting_items` has **two** callers: the saved detail
   (line 2477) and the **imported** fitting detail (line 2184),
   whose type ids come from user-pasted EFT or DNA text resolved
   against the bundled catalogue. Pasted text is a user-typed
   source. This slice must not fetch for it, and section 6 locks
   the shared renderer so the imported caller stays text-only.
2. Nothing in the app virtualizes rows. Every view renders
   inside one shell `ScrollArea::vertical` (shell line 3755),
   and every row the renderer builds is built every frame,
   on-screen or not. "Visible rows" in this app therefore means
   "rows the capped renderer builds", never "rows inside the
   viewport", and section 6 states the bound in those honest
   terms.

Candidate surfaces considered and rejected for this slice, with
the evidence in section 3: market selected item (one icon,
follow-up), assets rows (unbounded, `AssetRow` does not carry
`type_id`), skills catalogue (495 bundled types, no
virtualization), fittings list rows, and the imported fitting
detail.

## 2. Endpoint evidence (Flutter `ed698d3` and live probe)

Flutter's `EveTypeIcon` (`lib/core/widgets/eve_type_icon.dart`)
built `'${EveConfig.imageServerUrl}/types/$typeId/$variant?size=$normalizedSize'`
with `imageServerUrl = 'https://images.evetech.net'`, variant
defaulting to `'icon'` (`'render'` only for the ship in the
fitting editor, `'bp'`/`'bpc'` only for blueprints), sizes
normalized up to the next power of two from
`[32, 64, 128, 256, 512, 1024]`, no caching at all (raw
`Image.network`, retry on every rebuild), a spinner while
loading, and a `help_outline` glyph on error with the type id
and URL in the log. The Rust pipeline keeps only the URL form
and the power-of-two size fact; everything else is superseded
by the shipped bounded pipeline and the blank-box rule.

Live probe of the image service during discovery (observed
host-side with `curl`, never a test dependency):

| Probe | Result |
| --- | --- |
| `types/2048/icon?size=64` (module) | 200 PNG, 3,298 bytes, 64x64 RGBA |
| `types/587/icon?size=64` (ship) | 200 PNG, 6,062 bytes, 64x64 RGB |
| `types/178/icon?size=64` (charge) | 200 PNG, 6,674 bytes, 64x64 RGBA |
| `types/34/icon?size=64` (ore) | 200 PNG, 5,324 bytes |
| icon `?size=32` (7 probes) | 200 PNG, 1,482-2,153 bytes |
| `types/587/icon?size=128` | 200 PNG, 8,239 bytes |
| `types/34/icon?size=48` | 400, body `bad size` |
| `types/99999999/icon?size=32` (unknown) | 404, empty body |
| `types/683/icon?size=32` (blueprint) | 400 `bad category or variation` |
| `types/587/render?size=64` (ship) | 200 JPEG, 1,651 bytes |
| `types/2048/render` and `types/34/render` | 400 `bad category or variation` |

A sweep of one icon probe per SDE category across all 37
categories in the bundled catalogue returned 200 for 28
categories, 400 for blueprints, epic arcs, and thruster
sections, and 404 for a few legacy categories and for SKINs.
Conclusions the design locks:

- `types/{id}/icon` is the only general type endpoint. `render`
  is ship-only (400 for every non-ship probed), is JPEG with a
  different alpha story, and is excluded from this slice; a
  future ship-render slice would need its own kind and its own
  probe, not a variant flag on this one.
- The unknown-id answer for types is an honest 404, unlike the
  logos case (a 200 shared fallback). The guard in section 5 is
  still required: provenance is what bounds volume and keeps
  user-typed ids off the network, and a future service change
  must not be able to turn an unguarded request path into a
  fabricated attribution.
- Some catalogue-real types have no icon (blueprints 400, SKINs
  404). Those land as `Failed` and show the blank box beside the
  resolved name forever (no render-path retry). The design adds
  no category special-casing to avoid asking; asking once,
  bounded, and remembering the failure is the shipped pipeline's
  own behaviour.

## 3. Surface decision: the selected saved fitting's detail

**Locked first surface: the ship line and item rows of the
selected saved fitting in the Fittings view** (`src/ui/fittings.rs`
lines 2466 and 2473-2477, through `render_fitting_items`).
Nothing else gains an icon in this slice.

Justification, from the bodies in section 1:

1. It is a real row surface with a hard render bound that
   already exists. The slice's central risk is request volume
   from hundreds of distinct types; this surface proves the
   volume design (ensure only rendered rows, dedupe, semaphore)
   at realistic scale — one fitting is roughly 8-30 distinct
   types — while the shipped per-section cap bounds the worst
   case (section 6 states the exact ceiling). A one-icon
   surface would prove none of that.
2. Every id is EVE-sourced state. Ship and item type ids come
   from the loaded saved-fittings bundle, so the guard in
   section 5 falls out of `AppState` data the guard already
   lives beside. No id on this surface can be typed, searched,
   or pasted (the imported detail is explicitly excluded).
3. The row data is already shaped for it. `FittingItemRow`
   carries `type_id` and skips non-positive ids at construction;
   no struct threading, no grouping change, no new data load.
4. Flutter's heaviest type-icon investment was exactly here:
   module slots and ship in the fitting editor. The fittings
   detail is where a player reads "what is fitted", which is
   the question an item icon answers.

Rejected for this slice, each a named follow-up with its own
design if pursued:

- **Market selected item** (the smaller fallback). One icon,
  hard bound of 1, direct Flutter precedent at 64px. It is the
  natural second surface, but its guard is a different shape
  (the selected type and the capped quick-pick list are
  market-picker state, some of it derived from a name the user
  typed and EVE resolved), and as a first surface it would
  leave every volume question in this design unproven.
- **Assets rows.** Rejected on three counts: `AssetRow` drops
  `type_id` in `group_assets`, rows are unbounded (no cap, no
  virtualization, real holdings reach thousands of distinct
  types), and Flutter never shipped asset icons (an explicit
  placeholder with a TODO comment). Needs a visible-row or cap
  design first.
- **Skills catalogue.** Catalogue-bounded at 495 types and
  Flutter's cached `EveSkillIcon` precedes it, but the
  non-virtualized scroll would request every matching row on
  open. Needs a visible-window bound first.
- **Fittings list rows.** Ship icons beside each fitting name
  would add up to 100 ensures per view open for a navigation
  list the user scans by fitting name. Follow-up only.
- **Imported fitting detail.** Its ids derive from user-pasted
  text. Fetching for pasted input is a provenance decision this
  slice deliberately does not make; the detail stays text-only
  (section 6). Demo's "Use sample EFT/DNA" flows are unaffected
  either way because demo never fetches.

## 4. Kind decision and the locked key contract

**Locked: add a fifth variant, `ImageKind::Type`.** The kind
names what the image depicts — an item type — and every key,
cache file, texture, log word, and guard arm for it is its own.
Reusing any existing kind would store item bytes under a
character, corporation, alliance, or faction key, which is a
false statement about the bytes and a correctness hazard
wherever id ranges overlap. Adding the variant forces
completion of every exhaustive `match` on `ImageKind`; that
forced completion is the verification that no site was missed.
The complete production list, found by searching `ImageKind::`
over `src/` during discovery:

| Site | Type arm (locked) |
| --- | --- |
| `src/portraits.rs` `ImageKind::as_str` (lines 34-41) | `"type"` |
| `src/portraits.rs` `cache_filename` (lines 89-96) | `format!("type-{id}_{size}.png")` |
| `src/portraits.rs` `fetch_bytes`, production URL (lines 210-216) | `EveConfig::type_icon_url(id, size)` |
| `src/portraits.rs` `fetch_bytes`, test-seam URL (lines 217-242) | `format!("{}/types/{}/icon?size={}", base, id, size)` |
| `src/app/state.rs` `image_id_known` (lines 1286-1306) | section 5 |
| `src/app/state.rs` `standing_known` wanted match (lines 1312-1316) | joins the early return: `Character \| Alliance \| Type => return false` |
| `src/app/state.rs` `remove_character` `logo_known` closure (lines 1130-1145) | section 5.3 |
| `src/app/shell.rs` fetch size (lines 2263-2268) | its own arm: `ImageKind::Type => TYPE_ICON_SIZE` |
| `src/ui/portraits.rs` texture name (lines 121-126) | `format!("type-{id}")` |

New URL seam in `src/config.rs`, beside the logo helpers
(lines 168-198), exact shape:

```rust
pub fn type_icon_url(type_id: i64, size: u32) -> String {
    format!(
        "{}/types/{}/icon?size={}",
        Self::IMAGE_SERVER_URL,
        type_id,
        size
    )
}
```

Locked constants and names:

- `pub const TYPE_ICON_SIZE: u32 = 64;` in `src/portraits.rs`
  beside `LOGO_SIZE` (line 50). A separate constant with the
  same value today, deliberately not `LOGO_SIZE` itself: the
  two sizes answer different probe evidence (section 2: 64px
  icons are 3.3-6.7 KB and downscale to the 20-point render
  with HiDPI headroom, the same shape as logos at 64-to-20 and
  portraits at 256-to-32) and must be free to diverge without
  touching logo behaviour. 32 would halve the bytes and the
  headroom; 128 is unjustified for text rows. The fixed value
  is a valid power of two by construction, so no normalization
  function exists in this slice.
- Cache file literal for the locked size: `type-{id}_64.png`
  (for example `type-587_64.png`), in the existing `portraits/`
  directory. The `type-` prefix is load-bearing: a type id and
  an entity id with the same number must never share a file.
  No migration: no existing file is renamed or read under a new
  name.
- Texture name literal: `type-{id}`.
- Log word: `kind=type`, through the existing `[PORTRAIT]`
  lines (section 9).
- `pub const TYPE_ICON_PX: f32 = 20.0;` in
  `src/ui/portraits.rs` beside `DETAIL_LOGO_PX` (line 35): the
  one render size for type icons in this slice, ship line and
  item rows alike. It matches the detail-logo size so icon rows
  across views share one visual weight; it is its own constant
  so a later row-density decision does not move logos.
- Two thin view helpers in `src/ui/portraits.rs`, so the
  fittings view never spells `ImageKind` or a size:
  `ensure_type_icon_requested(state: &mut AppState, type_id: i64)`
  delegating to `ensure_logo_requested(state, ImageKind::Type, type_id)`,
  and `show_type_icon(ui, cache, state, type_id, size_px)`
  delegating to `show_logo(ui, cache, state, ImageKind::Type, type_id, size_px)`.
  The placeholder is therefore the shipped blank
  faint-background box by construction, not a second copy of
  the drawing code. `show_logo`'s doc comment gains type icons
  in its kind list; its deliberately name-free signature is why
  it is the right body to reuse (no name, no id can be
  formatted into the placeholder).

Unchanged by this slice: `MAX_IMAGE_BYTES`,
`MAX_IMAGE_DIMENSION`, the one semaphore at 4, cache-first
service behaviour including poisoned-entry drop, atomic
temp-and-rename writes, keyed landing, and the drain re-check.
The module doc comments in `src/portraits.rs` that say "all
four kinds" become "all five kinds" in the same commit that
adds the variant, the `cache_filename` doc gains its `type-`
sentence, and the `PortraitStore` growth paragraph (lines
276-282) is rewritten per section 7 — its current sentence
("bounded in practice by the user's own characters") becomes
false the moment this kind exists and must not survive.

## 5. Fetch guard: loaded saved-fittings ids only

`AppState::image_id_known` stays the single definition of
"this id may be fetched", shared by the request queue, the
shell drain re-check, the landing check, and texture prune.
This slice extends it in place with one private helper; there
is no second guard, no catalogue lookup, and no fittings-side
known-set.

### 5.1 Exact extension shape

```rust
/// Whether the active character's loaded saved fittings name
/// this item type (a fitting's ship or any fitted item).
/// EVE-sourced state only: the imported fitting, the market
/// selection, and the bundled catalogue are deliberately not
/// consulted, so nothing user-typed ever authorizes a fetch.
fn fitting_type_known(&self, id: i64) -> bool {
    self.fittings
        .as_ready()
        .and_then(|bundle| bundle.fittings.as_ref().ok())
        .is_some_and(|fittings| {
            fittings.iter().any(|fitting| {
                fitting.ship_type_id == id
                    || fitting.items.iter().any(|item| item.type_id == id)
            })
        })
}
```

`image_id_known` then reads, per kind: `Character`,
`Corporation`, `Alliance`, and `Faction` unchanged;
`Type => self.fitting_type_known(id)` and nothing else.

Consequences that must hold and are tested in section 10:

- An id named only by the bundled fitting-types catalogue (all
  25,818 rows), only by the imported fitting, only by the
  market selection or quick picks, only by assets or wallet
  state, or only by the name resolver's cache is **not** known
  and queues nothing. Catalogue membership was considered as
  the guard and rejected for three reasons: the catalogue
  lives on `MimirApp` (`src/app/shell.rs` line 124), not in the
  `AppState` the guard, drain, landing, and prune all consult,
  so it would need new plumbing through all four; membership
  does not imply an icon exists (blueprints and SKINs are
  catalogue rows whose icons 400 and 404); and it would
  authorize all 25,818 ids including ids derived from pasted
  import text, which is exactly the user-typed source the
  standing rules exclude.
- A `Ready` bundle whose fittings section is `Err` authorizes
  nothing; `Loading` and `Empty` authorize nothing.
- A saved-fitting type id authorizes the `Type` kind only: the
  same number under `Character`, `Corporation`, `Alliance`, or
  `Faction` stays exactly as known or unknown as it is today.
- Non-positive ids never queue (the existing `request_portrait`
  pre-check), even though ESI rows that carry them are already
  skipped when rows are built.

### 5.2 Character-keyed validity and prune lifetime

The guard reads the active character's saved fittings, and
inherits their ownership from the reset rules traced in
`src/app/state.rs`: a character switch sets
`self.fittings = LoadState::Loading` (line 1013), removing the
active character does the same (line 1176), and removing the
last character sets `Empty` (line 1233). From each of those
instants the previous character's fitting type ids are unknown:
an in-flight fetch lands through `apply_portrait_landing`,
re-checks the guard, and drops whole; the drain re-check skips
a queued key that stopped being known; and the next `prune`
frees the GPU textures. A same-character reselect skips the
reset, so icons survive, which is correct because the owner
did not change. Two characters whose saved fittings legitimately
fit the same module share one `(Type, id)` image, which is
correct: the image names the item type, not the character.

Prune lifetime is locked as **state-known over the whole
loaded bundle, not catalogue-static, and not selected-only**:

- Not catalogue-static: retaining every catalogue-known type's
  texture for the app's lifetime bounds GPU memory by 25,818
  possible 64x64 RGBA textures (about 16 KB each) and needs
  the catalogue inside prune, which does not have it. Static
  data about what types exist says nothing about what this
  character's session should keep uploaded.
- Not selected-only: the 591 lesson is that prune retained by
  a guard narrower than what was legitimately uploaded drops
  and re-uploads textures as the user navigates. Clicking from
  fitting A to fitting B and back would re-upload every A
  texture per round trip, and a fetch for A landing after the
  click to B would be dropped whole and refetched on return.
  The whole-bundle guard retains every type any of the active
  character's saved fittings names, so selection changes never
  thrash textures, while section 6 still bounds what may be
  *requested* to the selected fitting's rendered rows. The
  guard is a superset of the ensure set by design: retention
  is generous, requesting is stingy.

The Fittings view gains the same `cache.prune(state)` call the
Characters and Dashboard views already make at their tops
(`src/ui/characters.rs` line 32), so entering Fittings after a
character switch frees stale type textures instead of waiting
for a visit to a character surface.

### 5.3 Removal retain mirror

`remove_character` retains `portraits` and
`portrait_requests` by its own `logo_known` closure (state
lines 1130-1146) evaluated against sources captured before the
active-removal reset. Any guard source not mirrored there
loses its entries on every removal. Locked mirror: capture
before the closure, beside `standing_pairs`, the saved-fitting
type ids as a flat `Vec<i64>` (each fitting's `ship_type_id`
and every item's `type_id` from the `Ready` bundle's `Ok`
section, empty when not Ready or `Err`), and extend the
closure with `ImageKind::Type => fitting_type_ids.contains(&id)`.
Removing a non-active character then keeps the active
character's type entries and queued requests; removing the
active character retains them through the closure but they
immediately lose guard backing at the line 1176 reset, so
prune and landing finish the cleanup — the same lifecycle
detail-sourced and standings-sourced logos already have.

## 6. Volume bounds: ensure only what the capped renderer draws

This is the section that makes hundreds of distinct types
safe. The rules, all locked:

1. **Exactly two ensure sites**, both inside the selected
   saved fitting's detail in `src/ui/fittings.rs`: the ship
   line (once, for `selected.ship_type_id` when it is
   positive), and the item-row loop inside
   `render_fitting_items`, inside the existing
   `in_section.iter().take(FITTINGS_RENDER_MAX)` iterator —
   never on the full `in_section` or the full `item_rows`.
   Ensure set equals rendered set by construction: a row the
   100-per-section cap truncates away is never built, never
   ensured, and never fetched. Builders must not add a
   separate "ensure all rows" pre-pass; that is the one change
   that would silently unbound this surface.
2. **Hard ceiling per detail view**: 1 ship plus 8 sections
   times `FITTINGS_RENDER_MAX` (100) rows is at most 801
   rendered icon slots, hence at most 801 distinct ensure
   calls, and — after the dedupe in rule 3 — at most as many
   fetches as there are distinct types among them. That
   ceiling is a hostile-data bound (800 fitted items in one
   saved fitting); realistic fittings render 12-30 distinct
   types, and the demo fixtures render exactly 12 distinct
   (character 90000001, fitting 1: ship 587 plus items 2048,
   2049, 1225, 2050 twice, 1535, 28270, 2456, 2457, 34, 636,
   35 — 11 distinct items) and 6 (character 90000002: ship 597
   plus 2048, 2050, 1225, 2456, 36). The design states both
   numbers because claiming only the realistic one would be
   the dishonest version of this bound.
3. **Dedupe is the shipped pipeline's, unchanged**:
   `ensure_type_icon_requested` queues only `NotRequested`
   keys, `request_portrait` moves a key to `Loading` and
   dedupes the queue by `(kind, id)`, and the one semaphore
   bounds flight at 4 across all kinds together. Repeated
   rows for one type (two fitted copies of one module, the
   same type in two sections) queue one fetch. Re-rendering
   at frame rate queues nothing further, because every key
   has left `NotRequested`. Type fetches compete for the same
   4 permits as portraits and logos; that sharing is
   deliberate and unchanged — a second semaphore would double
   the app-wide bound.
4. **No viewport claim.** The shell builds every capped row
   every frame, including rows scrolled off the bottom.
   Offscreen-but-rendered rows within the cap therefore do
   ensure. The bound that makes this acceptable is rule 2's
   ceiling, not visibility. True viewport virtualization
   (`ScrollArea::show_rows` or equivalent) is a named future
   design for the assets and skills surfaces; this slice does
   not build it and does not pretend to.
5. **Failures are remembered.** A `Failed` icon (blueprint
   400, SKIN 404, network error) never re-queues from the
   render path, and this slice adds no retry button — N retry
   buttons for decorative row icons would be noise, the
   resolved name beside the blank box carries the meaning,
   and a disk-cached success needs no retry. The earlier
   explicit-button retry pattern remains available to a
   future slice if failure becomes visible in practice.
6. **No other row anywhere ensures.** The fittings list, the
   imported fitting detail, the loaded-charges block in the
   imported detail, market, assets, skills, and every other
   view are untouched. The imported detail shares
   `render_fitting_items`, so the gating is explicit in the
   signature, locked: `render_fitting_items` gains a final
   parameter `type_icons: Option<(&mut AppState, &mut PortraitImageCache)>`.
   The saved caller passes `Some((state, cache))`; the
   imported caller passes `None` and gets byte-identical
   `ui.label` rows with no icon widget and no ensure. Passing
   anything but `None` from the imported caller is a design
   violation a reviewer can see in one line.

## 7. Cache growth, stated honestly

The disk store never evicts (shipped behaviour: entries for
removed characters are left deliberately as inert,
kind-and-id-keyed files reused if the character returns). That
was easy to defend when growth tracked the user's characters.
With type icons the honest statement, which replaces the
current `PortraitStore` doc sentence in the same commit that
adds the kind, is:

- One disk entry per distinct type ever fetched: about 5 KB
  average at size 64 (probe range 3.3-6.7 KB, section 2). 100
  viewed types are about 0.5 MB; 1,000 are about 5 MB.
- Lifetime growth is bounded by distinct guard-backed types in
  saved fittings the user has actually selected, across all
  characters ever added — because sections 5 and 6 make every
  other id unrequestable. The catalogue-wide flood (25,818
  types, roughly 129 MB) is unreachable in this design, and
  that unreachability rests entirely on the guard; any future
  surface that widens the guard reopens this arithmetic and
  must restate it.
- GPU textures are about 16 KB per uploaded type (64x64
  RGBA), retained while the active character's loaded bundle
  names the type (section 5.2), freed by prune on switch or
  removal. Decoded `Ready` images in the state map follow the
  removal retain (section 5.3) and the last-character clear,
  the same lifetime class as every earlier kind.
- **No eviction policy is added in this slice.** No size cap
  on the directory, no least-recently-used sweep, no age
  limit, no staleness refresh: the stated bound (about 5 KB
  per selected-fitting type, realistically a few megabytes
  over years) does not justify the machinery, and inventing
  one without a witnessed problem would be scope this slice
  does not have. Revisit trigger: a future surface whose
  guard authorizes catalogue-scale id sets, or observed cache
  directories in the tens of megabytes in practice.

## 8. Rendering: layout, placeholder, wording

Surfaces in this slice (complete list): the ship line and the
item rows of the selected saved fitting's detail. Locked
layout, mirroring the established `show_logo` plus label
pattern in `src/ui/characters.rs`:

- Ship line: when `selected.ship_type_id > 0`, one
  `ui.horizontal` containing
  `show_type_icon(ui, cache, state, selected.ship_type_id, TYPE_ICON_PX)`
  then `ui.label(resolver.name(selected.ship_type_id))` — the
  same resolved text as today. The ensure for the ship id
  runs in `show` before this layout (the renderer holds only
  an immutable snapshot clone there, so ensures belong to the
  state-owning caller, as with the standings ensure loop in
  the Characters view). When the ship id is not positive, the
  plain label renders exactly as today with no icon widget
  and no box: a blank box means "an image belongs here and is
  pending or failed", and no image will ever belong to a
  non-positive id. The ship uses the `icon` endpoint like
  every other type in this slice (probe: 200 PNG); the
  ship-only `render` variant is excluded (section 2).
- Item rows, only on the `Some(...)` path of
  `render_fitting_items`: for each rendered row the loop
  first calls `ensure_type_icon_requested(state, row.type_id)`
  (section 6 rule 1 — the ensure lives inside the capped
  iterator, beside the row it serves), and the row becomes
  one `ui.horizontal` containing `show_type_icon(...,
  row.type_id, TYPE_ICON_PX)` then the existing label text
  unchanged (`type_name` alone for a slot row of quantity 1,
  `"{type_name} x{quantity}"` otherwise). Section headings,
  the "Showing X of N items." disclosure, section order, and
  the empty-fitting sentence are unchanged.
- Placeholder for `NotRequested`, `Loading`, and `Failed`:
  the blank faint-background box from `show_logo`, via
  `show_type_icon` (section 4). No initial, no glyph, no
  spinner, no type id, no fallback artwork. (Flutter's
  spinner and `help_outline` glyph are on the do-not-copy
  list: a glyph inside the slot reads as the item's mark.)
- Wording: this slice adds no user-visible string. Resolved
  names keep coming from the existing name paths; no format
  string in any changed view may include a raw type id, and
  the existing unresolved-name behaviour is untouched.
- Signature threading, locked: `ui::fittings::show` gains
  `cache: &mut PortraitImageCache` as a new final parameter,
  calls `cache.prune(state)` at its top (section 5.2), passes
  `Some((state, cache))`-equivalent reborrows into the saved
  `render_fitting_items` call and `None` into the imported
  call (the imported panel renders from `fittings_import_panel`,
  which needs no signature change beyond what the `None` call
  requires), and the shell's `View::Fittings` dispatch (shell
  lines 3775-3781) passes `&mut self.portrait_textures`. No
  other view signature changes. If the borrow shape of the
  snapshot-cloning `show` body makes the tuple awkward, the
  fallback locked shape is two parameters,
  `icon_state: Option<&mut AppState>` and
  `icon_cache: Option<&mut PortraitImageCache>`, asserted in
  a debug build to be both-present or both-absent — the tuple
  is preferred because it makes the mismatch unrepresentable.

## 9. Demo and logging

Demo behaviour is unchanged and stays zero-network. The
ensures only queue; `decide_portrait_start` refuses with
`Demo` and the drain spawns nothing, for every kind alike.
Demo data is untouched (`assets/demo/fittings.json`,
section 6 rule 2), so in demo the selected fitting's ship
line and item rows show blank boxes left of the resolved
names — placeholder-path evidence only, never evidence about
the fetched path, per the established demo-screenshot rule.
Two demo fixture ids (636, 1535) are fictional against the
live service (404 on probe); that is a fixture caveat with no
demo impact, since demo never asks, and no live impact, since
live ids come from EVE's own fittings response. The imported
sample-EFT and sample-DNA demo flows render text-only rows
exactly as today (the `None` path).

Logging: **no new log lines.** Type traffic flows through the
existing `[PORTRAIT]` lines with `kind=type` (request, drain
count, fetch started/skipped, fetched byte count, cache
hit/write, decode size, texture uploaded/replaced, prune
remaining count, landing failure with the fixed error
words), because every one formats `kind.as_str()` and the
plain integer id. The per-frame render path stays log-free
(ensures log only through `request_portrait`'s
once-per-transition lines). Nothing in this slice logs a URL,
a type name, imported text, or an error body. Builder check:
searching the diff for added `tracing::` lines outside
comments finds none.

## 10. Test plan (literal expectations throughout)

The shared state fixture for the guard tables (Builder A,
`src/app/state.rs`): characters rows for ids 1 (active) and 2
using the existing test row helpers (corporation 1000166, so
no fixture id below is known by row under any entity kind),
and `fittings` Ready with `Ok(vec![fitting_a, fitting_b])`
where fitting A has `ship_type_id` 587 and items with type
ids 2048 and 34, and fitting B has `ship_type_id` 597 and one
item with type id 178. All assertions use these literal ids.

### `src/config.rs` (Builder A)

- `type_icon_url(587, 64)` equals the literal
  `"https://images.evetech.net/types/587/icon?size=64"`, and
  `type_icon_url(2048, 64)` equals
  `"https://images.evetech.net/types/2048/icon?size=64"`,
  beside the existing URL literal tests.

### `src/portraits.rs` (Builder A)

- `ImageKind::Type.as_str()` equals `"type"`.
- `cache_filename(ImageKind::Type, 587, 64)` equals
  `"type-587_64.png"`; the same-number distinctness test
  extends to all five kinds at id 1000166 (five
  pairwise-distinct names, existing assertions unchanged).
- Type fetch through the mock server: serving a generated PNG
  for `(Type, 2048, TYPE_ICON_SIZE)` decodes successfully and
  the captured request line contains the literal
  `"/types/2048/icon?size=64"` — proving the test-seam path;
  the production path is proven by the `type_icon_url`
  literal above, the same split the logo tests use.
- Cache isolation: bytes written under `(Corporation, 587)`
  are not read back under `(Type, 587)` (distinct files), and
  bytes written under `(Type, 587)` read back under `(Type,
  587)` only.
- A mock 404 for `(Type, 99999999)` maps to
  `PortraitError::Status(404)`, with the test comment stating
  it documents only the status mapping (the live probe, not a
  test, is the evidence the real service 404s unknown types).

### `src/app/state.rs` (Builder A)

- Guard table on the shared fixture:
  `image_id_known(Type, 587)`, `(Type, 2048)`, `(Type, 34)`,
  `(Type, 597)`, and `(Type, 178)` are all true;
  `image_id_known(Type, 99999999)` (unknown everywhere),
  `(Type, 3300)` (a catalogue-real skill type named by no
  saved fitting — the catalogue-rejection row), and `(Type,
  500001)` (a faction id) are false. Cross-kind: every one of
  587, 2048, 34, 597, 178 is false under `Character`,
  `Corporation`, `Alliance`, and `Faction` on this fixture.
- Queueing: `request_portrait(Type, 2048)` queues exactly
  `vec![(ImageKind::Type, 2048)]` and a second call queues
  nothing more; `request_portrait(Type, 99999999)` and
  `request_portrait(Type, 3300)` queue nothing and create no
  `portraits` entry (the unknown-type rejection row);
  `request_portrait(Type, 0)` and `(Type, -1)` queue nothing.
- Imported-only state authorizes nothing: `fittings` stays
  `Loading` and `fittings_imported` is `Some(...)` naming
  type 2048 (constructed with the literal `ImportedFitting`
  shape the existing state tests use near line 2360);
  `image_id_known(Type, 2048)` is false and nothing queues.
  This is the user-pasted-source rejection row; no redesign
  of import state is in scope to make it passable.
- Section `Err` (a `needs_reauthorize` section error) makes
  every assertion in the guard table false; `fittings`
  `Loading` and `Empty` likewise.
- Switch: on the fixture state, after
  `set_active_character(2)`, `image_id_known(Type, 587)` is
  false (the line 1013 reset) — character A's fittings never
  fetch under character B. Same-character reselect keeps it
  true.
- Removal: with a `Ready` entry seeded for `(Type, 2048)` and
  `(Type, 2048)` also present in `portrait_requests`,
  `remove_character(2)` (non-active) retains both the entry
  and the queued request (the section 5.3 mirror);
  `remove_character(1)` (active) followed by the resulting
  state has `image_id_known(Type, 2048)` false. The existing
  all-kinds array tests (near lines 2803, 2908, 2949, 2967)
  gain `ImageKind::Type` so the remove-clears-everything and
  unknown-id cases cover the new kind.

### `src/app/shell.rs` (Builder B)

- Landing under the fittings guard: on the shared fixture
  state, `apply_portrait_landing(state, ImageKind::Type,
  2048, Ok(img))` returns true and `portrait_state(Type,
  2048)` is `Ready`; after `set_active_character(2)` a second
  landing for `(Type, 2048)` returns false and writes nothing
  (the mid-fetch switch property end to end).
- `apply_portrait_landing(state, ImageKind::Corporation,
  2048, Ok(img))` on the fixture state returns false
  (cross-kind rejection: a fitting type id is not a
  corporation key).
- The shell test arrays that enumerate every kind (found by
  searching `ImageKind::Character,` in the test module, near
  lines 4446-4678) gain `ImageKind::Type` wherever the test
  claims all-kinds coverage; where an array is
  character-fixture-specific its existing scope stands and
  Builder B does not widen it silently.

### `src/ui/portraits.rs` (Builder B)

- `ensure_type_icon_requested` mirrors the logo ensure table
  on the shared fixture: `NotRequested` 2048 queues exactly
  `vec![(ImageKind::Type, 2048)]`; `Loading`, `Ready`, and
  `Failed` entries for other known ids are left alone
  (`Failed` never re-queues); unknown 99999999 queues nothing
  and creates no entry.
- Texture keying: `Ready` images for `(Character, 587)` (on a
  state whose character row has id 587) and `(Type, 587)`
  upload as two textures (cache length 2, distinct handles).
- Prune lifetime (the section 5.2 no-thrash property):
  upload `(Type, 34)` — a type named only by fitting A —
  against the fixture state; change only
  `fittings_selected_fitting_id` to fitting B, prune, and the
  texture is still held with the same handle id (selection
  change cannot drop it). Prune against a state with
  `fittings` `Loading` empties the cache.
- `show_type_icon` headless (`egui::Context::run`, the
  `show_portrait_runs_headless` precedent): a `Ready`
  `(Type, 587)` uploads one texture, a non-ready `(Type,
  2048)` draws the box and uploads none.

### `src/ui/fittings.rs` (Builder B)

Headless tests calling the private `render_fitting_items`
directly (first egui-context tests in this module, same
`ctx.run` shape as `src/ui/portraits.rs`), on the shared
fixture state:

- Rendered-rows-only ensure: rows built from a fitting with
  Low 2048, Low 2048 again (a second fitted copy), and Cargo
  34 render through `Some(...)`; after one run
  `portrait_requests` equals exactly
  `vec![(ImageKind::Type, 2048), (ImageKind::Type, 34)]`
  (section order, duplicates deduped), and a second run adds
  nothing.
- Imported path: the same rows through `None` leave
  `portrait_requests` empty and the texture cache empty after
  a run — the user-pasted detail never ensures.
- Cap bound: one section with 101 distinct guard-known item
  ids (a fixture fitting naming literal ids 1001 through
  1101, rows via `fitting_item_rows`) renders through
  `Some(...)` and queues exactly 100 requests — the
  truncated row never ensures (section 6 rule 1, proven at
  the one site that could break it).

No test may reach the network; the section 2 probes were
discovery evidence, not test dependencies. The demo seed
tests need no change: demo data and seeding are untouched.

## 11. Integrator checklist

- `src/main.rs` and `src/lib.rs`: no change. `PortraitService`
  keeps its constructor and `image` signature; `Backends`
  gains no field. A builder who needs wiring there has
  diverged and stops.
- `Cargo.toml`, `assets/demo/`, `assets/sde/`: no change. No
  new dependency, no new catalogue, no fixture edit.
- This file and the earlier pipeline designs
  (`docs/portraits-design.md`, `docs/logos-design.md`,
  `docs/standing-icons-design.md`): builders do not edit
  them; design amendments go back to the parent.
- The complete cross-builder contract is the set of names in
  sections 4-6: `ImageKind::Type`, `TYPE_ICON_SIZE`,
  `EveConfig::type_icon_url`, the private `fitting_type_known`
  helper and the `fitting_type_ids` capture (Builder A only),
  `TYPE_ICON_PX`, `ensure_type_icon_requested`,
  `show_type_icon`, the `type_icons` parameter of
  `render_fitting_items`, and the `cache` parameter of
  `ui::fittings::show`. Neither builder invents a name not
  written here, and no builder adds a `tracing::` line
  (section 9) or a user-visible string (section 8).
- Build order: Builder A's variant commit lands first (its
  exhaustive-match errors then name exactly Builder B's
  sites). Each builder's commits are small and atomic per
  file or per seam, gates green at each one on the combined
  branch state they were made against.
- Gates at every commit: `cargo fmt --check`,
  `cargo clippy -- -D warnings`, `cargo test`,
  `cargo build`. Test count grows from 752 by the section 10
  additions; no existing test is deleted or weakened — the
  all-kinds array extensions only add a case.
- Manual demo check after integration (parent or
  integrator): demo mode, Fittings view, both demo
  characters — the ship line and every item row show a blank
  box left of the resolved name (13 boxes for the
  preselected fitting of character 90000001 — ship plus 12
  item rows including the duplicated module, over 12
  distinct queued types; 6 boxes and 6 distinct for
  90000002); the
  fittings list rows stay text-only; "Use sample EFT" then
  "Import" shows the imported detail text-only with no
  boxes; the log shows the demo-suppressed drain line with
  a `kind=type` queue count and no fetch-started line. This
  proves the placeholder path only; the fetched path rests
  on the section 10 tests until a live check is reported
  separately, and no demo screenshot may be described as
  proving a fetched icon.

## 12. Builder split, zero file overlap

- Builder A (pipeline and guard): `src/config.rs`,
  `src/portraits.rs`, `src/app/state.rs`. Owns section 4's
  URL seam, variant, cache naming, and `TYPE_ICON_SIZE`,
  section 5 entire, section 7's store doc rewrite, and its
  section 10 tests.
- Builder B (shell wiring and rendering): `src/app/shell.rs`
  (the `Type => TYPE_ICON_SIZE` arm, the `View::Fittings`
  cache argument, landing tests), `src/ui/portraits.rs`
  (texture name arm, `TYPE_ICON_PX`, the two helper
  delegations, its tests), `src/ui/fittings.rs` (the `cache`
  parameter, prune call, ship ensure and layout, the
  `type_icons` gating, its tests). Owns sections 6 and 8's
  code and its section 10 tests.

No file appears in both lists. `src/app/shell.rs` sits with
Builder B, unlike the standing-icons split, because this
slice has two shell edits of different kinds — the fetch-size
arm (pipeline-facing) and the Fittings view-call argument
(render-facing) — and one file must have one owner. The
exhaustive-match errors from adding the variant land one per
file above, so each builder's compile errors stay inside
their own files; a compiler error pointing at the other
builder's file is handed across, never edited across.

## 13. Exclusions (each is a decision, not an oversight)

- Renders (`types/{id}/render`), blueprint variants (`bp`,
  `bpc`), and every other image-service variant (section 2).
- Market selected-item icon, assets row icons, skills
  catalogue icons, fittings list-row icons, imported fitting
  icons, wallet, industry, killmail, and every other surface
  (section 3). Each is a follow-up under its own design; the
  guard is not quietly widened for any of them here.
- A catalogue-membership guard, a name-resolver guard, and
  any second known-set beside `image_id_known` (section 5.1).
- Cache eviction, directory size caps, staleness refresh, or
  any lifetime policy beyond the stated bound in section 7.
- Viewport virtualization and any "visible rows only" claim
  stronger than section 6 rule 4's honest version.
- Per-icon retry buttons and any other new user-visible
  string; category special-casing to pre-empt blueprint or
  SKIN failures; a size-normalization helper (the locked
  fixed size needs none).
- Flutter do-not-copy list: uncached per-rebuild fetches,
  in-box spinners, `help_outline` glyphs, full-URL and
  type-id error logging, unnormalized sizes, and `render`
  for the ship line.
- New OAuth scope, new source file, new cache directory, and
  any change to fittings fetching, import parsing, ordering,
  caps, or wording.
- No push and no merge from this workflow; the parent owns
  the branch after the design commit.




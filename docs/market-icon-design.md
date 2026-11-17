# Selected-item type icon in the Market view — design

Base: `develop` at `edc009b` (771 tests, post type-icons merge #593).
Branch: `feat/rust-market-icon`. Slice goal: show the selected
item's type icon in the Market view header — the follow-up named
by `docs/type-icons-design.md` section 3 (smallest fallback surface,
hard bound of 1, Flutter precedent at a 64px fetch, guard shape the
open question of this design).

Standing rules for the whole slice: verify from bodies read this
session, literal test expectations, the user interface never shows
raw ids, `[PORTRAIT]` logs carry kind and id only (never a URL, a
URL carries no name, no pasted text, no error body), small atomic
commits `type(scope): description` with no attribution, no push or
merge (the parent owns the branch after the design commit), gates
(`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`) pass at every commit. Demo makes zero
network calls.

Evidence in this document comes from bodies read during this
discovery session on the `edc009b` tree: `src/app/state.rs` (the
`image_id_known` guard at lines 1304-1342, `fitting_type_known` at
1332-1342, `request_portrait` at 1376-1413, the character-switch reset
at 921-1053, `remove_character` and its retain closure at 1080-1273,
the market selection setter at 864-886, test fixtures at 1882-2007
and 3100-3289), `src/app/shell.rs` (`apply_portrait_landing` at
452-485, the drain at 2211-2278 with its re-check at 2249-2256 and
the fetch-size match at 2265-2273, the responsive-shell render
dispatch around line 3775, `decide_portrait_start` at 379-387, the
market identity check at 182-190, `apply_market_lookup_candidates`
at 2182-2203), `src/ui/portraits.rs` (the prune retain at 72-82,
texture upload at 101-156 with `type-{id}` naming at 132, the ensure
and show delegations at 189-197 and 272-284, the type-icon tests at
880-932), `src/portraits.rs` (`TYPE_ICON_SIZE = 64` at 60, cache
growth at 293-314), `src/config.rs:201-208` (`type_icon_url`),
`src/ui/market.rs` (`show` at 557-603, `quick_pick_types` at
223-249, the selection call sites at 306-309 and 319-324,
`submit_lookup` at 253-263), `src/ui/fittings.rs` (`render_fitting_items`
at 1126-1174, the saved-detail ship line at 2496-2505, the
`cache.prune` at 2392), `src/ui/characters.rs:32` and
`src/ui/dashboard.rs:27` (the prune-at-top precedent), and
`src/demo/data.rs:1154-1183` (the demo market fixture).

Nothing was taken from memory; every load-bearing claim below
carries a verified body citation.

## 1. Current state (verified)

The shipped type-icon pipeline (type-icons merge at `edc009b`)
already implements everything a market header icon needs except
authorization and wiring:

- `ImageKind::Type` exists with cache file `type-{id}_{size}.png`
  (`src/portraits.rs:100-107`), `TYPE_ICON_SIZE = 64` as its own
  constant (`src/portraits.rs:54-60`), `EveConfig::type_icon_url`
  building `https://images.evetech.net/types/{id}/icon?size=64`
  (`src/config.rs:201-208`), texture name `type-{id}`
  (`src/ui/portraits.rs:132`), and the fetch-size arm
  `ImageKind::Type => TYPE_ICON_SIZE` in the shell drain
  (`src/app/shell.rs:2270`).
- The single fetch guard `AppState::image_id_known`
  (`src/app/state.rs:1304-1324`) admits `Type` only through
  `fitting_type_known` (`src/app/state.rs:1323`), which reads the
  active character's loaded saved-fittings bundle: ship and item
  type ids from a `Ready` `Ok` section; `Loading`, `Empty`, and
  `Err` authorize nothing (`src/app/state.rs:1332-1342`).
- Four sites share that guard: `request_portrait`
  (`src/app/state.rs:1376-1413`, ignores non-positive and unknown
  ids, dedupes the queue by `(kind, id)`), the shell drain
  re-check (`src/app/shell.rs:2249-2256`), the landing check in
  `apply_portrait_landing` (`src/app/shell.rs:458-460`), and
  texture prune (`src/ui/portraits.rs:72-82`, retains by
  `image_id_known`).
- Character ownership comes from the reset rules: a character
  switch sets `fittings = Loading`
  (`src/app/state.rs:1013`), removing the active character does the
  same (`src/app/state.rs:1193`), removing the last character sets
  `Empty` (`src/app/state.rs:1250`). `switching_character_revokes_fitting_type_knowledge`
  and `err_or_loading_fittings_authorize_nothing` pin all three.
- The removal retain (`src/app/state.rs:1129-1165`) captures
  `fitting_type_ids` before the active-removal reset and the closure
  retains `Type` entries only for those ids, mirroring the
  standings source captured beside it; `remove_character`'s
  `portraits` and `portrait_requests` are cleared only when no
  characters remain (`src/app/state.rs:1234-1237`).
- The market view (`src/ui/market.rs:557-603`) today renders the
  picker, then resolves the selected type's heading via the cached
  resolver name with fallback to the captured selection name and
  finally `"Unknown Item"`, then region, refresh, and the bundle
  sections. It receives no texture cache today: the shell dispatch
  is `View::Market => ui::market::show(ui, &mut self.state,
  &self.resolver)` (`src/app/shell.rs` render dispatch around line
  3775), with no `PortraitImageCache` argument and no `prune` call,
  unlike Characters (`src/ui/characters.rs:32`), Dashboard
  (`src/ui/dashboard.rs:27`), and Fittings
  (`src/ui/fittings.rs:2392`), which all call `cache.prune(state)`
  at their tops.

Two facts about the market selection are load-bearing:

1. **Provenance is ESI-sourced only at the call sites, never
   user-typed.** `set_market_selection`
   (`src/app/state.rs:868-886`) accepts an `i64` and a name (a
   blank or numeric name becomes `"Unknown Item"`), but nothing in
   the market view calls it with search text. The search box only
   calls `submit_lookup` (`src/ui/market.rs:253-263`), which sets
   `market_lookup_requested` and clears candidates; the shell then
   applies ESI answers: zero candidates shows the fixed not-found
   line, a single match auto-selects its id and name
   (`src/app/shell.rs:2189-2193`), several become clickable
   `market_candidates` (`src/app/shell.rs:2194-2201`), and the
   view's `show_picker` calls `set_market_selection(candidate.id,
   word)` (`src/ui/market.rs:306-309`) or `set_market_selection(
   *type_id, label.clone())` for a quick-pick
   (`src/ui/market.rs:319-324`). Quick-picks come from the loaded
   assets and wallet transactions — also EVE-sourced state —
   deduplicated, named, sorted, and capped at `QUICK_PICK_MAX = 12`
   (`src/ui/market.rs:21`, `quick_pick_types` at 223-249). The
   selection is therefore exactly the single id ESI either
   resolved from a name lookup or listed among what the character
   holds.
2. **The selection survives a character switch and removal; the
   bundle does not.** `set_active_character`
   (`src/app/state.rs:979-986`) resets `market` to `Loading` when a
   type is selected, clears candidates and the lookup message, and
   bumps `market_generation`, but keeps `market_selected_type_id`,
   region, and search text. The same three hold in
   `remove_character` for the active character (lines 1179-1184),
   and even the last-character branch sets `market = Empty`
   (line 1243) without clearing the selection. The market identity
   check (`src/app/shell.rs:185-190`) requires generation,
   selected type, region, and active character to all match, so a
   late market landing can never display under a switched or
   removed character — but the identity check governs the market
   bundle, not the image key.

The demo fixture installs both pieces from bundled data:
`apply_character` sets `market_selected_type_id` and name from
`fixture.selected_type_id` (`src/demo/data.rs:1157-1158`) and the
fittings bundle `Ready` (`src/demo/data.rs:1260-1262`). In demo
mode the shell drain suppresses every spawn kind-agnostically
(`src/app/shell.rs:2217-2223`), so demo selection never fetches
regardless of guard content; the icon renders the blank box.

## 2. The guard question: which ids authorize a Type fetch

Three shapes were considered; this section locks one on evidence.

**Option A (fittings oracle only).** Leave `image_id_known`'s
`Type` arm as `fitting_type_known(id)` and unchanged. A market
selection of X where X is not in any saved fitting authorizes
nothing: `request_portrait` logs `unknown kind=type` and queues
nothing. The market icon then fetches only when the same type id
happens to be fitted, even if the user never opens Fittings and
the fittings scope is never granted. That is not a market
selection guard at all; it makes the Market surface depend on the
content of an unrelated feature. It also fails the slice goal
("show the selected item's type icon") because the icon would be a
blank box for every item the character does not also fit. It
clears prune and landing trivially because nothing is ever queued,
but only by refusing to answer the question. Rejected.

**Option C (any candidate or quick-pick id).** Admit every type
in the current candidate list or the capped quick-pick list.
This answers the bounding question ("should any market-picker
input authorize any fetch?") as "yes, all of them" and authorizes
types the user has not selected: on a multi-match lookup, every ESI
candidate becomes fetchable (potentially a page of ids), and on
every frame the quick-pick list makes every one of up to 12
holdings fetchable. Volume multiplies by the picker list size for
no user benefit (the user asked to see the one icon beside the
selected item), it needs new guard plumbing over `market_candidates`
and `quick_pick_types` (a derived view computation, not `AppState`
state the four guard sites consult), and quick-picks change as
assets and wallet land, so the authorized set moves without a
selection event. Rejected.

**Option B (selection-sourced; the locked shape).** `Type` stays
known exactly when `fitting_type_known` holds (unchanged) **or**
the id is the selected market type (`market_selected_type_id ==
Some(id)`). Concretely, in `image_id_known` the `Type` arm becomes

```rust
ImageKind::Type => {
    self.fitting_type_known(id)
        || self.market_selected_type_id == Some(id)
}
```

keeping `fitting_type_known` itself unmodified so its name and
contract stay true (loaded saved fittings only, imported fitting
and catalogue deliberately not consulted). Nothing else changes in
the guard body: the doc comment on `image_id_known` gains one
clause ("or the selected market type for `Type`").

Why it is honest. The only admitted market id is the single
selected id, whose provenance section 1 establishes as ESI-sourced
(candidate ids from the universe/names lookup, quick-pick ids from
loaded assets or wallet holdings) and never user-typed: search text
never becomes a selected id. The guard admits at most one
market-sourced id at a time, so the volume bound for this surface
is 1: at most one market-sourced fetch per selection change, and
zero while the selection is stable.

What earlier designs considered and rejected, for the record.
The type-icons design considered the bundled catalogue (25,818
rows) and rejected it: the catalogue lives on `MimirApp`, not
`AppState`, the four guard sites cannot see it without new plumbing,
and membership does not imply an icon exists (blueprints 400,
SKINs 404 per section 2 probes). Option B introduces no catalogue
plumbing on either side; the selection is `AppState` state the four
sites already consult. The same earlier rejection disposes of any
"market candidates" or "quick picks" reading of Option C: it was
rejected for fittings volume, and it is doubly rejected for a
one-icon surface where the bound multiplies with no benefit.

## 3. Character-keyed validity on switch, and prune

The fittings arm is character-keyed by construction: switching
resets the bundle to `Loading`, so it authorizes nothing until the
new character's fittings land. The selection arm is deliberately
**not** character-keyed, because `market_selected_type_id` is
selection state, not character-owned data (section 1 point 2): the
switch keeps it, the removal keeps it, and public market data itself
is character-independent (public sections force
`needs_reauthorize = false` and need no scope at all). The image
also names the item type, not the character — the type-icons
design establishes that two characters sharing one module share one
`(Type, id)` image. So the icons survive a character switch and
are shared across characters; the market identity check keeps the
bundle honest, but it does not revoke image knowledge. The
consequence is stated plainly so a future reader does not "fix" it:
with zero characters, a selected type keeps its texture retained
(one texture, about 16 KB) until the selection changes. That is
harmless and is pruned when the selection moves.

Prune is the superset that prevents per-frame re-upload and
late-landing thrash (the standing-icons lesson): `image_id_known`
is the union of both sources, and `prune` retains by that union
(`src/ui/portraits.rs:74-75`). Concretely:

- While X is selected, `prune` retains both fitting-known types
  and X. Switching the fittings selection (A to B and back) never
  drops X, and switching the market selection (X to Y) drops X on
  the next prune while retaining any fitting-known types.
- Landing after deselect drops whole: `apply_portrait_landing`
  re-checks at apply time (`src/app/shell.rs:458-460`), and a
  result for the no-longer-selected type lands as unknown and
  returns `false`, writing nothing. Prune likewise drops only
  the GPU texture (`src/ui/portraits.rs:72-82` retains the
  texture map, never `AppState::portraits`), so a `Ready` image
  already in state survives a deselect: reselecting re-uploads
  that same image exactly once (the `Arc::ptr_eq` path in
  `texture`, `src/ui/portraits.rs:114-120`) with no refetch.
  The one inherited wart is the reverse order — deselect while
  a fetch is still `Loading`, then the dropped landing leaves
  the key `Loading`, and the render-path ensure queues only
  `NotRequested` keys (`src/ui/portraits.rs:183-187`), so that
  type shows the blank box until the entry is dropped some
  other way. That is the shipped semantics for every kind (the
  fittings switch has it today); this slice does not change
  it, and section 9 records the revisit trigger.
- The drain re-check (`src/app/shell.rs:2249-2256`) skips a queued
  key that stopped being known (character removed or switched from
  a fitting-derived key, or deselected from a market-derived key).
- Retention is generous (union), requesting is stingy (one market
  ensure at the header, section 5). That is the deliberate
  591-lesson split.

Removal retain must mirror both sources or the market icon drops
on every `remove_character` even for a non-active removal. The
current closure (`src/app/state.rs:1146-1162`) retains `Type` by
`fitting_type_ids` captured pre-reset. The locked seam: capture
the selected market type id beside it before the reset (for example
`let market_type_id = self.market_selected_type_id;`) and extend
the `Type` arm to `fitting_type_ids.contains(&id) ||
market_type_id == Some(id)`. Removing the active character then
retains the icon through the closure but it immediately loses the
fittings-arm backing at the lines-1192-1194 reset; the selection
arm keeps it backed (the selection survives), so prune and landing
finish the cleanup for former-fitting types exactly as they do
today, and the market icon persists with the selection as designed.

## 4. Trace: select X, request, switch mid-fetch, land/prune/render

The hard case: X is not in any loaded saved fitting, so only the
selection arm can authorize it.

1. **Select X.** The view calls `set_market_selection(X, name)`
   (`src/app/state.rs:868-886`): `market_selected_type_id =
   Some(X)`, name sanitized, candidates cleared, generation bumps,
   `market_fetch_requested = true`, bundle to `Loading` when X
   differs. The next market frame's ensure (section 5) calls
   `ensure_type_icon_requested(state, X)`, which calls
   `request_portrait(Type, X)`. The guard now returns true via the
   selection arm. `(Type, X)` is `NotRequested`, so it moves to
   `Loading` and one queue entry is pushed (`request_portrait`
   lines 1401-1411). `Ready`/`Loading` would no-op; a second ensure
   in the same or later frames queues nothing because the key has
   left `NotRequested`.
2. **Switch character mid-fetch** (the fetch is in flight under
   the semaphore in `PortraitService::image`,
   `src/portraits.rs:426-481`). `set_active_character` (lines
   921-1057) resets `fittings` to `Loading` (line 1013), `market`
   to `Loading` (line 981), and bumps `market_generation` (line
   985), but keeps `market_selected_type_id`. The selection arm is
   unaffected: `image_id_known(Type, X)` stays true. The drain
   re-check (`src/app/shell.rs:2249`) already passed before the
   switch, and landing re-checks (`src/app/shell.rs:458`): X is
   still selected, so the result applies. Prune on the new
   character's first frame retains X because the selection arm
   still holds. The Fittings view's own whole-bundle icons are the
   opposite: they lose their guard backing at the switch and a
   late landing or prune drops them whole — the shipped
   `switching_character_revokes_fitting_type_knowledge` behavior,
   preserved byte-for-byte.
3. **Land.** `apply_portrait_landing` inserts `Ready(_)` under
   `(Type, X)` only because the guard holds at apply time. The
   texture upload happens exactly once per image
   (`Arc::ptr_eq`, `src/ui/portraits.rs:114-156`); the placeholder
   before that quotes section 5 of the type-icons design: a blank
   faint-background box, never a fabricated mark.
4. **Deselect X to Y** (the user picks another item — there is
   no deselect-to-none UI, section 1). The next `prune` drops the
   `(Type, X)` texture because the selection arm no longer holds
   and X is not fitting-known; the `Ready` image in
   `AppState::portraits` is not pruned (section 3), so reselecting
   X re-uploads that image once with no refetch. A landing for X
   that was still in flight at the deselect drops whole instead
   and leaves the key `Loading` (the inherited wart in section
   3). There is no per-frame re-upload while X stays selected
   because prune retains the union the whole time.
5. **Demo.** The demo fixture selection is installed from the
   bundle, but `decide_portrait_start` suppresses spawning
   (`src/app/shell.rs:2217-2223`), so `(Type, X)` stays `Loading`
   forever and never uploads. The blank box renders every frame;
   zero network calls; no demo-specific guard is needed.

Failure modes exercised by the trace: deselect before landing
(dropped whole, not shown for the wrong item), switch before landing
(retained, shown for the same type under the new character —
correct, because the image names the type), selection with no
characters (state entries cleared by the last-removal branch at
`src/app/state.rs:1234-1237`; the texture is retained by prune
only while the selection holds and renders nothing), and
reselect (one re-upload, no refetch). None of them uploads a
fetched image for the wrong item,
because the key is what is rendered: `show_type_icon` only renders
`(Type, type_id)` for the currently selected id, which after a
deselect points at Y, never at X.

## 5. Header layout, shell wiring, and logs

The Flutter market detail precedent is a header card: a 64px
type icon at the left, then a text column with the item name in
`titleLarge` and a second smaller line (`EveTypeIcon(size: 64)`,
market browser panel item header; search rows use 32px). The
Rust fetch is already locked at that size (`TYPE_ICON_SIZE = 64`,
`src/portraits.rs:60`). Render size, decided from the Rust
bodies: `TYPE_ICON_PX = 20.0` is documented as the *fittings
detail row* size, with its own constant precisely so a
row-density decision moves nothing else
(`src/ui/portraits.rs:36-41`). The market header is not a row;
it is the Flutter detail header. Locked: **render at 64pt** — a
new `MARKET_TYPE_ICON_PX: f32 = 64.0` beside `TYPE_ICON_PX` in
`src/ui/portraits.rs`, passed to `show_type_icon`. Fetch 64,
render 64, one-to-one, no downscaling; the fittings rows keep
their 20pt untouched. Layout mirrors Flutter structurally:
one `ui.horizontal` containing the icon, then a `ui.vertical`
with the resolved heading and the existing `Region: …` line as
the second text line, and the Refresh button below the header.
Flutter's second line is a raw `Type ID: N` — **not copied**;
the interface never shows raw ids.

Placeholder: the same 64pt slot renders the `show_logo` blank
box — faint theme background, 2pt rounding, no initial, no
letter, no spinner (`src/ui/portraits.rs:252-269`) — for every
non-`Ready` state (`NotRequested`, `Loading`, `Failed`, and
demo forever). `show_logo` takes no name parameter, so nothing
can be formatted into the slot; the resolved heading beside it
carries the meaning.

Wiring, point by point:

- `src/ui/market.rs::show` gains `cache: &mut PortraitImageCache`.
  It calls `cache.prune(state)` at its top, mirroring
  `characters.rs:32`, `dashboard.rs:27`, `fittings.rs:2392`; without
  it the market icon texture would never be pruned (GPU leak until
  a visit to a pruning view) and a stale texture would linger past a
  character switch.
- Inside `show`, after the `let Some(type_id)` guard
  (`src/ui/market.rs:562`), exactly one ensure:
  `ensure_type_icon_requested(state, type_id)` before the heading,
  inside the `Some` branch so no ensure runs when nothing is
  selected. The current `ui.heading(heading)` plus `Region: …`
  label (`src/ui/market.rs:575-580`) become the locked header:
  `ui.horizontal` { `show_type_icon(ui, cache, state, type_id,
  MARKET_TYPE_ICON_PX)`; `ui.vertical` { heading; region label } },
  Refresh below. Heading words unchanged (cached resolver name,
  else the captured selection name, else `"Unknown Item"`);
  `type_id` itself is never formatted. Ensure set therefore
  equals rendered set by construction; the icon and labels are
  built every frame (no virtualization claim), bounded at one.
- `src/ui/portraits.rs`: add `MARKET_TYPE_ICON_PX` (above), and
  fix the `ensure_type_icon_requested` doc comment
  (`src/ui/portraits.rs:189-194`), which today says unknown ids
  queue nothing "through the saved-fittings guard" — after this
  slice the guard is the union; the delegation body is unchanged.
- `src/app/shell.rs` dispatch: `View::Market` passes
  `&mut self.portrait_textures` into `ui::market::show`, mirroring
  the Fittings arm. No other dispatch changes.
- Logs: no new log line. `request_portrait`'s existing
  `[PORTRAIT]` transitions carry `kind=type` and the id
  (`src/app/state.rs:1402-1406`, warn at 1386-1390), and
  upload/replace/prune already log by kind and id
  (`src/ui/portraits.rs:135-147`, `77-80`). URLs and names never
  appear, per the standing rules.

## 6. Builder split (A/B, zero file overlap) and integrator list

Two builders, file-disjoint, sharing only the locked contract:
the `image_id_known` `Type` arm is the union of section 2, and
`ensure_type_icon_requested` / `show_type_icon` keep their
signatures. B's ensure queues nothing until A's guard lands, so
the integrator lands A first; both can be authored in parallel.

- **Builder A — guard** (owns only `src/app/state.rs`):
  - `image_id_known` `Type` arm becomes the union (section 2);
    its doc comment (lines 1295-1300) gains the selection
    clause; `fitting_type_known` and its doc unchanged.
  - `remove_character` captures `market_type_id` pre-reset
    beside `fitting_type_ids` (lines 1129-1144) and the retain
    `Type` arm (line 1161) becomes
    `fitting_type_ids.contains(&id) || market_type_id == Some(id)`.
  - A's tests (section 7, state rows) in the same commit.
- **Builder B — header** (owns `src/ui/market.rs`,
  `src/ui/portraits.rs`, `src/app/shell.rs`):
  - `MARKET_TYPE_ICON_PX` + the ensure doc fix
    (`src/ui/portraits.rs`); B's prune/headless tests there.
  - Cache parameter, prune-at-top, single ensure, locked 64pt
    header (`src/ui/market.rs`); B's market headless test there.
  - Dispatch passes `&mut self.portrait_textures` at
    `src/app/shell.rs:3775`; B's landing-after-deselect and
    demo assertions there. No other shell change.
- **Integrator** (after A then B): full four gates; confirm the
  shipped fittings tests pass unmodified
  (`prune_keeps_type_icon_across_selection_change`,
  `switching_character_revokes_fitting_type_knowledge`,
  `type_icon_landing_applies_then_drops_after_switch`); journal
  entry in `docs/engineering-journal/`; no merge or push.

Explicitly untouched: `src/portraits.rs` and `src/config.rs`
(fetch pipeline reused as-is), `src/demo/data.rs` and
`assets/demo/` (demo already fetches nothing), `src/ui/fittings.rs`.

Every commit passes the four gates; the clippy gate includes
`--all-targets` (a prior slice shipped test-code lints by running
clippy without it).

## 7. Test plan (all expectations literal)

Guard table — every row is `image_id_known(ImageKind::Type, id)`
unless the row names a function. X is the selected type, F is
fitting-known only, U is neither, C is a candidate/quick-pick
type that was never selected:

| Setup | Expectation |
|---|---|
| X selected, fittings `Loading` (X not in fittings) | X true; `request_portrait(Type, X)` queues exactly `[(Type, X)]`, state `Loading` |
| X selected | U false, C false; requesting either queues nothing and creates no entry |
| No selection (`None`) | X false |
| `market_search = "…"` only, no selection | false (search text never authorizes) |
| F in loaded saved fittings, nothing selected | F true (unchanged) |
| F known, then `set_active_character` to another character | F true → false (switch revokes the fittings arm, shipped behavior) |
| X selected, then the same switch | X stays true (selection survives; deliberately not character-keyed) |
| X selected, then `set_market_selection(Y, …)` | X false, Y true |
| `request_portrait(Type, 0)` / negative, any setup | queues nothing (non-positive pre-check) |

Tests, by owner:

- **A, `src/app/state.rs`**
  `market_selection_authorizes_only_the_selected_type` pins the
  table's selection rows (selected-not-in-fittings true,
  unselected and candidate-only false, `None` false,
  search-text false).
  `market_selection_survives_switch_while_fitting_arm_revokes`
  pins the two switch rows.
  `removing_character_retains_selected_market_icon`: two-character
  fixture (the last-removal branch clears all portraits at
  lines 1234-1237 and must not be the fixture), X selected with
  `(Type, X)` `Ready` and queued; removing the non-active
  character keeps both; removing the active character keeps the
  selection and the entry through the retain closure.
- **B, `src/app/shell.rs`**
  `market_type_icon_landing_drops_after_deselect`, mirroring
  `type_icon_landing_applies_then_drops_after_switch`
  (lines 4748-4781): with X selected and not in fittings,
  landing `Ok(test_image(8, 8))` returns true and `Ready` is
  8×8; selecting Y, then landing X at 4×4, returns false and
  the 8×8 image is still there (a dropped landing writes
  nothing).
- **B, `src/ui/portraits.rs`**
  `prune_keeps_selected_market_type_icon_across_switch`,
  mirroring `prune_keeps_type_icon_across_selection_change`
  (line 881): X `Ready` uploads once; prune across a fittings
  selection change and across a character switch keeps the
  texture (same cache length, no re-upload — prune non-thrash);
  after selecting Y, prune drops the X texture.
- **B, `src/ui/market.rs`** one headless render test, mirroring
  `show_type_icon_runs_headless` (`src/ui/portraits.rs:916`):
  drive `show` with a selection of X and empty `portraits`;
  assert exactly one queued `(Type, X)` request and no texture
  uploaded (blank-box path).
- **B, demo**: with a demo selection, `take_portrait_requests`
  yields `[(Type, X)]` but the drain refusal
  `decide_portrait_start(true, false) == Some(Demo)` governs
  (the shipped `portrait_start_decision_table` at
  `src/app/shell.rs:4410-4417`), and `(Type, X)` never becomes
  `Ready`. No demo fixture edit.

## 8. Exclusions (follow-ups, each needs its own design)

- **Quick-pick row icons and lookup-candidate row icons** —
  Flutter draws these at 32px, but authorizing them is Option
  C: up to 12 quick-pick types or a page of candidates become
  fetchable without a selection. Rejected here (section 2).
- **Order-row icons** — public orders, the character's own
  orders, and any history or other per-row surface in the
  Market view. Every such row already repeats the one selected
  type, so a row icon adds volume and no information in this
  slice.
- Flutter's `Type ID: N` second header line (raw id; never in
  this interface), a retry button for a `Failed` icon, and any
  widening of the one-id selection arm.

## 9. Revisit conditions

- A second surface wants more than one icon per selection, or the
  market icon becomes a list (then the volume bound, the prune
  superset, and the removal retain all need their own design, not a
  widening of this one-id arm).
- Real cache directories show type-icon growth that makes
  no-eviction untenable for the market union (same condition as the
  type-icons design, one texture instead of hundreds).
- The image service's `icon` coverage changes for any category the
  market selects (blueprint 400, SKIN 404 per the earlier probes):
  a `Failed` market icon shows the blank box beside the resolved
  name forever, exactly as fittings rows do; no retry button in
  this slice.
- `market_selected_type_id` gains a per-character owner (a future
  slice stamps the selecting character and clears on switch): the
  selection arm then becomes character-keyed and section 3's
  "deliberately not" must be revisited with new evidence.
- The inherited stuck-`Loading` wart (section 3) gets a general
  fix — for example clearing a `Loading` entry when its landing
  or drain is dropped as unknown. That changes every kind's
  landing semantics and wants its own design; this slice only
  inherits it.


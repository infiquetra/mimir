# Corporation and alliance logos — design

Slice goal: show the corporation logo and, when one is present, the
alliance logo beside the corporation and alliance names that the
active-character detail already renders, fetched from the public EVE
image service through the shipped portrait pipeline (slice #587:
[src/portraits.rs](/home/jefcox/workspace/infiquetra/mimir/src/portraits.rs),
[src/ui/portraits.rs](/home/jefcox/workspace/infiquetra/mimir/src/ui/portraits.rs),
and the shell landing in
[src/app/shell.rs](/home/jefcox/workspace/infiquetra/mimir/src/app/shell.rs)),
generalized in place rather than forked. Same rules as portraits:
honest placeholder (never a fabricated logo), demo makes zero network
calls, keyed async landing (a logo for corporation A must never paint
under corporation B), bounded decode/cache/concurrency, no new
scopes, user interface never shows raw ids.

Branch `feat/rust-logos` off `develop` at e96d8b4 (719 tests at
base). This document is the one design commit on the branch; every
constant, signature, wording string, and test literal below is locked
from bodies re-read this session and from the two completed
discoveries (Flutter archaeology at commit ed698d3, and the live
image-service probe recorded in section 4). Where this document and
a prior summary disagree, this document governs, because it was
written against the re-read bodies.

## 1. Generalization shape: one shared service, keyed by kind and id

Decision: generalize the portrait pipeline in place with one new key
type. Do not build a parallel logo service, and do not rename the
modules or the shipped types.

Duplication cost of the rejected parallel service, quoted from the
bodies (src/portraits.rs is 606 lines, test module from line 368;
src/ui/portraits.rs is 380 lines):

| Block a parallel service would copy | Lines today |
|---|---|
| `PortraitError` variants and display text | src/portraits.rs:35-47 |
| `decode_portrait` (byte cap, decoder limits, dimension check) | src/portraits.rs:74-108 |
| `PortraitClient` build, timeout and user agent, `fetch_bytes` streaming abort and error mapping | src/portraits.rs:124-201 |
| `PortraitStore` bounded read, atomic temp-and-rename write, poisoned-entry drop | src/portraits.rs:214-282 |
| `PortraitService` semaphore and cache-first flow | src/portraits.rs:292-366 |
| `PortraitState` enum, request queue, drain | src/app/state.rs:663-669, 1228-1280 |
| Start refusal, keyed landing, one-spawn-per-id drain | src/app/shell.rs:361-384, 440-482, 2204-2259 |
| Texture cache with `Arc::ptr_eq` upload-once and prune | src/ui/portraits.rs:44-195 |

That is roughly 600 lines copied, plus three structural regressions
the shared shape avoids: a second `Semaphore::new(MAX_CONCURRENT_FETCHES)`
(src/portraits.rs:305) would silently double the app-wide in-flight
bound from 4 to 8; a second `Arc` field on `Backends`
(src/app/shell.rs:42-52) plus new construction in
[src/main.rs](/home/jefcox/workspace/infiquetra/mimir/src/main.rs:105-108)
for an identical client; and a second `TextureHandle` cache on
`MimirApp` beside `portrait_textures` (src/app/shell.rs:140-144).

The only genuinely portrait-specific pieces in those blocks are the
URL path, the cache file name, the map key, the fetch size, and the
name-initial placeholder. Each becomes kind-aware below; everything
else is reused byte-for-byte in behaviour.

Naming rule that bounds the diff: names that say "portrait" stay,
because both files stay named `portraits.rs` and the type renames
would touch every shipped call site for no behaviour gain. The one
exception is `PortraitService::portrait`, renamed to
`PortraitService::image`, because it returns a corporation or
alliance logo for two of its three kinds and it has exactly one
production call site (src/app/shell.rs:2250). `PortraitError` keeps
even its name on purpose: the natural new name would collide with
`image::ImageError`, which `decode_portrait` already matches on
(src/portraits.rs:96). The module doc comments are updated to say
the portrait modules are the shared image modules; the file names
and the `pub mod portraits;` registration in
[src/lib.rs](/home/jefcox/workspace/infiquetra/mimir/src/lib.rs:21)
do not move.

## 2. Locked key type, constants, and URL seams

One new type, in src/portraits.rs next to the existing constants:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ImageKind {
    Character,
    Corporation,
    Alliance,
}

impl ImageKind {
    /// Fixed lower-case word for log lines: "character",
    /// "corporation", or "alliance". Never derived from user text.
    pub fn as_str(&self) -> &'static str { /* match, locked words */ }
}

/// The one logo size the whole app requests.
pub const LOGO_SIZE: u32 = 64;
```

`PORTRAIT_SIZE: u32 = 256` (src/portraits.rs:18) is unchanged, as
are `MAX_IMAGE_BYTES` (1 MiB, :23), `MAX_IMAGE_DIMENSION` (1024,
:26), and `MAX_CONCURRENT_FETCHES` (4, :29). Logos reuse all three
bounds; no bound is raised for this slice.

Why 64, from the probe in section 4: 64 is a size the live service
accepts (it returned an exact 64x64 PNG), it covers the one locked
render size of 20.0 points at more than three times the pixels
(60 physical pixels even at 3x display scaling), and it is the
smallest accepted size at or above the largest Flutter logo render
(48 points, section 8), so no in-slice render ever upscales. The
observed alliance body at 64 was 8,807 bytes against 104,336 bytes
at 256 for the same id, with zero render gain at 20 points. Flutter's
cap of 512 is not copied: the probed alliance body at 512 was
1,052,037 bytes, which exceeds `MAX_IMAGE_BYTES` (1,048,576) by
3,461 bytes and would fail as `TooLarge`. There is no per-render
size normalization function in Rust; like portraits, the app
requests exactly one fixed size per kind and views downscale.

URL seams, in
[src/config.rs](/home/jefcox/workspace/infiquetra/mimir/src/config.rs)
beside `portrait_url` (:159-166), same shape, production requests go
through these named functions only:

```rust
pub fn corporation_logo_url(corporation_id: i64, size: u32) -> String {
    format!("{}/corporations/{}/logo?size={}", Self::IMAGE_SERVER_URL, corporation_id, size)
}
pub fn alliance_logo_url(alliance_id: i64, size: u32) -> String {
    format!("{}/alliances/{}/logo?size={}", Self::IMAGE_SERVER_URL, alliance_id, size)
}
```

`IMAGE_SERVER_URL` stays `"https://images.evetech.net"`
(src/config.rs:9). No scope constant in src/config.rs changes: the
image service is public and unauthenticated (src/portraits.rs:1-7),
so logos need no token and no new scope group exists after this
slice.

## 3. Fetch, decode, and cache layout per kind

All in src/portraits.rs (Builder A, section 13). Every signature
that today takes `character_id: i64` takes `kind: ImageKind` first
and `id: i64` second; bodies change only where kind matters.

- `PortraitClient::fetch_bytes(kind, id, size)`: the URL block at
  :163-170 becomes a match on kind. Production (injected base equal
  to `IMAGE_SERVER_URL`) calls `EveConfig::portrait_url`,
  `corporation_logo_url`, or `alliance_logo_url`. The test seam
  formats `"{base}/characters/{id}/portrait?size={size}"`,
  `"{base}/corporations/{id}/logo?size={size}"`, or
  `"{base}/alliances/{id}/logo?size={size}"` against its own base.
  Timeout, user agent, `e.without_url()` error mapping, the
  streaming abort above `MAX_IMAGE_BYTES`, `Status(code)` mapping,
  and the empty-body error (:171-199) are unchanged.
- `decode_portrait(bytes)` (:74-108): no signature or body change.
  It is already kind-agnostic and already accepts both formats the
  service sends (section 4). Its doc comment gains one sentence
  stating it decodes character portraits and logos alike.
- `PortraitStore::read_cached(kind, id, size)`,
  `write_cached(kind, id, size, bytes)`, and
  `remove_cached(kind, id, size)`: only the path computation
  changes. Bounded `take(MAX_IMAGE_BYTES + 1)` read, atomic
  temp-and-rename write, and silent-miss behaviour (:226-281) are
  unchanged. `PortraitStore::new` still roots at
  `{app_cache_dir}/portraits/` (:218-222); logos live in the same
  directory. A separate `logos/` directory was rejected: one store
  instance serves all three kinds, the kind prefix below makes
  collision impossible, and renaming or splitting the directory
  would orphan the shipped portrait cache for no gain.
- `PortraitService::image(kind, id, size)` (renamed from
  `portrait`, :315-365): the same app-lifetime semaphore, the same
  cache-first flow, the same validate-before-caching order, the
  same poisoned-entry drop and single refetch, and the same
  best-effort cache write. One semaphore now bounds portraits and
  logos together, so the app-wide bound stays 4 in flight.

Cache file names (`cache_filename(kind, id, size)` and
`cache_path(dir, kind, id, size)` replacing :51-59). The character
row is the shipped legacy name and must not change, or every
existing on-disk portrait is orphaned:

| Kind | File name pattern | Example at the locked size |
|---|---|---|
| Character | `{id}_{size}.jpg` (legacy, unchanged) | `90000001_256.jpg` |
| Corporation | `corp-{id}_{size}.png` | `corp-1000166_64.png` |
| Alliance | `alliance-{id}_{size}.png` | `alliance-99003581_64.png` |

The kind prefix is load-bearing, not decoration: corporation
1000166 and a hypothetical character 1000166 are the same number,
and without the prefix one kind's bytes would serve another kind's
slot. Extensions follow the observed content types from the probe
(JPEG for portraits, PNG for logos); a PNG body under a `.jpg`
name would still decode, and that is exactly why it must not
happen silently. No eviction is added: growth stays bounded in
practice by the distinct corporations and alliances of the user's
own characters, one small PNG each at the fixed size. Entries for
corporations no character belongs to any more are left on disk
inert and reused if a character returns, the same deliberate rule
the store already documents for removed characters (:203-209).

## 4. Live image-service evidence (probe, this session's discovery)

All values below were observed from `https://images.evetech.net`
with the app's own user agent string (matching
`EveConfig::USER_AGENT` at src/config.rs:11) during the discovery
phase of this slice. Builders never re-probe the live service in
tests; the mock server in section 11 replays these shapes.

- Controls: `characters/90000001/portrait?size=256` returned 200,
  `image/jpeg`, 4,884 bytes. `corporations/1000166/logo?size=256`
  returned 200, `image/png`, 14,789 bytes.
  `corporations/1000125/logo?size=256` (CONCORD) returned 200,
  `image/png`, 51,597 bytes. Logos are PNG; portraits are JPEG.
  This is observed, not assumed.
- Size sweep, corporation 1000166: 32 returned 1,762 bytes at
  exactly 32x32; 64 returned 4,964 bytes at 64x64; 128 returned
  11,422 bytes at 128x128; 256 returned 14,789 bytes; 512 returned
  19,533 bytes. Decoded dimensions equal the requested size.
- Size sweep, alliance 99003581 (a real alliance with a dense
  logo): 32 returned 2,743 bytes; 64 returned 8,807 bytes; 128
  returned 29,613 bytes; 256 returned 104,336 bytes; 512 returned
  1,052,037 bytes, over the 1 MiB cap. This row is the evidence
  behind `LOGO_SIZE = 64` and behind rejecting Flutter's 512 cap.
- Invalid sizes 100, 999, and 0 each returned HTTP 400 with the
  plain-text body `bad size`. A missing `size` parameter returned
  a body byte-identical to `size=128` (11,422 bytes). No request
  in the probe redirected. The app always sends an explicit
  locked size, so neither behaviour is relied on.
- Transparency: decoded with the same `image` 0.25 limits
  `decode_portrait` sets (1024 dimension cap, 32 MiB allocation
  cap, guessed format, src/portraits.rs:85-93), every probed logo
  decoded as RGBA with real alpha. Corporation 1000166 at 256x256:
  46,012 fully transparent pixels, 13,516 partially transparent,
  6,008 opaque, 81 distinct alpha levels. CONCORD 1000125: 27,484
  transparent, 37,631 partial, 421 opaque, 256 alpha levels.
  Alliance 99003581: 21,072 transparent, 37,638 partial, 6,826
  opaque, 256 alpha levels. Alpha reaches the screen unchanged
  because the shipped upload path is `image.to_rgba8()` into
  `egui::ColorImage::from_rgba_unmultiplied`
  (src/ui/portraits.rs:103-108), which section 8 reuses verbatim.
  No PNG-specific code is added anywhere; the only PNG-visible
  change in the slice is the `.png` cache extension above.

## 5. The service never 404s an unknown id: the 200 decision

Observed in the same probe: `corporations/999999999/logo?size=256`
returned 200 with a 12,832-byte PNG, and
`corporations/999999998/logo?size=256` returned byte-identical
bytes. `alliances/999999999/logo?size=256` returned 200 with a
13,097-byte PNG, and `alliances/99000001/logo?size=256` (the demo
fixture id in
[assets/demo/names.json](/home/jefcox/workspace/infiquetra/mimir/assets/demo/names.json))
returned byte-identical bytes. Unknown ids get one shared
fallback image per kind, not an error. Character portraits behave
the same way today: `characters/999999999/portrait?size=256` was
byte-identical to the control portrait, and the shipped portrait
slice already lives with that. Three ways to answer this were
considered:

1. **Treat the 200 as authoritative for the ids this slice may
   request (locked).** The slice requests a logo only for an id
   that came from EVE's own data for a known character (section 6
   guard): a `corporation_id` or `alliance_id` carried on a
   character row or on the loaded public info for the active
   character. Such an id names a real corporation or alliance by
   construction, so the fallback case requires the entity to have
   ceased to exist after EVE itself reported the membership, or never submitted a logo (unprobed); in both cases the image is the service's own shared fallback, never another entity's logo. In
   that residue the app shows exactly what the image service
   returns for that exact id; it fabricates nothing and shows no
   other entity's logo. The placeholder rules then cover the
   failure modes the app can actually observe: transport error,
   error status, oversized body, undecodable body.
2. Hash-pin the fallback PNGs and treat a match as failure.
   Rejected: it bakes today's fallback artwork into the binary,
   breaks silently the day the service changes that artwork, and
   the probe recorded truncated hashes only, so no honest literal
   exists to pin without new live fetches at build time.
3. Existence-check each id before requesting. Rejected: a second
   network dependency on the render path, new failure modes, and
   demo-mode complexity, to guard a case the section 6 guard
   already makes unreachable for arbitrary ids.

Consequences of the locked decision, each normative:

- No code may request a logo for a user-typed, searched, or
  otherwise unverified id. The kind-aware guard in section 6 is
  the enforcement point, and it has no bypass.
- `fetch_maps_404_to_a_status_error` (src/portraits.rs:532-543)
  still documents the status mapping against the mock server,
  with a comment that the live service does not 404 unknown ids.
  No test asserts that an unknown live id fails, because it does
  not.
- A mock 200 body is treated as a real image for every kind.
  Nothing in the service inspects body hashes, `ETag`, or
  `Cache-Control` (the probe saw differing cache lifetimes, which
  the app does not consume today either).

## 6. State keying (`src/app/state.rs`)

`PortraitState` (:663-669) keeps its four variants and its name.
The map and the queue change key only:

```rust
pub portraits: HashMap<(ImageKind, i64), PortraitState>,
pub portrait_requests: Vec<(ImageKind, i64)>,
pub fn portrait_state(&self, kind: ImageKind, id: i64) -> &PortraitState
pub fn request_portrait(&mut self, kind: ImageKind, id: i64)
pub fn take_portrait_requests(&mut self) -> Vec<(ImageKind, i64)>
pub fn image_id_known(&self, kind: ImageKind, id: i64) -> bool
```

`image_id_known` is new and is the single definition of "this id
may be fetched", shared by `request_portrait` here and by the
shell landing in section 7:

- `Character`: some row in `self.characters` has
  `character_id == id`. This is the shipped guard (:1239-1242),
  unchanged.
- `Corporation`: some row has `corporation_id == id`, **or** the
  loaded active public info has it:
  `self.character_detail.as_ready()` (`LoadState::as_ready` at
  :104) with `info.corporation_id == id`. `CharacterRow` carries
  `corporation_id: i64` and `CharacterPublicInfo` carries the
  same field, so both trusted sources are already in state.
- `Alliance`: some row has `alliance_id == Some(id)`, or the
  loaded info has `info.alliance_id == Some(id)`.
- `self.dashboard` is deliberately **not** consulted: every
  landing writes the identical `info` value to `dashboard` and
  `character_detail` together (live refresh at
  src/app/shell.rs:1417-1418, demo apply at :829-830), so it can
  never know an id the other two sources do not.

Guards inside `request_portrait`, in order: an id at or below
zero is ignored with a warning for every kind (an unloaded public
info record defaults `corporation_id` to 0, and id 0 names no
entity); then an unknown id per `image_id_known` is ignored with
a warning, the shipped behaviour. The
`Ready`/`Loading` no-op, the `NotRequested`/`Failed` move to
`Loading`, and queue dedup by `(kind, id)` (:1250-1267) are
unchanged. Note the shipped character guard would have rejected
every logo id outright, because corporation and alliance ids are
not character ids; the kind-aware guard is a correctness fix the
slice must make, not an optimization.

`remove_character` (:1077-1207): the portrait drop at :1098-1099
becomes a retain over both structures, evaluated against the
character list **after** the retain at :1079:

- keep a `(Character, id)` entry or queued request only when
  `id` is not the removed character (the shipped rule);
- keep a `(Corporation, id)` entry or queued request only when
  some remaining row has `corporation_id == id`;
- keep an `(Alliance, id)` entry only when some remaining row
  has `alliance_id == Some(id)`.

So a corporation logo shared by two characters survives removing
one of them and drops when the last member goes. A logo known
only through the loaded info (a corporation no row carries yet,
because rows refresh less often than detail) drops on any
removal; that is accepted and documented, because the next
detail render re-requests it through the ensure call in
section 8. Rows are the only removal-time source on purpose: at
the moment the active character is removed its loaded detail is
about to be replaced, and rows are the stable membership record.
The clear-everything branch when no characters remain
(:1168-1171) is unchanged and clears all kinds with it.
Character switching still never clears the map, so a late
landing writes only its own `(kind, id)` slot.

## 7. Shell landing and drain (`src/app/shell.rs`)

- `BackendMsg::PortraitFetched` (:107-110) becomes
  `PortraitFetched { kind: ImageKind, id: i64, image: Result<Arc<image::DynamicImage>, PortraitError> }`.
  The variant keeps its name; there is one message, one landing
  function, and one drain for all three kinds. No `LogoFetched`
  variant exists after this slice.
- `apply_portrait_landing(state, kind, id, image) -> bool`
  (:447-482): the membership check at :452-458 becomes
  `state.image_id_known(kind, id)`; the keyed insert becomes an
  insert under `(kind, id)`. Everything else is unchanged, in
  particular the rule that a late `Err` never overwrites a
  `Ready` that already landed (:471-478), now evaluated per
  `(kind, id)` key. The keyed insert stays the whole correctness
  argument: a corporation A result can write only the
  `(Corporation, A)` slot, including when A equals some character
  id numerically, because the kind is part of the key. A result
  for an unknown or no-longer-referenced id returns `false` and
  is dropped whole.
- `decide_portrait_start` and `PortraitStartRefusal` (:361-384)
  are unchanged, including the refusal order: demo first, then
  missing backends.
- `start_portrait_fetches` (:2210-2259) iterates drained
  `(kind, id)` pairs. The demo arm still spawns nothing. The
  backends-missing arm marks each drained `(kind, id)` as
  `Failed` under its own key. The spawn arm picks the size by
  kind and calls the renamed service method:

  ```rust
  let size = match kind {
      ImageKind::Character => PORTRAIT_SIZE,
      ImageKind::Corporation | ImageKind::Alliance => LOGO_SIZE,
  };
  let image = service.image(kind, id, size).await;
  ```

- The drain site (:1860-1862), the landing dispatch
  (:1773-1785), `Backends.portraits` (:47-51), and the
  `portrait_textures` field and construction (:140-144, :948) are
  unchanged in shape. src/main.rs is untouched: the service is
  still constructed once at :105-108, still with no I/O at
  construction, still in demo mode too. The view dispatch
  passing `portrait_textures` to the characters and dashboard
  views (:3740-3752) is untouched.

## 8. Rendering: one surface, in the characters detail

Flutter precedent at ed698d3, re-read for this design:
`CorporationLogo` (`lib/core/widgets/corporation_logo.dart`)
requests `corporations/{id}/logo?size=` or
`alliances/{id}/logo?size=` with sizes normalized up through
`[32, 64, 128, 256, 512]`, inside a surface-colored rounded box,
with a spinner while loading and an abstract glyph on error
(`Icons.business_outlined` for a corporation,
`Icons.shield_outlined` for an alliance, at half size). Its name
rows put a 20.0-point logo left of the corporation and alliance
names in the overview tab; a separate portrait panel pinned a
48-point corporation logo over the large portrait's corner. No
Flutter list or grid used `CorporationLogo`; switcher rows and
the dashboard showed names only.

### Surfaces in this slice (complete list)

| Surface | In scope | Evidence |
|---|---|---|
| Active-character detail corporation and alliance rows, `src/ui/characters.rs:152-174` | **Yes, the one surface** | Flutter overview-tab name rows; ids already in scope as `info.corporation_id` and `info.alliance_id`; names already rendered at :159 and :163 |
| Characters switcher list, `src/ui/characters.rs:89-104` | No | No Flutter list precedent; rows stay portrait plus text |
| Dashboard corporation column, `src/ui/dashboard.rs:73-94` | No | No Flutter grid precedent; `src/ui/dashboard.rs` is not edited in this slice at all |
| Standings groups, `src/ui/characters.rs:293-370` | No, follow-up | Flutter had standings icons, but Rust discards `from_id` at :352 and `StandingRow` carries no id or type, and the Flutter code routed factions through the corporations endpoint, which section 14 excludes |
| Shell character rail | No | Name-only by the portraits design (`docs/portraits-design.md`, "the shell rail stays name-only"); unchanged |
| The 48-point corner overlay on the large portrait | No | Rust has no stacked portrait panel to overlay; the detail portrait renders above the grid (`src/ui/characters.rs:124-151`) |

### Locked rendering contract (Builder B, section 13)

- New constant in src/ui/portraits.rs beside `LIST_PORTRAIT_PX`
  and `DETAIL_PORTRAIT_PX` (:29-31): `pub const DETAIL_LOGO_PX: f32 = 20.0;`
- `PortraitImageCache` (:44-133) keys its map by `(ImageKind, i64)`.
  `texture(ctx, state, kind, id)` returns a texture only for
  `PortraitState` `Ready` under that exact key; the
  `Arc::ptr_eq` reuse and replace logic (:96-102) and the
  `to_rgba8` into `from_rgba_unmultiplied` upload (:103-108)
  are unchanged, which is what carries PNG alpha to the screen.
  Texture names: character keeps `"portrait-{id}"` (:110)
  verbatim; corporation is `"logo-corp-{id}"`; alliance is
  `"logo-alliance-{id}"`.
- `prune(&[CharacterRow])` keeps its signature (:58). Its retain
  predicate becomes kind-aware over the rows it already
  receives: keep `(Character, id)` when some row has that
  character id (shipped rule), `(Corporation, id)` when some row
  has that `corporation_id`, `(Alliance, id)` when some row has
  `alliance_id == Some(id)`. Dashboard calls `prune` too
  (`src/ui/dashboard.rs:27`) and needs no edit, because the
  signature and the character behaviour are unchanged.
- `ensure_portrait_requested(state, character_id)` keeps its
  signature (:144-151) and now calls
  `request_portrait(ImageKind::Character, character_id)` when
  the character key is `NotRequested`. New sibling
  `ensure_logo_requested(state, kind, id)` does the same for a
  corporation or alliance key. `Failed` is still never
  re-queued from the render path; retry is a button, below.
- `show_portrait(...)` keeps its signature (:168-195) and renders
  through the character key. New sibling with this exact shape:

  ```rust
  pub fn show_logo(
      ui: &mut egui::Ui,
      cache: &mut PortraitImageCache,
      state: &AppState,
      kind: ImageKind,
      id: i64,
      size_px: f32,
  ) -> egui::Response
  ```

  There is deliberately no `name` parameter: a logo placeholder
  shows no initial and no letter, so a name cannot be formatted
  into its slot by accident, and no raw id is formatted either.
- Placeholder, per kind (identical for corporation and alliance,
  differing only in the key): when no texture exists, allocate
  the same `size_px` square `show_portrait` allocates (:184-185)
  and fill it with the theme's faint background color,
  `painter.rect_filled(response.rect, 2.0, ui.visuals().faint_bg_color)`.
  Nothing else is drawn: no initial, no letter, no glyph. This
  is the honest-placeholder rule applied to logos; egui has no
  Material icon font here, and drawing a business or shield
  shape in painter paths would fabricate a mark in the exact
  slot that must stay neutral. Flutter's glyph was a stock icon,
  not artwork invented for a specific entity, and the blank box
  on the Flutter surface color is the equivalent honest shape.
  The resolved name beside the box always renders, so no
  information is lost while a logo loads or after it fails.
- Placement in the detail (the `LoadState::Ready(info)` arm,
  `src/ui/characters.rs:113-189`): inside that arm, before the
  detail grid renders, call `ensure_logo_requested` for
  `info.corporation_id` when it is above zero, and for
  `info.alliance_id` when it is `Some` and above zero. These are
  the only two logo ensure calls in the app; the switcher and
  dashboard ensure loops (:31-35 in characters, :27-31 in
  dashboard) stay character-only, so opening the Characters
  view never fetches every listed character's corporation.
  In the grid, the corporation row's second cell becomes a
  horizontal row of `show_logo(Corporation, info.corporation_id, DETAIL_LOGO_PX)`
  and then `ui.label(&corp)`; the alliance row, when present,
  is `show_logo(Alliance, alliance_id, DETAIL_LOGO_PX)` then
  the resolved alliance name. Left-of-name mirrors the Flutter
  overview tab. When `info.corporation_id` is at or below zero,
  the cell is the name label only, with no box and no request.
  When detail is not `Ready`, nothing about logos renders or is
  requested, exactly as the names do not render there today.
- Text beside logos: labels `"Corporation"` and `"Alliance"`
  and the resolved names are verbatim what renders today
  (:158-165), resolved through the same `resolver.name(id)`
  calls, which return a word fallback and never a number. A
  logo does not gate on name resolution: the id comes from
  EVE's data (section 6), so a logo may land while the name
  still shows its fallback words.
- No logo status text exists. There is no equivalent of
  `placeholder_status` for logos and none is added: a 20-point
  logo is decoration beside an always-present name, the failed
  state offers a retry button instead, and the shipped detail
  portrait beside the same block already carries the cycle's
  status line (`placeholder_status` strings are unchanged,
  including in demo mode).

### Retry wording (complete list of new user-visible strings)

Directly after the shipped portrait retry block
(`src/ui/characters.rs:200-214`), two independent buttons in the
same style, each shown only when the detail is `Ready`, demo
mode is off, and that logo's state is `Failed`:

```rust
ui.button("Retry corporation logo") // -> state.request_portrait(ImageKind::Corporation, id)
ui.button("Retry alliance logo")    // -> state.request_portrait(ImageKind::Alliance, id)
```

The alliance button additionally requires `info.alliance_id` to
be `Some` above zero. That retry block sits outside the detail
`match` today, so the two buttons read their ids from
`state.character_detail.as_ready()` and render nothing when it
is `None`. `"Retry portrait"` (:206) is unchanged.
These two strings are the only new visible text in the slice:
no new heading, no new status message, no demo-mode sentence
for logos.

## 9. Demo rules

Demo mode makes zero network calls for logos through the same
mechanism as portraits, with no demo-only code added: the detail
ensure calls queue requests, `take_portrait_requests` drains
them, and `decide_portrait_start` returns the demo refusal, so
nothing spawns and entries stay `Loading`, rendering as the
blank box. Service construction still performs no I/O, so
building it in demo mode (src/main.rs:105-108) stays safe.

Fixture facts, re-read this session: both demo characters in
[assets/demo/characters.json](/home/jefcox/workspace/infiquetra/mimir/assets/demo/characters.json)
carry `corporation_id: 1000166` and `alliance_id: null`.
[assets/demo/names.json](/home/jefcox/workspace/infiquetra/mimir/assets/demo/names.json)
resolves 1000166 as "Demo Defense League" (corporation), 1000125
as "CONCORD" (corporation), and 99000001 as "Demo Alliance"
(alliance). So demo exercises the corporation placeholder beside
the name "Demo Defense League", and it exercises the shared-corp
state rule structurally (both rows reference 1000166). No demo
character has an alliance, so the alliance row never renders in
demo; the alliance path is exercised by the unit tests in
section 11 instead. **No demo fixture file is edited in this
slice.** Adding an alliance to a fixture character would change
demo data other views and screenshots depend on, to show a blank
box; not worth it. Note also that the live service answers
99000001 with the shared fallback image (section 5); demo never
fetches, so demo behaviour is unaffected either way.

## 10. Logging

One tag for the whole image pipeline: `[PORTRAIT]`. A second
`[LOGO]` tag was rejected because it would split the lines of a
single fetch-and-land cycle across two log filters; the kind is
a field instead. Every generalized log line in src/portraits.rs,
src/app/state.rs, src/app/shell.rs, and src/ui/portraits.rs
carries `kind={}` with the `ImageKind::as_str` word and `id={}`
with the plain integer, for example:

- `[PORTRAIT] fetching image kind=corporation id=1000166 size=64`
- `[PORTRAIT] image requested kind=alliance id=99003581`
- `[PORTRAIT] image landed kind=corporation id=1000166`
- `[PORTRAIT] logo retry requested from Characters view kind=corporation id=1000166`
  (the one new view-layer line, beside the shipped portrait
  retry line at `src/ui/characters.rs:208-211`)

Rules, all inherited from the shipped pipeline and restated
because the slice touches every call site: ids and counts only;
never a URL (the Flutter widget logged the full logo URL, which
is on the explicit do-not-copy list of the discovery), never a
corporation, alliance, or character name, never a token, never
an error body. `PortraitError` display text (:36-47) is
unchanged and stays log-only; views never render it. The
per-frame render path stays log-free (src/ui/portraits.rs:11-16
convention); upload, replace, prune, request, land, and retry
are the logged events. The two drain refusal lines
(src/app/shell.rs:2218-2224) keep their wording and their
`count=` field; the count now covers portraits and logos
together, which is the honest total of what was drained.

## 11. Test plan

Literal expectations throughout, per standing rules: hand-derived
values asserted exactly, never computed from the code under
test. Every shipped portrait test is updated only for the new
key/parameter shape; its expected values do not change unless a
row below says so. Test image bodies are generated in-test; no
image fixture file is committed, matching the shipped
`generated_png` precedent (src/portraits.rs:402-411), and no
test touches the live service.

### src/config.rs (Builder A)

- `EveConfig::corporation_logo_url(1000166, 64)` equals
  `"https://images.evetech.net/corporations/1000166/logo?size=64"`.
- `EveConfig::alliance_logo_url(99003581, 64)` equals
  `"https://images.evetech.net/alliances/99003581/logo?size=64"`.
- `portrait_url_shape` (:302-308) unchanged and still green.

### src/portraits.rs (Builder A)

Existing helpers are reused: `mock_bytes_server` (:376-398, its
mock response already sends `Content-Type: image/png`) and
`generated_png` (:402-411). One new helper,
`generated_rgba_png`, encodes an `ImageRgba8` from explicit
pixels so alpha is assertable; `generated_png` cannot express
alpha because it builds an opaque `Rgb8` image.

- Cache naming: character `cache_filename(Character, 90000001, 256) == "90000001_256.jpg"`
  (legacy literal, the shipped test kept), corporation
  `cache_filename(Corporation, 1000166, 64) == "corp-1000166_64.png"`,
  alliance `cache_filename(Alliance, 99003581, 64) == "alliance-99003581_64.png"`,
  plus the same numeric id in all three kinds producing three
  distinct file names (1000166 as character, corporation, and
  alliance at size 64), and `cache_path` parity with the shipped
  path test.
- Mock fetch per kind (mirroring `fetch_decodes_from_the_image_service_shape`,
  :510-529): corporation asserts the captured request contains
  `"GET /corporations/1000166/logo?size=64"` and decodes to
  8x8; alliance asserts `"GET /alliances/99003581/logo?size=64"`
  and decodes to 8x8; the character case keeps
  `"GET /characters/90000001/portrait?size=256"`.
- Alpha survival: a generated RGBA PNG with pixel literals
  `[255, 0, 0, 0]`, `[0, 255, 0, 128]`, and `[0, 0, 255, 255]`
  decodes through `decode_portrait`, and `to_rgba8()` pixels
  equal those literals in order. This is the in-test grounding
  for transparent logo rendering; no screenshot asserts pixels.
- Cross-kind cache isolation: after a corporation fetch fills
  the cache for id 1000166, an alliance request for the same
  numeric id against an unroutable base (`http://127.0.0.1:9`,
  the shipped technique at :575-584) fails, proving corporation
  bytes cannot serve the alliance slot, while a second
  corporation request succeeds from cache with no network.
- Status mapping: a corporation mock 404 yields
  `Err(PortraitError::Status(404))`, with the section 5 comment
  that the live service does not 404 unknown ids.
- Oversized body: an alliance fetch with a body of
  `MAX_IMAGE_BYTES + 1` yields `Err(PortraitError::TooLarge)`.
- Poisoned entry: a corporation cache entry of `b"not an image"`
  is dropped and refetched to a valid 8x8.
- Semaphore: `semaphore_starts_with_the_bounded_permits`
  (:500-507) unchanged; one service, 4 permits, both kinds.

### src/app/state.rs (Builder A)

The five shipped portrait tests (:2490-2574) are rewritten over
`(Character, id)` keys with identical expectations (queue once
`vec![(Character, 1)]`, unknown ignored, ready skips and failed
re-queues, map survives switch, remove drops). Note the test
helper `row(id, name)` (:1288-1296) already sets
`corporation_id: 1000166, alliance_id: None`. New cases:

- Same numeric id, different kinds queue independently:
  requesting character 1000166 is ignored as unknown (no such
  character row); requesting corporation 1000166 queues
  `[(Corporation, 1000166)]` and sets that key `Loading`, while
  `portrait_state(Character, 1000166)` stays `NotRequested`.
- Guard by source: corporation known via row queues; corporation
  known only via `character_detail` `Ready` info queues;
  corporation in neither queues nothing. Alliance mirrors this
  with a row changed to `alliance_id: Some(99003581)`.
- Zero and negative ids queue nothing for any kind.
- Shared corporation survives removal: two rows with
  `corporation_id: 1000166`, corporation key `Ready`; removing
  one character keeps it `Ready`; removing the last empties the
  whole map (the shipped clear rule).
- Queued corporation request drops on removal when no remaining
  row references it, and survives when one does.

### src/app/shell.rs (Builder A)

The `portrait_start_decision_table` (:4389-4396) is untouched.
`two_character_state` (:4398-4418) already gives both test rows
`corporation_id: 1000166, alliance_id: None`. The three shipped
landing tests are rewritten over `(Character, id)` keys with
identical expectations. New cases:

- Corporation landing writes only its slot: activate character
  2, land an 8x8 for `(Corporation, 1000166)`; that key is
  `Ready` 8x8, `(Corporation, 1000125)` stays `NotRequested`,
  and character keys are untouched. This is the "corporation A
  never paints under corporation B" test.
- Wrong-kind rejection: landing `(Corporation, 2)` where 2 is a
  character id but no row's corporation returns `false` and
  inserts nothing; `(Character, 1000166)` where 1000166 is a
  corporation but not a character likewise returns `false`.
- Unreferenced alliance landing is dropped: with all rows at
  `alliance_id: None`, landing `(Alliance, 99003581)` returns
  `false` and the key is absent.
- Late failure does not overwrite: with `(Corporation, 1000166)`
  `Ready`, landing `Err(PortraitError::Status(404))` for the
  same key returns `true` and the key stays `Ready`.

### src/ui/portraits.rs (Builder B)

The seven shipped tests (:224-380) are rewritten over
`(Character, id)` keys; `placeholder_status` expectations,
including every demo row, are untouched. New cases:

- `ensure_logo_requested` queues only a `NotRequested`
  corporation key; `Loading`, `Ready`, and `Failed` queue
  nothing, and an unknown corporation id queues nothing (the
  state guard), mirroring the portrait ensure test.
- Same numeric id in two kinds uploads two textures: character
  1000166 `Ready` and corporation 1000166 `Ready` give
  `cache.len() == 2` with distinct texture ids.
- Prune is kind-aware: with two rows in corporation 1000166,
  pruning to one such row keeps the corporation texture (same
  texture id reused); pruning to a row with a different
  corporation frees it, and a later lookup re-uploads.
- Texture is `None` for a corporation key in `NotRequested`,
  `Loading`, and `Failed`, `Some` only for `Ready`.
- Headless smoke: `show_logo` renders a `Ready` corporation
  (one upload) and a placeholder corporation (no upload) in
  one headless frame, mirroring `show_portrait_runs_headless`.

### src/ui/characters.rs (Builder B)

The pure-helper test suites in this file (`standing_groups` and
friends) run unmodified, which is the regression proof that
standings and the rest of the detail sections did not move.
Placement and buttons follow the pass that shipped for portrait
placement: demonstration in the demo surface by the integrator
(section 12), not a pixel assertion.

## 12. Integrator checklist

The integrator merges Builder A and Builder B and reconciles
exactly these cross-file seams. Every call site found by
searching the base tree this session is listed. The compiler is
the arbiter for the one-argument forms (`portrait_state(id)`,
`request_portrait(id)`, keyed-by-bare-id inserts), which stop
compiling once the keys change; text searches for
`service.portrait(` and for a `character_id` field inside
`PortraitFetched` must additionally come back empty, because
those old names are deleted rather than re-shaped.

1. `src/config.rs`: the two new URL functions beside
   `portrait_url` (:159-166); test at :302 parity.
2. `src/portraits.rs`: `cache_filename`/`cache_path` (:51-59),
   `fetch_bytes` URL block (:150-200), store methods
   (:226-281), service method rename and body (:315-365), and
   the in-file tests (:413-606) including
   `service.portrait(...)` call sites.
3. `src/app/state.rs`: new `use crate::portraits::ImageKind;`
   import, fields (:724-725), `remove_character`
   portrait drop (:1098-1099) and clear branch (:1169-1171),
   `portrait_state`/`request_portrait`/`take_portrait_requests`
   (:1228-1280), tests (:2486-2574).
4. `src/app/shell.rs`: import line (:34, gains `ImageKind` and
   `LOGO_SIZE`), `PortraitFetched` variant (:107-110),
   `apply_portrait_landing` (:447-482), landing dispatch
   (:1773-1785), `start_portrait_fetches` (:2210-2259) including
   the backends-missing insert (:2226-2228) and the one
   `service.portrait` call (:2250), landing tests (:4425-4493).
5. `src/ui/portraits.rs`: imports (:23-24, gain `ImageKind`),
   cache key and `texture` (:45-133),
   `ensure_portrait_requested` body (:144-151), `show_portrait`
   internal texture call (:176), tests (:255-380) including
   every `state.portraits.insert` and `cache.texture` call.
6. `src/ui/characters.rs`: detail portrait status call
   (:139-142), detail grid corporation/alliance cells
   (:158-165), portrait retry state calls (:205-212), plus the
   new ensure, logo, and retry blocks from section 8.
7. Verified no-change files, checked rather than edited:
   `src/ui/dashboard.rs` (its `prune`, `ensure_portrait_requested`,
   and `show_portrait` calls at :27-31 and :83 keep their
   signatures), `src/main.rs` (:10, :105-127), `src/lib.rs`,
   `Cargo.toml` (the slice uses the already-declared `image`
   0.25, `reqwest`, and `tokio`; no new dependency), and all of
   `assets/demo/`.
8. Gates, run at integration and at every builder commit:
   `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
   `cargo test`, `cargo build`. The integrator also opens the
   demo Characters view and confirms: blank placeholder box
   left of "Demo Defense League", no alliance row, portrait
   demo behaviour unchanged, and no network-shaped delay (demo
   drain is synchronous).

## 13. Builder split, zero file overlap

| Owner | Files (exclusive) | Delivers |
|---|---|---|
| Builder A, fetch/state/shell | `src/config.rs`, `src/portraits.rs`, `src/app/state.rs`, `src/app/shell.rs` | `ImageKind`, `LOGO_SIZE`, logo URL seams, generalized client/store/service/method rename, kind-aware state guard/queue/removal, generalized `PortraitFetched`/landing/drain, tests named for these files in section 11 |
| Builder B, rendering | `src/ui/portraits.rs`, `src/ui/characters.rs` | Kind-keyed texture cache, `ensure_logo_requested`, `show_logo`, blank-box placeholder, detail placement and two retry buttons, tests named for these files in section 11 |
| Integrator | no new files; section 12 only | seam reconciliation, gates, demo check |

No file appears under two owners. The shared contract is the
exact signature list in sections 2, 3, 6, 7, and 8; neither
builder introduces a name not written there. Neither builder
edits `docs/logos-design.md` (this file), `src/ui/dashboard.rs`,
`src/main.rs`, `src/lib.rs`, `Cargo.toml`, or `assets/demo/`.
`src/main.rs` needs no wiring change because `Backends` gains no
field and `PortraitService::new` keeps its signature: a builder
who finds a wiring change necessary has diverged from section 1
and stops instead of improvising. Commits are small and atomic
per file or per seam, and gates pass at every commit.

## 14. Exclusions (each is a decision, not an oversight)

- Item type icons and type renders (`types/{id}/icon`,
  `types/{id}/render` on the image service): a separate slice.
  No `ImageKind` variant for types is added now; adding one
  later only extends matches that the compiler forces the
  author to complete.
- Faction logos: Flutter's `FactionLogo` routed faction ids
  (for example 500001) through the corporations endpoint. This
  slice adds no faction kind and never requests a faction id;
  the probe fetched one only to confirm the endpoint shape.
  Standings faction rows stay text-only.
- Standings icons: follow-up slice (section 8 table). Requires
  carrying `from_id` and `from_type` into `StandingRow` and a
  kind decision for faction standing rows; nothing in this
  slice pre-builds it.
- Switcher-list and dashboard logos: no Flutter precedent
  (section 8). Names stay as today in both places.
- Flutter do-not-copy list, each item contradicted by a locked
  choice above: logging the full logo URL (section 10);
  uncached per-view image loads — Flutter logos used plain
  `Image.network` with no disk cache (section 3 reuses the
  cache-first service); per-render size normalization (one
  locked `LOGO_SIZE`, section 2); the unnormalized
  default-size URL helpers (locked seams only); the 512 size
  cap (exceeds the byte bound, section 4); the spinner inside
  the logo box and the glyph placeholder (blank box, section
  8); the 48-point corner overlay on the portrait (no such
  stack in Rust, section 8).
- No cache eviction, no cache migration, no cache directory
  rename: legacy portrait file names and the `portraits/`
  directory stand (section 3).
- No fallback-image detection and no existence lookup
  (section 5, decisions 2 and 3 rejected there).
- No new OAuth scope, no `Cargo.toml` change, no new source
  file. If a builder believes one is needed, that is a design
  amendment request back to the parent, not a builder decision.
- No push and no merge from this workflow; the parent owns the
  branch after the design commit.




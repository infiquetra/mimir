# Standing entity icons — design

Base: `develop` at `d40dadc` (739 tests). Branch:
`feat/rust-standing-icons`. This slice adds entity icons to the
Characters standings list (`src/ui/characters.rs`), reusing the
shipped kind-keyed image pipeline from the corporation and
alliance logos slice (`docs/logos-design.md`, shipped in pull
request 591). That design's section 14 deferred exactly this
work: "Standings icons: follow-up slice … Requires carrying
`from_id` and `from_type` into `StandingRow` and a kind decision
for faction standing rows; nothing in this slice pre-builds it."
This document makes that kind decision and locks every other
choice the builders need. Standing rules for the whole slice:
literal test expectations, the user interface never shows raw
ids, `[PORTRAIT]` logs carry kind and id counts only, small
atomic commits with no attribution, gates (`cargo fmt --check`,
`cargo clippy -- -D warnings`, `cargo test`, `cargo build`) pass
at every commit, and no builder pushes or merges (the parent
owns the branch after the design commit).

Evidence in this document comes from bodies read this session:
`src/portraits.rs`, `src/ui/portraits.rs`, `src/config.rs` lines
159-184, `src/app/state.rs` lines 349-376, 940-1219, and
1254-1342, `src/app/shell.rs` lines 362-483 and 2203-2260,
`src/ui/characters.rs` lines 1-311, 386-570, and 749-913,
`src/esi/models.rs` lines 250-258, and the Flutter bodies at the
retirement commit `ed698d3` quoted in section 2.

## 1. Current state (verified)

The standings list renders text only. `StandingRow`
(`src/ui/characters.rs` lines 386-392) is
`{ name: String, standing: f64, standing_text: String }`.
`standing_groups` (lines 418-463) buckets
`(resolver.name(standing.from_id), standing.standing,
standing.from_id)`, sorts by value descending then name then
`from_id`, and at line 445 maps `|(name, standing, _from_id)|`
into `StandingRow` — discarding `from_id`, and `from_type` never
enters the bucket at all. The ESI model already carries both:
`Standing { from_id: i64, from_type: String, standing: f64 }`
(`src/esi/models.rs` lines 250-258, every field
`#[serde(default)]`), fetched from
`GET /characters/{character_id}/standings/`.
`show_standings_section` (lines 749-776) draws, per group under
the fixed headings `["Factions", "NPC corporations", "Agents",
"Other"]`, one `ui.label(format!("{} {}", row.name,
row.standing_text))` per row. Group index mapping
(lines 405-412): `"faction"` to Factions, `"npc_corp"` or
`"corporation"` to NPC corporations, `"agent"` to Agents, every
other string (including `"alliance"` and `""`) to Other. No
standing is ever dropped; this slice preserves that.

`from_type` literals present in the tree (`src/`, `tests/`,
`assets/`): `faction` (id 500001), `npc_corp` (1000125),
`corporation` (1000125 in `tests/fixtures/clones_standings.json`
line 14, 1000006 in the characters test helper), `agent`
(3000001, test helper only), `alliance` (99000001, demo and test
helper), and `""` (424242, test helper). No other literals exist.

Standings live in `AppState.character_details:
LoadState<CharacterDetailData>`, where
`CharacterDetailData.standings: SectionResult<Vec<Standing>>`
(`src/app/state.rs` lines 353-361). It is a single store for the
active character only — there is no per-character map. Section 5
traces its reset rules; they are the character-keying argument
for the fetch guard.

## 2. Flutter precedent (commit `ed698d3`, read verbatim)

`standings_sub_tab.dart` drew a 40-point icon left of each row:

```dart
if (fromType == 'faction') {
  return FactionLogo(factionId: fromId, size: 40, borderRadius: 8);
} else if (fromType == 'npc_corp') {
  return CorporationLogo.corporation(corporationId: fromId, size: 40,
      borderRadius: 8);
} else if (fromType == 'agent') {
  return Container(width: 40, height: 40, ... Icon(Icons.person_outline));
}
return Container(width: 40, height: 40, ... Icons.help_outline ...);
```

`FactionLogo` builds
`'${EveConfig.imageServerUrl}/corporations/$factionId/logo?size=…'`
with the comment "Factions use the corporations endpoint in the
image server". A live probe this session confirmed it:
`GET https://images.evetech.net/corporations/500001/logo?size=64`
returned status 200, `image/png`, 5392 bytes, a 64x64 RGBA PNG.
So a faction id serves a real logo through the corporations
endpoint at the app's locked logo size.

What Flutter does not decide for Rust: the agent arm is a generic
`person_outline` glyph with no fetch (its comment claims agents
use the character portrait endpoint, but the code never fetches
one — do not copy the comment), unknown types got a
`help_outline` glyph, sections only rendered the `faction`,
`npc_corp`, and `agent` groups (so `corporation`, `alliance`,
and empty types were invisible), sizes were passed unnormalized
(`size=40`), loads were uncached per-view `Image.network` calls,
and the corporation logo widget logged the full URL. Every one
of those is on the do-not-copy list in section 11.

## 3. Kind decision: a new `ImageKind::Faction`

**Locked: add a fourth variant, `ImageKind::Faction`.** Faction
standing rows request `(Faction, from_id)`; `npc_corp` and
`corporation` standing rows request `(Corporation, from_id)`.
The Faction kind's image-service URL is the corporations
endpoint (section 2), but its pipeline key, cache file, texture,
log word, and guard arm are its own.

Justification, from bodies:

1. The kind names the entity kind, not the endpoint.
   `src/portraits.rs` lines 18-21: "The kind is part of every
   key: the same number in two kinds is two different entities
   (a corporation and a character can share an id), so one
   kind's bytes must never serve another kind's slot." A faction
   is not a corporation. Keying 500001 as `Corporation` would
   store faction bytes in `corp-500001_64.png` and log
   `kind=corporation id=500001` — both false statements about
   what the bytes depict.
2. Numeric disjointness is an observation, not a contract.
   Every body read this session shows faction ids in the
   500001-500002 range and corporation ids at 1000006, 1000125,
   and 1000166, so reuse would not alias today. But nothing in
   the code or in EVE's data the app controls guarantees the
   ranges stay disjoint, and the reuse design would make a
   future collision silently serve one entity's logo in another
   entity's slot. The kind key exists precisely so correctness
   never depends on id allocation ranges.
3. Guard precision. With reuse, the `Corporation` guard arm
   would have to accept a standings `faction` entry as a
   corporation source, and any future corporation source (rows,
   public info) would equally authorize a faction number. With
   a Faction kind, section 5 can state the honest rule: a
   faction id is known only from a `faction` standing, a
   corporation id only from corporation sources and
   `npc_corp`/`corporation` standings, and neither authorizes
   the other.
4. The cost is bounded and compiler-checked. Adding a variant
   forces completion of every exhaustive `match` on `ImageKind`
   (the complete list is in section 4). That forced completion
   is the verification that no surface was missed — the same
   property `docs/logos-design.md` section 14 relied on when it
   deferred new kinds: "adding one later only extends matches
   that the compiler forces the author to complete."

Rejected alternative: reuse `ImageKind::Corporation` for faction
ids because the endpoint and the bytes are identical. It saves
the section 4 match arms, and it is the only serious contender.
It is rejected because it trades a one-time mechanical cost for
a permanent honesty defect in keys, cache files, and logs, and
because it makes the guard's corporation arm mean "corporation
or faction", which no later reader can see from the kind name.
If the image service ever grows a real factions endpoint, the
Faction kind changes one URL arm; the reuse design would first
have to migrate cache files and split a conflated key space.

## 4. Locked key, URL, cache, texture, and size contract

Production `match` sites on `ImageKind` (complete list, found by
searching `ImageKind::` over `src/` this session; test-only uses
are covered by section 9):

| Site | Faction arm (locked) |
| --- | --- |
| `src/portraits.rs` `ImageKind::as_str` (lines 32-38) | `"faction"` |
| `src/portraits.rs` `cache_filename` (lines 85-91) | `format!("faction-{id}_{size}.png")` |
| `src/portraits.rs` `fetch_bytes`, production URL (lines 206-210) | `EveConfig::faction_logo_url(id, size)` |
| `src/portraits.rs` `fetch_bytes`, test-seam URL (lines 212-229) | `format!("{}/corporations/{}/logo?size={}", base, id, size)` |
| `src/app/state.rs` `image_id_known` (lines 1263-1281) | section 5 |
| `src/app/state.rs` `remove_character` `logo_known` closure (lines 1116-1124) | section 5 |
| `src/app/shell.rs` fetch size (lines 2250-2253) | joins the logo arm: `Corporation \| Alliance \| Faction => LOGO_SIZE` |
| `src/ui/portraits.rs` texture name (lines 121-125) | `format!("logo-faction-{id}")` |

New URL seam in `src/config.rs`, beside the existing three
(lines 159-184), exact shape:

```rust
pub fn faction_logo_url(faction_id: i64, size: u32) -> String {
    format!(
        "{}/corporations/{}/logo?size={}",
        Self::IMAGE_SERVER_URL,
        faction_id,
        size
    )
}
```

The corporations path inside a faction-named helper is
deliberate: the helper name states the entity, the path states
the verified endpoint (section 2), and a future endpoint change
touches this one body. The doc comment on the helper must say
factions are served by the corporations endpoint so the path
never reads as a copy-paste error.

Locked constants, unchanged: fetch size `LOGO_SIZE = 64`
(`src/portraits.rs` line 47), byte and dimension caps, the one
semaphore `MAX_CONCURRENT_FETCHES = 4` (line 59), cache-first
service behavior including poisoned-entry drop, and the
`portraits/` cache directory. No cache migration: no
`corp-500001_64.png` file is ever created by this slice, and no
existing file is renamed or read under a new name. The module
doc comments that say "all three kinds" (`src/portraits.rs`
lines 1-5, 264, 350-352) become "all four kinds" in the same
commit that adds the variant.

## 5. Fetch guard: standings-sourced ids, character-keyed

`AppState::image_id_known` (`src/app/state.rs` lines 1263-1281)
stays the single definition of "this id may be fetched", shared
by `request_portrait` (lines 1296-1333), the shell landing
`apply_portrait_landing` (`src/app/shell.rs` lines 450-483),
and texture prune (`src/ui/portraits.rs` lines 66-76). This
slice extends it in place; there is no standings-specific guard
and no second known-set.

### 5.1 Exact extension shape

One private helper on `AppState`, used by two arms:

```rust
/// Whether the loaded standings name `(kind, id)`: a `faction`
/// standing for `Faction`, an `npc_corp` or `corporation`
/// standing for `Corporation`, nothing for any other kind.
fn standing_known(&self, kind: ImageKind, id: i64) -> bool {
    let wanted: &[&str] = match kind {
        ImageKind::Faction => &["faction"],
        ImageKind::Corporation => &["npc_corp", "corporation"],
        ImageKind::Character | ImageKind::Alliance => return false,
    };
    self.character_details
        .as_ready()
        .and_then(|bundle| bundle.standings.as_ref().ok())
        .is_some_and(|standings| {
            standings
                .iter()
                .any(|s| s.from_id == id && wanted.contains(&s.from_type.as_str()))
        })
}
```

`image_id_known` then reads, per kind:

- `Character`: unchanged (character rows only). A standing
  never authorizes a character portrait — in particular an
  `agent` standing does not (section 7).
- `Corporation`: existing row or loaded-public-info check, OR
  `standing_known(Corporation, id)`.
- `Alliance`: unchanged (rows or loaded public info only). An
  `alliance` standing does not authorize an alliance logo
  fetch; alliance standing rows stay text-only (section 11).
- `Faction`: `standing_known(Faction, id)` and nothing else.
  Faction has no row or public-info source anywhere in the app.

Consequences that must hold and are tested in section 9: an
`Err` standings section authorizes nothing (`as_ref().ok()`
yields `None`), a non-Ready `character_details` authorizes
nothing, a `faction` standing for 500001 makes `(Faction,
500001)` known and does not make `(Corporation, 500001)` known,
an `npc_corp` standing makes `(Corporation, from_id)` known and
no other kind, and `agent`, `alliance`, `""`, and unknown types
authorize nothing. `request_portrait` keeps ignoring ids at or
below zero before the guard is consulted, so a standings entry
with `from_id <= 0` can never queue a fetch even though the
guard would match its type string. Ids known only from the name
resolver's cache, from demo fixtures as such, or from any typed
or searched text confer no fetch right; only state sourced from
EVE data (rows, loaded public info, loaded standings) does.

### 5.2 Character-keyed validity

Standings are the active character's standings, and the guard
inherits that ownership from `character_details` reset rules,
traced in `src/app/state.rs` this session:

- Character switch (`set_active_character`, different id):
  `self.character_details = LoadState::Loading` (line 964). From
  that instant the previous character's standing ids are unknown
  to the guard. A fetch already in flight for one of them lands
  through `apply_portrait_landing`, which re-checks
  `image_id_known` and drops the result whole (shell lines
  456-458). Textures uploaded earlier are dropped by the next
  `prune`, which retains by the same guard.
- Same-character reselect: the reset block is skipped
  (`previous_id != character_id` gate, line 940), so standings,
  icons, and textures all survive — correct, because the owner
  did not change.
- Removing the active character: `character_details` resets to
  `Loading` (line 1137) and a replacement is activated, whose
  own reset path also applies. Removing the last character sets
  `character_details` to `Empty` and clears `portraits` and
  `portrait_requests` outright (lines 1196-1204).
- Removing a non-active character: `character_details` is
  untouched, so the active character's standings icons keep
  their guard backing (section 5.3 handles the entry retain).

Because rendering only ever draws rows built from the currently
Ready bundle (section 7), character A's standing rows cannot
render under character B at all; the guard rules above cover the
fetch, landing, and texture lifetimes behind those rows. If both
characters legitimately have a standing with the same faction,
the same `(Faction, id)` image serving both rows is correct —
it is the same entity, and the image names the entity, not the
character who has the standing.

### 5.3 Removal retain mirror

`remove_character` evaluates its own `logo_known` closure
(lines 1116-1124) against the retained character list and the
loaded public info, then retains `portraits` and
`portrait_requests` by it (lines 1125-1127). Any guard source
not mirrored there loses its entries on every removal. Locked
mirror: before the closure, capture the standings source exactly
as the existing code captures `detail_corp` and
`detail_alliance` (lines 1107-1114) — the `Ok` standings slice's
`(from_type, from_id)` pairs, or an equivalent precomputed
predicate input — and extend the closure:

- `Corporation`: existing row or detail check, OR a captured
  `npc_corp`/`corporation` standing with that `from_id`.
- `Faction`: a captured `faction` standing with that `from_id`.
- `Character` and `Alliance`: unchanged.

Capture order matters and is already correct in the body: the
retain at lines 1125-1127 runs before the active-removal reset
of `character_details` at line 1137, so the captured standings
are the pre-removal ones. When the removed character was active,
entries retained only by its standings survive the retain but
immediately lose guard backing when `character_details` resets;
the next `prune` frees their textures and a late landing is
dropped. That matches how detail-sourced logos already behave.

## 6. `StandingRow` extension and the kind mapping

Locked row shape (`src/ui/characters.rs`):

```rust
pub struct StandingRow {
    pub name: String,
    pub standing: f64,
    pub standing_text: String,
    pub from_id: i64,
    pub from_type: String,
}
```

Both new fields are state, never rendered: no format string in
any view may include `from_id` or `from_type`, and no log line
may either (section 8). `standing_groups` carries them by
extending its bucket tuple to `(String, f64, i64, String)` —
name, standing, `from_id`, `from_type.clone()` — keeping the
existing sort (value descending, non-finite last, then name,
then `from_id`) and mapping all four into the row instead of
discarding `_from_id`. Grouping, headings, counts, and the
`[CHAR] grouped standings count=… groups=…` debug line are
unchanged.

One pure mapping helper, shared by the ensure loop and the
render loop so they can never disagree about eligibility:

```rust
/// The image kind one standing's entity may show, or `None`
/// when the row is text-only. Agents never fetch a portrait.
pub fn standing_icon_kind(from_type: &str) -> Option<ImageKind> {
    match from_type {
        "faction" => Some(ImageKind::Faction),
        "npc_corp" | "corporation" => Some(ImageKind::Corporation),
        _ => None,
    }
}
```

This is deliberately a second match on the type strings beside
`standing_group_index` rather than a merged table: grouping
answers "which heading" for every string, icon eligibility
answers "which kind, if any", and the two change for different
reasons. The strings must agree with section 5.1's `wanted`
lists; section 9 tests both against the same literals.

## 7. Rendering: surfaces, sizes, wording

Surfaces in this slice (complete list): standings rows in the
Characters view's character-detail block only. No switcher, no
dashboard, no other view changes.

Locked size: `portraits::DETAIL_LOGO_PX` (20 points,
`src/ui/portraits.rs` line 35), the same size as the detail
corporation and alliance logos left of their names
(`src/ui/characters.rs` lines 180-214). Rejected: Flutter's 40
points. Flutter's standings were a spacious card list; the Rust
standings section is a dense text list under four headings, and
a 40-point icon would double every row height for a decorative
gain. The decoded 64-pixel image downscales to 20 points, as
every other logo render does. No new size constant is added.

Row layout, locked:

- Icon-eligible row (`standing_icon_kind` returns `Some(kind)`
  and `from_id > 0`): one `ui.horizontal` containing
  `portraits::show_logo(ui, cache, state, kind, from_id,
  DETAIL_LOGO_PX)` then
  `ui.label(format!("{} {}", row.name, row.standing_text))` —
  the same text as today, so wording is unchanged. While the
  image is `NotRequested`, `Loading`, or `Failed`, `show_logo`
  draws its existing blank faint-background box; no initial, no
  glyph, no spinner, no id.
- Every other row (`agent`, `alliance`, `""`, unknown types,
  and eligible types with `from_id <= 0`): the plain
  `ui.label(...)` exactly as today, with no icon widget and no
  compensating blank space. Locked as "nothing", not "blank
  box": in this pipeline a blank box means "an image belongs
  here and is pending or failed", and drawing one for an agent
  would promise an image that will never arrive. The accepted
  cost is that Agents and Other rows start flush left while
  icon rows indent by the icon width; rows are grouped under
  separate headings, so the shift happens at heading boundaries,
  never mid-group except in Other (an `alliance` row beside no
  icon rows at all, since Other has no eligible types — in fact
  Agents and Other groups are uniformly icon-free, and Factions
  and NPC corporations are uniformly icon-bearing for positive
  ids).

Wording: this slice adds no user-visible string. Headings, the
counts line, "No standings yet", name plus `+3.25`-style value
text, and section error lines are all unchanged. There are no
per-standing retry buttons: a `Failed` standings icon stays a
blank box (the render path never re-queues `Failed`, per
`ensure_logo_requested`), and the existing detail logo retry
buttons are untouched. N retry buttons for a cosmetic list icon
would be noise; the name beside the box carries the meaning.

Ensure call site, locked: in `show`, beside the existing
detail-logo ensure block (lines 119-132), not inside
`show_standings_section` (which holds only a cloned bundle
snapshot and no mutable state). Shape: read
`state.character_details.as_ready()`, take `standings` as
`Ok(vec)` (an `Err` section queues nothing), clone the eligible
`(kind, id)` pairs into a small local `Vec` first (the borrow
pattern the detail block already uses with `detail_logo_ids`),
then call `portraits::ensure_logo_requested(state, kind, id)`
for each pair with `id > 0`. The comment above the detail block
that claims "the only two logo ensure calls in the app"
(lines 113-115) must be corrected in the same commit to cover
both blocks. Volume is the distinct eligible ids of the active
character only: `ensure_logo_requested` queues only
`NotRequested`, `request_portrait` dedups the queue, and the
one semaphore bounds flight at 4, so a long real standings list
drains in waves and duplicate standings for one entity queue
one fetch.

Signature threading, locked: `show_character_details` gains
`cache: &mut PortraitImageCache` (its one caller at line 311
already has it) and passes `state` (as `&AppState` after the
snapshot clone) plus `cache` to `show_standings_section`, whose
signature becomes
`fn show_standings_section(ui, bundle, resolver, panel_shown,
state: &AppState, cache: &mut PortraitImageCache)`. No other
section function changes signature.

## 8. Demo and logging

Demo behavior is unchanged and stays zero-network. The ensure
loop only queues requests; the shell's `decide_portrait_start`
(`src/app/shell.rs` lines 377-385) refuses with `Demo` and
`start_portrait_fetches` drains without spawning (lines
2215-2221). Demo standings data is untouched
(`assets/demo/character_detail.json`: character 90000001 has a
`faction` 500001 and an `npc_corp` 1000125 standing; 90000002
adds an `alliance` 99000001), so in demo the two eligible rows
per character show blank boxes and the alliance row stays
text-only — the same honest placeholder behavior as demo detail
logos today. Extending the guard does not change this: the
guard decides what may queue, the shell decides what may spawn,
and demo still spawns nothing.

Logging: no new log lines. Faction traffic flows through the
existing `[PORTRAIT]` lines with `kind=faction` (request,
fetch, cache hit/write, texture upload/replace, landing
failure, prune count) because every one of them formats
`kind.as_str()` and the plain integer id. The per-frame render
path stays log-free, the standings grouping `[CHAR]` debug
line is unchanged, and nothing anywhere logs a URL, an entity
name, a `from_type` string, or an error body. Builder check:
searching the diff for `tracing::` added lines should find none
outside comment text.

## 9. Test plan (literal expectations throughout)

### `src/config.rs` (Builder A)

- `faction_logo_url(500001, 64)` equals the literal
  `"https://images.evetech.net/corporations/500001/logo?size=64"`,
  beside the existing URL literal tests.

### `src/portraits.rs` (Builder A)

- `cache_filename(ImageKind::Faction, 500001, 64)` equals
  `"faction-500001_64.png"`; extend the same-number distinctness
  test (lines 519-521) to all four kinds at id 1000166: four
  pairwise-distinct names.
- `ImageKind::Faction.as_str()` equals `"faction"` (in whichever
  existing test covers `as_str`, or beside the filename tests).
- Faction fetch through the mock server: serving a generated
  PNG for `(Faction, 500001, LOGO_SIZE)` decodes successfully
  and the captured request line contains
  `"/corporations/500001/logo?size=64"` — proving the test seam
  routes Faction to the corporations path.
- Cache isolation: bytes written under `(Corporation, 500001)`
  are not read back under `(Faction, 500001)` (distinct files),
  mirroring the existing cross-kind cache tests.

### `src/app/state.rs` (Builder A)

Build states whose `character_details` is `Ready` with a bundle
whose other sections are `Err` fixtures and whose `standings`
section varies. Cases, each asserted with literal ids:

- Standings `Ok` with `{500001, "faction"}`, `{1000125,
  "npc_corp"}`, `{1000006, "corporation"}`, `{3000001,
  "agent"}`, `{99000001, "alliance"}`, `{424242, ""}`:
  `image_id_known(Faction, 500001)` is true;
  `image_id_known(Corporation, 500001)` is false;
  `image_id_known(Corporation, 1000125)` and
  `image_id_known(Corporation, 1000006)` are true with no row or
  detail naming them; `image_id_known(Faction, 1000125)`,
  `image_id_known(Character, 3000001)`,
  `image_id_known(Alliance, 99000001)`, and every kind at 424242
  are false.
- `request_portrait(Faction, 500001)` on that state queues
  exactly `vec![(ImageKind::Faction, 500001)]` and a second call
  queues nothing more; `request_portrait(Corporation, 500001)`
  queues nothing and creates no entry.
- Standings `Err` (a `needs_reauthorize` section error): every
  standings-derived assertion above is false and nothing queues.
- `character_details` `Loading`: nothing standings-derived is
  known.
- Switch: state with two character rows, the bundle above
  loaded, `(Faction, 500001)` requested; after
  `set_active_character(other_id)`, `image_id_known(Faction,
  500001)` is false (the bundle reset) — the
  standings-of-A-never-fetch-under-B property at the guard
  level.
- Removal: with the bundle loaded and `Ready` entries seeded
  for `(Faction, 500001)` and `(Corporation, 1000125)`,
  `remove_character(non_active_id)` retains both entries and
  any queued requests; `remove_character(active_id)` followed
  by the resulting state has `image_id_known` false for both
  (prune and landing then do their existing jobs). The existing
  all-kinds array test near line 2759 gains `ImageKind::Faction`
  so the remove-clears-everything case covers the new kind.

### `src/app/shell.rs` (Builder A)

- Landing under the standings guard: state with the section 9
  bundle; `apply_portrait_landing(Faction, 500001, Ok(img))`
  returns true and `portrait_state(Faction, 500001)` is `Ready`;
  after switching the active character (bundle reset), a second
  landing for `(Faction, 500001)` returns false and writes
  nothing — the mid-fetch switch property end to end.
- `apply_portrait_landing(Corporation, 500001, Ok(img))` on the
  faction-standing state returns false (cross-kind rejection).

### `src/ui/portraits.rs` (Builder B)

- Texture keying: `Ready` images for `(Corporation, 500001)`
  and `(Faction, 500001)` upload as two textures (`cache.len()`
  2, distinct handles), mirroring the existing same-number
  character/corporation test.
- Prune by standings: upload `(Faction, 500001)` against the
  bundle state, then prune against a state whose
  `character_details` is `Loading`; the cache is empty. Prune
  against the bundle state keeps it.

### `src/ui/characters.rs` (Builder B)

- Extend `standing_groups_order_sort_and_keep_unknown_types`
  with literal field assertions: the Caldari State row has
  `from_id == 500001` and `from_type == "faction"`, the NPC
  corporation rows carry 1000125/`"npc_corp"` and
  1000006/`"corporation"`, the Other rows carry
  99000001/`"alliance"` and 424242/`""`. Existing assertions
  stand unchanged.
- `standing_icon_kind` table: `"faction"` maps to
  `Some(ImageKind::Faction)`, `"npc_corp"` and `"corporation"`
  to `Some(ImageKind::Corporation)`, and `"agent"`, `"alliance"`,
  `""`, and `"character"` to `None`.

No test may reach the network; the section 2 probe was
discovery evidence, not a test dependency. The demo seed tests
(`tests/demo_seed.rs`) need no change: demo data and seeding
are untouched, and their existing resolver assertions already
cover the demo standing ids by name.

## 10. Integrator checklist

- `src/main.rs` and `src/lib.rs`: no change. `PortraitService`
  keeps its constructor and `image` signature; `Backends` gains
  no field. A builder who needs wiring there has diverged and
  stops.
- `Cargo.toml`: no change, no new dependency.
- `assets/demo/`: no change.
- `docs/logos-design.md` and this file: builders do not edit
  either; design amendments go back to the parent.
- The only cross-builder contract is the set of names in
  sections 4-6: `ImageKind::Faction`,
  `EveConfig::faction_logo_url`, the extended `StandingRow`
  fields `from_id`/`from_type`, `standing_icon_kind`, and the
  private `standing_known` helper (Builder A only). Neither
  builder invents a name not written here.
- Gates at every commit: `cargo fmt --check`,
  `cargo clippy -- -D warnings`, `cargo test`, `cargo build`.
  Test count grows from 739 by the section 9 additions; no
  existing test is deleted or weakened.
- Manual demo check after integration (parent or integrator):
  demo mode, Characters view, both demo characters — faction
  and NPC corporation rows show blank boxes left of names, the
  alliance row is text-only, zero network calls (log shows the
  demo-suppressed drain line, no fetch lines).

## 11. Builder split, zero file overlap

- Builder A (pipeline and guard): `src/config.rs`,
  `src/portraits.rs`, `src/app/state.rs`, `src/app/shell.rs`.
  Owns sections 3-5 and its section 9 tests. The shell size arm
  and both `fetch_bytes` arms are A's.
- Builder B (rendering): `src/ui/portraits.rs` (texture name arm
  and its tests only), `src/ui/characters.rs`. Owns sections 6-7
  and its section 9 tests.

No file appears in both lists. The exhaustive-match errors from
adding the variant land exactly one per file above, so each
builder's compile errors stay inside their own files; if a
compiler error points at the other builder's file, that is the
signal to hand it across, not to edit across. Commits are small
and atomic per file or per seam, gates green at each.

## 12. Exclusions (each is a decision, not an oversight)

- Agent portraits and agent icons of any kind. Flutter's agent
  arm was a generic glyph; its "character portrait endpoint"
  comment described code that does not exist. Agent rows are
  text-only and an agent id never reaches `request_portrait`
  under any kind.
- Alliance standing icons. The `alliance` type appears in demo
  data, but Flutter had no arm for it (its rows never rendered),
  and this slice's brief covers faction and corporation
  entities. Alliance standing rows stay text-only under Other,
  and section 5 deliberately does not widen the `Alliance`
  guard arm. Adding them later is a one-line `wanted` change
  plus a `standing_icon_kind` arm — a future slice can make
  that call with its own evidence.
- Reusing `ImageKind::Corporation` for faction ids (section 3).
- Flutter do-not-copy list: glyph placeholders
  (`person_outline`, `help_outline`, `flag_outlined`,
  `business_outlined`), spinners inside the icon box, uncached
  per-view loads, unnormalized sizes, the full-URL log line,
  dropping non-faction/npc_corp/agent sections, background
  tints and standing bars, and the 40-point box (section 7).
- Per-standing retry buttons and any other new user-visible
  string (section 7).
- Switcher, dashboard, and every other surface (section 7).
- New size constants, new OAuth scope, new source file, cache
  eviction or migration, and any change to standings fetching,
  grouping order, sorting, or counts.
- No push and no merge from this workflow; the parent owns the
  branch after the design commit.

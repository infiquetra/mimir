# Skill type icons in the Skills catalogue — design

Base: `develop` at `d456f38` (788 tests, post asset-icons merge
[#595](https://github.com/infiquetra/mimir/pull/595)).
Branch: `feat/rust-skill-icons`. Slice goal: show each rendered
Skills catalogue row's skill type icon through the shipped
`ImageKind::Type` pipeline.

This slice's design question is the guard, not the widget. The
catalogue is bundled static data (the SDE skill extract, 495
skill types), not character-loaded state, and every shipped
`Type` guard arm — fittings, assets, market selection — is
loaded-state sourced. The type-icons design considered
catalogue membership as a guard for fittings and rejected it
(`docs/type-icons-design.md` section 5.1, lines 346–359 of the
current tree). Section 3 of this document re-reads those three
rejection reasons against bodies and locks a verdict:
**ship, with an explicitly static bundled-data arm** — honest
here and still rejected for fittings, on evidence stated in
full, with the plumbing and app-lifetime retention that honesty
costs paid in sections 3–4 and a hard volume bound locked in
section 2. If any part of that evidence stops holding, this
design ships nothing (section 9 names the revisit triggers).

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
design session on the `d456f38` tree, plus the two read-only
discovery passes run for this slice (catalogue structure, guard
audit), whose load-bearing claims were re-read from bodies here:
`src/ui/skills.rs` (module head at 1–15, `show` at 313–472 with
the catalogue at 403–458, the skill-plan picker at 902–996),
`src/names/sde.rs` in full (`Sde` at 70–78, `contains` at
118–120, bundled counts pinned by its tests at 199–291),
`src/app/state.rs` (`AppState` at 687–728, `AppState::new` at
836–857, `remove_character`'s captures and retain at 1132–1183
and its resets at 1184–1290, `image_id_known` and its doc at
1310–1349, `fitting_type_known` at 1351–1367,
`asset_type_known` at 1369–1377, `request_portrait` at
1406–1448, the guard tests at 3286–3600),
`src/app/shell.rs` (`MimirApp` at 123–148 with `pub sde: Sde`
at 125, `decide_portrait_start` at 379–387,
`apply_portrait_landing` at 452–485, `MimirApp::new` at
838–963 with the SDE load at 845–848 and `AppState::new` at
851, the portrait drain at 2211–2278 with its re-check at
2249–2256, the outer scroll and dispatch at 3758–3798 with
`View::Skills` at 3772), `src/ui/portraits.rs`
(`TYPE_ICON_PX` at 36–41, `prune` at 78–88, the type-icon
ensure and show delegations at 201–210 and 285–297, the prune
tests at 894–1050), `src/portraits.rs:47-72` (sizes and the
fetch semaphore) and 420–446 (cache-first fetch),
`src/demo/data.rs` (the demo skills install at 1106–1109,
`seed_demo_state` at 1274), `src/ui/assets.rs` (the shipped
render cap and the demo queue test at 670),
`docs/type-icons-design.md` section 5.1 (lines 346–367) and
section 5.2, `docs/asset-icons-design.md` in full, the bundled
`assets/sde/skills.json` (counted this session, section 1),
and the vendored egui 0.29.1 source
(`src/containers/collapsing_header.rs`: `show_body_unindented`
at 191–199, `begin` / `load_with_default_open` at 544–553).

Nothing was taken from memory; every load-bearing claim below
carries a verified body citation.

## 1. Current state (verified)

- `show` (`src/ui/skills.rs:313`) is
  `show(ui, state, sde)` — no `PortraitImageCache`, no prune
  call — and the shell dispatch passes none
  (`src/app/shell.rs:3772`), unlike Dashboard, Characters,
  Assets, Market, and Fittings, which all receive
  `&mut self.portrait_textures` (3764–3794) and prune at their
  tops. `show` has exactly one call site (`shell.rs:3772`;
  verified by search this session). Section 5 locks the same
  wiring the asset-icons slice added.
- The catalogue renders only in the `Ready` branch, after the
  training queue: heading at 405, `search_box` into
  `state.skill_search` at 406–415, the query clone at 416, the
  trained-levels map from the `Ready` bundle at 417–422, and
  an empty-groups panel at 423–425. Inside its own
  `ScrollArea` (`skill_catalogue_scroll`, `max_height` 320, at
  426–429; itself nested in the shell-wide outer scroll at
  `src/app/shell.rs:3758`) it loops `sde.groups` in bundled
  file order, then `sde.types` filtered by `group_id` in file
  order, then `widgets::matches_search(&skill.type_name,
  &query)` (`src/ui/widgets.rs:206-208`: empty needle matches
  everything, else case-insensitive substring). There is no
  pre-filter pass and **no render cap anywhere in
  `skills.rs`** — no `RENDER_MAX`, no `take` — unlike the
  shipped caps in assets, fittings, industry, and exploration.
  The catalogue is provably unbounded today.
- **Blocking fact 1 — rows discard `type_id`.** Per group the
  view first builds `rows: Vec<String>` (432–443): one
  `"{type_name} — trained level {level}"` per match (439) plus
  an optional `prerequisite_line` `"Requires: …"` (440–442).
  Only display strings survive. Section 5 locks the
  carry-through, the same move asset-icons made for
  `AssetRow.type_id`.
- Rows render inside
  `CollapsingHeader::new(&group.group_name)
  .default_open(!query.is_empty()).show(...)` (447–453), each
  a bare `ui.label(row)`. Collapsing state therefore **exists
  here**, unlike assets (asset-icons section 2 rejected its
  expanded-groups option because no collapsing state existed
  anywhere in `assets.rs`). Verified egui 0.29.1 semantics:
  `show_body_unindented` returns `None` without calling the
  body closure when openness is at or below 0
  (`collapsing_header.rs:191-199`), so code inside the body
  genuinely does not run while a group is collapsed; and
  `default_open` applies only before the header's state is
  first stored — `begin` loads stored state via
  `load_with_default_open` and toggles only on an explicit
  `open(Some(_))` or a header click (544–553). So an empty
  search renders every group collapsed on the first frame,
  but typing a query later does **not** force stored-collapsed
  groups open. That is today's shipped catalogue behaviour,
  and section 2 locks explicitly that this slice does not
  change it.
- **Counts, scripted this session from
  `assets/sde/skills.json`:** 495 types (495 distinct
  `typeId`, all positive, minimum 2403), 24 groups, 1 category
  (16, "Skill"). File-order groups begin Gunnery 65, Missiles
  31, Spaceship Command 88, Fleet Support 18; the largest
  group is Spaceship Command at 88. 466 of the 495 skills
  carry prerequisites (the `sde.rs` test pins 749 total edges
  and 466 with edges at lines 269–276), so a fully expanded
  catalogue builds 961 label rows (495 skill + 466
  `Requires:`) of which only the 495 skill rows could ever
  carry an icon. Broad-search matches under `matches_search`:
  `"e"` 447, `" "` 447. Honest worst case today: all 24
  groups expanded puts 495 skill rows (961 labels) in one
  frame; the largest single-group burst is 88.
- The shipped type-icon pipeline already implements everything
  a catalogue row icon needs except authorization and wiring:
  `ImageKind::Type` with cache file `type-{id}_{size}.png`
  (`src/portraits.rs:106`), `TYPE_ICON_SIZE = 64` (`:60`;
  3.3–6.7 KB per icon per the probe note at 54–60), cache-first
  fetch (`:420-446`), the fetch-size arm in the shell drain
  (`src/app/shell.rs:2270`), texture name `type-{id}`
  (`src/ui/portraits.rs:138`), and one app-wide semaphore
  `MAX_CONCURRENT_FETCHES = 4` (`src/portraits.rs:72`).
  `ensure_type_icon_requested` queues only a `NotRequested`
  key (`src/ui/portraits.rs:208-210` via `ensure_logo_requested`
  at 189–199, which also refuses non-positive ids silently).
- The single fetch guard `AppState::image_id_known`
  (`src/app/state.rs:1324-1349`) admits `Type` today through
  exactly three loaded-state arms (1343–1347):
  `fitting_type_known` (1357–1367), `asset_type_known`
  (1373–1377), or `market_selected_type_id == Some(id)`. Four
  sites share that guard and nothing else: `request_portrait`
  (1420–1427), the shell drain re-check
  (`src/app/shell.rs:2249-2256`), the landing check in
  `apply_portrait_landing` (`src/app/shell.rs:458-460`), and
  texture `prune` (`src/ui/portraits.rs:78-88`). All four take
  `AppState` (or state derived from it) and nothing else.
- `Sde` lives on `MimirApp` (`pub sde: Sde`,
  `src/app/shell.rs:125`), loaded once in `MimirApp::new`
  (845–848, falling back to `Sde::default()` — empty — on load
  failure) and passed to views by reference. `AppState`
  (687–728) has no `sde` field and no skill-catalogue id set.
  Catalogue membership is therefore not consultable by any of
  the four guard sites today. Section 3 prices this.
- Demo installs `skills = LoadState::Ready(...)` from bundled
  data (`src/demo/data.rs:1106-1109`), and the portrait drain
  suppresses every spawn kind-agnostically in demo
  (`decide_portrait_start`, `src/app/shell.rs:379-387`, applied
  at 2217–2223; pinned by the shipped decision-table test at
  4422–4426). Section 5 covers demo under the new ensure.
- **Unprobed, stated plainly:** no body read this session proves
  all 495 bundled skill types return an icon at
  `types/{id}/icon`. The Flutter app shipped a skill icon widget
  against that URL shape for every catalogue skill (retired at
  `ed698d3`; discovery read those bodies), which is precedent,
  not a 495-id probe. Section 3 locks what the design does
  about that gap: accept it, in exactly the shipped
  fittings/assets form.

## 2. The volume bound (locked)

Four mechanisms were considered; this section locks one on
evidence. If none had been honest, this design would ship
nothing. One hybrid is honest, and both of its halves use
mechanisms that already exist in bodies.

**Option D — no bound (ensure every matching row). Rejected.**
Worst case: 495 distinct fetches from one view (all groups
expanded, section 1), about 2.4 MB of image traffic and up to
495 × 16,384 bytes ≈ 7.7 MiB of GPU textures queued behind the
4-fetch semaphore because the user opened a list. The
all-collapsed first frame does not save it: any one group
opening bursts up to 88, and nothing stops the walk to 495.

**Option C — `ScrollArea::show_rows` virtualization. Rejected
for this slice**, for the same three reasons asset-icons
section 2 recorded, each re-verified here: rows are
non-uniform (group headers, skill rows, and `Requires:` lines
interleave, `src/ui/skills.rs:432-453`), so the view would
have to flatten into fake uniform rows; the catalogue scroll
is already nested inside the shell's outer scroll
(`src/app/shell.rs:3758`); and, load-bearing, virtualization
bounds widgets per frame but **not** fetches per session —
scrolling through the catalogue still ensures all 495 over
time. A per-frame bound presented as a fetch bound would be
dishonest.

**Option B — expanded-groups-only, no numeric cap. Rejected
as the sole bound.** It is real here — ensures inside the
collapsing body closure queue nothing while collapsed
(section 1, `collapsing_header.rs:191-199`) — but its worst
case is still 495: expand all 24 groups, or arrive with a
broad query (`"e"` matches 447) whose groups default-open on
first store. It bounds the *accidental* burst, not the worst
case, and this slice's rule is that the worst case is stated
and bounded, not merely unlikely.

**Option A+B — a global rendered-row cap inside the expanded
bodies (the locked shape).** Mirror the shipped global cap —
`ASSETS_RENDER_MAX = 100` (`src/ui/assets.rs:16`, global
across groups with a remaining budget and one disclosure
label; asset-icons section 2 rejected a per-group cap because
group count is itself unbounded there) — and keep the ensure
inside the collapsing body, so collapsed groups consume no
budget and queue nothing. Each half covers the other's hole:
the cap bounds the all-expanded worst case the headers alone
allow; the headers mean the common first frame (empty search,
all collapsed) renders and ensures zero skill rows instead of
spending 100 fetches nobody asked to see.

Locked mechanism, in `src/ui/skills.rs`:

```rust
pub const SKILLS_CATALOGUE_RENDER_MAX: usize = 100;
```

In the catalogue `ScrollArea` closure, groups and skills keep
their existing order (bundled file order; search filter
applied per skill before anything counts, exactly as today):

- `total_filtered` counts skill rows matching the query
  across all groups (skill rows only; `Requires:` lines never
  count). The per-group row build already walks every match,
  so the count is free.
- A single `remaining` budget starts at
  `SKILLS_CATALOGUE_RENDER_MAX`. It is consumed **inside**
  each `CollapsingHeader` body, one per skill row actually
  rendered. A group whose body never runs (collapsed, or no
  matches so no header at all, as today at 444–446) consumes
  nothing. A skill row reached with `remaining == 0` renders
  nothing — no icon, no label — and neither does its
  prerequisite line: a `Requires:` line renders only
  immediately after its own rendered skill row (section 5),
  so the cap can never orphan a prerequisite under the wrong
  skill.
- When the budget actually suppresses a skill row inside an
  open body, after the group loop draw exactly one disclosure
  label: `"Showing 100 of {total_filtered} skills."` (the
  fittings/assets wording shape, with the shown count
  `total_filtered.min(SKILLS_CATALOGUE_RENDER_MAX)`; suppression
  can only happen after exactly 100 rows rendered, so the
  shown count is honest). Rows hidden merely because their
  group is collapsed are **not** cap suppression and draw no
  disclosure: the user controls the headers, and claiming the
  view "shows 0 of 495" on first open would misdescribe the
  shipped collapsing behaviour.
- The icon ensure lives inside the same budget check that
  draws the row (section 5), so the ensure set equals the
  rendered set by construction.

**The persistence choice, locked:** rely on egui's stored
collapsing state exactly as shipped (section 1). This slice
adds no force-open on query change. Rationale: force-opening
on a broad query is precisely the burst the cap then has to
absorb, it changes catalogue UX beyond icons, and the current
behaviour (results inside a stored-collapsed group wait for a
click) predates this slice and is not made worse by it. A
search-UX change wants its own design (section 8).

What the bound does and does not claim, plainly:

- Per frame: at most 100 skill rows render, at most 100 icon
  ensures run, each queueing at most once per load of its key
  (`ensure` queues only `NotRequested`; `request_portrait`
  dedupes). At the shipped 64-pixel fetch (3.3–6.7 KB per
  icon), one full window is at most about 0.7 MB of image
  traffic, at most 4 of it in flight at once.
- Per session: at most **495** distinct skill icons can ever
  fetch — the whole bundled catalogue — and only if the user
  explicitly renders every one of them across expansions and
  searches. Each fetch happens because its row was on screen,
  never from a background walk. That 495 ceiling, about
  1.6–3.3 MB on disk and about 7.7 MiB of GPU textures if all
  are retained (section 4 locks that retention), is the honest
  worst case of this surface. It is roughly 1.9% of the
  25,818-id fittings-catalogue flood the type-icons design
  refused (about 129 MB disk, about 408 MiB GPU at the same
  per-icon constants).
- First frame, empty search: 0 rows, 0 ensures, 0 fetches.
  Largest single user action: expanding Spaceship Command
  ensures at most 88 (its full group), inside the cap.

## 3. The guard verdict (locked): ship a static bundled-data arm

The type-icons design rejected catalogue membership as the
fittings guard for three stated reasons
(`docs/type-icons-design.md:350-359`, re-read this session).
Each is answered for **this** surface from bodies. The verdict
differs from fittings on provenance and volume only. It does
not differ on plumbing, and this design does not pretend
otherwise.

**(a) Plumbing — applies identically; paid, not argued away.**
"The catalogue lives on `MimirApp`, not in the `AppState` the
guard, drain, landing, and prune all consult, so it would need
new plumbing through all four." True here verbatim: `Sde`
sits on `MimirApp` (`src/app/shell.rs:125`), `AppState` has no
skill set (section 1), and all four sites consult only
`AppState`. Section 4 pays this cost in the cheapest honest
form: a copied set of the 495 bundled skill type ids installed
into `AppState` once at startup, so the four sites, their
signatures, and every existing call site stay byte-identical.
(The same copy trick would mechanically work for the
25,818-id fitting-types catalogue too. It was not the plumbing
that made fittings dishonest; reasons (b) and (c) were, and
they still bar that change. Section 8 keeps it excluded.)

**(b) Membership does not imply an icon exists — weakens,
does not vanish; accepted in shipped form.** For fittings,
blueprint types return 400 and SKIN types 404 (type-icons
probes), and those types sit in ordinary fitting rows. Here
every catalogue row is category 16, "Skill" (section 1), and
the retired Flutter app fetched `types/{id}/icon` for skill
catalogue rows as its normal path. But no body read this
session probes all 495 ids (section 1, named unprobed), so
this design does **not** claim every skill has an icon. It
claims the shipped failure shape is acceptable and already
tolerated on three surfaces: an icon-less type's fetch fails,
its key stays `Failed`, the render path never re-queues a
`Failed` key (`src/ui/portraits.rs:201-210`), and the row
shows the blank faint-background box beside the resolved
skill name forever (`show_logo`, `:265-283`) — never a
fabricated mark, never a retry storm, at most one failed
request per icon-less skill per app run. Fittings and assets
rows already live with exactly this for blueprint and SKIN
types.

**(c) User-typed provenance — fully distinguishes.** For
fittings, catalogue membership "would authorize all 25,818
ids including ids derived from pasted import text, which is
exactly the user-typed source the standing rules exclude":
the fitting-types catalogue resolves pasted EFT/DNA text into
type ids, so a catalogue guard launders pasted input into
fetch authorization. No such path exists here, verified in
bodies: catalogue rows iterate the bundled `sde.types`
filtered by group (`src/ui/skills.rs:433`); the only user
input in the surface, `state.skill_search`, is consumed
solely by `matches_search` as a substring filter over bundled
names (434) and is never parsed as, or resolved to, an id;
and there is no paste, import, or free-text path anywhere
that turns user text into a skill type id for this view (the
one other catalogue consumer in the file, the skill-plan
picker at 902–996, also only filters `sde.types` —
`Sde::search_skills`, `src/names/sde.rs:181-191` — and is out
of scope regardless, section 8). The set of ids this arm can
ever authorize is fixed at compile time by the bundled
extract: 495 ids the app shipped with, not ids any input can
add to. Search text can choose **which** bundled rows are
visible — the same visibility choice `assets_search` and
`fittings_search` already make on shipped icon surfaces — but
it cannot name a fetch target. That is the whole distinction,
and it is structural, not a matter of degree.

**No loaded-state alternative exists for this surface.** The
catalogue renders all 495 bundled skills beside a trained
level that defaults to 0 for untrained skills
(`src/ui/skills.rs:438`). Trained ids live in ESI-loaded
`state.skills`, but a trained-only guard structurally cannot
authorize the untrained majority of catalogue rows, so
"loaded-state only" does not mean a smaller icon set here —
it means no icons for most of the surface, which is the
ship-nothing outcome under another name. The honest choice is
binary, and this design takes the arm with (a) paid, (b)
accepted in shipped form, and (c) absent by construction.

**The contract narrowing, stated in the open.**
`image_id_known`'s doc today defines known as "names an
entity this state knows from EVE's own data"
(`src/app/state.rs:1310-1323`), and type-icons section 5.2
locked prune lifetime as "not catalogue-static" — for the
25,818-id fittings catalogue. This slice narrows that
contract for exactly one enumerated subset, the 495 bundled
skill types, and section 4 rewrites the doc to say so. A
future surface that wants catalogue authorization must re-run
this section's three answers for its own catalogue; the
skills arm is not precedent by analogy (section 8).

## 4. Guard shape (exact), prune lifetime, removal

**Plumbing: a copied id set in `AppState`, installed once.**
Threading `&Sde` through `image_id_known`, `request_portrait`,
the drain, the landing, and `prune` would change every
signature and call site of the shipped pipeline, including
views this slice does not touch. Copying the id set changes
none of them. In `src/app/state.rs`:

- One new `AppState` field beside `portraits` (727–728),
  documented as state-only (never rendered, never logged as a
  list; ids appear only in the shipped `[PORTRAIT]` lines):

```rust
pub skill_catalogue_type_ids: std::collections::HashSet<i64>,
```

  `AppState` derives `Default` (687) and `HashSet` defaults
  empty, so `AppState::new` (836–857) and every existing test
  fixture authorize **no** skill types until installation —
  the safe direction, and the property section 7 pins.
- One installer, beside `image_id_known`, taking the already
  loaded `Sde` (`state.rs` gains
  `use crate::names::sde::Sde;` beside its existing
  `crate::names::exploration_ref` import at line 16;
  `sde.rs` depends only on `crate::error`, so no cycle):

```rust
pub fn install_skill_catalogue_type_ids(&mut self, sde: &Sde) {
    self.skill_catalogue_type_ids =
        sde.types.iter().map(|t| t.type_id).collect();
    tracing::info!(
        "[SKILLS] skill catalogue guard installed count={}",
        self.skill_catalogue_type_ids.len()
    );
}
```

  (Count only — the `[SKILLS] SDE loaded skills=…` precedent
  at `src/names/sde.rs:97-103`; no id list in logs.)
- One call site: `MimirApp::new`
  (`src/app/shell.rs:838-963`), immediately after
  `let mut state = AppState::new(demo);` (851) and beside the
  exploration load at 852–855 — the same "bundled, loaded once,
  identical in demo and live modes, independent of characters
  and network" precedent its comment states. `sde` is in scope
  there (845). Because installation precedes
  `seed_demo_state` (933) and the demo path never replaces the
  field, demo is covered with no demo-specific code. If the
  bundled SDE failed to load, `sde` is `Sde::default()`
  (847), the installed set is empty, the catalogue already
  renders its unavailable panel (`src/ui/skills.rs:423-425`),
  and the arm authorizes nothing — failure degrades to
  today's text-only surface, never to a wider guard.
- `Sde` itself is unchanged. `Sde::contains`
  (`src/names/sde.rs:118-120`) already expresses membership,
  and the installer reads the public `types` field (75); no
  new `Sde` API is added for one call site.

**The arm.** A new private helper beside `asset_type_known`
(1369–1377). Do **not** widen any existing helper; unions
live only in `image_id_known` and the removal retain, per the
market/asset precedent:

```rust
/// Whether this item type is one of the bundled skill
/// catalogue's skill types (installed once at startup from
/// the SDE extract). Static bundled data, deliberately not
/// character state: the skills catalogue renders bundled
/// types no loaded state names (untrained skills), and no
/// user input can add an id to this set — the catalogue
/// search only filters bundled rows by name.
fn skill_catalogue_type_known(&self, id: i64) -> bool {
    self.skill_catalogue_type_ids.contains(&id)
}
```

The `Type` arm (1343–1347) becomes the 4-way union, nothing
else in the guard body changes:

```rust
ImageKind::Type => {
    self.fitting_type_known(id)
        || self.asset_type_known(id)
        || self.market_selected_type_id == Some(id)
        || self.skill_catalogue_type_known(id)
}
```

Doc fixes, each in its file owner's commit (section 6): the
`image_id_known` doc (1310–1323) gains, for `Type`, "or one
of the bundled skill catalogue's skill types (static bundled
data installed at startup; the one non-loaded-state source,
locked by the skill-icons design section 3)"; the
`fitting_type_known` doc (1351–1356) gains "the bundled skill
catalogue" in its not-consulted list so it stays literally
true; the `ensure_type_icon_requested` doc
(`src/ui/portraits.rs:201-207`) gains the skill-catalogue
source. `fitting_type_known` and `asset_type_known` bodies
are unchanged; the same number under `Character`,
`Corporation`, `Alliance`, or `Faction` is exactly as known
or unknown as today.

**Prune lifetime: catalogue-static, app lifetime — the
deliberate break, bounded and stated.** Because membership
never changes after startup, `prune`
(`src/ui/portraits.rs:78-88`, unchanged) retains every fetched
skill icon texture for the app's lifetime, across character
switches, view changes, and search changes. Quantified worst
case (section 2): 495 textures × 16,384 bytes (64×64 RGBA)
≈ 7.7 MiB GPU, 495 `Ready` images in `AppState::portraits`,
about 1.6–3.3 MB of disk cache — fixed by the shipped
catalogue, not by anything the user or ESI can grow at
runtime. This inverts the shipped character-keyed lifetime
for this subset only, and it is what makes the surface
non-thrashing: collapsing a group, switching character, or
re-filtering never drops and re-uploads a skill texture.
Two characters, or a character and the market selection,
sharing one `(Type, id)` image remains correct: the image
names the skill type, not the character (the union is an OR).

**Removal retain must mirror the arm**, or any
`remove_character` would drop every skill icon from state,
contradicting the static premise and re-uploading on return.
Mirror the shipped captures (`src/app/state.rs:1132-1158`):
before the retain closure, capture
`let skill_catalogue_type_ids: Vec<i64> =
self.skill_catalogue_type_ids.iter().copied().collect();`
beside `asset_type_ids` (1149–1153), and extend the closure's
`Type` arm (1175–1179) with
`|| skill_catalogue_type_ids.contains(&id)`. The closure
already retains both `portraits` and `portrait_requests`
(1181–1183), so one arm covers both. **The one lifetime
exception, inherited and stated:** removing the last
character clears all portrait state wholesale (1253–1255),
skill icons included. This slice does not special-case it:
with no characters the Skills view renders its no-character
panel and ensures nothing, and when a character returns, the
re-fetch is cache-first from disk (`src/portraits.rs:420-446`)
with no network for previously fetched icons.

**Character-keyed validity: deliberately none.** Switch,
same-id reselect, and non-last removal never revoke a skill
id: a fetch queued before a switch still spawns at drain
(re-check passes, `src/app/shell.rs:2249-2256`) and still
lands after it (458–460). That is correct here and would be a
bug on the other arms — the catalogue is identical under
every character, so there is no stale owner to protect. The
inherited stuck-`Loading` wart of the character-keyed arms
(a landing dropped as unknown leaves the key `Loading`,
recorded in asset-icons section 4) therefore cannot occur
through character operations on this arm; only the
last-character clear drops the entry, and it drops the queue
with it, so re-ensure after a character returns works.

Trace, end to end (skill type X is a bundled catalogue skill,
untrained, in no saved fitting, not held, not
market-selected — the case only this arm covers):

1. **Startup.** `MimirApp::new` loads the SDE and installs
   the 495-id set. No fetch has run; authorization is not
   requesting.
2. **First Skills frame, empty search.** `Ready` renders the
   queue and 24 collapsed group headers. Zero ensures
   (section 2). X fetches nothing.
3. **Expand X's group.** The body runs; X's row is inside the
   budget, ensure queues `(Type, X)` (`NotRequested` →
   `Loading`, one key). The drain re-check passes via the
   catalogue arm, spawns at `TYPE_ICON_SIZE` under the
   4-fetch semaphore, cache-first. The landing inserts
   `Ready` because the guard holds at apply time; the texture
   uploads once (`Arc::ptr_eq`,
   `src/ui/portraits.rs:120-123`). Before landing, and
   forever if the fetch fails (section 3b), the row shows
   the blank box beside X's bundled name.
4. **Switch character.** Nothing revokes X (above). The new
   character's Skills view shows X's icon immediately — no
   refetch, no re-upload — beside the new character's trained
   level for X. The level text is character state; the icon
   is type art. Both are correct.
5. **Remove a character (not the last).** The retain mirror
   keeps `(Type, X)` in both maps; the guard still reads
   true; prune keeps the texture. Removing the last
   character clears all portrait state (the stated
   exception); the disk cache still holds X's PNG.
6. **Demo.** The same installed set authorizes, ensures under
   an open group queue keys, and `decide_portrait_start`
   refuses every spawn (section 1): keys stay `Loading`,
   blank boxes render, zero network. Demo entered at runtime
   (`seed_demo_state`, `src/app/shell.rs:3720`) reuses the
   same `AppState`, so the installed set is already there.

## 5. Row layout, ensure sites, shell wiring, demo, logs

**Render size: `TYPE_ICON_PX = 20.0`, reused, no new
constant** (`src/ui/portraits.rs:36-41`: dense list rows,
left of the resolved name — the fittings and assets row
shape). The retired Flutter catalogue drew its skill icons
at 32; the shipped Rust row precedent is 20 across three
surfaces, catalogue rows here are if anything denser (paired
`Requires:` lines), and fetch 64 → render 20 keeps the
shipped downscale. `MARKET_TYPE_ICON_PX` is a detail header,
not a row, and is not reused.

**Row carry-through.** The per-group `rows: Vec<String>`
(`src/ui/skills.rs:432-443`) becomes rows that remember which
lines are skills:

```rust
struct CatalogueRow {
    /// `Some` for a skill row (icon + name), `None` for its
    /// prerequisite line (text only). State-only: never
    /// formatted into a rendered string, never logged.
    skill_type_id: Option<i64>,
    text: String,
}
```

(private to `src/ui/skills.rs`). The build loop pushes
`Some(skill.type_id)` with the existing
`"{type_name} — trained level {level}"` string byte-for-byte,
then `None` with the existing `prerequisite_line` string.
`total_filtered` (section 2) increments once per `Some` push
across all groups. The empty-group skip (444–446) is
unchanged in effect (no matches ⇒ no rows ⇒ no header).

**Row layout.** Inside the collapsing body, per row in order,
under the section 2 budget:

```rust
// skill row, only while remaining > 0 (then remaining -= 1):
ensure_type_icon_requested(state, type_id);
ui.horizontal(|ui| {
    show_type_icon(ui, cache, state, type_id, TYPE_ICON_PX);
    ui.label(&row.text);
});
// prerequisite row: plain label, only when its skill row rendered
ui.label(&row.text);
```

Label strings are the current ones unchanged; `type_id` is
never formatted — the bundled skill name in the text carries
the meaning, per the module doc's promise
(`src/ui/skills.rs:1-2`). The placeholder for every
non-`Ready` state is the `show_logo` blank box in the same
20-point slot, so rows never change height as icons land.
Prerequisite lines get **no** icon: a `Requires:` line names
several skills in one string, and inventing per-prerequisite
icons is a different surface (section 8).

**Ensure sites: exactly one, rendered rows only by
construction.** The single `ensure_type_icon_requested`
above, inside the collapsing body, inside the budget check,
in the `Ready` branch only. No ensure in the queue rows
(363–400), none in `Loading`/`Empty`/`Error` (460–467), none
in collapsed bodies, none for capped-off rows, none in the
plans section or its picker (`show_plans_section`,
`show_skill_picker` — neither gains the cache parameter), no
prefetch anywhere. Queue-row and picker icons are separate
decisions (section 8).

**Wiring, point by point:**

- `src/ui/skills.rs::show` gains
  `cache: &mut PortraitImageCache` after `sde`. It calls
  `cache.prune(state)` immediately after
  `widgets::mode_notice` (315) and **before** the
  no-character return (316–319), mirroring Fittings and
  Market, so textures prune even on frames that render no
  rows. (For skill icons prune is normally a no-op by design
  — section 4 — but the Skills view must still prune the
  other kinds' textures it shares the cache with when it is
  the first pruning view visited after a switch, exactly as
  every other icon view does.)
- `src/app/shell.rs` dispatch: the `View::Skills` arm (3772)
  becomes
  `ui::skills::show(ui, &mut self.state, &self.sde, &mut self.portrait_textures)`.
  `show`'s only call site (section 1), so no other caller
  changes. The view stays inside the existing outer scroll;
  the catalogue keeps its own inner scroll. No new scroll
  area.
- `src/app/shell.rs::MimirApp::new`: the one installer call
  (section 4). No other shell change except B's landing test
  (section 6).
- `src/ui/portraits.rs`: only the `ensure_type_icon_requested`
  doc fix (section 4). Signatures unchanged.
- Untouched: `src/portraits.rs`, `src/config.rs`,
  `src/names/sde.rs` (no new API, section 4), `src/esi/`,
  `src/demo/data.rs` and `assets/demo/`,
  `src/ui/fittings.rs`, `src/ui/market.rs`,
  `src/ui/assets.rs`.

**Demo: zero network, no change needed.** Demo skills are
`Ready` from bundled data (section 1), the catalogue is the
same bundled SDE, ensures queue only for opened rows inside
the cap, and the kind-agnostic drain refusal suppresses
every spawn. Demo catalogue rows render the blank box
forever, like demo fittings, asset, and market rows today.
No demo-specific guard, no fixture edit.

**Logs: no new per-frame line.** The render path stays
log-free (the `src/ui/portraits.rs:12-17` convention; up to
100 rows per frame). The once-per-install `[SKILLS]` count
line (section 4) and the shipped `[PORTRAIT]` transitions —
request, drain, landing, upload, prune, each kind+id only —
are the whole log surface. No `[SKILLS]` line may gain a
`type_id` list, a skill name, or search text.

## 6. Builder split (A/B, zero file overlap) and integrator list

Two builders, file-disjoint, sharing only the locked contract:
the `image_id_known` `Type` arm is the 4-way union of section 4,
`AppState::install_skill_catalogue_type_ids(&mut self, sde: &Sde)`
exists with that exact name and signature, `CatalogueRow` carries
`skill_type_id` per section 5, and
`ensure_type_icon_requested` / `show_type_icon` /
`PortraitImageCache` keep their signatures. B's ensures queue
nothing until A's guard lands, so the integrator lands A first;
both can be authored in parallel. Each builder's tests land in
the same commit as their code (section 7 assigns every test).

- **Builder A — guard** (owns only `src/app/state.rs`):
  - The `skill_catalogue_type_ids` field, the `Sde` import,
    `install_skill_catalogue_type_ids`,
    `skill_catalogue_type_known` beside `asset_type_known`, the
    4-way `Type` union, and the two doc fixes in this file (the
    `image_id_known` clause; the `fitting_type_known`
    not-consulted list). Existing helpers' bodies unchanged.
  - `remove_character` captures `skill_catalogue_type_ids`
    beside `asset_type_ids` and the retain `Type` arm gains
    the catalogue clause (section 4).
  - A's tests (section 7, state rows) in the same commit.
- **Builder B — Skills view and shell wiring** (owns
  `src/ui/skills.rs`, `src/ui/portraits.rs`, `src/app/shell.rs`):
  - `CatalogueRow` carry-through, `SKILLS_CATALOGUE_RENDER_MAX`
    + global budget inside the collapsing bodies + disclosure
    label, cache parameter, prune-after-`mode_notice`, single
    in-budget ensure, 20-point horizontal skill rows
    (`src/ui/skills.rs`); B's skills tests there, including the
    demo queue test.
  - The `ensure_type_icon_requested` doc fix
    (`src/ui/portraits.rs`); B's prune test there.
  - The installer call after `AppState::new(demo)` and the
    `View::Skills` dispatch cache argument
    (`src/app/shell.rs`); B's landing test there. No other
    shell change.
- **Integrator** (after A then B): full four gates; confirm the
  shipped guard and prune tests pass unmodified
  (`switching_character_revokes_fitting_type_knowledge`,
  `market_selection_authorizes_only_the_selected_type`,
  `asset_holdings_authorize_only_held_types`,
  `removing_character_retains_held_asset_icon`,
  `prune_keeps_type_icon_across_selection_change`,
  `prune_keeps_selected_market_type_icon_across_switch`,
  `prune_keeps_held_asset_type_icon_within_one_load`,
  `market_type_icon_landing_drops_after_deselect`,
  `asset_type_icon_landing_drops_after_switch`,
  `assets_show_queues_icons_for_rendered_rows_only`); confirm
  the shipped `image_id_known` kind-isolation behaviour is
  unchanged for `Character`/`Corporation`/`Alliance`/`Faction`;
  journal entry in `docs/engineering-journal/`; no merge or
  push.

Explicitly untouched by both: `src/portraits.rs`,
`src/config.rs`, `src/names/sde.rs`, `src/esi/`,
`src/demo/data.rs`, `assets/demo/`, `src/ui/fittings.rs`,
`src/ui/market.rs`, `src/ui/assets.rs`.

Every commit passes the four gates; the clippy gate includes
`--all-targets` (a prior slice shipped test-code lints by
running clippy without it).

## 7. Test plan (all expectations literal)

Fixture ids, verified against the bundled extract this session
(section 1): `3300` is the bundled skill "Gunnery" (first type
in file order; also pinned by `src/names/sde.rs:202`), `3329`
("Minmatar Frigate") is the 100th type in the view's
file-order walk, `30650` ("Amarr Strategic Cruiser", walk
position 151, the unique match for its own name) sits beyond
the cap, `34` is not a bundled skill type, and `999999` is in
no catalogue. Guard table — every row is
`image_id_known(ImageKind::Type, id)` unless named:

| Setup | Expectation |
|---|---|
| Catalogue installed from bundled SDE; nothing else loaded | `3300` true; `request_portrait(Type, 3300)` queues exactly `[(Type, 3300)]`, state `Loading` |
| Same setup | `34` false and `999999` false; requesting either queues nothing, no entry created |
| `AppState::default()` (nothing installed) | `3300` false; requesting it queues nothing |
| `skill_search = "3300"`, nothing installed | `3300` false (search text never authorizes, numeric or not) |
| Installed; `skills` `Ready` with an empty trained list | `3300` true (trained state is not the source) |
| Installed, then `set_active_character` to another character | `3300` stays true (static arm; contrast the assets row in `switching_character_revokes_asset_type_knowledge`-shape tests) |
| Installed | `image_id_known(Character, 3300)` false with no character rows (kind isolation) |
| `request_portrait(Type, 0)` / negative, installed | queues nothing (non-positive pre-check) |

Tests, by owner (names locked; expectations literal):

- **A, `src/app/state.rs`**
  `skill_catalogue_membership_authorizes_only_bundled_skill_types`
  pins the table's membership rows: install from
  `Sde::load_bundled()`; assert the installed set's length is
  `495`; `3300` true and queues exactly `[(Type, 3300)]` once
  (a second request queues nothing more); `34` and `999999`
  false with queue and `portraits` unchanged; a fresh default
  state reads `3300` false; `skill_search = "3300"` alone
  reads false; `(Character, 3300)` false; `request_portrait`
  with `0` and `-1` queues nothing. Mirrors
  `asset_holdings_authorize_only_held_types` (line 3475).
  `skill_catalogue_knowledge_survives_character_switch`: two
  character rows, installed set, `3300` `Ready`; switch to the
  other character and assert `3300` still true and the `Ready`
  entry untouched; same-id reselect also true. Mirrors
  `switching_character_revokes_fitting_type_knowledge` (line
  3286) with the opposite locked expectation — the test name
  and a comment must say the survival is the design, not an
  oversight.
  `removing_character_retains_skill_catalogue_icon`:
  two-character fixture (the last-removal branch clears all
  portraits at 1253–1255 and must not be the fixture), `3300`
  `Ready` plus a queued `(Type, 3300)` request; removing the
  non-active character keeps both; then removing the active
  character still keeps both **and** `image_id_known(3300)`
  still reads true afterwards (static arm, unlike the assets
  retain test at 3559 where the guard reads false after
  active removal). Also pin the stated exception in the same
  test: after removing down to zero characters, `portraits`
  and `portrait_requests` are empty while the installed set
  still has length `495`.
- **B, `src/ui/skills.rs`**
  `skills_catalogue_render_max_is_100`:
  `SKILLS_CATALOGUE_RENDER_MAX == 100` (the fittings/assets
  precedent).
  `skills_show_queues_icons_for_rendered_rows_only`: headless
  render mirroring `assets_show_queues_icons_for_rendered_rows_only`
  (`src/ui/assets.rs:499`) and
  `market_header_runs_headless_and_queues_one_type_icon`
  (`src/ui/market.rs:912`). Fixture: `Sde::load_bundled()`, an
  active character installed, catalogue ids installed into
  state, `skills = Ready` with an empty trained list and
  empty queue; a **fresh `egui::Context` per scenario** (stored
  collapsing state must not leak between cases — section 1).
  Cases, in order: no active character ⇒ queue empty (the
  no-character panel returns before the catalogue); empty
  `skill_search` ⇒ exactly `0` queued (all groups collapsed on
  first store — the expanded-only half of the bound);
  `skill_search = "e"` ⇒ exactly `100` queued `(Type, id)`
  requests, all distinct, including `(Type, 3300)` and
  `(Type, 3329)`, excluding `(Type, 30650)`, cache empty
  (blank-box path), and a second frame queues nothing new —
  100 is also the proof that the 466 `Requires:` lines and
  collapsed/capped rows ensure nothing, and that the budget is
  global (a per-group budget would queue hundreds here);
  then `skill_search = "Amarr Strategic Cruiser"` ⇒ exactly
  one additional queued key, `(Type, 30650)`
  (filter-before-cap reveals a beyond-cap row). A `Failed`
  catalogue icon never re-queues: seed `(Type, 3300)` as
  `Failed` in the `"e"` scenario variant and assert the queue
  holds the other `99` keys and not `3300`.
  `skills_demo_queues_catalogue_types_but_never_ready`,
  mirroring `assets_demo_queues_held_types_but_never_ready`
  (`src/ui/assets.rs:670`): `seed_demo_state` plus catalogue
  installation, `skill_search = "e"`, fresh context; a headless
  `show` queues exactly `100` distinct `(Type, id)` keys,
  uploads nothing, and no key is `Ready`;
  `decide_portrait_start(true, _) == Some(Demo)` is already
  pinned by the shipped decision-table test
  (`src/app/shell.rs:4422-4426`), so no spawn can follow. No
  demo fixture edit.
- **B, `src/app/shell.rs`**
  `skill_type_icon_landing_survives_character_switch`,
  mirroring `asset_type_icon_landing_drops_after_switch` (line
  4847) with the opposite locked outcome: installed state with
  two characters; landing `Ok(test_image(8, 8))` for `3300`
  returns true and `Ready` is 8×8; after switching the active
  character, landing `3300` at 4×4 still returns true and the
  image is replaced (the guard never revoked it); landing
  `999999` returns false before and after the switch and
  writes nothing.
- **B, `src/ui/portraits.rs`**
  `prune_keeps_skill_catalogue_type_icon_across_switch`,
  mirroring `prune_keeps_selected_market_type_icon_across_switch`
  (line 929): `3300` `Ready` uploads once; prune keeps the same
  texture handle across a character switch and across a
  `skill_search` change; prune against a state with nothing
  installed drops the texture (guard loss is the only drop
  path). Assert same handle id and unchanged cache length —
  no re-upload.
- No widget-text harness is invented for the disclosure label:
  its wording is locked in section 2 and verified by the
  queue-count tests above plus code review, the same standard
  the shipped caps meet.

## 8. Exclusions (follow-ups, each needs its own design)

- **Skill-plan picker icons.** `show_skill_picker`
  (`src/ui/skills.rs:902-996`) lists the same bundled types
  with no cap and its own search field. The guard arm this
  design installs would authorize picker ensures the moment
  anyone adds one, so this exclusion is load-bearing, not
  cosmetic: picker icons need their own volume bound (its
  result list is uncapped and sorted differently) decided in
  their own design. This slice adds no ensure there and does
  not pass it the cache.
- **Training-queue row icons, plan-entry icons, and
  per-prerequisite icons.** Queue rows name ESI-loaded skill
  ids (a loaded-state source), plan entries and prerequisite
  lines name bundled ones; each surface needs its own guard
  reading and row budget. Flutter drew queue icons at 20, but
  precedent is not a design.
- **Generalizing the catalogue arm.** The fitting-types
  catalogue (25,818 ids), the name resolver's cache, and any
  other bundled catalogue remain barred as guard sources: the
  type-icons rejection stands for them on reasons (b) and (c)
  (section 3). The skills arm authorizes exactly the ids
  installed from the bundled skill extract at startup —
  nothing widens it at runtime, and no second catalogue joins
  it without re-running section 3.
- Force-opening collapsing groups when the query changes, a
  raise of `SKILLS_CATALOGUE_RENDER_MAX`, sorting the
  catalogue (today: bundled file order), `show_rows`
  virtualization (section 2), a probe or allowlist of which
  of the 495 skills have icons, a retry affordance for a
  `Failed` icon, and any eviction policy for the retained
  495-texture worst case.

## 9. Revisit conditions

- A probe of the bundled 495 shows icon-less skills are
  common rather than rare (say, whole groups blank): section
  3(b)'s "accepted in shipped form" stops being honest and
  the arm needs an allowlist or removal. A handful of
  permanent blank boxes beside correct names is the accepted
  cost, as on the fittings and assets surfaces.
- The bundled skill extract stops being a closed skill-only
  set — it grows to thousands of types, gains non-skill
  categories, or starts resolving user text into ids. Each
  breaks a load-bearing section 3 fact (closed 495, category
  16 only, filter-only search); the guard verdict must be
  re-derived before the extract change ships, not after.
- Real cache directories show the retained-495 worst case
  (about 7.7 MiB GPU, about 3.3 MB disk) is a practical
  problem on target hardware, making app-lifetime retention
  untenable: an eviction design must then re-derive prune
  lifetime for static arms without reintroducing the
  drop-and-re-upload thrash the generous superset exists to
  prevent.
- Users routinely expand many groups only to hit the
  100-row cap, or report search results hiding in collapsed
  groups (the locked persistence choice, section 2):
  force-open-on-query or virtualization then earns its own
  design, with the fetch bound re-derived — section 2's
  honesty requirement (bound fetches, not only widgets per
  frame) still applies.
- The skill-plan picker, queue, or any new surface wants
  skill icons: its own design, per section 8. The installed
  guard set already existing is explicitly not authorization
  to add ensures elsewhere.




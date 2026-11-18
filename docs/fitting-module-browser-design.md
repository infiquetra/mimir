# Module browser for the fitting editor — design

Status: locked for the `feat/rust-fitting-module-browser`
slice. Base: `develop` at `7ddb489` (1,038 tests; the fitting
editor slice from pull request 608 is merged there — see
`docs/fitting-editor-design.md`). Slice branch:
`feat/rust-fitting-module-browser`. This document is the single
design commit; builders and the integrator implement exactly
what is locked here and nothing else.

The editor design deferred this piece by name: "Drag and drop,
click-to-equip browsers, and any item picker or search beyond
the exact-name box" (`docs/fitting-editor-design.md` section
11). This slice ships the browser part of that deferral. Drag
and drop stays deferred (section 12).

## 1. Goal and value ranking

Let the user add an item to the imported fitting draft by
browsing instead of typing its exact name from memory: pick a
section tab, optionally narrow by a name search, and click a
row to add it. The typed exact-name box stays exactly as it is;
the browser is a second door into the same room.

Value ranking (locked, in order):

1. **Every row the browser lists is addable by construction.**
   A row appears only when the shipped catalogue data proves,
   with the editor classifier's own predicates, that clicking
   it succeeds (section 3.3). The browser never sets up a
   refusal the editor then has to deliver, except the two
   quantity outcomes on stacked tabs that no listing can
   prevent (section 6.3).
2. **One add path, one refusal voice.** A click calls the same
   pure add function with the same arguments the "Add item"
   button builds, and any refusal reaches the user through the
   same label in the same words (section 6). The browser adds
   no classification, no placement, and no wording of its own.
3. **Never guess, never fabricate.** Section membership is
   proven from dogma slot effects and category, CPU and power
   grid figures print only when the catalogue carries them,
   and a raw type number is never rendered or logged (sections
   3 and 5).

## 2. Scope: placement, tabs, and what does not ship

### 2.1 Placement (locked)

The browser renders inside `fittings_import_panel`
(`src/ui/fittings.rs:2828`), in the existing edit block, after
the add row and its refusal label (`src/ui/fittings.rs:
2973-3007`) and before the item rows (`src/ui/fittings.rs:
3008-3028`). It therefore exists exactly when the editor
exists: a draft is present, the render guard's owner check
passed (`src/ui/fittings.rs:2924-2928`), and the catalogue
loaded (`src/ui/fittings.rs:2836-2839`). With no draft there
is nothing to add to, so there is no browser. An item added
by a click appears in the item rows in the same frame because
the click is applied to the working clone before those rows
are built (section 6.1).

### 2.2 Tabs (locked set, order, labels, default)

The Flutter browser (`module_browser.dart` in the pre-rewrite
app) has four tabs — `High`, `Med`, `Low`, `Rig` — defaulting
to High. The shipped Rust editor proves more sections than
Flutter tabs: its slot adds land subsystems
(`classify_module`, `src/fitting/eft.rs:388-406`, via
category 32 and effect 3772), and its stacked adds land
drones and fighters by category (`add_stacked`,
`src/fitting/editor.rs:138-145`). Those three ship as tabs
because the editor's add paths already ground them.

Seven tabs ship, in this order, with these verbatim labels.
The first four labels and the default follow Flutter; the
last three take the shipped Rust section nouns
(`section_label`, `src/ui/fittings.rs:102-113`). Each tab is
keyed by the `ImportSection` it lists
(`src/fitting/eft.rs:59-68`):

| Label | Section | Rows in bundled catalogue |
|---|---|---|
| `High` | `ImportSection::High` | 1,371 |
| `Med` | `ImportSection::Medium` | 903 |
| `Low` | `ImportSection::Low` | 1,005 |
| `Rig` | `ImportSection::Rig` | 642 |
| `Subsystems` | `ImportSection::Subsystem` | 48 |
| `Drones` | `ImportSection::Drones` | 129 |
| `Fighters` | `ImportSection::Fighters` | 94 |

Counts are scripted from `assets/sde/fitting_types.json` at
design time under the section 3 membership rules and are
pinned by test (section 10). The default tab at every reset
is `High`, as in Flutter.

There is no Cargo tab. Cargo has no positive membership to
browse: the editor's stacked path routes a name to Cargo by
elimination — anything that is not a drone, fighter, module,
or subsystem (`src/fitting/editor.rs:138-145`). Listing that
set would offer 21,594 rows across 33 categories (blueprints,
ships, apparel, and charges among them), five times the other
seven tabs combined, under a label that promises cargo
candidates the data cannot distinguish. That is a listing
without proof, so the Cargo tab is deferred by name (section
12). Typing a cargo name with a quantity keeps working
unchanged.

### 2.3 What does not ship (locked)

- No change to the typed add row, remove, quantity, or rename
  controls; the browser is additive below them.
- No new validation. The editor admits overfilled slots today
  and discloses them in the slot layout block (editor design
  section 5.2: disclose, never block). Browser clicks inherit
  that posture exactly; there is no "no free slot" refusal to
  surface because the add path has none.
- No icons on browser rows. The imported draft's rows render
  as plain text (`render_imported_item_rows` passes no icon
  path); the browser matches the panel it sits in.
- No persistence. Browser state is view-local memory with the
  draft's lifetime (section 8).

## 3. The pure candidate builder

### 3.1 Locked surface

One pure function in `src/fitting/editor.rs`, beside the add
operations whose contract it mirrors:

```rust
pub struct BrowserRow {
    pub type_id: i64,
    pub name: String,
    pub cpu: Option<f64>,
    pub power: Option<f64>,
}

pub fn browser_candidates(
    types: &FittingTypes,
    section: ImportSection,
) -> Vec<BrowserRow>
```

`type_id` is an internal key and sort tiebreak only, never
rendered and never logged. `name` is the catalogue row's name
trimmed, exactly the text a click passes to the add path
(section 6). `cpu` and `power` copy the row's optional
need figures (`src/names/fitting_types.rs:35-38`) untouched,
so the label in section 5 can only print what the catalogue
carries.

The builder takes no search query. Search is a view concern
applied by the panel over these candidates (section 4),
which keeps this module free of any `crate::ui` dependency
and lets the panel cache candidates per tab (section 7).

### 3.2 Membership (locked predicates, in order)

For each row of `types.types` in file order:

1. **Unique normalized name.** Compute the distinct type
   numbers per normalized name with the shipped
   `normalize_type_name` (`src/names/fitting_types.rs:
   363-368`), de-duplicating by (name, type number) with
   first row in file order winning — the load index's own
   semantics (`src/names/fitting_types.rs:399-406`). A row
   lists only when its normalized name maps to exactly one
   type number. This is the predicate `FittingTypes::lookup`
   expresses as `Found` rather than `Ambiguous` or `Unknown`
   (`src/names/fitting_types.rs:420-434`), proven here without
   calling `lookup` per row (each `lookup` emits a debug log
   line; 25,818 of them per build is not acceptable). In the
   bundled catalogue 12 of 25,802 normalized names are
   ambiguous; none of them is a section member under step 3,
   so this step excludes nothing today. It is locked anyway:
   the invariant in section 3.3 must hold by construction,
   not by current data luck.
2. **Name guard.** The trimmed name must be non-empty and
   must not parse as an integer — the shipped chooser guard
   verbatim (`src/ui/industry.rs:612-615`). A purely numeric
   name would render as a raw identifier. No bundled member
   fails this guard today; it is locked for the same reason.
3. **Section proof**, the editor classifier's predicates
   exactly:
   - Slot tabs (`High`, `Medium`, `Low`, `Rig`, `Subsystem`):
     `category_id` is 7 (module) or 32 (subsystem) — the
     shipped `CATEGORY_MODULE` / `CATEGORY_SUBSYSTEM`
     constants — and `slot_section(&row.slot_effects)`
     (`src/fitting/eft.rs:361-375`, effects 12, 13, 11, 2663,
     3772 checked in that order) returns `Some(section)` for
     the requested tab. These are steps 3 and 4 of
     `classify_module` (`src/fitting/eft.rs:393-403`)
     unchanged. Slot proof without category is not enough:
     330 bundled structure-module rows (category 66) carry
     slot effects — for example Standup Anticapital Missile
     Launcher I carries effect 12 — and every one would
     refuse `NotAModule` at add time.
   - `Drones`: `category_id` is 18 (`CATEGORY_DRONE`).
   - `Fighters`: `category_id` is 87 (`CATEGORY_FIGHTER`).
   - `Cargo`: no row lists. The match stays exhaustive over
     `ImportSection` with Cargo yielding an empty list,
     recording the deferral in code; no tab ever requests it.

### 3.3 The addability invariant (decision, locked)

Decision: **every listed row adds without a classification
refusal.** For slot tabs, steps 1 and 3 are precisely the
conditions under which `classify_module` returns `Slot`, and
it returns the same section the tab listed, because both run
`slot_section` over the same `slot_effects`. So
`add_item(fitting, types, &row.name, None)` succeeds and
lands in the tab's section for every candidate. For the
stacked tabs, steps 1 and 3 are precisely the conditions
under which `add_stacked` reaches its merge with the tab's
section (`src/fitting/editor.rs:133-145`), so
`add_item(fitting, types, &row.name, Some("1"))` succeeds
and lands in the tab's section for every candidate.

The only refusals a click can still meet come from the
quantity text the user typed, not from the row: an invalid
quantity refuses `InvalidQuantity`, and a merge past
2,147,483,647 refuses `QuantityTooLarge` (section 6.3).
Both surface through the existing refusal label.

This invariant is pinned by exhaustive tests over the
bundled catalogue (section 10, tests 3 and 4): if a future
catalogue or classifier change breaks the agreement between
builder and classifier, the test fails instead of the user
meeting a surprise refusal.

### 3.4 Sort (locked)

Candidates sort by lowercased name, then name, then type
number — the shipped chooser order verbatim
(`src/ui/industry.rs:623-629`). Flutter applies no sort (its
rows arrive in database order); a browsing list without a
stable, name-first order is not browsable, and the shipped
Rust choosers already settled this question. The sort runs
once per candidate build over at most 1,371 rows (section 7).
Search filtering preserves this order.

## 4. Search, render cap, and empty states

### 4.1 Search semantics (locked)

One search box above the rows, bound to the new state field
in section 8, hint text verbatim `Search by name`. Filtering
is a small pure helper in `src/ui/fittings.rs`:

```rust
fn browser_row_matches(row: &BrowserRow, needle: &str) -> bool {
    widgets::matches_search(&row.name, needle)
}
```

That is the shipped semantics reused, not reinvented:
case-insensitive substring on the name, empty needle matches
everything (`src/ui/widgets.rs:206-208`), the same wrapper
shape the fittings list already uses
(`fitting_matches_search`, `src/ui/fittings.rs:246-248`), and
the same semantics Flutter's browser applies to `name`. The
match runs against `row.name`, never the formatted row label:
searching `30.0` must not find modules by their CPU figure.
There is no trimming of the needle, no token or fuzzy
matching, and no match against type numbers — `matches_search`
as shipped decides all of it.

One search field serves all tabs, and its text survives tab
switches, as Flutter's single query does. Switching tabs
while a search is typed simply filters the new tab by it.

### 4.2 Render cap and the showing line (locked)

At most `FITTINGS_RENDER_MAX` (100, `src/ui/fittings.rs:58`)
rows render per frame — the cap this file already applies to
its own item lists, and the same cap the shipped choosers
use (`REACTION_CHOICE_RENDER_MAX`, `src/ui/industry.rs:53`).
When the filtered list exceeds the cap, the honest count
line renders above the rows, in this file's shipped format
(`src/ui/fittings.rs:1151-1153`):

```text
Showing {shown} of {total} items.
```

where `total` is the filtered count after search, so the
line always describes what the search matched. When the
filtered list fits under the cap, no line renders — the
precedent in both files. There is no browser-specific scroll
area: the rows ride the page scroll (`src/app/shell.rs:
3800`), like the shipped chooser lists, and the panel's
remaining blocks follow below as today.

### 4.3 Empty states (verbatim, locked)

- Filtered list empty and the search is empty:
  `No items in this section.` With the bundled catalogue
  every shipped tab is non-empty, so this state is
  reachable only on a fixture catalogue; it is worded and
  locked regardless.
- Filtered list empty and a search is typed:
  `No matches.` — Flutter's browser wording for exactly
  this state.

## 5. Row wording (verbatim format, locked)

A row is one `selectable_label` whose text is built by a pure
helper in `src/ui/fittings.rs`:

```rust
fn browser_row_label(row: &BrowserRow) -> String
```

- Both figures present:
  `{name} (CPU {cpu}, power grid {power})`, where `{cpu}` is
  `widgets::format_fitting_amount(cpu, "tf")` and `{power}`
  is `widgets::format_fitting_amount(power, "MW")`. Example:
  `Damage Control II (CPU 30.0 tf, power grid 1.0 MW)`.
- Only CPU present: `{name} (CPU {cpu})`.
- Only power grid present: `{name} (power grid {power})`.
- Neither present: `{name}` alone.

The units and formatter are the fitting resources block's
own (`src/ui/fittings.rs:1663-1669`, `src/ui/widgets.rs:
69`). Flutter prints `CPU: 0.0  PG: 0.0` for rows with no
data; the Rust catalogue carries these figures as options
precisely so absence stays visible, and this browser never
prints a `0.0` it cannot prove. In the bundled catalogue:
High rows carry both figures 1,350 of 1,371 times, Medium
875 of 903, Low 952 of 1,005 with 6 further rows carrying
power grid only; Rig, Subsystems, Drones, and Fighters rows
carry neither, so those tabs show plain names. No other text
appears on a row — in particular never the type number.

## 6. Click-to-add routing

### 6.1 One click, the existing add path (locked)

Rows render as `ui.selectable_label(false, label)`; there is
no browser selection state, because a click is an action,
not a selection. Single click is the shipped chooser
gesture (`src/ui/industry.rs:932-936`). During the row loop
the panel records the clicked row's name in a local; after
the loop it applies exactly one add against the panel's
working clone, in the same frame and before the item rows
below are built:

```rust
match editor_add_item(&mut imported, catalogue, &clicked_name, quantity) {
    Ok(()) => note_successful_edit(state),
    Err(refusal) => {
        state.fittings_editor_error = Some(add_refusal_message(refusal));
    }
}
```

— the "Add item" button's match verbatim
(`src/ui/fittings.rs:2997-3002`). A successful browser add
therefore marks the draft edited, clears any standing
refusal, drops the per-row quantity drafts, and disarms an
armed save confirmation, all through `note_successful_edit`
(`src/ui/fittings.rs:1384-1389`), identically to a typed add.

The click does not write the row's name into the typed
add-name field first. Filling the box would need a second
click on "Add item" to do anything, would overwrite text the
user may have typed there, and would still end at the same
call. Click-to-add means the add happens on the click,
through the one existing path. The panel never constructs
an `ImportedItem` itself and never calls `classify_module`
or `slot_section` for admission; `editor_add_item` re-proves
everything on every click, which is what keeps the
section 3.3 invariant honest rather than assumed.

### 6.2 Quantity rules per tab (locked)

- Slot tabs: the quantity argument is always `None`. The
  typed quantity box is ignored on these tabs, so a stray
  entry there can never turn a module click into a
  `StackedModule` refusal.
- `Drones` and `Fighters` tabs: the quantity argument is
  `Some(text)`, where `text` is the existing quantity field
  (`fittings_editor_add_quantity`, whose hint already reads
  "Quantity (drones, fighters, cargo only)") trimmed, or
  the literal `"1"` when that field is blank. One click
  with a blank quantity adds one; repeated clicks merge
  through the editor's own stacking, as repeated typed adds
  do. No new quantity field is created for the browser.

### 6.3 Refusals that remain possible (locked)

Only the stacked tabs can refuse, and only from quantity
state, never from the row: typed text that is not a valid
stack quantity refuses `InvalidQuantity`, and a merge that
would pass 2,147,483,647 refuses `QuantityTooLarge`. Both
render through the existing refusal label above the browser
(`src/ui/fittings.rs:3005-3007`) with `add_refusal_message`
wording — `Could not add: {reason}.` — byte-identical to a
typed add. The browser introduces no refusal text of its
own, and by section 3.3 no `UnknownName`, `AmbiguousName`,
`NotAModule`, or `NoSlotForModule` refusal is reachable from
a listed row.

## 7. Per-frame work (locked bound)

The bundled catalogue holds 25,818 rows. The shipped
choosers rebuild per frame, but over source sets of about a
hundred rows (the reaction chooser's test pins 111). A
per-frame rebuild here would scan 25,818 rows, normalize
every name, and sort up to 1,371 candidates on every frame
the panel is open. That bound is not accepted.

Locked instead: **candidates are cached per tab in state,
and the full catalogue is scanned at most once per tab
selection.** The panel rebuilds the cache only when the
cached section differs from the selected tab (section 8).
One build is the section 3.2 pass: one scan of 25,818 rows
with a normalized-name multiplicity map, plus one sort of at
most 1,371 rows. Every other frame does only chooser-scale
work: `matches_search` over at most 1,371 cached names, then
at most 100 row labels formatted and rendered. When no draft
is present, the browser does no work at all, because it does
not render.

The cache cannot go stale: the catalogue is a bundled asset
loaded once per process (`include_str!` in
`FittingTypes::load_bundled`, `src/names/fitting_types.rs:
371-374`) and immutable while the app runs. The cache is
still cleared at every editor reset site (section 8) so its
lifetime matches the draft's — discipline, not correctness.
The one new log line (section 9) makes each build visible,
so a rebuild-per-frame regression would be obvious in logs.

## 8. State fields and clearing (locked)

Exactly four new fields on `AppState`, beside the editor
fields (`src/app/state.rs:844-852`), memory-only like them:

| Field | Type | Initial / cleared value |
|---|---|---|
| `fittings_browser_section` | `ImportSection` | `ImportSection::High` |
| `fittings_browser_search` | `String` | empty |
| `fittings_browser_rows` | `Vec<BrowserRow>` | empty |
| `fittings_browser_rows_section` | `Option<ImportSection>` | `None` |

`fittings_browser_rows` is the section 7 cache;
`fittings_browser_rows_section` records which tab it was
built for, and `None` means no valid cache. The panel
rebuilds when `fittings_browser_rows_section` is not the
selected tab, then stores the tab alongside the rows.

All four fields return to their cleared values at every
existing editor reset site:

- `clear_editor_state` (`src/ui/fittings.rs:1393-1400`),
  which covers a new import outcome (success or fatal),
  "Clear import", and both demo-sample buttons
  (`src/ui/fittings.rs:2874-2910`).
- The three state reset sites that already clear the editor
  fields inline: character switch (`src/app/state.rs:
  1133-1138`), removal of the active character
  (`src/app/state.rs:1342-1347`), and no characters
  remaining (`src/app/state.rs:1403-1408`).

Nothing else clears them. A successful edit never clears
browser state (`note_successful_edit` is unchanged), so the
user can add several modules in a row from one tab and one
search. A tab switch clears nothing; it only makes the cache
stale by section comparison. Same-character reselect keeps
browser state, like every sibling field.

Borrow discipline in the panel follows the shipped pattern:
rows are read from the cache to collect a click, the click
is recorded in a local `Option<String>` name, and the add is
applied after the row loop — never while state the loop
reads is being mutated. Cloning the filtered names for the
rendered 100 rows, as the existing panels clone their
inputs, is acceptable; cloning the whole cache per frame
(all of up to 1,371 rows) is not needed by the pattern above
and does not happen; it would stand outside the section 7
bound.

## 9. Logging (locked)

Every new line carries the `[FITTING]` tag with counts and
fixed tokens only. Search text is user input and is never
logged; row type numbers are never logged. Locked behavior:

- Exactly one new line, at cache build:
  `[FITTING] module browser candidates built section={:?} rows={count}`
  at debug level. It fires at most once per tab selection
  (section 7), which is what makes the bound auditable.
- A click logs nothing new. The editor core already logs the
  canonical catalogue name on a successful add and the
  refusal kind on a refusal (`src/fitting/editor.rs:71-74`,
  `src/fitting/editor.rs:110-113`); a browser add reaches
  the same lines because it is the same call.
- Tab switches and search typing log nothing, matching the
  shipped choosers' search fields.

## 10. Test plan (locked, real-catalogue pins)

Pins run against `FittingTypes::load_bundled()`, as the editor
tests do (`src/fitting/editor.rs:249-251`). The counts and
first rows below were scripted from
`assets/sde/fitting_types.json` at design time replicating the
loader's filter (`src/names/fitting_types.rs:380-386`) and the
section 3 predicates; builders must reproduce them by test,
not re-derive looser ones. Sort below is the section 3.4 order.

| Section | Rows | First three names |
|---|---|---|
| High | 1,371 | `'Arbalest' Cruise Launcher I`, `'Arbalest' Heavy Missile Launcher`, `'Arbalest' Rapid Heavy Missile Launcher I` |
| Medium | 903 | `'Basic' Capacitor Recharger`, `'Basic' EM Shield Amplifier`, `'Basic' Explosive Shield Amplifier` |
| Low | 1,005 | `'Abatis' 100mm Steel Plates`, `'Accord' Core Compensation`, `'Anguis' Ice Harvester Upgrade` |
| Rig | 642 | `Capital Algid Energy Administrations Unit I`, `Capital Algid Energy Administrations Unit II`, `Capital Algid Hybrid Administrations Unit I` |
| Subsystem | 48 | `Legion Core - Augmented Antimatter Reactor`, `Legion Core - Dissolution Sequencer`, `Legion Core - Energy Parasitic Complex` |
| Drones | 129 | `'Augmented' Acolyte`, `'Augmented' Berserker`, `'Augmented' Hammerhead` |
| Fighters | 94 | `Ametat I`, `Ametat II`, `Antaeus I` |
| Cargo | 0 | — |

Builder A (unit tests in `src/fitting/editor.rs`):

1. **Counts and first rows.** For each section above, candidate
   length equals the table count and the first three names
   match (full literals, no ellipsis); Cargo is empty. No
   candidate name is empty, purely numeric, or untrimmed
   (`name != name.trim()` fails the test).
2. **Demo pins.** Each demo-sample name lists in its tab:
   `Damage Control II` in Low with CPU 30.0 and power 1.0,
   `1MN Afterburner II` in Medium with CPU 15.0 and power
   11.0, `200mm AutoCannon II` in High with CPU 9.0 and power
   4.0, `Small Projectile Burst Aerator I` in Rig with neither
   figure, and `Hobgoblin II` in Drones. (`EMP S` and
   `Nanite Repair Paste` from the same sample list nowhere —
   there is no Cargo tab; test 5 pins `EMP S`.)
3. **Slot-tab invariant, exhaustive.** For each slot tab,
   adding every candidate by name with `None` quantity to an
   empty draft always returns `Ok`, the appended row's
   section equals the tab, and its name equals the
   candidate's name. This is the section 3.3 decision pinned,
   not sampled.
4. **Stacked-tab invariant, exhaustive.** For Drones and
   Fighters, adding every candidate by name with `Some("1")`
   always returns `Ok` and the resulting row sits in the
   tab's section (merging permitted; assert one row per name
   reaching the section, as the editor's merge defines it).
5. **Exclusions.** None of these list under any section:
   `Lux Kontos` (module category, no slot effect),
   `Standup Anticapital Missile Launcher I` (slot effect,
   category 66), `Spiked Quafe` (ambiguous name), `Rifter`
   (ship), `EMP S` (charge; no Cargo tab).
6. **Fixture guard.** On a small `FittingTypes::from_json`
   catalogue in the shipped dual-fixture style, rows with a
   purely numeric name, an ambiguous pair (same name, two
   type numbers), a category-66 row carrying a slot effect,
   and a category-7 row with no slot effect all fail to list,
   while one ordinary module row does.
7. **Figure presence.** Low contains `Limited Hyperspatial
   Accelerator` with CPU absent and power grid 1.0 (a real
   bundled row exercising the CPU-absent case). Counts of
   rows carrying both figures are asserted for High (1,350),
   Medium (875), and Low (952), and every Rig, Subsystem,
   Drone, and Fighter candidate has both figures absent.

Builder B (tests in `src/ui/fittings.rs` and
`src/app/state.rs`):

8. **Row label literals.** Both figures present yields
   `Damage Control II (CPU 30.0 tf, power grid 1.0 MW)`;
   power-grid-only yields its single-figure form; a
   figureless row yields exactly its name. No label contains
   the row's type number as text for the demo pins of
   test 2.
9. **Search.** `browser_row_matches` filters candidates:
   `damage control` over Low candidates yields 25 rows
   starting `'Basic' Damage Control` then `Damage Control
   I`; the same needle upper-cased yields identical results;
   an empty needle yields all candidates; a nonsense needle
   yields none. Names-only matching is proven by showing
   that a search for `30.0` matches no row.
10. **Resets.** The existing isolation fixtures are extended,
    not replaced: `seed_import_state` /
    `assert_import_cleared` (`src/app/state.rs` tests) seed
    and assert all four browser fields across the switch,
    removal, and no-character paths, and the
    `clear_editor_state` panel test (`src/ui/fittings.rs`
    tests) asserts the same cleared values.

Regression: the full existing suite (1,038 tests at base)
passes unmodified except for test 10's fixture extension. An
import that is never browsed renders its item, statistics,
copy, and save blocks byte-for-byte as today; the browser is
one additive block that exists only inside the editor area.

## 11. Code structure and builder split (locked)

### 11.1 Builder A — pure candidate builder

`src/fitting/editor.rs` only: `BrowserRow` and
`browser_candidates` exactly as sections 3.1–3.4 lock them,
calling the already-`pub(crate)` `slot_section` and category
constants — no visibility change and no behavior change in
`src/fitting/eft.rs` or `src/names/fitting_types.rs`. Tests
1–7 of section 10 land with it.

Commit subject (locked):
`feat(fitting): add pure module browser candidate builder`

### 11.2 Builder B — state and panel

`src/app/state.rs`: the four section 8 fields, initialized
and cleared at the three inline reset sites. `src/ui/
fittings.rs`: the section 4–6 browser block in its locked
position (tabs, search box, showing line, rows, click
application), the `browser_row_label` and
`browser_row_matches` helpers, the cache rebuild with its
one section 9 log line, and the `clear_editor_state`
extension. Tab labels, hint, empty states, and the showing
line are the section 2.2, 4.1, 4.3, and 4.2 literals. Tests
8–10 land with it. Builders add a section 9 log line only —
no other new logging.

Commit subject (locked):
`feat(fitting): browse modules and click to add in the editor`

### 11.3 Integrator

- Merge A then B; resolve nothing by redesign. If B needs a
  surface A did not lock, it comes back as a design question,
  not an improvisation.
- Documentation commit mirroring the editor slice's closing
  step: README mention of the browser where the editor is
  described, and a `docs/engineering-journal/LEARNINGS.md`
  entry only if the build surfaces a non-obvious mechanism.

  Commit subject (locked): `docs(fitting): document module browser`
- Full gate on the merged tip (section 13), pushing nothing
  without instruction.

Demo behavior (locked): the browser is fully usable in demo
mode, like the editor it extends (editor design section
6.5). It reads the same bundled catalogue in demo as in live
play, so demo users can browse real items into a sample
import; the standing demo save restriction is unchanged and
needs no browser wording. There is no demo-only gating.

## 12. Deferred (named, not built)

- **Drag and drop** from browser to slots. The app has no
  egui drag-and-drop precedent anywhere — no drag source,
  drop target, or payload code in `src/` — and slot targets
  would need a placement grammar the editor deliberately
  does not have. Its own design, if ever.
- **Double-click to add.** Flutter double-clicks into the
  first empty slot; the Rust editor has no slot-capacity
  admission to mirror that against (section 2.3), and no
  shipped code in this app uses a double-click gesture.
  Single click is locked (section 6.1), so double-click has
  no distinct semantics to add in this slice.
- **Cargo tab** (section 2.2): needs a positive membership
  story — likely explicit charge and commodity categories
  with their own counts — before 21,594 catch-all rows could
  be honest candidates.
- **Ship browser / ship change**, and new-from-scratch
  fittings: unchanged deferrals from the editor design; the
  browser lists fitting contents, never hulls.
- **Charge editing**: unchanged deferral from the editor
  design. A Charges tab would list charge candidates with
  no add path to land in (charges cannot be added alone
  today), so it is not browsable in this slice.
- Showing why a searched name is absent (ambiguous,
  slotless, wrong category): the typed box already answers
  that with the importer's refusal wording; the browser
  stays a positive list of proven candidates.
- Recently-used or favourites ordering, filtering by CPU or
  power grid budget, and group/tree browsing: the order is
  the shipped name sort, and the figures on a row are
  information, not filters.

## 13. Verification gate (locked)

On the design commit and again on the merged slice tip:

```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build
```

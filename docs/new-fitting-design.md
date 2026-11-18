# New fitting from scratch — design

Status: locked for the `feat/rust-new-fitting` slice. Base:
`develop` at `3e0b594` (1,047 tests; the fitting editor from
pull request #608 and the module browser from pull request
#609 are merged there — see `docs/fitting-editor-design.md`
and `docs/fitting-module-browser-design.md`). Slice branch:
`feat/rust-new-fitting`. This document is the single design
commit; builders and the integrator implement exactly what is
locked here and nothing else.

The editor design deferred this piece by name: "Ship change
and new-from-scratch fittings (2.2)" and "Editing a copy of a
saved fitting (2.2)" (`docs/fitting-editor-design.md` section
11), and the module-browser design repeated both unchanged
(`docs/fitting-module-browser-design.md` section 12). This
slice ships new-from-scratch only. Editing a copy of a saved
fitting stays deferred, for the reason locked in section 12.

All file and line references are to the base tree at `3e0b594`
unless a Flutter reference says `ed698d3` (the last Flutter
tree, read via `git show` at discovery time).

## 1. Goal and value ranking

Let the user start a fitting by choosing a ship, instead of
only by pasting EFT or DNA text: search the bundled ship
list, click a hull, and land in the shipped editor and module
browser with an empty draft for that hull. Import stays
exactly as it is; the ship chooser is a second door into the
same draft.

Value ranking (locked, in order):

1. **Honest provenance.** A created draft is never described
   as imported. It carries a distinct format value (section
   5.1), its import-report counters are all zero because
   nothing was parsed (section 5.2), and every user-visible
   string that today says "imported" gets a locked created
   wording (section 7). Imported drafts keep every shipped
   string byte-for-byte.
2. **Every listed ship is choosable by construction.** A hull
   appears only when the bundled catalogue proves, with the
   shipped browser's own guards, that clicking it builds a
   valid draft whose bare-hull statistics render (section 3).
3. **One draft, one set of downstream rules.** A created
   draft is the same `ImportedFitting` the editor, browser,
   statistics, copy, and save blocks already consume. Zero
   items is decided by each shipped guard exactly as shipped
   (section 8); this slice adds no new silent path and no new
   refusal.

## 2. Scope: placement and what does not ship

### 2.1 Placement (locked)

The chooser renders inside `fittings_import_panel`
(`src/ui/fittings.rs:2878`), after the catalogue guard
(`src/ui/fittings.rs:2885-2888`) and before the paste box
(`src/ui/fittings.rs:2889-2894`). It therefore exists exactly
when import exists: before the saved-fittings `LoadState`
match (`src/ui/fittings.rs:3350-3353`), with an active
character (`src/ui/fittings.rs:3346-3349`), and only when the
bundled catalogue loaded. With no catalogue the shipped
load-failure sentence shows and there is no chooser, no paste
box, and no draft — unchanged.

Unlike the module browser, the chooser is **not** inside the
`owner_ok` draft guard (`src/ui/fittings.rs:2973-2977`): it
must exist when there is no draft, because creating the draft
is its purpose, and it stays visible when a draft exists,
because choosing again is the replacement path (section 6).
It renders above the working-clone point
(`src/ui/fittings.rs:2981-2983`), so a click that installs a
draft is picked up by the draft block in the same frame.

The chooser is always expanded: heading, standing note,
search box, then rows. The app has no collapsible-section
precedent in this panel, and the module browser — the closest
precedent — renders its full block unconditionally
(`src/ui/fittings.rs:3062-3135`). A collapsed or toggled
chooser is a rejected alternative, not a builder choice.

### 2.2 What does not ship

- No ship change on an existing draft (section 12). Choosing
  a ship always creates a new empty draft, replacing any
  current draft (section 6); it never carries items across
  hulls.
- No editing a copy of a saved fitting (section 12).
- No persistence of drafts, created or imported (section 12).
- No group, tree, faction, or class browsing, no favourites
  or recently-used ordering, and no filtering by any figure:
  the list is the proven set (section 3), the order is the
  shipped name sort (section 3.4), and the search is the
  shipped name search (section 4). This mirrors the module
  browser's standing deferral of the same ideas
  (`docs/fitting-module-browser-design.md` section 12).
- No new blocking validation anywhere downstream (section 8).

## 3. The pure ship-candidate builder

### 3.1 Membership (locked)

A catalogue row is listable if and only if **all** of these
hold, evaluated over the rows the loader kept
(`FittingTypes.types`; the loader already drops
`type_id <= 0` and blank names at
`src/names/fitting_types.rs:380-386`):

1. `category_id == 6` (`CATEGORY_SHIP`, the same constant the
   two parsers check: `src/fitting/eft.rs:545-554`,
   `src/fitting/dna.rs:105-113`).
2. The trimmed name is non-empty and not purely numeric
   (`trimmed.parse::<i64>().is_err()`) — the module browser's
   guard verbatim (`src/fitting/editor.rs:237-240`).
3. **Unique-name guard, as shipped:** the normalized name
   (`normalize_type_name`, `src/names/fitting_types.rs:363-368`)
   maps to exactly one distinct `type_id` across the whole
   catalogue, counted with the browser's de-duplicated
   `(normalized name, type_id)` counting
   (`src/fitting/editor.rs:218-225`, admission at
   `src/fitting/editor.rs:241-244`). A name two hulls share
   never lists: the chooser must not offer a click whose
   identity a later exact-name lookup would refuse as
   ambiguous.
4. **Stat-usability proof:** `cpu_output` and
   `power_output` are each present, finite, and
   non-negative — the same usability rule the resources
   block applies (parent fix on review: presence alone
   would list a negative-output hull whose resources
   block then reports unavailable). These are dogma 48 and 11 on the
   catalogue row (`src/names/fitting_types.rs:31-34`), the
   pair the resources block requires to print bare-hull
   numbers instead of its no-ship-output sentence
   (`FITTING_RESOURCES_NO_SHIP_OUTPUT`,
   `src/ui/fittings.rs:1471`). An empty draft's main content
   is its bare-hull statistics, so a choosable ship must
   prove the output pair. Zero is a real value and passes:
   the check is finite and non-negative, never `> 0.0`
   (section 3.3). No
   other attribute is required. Every other statistic block
   already swaps in an honest unavailable sentence when its
   own inputs are absent (section 8), so requiring more
   would exclude hulls the blocks already handle truthfully.

Emission de-duplicates on `(normalized name, type_id)`, first
row in file order winning — the shipped browser emission rule
(`src/fitting/editor.rs:227-236`), including its reason: a
later duplicate row the lookup index ignores must never be
the row a click appears to choose.

This membership is chooser-only. Import keeps its shipped
admission (category 6 and unique resolution through
`lookup`/`lookup_by_id`), so a future output-less hull could
still be imported and would show the honest no-output
sentence; it simply could not be started from the chooser.
That asymmetry is deliberate and is stated here so no builder
"unifies" the two.

### 3.2 Scripted counts (pinned)

Scripted from `assets/sde/fitting_types.json` at the base,
replicating the loader filter and section 3.1 exactly, and
cross-checked against an independent discovery script over
the same asset (identical results):

- Rows in the asset: 25,818. Rows the loader keeps: 25,818
  (0 skipped).
- Category-6 rows kept: **404**.
- Of those, unique normalized name: **404** (0 excluded).
- Purely numeric names among them: **0**.
- With both `cpuOutput` and `powerOutput` present as finite
  numbers: **404** (0 excluded, 0 non-finite).
- **Final listable set: 404 ships.**

The proof therefore excludes nothing today; its value is that
a future catalogue row that cannot prove the pair fails to
list instead of producing a draft whose first statistic block
is an apology. Builders reproduce the number 404 by test
(section 11), never by re-deriving a looser predicate.

### 3.3 The two zero-output hulls

Two listable hulls carry exactly `0.0 / 0.0`: type 2078
`Zephyr` and type 3532 `Echelon`. They list and are choosable:
present zero output is bundled data, and the resources block
renders real zeros for them exactly as it would after an
import of either hull today. Excluding them with a `> 0.0`
rule is a rejected alternative: it would drop two real,
importable ships for a distinction no downstream block makes.

### 3.4 Sort (locked)

Sorted by lowercased name, then name, then type number — the
module browser's comparator verbatim
(`src/fitting/editor.rs:269-275`). The type number is a sort
tiebreak and internal key only: never rendered, never logged.
First rows in this order (pinned in section 11): `Abaddon`,
`Absolution`, `Adrestia`, `Aeon`, `Algos`, `Alligator`,
`Amarr Shuttle`, `Anathema`, `Anshar`, `Apocalypse`. Last
three: `Zealot`, `Zephyr`, `Zirnitra`.

### 3.5 Row type and label (locked)

```rust
pub struct ShipRow {
    pub type_id: i64,
    pub name: String,
}
```

Beside `BrowserRow` in `src/fitting/editor.rs`, built by
`pub fn ship_candidates(types: &FittingTypes) -> Vec<ShipRow>`.
`name` is the trimmed catalogue name, as with `BrowserRow`
(`src/fitting/editor.rs:262-267`). The row label is the name
and nothing else: unlike module rows, no CPU or power-grid
figure is appended. `BrowserRow`'s figures are module *needs*
(`src/ui/fittings.rs:261-280`); a ship's output pair is a
membership proof (section 3.1 rule 4), not row content, and
the draft's own statistic blocks print the real outputs the
moment the hull is chosen. Printing outputs on 404 rows would
also invite figure-based filtering this slice defers
(section 2.2). Reusing `BrowserRow` for ships is rejected:
its `cpu`/`power` fields mean needs, and overloading them
with outputs would make one struct say two opposite things.

## 4. Search, render cap, and empty states (locked)

Following the module-browser precedent
(`src/ui/fittings.rs:3072-3108`, design sections 4-5 there):

- One single-line search box, hint text `Search by name`
  (the shipped browser hint verbatim,
  `src/ui/fittings.rs:3073-3075`), feeding
  `state.text_input_focused` exactly as the browser box does.
- Matching is `widgets::matches_search` on the row's
  catalogue name — empty needle matches everything, otherwise
  case-insensitive substring (`src/ui/widgets.rs:206-208`) —
  through a `ship_row_matches` predicate mirroring
  `browser_row_matches` (`src/ui/fittings.rs:254-256`). The
  match is on the name, never on a formatted label and never
  on the type number.
- Rows render as `selectable_label(false, name)`, capped at
  `FITTINGS_RENDER_MAX` (100, `src/ui/fittings.rs:58`), with
  the overflow label `Showing {shown} of {total} ships.` —
  the browser's `Showing {shown} of {} items.` template
  (`src/ui/fittings.rs:3096-3101`) with the noun changed,
  because these rows are ships, not items. With an empty
  search this shows the first 100 of 404 in section 3.4
  order.
- Empty result: `No matches.` when the search text is
  non-empty (browser wording verbatim,
  `src/ui/fittings.rs:3090-3093`). An empty candidate list
  with an empty search cannot occur against the bundled
  catalogue (404 candidates), but the branch still locks its
  wording, mirroring the browser's pair: `No ships to show.`
- Search pins (section 11): `rift` and `RIFTER` each yield
  exactly [`Rifter`]; `shuttle` yields 8 rows starting
  `Amarr Shuttle`, `Caldari Shuttle`,
  `Council Diplomatic Shuttle`; a nonsense needle yields 0;
  a needle of `587` (the Rifter's type number as text)
  yields 0, proving the number is never searched or shown.

Per-frame bound: the candidate list is cached in state and
built at most once until a reset clears it (section 9),
mirroring the browser's cached-rows rule
(`src/ui/fittings.rs:3076-3082`). The per-frame work is one
substring filter over at most 404 short names plus at most
100 rendered rows.

## 5. The blank draft construction (locked)

### 5.1 Provenance: a third format value

`ImportFormat` (`src/fitting/eft.rs:234-238`) gains one
variant:

```rust
pub enum ImportFormat {
    Eft,
    Dna,
    Created,
}
```

The type keeps its name and home; renaming it would churn
every shipped call site for no user-visible gain. Its doc
comment is extended to say the panel uses it to distinguish
a created draft from both input formats. Exactly four
exhaustive matches exist in production code and each gains a
locked `Created` arm:

- `imported_summary_line` (`src/ui/fittings.rs:792-809`):
  the created wording in section 7. This is the real arm.
- `format_import_issue`, `import_issues_heading`, and
  `import_issues_overflow_label` (`src/ui/fittings.rs:732`,
  `751`, `772`): the `Created` arm is byte-identical to the
  `Eft` arm in each. These arms are unreachable for a created
  draft — its issue list is empty at construction (section
  5.2) and the editor never pushes issues (refusals go to
  `fittings_editor_error`; `src/fitting/editor.rs` contains
  no write to `report.issues`) — but the compiler requires
  the arms, and reusing the EFT wording means that if the
  invariant were ever broken, the fallback text is shipped,
  tested wording rather than new prose. Each arm carries a
  one-line comment naming the invariant.

No other production match on `ImportFormat` exists. In
particular the DPS surface test
`imp.format == ImportFormat::Eft` (`src/fitting/dps.rs:195`)
is an equality check, not a match, and stays untouched:
a created draft takes the non-EFT branch, which is the
correct surface for it. Editor adds always produce
`charge: None` (`src/fitting/editor.rs:107`) and charge
editing is deferred, so a created draft can never hold a
loaded charge; its weapons are unloaded by construction,
which is exactly what the non-EFT branch models. Builders
must not "fix" this line to include `Created`.

Special-casing the summary line on all-zero counters instead
of a format variant is rejected: a header-only EFT import is
also all-zero (section 8) and *was* imported, so counters
cannot distinguish the two provenances.

### 5.2 The constructor (locked)

In `src/fitting/editor.rs`, beside `ship_candidates`:

```rust
pub fn new_fitting(types: &FittingTypes, ship: &ShipRow)
    -> Option<ImportedFitting>
```

It re-validates its input rather than trusting the caller:
`types.lookup_by_id(ship.type_id)` must return a row with
`category_id == 6`, both outputs usable (present,
finite, non-negative), and a trimmed name equal to
`ship.name`; otherwise `None`. (Uniqueness is a listing
property proven by `ship_candidates`; the constructor proves
identity, category, and stat presence for the one row it is
handed.) On success it builds, field for field:

- `name: format!("New {ship_name} Fit")` — Flutter's
  construction verbatim: `FittingController.setShip` sets
  `name: 'New $name Fit'`
  (`lib/features/fitting/presentation/fitting_providers.dart:43-57`
  at `ed698d3`). The rename row renames it like any draft
  (section 8).
- `ship_type_id`: the row's type number (> 0 by the loader
  filter).
- `ship_name`: the canonical catalogue name (`row.name`
  cloned), as both parsers store it
  (`src/fitting/eft.rs:552`, `src/fitting/dna.rs:114`).
  The name always comes from the catalogue row keyed by type
  number, never from UI-held text — the Flutter ship browser
  passed a hardcoded `(typeId, name)` pair and three of its
  six pairs named the wrong hull for the number
  (603 labelled `Incursus` where the catalogue says `Merlin`,
  608 labelled `Merlin` for `Atron`, 644 labelled
  `Megathron` for `Typhoon`;
  `lib/features/fitting/presentation/widgets/ship_browser.dart:11-18`
  at `ed698d3`, verified by script at discovery). This design
  makes that failure structurally impossible: no name is ever
  paired with a number by hand.
- `format: ImportFormat::Created`.
- `items: Vec::new()`.
- `report: ImportReport { imported_lines: 0,
  placeholder_lines: 0, charges_noted: 0, issues:
  Vec::new() }`. All zero because nothing was imported: no
  lines were read, no markers skipped, no charges noted, and
  there is nothing to complain about. This is the same zero
  state a header-only EFT and a hull-only DNA produce
  (`src/fitting/eft.rs:869-876`, `src/fitting/dna.rs:515-521`),
  reached honestly instead of by parsing empty text. The
  constructor never synthesizes import text and never calls
  a parser.

`to_character_fitting()` on this draft yields fitting number
−1, the name above, no description, and zero items
(`src/fitting/eft.rs:279-327`), and `name_resolver()` holds
only the ship (`src/fitting/eft.rs:333-344`) — exactly what
every downstream block already consumes for a header-only
import.

If `new_fitting` returns `None` for a listed row, the click
does nothing to any state: no draft change, no error text, no
status message — only the locked warning log line (section
9.2). This is defense-in-depth for a branch the listing proof
makes unreachable with the bundled catalogue; inventing
user-facing wording for it would be prose no test against
real data can reach. A fixture test reaches it with a
hand-built catalogue (section 11).

## 6. Choosing a ship: install and replacement (locked)

A click on a ship row, in the panel:

1. Calls `new_fitting(catalogue, &row)`. On `None`, stops
   (section 5.2).
2. Installs exactly as a successful import installs
   (`src/ui/fittings.rs:2920-2923`):
   `state.fittings_imported = Some(draft)`,
   `state.fittings_import_error = None`,
   `state.fittings_import_owner = state.active_character_id`,
   `clear_editor_state(state)`.
3. Additionally — locked differences from the import path,
   with reasons:
   - `state.fittings_import_text.clear()`. A created draft
     has no source text; leaving a previously pasted EFT or
     DNA block in the box beside it would present text the
     draft did not come from, and one stray **Import fitting**
     click would silently replace the created draft with it.
     Clearing follows the Clear-import and demo-sample
     precedent (`src/ui/fittings.rs:2939-2943`,
     `2947-2959`), which clear or replace the text whenever
     the draft's origin changes.
   - `state.fittings_write_confirm = None` (**disarm any
     armed save**). Replacing the whole draft is at least as
     strong as the edits that already disarm through
     `note_successful_edit` (`src/ui/fittings.rs:1416-1421`).
     The shipped import path does not disarm explicitly and
     relies on per-frame recomputation; an empty created
     draft would in fact drop an armed confirmation next
     frame through `unsaveable_label` (section 8). The
     explicit disarm is still locked, so the invariant "a
     replaced draft never inherits an armed confirmation"
     holds by construction and by test, not by a downstream
     coincidence. The whole field is cleared, whatever
     variant it held, exactly as `note_successful_edit` does.
4. `clear_editor_state` (step 2) is the entire editor and
   browser reset: add name and quantity, editor error,
   edited flag, per-row quantity drafts, rename seed, browser
   tab (back to High), browser search, and cached browser
   rows (`src/ui/fittings.rs:1438-1449`). The rename box
   reseeds from `New {ship} Fit` on the next frame through
   the shipped lazy seed (`src/ui/fittings.rs:3005-3007`).

**Replacement has no confirmation.** Choosing a ship while a
draft (imported or created, edited or not) exists replaces
it immediately and the old draft is gone. This mirrors both
shipped doors: a new import replaces the draft without asking
(`src/ui/fittings.rs:2912-2923`), and Flutter's `setShip`
replaced the working fitting unconditionally on tap
(`ship_browser.dart:55-57`, `fitting_providers.dart:43-57` at
`ed698d3`). The standing note (section 7) discloses the
replacement in advance; a confirmation step for a memory-only
draft that import already discards silently would be a new
interaction pattern with no precedent in this panel. The
armed-save case is covered by the disarm above: replacement
can lose the draft, never send it.

The click handler mirrors the browser's borrow discipline:
collect the clicked row during row rendering, act on it after
the row loop (`src/ui/fittings.rs:3102-3134`).

## 7. Verbatim wording (locked)

Rule: for `Eft` and `Dna` drafts every string below stays
byte-identical to the base. For `Created` drafts the created
column is used. Selection is by `imported.format`, at the
render site or through a small sibling helper beside the
existing helpers — builders choose the mechanism, never the
words. Internal identifiers (`fittings_imported`,
`FittingWriteConfirm::SaveImported`, `ImportedFitting`) keep
their names: they are code, not claims shown to the user, and
renaming them is out-of-scope churn.

### 7.1 The chooser block (new)

- Heading: `Start a new fitting`
- Standing note, always rendered under the heading:
  `Pick a ship to start an empty fitting in Mimir. Starting a new fitting replaces the fitting below, if there is one. Nothing is sent to EVE unless you save below, and the fitting is gone when you switch characters or close Mimir.`
  (The final two clauses mirror the import panel's standing
  disclosure at `src/ui/fittings.rs:2884`.)
- Search hint: `Search by name` (section 4).
- Overflow: `Showing {shown} of {total} ships.` (section 4).
- Empty search result: `No matches.`; empty list:
  `No ships to show.` (section 4).
- Row label: the ship name alone (section 3.5).

No **New fitting** button exists; the rows are the control,
as browser rows are theirs. No status-bar message is set on
creation: the draft block appearing below, headed by the
created summary line, is the feedback, exactly as a
successful import sets no status message.

### 7.2 Draft-block strings by provenance

| Site (base) | `Eft` / `Dna` (unchanged) | `Created` |
|---|---|---|
| Summary line (`src/ui/fittings.rs:792-809`) | `Imported "{name}" ({ship}): {n} items from {m} lines.` / `… segments.` | `Created "{name}" ({ship}): {n} items.` |
| Edited suffix (`src/ui/fittings.rs:1230`) | ` Edited since import.` | ` Edited.` |
| Draft label (`src/ui/fittings.rs:2988`) | `Imported fitting` | `Created fitting` |
| Editor note (`src/ui/fittings.rs:1226`) | shipped text, byte-identical | `Edits change only this fitting in Mimir. Nothing is sent to EVE unless you save below. Removing a module also removes its loaded charge. Items can be added only when Mimir's bundled data proves which slot they fit.` |
| Copy EFT button (`src/ui/fittings.rs:3215`) | `Copy imported fitting as EFT` | `Copy fitting as EFT` |
| Copy DNA button (`src/ui/fittings.rs:3237`) | `Copy imported fitting as DNA` | `Copy fitting as DNA` |
| Save arm button (`src/ui/fittings.rs:3325`) | `Save imported fitting to EVE...` | `Save fitting to EVE...` |

Notes on the created wordings:

- The summary drops the "from {m} lines/segments" clause
  entirely. `… from 0 lines.` would be technically true and
  is rejected: it still frames the draft as the output of a
  parse. `{name}` goes through the shipped
  `fitting_display_name` as in both existing arms.
- The editor note differs from the shipped note only by
  dropping the one word "imported". The loaded-charge
  sentence is inert for a created draft (it can never hold a
  charge, section 5.1) and is kept so the two notes differ by
  exactly the provenance claim and nothing else.
- Renaming all drafts' strings to the neutral created forms
  is rejected: imported drafts *were* imported, their wording
  is pinned by shipped tests, and flattening both provenances
  into one noun loses information the user currently gets.

Strings that need no created variant because they make no
provenance claim (verified at base, builders must not touch
them): the copy status messages (`Copied "{name}" as EFT`,
`src/ui/fittings.rs:866-874`; `Copied "{name}" as a DNA link`,
`src/ui/fittings.rs:838-864`), the copy-blocked statuses
(`src/ui/fittings.rs:3217-3220`, `3244-3246`), the save
confirmation title and summary (`src/ui/fittings.rs:899-911`),
the un-saveable label (`src/ui/fittings.rs:889-897`), the demo
write label (`src/ui/fittings.rs:883-884`), the empty-items
label `This fitting has no items to show.`
(`src/ui/fittings.rs:3139-3140`), and the editor heading
`Edit this fitting` (`src/ui/fittings.rs:1222`).

The placeholder and charge notes
(`src/ui/fittings.rs:812-831`) render only for non-zero
counters, so they correctly never appear on a created draft
without any new guard.

## 8. Zero-item behaviour of every downstream consumer (locked)

A created draft is not a new downstream case. Both parsers
already produce valid zero-item drafts — header-only EFT
(`src/fitting/eft.rs:869-876`) and hull-only DNA
(`src/fitting/dna.rs:515-521`) — and every consumer below
already renders, copies, or refuses them. This slice changes
none of these guards; the table records the shipped decision
each consumer applies to a created draft so no builder adds
a parallel one.

| Consumer | Zero-item behaviour (as shipped, unchanged) |
|---|---|
| Editor rename / typed add / module browser (`src/ui/fittings.rs:2995-3135`) | Fully usable. The rename box seeds `New {ship} Fit`; adds work from the first click; browser tabs list normally. The first successful edit sets the edited flag and disarms saves via `note_successful_edit`, and the summary gains ` Edited.` (section 7.2). |
| Item rows (`src/ui/fittings.rs:3137-3140`) | Shows `This fitting has no items to show.`; no remove or quantity controls exist until an item is added. |
| All 11 statistic blocks (`src/ui/fittings.rs:3166-3176`) | All render bare-hull numbers: resources at zero used against full output, calibration and bay usage at zero used, DPS with no weapons, active repair's three `0.0 HP/s` lines, slot layout, and the four ship blocks. None is omitted for emptiness; each keeps its shipped unavailable sentence for missing inputs. Section 3.1 rule 4 proves the resources block specifically renders numbers for every choosable hull. |
| Loaded-charges and issues blocks (`src/ui/fittings.rs:3178-3214`) | Both hidden: counters are zero and the issue list is empty, by their shipped `> 0` / non-empty guards. |
| Copy as EFT (`src/ui/fittings.rs:3215-3235`) | **Allowed.** With a resolved ship and zero contributors, the export is the header alone, `[Ship, New {ship} Fit]`, which re-imports as a valid empty draft. This slice adds no empty-draft refusal: refusing only created drafts while header-only imports copy freely would punish the honest provenance. The shipped ship-unresolved guard and its status wording are the only refusals, unchanged. |
| Copy as DNA (`src/ui/fittings.rs:3237-3266`) | **Allowed** on the same reasoning: the export is the hull-only link `{ship_type_id}::`, which re-imports cleanly. Only the shipped no-ship guard refuses. |
| Save to EVE (`src/ui/fittings.rs:3278-3331`) | **Refused by the shipped guard.** `unsaveable_label` returns `This fitting cannot be saved to EVE: nothing in it fits an EVE fitting slot.` whenever the mapped request has no items (`src/ui/fittings.rs:889-891`); that label replaces the arm button, and an already-armed confirmation is dropped. ESI requires at least one item (`src/fitting/write_map.rs:36-41`), so builders must not "fix" this by allowing empty saves. After the user adds an item, the created draft saves through the identical confirm path, with the section 7.2 arm wording. Flutter sent `items: []` to ESI for a blank hull (`fitting_providers.dart:191-217` at `ed698d3`); the shipped Rust guard refusing is a deliberate, already-locked deviation, not a gap in this slice. There is no local save in the Rust app to differ from. |
| Demo mode (`src/ui/fittings.rs:3270-3273`) | The chooser is fully usable in demo — it reads the same bundled catalogue, as the module browser does (module-browser design section 11) — and the standing demo write label replaces the save affordance, unchanged. No demo-only gating, no demo-only wording. |

## 9. State fields and clearing (locked)

### 9.1 New fields

Beside the browser fields in `AppState`
(`src/app/state.rs:854-863`), with the same memory-only,
never-persisted contract, and a comment block in the shipped
style naming this design:

- `fittings_ship_search: String` — the chooser search text.
- `fittings_ship_rows: Vec<ShipRow>` — cached candidates.
- `fittings_ship_rows_built: bool` — whether the cache holds
  the built list. A boolean, not an `Option`: the browser's
  `Option<ImportSection>` records *which tab* its cache is
  for; the chooser has one list, so one bit is the honest
  state. An empty `Vec` alone cannot serve, because a built
  empty list (fixture catalogues) must not rebuild every
  frame.

No other new state. Creation needs no pending-selection or
confirmation field (section 6).

### 9.2 Clearing

The three fields reset to empty string, empty vector,
and `false`:

- Inside `clear_editor_state` (`src/ui/fittings.rs:1438-1449`),
  as three added lines in the ship comment's terms. Every
  panel site thereby inherits the reset — import success and
  failure, **Clear import**, both demo samples, and creation
  itself — because a chooser left filtered from a previous
  draft or character is state from a dead context: after any
  of those actions the chooser shows the unfiltered first
  100 ships again. The cache rebuild after a clear is one
  capped-catalogue scan on the next frame (section 4 bound),
  logged as section 10 locks.
- At the three `AppState` reset sites that enumerate the
  browser fields field-for-field: character switch
  (`src/app/state.rs:1150-1153`), removal of the active
  character (`src/app/state.rs:1365-1366` region), and
  removal leaving no characters
  (`src/app/state.rs:1430-1431` region), with the shipped
  per-field style at each site.

The existing isolation fixtures (`seed_import_state` /
`assert_import_cleared` in `src/app/state.rs` tests, extended
for the browser in #609) are extended again, not replaced, to
seed and assert all three fields (section 11).

## 10. Logging (locked)

`[FITTING]` tag, counts and catalogue names only. The search
text is user text and is never logged; a raw type number is
never logged. Exactly two new lines, plus reuse of shipped
ones:

1. Cache build, `debug`, mirroring the browser's line
   (`src/ui/fittings.rs:3080-3082`):
   `[FITTING] ship candidates built rows={n}`
2. Creation, `info`, mirroring the import-complete line's
   level and field style (`src/ui/fittings.rs:2914-2919`)
   with its counters pinned at construction values so a log
   reader sees the same zero state the draft carries:
   `[FITTING] new fitting created ship={ship_name} items=0`
   where `{ship_name}` is the catalogue name (catalogue text,
   not user text — the editor's add line already logs
   catalogue names, `src/fitting/editor.rs:110-113`).
3. Constructor refusal on a listed row (the unreachable
   branch, section 5.2), `warn`, with no name or number:
   `[FITTING] new fitting refused unlisted ship row`

Nothing else logs. Row renders, searches, and hovers are
silent, as in the browser.

## 11. Test plan (locked, real-catalogue pins)

Pins run against `FittingTypes::load_bundled()`, as the
editor and browser pins do. The regression bar: the full
existing suite (1,047 tests at base) passes unmodified except
for the fixture extension in Builder B test 6. An imported
draft that is never created renders its summary, notes,
statistics, copy, and save blocks byte-for-byte as today; the
chooser is one additive block above the paste box, and the
`Created` wording exists only on created drafts.

Builder A (pure tests in `src/fitting/editor.rs`):

1. **Count and ends.** `ship_candidates` over the bundled
   catalogue yields exactly **404** rows; the first three
   names are `Abaddon`, `Absolution`, `Adrestia` and the last
   three are `Zealot`, `Zephyr`, `Zirnitra` (full literals).
   No candidate name is empty, purely numeric, or untrimmed.
2. **Zero-output inclusion.** `Zephyr` and `Echelon` both
   list (section 3.3 pins the presence-not-positive rule).
3. **Construction invariant, exhaustive.** For every one of
   the 404 candidates, `new_fitting` returns `Some` draft
   with `format == Created`, the candidate's type number and
   name, name `New {ship} Fit` (asserted by format against the
   candidate name, plus the full literal `New Rifter Fit` for
   the Rifter), `items` empty, and all four report fields at
   zero/empty. The listing proof composing with construction
   is pinned exhaustively, not sampled.
4. **Round trip by copy equivalence.** The Rifter draft from
   test 3, synthesized with `to_character_fitting()`, exports
   header-only EFT text `[Rifter, New Rifter Fit]` and DNA
   text `587::` through the shipped exporters, and both texts
   re-import through `parse_import` to zero-item drafts for
   the same hull — pinning section 8's allow decisions at the
   pure layer.
5. **Fixture exclusions.** On a small `FittingTypes::from_json`
   catalogue in the shipped fixture style: a category-6 row
   missing `cpuOutput`, one missing `powerOutput`, an
   ambiguous pair (same normalized name, two type numbers,
   both category 6), a category-6 row with a purely numeric
   name, and a category-7 row carrying both outputs all fail
   to list, while one ordinary category-6 row with both
   outputs lists and constructs. `new_fitting` handed a
   `ShipRow` whose type number resolves to a non-ship row (or
   no row) returns `None` — the section 5.2 refusal, reached
   here and only here.

Builder B (tests in `src/ui/fittings.rs` and
`src/app/state.rs`):

6. **Resets.** The `seed_import_state` / `assert_import_cleared`
   fixtures seed and assert all three ship fields across the
   switch, removal, and no-character paths, and the shipped
   `clear_editor_state` panel test asserts the same cleared
   values after seeding them (section 9.2).
7. **Summary and suffix literals.** A created draft renders
   `Created "New Rifter Fit" (Rifter): 0 items.` unedited and
   the same line plus ` Edited.` when the edited flag is set;
   the shipped EFT and DNA expected strings, including
   ` Edited since import.`, keep passing unmodified beside
   them.
8. **Wording selection.** The created column of section 7.2
   is asserted as literals (draft label, editor note, both
   copy buttons, save arm button) for a `Created` draft,
   through whatever pure helpers the render uses; the `Eft`
   values are the shipped literals. No label for any created
   fixture contains the Rifter's type number `587` as text.
9. **Search.** `ship_row_matches` over the real candidates:
   `rift` yields [`Rifter`], `RIFTER` identical, `shuttle`
   yields 8 rows starting with the section 4 names, an empty
   needle yields all 404, a nonsense needle yields 0, and
   `587` yields 0.
10. **Install and disarm.** Seeding state with an existing
    draft, an import error, paste text, dirty editor/browser
    state, and `fittings_write_confirm =
    Some(SaveImported { .. })`, then applying the creation
    install for the Rifter (through whatever small state
    helper Builder B factors the click into, so this is
    testable without a frame), asserts: the created draft is
    installed with owner equal to the active character, error
    and paste text are cleared, `clear_editor_state`'s cleared
    values hold for editor, browser, **and ship fields**, and
    `fittings_write_confirm == None`.
11. **Demo pins.** `Rifter` (the ship of both shipped demo
    samples, `src/ui/fittings.rs:688-713`) and `Drake` list as
    candidates, and the Rifter constructs `New Rifter Fit` —
    the hulls a demo user can start from are the real 404,
    with no demo-only list. (Builder A test 3's literals may
    carry these pins; either builder landing them satisfies
    this line, but they must exist exactly once.)

## 12. Deferred (named, not built)

- **Editing a copy of a saved fitting.** Stays deferred, and
  is the natural next slice after this one now that drafts
  can be created without a parse. The blocker is unchanged
  from the editor design's deferral: no saved-to-draft
  conversion exists. The editor consumes `ImportedFitting`'s
  sectioned items with optional loaded charges, while a saved
  `CharacterFitting` carries ESI flag strings and no charges;
  turning flags back into sections (and deciding provenance
  wording, charge honesty, and what a *copy* may claim about
  its source) is its own design, not an extra button here.
  Shipping it inside this slice would have to invent that
  conversion unreviewed.
- **Ship change on an existing draft.** A created or imported
  draft keeps its hull for its whole life. Moving items to a
  new hull needs a fitment story for every carried item
  against the new ship that the shipped editor deliberately
  does not have (its only admission proof is slot-section
  membership on add). Choosing a ship therefore always starts
  empty (section 6); the user re-adds with full per-add proof.
- **Persistence of drafts.** Created drafts share the import
  draft's memory-only contract
  (`src/app/state.rs:830-833`): gone on character switch,
  removal, or close, never written anywhere except by an
  explicit Save to EVE of a non-empty draft. Local draft
  storage is its own design if ever wanted.
- Everything the editor and browser already defer stays
  deferred unchanged: drag and drop, charge editing,
  module state, move/reorder/undo, the Cargo browser tab,
  and any new blocking validation.

## 13. Code structure and builder split (locked)

### 13.1 Builder A — pure candidates and constructor

Files: `src/fitting/eft.rs` (the `Created` variant and its
doc comment only) and `src/fitting/editor.rs` (`ShipRow`,
`ship_candidates`, `new_fitting`, and the Builder A tests of
section 11). Adding the variant breaks the four exhaustive
matches in `src/ui/fittings.rs`; Builder A adds the three
issue-wording arms byte-identical to their `Eft` arms (section
5.1) so the tree compiles at the A/B boundary, and touches
nothing else in that file. The summary-line arm is Builder
B's, so at the boundary `imported_summary_line`'s `Created`
arm is also Builder A's to add — with the exact section 7.2
template — purely to keep the boundary compiling; Builder B
then owns all wording tests around it.

Commit subject (locked):
`feat(fitting): add ship candidates and blank fitting constructor`

### 13.2 Builder B — chooser panel, state, and wording

Files: `src/app/state.rs` (three fields, three reset sites,
fixture extension) and `src/ui/fittings.rs` (chooser block,
`ship_row_matches`, creation install with clearing and
disarm, the section 7.2 provenance wording, logging lines 1
and 3 — line 2 fires at the install site Builder B writes —
and the Builder B tests of section 11). Builder B does not
change the pure layer's membership, sort, or construction.

Commit subject (locked):
`feat(fitting): add new-fitting ship chooser`

### 13.3 Integrator

Merges A then B (B depends on A's public items), runs the
full verification gate (section 14), confirms the 404-count
pin and the wording literals main-side, and lands any
user-facing documentation follow-up as its own commit with
subject (locked):
`docs(fitting): document new fitting from scratch`
plus the engineering-journal entry the repo requires for the
mechanism (the format-variant provenance decision), in that
same docs commit. The integrator changes no behaviour: any
gate failure goes back to the owning builder.

## 14. Verification gate (locked)

On the final merged tree, all four, in order, with output
read — not skimmed for exit codes alone:

1. `cargo fmt --check`
2. `cargo clippy --all-targets -- -D warnings`
3. `cargo test` — the 1,047 base tests plus this slice's
   additions, zero failures, and no base test modified beyond
   the section 11 fixture extensions.
4. `cargo build`

This design commit itself was verified the same way on the
base tree (a documentation-only change must still leave all
four green).

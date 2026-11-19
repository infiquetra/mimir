# Changing a draft's ship — design

Status: locked for the `feat/rust-change-ship` slice. Base:
`develop` at `317e11f` (1,081 tests; the fitting editor, the
module browser, new-fitting-from-scratch, and editing a copy
of a saved fitting are merged there — see
`docs/fitting-editor-design.md`,
`docs/fitting-module-browser-design.md`,
`docs/new-fitting-design.md`, and
`docs/edit-saved-copy-design.md`). Slice branch:
`feat/rust-change-ship`. This document is the single design
commit; builders and the integrator implement exactly what is
locked here and nothing else.

Three designs deferred this piece by name. The editor design
deferred "Ship change and new-from-scratch fittings"
(`docs/fitting-editor-design.md` sections 2.2 and 11: "There
is no ship-picker seam in the Rust app, and swapping the hull
under a fitted item list would silently re-mean every slot,
hardpoint, and bay figure"). The new-fitting design shipped
the ship picker for starting empty drafts and repeated the
deferral: "Moving items to a new hull needs a fitment story
for every carried item" (`docs/new-fitting-design.md`
sections 2.2 and 12). The saved-copy design repeated it again
unchanged (`docs/edit-saved-copy-design.md` section 11).
This is that design, and its fitment story is the honest one
the shipped blocks already tell (section 8): items are never
re-proven against the new hull, never removed, and never
blocked; every figure is worked out again for the new ship
from the unchanged item list, and any overflow shows in the
shipped over-capacity lines. The slice it locks lets any
existing draft — imported (`Eft`/`Dna`), created
(`Created`), or copied (`Copied`) — change its ship to any
other choosable ship while keeping its name, its provenance,
every item, every loaded charge, and its import report
exactly as they are.

All file and line references are to the base tree at
`317e11f` unless a Flutter reference says `ed698d3` (the
last Flutter tree).

## 1. Goal and value ranking

Let the user put the draft they already have onto a
different ship — they imported the wrong variant's text,
picked the wrong hull at creation, or want to see the same
items on the hull they actually fly — without re-importing,
re-adding every module by hand, or discarding the draft.

Value ranking (locked, in order):

1. **Only the ship changes.** The operation assigns exactly
   two fields from one re-validated catalogue row
   (`ship_type_id`, `ship_name`). The fitting name, the
   `ImportFormat` provenance, every `ImportedItem`
   (including every stored loaded charge), and every field
   of the `ImportReport` stay byte-identical (section 3.2).
   Nothing is recounted, reworded, or "fixed up" on the way.
2. **The fitting name never changes silently.** A ship
   change never renames the draft, for any provenance — not
   even a created draft still carrying its synthesized
   `New {ship} Fit` title (section 4). Renaming remains the
   shipped rename row, one explicit click.
3. **Fitment is disclosed, never enforced.** Items that do
   not fit the new ship — too many for its slots or
   hardpoints, or subsystems on a hull that takes none —
   are kept, shown on their item rows, and counted by the
   shipped statistic blocks on the new hull (section 8).
   This slice adds no auto-removal, no refusal, and no new
   gate on copy or save.
4. **One draft, one set of downstream rules.** A changed
   draft is the same `ImportedFitting` the editor, browser,
   statistics, copy, and save blocks already consume.
   A successful change is an edit on exactly the shipped
   terms: it marks the draft edited and disarms any armed
   save through the shipped `note_successful_edit`
   (section 5.3). Picking the ship the draft is already on
   is not an edit at all (section 3.3).
5. **The shipped chooser keeps its meaning.** The
   `Start a new fitting` block above the paste box still
   starts an empty draft and still replaces the current
   draft, byte-identical. Changing ship is a second,
   separate block inside the editor, where the draft it
   edits is on screen (section 6.1).

## 2. Scope: placement and what does not ship

### 2.1 Placement (locked)

The change-ship block renders inside `fittings_import_panel`
(`src/ui/fittings.rs:3164`), inside the existing draft block:
after the owner guard (`src/ui/fittings.rs:3307-3311`) and
the working clone (`src/ui/fittings.rs:3315-3317`), inside
the edit block that opens at `Edit this fitting`
(`src/ui/fittings.rs:3332-3333`), **after the rename row**
(`src/ui/fittings.rs:3334-3355`) and **before the typed add
row** (`src/ui/fittings.rs:3356`). The two fitting-level
controls — the name and the ship — sit together, above the
item-level controls.

It therefore exists exactly when the editor exists: the
bundled catalogue loaded (the panel returns early with its
shipped load-failure sentence otherwise,
`src/ui/fittings.rs:3172-3175`), a draft is installed, and
that draft belongs to the active character. It renders for
all four provenances identically, in demo mode identically,
and while a fitting write is in flight identically — the
shipped edit controls have none of those gates, and this
slice adds none.

The placement before the local resolver, the item rows, the
write-back, the synthesis, and every statistic, copy, and
save derivation (`src/ui/fittings.rs:3471-3495`) is
load-bearing: a click's new hull is what the resolver,
`to_character_fitting()`, and everything below read in that
same frame — exactly how a rename's new name is what the
same frame's copy header prints. Builders must not move
the block below the write-back.

### 2.2 What does not ship

- No mode on the shipped chooser (section 6.1). The top
  block's heading, note, and replace-with-empty click are
  unchanged byte-for-byte.
- No confirmation before a change. Picking a row applies at
  once, as every shipped editor control applies at once
  (rename, the browser's add rows). Items survive a change,
  so the draft cannot be lost by it; and a change can
  usually be undone by picking the previous hull again —
  except when the draft's current hull is not itself a
  choosable ship (section 3.5), in which case the way back
  is re-import or re-copy. That asymmetry is accepted and
  recorded here; it does not buy a confirmation pattern
  this panel has never had.
- No per-item fitment proof against the new hull: no check
  of ship group restrictions, skill requirements, slot
  counts, hardpoints, bandwidth, fighter tubes, or bay
  volumes as an admission rule (section 8). The editor's
  only admission proof stays the add path's slot-section
  membership, unchanged.
- No auto-removal, move, or merge of items that the new
  hull cannot hold, and no charge compatibility check.
  Charges have no fitment proof data in the seams used
  here, exactly as the editor design recorded when it
  deferred charge editing.
- No subsystem-aware slot recomputation. What the slot
  layout block shows after a change is whatever it would
  show for an import of the same items on the same hull
  today, including its tech-3 suppression (section 8).
- No retitling (section 4), no provenance change, and no
  edit of any saved EVE fitting: only the in-memory draft
  changes, and saving it still creates a new EVE fitting
  through the shipped path.
- No persistence of drafts, and nothing from the deferred
  lists the editor and browser designs already carry
  (drag and drop, charge editing, module state,
  move/reorder/undo, the Cargo browser tab).

## 3. The pure change operation (locked)

### 3.1 Signature and outcome

One new pure function in `src/fitting/editor.rs`, beside
`new_fitting` (`src/fitting/editor.rs:379`):

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShipChangeOutcome {
    Changed,
    SameShip,
    Refused,
}

pub fn change_ship(
    fitting: &mut ImportedFitting,
    types: &FittingTypes,
    ship: &ShipRow,
) -> ShipChangeOutcome
```

Pure means the shipped meaning for this module
(`src/fitting/editor.rs:1-17`): no egui, no state, no
network, no database, never panics on any input. It is
**not** re-exported from `src/fitting/mod.rs`: `new_fitting`
and `ship_candidates` are not re-exported there either
(`src/fitting/mod.rs:27` re-exports only the original four
edit operations), and the panel imports the chooser family
directly from `crate::fitting::editor`
(`src/ui/fittings.rs:21-25`). Builder B imports it the same
way, aliased `change_ship as editor_change_ship` in the
shipped style.

### 3.2 Validation and assignment

Steps, in this order:

1. **Re-validate the row exactly as `new_fitting`
   validates it** (`src/fitting/editor.rs:380-387`):
   `types.lookup_by_id(ship.type_id)` must return a row
   with `category_id == CATEGORY_SHIP` (6), both outputs
   usable under `output_usable` (present, finite,
   non-negative; `src/fitting/editor.rs:196-198`), and a
   trimmed name equal to `ship.name`. Any failure: return
   `Refused` and mutate nothing. The same private
   `output_usable` helper is the rule, shared, never a
   re-spelled copy in a second place, and no weaker
   category-6-only check is allowed: a hull whose outputs
   the resources block cannot use is not a valid change
   target, for the reason the new-fitting design locked
   in its section 3.1.
2. **Same-ship check (section 3.3).**
3. **Assign the pair, from the catalogue row exactly as
   `new_fitting` assigns them** (`src/fitting/editor.rs:
   390-391`): `fitting.ship_type_id = row.type_id` and
   `fitting.ship_name = row.name.clone()` — the canonical
   name from the row keyed by type number, never the
   `ShipRow` text alone and never any UI-held text. Then
   return `Changed` and log as section 10 locks.

Nothing else is touched, field for field:

- `name`: untouched (section 4).
- `format`: untouched. An `Eft` draft stays `Eft`, a
  `Copied` draft stays `Copied`; provenance describes
  where the draft came from, and a hull change does not
  rewrite that history. No new `ImportFormat` variant is
  added, and no exhaustive match gains an arm.
- `items`: untouched — same rows, same order, same
  quantities, same `charge` on every row.
- `report`: untouched — `imported_lines`,
  `placeholder_lines`, `charges_noted`, and `issues` all
  keep their values. In particular `change_ship` does
  **not** call `recount_charges`
  (`src/fitting/editor.rs:79-85`), deliberately departing
  from the other four edit operations: those recount
  because they can change which rows carry a charge,
  while a ship change cannot, so any observable effect of
  a recount here would be silently rewriting a counter
  this operation has no business rewriting. The report
  stays byte-identical, and test 1 of section 11 pins it.
  `ImportedFitting` and `ImportReport` derive no
  `PartialEq` (`src/fitting/eft.rs:183`, `285`), so tests
  compare the report field by field, as the shipped
  construction tests do; builders do not add derives for
  test convenience.

### 3.3 Same ship is a no-op (locked decision)

When the **validated** row's `type_id` equals
`fitting.ship_type_id`, the outcome is `SameShip`:
nothing is assigned — not even `ship_name` from the
catalogue row — and the caller treats the click as if it
had not happened (section 5.3). The identity is the type
number alone: it is the draft's ship key everywhere
(`to_character_fitting` copies it,
`src/fitting/eft.rs:317`; the resolver is keyed by it,
`src/fitting/eft.rs:367`), while `ship_name` is a stored
display string whose provenance differs by format
(catalogue-canonical for parsed and created drafts,
resolver-resolved for copied drafts,
`src/fitting/eft.rs:291-294`). A same-number click that
"corrected" a copied draft's resolver name to the
catalogue spelling would be a silent rename of exactly
the kind value 2 forbids.

Validation runs **before** this check: a hand-built row
carrying the current type number under a wrong name, or
resolving to a row that fails the output proof, is
`Refused`, never blessed as a no-op. The ordering is
pinned by test 3 of section 11.

A refused-no-change with its own error text is rejected:
clicking the current hull is not a mistake to report,
the draft the user already sees *is* the requested
result, and error prose for it would be wording with
nothing to act on. Silence also keeps the armed-save
argument clean: a same-ship click leaves the save
confirmation armed because the mapping it confirms is
bit-for-bit unchanged (section 5.3).

### 3.4 The refused outcome

`Refused` is defense-in-depth for a row the listing proof
would never hand the panel, reachable only from a fixture
catalogue — the same posture as `new_fitting` returning
`None` for a listed row (new-fitting design section 5.2).
The click then does nothing to any state: no draft change,
no error text, no status message — only the locked
warning log line (section 10). Inventing user-facing
wording for a branch no test against real data can reach
is rejected on the precedent that design set.

### 3.5 Which hulls can be targets, and which can be left

The target set is the shipped choosable set:
`ship_candidates` (404 ships over the bundled catalogue,
`src/fitting/editor.rs:320-369`), re-validated per click
by section 3.2. The deliberate asymmetry the new-fitting
design locked for the chooser applies identically here:
import and copy can produce drafts on hulls outside that
set (an output-less hull imported from text, a special
hull copied from EVE), and such a draft can always change
**away** to any of the 404, but no draft can change **to**
a hull outside the 404. The current hull gets no special
injected row, no "(current ship)" marker, and no listing
exception. Builders must not unify the target set with
import's admission or invent a way back; re-import and
re-copy already are ways back.

## 4. Name policy (locked): the name never follows the hull

**A ship change never changes `ImportedFitting.name`, for
any format, ever.** There is no format branch and no
string test in `change_ship`.

The tempting alternative — when a created draft's name is
still its synthesized `New {old ship} Fit`
(`new_fitting`, `src/fitting/editor.rs:389`), rewrite it
to `New {new ship} Fit` — is rejected, for a reason the
codebase has already paid for once. Detecting "still the
default" would mean inferring provenance from a value:
`format == Created && name == format!("New {} Fit",
old_ship)`. That equality is not proof the name is the
synthesized one. The shipped `rename`
(`src/fitting/editor.rs:455-459`) stores any trimmed
text, including that exact string typed by hand, and
nothing records whether the current name was synthesized,
typed, or typed back to look synthesized. No code in the
base tree detects the `New {ship} Fit` shape at all. The
new-fitting design rejected the same move when it refused
to recognize a created draft by its all-zero counters,
because a header-only import is all-zero too (its
section 5.1); string equality here fails the same way
for the same reason. Ground the detection exactly or do
not do it: it cannot be grounded, so this design does
not do it.

Consequences, accepted and disclosed (the standing note,
section 7):

- A created Rifter draft changed to a Punisher is still
  titled `New Rifter Fit`, and the shipped summary line
  says so plainly beside the new hull:
  `Created "New Rifter Fit" (Punisher): 0 items. Edited.`
  The mismatch is visible, honest, and one rename from
  tidy. The copy EFT header likewise reads
  `[Punisher, New Rifter Fit]` until the user renames.
- Imported and copied names — chosen by whoever wrote
  the source text or saved the fitting — are obviously
  never this operation's to rewrite.
- The rename box needs no reseeding on a ship change:
  it is seeded once from `fitting.name`
  (`src/ui/fittings.rs:3339-3341`), and since the name
  did not change, whatever the box holds is still a
  draft of the current name. `apply_ship_change`
  (section 5.1) does not touch `fittings_editor_name`.

## 5. Applying a change in the panel (locked)

### 5.1 The apply helper

Builder B factors the click into a private helper in
`src/ui/fittings.rs`, beside `note_successful_edit`
(`src/ui/fittings.rs:1594`), so the bookkeeping of
section 5.3 is testable without a frame — the shipped
factoring precedent of `install_created_fitting` and
`install_copied_fitting`. Locked name and shape:

```rust
fn apply_ship_change(
    state: &mut AppState,
    imported: &mut ImportedFitting,
    catalogue: &FittingTypes,
    row: &ShipRow,
)
```

It calls `editor_change_ship(imported, catalogue, row)`
on the **working clone** (the clone taken at
`src/ui/fittings.rs:3315` and written back at `:3494`),
never on `state.fittings_imported` directly and never
through an install of a new draft. It allocates no
draft and replaces nothing. The row-click collection
mirrors the shipped chooser and browser discipline:
record the clicked `ShipRow` during row rendering, act
on it after the row loop (`src/ui/fittings.rs:3213-3221`,
`3437-3469`).

### 5.2 What a change is not

A ship change is not an install. On `Changed`,
`apply_ship_change` mutates the clone, calls
`note_successful_edit`, and does nothing else. In
particular it does **not**:

- call `clear_editor_state` (that resets the edited flag
  itself, the tab, the searches, and the caches —
  discarding editor working state the user keeps across
  every other edit),
- clear the paste text, the import error, or the owner
  (all still describe this draft),
- clear either ship search or the browser search, the
  add drafts, or the rename draft (a browser add
  clears none of these either),
- invalidate the module-browser row cache: its
  candidates are keyed by slot section and proven per
  module, never per ship, so a hull change gives the
  cache nothing to rebuild,
- set a status message (section 7).

### 5.3 Edited marking and save disarm, by outcome

- **`Changed`:** `note_successful_edit(state)`, exactly
  as rename, add, remove, and set-quantity call it
  (`src/ui/fittings.rs:3352`, `3381`, `3479-3484`). That
  one shipped helper is the whole bookkeeping: the
  draft is marked edited (`fittings_import_edited =
  true`, so the summary gains ` Edited since import.`
  for `Eft`/`Dna` and ` Edited.` for `Created`/`Copied`
  through the shipped suffix selection,
  `src/ui/fittings.rs:1569-1578`), any editor refusal
  text clears, the index-keyed quantity drafts clear
  (inherited shipped behaviour of every successful edit;
  indices do not shift here, but this slice does not
  fork the helper to special-case it), and
  `fittings_write_confirm` is cleared whole. The disarm
  is load-bearing for the reason rename's is: the armed
  confirmation is keyed by character only
  (`FittingWriteConfirm::SaveImported { character_id }`)
  and re-renders every frame from the current mapping
  (`src/ui/fittings.rs:3613-3637`), so without disarm an
  already-armed block would quietly refill with the new
  ship's name and counts and could be confirmed without
  the user ever re-reading the ship line. With disarm,
  saving takes the shipped re-arm click. No hull stamp
  is added to the confirmation state.
- **`SameShip`:** nothing. The edited flag, the editor
  error, the quantity drafts, and any armed
  confirmation all keep their values, because the draft
  and therefore the save mapping are bit-for-bit what
  they were. This is the mechanical reason a no-op is
  safe here rather than merely convenient.
- **`Refused`:** nothing, plus the section 10 warning
  line (section 3.4).

## 6. Chooser reuse: one cache, two blocks (locked)

### 6.1 A second block, not a mode

**Locked: a second chooser block inside the editor. One
block with a create/change mode is rejected.** The
shipped block's click discards the current draft and
starts empty; this slice's click keeps every item. The
same 404 rows carrying opposite consequences behind a
mode toggle is a data-loss trap for one forgotten mode,
and the mode would itself need state, a reset story at
every site in section 9.2, and two standing notes where
the panel today has one unambiguous sentence: "Starting
a new fitting replaces the fitting below, if there is
one" (`src/ui/fittings.rs:1608`). Two spatially separate
blocks make each click's meaning readable from where it
was clicked: above the paste box it starts over, inside
the editor — beside the fitting it edits — it keeps
everything. A mode is a rejected alternative, not a
builder choice. The new block is always expanded,
heading, standing note, search box, then rows, like the
block it mirrors and like the module browser; the panel
has no collapsible precedent.

### 6.2 Shared cache, separate search

Both blocks list the one `ship_candidates` set, so both
read the one shipped cache pair:

- `fittings_ship_rows: Vec<ShipRow>` and
  `fittings_ship_rows_built: bool`
  (`src/app/state.rs:875-876`) are **shared**. The list
  is built at most once per clear cycle and logged at
  most once (section 10), by whichever block renders
  first; in the shipped layout that is always the top
  block, whose build site and log line
  (`src/ui/fittings.rs:3188-3195`) are unchanged. No
  second cache and no hull key are added: the rows are
  catalogue data, identical for both blocks, and
  `ShipRow { type_id, name }` carries every value
  either click needs.
- The searches are **separate**. The top block keeps
  `fittings_ship_search` (`src/app/state.rs:874`); the
  change block gets one new field,
  `fittings_ship_change_search: String`, beside it
  (section 9.1). Typing in one never filters the other.
  Sharing one string between two simultaneously visible
  boxes is rejected: egui would show the same text in
  both, and a search typed to *start* a fitting would
  silently narrow the list used to *change* one.
- Filtering, capping, and row rendering are the shipped
  rules, applied identically: `ship_row_matches`
  (case-insensitive substring on the catalogue name,
  never the type number, `src/ui/fittings.rs:264-266`),
  recomputed per frame and never stored; rows as
  `selectable_label(false, name)` — the flag is `false`
  for every row, including the current hull's (section
  3.5) — capped at `FITTINGS_RENDER_MAX` (100,
  `src/ui/fittings.rs:60`), with the shipped overflow
  and empty wordings (section 7). The search box feeds
  `state.text_input_focused` exactly as the shipped box
  does (`src/ui/fittings.rs:3184-3187`).

Per-frame bound: two substring filters over at most 404
short names plus at most 100 rendered rows per block.
The catalogue scan itself is unchanged — at most once
until a reset clears the shared `built` flag.

Builder B may factor the shared search/filter/rows
rendering of the two blocks into one private helper
parameterized by which search string it binds, or may
render the second block beside the first in the same
shape: the mechanism is the builder's, the rendered
strings, order, caps, and click meanings are locked.
If a helper is factored, the top block must render
identically to today — its shipped tests pass
unmodified (section 11).

## 7. Verbatim wording (locked)

### 7.1 The change-ship block (new)

- Heading: `Change ship`
- Standing note, always rendered under the heading:
  `Pick a ship to move this fitting onto that ship. The fitting name, every item, and every loaded charge stay exactly as they are, and the figures below are worked out again for the new ship. Items that do not fit the new ship are kept, not removed or blocked, so remove them below if you do not want them. Picking the ship this fitting is already on changes nothing.`
  One string for all four provenances; no format branch.
  ("below" is accurate where the block sits: the item
  rows, their Remove controls, and every statistic
  block render below it, per section 2.1.)
- Search hint: `Search by name` (the shipped hint
  verbatim, `src/ui/fittings.rs:3185`).
- Overflow: `Showing {shown} of {total} ships.` (the
  shipped template verbatim,
  `src/ui/fittings.rs:3211`).
- Empty search result: `No matches.`; empty built list:
  `No ships to show.` (both shipped verbatim,
  `src/ui/fittings.rs:3202-3207`; the second is
  unreachable against the bundled 404 but keeps its
  locked wording, as it does today).
- Row label: the ship name alone, no figures, no
  current-ship suffix, never a type number.

There is **no button** (the rows are the control, as in
the shipped chooser and browser), **no status-bar
message** on any outcome, and **no error text**: a
successful change is its own feedback — the summary
line's ship name and edited suffix, and every figure
below, in the same or the next frame, exactly as a
rename needs no status. `SameShip` and `Refused` set
no `fittings_editor_error`: that field carries the
add and quantity templates (`Could not add: ...`,
`Could not set the quantity: ...`,
`src/ui/fittings.rs:1582-1589`), and this slice adds no
sibling template. The heading and note live as
constants beside `FITTINGS_SHIP_HEADING` and
`FITTINGS_SHIP_NOTE` (`src/ui/fittings.rs:1601-1608`),
named in that style; the constant names are the
builder's, the strings are not.

### 7.2 Strings that do not change

Every existing string keeps its bytes and its selection
rule. In particular, builders must not touch:

- the summary line's four arms
  (`src/ui/fittings.rs:856-885`): a change shows up
  only through the interpolated values it already
  prints — the new `ship_name`, the unchanged name,
  the unchanged item count, and, for `Eft`/`Dna`, the
  unchanged `imported_lines` parse count,
- the edited suffixes and their format selection
  (`src/ui/fittings.rs:1400-1405`, `1569-1578`),
- `draft_label`, `editor_note`, both copy buttons, and
  the save arm button (`src/ui/fittings.rs:891-939`):
  none is ship-keyed today, and none gains a ship arm,
- the placeholder and charges notes
  (`src/ui/fittings.rs:942-961`), still driven by the
  untouched counters,
- the top chooser's heading, note, hint, overflow, and
  empty wordings (`src/ui/fittings.rs:1603-1608`,
  `3182-3222`),
- every statistic block's heading, lines, disclosures,
  and unavailable sentences (section 8),
- the copy statuses, the copy-blocked statuses, the
  save confirmation's lines and the un-saveable label,
  and the demo write label.

## 8. What a change does downstream (locked)

Every consumer already derives from the draft per frame,
through the write-back, the local resolver, and the
synthesis (`src/ui/fittings.rs:3471-3495`). A consistent
pair assignment (section 3.2) is therefore the whole
integration: `to_character_fitting()` copies the new
`ship_type_id` (`src/fitting/eft.rs:317`) and
`name_resolver()` inserts the new pair
(`src/fitting/eft.rs:367`), and each consumer reads the
new hull against the unchanged items. This slice changes
no downstream guard; the notes below record what each
shipped path does with the carried-over items so no
builder adds a parallel rule.

- **Summary, notes, issues.** The summary names the new
  hull (section 7.2). The report is parse history and
  is not re-meant by this slice: the placeholder and
  charges notes, and the issues list with its quoted
  source lines, still describe the original import —
  the same frozen-counter contract every shipped edit
  already lives under, disclosed by the edited suffix
  once section 5.3 marks the draft edited.
- **Item rows.** Every row renders exactly as before,
  in the same section and order, charges attached; the
  remove and quantity controls work unchanged. Nothing
  is reclassified: sections were proven when each item
  entered (at parse, at add, or at copy conversion),
  never against a hull.
- **The eleven statistic blocks**
  (`src/ui/fittings.rs:3500-3510`) recompute on the new
  hull in the same frame: resources against the new
  outputs, rig calibration, bay usage against the new
  bays, DPS (hull identity does not affect weapon or
  charge pairing, which is section- and catalogue-rule
  driven; the new hull's drone bandwidth and fighter
  limits cap those families as shipped), cap stability,
  active repair, slot layout, and the four ship blocks
  print the new bare hull. A block with no usable data
  for the new hull shows its shipped unavailable
  sentence. Zero items is not special: an empty created
  draft may change ship (that is the wrong-hull-at-
  creation case), is marked edited, and still copies as
  a header-only/DNA-hull-only draft while save stays
  refused by the shipped empty guard.
- **Slot layout, the leftover disclosure.** Over-use
  shows in the shipped line `{label}: {used} of
  {capacity} used ({over} over)` in the over-capacity
  red (`src/ui/fittings.rs:3039-3053`, `3140-3146`),
  dimension by dimension, with the shipped
  excluded-module sentences and disclosure. Changing
  **to** one of the four subsystem hulls (type numbers
  29984 Tengu, 29986 Legion, 29988 Proteus, 29990 Loki —
  the only candidates whose `maxSubSystems` is usable)
  suppresses the high/medium/low/turret/launcher lines
  and shows rigs and subsystems plus the shipped tech-3
  sentence ("This ship's high, medium, and low slots
  and its turret and launcher hardpoints are set by its
  fitted subsystems, which are not applied here, so
  those lines are not shown.",
  `src/ui/fittings.rs:3017`). Changing **away** from a
  subsystem hull, subsystem items stay on their item
  rows for the user to remove; the slot layout block
  shows no subsystem dimension for them because the
  new hull has no usable `maxSubSystems`
  (`src/fitting/slot_layout.rs:188`, `294-298`) — which
  is already what any import carrying subsystem rows
  onto a non-subsystem hull shows today, so this slice
  introduces no new silent case, only a new way to
  arrive at an already-shipped screen. The standing
  note (section 7.1) covers the policy in advance: kept,
  not removed, not blocked.
- **Copy EFT / DNA.** The EFT header names the new hull
  through the swapped resolver pair
  (`[New Ship, Fitting Name]`); the DNA text leads
  with the new type number. Charges still count as
  left out in both statuses from the untouched
  `charges_noted`. No exporter change.
- **Save.** `build_save_request` carries the new
  `ship_type_id` verbatim (`src/fitting/write_map.rs:
  181-186`) and its kept/dropped rules do not consult
  hull capacity: items whose synthesized flags exceed
  the ESI flag ranges drop with their shipped reasons
  and pre-confirm disclosure, and the rest are sent —
  exactly what saving an over-slot import already does
  today. This slice adds no fitment gate to saving;
  whether EVE accepts an over-slot fitting is EVE's
  answer through the shipped error path, not a silent
  pre-drop here. The confirmation prints the new
  `ship_name` (`src/ui/fittings.rs:3627`) from the
  draft, which section 3.2 keeps in agreement with
  the catalogue row by construction.
- **Demo mode.** The block is fully usable in demo,
  over the same bundled 404 as the shipped chooser;
  the standing demo write label replaces the save
  affordance below, unchanged.

## 9. State fields and clearing (locked)

### 9.1 One new field

Beside the ship-chooser fields in `AppState`
(`src/app/state.rs:864-876`), inside that comment block
extended to name this design, with the same memory-only,
never-persisted contract:

- `fittings_ship_change_search: String` — the
  change-ship block's search text (section 6.2).

No other new state. There is no mode field (section
6.1), no second row cache or built flag (section 6.2),
no pending-selection or confirmation field, and no
record of the previous hull.

### 9.2 Clearing

`fittings_ship_change_search` resets to the empty string
at every site that clears `fittings_ship_search` today:

- Inside `clear_editor_state`
  (`src/ui/fittings.rs:1640-1642`), beside the three
  shipped lines. Every panel site thereby inherits the
  reset — import success and failure, **Clear import**,
  both demo samples, creation, and copy-install —
  because a change-search left filtered from a previous
  draft or character is state from a dead context, on
  the shipped reasoning for the chooser fields.
- At the three `AppState` reset sites that enumerate
  the ship fields field-for-field: character switch
  (`src/app/state.rs:1167-1169`), removal of the active
  character (`src/app/state.rs:1383-1385`), and removal
  leaving no characters (`src/app/state.rs:1451-1453`),
  in the shipped per-field style at each site.

A successful change does **not** clear it (section 5.2):
the block stays filtered as typed so the user can pick
a different nearby hull, exactly as a browser add
leaves the browser search standing. The shared rows and
built flag keep their shipped clearing; no site gains
or loses a reset for them.

The isolation fixtures (`seed_import_state` /
`assert_import_cleared` in `src/app/state.rs` tests at
`:2815-2841`, and `editor_clear_drops_all_editor_fields`
in `src/ui/fittings.rs` tests at `:8902-8939`) are
extended again, not replaced, to seed and assert the
new field, including the shipped same-character-reselect
and non-active-removal assertions that seeded values
survive (`src/app/state.rs:2849-2887`).

## 10. Logging (locked)

`[FITTING]` tag. The catalogue ship name of the target
hull is bundled data and may be logged, as creation
already logs it (`install_created_fitting`,
`src/ui/fittings.rs:1661-1664`) and the editor already
logs catalogue item names
(`src/fitting/editor.rs:110-113`). Neither search text
is ever logged, the previous `ship_name` is never logged
(for a copied draft it is resolver text, not a
re-validated catalogue row), and no type number is ever
logged. Exactly two new lines, plus reuse of shipped
ones:

1. On `Changed`, in `change_ship` in
   `src/fitting/editor.rs` beside the other editor edit
   lines, `debug` at their level (rename at
   `:458`, remove at `:411-415`):
   `[FITTING] editor ship changed ship={ship_name} items={n}`
   where `{ship_name}` is the validated catalogue row's
   name (the value just assigned) and `{n}` is
   `fitting.items.len()` — unchanged by the operation
   and logged so a reader sees the carried count.
2. On `Refused`, in `apply_ship_change` in
   `src/ui/fittings.rs`, `warn`, mirroring the creation
   refusal line ("`new fitting refused unlisted ship
   row`", `src/ui/fittings.rs:1658`) with no name,
   number, or search text:
   `[FITTING] ship change refused unlisted ship row`

`SameShip` logs nothing: nothing happened, on the
precedent of `remove_item`'s silent out-of-range return
(`src/fitting/editor.rs:405-408`). The shared cache
build keeps its shipped line, `[FITTING] ship candidates
built rows={n}` (`src/ui/fittings.rs:3191-3194`), fired
at most once per clear cycle however many blocks render
(section 6.2). Row renders, searches, and hovers in the
new block are silent, as in the shipped block. Nothing
else logs.

## 11. Test plan (locked, real-catalogue pins)

Pins run against `FittingTypes::load_bundled()`, as the
editor, browser, and chooser pins do. Catalogue figures
below were scripted from `assets/sde/fitting_types.json`
at the base: Rifter (587) high 3 / medium 3 / low 4 /
rigs 3 / turret 3 / launcher 2; Punisher (597) high 4 /
medium 2 / low 5 / rigs 3 / turret 4 / launcher 0;
Echelon (3532, a zero-output candidate) high 0 / medium
1 / low 0 / rigs 0 / turret 0 / launcher 0; Tengu (29984)
rigs 3 / subsystems 5 with the other five dimensions
suppressed. The demo sample EFT (`DEMO_SAMPLE_EFT`,
`src/ui/fittings.rs:698-717`) carries 2 low, 2 medium,
3 high (turret) with one loaded charge, 1 rig, one
drone stack, and two cargo stacks.

The regression bar: the full existing suite (1,081 tests
at base) passes unmodified except for the fixture
extensions named in tests 7 and 9. A draft that is never
ship-changed renders its summary, notes, statistics,
copy, and save blocks byte-for-byte as today; the top
chooser is untouched; the change block is one additive
block inside the editor.

Builder A (pure tests in `src/fitting/editor.rs`):

1. **Only the pair changes.** A Rifter draft parsed from
   EFT text carrying a loaded charge, an empty-slot
   marker, and one un-importable line (so every report
   field is non-trivial) is cloned, then changed to the
   Punisher candidate row: outcome `Changed`;
   `ship_type_id`/name are the Punisher pair (`597` may
   appear as a test-side number, never in a shipped
   string); `name` and `format` equal the clone's;
   `items` equal the clone's row for row, charges
   included (`ImportedItem` derives `PartialEq`); and
   `report` equals the clone's field by field —
   `imported_lines`, `placeholder_lines`,
   `charges_noted`, and every issue's fields — pinning
   section 3.2's no-recount lock.
2. **Exhaustive over the 404.** From a fresh clone of an
   item-carrying Rifter draft for each candidate: every
   row other than Rifter yields `Changed` with its pair
   assigned and `items`/`report` untouched as in test 1;
   the Rifter row yields `SameShip`. Listing proof
   composing with the change proof is pinned
   exhaustively, not sampled — the shipped construction
   test's discipline (`src/fitting/editor.rs:1063-1088`).
3. **Same-ship ordering.** Changing to the draft's own
   candidate row yields `SameShip` and leaves every
   field unchanged, the stored `ship_name` string
   included. A forged `ShipRow` with the current type
   number but a wrong name yields `Refused` (validation
   precedes the same-ship check, section 3.3), also
   changing nothing.
4. **Fixture refusals.** On the shipped fixture
   catalogue of `ship_fixture_guard_excludes_each_failure_mode`
   (`src/fitting/editor.rs:1118-1161`), changing an
   Ordinary Hull draft with forged rows for the
   category-7 row, an absent number, and the
   negative-output hull each yields `Refused` with the
   draft unchanged field by field; the one listed row
   (the draft's own hull in this fixture catalogue)
   still constructs the draft and yields `SameShip`.
5. **The name never follows.** A draft from
   `new_fitting` on the Rifter (name `New Rifter Fit`,
   full literal) changed to the Punisher still reads
   `New Rifter Fit`; an imported draft renamed by hand
   with the shipped `rename` to exactly `New Rifter Fit`
   (the section 4 collision) changed to the Punisher
   also still reads `New Rifter Fit`; an ordinary
   imported name is byte-identical after a change.
6. **Copy equivalence after a change.** A small Rifter
   draft changed to the Punisher, synthesized with
   `to_character_fitting()`, exports EFT whose first
   line is the literal `[Punisher, {its unchanged
   name}]`, and both the EFT and DNA exports re-import
   through `parse_import` to Punisher drafts with the
   same item count — pinning section 8's header/leader
   claims at the pure layer, in the shape of the shipped
   round-trip test (`src/fitting/editor.rs:1090-1116`).
   An empty created draft changed Rifter → Punisher
   likewise exports and re-imports as a zero-item
   Punisher draft.

Builder B (tests in `src/ui/fittings.rs` and
`src/app/state.rs`):

7. **Resets.** The fixtures of section 9.2 seed and
   assert `fittings_ship_change_search` across the
   switch, removal, no-character, reselect-keeps, and
   non-active-removal-keeps paths, and the shipped
   `clear_editor_state` panel test asserts the same
   cleared value after seeding it.
8. **Wording literals.** The section 7.1 heading and
   standing note asserted byte-for-byte through the
   constants/helpers the render uses; neither contains
   `587` or `597` as text. Through
   `imported_summary_line_edited`, a changed draft
   renders the shipped template with the new hull in
   full literal form for at least the `Eft` arm (with
   ` Edited since import.`) and the `Created` arm (the
   section 4 line `Created "New Rifter Fit" (Punisher):
   0 items. Edited.`), beside the shipped un-changed
   literals passing unmodified.
9. **Apply bookkeeping, by outcome.** Seeding state with
   a working draft, paste text, an editor error, a
   quantity draft, both ship searches set,
   `fittings_import_edited = false`, and
   `fittings_write_confirm =
   Some(SaveImported { character_id })`, then applying
   `apply_ship_change` three times: `Changed` (a second
   candidate) asserts the new pair, unchanged items,
   edited true, error cleared, quantity drafts cleared,
   confirm `None`, and paste text, owner, and **both
   search strings untouched**; `SameShip` (the current
   candidate) asserts edited still false and error,
   quantity drafts, and the armed confirmation all
   untouched; `Refused` (a forged row) asserts
   everything untouched. The shipped created-install
   and copied-install tests are extended to seed the
   new search and assert install clears it (their
   section 9.2 `clear_editor_state` inheritance).
10. **Slot-layout disclosure pins.** Through
    `slot_layout_lines` on the synthesized demo-sample
    draft after a change (the shipped sample-layout
    test's harness, `src/ui/fittings.rs:8206-8248`):
    Rifter → Punisher yields the literal pair list
    `Low slots: 2 of 5 used (3 left)`, `Medium slots:
    2 of 2 used (0 left)`, `High slots: 3 of 4 used
    (1 left)`, `Rigs: 1 of 3 used (2 left)`,
    `Turret hardpoints: 3 of 4 used (1 left)`,
    `Launcher hardpoints: 0 of 0 used (0 left)`, none
    over; Rifter → Echelon yields `Low slots: 2 of 0
    used (2 over)`, `Medium slots: 2 of 1 used
    (1 over)`, `High slots: 3 of 0 used (3 over)`,
    `Rigs: 1 of 0 used (1 over)`, `Turret hardpoints:
    3 of 0 used (3 over)`, `Launcher hardpoints: 0 of 0
    used (0 left)`, the five over lines carrying the
    over flag `true`; Rifter → Tengu yields exactly
    `Rigs: 1 of 3 used (2 left)` and
    `Subsystems: 0 of 5 used (5 left)` with
    `subsystem_layout` true.
11. **Demo pins.** The demo samples' Rifter and the
    Punisher, Echelon, and Tengu all list as candidates
    (already pinned for the 404; the four names asserted
    here so the pins above rest on named rows). The
    copied Demo Brawler draft (the shipped
    `DEMO_FITTINGS_JSON` + `convert_saved_fitting`
    precedent of the saved-copy tests; 11 items
    including one Subsystems-section row) changed
    Rifter → Tengu keeps all 11 items byte-identical
    and its layout shows `Subsystems: 1 of 5 used
    (4 left)`; changed Rifter → Echelon it still keeps
    the Subsystems row in `items` while the layout's
    subsystem dimension is `None` — the never-auto-remove
    pin of section 8. Tests 10 and 11 may share
    harnesses; each literal exists exactly once.

## 12. Deferred (named, not built)

- **Fitment-guarded ship change.** Refusing, warning
  with a confirm step, or auto-removing items the new
  hull cannot hold needs per-item fitment rules (ship
  groups, skill gates, subsystem-granted slots) the
  catalogue seams here do not carry; the editor design
  already defers any new blocking validation, and this
  slice keeps disclosure as the whole story (section 8).
- **Subsystem-aware statistics.** Applying fitted
  subsystems' slot, hardpoint, and bonus effects is
  deferred by every statistic block today, for changed
  and never-changed drafts alike; a hull change makes
  that pre-existing gap no wider.
- **Charge compatibility.** Whether a kept charge can
  load in its module on the new hull has no proof data;
  charge editing itself stays deferred.
- **Changing to a non-candidate hull** (section 3.5)
  and any current-hull listing exception.
- **A create/change mode on one chooser** (section 6.1),
  favourites and recently-used ordering in either
  chooser, and group/tree/figure browsing of ships.
- Everything the editor, browser, and chooser already
  defer stays deferred unchanged: drag and drop,
  module state, move/reorder/undo, the Cargo browser
  tab, draft persistence, and editing a saved fitting
  in place.

## 13. Code structure and builder split (locked)

### 13.1 Builder A — pure change operation

Files: `src/fitting/editor.rs` only — `ShipChangeOutcome`,
`change_ship` beside `new_fitting`, the section 10 line 1
log, and Builder A tests 1–6 of section 11. No
`src/fitting/eft.rs` change (no format variant, no new
derive), no `src/fitting/mod.rs` change (section 3.1),
and no UI change: adding two public items to an already
public module breaks no exhaustive match, so the tree
compiles at the A/B boundary with exactly this file
touched.

Commit subject (locked):
`feat(fitting): add pure ship change for fitting drafts`

### 13.2 Builder B — editor block, state, and bookkeeping

Files: `src/app/state.rs` (the section 9.1 field, the
three reset sites, the fixture extension) and
`src/ui/fittings.rs` (the section 2.1 block with its
shared-cache reads, the section 7.1 constants,
`apply_ship_change` with the section 10 line 2 log, the
`clear_editor_state` line, the `editor_change_ship`
import, and Builder B tests 7–11). Builder B does not
change the pure layer's validation, outcome semantics,
candidates, or construction, and does not alter the top
chooser's rendering beyond the section 6.2 optional
helper factoring under its byte-identical condition.

Commit subject (locked):
`feat(fitting): add change-ship control to fitting editor`

### 13.3 Integrator

Merges A then B (B depends on A's public items), runs
the full verification gate (section 14), confirms the
404-count pin, the exhaustive change pin, the slot-layout
literals, and the wording literals main-side, and lands
any user-facing documentation follow-up as its own
commit with subject (locked):
`docs(fitting): document changing a draft's ship`
plus the engineering-journal entry the repo requires for
the mechanism (the byte-identical carry-over contract
and the no-recount/no-retitle decisions), in that same
docs commit. The integrator changes no behaviour: any
gate failure goes back to the owning builder.

## 14. Verification gate (locked)

On the design commit, and again on the final merged
tree, all four, in order, with output read — not skimmed
for exit codes alone:

1. `cargo fmt --check`
2. `cargo clippy --all-targets -- -D warnings`
3. `cargo test` — the 1,081 base tests plus this slice's
   additions, zero failures, and no base test modified
   beyond the fixture extensions of tests 7 and 9.
4. `cargo build`

This design commit itself was verified the same way on
the base tree (a documentation-only change must still
leave all four green).

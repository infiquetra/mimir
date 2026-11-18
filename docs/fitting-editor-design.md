# Fitting editor (first slice: edit the imported fitting) — design

Status: locked for the `feat/rust-fitting-editor` slice.
Base: `develop` at `789934e` (1,019 tests; fitting import,
copy-back, EVE write, slot layout, resources, calibration, bay
usage, damage per second, capacitor stability, active repair,
ship base statistics, resistances, effective hit points, and
navigation/targeting are all merged there — see the earlier
fitting design documents in this directory). Slice branch:
`feat/rust-fitting-editor`. This document is the single design
commit; builders and the integrator implement exactly what is
locked here and nothing else.

## 1. Goal and value ranking

Let the user change an imported fitting before copying or saving
it: add items by exact catalogue name, remove items, change
stacked quantities, and rename the fitting — all against the
in-memory import draft that already exists, so the edited fitting
flows into the existing copy and save paths with zero new write
plumbing. Every statistic block already pure-computes from the
fitting each frame, so an edit is visible in every readout on the
next frame with no new calculation code.

Value ranking (locked, in order):

1. **Never guess a slot, and never edit anything but the
   draft.** An added item enters a slot section only when the
   bundled catalogue's dogma slot effects prove that slot
   (section 3). Anything unproven is refused in words, never
   placed in a likely-looking section. Saved EVE fittings are
   never mutated by this slice (section 2.2).
2. **The edited fitting is the fitting every downstream path
   sees.** Copy, save, and every statistic block consume the
   same edited draft through the synthesis they already run
   (section 5). No second representation, no cached copy that
   can drift, and an armed save confirmation never survives an
   edit (section 5.3).
3. **Reuse the importer's rules verbatim.** Name lookup, slot
   proof, stacked-item classification, and quantity bounds are
   the importer's, called or mirrored exactly (sections 3 and
   4). One grammar for "what may enter a fitting", not two.

## 2. Scope: what the seams honestly support

### 2.1 The edit target (locked)

The editor mutates exactly one thing: `AppState.fittings_imported:
Option<ImportedFitting>` (the import design's draft fields at
`src/app/state.rs:833-836`). That draft is memory-only, never
persisted, never inserted into the saved-fittings data, and
cleared on character switch and removal. Its items are
`ImportedItem { type_id, name, section, quantity, charge }`
(`src/fitting/eft.rs:245-253`); quantity is always 1 for slot
sections and a merged total for stacked sections.

Everything downstream already derives from the draft per frame:
`ImportedFitting::to_character_fitting()` (`src/fitting/eft.rs:
278-326`, called at `src/ui/fittings.rs:2716`) synthesizes the
`CharacterFitting` the renderer, exporters, statistics, and save
mapper consume, and `ImportedFitting::name_resolver()`
(`src/fitting/eft.rs:332-343`) supplies the canonical names.
Editing `items` (and `name`) is therefore the whole integration:
flags are assigned by the synthesis counters, never by the
editor (section 3.3).

### 2.2 What is not edited (locked, with reasons)

- **Saved EVE fittings, in place.** The only wired write
  endpoints are create and delete (the fitting-write design);
  there is no update path on the EVE side to write an edit back
  to. The saved-fitting detail gains no edit controls.
- **A copy of a saved fitting as a new draft.** Deferred, not
  silently approximated. Converting a saved fitting would have
  to fabricate an import report (lines, placeholders, issues)
  for a fitting that was never imported, and saved fittings
  carry no loaded-charge data to carry over. It ships only with
  its own design that keeps that provenance honest.
- **The ship.** The draft's ship comes from the import header,
  resolved to a category-6 (ship) catalogue row at parse time.
  There is no ship-picker seam in the Rust app, and swapping
  the hull under a fitted item list would silently re-mean
  every slot, hardpoint, and bay figure. Deferred (section 11).
- **Creating a fitting from nothing.** A draft exists only
  after a successful import (including the demo samples).
  "New empty fitting on a chosen ship" needs the ship picker
  above; deferred with it.

### 2.3 Operations (locked exhaustive list)

Exactly four operations ship:

1. **Add an item by exact name**, in two shapes mirroring the
   import grammar: no quantity means one fitted slot item
   (section 3.1); a quantity means a stacked drones/fighters/
   cargo entry (section 3.2).
2. **Remove an item row** — the whole row, charge included
   (section 4.2).
3. **Set a stacked row's quantity** to a typed absolute value
   (section 4.3). Slot rows have no quantity control.
4. **Rename the fitting** (section 4.4).

There is no reorder, no move between sections, no duplicate
button, and no undo. Section 11 names each deferred piece.

## 3. Adding items: slot-effect proof or refusal

All add logic is pure and lives with the importer (section 8.1).
The name is resolved by `FittingTypes::lookup` (trim, collapse
whitespace, lowercase-insensitive exact match;
`src/names/fitting_types.rs:420-434`) — the same lookup the
importer uses. User-typed text is never logged (section 7).

### 3.1 Slot adds (no quantity typed)

Mirror `classify_module` (`src/fitting/eft.rs:388-406`) exactly:

1. `lookup` returns Unknown → refuse `UnknownName`.
2. Ambiguous → refuse `AmbiguousName`.
3. Found row whose `category_id` is neither 7 (module) nor 32
   (subsystem) → refuse `NotAModule`.
4. `slot_section(&row.slot_effects)` (`src/fitting/eft.rs:
   361-375`) checks dogma effects 12 (high), 13 (medium), 11
   (low), 2663 (rig), 3772 (subsystem), in that order. `None`
   → refuse `NoSlotForModule`. **This is the slot proof: an
   item whose slot cannot be proven from shipped
   `slot_effects` data is refused, never guessed into a
   section.**
5. On success, append `ImportedItem { type_id: row.type_id,
   name: row.name.clone() (canonical catalogue name, never the
   typed text), section, quantity: 1, charge: None }`.

Duplicate slot items are allowed (import allows the same module
on many lines; each is its own fitted slot). Capacity is not a
gate: import never refuses an over-slot fitting, and the slot
layout block discloses overage (section 5.2). The editor adds no
capacity, hardpoint, group, or skill gate of its own.

### 3.2 Stacked adds (a quantity typed)

Mirror the importer's stacked step (`src/fitting/eft.rs:
633-672`) exactly:

1. The quantity must satisfy the same rule as
   `parse_stack_quantity` (`src/fitting/eft.rs:447-457`): first
   digit 1–9, at most 10 digits, at most 2,147,483,647
   (`MAX_STACK_QUANTITY`). Anything else → refuse
   `InvalidQuantity`.
2. `lookup` Unknown/Ambiguous → refuse as in 3.1.
3. Section by `category_id`: 18 → Drones, 87 → Fighters, 7 or
   32 → refuse `StackedModule`, anything else → Cargo. This is
   the importer's rule verbatim, including that a charge or any
   other catalogue item lands in Cargo; the editor invents no
   extra refusal the importer does not have.
4. Merge by type like `absorb_stack` (`src/fitting/eft.rs:
   462-489`): an existing stacked row of the same type absorbs
   the quantity; if the sum would exceed `MAX_STACK_QUANTITY`
   → refuse `QuantityTooLarge` and change nothing. DNA-imported
   drafts hold one row per unit (`quantity: 1`, never merged);
   merging into the first matching row is still correct because
   export aggregates stacked rows by type.

### 3.3 Flag assignment (unchanged, restated)

The editor never writes a flag string. `to_character_fitting`
assigns `LoSlot{n}` / `MedSlot{n}` / `HiSlot{n}` / `RigSlot{n}` /
`SubSystemSlot{n}` by per-section counters in item order, and
the bare `DroneBay` / `FighterBay` / `Cargo` flags for stacked
sections. Removing a slot item therefore renumbers later items
in that section on the next synthesis — the same renumbering
import already produces for a shorter paste. Flags are never
rendered (the fittings module's standing promise), so this is
invisible except through order in the item list.

## 4. Remove, quantity, rename, and the report counters

### 4.1 New editor state (locked fields)

Four sibling fields beside the import fields in `AppState`, all
memory-only, all cleared at every site that clears
`fittings_imported` today (character switch, character removal,
auth reset — `src/app/state.rs:1113-1116`, `1316-1319`,
`1371-1374` — plus the panel's Clear import, demo-sample, and
new-import paths, section 6):

- `fittings_editor_add_name: String` — the add box text.
- `fittings_editor_add_quantity: String` — the optional
  quantity box text (empty means a slot add).
- `fittings_editor_error: Option<String>` — the last refusal
  wording, rendered under the add box; cleared on any
  successful edit and whenever the draft is cleared/replaced.
- `fittings_import_edited: bool` — true after the first
  successful edit of the current draft; drives the edited
  wording in section 6.3.

### 4.2 Remove

Each rendered draft row gains a remove control (section 6.2).
Removing deletes the whole `ImportedItem` at that index. A slot
row's loaded charge (`ImportedItem.charge`) exists only on that
row — charges have no row of their own and never enter the
synthesized fitting — so removing a charged module removes its
charge with it. That is disclosed once, in the standing editor
note (section 6.3), not per click; there is no confirmation and
no undo (re-import restores the original).

### 4.3 Set stacked quantity

Stacked rows (Drones, Fighters, Cargo) gain a quantity text box
prefilled with the current quantity and a set control. The
typed value must satisfy the section 3.2 step-1 rule; anything
else refuses with the `InvalidQuantity` wording and changes
nothing. Setting a quantity replaces the row total (it is not
an increment). To remove a stacked row entirely the user
removes the row (4.2); quantity 0 is refused, matching the
import grammar, which has no zero-quantity line. Slot rows
render their fixed quantity as today and gain no control:
their quantity is 1 by construction.

### 4.4 Rename

A name text box prefilled with `ImportedFitting.name` and an
apply control set `name` to the trimmed text. Empty is allowed
(the header name may already be empty, and every consumer has a
display fallback; the save mapper substitutes its own fallback
name when saving). The ship name is not editable (2.2).

### 4.5 Report counters after an edit (locked)

`ImportReport { imported_lines, placeholder_lines,
charges_noted, issues }` (`src/fitting/eft.rs:161-168`) is
parse history. After any successful edit:

- `charges_noted` is **recounted** as the number of items with
  `charge.is_some()`. It feeds live disclosures (the charges
  note, both copy status messages, the save confirmation's
  charges line), so it must describe the current draft, never
  the parse.
- `imported_lines`, `placeholder_lines`, and `issues` stay
  frozen as the record of the paste. They stop describing the
  item count, which is why the summary line changes once edited
  (section 6.3) instead of these counters being rewritten to
  pretend the paste said something else.

## 5. Recomputation and the existing flows (unchanged)

### 5.1 Every statistic block recomputes for free

The imported detail re-derives `synth =
imported.to_character_fitting()` and `local_resolver =
imported.name_resolver()` every frame (`src/ui/fittings.rs:
2716-2718`) and feeds the same pure functions the saved detail
uses: `fitting_resources_with_skills`, `rig_calibration`,
`bay_usage`, `fitting_dps`, `fitting_cap_stability`,
`fitting_active_repair`, `slot_layout`, `ship_base_stats`,
`ship_resistances`, `ship_base_ehp`, `ship_nav_targeting`
(render calls at `src/ui/fittings.rs:2728-2738`). An edit
mutates `items`; the next frame's synthesis carries it into all
of them. No statistic function changes, and none may cache
across edits. Two call sites deserve naming:

- `fitting_dps` also receives `Some(&imported)` for loaded
  charges, so removing a charged module (4.2) correctly drops
  its charge contribution on the next frame, automatically.
- `slot_layout` recounts distinct flags, so renumbering (3.3)
  and over-slot adds (3.1) are reflected exactly; the editor
  adds no slot counting of its own.

### 5.2 Validation posture (locked: disclose, never block)

The editor adds no blocking validation beyond name resolution,
slot proof, and quantity bounds. Over-slot, over-CPU (central
processing unit), over-power-grid, over-calibration, hardpoint
overflow, and untrained skills remain display-only disclosures
in their existing blocks — the same posture import has today
(an imported fitting can already be all of those). The one hard
gate downstream stays where it is: the save mapper's refusals
(no ship, no saveable items, more than 512 items), surfaced by
the existing unsaveable label.

### 5.3 Copy and save flows (unchanged, one disarm rule)

Edited drafts reach the existing buttons untouched: "Copy
imported fitting as EFT" / "Copy imported fitting as DNA" run
`fitting_to_eft(&synth, &local_resolver)` / `fitting_to_dna(
&synth)`, and "Save imported fitting to EVE..." runs
`build_save_request(&synth)` through the armed confirmation
into the existing write flight. Added items copy and save like
imported ones because they are the same rows; charges stay
excluded from copy and save exactly as today, with the recount
(4.5) keeping every charges-left-out disclosure truthful.

**Disarm rule (new, locked):** any successful edit sets
`state.fittings_write_confirm = None`. The armed confirmation
already recomputes its mapping per frame, so it would never
send stale bits — but a user must never confirm one fitting
and send an edited other. Editing while armed silently returns
to the arm button; the user re-arms and re-reads. A write
already in flight is unaffected (it carries its own request).

### 5.4 Raw identifiers

Nothing new can leak: added rows store the canonical catalogue
name, rendering goes through the local resolver as today,
refusal wording is fixed strings, and no control ever shows a
type number or flag string. The DNA clipboard text remains the
one deliberate numbers-only format, unchanged.

## 6. User interface and verbatim wording

All controls live inside the existing imported-fitting detail
in `fittings_import_panel` (`src/ui/fittings.rs:2609`), under
the same owner guard: they render only when the draft belongs
to the active character. No saved-fitting surface changes.

### 6.1 Layout (locked order)

After the existing summary line and notes, before the item
list: an "Edit this fitting" heading, the standing editor note
(6.3), the rename row, then the add row. Remove controls sit on
each item row; the quantity box sits on each stacked row. The
statistic blocks, loaded-charges list, issues list, and copy/
save buttons keep their current order below.

### 6.2 Controls (verbatim)

- Heading: `Edit this fitting`
- Name box hint: `Fitting name`; button: `Rename fitting`
- Add name box hint: `Exact item name, like Damage Control II`
- Add quantity box hint: `Quantity (drones, fighters, cargo only)`
- Add button: `Add item` — enabled only when the name box is
  non-empty after trimming.
- Per-row remove button: `Remove`
- Per-stacked-row quantity button: `Set quantity`

### 6.3 Standing notes and the edited summary (verbatim)

Standing note under the heading, always shown while a draft is
shown:

> Edits change only this imported fitting in Mimir. Nothing is
> sent to EVE unless you save below. Removing a module also
> removes its loaded charge. Items can be added only when
> Mimir's bundled data proves which slot they fit.

Once `fittings_import_edited` is true, the summary line
(`Imported "name" (Ship): N items from M lines.`) gains the
suffix ` Edited since import.` and the `Imported fitting`
label stays. The frozen line/segment count remains in the
summary — with the suffix it is honest parse history, not a
claim about the current rows.

### 6.4 Refusals (verbatim)

Every refusal renders in `fittings_editor_error` as
`Could not add: {reason}.` for adds, or `Could not set the
quantity: {reason}.` for quantity sets, where `{reason}` is
the importer's fixed `ImportIssueKind::reason()` string
(`src/fitting/eft.rs:101-159`) for the same condition:

- unknown name → "no item in Mimir's bundled data has this
  exact name"
- ambiguous name → "this name matches more than one item in
  Mimir's bundled data"
- not a module → "this item is not a fitted module; drones,
  fighters, and cargo need a quantity suffix like x5" (in the
  editor: "type a quantity to add it in bulk instead" is NOT
  added — the importer's sentence is reused verbatim so the
  two surfaces never drift; the quantity box hint carries the
  editor-specific guidance)
- no provable slot → "Mimir's bundled data does not say which
  slot this module fits"
- stacked module → "modules are listed once per fitted slot,
  without a quantity suffix like x5"
- bad quantity → "the quantity must be a whole number from 1
  to 2,147,483,647, written like x5"
- merge overflow → "the combined quantity for this item would
  exceed 2,147,483,647"

Rename has no refusal. Remove has no refusal. A refusal changes
no state except `fittings_editor_error` itself.

### 6.5 Draft lifetime and demo behavior (locked)

An edited draft dies exactly when an unedited one does, with
no warning and no "unsaved edits" prompt — the import design's
lifetime is the editor's: switching characters, removing the
active character, "Clear import", either demo-sample button, a
new import (success replaces the draft; a fatal clears it), and
closing Mimir all discard edits along with the draft. The
standing import note already tells the user the fitting "is
gone when you switch characters or close Mimir"
(`src/ui/fittings.rs:2616`); it is not reworded.

Demo mode: the editor is fully usable in demo (import already
is, and the samples exist so demo users can try exactly this).
Copy buttons work as today. The one demo restriction is
unchanged and already worded: the save affordance renders
`Demo mode uses sample data. Saving or deleting fittings in
EVE is disabled.` and no write starts. The editor adds no
demo-specific wording and no demo-only gating.

## 7. Logging (locked)

Every new log line uses the `[FITTING]` tag and carries counts
and fixed tokens only — never typed text, never pasted
contents, matching the importer's standing rule
(`src/fitting/eft.rs:12-14`). Canonical catalogue names of
successfully added items may be logged (bundled data, not user
input); refused names are never logged. Locked lines:

- `[FITTING] editor item added name={canonical} section={:?} items={total}`
- `[FITTING] editor add refused kind={:?}`
- `[FITTING] editor item removed items={total} charges={recounted}`
- `[FITTING] editor quantity set items={total}`
- `[FITTING] editor quantity refused`
- `[FITTING] editor renamed`

## 8. Code structure and builder split (locked)

### 8.1 Builder A — pure editor core

New module `src/fitting/editor.rs` (registered in
`src/fitting/mod.rs`), pure like its siblings: no egui, no
state. It reuses `classify_module`'s logic; to avoid
duplicating the classification, A makes `classify_module`,
`ModuleOutcome`, `parse_stack_quantity`, and `absorb_stack`
`pub(crate)` in `src/fitting/eft.rs` (visibility only, no
behavior change) and calls them.

Locked surface:

- `pub enum EditRefusal { UnknownName, AmbiguousName,
  NotAModule, NoSlotForModule, StackedModule, InvalidQuantity,
  QuantityTooLarge }` with `reason()` delegating to the
  matching `ImportIssueKind::reason()`.
- `pub fn add_item(fitting: &mut ImportedFitting, types:
  &FittingTypes, name: &str, quantity: Option<&str>) ->
  Result<(), EditRefusal>` — `None` quantity runs section 3.1,
  `Some` runs 3.2; on success recounts charges (4.5; a no-op
  for adds, kept uniform).
- `pub fn remove_item(fitting: &mut ImportedFitting, index:
  usize) -> bool` — false (no change) when out of range; on
  success recounts charges.
- `pub fn set_quantity(fitting: &mut ImportedFitting, index:
  usize, quantity: &str) -> Result<(), EditRefusal>` — refuses
  `InvalidQuantity` for slot rows and bad values alike; the
  row-kind distinction needs no separate wording because slot
  rows render no control (4.3).
- `pub fn rename(fitting: &mut ImportedFitting, name: &str)`
  — trims and stores.

Commit subject (locked): `feat(fitting): add pure fitting editor core`

### 8.2 Builder B — state and panel

`src/app/state.rs`: the four fields of section 4.1, initialized
empty/false/None, cleared at the three existing reset sites.
`src/ui/fittings.rs`: the section 6 controls inside
`fittings_import_panel`; row controls threaded through the
imported item rendering only (the saved detail's rendering is
untouched); the disarm rule (5.3); `fittings_import_edited`
set on any successful edit; editor fields cleared on Clear
import, both demo-sample buttons, and every new import outcome
(success or fatal). Per-frame clone discipline follows the
panel's existing pattern: mutate a clone or record intents,
write back after rendering, never hold the borrow across
egui calls.

Commit subject (locked): `feat(fitting): edit imported fittings in the panel`

### 8.3 Integrator

- Merge A then B; resolve nothing by redesign.
- `docs/engineering-journal/LEARNINGS.md` entry if the build
  surfaces a non-obvious mechanism; otherwise none.
- Full gate on the merged tip (section 10), pushing nothing
  without instruction.

## 9. Test plan (locked, real-catalogue pins)

All pins run against `FittingTypes::bundled()` — no synthetic
catalogue — following the existing catalogue tests. Pinned rows
(verified in the bundled catalogue during design): Rifter
(type number 587, ship), Damage Control II (low slot, effect
11), Hobgoblin II (2456, drone); the demo sample block
(`src/ui/fittings.rs:650-669`) additionally proves 200mm
AutoCannon II (high), Small Armor Repairer II (low), 1MN
Afterburner II and Warp Scrambler II (medium), Small Projectile
Burst Aerator I (rig), and EMP S / Nanite Repair Paste (cargo)
resolve issue-free.

Builder A (unit tests in `src/fitting/editor.rs`):

1. Slot add of "Damage Control II" appends one Low row with
   the canonical name and quantity 1, and `to_character_fitting`
   gives it the next `LoSlot{n}` flag.
2. Each section proven from real effects: one add each lands
   in High (200mm AutoCannon II), Medium (1MN Afterburner II),
   Low (Damage Control II), Rig (Small Projectile Burst
   Aerator I).
3. Slotless refusal: a category-7 row with empty
   `slot_effects`, found in the bundled catalogue at build
   time and pinned by literal name in the test, refuses
   `NoSlotForModule` and changes nothing. (A must pin the
   discovered literal; if no such published row exists, A
   reports that instead of fabricating one.)
4. Unknown and ambiguous names refuse and change nothing;
   "Damage Control" (no such exact name) pins Unknown.
5. A drone name without quantity ("Hobgoblin II") refuses
   `NotAModule`; with quantity "5" it lands in Drones.
6. Stacked merge: adding Hobgoblin II x2 then x3 yields one
   row of 5; a merge crossing 2,147,483,647 refuses
   `QuantityTooLarge` with the earlier quantity intact.
7. A module with a quantity refuses `StackedModule`; bad
   quantities ("0", "x5", "2147483648", "05") refuse
   `InvalidQuantity`.
8. Cargo add of "Nanite Repair Paste" x8 lands in Cargo.
9. Remove deletes the row and its charge: import the demo
   sample, remove the charged 200mm AutoCannon II row, charges
   recount to 0 — and the imported-lines/placeholder counters
   stay at their parse values (4.5).
10. Remove renumbers: after removing the first of three high
    modules, the synthesized flags are `HiSlot0..HiSlot1` for
    the survivors in order.
11. `set_quantity` replaces a stacked total, refuses on a slot
    row, and refuses "0".
12. Round trip: an edited draft copied through
    `fitting_to_eft` re-imports to the same item multiset
    (charges excluded, as copy already discloses).

Builder B (state/panel tests):

13. Editor fields clear on character switch alongside the
    import fields (extend the existing switch test at
    `src/app/state.rs:2705`).
14. The edited suffix appears only after a successful edit;
    the refusal templates render the importer's reason strings
    verbatim (string equality against `ImportIssueKind::
    reason()`).
15. Arming the save confirmation, then editing, disarms it
    (5.3); an untouched draft's arm-confirm-send flow is
    byte-identical to today.

Regression: the full existing suite (1,019 tests at base) must
pass unmodified except for test 13's extension; an unedited
import renders byte-for-byte as today.

## 10. Verification gate (locked)

On the design commit and again on the merged slice tip:

```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
cargo build
```

## 11. Deferred (named, not built)

- Drag and drop, click-to-equip browsers, and any item picker
  or search beyond the exact-name box (no browse seam exists;
  fuzzy search would also break the importer's exact-name,
  never-guess contract).
- Charge editing: adding, changing, or removing a loaded
  charge on its own. Charges are display-only, excluded from
  copy and save, and have no fitment proof data (no
  charge-group compatibility in the catalogue seams used
  here).
- Ship change and new-from-scratch fittings (2.2).
- Editing a copy of a saved fitting (2.2).
- Module state (online/offline/overheated), move/swap/
  reorder, duplicate-row, undo/redo.
- Any new blocking validation (capacity, hardpoints, groups,
  skills) beyond section 5.2's disclosures.
- Persisting drafts or edits anywhere (local or EVE update).


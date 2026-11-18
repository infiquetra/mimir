# Editing a copy of a saved fitting — design

Status: locked for the `feat/rust-edit-saved-copy` slice.
Base: `develop` at `4fe0c84` (1,056 tests; the fitting
editor, the module browser, and new-fitting-from-scratch are
merged there — see `docs/fitting-editor-design.md`,
`docs/fitting-module-browser-design.md`, and
`docs/new-fitting-design.md`). Slice branch:
`feat/rust-edit-saved-copy`. This document is the single
design commit; builders and the integrator implement exactly
what is locked here and nothing else.

The editor design deferred this piece by name: converting a
saved fitting "would have to fabricate an import report
(lines, placeholders, issues) for a fitting that was never
imported, and saved fittings carry no loaded-charge data to
carry over. It ships only with its own design that keeps that
provenance honest" (`docs/fitting-editor-design.md` section
2.2). The new-fitting design repeated the deferral unchanged
(`docs/new-fitting-design.md` sections 2.2 and 12). This is
that design. The slice it locks converts one selected saved
fitting into a new in-memory draft the shipped editor can
edit. The draft, if saved at all, saves as a **new** EVE
fitting through the shipped save path; the saved fitting it
was copied from is never overwritten, because EVE has no
update endpoint for the app to use even by accident (the
fitting-write design's create-and-delete surface).

All file and line references are to the base tree at
`4fe0c84`.

## 1. Goal and value ranking

Let the user open a saved fitting, click one button, and land
in the shipped editor and module browser with a draft holding
that fitting's ship and items — without pasting an EFT export
of their own fitting back into Mimir, and without the draft
ever pretending to be the saved fitting, an import, or a
from-scratch creation.

Value ranking (locked, in order):

1. **No silent loss, no invented data.** Every row of the
   saved fitting either converts faithfully or is counted in
   a named, user-visible skip disclosure that rides on the
   draft (section 3). Nothing is guessed: not a name, not a
   slot, not a quantity, not a loaded charge.
2. **Honest provenance.** A copied draft carries a fourth
   format value (section 3.5), and every user-visible string
   that today says "imported" or "created" gets a locked
   copied wording or an already-neutral wording (section 6).
   The draft saves as a new EVE fitting, and the save
   confirmation for a copied draft says the saved fitting it
   was copied from stays as it is (section 6.3).
3. **One draft, one set of downstream rules.** A copied
   draft is the same `ImportedFitting` the editor, browser,
   statistics, copy, and save blocks already consume, and it
   installs exactly as a created draft installs — owner,
   paste-text clearing, whole-field disarm, and
   editor/browser/ship clearing included (section 5). This
   slice adds no new state field and no new downstream guard.
4. **The saved fitting is read-only here.** The conversion
   reads the selected `CharacterFitting` and nothing else.
   The original's save-a-copy and delete affordances keep
   working exactly as shipped; installing a copy disarms
   them (section 5) so no armed confirmation can be
   confirmed against a screen the user has mentally moved
   on from, but re-arming is one click, unchanged.

## 2. Scope: placement and what does not ship

### 2.1 Placement (locked)

The control renders inside the selected saved fitting's
detail (`src/ui/fittings.rs:3624-3867` at base), **after**
`Copy as DNA` (`src/ui/fittings.rs:3708`) and **before** the
write affordances block (`src/ui/fittings.rs:3742`). It is
therefore visible exactly when a detail is visible: a fitting
is selected and present in the loaded list. Two gates and no
others:

- **Catalogue present.** `fitting_types` is `Some`. The
  conversion itself needs no catalogue (section 3.4), but the
  draft it installs renders only inside
  `fittings_import_panel`, which returns early with its
  shipped load-failure sentence when the catalogue failed
  (`src/ui/fittings.rs:3024-3027`). Offering a button whose
  result cannot appear would be a silent no-op; with no
  catalogue the import panel already explains the failure
  once, and the detail simply has no edit-a-copy button.
- **Active character present.** `state.active_character_id`
  is `Some`, because the install stamps that character as the
  draft owner (section 5) and the draft block renders only
  under its owner guard (`src/ui/fittings.rs:3159-3163`). The
  saved list itself only loads for an active character, so
  this gate is expected to be always-true where a detail
  renders; it is locked anyway so the install never stamps a
  `None` owner beside a `Some` draft.

The button is **not** a write affordance: it is not gated by
`write_enabled`, it is not replaced by the in-flight row, and
it is **not** hidden in demo mode. Installing a draft sends
nothing to EVE; the shipped chooser and module browser are
likewise fully usable in demo (new-fitting design section 8,
module-browser design section 11), and the demo pins of
section 4 exist so a demo user can exercise this slice end
to end against the shipped sample fittings.

The draft installs into `state.fittings_imported`, which
renders in the import panel **above** the saved list
(`src/ui/fittings.rs:3539` renders the panel before the
saved-fittings match). The click therefore happens below the
place its result appears, which is why — alone among the
three draft doors — this install sets a status message
(section 6.1). No scrolling, focus, or navigation behaviour
is added; the app has no precedent for it and the status line
plus the summary line at the draft block are the feedback.

### 2.2 What does not ship

- No editing the saved fitting itself, and no write-back.
  The saved detail gains no remove, quantity, rename, or add
  controls; EVE's fitting endpoints are create and delete,
  so there is still nothing to write an edit of the original
  to (editor design section 2.2, unchanged).
- No second draft slot. A copied draft replaces the current
  draft — imported, created, or copied — on the same
  no-confirmation terms as every shipped replacement
  (section 5).
- No persistence. A copied draft shares the memory-only
  contract of every draft: gone on character switch,
  character removal, or close (section 8).
- No description carry-over. `ImportedFitting` has no
  description field for any provenance (section 3.5 names
  this as a known non-carry, as it already is for the
  shipped save-an-import path); adding one for copied drafts
  only would fork the draft model for a notes string.
- No charge synthesis. Saved fittings carry no loaded-charge
  data (section 3.4); nothing in this slice assumes a charge
  for any module.
- No change to save-a-copy. The shipped one-click
  save-a-copy of the unedited original
  (`src/ui/fittings.rs:3817-3845` at base) is a different,
  already-working path and keeps its button, its
  confirmation, and its dropped-item disclosures untouched.

## 3. The pure conversion (locked)

One new pure function in one new module,
`src/fitting/saved_copy.rs`, re-exported from
`src/fitting/mod.rs`:

```rust
pub enum SavedCopyOutcome {
    Converted(ImportedFitting),
    Refused(SavedCopyRefusal),
}

pub enum SavedCopyRefusal {
    NoShip,
    ShipUnnamed,
}

pub fn convert_saved_fitting(
    source: &CharacterFitting,
    resolver: &NameResolver,
) -> SavedCopyOutcome
```

Pure means the shipped meaning: no egui, no state, no
network, no database, never panics on any input, logs counts
only (section 9). `NameResolver::cached` is a synchronous
in-memory lookup (`src/names/resolver.rs:144-146`), and
`src/fitting/eft.rs` already names the type
(`src/fitting/eft.rs:20`), so taking the resolver crosses no
layering line the parsers have not crossed. The converter
deliberately does **not** take `&FittingTypes` (section 3.4).

The decision model has exactly two tiers. **Whole-conversion
refusal** happens only when no draft can be titled honestly:
the ship gate of section 3.4. Every other problem is a
**counted skip**: the row does not convert, the rest of the
fitting does, and the skip rides on the installed draft as an
`ImportIssue` with a copied-only kind (section 3.2), rendered
by the shipped issues block under copied wording (section
6.4). This is the import posture — partial success with a
named, counted remainder — applied to a new source, and it
matches the save mapper's counted drops and the exporters'
counted skips. A whole-refusal-on-any-bad-row model was
rejected: it would make the shipped demo's primary sample
fitting uneditable over one sample junk row (section 4),
and every real saved fitting carrying one row Mimir cannot
hold would be entirely uneditable for the sake of that row,
which discloses strictly less than naming the row and
converting the rest.

### 3.1 The flag-to-section table (locked, exhaustive)

Section comes from the flag string alone, by exact match
against this table. The slot rows are the write mapper's
ESI enum table (`src/fitting/write_map.rs:76-83`, membership
rule `is_slot_flag`, `src/fitting/write_map.rs:88-99`:
prefix plus canonical decimal index, in range) minus its
service row; the stacked rows are its stacked accept set
(`src/fitting/write_map.rs:115`).

| Saved flag | `ImportSection` |
|---|---|
| `HiSlot0`–`HiSlot7` | `High` |
| `MedSlot0`–`MedSlot7` | `Medium` |
| `LoSlot0`–`LoSlot7` | `Low` |
| `RigSlot0`–`RigSlot2` | `Rig` |
| `SubSystemSlot0`–`SubSystemSlot3` | `Subsystem` |
| `DroneBay` (exact) | `Drones` |
| `FighterBay` (exact) | `Fighters` |
| `Cargo` (exact) | `Cargo` |
| anything else | counted skip, `CopiedNoSection` |

"Anything else" is exhaustive by construction and includes
every other flag the codebase handles anywhere, each of
which is a skip, never a guess:

- `ServiceSlot0`–`ServiceSlot7` — a real ESI slot enum
  member the write mapper can save
  (`src/fitting/write_map.rs:82`), but `ImportSection` has
  no service section (`src/fitting/eft.rs:58-69`) and no
  dogma slot effect maps to one (`slot_section`,
  `src/fitting/eft.rs:367-381`). Routing it to `Cargo` —
  which is where the saved view happens to display it
  (`section_for_flag`, `src/ui/fittings.rs:83-101`) — would
  silently change a fitted service module into carried
  cargo and then save it back under the wrong flag. A user
  who needs the service row preserved still has the shipped
  save-a-copy of the original, which maps it faithfully.
- The view's catch-all: any string `section_for_flag` would
  group under "Cargo and other items" that is not exactly
  `Cargo` — `Invalid` (the demo row of section 4), `Hangar`,
  the empty string, `Foo` — because the view's grouping is a
  display whitelist, never a claim that the row is cargo,
  while a draft `Cargo` row **is** that claim and saves back
  as `Cargo`.
- Prefix lookalikes the view accepts but the ESI enum does
  not: `LoSlot8`, `RigSlot3`, `HiSlot00`, `HiSlotX`,
  `loslot0`, `DroneBayExtra`. The write mapper already drops
  every one of these as `NoEsiFlag`
  (`src/fitting/write_map.rs:271-304` tests); converting
  them by prefix would resurrect, under a renumbered valid
  flag, rows the save path today refuses to send.

Two rejected mappings, named so no builder re-derives them:
the **view whitelist** (`section_for_flag` prefix matching)
is rejected for the reason above — it is a rendering
grouping that was never a saveability claim; and
**dogma-derived sectioning** (`slot_section` over the
catalogue row) is rejected because EVE already placed the
item — the flag is the authority on where it sits, exactly
as the write mapper trusts it, and re-deriving placement
from bundled data would skip or move real saved items
whenever the catalogue lags EVE or the hull is a special
case (section 3.4).

### 3.2 Row decision order and skip kinds (locked)

Each source row is decided in this order; the first failing
check is the row's one skip, so a row with two faults counts
exactly once, under a deterministic kind:

1. `type_id <= 0` → skip, `CopiedNotSaveable`. (The write
   mapper's first check, `src/fitting/write_map.rs:113-114`;
   the saved view likewise shows no row for it,
   `fitting_item_rows`, `src/ui/fittings.rs:217`.)
2. Flag not in the section 3.1 table → skip,
   `CopiedNoSection`. Checked before quantity because a row
   with no section has no quantity rule to fail.
3. Quantity not holdable in its section (section 3.3) →
   skip, `CopiedBadQuantity`.
4. Slot sections only: the exact flag was already claimed
   by an earlier converted row → skip,
   `CopiedDuplicateSlot`. First claim wins, as in the write
   mapper (`src/fitting/write_map.rs:122-130`); later
   claimants are named, never merged into the slot.
5. `resolver.cached(type_id)` is `None` → skip,
   `CopiedUnnamed`. The placeholder string `Unknown Item`
   (`NameResolver::name`'s fallback,
   `src/names/resolver.rs:166-175`) must never be baked
   into a draft as an item's name: it would be exported,
   saved back, and collide across unrelated items. A real
   cached name is displayable by construction
   (`insert_with_category` refuses empty and purely numeric
   names, `src/names/resolver.rs:119-127`).
6. Stacked sections only: merging this row into the
   already-converted stack for its `(section, type_id)`
   would exceed `MAX_STACK_QUANTITY` → skip,
   `CopiedBadQuantity`; the earlier stack stands
   (section 3.3).

The five kinds are new `ImportIssueKind` variants in
`src/fitting/eft.rs` — `CopiedNoSection`,
`CopiedDuplicateSlot`, `CopiedBadQuantity`,
`CopiedNotSaveable`, `CopiedUnnamed` — each with a
`reason()` arm (wording locked in section 6.4). No existing
kind is reused: every shipped reason describes pasted text
or a DNA segment ("the item at the start of this segment…",
`src/fitting/eft.rs:146-148`), which would be a false claim
about a row that came from EVE, not from a paste. The kinds
are constructed only by the converter; the two parsers never
emit them, and no provenance's rendering changes because the
copied issue template (section 6.4) is selected by draft
format, not by kind.

Each skip is one `ImportIssue` appended to the draft's
report in source-row order, with:

- `line`: the 1-based source row index. The copied template
  never renders it (section 6.4); it is carried so the order
  is deterministic, tests can pin which row skipped, and the
  field is never a fabricated "paste line".
- `text`: the item's resolved name when one is known, else
  the empty string. It is **never the flag string** — flags
  are "grouped only through the view whitelist and never
  rendered verbatim" (`src/esi/models.rs:712-715`) — and
  never a type number. Empty text is the signal the copied
  template uses for its nameless form (section 6.4), which
  covers `CopiedNotSaveable` and `CopiedUnnamed` rows; a
  `CopiedNoSection`, `CopiedDuplicateSlot`, or
  `CopiedBadQuantity` row whose name also has not loaded
  likewise carries empty text (the name lookup for `text`
  is a plain `cached` read and does not change the row's
  already-decided kind).

### 3.3 Quantity rules and stacked merging (locked)

Saved quantities are raw, unvalidated JSON numbers: the
model carries them "raw and clamped at render/export, never
at parse" (`src/esi/models.rs:715-716`), and a quantity of
`-3` parses (base test at `src/esi/models.rs:1266`). The
converter is therefore the first place these numbers meet a
rule, and the rule is the draft's own invariant plus the
write mapper's dispositions — never the render clamp and
never the EFT exporter's repeat expansion.

- **Slot sections** (`Low`, `Medium`, `High`, `Rig`,
  `Subsystem`): a row converts if and only if its quantity
  is exactly `1`, and the converted `ImportedItem` carries
  `quantity: 1` — the invariant the field already promises
  ("Always 1 for slot sections; merged total for stacked
  sections", `src/fitting/eft.rs:256`). Any other quantity
  (`0`, negative, `2..`) is a `CopiedBadQuantity` skip.
  Forcing a quantity of 5 down to 1 — as the write mapper
  does for the save body it discloses at confirmation
  (`src/fitting/write_map.rs:122-127`) — is rejected here
  because the draft is the user's working copy, not a
  one-shot disclosed mapping: a silently rewritten count
  would ride through every later edit and save with its
  disclosure left behind on a screen the user no longer
  sees. Expanding quantity 5 into five fitted rows — as the
  EFT exporter does for clipboard text, capped at 16
  (`src/ui/fittings.rs:69`) — is rejected because it invents
  fitted slots the saved fitting never claimed.
- **Stacked sections** (`Drones`, `Fighters`, `Cargo`): a
  row converts if and only if
  `1 <= quantity <= MAX_STACK_QUANTITY` (2,147,483,647,
  `src/fitting/eft.rs:27`), and the quantity is a merged
  total, exactly as an EFT stacked line is. Rows for the
  same `(section, type_id)` merge into one `ImportedItem`
  by summing, keeping first-appearance order — the shipped
  `absorb_stack` semantics (`src/fitting/eft.rs:468-498`),
  including its overflow rule: when a sum would exceed
  `MAX_STACK_QUANTITY`, the crossing row is a
  `CopiedBadQuantity` skip and the earlier total stands.
  The merge key includes the section, where `absorb_stack`'s
  own index is keyed by type number alone; the parsers can
  key by type alone because category classification puts a
  type in exactly one stacked section, while a flag-first
  conversion can meet the same type under `DroneBay` and
  `Cargo` as two genuinely separate stacks that must never
  merge. This is the one place "identical to import
  semantics" means identical in effect per section, not a
  literal reuse of the parser's index shape; builders may
  reuse `absorb_stack` per section or implement the same
  rule in the converter — the lock is the observable rule.
  Quantity `<= 0` or `> MAX_STACK_QUANTITY` on a single row
  is a `CopiedBadQuantity` skip (the write mapper drops the
  `<= 0` case as `NotSaveable`,
  `src/fitting/write_map.rs:115-120`; the import cap makes
  the above-cap case unholdable by a draft at all).

Converted items keep source-row order overall: slot items in
the relative order their rows appeared within their section
(which is the order synthesis numbers them, section 3.6),
stacked items at their first-appearance position. No
sorting, no section regrouping, and no item cap is added: a
draft can hold a header-only import's zero items and a DNA
import's thousands, and the shipped 512-item and
at-least-one-item rules stay decisions of the save block
exactly as they are for every other provenance (new-fitting
design section 8).

### 3.4 Names, the ship gate, and what is not re-proved (locked)

**Names come from the app resolver, not the bundled
catalogue.** Each converted item's `name` is
`resolver.cached(type_id)` — the same name the saved detail
displayed on the row the user clicked through
(`fitting_item_rows`, `src/ui/fittings.rs:224`). The
alternative, catalogue names by type number, is rejected for
two reasons. In live mode it would rename items against the
names the user is looking at whenever the bundled data and
EVE disagree, and it would make conversion refuse or skip
real saved items the catalogue has not caught up with. In
demo mode it is simply wrong: the shipped demo fittings use
invented display names from `assets/demo/names.json` ("Demo
Small Railgun" and friends) over type numbers whose
catalogue rows are unrelated published types, and two demo
item numbers (1535, 636) have no catalogue row at all — a
catalogue-named demo copy would bear no resemblance to the
fitting on screen. Type number is the identity in both
models (`FittingItem` and `ImportedItem` carry the same
number through unchanged); the resolver name is display
text, and the draft's local resolver
(`ImportedFitting::name_resolver`,
`src/fitting/eft.rs:338-349`) already rebuilds itself from
the item names the converter stamps, so every downstream
render, copy, and dropped-item disclosure sees exactly those
names.

**The ship gate** is the only whole-conversion refusal, and
it mirrors the two shipped copy-button refusals:

- `source.ship_type_id <= 0` → `Refused(NoShip)` (the
  DNA-copy rule, `src/ui/fittings.rs:3708-3720` at base).
- `resolver.cached(source.ship_type_id)` is `None` →
  `Refused(ShipUnnamed)` (the EFT-copy rule:
  `fitting_to_eft` returns `None` when the ship name has not
  loaded, `src/ui/fittings.rs:306-310`).

On success `ship_name` is that cached name, cloned. The
catalogue is **not** consulted for the ship: not for
category 6, not for CPU/power outputs. A created draft needs
the catalogue's ship proof because its hull comes from a
list Mimir offers (new-fitting design section 3.1); a copied
draft's hull comes from EVE, and every statistic block
already renders for this exact hull in the saved detail —
with its shipped unavailable sentences wherever bundled data
is missing — because both blocks consume the same
`CharacterFitting` shape (section 7). Refusing conversion
for a ship the saved detail renders fine would be a new
blocking validation, which the editor's disclose-never-block
posture forbids adding (editor design section 5.2). Builder
A amends the `ship_name` field comment ("Canonical catalogue
ship name", `src/fitting/eft.rs:267`) and the `ImportFormat`
comment (`src/fitting/eft.rs:232-237`) to say what is then
true for all four provenances: the ship name the draft was
made with — catalogue-canonical for parsed and created
drafts, resolver-resolved for copied drafts.

**Category and dogma are not re-proved.** A converted item
is admitted by its flag (section 3.1), its quantity
(section 3.3), and its resolved name — never by asking the
catalogue whether that type "belongs" in that section. The
demo pins make this observable (section 4: the demo's
shield booster sits in a medium slot under a type number
whose catalogue row is an asteroid). Re-proof is what the
editor does for items the *user adds*; re-proving items EVE
already fitted would let bundled-data gaps silently shrink
a real fitting, and the shipments that already trust the
flag — the write mapper, the saved view, and every saved
statistic block — are the precedent.

**Charges: none exist, none are invented.** A saved fitting
carries no loaded-charge field anywhere
(`FittingItem` is exactly flag, quantity, type number,
`src/esi/models.rs:721-728`); the standing disclosure for
saved and DNA fittings already says no charge is assumed.
Every converted item therefore carries `charge: None` and
the draft reports `charges_noted: 0`. A charge-category
type carried under `Cargo` converts as ordinary stacked
cargo — its flag says it is in the hold, and promoting it
to a module's loaded charge would be fabrication.

### 3.5 The constructed draft (locked)

On success the converter returns exactly one
`ImportedFitting` with:

- `format`: a fourth `ImportFormat` variant, **`Copied`**
  (Builder A adds it in `src/fitting/eft.rs` beside `Eft`,
  `Dna`, and `Created`, and extends the enum's doc comment:
  a copied draft was neither parsed nor created from
  scratch, and the variant is what keeps every summary,
  label, and confirmation from claiming either). Reusing
  `Created` is rejected outright: its summary says
  `Created "…"` and its label says `Created fitting`
  (`src/ui/fittings.rs:829-834`, `855-860`), both false for a
  draft whose items came from EVE; reusing `Eft` or `Dna`
  would claim a parse of lines or segments that never
  happened.
- `name`: the saved fitting's name, **verbatim** —
  `source.name.clone()`, untrimmed and unsuffixed. This is
  the name default, locked. No `Copy of …` prefix and no
  `… (copy)` suffix: the shipped save-a-copy already saves
  under the original's name (`build_save_request` takes the
  source name, `src/fitting/write_map.rs:136-150`), so a
  saved-back copy behaving the same way is the familiar
  contract; provenance is carried by the format and its
  locked wording (section 6), not by mutating the user's
  text — a mutation the 50-character save truncation would
  then mangle further. The editor's shipped rename is the
  way to tell them apart in EVE, and the rename box seeds
  from this name on install (section 5). An empty or
  digit-only source name stays as-is in the draft: display
  falls back through the shipped `fitting_display_name`
  ("Unnamed fitting", `src/ui/fittings.rs:160-168`) and the
  save path falls back through its shipped `"Unnamed fit"`,
  both unchanged for every provenance.
- `ship_type_id` and `ship_name`: from the ship gate
  (section 3.4).
- `items`: the converted items of sections 3.1–3.3 — each
  `{ type_id (source, unchanged), name (resolver-cached),
  section (flag table), quantity (1 for slots, merged total
  for stacked), charge: None }`. Zero items is a valid,
  installable result: a saved fitting with no rows converts
  to an empty copied draft, and one whose rows all skip
  converts to an empty copied draft with its skips named
  below it — the same posture as a header-only import whose
  every line was an issue. The save block then refuses the
  empty draft by its shipped guard, unchanged (section 7).
- `report`: `imported_lines: 0`, `placeholder_lines: 0`,
  `charges_noted: 0` — nothing was parsed, so every parse
  counter is zero, exactly as for a created draft
  (new-fitting design section 5.2) — and `issues`: the
  counted skips of section 3.2 in source-row order. This is
  the one deliberate difference from `Created`, whose issues
  are empty by construction: a copied draft can carry
  issues that are not import issues, which is why the three
  issue-wording functions gain real `Copied` arms instead
  of sharing the EFT arm on the argument that the list is
  always empty (the argument the shipped comments make for
  `Created` at `src/ui/fittings.rs:741-742` and its two
  siblings).

**What a copy does not carry** (named, so nothing about it
is silent at the design level):

- The original's EVE fitting identity. Synthesis stamps
  `fitting_id: -1` for every draft
  (`src/fitting/eft.rs:288`), so no delete or save-a-copy
  target can ever be derived from a copied draft; saving it
  can only ever create.
- The original's description. No provenance carries one
  (`to_character_fitting` sets `description: None`,
  `src/fitting/eft.rs:290`); a saved-back copy therefore
  gets the shipped fallback description, exactly as a saved
  import or created draft does today. The notes themselves
  remain untouched on the original in EVE.
- Original slot indices and their gaps. A lone `LoSlot3`
  synthesizes back as `LoSlot0` (section 3.6). Slot index
  within a section carries no fitment meaning in EVE, and
  every shipped draft already renumbers this way; the
  invariant of section 3.6 is stated over the normalized
  form so this is a definition, not a loss discovered later.

### 3.6 The round-trip invariant (locked)

Let *normalization* of a saved fitting mean: drop the
rows section 3.2 counts as skips; merge stacked rows per
section 3.3; then renumber slot flags sequentially from 0
within each section in source relative order (`LoSlot0…`,
`MedSlot0…`, `HiSlot0…`, `RigSlot0…`, `SubSystemSlot0…`),
with stacked rows under their exact `DroneBay`,
`FighterBay`, and `Cargo` flags. The invariant, pinned by
test (section 10):

> For every saved fitting whose conversion succeeds,
> `converted.to_character_fitting().items` equals the
> normalization of the source — same type numbers, same
> quantities, same flags after renumbering — and converting
> that synthesized fitting again under the same resolver
> yields a draft whose items are identical to the first
> conversion's, with zero skips.

The first half holds by construction of the flag table and
synthesis (`to_character_fitting`,
`src/fitting/eft.rs:284-332`): because admitted slot flags
are the in-range enum members with no duplicates, the
per-section counts can never exceed the enum ranges
(8/8/8/3/4), so synthesis can never emit an out-of-range
flag for a copied draft; and `build_save_request` over the
synthesized fitting drops nothing (its dropped list is
empty), subject only to its whole-fitting guards (ship
present by the gate; emptiness and the 512 cap remain the
save block's own disclosures). The second half — conversion
is a fixed point on its own output — is what makes "edit a
copy, save it as a new fitting, edit a copy of *that*"
loss-free. The test in section 10 builds its expected
normalization by hand in the test, never by calling
converter internals, so the pin can actually fail.

## 4. Demo pins (locked, scripted from the shipped fixtures)

Scripted at design time from `assets/demo/fittings.json`
and `assets/demo/names.json` at base, under the resolver the
demo loader builds from those names. These are the expected
values Builder B's asset-driven test asserts (section 10);
any disagreement is a converter bug, not a fixture edit —
**no demo fixture changes in this slice**.

- **Fitting 1, "Demo Brawler"** (character 90000001, ship
  Rifter, the pre-selected detail): 12 saved rows convert
  to **11 draft items and 1 skip**.
  - Slots, all quantity 1: Low — Demo Small Railgun;
    Medium — Demo Small Afterburner, Demo Small Shield
    Booster; High — Demo Light Missile Launcher (twice,
    from `HiSlot0` and `HiSlot1`: same type, distinct
    slots, **not** merged — merging is a stacked-section
    rule only); Rig — Demo Small Auxiliary Thruster;
    Subsystem — Demo Interdiction Subsystem.
  - Stacked: Drones — Demo Light Drone x5; Fighters — Demo
    Light Fighter x2; Cargo — Tritanium x500 and Demo Light
    Missile x200 (distinct types, no merge).
  - The one skip: the `Invalid`-flagged Pyerite row,
    `CopiedNoSection`, named in the draft's issues as
    `"Pyerite" - …` (section 6.4). This row is the reason
    the counted-skip tier exists: under a whole-refusal
    model the demo's headline fitting could not be edited
    at all.
  - Summary: `Copied "Demo Brawler" (Rifter) from your
    saved fittings: 11 items.`
- **Fitting 2, "Mission Runner"** (90000001, Rifter): 4 rows
  convert to **4 items, 0 skips** — High Demo Small Railgun,
  Low Demo Small Afterburner, Drones Demo Light Drone x3,
  Cargo Isogen x10. The railgun and afterburner sit in
  sections their catalogue dogma disagrees with; both
  convert by flag (section 3.4), pinning the
  no-re-proof rule against shipped data.
- **Fitting 10, "Demo Runner"** (character 90000002, ship
  Punisher): 5 rows convert to **5 items, 0 skips** — Low
  Demo Small Railgun, High Demo Light Missile Launcher,
  Medium Demo Small Shield Booster, Drones Demo Light Drone
  x3, Cargo Mexallon x20.

All three ship type numbers resolve in the demo resolver
(Rifter, Punisher), so neither refusal in section
3.4 is reachable from the shipped fixtures; refusals are
pinned by unit fixtures instead (section 10).

## 5. Install: clicking Edit a copy (locked)

The click runs the conversion against the still-selected
saved fitting and the panel's resolver, then:

- **On `Converted(draft)`**, install exactly as
  `install_created_fitting` installs
  (`src/ui/fittings.rs:1573-1588`), through a sibling helper
  factored for testability the same way,
  `install_copied_fitting(state, draft)`:
  1. `state.fittings_imported = Some(draft)`;
  2. `state.fittings_import_error = None`;
  3. `state.fittings_import_owner =
     state.active_character_id` (the section 2.1 gate has
     already established this is `Some`);
  4. `state.fittings_import_text.clear()` — a copied draft
     has no source text, so leaving a pasted block beside it
     would present text the draft did not come from and one
     stray Import click would silently replace it (the
     creation lock verbatim);
  5. `state.fittings_write_confirm = None` — the **whole
     field**, whatever variant it held. This disarms all
     three shipped confirmations by one assignment: a
     `SaveImported` armed for the draft being replaced, and
     the original fitting's own `SaveCopy` and `Delete`
     (stamped with its character and fitting numbers at
     `src/ui/fittings.rs:3832-3836` and `3853-3856` at base).
     This matters more here than at creation: an armed
     delete of the original has *this very fitting* as its
     target, and the user has just said they want to work
     from it. The staleness sweep would **not** catch it —
     the fitting is still selected and still in the list, so
     `write_confirm_is_stale` (`src/ui/fittings.rs:1205-1231`)
     keeps it renderable — hence the explicit whole-field
     disarm, by construction and by test, never by a
     downstream coincidence. Disarm is not disable: the
     arm buttons render again next frame, one click away,
     unchanged.
  6. `clear_editor_state(state)` — the entire editor,
     browser, and ship-chooser reset as shipped
     (`src/ui/fittings.rs:1542-1560`): add name and
     quantity, editor error, edited flag (so the copied
     summary starts without its edited suffix), per-row
     quantity drafts, rename seed, browser tab back to
     High, browser search and cached rows, ship search and
     cached ship rows. The rename box reseeds from the
     copied name (section 3.5) on the next frame through
     the shipped lazy seed.
  7. Set the section 6.1 status message (the one locked
     difference from the created install, with its reason
     stated there).

  Nothing else changes. In particular
  `fittings_selected_fitting_id` keeps the original
  selected — its detail stays on screen below for
  comparison, and its Copy, Save-a-copy, and Delete controls
  keep working against the original — and no write-in-flight
  or queued-request field is touched, exactly as at
  creation: a write already in flight for the original
  completes against the original, and installing a draft
  neither needs nor grants any power over it.
- **On `Refused(..)`**, nothing installs, nothing is
  cleared, and no confirmation is disarmed: the current
  draft, paste text, editor state, and any armed button all
  stay exactly as they were. Only the refusal status
  message is set (section 6.1) and the refusal logged
  (section 9). A refusal the user can fix by waiting for
  names to load must never cost them the draft they
  already had.

**Replacement has no confirmation.** Clicking with a draft
already present — imported, created, or an earlier copy,
edited or not — replaces it immediately. Both shipped doors
already work this way (new-fitting design section 6), the
button's standing note discloses the replacement in advance
(section 6.1), and the disarm above covers the one dangerous
case: replacement can lose the old draft, never send it.
The click handler follows the panel's borrow discipline:
convert from the `&CharacterFitting` the detail render
already resolved, act on the outcome after the immutable
borrow ends.

## 6. Verbatim wording (locked)

Rule: for `Eft`, `Dna`, and `Created` drafts every string
below stays byte-identical to the base. For `Copied` drafts
the copied column is used. Selection is by
`imported.format`, at the render site or through the
existing small helpers — builders choose the mechanism,
never the words. Internal identifiers (`fittings_imported`,
`FittingWriteConfirm::SaveImported`, `ImportedFitting`,
`install_copied_fitting`) keep or follow the shipped names:
they are code, not claims shown to the user.

### 6.1 The control, its note, and its status messages (new)

Rendered in the saved detail at the section 2.1 placement,
in this order:

- Button: `Edit a copy in Mimir`
- Standing note, always rendered directly under the button:
  `Editing a copy changes only the copy in Mimir and replaces the fitting above, if there is one. The saved fitting in EVE stays as it is, and saving the copy adds a new fitting.`
  ("the fitting above" is the draft block's actual position
  on this panel, section 2.1 — the ship chooser's note says
  "the fitting below" because from the chooser the draft
  *is* below; each note describes its own screen.)

Status messages (set only by this click; no other path sets
them):

- Converted, no skips:
  `Editing a copy of "{name}" above. The saved fitting in EVE is unchanged.`
- Converted, one skip:
  `Editing a copy of "{name}" above. The saved fitting in EVE is unchanged. 1 item could not be copied and is listed with the copy.`
- Converted, N skips (N > 1):
  `Editing a copy of "{name}" above. The saved fitting in EVE is unchanged. {n} items could not be copied and are listed with the copy.`
- Refused `NoShip`:
  `That fitting cannot be copied for editing: it has no ship. Refresh and try again.`
- Refused `ShipUnnamed`:
  `That fitting cannot be copied for editing yet: its ship name has not loaded. Refresh and try again.`

`{name}` is `fitting_display_name(&draft.name)`, as in the
saved detail's own copy statuses. The converted statuses are
the locked deviation from the created install's no-status
rule, for the reason locked in section 2.1: the result
appears above the click, possibly off-screen, and the status
line is the feedback at the point of action. The two refusal
statuses mirror the shipped copy-button refusals
(`src/ui/fittings.rs:3672-3685`, `3708-3720` at base) with
the verb changed to match this button.

### 6.2 Draft-block strings by provenance

| Site (base) | `Copied` wording |
|---|---|
| Summary line (`imported_summary_line`, `src/ui/fittings.rs:827-850`) | `Copied "{name}" ({ship}) from your saved fittings: {n} items.` |
| Edited suffix (`imported_summary_line_edited`, `src/ui/fittings.rs:1486-1496`) | ` Edited.` (the `Created` arm; a copied draft cannot have changed "since import") |
| Draft label (`draft_label`, `src/ui/fittings.rs:855-860`) | `Copied fitting` |
| Editor note (`editor_note`, `src/ui/fittings.rs:867-872`) | `Edits change only this copy in Mimir. The saved fitting in EVE stays as it is. Nothing is sent to EVE unless you save below, and saving adds a new fitting. Removing a module also removes its loaded charge. Items can be added only when Mimir's bundled data proves which slot they fit.` |
| Copy EFT button (`src/ui/fittings.rs:875-880`) | `Copy fitting as EFT` (the `Created` neutral arm) |
| Copy DNA button (`src/ui/fittings.rs:883-888`) | `Copy fitting as DNA` (the `Created` neutral arm) |
| Save arm button (`src/ui/fittings.rs:891-896`) | `Save fitting to EVE...` (the `Created` neutral arm) |

Notes on these choices:

- The summary carries `from your saved fittings` so the
  draft's own headline can never be misread as the saved
  fitting itself or as clipboard output, and it drops any
  "from N lines/segments" clause for the created draft's
  reason: nothing was parsed. `{n}` is `items.len()`, the
  same row count every other arm reports (stacked rows
  count once), so the demo pins of section 4 read `11`,
  `4`, and `5`.
- The three buttons take the already-neutral `Created`
  forms rather than a "copied fitting" form: `Copy copied
  fitting as EFT` collides the clipboard verb with the
  provenance noun, and the neutral forms make no false
  claim — provenance is stated once, prominently, in the
  summary, the label, and the editor note directly above
  them. Grouping the match arms as `Created | Copied` at
  these three helpers and the edited suffix is the expected
  mechanism.
- The loaded-charge sentence stays in the copied editor
  note, inert as it is for created drafts (a copied draft
  can hold a charge only if a later editor feature adds
  one; today it never can, section 3.4), so the three notes
  differ only in their provenance claims.

### 6.3 The save confirmation for a copied draft (locked)

A copied draft saves through the shipped draft save flow
(the `SaveImported` confirmation, recomputed every frame
from the current draft so what is confirmed is bit-for-bit
what Confirm sends). One wording changes for `Copied`:
the confirmation summary. The shipped imported summary —
`"{name}" ({ship}, {kept} items) will be added to this
character's in-game fitting list.`
(`save_confirmation_imported`, `src/ui/fittings.rs:994-998`)
— already says "added", but for a copy the load-bearing
fact is that the original is untouched, and this is the
last screen before the one irreversible-feeling click, so
the copied summary is locked as:

`"{name}" ({ship}, {kept} items) will be added as a new fitting to this character's in-game fitting list. The saved fitting it was copied from stays as it is.`

`{name}` and `{kept}` are the mapping's current values
(the draft's possibly-renamed, possibly-edited state), as
in both shipped summaries; `{ship}` is the draft's
`ship_name`, as the draft save call already passes
(`src/ui/fittings.rs:3479` at base). Builder B gives
`render_save_confirm` a third summary selection for copied
drafts — an enum replacing its `copy: bool`, or an added
parameter; the mechanism is Builder B's, the words are not —
and the shipped saved-fitting save-a-copy keeps
`save_confirmation_copy`'s wording byte-identical,
including its own "The original stays as it is." Everything
else in the block is provenance-neutral and unchanged: the
title, the fallback-name, truncated-name, and
truncated-description lines, the charges-not-sent line
(never shown for a copied draft, whose counter is 0), the
dropped-item disclosures (reachable for a copied draft only
after the user edits it into a shape the mapper drops —
an unedited copy drops nothing, section 3.6), and the
confirm and cancel buttons.

### 6.4 Skip disclosures (locked)

Skips render in the shipped issues block under the draft
(`src/ui/fittings.rs:3386-3401` at base), selected by
`imported.format == Copied` in the three wording functions.
No new block, no new cap: the shipped
`IMPORT_ISSUES_RENDER_MAX` (20) and its overflow mechanics
apply unchanged.

- Heading: `1 item could not be copied:` /
  `{n} items could not be copied:`
- Row, named item (`text` non-empty):
  `"{text}" - {reason}.` — the text truncated by the
  shipped 120-character `truncate_issue_text`, as every
  other arm does. No `Line n:` prefix: there was no line.
- Row, unnamed item (`text` empty):
  `One saved item - {reason}.`
- Overflow: `...and 1 more item that could not be copied.`
  / `...and {n} more items that could not be copied.`
  The shipped "Fix the lines above and import again"
  tail is not carried over; there is nothing to fix in a
  text the user never wrote, and the full count is already
  in the heading.

The five `reason()` strings (locked verbatim):

| Kind | Reason |
|---|---|
| `CopiedNoSection` | `its place in the saved fitting is not a slot or bay an edited copy can hold, so it was left out` |
| `CopiedDuplicateSlot` | `another item in the saved fitting already uses its slot, so it was left out` |
| `CopiedBadQuantity` | `its quantity in the saved fitting cannot be held in an edited copy, so it was left out` |
| `CopiedNotSaveable` | `it cannot be saved as part of a fitting, so it was left out` |
| `CopiedUnnamed` | `its name has not loaded yet, so it was left out` |

So the demo's one skip reads in full:
`"Pyerite" - its place in the saved fitting is not a slot or bay an edited copy can hold, so it was left out.`
and a not-yet-loaded name reads:
`One saved item - its name has not loaded yet, so it was left out.`
(The remedy for the latter — wait for names, click again —
is the same refresh story as every name-gated button in the
panel; the status-on-refusal tells the ship case explicitly,
and a per-item unnamed skip leaves the rest of the copy
editable in the meantime.)

### 6.5 Strings that need no copied variant

Verified at base; builders must not touch them for this
slice:

- The standing import-panel heading and note
  (`src/ui/fittings.rs:3022-3023`). They describe the paste
  box they head, which still does exactly what they say;
  the new-fitting design left them in place above created
  drafts for the same reason, and the copied summary,
  label, and note state this draft's provenance directly
  under them.
- The copy status messages (`Copied "{name}" as EFT`,
  `Copied "{name}" as a DNA link`, with their left-out
  clauses), the copy-blocked statuses, the placeholder and
  charge notes (both counter-gated at 0 for copied drafts,
  so correctly never rendered), the editor heading
  `Edit this fitting`, the empty-items label, the
  un-saveable labels, and the demo write label.
- The DPS block's saved/DNA charge disclosure. The draft
  reaches DPS as the same synthesized fitting a created
  draft is (`render_fitting_dps` takes the synthesis plus
  the draft, `src/ui/fittings.rs:3355` at base), and its
  format test is an EFT-only equality
  (`src/fitting/dps.rs:195`), so `Copied` takes the
  already-shipped non-EFT path byte-identically to
  `Created` — Builder A confirms this by inspection and
  adds no arm there.

## 7. Downstream consumers (locked, all unchanged)

A copied draft is not a new downstream case. It differs
from a created draft only in format and in possibly
non-empty items and issues — a state both parsers already
produce. No guard below changes; the table records the
shipped decision each consumer applies so no builder adds a
parallel one.

| Consumer | Behaviour on a copied draft (as shipped) |
|---|---|
| Editor rename / typed add / module browser | Fully usable; the rename box seeds the original's verbatim name. Adds prove slot membership against the catalogue for the *new* item only; items the conversion admitted by flag are removed and re-quantified by index and section, which never re-proves them. The first successful edit sets the edited flag, disarms saves via `note_successful_edit`, and the summary gains ` Edited.` |
| Item rows | Render sectioned from the draft's local resolver — the names the saved detail showed (section 3.4). An all-slots-converted copy shows one row per saved slot row, stacked rows merged per section 3.3. |
| All statistic blocks | Compute from the synthesized fitting exactly as they compute from the saved fitting itself in the detail below — same ship, same item multiset after normalization (section 3.6) — so an unedited copy's numbers agree with the original's block for block, including every shipped unavailable sentence where bundled data is missing. |
| Loaded-charges block | Hidden: `charges_noted` is 0 and no item carries a charge. |
| Issues block | Shows the section 6.4 skip disclosures when the conversion skipped rows; hidden when it did not. Edits never add to or clear the list (the editor never pushes issues), so a skip stays disclosed for the draft's whole life, through every edit and at save time. |
| Copy as EFT | Allowed, including for a zero-item copy (the header alone), through the shipped exporter against the local resolver. Names are resolver names, so re-importing the copied text is subject to the parser's catalogue lookup exactly as a saved fitting's own EFT export is today — no new promise is made or needed. |
| Copy as DNA | Allowed on the same terms; drones, fighters, and cargo count as left out by the shipped exporter, disclosed in its status, unchanged. |
| Save to EVE | The shipped draft save flow with the section 6.3 summary. The shipped guards decide: unedited copies map drop-free (section 3.6), an emptied or 513-plus-item edited copy gets the shipped un-saveable label, and Confirm sends only ever a create. |
| Demo mode | The button, conversion, editor, and copy buttons are fully usable against the section 4 fixtures; the standing demo write label replaces the save affordance, unchanged. No demo-only gating, no demo-only wording. |

## 8. State fields and clearing (locked: none)

This slice adds **no `AppState` field**. The conversion's
entire output is the draft: skips ride on its existing
report (section 3.5), provenance on its existing format,
and the install (section 5) writes only the fields the
created install already writes. Consequently every shipped
reset covers a copied draft without any new site:

- **Character switch** (`set_active_character`,
  `src/app/state.rs:1149-1179` at base): clears the saved
  selection, paste text, draft, import error and owner,
  every editor field, the browser tab/search/rows, the ship
  search/rows, and the write confirm/requested/pending
  fields. A copied draft dies with its character exactly
  like an imported or created one; copying again under the
  other character re-converts from that character's saved
  list. Nothing about a copy is keyed, cached, or carried.
- **Character removal and no-character paths**: the same
  shipped blocks, untouched.
- **Replacement by any other door** — a new import, a ship
  choice, a later edit-a-copy click, Clear: each already
  replaces or clears `fittings_imported` (with its report,
  skips included) and runs its shipped clearing; a copied
  draft needs no send-off of its own.

The draft block's owner guard
(`src/ui/fittings.rs:3159-3163`) is likewise the only
render gate a copied draft needs, defense-in-depth exactly
as for the other provenances.

## 9. Logging (locked)

`[FITTING]` tag, **counts only**. Fitting names are user
text, ship and item names come from the live resolver
rather than the bundled catalogue, and no flag string or
type number is ever logged by this slice. (Some shipped
saved-detail lines log the display name; this slice adds
none of those — the converter and install follow the pure
fitting layer's stricter counts-only rule.) Exactly three
new lines:

1. Conversion success, `debug`, in the converter,
   mirroring `build_save_request`'s counts style
   (`src/fitting/write_map.rs:174-179`):
   `[FITTING] saved copy converted items={items} skipped={skipped}`
   where `{items}` is the converted item count and
   `{skipped}` the skip count (`report.issues.len()`).
2. Conversion refusal, `debug`, in the converter:
   `[FITTING] saved copy refused reason={reason:?}`
   with the `SavedCopyRefusal` debug form (`NoShip` or
   `ShipUnnamed`) — an enum value, never user text.
3. Install, `info`, in `install_copied_fitting`, mirroring
   the import-complete line's level and field style with
   the copied draft's counters pinned at their construction
   values:
   `[FITTING] saved copy installed items={items} skipped={skipped} charges=0`

Nothing else logs. The button render, the selection, and
the saved detail are silent, as at base. Internal log text
that still says "imported" on shared paths (`kind=save_imported`
and friends) is not user-visible and is out of scope, as it
was for created drafts.

## 10. Test plan (locked)

The regression bar: the full existing suite (1,056 tests at
base) passes unmodified except for the compile-boundary
match arms of section 12.1, which carry their final section
6 wording from the start so no shipped literal ever
changes. An imported or created draft that is never copied
renders its summary, notes, issues, statistics, copy, and
save blocks byte-for-byte as today. Expected values below
are stated as literals or as hand-built structures; a test
may never derive its expectation by calling the converter
(or a helper the converter also calls) on the same input.

Builder A (pure tests in `src/fitting/saved_copy.rs`, plus
the `reason()` literals asserted where the kinds live):

1. **Flag table, exhaustive.** One fixture per table row
   of section 3.1 converts to its locked section — the
   boundary indices `HiSlot7`, `RigSlot2`, `SubSystemSlot3`
   included — and each of `ServiceSlot0`, `ServiceSlot7`,
   `Invalid`, `Hangar`, ``, `Foo`, `LoSlot8`, `RigSlot3`,
   `SubSystemSlot4`, `HiSlot00`, `HiSlotX`, `loslot0`,
   `DroneBayExtra`, `cargo` converts to exactly one
   `CopiedNoSection` skip and no item.
2. **Quantity rules.** Slot rows at quantities 1 (converts,
   quantity 1), 0, -3, and 5 (each one `CopiedBadQuantity`
   skip, no item — not forced to 1, not expanded); stacked
   rows at 1 and `MAX_STACK_QUANTITY` (convert), 0, -1, and
   `MAX_STACK_QUANTITY + 1` (each one skip).
3. **Stacked merging.** Two `Cargo` rows of one type merge
   to their sum at first-appearance position; the same type
   under `DroneBay` and `Cargo` stays two items; two slot
   rows of one type under distinct flags stay two items of
   quantity 1; a merge crossing `MAX_STACK_QUANTITY` keeps
   the first total and counts the crossing row as one
   `CopiedBadQuantity` skip.
4. **Duplicates and decision order.** The second claim on
   an exact slot flag is one `CopiedDuplicateSlot` skip and
   the first row's item stands; multi-fault rows count once
   under the section 3.2 order — pinned cases: type
   `<= 0` with an unknown flag reports `CopiedNotSaveable`;
   an unknown flag with quantity 0 reports
   `CopiedNoSection`; a duplicate slot with quantity 5
   reports `CopiedBadQuantity`; a duplicate slot whose
   name is unresolved reports `CopiedDuplicateSlot`.
5. **Names and the ship gate.** An item whose number the
   resolver has not cached is one `CopiedUnnamed` skip with
   empty issue text, and the placeholder `Unknown Item`
   appears nowhere in the draft; `ship_type_id <= 0`
   refuses `NoShip`; an uncached ship number refuses
   `ShipUnnamed`; a resolved ship with zero rows converts
   to an empty draft; a fitting whose rows all skip
   converts to an empty draft carrying only its skips.
6. **Construction.** A converted draft asserts `format ==
   Copied`, the source name byte-for-byte (including an
   empty source name staying empty), the resolver ship
   name, all three parse counters at 0, every charge
   `None`, and issues in source-row order with 1-based
   source indices.
7. **Round trip.** A hand-built fitted example — interleaved
   slot rows including a gap (`LoSlot3` with no `LoSlot1`),
   a same-type slot pair, splittable stacked rows,
   drones, fighters, and one skip of each kind from tests
   1–5 — converts, synthesizes, and equals the
   hand-written normalization of section 3.6 exactly
   (full `Vec<FittingItem>` literal); `build_save_request`
   over the synthesis reports no dropped items; converting
   the synthesis again yields identical items and zero
   skips; and the synthesis carries `fitting_id == -1` and
   `description == None`.
8. **Reason literals.** The five section 6.4 `reason()`
   strings asserted byte-for-byte, and no `Copied` issue
   text, converted item name, ship name, or reason contains
   a source type number rendered as text (the fixtures use
   numbers whose decimal forms — e.g. `587` — would show).

Builder B (tests in `src/ui/fittings.rs`; no state-file
fixture changes, because no field is added):

9. **Summary, suffix, and label literals.** A copied draft
   renders `Copied "Demo Brawler" (Rifter) from your saved
   fittings: 11 items.` unedited (the section 4 fixture)
   and the same line plus ` Edited.` when edited; label
   `Copied fitting`; the section 6.2 editor note
   byte-for-byte; the three neutral buttons shared with
   `Created`; and the shipped EFT, DNA, and Created
   literals keep passing unmodified beside them.
10. **Skip wording.** Heading singular and plural, the
    named and unnamed row forms (the full Pyerite sentence
    and the full unnamed sentence of section 6.4), and the
    overflow singular and plural, asserted through the
    same pure wording helpers the block renders with; no
    copied row contains `Line` or a type number as text.
11. **Save confirmation.** The section 6.3 copied summary
    asserted byte-for-byte for a renamed, edited copied
    draft (the mapping's current name and kept count), and
    both shipped summaries asserted unchanged for their
    own paths.
12. **Install and total disarm.** Seeding state with an
    existing draft, an import error, paste text, dirty
    editor/browser/ship state, and — in three separate
    runs — `fittings_write_confirm` set to `SaveImported`,
    to `SaveCopy` stamped for the fitting being copied,
    and to `Delete` stamped for that same fitting, then
    applying `install_copied_fitting`, asserts: the copied
    draft is installed with owner equal to the active
    character, error and paste text cleared,
    `clear_editor_state`'s cleared values hold for editor,
    browser, **and ship fields**, the edited flag is
    false, `fittings_write_confirm == None` in all three
    runs, the saved selection is unchanged, and the
    section 6.1 status message matches the converted
    template for the draft's skip count (0, 1, and >1
    across runs or fixtures).
13. **Refusal is a no-op.** Applying the click path's
    refusal branch over the same seeded state asserts the
    prior draft, paste text, editor state, selection, and
    armed confirmation are all untouched and the status is
    the locked refusal text for each refusal variant.
14. **Demo pins.** Parsing the shipped
    `DEMO_FITTINGS_JSON` (the existing asset-test
    precedent in this file) with a resolver built from the
    shipped demo names asserts section 4 exactly: Demo
    Brawler → 11 items (full ordered names, sections, and
    quantities) plus the one `CopiedNoSection` Pyerite
    skip; Mission Runner → 4 items, 0 skips; Demo Runner
    → 5 items, 0 skips. The Demo Brawler case also asserts
    the High pair was not merged and the two Cargo types
    were not merged.

## 11. Deferred (named, not built)

- **Editing the saved fitting in place.** Still impossible
  and still not approximated: EVE offers create and delete
  only, so "save my edits over the original" would have to
  be a delete-plus-create that silently changes the
  fitting's identity and loses its notes; if ever wanted it
  is its own design with its own confirmation language, not
  a mode of this button.
- **Carrying the original's description into the draft.**
  Needs a draft-model field every provenance would then
  have to answer for (section 3.5); notes editing is a
  separate slice if ever wanted.
- **A service-slot section.** Holding `ServiceSlot` rows in
  a draft needs an `ImportSection` variant, a browser tab
  decision, and slot-layout semantics for hulls that take
  service modules; until then they are counted skips here
  and preserved faithfully by the shipped save-a-copy.
- **Copying across characters.** A draft is owned by the
  active character and dies on switch, as every draft does.
  The clipboard path (Copy as EFT, switch, Import) already
  carries a fitting across characters.
- Everything the editor and browser already defer stays
  deferred unchanged: drag and drop, charge editing,
  module state, move/reorder/undo, ship change on an
  existing draft, and draft persistence.

## 12. Code structure and builder split (locked)

### 12.1 Builder A — pure conversion

Files: `src/fitting/eft.rs` (the `Copied` format variant,
the five issue kinds with their `reason()` arms, and the
two doc-comment amendments of section 3.4 — variants and
comments only, no parser change), the new
`src/fitting/saved_copy.rs` (the section 3 converter, its
outcome and refusal types, and Builder A tests 1–8), and
`src/fitting/mod.rs` (module and re-exports:
`convert_saved_fitting`, `SavedCopyOutcome`,
`SavedCopyRefusal`). Adding `Copied` breaks the exhaustive
`ImportFormat` matches in `src/ui/fittings.rs` — the three
issue-wording functions (`src/ui/fittings.rs:740`, `767`,
`797` at base), `imported_summary_line` (`827`), the four
label helpers (`855`, `867`, `875`, `883`, `891`), and the
edited suffix (`1486`) — so Builder A adds the `Copied`
arm at each with its **final** section 6 wording purely to
keep the A/B boundary compiling, and touches nothing else
in that file; Builder B then owns the tests around those
arms. (The one non-UI format read, `src/fitting/dps.rs:195`,
is an equality test and needs no arm, section 6.5.)

Commit subject (locked):
`feat(fitting): add saved-fitting copy conversion`

### 12.2 Builder B — control, install, and wording

Files: `src/ui/fittings.rs` only — the section 2.1 control
with its gates, `install_copied_fitting` and the click
path with its refusal branch, the section 6.1 statuses,
the section 6.3 save-confirmation selection, the
section 9 install log line, and Builder B tests 9–14.
Builder B changes no pure-layer rule, adds no state field,
and does not modify `src/app/state.rs`.

Commit subject (locked):
`feat(fitting): add edit-a-copy control for saved fittings`

### 12.3 Integrator

Merges A then B (B depends on A's public items), runs the
full verification gate (section 13), confirms the demo
pins and wording literals main-side, and lands any
user-facing documentation follow-up as its own commit with
subject (locked):
`docs(fitting): document editing a copy of a saved fitting`
plus the engineering-journal entry the repo requires for
the mechanism (the resolver-named, flag-first conversion
and its fourth provenance), in that same docs commit. The
integrator changes no behaviour: any gate failure goes
back to the owning builder.

## 13. Verification gate (locked)

On the final merged tree, all four, in order, with output
read — not skimmed for exit codes alone:

1. `cargo fmt --check`
2. `cargo clippy --all-targets -- -D warnings`
3. `cargo test` — the 1,056 base tests plus this slice's
   additions, zero failures, and no base test modified
   beyond the section 12.1 compile-boundary arms.
4. `cargo build`

This design commit itself was verified the same way on the
base tree (a documentation-only change must still leave all
four green).

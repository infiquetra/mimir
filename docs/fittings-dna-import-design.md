# DNA fitting-link import slice — locked design

Branch: `feat/rust-fittings-dna-import`. Base: `develop` at
`b97d680` (merge of pull request #573, the fittings write
slice). This document locks the design for importing EVE
DNA fitting links in the existing Fittings import panel.
It extends, and never contradicts,
`docs/fittings-import-design.md` (the EFT import slice,
pull request #571) except for that document's section 2
"No other formats" exclusion of DNA, which this slice
supersedes (section 12 below gives the exact pointer edit).

The user pastes or types a DNA fitting link: the single
line of colon-separated type numbers the EVE client
produces ("Copy to clipboard" fitting links), of the form
ship, then item segments, ending in `::`. Mimir parses it
locally into the same `ImportedFitting` model as EFT, so
display, per-segment problem reporting, copy-back as EFT,
and Save to EVE (pull request #573) all work for DNA
imports unchanged. Every type number resolves against the
bundled `FittingTypes` catalogue offline; importing makes
zero network calls, needs no EVE scope, and stores
nothing. This completes Flutter `importFromText` parity:
Flutter accepted EFT text and DNA links in one box
(`fitting_providers.dart` at `ed698d3`); the Rust panel
accepts EFT only today.

Terms on first use: EFT is the EVE Fitting Tool text
format (`[Ship, Fitting name]` then one item per line).
DNA is the numeric fitting-link format defined in
section 4. AAR means After Action Report; the "AAR
adapter" is Flutter's strict fit-import adapter described
in section 3. SDE is the Static Data Export, CCP's
published game-data dump. ESI is the EVE Swagger
Interface, the EVE Online API; no ESI surface changes in
this slice.

## 1. Value ranking (LOCKED)

When two choices conflict, the higher rank wins. This is
the ranking the slice brief locks; every rule below that
was a genuine choice cites the deciding rank.

| Rank | Value | What it decides here |
|---|---|---|
| 1 | Honesty: never silently drop, guess, misclassify, or display a pasted number as if it were a name | Per-segment issues for every bad segment; unknown ship is fatal, never a fabricated name; drones/charges/cargo are reported unsupported, never mis-slotted; issue text shows resolved names only, never the pasted number |
| 2 | Oracle parity with the inspected Flutter bodies (base parser shape, AAR strictness) | Grammar, quantity-expansion, fit naming, and routing follow the bodies in section 3 rule by rule; divergences are recorded in section 10, never silent |
| 3 | Round-trip through shipped code unchanged (copy back as EFT, Save to EVE) | DNA produces ordinary `ImportedItem` rows with slot quantity 1, so `to_character_fitting`, `fitting_to_eft`, and `build_save_request` need no change |
| 4 | Bounded work, no panics on any input | Byte, segment, expanded-item, and quantity caps from the shipped bounds family plus the AAR 4,096 expanded cap; checked arithmetic; no new dependencies |

Paste convenience (rank 6 in the EFT design) loses to all
four: DNA fields tolerate no interior whitespace, no
leading zeros, and no missing terminator guessing beyond
the exact forms section 4 accepts.

## 2. Hard scope and explicit non-goals

In scope: one pure DNA parser and format router in
`src/fitting/`, one catalogue lookup by type number in
`src/names/fitting_types.rs`, format-aware wording in the
existing import panel, one demo DNA sample, and wording
updates listed in section 9.

Explicitly out of scope:

- No new ESI endpoints, scopes, or network calls of any
  kind. `EveConfig::FITTINGS_SCOPES` is untouched. DNA
  type numbers resolve only against the bundled
  catalogue; the ESI id-resolution endpoint must not be
  used on this path.
- No DNA export or generation. Flutter's `generateDna`
  exists at `ed698d3` but has no production callers (the
  fitting screen copies as EFT only; section 3), and it
  is lossy (drones, fighters, cargo, and loaded charges
  are dropped). Copy-back for a DNA import is EFT,
  through the shipped exporter, exactly like an EFT
  import. There is no "Copy as DNA" button.
- No Pyfa XML or any third format. The router knows
  exactly two formats; anything else fails honestly
  (section 7).
- No simulator statistics and no physical-validity
  checks (slot counts per ship, module-to-ship
  compatibility). The catalogue carries no dogma
  attributes and no slot counts; EFT import does not
  check these either, and DNA adds none.
- No persistence. The imported fitting lives in
  `AppState` memory only, owner-cleared on character
  switch, exactly as today. No new `AppState` fields.
- No changes to the EFT grammar, the EFT write
  contracts (`src/fitting/write_map.rs` is untouched),
  the exporter `fitting_to_eft`, or the bundled
  catalogue asset. Shared-code changes are additive
  only (section 5.4 lists every one).
- No loaded-charge representation from DNA. Neither
  Flutter layer encodes charges in DNA (section 3); a
  charge type number in a DNA link is reported
  unsupported, never attached as a loaded charge and
  never filed as cargo. `charges_noted` is always 0 for
  DNA imports.
- No new crate dependencies. `Cargo.toml` has no
  `regex` crate and this slice adds none; number
  validation is hand-rolled like
  `parse_stack_quantity`.

## 3. Evidence base (inspected bodies)

Flutter bodies were read with `git show ed698d3:<path>`
during discovery and re-read while locking this design.
Dart files must never be restored into the tree.

- `lib/features/fitting/domain/format_parser.dart` at
  `ed698d3`: `parseDna` (lines 265-349) and
  `generateDna` (lines 393-410). The base tolerant
  parser: split on `:`, first part is the ship type
  number, each later non-empty part splits on `;` into
  type number and optional quantity (missing quantity
  means 1), each segment expands into that many fitted
  modules placed by the module's catalogued slot, fit
  name is `Imported <ship name>`. Its silent-drop
  behaviours (unknown numbers skipped, bad quantities
  defaulted to 1, unknown ship named `Ship #<number>`,
  unbounded expansion, full paste in a debug log) are
  the behaviours section 10 explicitly does not copy.
- `lib/features/combat_analyzer/data/aar_fit_import_parser.dart`
  at `ed698d3` (the strict AAR adapter): routing by
  first non-blank line starting with `[` (lines
  130-137), `_parseDna` (lines 262-355), caps and
  validators (lines 49-58, 541-582): 256 KiB input,
  4,096 expanded modules, quantities matching
  `^[1-9][0-9]*$` and at most 2,147,483,647, single-line
  DNA only, at most two trailing empty parts, no empty
  interior segments, at most two `;` fields per segment,
  ship must exist and be category 6, entries must be
  category 7 with a slot or category 32 subsystems.
  This adapter is the strictness source, not the parity
  target: its all-or-nothing exception transport is not
  ported; the Rust per-segment report model is (rank 1).
- `lib/core/sde/sde_service.dart` at `ed698d3`:
  `_slotTypeFor` (lines 1019-1026) maps dogma effects to
  slots in check order 12 high, 13 medium, 11 low,
  2663 rig, 3772 subsystem, falling back to high when no
  effect matches. The fallback is not copied; the check
  order already shipped in Rust `slot_section`.
- `lib/features/fitting/application/fitting_providers.dart`
  at `ed698d3`: `importFromText` (lines 161-180) trims,
  then tries EFT, then DNA. This try-order is superseded
  by the AAR bracket routing rule (rank 1: never fall
  back to the other format after a malformed paste).
- Oracle tests at `ed698d3`:
  `test/features/fitting/domain/format_parser_test.dart`
  (DNA round-trip `587:2048;2::`, quantity expansion
  `587:2048;2:5973;1:484;3::`, unknown-number skip
  `587:999999;1::`, colon-in-fit-name routing) and the
  AAR fixture `587:2048;1::`
  (`aar_fit_import_fixtures.dart`). Section 11 ports
  these inputs verbatim. Verified against the shipped
  Rust catalogue: type 587 is Rifter (category 6),
  2048 is Damage Control II (category 7, low effect 11),
  5973 is a medium module (effect 13), 484 is a high
  module (effect 12), so the expansion oracle holds
  against real data, not only Flutter's mocks.
- Current Rust at `b97d680`: `src/fitting/eft.rs`
  (bounds at lines 23-27, report and fatal model at
  56-217, `slot_section` at 306-320,
  `parse_stack_quantity` at 392-402, `parse_eft` at
  438-667, the "DNA blob is malformed EFT" test at line
  1309); `src/names/fitting_types.rs` (row shape at
  22-31, name lookup at 114-128, no lookup by type
  number exists); `src/ui/fittings.rs` (import panel at
  944-1173, exporter repeat cap `MAX_EFT_SLOT_REPEATS`
  = 16 at line 32, demo sample at 510-529, issue
  rendering at 531-616); `src/fitting/write_map.rs`
  (save name cap 50 characters at line 58, slot-flag
  rules at 101-134); `src/fitting/mod.rs` (module
  layout and re-exports). Catalogue facts verified by
  counting the shipped asset: 25,818 rows, zero
  duplicate type numbers, zero rows with more than one
  slot effect, all 48 subsystem-category rows carry
  effect 3772, and the longest `Imported <ship>` name
  over all 404 ships is 51 characters (the one ship
  whose DNA fit name Save to EVE will shorten with the
  shipped disclosure; section 8).

## 4. DNA grammar (LOCKED)

The parser entry point is
`parse_dna(text: &str, types: &FittingTypes) -> EftImportOutcome`
in the new module `src/fitting/dna.rs` (placement locked
in section 5.4). It is pure like `parse_eft`: no egui, no
state, no network, no database. It never panics on any
input: no `unwrap`, `expect`, or input-derived indexing
outside tests; all arithmetic is checked or saturating;
every loop is bounded by a cap checked before the loop
runs. Steps run in this exact order; the first failing
step decides the outcome.

### 4.1 Bounds and normalisation (before any parsing)

1. Byte cap: if `text.len()` exceeds
   `MAX_EFT_IMPORT_BYTES` (65,536; `src/fitting/eft.rs`
   line 23), return fatal `TooLarge` (reused; its
   wording is format-neutral). The check uses the raw
   pasted text before normalisation, mirroring
   `parse_eft` line 441. The AAR 256 KiB cap is not
   adopted: the shipped 64 KiB bounds family governs
   both formats in one box (divergence D8, section 10).
   A real DNA link is a few hundred bytes.
2. Line-ending normalisation identical to `parse_eft`
   line 445: CRLF to LF first, then lone CR to LF.
3. A leading byte-order mark (U+FEFF) is dropped,
   identical to `parse_eft` line 449.
4. Trim outer whitespace (the `importFromText` trim).
   If nothing remains, return fatal `Empty` (reused;
   its wording changes once, section 9.3).
5. Single line only: if the trimmed text contains a
   line feed, return fatal `DnaMalformed` (new,
   section 6.2). This is the AAR "compact must be
   exactly one line" rule; leading and trailing blank
   lines are already gone after the trim, so a link
   pasted with a trailing newline imports fine.

### 4.2 Ship segment

6. Split the single line on `:`. Fewer than two parts
   (no colon at all, for example a bare ship number or
   plain words) returns fatal `DnaMalformed`. Both
   Flutter layers require at least one colon.
7. The first part is the ship field. It must satisfy
   the positive-number rule (section 4.5). Any other
   shape (empty, `0`, negative, leading zero, letters,
   interior whitespace, over the cap) returns fatal
   `DnaMalformed`: a malformed ship field means the
   paste is not a DNA link, which is a different fact
   from an unknown ship. A ship field of `0` fails here.
8. Resolve the number with the new catalogue lookup by
   type number (section 5.4). No row returns fatal
   `DnaShipUnknown` (new). A row whose `category_id` is
   not 6 returns fatal `DnaShipNotShip` (new). This is
   category-6 hull parity with the EFT header rule
   (`src/fitting/eft.rs` line 485) and with the AAR
   adapter; Flutter base accepts any integer and
   fabricates `Ship #<number>` for unknown hulls, which
   is never copied (rank 1, divergence D2). The EFT
   `ShipAmbiguous` fatal has no DNA counterpart: a
   number lookup returns at most one row by
   construction (section 5.4). Neither new message
   contains the pasted number (rank 1).

### 4.3 Body segments and the trailing terminator

9. The remaining parts are body segment candidates.
   Strip at most two trailing empty parts: they are
   the `::` terminator the EVE client writes. Zero,
   one, or two trailing colons are all accepted; the
   terminator carries no segment and is never counted.
   Hull-only links are therefore valid empty fittings:
   ship followed by `:` or `::` imports with zero
   items and zero issues, in parity with the valid
   EFT header-only fitting.
10. Segment cap: if more than `MAX_DNA_SEGMENTS`
    (1,000, new constant in `src/fitting/dna.rs`)
    candidates remain, return fatal
    `DnaTooManySegments` (new) before examining any
    segment. Refused whole, never truncated (the
    bounds-fatals rule both Rust parsers share).
11. Every remaining candidate is one accounted segment,
    numbered from 1 in paste order. An empty candidate
    (an interior `::`, or a third trailing empty beyond
    the terminator) yields exactly one `EmptySegment`
    issue (new kind, section 6.1). The AAR adapter
    fails the whole link for these; the Rust report
    model accounts per segment instead, so the good
    segments still import and the empty one is named
    by position (rank 1 governs over the AAR
    transport; divergences D4, D5). Flutter base skips
    empty parts silently; that is never copied.

### 4.4 One segment

For each non-empty accounted segment, checks run in this
exact order and the first failure yields the segment's
single issue; a segment that passes every check
contributes items. Exactly one outcome per segment is
the accounting invariant of section 6.3.

1. Split the segment on `;`. More than two fields
   yields `ExtraSegmentFields` (new kind). Flutter
   base ignores extra fields; the AAR adapter rejects
   them; Rust reports the segment (divergence D6).
2. Field 1 is the item number. It must satisfy the
   positive-number rule (section 4.5), else
   `InvalidTypeId` (new kind). This covers non-numeric
   text, `0`, negatives, leading zeros, an empty first
   field (segment starting with `;`), values over the
   cap, and any interior whitespace.
3. Field 2, when present, is the quantity. It must
   satisfy the positive-number rule, else
   `InvalidSegmentQuantity` (new kind). A missing
   second field means quantity 1 (both Flutter layers
   agree). An empty second field (segment ending with
   `;`) is invalid, not 1: Flutter base defaults it to
   1 silently, which is never copied (divergence D3).
   Quantity form is checked before the number is
   resolved, mirroring the EFT stacked-line order
   (`src/fitting/eft.rs` lines 575-579), so a segment
   with both faults reports the quantity fault only
   when the item field itself is well-formed.
4. Resolve the item number by catalogue lookup. No row
   yields `UnknownTypeId` (new kind). Flutter base
   skips unknown numbers silently (its own test pins
   an unknown segment yielding an empty fitting); that
   outcome is inverted here (rank 1, divergence D1).
   An unknown segment does not fail the whole import:
   the ship resolved, so the fitting imports with this
   one segment reported, in parity with EFT
   unknown-name lines.
5. Classify the row (section 5). A module or subsystem
   with no slot effect yields `NoSlotForModule`
   (reused kind; its wording is format-neutral). Any
   other category yields `UnsupportedDnaItem` (new
   kind).
6. Expand the quantity (section 5.2). Crossing the
   expanded-item cap returns fatal `DnaTooManyItems`
   for the whole import (new), discarding everything,
   before any item from the crossing segment is added.

### 4.5 The positive-number rule

One validator serves the ship field, item fields, and
quantity fields, as the AAR `_parsePositiveId` and
`_parseQuantity` share one rule. A field is a valid
positive number when: it is non-empty; it is at most 10
characters; every character is an ASCII digit; the
first character is not `0`; and the value is at most
`MAX_STACK_QUANTITY` (2,147,483,647, reused). This
accepts exactly the AAR set `^[1-9][0-9]*$` bounded by
the same cap (any 11-digit value without a leading zero
already exceeds the cap), and it matches the shipped
`parse_stack_quantity` rules plus the digit check that
function gets from its caller. Whitespace inside a
field fails the digit check: the only whitespace DNA
tolerates is the outer trim of step 4. Non-ASCII digits
fail. A leading `+` or `-` fails. The validator is a new
private helper in `src/fitting/dna.rs`;
`parse_stack_quantity` itself is not modified.

## 5. Classification, quantities, and shared code

### 5.1 Which section a resolved number lands in

Slot identity comes only from the catalogue row: its
`category_id` gates, then the shipped `slot_section`
function (`src/fitting/eft.rs` lines 306-320, dogma
effects in Flutter `_slotTypeFor` check order 12, 13,
11, 2663, 3772) decides the section. DNA segment
position never implies a section; the Flutter
quantity-expansion oracle proves placement is by
catalogued slot, not by position. The full table:

| Catalogue row | Outcome |
|---|---|
| Category 7 (module), `slot_section` returns a section | That `ImportSection` (`Low`, `Medium`, `High`, `Rig`, or `Subsystem`) |
| Category 32 (subsystem), `slot_section` returns a section | That section (on the shipped catalogue always `Subsystem`: all 48 category-32 rows carry effect 3772) |
| Category 7 or 32, no slot effect | `NoSlotForModule` issue (reused kind). Never the Flutter base fallback to high slot |
| Any other category: 6 ship, 8 charge, 18 drone, 87 fighter, 4 material, 9 blueprint, 0 unclassified, anything else | `UnsupportedDnaItem` issue (new kind) |

This is the AAR acceptance set (modules or subsystems
with explicit slots) expressed per segment instead of
as a whole-link failure. Neither Flutter layer gives
drones, fighters, charges, or cargo any DNA
representation: the base parser touches only the five
slot lists and mis-slots everything else as a high-slot
module through its fallback, and `generateDna` counts
only fitted modules. Inventing a drone/cargo mapping
would be ungrounded grammar, and filing a charge
number as cargo (the EFT stacked-line rule) would
misrepresent a number whose DNA meaning no inspected
body defines; rank 1 chooses the reported issue
(divergence D7). A second ship number appearing as a
segment is category 6 and lands in the same row.

Slot conflicts: `slot_section` takes the first matching
effect in check order. The AAR adapter instead requires
every slot effect on a type to agree. Rust keeps the
one shipped slot function as the single slot truth for
both formats (divergence D9); on the shipped catalogue
zero rows carry more than one slot effect, so the two
rules cannot disagree on current data. If a future
catalogue regeneration introduces such a row, both
formats change behaviour together, which is the honest
place for that decision.

There is no per-ship slot-count validation, here or in
EFT: the catalogue carries no slot counts. A link
naming nine low modules imports nine low items;
copy-back writes nine lines, and Save to EVE keeps the
slots EVE defines and names the rest as left out
through the shipped `write_map` disclosure. Nothing is
dropped at import time.

### 5.2 Quantity semantics: expansion, never stacking

A DNA quantity on a slot segment means that many
fitted copies (Flutter base expands the loop; the AAR
adapter counts the same expansion). Rust expands
identically: a segment with quantity N appends N
separate `ImportedItem` rows, each with `quantity: 1`
and `charge: None`, in DNA segment order. Consequences,
all locked:

- The shipped invariant "slot item quantity is always
  1" (`src/fitting/eft.rs` line 196) holds for DNA, so
  nothing downstream can silently multiply or divide:
  `to_character_fitting` hands each copy its own slot
  flag (`LoSlot0`, `LoSlot1`, ... in item order per
  section, the same per-section contiguity Flutter
  assigns); the exporter writes one EFT line per copy
  with a repeat count of 1, so `MAX_EFT_SLOT_REPEATS`
  (16) is never engaged by imported data, exactly as
  the EFT design records; `build_save_request` sees
  distinct flags, never one row with quantity N to
  force down to 1. Storing one row with quantity N
  instead would do the opposite: the exporter would
  truncate the copy at 16 lines with a skipped count
  and the save mapping would collapse N copies into a
  single sent item. Locked against (rank 3).
- Duplicate segments never merge: the same module
  number in two segments, or split as quantity 2 plus
  quantity 1, produces three slot rows either way, in
  parity with EFT plain lines (one line, one row,
  never merged). The EFT stacked-line merger
  `absorb_stack` is not used by DNA, because DNA
  produces no stacked sections (`Drones`, `Fighters`,
  `Cargo` are never produced). `QuantityTooLarge` is
  therefore never emitted by DNA: there is no merge to
  overflow.
- Copy-back is stable: DNA quantity N becomes N EFT
  lines becomes N re-imported items. For an absurd
  link whose expansion exceeds the EFT re-import line
  cap, re-import fails with the shipped `TooManyLines`
  fatal rather than truncating. Real fittings (at most
  a few dozen slots) never approach either cap.

### 5.3 Quantity caps, reconciled

Four numbers meet here and each keeps its own job:

- `MAX_STACK_QUANTITY` (2,147,483,647, reused): the
  largest value any single DNA field may spell. A
  field over it is a form error (`InvalidTypeId` or
  `InvalidSegmentQuantity` per field, or
  `DnaMalformed` for the ship field), never an
  expansion attempt.
- `MAX_DNA_EXPANDED_ITEMS` (4,096, new constant in
  `src/fitting/dna.rs`): the largest total fitted-item
  count one DNA link may expand to, summed across all
  accepted segments in order. This is the AAR
  `maxExpandedModules` value verbatim, the only
  DNA-specific bounds number the inspected bodies
  ground. The running total is checked before each
  accepted segment expands (`total + quantity` must
  not exceed 4,096; exactly 4,096 is accepted), with
  the addition done so a cap-sized quantity cannot
  overflow (`usize::try_from(quantity).unwrap_or(usize::MAX)`
  then the comparison, or checked addition). Crossing
  returns fatal `DnaTooManyItems`, discarding the
  whole import: a link that claims thousands of fitted
  modules is corrupt as a link, and bounds refusals in
  both parsers are whole-import, never truncation.
  Checking before expanding also means the items
  vector never grows past 4,096 rows whatever the
  quantities spell (rank 4).
- `MAX_DNA_SEGMENTS` (1,000): bounds accounted
  segments and therefore the issue list (at most one
  issue per segment), in the same family as the
  1,000-line EFT cap.
- `MAX_EFT_SLOT_REPEATS` (16, exporter): never engaged
  by DNA-imported data because every expanded row has
  quantity 1 (section 5.2). No change.

Subsystem quantities use the identical expansion and
caps as module quantities: a subsystem segment with
quantity N is N subsystem rows. Real subsystem segments
usually omit the quantity (meaning 1); nothing special
is locked for them beyond this sentence.

### 5.4 Shared code: exact file changes for the parser

New file `src/fitting/dna.rs` holds `parse_dna`, the
router `parse_import` (section 7), the positive-number
validator, the by-number classifier, and the two new
constants `MAX_DNA_SEGMENTS` (1,000) and
`MAX_DNA_EXPANDED_ITEMS` (4,096), both `pub`.
`src/fitting/eft.rs` is 1,549 lines of EFT-specific
parsing under a "Pure EFT parser" header; a sibling
module mirrors the `eft` / `write_map` split and keeps
each grammar in one file. `src/fitting/mod.rs` gains
`pub mod dna;` and re-exports `parse_dna`,
`parse_import`, and the two constants alongside the
existing re-exports. The outcome type is reused
verbatim: `parse_dna` and `parse_import` return
`EftImportOutcome`. The type name is EFT-flavoured but
renaming it would churn every shipped call site and
test for a spelling; locked against.

Additive changes in `src/fitting/eft.rs` (the shared
model home), and nothing else there:

- Five new `ImportFatal` variants and six new
  `ImportIssueKind` variants with the fixed strings of
  section 6, added as new match arms. No existing
  variant, message, or reason changes except the one
  `Empty` message of section 9.3.
- A new `ImportFormat` enum (`Eft`, `Dna`; `Debug`,
  `Clone`, `Copy`, `PartialEq`, `Eq` like its
  neighbours) and a `format: ImportFormat` field on
  `ImportedFitting`. `parse_eft` sets `Eft` at its one
  construction site (line 655); `parse_dna` sets
  `Dna`. The field exists so the panel can say
  "segment" for DNA and "line" for EFT (section 6.4);
  no other behaviour reads it in this slice. Three
  test literals construct `ImportedFitting` today
  (`src/app/state.rs` seed helper, two in
  `src/ui/fittings.rs` tests) and each gains
  `format: ImportFormat::Eft` mechanically; this
  compile-forced touch is assigned to Builder A in
  section 12 even though two sit in Builder B's file.
- Visibility lifts to `pub(crate)` for exactly four
  items `dna.rs` needs: `CATEGORY_SHIP`,
  `CATEGORY_MODULE`, `CATEGORY_SUBSYSTEM`, and
  `slot_section`. No other helper is lifted:
  `dna.rs` constructs `ImportIssue` directly (its
  fields are already `pub`) and has its own five-line
  fatal helper mirroring `failed`. `absorb_stack`,
  `split_stack`, `parse_stack_quantity`, and
  `classify_module` are not touched and not used.

Catalogue change in `src/names/fitting_types.rs`:
`FittingTypes` gains a `by_id: HashMap<i64, usize>`
index built in `from_json` alongside `by_normalized`,
plus `pub fn lookup_by_id(&self, type_id: i64) -> Option<&FittingType>`.
Duplicate type numbers, should a future asset ever
contain any (the shipped asset has zero), resolve to
the first row in file order (`entry(...).or_insert`
semantics), pinned by test. `lookup_by_id` returns
`None` for any number with no row, including 0 and
negatives (such rows are already filtered at load).
It logs nothing per call: it sits in a per-segment
loop, and no log line may carry a pasted number in any
case (section 6.5). Loading log lines stay counts-only
as shipped.

## 6. Report model (LOCKED)

DNA rides the shipped report model (`ImportReport`,
`ImportIssue`, `ImportFatal`) with additive variants
only. Field meanings for DNA:

- `ImportIssue.line` carries the 1-based accounted
  segment number (section 4.3 step 11). The field name
  is legacy from EFT; renaming it would churn every
  EFT call site, so the panel wording adapts instead
  (section 6.4). The struct and field are unchanged.
- `ImportReport.imported_lines` counts accounted
  segments that contributed items (one per accepted
  segment, whatever its quantity, mirroring how an EFT
  stacked line counts once).
  `placeholder_lines` is always 0 and `charges_noted`
  is always 0 for DNA (DNA has neither concept), so
  the shipped placeholder and charge notes simply
  never render for DNA imports.
- `ImportedFitting.format` is `Dna` (section 5.4).

### 6.1 Issue kinds: fixed reason strings

Six new kinds, one reused kind. Reasons are fixed
`&'static str` values, contain no type numbers, and are
locked verbatim (tests pin them through the rendered
row template, as the EFT rows are pinned):

| Kind | `reason()` (LOCKED verbatim) |
|---|---|
| `EmptySegment` (new) | `this segment is empty; DNA segments are separated by single colons` |
| `ExtraSegmentFields` (new) | `a DNA segment is one item, optionally followed by a semicolon and a quantity` |
| `InvalidTypeId` (new) | `the item at the start of this segment is not written as a whole number from 1 to 2,147,483,647` |
| `UnknownTypeId` (new) | `Mimir's bundled data has no item for this segment` |
| `InvalidSegmentQuantity` (new) | `the quantity after the semicolon must be a whole number from 1 to 2,147,483,647` |
| `UnsupportedDnaItem` (new) | `DNA links list fitted modules and subsystems only, and this item is not one` |
| `NoSlotForModule` (reused) | `Mimir's bundled data does not say which slot this module fits` (unchanged) |

No other shipped kind is emitted by DNA: `UnknownName`
and `AmbiguousName` speak of names, `InvalidQuantity`
speaks of the EFT `x5` form, `StackedModule` and
`NotAModule` speak of EFT quantity suffixes, the charge
kinds speak of comma lines, `BracketedLine` is
EFT-shaped, and `QuantityTooLarge` needs a merge DNA
never performs. Reusing any of them would put wrong
words in front of the user (rank 1).

### 6.2 Fatals: fixed message strings

Five new fatals, two reused. Messages are locked
verbatim and never contain the pasted ship number:

| Fatal | `message()` (LOCKED verbatim) |
|---|---|
| `DnaMalformed` (new) | `Could not import: paste an EFT block starting with [Ship name, Fitting name], or a single-line DNA fitting link. Nothing was imported.` |
| `DnaShipUnknown` (new) | `Could not import: Mimir's bundled data has no ship for this DNA link. Nothing was imported.` |
| `DnaShipNotShip` (new) | `Could not import: this DNA link does not start with a ship in Mimir's bundled data. Nothing was imported.` |
| `DnaTooManySegments` (new) | `That DNA link has too many segments to import (limit 1,000 segments). Nothing was imported.` |
| `DnaTooManyItems` (new) | `That DNA link has too many fitted items to import (limit 4,096 items). Nothing was imported.` |
| `Empty` (reused) | Wording updated once; section 9.3 |
| `TooLarge` (reused) | Unchanged; already format-neutral |

`DnaMalformed` deliberately covers every "this is not
a DNA link" shape with one honest sentence (no colon,
malformed ship field, multi-line non-EFT paste), so a
paste that is neither format gets routing guidance
instead of a format-specific complaint (section 7).
The EFT fatals `HeaderMalformed`, `ShipUnknown`,
`ShipAmbiguous`, `ShipNotShip`, and `TooManyLines` are
never returned by `parse_dna`: their wordings describe
names and lines, and the DNA twins above exist
precisely so DNA pastes never show them.

### 6.3 Issue text: names only, never the pasted number

For EFT, `ImportIssue.text` echoes the user's trimmed
line, which is a name and safe to show. For DNA the raw
segment is digits; echoing it would display a bare type
number as if it were an item identity, which rank 1
and the panel's never-a-raw-number rule forbid. Locked
instead:

- If the segment's first field parses under
  section 4.5 and resolves by catalogue lookup, `text`
  is the row's canonical catalogue name (for example a
  drone segment reports its real drone name beside the
  unsupported reason, so the user can recognise the
  item). This display lookup runs for every non-empty
  segment issue, including form errors in later fields
  (`ExtraSegmentFields`, `InvalidSegmentQuantity`),
  and never changes which kind is reported: kind order
  is section 4.4, the lookup is display-only.
- If no name is available (unparseable first field, or
  a number with no catalogue row), `text` is the fixed
  string `unresolved item`.
- For `EmptySegment`, `text` is the empty string,
  which truthfully shows the emptiness and contains no
  number.

Ship fatals carry no text at all (fatals have no issue
rows), so the pasted ship number is displayed nowhere:
not in a message, not in a reason, not in issue text,
not in the fit name (section 8 uses the canonical
catalogue ship name), and not in any log line
(section 6.5). Accepted items display through
`ImportedItem.name`, always the canonical catalogue
name. The segment number itself (the position, 1,
2, 3, ...) is displayed as the row position, which is
the locator the brief requires, not a type identity.

Accounting invariant, restated for segments and pinned
by test (section 11): for every `Imported` DNA outcome,
`report.imported_lines + report.issues.len()` equals
the accounted segment count (parts after the ship,
minus the stripped terminator of section 4.3 step 9),
and `placeholder_lines` and `charges_noted` are 0.
Each accounted segment contributes items (counted once
in `imported_lines`) or exactly one issue. Fatal
outcomes produce no fitting and the invariant does not
apply.

### 6.4 Panel wording for segments

The four shipped wording helpers in
`src/ui/fittings.rs` become format-aware on
`ImportedFitting.format`; EFT output stays
byte-identical and DNA says "segment":

- Issue row: EFT `Line {n}: "{text}" - {reason}.`
  (unchanged); DNA (LOCKED)
  `Segment {n}: "{text}" - {reason}.` The 120-character
  truncation rule is shared unchanged.
- Issues heading: DNA (LOCKED)
  `1 segment could not be imported:` and
  `{n} segments could not be imported:`.
- Issues overflow: DNA (LOCKED)
  `...and 1 more segment that could not be imported. Fix the segments above and import again to see the rest.`
  and the plural with `segments` in both places.
- Summary line: DNA (LOCKED)
  `Imported "{name}" ({ship}): {items} items from {segments} segments.`
  where `{segments}` is `report.imported_lines`.

Exact function signatures are Builder B's mechanism
(passing `ImportFormat` into the helpers is the
expected shape); the strings above are the lock, and
the shipped EFT template tests must pass with their
assertions unchanged, gaining only the new argument.

### 6.5 Logging

All parser and panel logs use the `[FITTING]` tag and
counts or categories only: byte counts, segment counts,
item counts, issue counts, the format word (`eft` or
`dna`), and fatal variant names via `{:?}` as shipped.
Never pasted text, never a pasted number, never tokens
(no token exists on this path). `parse_dna` logs entry
bytes and completion counts mirroring `parse_eft`'s
lines; the router logs the detected format word once.
Flutter base logs the full DNA string at debug level;
that is never copied (divergence D10). No log line in
this slice needs the repository logger file the old
Flutter guidance names; Rust `tracing` with the
`[FITTING]` tag is the shipped pattern.

## 7. Format routing (LOCKED)

One new pure function in `src/fitting/dna.rs`:

`parse_import(text: &str, types: &FittingTypes) -> EftImportOutcome`

The import panel's Import click (`src/ui/fittings.rs`
line 977) calls `parse_import` where it calls
`parse_eft` today; everything after the call (storing
the fitting or the fatal message, owner stamping,
logging counts) is unchanged. Routing rule, from the
AAR adapter's `_firstNonemptyStartsWithBracket`:

1. Replicate the parsers' normalisation for scanning
   only (line endings, leading byte-order mark), then
   find the first line whose trim is non-empty.
2. If that trimmed line starts with `[`, return
   `parse_eft(original_text, types)`. A colon inside
   an EFT fit name (`[Rifter, PvP: Armor]`) therefore
   routes EFT; containment of `:` is never the test.
3. If there is no non-blank line, return
   `parse_eft(original_text, types)`, which yields the
   shipped `Empty` (or `TooLarge` for an oversized
   blank paste) exactly as today.
4. Otherwise return `parse_dna(original_text, types)`.

Each parser receives the original unmodified text and
normalises internally, so EFT routing is byte-identical
in behaviour to today: same function, same input.
There is no fallback in either direction: a `[` paste
with a malformed header fails as EFT
(`HeaderMalformed`) and is never retried as DNA; a
non-`[` paste that is not a DNA link fails with
`DnaMalformed` (section 6.2, whose wording names both
acceptable forms) and is never retried as EFT. A paste
that is neither format therefore fails honestly and
imports nothing, never a silent partial import under
the other grammar. `parse_eft` itself is unchanged: a
DNA string passed to it directly still returns
`HeaderMalformed`, and its existing test at line 1309
stays valid word for word; all new behaviour arrives
through the router. Flutter's `importFromText`
try-EFT-then-DNA order is superseded by this rule
(rank 1; it depends on the base EFT parser returning
null, a shape the Rust fatal model deliberately does
not have).

## 8. Fit naming (LOCKED)

A DNA import is named `Imported <ship name>`, where the
ship name is the canonical catalogue name of the
resolved ship row (Flutter base parity:
`'Imported $shipTypeName'`). `ImportedFitting.name`
carries that string, `ship_name` carries the same
canonical name, and `ship_type_id` carries the resolved
row's number. The name is stored untruncated at import,
in parity with EFT header names. On Save to EVE the
shipped `write_map` machinery applies unchanged: names
over 50 characters are shortened to the first 50 with
the confirmation disclosing the original length.
Verified against the shipped catalogue, exactly the
longest ship name crosses that line (51 characters
with the prefix), and its disclosure is already built
and tested; DNA adds no naming code beyond the prefix
rule. Copy-back writes the name into the EFT header
through the shipped sanitiser; catalogue ship names
contain no brackets or commas (a shipped catalogue
invariant test pins this), so the header round-trips.

## 9. User-visible wording and the demo story (LOCKED)

All strings below are locked verbatim. None of them
contains an example type number: a worked numeric
example in help text would display bare numbers the
rest of this design works to keep off the screen.

### 9.1 Panel strings (Builder B, `src/ui/fittings.rs`)

- Heading (today "Import a fitting from EFT text") becomes
  `Import a fitting from EFT or DNA text`.
- Helper label becomes
  `Paste an EFT block (the [Ship, Fitting name] text format) or a DNA fitting link (the single line of separated numbers the EVE client copies). The imported fitting stays in Mimir on this device unless you save it to EVE below, and it is gone when you switch characters or close Mimir.`
  (The tail sentence is unchanged from today.)
- Text-box hint becomes
  `Paste EFT text ([Ship, Fitting name] then one item per line) or a DNA fitting link (one line, ending ::)`.
- Segment wording for issue rows, headings, overflow,
  and the summary line: section 6.4.
- The copy button stays `Copy imported fitting as EFT`
  for both formats; there is no DNA copy button.

### 9.2 Demo sample DNA (Builder B)

A second demo button, `Use sample DNA`, demo mode only,
immediately beside the shipped `Use sample EFT` button
and with the same state effects (fills the box, clears
any imported fitting and error, clears the owner). The
sample constant `DEMO_SAMPLE_DNA` sits beside
`DEMO_SAMPLE_EFT` and is LOCKED verbatim:

`587:2048:1183;1:438;1:448;1:2889;3:31668;1::`

It is the shipped sample Rifter's fitted modules with
the placeholder, loaded charge, drones, and cargo
removed (DNA lists fitted modules only): Damage
Control II with the quantity omitted (the default-1
form), Small Armor Repairer II, 1MN Afterburner II,
Warp Scrambler II, three 200mm AutoCannon II as one
quantity-3 segment (the expansion form), and Small
Projectile Burst Aerator I. Expected outcome, pinned by
the demo test twin of
`demo_sample_parses_with_one_placeholder_and_one_charge`:
imports
through `parse_import` with zero issues, six imported
segments, eight items, ship Rifter, name
`Imported Rifter`, format `Dna`; and its copy-back
re-imports cleanly as EFT with zero exporter skips,
twinning
`demo_sample_round_trips_through_exporter_with_zero_skips`.
Every number
above was verified against the shipped catalogue while
locking this design (section 3).

### 9.3 Shared wording (Builder A) and documents (Integrator)

- `ImportFatal::Empty` message becomes
  `Paste an EFT block or a DNA fitting link first - the import box is empty.`
  (today it names EFT only). This is the single
  changed shipped string in the slice; the variant and
  its trigger are unchanged, and the pinning test in
  `src/fitting/eft.rs` updates its one assertion.
  Builder A makes this edit with the new fatal arms.
- `README.md`, Fittings bullet: the sentence beginning
  "EFT text can also be pasted or typed into the view"
  becomes
  "EFT text or a DNA fitting link can also be pasted or typed into the view to see a local imported fitting — every ship and module name is resolved against a bundled catalogue, any line or DNA segment that cannot be imported is shown with its reason instead of being dropped, and the result can be copied back as EFT; importing makes no network calls and needs no EVE scope."
  and the Roadmap Fitting bullet gains "and local
  in-memory DNA link import" in its shipped-features
  list. (Em dashes rendered as in the file's existing
  style; the Integrator matches surrounding
  punctuation.)
- `docs/fittings-import-design.md` section 2: append
  one sentence after the "No other formats" bullet:
  "Superseded for DNA by `docs/fittings-dna-import-design.md`: DNA links now route to a DNA parser instead of failing the header rule; every other exclusion in this section stands."
  The locked EFT design is not otherwise rewritten.
- Engineering journal (`docs/engineering-journal/`):
  the Integrator adds one `DECISIONS.md` entry
  recording "DNA strictness comes from the AAR
  adapter, expressed through the per-segment report
  model; `generateDna` not ported (dead and lossy in
  Flutter)", with rejected alternatives (base-parser
  tolerance; drone/cargo mapping) and a revisit
  condition (a grounded EVE DNA grammar that
  represents drones or cargo). In the same integrator
  commit, per repository practice.

## 10. Divergences from Flutter, recorded (LOCKED)

Each divergence is deliberate; silence about any of
them would be a defect. "Base" is `parseDna`, "AAR" is
the strict adapter.

| ID | Behaviour | Flutter | This slice | Why |
|---|---|---|---|---|
| D1 | Unknown item number | Base skips silently (test pins an empty fitting) | `UnknownTypeId` issue with segment position; fitting still imports | Rank 1; EFT unknown-line parity |
| D2 | Unknown or non-ship hull | Base imports with fabricated `Ship #<number>` name, no category check | Fatals `DnaShipUnknown` / `DnaShipNotShip`, number never displayed | Rank 1; EFT header and AAR parity |
| D3 | Bad quantity (non-numeric, empty, zero, negative, overflow, leading zero) | Base defaults to 1, or expands zero times, silently | `InvalidSegmentQuantity` issue; segment contributes nothing | Rank 1; AAR strictness |
| D4 | Empty interior segment | Base skips; AAR fails the whole link | `EmptySegment` issue; other segments import | Rank 1 via the report model over the AAR transport |
| D5 | More than two trailing empties | Base tolerates any; AAR fails the whole link | Two stripped as terminator; each extra is an `EmptySegment` issue | Same as D4 (one uniform rule) |
| D6 | Extra `;` fields | Base ignores; AAR fails the whole link | `ExtraSegmentFields` issue | Same as D4 |
| D7 | Drone, fighter, charge, cargo, ship numbers as segments | Base mis-slots as high modules; AAR fails the whole link | `UnsupportedDnaItem` issue naming the resolved item | Rank 1; no grounded DNA representation exists |
| D8 | Input byte cap | AAR 256 KiB; base uncapped | 64 KiB, the shipped family cap for the shared box | Rank 4; one box, one cap |
| D9 | Type with several slot effects | AAR requires unanimity, else reject | First match in shipped check order via the one `slot_section` | Single slot truth; zero shipped rows differ (verified) |
| D10 | Logging the paste | Base debug-logs the full DNA string | Counts, categories, and variant names only | Slice logging bound |
| D11 | Format selection | `importFromText` tries EFT, falls back to DNA on null | Bracket routing, no fallback in either direction | Rank 1; AAR rule; Rust has fatals, not nulls |
| D12 | DNA generation | `generateDna` exists, no production callers, lossy | Not ported; copy-back is EFT only | Rank 2 reads the product behaviour, not the dead code |

Behaviours kept at parity and worth stating: segment
slot placement by catalogued effect (never by
position), quantity expansion into per-slot copies in
segment order, missing quantity means 1, subsystems
supported, the number grammar and the 2,147,483,647
cap, the 4,096 expanded cap, `Imported <ship>` naming,
single-line links, at most the `::` terminator, and
bracket-first routing with colon-in-fit-name safety.

## 11. Test plan (LOCKED)

Gates for every implementation commit are the
continuous-integration gates in
`.github/workflows/ci.yml`: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, and
`cargo test`, all green. Tests use a two-layer fixture
strategy mirroring the shipped EFT tests: a small
hand-written catalogue literal in `src/fitting/dna.rs`
tests (reusing the EFT fixture numbers so the files
read alike: solo ship 1003, duplicate-name ships
1001/1002, low 2001, medium 2002, high 2003, rig
2004, subsystem 2005 category 32, slotless 2006
category 7, drone 3001, fighter 3002, charge 4001,
widget 5001 category 4) for grammar rules, and the
bundled catalogue for real-number oracles. The
duplicate-name pair pins that name ambiguity is
unreachable in DNA: one test asserts ship 1001 imports
cleanly by number. Module row 2001 doubles as the
non-ship hull for the `DnaShipNotShip` test.

Ported Flutter oracles, inputs verbatim:

1. Bundled: `587:2048;2::` imports ship Rifter with
   two low Damage Control II rows, quantity 1 each,
   name `Imported Rifter`, zero issues; copy-back EFT
   contains the header `[Rifter, Imported Rifter]`
   and two Damage Control II lines (the Rust form of
   the Flutter round-trip, since DNA generation is
   excluded), and re-imports to the same items.
2. Bundled: `587:2048;2:5973;1:484;3::` expands to two
   low, one medium, three high rows in segment order.
3. Bundled: `587:2048;1::` (the AAR supported fixture)
   imports one low row.
4. Bundled, inverted: `587:999999;1::` imports with
   zero items and exactly one `UnknownTypeId` issue at
   segment 1 whose rendered text is `unresolved item`
   (explicitly not the Flutter empty-fitting silence).
5. Routing: `parse_import` on
   `[Rifter, PvP: Armor]` plus a module line imports
   as EFT with fit name `PvP: Armor`.

Grammar and adversarial corpus (fixture unless noted);
every `Imported` case also asserts the section 6.3
invariant with an independent segment recount helper,
twinned on the EFT `assert_invariant`:

- Empty and whitespace-only input: `Empty`, through
  both `parse_dna` and `parse_import`.
- Oversized input (over 65,536 bytes): `TooLarge`,
  including an oversized blank paste through
  `parse_import`.
- Colons only (`:`, `::`, `:::` with no ship): the
  ship field is empty, so `DnaMalformed` in each case.
- No colon (`1003`, plain words): `DnaMalformed`.
- Hull-only forms `1003:` and `1003::`: valid, zero
  items, zero issues. With a segment present, zero,
  one, and two trailing colons (`1003:2001`,
  `1003:2001:`, `1003:2001::`) all import identically.
- Ship field `0`, negative, leading zero, letters,
  interior space, over-cap digits: `DnaMalformed`
  each. Unknown ship number: `DnaShipUnknown`.
  Catalogue module number as hull: `DnaShipNotShip`.
  Bundled twins: module 2048 as hull is
  `DnaShipNotShip`.
- Multi-line DNA (link, newline, link), DNA with an
  interior carriage return, and CRLF plus outer
  whitespace plus leading byte-order mark around one
  valid link (the last imports cleanly).
- Quantity forms on one module segment: omitted
  (imports one), `;1`, `;0`, `;-1`, `;007`, `;abc`,
  bare trailing `;`, `;2147483647` as a slot quantity
  (form-valid, so `DnaTooManyItems`, not a quantity
  issue), `;2147483648` and a 20-digit quantity
  (`InvalidSegmentQuantity`), each reported once.
- Item-field forms: `0`, negative, letters, empty
  first field, leading zero: `InvalidTypeId` each.
- Extra fields (`2001;1;9`): `ExtraSegmentFields`, and
  its issue text is the resolved module name
  (section 6.3 display rule).
- Interior empty segment and three trailing colons
  after a valid segment: one `EmptySegment` issue
  each at the right position, valid segments import.
- Duplicate segments and split quantities (`2001;2`
  then `2001;1`, and `2001` twice): three and two
  separate quantity-1 rows, never merged.
- Caps: exactly 4,096 expanded items imports; 4,097
  in one segment and a crossing split across two
  segments each return `DnaTooManyItems`; 1,001
  accounted segments return `DnaTooManySegments`
  while 1,000 import.
- Classification: subsystem segment lands in
  `Subsystem` (quantity omitted and `;2` forms);
  slotless module is `NoSlotForModule` with its name
  as issue text; drone, fighter, charge, widget
  (category 4), and a ship row as segments are
  `UnsupportedDnaItem` each with resolved names as
  text. Bundled twins: Hobgoblin II (2456), EMP S
  (185), and Tritanium (34) segments are unsupported
  with those names shown.
- Cross-routing: `parse_eft` on a DNA string still
  returns `HeaderMalformed` (shipped test untouched);
  `parse_dna` on EFT text returns `DnaMalformed`;
  `parse_import` on a `[` paste with a malformed
  header returns the EFT fatal (never a DNA outcome);
  `parse_import` on non-format words returns
  `DnaMalformed`; leading blank lines before a DNA
  link still route DNA.
- Never panics: one adversarial test in the shipped
  style runs the whole corpus above plus emoji,
  embedded NUL, non-ASCII digits, very long digit
  fields, and segments of only separators through
  `parse_import`, asserting an outcome (imported or a
  named fatal) for each.
- Number-display sweep: for every fatal message and
  every rendered issue row produced in the DNA tests,
  assert the pasted item numbers used as inputs do
  not appear as substrings (segment positions and the
  fixed limit numbers in locked strings excepted by
  construction; test inputs choose numbers colliding
  with neither).

Catalogue tests (`src/names/fitting_types.rs`):
bundled `lookup_by_id(587)` is the Rifter row and
`lookup_by_id(2048)` carries the low effect; unknown,
zero, and negative numbers return `None`; a literal
fixture with a duplicated type number resolves to the
first row.

Save and copy interplay (parser tests): the
synthesised fitting from a quantity-3 segment carries
three distinct slot flags; `build_save_request` keeps
all three at quantity 1; and the exporter emits three
lines with zero skips.

Panel tests (`src/ui/fittings.rs`, Builder B): the DNA
issue row, heading, overflow, and summary templates
byte-equal section 6.4; the shipped EFT template tests
pass unchanged apart from the new format argument; the
two demo-DNA tests of section 9.2; and a test that the
panel strings of section 9.1 are the rendered ones
where the shipped tests already pin such strings.

## 12. Ownership, commits, and sequencing (LOCKED)

Staffing follows the slice brief: builders run
`muse-ember-1.0` at maximum effort with gates proving
each commit; design (this document), integration, and
adversarial review run `muse-wonder-full-1.0`. No
child inherits a model by omission. Commits are small
and atomic in `type(scope): description` form with no
attribution lines. Nobody pushes or merges; the parent
does that.

- Design (this commit): `docs(fittings): lock DNA link import design`
  — this file only.
- Builder A, commit 1:
  `feat(fittings): resolve catalogue types by number`
  — `src/names/fitting_types.rs` (`by_id`,
  `lookup_by_id`, tests) only.
- Builder A, commit 2:
  `feat(fittings): parse DNA fitting links locally`
  — `src/fitting/dna.rs`, `src/fitting/mod.rs`, the
  additive `src/fitting/eft.rs` changes of
  section 5.4 including the section 9.3 `Empty`
  wording, and the compile-forced `format:` additions
  to the three `ImportedFitting` test literals
  (`src/app/state.rs`, `src/ui/fittings.rs`). All
  parser, routing, invariant, interplay, and
  number-display tests of section 11 that do not need
  panel wording. This commit must compile and pass
  gates on its own; the panel still calls `parse_eft`
  here, so user-visible behaviour is unchanged until
  Builder B.
- Builder B, commit 1 (rebased on Builder A):
  `feat(fittings): offer DNA import in the fittings panel`
  — `src/ui/fittings.rs` only: the `parse_import` call
  site, format-aware wording helpers and their tests,
  section 9.1 strings, `DEMO_SAMPLE_DNA`, the
  `Use sample DNA` button, and the demo tests.
- Integrator, one commit:
  `docs(fittings): document DNA link import`
  — the `README.md`, `docs/fittings-import-design.md`,
  and engineering-journal edits of section 9.3, after
  running the stale-claim sweep (`DNA` across
  `README.md`, `docs/`, and `src/` comments must agree
  with this design; the EFT design's "reported as
  malformed" sentence is the known hit the pointer
  sentence resolves) and the full gates. The
  Integrator also verifies no file outside the lists
  above changed (`Cargo.toml`, `src/config.rs`,
  `src/fitting/write_map.rs`, the catalogue asset, and
  `AppState` fields all untouched) and that `git diff`
  on `parse_eft`'s body is empty apart from the one
  `format:` field at its construction site.

Sequencing is strictly A then B then Integrator:
Builder B's wording helpers need `ImportFormat`, and
the demo test needs `parse_import`. Builder A must not
edit panel strings beyond the compile-forced literals;
Builder B must not edit `src/fitting/` at all — a
parser gap found by B goes back to A as a new commit,
never a panel workaround.

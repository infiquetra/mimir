# Editing loaded charges on draft module rows — design

Status: locked for the `feat/rust-charge-editing` slice.
Base: `develop` at `465f732` (1,091 tests; the fitting
editor, module browser, new-fitting-from-scratch, editing a
copy of a saved fitting, and changing a draft's ship are all
merged there — see `docs/fitting-editor-design.md`,
`docs/fitting-module-browser-design.md`,
`docs/new-fitting-design.md`,
`docs/edit-saved-copy-design.md`, and
`docs/change-ship-design.md`). Slice branch:
`feat/rust-charge-editing`. This document is the single
design commit; builders and the integrator implement exactly
what is locked here and nothing else.

The editor design deferred this piece by name: "Charge
editing: adding, changing, or removing a loaded charge on
its own. Charges are display-only, excluded from copy and
save, and have no fitment proof data (no charge-group
compatibility in the catalogue seams used here)"
(`docs/fitting-editor-design.md` section 11). The DPS
design repeated the state it found: "No body on any surface
checks charge-to-weapon compatibility (`chargeSize`,
`launcherGroup`), Flutter's engine included"
(`docs/fitting-dps-design.md` section 2.3). This design
settles the fitment question from the committed data
(section 2.3): the charge-group join is provable end to end
from files already in the repository, so this slice emits
it, loads it, and checks it. The charge-size half is not
provable as a general rule from those files, so it is
neither emitted nor checked, and the locked wording says
so (sections 2.3 and 8). Nothing in this slice implies a
check that does not run.

Discovery: two read-only reports re-verified during design
against the bodies named below, with every count in
sections 2 and 3 re-scripted during design over
`assets/sde/fitting_types.json` (3,754,697 bytes, sha256
`69967d0030457087e88b9b88ebe9bdc0292d44c4a60cf75c8b58f048145db772`
at base), `scripts/sde/dgmTypeAttributes.csv.bz2`,
`scripts/sde/invTypes.csv.bz2`, `scripts/sde/invGroups.csv.bz2`,
and `dogmaAttributes.jsonl` inside
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`,
plus the retired Flutter tree at `ed698d3` read via
`git show`. All file and line references are to the base
tree at `465f732` unless a Flutter reference says `ed698d3`.

## 1. Goal and value ranking

Let the user set, change, and clear the loaded charge on
any fitted module row of the draft they are already
editing, by exact catalogue name, so the pairing that the
damage-per-second (DPS) block computes from is something
they can build inside Mimir instead of only something an
EFT paste can bring in. Today charges exist on a draft
only when imported EFT text spelled them
(`Module, Charge`), so a fitting created from scratch, a
copied saved fitting, and a DNA import can never show
turret or launcher DPS at all. After this slice they can:
type a charge name on the module's own item row, and the
next frame's DPS, Loaded charges list, and every
charges-left-out disclosure read the new pairing through
the paths that already exist.

Value ranking (locked, in order):

1. **Never claim a check that does not run.** The slice
   checks exactly one compatibility fact — that the
   charge's group is one of the groups the bundled data
   lists for that module (section 2.3) — and its wording
   claims exactly that, including naming the charge-size
   check it deliberately does not make (section 8). A
   pairing Mimir cannot prove is refused in words, never
   quietly accepted; a pairing Mimir accepts is never
   described as more proven than the group join makes it.
2. **The editor's rules are the importer's rules.** The
   rows that may carry a charge, the name lookup, the
   category proof, and three of the four refusal wordings
   are the importer's, called or mirrored exactly
   (sections 2.1, 2.2, and 4). One grammar for "what
   charge may sit on a row", with the group check as the
   single named addition, because import transcribes a
   user's text while the editor helps build a new
   pairing (section 4.4).
3. **The edited charge is the charge every downstream
   path sees.** Set, change, and clear mutate only
   `ImportedItem.charge` and recount `charges_noted`;
   DPS, the Loaded charges block, the local resolver, and
   the copy/save disclosures already derive from those
   per frame (section 6). Copy and save keep excluding
   charges exactly as today, with the recount keeping
   their disclosures truthful. No second representation
   and no cached pairing can drift.
4. **An untouched draft renders byte-for-byte as today.**
   New controls sit on rows that already render; the one
   downstream behavior change (the DPS pairing surface,
   section 5) activates only on a draft that actually
   carries a charge.

## 2. Evidence: charges today, and what compatibility can be proven

### 2.1 The charge model at base

- `ImportedCharge { type_id, name }`
  (`src/fitting/eft.rs:269-273`) riding on
  `ImportedItem { type_id, name, section, quantity,
  charge: Option<ImportedCharge> }` (`src/fitting/eft.rs:
  275-283`) is the whole model. `ImportReport`
  (`src/fitting/eft.rs:182-189`) carries `charges_noted`,
  a parallel counter the editor already recounts after
  every successful edit (`recount_charges`,
  `src/fitting/editor.rs:83-89`).
- Charges are display-and-DPS only: `to_character_fitting`
  excludes them (`src/fitting/eft.rs:306-358`), the ESI
  wire shapes have no charge field to send one in
  (`src/esi/models.rs` `FittingItem` is flag, quantity,
  type number), and `name_resolver()` re-derives charge
  names from the rows every call (`src/fitting/eft.rs:
  364-375`). There is no `set_charge` or `clear_charge`
  symbol anywhere in `src/` today.

### 2.2 Which rows may carry a charge, and how import proves a charge

Only slot-section rows (Low, Medium, High, Rig,
Subsystem), never stacked rows (Drones, Fighters, Cargo).
The importer's comma handler (`src/fitting/eft.rs:
618-666`) stores `charge: Some` only after
`classify_module` (`src/fitting/eft.rs:418-438`) proves
the module side of the line — category 7 or 32 with a
`slot_section` (`src/fitting/eft.rs:393-407`, dogma slot
effects 12, 13, 11, 2663, 3772 in that order) — and every
other creation path hard-codes `charge: None` (plain
lines, `absorb_stack`, DNA, copied and created drafts,
the editor's adds). So every slot row in any draft is
already module-proven at entry, whatever its provenance,
and its section is the proof this design reuses; no
charge can exist on a stacked row, and DPS's `slot_rows`
(`src/fitting/dps.rs:358-391`) already ignores anything
outside the five slot sections.

Import proves the charge side in `src/fitting/eft.rs:
637-656` by the catalogue lookup every other name takes:
`FittingTypes::lookup` (`src/names/fitting_types.rs:
420-434`, normalized-exact, never substring or fuzzy)
yields Unknown, Ambiguous, or a row whose category must
be 8 (charge). Those three conditions are the import
issue kinds `UnknownCharge`, `AmbiguousCharge`, and
`NotACharge` (`src/fitting/eft.rs:91-93`) with fixed
reason sentences (`src/fitting/eft.rs:138-144`). On
success the importer stores the catalogue row's canonical
name, never the typed text. Module-to-charge fit is not
checked at import, and this slice does not add it there
(section 4.4).

### 2.3 Compatibility: the group join is proved, the size rule is not

**The group join (locked as the one compatibility
check).** From `dogmaAttributes.jsonl` in the pinned zip,
attributes 604, 605, 606, 609, and 610 are `chargeGroup1`
through `chargeGroup5`, each described "One of the groups
of charge this launcher can be loaded with". A module's
values for those attributes in the committed
`dgmTypeAttributes.csv.bz2` are its accepted charge
groups; a charge's own group is its `groupID` column in
the committed `invTypes.csv.bz2`. The generator already
reads both caches (`scripts/sde/generate_fitting_types_sde.py`
header). Scripted at the base catalogue of 25,818 rows:

- 980 slot-proven category-7 rows (category 7 with a slot
  effect — the importer's proof, section 2.2; no
  category-32 row carries a group attribute) hold one or
  more group values: 1,489 values in total, list lengths
  1–3, every value a positive whole number, no value
  repeated within a row, and every value resolving to an
  `invGroups` group of category 8. They include 637 of
  658 `turretFitted` rows and all 147 `launcherFitted`
  rows, plus 200 carriers with neither marker — script
  modules, capacitor boosters, ancillary repairers and
  boosters, command bursts, probe and bomb launchers —
  which legitimately load charges in EVE even though the
  DPS pass never reads them (it requires a firing cycle,
  section 5). The 21 `turretFitted` rows without values
  are the basic mining lasers, gas scoops, and ice
  miners (for example 482 Miner II), which take no
  crystal; the modulated mining modules that do take
  crystals carry groups (for example 17912 Modulated
  Strip Miner II).
- All 1,005 category-8 rows have an `invTypes` group: 67
  distinct charge groups. Every one of the 980 carriers'
  accepted groups contains at least one catalogue charge
  (no dead carrier), and 60 of the 67 charge groups are
  accepted by at least one slot-proven carrier. The
  remaining seven groups (1546, 1547, 1548, 1549, 1551,
  1976, 4186 — structure missiles, bombs, scripts, and
  fireworks; 15 charges) are accepted only by
  category-23 and category-66 rows that a draft can never
  hold (drafts admit categories 7 and 32 only), so those
  15 charges are honestly unsettable on any draft row.
- No normalized charge name is ambiguous over the
  shipped catalogue (zero category-8 collisions among
  the catalogue's twelve ambiguous names), so the
  `AmbiguousCharge` refusal is exercised only against a
  hand-built fixture (test 6, section 11).
- The 62 cache carriers absent from the catalogue
  (unpublished types, including 10642 Countermeasure
  Launcher I, whose cache values name groups 84 and 91
  that `invGroups` does not carry) never become catalogue
  rows under the generator's published-row rule, so the
  stale values cannot reach the loader; the generator's
  load still validates cache-wide (section 3.1).

Nothing is missing for this join: no table and no
attribute needs to be fetched, and Flutter holds nothing
to borrow — its `acceptedChargeGroups` field
(`ed698d3:lib/features/fitting/domain/models.dart:297`)
is dead data, assigned `[]` at every call site and never
consumed, with no derivation from attributes 604–610
anywhere in that tree.

**The size rule (locked as not shipped).** Attribute 128
`chargeSize`, "The size of the charges that can fit in
the turret/whatever", tempts a second rule — require the
charge's size to equal the module's — and the turret half
of the data is suggestive: all 637 group-carrying turrets
hold a size, all charges in turret-accepted groups hold
one, and the classes partition evenly (projectile group
83 splits 32/32/32/32 over sizes 1–4). But as a general
refusal rule it is contradicted by the same committed
data: the three small ancillary shield boosters (32774,
41480, 88717) hold a present size of 0.0, which under
equality would accept nothing; capacitor-booster group
87 carries charges with no size row at all (263 Cap
Booster 25, 33330 Navy Cap Booster 25) alongside sized
ones for the same 61 carriers, 43 of which hold no module
size; and no body in the repository — SDE, cache, Rust, or
Flutter at `ed698d3` (whose only booster pairing is a
synthetic fixture, type numbers 700–702, carrying no
attribute 128) — states the rule that reconciles those
rows. Scoping equality to `turretFitted` rows was
rejected: the marker excludes sized carriers whose data
partitions just as cleanly (85084 Small and 85085 Medium
Breacher Pod Launchers at sizes 1 and 2 against their
pods; the modulated strip miners likewise carry no
marker), so the scope would be this design's invention
rather than the data's statement, and no wording could
truthfully describe a check that applies by marker on
some rows and is silently absent on others. Under value
1 this ships the proved half and names the unproved one:
a wrong-size charge of an accepted kind (for example
247 Radio M in a small laser) is accepted and counted in
DPS exactly as recorded, precisely as an imported pairing
is today, and the standing note says the size is not
checked (section 8). Section 12 records the deferral.

## 3. Catalogue extension (locked)

Generator-driven and additive, in
`scripts/sde/generate_fitting_types_sde.py`, cloning the
need-filter slice's shapes (its design section 4): sorted
by type number, compact separators, fail-loud with exit 1
and nothing written on any invalid input row. Sources are
only the committed caches the generator already reads.
Two new keys, appended after `requiredSkillIds` (today's
last keys) in the order `chargeGroupIds`, then
`chargeGroupId`; a row carries at most one of them, and
every other row is byte-identical to today.

### 3.1 Emission rules

- `"chargeGroupIds": [<int>…]` — on exactly the 980
  category-7-or-32 rows that carry a slot effect and at
  least one of attributes 604, 605, 606, 609, 610 in
  `dgmTypeAttributes.csv.bz2`. Values in attribute order
  604, 605, 606, 609, 610, absent slots skipped, emitted
  as integers (86, never 86.0) — the `requiredSkillIds`
  aggregate discipline, and for the same reason: the
  five dogma names differ only by slot ordinal, and no
  key is emitted under two names. Present only when
  non-empty (sparse): absence means the bundled data
  lists nothing this module can be loaded with, mirroring
  `slotEffects`' slot proof, which is what section 4
  consults. The slot-effect and category scope is
  deliberate: category-23 and category-66 group carriers
  (89 rows, starbase batteries and structure modules)
  gain no key, because no locked computation reads them —
  a draft can hold only slot-proven category-7/32 rows —
  and dead data on rows nothing reads was the rejected
  alternative in the need-filter slice too.
- `"chargeGroupId": <int>` — on every category-8 row
  (1,005 rows): the `invTypes groupID` column the
  generator already reads for `categoryId`. A new key,
  deliberately not the need slices' `groupId`: that key
  is locked on exactly the need-carrying category-7
  population (generator fail-loud at the need-filter
  invariant block, Rust invariant at
  `src/names/fitting_types.rs` in
  `bundled_catalogue_invariants`), and its `None`-versus-
  present meaning feeds the resources unprovable-reduction
  count (`src/fitting/resources.rs:249,493`). Charges are
  never counted modules, so reusing the key would change
  nothing computationally and would silently re-mean a
  locked invariant; a charge-scoped key keeps both
  contracts intact.
- Attribute loading follows the capacitor block's global
  fail-loud shape (unlike DPS's skip-negative load: the
  cache carries no questionable row among these five
  attributes, scripted during design — zero duplicates,
  zero unparseable, zero non-finite, zero non-integral,
  zero non-positive values cache-wide): a duplicate,
  unparseable, non-finite, non-integral, or non-positive
  wanted row fails and writes nothing. An unparseable
  `groupID` on a category-8 row fails the same way (the
  need-filter emission's `int(row["groupID"])` precedent).
- Fail-loud after emission, in the need-filter invariant
  style: `chargeGroupId` present exactly when the row is
  category 8, always a positive integer that is not a
  boolean; `chargeGroupIds` only on category-7-or-32 rows
  with non-empty `slotEffects`, always a list of one to
  five positive integers, none repeated within the row.
- The header docstring gains the house paragraph naming
  the two keys, populations, sources, and this design;
  the summary print gains one line:
  `charge_group_keys chargeGroupIds={n} chargeGroupValues={n} chargeGroupId={n}`.

### 3.2 Expected counts, oracles, size, and proofs

Scripted against the shipped catalogue and caches during
design, and locked as generator expected counts
(`CHARGE_GROUP_EXPECTED_COUNTS`, the
`NEED_FILTER_EXPECTED_COUNTS` shape): `chargeGroupIds`
on 980 rows carrying 1,489 values, `chargeGroupId` on
1,005 rows. A simulation of the locked emission
(appending the two keys in compact separators) adds
43,623 bytes, for **3,798,320 bytes expected**; the
regenerated file must land at or below **3,815,000
bytes** or Builder A stops and reports.

`CHARGE_GROUP_ORACLES`, the `(typeId, key,
expected-or-None)` tuple shape of `NEED_FILTER_ORACLES`,
every value read from the caches during design. Present:
(2889 200mm AutoCannon II, `chargeGroupIds`, [83, 372]),
(450 Gatling Pulse Laser I, [86]), (499 Light Missile
Launcher I, [384, 394]), (4256 Bomb Launcher II,
[90, 863, 864]), (1952 Sensor Booster II, [910]), (3568
Small Capacitor Booster II, [87]), (17912 Modulated Strip
Miner II, [482]); (21898 Republic Fleet EMP S,
`chargeGroupId`, 83), (185 EMP S, 83), (210 Scourge Light
Missile, 384), (267 Scourge Torpedo, 89), (239 Radio S,
86), (28668 Nanite Repair Paste, 916), (29009 Targeting
Range Script, 910), (11287 Cap Booster 400, 87). Absence:
(2048 Damage Control II, `chargeGroupIds`), (482 Miner
II, `chargeGroupIds`), (16631 Small Artillery Battery,
`chargeGroupIds` — a cache carrier outside the emission
scope, section 3.1), (587 Rifter, `chargeGroupIds`),
(587, `chargeGroupId`), (2889, `chargeGroupId` — a module
is not a charge), (21898, `chargeGroupIds` — a charge
lists no accepted groups), (2456 Hobgoblin II,
`chargeGroupId`).

**Proof obligations (Builder A, reported in the A1 commit
body, not committed as scripts)**, the need-slice trio:
run the generator twice and compare sha256
(determinism); strip the two new keys from the
regenerated file and compare byte-for-byte with the base
sha256 in this document's header (additive-only proof);
state the exact new byte count. The new asset still loads
on old code (no `deny_unknown_fields`), and old assets
still load on new code (both loader fields are `default`,
section 3.3).

### 3.3 Loader fields and invariants

`FittingType` (`src/names/fitting_types.rs:22`) gains two
fields after `required_skill_ids` (lines 324–327), in a
comment block in the house style naming the sources
(attributes 604–610 aggregated in slot order; the
inventory group column), each `#[serde(default)]`:

```rust
#[serde(rename = "chargeGroupIds", default)]
pub charge_group_ids: Option<Vec<i64>>,
#[serde(rename = "chargeGroupId", default)]
pub charge_group_id: Option<i64>,
```

`PartialEq` is retained; loading, indexing, and lookup
behavior do not change. `Option` follows the
`required_skill_ids` precedent: `None` means this
catalogue carries no such data for the row (every
hand-built fixture without the keys, every old asset),
and section 4 treats `None` and a present-but-useless
value identically — membership cannot be proven, so the
set is refused, never guessed (section 4.2). Group
numbers are internal keys: never rendered and never
logged, like `BrowserRow`'s type number.

Invariants added to `bundled_catalogue_invariants` over
the real bundled asset, existing invariants passing
unmodified: `charge_group_ids` is `Some` only on
category-7-or-32 rows with non-empty `slot_effects`, holds
one to five entries, every entry positive, none repeated,
980 rows and 1,489 values in total; `charge_group_id` is
`Some` exactly on the 1,005 category-8 rows, always
positive; every value in every `charge_group_ids` list
equals at least one category-8 row's `charge_group_id`
(no accepted group is charge-less in the shipped data,
section 2.3); and spot pins identical to section 3.2's
oracles, beside the need-filter spot pins.

## 4. The pure set, change, and clear operations (locked)

### 4.1 Surface

Two new pure functions in `src/fitting/editor.rs`, beside
`set_quantity`, with the module's standing meaning of
pure (no egui, no state, never panics on any input):

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChargeRefusal {
    UnknownCharge,
    AmbiguousCharge,
    NotACharge,
    IncompatibleCharge,
}

pub fn set_charge(
    fitting: &mut ImportedFitting,
    types: &FittingTypes,
    index: usize,
    name: &str,
) -> Result<(), ChargeRefusal>

pub fn clear_charge(fitting: &mut ImportedFitting, index: usize) -> bool
```

`set_charge` is set and change in one operation: it
overwrites whatever `charge` the row carries (including
`None`). `ChargeRefusal::reason()` delegates the first
three variants to the matching `ImportIssueKind::reason()`
— verbatim, per section 8.3 — and returns this design's one
new fixed sentence for `IncompatibleCharge`. A separate
enum, not new `EditRefusal` variants: `EditRefusal`'s
contract is that every variant's wording delegates to the
importer (`src/fitting/editor.rs:32-60`), `ShipChangeOutcome`
set the precedent for a sibling outcome type, and the
add/quantity refusal surface stays untouched. Neither
function is re-exported from `src/fitting/mod.rs`
(the `new_fitting`/`change_ship` precedent); the panel
imports them from `crate::fitting::editor` aliased
`set_charge as editor_set_charge` and
`clear_charge as editor_clear_charge`, beside its existing
aliases (`src/ui/fittings.rs:21-26`). Builder B1 makes
`CATEGORY_CHARGE` (`src/fitting/eft.rs:33`) `pub(crate)` —
visibility only, no behavior change, exactly as the first
editor slice widened `classify_module` — and imports
`ImportedCharge`; the module doc comment
(`src/fitting/editor.rs:1-21`) gains the two operations in
its recount sentence. Beyond that one visibility line the
importers (`eft.rs`, `dna.rs`, `saved_copy.rs`) get no
behavior change: import gains no compatibility check and
no new charge path.

### 4.2 `set_charge`: proof order

Steps, in this order; any refusal mutates nothing except
the caller's error state, logs per section 10, and returns
the kind:

1. **Row eligibility.** The row at `index` must exist and
   sit in a slot section (Low, Medium, High, Rig,
   Subsystem) — the importer's proof by construction
   (section 2.2). Out-of-range or stacked refuses
   `IncompatibleCharge`: the panel renders no set control
   on such rows (section 7), so this branch is
   defense-in-depth in the `set_quantity` posture (slot
   rows and unknown indices take its one refusal there,
   `src/fitting/editor.rs:498-507`), and the locked reason
   sentence is worded about the module every rendered
   control does sit on.
2. **Name resolution, the importer's.** `types.lookup(name)`:
   Unknown refuses `UnknownCharge`, Ambiguous refuses
   `AmbiguousCharge`. The raw box text is passed untouched;
   normalization is the lookup's. An empty or
   whitespace-only name normalizes to nothing and lands
   here as Unknown (the button is separately disabled then,
   section 7). A comma inside the box text has no grammar
   here — this is not an import line, so
   `MalformedChargeLine` has no editor counterpart; the
   text simply lookups or does not.
3. **Category proof, the importer's.** A found row whose
   `category_id` is not 8 refuses `NotACharge` — including
   module names and cargo names alike ("Damage Control II"
   and "Tritanium" are both this refusal).
4. **Compatibility, the one new check.** The charge's
   `charge_group_id` must be a member of the module row's
   `charge_group_ids`, both read from the catalogue: the
   charge side from the found row of step 3, the module
   side from `types.lookup_by_id(item.type_id)`. Anything
   unprovable refuses `IncompatibleCharge`: no catalogue row
   for the draft row's type number, `charge_group_ids` absent
   or empty, `charge_group_id` absent, or membership false.
   Nothing here dereferences a type number into user-facing
   text, and nothing consults a size (section 2.3).
5. **Store and recount.** `item.charge = Some(ImportedCharge
   { type_id, name })` from the found catalogue row —
   canonical name, never the typed text, exactly as import
   stores it — then `recount_charges`.

Setting the charge the row already carries succeeds like
any other set: it stores the identical pair and recounts
(the `rename` precedent, which always stores; there is no
same-charge outcome, because stored charge names are
catalogue-canonical on every path, so the same-number
re-spelling hazard that forced `ShipChangeOutcome::SameShip`
does not exist here).

### 4.3 `clear_charge` and the counters

`clear_charge` mirrors `remove_item`'s contract
(`src/fitting/editor.rs:466-480`): returns `false` and
changes nothing when `index` is out of range, the row is
not a slot row, or the row carries no charge; otherwise it
sets `charge` to `None`, recounts, logs (section 10), and
returns `true`. There is no refusal wording for a clear —
the panel renders the control only when a charge is present,
so `false` is silent defense-in-depth, as an out-of-range
remove is today.

Counter semantics, restating the editor design's section
4.5 on the new operations: `charges_noted` is always the
recount (`items` with `charge.is_some()`), never a hand
increment, so set on a chargeless row raises it by the
recount, change keeps it, and clear lowers it;
`imported_lines`, `placeholder_lines`, and `issues` stay
frozen parse history, so a created draft may now hold
charges with zero imported lines — the edited suffix
(section 7.3) is the disclosure, exactly as it already is
when items are added to a created draft. Item count, order,
quantities, sections, name, ship, and format never change
under either operation. The one shipped edit that
deliberately does not recount, `change_ship`, stays that
way: a ship change moves no charge and re-checks no
pairing, because compatibility here is a property of the
module row, never of the hull.

### 4.4 Why the editor checks fit while import does not

Import is transcription: an EFT block's pairings are the
author's record, Mimir stores them exactly as listed, and
the DPS disclosure has always said so (now "exactly as
recorded", section 8.4). The editor is construction:
Mimir is helping create a pairing that did not exist, and
accepting one its own bundled data contradicts would manufacture
a DPS number from a pairing EVE cannot hold. The asymmetry is
therefore deliberate and recorded, with one accepted
consequence: a charge an import recorded on a module whose
groups do not list it (or on a module listing nothing at all)
stays fully usable — shown, counted in DPS, removable by
clear or by removing the row — but once cleared or changed
away it cannot be set back from the item row; re-importing the
original text brings it back, as re-import restores everything
a draft edit removes. Adding the check to the importer instead
would break faithful transcription and change issue/invariant
accounting (`charges_noted` against imported lines) under a
grammar this slice does not own; section 12 names it deferred.

## 5. DPS consequences and the pairing surface (locked)

`fitting_dps` (`src/fitting/dps.rs:173`) reads pairings
only through `slot_rows` (`src/fitting/dps.rs:358-391`),
which already maps every imported slot row's
`charge` for any draft. One gate decides whether turret
and launcher families exist at all: `is_eft`
(`src/fitting/dps.rs:195`), today format-keyed because
only an EFT import could carry pairings (DPS design
section 2.3). That premise is what this slice ends, so
the gate's meaning widens — and only that far: the pairing
surface is present exactly when the fitting is an `Eft`
draft (unchanged, including with zero charges) or any
other draft carrying at least one charge on any row. In
code terms, Builder B2 redefines the gate (the variable's
name is the builder's; the semantics are locked) as:
imported is `Some` and (its format is `Eft` or any item
has `charge.is_some()`). Every use of the gate keeps its
meaning against the new definition — family initialization,
the not-on-surface unloaded branch, and the volley and
turret-range finals (`src/fitting/dps.rs:196-203,236-241,
313-325`) — so volley, optimal, and falloff appear on a
charged `Dna`/`Created`/`Copied` draft exactly as on an
`Eft` one, and disappear again when its last charge is
cleared, because the surface is a property of the draft's
current rows, never a sticky flag.

This supersedes one cell of the DPS design's surface
table (its section 1: DNA import detail, "No DPS line;
unloaded count"; its section 2.3 DNA bullet): a DNA draft
behaves as the saved surface until a charge is set on it,
then as the EFT surface, for the same reason the table
separated the surfaces at all — a pairing either exists to
compute from or the weapons count as unloaded. Nothing
else in that design changes: formulas, family
classification (cycle attribute 51, multiplier attribute
64), the present-zero and excluded rules, and the
per-family no-total rule are untouched. The saved detail
passes `imported: None` and is byte-identical; an `Eft`
draft is byte-identical whether edited or not; a
`Dna`/`Created`/`Copied` draft with no charges is
byte-identical (value 4), so the shipped demo-DNA pin
(turrets and launchers `None`, three unloaded,
`src/ui/fittings.rs` around the sample-DNA assertions)
passes unmodified. B2 updates the `dps.rs` doc comments
that state the old premise (module header, the
`FittingDps` and `fitting_dps` docs, the weapon-pass
comment) — prose only, no formula comment rewritten.

Consequences by edit, restated so no builder adds a
parallel rule: setting a charge on a weapon-candidate row
(catalogue row with category 7 or 32 and a usable cycle,
`src/fitting/dps.rs:226-231`) moves that row from unloaded
to counted, excluded (no usable charge damage data), or
known-zero (damage sum zero) on the next frame; clearing
moves it back to unloaded; changing swaps the damage sum.
Each can flip `Available`/`Unavailable` at the margins
through the shipped finals (`src/fitting/dps.rs:333-340`);
nothing in this slice special-cases that. A charge on a
non-weapon slot row (a script on a sensor booster, a
booster charge on a capacitor booster) changes no damage
number: the row fails the cycle gate before its charge is
read, counts as neither unloaded nor excluded, and shows
in the Loaded charges list and the charge disclosures —
which is the honest display for pairings DPS does not model.
On a non-EFT draft it does flip the pairing surface itself
on (the locked gate above is any charge present), so the
weapon families and volley render as honest zeroes instead
of absent — the same zeroes a zero-charge EFT draft shows;
no damage is invented either way (pinned by test).
No compatibility predicate is consulted inside DPS:
imported pairings, including incompatible ones, still
compute exactly as recorded (section 4.4); the group
check runs once, at set time, in the editor.

## 6. Downstream consistency (locked, mostly restated)

Every consumer already derives from the draft per frame
through the write-back, `name_resolver()`, and
`to_character_fitting()` (`src/ui/fittings.rs:3542-3581`
at base). Mutating `charge` plus the recount is therefore
the whole integration; this section names each surface so
no builder adds a parallel path.

- **The counter.** `charges_noted` after the recount is
  the count every disclosure below reads, on all four
  provenances — including `Created` and `Copied` drafts,
  which can now hold charges for the first time.
- **Loaded charges block** (`src/ui/fittings.rs:
  3582-3604`): derives `charged_total` from the rows, so a
  set charge appears as `"{module name} - {charge name}"`
  in item order and a cleared one disappears, same frame.
  It renders stored names, not resolver output.
- **The charges note** (`charges_note`, `src/ui/fittings.rs:
  953-962`, rendered at `:3357`): wording unchanged; it
  now also describes editor-set charges truthfully ("is
  listed below the items. It is not included when you copy
  this fitting as EFT."), because set charges list and
  exclude identically.
- **Copy EFT and Copy DNA**: both run on the charge-free
  synthesis and disclose left-out counts from the recounted
  `charges_noted` (`copy_imported_status_message`
  `src/ui/fittings.rs:997-1005`;
  `copy_imported_dna_status_message` `:969-995`; render and
  log sites `:3620-3671`). Wording unchanged. No exporter
  gains a charge spelling (section 12): copying a fitting
  whose charges were all set in the editor drops them all,
  and the statuses count them.
- **Save.** `build_save_request` on the same synthesis has
  no charge to carry (section 2.1); the confirmation's
  `charges_not_sent_line` (`src/ui/fittings.rs:1075-1077`,
  rendered when the count is positive at `:1218-1222`)
  reads the recount. Wording unchanged. Editing while
  armed disarms (section 7.3), so no confirmation can
  confirm one charge count and send with another.
- **Resolver-dependent rendering.** `name_resolver()` is
  built once per panel frame before the item rows render
  (`src/ui/fittings.rs:3542`) — the shipped ordering,
  unchanged. A charge set this frame therefore enters the
  resolver next frame and a cleared charge lingers one
  frame; nothing user-visible reads charge names through
  the resolver in the interim (the Loaded charges block
  uses stored names, exporters exclude charges), exactly
  the staleness the shipped remove path already accepts.
  Builders must not add a mid-frame resolver rebuild.
- **Charge-blind statistics stay blind.** Resources, rig
  calibration, bay usage, capacitor stability, active
  repair, slot layout, and the four ship blocks consume
  `synth` only (`src/ui/fittings.rs:3566-3581`); only
  `render_fitting_dps` also receives the draft. Setting a
  capacitor-booster or paste charge therefore models no
  capacitor gain and no repair change — already true of
  imported such charges, and unchanged.
- **Standing promises kept.** "Removing a module also
  removes its loaded charge" (editor note) still holds via
  `remove_item`; "every loaded charge stay exactly as they
  are" (change-ship note) still holds via `change_ship`'s
  no-recount byte-identity. Sections 4.3 and 8 carry the
  charge sentence the editor note gains.

## 7. Per-row controls, draft state, and edit bookkeeping (locked)

### 7.1 Which rows render charge controls

Charge controls render inside `render_imported_item_rows`
(`src/ui/fittings.rs:1509-1565`), on the imported-draft
rows only; the saved-fitting detail renders no charge
control (saved fittings carry no pairing, section 2.1).
Per rendered row, by the row's own data — its display
section, whether it currently carries a charge, and
whether the catalogue lists charges for its module
(its row's `charge_group_ids` present and non-empty,
read by type number from the panel's catalogue):

| Row | Charge box | `Set charge` | `Clear charge` |
|---|---|---|---|
| Slot row, charge carried | Yes, seeded with charge name | Yes | Yes |
| Slot row, no charge, module lists groups | Yes, seeded empty | Yes | No |
| Slot row, no charge, module lists nothing | No | No | No |
| Stacked row | No | No | No |

The third row is the quantity-control shape: slot rows
render no quantity box because a quantity is impossible
by construction, and a module the data lists nothing for
renders no charge box because every set on it would be
the same refusal. It still renders `Remove`. The first
row always renders both buttons even when the module
lists nothing — an imported pairing on such a module
(section 4.4) must stay clearable, and a set attempt
there refuses `IncompatibleCharge` with the charge kept.
Rows past the shipped `FITTINGS_RENDER_MAX` per-section
render cap gain no controls, exactly as remove and
quantity behave today; the shipped "Showing {shown} of
{total} items." line already discloses that.

To render this, `ImportedItemRow` (`src/ui/fittings.rs:
1410-1418`) must learn each row's stored charge name and
whether its module lists groups, derived in
`imported_item_rows` from the draft (the stored charge)
and the catalogue (by-type-number group proof). Builder B3
threads the catalogue — already in scope in
`fittings_import_panel` — to that derivation; field names
and the factoring are the builder's, the render table
above, order, and strings are locked. Per-frame cost is
one by-number lookup per rendered slot row over
structures rebuilt per frame today; no cache is added.

### 7.2 The row layout and intents

Within a slot row's shipped horizontal, in order: the
item label, then the charge controls (box, then
`Set charge`, then `Clear charge` when present), then
`Remove` last, where it sits today. Stacked rows keep
label, quantity box, `Set quantity`, `Remove` untouched —
the two control families never share a row. The charge
box is a single-line text edit feeding
`state.text_input_focused` exactly as the quantity box
does (`src/ui/fittings.rs:1547-1548`); its width is the
builder's (the quantity box's 90 is code, not a lock).
`Set charge` is enabled only when that row's draft text
is non-empty after trimming — the add button's rule
(`src/ui/fittings.rs:3438-3441`) — so emptying the box
offers `Clear charge`, never an empty set (the
quantity-zero posture: removal has its own control).
`Clear charge` is always enabled when rendered.

`ImportedEditIntent` (`src/ui/fittings.rs:1498-1501`)
gains `SetCharge(usize, String)` and `ClearCharge(usize)`
in the shipped shape; the first intent of a frame wins,
and the apply site (`src/ui/fittings.rs:3546-3562`) gains
the two arms: set runs `editor_set_charge` on the working
clone and routes `Ok` to `note_successful_edit` and `Err`
to `state.fittings_editor_error` through section 8.3's
template; clear runs `editor_clear_charge` and routes
`true` to `note_successful_edit` (`false` does nothing,
mirroring the remove arm). No factored apply helper is
added — remove and set-quantity already apply inline, and
this slice follows them rather than the ship-change
helper, whose outcome branching was heavier. A charge
refusal renders in the one shipped editor-error site
under the add row (`src/ui/fittings.rs:3459-3461`), as a
quantity refusal already does, not beside the row.

### 7.3 Draft state, edited marking, and the disarm

One new view-state field: `fittings_editor_charge:
HashMap<usize, String>` in `AppState` beside
`fittings_editor_quantity` (`src/app/state.rs:849`), the
quantity-draft precedent exactly — drafts keyed by draft
row index, seeded in the row render via entry-or-insert
with the row's current charge name (the stored canonical
name) or the empty string when the row carries none, and
surviving failed sets untouched so the user edits their
text rather than retyping (a refusal changes no state
except `fittings_editor_error`, section 4.2).

`note_successful_edit` (`src/ui/fittings.rs:1595-1600`)
gains one line, clearing the charge drafts alongside the
quantity drafts. That inheritance is load-bearing in both
directions: any successful edit (add, remove, quantity,
rename, ship change, charge set/clear) drops index-keyed
drafts before indices can re-point stale text at a
different module, and a successful set or clear re-seeds
every box from current charges next frame. With that, the
existing helper is the whole bookkeeping for a successful
charge edit: `fittings_import_edited` true (summary gains
` Edited since import.` or ` Edited.` by the shipped
format selection, `src/ui/fittings.rs:1570-1579`), any
editor refusal cleared, both draft maps cleared, and
`fittings_write_confirm` cleared whole — the disarm
matters here for the count, not the spelling: an armed
confirmation re-renders charges from the live draft,
so without disarm a set or clear could quietly change the
charges-not-sent line under an already-read confirmation.
A refused set and a `false` clear touch none of this
(the `SameShip`/`Refused` posture of the ship-change
design's section 5.3).

Clearing follows the existing reset sites for
`fittings_editor_quantity`, field for field (section 9).
Demo behavior: the controls are fully usable in demo over
either sample, with the standing demo write label as the
only restriction, unchanged; no demo-specific wording is
added.

## 8. Verbatim wording (locked)

### 8.1 Controls

- Charge box hint: `Exact charge name, like Republic Fleet EMP S`
- Buttons: `Set charge`, `Clear charge`
- No new heading, no status-bar message on any charge
  outcome (success is the redrawn row, the Loaded charges
  list, the charges note, and the figures; a refusal is
  the editor error), and no confirmation. Control strings
  render literally as the `Set quantity`/`Remove` strings
  beside them do; no control ever shows a type number, a
  group number, or a flag string.

### 8.2 The editor note (all three arms extended)

The following two sentences append verbatim to the end of
each `editor_note` arm (`src/ui/fittings.rs:907-913`,
constant at `:1397`), so the arms keep differing only by
provenance, and the `editor_note` doc comment's claim that
a created draft can never hold a charge is deleted with
the inert-sentence reasoning replaced by this section's:

> Set or clear a module's loaded charge on its item row
> below. A charge can be set only when Mimir's bundled
> data lists it as a kind that module can be loaded with;
> the charge's size is not checked.

Full resulting `FITTINGS_EDITOR_NOTE`, for the test pin:
`Edits change only this imported fitting in Mimir. Nothing is sent to EVE unless you save below. Removing a module also removes its loaded charge. Items can be added only when Mimir's bundled data proves which slot they fit. Set or clear a module's loaded charge on its item row below. A charge can be set only when Mimir's bundled data lists it as a kind that module can be loaded with; the charge's size is not checked.`
The Created and Copied arms are their shipped texts plus
the same two sentences. "Below" is accurate where the note
renders: the item rows and every figure sit below it.

### 8.3 Refusals

One new template beside `add_refusal_message` and
`quantity_refusal_message` (`src/ui/fittings.rs:1581-1590`),
the helper's name the builder's:

`Could not set the charge: {reason}.`

with `{reason}` from `ChargeRefusal::reason()`:

- `UnknownCharge` → `ImportIssueKind::UnknownCharge`:
  "the loaded charge after the comma has no exact match
  in Mimir's bundled data"
- `AmbiguousCharge` → `ImportIssueKind::AmbiguousCharge`:
  "the loaded charge after the comma matches more than
  one item in Mimir's bundled data"
- `NotACharge` → `ImportIssueKind::NotACharge`: "the name
  after the comma is not a charge"
- `IncompatibleCharge` → new fixed sentence: "Mimir's
  bundled data does not list this charge as one this
  module can be loaded with"

The three delegated sentences keep their "after the comma"
phrasing in a surface with no comma. That awkwardness is
accepted and recorded, on the editor design's verbatim
precedent (its section 6.4 reuses the importer's
quantity-suffix sentence in the editor so the two surfaces
never drift): one reason string per condition, shared,
never respelled per surface. Full rendered forms for the
test pins, for example: `Could not set the charge:
Mimir's bundled data does not list this charge as one
this module can be loaded with.` No refusal names the
charge, the module, or any number; refused text is never
echoed.

### 8.4 The DPS disclosure (one sentence replaced)

In `FITTING_DPS_DISCLOSURE` (`src/ui/fittings.rs:2660`),
exactly the sentence beginning "Turret and launcher damage
counts only" through "...no charge is assumed." and the
dependent clause "those same listed charges" in the volley
sentence are replaced; every other sentence keeps its
bytes. The replacement (rendered on both details, so it
must be true of a saved fitting too):

> Turret and launcher damage counts only a loaded charge
> recorded with its module, listed after the module in
> imported EFT text or set on the module's item row in a
> fitting draft, counted exactly as recorded; saved
> fittings record no loaded charges, and no charge is
> assumed. … from those same recorded charges; …

"Exactly as recorded" preserves the DPS design's parity
claim after section 5's widening: pairings are never
compatibility-filtered inside DPS, imported ones included,
and editor-set ones were group-checked as a condition of
being recorded. The unloaded-weapons line ("has no loaded
charge listed, so it is not counted above") keeps its
bytes: it speaks only of weapons with no recording, where
"listed" remains true.

### 8.5 Strings that do not change

Every other existing string keeps its bytes and selection
rule. In particular builders must not touch: the summary
line and its edited suffixes; `charges_note`; both copy
buttons and statuses; the save arm button and every
save-confirmation line including `charges_not_sent_line`;
the change-ship heading and note; the Loaded charges
heading and its `"{module} - {charge}"` rows; every
statistic block's heading, lines, and disclosure except
section 8.4's replacement; and the import panels, fatals,
and issue wordings. Charge editing shows in those surfaces
only through the recounted value they already interpolate.

## 9. State fields and clearing (locked)

One new field beside `fittings_editor_quantity` inside the
editor comment block (`src/app/state.rs:838-853`), under
the same memory-only, never-persisted contract, with the
comment's per-row-drafts sentence extended to name both
maps:

- `fittings_editor_charge: HashMap<usize, String>` — the
  per-row charge name drafts (section 7.3).

No other new state: no pending-selection, no cache of
catalogue proofs (they re-derive per frame, section 7.1),
and no record of a charge the user cleared.

The field clears — to an empty map — at every site that
clears `fittings_editor_quantity` today:

- inside `clear_editor_state` (`src/ui/fittings.rs:
  1654-1674`), beside it, inheriting every panel reset
  (import success and failure, Clear import, both demo
  samples, creation, copy-install), because drafts from a
  dead draft or a previous character must never survive;
- inside `note_successful_edit` (`src/ui/fittings.rs:
  1595-1600`), beside the quantity line (section 7.3);
- at the three `AppState` reset sites that enumerate the
  editor fields field-for-field: character switch (the
  block around `src/app/state.rs:1160`), removal of the
  active character (around `:1377`), and removal leaving
  no characters (around `:1446`), in the shipped
  per-field style at each site.

The isolation fixtures are extended, never replaced: the
`seed_import_state`/`assert_import_cleared` pair in
`src/app/state.rs` tests and the shipped
`clear_editor_state` and `note_successful_edit` panel tests
in `src/ui/fittings.rs` tests seed the new map and assert
it cleared, including the same-character-reselect and
non-active-removal assertions that seeded values survive.

## 10. Logging (locked)

`[FITTING]` tag, the editor's standing rule
(`src/fitting/editor.rs:17-21`): canonical catalogue names
of successful operations may be logged (bundled data);
typed and refused text never; no type or group number ever.
Exactly three new lines, in `src/fitting/editor.rs` at the
other editor lines' `debug` level:

1. On a successful set or change, in `set_charge`:
   `[FITTING] editor charge set name={charge} charges={charges}`
   where `{charge}` is the stored canonical charge name and
   `{charges}` is the recounted `charges_noted`.
2. On any set refusal, in `set_charge`, the `refused`
   helper's shape (`src/fitting/editor.rs:75-78`):
   `[FITTING] editor charge refused kind={kind:?}`
3. On a successful clear, in `clear_charge`, the remove
   line's shape:
   `[FITTING] editor charge cleared charges={charges}`

A `false` clear logs nothing (the out-of-range remove
precedent). Row renders, hovers, box typing, and the DPS
render are silent, as today; the catalogue load line already
reports counts once. Nothing else logs.

## 11. Test plan (locked, real-catalogue pins)

Pins run against `FittingTypes::load_bundled()` unless a
test is labelled synthetic. Scripted figures at base:
200mm AutoCannon II (2889) cycle 3750.0, multiplier 3.465;
Republic Fleet EMP S (21898) damage sum 13.8 → volley
47.817, DPS 12.7512; EMP S (185) sum 12.0 → volley 41.58,
DPS 11.088; Light Missile Launcher I (499) cycle 16000.0
with Scourge Light Missile (210) sum 83.0 → DPS 5.1875.
The demo sample EFT (`DEMO_SAMPLE_EFT`,
`src/ui/fittings.rs:699-718`) parses in item order with
its one charged 200mm AutoCannon II row between the two
uncharged ones; tests locate rows by charge presence or
type rather than asserting a parse-order index literal.

**Regression bar:** the full existing suite (1,091 tests
at base) passes unmodified except the fixture extensions
and the `editor_note` and DPS-disclosure literals (tests
15 and 16). A draft no charge edit ever
touches renders byte-for-byte as today, saved surface
included.

**Builder A (generator and loader):**

1. Generator: section 3.2's oracle list and expected
   counts as self-validation (a cache that disagrees
   fails with nothing written); the twice-run,
   strip-two-keys, and exact-byte-count proofs in the A1
   commit body, landing at or below 3,815,000 bytes.
2. Loader: section 3.3's invariants inside
   `bundled_catalogue_invariants` and spot pins identical
   to the oracles; an old-shape JSON without the two keys
   loads with both fields `None` (extending the existing
   fixture-loading tests, labelled synthetic).

**Builder B1 (pure tests in `src/fitting/editor.rs`):**

3. Set on a chargeless row: on the demo-sample draft, set
   "EMP S" on an uncharged 200mm AutoCannon II row — the
   row stores type 185 with canonical name "EMP S",
   `charges_noted` recounts 1 → 2, and name, format,
   item order and quantities, `imported_lines`,
   `placeholder_lines`, and `issues` equal a pre-edit
   clone field for field.
4. Change and re-set: change the charged row Republic
   Fleet EMP S → EMP S (recount stays 1); set "EMP S" on
   it again (success, identical stored pair, recount
   still 1 — the no-same-outcome lock of section 4.2);
   set by a differently cased, extra-spaced spelling of
   the same name (lookup normalization stores the
   canonical name).
5. Clear: clearing the charged row stores `None` and
   recounts to 0; clearing it again returns `false`;
   clearing a stacked row and an out-of-range index
   return `false`, each with the draft unchanged.
6. Every refusal changes nothing (whole-draft equality
   against a clone, report counters included):
   `UnknownCharge` on "No Such Charge" and on "  ";
   `NotACharge` on "Tritanium" and on the module name
   "Damage Control II" set as a charge;
   `IncompatibleCharge` on "Scourge Light Missile" and on
   "Radio S" against a 200mm AutoCannon II row, on "EMP S"
   against the Damage Control II row (lists nothing), on
   any name against the stacked Hobgoblin II row and an
   out-of-range index — including an unknown name on the
   stacked row, pinning row-eligibility-first ordering —
   and on "Standup Light Missile" against a Light Missile
   Launcher I row (a structure-only charge, section 2.3).
   On a synthetic `FittingTypes::from_json` fixture
   (labelled synthetic): `AmbiguousCharge` on a duplicated
   category-8 name; `IncompatibleCharge` when the charge
   row carries no `chargeGroupId` key and when the draft
   row's type number has no catalogue row (old-asset and
   hostile-draft defense).
7. Families beyond turrets: an EFT-built "[Rifter, T]"
   draft with Light Missile Launcher I set by exact name
   "Scourge Light Missile" succeeds, then changing to
   "Scourge Torpedo" refuses `IncompatibleCharge` with the
   light missile still stored; a Sensor Booster II row
   added through `add_item` accepts "Targeting Range
   Script" and refuses "EMP S"; a Small Capacitor Booster
   II row accepts "Cap Booster 400".
8. The locked non-check: a Gatling Pulse Laser I row
   accepts "Radio M" (group matches; size differs and is
   not consulted, section 2.3). This pin exists so the
   size deferral cannot be silently "fixed" without a
   design.
9. Exhaustive composition: for every bundled row with
   `charge_group_ids` present (980), a hand-built
   one-item draft of that module accepts the first
   catalogue charge (file order) whose `charge_group_id`
   is listed, storing that charge's pair — the
   generator→loader→editor join proven at every carrier,
   not sampled (the 404-ship discipline).
10. Copy round trip: after setting an editor charge on
    the demo draft, `fitting_to_eft` output re-imports
    through `parse_import` with zero issues, the same item
    count, and `charges_noted` 0 — copy still excludes
    charges, now including editor-set ones.

**Builder B2 (pure DPS tests in `src/fitting/dps.rs` or
the shipped `src/ui/fittings.rs` harnesses they extend):**

11. Created surface: `new_fitting` Rifter plus one added
    200mm AutoCannon II computes turrets `None` before
    any set (the untouched-surface regression pin) and,
    after setting Republic Fleet EMP S, turrets
    `Some(12.7512)`, launchers `Some(0.0)`, volley
    `Some(47.817)`, optimal 1200.0, falloff 5160.0,
    unloaded 0; clearing that only charge returns the
    families to `None` (surface-from-rows pin).
12. DNA demo: the shipped sample-DNA assertions pass
    unmodified; setting Republic Fleet EMP S on one of
    its three 200mm AutoCannon II rows yields the demo-EFT
    numbers of test 11 with unloaded 2, including through
    `dps_lines` (`"Turret DPS: 12.8 DPS"` and
    `"Volley: 47.8 damage"` as formatted today).
13. EFT demo transitions: clearing its charged row yields
    turrets `Some(0.0)`, volley `Some(0.0)`, unloaded 3;
    changing Republic Fleet EMP S to EMP S yields DPS
    11.088 and volley 41.58; a launcher draft from test 7
    computes launcher DPS 5.1875.
14. Non-weapon charge: an EFT draft carrying a Sensor
    Booster II with a set script (test 7's draft) has the
    same `FittingDps` as before the set — unloaded and
    excluded counts unchanged.

**Builder B3 (tests in `src/ui/fittings.rs` and
`src/app/state.rs`):**

15. Resets: section 9's fixtures seed and assert
    `fittings_editor_charge` across switch, removals,
    reselect-keeps, and non-active-removal-keeps, plus
    `clear_editor_state` and `note_successful_edit`
    clearing it beside the quantity drafts.
16. Wording literals: the hint, both buttons' strings as
    rendered (through the constants/literals the render
    uses); all four full `Could not set the charge: ….`
    forms — the three delegated ones asserted string-equal
    to the `ImportIssueKind::reason()` delegation, the
    incompatible one to its section 8.3 literal, none
    containing a type or group number; the three full
    `editor_note` literals of section 8.2 (the modified
    base assertions); the full replaced
    `FITTING_DPS_DISCLOSURE` literal (the modified base
    assertion).
17. Row derivation: over `imported_item_rows` on the demo
    draft, the three autocannon rows offer charge
    controls (the charged one seeded
    `"Republic Fleet EMP S"` with a clear), the Damage
    Control II, armor repairer, afterburner, scrambler,
    and rig rows offer none, and no stacked row offers
    any; over an EFT draft parsed from
    `"Damage Control II, EMP S"`, that row offers controls
    seeded `"EMP S"` with a clear (the imported-pairing
    row of section 7.1).
18. Demo pins: both decode samples and the demo DPS line
    arrays pass unmodified; the demo draft's charge can
    be cleared and re-set through the pure operations
    with `charges_note(1)`, both copy status messages at
    count 1, and `charges_not_sent_line(1)` keeping their
    shipped literals on the round trip (count moves,
    words do not).

(Each numbered literal above exists exactly once. Tests
11, 13, and 14 call `fitting_dps` directly and live in
`src/fitting/dps.rs`; test 12 additionally asserts
through `dps_lines` and extends the shipped demo-DPS
harness in `src/ui/fittings.rs` tests, which B2 owns as
test-only lines in that file.)

## 12. Deferred (named, not built)

- **The charge-size check** (attribute 128): deferred for
  the contradiction in section 2.3 — present 0.0 module
  sizes on 32774, 41480, and 88717, size-less group-87
  charges beside sized ones for the same carriers, and no
  body in the repository stating a reconciling rule.
  Nothing is missing from the committed tables; the
  missing piece is the rule itself. A future design needs
  per-carrier-family evidence (the turret partition is its
  starting point), emission, and a wording that describes
  exactly where size is enforced. Until then the note's
  "the charge's size is not checked" stays.
- **Import-time compatibility.** EFT and DNA import record
  pairings unchecked by design (section 4.4); refusing or
  stripping imported charges is a change to the import
  grammar and its issue and invariant accounting, owned
  by no part of this slice.
- **Exporting charges in copied EFT text.** EFT text could
  spell a pairing, but the shipped exporters run on the
  charge-free synthesis with four disclosures built on
  exclusion; carrying editor-set charges into a clipboard
  format is its own design, and DNA/ESI cannot hold them
  at all.
- **A charge picker or browser tab.** Exact names only,
  the editor's standing grammar; a browse surface over the
  1,005 charges (or the compatible subset per row) needs
  its own candidate design. The importer's exact-name,
  never-guess contract stands.
- **How many charges are loaded.** The model stores a
  charge kind per row, never a count; import's grammar has
  no count either, and capacity-by-volume is unmodelled.
  Nothing in this slice shows or asks a quantity.
- **Charge effects on capacitor and repair figures.**
  Booster charges and paste are settable display pairings
  here; the capacitor-stability and sustained-tank designs
  already defer consuming them, for imported and editor-set
  charges alike.
- **Bulk operations** (set the same charge on every
  matching row), module state, drag and drop, and
  everything the editor already defers stay deferred.

## 13. Code structure and builder split (locked)

Small atomic commits, `type(scope): description`, no
attribution, nobody pushes. Every commit compiles and
passes the section 14 gate on its own. Sequencing: A1,
then A2 (its invariants need the regenerated asset; A1
alone is safe because old code ignores the new keys);
B1 needs A2's loader fields; B2 needs B1's operations;
B3 needs B1 and B2; integrator last. There is no safe
parallelism on the code path (B1 and B2 touch adjacent
pure files through one test surface), and none is needed.

- **Design** (this commit): `docs/charge-editing-design.md`
  only. Subject: `docs(fitting): design charge editing`.
- **Builder A — catalogue.** (A1)
  `scripts/sde/generate_fitting_types_sde.py` + the
  regenerated `assets/sde/fitting_types.json`: the header
  paragraph, the attribute load, the emission block, the
  oracles and expected counts, the fail-loud invariants,
  and the summary line of section 3. Subject:
  `feat(sde): emit charge groups for modules and charges`.
  (A2) `src/names/fitting_types.rs`: the two loader
  fields and section 3.3's invariants and spot pins.
  Subject: `feat(catalogue): load charge groups`.
  Builder A changes no `src/fitting/` or `src/ui/` files.
- **Builder B1 — pure charge editing.**
  `src/fitting/editor.rs` (the `ChargeRefusal` type,
  `set_charge`, `clear_charge`, the three log lines, the
  module-doc update, tests 3–10) plus the visibility-only
  `CATEGORY_CHARGE` line in `src/fitting/eft.rs`. No
  `src/fitting/mod.rs` change (section 4.1), no UI change:
  the tree compiles at the B1 boundary with the panel not
  yet calling anything new. Subject:
  `feat(fitting): add pure charge editing for fitting drafts`.
- **Builder B2 — DPS pairing surface.** `src/fitting/dps.rs`
  (the section 5 gate redefinition, its doc-comment
  updates, tests 11, 13, and 14) plus test-only lines in
  `src/ui/fittings.rs` for test 12's `dps_lines` assertions.
  No formula, classification, or shipped-string change;
  until B3 no panel control can create a charge, so the
  disclosure text is never wrong on a shipped interaction
  path. Subject:
  `feat(fitting): count charges set on a draft in its DPS`.
- **Builder B3 — panel and state.** `src/app/state.rs`
  (the section 9 field and its three reset sites) and
  `src/ui/fittings.rs` (row derivation and controls, the
  two intent arms, the refusal template, the editor-note
  and DPS-disclosure replacements, the `note_successful_edit`
  line, the `clear_editor_state` line, imports, and tests
  15–18). Builder B3 changes no pure-layer rule, no
  importer, and no catalogue file. Subject:
  `feat(fitting): edit loaded charges in the panel`.
- **Integrator.** Merges A1, A2, B1, B2, B3 in order; runs
  the full gate on the merged tip; pins the regenerated
  catalogue's exact byte count and sha256 in the merge
  report; and lands user-facing documentation and the
  engineering-journal entry the mechanism requires (the
  group-only compatibility decision and its size-deferral
  evidence) as one commit. Subject:
  `docs(fitting): document editing loaded charges`. The
  integrator changes no behavior: any gate failure goes
  back to the owning builder.

## 14. Verification gate (locked)

On the design commit, on every builder commit, and again
on the final merged tree, all four, in order, with output
read — not skimmed for exit codes alone:

1. `cargo fmt --check`
2. `cargo clippy --all-targets -- -D warnings`
3. `cargo test` — the 1,091 base tests plus this slice's
   additions, zero failures, and no base test modified
   beyond the fixture extensions and the two wording
   literals named in section 11's regression bar.
4. `cargo build`

Plus, on A1 only, the generator proofs of section 3.2
(twice-run determinism, strip-two-keys byte identity
against the header's base sha256, exact byte count within
budget), reported in that commit's body. This design
commit itself was verified the same way on the base tree
(a documentation-only change must still leave all four
green).








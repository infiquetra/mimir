# Bay capacities and bay usage — design

Status: locked for implementation. Base: `develop` at `88e031d`. Slice branch:
`feat/rust-bay-capacities`. Discovery: two read-only reports (Flutter bay math at
`ed698d3`; catalogue/cache data audit), re-verified against the bodies named
below during design. Every number in this document traces to an inspected body:
`dogmaAttributes.jsonl` / `dogmaUnits.jsonl` in the pinned SDE zip
(`scripts/sde/eve-online-static-data-3503375-jsonl.zip`), the committed Fuzzwork
caches `scripts/sde/invTypes.csv.bz2` and `scripts/sde/dgmTypeAttributes.csv.bz2`
read directly, the committed catalogue `assets/sde/fitting_types.json`, Flutter
at `ed698d3` via `git show`, and current Rust (`src/fitting/resources.rs`,
`src/fitting/ship_stats.rs`, `src/fitting/eft.rs`, `src/fitting/write_map.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`scripts/sde/generate_fitting_types_sde.py`, `assets/demo/fittings.json`).

## 1. Goal and value ranking

Goal: in both fitting details (saved fitting detail and imported fitting
detail), show bay usage at base values from catalogue data, as four
used-versus-capacity dimensions:

- cargo bay volume used versus ship cargo capacity;
- drone bay volume used versus ship drone capacity;
- drone bandwidth used versus ship drone bandwidth;
- fighter bay volume used versus ship fighter capacity (in scope — see
  section 2.4 for the grounding that satisfies the slice brief's condition).

Value ranking, in order, when any two rules below appear to conflict:

1. **Never show a used/capacity pair from mixed sources without its sources
   being the locked ones for that pair.** Each capacity and each per-item cost
   has exactly one authoritative source, locked in section 2. A number read
   from any other source (dogma attribute 38 rows, dogma attribute 161 rows,
   Flutter's synthesized attribute-38 key, `capacitySecondary` 1233, multiplier
   or bonus attributes) must never reach a bay line, even when it looks
   plausible.
2. **Correctness.** Plain sums over the fitting's items, quantity semantics
   and unknown-counting exactly as locked; unknown data is counted and
   disclosed, never silently zeroed.
3. **Reuse.** Mirror the existing pure-layer, generator, and rendering shapes
   (`resources.rs`, the additive catalogue extensions of the resource /
   base-stat / resonance slices, `resource_line` wording) wherever they fit
   without violating 1 or 2. Where reuse would misname a value (for example
   reusing `ResourceBudget.output` for a capacity), correctness wins and a
   small parallel type is used (section 4).

## 2. Sources and grounding (inspected bodies only)

### 2.1 Dogma attribute and unit truth

From `dogmaAttributes.jsonl` / `dogmaUnits.jsonl` in the pinned zip, `_key` is
the id:

| Id | Dogma name | Display name (en) | Unit id | Role in this slice |
|---|---|---|---|---|
| 38 | `capacity` | Capacity | 9 | Named only. **Never read** (section 2.2). |
| 161 | `volume` | Volume | 9 | Named only. **Never read** (section 2.2). |
| 283 | `droneCapacity` | Drone Capacity | 9 | Ship drone bay capacity. |
| 1271 | `droneBandwidth` | Drone Bandwidth | 128 | Ship drone bandwidth. |
| 1272 | `droneBandwidthUsed` | Bandwidth Needed | 128 | Per-drone bandwidth cost. |
| 2055 | `fighterCapacity` | Fighter Hangar Capacity | 9 | Ship fighter bay capacity. |

Units from `dogmaUnits.jsonl`, display names verbatim: unit 9 is `m3`
(description "Cubic meter"); unit 128 is `Mbit/sec` (description "Mega bits
per second"). These two display strings are the only units the bay block
renders. Flutter rendered `MBit` (`stats_panel.dart` at `ed698d3`); this slice
uses the dogmaUnits display name `Mbit/sec`, not the Flutter string.

A fighter-name search over `dogmaAttributes.jsonl` finds exactly one
bay-capacity candidate, 2055; the rest of the fighter family (2216 tubes,
2217–2219 slots, 2215 squadron size, ability attributes) is not capacity data
and stays out.

Specialized-hold and capacity-modifier attributes exist in dogma and are
excluded by name in section 10 (908, 912, 1549–1564, 1573, 1646, 1653, 1770,
1804, 2467, 2657, 2675, 1233 `capacitySecondary`, 149
`cargoCapacityMultiplier`, 614 `cargoCapacityBonus`, 2689 `cargoCapacityAdd`,
499 `droneCapacityBonus`). None of them is a base capacity for the four bays
here.

### 2.2 The authoritative source per value — the "38" collision

Three different things share nearby numbers; confusing them is the one real
correctness trap in this slice.

- **Ship cargo capacity = the `capacity` column of `invTypes`, and only that
  column.** `dgmTypeAttributes.csv.bz2` contains **zero** rows with attribute
  id 38 anywhere, so dogma carries no ship cargo capacity at all. Every one of
  the 404 category-6 (ship) catalogue rows has an `invTypes.capacity` value:
  401 nonzero and 3 present-zero (`"0E-10"`: 670 Capsule, 33328 Capsule -
  Genolution 'Auroral' 197-variant, 45534 Monitor). There is no ship with both
  sources to reconcile; `invTypes.capacity` is the sole authority. Values read
  directly: 587 Rifter `140.0`, 597 Punisher `135.0`, 593 Tristan `140.0`,
  638 Raven `830.0`, 2863 Primae `100.0`, 45649 Komodo `13750.0`.
- **Per-type volume = the `volume` column of `invTypes`, and only that
  column.** Dogma attribute 161 `volume` is a decoy: `dgmTypeAttributes` has
  only 6 rows for it (structure/container types), none in the catalogue.
  Flutter at `ed698d3` stored `invTypes.volume` under a **synthesized** dogma
  key 38 (`dogma_attributes.dart:47`, generator comment "drone bay usage needs
  it as attribute 38"); that 38 is item volume, not dogma 38 `capacity`, and
  must never be read as either. Rust reads `invTypes.volume` directly and
  stores it under its own catalogue key (section 3).
- **Ship drone capacity (283), ship drone bandwidth (1271), ship fighter
  capacity (2055), and per-drone bandwidth cost (1272) are genuine dogma
  rows** in `dgmTypeAttributes`, read the same way the generator already reads
  resource / base-stat / resonance rows (`valueFloat`, fail-loud on
  unparseable, non-finite, or negative values).

Coverage over the 404 published category-6 catalogue ships (scripted join of
the caches against `assets/sde/fitting_types.json`, 25,818 rows):

- 283 and 1271: present on 403 of 404 ships (175 explicit `0.0`, 228 nonzero).
  The one absent ship is 2863 Primae (no 283 row, no 1271 row; cargo capacity
  `100.0` present). Largest: 28352 Rorqual 283 = `8800.0`, 1271 = `125.0`.
- 2055: present on exactly 12 ships, all nonzero (3514 Revenant `100000.0`,
  22852 Hel `110000.0`, 23757 Archon `60000.0`, 23911 Thanatos `70000.0`,
  23913 Nyx `110000.0`, 23915 Chimera `55000.0`, 23917 Wyvern `110000.0`,
  23919 Aeon `110000.0`, 24483 Nidhoggur `65000.0`, 42125 Vendetta `110000.0`,
  45647 Caiman `40000.0`, 45649 Komodo `45000.0`). All 12 also carry
  283 = `0.0` and 1271 = `0.0`: the fighter bay is a separate hangar, computed
  independently, never summed with the drone bay. (Flutter's `ed698d3`
  `dogma.json` shows Thanatos 2055 = 75000; the current cache reads `70000.0`.
  The cache is the authority for this slice; the difference is SDE drift, not
  a conflict to reconcile.)
- 1272: present on 125 of the 129 category-18 (drone) catalogue types
  (values: 5.0 ×40, 10.0 ×34, 20.0 ×1, 25.0 ×46, 50.0 ×4). The 4 absent types
  are the mutated drones 60478 Light (volume `5.0`), 60479 Medium (`10.0`),
  60480 Heavy (`25.0`), 60481 Sentry (`25.0`) — a genuine unknown-bandwidth
  case that must be counted and disclosed (section 4), never zeroed the way
  Flutter's `?? 0.0` did.
- Volume: every catalogue row resolves in `invTypes` (0 missing). 931 rows
  have volume `0.0` (mostly non-fitting categories; every plausible fitting
  category is nonzero: category 8 charges 1005/1005, category 18 drones
  129/129, category 87 fighters 94/94). A present `0.0` volume is real data
  ("takes no bay space"), distinct from an absent row. Fractional volumes are
  normal (34 Tritanium `0.01`, 185 EMP S `0.0025`), so volume is `f64`
  everywhere and is never integer-truncated. Fighters carry no 1272 rows at
  all: bandwidth is drones-only. Fighter volumes run 800.0–6000.0 (40556
  Templar II `1000.0`, 23059 Firbolg I `1000.0`).

Consequence for invariants: "every ship carries every bay key" is false and
must never be asserted. Absent is distinct from present `0.0` throughout,
following the existing generator/loader precedent (a present `0.0` row is
emitted; a missing row emits no key).

### 2.3 Which fitting sections count toward which bay

The pure layer counts by the same section rule the user already sees in the
grouped item list, `section_for_flag` in `src/ui/fittings.rs`:

- flag exactly `DroneBay` → drone bay (volume) and drone bandwidth;
- flag exactly `FighterBay` → fighter bay (volume);
- any other flag that is not a slot flag → cargo bay. This is the UI catch-all
  that files `Cargo`, `Invalid`, `ServiceSlot0`, `""`, and any unknown flag
  under "Cargo and other items";
- slot flags (`LoSlot*`, `MedSlot*`, `HiSlot*`, `RigSlot*`,
  `SubSystemSlot*` prefixes) count toward no bay.

Counting by exact `Cargo` only was rejected: the bay numbers would then
disagree with the printed "Cargo and other items" list for any catch-all row
(the demo fixture's `Invalid` row, section 7, makes that disagreement
visible). The cost of the mirrored rule, stated plainly: a row under a
`ServiceSlot*` flag (filed under cargo by the UI) counts its volume as cargo.
That matches what the user sees grouped as cargo, and saved EVE fittings and
synthesized imports do not produce such rows in practice. Following the
`resources.rs` independence precedent, the pure module tests flag strings
itself and does not depend on the UI enum; a test pins the two predicates
equivalent over the locked flag set (section 8).

Category is never consulted: a charge-type row under `Cargo` counts as cargo,
a blueprint under `FighterBay` counts as fighter-bay volume when the bay has
capacity data. Belonging is judged by flag, exactly as `resources.rs` judges
slot consumption by flag prefix.

### 2.4 Fighter bay is in scope

The brief's condition ("include only if discovery grounds a capacity
attribute and used-volume semantics in inspected bodies") is met on both
halves: attribute 2055 `fighterCapacity`, unit 9, present nonzero on 12
catalogue ships (section 2.2); and used = Σ quantity × `invTypes.volume` over
`FighterBay` rows, the same semantics Flutter's engine used
(`dogma_engine.dart` at `ed698d3`, gated on the hull carrying 2055) and the
same volume column this slice already ships for every type. Fighter tubes,
squadron slots, and fighter damage stay out (section 10).

### 2.5 Deliberate divergences from Flutter (do not "fix" back)

1. **Base capacities only.** Flutter showed effective capacities (skills and
   modules applied). This slice shows base values; the block disclosure names
   the excluded bonuses (section 6).
2. **Bandwidth is a plain fitted sum**, Σ quantity × 1272 over all `DroneBay`
   rows. Flutter computed an active-only sum capped at the ship's bandwidth
   (using its `inSpace` field), which can never show over-bandwidth. Rust
   `CharacterFitting` has no in-space field, and the brief mandates plain
   sums, so over-bandwidth is a real, displayable state here.
3. **Unknown data is counted and disclosed**, not silently skipped or zeroed
   (Flutter skipped unknown types and used `?? 0.0` for unknown volume and
   bandwidth).
4. **Over-capacity is styled on every bay line** (Flutter styled only the
   fighter bay line; the drone lines had no over-capacity colour).
5. **Cargo bay usage is new.** Flutter never computed or displayed it (no
   cargo fields in `FittingStats`, no cargo math in the engine, no cargo
   readout in the editor). There is no Flutter precedent to copy or
   contradict.
6. **Present-zero bays render.** Flutter hid its drone section unless
   capacity or used was positive. This slice follows the sibling Rust blocks:
   a present `0.0` capacity renders a real line (section 5).

### 2.6 Quantity semantics by source (one math path)

All sources land in `CharacterFitting.items` (`flag`, `quantity`, `type_id`),
and the pure function reads only that shape, so saved, imported, and demo
fittings share one math path with no per-source branching:

- Saved (ESI/demo) rows carry raw flags and stacked quantities
  (`assets/demo/fittings.json`: `DroneBay` ×5, `Cargo` ×500).
- EFT synthesis (`ImportedFitting::to_character_fitting` in
  `src/fitting/eft.rs`) merges duplicate stacks by type into one row with a
  summed quantity capped at `MAX_STACK_QUANTITY` (2,147,483,647), maps
  sections to exactly `DroneBay` / `FighterBay` / `Cargo`, and excludes loaded
  charges entirely (display-only, disclosed by the import report). Loaded
  charges therefore never count toward any bay.
- DNA import accepts only modules/subsystems, so a synthesized DNA fitting
  structurally has empty bays; "0.0 used" is correct data, not missing data.
- `write_map.rs` preserves `DroneBay` / `FighterBay` / `Cargo` rows with
  quantity when saving; this slice changes nothing there.

## 3. Catalogue extension

Generator-driven and additive, in `scripts/sde/generate_fitting_types_sde.py`,
cloning the resource / base-stat / resonance emission patterns (sorted by
`typeId`, compact separators, fail-loud with exit 1 and nothing written on
duplicate, unparseable, non-finite, or negative values).

### 3.1 New keys and emission rules

Key order within a row is locked: existing keys keep their existing order;
new keys are appended after them in the order below.

| Catalogue key | Rust field (`FittingType`) | Source | Emitted on |
|---|---|---|---|
| `volume` | `volume: Option<f64>` | `invTypes.volume` | **Every row** (see 3.2). |
| `cargoCapacity` | `cargo_capacity: Option<f64>` | `invTypes.capacity` | Category 6 only. |
| `droneCapacity` | `drone_capacity: Option<f64>` | dgm 283 | Category 6, sparse (only when a row exists). |
| `droneBandwidth` | `drone_bandwidth: Option<f64>` | dgm 1271 | Category 6, sparse. |
| `fighterCapacity` | `fighter_capacity: Option<f64>` | dgm 2055 | Category 6, sparse. |
| `droneBandwidthUsed` | `drone_bandwidth_used: Option<f64>` | dgm 1272 | Sparse wherever a 1272 row exists (all such rows are category 18; the loader invariant asserts that). |

Rules:

- `invTypes.volume` and `invTypes.capacity` are parsed as floats with the
  same fail-loud validation as dogma values. The string `"0E-10"` parses to a
  present `0.0` and is emitted as `0.0`, never omitted. An unparseable,
  non-finite, or negative volume/capacity on any emitted row fails the
  generation. (The generator currently drops both columns; this is the first
  slice to read them.)
- `cargoCapacity` is read from the `invTypes` row the generator already
  iterates, and is emitted on every category-6 row, because the column is
  present on every ship (section 2.2). Non-ship rows never carry it, even
  though `invTypes.capacity` exists for all types: cargo capacity is a ship
  value here, and emitting it on 25,818 rows would pay size for data no
  reader uses.
- `droneCapacity` / `droneBandwidth` / `fighterCapacity` /
  `droneBandwidthUsed` come from `dgmTypeAttributes` via the existing
  per-attribute parse loop shape (new attribute-id constants and per-type
  maps alongside `RESOURCE_ATTR_IDS` / `base_stats_by_type`), sparse: a key
  is present exactly when a source row exists, including present `0.0`
  (587 Rifter carries 283 = `0.0` and 1271 = `0.0` and must emit both keys as
  `0.0`; 2863 Primae emits neither).
- Key counts are tallied and reported in the generator summary like the
  existing resource/base-stat/resonance counts.

### 3.2 Volume goes on every row — the size decision, costed

Cargo can be any inventory type: the generator's locked row rule is "All
categories are kept (cargo can be any inventory type)", and EFT import maps
any unsectioned category to cargo. A subset rule (for example categories
7+8+18+87) would silently undercount cargo for every out-of-subset type
(materials, commodities, blueprints — the demo cargo rows are category 4)
and no body grounds any cargo-subset definition. Volume therefore goes on
**all 25,818 rows**.

Simulated delta (measured against the committed catalogue with the
generator's compact separators): the catalogue is 2,762,636 bytes today;
adding `,"volume":<number>` to every row adds ~356,560 bytes, for ~3,119,196
bytes (+12.9%). The ship capacity keys and `droneBandwidthUsed` add well
under 10 KB more on top (404 ship rows, 125 drone rows). Because
`FittingTypes::load_bundled` uses `include_str!`, the binary grows by the
same amount; there is no network cost (offline-first). **Size budget: the
regenerated catalogue must land within 3,200,000 bytes**; Builder A reports
the actual byte count in the commit. If regeneration exceeds the budget, that
is a stop-and-report event, not a reason to quietly subset.

This is the first extension that touches every row, so the usual "every
other row byte-identical" gate changes shape (section 8): stripping exactly
the six new keys from the regenerated file must reproduce the committed
pre-slice file byte for byte.

### 3.3 Generator oracles

A new `BAY_ORACLES` list in the `RESOURCE_ORACLES` shape —
`(typeId, key, expected)` — plus absence oracles `(typeId, key)` that fail if
the key is emitted. Every value below was read directly from
`invTypes.csv.bz2` / `dgmTypeAttributes.csv.bz2` during design:

Present-value oracles:

- (587, `cargoCapacity`, 140.0), (587, `droneCapacity`, 0.0),
  (587, `droneBandwidth`, 0.0), (587, `volume`, 27289.0)
- (593, `cargoCapacity`, 140.0), (593, `droneCapacity`, 40.0),
  (593, `droneBandwidth`, 25.0)
- (638, `cargoCapacity`, 830.0), (638, `droneCapacity`, 75.0),
  (638, `droneBandwidth`, 50.0)
- (670, `cargoCapacity`, 0.0) — present zero from `"0E-10"`, never absent
- (2863, `cargoCapacity`, 100.0)
- (23911, `fighterCapacity`, 70000.0), (23911, `cargoCapacity`, 875.0),
  (23911, `droneCapacity`, 0.0)
- (45647, `fighterCapacity`, 40000.0), (45647, `cargoCapacity`, 2750.0)
- (2456, `volume`, 5.0), (2456, `droneBandwidthUsed`, 5.0)
- (2488, `volume`, 5.0), (2488, `droneBandwidthUsed`, 5.0)
- (34, `volume`, 0.01), (185, `volume`, 0.0025), (28668, `volume`, 0.01)
- (40556, `volume`, 1000.0), (23059, `volume`, 1000.0)
- (60478, `volume`, 5.0)

Absence oracles:

- (587, `fighterCapacity`), (593, `fighterCapacity`)
- (2863, `droneCapacity`), (2863, `droneBandwidth`),
  (2863, `fighterCapacity`)
- (60478, `droneBandwidthUsed`), (60479, `droneBandwidthUsed`),
  (60480, `droneBandwidthUsed`), (60481, `droneBandwidthUsed`)
- (2456, `cargoCapacity`), (34, `cargoCapacity`), (34, `droneBandwidthUsed`),
  (587, `droneBandwidthUsed`)

### 3.4 Invariants (generator self-validation and loader test)

Generator self-validation and the loader's `bundled_catalogue_invariants`
test in `src/names/fitting_types.rs` both assert, for the shipped catalogue:

- every present bay value is finite and ≥ 0.0;
- `volume` is present on every row;
- `cargoCapacity` is present on every category-6 row and on no other row;
- `droneCapacity` / `droneBandwidth` / `fighterCapacity` appear only on
  category-6 rows (absence is allowed — never require them);
- `droneBandwidthUsed` appears only on category-18 rows;
- absence stays distinct from `0.0` (the 670 and 587 oracles pin this).

Loader: the six new `FittingType` fields are `Option<f64>` with
`#[serde(default)]`, placed after the existing fields, mirroring
`cpu_output` and friends. Old fixture JSON in existing tests (which lacks the
new keys) must keep parsing. The load log line
(`[FITTING] fitting types loaded types=… skipped=…`) is unchanged; no new
logging is added at load.

### 3.5 Determinism proofs (Builder A, same commit as the catalogue)

1. Run the generator twice into two outputs; SHA-256 hashes are identical.
2. Strip exactly the six new keys from the regenerated catalogue; the result
   is byte-identical to the committed pre-slice `fitting_types.json` (this
   proves every pre-existing key, value, row, and ordering is untouched).
3. Generator self-validation (oracles + invariants) passes, and the summary
   key counts match the audited expectations: `volume` 25,818;
   `cargoCapacity` 404; `droneCapacity` 403; `droneBandwidth` 403;
   `fighterCapacity` 12; `droneBandwidthUsed` 125. A count mismatch is a
   stop-and-report event.

## 4. Pure API

New module `src/fitting/bay_usage.rs`, exported from `src/fitting/mod.rs`,
following the `resources.rs` shape: pure computation over
`&CharacterFitting` + `&FittingTypes`, no egui, no state, no network, no
database, and **no logging** (render cadence; the catalogue load already logs
counts once).

```rust
pub fn bay_usage(fitting: &CharacterFitting, catalogue: &FittingTypes) -> BayUsageOutcome;

pub enum BayUsageOutcome {
    Available(BayUsage),
    Unavailable, // no usable ship row, or no bay has capacity data
}

pub struct BayUsage {
    pub cargo: Option<BayBudget>,
    pub drone: Option<BayBudget>,
    pub drone_bandwidth: Option<BayBudget>,
    pub fighter: Option<BayBudget>,
}

pub struct BayBudget {
    pub used: f64,
    pub capacity: f64,
    pub excluded_items: usize,
}
impl BayBudget {
    pub fn remaining(&self) -> f64; // capacity - used
    pub fn is_over(&self) -> bool;  // used > capacity
}
```

`BayBudget` is its own type rather than a reuse of `ResourceBudget`: the
field names `output` / `excluded_modules` would misname a capacity and
non-module items (value ranking 2 over 3). The method surface
(`remaining`, `is_over`) mirrors `ResourceBudget` exactly.

Semantics, locked:

- Ship resolution mirrors `resources.rs` / `ship_stats.rs`: `ship_type_id`
  must be > 0, resolve in the catalogue, and be category 6, else
  `Unavailable`.
- Each bay's capacity is `usable(ship.<field>)` with the shared rule —
  present, finite, ≥ 0.0; present `0.0` is a real zero. A bay whose capacity
  is unusable/absent is `None` in `BayUsage`; the other bays are unaffected.
  If all four are `None`, the outcome is `Unavailable`.
- Item pass, per item: `type_id <= 0` rows are ignored entirely (neither
  counted nor excluded), `quantity` is clamped with `.max(0)`, quantity 0
  contributes and excludes nothing — `resources.rs` verbatim. Section
  assignment follows section 2.3. Slot-section rows are skipped.
- For a counted row, the cost value is `usable(row.volume)` (cargo, drone,
  fighter bays) or `usable(row.drone_bandwidth_used)` (bandwidth). Present
  and usable: `used += quantity as f64 * value`. Absent type, absent field,
  or unusable value: `excluded_items` increases by the clamped quantity in
  **units** (a stacked row of 5 unknown items reports 5), with saturating
  addition — the `resources.rs` excluded-counting precedent. A present
  volume of `0.0` counts (adds 0.0, excludes nothing).
- A `None` bay still has its items *pass over* without accumulating anything:
  no used, no excluded counts. Excluded counts exist only alongside a real
  capacity, because the disclosure sentence reads "does not count N items"
  against a shown total. (Example: the demo's `FighterBay` blueprint row on a
  Rifter, which has no fighter capacity — no line, no count.)
- Drone bay volume and drone bandwidth are independent dimensions over the
  same rows: a drone with known volume but no 1272 row (60478) counts toward
  bay volume and excludes from bandwidth, and vice versa.
- Over-capacity is ordinary data: `used` may exceed `capacity` (including
  capacity `0.0` with items present); nothing is clamped, capped, or errored.
  Bandwidth is never capped at the ship's bandwidth (section 2.5).
- Huge quantities stay finite and formatter-safe the same way
  `resources.rs` relies on `f64` multiplication and the UI formatter's
  huge-magnitude guard (section 8 pins `i64::MAX`).

## 5. Availability

- **Per-bay independence.** Each of the four dimensions is available or not
  on its own capacity field. 2863 Primae shows a cargo line and no drone,
  bandwidth, or fighter lines. A carrier shows cargo, drone (`0.0`
  capacity), bandwidth (`0.0`), and fighter lines.
- **Independence from sibling blocks.** `bay_usage` keys off its own five
  catalogue fields (four capacities on the ship, volume/bandwidth on items)
  and nothing else. Its outcome never affects, and is never affected by,
  fitting resources, ship base stats, resistances, EHP (effective hit
  points), or peak recharge outcomes; each block renders or shows its own
  unavailable sentence independently. A test pins at least one cross
  combination each way (section 8).
- **Missing capacity versus capacity exactly `0.0`.** Missing capacity data
  for a bay yields no line for that bay — never a zero, a dash, or
  placeholder words (the `ship_stat_line` precedent). A present capacity of
  exactly `0.0` with items present yields a real over-capacity line
  (used > 0.0 of 0.0). A present `0.0` capacity with nothing fitted yields
  "0.0 of 0.0 (0.0 left)": present data renders, per section 2.5 rule 6.
- **Ship-level failure** (unknown/non-ship/`ship_type_id <= 0`, or all four
  capacities unusable) yields `Unavailable` and the block's fixed unavailable
  sentence. A failed catalogue load yields the block's no-catalogue sentence.
  The heading renders in every state, so the feature is never silently
  omitted (sibling-block precedent).
- The block renders even when the fitting has no items (sibling precedent):
  every available bay shows 0.0 used against its capacity.

## 6. UI

### 6.1 Placement: its own block

Decision: **a new block, not lines inside the "Ship (base values)" block.**
Sibling precedent is uniform — resources, base stats, resistances, EHP, and
peak recharge are each their own headed block with their own disclosure —
and bay *usage* depends on what is fitted, unlike the bare-hull numbers in
the ship block, so folding it in would put fitted-dependent numbers under a
bare-hull heading and disclosure. The block is rendered by one shared
function (working name `render_bay_usage`) called from both detail sites in
`src/ui/fittings.rs`, immediately **after** `render_fitting_resources` and
before `render_ship_base_stats` (used-versus-capacity fitted math sits next
to used-versus-output fitted math; bare-hull blocks follow). It takes only
`(&CharacterFitting, Option<&FittingTypes>)` — no skill levels, no SDE
handle — so it renders identically for every viewing character, like the
ship blocks. It logs nothing.

### 6.2 Verbatim templates

Heading (locked): `Bays (base values)`.

Bay lines reuse the `resource_line` shape exactly — `{label}: {used} of
{capacity} used ({remaining} left)`, or `({over} over)` when `is_over()` —
formatted with `widgets::format_fitting_amount` (one decimal, grouped
digits, huge-magnitude guard). Exactly at capacity is `0.0 … left` in the
normal colour. An over-capacity line renders in `egui::Color32::LIGHT_RED`,
the resources precedent. Locked labels and units, in locked order:

| Order | Label | Unit | Example |
|---|---|---|---|
| 1 | `Cargo bay` | `m3` | `Cargo bay: 5.0 m3 of 140.0 m3 used (135.0 m3 left)` |
| 2 | `Drone bay` | `m3` | `Drone bay: 25.0 m3 of 0.0 m3 used (25.0 m3 over)` |
| 3 | `Drone bandwidth` | `Mbit/sec` | `Drone bandwidth: 25.0 Mbit/sec of 25.0 Mbit/sec used (0.0 Mbit/sec left)` |
| 4 | `Fighter bay` | `m3` | `Fighter bay: 3,000.0 m3 of 40,000.0 m3 used (37,000.0 m3 left)` |

A `None` bay contributes no line. Note the formatter rounds to one decimal:
a computed 0.58 m3 renders as `0.6 m3` and a computed 5.02 m3 as `5.0 m3`.
That is the shared formatter's locked behaviour (tests pin computed `f64`
values in the pure layer and rendered strings separately, section 8); no
bay-specific formatter is added.

Excluded-item lines (one per dimension, rendered after the bay lines in the
same dimension order, only when the count is > 0), mirroring
`cpu_excluded_line` singular/plural shape:

- `Cargo bay does not count 1 item with no volume data in Mimir's bundled item data.`
- `Cargo bay does not count {n} items with no volume data in Mimir's bundled item data.`
- `Drone bay does not count …` (same pattern, "volume data")
- `Fighter bay does not count …` (same pattern, "volume data")
- `Drone bandwidth does not count 1 item with no bandwidth data in Mimir's bundled item data.`
- `Drone bandwidth does not count {n} items with no bandwidth data in Mimir's bundled item data.`

"Item/items" is used uniformly (not "drones"): counting is flag-driven, and
a row under `DroneBay` need not be a drone-category type.

Disclosure (locked, this block's own sentence — decision: the existing
ship-stats disclosure does **not** cover this block; it describes bare-hull
numbers, while bay usage is fitted-dependent and excludes a different set,
namely capacity bonuses and specialized holds):

> `Base bay capacities and plain item volumes from Mimir's bundled item data. Capacity bonuses from skills, modules (such as cargo expanders), rigs, subsystems, implants, and the ship itself are not applied, and specialized holds are not counted, so these numbers can differ from EVE.`

Unavailable sentences (locked, sibling shape):

- No catalogue: `Bay usage unavailable: Mimir's bundled item data failed to load.`
- No ship data: `Bay usage unavailable: Mimir's bundled item data has no bay capacity data for this fitting's ship.`

## 7. Demo story (hand-derived from quoted rows)

All inputs from `assets/demo/fittings.json` and the in-code samples in
`src/ui/fittings.rs`; all volumes/capacities quoted in sections 2–3
(2456 Hobgoblin II volume 5.0, bandwidth 5.0; 34/35/36/37 minerals volume
0.01 each; 185 EMP S 0.0025; 28668 Nanite Repair Paste 0.01; 587 Rifter
cargo 140.0 / drone 0.0 / bandwidth 0.0 / no fighter; 597 Punisher cargo
135.0 / drone 0.0 / bandwidth 0.0 / no fighter). Type 636 (Demo Brawler
cargo ×200) is **absent from `invTypes` and the catalogue** — it is the
demo's built-in unknown-volume exhibit. Type 2457 under `FighterBay` is a
blueprint (volume 0.01) and counts for nothing here because the Rifter has
no fighter capacity (section 4, `None`-bay rule).

Character 90000001, "Demo Brawler" (587 Rifter):

- Cargo bay: used = 500×0.01 (34, `Cargo`) + 2×0.01 (35, `Invalid` →
  catch-all cargo) = 5.02 of 140.0; excluded 200 (type 636 ×200). Renders
  `5.0 m3 of 140.0 m3 used (135.0 m3 left)` plus the 200-item excluded line.
- Drone bay: used = 5×5.0 = 25.0 of 0.0, over. Renders red.
- Drone bandwidth: used = 5×5.0 = 25.0 of 0.0, over. Renders red.
- Fighter bay: no capacity data → no line, no excluded count.

Character 90000001, "Mission Runner" (587 Rifter):

- Cargo bay: 10×0.01 (37) = 0.1 of 140.0. Drone bay 15.0 of 0.0 over;
  bandwidth 15.0 of 0.0 over; no fighter line.

Character 90000002, "Demo Runner" (597 Punisher):

- Cargo bay: 20×0.01 (36) = 0.2 of 135.0. Drone bay 15.0 of 0.0 over;
  bandwidth 15.0 of 0.0 over; no fighter line.

Sample EFT import (`DEMO_SAMPLE_EFT`, Rifter, through synthesis):

- Cargo bay: 200×0.0025 (185 EMP S) + 8×0.01 (28668) = 0.58 of 140.0,
  rendering as `0.6 m3`. The loaded charge (Republic Fleet EMP S) is
  synthesis-excluded and counts nowhere. Drone bay 2×5.0 = 10.0 of 0.0 over;
  bandwidth 10.0 of 0.0 over; no fighter line.

Sample DNA import (`DEMO_SAMPLE_DNA`, Rifter, modules only):

- Cargo bay 0.0 of 140.0; drone bay 0.0 of 0.0 (0.0 left); bandwidth 0.0 of
  0.0; no fighter line. Empty bays by construction, shown as zeros against
  present capacities — correct, not missing.

The demo intentionally exhibits over-capacity (every demo fit carries
Hobgoblins on zero-drone-capacity frigates), an unknown-volume disclosure,
and the absent-fighter-bay omission. No demo carrier exists, so the fighter
line is exercised by pure/UI tests (section 8), not by demo data; demo data
is not modified by this slice.

## 8. Test plan

Pure layer (`bay_usage.rs`, against the bundled catalogue plus small fixture
catalogues via `FittingTypes::from_json`, the `resources.rs` test shape):

1. Oracle fit: 593 Tristan + 5×2488 Warrior II in `DroneBay` → drone bay
   25.0/40.0, bandwidth 25.0/25.0 (exactly at capacity, not over), cargo
   0.0/140.0, fighter `None`, all excluded 0.
2. Zero-capacity hull: 587 Rifter + 5×2456 → drone 25.0/0.0 `is_over`,
   bandwidth 25.0/0.0 `is_over`; and Rifter with no items → 0.0/0.0, not
   over, present (not `None`).
3. Absent capacity: 2863 Primae + drones fitted → cargo present, drone /
   bandwidth / fighter `None`, and the fitted drones contribute no excluded
   counts anywhere.
4. Fighter oracle: 45647 Caiman + 3×40556 Templar II in `FighterBay` →
   fighter 3000.0/40000.0; drone and bandwidth present at capacity 0.0 (the
   bays are independent, never summed).
5. Unknown counting: unknown type id and catalogue-absent volume add
   quantity **units** to that bay's `excluded_items` only; 60478 Light
   Mutated Drone counts 5.0 drone volume and excludes 1 bandwidth unit per
   drone; a present `0.0` volume counts and excludes nothing.
6. Section rule: the locked flag set (`DroneBay`, `FighterBay`, `Cargo`,
   `Invalid`, `ServiceSlot0`, `""`, `Foo`, `DroneBayExtra`, each slot
   prefix) lands exactly as `section_for_flag` files it (slot prefixes
   nowhere); pin the pure predicate against the UI predicate over this set
   with a test in `bay_usage.rs` duplicating the cases (no UI dependency).
7. Quantity/type clamps: quantity multiplies; 0 and negative quantities
   contribute and exclude nothing; `type_id` 0/negative rows are invisible;
   `i64::MAX` quantity stays finite and reports over (the `resources.rs`
   huge-quantity precedent).
8. Ship failures: unknown id, non-category-6 id, 0, negative → `Unavailable`;
   fixture ship with all capacities absent → `Unavailable`; fixture ship
   with exactly one capacity → `Available` with the other three `None`.
9. Independence: a fitting whose resources outcome is `ShipNoOutput` can
   still be bay-`Available` and vice versa (fixture catalogues), and bay
   availability ignores base-stat/resonance presence.
10. Synthesis path: the sample EFT (section 7 values) through `parse_eft` →
    `to_character_fitting` → `bay_usage`; the sample DNA yields present-zero
    bays. Loaded charges count nowhere.

Generator and loader (Builder A gates, section 3.5): double-run SHA-256
equality; strip-six-keys byte-identity against the pre-slice catalogue;
`BAY_ORACLES` present/absent checks; summary counts exactly as audited;
regenerated size within the 3,200,000-byte budget; loader
`bundled_catalogue_invariants` extended per section 3.4; old-shape fixture
JSON (no new keys) still parses.

UI (`src/ui/fittings.rs` tests, Builder B):

11. Line templates byte-exact for under / exactly-at / over cases in both
    units, including the one-decimal rounding exhibits (`0.6 m3` for 0.58);
    over lines flagged for the red rendering path the same way resource
    lines are tested.
12. Excluded-line templates byte-exact for 0 (none), 1 (singular), 2+
    (plural), all four dimensions.
13. Heading, disclosure, and both unavailable sentences byte-exact.
14. Demo pins: all three demo fittings and both samples produce the section 7
    computed values (pure) and rendered lines (UI), including the 200-item
    cargo excluded line on Demo Brawler and no fighter line anywhere in demo.
15. **Existing blocks byte-identical gate:** every pre-existing UI test for
    resources, ship base stats, resistances, EHP, and peak recharge passes
    unmodified; the only render change in either detail is the inserted bay
    block between resources and ship base stats. No existing test's expected
    string changes.

Repo gates at every commit: `cargo test`, `cargo clippy` (repo lints),
formatter check, and the demo smoke run used by prior slices. No behaviour
outside the fittings detail views changes.

## 9. Integrator list

- `README.md`: the Fittings bullet gains a bay-usage sentence alongside the
  existing resources/base-values sentences, naming base capacities, plain
  volumes, unapplied capacity bonuses (cargo expanders named), uncounted
  specialized holds, and that numbers can differ from EVE. The "no DPS
  numbers" sentence stays true and unchanged in scope (no drone/fighter DPS
  is added). Any feature-count or screenshot inventory sites touched by
  prior fitting slices get the same treatment; if none exist, say so in the
  commit.
- `docs/engineering-journal/LEARNINGS.md`: dated entry for the "38" collision
  (dogma 38 `capacity` has zero rows; Flutter's key 38 was synthesized
  `invTypes.volume`; dogma 161 `volume` is a decoy) with Evidence
  (cache/zip cites), Mechanism, and the generalizable rule (a named
  attribute with zero per-type rows is not a data source; check the
  `invTypes` columns before trusting an attribute name).
- `docs/engineering-journal/DECISIONS.md`: dated entry covering (a) volume on
  every catalogue row at +12.9% versus an ungrounded subset, (b) fighter bay
  included on the 2055 grounding, (c) flag-driven counting mirroring the UI
  catch-all (with the `ServiceSlot*` cost stated), each with rationale,
  rejected alternatives, and a revisit condition.
- This design file is the design commit; no other docs move in builder
  commits. No `docs/HANDOFF.md` or spec change is required by this slice.

## 10. Exclusions (explicitly not in this slice)

- Skill, module, rig, subsystem, implant, and ship capacity bonuses of every
  kind (cargo expanders and friends change nothing shown; attributes 149,
  614, 2689, 499 are never read). Base values only.
- Specialized holds and hangars: ore/mineral/gas/salvage/planetary/ammo/
  booster/corpse/Quafe/command-center/subsystem/material/fuel bays, ship
  maintenance bay, fleet hangar, ship holds, and `capacitySecondary` (1233).
  Items that EVE would place in a specialized hold still count by their
  fitting flag here; the disclosure says specialized holds are not counted.
- Drone control range, drone/fighter DPS (damage per second), fighter
  tubes/squadrons/abilities, active-versus-in-bay drone states.
- Any editor or write-path change; any ESI, scope, storage, or demo-data
  change. Imported fittings get bay numbers only through the existing
  synthesis to `CharacterFitting`.
- Capacitor, CPU/power, and all other fitting math: untouched.

## 11. Ownership and commit split

Small atomic commits, `type(scope): description`, no attribution lines.
Nothing is pushed or merged by builders; the parent does that. Resolved
names only in UI text; `[FITTING]` counts-only logging, never per rendered
frame (this slice adds no new log lines: the pure function and render
function log nothing, and the loader's existing counts line is unchanged).

1. **Design (this commit):** `docs(bays): design bay capacities and bay usage`
   — only `docs/bay-capacities-design.md`.
2. **Builder A — data and pure layer:** generator extension + regenerated
   catalogue + loader fields/invariants + `src/fitting/bay_usage.rs` with its
   tests and `mod.rs` export. Split as (a) generator + catalogue with the
   section 3.5 proofs stated in the commit body, (b) loader + pure module.
   Builder A touches no file under `src/ui/`.
3. **Builder B — rendering:** `render_bay_usage` and its line/disclosure
   helpers in `src/ui/fittings.rs`, wired into both detail sites after
   resources, with UI tests and the section 7 demo pins. Builder B touches
   no generator, catalogue, loader, or pure-module file. Depends on Builder
   A's public API exactly as locked in section 4; any needed API change goes
   back through the design (amend this file in its own commit), never a
   silent rendezvous edit.
4. **Integrator:** README + engineering journal (section 9), final full gate
   run, demo smoke of both detail views against section 7, and confirmation
   that the existing-blocks byte-identical gate (test 15) holds on the final
   tree.

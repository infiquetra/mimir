# Fitting resources (base CPU and power grid) — design

Status: locked for the `feat/rust-fitting-resources` slice. Base:
`develop` at `c0aee79` (verified clean before branching). Slice branch:
`feat/rust-fitting-resources`. This document is the single design commit;
builders and the integrator implement exactly what is locked here and
nothing else.

## 1. Goal and value ranking

Show fitting resources — CPU and power grid used versus the ship's
output, with the amount left — for the selected saved fitting and for
the imported fitting in the Fittings view. This is the first honest
slice of a fitting simulator: only what base dogma attributes in the
bundled catalogue can prove, computed locally. No network, no ESI
changes, no new scopes, no persistence.

Value ranking (locked, in order):

1. **Never show an unlabeled partial total.** Every number on screen
   says exactly what it includes and excludes, in the view itself
   (section 4 wording). A total that looks like an in-game fitting
   total but silently ignores modifiers is a lie and is the failure
   this slice exists to avoid.
2. **Correctness of the base sums.** The unmodified attribute sums
   must be hand-verifiable against the cache rows (section 8 oracles).
3. **Reuse.** Existing catalogue, section, exporter-disclosure, and
   formatting precedents beat new machinery.

Non-goals are locked in section 10. In particular: no DPS, tank,
capacitor, or speed numbers; no fitting editor; no calibration.

## 2. Attribute set (locked)

Every identifier below traces to an inspected body. No EVE attribute
number in this design comes from memory.

| Role | Attribute | Source of the number | Unit |
|---|---|---|---|
| Ship CPU output | 48 (`cpuOutput`, "CPU output of ship") | `dogmaAttributes.jsonl` `_key` 48 in `scripts/sde/eve-online-static-data-3503375-jsonl.zip`; Flutter `dogma_attributes.dart:3` at `ed698d3` (`cpuOutput = 48`) | 106 = `tf` (`dogmaUnits.jsonl` `_key` 106, Teraflops) |
| Ship power output | 11 (`powerOutput`, "power output of power core") | `dogmaAttributes.jsonl` `_key` 11; Flutter `dogma_attributes.dart:4` (`powerOutput = 11`) | 107 = `MW` (`dogmaUnits.jsonl` `_key` 107, MegaWatts) |
| Module CPU need | 50 (`cpu`, "CPU need of module") | `dogmaAttributes.jsonl` `_key` 50; Flutter `dogma_attributes.dart:71` (`cpuLoad = 50`) | 106 = `tf` |
| Module power need | 30 (`power`, "current power need") | `dogmaAttributes.jsonl` `_key` 30; Flutter `dogma_attributes.dart:72` (`powerLoad = 30`) | 107 = `MW` |

Explicitly **not** used, with the inspected reason:

- Attributes 49 (`cpuLoad`, "CPU load of ship") and 15 (`powerLoad`,
  "Current load of power core") are runtime load attributes, not base
  capacity or base need (`dogmaAttributes.jsonl` `_key` 49 and 15).
- Attribute 1153 (`upgradeLoad`, calibration cost; Flutter
  `dogma_attributes.dart:73`) is the rig resource. Calibration is out
  of this slice (section 10).
- Attributes 145 and 202 are output multipliers read by effect
  modifiers (Reactor Control Unit and Co-Processor families; prior
  discovery result 2, Flutter engine routing). They are modifier
  inputs, not base values, and are excluded by section 4.

Values come from one place only: `scripts/sde/dgmTypeAttributes.csv.bz2`
(header `typeID,attributeID,valueInt,valueFloat`, 612,816 rows),
joined into the bundled catalogue by the generator (section 5). The
runtime never reads the CSV cache or the zip archive. Inspected cache
facts the design relies on (read directly from the cache during
design):

- All 9,556 rows for attributes 48/11/50/30 carry `valueFloat` only
  (`valueInt` is always the literal `None` for these attributes), no
  `(typeID, attributeID)` pair is duplicated, none is negative, and
  exactly 8 are fractional — all attribute 50 with a `.5` CPU need
  (for example type 37303, Dual 1000mm Railgun II, CPU 126.5). The
  fractional rows are why display keeps one decimal (section 3).
- Every one of the 404 category-6 (ship) catalogue rows has both
  output rows. Two ships carry present zero outputs (2078 Zephyr and
  3532 Echelon, both 0.0/0.0): present-zero is data, not absence.
- Rigs never carry 50/30 rows: 0 of 642 catalogue rows whose only slot
  effect is 2663. Subsystems never carry 50/30 rows: 0 of 48
  category-32 rows. Twelve offensive subsystems (45598–45609) carry
  11/48 output rows; section 4 locks what happens to those (nothing).
- Among category-7 rows with a low/medium/high slot effect (11/13/12),
  3,177 of 3,279 carry both need rows. The remainder split into
  genuinely zero-cost passive modules with no rows at all (Overdrive
  Injector, Nanofiber, Expanded Cargohold, Inertial Stabilizer
  families), six rows with a power row but no CPU row (Hyperspatial
  Accelerator and Jump Drive Economizer families, power 1.0), and the
  Abyssal module families, which have no base rows because their
  in-game values are mutated per item. Absence alone cannot tell
  "costs nothing" from "no base data exists", so section 3 treats
  absence as *not counted and disclosed*, never as a silent zero.
- Present explicit `0.0` needs exist and must stay distinct from
  absence: type 1355 (Reactor Control Unit II) has power `0.0`, type
  3888 (Co-Processor II) has CPU `0.0`. The catalogue therefore uses
  optional values (section 5), not `0.0` defaults.

Missing-row behavior (locked): a module dimension with no attribute
row contributes nothing to that dimension's sum and increments that
dimension's excluded-module count (section 3). A ship with no
catalogue row, a non-ship ship row, or a missing output in either
dimension yields no resource numbers at all (section 6), never a
zero denominator.

## 3. Computation model (locked)

The computation is a pure function over a `CharacterFitting` and the
bundled catalogue (section 6 gives the API). Saved fittings already
are `CharacterFitting`s; imported fittings reach the same function
through the existing `ImportedFitting::to_character_fitting()`
synthesis (`src/fitting/eft.rs:278-326`), so there is one code path.

**Consuming sections.** Only items whose ESI flag names a low, medium,
or high slot consume CPU or power grid. The pure module tests the flag
prefixes itself (`LoSlot`, `MedSlot`, `HiSlot` — the same prefixes
`section_for_flag` matches at `src/ui/fittings.rs:47-65`) rather than
depending on the UI enum, following the `ImportSection` independence
precedent (`src/fitting/eft.rs:56-68`). Grounding: Flutter's usage
loop sums over `fitting.allModules` (high, medium, low, rig,
subsystem; `models.dart:55-61`, `dogma_engine.dart:688-695` at
`ed698d3`), and rigs and subsystems contribute exactly nothing to
that sum in the inspected data (0 of 642 rigs and 0 of 48 subsystems
carry 50/30 rows, section 2), so restricting consumption to
low/medium/high is numerically identical to Flutter's loop on base
values. Rigs, subsystems, drones, fighters, cargo, catch-all flags,
and loaded charges are therefore:

- never summed, and
- never counted as excluded (they are not failed modules; a rig with
  no CPU row is normal, and counting every rig as "no data" would
  cry wolf on every real fit).

Loaded charges deserve one explicit sentence: they never consume CPU
or power grid in Flutter's loop, and they do not exist in the
synthesized `CharacterFitting` anyway (charges are display-only,
`src/fitting/eft.rs:274-277`), so charge resource use is excluded as
unconsumed, not as unknown (section 10).

**Per-item contribution.** For each item row in a consuming section:

- Rows with `type_id <= 0` are ignored entirely — neither counted nor
  excluded — matching `fitting_item_rows` (`src/ui/fittings.rs:181-183`).
- Quantity is clamped with `quantity.max(0)` (the
  `fitting_item_rows` precedent, `src/ui/fittings.rs:190`). A clamped
  quantity of 0 contributes 0 and is neither counted nor excluded.
- The catalogue row is found with `FittingTypes::lookup_by_id`
  (`src/names/fitting_types.rs:143-147`). Slot-section quantities are
  1 on both import paths (EFT import rejects stacked slot modules and
  pushes quantity 1; DNA import expands quantities into repeated
  quantity-1 rows), but saved ESI rows carry their quantity raw, so
  the sum always multiplies: contribution = clamped quantity ×
  per-unit need, in `f64`.
- Per dimension independently: if the row is absent from the
  catalogue, or that dimension's optional value is `None`, or the
  value is non-finite or negative (defense in depth; the bundled
  catalogue invariants in section 5 prove this cannot happen for the
  shipped asset), the row contributes 0 to that dimension and
  increments that dimension's `excluded_modules` count by 1 **row**
  (not by units), mirroring the row-counted `skipped_unknown` of the
  EFT exporter (`src/ui/fittings.rs:251-280`). A present `0.0` counts
  as a real 0 and does not increment anything.
- Whether the item "belongs" in that slot is never judged. A Damage
  Control II stored in a high slot (the Mission Runner demo fit does
  exactly this) still counts: section comes from the flag, cost from
  the catalogue, exactly as the renderer already groups it.

**Ship output.** `lookup_by_id(fitting.ship_type_id)` must find a
category-6 row with both outputs present, finite, and ≥ 0; otherwise
the result is "no ship output" (section 6) and no numbers render. The
output is the hull row's base 48/11 only. Flutter initializes ship
attributes from the hull alone (`dogma_engine.dart:268` at `ed698d3`:
`Map.from(shipType.baseAttributes)`); subsystem output rows reach a
Flutter total only through effect modifiers, which this slice does
not apply (section 4), so the twelve offensive-subsystem output rows
in section 2 are deliberately not added and not emitted (section 5).

**Arithmetic.** All math is `f64`, summed in stored item order, with
no rounding until display (Flutter's engine likewise keeps doubles
and rounds only in the readout). `remaining = output - used` is
computed from the unrounded values. Over-budget is `used > output`
(strictly, matching Flutter's diagnostics comparison) and is a
display state, never an error: the numbers still render, with the
over-budget wording and colour in section 7. The function is total:
`i64::MAX` quantity × the largest catalogue need is finite in `f64`,
counts use `saturating_add`, and nothing panics on hostile saved
data.

There is no module online/offline state in the Rust model
(`FittingItem` is flag, quantity, type ID only,
`src/esi/models.rs:721-728`), so Flutter's offline skip
(`dogma_engine.dart:688`) has no counterpart to port: every consuming
row counts. This is a property of the data the app holds, recorded
here so nobody later "fixes" it by inventing a state.

**Display rounding.** Exactly one decimal, thousands-grouped, always:
Flutter's readout is `toStringAsFixed(1)`
(`fitting_editor.dart:412-421` at `ed698d3`, labels `CPU` and `Power
Grid`), the `.5` CPU rows in section 2 make integer display lossy,
and outputs reach the millions (so grouping follows the
`format_isk`/`format_sp` shape in `src/ui/widgets.rs:8-53`). The
formatter is a new total function in `src/ui/widgets.rs`:

```rust
pub fn format_fitting_amount(value: f64, unit: &str) -> String
```

producing for example `114.0 tf`, `1,234.5 MW`, `-3.0 tf` (sign,
grouped whole part, `.` plus one fractional digit from rounding the
absolute value to the nearest tenth, half away from zero — the same
shape as `format_isk`'s carry handling), and `0.0 {unit}` with a
`[UI]` warning log for non-finite input (the `format_isk` precedent).
Builder B owns it and its unit tests (section 11). No percent and no
progress bar: Flutter's readout has neither, and the only
`ProgressBar` in the app shows skill training time
(`src/ui/skills.rs:107-117`), which is not a resource precedent. A
bar would also need an invented answer for "used / 0.0 output" on the
two zero-output ships; text has no such hole.

## 4. Modifier depth (locked: base values only)

This slice applies **no modifiers at all**. Used is the sum of base
needs; output is the hull's base output. The decision is grounded in
what the inspected Flutter implementation actually does and in what
this slice's inputs can prove:

- Flutter raises the outputs for two trained skills through a curated
  table (CPU Management 3426 → 48 and Power Grid Management 3413 →
  11, +5% per level; prior discovery result 2, `dogma_engine.dart`
  at `ed698d3`). Porting only that table would still leave module
  output bonuses unapplied, so the total would remain partial — with
  more moving parts (trained-skill levels are not an input to the
  locked pure function, section 6) and the same disclosure duty.
  Rank 1 in section 1 prefers the simpler, fully provable base sum.
- Flutter routes module output bonuses (Reactor Control effect 56,
  Co-Processor effect 536, additive output effects, drawback effects)
  and ship trait bonuses through its generic modifier pipeline, but
  prior discovery found **no test** in `dogma_engine_test.dart` or
  `dogma_modifiers_test.dart` exercising any 48/11 modifier. Engine-
  supported but test-unexercised behavior is not a grounded oracle,
  and the Rust catalogue carries no effect-modifier data at all.
- Skill reductions to module needs (the Weapon Upgrades family on
  50/30) were never applied even by Flutter's usage path: usage sums
  raw type values (`dogma_engine.dart:688-695`). Excluding them is
  faithful, and they are still named below because a user comparing
  with the game will see the difference.
- The Fittings view holds no implants (the fitting model has no
  implant slots on either side), so implant bonuses cannot enter.

The following sentence ships **verbatim** in the view under every
rendered resource block (section 7), and the same exclusions are
named in the README (section 9). It is written in the view's plain
voice ("Mimir's bundled item data" is the existing phrase for the
catalogue, `src/ui/fittings.rs:1143`):

> Base values from Mimir's bundled item data. Skills, implants, and
> bonuses from modules, rigs, subsystems, and the ship itself are not
> applied, so these numbers can differ from EVE.

Each named class maps to a grounded exclusion: skills (output skills
plus need-reduction skills), implants (not held), module bonuses
(output multipliers/adders like Reactor Control Units and
Co-Processors), rig bonuses and drawbacks, subsystem output rows
(section 2 and 3), and ship role/trait bonuses. No other wording may
wrap the numbers in a way that implies an in-game total: the block
heading itself carries "(base values)" (section 7), and no string in
the slice may call these numbers fitting "statistics" (section 9).

## 5. Catalogue extension (locked)

The bundled catalogue (`assets/sde/fitting_types.json`, today
2,450,460 bytes, 25,818 types, sha256
`fe2a9ba0800e49cb4de618cd167f3e03527c696368049f855e029f16bf847624`)
gains base resource attributes through its existing generator only.
Hand-editing the JSON is forbidden, as with every generated asset in
this repo.

**Generator changes** (`scripts/sde/generate_fitting_types_sde.py`,
191 lines today, read in full):

- Add `"dgmTypeAttributes": "dgmTypeAttributes.csv.bz2"` to `CACHES`
  (lines 37-41) so the existing missing-cache failure covers it, and
  load it with the existing `load_csv` helper. The committed cache is
  already on disk; the generator still never downloads.
- Build a per-type map from rows whose `attributeID` is in
  `{48, 11, 50, 30}` (a named constant with a comment citing
  `dogmaAttributes.jsonl` and Flutter `dogma_attributes.dart` at
  `ed698d3`, mirroring the `SLOT_EFFECT_IDS` provenance comment at
  lines 14-17). Parse `valueFloat` as `float` (section 2 proves these
  rows always carry it); an unparseable or non-finite or negative
  value in a wanted row is a `fail(...)`, and a duplicated
  `(typeID, attributeID)` wanted pair is a `fail(...)` — the
  generator fails loudly and writes nothing, per its header contract.
- Emission is additive and sparse. For each type row, after the
  existing four keys in their existing order:
  - category 6 only: append `"cpuOutput"` (attribute 48) and
    `"powerOutput"` (attribute 11), each only when a row exists;
  - category 7 with non-empty `slotEffects` only: append `"cpu"`
    (attribute 50) and `"power"` (attribute 30), each only when a
    row exists;
  - every other row is byte-identical to today.
  Key names mirror the SDE attribute names (`cpuOutput`,
  `powerOutput`, `cpu`, `power` in `dogmaAttributes.jsonl`) in the
  file's camelCase convention. Category-32 subsystem output rows are
  **not** emitted: no locked computation reads them (section 3), and
  dead data in a bundled asset is how the next reader talks
  themselves into an ungrounded sum. The 404 ship and ~3,183 module
  rows that gain keys keep their existing keys byte-stable;
  consumers ignore unknown fields (the Rust struct has no
  `deny_unknown_fields`), so the new asset still loads on old code.
- Self-validation grows, in the existing style: attribute oracle
  checks on the existing `ORACLES` ids plus new pins — 587 Rifter
  cpuOutput 130.0 / powerOutput 41.0; 2048 Damage Control II cpu 30.0
  / power 1.0; 1183 cpu 6.0 / power 6.0; 438 cpu 15.0 / power 11.0;
  448 cpu 36.0 / power 1.0; 2889 cpu 9.0 / power 4.0; 31668 (rig)
  neither cpu nor power key; 45623 (subsystem) no resource keys at
  all; 37303 cpu 126.5 (the fractional pin); 1355 power present and
  0.0 (the explicit-zero pin); 1236 Overdrive Injector System II
  neither key (the zero-cost-absence pin). Every value just listed
  was read from the cache during design, not recalled. Plus a
  catalogue-wide invariant: every category-6 row carries both
  outputs (true today, 404/404), so a future cache refresh that
  drops a ship output fails loudly instead of blanking that ship in
  the UI. The summary print gains the counts of rows gaining each
  key.
- Determinism is unchanged: types sorted by `typeId`, compact
  separators, trailing newline, no timestamps, dict insertion order
  fixed by construction. Proof obligations for Builder A (section
  8): run the generator twice and compare sha256; strip the four new
  keys from the new file and compare byte-for-byte with the base
  file's sha256 above. Both proofs are run once and reported in the
  commit body or PR text, not committed as scripts.

**Size budget.** A simulation of the locked emission rule over the
real cache adds ≈92,264 bytes → ≈2,542,724 bytes (+3.8%). Budget:
the regenerated file must land within +150,000 bytes of today's
2,450,460; Builder A states the exact new byte count in the commit
body. Anything over budget means the emission rule drifted (for
example emitting on non-slot rows) and stops the slice for review.

**Rust loader** (`src/names/fitting_types.rs:20-31`). `FittingType`
gains four fields, each `#[serde(default)]` so old assets and test
fixtures without the keys load as `None` (the `slotEffects` default
precedent at line 29):

```rust
#[serde(rename = "cpuOutput", default)]
pub cpu_output: Option<f64>,
#[serde(rename = "powerOutput", default)]
pub power_output: Option<f64>,
#[serde(rename = "cpu", default)]
pub cpu: Option<f64>,
#[serde(rename = "power", default)]
pub power: Option<f64>,
```

`PartialEq` is retained (tests construct and compare rows by lookup,
not by float equality, but the derive must keep compiling). Loading,
indexing, and lookup behavior do not change; nothing is validated at
load beyond what exists today (the computation guards values,
section 3, and the invariants test proves the shipped asset).

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs:278-325`), all over the real bundled
asset: every category-6 row has both outputs `Some`, finite, ≥ 0;
every present resource value anywhere is finite and ≥ 0; no row
outside (category 6) ∪ (category 7 with non-empty slot effects)
carries any resource value; category-7 rows whose only slot effect
is 2663 (rigs) carry neither need; output fields are `None` on
category-7 rows and need fields are `None` on category-6 rows; the
same spot pins as the generator oracles (587, 2048, 37303 cpu 126.5,
1355 power `Some(0.0)`, 1236 both `None`, 31668 both `None`). The
existing invariants pass unmodified.

## 6. Pure API (locked)

New module `src/fitting/resources.rs`, declared and re-exported from
`src/fitting/mod.rs` beside `dna`/`eft`/`write_map`. The module
header follows the house pattern (`src/fitting/mod.rs:1-2`): pure
computation over the bundled catalogue — no egui, no state, no
network, no database. It depends on `CharacterFitting` /
`FittingItem` (`src/esi/models.rs:699-728`) and `FittingTypes`, the
same dependencies `src/fitting/eft.rs` already takes.

```rust
/// One resource dimension: base need summed over counted fitted
/// modules against the hull's base output.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResourceBudget {
    pub used: f64,
    pub output: f64,
    /// Consuming-section rows with no usable value for this
    /// dimension (absent from the catalogue, no attribute row, or
    /// an unusable value). Counted in rows, never silently zero.
    pub excluded_modules: usize,
}

impl ResourceBudget {
    pub fn remaining(&self) -> f64 { self.output - self.used }
    pub fn is_over(&self) -> bool { self.used > self.output }
}

/// Base CPU / power grid outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FittingResources {
    Available { cpu: ResourceBudget, power: ResourceBudget },
    /// The catalogue has no usable ship output for this fitting's
    /// ship, so no honest numbers exist.
    ShipNoOutput,
}

pub fn fitting_resources(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> FittingResources;
```

Locked semantics (section 3 restated as contract):

- `ShipNoOutput` when `ship_type_id <= 0`, when the catalogue has no
  row for it, when the row is not category 6, or when either output
  is `None`, non-finite, or negative. There is no error channel: bad
  input degrades to disclosure, and the function never panics.
- Otherwise both budgets are computed independently per section 3.
  Unknown items are never silently zero: every consuming-section row
  (clamped quantity > 0) that cannot contribute to a dimension is
  counted in that dimension's `excluded_modules`, like the exporters'
  disclosed skips. Both paths share this one function: the saved
  detail passes the selected `CharacterFitting`; the imported detail
  passes `imported.to_character_fitting()` — the same `synth` value
  the panel already builds (`src/ui/fittings.rs:1241`).
- Exactly one log line per call, `[FITTING]` tag, counts only (the
  repo logging rule: every change adds `[FEATURE]` debug logging, and
  the fitting slice rule is counts only — no names, no pasted text,
  no type numbers): a `tracing::debug!` with the counted-row and
  excluded-row counts, plus the `ShipNoOutput` outcome. No `info!`:
  this runs at render cadence like `fitting_item_rows`, whose log is
  also `debug!` (`src/ui/fittings.rs:202-207`).

Unit tests live in the module beside the code (section 8), against
both hand-built `FittingTypes::from_json` fixtures and the real
bundled catalogue.

## 7. UI placement and exact strings (locked)

One shared renderer in `src/ui/fittings.rs`, called from both
details with the fitting and `fitting_types: Option<&FittingTypes>`
(which `show` already receives, `src/ui/fittings.rs:1407-1412`):

```rust
fn render_fitting_resources(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
)
```

Placement: in the saved detail immediately after the items block
(`src/ui/fittings.rs:1523-1528`) and before the "Copy as EFT" button
(line 1529); in the imported detail immediately after the items
block (lines 1243-1248) and before "Loaded charges" (line 1255). The
block renders even when the fitting has no items — a hull-only fit
has honest zeros to show. It renders in demo mode identically; the
existing demo banner (`widgets::mode_notice`) already owns the
"invented sample rows" disclosure.

Rendered lines, exactly (all numbers through
`format_fitting_amount`, section 3):

1. Heading: `Fitting resources (base values)` via `ui.heading`,
   matching the section-heading style of `render_fitting_items`.
2. CPU line: `CPU: {used} of {output} tf used ({remaining} tf left)`
   — for example `CPU: 114.0 of 130.0 tf used (16.0 tf left)`.
3. Power grid line: `Power grid: {used} of {output} MW used
   ({remaining} MW left)` — for example `Power grid: 31.0 of 41.0 MW
   used (10.0 MW left)`. (Two words, matching Flutter's `Power Grid`
   label; sentence case, matching "Low slots".)
4. Over-budget variant of either line: `({over} tf over)` /
   `({over} MW over)` with the positive overage, and the whole line
   in `egui::Color32::LIGHT_RED` via `ui.colored_label` — the app's
   error colour (`src/ui/widgets.rs:149`), standing in for Flutter's
   red value text (prior discovery result 2). Exactly-at-budget
   renders `0.0 tf left` in the normal colour.
5. Excluded-module line, per dimension, only when that dimension's
   count is above zero: `CPU does not count {n} fitted modules with
   no CPU data in Mimir's bundled item data.` and `Power grid does
   not count {n} fitted modules with no power grid data in Mimir's
   bundled item data.` — with `1 fitted module` singular when
   n = 1. Per-dimension lines (never a combined count) so the two
   budgets can disagree honestly (the six power-only rows, section 2).
6. The section 4 disclosure sentence, verbatim, always last when
   numbers render.

Unavailable states replace lines 2-6 (the heading still renders, so
the view never silently omits the feature):

- Catalogue failed to load (`fitting_types` is `None`):
  `Fitting resources unavailable: Mimir's bundled item data failed
  to load.` — mirroring the import panel's locked sentence
  (`src/ui/fittings.rs:1143`).
- `ShipNoOutput`: `Fitting resources unavailable: Mimir's bundled
  item data has no ship output data for this fitting's ship.`

Wording is produced by small pure helpers beside the renderer
(over/left line, excluded line) so the exact strings are unit-test
pinned without an egui harness, following the
`placeholder_note`/`charges_note` helper precedent. No raw EVE
numeric IDs appear in any string; the block names no modules, so
nothing new needs name resolution. The renderer logs nothing itself
(the pure function already logged counts).

**Demo story (locked).** The demo saved fittings are partially
invented sample rows — `assets/demo/fittings.json` puts a blueprint
(2049) and an ore (1225) in module slots, a drone (28270, named
"Demo Interdiction Subsystem" in `assets/demo/names.json`) in a
subsystem slot, and two type numbers absent from the catalogue
(1535, 636). The fixture is **not repaired in this slice**: changing
it would churn the demo name set and the deliberate invalid-flag
demonstration for no resource benefit. Instead the honest demo
behaviour is the disclosure machinery itself, and these are the
exact numbers a reviewer sees (hand-computed from the cache rows in
section 2 during design):

- Demo Brawler (Rifter, 130.0 tf / 41.0 MW): counted Damage Control
  II (30.0/1.0) + 2 × Gistum C-Type Multispectrum Shield Hardener
  (27.0/1.0 each) → CPU `84.0 of 130.0 tf used (46.0 tf left)`,
  power grid `3.0 of 41.0 MW used (38.0 MW left)`, and both excluded
  lines at 2 fitted modules (the blueprint and the ore). Rig,
  subsystem, drone, fighter, and cargo rows neither count nor
  exclude.
- Mission Runner (Rifter): `30.0 of 130.0 tf (100.0 left)`,
  `1.0 of 41.0 MW (40.0 left)`, both excluded lines at 1.
- Demo Runner (Punisher, 140.0 tf / 67.0 MW): `57.0 of 140.0 tf
  (83.0 left)`, `2.0 of 67.0 MW (65.0 left)`, both excluded lines
  at 1.
- The clean showcase is the demo import sample: "Use sample EFT" (or
  the identical sample DNA) → Import shows `114.0 of 130.0 tf (16.0
  left)` and `31.0 of 41.0 MW (10.0 left)` with no excluded lines —
  the section 8 oracle, visible end to end with no account.

No new demo data, buttons, or modes are added.

## 8. Test plan (locked)

Oracle numbers below were computed during design from the cache rows
themselves (`scripts/sde/dgmTypeAttributes.csv.bz2`): Rifter 587
outputs 130.0 tf / 41.0 MW; Damage Control II 2048 needs 30.0/1.0;
Small Armor Repairer II 1183 needs 6.0/6.0; 1MN Afterburner II 438
needs 15.0/11.0; Warp Scrambler II 448 needs 36.0/1.0; 200mm
AutoCannon II 2889 needs 9.0/4.0. Note for anyone cross-checking
Flutter: its `dogma_engine_test.dart` Rifter uses synthetic 125/37
outputs — this slice's oracles use the real cache rows 130.0/41.0
and say so in the test comments; the Flutter test values are not
ported.

**Pure calculation** (`src/fitting/resources.rs`, Builder A), against
the real bundled catalogue where stated:

- Hull only (Rifter, no items): used 0.0/0.0, output 130.0/41.0,
  remaining 130.0/41.0, excluded 0/0, not over.
- Rifter + Damage Control II in `LoSlot0`: used 30.0/1.0, remaining
  100.0/40.0.
- Sample-fit oracle: `parse_eft(DEMO_SAMPLE_EFT)` (or the sample
  DNA) → `to_character_fitting()` → used 114.0 CPU / 31.0 power
  (30+6+15+36+9×3 and 1+6+11+1+4×3), remaining 16.0/10.0, excluded
  0/0 — proving the shared synthesis path, the rig's non-counting,
  and the loaded charge's non-counting in one fit. If the test needs
  the sample text it constructs the equivalent `CharacterFitting`
  locally rather than reaching into UI constants.
- Unknown and data-less rows: an absent-from-catalogue type in a low
  slot, type 2049 (blueprint, in catalogue, no needs), and type 1236
  (module, no need rows) each add 1 to both excluded counts and 0 to
  both sums; type 33981 (power `Some(1.0)`, CPU none) counts power
  and excludes CPU only; type 1355 (power `Some(0.0)`) counts as a
  real 0 with no exclusion.
- Non-consuming sections: the same counted module under `RigSlot0`,
  `SubSystemSlot0`, `DroneBay`, `FighterBay`, `Cargo`, an unknown
  flag, and an empty flag contributes nothing and excludes nothing;
  flag prefix pins (`LoSlot0`, `MedSlot7`, `HiSlot3` consume).
- Quantity handling: a saved row with quantity 3 contributes 3×;
  quantity 0 and -5 contribute 0 and exclude nothing; `type_id` 0
  and -1 are ignored entirely; quantity `i64::MAX` on a counted
  module yields a finite `used`, `is_over()`, and no panic.
- Ship failures: unknown ship ID, non-ship ship ID (2048), and
  `ship_type_id` 0 all return `ShipNoOutput`.
- Zero-output ship (fixture catalogue, outputs `Some(0.0)`,
  `Some(0.0)` — the Zephyr/Echelon shape): hull-only is not over
  with remaining 0.0; one counted module is over with the exact
  negative remaining.
- Over-budget pin: enough real modules on a Rifter to exceed CPU
  only (for example 5 × Damage Control II rows = 150.0 > 130.0,
  power 5.0 ≤ 41.0): CPU `is_over()`, power not, numbers still exact.
- Fixture-catalogue guards (`FittingTypes::from_json`): a `null` /
  absent key loads as `None`; negative and non-finite catalogue
  values (JSON cannot spell NaN, so negative and absent cover the
  guard's testable half; the `is_finite` half is pinned through a
  directly constructed `FittingType` if the test constructs the
  struct) are treated as excluded, never summed.

**Catalogue** (`src/names/fitting_types.rs` + generator, Builder A):
the section 5 invariants and spot pins; old-fixture JSON without the
new keys still loads (the existing fixture tests prove it — they
must pass unmodified apart from any `FittingType` literal
construction the new fields force); generator run twice → identical
sha256, and new-keys-stripped output byte-identical to the base
sha256 in section 5 (reported, not committed).

**UI wording and formatting** (`src/ui/fittings.rs`,
`src/ui/widgets.rs`, Builder B): formatter pins — `0.0 tf`,
`114.0 tf`, `126.5 tf` (fractional), `1,234.5 MW` (grouping),
`999.95` → `1,000.0` (tenth-carry rollover, mirroring the
`format_isk` 999.999 pin), `-3.0 tf`, non-finite → `0.0 tf`; line
pins for left / over / exactly-at-budget; excluded-line pins for 0
(absent → helper returns `None`), 1 (singular), 2 (plural), per
dimension; the two unavailable sentences; the demo-story numbers of
section 7 as a `fitting_resources` call over the real demo fixture
shape (Demo Brawler 84.0/3.0 with excluded 2/2) so fixture drift
fails a test instead of surprising a reviewer.

**Gates at every commit** (repo standard): `cargo test`,
`cargo clippy --all-targets -- -D warnings`, `cargo fmt --check`.
Existing fitting, import, export, demo, and catalogue tests pass
unmodified except where this design explicitly extends them.

## 9. Integrator list (locked)

The integrator (not the builders) makes these changes after both
builders land:

- **README** — three sentences change, all keeping the rule that
  resources are not fitting statistics:
  1. The Fittings bullet's closing claim ("There are no fitting
     statistics (no DPS, tank, or capacitor numbers).", line 22)
     becomes a sentence that adds the resource readout in the view's
     own honesty terms: base CPU and power grid for saved and
     imported fittings from bundled item data, with skills, implants,
     and module/rig/subsystem/ship bonuses not applied — and still
     states there are no DPS, tank, capacitor, or speed numbers.
     The words "simulator" and "statistics" must not attach to the
     new numbers.
  2. The Roadmap Fitting bullet (line 31): the parenthetical gains
     the base resource readout beside EFT/DNA export and import; the
     "ship fitting simulator with fitting statistics" stays listed
     as not implemented.
  3. The Status paragraph (line 37): "the fitting simulator is not
     present yet" stays true; the "only fitting features" enumeration
     gains the base resource readout.
- **Engineering journal** — a dated `LEARNINGS.md` entry in the same
  change set (repo rule): the absent-versus-zero attribute finding
  (genuine zero-cost modules are indistinguishable from Abyssal
  no-base-data modules in `dgmTypeAttributes`, so absence is
  disclosed, never zeroed) and the subsystem-output finding (hull
  rows only, per Flutter's pipeline), each with Evidence
  (file:line), Mechanism, and a one-line generalizable rule; plus a
  `DECISIONS.md` entry if the implementation surfaces a convention
  the next simulator slice must follow (base-values-first honesty
  labelling). Keep both short.
- Confirm the slice diff contains no ESI, scope, persistence, or
  network changes, and that the regenerated catalogue byte count in
  Builder A's commit body matches the committed file.

## 10. Exclusions (locked)

Out of this slice, by name: DPS, volley, tank/EHP, capacitor,
speed/navigation, targeting, and every other fitting statistic;
calibration (attribute 1153) and any rig-cost display; all modifier
application (skills including the two output skills and all
need-reduction skills, implants, module output bonuses, rig
bonuses/drawbacks, subsystem outputs and bonuses, ship role/trait
bonuses, stacking of any kind); skill application in any form (no
trained-skill input reaches the pure function); charges' resource
use (unconsumed in the grounded model, section 3); the fitting
editor and any fitting mutation; module online/offline state (the
model does not hold it, section 3); per-module resource itemization
in the item list (totals only — the block names no modules);
percentages and bars (section 3); ESI calls, scopes, and stored
data; demo fixture repair (section 7); reading `dogma.json`,
`effect_modifiers.json`, or the pinned zip at runtime (design-time
grounding sources only). Anything on this list appearing in a
builder commit is a design breach, not a bonus.

## 11. Ownership (locked)

Small atomic commits, `type(scope): description`, no attribution.
Nobody pushes or merges; the parent does that.

- **Builder A — data and pure calculation.** (1) Generator extension
  + regenerated `assets/sde/fitting_types.json` + loader fields +
  invariants (`feat(fittings): …`, exact new byte count and both
  determinism proofs in the commit body). (2) `src/fitting/resources.rs`
  with its tests, wired in `src/fitting/mod.rs`. Commit (2) must
  compile and pass gates with no UI change (dead-code warnings
  handled by the re-export, not by `#[allow]`).
- **Builder B — UI.** (3) `format_fitting_amount` in
  `src/ui/widgets.rs` with tests. (4) `render_fitting_resources` and
  both call sites in `src/ui/fittings.rs` with wording pins. Builder
  B changes no catalogue, generator, or `src/fitting/` files, and no
  demo assets.
- **Integrator.** (5) README + engineering journal (section 9), any
  cross-builder seam fix the two halves reveal (signature drift
  between sections 6 and 7 is the integrator's to reconcile back to
  this document, not to whichever builder wrote first), final gates,
  and a demo-mode visual pass over the section 7 demo story (all
  three demo fits plus the sample import) before reporting done.

Sequencing: A(1) → A(2) and B(3) in parallel-safe order (B(3) needs
nothing from A; B(4) needs A(2)'s API) → B(4) → integrator (5).

# Rig calibration — design

Status: locked for implementation. Base: `develop` at `72af56c`. Slice branch:
`feat/rust-rig-calibration`. Discovery: two read-only reports (Flutter
calibration math at `ed698d3` plus the shipped Rust twin templates; catalogue
and cache data audit), re-verified against the bodies named below during
design. Calibration is grounded at base values (section 2), so this slice is
a go. Every number in this document traces to an inspected body:
`dogmaAttributes.jsonl` / `dogmaUnits.jsonl` in the pinned SDE zip
(`scripts/sde/eve-online-static-data-3503375-jsonl.zip`), the committed
Fuzzwork caches `scripts/sde/dgmTypeAttributes.csv.bz2` and
`scripts/sde/invTypes.csv.bz2` read directly this session, the committed
catalogue `assets/sde/fitting_types.json` (3,148,744 bytes, 25,818 types),
Flutter at `ed698d3` via `git show`, and current Rust
(`src/fitting/resources.rs`, `src/fitting/bay_usage.rs`,
`src/fitting/eft.rs`, `src/fitting/dna.rs`, `src/fitting/write_map.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`scripts/sde/generate_fitting_types_sde.py`, `assets/demo/fittings.json`).

## 1. Goal and value ranking

Goal: in both fitting details (saved fitting detail and imported fitting
detail), show rig calibration used versus the ship's base calibration, at
base values from catalogue data — one used-versus-capacity dimension,
following the shipped CPU/power grid resources (`src/fitting/resources.rs`)
and bay usage (`src/fitting/bay_usage.rs`) patterns.

Value ranking, in order, when any two rules below appear to conflict:

1. **Never show a calibration number read from the wrong attribute.** Ship
   capacity has exactly one source (dogma 1132 `upgradeCapacity`) and each
   rig's cost has exactly one source (dogma 1153 `upgradeCost`). Any other
   value — Flutter's capacity read of 1153, its `400` fallback, dogma 560,
   structure rows on non-ship categories — must never reach the line
   (section 2).
2. **Correctness.** One plain sum over rig-slot rows, quantity semantics and
   unknown-counting exactly as locked; unknown data is counted and disclosed,
   never silently zeroed; absent data is never shown as zero and a present
   `0.0` renders as data.
3. **Reuse.** Mirror the existing pure-layer, generator, and rendering shapes
   wherever they fit without violating 1 or 2. Where reuse would couple
   availability or misname a value (folding calibration into
   `FittingResources` under its two-dimension gate and skill scaling, or
   calling a capacity an `output`), correctness wins and a small parallel
   shape is used — the same call the bay slice made (section 4).

Base values only: no skill, implant, or ship-bonus modifiers apply in this
slice (section 10). Discovery proves no shipped Rust pattern applies a
modifier to calibration: the only scaling anywhere in the fitting views is
the CPU Management 3426 / Power Grid Management 3413 output scaling inside
`fitting_resources_with_skills`, and calibration has no skill analogue there.

## 2. Sources and grounding (inspected bodies only)

### 2.1 Dogma attribute and unit truth

From `dogmaAttributes.jsonl` / `dogmaUnits.jsonl` in the pinned zip, `_key`
is the id:

| Id | Dogma name | Display name (en) | Unit id | Role in this slice |
|---|---|---|---|---|
| 1132 | `upgradeCapacity` | Calibration | 120 | Ship calibration (capacity). |
| 1153 | `upgradeCost` | Calibration cost | — (no `unitID` key) | Per-rig calibration cost. |
| 560 | `cloakingTargetingDelay` | Sensor Recalibration Time | 101 | **Decoy. Never read.** |

Verbatim records: 1132 has `attributeCategoryID` 7, `dataType` 5,
`defaultValue` 0.0, description "Attribute on ships used for ship upgrades",
`highIsGood` true, `iconID` 2887, `published` true, `stackable` true. 1153
has `attributeCategoryID` 1, `dataType` 5, `defaultValue` 0.0, description
"How much of the upgrade capacity is used when this is fitted to a ship.",
`highIsGood` true, `iconID` 2887, `published` true, `stackable` true, and
no `unitID` key at all. Unit 120 is `attributePoints`, display name (en)
verbatim `points`; unit 101 is `Milliseconds`.

A full sweep of `dogmaAttributes.jsonl` for display names or dogma names
containing "calibration" or "upgrade" finds exactly three rows: 1132, 1153,
and the 560 decoy (cloaking recalibration delay — "The time targeting
systems take to recalibrate after cloaking"). There is no fourth candidate
and no ambiguity about which id is capacity and which is cost. The catalogue
keys are the dogma `name` fields verbatim: `upgradeCapacity` and
`upgradeCost`.

The unit asymmetry is real and locked: the capacity side carries unit 120
`points` and the cost side is unitless in dogma. Both sides are the same
points in game, so the line renders `points` on every amount (section 6.2) —
the dogmaUnits display name for the capacity's unit — and never `m3`, `tf`,
`MW`, or `Mbit/sec`.

### 2.2 Coverage (scripted join of the caches against the catalogue)

Over the 404 published category-6 (ship) catalogue rows, attribute 1132:

- Present nonzero on 381 ships: `400.0` on 327, `350.0` on 41, `1.0` on 12
  (all shuttles and prototypes: 672 Caldari Shuttle, 2078 Zephyr, 11129 /
  11132 / 11134, 21097, 21628, 29266 Apotheosis, 30842, 33513 Leopard,
  34496, 64034 Boobook), and `300.0` on 1 (635 Opux Luxury Yacht).
- Present as `0.0` on 20 ships (raw cache string `'0.0'`): 588 Reaper, 596
  Impairor, 601 Ibis, 606 Velator, 615 Immolator, 617 Echo, 33079 Hematos,
  33081 Taipan, 33083 Violator (corvettes, group 237), 3532 Echelon, 20183
  Providence, 20185 Charon, 20187 Obelisk, 20189 Fenrir, 81040 Avalanche
  (freighters, group 513), 28844 Rhea, 28846 Nomad, 28848 Anshar, 28850 Ark
  (jump freighters, group 902), and 45534 Monitor. Present zero is data:
  these hulls render `used of 0.0`, never "unavailable".
- Absent (no row) on exactly 3 ships: 670 Capsule, 2863 Primae, and 33328
  Capsule - Genolution 'Auroral' 197-variant. These have no honest capacity
  number (section 5).
- 14 published non-ship rows also carry 1132 at `400.0` (category-65 Upwell
  structures: 35825 Raitaru, 35826 Azbel, 35827 Sotiyo, 35832 Astrahus,
  35833 Fortizar, 35834 Keepstar, 35835 Athanor, 35836 Tatara, 40340,
  47512–47516). They are why `upgradeCapacity` emission is gated to category
  6 exactly like `cpuOutput` / `powerOutput` (section 3.1): without the gate
  a structure row would look like a ship with calibration.
- 0 ships carry 1153. There are no duplicate (type, attribute) rows for
  1132 or 1153 anywhere in the cache.

Over the 921 published rigs (types whose `slotEffects` is `[2663]`),
attribute 1153:

- Present on all 921. Zero rigs lack the row.
- Category split: 642 ship rigs in category 7 (groups 773 Rig Armor, 774
  Rig Shield, 775 Rig Energy Weapon, 776 Rig Hybrid Weapon, 777 Rig
  Projectile Weapon, 778 Rig Drones, 779 Rig Launcher, 781 Rig Core, 782
  Rig Navigation, 786 Rig Electronic Systems, 1232 Rig Resource Processing,
  1233 Rig Scanning, 1234 Rig Targeting, 1308 Rig Anchor) and 279 structure
  rigs in category 66 (groups 1613–1642, 1816–1870, 1912–1945, 1984).
- Value distribution: `25.0` ×4, `50.0` ×236, `75.0` ×132, `100.0` ×210,
  `150.0` ×213, `200.0` ×60, `250.0` ×2, `300.0` ×64.
- 0 published non-rig types carry 1153, and 0 rigs carry 1132.

The category-66 half is the one emission trap: the generator's existing
module-need gate is `category_id == 7 and slot_effects`
(`generate_fitting_types_sde.py` line 632), which would silently drop all
279 structure rigs' costs. Structure rigs cannot appear under a ship's
`RigSlot*` flag in a saved fitting, but they pass the same EFT/DNA rig
section classification as ship rigs (effect 2663), so a dropped cost would
surface as a false "no data" exclusion instead of a counted cost. Section
3.1 therefore gates `upgradeCost` on effect 2663, not on category 7.

Values read directly from `dgmTypeAttributes.csv.bz2` (`valueFloat` column)
this session — the oracle pool for sections 3.3 and 8:

| typeId | Name | Attr | Raw | Parsed |
|---|---|---|---|---|
| 587 | Rifter (ship) | 1132 | `'400.0'` | 400.0 |
| 597 | Punisher (ship) | 1132 | `'400.0'` | 400.0 |
| 29986 | Legion (ship) | 1132 | `'400.0'` | 400.0 |
| 638 | Raven (ship) | 1132 | `'400.0'` | 400.0 |
| 23757 | Archon (ship) | 1132 | `'400.0'` | 400.0 |
| 11567 | Avatar (ship) | 1132 | `'400.0'` | 400.0 |
| 3514 | Revenant (ship) | 1132 | `'350.0'` | 350.0 |
| 635 | Opux Luxury Yacht (ship) | 1132 | `'300.0'` | 300.0 |
| 672 | Caldari Shuttle (ship) | 1132 | `'1.0'` | 1.0 |
| 588 | Reaper (ship) | 1132 | `'0.0'` | 0.0 (present) |
| 670 | Capsule (ship) | 1132 | — | absent |
| 2863 | Primae (ship) | 1132 | — | absent |
| 33328 | Capsule - Genolution 'Auroral' 197-variant | 1132 | — | absent |
| 35825 | Raitaru (category 65 structure) | 1132 | `'400.0'` | 400.0 (must not emit) |
| 31668 | Small Projectile Burst Aerator I (rig) | 1153 | `'200.0'` | 200.0 |
| 31716 | Small EM Shield Reinforcer I (rig) | 1153 | `'50.0'` | 50.0 |
| 25736 | Large EM Armor Reinforcer I (rig) | 1153 | `'50.0'` | 50.0 |
| 4395 | Medium Processor Overclocking Unit I (rig) | 1153 | `'150.0'` | 150.0 |
| 4399 | Medium Processor Overclocking Unit II (rig) | 1153 | `'300.0'` | 300.0 |
| 37146 | Standup M-Set Basic Medium Ship Manufacturing Material Efficiency I (category-66 rig) | 1153 | `'100.0'` | 100.0 |
| 37147 | Standup M-Set Basic Medium Ship Manufacturing Material Efficiency II (category-66 rig) | 1153 | `'150.0'` | 150.0 |

Ships carry no 1153 row and rigs carry no 1132 row (verified `None` for
every pair above and catalogue-wide in the counts). Note 31668 is already
the generator's rig oracle row (`ORACLES`, category 7, slot effect 2663),
but the existing resource oracles only assert it carries no CPU/power keys;
its `200.0` cost row has been sitting unasserted in the cache.

### 2.3 What Flutter did, and the bug this slice must not port

Flutter at `ed698d3` computes calibration but never displays it, and reads
the ship capacity from the wrong attribute:

- `lib/features/fitting/domain/dogma_attributes.dart:73` defines a single
  constant `upgradeLoad = 1153 // calibration`. There is no constant for
  1132 anywhere in the Flutter tree.
- `lib/core/sde/sde_service.dart:1062,1095-1097` reads attribute 1153 as
  each type's `calibration`, truncated with `toInt()` and defaulted with
  `?? 0` — a genuine dogma read for rig cost, with absent silently zeroed.
- `lib/features/fitting/domain/dogma_engine.dart:837` computes the ship's
  `calibrationMax = attr(DogmaAttributes.upgradeLoad, 400).toInt()` — it
  reads 1153 (the rig cost) as the ship capacity with a magic `400`
  fallback. Ships never carry 1153 (0 of 404 above), so the fallback always
  wins: every hull renders a capacity of 400. That is coincidentally right
  for the 327 ships whose true 1132 is `400.0` (for example Rifter 587) and
  wrong for the other 74 present-value ships (`350.0` Revenant 3514, `0.0`
  Reaper 588, `1.0` Caldari Shuttle 672, `300.0` Opux 635).
- `dogma_engine.dart:688-695` sums `calibration` over `Fitting.allModules`
  (high + medium + low + rigs + subsystems), silently skipping unknown types
  (`if (type == null) continue`) and offline modules. Only rigs contribute
  in practice because only rigs carry 1153.
- `dogma_engine.dart:1214-1222` emits only a diagnostic string
  (`Fitting exceeds calibration budget.`) when the sum passes the max.
- No display exists: `stats_panel.dart` has no calibration row, and
  `fitting_editor.dart:397-427` documents "CPU / Power Grid / Calibration
  text" but builds only the CPU and Power Grid readouts. No Flutter test
  asserts `calibrationUsed`, `calibrationMax`, or the diagnostic; the one
  calibration field test uses a synthetic `1153: 150.0` row for type 31716,
  whose real cache value is `50.0`.

Deliberate divergences (do not "fix" back to Flutter):

1. Capacity reads 1132 `upgradeCapacity`, never 1153, and there is no `400`
   fallback and no fallback of any kind: absent capacity is `Unavailable`
   (section 5), never an invented number.
2. Values stay `f64` end to end (`format_fitting_amount`); no `toInt()`
   truncation, no integer rendering.
3. Unknown rig costs are excluded with a disclosed count (section 4), never
   the Flutter silent `continue`, and never `?? 0`.
4. The used sum is a plain uncapped sum; over-capacity renders as a positive
   `(N over)` amount in red (section 6.2), not a diagnostic-only string and
   never a capped value.
5. Calibration is displayed, in both fitting details (section 6). Flutter's
   computed-but-hidden state is the gap this slice closes.
6. Rust `CharacterFitting` has no offline state and no subsystems in the rig
   sum: counting is driven by the `RigSlot` flag prefix alone (section 4),
   mirroring how `resources.rs:113-115` tests ESI flag prefixes itself
   instead of depending on module state or the UI section enum.

There is no Flutter synthesis trap for calibration (contrast the bay slice,
where Flutter's key 38 was synthesized `invTypes.volume`): both 1132 and
1153 are genuine dogma rows, and Flutter's 1153 read was a genuine read —
just used for the wrong side of the pair in the engine.

### 2.4 Which flags consume calibration (one rule, three fitting shapes)

The pure layer counts a fitting row toward calibration used exactly when its
ESI flag satisfies `flag.starts_with("RigSlot")`. Slot belonging is never
judged beyond the prefix — the `resources.rs` precedent
(`slot_flag_prefixes_consume_regardless_of_module`): any type under
`RigSlot*` contributes its `upgradeCost`, and a rig under any other flag
contributes nothing. Every other flag — `LoSlot*`, `MedSlot*`, `HiSlot*`,
`SubSystemSlot*`, `ServiceSlot*`, `DroneBay`, `FighterBay`, `Cargo`,
`Invalid`, `""`, and any unknown flag — neither counts nor excludes.

All three fitting shapes land on the same `CharacterFitting` before the pure
function runs, so there is one math path:

- **Saved (ESI):** `write_map.rs:76-82` lists `("RigSlot", 2)` in
  `SLOT_FLAGS`; `RigSlot0`–`RigSlot2` are the representable rig flags and
  each kept rig is forced to `quantity: 1` and de-duplicated by flag on the
  save path. A read-back saved fitting therefore carries rig rows at
  quantity 1. The pure layer still multiplies by whatever quantity a row
  carries (section 4), so a hostile or future stacked rig row is summed and
  counted honestly instead of assumed away.
- **EFT import:** `eft.rs` classifies a module line to `ImportSection::Rig`
  by slot effect 2663 and synthesises flags `RigSlot0`, `RigSlot1`, … in
  line order, one row per line at quantity 1; a stacked `Name xN` line on a
  rig is a `StackedModule` import issue, not a quantity.
- **DNA import:** `dna.rs` classifies by `slot_effects` and expands each
  `;quantity` segment into that many quantity-1 rows before
  `to_character_fitting` assigns `RigSlot0, 1, 2, …`. A DNA `;3` on a rig
  type therefore arrives as three rig rows.

Consequence: after synthesis no path carries a rig quantity above 1 today,
but the locked contract is the general multiply (section 4), and the test
plan pins a stacked rig row (section 8) so the rule cannot silently rot.

## 3. Catalogue extension

### 3.1 New keys and emission rules

The generator (`scripts/sde/generate_fitting_types_sde.py`) gains one
attribute family, mirroring the resource/base-stat/resonance/bay families
(lines 60–141, 379–524, 557–702 as read this session):

- Constants: `CALIBRATION_ATTR_IDS = {1132, 1153}`,
  `SHIP_CALIBRATION_ATTR = 1132`, `RIG_CALIBRATION_ATTR = 1153`, with a
  header comment citing the `dogmaAttributes.jsonl` names and `_key`s, unit
  120 `attributePoints` / `points` for 1132, the missing `unitID` for 1153,
  and the 560 decoy — the same provenance style as the bay block comment
  that names the 38/161 decoys.
- Scan loop: a fifth fail-loud pass over `dgmTypeAttributes` cloned from the
  existing four — duplicate (type, attribute) row fails, `float(valueFloat)`
  parse failure fails, non-finite fails, negative fails; nothing is written
  on any failure.
- Emission, additive and sparse, appended after the existing bay keys so the
  locked key order becomes `… droneBandwidthUsed, upgradeCapacity,
  upgradeCost` (each row gains at most one of the two new keys):
  - `upgradeCapacity` on a category-6 row exactly when a 1132 row exists for
    that type (present `0.0` emits as `0.0`; absent emits nothing — 401 rows
    emit, 3 do not).
  - `upgradeCost` on any row whose emitted `slotEffects` is `[2663]`
    exactly when a 1153 row exists (921 rows emit). The gate tests the slot
    effect, never `category_id == 7`.
  - Every other row is byte-identical to the current catalogue, and every
    emitted row is byte-identical up to the appended fragment.
- The run summary prints one new line,
  `calibration_keys upgradeCapacity=401 upgradeCost=921`, beside the
  existing `resource_keys` / `bay_keys` lines.

Loader (`src/names/fitting_types.rs`, after the bay fields at lines
106–117):

```rust
// Rig calibration (docs/rig-calibration-design.md section 3.1):
// dogma 1132 `upgradeCapacity` on category 6 rows and dogma
// 1153 `upgradeCost` on slot-effect-2663 (rig) rows, sparse.
#[serde(rename = "upgradeCapacity", default)]
pub upgrade_capacity: Option<f64>,
#[serde(rename = "upgradeCost", default)]
pub upgrade_cost: Option<f64>,
```

### 3.2 Size budget (costed)

Current `assets/sde/fitting_types.json`: 3,148,744 bytes. Simulating the
generator's exact output arithmetic (compact separators, `json.dumps` of the
parsed float): ship fragments add 9,560 bytes over 401 ships
(`,"upgradeCapacity":400.0` = 24 B dominant; the 20 present-zero ships emit
`,"upgradeCapacity":0.0`) and rig fragments add 18,048 bytes over 921 rigs.
Locked expectation: **+27,608 bytes → 3,176,352 bytes (+0.88%)**. A
regeneration whose byte delta differs from the sum of its new fragments, or
whose diff touches any existing key, is a defect (section 3.5).

### 3.3 Generator oracles

`CALIBRATION_ORACLES` mirrors `BAY_ORACLES` tuple shape
`(typeId, key, expected-or-None)` where `None` means the key must be absent
from that row. Every expected value is a hand-derived literal read from the
cache table in section 2.2, never built from the constants under test:

- Present capacity: `(587, "upgradeCapacity", 400.0)`,
  `(597, "upgradeCapacity", 400.0)`, `(3514, "upgradeCapacity", 350.0)`,
  `(635, "upgradeCapacity", 300.0)`, `(672, "upgradeCapacity", 1.0)`,
  `(588, "upgradeCapacity", 0.0)`.
- Explicit-zero pin, cloned from the 1355-power and 670-cargo pins: type 588
  must carry `upgradeCapacity` present as `0.0`, never absent.
- Absent capacity: `(670, "upgradeCapacity", None)`,
  `(2863, "upgradeCapacity", None)`, `(33328, "upgradeCapacity", None)`.
- Present cost: `(31668, "upgradeCost", 200.0)`,
  `(25736, "upgradeCost", 50.0)`, `(4395, "upgradeCost", 150.0)`,
  `(4399, "upgradeCost", 300.0)`,
  `(37146, "upgradeCost", 100.0)` (the category-66 gate pin — this oracle is
  the one that fails if the emission gate is cloned from the category-7
  module-need gate by mistake),
  `(37147, "upgradeCost", 150.0)`.
- Cross-key absence: `(587, "upgradeCost", None)`,
  `(31668, "upgradeCapacity", None)`, `(37146, "upgradeCapacity", None)`,
  `(2048, "upgradeCost", None)` (a slot module carries neither key),
  `(35825, "upgradeCapacity", None)` (the category-65 structure pin — the
  cache carries 1132 `400.0` for Raitaru and the category-6 gate must drop
  it).

### 3.4 Invariants (generator self-validation and loader test)

Both the generator's catalogue-wide validation loop and the loader's
`bundled_catalogue_invariants` test assert, for every catalogue row:

1. Every present `upgradeCapacity` / `upgradeCost` value is finite and
   `>= 0.0`.
2. `upgradeCapacity` appears only on category-6 rows. **Absence on a ship is
   allowed** (670, 2863, 33328) — deliberately *not* the every-ship rule the
   CPU/power outputs carry, because those three hulls genuinely have no
   1132 row. Requiring presence would fail a correct catalogue.
3. `upgradeCost` appears only on rows with `slotEffects == [2663]`, and
   **every** such row carries it: all 921 cache rigs carry 1153, so a future
   cache refresh that drops a rig cost must fail loudly here instead of
   turning that rig into a permanent excluded count.
4. No row carries both keys (implied by 2 and 3 together — no row is both
   category 6 and slot-effect 2663 — and asserted anyway so a gate bug
   cannot pass silently).

Loader spot pins beside the existing ones in `bundled_catalogue_invariants`,
same literals as section 3.3: Rifter 587 `upgrade_capacity == Some(400.0)`,
Reaper 588 `Some(0.0)`, Capsule 670 `None`, rig 31668
`upgrade_cost == Some(200.0)` and `upgrade_capacity == None`, structure rig
37146 `upgrade_cost == Some(100.0)`, Raitaru 35825
`upgrade_capacity == None`. The pre-existing rig pin (`31668.cpu/power ==
None`) stays untouched.

### 3.5 Determinism proofs (Builder A, same commit as the catalogue)

1. Re-running `python3 scripts/sde/generate_fitting_types_sde.py` on the
   committed tree produces a byte-identical `assets/sde/fitting_types.json`
   (`git status` clean afterwards) and prints the locked counts
   (`calibration_keys upgradeCapacity=401 upgradeCost=921`).
2. The catalogue diff against the pre-slice file touches only appended
   `upgradeCapacity` / `upgradeCost` fragments: 3,148,744 → 3,176,352 bytes
   (+27,608), no existing key changed, no row reordered. Builder A states
   the observed byte counts in the commit body; a mismatch blocks the
   commit, it is not explained away.

## 4. Pure API

**Decision: a new module `src/fitting/calibration.rs`, not an extension of
`resources.rs`.** Justified from the bodies:

- `FittingResources::Available { cpu, power }` is gated on *both* outputs
  being usable (`resources.rs:152-157`); adding calibration there would make
  calibration disappear whenever CPU or power output data is unusable, and
  would make CPU/power disappear for the three capacity-absent hulls if the
  gate grew — availability must be independent (section 5).
- `fitting_resources_with_skills` exists to scale outputs by skills; no
  calibration skill exists in this slice. Folding calibration into that
  function or its result would invite a false "with skill bonuses" reading
  (the resources heading literally changes to say so when levels are
  loaded).
- `ResourceBudget` names its capacity field `output` (`resources.rs:79-86`).
  Dogma names this value `upgradeCapacity`; calling it an output misnames
  it. The bay slice faced the same misnaming and shipped its own
  `BayBudget { capacity }` in its own module instead of reusing
  `ResourceBudget` (`bay_usage.rs:31-52`). Calibration follows that shipped
  precedent.
- The cost of a module is the small duplication of `usable()` and the
  ship-resolution gate — duplication `bay_usage.rs` already carries and that
  keeps each pure function independently testable at render cadence.

Locked shape:

```rust
/// Base rig calibration for one fitting: plain rig-cost sum over
/// counted rig-slot rows against the hull's base calibration.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CalibrationBudget {
    pub used: f64,
    pub capacity: f64,
    /// Rig-slot rows with no usable cost (absent from the
    /// catalogue, no cost row, or an unusable value). Counted
    /// in quantity units, never silently zero.
    pub excluded_rigs: usize,
}

impl CalibrationBudget {
    pub fn remaining(&self) -> f64;  // capacity - used
    pub fn is_over(&self) -> bool;   // used > capacity
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CalibrationOutcome {
    Available(CalibrationBudget),
    /// The catalogue has no usable calibration data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

pub fn rig_calibration(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> CalibrationOutcome;
```

Exported from `src/fitting/mod.rs` exactly as `bay_usage` is:
`pub use calibration::{rig_calibration, CalibrationBudget, CalibrationOutcome};`

Counting rules, each cloned from the named shipped line:

1. Ship resolution (`resources.rs:141-157` shape): `ship_type_id > 0`, the
   row resolves via `lookup_by_id`, `category_id == 6`, and
   `usable(ship.upgrade_capacity)` is `Some` — else `Unavailable`. There is
   no partial state: calibration has one dimension, so there is no per-bay
   `None` pattern to copy from bays.
2. `usable(value)` is the shared rule verbatim (`resources.rs:120-122`):
   present, finite, `>= 0.0`. A present `0.0` is a real zero on both sides:
   a `0.0`-capacity hull is `Available`, and a `0.0`-cost rig counts and
   excludes nothing. Negative, NaN, and infinite catalogue values are no
   data (the generator and loader already forbid them; the pure layer
   defends anyway, as the twins do).
3. Per item: skip unless `type_id > 0 && flag.starts_with("RigSlot")`
   (`resources.rs:213-215` shape); `quantity = quantity.max(0)`, skip when 0
   (so quantity 0 and negative quantities neither count nor exclude);
   `used += quantity as f64 * cost` when the catalogue row resolves and its
   `upgrade_cost` is usable; otherwise
   `excluded_rigs = excluded_rigs.saturating_add(quantity_units)` with
   `quantity_units = usize::try_from(quantity).unwrap_or(0)` — excluded
   counts rigs, not rows, matching the multiplied sums
   (`resources.rs:180-188`).
4. Hostile values: a `RigSlot` row at `quantity = i64::MAX` multiplies in
   `f64` and stays finite (`(i64::MAX as f64) * 300.0` is about 2.8e21),
   reporting over — the twin's
   `huge_quantity_stays_finite_and_reports_over` behaviour. Excluded counts
   saturate, never wrap. Ship `type_id` 0, negative, unknown, or category ≠ 6
   is `Unavailable`.
5. The function is pure and logs nothing: no egui, no state, no network, no
   database, and no `[FITTING]` lines — it runs at render cadence, and the
   catalogue load already logs counts once (the `bay_usage.rs` module-doc
   rule). The module doc names sources (dogma 1132/1153, unit `points`, the
   Flutter wrong-attribute bug) and this design file, mirroring the twin
   module docs.

## 5. Availability

Calibration availability depends only on the ship's `upgradeCapacity` —
never on CPU/power output data, bay capacity data, skill loading, or the
fitting's items. The four blocks keep rendering side by side in every
combination:

- The three capacity-absent hulls (670 Capsule, 2863 Primae, 33328) show the
  calibration unavailable sentence while the resources block still shows
  numbers — every category-6 row carries both CPU and power outputs by the
  loader invariant (`fitting_types.rs:427-432`), Primae included. Rifter's
  Calibration numbers and a Capsule's CPU numbers are independent facts.
- The reverse combination (calibration present, resources unavailable)
  cannot occur on the bundled catalogue — every ship carries both outputs —
  but the pure functions do not know that, and a fixture-catalogue test pins
  the independence anyway (section 8) so a future catalogue change cannot
  couple them.
- A fitting with no items, or no rig rows, still renders the block:
  `0.0 of {capacity}` used, exactly as `render_fitting_resources` renders an
  empty fitting.
- Catalogue load failure renders the no-catalogue sentence under the
  calibration heading, the same shape every block uses; the heading always
  renders so the view never silently omits the feature.

## 6. UI

### 6.1 Placement: its own block, directly after Fitting resources

**Decision: calibration gets its own block** — its own heading, disclosure,
and unavailable sentences — rendered immediately after the
`render_fitting_resources` block and before `render_bay_usage`, at both
detail sites. Not a third line inside the resources block. Justified from
the bodies:

- The resources block is skill-aware: with loaded skills its heading becomes
  `Fitting resources (with skill bonuses)`, two skill lines render, and the
  applied disclosure replaces the base one (`fittings.rs:1304-1336`). A
  calibration line inside that block would sit under a "with skill bonuses"
  heading and an applied disclosure while no skill touches it — a false
  claim by placement. Keeping it outside keeps every claim in the resources
  block true byte-for-byte.
- Availability is independent (section 5). Inside the resources block, the
  `ShipNoOutput` arm renders one unavailable sentence and no lines
  (`fittings.rs:1300-1303`); a nested calibration would need a second,
  differently-worded unavailable state inside both the base and applied
  arms — the exact coupling the bay block avoided by shipping as its own
  block with its own heading (`Bays (base values)`).
- The bay block is the shipped precedent for a no-skills fitting block:
  `render_bay_usage(ui, fitting, fitting_types)` takes no skill levels and
  no SDE handle and renders identically for every viewing character
  (`fittings.rs:1665-1692`). Calibration takes the same signature.
- Placement after resources and before bays groups the three *fitting
  constraint* checks (CPU, power grid, calibration — the numbers that answer
  "does this fit?") ahead of the *storage* check (bays) and the bare-hull
  blocks (ship values, resistances, effective hit points). Locked detail
  order at both sites: items → Fitting resources → Rig calibration → Bays →
  Ship → Ship resistances → Ship effective hit points.

Locked wiring (the only two call sites, mirroring how every block is added):

- Imported detail: `render_rig_calibration(ui, &synth, fitting_types);`
  directly after the `render_fitting_resources(...)` call at
  `fittings.rs:1818` and before `render_bay_usage` at `:1819`.
- Saved detail: `render_rig_calibration(ui, selected, fitting_types);`
  directly after the `render_fitting_resources(...)` call at
  `fittings.rs:2108` and before `render_bay_usage` at `:2109`.

Signature, mirroring `render_bay_usage`:
`fn render_rig_calibration(ui: &mut egui::Ui, fitting: &CharacterFitting,
fitting_types: Option<&FittingTypes>)`. It renders even when the fitting has
no items and logs nothing (render cadence). Constants live with the other
blocks' constants in `fittings.rs`, named in their style:
`FITTINGS_CALIBRATION_HEADING`, `FITTING_CALIBRATION_DISCLOSURE`,
`FITTING_CALIBRATION_NO_CATALOGUE`, `FITTING_CALIBRATION_NO_SHIP_DATA`.

### 6.2 Verbatim templates

Heading (always renders, including over an unavailable sentence):

```text
Rig calibration (base values)
```

One line, via a pure `calibration_line(budget: &CalibrationBudget) -> String`
cloned from `resource_line` / `bay_line` (label `Calibration`, unit
`points`, `widgets::format_fitting_amount` for every amount):

- Under capacity: `Calibration: {used} of {capacity} used ({remaining} left)`
  — for example `Calibration: 200.0 points of 400.0 points used (200.0 points left)`.
- Exactly at capacity: remaining is `0.0`, normal colour — for example
  `Calibration: 400.0 points of 400.0 points used (0.0 points left)`.
- Over capacity: `Calibration: {used} of {capacity} used ({over} over)` with
  a positive overage — for example at 300.0 + 150.0 against 400.0,
  `Calibration: 450.0 points of 400.0 points used (50.0 points over)` —
  rendered with `ui.colored_label(egui::Color32::LIGHT_RED, line)` exactly as
  the resource and bay over lines are. `is_over()` is the only red trigger;
  excluded lines are never red.

Excluded line, via a pure `calibration_excluded_line(excluded: usize) ->
Option<String>` cloned from `cpu_excluded_line` (the counted section is the
item list's `Rigs` section, `fittings.rs` `section_for_flag`, so the noun is
"fitted rig" as resources use "fitted module" for their counted sections):

- `0` → no line.
- `1` → `Calibration does not count 1 fitted rig with no calibration cost data in Mimir's bundled item data.`
- `n >= 2` → `Calibration does not count {n} fitted rigs with no calibration cost data in Mimir's bundled item data.`

Disclosure (one sentence pair, always under an available block, naming what
is not applied — this block's own constant, never the resources constant,
even where words coincide):

```text
Base rig calibration costs against the ship's base calibration, from Mimir's bundled item data. Skills, implants, and bonuses from modules, rigs, subsystems, and the ship itself are not applied, so these numbers can differ from EVE.
```

Unavailable sentences (heading still renders above each; no numbers, no
disclosure under either):

```text
Rig calibration unavailable: Mimir's bundled item data failed to load.
Rig calibration unavailable: Mimir's bundled item data has no calibration data for this fitting's ship.
```

Render order inside the block: heading → calibration line → excluded line
(when present) → disclosure. No skill lines exist in this block in any
state, and the block's output for a given fitting and catalogue is identical
regardless of the viewing character's skills — a pinned test (section 8).

## 7. Demo story (hand-derived from quoted rows)

All inputs from the committed `assets/demo/fittings.json` (read this
session) and the in-code samples in `src/ui/fittings.rs`; capacities and
costs quoted in section 2.2 (587 Rifter capacity 400.0; 597 Punisher
capacity 400.0; 31668 Small Projectile Burst Aerator I cost 200.0). Demo
data is not modified by this slice.

Ship capacities and costs below are the section 2.2 literals; the arithmetic
is written out, and no expected value is built from any constant under test:

Character 90000001, "Demo Brawler" (fitting 1, 587 Rifter, selected):

- Rig rows: one — `RigSlot0`, quantity 1, type 1535. Type 1535 has no row in
  `invTypes` and no row in the catalogue at all (verified this session: no
  `invTypes` match, no 1132 row, no 1153 row), so it contributes nothing to
  used and 1 to excluded. It is the demo's built-in unknown-cost exhibit for
  this block; Builder B must not "fix" the type id.
- Calibration: used = 0.0, capacity = 400.0, remaining = 400.0 − 0.0 =
  400.0, excluded 1, not over. Renders
  `Calibration: 0.0 points of 400.0 points used (400.0 points left)` plus
  the singular excluded line.
- The other eleven items (`LoSlot0` 2048, `MedSlot0` 2049, `MedSlot1` 1225,
  `HiSlot0/1` 2050, `SubSystemSlot0` 28270, `DroneBay` 2456 ×5, `FighterBay`
  2457 ×2, `Cargo` 34 ×500, `Cargo` 636 ×200, `Invalid` 35 ×2) neither
  count nor exclude — including type 636, the bay block's unknown-volume
  exhibit, which sits under `Cargo` and so is invisible to calibration.

Character 90000001, "Mission Runner" (fitting 2, 587 Rifter):

- No `RigSlot*` rows. Calibration: used = 0.0 of 400.0 (400.0 left),
  excluded 0. Renders the plain line with no excluded line — a real zero
  against a present capacity, not a missing block.

Character 90000002, "Demo Runner" (fitting 10, 597 Punisher):

- No `RigSlot*` rows. Calibration: used = 0.0 of 400.0 (400.0 left),
  excluded 0.

Sample EFT import (`DEMO_SAMPLE_EFT`, [Rifter, Sample Brawler], through
synthesis):

- Rig rows after synthesis: `RigSlot0` Small Projectile Burst Aerator I
  (31668) ×1; the `[Empty Rig slot]` line is a placeholder and synthesises
  no row. Calibration: used = 1 × 200.0 = 200.0 of 400.0, remaining =
  400.0 − 200.0 = 200.0, excluded 0. Renders
  `Calibration: 200.0 points of 400.0 points used (200.0 points left)`.

Sample DNA import (`DEMO_SAMPLE_DNA` =
`587:2048:1183;1:438;1:448;1:2889;3:31668;1::`, through synthesis):

- The `31668;1` segment expands to one rig row. Calibration: used =
  1 × 200.0 = 200.0 of 400.0 (200.0 left), excluded 0 — identical to the
  sample EFT, as the two samples fit the same rig.

The demo therefore exhibits the counted case (both samples), the
no-rigs real-zero case (two saved fittings), and the unknown-cost excluded
disclosure (Demo Brawler). It has no over-capacity, zero-capacity, or
capacity-absent exhibit; those are covered by pure/UI tests against the
bundled catalogue and fixture catalogues (section 8).

## 8. Test plan

Standing rule for every test below: expected numbers are hand-derived
literals with the arithmetic written in comments, read from the section 2.2
cache table — never built from the constants under test
(`CALIBRATION_ATTR_IDS`, catalogue keys, or a second call into the code
under test). Gates at every commit: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build`.

Generator and catalogue (Builder A):

1. The generator run passes with the section 3.3 `CALIBRATION_ORACLES`, the
   588 explicit-zero pin, and the section 3.4 invariants; a hands-on
   corruption check (temporarily flip one oracle literal) confirms the run
   fails loudly and writes nothing.
2. Determinism proofs 3.5 (byte-identical re-run; +27,608 bytes; counts line
   `upgradeCapacity=401 upgradeCost=921`).

Loader (`src/names/fitting_types.rs` tests, Builder A):

3. `bundled_catalogue_invariants` gains the section 3.4 per-row assertions
   and the spot pins 587 `Some(400.0)`, 588 `Some(0.0)`, 670 `None`, 31668
   `Some(200.0)` / capacity `None`, 37146 `Some(100.0)`, 35825 `None`.

Pure layer (`src/fitting/calibration.rs` tests, Builder A; bundled catalogue
plus `FittingTypes::from_json` fixtures, the `resources.rs` test shape):

4. Hull only, Rifter 587 with no items: used 0.0, capacity 400.0, remaining
   400.0, excluded 0, not over.
5. One counted rig: 587 + `RigSlot0` 31668 ×1 → used = 1 × 200.0 = 200.0 of
   400.0, remaining 200.0, excluded 0, not over.
6. Exactly at capacity: 587 + `RigSlot0` 31668 ×1 + `RigSlot1` 4395 ×1 +
   `RigSlot2` 25736 ×1 → used = 200.0 + 150.0 + 50.0 = 400.0 of 400.0,
   remaining 0.0, excluded 0, `is_over() == false`.
7. Over capacity: 587 + `RigSlot0` 4399 ×1 + `RigSlot1` 4395 ×1 → used =
   300.0 + 150.0 = 450.0 of 400.0, remaining −50.0, `is_over() == true`.
8. Present-zero capacity: 588 Reaper with no items → `Available`, 0.0 of
   0.0, not over; 588 + `RigSlot0` 31668 ×1 → 200.0 of 0.0, over. (A
   `0.0`-capacity hull must never come back `Unavailable`.)
9. Absent capacity: 670 Capsule, 2863 Primae, 33328 with any items (rigs
   fitted included) → `Unavailable`.
10. Non-400 capacities (the Flutter-fallback tripwire): 3514 Revenant hull
    only → 0.0 of 350.0; 635 Opux hull only → 0.0 of 300.0; 672 Caldari
    Shuttle + `RigSlot0` 25736 ×1 → 50.0 of 1.0, over. Any hidden `400`
    fallback fails these literally.
11. Unknown and dataless rig rows are excluded, never zeroed: 587 with
    `RigSlot0` 999999 (absent from the catalogue) ×1 → used 0.0, excluded 1;
    `RigSlot1` 2048 (catalogue row, no cost) ×1 → excluded 2 total; a
    stacked unknown `RigSlot0` 999999 ×5 → excluded 5 (rigs, not rows).
12. Flag discipline: 31668 under each of `LoSlot0`, `MedSlot0`, `HiSlot0`,
    `SubSystemSlot0`, `DroneBay`, `FighterBay`, `Cargo`, `Invalid`, `Foo`,
    `""` → used 0.0, excluded 0; 2048 under `RigSlot3` (out of ESI range but
    prefix-true) → excluded 1 (prefix rule, slot belonging never judged);
    999999 under `Cargo` → excluded 0.
13. Quantity: 587 + `RigSlot0` 31668 quantity 2 → used = 2 × 200.0 = 400.0;
    quantity 0 and −5 → used 0.0, excluded 0; `type_id` 0 and −1 under
    `RigSlot0` → used 0.0, excluded 0; `RigSlot0` 31668 quantity `i64::MAX`
    → used finite, `is_over() == true`, excluded 0.
14. Ship failures: `ship_type_id` 999999 (absent), 2048 (category 7), 31668
    (a rig, category 7), 35825 (category 65 — its cache 1132 `400.0` must
    never surface), 0, −1 → all `Unavailable`.
15. Structure-rig cost counts through the pure path: 587 + `RigSlot0` 37146
    ×1 → used = 100.0, excluded 0 (the category-66 emission, end to end).
16. Fixture defences (small `from_json` catalogues): capacity present as
    `Some(0.0)` counts as data; capacity negative or absent →
    `Unavailable`; a fixture rig row with `upgradeCost` 0.0 counts and
    excludes nothing; a fixture rig row with no cost key excludes. (JSON
    cannot carry NaN/inf; non-finite stays a generator-side reject.)
17. Independence fixture: a category-6 fixture row with `upgradeCapacity`
    present and no `cpuOutput`/`powerOutput` → `rig_calibration` is
    `Available` while `fitting_resources` on the same fixture is
    `ShipNoOutput`; and the bundled Primae 2863 → calibration `Unavailable`
    while `fitting_resources` is `Available`.
18. Synthesis paths: the sample EFT text (one rig 31668) through `parse_eft`
    → 200.0 of 400.0, excluded 0; a DNA string `587:31668;2::` through
    `parse_import` (expands to two rig rows) → used = 2 × 200.0 = 400.0 of
    400.0, not over.

UI (`src/ui/fittings.rs` tests, Builder B; the shipped pure-line test shape
used for `resource_line` / bay lines):

19. Line templates verbatim: under → `Calibration: 200.0 points of 400.0 points used (200.0 points left)`;
    at → `Calibration: 400.0 points of 400.0 points used (0.0 points left)`;
    over → `Calibration: 450.0 points of 400.0 points used (50.0 points over)`
    with the over flag true; excluded lines at 0 (none), 1 (singular), 2
    (plural) verbatim from section 6.2.
20. Constants pinned verbatim: heading, disclosure, and both unavailable
    sentences equal the section 6.2 strings.
21. Demo pins (section 7) over the real demo bundle and both samples:
    Demo Brawler 0.0 of 400.0 with excluded 1 and the singular line;
    Mission Runner and Demo Runner 0.0 of 400.0, excluded 0;
    `DEMO_SAMPLE_EFT` and `DEMO_SAMPLE_DNA` each 200.0 of 400.0, excluded 0.
22. Existing-blocks regression: the pre-slice UI line tests for resources,
    bays, ship values, resistances, and effective hit points pass unchanged,
    and the resources block output for a fixed fitting+skills input is
    byte-identical before and after the calibration block lands beside it.

## 9. Integrator list

- `README.md`: the Fittings bullet gains one calibration sentence beside the
  existing CPU/power grid and bay sentences, naming base values, the
  unapplied skill/implant/module/rig/subsystem/ship bonuses, the
  excluded-with-count rule, and that numbers can differ from EVE. Draft
  (fits the paragraph's voice; final wording is the integrator's): "The same
  details also show rig calibration used against the ship's base
  calibration, as plain sums of base rig calibration costs from that bundled
  data, with skills, implants, and bonuses from modules, rigs, subsystems,
  and the ship itself not applied, so these numbers can also differ from
  EVE; rigs whose calibration cost is not in the bundled data are left out
  of the sum with a disclosed count, never counted as zero." The "no DPS
  numbers … no adjusted (fitted) fitting totals" sentence stays true and
  unchanged (calibration is a base-value budget, not a fitted total).
- `docs/engineering-journal/LEARNINGS.md`: dated entry for the Flutter
  capacity bug (engine read the rig-cost attribute 1153 as the ship
  capacity, so a magic `400` fallback silently won on every hull and the
  value was never displayed, so nobody saw it), with Evidence
  (`ed698d3` file+line and cache counts from section 2), Mechanism, and the
  generalizable rule (an attribute used for both sides of a used/capacity
  pair hides a wrong-side read behind its own fallback; pin a non-modal
  capacity value — 350.0/1.0/0.0 — as the oracle, since the modal 400.0
  cannot distinguish truth from fallback).
- `docs/engineering-journal/DECISIONS.md`: dated entry only if the
  integrator judges a durable decision was made; candidates are (a) new
  `calibration.rs` module over extending `resources.rs` (rationale in
  section 4; rejected: third field on `FittingResources`), and (b)
  effect-2663 emission gate over the category-7 gate (rationale in section
  2.2; rejected: cloning the module-need gate, which drops 279 structure
  rigs). Each with rejected alternatives and a revisit condition, per the
  journal practice.
- This design file is the design commit; no other docs move in builder
  commits. No `docs/HANDOFF.md` or spec change is required by this slice.
  Final verification (integrator): full gate run on the final tree plus a
  demo smoke of both detail views against section 7.

## 10. Exclusions (explicitly not in this slice)

- **Skill modifiers** of every kind: no skill scales the capacity or reduces
  a rig cost here, and the CPU Management 3426 / Power Grid Management 3413
  scaling in `resources.rs` is untouched and never feeds calibration. The
  block renders identically with or without loaded skills.
- **Implant, module, rig, subsystem, and ship-bonus modifiers** of every
  kind, including any effect that raises a hull's calibration or reduces a
  rig's calibration cost (**calibration-reduction effects** are out by
  name): base dogma 1132 and 1153 values only, exactly as shipped CPU/power
  grid *needs* are base-only. The disclosure (section 6.2) says so.
- Structure fitting: category-65 hulls are never ship-resolved and their
  1132 rows are never emitted; category-66 structure rigs carry emitted
  costs only so an imported structure-rig row counts honestly — no structure
  capacity display of any kind.
- Rig count limits, rig slot counts, and any "too many rigs" validation:
  this slice sums calibration; slot representability stays with
  `write_map.rs` and the importers.
- Any editor or write-path change; any ESI, scope, storage, or demo-data
  change. Imported fittings get calibration numbers only through the
  existing synthesis to `CharacterFitting`.
- CPU/power grid, bays, ship stats, resistances, and effective hit points:
  byte-untouched, including their headings, disclosures, and unavailable
  sentences.

## 11. Ownership and commit split

Small atomic commits, `type(scope): description`, no attribution lines.
Nothing is pushed or merged by builders; the parent does that. Gates at each
commit: `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`. This slice adds no new log lines: the pure
function and render function log nothing (render cadence), the generator's
new `calibration_keys` line is a build-script print, not an app log, and no
user text or token is ever logged. UI text shows resolved names and
disclosed counts only — never a raw EVE id as a number on screen (type ids
appear only inside tests and this document).

1. **Design (this commit):** `docs(calibration): design rig calibration` —
   only `docs/rig-calibration-design.md`.
2. **Builder A — data and pure layer.** Owns exactly:
   `scripts/sde/generate_fitting_types_sde.py`,
   `assets/sde/fitting_types.json` (regenerated, never hand-edited),
   `src/names/fitting_types.rs` (two loader fields + invariants + pins),
   `src/fitting/calibration.rs` (new, with its tests), and the
   `src/fitting/mod.rs` export lines. Split as (a) generator + catalogue
   with the section 3.5 proofs stated in the commit body, (b) loader + pure
   module. Suggested messages: `feat(calibration): emit calibration keys in
   fitting catalogue`, then `feat(calibration): add pure rig calibration
   calculation`. Builder A touches no file under `src/ui/` and no demo data.
3. **Builder B — rendering and demo pins.** Owns exactly
   `src/ui/fittings.rs`: the four constants, `calibration_line`,
   `calibration_excluded_line`, `render_rig_calibration`, the two call sites
   (section 6.1), and the section 8 UI tests (19–22) including the
   section 7 demo pins — which read the committed demo data but modify none
   of it. Suggested message: `feat(calibration): show rig calibration in
   fitting details`. Builder B touches no generator, catalogue, loader, or
   pure-module file. Depends on Builder A's locked section 4 API
   (`rig_calibration`, `CalibrationBudget { used, capacity, excluded_rigs }`,
   `CalibrationOutcome`); any needed API change goes back through this
   design in its own commit, never a silent rendezvous edit.
4. **Integrator:** README + engineering journal (section 9), final full gate
   run, the section 7 demo smoke of both detail views, and confirmation that
   the existing blocks stayed byte-identical (test 22).





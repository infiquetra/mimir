# Base active repair — design

Status: locked for the `feat/rust-sustained-tank` slice. Base:
`develop` at `35a37a4` (merge of the capacitor-stability slice,
[#600](https://github.com/infiquetra/mimir/pull/600)), clean, 863
tests (stated at slice start; this design commit re-runs the
section 8 gates). Slice branch: `feat/rust-sustained-tank`.
Discovery: two read-only reports — the retired Flutter tank math
at `ed698d3` (full-body reads of `dogma_attributes.dart`, the
`dogma_engine.dart` repair block, `models.dart`, the E2 test
group in `dogma_engine_test.dart`, `damage_pattern.dart`,
`stats_panel.dart`) and the Rust repair data seams (committed
Fuzzwork caches, pinned SDE zip, shipped catalogue, demo
fittings, all scripted). During design, every count, per-type
value, effect name, and byte figure below was re-derived by
script from `scripts/sde/dgmTypeAttributes.csv.bz2`,
`scripts/sde/dgmTypeEffects.csv.bz2`,
`scripts/sde/eve-online-static-data-3503375-jsonl.zip`,
`assets/sde/fitting_types.json`, and
`assets/demo/fittings.json`, and the current Rust seams
(`src/fitting/ship_cap_stability.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`src/ui/widgets.rs`,
`scripts/sde/generate_fitting_types_sde.py`) were read
directly. No EVE formula here is recalled.

**Grounded verdict up front:** raw active repair per second
(repair amount per cycle divided by cycle seconds, summed per
hit-point layer) is grounded end to end and ships.
Resistance-applied "effective" tank per second (raw repair
divided by a resistance factor, in effective hit points —
EHP — per second) is **not grounded by any inspected body and
ships nothing** (section 2.4): no Flutter body divides a
repair rate by a resistance or resonance, the Flutter
after-action report's sustained-repair label is the literal
string `"Not modeled"`, and the shipped Rust EHP module
divides buffer hit points only. This slice therefore shows
raw base hit points restored per second per layer, labelled
active repair, with the resistances-not-applied fact in the
disclosure. It is the slice the issue calls "sustained
tank"; the on-screen name is deliberately narrower, because
the grounded rate is Flutter's while-cycling rate (its own
comment calls it burst hit points per second), ancillary
reload time is not averaged into it, and whether the
capacitor can sustain continuous cycling is the shipped
Capacitor block's statement (#600), not re-simulated here.

## 1. Goal and value ranking

Show, for the selected saved fitting and for the imported
fitting in the Fittings view, the base active repair the
fitted self-repair modules (shield boosters, armor
repairers, hull repairers) would restore per second while
cycling, per hit-point layer: shield, armor, hull.

Value ranking (locked, in order):

1. **Never a tank number without its assumptions on
   screen.** Base values, every counted repair module
   cycling continuously, resistances not applied, ancillary
   modules at their unloaded amount with reload time not
   modelled, remote repairers not counted, and a disclosed
   count of repair modules whose base repair data is
   missing. A bare "tank: 61 HP/s" that reads like an
   in-game sustained figure is the failure this slice
   exists to avoid.
2. **Grounded math only.** The formula is Flutter's,
   quoted in section 2; every input is a base catalogue
   value section 3 names. Anything ungrounded (effective
   repair, reload-averaged ancillary rates, loaded-charge
   multipliers — sections 2.4, 9) ships nothing rather
   than an approximation.
3. **Reuse.** The cycle attribute already ships (#600);
   mirror the shipped pure-module shape, slot-flag gate,
   excluded-with-count rule, generator extension pattern,
   effect-marker pattern, and formatter of the damage per
   second (DPS) and capacitor-stability slices.

## 2. Repair math (locked — replicate Flutter at base values)

### 2.1 Per-module rate and per-layer sum

Flutter `dogma_engine.dart` at `ed698d3`, repair block
(lines 752–777, read in full during discovery):

```dart
// Burst HP/s uses raw duration (73), not duration+reactivationDelay.
final repairDurationMs = moduleAttr(type, DogmaAttributes.duration);
if (repairDurationMs > 0) {
  final effectIds = type.effects.map((e) => e.effectId).toSet();
  if (effectIds.any(_armorRepairEffects.contains)) {
    var amount = moduleAttr(type, DogmaAttributes.armorRepairAmount);
    // (Nanite Repair Paste multiplier branch — section 2.3)
    armorRepairHps += amount / (repairDurationMs / 1000);
  } else if (effectIds.any(_shieldBoostEffects.contains)) {
    shieldBoostHps +=
        moduleAttr(type, DogmaAttributes.shieldBoostAmount) /
        (repairDurationMs / 1000);
  } else if (effectIds.any(_hullRepairEffects.contains)) {
    hullRepairHps +=
        moduleAttr(type, DogmaAttributes.hullRepairAmount) /
        (repairDurationMs / 1000);
  }
}
```

with effect routing (lines 72–74):

```dart
static const Set<int> _armorRepairEffects = {27, 5275};
static const Set<int> _shieldBoostEffects = {4, 4936};
static const Set<int> _hullRepairEffects  = {26};
```

Locked port at base values, per fitted module unit:

```text
rate (HP/s) = base repair amount / (base duration in milliseconds / 1000)
```

summed (`+=`, as in the body) into the layer its effect
routes to. The family's amount attribute and the cycle
attribute are locked in section 3. Flutter's `moduleAttr`
applies ship, skill, and module bonuses to both amount and
duration; that pipeline is **not** ported. At base values
the bonuses are absent, which is exactly why the base-pure
Flutter test oracles (section 8, E2.1–E2.4) transfer and
the bonus oracles (E2.6, E2.7) do not. Flutter checks armor
first, then shield, then hull (the `else if` chain above);
the port keeps that priority for any hypothetical
multi-effect type (zero exist in the shipped data,
section 3). Repairs land at the start or end of a cycle in
game depending on family; no inspected body uses that
timing in a rate, and a per-second average does not need
it, so no timing term exists. There is no combined
all-layers total: Flutter stores three separate fields
(`effectiveShieldBoost`, `effectiveArmorRepair`,
`effectiveHullRepair` — `models.dart:194–223`; "effective"
there means bonus-adjusted, never resistance-adjusted),
hit-point layers repair independently, and a summed total
would add shield hit points to armor hit points as if the
layers were one pool. Section 5's shape has no total field
to render.

### 2.2 Cycle: raw duration only — reload is never added

The cycle is base `duration` (73) and nothing else.
Flutter's comment says so in words ("Burst HP/s uses raw
duration (73), not duration+reactivationDelay"), and its
E2.3 oracle proves it: the Small Ancillary Armor Repairer
fixture carries a 60,000 ms reactivation delay and still
expects `52.0 / 6.0 = 8.667 HP/s`, not `52.0 / 66.0`. This
is the deliberate opposite of the capacitor slice, whose
cycle **does** add a present `reloadTime` (1795) because
Flutter's capacitor drain does (`dogma_engine.dart:697–713`;
`docs/cap-stability-design.md` section 3). The two cycles
are different because the two Flutter bodies are different;
nobody "harmonises" them.

Consequence, locked into the disclosure (section 6): for
charge-fed (ancillary, "fueled") modules the shown rate is
the rate while cycling, not a long-run average over clips
and the 60-second reload. No inspected body computes a
reload- or clip-averaged repair rate — the capacitor
simulator's words are "clips are treated as infinite — a
stocked-boosters assumption" (`cap_simulator.dart:70–71`)
with "no reload time to add" (line 164) — and no Rust
fitting shape holds a loaded charge count, so that average
cannot be grounded today and ships nothing (section 9).
Attribute 51 `speed` is never a repair cycle: scripted over
the caches during discovery and re-checked at design time,
0 of the 356 catalogue repair types (self plus remote)
carry it. The capacitor slice's 73-else-51 fallback does
not carry over.

### 2.3 Ancillary modules: unloaded (dry) amounts only

Ancillary armor repairers (effect 5275) repair at their
base amount unloaded, and at `base amount ×
chargedArmorDamageMultiplier` (1886, value 3.0 on every
shipped holder) when loaded with Nanite Repair Paste
(charge type 28668). That loaded branch is the only
charge-dependent repair branch in Flutter (E2.3: 8.667 HP/s
unloaded, 26.0 HP/s loaded, `52.0 × 3.0 / 6.0`). Ancillary
shield boosters (effect 4936) have **no** charge branch in
Flutter at all: their hit points per second are identical
loaded or unloaded in the body.

Locked: **this slice ships dry amounts on every surface.**
Attribute 1886 is never emitted or read, exactly as the
capacitor slice never emits `capacitorBonus` (67). Three
grounded reasons:

- Saved fittings carry no module-to-charge pairing (a
  loaded paste charge sits as unlinked cargo), DNA links
  likewise; only imported EFT (EVE Fitting Tool format)
  text pairs a charge with its module (`ImportedItem.charge`,
  `src/fitting/eft.rs`). The capacitor slice already faced
  this fork for booster injectors and locked "ship nothing
  rather than branch saved-versus-imported meaning on the
  same labelled line" (`docs/cap-stability-design.md`
  section 9). The DPS slice (#598) did take the EFT-only
  path, but only because a turret has no damage at all
  without its listed charge; an ancillary repairer has an
  honest base repair amount with no charge listed, so the
  condition that forced the DPS branch does not hold here.
- A dry-only rule keeps one pure entry point over the
  synthesized `CharacterFitting` for saved, DNA, and EFT
  surfaces alike (the capacitor shape), with no
  surface-specific number to label twice.
- The shipped cache value for the multiplier is 3.0 on all
  8 catalogue self-armor ancillary types that carry repair
  data (of 12 with effect 5275; 4 are abyssal types with no
  repair rows at all, section 3), so a future loaded
  variant is a multiplier emission away — but it is not
  this slice.

The disclosure states the dry rule on screen (section 6).
Capacitor-booster charges loaded in an ancillary shield
booster change nothing in this slice: no Flutter body
reads them for repair, and their capacitor cost is already
the module's own `capacitorNeed` in #600.

### 2.4 Resistances are never applied — effective tank ships nothing

The candidate combination — raw HP/s divided by an omni
(equal-quarters damage) resonance denominator, mirroring
how `src/fitting/ship_ehp.rs` divides buffer hit points —
was examined and rejected as ungrounded. The evidence,
each item an inspected body:

- The repair accumulation above contains no resistance or
  resonance factor: it stores raw `amount / cycle` summed
  per layer.
- The only resistance division in the Flutter fitting
  bodies is `damage_pattern.dart` `_layerEhp`, applied to
  buffer hit points to produce EHP, never to a rate.
- `models.dart:194–223` stores repair rates and EHP
  side by side; no field combines them, and no symbol
  `sustained`, `totalTank`, or EHP-per-second exists in
  `lib/features/fitting` (grep zero at `ed698d3`).
- The Flutter after-action report's sustained-repair label
  is hardcoded `"Not modeled"`
  (`aar_fit_calculation.dart:179`).
- The shipped Rust EHP body divides hit points by the omni
  denominator; it names no rate.

Dividing a repair rate by that denominator because the
arithmetic looks analogous is exactly the recalled-formula
move this program forbids. So: no effective (resistance-
applied) lines, omni or per-damage-type, in this slice.
The shipped base resistances block and base EHP block stay
as they are; this block's numbers are raw hit points per
second and the disclosure says resistances are not applied.
If a later slice wants effective tank, it must ground the
combination in a body that actually performs it.

### 2.5 Passive shield recharge is never summed

Flutter computes `peakShieldRecharge = 2.5 × shieldHp /
(shieldRecharge / 1000)` (`dogma_engine.dart:891–894`) into
a fourth, separate field and never adds it to shield boost.
Rust already ships that peak as "Shield peak recharge" in
the Ship block (`ship_base_peak_recharge`,
`docs/peak-recharge-rates-design.md`). This slice adds no
second copy and no active-plus-passive sum: the peak is the
maximum of a curve, not a constant rate, so the sum would
overstate every moment except one. The disclosure points
at the existing line instead.

## 3. Attribute set, effect set, and catalogue emission (locked)

Attribute identities, from `dogmaAttributes.jsonl` in the
pinned zip (`name`, `unitID`, `defaultValue` read during
design) cross-checked against Flutter
`dogma_attributes.dart` at `ed698d3`:

| Role | Attribute | Unit | Catalogue today |
|---|---|---|---|
| Shield repair per cycle | 68 `shieldBonus` (Flutter's editorial name: `shieldBoostAmount`) | 113 | **Absent** |
| Armor repair per cycle | 84 `armorDamageAmount` (Flutter: `armorRepairAmount`) | 113 | **Absent** |
| Hull repair per cycle | 83 `structureDamageAmount` (Flutter: `hullRepairAmount`) | 113 | **Absent** |
| Cycle | 73 `duration` | 101 (ms) | Ships (#600, 1,489 rows) |
| Loaded-paste multiplier | 1886 `chargedArmorDamageMultiplier` | 104 (×) | Absent; **never emitted** (section 2.3) |

Attribute 83 is the ship's hull layer (static data
"structure" is the hull; hull hit points are attribute 9
`hp`, already shipped under that reading). The
structure-repair decoys 1170/1171 sit only on a type that
is not in the catalogue and are never read. All three
amount attributes default to 0.0 in the static data, which
is why a *present* row is the signal (section 4 distinguishes
a present zero from absence).

Effect identities, from `dogmaEffects.jsonl` `name` read
during design, matching Flutter's routing sets:

| Effect | SDE name | Layer |
|---|---|---|
| 4 | `shieldBoosting` | shield (self) |
| 4936 | `fueledShieldBoosting` | shield (self, ancillary) |
| 27 | `armorRepair` | armor (self) |
| 5275 | `fueledArmorRepair` | armor (self, ancillary) |
| 26 | `structureRepair` | hull (self) |
| 6186 `shipModuleRemoteShieldBooster`, 6652 `shipModuleAncillaryRemoteShieldBooster` | — | remote shield — **excluded** |
| 6188 `shipModuleRemoteArmorRepairer`, 6651 `shipModuleAncillaryRemoteArmorRepairer`, 7166 `ShipModuleRemoteArmorMutadaptiveRepairer` | — | remote armor — **excluded** |
| 6185 `shipModuleRemoteHullRepairer` | — | remote hull — **excluded** |

Remote repairers carry the **same** amount attributes and
the same `duration` as self repairers (scripted: all 106
catalogue remote types carry amount + 73). Attribute
presence alone therefore cannot tell a fitted remote
repairer (it repairs its target, not its own ship) from a
self repairer. Flutter separates them by effect set — the
remote effects are simply not in its three routing sets.
The Rust catalogue stores no general effect field, only
`slotEffects`, so the separation must happen at generation
time. (In the shipped data, slot effect and `maxRange`
also happen to separate the families perfectly, but a proxy
that merely correlates today is not the grounded rule; the
effect gate is.)

Coverage, scripted during design over the committed caches
joined to the shipped catalogue (25,818 types; categories
and slot effects read from the catalogue itself):

| Family | Catalogue types with a self effect | With amount + `duration` | With neither |
|---|---|---|---|
| Shield (4: 94, 4936: 14) | 108 | 99 | 9 |
| Armor (27: 105, 5275: 12) | 117 | 109 | 8 |
| Hull (26) | 25 | 25 | 0 |

Every one of the 250 is category 7 and carries a slot
effect (`[11]` low for armor, `[13]` medium for shield and
hull — slot-effect names per `dogmaEffects.jsonl`: 11 low,
12 high, 13 medium). No type carries two self-repair
effects, and no catalogue type carries more than one of the
three amount attributes. Partial rows do not exist: no
self type carries an amount without `duration` or a
`duration` without its amount. No amount or cycle value on
any self type is zero, negative, or missing alongside its
partner. The 17 "neither" types are exactly the abyssal
(mutation) variants — 47781 Small Abyssal Shield Booster,
47785, 47789, 47793, 47836, 47838, 47840, 56309, 56310
(shield); 47769 Small Abyssal Armor Repairer, 47773,
47777, 47842, 47844, 47846, 56307, 56308 (armor) — whose
cache rows hold only required-skill attributes: mutated
modules have per-instance stats no base catalogue can
state. They are the excluded-with-count population of
section 4. `reloadTime` (1795, every value 60,000 ms) is
present only on fueled types that carry repair data
(10 shield, 8 armor) and already ships for the Capacitor
block; this slice never reads it (section 2.2).

**Emission (locked).** The generator
(`scripts/sde/generate_fitting_types_sde.py`) emits eight
new sparse keys for category-7/66 rows carrying a slot
effect (the #600 gate: generator `SLOT_EFFECT_IDS =
{11, 12, 13, 2663, 3772}`) **and** a self-repair effect
from `dgmTypeEffects.csv.bz2` (the same cache the
generator already reads for `slotEffects` and for the
`turretFitted` / `launcherFitted` / fighter-ability
boolean markers):

- Three amount keys under their verbatim SDE names —
  `shieldBonus` (68), `armorDamageAmount` (84),
  `structureDamageAmount` (83) — emitted exactly when a
  cache row for that attribute exists on a type passing
  the gate, including a present `0.0`. Expected counts:
  99 / 109 / 25. Because the gate requires a self effect,
  amount presence in the shipped catalogue **is** the
  self-repair classification: a remote repairer never
  gains an amount key even though the cache carries its
  amount row. (Ungated emission was simulated during
  discovery at 145 / 161 / 33 keys — rejected: it would
  re-create the remote-versus-self ambiguity at runtime.)
- Five boolean markers under their verbatim SDE effect
  names — `shieldBoosting`, `fueledShieldBoosting`,
  `armorRepair`, `fueledArmorRepair`,
  `structureRepair` — `true` exactly when the type carries
  that effect and passes the gate, in the fighter-marker
  shape (`fighterAbilityAttackM`, DPS design section 2.5).
  Expected counts: 94 / 14 / 105 / 12 / 25. The markers
  exist for one reason: without them a fitted abyssal
  repairer (no amount row to emit) is indistinguishable
  from a fitted non-repair module, and section 4's
  excluded-with-count rule would be unimplementable for
  exactly the population it exists for.

Key order within a row is locked: existing keys keep their
order; the eight new keys append immediately after the
#600 keys (`capacitorNeed`, `duration`, `reloadTime`) in
the order listed above (amounts in shield/armor/hull
order, then markers grouped shield, armor, hull:
`shieldBoosting`, `fueledShieldBoosting`, `armorRepair`,
`fueledArmorRepair`, `structureRepair`). Emission
follows the house fail-loud pattern (exit 1, nothing
written, on duplicate / unparseable / non-finite /
negative source values; the `dps`-load and cap-key
precedents) with oracle counts in a new
`REPAIR_EXPECTED_COUNTS` map and spot oracles in a new
`REPAIR_ORACLES` list (section 8). Scripted append size
against the shipped 3,611,903-byte catalogue: amounts
+5,571 bytes, markers +5,330 bytes, for **3,622,804 bytes
expected**; the regenerated catalogue must land within
**3,632,000 bytes** or the builder stops and reports (the
DPS budget precedent). The integrator pins the exact byte
count. The catalogue file is generated; never hand-edit
it. Logistics drones are fenced off twice over: category
18 fails the category-7/66 emission gate (18 cache types
carry repair amounts for their remote-repair behaviour),
and `DroneBay` rows are never slot rows (section 4).

**Loader.** `src/names/fitting_types.rs` gains three
`#[serde(rename, default)] Option<f64>` fields —
`shield_bonus`, `armor_damage_amount`,
`structure_damage_amount` — and five `bool` marker fields
in the `turret_fitted` rename-and-default shape, plus
`bundled_catalogue_invariants` pins: each amount finite
`≥ 0`; amount and marker presence only on category-7/66
rows with a slot effect; an amount key never appears
without its family's marker (shield amount ⇒
`shieldBoosting` or `fueledShieldBoosting`, and likewise
armor and hull); at most one amount key per row; the eight
expected counts above; and the section 8 spot values.
`duration` is unchanged and shared with #600: the same
emitted milliseconds feed the capacitor cycle there (plus
a present reload) and the repair cycle here (raw) — one
catalogue value, two locked consumers, no second key.

## 4. Module inclusion rules (locked)

Grid: **slot rows only** — saved fittings by ESI flag
prefix (`LoSlot`/`MedSlot`/`HiSlot`/`RigSlot`/
`SubSystemSlot`, the shipped `is_slot_flag` shape in
`src/fitting/ship_cap_stability.rs`), imported fittings by
slot section via the `to_character_fitting()` synthesis,
one code path. One catalogue lookup per row; quantity is
in **units** clamped `max(0)`, and a zero-quantity row
contributes and excludes nothing (the shipped capacitor
counting loop's units precedent: a stacked slot row of
five counts five). Rows with `type_id ≤ 0` are ignored
entirely. No `category_id` test beyond the catalogue's own
emission gate: in shipped data an amount key or marker can
only exist on a category-7/66 slot type, so amount/marker
presence is the classification, and a drone type filed
under a slot flag (the demo fixture files drone 28270
under `SubSystemSlot0`) carries neither and falls out
cleanly. Slot belonging is never judged against the row's
own slot effect (a shield booster under a `LoSlot` flag
still counts toward shield; flag prefix is the only
section test, as in every shipped sibling).

Family for a candidate row: armor if `armorRepair` or
`fueledArmorRepair`, else shield if `shieldBoosting` or
`fueledShieldBoosting`, else hull if `structureRepair`
(Flutter's priority order, section 2.1). Where a marker
were ever absent but an amount key present — impossible in
shipped data by the section 3 invariants — the amount key
alone also makes the row a candidate of that key's family
(defence in depth; fixture-only).

Per slot row, from base catalogue values only:

| Base data on the row's type | Treatment |
|---|---|
| Candidate (marker or amount, above) with usable amount `> 0` for its family and usable `duration > 0` | **Counted**: `quantity × amount / (duration / 1000)` added to that layer; `counted_modules` += quantity units |
| Candidate with usable amount `== 0.0` present | **Known zero**: contributes 0 HP/s, neither counted nor excluded (the capacitor slice's present-zero `capacitorNeed` precedent; 0 such types ship) |
| Candidate with amount absent (the 17 abyssal types), or amount present but `duration` absent / `≤ 0`, or amount/cycle non-finite or negative (impossible in shipped data; invariants prove it) | **Excluded with count** — a proven repairer without a provable rate is never zero-repair |
| Type absent from the catalogue | **Excluded with count** (shipped capacitor/resources precedent: an unknown fitted module might repair; counting it as excluded never claims zero) |
| Known type, no marker and no amount key — every non-repair module, every remote repairer (section 3 gate), drones, blueprints, ore | **Not a repairer**: neither counted nor excluded |
| Non-slot row (`DroneBay`, `FighterBay`, `Cargo`, any other flag) | Never scanned: neither counted nor excluded, whatever its type |

**Module state.** Neither Rust fitting shape carries
online/offline state, so Flutter's offline skip
(`dogma_engine.dart:687–688`, test E2.5) has no
counterpart: every counted module is assumed cycling
continuously, and section 6's wording says exactly that —
the same locked assumption, in the same words, as the
Capacitor block, so the two blocks cannot be read as
assuming different things about the same modules.

**Charges** never produce or modify a rate (section 2.3):
an EFT line listing Nanite Repair Paste after an ancillary
repairer renders the same dry number as the saved surface.
**Remote repairers fitted on this ship** contribute
nothing here by construction (they gain no amount key);
their capacitor use on this ship is already counted as a
drain by #600, and incoming remote repairs from other
ships are not a property of this fitting at all
(section 9).

## 5. Pure API (locked)

New sibling module `src/fitting/active_repair.rs`,
mirroring `ship_cap_stability.rs` (no egui, no state, no
network, no database, logs nothing — render cadence; the
catalogue load already logs counts once). One entry point
over the synthesized `CharacterFitting` — the capacitor
shape, not the DPS `(fitting, imported, catalogue)` triple,
because dry-only amounts (section 2.3) need no charge
pairing from the imported side:

```rust
pub struct FittingActiveRepair {
    pub shield_hp_per_sec: Option<f64>,
    pub armor_hp_per_sec: Option<f64>,
    pub hull_hp_per_sec: Option<f64>,
    pub counted_modules: u64,
    pub excluded_modules: u64,
}

pub fn fitting_active_repair(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> FittingActiveRepair
```

Decisions locked:

- **No ship input and no availability outcome.** Raw
  repair rates depend only on fitted modules (effective
  tank, the only consumer of ship resistances or hit
  points, ships nothing — section 2.4), so there is no
  `Unavailable` state and no ship lookup: a fitting whose
  ship type is absent from the catalogue still gets exact
  module rates. The Capacitor block's unavailable sentence
  exists because its verdict needs hull capacitor data;
  this block has no counterpart sentence beyond the
  catalogue-failed-to-load line every block renders
  (section 6).
- **Each layer is `Some(sum)` whenever the sum is
  finite**, including `Some(0.0)` when nothing counted —
  an empty sum over proven data is a known zero, rendered
  as such (the shipped present-zero precedent), never
  omitted as if unknown. A sum is `None` only if it goes
  non-finite (hostile quantities against bounded catalogue
  values; defence in depth, in the capacitor slice's
  `total_use_per_sec` shape). Layers are independent: one
  layer's `None` never affects another's.
- **No total field, no outcome enum, no percent.**
  (Sections 2.1, 2.4, 2.5.) Anyone adding one later must
  ground it per section 2.4, not derive it here.
- The function is total: saturating counts, values
  filtered through the shipped `usable()` shape (present,
  finite, `≥ 0`), no panic on hostile saved data.
- Re-exported from `src/fitting/mod.rs` alphabetically
  like its siblings. The module doc cites this design,
  the raw-only / dry-only / no-modifiers locks, and the
  logs-nothing rule in the siblings' words. No
  `ship_resistances`, `ship_ehp`, `ship_peak_recharge`,
  or `ship_cap_stability` call anywhere in the module:
  composing with them is a display-juxtaposition matter,
  not an arithmetic one.

## 6. UI (locked — new sibling block)

New `render_fitting_active_repair` in `src/ui/fittings.rs`,
mirroring `render_fitting_cap_stability`
(`src/ui/fittings.rs:2195`): called immediately **after**
the Capacitor block at both detail sites — imported detail
(after the `render_fitting_cap_stability` call at
`src/ui/fittings.rs:2508`) and saved detail (after
`src/ui/fittings.rs:2815`) — so the two continuous-cycling
blocks sit together, ahead of slot layout and the bare-hull
blocks. It cannot ride the "Ship (base values)" block: its
numbers come from fitted modules, not the hull. Both sites
pass the `CharacterFitting` they already hold (saved) or
synthesize (imported), so saved, DNA, and EFT surfaces
render identically (section 2.3). Heading verbatim:

```text
Active repair (base values)
```

Rejected headings: "Sustained tank" and "Tank" — both
promise the resistance-applied, cap-checked steady-state
figure this slice does not compute (sections 2.2, 2.4);
"Defense" would collide in meaning with the resistances
and EHP blocks. Lines, in order — each via
`ship_stat_line(label, value, "HP/s")`
(`src/ui/fittings.rs:1420`), amounts via
`widgets::format_fitting_amount` (`src/ui/widgets.rs:69`),
which renders one decimal (`61.3 HP/s`); `None` omits its
line; module names are never shown, only counts, so no raw
id can appear:

```text
Shield boost: {amount} HP/s
Armor repair: {amount} HP/s
Hull repair: {amount} HP/s
{count} fitted modules are not counted because   [excluded_modules > 0]
their base repair data is not in Mimir's
bundled item data.
```

Label order is shield, armor, hull — the Ship block's
layer order. "Shield boost" is the static-data operation
name for shield repair (effect `shieldBoosting`,
attribute `shieldBonus`) and keeps this line distinct
from the Ship block's "Shield peak recharge" passive line.
The excluded line uses the Capacitor block's singular /
plural pair with "base capacitor use" replaced by "base
repair data", verbatim:

```text
1 fitted module is not counted because its base repair data is not in Mimir's bundled item data.
{n} fitted modules are not counted because their base repair data is not in Mimir's bundled item data.
```

The heading renders in every state, including a fitting
with no items (three `0.0 HP/s` lines). Hiding zero repair
rows was Flutter's fitting-panel choice (it rendered no
repair rows at all) and its after-action panel's
positive-only choice; shipped Rust blocks render present
data including exact zeros, and a reader comparing two
fittings needs the zero to be a stated zero, not an absent
block. When the catalogue itself failed to load, the block
renders the heading and this sentence only (mirroring the
Capacitor block's no-catalogue line):

```text
Active repair unavailable: Mimir's bundled item data failed to load.
```

**Disclosure**, rendered verbatim under the lines whenever
the catalogue loaded (new constant
`FITTING_ACTIVE_REPAIR_DISCLOSURE`):

> Assumes every counted repair module keeps cycling
> continuously. Base values from Mimir's bundled item
> data: base hit points restored per cycle at base cycle
> times, with resistances, skills, implants, and bonuses
> from modules, rigs, subsystems, and the ship itself not
> applied — raw hit points per second, not effective hit
> points per second. Ancillary repair modules are counted
> at their unloaded repair amount: loaded charges (such
> as Nanite Repair Paste) and reload time are not
> modelled, so an ancillary module's rate is its rate
> while cycling, not a long-run average. Remote
> repairers, which repair other ships, are not counted.
> Repair modules' capacitor use is counted in the
> Capacitor block above; this block does not model
> whether the capacitor can sustain continuous cycling.
> Passive shield recharge is shown as shield peak
> recharge in the Ship block and is not included here, so
> these numbers can differ from EVE.

Every clause carries one locked decision from section 2:
continuous cycling (section 4), raw not effective
(section 2.4), dry ancillary with no reload average
(sections 2.2, 2.3), remote exclusion (section 3), the
capacitor interaction stated as #600's separate statement
rather than re-simulated, and no passive sum
(section 2.5). The renderer gains no logging (render
cadence; counts only, per the house rule — there is
nothing here to log beyond what the catalogue load already
logs once).

## 7. Demo numbers (hand-derived; divisions shown)

No shipped demo fitting carries a self-repair module
(verified against `assets/demo/fittings.json` during
design). The demo story is therefore three known zeros,
plus one excluded count that pins the unknown-type rule on
a real fixture:

- **Demo Brawler (fitting 1, Rifter 587).** Slot rows:
  Damage Control II 2048 (`LoSlot0`), its blueprint 2049
  (`MedSlot0`), Crokite 1225 (`MedSlot1`), shield hardener
  2050 ×2 (`HiSlot0/1`), type 1535 (`RigSlot0`), drone
  28270 (`SubSystemSlot0`). None of 2048/2049/1225/2050/
  28270 carries a repair marker or amount (catalogue rows
  read during design), so they are not repairers. Type
  1535 is **absent from the catalogue**, so section 4
  counts it excluded. Result: shield `0.0`, armor `0.0`,
  hull `0.0` HP/s, counted 0, **excluded 1** — the block
  shows the singular excluded sentence.
- **Mission Runner (fitting 2, Rifter 587).** Slot rows:
  2048, 2049, both known non-repairers. Result: three
  `0.0` HP/s lines, counted 0, excluded 0, no excluded
  sentence.
- **Demo Runner (fitting 10, Punisher 597).** Slot rows:
  2048, 2050, 1225, all known non-repairers. Result as
  fitting 2.

Rendered demo block (fittings 2 and 10):

```text
Active repair (base values)
Shield boost: 0.0 HP/s
Armor repair: 0.0 HP/s
Hull repair: 0.0 HP/s
```

Non-demo hand oracles from cache values read during design
(amount / `duration`, both already partly shipped — the
`duration` values below are the committed catalogue's):

- **1183 Small Armor Repairer II:** amount 92.0, duration
  6000.0 ms → `92.0 / 6.0 = 15.333…` armor HP/s, rendered
  `15.3 HP/s`. This is the armor repairer in the capacitor
  slice's EFT sample, so that sample (1183 + afterburner
  438 + scrambler 448 + 3× autocannon 2889, none of the
  others a repairer — verified) reads here: armor
  `15.333…`, shield `0.0`, hull `0.0`, counted 1,
  excluded 0, while #600 separately counts the same
  module's `40.0 / 6.0` GJ/s drain — the two blocks'
  numbers coexist without either doing the other's work.
- **3540 Large Armor Repairer II:** `920.0 / 15.0 =
  61.333…` armor HP/s (rendered `61.3 HP/s`) — the Flutter
  E2.1 numbers on the real type.
- **10850 Medium Shield Booster II:** `104.0 / 3.0 =
  34.666…` shield HP/s (rendered `34.7 HP/s`) — E2.2.
- **2355 Small Hull Repairer II:** `30.0 / 24.0 = 1.25`
  hull HP/s (rendered `1.3 HP/s` — the formatter rounds
  the tenth half away from zero, `src/ui/widgets.rs`;
  the stored rate stays 1.25 exactly) — E2.4.
- **33076 Small Ancillary Armor Repairer:** `52.0 / 6.0 =
  8.666…` armor HP/s dry (rendered `8.7 HP/s`), with
  `reloadTime` 60,000 ms ignored and the cache's
  `chargedArmorDamageMultiplier` 3.0 unemitted — E2.3's
  dry half; its loaded `26.0` is never an expectation
  here.
- **32774 Small Ancillary Shield Booster:** `52.0 / 2.0 =
  26.0` shield HP/s exactly — the reload-ignored pin in
  its starkest form (a reload-added cycle would read
  `52.0 / 62.0`).

## 8. Test plan (locked literals; Flutter oracle cross-checks)

**Flutter base-pure oracles** (`dogma_engine_test.dart` E2
group at `ed698d3`). The E2 fixtures are test-local types,
but during design the committed cache was read for the
real types the fixtures mimic and the values are
identical, so each oracle is pinned twice over: as a
fixture-catalogue case with the E2 numbers, and against
the bundled catalogue with the real type. All rate
assertions use one absolute tolerance of `1e-9` with the
arithmetic in a comment (peak/capacitor precedent; no
special-casing values that happen to be exact into
`assert_eq!`); `assert_eq!` is reserved for counts, `None`
outcomes, and rendered line strings.

| Oracle | Literal | Real type (cache amount / duration) |
|---|---|---|
| E2.1 armor | `920.0 / 15.0 = 61.333…` | 3540 (920.0 / 15000.0 ms) |
| E2.2 shield | `104.0 / 3.0 = 34.666…` | 10850 (104.0 / 3000.0 ms) |
| E2.3 ancillary armor, dry half only | `52.0 / 6.0 = 8.666…` (loaded `26.0` never asserted) | 33076 (52.0 / 6000.0 ms, multiplier 3.0 in cache, unemitted) |
| E2.4 hull | `30.0 / 24.0 = 1.25` | 2355 (30.0 / 24000.0 ms) |
| E2.5 offline | **not ported** — no module state exists (section 4); named, no test | — |
| E2.6 (84.333), E2.7 (112.444), real-SDE T8.3 (112.444) | **never base expectations** — ship-trait and skill bonuses; asserting them would prove the bonus pipeline leaked in. The base expectation for their module is E2.1's 61.333… | — |
| E2.8 passive peak 1.8 | Already shipped by the peak slice; this slice asserts it is **not** added to any layer (a bare Rifter reads shield `0.0` here) | — |

**Builder A — generator, loader, pure module tests:**

- Generator: `REPAIR_EXPECTED_COUNTS` (amounts
  99 / 109 / 25; markers 94 / 14 / 105 / 12 / 25) and
  `REPAIR_ORACLES` — present values (3540
  `armorDamageAmount` 920.0, 10850 `shieldBonus` 104.0,
  2355 `structureDamageAmount` 30.0, 1183
  `armorDamageAmount` 92.0, 33076 `armorDamageAmount`
  52.0 with `fueledArmorRepair` true, 32774 `shieldBonus`
  52.0 with `fueledShieldBoosting` true), marker-only
  oracles (47781 `shieldBoosting` true with `shieldBonus`
  absent; 47769 `armorRepair` true with
  `armorDamageAmount` absent), absence oracles proving
  the effect gate (3588 Small Remote Shield Booster II:
  no `shieldBonus`, no marker — its cache amount 85.0
  must not appear; 11355 Small Remote Armor Repairer I:
  no `armorDamageAmount`, no marker; 2048, 2050, 587: no
  new keys at all), and one 1886-absence oracle (33076
  gains no `chargedArmorDamageMultiplier` key). Fail-loud
  cases follow the shipped generator pattern.
- Loader: the section 3 invariants and counts over the
  bundled catalogue, spot values for the oracle types
  above, and a deserialisation fixture proving the new
  fields default cleanly on rows without them.
- Pure: the four E2 literals; reload ignored (32774 →
  exactly `52.0 / 2.0 = 26.0` within `1e-9`, and a fixture
  pair differing only in `reloadTime` giving equal rates
  — the field is never read); multi-module sum
  (`2 × (92.0 / 6.0) = 30.666…` as two rows and as one
  quantity-2 row); layers independent (one module per
  family sums into three separate layers, no cross-talk);
  the section 4 matrix, one test per row — counted,
  known-zero present `0.0` amount (fixture-only; neither
  counted nor excluded), candidate with amount but no
  `duration` (fixture-only), amount `≤ 0` / non-finite
  (fixture-only), unknown type id excluded, known
  non-repairer and known remote repairer neither,
  non-slot rows ignored even for a repairer type,
  `type_id ≤ 0` ignored, quantity `max(0)` and
  zero-quantity, slot flag judged by prefix only (shield
  booster under `LoSlot0` counts toward shield); ship type
  absent from catalogue with a fitted repairer still
  yields exact rates (no ship input, section 5); a
  non-finite layer sum yields that layer `None` and the
  others intact.
- Bundled-catalogue pass: the three demo fittings
  (section 7 numbers, including Demo Brawler excluded 1),
  one real type per family (3540 / 10850 / 2355), the
  dry-ancillary pair (33076 → `8.666…`, never `26.0`;
  32774 → `26.0`), real remote repairers fitted (3588,
  11355 → all layers `0.0`, counted 0, excluded 0), real
  abyssal repairers fitted (47781, 47769 → excluded
  counts, layers `0.0`), and the capacitor slice's EFT
  sample synthesis (armor `92.0 / 6.0 = 15.333…`, counted
  1, excluded 0).

**Builder B — renderer tests:**

- Verbatim heading, line templates, and disclosure
  constant (byte-exact against section 6), including the
  one-decimal renderings `61.3 / 34.7 / 1.3 / 15.3 HP/s`
  and stored-versus-rendered exactness for 1.25.
- Demo blocks: fittings 2 and 10 render the section 7
  four lines with no excluded sentence; fitting 1 adds
  the singular excluded sentence; plural form pinned by
  a fixture fitting with two excluded units.
- `None` layer omits only its own line; no-catalogue
  renders heading plus the failed-to-load sentence and no
  disclosure; empty fitting renders three `0.0 HP/s`
  lines.
- Surface symmetry: the same fitting as saved and as
  imported (including an EFT import listing Nanite Repair
  Paste after 33076) renders identical lines — the dry
  rule made visible.
- Regression: every other block's line tests pass
  unmodified — this slice inserts one block after
  Capacitor and rewords none of theirs.

**Gates (every commit):** `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`,
`cargo build`.

## 9. Exclusions (locked — ship-nothing lines are explicit)

- **No effective (resistance-applied) tank** — no EHP per
  second, no omni or per-damage-type repair divisor, no
  "tank" total (section 2.4). The base resistances block
  and base EHP block are untouched.
- **No passive-plus-active sum** and no second peak
  recharge line (section 2.5).
- **No reload- or clip-averaged ancillary rate**, and no
  loaded-charge amounts on any surface: attribute 1886
  is never emitted or read; EFT-listed charges never
  modify a repair rate in this slice (sections 2.2, 2.3).
- **No remote repairs, either direction.** Fitted remote
  repairers contribute nothing to this ship's layers
  (section 3's gate keeps their amounts out of the
  catalogue entirely, so they are not even an excluded
  count — they are known non-self data), and incoming
  remote repairs from fleetmates ("logistics received")
  are not a property of a fitting and are never modelled.
  A future outgoing-logistics figure needs its own design;
  it must not be smuggled into these layers.
- **No capacitor re-simulation.** Repair modules'
  `capacitorNeed` and cycle are already counted as drains
  by #600; this slice adds no drain, reads no capacitor
  value, and states the interaction only in the
  disclosure. A fitting can show a high repair rate here
  and a depleting capacitor there; both statements are
  labelled, neither edits the other.
- **No modifiers of any kind:** amounts and cycles stay
  base. Ship traits and skills (Flutter E2.6/E2.7's repair
  amount and repair-cycle bonuses), module/rig/subsystem
  bonuses, implants, overheating — none applied, none
  emitted for. No stacking penalty exists to apply: repair
  amounts sum directly in the grounded body.
- **No module state** (online/offline/overheated), no
  pulsing, no staggered activation, no repair-timing
  (cycle-start versus cycle-end) modelling.
- No new ESI scopes, storage, or EFT/DNA format changes;
  no change to `ship_stats`, `ship_resistances`,
  `ship_ehp`, `ship_peak_recharge`, or
  `ship_cap_stability` (consumed not at all — section 5).

## 10. Integrator list

- **README** (Fittings bullet): add active repair to the
  base-values sequence after the capacitor-stability
  sentence, in the same voice ("The same details also
  show base active repair per hit-point layer — raw base
  hit points per second from the fitted shield boosters,
  armor repairers, and hull repairers in Mimir's bundled
  item data, cycling continuously — with resistances,
  skills, implants, bonuses from modules, rigs,
  subsystems, and the ship itself, loaded charges, and
  reload time not applied; repair modules whose base
  repair data is not in the bundled data are left out
  with a disclosed count, never counted as zero, and
  remote repairers are not counted."), and replace the
  closing denial's "There are still no sustained-tank
  figures, and no adjusted (fitted) fitting totals of any
  kind" with "There are still no adjusted (fitted) fitting
  totals of any kind", leaving its parenthetical intact. In the line-31
  not-implemented checklist, extend the shipped-readout
  list with "the base active-repair readout" alongside the
  base capacitor-stability readout.
- **Engineering journal**
  (`docs/engineering-journal/LEARNINGS.md`, integrator's
  commit): two entries with Evidence/Mechanism/rule —
  (a) Flutter's repair rate is a while-cycling burst rate
  over raw `duration`, never reload-averaged, and no body
  divides a repair rate by a resistance, so the shipped
  figure is raw active repair, not sustained/effective
  tank (sections 2.2, 2.4 bodies); (b) when the same
  attributes serve self and remote modules, classification
  must be gated by effect at generation time, and
  missing-data population needs an effect marker or it
  cannot be counted honestly (section 3).
- Nothing else: no HANDOFF change beyond what the parent
  directs, no fitting-format or ESI change. If build
  discovery contradicts any count in sections 3 or 8, the
  slice stops rather than growing scope.

## 11. Ownership and commit split

- **Design (this commit):** `docs/sustained-tank-design.md`
  only. Commit: `docs(fitting): design base active repair`.
- **Builder A — data + pure calculation:** generator
  (`scripts/sde/generate_fitting_types_sde.py`),
  regenerated `assets/sde/fitting_types.json`, loader
  (`src/names/fitting_types.rs`), new
  `src/fitting/active_repair.rs`, `src/fitting/mod.rs`
  wiring, section 8 Builder-A/generator tests. Commits:
  `feat(sde): emit module base repair amounts and markers`,
  `feat(fitting): add pure base active repair`.
- **Builder B — render:** `src/ui/fittings.rs` only,
  section 8 Builder-B tests. Commit:
  `feat(fittings): show base active repair in fitting details`.
- **Integrator:** README + journal per section 10, full
  gates, demo check, catalogue byte-count verification
  against section 3's 3,622,804 expected (3,632,000
  ceiling). Commit:
  `docs(fittings): document base active repair`.

Builder B touches no `src/fitting/` file and codes against
section 5's locked API. Small atomic commits,
`type(scope): description`, no attribution lines. Nobody
pushes or merges; the parent does that.

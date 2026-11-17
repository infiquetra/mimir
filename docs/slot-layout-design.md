# Slot layout — design

Status: locked for implementation. Base: `develop` at `b3d009b`. Slice branch:
`feat/rust-slot-layout`. Discovery: two read-only reports (Flutter slot layout
at `ed698d3` plus the current Rust seams; SDE slot/hardpoint data audit),
re-verified against the bodies named below during design. Slot counts are
grounded at base values and hardpoint use is grounded end to end (section 2),
so this slice is a go for all seven dimensions: high, medium, low, rig, and
subsystem slots, plus turret and launcher hardpoints. Every number in this
document traces to an inspected body: `dogmaAttributes.jsonl`,
`dogmaEffects.jsonl`, and `dogmaUnits.jsonl` in the pinned SDE zip
(`scripts/sde/eve-online-static-data-3503375-jsonl.zip`), the committed
Fuzzwork caches `scripts/sde/dgmTypeAttributes.csv.bz2`,
`scripts/sde/dgmTypeEffects.csv.bz2`, `scripts/sde/invTypes.csv.bz2`, and
`scripts/sde/invGroups.csv.bz2` read directly this session, the committed
catalogue `assets/sde/fitting_types.json` (3,176,352 bytes), Flutter at
`ed698d3` via `git show`, and current Rust (`src/fitting/calibration.rs`,
`src/fitting/resources.rs`, `src/fitting/bay_usage.rs`, `src/fitting/eft.rs`,
`src/fitting/dna.rs`, `src/fitting/write_map.rs`,
`src/names/fitting_types.rs`, `src/ui/fittings.rs`,
`scripts/sde/generate_fitting_types_sde.py`, `assets/demo/fittings.json`).

## 1. Goal and value ranking

Goal: in both fitting details (saved fitting detail and imported fitting
detail), show slot use against the ship's base slot layout, at base values
from catalogue data — fitted versus available for high, medium, low, rig, and
subsystem slots, and for turret and launcher hardpoints — following the
shipped CPU/power grid resources (`src/fitting/resources.rs`), bay usage
(`src/fitting/bay_usage.rs`), and rig calibration
(`src/fitting/calibration.rs`) patterns. Base hull layout only:
subsystem-granted slot changes and every other modifier are not applied
(section 10), and the tech-3 case where base counts alone would mislead is
handled by suppression plus an explicit sentence (sections 4 and 6), never by
a fitted-as-capacity substitution.

Value ranking, in order, when any two rules below appear to conflict:

1. **Never show a slot or hardpoint number read from the wrong source.**
   Each available count has exactly one locked dogma attribute (section 2.1)
   and hardpoint consumption has exactly one locked marker pair (effects
   40/42, section 2.3). Names, attribute 47 `slots`, attribute 64
   `damageMultiplier`, attribute 1154 `upgradeSlotsLeft`, and the subsystem
   modifiers must never reach a line.
2. **Correctness.** Fitted counts are flag occupancy (one distinct slot flag,
   one slot), exactly as locked in section 4; unknown hardpoint data is
   counted and disclosed, never silently zeroed; absent data is never shown
   as zero and a present `0.0` renders as data. A dimension whose count
   cannot be known does not render a line (sections 4 and 5).
3. **Reuse.** Mirror the existing pure-layer, generator, and rendering shapes
   wherever they fit without violating 1 or 2. Where reuse would mislead
   (multiplying a slot row's quantity into an occupancy count, or inheriting
   Flutter's fitted-as-capacity tech-3 guard), correctness wins and the
   divergence is locked and justified (section 4).

## 2. Sources and grounding (inspected bodies only)

### 2.1 Ship base layout attributes (locked)

From `dogmaAttributes.jsonl` / `dogmaUnits.jsonl` in the pinned zip, `_key`
is the id. All seven locked attributes are `dataType` 4 (float); every cache
row carries the value in `valueFloat` with `valueInt` the string `None`
(verified over every row of every locked attribute this session).

| Id | Dogma name | Display name (en) | Unit | Role in this slice |
|---|---|---|---|---|
| 14 | `hiSlots` | High Slots | 122 `Fitting slots` | Ship high slots. |
| 13 | `medSlots` | Medium Slots | 122 | Ship medium slots. |
| 12 | `lowSlots` | Low Slots | 122 | Ship low slots. Description: "The number of low power slots on the ship." |
| 1137 | `rigSlots` | Rig Slots | 122 | Ship rig slots. Description: "The number of rig slots on the ship." |
| 1367 | `maxSubSystems` | Subsystem Slots | — (no `unitID` key) | Ship subsystem slots; also the tech-3 detector (section 4). |
| 102 | `turretSlotsLeft` | Turret Hardpoints | 141 `Hardpoints` | Ship turret hardpoints. |
| 101 | `launcherSlotsLeft` | Launcher Hardpoints | 141 | Ship launcher hardpoints. |

The catalogue keys are the dogma `name` fields verbatim, the same rule every
shipped key follows (`cpuOutput`, `upgradeCapacity`): `hiSlots`, `medSlots`,
`lowSlots`, `rigSlots`, `maxSubSystems`, `turretSlotsLeft`,
`launcherSlotsLeft`. The `SlotsLeft` names of 101/102 describe what the live
dogma engine decrements; the static per-type value on the bare hull is the
ship's total hardpoints, which is how Flutter read them
(`lib/core/sde/sde_service.dart` at `ed698d3`, lines 1001–1006:
`turretSlots: attributes[102]`, `launcherSlots: attributes[101]`) and how
the Flutter SDE test oracle pins them (Rifter 587: turret 3, launcher 2 —
the same values in `dgmTypeAttributes.csv.bz2` rows `(587, 102) = 3.0` and
`(587, 101) = 2.0`, read this session). No plain-count alternative exists
for hardpoints, so 101/102 are locked as the base counts.

**Rig source, decided: 1137, never 1154.** Dogma carries a second rig-like
attribute, 1154 `upgradeSlotsLeft` (display "Rig Slots", description "How
many rigs can by fitted to this ship."). Where a plain count attribute
exists (1137, in the same `*Slots` naming family and unit 122 as the locked
12/13/14, and the attribute Flutter read), it is locked; 1154 is not
emitted and is never a per-ship fallback (a ship-dependent source would make
the same line mean two different reads). The cost is exact and small: the
seven ships with 1137 absent and 1154 present as `0.0` (588 Reaper, 596
Impairor, 601 Ibis, 606 Velator, 33079 Hematos, 33081 Taipan, 33083 Violator)
have no rig dimension and render no rig line. When both are present (380
ships) they agree on every ship (0 disagreements, scripted this session), so
the choice changes presence on those seven hulls only, never a value.

**Decoys, barred** (each verified in `dogmaAttributes.jsonl` and the caches
this session; none is ever read):

- 1154 `upgradeSlotsLeft` — the unchosen rig source, above.
- 47 `slots` (`attributeCategoryID` 9, `published` false, default 1.0): "The
  number of slots this module requires. Only used for launchers, bays and
  turrets." A per-module requirement, not a hull count (0 ships carry it),
  and not a hardpoint marker (section 2.3).
- 106 `droneBaySlotsLeft` — drone bay remaining; 0 ships carry it.
- 1366 `subSystemSlot` — a per-subsystem slot id (values 125–129 on 48
  published category-32 subsystems plus skill 33095), not a hull count.
- 1368 `turretHardPointModifier`, 1369 `launcherHardPointModifier`, 1374
  `hiSlotModifier`, 1375 `medSlotModifier`, 1376 `lowSlotModifier` — the
  subsystem-granted changes this slice explicitly does not apply. Every
  published carrier is category 32 (12/12/48/48/48 carriers); 0 ships carry
  them.
- 2056 `serviceSlots` — structures only (0 ships). Service slots are not a
  ship fitting dimension in this slice.
- 64 `damageMultiplier` and 212 (missile damage bonus) — damage values
  Flutter's DPS code probed; neither marks hardpoint consumption
  (section 2.3).

### 2.2 Coverage (scripted join of the caches against the catalogue)

Over the 404 published category-6 (ship) catalogue rows, scripted this
session (present / present-zero / absent; all values finite, non-negative,
and integral — maxima 8.0 for 12/13/14/101/102, 3.0 for 1137, 5.0 for 1367;
no duplicate (type, attribute) rows anywhere):

| Attr | Present | Nonzero | Zero | Absent | Absent examples |
|---|---|---|---|---|---|
| 12 low | 402 | 384 | 18 | 2 | 670 Capsule, 33328 Capsule 'Auroral' |
| 13 med | 402 | 377 | 25 | 2 | same two capsules |
| 14 high | 402 | 376 | 26 | 2 | same two capsules |
| 1137 rig | 380 | 369 | 11 | 24 | capsules/shuttles; the seven 1154-only corvettes |
| 1367 subsystem | 4 | 4 | 0 | 400 | only 29984 Tengu, 29986 Legion, 29988 Proteus, 29990 Loki, all 5.0 |
| 101 launcher | 404 | 177 | 227 | 0 | — |
| 102 turret | 402 | 296 | 106 | 2 | 2863 Primae, 2998 Noctis |

Present zero is real data and renders: Echelon 3532 carries (12, 14) =
`0.0`, Providence 20183 carries (13, 14) = `0.0`, Punisher 597 carries
101 = `0.0` — those lines read `0 of 0` (section 6). Absent is no data:
Capsule 670 carries 101/102 present as `0.0` but has no 12/13/14, 1137, or
1367 rows at all, so it proves exactly its two hardpoint dimensions and no
slot dimension (section 5). Primae 2863 / Noctis 2998 carry no 102 row —
absent turret data, which is not the same fact as zero turrets.

Tech-3 hulls: all four carry 12/13/14 = `0.0`, 101/102 = `0.0`, 1137 = `3.0`,
1367 = `5.0` verbatim. The zeros are present data, but the live layout comes
from fitted subsystems (the barred modifiers above), which this slice does
not apply. A bare-hull line such as "5 of 0 used (5 over)" would be a false
over-use claim about a healthy fit. Section 4 locks the honest handling:
on a hull with a usable `maxSubSystems`, the five subsystem-dependent
dimensions (high, medium, low, turret, launcher) are suppressed, rig and
subsystem lines (both true base hull counts — no subsystem modifier grants
rig slots; the modifier set above has no rig entry) still render, and the
block adds a sentence naming what is not shown and why (section 6.2).
Flutter's only tech-3 handling, `AarFitCoverage._dynamicSlotCapacity` in
the Combat Analyzer at `ed698d3` (capacity replaced by the fitted count when
the base count is zero), is a display guard that can never show over-use; it
is explicitly not copied.

### 2.3 Hardpoint consumption (grounded end to end)

`dogmaEffects.jsonl` carries exactly two fitted-marker effects, both pure
markers (`published` true, no modifier payload):

- 40 `launcherFitted` — "Requires a launcher hardpoint".
- 42 `turretFitted` — "Requires a turret hardpoint".

Joined against `dgmTypeEffects.csv.bz2` over published types this session:
effect 40 has 147 carriers (143 category 7 plus 4 category-66 Standup
launchers 35921/35922/47298/47323), effect 42 has 658 carriers (all
category 7), every carrier of either carries slot effect 12 (`hiPower`)
only, and **no type carries both**. Named rows: 2889 200mm AutoCannon II
and 450 Gatling Pulse Laser I carry 42; 499 Light Missile Launcher I, 10631
Rocket Launcher II, and 2410 Heavy Missile Launcher II carry 40; 405
'Micro' Remote Shield Booster, 1182 Auto Targeting System I, and 1547 Small
Proton Smartbomb I are high-slot modules (effect 12) carrying neither — a
real "uses a high slot, uses no hardpoint" population the counting must not
force into a hardpoint bucket. Because both markers are high-slot effects
confirmed by their carrier sets, a hardpoint is consumed exactly when a
counted high-slot row's module carries 40 (launcher) or 42 (turret).

Attribute 47 is not a substitute, measured: 853 published types carry
47 = `1.0` (846 category 7, 7 category 66); the intersection with the 805
effect-40/42 carriers is 802, leaving 51 false positives (27914 Bomb
Launcher I, 24348 Small Tractor Beam I, 60313 Gas Cloud Harvester I, the
medium-slot Ship Scanners 443/1855/6527 — high-slot or not, 47 cannot say
which hardpoint) and 3 false negatives (37450/37451/37452 Ice Mining Lasers
carry 42 and no 47). Module names are barred for the same reason: "Bomb
Launcher" carries no launcher effect. Flutter never grounded any of this —
`turretSlots`/`launcherSlots` were parsed into `ShipType` and never read in
the fitting engine, editor, stats panel, or ESI export, and no per-module
hardpoint determination exists in Flutter fitting (D1 report, re-verified).

Consumption is therefore grounded in the data but is **not in the current
catalogue**: `slotEffects` carries only {11, 12, 13, 2663, 3772}, and 40/42
never appear. This slice emits the markers as new catalogue data
(section 3.1). With that emission locked, turret/launcher lines ship. Had
either side (ship counts or module markers) failed to ground, this design
would ship slot counts only; both sides ground, so none of the seven
dimensions is excluded on evidence grounds.

### 2.4 Which flags occupy which dimension (one rule, three fitting shapes)

Counting is flag-driven, never category- or effect-driven — the shipped
pure-layer rule (`resources.rs` Lo/Med/Hi prefixes, `calibration.rs`
`RigSlot`, `bay_usage.rs` mirroring `section_for_flag` in
`src/ui/fittings.rs:62-80`). The dimension of a fitted row is its flag
prefix: `HiSlot` high, `MedSlot` medium, `LoSlot` low, `RigSlot` rig,
`SubSystemSlot` subsystem. Every other flag (`DroneBay`, `FighterBay`,
`Cargo`, `ServiceSlot0`, `Invalid`, `""`, unknown strings) occupies no slot
dimension. The module's own slot effect is never consulted for occupancy —
a Damage Control II (slot effect 11) under a `HiSlot0` flag occupies a high
slot, exactly as it consumes CPU under that flag in `resources.rs` today.

The three fitting shapes that reach the pure function, from the bodies:

- **Saved (ESI):** flags as ESI returned them, unvalidated remote JSON.
  `src/fitting/write_map.rs` proves the hostile cases are real:
  `is_slot_flag` (lines 88–99) accepts only canonical in-range flags
  (Hi/Med/Lo 0–7, Rig 0–2, SubSystem 0–3, Service 0–7), `build_save_request`
  forces slot quantity to 1 (lines 121–127), and a second claim on the same
  flag is dropped as `DropReason::DuplicateSlot` (lines 20–23; test
  `duplicate_slot_flag_keeps_first_and_drops_rest`). So saved rows can carry
  duplicate flags, out-of-range indices (`RigSlot7`), non-canonical strings
  (`HiSlot00`), and quantities other than 1. Section 4 locks how each counts.
- **EFT import:** `to_character_fitting` (`src/fitting/eft.rs:278-326`)
  synthesizes per-section counters from 0 (`LoSlot{n}`, `MedSlot{n}`,
  `HiSlot{n}`, `RigSlot{n}`, `SubSystemSlot{n}`), always quantity 1 for slot
  sections (`ImportedItem.quantity`, eft.rs:250; stacked module lines are
  rejected with `ImportIssueKind::StackedModule`). Flags are distinct by
  construction, and counters can exceed the ship's layout (imports are not
  capacity-checked) — the over case is a rendering requirement, not an
  error.
- **DNA import:** `parse_dna` expands each segment's quantity into that many
  quantity-1 rows (`src/fitting/dna.rs:215-223`), then the same synthesis
  assigns distinct flags. `587:2889;2::` therefore occupies two high slots,
  not one slot with quantity 2.

## 3. Catalogue extension

### 3.1 New keys and emission rules

Nine new keys, appended after the calibration keys (`upgradeCapacity`,
`upgradeCost`) in this locked order on every row that gains them:
`hiSlots`, `medSlots`, `lowSlots`, `rigSlots`, `maxSubSystems`,
`turretSlotsLeft`, `launcherSlotsLeft`, `turretFitted`, `launcherFitted`.
Every row that gains none of the nine is byte-identical to the current
catalogue, and every emitted row is byte-identical up to the appended
fragment (the calibration emission rule).

**Ship layout keys (seven, numeric):** emitted on category-6 rows only,
sparse by presence — the key is present exactly when a
`dgmTypeAttributes` row exists for (type, attribute), so present `0.0` and
absent stay distinct in the file. Key → attribute: `hiSlots` 14, `medSlots`
13, `lowSlots` 12, `rigSlots` 1137, `maxSubSystems` 1367,
`turretSlotsLeft` 102, `launcherSlotsLeft` 101. The generator parses
`valueFloat` and validates fail-loud, writing nothing on failure (the
calibration pattern, generator lines 569–604): unparseable, duplicated
(type, attribute) row, non-finite, negative, or **non-integral** all fail.
Integrality is locked, not incidental: every value of all seven attributes
in the whole cache (576/576/576/533/4/566/541 rows) is an integral float
this session, and a future fractional value would be a different fact that
must stop the regeneration, not round into the catalogue. Validation scope
mirrors the existing blocks: rows for unpublished types are also parsed and
must pass (the resonance block's scan does the same). Values are emitted as
the parsed floats (`3.0`), so the JSON number type matches every other
catalogue key; conversion to integer counts happens in the pure layer
(section 4.1).

**Module marker keys (two, boolean):** `turretFitted` is emitted as JSON
`true` exactly when the type's `dgmTypeEffects` rows contain effect 42, and
`launcherFitted` exactly when they contain effect 40 — on any published row,
with no category gate. The four category-66 Standup launchers carry real
effect-40 rows; a category-7 gate would make them read as "known to use no
hardpoint," which the data contradicts (the category-66 rig cost precedent:
structure rig 37146 counts through the pure calibration path today).
`false` is never emitted (sparse true-only); absence of the key on a
catalogue row means the generator joined that type's full effect set and
found no marker — a known negative, distinct from the type being absent
from the catalogue entirely (section 4). Booleans are locked over the
alternatives the data audit costed: extending `slotEffects` with 40/42 is
barred — it breaks the `slot_effects.len() <= 1` loader invariant
(`src/names/fitting_types.rs:399-403`) and the first-match slot
classification both importers share; a separate `hardpointEffects` array
costs more bytes (+19,320 vs +16,394, section 3.2) and a second Vec on
every row for a two-valued fact.

Expected key counts (scripted simulation over the committed catalogue and
caches this session; the generator prints and the build verifies them):
`hiSlots` 402, `medSlots` 402, `lowSlots` 402, `rigSlots` 380,
`maxSubSystems` 4, `turretSlotsLeft` 402, `launcherSlotsLeft` 404,
`turretFitted` 658, `launcherFitted` 147.

### 3.2 Size budget (costed)

Current `assets/sde/fitting_types.json`: 3,176,352 bytes. Simulating the
locked emission by exact re-serialisation of the committed file (compact
separators, same float spelling) adds 58,402 bytes. Locked expectation:
**+58,402 bytes → 3,234,754 bytes (+1.84%)**. A regeneration whose byte
delta differs from the sum of its new fragments, or whose final size is not
3,234,754 bytes against these caches, blocks the catalogue commit until the
difference is explained (the calibration size rule).

### 3.3 Generator oracles

New `SLOT_LAYOUT_ORACLES` in the `CALIBRATION_ORACLES` tuple shape
`(typeId, key, expected-or-None)`, a `None` expected meaning the key must be
absent. Every value read from `dgmTypeAttributes.csv.bz2` /
`dgmTypeEffects.csv.bz2` this session — the full layout rows for five
hulls across the size range, the absent pins, the present-zero pins, the
un-chosen-source pin, and the marker/decoy pins:

Ship layouts (12 low, 13 med, 14 high, 101 launcher, 102 turret, 1137 rig,
1367 subsystem):

- 587 Rifter: low 4.0, med 3.0, high 3.0, launcher 2.0, turret 3.0, rig
  3.0, `maxSubSystems` absent.
- 620 Osprey: 3.0 / 5.0 / 5.0 / 2.0 / 1.0 / 3.0 / absent.
- 638 Raven: 5.0 / 7.0 / 7.0 / 6.0 / 4.0 / 3.0 / absent.
- 671 Erebus: 7.0 / 6.0 / 8.0 / 0.0 / 6.0 / 3.0 / absent.
- 29986 Legion (and identically 29984 Tengu, 29988 Proteus, 29990 Loki):
  0.0 / 0.0 / 0.0 / 0.0 / 0.0 / 3.0 / 5.0.

Presence edges:

- 670 Capsule: `lowSlots`/`medSlots`/`hiSlots`/`rigSlots`/`maxSubSystems`
  absent, `launcherSlotsLeft` 0.0 present, `turretSlotsLeft` 0.0 present.
  (33328 identical on presence.)
- 2863 Primae: `turretSlotsLeft` absent, `rigSlots` absent, `medSlots` 0.0,
  `hiSlots` 0.0, `lowSlots` 4.0, `launcherSlotsLeft` 0.0. 2998 Noctis:
  `turretSlotsLeft` absent, high 8.0, rig 3.0.
- 3532 Echelon present-zero pin: `lowSlots` 0.0 and `hiSlots` 0.0 present —
  plus an explicit-zero check in the style of the calibration 588 pin
  (generator lines 955–965): the key must be present as 0.0, never absent.
- 588 Reaper un-chosen-source pin: `rigSlots` absent even though 1154 =
  0.0 exists in the cache — a regression to 1154 (or a 1154 fallback)
  fails here. Sub-check across all seven 1154-only hulls (588, 596, 601,
  606, 33079, 33081, 33083): `rigSlots` absent.
- 597 Punisher: `launcherSlotsLeft` 0.0 present, `turretSlotsLeft` 4.0,
  low 5.0, med 2.0, high 4.0, rig 3.0 (demo hull, section 7).
- Category gates: 2048 Damage Control II, 31668 (rig), 45623 (subsystem),
  and 34 Tritanium carry none of the seven ship keys; 587 carries neither
  marker key.

Markers:

- 2889 200mm AutoCannon II: `turretFitted` true, `launcherFitted` absent.
  499 Light Missile Launcher I: the mirror. 10631 Rocket Launcher II and
  2410 Heavy Missile Launcher II: `launcherFitted` true.
- 405 'Micro' Remote Shield Booster: neither marker (known neither).
- Decoy pins (attribute 47 present, markers absent): 27914 Bomb Launcher
  I, 24348 Small Tractor Beam I, 60313 Gas Cloud Harvester I, and the
  medium-slot 443 Ship Scanner I. False-negative pin: 37450 Ice Mining
  Laser I carries `turretFitted` true with no 47 row.
- Category-66 pin: 35921 Standup Anticapital Missile Launcher I carries
  `launcherFitted` true (no category gate).

### 3.4 Invariants (generator self-validation and loader test)

Generator, catalogue-wide (fail-loud, write nothing), after the calibration
invariants:

- Every present ship layout value is a finite, non-negative, integral
  number (not a bool); each of the seven keys appears only on category-6
  rows. Absence is allowed on any ship — never required to be present (the
  bay/calibration absence rule; capsule hulls are the proof case).
- `maxSubSystems` carriers are exactly {29984, 29986, 29988, 29990} — the
  tech-3 detector's carrier set is pinned, so a cache refresh that adds or
  drops a subsystem-layout hull fails loudly instead of silently widening
  the suppression (section 4).
- `turretFitted`/`launcherFitted`, when present, are JSON `true` only,
  appear only on rows whose `slotEffects` is exactly `[12]`, and never on
  the same row — all three facts hold over the full carrier join today.
- Key counts equal the section 3.1 expectations; the counts print with
  the other key-count lines.

Loader (`src/names/fitting_types.rs`): `FittingType` gains, after
`upgrade_cost`, seven `Option<f64>` fields with `#[serde(rename, default)]`
— key → field: `hiSlots` → `hi_slots`, `medSlots` → `med_slots`,
`lowSlots` → `low_slots`, `rigSlots` → `rig_slots`, `maxSubSystems` →
`max_sub_systems`, `turretSlotsLeft` → `turret_hardpoints`,
`launcherSlotsLeft` → `launcher_hardpoints` (the field reads as what the
value is used as, the `hp` → `hull_hp` precedent) — and two marker fields
`turret_fitted: bool` / `launcher_fitted: bool` with
`#[serde(rename, default)]` (absent key loads as `false`). The numeric
fields stay `Option<f64>` like every other catalogue value: the source is
a float (`valueInt` is always the string `None`), and integrality is
validated at generation (section 3.1), asserted in
`bundled_catalogue_invariants`, and re-checked at conversion in the pure
layer (section 4.1) — three lines of defence, in the order the twins
already use for finiteness.

`bundled_catalogue_invariants` gains a slot-layout block mirroring the
calibration block (lines 626–668): every present layout value finite,
non-negative, and integral (`value.fract() == 0.0`); any layout key implies
category 6; `turret_fitted || launcher_fitted` implies
`slot_effects == [12]`; never both markers true; `max_sub_systems`
present only on the four pinned type ids. Spot pins mirror the generator
oracles in the calibration pin style (lines 841–861): Rifter full layout,
Legion zeros + 5.0, Capsule absent/present split, Primae turret absent,
Reaper rig absent, 2889/499/405 markers, 37450 turret marker, 35921
launcher marker, and no layout keys on 2048/31668/45623.

### 3.5 Determinism proofs (Builder A, same commit as the catalogue)

1. Regenerating against the committed caches on the base tree (pre-change
   generator) produces a byte-identical `fitting_types.json` — the starting
   point is proven, not assumed.
2. Regenerating with the new generator changes only the appended fragments:
   3,176,352 → 3,234,754 bytes, key counts as section 3.1. The observed
   byte counts go in the commit body; a mismatch blocks the commit.
3. Regenerating twice produces a byte-identical file both times.

## 4. Pure API

**Decision: a new module `src/fitting/slot_layout.rs`, not an extension of
`calibration.rs` or `resources.rs`.** Justified from the bodies, on the
calibration precedent (`docs/rig-calibration-design.md` section 4):

- Availability must be independent per block (section 5).
  `FittingResources::Available` is gated on both ship outputs and carries
  skill scaling; `rig_calibration` is gated on one calibration value.
  Folding seven slot dimensions into either would make slot lines vanish
  when unrelated data is missing (Capsule 670 has no calibration and no
  slot rows but proves its hardpoints; Primae 2863 the reverse).
- The seven dimensions are independently present-or-absent per hull
  (section 2.2), which is the `BayUsage` shape (per-dimension `Option`,
  all-`None` → `Unavailable`, `src/fitting/bay_usage.rs:54-72`), not the
  single-budget `CalibrationBudget` shape. The bay slice is the structural
  twin; calibration remains the precedent for "one concern per pure module."
- Fitted counting here is occupancy (distinct flags), a different rule
  from the amount sums in resources/calibration/bays. A separate module
  keeps that divergence visible and separately tested instead of buried
  in a shared accumulator.
- The cost is the small duplication of `usable()` and the ship-resolution
  gate that `bay_usage.rs` and `calibration.rs` already carry.

Locked shape:

```rust
/// One slot or hardpoint dimension: distinct occupied slot flags
/// against the hull's base count for that dimension.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SlotBudget {
    pub used: usize,
    pub capacity: usize,
    /// Hardpoint dimensions only: occupied high slots whose module
    /// is absent from the catalogue, so whether it consumes a
    /// hardpoint cannot be known. Counted in occupied high slots
    /// (one per distinct flag), never silently zero. Slot
    /// dimensions always carry 0.
    pub excluded_modules: usize,
}

impl SlotBudget {
    pub fn remaining(&self) -> i64;  // capacity - used (via i128)
    pub fn is_over(&self) -> bool;   // used > capacity
}

/// Base slot layout usages for one fitting. Each field is `None`
/// when the hull has no usable base count for that dimension —
/// or, on a subsystem-layout hull, when the dimension is set by
/// subsystems rather than the base hull; the other dimensions
/// are unaffected.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SlotLayout {
    pub high: Option<SlotBudget>,
    pub medium: Option<SlotBudget>,
    pub low: Option<SlotBudget>,
    pub rig: Option<SlotBudget>,
    pub subsystem: Option<SlotBudget>,
    pub turret: Option<SlotBudget>,
    pub launcher: Option<SlotBudget>,
    /// True when the hull's layout is subsystem-defined (usable
    /// `max_sub_systems`) and the five subsystem-dependent
    /// dimensions were suppressed. The UI renders its tech-3
    /// sentence exactly when this is true.
    pub subsystem_layout: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlotLayoutOutcome {
    Available(SlotLayout),
    /// The catalogue has no usable slot layout data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

pub fn slot_layout(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> SlotLayoutOutcome;
```

Exported from `src/fitting/mod.rs` exactly as the twins are:
`pub use slot_layout::{slot_layout, SlotBudget, SlotLayout, SlotLayoutOutcome};`
with `pub mod slot_layout;` in alphabetical position. `remaining()` returns
`i64` computed through `i128` (`(capacity as i128 - used as i128) as i64`):
counts are bounded by the fitting's item count and a catalogue capacity, so
the cast cannot truncate in practice, and the signed shape mirrors
`BayBudget::remaining` semantics (negative exactly when over) for the UI
line function.

### 4.1 Capacity conversion

`usable_count(value: Option<f64>) -> Option<usize>` — this module's twin of
`usable()`, stricter by exactly the integrality rule the data forces:
present, finite, `>= 0.0`, `fract() == 0.0`, and `<= 9_007_199_254_740_992.0`
(2^53, the largest consecutive integer an `f64` spells exactly); conversion
is `Some(value as usize)` after those checks (on this app's 64-bit targets
the 2^53 bound keeps the cast exact). Anything else — absent, negative,
NaN, infinite, fractional, or beyond exact-integer range — is no data for
that dimension: the dimension is `None`, never a rounded or clamped count.
A present `0.0` converts to `Some(0)` and renders (section 2.2).

### 4.2 Counting rules (each locked against a named body)

1. **Ship resolution** (`bay_usage.rs:119-141` shape): `ship_type_id > 0`,
   the row resolves via `lookup_by_id`, `category_id == 6` — else
   `Unavailable`. Each dimension's capacity is `usable_count` of its ship
   field (`hi_slots`, `med_slots`, `low_slots`, `rig_slots`,
   `max_sub_systems`, `turret_hardpoints`, `launcher_hardpoints`); absent
   or unusable yields `None` for that dimension only. When every dimension
   is `None`, the outcome is `Unavailable`.
2. **Tech-3 suppression:** when `usable_count(ship.max_sub_systems)` is
   `Some`, the hull is subsystem-layout: `subsystem_layout` is `true` and
   the high, medium, low, turret, and launcher capacities are treated as
   `None` regardless of their present `0.0` values (those zeros describe
   the bare hull before subsystems, section 2.2 — rendering them would
   claim a healthy tech-3 fit is over on every line). Rig and subsystem
   dimensions keep their base counts. Detection is data-driven (the
   pinned 1367 carrier set, section 3.4), never a hardcoded hull list in
   the pure function.
3. **Row eligibility** (the twins' guards): skip rows with `type_id <= 0`;
   `quantity = quantity.max(0)`, skip when 0 — zero and negative quantities
   neither occupy nor exclude.
4. **Occupancy = distinct flags, first row wins.** A slot is occupied once
   per distinct flag string under the dimension's prefix (the section 2.4
   prefix rule, tested by `starts_with`, never via the UI enum — the
   flag-prefix independence precedent). The first eligible row claiming a
   flag occupies it; later rows with the identical flag string are
   ignored entirely. This mirrors `build_save_request`'s model verbatim
   (first claim kept with quantity forced to 1, rest dropped
   `DuplicateSlot`): in ESI's model one flag names one physical slot, so
   two `HiSlot0` rows are one occupied slot with a disputed occupant, and
   the save path already defines the survivor as the first.
5. **Quantity never multiplies.** An occupying row counts 1 toward its
   dimension whatever its (positive) quantity says. This diverges from
   resources/calibration/bays deliberately: those sum *amounts* (tf, MW,
   points, m3), where a stacked row of five really is five items' worth;
   a slot flag is *occupancy*, and every ship-side body agrees quantity
   carries no slot information — synthesis always emits 1 for slot
   sections (eft.rs:250), DNA expands quantity into separate rows before
   synthesis (dna.rs:215-223), and the save mapping forces slot quantity
   to 1 (write_map.rs:121-127). A saved `HiSlot0` row at quantity 5 is
   one occupied high slot whose quantity field is noise, not five slots.
6. **Flag validity is not judged.** Occupancy follows the prefix rule
   the twins use (calibration counts `RigSlot3` today): `RigSlot7`,
   `HiSlot00`, and `HiSlot` with no suffix each occupy one slot of their
   dimension and surface as over-use against the real capacity rather
   than vanishing. `write_map`'s canonical-range check is a save-path
   concern (what ESI will accept), not a counting rule — importing it
   here would silently un-count fitted modules the item list displays.
7. **Hardpoint use:** for each occupied high flag, look up the occupying
   row's catalogue row. `turret_fitted` true → +1 turret used;
   `launcher_fitted` true → +1 launcher used; a present row with both
   false consumes neither (known negative, section 3.1); **no catalogue
   row → the module's hardpoint use cannot be known**: +1 to
   `excluded_modules` on each present hardpoint dimension (the
   resources rule where one unknown module excludes from both CPU and
   power). A `None` hardpoint dimension accumulates nothing — no used,
   no excluded — the bay rule (`bay_usage.rs:167-171`). Only high flags
   are hardpoint candidates: a marker-carrying module under any other
   flag consumes no hardpoint here (hardpoints are a high-slot constraint
   in every body: all 805 marker carriers carry slot effect 12, and
   flag-driven counting never relocates a row).
8. **Slot dimensions need no module lookup.** Occupancy is known from
   the flag alone, so an unknown module (type 999999) under `LoSlot0`
   still occupies a low slot: slot dimensions have no excluded counts
   (`excluded_modules` stays 0) and no excluded UI lines. This is the
   honest inverse of rule 7 — what cannot be known (hardpoint use of an
   unknown module) is disclosed, what can (the flag is occupied) is
   counted.
9. **Order and identity:** counting is a single pass in `fitting.items`
   order (first-claim in rule 4 makes order observable only for hostile
   duplicate rows, where it matches the save path). Distinctness keys on
   the full flag string — `HiSlot0` and `HiSlot00` are two distinct
   occupied strings (rule 6), `HiSlot0` twice is one.
10. **Purity:** pure computation, logs nothing (render cadence; the
    catalogue load already logs counts once). The module doc names its
    sources (dogma 12/13/14/1137/1367/101/102, effects 40/42, the barred
    47/1154 and subsystem modifiers, the tech-3 suppression) and this
    design file, mirroring the twin module docs.

## 5. Availability

Slot layout availability depends only on the ship's seven layout values —
never on CPU/power output data, calibration data, bay capacity data, skill
loading, or the fitting's items (the calibration section-5 rule, with the
bay per-dimension shape underneath). Pinned combinations, all rendering
side by side with the other blocks:

- Capsule 670: slot dimensions `None`, turret and launcher present as
  `Some` counts of 0 → `Available` with exactly the two hardpoint lines,
  while calibration is `Unavailable` (1132 absent) and resources are
  `Available` (every category-6 row carries both outputs by loader
  invariant). Partial data proves partial lines; nothing is zero-filled.
- Primae 2863: turret `None` (102 absent) and rig `None` (1137 absent),
  the other five dimensions `Some` → five lines, while calibration is
  `Unavailable` and resources `Available` (the shipped
  `independence_from_cpu_pg_outputs` pairing, extended).
- A fixture hull with layout values but no CPU/power outputs is
  `Available` here and `ShipNoOutput` in resources (fixture test,
  section 8) — the independence runs both ways even though the bundled
  catalogue cannot produce the second combination.
- Tech-3 hulls: `Available` with rig and subsystem `Some`, the other five
  suppressed `None`, `subsystem_layout` true (section 4 rule 2). They are
  never `Unavailable` and never shown over against bare-hull zeros.
- A fitting with no items still renders the block: every present dimension
  reads `0 of {capacity}`, as the twin blocks render empty fittings.
- `Unavailable` arises only from ship resolution failure (`ship_type_id`
  0/negative/unknown/non-category-6) or every dimension `None`. Catalogue
  load failure renders the no-catalogue sentence under the heading. The
  heading always renders so the view never silently omits the feature.

## 6. UI

### 6.1 Placement: its own block, after Bays

**Decision: slot layout gets its own block** — own heading, disclosure, and
unavailable sentences — rendered immediately after `render_bay_usage` and
before `render_ship_base_stats` at both detail sites. Justified from the
bodies, on the calibration/bay reasoning:

- Availability is independent (section 5) and per-dimension. Inside any
  existing block, seven optional lines plus a tech-3 sentence would need
  their own unavailable and disclosure states nested under another block's
  claims — the exact coupling the bay and calibration own-block decisions
  avoided.
- No skill touches this block, so it takes the `render_bay_usage`
  signature (no levels, no SDE handle) and renders identically for every
  viewing character.
- Order: items → Fitting resources → Rig calibration → Bays → **Slot
  layout** → Ship → Ship resistances → Ship effective hit points. The
  fit-derived constraint blocks (resources, calibration, bays, slots —
  the numbers that answer "does this fit?") stay ahead of the bare-hull
  blocks; the newest fit-derived block appends after the shipped ones
  rather than reshuffling them.

Locked wiring (the only two call sites):

- Imported detail: `render_slot_layout(ui, &synth, fitting_types);`
  directly after the `render_bay_usage` call at `src/ui/fittings.rs:1915`
  and before `render_ship_base_stats` at `:1916`.
- Saved detail: `render_slot_layout(ui, selected, fitting_types);`
  directly after `render_bay_usage` at `src/ui/fittings.rs:2206` and
  before `render_ship_base_stats` at `:2207`.

Signature: `fn render_slot_layout(ui: &mut egui::Ui, fitting:
&CharacterFitting, fitting_types: Option<&FittingTypes>)`. Constants live
with the other blocks' constants in `fittings.rs`:
`FITTINGS_SLOT_LAYOUT_HEADING`, `FITTING_SLOT_LAYOUT_DISCLOSURE`,
`FITTING_SLOT_LAYOUT_TECH3_NOTE`, `FITTING_SLOT_LAYOUT_NO_CATALOGUE`,
`FITTING_SLOT_LAYOUT_NO_SHIP_DATA`. It renders even with no items and logs
nothing (render cadence; the pure function logs nothing).

### 6.2 Verbatim templates

Heading (always renders, including over an unavailable sentence):

```text
Slot layout (base values)
```

Lines, in locked order — Low, Medium, High, Rigs, Subsystems, Turret
hardpoints, Launcher hardpoints — via a pure
`slot_line(label: &str, budget: &SlotBudget) -> String` cloned from
`calibration_line`/`bay_line`, with one locked difference: counts are
integers rendered with `{}` (`usize`/`i64` display), never
`widgets::format_fitting_amount` — that formatter is for `f64` amounts
with units (`src/ui/widgets.rs:69`), and there is no unit word on a slot
count line. Slot labels are the item list's own section words
(`section_label`, fittings.rs:82-93, so the block and the grouped list
above it name the same sets identically); hardpoint labels are the dogma
display names. A `None` dimension contributes no line (the bay rule).

- Under capacity: `{label}: {used} of {capacity} used ({remaining} left)`
- Exactly at capacity: `… used (0 left)` — normal colour (twin rule).
- Over capacity: `{label}: {used} of {capacity} used ({over} over)` where
  `over` is the positive overage — rendered with
  `ui.colored_label(egui::Color32::LIGHT_RED, line)` (twin rule: every
  line of this block carries the over colour when over, all seven labels).
- Present-zero dimension with nothing fitted:
  `High slots: 0 of 0 used (0 left)` — renders like any other value,
  never dashed or hidden (present `0.0` is data, section 2.2).

Per-dimension excluded lines follow the dimension lines in the same order
(the bay `bay_usage_lines` arrangement), hardpoint dimensions only, via
`hardpoint_excluded_line(label, excluded)`: `None` at 0, else —

- 1: `{label} does not count 1 fitted module missing from Mimir's bundled item data.`
- 2+: `{label} does not count {excluded} fitted modules missing from Mimir's bundled item data.`

"Missing from" is locked over the twins' "with no … data" wording because
the only exclusion this block has is a module with no catalogue row at
all (section 4 rules 7–8); a catalogued module without a marker is known
to consume no hardpoint and is never described as missing data. Slot
dimensions render no excluded line ever (`excluded_modules` is always 0).

Tech-3 sentence (renders after the dimension and excluded lines, before
the disclosure, exactly when `subsystem_layout` is true — on those hulls
only the Rigs and Subsystems lines appear above it):

```text
This ship's high, medium, and low slots and its turret and launcher hardpoints are set by its fitted subsystems, which are not applied here, so those lines are not shown.
```

Disclosure (the block's own sentence, naming what is and is not applied):

```text
Base slot and hardpoint counts from Mimir's bundled item data. Slots and hardpoints granted by fitted subsystems are not applied, and no skill, implant, module, rig, or ship bonuses are applied, so these numbers can differ from EVE.
```

Unavailable sentences (heading + one sentence, no lines, no disclosure):

```text
Slot layout unavailable: Mimir's bundled item data failed to load.
Slot layout unavailable: Mimir's bundled item data has no slot layout data for this fitting's ship.
```

A lines helper `slot_layout_lines(layout: &SlotLayout) -> Vec<(String, bool)>`
in the `bay_usage_lines` shape carries the over flag per line; excluded
lines append after the seven dimension positions in dimension order with
`false`. The tech-3 sentence is not part of that vec (it is keyed on
`subsystem_layout`, not on a budget) and is rendered by
`render_slot_layout` between the lines and the disclosure.

## 7. Demo story (hand-derived from quoted rows)

All inputs from the committed `assets/demo/fittings.json` (read this
session) and cache rows quoted in section 3.3. Rifter 587 base layout:
low 4, med 3, high 3, rig 3, turret 3, launcher 2, no subsystem dimension.
Counting follows section 4 (flag occupancy; module identity matters only
for hardpoints).

**Demo Brawler** (character 90000001, Rifter): `LoSlot0` Damage Control II
(2048) → low 1. `MedSlot0` (2049, a blueprint) and `MedSlot1` (1225,
Crokite) → medium 2 — flag-driven: neither is a medium module, both occupy
medium flags. `HiSlot0`/`HiSlot1` (2050 shield hardener, catalogued with
no hardpoint marker) → high 2, turret 0, launcher 0, excluded 0.
`RigSlot0` (1535, absent from the catalogue) → rig 1 (occupancy needs no
module data; slot dimensions never exclude). `SubSystemSlot0` (28270)
counts toward nothing: the Rifter has no subsystem dimension, so there is
no subsystem line. Drone/fighter/cargo/`Invalid` rows occupy no dimension.

```text
Slot layout (base values)
Low slots: 1 of 4 used (3 left)
Medium slots: 2 of 3 used (1 left)
High slots: 2 of 3 used (1 left)
Rigs: 1 of 3 used (2 left)
Turret hardpoints: 0 of 3 used (3 left)
Launcher hardpoints: 0 of 2 used (2 left)
Base slot and hardpoint counts from Mimir's bundled item data. …
```

(Arithmetic: 4 − 1 = 3, 3 − 2 = 1, 3 − 2 = 1, 3 − 1 = 2, 3 − 0 = 3,
2 − 0 = 2.)

**Mission Runner** (90000001, Rifter): `HiSlot0` 2048 (a low module under a
high flag, catalogued, no marker) → high 1, turret 0, launcher 0;
`LoSlot0` 2049 → low 1. Lines: Low 1/4 (3 left), Medium 0/3 (3 left),
High 1/3 (2 left), Rigs 0/3 (3 left), Turret 0/3 (3 left), Launcher 0/2
(2 left).

**Demo Runner** (90000002, Punisher 597 — low 5, med 2, high 4, rig 3,
turret 4, launcher 0 present): `LoSlot0` 2048, `HiSlot0` 2050, `MedSlot0`
1225. Lines: Low 1/5 (4 left), Medium 1/2 (1 left), High 1/4 (3 left),
Rigs 0/3 (3 left), Turret 0/4 (4 left), Launcher 0/0 (0 left) — the demo's
present-zero exhibit: a real `0 of 0` line, not a missing dimension.

**Sample EFT** (the calibration test's "Sample Brawler" text, reused as a
synthesis pin): Rifter with 2 low, 2 medium, 3 × 200mm AutoCannon II
(2889, turret marker) high, 1 rig → Low 2/4 (2 left), Medium 2/3 (1 left),
High 3/3 (0 left), Rigs 1/3 (2 left), Turret 3/3 (0 left), Launcher 0/2
(2 left).

The demo exhibits the counted, present-zero, flag-over-module-identity,
unknown-module-occupies, and no-subsystem-line cases. It has no tech-3
hull and no over-layout fit; those are pinned in unit tests instead
(section 8), and the demo data is not modified by this slice.

## 8. Test plan

Numbers are hand-derived literals with the arithmetic in comments, citing
cache rows — never built from the constants under test (the standing rule;
precedent `calibration.rs:171-174`). Each item names its file.

**Generator** (`scripts/sde/generate_fitting_types_sde.py`, run manually;
self-validating):

1. `SLOT_LAYOUT_ORACLES` from section 3.3, including the Echelon
   explicit-zero check and the seven-hull 1154 sub-check; catalogue-wide
   invariants from section 3.4; key-count print; determinism proofs
   1–3 from section 3.5 (byte counts quoted in the commit body).

**Loader** (`src/names/fitting_types.rs`):

2. `bundled_catalogue_invariants` slot-layout block + spot pins
   (section 3.4).
3. Fixture parse: a row with `"hiSlots":3.0,"turretFitted":true` loads
   into `hi_slots == Some(3.0)`, `turret_fitted == true`; a row without
   the new keys loads with all `None`/`false` (old-catalogue tolerance
   that the twins' `default` pattern already proves, pinned here).

**Pure layer** (`src/fitting/slot_layout.rs`):

4. Hull-only Rifter: six `Some` capacity pins asserted literally per
   field (low 4, medium 3, high 3, rig 3, turret 3, launcher 2),
   subsystem `None`, `subsystem_layout` false, all used 0,
   `remaining()` equal to each capacity, none over.
5. Non-modal capacities (the anti-fallback pins; any hidden default like
   Flutter's `?? 0` or a hardcoded layout fails): Raven 638 = 5/7/7/3,
   turret 4, launcher 6; Erebus 671 = 7/6/8/3, turret 6, launcher 0;
   Osprey 620 turret 1, launcher 2.
6. Present-zero renders: Echelon 3532 high/low `Some` capacity 0, used 0,
   not over; Punisher 597 launcher `Some(0)`; one fitted high row on
   Echelon → used 1 of 0, `is_over`, `remaining() == -1`.
7. Absent is not zero: Capsule 670 → `Available` with low/med/high/rig/
   subsystem `None`, turret/launcher `Some` 0-capacity budgets; Primae
   2863 → turret `None`, rig `None`, launcher `Some(0)`; Noctis 2998 →
   turret `None`, high 8.
8. Occupancy counting: distinct flags (two `HiSlot0` rows → high used
   1); first-row-wins hardpoint identity (`HiSlot0` turret module 2889
   then `HiSlot0` launcher module 499 → turret 1, launcher 0; reversed
   order → the mirror); quantity ignored (one `HiSlot0` row quantity 5 →
   high 1, turret 1 for 2889 — not 5); `HiSlot00` distinct from
   `HiSlot0` (→ 2); `RigSlot7` occupies (rig 1, over on a 0-rig hull or
   counted toward over on Rifter with 3 more rigs: 4 of 3, remaining
   −1); quantity 0 and −5 rows occupy nothing; `type_id` 0/−1 rows
   occupy nothing; non-slot flags (`DroneBay`, `Cargo`, `Invalid`,
   `ServiceSlot0`, `""`, `Foo`) occupy nothing and exclude nothing.
9. Hardpoint counting: 2889 → turret; 499 → launcher; 405 → neither
   (excluded 0); unknown 999999 under `HiSlot0` → high 1, turret and
   launcher excluded 1 each; unknown under `LoSlot0` → low 1, no
   hardpoint exclusion; marker module under `LoSlot0` (2889) → low 1,
   turret 0. Category-66 pin: 35921 under `HiSlot0` → launcher 1.
   Decoy pin: 27914 Bomb Launcher I under `HiSlot0` → high 1, launcher
   0, excluded 0 (effect, not name or 47).
10. Over/exact per shape: exactly at capacity (3 distinct high flags on
    Rifter → 3 of 3, remaining 0, not over); over (4 distinct → over,
    remaining −1); hardpoint over tracked per dimension (Rifter with 4
    distinct high flags all carrying 2889 → high 4 of 3 over and turret
    4 of 3 over, launcher 0 of 2 not over).
11. Tech-3: Legion 29986 empty → rig `Some` 3, subsystem `Some` 5,
    high/med/low/turret/launcher `None`, `subsystem_layout` true.
    Legion with fitted highs and 5 subsystem rows → still no high line
    data (`None`), subsystem used 5 of 5 (0 left); 6 distinct
    `SubSystemSlot` rows → over, remaining −1. No non-tech-3 hull in
    the catalogue sets `subsystem_layout` (pin on Rifter + Raven).
12. Ship failures: 999999, 2048 (category 7), 35825 (category 65), 0, −1
    → `Unavailable`.
13. Fixture defences (`FittingTypes::from_json`): capacity `0.0` →
    `Some(0)`; `−1.0`, absent → dimension `None`; **fractional `2.5` →
    dimension `None`** (integral lock); `1e20` → `None` (exact-range
    lock); a hull whose every layout key is unusable → `Unavailable`;
    fixture `maxSubSystems: 5.0` on a non-tech-3 id still triggers
    suppression (data-driven, not an id list).
14. Independence: fixture hull with layout but no outputs → slot
    `Available` + resources `ShipNoOutput`; bundled Primae 2863 → slot
    `Available` + calibration `Unavailable`; bundled Capsule 670 → slot
    `Available` (hardpoints) + calibration `Unavailable` + resources
    `Available`.
15. Synthesis paths: the section-7 Sample EFT through `parse_eft` →
    `to_character_fitting` → the six pinned lines' budgets; DNA
    `587:2889;2:499;1::` → high 3 of 3, turret 2 of 3, launcher 1 of 2
    (2× 2889 turret + 1× 499 launcher by expansion); EFT with 4 high
    modules on a Rifter → high over (imports are not capacity-checked;
    the block shows it).

**UI** (`src/ui/fittings.rs`):

16. `slot_line` templates literal: under (`High slots: 2 of 3 used
    (1 left)`), exact (`0 left`), over (`(1 over)`), present-zero
    (`0 of 0 used (0 left)`), each label of the seven spelled literally.
17. `hardpoint_excluded_line` 0/1/2+ literals for both labels.
18. Heading/disclosure/tech-3/unavailable constants asserted verbatim
    (twin style, e.g. fittings.rs:4736); `slot_layout_lines` ordering:
    dimension lines in locked order with `None` skipped, excluded lines
    after, over flags paired.
19. Demo pins (section 7) over the real demo bundle: Demo Brawler,
    Mission Runner, Demo Runner line-for-line through the pure function
    (the calibration demo-pin precedent — reads committed demo data,
    modifies none).

**Gates at every commit:** `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`, `cargo build`
(all from a clean checkout of the commit). No new logging anywhere in the
pure or render paths; the only `[FITTING]`-tagged lines remain the
existing catalogue-load counts.

## 9. Integrator list

- Re-export in `src/fitting/mod.rs` (section 4); no consumer changes —
  slot layout does not feed EFT export, DNA export, the save mapping, or
  any other block. It is a new read-only view over existing inputs.
- No `import` of the UI enum into the pure layer, and no import of pure
  flag helpers into the UI: each side keeps its own prefix test (the twin
  independence rule, pinned by the disjoint flag tests on both sides).
- The block consumes the already-loaded `fitting_types` handle at both
  detail sites: no new load, no demo-data change, no state field, no ESI
  or scope change, no storage change.
- Skills are not threaded in: `render_slot_layout` is not given
  `levels`, so no viewing-character data can move these numbers; the
  saved and imported calls pass exactly what `render_bay_usage` receives.
- `docs/engineering-journal/` entries ride in the implementation commits
  per repo practice if the build surfaces a non-obvious learning; the
  design itself needs none at lock time.
- Later slices that must not be assumed by this one: subsystem-granted
  layout computation (would replace the tech-3 suppression with real
  numbers plus its own disclosure), slot-aware fitting editor validation,
  fighter-tube counts. Each needs its own evidence pass; none may reuse
  this block's base numbers as effective values.

## 10. Exclusions (explicitly not in this slice)

- Any subsystem-granted slot/hardpoint computation (attributes 1368/
  1369/1374/1375/1376 and the effects that apply them are never read);
  tech-3 hulls get the section 4 suppression, nothing more.
- Any other modifier: skills, implants, module/rig/ship bonuses. There is
  no "with skill bonuses" variant and no scaling hook.
- Attribute 1154 in any role (not emitted, not a fallback), attribute 47,
  64, 106, 212, 1366, 2056, and name-based hardpoint guessing — section
  2's barred list, enforced by oracle pins rather than by convention.
- Service slots, fighter tubes/squadrons, and drone counts as dimensions
  (bays already cover drone/fighter volume and bandwidth).
- Percentages, bars, icons, or any rendering beyond the twin line format;
  no fitting validity verdict (over-use is shown, never judged beyond the
  red over line).
- Any editor/placement validation, import rejection, or save-path change
  based on slot counts — over-layout fittings still import, display, and
  save exactly as today.
- Any change to resources, calibration, bays, ship-stat blocks, EFT/DNA
  parsing or synthesis, demo data, ESI models, or scopes.
- Hardpoint lines without the section 3 marker emission: if the marker
  keys fail their oracles during build, the slice ships slot lines only
  and the failure is reported — never a name-based substitute.

## 11. Ownership and commit split

Three workstreams, two builders then one integrator. Small atomic
commits, `type(scope): description`, no attribution lines. Each commit
passes the section-8 gates.

1. **Design (this document).** `docs(slots): lock the slot layout design`
   — adds only `docs/slot-layout-design.md`.
2. **Builder A — catalogue and pure calculation.** Owns exactly
   `scripts/sde/generate_fitting_types_sde.py`,
   `assets/sde/fitting_types.json` (regenerated), `src/names/fitting_types.rs`
   (fields, invariants, pins), `src/fitting/slot_layout.rs` (new), and
   `src/fitting/mod.rs` (two lines). Commits:
   `feat(sde): emit ship slot layout and hardpoint markers` (generator +
   catalogue + loader, with section 3.5 byte evidence in the body) then
   `feat(fitting): add pure slot layout calculation` (module + re-export
   + tests 4–15). Builder A touches no file under `src/ui/` and no demo
   data.
3. **Builder B — rendering and demo pins.** Owns exactly
   `src/ui/fittings.rs` (constants, `slot_line`,
   `hardpoint_excluded_line`, `slot_layout_lines`, `render_slot_layout`,
   both call sites, tests 16–19). One commit:
   `feat(ui): show slot layout in both fitting details`. Builder B starts
   from Builder A's landed commits (the render compiles against the pure
   API) and touches nothing under `src/fitting/`, `src/names/`, or
   `scripts/`.
4. **Integrator.** Owns no source file by default. Verifies: clean-tree
   gates on the branch head; regeneration determinism re-run
   (byte-identical, 3,234,754 bytes); the section-7 demo smoke in both
   detail views against the demo bundle; a tech-3 smoke (an imported
   Legion fitting shows Rigs/Subsystems lines plus the tech-3 sentence
   and no bare-hull over lines); and that no push or merge happens — the
   parent does that.

Sequencing: design → Builder A (two commits) → Builder B (one commit) →
integrator checks. File overlap between builders is zero; the only shared
surface is the section-4 API shape, locked here so neither builder
improvises it.



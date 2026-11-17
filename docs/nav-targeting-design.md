# Ship navigation and targeting (base values) — design

Status: locked for the `feat/rust-nav-targeting` slice. Base:
`develop` at `312d486` (merge of #585), clean, 630 tests. Follows
the shipped patterns of #578 (`src/fitting/ship_stats.rs`), #579
(resistances), #580 (effective hit points), and #581/#582 (recharge
durations and peak rates): bare-hull base values only, no modifier
of any kind, absent data omitted, a present `0.0` rendered.

Every identity, unit, coverage count, and oracle below was verified
this session from an inspected body: the pinned SDE zip
(`scripts/sde/eve-online-static-data-3503375-jsonl.zip`,
`dogmaAttributes.jsonl` / `dogmaUnits.jsonl`), the committed caches
(`scripts/sde/dgmTypeAttributes.csv.bz2`, `invTypes.csv.bz2`), the
bundled catalogue (`assets/sde/fitting_types.json`, 3,234,754
bytes, 404 category-6 rows), Flutter at `ed698d3` via `git show`,
and the current Rust bodies named inline. Nothing is recalled from
general EVE knowledge.

## 1. Goal and value ranking

Add one new block, "Ship navigation and targeting (base values)",
to both fitting detail views (imported and saved), showing the
bare hull's base navigation and targeting statistics: warp speed,
align time, mass, signature radius, targeting range, scan
resolution, sensor strength, and maximum locked targets.

Ranking, in order: **never a number whose unit or formula is not
grounded in an inspected body** (an ungrounded candidate is
excluded and recorded, section 10) > **honest absence** (absent
renders nothing, present `0.0` renders; never a zero, dash, or
placeholder for no data) > **base-only labeling** (every number
under a "(base values)" heading with the block's own disclosure) >
**reuse** (the `ship_stats.rs` Outcome/`usable` shape, the
resistance segment join, `format_fitting_amount`, the slot-layout
integer-count rendering).

## 2. Locked grounded set

Coverage is over the 404 category-6 catalogue ships. Every wanted
cache row carries `valueFloat` with `valueInt` `None`. Units are
verbatim `dogmaUnits` `displayName.en` unless a conversion is
named.

| Field (pure) | Source | Unit (verbatim) | Coverage / range |
|---|---|---|---|
| `warp_speed` | dogma 600 `warpSpeedMultiplier` under the 1281 invariant (§2.1) | `AU/s` (unit 144, via 1281) | 404/404 nonzero, 1.5–5.0 |
| `align_time_secs` | derived (§2.2), no catalogue key | `s` (derived seconds) | wherever agility+mass usable |
| `agility` | dogma 70 `agility`, display "Inertia Modifier" | `x` (unit 104) — align input only, not displayed (§2.3) | 404/404 nonzero, 0.03–1000.0 |
| `mass` | `invTypes.mass` column (§2.4) | `kg` (unit 2, via dogma 4) | 404/404 nonzero, 5,000–2.4e9 |
| `signature_radius` | dogma 552 `signatureRadius` | `m` (unit 1) | 404/404 nonzero, 20.0–24,800.0 |
| `max_target_range_km` | dogma 76 `maxTargetRange`, raw metres / 1000 in the pure layer | `km` (converted, §2.5) | 404 present, 9 present-zero, max 5,800,000 m |
| `scan_resolution` | dogma 564 `scanResolution` | `mm` (unit 102) | 390 present, 8 present-zero, 14 absent |
| `sensor_radar` | dogma 208 `scanRadarStrength` | `points` (unit 120) | 404 present, 105 nonzero |
| `sensor_ladar` | dogma 209 `scanLadarStrength` | `points` | 404 present, 88 nonzero |
| `sensor_magnetometric` | dogma 210 `scanMagnetometricStrength` | `points` | 404 present, 110 nonzero |
| `sensor_gravimetric` | dogma 211 `scanGravimetricStrength` | `points` | 404 present, 107 nonzero |
| `max_locked_targets` | dogma 192 `maxLockedTargets`, no `unitID` (a count) | none — bare integer | 404 present, 11 present-zero, max 14 |

Flutter cross-check (`dogma_attributes.dart` at `ed698d3`):
`mass = 4`, `inertiaModifier = 70`, `warpSpeedMultiplier = 600`,
`maxTargetRange = 76`, `scanResolution = 564`,
`maxLockedTargets = 192`, `signatureRadius = 552` — the same ids.
Flutter has **no** sensor-strength constant and renders no sensor
line; the four sensor identities rest on the pinned SDE bodies
alone (names, display names, descriptions, unit 120), which is
grounding enough to ship, with presentation decided in §2.6.

### 2.1 Warp speed: the `AU/s` label and the 1281 invariant

Dogma 600's own unit is 104 Multiplier, display `x`. Rendering
600 with the label `AU/s` on that authority alone would be
ungrounded. The label is instead grounded by two inspected
bodies together:

- Dogma 1281 `baseWarpSpeed`, display "Ship Warp Speed", unit 144
  Warp speed with verbatim display `AU/s`, description "Just for
  the UI to display the ship warp speed." In the committed cache
  it is present on all 404 ships and constant at `1.0` (547
  type-rows total, one distinct value).
- Flutter `dogma_engine.dart` at `ed698d3` (align/warp block,
  quoted verbatim in §2.2): warp speed is "`baseWarpSpeed` …
  times the warp speed multiplier, i.e. the multiplier itself,
  in AU/s", and `stats_panel.dart` renders
  `'${stats.warpSpeed.toStringAsFixed(1)} AU/s'`.

Locked treatment: the displayed warp speed is the closed form
`baseWarpSpeed × warpSpeedMultiplier`. The generator asserts
1281 == 1.0 on every category-6 row as a fail-loud tripwire
(§3) and emits only `warpSpeedMultiplier`; the pure layer carries
it as `warp_speed` in AU/s under that invariant, recorded at the
field. If a future SDE ever ships a non-1.0 `baseWarpSpeed`, the
generator fails before any wrong number can render, and emitting
1281 becomes a new design decision. Emitting 1281 today is
rejected: a constant 1.0 on 404 rows carries no information.
Rendering 600 with unit `x` is rejected: "Warp speed: 5.0 x"
tells the reader nothing, and the AU/s reading is grounded by
the two bodies above.

### 2.2 Align time: grounded formula, quoted verbatim

Align time ships **only** because its formula exists in an
inspected in-repo body. Flutter `dogma_engine.dart` at `ed698d3`,
align/warp block, verbatim:

```dart
    // Align time and warp speed follow pyfa's closed-form definitions.
    // align = -ln(0.25) * agility * mass / 1e6 seconds; warp speed is
    // baseWarpSpeed (absent from current SDE and ESI data, verified
    // 2026-09-07) times the warp speed multiplier, i.e. the multiplier
    // itself, in AU/s.
    final massKg = attr(DogmaAttributes.mass);
    final agility = attr(DogmaAttributes.inertiaModifier);
    final alignTime = massKg > 0 && agility > 0
        ? -log(0.25) * agility * massKg / 1e6
        : 0.0;
```

Flutter feeds post-modifier `attr()` values into this line; the
Rust port substitutes base agility and base mass (the
no-modifiers lock). Bare-oracle equivalence: Flutter test
"align time and warp speed follow the pyfa closed forms"
(`dogma_engine_test.dart`) uses an empty fitting with the comment
`// -ln(0.25) * 3.2 * 1067000 / 1e6` and expects
`closeTo(4.7334, 0.001)` — base and adjusted coincide there, and
the inputs match the committed caches (Rifter agility 3.2, mass
1,067,000).

Locked Rust form, computed in the pure layer:

```text
align_time_secs = -ln(0.25) * agility * mass / 1_000_000
```

Guards (the #582 peak-rate precedent: Flutter's `0.0` sentinel
conflates "not computable" with a real zero, so Rust maps it to
absence): `Some` only when agility and mass are both present,
finite, and `> 0`, and the result is finite; otherwise `None`
and the line is omitted. On real data the guard never fires
(agility and mass are nonzero on 404/404 ships). The unit is
derived seconds — agility is a multiplier, mass is kilograms,
the Flutter comment names the result "seconds", and the panel
renders `s` — so the line unit is `s`, not a dogma unit.

### 2.3 Agility: shipped as data, not displayed

Dogma 70 is fully grounded (unit `x`, display "Inertia
Modifier") and is emitted and carried as the align input. It is
**not** given a display line, for two recorded reasons: Flutter
carries `inertiaModifier` on its stats object but never renders
it (no panel row exists to mirror), and the shared one-decimal
formatter (`widgets::format_fitting_amount`) would render real
hull values misleadingly — Erebus 0.037 → `0.0 x`, Raven 0.12 →
`0.1 x` — a present nonzero reading as zero. Inventing a
higher-precision formatter for one line is out of scope. Align
time, which Flutter does display, carries the usable
information. Revisit if a multi-decimal formatter ever ships.

### 2.4 Mass: the invTypes column, never dogma 4

Dogma 4 `mass` (unit 2 Mass, display `kg`) has **zero** rows on
catalogue ships in `dgmTypeAttributes.csv.bz2` and only 5 rows
in the whole cache, all on unpublished NPC types — the same
decoy shape as dogma 38/161 in the bay slice. A dogma-4 read
would be empty for every ship. The value lives in the
`invTypes.csv.bz2` `mass` column: nonempty and nonzero on
404/404 ships. Flutter's own generator proves the route
("mass lives in the invTypes column, not in dgmTypeAttributes,
but dogma consumers (align time) need it as attribute 4"), and
its engine names the value `massKg`. Locked: the generator
reads the invTypes column on category-6 rows only (the
`cargoCapacity` precedent) and never reads dogma 4. The `kg`
label is grounded via dogma 4's unit 2 plus Flutter's `massKg`
naming; that route is recorded here because no ship row ties
them directly. Mass is displayed (a new display line — Flutter
carries `massKg` but never renders it) because value and unit
are grounded and the formatter handles the range honestly with
grouping (`2,100,000,000.0 kg`); it is also the align input.

### 2.5 Targeting range conversion

Dogma 76 is raw metres (unit 1, display `m`). Flutter's panel
renders `(targetRange / 1000)` in `km`. Locked: the catalogue
stores raw metres; the pure layer converts `/ 1000.0` into
`max_target_range_km` (the #581 milliseconds-to-seconds shape);
the line unit is `km`. Raw metres would render `22,500.0 m`
where every inspected display body says `22.5 km`. A present
`0.0` (Capsule 670, the freighter set) converts to `0.0 km` and
renders — it is a known zero, not missing data.

### 2.6 Sensor strength presentation: one joined line, all four

The four attributes (208–211) are each present on 404/404
ships. Exactly one is positive on 402 ships; all four are
positive on exactly two (Apotheosis 29266 at 10.0 each, Council
Diplomatic Shuttle 34496 at 8.0 each). Flutter presents none of
them, so the presentation is decided from the nearest Rust
body: the resistances block (#579) renders one line per layer
with four segments joined by `, `, present `0.0` segments
included, absent segments omitted. Locked presentation mirrors
it exactly — one line:

```text
Sensor strength: RADAR 0.0 points, Ladar 8.0 points, Magnetometric 0.0 points, Gravimetric 0.0 points
```

Segment labels are the sensor names from the SDE display names
("RADAR Sensor Strength", "Ladar Sensor Strength",
"Magnetometric Sensor Strength", "Gravimetric Sensor
Strength") with the shared "Sensor Strength" suffix carried by
the line label instead. Segment order is attribute-id order
(208, 209, 210, 211). Rejected alternatives, with reasons:
strongest-only (an invented aggregation that would hide the
two all-four hulls and every present zero); positive-only
segments (a present `0.0` is a known "no such sensor" and the
standing rule renders it; dropping it would also make the line
shape vary by hull for no grounded reason); four separate lines
(no precedent — the four-value precedent in this codebase is
the joined resistance line, and four lines would triple the
block's height to say the same thing). If all four are absent
(never on real data), the line is omitted.

### 2.7 Decoys barred

Never emitted, never read, each with its evidence:

- Dogma 1281 `baseWarpSpeed` as a value source — constant 1.0;
  tripwire only (§2.1).
- Dogma 4 `mass` as a value source — zero ship rows (§2.4).
- Dogma 1169 `scanGenericStrength`, 1908 `scanWormholeStrength`
  — zero type-rows anywhere in the cache.
- Sensor adjacents 238–241 (ECM jammer strength bonuses),
  1027–1030 (percent), 1473–1476 (multiplier), 1136
  `scanAllStrength`, 1371 — none is a per-type ship strength.
- Agility adjacents 151 `agilityBonus`, 169
  `agilityMultiplier`, 559 `Inertia`, 2690 `agilityBonusAdd` —
  zero ship rows.
- Signature adjacents 554, 652, 973, 983 `signatureRadiusAdd`,
  1477 — zero ship rows; 983/796 `massAdd` are Flutter
  modifier inputs, forbidden in a base-only slice.
- Target-count adjacents 235 (bonus), 3034 (multiplier), 193
  `maxAttackTargets` — zero ship rows.
- Dogma 101 `launcherSlotsLeft` — slot-layout hardpoints,
  already shipped; not targeting. 79 `scanSpeed`, 765
  `scanRange` — not scan resolution.

## 3. Catalogue: generator

In `scripts/sde/generate_fitting_types_sde.py`, mirroring the
slot-layout (#585) seams:

- `NAV_TARGETING_ATTR_IDS = {600, 70, 552, 76, 564, 208, 209,
  210, 211, 192}` plus one named constant per attribute, each
  with a comment citing its `dogmaAttributes` name/display name
  and `dogmaUnits` display, and the decoy bars of §2.7.
- 1281 is read **only** for the tripwire: every category-6 row
  must carry `baseWarpSpeed == 1.0`, else `fail(...)`. It is
  never emitted. Dogma 4, 1169, and 1908 are never read; a
  comment records why, beside the 38/161 precedent.
- `valueFloat` parse loop, fail-loud on duplicate rows,
  unparseable, non-finite, or negative values (existing shape).
  Attribute 192 additionally fails loud when non-integral
  (`fract != 0`), because the pure layer renders it as an
  integer count; all 404 committed rows are integral.
- `mass` from the `invTypes` `mass` column on category-6 rows
  only, through the same fail-loud float parse as
  `cargoCapacity` (unparseable / non-finite / negative fails).
- Sparse emission by presence on category-6 rows only, 11 keys
  appended after `launcherFitted` in this locked order:
  `warpSpeedMultiplier`, `agility`, `signatureRadius`,
  `maxTargetRange`, `scanResolution`, `scanRadarStrength`,
  `scanLadarStrength`, `scanMagnetometricStrength`,
  `scanGravimetricStrength`, `maxLockedTargets`, `mass`.
  Keys are the SDE dogma names verbatim; `mass` keeps the
  invTypes column name (the `volume` precedent).
- Expected emission counts (`NAV_TARGETING_EXPECTED_COUNTS`):
  404 for every key except `scanResolution` at 390; `mass` 404.
- `NAV_TARGETING_ORACLES`: `(typeId, key, expected-or-None)`
  tuples read from the committed caches (hand values in §7),
  including explicit-zero pins (Capsule 670 `maxTargetRange`
  0.0, `maxLockedTargets` 0.0), absence pins (Capsule 670 and
  Zephyr 2078 `scanResolution` → `None`), a non-ship pin (a
  category-7 module and commodity 34 carry none of the 11
  keys), and the all-four-positive sensor pins (Apotheosis
  29266).

Size: the 11 keys add 106,580 bytes under the existing compact
separators and float formatting, 3,234,754 → 3,341,334 bytes
(simulated during discovery from the committed caches; the
regeneration diff must land on this number or the discrepancy
is investigated before commit, never waved through). Align
time adds zero bytes (derived).

## 4. Catalogue: loader

In `src/names/fitting_types.rs`, 11 new fields on `FittingType`,
all `Option<f64>`, `#[serde(rename = "…", default)]`, serde
name verbatim from §3, field names reading as the value:
`warp_speed_multiplier`, `agility`, `signature_radius`,
`max_target_range`, `scan_resolution`,
`scan_radar_strength`, `scan_ladar_strength`,
`scan_magnetometric_strength`, `scan_gravimetric_strength`,
`max_locked_targets`, `mass`. One comment block cites this
design, the dogma ids, the invTypes source of `mass`, and the
never-read decoys (the bay/slot comment shape).

Bundled-catalogue invariants extended beside the existing ones:
every present value finite and `>= 0.0`; `max_locked_targets`
present values integral (`fract() == 0.0`); every present value
on a category-6 row only; non-ship rows carry none; spot pins
for Rifter 587 and Punisher 597 literals (§7), Capsule 670
present-zero and absent-scan-resolution pins.

## 5. Pure API

New sibling module `src/fitting/ship_nav_targeting.rs`.
Extending `ShipBaseStats` is rejected: it would change a
shipped struct and couple this block's availability to #578's
seven fields, against the resistances/EHP precedent that each
block ships its own struct, outcome, and heading with
availability independent of its neighbours. One module (not
two) because this is one slice and one block; Flutter's two
panel sections become two ordered line groups inside it (§6).

```rust
pub struct ShipNavTargeting {
    pub warp_speed: Option<f64>,          // AU/s, §2.1
    pub align_time_secs: Option<f64>,     // derived, §2.2
    pub agility: Option<f64>,             // align input, §2.3
    pub mass: Option<f64>,                // kg
    pub signature_radius: Option<f64>,    // m
    pub max_target_range_km: Option<f64>, // converted, §2.5
    pub scan_resolution: Option<f64>,     // mm
    pub sensor_radar: Option<f64>,        // points
    pub sensor_ladar: Option<f64>,        // points
    pub sensor_magnetometric: Option<f64>,// points
    pub sensor_gravimetric: Option<f64>,  // points
    pub max_locked_targets: Option<i64>,  // count
}
pub enum ShipNavTargetingOutcome { Available(ShipNavTargeting), Unavailable }
pub fn ship_nav_targeting(fitting: &CharacterFitting, catalogue: &FittingTypes)
    -> ShipNavTargetingOutcome
```

Semantics, locked, mirroring `ship_stats.rs:55–98`: lookup by
`ship_type_id > 0`; `category_id != 6` → `Unavailable`; each
`f64` field through the same `usable` guard (present, finite,
`>= 0.0`; present `0.0` stays `Some(0.0)`); targeting range
converted `m / 1000.0` after the guard;
`max_locked_targets` through an integral guard (finite,
`>= 0.0`, `fract() == 0.0`, cast-safe) → `Option<i64>`;
`align_time_secs` from the private helper over the guarded
agility and mass (§2.2 guards; re-checks finiteness/sign and
result finiteness itself, the `ship_ehp` precedent, so direct
construction cannot smuggle a NaN into a rendered line);
all-`None` across the eleven catalogue-backed fields →
`Unavailable` (align, being derived from two of them, does not
count separately). Items are never read. The module logs
nothing: pure, render-cadence, same header contract as
`ship_stats.rs` (base-only sentence naming the excluded
modifiers, design pointer, purity sentence).

## 6. UI wording (locked verbatim)

In `src/ui/fittings.rs`, beside the #578/#579/#580 blocks.
Constants:

```text
FITTINGS_SHIP_NAV_TARGETING_HEADING = "Ship navigation and targeting (base values)"
FITTING_SHIP_NAV_TARGETING_DISCLOSURE = "These are the bare hull's base navigation and targeting values from Mimir's bundled item data. Fitted modules, rigs, subsystems, skills, implants, and ship bonuses are not applied, so these numbers can differ from EVE."
FITTING_SHIP_NAV_TARGETING_NO_CATALOGUE = "Ship navigation and targeting unavailable: Mimir's bundled item data failed to load."
FITTING_SHIP_NAV_TARGETING_NO_SHIP_DATA = "Ship navigation and targeting unavailable: Mimir's bundled item data has no navigation or targeting data for this fitting's ship."
```

Lines, in locked order (navigation group, then targeting
group — the Flutter panel's NAVIGATION → TARGETING order,
signature radius in targeting as in that panel). Amount lines
reuse `ship_stat_line(label, value, unit)` →
`widgets::format_fitting_amount` (exactly one decimal,
thousands-grouped); the one-decimal shape is honest for every
displayed range here (warp values are exact at one decimal,
align/mass/signature/range/scan/sensor values round like the
shipped peak rates do — rounding lives in the formatter,
never in the API). `None` omits the line; a present `0.0`
renders. Agility has no line (§2.3).

```text
Warp speed: {warp_speed} AU/s
Align time: {align_time_secs} s
Mass: {mass} kg
Signature radius: {signature_radius} m
Targeting range: {max_target_range_km} km
Scan resolution: {scan_resolution} mm
Sensor strength: RADAR {sensor_radar} points, Ladar {sensor_ladar} points, Magnetometric {sensor_magnetometric} points, Gravimetric {sensor_gravimetric} points
Max locked targets: {max_locked_targets}
```

The sensor line reuses the resistance segment shape
(`ship_resistance_segment`: `"{label} {formatted}"`, segments
joined `", "`, all-absent → no line), formatted with
`format_fitting_amount`. The count line renders the `i64` with
`{}` and no unit (the `slot_line` comment precedent: counts
never use `format_fitting_amount`), via a small
`ship_count_line(label, Option<i64>)` helper with the same
omit-on-`None` contract.

`render_ship_nav_targeting(ui, fitting, fitting_types)` mirrors
`render_ship_base_stats` exactly: catalogue `None` → heading +
no-catalogue line; `Available` → heading + lines + disclosure;
`Unavailable` → heading + no-ship-data line. The heading
always renders. It is called in **both** detail views
immediately after `render_ship_base_ehp` (imported synth site
and saved selected site), preserving the locked shared order:
resources → calibration → bay → slots → ship stats →
resistances → EHP → navigation/targeting. No colour, no new
widget, render code logs nothing.

## 7. Hand numbers (oracles and demo)

Cache rows read this session from
`dgmTypeAttributes.csv.bz2` / `invTypes.csv.bz2`. Align values
are hand-derived: `-ln(0.25) = 1.386294…`; e.g. Rifter
`1.386294 × 3.2 × 1,067,000 / 1,000,000 = 4.733363…`.

| Ship | 600 | 70 | mass | 552 | 76 (m) | 564 | 208/209/210/211 | 192 | align (s) |
|---|---|---|---|---|---|---|---|---|---|
| Rifter 587 | 5.0 | 3.2 | 1,067,000 | 35.0 | 22,500 | 660.0 | 0/8/0/0 | 4 | 4.733363 |
| Punisher 597 | 5.0 | 2.9 | 1,190,000 | 37.0 | 25,000 | 640.0 | 10/0/0/0 | 4 | 4.784102 |
| Osprey 620 | 4.0 | 0.61 | 11,100,000 | 95.0 | 62,500 | 280.0 | 0/0/0/15 | 8 | 9.386599 |
| Raven 638 | 3.0 | 0.12 | 99,300,000 | 410.0 | 90,000 | 111.0 | 0/0/0/22 | 7 | 16.519084 |
| Erebus 671 | 1.5 | 0.037 | 2,100,000,000 | 23,205.0 | 250,000 | 65.0 | 0/0/240/0 | 8 | 107.715072 |
| Capsule 670 | 4.0 | 2.0 | 32,000 | 25.0 | 0.0 | absent | 0/3/0/0 | 0 | 0.088723 |
| Legion 29986 | 4.0 | 0.52 | 14,500,000 | 170.0 | 70,000 | 230.0 | 17/0/0/0 | 6 | 10.452659 |
| Apotheosis 29266 | 5.0 | 1.0 | 1,600,000 | 25.0 | 35,000 | absent | 10/10/10/10 | 2 | 2.218071 |

Demo story (`assets/demo/fittings.json`, unmodified): Demo
Brawler and Mission Runner are Rifter 587; Demo Runner is
Punisher 597. Expected rendered block for the Rifter fittings:

```text
Ship navigation and targeting (base values)
Warp speed: 5.0 AU/s
Align time: 4.7 s
Mass: 1,067,000.0 kg
Signature radius: 35.0 m
Targeting range: 22.5 km
Scan resolution: 660.0 mm
Sensor strength: RADAR 0.0 points, Ladar 8.0 points, Magnetometric 0.0 points, Gravimetric 0.0 points
Max locked targets: 4
(disclosure as §6)
```

Punisher: `5.0 AU/s`, `4.8 s`, `1,190,000.0 kg`, `37.0 m`,
`25.0 km`, `640.0 mm`, sensor `RADAR 10.0` with the rest `0.0`,
`4`. (Rendered decimals are the formatter's one-decimal
rounding of the §7 table values; tests pin the full-precision
pure values and the rendered strings separately.)

## 8. Test plan (18 items; literals only, arithmetic in comments)

Generator (run during regeneration; failure blocks the commit):

1. `NAV_TARGETING_ORACLES` pass, incl. Capsule zeros/absence,
   Apotheosis sensors, non-ship absence; counts equal
   `NAV_TARGETING_EXPECTED_COUNTS`; 1281 tripwire holds;
   output size is 3,341,334 bytes.

Loader (`fitting_types.rs`):

2. Bundled invariants: finite, `>= 0.0`, integral 192,
   category-6-only, non-ship absence.
3. Spot pins: Rifter/Punisher literals from §7; Capsule
   `max_target_range == Some(0.0)`, `scan_resolution == None`.

Pure (`ship_nav_targeting.rs`), tolerance `1e-9` for align:

4. Oracle ships (§7: 587, 597, 620, 638, 671, 29986) return
   every literal, range already in km (22,500/1000 = 22.5 in a
   comment), targets as `Some(4)` etc.
5. Align literals from §7 with the multiplication shown in
   comments (Rifter `1.386294… × 3.2 × 1,067,000 / 1e6`),
   never built from the constant under test; Rifter cross-pins
   Flutter's `closeTo(4.7334, 0.001)`.
6. Capsule 670: present zeros stay `Some(0.0)` (range, three
   sensors), targets `Some(0)`, `scan_resolution == None`,
   align `Some(0.088723…)`.
7. Fitted-items-ignored: a Rifter fitting with items returns
   byte-identical stats to the empty fitting.
8. Absent vs zero: a ship row with no scan-resolution (670)
   omits only that field; all-`None` synthetic → `Unavailable`.
9. Guards via synthetic catalogue rows: negative, NaN, and
   infinite values → `None` per field, independently.
10. Align guards: agility `Some(0.0)` or mass `Some(0.0)` →
    align `None` while the other fields still render; missing
    agility or mass → align `None`; overflow-to-non-finite →
    `None`.
11. Non-integral `max_locked_targets` synthetic (e.g. 4.5) →
    `None`, other fields unaffected.
12. Non-ship (`category_id != 6`), unknown id, and
    `ship_type_id <= 0` → `Unavailable`.
13. Neighbour independence: Echelon-3532-style fixture — nav/
    targeting `Available` while resources are unusable, and a
    ship with full #578 stats but no nav fields leaves #578
    `Available` and this block `Unavailable`.

UI (`fittings.rs`):

14. Line templates: a full synthetic `ShipNavTargeting`
    renders the eight §6 lines verbatim (one-decimal,
    grouped mass, joined sensor line, bare count).
15. Omission: `None` scan/count/sensors each omit exactly
    their line; all-`None` sensors omit the joined line;
    present `0.0` range renders `Targeting range: 0.0 km`;
    `Some(0)` renders `Max locked targets: 0`.
16. Sensor join order and labels pinned (Apotheosis values →
    four positive segments in RADAR, Ladar, Magnetometric,
    Gravimetric order).
17. Wording pins: heading, disclosure, both unavailable
    constants equal §6 verbatim (sibling pin shape).
18. Demo pins over the real demo bundle: Rifter and Punisher
    blocks equal §7's rendered text in both detail views'
    line builder.

## 9. File split (zero overlap) and integrator

- **Builder A — catalogue.** Owns exactly
  `scripts/sde/generate_fitting_types_sde.py`,
  `assets/sde/fitting_types.json` (regenerated),
  `src/names/fitting_types.rs`. Tests 1–3. Touches nothing
  under `src/fitting/` or `src/ui/`.
- **Builder B — pure + UI.** Owns exactly
  `src/fitting/ship_nav_targeting.rs` (new) and
  `src/ui/fittings.rs` (constants, line builders, render fn,
  both call sites). Tests 4–18. Touches no generator,
  catalogue JSON, or loader file. Depends on A's field names
  (§4) and §5's API only.
- **Integrator.** Owns `src/fitting/mod.rs` (`pub mod
  ship_nav_targeting;` + re-export of `ship_nav_targeting`,
  `ShipNavTargeting`, `ShipNavTargetingOutcome`), assembles A
  then B, runs the full gates, verifies the demo smoke in both
  detail views and the 3,341,334-byte catalogue, and owns any
  `docs/engineering-journal/` capture. No push, no merge —
  the parent owns those.

Gates per commit: `cargo fmt --check`, `cargo clippy
--all-targets -- -D warnings`, `cargo test`, `cargo build`.
Commits small and atomic, `type(scope): description`, no
attribution lines. Suggested sequence: docs (this file) →
A (generator + catalogue + loader) → B (pure + UI) →
integrator wiring if `mod.rs` was not already carried by B's
branch assembly.

## 10. Exclusions (recorded, with evidence)

- **Raw agility display line** — data ships, no line. No
  Flutter precedent (carried, never rendered) and the shared
  one-decimal formatter renders real values as `0.0 x` (§2.3).
- **Dogma 1281 as an emitted value** — constant 1.0 on all
  404 ships; tripwire only (§2.1). Rendering 600 as `x` also
  excluded there.
- **Every §2.7 decoy** — zero ship rows or wrong meaning,
  listed with evidence; none is emitted or read.
- **Effective (modified) values of any kind** — Flutter's
  adds/multipliers/percent pipeline, `massAdd 796`,
  `signatureRadiusAdd 983`, skill modifiers, and its
  `_dashIfUnmodelled` zero-dash are explicitly not copied;
  absence is `None`/omission here.
- **Flutter's `NAVIGATION`/`TARGETING` headings and
  `toStringAsFixed` rounding** — Rust uses its own per-block
  "(base values)" heading and `format_fitting_amount`.
- **Max speed** — already shipped in the #578 block
  (`Max speed: … m/s`); not duplicated here.
- **Max velocity's dogma unit string** — out of scope: the
  #578 block already renders `m/s`; this slice does not
  relitigate shipped wording.

Nothing in the candidate list was left ungrounded without a
recorded reason: warp speed, agility (as data), align time,
signature radius, targeting range, scan resolution, all four
sensor strengths, max locked targets, and mass all ground to
inspected bodies as locked in §2.

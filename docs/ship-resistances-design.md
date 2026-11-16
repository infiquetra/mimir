# Ship resistances (base damage resistances) — design

Status: locked for the `feat/rust-ship-resistances` slice. Base:
`develop` at `9de864f` (verified clean before branching). Slice
branch: `feat/rust-ship-resistances`. This document is the single
design commit; builders and the integrator implement exactly what
is locked here and nothing else. It extends the ship base stats
slice (`docs/ship-base-stats-design.md`, #578) and deliberately
reuses its shapes; where this document says "mirrors #578", the
#578 wording and structure are the precedent and do not need
relitigating.

## 1. Goal and value ranking

Show a "Ship resistances (base values)" block in both fitting
details (the selected saved fitting and the imported fitting in
the Fittings view), after the "Ship (base values)" block shipped
by #578. The block lists the hull's base damage resistance
percentages for shield, armor, and hull, against EM, thermal,
kinetic, and explosive damage (twelve values), derived from the
hull's base resonance dogma attributes added to the bundled
fitting-types catalogue. Each percentage is one catalogue
resonance converted once (section 2); nothing is fitted,
weighted, averaged, or simulated. No network, no ESI changes, no
new scopes, no persistence.

Value ranking (locked, in order):

1. **Never show an unlabeled base resistance.** A bare-hull
   resistance presented where a user expects their fitted ship's
   tank is a lie, and it is the failure this slice exists to
   avoid — worse here than in #578, because a resistance
   percentage is the number a fitted-total readout is made of.
   The heading carries "(base values)" and a disclosure sentence
   under every rendered block names everything not applied
   (fitted modules, rigs, subsystems, skills, implants, ship
   bonuses; section 6). This outranks correctness and reuse: an
   accurate hull resistance a reader mistakes for their fitted
   resistance is still a failure.
2. **Correctness of the base values.** Every percentage must be
   hand-derivable from a quoted cache resonance row (section 8
   oracles), the hull attribute set must be the proven one
   (section 2 — the wrong set shows invented resistances), and
   absence must never render as a number while a present
   resonance of exactly 1.0 (a real 0% resistance) must render
   (section 2).
3. **Reuse.** The catalogue generator's additive-emission
   pattern, the loader's optional-field shape, the #578
   pure-function and renderer shapes, and the one fitting number
   formatter beat new machinery (sections 3–6).

Non-goals are locked in section 10. In particular: no EHP
(effective hit points) of any profile, no recharge, no modifier
of any kind (hardeners, Damage Control, rigs, subsystems, ship
bonuses, skills, implants), no damage profiles or weighting, no
DPS or tank simulation.

The resources block and the #578 ship base values block (their
wording, arithmetic, availability logic, and locked strings) are
unchanged by this slice. Nothing in `src/fitting/resources.rs`,
`src/fitting/ship_stats.rs`, `render_fitting_resources`,
`render_ship_base_stats`, or their constants appears in this
slice's diff (sections 6 and 8 pin this as a regression gate).

## 2. Attribute set and conversion (locked)

Every identifier below traces to an inspected body. No EVE
attribute number, unit meaning, or ship value in this design
comes from memory.

| Layer | EM | Thermal | Kinetic | Explosive |
|---|---|---|---|---|
| Shield | 271 | 274 | 273 | 272 |
| Armor | 267 | 270 | 269 | 268 |
| Hull | 113 | 110 | 109 | 111 |

Sources, common to all twelve: `dogmaAttributes.jsonl` in
`scripts/sde/eve-online-static-data-3503375-jsonl.zip` gives
each attribute's SDE name (`shieldEmDamageResonance`,
`armorEmDamageResonance`, `emDamageResonance`, …), unit 108,
and default value 1.0; Flutter `dogma_attributes.dart` at
`ed698d3` gives the same twelve numbers as
`shieldEmResist`…`hullExplosiveResist`, in EM, thermal, kinetic,
explosive order within each layer (its lines 14–31), and
`ResistProfile` in `models.dart` at `ed698d3` fixes the same
damage-type field order (em, thermal, kinetic, explosive) with
`DefenseProfile` fixing the layer order shield, armor, hull.
Section 6 locks both orders for display.

**The hull set is 109–113, not 974–977 (proven, not chosen).**
Two hull candidate sets exist, and their SDE English display
names are identical ("Structure EM Damage Resistance" and
siblings on both), so the display name cannot distinguish them;
the attribute name can (`emDamageResonance` family versus
`hullEmDamageResonance` family). Two inspected bodies settle it
the same way:

- Flutter `dogma_attributes.dart` at `ed698d3` (lines 26–31)
  carries the verbatim comment "Hull resonances live on the ship
  (emDamageResonance family), not on the Damage Control's own
  bonus attributes 974-977", with `hullEmResist = 113`,
  `hullThermalResist = 110`, `hullKineticResist = 109`,
  `hullExplosiveResist = 111`. Its Damage Control tests prove
  the other direction: a Rifter ship fixture holds 974–977 at
  1.0 while Damage Control II holds 0.6, and effect 2302 maps
  the module's 974–977 onto the ship's 113/110/109/111
  (`damage_pattern_test.dart` at `ed698d3`). Attributes 974–977
  are therefore a fitted module's bonus inputs — exactly the
  modifier data this slice must never emit as a base value.
- The cache coverage audit agrees: in
  `scripts/sde/dgmTypeAttributes.csv.bz2`, each of 109, 110,
  111, 113 is present on **all 404** published category-6
  (ship) rows of the committed catalogue, every row exactly
  0.67, while each of 974–977 is present on only 9 of 404 ships
  (Rifter 587, Tristan 593, Caracal 621, Bellicose 630, Sabre
  22456, Flycatcher 22464, Tengu 29984, Bifrost 37480, Stork
  37482), every row 1.0, and absent on the other 395.

Emitting 974–977 would show an invented 0% hull resistance on
nine ships and no hull line on 395. The Rifter is the tripwire:
it carries both sets (0.67 and 1.0), and only the 109-set yields
its true 33% hull resistance (section 8 pins this). Attribute
112 (`energyDamageAbsorptionFactor`) sits between 109 and 113
numerically, has zero rows in the entire cache, and is not a
resistance; the span 109–113 is not a block and is never treated
as one. Hull numeric order also differs from damage order
(109 kinetic, 110 thermal, 111 explosive, 113 EM): nothing in
this slice may iterate the attribute set in numeric or set
order and call the result EM/thermal/kinetic/explosive
(sections 3 and 4 lock explicit ordering).

**Conversion (locked): `resist % = (1 − resonance) × 100`.**
The formula is grounded twice, never recalled from EVE folklore.
`dogmaUnits.jsonl` `_key` 108 (name "Inverse Absolute Percent",
en displayName `%`) states verbatim "Used for resistance.
0.0 = 100% 1.0 = 0%", which is the linear map above. Flutter
`dogma_engine.dart` at `ed698d3` (lines 856–858) implements the
identical map: `resonance != null ? (1.0 - resonance) * 100 :
0.0`, commented "resonance 1.0 = 0% resist, 0.2 = 80% resist".
This slice copies the formula and its unit meaning only — never
Flutter's adjusted (fitted) totals, and never its handling of a
missing row: the Flutter engine reads ship resonances through
`attr(id, 1.0)`, so an absent row silently becomes resonance
1.0 = 0% resistance. That silent default is exactly what the
honesty rules forbid here (below).

**Out-of-range resonances (locked, decided from the bodies).**
No clamping anywhere. The inspected facts:

- On shipped data the question is unreachable: of the 4,848
  ship rows (404 ships × 12), **none** lies outside [0, 1]
  (observed ship range across all twelve: 0.10 to 1.00), and no
  ship row is negative.
- A resonance **above 1** is a real cache value shape (8 rows,
  all on four unpublished NPC types — for example attribute 273
  at 7.0 on type 15580 — which the category-6 gate never emits)
  and the grounded formula maps it to a negative percentage
  (1.1 → −10%, 7.0 → −600%). Flutter renders that signed result
  with no clamp and no range check. This slice does the same: a
  present resonance above 1 renders its true signed percent.
  The generator must therefore **not** fail on a value above 1
  (its cache scan sees the unpublished NPC rows; rejecting them
  would fail generation today), and neither the loader
  invariants nor the pure function may impose an upper bound.
- A **negative** resonance (which would mean above 100%) exists
  nowhere in the cache — zero rows in 612,816 — and both
  precedents treat negative wanted values as invalid data: the
  generator already fails loudly on negative resource and
  base-stat values, and the #578 `usable` rule treats a negative
  catalogue value as no data. This slice keeps that treatment:
  the generator fails on a negative resonance row and writes
  nothing, and a negative value reaching the pure function
  (fixture or future malformed asset) is no data for that one
  resistance only. This is rejection of invalid data, stated
  here and pinned by tests (section 8) — never a silent clamp
  of a rendered value.
- The percentage is computed in `f64` exactly as written. A
  finite, non-negative resonance whose computed percentage is
  non-finite (only possible for a resonance near the `f64`
  ceiling, where the ×100 overflows) is no data for that
  resistance (section 4); it must never reach the formatter,
  whose non-finite fallback would print a false `0.0%`.

Values come from one place only:
`scripts/sde/dgmTypeAttributes.csv.bz2` (header
`typeID,attributeID,valueInt,valueFloat`, 612,816 rows), joined
into the bundled catalogue by the generator (section 3). The
runtime never reads the CSV cache or the zip archive. Inspected
cache facts the design relies on (read directly from the cache
and the current catalogue during design; catalogue today
2,582,771 bytes, sha256
`ef808758e16901c829168a6327c85b3f0c1966b242e941096f687705cf5616fe`):

- **All 404 published ships carry all twelve attributes** —
  present 404, absent 0, explicit `0.0` 0 for each of the
  twelve. Ranges: shield EM 0.10–1.00 (exactly 1.0 — a real 0%
  resistance — on 351 ships), shield thermal 0.10–0.80, shield
  kinetic 0.10–0.725, shield explosive 0.10–0.725; armor EM
  0.10–0.675, thermal 0.10–0.675, kinetic 0.10–0.75, explosive
  0.10–0.90; hull all four exactly 0.67 on every ship (a flat
  33% — that is the data, not a rendering shortcut; the hull
  line must still be computed per ship from its four rows).
  The presence invariant in section 3 therefore passes today
  and a future cache refresh that drops a ship row fails loudly
  there instead of blanking a segment.
- No `(typeID, attributeID)` pair among the twelve is duplicated
  anywhere in the cache, and `valueInt` is the literal string
  `None` on every one of the 612,816 cache rows: `valueFloat`
  is the sole source, as for resources and base stats.
- Fractional resonances need up to five decimal places (armor
  kinetic/thermal), so percentages need up to three (for
  example Falcon 11957 armor thermal 0.20625 → 79.375%): of the
  4,848 ship percentages, 4,613 are exact at zero decimals, 137
  need one, 66 need two, 32 need three. Section 5 locks the
  display precision from these counts and the Flutter
  precedent; the API keeps every percentage exact.
- These attributes also live on non-ships: 53,981 wanted rows
  sit on types outside the 404 ships. Emission is gated to
  category 6 only (section 3), exactly as #578 found for base
  stats.

Missing-value semantics (locked), mirroring #578: each of the
twelve resistances is an `Option<f64>` (resonance in the
catalogue, percentage in the pure API). **Absent means no
data**: that damage type is omitted from its layer's line
(section 6) — never a rendered 0%, never a dash, never an
"unknown" string. **A present resonance of exactly 1.0 is a
real 0% resistance and renders `0.0%`** (351 ships carry it for
shield EM; omitting it would hide the one fact a reader most
needs about an armor ship's shield). A present resonance of
0.0 would be a real 100% and renders (unobserved in today's
ships; pinned by fixture, section 8). A ship with no catalogue
row, a non-ship ship row, or a ship row with no usable
resistance at all yields no numbers, only the fixed unavailable
sentence (section 6). On today's catalogue the absent path is
unreachable for real ships (404/404 on all twelve, above); it
ships proven by fixtures only, mirroring #578.

## 3. Catalogue extension (locked)

The bundled catalogue gains the twelve base resonance attributes
through its existing generator only. Hand-editing the JSON is
forbidden, as with every generated asset in this repo.

**Generator changes**
(`scripts/sde/generate_fitting_types_sde.py`, 501 lines today,
read in full). The `dgmTypeAttributes` cache is already loaded;
nothing new is read from disk and the generator still never
downloads.

- Add a parallel constant block beside `BASE_STAT_ATTR_IDS`
  (lines 68–73), with a provenance comment citing
  `dogmaAttributes.jsonl`, `dogmaUnits.jsonl` unit 108, and
  Flutter `dogma_attributes.dart` at `ed698d3`, including why
  the hull set is the `emDamageResonance` family and not
  974–977 (section 2):

  ```python
  RESIST_ATTR_IDS = {271, 274, 273, 272, 267, 270, 269, 268,
                     113, 110, 109, 111}
  SHIELD_EM_RESONANCE_ATTR = 271
  SHIELD_THERMAL_RESONANCE_ATTR = 274
  SHIELD_KINETIC_RESONANCE_ATTR = 273
  SHIELD_EXPLOSIVE_RESONANCE_ATTR = 272
  ARMOR_EM_RESONANCE_ATTR = 267
  ARMOR_THERMAL_RESONANCE_ATTR = 270
  ARMOR_KINETIC_RESONANCE_ATTR = 269
  ARMOR_EXPLOSIVE_RESONANCE_ATTR = 268
  HULL_EM_RESONANCE_ATTR = 113
  HULL_THERMAL_RESONANCE_ATTR = 110
  HULL_KINETIC_RESONANCE_ATTR = 109
  HULL_EXPLOSIVE_RESONANCE_ATTR = 111
  ```

  The set is membership only; it is never iterated for order
  (section 2's hull-order trap).
- Build a third per-type map beside `base_stats_by_type`
  (lines 250–281) with the same loud failures: an unparseable,
  non-finite, or **negative** value, or a duplicated
  `(typeID, attributeID)` pair, is a `fail(...)` and writes
  nothing, with messages saying "ship resistance", never
  "resource" or "base stat". Deliberately **not** a failure: a
  value above 1 (section 2 — the scan sees unpublished NPC
  rows carrying 1.1, 1.2, and 7.0 today).
- Emission is additive and sparse, **category 6 only**, inside
  the existing category-6 branch after the five base-stat
  if-blocks (lines 323–338). Twelve explicit if-blocks in this
  locked key order: `shieldEmDamageResonance` (271),
  `shieldThermalDamageResonance` (274),
  `shieldKineticDamageResonance` (273),
  `shieldExplosiveDamageResonance` (272),
  `armorEmDamageResonance` (267),
  `armorThermalDamageResonance` (270),
  `armorKineticDamageResonance` (269),
  `armorExplosiveDamageResonance` (268), `emDamageResonance`
  (113), `thermalDamageResonance` (110),
  `kineticDamageResonance` (109), `explosiveDamageResonance`
  (111). Key names are the SDE attribute names verbatim, as
  with every prior key; values are emitted **as resonances**,
  never pre-converted — the catalogue stores SDE data and the
  percentage exists only past the pure function (section 4).
  Every non-category-6 row is byte-identical to today and every
  category-6 row keeps its existing keys byte-stable; consumers
  ignore unknown fields, so the new asset still loads on old
  code. Module, rig, and subsystem rows carrying these
  attributes in the cache (including every 974–977 row
  anywhere) are not emitted: no locked computation reads them.
- Self-validation: a `RESIST_ORACLES` list beside
  `SHIP_STAT_ORACLES` (line 135), same tuple shape, a `None`
  key meaning none of the twelve new keys may be present.
  Values are resonances read from the cache during design
  (percentages hand-derived in section 8):
  - 587 Rifter, all twelve: shield 1.0, 0.8, 0.6, 0.5; armor
    0.4, 0.65, 0.75, 0.9; hull 0.67 ×4 (the 974–977 tripwire:
    those rows are also 1.0 on this ship and must not appear
    under any key).
  - 597 Punisher, all twelve: shield 1.0, 0.8, 0.6, 0.5; armor
    0.5, 0.65, 0.75, 0.8; hull 0.67 ×4.
  - 32209 Mimir (the asymmetric pin): armor EM 0.1, armor
    thermal 0.325, shield EM 1.0.
  - 29986 Legion: armor explosive 0.4, armor kinetic 0.5625,
    shield explosive 0.25, shield kinetic 0.45.
  - 11957 Falcon: armor kinetic 0.46875, armor thermal 0.20625
    (the three-decimal percentage pins behind section 5).
  - 2048 Damage Control II (module), 31668 rig, 45623
    subsystem: no new key at all.
- Catalogue-wide invariant beside the base-stat check (lines
  440–452): every category-6 entry carries all twelve new keys
  (true today, 404/404 — all twelve or the generator fails; a
  weaker "at least one layer" invariant was rejected because
  audit reality is 12 of 12 on every ship, and anything weaker
  would let a cache refresh silently drop a damage type the UI
  omission rule would then hide per ship). The summary print
  gains the twelve per-key counts (`=404` each on today's
  cache) beside the base-stat print (lines 491–497).
- Determinism is unchanged: types sorted by `typeId`, compact
  separators, trailing newline, no timestamps, dict insertion
  order fixed by construction. Proof obligations for Builder A
  (section 8): run the generator twice → identical sha256;
  strip the twelve new keys → byte-identical to today's
  `ef808758…`. Both proofs are run once and reported in the
  commit body, not committed as scripts.

**Size budget.** A simulation of the locked emission rule over
the real cache (404 ships × 12 entries; the simulation method
reproduces #578's measured +40,047 bytes to the byte) adds
157,694 bytes → 2,740,465 bytes (+6.11%). The long SDE-verbatim
key names drive the cost; shorter aliases were rejected because
every prior key in this asset is the SDE name verbatim and a
renamed key is how a future reader misjoins it. Budget: the
regenerated file must land within +175,000 bytes of today's
2,582,771; Builder A states the exact new byte count in the
commit body. Anything over budget means the emission rule
drifted (for example emitting on non-ship rows, where 53,981
wanted rows wait, or emitting 974–977) and stops the slice for
review.

**Rust loader** (`src/names/fitting_types.rs:22-55`).
`FittingType` gains twelve fields after `max_velocity`, each
`#[serde(default)]` so old assets and test fixtures without the
keys load as `None`, renamed to the SDE keys above in the same
order. Rust field names: `shield_em_resonance`,
`shield_thermal_resonance`, `shield_kinetic_resonance`,
`shield_explosive_resonance`, `armor_em_resonance`,
`armor_thermal_resonance`, `armor_kinetic_resonance`,
`armor_explosive_resonance`, and hull as
`hull_em_resonance` / `hull_thermal_resonance` /
`hull_kinetic_resonance` / `hull_explosive_resonance` with
renames `emDamageResonance` / `thermalDamageResonance` /
`kineticDamageResonance` / `explosiveDamageResonance` — the
`hp` → `hull_hp` precedent: the key keeps the SDE name, the
field reads as what the value is, and a doc comment pins both
the mapping and the not-974–977 reason (section 2). Fields hold
**resonances**. Loading, indexing, and lookup behavior do not
change; nothing is validated at load (the pure function guards
values, section 4; the invariants test proves the shipped
asset). No code constructs `FittingType` literals (tests build
rows through `from_json`), so the new fields force no fixture
churn.

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs:302-482`), all over the real
bundled asset: every category-6 row has all twelve new values
`Some` and finite and ≥ 0 — **with no upper bound** (section 2:
a resonance above 1 is legal data that renders a negative
percent; asserting ≤ 1 would make a future legitimate ship row
fail for a reason this design does not claim); every present
new value anywhere is finite and ≥ 0; no row outside category
6 carries any of the twelve; spot pins mirroring the generator
oracles (587 and 597 all twelve resonances, 32209 armor EM
`Some(0.1)` and armor thermal `Some(0.325)`, 11957 armor
kinetic `Some(0.46875)` and armor thermal `Some(0.20625)`,
2048/31668/45623 all twelve `None`). The existing invariants,
including every resource and base-stat invariant and pin, pass
unmodified.

## 4. Pure API (locked)

New module `src/fitting/ship_resistances.rs`, declared and
re-exported from `src/fitting/mod.rs` beside `ship_stats`. A
**sibling outcome, not an extension of `ShipBaseStats`** — the
#578 decision recorded in `docs/engineering-journal/DECISIONS.md`
(each base-attribute block ships as its own heading plus
disclosure, available independently of its neighbours) decides
this in advance, and extending `ShipBaseStats` would also break
section 8's gate that the #578 block and its strings stay
byte-identical. The module header follows the house pattern:
pure computation over the bundled catalogue — no egui, no
state, no network, no database. It depends on
`CharacterFitting` and `FittingTypes`, the same dependencies
`ship_stats.rs` takes, so both fitting details reach it through
the same one code path.

```rust
/// One layer's base damage resistance percentages, in
/// EM/thermal/kinetic/explosive order. Each field is
/// `(1.0 - resonance) * 100.0` for a usable catalogue
/// resonance; `None` means no data for that damage type:
/// the caller omits it, never renders a zero. A present
/// resonance of 1.0 is `Some(0.0)`; a resonance above 1.0
/// is a true negative percentage.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ResistLayer {
    pub em: Option<f64>,
    pub thermal: Option<f64>,
    pub kinetic: Option<f64>,
    pub explosive: Option<f64>,
}

/// One hull's base damage resistances, by layer.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipResistances {
    pub shield: ResistLayer,
    pub armor: ResistLayer,
    pub hull: ResistLayer,
}

/// Base resistances outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShipResistancesOutcome {
    Available(ShipResistances),
    /// The catalogue has no usable resistance data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

pub fn ship_resistances(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> ShipResistancesOutcome;
```

The nested shape mirrors `ResistProfile`/`DefenseProfile`
(`models.dart` at `ed698d3`: layer order shield, armor, hull;
field order em, thermal, kinetic, explosive) — labels and
order only; its values here are base percentages, never
Flutter's adjusted totals. Fields hold **percentages**, not
resonances: the conversion is arithmetic and belongs in the
pure layer once, not in the renderer.

Locked semantics:

- `Unavailable` when `ship_type_id <= 0`, when the catalogue
  has no row for it, when the row is not category 6, **or when
  every one of the twelve resistances is unusable** (mirroring
  #578's all-absent collapse: an `Available` value with no
  renderable segment would put a heading over nothing). There
  is no error channel: bad input degrades to disclosure, and
  the function never panics.
- Otherwise `Available`, each field independently computed from
  its resonance by one local rule: a resonance is usable when
  present, finite, and non-negative (no upper bound, section
  2); the percentage is `(1.0 - resonance) * 100.0`, and a
  non-finite percentage result is `None` (section 2's overflow
  guard). Per-resistance independence is the point: one missing
  resonance omits one segment (section 6) and never blanks the
  other eleven; one wholly absent layer omits one line.
- The fitting's items are never read. Fitted modules (including
  a Damage Control and its 974–977 inputs, hardeners, and
  resistance rigs), subsystems, skills, implants, and ship
  bonuses contribute nothing — there is no summing, chaining,
  stacking penalty, or excluded-module concept in this API. A
  hull-only fitting and a fully fitted one return identical
  results for the same ship (pinned in section 8).
- **Independence from resources and base stats (locked).**
  Availability keys off the twelve resonance fields only;
  `ship_base_stats` keys off the five base-stat fields and
  `FittingResources` off `cpu_output`/`power_output`. No block's
  function calls or consults another's. A ship row with base
  stats but no resonances renders the base-values block and the
  resistances unavailable sentence; the reverse renders
  resistances and the ship-values sentence; likewise against
  resources in both directions (all four combinations pinned,
  section 8). On today's catalogue every ship is fully
  available in all three, so independence is fixture-proven.
- **No logging in the pure function or the renderer**, exactly
  as in #578: both run at render cadence, and the slice rule is
  `[FITTING]` counts-only logging, never per rendered frame.
  This slice adds no runtime log lines; its only observable
  outputs are the rendered block and the generator's summary
  counts (section 3). The repo rule that every change adds
  `[FEATURE]` debug logging is recorded here as deliberately
  not applicable, for the same render-cadence reason #578 and
  the skill-resources design give; reviewers who disagree
  should challenge it on this document, not by adding per-frame
  logs.

Unit tests live in the module beside the code (section 8),
against both hand-built `FittingTypes::from_json` fixtures and
the real bundled catalogue. `src/fitting/ship_stats.rs` and
`src/fitting/resources.rs` are not modified at all.

## 5. Percent formatting (locked)

Percentages render with **exactly one decimal** through a thin
percent helper that reuses the one fitting number formatter:

```rust
// src/ui/widgets.rs, directly beside format_fitting_amount
pub fn format_fitting_percent(value: f64) -> String;
```

`format_fitting_percent` obtains the number from
`format_fitting_amount(value, "%")` (`src/ui/widgets.rs:69-102`)
and removes the formatter's separator space before the `%`, so
the rendered shape is `33.0%`, `-10.0%`, `0.0%`, `100.0%`. It is
a unit-spelling adapter only: it must not reimplement grouping,
rounding, sign handling, or the magnitude guards, and its tests
pin that it inherits them (section 8). `format_fitting_amount`
itself is not modified. The `%` spelling is unit 108's SDE
display name (section 2) and the no-space shape matches the
codebase's existing percent precedent
(`aar_derived_facts.dart` at `ed698d3`, `toStringAsFixed(1)`);
`33.0 %` would be a formatter artifact, not a player-facing
string.

Why one decimal, decided from the inspected values and
precedent:

- Flutter's only resist-percent formatting is one decimal
  (`aar_derived_facts.dart:181-183` at `ed698d3`), and the Rust
  fitting formatter is one decimal throughout (`114.0 tf`,
  `450.0 HP`). One precision in one panel is one precision of
  truth; the rejected alternative (2–3 decimals just for
  resistances) serves 98 of 4,848 rows by making this block
  look more precise than every block around it.
- **The lossy cases are named, not hidden.** 98 ship
  percentages (2%) round at one decimal — for example Nemesis
  11377 armor thermal 43.125% renders `43.1%`, Legion 29986
  armor kinetic 43.75% renders `43.8%`, Falcon 11957 armor
  thermal 79.375% renders `79.4%`, and Mimir 32209 armor
  thermal 67.5% renders exactly. The catalogue and the pure
  API keep the exact `f64` percentage; only the rendered
  string rounds, exactly as #578 accepted for `218.75` →
  `218.8 GJ`. Section 8 pins these renderings.
- Float dust is absorbed the same way: `(1.0 − 0.8) × 100` is
  `19.999999999999996` in `f64`, and `(1.0 − 0.67) × 100` is
  `32.99999999999999`; both render `20.0%` and `33.0%`. API
  tests therefore compare percentages with the resources
  `1e-9` tolerance, not `assert_eq!` (section 8).
- **Magnitudes are proven tame on shipped data; the guards are
  still inherited.** Ship resonances lie in [0.10, 1.00]
  (section 2), so every shipped percentage lies in [0, 90] —
  far inside the formatter's `i64`-split range. A resonance
  above 1 (section 2) yields a negative percentage, and the
  formatter is sign-aware (half away from zero); a fixture
  resonance of 7.0 renders `-600.0%`. The ≥ 9.0e18 grouped
  path and the non-finite fallback can only fire on synthetic
  input, because the pure function filters non-finite
  resonances and non-finite results before the formatter ever
  sees them (section 4) — but reusing the formatter gets both
  guards, including the huge-magnitude split-overflow safety,
  without a second implementation to keep honest.

No bars, no colour coding, no omni/average line, no totals
(section 10).

## 6. UI block in both fitting details (locked)

One shared renderer in `src/ui/fittings.rs`, directly beside
`render_ship_base_stats` (line 1357), called from both details
with the fitting and `fitting_types: Option<&FittingTypes>`:

```rust
fn render_ship_resistances(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
)
```

No skill levels and no SDE handle: the block never depends on
the viewing character, needs no name resolution (`EM`,
`Thermal`, `Kinetic`, `Explosive`, `Shield`, `Armor`, `Hull`
are locked label constants, not EVE type names), and no EVE
numeric ID appears in any string.

**Placement (locked).** Immediately **after** the ship base
values block in both details: in the imported detail after
`render_ship_base_stats` (line 1507), in the saved detail
after it (line 1794), always before the action buttons and
other following sections. Both details therefore read items →
fitting resources → ship base values → ship base resistances →
actions, with no per-detail fork. Resistances sit beside the
defensive hit-point values they qualify, below the fit-decision
resources readout. Merging the lines into the "Ship (base
values)" block was rejected (section 4): it would rewrite
#578's locked disclosure and couple the blocks' availability.
The new calls are additional statements after the two existing
`render_ship_base_stats` calls; that plus the new renderer,
line helper, and constants is the entire `fittings.rs` diff.
The block renders even when the fitting has no items, and even
when a neighbouring block renders an unavailable sentence, and
vice versa (section 4 independence). It renders in demo mode
identically; the existing demo banner already owns the
"invented sample rows" disclosure.

**Locked strings.** Constants beside the ship base stats
constants (lines 1163–1173), in the same style:

- Heading, via `ui.heading`, always (so the view never
  silently omits the feature):

  > Ship resistances (base values)

- Unavailable, catalogue failed to load (`fitting_types` is
  `None`):

  > Ship resistances unavailable: Mimir's bundled item data
  > failed to load.

- Unavailable, no usable resistance data (section 4
  `Unavailable`):

  > Ship resistances unavailable: Mimir's bundled item data
  > has no resistance data for this fitting's ship.

- Disclosure, verbatim, always last when numbers render:

  > These are the bare hull's base resistances from Mimir's
  > bundled item data. Fitted modules, rigs, subsystems,
  > skills, implants, and ship bonuses are not applied, so
  > these numbers can differ from EVE.

  Each named class maps to a grounded exclusion: fitted
  modules (hardeners, Damage Control, reactive armor
  hardeners, shield and armor rigs), rigs, subsystems (whose
  contributions reach fitted totals only through modifiers),
  skills, implants (the fitting model holds none), and ship
  bonuses (role and trait bonuses; this app holds no data for
  them). The sentence is this block's own, parallel to but not
  shared with the #578 disclosure one block above — each block
  is self-labeling (rank 1, section 1), and neither may be read
  as covering the other. Constant names follow the house
  pattern: `FITTINGS_SHIP_RESISTANCES_HEADING`,
  `FITTING_SHIP_RESISTANCES_DISCLOSURE`,
  `FITTING_SHIP_RESISTANCES_NO_CATALOGUE`,
  `FITTING_SHIP_RESISTANCES_NO_SHIP_DATA`.

**Layer lines (locked).** One line per layer, in shield, armor,
hull order; within a line, segments in EM, thermal, kinetic,
explosive order (section 2), joined by `, `, each segment
`{label} {percent}` with `{percent}` from
`format_fitting_percent` (section 5). Damage labels are
`EM`, `Thermal`, `Kinetic`, `Explosive` — the SDE display-name
vocabulary ("Shield Thermal Damage Resistance", section 2)
spelled in full in the view's sentence-case voice (`Capacitor
capacity` precedent, not the AAR's `Th/Kin/Exp` abbreviations,
and not its adjusted values). Templates verbatim:

| Template | Example (Rifter 587) |
|---|---|
| `Shield resistances: EM {p}, Thermal {p}, Kinetic {p}, Explosive {p}` | `Shield resistances: EM 0.0%, Thermal 20.0%, Kinetic 40.0%, Explosive 50.0%` |
| `Armor resistances: EM {p}, Thermal {p}, Kinetic {p}, Explosive {p}` | `Armor resistances: EM 60.0%, Thermal 35.0%, Kinetic 25.0%, Explosive 10.0%` |
| `Hull resistances: EM {p}, Thermal {p}, Kinetic {p}, Explosive {p}` | `Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%` |

Lines are produced by a small pure helper beside the renderer
(the `ship_base_stat_lines` precedent, lines 1335–1346), e.g.
`ship_resistance_lines(&ShipResistances) -> Vec<String>` built
from a per-layer segment helper, so every exact string is
unit-test pinned without an egui harness. All lines use the
normal label colour; a bare hull value has no over/under
state. The block is at most a heading, three lines, and the
disclosure, and needs no windowing.

**Missing-resistance rule (locked).** A resistance whose field
is `None` contributes **no segment** — omitted, not zeroed, not
dashed, not replaced with words. A layer with no usable
resistance contributes **no line**. The remaining segments and
lines still render, and the disclosure still renders last.
Only when all twelve are unusable (section 4 `Unavailable`)
does the fixed unavailable sentence replace all lines and the
disclosure. On today's catalogue this rule is unreachable for
real ships (section 2: 404/404 on all twelve); it exists so a
future catalogue gap degrades one segment, and it is proven by
fixtures (section 8). A present 0.0% (resonance 1.0) and a
present negative percentage (resonance above 1) both render as
ordinary segments (sections 2 and 5).

The renderer logs nothing itself (section 4).
`render_fitting_resources`, `render_ship_base_stats`, their
helpers, constants, and call sites are untouched.

## 7. Demo story (locked)

The demo hulls are real catalogue ships (`assets/demo/fittings.json`,
read in full during discovery), so every demo fit shows honest,
hand-computed base resistances for its actual ship. No demo
data changes in this slice. Percentages below are
`(1 − resonance) × 100` over the cache rows quoted in
section 8, rendered at one decimal (section 5); every demo
percentage is exact at one decimal.

- Demo Brawler and Mission Runner (both Rifter 587 — and the
  tripwire: this ship also carries decoy 974–977 rows at 1.0,
  so a wrong-set implementation shows hull 0% here instead of
  the locked 33%):

  ```text
  Ship resistances (base values)
  Shield resistances: EM 0.0%, Thermal 20.0%, Kinetic 40.0%, Explosive 50.0%
  Armor resistances: EM 60.0%, Thermal 35.0%, Kinetic 25.0%, Explosive 10.0%
  Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%
  ```

  followed by the section 6 disclosure. The invented module
  rows in these fits change none of these numbers, because the
  pure function never reads items (section 4) — which the
  identical blocks on both Rifter fits demonstrate.
- Demo Runner (Punisher 597): shield line identical to the
  Rifter's (same four shield resonances), then:

  ```text
  Armor resistances: EM 50.0%, Thermal 35.0%, Kinetic 25.0%, Explosive 20.0%
  Hull resistances: EM 33.0%, Thermal 33.0%, Kinetic 33.0%, Explosive 33.0%
  ```

  The armor difference (EM 50.0% vs 60.0%, Explosive 20.0% vs
  10.0%) is the per-hull signal the block exists to show.
- The demo sample import ("Use sample EFT" / "Use sample
  DNA", both the `[Rifter, Sample Brawler]` fit) shows the
  same Rifter block in the imported detail, identically under
  either demo character: base resistances never depend on who
  is viewing. This is the clean no-account walkthrough: demo →
  Fittings → Use sample EFT → Import fitting, then scroll.

**Visibility expectation (locked wording for reviewers).** The
Fittings view renders inside the shell's vertical scroll area,
and this block sits below the item sections, the resources
block, and the ship base values block in both details. It will
therefore normally sit **below the fold**, exactly as those
blocks do today: a reviewer must scroll to see it, and a
screenshot of just the first screenful must not be graded as
"block missing". The integrator's visual pass (section 9)
scrolls to it in both details.

## 8. Test plan (locked)

Oracle resonance rows read during design from
`scripts/sde/dgmTypeAttributes.csv.bz2` (every quoted row has
`valueInt` `None` and the `valueFloat` shown), in
shield–armor–hull layers, each EM/thermal/kinetic/explosive,
with percentages hand-derived as `(1 − r) × 100`:

- Rifter 587: shield 1.0/0.8/0.6/0.5 → 0/20/40/50; armor
  0.4/0.65/0.75/0.9 → 60/35/25/10; hull 0.67×4 → 33×4. (Also
  carries 974–977 at 1.0 — decoy, never emitted; section 2.)
- Punisher 597: shield 1.0/0.8/0.6/0.5 → 0/20/40/50; armor
  0.5/0.65/0.75/0.8 → 50/35/25/20; hull 0.67×4 → 33×4.
- Mimir 32209 (asymmetric oracle, shield EM 0% beside armor EM
  90%): shield 1.0/0.8/0.6/0.5 → 0/20/40/50; armor
  0.1/0.325/0.75/0.9 → 90/67.5/25/10; hull 0.67×4 → 33×4.
- Legion 29986: shield 1.0/0.8/0.45/0.25 → 0/20/55/75; armor
  0.5/0.65/0.5625/0.4 → 50/35/43.75/60; hull 33×4.
- Falcon 11957: armor kinetic 0.46875 → 53.125, armor thermal
  0.20625 → 79.375; Nemesis 11377: armor thermal 0.56875 →
  43.125, armor kinetic 0.4875 → 51.25.

Flutter's engine-test Rifter percentages beyond the bare-hull
33.0 (notably the Damage Control II adjusted 59.8%, and every
EHP figure) are fitted totals, not oracles; they are not
ported. Test comments quote the cache rows as the resources
and base-stat tests do.

**Pure calculation** (`src/fitting/ship_resistances.rs`,
Builder A), percentages compared with `1e-9` tolerance (these
are computed values with float dust, section 5 — the resources
tolerance, not the stored-value `assert_eq!`):

- Oracle ships: Rifter, Punisher, and the asymmetric Mimir
  each return `Available` with all twelve literal percentages
  above; Legion and Falcon/Nemesis pins cover the exact
  two/three-decimal percentages (43.75, 79.375, 43.125) in the
  API. Rifter hull is `Some(≈33.0)` ×4 — the 974–977 tripwire
  as a test.
- Items are ignored: a Rifter fitted with Damage Control II
  (2048) plus an unknown type and a stacked quantity returns a
  result equal to the hull-only Rifter (the no-modifiers lock
  as a test, with the decoy attribute's own module fitted).
- Ship failures: unknown ship ID (999999), non-ship ship ID
  (2048), `ship_type_id` 0 and −1 all return `Unavailable`.
- Absent versus present values (fixture catalogue): a
  category-6 row with some resonance keys absent, shield EM
  present as **1.0 → `Some(0.0)`**, one resonance present as
  **0.0 → `Some(100.0)`**, and the rest ordinary returns
  `Available` with exactly the absent fields `None`; a row
  with none of the twelve keys returns `Unavailable`; a row
  with exactly one resonance present returns `Available` with
  eleven `None`s; a row with one full layer and nothing else
  returns `Available` with two all-`None` layers.
- Out-of-range and guard pins (fixtures + the private
  conversion rule): resonance 1.1 → `Some(≈−10.0)` and 7.0 →
  `Some(≈−600.0)` (signed, never clamped); a negative
  resonance → `None` for that field only, siblings unaffected;
  non-finite values rejected by the conversion rule (JSON
  cannot spell NaN, so the non-finite half is pinned through
  the private helper, the #578 `usable` symmetry); a finite
  resonance at the `f64` ceiling whose percentage overflows
  (`1e308`) → `None`.
- Independence (fixtures, all combinations): resistances-only
  row → resistances `Available`, `ship_base_stats`
  `Unavailable`, resources `ShipNoOutput`; base-stats-only row
  → the reverse against resistances; outputs-only row →
  resources `Available`, resistances `Unavailable`. (The real
  catalogue has no such ship; fixtures only.)

**Catalogue** (`src/names/fitting_types.rs` + generator,
Builder A): the section 3 invariants and spot pins; old-fixture
JSON without the new keys still loads (existing fixture tests
prove it and must pass unmodified); generator run twice →
identical sha256, and new-keys-stripped output byte-identical
to base `ef808758…` (reported in the commit body, not
committed); regenerated byte count within the section 3
budget, exact count in the commit body.

**UI wording, formatting, demo** (`src/ui/fittings.rs` +
`src/ui/widgets.rs`, Builder B), string-exact through the pure
line helper:

- The three Rifter lines and three Punisher lines from
  sections 6–7, built from real `ship_resistances` results over
  the bundled catalogue; demo pins for all three demo fits
  prove demo fixture drift would fail a test.
- Formatting pins through `format_fitting_percent` and the
  lines: `0.0%` (resonance 1.0 renders, Rifter shield EM),
  `33.0%` (float dust absorbed), `67.5%` (Mimir armor
  thermal), `43.1%`, `43.8%`, `79.4%` (section 5's rounding
  pins: 43.125 / 43.75 / 79.375 exact in the API, one decimal
  on screen), `100.0%`, `-10.0%`, `-600.0%` (signed render
  through the line helper), and the helper's inherited guards
  (thousands grouping `1,234.5%`, a ≥ 9.0e18 magnitude, and
  non-finite → the formatter's `0.0%` fallback — reachable only
  synthetically, section 5).
- Omission pins: the fixture resistances produce a shield line
  **starting** `EM 0.0%` (present 1.0 renders) with absent
  segments missing entirely from the string (assertion on
  absence, not on placeholder text), and an all-absent layer
  produces no line.
- The heading, both unavailable sentences, and the disclosure,
  verbatim, following the `ship_base_stats_unavailable_and_disclosure_wording`
  precedent.
- Imported path: the section 7 sample fit through `parse_eft`
  → `to_character_fitting()` → `ship_resistances` yields the
  Rifter block, and likewise through the DNA sample (mirroring
  #578's sample pins for both importers).

**Regression gate (both builders).** Every existing resources
and ship base stats test in `src/fitting/` and every resources,
base-values, and demo pin in `src/ui/fittings.rs` passes
**unmodified**; the rendered resources and ship base values
blocks are byte-identical to `9de864f`. `src/fitting/resources.rs`,
`src/fitting/ship_stats.rs`, `render_fitting_resources`,
`render_ship_base_stats`, `ship_base_stat_lines`,
`format_fitting_amount`, and their constants must not appear
in this slice's diff at all (new call statements after the two
`render_ship_base_stats` calls and the new percent helper
beside the formatter are the only permitted adjacencies).

**Gates at every commit** (repo standard): `cargo test`,
`cargo clippy --all-targets -- -D warnings`, `cargo fmt --check`.

## 9. Integrator list (locked)

The integrator (not the builders) makes these changes after
both builders land:

- **README** — three sites (line numbers at `9de864f`), all
  keeping the rule that base resistances are not fitting
  statistics: the words "simulator" and "statistics" must not
  attach to the new numbers, and no sentence may imply fitted
  totals.
  1. The Fittings bullet (line 22): the base ship values
     sentence gains a joined sentence for the ship's base
     shield, armor, and hull damage resistances in the same
     honesty terms (bare hull base resistances from the bundled
     item data, fitted modules/rigs/subsystems/skills/implants/
     ship bonuses not applied). **The closing denial must be
     corrected:** today's "There are still no DPS or tank
     numbers — no resistances, no effective hit points, and no
     recharge or capacitor-stability figures" becomes false the
     moment this slice lands, because base resistances now
     render. It must narrow to what stays true — no DPS, no
     effective hit points, no recharge or capacitor-stability
     figures, and no adjusted fitting totals of any kind —
     without denying the base resistances the previous sentence
     just described, and with resistances explicitly described
     as base-only wherever they are named (an unqualified "no
     resistances" and an unqualified "resistances" are both
     wrong now). The "not been live-verified" caveat stays.
  2. The Roadmap Fitting bullet (line 31): the parenthetical
     gains the base resistances readout beside the base ship
     values readout; "ship fitting simulator with fitting
     statistics" stays listed as not implemented.
  3. The Status paragraph (line 37): the "only fitting
     features" enumeration gains the base resistances readout;
     "the fitting simulator is not present yet" stays true.
- **Engineering journal** — in the same change set (repo rule),
  kept short: a dated `LEARNINGS.md` entry with Evidence
  (file:line), Mechanism, and a one-line generalizable rule,
  covering the hull-set trap — two attribute sets share
  identical display names, the authoritative set (109–113)
  covers 404/404 ships while the Damage Control bonus set
  (974–977) covers 9/404 at 1.0, so coverage plus the retired
  app's constants, never the display name, must arbitrate
  which set is ship data — and the 12-of-12 coverage finding
  (the absent/present-zero honesty paths again ship proven
  only by fixtures, while the category-6 gate keeps 53,981
  non-ship rows out). Plus a short `DECISIONS.md` entry for
  the out-of-range rule (resonance above 1 renders its true
  signed percent with no upper bound anywhere; negative
  resonance is invalid data), with a "revisit when" condition
  (if a published ship ever carries a resonance outside [0, 1]
  in the cache). The #578 decisions on self-labeling blocks
  and independent availability are followed, not re-decided.
- Confirm the slice diff contains no ESI, scope, persistence,
  network, demo-asset, resources-stack, or base-stats-stack
  changes (section 8 regression gate), that the regenerated
  catalogue byte count in Builder A's commit body matches the
  committed file and sits within the section 3 budget, and run
  a demo-mode visual pass over the section 7 demo story (all
  three demo fits plus both sample imports), scrolling to the
  block in both details per section 7's below-the-fold
  expectation, before reporting done.

## 10. Exclusions (locked)

Out of this slice, by name: EHP (effective hit points) in any
form — omni, per-damage-profile, per-layer, or a summed
"total HP"/"total EHP" line; damage profiles and per-type
weighting of any kind, including an "omni" or average
resistance line; shield and capacitor recharge rates, times,
peak recharge, and any tank (HP/s) or capacitor simulation;
DPS, volley, and every other fitting statistic; all modifier
application — fitted modules (hardeners, Damage Control
including any read of attributes 974–977, energized membranes,
platings, extenders), rigs, subsystems (including emitting or
reading subsystem rows for these attributes), ship role and
trait bonuses, implants, and skills; stacking penalties and
modifier chaining of any kind; any trained-skill or fitted-item
input reaching `ship_resistances` (the signature takes none);
the fitting editor and any fitting mutation; bars, sparklines,
and colour coding; any change to the resources or ship base
values blocks' behavior, wording, or availability logic; ESI
calls, scopes, and stored data; demo fixture changes; reading
the pinned zip or the CSV caches at runtime (design-time
grounding sources only). Anything on this list appearing in a
builder commit is a design breach, not a bonus.

## 11. Ownership (locked)

Small atomic commits, `type(scope): description`, no
attribution. Nobody pushes or merges; the parent does that.

- **Builder A — data and pure calculation.** (1) Generator
  extension + regenerated `assets/sde/fitting_types.json` +
  loader fields + invariants (exact new byte count and both
  determinism proofs in the commit body). (2)
  `src/fitting/ship_resistances.rs` with its tests, wired in
  `src/fitting/mod.rs`. Commit (2) must compile and pass gates
  with no UI change (dead-code warnings handled by the
  re-export, not by `#[allow]`). Builder A touches no
  `src/ui/` files, no `src/fitting/ship_stats.rs`, and no
  `src/fitting/resources.rs`.
- **Builder B — UI.** (3) `format_fitting_percent` in
  `src/ui/widgets.rs` (beside, never modifying,
  `format_fitting_amount`), `render_ship_resistances`, its line
  helpers, its locked-string constants, and both call sites in
  `src/ui/fittings.rs`, with wording, formatting, and demo
  pins (section 8). If a change to `format_fitting_amount`
  itself seems necessary, stop and take it back to this
  document. Builder B changes no catalogue, generator,
  `src/fitting/`, or demo files, and must not modify
  `render_fitting_resources`, `render_ship_base_stats`, their
  helpers, or any of their constants — the call-site diffs are
  added statements after the two existing calls (section 6).
- **Integrator.** (4) README + engineering journal (section
  9), any cross-builder seam fix the two halves reveal
  (signature drift between sections 4 and 6 is the
  integrator's to reconcile back to this document, not to
  whichever builder wrote first), final gates, and the demo
  visual pass including the below-the-fold scroll check
  (section 7).

Sequencing: A(1) → A(2) → B(3) → integrator (4). B(3) needs
A(2)'s API; nothing else in the slice has slack to reorder.

# Ship base stats (hull shield, armor, hull, capacitor, velocity) — design

Status: locked for the `feat/rust-ship-base-stats` slice. Base:
`develop` at `f8fc6da` (verified clean before branching). Slice
branch: `feat/rust-ship-base-stats`. This document is the single
design commit; builders and the integrator implement exactly what
is locked here and nothing else.

## 1. Goal and value ranking

Show a "Ship (base values)" block in both fitting details (the
selected saved fitting and the imported fitting in the Fittings
view), beside the fitting-resources block shipped by
`docs/fitting-resources-design.md` and extended by
`docs/fitting-skill-resources-design.md`. The block lists the
hull's base shield, armor, and hull hit points, capacitor
capacity, and maximum velocity, read from base ship dogma
attributes added to the bundled fitting-types catalogue. Nothing
is fitted, summed, or simulated: each number is one catalogue
value for the fitting's ship, formatted. No network, no ESI
changes, no new scopes, no persistence.

Value ranking (locked, in order):

1. **Never show an unlabeled base number.** A base hull value
   presented where a user expects a fitted total is a lie, and it
   is the failure this slice exists to avoid. The heading carries
   "(base values)" and a disclosure sentence under every rendered
   block names everything not applied (fitted modules, rigs,
   subsystems, skills, implants, ship bonuses; section 6). This
   outranks correctness and reuse: an accurate number a reader
   mistakes for their fitted ship's tank or speed is still a
   failure.
2. **Correctness of the base values.** Every value must be
   hand-verifiable against the committed cache rows (section 8
   oracles), with absence never rendered as zero and a present
   zero never hidden (section 2).
3. **Reuse.** The catalogue generator's additive-emission
   pattern, the loader's optional-field shape, the resources
   pure-function and renderer shapes, and the one fitting number
   formatter beat new machinery (sections 3–6).

Non-goals are locked in section 10. In particular: no
resistances or EHP (effective hit points), no recharge rates or
times, no modifier of any kind, no DPS or capacitor simulation,
no fitting editor.

The resources block (base and skill-applied states, wording,
arithmetic) is unchanged by this slice. Nothing in
`src/fitting/resources.rs`, `render_fitting_resources`, its
locked strings, or `format_fitting_amount`'s shape changes
(sections 5, 6, 8 pin this as a regression gate).

## 2. Attribute set (locked)

Every identifier below traces to an inspected body. No EVE
attribute number, unit, or ship value in this design comes from
memory.

| Role | Attribute | Unit | Source of the number |
|---|---|---|---|
| Shield hit points | 263 (`shieldCapacity`, "Shield Capacity") | 113 = `HP` | `dogmaAttributes.jsonl` `_key` 263 in `scripts/sde/eve-online-static-data-3503375-jsonl.zip`; `dogmaUnits.jsonl` `_key` 113 (name "Hitpoints", en displayName `HP`); Flutter `dogma_attributes.dart` at `ed698d3` (`shieldCapacity = 263`) |
| Armor hit points | 265 (`armorHP`, "Armor Hitpoints") | 113 = `HP` | `dogmaAttributes.jsonl` `_key` 265; Flutter `armorHp = 265` |
| Hull hit points | 9 (`hp`, "Structure Hitpoints") | 113 = `HP` | `dogmaAttributes.jsonl` `_key` 9; Flutter `hullHp = 9` |
| Capacitor capacity | 482 (`capacitorCapacity`, "Capacitor Capacity") | 114 = `GJ` | `dogmaAttributes.jsonl` `_key` 482; `dogmaUnits.jsonl` `_key` 114 (name "capacitor units", en displayName `GJ`); Flutter `capacitorCapacity = 482` |
| Maximum velocity | 37 (`maxVelocity`, "Maximum Velocity") | 11 = `m/sec` (en) | `dogmaAttributes.jsonl` `_key` 37 (also carries `maxAttributeID` 2033, unused here); `dogmaUnits.jsonl` `_key` 11 (name "Acceleration", en displayName `m/sec`); Flutter `maxVelocity = 37` |

Display-string decisions (locked in section 6, grounded here):

- **Velocity renders `m/s`, not `m/sec`.** The unit-11 record is
  a known data quirk: it is named "Acceleration" and its
  description says "Meter per second squared", while attribute
  37 is a velocity ("Maximum velocity of ship"). The same unit
  record spells its display name `m/s` in German, Spanish,
  Korean, and Chinese; the English `m/sec` is the outlier.
  Flutter's stats panel renders `m/s`
  (`stats_panel.dart` at `ed698d3`, NAVIGATION "Max Speed"), and
  that is the string EVE players see. The design locks `m/s`
  and records the quirk instead of copying `m/sec` verbatim.
- **Attribute 9 renders with the label `Hull`.** The SDE English
  display name is "Structure Hitpoints"; Flutter labels the
  same value `Hull` (`stats_panel.dart`, DEFENSE rows
  Shield/Armor/Hull), and this slice's own brief names it hull
  hit points. The catalogue key keeps the SDE attribute name
  `hp` (section 3); only the on-screen label is `Hull`.

Explicitly **not** used, with the inspected reason:

- Resistances for all three layers (for example attributes
  271–274 shield, 267–270 armor, 109–113 hull in
  `dogma_attributes.dart` at `ed698d3`) and any EHP arithmetic
  over them. Flutter's DEFENSE section leads with an EHP total;
  this slice shows no resistances and computes no EHP
  (section 10).
- Recharge: `shieldRechargeTime` 479 and
  `capacitorRechargeTime` 55 (`dogma_attributes.dart` at
  `ed698d3`). No recharge rates, times, or stability numbers
  (section 10).
- Bonus-add attributes such as 72 (`shieldCapacityBonus`) and
  1159 (`armorHpBonusAdd`) — module-side adders read by the
  Flutter modifier pipeline, not base ship values.
- The five `_skillModifiers` entries that target these exact
  attributes in Flutter (`dogma_engine.dart` at `ed698d3`):
  Navigation 3449 → 37, Capacitor Management 3418 → 482,
  Shield Management 3419 → 263, Hull Upgrades 3394 → 265,
  Mechanics 3392 → 9, each +5% per level, plus Shield
  Operation 3416 → 479. They are the six skill-table entries
  left unapplied by the skill-resources slice (which applied
  only 3426 → 48 and 3413 → 11). This block applies no skills;
  the disclosure says so (section 6).

Values come from one place only:
`scripts/sde/dgmTypeAttributes.csv.bz2` (header
`typeID,attributeID,valueInt,valueFloat`, 612,816 rows), joined
into the bundled catalogue by the generator (section 3). The
runtime never reads the CSV cache or the zip archive. Inspected
cache facts the design relies on (read directly from the cache
and the current catalogue during design):

- The catalogue (`assets/sde/fitting_types.json`, today
  2,542,724 bytes, 25,818 types, sha256
  `44f269fd2ee0920221d0524a6cc26ef29b4e6a0d9069f026ec91095f44d9acef`)
  holds 404 published category-6 (ship) rows. **All 404 carry
  all five attributes.** For each of 263/265/9/482/37 over those
  404 rows: present 404, absent 0, explicit `0.0` 0. Observed
  ranges: shield 63.0 (Capsule 670) to 950,000.0 (Komodo
  45649); armor 125.0 to 950,000.0; hull 13.0 to 615,000.0;
  capacitor 125.0 to 145,000.0; velocity 60.0 to 500.0. Every
  shipped value is positive, so the presence invariant in
  section 3 passes today and a future cache refresh that drops
  a ship row fails loudly there instead of blanking a line.
- **No shieldless or genuine-zero ship exists in the current
  404.** The absent-versus-zero distinction below is therefore
  unexercised by shipped data and is pinned by fixture-catalogue
  tests, not by bundled rows (section 8). The generator oracle
  list correspondingly has no present-zero ship pin to quote;
  inventing one from memory is forbidden.
- No `(typeID, attributeID)` pair among the five attributes is
  duplicated anywhere in the cache (42,943 rows total), and
  `valueInt` is the literal string `None` on every one of them:
  `valueFloat` is the sole source, exactly as for the four
  resource attributes.
- Fractional values exist and forbid integer display
  (section 5): capacitor 482 is fractional on 13 ships
  (Echelon 3532 `187.5`, Helios 11172 `218.75`, Vengeance 11365
  `487.5`, and ten more), and velocity 37 on one (Mekubal
  78333 `322.3`). The three hit-point attributes are
  integer-valued on all 404. One capacitor value, `218.75`,
  needs two decimals to render exactly; section 5 locks how
  the formatter handles that.
- These attributes also live on non-ships: 40,923 of the 42,943
  rows sit on types outside the catalogue's 404 ships, spread
  across catalogue categories 7 (modules), 18, 23, 87, 32
  (subsystems), and others. Emission is therefore gated to
  category 6 only (section 3), exactly like ship CPU/power
  outputs; emitting anywhere else would put ship-stat keys on
  thousands of rows no locked computation reads.

Missing-value semantics (locked), mirroring the resource slice's
optional-value model: each ship stat is an `Option<f64>` in the
catalogue. **Absent means no data**: the stat's line is omitted
from the block (section 6) — never a rendered `0`, never a dash,
never an "unknown" string (no raw IDs or placeholder numbers may
reach the screen). **A present `0.0` is a real zero** and
renders like any other value (a hypothetical hull with no
shield shows `Shield: 0.0 HP`). A ship with no catalogue row, a
non-ship ship row, or a ship row with no usable stat value at
all yields no numbers, only the fixed unavailable sentence
(section 6).

## 3. Catalogue extension (locked)

The bundled catalogue gains the five base ship attributes
through its existing generator only. Hand-editing the JSON is
forbidden, as with every generated asset in this repo.

**Generator changes** (`scripts/sde/generate_fitting_types_sde.py`,
345 lines today, read in full). The `dgmTypeAttributes` cache is
already loaded for the resource join; nothing new is read from
disk and the generator still never downloads.

- Add a parallel constant beside `RESOURCE_ATTR_IDS` (line 55),
  with a provenance comment citing `dogmaAttributes.jsonl` and
  Flutter `dogma_attributes.dart` at `ed698d3`, mirroring the
  existing comment style:

  ```python
  BASE_STAT_ATTR_IDS = {263, 265, 9, 482, 37}
  SHIELD_CAPACITY_ATTR = 263
  ARMOR_HP_ATTR = 265
  HULL_HP_ATTR = 9
  CAPACITOR_CAPACITY_ATTR = 482
  MAX_VELOCITY_ATTR = 37
  ```

  A parallel set (not widening `RESOURCE_ATTR_IDS`) keeps
  failure messages honest: a bad shield row says "ship base
  stat", never "resource".
- Build a second per-type map from rows whose `attributeID` is
  in `BASE_STAT_ATTR_IDS`, with the same loud failures as the
  resource join (lines 167–196): parse `valueFloat` as `float`
  (section 2 proves these rows always carry it); an
  unparseable, non-finite, or negative value, or a duplicated
  `(typeID, attributeID)` pair, is a `fail(...)` — the
  generator exits nonzero and writes nothing.
- Emission is additive and sparse, **category 6 only**. For
  each ship row, after the existing keys in their existing
  order (`typeId`, `typeName`, `categoryId`, `slotEffects`,
  `cpuOutput`, `powerOutput`), append each of
  `"shieldCapacity"` (263), `"armorHP"` (265), `"hp"` (9),
  `"capacitorCapacity"` (482), `"maxVelocity"` (37) only when
  a row exists, in that key order. Key names are the SDE
  attribute names verbatim (`shieldCapacity`, `armorHP`, `hp`,
  `capacitorCapacity`, `maxVelocity` in
  `dogmaAttributes.jsonl`), matching the resource keys'
  precedent (`cpuOutput`, `cpu`). Every non-category-6 row is
  byte-identical to today, and every category-6 row keeps its
  existing keys byte-stable; consumers ignore unknown fields
  (the Rust struct has no `deny_unknown_fields`), so the new
  asset still loads on old code. Subsystem (category 32) and
  module rows carrying these attributes in the cache are **not**
  emitted: no locked computation reads them, and dead data in
  a bundled asset is how the next reader talks themselves into
  an ungrounded sum (the resource design's subsystem-output
  reasoning, applied unchanged).
- Self-validation grows in the existing style: a
  `SHIP_STAT_ORACLES` list beside `RESOURCE_ORACLES` (line 96),
  same tuple shape `(typeId, key-or-None, expected)`, where a
  `None` key means none of the five new keys may be present on
  that row. Every value below was read from the cache during
  design (section 8 quotes the rows):
  - 587 Rifter: shieldCapacity 450.0, armorHP 450.0, hp 350.0,
    capacitorCapacity 250.0, maxVelocity 365.0.
  - 597 Punisher: 350.0, 500.0, 450.0, 400.0, 355.0.
  - 29986 Legion: 1800.0, 2900.0, 1800.0, 1800.0, 185.0.
  - 638 Raven: 7700.0, 6380.0, 7040.0, 5500.0, 113.0.
  - 3532 Echelon capacitorCapacity 187.5 (fractional pin; this
    hull is also one of the two present-zero resource-output
    ships, which section 8 uses for the independence pin).
  - 11172 Helios capacitorCapacity 218.75 (the two-decimal
    pin behind section 5's rounding lock).
  - 78333 Mekubal maxVelocity 322.3 (the fractional-velocity
    pin).
  - 2048 Damage Control II (module), 31668 rig, and 45623
    subsystem: no new key at all (the category-6 gate pins).
  There is no shieldless or explicit-zero ship oracle:
  section 2 proves none exists in the current cache, so the
  present-zero path is proven only by Rust fixtures
  (section 8), never by an invented cache row.
- Catalogue-wide invariant, beside the existing ship-output
  check (lines 297–303): every category-6 entry carries all
  five new keys (true today, 404/404). A future cache refresh
  that drops a ship stat fails loudly instead of silently
  omitting that line in the UI. The summary print gains the
  counts of rows gaining each new key (`shieldCapacity=404
  armorHP=404 hp=404 capacitorCapacity=404 maxVelocity=404`
  on today's cache).
- Determinism is unchanged: types sorted by `typeId`, compact
  separators, trailing newline, no timestamps, dict insertion
  order fixed by construction. Proof obligations for Builder A
  (section 8): run the generator twice and compare sha256;
  strip the five new keys from the new file and compare
  byte-for-byte with the base file's sha256 in section 2. Both
  proofs are run once and reported in the commit body or PR
  text, not committed as scripts.

**Size budget.** A simulation of the locked emission rule over
the real cache (404 ships × 5 `,"key":value` entries) adds
40,047 bytes → 2,582,771 bytes (+1.57%). Budget: the
regenerated file must land within +60,000 bytes of today's
2,542,724; Builder A states the exact new byte count in the
commit body. Anything over budget means the emission rule
drifted (for example emitting on non-ship rows, where 40,923
wanted rows wait; section 2) and stops the slice for review.

**Rust loader** (`src/names/fitting_types.rs:20-39`).
`FittingType` gains five fields after `power`, each
`#[serde(default)]` so old assets and test fixtures without
the keys load as `None` (the `slotEffects` and resource-field
precedent):

```rust
#[serde(rename = "shieldCapacity", default)]
pub shield_capacity: Option<f64>,
#[serde(rename = "armorHP", default)]
pub armor_hp: Option<f64>,
#[serde(rename = "hp", default)]
pub hull_hp: Option<f64>,
#[serde(rename = "capacitorCapacity", default)]
pub capacitor_capacity: Option<f64>,
#[serde(rename = "maxVelocity", default)]
pub max_velocity: Option<f64>,
```

The catalogue key for hull stays the SDE name `hp`; the Rust
field is `hull_hp` so call sites read as what the value is
(attribute 9, "Structure Hitpoints", labelled `Hull` on
screen), with a doc comment pinning the mapping. Loading,
indexing, and lookup behavior do not change; nothing is
validated at load beyond what exists today (the pure function
guards values, section 4, and the invariants test proves the
shipped asset). No code in the tree constructs `FittingType`
literals (verified by search; tests build rows through
`from_json`), so the new fields force no fixture churn.

**Invariants to add** to `bundled_catalogue_invariants`
(`src/names/fitting_types.rs:287-390`), all over the real
bundled asset: every category-6 row has all five new values
`Some`, finite, and ≥ 0 (presence is the "every ship has hull
hit points" invariant — a present `0.0` stays legal data and
renders, section 2); every present new value anywhere is
finite and ≥ 0; no row outside category 6 carries any of the
five values; the same spot pins as the generator oracles (587
and 597 full five-value pins, 3532 capacitor `Some(187.5)`,
11172 capacitor `Some(218.75)`, 78333 velocity `Some(322.3)`,
2048/31668/45623 all five `None`). The existing invariants —
including every resource invariant and pin — pass unmodified.

## 4. Pure API (locked)

New module `src/fitting/ship_stats.rs`, declared and
re-exported from `src/fitting/mod.rs` beside `dna`/`eft`/
`resources`/`write_map`. A sibling module (not an extension of
`resources.rs`) keeps the skill-applied resources stack
file-for-file unchanged and reviewable as such (section 1).
The module header follows the house pattern
(`src/fitting/mod.rs:1-2`): pure computation over the bundled
catalogue — no egui, no state, no network, no database. It
depends on `CharacterFitting` and `FittingTypes`, the same
dependencies `resources.rs` takes, so both fitting details
reach it through the same one code path (saved fittings
directly; imported fittings through the existing
`ImportedFitting::to_character_fitting()` synthesis).

```rust
/// One hull's base ship values. Each field is the catalogue
/// value when usable (present, finite, non-negative); a present
/// `0.0` stays a real zero. `None` means no data for that stat:
/// the caller omits the line, never renders a zero.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ShipBaseStats {
    pub shield_capacity: Option<f64>,
    pub armor_hp: Option<f64>,
    pub hull_hp: Option<f64>,
    pub capacitor_capacity: Option<f64>,
    pub max_velocity: Option<f64>,
}

/// Base ship values outcome for one fitting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ShipBaseStatsOutcome {
    Available(ShipBaseStats),
    /// The catalogue has no usable base ship data for this
    /// fitting's ship, so no honest numbers exist.
    Unavailable,
}

pub fn ship_base_stats(
    fitting: &CharacterFitting,
    catalogue: &FittingTypes,
) -> ShipBaseStatsOutcome;
```

Locked semantics:

- `Unavailable` when `ship_type_id <= 0`, when the catalogue
  has no row for it, when the row is not category 6, **or when
  every one of the five values is unusable** (absent,
  non-finite, or negative — defense in depth; the section 3
  invariants prove this cannot happen for the shipped asset,
  whose 404 ships all carry all five). The all-absent case
  must collapse to `Unavailable`: an `Available` block with no
  lines would render a heading over nothing, which is a
  silent omission wearing a heading. There is no error
  channel: bad input degrades to disclosure, and the function
  never panics.
- Otherwise `Available` with each field independently passed
  through the `usable` rule (`present && finite && >= 0.0`,
  the `resources.rs:120-122` semantics; implemented locally —
  five lines of filter do not justify exporting a private
  helper across modules). Per-stat independence is the point:
  one missing stat omits one line (section 6) and never blanks
  the other four.
- The fitting's items are never read. Fitted modules, rigs,
  and subsystems contribute nothing — there is no summing,
  counting, or excluded-module concept in this API, because
  the values describe the bare hull. A hull-only fitting and
  a fully fitted one return identical results for the same
  ship (pinned in section 8).
- **Independence from resources (locked).** Availability keys
  off the five new fields only; `FittingResources` keys off
  `cpu_output`/`power_output`. Neither function calls or
  consults the other. A ship row with outputs but no stat
  rows renders resources and the stats unavailable sentence;
  the reverse renders stats and the resources unavailable
  sentence. Entangling them (for example reusing
  `ShipNoOutput` as the stats outcome) would blank one honest
  block when the other lacks data.
- **No logging in the pure function or the renderer.** Both
  run at render cadence; the slice rule is `[FITTING]`
  counts-only logging, never per rendered frame, and the
  shipped resources precedent logs nothing in its pure
  function. This slice adds no runtime log lines: its only
  observable outputs are the rendered block and the
  generator's summary counts (section 3), which follow the
  generator's existing print style. (The repo rule that every
  change adds `[FEATURE]` debug logging is recorded here as
  deliberately not applicable, for the same render-cadence
  reason the skill-resources design gives in its section 4;
  reviewers who disagree should challenge it on this document,
  not by adding per-frame logs.)

Unit tests live in the module beside the code (section 8),
against both hand-built `FittingTypes::from_json` fixtures and
the real bundled catalogue.

## 5. Number formatting (locked)

All five values render through the existing
`format_fitting_amount(value, unit)` (`src/ui/widgets.rs:69-102`):
thousands-grouped, exactly one decimal, half away from zero,
total on hostile input (non-finite renders `0.0 {unit}` with a
`[UI]` warning; magnitudes at or past 9.0e18 take the grouped
direct-render path instead of the `i64` split). No new
formatter is written. Units are `HP` for shield/armor/hull,
`GJ` for capacitor capacity, and `m/s` for maximum velocity
(section 2 locks the strings).

Why reuse, decided from the inspected values and precedent:

- **Integer display is lossy on real rows.** Flutter's stats
  panel uses `toStringAsFixed(0)` for hit points, capacitor,
  and velocity. On today's cache that would render Echelon's
  capacitor `187.5` as `188` and Mekubal's velocity `322.3`
  as `322` — wrong numbers, not rounded display. A
  grouped-integer helper was considered and rejected for
  exactly this reason. Flutter's other fitting readout (the
  resource values) keeps one decimal, and that is the shape
  the Rust formatter already implements.
- **One fitting number format.** The stats block sits directly
  under the resources block (section 6), whose lines read
  `114.0 tf`. Two decimal conventions three centimetres apart
  would read as two different precisions of truth. One
  formatter also means one set of hostile-magnitude guards,
  already pinned by tests (`src/ui/widgets.rs:282-311`).
- **The one lossy case is named, not hidden.** Helios and one
  other hull carry capacitor `218.75`, which one-decimal
  display renders as `218.8 GJ`. The catalogue and the pure
  API keep the exact `f64`; only the rendered string rounds,
  to the nearest 0.1, exactly as resource outputs already
  round (the skill slice's `51.25` → `51.3 MW` pin is the
  same accepted display rounding). Section 8 pins `218.8 GJ`
  so the choice stays visible in a test instead of surprising
  a reviewer. A two-decimal formatter was considered and
  rejected: it would render every other value with trailing
  noise (`450.00 HP` beside `114.0 tf`) to serve two hulls.
- **Magnitudes are tame; the guards are still free.** The
  largest shipped value is 950,000.0 (section 2), far inside
  the formatter's `i64`-split range, and no arithmetic ever
  multiplies these values. The ≥ 9.0e18 and non-finite guards
  therefore only fire on fixture or future data — but reusing
  the formatter gets them without a second implementation to
  keep honest. Example renderings: `450.0 HP`, `7,700.0 HP`,
  `950,000.0 HP`, `187.5 GJ`, `218.8 GJ`, `365.0 m/s`,
  `322.3 m/s`, `0.0 HP` (a present zero, section 2).

No percentages, no bars, no totals line (summing the three
hit-point layers into a "total HP" would invent a tank number
the slice does not ground; section 10).

## 6. UI block in both fitting details (locked)

One shared renderer in `src/ui/fittings.rs`, directly beside
`render_fitting_resources` (line 1230), called from both
details with the fitting and `fitting_types:
Option<&FittingTypes>` (which `show` already receives):

```rust
fn render_ship_base_stats(
    ui: &mut egui::Ui,
    fitting: &CharacterFitting,
    fitting_types: Option<&FittingTypes>,
)
```

No skill levels and no SDE handle: the block never depends on
the viewing character, so it renders identically for every
owner and needs no name resolution (all strings below are
locked constants; no EVE numeric ID appears in any of them).

**Placement (locked).** Immediately **after** the resources
block in both details. In the saved detail: after
`render_fitting_resources` (line 1716) and before the "Copy
as EFT" button (line 1717). In the imported detail: after
`render_fitting_resources` (line 1430) and before "Loaded
charges" (line 1438). Both details therefore read items →
fitting resources → ship base values → actions, with no
per-detail fork. Resources first because they are the
fit-decision readout; the hull's base values are reference
beside them. The reverse order was rejected: it would put the
numbers most easily mistaken for fitted totals (rank 1,
section 1) ahead of the block that describes the actual fit.
The block renders even when the fitting has no items (a
hull-only fit has honest base values to show), and even when
the resources block renders an unavailable sentence, and vice
versa (section 4 independence). It renders in demo mode
identically; the existing demo banner (`widgets::mode_notice`)
already owns the "invented sample rows" disclosure.

**Locked strings.** Constants beside the resources constants
(lines 1138–1157), in the same style:

- Heading, via `ui.heading`, always (so the view never
  silently omits the feature):

  > Ship (base values)

- Unavailable, catalogue failed to load (`fitting_types` is
  `None`):

  > Ship values unavailable: Mimir's bundled item data failed
  > to load.

- Unavailable, no usable ship data (section 4 `Unavailable`):

  > Ship values unavailable: Mimir's bundled item data has no
  > base ship data for this fitting's ship.

  Both mirror the resources unavailable sentences' shape and
  keep the resources failed-to-load sentence's exact tail
  (`src/ui/fittings.rs:1156`). The words are "Ship values",
  never "Ship statistics" (section 9).
- Disclosure, verbatim, always last when numbers render:

  > Base ship values from Mimir's bundled item data. Fitted
  > modules, rigs, subsystems, skills, implants, and ship
  > bonuses are not applied, so these numbers can differ from
  > EVE.

  Each named class maps to a grounded exclusion: fitted
  modules (hit-point adders such as shield extenders and armor
  plates, propulsion, and every other module effect), rigs,
  subsystems (their attribute contributions reach Flutter
  totals only through effect modifiers), skills (the five
  `_skillModifiers` entries in section 2), implants (the
  fitting model holds none), and ship bonuses (role and trait
  bonuses, which this app holds no data for). The sentence is
  this block's own: the resources disclosure one block above
  says "Skills … are not applied" in its base state and names
  the two applied output skills in its applied state, and
  neither may be read as covering this block. The two
  disclosures coexisting is deliberate — each block is
  self-labeling (rank 1), and merging them into one paragraph
  would let the resources block's "(with skill bonuses)"
  heading bleed onto unskilled base values.

**Stat lines (locked).** Rendered in this order — shield,
armor, hull, capacitor, velocity — the Flutter stats panel's
DEFENSE → CAPACITOR → NAVIGATION order
(`stats_panel.dart` at `ed698d3`) and the order this slice's
brief lists. Labels adapt Flutter's short labels
(`Shield`/`Armor`/`Hull`) to the view's sentence-case voice
("Power grid", "Low slots"), with capacitor spelled out
because a bare `Capacity` three lines under a shield line is
ambiguous:

| Template | Example (Rifter 587) |
|---|---|
| `Shield: {value} HP` | `Shield: 450.0 HP` |
| `Armor: {value} HP` | `Armor: 450.0 HP` |
| `Hull: {value} HP` | `Hull: 350.0 HP` |
| `Capacitor capacity: {value} GJ` | `Capacitor capacity: 250.0 GJ` |
| `Max speed: {value} m/s` | `Max speed: 365.0 m/s` |

where `{value}` is `format_fitting_amount`'s grouped
one-decimal number (section 5). Lines are produced by a small
pure helper beside the renderer (the `resource_line` precedent,
lines 1162–1172) so the exact strings are unit-test pinned
without an egui harness. All lines use the normal label
colour; there is no over/under state for a bare hull value,
so the resources block's `LIGHT_RED` has no counterpart here.
No module is named, so no row approaches the item-list render
caps: the block is at most a heading, five stat lines, and
the disclosure, and needs no windowing.

**Missing-stat rule (locked).** A stat whose field is `None`
(absent or unusable, section 4) renders **no line** — omitted,
not zeroed, not dashed, not replaced with words. Flutter's
`_dashIfUnmodelled` renders `—` for an engine zero; this slice
inverts it on purpose: `—` would still be a slot where a
reader supplies a number, and a rendered `0.0` would assert a
fact the data does not carry. The remaining stats still
render, and the disclosure still renders last. Only when no
stat is usable (or there is no ship row at all) does the
fixed unavailable sentence replace all lines and the
disclosure — a partial block with its disclosure is more
honest than either blanking four good values or inventing
per-stat "unknown" text. On today's catalogue this path is
unreachable for real ships (section 2: all 404 carry all
five); it exists so a future catalogue gap degrades one line,
not the block, and it is proven by fixtures (section 8).

The renderer logs nothing itself (section 4). The resources
renderer, its call sites (lines 1430 and 1716), and every one
of its locked strings are untouched: the new call is an
additional statement after each existing call, which is the
entire diff surface beside the new renderer.

## 7. Demo story (locked)

The demo hulls are real catalogue ships even though their
fitted items are partly invented sample rows
(`assets/demo/fittings.json`, read in full), so every demo fit
shows honest, hand-computed base values for its actual ship.
No demo data changes in this slice.

- Demo Brawler and Mission Runner (both Rifter 587; cache rows
  263 `450.0`, 265 `450.0`, 9 `350.0`, 482 `250.0`, 37
  `365.0`):

  ```text
  Ship (base values)
  Shield: 450.0 HP
  Armor: 450.0 HP
  Hull: 350.0 HP
  Capacitor capacity: 250.0 GJ
  Max speed: 365.0 m/s
  ```

  followed by the section 6 disclosure. The invented module
  rows in these fits (a blueprint, an ore, absent type
  numbers) change none of these numbers, because the pure
  function never reads items (section 4) — which the
  identical blocks on both Rifter fits demonstrate.
- Demo Runner (Punisher 597; cache rows 263 `350.0`, 265
  `500.0`, 9 `450.0`, 482 `400.0`, 37 `355.0`):

  ```text
  Shield: 350.0 HP
  Armor: 500.0 HP
  Hull: 450.0 HP
  Capacitor capacity: 400.0 GJ
  Max speed: 355.0 m/s
  ```

- The demo sample import ("Use sample EFT" / "Use sample
  DNA", both the `[Rifter, Sample Brawler]` fit;
  `DEMO_SAMPLE_DNA` begins `587:`) shows the same Rifter block
  in the imported detail, identically under either demo
  character: base ship values never depend on who is viewing.
  This is the clean no-account walkthrough: demo → Fittings →
  Use sample EFT → Import fitting, then scroll.

**Visibility expectation (locked wording for reviewers).** The
Fittings view renders inside the shell's vertical scroll area
(`src/app/shell.rs:3207`), and in both details this block sits
below the item sections and the resources block. It will
therefore normally sit **below the fold**, exactly as the
resources block does today: a reviewer must scroll to see it,
and a screenshot of just the first screenful must not be
graded as "block missing". The integrator's visual pass
(section 9) scrolls to it in both details.

## 8. Test plan (locked)

Oracle numbers below were read during design from the cache
rows themselves (`scripts/sde/dgmTypeAttributes.csv.bz2`; every
quoted row has `valueInt` `None` and the `valueFloat` shown):
Rifter 587 (263 `450.0`, 265 `450.0`, 9 `350.0`, 482 `250.0`,
37 `365.0`); Punisher 597 (`350.0`, `500.0`, `450.0`, `400.0`,
`355.0`); Legion 29986 (`1800.0`, `2900.0`, `1800.0`,
`1800.0`, `185.0`); Raven 638 (`7700.0`, `6380.0`, `7040.0`,
`5500.0`, `113.0`); Echelon 3532 (482 `187.5`); Helios 11172
(482 `218.75`); Mekubal 78333 (37 `322.3`); Komodo 45649 (263
`950000.0`). Flutter's engine tests use synthetic Rifter hull
values (400/400/350/300 in `dogma_engine_test.dart` at
`ed698d3`); they are test doubles, not oracles, and are not
ported. Test comments quote the cache rows as the resources
tests do (`src/fitting/resources.rs:258-261`).

**Pure calculation** (`src/fitting/ship_stats.rs`, Builder A),
against the real bundled catalogue where stated, floats exact
(these are stored values, no arithmetic — `assert_eq!` on the
`Option<f64>`s, stronger than the resources `1e-9` tolerance):

- Oracle ships: Rifter, Punisher, Legion, and Raven each
  return `Available` with all five literal values above.
  Fractional pins: Echelon capacitor `Some(187.5)`, Helios
  capacitor `Some(218.75)` (exact in the API; only display
  rounds), Mekubal velocity `Some(322.3)`.
- Items are ignored: a Rifter with fitted modules (including
  an unknown type and a stacked quantity) returns results
  equal to the hull-only Rifter. This is the no-modifiers
  lock as a test: any future "add module bonuses" edit fails
  here first.
- Ship failures: unknown ship ID (999999), non-ship ship ID
  (2048 Damage Control II), and `ship_type_id` 0 and -1 all
  return `Unavailable`.
- Absent versus zero (fixture catalogue via
  `FittingTypes::from_json`, the path shipped data cannot
  exercise, section 2): a category-6 row with `shieldCapacity`
  absent, `armorHP` present as `0.0`, and the rest present
  returns `Available` with shield `None` and armor
  `Some(0.0)`; a category-6 row with none of the five keys
  returns `Unavailable` (the all-absent collapse, section 4);
  a row with exactly one stat present returns `Available`
  with four `None`s.
- Guard pins (fixture): a negative catalogue value is treated
  as no data for that stat only (JSON cannot spell NaN, so
  the non-finite half is pinned through a directly
  constructed row or left to the `usable` filter's symmetry
  with `resources.rs`, whose tests already pin the rule).
- Independence (fixtures): a category-6 row with `cpuOutput`/
  `powerOutput` but no stat keys gives `fitting_resources`
  `Available` and `ship_base_stats` `Unavailable`; a row with
  stat keys but no outputs gives the reverse. Real-catalogue
  companion: the Echelon (3532) is a present-zero-output ship
  whose stats are fully `Available` — resources reads
  `0.0`/`0.0` outputs while the stats block shows real hull
  numbers, proving the two availabilities separate.

**Catalogue** (`src/names/fitting_types.rs` + generator,
Builder A): the section 3 invariants and spot pins; old-fixture
JSON without the new keys still loads (the existing fixture
tests prove it and must pass unmodified); generator run twice
→ identical sha256, and new-keys-stripped output byte-identical
to the base sha256 in section 2 (reported in the commit body,
not committed); regenerated byte count within the section 3
budget, exact count in the commit body.

**UI wording and formatting** (`src/ui/fittings.rs`, Builder B),
string-exact through the pure line helper:

- The five Rifter lines and five Punisher lines from
  section 7, built from real `ship_base_stats` results over
  the bundled catalogue (proving demo fixture drift would
  fail a test, not surprise a reviewer).
- Formatting pins through the lines: `7,700.0 HP` (Raven
  shield, thousands grouping), `950,000.0 HP` (Komodo
  shield), `187.5 GJ` (Echelon), `218.8 GJ` (Helios — the
  section 5 rounding pin: exact `218.75` in the API, one
  decimal on screen), `322.3 m/s` (Mekubal — fractional
  velocity survives, where Flutter's integer display would
  show `322`).
- Present zero renders, absence omits: the section 8 fixture
  stats produce an `Armor: 0.0 HP` line and **no** shield
  line (the helper returns no line for `None`; the assertion
  is on absence, not on a placeholder string).
- The heading, both unavailable sentences, and the disclosure,
  verbatim, following the resources wording-pin precedent
  (`fitting_resource_unavailable_and_disclosure_wording`).
- Imported path: the section 7 sample fit through
  `parse_eft` → `to_character_fitting()` →
  `ship_base_stats` yields the Rifter block, proving the
  imported detail's synthesis seam.

**Regression gate (both builders).** Every existing resources
test in `src/fitting/resources.rs` and every resources wording
and demo pin in `src/ui/fittings.rs` (base and skill-applied)
passes **unmodified** — stated as a gate, like the
skill-resources design's byte-identical-base gate, rather than
re-pinned here. `src/fitting/resources.rs`,
`render_fitting_resources`, and its constants must not appear
in this slice's diff at all.

**Gates at every commit** (repo standard): `cargo test`,
`cargo clippy --all-targets -- -D warnings`, `cargo fmt
--check`. Existing fitting, import, export, demo, and
catalogue tests pass unmodified except where this design
explicitly extends them.

## 9. Integrator list (locked)

The integrator (not the builders) makes these changes after
both builders land:

- **README** — three sites (line numbers at `f8fc6da`), all
  keeping the rule that base ship values are not fitting
  statistics: the words "simulator" and "statistics" must not
  attach to the new numbers, and no sentence may imply fitted
  totals.
  1. The Fittings bullet (line 22): the resources sentence
     ("Selecting a saved fitting or importing one also shows
     its CPU and power grid use …") gains a joined sentence
     for the base ship values in the same honesty terms — the
     ship's base shield, armor, hull, capacitor capacity, and
     max speed values from the bundled item data, with fitted
     modules, rigs, subsystems, skills, implants, and ship
     bonuses not applied. **The closing denial must also be
     corrected:** today's "There are still no DPS, tank,
     capacitor, or speed numbers." becomes false the moment
     this slice lands, because base capacitor capacity and
     base max speed now render. It must narrow to what stays
     true — no DPS or tank numbers (no resistances, no EHP,
     no recharge or stability figures) — without denying the
     base values the previous sentence just described. The
     neighbouring "not been live-verified" caveat is
     unaffected and stays.
  2. The Roadmap Fitting bullet (line 31): the parenthetical's
     CPU/power readout phrase gains the base ship values
     readout beside it; "ship fitting simulator with fitting
     statistics" stays listed as not implemented.
  3. The Status paragraph (line 37): the "only fitting
     features" enumeration gains the base ship values
     readout; "the fitting simulator is not present yet"
     stays true.
- **Engineering journal** — a dated `LEARNINGS.md` entry in
  the same change set (repo rule), with Evidence (file:line),
  Mechanism, and a one-line generalizable rule, covering:
  (a) the all-five coverage finding — every one of the 404
  published ships carries all five base attributes with no
  absent or explicit-zero rows, so the absent-versus-zero
  honesty path ships unexercised by real data and is proven
  only by fixtures, while 40,923 wanted rows on non-ships are
  what make the category-6 emission gate load-bearing; and
  (b) the `dogmaUnits` unit-11 quirk (an "Acceleration" unit,
  described as metres per second squared, carrying the
  maximum-velocity attribute, with `m/s` locked as the
  rendered string over the English `m/sec`). Plus a short
  `DECISIONS.md` entry if implementation confirms the
  convention this design assumes — each new base-attribute
  block ships as its own heading plus disclosure with
  availability independent of its neighbours — with a
  "revisit when" condition. Keep both short.
- Confirm the slice diff contains no ESI, scope, persistence,
  network, demo-asset, or resources-stack changes (section 8
  regression gate: `src/fitting/resources.rs` and
  `render_fitting_resources` untouched), that the regenerated
  catalogue byte count in Builder A's commit body matches the
  committed file and sits within the section 3 budget, and
  run a demo-mode visual pass over the section 7 demo story
  (all three demo fits plus the sample import), scrolling to
  the block in both details per section 7's below-the-fold
  expectation, before reporting done.

## 10. Exclusions (locked)

Out of this slice, by name: resistances of every layer and
EHP (effective hit points) in any form, including a summed
"total HP" line; shield and capacitor recharge rates, times,
peak recharge, and capacitor stability, and any capacitor
simulation; DPS, volley, targeting, and every other fitting
statistic; all modifier application — fitted modules (including
per-module hit-point, capacitor, or speed contributions
itemized anywhere), rigs, subsystems (including emitting or
reading subsystem rows for these attributes), ship role and
trait bonuses, implants, and skills, explicitly including the
six Flutter `_skillModifiers` entries not yet applied anywhere
in Rust (Navigation 3449 → 37, Capacitor Management 3418 →
482, Shield Management 3419 → 263, Hull Upgrades 3394 → 265,
Mechanics 3392 → 9, Shield Operation 3416 → 479); stacking
penalties of any kind; any trained-skill input reaching
`ship_base_stats` (the signature takes none); the fitting
editor and any fitting mutation; percentages and bars; any
change to the resources block's behavior, wording, or
availability logic in either its base or skill-applied state;
ESI calls, scopes, and stored data; demo fixture changes;
reading `dogma.json`, `effect_modifiers.json`, or the pinned
zip at runtime (design-time grounding sources only). Anything
on this list appearing in a builder commit is a design breach,
not a bonus.

## 11. Ownership (locked)

Small atomic commits, `type(scope): description`, no
attribution. Nobody pushes or merges; the parent does that.

- **Builder A — data and pure calculation.** (1) Generator
  extension + regenerated `assets/sde/fitting_types.json` +
  loader fields + invariants (exact new byte count and both
  determinism proofs in the commit body). (2)
  `src/fitting/ship_stats.rs` with its tests, wired in
  `src/fitting/mod.rs`. Commit (2) must compile and pass
  gates with no UI change (dead-code warnings handled by the
  re-export, not by `#[allow]`). Builder A touches no
  `src/ui/` files and no `src/fitting/resources.rs`.
- **Builder B — UI.** (3) `render_ship_base_stats`, its line
  helper, its locked-string constants, and both call sites in
  `src/ui/fittings.rs`, with wording and demo pins (section
  8). No `src/ui/widgets.rs` change is needed or permitted —
  the formatter is reused as-is (section 5); if a formatter
  change seems necessary, stop and take it back to this
  document. Builder B changes no catalogue, generator,
  `src/fitting/`, or demo files, and must not modify
  `render_fitting_resources` or any resources constant — the
  call-site diffs are added statements after the two existing
  calls (section 6).
- **Integrator.** (4) README + engineering journal (section
  9), any cross-builder seam fix the two halves reveal
  (signature drift between sections 4 and 6 is the
  integrator's to reconcile back to this document, not to
  whichever builder wrote first), final gates, and the demo
  visual pass including the below-the-fold scroll check
  (section 7).

Sequencing: A(1) → A(2) → B(3) → integrator (4). B(3) needs
A(2)'s API; nothing else in the slice has slack to reorder.

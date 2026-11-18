# Fitting need reductions (five trained-skill module need reductions) — design

Status: locked for the `feat/rust-fitting-need-reductions` slice.
Base: `develop` at `3ae16f8` (verified clean before branching; the
base fitting-resources readout from `docs/fitting-resources-design.md`
and the two skill-applied ship outputs from
`docs/fitting-skill-resources-design.md` are merged there). Slice
branch: `feat/rust-fitting-need-reductions`. This document is the
single design commit; builders and the integrator implement exactly
what is locked here and nothing else.

## 1. Goal and value ranking

Reduce counted module CPU and power grid needs in the existing
fitting-resources block by the five trained skills whose complete
modifier data is present in the committed Static Data Export (SDE)
files (section 2), at the fitting-owning character's trained levels,
when that character's skill data is loaded. Ship outputs keep the
two already-shipped skill bonuses. When skill data is not loaded,
the current base-values block renders exactly as it does today,
byte for byte. No network, no ESI changes, no new scopes, no
persistence: trained levels come from the skills state already
loaded for the Skills view, and per-module filter inputs come from
the bundled fitting catalogue after the generator extension in
section 4.

This slice is **not a port of Flutter fitting behavior**. The
retired Flutter engine at `ed698d3` never reduced module needs:
usage is a raw sum (`cpuUsed += type.cpu; powerUsed +=
type.powergrid`, `dogma_engine.dart:688-695`), no `moduleAttr`
call reads attributes 50/30, and no fitting test pins any need
changing with skill level. What Flutter does ground is the
*formula machinery* — how a skill's per-level attribute becomes an
unpenalized post-percent factor on a filter-matched module
attribute (section 2.2). The reductions themselves are new
behavior justified only where the committed SDE files carry the
full modifier triple and that machinery defines the arithmetic.
Anything beyond that ships nothing and is named deferred in
section 2.3, with the exact missing data.

Value ranking (locked, in order):

1. **Never show an unlabeled partial total, and never replace a
   base figure silently.** This outranks the rest by a wide
   margin. The applied block shows the reduced used figures in
   the existing CPU/power grid lines **and** the base used
   figures on their own lines, names every skill that can reduce
   a need with its level and percent, and counts every module
   that had to stay at full need because its reduction could not
   be proven (sections 6 and 8). A reduced number computed from
   the wrong character, from no data, from an invented percent,
   or from an invented group or skill mapping is the same failure
   as an unlabeled partial total.
2. **Correctness of the arithmetic.** Every percent, filter, and
   test literal must be hand-verifiable against the inspected
   SDE rows and Flutter bodies cited in sections 2 and 3, and
   against real catalogue rows (section 9). No per-level percent
   and no group or required-skill mapping comes from memory or
   from what "EVE surely does".
3. **Reuse.** The existing pure function and its `Option`
   loaded-vs-not-loaded contract, the switch-boundary skills
   reset shipped with the output bonuses, the generator's
   additive-emission pattern, and the SDE skill-name plumbing
   beat new machinery. In particular this slice does **not**
   build the general modifier pipeline: the twelve locked
   modifier entries are a table, evaluated directly.

Non-goals are locked in section 11. In particular: no general
dogma modifier engine, no module/rig/subsystem/ship need or
output modifiers beyond the seven skills in total (two shipped
output skills plus the five here), no implants, no calibration,
no new fitting statistic of any kind, no editor.

## 2. Evidence and the ship/defer decision (locked)

Every identifier, percent, and filter below was re-derived during
design by scripted read-only inspection of the three committed
SDE sources — `scripts/sde/dgmTypeEffects.csv.bz2`,
`scripts/sde/dgmTypeAttributes.csv.bz2`, and
`dogmaEffects.jsonl` inside
`scripts/sde/eve-online-static-data-3503375-jsonl.zip` — joined to
`scripts/sde/invTypes.csv.bz2` / `invGroups.csv.bz2` and to the
shipped `assets/sde/fitting_types.json`. The Flutter bodies were
re-read at `ed698d3` via `git show`. Nothing comes from memory
and nothing was fetched from the network.

### 2.1 What ships: five skills, twelve modifier entries

An exhaustive scripted scan of every published category-16
(Skill) type for attributes 310 (`cpuNeedBonus`) or 323
(`powerNeedBonus`) in `dgmTypeAttributes.csv.bz2` returns exactly
five skills. For each one, `dogmaEffects.jsonl` carries the
resolved `modifierInfo` entries that spend that attribute, so the
full data a reduction needs — source skill, per-level value
attribute, operation, modified attribute, and target filter — is
present in the committed files with no extra table:

| Source skill (type ID) | Per-level value | Dimension | Modifier entries that ship (effect → filter) |
|---|---|---|---|
| Weapon Upgrades (3318) | 310 = −5.0 | CPU need (50) | 581 → requires Gunnery (3300); 581 → requires Vorton Projector Operation (55033); 675 → requires Energy Pulse Weapons (3421); 677 → requires Missile Launcher Operation (3319); 3519 → group 862 (Missile Launcher Bomb) |
| Advanced Weapon Upgrades (11207) | 323 = −2.0 | Power need (30) | 1638 → requires Gunnery (3300); 1638 → requires Missile Launcher Operation (3319); 1638 → requires Vorton Projector Operation (55033); 3520 → requires Bomb Deployment (28073) |
| Energy Grid Upgrades (3424) | 310 = −5.0 | CPU need (50) | 396 → requires Energy Grid Upgrades (3424) |
| Electronics Upgrades (3432) | 310 = −5.0 | CPU need (50) | 212 → requires Electronics Upgrades (3432) |
| Shield Upgrades (3425) | 323 = −5.0 | Power need (30) | 273 → requires Shield Upgrades (3425) |

Filter skill names were read from the same committed files
(3300 Gunnery, 3319 Missile Launcher Operation, 3421 Energy
Pulse Weapons, 55033 Vorton Projector Operation, 28073 Bomb
Deployment; group 862 is "Missile Launcher Bomb" in
`invGroups.csv.bz2`). Every shipped entry has the same shape in
`dogmaEffects.jsonl`: domain `shipID`, operation 6,
modifiedAttributeID 50 or 30, modifyingAttributeID 310 or 323,
func `LocationRequiredSkillModifier` with a `skillTypeID` filter
— except effect 3519, whose single entry is func
`LocationGroupModifier` with `groupID` 862. `dgmTypeEffects`
confirms each effect rides on its source skill type (3318:
211/581/672/675/677/3519; 11207: 246/1638/3520; 3424: 211/396;
3432: 211/212; 3425: 246/273; effect 132 also rides on every
skill and is dealt with in section 2.3). No `dgmExpressions`
table is needed or used: the zip carries no such member, and
`modifierInfo` already ships resolved (the generator comment at
`scripts/sde/generate_dogma_sde.py:55-64` records the same fact
for the sibling dogma extract).

Scripted reach over the shipped catalogue (category-7 rows with
a slot effect and at least one need key, 3,183 rows, section 4):
Weapon Upgrades matches 906 module types, Advanced Weapon
Upgrades 781, Energy Grid Upgrades 128, Shield Upgrades 117,
Electronics Upgrades 21. No shipped row matches two entries of
the same source skill, and no shipped row matches two source
skills on the same dimension; the product rule for those cases
is still locked in section 3 for fixtures and future caches.

### 2.2 The formula is grounded by inspected Flutter machinery

No Flutter body applies these five skills (section 1). The
arithmetic is nevertheless fully defined by Flutter's *generic*
skill-modifier path at `ed698d3`, which this design re-reads and
reuses piece for piece:

- **Per-level scaling.** The skill-owner loop builds
  `ownerAttributes` as *every* base attribute of the skill type
  multiplied by the clamped trained level
  (`dogma_engine.dart:596-612`: level
  `(skillLevels[skillId] ?? 0).clamp(0, 5)`, skip on 0, then
  `attr.value * level`). So attribute 310 = −5.0 contributes
  −5.0 × level, and 323 = −2.0 contributes −2.0 × level,
  regardless of which "boost" effect carries the row. This is
  also why the item-domain boost effects below must not be
  applied a second time (section 2.3).
- **Filter evaluation.** `routeLocationModifier`
  (`dogma_engine.dart:377-533`) treats the entry's `skillTypeID`
  as "targets must require this skill" and evaluates it with
  `requiresSkill`: exact equality over the module's six
  required-skill attributes 182, 183, 184, 1285, 1289, 1290
  (`requiredSkillAttributeIds`, `dogma_engine.dart:40-51`;
  its comment matches pyfa's `Item.requiredSkills`). A
  `groupId` on the entry restricts targets to module types with
  that exact `groupId` (`type.groupId != modifier.groupId` is
  skipped), and a target that does not carry the modified
  attribute is skipped. Skill-owned routing passes the value
  raw (`scale = 1.0` for non-ship owners) because the ×level
  scaling above already happened.
- **Operation 6.** postPercent stores factor `1 + raw/100` per
  modifier entry (`store` inside `routeLocationModifier`;
  operator codes pinned at `dogma_engine.dart:25-34` and
  `models.dart:321-331`: "6 = postPercent (`modified *= 1 +
  value/100`)").
- **Chaining.** Skill-owned bonuses are stored
  `penalized: false`, and `_applyBonuses`
  (`dogma_engine.dart:182-207`) multiplies unpenalized factors
  straight onto the base: `base × Π factors`. There is no
  stacking penalty for skill owners, and attributes 50/30 are
  not in `_nonStackableAttributes` (exactly the 12 resistance
  attributes, `dogma_engine.dart:112-128`) either.
- **The one exercised skill-to-module oracle.** Repair Systems
  (skill 3393, effect 272, in the allowlist) applies
  `durationBonus` −5.0 × level 5 = −25 through an operation-6
  `LocationRequiredSkillModifier` onto a module attribute, and
  test E2.7 pins the outcome (`dogma_engine_test.dart:1410-1492`,
  `effectiveArmorRepair` closeTo 112.444). That is the identical
  chain — skill attribute × level → required-skill filter →
  post-percent on a module attribute — with a different target
  attribute. The need reductions reuse the chain; only the
  target attributes (50/30 instead of 73) and the table of
  entries are new.

The present Rust tree applies none of this to needs:
`src/fitting/resources.rs:12-16` states "Module needs are never
scaled", the used-sum loop at `src/fitting/resources.rs:170-197`
sums raw catalogue needs, and the shipped catalogue carries
neither a module's group nor its Required skills (scripted
census of `assets/sde/fitting_types.json`: 25,818 types, zero
rows with a `groupId` or required-skill key — sections 4 and 5
add exactly that).

### 2.3 What ships nothing, with the exact missing data

Each of these is deferred by name. None of them may be
approximated, folded into a shipped percent, or left as a silent
gap:

- **Effect 672, `weaponUpgradesSkillBoostCpu`** (on Weapon
  Upgrades 3318, its only carrier):
  `ItemModifier`, domain `itemID`, modified 50, modifying 280
  (`skillLevel`), operation 0. Flutter's skill loop skips every
  `itemID`-domain modifier outright (`if (modifier.domain ==
  'itemID') continue`), so no inspected body defines what this
  entry would do to a fitted module's need, and no test oracle
  exercises it. Modelling it would require a decision the
  evidence cannot make. Deferred; named in the code table's
  provenance comment as deliberately absent.
- **The skill-effect and boost effects 132, 211, and 246.**
  132 writes `skillLevel` (280) on the skill item itself;
  211/246 write 310/323 from 280, all `itemID` `ItemModifier`s.
  They are the client-side spelling of the same ×level scaling
  the Flutter owner-attributes step performs (section 2.2), so
  this slice models the scaling once, in the formula, and gives
  these effects no table entries. Counting them again would
  double-scale every reduction. This is a locked reading, not
  an omission: builders must not "complete the chain".
- **The three unpublished siblings**: Advanced Energy Grid
  Upgrades (11204), Advanced Shield Upgrades (11206), Advanced
  Sensor Upgrades (11208). All are `published=0` in
  `invTypes.csv.bz2`, carry a 0.0 bias on 310/323, and ride
  effects 396/273/212. They are absent from the bundled skills
  catalogue and can never appear in a character's trained
  payload. No constants, no levels, no table rows for them.
- **Every non-skill carrier of 310/323 and every other need
  modifier** (implants such as the category-20 Zainou 'Gnome'
  rows, and any module, rig, subsystem, or ship effect that
  modifies 50/30). The fitting model holds no implants, and the
  rest needs the general modifier pipeline this slice
  deliberately does not build (section 1, rank 3). They stay
  named as not applied in the applied disclosure (section 8).
- **Any reduction whose entry is not in the section 2.1 table.**
  If a future cache adds a 310/323 skill or a new filter, it
  ships nothing until a new design adds the table row from
  inspected rows. The runtime never discovers reductions from
  the catalogue at load time.

## 3. Reduction arithmetic (locked)

For one counted module row (the base design's counting rules:
low/medium/high flag, `type_id > 0`, quantity clamped with
`max(0)` and quantity 0 skipped, catalogue row present, and a
usable need in the dimension — all unchanged from
`docs/fitting-resources-design.md` section 3), with base need
`b` in one dimension:

```text
factor     = Π over matched entries (1 + per_level(entry) * level(source(entry)) / 100)
reduced    = b * factor
contribution to used = quantity * reduced
contribution to base_used = quantity * b
```

- `per_level` is the SDE percent value from section 2.1: −5.0
  for every Weapon Upgrades, Energy Grid Upgrades, Electronics
  Upgrades, and Shield Upgrades entry; −2.0 for every Advanced
  Weapon Upgrades entry. Code stores these as percents (−5.0 /
  −2.0), never as 0.05-style fractions, so the table can be
  checked against the `dgmTypeAttributes` rows character for
  character. Level 5 therefore gives ×0.75 (or ×0.90 for
  Advanced). Per-level compounding is the forbidden mutant:
  0.95⁵ = 0.7738… and 0.98⁵ = 0.9039… must both fail the tests
  (section 9).
- **One factor per matched modifier entry**, not per skill and
  not per module. This is Flutter's storage rule (one `_Bonus`
  per entry, section 2.2). Two entries of one skill matching
  one module, or two skills matching one dimension, multiply:
  ×0.75 × ×0.75 = ×0.5625 at both level 5. Scripted shipped
  data contains zero such rows (section 2.1), so on the shipped
  catalogue at most one factor differs from 1 per need; the
  product rule is pinned by labelled synthetic fixtures.
- **Matching.** A required-skill entry matches when its filter
  skill ID is an element of the module row's
  `required_skill_ids` (exact integer equality — the runtime
  form of Flutter's six-slot `requiresSkill`). The group entry
  (3519, CPU only) matches when the row's `group_id` is exactly
  862. Matching is decided per dimension from the dimension's
  entries only; a CPU entry never touches power and vice versa.
- **Skill-level lookup is by source skill, never by filter
  skill.** The filter names what the *module* must require; the
  level comes from the *source* skill in the left column of the
  section 2.1 table. Training Gunnery (3300) or any other filter
  skill changes nothing by itself — pinned as the wrong-ID trap
  alongside the existing 3418 trap (section 9).
- **Levels clamp to `0..=5`** exactly as the shipped output
  skills do (`clamp_level`, `src/fitting/resources.rs:49-51`):
  negative becomes 0, above 5 becomes 5, `i32::MIN`/`i32::MAX`
  cannot panic or overflow (convert after clamping). The pure
  function re-clamps defensively, so a hand-built levels struct
  cannot exceed ×0.75 / ×0.90 per entry.
- **Level 0 is factor 1**, whether the row is present at
  trained level 0 or absent from a loaded bundle (section 7
  states the loaded-bundle honesty rule in full). A matched
  entry at level 0 is a proven no-reduction, never an error and
  never counted as unreduced (section 6).
- All math is `f64`, reduced per module before the quantity
  multiplication, with no rounding until display — the
  existing `format_fitting_amount` one-decimal rule, unchanged.
  A present explicit `0.0` need stays a real `0.0` under any
  factor. Reductions never resurrect an excluded dimension: a
  need that is absent, non-finite, or negative in the catalogue
  follows the base excluded path before any factor is
  considered, and a fitting whose ship has no usable output is
  still `ShipNoOutput` at every level.

## 4. Catalogue emission (locked)

The bundled catalogue (`assets/sde/fitting_types.json`, today
3,622,804 bytes, 25,818 types, sha256
`e12703223bd555d0f41221d3989412a4433331d112578386eefc85f256d27d27`)
gains the two per-module filter inputs through its existing
generator only (`scripts/sde/generate_fitting_types_sde.py`).
Hand-editing the JSON is forbidden, as with every generated
asset in this repo. The generator keeps reading only the four
committed Fuzzwork caches it reads today; it does **not** open
the jsonl zip, and the runtime modifier table (section 6) is
not duplicated into the generator. The generator copies two raw
filter inputs; interpretation lives in the pure Rust layer,
following the resources precedent (raw 48/11/50/30 values in the
asset, the +5%-per-level output rule as a runtime constant).

**New source data, read with the existing patterns:**

- Attributes 182, 183, 184, 1285, 1289, 1290 from
  `dgmTypeAttributes.csv.bz2` (the six required-skill slots; a
  named constant with a provenance comment citing
  `dogmaAttributes.jsonl` and Flutter's
  `requiredSkillAttributeIds` at `ed698d3`, mirroring the
  `RESOURCE_ATTR_IDS` comment at generator lines 133-141).
  Scripted cache facts the design relies on: every one of the
  11,760 such rows carries `valueFloat` (`valueInt` is always
  the literal `None`), so values parse from `valueFloat` like
  every other attribute set. A value that is unparseable,
  non-finite, non-integral, or ≤ 0 in a wanted row is a
  `fail(...)`; a duplicated `(typeID, attributeID)` pair or a
  duplicated skill within one type's six slots is a
  `fail(...)` — the generator fails loudly and writes nothing,
  per its header contract. (Over the emission population below:
  4,306 slot values, zero duplicates, zero bad values.)
- The module's group from the `invTypes.csv.bz2` `groupID`
  column the generator already reads for `categoryId`
  (generator line 1708). Emitted as the integer ID; an
  unparseable value on an emission-population row is a
  `fail(...)`.

**Emission rule (additive, locked key order).** For each type
row, existing keys keep their order; the two new keys append
after the last existing keys (the sustained-tank repair markers
ending in `structureRepair`), in the order `groupId`, then
`requiredSkillIds`, exactly on the population that gains a
`cpu` or `power` key today — category 7, non-empty
`slotEffects`, and at least one of attributes 50/30 present
(the rule at generator lines 1801-1807). Every other row is
byte-identical to today.

- `"groupId": <int>` — always present on population rows (the
  `groupID` column always exists for them; category 7 could
  only be assigned from a found group).
- `"requiredSkillIds": [<int>…]` — always present on population
  rows, **including as an empty list**. Values are the six
  slots in attribute order 182, 183, 184, 1285, 1289, 1290,
  absent slots skipped, emitted as integers (3300, never
  3300.0). Always-present is load-bearing: it is what lets the
  loader tell "proven to require nothing relevant" (present
  list) from "filter data not in this catalogue" (absent key,
  section 6's unreduced rule). Sparse-when-empty emission was
  rejected for exactly that conflation.
- Rigs gain neither key (they gain no needs today: slot effect
  2663 rows carry no 50/30), ships gain neither key (their
  required skills never gate a *module* need), and the
  discounted category-66/32 populations other slices read gain
  neither key (this pure layer counts needs only where `cpu` /
  `power` keys exist). Dead filter data on rows no locked
  computation reads was the rejected alternative, per the base
  design's subsystem-output precedent.

**Expected counts, oracles, and size.** Scripted against the
shipped catalogue and caches during design: population 3,183
rows (`cpu` on 3,177, `power` on 3,183); `groupId` on 3,183;
`requiredSkillIds` on 3,183 (3,175 non-empty, 8 empty; 4,306
values in total). Generator self-validation grows in the
existing style — an oracle list plus an expected-counts map
covering: 2889 (200mm AutoCannon II) groupId 55, required
[3302, 3300, 11084]; 4256 (Bomb Launcher II) groupId 862,
required [28073]; 2048 (Damage Control II) groupId 60,
required [3394]; 1355 (Reactor Control Unit II) groupId 769,
required [3424]; 37303 (Dual 1000mm Railgun II) groupId 74,
required [41406, 21666, 3300]; 33981 (power-only row) groupId
1289, required [3455]; 1236 (Overdrive Injector System II, no
needs) neither key; 587 (Rifter) neither key; and the
catalogue-wide invariants of section 5 restated as fail-loud
checks. A simulation of the locked emission (appending
`,"groupId":G,"requiredSkillIds":[…]` in compact separators to
the 3,183 population rows) adds 131,893 bytes, for
**3,754,697 bytes expected**; the regenerated file must land at
or below **3,770,000 bytes** or the builder stops and reports
(the budget precedent). The summary print gains the two key
counts; the integrator pins the exact new byte count and sha256
in the merge report.

**Proof obligations (Builder A, reported in the commit body,
not committed as scripts):** run the generator twice and
compare sha256 (determinism); strip the two new keys from the
regenerated file and compare byte-for-byte with the base
sha256 above (additive-only proof). The new asset still loads
on old code (no `deny_unknown_fields`), and old assets still
load on new code (both loader fields are `default`, section 5).

## 5. Loader fields and invariants (locked)

`FittingType` (`src/names/fitting_types.rs:22`) gains two fields
after the last existing fields (the sustained-tank markers
ending at `structure_repair`), each `#[serde(default)]` so old
assets and hand-built test fixtures without the keys load —
as `None`, which is a meaningful value in section 6, not a
default to paper over:

```rust
#[serde(rename = "groupId", default)]
pub group_id: Option<i64>,
#[serde(rename = "requiredSkillIds", default)]
pub required_skill_ids: Option<Vec<i64>>,
```

`Option<Vec<…>>` over a plain defaulted `Vec` is the load-bearing
choice (`slot_effects` uses the plain-Vec shape and is *not* the
precedent here): `None` means "this catalogue carries no filter
data for the row", `Some([])` means "filter data present; the
module requires no skills". Conflating the two would make
section 6's unprovable-reduction count unimplementable — the
same reasoning the sustained-tank design used for its repair
markers. `PartialEq` is retained. Loading, indexing, and lookup
behavior do not change; nothing is validated at load beyond what
exists today (the pure layer treats hostile values defensively:
negative or zero IDs simply never equal a filter, and duplicates
in the list are harmless under membership matching).

**Invariants to add** to `bundled_catalogue_invariants` in
`src/names/fitting_types.rs`, all over the real bundled asset,
existing invariants passing unmodified:

- `group_id` and `required_skill_ids` are `Some` on exactly the
  rows where `cpu` or `power` is `Some`, and `None` on every
  other row (the section 4 population, restated as a Rust pin).
- Every present `group_id` is > 0; every `required_skill_ids`
  list has at most 6 entries, every entry > 0, no entry repeated
  within a row.
- Counts: 3,183 rows with `group_id`, 3,183 with
  `required_skill_ids`, 4,306 values in total.
- Spot pins identical to the generator oracles in section 4
  (2889, 4256, 2048, 1355, 37303, 33981 present with the listed
  values; 1236 and 587 both `None`).

## 6. Pure API (locked)

All new computation lives in `src/fitting/resources.rs`, inside
the existing entry point. There is no new public function: the
applied result (outputs raised, needs reduced) is one outcome a
caller either asks for with loaded levels or does not, and a
second entry point would invite a view to mix reduced needs
with base outputs. The base contract is preserved exactly:
`fitting_resources(f, c) == fitting_resources_with_skills(f, c,
None)`, and `None` output is number-for-number today's.

```rust
/// Weapon Upgrades: -5% CPU need (attribute 50) per trained
/// level on filter-matched modules. Provenance: SDE attribute
/// 310 = -5.0 on type 3318; effects 581/675/677/3519 in
/// dogmaEffects modifierInfo. (Five constants, this shape.)
pub const WEAPON_UPGRADES_SKILL_ID: i64 = 3318;
pub const ADVANCED_WEAPON_UPGRADES_SKILL_ID: i64 = 11207;
pub const ENERGY_GRID_UPGRADES_SKILL_ID: i64 = 3424;
pub const ELECTRONICS_UPGRADES_SKILL_ID: i64 = 3432;
pub const SHIELD_UPGRADES_SKILL_ID: i64 = 3425;

/// Trained levels of the two resource output skills and the
/// five need-reduction skills, clamped to `0..=5`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ResourceSkillLevels {
    pub cpu_management: i32,
    pub power_grid_management: i32,
    pub weapon_upgrades: i32,
    pub advanced_weapon_upgrades: i32,
    pub energy_grid_upgrades: i32,
    pub electronics_upgrades: i32,
    pub shield_upgrades: i32,
}
```

`resource_skill_levels` extends to all seven IDs with its
existing semantics verbatim: `trained_skill_level` only, absent
row ≡ 0 **inside a loaded payload** (section 7), present 0 ≡ 0,
duplicate rows last-wins, every value clamped. The five
constants are re-exported from `src/fitting/mod.rs` beside the
two existing ones. Existing test literals of
`ResourceSkillLevels` (in `src/fitting/resources.rs` and
`src/ui/fittings.rs`) gain the five new fields at 0 — a
mechanical literal extension; every existing assertion is
unchanged and must pass with the same numbers, which is itself
the level-0-identity gate.

**The entry table is private and complete in one place**: the
twelve entries of section 2.1 (source skill, dimension,
per-level percent, filter kind and value, effect ID in a
comment), so a reviewer can diff it against `dogmaEffects.jsonl`
mechanically. Effect 672 and the section 2.3 deferrals are named
in that comment as deliberately absent. No entry may be read
from `assets/sde/dogma.json` or `effect_modifiers.json` at
runtime; the fitting loader keeps loading only
`fitting_types.json`.

**`ResourceBudget` gains two fields** (existing fields and
methods unchanged; `used` becomes the reduced sum under
`Some(levels)`, so `remaining()` and `is_over()` judge against
the applied output exactly as today):

```rust
pub struct ResourceBudget {
    pub used: f64,
    pub output: f64,
    pub excluded_modules: usize,
    /// Sum of counted needs before skill reductions. Equals
    /// `used` when no levels are applied.
    pub base_used: f64,
    /// Counted modules kept at full need in this dimension
    /// because the catalogue row carries no filter data to
    /// prove or disprove a reduction (see design).
    pub unreduced_modules: usize,
}
```

**Excluded vs unreduced — the counting contract (locked).**
The two counts answer different questions and never overlap for
one module in one dimension:

- `excluded_modules` (unchanged): the need itself is unusable
  (no catalogue row, no attribute row, non-finite or negative).
  The module contributes 0 to both sums. This check runs first;
  an excluded module is never also unreduced.
- `unreduced_modules` (new): the need **is counted**, at its
  full base value in both `used` and `base_used`, but whether a
  reduction applies cannot be proven because the row's filter
  data is missing — and only when a reduction could have
  mattered. Precisely, for a counted dimension, increment by
  the row's quantity-units (the same unit counting as
  `excluded_modules`) when **all** of:
  1. `levels` is `Some`;
  2. at least one source skill for that dimension has a clamped
     level above 0 (CPU: 3318/3424/3432; power: 11207/3425) —
     when every relevant level is 0 the factor is provably 1
     whatever the filters say, so nothing is unproven;
  3. the filter data that dimension's entries need is absent:
     `required_skill_ids` is `None` (either dimension), or —
     CPU only, because its one group entry lives there —
     `group_id` is `None`.
- Everything else counted is **proven**: complete filter data
  matching no entry (full need, no count), complete data
  matching at level 0 (full need, no count), or a matched
  reduction (reduced `used`, full `base_used`, no count). On
  the shipped regenerated catalogue every counted row has
  complete filter data (section 5 invariant), so shipped-data
  `unreduced_modules` is always 0; the count exists for stale
  or hand-built catalogues, and for honesty if a future cache
  ever breaks the invariant at runtime.

The module header docs are rewritten to state the new truth
precisely: the skill-aware entry point raises the two outputs
*and* reduces needs by the five table skills; the base function
is unchanged; implants and module/rig/subsystem/ship
modifications of outputs and needs are still not applied.
**No new logging in the pure module or the renderer** — both run
at render cadence; the shipped precedent
(`docs/fitting-skill-resources-design.md` section 4) bans
per-frame logging there, and this slice introduces no new
user-action or load-time site that could carry a `[FITTING]`
counts-only line without duplicating render state. The slice's
diagnostic addition is the generator summary print (section 4).

## 7. Level source and ownership (locked, reused)

Nothing in this section is new machinery; it restates the
shipped contracts the five new levels ride on, so builders do
not relitigate them:

- **Field: `trained_skill_level` only** — the same field the two
  output skills read (`resource_skill_levels`,
  `src/fitting/resources.rs:53-74`), with `active_skill_level`
  never read. A test pins the choice for a reduction skill
  (active 5, trained 2 yields the level-2 factor).
- **Absent skill = level 0 = no reduction, stated honestly.**
  ESI returns injected skills only, so inside a **loaded**
  (`Ready`) bundle an absent row means not injected, which is
  arithmetically level 0 — and the applied block says so in
  words (the level-0 line template, section 8). A bundle that
  is **not loaded** is never promoted to level 0: `None` renders
  the base block, whose disclosure says skills are not applied
  at all. The distinction is the existing
  `state.skills.as_ready().map(|data|
  resource_skill_levels(&data.skills))` at both renderer call
  sites (`src/ui/fittings.rs:2605-2607`, 2913-2915), unchanged.
- **Ownership** is the shipped switch-boundary reset:
  `set_active_character` and the removed-active path already
  reset `skills` to `Loading` (`src/app/state.rs:1070, 1296`,
  tests at 2639-2696), so a `Ready` bundle under the current
  active character is that character's. No state change in this
  slice; `SkillsData` gains no fields.
- **Which character**: always the fitting-owning (active)
  character, enforced by the two existing detail gates. No
  per-fitting or per-import fork.

## 8. UI wording (locked verbatim)

One shared renderer, both details, `render_fitting_resources`
(`src/ui/fittings.rs:1341-1415`) — no second code path. Skill
names resolve through `Sde::skill_name_quiet`
(`src/names/sde.rs:141`) against the bundled skills catalogue,
which carries all five names (verified by read: 3318 Weapon
Upgrades, 11207 Advanced Weapon Upgrades, 3424 Energy Grid
Upgrades, 3432 Electronics Upgrades, 3425 Shield Upgrades). A
raw skill ID is never rendered; a catalogue miss degrades to
"Unknown Skill".

**Base state (`None`, and all unavailable states) —
byte-identical to today.** Heading, `resource_line` lines,
excluded lines, disclosure, and both unavailable sentences are
untouched strings (`src/ui/fittings.rs:1182-1201`). This is a
gate, not a re-pin (section 9).

**Applied state (`Available` + `Some(levels)`).** The heading
stays `Fitting resources (with skill bonuses)`. Lines render in
this exact order:

1. CPU line and Power grid line — the existing `resource_line`
   templates and over-budget colour, `used` now the reduced
   sum, `output` the applied output. Over-budget is judged on
   the reduced used against the applied output.
2. The two existing output skill lines, templates untouched
   (`CPU output includes …`, `Power grid output includes …`).
3. CPU base-need line (new pure helper, always rendered):
   `CPU need before skill reductions: {base} tf.` — e.g.
   `CPU need before skill reductions: 114.0 tf.`
4. Power grid base-need line: `Power grid need before skill
   reductions: {base} MW.` These two lines are why the reduced
   `used` in step 1 never replaces a base figure silently: the
   base total is on screen in every applied render, including
   renders where it equals the reduced total.
5. Five need-reduction skill lines (new pure helper in the
   `skill_line` shape), in this order — CPU skills in
   section 2.1 table order, then power skills: Weapon
   Upgrades, Energy Grid Upgrades, Electronics Upgrades,
   Advanced Weapon Upgrades, Shield Upgrades. `{name}` is the
   resolved SDE name; `{pct}` is `level * 5`, except Advanced
   Weapon Upgrades where it is `level * 2`:
   - level > 0, CPU skill: `CPU need of matching modules
     includes {name} level {level} (-{pct}%).` — e.g.
     `CPU need of matching modules includes Weapon Upgrades
     level 5 (-25%).`
   - level > 0, power skill: `Power grid need of matching
     modules includes {name} level {level} (-{pct}%).` — e.g.
     `Power grid need of matching modules includes Advanced
     Weapon Upgrades level 5 (-10%).`
   - level 0: `CPU need of matching modules includes no
     reduction: {name} is level 0.` (and the `Power grid need`
     form). "Matching modules" is load-bearing wording: the
     percent applies per matched module, never to the whole
     dimension, and no line may state a single whole-fit
     percent.
6. Excluded-module lines, existing per-dimension templates,
   unchanged.
7. Unreduced-module lines (new, per dimension, only when that
   dimension's count is above zero; `1 fitted module` singular):
   `CPU counts {n} fitted modules at full need: Mimir's
   bundled item data has no skill-reduction data for them.`
   and the `Power grid counts …` form. These never render on
   the shipped catalogue (section 6); they exist so a mixed
   reduced-plus-unprovable total can never present as fully
   reduced.
8. Applied disclosure, replaced verbatim (the current constant
   at `src/ui/fittings.rs:1197` is superseded by this slice;
   its old "Module need reductions … are not applied" clause
   becomes false and must not survive anywhere in the view):

> Ship outputs and module needs include only the skill bonuses
> and reductions above, from Mimir's bundled item data and this
> character's trained skill levels. Implants, and bonuses and
> reductions from modules, rigs, subsystems, and the ship
> itself are not applied, so these numbers can differ from EVE.

No string in this slice calls these numbers fitting
"statistics" or a "simulator" result.

**No-character and demo behavior (locked).** No active
character, or skills in `Loading` / `Empty` / `Error` (never
refreshed, mid-switch, failed refresh with no bundle), renders
the base block above — reductions are never guessed from a
missing bundle. Demo mode always has `Ready` skills and keeps
rendering the applied block; scripted over
`assets/demo/skillqueue.json` during design, **neither demo
character has any of the five skills** (Aria Voss 90000001:
Power Grid Management 3413 at trained 5, Gunnery 3300 at
trained 4, no reduction skill; Marcus Hale 90000002: CPU
Management 3426 at trained 5, no reduction skill), and neither
fixture changes. Demo used/output numbers therefore stay
exactly the shipped applied story (`Demo Brawler` 84.0/130.0
CPU, 3.0/51.3 power grid; the sample import at 114.0/31.0 for
both importers, outputs per importer as today), while the block
gains the two before-reductions lines (equal to the used
figures) and five level-0 reduction lines. Aria's Gunnery level
4 reducing nothing — filter skill, not source skill — is part
of the locked demo story and is pinned by test, not "fixed".

## 9. Test plan (locked)

There is **no Flutter test oracle for a need value** (section 1);
claiming one would be invention. The literal source for every
number below is the scripted shipped data of section 2 (cache
rows joined to the shipped catalogue, re-derived during
design), and the factor shape's only Flutter citation is the
Repair Systems E2.7 chain (section 2.2), named as such in test
comments. Hand-built `FittingTypes::from_json` fixtures are
labelled synthetic in test comments, per house convention.
Floats within `1e-9` unless a string pin is stated.

**Generator and loader (Builder A).** The section 4 oracle list
and expected counts as generator self-validation (a wrong cache
fails the generator, exit nonzero, nothing written); the
section 5 invariants in `bundled_catalogue_invariants`; the
twice-run and strip-keys proofs reported in the A1 commit body;
exact new byte count stated in the A1 commit body and within
the section 4 budget.

**Pure calculation (`src/fitting/resources.rs`, Builder B)**,
on the real bundled catalogue unless labelled synthetic:

- Level table on one matched module (2889 200mm AutoCannon II,
  base 9.0 CPU / 4.0 power, requires Gunnery): Weapon Upgrades
  levels 0/1/2/5 → CPU used 9.0 / 8.55 / 8.1 / 6.75 with
  `base_used` 9.0 throughout; Advanced Weapon Upgrades levels
  1/2/5 → power used 3.92 / 3.84 / 3.6. Levels 2 and 5 are the
  mutation-sensitive pins: they fail under per-level
  compounding (9 × 0.95⁵ = 6.964…, 4 × 0.98⁵ = 3.615…).
  Dimensions are independent (CPU skill at 5 with power
  skills at 0 scales CPU only, and vice versa).
- One real-row pin per shipped filter entry, source skill at
  level 5: Gunnery (2889 → 6.75/3.6 above); Missile Launcher
  Operation (499 Light Missile Launcher I, 21.0 → 15.75 CPU,
  6.0 → 5.4 power); Energy Pulse Weapons (1547 Small Proton
  Smartbomb I, 30.0 → 22.5 CPU); Vorton Projector Operation
  (54739 Small Vorton Projector I, 97.0 → 72.75 CPU, 26.0 →
  23.4 power); Bomb group 862 plus Bomb Deployment (4256 Bomb
  Launcher II, 55.0 → 41.25 CPU via the group entry, 10.0 →
  9.0 power); Energy Grid Upgrades (1355 Reactor Control Unit
  II, 22.0 → 16.5 CPU, present-0.0 power stays 0.0 and
  unexcluded); Electronics Upgrades (1986 Signal Amplifier I,
  20.0 → 15.0 CPU); Shield Upgrades (377 Small Shield Extender
  I, 2.0 → 1.5 power, 20.0 CPU unchanged). Fractional base:
  37303 CPU 126.5 → 94.875 at Weapon Upgrades 5.
- Wrong-ID traps: a payload with Gunnery (3300), Missile
  Launcher Operation (3319), Energy Pulse Weapons (3421),
  Bomb Deployment (28073), or Capacitor Management (3418) at
  level 5 and no source skill changes no need; a payload with
  only the *other* dimension's source skill changes nothing in
  this dimension. Non-matching module at all skills level 5:
  2048 Damage Control II stays 30.0/1.0, `base_used` equal,
  both counts 0.
- Sample fit through the shared EFT synthesis path (the
  existing 114.0/31.0 oracle: three 2889s are its only matched
  modules): at Weapon Upgrades 5 + Advanced Weapon Upgrades 5,
  CPU used 107.25 against `base_used` 114.0, power used 29.8
  against `base_used` 31.0, both counts 0; the existing base
  sample test passes unmodified on the `None` path.
- Identity and guards: `None` equals base including
  `base_used == used` and `unreduced_modules == 0`;
  `ShipNoOutput` at all-5 levels; lookup pins for the seven IDs
  (absent ≡ 0, trained-not-active, duplicate last-wins,
  −3/7/`i32::MIN`/`i32::MAX` clamping, hand-built struct
  re-clamp) extending the existing two-skill tests; quantity
  multiplies the reduced per-unit need (3 × 2889 → 20.25 CPU);
  over-budget judged on reduced used (16 × 2889: base 144.0
  over Rifter 130.0 becomes 108.0 under it at Weapon Upgrades
  5 with CPU Management 0; 20 × 2889 at 135.0 reduced stays
  over, remaining exactly −5.0).
- Excluded-before-reduction: 1236 (no needs) is excluded in
  both dimensions and never unreduced, at any levels; 33981
  (power-only) counts power at base (its required skill 3455
  matches nothing) and excludes CPU.
- Unreduced rule (synthetic `from_json` fixtures — the shipped
  catalogue makes the count unreachable): a module row without
  the new keys at Weapon Upgrades 5 counts at full need with
  `unreduced_modules` = its quantity in CPU and (at Advanced 5)
  power; the same fixture with all relevant levels 0 counts 0
  unreduced; a row with `requiredSkillIds` present but
  `groupId` absent is unreduced in CPU only; `Some([])` is
  proven (0 unreduced, full need); a stacked quantity-3
  unreduced row counts 3.
- Product rule (synthetic, labelled; zero shipped rows):
  a module requiring both 3300 and 3319 at Weapon Upgrades 5
  takes ×0.75 twice (100.0 → 56.25); a module requiring both
  3300 and 3424 takes Weapon and Energy Grid factors (100.0 →
  75.0 under either alone, 56.25 under both at 5).

**UI wording and demo pins (`src/ui/fittings.rs`, Builder B)**,
string-exact:

- The base-state pins and the existing applied output pins pass
  with numbers unmodified — the byte-identical-base gate and
  the level-0-identity gate. The two pins that name the old
  applied disclosure are updated to the section 8 disclosure
  verbatim; no surviving string may claim need reductions are
  not applied in the applied block.
- Reduction-line helper at level 5 (`-25%`, Advanced `-10%`),
  level 1 (`-5%`, Advanced `-2%`), and level 0 (no-reduction
  template), all five names resolved through the real bundled
  SDE, never raw IDs; Advanced lines pin the ×2 percent (a
  ×5-for-everything mutant fails).
- Before-reductions lines on the sample fit at both weapon
  skills level 5: `CPU: 107.3 tf of … used …` (107.25 renders
  `107.3`, half away from zero) beside `CPU need before skill
  reductions: 114.0 tf.`, and `Power grid need before skill
  reductions: 31.0 MW.` beside the 29.8 MW used figure.
- Unreduced lines singular and plural from a synthetic-catalogue
  render fixture; excluded lines coexisting with unreduced
  lines in one render (different modules, both disclosed).
- Demo story: levels taken from the real demo skillqueue
  through `resource_skill_levels` (not hand-typed), all three
  demo fits and the sample import under both importers keep
  today's used/output lines exactly, gain before-reductions
  lines equal to the used figures, and gain the five level-0
  reduction lines — including Aria (Gunnery trained 4) reducing
  nothing.

**Gates at every commit** (repo standard, this design commit
included): `cargo fmt --check`, `cargo clippy --all-targets --
-D warnings`, `cargo test`, `cargo build`. Existing fitting,
state, skills, import, export, and demo tests pass except the
mechanical literal extensions and disclosure re-pins this
design explicitly locks.

## 10. Integrator list (locked)

The integrator (not the builders) makes these changes after
both builders land:

- **README** — the same three sites the output-bonus slice
  touched (re-verified during design): (1) the Fittings bullet
  (line 22): the resources sentence gains module needs reduced
  by the five named skills at the owning character's trained
  levels when skill data is loaded, base figures still shown,
  with implants and module/rig/subsystem/ship bonuses and
  reductions still not applied; (2) the Roadmap Fitting bullet
  (line 31) parenthetical gains the need-reduction application;
  "ship fitting simulator with fitting statistics" stays not
  implemented; (3) the Status paragraph (line 37) updates the
  same way; "the fitting simulator is not present yet" stays
  true. Nowhere may the README attach "simulator" or
  "statistics" to these numbers.
- **Engineering journal** — dated entries in the same change
  set (repo rule): a `LEARNINGS.md` entry with Evidence
  (file:line), Mechanism, and a one-line generalizable rule for
  (a) shipping behavior beyond the reference app only where a
  committed data file carries the full modifier triple *and* an
  inspected generic-machinery body plus one exercised oracle
  define the formula (Flutter never applied these skills; the
  chain is what ported), and (b) present-empty vs absent filter
  data (`Some([])` vs `None`) as the precondition for any
  counted-but-unprovable disclosure. Plus a short
  `DECISIONS.md` entry recording the locked-entries-table-over-
  general-pipeline choice with its revisit condition (a slice
  that needs a second modifier family reopens it).
- Pin the regenerated catalogue's exact byte count and sha256
  in the merge report; confirm the slice diff contains no ESI,
  scope, persistence, network, state, or demo-asset changes,
  and no `dogma.json` / `effect_modifiers.json` reads; run a
  demo-mode visual pass over the section 8 demo story.

## 11. Exclusions (locked)

Out of this slice, by name: effect 672 and the 132/211/246
item-domain chain as table entries (section 2.3); the three
unpublished Advanced siblings (11204/11206/11208); implants;
module, rig, subsystem, and ship bonuses or reductions to
outputs or needs of any kind (including Reactor Control Unit /
Co-Processor output effects and ship trait bonuses); the
general dogma modifier pipeline, `dgmExpressions`, and any
runtime use of `dogma.json` or `effect_modifiers.json`;
stacking penalties; calibration interaction (upgrade load is
never reduced here); the six other Flutter `_skillModifiers`
ship attributes; DPS, volley, tank/EHP, capacitor, speed,
targeting, and every other fitting statistic, including any
skill application to those readouts; percentages or bars beyond
the locked per-skill line percents; per-module resource
itemization; the fitting editor and any fitting mutation; ESI
calls, scopes, stored data, state changes, and demo fixture
changes; owner-stamping `SkillsData`; emitting filter keys on
rows outside the section 4 population; discovering reductions
from catalogue data at runtime. Anything on this list appearing
in a builder commit is a design breach, not a bonus.

## 12. Ownership (locked)

Small atomic commits, `type(scope): description`, no
attribution, with the locked subjects below. Nobody pushes or
merges; the parent does that. Every commit compiles and passes
the section 9 gates on its own.

- **Design** (this commit): `docs/fitting-need-reductions-design.md`
  only. Subject: `docs(fitting): design skill need reductions`.
- **Builder A — catalogue.** (A1) `scripts/sde/generate_fitting_types_sde.py`
  + the regenerated `assets/sde/fitting_types.json`, with the
  section 4 oracles, counts, budget, and proof obligations.
  Subject: `feat(sde): emit module group and required skills`.
  (A2) `src/names/fitting_types.rs`: the two loader fields and
  the section 5 invariants. Subject:
  `feat(catalogue): load module group and required skills`.
  Builder A changes no `src/fitting/` or `src/ui/` files.
- **Builder B — pure computation and render.** (B1)
  `src/fitting/resources.rs` + re-exports in
  `src/fitting/mod.rs`: the five constants, extended levels,
  the entry table, budget fields, the excluded/unreduced
  contract, header rewrite, pure tests. Subject:
  `feat(fitting): apply skill need reductions to resources`.
  (B2) `src/ui/fittings.rs`: before-reduction lines, the five
  reduction lines, unreduced lines, replaced applied
  disclosure, wording and demo pins. Subject:
  `feat(fittings): show skill need reductions`. Builder B
  changes no catalogue, generator, state, or demo files.
- **Integrator.** README + engineering journal (section 10),
  any cross-builder seam fix reconciled back to this document
  (not to whichever builder wrote first), final gates, the demo
  visual pass, and the catalogue byte pin. Subject:
  `docs(fitting): document skill need reductions`.

Sequencing: A1, then A2 (its invariants need the regenerated
asset; A1 alone is safe because old code ignores the new keys);
B1 needs A2's loader fields; B2 needs B1; integrator last.
There is no safe A/B parallelism on the code path, and none is
needed: each commit is small and independently gated.

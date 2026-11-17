# Fitting damage per second (base values) — design

Status: locked for implementation. Base: `develop` at `82617be`, clean.
Slice branch: `feat/rust-fitting-dps`. Discovery: two read-only reports
(Flutter damage-per-second (DPS) engine at `ed698d3`; Rust data seams),
re-verified against the bodies named below during design. Every attribute
id, formula, and number in this document traces to an inspected body:
`dogmaAttributes.jsonl` / `dogmaEffects.jsonl` / `dogmaUnits.jsonl` in the
pinned SDE zip (`scripts/sde/eve-online-static-data-3503375-jsonl.zip`),
the committed Fuzzwork caches `scripts/sde/dgmTypeAttributes.csv.bz2` and
`scripts/sde/dgmTypeEffects.csv.bz2` read directly, the committed
catalogue `assets/sde/fitting_types.json`, Flutter at `ed698d3` via
`git show` (`dogma_engine.dart`, `dogma_attributes.dart`,
`dogma_engine_test.dart` oracles quoted through discovery and spot-read
during design), and current Rust (`src/esi/models.rs`,
`src/fitting/eft.rs`, `src/fitting/dna.rs`, `src/fitting/bay_usage.rs`,
`src/fitting/write_map.rs`, `src/names/fitting_types.rs`,
`src/ui/fittings.rs`, `src/ui/widgets.rs`,
`scripts/sde/generate_fitting_types_sde.py`,
`assets/demo/fittings.json`). No damage formula in this document is
recalled; each is quoted from the Flutter engine body named beside it.

## 1. Goal, per-family verdicts, and value ranking

Goal: in both fitting details (saved fitting detail and imported fitting
detail), show base damage per second per weapon family, for exactly the
families discovery grounds end to end on that surface, with every number
labelled with what is included and what is not. The reconciled verdicts
(discovery report P1 called all four families formula-grounded; report
P2 called turrets, launchers, and fighters ungrounded on the saved
surface; the bodies read during design settle both claims per family and
per surface):

| Family | Saved (ESI) detail | DNA import detail | EFT import detail | Settling evidence |
|---|---|---|---|---|
| Turrets | No DPS line; unloaded count | No DPS line; unloaded count | DPS from listed loaded charges only | Charge pairing exists only in `ImportedItem.charge`; saved items carry charges as unlinked cargo (section 2.3) |
| Launchers | No DPS line; unloaded count | No DPS line; unloaded count | DPS from listed loaded charges only | Same as turrets; missile damage lives on the charge |
| Drones | DPS line | DPS line (structurally 0.0: DNA imports no drones) | DPS line | Damage, cycle, and multiplier live on the drone type; no charge is involved (section 2.2) |
| Fighters | DPS line where the ship has fighter data | DPS line rule as saved (structurally no fighters) | DPS line | Damage lives on the fighter type; ability effects are in the committed effects cache (section 2.5) |

So this slice ships drone and fighter DPS on both details, and turret and
launcher DPS only on the imported-EFT detail. No family is approximated:
where a surface carries no charge pairing, turret and launcher DPS is
absent (never zero-filled, never defaulted to an assumed charge), and the
fitted weapons that could not be counted are disclosed as a count
(section 6).

Value ranking, in order, when any two rules below appear to conflict:

1. **Never show a DPS number from an assumed charge, an assumed active
   count beyond the locked cap rules, or a source other than the locked
   one for that value.** A missing line with a disclosed count always
   beats a plausible number.
2. **Correctness.** Formulas are Flutter's, quoted in section 2.2, at
   base values only; unknown damage data is counted and disclosed, never
   silently zeroed.
3. **Reuse.** Mirror the existing pure-layer, generator, and rendering
   shapes (`bay_usage.rs`, the additive catalogue extensions, the
   `format_fitting_amount` formatter) wherever they fit without
   violating 1 or 2. Where the shipped Rust precedent and Flutter
   disagree (unknown bandwidth cost, absent capacity), the shipped Rust
   precedent wins and the divergence is named (section 2.6).

## 2. Sources and grounding (inspected bodies only)

### 2.1 Dogma attribute, unit, and effect truth

From `dogmaAttributes.jsonl` in the pinned zip (`_key` is the id;
`defaultValue` and unit id read during design) and
`dogmaEffects.jsonl` (effect names):

| Id | Dogma name | Unit | Default | Role in this slice |
|---|---|---|---|---|
| 51 | `speed` | 101 Milliseconds | 0.0 | Weapon and drone cycle time in milliseconds. Flutter calls this `rateOfFire`; the catalogue key follows the SDE name (section 3) |
| 64 | `damageMultiplier` | 104 x | 1.0 | Turret and drone damage modifier; its presence also classifies a weapon as a turret (section 2.4) |
| 114 | `emDamage` | 113 damage | 0.0 | Charge and drone damage component |
| 116 | `explosiveDamage` | 113 damage | 0.0 | Charge and drone damage component |
| 117 | `kineticDamage` | 113 damage | 0.0 | Charge and drone damage component |
| 118 | `thermalDamage` | 113 damage | 0.0 | Charge and drone damage component |
| 283 | `droneCapacity` | 9 `m3` | 0.0 | Already emitted; not read by DPS (named to avoid confusion with bandwidth) |
| 1271 | `droneBandwidth` | 128 `Mbit/sec` | 0.0 | Ship drone bandwidth; already emitted as `droneBandwidth` |
| 1272 | `droneBandwidthUsed` | 128 `Mbit/sec` | 0.0 | Per-drone bandwidth cost; already emitted under this name |
| 2055 | `fighterCapacity` | 9 `m3` | 0.0 | Ship fighter bay capacity; already emitted; gates the fighter family (section 4), never caps DPS |
| 212 | `missileDamageMultiplier` | 104 x | 1.0 | **Never emitted or read.** Character-level (zero rows on category-7 types in the cache); Flutter's ballistics special case is a bonus path, and bonuses are out of scope |
| 2212 | `fighterSquadronIsLight` | — | 0.0 | Fighter class flag |
| 2213 | `fighterSquadronIsSupport` | — | 0.0 | Fighter class flag |
| 2214 | `fighterSquadronIsHeavy` | — | 0.0 | Fighter class flag |
| 2215 | `fighterSquadronMaxSize` | — | 0.0 | Fighters per squadron |
| 2216 | `fighterTubes` | — | 0.0 | Ship launch tubes (total active squadrons) |
| 2217 | `fighterLightSlots` | — | 0.0 | Ship light squadron cap |
| 2218 | `fighterSupportSlots` | — | 0.0 | Ship support squadron cap |
| 2219 | `fighterHeavySlots` | — | 0.0 | Ship heavy squadron cap |
| 2226 | `fighterAbilityAttackMissileDamageMultiplier` | 104 x | 0.0 | Fighter attack-ability damage modifier (Flutter overrides an absent value to 1.0, section 2.2) |
| 2227–2230 | `fighterAbilityAttackMissileDamageEM/Therm/Kin/Exp` | 113 | 0.0 | Fighter attack-ability damage per fighter |
| 2233 | `fighterAbilityAttackMissileDuration` | 101 Milliseconds | 0.0 | Fighter attack-ability cycle time |
| 2130 | `fighterAbilityMissilesDamageMultiplier` | 104 x | 0.0 | Fighter missile-ability damage modifier |
| 2131–2134 | `fighterAbilityMissilesDamageEM/Therm/Kin/Exp` | 113 | 0.0 | Fighter missile-ability damage per fighter |
| 2182 | `fighterAbilityMissilesDuration` | 101 Milliseconds | 0.0 | Fighter missile-ability cycle time |

Effects, from `dogmaEffects.jsonl` names and Flutter's
`_fighterAbilityByEffect` map (`dogma_engine.dart` at `ed698d3`): 6465
`fighterAbilityAttackM` is the fighter attack ability, 6431
`fighterAbilityMissiles` is the missile ability, 6485
`fighterAbilityLaunchBomb` and 6554 `fighterAbilityKamikaze` are named
only (never DPS, section 10). Decoys that must never be emitted or read
for DPS: 3 `damage` (structure damage), 39 `damageHP` (hitpoints), 73
`duration` (non-weapon module cycle; smartbombs cycle on it, section
2.6), 54 `maxRange` and 158 `falloff` (Flutter reads them only for a
volley-weighted range display, which this slice does not show, section
10), 160 `trackingSpeed` (defined in Flutter, never used in DPS), 128
`chargeSize` and 137 `launcherGroup` (compatibility data Flutter never
checks, section 2.3), and the fighter `explosion*` application
attributes (no application math exists in the DPS bodies).

Per-type values come only from the committed caches the generator
already reads — never from the zip's `typeDogma.jsonl` and never from
`assets/sde/dogma.json` (the Flutter-served dogma file, which no Rust
body reads). Where the cache and the zip disagree, the cache is the
authority: the zip's `typeDogma.jsonl` reads 23059 Firbolg I as
squadron size 6 with attack thermal 112.5, while the cache reads size
9.0 with thermal 75.0 (both read during design). The per-full-squadron
volley is 675 either way (6 × 112.5 = 9 × 75.0), but partial squadrons
differ; this slice ships cache values, exactly as the bay slice shipped
the cache's 70000.0 fighter capacity for 23911 Thanatos against
Flutter's 75000, and names the drift rather than reconciling it.

### 2.2 Formulas, quoted from the Flutter engine at `ed698d3`

The single engine is `DogmaEngine.calculateDetailedStats` in
`lib/features/fitting/domain/dogma_engine.dart`. Flutter computes
effective values (`moduleAttr` / `chargeAttr` apply skill, ship, and
module bonuses); this slice reads the same attributes at base values
only, the shipped Rust pattern of `resources.rs` and `bay_usage.rs`.
What moves over is the arithmetic and the guard chain, nothing else.

**Turrets and launchers** (engine comment block `// 5. Offense`, read
verbatim during design): "Turrets multiply charge damage by their
damage modifier (64); launchers contribute the charge damage alone
(pyfa parity). Unloaded weapons contribute nothing, exactly like an
unloaded gun in game." Guard chain per fitted module: offline → skip
(no module state exists in either Rust shape, so every fitted module
takes the online path and the disclosure says so); type missing →
skip; no cycle attribute 51 → skip; cycle ≤ 0 → skip; no loaded
charge → skip; charge damage sum over attributes 114, 116, 117, 118
≤ 0 → skip. Then, with Σ the sum of the four charge damage components:

- turret (module carries attribute 64): volley = Σ × module attribute
  64; DPS = volley / (module attribute 51 / 1000)
- launcher (module has no attribute 64): DPS = Σ / (module attribute
  51 / 1000)

Division by (milliseconds / 1000) is the only cycle handling. There is
no reload time, no missile flight time, no range, falloff, tracking,
or damage-application term anywhere in the body; attributes 54 and 158
feed a separate volley-weighted display average only. Flutter sums
turret and launcher output into one displayed DPS (its `dpsGuns` /
`dpsMissiles` split is never rendered in `stats_panel.dart`); this
slice deliberately renders the split instead, because the two families
have different charge sources and the split is already computed — a
named divergence from the Flutter panel, not from the engine.

**Drones** (engine `// 5b. Drones`, read verbatim during design): "like
pyfa, every fitted drone counts as active unless the fit records
drones in space, and the ship's drone bandwidth caps how many can fly
at once. Damage follows the turret shape: damage components times the
drone's damage modifier, per cycle." Per drone group, in fit order:
`needed` = attribute 1272; `fitted` = in-space count when recorded else
quantity (Rust records no in-space count, so quantity); `active` =
`min(fitted, floor(bandwidthLeft / needed))` when `needed > 0`, else
`fitted`; bandwidth is consumed by the active count **before** the
cycle check; then cycle = the drone type's own attribute 51 (no ammo),
≤ 0 or absent → no DPS from that group; drone volley = Σ(114, 116, 117,
118) on the drone type, multiplied by attribute 64 when the type
carries it; DPS += active × volley / (cycle / 1000). A present drone
type with no cycle or no damage components therefore deals a known
0 — the SDE defaults for 51 and the four components are all 0.0
(section 2.1), so absence on a catalogued type is data, not a gap.

**Fighters** (engine fighter block, read verbatim during design): hull
caps are the integer parts of ship attributes 2216 (tubes), 2217
(light), 2218 (support), 2219 (heavy), with a missing cap attribute
read as 0 (Flutter `hullCap`; the SDE default for all four is also
0.0). Per fighter group, in fit order: type missing or squadron max
size 2215 missing or ≤ 0 → no DPS; launched = in-space capped at
quantity when recorded, else quantity (Rust: quantity); squadrons are
filled sequentially at sizes `min(maxSize, remaining)`; a group is
launchable when any of 2212/2213/2214 is > 0, and its class is light
if 2212 > 0, else support if 2213 > 0, else heavy. The active ability
is attack (effect 6465) when present, else missiles (effect 6431),
else none. Per squadron, in order: not launchable, no tube left, or no
class slot left → squadron inactive; otherwise one tube and one class
slot are consumed (even when the ability is none). For an active
squadron with an ability: components = Σ of the ability's four damage
attributes (attack 2227–2230, missiles 2131–2134) on the fighter type;
modifier = the ability's multiplier attribute (2226 or 2130) **or 1.0
when that attribute is absent** (Flutter's explicit override; the SDE
default is 0.0 and must not be used here); duration = the ability's
duration attribute (2233 or 2182) in milliseconds, absent or ≤ 0 → no
DPS from that squadron; volley = components × modifier × squadron
size; DPS += volley / (duration / 1000). Fighter bay capacity (2055)
never truncates DPS — Flutter tests pin over-capacity fittings dealing
full tube-capped damage. Bomb (6485), kamikaze (6554), and utility
abilities never contribute DPS in the engine body.

Flutter test bodies at `ed698d3` pin this arithmetic with literal
expectations the Rust tests cross-check at base values (section 8):
the untrained turret fixture (charge kinetic 100, multiplier 2.0,
cycle 4000 ms) yields volley 200 and 50 DPS; the drone fixture
(explosive 10, multiplier 2.0, cycle 4000 ms, cost 5.0, ship
bandwidth 25) yields 25 DPS from 5 active drones, and 10 DPS at
bandwidth 12 (floor(12/5) = 2 active); the fighter fixture (components
207, size 6, duration 5000 ms) yields 6 × 207 / 5 = 248.4 DPS.
Fixtures in those tests that carry skill or module bonuses (a damage
amplifier's ×1.205, a ship rate-of-fire trait) are effective-path
evidence only and are never used as base expectations. Two real-type
cross-checks survive in the engineering journal from the Flutter era
and match the cache arithmetic in section 7 exactly: a 125mm Gatling
AutoCannon I with Proton S at 3.4 DPS, and five Warrior II at 47.0
DPS only after a damage amplifier's ×1.205 (base 39.0 × 1.205 = 47.0;
Warriors on a zero-bandwidth Rifter produce 0 drone DPS).

### 2.3 Charges per input shape — where a pairing exists at all

- **Saved (ESI) fittings** (`src/esi/models.rs`, `FittingItem` is
  exactly `{flag, quantity, type_id}`): no charge field exists. A
  charge type in a saved fitting is an unlinked `Cargo` item. There is
  no module-to-charge pairing anywhere in the saved shape, and
  `build_save_request` (`src/fitting/write_map.rs`) preserves that:
  Mimir-saved fittings never create one either. No honest turret or
  launcher DPS can be derived, and assigning a cargo charge to a
  weapon would invent the default charge this slice forbids.
- **EFT imports** (`src/fitting/eft.rs`): a `Module, Charge` line
  stores `ImportedCharge{type_id, name}` on `ImportedItem.charge`
  after the charge name resolves to a category-8 type. This is the
  only pairing that survives anywhere. The imported detail holds the
  `ImportedFitting` itself at render time (in
  `fittings_import_panel`) next to its synthesis, so the DPS block can
  read the pairing there without changing any shape.
  `to_character_fitting()` drops charges by design and keeps doing
  so; nothing is saved, exported, or written back from the pairing.
- **DNA imports** (`src/fitting/dna.rs`): segments carry modules only;
  `charges_noted` is always 0. DNA detail therefore behaves exactly
  like the saved surface for weapons.

No body on any surface checks charge-to-weapon compatibility
(`chargeSize`, `launcherGroup`), Flutter's engine included: an EFT
text pairing any category-8 charge with any weapon is computed as
listed. That is parity and is stated in the locked disclosure
(section 6).

**Charge rule, locked for every shape:** a weapon deals DPS only from
a charge paired with it in the imported EFT text. A weapon with no
pairing contributes nothing and is counted in `unloaded_weapons`
(section 4). No charge is ever assumed, inferred from cargo, or
defaulted.

### 2.4 Weapon classification

Flutter classifies inside the offense loop only: a fitted module with
a usable cycle attribute 51 and a damaging loaded charge is a turret
when its type carries attribute 64, otherwise a launcher. The
catalogue's existing `turretFitted` / `launcherFitted` booleans
(effects 42 and 40, used for hardpoint counting) must not classify
DPS: over the committed caches, cycle-plus-multiplier types in high
slots number 636 and match `turretFitted`, but 22 `turretFitted` types
are mining lasers with no cycle and no multiplier (the cycle gate
excludes them), and 18 cycle-carrying launchers (probe, bomb,
defender, civilian, and breacher-pod launchers among them) carry
neither boolean. The locked classification is therefore the engine's:
attribute 51 present and usable marks a weapon candidate; attribute
64 present marks the turret family, absent marks the launcher family.
Slot, category, and hardpoint markers are never consulted for the
family split. Eligibility for the candidate pass is a separate bound,
and it does consult category: only categories 7 and 32 (the parser's
module and subsystem categories, `classify_module` in
`src/fitting/eft.rs`) can be candidates, because drones carry
attributes 51 and 64 as well and a saved or synthesized fitting can
file a drone type under a slot flag — the demo fixture does exactly
that (28270, a category-18 drone under `SubSystemSlot0`, section 7).
Flutter never needed this bound because its model keeps modules and
drones in separate lists; the flag-driven Rust shapes do. In the
shipped data every category-7-or-32 row with attribute 51 is
category 7, so the bound excludes junk filings and nothing else.

### 2.5 Fighter ability grounding (resolves the discovery conflict)

Discovery report P2 excluded fighters for want of an
effect-to-ability seam in Rust today. The bodies read during design
supply that seam: the committed `dgmTypeEffects.csv.bz2` — the same
file the generator already reads for `slotEffects` and for the
`turretFitted` / `launcherFitted` boolean markers (effects 42 and
40) — carries effect 6465 on 54 category-87 catalogue types and
effect 6431 on 56, with 36 carrying both (attack is then preferred,
per section 2.2) and 20 carrying neither (electronic-warfare and
standup fighters, honestly no DPS ability). Every category-87 type
with an attack effect also carries duration 2233, and every
missiles-only type carries 2182 (scripted during design, zero gaps).
Emitting two sparse boolean markers for 6465 and 6431 is the identical
generator pattern as the shipped hardpoint markers, so fighter DPS is
grounded end to end: formula (section 2.2), per-type attributes
(cache), ability choice (cache), squadron and tube caps (cache), and
fitted quantities (`FighterBay` rows on both surfaces).

### 2.6 Deliberate divergences from Flutter (do not "fix" back)

1. **Base values only.** Flutter showed effective DPS. No skill,
   implant, ship, module, rig, or subsystem bonus ever applies —
   including the damage-amplifier and ballistics paths Flutter
   special-cases. The disclosure names the exclusions (section 6).
2. **Drone active count is bandwidth-capped, like Flutter, not the
   fitted count.** The shipped bay block deliberately shows an
   uncapped fitted *bandwidth sum* so over-bandwidth is visible as
   used-versus-capacity; that precedent governs a usage sum, not a
   damage rate. Counting every fitted drone for DPS would credit
   damage from drones that cannot be in space together (a Tristan
   with eight Warrior II in the bay would show eight drones of DPS
   against a 25 Mbit/sec bandwidth that flies five). The locked rule
   is Flutter's: quantity in `DroneBay` order, capped group by group
   at `floor(bandwidthLeft / needed)`. Drones past the cap are
   known-not-flying spares: neither DPS nor excluded items.
3. **Unknown data is counted and disclosed**, per shipped Rust
   precedent, where Flutter silently skipped missing types and read a
   missing bandwidth cost as 0. A drone or fighter type absent from
   the catalogue counts as excluded damage data. A catalogued drone
   with usable cycle and positive volley but no usable bandwidth cost
   counts its fitted quantity as excluded (the bay slice locked the
   same attribute absence as a disclosed unknown for the mutated
   drones 60478–60481; in the shipped data those four carry no cycle
   or damage attributes at all, so this branch is fixture-only for
   DPS — a catalogued type with no cycle or no damage is instead a
   known zero by SDE default, section 2.2).
4. **Per-family lines, no total** (section 5). Flutter displayed one
   summed DPS. A summed total would be dishonest on every surface
   where any family's damage is unknown, and "all families known" is
   not decidable for absent families without inventing meaning for an
   absent bandwidth or tube row (2863 Primae has no drone attribute
   rows at all; a Rifter can carry a `FighterBay` blueprint). This
   slice renders per-family lines only and says so in the disclosure.
5. **Present-zero families render.** Flutter hid zero DPS rows and
   the whole offense section at zero. Shipped Rust blocks render
   present data including exact zeros (a Rifter's 0.0 drone
   bandwidth), and the heading renders in every state; section 5
   locks which zero lines appear.
6. **Fighter group usability is checked before tube allocation where
   counting requires it.** Flutter consumes a tube and class slot for
   a launchable squadron and only then discovers a missing duration.
   Excluded counting in item units (the shipped precedent) cannot be
   expressed after consumption without double-counting fighters, so a
   group whose chosen ability has no usable duration counts its
   quantity as excluded and consumes no tube. In the shipped data
   this case does not occur (section 2.5), so the divergence is
   fixture-only; the launchable-but-no-ability case keeps Flutter's
   order exactly (tube consumed, zero DPS).
7. **Smartbombs, mining lasers, and other slot modules without cycle
   attribute 51 deal no DPS** — not a divergence from the engine (its
   cycle gate does the same) but locked here because the caches carry
   smartbomb damage on the module itself: damage components are
   emitted only on charges and drones (section 3), so no later reader
   can mistake module-carried damage for a charge.

## 3. Catalogue extension

Generator-driven and additive, in
`scripts/sde/generate_fitting_types_sde.py`, cloning the resource,
bay, and navigation emission patterns (sorted by `typeId`, compact
separators, fail-loud with exit 1 and nothing written on duplicate,
unparseable, non-finite, or negative values). Sources are only the
committed caches the generator already reads. New attribute keys use
dogma names verbatim, so attribute 51 is emitted as `speed`, never as
Flutter's `rateOfFire`; no key is emitted under two names.

### 3.1 New keys, emission rules, and expected counts

Key order within a row is locked: existing keys keep their order; new
keys append after the navigation/mass block in the order below.
Counts were scripted during design over the cache joined to the
committed catalogue (25,818 rows) and are stop-and-report values in
the generator summary, in the `NAV_TARGETING_EXPECTED_COUNTS` shape.

| Catalogue key | Rust field (`FittingType`) | Source | Emitted on | Count |
|---|---|---|---|---|
| `speed` | `speed` | dgm 51 | Categories 7 and 18, sparse | 873 (797 + 76) |
| `damageMultiplier` | `damage_multiplier` | dgm 64 | Categories 7 and 18, sparse | 837 (748 + 89) |
| `emDamage` | `em_damage` | dgm 114 | Categories 8 and 18, sparse | 897 |
| `explosiveDamage` | `explosive_damage` | dgm 116 | Categories 8 and 18, sparse | 897 |
| `kineticDamage` | `kinetic_damage` | dgm 117 | Categories 8 and 18, sparse | 897 |
| `thermalDamage` | `thermal_damage` | dgm 118 | Categories 8 and 18, sparse | 897 (see the negative-row rule below; the design-time scripted count was 898) |
| `fighterSquadronMaxSize` | `fighter_squadron_max_size` | dgm 2215 | Category 87, sparse | 94 |
| `fighterSquadronIsLight` | `fighter_squadron_is_light` | dgm 2212 | Category 87, sparse | 24 |
| `fighterSquadronIsSupport` | `fighter_squadron_is_support` | dgm 2213 | Category 87, sparse | 12 |
| `fighterSquadronIsHeavy` | `fighter_squadron_is_heavy` | dgm 2214 | Category 87, sparse | 17 |
| `fighterAbilityAttackMissileDamageMultiplier` | `fighter_attack_damage_multiplier` | dgm 2226 | Category 87, sparse | 62 |
| `fighterAbilityAttackMissileDamageEM` | `fighter_attack_damage_em` | dgm 2227 | Category 87, sparse | 62 |
| `fighterAbilityAttackMissileDamageTherm` | `fighter_attack_damage_therm` | dgm 2228 | Category 87, sparse | 62 |
| `fighterAbilityAttackMissileDamageKin` | `fighter_attack_damage_kin` | dgm 2229 | Category 87, sparse | 62 |
| `fighterAbilityAttackMissileDamageExp` | `fighter_attack_damage_exp` | dgm 2230 | Category 87, sparse | 62 |
| `fighterAbilityAttackMissileDuration` | `fighter_attack_duration` | dgm 2233 | Category 87, sparse | 62 |
| `fighterAbilityMissilesDamageMultiplier` | `fighter_missiles_damage_multiplier` | dgm 2130 | Category 87, sparse | 65 |
| `fighterAbilityMissilesDamageEM` | `fighter_missiles_damage_em` | dgm 2131 | Category 87, sparse | 65 |
| `fighterAbilityMissilesDamageTherm` | `fighter_missiles_damage_therm` | dgm 2132 | Category 87, sparse | 65 |
| `fighterAbilityMissilesDamageKin` | `fighter_missiles_damage_kin` | dgm 2133 | Category 87, sparse | 65 |
| `fighterAbilityMissilesDamageExp` | `fighter_missiles_damage_exp` | dgm 2134 | Category 87, sparse | 65 |
| `fighterAbilityMissilesDuration` | `fighter_missiles_duration` | dgm 2182 | Category 87, sparse | 65 |
| `fighterTubes` | `fighter_tubes` | dgm 2216 | Category 6, sparse | 12 |
| `fighterLightSlots` | `fighter_light_slots` | dgm 2217 | Category 6, sparse | 12 |
| `fighterSupportSlots` | `fighter_support_slots` | dgm 2218 | Category 6, sparse | 10 |
| `fighterHeavySlots` | `fighter_heavy_slots` | dgm 2219 | Category 6, sparse | 7 |
| `fighterAbilityAttackM` | `fighter_ability_attack: bool` | effect 6465 | Category 87, sparse `true` | 54 |
| `fighterAbilityMissiles` | `fighter_ability_missiles: bool` | effect 6431 | Category 87, sparse `true` | 56 |

Rules:

- Sparse means a key is present exactly when a source row exists,
  including a present `0.0` (charge and combat-drone damage rows carry
  explicit zeros, e.g. 180 Proton S `explosiveDamage` 0.0). Absence is
  never rewritten as an emitted zero.
- The category restrictions are part of the lock, not an optimization:
  categories 23, 66, and 20 also carry rows for one or both of
  attributes 51 and 64 in the cache, category 7 carries
  damage components on smartbomb modules, and category 65 structures
  carry attribute 2216. None of those rows is emitted. The boolean markers use the
  SDE effect names verbatim (`fighterAbilityAttackM` is truncated in
  the SDE itself), exactly as `turretFitted` / `launcherFitted` use
  effect names 42 / 40, and are emitted from `dgmTypeEffects` only on
  category-87 rows.
- Negative source rows are never emitted (integrator amendment,
  Builder A deviation at `df1b584`): the committed cache carries six
  negative damage-per-second source rows, including published
  category-8 type 53343 (Yoiul Festival Snowball) with a sole
  `thermalDamage` row of -10.0, which the finite-and-non-negative
  invariant in section 3.3 cannot admit and a global fail-loud
  would let block the whole catalogue. The generator therefore
  skips negative rows at load and counts them in its summary;
  absence is data, negative damage is not. This is why the shipped
  `thermalDamage` count is 897, not the design-time 898.
- `speed` values are milliseconds. Nothing converts them at load or
  in the catalogue; the pure layer divides by 1000 in the formula,
  mirroring the engine's `(cycleMs / 1000)` and avoiding the
  seconds-versus-milliseconds trap the Flutter tests pin.

Simulated size (scripted `,"key":value` append against the committed
catalogue, 3,341,334 bytes): the 26 numeric keys above add roughly
141,900 bytes and the two boolean markers roughly 3,400 bytes, for
approximately 3,486,600 bytes (+4.4%). **Size budget: the regenerated
catalogue must land within 3,550,000 bytes**; Builder A reports the
actual byte count in the commit. Over budget is a stop-and-report
event, not a reason to quietly subset keys.

### 3.2 Generator oracles

A new `DPS_ORACLES` list in the `BAY_ORACLES` shape — `(typeId, key,
expected)` with `None` an absence oracle. Every value below was read
from `dgmTypeAttributes.csv.bz2` / `dgmTypeEffects.csv.bz2` during
design:

Present-value oracles:

- (484 125mm Gatling AutoCannon I, `speed`, 3000.0),
  (484, `damageMultiplier`, 2.0625)
- (2889 200mm AutoCannon II, `speed`, 3750.0),
  (2889, `damageMultiplier`, 3.465)
- (2404 Light Missile Launcher II, `speed`, 12800.0)
- (180 Proton S, `emDamage`, 3.0), (180, `kineticDamage`, 2.0),
  (180, `explosiveDamage`, 0.0), (180, `thermalDamage`, 0.0)
- (21898 Republic Fleet EMP S, `emDamage`, 10.35),
  (21898, `explosiveDamage`, 2.3), (21898, `kineticDamage`, 1.15),
  (21898, `thermalDamage`, 0.0)
- (210 Scourge Light Missile, `kineticDamage`, 83.0)
- (2488 Warrior II, `speed`, 4000.0),
  (2488, `damageMultiplier`, 1.56), (2488, `explosiveDamage`, 20.0)
- (2456 Hobgoblin II, `damageMultiplier`, 1.92),
  (2456, `thermalDamage`, 20.0)
- (23059 Firbolg I, `fighterSquadronMaxSize`, 9.0),
  (23059, `fighterSquadronIsLight`, 1.0),
  (23059, `fighterAbilityAttackMissileDamageMultiplier`, 1.0),
  (23059, `fighterAbilityAttackMissileDamageTherm`, 75.0),
  (23059, `fighterAbilityAttackMissileDuration`, 5000.0),
  (23059, `fighterAbilityMissilesDamageTherm`, 138.0),
  (23059, `fighterAbilityMissilesDuration`, 14000.0),
  (23059, `fighterAbilityAttackM`, true),
  (23059, `fighterAbilityMissiles`, true)
- (40358 Equite I, `fighterSquadronMaxSize`, 12.0),
  (40358, `fighterAbilityMissilesDamageEM`, 38.0),
  (40358, `fighterAbilityMissilesDuration`, 3500.0),
  (40358, `fighterAbilityMissiles`, true)
- (23911 Thanatos, `fighterTubes`, 3.0),
  (23911, `fighterLightSlots`, 3.0),
  (23911, `fighterSupportSlots`, 1.0)

Absence oracles:

- (2404, `damageMultiplier`) — a launcher must never gain attribute 64
- (484, `emDamage`) and (1563 Small EMP Smartbomb I, `emDamage`),
  (1563, `speed`) — module-carried damage is never emitted
- (482 Miner II, `speed`), (482, `damageMultiplier`) — the
  `turretFitted` marker must not leak into DPS data
- (180, `speed`), (180, `damageMultiplier`) — charges carry neither
- (60478, `speed`), (60478, `emDamage`) — mutated drones carry no DPS
  attributes
- (40358, `fighterAbilityAttackM`) — missiles-only stays missiles-only
- (40568 Cenobite II, `fighterAbilityAttackM`),
  (40568, `fighterAbilityMissiles`) — no-ability fighters stay so
- (23911, `fighterHeavySlots`) — absent stays absent (the pure layer
  reads it as a 0 cap per section 2.2, the catalogue never invents it)
- (587 Rifter, `fighterTubes`), (587, `speed`)

### 3.3 Invariants (generator self-validation and loader test)

Both assert, for the shipped catalogue:

- every present DPS value is finite and ≥ 0.0;
- `speed` / `damageMultiplier` appear only on category 7 or 18 rows;
  the four damage components only on category 8 or 18 rows; the
  fighter per-type keys and both boolean markers only on category-87
  rows; the four tube/slot keys only on category-6 rows;
- summary key counts match section 3.1 exactly;
- absence stays distinct from `0.0` (the 180 present-zero and 23911
  absent-heavy oracles pin both sides).

Loader: the 26 new fields are `Option<f64>` with
`#[serde(rename = "…", default)]` and the two markers are `bool` with
`#[serde(default)]`, placed after the existing fields, mirroring the
bay fields and `turret_fitted`. Old fixture JSON without the new keys
must keep parsing. The load log line is unchanged; no logging is
added.

### 3.4 Determinism proofs (Builder A, same commit as the catalogue)

1. Run the generator twice into two outputs; SHA-256 hashes are
   identical.
2. Strip exactly the 28 new keys from the regenerated catalogue; the
   result is byte-identical to the committed pre-slice
   `fitting_types.json`.
3. Generator self-validation (oracles + invariants + counts) passes,
   and the regenerated size is within the section 3.1 budget.

## 4. Pure API

New module `src/fitting/dps.rs`, exported from `src/fitting/mod.rs`,
following the `bay_usage.rs` shape: pure computation, no egui, no
state, no network, no database, and **no logging** (render cadence).
One function serves both details; the imported detail passes the
`ImportedFitting` it already holds so EFT charge pairings (section
2.3) are read where they exist, and the saved detail passes `None`:

```rust
pub fn fitting_dps(
    fitting: &CharacterFitting,
    imported: Option<&ImportedFitting>,
    catalogue: &FittingTypes,
) -> FittingDpsOutcome;

pub enum FittingDpsOutcome {
    Available(FittingDps),
    Unavailable, // no usable ship row, or no family available
}

pub struct FittingDps {
    pub turrets: Option<FamilyDps>,
    pub launchers: Option<FamilyDps>,
    pub drones: Option<FamilyDps>,
    pub fighters: Option<FamilyDps>,
    /// Fitted weapon candidates with no loaded-charge pairing on
    /// this surface (section 2.3), in quantity units.
    pub unloaded_weapons: usize,
}

pub struct FamilyDps {
    pub dps: f64,
    /// Counted-section items with no usable damage data for this
    /// family, in quantity units, never silently zero.
    pub excluded_items: usize,
}
```

Common semantics, locked (all mirror `bay_usage.rs` / `resources.rs`
unless a section above says otherwise): ship resolution requires
`ship_type_id > 0`, a catalogue row, and category 6, else
`Unavailable`; a catalogue value is usable only when present, finite,
and ≥ 0.0 (for cycle and duration values, also > 0.0 where the guard
chain requires it); item rows with `type_id <= 0` are invisible,
quantities clamp with `.max(0)` and quantity 0 contributes and
excludes nothing; excluded counts use saturating addition in quantity
units; computed DPS is an unrounded `f64` — rounding exists only in
the UI formatter (section 6). Damage-component sums read an absent
component as 0.0 on a catalogued type (SDE defaults, section 2.2),
while a present-but-unusable component (fixture catalogues only)
excludes that item. `Unavailable` also results when all four families
are `None` and `unloaded_weapons` is 0, mirroring the bay rule that a
block with no dimension at all is unavailable.

**Weapon pass (turrets and launchers).** The candidate pass runs over
slot-section rows only: for a `CharacterFitting`, flags with the
`LoSlot` / `MedSlot` / `HiSlot` / `RigSlot` / `SubSystemSlot` prefixes
(the `bay_usage` slot predicate, tested by the pure module itself);
for an `ImportedFitting`, `ImportSection` Low / Medium / High / Rig /
Subsystem items. A row whose type is absent from the catalogue is not
counted anywhere in this block (it cannot be classified; the
resources block already discloses catalogue-absent modules). A
catalogued row is a weapon candidate only when its category is 7 or
32 and its `speed` is usable and > 0 (section 2.4). For each
candidate, in input order:

- Surface is saved (`imported` is `None`) or DNA (`imported.format`
  is `Dna`): the candidate has no pairing by construction, so
  `unloaded_weapons` increases by its quantity units. `turrets` and
  `launchers` stay `None`.
- Surface is EFT: `turrets` and `launchers` are `Some` (starting at
  0.0 DPS, 0 excluded). The family is decided first by
  `damage_multiplier.is_some()` on the module row (present → turret,
  absent → launcher; a present-but-unusable multiplier excludes the
  candidate into the turret family's `excluded_items`). `charge` is
  `None` → `unloaded_weapons` increases by quantity units (slot items
  are quantity 1 per the parser's own invariant, but the pure layer
  counts units regardless). `charge` is `Some` but its type is absent
  from the catalogue, or any present component is unusable → that
  family's `excluded_items` increases. Otherwise Σ is the four
  components of the charge type (absent component = 0.0); Σ ≤ 0
  contributes a known 0 (not unloaded, not excluded); Σ > 0 adds
  Σ × multiplier / (`speed` / 1000) for turrets or Σ / (`speed` /
  1000) for launchers.

**Drone pass.** Available (`Some`) only when the ship's
`drone_bandwidth` is usable; an absent bandwidth (2863 Primae) yields
`None` and `DroneBay` rows then accumulate nothing, not even excluded
counts (the bay rule for a `None` dimension). Rows are exact-flag
`DroneBay` rows in `fitting.items` order, on both surfaces. Per row:
type absent from the catalogue → `excluded_items` += units, no
bandwidth consumed. Otherwise compute volley (four components,
absent = 0.0, present-unusable → excluded; × `damage_multiplier` when
present and usable, present-unusable → excluded) and cycle (`speed`,
usable and > 0 required for damage). Then the bandwidth gate, in
Flutter's order: `drone_bandwidth_used` usable → active =
`min(quantity, floor(bandwidth_left / needed))` when needed > 0 else
quantity, and `bandwidth_left -= active × needed` — consumption
happens even when volley or cycle then yields zero DPS; cost absent
or unusable → no consumption, and when volley > 0 with a usable cycle
the row's units count as `excluded_items` (section 2.6 rule 3),
otherwise it is a silent known zero. DPS += active × volley /
(cycle / 1000) when cycle is usable; drones beyond the bandwidth cap
contribute and exclude nothing.

**Fighter pass.** Available (`Some`) only when the ship's
`fighter_capacity` (already emitted) and `fighter_tubes` are both
usable; otherwise `None` and `FighterBay` rows accumulate nothing.
(On shipped data the same 12 category-6 hulls carry both keys.)
Class caps read absent as 0 per section 2.2 (`usable(…).unwrap_or(0.0)`,
then integer part); tubes likewise take the integer part. Rows are
exact-flag `FighterBay` rows in items order. Per row: type absent
from the catalogue → excluded += units. Squadron max size absent,
unusable, or with integer part ≤ 0 → excluded += units (a
non-fighter row filed under `FighterBay` is honestly "no fighter
damage data"). Ability chosen from the boolean markers (attack
preferred). Ability present but its duration absent, unusable, or
≤ 0 → excluded += units, no tube consumed (section 2.6 rule 6). Class
from the flags in light → support → heavy order; no flag usable and
> 0 → launchable is false, a known zero consuming nothing. Otherwise
squadrons fill sequentially; each squadron beyond the remaining
tubes or its class cap is a known inactive spare (no DPS, not
excluded), each active squadron consumes one tube and one class slot
— including a launchable group with no damage ability (tube
consumed, 0 DPS, Flutter order) — and adds components × modifier
(absent modifier = 1.0, present-unusable excludes the group before
allocation, fixture-only) × size / (duration / 1000). Bay capacity
never caps the result.

## 5. Availability and the total rule

- **Per-family independence.** Each family is available or not on its
  own gate (section 4): EFT surface for turrets and launchers, usable
  ship bandwidth for drones, usable fighter capacity plus tubes for
  fighters. One family's absence never suppresses another's line, and
  the DPS outcome never affects, and is never affected by, the
  resources, bay, slot-layout, or ship-stat outcomes.
- **Missing family data versus family DPS exactly 0.0.** A `None`
  family contributes no line — never a zero, a dash, or placeholder
  words. A `Some` family at 0.0 renders a real `0.0` line: drones on
  a present-zero-bandwidth hull, turrets and launchers on an EFT
  import listing no damaging pairings, fighters on a carrier with an
  empty bay.
- **No total is ever shown** (section 2.6 rule 4). The pure layer
  returns no total field. A fitting can display up to four family
  lines side by side; the user adding them does so with the
  disclosure in view, but Mimir never prints a sum that could
  silently omit an uncounted family.
- **Ship-level failure** (unknown or non-ship `ship_type_id`, or
  every family `None` with no unloaded weapons) yields `Unavailable`
  and the block's fixed unavailable sentence; a failed catalogue
  load yields the no-catalogue sentence. The heading renders in every
  state (sibling precedent), including a fitting with no items.

## 6. UI

### 6.1 Placement

One shared function (working name `render_fitting_dps`) in
`src/ui/fittings.rs`, called from both detail sites immediately after
`render_bay_usage` and before `render_slot_layout` — fitted-dependent
numbers stay grouped before the bare-hull blocks, as with every prior
slice. It takes `(&CharacterFitting, Option<&ImportedFitting>,
Option<&FittingTypes>)`: the saved site passes `None` for the
imported argument, the imported site passes the `ImportedFitting` it
already holds alongside its existing synthesis (the synthesis itself
is unchanged and still charge-free). No skill levels, no SDE handle.
It logs nothing.

### 6.2 Verbatim templates

Heading (locked): `Damage per second (base values)`.

Family lines, in locked order Turret, Launcher, Drones, Fighters,
each rendered only when that family is `Some`, formatted with
`widgets::format_fitting_amount` and the unit string `DPS` (one
decimal, grouped digits, huge-magnitude guard, exactly as shipped
blocks format amounts):

- `Turret DPS: {amount} DPS` — for example `Turret DPS: 12.8 DPS`
- `Launcher DPS: {amount} DPS`
- `Drone DPS: {amount} DPS`
- `Fighter DPS: {amount} DPS`

Excluded-item lines (after the family lines, same family order, only
when that family's count is > 0), mirroring the bay singular/plural
shape:

- `Turret DPS does not count 1 item with no damage data in Mimir's bundled item data.`
- `Turret DPS does not count {n} items with no damage data in Mimir's bundled item data.`
- `Launcher DPS does not count …`, `Drone DPS does not count …`,
  `Fighter DPS does not count …` (same two shapes)

Unloaded-weapon line (after the excluded lines, only when the count
is > 0). One locked wording covers both details, because saved and
DNA fittings list no charges at all and an EFT fitting lists only the
ones after a comma:

- `1 fitted weapon has no loaded charge listed, so it is not counted above.`
- `{n} fitted weapons have no loaded charge listed, so they are not counted above.`

Disclosure (locked, this block's own sentence set; every included and
excluded factor a reader needs is named, and the no-total rule is
stated plainly):

> `Base damage per second from Mimir's bundled item data: base charge, drone, and fighter damage per firing cycle, with no skill, implant, ship, module, rig, or subsystem bonuses applied. Turret and launcher damage counts only a loaded charge listed after the module in imported EFT text, exactly as listed; saved and DNA fittings list no loaded charges, and no charge is assumed. Fitted weapons are treated as online, drones and fighters as launched up to the ship's base drone bandwidth and fighter tubes, and every shot is counted at full damage, with no range, falloff, tracking, missile application, reload time, or flight time applied. No total is shown, because any family's damage can be unknown while another's is counted.`

Unavailable sentences (locked, sibling shape):

- No catalogue: `Damage per second unavailable: Mimir's bundled item data failed to load.`
- No ship data: `Damage per second unavailable: Mimir's bundled item data has no damage data for this fitting's ship.`

No line in this block is ever rendered in the over-capacity red:
DPS has no budget to exceed, and an inactive spare is ordinary data.

## 7. Demo story (hand-derived from quoted rows)

All inputs from `assets/demo/fittings.json` and the in-code samples
in `src/ui/fittings.rs`; all attribute values quoted in sections 2–3
(587 Rifter and 597 Punisher drone bandwidth present `0.0`, no
fighter data; 2456 Hobgoblin II cycle 4000.0 ms, multiplier 1.92,
thermal 20.0, bandwidth cost 5.0 — per-drone volley 20.0 × 1.92 =
38.4, per-drone DPS 38.4 / 4.0 = 9.6 when it can fly; 2889 200mm
AutoCannon II cycle 3750.0, multiplier 3.465; 21898 Republic Fleet
EMP S components 10.35 + 2.3 + 1.15 + 0.0 = 13.8). Demo data is not
modified by this slice.

Saved demo fittings (saved detail, `imported` is `None`):

- "Demo Brawler" (587 Rifter): its module-type slot rows
  (2048/2049/1225/2050/1535) carry no `speed` in the cache, so there
  is no weapon candidate. Its `SubSystemSlot0` row is type 28270 —
  a category-18 drone carrying cycle 4000.0 and multiplier 1.84,
  filed under a slot flag by the demo data; the category bound
  (section 2.4) keeps it out of the weapon pass, and it is not under
  `DroneBay`, so it counts nowhere in this block. Unloaded weapons
  = 0 and no unloaded line renders. Drones: 5
  Hobgoblin II, bandwidth 0.0 → active min(5, floor(0.0/5.0)) = 0 →
  `Drone DPS: 0.0 DPS`. Fighters: no capacity → no line (the
  `FighterBay` row is a category-9 blueprint and accumulates
  nothing). The block is the heading, the 0.0 drone line, and the
  disclosure.
- "Mission Runner" (587 Rifter) and "Demo Runner" (597 Punisher):
  identical shape — no weapon candidate, 3 Hobgoblin II at bandwidth
  0.0 → `Drone DPS: 0.0 DPS`, no other lines.

The demo deliberately exhibits the honest-zero case: combat drones on
zero-bandwidth frigates deal no damage, and the block says 0.0 rather
than crediting five unflyable drones (compare section 4: a Tristan
flying five of them shows real damage, section 8 test 4).

Sample EFT import (`DEMO_SAMPLE_EFT`, Rifter, EFT surface):

- Turrets: three 200mm AutoCannon II are all candidates (cycle
  3750.0, multiplier present). One lists Republic Fleet EMP S:
  volley 13.8 × 3.465 = 47.817; DPS 47.817 / 3.75 = 12.7512, rendering
  `Turret DPS: 12.8 DPS`. The other two list no charge: unloaded
  weapons = 2, rendering `2 fitted weapons have no loaded charge
  listed, so they are not counted above.`
- Launchers: no candidate without a multiplier → the EFT surface
  family is `Some(0.0)`, rendering `Launcher DPS: 0.0 DPS`.
- Drones: Hobgoblin II x2 at bandwidth 0.0 → `Drone DPS: 0.0 DPS`.
  No fighter line.

Sample DNA import (`DEMO_SAMPLE_DNA`, Rifter, `2889;3` among the
segments): DNA behaves as saved — three turret candidates, no
pairings, so no turret or launcher line and `3 fitted weapons have
no loaded charge listed, so they are not counted above.` DNA imports
no drones, so the drone line is `Drone DPS: 0.0 DPS` against the
present-zero bandwidth. No fighter line.

No demo carrier or drone-bandwidth hull exists, so fighter lines and
positive drone DPS are exercised by pure and UI tests (section 8),
not by demo data.

## 8. Test plan

Literal expectations with the arithmetic in comments, against the
bundled catalogue plus small fixture catalogues via
`FittingTypes::from_json` (the `bay_usage.rs` test shape). Synthetic
fixtures cross-check the Flutter literals quoted in section 2.2 at
base values; real-type tests use cache values hand-derived here.
Computed `f64` values are pinned in the pure layer, rendered strings
separately in the UI tests.

Pure layer (`src/fitting/dps.rs`):

1. **Turret, synthetic Flutter cross-check.** Fixture module `speed`
   4000.0, `damageMultiplier` 2.0; fixture charge kinetic 100.0
   (other components absent = 0.0). EFT surface: volley 100 × 2.0 =
   200; 200 / (4000/1000) = 50.0 turret DPS; launcher 0.0; unloaded
   0.
2. **Launcher, synthetic and real.** Same charge against a fixture
   module with `speed` 2000.0 and no multiplier: 100 / 2.0 = 50.0
   launcher DPS, turret 0.0. Real: 2404 Light Missile Launcher II
   (speed 12800.0, no multiplier) with 210 Scourge Light Missile
   (kinetic 83.0): 83 / 12.8 = 6.484375 launcher DPS through
   `parse_eft` text, proving the pairing path, not a fixture struct.
3. **Turret, real.** 484 125mm Gatling AutoCannon I with 180 Proton
   S: Σ = 3.0 + 0.0 + 2.0 + 0.0 = 5.0; volley 5.0 × 2.0625 = 10.3125;
   10.3125 / 3.0 = 3.4375 DPS (the journal's 3.4 at one decimal).
   Sample-EFT arithmetic: 2889 with 21898 → 12.7512 (section 7).
4. **Drones, real and capped.** 593 Tristan (bandwidth 25.0) + 5×2488
   Warrior II: volley 20.0 × 1.56 = 31.2; 31.2 / 4.0 = 7.8 each;
   active min(5, floor(25/5)) = 5 → 39.0. Tristan + 8×2488 → active
   still 5 → 39.0, excluded 0 (spares are not exclusions). Tristan +
   5×2488 then 5×2456 in a second row → first group consumes all
   bandwidth → still 39.0 (fit order is observable).
5. **Drones, synthetic Flutter cap cross-check.** Fixture drone
   explosive 10.0, multiplier 2.0, cycle 4000.0, cost 5.0; ship
   bandwidth 25.0 → volley 20, 5 each, 5 active → 25.0. Bandwidth
   12.0 → floor(12/5) = 2 active → 10.0. Bandwidth 0.0 (587 Rifter +
   real Hobgoblins) → 0.0 with the family `Some`.
6. **Drone known-zero and unknown.** 60478 (no DPS attributes) on a
   Tristan → 0.0, excluded 0. Catalogue-absent drone type ×3 →
   0.0, excluded 3. Fixture drone with volley > 0 and cycle but no
   bandwidth cost → excluded by quantity, no bandwidth consumed (a
   following known-cost group still flies its full count). Fixture
   non-damaging drone with a cost consumes bandwidth before a later
   combat group (Flutter consumption order).
7. **Fighters, real.** 23911 Thanatos (tubes 3, light 3, support 1,
   heavy absent → 0) + 18×23059 Firbolg I (size 9, light, both
   ability markers → attack; thermal 75.0, multiplier 1.0, duration
   5000.0): squadrons 9 + 9; volley each (75.0 × 1.0 × 9) = 675;
   675 / 5.0 = 135.0 each → 270.0. 10×23059 → sizes 9 and 1 →
   135.0 + (75.0 × 1 / 5.0) 15.0 = 150.0. Missiles-preferred-never
   check: the same Firbolg rows never touch the 138.0 / 14000.0
   missile attributes.
8. **Fighters, synthetic cross-checks.** Flutter fixture shape:
   components summing 207, multiplier 1.0, size 6, duration 5000.0 →
   6 × 207 / 5 = 248.4. Missiles-only fixture (no attack marker):
   components 36, size 12, duration 3500.0 → 12 × 36 / 3.5 =
   123.428571… Tube cap: 5 squadrons against 4 tubes → 4 × 248.4.
   Class cap: heavy cap 0 on a heavy group → 0.0, family `Some`.
   Multiplier absent → ×1.0 (never ×0.0). Launchable no-ability
   group first consumes a tube from a later damaging group.
   No-squadron-size group ×q → excluded q, no tube consumed.
   Non-carrier 587 + `FighterBay` rows → fighters `None`, nothing
   accumulated.
9. **Charge surfaces.** The same weapon rows: saved shape → turrets
   and launchers `None`, unloaded = candidate count (a `Cargo` charge
   of the right type sitting beside them changes nothing); DNA
   through `parse_import` → identical; EFT with a charge line → the
   test-2 numbers and unloaded reduced accordingly. EFT charge with
   Σ = 0 (fixture probe charge) → candidate counts as neither
   unloaded nor excluded, family 0.0. A mining laser (482) and a
   smartbomb (1563) are never candidates on any surface, and neither
   is a category-18 drone type filed under a slot flag (28270 under
   `SubSystemSlot0`, the demo pin in test 14 covers it end to end).
10. **Clamps and failures.** Quantity multiplies drones and fighters
    before caps; quantity 0 and negative, `type_id` ≤ 0 rows
    invisible; `i64::MAX` drone quantity stays finite (active capped,
    excluded saturating). Unknown ship id, non-category-6 ship →
    `Unavailable`. Primae 2863 + drones → drones `None`, other
    families unaffected, no excluded leakage. Fixture ship with
    fighter capacity but no tubes → fighters `None`. Slot-flag
    predicate pinned over the locked flag set (`HiSlot0`, `DroneBay`,
    `Cargo`, `Invalid`, `ServiceSlot0`, `""`, each slot prefix)
    duplicating the bay cases.

Generator and loader (Builder A gates, section 3.4): double-run
SHA-256 equality; strip-28-keys byte-identity; `DPS_ORACLES`
present/absent checks; counts and size budget; loader
`bundled_catalogue_invariants` extended per section 3.3; old-shape
fixture JSON still parses; loader value spot-checks mirroring the
oracle rows (484 speed/multiplier, 2404 absent multiplier, 23911
absent heavy slots, 23059 both markers).

UI (`src/ui/fittings.rs` tests, Builder B):

11. Line templates byte-exact, including the one-decimal rounding
    exhibits (`12.8 DPS` for computed 12.7512; `3.4 DPS` for 3.4375)
    and present-zero lines.
12. Excluded and unloaded templates byte-exact for 0 (none), 1
    (singular), 2+ (plural), in family order with the unloaded line
    last.
13. Heading, disclosure, and both unavailable sentences byte-exact.
14. Demo pins: the three demo fittings and both samples produce the
    section 7 computed values (pure) and rendered lines (UI),
    including no fighter line anywhere in demo and the 2- and
    3-unloaded lines on the samples.
15. **Existing blocks byte-identical gate:** every pre-existing UI
    test passes unmodified; the only render change in either detail
    is the inserted DPS block between bay usage and slot layout; the
    "Loaded charges" list, copy-back text, and synthesis are
    unchanged (charges stay display-only outside this block's math).

Gates at every commit: `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`,
`cargo build`. Nothing is live-verified against EVE by this slice
(all inputs are bundled data and pasted text).

## 9. Integrator list

- `README.md`: the Fittings bullet gains a damage-per-second sentence
  in the shape of the bay sentence (per-family base DPS; turret and
  launcher only from a loaded charge listed in imported EFT text;
  no bonuses, application, reload, or flight time; no total), and the
  sentence "There are still no DPS numbers …" is updated so it no
  longer denies the shipped block (capacitor-stability, sustained
  tank, and adjusted totals stay absent). The "Fitting" overview line
  is left alone unless it enumerates readouts. Any screenshot or
  feature inventory sites touched by prior fitting slices get the
  same treatment; if none exist, say so in the commit.
- `docs/engineering-journal/LEARNINGS.md`: dated entry for the charge
  pairing asymmetry (saved shapes carry charges as unlinked cargo;
  only imported EFT text pairs a charge with a weapon) with Evidence,
  Mechanism, and the generalizable rule (a damage rate needs the
  ammunition paired, not merely present; never join on cargo). The
  cache-versus-zip fighter drift (23059 size/damage, cache wins)
  goes in the same entry or its own.
- `docs/engineering-journal/DECISIONS.md`: dated entry covering (a)
  per-family lines with no total, (b) bandwidth-capped drone active
  count against the bay slice's uncapped usage sum, (c) turret and
  launcher DPS locked to the EFT detail, each with rationale,
  rejected alternatives, and a revisit condition.
- This design file is the design commit; no other docs move in
  builder commits.

## 10. Exclusions (explicitly not in this slice)

- Any total or combined DPS figure, and any volley, optimal-range, or
  falloff line (Flutter's volley-weighted range display reads
  attributes 54 and 158, which are never emitted here).
- Damage application of every kind: range and falloff curves,
  tracking, target signature and velocity, missile explosion radius
  and velocity, resistances of any target. Every shot counts at full
  base damage, as the disclosure states.
- Reload time, charge consumption over time, capacitor use of
  weapons, overheating, and missile flight time — none exists in the
  quoted engine bodies.
- Skills, implants, ship bonuses, module and rig bonuses (damage
  amplifiers, ballistics, heat sinks), stacking penalties, and every
  other modifier; attribute 212 is never emitted or read.
- Charge compatibility validation (`chargeSize`, `launcherGroup`),
  turret/launcher grouping, and ammo switching. An imported pairing
  is computed exactly as listed.
- Smartbomb, doomsday, bomb-ability, and kamikaze damage; fighter
  utility abilities; structure (`FighterBay` on category-65 hulls is
  never a category-6 ship) fighters.
- Any new charge storage: no change to saved fittings, synthesis,
  export, save, or delete paths. The EFT pairing is read in the
  imported detail only and dies with the import, exactly as today.
- Sentry-drone or fighter range behaviour, drone control range, and
  active-versus-in-bay states beyond the locked bandwidth/tube caps.
- Any demo-data, ESI, scope, or storage change.

## 11. Ownership and commit split

Small atomic commits, `type(scope): description`, no attribution
lines. Nothing is pushed or merged by builders; the parent does that.
Resolved names only in UI text (this block renders no type names at
all); `[FITTING]` counts-only logging, never per rendered frame (this
slice adds no new log lines: the pure function and render function
log nothing, and the loader's counts line is unchanged).

1. **Design (this commit):** `docs(dps): design base fitting damage
   per second` — only `docs/fitting-dps-design.md`.
2. **Builder A — data and pure layer, zero `src/ui/` changes:**
   (a) `feat(sde): emit base damage attributes for fitting types` —
   generator extension + regenerated catalogue with the section 3.4
   proofs and actual byte count in the commit body;
   (b) `feat(fitting): add pure base damage-per-second calculation`
   — loader fields/invariants + `src/fitting/dps.rs` with its tests
   (section 8 tests 1–10) + `src/fitting/mod.rs` export. Builder A
   owns `scripts/sde/generate_fitting_types_sde.py`,
   `assets/sde/fitting_types.json`, `src/names/fitting_types.rs`,
   `src/fitting/dps.rs`, `src/fitting/mod.rs`.
3. **Builder B — rendering, zero generator/catalogue/loader/pure
   changes:** `feat(fittings): show base damage per second in fitting
   details` — `render_fitting_dps` and its line helpers in
   `src/ui/fittings.rs` only, wired into both detail sites after bay
   usage, passing `Some(&imported)` at the imported site and `None`
   at the saved site, with UI tests (section 8 tests 11–15). Depends
   on Builder A's public API exactly as locked in section 4; any
   needed API change goes back through the design (amend this file in
   its own commit), never a silent rendezvous edit.
4. **Integrator:** README + engineering journal (section 9) as
   `docs(dps): document base fitting damage per second`; final full
   gate run (`cargo fmt --check`, `cargo clippy --all-targets -- -D
   warnings`, `cargo test`, `cargo build`); demo smoke of both
   details against section 7; confirmation that the existing-blocks
   byte-identical gate (test 15) holds on the final tree.

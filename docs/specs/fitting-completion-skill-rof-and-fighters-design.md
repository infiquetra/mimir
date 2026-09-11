# Fitting Module Completion — Architecture and Technical Contracts

**Companion to.** `docs/specs/fitting-completion-skill-rof-and-fighters.md`
(the WHAT). This document is the HOW: exact modifier routing, filter
definitions, data contracts, and the test scenarios the planner and the test
author enforce.

**Sources.** `mimir-context-library/platform-specs/03-feature-modules/fitting/specification.md`
(Dogma engine architecture, `FittingStats`, `DogmaAttributes`);
`docs/engineering-journal/QUEUED.md` (skill cycle-time bonuses P2, fighter
support P3); raw SDE CSVs in `scripts/sde/` (fuzzwork dump, 2026-09-11);
`dgmAttributeTypes.csv` and `invFlags.csv` (fuzzwork); pyfa `eos/effects.py`,
`eos/saveddata/fighter.py`, `eos/saveddata/fighterAbility.py`,
`eos/modifiedAttributeDict.py` (master, fetched 2026-09-11); ESI
`meta/openapi.json` (fighter location flags).

**Date.** 2026-09-11. **Author.** Architect session (Claude).

---

## 0. Evidence that changes the product spec — read first

The product spec's §0 investigation and §2.2 data model were checked against
the raw SDE and pyfa. Several load-bearing claims are wrong. The planner
must apply these corrections before the test author writes cases verbatim.

| # | Spec claim | What the data says | Consequence |
|---|---|---|---|
| C1 | "No data-driven filter exists; a transitive skill closure is needed" (§0) | The SDE **publishes** the filters as resolved modifiers on the skill types themselves: Rapid Firing effect 582 = `shipID / LocationRequiredSkillModifier / 51 <- 293 / op 6 / skillTypeID 3300`; Gunnery 414 (`51 <- 441`, filter 3300); MLO and Rapid Launch 1763 (`51 <- 293`, filter 3319); XL Torpedo/Cruise Spec 6578/6577 (filter = the spec skill itself). They were invisible only because category 16 (Skill) is not bundled, so their effects never reached `effect_modifiers.json`. | No closure. Route skill effects like ship effects. |
| C2 | The six sub-capital missile specialisations resolve from data | Their effect 1851 `selfRof` has **empty** `modifierInfo`. pyfa hardcodes `Effect1851: filteredItemBoost(requiresSkill(skill), 'speed', rofBonus * level)`. | One curated table entry, shaped exactly like the published 6577/6578. |
| C3 | "18 turrets need transitive closure (Quad 800mm Repeating Cannon II, Quad Mega Pulse Laser II)" | They list Gunnery **directly** in `requiredSkill4` (attr 1285). Sweep of all 780 published weapons with a cycle: 622 require Gunnery directly, 143 require MLO directly, **0** are transitive-only, 15 require neither (Vorton, probe/bomb launchers). | Filter = direct required skill over the six slots 182/183/184/1285/1289/1290, exactly what dogma's `LocationRequiredSkillModifier` means and what pyfa's `requiresSkill` checks. |
| C4 | Skill set = "15 skills carrying rofBonus" | **Gunnery** (3300) grants -2%/level turret cycle via attribute 441 `turretSpeeBonus`, not 293. At all-V, turret cycle is x0.72 (Gunnery x0.90, Rapid Firing x0.80), not x0.80. | Gunnery is in scope; §1.1's "20% understatement" is really 38.9% more DPS. |
| C5 | Ship attrs 908 (bay), 1547 (tubes), 2216/2217/2218 (light/support/heavy) (§2.2) | 908 is `shipMaintenanceBayCapacity` and 1547 is `rigSize`. Correct IDs: **2055** `fighterCapacity` (Thanatos 75,000 m3), **2216** `fighterTubes` (4), **2217** `fighterLightSlots` (3), **2218** `fighterSupportSlots` (2), **2219** `fighterHeavySlots` (0). Nyx: tubes 5, light 3, support 0, heavy 4, bay 110,000. | Rewrite §2.2 and every T2.x referencing 908/1547. |
| C6 | Attack ability = cycle 2128 (seconds), damage 2131..2134, multiplier 2226 | 2128 is `fighterAbilityMissilesDamageReductionSensitivity`. The **Attack** ability (effect 6465 `fighterAbilityAttackM`) uses 2226 multiplier, 2227/2228/2229/2230 EM/Therm/Kin/Exp, **2233 duration in milliseconds**. 2130..2134 and 2182 belong to the secondary **Missiles** ability (6431). Templar I attack EM is 2227 = 97.5; its 2131 = 178.5 is the missile salvo. | R2.1/T2.1/T2.4/T2.22 must use 2227..2230, 2226, 2233 ms. |
| C7 | "Drone Damage Amplifiers do not apply to fighters" (R2.6, AC2.10, T2.18) | DDA effect 6556 carries three fighter modifiers (`charID / OwnerRequiredSkillModifier` on 2226, 2178, 2130 from 1255, filter skill 23069). pyfa applies them with stacking penalty. All 53 ship-usable fighters require 23069 directly. | Invert: DDAs boost fighters. |
| C8 | Fighter skills and hull bonuses out of scope (R2.8) | Fighters (6560, +5%/lvl on 2226/2178/2130), Heavy Fighters (6563), racial Fighter Specializations (12844/12846/12847/12848, +2%/lvl), Drone Interfacing (6663, +10%/lvl to fighters too), Fighter Hangar Management (6570, +5%/lvl bay), and every carrier hull bonus (6601 Thanatos, 6602 Nidhoggur, 6605 Nyx, 6606 Hel, 6603/6604 Aeon/Wyvern, 6984 role) are published, resolvable `charID` modifiers. With fighters routed through the existing `charID` path they apply **for free**; excluding them would need extra code and understate a Thanatos by ~2.3x at all V. | Recommend in scope (§3.6). |
| C9 | Squadron size "e.g. 6" | 2215 by role: 6 (light attack, heavy), 3 (support), 12 (superiority light, e.g. Gram), 9 (some structure fighters). All 94 fighters carry 2215. | Fine; read from data. |
| C10 | Bay over-capacity "is a fit error" | No `FittingError` mechanism exists in the codebase; CPU/PG over-capacity is reported as used/max only. | Report used/max, never truncate DPS; panel renders the row in `EveColors.error` when used > max. |

The QUEUED/LEARNINGS 2026-09-08 premise ("modifierInfo stops at item
boundaries") is therefore also wrong for most skills. Skill effects that are
genuinely empty in the current SDE: 1851 (six missile specs, cycle),
660/661/662/668 (Rockets/Light/Heavy/HAM/Cruise/Torpedoes/Auto-Targeting,
damage), 1730 (Light/Medium/Heavy Drone Operation, Sentry Drone
Interfacing, racial Drone Specializations, damage). Everything else
cross-item on a skill is published.

---

## 1. Shared engine changes (both work items)

### 1.1 Bundle skills and fighters

`scripts/sde/generate_dogma_sde.py`:

- `TARGET_CATEGORIES += {16, 87}`. Cost: +511 skill types (4,193 attribute
  rows, 1,491 effect rows) and +94 fighter types (5,729 attribute rows, 262
  effect rows); roughly +0.6 MB on `dogma.json`. Skill effects (582, 414,
  1763, 1851, 6560, 6563, 6570, 6663, 12844..12848, ...) and fighter ability
  effects (6465, 6431, 6485, 6554, ...) become `referenced_effects` and land
  in `effect_modifiers.json` (1851 and the ability effects with an empty
  `modifiers` list but a name).
- Skills already seeded from `assets/sde/skills.json` keep `rank`,
  `primaryAttribute`, `secondaryAttribute`: `_importSdeData` upserts with
  those columns absent, and Drift's `insertAllOnConflictUpdate` only sets
  present columns. Add a test that proves it (§4.4).
- Fighter and skill types must not appear in the module browser:
  `getModulesBySlotType` selects by slot effects 11/12/13/2663/3772, which
  neither carries. Lock with a test (§4.4).

**Re-import gating.** `initialize()` skips `_loadBundledDogma` whenever
`hasDogmaData()` is true, so existing installs would never receive the new
categories. Contract:

- `SdeService.bundledDogmaVersion = 2` (int constant; bump on every
  regeneration that changes coverage).
- `SdeMetadata` key `dogma_version`. `initialize()` imports when
  `!hasDogmaData || getMetadata('dogma_version') != '$bundledDogmaVersion'`,
  then writes the key. Import is idempotent (upserts).

### 1.2 Batch type loading

`SdeService.getModuleType` issues 4-5 queries per type and resolves
prerequisite names one by one; a character has up to ~500 trained skills.
Add:

```dart
/// Types with attributes and effects only (no prerequisite names):
/// 3 queries total (types, attributes, effects, each `WHERE typeId IN`),
/// chunked at 500 ids. Missing ids are absent from the result.
Future<Map<int, ModuleType>> getDogmaTypes(Iterable<int> typeIds);
```

`ModuleType` is reused (slotType defaults to high, cpu/powergrid 0,
`skillRequirements` empty). Optional later cleanup: route the module/charge
loop in `fittingStatsProvider` through the same call.

### 1.3 Required-skill filter over six slots

`DogmaEngine._requiredSkillAttributes = {182, 183, 184, 1285, 1289, 1290}`.
`requiresSkill(type, skillId)` is a direct check over those attributes, the
same set pyfa's `Item.requiredSkills` reads. No transitive closure (C3).

### 1.4 Bonus buckets carry a stacking flag

Today `modulePercent`/`chargePercent` penalise every percent bonus on an
attribute regardless of source, and `moduleMul`/`chargeMul` never penalise.
With three unpenalised ROF sources (ship trait, Gunnery, Rapid Firing) on one
turret this becomes wrong, so the buckets change shape:

```dart
class _Bonus {
  const _Bonus(this.factor, {required this.penalized});
  final double factor;      // 1 + pct/100 for op 6, raw multiplier for op 0/4
  final bool penalized;
}
// per target type id -> attribute id -> bonuses
Map<int, Map<int, List<_Bonus>>> moduleBonuses, chargeBonuses;
```

Evaluation (`moduleAttr`/`chargeAttr`), matching pyfa
`ModifiedAttributeDict.__calculateValue`:

```
value = base
      x product(unpenalised factors)
      x chain(penalised factors > 1)   // sorted by |f-1| desc, i-th x (1 + (f-1) * exp(-(i/2.67)^2)), i from 0
      x chain(penalised factors < 1)   // separate chain, same rule
```

`exp(-(i/2.67)^2)` equals the existing `getStackingPenalty(i + 1)`.

**Penalised iff the owner is a fitted module, charge, drone or fighter.**
Ship-owned and skill-owned bonuses are never penalised (pyfa `boost`/
`multiply` default `stackingPenalties=False`; module handlers such as
Effect6556, 763, 91 pass `True`). Attribute stackability (dgmAttributeTypes
`stackable`) is not bundled yet; every module-owned bonus routed today
targets a non-stackable attribute (51, 64, 158, 54, 160, 212, 1255-fed
2226/2130, 114..118 via BCS), so owner kind is sufficient for this increment.
Bundling `stackable` is a follow-up (§7).

Planner decision recorded: this also makes two or more heat sinks, gyros,
BCS, DDAs or FSUs stacking-penalised (pyfa parity, currently unpenalised).
Existing tests use single modules and are unaffected. If the owner wants
today's numbers preserved for now, register op 0/4 module bonuses with
`penalized: false` (one line) and file the parity fix in QUEUED.

The ship-level `percentModifiers`/`mulModifiers` keep their current rule
(`_nonStackableAttributes` = the twelve resonances). Ship-level entries
gain no penalty flag in this increment.

### 1.5 Ship bonus scaling map (fixes capitals)

Today every ship-owned modifier is multiplied by the level of the **first**
required skill (182 -> 183 -> 184). For carriers 182 is Capital Ships
(20533) and the racial carrier skill sits in 183, so hull fighter bonuses
would scale with the wrong skill. Role bonuses (`shipBonusRole*`) are also
scaled today although they must apply raw.

The SDE encodes the scaling explicitly: racial ship skills carry
`shipID / ItemModifier / <bonusAttr> <- 280 (skillLevel) / op 0` modifiers
(Minmatar Frigate 453/762/4601 -> 460/587/1626; Gallente Carrier 6585 ->
2367/2368/2369/2370/5983/6198/6197; Assault Frigates 987/988 -> 673/675).

Contract:

```
bonusScale: Map<int attributeId, double level>
  built from the ship's required skills (six slots) whose types are in
  `skillTypes`: for each modifier with domain shipID, func ItemModifier,
  modifyingAttributeId 280, operator 0 or 4:
      bonusScale[modifiedAttributeId] = clamp(level(skill), 0, 5)
ship-owned modifier value = base x (bonusScale[modifyingAttributeId] ?? 1.0)
```

Untrained racial skill -> level 0 -> bonus 0 (today's behaviour). Attributes
not targeted by any required skill (role bonuses) apply raw (fix).

**Compatibility shim.** When `skillTypes` is empty (hand-built fixtures in
existing tests) fall back to today's `shipSkillLevel` rule and log at debug.
New tests pass skill types; the shim is removed once the fixture tests are
migrated (tracked in QUEUED).

### 1.6 `calculateStats` signature

```dart
Future<FittingStats> calculateStats(
  Fitting fitting,
  ShipType shipType,
  Map<String, ModuleType> moduleTypes,   // modules, charges, drones, fighters, bomb charges
  List<CharacterSkill> characterSkills,  // levels; missing skill = 0
  {
    Map<int, List<EffectModifier>> effectModifiers = const {},
    Map<int, ModuleType> skillTypes = const {},  // NEW: trained skills + ship required skills
  },
)
```

Pure addition; all existing call sites compile unchanged.

Provider wiring (`fitting_providers.dart`):

- New `fittingSkillTypesProvider = FutureProvider<Map<int, ModuleType>>`:
  ids = trained skill ids with level > 0 (from `trainedSkillsProvider`) union
  the active ship's required skill ids (six slots) -> `sde.getDogmaTypes`.
  Riverpod caches it; it only recomputes when the character, their skills
  or the hull changes.
- `fittingStatsProvider` watches it, resolves fighter types and their bomb
  charge (attribute 2324) into `moduleTypes`, and passes the union of
  module, charge, drone, fighter and skill effect ids to
  `ensureEffectModifiers`.

---

## 2. Work Item 1 — skill cycle-time bonuses

### 2.1 Modifier routing for skill owners

For every entry in `skillTypes` with `level = clamp(L, 0, 5) > 0`:

1. **Owner attribute resolution.** `skillValue(attr) = type.baseAttributes[attr] * level`;
   `skillValue(280) = level`. This is pyfa's
   `skill.getModifiedItemAttr(x) * skill.level`, and it is what the skill's
   own `itemID` effects (163 `293 <- 280`, 413 `441 <- 280`, 152
   `292 <- 280`) encode. `itemID`-domain modifiers are therefore **ignored**
   (already the engine's behaviour).
2. **Allowlist.** Only effects in `DogmaEngine.skillEffectAllowlist` are
   routed; every other skill effect is counted and reported in one debug
   line (`Ignored N skill effects outside the allowlist`). pyfa is itself an
   allowlist (one handler per effect), and this keeps unvalidated skills
   (Advanced Weapon Upgrades, Thermodynamics, ...) from changing numbers
   before their tests exist. Growing it is one id plus one test.
3. **Routing** reuses `routeOwnerModifiers(effects, ownerAttributes,
   ownerIsShip: false, penalized: false)`:
   - `shipID / LocationRequiredSkillModifier` -> `moduleBonuses[target][attr]`
     for every fitted module type with `requiresSkill(target, skillTypeId)`
     (drones and fighters excluded from this loop, as today).
   - `charID / OwnerRequiredSkillModifier` -> `chargeBonuses[target][attr]`
     for loaded charges, drones and fighters passing the same filter.
   - `shipID / ItemModifier` -> ship `percentModifiers`/`mulModifiers`
     (e.g. 6570 fighter bay).
4. **Curated supplement** `_curatedSkillModifiers` (same pattern as
   `_expressionTreeSpeedEffects`): applied only when the bundled modifier
   list for that effect is empty on that skill.

| Owner skill | Synthesised modifier (mirrors published 6577/6578 and pyfa Effect1851) |
|---|---|
| 20209 Rocket Spec, 20210 Light Missile Spec, 20211 Heavy Missile Spec, 25718 HAM Spec, 20212 Cruise Spec, 20213 Torpedo Spec | `EffectModifier(effectId: 1851, func: 'LocationRequiredSkillModifier', operator: 6, modifiedAttributeId: 51, modifyingAttributeId: 293, domain: 'shipID', skillTypeId: <owner>)` |

### 2.2 Effect allowlist for this work item (all verified in the SDE)

| Effect | Skill(s) | Published modifier | Bonus at V |
|---|---|---|---|
| 414 | 3300 Gunnery | `51 <- 441` op 6, filter 3300 | turret cycle x0.90 |
| 582 | 3310 Rapid Firing | `51 <- 293` op 6, filter 3300 | turret cycle x0.80 |
| 1763 | 3319 MLO, 21071 Rapid Launch | `51 <- 293` op 6, filter 3319 | launcher cycle x0.90 and x0.85 |
| 6577 | 41410 XL Cruise Missile Spec | `51 <- 293` op 6, filter 41410 | x0.90 |
| 6578 | 41409 XL Torpedo Spec | `51 <- 293` op 6, filter 41409 | x0.90 |
| 1851 (curated) | six sub-capital missile specs | see §2.1 | x0.90 |

Verified target shapes: T1 launchers carry MLO in 182 or 183 (Rocket
Launcher I: 182 = 3320 Rockets, 183 = 3319); T2 launchers carry the
specialisation in 183 (Rocket Launcher II: 182 = 3319, 183 = 20209); XL
Torpedo Launcher II carries 41409 in 184; every turret carries 3300 in 183,
184 or 1285 (Dual Giga Pulse Laser II uses 184, the Quad variants 1285). Turret specialisations carry 292 (damage), never 293 (spec R1.3
holds).

Skills already in the hardcoded `_skillModifiers` table (CPU Management,
Engineering, Navigation, ...) are **not** allowlisted in this increment so
nothing double-applies; retiring that table in favour of their published
effects (397, 394, ...) is a follow-up with an equivalence test.

### 2.3 Worked numbers (for the parity tests)

- 125mm Gatling AutoCannon I (51 = 3000 ms) on a Rifter, Minmatar Frigate V,
  Gunnery V, Rapid Firing V: `3000 x 0.625 x 0.90 x 0.80 = 1350 ms`.
  Multiplicative, unpenalised, volley unchanged.
- Light Missile Launcher II (51 = 12800 ms), MLO V, Light Missile Spec V:
  `12800 x 0.90 x 0.90 = 10368 ms`; add Rapid Launch V: `x 0.85 = 8812.8 ms`.
- Rocket Launcher I with every specialisation at V and MLO 0: unchanged
  (requires 3320 and 3319 only).

### 2.4 Logging

`Log.d('DOGMA', 'Skill <id> L<level> effect <effectId>: <attr> op<op> <value> -> <n> targets')`
per applied modifier; one summary line per calculation with the count of
ignored (non-allowlisted) skill effects.

---

## 3. Work Item 2 — fighters

### 3.1 Models (`lib/features/fitting/domain/models.dart`, freezed)

```dart
@freezed
abstract class FighterGroup with _$FighterGroup {
  const factory FighterGroup({
    required int typeId,
    required String typeName,
    required int quantity,        // fighters of this type carried (ESI FighterBay quantity, EFT "xN")
    @Default(0) int inSpace,      // fighters launched; 0 = launch everything the hull allows
  }) = _FighterGroup;
  factory FighterGroup.fromJson(Map<String, dynamic> json) => _$FighterGroupFromJson(json);
}

// Fitting: pure addition, old saved JSON without the key loads as [].
@Default([]) List<FighterGroup> fighters,

enum FighterAbilityKind { attack, missiles, bomb, kamikaze, microWarpDrive, afterburner,
  microJumpDrive, evasiveManeuvers, tackle, stasisWebifier, warpDisruption,
  energyNeutralizer, ecm }

@freezed
abstract class FighterSquadronStats with _$FighterSquadronStats {
  const factory FighterSquadronStats({
    required int typeId,
    required String typeName,
    required int squadronSize,          // attr 2215
    required int squadrons,             // derived from quantity
    required int activeSquadrons,       // after tube/class limits
    required List<FighterAbilityKind> abilities,   // every ability the type carries
    FighterAbilityKind? activeAbility,  // the one contributing DPS, if any
    @Default(0.0) double dps,
  }) = _FighterSquadronStats;
  ...
}

// FittingStats: pure additions.
@Default(0.0) double dpsFighters,
@Default(0.0) double fighterBayUsed,   // m3
@Default(0.0) double fighterBayMax,    // m3, 0 when the hull has no attr 2055
@Default(0) int fighterTubesUsed,
@Default(0) int fighterTubesMax,
@Default(0) int fighterLightUsed,  @Default(0) int fighterLightMax,
@Default(0) int fighterSupportUsed, @Default(0) int fighterSupportMax,
@Default(0) int fighterHeavyUsed,  @Default(0) int fighterHeavyMax,
@Default([]) List<FighterSquadronStats> fighterSquadrons,
```

Why fighter counts rather than squadron objects (spec R3): ESI `FighterBay`
items and pyfa EFT lines (`Templar II x6`, one line per squadron) both carry
fighter counts; squadrons are derived deterministically (§3.3). Repeated
EFT lines of one type merge by summing.

`dpsTotal = dpsGuns + dpsMissiles + dpsDrones + dpsFighters`. `volley`
stays guns + missiles (drones are excluded today; fighters follow drones).

### 3.2 Attribute contract (`dogma_attributes.dart` additions)

| Constant | Id | Meaning |
|---|---|---|
| `fighterCapacity` | 2055 | fighter bay, m3 |
| `fighterTubes` | 2216 | launch tubes |
| `fighterLightSlots` / `fighterSupportSlots` / `fighterHeavySlots` | 2217 / 2218 / 2219 | per-class squadron caps |
| `fighterSquadronMaxSize` | 2215 | fighters per squadron |
| `fighterSquadronIsLight` / `IsSupport` / `IsHeavy` | 2212 / 2213 / 2214 | class flags (1.0) |
| `fighterSquadronRole` | 2270 | 1 superiority, 2 light attack, 3 support, 4 heavy attack, 5 long-range heavy |
| `fighterAttackDamageMultiplier` | 2226 | Attack ability |
| `fighterAttackDamageEm/Therm/Kin/Exp` | 2227 / 2228 / 2229 / 2230 | Attack ability |
| `fighterAttackDuration` | 2233 | ms |
| `fighterMissilesDamageMultiplier` | 2130 | Missiles ability |
| `fighterMissilesDamageEm/Therm/Kin/Exp` | 2131 / 2132 / 2133 / 2134 | Missiles ability |
| `fighterMissilesDuration` | 2182 | ms |
| `fighterBombType` / `fighterBombDuration` | 2324 / 2349 | Bomb ability (charge type id, ms) |
| `fighterRefuelingTime` | 2426 | ms (recorded, unused in v1) |

Structure fighters use 2740/2741/2742 flags and hulls use 2737..2739; ships
never carry those slots, so structure fighters classify but never launch.
`fighterAbilityAttackTurret*` (2171..2180) is carried by no published
fighter; the ability table lists it for completeness behind a
`containsKey` guard.

### 3.3 Engine contract

**F1. Classification.** A type in `fitting.fighters` is a fighter iff
`baseAttributes.containsKey(2215)`. Class = first true of 2212/2213/2214
(else standup flags -> unlaunchable on ships). Fighter type ids are added to
`charTargetIds` and to the exclusion set of the `shipID` module loop,
exactly like drones.

**F2. Squadrons.** `maxSize = attr(2215)`; `launched = inSpace > 0 ? min(inSpace, quantity) : quantity`;
`squadrons = ceil(launched / maxSize)` with sizes `[maxSize, ..., remainder]`.
Bay usage counts everything carried: `fighterBayUsed += quantity x volume(38)`.

**F3. Activation (deterministic, spec R4).** Iterate `fitting.fighters` in
declaration order, squadrons in order. A squadron activates iff
`tubesLeft > 0` and `classLeft(class) > 0`; both decrement. Hull caps read
`shipType.baseAttributes.containsKey(id) ? attr(id) : 0` for 2216..2219 and
2055 (the `ItemModifier + shipID` branch writes phantom attributes such as
2055 = 1.05 on hulls that lack them, so the guard is mandatory).

**F4. Abilities.** Curated table keyed by effect id (the
`_expressionTreeSpeedEffects` pattern; ability effects publish no
`modifierInfo`):

| Effect | Kind | Multiplier | Damage attrs | Duration | Charges (pyfa `NUM_SHOTS_MAPPING` by role 2270) |
|---|---|---|---|---|---|
| 6465 `fighterAbilityAttackM` | attack | 2226 | 2227..2230 | 2233 | none |
| 6431 `fighterAbilityMissiles` | missiles | 2130 | 2131..2134 | 2182 | role 2: 12 shots / 4 s rearm; 4: 6 / 6 s; 5: 3 / 20 s; 1: unlimited |
| 6485 `fighterAbilityLaunchBomb` | bomb | 1.0 | charge 2324's 114/116/117/118 | 2349 | role 5: 3 / 20 s |
| 6554 `fighterAbilityKamikaze` | kamikaze | — | — | — | one-shot, never DPS |
| 6441, 6440, 6442, 6439, 6464, 6435, 6436, 6434, 6437 | propulsion / ewar kinds | — | — | — | represented, no DPS |

Active ability (pyfa `Fighter.__init__` parity): if the type carries 6465,
only `attack` deals DPS; otherwise every damage ability except `bomb` and
`kamikaze` is active (Gram: `missiles`). Reloads are infinite in v1 (pyfa
default `factorReload = False`, and Mimir's cap injectors already assume
infinite clips); the shot/rearm table is recorded in the constant for the
queued clip-reload work.

**F5. DPS.**

```
components_i = chargeAttr(fighter, dmgAttr_i)              // after charID bonuses, §3.6
mult         = chargeAttr(fighter, multAttr) (1.0 if absent)
duration_ms  = chargeAttr(fighter, durationAttr)
squadronVolley = sum(components) x mult x squadronSize
squadronDps    = squadronVolley / (duration_ms / 1000)
dpsFighters    = sum over active squadrons
```

Missing 2215, multiplier, damage or duration attributes -> that type
contributes 0 and is logged; never throws.

**F6. Bay and tubes.** `fighterBayMax = attr(2055)` after ship
`percentModifiers` (6570 Fighter Hangar Management +5%/lvl); `fighterTubesMax = attr(2216)`;
used values from F3. Over-capacity is reported, never truncated.

**F7. Drone isolation.** Drones and fighters live in separate lists and
loops; `droneBandwidthUsed`, `droneBayUsed`, `dpsDrones` are computed by
untouched code. Regression-locked by T2.13/T2.14.

### 3.4 Parsers and mappers

- **EFT import** (`format_parser.dart`): a line matching `^(.+?) x(\d+)$`
  whose resolved type's group is in category 18 -> `DroneGroup(quantity)`,
  category 87 -> `FighterGroup(quantity)`; same-type lines merge. This also
  fixes the pre-existing silent drop of EFT drones (today `Hobgoblin II x2`
  fails the name lookup and vanishes). Category comes from
  `database.getGroup(groupId).categoryId`.
- **EFT export** (`generateEft`): after rigs, a blank line, then drone
  lines, a blank line, then fighter lines, each `Name xN` (pyfa
  `exportFighters` ordering: light, heavy, support). Round-trips.
- **ESI asset snapshot** (`combat_fit_snapshot_mapper.dart`):
  `locationFlag` `FighterBay` -> `FighterGroup(quantity)`;
  `FighterTube0`..`FighterTube4` -> same type merged with `inSpace += quantity`.
- **Killmail** (`combat_killmail_fit_mapper.dart`): flag 158 -> bay,
  159..163 -> tubes (in space). 87 DroneBay is already used. fuzzwork's
  `invFlags.csv` is header-only (verified 2026-09-11), so the plan's data
  step must confirm 158..163 from CCP's official SDE `invFlags` YAML or
  from a real carrier killmail on zKillboard before the mapper test is
  written; the ESI name flags (`FighterBay`, `FighterTube0..4`) used by the
  snapshot mapper are confirmed from `meta/openapi.json` for both the
  assets `location_flag` and the fittings `flag` enums.
- **ESI fitting export** (`esi_fitting_export.dart`): one
  `{type_id, flag: 'FighterBay', quantity}` per group. (Drones are not
  exported today either; emitting `DroneBay` items is a one-line sibling fix
  the planner may include.)
- **Persistence**: saved-fitting JSON gains `fighters`; absent key -> `[]`.

### 3.5 UI (`stats_panel.dart`)

- OFFENSE: `Fighters` row when `dpsFighters > 0` (next to `Drones`).
- New `FIGHTERS` section when `fighterTubesMax > 0 || fighterBayUsed > 0`:
  `Tubes used/max`, `Bay used/max m3` (error colour when used > max),
  `Light a/b`, `Support a/b`, `Heavy a/b`, then one row per
  `fighterSquadrons` entry (`typeName  active/squadrons  dps`).
- Hulls without tubes or bay render no section (S2.6).
- Editor: no drone or fighter editing UI exists; fighters enter through
  EFT import, ESI snapshot and killmails. Editing is out of scope (flag in
  QUEUED).

### 3.6 Bonuses that reach fighters through existing routing

Because fighters join `charTargetIds`, these apply with no new engine
branches (owner kind decides the penalty flag, §1.4):

| Source | Effect | Modifier | Owner -> penalty |
|---|---|---|---|
| Drone Damage Amplifier | 6556 | `charID` 2226/2178/2130 <- 1255 op 6, filter 23069 | module -> penalised |
| Fighter Support Unit | 6566 | `charID` 2233/2177/2182 <- 2337 op 4, filter 23069 | module -> penalised |
| Carrier hull (Thanatos) | 6601 | `charID` 2226/2178/2130 <- 2367 op 6, filter 23069; 2367 scaled by Gallente Carrier via §1.5 | ship -> unpenalised |
| Fighters skill | 6560 | `charID` 2226/2178/2130 <- 292 op 6, filter 23069 | skill -> unpenalised |
| Heavy Fighters | 6563 | same on filter 32339 | skill |
| Racial Fighter Specialization | 12844/12846/12847/12848 | same on filter 9239x | skill |
| Drone Interfacing | 6663 | `charID` 64 <- 292 filter 3436 (drones) and 2226/2178/2130 filter 23069 (fighters) | skill |
| Fighter Hangar Management | 6570 | `shipID / ItemModifier` 2055 <- 2340 op 6 | skill -> ship bucket |

Allowlist additions for this work item: 6560, 6563, 6570, 6663, 12844,
12846, 12847, 12848 (6561/6562 optional; nothing consumes fighter velocity
or shield yet). Note 6663 also adds Drone Interfacing to drone DPS, a
correct change for drone fits that the production-wiring test must
re-baseline only if its seeded character trains it (it trains nothing
today).

---

## 4. Test scenarios the test author enforces

Fixture conventions: `dogma_engine_test.dart` groups build `ShipType`/
`ModuleType` by hand and pass `skillTypes:`; `real_sde_weapon_test.dart`
loads `assets/sde/dogma.json` and `effect_modifiers.json` from disk;
`fitting_stats_production_wiring_test.dart` seeds Drift from the bundled
types inside `tester.runAsync` and renders `StatsPanel` on a 1200x2400
surface. Spec ids are kept where the case survives; corrected cases are
marked.

### 4.1 `DogmaEngine skill cycle bonuses` (unit)

| Id | Case | Expected |
|---|---|---|
| T1.1..T1.3 | Rapid Firing V / III / untrained on a turret with 183 = 3300, RoF 3000 | 2400 / 2640 / 3000 ms |
| **T1.1g (new)** | Gunnery V (441 = -2, effect 414) on the same turret | 2700 ms; with Rapid Firing V: 2160 ms |
| T1.4 | MLO V on launcher with 182 = 3319 | 3600 ms |
| **T1.4r (new)** | Rapid Launch V (293 = -3, effect 1763) | x0.85; with MLO V x0.765 |
| T1.5..T1.8 | Rocket Spec on T2 launcher (183 = 20209); composition with MLO; leak across classes; T1 launcher untouched | per spec |
| T1.9 / T1.10 | Rapid Firing on a launcher; MLO on a turret | unchanged |
| **T1.11 (replaces transitive)** | Turret with 3300 only in 1285 (Quad 800mm shape) | Rapid Firing applies |
| **T1.12 (replaces)** | Turret with 182/183/184 = 55033/54826/54829 (Vorton shape) | unchanged |
| T1.13 / T1.14 | Ship trait -7.5%/lvl at V + Gunnery V + Rapid Firing V | `base x 0.625 x 0.9 x 0.8` exactly; no penalty |
| **T1.14m (new)** | Two module-owned ROF bonuses (op 4, e.g. two gyros) plus skills | module pair penalised in one chain, skills untouched |
| T1.15 | Volley unchanged | equal to untrained |
| T1.16 / T1.17 | Cap drain key uses the shortened cycle; offline module inert | per spec |
| T1.18 | Skill type without attr 293 | no bonus, no throw |
| T1.19 | Level 7 recorded | treated as 5 |
| **T1.23 (new)** | Curated 1851 yields to bundled data | give 1851 a non-empty bundled list in the fixture; the curated entry is not applied |
| **T1.24 (new)** | Non-allowlisted skill effect | ignored and counted; numbers unchanged |
| **T1.25 (new)** | Skill filter honours slots 1289/1290 | bonus applies |

### 4.2 `DogmaEngine fighters` (unit)

| Id | Case | Expected |
|---|---|---|
| T2.1 | 1 squadron, 2215 = 6, 2228 = 207, 2226 = 1.0, 2233 = 5000 | `6 x 207 / 5 = 248.4` dps |
| T2.2 / T2.3 / T2.5 | size 9 vs 6; multiplier 1.5; four components 50 each | ratio 1.5; x1.5; volley 200 x size |
| **T2.4 (corrected)** | 2233 = 5000 | divides by 5.0 s, not 5000 |
| T2.6..T2.10 | tube cap (2216 = 4), class cap (2219 = 2), zero cap (Nyx 2218 = 0 with a support squadron), stricter wins, mixed classes in declaration order | per spec with corrected ids; T2.10 expected set = first four squadrons in declaration order that fit their class |
| **T2.6q (new)** | quantity 14, maxSize 6, tubes 3 | squadrons 6/6/2, all active, dps = 14/6 x one full squadron's dps |
| **T2.6s (new)** | inSpace = 6 of quantity 12 | one squadron active; bay usage still 12 x volume |
| T2.11 / **T2.12 (corrected)** | bay usage 3 x 6 x 1000; bay 2055 = 10000 | `fighterBayUsed = 18000`, `fighterBayMax = 10000`, dps unchanged (no truncation) |
| T2.13 / T2.14 | drones + fighters on one hull; fighters only | drone fields bit-identical; bandwidth 0 |
| T2.15 | guns + drones + fighters | `dpsTotal` sums each once |
| T2.16 | Rifter + fighters | all fighter fields 0, no section, no throw |
| T2.17 | fighter lacking 2215 or 2233 | contributes 0, logged |
| **T2.18 (inverted)** | DDA II (1255 = 20.5) + Templar squadron | fighter dps x1.205; drone dps also x1.205 |
| **T2.18b (new)** | two DDAs | second penalised: `x (1 + 0.205) x (1 + 0.205 x 0.869)` |
| T2.19 | Firbolg shape (6465 + 6431 + 6441) | dps from `attack` only; `abilities` lists three kinds, `activeAbility = attack` |
| **T2.19g (new)** | Gram shape (6431 + 6439 + 6464, role 1) | dps from `missiles`; infinite cycle |
| **T2.19b (new)** | Ametat shape (6465 + 6485 bomb + 6442) | dps from `attack`; bomb represented, inactive |
| T2.20 | Templar (2227) vs Einherji (2230) | component lands in EM vs explosive |
| T2.21 | standup flags 2740..2742 | classified, 0 active on a carrier |
| **T2.25 (new)** | Thanatos-shaped hull: 182 = 20533, 183 = 24313, effect 6601 with 2367 = 5; Gallente Carrier type with 6585 (`2367 <- 280`); Capital Ships V, Gallente Carrier III | fighter dps x1.15 (not x1.25) |
| **T2.26 (new)** | same, role attribute not targeted by any required skill | role bonus applies raw |
| **T2.27 (new)** | Fighters V (6560, 292 = 5) + hull V + DDA | `x1.25 x1.25 x1.205`, skills and hull unpenalised |
| **T2.28 (new)** | Fighter Hangar Management V (6570) | `fighterBayMax = 2055 x 1.25`; a hull without 2055 stays 0 |

### 4.3 Parity from bundled assets (`real_sde_weapon_test.dart`)

| Id | Case | Expected (recomputed from raw attributes in the test) |
|---|---|---|
| T1.20 | 125mm Gatling AutoCannon I + Proton S, Minmatar Frigate V + Gunnery V + Rapid Firing V, skill types from the bundle | cycle `51 x (1 - 0.375) x (1 + 441 x 5 / 100) x (1 + 293 x 5 / 100)`; volley unchanged |
| T1.20b | + Small Autocannon Specialization V | cycle identical (attr 293 absent) |
| T1.21 | Light Missile Launcher II + light missile, MLO V + Light Missile Spec V + Rapid Launch V | `12800 x 0.9 x 0.9 x 0.85` |
| **T1.26 (curation guard)** | bundled 1851 modifier list | still empty; if it ever fills, fail with a message to delete the curated entry |
| **T1.27 (new)** | bundled 582/414/1763/6577/6578 | present with the shapes in §2.2 |
| T2.22 | Thanatos + 3 x Firbolg I (18 fighters), no skills | `3 x 6 x 2228 / (2233/1000) = 405.0`; tubes 3/4, light 3/3, bay 18,000/75,000 |
| **T2.22s (new)** | same + Fighters V + Drone Interfacing V + Gallente Carrier V | `405 x 1.25 x 1.5 x 1.25`, from raw 292/2367 values |
| T2.23 | Nyx (2218 = 0) + Dromi I (support) | 0 active; Nyx + Cyclops I (heavy) -> 1 active |
| **T2.29 (new)** | every bundled fighter type | classifies, carries 2215, and every 6465 carrier has 2226 and 2233 |

### 4.4 Data and service tests

- Generator/asset: `dogma.json` contains categories 16 and 87; `effect_modifiers.json` contains 582, 414, 1763, 6577, 6578, 6560, 6563, 6570, 6663, 6465, 6431, 6485 keys.
- `SdeService.initialize()` re-imports when `dogma_version` metadata differs and skips when equal; skills seeded from `skills.json` keep `rank`/`primaryAttribute` after the dogma import.
- `getDogmaTypes([3310, 23055, 999999])` returns two entries with attributes and effects in three queries (assert via a counting `QueryExecutor` or by timing-free query log).
- `getModulesBySlotType` never returns a skill or fighter type.

### 4.5 Parser, mapper and export tests

- `parseEft` with a pyfa export containing `Hobgoblin II x5`, a blank line, `Templar II x6` twice: drones `[Hobgoblin II x5]`, fighters `[Templar II quantity 12]`; `generateEft` round-trips the same text.
- Snapshot mapper: `FighterBay` quantity 12 and `FighterTube0` quantity 6 of one type -> `FighterGroup(quantity: 18, inSpace: 6)`; `DroneBay` untouched.
- Killmail mapper: flags 158 and 161 -> bay and in-space; 87 still a drone.
- ESI export: `FighterBay` items with the carried quantity; modules unchanged; drop list unchanged.
- Saved fitting JSON without `fighters` loads with `[]`.

### 4.6 Widget (`fitting_stats_production_wiring_test.dart`)

- **T1.22** Seed the in-memory `AppDatabase` with an active character whose
  trained skills include Gunnery V and Rapid Firing V; the rendered DPS row
  strictly exceeds the untrained render of the same Tristan fit.
- **T2.24** Seed Thanatos (23911), Firbolg I (23059) and the Fighters skill
  (23069) from the bundle; render: `FIGHTERS` header, `Tubes 3/4`, `Bay
  18000/75000 m3`, `Light 3/3`, a `Fighters` DPS row; the Tristan case still
  renders `DRONES` rows and no `FIGHTERS` header.
- Bay over-capacity row uses `EveColors.error`.

---

## 5. Journal and spec updates (same change set, AGENTS.md rule)

1. LEARNINGS 2026-09-08 "modifierInfo stops at item boundaries": correct
   inline (skills were not bundled; most skill effects are published; the
   empty ones are 1851, 660/661/662/668, 1730), move the old text to
   ARCHIVE as SUPERSEDED. The generalisable rule "do not derive filters
   from adjacent attributes" stands.
2. Product spec: apply §0 C1..C10 (or mark superseded by this document).
3. DECISIONS: allowlist-plus-curated-supplement for skill effects; owner
   kind decides stacking penalty; fighter counts not squadron objects;
   infinite fighter reloads.
4. QUEUED: move both entries to ARCHIVE as SHIPPED when done; add
   follow-ups from §7.

---

## 6. Sequencing for the planner

- [SEQ] U0 Data: generator categories 16/87, regenerate assets, `dogma_version` gating, `getDogmaTypes`. Tests §4.4.
- [SEQ] U1 Engine core: six-slot filter, `_Bonus` buckets with penalty flag, `bonusScale`, `skillTypes` parameter with the fixture shim. Existing tests green unmodified.
- [P1] U2 Skill cycle bonuses: allowlist, curated 1851, provider `fittingSkillTypesProvider`. Tests §4.1, T1.20/T1.21/T1.26/T1.27.
- [P1] U3 Fighter models + parsers/mappers/export. Tests §4.5 (independent of the engine).
- [SEQ] U4 Fighter engine + allowlist additions + StatsPanel. Tests §4.2, §4.3 fighter rows, §4.6. Depends on U1..U3.
- [SEQ] U5 Journal, spec corrections, HANDOFF.

Reviewer prompts: check `containsKey` guards on hull fighter attributes,
that fighters never enter the `shipID` module loop, and that no skill
effect outside the allowlist changes any number (T1.24).

---

## 7. Out of scope, recorded for QUEUED

- Missile damage skills (660/661/662/668 empty) and drone damage skills
  (1730 empty): same curated-supplement mechanism, `charID`
  `OwnerRequiredSkillModifier` on 114/116/117/118 (charges) and 64 (drones)
  from 292, filter = owner skill. Turret damage skills are published and
  need only allowlisting.
- Retire the hardcoded `_skillModifiers` table in favour of the published
  effects (397, 394, ...) with an equivalence test.
- Bundle `dgmAttributeTypes.stackable` and penalise by attribute, not owner
  kind; add 37/70/76/552/564 to the ship-level non-stackable set.
- `SdeEffectModifiers` (Drift) lacks `skillTypeId`/`groupId`, so the
  ESI-fetch fallback strips filters. Harmless while everything is bundled.
- Fighter reloads (shot counts and rearm times are recorded in the ability
  table) join the queued cap clip-reload work.
- Fighter/drone editing UI in the fitting editor.
- pyfa or in-game spot check of one turret fit and one carrier fit (spec
  R5) remains the only external validation.

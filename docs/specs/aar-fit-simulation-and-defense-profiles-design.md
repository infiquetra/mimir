# AAR Fit Simulation & Defense Profile Derivation — Architecture and Technical Contracts

**Companion to.** `docs/specs/aar-fit-simulation-and-defense-profiles.md`
(the WHAT, Product, 2026-09-11). This document is the HOW: data models,
service contracts, exact formulas for the engine fixes, file layout, and the
test specifications the planner sequences and the test author writes
verbatim.

**Sources.** `lib/features/fitting/domain/dogma_engine.dart` (1,148 lines at
f1225a9), `lib/features/combat_analyzer/**` (enrichment, ledger, matchup,
resolver, screen, Codex client), `assets/sde/dogma.json` and
`assets/sde/effect_modifiers.json` (bundled SDE, probed 2026-09-11),
`scripts/sde` fuzzwork `dgmAttributeTypes.csv`, pyfa
`eos/modifiedAttributeDict.py` (attribute evaluation order) and
`eos/saveddata/fit.py` (`calculateEhp`, `calculateShieldRecharge`).

**Date.** 2026-09-11. **Author.** Architect session (Claude).

---

## 0. Evidence that changes the product spec — read first

The spec's §0 table says the dogma engine "already derives" shield/armor/hull
HP and resists. Probing the bundled SDE against the engine shows three
defects that sit **underneath** E1–E3 and make today's EHP wrong for every
buffer fit and every fit with a Damage Control. They are cheap, they are in
the same file E1/E2 touch, and the AAR is worthless without them. They are
added as **E0a/E0b/E0c** and go first.

| # | Spec claim | What the code and data say | Consequence |
|---|---|---|---|
| C1 | "Shield/armor/hull HP — Derived" (§0.1) | The engine supports operators 0/4 (multiply) and 6 (percent) only; operator **2 (`modAdd`)** is counted as `unsupportedOperators` and dropped (`dogma_engine.dart:341-345`, `494-500`). Shield extenders publish `effect 21: ItemModifier / op 2 / 263 <- 72 / shipID` (LSE II +2,600), armor plates `effect 2837: op 2 / 265 <- 1159` (1600mm II +4,800), plus the extender signature add (2029: `552 <- 983`) and plate mass add (1959: `4 <- 796`). **No extender or plate adds any HP today.** | **E0a** (§2.1). A 1600mm-plated Rifter reports 450 armor HP instead of 5,250. Highest-value fix in the milestone. |
| C2 | Hull resists derived (§0.1) | `DogmaAttributes.hull*Resist` are **974–977**, which are the Damage Control's *own* bonus attributes (`hullEmDamageResonance`, stackable=1). Ships carry hull resonances at **113 em / 110 thermal / 109 kinetic / 111 explosive** (`emDamageResonance` etc., stackable=0, value 0.67 on every hull probed). The DCU modifies 113/110/109/111 (effect 2302). Rifter happens to carry 974–977 = 1.0, so hull resist reads 0% and the DCU's 40% hull resist never applies. | **E0b** (§2.2). Rifter hull EHP is 350 today, 522.39 correct; with DCU II 870.65. |
| C3 | Known-skill derivation is trustworthy (R2.1) | `_skillModifiers` maps five of seven skill IDs to the wrong skill: 3418 is **Capacitor Management** (engine says CPU Management; CPU Management is 3426), 3402 is **Science** (engine: Engineering; Power Grid Management is 3413), 3455 is **Warp Drive Operation** (engine: Navigation, 3449), 3424 is **Energy Grid Upgrades** (engine: Capacitor Management), 3425 is **Shield Upgrades** (engine: Shield Management, 3419). Tests at `dogma_engine_test.dart:157,158,344` encode the wrong IDs. All-V is unaffected; the R2.1 known-skills path is wrong today. | **E0c** (§2.3). Fix IDs, and apply the table *after* modAdd (pyfa order) so extender HP receives Shield Management. |
| C4 | Matchup "fed by the already-working `CombatDamageProfileResolver` (incoming damage by type)" (W3) | The resolver has one method, `resolveOutgoingProfile`, which filters `event.isOutgoingDamage`. There is **no incoming profile**. The log parser captures `weaponName` for incoming lines too (`combat_log_parser.dart:216-225`), so the incoming variant is the same algorithm with the direction flipped. | Add `resolveIncomingProfile` (§4.3). Pilot defense is matched against **incoming**; opponent defense against **outgoing**. |
| C5 | S3 "rigs destroyed and unrecoverable" | Killmails list rigs (destroyed and dropped, flags 92–99, already mapped by `CombatKillmailFitMapper`). What a killmail lacks is module **state** (online/active, assumed active), pilot **skills**, boosters, and implants. Partial fits come from manual EFT imports and unresolvable type IDs, not from killmail rigs. | Coverage is reported as fitted-vs-hull-slots plus unresolved IDs (§3.3); the "floor" wording applies to unresolved modules, not rigs. |
| C6 | AC2.4 "percentages sum to 100%" | `CombatDamageTypeEstimate.percent` is a **fraction** (0..1); the UI multiplies by 100 (`_formatPercent`). | Tests assert `sum == 1.0 ± 1e-6`. |
| C7 | S1: Thermal 34.8% flagged `resistHole` | Assessment is absolute today (`<= 20` hole, `>= 60` strong); 34.8 is `neutral`. AC2.3 ("lowest-resist type carrying material damage") needs a relative rule. | Relative rule with absolute floor (§3.4). The existing matchup test still passes. |
| C8 | `effectiveShieldBoost`/`effectiveArmorRepair` "never set" — units unstated | Defined here as **HP/s, single-cycle burst**, no reload, no overheat, summed over active modules of the layer; ancillary armor repairers multiply by 1886 only when Nanite Repair Paste (28668) is loaded. Hull repairers exist too (attr 83, effect 26). | E2 (§2.5) adds `effectiveHullRepair` and `peakShieldRecharge`. |
| C9 | AC1.5/T1.7 "pure and synchronous" | `DogmaEngine.calculateStats` is `async` (returns a Future) but performs no I/O. | Contract: *pure* (no DB, no network, deterministic); tests `await` with hand-built types and no database. |
| C10 | `AarUnknown`/`CombatEvidenceFact` can express skill assumptions and derived sources | `EvidenceSource` has no derived value; `AarUnknownCategory` has no skills category. | Add `EvidenceSource.dogmaDerivation` and `AarUnknownCategory.skills` (additive; `fromJson` fallbacks unchanged). |
| C11 | T8.4 fighters reach the prompt | `FitEvidence.toPromptJson` omits `fighters`. | Add `fighters` (one line). |
| C12 | Per-fit derivation is one engine call | Tank classification needs a **bare-hull baseline** with the same skills to measure buffer investment (§3.2). | Two engine calls per fit (both pure, milliseconds). |

Everything else in the spec (R1–R5, S1–S7, sequencing, journal protocol)
stands. The spec's acceptance IDs are kept below wherever they survive;
corrected or added cases are marked.

---

## 1. Architecture

```
FitEvidence (pilot | victim)          ParsedCombatEncounter
        │                                     │
        ▼                                     ▼
CombatFitDerivationService (data)     CombatDamageProfileResolver (data)
  resolve ShipType + types (SDE)        resolveIncomingProfile / Outgoing
  resolve skills: pilot (ESI cache) or All V
        │                                     │
        ▼                                     │
CombatFitDeriver (domain, pure) ──► AarFitDerivation ◄─────────┘
  DogmaEngine.calculateStats ×2            │            CombatDamageMatchupAnalyzer
  TankClassifier                           │              (profile EHP, relative holes)
  AarFitCoverage                           ▼
                              AarDerivationBundle {pilot?, opponent?, matchups, unknowns}
                                     │                 │
             AarDerivedFactsBuilder  │                 │  aarFitDerivationsProvider
                                     ▼                 ▼
                    CombatEvidenceLedger (persisted)   AarDerivedStatsPanel / AarMatchupSection
                    Codex prompt v4 (derivedFits, damageMatchups)
```

Decisions (spec §7):

- **D1 — where the service lives.** Split. `combat_analyzer/domain/combat_fit_deriver.dart` is pure (types injected). `combat_analyzer/data/combat_fit_derivation_service.dart` resolves SDE and skills and calls the deriver. The type-resolution code is **extracted from `fittingStatsProvider`** into a shared loader (§4.1) so the AAR and the fitting screen feed the engine identical inputs — that is how R1.4 "one engine, one answer" is made structural, not aspirational.
- **D2 — dual-tank rule.** Active beats buffer; among active layers the highest raw HP/s wins; among buffer layers the largest **module-added omni EHP** wins (measured against a bare-hull baseline). Ties resolve by larger layer EHP, then by fixed order. Full rule in §3.2.
- **D3 — summary EHP.** `DefenseProfile.totalEhp` stays omni and is documented as such; profile-weighted EHP is a separate value carrying its `DamagePattern`. The StatsPanel row is unchanged (AC2.2).
- **Persistence.** Derived **facts and unknowns** are merged into the enrichment ledger and saved (they are what the LLM saw). The structured derivation is **not** persisted; the UI recomputes it live through a provider so it always reflects the current engine. Fact IDs are deterministic (§3.6) so re-derivation replaces rather than duplicates.

---

## 2. Engine corrections (`lib/features/fitting/domain`)

All changes are in `dogma_engine.dart`, `dogma_attributes.dart`, `models.dart`
and one new file `damage_pattern.dart`. Existing tests must pass unchanged
except the three wrong-ID assertions named in E0c.

### 2.1 E0a — operator 2/3 (`modAdd`/`modSub`) on ship attributes

**Evaluation order (pyfa `ModifiedAttributeDict.__calculateValue`, dogma):**

```
value(attr) = (base + Σ adds) × Π(multipliers, op 0/4) × chain(percents, op 6)
```

Adds are applied before every multiplier and percent. The engine today
computes `base × Πmul × chain(pct)` and pre-multiplies `base` by the
`_skillModifiers` table; both must change.

Contract:

```dart
static const int _modAdd = 2;
static const int _modSub = 3;

final addModifiers = <int, double>{};            // ship attributes only

// routeOwnerModifiers, branch `ItemModifier && domain == 'shipID'`:
if (modifier.operator == _modAdd)      addModifiers[id] = (addModifiers[id] ?? 0) + value;
else if (modifier.operator == _modSub) addModifiers[id] = (addModifiers[id] ?? 0) - value;
else if (_isMul(op)) ... // unchanged
else if (op == _postPercent) ... // unchanged

// routeLocationModifier: only the ship-side branch
// (`shipType.baseAttributes.containsKey(modifiedAttributeId)`) accepts op 2/3
// the same way. Module-side targets keep counting op 2/3 as unsupported
// (no fitted-module add modifiers exist in the bundle for ship modules).

// Finalisation (replaces the two forEach blocks at 702-720):
final touched = {...addModifiers.keys, ...mulModifiers.keys, ...percentModifiers.keys};
for (final id in touched) {
  final hasBase = attributes.containsKey(id);
  final base = hasBase ? attributes[id]! : (addModifiers.containsKey(id) ? 0.0 : 1.0);
  var v = base + (addModifiers[id] ?? 0.0);
  for (final m in mulModifiers[id] ?? const []) v *= m;
  v *= _percentChain(id, percentModifiers[id] ?? const []);   // existing sorted/penalised loop
  attributes[id] = v;
}
```

`value` for adds is `base × scale` exactly as for the other operators
(`scale` = bonusScale / legacy ship-skill level for ship-owned modifiers,
1.0 for module-owned). The phantom-attribute behaviour for mul/percent-only
attributes (base 1.0) is preserved; an add-only attribute starts at 0.

`_skillModifiers` no longer multiplies `attributes[attributeId]` up front
(lines 229-234). It appends to `percentModifiers`:

```dart
for (final (skillId, attributeId, perLevel) in _skillModifiers) {
  final level = skillLevels[skillId] ?? 0;
  if (level == 0 || !shipType.baseAttributes.containsKey(attributeId)) continue;
  addTo(percentModifiers, attributeId, perLevel * level * 100);   // +25 at V
}
```

Numerically identical to today when no adds exist (a single percent on a
stackable attribute is a plain multiply), so the existing skill tests keep
their values. With adds it yields the game's order:

| Fit (no other skills) | Today | E0a | Check |
|---|---|---|---|
| Rifter + MSE II | shield 450 | 450 + 1,100 = **1,550**; sig 35 + 7 = **42 m** | |
| Rifter + MSE II + Shield Management V | 562.5 | (450 + 1,100) × 1.25 = **1,937.5** | pre-add order would give 1,662.5 — the discriminating assertion |
| Rifter + 1600mm Steel Plates II | armor 450 | 450 + 4,800 = **5,250**; mass 1,067,000 + 3,750,000 = 4,817,000 kg; align −ln(0.25)×3.2×4.817 = **21.37 s** (base 4.73 s) | |
| Rifter + 2× MSE II | 450 | **2,650**; sig **49 m** | |

### 2.2 E0b — hull resonance attribute IDs

```dart
// dogma_attributes.dart
static const int hullEmResist = 113;        // emDamageResonance (was 974)
static const int hullThermalResist = 110;   // thermalDamageResonance (was 977)
static const int hullKineticResist = 109;   // kineticDamageResonance (was 976)
static const int hullExplosiveResist = 111; // explosiveDamageResonance (was 975)
```

`_nonStackableAttributes` follows the constants (113/110/109/111 are
stackable=0 in `dgmAttributeTypes`; 974–977 are stackable=1 and never
modified). Damage Control II's effect 2302 then lands on the hull:

| Rifter (no skills) | shield EHP | armor EHP | hull EHP | total |
|---|---|---|---|---|
| bare, today | 620.69 | 666.67 | 350.00 | 1,637.36 |
| bare, E0b | 620.69 | 666.67 | 350/0.67 = **522.39** | **1,809.74** |
| + Damage Control II | 450/0.634375 = 709.36 | 450/0.57375 = 784.31 | 350/(0.67×0.6) = **870.65** | 2,364.32 |

(Shield mean resonance with DCU: (0.875+0.7+0.525+0.4375)/4 = 0.634375; armor
(0.34+0.5525+0.6375+0.765)/4 = 0.57375.)

### 2.3 E0c — `_skillModifiers` skill IDs

```dart
static const List<(int, int, double)> _skillModifiers = [
  (3426, DogmaAttributes.cpuOutput, 0.05),          // CPU Management (was 3418)
  (3413, DogmaAttributes.powerOutput, 0.05),        // Power Grid Management (was 3402)
  (3449, DogmaAttributes.maxVelocity, 0.05),        // Navigation (was 3455)
  (3418, DogmaAttributes.capacitorCapacity, 0.05),  // Capacitor Management (was 3424)
  (3419, DogmaAttributes.shieldCapacity, 0.05),     // Shield Management (was 3425)
  (3394, DogmaAttributes.armorHp, 0.05),            // Hull Upgrades (unchanged)
  (3392, DogmaAttributes.hullHp, 0.05),             // Mechanics (unchanged)
  (3416, DogmaAttributes.shieldRechargeTime, -0.05),// Shield Operation (new; feeds peak recharge)
];
```

Verified against the bundle: each skill's published ship effect is
`ItemModifier / op 6 / shipID` on exactly that attribute (446 → 263,
490 → 11, 394 → 37, 2432 → 482, 397 → 48, 271 → 265, 392 → 9, 486 → 479).
Those effect IDs are **deliberately not** added to `skillEffectAllowlist`:
with `skillTypes` supplied they would double-apply on top of the table.
Retiring the table in favour of routing (QUEUED P3) stays queued.

One skill effect **is** added to the allowlist because it targets modules,
which the table cannot express: **272 Repair Systems**
(`LocationRequiredSkillModifier / op 6 / 73 <- 312 / shipID / filter 3393`,
−5%/level repairer duration). It is exactly the Rapid Firing shape and
routes through the existing skill loop with no new code.

Test edits (the only existing assertions that change):
`dogma_engine_test.dart:157` 3418 → 3426, `:158` 3455 → 3449, `:344` 3425 →
3419. Values are unchanged.

### 2.4 E1 — EHP against a damage pattern

New file `lib/features/fitting/domain/damage_pattern.dart`:

```dart
/// Incoming damage split. Fractions are normalised to sum to 1.
@freezed
abstract class DamagePattern with _$DamagePattern {
  const DamagePattern._();
  const factory DamagePattern({
    required double em, required double thermal,
    required double kinetic, required double explosive,
    @Default('omni') String label,
  }) = _DamagePattern;

  static const omni = DamagePattern(em: .25, thermal: .25, kinetic: .25, explosive: .25);

  /// Normalises raw amounts; returns null when the total is 0.
  static DamagePattern? fromAmounts({required double em, required double thermal,
      required double kinetic, required double explosive, String label = 'observed'});
}

@freezed
abstract class LayeredEhp with _$LayeredEhp {
  const factory LayeredEhp({
    required DamagePattern pattern,
    required double shield, required double armor, required double hull,
  }) = _LayeredEhp;
  double get total => shield + armor + hull;
}

extension DefenseProfileEhp on DefenseProfile {
  /// pyfa `calculateEhp`: hp / Σ_t p_t · resonance_t, per layer.
  LayeredEhp ehpAgainst(DamagePattern p) => LayeredEhp(
    pattern: p,
    shield: _layer(shieldHp, shieldResists, p),
    armor: _layer(armorHp, armorResists, p),
    hull: _layer(hullHp, hullResists, p),
  );
}

double _layer(double hp, ResistProfile r, DamagePattern p) {
  final denom = p.em * (1 - r.em / 100) + p.thermal * (1 - r.thermal / 100)
      + p.kinetic * (1 - r.kinetic / 100) + p.explosive * (1 - r.explosive / 100);
  return denom <= 0 ? hp : hp / denom;   // 100% resist everywhere: report raw hp, never ∞
}
```

The engine's `calculateEhp` (lines 776-781) is deleted; `DefenseProfile`
EHP fields are filled from `ehpAgainst(DamagePattern.omni)` so there is one
formula. With `p = 0.25` each, `Σ p_t(1 − r_t) = 1 − mean(r)`, i.e. the
current flat-average value exactly (AC2.2, T3.3). `DefenseProfile`'s doc
comment states: *`shieldEhp/armorEhp/hullEhp/totalEhp` are omni
(25/25/25/25); use `ehpAgainst` for any other pattern.*

Worked values (1,000 HP layer):

| Resists EM/Th/Kin/Exp | Pattern | Σ p(1−r) | EHP |
|---|---|---|---|
| 0/50/50/50 | 100% EM | 1.000 | **1,000.00** (T3.1) |
| 0/50/50/50 | 100% Exp | 0.500 | **2,000.00** (T3.2) |
| 0/50/50/50 | omni | 0.625 | **1,600.00** = 1000/(1−0.375) (T3.3) |
| 0/20/40/50 | 3% EM / 19% Th / 78% Kin | 0.03 + 0.152 + 0.468 = 0.650 | **1,538.46** (T3.4) |
| 0/20/40/50 | omni | 0.725 | 1,379.31 |
| 0/0/0/0 | any | 1.000 | 1,000.00 (T3.5) |

### 2.5 E2 — active repair on `DefenseProfile`

`models.dart`:

```dart
@Default(0.0) double effectiveShieldBoost,   // HP/s, burst, sum of active shield boosters
@Default(0.0) double effectiveArmorRepair,   // HP/s, burst, sum of active armor repairers
@Default(0.0) double effectiveHullRepair,    // HP/s, burst, sum of active hull repairers (new)
@Default(0.0) double peakShieldRecharge,     // HP/s, passive: 2.5 × shieldHp / (rechargeMs/1000) (new)
```

`dogma_attributes.dart` additions: `armorRepairAmount = 84`,
`shieldBoostAmount = 68`, `hullRepairAmount = 83`,
`chargedArmorDamageMultiplier = 1886`, `naniteRepairPasteTypeId = 28668`,
`shieldCapacityBonusAdd = 72`, `armorHpBonusAdd = 1159`,
`signatureRadiusAdd = 983`, `massAddition = 796`.

Engine, inside the existing module loop (after `cycleMs`, which already
includes `reactivationDelay` for ancillaries, so use the raw duration for the
burst figure):

```dart
static const Set<int> _armorRepairEffects = {27, 5275};   // armorRepair, fueledArmorRepair
static const Set<int> _shieldBoostEffects = {4, 4936};    // shieldBoosting, fueledShieldBoosting
static const Set<int> _hullRepairEffects = {26};          // structureRepair

final durationMs = moduleAttr(type, DogmaAttributes.duration);   // bonused (hull 5342, skill 272)
if (durationMs > 0) {
  final effectIds = type.effects.map((e) => e.effectId).toSet();
  if (effectIds.any(_armorRepairEffects.contains)) {
    var amount = moduleAttr(type, DogmaAttributes.armorRepairAmount);      // bonused
    if (module.chargeTypeId == DogmaAttributes.naniteRepairPasteTypeId &&
        type.baseAttributes.containsKey(DogmaAttributes.chargedArmorDamageMultiplier)) {
      amount *= moduleAttr(type, DogmaAttributes.chargedArmorDamageMultiplier);
    }
    armorRepairHps += amount / (durationMs / 1000);
  } else if (effectIds.any(_shieldBoostEffects.contains)) {
    shieldBoostHps += moduleAttr(type, DogmaAttributes.shieldBoostAmount) / (durationMs / 1000);
  } else if (effectIds.any(_hullRepairEffects.contains)) {
    hullRepairHps += moduleAttr(type, DogmaAttributes.hullRepairAmount) / (durationMs / 1000);
  }
}
```

Offline modules are already skipped at the top of the loop (T5.7). Overheat
(effects 3200/3201, `itemID` domain) and ancillary reload/clip are **not**
modelled (QUEUED P3); the fact's limitations say so.

`peakShieldRecharge = shieldRecharge > 0 ? 2.5 * shieldHp / (shieldRecharge / 1000) : 0`
(pyfa `calculateShieldRecharge` at 25%: `10/T × √.25 × (1−√.25) × C`).

Worked values (no skills):

| Module | amount | duration | HP/s |
|---|---|---|---|
| Large Armor Repairer II (3540) | 920 | 15,000 ms | **61.333** |
| same on Myrmidon, Gallente Battlecruiser V (5342: +7.5%/lvl on 84, filter 3393) | 920 × 1.375 = 1,265 | 15,000 | **84.333** |
| same + Repair Systems V (272: −25% duration) | 1,265 | 11,250 | **112.444** |
| Medium Shield Booster II (10850) | 104 | 3,000 | **34.667** |
| Small Ancillary Armor Repairer (33076) + Nanite Repair Paste | 52 × 3 = 156 | 6,000 | **26.000** (8.667 unloaded) |
| Small Hull Repairer II (2355) | 30 | 24,000 | **1.250** |
| Rifter passive peak | 2.5 × 450 / 625 s | | **1.800** |
| Myrmidon passive peak | 2.5 × 3,500 / 1,400 s | | **6.250** |

### 2.6 E3 — tank layer classification

Lives in the combat analyzer (§3.2); the engine only supplies the inputs
above. `CombatDamageMatchupAnalyzer._primaryLayer` (raw HP) stays as the
fallback when no `TankAssessment` is passed, so the existing test is
untouched.

---

## 3. Domain contracts (`lib/features/combat_analyzer/domain`)

The combat analyzer uses plain immutable classes with `toJson`/`fromJson`,
not freezed; new domain types follow that convention.

### 3.1 `aar_fit_derivation.dart`

```dart
enum AarFitSubject { self, opponent }      // whose ship this is, from the pilot's view
enum AarSkillBasis { knownCharacter, allFive }

class AarSkillContext {
  const AarSkillContext({required this.basis, required this.skills, this.characterId});
  final AarSkillBasis basis;
  final List<CharacterSkill> skills;       // knownCharacter: ESI cache; allFive: every category-16 skill at 5
  final int? characterId;
  String get label => switch (basis) {
    AarSkillBasis.knownCharacter => 'Character skills (ESI, character $characterId)',
    AarSkillBasis.allFive => 'assumes All V',
  };
  EvidenceConfidence get confidence => switch (basis) {
    AarSkillBasis.knownCharacter => EvidenceConfidence.derived,
    AarSkillBasis.allFive => EvidenceConfidence.reference,   // strictly lower (AC1.8)
  };
}

class AarFitCoverage {
  const AarFitCoverage({required this.highFitted, required this.highSlots, /* med, low, rig, subsystem */
      required this.unresolvedTypeIds, required this.unresolvedNames});
  bool get hasUnresolved => unresolvedTypeIds.isNotEmpty;
  String describe();   // "High 3/3, Mid 1/3, Low 2/3, Rig 0/3; 1 module not in SDE (Type #99999)"
  static AarFitCoverage of(Fitting fitting, ShipType ship, Map<int, String> unresolved);
}

class AarFitDerivation {
  final FitEvidenceRole role;
  final AarFitSubject subject;
  final EvidenceSource fitSource;          // copied from FitEvidence
  final int shipTypeId; final String shipName;
  final AarSkillContext skills;
  final FittingStats stats;                // omni EHP, resists, cap, DPS, mobility
  final FittingStats baseline;             // bare hull, same skills
  final TankAssessment tank;
  final AarFitCoverage coverage;
  final DateTime derivedAt;
  final List<String> limitations;          // skill label, "module states assumed active", coverage, unmodelled items
  Map<String, dynamic> toPromptJson();     // §5.3
}

sealed class AarFitDerivationResult {}
class AarFitDerived extends AarFitDerivationResult { final AarFitDerivation derivation; }
class AarFitDerivationFailed extends AarFitDerivationResult { final AarUnknown unknown; final String reason; }

class AarDerivationBundle {
  final AarFitDerivation? self;            // pilot's ship (pilot evidence, or victim evidence when pilot was the victim)
  final AarFitDerivation? opponent;        // victim evidence when the pilot won
  final CombatDamageMatchup? selfMatchup;  // incoming profile vs self defense
  final CombatDamageMatchup? opponentMatchup; // outgoing profile vs opponent defense
  final List<AarUnknown> unknowns;
  bool get isEmpty => self == null && opponent == null;
}
```

Subject resolution (service, §4.2): `pilotFitEvidence` → `self`;
`victimFitEvidence` → `self` when `enrichment.victimCharacterId ==
encounter.characterId`, else `opponent`. When both pilot evidence and a
self-victim killmail exist, the pilot evidence wins for `self` and the
killmail derivation is dropped with a limitation (one self panel, S7 stays
two panels only when the roles differ).

### 3.2 `tank_classifier.dart`

```dart
enum TankLayer { shield, armor, hull, unknown }
enum TankMode { active, buffer, unfitted }

class TankAssessment {
  final TankLayer layer; final TankMode mode;
  final double shieldBoostHps, armorRepairHps, hullRepairHps;      // from DefenseProfile
  final double shieldGainEhp, armorGainEhp, hullGainEhp;           // fit omni EHP − baseline omni EHP
  final String reasoning;
  String get label => '${layer.name[0].toUpperCase()}${layer.name.substring(1)} (${mode.name})';
}

class TankClassifier {
  static const double _minGainEhp = 0.5;
  static TankAssessment classify({required FittingStats fit, required FittingStats baseline});
}
```

Rule (R4.2, deterministic and documented):

1. `active = {shield: effectiveShieldBoost, armor: effectiveArmorRepair, hull: effectiveHullRepair}`.
   If `max(active) > 0`: `layer = argmax(active)`, `mode = active`. Ties (equal
   HP/s): larger omni layer EHP, then fixed order **armor, shield, hull**.
2. Else `gain[L] = fit.defenses.<L>Ehp − baseline.defenses.<L>Ehp` (omni).
   If `max(gain) > 0.5`: `layer = argmax(gain)`, `mode = buffer`. Ties: larger
   layer EHP, then **shield, armor, hull**.
3. Else `layer = argmax(fit.defenses.<L>Ehp)`, `mode = unfitted`; ties
   **shield, armor, hull**.
4. If the fit has no positive HP on any layer: `layer = unknown`, `mode = unfitted`.

`reasoning` is a single sentence naming the winning quantity and the
runners-up, e.g. *"Armor (active): 61.3 HP/s armor repair vs 0.0 shield
boost, 0.0 hull repair; buffer gains shield +3,586 / armor +0 / hull +0
EHP."* It is the value of the tank fact (AC2.10).

Why gain-based rather than raw HP: a bulkhead-only Rifter (hull 350 × 1.25 =
437.5 HP) never beats its 450-HP shield by raw HP, yet the pilot invested in
hull. Known edge: a fit whose only tank module is a Damage Control
classifies **hull (buffer)** because the DCU's 60% hull resist is its
largest absolute EHP gain (Rifter: +348 hull vs +118 armor vs +89 shield).
The reasoning string makes this legible; T5.9 locks it.

Worked classifications (no skills):

| Fit | active HP/s | gains (S/A/H EHP) | Result |
|---|---|---|---|
| Myrmidon + LAR II + LSE II | A 61.33 | 3,586 / 0 / 0 | **Armor (active)** (T5.1) |
| Rifter + 2× MSE II | — | 3,034.5 / 0 / 0 | **Shield (buffer)** (T5.2) |
| Rifter + Small Shield Booster II | S 17.5 | 0 / 0 / 0 | **Shield (active)** (T5.3) |
| Myrmidon + LAR II + MSB II | A 61.33, S 34.67 | — | **Armor (active)** (T5.4) |
| Rifter + Reinforced Bulkheads II | — | 0 / 0 / 130.6 | **Hull (buffer)** (T5.5) |
| Rifter bare | — | 0 / 0 / 0 | **Armor (unfitted)** (armor 666.67 > shield 620.69) (T1.4) |
| Rifter + DCU II | — | 88.7 / 117.6 / 348.3 | **Hull (buffer)** (T5.9, documented edge) |

### 3.3 `combat_fit_deriver.dart` (pure)

```dart
class CombatFitDeriver {
  const CombatFitDeriver({DogmaEngine? engine});

  /// Pure: no I/O. Runs the engine on the evidence fit and on a bare hull with
  /// the same skills, classifies the tank, and reports coverage.
  Future<AarFitDerivation> derive({
    required FitEvidence evidence,
    required AarFitSubject subject,
    required FittingStatsInputs inputs,        // §4.1
    required AarSkillContext skills,
    DateTime? now,
  });
}
```

Steps: `stats = engine.calculateStats(fitting, inputs.shipType,
inputs.moduleTypes, skills.skills, effectModifiers: inputs.effectModifiers,
skillTypes: inputs.skillTypes)`; `baseline` = same call with
`Fitting(id: '${id}-baseline', name: 'baseline', shipTypeId, shipName)`;
`tank = TankClassifier.classify(fit: stats, baseline: baseline)`;
`coverage = AarFitCoverage.of(fitting, shipType, inputs.unresolved)`.
Limitations always include the skill label and *"Module states from
evidence are assumed active"*; add *"N modules not in the SDE were ignored;
EHP and DPS are a floor"* when `coverage.hasUnresolved`, and *"Ancillary
reload, overheat and clip reloads are not modelled"* when any ancillary
repairer or booster is fitted. Log `[AAR.DERIVE]` at `d` on entry (role,
subject, ship, skill basis, module count) and `i` with EHP/DPS/tank on exit.

### 3.4 `combat_damage_matchup.dart` changes

```dart
class CombatDamageMatchupAnalyzer {
  static CombatDamageMatchup analyze({
    required CombatDamageProfile profile,
    required DefenseProfile? defense,        // null → every entry `unknown`, resistPercent null (T4.4)
    TankAssessment? tank,                    // layer from R4; fallback: existing raw-HP _primaryLayer
    required String targetLabel,
  });
}

class CombatDamageMatchupEntry {
  final String type; final int amount;
  final double percent;                      // fraction of resolved incoming damage (unchanged)
  final double? resistPercent;               // null when no defense evidence
  final double? appliedPercent;              // fraction of post-resist damage: p_t(1−r_t) / Σ p_u(1−r_u)
  final DamageMatchupAssessment assessment;
  final String evidence;
}

class CombatDamageMatchup {
  final String targetLabel; final String layer; final String summary;
  final List<CombatDamageMatchupEntry> entries;
  final DamagePattern? pattern;              // built from the profile (null when no entries)
  final LayeredEhp? ehpAgainstPattern;       // defense.ehpAgainst(pattern)
  final LayeredEhp? ehpOmni;                 // defense.ehpAgainst(DamagePattern.omni)
  final String? primaryHole;                 // entry type with the largest appliedPercent among resistHole entries
}
```

Assessment rule (C7), with `mean` = arithmetic mean of the four resists of
the chosen layer:

```
resistHole   if resist <= 20 || resist <= mean − 5
strongResist if resist >= mean + 5
neutral      otherwise
unknown      when defense is null or the layer is unknown
```

Checks: existing test (shield 0/20/70/10, mean 25): Kinetic 70 → strong,
Explosive 10 → hole ✓. T4.1 (10/60/60/60, mean 47.5): EM hole, others
strong. T4.3 (flat): all neutral. S1 (52.4/34.8/63.1/71.2, mean 55.375):
Thermal hole, Kinetic and Explosive strong, EM neutral; applied shares for
3/19/78%: EM 3.4%, Thermal 29.1%, Kinetic 67.6% → `primaryHole = Thermal`.

`DamagePattern` from a profile (`combat_analyzer/domain/damage_pattern_x.dart`):
`DamagePattern.fromAmounts(em: amountOf('EM'), thermal: amountOf('Thermal'),
kinetic: amountOf('Kinetic'), explosive: amountOf('Explosive'), label:
'observed incoming')` over `profile.entries` only — unknown weapons are
already excluded upstream (R3.4).

JSON: `resistPercent`/`appliedPercent` serialise as `null` when absent;
`fromJson` accepts missing keys (older persisted matchups, if any, still
load).

### 3.5 `combat_evidence_ledger.dart` additions

```dart
enum EvidenceSource { combatLog, killmail, zkill, sde, currentShipSnapshot, manualFitImport, dogmaDerivation }
enum AarUnknownCategory { pilotFit, opponentFit, range, pilotingIntent, tankLayer, fleetContext, telemetry, skills }
// FitEvidence.toPromptJson: add 'fighters': fitting.fighters.map((f) => f.toJson()).toList()
```

No exhaustive `switch` over these enums exists in `lib/` (checked), so the
additions are non-breaking.

### 3.6 `aar_derived_facts.dart`

```dart
class AarDerivedFactsBuilder {
  static List<CombatEvidenceFact> facts(AarFitDerivation d, {required String encounterId, CombatDamageMatchup? matchup});
  static List<AarUnknown> unknownsFor(AarDerivationBundle bundle, {required bool hasPilotEvidence, required bool hasOpponentEvidence, required CombatDamageProfile incoming});
}
```

Fact IDs are deterministic: `ev-derived-<subject>-<key>-<encounterId>` with
`subject ∈ {self, opponent}`. Every fact: `source = dogmaDerivation`,
`confidence = d.skills.confidence`, `evidenceTime = d.derivedAt`,
`limitations = d.limitations`.

| key | label | value (format) |
|---|---|---|
| `skills` | Skill assumption | `d.skills.label` (R2.4) |
| `ehp-omni` | Derived EHP (omni 25/25/25/25) | `12,345 EHP (shield 1,234 / armor 5,678 / hull 890)` |
| `resists-<layer>` (×3) | Derived shield/armor/hull resists | `EM 52.4% / Th 34.8% / Kin 63.1% / Exp 71.2%; 4,500 HP` |
| `tank` | Derived tank layer | `tank.reasoning` (AC2.10) |
| `repair` | Derived active repair | `armor 84.3 HP/s, shield 0.0 HP/s, hull 0.0 HP/s; passive shield 6.3 HP/s` |
| `cap` | Derived capacitor | `Stable at 41%` / `Unstable: empty in 47 s` / `Not modelled (no capacitor attributes)` |
| `dps` | Derived DPS | `312.4 DPS (guns 210.0 / missiles 0.0 / drones 102.4 / fighters 0.0); volley 890` |
| `mobility` | Derived speed and signature | `1,234 m/s; sig 42 m; align 4.7 s` |
| `coverage` | Fit coverage | `coverage.describe()` |
| `matchup` | Damage matchup (self: incoming; opponent: outgoing) | `Kinetic 78% vs 63.1% (strong), Thermal 19% vs 34.8% (hole), EM 3% vs 52.4% (neutral); EHP vs this profile 8,412 (omni 8,910); primary hole Thermal` |

Unknowns (R5.4), each naming the missing quantity and the unlocking evidence:

| condition | category | label | detail |
|---|---|---|---|
| no pilot evidence | pilotFit | (existing baseline unknown kept) | |
| no opponent evidence | opponentFit | Opponent defense profile | `No opponent fit evidence: resists, EHP and tank layer cannot be derived. A matched killmail of the opponent's loss or a manual fit import resolves it.` |
| ship unresolved | pilotFit / opponentFit | Ship type not in SDE | `Ship type #N is not in the bundled SDE; no stats derived. Updating the SDE bundle resolves it.` |
| unresolved modules | same as role | Modules not in SDE | `N modules not in the bundled SDE (names/ids); derived EHP and DPS are a floor.` |
| All V basis | skills | Pilot skills / Opponent skills | `Skills unknown; derived figures assume All V and are an upper bound. ESI skill data for the character resolves it.` |
| incoming unknown weapons | telemetry | Unresolved incoming weapons | `Incoming damage from <names> could not be typed and is excluded from the matchup.` |

---

## 4. Data layer (`lib/features/fitting/data`, `lib/features/combat_analyzer/data`)

### 4.1 Shared loader — `lib/features/fitting/data/fitting_stats_inputs.dart`

```dart
class FittingStatsInputs {
  final ShipType shipType;
  final Map<String, ModuleType> moduleTypes;   // modules, charges, drones, fighters, fighter bombs
  final Map<int, ModuleType> skillTypes;       // requested skill ids ∪ ship required skills
  final Map<int, List<EffectModifier>> effectModifiers;
  final Map<int, String> unresolved;           // typeId → display name from the Fitting, absent from SDE
}

/// Extracted verbatim from fittingStatsProvider (lines 316-405). Returns null
/// only when the ship type is unresolvable.
Future<FittingStatsInputs?> loadFittingStatsInputs(
  SdeService sde, Fitting fitting, {required Iterable<int> skillTypeIds, ShipType? shipType});
```

`fittingStatsProvider` becomes: resolve trained skills → `loadFittingStatsInputs(sde, fitting, skillTypeIds: trained>0)` → `engine.calculateStats(...)`. `fittingSkillTypesProvider` is folded in. Identical output by construction (T1.2, T9.4).

`SdeService.getDogmaTypes` is extended to populate `cpu` (attr 50),
`powergrid` (30), `calibration` (1153) and `slotType` (effects
12/13/11/2663/3772) from the rows it already loads, so the loader can use one
batch call instead of N `getModuleType` round-trips. `groupName` and
`skillRequirements` stay empty (unused by the engine). The
production-wiring test (AC5.1) proves the values match.

### 4.2 `combat_fit_derivation_service.dart`

```dart
final combatFitDerivationServiceProvider = Provider<CombatFitDerivationService>(...);

class CombatFitDerivationService {
  CombatFitDerivationService({required SdeService sde, required SkillRepository skills,
      CombatFitDeriver deriver = const CombatFitDeriver()});

  Future<AarDerivationBundle> deriveForEncounter({
    required ParsedCombatEncounter encounter,
    required CombatEnrichment enrichment,
    required CombatDamageProfile incoming,
    required CombatDamageProfile outgoing,
  });

  Future<AarFitDerivationResult> deriveEvidence(FitEvidence evidence, {required AarFitSubject subject, required AarSkillContext skills});
  Future<AarSkillContext> skillContextFor({required AarFitSubject subject, int? characterId});
}
```

`skillContextFor`: `subject == self && characterId != null` → `skills.getCharacterSkills(characterId)` (returns the **Drift row class**, also named `CharacterSkill`; import `app_database.dart` with a prefix and map `skillId`/`trainedSkillLevel` to the fitting model's `CharacterSkill(skillId, level)`, exactly as `fittingStatsProvider` does); non-empty → `knownCharacter`. Otherwise `allFive`: `sde.database.getAllSkills()` mapped to `CharacterSkill(level: 5)`, cached in the service for the process lifetime (static per SDE version; 511 ids, two `getDogmaTypes` chunks). `deriveEvidence`: `loadFittingStatsInputs(sde, evidence.fitting, skillTypeIds: context.skills.map(id))` → null ship → `AarFitDerivationFailed` with the ship unknown; else `deriver.derive(...)`. Never throws for data gaps (R1.3); exceptions from the engine are caught, logged at `e` with stack, and reported as `AarFitDerivationFailed(reason: 'engine error')`.

`deriveForEncounter` builds the bundle: subjects per §3.1; `selfMatchup =
analyze(profile: incoming, defense: self?.stats.defenses, tank: self?.tank,
targetLabel: encounter.characterName)`; `opponentMatchup` uses `outgoing`
and `enrichment.victimName ?? 'Opponent'`; `unknowns =
AarDerivedFactsBuilder.unknownsFor(...)`.

### 4.3 `combat_damage_profile_resolver.dart`

```dart
Future<CombatDamageProfile> resolveOutgoingProfile(ParsedCombatEncounter e) => _resolve(e, incoming: false);
Future<CombatDamageProfile> resolveIncomingProfile(ParsedCombatEncounter e) => _resolve(e, incoming: true);
final combatIncomingDamageProfileProvider = FutureProvider.family<CombatDamageProfile, ParsedCombatEncounter>(...);
```

`_resolve` is the existing body with the event filter parameterised
(`isIncomingDamage` vs `isOutgoingDamage`). Unknown weapons are collected
per direction (R3.4).

### 4.4 `combat_enrichment_service.dart`

```dart
Future<CombatEnrichment> attachDerivedEvidence(CombatEnrichment enrichment, AarDerivationBundle bundle, {required String encounterId});
```

Merges `AarDerivedFactsBuilder.facts(...)` for `self` and `opponent` and
`bundle.unknowns` into the ledger via `_mergeLedgers`, then `_save`.
`_mergeLedgers` gains **unknown de-duplication by `(category, label)`**
(today it concatenates, which would duplicate on every re-analysis) and
removes `AarUnknownCategory.skills` entries before adding the fresh ones.
Persisted ledger facts are a snapshot of what the LLM saw; the UI panel is
live (§1).

### 4.5 `combat_analysis_service.dart` and `codex_analysis_client.dart`

`analyzeEncounter` gains a stage between enrichment and the LLM (stageCount 8 → 9):

```
stage 5/9 'Deriving fit statistics' — incoming/outgoing profiles, bundle, attachDerivedEvidence
```

`CodexAnalysisClient.analyzeEncounter(..., AarDerivationBundle? derivation)`;
`_buildPrompt` emits `schema: 'mimir.combat_aar_input.v4'` with

```json
"derivedFits": [ <AarFitDerivation.toPromptJson()> ... ],
"damageMatchups": { "self": <CombatDamageMatchup.toJson()>, "opponent": ... }
```

System prompt additions (rules block):

- *Treat `derivedFits` and `damageMatchups` as computed by Mimir's dogma engine from the supplied fit evidence. They are derived, not observed; cite their `ev-derived-*` ledger ids.*
- *Every derived fit carries `skills.basis`. When it is `allFive`, say "assuming All V" wherever you quote its numbers and treat them as an upper bound.*
- *Do not restate resist or EHP figures that are not in `derivedFits`; if a fit has no derivation, say the resist profile is unknown.*

`CombatAarReport.version` stays 3: the output schema does not change. The
`CombatAnalysisService` constructor takes `CombatFitDerivationService` and
`CombatDamageProfileResolver`; the provider wires them.

### 4.6 `combat_providers.dart`

```dart
final aarFitDerivationsProvider = FutureProvider.family<AarDerivationBundle, ParsedCombatEncounter>((ref, encounter) async {
  await ref.watch(sdeInitializerProvider.future);
  final enrichment = await ref.watch(combatEnrichmentProvider(encounter.id).future);
  if (enrichment == null) return const AarDerivationBundle.empty();
  final incoming = await ref.watch(combatIncomingDamageProfileProvider(encounter).future);
  final outgoing = await ref.watch(combatDamageProfileProvider(encounter).future);
  return ref.read(combatFitDerivationServiceProvider).deriveForEncounter(encounter: encounter, enrichment: enrichment, incoming: incoming, outgoing: outgoing);
});
```

Keyed by `ParsedCombatEncounter` like `combatDamageProfileProvider`
(identity equality; the screen holds one instance, which is how the existing
provider already works).

---

## 5. Presentation

### 5.1 `widgets/aar_derived_stats_panel.dart`

`AarDerivedStatsPanel extends ConsumerWidget` — props: `derivation`, `title`,
`matchup?`. Layout mirrors `StatsPanel` rows:

- Header: `EveTypeIcon(shipTypeId)`, ship name via `itemNameProvider(shipTypeId).when(...)` (T10.7), title, and a **skill badge**: amber `assumes All V` when `basis == allFive`, neutral `ESI skills` otherwise (AC4.5).
- DEFENSE: `EHP (omni)` total; per-layer row `Shield 1,550 HP · EM 0% / Th 20% / Kin 40% / Exp 50%`; `Tank` chip `tank.label` with `reasoning` as tooltip; `Active rep` rows only when > 0; `Passive shield` peak.
- CAPACITOR: capacity, recharge, `Stable 41%` / `Empty in 47 s` / `—` when `capacitorCapacity == 0` (AC3.3, same `_dashIfUnmodelled` rule as StatsPanel).
- OFFENSE: DPS with breakdown, volley, optimal/falloff when > 0.
- MOBILITY: speed, sig, align.
- Footer: `coverage.describe()` and limitations as `- item` lines.

### 5.2 `widgets/aar_matchup_section.dart`

Rows per entry: `Kinetic  78%  vs 63.1%  strong  (67.6% of damage taken)`,
coloured by assessment (hole red, strong green, neutral default, unknown
dim). Header line: `EHP vs incoming 8,412 · omni 8,910 · layer Armor (active)`.
When `defense == null`: a single line *"Resist profile unknown — no fit
evidence"*, no rows with numbers.

### 5.3 `analysis_multipane_screen.dart`

- Fits tab: after each `_DestroyedFitSection` (pilot and destroyed ship), render `ref.watch(aarFitDerivationsProvider(encounter)).when(data: bundle → panel for the matching subject or nothing, loading: linear progress placeholder, error: `_buildError`-style card)`. No panel when the bundle has no derivation for that subject (AC4.3, T10.4).
- Damage tab: `AarMatchupSection` for `selfMatchup` after `_DamageTypeSection`; `opponentMatchup` beneath it when present.
- Evidence card: unchanged — derived facts and specific unknowns appear through the existing ledger rendering.

Never `.value ?? default` (AC4.6). Log `[COMBAT.UI]` at `d` when a panel
builds and `e` on provider error.

---

## 6. File layout

```
lib/features/fitting/domain/dogma_engine.dart              E0a E0b E0c E2 (§2)
lib/features/fitting/domain/dogma_attributes.dart          new ids (§2.2, §2.5)
lib/features/fitting/domain/damage_pattern.dart            NEW E1 (§2.4)
lib/features/fitting/domain/models.dart                    DefenseProfile fields + doc (§2.5)
lib/features/fitting/data/fitting_stats_inputs.dart        NEW shared loader (§4.1)
lib/features/fitting/presentation/fitting_providers.dart   use loader (§4.1)
lib/core/sde/sde_service.dart                              getDogmaTypes cpu/pg/cal/slot (§4.1)
lib/features/combat_analyzer/domain/aar_fit_derivation.dart     NEW (§3.1)
lib/features/combat_analyzer/domain/tank_classifier.dart        NEW (§3.2)
lib/features/combat_analyzer/domain/combat_fit_deriver.dart     NEW (§3.3)
lib/features/combat_analyzer/domain/aar_derived_facts.dart      NEW (§3.6)
lib/features/combat_analyzer/domain/damage_pattern_x.dart       NEW profile→pattern (§3.4)
lib/features/combat_analyzer/domain/combat_damage_matchup.dart  (§3.4)
lib/features/combat_analyzer/domain/combat_evidence_ledger.dart (§3.5)
lib/features/combat_analyzer/data/combat_fit_derivation_service.dart NEW (§4.2)
lib/features/combat_analyzer/data/combat_damage_profile_resolver.dart (§4.3)
lib/features/combat_analyzer/data/combat_enrichment_service.dart (§4.4)
lib/features/combat_analyzer/data/combat_analysis_service.dart  (§4.5)
lib/features/combat_analyzer/data/codex_analysis_client.dart    (§4.5)
lib/features/combat_analyzer/data/combat_providers.dart         (§4.6)
lib/features/combat_analyzer/presentation/widgets/aar_derived_stats_panel.dart NEW (§5.1)
lib/features/combat_analyzer/presentation/widgets/aar_matchup_section.dart     NEW (§5.2)
lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart       (§5.3)
```

`models.dart` and `damage_pattern.dart` need `build_runner` (freezed).

---

## 7. Test specifications

Spec IDs are kept; `*` marks corrected or added cases. Numbers come from §2
and §3 and from the bundled SDE (`assets/sde/dogma.json`), never from
fixtures invented to fit.

### 7.1 `test/features/fitting/domain/dogma_engine_test.dart` — E0/E2 (new groups)

Fixtures: `_rifter()` as today (cpu 125, velocity 300, shield 400 …) plus
bundle-faithful ones where the case needs them: `shieldExtender` (type 3831,
attr 72 = 1100, 983 = 7, effects 21 `[EffectModifier(21, 'ItemModifier', 2, 263, 72, 'shipID')]`, 2029 `[... 2, 552, 983 ...]`), `plate1600` (20353, 1159 = 4800, 796 = 3,750,000, effects 2837/1959), `dcuII` (2048, resonances per §2.2, effect 2302 with all twelve `op 0` modifiers including `113 <- 974`, `111 <- 975`, `109 <- 976`, `110 <- 977`), `larII` (3540: 84 = 920, 73 = 15000, 6 = 400, effect 27), `msbII` (10850: 68 = 104, 73 = 3000, effect 4), `saar` (33076: 84 = 52, 1886 = 3, 73 = 6000, 1795 = 60000, effect 5275), `hullRepII` (2355: 83 = 30, 73 = 24000, effect 26), `bulkheadsII` (1335: 150 = 1.25, effect 60 `op 4, 9 <- 150`).

| ID | Case | Expect |
|---|---|---|
| E0a.1* | Rifter(shield 450) + MSE II, no skills | `shieldHp == 1550`, `signatureRadius == 42` |
| E0a.2* | same + `CharacterSkill(3419, 5)` | `shieldHp closeTo(1937.5, 1e-6)` — **not** 1662.5 |
| E0a.3* | Rifter + 1600mm II | `armorHp == 5250`, `massKg == 4817000`, `alignTime closeTo(21.369, 0.01)` |
| E0a.4* | Rifter + MSE II + shield rig percent (+15% on 263 op 6) | `(450+1100)×1.15 = 1782.5` |
| E0a.5* | modSub (op 3) on a ship attribute | subtracted; `unsupportedOperators` log count unchanged for op 2/3 on ship attrs |
| E0a.6* | op 2 aimed at a fitted module attribute | still ignored (documented) |
| E0b.1* | Rifter with 113/110/109/111 = 0.67 and 974–977 = 1.0 (bundle-faithful) | `hullResists.em closeTo(33, 1e-6)`, `hullEhp closeTo(522.388, 0.01)`, `totalEhp closeTo(1809.744, 0.01)` |
| E0b.2* | + DCU II | `hullResists.em closeTo(59.8, 0.01)`, `hullEhp closeTo(870.65, 0.01)`, `armorEhp closeTo(784.31, 0.01)`, `shieldEhp closeTo(709.36, 0.01)` |
| E0c.1* | existing line 157/158/344 tests with corrected IDs (3426, 3449, 3419) | values unchanged (125×1.25, 300×1.20, 400×1.25) |
| E0c.2* | wrong IDs from before (3418 for CPU) | `cpuMax == 125` (no effect) — locks the correction |
| E0c.3* | `CharacterSkill(3416, 5)` | `shieldRecharge == base × 0.75`; `peakShieldRecharge` rises by 4/3 |
| E2.1 (T5.6) | Rifter + LAR II | `effectiveArmorRepair closeTo(61.333, 0.001)` |
| E2.2* | Rifter + MSB II | `effectiveShieldBoost closeTo(34.667, 0.001)` |
| E2.3* | Rifter + SAAR, no charge / with charge 28668 | `8.667` / `26.0` |
| E2.4* | Rifter + Small Hull Repairer II | `effectiveHullRepair == 1.25` |
| E2.5 (T5.7) | LAR II with `state: ModuleState.offline` | all repair fields 0 |
| E2.6* | Myrmidon fixture (5342 `LocationRequiredSkillModifier 6, 84 <- 746, filter 3393`, 746 = 7.5, 182 = 33097) + LAR II (182 = 3393) + `CharacterSkill(33097, 5)` | `effectiveArmorRepair closeTo(84.333, 0.001)` |
| E2.7* | E2.6 + skill type 3393 in `skillTypes` with effect 272 modifiers + `CharacterSkill(3393, 5)` | `closeTo(112.444, 0.001)` |
| E2.8* | Rifter passive | `peakShieldRecharge closeTo(1.8, 1e-6)` |
| E2.9* | capless hull (no 482/55) | `peakShieldRecharge == 0` when 479 absent; cap fields 0/false (AC3.3) |

### 7.2 `test/features/fitting/domain/damage_pattern_test.dart` — Group C

| ID | Case | Expect |
|---|---|---|
| T3.1 | `DefenseProfile(armorHp: 1000, armorResists: 0/50/50/50)`, pattern EM 1.0 | `ehpAgainst(p).armor closeTo(1000, 0.01)` |
| T3.2 | same, Exp 1.0 | `2000` |
| T3.3 | same, `DamagePattern.omni` | `1600`, and `== hp / (1 − omniResist/100)` within 1e-9 |
| T3.4 | 0/20/40/50, `fromAmounts(em: 3, thermal: 19, kinetic: 78, explosive: 0)` | `closeTo(1538.4615, 0.001)` |
| T3.5 | all-zero resists, any pattern | `== hp` |
| T3.6* | pattern label | `omni.label == 'omni'`; `fromAmounts(...).label == 'observed'`; `LayeredEhp.pattern` carried |
| C.7* | `fromAmounts` all zero | returns null |
| C.8* | 100% resist on a layer | returns raw hp, no infinity/NaN |
| C.9* | engine parity | `DogmaEngine` stats: `defenses.totalEhp == defenses.ehpAgainst(DamagePattern.omni).total` within 1e-9 for the Rifter+DCU fixture |

### 7.3 `test/features/fitting/domain/real_sde_defense_test.dart` — Group H (bundled SDE from disk, like `real_sde_weapon_test.dart`)

All V = every skill id in the bundle at level 5: the test reads `assets/sde/skills.json` (keys `categories`, `groups`, `types`), takes `groups` with `categoryId == 16`, then `types` in those groups; `skillTypes` = `getDogmaTypes` of all of them, loaded from `dogma.json` the way `real_sde_weapon_test.dart` builds `ModuleType`s.

| ID | Case | Expect |
|---|---|---|
| T8.1 | Rifter (587) bare, no skills | `totalEhp closeTo(1809.744, 0.01)` recomputed in-test from raw resonances |
| T8.1b* | Rifter + MSE II (3831) + Shield Management V only | `shieldHp closeTo(1937.5, 0.01)` |
| T8.2 | Rifter + DCU II (2048) | resists recomputed from resonance × 0.85/0.875/0.6; `hullResists.em closeTo(59.8, 0.01)` |
| T8.3 | Myrmidon (24700) + LAR II (3540) + LSE II (3841), All V | `effectiveArmorRepair closeTo(112.444, 0.01)`; `shieldHp closeTo((3500+2600)×1.25, 0.01)`; `isCapStable` matches an in-test `CapSimulator` run with the same drain (400 GJ / 11,250 ms) |
| T8.4 | Thanatos + 3× Firbolg I (prior milestone fixture), All V | `dpsFighters > 0` in the AAR derivation of a `FitEvidence` carrying that fit |

### 7.4 `test/features/combat_analyzer/domain/tank_classifier_test.dart` — Group E

Inputs are `FittingStats` pairs (fit, baseline) built by hand from the tables in §3.2.

| ID | fit vs baseline | Expect |
|---|---|---|
| T5.1 | armorRepair 61.33; shieldEhp gain 3586 | `armor / active`; reasoning contains `61.3 HP/s` |
| T5.2 | no repair; shield gain 3034.5 | `shield / buffer` |
| T5.3 | shieldBoost 17.5 | `shield / active` |
| T5.4 | armor 61.33, shield 34.67 | `armor / active`; reasoning names both rates |
| T5.5 | hull gain 130.6 only | `hull / buffer` |
| T5.8 | any | `reasoning.isNotEmpty`, `label` formatted `Armor (active)` |
| T5.9* | gains 88.7 / 117.6 / 348.3 (DCU-only Rifter) | `hull / buffer` — documented edge |
| E.10* | bare hull (all gains 0) shield 620.69 / armor 666.67 / hull 522.39 | `armor / unfitted` |
| E.11* | active tie 20/20 with armorEhp > shieldEhp | armor; equal EHP too → armor by fixed order |
| E.12* | all HP zero | `unknown / unfitted` |

### 7.5 `test/features/combat_analyzer/domain/combat_fit_deriver_test.dart` — Groups A, B (pure; no database)

Fixtures: `FittingStatsInputs` built from the same hand-made `ShipType`/`ModuleType` maps used in `dogma_engine_test.dart` (Rifter, 200mm AC II + Republic Fusion S, MSE II).

| ID | Case | Expect |
|---|---|---|
| T1.1 | Rifter + 3× 200mm AC (loaded) + MSE II, allFive context (skills list may be empty for purity — basis drives the label) | `stats.defenses.totalEhp > 0`, `dpsGuns > 0`, `capacitorCapacity > 0` |
| T1.2 | same `Fitting` + skills through `DogmaEngine().calculateStats` directly | `derivation.stats == engineStats` (freezed equality) |
| T1.4 | hull only | `stats == baseline`; `tank.mode == unfitted` |
| T1.5 | highs + 1 mid, ship with 3/3/3 slots | `coverage.describe()` contains `Mid 1/3`, `Low 0/3` |
| T1.6 | one typeId absent from `moduleTypes` (in `unresolved`) | derives; `coverage.hasUnresolved`; limitations contain `1 modules not in the SDE` |
| T1.7 | no DB, no network — runs under `test()` with `FakeAsync`-free plain `await` | completes; `derivedAt` set from injected `now` |
| T2.1 | `AarSkillContext.knownCharacter` with `CharacterSkill(3419, 5)` | `shieldHp == 1550 × 1.25` |
| T2.2 | `allFive` with the same skill at 5 | identical numbers; `skills.label == 'assumes All V'` |
| T2.3 | confidence ordering | `knownCharacter.confidence.index < allFive.confidence.index` (derived < reference) |
| T2.5 | same fit, skills `[]` vs all-V list of the engine's table ids at 5 | All V strictly higher `shieldHp`, `cpuMax` |
| A.8* | limitations always include the skill label and "assumed active" | contains both |
| A.9* | ancillary fitted | limitations mention reload/overheat not modelled |

### 7.6 `test/features/combat_analyzer/domain/combat_damage_matchup_test.dart` — Group D (extend the file; existing test stays byte-identical)

| ID | Case | Expect |
|---|---|---|
| T4.1 | resists 10/60/60/60 (chosen layer), profile 90% EM 10% Kin | EM `resistHole`; Kin `strongResist`; `primaryHole == 'EM'` |
| T4.2 | same resists, 90% Kin | Kin `strongResist` |
| T4.3 | flat 50s, even profile | all `neutral`; `primaryHole == null` |
| T4.4 | `defense: null` | every entry `unknown`, `resistPercent == null`, `appliedPercent == null`, `ehpAgainstPattern == null`, `layer == 'unknown'` |
| T4.5 | mixed profile | `Σ percent closeTo(1.0, 1e-6)`; `Σ appliedPercent closeTo(1.0, 1e-6)` |
| T4.7 | `tank: TankAssessment(layer: armor, mode: active)` on a defense whose shield HP is larger | `layer == 'armor'`; resists from `armorResists` |
| D.8* | S1 numbers: armor 52.4/34.8/63.1/71.2, 3/19/78 | Thermal hole, Kinetic & Explosive strong, EM neutral; `appliedPercent` Kin `closeTo(0.676, 0.001)`, Th `0.291`, EM `0.034`; `ehpAgainstPattern.armor` = `armorHp / (0.03×0.476 + 0.19×0.652 + 0.78×0.369)` |
| D.9* | `DamagePattern` from profile with unknown weapons present | unknown weapons ignored; pattern sums to 1 |
| D.10* | JSON round trip with null resist | `fromJson(toJson())` preserves nulls and `primaryHole` |

`combat_damage_profile_resolver_test.dart` adds T4.6-incoming*: log lines
`100 from Enemy - Scourge Rocket - Hits` and `50 from Enemy - Mystery Gun - Hits`
with Scourge Rocket seeded (kinetic 20) → `resolveIncomingProfile`: one
Kinetic entry, `percent == 1.0`, `unknownWeapons == ['Mystery Gun']`;
`resolveOutgoingProfile` of the same log is empty (AC2.5, R3.4).

### 7.7 `test/features/combat_analyzer/domain/aar_derived_facts_test.dart` — Group G

| ID | Case | Expect |
|---|---|---|
| T7.1 | derivation from §7.5 T1.1 | ≥ 8 facts; ids start with `ev-derived-self-`; all `source == dogmaDerivation` |
| T7.2 | mixed ledger (baseline combatLog facts + derived) | `facts.map(source).toSet()` contains both `combatLog` and `dogmaDerivation` |
| T7.3 | `unknownsFor` with no evidence | contains `opponentFit / Opponent defense profile`; pilotFit unknown retained by the service (not duplicated) |
| T7.4 | derivation with unresolved module | unknown detail names `Type #<id>` and says "floor" |
| T2.4 | allFive derivation | `skills` fact value `assumes All V`; every fact's `limitations` contain it; `confidence == reference` |
| G.6* | deterministic ids | building twice yields identical id lists; encounter id suffix present |
| G.7* | `attachDerivedEvidence` twice on the same enrichment (service test, in-memory `AppDatabase`) | fact count unchanged on the second call; unknowns not duplicated |
| T7.5 | rendered panel (§7.9) values | every number string shown by `AarDerivedStatsPanel` for a derivation appears in `AarDerivedFactsBuilder.facts(...)` values (test walks `find.byType(Text)`) |

### 7.8 `test/features/combat_analyzer/data/combat_fit_derivation_service_test.dart` and `combat_analysis_service_test.dart` — Group I (Drift in-memory, seeded from the bundle like `fitting_stats_production_wiring_test.dart`, inside `runAsync`)

| ID | Case | Expect |
|---|---|---|
| T9.4 / T1.3 | `FitEvidence` with `shipTypeId: 999999` | `AarFitDerivationFailed`, `unknown.label == 'Ship type not in SDE'`; no throw |
| T9.4b* | Rifter fit through the service vs `fittingStatsProvider` in a `ProviderContainer` with the same seeded SDE and the same `CharacterSkill` list | `stats == providerStats` |
| I.3* | `skillContextFor(self, characterId)` with seeded `CharacterSkills` rows | `knownCharacter`; with none → `allFive` and `skills.length == seeded skill count` |
| T9.2 | `CombatAnalysisService.analyzeEncounter` with a `FakeCodexAnalysisClient` (subclass overriding `analyzeEncounter` to capture the prompt and return a fixed report) and an enrichment carrying a pilot fit | prompt JSON contains `"schema": "mimir.combat_aar_input.v4"`, `derivedFits` with one entry, `evidenceLedger.facts` with `ev-derived-self-ehp-omni-*`; progress stage labels include `Deriving fit statistics` |
| T9.3 | same with no fit evidence | completes; prompt has `derivedFits: []`; ledger unknowns include `Opponent defense profile` |
| T9.1 | source scan | `File('lib/features/combat_analyzer/data/combat_fit_derivation_service.dart')` contains `CombatDamageMatchupAnalyzer.analyze(` (AC2.6) |

### 7.9 `test/features/combat_analyzer/presentation/aar_derived_stats_panel_test.dart` — Group J (widget; `ProviderScope` overrides for `aarFitDerivationsProvider`, `itemNameProvider`)

| ID | Case | Expect |
|---|---|---|
| T10.1 | bundle with `self` | finds `EHP (omni)`, a `Tank` chip, `DPS`, `Stable` or `Empty in` |
| T10.2 | provider `Completer` unresolved | progress indicator; no exception |
| T10.3 | provider throws | error card; no exception |
| T10.4 | empty bundle | `find.byType(AarDerivedStatsPanel)` → nothing |
| T10.5 | bundle with `self` and `opponent` | two panels |
| T10.6 | `allFive` | `find.text('assumes All V')` |
| T10.7 | `itemNameProvider` overridden to `'Rifter'` | shows `Rifter`, `find.textContaining('Item #')` nothing |
| J.8* | matchup section with `defense == null` | shows `Resist profile unknown`, no `%` rows |
| J.9* | StatsPanel regression | `fitting_stats_production_wiring_test.dart` unchanged and green (AC5.1) |

---

## 8. Sequencing for the planner

Tiers follow the work shape (judgment → Opus; mechanical → Sonnet).

- **U0 [SEQ] Engine corrections E0a/E0b/E0c + E1 helper** — `dogma_engine.dart`, `dogma_attributes.dart`, `damage_pattern.dart`, `models.dart` doc. Tests §7.1 (E0 rows), §7.2. Opus. Gate: all existing fitting tests green with the three ID edits.
- **U1 [P1] E2 active repair + peak recharge** — engine module loop, `DefenseProfile` fields, allowlist 272. Tests §7.1 E2 rows, §7.3. Opus.
- **U1b [P1] Shared loader + `getDogmaTypes` fill** — `fitting_stats_inputs.dart`, provider refactor, SDE service. Test: production-wiring unchanged. Sonnet.
- **U2 [SEQ after U0/U1/U1b] Domain: derivation, tank, facts, matchup** — §3 files. Tests §7.4, §7.5, §7.6, §7.7 (except G.7/T7.5). Opus.
- **U3 [SEQ after U2] Data: service, incoming resolver, enrichment merge, pipeline stage, prompt v4** — §4. Tests §7.8, resolver incoming case, G.7. Opus for the prompt rules, Sonnet for the rest.
- **U4 [P2] UI panel + matchup section + screen wiring** — §5. Tests §7.9, T7.5. Sonnet.
- **U5 [P2] Journal** — §9. Sonnet.
- **U6 [SEQ] Closing gate** — `flutter analyze`, full `flutter test`, one manual spot-check of Rifter+MSE II EHP against pyfa or in-game if available (spec R3).

U0 is the whole reason the milestone produces trustworthy numbers; it ships
alone first so the fitting screen benefits even if the rest slips.

---

## 9. Journal protocol on ship (spec §9 plus)

- ARCHIVE: QUEUED P1 "AAR fit simulation and defense profile derivation" as SHIPPED.
- LEARNINGS entries: (1) *flat-average EHP hides resist holes* (spec §9); (2) *operator 2 was never implemented, so every plate and extender was silently ignored* — generalizable rule: a modifier-routing engine must count and surface unsupported operators per attribute, not just log a total; (3) *hull resonance ids 974–977 are the DCU's bonus attributes, ships use 109/110/111/113*; (4) *`_skillModifiers` carried five wrong skill ids for months because the tests were written from the table, not from the SDE* — rule: fixture ids come from the bundle, never from the code under test.
- QUEUE: turret tracking / missile application in the matchup; LLM prompt regression follow-up (spec R4); retire `_skillModifiers` in favour of routing 446/490/394/2432/397/271/392/486 (now P2: the table is a double-application hazard); second-order module bonuses (compensation skills modify a module's *bonus* attribute 984–987, which `routeOwnerModifiers` reads raw — needs `moduleAttr` for the modifying value); ancillary reload / overheat in repair rates; `dogmaVersion` stamp on derived facts.
- Re-check QUEUED P1 "AAR evidence completeness score": the specific unknowns in §3.6 are its input.

---

## 10. Out of scope, stated

Clip and ancillary reloads, overheat, turret tracking and missile
application in the matchup, projection (webs/painters) onto the matchup,
fit editing from the AAR, Exploration, and any change to the AAR report
output schema (`CombatAarReport.version` stays 3).

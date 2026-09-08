import 'dart:math';

import '../../../core/logging/logger.dart';
import 'cap_simulator.dart';
import 'dogma_attributes.dart';
import 'models.dart';

/// The core calculation engine for EVE Online ship fitting.
///
/// Processes a [Fitting], applies character skills, and calculates
/// derived statistics like EHP, DPS, capacitor stability, and resource usage.
class DogmaEngine {
  /// Dogma operator codes as observed from ESI's live effect data.
  static const int _postMul = 0;
  static const int _postPercent = 6;

  /// Damage resonances are non-stackable: multiple modifiers on the same
  /// resonance take the stacking penalty. Everything else ESI points at
  /// (cpu, powergrid, velocity, ...) is stackable.
  static const Set<int> _nonStackableAttributes = {
    DogmaAttributes.armorEmResist,
    DogmaAttributes.armorExplosiveResist,
    DogmaAttributes.armorKineticResist,
    DogmaAttributes.armorThermalResist,
    DogmaAttributes.shieldEmResist,
    DogmaAttributes.shieldExplosiveResist,
    DogmaAttributes.shieldKineticResist,
    DogmaAttributes.shieldThermalResist,
    DogmaAttributes.hullEmResist,
    DogmaAttributes.hullExplosiveResist,
    DogmaAttributes.hullKineticResist,
    DogmaAttributes.hullThermalResist,
  };

  /// Effects whose bonus lives in a dogma expression tree that ESI does not
  /// publish as modifiers (verified live on 2026-09-07: effects 6730 and
  /// 6731 return empty modifier lists).
  ///
  /// Maps effectId to (modified attribute, modifying attribute): speedFactor
  /// (20, display name "Maximum Velocity Bonus", percent unit) applied
  /// postPercent to maxVelocity (37). Cross-checked against the bundled SDE
  /// values — AB I 115, AB II 135, MWD I 500, MWD II 510 — which match the
  /// in-game multipliers (x2.15, x2.35, x6, x6.1).
  static const Map<int, (int, int)> _expressionTreeSpeedEffects = {
    6730: (DogmaAttributes.maxVelocity, DogmaAttributes.speedFactor),
    6731: (DogmaAttributes.maxVelocity, DogmaAttributes.speedFactor),
  };

  /// Calculate stacking penalty for the n-th module affecting an attribute.
  /// Note: n is 1-indexed. The first module (highest bonus) has n=1 and penalty=1.0.
  static double getStackingPenalty(int n) {
    if (n <= 1) return 1.0;
    return exp(-pow((n - 1) / 2.67, 2));
  }

  /// Skill-driven postMul modifiers applied to ship attributes.
  ///
  /// Entries are (skillTypeId, attributeId, bonusPerLevel). These are EVE's
  /// classic +5%/level skill effects; applying them postMul to the ship
  /// attribute reproduces how the game derives the same values.
  static const List<(int, int, double)> _skillModifiers = [
    (3418, DogmaAttributes.cpuOutput, 0.05), // CPU Management
    (3402, DogmaAttributes.powerOutput, 0.05), // Engineering
    (3455, DogmaAttributes.maxVelocity, 0.05), // Navigation
    (3424, DogmaAttributes.capacitorCapacity, 0.05), // Capacitor Management
    (3425, DogmaAttributes.shieldCapacity, 0.05), // Shield Management
    (3394, DogmaAttributes.armorHp, 0.05), // Hull Upgrades
    (3392, DogmaAttributes.hullHp, 0.05), // Mechanics
  ];

  /// Calculate full statistics for a fitting.
  ///
  /// [effectModifiers] maps an effectId to the modifiers ESI publishes for
  /// it; without them (offline, never fetched) modules contribute resource
  /// usage only and the stats reflect base plus skill attributes.
  Future<FittingStats> calculateStats(
    Fitting fitting,
    ShipType shipType,
    Map<String, ModuleType> moduleTypes,
    List<CharacterSkill> characterSkills, {
    Map<int, List<EffectModifier>> effectModifiers = const {},
  }) async {
    Log.d('DOGMA', 'Calculating stats for fitting: ${fitting.name}');

    // 1. Attribute pipeline: ship base attributes, then character skills,
    //    then module effects. Everything below reads from this map so a
    //    trained skill or a fitted module visibly changes the numbers.
    final attributes = Map<int, double>.from(shipType.baseAttributes);

    final skillLevels = {
      for (final skill in characterSkills) skill.skillId: skill.level,
    };
    for (final (skillId, attributeId, perLevel) in _skillModifiers) {
      final level = skillLevels[skillId] ?? 0;
      final base = attributes[attributeId];
      if (level == 0 || base == null) continue;
      attributes[attributeId] = base * (1 + perLevel * level);
    }

    double attr(int id, [double fallback = 0.0]) => attributes[id] ?? fallback;

    // 2. Resource usage, and collect dogma modifiers from the ship and its
    //    fitted modules.
    //
    // Modifier semantics come from CCP's resolved effect modifiers (bundled
    // from the SDE's dgmEffects.modifierInfo, ESI-compatible), not from
    // guessed constants: operator 6 is postPercent and operator 0 is
    // postMul. See EffectModifier.
    //
    // Routing follows the modifier's func and domain, as observed in the
    // bundled data (2026-09-08):
    //  - ItemModifier + shipID: the owner modifies the ship itself
    //    (hardeners, damage control, ship resistance traits).
    //  - Location*/Owner* + shipID: the owner modifies fitted modules,
    //    optionally group-restricted (racial weapon bonuses, tracking
    //    enhancers); also the ship when it carries the modified attribute.
    //  - Location*/Owner* + charID: the owner modifies loaded charges
    //    (racial missile damage bonuses).
    double cpuUsed = 0.0;
    double powerUsed = 0.0;
    int calibrationUsed = 0;
    final percentModifiers = <int, List<double>>{};
    final mulModifiers = <int, List<double>>{};
    final modulePercent = <int, Map<int, List<double>>>{};
    final moduleMul = <int, Map<int, List<double>>>{};
    final chargePercent = <int, Map<int, List<double>>>{};
    final chargeMul = <int, Map<int, List<double>>>{};
    var unsupportedOperators = 0;
    final capDrains = <String, CapDrain>{};

    final chargeTypeIds = fitting.allModules
        .map((module) => module.chargeTypeId)
        .whereType<int>()
        .toSet();

    void addTo(Map<int, List<double>> target, int attributeId, double value) =>
        target.putIfAbsent(attributeId, () => []).add(value);

    void routeLocationModifier(EffectModifier modifier, double value) {
      if (modifier.operator != _postPercent && modifier.operator != _postMul) {
        unsupportedOperators++;
        return;
      }
      final percents = modifier.operator == _postPercent;
      if (modifier.domain == 'charID') {
        for (final chargeId in chargeTypeIds) {
          final charge = moduleTypes[chargeId.toString()];
          if (charge == null) continue;
          if (modifier.groupId != null && charge.groupId != modifier.groupId) {
            continue;
          }
          if (!charge.baseAttributes.containsKey(
            modifier.modifiedAttributeId,
          )) {
            continue;
          }
          addTo(
            (percents ? chargePercent : chargeMul).putIfAbsent(
              chargeId,
              () => {},
            ),
            modifier.modifiedAttributeId,
            value,
          );
        }
        return;
      }
      if (modifier.domain != 'shipID') return;
      if (shipType.baseAttributes.containsKey(modifier.modifiedAttributeId)) {
        addTo(
          percents ? percentModifiers : mulModifiers,
          modifier.modifiedAttributeId,
          value,
        );
      }
      for (final type in moduleTypes.values) {
        if (modifier.groupId != null && type.groupId != modifier.groupId) {
          continue;
        }
        if (!type.baseAttributes.containsKey(modifier.modifiedAttributeId)) {
          continue;
        }
        addTo(
          (percents ? modulePercent : moduleMul).putIfAbsent(
            type.typeId,
            () => {},
          ),
          modifier.modifiedAttributeId,
          value,
        );
      }
    }

    void routeOwnerModifiers(
      List<DogmaEffect> effects,
      Map<int, double> ownerAttributes, {
      Map<int, double>? fallbackAttributes,
    }) {
      for (final effect in effects) {
        for (final modifier
            in effectModifiers[effect.effectId] ?? const <EffectModifier>[]) {
          if (modifier.func == 'EffectStopper') continue;
          final modifyingId = modifier.modifyingAttributeId;
          final base = modifyingId == null
              ? null
              : ownerAttributes[modifyingId] ??
                    fallbackAttributes?[modifyingId];
          if (base == null) continue;
          final skillId = modifier.skillTypeId;
          final value = skillId != null
              ? base * (skillLevels[skillId] ?? 0)
              : base;
          if (value == 0) continue;

          if (modifier.func == 'ItemModifier') {
            if (modifier.domain != 'shipID') continue;
            if (modifier.operator == _postMul) {
              addTo(mulModifiers, modifier.modifiedAttributeId, value);
            } else if (modifier.operator == _postPercent) {
              addTo(percentModifiers, modifier.modifiedAttributeId, value);
            } else {
              unsupportedOperators++;
            }
            continue;
          }
          routeLocationModifier(modifier, value);
        }
      }
    }

    // Ship traits (racial bonuses) live on the ship type's own effects.
    routeOwnerModifiers(shipType.effects, shipType.baseAttributes);

    /// Effective attribute of a fitted module after group/skill bonuses.
    /// Bonuses from separate sources on one attribute take the dogma
    /// stacking penalty, strongest first, like in game.
    double moduleAttr(ModuleType type, int id) {
      final base = type.baseAttributes[id];
      if (base == null) return 0.0;
      var value = base;
      final percents = modulePercent[type.typeId]?[id];
      if (percents != null) {
        final sorted = [...percents]
          ..sort((a, b) => b.abs().compareTo(a.abs()));
        for (var i = 0; i < sorted.length; i++) {
          value *= 1 + (sorted[i] / 100) * getStackingPenalty(i + 1);
        }
      }
      for (final mul in moduleMul[type.typeId]?[id] ?? const <double>[]) {
        value *= mul;
      }
      return value;
    }

    /// Effective attribute of a loaded charge after character-wide bonuses.
    double chargeAttr(ModuleType charge, int id) {
      final base = charge.baseAttributes[id];
      if (base == null) return 0.0;
      var value = base;
      final percents = chargePercent[charge.typeId]?[id];
      if (percents != null) {
        final sorted = [...percents]
          ..sort((a, b) => b.abs().compareTo(a.abs()));
        for (var i = 0; i < sorted.length; i++) {
          value *= 1 + (sorted[i] / 100) * getStackingPenalty(i + 1);
        }
      }
      for (final mul in chargeMul[charge.typeId]?[id] ?? const <double>[]) {
        value *= mul;
      }
      return value;
    }

    for (final module in fitting.allModules) {
      if (module.state == ModuleState.offline) continue;

      final type = moduleTypes[module.typeId.toString()];
      if (type == null) continue;

      cpuUsed += type.cpu;
      powerUsed += type.powergrid;
      calibrationUsed += type.calibration;

      // Cap cycle costs read the bonus-adjusted values so ship and module
      // cap-need bonuses change capacitor stability like in game.
      final hasCapNeed = type.baseAttributes.containsKey(
        DogmaAttributes.capacitorNeed,
      );
      final hasCycle = type.baseAttributes.containsKey(
        DogmaAttributes.duration,
      );
      if (hasCapNeed && hasCycle) {
        final capNeed = moduleAttr(type, DogmaAttributes.capacitorNeed);
        final cycleMs = moduleAttr(type, DogmaAttributes.duration);
        if (capNeed > 0 && cycleMs > 0) {
          final key = '${cycleMs.round()}:${capNeed.toStringAsFixed(3)}';
          capDrains[key] = CapDrain(
            durationMs: cycleMs,
            capNeed: capNeed,
            count: (capDrains[key]?.count ?? 0) + 1,
          );
        }
      }

      routeOwnerModifiers(
        type.effects,
        type.baseAttributes,
        fallbackAttributes: module.attributes,
      );

      for (final effect in type.effects) {
        // Propulsion bonuses hide in expression trees the SDE does not
        // publish as modifiers; apply the verified curated mapping for
        // those effects.
        final speedEffect = _expressionTreeSpeedEffects[effect.effectId];
        if (speedEffect != null) {
          final (modifiedId, modifyingId) = speedEffect;
          final value =
              type.baseAttributes[modifyingId] ??
              module.attributes[modifyingId];
          if (value != null) {
            percentModifiers.putIfAbsent(modifiedId, () => []).add(value);
          }
        }
      }
    }

    // postPercent modifiers combine multiplicatively; on non-stackable
    // attributes (the damage resonances) the n-th strongest bonus is scaled
    // by the dogma stacking penalty.
    percentModifiers.forEach((attributeId, values) {
      final sorted = [...values]..sort((a, b) => b.abs().compareTo(a.abs()));
      var factor = 1.0;
      for (var i = 0; i < sorted.length; i++) {
        final penalty = _nonStackableAttributes.contains(attributeId)
            ? getStackingPenalty(i + 1)
            : 1.0;
        factor *= 1 + (sorted[i] / 100) * penalty;
      }
      attributes[attributeId] = attr(attributeId, 1.0) * factor;
    });

    mulModifiers.forEach((attributeId, values) {
      var factor = 1.0;
      for (final value in values) {
        factor *= value;
      }
      attributes[attributeId] = attr(attributeId, 1.0) * factor;
    });

    if (unsupportedOperators > 0) {
      Log.d(
        'DOGMA',
        'Ignored $unsupportedOperators modifiers with unsupported operators',
      );
    }

    final cpuMax = attr(DogmaAttributes.cpuOutput);
    final powerMax = attr(DogmaAttributes.powerOutput);
    final calibrationMax = attr(DogmaAttributes.upgradeLoad, 400).toInt();

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
    final warpSpeed = attr(DogmaAttributes.warpSpeedMultiplier);

    // 3. Calculate Defenses
    final shieldHp = attr(DogmaAttributes.shieldCapacity);
    final armorHp = attr(DogmaAttributes.armorHp);
    final hullHp = attr(DogmaAttributes.hullHp);

    // Convert resonance to resist % (resonance 1.0 = 0% resist, 0.2 = 80% resist)
    double toResist(double? resonance) =>
        resonance != null ? (1.0 - resonance) * 100 : 0.0;

    final shieldResists = ResistProfile(
      em: toResist(attr(DogmaAttributes.shieldEmResist, 1.0)),
      thermal: toResist(attr(DogmaAttributes.shieldThermalResist, 1.0)),
      kinetic: toResist(attr(DogmaAttributes.shieldKineticResist, 1.0)),
      explosive: toResist(attr(DogmaAttributes.shieldExplosiveResist, 1.0)),
    );

    final armorResists = ResistProfile(
      em: toResist(attr(DogmaAttributes.armorEmResist, 1.0)),
      thermal: toResist(attr(DogmaAttributes.armorThermalResist, 1.0)),
      kinetic: toResist(attr(DogmaAttributes.armorKineticResist, 1.0)),
      explosive: toResist(attr(DogmaAttributes.armorExplosiveResist, 1.0)),
    );

    final hullResists = ResistProfile(
      em: toResist(attr(DogmaAttributes.hullEmResist, 1.0)),
      thermal: toResist(attr(DogmaAttributes.hullThermalResist, 1.0)),
      kinetic: toResist(attr(DogmaAttributes.hullKineticResist, 1.0)),
      explosive: toResist(attr(DogmaAttributes.hullExplosiveResist, 1.0)),
    );

    // EHP Calculation
    double calculateEhp(double hp, ResistProfile resists) {
      final avgResist =
          (resists.em + resists.thermal + resists.kinetic + resists.explosive) /
          400.0;
      return hp / (1.0 - avgResist);
    }

    final shieldEhp = calculateEhp(shieldHp, shieldResists);
    final armorEhp = calculateEhp(armorHp, armorResists);
    final hullEhp = calculateEhp(hullHp, hullResists);

    final defenses = DefenseProfile(
      shieldHp: shieldHp,
      shieldRecharge: attr(DogmaAttributes.shieldRechargeTime),
      shieldResists: shieldResists,
      shieldEhp: shieldEhp,
      armorHp: armorHp,
      armorResists: armorResists,
      armorEhp: armorEhp,
      hullHp: hullHp,
      hullResists: hullResists,
      hullEhp: hullEhp,
      totalEhp: shieldEhp + armorEhp + hullEhp,
    );

    // 4. Calculate Capacitor
    final capCapacity = attr(DogmaAttributes.capacitorCapacity);
    final capRecharge = attr(DogmaAttributes.capacitorRechargeTime);

    // Capacitor stability: simulate the repeating drains against pyfa's
    // recharge curve. Without capacitor attributes the row stays unmodelled
    // (0 / false) and the panel renders a dash.
    var capStableValue = 0.0;
    var capIsStable = false;
    if (capCapacity > 0 && capRecharge > 0) {
      final capResult = CapSimulator(
        capacity: capCapacity,
        rechargeMs: capRecharge,
        drains: capDrains.values.toList(),
      ).run();
      capIsStable = capResult.isStable;
      capStableValue = capResult.isStable
          ? capResult.stablePercent
          : capResult.secondsToEmpty;
    }

    // 5. Offense: volley and DPS of fitted turrets and launchers with their
    //    loaded charges, after all bonuses. Turrets multiply charge damage
    //    by their damage modifier (64); launchers contribute the charge
    //    damage alone (pyfa parity). Unloaded weapons contribute nothing,
    //    exactly like an unloaded gun in game.
    var dpsGuns = 0.0;
    var dpsMissiles = 0.0;
    var volleyTotal = 0.0;
    var turretVolley = 0.0;
    var optimalWeighted = 0.0;
    var falloffWeighted = 0.0;
    for (final module in fitting.allModules) {
      if (module.state == ModuleState.offline) continue;
      final type = moduleTypes[module.typeId.toString()];
      if (type == null) continue;
      if (!type.baseAttributes.containsKey(DogmaAttributes.rateOfFire)) {
        continue;
      }
      final cycleMs = moduleAttr(type, DogmaAttributes.rateOfFire);
      if (cycleMs <= 0) continue;
      final charge = module.chargeTypeId == null
          ? null
          : moduleTypes[module.chargeTypeId.toString()];
      if (charge == null) continue;
      var chargeVolley = 0.0;
      for (final id in DogmaAttributes.damageComponents) {
        chargeVolley += chargeAttr(charge, id);
      }
      if (chargeVolley <= 0) continue;
      final isTurret = type.baseAttributes.containsKey(
        DogmaAttributes.turretDamageMultiplier,
      );
      final volley = isTurret
          ? chargeVolley *
                moduleAttr(type, DogmaAttributes.turretDamageMultiplier)
          : chargeVolley;
      final dps = volley / (cycleMs / 1000);
      if (isTurret) {
        dpsGuns += dps;
        turretVolley += volley;
        optimalWeighted +=
            moduleAttr(type, DogmaAttributes.optimalRange) * volley;
        falloffWeighted += moduleAttr(type, DogmaAttributes.falloff) * volley;
      } else {
        dpsMissiles += dps;
      }
      volleyTotal += volley;
    }
    final dpsTotal = dpsGuns + dpsMissiles;
    Log.d(
      'DOGMA',
      'Offense for ${fitting.name}: dps=${dpsTotal.toStringAsFixed(1)} '
          'guns=${dpsGuns.toStringAsFixed(1)} '
          'missiles=${dpsMissiles.toStringAsFixed(1)} '
          'volley=${volleyTotal.toStringAsFixed(1)}',
    );

    // 6. Build Stats Object.
    return FittingStats(
      cpuUsed: cpuUsed,
      cpuMax: cpuMax,
      powerUsed: powerUsed,
      powerMax: powerMax,
      calibrationUsed: calibrationUsed,
      calibrationMax: calibrationMax,
      defenses: defenses,
      capacitorCapacity: capCapacity,
      capacitorRecharge: capRecharge,
      capacitorStable: capStableValue,
      isCapStable: capIsStable,
      dpsTotal: dpsTotal,
      dpsGuns: dpsGuns,
      dpsMissiles: dpsMissiles,
      volley: volleyTotal,
      optimalRange: turretVolley > 0 ? optimalWeighted / turretVolley : 0.0,
      falloffRange: turretVolley > 0 ? falloffWeighted / turretVolley : 0.0,
      maxVelocity: attr(DogmaAttributes.maxVelocity),
      inertiaModifier: agility,
      massKg: massKg,
      alignTime: alignTime,
      warpSpeed: warpSpeed,
      targetRange: attr(DogmaAttributes.maxTargetRange),
      scanResolution: attr(DogmaAttributes.scanResolution),
      maxLockedTargets: attr(DogmaAttributes.maxLockedTargets).toInt(),
      signatureRadius: attr(DogmaAttributes.signatureRadius),
      droneBandwidthMax: attr(DogmaAttributes.droneBandwidth),
      droneBayMax: attr(DogmaAttributes.droneCapacity),
    );
  }
}

import 'dart:math';

import '../../../core/logging/logger.dart';
import 'dogma_attributes.dart';
import 'models.dart';

/// The core calculation engine for EVE Online ship fitting.
///
/// Processes a [Fitting], applies character skills, and calculates
/// derived statistics like EHP, DPS, capacitor stability, and resource usage.
class DogmaEngine {
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
  Future<FittingStats> calculateStats(
    Fitting fitting,
    ShipType shipType,
    Map<String, ModuleType> moduleTypes,
    List<CharacterSkill> characterSkills,
  ) async {
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

    // 2. Resource usage and module attribute effects.
    double cpuUsed = 0.0;
    double powerUsed = 0.0;
    int calibrationUsed = 0;

    for (final module in fitting.allModules) {
      if (module.state == ModuleState.offline) continue;

      final type = moduleTypes[module.typeId.toString()];
      if (type == null) continue;

      cpuUsed += type.cpu;
      powerUsed += type.powergrid;
      calibrationUsed += type.calibration;

      // Propulsion modules carry their multiplier as speedFactor, applied
      // postPercent to max velocity, i.e. a factor of 0.5 means +50%.
      final speedFactor = type.baseAttributes[DogmaAttributes.speedFactor];
      if (speedFactor != null) {
        attributes[DogmaAttributes.maxVelocity] =
            attr(DogmaAttributes.maxVelocity) * (1 + speedFactor);
      }
    }

    final cpuMax = attr(DogmaAttributes.cpuOutput);
    final powerMax = attr(DogmaAttributes.powerOutput);
    final calibrationMax = attr(DogmaAttributes.upgradeLoad, 400).toInt();

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

    // 5. Build Stats Object.
    //
    // dps*, alignTime, warpSpeed and capacitorStable are left at their zero
    // defaults on purpose: the engine does not model them yet, and the stats
    // panel renders those zeros as "—" instead of presenting them as real
    // measurements.
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
      maxVelocity: attr(DogmaAttributes.maxVelocity),
      inertiaModifier: attr(DogmaAttributes.inertiaModifier),
      massKg: attr(DogmaAttributes.mass),
      targetRange: attr(DogmaAttributes.maxTargetRange),
      scanResolution: attr(DogmaAttributes.scanResolution),
      maxLockedTargets: attr(DogmaAttributes.maxLockedTargets).toInt(),
      signatureRadius: attr(DogmaAttributes.signatureRadius),
    );
  }
}

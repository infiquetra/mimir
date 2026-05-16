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

  /// Calculate full statistics for a fitting.
  Future<FittingStats> calculateStats(
    Fitting fitting,
    ShipType shipType,
    Map<String, ModuleType> moduleTypes,
    List<CharacterSkill> characterSkills,
  ) async {
    Log.d('DOGMA', 'Calculating stats for fitting: ${fitting.name}');
    
    // 1. Gather base attributes from Ship
    final baseCpu = shipType.baseAttributes[DogmaAttributes.cpuOutput] ?? 0.0;
    final basePower = shipType.baseAttributes[DogmaAttributes.powerOutput] ?? 0.0;
    final baseCalibration = shipType.baseAttributes[DogmaAttributes.upgradeLoad]?.toInt() ?? 400; // default 400
    
    // TODO: Apply character skills to base ship attributes (e.g., Engineering, CPU Management)
    
    double cpuMax = baseCpu;
    double powerMax = basePower;
    
    // 2. Calculate resource usage
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
    }
    
    // 3. Calculate Defenses
    final shieldHp = shipType.baseAttributes[DogmaAttributes.shieldCapacity] ?? 0.0;
    final armorHp = shipType.baseAttributes[DogmaAttributes.armorHp] ?? 0.0;
    final hullHp = shipType.baseAttributes[DogmaAttributes.hullHp] ?? 0.0;
    
    // Convert resonance to resist % (resonance 1.0 = 0% resist, 0.2 = 80% resist)
    double toResist(double? resonance) => resonance != null ? (1.0 - resonance) * 100 : 0.0;
    
    final shieldResists = ResistProfile(
      em: toResist(shipType.baseAttributes[DogmaAttributes.shieldEmResist]),
      thermal: toResist(shipType.baseAttributes[DogmaAttributes.shieldThermalResist]),
      kinetic: toResist(shipType.baseAttributes[DogmaAttributes.shieldKineticResist]),
      explosive: toResist(shipType.baseAttributes[DogmaAttributes.shieldExplosiveResist]),
    );
    
    final armorResists = ResistProfile(
      em: toResist(shipType.baseAttributes[DogmaAttributes.armorEmResist]),
      thermal: toResist(shipType.baseAttributes[DogmaAttributes.armorThermalResist]),
      kinetic: toResist(shipType.baseAttributes[DogmaAttributes.armorKineticResist]),
      explosive: toResist(shipType.baseAttributes[DogmaAttributes.armorExplosiveResist]),
    );
    
    final hullResists = ResistProfile(
      em: toResist(shipType.baseAttributes[DogmaAttributes.hullEmResist]),
      thermal: toResist(shipType.baseAttributes[DogmaAttributes.hullThermalResist]),
      kinetic: toResist(shipType.baseAttributes[DogmaAttributes.hullKineticResist]),
      explosive: toResist(shipType.baseAttributes[DogmaAttributes.hullExplosiveResist]),
    );
    
    // EHP Calculation
    double calculateEhp(double hp, ResistProfile resists) {
      final avgResist = (resists.em + resists.thermal + resists.kinetic + resists.explosive) / 400.0;
      return hp / (1.0 - avgResist);
    }
    
    final shieldEhp = calculateEhp(shieldHp, shieldResists);
    final armorEhp = calculateEhp(armorHp, armorResists);
    final hullEhp = calculateEhp(hullHp, hullResists);
    
    final defenses = DefenseProfile(
      shieldHp: shieldHp,
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
    final capCapacity = shipType.baseAttributes[DogmaAttributes.capacitorCapacity] ?? 0.0;
    final capRecharge = shipType.baseAttributes[DogmaAttributes.capacitorRechargeTime] ?? 0.0;
    
    // 5. Build Stats Object
    return FittingStats(
      cpuUsed: cpuUsed,
      cpuMax: cpuMax,
      powerUsed: powerUsed,
      powerMax: powerMax,
      calibrationUsed: calibrationUsed,
      calibrationMax: baseCalibration,
      defenses: defenses,
      capacitorCapacity: capCapacity,
      capacitorRecharge: capRecharge,
      // TODO: proper calculation of other stats
    );
  }
}

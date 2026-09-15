import '../../fitting/domain/damage_pattern.dart';
import '../../fitting/domain/models.dart';
import 'aar_fit_comparison.dart';
import 'aar_fit_derivation.dart';
import 'aar_fit_snapshot.dart';
import 'tank_classifier.dart';

enum AarMetricAvailability {
  available,
  partial,
  unavailable,
  notModeled,
  unbounded,
}

class AarMetricValue {
  const AarMetricValue({
    this.value,
    this.availability = AarMetricAvailability.available,
    this.unit,
    this.limitations = const [],
  });

  final double? value;
  final AarMetricAvailability availability;
  final String? unit;
  final List<String> limitations;

  bool get isFiniteValue => value != null && value!.isFinite && !value!.isNaN;
}

class CombatFitComputation {
  const CombatFitComputation({
    required this.stats,
    required this.bareHullStats,
    required this.tank,
    required this.coverage,
    this.diagnostics = const [],
    this.frameKey = '',
  });

  final FittingStats stats;
  final FittingStats bareHullStats;
  final TankAssessment tank;
  final AarFitCoverage coverage;
  final List<String> diagnostics;
  final String frameKey;
}

class AarComputationQualification {
  const AarComputationQualification({
    this.availability = AarMetricAvailability.available,
    this.confidentImprovement = true,
    this.limitations = const [],
    this.offenseIncomplete = false,
    this.constraintWarning = false,
    this.invalid = false,
  });

  final AarMetricAvailability availability;
  final bool confidentImprovement;
  final List<String> limitations;
  final bool offenseIncomplete;
  final bool constraintWarning;
  final bool invalid;
}

class AarComparisonFrame {
  AarComparisonFrame({
    required this.key,
    Map<String, CombatFitComputation>? columns,
  }) : columns = columns ?? <String, CombatFitComputation>{};

  final String key;
  final Map<String, CombatFitComputation> columns;

  /// Naive: publishes any result, including late keys.
  bool publish(
    String resultKey,
    String columnId,
    CombatFitComputation computation,
  ) {
    columns[columnId] = computation;
    return true;
  }

  static String requestKey({
    required Iterable<String> sourceFingerprints,
    required AarComparisonContext context,
  }) {
    return [
      ...sourceFingerprints,
      context.skillFingerprint,
      context.profileKey,
      context.sdeRevision,
      context.calculatorRevision,
    ].join('|');
  }
}

/// Compile stub for W4. GREEN uses shared ehpAgainst, one skill context,
/// tagged cap comparison, and late-result rejection.
class AarComparisonMetrics {
  /// Naive: always projects Omni stored EHP, ignoring [pattern].
  static LayeredEhp ehpFor(DefenseProfile defenses, DamagePattern pattern) {
    return LayeredEhp(
      pattern: pattern,
      shield: defenses.shieldEhp,
      armor: defenses.armorEhp,
      hull: defenses.hullEhp,
    );
  }

  static AarMetricValue delta(double baseline, double target) {
    return AarMetricValue(value: target - baseline);
  }

  /// Naive: divides even when baseline is 0 / nonfinite.
  static AarMetricValue percentDelta(double baseline, double target) {
    return AarMetricValue(value: (target - baseline) / baseline);
  }

  static AarMetricValue resistPp(
    double baselineFraction,
    double targetFraction,
  ) {
    return AarMetricValue(value: (targetFraction - baselineFraction) * 100);
  }

  static String formatEhp(double value) => value.toString();

  static String formatPercent(double fraction) => '${fraction * 100}';

  static String formatResistPp(double points) => points.toString();

  /// Naive: subtracts overloaded capacitorStable scalars.
  static String capTransition({
    required FittingStats baseline,
    required FittingStats target,
  }) {
    return (target.capacitorStable - baseline.capacitorStable).toString();
  }

  static String sustainedRepairLabel(FittingStats stats) => 'Modeled';

  static double weaponVolley(FittingStats stats) =>
      stats.volley + stats.dpsDrones + stats.dpsFighters;

  static bool constraintsLegal(FittingStats stats) {
    return stats.cpuUsed <= stats.cpuMax &&
        stats.powerUsed <= stats.powerMax &&
        stats.calibrationUsed <= stats.calibrationMax;
  }

  static AarSkillContext commonSkills({
    required List<CharacterSkill> cachedPilotSkills,
    required bool opponentColumn,
    int? characterId,
  }) {
    if (opponentColumn) {
      return const AarSkillContext(basis: AarSkillBasis.allFive, skills: []);
    }
    if (cachedPilotSkills.isEmpty) {
      return const AarSkillContext(basis: AarSkillBasis.allFive, skills: []);
    }
    return AarSkillContext(
      basis: AarSkillBasis.knownCharacter,
      skills: cachedPilotSkills,
      characterId: characterId,
    );
  }

  static String skillDisclosure(
    AarSkillContext skills, {
    required bool opponentColumn,
  }) {
    return skills.label;
  }

  static AarComputationQualification qualifyComputation({
    required AarFitSnapshot snapshot,
    required CombatFitComputation computation,
    required AarComparisonContext context,
  }) {
    final cpuExcess = computation.stats.cpuUsed > computation.stats.cpuMax;
    return AarComputationQualification(
      availability: AarMetricAvailability.available,
      confidentImprovement: true,
      offenseIncomplete: false,
      constraintWarning: false,
      invalid: cpuExcess,
      limitations: [if (cpuExcess) 'Fitting exceeds CPU and is invalid'],
    );
  }

  static List<DroneGroup> canonicalDrones(List<DroneGroup> drones) {
    return List<DroneGroup>.from(drones);
  }

  static List<FighterGroup> canonicalFighters(List<FighterGroup> fighters) {
    return List<FighterGroup>.from(fighters);
  }
}

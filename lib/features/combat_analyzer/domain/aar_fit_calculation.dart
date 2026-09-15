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

  bool publish(
    String resultKey,
    String columnId,
    CombatFitComputation computation,
  ) {
    if (resultKey != key) return false;
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

class AarComparisonMetrics {
  static LayeredEhp ehpFor(DefenseProfile defenses, DamagePattern pattern) {
    return defenses.ehpAgainst(pattern);
  }

  static AarMetricValue delta(double baseline, double target) {
    if (!_finite(baseline) || !_finite(target)) {
      return const AarMetricValue(
        availability: AarMetricAvailability.unavailable,
      );
    }
    return AarMetricValue(value: target - baseline);
  }

  static AarMetricValue percentDelta(double baseline, double target) {
    if (!_finite(baseline) || !_finite(target) || baseline <= 0) {
      return const AarMetricValue(
        availability: AarMetricAvailability.unavailable,
      );
    }
    return AarMetricValue(value: (target - baseline) / baseline);
  }

  static AarMetricValue resistPp(
    double baselineFraction,
    double targetFraction,
  ) {
    if (!_finite(baselineFraction) || !_finite(targetFraction)) {
      return const AarMetricValue(
        availability: AarMetricAvailability.unavailable,
      );
    }
    return AarMetricValue(
      value: (targetFraction - baselineFraction) * 100,
      unit: 'pp',
    );
  }

  static String formatEhp(double value) {
    final n = value.round();
    final sign = n < 0 ? '-' : '';
    final digits = n.abs().toString();
    final buf = StringBuffer(sign);
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  static String formatPercent(double fraction) {
    if (!_finite(fraction)) return '—';
    return '${(fraction * 100).toStringAsFixed(1)}%';
  }

  static String formatResistPp(double points) {
    if (!_finite(points)) return '—';
    final n = points.round();
    final sign = n > 0 ? '+' : '';
    return '$sign$n pp';
  }

  static String capTransition({
    required FittingStats baseline,
    required FittingStats target,
  }) {
    if (!baseline.isCapStable && target.isCapStable) {
      return 'Depleting → Modeled stable';
    }
    if (baseline.isCapStable && !target.isCapStable) {
      return 'Modeled stable → Depleting';
    }
    if (baseline.isCapStable && target.isCapStable) {
      return '${baseline.capacitorStable.round()}% → ${target.capacitorStable.round()}%';
    }
    return '${baseline.capacitorStable.round()}s → ${target.capacitorStable.round()}s';
  }

  static String sustainedRepairLabel(FittingStats stats) => 'Not modeled';

  static double weaponVolley(FittingStats stats) => stats.volley;

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
    if (cachedPilotSkills.isEmpty) {
      return AarSkillContext(
        basis: AarSkillBasis.allFive,
        skills: const [],
        characterId: characterId,
      );
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
    if (opponentColumn) {
      return 'Modeled with comparison skills; opponent skills unknown';
    }
    return skills.label;
  }

  static AarComputationQualification qualifyComputation({
    required AarFitSnapshot snapshot,
    required CombatFitComputation computation,
    required AarComparisonContext context,
  }) {
    final unknownCharge = snapshot.knowledge.occurrences.any(
      (occurrence) => occurrence.charge == ChargeKnowledge.unknown,
    );
    final unknownModules = _hasUnknownModules(snapshot);
    final missingDroneFighter = _missingDroneFighterKnowledge(snapshot);
    final offenseIncomplete = unknownCharge || missingDroneFighter;
    final constraintWarning = !constraintsLegal(computation.stats);
    final qualified = unknownModules || offenseIncomplete;
    return AarComputationQualification(
      availability: qualified
          ? AarMetricAvailability.partial
          : AarMetricAvailability.available,
      confidentImprovement: !qualified,
      offenseIncomplete: offenseIncomplete,
      constraintWarning: constraintWarning,
      invalid: false,
      limitations: [
        if (unknownCharge) 'Loaded charges are unknown',
        if (unknownModules) 'Unresolved or omitted modules qualify these stats',
        if (constraintWarning) 'Fitting exceeds CPU/PG/calibration budget',
      ],
    );
  }

  static List<DroneGroup> canonicalDrones(List<DroneGroup> drones) {
    final copy = List<DroneGroup>.from(drones);
    copy.sort((a, b) {
      final type = a.typeId.compareTo(b.typeId);
      if (type != 0) return type;
      final space = a.inSpace.compareTo(b.inSpace);
      if (space != 0) return space;
      final bay = a.inBay.compareTo(b.inBay);
      if (bay != 0) return bay;
      return a.quantity.compareTo(b.quantity);
    });
    return copy;
  }

  static List<FighterGroup> canonicalFighters(List<FighterGroup> fighters) {
    final copy = List<FighterGroup>.from(fighters);
    copy.sort((a, b) {
      final type = a.typeId.compareTo(b.typeId);
      if (type != 0) return type;
      final space = a.inSpace.compareTo(b.inSpace);
      if (space != 0) return space;
      return a.quantity.compareTo(b.quantity);
    });
    return copy;
  }

  static bool _finite(double value) => value.isFinite && !value.isNaN;

  static bool _hasUnknownModules(AarFitSnapshot snapshot) {
    if (snapshot.knowledge.unplacedEntries.isNotEmpty) return true;
    const moduleGroups = {
      FitInventoryGroup.high,
      FitInventoryGroup.mid,
      FitInventoryGroup.low,
      FitInventoryGroup.rigs,
      FitInventoryGroup.subsystems,
    };
    for (final group in moduleGroups) {
      final info = snapshot.knowledge.group(group);
      if (info.applicability == GroupApplicability.notApplicable) continue;
      if (info.completeness == InventoryCompleteness.unknown ||
          info.completeness == InventoryCompleteness.partial) {
        return true;
      }
    }
    return false;
  }

  static bool _missingDroneFighterKnowledge(AarFitSnapshot snapshot) {
    for (final group in [
      FitInventoryGroup.drones,
      FitInventoryGroup.fighters,
    ]) {
      final info = snapshot.knowledge.group(group);
      if (info.applicability == GroupApplicability.notApplicable) continue;
      if (info.completeness == InventoryCompleteness.unknown) return true;
    }
    return false;
  }
}

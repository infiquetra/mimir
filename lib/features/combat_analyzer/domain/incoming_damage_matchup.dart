import '../../fitting/domain/damage_pattern.dart';
import 'damage_matchup_assessment.dart';
import 'incoming_damage_allocation.dart';
import 'tank_classifier.dart';

enum IncomingDefenseStatus {
  available,
  noTypedDamage,
  pilotDefenseUnavailable,
  invalidDefense,
  numericPrecisionUnavailable,
}

enum IncomingPressureStatus {
  available,
  unknownLayer,
  zeroDenominator,
  unavailable,
}

final class IncomingResistResult {
  const IncomingResistResult({
    required this.type,
    required this.profileFraction,
    required this.assessment,
    this.resistPercent,
    this.modeledPressure,
  });

  final IncomingDamageType type;
  final double profileFraction;
  final double? resistPercent;
  final double? modeledPressure;
  final DamageMatchupAssessment assessment;
}

final class AarIncomingDefenseMatchup {
  const AarIncomingDefenseMatchup({
    required this.status,
    required this.pressureStatus,
    required this.layer,
    required this.entries,
    required this.guardedLayers,
    required this.limitationCodes,
    this.pattern,
    this.ehp,
    this.omniEhp,
    this.primaryHole,
    this.pilotFitKey,
  });

  final IncomingDefenseStatus status;
  final IncomingPressureStatus pressureStatus;
  final DamagePattern? pattern;
  final LayeredEhp? ehp;
  final LayeredEhp? omniEhp;
  final TankLayer layer;
  final List<IncomingResistResult> entries;
  final IncomingDamageType? primaryHole;
  final List<TankLayer> guardedLayers;
  final List<String> limitationCodes;
  final String? pilotFitKey;
}

import '../../fitting/domain/models.dart';
import 'combat_damage_matchup.dart';
import 'combat_evidence_ledger.dart';
import 'tank_classifier.dart';

enum AarFitSubject { self, opponent }

enum AarSkillBasis { knownCharacter, allFive }

class AarSkillContext {
  const AarSkillContext({
    required this.basis,
    required this.skills,
    this.characterId,
  });

  final AarSkillBasis basis;
  final List<CharacterSkill> skills;
  final int? characterId;

  String get label => switch (basis) {
    AarSkillBasis.knownCharacter =>
      'Character skills (ESI, character $characterId)',
    AarSkillBasis.allFive => 'assumes All V',
  };

  EvidenceConfidence get confidence => switch (basis) {
    AarSkillBasis.knownCharacter => EvidenceConfidence.derived,
    AarSkillBasis.allFive => EvidenceConfidence.reference,
  };
}

class AarFitCoverage {
  const AarFitCoverage({
    required this.highFitted,
    required this.highSlots,
    required this.medFitted,
    required this.medSlots,
    required this.lowFitted,
    required this.lowSlots,
    required this.rigFitted,
    required this.rigSlots,
    required this.subsystemFitted,
    required this.subsystemSlots,
    required this.unresolvedTypeIds,
    required this.unresolvedNames,
  });

  final int highFitted;
  final int highSlots;
  final int medFitted;
  final int medSlots;
  final int lowFitted;
  final int lowSlots;
  final int rigFitted;
  final int rigSlots;
  final int subsystemFitted;
  final int subsystemSlots;
  final List<int> unresolvedTypeIds;
  final List<String> unresolvedNames;

  bool get hasUnresolved => unresolvedTypeIds.isNotEmpty;

  String describe() => '';

  static AarFitCoverage of(
    Fitting fitting,
    ShipType ship,
    Map<int, String> unresolved,
  ) {
    return AarFitCoverage(
      highFitted: 0,
      highSlots: 0,
      medFitted: 0,
      medSlots: 0,
      lowFitted: 0,
      lowSlots: 0,
      rigFitted: 0,
      rigSlots: 0,
      subsystemFitted: 0,
      subsystemSlots: 0,
      unresolvedTypeIds: unresolved.keys.toList(),
      unresolvedNames: unresolved.values.toList(),
    );
  }
}

class AarFitDerivation {
  const AarFitDerivation({
    required this.role,
    required this.subject,
    required this.fitSource,
    required this.shipTypeId,
    required this.shipName,
    required this.skills,
    required this.stats,
    required this.baseline,
    required this.tank,
    required this.coverage,
    required this.derivedAt,
    this.limitations = const [],
  });

  final FitEvidenceRole role;
  final AarFitSubject subject;
  final EvidenceSource fitSource;
  final int shipTypeId;
  final String shipName;
  final AarSkillContext skills;
  final FittingStats stats;
  final FittingStats baseline;
  final TankAssessment tank;
  final AarFitCoverage coverage;
  final DateTime derivedAt;
  final List<String> limitations;

  Map<String, dynamic> toPromptJson() => {
    'role': role.name,
    'subject': subject.name,
    'shipTypeId': shipTypeId,
    'shipName': shipName,
  };
}

sealed class AarFitDerivationResult {}

class AarFitDerived extends AarFitDerivationResult {
  AarFitDerived(this.derivation);
  final AarFitDerivation derivation;
}

class AarFitDerivationFailed extends AarFitDerivationResult {
  AarFitDerivationFailed({required this.unknown, required this.reason});
  final AarUnknown unknown;
  final String reason;
}

class AarDerivationBundle {
  const AarDerivationBundle({
    this.self,
    this.opponent,
    this.selfMatchup,
    this.opponentMatchup,
    this.unknowns = const [],
  });

  final AarFitDerivation? self;
  final AarFitDerivation? opponent;
  final CombatDamageMatchup? selfMatchup;
  final CombatDamageMatchup? opponentMatchup;
  final List<AarUnknown> unknowns;

  bool get isEmpty => self == null && opponent == null;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_providers.dart';
import '../../../core/sde/sde_service.dart';
import '../../skills/data/skill_repository.dart';
import '../domain/aar_fit_derivation.dart';
import '../domain/combat_damage_profile.dart';
import '../domain/combat_enrichment.dart';
import '../domain/combat_evidence_ledger.dart';
import '../domain/combat_fit_deriver.dart';
import '../domain/parsed_combat_encounter.dart';

final combatFitDerivationServiceProvider = Provider<CombatFitDerivationService>(
  (ref) {
    Log.d('AAR', 'combatFitDerivationServiceProvider() - START');
    return CombatFitDerivationService(
      sde: ref.watch(sdeServiceProvider),
      skills: ref.watch(skillRepositoryProvider),
    );
  },
);

/// U3 stub: Devs implement §4.2 (skill context, loadFittingStatsInputs, matchup).
class CombatFitDerivationService {
  CombatFitDerivationService({
    required SdeService sde,
    required SkillRepository skills,
    CombatFitDeriver deriver = const CombatFitDeriver(),
  }) : _sde = sde,
       _skills = skills,
       _deriver = deriver;

  final SdeService _sde;
  final SkillRepository _skills;
  final CombatFitDeriver _deriver;

  Future<AarDerivationBundle> deriveForEncounter({
    required ParsedCombatEncounter encounter,
    required CombatEnrichment enrichment,
    required CombatDamageProfile incoming,
    required CombatDamageProfile outgoing,
  }) async {
    Log.d(
      'AAR',
      'deriveForEncounter(${encounter.id}) stub '
          'sde=${_sde.isInitialized} deriver=${_deriver.runtimeType}',
    );
    return const AarDerivationBundle.empty();
  }

  Future<AarFitDerivationResult> deriveEvidence(
    FitEvidence evidence, {
    required AarFitSubject subject,
    required AarSkillContext skills,
  }) async {
    Log.d(
      'AAR',
      'deriveEvidence ship=${evidence.fitting.shipTypeId} stub '
          'skills=${_skills.runtimeType}',
    );
    return AarFitDerivationFailed(
      unknown: const AarUnknown(
        category: AarUnknownCategory.pilotFit,
        label: 'stub',
        detail: 'U3 stub',
      ),
      reason: 'stub',
    );
  }

  Future<AarSkillContext> skillContextFor({
    required AarFitSubject subject,
    int? characterId,
  }) async {
    Log.d(
      'AAR',
      'skillContextFor subject=${subject.name} characterId=$characterId stub',
    );
    return const AarSkillContext(basis: AarSkillBasis.allFive, skills: []);
  }
}

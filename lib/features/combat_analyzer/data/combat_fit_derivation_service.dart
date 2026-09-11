import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_providers.dart';
import '../../../core/sde/sde_service.dart';
import '../../fitting/data/fitting_stats_inputs.dart';
import '../../fitting/domain/models.dart';
import '../../skills/data/skill_repository.dart';
import '../domain/aar_derived_facts.dart';
import '../domain/aar_fit_derivation.dart';
import '../domain/combat_damage_matchup.dart';
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
  List<CharacterSkill>? _allFiveSkills;

  Future<AarDerivationBundle> deriveForEncounter({
    required ParsedCombatEncounter encounter,
    required CombatEnrichment enrichment,
    required CombatDamageProfile incoming,
    required CombatDamageProfile outgoing,
  }) async {
    Log.d('AAR', 'deriveForEncounter(${encounter.id}) - START');
    if (!_sde.isInitialized) {
      await _sde.initialize();
    }

    final failedUnknowns = <AarUnknown>[];
    AarFitDerivation? self;
    AarFitDerivation? opponent;

    final pilotEvidence = enrichment.pilotFitEvidence;
    final victimEvidence = enrichment.victimFitEvidence;
    final victimIsSelf =
        victimEvidence != null &&
        enrichment.victimCharacterId != null &&
        enrichment.victimCharacterId == encounter.characterId;
    final hasPilotEvidence = pilotEvidence != null;
    final hasOpponentEvidence = victimEvidence != null && !victimIsSelf;

    if (pilotEvidence != null) {
      final skills = await skillContextFor(
        subject: AarFitSubject.self,
        characterId: encounter.characterId,
      );
      final result = await deriveEvidence(
        pilotEvidence,
        subject: AarFitSubject.self,
        skills: skills,
      );
      if (result is AarFitDerived) {
        self = result.derivation;
      } else if (result is AarFitDerivationFailed) {
        failedUnknowns.add(result.unknown);
      }
    }

    if (victimEvidence != null) {
      if (victimIsSelf && self != null) {
        Log.i(
          'AAR',
          'pilot evidence wins over self-victim killmail for ${encounter.id}',
        );
      } else {
        final subject = victimIsSelf
            ? AarFitSubject.self
            : AarFitSubject.opponent;
        final skills = await skillContextFor(
          subject: subject,
          characterId: victimIsSelf ? encounter.characterId : null,
        );
        final result = await deriveEvidence(
          victimEvidence,
          subject: subject,
          skills: skills,
        );
        if (result is AarFitDerived) {
          if (subject == AarFitSubject.self) {
            self = result.derivation;
          } else {
            opponent = result.derivation;
          }
        } else if (result is AarFitDerivationFailed) {
          failedUnknowns.add(result.unknown);
        }
      }
    }

    final selfMatchup = CombatDamageMatchupAnalyzer.analyze(
      profile: incoming,
      defense: self?.stats.defenses,
      tank: self?.tank,
      targetLabel: encounter.characterName,
    );
    final opponentMatchup = CombatDamageMatchupAnalyzer.analyze(
      profile: outgoing,
      defense: opponent?.stats.defenses,
      tank: opponent?.tank,
      targetLabel: enrichment.victimName ?? 'Opponent',
    );
    final bundle = AarDerivationBundle(
      self: self,
      opponent: opponent,
      selfMatchup: selfMatchup,
      opponentMatchup: opponentMatchup,
      unknowns: [
        ...failedUnknowns,
        ...AarDerivedFactsBuilder.unknownsFor(
          AarDerivationBundle(self: self, opponent: opponent),
          hasPilotEvidence: hasPilotEvidence,
          hasOpponentEvidence: hasOpponentEvidence,
          incoming: incoming,
        ),
      ],
    );
    Log.i(
      'AAR',
      'deriveForEncounter(${encounter.id}) self=${self != null} '
          'opponent=${opponent != null} unknowns=${bundle.unknowns.length}',
    );
    return bundle;
  }

  Future<AarFitDerivationResult> deriveEvidence(
    FitEvidence evidence, {
    required AarFitSubject subject,
    required AarSkillContext skills,
  }) async {
    Log.d(
      'AAR',
      'deriveEvidence ship=${evidence.fitting.shipTypeId} '
          'subject=${subject.name} basis=${skills.basis.name}',
    );
    final unknownCategory = subject == AarFitSubject.self
        ? AarUnknownCategory.pilotFit
        : AarUnknownCategory.opponentFit;
    final inputs = await loadFittingStatsInputs(
      _sde,
      evidence.fitting,
      skillTypeIds: skills.skills.map((skill) => skill.skillId),
    );
    if (inputs == null) {
      return AarFitDerivationFailed(
        unknown: AarUnknown(
          category: unknownCategory,
          label: 'Ship type not in SDE',
          detail:
              'Ship type ${evidence.fitting.shipTypeId} '
              '(${evidence.fitting.shipName}) is not in the bundled SDE.',
        ),
        reason: 'Ship type not in SDE',
      );
    }
    try {
      final derivation = await _deriver.derive(
        evidence: evidence,
        subject: subject,
        inputs: inputs,
        skills: skills,
      );
      return AarFitDerived(derivation);
    } catch (e, stack) {
      Log.e('AAR', 'deriveEvidence engine error', e, stack);
      return AarFitDerivationFailed(
        unknown: AarUnknown(
          category: unknownCategory,
          label: 'Fit derivation failed',
          detail:
              'The dogma engine failed while deriving '
              '${evidence.fitting.shipName}.',
        ),
        reason: 'engine error',
      );
    }
  }

  Future<AarSkillContext> skillContextFor({
    required AarFitSubject subject,
    int? characterId,
  }) async {
    Log.d(
      'AAR',
      'skillContextFor subject=${subject.name} characterId=$characterId',
    );
    if (subject == AarFitSubject.self && characterId != null) {
      final rows = await _skills.getCharacterSkills(characterId);
      if (rows.isNotEmpty) {
        return AarSkillContext(
          basis: AarSkillBasis.knownCharacter,
          skills: [
            for (final row in rows)
              CharacterSkill(
                skillId: row.skillId,
                level: row.trainedSkillLevel,
              ),
          ],
          characterId: characterId,
        );
      }
    }
    return AarSkillContext(
      basis: AarSkillBasis.allFive,
      skills: await _loadAllFiveSkills(),
    );
  }

  Future<List<CharacterSkill>> _loadAllFiveSkills() async {
    final cached = _allFiveSkills;
    if (cached != null) return cached;
    final types = await _sde.database.getAllSkills();
    final skills = [
      for (final type in types) CharacterSkill(skillId: type.typeId, level: 5),
    ];
    _allFiveSkills = skills;
    Log.d('AAR', 'cached All V skill list length=${skills.length}');
    return skills;
  }
}

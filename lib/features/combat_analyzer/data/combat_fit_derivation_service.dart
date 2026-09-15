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
import '../domain/incoming_damage_allocation.dart';
import '../domain/incoming_damage_matchup.dart';
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
    IncomingDamageAllocation? incomingAllocation,
  }) async {
    Log.d('AAR', 'deriveForEncounter(${encounter.id}) - START');
    final fits = await deriveFitsForEncounter(
      encounter: encounter,
      enrichment: enrichment,
      selfSkills: null,
      opponentSkills: null,
    );
    if (incomingAllocation != null) {
      final composed = composeMatchups(
        fits: fits,
        incoming: incomingAllocation,
        outgoing: outgoing,
        encounter: encounter,
        enrichment: enrichment,
      );
      return AarDerivationBundle(
        self: composed.self,
        opponent: composed.opponent,
        selfMatchup: composed.selfMatchup,
        opponentMatchup: composed.opponentMatchup,
        unknowns: [
          ...composed.unknowns,
          ...AarDerivedFactsBuilder.unknownsFor(
            AarDerivationBundle(
              self: composed.self,
              opponent: composed.opponent,
            ),
            hasPilotEvidence: enrichment.pilotFitEvidence != null,
            hasOpponentEvidence:
                enrichment.victimFitEvidence != null &&
                enrichment.victimCharacterId != encounter.characterId,
            incoming: incoming,
          ),
        ],
      );
    }

    final selfMatchup = CombatDamageMatchupAnalyzer.analyze(
      profile: incoming,
      defense: fits.self?.stats.defenses,
      tank: fits.self?.tank,
      targetLabel: encounter.characterName,
    );
    final opponentMatchup = CombatDamageMatchupAnalyzer.analyze(
      profile: outgoing,
      defense: fits.opponent?.stats.defenses,
      tank: fits.opponent?.tank,
      targetLabel: enrichment.victimName ?? 'Opponent',
    );
    final bundle = AarDerivationBundle(
      self: fits.self,
      opponent: fits.opponent,
      selfMatchup: selfMatchup,
      opponentMatchup: opponentMatchup,
      unknowns: [
        ...fits.unknowns,
        ...AarDerivedFactsBuilder.unknownsFor(
          AarDerivationBundle(self: fits.self, opponent: fits.opponent),
          hasPilotEvidence: enrichment.pilotFitEvidence != null,
          hasOpponentEvidence:
              enrichment.victimFitEvidence != null &&
              enrichment.victimCharacterId != encounter.characterId,
          incoming: incoming,
        ),
      ],
    );
    Log.i(
      'AAR',
      'deriveForEncounter(${encounter.id}) self=${fits.self != null} '
          'opponent=${fits.opponent != null} unknowns=${bundle.unknowns.length}',
    );
    return bundle;
  }

  Future<AarDerivationBundle> deriveFitsForEncounter({
    required ParsedCombatEncounter encounter,
    required CombatEnrichment enrichment,
    required AarSkillContext? selfSkills,
    required AarSkillContext? opponentSkills,
    List<String> selfInputIssues = const [],
    List<String> opponentInputIssues = const [],
  }) async {
    Log.d('AAR.MATCHUP', 'deriveFitsForEncounter(${encounter.id}) - START');
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

    Future<AarSkillContext> skillsFor(
      AarFitSubject subject,
      AarSkillContext? override,
      List<String> issues,
    ) async {
      if (issues.isNotEmpty && override == null) {
        throw StateError('unavailable skill context');
      }
      if (override != null) return override;
      return skillContextFor(
        subject: subject,
        characterId: subject == AarFitSubject.self
            ? encounter.characterId
            : null,
      );
    }

    if (pilotEvidence != null) {
      try {
        final skills = await skillsFor(
          AarFitSubject.self,
          selfSkills,
          selfInputIssues,
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
      } catch (e, stack) {
        Log.e('AAR.MATCHUP', 'self fit derivation unavailable', e, stack);
        failedUnknowns.add(
          const AarUnknown(
            category: AarUnknownCategory.pilotFit,
            label: 'Pilot fit unavailable',
            detail: 'Self fit derivation was unavailable.',
          ),
        );
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
        try {
          final skills = await skillsFor(
            subject,
            subject == AarFitSubject.self ? selfSkills : opponentSkills,
            subject == AarFitSubject.self
                ? selfInputIssues
                : opponentInputIssues,
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
        } catch (e, stack) {
          Log.e('AAR.MATCHUP', 'victim fit derivation unavailable', e, stack);
          failedUnknowns.add(
            AarUnknown(
              category: victimIsSelf
                  ? AarUnknownCategory.pilotFit
                  : AarUnknownCategory.opponentFit,
              label: 'Fit derivation unavailable',
              detail: 'Fit derivation was unavailable.',
            ),
          );
        }
      }
    }

    Log.i(
      'AAR.MATCHUP',
      'deriveFitsForEncounter(${encounter.id}) self=${self != null} '
          'opponent=${opponent != null}',
    );
    return AarDerivationBundle(
      self: self,
      opponent: opponent,
      unknowns: failedUnknowns,
    );
  }

  AarDerivationBundle composeMatchups({
    required AarDerivationBundle fits,
    required IncomingDamageAllocation? incoming,
    required CombatDamageProfile? outgoing,
    required ParsedCombatEncounter encounter,
    required CombatEnrichment enrichment,
  }) {
    Log.d(
      'AAR.MATCHUP',
      'composeMatchups(${encounter.id}) incoming=${incoming != null} '
          'outgoing=${outgoing != null}',
    );
    CombatDamageMatchup? selfMatchup;
    if (incoming != null) {
      final incomingDefense = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: incoming.components,
        defense: fits.self?.stats.defenses,
        tank: fits.self?.tank,
        pilotFitKey: fits.self?.shipName,
      );
      selfMatchup = _projectIncomingMatchup(
        incomingDefense,
        encounter.characterName,
      );
    }
    CombatDamageMatchup? opponentMatchup;
    if (outgoing != null) {
      opponentMatchup = CombatDamageMatchupAnalyzer.analyze(
        profile: outgoing,
        defense: fits.opponent?.stats.defenses,
        tank: fits.opponent?.tank,
        targetLabel: enrichment.victimName ?? 'Opponent',
      );
    }
    return AarDerivationBundle(
      self: fits.self,
      opponent: fits.opponent,
      selfMatchup: selfMatchup,
      opponentMatchup: opponentMatchup,
      unknowns: fits.unknowns,
    );
  }

  CombatDamageMatchup _projectIncomingMatchup(
    AarIncomingDefenseMatchup defense,
    String targetLabel,
  ) {
    const labels = {
      IncomingDamageType.em: 'EM',
      IncomingDamageType.thermal: 'Thermal',
      IncomingDamageType.kinetic: 'Kinetic',
      IncomingDamageType.explosive: 'Explosive',
    };
    return CombatDamageMatchup(
      targetLabel: targetLabel,
      layer: defense.layer.name,
      summary: defense.status == IncomingDefenseStatus.available
          ? 'Incoming defense vs $targetLabel ${defense.layer.name} resists.'
          : 'Incoming defense unavailable for $targetLabel.',
      entries: [
        for (final entry in defense.entries)
          CombatDamageMatchupEntry(
            type: labels[entry.type] ?? entry.type.name,
            amount: 0,
            percent: entry.profileFraction,
            assessment: entry.assessment,
            evidence: 'Canonical incoming allocation vs $targetLabel.',
            resistPercent: entry.resistPercent,
            appliedPercent: entry.modeledPressure,
          ),
      ],
      pattern: defense.pattern,
      ehpAgainstPattern: defense.ehp,
      ehpOmni: defense.omniEhp,
      primaryHole: defense.primaryHole == null
          ? null
          : labels[defense.primaryHole!],
    );
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
      effectLookupPolicy: EffectLookupPolicy.localOnly,
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
      try {
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
      } catch (e, stack) {
        Log.e('AAR', 'skillContextFor unavailable', e, stack);
        rethrow;
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

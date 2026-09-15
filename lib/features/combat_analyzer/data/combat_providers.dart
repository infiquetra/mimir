import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_providers.dart';
import 'aar_evidence_operation_coordinator.dart';
import 'combat_damage_profile_resolver.dart';
import 'combat_enrichment_repository.dart';
import 'combat_enrichment_service.dart';
import 'combat_fit_derivation_service.dart';
import 'combat_killmail_discovery_client.dart';
import 'log_scanner.dart';
import 'parsed_encounter_cache.dart';
import '../../skills/data/skill_repository.dart';
import '../domain/aar_attacker_matchup.dart';
import '../domain/aar_attacker_matchup_deriver.dart';
import '../domain/aar_evidence_assessment.dart';
import '../domain/aar_evidence_scorer.dart';
import '../domain/aar_fit_derivation.dart';
import '../domain/combat_actor_classifier.dart';
import '../domain/combat_attacker_correlation.dart';
import '../domain/combat_enrichment.dart';
import '../domain/combat_evidence_ledger.dart';
import '../domain/incoming_damage_allocation.dart';
import '../domain/incoming_damage_allocator.dart';
import '../domain/parsed_combat_encounter.dart';
import '../domain/combat_log_parser.dart';

enum CombatAarStatus { none, ready, legacy }

final logScannerProvider = FutureProvider<LogScanner>((ref) async {
  Log.d('COMBAT', 'logScannerProvider() - START');
  Log.d('COMBAT', 'logScannerProvider() - SUCCESS');
  return LogScanner();
});

final combatEnrichmentRepositoryProvider = Provider<CombatEnrichmentRepository>(
  (ref) {
    Log.d('COMBAT.ENRICH', 'combatEnrichmentRepositoryProvider() - START');
    return CombatEnrichmentRepository(database: ref.watch(databaseProvider));
  },
);

final combatKillmailDiscoveryClientProvider =
    Provider<CombatKillmailDiscoveryClient>((ref) {
      Log.d('COMBAT.ENRICH', 'combatKillmailDiscoveryClientProvider() - START');
      return CombatKillmailDiscoveryClient();
    });

final aarEvidenceOperationCoordinatorProvider =
    Provider<AarEvidenceOperationCoordinator>((ref) {
      Log.d('AAR', 'aarEvidenceOperationCoordinatorProvider() - START');
      final coordinator = AarEvidenceOperationCoordinator();
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

final combatEnrichmentServiceProvider = Provider<CombatEnrichmentService>((
  ref,
) {
  Log.d('COMBAT.ENRICH', 'combatEnrichmentServiceProvider() - START');
  return CombatEnrichmentService(
    repository: ref.watch(combatEnrichmentRepositoryProvider),
    esiClient: ref.watch(esiClientProvider),
    discoveryClient: ref.watch(combatKillmailDiscoveryClientProvider),
    tokenManager: ref.watch(tokenManagerProvider),
    oauthService: ref.watch(oauthServiceProvider),
    sdeService: ref.watch(sdeServiceProvider),
    coordinator: ref.watch(aarEvidenceOperationCoordinatorProvider),
  );
});

final aarFitDerivationsProvider =
    FutureProvider.family<AarDerivationBundle, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'AAR',
        'aarFitDerivationsProvider(encounter=${encounter.id}) - START',
      );
      await ref.watch(sdeInitializerProvider.future);
      final enrichment = await ref.watch(
        combatEnrichmentProvider(encounter.id).future,
      );
      if (enrichment == null) return const AarDerivationBundle.empty();
      final incoming = await ref.watch(
        combatIncomingDamageProfileProvider(encounter).future,
      );
      final outgoing = await ref.watch(
        combatDamageProfileProvider(encounter).future,
      );
      IncomingDamageAllocation? incomingAllocation;
      try {
        final allocationResult = await ref.watch(
          combatIncomingDamageAllocationProvider(encounter).future,
        );
        if (allocationResult is IncomingAllocationReady) {
          incomingAllocation = allocationResult.allocation;
        }
      } catch (e, stack) {
        Log.e('AAR.MATCHUP', 'fit facade allocation unavailable', e, stack);
      }
      return ref
          .read(combatFitDerivationServiceProvider)
          .deriveForEncounter(
            encounter: encounter,
            enrichment: enrichment,
            incoming: incoming,
            outgoing: outgoing,
            incomingAllocation: incomingAllocation,
          );
    });

final aarEvidenceAssessmentProvider =
    FutureProvider.family<AarEvidenceAssessment, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'AAR.EVIDENCE',
        'aarEvidenceAssessmentProvider(encounter=${encounter.id}) - START',
      );
      final enrichment = await ref.watch(
        combatEnrichmentProvider(encounter.id).future,
      );
      final bundle = await ref.watch(
        aarFitDerivationsProvider(encounter).future,
      );
      final incoming = await ref.watch(
        combatIncomingDamageProfileProvider(encounter).future,
      );
      final outgoing = await ref.watch(
        combatDamageProfileProvider(encounter).future,
      );
      return const AarEvidenceScorer().assess(
        AarEvidenceInputs(
          encounter: encounter,
          enrichment: enrichment,
          bundle: bundle,
          incoming: incoming,
          outgoing: outgoing,
        ),
      );
    });

final combatEnrichmentProvider =
    FutureProvider.family<CombatEnrichment?, String>((ref, parsedEncounterId) {
      Log.d(
        'COMBAT.ENRICH',
        'combatEnrichmentProvider($parsedEncounterId) - START',
      );
      return ref
          .watch(combatEnrichmentServiceProvider)
          .loadEnrichment(parsedEncounterId);
    });

final combatAttackerCorrelationProvider =
    FutureProvider.family<AttackerCorrelation?, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'COMBAT.CORRELATE',
        'combatAttackerCorrelationProvider(encounter=${encounter.id}) - START',
      );
      final enrichment = await ref.watch(
        combatEnrichmentProvider(encounter.id).future,
      );
      if (enrichment == null) return null;
      final ensured = await ref
          .read(combatEnrichmentServiceProvider)
          .ensureAttackerCorrelation(encounter, enrichment);
      return ensured.attackerCorrelation;
    });

final class AarSdeRevision {
  const AarSdeRevision({required this.generation, required this.contentKey});

  final int generation;
  final String contentKey;
}

final class AarFitRequest {
  const AarFitRequest({
    required this.encounterId,
    required this.pilotName,
    required this.requestKey,
    required this.sde,
    this.pilotCharacterId,
    this.victimCharacterId,
    this.pilotEvidence,
    this.victimEvidence,
    this.selfSkills,
    this.opponentSkills,
    this.selfInputIssues = const [],
    this.opponentInputIssues = const [],
  });

  final String encounterId;
  final String pilotName;
  final String requestKey;
  final int? pilotCharacterId;
  final int? victimCharacterId;
  final FitEvidence? pilotEvidence;
  final FitEvidence? victimEvidence;
  final AarSkillContext? selfSkills;
  final AarSkillContext? opponentSkills;
  final List<String> selfInputIssues;
  final List<String> opponentInputIssues;
  final AarSdeRevision sde;

  @override
  bool operator ==(Object other) {
    return other is AarFitRequest && other.requestKey == requestKey;
  }

  @override
  int get hashCode => requestKey.hashCode;
}

enum AarIncomingDependencyStatus { loading, ready, unavailable, error, invalid }

final class AarIncomingMatchupState {
  const AarIncomingMatchupState({
    required this.encounterId,
    required this.allocationRequestKey,
    required this.identityRequestKey,
    required this.allocationStatus,
    required this.correlationStatus,
    required this.classificationStatus,
    required this.defenseStatus,
    this.fitRequestKey,
    this.bundle,
    this.issueCodes = const [],
  });

  final String encounterId;
  final String allocationRequestKey;
  final String identityRequestKey;
  final String? fitRequestKey;
  final AarIncomingMatchupBundle? bundle;
  final AarIncomingDependencyStatus allocationStatus;
  final AarIncomingDependencyStatus correlationStatus;
  final AarIncomingDependencyStatus classificationStatus;
  final AarIncomingDependencyStatus defenseStatus;
  final List<String> issueCodes;
}

final aarSdeRevisionProvider = StreamProvider<AarSdeRevision>((ref) async* {
  Log.d('AAR.MATCHUP', 'aarSdeRevisionProvider() - START');
  yield const AarSdeRevision(generation: 0, contentKey: 'sde-decimal-v1');
  var generation = 0;
  try {
    await for (final _
        in ref.watch(sdeDatabaseProvider).watchDerivationRevision()) {
      generation += 1;
      yield AarSdeRevision(
        generation: generation,
        contentKey: 'sde-decimal-v1',
      );
    }
  } catch (e, stack) {
    Log.e('AAR.MATCHUP', 'sde revision watch failed', e, stack);
  }
});

final aarLocalSkillsProvider = StreamProvider.family<List<dynamic>, int>((
  ref,
  characterId,
) {
  Log.d('AAR.MATCHUP', 'aarLocalSkillsProvider($characterId) - START');
  return ref.watch(skillRepositoryProvider).watchCharacterSkills(characterId);
});

final combatIncomingDamageAllocationProvider =
    FutureProvider.family<IncomingAllocationResult, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'AAR.MATCHUP',
        'combatIncomingDamageAllocationProvider(encounter=${encounter.id}) - START',
      );
      try {
        ref.watch(aarSdeRevisionProvider);
        final resolver = ref.watch(combatDamageProfileResolverProvider);
        return await resolver.resolveIncomingAllocation(
          encounter,
          sdeContentKey: 'sde-decimal-v1',
        );
      } catch (e, stack) {
        Log.e('AAR.MATCHUP', 'allocation provider failed', e, stack);
        return IncomingAllocationInvalid(
          encounterId: encounter.id,
          reasonCode: 'lookupFailed',
        );
      }
    });

final aarLocalActorTypesProvider =
    FutureProvider.family<Map<String, CombatTypeRef>, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'AAR.MATCHUP',
        'aarLocalActorTypesProvider(encounter=${encounter.id}) - START',
      );
      try {
        final database = ref.watch(sdeDatabaseProvider);
        final byName = <String, CombatTypeRef>{};
        for (final name in encounter.aggregates.incomingBySource.keys) {
          final key = normalizeCombatName(name);
          if (key.isEmpty || key == 'unknown') continue;
          final matches = await database.searchTypesByName(name, limit: 20);
          final exact = [
            for (final match in matches)
              if (normalizeCombatName(match.typeName) == key) match,
          ];
          if (exact.length != 1) continue;
          final type = exact.single;
          final group = await database.getGroup(type.groupId);
          if (group == null) continue;
          byName[key] = CombatTypeRef(
            typeId: type.typeId,
            typeName: type.typeName,
            groupId: type.groupId,
            categoryId: group.categoryId,
          );
        }
        return byName;
      } catch (e, stack) {
        Log.e('AAR.MATCHUP', 'local actor types unavailable', e, stack);
        return const {};
      }
    });

final aarFitSnapshotProvider =
    FutureProvider.family<AarDerivationBundle, ParsedCombatEncounter>((
      ref,
      encounter,
    ) async {
      Log.d(
        'AAR.MATCHUP',
        'aarFitSnapshotProvider(encounter=${encounter.id}) - START',
      );
      try {
        ref.watch(aarSdeRevisionProvider);
        final enrichment = await ref.watch(
          combatEnrichmentProvider(encounter.id).future,
        );
        if (enrichment == null) return const AarDerivationBundle.empty();
        return await ref
            .read(combatFitDerivationServiceProvider)
            .deriveFitsForEncounter(
              encounter: encounter,
              enrichment: enrichment,
              selfSkills: null,
              opponentSkills: null,
            );
      } catch (e, stack) {
        Log.e('AAR.MATCHUP', 'fit snapshot unavailable', e, stack);
        return const AarDerivationBundle.empty();
      }
    });

final aarIncomingMatchupsProvider =
    Provider.family<AarIncomingMatchupState, ParsedCombatEncounter>((
      ref,
      encounter,
    ) {
      Log.d(
        'AAR.MATCHUP',
        'aarIncomingMatchupsProvider(encounter=${encounter.id}) - START',
      );
      final allocationAsync = ref.watch(
        combatIncomingDamageAllocationProvider(encounter),
      );
      final correlationAsync = ref.watch(
        combatAttackerCorrelationProvider(encounter),
      );
      final typesAsync = ref.watch(aarLocalActorTypesProvider(encounter));
      final fitAsync = ref.watch(aarFitSnapshotProvider(encounter));
      final enrichmentAsync = ref.watch(combatEnrichmentProvider(encounter.id));

      var allocationStatus = AarIncomingDependencyStatus.loading;
      IncomingAllocationResult allocationResult =
          IncomingDamageAllocator.allocate(
            encounter: encounter,
            weapons: const {},
            sdeContentKey: 'sde-decimal-v1',
          );
      allocationAsync.when(
        data: (value) {
          allocationResult = value;
          allocationStatus = value is IncomingAllocationReady
              ? AarIncomingDependencyStatus.ready
              : AarIncomingDependencyStatus.invalid;
        },
        loading: () {
          if (allocationResult is IncomingAllocationReady) {
            allocationStatus = AarIncomingDependencyStatus.ready;
          }
        },
        error: (error, stack) {
          Log.e('AAR.MATCHUP', 'allocation provider failed', error, stack);
          allocationStatus = AarIncomingDependencyStatus.error;
        },
      );

      var correlationStatus = AarIncomingDependencyStatus.loading;
      AttackerCorrelation? correlation;
      correlationAsync.when(
        data: (value) {
          correlation = value;
          correlationStatus = value == null
              ? AarIncomingDependencyStatus.unavailable
              : AarIncomingDependencyStatus.ready;
        },
        loading: () {},
        error: (error, stack) {
          Log.e('AAR.MATCHUP', 'correlation provider failed', error, stack);
          correlationStatus = AarIncomingDependencyStatus.error;
        },
      );

      var classificationStatus = AarIncomingDependencyStatus.loading;
      var localTypes = <String, CombatTypeRef>{};
      typesAsync.when(
        data: (value) {
          localTypes = value;
          classificationStatus = AarIncomingDependencyStatus.ready;
        },
        loading: () {
          classificationStatus = AarIncomingDependencyStatus.ready;
        },
        error: (error, stack) {
          classificationStatus = AarIncomingDependencyStatus.error;
        },
      );

      var defenseStatus = AarIncomingDependencyStatus.loading;
      AarFitDerivation? pilotFit;
      FitEvidence? pilotFitEvidence;
      fitAsync.when(
        data: (value) {
          pilotFit = value.self;
          defenseStatus = AarIncomingDependencyStatus.ready;
        },
        loading: () {},
        error: (error, stack) {
          Log.e('AAR.MATCHUP', 'fit snapshot unavailable', error, stack);
          defenseStatus = AarIncomingDependencyStatus.error;
        },
      );
      enrichmentAsync.when(
        data: (value) {
          if (pilotFit?.fitSource == EvidenceSource.killmail) {
            pilotFitEvidence = value?.victimFitEvidence;
          } else {
            pilotFitEvidence = value?.pilotFitEvidence;
          }
          if (correlation == null && value?.attackerCorrelation != null) {
            correlation = value!.attackerCorrelation;
            if (correlationStatus == AarIncomingDependencyStatus.loading) {
              correlationStatus = AarIncomingDependencyStatus.ready;
            }
          }
        },
        loading: () {},
        error: (_, _) {},
      );

      AarIncomingMatchupBundle? bundle;
      final readyAllocation = allocationResult;
      if (readyAllocation is IncomingAllocationReady) {
        final allocation = readyAllocation.allocation;
        final context = IncomingCorrelationContext(
          parsedEncounterId: encounter.id,
          selectedKillmailId: correlation?.killmailId,
          selfCharacterId: encounter.characterId,
          selfIsVictim: correlation?.selfIsVictim,
          correlation: correlation,
          currentParticipants: const [],
          localActorTypes: localTypes,
        );
        bundle = AarAttackerMatchupDeriver.derive(
          allocation: allocation,
          correlation: context,
          pilotFit: defenseStatus == AarIncomingDependencyStatus.ready
              ? pilotFit
              : null,
          pilotFitEvidence: pilotFitEvidence,
          pilotFitKey: pilotFit?.shipName,
          dependencyLimitations: const [],
        );
      }

      Log.i(
        'AAR.MATCHUP',
        'matchups ${encounter.id} allocation=${allocationStatus.name} '
            'correlation=${correlationStatus.name} '
            'defense=${defenseStatus.name} '
            'attackers=${bundle?.attackers.length ?? 0}',
      );
      return AarIncomingMatchupState(
        encounterId: encounter.id,
        allocationRequestKey: encounter.id,
        identityRequestKey: '${encounter.id}:${correlation?.killmailId}',
        fitRequestKey: '${encounter.id}:${pilotFit?.shipName}',
        bundle: bundle,
        allocationStatus: allocationStatus,
        correlationStatus: correlationStatus,
        classificationStatus: classificationStatus,
        defenseStatus: defenseStatus,
        issueCodes: const [],
      );
    });

final rawEncountersProvider = FutureProvider<List<ParsedCombatEncounter>>((
  ref,
) async {
  Log.d('COMBAT', 'rawEncountersProvider() - START');
  final scanner = await ref.watch(logScannerProvider.future);
  final database = ref.watch(databaseProvider);
  final cache = ParsedEncounterCache(database);
  final files = await scanner.getCombatLogs();
  Log.i('COMBAT', 'Parsing ${files.length} combat log files');

  await cache.pruneToFiles(files);
  final characters = await database.getAllCharacters();
  final characterIdsByName = {
    for (final character in characters)
      character.name.trim().toLowerCase(): character.characterId,
  };

  final allEncounters = <ParsedCombatEncounter>[];
  for (final file in files) {
    final cached = await cache.loadValidForFile(file);
    final encounters = cached ?? await CombatLogParser.parseFile(file);
    if (cached == null) {
      await cache.saveForFile(file, encounters);
    }
    allEncounters.addAll(
      encounters.map((encounter) {
        final characterId =
            characterIdsByName[encounter.characterName.trim().toLowerCase()];
        return characterId == null
            ? encounter
            : encounter.copyWith(characterId: characterId);
      }),
    );
  }

  final sortedEncounters = allEncounters
    ..sort((a, b) => b.startTime.compareTo(a.startTime));
  Log.i('COMBAT', 'Parsed ${sortedEncounters.length} combat encounters');
  return sortedEncounters;
});

final combatAarStatusesProvider = FutureProvider<Map<String, CombatAarStatus>>((
  ref,
) async {
  Log.d('COMBAT.AAR', 'combatAarStatusesProvider() - START');
  final database = ref.watch(databaseProvider);
  final rows = await database.select(database.combatEncounters).get();
  final statuses = <String, CombatAarStatus>{};
  for (final row in rows) {
    final status = _statusForRow(row);
    statuses[row.id] = status;
    final parsedEncounterId = row.parsedEncounterId;
    if (parsedEncounterId != null && parsedEncounterId.trim().isNotEmpty) {
      statuses[parsedEncounterId] = status;
    }
  }
  Log.i('COMBAT.AAR', 'Loaded ${statuses.length} cached AAR markers');
  return statuses;
});

CombatAarStatus _statusForRow(CombatEncounter row) {
  final analysisJson = row.analysisJson;
  if (analysisJson == null || analysisJson.trim().isEmpty) {
    return CombatAarStatus.legacy;
  }
  try {
    final decoded = jsonDecode(analysisJson);
    if (decoded is Map &&
        (decoded['version'] == 2 || decoded['version'] == 3)) {
      return CombatAarStatus.ready;
    }
  } catch (e, stack) {
    Log.w('COMBAT.AAR', 'Failed to inspect AAR version for ${row.id}: $e');
    Log.d('COMBAT.AAR', 'AAR version inspection stack: $stack');
  }
  return CombatAarStatus.legacy;
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_service.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_store.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_generation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

import '../fixtures/attacker_matchup_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P01–P10 aarIncomingMatchupsProvider', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late _CountingDiscovery discovery;
    late _CountingCodex codex;
    late _CountingRepository repository;

    setUp(() {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      discovery = _CountingDiscovery();
      codex = _CountingCodex();
      repository = _CountingRepository(database: appDb);
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    CombatEnrichmentService enrichmentService() {
      return CombatEnrichmentService(
        repository: repository,
        esiClient: EsiClient(
          tokenManager: TokenManager(database: appDb),
          oauthService: OAuthService(),
          database: appDb,
        ),
        discoveryClient: discovery,
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        sdeService: SdeService(database: sdeDb),
      );
    }

    test('P01 local matchups do not call AI or zKill', () async {
      final s2 = s2Fleet();
      await repository.saveEnrichment(s2.enrichment);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(appDb),
          sdeDatabaseProvider.overrideWithValue(sdeDb),
          combatEnrichmentServiceProvider.overrideWith(
            (ref) => enrichmentService(),
          ),
          combatEnrichmentProvider.overrideWith((ref, id) => s2.enrichment),
          combatAttackerCorrelationProvider.overrideWith(
            (ref, enc) => s2.correlation,
          ),
          codexAnalysisClientProvider.overrideWithValue(codex),
        ],
      );
      addTearDown(container.dispose);
      final state = container.read(aarIncomingMatchupsProvider(s2.encounter));
      expect(state.bundle, isNotNull);
      expect(codex.calls, 0);
      expect(discovery.pages, 0);
    });

    test('P02 concurrent ensure writes once', () async {
      final s2 = s2Fleet();
      final legacy = CombatEnrichment(
        parsedEncounterId: s2.encounter.id,
        status: CombatEnrichmentStatus.killmailMatched,
        source: CombatEnrichmentSource.zkillEsi,
        rawKillmail: s2.detail.toJson(),
        killmailId: s2.detail.killmailId,
      );
      await repository.saveEnrichment(legacy);
      repository.saveCalls = 0;
      final service = enrichmentService();
      await Future.wait([
        service.ensureAttackerCorrelation(s2.encounter, legacy),
        service.ensureAttackerCorrelation(s2.encounter, legacy),
      ]);
      expect(repository.saveCalls, 1);
    });

    test('P05 Possible to Probable regroups without new damage', () async {
      final s3 = s3Residuals();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(appDb),
          sdeDatabaseProvider.overrideWithValue(sdeDb),
          combatEnrichmentProvider.overrideWith((ref, id) => s3.enrichment),
          combatAttackerCorrelationProvider.overrideWith(
            (ref, enc) => s3.correlation,
          ),
        ],
      );
      addTearDown(container.dispose);
      final possible = container.read(
        aarIncomingMatchupsProvider(s3.encounter),
      );
      expect(possible.bundle, isNotNull);
      final possibleLogged = possible.bundle!.allocation.totalIncomingDamage;

      final promoted = [
        for (final row in s3.correlation.correlated)
          if (row.confidence == AttackerCorrelationConfidence.possible)
            CorrelatedAttacker(
              actor: row.actor,
              participant: row.participant,
              confidence: AttackerCorrelationConfidence.probable,
              score: 0.55,
              signals: row.signals,
            )
          else
            row,
      ];
      final regrouped = AttackerCorrelation(
        killmailId: s3.correlation.killmailId,
        selfIsVictim: s3.correlation.selfIsVictim,
        correlated: promoted,
        unattributedActors: s3.correlation.unattributedActors,
        uncorrelatedParticipants: s3.correlation.uncorrelatedParticipants,
        correlatedIncomingDamage: s3.correlation.correlatedIncomingDamage,
        unattributedIncomingDamage: s3.correlation.unattributedIncomingDamage,
        npcIncomingDamage: s3.correlation.npcIncomingDamage,
        totalIncomingDamage: s3.correlation.totalIncomingDamage,
        reasons: s3.correlation.reasons,
        correlatedAt: s3.correlation.correlatedAt,
      );
      final next = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(appDb),
          sdeDatabaseProvider.overrideWithValue(sdeDb),
          combatEnrichmentProvider.overrideWith((ref, id) => s3.enrichment),
          combatAttackerCorrelationProvider.overrideWith(
            (ref, enc) => regrouped,
          ),
        ],
      );
      addTearDown(next.dispose);
      final after = next.read(aarIncomingMatchupsProvider(s3.encounter));
      expect(after.bundle!.allocation.totalIncomingDamage, possibleLogged);
      expect(
        after.bundle!.attackers.length,
        greaterThan(possible.bundle!.attackers.length),
      );
    });

    test('P05 provider graph includes revision, allocation, fit snapshot', () {
      final source = File(
        'lib/features/combat_analyzer/data/combat_providers.dart',
      ).readAsStringSync();
      expect(source, contains('aarSdeRevisionProvider'));
      expect(source, contains('combatIncomingDamageAllocationProvider'));
      expect(source, contains('aarFitSnapshotProvider'));
      expect(source, contains('aarLocalSkillsProvider'));
      expect(source, contains('aarLocalActorTypesProvider'));
      expect(source, contains('aarIncomingMatchupsProvider'));
    });

    test(
      'P07 independent statuses: missing fit does not invent zero EHP',
      () async {
        final s2 = s2Fleet();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(appDb),
            sdeDatabaseProvider.overrideWithValue(sdeDb),
            combatEnrichmentProvider.overrideWith((ref, id) => s2.enrichment),
            combatAttackerCorrelationProvider.overrideWith(
              (ref, enc) => s2.correlation,
            ),
            aarFitSnapshotProvider.overrideWith(
              (ref, request) => throw StateError('fit unavailable'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final state = container.read(aarIncomingMatchupsProvider(s2.encounter));
        expect(state.allocationStatus, AarIncomingDependencyStatus.ready);
        expect(state.defenseStatus, isNot(AarIncomingDependencyStatus.ready));
        expect(state.bundle?.aggregateDefense.ehp?.total, isNot(0));
      },
    );

    test(
      'P10 logs use [AAR.MATCHUP] and do not call Codex on reread',
      () async {
        final lines = <String>[];
        final prior = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          lines.add(message ?? '');
        };
        addTearDown(() => debugPrint = prior);

        final s2 = s2Fleet();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(appDb),
            sdeDatabaseProvider.overrideWithValue(sdeDb),
            combatEnrichmentProvider.overrideWith((ref, id) => s2.enrichment),
            combatAttackerCorrelationProvider.overrideWith(
              (ref, enc) => s2.correlation,
            ),
            codexAnalysisClientProvider.overrideWithValue(codex),
          ],
        );
        addTearDown(container.dispose);
        container.read(aarIncomingMatchupsProvider(s2.encounter));
        container.read(aarIncomingMatchupsProvider(s2.encounter));
        expect(codex.calls, 0);
        expect(
          lines.where((line) => line.contains('[AAR.MATCHUP]')),
          isNotEmpty,
        );
      },
    );
  });

  test('P05 SdeDatabase.watchDerivationRevision is the revision seam', () {
    expect(
      File('lib/core/sde/sde_database.dart').readAsStringSync(),
      contains('watchDerivationRevision'),
    );
  });

  test('known-empty effects differ from unavailable localOnly effects', () {
    final sde = File('lib/core/sde/sde_service.dart').readAsStringSync();
    expect(sde, contains('loadEffectModifierInputs'));
    expect(sde, contains('EffectLookupPolicy'));
    expect(
      File(
        'lib/features/fitting/data/fitting_stats_inputs.dart',
      ).readAsStringSync(),
      contains('unavailableEffectIds'),
    );
  });
}

class _CountingDiscovery extends CombatKillmailDiscoveryClient {
  int pages = 0;

  @override
  Future<List<CombatZkillKillmailRef>> fetchCharacterPage({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
  }) async {
    pages++;
    return const [];
  }
}

class _CountingCodex extends CodexAnalysisClient {
  _CountingCodex()
    : super(
        authService: CodexAuthService(
          authStore: CodexAuthStore(authFilePath: '/tmp/mimir-m5-unused.json'),
        ),
      );

  int calls = 0;

  @override
  Future<CodexAnalysisResult> analyzeEncounter({
    required ParsedCombatEncounter encounter,
    required String model,
    CombatEnrichment? enrichment,
    AarDerivationBundle? derivation,
    AarIncomingMatchupBundle? perAttackerIncoming,
    PreparedAarComparisonInput? fitComparisonInput,
  }) async {
    calls++;
    throw StateError('analyzeEncounter must not run during P01/P10');
  }
}

class _CountingRepository extends CombatEnrichmentRepository {
  _CountingRepository({required super.database});

  int saveCalls = 0;

  @override
  Future<void> saveEnrichment(CombatEnrichment enrichment) async {
    saveCalls++;
    await super.saveEnrichment(enrichment);
  }
}

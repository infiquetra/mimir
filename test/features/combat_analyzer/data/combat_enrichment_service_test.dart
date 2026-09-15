import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_actor_classifier.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlator.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_evidence_fixtures.dart';
import '../fixtures/aar_fit_import_fixtures.dart';
import '../fixtures/attacker_correlation_fixtures.dart';
import '../fixtures/fit_evidence_harness.dart';

void main() {
  group('CombatEnrichmentService.attachDerivedEvidence', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late CombatEnrichmentService service;

    setUp(() {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      service = CombatEnrichmentService(
        repository: CombatEnrichmentRepository(database: appDb),
        esiClient: EsiClient(
          tokenManager: TokenManager(database: appDb),
          oauthService: OAuthService(),
          database: appDb,
        ),
        discoveryClient: CombatKillmailDiscoveryClient(),
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        sdeService: SdeService(database: sdeDb),
      );
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    test(
      'G.7 attachDerivedEvidence twice does not duplicate facts or unknowns',
      () async {
        const enrichment = CombatEnrichment(
          parsedEncounterId: 'enc-1',
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
        );
        final derivation = AarFitDerivation(
          role: FitEvidenceRole.pilot,
          subject: AarFitSubject.self,
          fitSource: EvidenceSource.manualFitImport,
          shipTypeId: 587,
          shipName: 'Rifter',
          skills: const AarSkillContext(
            basis: AarSkillBasis.allFive,
            skills: [],
          ),
          stats: const FittingStats(defenses: DefenseProfile(totalEhp: 1809)),
          baseline: const FittingStats(),
          tank: const TankAssessment(
            layer: TankLayer.armor,
            mode: TankMode.unfitted,
            shieldBoostHps: 0,
            armorRepairHps: 0,
            hullRepairHps: 0,
            shieldGainEhp: 0,
            armorGainEhp: 0,
            hullGainEhp: 0,
            reasoning: 'Armor (unfitted)',
          ),
          coverage: const AarFitCoverage(
            highFitted: 0,
            highSlots: 4,
            medFitted: 0,
            medSlots: 3,
            lowFitted: 0,
            lowSlots: 3,
            rigFitted: 0,
            rigSlots: 3,
            subsystemFitted: 0,
            subsystemSlots: 0,
            unresolvedTypeIds: [],
            unresolvedNames: [],
          ),
          derivedAt: DateTime.utc(2026, 9, 11),
          limitations: const ['assumes All V'],
        );
        final bundle = AarDerivationBundle(
          self: derivation,
          unknowns: const [
            AarUnknown(
              category: AarUnknownCategory.opponentFit,
              label: 'Opponent defense profile',
              detail: 'No opponent fit evidence.',
            ),
            AarUnknown(
              category: AarUnknownCategory.skills,
              label: 'Pilot skills',
              detail: 'assumes All V',
            ),
          ],
        );

        final first = await service.attachDerivedEvidence(
          enrichment,
          bundle,
          encounterId: 'enc-1',
        );
        final derivedFacts = first.evidenceLedger.facts
            .where((f) => f.source == EvidenceSource.dogmaDerivation)
            .toList();
        expect(derivedFacts, isNotEmpty);

        final second = await service.attachDerivedEvidence(
          first,
          bundle,
          encounterId: 'enc-1',
        );
        expect(
          second.evidenceLedger.facts
              .where((f) => f.source == EvidenceSource.dogmaDerivation)
              .length,
          derivedFacts.length,
        );

        final unknownKeys = second.evidenceLedger.unknowns
            .map((u) => '${u.category.name}|${u.label}')
            .toList();
        expect(unknownKeys.toSet().length, unknownKeys.length);
      },
    );
  });

  group('Group D — killmailSearchCompleted on enrichEncounter', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late CombatEnrichmentService service;
    late CombatEnrichmentRepository repository;

    setUp(() async {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      repository = CombatEnrichmentRepository(database: appDb);
      service = CombatEnrichmentService(
        repository: repository,
        esiClient: EsiClient(
          tokenManager: TokenManager(database: appDb),
          oauthService: OAuthService(),
          database: appDb,
        ),
        discoveryClient: CombatKillmailDiscoveryClient(),
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        sdeService: SdeService(database: sdeDb),
      );
      await sdeDb.upsertCategories([
        SdeCategoriesCompanion.insert(
          categoryId: const Value(6),
          categoryName: 'Ship',
        ),
      ]);
      await sdeDb.upsertGroups([
        SdeGroupsCompanion.insert(
          groupId: const Value(25),
          groupName: 'Frigate',
          categoryId: 6,
        ),
      ]);
      await sdeDb.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: const Value(587),
          typeName: 'Rifter',
          groupId: 25,
        ),
      ]);
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    test('D.9 enrichEncounter marks killmailSearchCompleted', () async {
      final searched = await service.enrichEncounter(
        _encounter(listener: 'SearchPilot'),
      );
      expect(searched.status, CombatEnrichmentStatus.logOnly);
      expect(searched.killmailSearchCompleted, isTrue);
      final reloaded = await service.loadEnrichment(searched.parsedEncounterId);
      expect(reloaded, isNotNull);
      expect(reloaded!.killmailSearchCompleted, isTrue);

      final imported = await service.importPilotFit(
        _encounter(listener: 'ImportPilot'),
        '[Rifter, Test]',
      );
      expect(imported.killmailSearchCompleted, isFalse);
      expect(imported.matchReason, CombatEnrichment.uncachedMatchReason);

      final alreadySearched = _encounter(listener: 'PreservePilot');
      await repository.saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: alreadySearched.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          matchReason: 'No ESI or zKill killmail matched this encounter.',
          killmailSearchCompleted: true,
        ),
      );
      final preserved = await service.importPilotFit(
        alreadySearched,
        '[Rifter, Test]',
      );
      expect(preserved.killmailSearchCompleted, isTrue);
    });
  });

  group('Group E — attacker correlation on CombatEnrichmentService', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late CountingCombatEnrichmentRepository repository;
    late _FakeEsiClient esi;
    late CombatEnrichmentService service;
    late ParsedCombatEncounter encounter;

    setUp(() async {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      await seedAttackerCorrelationSde(sdeDb);
      repository = CountingCombatEnrichmentRepository(database: appDb);
      esi = _FakeEsiClient(
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        database: appDb,
        detail: unnamedS2Detail(),
      );
      service = CombatEnrichmentService(
        repository: repository,
        esiClient: esi,
        discoveryClient: CombatKillmailDiscoveryClient(),
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        sdeService: SdeService(database: sdeDb),
      );
      encounter = s2Loss().encounter;
      await _seedS2ZkillCache(repository);
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    test(
      'T5.1 enrichEncounter correlates after name resolution and persists',
      () async {
        final enriched = await service.enrichEncounter(encounter);
        expect(enriched.status, CombatEnrichmentStatus.killmailMatched);
        expect(enriched.attackerCorrelation, isNotNull);
        final artem = enriched.attackerCorrelation!.correlated.firstWhere(
          (row) => row.actor.displayName == 'Artem S3',
        );
        expect(artem.confidence, AttackerCorrelationConfidence.confirmed);
        final loaded = await service.loadEnrichment(encounter.id);
        expect(loaded, isNotNull);
        expect(loaded!.attackerCorrelation, isNotNull);
        expect(
          loaded.attackerCorrelation!.toJson(),
          enriched.attackerCorrelation!.toJson(),
        );
      },
    );

    test('T5.4 no new network calls during correlation', () async {
      await service.enrichEncounter(encounter);
      expect(esi.getKillmailDetailCalls, 1);
      expect(esi.resolveNamesCalls, 1);
      expect(esi.otherCalls, 0);

      final loaded = await service.loadEnrichment(encounter.id);
      expect(loaded, isNotNull);
      await service.ensureAttackerCorrelation(encounter, loaded!);
      expect(esi.getKillmailDetailCalls, 1);
      expect(esi.resolveNamesCalls, 1);
      expect(esi.otherCalls, 0);
    });

    test('T5.5 correlation failure leaves enrichment intact', () async {
      final lines = <String>[];
      final prior = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        lines.add(message ?? '');
      };
      addTearDown(() => debugPrint = prior);

      final failing = CombatEnrichmentService(
        repository: repository,
        esiClient: esi,
        discoveryClient: CombatKillmailDiscoveryClient(),
        tokenManager: TokenManager(database: appDb),
        oauthService: OAuthService(),
        sdeService: SdeService(database: sdeDb),
        correlator: const _ThrowingCorrelator(),
      );
      final enriched = await failing.enrichEncounter(encounter);
      expect(enriched.status, CombatEnrichmentStatus.killmailMatched);
      expect(enriched.attackerCorrelation, isNull);
      expect(enriched.victimFitEvidence, isNotNull);
      expect(
        lines.where(
          (line) => line.contains('[COMBAT.CORRELATE]') && line.contains('❌'),
        ),
        isNotEmpty,
        reason: 'logged lines were: $lines',
      );
    });

    test('T5.6 evidence facts emitted per correlated attacker', () async {
      final enriched = await service.enrichEncounter(encounter);
      expect(
        _fact(enriched, 'ev-correlated-attacker-1234567-9001').confidence,
        EvidenceConfidence.proven,
      );
      expect(
        _fact(enriched, 'ev-correlated-attacker-1234567-9002').confidence,
        EvidenceConfidence.proven,
      );
      expect(
        _fact(enriched, 'ev-correlated-attacker-1234567-9003').confidence,
        EvidenceConfidence.derived,
      );
      expect(
        enriched.evidenceLedger.unknowns.map((unknown) => unknown.label),
        contains('Attackers absent from combat log'),
      );

      final again = await service.ensureAttackerCorrelation(
        encounter,
        enriched,
      );
      expect(
        again.evidenceLedger.facts
            .where((fact) => fact.id.startsWith('ev-correlated-attacker-'))
            .map((fact) => fact.id)
            .toSet(),
        {
          'ev-correlated-attacker-1234567-9001',
          'ev-correlated-attacker-1234567-9002',
          'ev-correlated-attacker-1234567-9003',
        },
      );
      expect(
        again.evidenceLedger.unknowns
            .where(
              (unknown) => unknown.label == 'Attackers absent from combat log',
            )
            .length,
        1,
      );
    });

    test('E.7 ensureAttackerCorrelation backfills a cached row once', () async {
      final detail = s2Loss().detail.copyWith(killmailHash: 'hash-s2');
      final legacy = CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: CombatEnrichmentStatus.killmailMatched,
        source: CombatEnrichmentSource.zkillEsi,
        rawKillmail: detail.toJson(),
      );
      await repository.saveEnrichment(legacy);
      repository.saveCalls = 0;

      final first = await service.ensureAttackerCorrelation(encounter, legacy);
      expect(first.attackerCorrelation, isNotNull);
      expect(
        first.attackerCorrelation!.correlated.map(
          (row) => row.actor.displayName,
        ),
        contains('Artem S3'),
      );
      expect(repository.saveCalls, 1);
      final loaded = await service.loadEnrichment(encounter.id);
      expect(loaded!.attackerCorrelation, isNotNull);

      final second = await service.ensureAttackerCorrelation(encounter, first);
      expect(repository.saveCalls, 1);
      expect(
        second.attackerCorrelation!.toJson(),
        first.attackerCorrelation!.toJson(),
      );
    });

    test(
      'E.8 ensureAttackerCorrelation is a no-op for logOnly and for rows without rawKillmail',
      () async {
        repository.saveCalls = 0;
        final logOnly = CombatEnrichment(
          parsedEncounterId: encounter.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
        );
        final afterLogOnly = await service.ensureAttackerCorrelation(
          encounter,
          logOnly,
        );
        expect(afterLogOnly.attackerCorrelation, isNull);
        expect(afterLogOnly.status, CombatEnrichmentStatus.logOnly);
        expect(repository.saveCalls, 0);

        final noRaw = CombatEnrichment(
          parsedEncounterId: encounter.id,
          status: CombatEnrichmentStatus.killmailMatched,
          source: CombatEnrichmentSource.zkillEsi,
        );
        final afterNoRaw = await service.ensureAttackerCorrelation(
          encounter,
          noRaw,
        );
        expect(afterNoRaw.attackerCorrelation, isNull);
        expect(repository.saveCalls, 0);
      },
    );

    test('I.2 service logs at info on enrichment', () async {
      final lines = <String>[];
      final prior = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        lines.add(message ?? '');
      };
      addTearDown(() => debugPrint = prior);

      await service.enrichEncounter(encounter);
      expect(
        lines.where((line) => line.contains('[COMBAT.CORRELATE] ℹ️')),
        isNotEmpty,
        reason: 'logged lines were: $lines',
      );
    });
  });

  group('T13–T20 captureCurrentPilotFit storage', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('T15 invalid x-pages does not keep page-one inventory', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      harness.scriptCharacterShip();
      harness.scriptAssetPage(
        characterId: FitEvidenceHarness.characterAId,
        page: 1,
        body: aarFittedPage1(),
        xPages: 'nope',
      );
      await expectLater(
        harness.enrichmentService.captureCurrentPilotFit(
          encounter,
          confirmed: true,
        ),
        throwsA(isA<Object>()),
      );
      expect(await harness.repository.loadEnrichment(encounter.id), isNull);
    });

    test(
      'T18 confirmed empty inventory persists the no-modules limitation',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        harness.scriptFittedCapture(emptyInventory: true);
        final saved = await harness.enrichmentService.captureCurrentPilotFit(
          encounter,
          confirmed: true,
        );
        expect(saved.pilotFitEvidence!.fitting.allModules, isEmpty);
        expect(
          saved.pilotFitEvidence!.limitations,
          contains(kAarEmptyModulesLimitation),
        );
      },
    );

    test('T17 ship HTTP 401 collapses to no-ship, not reauthorize', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      harness.scriptCharacterShip(statusCode: 401);
      await expectLater(
        harness.enrichmentService.captureCurrentPilotFit(
          encounter,
          confirmed: true,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'ESI did not return a current ship.',
          ),
        ),
      );
      expect(
        harness.esiAdapter.requests.where(
          (r) => r.uri.path.contains('/assets'),
        ),
        isEmpty,
      );
    });

    test('T17 missing token is an explicit 401 before HTTP', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.tokenManager.deleteTokens(FitEvidenceHarness.characterAId);
      await expectLater(
        harness.enrichmentService.captureCurrentPilotFit(
          encounter,
          confirmed: true,
        ),
        throwsA(isA<EsiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(harness.esiAdapter.requests, isEmpty);
    });
  });
}

ParsedCombatEncounter _encounter({required String listener}) {
  return CombatLogParser.parseLines([
    'Listener: $listener',
    '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
  ]).single;
}

CombatEvidenceFact _fact(CombatEnrichment enrichment, String id) {
  return enrichment.evidenceLedger.facts.firstWhere((fact) => fact.id == id);
}

Future<void> _seedS2ZkillCache(CombatEnrichmentRepository repository) async {
  const ref = CombatZkillKillmailRef(
    killmailId: 1234567,
    killmailHash: 'hash-s2',
  );
  await repository.saveSearchCache(
    characterId: 42,
    year: 2026,
    month: 5,
    direction: 'losses',
    page: 1,
    response: [ref.toJson()],
  );
  await repository.saveSearchCache(
    characterId: 42,
    year: 2026,
    month: 5,
    direction: 'losses',
    page: 2,
    response: const [],
  );
  await repository.saveSearchCache(
    characterId: 42,
    year: 2026,
    month: 5,
    direction: 'kills',
    page: 1,
    response: const [],
  );
}

class CountingCombatEnrichmentRepository extends CombatEnrichmentRepository {
  CountingCombatEnrichmentRepository({required super.database});

  int saveCalls = 0;

  @override
  Future<void> saveEnrichment(CombatEnrichment enrichment) async {
    saveCalls++;
    await super.saveEnrichment(enrichment);
  }
}

class _FakeEsiClient extends EsiClient {
  _FakeEsiClient({
    required super.tokenManager,
    required super.oauthService,
    required super.database,
    required this.detail,
  });

  final EsiKillmailDetail detail;
  int getKillmailDetailCalls = 0;
  int resolveNamesCalls = 0;
  int otherCalls = 0;

  static const _names = {
    42: 'Pilot',
    9001: 'Artem S3',
    9002: 'Kite Mondeo',
    9003: 'Dax Rho',
    9004: 'Pell Ivo',
  };

  @override
  Future<EsiKillmailDetail> getKillmailDetail({
    required int killmailId,
    required String killmailHash,
  }) async {
    getKillmailDetailCalls++;
    return detail.copyWith(killmailHash: killmailHash);
  }

  @override
  Future<List<EsiUniverseName>> resolveNames(List<int> ids) async {
    resolveNamesCalls++;
    return [
      for (final id in ids)
        if (_names.containsKey(id))
          EsiUniverseName(id: id, name: _names[id]!, category: 'character'),
    ];
  }

  @override
  Future<List<EsiKillmailRef>> getCharacterRecentKillmailRefs(
    int characterId,
  ) async {
    otherCalls++;
    return const [];
  }
}

class _ThrowingCorrelator extends CombatAttackerCorrelator {
  const _ThrowingCorrelator();

  @override
  AttackerCorrelation correlate({
    required ParsedCombatEncounter encounter,
    required EsiKillmailDetail detail,
    required CombatActorTypeIndex typeIndex,
    required DateTime now,
  }) {
    throw StateError('correlation boom');
  }
}

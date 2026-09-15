import 'dart:async';

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
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
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

  group('U3 atomic retention and analysis barrier', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('T11 SQL trigger abort keeps the loadable prior row', () async {
      final encounter = encounterWith(
        characterId: FitEvidenceHarness.characterAId,
      );
      await harness.repository.saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: encounter.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          pilotFitEvidence: const FitEvidence(
            role: FitEvidenceRole.pilot,
            source: EvidenceSource.currentShipSnapshot,
            confidence: EvidenceConfidence.reference,
            fitting: Fitting(
              id: 'prior-ref',
              name: 'Reference',
              shipTypeId: 587,
              shipName: 'Rifter',
            ),
          ),
        ),
      );
      await harness.appDb.customStatement('''
CREATE TRIGGER abort_t11_update
BEFORE UPDATE ON combat_encounter_enrichments
WHEN NEW.parsed_encounter_id = '${encounter.id}'
BEGIN
  SELECT RAISE(ABORT, 'sql boom');
END;
''');
      await expectLater(
        harness.enrichmentService.importPilotFit(encounter, kAarSupportedEft),
        throwsA(anything),
      );
      final reloaded = await CombatEnrichmentRepository(
        database: harness.appDb,
      ).loadEnrichment(encounter.id);
      expect(reloaded, isNotNull);
      expect(
        reloaded!.pilotFitEvidence!.confidence,
        EvidenceConfidence.reference,
      );
      expect(reloaded.pilotFitEvidence!.fitting.id, 'prior-ref');
      await harness.appDb.customStatement(
        'DROP TRIGGER IF EXISTS abort_t11_update',
      );
    });

    test(
      'T22 service replacement updates one pilot fact and keeps unrelated evidence',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.seedUnrelatedEnrichment(encounter);
        final imported = await harness.enrichmentService.importPilotFit(
          encounter,
          kAarSupportedEft,
        );
        _assertServiceUnrelatedPreserved(imported, encounter.id);
        expect(
          imported.pilotFitEvidence!.source,
          EvidenceSource.manualFitImport,
        );
        expect(imported.pilotFitEvidence!.fitting.lowSlots.single.typeId, 2048);

        harness.scriptFittedCapture();
        final captured = await harness.enrichmentService.captureCurrentPilotFit(
          encounter,
          confirmed: true,
        );
        _assertServiceUnrelatedPreserved(captured, encounter.id);
        expect(
          captured.pilotFitEvidence!.source,
          EvidenceSource.currentShipSnapshot,
        );
        expect(
          captured.pilotFitEvidence!.confidence,
          EvidenceConfidence.confirmed,
        );
        final reloaded = await harness.repository.loadEnrichment(encounter.id);
        _assertServiceUnrelatedPreserved(reloaded!, encounter.id);
      },
    );

    test(
      'T26 manual import retains fit through matched killmail refresh',
      () async {
        await _attachAndForceAnalyze(
          harness,
          attach: _AttachKind.import,
          refresh: _RefreshKind.matched,
        );
      },
    );

    test('T26 manual import retains fit through no-match refresh', () async {
      await _attachAndForceAnalyze(
        harness,
        attach: _AttachKind.import,
        refresh: _RefreshKind.noMatch,
      );
    });

    test(
      'T26 manual import retains fit through null-character refresh',
      () async {
        await _attachAndForceAnalyze(
          harness,
          attach: _AttachKind.import,
          refresh: _RefreshKind.nullCharacter,
        );
      },
    );

    test(
      'T26 confirmed capture retains fit through matched killmail refresh',
      () async {
        await _attachAndForceAnalyze(
          harness,
          attach: _AttachKind.capture,
          refresh: _RefreshKind.matched,
        );
      },
    );

    test(
      'T26 confirmed capture retains fit through no-match refresh',
      () async {
        await _attachAndForceAnalyze(
          harness,
          attach: _AttachKind.capture,
          refresh: _RefreshKind.noMatch,
        );
      },
    );

    test(
      'T26 no-match refresh retains attached pilot fit and existing victim evidence',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.seedCachedReport(encounter);
        await harness.seedUnrelatedEnrichment(encounter);
        await harness.enrichmentService.importPilotFit(
          encounter,
          kAarSupportedEft,
        );
        await harness.grantKillmailScope();
        harness.scriptNoMatchKillmails();
        await harness.analysisService.analyzeEncounter(
          encounter,
          forceRefresh: true,
        );
        final stored = await harness.repository.loadEnrichment(encounter.id);
        expect(stored!.pilotFitEvidence, isNotNull);
        expect(stored.victimFitEvidence, isNotNull);
        expect(stored.victimFitEvidence!.fitting.id, 'victim-fit');
        expect(harness.codex.lastEnrichment!.pilotFitEvidence, isNotNull);
        expect(harness.codex.lastEnrichment!.victimFitEvidence, isNotNull);
      },
    );

    test(
      'T27 AI failure preserves fit and cached report; retry uses the fit',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        await harness.seedCachedReport(encounter);
        await harness.grantKillmailScope();
        harness.scriptNoMatchKillmails();
        await harness.enrichmentService.importPilotFit(
          encounter,
          kAarSupportedEft,
        );
        harness.codex.error = StateError('ai down');
        await expectLater(
          harness.analysisService.analyzeEncounter(
            encounter,
            forceRefresh: true,
          ),
          throwsA(isA<Exception>()),
        );
        expect(
          (await harness.repository.loadEnrichment(
            encounter.id,
          ))!.pilotFitEvidence,
          isNotNull,
          reason: 'AI failure must not drop the newly attached pilot fit',
        );
        final cached = await harness.analysisService.getCachedAnalysis(
          encounter,
        );
        expect(cached, isNotNull);
        expect(cached!.llmSummary, 'Cached summary');
        expect(harness.codex.calls, 1);

        harness.codex.error = null;
        harness.codex.result = CodexAnalysisResult(
          report: CombatAarReport.fromLegacy(
            summary: 'Retry summary',
            mistakes: '',
            improvements: '',
            fits: '',
          ),
        );
        await harness.analysisService.analyzeEncounter(
          encounter,
          forceRefresh: true,
        );
        expect(harness.codex.calls, 2);
        expect(harness.codex.lastEnrichment!.pilotFitEvidence, isNotNull);
        expect(
          harness.codex.lastEnrichment!.pilotFitEvidence!.source,
          EvidenceSource.manualFitImport,
        );
        expect(harness.codex.lastDerivation!.self, isNotNull);
        expect(
          harness.codex.lastDerivation!.self!.fitSource,
          EvidenceSource.manualFitImport,
        );
        final retried = await harness.analysisService.getCachedAnalysis(
          encounter,
        );
        expect(retried!.llmSummary, 'Retry summary');
      },
    );

    test(
      'T30 competing attachment is rejected as busy and analysis waits for the new fit',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        harness.scriptFittedCapture();
        harness.repository.mutationEntered = Completer<void>();
        harness.repository.allowMutation = Completer<void>();
        final pending = harness.enrichmentService.importPilotFit(
          encounter,
          kAarSupportedEft,
        );
        await harness.repository.mutationEntered!.future;
        expect(harness.repository.saveCalls, 1);

        Object? duplicateError;
        Object? competingError;
        unawaited(
          harness.enrichmentService
              .importPilotFit(encounter, kAarHeaderOnlyEft)
              .then<void>(
                (_) {},
                onError: (error, _) => duplicateError = error,
              ),
        );
        unawaited(
          harness.enrichmentService
              .captureCurrentPilotFit(encounter, confirmed: true)
              .then<void>(
                (_) {},
                onError: (error, _) => competingError = error,
              ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(
          harness.repository.saveCalls,
          1,
          reason: 'duplicate/competing attachment must not enter a second save',
        );
        expect(duplicateError?.toString().toLowerCase(), contains('busy'));
        expect(competingError?.toString().toLowerCase(), contains('busy'));

        final analysis = harness.analysisService.analyzeEncounter(encounter);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(harness.codex.calls, 0);

        harness.repository.allowMutation!.complete();
        await pending;
        await analysis;
        expect(harness.codex.calls, 1);
        expect(
          harness.codex.lastEnrichment!.pilotFitEvidence!.source,
          EvidenceSource.manualFitImport,
        );
        expect(
          harness
              .codex
              .lastEnrichment!
              .pilotFitEvidence!
              .fitting
              .lowSlots
              .single
              .typeId,
          2048,
        );
      },
    );

    test(
      'T30 delayed refresh cannot overwrite the attached pilot fit',
      () async {
        final encounter = encounterWith(
          characterId: FitEvidenceHarness.characterAId,
        );
        final releaseDiscovery = Completer<void>();
        harness.discovery.onFetch =
            ({
              required int characterId,
              required int year,
              required int month,
              required String direction,
              required int page,
            }) async {
              await releaseDiscovery.future;
              return const <CombatZkillKillmailRef>[];
            };
        final refresh = harness.enrichmentService.enrichEncounter(
          encounter,
          forceRefresh: true,
        );
        for (var i = 0; i < 50 && harness.discovery.fetches.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(harness.discovery.fetches, isNotEmpty);

        final ungated = CombatEnrichmentService(
          repository: CombatEnrichmentRepository(database: harness.appDb),
          esiClient: harness.esiClient,
          discoveryClient: harness.discovery,
          tokenManager: harness.tokenManager,
          oauthService: harness.oauthService,
          sdeService: harness.sdeService,
        );
        await ungated.importPilotFit(encounter, kAarUniqueBeyond20Eft);
        expect(
          (await harness.repository.loadEnrichment(
            encounter.id,
          ))!.pilotFitEvidence!.fitting.shipTypeId,
          9020,
        );

        releaseDiscovery.complete();
        await refresh;
        final loaded = await CombatEnrichmentRepository(
          database: harness.appDb,
        ).loadEnrichment(encounter.id);
        expect(loaded, isNotNull);
        expect(
          loaded!.pilotFitEvidence,
          isNotNull,
          reason: 'delayed refresh overwrote the attached UniqueShip fit',
        );
        expect(loaded.pilotFitEvidence!.fitting.shipTypeId, 9020);
        expect(loaded.pilotFitEvidence!.source, EvidenceSource.manualFitImport);
      },
    );
  });
}

enum _AttachKind { import, capture }

enum _RefreshKind { matched, noMatch, nullCharacter }

Future<void> _attachAndForceAnalyze(
  FitEvidenceHarness harness, {
  required _AttachKind attach,
  required _RefreshKind refresh,
}) async {
  final encounter = encounterWith(
    characterId: refresh == _RefreshKind.nullCharacter
        ? null
        : FitEvidenceHarness.characterAId,
  );
  await harness.seedCachedReport(encounter);
  if (refresh == _RefreshKind.matched) {
    if (encounter.characterId != null) {
      await harness.grantKillmailScope();
    }
    harness.scriptMatchedKillmail();
  } else if (refresh == _RefreshKind.noMatch) {
    await harness.grantKillmailScope();
    harness.scriptNoMatchKillmails();
  }

  late EvidenceSource source;
  if (attach == _AttachKind.import) {
    await harness.enrichmentService.importPilotFit(encounter, kAarSupportedEft);
    source = EvidenceSource.manualFitImport;
  } else {
    harness.scriptFittedCapture();
    await harness.enrichmentService.captureCurrentPilotFit(
      encounter,
      confirmed: true,
    );
    source = EvidenceSource.currentShipSnapshot;
  }

  expect(harness.codex.calls, 0);
  await harness.analysisService.analyzeEncounter(encounter, forceRefresh: true);
  expect(harness.codex.calls, 1);
  final stored = await harness.repository.loadEnrichment(encounter.id);
  expect(stored, isNotNull, reason: 'stored enrichment missing after refresh');
  expect(
    stored!.pilotFitEvidence,
    isNotNull,
    reason: 'stored pilotFitEvidence was dropped on $refresh after $attach',
  );
  expect(stored.pilotFitEvidence!.source, source);
  expect(stored.pilotFitEvidence!.confidence, EvidenceConfidence.confirmed);
  expect(stored.pilotFitEvidence!.fitting.shipTypeId, 587);
  expect(
    harness.codex.lastEnrichment?.pilotFitEvidence,
    isNotNull,
    reason: 'codex.lastEnrichment.pilotFitEvidence dropped on $refresh',
  );
  expect(harness.codex.lastEnrichment!.pilotFitEvidence!.source, source);
  expect(
    harness.codex.lastDerivation?.self,
    isNotNull,
    reason: 'codex.lastDerivation.self missing on $refresh after $attach',
  );
  expect(harness.codex.lastDerivation!.self!.shipTypeId, 587);
  expect(harness.codex.lastDerivation!.self!.fitSource, source);
}

void _assertServiceUnrelatedPreserved(
  CombatEnrichment enrichment,
  String encounterId,
) {
  expect(enrichment.killmailId, kAarKillmailId);
  expect(enrichment.killmailHash, kAarKillmailHash);
  expect(enrichment.killmailSearchCompleted, isTrue);
  expect(enrichment.victimFitEvidence, isNotNull);
  expect(enrichment.attackerCorrelation, isNotNull);
  final factIds = enrichment.evidenceLedger.facts
      .map((fact) => fact.id)
      .toList();
  expect(factIds.where((id) => id == 'ev-pilot-fit-$encounterId'), [
    'ev-pilot-fit-$encounterId',
  ]);
  expect(factIds, contains('ev-killmail-$kAarKillmailId'));
  expect(factIds, contains('ev-victim-ship-$kAarKillmailId'));
  expect(
    factIds,
    contains('ev-correlated-attacker-$kAarKillmailId-$kAarVictimCharacterId'),
  );
  expect(factIds, contains('ev-custom-note-$encounterId'));
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

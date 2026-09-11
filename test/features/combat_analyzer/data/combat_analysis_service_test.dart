import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_service.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_store.dart';
import 'package:mimir/features/combat_analyzer/data/combat_analysis_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase appDb;
  late SdeDatabase sdeDb;
  late Directory tempDir;

  setUp(() async {
    appDb = AppDatabase.forTesting(NativeDatabase.memory());
    sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('mimir-aar-u3-');
  });

  tearDown(() async {
    await appDb.close();
    await sdeDb.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  CombatEnrichmentService enrichmentService() {
    return CombatEnrichmentService(
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
  }

  test(
    'T9.2 analyzeEncounter with pilot fit emits v4 prompt, derivedFits, and derive stage',
    () async {
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
      ]).single;
      final enrichment = CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: CombatEnrichmentStatus.logOnly,
        source: CombatEnrichmentSource.none,
        pilotFitEvidence: const FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.confirmed,
          fitting: Fitting(
            id: 'fit-1',
            name: 'Rifter',
            shipTypeId: 587,
            shipName: 'Rifter',
          ),
        ),
      );
      await CombatEnrichmentRepository(
        database: appDb,
      ).saveEnrichment(enrichment);

      final fake = FakeCodexAnalysisClient(
        authFilePath: '${tempDir.path}/auth.json',
      );
      final analysis = CombatAnalysisService(
        database: appDb,
        codexClient: fake,
        enrichmentService: enrichmentService(),
      );
      final labels = <String>[];
      await analysis.analyzeEncounter(
        encounter,
        onProgress: (p) => labels.add(p.label),
      );

      expect(fake.capturedPrompt, isNotNull);
      final payload = jsonDecode(fake.capturedPrompt!) as Map<String, dynamic>;
      expect(payload['schema'], 'mimir.combat_aar_input.v4');
      expect(payload['derivedFits'], isA<List>());
      expect((payload['derivedFits'] as List).length, 1);
      expect(payload['damageMatchups'], isA<Map>());
      final ledger = payload['evidenceLedger'] as Map<String, dynamic>?;
      final factIds = [
        for (final fact in (ledger?['facts'] as List? ?? const []))
          (fact as Map)['id']?.toString(),
      ];
      expect(
        factIds.any(
          (id) => id != null && id.startsWith('ev-derived-self-ehp-omni-'),
        ),
        isTrue,
      );
      expect(labels, contains('Deriving fit statistics'));
    },
  );

  test(
    'T9.3 analyzeEncounter with no fit evidence has empty derivedFits and opponent unknown',
    () async {
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
      ]).single;
      final fake = FakeCodexAnalysisClient(
        authFilePath: '${tempDir.path}/auth.json',
      );
      final analysis = CombatAnalysisService(
        database: appDb,
        codexClient: fake,
        enrichmentService: enrichmentService(),
      );
      await analysis.analyzeEncounter(encounter);

      expect(fake.capturedPrompt, isNotNull);
      final payload = jsonDecode(fake.capturedPrompt!) as Map<String, dynamic>;
      expect(payload['derivedFits'], isA<List>());
      expect((payload['derivedFits'] as List), isEmpty);
      final ledger = payload['evidenceLedger'] as Map<String, dynamic>?;
      final unknownLabels = [
        for (final u in (ledger?['unknowns'] as List? ?? const []))
          (u as Map)['label']?.toString(),
      ];
      expect(unknownLabels, contains('Opponent defense profile'));
    },
  );

  group('Group D — analyzeEncounter evidence snapshot', () {
    const allowedPromptKeys = {
      'schema',
      'pilot',
      'startTime',
      'endTime',
      'durationSeconds',
      'outcomeHint',
      'outcomeEvidence',
      'aggregates',
      'events',
      'eventOmittedCount',
      'killmailEvidence',
      'evidenceLedger',
      'pilotFitEvidence',
      'victimFitEvidence',
      'derivedFits',
      'damageMatchups',
      'compactEvidence',
    };

    Future<
      ({
        ParsedCombatEncounter encounter,
        FakeCodexAnalysisClient fake,
        CombatAnalysisService analysis,
      })
    >
    harness() async {
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
      ]).single;
      await CombatEnrichmentRepository(
        database: appDb,
      ).saveEnrichment(_t9Enrichment(encounter));
      final fake = FakeCodexAnalysisClient(
        authFilePath: '${tempDir.path}/auth.json',
      );
      final analysis = CombatAnalysisService(
        database: appDb,
        codexClient: fake,
        enrichmentService: enrichmentService(),
      );
      return (encounter: encounter, fake: fake, analysis: analysis);
    }

    Map<String, dynamic> snapshotJson(CombatEncounter row) {
      final decoded =
          jsonDecode(row.analysisJson ?? '') as Map<String, dynamic>;
      return decoded;
    }

    test(
      'T4.1 analyzeEncounter records the evidence score on the stored report',
      () async {
        final h = await harness();
        await h.analysis.analyzeEncounter(h.encounter);
        final cached = await h.analysis.getCachedAnalysis(h.encounter);
        expect(cached, isNotNull);
        final json = snapshotJson(cached!);
        expect(json['version'], 3);
        final evidence = json['evidenceAtGeneration'];
        expect(evidence, isA<Map>());
        final snap = Map<String, dynamic>.from(evidence as Map);
        expect(snap['score'], inInclusiveRange(0, 100));
        expect(snap['band'], anyOf('low', 'partial', 'good', 'complete'));
        expect(snap['statuses']?['pilotFit'], anyOf('complete', 'partial'));
      },
    );

    test(
      'T4.2 analyzeEncounter stage 5 progress detail includes evidence scoring',
      () async {
        final h = await harness();
        final labels = <String>[];
        final details = <String>[];
        await h.analysis.analyzeEncounter(
          h.encounter,
          onProgress: (p) {
            labels.add(p.label);
            details.add(p.detail);
          },
        );
        expect(labels, hasLength(9));
        expect(labels[4], 'Deriving fit statistics');
        expect(details[4], contains('evidence scoring'));
      },
    );

    test('T4.2 recorded score is not recomputed on load', () async {
      final h = await harness();
      await h.analysis.analyzeEncounter(h.encounter);
      final first = snapshotJson(
        (await h.analysis.getCachedAnalysis(h.encounter))!,
      );
      expect(first['evidenceAtGeneration'], isA<Map>());
      final recorded = first['evidenceAtGeneration'] as Map;
      final recordedScore = recorded['score'];

      await CombatEnrichmentRepository(database: appDb).saveEnrichment(
        CombatEnrichment(
          parsedEncounterId: h.encounter.id,
          status: CombatEnrichmentStatus.logOnly,
          source: CombatEnrichmentSource.none,
          killmailSearchCompleted: true,
        ),
      );
      final reloaded = await h.analysis.getCachedAnalysis(h.encounter);
      final again = snapshotJson(reloaded!);
      expect(again['evidenceAtGeneration']['score'], recordedScore);
    });

    test('T4.6 prompt v4 payload is unchanged', () async {
      final h = await harness();
      await h.analysis.analyzeEncounter(h.encounter);
      expect(h.fake.capturedPrompt, isNotNull);
      final payload =
          jsonDecode(h.fake.capturedPrompt!) as Map<String, dynamic>;
      expect(payload.keys.toSet(), everyElement(isIn(allowedPromptKeys)));
      expect(payload['schema'], 'mimir.combat_aar_input.v4');
      expect(h.fake.capturedPrompt, isNot(contains('killmailSearchCompleted')));
      expect(h.fake.capturedPrompt, isNot(contains('evidenceAtGeneration')));
      expect(h.fake.capturedPrompt, isNot(contains('evidenceScore')));
      expect(
        payload['killmailEvidence'],
        h.fake.capturedEnrichment!.toPromptJson(),
      );
    });

    test(
      'D.8 progress stage 5 label unchanged, detail mentions scoring',
      () async {
        final h = await harness();
        final progress = <CombatAnalysisProgress>[];
        await h.analysis.analyzeEncounter(
          h.encounter,
          onProgress: progress.add,
        );
        expect(progress, hasLength(9));
        expect(progress[4].label, 'Deriving fit statistics');
        expect(progress[4].stage, 5);
        expect(progress[4].stageCount, 9);
        expect(progress[4].detail, contains('evidence scoring'));
      },
    );

    test(
      'D.8 re-running analyzeEncounter replaces snapshot with newly evaluated score',
      () async {
        final h = await harness();
        await h.analysis.analyzeEncounter(h.encounter);
        final first = snapshotJson(
          (await h.analysis.getCachedAnalysis(h.encounter))!,
        );
        expect(first['evidenceAtGeneration'], isA<Map>());
        final firstScore = first['evidenceAtGeneration']['score'];
        final firstPilot =
            first['evidenceAtGeneration']['statuses']['pilotFit'];

        await CombatEnrichmentRepository(database: appDb).saveEnrichment(
          CombatEnrichment(
            parsedEncounterId: h.encounter.id,
            status: CombatEnrichmentStatus.logOnly,
            source: CombatEnrichmentSource.none,
            killmailSearchCompleted: true,
          ),
        );
        await appDb.delete(appDb.combatEncounters).go();

        await h.analysis.analyzeEncounter(h.encounter);
        final second = snapshotJson(
          (await h.analysis.getCachedAnalysis(h.encounter))!,
        );
        expect(second['evidenceAtGeneration'], isA<Map>());
        expect(
          second['evidenceAtGeneration']['score'] != firstScore ||
              second['evidenceAtGeneration']['statuses']['pilotFit'] !=
                  firstPilot,
          isTrue,
          reason:
              're-analysis should write a newly evaluated snapshot, '
              'got $firstScore/$firstPilot then ${second['evidenceAtGeneration']}',
        );
      },
    );
  });
}

class FakeCodexAnalysisClient extends CodexAnalysisClient {
  FakeCodexAnalysisClient({required String authFilePath})
    : super(
        authService: CodexAuthService(
          authStore: CodexAuthStore(authFilePath: authFilePath),
        ),
      );

  String? capturedPrompt;
  CombatEnrichment? capturedEnrichment;

  @override
  Future<CodexAnalysisResult> analyzeEncounter({
    required ParsedCombatEncounter encounter,
    required String model,
    CombatEnrichment? enrichment,
    AarDerivationBundle? derivation,
  }) async {
    capturedEnrichment = enrichment;
    capturedPrompt = buildPrompt(
      encounter,
      enrichment: enrichment,
      derivation: derivation,
    );
    return CodexAnalysisResult(
      report: CombatAarReport.fromLegacy(
        summary: 'ok',
        mistakes: '',
        improvements: '',
        fits: '',
      ),
    );
  }
}

CombatEnrichment _t9Enrichment(ParsedCombatEncounter encounter) {
  return CombatEnrichment(
    parsedEncounterId: encounter.id,
    status: CombatEnrichmentStatus.logOnly,
    source: CombatEnrichmentSource.none,
    killmailSearchCompleted: true,
    pilotFitEvidence: const FitEvidence(
      role: FitEvidenceRole.pilot,
      source: EvidenceSource.manualFitImport,
      confidence: EvidenceConfidence.confirmed,
      fitting: Fitting(
        id: 'fit-1',
        name: 'Rifter',
        shipTypeId: 587,
        shipName: 'Rifter',
      ),
    ),
  );
}

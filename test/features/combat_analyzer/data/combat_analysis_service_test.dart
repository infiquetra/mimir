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
}

class FakeCodexAnalysisClient extends CodexAnalysisClient {
  FakeCodexAnalysisClient({required String authFilePath})
    : super(
        authService: CodexAuthService(
          authStore: CodexAuthStore(authFilePath: authFilePath),
        ),
      );

  String? capturedPrompt;

  @override
  Future<CodexAnalysisResult> analyzeEncounter({
    required ParsedCombatEncounter encounter,
    required String model,
    CombatEnrichment? enrichment,
    AarDerivationBundle? derivation,
  }) async {
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

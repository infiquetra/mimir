import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_generation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group I — AAR evidence logging', () {
    final lines = <String>[];
    DebugPrintCallback? prior;

    setUp(() {
      lines.clear();
      prior = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        lines.add(message ?? '');
      };
    });

    tearDown(() {
      debugPrint = prior ?? debugPrint;
    });

    test(
      'T9.1 assess emits [AAR.EVIDENCE] info with score, band, and statuses',
      () {
        const AarEvidenceScorer().assess(s1Inputs());
        final pattern = RegExp(
          r'^\[AAR\.EVIDENCE\] ℹ️ score=49 band=partial capped=false '
          r'pilotFit=missing combatLog=complete opponentIdentity=complete '
          r'opponentFit=inferred damageProfile=partial$',
        );
        expect(
          lines.where(pattern.hasMatch),
          isNotEmpty,
          reason: 'logged lines were: $lines',
        );
      },
    );

    test('I.2 provider logs a START line', () async {
      final s1 = s1Inputs();
      final encounter = s1.encounter;
      final container = ProviderContainer(
        overrides: [
          combatEnrichmentProvider.overrideWith(
            (ref, id) async => s1.enrichment,
          ),
          aarFitDerivationsProvider.overrideWith((ref, enc) async => s1.bundle),
          combatIncomingDamageProfileProvider.overrideWith(
            (ref, enc) async => s1.incoming,
          ),
          combatDamageProfileProvider.overrideWith(
            (ref, enc) async => s1.outgoing,
          ),
          combatAnalysisServiceProvider.overrideWith(
            (ref) => throw StateError(
              'combatAnalysisServiceProvider must not be read during scoring',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(aarEvidenceAssessmentProvider(encounter).future);
      expect(
        lines.any(
          (line) => line.startsWith(
            '[AAR.EVIDENCE] aarEvidenceAssessmentProvider(encounter=',
          ),
        ),
        isTrue,
        reason: 'logged lines were: $lines',
      );
    });

    test('I.3 service logs the recorded score', () async {
      final appDb = AppDatabase.forTesting(NativeDatabase.memory());
      final sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      final tempDir = await Directory.systemTemp.createTemp('mimir-aar-i3-');
      addTearDown(() async {
        await appDb.close();
        await sdeDb.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
      ]).single;
      await CombatEnrichmentRepository(database: appDb).saveEnrichment(
        CombatEnrichment(
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
        ),
      );
      final fake = _LoggingFakeCodex(authFilePath: '${tempDir.path}/auth.json');
      final analysis = CombatAnalysisService(
        database: appDb,
        codexClient: fake,
        enrichmentService: CombatEnrichmentService(
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
        ),
      );
      await analysis.analyzeEncounter(encounter);
      expect(
        lines.any(
          (line) =>
              line.startsWith('[AAR.EVIDENCE] ℹ️ analyzeEncounter(') &&
              line.contains(') recording '),
        ),
        isTrue,
        reason: 'logged lines were: $lines',
      );
    });
  });
}

class _LoggingFakeCodex extends CodexAnalysisClient {
  _LoggingFakeCodex({required String authFilePath})
    : super(
        authService: CodexAuthService(
          authStore: CodexAuthStore(authFilePath: authFilePath),
        ),
      );

  @override
  Future<CodexAnalysisResult> analyzeEncounter({
    required ParsedCombatEncounter encounter,
    required String model,
    CombatEnrichment? enrichment,
    AarDerivationBundle? derivation,
    AarIncomingMatchupBundle? perAttackerIncoming,
    PreparedAarComparisonInput? fitComparisonInput,
  }) async {
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

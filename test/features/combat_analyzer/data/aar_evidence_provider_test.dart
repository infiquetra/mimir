import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

import '../fixtures/aar_evidence_fixtures.dart';
import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  group('Group E — aarEvidenceAssessmentProvider', () {
    late _Holder holder;
    late ParsedCombatEncounter encounter;
    late CountingCodexClient codex;
    late ProviderContainer container;

    setUp(() {
      final s1 = s1Inputs();
      encounter = s1.encounter;
      holder = _Holder(s1);
      codex = CountingCodexClient();
      container = ProviderContainer(
        overrides: _overrides(holder, encounter, codex),
      );
    });

    tearDown(() => container.dispose());

    test(
      'T5.1 assessment resolves from the four providers without the analysis client',
      () async {
        final assessment = await container.read(
          aarEvidenceAssessmentProvider(encounter).future,
        );
        expect(assessment, isA<AarEvidenceAssessment>());
        expect(assessment.score, 49);
        expect(assessment.band, AarEvidenceBand.partial);
      },
    );

    test('T5.2 zero analysis client calls during scoring', () async {
      await container.read(aarEvidenceAssessmentProvider(encounter).future);
      expect(codex.calls, 0);
    });

    test('T5.3 invalidating the enrichment provider recomputes', () async {
      final first = await container.read(
        aarEvidenceAssessmentProvider(encounter).future,
      );
      expect(first.score, 49);

      holder.enrichment = enrichment(
        parsedEncounterId: encounter.id,
        victimFitEvidence: holder.enrichment?.victimFitEvidence,
        pilotFitEvidence: fitEvidence(),
      );
      container.invalidate(combatEnrichmentProvider(encounter.id));

      final second = await container.read(
        aarEvidenceAssessmentProvider(encounter).future,
      );
      expect(second.score, 79);
      expect(second.band, AarEvidenceBand.good);
    });

    test('T5.4 scores with no enrichment row', () async {
      holder.enrichment = null;
      holder.bundle = const AarDerivationBundle.empty();
      container.invalidate(combatEnrichmentProvider(encounter.id));
      container.invalidate(aarFitDerivationsProvider(encounter));

      final assessment = await container.read(
        aarEvidenceAssessmentProvider(encounter).future,
      );
      expect(
        assessment[AarEvidenceDimension.pilotFit].status,
        AarEvidenceStatus.missing,
      );
      expect(
        assessment[AarEvidenceDimension.opponentIdentity].status,
        AarEvidenceStatus.missing,
      );
      expect(assessment[AarEvidenceDimension.opponentIdentity].actions, [
        AarEvidenceAction.searchKillmails,
      ]);
      expect(
        assessment[AarEvidenceDimension.combatLog].status,
        AarEvidenceStatus.complete,
      );
    });

    test(
      'E.5 provider error surfaces as AsyncError, not a throw in the scorer',
      () async {
        final failing = ProviderContainer(
          overrides: _overrides(holder, encounter, codex, throwIncoming: true),
        );
        addTearDown(failing.dispose);
        final provider = aarEvidenceAssessmentProvider(encounter);
        failing.listen(provider, (_, _) {});

        await expectLater(
          failing.read(provider.future),
          throwsA(isA<StateError>()),
        );
        expect(
          failing.read(provider),
          isA<AsyncError<AarEvidenceAssessment>>(),
        );
      },
    );
  });

  group('combatAttackerCorrelationProvider', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late ProviderContainer container;
    late ParsedCombatEncounter encounter;

    setUp(() {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      final s2 = s2Loss();
      encounter = s2.encounter;
      final enrichment = CombatEnrichment(
        parsedEncounterId: encounter.id,
        status: CombatEnrichmentStatus.killmailMatched,
        source: CombatEnrichmentSource.zkillEsi,
        rawKillmail: s2.detail.toJson(),
        attackerCorrelation: correlate(s2),
      );
      final service = CombatEnrichmentService(
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
      container = ProviderContainer(
        overrides: [
          combatEnrichmentProvider.overrideWith((ref, id) async => enrichment),
          combatEnrichmentServiceProvider.overrideWith((ref) => service),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await appDb.close();
      await sdeDb.close();
    });

    test(
      'combatAttackerCorrelationProvider(encounter) loads correlation from combatEnrichmentProvider',
      () async {
        final loaded = await container.read(
          combatAttackerCorrelationProvider(encounter).future,
        );
        expect(loaded, isNotNull);
        expect(
          loaded!.correlated.map((row) => row.actor.displayName),
          contains('Artem S3'),
        );
      },
    );
  });
}

class _Holder {
  _Holder(AarEvidenceInputs s1)
    : enrichment = s1.enrichment,
      bundle = AarDerivationBundle(
        self: derivation(),
        opponent: s1.bundle.opponent,
      ),
      incoming = s1.incoming,
      outgoing = s1.outgoing;

  CombatEnrichment? enrichment;
  AarDerivationBundle bundle;
  CombatDamageProfile incoming;
  CombatDamageProfile outgoing;
}

List<Override> _overrides(
  _Holder holder,
  ParsedCombatEncounter encounter,
  CountingCodexClient codex, {
  bool throwIncoming = false,
}) {
  return [
    combatEnrichmentProvider.overrideWith((ref, id) async => holder.enrichment),
    aarFitDerivationsProvider.overrideWith((ref, enc) async => holder.bundle),
    combatIncomingDamageProfileProvider.overrideWith((ref, enc) async {
      if (throwIncoming) {
        throw StateError('incoming profile failed');
      }
      return holder.incoming;
    }),
    combatDamageProfileProvider.overrideWith(
      (ref, enc) async => holder.outgoing,
    ),
    codexAnalysisClientProvider.overrideWithValue(codex),
    combatAnalysisServiceProvider.overrideWith(
      (ref) => throw StateError(
        'combatAnalysisServiceProvider must not be read during scoring',
      ),
    ),
  ];
}

class CountingCodexClient extends CodexAnalysisClient {
  CountingCodexClient()
    : super(
        authService: CodexAuthService(
          authStore: CodexAuthStore(
            authFilePath: '/tmp/mimir-u3-unused-auth.json',
          ),
        ),
      );

  int calls = 0;

  @override
  Future<CodexAnalysisResult> analyzeEncounter({
    required ParsedCombatEncounter encounter,
    required String model,
    CombatEnrichment? enrichment,
    AarDerivationBundle? derivation,
  }) async {
    calls += 1;
    throw StateError('analyzeEncounter must not be called during scoring');
  }
}

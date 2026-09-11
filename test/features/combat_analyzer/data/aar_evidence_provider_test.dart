import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_service.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_store.dart';
import 'package:mimir/features/combat_analyzer/data/combat_analysis_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

import '../fixtures/aar_evidence_fixtures.dart';

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
          overrides: [
            ..._overrides(holder, encounter, codex),
            combatIncomingDamageProfileProvider.overrideWith(
              (ref, enc) => throw StateError('incoming profile failed'),
            ),
          ],
        );
        addTearDown(failing.dispose);
        final provider = aarEvidenceAssessmentProvider(encounter);
        failing.listen(provider, (_, __) {});

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

_overrides(
  _Holder holder,
  ParsedCombatEncounter encounter,
  CountingCodexClient codex,
) {
  return [
    combatEnrichmentProvider.overrideWith((ref, id) async => holder.enrichment),
    aarFitDerivationsProvider.overrideWith((ref, enc) async => holder.bundle),
    combatIncomingDamageProfileProvider.overrideWith(
      (ref, enc) async => holder.incoming,
    ),
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

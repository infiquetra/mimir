import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:mimir/features/combat_analyzer/data/combat_analysis_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/presentation/analysis_multipane_screen.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_evidence_checklist_card.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_pre_analysis_gate.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group H — AnalysisMultiPaneScreen evidence integration', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late Holder holder;
    late ParsedCombatEncounter encounter;
    late FakeEnrichmentService enrichmentService;
    late FakeAnalysisService analysisService;

    setUp(() {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      final s1 = s1Inputs();
      encounter = s1.encounter;
      holder = Holder(s1);
      enrichmentService = FakeEnrichmentService(
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
        holder: holder,
      );
      analysisService = FakeAnalysisService(
        database: appDb,
        codexClient: _UnusedCodexClient(),
        enrichmentService: enrichmentService,
      );
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      CombatEncounter? cached,
      AarEvidenceAssessment? assessmentOverride,
    }) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      analysisService.cached = cached;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(appDb),
            sdeInitializerProvider.overrideWith((ref) async {}),
            combatAnalysisServiceProvider.overrideWithValue(analysisService),
            combatEnrichmentServiceProvider.overrideWithValue(
              enrichmentService,
            ),
            combatEnrichmentProvider.overrideWith(
              (ref, id) async => holder.enrichment,
            ),
            aarFitDerivationsProvider.overrideWith(
              (ref, enc) async => holder.bundle,
            ),
            combatIncomingDamageProfileProvider.overrideWith(
              (ref, enc) async => holder.incoming,
            ),
            combatDamageProfileProvider.overrideWith(
              (ref, enc) async => holder.outgoing,
            ),
            if (assessmentOverride != null)
              aarEvidenceAssessmentProvider.overrideWith(
                (ref, enc) async => assessmentOverride,
              ),
            itemNameProvider.overrideWith((ref, id) async {
              return switch (id) {
                587 => 'Rifter',
                24700 => 'Myrmidon',
                _ => 'Type $id',
              };
            }),
          ],
          child: MaterialApp(
            home: AnalysisMultiPaneScreen(encounter: encounter),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    CombatEncounter cachedRow({
      AarEvidenceSnapshot? snapshot,
      bool legacy = false,
    }) {
      final report = CombatAarReport(
        headline: 'Test headline',
        summary: 'Summary',
        outcomeAssessment: 'Outcome',
        keyMoments: const [],
        rankedMistakes: const [],
        recommendations: const [],
        fitAdvice: const [],
        trainingDrills: const [],
        damageAnalysis: const AarDamageAnalysis.empty(),
        resourceTopicIds: const [],
        confidence: 0.9,
        unknowns: const [],
        evidenceAtGeneration: snapshot,
      );
      return CombatEncounter(
        id: encounter.id,
        parsedEncounterId: encounter.id,
        analysisVersion: 3,
        analysisJson: legacy ? null : jsonEncode(report.toJson()),
        encounterTime: encounter.startTime,
        opposingCharacters: '[]',
        opposingCorporations: '[]',
        opposingAlliances: '[]',
        opposingShipTypes: '[]',
        totalDamageDealt: encounter.totalDamageDealt,
        totalDamageReceived: encounter.totalDamageReceived,
        isVictory: true,
        llmSummary: 'Summary',
        llmFeedbackMistakes: 'Mistake',
        llmFeedbackImprovements: 'Improve',
        llmFeedbackFits: 'Fit',
        damageChartData: '[]',
      );
    }

    testWidgets('T8.1 card renders above the killmail chips post-analysis', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        cached: cachedRow(snapshot: _snapshot(score: 49)),
      );
      expect(find.byType(AarEvidenceChecklistCard), findsWidgets);
      expect(
        tester.getTopLeft(find.byType(AarEvidenceChecklistCard).first).dy,
        lessThan(tester.getTopLeft(find.text('Evidence').first).dy),
      );
    });

    testWidgets('T8.2 old three-button Wrap no longer renders', (tester) async {
      await pumpScreen(
        tester,
        cached: cachedRow(snapshot: _snapshot(score: 49)),
      );
      expect(find.text('Import Pilot Fit'), findsNothing);
      expect(find.text('Snapshot Current Fit'), findsNothing);
      expect(find.text('Use Current Fit For This Fight'), findsNothing);
      expect(find.text('Reauthorize Character'), findsNothing);
    });

    testWidgets(
      'T8.3 tapping Use Current Fit on the row invokes the capture path',
      (tester) async {
        await pumpScreen(tester);
        final useFit = find.byKey(
          const Key('aar-evidence-action-useCurrentFit-pilotFit'),
        );
        expect(useFit, findsOneWidget);
        await tester.ensureVisible(useFit);
        await tester.tap(useFit);
        await tester.pump();
        expect(enrichmentService.captureCalls, [
          (encounter.id, confirmed: true),
        ]);
      },
    );

    testWidgets('T8.4 after capture the score rises and the row moves', (
      tester,
    ) async {
      await pumpScreen(tester);
      final useFit = find.byKey(
        const Key('aar-evidence-action-useCurrentFit-pilotFit'),
      );
      expect(useFit, findsOneWidget);
      await tester.ensureVisible(useFit);
      await tester.tap(useFit);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('79%'), findsWidgets);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('aar-evidence-row-pilotFit')))
            .dy,
        greaterThan(
          tester
              .getTopLeft(
                find.byKey(const Key('aar-evidence-row-damageProfile')),
              )
              .dy,
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('aar-evidence-row-pilotFit')),
          matching: find.byType(OutlinedButton),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'T8.5 score chip renders next to the analyze button in the empty state',
      (tester) async {
        holder.enrichment = enrichment(
          parsedEncounterId: encounter.id,
          victimFitEvidence: holder.enrichment?.victimFitEvidence,
          pilotFitEvidence: fitEvidence(),
        );
        await pumpScreen(tester);
        expect(find.byKey(const Key('aar-gate-chip')), findsOneWidget);
        expect(find.byKey(const Key('aar-analyze-button')), findsOneWidget);
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.byKey(const Key('aar-gate-chip')),
              matching: find.byType(Row),
            ),
            matching: find.byKey(const Key('aar-analyze-button')),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('H.6 pre-analysis renders the full checklist card', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byType(AarEvidenceChecklistCard), findsOneWidget);
      expect(find.byType(AarPreAnalysisGate), findsOneWidget);
    });

    testWidgets(
      'H.7 provenance banner: recorded 49, current 79 → re-analyze prompt',
      (tester) async {
        holder.enrichment = enrichment(
          parsedEncounterId: encounter.id,
          victimFitEvidence: holder.enrichment?.victimFitEvidence,
          pilotFitEvidence: fitEvidence(),
        );
        await pumpScreen(
          tester,
          cached: cachedRow(snapshot: _snapshot(score: 49)),
        );
        expect(
          find.byKey(const Key('aar-provenance-recorded')),
          findsOneWidget,
        );
        expect(
          find.textContaining('generated at 49% Partial evidence'),
          findsOneWidget,
        );
        expect(find.textContaining('Evidence is now 79%'), findsOneWidget);
        expect(
          find.byKey(const Key('aar-provenance-reanalyze')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('aar-provenance-reanalyze')));
        await tester.pump();
        expect(analysisService.analyzeCalls, isNotEmpty);
        expect(analysisService.analyzeCalls.last.forceRefresh, isTrue);
      },
    );

    testWidgets('H.8 provenance banner: recorded 79, current 85 → no prompt', (
      tester,
    ) async {
      final current85 = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.partial,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.complete,
          d4: AarEvidenceStatus.complete,
          d5: AarEvidenceStatus.complete,
        ),
      );
      expect(current85.score, 85);
      await pumpScreen(
        tester,
        cached: cachedRow(
          snapshot: _snapshot(score: 79, band: AarEvidenceBand.good),
        ),
        assessmentOverride: current85,
      );
      expect(find.byKey(const Key('aar-provenance-recorded')), findsOneWidget);
      expect(
        find.textContaining('generated at 79% Good evidence'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('aar-provenance-reanalyze')), findsNothing);
    });

    testWidgets('H.9 legacy report shows "not recorded"', (tester) async {
      await pumpScreen(tester, cached: cachedRow(legacy: true));
      expect(find.text('Evidence at generation: not recorded'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
    });

    testWidgets(
      'H.10 Search Killmails row action calls enrichEncounter and invalidates',
      (tester) async {
        holder.enrichment = null;
        holder.bundle = const AarDerivationBundle.empty();
        await pumpScreen(tester);
        final search = find.byKey(
          const Key('aar-evidence-action-searchKillmails-opponentIdentity'),
        );
        expect(search, findsOneWidget);
        await tester.ensureVisible(search);
        await tester.tap(search);
        await tester.pump();
        await tester.pump();
        expect(enrichmentService.enrichCalls, hasLength(1));
        expect(
          find.descendant(
            of: find.byKey(const Key('aar-evidence-row-opponentIdentity')),
            matching: find.text('Complete'),
          ),
          findsOneWidget,
        );
        expect(search, findsNothing);
      },
    );
  });
}

AarEvidenceSnapshot _snapshot({
  required int score,
  AarEvidenceBand band = AarEvidenceBand.partial,
}) {
  return AarEvidenceSnapshot(
    score: score,
    band: band,
    capped: false,
    statuses: const {
      AarEvidenceDimension.pilotFit: AarEvidenceStatus.missing,
      AarEvidenceDimension.combatLog: AarEvidenceStatus.complete,
      AarEvidenceDimension.opponentIdentity: AarEvidenceStatus.complete,
      AarEvidenceDimension.opponentFit: AarEvidenceStatus.inferred,
      AarEvidenceDimension.damageProfile: AarEvidenceStatus.partial,
    },
  );
}

class Holder {
  Holder(AarEvidenceInputs s1)
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

class FakeAnalysisService extends CombatAnalysisService {
  FakeAnalysisService({
    required super.database,
    required super.codexClient,
    required super.enrichmentService,
  });

  CombatEncounter? cached;
  final analyzeCalls = <({bool forceRefresh})>[];

  @override
  Future<CombatEncounter?> getCachedAnalysis(
    ParsedCombatEncounter encounter,
  ) async {
    return cached;
  }

  @override
  Future<CombatEncounter> analyzeEncounter(
    ParsedCombatEncounter encounter, {
    bool forceRefresh = false,
    CombatAnalysisProgressCallback? onProgress,
  }) async {
    analyzeCalls.add((forceRefresh: forceRefresh));
    return cached ??
        CombatEncounter(
          id: encounter.id,
          encounterTime: encounter.startTime,
          opposingCharacters: '[]',
          opposingCorporations: '[]',
          opposingAlliances: '[]',
          opposingShipTypes: '[]',
          totalDamageDealt: 0,
          totalDamageReceived: 0,
          isVictory: true,
          llmSummary: 'ok',
          llmFeedbackMistakes: '',
          llmFeedbackImprovements: '',
          llmFeedbackFits: '',
          damageChartData: '[]',
        );
  }
}

class FakeEnrichmentService extends CombatEnrichmentService {
  FakeEnrichmentService({
    required super.repository,
    required super.esiClient,
    required super.discoveryClient,
    required super.tokenManager,
    required super.oauthService,
    required super.sdeService,
    required this.holder,
  });

  Holder holder;
  final captureCalls = <(String, {bool confirmed})>[];
  final enrichCalls = <String>[];

  @override
  Future<CombatEnrichment?> loadEnrichment(String parsedEncounterId) async {
    return holder.enrichment;
  }

  @override
  Future<CombatEnrichment> captureCurrentPilotFit(
    ParsedCombatEncounter encounter, {
    bool confirmed = false,
  }) async {
    captureCalls.add((encounter.id, confirmed: confirmed));
    holder.enrichment = enrichment(
      parsedEncounterId: encounter.id,
      victimFitEvidence: holder.enrichment?.victimFitEvidence,
      pilotFitEvidence: fitEvidence(),
    );
    holder.bundle = AarDerivationBundle(
      self: derivation(),
      opponent: holder.bundle.opponent,
    );
    return holder.enrichment!;
  }

  @override
  Future<CombatEnrichment> enrichEncounter(
    ParsedCombatEncounter encounter, {
    bool forceRefresh = false,
  }) async {
    enrichCalls.add(encounter.id);
    holder.enrichment = enrichment(
      parsedEncounterId: encounter.id,
      victimFitEvidence: fitEvidence(
        role: FitEvidenceRole.victim,
        source: EvidenceSource.killmail,
        confidence: EvidenceConfidence.proven,
      ),
    );
    holder.bundle = AarDerivationBundle(
      self: holder.bundle.self,
      opponent: derivation(
        subject: AarFitSubject.opponent,
        fitSource: EvidenceSource.killmail,
      ),
    );
    return holder.enrichment!;
  }
}

class _UnusedCodexClient extends CodexAnalysisClient {
  _UnusedCodexClient()
    : super(
        authService: CodexAuthService(
          authStore: CodexAuthStore(
            authFilePath: '/tmp/mimir-u5-unused-auth.json',
          ),
        ),
      );
}

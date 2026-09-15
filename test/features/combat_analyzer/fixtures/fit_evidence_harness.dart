import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/auth_providers.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/core/theme/app_theme.dart';
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_service.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_store.dart';
import 'package:mimir/features/combat_analyzer/data/combat_analysis_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_repository.dart';
import 'package:mimir/features/combat_analyzer/data/combat_enrichment_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_fit_derivation_service.dart';
import 'package:mimir/features/combat_analyzer/data/combat_killmail_discovery_client.dart';
import 'package:mimir/features/combat_analyzer/data/combat_providers.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/presentation/analysis_multipane_screen.dart';
import 'package:mimir/features/skills/data/skill_repository.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';

/// Real-storage AAR fit-evidence test harness.
///
/// Databases live outside the widget tree so a ProviderScope can be disposed
/// and reopened over the same SQL. Unexpected ESI HTTP is a test failure.
class FitEvidenceHarness {
  FitEvidenceHarness();

  static const int characterAId = 42;
  static const int characterBId = 99;
  static const String characterAName = 'Pilot';
  static const String characterBName = 'Other Pilot';
  static DateTime clock() => DateTime.utc(2026, 9, 15, 12);

  late final AppDatabase appDb;
  late final SdeDatabase sdeDb;
  late final SdeService sdeService;
  late final TokenManager tokenManager;
  late final OAuthService oauthService;
  late final ScriptedEsiAdapter esiAdapter;
  late final EsiClient esiClient;
  late final GatedEnrichmentRepository repository;
  late final RecordingDiscoveryClient discovery;
  late final RecordingCodexClient codex;
  late final CombatEnrichmentService enrichmentService;
  late final CombatFitDerivationService derivationService;
  late final CombatDamageProfileResolver damageResolver;
  late final CombatAnalysisService analysisService;
  late final SkillRepository skillRepository;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _tornDown = false;

  /// Finite SDE revision stream. The production provider watches Drift
  /// `tableUpdates` for the life of the scope; cancelling that watch and then
  /// closing the in-memory SDE database deadlocks NativeDatabase.close.
  static const AarSdeRevision sdeRevision = AarSdeRevision(
    generation: 0,
    contentKey: 'sde-decimal-v1',
  );

  Future<void> setUp() async {
    appDb = AppDatabase.forTesting(NativeDatabase.memory());
    sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
    sdeService = SdeService(database: sdeDb);
    oauthService = OAuthService();
    tokenManager = TokenManager(database: appDb);
    esiAdapter = ScriptedEsiAdapter();
    final dio = Dio();
    esiClient = EsiClient(
      tokenManager: tokenManager,
      oauthService: oauthService,
      database: appDb,
      dio: dio,
    );
    dio.httpClientAdapter = esiAdapter;
    repository = GatedEnrichmentRepository(database: appDb);
    discovery = RecordingDiscoveryClient();
    codex = RecordingCodexClient();
    skillRepository = SkillRepository(database: appDb, esiClient: esiClient);
    enrichmentService = CombatEnrichmentService(
      repository: repository,
      esiClient: esiClient,
      discoveryClient: discovery,
      tokenManager: tokenManager,
      oauthService: oauthService,
      sdeService: sdeService,
    );
    derivationService = CombatFitDerivationService(
      sde: sdeService,
      skills: skillRepository,
    );
    damageResolver = CombatDamageProfileResolver(database: sdeDb);
    analysisService = CombatAnalysisService(
      database: appDb,
      codexClient: codex,
      enrichmentService: enrichmentService,
      derivationService: derivationService,
      damageProfileResolver: damageResolver,
    );
    await seedMinimalSde();
    await seedCharacters();
    await sdeService.initialize();
  }

  /// Unmount the widget tree and its ProviderScope before [tearDown].
  Future<void> disposeWidgets(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// Cancel the ESI error-limit Drift watch and flush its close timer.
  Future<void> disposeEsiWatch(WidgetTester tester) async {
    esiClient.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// ESI error-limit subscription, then databases. Call [disposeWidgets] first
  /// from widget tests; do not close databases inside a testWidgets body.
  Future<void> tearDown() async {
    if (_tornDown) return;
    _tornDown = true;
    final allow = repository.allowMutation;
    if (allow != null && !allow.isCompleted) {
      allow.complete();
    }
    esiClient.dispose();
    await sdeDb.close();
    await appDb.close();
  }

  Future<void> seedMinimalSde() async {
    await sdeDb.upsertCategories([
      SdeCategoriesCompanion.insert(
        categoryId: const Value(6),
        categoryName: 'Ship',
      ),
      SdeCategoriesCompanion.insert(
        categoryId: const Value(7),
        categoryName: 'Module',
      ),
      SdeCategoriesCompanion.insert(
        categoryId: const Value(16),
        categoryName: 'Skill',
      ),
    ]);
    await sdeDb.upsertGroups([
      SdeGroupsCompanion.insert(
        groupId: const Value(25),
        groupName: 'Frigate',
        categoryId: 6,
      ),
      SdeGroupsCompanion.insert(
        groupId: const Value(255),
        groupName: 'Gunnery',
        categoryId: 16,
      ),
    ]);
    await sdeDb.upsertTypes([
      SdeTypesCompanion.insert(
        typeId: const Value(587),
        typeName: 'Rifter',
        groupId: 25,
      ),
      SdeTypesCompanion.insert(
        typeId: const Value(3300),
        typeName: 'Gunnery',
        groupId: 255,
      ),
    ]);
    await sdeDb.upsertTypeAttributes([
      SdeTypeAttributesCompanion.insert(
        typeId: 587,
        attributeId: 9,
        value: 350,
      ),
      SdeTypeAttributesCompanion.insert(
        typeId: 587,
        attributeId: 263,
        value: 450,
      ),
    ]);
    await sdeDb.setMetadata(
      'dogma_version',
      '${SdeService.bundledDogmaVersion}',
    );
  }

  Future<void> seedCharacters() async {
    final expiry = clock().add(const Duration(days: 30));
    await appDb.upsertCharacter(
      CharactersCompanion.insert(
        characterId: const Value(characterAId),
        name: characterAName,
        corporationId: 1000001,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.test/a.png',
        tokenExpiry: expiry,
        lastUpdated: clock(),
        accessToken: const Value('access-a'),
        refreshToken: const Value('refresh-a'),
        isActive: const Value(true),
      ),
    );
    await appDb.upsertCharacter(
      CharactersCompanion.insert(
        characterId: const Value(characterBId),
        name: characterBName,
        corporationId: 1000002,
        corporationName: 'Other Corp',
        portraitUrl: 'https://example.test/b.png',
        tokenExpiry: expiry,
        lastUpdated: clock(),
        accessToken: const Value('access-b'),
        refreshToken: const Value('refresh-b'),
        isActive: const Value(false),
      ),
    );
  }

  Future<void> seedCachedReport(
    ParsedCombatEncounter encounter, {
    CombatAarReport? report,
  }) async {
    final body =
        report ??
        CombatAarReport.fromLegacy(
          summary: 'Cached summary',
          mistakes: '',
          improvements: '',
          fits: '',
        );
    await appDb
        .into(appDb.combatEncounters)
        .insert(
          CombatEncounter(
            id: encounter.id,
            parsedEncounterId: encounter.id,
            analysisVersion: 3,
            analysisJson: jsonEncode(body.toJson()),
            encounterTime: encounter.startTime,
            opposingCharacters: '[]',
            opposingCorporations: '[]',
            opposingAlliances: '[]',
            opposingShipTypes: '[]',
            totalDamageDealt: encounter.totalDamageDealt,
            totalDamageReceived: encounter.totalDamageReceived,
            isVictory: true,
            llmSummary: body.summary,
            llmFeedbackMistakes: '',
            llmFeedbackImprovements: '',
            llmFeedbackFits: '',
            damageChartData: '[]',
          ),
        );
  }

  List<Override> overrides() {
    return [
      databaseProvider.overrideWithValue(appDb),
      sdeDatabaseProvider.overrideWithValue(sdeDb),
      sdeServiceProvider.overrideWithValue(sdeService),
      sdeInitializerProvider.overrideWith((ref) async {
        if (!sdeService.isInitialized) {
          await sdeService.initialize();
        }
      }),
      tokenManagerProvider.overrideWithValue(tokenManager),
      oauthServiceProvider.overrideWithValue(oauthService),
      esiClientProvider.overrideWithValue(esiClient),
      combatEnrichmentRepositoryProvider.overrideWithValue(repository),
      combatKillmailDiscoveryClientProvider.overrideWithValue(discovery),
      combatEnrichmentServiceProvider.overrideWithValue(enrichmentService),
      combatFitDerivationServiceProvider.overrideWithValue(derivationService),
      combatDamageProfileResolverProvider.overrideWithValue(damageResolver),
      combatAnalysisServiceProvider.overrideWithValue(analysisService),
      skillRepositoryProvider.overrideWithValue(skillRepository),
      codexAnalysisClientProvider.overrideWithValue(codex),
      aarSdeRevisionProvider.overrideWith(
        (ref) => Stream<AarSdeRevision>.value(sdeRevision),
      ),
      aarLocalSkillsProvider.overrideWith((ref, characterId) {
        return Stream<List<dynamic>>.fromFuture(
          skillRepository
              .getCharacterSkills(characterId)
              .then(List<dynamic>.from),
        );
      }),
      itemNameProvider.overrideWith((ref, id) async {
        return switch (id) {
          587 => 'Rifter',
          _ => 'Unknown Item',
        };
      }),
    ];
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required ParsedCombatEncounter encounter,
    Size size = const Size(1400, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          home: AnalysisMultiPaneScreen(encounter: encounter),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> reopen(
    WidgetTester tester, {
    required ParsedCombatEncounter encounter,
  }) async {
    await disposeWidgets(tester);
    await pumpScreen(tester, encounter: encounter);
  }

  Future<void> replaceEncounter(
    WidgetTester tester, {
    required ParsedCombatEncounter encounter,
  }) async {
    await pumpScreen(tester, encounter: encounter);
  }

  Future<Finder> waitFor(
    WidgetTester tester,
    Finder finder, {
    int pumps = 40,
  }) async {
    for (var i = 0; i < pumps; i++) {
      if (finder.evaluate().isNotEmpty) return finder;
      await tester.pump(const Duration(milliseconds: 50));
    }
    return finder;
  }
}

class ScriptedEsiAdapter implements HttpClientAdapter {
  final _scripts =
      <bool Function(RequestOptions), ResponseBody Function(RequestOptions)>{};
  final requests = <RequestOptions>[];

  void script(
    bool Function(RequestOptions options) match,
    ResponseBody Function(RequestOptions options) reply,
  ) {
    _scripts[match] = reply;
  }

  void scriptJson(
    bool Function(RequestOptions options) match,
    Object body, {
    int statusCode = 200,
    Map<String, List<String>> headers = const {},
  }) {
    script(match, (options) {
      return ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...headers,
        },
      );
    });
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    for (final entry in _scripts.entries) {
      if (entry.key(options)) {
        return entry.value(options);
      }
    }
    throw StateError('unexpected ESI HTTP ${options.method} ${options.uri}');
  }

  @override
  void close({bool force = false}) {}
}

class RecordingDiscoveryClient extends CombatKillmailDiscoveryClient {
  final fetches =
      <({int characterId, int year, int month, String direction, int page})>[];
  List<CombatZkillKillmailRef> Function({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
  })?
  onFetch;

  @override
  Future<List<CombatZkillKillmailRef>> fetchCharacterPage({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
  }) async {
    fetches.add((
      characterId: characterId,
      year: year,
      month: month,
      direction: direction,
      page: page,
    ));
    return onFetch?.call(
          characterId: characterId,
          year: year,
          month: month,
          direction: direction,
          page: page,
        ) ??
        const [];
  }
}

class RecordingCodexClient extends CodexAnalysisClient {
  RecordingCodexClient()
    : super(
        authService: CodexAuthService(
          authStore: CodexAuthStore(
            authFilePath: '/tmp/mimir-fit-evidence-unused.json',
          ),
        ),
      );

  int calls = 0;
  CombatEnrichment? lastEnrichment;
  AarDerivationBundle? lastDerivation;
  AarIncomingMatchupBundle? lastPerAttackerIncoming;
  Object? error;
  CodexAnalysisResult? result;

  @override
  Future<CodexAnalysisResult> analyzeEncounter({
    required ParsedCombatEncounter encounter,
    required String model,
    CombatEnrichment? enrichment,
    AarDerivationBundle? derivation,
    AarIncomingMatchupBundle? perAttackerIncoming,
  }) async {
    calls += 1;
    lastEnrichment = enrichment;
    lastDerivation = derivation;
    lastPerAttackerIncoming = perAttackerIncoming;
    if (error != null) {
      throw error!;
    }
    return result ??
        CodexAnalysisResult(
          report: CombatAarReport.fromLegacy(
            summary: 'ok',
            mistakes: '',
            improvements: '',
            fits: '',
          ),
        );
  }
}

class GatedEnrichmentRepository extends CombatEnrichmentRepository {
  GatedEnrichmentRepository({required super.database});

  int saveCalls = 0;
  Completer<void>? mutationEntered;
  Completer<void>? allowMutation;
  Object? failWith;

  @override
  Future<void> saveEnrichment(CombatEnrichment enrichment) async {
    saveCalls += 1;
    final entered = mutationEntered;
    if (entered != null && !entered.isCompleted) {
      entered.complete();
    }
    if (allowMutation != null) {
      await allowMutation!.future;
    }
    if (failWith != null) {
      throw failWith!;
    }
    await super.saveEnrichment(enrichment);
  }
}

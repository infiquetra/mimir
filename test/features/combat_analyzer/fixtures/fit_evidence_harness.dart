import 'dart:async';
import 'dart:convert';

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
import 'package:mimir/features/combat_analyzer/data/aar_evidence_operation_coordinator.dart';
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
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/combat_analyzer/presentation/analysis_multipane_screen.dart';
import 'package:mimir/features/skills/data/skill_repository.dart';
import 'package:mimir/features/wallet/data/wallet_providers.dart';

import 'aar_comparison_fixtures.dart';
import 'aar_fit_import_fixtures.dart';

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
  static DateTime defaultClock() => DateTime.utc(2026, 9, 15, 12);

  /// Injected clock. Tests may replace this before [setUp].
  DateTime Function() clock = defaultClock;

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
  late final GatedFitDerivationService derivationService;
  late final CombatDamageProfileResolver damageResolver;
  late final CombatAnalysisService analysisService;
  late final SkillRepository skillRepository;
  late final AarEvidenceOperationCoordinator coordinator;

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
    coordinator = AarEvidenceOperationCoordinator();
    skillRepository = SkillRepository(database: appDb, esiClient: esiClient);
    enrichmentService = CombatEnrichmentService(
      repository: repository,
      esiClient: esiClient,
      discoveryClient: discovery,
      tokenManager: tokenManager,
      oauthService: oauthService,
      sdeService: sdeService,
      coordinator: coordinator,
    );
    derivationService = GatedFitDerivationService(
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
      coordinator: coordinator,
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
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
    final allowDerive = derivationService.allowDerive;
    if (allowDerive != null && !allowDerive.isCompleted) {
      allowDerive.complete();
    }
    esiClient.dispose();
    coordinator.dispose();
    await sdeDb.close();
    await appDb.close();
  }

  Future<void> seedMinimalSde() async {
    await seedAarImportSde(sdeDb);
    await seedComparisonSde(sdeDb);
  }

  Future<void> seedComparisonFixtures() => seedComparisonSde(sdeDb);

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

  /// Default test overrides pin the enrichment service and finite SDE/skill
  /// streams so widget teardown cannot deadlock NativeDatabase.close.
  List<Override> overrides() {
    return _overrides(
      pinEnrichmentService: true,
      pinFiniteRevisionStreams: true,
    );
  }

  /// Production-provider-composition variant. Does not override
  /// [combatEnrichmentServiceProvider], [aarSdeRevisionProvider], or
  /// [aarLocalSkillsProvider], so live revision/publication watches stay
  /// wired. Callers must dispose the ProviderScope, then the ESI watch,
  /// then close databases — a live SDE `tableUpdates` watch plus
  /// NativeDatabase.close can deadlock.
  List<Override> productionCompositionOverrides() {
    return _overrides(
      pinEnrichmentService: false,
      pinFiniteRevisionStreams: false,
    );
  }

  static const pinnedLiveSeams = {
    'combatEnrichmentServiceProvider',
    'aarSdeRevisionProvider',
    'aarLocalSkillsProvider',
  };

  List<Override> _overrides({
    required bool pinEnrichmentService,
    required bool pinFiniteRevisionStreams,
  }) {
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
      if (pinEnrichmentService)
        combatEnrichmentServiceProvider.overrideWithValue(enrichmentService),
      combatFitDerivationServiceProvider.overrideWithValue(derivationService),
      combatDamageProfileResolverProvider.overrideWithValue(damageResolver),
      combatAnalysisServiceProvider.overrideWithValue(analysisService),
      aarEvidenceOperationCoordinatorProvider.overrideWith(
        (ref) => coordinator,
      ),
      skillRepositoryProvider.overrideWithValue(skillRepository),
      codexAnalysisClientProvider.overrideWithValue(codex),
      if (pinFiniteRevisionStreams) ...[
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
      ],
      itemNameProvider.overrideWith((ref, id) async {
        return switch (id) {
          587 => 'Rifter',
          2048 => 'Damage Control II',
          5973 => '1MN Afterburner II',
          484 => '125mm Gatling AutoCannon II',
          3117 => 'Small Projectile Burst Aerator I',
          2456 => 'Hobgoblin II',
          185 => 'EMP S',
          9020 => 'UniqueShip',
          kAarMseTypeId => 'Medium Shield Extender II',
          kAarRailgunTypeId => 'Railgun',
          _ => kCmpTypeNames[id] ?? 'Unknown Item',
        };
      }),
    ];
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required ParsedCombatEncounter encounter,
    Size size = const Size(1400, 1200),
    List<Override> extraOverrides = const [],
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides(), ...extraOverrides],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              devicePixelRatio: 1,
              textScaler: TextScaler.linear(textScale),
            ),
            child: AnalysisMultiPaneScreen(encounter: encounter),
          ),
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

  Future<void> activateCharacter(int characterId) {
    return appDb.setActiveCharacter(characterId);
  }

  Future<void> seedKnownSkills({
    int characterId = characterAId,
    Map<int, int> levels = const {3300: 5},
  }) {
    return appDb.replaceCharacterSkills(characterId, [
      for (final entry in levels.entries)
        CharacterSkillsCompanion.insert(
          characterId: characterId,
          skillId: entry.key,
          trainedSkillLevel: entry.value,
          activeSkillLevel: entry.value,
          skillpointsInSkill: 256000,
          lastUpdated: clock(),
        ),
    ]);
  }

  Future<void> seedDefenseSde() => seedAarDefenseSde(sdeDb);

  void scriptCharacterShip({
    int characterId = characterAId,
    int shipTypeId = 587,
    int shipItemId = kAarShipItemId,
    String shipName = 'Manual Rifter',
    String? shipTypeName = 'Rifter',
    int statusCode = 200,
    Future<void>? delay,
  }) {
    esiAdapter.script(
      (options) {
        return options.uri.path.contains('/characters/$characterId/ship');
      },
      (options) async {
        if (delay != null) await delay;
        return ResponseBody.fromString(
          jsonEncode({
            'ship_type_id': shipTypeId,
            'ship_item_id': shipItemId,
            'ship_name': shipName,
            'ship_type_name': ?shipTypeName,
          }),
          statusCode,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      },
    );
  }

  void scriptAssetPage({
    required int characterId,
    required int page,
    required Object body,
    int totalPages = 1,
    int statusCode = 200,
    String? xPages,
  }) {
    esiAdapter.scriptJson(
      (options) => _isAssetPage(options, characterId, page),
      body,
      statusCode: statusCode,
      headers: {
        'x-pages': [xPages ?? '$totalPages'],
      },
    );
  }

  void scriptFittedCapture({
    int characterId = characterAId,
    int shipTypeId = 587,
    int shipItemId = kAarShipItemId,
    String shipName = 'Manual Rifter',
    String shipTypeName = 'Rifter',
    bool twoPages = false,
    bool unrelated = false,
    bool emptyInventory = false,
    Future<void>? delayShip,
  }) {
    scriptCharacterShip(
      characterId: characterId,
      shipTypeId: shipTypeId,
      shipItemId: shipItemId,
      shipName: shipName,
      shipTypeName: shipTypeName,
      delay: delayShip,
    );
    if (emptyInventory) {
      scriptAssetPage(
        characterId: characterId,
        page: 1,
        body: const <Map<String, dynamic>>[],
      );
      return;
    }
    if (twoPages) {
      scriptAssetPage(
        characterId: characterId,
        page: 1,
        body: aarFittedPage1(shipItemId: shipItemId),
        totalPages: 2,
      );
      scriptAssetPage(
        characterId: characterId,
        page: 2,
        body: aarFittedPage2(shipItemId: shipItemId, unrelated: unrelated),
        totalPages: 2,
      );
      return;
    }
    scriptAssetPage(
      characterId: characterId,
      page: 1,
      body: [
        ...aarFittedPage1(shipItemId: shipItemId),
        ...aarFittedPage2(shipItemId: shipItemId, unrelated: unrelated),
      ],
    );
  }

  static String killmailAccessToken({int characterId = characterAId}) {
    String encode(Map<String, Object> json) {
      return base64Url
          .encode(utf8.encode(jsonEncode(json)))
          .replaceAll('=', '');
    }

    final header = encode({'alg': 'none', 'typ': 'JWT'});
    final payload = encode({
      'sub': 'CHARACTER:EVE:$characterId',
      'name': characterId == characterAId ? characterAName : characterBName,
      'exp': 2000000000,
      'scp': ['esi-killmails.read_killmails.v1'],
    });
    return '$header.$payload.sig';
  }

  Future<void> grantKillmailScope({int characterId = characterAId}) async {
    final expiry = clock().add(const Duration(days: 30));
    final isA = characterId == characterAId;
    await appDb.upsertCharacter(
      CharactersCompanion.insert(
        characterId: Value(characterId),
        name: isA ? characterAName : characterBName,
        corporationId: isA ? 1000001 : 1000002,
        corporationName: isA ? 'Test Corp' : 'Other Corp',
        portraitUrl: isA
            ? 'https://example.test/a.png'
            : 'https://example.test/b.png',
        tokenExpiry: expiry,
        lastUpdated: clock(),
        accessToken: Value(killmailAccessToken(characterId: characterId)),
        refreshToken: Value(isA ? 'refresh-a' : 'refresh-b'),
        isActive: Value(isA),
      ),
    );
  }

  void scriptMatchedKillmail({int characterId = characterAId}) {
    esiAdapter.scriptJson(
      (options) => options.uri.path.contains(
        '/characters/$characterId/killmails/recent',
      ),
      [
        {'killmail_id': kAarKillmailId, 'killmail_hash': kAarKillmailHash},
      ],
    );
    esiAdapter.scriptJson(
      (options) => options.uri.path.contains(
        '/killmails/$kAarKillmailId/$kAarKillmailHash',
      ),
      aarMatchedKillmailJson(attackerCharacterId: characterId),
    );
    discovery.onFetch =
        ({
          required int characterId,
          required int year,
          required int month,
          required String direction,
          required int page,
        }) {
          if (page > 1) return const [];
          return const [
            CombatZkillKillmailRef(
              killmailId: kAarKillmailId,
              killmailHash: kAarKillmailHash,
            ),
          ];
        };
  }

  void scriptNoMatchKillmails({int characterId = characterAId}) {
    esiAdapter.scriptJson(
      (options) => options.uri.path.contains(
        '/characters/$characterId/killmails/recent',
      ),
      const [],
    );
    discovery.onFetch =
        ({
          required int characterId,
          required int year,
          required int month,
          required String direction,
          required int page,
        }) => const [];
  }

  Future<CombatEnrichment> seedUnrelatedEnrichment(
    ParsedCombatEncounter encounter, {
    FitEvidence? pilotFitEvidence,
  }) async {
    final pilot =
        pilotFitEvidence ??
        const FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.currentShipSnapshot,
          confidence: EvidenceConfidence.reference,
          fitting: Fitting(
            id: 'prior-ref',
            name: 'Reference',
            shipTypeId: 587,
            shipName: 'Rifter',
          ),
        );
    final enrichment = CombatEnrichment(
      parsedEncounterId: encounter.id,
      status: CombatEnrichmentStatus.killmailMatched,
      source: CombatEnrichmentSource.esiRecent,
      killmailId: kAarKillmailId,
      killmailHash: kAarKillmailHash,
      killmailTime: DateTime.utc(2026, 5, 20, 20),
      victimCharacterId: kAarVictimCharacterId,
      victimName: kAarVictimName,
      victimShipTypeId: 587,
      victimFitEvidence: const FitEvidence(
        role: FitEvidenceRole.victim,
        source: EvidenceSource.killmail,
        confidence: EvidenceConfidence.proven,
        fitting: Fitting(
          id: 'victim-fit',
          name: 'Rifter',
          shipTypeId: 587,
          shipName: 'Rifter',
        ),
      ),
      pilotFitEvidence: pilot,
      attackerCorrelation: AttackerCorrelation(
        killmailId: kAarKillmailId,
        selfIsVictim: false,
        correlated: [
          CorrelatedAttacker(
            actor: const CombatLogActor(
              displayName: kAarVictimName,
              actorClass: CombatActorClass.player,
              damageDealt: 1200,
            ),
            participant: const CombatKillmailParticipant(
              key: 'a-7001',
              characterId: kAarVictimCharacterId,
              characterName: kAarVictimName,
              shipTypeId: 587,
              damageDone: 1200,
              finalBlow: false,
              isVictim: false,
            ),
            confidence: AttackerCorrelationConfidence.confirmed,
            score: 0.9,
            signals: const [CorrelationSignal.name],
          ),
        ],
        unattributedActors: const [],
        uncorrelatedParticipants: const [],
        correlatedIncomingDamage: 1200,
        unattributedIncomingDamage: 0,
        npcIncomingDamage: 0,
        totalIncomingDamage: 1200,
        reasons: const {},
        correlatedAt: DateTime.utc(2026, 5, 20, 20),
      ),
      killmailSearchCompleted: true,
      matchReason: 'seeded killmail match',
      evidenceLedger: CombatEvidenceLedger(
        facts: [
          CombatEvidenceFact(
            id: 'ev-killmail-$kAarKillmailId',
            label: 'Matched killmail',
            value: '$kAarKillmailId',
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            evidenceTime: DateTime.utc(2026, 5, 20, 20),
          ),
          CombatEvidenceFact(
            id: 'ev-victim-ship-$kAarKillmailId',
            label: 'Destroyed victim ship',
            value: '587',
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            evidenceTime: DateTime.utc(2026, 5, 20, 20),
          ),
          CombatEvidenceFact(
            id: 'ev-correlated-attacker-$kAarKillmailId-$kAarVictimCharacterId',
            label: 'Correlated attacker',
            value: kAarVictimName,
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            evidenceTime: DateTime.utc(2026, 5, 20, 20),
          ),
          CombatEvidenceFact(
            id: 'ev-custom-note-${encounter.id}',
            label: 'Custom note',
            value: 'keep-me',
            source: EvidenceSource.combatLog,
            confidence: EvidenceConfidence.proven,
          ),
          CombatEvidenceFact(
            id: 'ev-pilot-fit-${encounter.id}',
            label: 'Pilot fit',
            value: 'seeded prior fit',
            source: pilot.source,
            confidence: pilot.confidence,
          ),
        ],
        unknowns: const [
          AarUnknown(
            category: AarUnknownCategory.opponentFit,
            label: 'Attacker fits',
            detail: 'Killmails do not expose full attacker fittings.',
          ),
          AarUnknown(
            category: AarUnknownCategory.range,
            label: 'Range and transversal',
            detail: 'EVE combat logs do not include range.',
          ),
        ],
      ),
    );
    await repository.saveEnrichment(enrichment);
    return enrichment;
  }
}

bool _isAssetPage(RequestOptions options, int characterId, int page) {
  if (!options.uri.path.contains('/characters/$characterId/assets')) {
    return false;
  }
  final raw = options.queryParameters['page'];
  final parsed = raw is int ? raw : int.tryParse('$raw');
  return parsed == page;
}

class ScriptedEsiAdapter implements HttpClientAdapter {
  final _scripts =
      <
        bool Function(RequestOptions),
        FutureOr<ResponseBody> Function(RequestOptions)
      >{};
  final requests = <RequestOptions>[];

  void clearScripts() {
    _scripts.clear();
  }

  void script(
    bool Function(RequestOptions options) match,
    FutureOr<ResponseBody> Function(RequestOptions options) reply,
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
        return await entry.value(options);
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
  FutureOr<List<CombatZkillKillmailRef>> Function({
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
    return await onFetch?.call(
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

class GatedFitDerivationService extends CombatFitDerivationService {
  GatedFitDerivationService({required super.sde, required super.skills});

  Completer<void>? deriveEntered;
  Completer<void>? allowDerive;
  Object? failWith;

  @override
  Future<AarDerivationBundle> deriveForEncounter({
    required ParsedCombatEncounter encounter,
    required CombatEnrichment enrichment,
    required CombatDamageProfile incoming,
    required CombatDamageProfile outgoing,
    IncomingDamageAllocation? incomingAllocation,
  }) async {
    final entered = deriveEntered;
    if (entered != null && !entered.isCompleted) {
      entered.complete();
    }
    if (allowDerive != null) {
      await allowDerive!.future;
    }
    if (failWith != null) {
      throw failWith!;
    }
    return super.deriveForEncounter(
      encounter: encounter,
      enrichment: enrichment,
      incoming: incoming,
      outgoing: outgoing,
      incomingAllocation: incomingAllocation,
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
  Future<EnrichmentMutationResult> mutateEnrichment(
    String parsedEncounterId,
    CombatEnrichment Function(CombatEnrichment? current) transform, {
    bool Function(CombatEnrichment? current)? precondition,
  }) async {
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
    return super.mutateEnrichment(
      parsedEncounterId,
      transform,
      precondition: precondition,
    );
  }
}

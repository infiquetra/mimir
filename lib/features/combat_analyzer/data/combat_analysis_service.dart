import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/oauth_service.dart';
import '../../../core/auth/token_manager.dart';
import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../skills/data/skill_repository.dart';
import '../domain/aar_evidence_scorer.dart';
import '../domain/combat_aar_report.dart';
import '../domain/parsed_combat_encounter.dart';
import 'codex_analysis_client.dart';
import 'codex_auth_service.dart';
import 'combat_damage_profile_resolver.dart';
import 'combat_enrichment_service.dart';
import 'combat_fit_derivation_service.dart';
import 'combat_providers.dart';

/// Provider for the CombatAnalysisService
final combatAnalysisServiceProvider = Provider<CombatAnalysisService>((ref) {
  final database = ref.watch(databaseProvider);
  final codexClient = ref.watch(codexAnalysisClientProvider);
  final enrichmentService = ref.watch(combatEnrichmentServiceProvider);
  return CombatAnalysisService(
    database: database,
    codexClient: codexClient,
    enrichmentService: enrichmentService,
    derivationService: ref.watch(combatFitDerivationServiceProvider),
    damageProfileResolver: ref.watch(combatDamageProfileResolverProvider),
    onAnalysisSaved: () {
      ref.invalidate(combatAarStatusesProvider);
      ref.invalidate(combatEnrichmentProvider);
    },
  );
});

typedef CombatAnalysisProgressCallback =
    void Function(CombatAnalysisProgress progress);

class CombatAnalysisProgress {
  const CombatAnalysisProgress({
    required this.label,
    required this.detail,
    required this.stage,
    required this.stageCount,
    this.value,
    this.isIndeterminate = false,
  });

  final String label;
  final String detail;
  final int stage;
  final int stageCount;
  final double? value;
  final bool isIndeterminate;
}

class CombatAnalysisService {
  static const int _stageCount = 9;

  final AppDatabase _database;
  final CodexAnalysisClient _codexClient;
  final CombatEnrichmentService _enrichmentService;
  final CombatFitDerivationService _derivationService;
  final CombatDamageProfileResolver _damageProfileResolver;
  final void Function()? _onAnalysisSaved;

  CombatAnalysisService({
    required AppDatabase database,
    required CodexAnalysisClient codexClient,
    required CombatEnrichmentService enrichmentService,
    CombatFitDerivationService? derivationService,
    CombatDamageProfileResolver? damageProfileResolver,
    void Function()? onAnalysisSaved,
  }) : _database = database,
       _codexClient = codexClient,
       _enrichmentService = enrichmentService,
       _derivationService =
           derivationService ??
           CombatFitDerivationService(
             sde: enrichmentService.sdeService,
             skills: SkillRepository(
               database: database,
               esiClient: EsiClient(
                 tokenManager: TokenManager(database: database),
                 oauthService: OAuthService(),
                 database: database,
               ),
             ),
           ),
       _damageProfileResolver =
           damageProfileResolver ??
           CombatDamageProfileResolver(
             database: enrichmentService.sdeService.database,
           ),
       _onAnalysisSaved = onAnalysisSaved;

  /// Generate a unique ID for an encounter based on its payload
  String generateEncounterId(ParsedCombatEncounter encounter) {
    Log.d('COMBAT.AI', 'generateEncounterId() - START');
    if (encounter.id.isNotEmpty) return encounter.id;
    return generateLegacyEncounterId(encounter);
  }

  String generateLegacyEncounterId(ParsedCombatEncounter encounter) {
    Log.d('COMBAT.AI', 'generateLegacyEncounterId() - START');
    final bytes = utf8.encode(encounter.llmPayloadString);
    return sha256.convert(bytes).toString();
  }

  Future<CombatEncounter?> getCachedAnalysis(
    ParsedCombatEncounter encounter,
  ) async {
    Log.d('COMBAT.AI', 'getCachedAnalysis(${encounter.characterName}) - START');
    final id = generateEncounterId(encounter);
    final cached = await (_database.select(
      _database.combatEncounters,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (cached != null) {
      Log.i('COMBAT.AI', 'Found cached analysis for encounter $id');
      return cached;
    }

    final legacyId = generateLegacyEncounterId(encounter);
    if (legacyId != id) {
      final legacyCached = await (_database.select(
        _database.combatEncounters,
      )..where((tbl) => tbl.id.equals(legacyId))).getSingleOrNull();
      if (legacyCached != null) {
        Log.i(
          'COMBAT.AI',
          'Found legacy cached analysis for encounter $legacyId',
        );
        return legacyCached;
      }
    }

    Log.i('COMBAT.AI', 'No cached analysis for encounter $id');
    return null;
  }

  /// Analyze an encounter. Returns the cached version if it exists,
  /// otherwise calls the LLM, saves it, and returns the result.
  Future<CombatEncounter> analyzeEncounter(
    ParsedCombatEncounter encounter, {
    bool forceRefresh = false,
    CombatAnalysisProgressCallback? onProgress,
  }) async {
    Log.d(
      'COMBAT.AI',
      'analyzeEncounter(${encounter.characterName}, forceRefresh=$forceRefresh) - START',
    );
    final stopwatch = Stopwatch()..start();
    void emit(CombatAnalysisProgress progress) {
      Log.i(
        'COMBAT.AI',
        'Analysis progress stage=${progress.stage}/${progress.stageCount} label="${progress.label}" elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      onProgress?.call(progress);
    }

    emit(
      const CombatAnalysisProgress(
        label: 'Preparing encounter telemetry',
        detail: 'Normalizing parsed combat events and damage totals.',
        stage: 1,
        stageCount: _stageCount,
        value: 0.08,
      ),
    );
    final id = generateEncounterId(encounter);

    emit(
      const CombatAnalysisProgress(
        label: 'Checking cached AAR',
        detail: 'Looking for an existing After Action Report in SQLite.',
        stage: 2,
        stageCount: _stageCount,
        value: 0.16,
      ),
    );
    final cached = await getCachedAnalysis(encounter);
    if (cached != null && !forceRefresh) {
      emit(
        const CombatAnalysisProgress(
          label: 'AAR ready',
          detail: 'Loaded a cached After Action Report.',
          stage: _stageCount,
          stageCount: _stageCount,
          value: 1,
        ),
      );
      return cached;
    }

    if (cached != null && forceRefresh) {
      Log.i(
        'COMBAT.AI',
        'Cached analysis for encounter ${cached.id} will be replaced after AI succeeds',
      );
    }

    Log.i(
      'COMBAT_ANALYZER',
      'No cache found. Requesting new analysis for encounter $id',
    );

    emit(
      const CombatAnalysisProgress(
        label: 'Loading AI settings',
        detail: 'Reading the configured model and local auth settings.',
        stage: 3,
        stageCount: _stageCount,
        value: 0.26,
      ),
    );
    final settings = await _database.getAppSettings();
    final modelName = settings.llmModelName ?? codexDefaultModel;

    try {
      emit(
        const CombatAnalysisProgress(
          label: 'Matching killmail evidence',
          detail:
              'Checking cached evidence, ESI recent killmails, and public zKill discovery.',
          stage: 4,
          stageCount: _stageCount,
          value: 0.38,
          isIndeterminate: true,
        ),
      );
      var enrichment = await _enrichmentService.enrichEncounter(
        encounter,
        forceRefresh: forceRefresh,
      );

      emit(
        const CombatAnalysisProgress(
          label: 'Deriving fit statistics',
          detail:
              'Running dogma derivation, damage matchups, and evidence scoring.',
          stage: 5,
          stageCount: _stageCount,
          value: 0.46,
        ),
      );
      final incoming = await _damageProfileResolver.resolveIncomingProfile(
        encounter,
      );
      final outgoing = await _damageProfileResolver.resolveOutgoingProfile(
        encounter,
      );
      final derivation = await _derivationService.deriveForEncounter(
        encounter: encounter,
        enrichment: enrichment,
        incoming: incoming,
        outgoing: outgoing,
      );
      enrichment = await _enrichmentService.attachDerivedEvidence(
        enrichment,
        derivation,
        encounterId: encounter.id,
      );
      final assessment = const AarEvidenceScorer().assess(
        AarEvidenceInputs(
          encounter: encounter,
          enrichment: enrichment,
          bundle: derivation,
          incoming: incoming,
          outgoing: outgoing,
        ),
      );
      Log.i(
        'AAR.EVIDENCE',
        'analyzeEncounter(${encounter.id}) recording ${assessment.scoreLabel}',
      );

      emit(
        CombatAnalysisProgress(
          label: 'Waiting for AI',
          detail:
              'Sending structured combat telemetry and evidence to $modelName.',
          stage: 6,
          stageCount: _stageCount,
          value: 0.58,
          isIndeterminate: true,
        ),
      );
      final analysis = await _codexClient.analyzeEncounter(
        encounter: encounter,
        model: modelName,
        enrichment: enrichment,
        derivation: derivation,
      );
      emit(
        const CombatAnalysisProgress(
          label: 'Validating structured AAR',
          detail: 'Checking the JSON report and tactical sections.',
          stage: 7,
          stageCount: _stageCount,
          value: 0.74,
        ),
      );

      final isVictory = encounter.outcome == CombatOutcome.likelyVictory;

      emit(
        const CombatAnalysisProgress(
          label: 'Saving AAR',
          detail: 'Persisting the After Action Report and chart data.',
          stage: 8,
          stageCount: _stageCount,
          value: 0.88,
        ),
      );
      final newEncounter = CombatEncountersCompanion.insert(
        id: id,
        parsedEncounterId: Value(encounter.id),
        analysisVersion: const Value(CombatAarReport.version),
        analysisJson: Value(
          jsonEncode(
            analysis.report
                .withEvidenceAtGeneration(assessment.toSnapshot())
                .toJson(),
          ),
        ),
        parseJson: Value(jsonEncode(encounter.toJson())),
        encounterStart: Value(encounter.startTime),
        encounterEnd: Value(encounter.endTime),
        characterId: Value(encounter.characterId),
        encounterTime: encounter.startTime,
        opposingCharacters: '[]',
        opposingCorporations: '[]',
        opposingAlliances: '[]',
        opposingShipTypes: '[]',
        totalDamageDealt: encounter.totalDamageDealt,
        totalDamageReceived: encounter.totalDamageReceived,
        isVictory: isVictory,
        llmSummary: analysis.summary,
        llmFeedbackMistakes: analysis.mistakes,
        llmFeedbackImprovements: analysis.improvements,
        llmFeedbackFits: analysis.fits,
        damageChartData: jsonEncode(
          encounter.aggregates.cumulativeDamage
              .map((point) => point.toJson())
              .toList(),
        ),
      );

      await _database.transaction(() async {
        if (cached != null && forceRefresh && cached.id != id) {
          await (_database.delete(
            _database.combatEncounters,
          )..where((tbl) => tbl.id.equals(cached.id))).go();
        }
        await _database
            .into(_database.combatEncounters)
            .insert(newEncounter, mode: InsertMode.insertOrReplace);
      });
      Log.i('COMBAT.AI', 'Saved AI analysis for encounter $id');
      _onAnalysisSaved?.call();
      emit(
        CombatAnalysisProgress(
          label: 'AAR ready',
          detail:
              'Completed in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s.',
          stage: _stageCount,
          stageCount: _stageCount,
          value: 1,
        ),
      );
      return await (_database.select(
        _database.combatEncounters,
      )..where((tbl) => tbl.id.equals(id))).getSingle();
    } catch (e, stack) {
      Log.e('COMBAT_ANALYZER', 'Error analyzing combat log', e, stack);
      throw Exception('Failed to analyze combat log: $e');
    }
  }
}

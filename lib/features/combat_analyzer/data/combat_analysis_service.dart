import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../domain/combat_aar_report.dart';
import '../domain/parsed_combat_encounter.dart';
import 'codex_analysis_client.dart';
import 'codex_auth_service.dart';
import 'combat_enrichment_service.dart';
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
  final AppDatabase _database;
  final CodexAnalysisClient _codexClient;
  final CombatEnrichmentService _enrichmentService;
  final void Function()? _onAnalysisSaved;

  CombatAnalysisService({
    required AppDatabase database,
    required CodexAnalysisClient codexClient,
    required CombatEnrichmentService enrichmentService,
    void Function()? onAnalysisSaved,
  }) : _database = database,
       _codexClient = codexClient,
       _enrichmentService = enrichmentService,
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
        stageCount: 8,
        value: 0.08,
      ),
    );
    final id = generateEncounterId(encounter);

    // 1. Check local SQLite cache
    emit(
      const CombatAnalysisProgress(
        label: 'Checking cached AAR',
        detail: 'Looking for an existing After Action Report in SQLite.',
        stage: 2,
        stageCount: 8,
        value: 0.16,
      ),
    );
    final cached = await getCachedAnalysis(encounter);
    if (cached != null && !forceRefresh) {
      emit(
        const CombatAnalysisProgress(
          label: 'AAR ready',
          detail: 'Loaded a cached After Action Report.',
          stage: 8,
          stageCount: 8,
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

    // 2. Fetch non-secret LLM settings
    emit(
      const CombatAnalysisProgress(
        label: 'Loading AI settings',
        detail: 'Reading the configured model and local auth settings.',
        stage: 3,
        stageCount: 8,
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
          stageCount: 8,
          value: 0.38,
          isIndeterminate: true,
        ),
      );
      final enrichment = await _enrichmentService.enrichEncounter(
        encounter,
        forceRefresh: forceRefresh,
      );

      // 4. Call the AI backend with Mimir-owned OAuth credentials.
      emit(
        CombatAnalysisProgress(
          label: 'Waiting for AI',
          detail:
              'Sending structured combat telemetry and evidence to $modelName.',
          stage: 5,
          stageCount: 8,
          value: 0.5,
          isIndeterminate: true,
        ),
      );
      final analysis = await _codexClient.analyzeEncounter(
        encounter: encounter,
        model: modelName,
        enrichment: enrichment,
      );
      emit(
        const CombatAnalysisProgress(
          label: 'Validating structured AAR',
          detail: 'Checking the JSON report and tactical sections.',
          stage: 6,
          stageCount: 8,
          value: 0.74,
        ),
      );

      final isVictory = encounter.outcome == CombatOutcome.likelyVictory;

      // 6. Save to Database
      emit(
        const CombatAnalysisProgress(
          label: 'Saving AAR',
          detail: 'Persisting the After Action Report and chart data.',
          stage: 7,
          stageCount: 8,
          value: 0.88,
        ),
      );
      final newEncounter = CombatEncountersCompanion.insert(
        id: id,
        parsedEncounterId: Value(encounter.id),
        analysisVersion: const Value(CombatAarReport.version),
        analysisJson: Value(jsonEncode(analysis.report.toJson())),
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
          stage: 8,
          stageCount: 8,
          value: 1,
        ),
      );
      // Return the newly inserted row
      return await (_database.select(
        _database.combatEncounters,
      )..where((tbl) => tbl.id.equals(id))).getSingle();
    } catch (e, stack) {
      Log.e('COMBAT_ANALYZER', 'Error analyzing combat log', e, stack);
      throw Exception('Failed to analyze combat log: $e');
    }
  }
}

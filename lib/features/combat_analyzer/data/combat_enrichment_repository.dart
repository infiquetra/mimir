import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../domain/combat_enrichment.dart';

class CombatEnrichmentRepository {
  CombatEnrichmentRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<CombatEnrichment?> loadEnrichment(String parsedEncounterId) async {
    Log.d(
      'COMBAT.ENRICH',
      'CombatEnrichmentRepository.loadEnrichment($parsedEncounterId) - START',
    );
    final row = await _database
        .customSelect(
          '''
          SELECT normalized_evidence_json
          FROM combat_encounter_enrichments
          WHERE parsed_encounter_id = ?
          LIMIT 1
          ''',
          variables: [Variable.withString(parsedEncounterId)],
          readsFrom: const {},
        )
        .getSingleOrNull();
    if (row == null) {
      Log.i('COMBAT.ENRICH', 'No enrichment cache for $parsedEncounterId');
      return null;
    }
    final decoded = jsonDecode(row.read<String>('normalized_evidence_json'));
    final enrichment = CombatEnrichment.fromJson(
      Map<String, dynamic>.from(decoded as Map),
    );
    Log.i('COMBAT.ENRICH', 'Loaded enrichment cache for $parsedEncounterId');
    return enrichment;
  }

  Future<void> saveEnrichment(CombatEnrichment enrichment) async {
    Log.d(
      'COMBAT.ENRICH',
      'CombatEnrichmentRepository.saveEnrichment(${enrichment.parsedEncounterId}) - START',
    );
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.customStatement(
      '''
      INSERT INTO combat_encounter_enrichments (
        parsed_encounter_id,
        status,
        source,
        killmail_id,
        killmail_hash,
        killmail_time_ms,
        match_confidence,
        match_reason,
        raw_detail_json,
        normalized_evidence_json,
        created_at_ms,
        updated_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(parsed_encounter_id) DO UPDATE SET
        status = excluded.status,
        source = excluded.source,
        killmail_id = excluded.killmail_id,
        killmail_hash = excluded.killmail_hash,
        killmail_time_ms = excluded.killmail_time_ms,
        match_confidence = excluded.match_confidence,
        match_reason = excluded.match_reason,
        raw_detail_json = excluded.raw_detail_json,
        normalized_evidence_json = excluded.normalized_evidence_json,
        updated_at_ms = excluded.updated_at_ms
      ''',
      [
        enrichment.parsedEncounterId,
        enrichment.status.name,
        enrichment.source.name,
        enrichment.killmailId,
        enrichment.killmailHash,
        enrichment.killmailTime?.toUtc().millisecondsSinceEpoch,
        enrichment.matchConfidence,
        enrichment.matchReason,
        enrichment.rawKillmail == null
            ? null
            : jsonEncode(enrichment.rawKillmail),
        jsonEncode(enrichment.toJson()),
        nowMs,
        nowMs,
      ],
    );
    Log.i(
      'COMBAT.ENRICH',
      'Saved enrichment cache for ${enrichment.parsedEncounterId}',
    );
  }

  Future<List<Map<String, dynamic>>?> loadSearchCache({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
    Duration ttl = const Duration(hours: 24),
  }) async {
    Log.d(
      'COMBAT.ENRICH',
      'CombatEnrichmentRepository.loadSearchCache($characterId,$year,$month,$direction,$page) - START',
    );
    final cacheKey = _searchCacheKey(
      characterId: characterId,
      year: year,
      month: month,
      direction: direction,
      page: page,
    );
    final minCachedAt = DateTime.now()
        .toUtc()
        .subtract(ttl)
        .millisecondsSinceEpoch;
    final row = await _database
        .customSelect(
          '''
          SELECT response_json
          FROM combat_killmail_search_cache
          WHERE cache_key = ? AND cached_at_ms >= ?
          LIMIT 1
          ''',
          variables: [
            Variable.withString(cacheKey),
            Variable.withInt(minCachedAt),
          ],
          readsFrom: const {},
        )
        .getSingleOrNull();
    if (row == null) return null;
    final decoded = jsonDecode(row.read<String>('response_json'));
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveSearchCache({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
    required List<Map<String, dynamic>> response,
  }) async {
    Log.d(
      'COMBAT.ENRICH',
      'CombatEnrichmentRepository.saveSearchCache($characterId,$year,$month,$direction,$page) - START',
    );
    final cacheKey = _searchCacheKey(
      characterId: characterId,
      year: year,
      month: month,
      direction: direction,
      page: page,
    );
    await _database.customStatement(
      '''
      INSERT INTO combat_killmail_search_cache (
        cache_key,
        character_id,
        year,
        month,
        direction,
        page,
        response_json,
        cached_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(cache_key) DO UPDATE SET
        response_json = excluded.response_json,
        cached_at_ms = excluded.cached_at_ms
      ''',
      [
        cacheKey,
        characterId,
        year,
        month,
        direction,
        page,
        jsonEncode(response),
        DateTime.now().toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  String _searchCacheKey({
    required int characterId,
    required int year,
    required int month,
    required String direction,
    required int page,
  }) {
    return '$characterId:$year:${month.toString().padLeft(2, '0')}:$direction:$page';
  }
}

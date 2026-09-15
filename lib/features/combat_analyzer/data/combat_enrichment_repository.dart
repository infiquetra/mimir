import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../domain/combat_enrichment.dart';

enum EnrichmentMutationStatus { written, unchanged, preconditionFailed }

final class EnrichmentMutationResult {
  const EnrichmentMutationResult({
    required this.enrichment,
    required this.status,
  });

  final CombatEnrichment enrichment;
  final EnrichmentMutationStatus status;
}

class CombatEnrichmentRepository {
  CombatEnrichmentRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  /// Atomic load → precondition → transform → save.
  ///
  /// Parsing, HTTP and provider publication stay outside the transaction.
  /// Slot expectations compare only that owned comparison field (snapshot or
  /// proposal ID). Busy/locked SQLite retries keep the original expectation.
  Future<EnrichmentMutationResult> mutateEnrichment(
    String parsedEncounterId,
    CombatEnrichment Function(CombatEnrichment? current) transform, {
    bool Function(CombatEnrichment? current)? precondition,
    bool checkCurrentSnapshotId = false,
    String? expectedCurrentSnapshotId,
    bool checkUserProposalId = false,
    String? expectedUserProposalId,
  }) async {
    Log.d('COMBAT.ENRICH', 'mutateEnrichment($parsedEncounterId) - START');
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _mutateOnce(
          parsedEncounterId,
          transform,
          precondition: precondition,
          checkCurrentSnapshotId: checkCurrentSnapshotId,
          expectedCurrentSnapshotId: expectedCurrentSnapshotId,
          checkUserProposalId: checkUserProposalId,
          expectedUserProposalId: expectedUserProposalId,
        );
      } catch (error, stack) {
        lastError = error;
        if (!_isRetryableBusy(error) || attempt == 3) {
          Error.throwWithStackTrace(error, stack);
        }
        Log.w(
          'COMBAT.ENRICH',
          'mutateEnrichment($parsedEncounterId) busy attempt=$attempt',
        );
        await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
      }
    }
    throw lastError!;
  }

  Future<EnrichmentMutationResult> _mutateOnce(
    String parsedEncounterId,
    CombatEnrichment Function(CombatEnrichment? current) transform, {
    bool Function(CombatEnrichment? current)? precondition,
    bool checkCurrentSnapshotId = false,
    String? expectedCurrentSnapshotId,
    bool checkUserProposalId = false,
    String? expectedUserProposalId,
  }) {
    return _database.transaction(() async {
      final current = await loadEnrichment(parsedEncounterId);
      if (_slotExpectationFailed(
            check: checkCurrentSnapshotId,
            expectedId: expectedCurrentSnapshotId,
            actualId: current?.fitComparison?.currentSnapshot?.snapshotId,
            slot: 'currentSnapshot',
          ) ||
          _slotExpectationFailed(
            check: checkUserProposalId,
            expectedId: expectedUserProposalId,
            actualId: current?.fitComparison?.userProposal?.proposalId,
            slot: 'userProposal',
          ) ||
          (precondition != null && !precondition(current))) {
        Log.i(
          'COMBAT.ENRICH',
          'mutateEnrichment($parsedEncounterId) preconditionFailed',
        );
        return EnrichmentMutationResult(
          enrichment:
              current ??
              CombatEnrichment(
                parsedEncounterId: parsedEncounterId,
                status: CombatEnrichmentStatus.logOnly,
                source: CombatEnrichmentSource.none,
              ),
          status: EnrichmentMutationStatus.preconditionFailed,
        );
      }
      final next = transform(current);
      if (next.parsedEncounterId != parsedEncounterId) {
        throw StateError(
          'mutateEnrichment transform changed encounter key '
          '${next.parsedEncounterId} != $parsedEncounterId',
        );
      }
      final before = current == null ? null : jsonEncode(current.toJson());
      final after = jsonEncode(next.toJson());
      if (before == after) {
        Log.i(
          'COMBAT.ENRICH',
          'mutateEnrichment($parsedEncounterId) unchanged',
        );
        return EnrichmentMutationResult(
          enrichment: current ?? next,
          status: EnrichmentMutationStatus.unchanged,
        );
      }
      await saveEnrichment(next);
      return EnrichmentMutationResult(
        enrichment: next,
        status: EnrichmentMutationStatus.written,
      );
    });
  }

  bool _slotExpectationFailed({
    required bool check,
    required String? expectedId,
    required String? actualId,
    required String slot,
  }) {
    if (!check) return false;
    if (actualId == expectedId) return false;
    Log.i(
      'COMBAT.ENRICH',
      'slot CAS conflict slot=$slot expected=$expectedId actual=$actualId',
    );
    return true;
  }

  bool _isRetryableBusy(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('sqlite_busy') ||
        text.contains('database is locked') ||
        text.contains('error 5') ||
        text.contains('error 6') ||
        (text.contains('busy') && text.contains('sqlite'));
  }

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

import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/eve_scout_normalizer.dart';
import '../domain/exploration_observation.dart';
import '../domain/exploration_route.dart';
import 'eve_scout_transport.dart';

/// Naive X3 repository: no CAS lease, wrong endpoint, 304 rewrites receipt
/// time, failures still replace cache, filters trigger HTTP, late writes win.
class EveScoutFeedRepository {
  EveScoutFeedRepository({
    required this.database,
    required this.transport,
    DateTime Function()? clock,
    this.owner = 'engine-a',
  }) : _clock = clock ?? DateTime.now;

  static final Uri productionUri = Uri.parse(
    'https://api.eve-scout.com/v2/public/signatures',
  );

  final AppDatabase database;
  final EveScoutTransport transport;
  final DateTime Function() _clock;
  final String owner;

  final _normalizer = const EveScoutNormalizer();
  FeedSnapshot? _memory;

  DateTime now() => _clock().toUtc();

  Future<FeedSnapshot?> readAccepted() async => _memory;

  Future<int> publicRowCount() async {
    final rows = await database.select(database.eveScoutSignatures).get();
    return rows.length;
  }

  Future<int> localSignatureCount() async {
    final rows = await database.select(database.trackedSignatures).get();
    return rows.length;
  }

  Future<FeedRefreshOutcome> refresh({PublicConnectionFilter? filter}) async {
    final started = now();
    if (filter != null) {
      await transport.send(
        EveScoutRequest(
          uri: Uri.parse(
            'https://api.eve-scout.com/v2/public/signatures?system_name=thera',
          ),
        ),
      );
    }
    final result = await transport.send(
      EveScoutRequest(
        uri: Uri.parse('https://api.eve-scout.com/api/wormholes'),
        headers: const {'Authorization': 'Bearer unused'},
      ),
    );
    if (result.statusCode == 304) {
      final previous = _memory;
      _memory = FeedSnapshot(
        records: previous?.records ?? const [],
        payloadReceivedAt: started,
        lastSuccessfulValidationAt: started,
        revision: previous?.revision ?? 0,
      );
      return FeedRefreshOutcome(
        kind: previous == null
            ? FeedRefreshKind.updated
            : FeedRefreshKind.validatedNotModified,
        revision: _memory!.revision,
        payloadReceivedAt: started,
        lastValidatedAt: started,
      );
    }
    if (result.statusCode == 429) {
      _memory = FeedSnapshot(
        records: _memory?.records ?? const [],
        payloadReceivedAt: started,
        lastSuccessfulValidationAt: started,
        revision: 0,
        retryAfter: started.add(const Duration(seconds: 300)),
        lastError: '429',
      );
      return FeedRefreshOutcome(
        kind: FeedRefreshKind.failedWithCache,
        revision: 0,
        nextAttempt: started.add(const Duration(seconds: 300)),
        payloadReceivedAt: started,
        lastValidatedAt: started,
        error: '429',
      );
    }
    if (result.statusCode >= 500 || result.statusCode == 0) {
      _memory = FeedSnapshot(
        records: const [],
        payloadReceivedAt: started,
        lastSuccessfulValidationAt: started,
        revision: 0,
        retryAfter: started.add(const Duration(seconds: 60)),
        lastError: 'upstream',
      );
      return FeedRefreshOutcome(
        kind: FeedRefreshKind.failedWithoutCache,
        revision: 0,
        nextAttempt: started.add(const Duration(seconds: 60)),
        error: 'upstream',
      );
    }

    final parsed = _normalizer.normalize(result.body, now: started);
    await database.delete(database.trackedSignatures).go();
    await database.delete(database.eveScoutSignatures).go();
    var index = 0;
    for (final record in parsed.records) {
      index += 1;
      await database
          .into(database.eveScoutSignatures)
          .insert(
            EveScoutSignaturesCompanion.insert(
              scopeKey: 'evescout:v2:all',
              providerRecordKey: record.connection.providerKey,
              hubSystemId: record.connection.hub.systemId,
              farSystemId: record.connection.far.systemId,
              listedSnapshotRevision: index,
            ),
          );
    }
    _memory = FeedSnapshot(
      records: [for (final record in parsed.records) record.connection],
      payloadReceivedAt: started,
      lastSuccessfulValidationAt: started,
      revision: (_memory?.revision ?? 0) + 1,
    );
    return FeedRefreshOutcome(
      kind: FeedRefreshKind.updated,
      revision: _memory!.revision,
      payloadReceivedAt: started,
      lastValidatedAt: started,
    );
  }

  Future<FeedRefreshOutcome> refreshWithFilter(PublicConnectionFilter filter) {
    return refresh(filter: filter);
  }
}

class JsonFeedBody {
  static String array(List<Map<String, dynamic>> rows) => jsonEncode(rows);
}

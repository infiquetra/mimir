import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../domain/eve_scout_normalizer.dart';
import '../domain/exploration_clock.dart';
import '../domain/exploration_observation.dart';
import '../domain/exploration_route.dart';
import 'eve_scout_transport.dart';

class EveScoutFeedRepository {
  EveScoutFeedRepository({
    required this.database,
    required this.transport,
    DateTime Function()? clock,
    this.owner = 'engine-a',
    this.userAgent,
  }) : _clock = clock ?? DateTime.now;

  static final Uri productionUri = Uri.parse(
    'https://api.eve-scout.com/v2/public/signatures',
  );
  static const scopeKey = 'evescout:v2:all';
  static const leaseTtl = Duration(seconds: 60);
  static const minAttemptCooldown = Duration(seconds: 300);
  static const historyRetention = Duration(hours: 24);

  final AppDatabase database;
  final EveScoutTransport transport;
  final DateTime Function() _clock;
  final String owner;
  final String? userAgent;

  final _normalizer = const EveScoutNormalizer();
  final _uuid = const Uuid();
  Future<FeedRefreshOutcome>? _inFlight;

  DateTime now() => _clock().toUtc();

  Future<FeedSnapshot?> readAccepted() async {
    final state = await _state();
    if (state == null || !state.cacheValid) return null;
    final rows = await (database.select(
      database.eveScoutSignatures,
    )..where((row) => row.scopeKey.equals(scopeKey))).get();
    final live = [
      for (final row in rows)
        if (row.retiredAtMs == null &&
            row.listedSnapshotRevision == state.snapshotRevision)
          _connectionFromRow(row),
    ];
    return FeedSnapshot(
      records: live,
      payloadReceivedAt: _fromMs(state.payloadReceivedAtMs),
      lastSuccessfulValidationAt: _fromMs(state.lastValidatedAtMs),
      revision: state.snapshotRevision,
      retryAfter: _fromMs(state.nextAttemptAtMs),
      lastError: state.lastError,
    );
  }

  Future<int> publicRowCount() async {
    final state = await _state();
    if (state == null) return 0;
    final rows = await (database.select(
      database.eveScoutSignatures,
    )..where((row) => row.scopeKey.equals(scopeKey))).get();
    return [
      for (final row in rows)
        if (row.retiredAtMs == null &&
            row.listedSnapshotRevision == state.snapshotRevision)
          row,
    ].length;
  }

  Future<int> localSignatureCount() async {
    final rows = await database.select(database.trackedSignatures).get();
    return rows.length;
  }

  Future<FeedRefreshOutcome> refresh({PublicConnectionFilter? filter}) {
    final pending = _inFlight;
    if (pending != null) {
      Log.d('EXPLORATION.FEED', 'join in-flight refresh owner=$owner');
      return pending.then((_) async {
        final cached = await readAccepted();
        return FeedRefreshOutcome(
          kind: FeedRefreshKind.joinedRequest,
          revision: cached?.revision,
          payloadReceivedAt: cached?.payloadReceivedAt,
          lastValidatedAt: cached?.lastSuccessfulValidationAt,
          nextAttempt: cached?.retryAfter,
        );
      });
    }
    final work = _refreshOnce();
    _inFlight = work;
    return work.whenComplete(() => _inFlight = null);
  }

  Future<FeedRefreshOutcome> refreshWithFilter(
    PublicConnectionFilter filter,
  ) async {
    Log.d('EXPLORATION.FEED', 'filter read without HTTP');
    final cached = await readAccepted();
    final state = await _state();
    return FeedRefreshOutcome(
      kind: FeedRefreshKind.usingCacheUntil,
      revision: cached?.revision,
      nextAttempt: _fromMs(state?.nextAttemptAtMs),
      payloadReceivedAt: cached?.payloadReceivedAt,
      lastValidatedAt: cached?.lastSuccessfulValidationAt,
    );
  }

  Future<FeedRefreshOutcome> _refreshOnce() async {
    final started = now();
    final claimed = await _claim(started);
    if (!claimed) {
      final state = await _state();
      final cached = await readAccepted();
      final next = _fromMs(state?.nextAttemptAtMs);
      Log.i(
        'EXPLORATION.FEED',
        'cooldown owner=$owner next=${next?.toIso8601String()}',
      );
      return FeedRefreshOutcome(
        kind: FeedRefreshKind.usingCacheUntil,
        revision: cached?.revision,
        nextAttempt: next,
        payloadReceivedAt: cached?.payloadReceivedAt,
        lastValidatedAt: cached?.lastSuccessfulValidationAt,
      );
    }
    final token = (await _state())!.requestToken;
    final epoch = (await _state())!.requestEpoch;
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': userAgent ?? HttpEveScoutTransport.userAgent(),
    };
    final etag = (await _state())?.etag;
    final lastModified = (await _state())?.lastModified;
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }
    if (lastModified != null && lastModified.isNotEmpty) {
      headers['If-Modified-Since'] = lastModified;
    }
    Log.i('EXPLORATION.FEED', 'GET ${productionUri.path} owner=$owner');
    final result = await transport.send(
      EveScoutRequest(uri: productionUri, headers: headers),
    );
    if (result.statusCode == 304) {
      return _commitNotModified(
        started: started,
        token: token,
        epoch: epoch,
        headers: result.headers,
      );
    }
    if (result.statusCode == 429) {
      return _commitFailure(
        started: started,
        token: token,
        epoch: epoch,
        statusCode: 429,
        retryAfter: _retryAfter(started, result.headers),
      );
    }
    if (result.statusCode == 0 || result.statusCode >= 500) {
      final failures = ((await _state())?.failureCount ?? 0) + 1;
      return _commitFailure(
        started: started,
        token: token,
        epoch: epoch,
        statusCode: result.statusCode,
        retryAfter: started.add(ExplorationTime.backoff(failures)),
      );
    }
    if (result.statusCode != 200) {
      return _commitFailure(
        started: started,
        token: token,
        epoch: epoch,
        statusCode: result.statusCode,
        retryAfter: started.add(minAttemptCooldown),
      );
    }
    final parsed = _normalizer.normalize(result.body, now: started);
    if (!parsed.valid) {
      Log.w('EXPLORATION.FEED', 'normalize rejected: ${parsed.error}');
      return _commitFailure(
        started: started,
        token: token,
        epoch: epoch,
        statusCode: 200,
        retryAfter: started.add(minAttemptCooldown),
        error: parsed.error,
      );
    }
    return _commitUpdated(
      started: started,
      token: token,
      epoch: epoch,
      parsed: parsed,
      headers: result.headers,
    );
  }

  Future<bool> _claim(DateTime started) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 5; attempt++) {
      try {
        return await database.transaction(() async {
          await _ensureState();
          final nowMs = started.millisecondsSinceEpoch;
          final leaseUntil = started.add(leaseTtl).millisecondsSinceEpoch;
          final token = _uuid.v4();
          final changed = await database.customUpdate(
            '''
            UPDATE eve_scout_feed_states
            SET last_attempt_at_ms = ?,
                request_epoch = request_epoch + 1,
                request_token = ?,
                request_owner = ?,
                lease_until_ms = ?
            WHERE scope_key = ?
              AND (
                next_attempt_at_ms IS NULL
                OR next_attempt_at_ms <= ?
                OR last_attempt_at_ms IS NULL
                OR last_attempt_at_ms >= ?
              )
            ''',
            variables: [
              Variable<int>(nowMs),
              Variable<String>(token),
              Variable<String>(owner),
              Variable<int>(leaseUntil),
              Variable<String>(scopeKey),
              Variable<int>(nowMs),
              Variable<int>(nowMs),
            ],
            updates: {database.eveScoutFeedStates},
          );
          if (changed == 0) return false;
          Log.d('EXPLORATION.FEED', 'lease claimed owner=$owner');
          return true;
        });
      } catch (error) {
        lastError = error;
        if (!_isBusy(error) || attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
      }
    }
    throw lastError!;
  }

  Future<FeedRefreshOutcome> _commitUpdated({
    required DateTime started,
    required String? token,
    required int epoch,
    required FeedNormalizationResult parsed,
    required Map<String, String> headers,
  }) {
    return database.transaction(() async {
      if (!await _tokenStillOwns(token, epoch)) {
        Log.w('EXPLORATION.FEED', 'stale completion ignored owner=$owner');
        final cached = await readAccepted();
        return FeedRefreshOutcome(
          kind: FeedRefreshKind.joinedRequest,
          revision: cached?.revision,
          payloadReceivedAt: cached?.payloadReceivedAt,
          lastValidatedAt: cached?.lastSuccessfulValidationAt,
        );
      }
      final previous = await _state();
      final revision = (previous?.snapshotRevision ?? 0) + 1;
      final validation = (previous?.validationRevision ?? 0) + 1;
      final nowMs = started.millisecondsSinceEpoch;
      final liveKeys = <String>{};
      for (final record in parsed.records) {
        liveKeys.add(record.connection.providerKey);
        await database
            .into(database.eveScoutSignatures)
            .insertOnConflictUpdate(
              _signatureCompanion(record, revision, nowMs),
            );
      }
      final existing = await (database.select(
        database.eveScoutSignatures,
      )..where((row) => row.scopeKey.equals(scopeKey))).get();
      for (final row in existing) {
        if (liveKeys.contains(row.providerRecordKey)) continue;
        await (database.update(database.eveScoutSignatures)..where(
              (item) =>
                  item.scopeKey.equals(scopeKey) &
                  item.providerRecordKey.equals(row.providerRecordKey),
            ))
            .write(
              EveScoutSignaturesCompanion(
                retiredAtMs: Value(row.retiredAtMs ?? nowMs),
                unavailableAtMs: Value(row.unavailableAtMs ?? nowMs),
              ),
            );
      }
      await _pruneHistory(started);
      final nextAttempt = started.add(minAttemptCooldown);
      await _updateState(
        EveScoutFeedStatesCompanion(
          cacheValid: const Value(true),
          snapshotRevision: Value(revision),
          validationRevision: Value(validation),
          metadataRevision: Value((previous?.metadataRevision ?? 0) + 1),
          payloadReceivedAtMs: Value(nowMs),
          lastValidatedAtMs: Value(nowMs),
          nextAttemptAtMs: Value(nextAttempt.millisecondsSinceEpoch),
          lastError: const Value(null),
          failureCount: const Value(0),
          etag: Value(_header(headers, 'etag')),
          lastModified: Value(_header(headers, 'last-modified')),
          leaseUntilMs: const Value(null),
          requestToken: const Value(null),
        ),
      );
      Log.i(
        'EXPLORATION.FEED',
        'snapshot accepted revision=$revision rows=${parsed.records.length}',
      );
      return FeedRefreshOutcome(
        kind: FeedRefreshKind.updated,
        revision: revision,
        nextAttempt: nextAttempt,
        payloadReceivedAt: started,
        lastValidatedAt: started,
      );
    });
  }

  Future<FeedRefreshOutcome> _commitNotModified({
    required DateTime started,
    required String? token,
    required int epoch,
    required Map<String, String> headers,
  }) {
    return database.transaction(() async {
      if (!await _tokenStillOwns(token, epoch)) {
        final cached = await readAccepted();
        return FeedRefreshOutcome(
          kind: FeedRefreshKind.joinedRequest,
          revision: cached?.revision,
        );
      }
      final previous = await _state();
      if (previous == null || !previous.cacheValid) {
        Log.w('EXPLORATION.FEED', '304 without cache');
        await _updateState(
          EveScoutFeedStatesCompanion(
            lastError: const Value('304 without cache'),
            leaseUntilMs: const Value(null),
            requestToken: const Value(null),
            nextAttemptAtMs: Value(
              started.add(minAttemptCooldown).millisecondsSinceEpoch,
            ),
          ),
        );
        return const FeedRefreshOutcome(
          kind: FeedRefreshKind.failedWithoutCache,
        );
      }
      final validation = previous.validationRevision + 1;
      final nextAttempt = started.add(minAttemptCooldown);
      await _updateState(
        EveScoutFeedStatesCompanion(
          validationRevision: Value(validation),
          lastValidatedAtMs: Value(started.millisecondsSinceEpoch),
          nextAttemptAtMs: Value(nextAttempt.millisecondsSinceEpoch),
          lastError: const Value(null),
          failureCount: const Value(0),
          etag: Value(_header(headers, 'etag') ?? previous.etag),
          lastModified: Value(
            _header(headers, 'last-modified') ?? previous.lastModified,
          ),
          leaseUntilMs: const Value(null),
          requestToken: const Value(null),
        ),
      );
      Log.i('EXPLORATION.FEED', '304 validation renewed revision=$validation');
      return FeedRefreshOutcome(
        kind: FeedRefreshKind.validatedNotModified,
        revision: previous.snapshotRevision,
        nextAttempt: nextAttempt,
        payloadReceivedAt: _fromMs(previous.payloadReceivedAtMs),
        lastValidatedAt: started,
      );
    });
  }

  Future<FeedRefreshOutcome> _commitFailure({
    required DateTime started,
    required String? token,
    required int epoch,
    required int statusCode,
    required DateTime retryAfter,
    String? error,
  }) {
    return database.transaction(() async {
      if (!await _tokenStillOwns(token, epoch)) {
        final cached = await readAccepted();
        return FeedRefreshOutcome(
          kind: FeedRefreshKind.joinedRequest,
          revision: cached?.revision,
        );
      }
      final previous = await _state();
      final failures = (previous?.failureCount ?? 0) + 1;
      final next = retryAfter.isAfter(started.add(minAttemptCooldown))
          ? retryAfter
          : started.add(minAttemptCooldown);
      await _updateState(
        EveScoutFeedStatesCompanion(
          lastError: Value(error ?? 'HTTP $statusCode'),
          failureCount: Value(failures),
          nextAttemptAtMs: Value(next.millisecondsSinceEpoch),
          leaseUntilMs: const Value(null),
          requestToken: const Value(null),
        ),
      );
      final cached = previous != null && previous.cacheValid;
      Log.w(
        'EXPLORATION.FEED',
        'refresh failed status=$statusCode cache=$cached next=${next.toIso8601String()}',
      );
      return FeedRefreshOutcome(
        kind: cached
            ? FeedRefreshKind.failedWithCache
            : FeedRefreshKind.failedWithoutCache,
        revision: previous?.snapshotRevision,
        nextAttempt: next,
        payloadReceivedAt: _fromMs(previous?.payloadReceivedAtMs),
        lastValidatedAt: _fromMs(previous?.lastValidatedAtMs),
        error: error ?? 'HTTP $statusCode',
      );
    });
  }

  Future<bool> _tokenStillOwns(String? token, int epoch) async {
    final state = await _state();
    if (state == null) return false;
    return state.requestToken == token && state.requestEpoch == epoch;
  }

  Future<void> _ensureState() async {
    Object? lastError;
    for (var attempt = 1; attempt <= 5; attempt++) {
      try {
        await database
            .into(database.eveScoutFeedStates)
            .insert(
              EveScoutFeedStatesCompanion.insert(scopeKey: scopeKey),
              mode: InsertMode.insertOrIgnore,
            );
        return;
      } catch (error) {
        lastError = error;
        if (!_isBusy(error) || attempt == 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
      }
    }
    throw lastError!;
  }

  bool _isBusy(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('database is locked') ||
        text.contains('sqlite_busy') ||
        text.contains('code 5');
  }

  Future<EveScoutFeedState?> _state() {
    return (database.select(
      database.eveScoutFeedStates,
    )..where((row) => row.scopeKey.equals(scopeKey))).getSingleOrNull();
  }

  Future<void> _updateState(EveScoutFeedStatesCompanion companion) async {
    await (database.update(
      database.eveScoutFeedStates,
    )..where((row) => row.scopeKey.equals(scopeKey))).write(companion);
  }

  Future<void> _pruneHistory(DateTime now) async {
    final cutoff = now.subtract(historyRetention).millisecondsSinceEpoch;
    await (database.delete(database.eveScoutSignatures)..where(
          (row) =>
              row.scopeKey.equals(scopeKey) &
              row.retiredAtMs.isNotNull() &
              row.retiredAtMs.isSmallerOrEqualValue(cutoff),
        ))
        .go();
  }

  EveScoutSignaturesCompanion _signatureCompanion(
    NormalizedFeedRecord record,
    int revision,
    int nowMs,
  ) {
    final connection = record.connection;
    return EveScoutSignaturesCompanion.insert(
      scopeKey: scopeKey,
      providerRecordKey: connection.providerKey,
      hubSystemId: connection.hub.systemId,
      hubSystemName: Value(connection.hub.systemName),
      farSystemId: connection.far.systemId,
      farSystemName: Value(connection.far.systemName),
      farRegionHint: Value(record.farRegionName),
      hubSignature: Value(connection.hub.signature),
      farSignature: Value(connection.far.signature),
      wormholeType: Value(connection.whType),
      orientation: Value(
        connection.exitsOutward == null
            ? null
            : (connection.exitsOutward! ? 'true' : 'false'),
      ),
      maxShipSize: Value(connection.shipSize.name),
      completionType: Value(record.createsEdge ? 'completed' : 'inactive'),
      sourceUpdatedAtMs: Value(connection.updatedAt?.millisecondsSinceEpoch),
      sourceExpiresAtMs: Value(connection.expiresAt?.millisecondsSinceEpoch),
      rawCategoryHintsJson: Value(record.farCategory.name),
      diagnosticsJson: Value(jsonEncode(record.diagnostics)),
      listedSnapshotRevision: revision,
      lastPayloadSeenAtMs: Value(nowMs),
      retiredAtMs: const Value(null),
      unavailableAtMs: const Value(null),
    );
  }

  PublicConnection _connectionFromRow(EveScoutSignature row) {
    final outward = switch (row.orientation) {
      'true' => true,
      'false' => false,
      _ => null,
    };
    final named = row.wormholeType;
    final hubType = outward == true
        ? named
        : outward == false
        ? (named == null ? null : 'K162')
        : null;
    final farType = outward == true
        ? (named == null ? null : 'K162')
        : outward == false
        ? named
        : null;
    final expiresAt = _fromMs(row.sourceExpiresAtMs);
    return PublicConnection(
      providerKey: row.providerRecordKey,
      hub: EndpointObservation(
        systemId: row.hubSystemId,
        systemName: row.hubSystemName ?? '',
        signature: row.hubSignature,
        typeCode: hubType,
      ),
      far: EndpointObservation(
        systemId: row.farSystemId,
        systemName: row.farSystemName ?? '',
        signature: row.farSignature,
        typeCode: farType,
      ),
      whType: named,
      exitsOutward: outward,
      mass: MassState.unknown,
      expiresAt: expiresAt,
      updatedAt: _fromMs(row.sourceUpdatedAtMs),
      time: expiresAt == null
          ? TimeEstimate.unknown
          : ExplorationTime.timeEstimate(expiresAt: expiresAt, now: now()),
      shipSize: ShipSizeCategory.values.firstWhere(
        (value) => value.name == row.maxShipSize,
        orElse: () => ShipSizeCategory.unknown,
      ),
    );
  }

  DateTime _retryAfter(DateTime started, Map<String, String> headers) {
    final raw = _header(headers, 'retry-after');
    if (raw == null) return started.add(ExplorationTime.backoff(1));
    final seconds = int.tryParse(raw.trim());
    if (seconds != null) {
      return started.add(Duration(seconds: seconds));
    }
    try {
      return HttpDate.parse(raw).toUtc();
    } on FormatException {
      return started.add(ExplorationTime.backoff(1));
    }
  }

  String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }

  DateTime? _fromMs(int? ms) {
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
}

class JsonFeedBody {
  static String array(List<Map<String, dynamic>> rows) => jsonEncode(rows);
}

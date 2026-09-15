// X3 RED contracts for EveScoutFeedRepository (P03–P07).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §3.1 / §3.3:
// - P03: legacy URL + Authorization header; rows stay in memory not SQLite.
// - P04: every caller hits HTTP; filters send another request.
// - P05: 429 uses 300s; 304 rewrites payloadReceivedAt; 304 without cache succeeds.
// - P06: [] and HTML wipe local notebook rows / accepted revision.
// - P07: second engine does not see SQLite state; late writes overwrite.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/exploration/data/eve_scout_feed_repository.dart';
import 'package:mimir/features/exploration/data/eve_scout_transport.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';
import 'package:path/path.dart' as p;

import '../fixtures/exploration_fixtures.dart';

class ScriptedEveScoutTransport implements EveScoutTransport {
  ScriptedEveScoutTransport();

  final requests = <EveScoutRequest>[];
  final _queue = <FeedHttpResult>[];
  Completer<FeedHttpResult>? firstHold;

  void enqueue(FeedHttpResult result) => _queue.add(result);

  void enqueueJson(List<Map<String, dynamic>> rows, {int statusCode = 200}) {
    enqueue(FeedHttpResult(statusCode: statusCode, body: jsonEncode(rows)));
  }

  @override
  Future<FeedHttpResult> send(EveScoutRequest request) {
    requests.add(request);
    if (requests.length == 1 && firstHold != null) {
      return firstHold!.future;
    }
    if (_queue.isEmpty) {
      return Future.value(const FeedHttpResult(statusCode: 200, body: '[]'));
    }
    return Future.value(_queue.removeAt(0));
  }
}

void main() {
  late AppDatabase database;
  late ScriptedEveScoutTransport transport;
  late DateTime clock;
  late EveScoutFeedRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    transport = ScriptedEveScoutTransport();
    clock = kExplorationT0;
    repository = EveScoutFeedRepository(
      database: database,
      transport: transport,
      clock: () => clock,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertLocalSignature() async {
    await database
        .into(database.trackedSignatures)
        .insert(
          TrackedSignaturesCompanion.insert(
            id: 'local-abc',
            characterId: kCharacter7,
            systemId: kAlphaSystemId,
            code: 'ABC-123',
            firstSeenAtMs: kExplorationT0.millisecondsSinceEpoch,
            lastSeenAtMs: kExplorationT0.millisecondsSinceEpoch,
          ),
        );
  }

  group('P03 verified v2 request and SQLite cache', () {
    test(
      'GET /v2/public/signatures with public headers and persisted rows',
      () async {
        transport.enqueueJson([F3Fixtures.wireRecord()]);
        final outcome = await repository.refresh();
        expect(outcome.kind, FeedRefreshKind.updated);
        expect(transport.requests, hasLength(1));
        final request = transport.requests.single;
        expect(
          request.uri.toString(),
          EveScoutFeedRepository.productionUri.toString(),
        );
        expect(request.uri.path, '/v2/public/signatures');
        expect(request.uri.query, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['User-Agent'], contains('Mimir/'));
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.headers.containsKey('Cookie'), isFalse);
        expect(await repository.publicRowCount(), 1);
        final cached = await repository.readAccepted();
        expect(cached, isNotNull);
        expect(cached!.records.single.providerKey, F3Fixtures.providerKey);
        expect(cached.payloadReceivedAt, kExplorationT0);
      },
    );
  });

  group('P04 single-flight, cooldown, no filter HTTP', () {
    test('two refreshes share one attempt; filters do not fetch', () async {
      transport.enqueueJson([F3Fixtures.wireRecord()]);
      final first = repository.refresh();
      final second = repository.refresh();
      final results = await Future.wait([first, second]);
      expect(transport.requests, hasLength(1));
      expect(
        results.map((result) => result.kind),
        containsAll([FeedRefreshKind.updated, FeedRefreshKind.joinedRequest]),
      );

      clock = F4Fixtures.staleAt;
      transport.requests.clear();
      await repository.refreshWithFilter(
        const PublicConnectionFilter(hubSystemId: kTheraSystemId),
      );
      expect(transport.requests, isEmpty);

      clock = kExplorationT0.add(const Duration(seconds: 299));
      transport.enqueueJson([F3Fixtures.wireRecord()]);
      final cooling = await repository.refresh();
      expect(cooling.kind, FeedRefreshKind.usingCacheUntil);
      expect(transport.requests, isEmpty);
    });
  });

  group('P05 backoff, Retry-After, and 304', () {
    test('429 Retry-After 600 next-attempts at 12:15 not 12:10', () async {
      clock = F4Fixtures.staleAt;
      transport.enqueue(
        const FeedHttpResult(statusCode: 429, headers: {'retry-after': '600'}),
      );
      await repository.refresh();
      transport.enqueueJson([F3Fixtures.wireRecord()]);
      clock = DateTime.utc(2026, 9, 15, 12, 10);
      final tooSoon = await repository.refresh();
      expect(tooSoon.kind, FeedRefreshKind.usingCacheUntil);
      expect(tooSoon.nextAttempt, F4Fixtures.retryAfterDeadline);
      expect(transport.requests, hasLength(1));

      clock = F4Fixtures.retryAfterDeadline;
      transport.enqueueJson([F3Fixtures.wireRecord()]);
      final allowed = await repository.refresh();
      expect(allowed.kind, FeedRefreshKind.updated);
      expect(transport.requests, hasLength(2));
    });

    test(
      '304 with cache renews validation only; 304 without cache fails',
      () async {
        transport.enqueueJson([
          F3Fixtures.wireRecord(),
          F3Fixtures.wireRecord(id: '43'),
        ]);
        await repository.refresh();
        expect(
          (await repository.readAccepted())!.payloadReceivedAt,
          kExplorationT0,
        );

        clock = DateTime.utc(2026, 9, 15, 12, 10);
        transport.enqueue(const FeedHttpResult(statusCode: 304));
        final notModified = await repository.refresh();
        expect(notModified.kind, FeedRefreshKind.validatedNotModified);
        final cached = await repository.readAccepted();
        expect(cached!.payloadReceivedAt, kExplorationT0);
        expect(
          cached.lastSuccessfulValidationAt,
          DateTime.utc(2026, 9, 15, 12, 10),
        );
        expect(cached.records, hasLength(2));

        final empty = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(empty.close);
        final bare = EveScoutFeedRepository(
          database: empty,
          transport: transport,
          clock: () => clock,
        );
        transport.enqueue(const FeedHttpResult(statusCode: 304));
        final failed = await bare.refresh();
        expect(failed.kind, FeedRefreshKind.failedWithoutCache);
      },
    );
  });

  group('P06 atomic empty, malformed, and local isolation', () {
    test('valid [] retires public rows and keeps local signatures', () async {
      await insertLocalSignature();
      transport.enqueueJson([
        F3Fixtures.wireRecord(),
        F3Fixtures.wireRecord(id: '43'),
      ]);
      await repository.refresh();
      expect(await repository.publicRowCount(), 2);
      transport.enqueue(const FeedHttpResult(statusCode: 200, body: '[]'));
      final emptied = await repository.refresh();
      expect(emptied.kind, FeedRefreshKind.updated);
      expect(await repository.publicRowCount(), 0);
      expect(await repository.localSignatureCount(), 1);
    });

    test('HTML and conflicting duplicates retain revision 1', () async {
      transport.enqueueJson([F3Fixtures.wireRecord()]);
      await repository.refresh();
      expect((await repository.readAccepted())!.revision, 1);
      transport.enqueue(
        const FeedHttpResult(statusCode: 200, body: '<html>nope</html>'),
      );
      final html = await repository.refresh();
      expect(html.kind, FeedRefreshKind.failedWithCache);
      expect((await repository.readAccepted())!.revision, 1);
      expect(await repository.publicRowCount(), 1);

      transport.enqueueJson([
        F3Fixtures.wireRecord(id: 42),
        F3Fixtures.wireRecord(id: '42', expiresAt: '2026-09-16T00:00:00Z'),
      ]);
      final conflict = await repository.refresh();
      expect(conflict.kind, FeedRefreshKind.failedWithCache);
      expect(
        (await repository.readAccepted())!.records.single.providerKey,
        F3Fixtures.providerKey,
      );
    });
  });

  group('P07 two engines, late response, shared ownership', () {
    test(
      'second engine rereads SQLite and ignores a stale completion',
      () async {
        final dir = await Directory.systemTemp.createTemp('x3-feed-');
        final file = File(p.join(dir.path, 'app.sqlite'));
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        final dbA = AppDatabase.forTesting(NativeDatabase(file));
        final dbB = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(dbA.close);
        addTearDown(dbB.close);
        final shared = ScriptedEveScoutTransport();
        final repoA = EveScoutFeedRepository(
          database: dbA,
          transport: shared,
          clock: () => clock,
          owner: 'engine-a',
        );
        final repoB = EveScoutFeedRepository(
          database: dbB,
          transport: shared,
          clock: () => clock,
          owner: 'engine-b',
        );

        shared.firstHold = Completer<FeedHttpResult>();
        final late = repoA.refresh();
        shared.enqueueJson([F3Fixtures.wireRecord(id: '99')]);
        final newer = await repoB.refresh();
        expect(newer.kind, FeedRefreshKind.updated);
        expect(shared.requests, hasLength(2));
        expect(
          (await repoB.readAccepted())!.records.single.providerKey,
          'evescout:99',
        );

        shared.firstHold!.complete(
          FeedHttpResult(
            statusCode: 200,
            body: jsonEncode([F3Fixtures.wireRecord()]),
          ),
        );
        final stale = await late;
        expect(stale.kind, isNot(FeedRefreshKind.updated));
        expect(
          (await repoB.readAccepted())!.records.single.providerKey,
          'evescout:99',
        );
        expect(await repoA.readAccepted(), isNotNull);
        expect(
          (await repoA.readAccepted())!.records.single.providerKey,
          'evescout:99',
        );
      },
    );
  });
}

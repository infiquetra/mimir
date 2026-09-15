import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';

import 'exploration_fixtures.dart';

/// Recording public-feed transport. Unexpected HTTP is a test failure.
class RecordingEveScoutTransport {
  RecordingEveScoutTransport();

  final List<Uri> requests = [];
  final List<Map<String, String>> requestHeaders = [];
  bool failUnexpected = true;
  RecordingHttpResponse? nextResponse;

  Future<RecordingHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    requests.add(uri);
    requestHeaders.add(Map<String, String>.from(headers ?? const {}));
    if (nextResponse != null) {
      final response = nextResponse!;
      nextResponse = null;
      return response;
    }
    if (failUnexpected) {
      throw StateError('unexpected EVE-Scout HTTP: $uri');
    }
    return const RecordingHttpResponse(statusCode: 200, body: '[]');
  }
}

class RecordingHttpResponse {
  const RecordingHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// Clipboard reads are recorded. Auto-read without Paste must stay zero.
class RecordingClipboard {
  RecordingClipboard();

  final List<String> reads = [];
  final List<String> writes = [];
  String? _value;

  void seed(String text) => _value = text;

  String? read() {
    final value = _value ?? '';
    reads.add(value);
    return _value;
  }

  void write(String text) => writes.add(text);
}

class RecordingEsiAdapter {
  RecordingEsiAdapter();

  final List<Uri> requests = [];
  final List<String> waypointWrites = [];
  final List<String> bookmarkWrites = [];

  void assertNoSideEffects() {
    if (waypointWrites.isNotEmpty || bookmarkWrites.isNotEmpty) {
      throw StateError('unexpected ESI write: $waypointWrites $bookmarkWrites');
    }
  }
}

class RecordingWindowAdapter {
  RecordingWindowAdapter();

  final List<String> events = [];
}

class RecordingWorkerScheduler {
  RecordingWorkerScheduler();

  final List<String> scheduled = [];
  final List<String> cancelled = [];
}

/// Owns App + SDE databases outside widget lifetime with an injected T0 clock.
class ExplorationTestHarness {
  ExplorationTestHarness();

  static const int baselineAppSchema = 20;
  static const int baselineSdeSchema = 6;

  DateTime Function() clock = () => kExplorationT0;

  late final AppDatabase appDb;
  late final SdeDatabase sdeDb;
  late final RecordingEveScoutTransport http;
  late final RecordingClipboard clipboard;
  late final RecordingEsiAdapter esi;
  late final RecordingWindowAdapter windows;
  late final RecordingWorkerScheduler workers;

  bool _tornDown = false;

  Future<void> setUp() async {
    appDb = AppDatabase.forTesting(NativeDatabase.memory());
    sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
    http = RecordingEveScoutTransport();
    clipboard = RecordingClipboard();
    esi = RecordingEsiAdapter();
    windows = RecordingWindowAdapter();
    workers = RecordingWorkerScheduler();
  }

  List<Override> overrides() {
    return [
      databaseProvider.overrideWithValue(appDb),
      sdeDatabaseProvider.overrideWithValue(sdeDb),
    ];
  }

  ExplorationClock explorationClock() => ExplorationClock(now: clock);

  int get capturedAppSchema => appDb.schemaVersion;
  int get capturedSdeSchema => sdeDb.schemaVersion;

  Future<void> tearDown() async {
    if (_tornDown) return;
    _tornDown = true;
    await appDb.close();
    await sdeDb.close();
  }
}

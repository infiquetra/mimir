import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/exploration/data/exploration_reference_repository.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/domain/exploration_reference_deriver.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const perfLog = 'EXPLORATION.PERF';

  group('Exploration Performance Harness (P18/X10)', () {
    late SdeDatabase sdeDb;
    late SdeService sdeService;
    late ExplorationReferenceRepository refRepo;

    setUp(() async {
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      sdeService = SdeService(database: sdeDb);
      refRepo = ExplorationReferenceRepository(
        database: sdeDb,
        service: sdeService,
      );

      final rawTypes = List.generate(
        350,
        (i) => RawWormholeRecord(
          typeId: 10000 + i,
          code: 'WH-${i.toString().padLeft(3, '0')}',
          name: 'Wormhole Type $i',
          published: i % 5 != 0,
          rawTargetClass: (i % 6) + 1,
          rawMaxStableTimeMinutes: 1440,
          rawTotalMassKg: 1000000000.0,
          rawJumpMassKg: 300000000.0,
        ),
      );

      final bundle = ExplorationReferenceBundle(
        manifest: ReferenceManifest(
          sdeBuild: 3503375,
          datasetSchema: 1,
          checksums: const {'exploration.json': 'sha256:perf'},
          rowCounts: const {'wormholeTypes': 350, 'effects': 36},
          importedAt: DateTime.now(),
          coverage: 'perf-fixture',
          validation: 'ok',
        ),
        types: rawTypes,
        checksum: 'sha256:perf',
      );

      final result = await refRepo.importBundle(bundle);
      expect(result.success, isTrue);
    });

    tearDown(() async {
      await sdeDb.close();
    });

    test(
      'Indexed reference search p95 <= 100ms (>= 100 measured runs)',
      () async {
        // Warmup: 10 runs
        for (var i = 0; i < 10; i++) {
          await refRepo.searchExplorationTypes(
            TypeSearchQuery(text: 'WH-${i.toString().padLeft(2, '0')}'),
          );
        }

        // Measured runs: 100 runs
        const sampleCount = 100;
        final durationsMs = <double>[];

        for (var i = 0; i < sampleCount; i++) {
          final query = TypeSearchQuery(
            text: 'WH-${(i % 30).toString().padLeft(2, '0')}',
            rawTargetClass: i % 2 == 0 ? 1 : null,
          );
          final sw = Stopwatch()..start();
          final results = await refRepo.searchExplorationTypes(query);
          sw.stop();
          durationsMs.add(sw.elapsedMicroseconds / 1000.0);
          expect(results, isNotNull);
        }

        durationsMs.sort();
        final p50 = durationsMs[(sampleCount * 0.50).floor()];
        final p95 = durationsMs[(sampleCount * 0.95).floor()];
        final peakRssMb = ProcessInfo.currentRss / (1024 * 1024);

        Log.i(
          perfLog,
          'SEARCH PERF: OS=${Platform.operatingSystem} cores=${Platform.numberOfProcessors} '
          'mode=${kDebugMode ? "debug" : "release"} samples=$sampleCount '
          'p50=${p50.toStringAsFixed(2)}ms p95=${p95.toStringAsFixed(2)}ms '
          'peakRss=${peakRssMb.toStringAsFixed(1)}MB',
        );

        expect(
          p95,
          lessThanOrEqualTo(100.0),
          reason: 'Search p95 must be <= 100ms per specification',
        );
      },
    );

    test(
      'Pure routing solver p95 <= 1s on 10k-system/30k-directed-edge fixture (>= 100 measured runs)',
      () {
        const nodeCount = 10000;
        const targetEdgeCount = 30000;

        // 1. Graph building (timed separately)
        final buildSw = Stopwatch()..start();
        final nodes = <int>{};
        for (var i = 1; i <= nodeCount; i++) {
          nodes.add(i);
        }

        final edges = <DirectedExplorationEdge>[];
        // Deterministic ring topology (10,000 edges)
        for (var i = 1; i <= nodeCount; i++) {
          final next = (i % nodeCount) + 1;
          edges.add(
            DirectedExplorationEdge(
              key: 'gate-$i-$next',
              fromSystemId: i,
              toSystemId: next,
              kind: 'gate',
            ),
          );
        }

        // Chordal and cross-network shortcuts (20,000 edges, with ties and unavailable edges)
        var edgeIdx = 0;
        while (edges.length < targetEdgeCount) {
          edgeIdx++;
          final from = ((edgeIdx * 37) % nodeCount) + 1;
          final step = ((edgeIdx * 53) % 499) + 2;
          final to = ((from + step - 1) % nodeCount) + 1;
          if (from == to) continue;

          final isWormhole = edgeIdx % 3 == 0;
          final isEol = edgeIdx % 7 == 0;
          final isCritical = edgeIdx % 11 == 0;

          edges.add(
            DirectedExplorationEdge(
              key: 'edge-$edgeIdx-$from-$to',
              canonicalKey: 'edge-$edgeIdx',
              fromSystemId: from,
              toSystemId: to,
              kind: isWormhole ? 'wormhole' : 'gate',
              eol: isEol,
              critical: isCritical,
            ),
          );
        }
        buildSw.stop();

        final graph = GraphSnapshot(
          nodes: nodes,
          edges: edges,
          topologyAvailable: true,
        );

        expect(graph.nodes.length, nodeCount);
        expect(graph.edges.length, targetEdgeCount);

        // Warmup pure solver: 10 runs
        for (var i = 0; i < 10; i++) {
          final req = RouteRequest(
            originSystemId: (i * 73) % nodeCount + 1,
            destinationSystemId: (i * 127 + 500) % nodeCount + 1,
            preferences: const RoutePreferences(
              avoidEol: true,
              avoidCriticalMass: true,
            ),
          );
          ExplorationRouteEngine.route(req, graph);
        }

        // Measured solver runs: 100 runs
        const sampleCount = 100;
        final solverDurationsMs = <double>[];

        for (var i = 0; i < sampleCount; i++) {
          final origin = ((i * 97) % nodeCount) + 1;
          final dest = ((i * 313 + 3333) % nodeCount) + 1;
          final req = RouteRequest(
            originSystemId: origin,
            destinationSystemId: dest,
            preferences: RoutePreferences(
              avoidEol: i % 2 == 0,
              avoidCriticalMass: i % 3 == 0,
              preferHighsec: i % 4 == 0,
            ),
            operationId: 'perf-$i',
          );

          final sw = Stopwatch()..start();
          final result = ExplorationRouteEngine.route(req, graph);
          sw.stop();
          solverDurationsMs.add(sw.elapsedMicroseconds / 1000.0);
          expect(result, isNotNull);
        }

        solverDurationsMs.sort();
        final p50 = solverDurationsMs[(sampleCount * 0.50).floor()];
        final p95 = solverDurationsMs[(sampleCount * 0.95).floor()];
        final peakRssMb = ProcessInfo.currentRss / (1024 * 1024);

        Log.i(
          perfLog,
          'ROUTING PERF: OS=${Platform.operatingSystem} cores=${Platform.numberOfProcessors} '
          'mode=${kDebugMode ? "debug" : "release"} samples=$sampleCount '
          'nodes=${graph.nodes.length} edges=${graph.edges.length} '
          'graphBuildTime=${buildSw.elapsedMilliseconds}ms '
          'pureSolver_p50=${p50.toStringAsFixed(2)}ms pureSolver_p95=${p95.toStringAsFixed(2)}ms '
          'peakRss=${peakRssMb.toStringAsFixed(1)}MB',
        );

        expect(
          p95,
          lessThanOrEqualTo(1000.0),
          reason: 'Pure routing solver p95 must be <= 1s per specification',
        );
      },
    );
  });
}

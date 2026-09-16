import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/exploration/data/eve_scout_feed_repository.dart';
import 'package:mimir/features/exploration/data/eve_scout_transport.dart';
import 'package:mimir/features/exploration/data/exploration_notebook_repository.dart';
import 'package:mimir/features/exploration/data/exploration_origin_service.dart';
import 'package:mimir/features/exploration/data/exploration_reference_repository.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_graph_builder.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/domain/exploration_reference_deriver.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

const _log = 'EXPLORATION.PROVIDER';

final explorationClockProvider = Provider<ExplorationClock>((ref) {
  return ExplorationClock();
});

final explorationReferenceRepositoryProvider =
    Provider<ExplorationReferenceRepository>((ref) {
      return ExplorationReferenceRepository(
        database: ref.watch(sdeDatabaseProvider),
        service: ref.watch(sdeServiceProvider),
      );
    });

final explorationReferenceStatusProvider =
    StreamProvider<ExplorationReferenceStatus>((ref) {
      final repo = ref.watch(explorationReferenceRepositoryProvider);
      return Stream.fromFuture(repo.readExplorationManifest()).map((manifest) {
        Log.d(_log, 'reference status build=${manifest?.sdeBuild}');
        return ExplorationReferenceStatus(
          ready: manifest != null,
          version: manifest?.sdeBuild.toString(),
        );
      });
    });

final explorationTypeSearchProvider = FutureProvider.autoDispose
    .family<List<WormholeTypeReference>, String>((ref, query) async {
      final repo = ref.watch(explorationReferenceRepositoryProvider);
      final groups = await repo.searchExplorationTypes(
        TypeSearchQuery(text: query),
      );
      return [for (final group in groups) ...group.variants];
    });

final explorationSystemSearchProvider = FutureProvider.autoDispose
    .family<List<SystemReference>, String>((ref, query) async {
      final repo = ref.watch(explorationReferenceRepositoryProvider);
      final rows = await repo.service.searchSystems(query);
      return [
        for (final row in rows)
          SystemReference(
            systemId: row.systemId,
            name: row.name,
            constellationId: row.constellationId,
            regionId: row.regionId,
            constellationName: row.constellationName,
            regionName: row.regionName,
            rawSecurity: row.rawSecurity,
            rawClass: row.rawClass,
            inheritedClass: row.inheritedClass,
            inheritanceSource: row.inheritanceSource,
            effectBeaconTypeId: row.effectBeaconTypeId,
            visualSunTypeId: row.visualSunTypeId,
          ),
      ];
    });

final explorationSystemDetailProvider = FutureProvider.autoDispose
    .family<SystemReference?, int>((ref, id) async {
      final repo = ref.watch(explorationReferenceRepositoryProvider);
      final rows = await repo.getSystemReferences([id]);
      return rows.isEmpty ? null : rows.first;
    });

final eveScoutTransportProvider = Provider<EveScoutTransport>((ref) {
  return HttpEveScoutTransport();
});

final eveScoutFeedRepositoryProvider = Provider<EveScoutFeedRepository>((ref) {
  return EveScoutFeedRepository(
    database: ref.watch(databaseProvider),
    transport: ref.watch(eveScoutTransportProvider),
    clock: () => ref.watch(explorationClockProvider).now(),
  );
});

var explorationFeedWatchHttpCalls = 0;

final eveScoutFeedProvider = StreamProvider<FeedSnapshot>((ref) {
  Log.d(_log, 'watch feed cache (no HTTP)');
  final cached = ExplorationSession.shared.publicFeed ?? FeedSnapshot();
  return Stream.value(cached);
});

final explorationRefreshControllerProvider =
    Provider<ExplorationRefreshController>((ref) {
      return ExplorationRefreshController();
    });

final explorationVisibilityProvider = Provider<bool>((ref) => true);

final explorationLiveDemandProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(explorationVisibilityProvider);
});

final explorationNotebookRepositoryProvider =
    Provider<ExplorationNotebookRepository>((ref) {
      return ExplorationNotebookRepository(
        database: ref.watch(databaseProvider),
        clock: () => ref.watch(explorationClockProvider).now(),
      );
    });

final explorationNotebookProvider =
    StreamProvider.family<
      List<TrackedSignature>,
      ({NotebookScope scope, String view})
    >((ref, key) {
      return Stream.value(ExplorationSession.shared.notebookFor(key.scope));
    });

final explorationImportControllerProvider =
    Provider.family<ExplorationImportController, NotebookScope>((ref, scope) {
      return ExplorationImportController(scope);
    });

final explorationConnectionControllerProvider =
    Provider.family<ExplorationConnectionController, NotebookScope>((
      ref,
      scope,
    ) {
      return ExplorationConnectionController(scope);
    });

final explorationOriginControllerProvider =
    Provider<ExplorationOriginController>((ref) {
      final clock = ref.watch(explorationClockProvider);
      final esi = ref.watch(esiClientProvider);
      final controller = ExplorationOriginController(
        service: ExplorationOriginService(
          clock: clock.now,
          strictLocation: esi.getCharacterLocationStrict,
        ),
      );
      ref
          .watch(activeCharacterProvider)
          .when(
            data: (character) {
              Log.d(_log, 'origin character=${character?.characterId}');
            },
            loading: () {
              Log.d(_log, 'origin character loading');
            },
            error: (error, stack) {
              Log.w(_log, 'origin character error: $error');
            },
          );
      return controller;
    });

final explorationRouteInputsProvider = Provider<ExplorationRouteInputs>((ref) {
  final origin = ref.watch(explorationOriginControllerProvider).origin;
  return ExplorationRouteInputs(origin: origin);
});

final explorationGraphProvider = FutureProvider.family<GraphSnapshot, String>((
  ref,
  inputKey,
) async {
  final characterId = ref
      .watch(activeCharacterProvider)
      .when(
        data: (character) => character?.characterId,
        loading: () => null,
        error: (error, stack) {
          Log.w(_log, 'graph character error: $error');
          return null;
        },
      );
  final edges = ExplorationSession.shared.visibleEdges(characterId ?? 0);
  return ExplorationGraphBuilder.fromEdges(edges);
});

final explorationRouteControllerProvider = Provider<ExplorationRouteController>(
  (ref) {
    return ExplorationRouteController(
      isCurrent: (observedAt, now) => ExplorationOriginService(
        clock: () => now,
      ).isCurrentObservation(observedAt, now),
    );
  },
);

final explorationNearestControllerProvider =
    Provider<ExplorationNearestController>((ref) {
      return ExplorationNearestController();
    });

final explorationDeadlineProvider = Provider<ExplorationDeadlineController>((
  ref,
) {
  return ExplorationDeadlineController(
    clock: () => ref.watch(explorationClockProvider).now(),
  );
});

final explorationNavigationControllerProvider =
    Provider<ExplorationNavigationController>((ref) {
      return ExplorationNavigationController();
    });

final explorationNameResolverProvider = Provider<ExplorationNameResolver>((
  ref,
) {
  return ExplorationNameResolver();
});

class ExplorationReferenceStatus {
  const ExplorationReferenceStatus({this.ready = false, this.version});

  final bool ready;
  final String? version;
}

class ExplorationRouteInputs {
  const ExplorationRouteInputs({
    this.origin = const UnselectedOrigin(),
    this.destinationSystemId,
    this.preferences = RoutePreferences.defaults,
  });

  final OriginSelection origin;
  final int? destinationSystemId;
  final RoutePreferences preferences;
}

class ExplorationRefreshController {
  FeedSnapshot? cache;
  var httpCalls = 0;

  Future<void> refreshPublicFeed(String reason) async {
    Log.i(_log, 'refreshPublicFeed reason=$reason');
    if (cache != null && cache!.lastSuccessfulValidationAt != null) {
      return;
    }
    httpCalls += 1;
  }
}

class ExplorationNameResolver {
  ExplorationNameResolver({this.local = const {}, this.cached = const {}});

  final Map<int, String> local;
  final Map<int, String> cached;

  String resolve(int id) {
    final localName = local[id];
    if (localName != null && localName.isNotEmpty) return localName;
    final cachedName = cached[id];
    if (cachedName != null && cachedName.isNotEmpty) return cachedName;
    return 'Unknown';
  }
}

class ExplorationDeadlineController {
  ExplorationDeadlineController({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  var originCurrent = true;
  var feedFreshness = FeedFreshness.fresh;
  var timeEstimate = TimeEstimate.stable;
  var verificationValid = true;
  var httpCalls = 0;

  DateTime now() => _now().toUtc();

  void tick({
    DateTime? originObservedAt,
    DateTime? publicValidatedAt,
    DateTime? expiresAt,
    DateTime? verifiedAt,
  }) {
    final clock = now();
    if (originObservedAt != null) {
      originCurrent =
          clock.difference(originObservedAt.toUtc()) <=
          ExplorationOriginService.currentWindow;
    }
    if (publicValidatedAt != null) {
      feedFreshness = ExplorationTime.feedFreshness(
        validatedAt: publicValidatedAt.toUtc(),
        now: clock,
      );
    }
    if (expiresAt != null) {
      timeEstimate = ExplorationTime.timeEstimate(
        expiresAt: expiresAt.toUtc(),
        now: clock,
      );
    }
    if (verifiedAt != null) {
      verificationValid =
          clock.difference(verifiedAt.toUtc()) < const Duration(hours: 24);
    }
  }
}

class ExplorationRouteController {
  ExplorationRouteController({
    bool Function(DateTime observedAt, DateTime now)? isCurrent,
  }) : _isCurrent = isCurrent;

  final bool Function(DateTime observedAt, DateTime now)? _isCurrent;

  var generation = 0;
  RouteResult? published;

  void switchCharacter(int characterId) {
    generation++;
    Log.i(_log, 'route generation=$generation character=$characterId');
  }

  Future<void> complete(
    Future<RouteResult> work, {
    DateTime Function()? now,
    DateTime? originObservedAt,
  }) async {
    final gen = generation;
    final result = await work;
    if (gen != generation) {
      published = null;
      Log.i(_log, 'dropped late route generation=$gen');
      return;
    }
    final clock = (now ?? DateTime.now)().toUtc();
    var outdated = result.outdated;
    if (originObservedAt != null) {
      final current = _isCurrent != null
          ? _isCurrent(originObservedAt, clock)
          : clock.difference(originObservedAt.toUtc()) <=
                ExplorationOriginService.currentWindow;
      if (!current) outdated = true;
    }
    published = RouteResult(
      outcome: result.outcome,
      steps: result.steps,
      gateJumps: result.gateJumps,
      wormholeJumps: result.wormholeJumps,
      riskSum: result.riskSum,
      maxRisk: result.maxRisk,
      fingerprint: result.fingerprint,
      limitations: result.limitations,
      calculatedAt: result.calculatedAt,
      outdated: outdated,
    );
  }
}

class ExplorationNearestController {
  var generation = 0;
  NearestEntranceOutcome? published;

  void switchCharacter(int characterId) {
    generation++;
  }
}

class ExplorationNavigationController {
  var selectedView = 0;
}

class ExplorationImportController {
  ExplorationImportController(this.scope);
  final NotebookScope scope;
}

class ExplorationConnectionController {
  ExplorationConnectionController(this.scope);
  final NotebookScope scope;
}

class ExplorationSession {
  ExplorationSession();

  static final shared = ExplorationSession();

  OriginSelection origin = const UnselectedOrigin();
  FeedSnapshot? publicFeed;
  final notebook = <int, List<TrackedSignature>>{};
  final edges = <DirectedExplorationEdge>[];

  void reset() {
    origin = const UnselectedOrigin();
    publicFeed = null;
    notebook.clear();
    edges.clear();
  }

  void setManual(int systemId) {
    origin = ManualOrigin(systemId);
  }

  void switchCharacter({required int from, required int to}) {
    if (origin is! ManualOrigin) {
      origin = const UnselectedOrigin();
    }
    edges.removeWhere((edge) => edge.privateOwner != null);
  }

  List<TrackedSignature> notebookFor(NotebookScope scope) {
    return [
      for (final row
          in notebook[scope.characterId] ?? const <TrackedSignature>[])
        if (row.systemId == scope.systemId) row,
    ];
  }

  List<DirectedExplorationEdge> visibleEdges(int characterId) {
    return [
      for (final edge in edges)
        if (edge.privateOwner == null || edge.privateOwner == characterId) edge,
    ];
  }
}

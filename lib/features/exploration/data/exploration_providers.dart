import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/exploration/data/exploration_origin_service.dart';
import 'package:mimir/features/exploration/data/exploration_reference_repository.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

/// Naive X6 providers: unguarded AsyncValue access, watch-triggered HTTP,
/// no generation reject, badges ignore local timers, names fall back to raw IDs.

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
      return Stream.value(const ExplorationReferenceStatus());
    });

final explorationTypeSearchProvider = FutureProvider.autoDispose
    .family<List<WormholeTypeReference>, String>((ref, query) async {
      return const [];
    });

final explorationSystemSearchProvider = FutureProvider.autoDispose
    .family<List<SystemReference>, String>((ref, query) async {
      return const [];
    });

final explorationSystemDetailProvider = FutureProvider.autoDispose
    .family<SystemReference?, int>((ref, id) async {
      return null;
    });

var explorationFeedWatchHttpCalls = 0;

final eveScoutFeedProvider = StreamProvider<FeedSnapshot>((ref) {
  explorationFeedWatchHttpCalls += 1;
  return Stream.value(FeedSnapshot());
});

final explorationRefreshControllerProvider =
    Provider<ExplorationRefreshController>((ref) {
      return ExplorationRefreshController();
    });

final explorationVisibilityProvider = Provider<bool>((ref) => true);

final explorationLiveDemandProvider = Provider<bool>((ref) => true);

final explorationNotebookProvider =
    StreamProvider.family<
      List<TrackedSignature>,
      ({NotebookScope scope, String view})
    >((ref, key) {
      return Stream.value(ExplorationSession.shared.notebookFor(key.scope));
    });

final explorationImportControllerProvider =
    Provider.family<Object, NotebookScope>((ref, scope) => Object());

final explorationConnectionControllerProvider =
    Provider.family<Object, NotebookScope>((ref, scope) => Object());

final explorationOriginControllerProvider =
    Provider<ExplorationOriginController>((ref) {
      final active = ref.watch(activeCharacterProvider).value;
      return ExplorationOriginController(
        service: ExplorationOriginService(
          clock: () => ref.watch(explorationClockProvider).now(),
        ),
      )..generation = active?.characterId ?? 0;
    });

final explorationRouteInputsProvider = Provider<ExplorationRouteInputs>((ref) {
  return const ExplorationRouteInputs();
});

final explorationGraphProvider = FutureProvider.family<GraphSnapshot, String>((
  ref,
  inputKey,
) async {
  return GraphSnapshot(nodes: {}, edges: const []);
});

final explorationRouteControllerProvider = Provider<ExplorationRouteController>(
  (ref) {
    return ExplorationRouteController();
  },
);

final explorationNearestControllerProvider = Provider<Object>(
  (ref) => Object(),
);

final explorationDeadlineProvider = Provider<ExplorationDeadlineController>((
  ref,
) {
  return ExplorationDeadlineController(
    clock: () => ref.watch(explorationClockProvider).now(),
  );
});

final explorationNavigationControllerProvider = Provider<Object>(
  (ref) => Object(),
);

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
    httpCalls += 1;
    cache = null;
  }
}

class ExplorationNameResolver {
  ExplorationNameResolver({this.local = const {}, this.cached = const {}});

  final Map<int, String> local;
  final Map<int, String> cached;

  String resolve(int id) => 'Item #$id';
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
    httpCalls += 1;
  }
}

class ExplorationRouteController {
  var generation = 0;
  RouteResult? published;

  void switchCharacter(int characterId) {
    generation++;
  }

  Future<void> complete(
    Future<RouteResult> work, {
    DateTime Function()? now,
    DateTime? originObservedAt,
  }) async {
    published = await work;
  }
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
    origin = const UnselectedOrigin();
    publicFeed = null;
    notebook[to] = List<TrackedSignature>.from(notebook[from] ?? const []);
  }

  List<TrackedSignature> notebookFor(NotebookScope scope) {
    return notebook[scope.characterId] ?? const [];
  }

  List<DirectedExplorationEdge> visibleEdges(int characterId) => edges;
}

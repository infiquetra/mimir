// X6 RED contracts for providers, ViewModels, and CharacterNavRail (P09/P15/P17).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §5:
// - late route results publish after character switch
// - private notebook/edges leak across characters; public/manual are wiped
// - local timers keep current/fresh/stable badges and issue HTTP
// - names fall back to Item #<id>; providers use unguarded .value
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/data/exploration_origin_service.dart';
import 'package:mimir/features/exploration/data/exploration_providers.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  setUp(() {
    explorationFeedWatchHttpCalls = 0;
    ExplorationSession.shared.reset();
  });

  group('§5.1 provider topology', () {
    test('declared provider names match the design table', () {
      final source = File(
        'lib/features/exploration/data/exploration_providers.dart',
      ).readAsStringSync();
      const names = [
        'explorationClockProvider',
        'explorationReferenceRepositoryProvider',
        'explorationReferenceStatusProvider',
        'explorationTypeSearchProvider',
        'explorationSystemSearchProvider',
        'explorationSystemDetailProvider',
        'eveScoutFeedProvider',
        'explorationRefreshControllerProvider',
        'explorationVisibilityProvider',
        'explorationLiveDemandProvider',
        'explorationNotebookProvider',
        'explorationImportControllerProvider',
        'explorationConnectionControllerProvider',
        'explorationOriginControllerProvider',
        'explorationRouteInputsProvider',
        'explorationGraphProvider',
        'explorationRouteControllerProvider',
        'explorationNearestControllerProvider',
        'explorationDeadlineProvider',
        'explorationNavigationControllerProvider',
        'explorationNameResolverProvider',
      ];
      for (final name in names) {
        expect(source.contains('final $name'), isTrue, reason: name);
      }
    });

    test('explorationClockProvider is overridable', () {
      final container = ProviderContainer(
        overrides: [
          explorationClockProvider.overrideWith(
            (ref) => ExplorationClock(now: () => kExplorationT0),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(explorationClockProvider).now(), kExplorationT0);
    });
  });

  group('P09 character switch isolation', () {
    test('late route completion cannot publish after switch', () async {
      final controller = ExplorationRouteController();
      final hold = Completer<RouteResult>();
      final pending = controller.complete(
        hold.future,
        originObservedAt: kExplorationT0,
        now: () => kExplorationT0,
      );
      controller.switchCharacter(kCharacter8);
      hold.complete(
        RouteResult(
          outcome: RouteOutcome.found,
          fingerprint: 'char-7',
          calculatedAt: kExplorationT0,
        ),
      );
      await pending;
      expect(controller.published, isNull);
    });

    test('private notebook and edges stay on the owning character', () {
      final session = ExplorationSession.shared;
      session.notebook[kCharacter7] = [
        TrackedSignature(
          id: 'sig-7',
          characterId: kCharacter7,
          systemId: kAlphaSystemId,
          code: 'ABC-123',
          episodeId: 'ep-7',
        ),
      ];
      session.edges.addAll([
        DirectedExplorationEdge(
          key: 'public',
          fromSystemId: kAlphaSystemId,
          toSystemId: kTheraSystemId,
          kind: 'wormhole',
        ),
        DirectedExplorationEdge(
          key: 'private-7',
          fromSystemId: kAlphaSystemId,
          toSystemId: kTurnurSystemId,
          kind: 'wormhole',
          privateOwner: kCharacter7,
        ),
        DirectedExplorationEdge(
          key: 'private-8',
          fromSystemId: kAlphaSystemId,
          toSystemId: 201,
          kind: 'wormhole',
          privateOwner: kCharacter8,
        ),
      ]);

      session.switchCharacter(from: kCharacter7, to: kCharacter8);

      expect(
        session.notebookFor(
          const NotebookScope(
            characterId: kCharacter8,
            systemId: kAlphaSystemId,
          ),
        ),
        isEmpty,
      );
      expect(
        session
            .notebookFor(
              const NotebookScope(
                characterId: kCharacter7,
                systemId: kAlphaSystemId,
              ),
            )
            .map((row) => row.id),
        ['sig-7'],
      );
      expect(session.visibleEdges(kCharacter8).map((edge) => edge.key), [
        'public',
      ]);
      expect(
        session.visibleEdges(kCharacter8).any((edge) => edge.privateOwner == 7),
        isFalse,
      );
    });

    test('public feed and manual origin survive character switch', () {
      final session = ExplorationSession.shared;
      session.setManual(kAlphaSystemId);
      session.publicFeed = FeedSnapshot(
        records: const [],
        revision: 4,
        lastSuccessfulValidationAt: kExplorationT0,
      );
      session.switchCharacter(from: kCharacter7, to: kCharacter8);
      expect(session.origin, isA<ManualOrigin>());
      expect((session.origin as ManualOrigin).systemId, kAlphaSystemId);
      expect(session.publicFeed?.revision, 4);
    });
  });

  group('P15 local timer invalidation', () {
    test('local ticks never make HTTP', () {
      final deadline = ExplorationDeadlineController(
        clock: () => kExplorationT0,
      );
      deadline.tick(
        originObservedAt: kExplorationT0,
        publicValidatedAt: kExplorationT0,
        expiresAt: kExplorationT0.add(const Duration(hours: 8)),
        verifiedAt: kExplorationT0,
      );
      expect(deadline.httpCalls, 0);
    });

    test('current origin is outdated at 60s+1ms', () {
      final now = kExplorationT0.add(
        const Duration(seconds: 60, milliseconds: 1),
      );
      final deadline = ExplorationDeadlineController(clock: () => now);
      deadline.tick(originObservedAt: kExplorationT0);
      expect(deadline.originCurrent, isFalse);
      expect(
        ExplorationOriginService(
          clock: () => now,
        ).isCurrentObservation(kExplorationT0, now),
        isFalse,
      );
    });

    test('public feed is stale at 5m and view-only at 24h', () {
      final stale = ExplorationDeadlineController(
        clock: () => kExplorationT0.add(const Duration(minutes: 5)),
      )..tick(publicValidatedAt: kExplorationT0);
      expect(stale.feedFreshness, FeedFreshness.stale);

      final viewOnly = ExplorationDeadlineController(
        clock: () => kExplorationT0.add(const Duration(hours: 24)),
      )..tick(publicValidatedAt: kExplorationT0, verifiedAt: kExplorationT0);
      expect(viewOnly.feedFreshness, FeedFreshness.viewOnly);
      expect(viewOnly.verificationValid, isFalse);
    });

    test('EOL starts at expiresAt-4h+1ms', () {
      final deadline = ExplorationDeadlineController(
        clock: () =>
            kExplorationT0.add(const Duration(hours: 4, milliseconds: 1)),
      )..tick(expiresAt: kExplorationT0.add(const Duration(hours: 8)));
      expect(deadline.timeEstimate, TimeEstimate.eol);
    });

    test('watching the feed provider does not itself make HTTP', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(eveScoutFeedProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(eveScoutFeedProvider.future);
      expect(explorationFeedWatchHttpCalls, 0);
    });

    test('refresh keeps an already-valid cache', () async {
      final refresh = ExplorationRefreshController()
        ..cache = FeedSnapshot(
          revision: 3,
          lastSuccessfulValidationAt: kExplorationT0,
        );
      await refresh.refreshPublicFeed('appbar');
      expect(refresh.cache?.revision, 3);
    });

    test(
      'route completing after origin expiry is outdated immediately',
      () async {
        final controller = ExplorationRouteController();
        await controller.complete(
          Future.value(
            RouteResult(
              outcome: RouteOutcome.found,
              fingerprint: 'late',
              calculatedAt: kExplorationT0.add(
                const Duration(seconds: 60, milliseconds: 1),
              ),
            ),
          ),
          originObservedAt: kExplorationT0,
          now: () =>
              kExplorationT0.add(const Duration(seconds: 60, milliseconds: 1)),
        );
        expect(controller.published, isNotNull);
        expect(controller.published!.outdated, isTrue);
      },
    );
  });

  group('P17 name resolver and AsyncValue safety', () {
    test('resolves local first, then cache, and never shows raw IDs', () {
      final resolver = ExplorationNameResolver(
        local: {kAlphaSystemId: 'Alpha'},
        cached: {30000142: 'Jita'},
      );
      expect(resolver.resolve(kAlphaSystemId), 'Alpha');
      expect(resolver.resolve(30000142), 'Jita');
      expect(resolver.resolve(1), 'Unknown');
      expect(resolver.resolve(kAlphaSystemId), isNot(contains('9101')));
      expect(resolver.resolve(1), isNot(contains('Item #')));
      expect(resolver.resolve(1), isNot(contains('1')));
    });

    test('exploration providers do not use unguarded AsyncValue.value', () {
      final source = File(
        'lib/features/exploration/data/exploration_providers.dart',
      ).readAsStringSync();
      expect(RegExp(r'Provider\)\.value').hasMatch(source), isFalse);
      expect(source.contains('requireValue'), isFalse);
      expect(source.contains('.when('), isTrue);
    });

    test('CharacterNavRail uses .when() for the active character', () {
      final source = File(
        'lib/core/widgets/character_nav_rail.dart',
      ).readAsStringSync();
      expect(source.contains('activeCharacterProvider).value'), isFalse);
      expect(
        source.contains('ref.watch(activeCharacterProvider).value'),
        isFalse,
      );
      expect(source.contains('activeCharacterProvider'), isTrue);
      expect(source.contains('.when('), isTrue);
    });
  });
}

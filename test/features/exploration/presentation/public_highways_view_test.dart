// X8 RED contracts for PublicHighwaysView (U02–U03, U06–U10, U18).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §6.4:
// - Live/remainingHours; hub-only copy; one empty copy for every surface
// - no RefreshIndicator; nearest combines jumps; Route writes to EVE
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';
import 'package:mimir/features/exploration/presentation/exploration_screen.dart';
import 'package:mimir/features/exploration/presentation/public_highways_view.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  final copied = <String>[];

  setUp(() {
    copied.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copied.add(args['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  PublicConnection f3({String? inSignature = 'FAR-456', bool? outward = true}) {
    return PublicConnection.fromWire(
      F3Fixtures.wireRecord(inSignature: inSignature, exitsOutward: outward),
      now: kExplorationT0,
    );
  }

  Future<void> pumpView(
    WidgetTester tester,
    PublicHighwaysViewModel model, {
    Size size = const Size(1440, 900),
    double textScale = 1,
    Future<void> Function()? onRefresh,
    ValueChanged<int>? onSelectFarSystem,
    ValueChanged<int>? onEveWrite,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: PublicHighwaysView(
              model: model,
              onRefresh: onRefresh,
              onSelectFarSystem: onSelectFarSystem,
              onEveWrite: onEveWrite,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('U06/U07 PublicHighwaysView feed', () {
    testWidgets('ExplorationScreen tab 1 hosts PublicHighwaysView', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1440, 900)),
          child: MaterialApp(home: ExplorationScreen()),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Connections').first);
      await tester.pump();
      expect(find.byType(PublicHighwaysView), findsOneWidget);
    });

    testWidgets('status strip shows validation/receipt/report, not Live', (
      tester,
    ) async {
      await pumpView(
        tester,
        PublicHighwaysViewModel(
          connections: [f3()],
          freshness: FeedFreshness.stale,
          validatedAt: kExplorationT0,
          payloadReceivedAt: kExplorationT0.subtract(const Duration(hours: 1)),
          reportedAt: F3Fixtures.reportedUpdate,
        ),
      );
      expect(find.byKey(const Key('public-feed-status')), findsOneWidget);
      expect(find.textContaining('Live'), findsNothing);
      expect(find.textContaining('Stale'), findsOneWidget);
      expect(find.textContaining('EVE-Scout'), findsOneWidget);
      expect(find.textContaining('Signal Cartel'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
    });

    testWidgets('AppBar and pull refresh share one controller', (tester) async {
      var calls = 0;
      await pumpView(
        tester,
        PublicHighwaysViewModel(surface: PublicHighwaysSurface.validEmpty),
        onRefresh: () async {
          calls += 1;
        },
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh connections'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Connections updated.'), findsNothing);
    });

    testWidgets('cards show both endpoints, Unknown mass, reported size', (
      tester,
    ) async {
      await pumpView(tester, PublicHighwaysViewModel(connections: [f3()]));
      expect(find.textContaining('Turnur'), findsWidgets);
      expect(find.textContaining('Alpha'), findsWidgets);
      expect(find.textContaining('K162'), findsWidgets);
      expect(find.textContaining('B274'), findsWidgets);
      expect(find.textContaining('Unknown'), findsWidgets);
      expect(find.textContaining('xlarge'), findsWidgets);
      expect(find.textContaining('Item #'), findsNothing);
      expect(find.textContaining('$kAlphaSystemId'), findsNothing);
    });

    testWidgets('copy uses the selected known far signature only', (
      tester,
    ) async {
      await pumpView(tester, PublicHighwaysViewModel(connections: [f3()]));
      await tester.tap(find.byKey(const Key('copy-far-signature')));
      await tester.pump();
      expect(copied, ['FAR-456']);
      expect(find.text('Signature copied.'), findsOneWidget);
    });

    testWidgets('absent far signature has no copy button', (tester) async {
      await pumpView(
        tester,
        PublicHighwaysViewModel(connections: [f3(inSignature: null)]),
      );
      expect(find.byKey(const Key('copy-far-signature')), findsNothing);
    });
  });

  group('U08 distinct empty and error surfaces', () {
    testWidgets('valid empty, filtered empty, and failures differ', (
      tester,
    ) async {
      await pumpView(
        tester,
        const PublicHighwaysViewModel(
          surface: PublicHighwaysSurface.validEmpty,
        ),
      );
      expect(
        find.text('No reported connections for this selection.'),
        findsOneWidget,
      );

      await pumpView(
        tester,
        const PublicHighwaysViewModel(
          surface: PublicHighwaysSurface.filteredEmpty,
        ),
      );
      expect(find.text('No connections match these filters.'), findsOneWidget);

      await pumpView(
        tester,
        const PublicHighwaysViewModel(
          surface: PublicHighwaysSurface.failedWithCache,
        ),
      );
      expect(
        find.textContaining(
          'Could not refresh connections. Showing cached observations.',
        ),
        findsOneWidget,
      );

      await pumpView(
        tester,
        const PublicHighwaysViewModel(
          surface: PublicHighwaysSurface.failedWithoutCache,
        ),
      );
      expect(find.text('Connections unavailable.'), findsOneWidget);
    });
  });

  group('U10 nearest entrance', () {
    testWidgets('separate counts, avoided hub excluded, no EVE write', (
      tester,
    ) async {
      final eveWrites = <int>[];
      final selected = <int>[];
      await pumpView(
        tester,
        PublicHighwaysViewModel(
          avoidLowsec: true,
          nearest: const [
            NearestEntranceOutcome(
              approachSystemId: kAlphaSystemId,
              hubSystemId: kTheraSystemId,
              gateJumps: 1,
              wormholeJumps: 1,
              found: true,
              summary: F8Fixtures.bToTSummary,
            ),
            NearestEntranceOutcome(
              approachSystemId: kAlphaSystemId,
              hubSystemId: kTurnurSystemId,
              gateJumps: 1,
              wormholeJumps: 1,
              found: true,
            ),
          ],
        ),
        onSelectFarSystem: selected.add,
        onEveWrite: eveWrites.add,
      );
      expect(find.text(F8Fixtures.bToTSummary), findsOneWidget);
      expect(find.textContaining('Turnur'), findsNothing);
      await tester.tap(find.byKey(const Key('route-to-entrance')));
      await tester.pump();
      expect(selected, [kAlphaSystemId]);
      expect(eveWrites, isEmpty);
    });
  });

  group('U02/U03/U18 responsive', () {
    testWidgets('320/600/1100/1440 and 200% text do not overflow', (
      tester,
    ) async {
      final model = PublicHighwaysViewModel(connections: [f3()]);
      for (final size in const [
        Size(320, 640),
        Size(600, 800),
        Size(1100, 800),
        Size(1440, 900),
      ]) {
        await pumpView(tester, model, size: size, textScale: 2);
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });
}

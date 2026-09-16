// X9 RED contracts for RoutePlannerView (U02, U10, U15–U18).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §6.4–§6.6:
// - raw system IDs; Calculate writes to EVE; Safe/ETA/ship-pass claims
// - missing stale-cache preference; one No-route copy; no Outdated
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';
import 'package:mimir/features/exploration/presentation/exploration_screen.dart';
import 'package:mimir/features/exploration/presentation/route_planner_view.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  const names = {
    F7Systems.a: 'Alpha',
    F7Systems.b: 'Bravo',
    F7Systems.t: 'Thera',
    F7Systems.z: 'Zulu',
  };

  RouteResult foundRoute({bool outdated = false}) {
    return RouteResult(
      outcome: RouteOutcome.found,
      gateJumps: 1,
      wormholeJumps: 2,
      riskSum: 3,
      maxRisk: EdgeRisk.high,
      outdated: outdated,
      calculatedAt: kExplorationT0,
      limitations: const ['Public feed is Stale'],
      steps: const [
        RouteStep(
          fromSystemId: F7Systems.a,
          toSystemId: F7Systems.b,
          edgeKey: 'g-101-102',
          kind: 'gate',
        ),
        RouteStep(
          fromSystemId: F7Systems.b,
          toSystemId: F7Systems.t,
          edgeKey: 'w01-fwd',
          kind: 'wormhole',
          fromSignature: 'ABC-123',
          fromTypeCode: 'K162',
        ),
        RouteStep(
          fromSystemId: F7Systems.t,
          toSystemId: F7Systems.z,
          edgeKey: 'tz-fwd',
          kind: 'wormhole',
          fromSignature: 'DEF-456',
          fromTypeCode: 'B274',
        ),
      ],
    );
  }

  Future<void> pumpView(
    WidgetTester tester,
    RoutePlannerViewModel model, {
    Size size = const Size(1440, 900),
    double textScale = 1,
    VoidCallback? onCalculate,
    VoidCallback? onCancel,
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
            body: RoutePlannerView(
              model: model,
              onCalculate: onCalculate,
              onCancel: onCancel,
              onEveWrite: onEveWrite,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  RoutePlannerViewModel base({
    RouteResult? result,
    bool calculating = false,
    OriginSelection origin = const ManualOrigin(F7Systems.a),
    List<String> excluded = const [],
  }) {
    return RoutePlannerViewModel(
      origin: origin,
      originName: 'Alpha',
      destinationSystemId: F7Systems.z,
      destinationName: 'Zulu',
      preferences: RoutePreferences.defaults,
      result: result,
      calculating: calculating,
      excludedReasons: excluded,
      systemNames: names,
      originObservedAt: kExplorationT0,
      sourceAgeLabel: 'Validated 4m ago',
    );
  }

  group('U10 origin and destination', () {
    testWidgets('ExplorationScreen Routes tab hosts RoutePlannerView', (
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
      await tester.tap(find.text('Routes').first);
      await tester.pump();
      expect(find.byType(RoutePlannerView), findsOneWidget);
    });

    testWidgets(
      'origin modes and named destination, never raw IDs or EVE write',
      (tester) async {
        final eveWrites = <int>[];
        await pumpView(
          tester,
          base(),
          onCalculate: () {},
          onEveWrite: eveWrites.add,
        );
        expect(find.textContaining('Use current location'), findsOneWidget);
        expect(find.textContaining('Use last known location'), findsOneWidget);
        expect(find.textContaining('Manual'), findsOneWidget);
        expect(find.textContaining('Alpha'), findsWidgets);
        expect(find.textContaining('Zulu'), findsWidgets);
        expect(find.textContaining('${F7Systems.a}'), findsNothing);
        expect(find.textContaining('${F7Systems.z}'), findsNothing);
        expect(find.textContaining('Item #'), findsNothing);
        await tester.tap(find.text('Calculate route'));
        await tester.pump();
        expect(eveWrites, isEmpty);
      },
    );
  });

  group('U15/U16 preferences, status, and steps', () {
    testWidgets('all six R23 preferences are present', (tester) async {
      await pumpView(tester, base());
      expect(find.widgetWithText(SwitchListTile, 'Avoid EOL'), findsOneWidget);
      expect(
        find.widgetWithText(SwitchListTile, 'Avoid Critical Mass'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Avoid Lowsec'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Avoid Nullsec'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Prefer Highsec'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SwitchListTile, 'Use stale cached connections'),
        findsOneWidget,
      );
    });

    testWidgets(
      'calculating shows progress and cancel; outdated stays visible',
      (tester) async {
        await pumpView(tester, base(calculating: true), onCancel: () {});
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await pumpView(tester, base(result: foundRoute(outdated: true)));
        expect(find.textContaining('Outdated'), findsOneWidget);
        expect(find.textContaining('Current route'), findsNothing);
        expect(find.textContaining('Avoid EOL'), findsWidgets);
        expect(find.textContaining('Validated 4m ago'), findsOneWidget);
        expect(find.textContaining('Bravo'), findsWidgets);
      },
    );

    testWidgets('steps are named with separate gate/wormhole counts', (
      tester,
    ) async {
      await pumpView(tester, base(result: foundRoute()));
      expect(find.textContaining('Alpha'), findsWidgets);
      expect(find.textContaining('Bravo'), findsWidgets);
      expect(find.textContaining('Thera'), findsWidgets);
      expect(find.textContaining('Zulu'), findsWidgets);
      expect(find.textContaining('1 gate'), findsOneWidget);
      expect(find.textContaining('2 wormhole'), findsOneWidget);
      expect(find.textContaining('3 jumps'), findsOneWidget);
      expect(find.textContaining('ABC-123'), findsOneWidget);
      expect(find.textContaining('K162'), findsOneWidget);
      expect(find.textContaining('${F7Systems.a}'), findsNothing);
    });

    testWidgets('risk has no Safe, ETA, or ship-pass promise', (tester) async {
      await pumpView(tester, base(result: foundRoute()));
      expect(find.text('High'), findsOneWidget);
      expect(find.textContaining('Safe'), findsNothing);
      expect(find.textContaining('ETA'), findsNothing);
      expect(find.textContaining('Ship can pass'), findsNothing);
    });
  });

  group('U17 excluded edges and distinct no-route states', () {
    testWidgets('excluded reasons stay visible', (tester) async {
      await pumpView(
        tester,
        base(
          result: foundRoute(),
          excluded: const ['EOL B→Thera excluded by Avoid EOL'],
        ),
      );
      expect(
        find.textContaining('EOL B→Thera excluded by Avoid EOL'),
        findsOneWidget,
      );
    });

    testWidgets('three R26 no-route states are distinct', (tester) async {
      await pumpView(
        tester,
        base(
          result: const RouteResult(
            outcome: RouteOutcome.noRouteUnderPreferences,
          ),
        ),
      );
      expect(find.text('No route under these preferences'), findsOneWidget);

      await pumpView(
        tester,
        base(result: const RouteResult(outcome: RouteOutcome.noRouteInGraph)),
      );
      expect(
        find.text('No route in the available connection graph'),
        findsOneWidget,
      );

      await pumpView(
        tester,
        base(result: const RouteResult(outcome: RouteOutcome.dataUnavailable)),
      );
      expect(find.text('Route data unavailable'), findsOneWidget);
    });
  });

  group('U02/U18 responsive', () {
    testWidgets('320/600/1100/1440 and 200% text do not overflow', (
      tester,
    ) async {
      for (final size in const [
        Size(320, 640),
        Size(600, 800),
        Size(1100, 800),
        Size(1440, 900),
      ]) {
        await pumpView(
          tester,
          base(result: foundRoute()),
          size: size,
          textScale: 2,
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });
}

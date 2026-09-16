// X8 RED contracts for WormholeDatabaseView (U02–U05, U18).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §6.2–§6.4:
// - search/filters do not apply; Types/Systems switch is missing
// - lifetime shown as minutes; K162 zeros; C729 has no Varies
// - Thera/Pochven leak Nullsec; modifiers lack signs; Live status
// - 320px/200% filter chips overflow; raw Item # IDs
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/presentation/exploration_screen.dart';
import 'package:mimir/features/exploration/presentation/wormhole_database_view.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  Future<void> pumpView(
    WidgetTester tester,
    WormholeDatabaseViewModel model, {
    Size size = const Size(1440, 900),
    double textScale = 1,
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
          home: Scaffold(body: WormholeDatabaseView(model: model)),
        ),
      ),
    );
    await tester.pump();
  }

  WormholeDatabaseViewModel f1Model() {
    return WormholeDatabaseViewModel(
      types: [
        F1Fixtures.b274,
        F1Fixtures.k162,
        F1Fixtures.i078,
        F1Fixtures.q001,
        F1Fixtures.q002,
      ],
      groups: [
        WormholeCodeGroup.fromVariants([
          F1Fixtures.typeFromRaw(F1Fixtures.c729V1Raw()),
          F1Fixtures.typeFromRaw(F1Fixtures.c729V2ConflictRaw()),
        ]),
      ],
      selectedType: F1Fixtures.b274,
      statusVersion: 'schema 7',
    );
  }

  group('U04 WormholeDatabaseView types', () {
    testWidgets('ExplorationScreen tab 0 hosts WormholeDatabaseView', (
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
      expect(find.byType(WormholeDatabaseView), findsOneWidget);
    });

    testWidgets('search and capital filter hide non-matches', (tester) async {
      await pumpView(tester, f1Model());
      await tester.enterText(find.byType(TextField), ' b274 ');
      await tester.pump();
      expect(find.text('B274'), findsWidgets);
      expect(find.text('Q001'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Capital'));
      await tester.pump();
      expect(find.text('Q001'), findsWidgets);
      expect(find.text('Q002'), findsNothing);
    });

    testWidgets('B274 detail uses seconds, kg, and regen per cycle', (
      tester,
    ) async {
      await pumpView(tester, f1Model());
      expect(find.textContaining('86400'), findsOneWidget);
      expect(find.textContaining('2000000000'), findsOneWidget);
      expect(find.textContaining('375000000'), findsOneWidget);
      expect(find.textContaining('kg/cycle'), findsOneWidget);
      expect(find.textContaining('1440'), findsNothing);
      expect(find.textContaining('Item #'), findsNothing);
      expect(find.textContaining('$kB274TypeId'), findsNothing);
    });

    testWidgets('K162 unknowns stay Unknown, never zero', (tester) async {
      await pumpView(
        tester,
        WormholeDatabaseViewModel(
          types: [F1Fixtures.k162],
          selectedType: F1Fixtures.k162,
        ),
      );
      expect(find.text('Unknown'), findsWidgets);
      expect(find.textContaining('0 kg'), findsNothing);
      expect(find.textContaining('0m'), findsNothing);
    });

    testWidgets('C729 jump disagreement is Varies', (tester) async {
      await pumpView(tester, f1Model());
      expect(find.textContaining('Varies'), findsOneWidget);
    });
  });

  group('U05 WormholeDatabaseView systems', () {
    testWidgets('Thera and Pochven are not Nullsec', (tester) async {
      await pumpView(
        tester,
        WormholeDatabaseViewModel(
          systems: [F2Fixtures.thera(), F2Fixtures.pochven()],
          selectedSystem: F2Fixtures.thera(),
        ),
      );
      await tester.tap(find.text('Systems'));
      await tester.pump();
      expect(find.textContaining('Thera'), findsWidgets);
      expect(find.textContaining('Nullsec'), findsNothing);
      expect(find.textContaining('$kTheraSystemId'), findsNothing);
    });

    testWidgets('effect modifiers include signs and scopes', (tester) async {
      await pumpView(
        tester,
        WormholeDatabaseViewModel(
          selectedSystem: F2Fixtures.j005926(),
          selectedEffect: SystemEffect(
            family: EffectFamily.redGiant,
            strength: 1,
            beaconTypeId: 30848,
            modifiers: const [
              EffectModifier(
                attributeId: 1,
                label: 'Heat damage',
                percentChange: 15,
                scope: 'local ships',
              ),
            ],
          ),
        ),
      );
      expect(find.textContaining('+15'), findsOneWidget);
      expect(find.textContaining('local ships'), findsOneWidget);
    });

    testWidgets('statics keep honest source attribution', (tester) async {
      await pumpView(
        tester,
        WormholeDatabaseViewModel(
          selectedSystem: SystemReference(
            systemId: kAlphaSystemId,
            name: 'Alpha',
            constellationName: 'Alpha Constellation',
            regionName: 'Fixture Region',
            statics: const [
              StaticAssignment(
                systemId: kAlphaSystemId,
                code: 'K162',
                source: 'system assignment',
                meaning: 'verified static',
              ),
            ],
          ),
        ),
      );
      expect(find.textContaining('Alpha Constellation'), findsOneWidget);
      expect(find.textContaining('system assignment'), findsOneWidget);
    });

    testWidgets('reference status is installed version, not Live', (
      tester,
    ) async {
      await pumpView(tester, f1Model());
      expect(find.byKey(const Key('reference-status-strip')), findsOneWidget);
      expect(find.textContaining('schema 7'), findsOneWidget);
      expect(find.textContaining('Live'), findsNothing);
    });
  });

  group('U02/U18 responsive and offline', () {
    testWidgets('320/600/1100/1440 and 200% text do not overflow', (
      tester,
    ) async {
      for (final size in const [
        Size(320, 640),
        Size(600, 800),
        Size(1100, 800),
        Size(1440, 900),
      ]) {
        await pumpView(tester, f1Model(), size: size, textScale: 2);
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });

    testWidgets('1100 usable width shows a master-detail pane', (tester) async {
      await pumpView(tester, f1Model(), size: const Size(1100, 800));
      expect(
        find.byKey(const Key('exploration-database-detail-pane')),
        findsOneWidget,
      );
    });
  });
}

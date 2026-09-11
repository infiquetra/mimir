import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/theme/eve_colors.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/fitting/presentation/fitting_providers.dart';
import 'package:mimir/features/fitting/presentation/widgets/stats_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Fitting thanatosFit() => const Fitting(
    id: 'thanatos',
    name: 'Thanatos',
    shipTypeId: 23911,
    shipName: 'Thanatos',
    fighters: [
      FighterGroup(typeId: 23059, typeName: 'Firbolg I', quantity: 18),
    ],
  );

  Fitting tristanFit() => const Fitting(
    id: 'tristan',
    name: 'Tristan',
    shipTypeId: 593,
    shipName: 'Tristan',
    drones: [DroneGroup(typeId: 2488, typeName: 'Warrior II', quantity: 5)],
  );

  Future<void> pumpPanel(
    WidgetTester tester, {
    required Fitting fitting,
    required FittingStats stats,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fittingStatsProvider.overrideWithValue(AsyncValue.data(stats)),
          activeFittingProvider.overrideWith(
            () => _FixedFittingController(fitting),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, height: 2000, child: StatsPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'T2.24 FIGHTERS section renders tubes, bay, per-class and fighter DPS',
    (tester) async {
      await pumpPanel(
        tester,
        fitting: thanatosFit(),
        stats: FittingStats(
          dpsTotal: 405,
          dpsFighters: 405,
          fighterTubesUsed: 3,
          fighterTubesMax: 4,
          fighterBayUsed: 18000,
          fighterBayMax: 75000,
          fighterLightUsed: 3,
          fighterLightMax: 3,
          fighterSquadrons: const [
            FighterSquadronStats(
              typeId: 23059,
              typeName: 'Firbolg I',
              squadronSize: 6,
              squadrons: 3,
              activeSquadrons: 3,
              abilities: [FighterAbilityKind.attack],
              activeAbility: FighterAbilityKind.attack,
              dps: 405,
            ),
          ],
        ),
      );

      expect(find.text('FIGHTERS'), findsOneWidget);
      expect(find.text('Tubes'), findsOneWidget);
      expect(find.textContaining('3/4'), findsWidgets);
      expect(find.text('Bay'), findsOneWidget);
      expect(find.textContaining('18000/75000'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.textContaining('3/3'), findsWidgets);
      expect(find.text('Fighters'), findsOneWidget);
      expect(find.text('405.0'), findsWidgets);
    },
  );

  testWidgets(
    'T2.24 bay over-capacity uses EveColors.error and Tristan has no FIGHTERS',
    (tester) async {
      await pumpPanel(
        tester,
        fitting: thanatosFit(),
        stats: const FittingStats(
          dpsFighters: 405,
          fighterTubesUsed: 3,
          fighterTubesMax: 4,
          fighterBayUsed: 18000,
          fighterBayMax: 10000,
          fighterLightUsed: 3,
          fighterLightMax: 3,
        ),
      );

      expect(find.text('FIGHTERS'), findsOneWidget);
      final bayValue = find.textContaining('18000/10000');
      expect(bayValue, findsOneWidget);
      final bayText = tester.widget<Text>(bayValue);
      expect(bayText.style?.color, EveColors.error);

      await pumpPanel(
        tester,
        fitting: tristanFit(),
        stats: const FittingStats(
          dpsTotal: 25,
          dpsDrones: 25,
          droneBandwidthUsed: 25,
          droneBandwidthMax: 25,
          droneBayUsed: 25,
          droneBayMax: 40,
        ),
      );

      expect(find.text('DRONES'), findsOneWidget);
      expect(find.text('FIGHTERS'), findsNothing);
    },
  );
}

class _FixedFittingController extends FittingController {
  _FixedFittingController(this._fitting);
  final Fitting _fitting;

  @override
  Fitting? build() => _fitting;
}

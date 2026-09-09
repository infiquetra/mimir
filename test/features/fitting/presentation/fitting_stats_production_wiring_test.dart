import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/fitting/domain/dogma_attributes.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/fitting/presentation/fitting_providers.dart';
import 'package:mimir/features/fitting/presentation/widgets/stats_panel.dart';

/// Regression lock for the production wiring of fitting stats.
///
/// Unit tests build ModuleType/ShipType fixtures by hand, which is how the
/// dead `effects` mapping (getModuleType never populated it, so no module
/// bonus ever applied in the app) stayed green for so long. This test walks
/// the real chain instead: bundled SDE asset -> Drift seed -> SdeService ->
/// fittingStatsProvider -> DogmaEngine -> StatsPanel, using real type data
/// for a Tristan fit with a loaded autocannon, a drone bay and a fitted
/// Drone Damage Amplifier II.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rifter = 587;
  const tristan = 593; // drone frigate: 25 MBit bandwidth, 40 m3 bay
  const autocannon = 484; // 125mm Gatling AutoCannon I
  const protonS = 180;
  const warriorII = 2488;
  const ddaII = 4405;
  const typeIds = [rifter, tristan, autocannon, protonS, warriorII, ddaII];

  late Map<int, Map<String, dynamic>> bundledTypes;

  Map<int, double> attrsOf(int typeId) => {
    for (final a in (bundledTypes[typeId]!['dogmaAttributes'] as List).map(
      (a) => a as Map<String, dynamic>,
    ))
      a['attributeId'] as int: (a['value'] as num).toDouble(),
  };

  setUpAll(() {
    final dogma =
        json.decode(File('assets/sde/dogma.json').readAsStringSync())
            as Map<String, dynamic>;
    bundledTypes = {
      for (final t in (dogma['types'] as List).map(
        (t) => t as Map<String, dynamic>,
      ))
        t['typeId'] as int: t,
    };
  });

  testWidgets(
    'StatsPanel shows real offense and drone rows through production wiring',
    (tester) async {
      final database = SdeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      // Drift's memory database answers from a real isolate, which the
      // widget-test fake async zone never pumps; real async belongs in
      // runAsync blocks.
      final service = (await tester.runAsync(() async {
        await database.upsertCategories([
          SdeCategoriesCompanion.insert(
            categoryId: const Value(6),
            categoryName: 'Ship',
          ),
          SdeCategoriesCompanion.insert(
            categoryId: const Value(7),
            categoryName: 'Module',
          ),
          SdeCategoriesCompanion.insert(
            categoryId: const Value(8),
            categoryName: 'Charge',
          ),
          SdeCategoriesCompanion.insert(
            categoryId: const Value(18),
            categoryName: 'Drone',
          ),
        ]);
        await database.upsertGroups([
          for (final id in typeIds)
            SdeGroupsCompanion.insert(
              groupId: Value(bundledTypes[id]!['groupId'] as int),
              groupName: 'group $id',
              categoryId: 6,
            ),
        ]);
        await database.upsertTypes([
          for (final id in typeIds)
            SdeTypesCompanion.insert(
              typeId: Value(id),
              typeName: bundledTypes[id]!['typeName'] as String,
              groupId: bundledTypes[id]!['groupId'] as int,
            ),
        ]);
        await database.upsertTypeAttributes([
          for (final id in typeIds)
            for (final attr
                in (bundledTypes[id]!['dogmaAttributes'] as List).map(
                  (a) => a as Map<String, dynamic>,
                ))
              SdeTypeAttributesCompanion.insert(
                typeId: id,
                attributeId: attr['attributeId'] as int,
                value: (attr['value'] as num).toDouble(),
              ),
        ]);
        await database.upsertTypeEffects([
          for (final id in typeIds)
            for (final effect
                in (bundledTypes[id]!['dogmaEffects'] as List).map(
                  (e) => e as Map<String, dynamic>,
                ))
              SdeTypeEffectsCompanion.insert(
                typeId: id,
                effectId: effect['effectId'] as int,
                isDefault: const Value(false),
              ),
        ]);
        // Satisfies the industry seeding gate so initialize() skips the full
        // asset import but still loads the bundled effect modifiers.
        await database.upsertIndustryActivities([
          SdeIndustryActivitiesCompanion.insert(
            typeId: rifter,
            activityId: 1,
            time: 1,
          ),
        ]);

        final service = SdeService(database: database);
        await service.initialize();
        return service;
      }))!;

      final fitting = Fitting(
        id: 'prod-wiring',
        name: 'Production wiring fit',
        shipTypeId: tristan,
        shipName: 'Tristan',
        highSlots: [
          FittedModule(
            typeId: autocannon,
            typeName: '125mm Gatling AutoCannon I',
            slotType: SlotType.high,
            slotIndex: 0,
            chargeTypeId: protonS,
            chargeName: 'Proton S',
          ),
        ],
        lowSlots: [
          FittedModule(
            typeId: ddaII,
            typeName: 'Drone Damage Amplifier II',
            slotType: SlotType.low,
            slotIndex: 0,
          ),
        ],
        drones: [
          DroneGroup(
            typeId: warriorII,
            typeName: 'Warrior II',
            quantity: 5,
            inBay: 5,
          ),
        ],
      );

      // Resolve the real provider chain (activeFitting -> ship type ->
      // module/charge/drone types -> bundled modifiers -> engine) in real
      // async: Drift answers from a background isolate, whose port replies
      // the widget-test fake async zone would never deliver.
      final stats = (await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            // The stats provider reads the active character through the
            // real repository/ESI stack; an empty in-memory app database
            // yields "no active character" without platform plugins.
            databaseProvider.overrideWithValue(
              AppDatabase.forTesting(NativeDatabase.memory()),
            ),
            sdeServiceProvider.overrideWithValue(service),
            activeFittingProvider.overrideWith(
              () => _FixedFittingController(fitting),
            ),
          ],
        );
        addTearDown(container.dispose);
        return container.read(fittingStatsProvider.future);
      }))!;
      expect(stats, isNotNull);

      final turretAttrs = attrsOf(autocannon);
      final ammoAttrs = attrsOf(protonS);
      final droneAttrs = attrsOf(warriorII);
      final ddaAttrs = attrsOf(ddaII);

      // No active character in this wiring test, so racial bonuses are off;
      // the amp (module-owned, raw) must still apply — that is the mapping
      // the dead-`effects` bug killed.
      final gunVolley =
          DogmaAttributes.damageComponents
              .map((id) => ammoAttrs[id] ?? 0.0)
              .fold<double>(0, (a, b) => a + b) *
          turretAttrs[DogmaAttributes.turretDamageMultiplier]!;
      final gunDps =
          gunVolley / (turretAttrs[DogmaAttributes.rateOfFire]! / 1000);
      final droneVolley =
          DogmaAttributes.damageComponents
              .map((id) => droneAttrs[id] ?? 0.0)
              .fold<double>(0, (a, b) => a + b) *
          droneAttrs[DogmaAttributes.turretDamageMultiplier]! *
          (1 + ddaAttrs[1255]! / 100);
      final droneDps =
          5 * droneVolley / (droneAttrs[DogmaAttributes.rateOfFire]! / 1000);

      expect(stats.dpsGuns, closeTo(gunDps, 0.01));
      expect(stats.dpsDrones, closeTo(droneDps, 0.01));
      expect(stats.dpsTotal, closeTo(gunDps + droneDps, 0.01));
      expect(stats.volley, closeTo(gunVolley, 0.01));
      expect(stats.droneBandwidthUsed, 25.0);
      expect(stats.droneBayUsed, 25.0);
      // The turret's own falloff, unboosted: no active character means the
      // ship's racial bonus stays at skill level 0.
      expect(
        stats.falloffRange,
        closeTo(turretAttrs[DogmaAttributes.falloff]!, 0.01),
      );

      // The panel renders the sections and the computed numbers. The stats
      // list is taller than the default 800x600 test surface and the
      // ListView builds lazily, so grow the surface to lay out every row.
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

      expect(find.text('OFFENSE'), findsOneWidget);
      expect(find.text('DRONES'), findsOneWidget);
      expect(find.text('DPS'), findsOneWidget);
      expect(find.text((gunDps + droneDps).toStringAsFixed(1)), findsOneWidget);
      expect(find.text('Bandwidth'), findsOneWidget);
      expect(find.text('Bay'), findsOneWidget);
    },
  );
}

class _FixedFittingController extends FittingController {
  _FixedFittingController(this._fitting);
  final Fitting _fitting;

  @override
  Fitting? build() => _fitting;
}

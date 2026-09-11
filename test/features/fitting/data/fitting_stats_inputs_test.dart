import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/fitting/data/fitting_stats_inputs.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SdeDatabase database;
  late SdeService sdeService;

  setUp(() {
    database = SdeDatabase.forTesting(NativeDatabase.memory());
    sdeService = SdeService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedType({
    required int typeId,
    required String name,
    required int groupId,
    required int categoryId,
    required String groupName,
    Map<int, double> attributes = const {},
    List<int> effectIds = const [],
  }) async {
    await database.upsertCategories([
      SdeCategoriesCompanion.insert(
        categoryId: Value(categoryId),
        categoryName: 'Category $categoryId',
      ),
    ]);
    await database.upsertGroups([
      SdeGroupsCompanion.insert(
        groupId: Value(groupId),
        groupName: groupName,
        categoryId: categoryId,
      ),
    ]);
    await database.upsertTypes([
      SdeTypesCompanion.insert(
        typeId: Value(typeId),
        typeName: name,
        groupId: groupId,
      ),
    ]);
    if (attributes.isNotEmpty) {
      await database.upsertTypeAttributes([
        for (final entry in attributes.entries)
          SdeTypeAttributesCompanion.insert(
            typeId: typeId,
            attributeId: entry.key,
            value: entry.value,
          ),
      ]);
    }
    if (effectIds.isNotEmpty) {
      await database.upsertTypeEffects([
        for (final effectId in effectIds)
          SdeTypeEffectsCompanion.insert(
            typeId: typeId,
            effectId: effectId,
            isDefault: const Value(false),
          ),
      ]);
    }
  }

  group('getDogmaTypes field enrichment', () {
    test(
      'populates cpu, powergrid, calibration and slotType from attrs/effects',
      () async {
        await seedType(
          typeId: 3540,
          name: 'Large Armor Repairer II',
          groupId: 62,
          categoryId: 7,
          groupName: 'Armor Repairer',
          attributes: {50: 80.0, 30: 2100.0, 1153: 0.0},
          effectIds: const [11],
        );
        await seedType(
          typeId: 10850,
          name: 'Medium Shield Booster II',
          groupId: 40,
          categoryId: 7,
          groupName: 'Shield Booster',
          attributes: {50: 90.0, 30: 12.0},
          effectIds: const [13],
        );
        await seedType(
          typeId: 3831,
          name: 'Medium Shield Extender II',
          groupId: 38,
          categoryId: 7,
          groupName: 'Shield Extender',
          attributes: {50: 30.0, 30: 1.0},
          effectIds: const [13],
        );
        await seedType(
          typeId: 484,
          name: '125mm Gatling AutoCannon I',
          groupId: 55,
          categoryId: 7,
          groupName: 'Projectile Weapon',
          attributes: {50: 3.0, 30: 4.0},
          effectIds: const [12],
        );
        await seedType(
          typeId: 31716,
          name: 'Medium Core Defense Field Extender I',
          groupId: 781,
          categoryId: 7,
          groupName: 'Rig Shield',
          attributes: {50: 0.0, 30: 0.0, 1153: 150.0},
          effectIds: const [2663],
        );
        await seedType(
          typeId: 29984,
          name: 'Tengu Offensive - Accelerated Ejection Bay',
          groupId: 958,
          categoryId: 32,
          groupName: 'Offensive Subsystem',
          attributes: {50: 0.0, 30: 0.0},
          effectIds: const [3772],
        );

        final result = await sdeService.getDogmaTypes(const [
          3540,
          10850,
          3831,
          484,
          31716,
          29984,
        ]);

        expect(result[3540]!.slotType, SlotType.low);
        expect(result[3540]!.cpu, 80.0);
        expect(result[3540]!.powergrid, 2100.0);

        expect(result[10850]!.slotType, SlotType.med);
        expect(result[10850]!.cpu, greaterThan(0));
        expect(result[10850]!.powergrid, greaterThan(0));

        expect(result[3831]!.slotType, SlotType.med);
        expect(result[3831]!.cpu, greaterThan(0));

        expect(result[484]!.slotType, SlotType.high);
        expect(result[484]!.cpu, greaterThan(0));

        expect(result[31716]!.slotType, SlotType.rig);
        expect(result[31716]!.calibration, 150);

        expect(result[29984]!.slotType, SlotType.subsystem);
      },
    );
  });

  group('loadFittingStatsInputs contract', () {
    Future<void> seedRifterAndDc() async {
      await seedType(
        typeId: 587,
        name: 'Rifter',
        groupId: 25,
        categoryId: 6,
        groupName: 'Frigate',
        attributes: {14: 4.0, 13: 3.0, 12: 4.0, 1137: 3.0},
      );
      await seedType(
        typeId: 2048,
        name: 'Damage Control II',
        groupId: 60,
        categoryId: 7,
        groupName: 'Damage Control',
        attributes: {50: 30.0, 30: 1.0},
        effectIds: const [11],
      );
    }

    test('returns FittingStatsInputs for a resolvable Rifter fit', () async {
      await seedRifterAndDc();
      const fitting = Fitting(
        id: '1',
        name: 'Rifter DC',
        shipTypeId: 587,
        shipName: 'Rifter',
        lowSlots: [
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            slotType: SlotType.low,
            slotIndex: 0,
          ),
        ],
      );

      final inputs = await loadFittingStatsInputs(
        sdeService,
        fitting,
        skillTypeIds: const [],
      );

      expect(inputs, isNotNull);
      expect(inputs!.shipType.typeId, 587);
      expect(inputs.moduleTypes.containsKey('2048'), isTrue);
    });

    test('records typeIds missing from the SDE in unresolved', () async {
      await seedRifterAndDc();
      const fitting = Fitting(
        id: '2',
        name: 'Rifter mystery',
        shipTypeId: 587,
        shipName: 'Rifter',
        highSlots: [
          FittedModule(
            typeId: 999999,
            typeName: 'Mystery Gun',
            slotType: SlotType.high,
            slotIndex: 0,
          ),
        ],
        lowSlots: [
          FittedModule(
            typeId: 2048,
            typeName: 'Damage Control II',
            slotType: SlotType.low,
            slotIndex: 0,
          ),
        ],
      );

      final inputs = await loadFittingStatsInputs(
        sdeService,
        fitting,
        skillTypeIds: const [],
      );

      expect(inputs, isNotNull);
      expect(inputs!.unresolved.containsKey(999999), isTrue);
      expect(inputs.unresolved[999999], 'Mystery Gun');
      expect(inputs.unresolved.containsKey(2048), isFalse);
    });
  });
}

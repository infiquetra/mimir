import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SdeDatabase database;
  late SdeService sdeService;

  setUp(() {
    // Create an in-memory database for testing
    database = SdeDatabase.forTesting(NativeDatabase.memory());
    sdeService = SdeService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('SdeService Dogma Loading Tests', () {
    test('Loads bundled dogma data and parses ShipType correctly', () async {
      // 1. Arrange - seed the SDE tables with a minimal Rifter (typeId 587)
      //    plus its Minmatar Frigate prerequisite.
      //
      //    SdeService normally loads assets/sde/dogma.json through rootBundle,
      //    which a unit test cannot intercept. Inserting the rows that import
      //    would have produced keeps this test focused on getShipType's parsing
      //    rather than on asset loading.
      await database.upsertCategories([
        SdeCategoriesCompanion.insert(
          categoryId: const Value(6),
          categoryName: 'Ship',
        ),
      ]);
      await database.upsertGroups([
        SdeGroupsCompanion.insert(
          groupId: const Value(25),
          groupName: 'Frigate',
          categoryId: 6,
        ),
      ]);
      await database.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: const Value(587),
          typeName: 'Rifter',
          groupId: 25,
          description: const Value('A very fast frigate.'),
        ),
        SdeTypesCompanion.insert(
          typeId: const Value(3331),
          typeName: 'Minmatar Frigate',
          groupId: 255,
        ), // Mock skill
      ]);
      await database.upsertTypeAttributes([
        SdeTypeAttributesCompanion.insert(
          typeId: 587,
          attributeId: 14,
          value: 4.0,
        ), // highSlots
        SdeTypeAttributesCompanion.insert(
          typeId: 587,
          attributeId: 13,
          value: 3.0,
        ), // medSlots
        SdeTypeAttributesCompanion.insert(
          typeId: 587,
          attributeId: 12,
          value: 4.0,
        ), // lowSlots
        SdeTypeAttributesCompanion.insert(
          typeId: 587,
          attributeId: 1137,
          value: 3.0,
        ), // rigSlots
        SdeTypeAttributesCompanion.insert(
          typeId: 587,
          attributeId: 102,
          value: 3.0,
        ), // turretSlots
        SdeTypeAttributesCompanion.insert(
          typeId: 587,
          attributeId: 101,
          value: 2.0,
        ), // launcherSlots
      ]);
      await database.upsertSkillRequirements([
        SdeSkillRequirementsCompanion.insert(
          skillId: 587,
          requiredSkillId: 3331,
          requiredLevel: 1,
        ),
      ]);

      // 2. Act
      final ship = await sdeService.getShipType(587);

      // 3. Assert
      expect(ship, isNotNull);
      expect(ship!.name, 'Rifter');
      expect(ship.groupName, 'Frigate');
      expect(ship.highSlots, 4);
      expect(ship.medSlots, 3);
      expect(ship.lowSlots, 4);
      expect(ship.rigSlots, 3);
      expect(ship.turretSlots, 3);
      expect(ship.launcherSlots, 2);

      expect(ship.skillRequirements.length, 1);
      expect(ship.skillRequirements.first.skillName, 'Minmatar Frigate');
      expect(ship.skillRequirements.first.requiredLevel, 1);
    });

    test('getModulesBySlotType returns valid ModuleType list', () async {
      // 1. Arrange
      await database.upsertCategories([
        SdeCategoriesCompanion.insert(
          categoryId: const Value(7),
          categoryName: 'Module',
        ),
      ]);
      await database.upsertGroups([
        SdeGroupsCompanion.insert(
          groupId: const Value(53),
          groupName: 'Energy Weapon',
          categoryId: 7,
        ),
      ]);
      await database.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: const Value(1234),
          typeName: 'Dual Light Pulse Laser I',
          groupId: 53,
        ),
      ]);
      await database.upsertTypeEffects([
        SdeTypeEffectsCompanion.insert(
          typeId: 1234,
          effectId: 12,
          isDefault: const Value(true),
        ), // effectId 12 = High Slot
      ]);
      await database.upsertTypeAttributes([
        SdeTypeAttributesCompanion.insert(
          typeId: 1234,
          attributeId: 50,
          value: 5.0,
        ), // CPU
        SdeTypeAttributesCompanion.insert(
          typeId: 1234,
          attributeId: 30,
          value: 2.0,
        ), // Powergrid
      ]);

      // 2. Act
      final modules = await sdeService.getModulesBySlotType(SlotType.high);

      // 3. Assert
      expect(modules.isNotEmpty, isTrue);
      final laser = modules.firstWhere((m) => m.typeId == 1234);
      expect(laser.name, 'Dual Light Pulse Laser I');
      expect(laser.groupName, 'Energy Weapon');
      expect(laser.slotType, SlotType.high);
      expect(laser.cpu, 5.0);
      expect(laser.powergrid, 2.0);
    });
  });
}

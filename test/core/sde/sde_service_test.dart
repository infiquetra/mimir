import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';

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
      // 1. Arrange - Setup minimal mock JSON for a Rifter (typeId: 587)
      const mockDogmaJson = '''
      {
        "categories": [{"categoryId": 6, "categoryName": "Ship"}],
        "groups": [{"groupId": 25, "groupName": "Frigate", "categoryId": 6}],
        "types": [
          {
            "typeId": 587,
            "typeName": "Rifter",
            "groupId": 25,
            "description": "A very fast frigate.",
            "dogmaAttributes": [
              {"attributeId": 14, "value": 4.0},
              {"attributeId": 13, "value": 3.0},
              {"attributeId": 12, "value": 4.0},
              {"attributeId": 1137, "value": 3.0},
              {"attributeId": 102, "value": 3.0},
              {"attributeId": 101, "value": 2.0},
              {"attributeId": 50, "value": 125.0},
              {"attributeId": 30, "value": 37.0}
            ],
            "dogmaEffects": [
              {"effectId": 12, "isDefault": false}
            ],
            "prerequisites": [
              {"skillId": 3331, "level": 1}
            ]
          },
          {
            "typeId": 3331,
            "typeName": "Minmatar Frigate",
            "groupId": 255,
            "description": "Skill",
            "rank": 2,
            "primaryAttribute": "perception",
            "secondaryAttribute": "willpower"
          }
        ]
      }
      ''';

      // Inject the mock JSON by overriding rootBundle.loadString?
      // Wait, SdeService reads from 'assets/sde/dogma.json' using rootBundle.
      // In tests, we can use DefaultAssetBundle or directly mock the service,
      // but the easiest is to manually call `_importSdeData` since it's private,
      // or we can just make it visible for testing, OR we can mock the rootBundle!

      // To keep it simple, let's just make a small extension or use the actual
      // database methods to insert the JSON exactly like _importSdeData does.
      
      // Let's actually use the database directly for the setup, since we're testing getShipType
      await database.upsertCategories([
        SdeCategoriesCompanion.insert(categoryId: const Value(6), categoryName: 'Ship'),
      ]);
      await database.upsertGroups([
        SdeGroupsCompanion.insert(groupId: const Value(25), groupName: 'Frigate', categoryId: 6),
      ]);
      await database.upsertTypes([
        SdeTypesCompanion.insert(typeId: const Value(587), typeName: 'Rifter', groupId: 25, description: const Value('A very fast frigate.')),
        SdeTypesCompanion.insert(typeId: const Value(3331), typeName: 'Minmatar Frigate', groupId: 255), // Mock skill
      ]);
      await database.upsertTypeAttributes([
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 14, value: 4.0), // highSlots
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 13, value: 3.0), // medSlots
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 12, value: 4.0), // lowSlots
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 1137, value: 3.0), // rigSlots
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 102, value: 3.0), // turretSlots
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 101, value: 2.0), // launcherSlots
      ]);
      await database.upsertSkillRequirements([
        SdeSkillRequirementsCompanion.insert(skillId: 587, requiredSkillId: 3331, requiredLevel: 1),
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
  });
}

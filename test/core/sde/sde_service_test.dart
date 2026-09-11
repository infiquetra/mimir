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

  group('SdeService bundled effect modifiers', () {
    test('initialize loads modifiers and types expose their effects', () async {
      // Seed one row per gated table so initialize() treats the database as
      // seeded and skips the full asset import, while the per-launch bundled
      // modifier asset still loads.
      await database.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: const Value(587),
          typeName: 'Rifter',
          groupId: 25,
        ),
      ]);
      await database.upsertTypeAttributes([
        SdeTypeAttributesCompanion.insert(
          typeId: 587,
          attributeId: 4,
          value: 1,
        ),
      ]);
      await database.upsertIndustryActivities([
        SdeIndustryActivitiesCompanion.insert(
          typeId: 587,
          activityId: 1,
          time: 1,
        ),
      ]);
      await database.upsertTypeEffects([
        SdeTypeEffectsCompanion.insert(
          typeId: 587,
          effectId: 5779,
          isDefault: const Value(false),
        ),
        SdeTypeEffectsCompanion.insert(
          typeId: 587,
          effectId: 7248,
          isDefault: const Value(false),
        ),
      ]);

      await sdeService.initialize();

      final ship = await sdeService.getShipType(587);
      expect(ship, isNotNull);
      expect(
        ship!.effects.map((effect) => effect.effectId),
        containsAll(<int>[5779, 7248]),
      );
      expect(
        ship.effects.firstWhere((effect) => effect.effectId == 5779).name,
        'shipBonusSPTFalloffMF2',
      );

      // Bundled modifiers need no network and carry the skill linkage the
      // engine needs for racial bonuses.
      final modifiers = await sdeService.ensureEffectModifiers([5779, 7248]);
      final falloff = modifiers[5779]!.single;
      expect(falloff.func, 'LocationRequiredSkillModifier');
      expect(falloff.operator, 6);
      expect(falloff.modifiedAttributeId, 158);
      expect(falloff.modifyingAttributeId, 587);
      expect(falloff.skillTypeId, 3302);
      final rof = modifiers[7248]!.single;
      expect(rof.modifiedAttributeId, 51);
      expect(rof.modifyingAttributeId, 460);
    });
  });

  group('SdeService dogma_version gate', () {
    Future<void> seedExistingInstall({
      int typeId = 1234,
      int? rank,
      String? primaryAttribute,
      String? secondaryAttribute,
    }) async {
      await database.upsertCategories([
        SdeCategoriesCompanion.insert(
          categoryId: const Value(7),
          categoryName: 'Module',
        ),
        SdeCategoriesCompanion.insert(
          categoryId: const Value(16),
          categoryName: 'Skill',
        ),
      ]);
      await database.upsertGroups([
        SdeGroupsCompanion.insert(
          groupId: const Value(53),
          groupName: 'Energy Weapon',
          categoryId: 7,
        ),
        SdeGroupsCompanion.insert(
          groupId: const Value(255),
          groupName: 'Gunnery',
          categoryId: 16,
        ),
      ]);
      await database.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: Value(typeId),
          typeName: 'Seeded type $typeId',
          groupId: typeId == 3310 ? 255 : 53,
          rank: rank != null ? Value(rank) : const Value.absent(),
          primaryAttribute: primaryAttribute != null
              ? Value(primaryAttribute)
              : const Value.absent(),
          secondaryAttribute: secondaryAttribute != null
              ? Value(secondaryAttribute)
              : const Value.absent(),
        ),
      ]);
      await database.upsertTypeAttributes([
        SdeTypeAttributesCompanion.insert(
          typeId: typeId,
          attributeId: 50,
          value: 5.0,
        ),
      ]);
      await database.upsertIndustryActivities([
        SdeIndustryActivitiesCompanion.insert(
          typeId: typeId,
          activityId: 1,
          time: 1,
        ),
      ]);
      await database.upsertTypeEffects([
        SdeTypeEffectsCompanion.insert(
          typeId: typeId,
          effectId: 12,
          isDefault: const Value(true),
        ),
      ]);
    }

    Future<int> typeCount() async {
      final rows = await database.select(database.sdeTypes).get();
      return rows.length;
    }

    test(
      'initialize writes dogma_version and skips re-import when it matches',
      () async {
        await seedExistingInstall();
        await database.setMetadata(
          'dogma_version',
          '${SdeService.bundledDogmaVersion}',
        );
        final before = await typeCount();

        await sdeService.initialize();

        expect(await typeCount(), before);
        expect(
          await database.getMetadata('dogma_version'),
          '${SdeService.bundledDogmaVersion}',
        );
      },
    );

    test(
      'initialize re-imports dogma when bundledDogmaVersion increments',
      () async {
        await seedExistingInstall();
        await database.setMetadata('dogma_version', '1');
        expect(SdeService.bundledDogmaVersion, greaterThan(1));

        await sdeService.initialize();

        expect(
          await database.getMetadata('dogma_version'),
          '${SdeService.bundledDogmaVersion}',
        );
        expect(
          await typeCount(),
          greaterThan(100),
          reason: 're-import must load bundled dogma.json on version mismatch',
        );
        final groups = await database.select(database.sdeGroups).get();
        expect(
          groups.map((g) => g.categoryId).toSet(),
          containsAll({16, 87}),
          reason:
              'U0 bundle must include skill (16) and fighter (87) categories',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'dogma re-import keeps rank and attributes on skills seeded from skills.json',
      () async {
        await seedExistingInstall(
          typeId: 3310,
          rank: 2,
          primaryAttribute: 'perception',
          secondaryAttribute: 'willpower',
        );
        await database.setMetadata('dogma_version', '1');

        await sdeService.initialize();

        expect(await sdeService.getSkillRank(3310), 2);
        final attrs = await sdeService.getSkillAttributes(3310);
        expect(attrs, isNotNull);
        expect(attrs!.primary, 'perception');
        expect(attrs.secondary, 'willpower');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('SdeService.getDogmaTypes', () {
    Future<void> seedDogmaType({
      required int typeId,
      required String name,
      required int groupId,
      required int categoryId,
      required String groupName,
      required Map<int, double> attributes,
      required List<int> effectIds,
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
      await database.upsertTypeAttributes([
        for (final entry in attributes.entries)
          SdeTypeAttributesCompanion.insert(
            typeId: typeId,
            attributeId: entry.key,
            value: entry.value,
          ),
      ]);
      await database.upsertTypeEffects([
        for (final effectId in effectIds)
          SdeTypeEffectsCompanion.insert(
            typeId: typeId,
            effectId: effectId,
            isDefault: const Value(false),
          ),
      ]);
      await database.upsertSkillRequirements([
        SdeSkillRequirementsCompanion.insert(
          skillId: typeId,
          requiredSkillId: 3300,
          requiredLevel: 1,
        ),
      ]);
    }

    test(
      'returns a map of ModuleType with attributes and effects in three batched queries',
      () async {
        final counter = _SelectCounter();
        await database.close();
        database = SdeDatabase.forTesting(
          NativeDatabase.memory().interceptWith(counter),
        );
        sdeService = SdeService(database: database);

        await seedDogmaType(
          typeId: 3310,
          name: 'Rapid Firing',
          groupId: 255,
          categoryId: 16,
          groupName: 'Gunnery',
          attributes: {293: -4.0, 280: 0.0},
          effectIds: const [582],
        );
        await seedDogmaType(
          typeId: 23055,
          name: 'Templar I',
          groupId: 1652,
          categoryId: 87,
          groupName: 'Light Fighter',
          attributes: {2215: 6.0, 2226: 1.0},
          effectIds: const [6465],
        );

        counter.reset();
        final result = await sdeService.getDogmaTypes(const [
          3310,
          23055,
          999999,
        ]);

        expect(result.keys, unorderedEquals([3310, 23055]));
        expect(result.containsKey(999999), isFalse);

        final rapidFiring = result[3310]!;
        expect(rapidFiring.name, 'Rapid Firing');
        expect(rapidFiring.baseAttributes[293], -4.0);
        expect(rapidFiring.baseAttributes[280], 0.0);
        expect(rapidFiring.effects.map((e) => e.effectId), [582]);
        expect(rapidFiring.skillRequirements, isEmpty);
        expect(rapidFiring.cpu, 0.0);
        expect(rapidFiring.powergrid, 0.0);
        expect(rapidFiring.calibration, 0);
        expect(rapidFiring.slotType, SlotType.high);

        final templar = result[23055]!;
        expect(templar.name, 'Templar I');
        expect(templar.baseAttributes[2215], 6.0);
        expect(templar.effects.map((e) => e.effectId), [6465]);
        expect(templar.skillRequirements, isEmpty);

        expect(counter.types, 1, reason: 'types must be one IN query');
        expect(
          counter.attributes,
          1,
          reason: 'attributes must be one IN query',
        );
        expect(counter.effects, 1, reason: 'effects must be one IN query');
        expect(
          counter.requirements,
          0,
          reason: 'getDogmaTypes must not resolve prerequisite names',
        );
      },
    );

    test('getDogmaTypes chunks IN lists at 500 ids', () async {
      final counter = _SelectCounter();
      await database.close();
      database = SdeDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter),
      );
      sdeService = SdeService(database: database);

      await database.upsertCategories([
        SdeCategoriesCompanion.insert(
          categoryId: const Value(16),
          categoryName: 'Skill',
        ),
      ]);
      await database.upsertGroups([
        SdeGroupsCompanion.insert(
          groupId: const Value(255),
          groupName: 'Gunnery',
          categoryId: 16,
        ),
      ]);
      await database.upsertTypes([
        for (var id = 1; id <= 501; id++)
          SdeTypesCompanion.insert(
            typeId: Value(id),
            typeName: 'Type $id',
            groupId: 255,
          ),
      ]);
      await database.upsertTypeAttributes([
        for (var id = 1; id <= 501; id++)
          SdeTypeAttributesCompanion.insert(
            typeId: id,
            attributeId: 280,
            value: 0.0,
          ),
      ]);
      await database.upsertTypeEffects([
        for (var id = 1; id <= 501; id++)
          SdeTypeEffectsCompanion.insert(
            typeId: id,
            effectId: 414,
            isDefault: const Value(false),
          ),
      ]);

      counter.reset();
      final result = await sdeService.getDogmaTypes(
        List<int>.generate(501, (i) => i + 1),
      );

      expect(result.length, 501);
      expect(counter.types, 2);
      expect(counter.attributes, 2);
      expect(counter.effects, 2);
    });

    test('getDogmaTypes returns an empty map for an empty id list', () async {
      final result = await sdeService.getDogmaTypes(const []);
      expect(result, isEmpty);
    });
  });

  group('SdeService.getModulesBySlotType excludes skills and fighters', () {
    test('category 16 skills and category 87 fighters never appear', () async {
      await database.upsertCategories([
        SdeCategoriesCompanion.insert(
          categoryId: const Value(7),
          categoryName: 'Module',
        ),
        SdeCategoriesCompanion.insert(
          categoryId: const Value(16),
          categoryName: 'Skill',
        ),
        SdeCategoriesCompanion.insert(
          categoryId: const Value(87),
          categoryName: 'Fighter',
        ),
      ]);
      await database.upsertGroups([
        SdeGroupsCompanion.insert(
          groupId: const Value(53),
          groupName: 'Projectile Weapon',
          categoryId: 7,
        ),
        SdeGroupsCompanion.insert(
          groupId: const Value(255),
          groupName: 'Gunnery',
          categoryId: 16,
        ),
        SdeGroupsCompanion.insert(
          groupId: const Value(1652),
          groupName: 'Light Fighter',
          categoryId: 87,
        ),
      ]);
      await database.upsertTypes([
        SdeTypesCompanion.insert(
          typeId: const Value(561),
          typeName: '125mm Gatling AutoCannon I',
          groupId: 53,
        ),
        SdeTypesCompanion.insert(
          typeId: const Value(3310),
          typeName: 'Rapid Firing',
          groupId: 255,
        ),
        SdeTypesCompanion.insert(
          typeId: const Value(23055),
          typeName: 'Templar I',
          groupId: 1652,
        ),
      ]);
      await database.upsertTypeEffects([
        SdeTypeEffectsCompanion.insert(
          typeId: 561,
          effectId: 12,
          isDefault: const Value(true),
        ),
        // Skills and fighters carry non-slot effects only.
        SdeTypeEffectsCompanion.insert(
          typeId: 3310,
          effectId: 582,
          isDefault: const Value(false),
        ),
        SdeTypeEffectsCompanion.insert(
          typeId: 23055,
          effectId: 6465,
          isDefault: const Value(false),
        ),
      ]);
      await database.upsertTypeAttributes([
        SdeTypeAttributesCompanion.insert(
          typeId: 561,
          attributeId: 50,
          value: 5.0,
        ),
      ]);

      for (final slot in SlotType.values) {
        final modules = await sdeService.getModulesBySlotType(slot);
        expect(
          modules.map((m) => m.typeId),
          isNot(contains(3310)),
          reason: 'skill 3310 must not appear in $slot',
        );
        expect(
          modules.map((m) => m.typeId),
          isNot(contains(23055)),
          reason: 'fighter 23055 must not appear in $slot',
        );
      }

      final highs = await sdeService.getModulesBySlotType(SlotType.high);
      expect(highs.map((m) => m.typeId), contains(561));
    });
  });
}

/// Counts Drift SELECTs by table so getDogmaTypes can lock the 3-query batch.
class _SelectCounter extends QueryInterceptor {
  int types = 0;
  int attributes = 0;
  int effects = 0;
  int requirements = 0;

  void reset() {
    types = 0;
    attributes = 0;
    effects = 0;
    requirements = 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    final sql = statement.toLowerCase();
    if (sql.contains('sde_skill_requirements')) {
      requirements++;
    } else if (sql.contains('sde_type_attributes')) {
      attributes++;
    } else if (sql.contains('sde_type_effects')) {
      effects++;
    } else if (sql.contains('sde_types')) {
      types++;
    }
    return super.runSelect(executor, statement, args);
  }
}

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';

void main() {
  late SdeDatabase database;

  setUp(() async {
    database = SdeDatabase.forTesting(NativeDatabase.memory());

    await database.batch((batch) {
      batch.insertAll(database.sdeCategories, [
        SdeCategoriesCompanion.insert(categoryId: const drift.Value(16), categoryName: 'Skill'),
        SdeCategoriesCompanion.insert(categoryId: const drift.Value(6), categoryName: 'Ship'),
      ]);
      batch.insertAll(database.sdeGroups, [
        SdeGroupsCompanion.insert(
          groupId: const drift.Value(255),
          groupName: 'Gunnery',
          categoryId: 16,
        ),
        SdeGroupsCompanion.insert(
          groupId: const drift.Value(25),
          groupName: 'Frigate',
          categoryId: 6,
        ),
      ]);
      batch.insertAll(database.sdeTypes, [
        SdeTypesCompanion.insert(
          typeId: const drift.Value(3301),
          typeName: 'Gunnery',
          groupId: 255,
        ),
        SdeTypesCompanion.insert(
          typeId: const drift.Value(587),
          typeName: 'Rifter',
          groupId: 25,
        ),
      ]);
      batch.insertAll(database.sdeSkillRequirements, [
        SdeSkillRequirementsCompanion.insert(
          skillId: 3301,
          requiredSkillId: 3300,
          requiredLevel: 1,
        ),
      ]);
      // Dogma and industry rows for the SHIP type: exactly the data the old
      // clearAll()-based update destroyed.
      batch.insertAll(database.sdeTypeAttributes, [
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 14, value: 4.0),
        SdeTypeAttributesCompanion.insert(typeId: 587, attributeId: 13, value: 3.0),
      ]);
      batch.insertAll(database.sdeTypeEffects, [
        SdeTypeEffectsCompanion.insert(
          typeId: 587,
          effectId: 12,
          isDefault: const drift.Value(false),
        ),
      ]);
      batch.insertAll(database.sdeIndustryActivities, [
        SdeIndustryActivitiesCompanion.insert(typeId: 587, activityId: 1, time: 1200),
      ]);
    });
  });

  tearDown(() async {
    await database.close();
  });

  group('deleteSkillSlice', () {
    test('removes skill types and their prerequisites', () async {
      await database.deleteSkillSlice(
        skillGroupIds: [255],
        skillTypeIds: [3301],
      );

      final remainingTypes = await database.searchTypesByName('');
      expect(
        remainingTypes.map((t) => t.typeId),
        [587],
        reason: 'only the skill type should be gone',
      );

      final remainingRequirements =
          await database.getSkillPrerequisites(3301);
      expect(remainingRequirements, isEmpty);
    });

    test('leaves dogma attributes, effects and industry data untouched', () async {
      await database.deleteSkillSlice(
        skillGroupIds: [255],
        skillTypeIds: [3301],
      );

      final attributes = await database.getTypeAttributes(587);
      expect(attributes, hasLength(2));

      final effects = await database.getTypeEffects(587);
      expect(effects, hasLength(1));

      expect(
        await database.hasIndustryData(),
        isTrue,
        reason:
            'a skills-only update must never empty the industry tables; '
            'doing so broke Ship Fitting and Industry until restart',
      );
      expect(await database.hasDogmaData(), isTrue);
    });

    test('is a no-op for empty id lists', () async {
      await database.deleteSkillSlice(skillGroupIds: [], skillTypeIds: []);

      final remainingTypes = await database.searchTypesByName('');
      expect(remainingTypes, hasLength(2));
    });
  });
}

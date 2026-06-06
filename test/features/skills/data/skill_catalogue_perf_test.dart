import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart' hide skillGroupsProvider;
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/skills/data/skill_repository.dart';
import 'package:mimir/features/skills/data/skill_catalogue_providers.dart';
import 'package:mockito/mockito.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:drift/native.dart';

class FakeSkillRepository implements SkillRepository {
  List<CharacterSkill> skillsToReturn = [];

  @override
  Future<List<CharacterSkill>> getCharacterSkills(int characterId) async {
    print('FakeSkillRepository.getCharacterSkills called for $characterId');
    return skillsToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Skill Catalogue Performance', () {
    late AppDatabase appDb;
    late SdeDatabase sdeDb;
    late FakeSkillRepository mockRepo;
    late ProviderContainer container;

    setUp(() async {
      appDb = AppDatabase.forTesting(NativeDatabase.memory());
      sdeDb = SdeDatabase.forTesting(NativeDatabase.memory());
      mockRepo = FakeSkillRepository();

      // Seed SDE Database with test data
      final groups = List.generate(
        50,
        (i) => SdeGroupsCompanion.insert(
          groupId: Value(i),
          groupName: 'Group $i',
          categoryId: 16,
        ),
      );

      final sdeTypes = List.generate(
        2000,
        (i) => SdeTypesCompanion.insert(
          typeId: Value(i),
          typeName: 'Skill $i',
          groupId: i % 50,
        ),
      ).cast<SdeTypesCompanion>();

      await sdeDb.batch((batch) {
        batch.insertAll(sdeDb.sdeGroups, groups);
        batch.insertAll(sdeDb.sdeTypes, sdeTypes);
        // Add dummy dogma data to bypass expensive _loadBundledDogma during tests
        batch.insertAll(sdeDb.sdeTypeAttributes, [
          SdeTypeAttributesCompanion.insert(
            typeId: 1,
            attributeId: 1,
            value: 1.0,
          ),
        ]);
      });
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    test(
      'skillGroupsWithProgressProvider calculates quickly without pulling all skills to Dart memory',
      () async {
        // Mock 200 trained skills out of 2000
        final characterSkills = List.generate(
          200,
          (i) => CharacterSkill(
            id: i,
            characterId: 1,
            skillId: i * 10,
            trainedSkillLevel: i % 5 + 1,
            activeSkillLevel: i % 5 + 1,
            skillpointsInSkill: 1000,
            lastUpdated: DateTime.now(),
          ),
        ).cast<CharacterSkill>();

        mockRepo.skillsToReturn = characterSkills;

        // We use the overridden activeCharacterProvider now, no need to insert

        final testContainer = ProviderContainer(
          overrides: [
            sdeDatabaseProvider.overrideWithValue(sdeDb),
            databaseProvider.overrideWithValue(appDb),
            skillRepositoryProvider.overrideWithValue(mockRepo),
            activeCharacterProvider.overrideWith(
              (ref) => Stream.value(
                Character(
                  characterId: 1,
                  name: 'Test',
                  corporationId: 1,
                  corporationName: 'Test Corp',
                  portraitUrl: '',
                  tokenExpiry: DateTime.now(),
                  lastUpdated: DateTime.now(),
                  isActive: true,
                  securityStatus: 5.0,
                ),
              ),
            ),
          ],
        );

        // Keep providers alive during the test to prevent Riverpod from aborting their futures
        final charSub = testContainer.listen(
          activeCharacterProvider,
          (_, __) {},
        );
        final groupsSub = testContainer.listen(skillGroupsProvider, (_, __) {});
        final progressSub = testContainer.listen(
          skillGroupsWithProgressProvider,
          (_, __) {},
        );

        print('Pre-warming skillGroupsProvider...');
        await testContainer.read(skillGroupsProvider.future);
        print('Pre-warmed skillGroupsProvider');

        // Wait for active character to be emitted from DB
        await testContainer.read(activeCharacterProvider.future);
        print('Pre-warmed activeCharacterProvider');

        print(
          'Starting stopwatch and reading skillGroupsWithProgressProvider...',
        );
        final stopwatch = Stopwatch()..start();

        // Read the future
        final result = await testContainer.read(
          skillGroupsWithProgressProvider.future,
        );
        stopwatch.stop();
        print(
          'Calculated ${result.length} groups in ${stopwatch.elapsedMilliseconds}ms',
        );

        charSub.close();
        groupsSub.close();
        progressSub.close();

        // Ensure we got 50 groups
        expect(result.length, 50);

        // Check execution time is fast (in an actual device it will be fast, in tests CI it might be up to a few ms)
        // Since it's doing two small SQL queries and mapping ~200 items, it should take less than 2000ms.
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason: 'Calculations should be pushed to SQLite to run under 2000ms',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}

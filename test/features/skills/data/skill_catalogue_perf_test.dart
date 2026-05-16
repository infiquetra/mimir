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
import 'package:drift/native.dart';

class FakeSkillRepository implements SkillRepository {
  List<CharacterSkill> skillsToReturn = [];
  
  @override
  Future<List<CharacterSkill>> getCharacterSkills(int characterId) async {
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
      final groups = List.generate(50, (i) => SdeGroupsCompanion.insert(
        groupId: Value(i),
        groupName: 'Group $i',
        categoryId: 16,
      ));
      await sdeDb.upsertGroups(groups);

      final types = List.generate(2000, (i) => SdeTypesCompanion.insert(
        typeId: Value(i),
        typeName: 'Skill $i',
        groupId: i % 50,
      )).cast<SdeTypesCompanion>();
      await sdeDb.upsertTypes(types);
    });

    tearDown(() async {
      await appDb.close();
      await sdeDb.close();
    });

    test('skillGroupsWithProgressProvider calculates quickly without pulling all skills to Dart memory', () async {
      // Mock 200 trained skills out of 2000
      final characterSkills = List.generate(200, (i) => CharacterSkill(
        id: i,
        characterId: 1,
        skillId: i * 10,
        trainedSkillLevel: i % 5 + 1,
        activeSkillLevel: i % 5 + 1,
        skillpointsInSkill: 1000,
        lastUpdated: DateTime.now(),
      )).cast<CharacterSkill>();
      
      mockRepo.skillsToReturn = characterSkills;
      
      // Override active character
      final mockChar = Character(
        characterId: 1,
        name: 'Test',
        corporationId: 1,
        corporationName: 'Test Corp',
        securityStatus: 5.0,
        portraitUrl: '',
        tokenExpiry: DateTime.now(),
        lastUpdated: DateTime.now(),
        isActive: true,
      );

      final testContainer = ProviderContainer(
        overrides: [
          sdeDatabaseProvider.overrideWithValue(sdeDb),
          skillRepositoryProvider.overrideWithValue(mockRepo),
          activeCharacterProvider.overrideWith((ref) => Stream.value(mockChar)),
        ],
      );

      // Pre-warm the skillGroupsProvider so JSON parsing isn't counted in the perf test
      await testContainer.read(skillGroupsProvider.future);

      final stopwatch = Stopwatch()..start();
      
      // Read the future
      final result = await testContainer.read(skillGroupsWithProgressProvider.future);
      
      stopwatch.stop();

      // Ensure we got 50 groups
      expect(result.length, 50);
      
      // Check execution time is fast (in an actual device it will be fast, in tests CI it might be up to a few ms)
      // Since it's doing two small SQL queries and mapping ~200 items, it should take less than 200ms.
      expect(stopwatch.elapsedMilliseconds, lessThan(300), reason: 'Provider evaluation took too long, likely doing N+1 or loading all skills into memory.');
    });
  });
}

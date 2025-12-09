import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/skills/data/skill_catalogue_providers.dart'
    hide skillGroupsProvider, skillsByGroupProvider;
import 'package:mimir/features/skills/data/skill_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}

class MockSdeService extends Mock implements SdeService {}

class MockSdeDatabase extends Mock implements SdeDatabase {}

void main() {
  late AppDatabase database;
  late MockEsiClient mockEsiClient;
  late MockSdeService mockSdeService;
  late MockSdeDatabase mockSdeDatabase;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockEsiClient = MockEsiClient();
    mockSdeService = MockSdeService();
    mockSdeDatabase = MockSdeDatabase();

    // Setup SDE service to return mock database
    when(() => mockSdeService.database).thenReturn(mockSdeDatabase);
    when(() => mockSdeService.initialize()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        esiClientProvider.overrideWithValue(mockEsiClient),
        sdeServiceProvider.overrideWithValue(mockSdeService),
      ],
    );
  });

  tearDown(() async {
    await database.close();
    container.dispose();
  });

  group('skillGroupsProvider', () {
    test('returns all skill groups from SDE', () async {
      final testGroups = [
        SdeGroup(groupId: 255, groupName: 'Gunnery', categoryId: 16),
        SdeGroup(groupId: 256, groupName: 'Missiles', categoryId: 16),
        SdeGroup(groupId: 257, groupName: 'Spaceship Command', categoryId: 16),
      ];

      when(() => mockSdeService.getSkillGroups())
          .thenAnswer((_) async => testGroups);

      final List<SdeGroup> result = await container.read(skillGroupsProvider.future) as List<SdeGroup>;

      expect(result, hasLength(3));
      expect(result[0].groupName, 'Gunnery');
      expect(result[1].groupName, 'Missiles');
      expect(result[2].groupName, 'Spaceship Command');
      verify(() => mockSdeService.initialize()).called(1);
      verify(() => mockSdeService.getSkillGroups()).called(1);
    });

    test('returns empty list when SDE has no groups', () async {
      when(() => mockSdeService.getSkillGroups())
          .thenAnswer((_) async => []);

      final result = await container.read(skillGroupsProvider.future);

      expect(result, isEmpty);
    });
  });

  group('skillsByGroupProvider', () {
    test('returns skills with trained levels for active character', () async {
      const characterId = 12345;
      const groupId = 255;

      // Insert active character
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98000001,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));
      await database.setActiveCharacter(characterId);

      // Insert trained skills
      await database.batch((batch) {
        batch.insertAll(database.characterSkills, [
          CharacterSkillsCompanion.insert(
            characterId: characterId,
            skillId: 3301, // Mechanics
            trainedSkillLevel: 5,
            activeSkillLevel: 5,
            skillpointsInSkill: 256000,
            lastUpdated: DateTime.now(),
          ),
          CharacterSkillsCompanion.insert(
            characterId: characterId,
            skillId: 3302, // Engineering
            trainedSkillLevel: 3,
            activeSkillLevel: 3,
            skillpointsInSkill: 8000,
            lastUpdated: DateTime.now(),
          ),
        ]);
      });

      // Mock SDE skills
      final testSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: groupId),
        SdeType(typeId: 3302, typeName: 'Engineering', groupId: groupId),
        SdeType(typeId: 3303, typeName: 'Shield Management', groupId: groupId),
      ];

      when(() => mockSdeService.getSkillsByGroup(groupId))
          .thenAnswer((_) async => testSkills);

      final List<SkillWithLevel> result =
          await container.read(skillsByGroupProvider(groupId).future) as List<SkillWithLevel>;

      expect(result, hasLength(3));

      // Mechanics - level 5
      expect(result[0].skill.typeName, 'Mechanics');
      expect(result[0].trainedLevel, 5);
      expect(result[0].isTraining, false);

      // Engineering - level 3
      expect(result[1].skill.typeName, 'Engineering');
      expect(result[1].trainedLevel, 3);
      expect(result[1].isTraining, false);

      // Shield Management - untrained
      expect(result[2].skill.typeName, 'Shield Management');
      expect(result[2].trainedLevel, 0);
      expect(result[2].isTraining, false);
    });

    test('marks skills in queue as training', () async {
      const characterId = 12345;
      const groupId = 255;

      // Insert active character
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98000001,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));
      await database.setActiveCharacter(characterId);

      // Insert skill in queue
      await database.batch((batch) {
        batch.insertAll(database.skillQueueEntries, [
          SkillQueueEntriesCompanion.insert(
            characterId: characterId,
            queuePosition: 0,
            skillId: 3301, // Currently training
            finishedLevel: 5,
            startDate: Value(DateTime.now().subtract(const Duration(hours: 1))),
            finishDate: Value(DateTime.now().add(const Duration(hours: 2))),
            trainingStartSp: const Value(100000),
            levelEndSp: const Value(256000),
            levelStartSp: const Value(0),
          ),
        ]);
      });

      final testSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: groupId),
      ];

      when(() => mockSdeService.getSkillsByGroup(groupId))
          .thenAnswer((_) async => testSkills);

      final List<SkillWithLevel> result =
          await container.read(skillsByGroupProvider(groupId).future) as List<SkillWithLevel>;

      expect(result, hasLength(1));
      expect(result[0].skill.typeName, 'Mechanics');
      expect(result[0].isTraining, true);
    });

    test('returns all skills at level 0 when no character selected', () async {
      const groupId = 255;

      final testSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: groupId),
        SdeType(typeId: 3302, typeName: 'Engineering', groupId: groupId),
      ];

      when(() => mockSdeService.getSkillsByGroup(groupId))
          .thenAnswer((_) async => testSkills);

      final List<SkillWithLevel> result =
          await container.read(skillsByGroupProvider(groupId).future) as List<SkillWithLevel>;

      expect(result, hasLength(2));
      expect(result[0].trainedLevel, 0);
      expect(result[0].isTraining, false);
      expect(result[1].trainedLevel, 0);
      expect(result[1].isTraining, false);
    });
  });

  group('skillGroupsWithProgressProvider', () {
    test('calculates trained count vs total count for each group', () async {
      const characterId = 12345;

      // Insert active character
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98000001,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));
      await database.setActiveCharacter(characterId);

      // Insert trained skills (2 out of 3 in Gunnery group)
      await database.batch((batch) {
        batch.insertAll(database.characterSkills, [
          CharacterSkillsCompanion.insert(
            characterId: characterId,
            skillId: 3301,
            trainedSkillLevel: 5,
            activeSkillLevel: 5,
            skillpointsInSkill: 256000,
            lastUpdated: DateTime.now(),
          ),
          CharacterSkillsCompanion.insert(
            characterId: characterId,
            skillId: 3302,
            trainedSkillLevel: 3,
            activeSkillLevel: 3,
            skillpointsInSkill: 8000,
            lastUpdated: DateTime.now(),
          ),
        ]);
      });

      final testGroups = [
        SdeGroup(groupId: 255, groupName: 'Gunnery', categoryId: 16),
      ];

      final testSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: 255),
        SdeType(typeId: 3302, typeName: 'Engineering', groupId: 255),
        SdeType(typeId: 3303, typeName: 'Shield Management', groupId: 255),
      ];

      when(() => mockSdeService.getSkillGroups())
          .thenAnswer((_) async => testGroups);
      when(() => mockSdeService.getSkillsByGroup(255))
          .thenAnswer((_) async => testSkills);

      final List<SkillGroupWithProgress> result =
          await container.read(skillGroupsWithProgressProvider.future) as List<SkillGroupWithProgress>;

      expect(result, hasLength(1));
      expect(result[0].group.groupName, 'Gunnery');
      expect(result[0].trainedCount, 2); // 2 out of 3 trained
      expect(result[0].totalCount, 3);
    });

    test('returns 0 trained when no character selected', () async {
      final testGroups = [
        SdeGroup(groupId: 255, groupName: 'Gunnery', categoryId: 16),
      ];

      final testSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: 255),
        SdeType(typeId: 3302, typeName: 'Engineering', groupId: 255),
      ];

      when(() => mockSdeService.getSkillGroups())
          .thenAnswer((_) async => testGroups);
      when(() => mockSdeService.getSkillsByGroup(255))
          .thenAnswer((_) async => testSkills);

      final List<SkillGroupWithProgress> result =
          await container.read(skillGroupsWithProgressProvider.future) as List<SkillGroupWithProgress>;

      expect(result, hasLength(1));
      expect(result[0].trainedCount, 0);
      expect(result[0].totalCount, 2);
    });
  });

  group('searchSkillsProvider', () {
    test('returns empty list for queries less than 2 characters', () async {
      final result1 = await container.read(searchSkillsProvider('').future);
      final result2 = await container.read(searchSkillsProvider('a').future);

      expect(result1, isEmpty);
      expect(result2, isEmpty);

      // Should not call SDE
      verifyNever(() => mockSdeDatabase.getAllSkills());
    });

    test('performs case-insensitive search', () async {
      const characterId = 12345;

      // Insert active character
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98000001,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));
      await database.setActiveCharacter(characterId);

      final allSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: 255),
        SdeType(typeId: 3302, typeName: 'Engineering', groupId: 255),
        SdeType(typeId: 3327, typeName: 'Spaceship Command', groupId: 257),
      ];

      when(() => mockSdeDatabase.getAllSkills())
          .thenAnswer((_) async => allSkills);

      // Search for "ship" (should match "Spaceship Command")
      final List<SkillWithLevel> result =
          await container.read(searchSkillsProvider('ship').future) as List<SkillWithLevel>;

      expect(result, hasLength(1));
      expect(result[0].skill.typeName, 'Spaceship Command');

      // Search with different case
      final List<SkillWithLevel> result2 =
          await container.read(searchSkillsProvider('SHIP').future) as List<SkillWithLevel>;
      expect(result2, hasLength(1));
      expect(result2[0].skill.typeName, 'Spaceship Command');
    });

    test('returns multiple matches', () async {
      final allSkills = [
        SdeType(typeId: 3301, typeName: 'Small Hybrid Turret', groupId: 255),
        SdeType(typeId: 3302, typeName: 'Medium Hybrid Turret', groupId: 255),
        SdeType(typeId: 3303, typeName: 'Large Projectile Turret', groupId: 255),
      ];

      when(() => mockSdeDatabase.getAllSkills())
          .thenAnswer((_) async => allSkills);

      // Search for "turret"
      final List<SkillWithLevel> result =
          await container.read(searchSkillsProvider('turret').future) as List<SkillWithLevel>;

      expect(result, hasLength(3));
      expect(result.map((s) => s.skill.typeName), containsAll([
        'Small Hybrid Turret',
        'Medium Hybrid Turret',
        'Large Projectile Turret',
      ]));
    });

    test('returns empty list for no matches', () async {
      final allSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: 255),
      ];

      when(() => mockSdeDatabase.getAllSkills())
          .thenAnswer((_) async => allSkills);

      final result = await container.read(searchSkillsProvider('nonexistent').future);

      expect(result, isEmpty);
    });

    test('returns skills at level 0 when no character selected', () async {
      final allSkills = [
        SdeType(typeId: 3301, typeName: 'Mechanics', groupId: 255),
      ];

      when(() => mockSdeDatabase.getAllSkills())
          .thenAnswer((_) async => allSkills);

      final result = await container.read(searchSkillsProvider('mech').future);

      expect(result, hasLength(1));
      expect(result[0].trainedLevel, 0);
      expect(result[0].isTraining, false);
    });
  });
}

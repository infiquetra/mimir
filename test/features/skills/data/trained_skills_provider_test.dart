import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart' as esi;
import 'package:mimir/features/skills/data/skill_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements esi.EsiClient {}

void main() {
  late AppDatabase database;
  late MockEsiClient mockEsiClient;
  late ProviderContainer container;

  const characterId = 12345;

  esi.CharacterSkills esiSkills() => esi.CharacterSkills(
    skills: [
      esi.SkillItem(
        skillId: 3301, // Mechanics
        trainedSkillLevel: 4,
        activeSkillLevel: 4,
        skillpointsInSkill: 45000,
      ),
      esi.SkillItem(
        skillId: 3302, // Science
        trainedSkillLevel: 5,
        activeSkillLevel: 5,
        skillpointsInSkill: 256000,
      ),
    ],
    totalSp: 301000,
    unallocatedSp: 1200,
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockEsiClient = MockEsiClient();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        esi.esiClientProvider.overrideWithValue(mockEsiClient),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  group('trainedSkillsProvider', () {
    test(
      'serves the cache without touching ESI when skills are cached',
      () async {
        await database.replaceCharacterSkills(characterId, [
          CharacterSkillsCompanion.insert(
            characterId: characterId,
            skillId: 3301,
            trainedSkillLevel: 3,
            activeSkillLevel: 3,
            skillpointsInSkill: 24000,
            lastUpdated: DateTime.now(),
          ),
        ]);

        final result = await container.read(
          trainedSkillsProvider(characterId).future,
        );

        expect(result, hasLength(1));
        expect(result.single.trainedSkillLevel, 3);
        verifyNever(() => mockEsiClient.getSkills(any()));
      },
    );

    test('fetches from ESI and persists when the cache is empty, so the '
        'catalogue never renders a character as fully untrained', () async {
      when(
        () => mockEsiClient.getSkills(characterId),
      ).thenAnswer((_) async => esiSkills());

      final result = await container.read(
        trainedSkillsProvider(characterId).future,
      );

      expect(result, hasLength(2));
      expect(
        result.map((s) => s.trainedSkillLevel).toList(),
        containsAll([4, 5]),
      );
      verify(() => mockEsiClient.getSkills(characterId)).called(1);

      // The fetch must land in Drift: every catalogue/plan surface joins
      // against the CharacterSkills table, not against this provider.
      final persisted = await database.getCharacterSkills(characterId);
      expect(persisted, hasLength(2));
    });

    test(
      'returns empty and does not throw when ESI fails on a cold cache',
      () async {
        when(
          () => mockEsiClient.getSkills(characterId),
        ).thenThrow(Exception('ESI 503'));

        final result = await container.read(
          trainedSkillsProvider(characterId).future,
        );

        expect(result, isEmpty);
      },
    );
  });

  group('refreshCharacterSkillsProvider', () {
    test('invalidates the trained-skills cache after a refresh', () async {
      await database.replaceCharacterSkills(characterId, [
        CharacterSkillsCompanion.insert(
          characterId: characterId,
          skillId: 3301,
          trainedSkillLevel: 3,
          activeSkillLevel: 3,
          skillpointsInSkill: 24000,
          lastUpdated: DateTime.now(),
        ),
      ]);

      final before = await container.read(
        trainedSkillsProvider(characterId).future,
      );
      expect(before.single.trainedSkillLevel, 3);

      when(
        () => mockEsiClient.getSkills(characterId),
      ).thenAnswer((_) async => esiSkills());

      await container.read(refreshCharacterSkillsProvider(characterId).future);

      final after = await container.read(
        trainedSkillsProvider(characterId).future,
      );
      expect(after, hasLength(2));
      expect(
        after.map((s) => s.trainedSkillLevel).toList(),
        containsAll([4, 5]),
      );
    });
  });
}

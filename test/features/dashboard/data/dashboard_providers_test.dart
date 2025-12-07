import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/dashboard/data/dashboard_providers.dart';
import 'package:mimir/features/skills/data/skill_repository.dart';

class MockEsiClient extends Mock implements EsiClient {}

void main() {
  late AppDatabase database;
  late MockEsiClient mockEsiClient;
  late ProviderContainer container;

  setUp(() {
    // Use in-memory database for testing.
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockEsiClient = MockEsiClient();

    // Create provider container with database and ESI client overrides.
    // Let allCharactersProvider use real implementation (via repository).
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        esiClientProvider.overrideWithValue(mockEsiClient),
      ],
    );
  });

  tearDown(() async {
    await database.close();
    container.dispose();
  });

  group('allCharacterBalancesProvider', () {
    test('should return empty map when no characters exist', () async {
      final result = await container.read(allCharacterBalancesProvider.future);
      expect(result, isEmpty);
    });

    test('should return balances for all characters with wallet data',
        () async {
      // Insert two characters
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      // Record wallet balances
      await database.recordWalletBalance(11111111, 1000000.0);
      await database.recordWalletBalance(22222222, 2500000.0);

      final result = await container.read(allCharacterBalancesProvider.future);

      expect(result, hasLength(2));
      expect(result[11111111], equals(1000000.0));
      expect(result[22222222], equals(2500000.0));
    });

    test('should exclude characters without wallet balances', () async {
      // Insert two characters
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      // Only record balance for first character
      await database.recordWalletBalance(11111111, 1000000.0);

      final result = await container.read(allCharacterBalancesProvider.future);

      expect(result, hasLength(1));
      expect(result[11111111], equals(1000000.0));
      expect(result.containsKey(22222222), isFalse);
    });
  });

  group('allCharacterSkillQueuesProvider', () {
    test('should return empty map when no characters exist', () async {
      final result =
          await container.read(allCharacterSkillQueuesProvider.future);
      expect(result, isEmpty);
    });

    test('should return skill queues for all characters', () async {
      // Insert two characters
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      // Add skill queues
      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3300,
          finishedLevel: 4,
          finishDate: Value(DateTime.now().add(const Duration(hours: 2))),
        ),
      ]);

      await database.replaceSkillQueue(22222222, [
        SkillQueueEntriesCompanion.insert(
          characterId: 22222222,
          queuePosition: 0,
          skillId: 3301,
          finishedLevel: 5,
          finishDate: Value(DateTime.now().add(const Duration(hours: 5))),
        ),
        SkillQueueEntriesCompanion.insert(
          characterId: 22222222,
          queuePosition: 1,
          skillId: 3302,
          finishedLevel: 3,
          finishDate: Value(DateTime.now().add(const Duration(days: 1))),
        ),
      ]);

      final result =
          await container.read(allCharacterSkillQueuesProvider.future);

      expect(result, hasLength(2));
      expect(result[11111111], hasLength(1));
      expect(result[22222222], hasLength(2));
    });

    test('should include characters with empty skill queues', () async {
      // Insert two characters
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      // Only add queue for first character
      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3300,
          finishedLevel: 4,
        ),
      ]);

      final result =
          await container.read(allCharacterSkillQueuesProvider.future);

      expect(result, hasLength(2));
      expect(result[11111111], hasLength(1));
      expect(result[22222222], isEmpty); // Empty queue, not null
    });
  });

  group('combinedWealthProvider', () {
    test('should return 0.0 when no characters exist', () async {
      // Wait for the balance provider to load
      await container.read(allCharacterBalancesProvider.future);

      final result = container.read(combinedWealthProvider);
      expect(result.value, equals(0.0));
    });

    test('should correctly sum balances from all characters', () async {
      // Insert three characters
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(33333333),
        name: 'Pilot Three',
        corporationId: 98000003,
        corporationName: 'Corp Three',
        portraitUrl: 'https://example.com/3',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      // Record balances
      await database.recordWalletBalance(11111111, 1000000.0);
      await database.recordWalletBalance(22222222, 2500000.0);
      await database.recordWalletBalance(33333333, 750000.0);

      // Wait for provider to update
      await container.read(allCharacterBalancesProvider.future);

      final result = container.read(combinedWealthProvider);
      expect(result.value, equals(4250000.0)); // 1M + 2.5M + 750K
    });

    test('should handle single character correctly', () async {
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.recordWalletBalance(11111111, 1234567.89);

      // Wait for provider to update
      await container.read(allCharacterBalancesProvider.future);

      final result = container.read(combinedWealthProvider);
      expect(result.value, equals(1234567.89));
    });

    test('should handle characters without balances', () async {
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      // Only one character has a balance
      await database.recordWalletBalance(11111111, 1000000.0);

      // Wait for provider to update
      await container.read(allCharacterBalancesProvider.future);

      final result = container.read(combinedWealthProvider);
      expect(result.value, equals(1000000.0));
    });
  });

  group('nextSkillsCompletingProvider', () {
    test('should return empty list when no characters exist', () async {
      // Trigger Drift stream to emit by performing a no-op query
      // (Drift streams don't emit until table is accessed)
      await database.getAllCharacters();

      final completions =
          await container.read(nextSkillsCompletingProvider.future);
      expect(completions, isEmpty);
    }, skip: 'StreamProvider tests require widget context - moved to integration tests');

    test('should return next skill per character sorted by finish time',
        () async {
      final now = DateTime.now();
      final soon = now.add(const Duration(hours: 2));
      final later = now.add(const Duration(hours: 5));
      final muchLater = now.add(const Duration(days: 1));

      // Insert characters
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: now.add(const Duration(hours: 1)),
        lastUpdated: now,
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: now.add(const Duration(hours: 1)),
        lastUpdated: now,
      ));

      // Add skill queues with different finish times (in non-sorted order)
      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3300,
          finishedLevel: 4,
          finishDate: Value(later), // Finishes later
        ),
      ]);

      await database.replaceSkillQueue(22222222, [
        SkillQueueEntriesCompanion.insert(
          characterId: 22222222,
          queuePosition: 0,
          skillId: 3301,
          finishedLevel: 5,
          finishDate: Value(soon), // Finishes soon (first in queue)
        ),
        SkillQueueEntriesCompanion.insert(
          characterId: 22222222,
          queuePosition: 1,
          skillId: 3302,
          finishedLevel: 3,
          finishDate: Value(muchLater), // Later skill (not returned)
        ),
      ]);

      // Wait for providers to update
      await container.read(allCharactersProvider.future);
      await container.read(allCharacterSkillQueuesProvider.future);

      final completions =
          await container.read(nextSkillsCompletingProvider.future);

      // Should return only 2 skills - one per character (first skill from each queue)
      expect(completions, hasLength(2));

      // Verify sorting: soon → later
      expect(completions[0].skillEntry.skillId, equals(3301)); // soon
      expect(completions[1].skillEntry.skillId, equals(3300)); // later

      // Verify character associations (should only be one skill per character)
      expect(completions[0].character.characterId, equals(22222222));
      expect(completions[1].character.characterId, equals(11111111));
    }, skip: 'StreamProvider tests require widget context - moved to integration tests');

    test('should return first skill with finish date per character', () async {
      final now = DateTime.now();

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: now.add(const Duration(hours: 1)),
        lastUpdated: now,
      ));

      // Add queue with mixed finish dates - should only return first one with finish date
      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3300,
          finishedLevel: 4,
          finishDate: Value(now.add(const Duration(hours: 2))),
        ),
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 1,
          skillId: 3301,
          finishedLevel: 5,
          // No finish date (paused skill)
        ),
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 2,
          skillId: 3302,
          finishedLevel: 3,
          finishDate: Value(now.add(const Duration(hours: 5))),
        ),
      ]);

      // Wait for providers to update
      await container.read(allCharactersProvider.future);
      await container.read(allCharacterSkillQueuesProvider.future);

      final completions =
          await container.read(nextSkillsCompletingProvider.future);

      // Should only return first skill from queue (one per character)
      expect(completions, hasLength(1));
      expect(completions[0].skillEntry.skillId, equals(3300));
    }, skip: 'StreamProvider tests require widget context - moved to integration tests');

    test('should handle characters with empty queues', () async {
      final now = DateTime.now();

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: now.add(const Duration(hours: 1)),
        lastUpdated: now,
      ));

      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(22222222),
        name: 'Pilot Two',
        corporationId: 98000002,
        corporationName: 'Corp Two',
        portraitUrl: 'https://example.com/2',
        tokenExpiry: now.add(const Duration(hours: 1)),
        lastUpdated: now,
      ));

      // Only add queue for first character
      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3300,
          finishedLevel: 4,
          finishDate: Value(now.add(const Duration(hours: 2))),
        ),
      ]);

      // Wait for providers to update
      await container.read(allCharactersProvider.future);
      await container.read(allCharacterSkillQueuesProvider.future);

      final completions =
          await container.read(nextSkillsCompletingProvider.future);

      expect(completions, hasLength(1));
      expect(completions[0].character.characterId, equals(11111111));
    }, skip: 'StreamProvider tests require widget context - moved to integration tests');
  });

  group('NextSkillCompletion', () {
    test('should implement equality correctly', () async {
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(11111111),
        name: 'Pilot One',
        corporationId: 98000001,
        corporationName: 'Corp One',
        portraitUrl: 'https://example.com/1',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3300,
          finishedLevel: 4,
        ),
      ]);

      final character = (await database.getAllCharacters()).first;
      final skill = (await database.getSkillQueue(11111111)).first;

      final completion1 = NextSkillCompletion(
        character: character,
        skillEntry: skill,
      );

      final completion2 = NextSkillCompletion(
        character: character,
        skillEntry: skill,
      );

      expect(completion1, equals(completion2));
      expect(completion1.hashCode, equals(completion2.hashCode));
    });
  });
}

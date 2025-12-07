import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/skills/data/skill_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}

void main() {
  late AppDatabase database;
  late MockEsiClient mockEsiClient;
  late SkillRepository repository;

  setUp(() {
    // Use in-memory database for testing.
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockEsiClient = MockEsiClient();
    repository = SkillRepository(
      database: database,
      esiClient: mockEsiClient,
    );

    // Reset any previous mock interactions.
    reset(mockEsiClient);
  });

  tearDown(() async {
    await database.close();
  });

  group('refreshSkillQueue', () {
    test('should fetch queue from ESI and save to database', () async {
      const characterId = 12345678;
      final queueItems = [
        SkillQueueItem(
          queuePosition: 0,
          skillId: 3327,
          finishedLevel: 5,
          startDate: DateTime.parse('2025-01-01T10:00:00Z'),
          finishDate: DateTime.parse('2025-01-02T10:00:00Z'),
          trainingStartSp: 0,
          levelEndSp: 256000,
          levelStartSp: 0,
        ),
        SkillQueueItem(
          queuePosition: 1,
          skillId: 3386,
          finishedLevel: 4,
          startDate: DateTime.parse('2025-01-02T10:00:00Z'),
          finishDate: DateTime.parse('2025-01-03T10:00:00Z'),
          trainingStartSp: 10000,
          levelEndSp: 45255,
          levelStartSp: 5657,
        ),
      ];

      // Mock ESI client to return queue items.
      when(() => mockEsiClient.getSkillQueue(characterId))
          .thenAnswer((_) async => queueItems);

      // Call repository method.
      await repository.refreshSkillQueue(characterId);

      // Verify queue entries were saved to database.
      final savedQueue = await database.getSkillQueue(characterId);
      expect(savedQueue, hasLength(2));
      expect(savedQueue[0].skillId, equals(3327));
      expect(savedQueue[0].queuePosition, equals(0));
      expect(savedQueue[1].skillId, equals(3386));
      expect(savedQueue[1].queuePosition, equals(1));
    });

    test('should handle empty queue response', () async {
      const characterId = 12345678;

      // Mock ESI client to return empty list.
      when(() => mockEsiClient.getSkillQueue(characterId))
          .thenAnswer((_) async => []);

      // Call repository method.
      await repository.refreshSkillQueue(characterId);

      // Verify no entries were saved.
      final savedQueue = await database.getSkillQueue(characterId);
      expect(savedQueue, isEmpty);
    });

    test('should throw EsiException on API error', () async {
      const characterId = 12345678;

      // Mock ESI client to throw exception.
      when(() => mockEsiClient.getSkillQueue(characterId))
          .thenThrow(const EsiException('API Error', statusCode: 500));

      // Expect exception to be rethrown.
      expect(
        () => repository.refreshSkillQueue(characterId),
        throwsA(isA<EsiException>()),
      );
    });

    test('should handle token refresh failure (401)', () async {
      const characterId = 12345678;

      // Mock ESI client to throw auth error.
      when(() => mockEsiClient.getSkillQueue(characterId))
          .thenThrow(const EsiException('Unauthorized', statusCode: 401));

      // Expect exception to be rethrown.
      expect(
        () => repository.refreshSkillQueue(characterId),
        throwsA(
          predicate((e) => e is EsiException && e.isAuthError),
        ),
      );
    });

    test('should replace existing queue on refresh', () async {
      const characterId = 12345678;

      // Insert initial queue.
      await database.replaceSkillQueue(characterId, [
        SkillQueueEntriesCompanion.insert(
          characterId: characterId,
          queuePosition: 0,
          skillId: 9999,
          finishedLevel: 3,
        ),
      ]);

      // Verify initial queue.
      final initialQueue = await database.getSkillQueue(characterId);
      expect(initialQueue, hasLength(1));
      expect(initialQueue[0].skillId, equals(9999));

      // Mock ESI with new queue.
      final newQueueItems = [
        SkillQueueItem(
          queuePosition: 0,
          skillId: 3327,
          finishedLevel: 5,
          startDate: DateTime.parse('2025-01-01T10:00:00Z'),
          finishDate: DateTime.parse('2025-01-02T10:00:00Z'),
          trainingStartSp: 0,
          levelEndSp: 256000,
          levelStartSp: 0,
        ),
      ];

      when(() => mockEsiClient.getSkillQueue(characterId))
          .thenAnswer((_) async => newQueueItems);

      // Refresh queue.
      await repository.refreshSkillQueue(characterId);

      // Verify queue was replaced.
      final updatedQueue = await database.getSkillQueue(characterId);
      expect(updatedQueue, hasLength(1));
      expect(updatedQueue[0].skillId, equals(3327));
    });
  });

  group('getSkillQueue', () {
    test('should return queue from database', () async {
      const characterId = 12345678;

      // Insert test queue.
      await database.replaceSkillQueue(characterId, [
        SkillQueueEntriesCompanion.insert(
          characterId: characterId,
          queuePosition: 0,
          skillId: 3327,
          finishedLevel: 5,
        ),
        SkillQueueEntriesCompanion.insert(
          characterId: characterId,
          queuePosition: 1,
          skillId: 3386,
          finishedLevel: 4,
        ),
      ]);

      // Call repository method.
      final queue = await repository.getSkillQueue(characterId);

      // Verify queue.
      expect(queue, hasLength(2));
      expect(queue[0].skillId, equals(3327));
      expect(queue[1].skillId, equals(3386));
    });

    test('should return empty list when no queue exists', () async {
      const characterId = 12345678;

      // Call repository method.
      final queue = await repository.getSkillQueue(characterId);

      // Verify empty queue.
      expect(queue, isEmpty);
    });
  });

  group('getAllCharacterQueues', () {
    test('should return queues for all characters', () async {
      // Insert test characters.
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

      // Insert queues for both characters.
      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3327,
          finishedLevel: 5,
        ),
      ]);
      await database.replaceSkillQueue(22222222, [
        SkillQueueEntriesCompanion.insert(
          characterId: 22222222,
          queuePosition: 0,
          skillId: 3386,
          finishedLevel: 4,
        ),
        SkillQueueEntriesCompanion.insert(
          characterId: 22222222,
          queuePosition: 1,
          skillId: 3392,
          finishedLevel: 3,
        ),
      ]);

      // Call repository method.
      final queues = await repository.getAllCharacterQueues();

      // Verify queues map.
      expect(queues, hasLength(2));
      expect(queues[11111111], hasLength(1));
      expect(queues[11111111]![0].skillId, equals(3327));
      expect(queues[22222222], hasLength(2));
      expect(queues[22222222]![0].skillId, equals(3386));
    });

    test('should include characters with empty queues', () async {
      // Insert characters.
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

      // Only insert queue for first character.
      await database.replaceSkillQueue(11111111, [
        SkillQueueEntriesCompanion.insert(
          characterId: 11111111,
          queuePosition: 0,
          skillId: 3327,
          finishedLevel: 5,
        ),
      ]);

      // Call repository method.
      final queues = await repository.getAllCharacterQueues();

      // Verify both characters in map.
      expect(queues, hasLength(2));
      expect(queues[11111111], hasLength(1));
      expect(queues[22222222], isEmpty);
    });

    test('should return empty map when no characters exist', () async {
      // No characters inserted.

      // Call repository method.
      final queues = await repository.getAllCharacterQueues();

      // Verify empty map.
      expect(queues, isEmpty);
    });
  });
}

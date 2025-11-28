import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    // Use in-memory database for testing.
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Characters', () {
    test('should insert and retrieve a character', () async {
      final character = CharactersCompanion.insert(
        characterId: const Value(12345678),
        name: 'Test Pilot',
        corporationId: 98000001,
        corporationName: 'Test Corporation',
        portraitUrl: 'https://images.evetech.net/characters/12345678/portrait',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      );

      await database.upsertCharacter(character);

      final characters = await database.getAllCharacters();
      expect(characters, hasLength(1));
      expect(characters.first.name, equals('Test Pilot'));
      expect(characters.first.characterId, equals(12345678));
    });

    test('should update existing character on upsert', () async {
      final character = CharactersCompanion.insert(
        characterId: const Value(12345678),
        name: 'Test Pilot',
        corporationId: 98000001,
        corporationName: 'Test Corporation',
        portraitUrl: 'https://images.evetech.net/characters/12345678/portrait',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      );

      await database.upsertCharacter(character);

      // Update the character with a new corporation.
      final updatedCharacter = CharactersCompanion.insert(
        characterId: const Value(12345678),
        name: 'Test Pilot',
        corporationId: 98000002,
        corporationName: 'New Corporation',
        portraitUrl: 'https://images.evetech.net/characters/12345678/portrait',
        tokenExpiry: DateTime.now().add(const Duration(hours: 2)),
        lastUpdated: DateTime.now(),
      );

      await database.upsertCharacter(updatedCharacter);

      final characters = await database.getAllCharacters();
      expect(characters, hasLength(1));
      expect(characters.first.corporationName, equals('New Corporation'));
    });

    test('should set active character', () async {
      // Insert two characters.
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

      // Set second character as active.
      await database.setActiveCharacter(22222222);

      final active = await database.getActiveCharacter();
      expect(active, isNotNull);
      expect(active!.characterId, equals(22222222));
      expect(active.name, equals('Pilot Two'));
    });

    test('should delete character and related data', () async {
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(12345678),
        name: 'Test Pilot',
        corporationId: 98000001,
        corporationName: 'Test Corporation',
        portraitUrl: 'https://example.com/portrait',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.deleteCharacter(12345678);

      final characters = await database.getAllCharacters();
      expect(characters, isEmpty);
    });
  });

  group('SkillQueue', () {
    test('should replace skill queue for character', () async {
      // First insert a character.
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(12345678),
        name: 'Test Pilot',
        corporationId: 98000001,
        corporationName: 'Test Corporation',
        portraitUrl: 'https://example.com/portrait',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      final entries = [
        SkillQueueEntriesCompanion.insert(
          characterId: 12345678,
          queuePosition: 0,
          skillId: 3300,
          finishedLevel: 4,
        ),
        SkillQueueEntriesCompanion.insert(
          characterId: 12345678,
          queuePosition: 1,
          skillId: 3301,
          finishedLevel: 5,
        ),
      ];

      await database.replaceSkillQueue(12345678, entries);

      final queue = await database.getSkillQueue(12345678);
      expect(queue, hasLength(2));
      expect(queue[0].queuePosition, equals(0));
      expect(queue[1].queuePosition, equals(1));
    });
  });

  group('Wallet', () {
    test('should record and retrieve wallet balance', () async {
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(12345678),
        name: 'Test Pilot',
        corporationId: 98000001,
        corporationName: 'Test Corporation',
        portraitUrl: 'https://example.com/portrait',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      await database.recordWalletBalance(12345678, 1234567890.50);

      final balance = await database.getLatestWalletBalance(12345678);
      expect(balance, equals(1234567890.50));
    });

    test('should insert wallet journal entries', () async {
      await database.upsertCharacter(CharactersCompanion.insert(
        characterId: const Value(12345678),
        name: 'Test Pilot',
        corporationId: 98000001,
        corporationName: 'Test Corporation',
        portraitUrl: 'https://example.com/portrait',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      ));

      final entries = [
        WalletJournalEntriesCompanion.insert(
          id: const Value(1001),
          characterId: 12345678,
          amount: 1000000.0,
          balance: 10000000.0,
          refType: 'player_donation',
          date: DateTime.now(),
        ),
        WalletJournalEntriesCompanion.insert(
          id: const Value(1002),
          characterId: 12345678,
          amount: -500000.0,
          balance: 9500000.0,
          refType: 'market_transaction',
          date: DateTime.now(),
        ),
      ];

      await database.insertWalletJournalEntries(entries);

      final journal = await database.getWalletJournal(12345678);
      expect(journal, hasLength(2));
    });
  });
}

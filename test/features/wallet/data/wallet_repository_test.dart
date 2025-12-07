import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/wallet/data/wallet_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements EsiClient {}

void main() {
  late AppDatabase database;
  late MockEsiClient mockEsiClient;
  late WalletRepository repository;

  setUp(() {
    // Use in-memory database for testing.
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockEsiClient = MockEsiClient();
    repository = WalletRepository(
      database: database,
      esiClient: mockEsiClient,
    );

    // Reset any previous mock interactions.
    reset(mockEsiClient);
  });

  tearDown(() async {
    await database.close();
  });

  group('refreshWalletBalance', () {
    test('should fetch balance from ESI and save to database', () async {
      const characterId = 12345678;
      const balance = 1500000000.0;

      // Mock ESI client to return balance.
      when(() => mockEsiClient.getWalletBalance(characterId))
          .thenAnswer((_) async => balance);

      // Call repository method.
      final result = await repository.refreshWalletBalance(characterId);

      // Verify balance was returned.
      expect(result, equals(balance));

      // Verify balance was saved to database.
      final savedBalance = await database.getLatestWalletBalance(characterId);
      expect(savedBalance, equals(balance));
    });

    test('should throw EsiException on API error', () async {
      const characterId = 12345678;

      // Mock ESI client to throw exception.
      when(() => mockEsiClient.getWalletBalance(characterId))
          .thenThrow(const EsiException('API Error', statusCode: 500));

      // Expect exception to be rethrown.
      expect(
        () => repository.refreshWalletBalance(characterId),
        throwsA(isA<EsiException>()),
      );
    });

    test('should handle token refresh failure (401)', () async {
      const characterId = 12345678;

      // Mock ESI client to throw auth error.
      when(() => mockEsiClient.getWalletBalance(characterId))
          .thenThrow(const EsiException('Unauthorized', statusCode: 401));

      // Expect exception to be rethrown.
      expect(
        () => repository.refreshWalletBalance(characterId),
        throwsA(
          predicate((e) => e is EsiException && e.isAuthError),
        ),
      );
    });
  });

  group('refreshWalletJournal', () {
    test('should fetch journal from ESI and save to database', () async {
      const characterId = 12345678;
      final journalItems = [
        WalletJournalItem(
          id: 1,
          amount: 100000.0,
          balance: 1100000.0,
          refType: 'bounty_prizes',
          date: DateTime.parse('2025-01-01T10:00:00Z'),
          firstPartyId: characterId,
          secondPartyId: null,
          description: 'Bounty prizes',
        ),
        WalletJournalItem(
          id: 2,
          amount: -50000.0,
          balance: 1050000.0,
          refType: 'market_escrow',
          date: DateTime.parse('2025-01-01T11:00:00Z'),
          firstPartyId: characterId,
          secondPartyId: 98000001,
          description: 'Market escrow',
        ),
      ];

      // Mock ESI client to return journal items.
      when(() => mockEsiClient.getWalletJournal(characterId))
          .thenAnswer((_) async => journalItems);

      // Call repository method.
      await repository.refreshWalletJournal(characterId);

      // Verify journal entries were saved to database (ordered by date DESC).
      final savedEntries = await database.getWalletJournal(characterId, limit: 10);
      expect(savedEntries, hasLength(2));
      // Newest entry first (id: 2, date: 11:00)
      expect(savedEntries[0].id, equals(2));
      expect(savedEntries[0].amount, equals(-50000.0));
      // Older entry second (id: 1, date: 10:00)
      expect(savedEntries[1].id, equals(1));
      expect(savedEntries[1].amount, equals(100000.0));
    });

    test('should handle empty journal response', () async {
      const characterId = 12345678;

      // Mock ESI client to return empty list.
      when(() => mockEsiClient.getWalletJournal(characterId))
          .thenAnswer((_) async => []);

      // Call repository method.
      await repository.refreshWalletJournal(characterId);

      // Verify no entries were saved.
      final savedEntries = await database.getWalletJournal(characterId, limit: 10);
      expect(savedEntries, isEmpty);
    });

    test('should throw EsiException on scope error (403)', () async {
      const characterId = 12345678;

      // Mock ESI client to throw scope error.
      when(() => mockEsiClient.getWalletJournal(characterId))
          .thenThrow(const EsiException('Forbidden - missing scope', statusCode: 403));

      // Expect exception to be rethrown.
      expect(
        () => repository.refreshWalletJournal(characterId),
        throwsA(
          predicate((e) => e is EsiException && e.isScopeError),
        ),
      );
    });
  });

  group('get30DaySummary', () {
    test('should calculate income and expenses from last 30 days', () async {
      const characterId = 12345678;
      final now = DateTime.now();
      final twentyDaysAgo = now.subtract(const Duration(days: 20));
      final fortyDaysAgo = now.subtract(const Duration(days: 40));

      // Insert test journal entries.
      await database.insertWalletJournalEntries([
        // Recent income (within 30 days)
        WalletJournalEntriesCompanion.insert(
          id: const Value(1),
          characterId: characterId,
          amount: 1000000.0,
          balance: 2000000.0,
          refType: 'bounty_prizes',
          date: twentyDaysAgo,
        ),
        // Recent expense (within 30 days)
        WalletJournalEntriesCompanion.insert(
          id: const Value(2),
          characterId: characterId,
          amount: -500000.0,
          balance: 1500000.0,
          refType: 'market_escrow',
          date: twentyDaysAgo,
        ),
        // Old entry (should be excluded)
        WalletJournalEntriesCompanion.insert(
          id: const Value(3),
          characterId: characterId,
          amount: 2000000.0,
          balance: 3500000.0,
          refType: 'bounty_prizes',
          date: fortyDaysAgo,
        ),
      ]);

      // Call repository method.
      final summary = await repository.get30DaySummary(characterId);

      // Verify calculations (only recent entries).
      expect(summary.income, equals(1000000.0));
      expect(summary.expenses, equals(500000.0));
      expect(summary.net, equals(500000.0));
    });

    test('should handle zero income and zero expenses', () async {
      const characterId = 12345678;

      // No journal entries inserted.

      // Call repository method.
      final summary = await repository.get30DaySummary(characterId);

      // Verify zero values.
      expect(summary.income, equals(0.0));
      expect(summary.expenses, equals(0.0));
      expect(summary.net, equals(0.0));
    });

    test('should handle only income entries', () async {
      const characterId = 12345678;
      final twentyDaysAgo = DateTime.now().subtract(const Duration(days: 20));

      // Insert only income entries.
      await database.insertWalletJournalEntries([
        WalletJournalEntriesCompanion.insert(
          id: const Value(1),
          characterId: characterId,
          amount: 1000000.0,
          balance: 1000000.0,
          refType: 'bounty_prizes',
          date: twentyDaysAgo,
        ),
        WalletJournalEntriesCompanion.insert(
          id: const Value(2),
          characterId: characterId,
          amount: 2000000.0,
          balance: 3000000.0,
          refType: 'insurance',
          date: twentyDaysAgo,
        ),
      ]);

      // Call repository method.
      final summary = await repository.get30DaySummary(characterId);

      // Verify only income.
      expect(summary.income, equals(3000000.0));
      expect(summary.expenses, equals(0.0));
      expect(summary.net, equals(3000000.0));
    });

    test('should handle only expense entries', () async {
      const characterId = 12345678;
      final twentyDaysAgo = DateTime.now().subtract(const Duration(days: 20));

      // Insert only expense entries.
      await database.insertWalletJournalEntries([
        WalletJournalEntriesCompanion.insert(
          id: const Value(1),
          characterId: characterId,
          amount: -500000.0,
          balance: 500000.0,
          refType: 'market_escrow',
          date: twentyDaysAgo,
        ),
        WalletJournalEntriesCompanion.insert(
          id: const Value(2),
          characterId: characterId,
          amount: -300000.0,
          balance: 200000.0,
          refType: 'station_service_fee',
          date: twentyDaysAgo,
        ),
      ]);

      // Call repository method.
      final summary = await repository.get30DaySummary(characterId);

      // Verify only expenses.
      expect(summary.income, equals(0.0));
      expect(summary.expenses, equals(800000.0));
      expect(summary.net, equals(-800000.0));
    });
  });

  group('getAllCharacterBalances', () {
    test('should return balances for all characters', () async {
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

      // Record balances for both characters.
      await database.recordWalletBalance(11111111, 1500000000.0);
      await database.recordWalletBalance(22222222, 2500000000.0);

      // Call repository method.
      final balances = await repository.getAllCharacterBalances();

      // Verify balances map.
      expect(balances, hasLength(2));
      expect(balances[11111111], equals(1500000000.0));
      expect(balances[22222222], equals(2500000000.0));
    });

    test('should exclude characters without balances', () async {
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

      // Only record balance for first character.
      await database.recordWalletBalance(11111111, 1500000000.0);

      // Call repository method.
      final balances = await repository.getAllCharacterBalances();

      // Verify only one balance.
      expect(balances, hasLength(1));
      expect(balances[11111111], equals(1500000000.0));
      expect(balances.containsKey(22222222), isFalse);
    });

    test('should return empty map when no characters exist', () async {
      // No characters inserted.

      // Call repository method.
      final balances = await repository.getAllCharacterBalances();

      // Verify empty map.
      expect(balances, isEmpty);
    });
  });

  group('WalletSummary', () {
    test('should calculate net correctly', () {
      const summary = WalletSummary(income: 1000000.0, expenses: 400000.0);
      expect(summary.net, equals(600000.0));
    });

    test('should handle negative net (more expenses than income)', () {
      const summary = WalletSummary(income: 300000.0, expenses: 500000.0);
      expect(summary.net, equals(-200000.0));
    });

    test('should handle zero values', () {
      const summary = WalletSummary(income: 0.0, expenses: 0.0);
      expect(summary.net, equals(0.0));
    });
  });
}

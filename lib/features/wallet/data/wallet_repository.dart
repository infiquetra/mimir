import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';

/// Repository for managing wallet data.
///
/// Coordinates between:
/// - ESI client for fetching wallet balance and journal
/// - Local database for caching and offline access
class WalletRepository {
  final AppDatabase _database;
  final EsiClient _esiClient;

  WalletRepository({
    required AppDatabase database,
    required EsiClient esiClient,
  })  : _database = database,
        _esiClient = esiClient;

  /// Refreshes the wallet balance from ESI and records a snapshot.
  Future<double> refreshWalletBalance(int characterId) async {
    Log.d('WALLET', 'refreshWalletBalance($characterId) - START');
    try {
      // Fetch wallet balance from ESI.
      Log.d('WALLET', 'refreshWalletBalance - fetching from ESI');
      final balance = await _esiClient.getWalletBalance(characterId);
      Log.i('WALLET', 'refreshWalletBalance - fetched balance: $balance ISK');

      // Record the balance snapshot.
      Log.d('WALLET', 'refreshWalletBalance - saving to database');
      await _database.recordWalletBalance(characterId, balance);
      Log.i('WALLET', 'refreshWalletBalance - saved balance snapshot');
      Log.d('WALLET', 'refreshWalletBalance($characterId) - SUCCESS');
      return balance;
    } catch (e, stack) {
      Log.e('WALLET', 'refreshWalletBalance($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Refreshes the wallet journal from ESI.
  Future<void> refreshWalletJournal(int characterId) async {
    Log.d('WALLET', 'refreshWalletJournal($characterId) - START');
    try {
      // Fetch wallet journal from ESI (first page).
      Log.d('WALLET', 'refreshWalletJournal - fetching from ESI');
      final journalItems = await _esiClient.getWalletJournal(characterId);
      Log.i('WALLET', 'refreshWalletJournal - fetched ${journalItems.length} journal entries from ESI');

      // Convert ESI items to database companions.
      Log.d('WALLET', 'refreshWalletJournal - converting to database companions');
      final companions = journalItems.map((item) {
        return WalletJournalEntriesCompanion.insert(
          id: Value(item.id),
          characterId: characterId,
          amount: item.amount,
          balance: item.balance,
          refType: item.refType,
          firstPartyId: Value(item.firstPartyId),
          secondPartyId: Value(item.secondPartyId),
          description: Value(item.description),
          date: item.date,
        );
      }).toList();

      // Insert entries (ignores duplicates via ON CONFLICT UPDATE).
      Log.d('WALLET', 'refreshWalletJournal - saving to database');
      await _database.insertWalletJournalEntries(companions);
      Log.i('WALLET', 'refreshWalletJournal - saved ${companions.length} journal entries');
      Log.d('WALLET', 'refreshWalletJournal($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('WALLET', 'refreshWalletJournal($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Gets the latest wallet balance from the local database.
  Future<double?> getLatestWalletBalance(int characterId) async {
    Log.d('WALLET', 'getLatestWalletBalance($characterId) - START');
    try {
      final balance = await _database.getLatestWalletBalance(characterId);
      Log.i('WALLET', 'getLatestWalletBalance - ${balance != null ? "found: $balance ISK" : "no balance recorded"}');
      Log.d('WALLET', 'getLatestWalletBalance($characterId) - SUCCESS');
      return balance;
    } catch (e, stack) {
      Log.e('WALLET', 'getLatestWalletBalance($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Watches the wallet journal for reactive updates.
  Stream<List<WalletJournalEntry>> watchWalletJournal(
    int characterId, {
    int limit = 50,
  }) {
    Log.d('WALLET', 'watchWalletJournal($characterId, limit=$limit) - subscribed to stream');
    return _database.watchWalletJournal(characterId, limit: limit);
  }

  /// Gets the wallet journal from the local database.
  Future<List<WalletJournalEntry>> getWalletJournal(
    int characterId, {
    int limit = 50,
  }) async {
    Log.d('WALLET', 'getWalletJournal($characterId, limit=$limit) - START');
    try {
      final journal = await _database.getWalletJournal(characterId, limit: limit);
      Log.i('WALLET', 'getWalletJournal - found ${journal.length} entries');
      Log.d('WALLET', 'getWalletJournal($characterId, limit=$limit) - SUCCESS');
      return journal;
    } catch (e, stack) {
      Log.e('WALLET', 'getWalletJournal($characterId, limit=$limit) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Gets wallet balances for all characters.
  ///
  /// Returns a map of characterId → balance for all characters that
  /// have a recorded balance. Characters without balances are excluded.
  Future<Map<int, double>> getAllCharacterBalances() async {
    Log.d('WALLET', 'getAllCharacterBalances() - START');
    try {
      final characters = await _database.getAllCharacters();
      Log.i('WALLET', 'getAllCharacterBalances - loading balances for ${characters.length} characters');
      final balanceMap = <int, double>{};

      for (final character in characters) {
        final balance = await _database.getLatestWalletBalance(character.characterId);
        if (balance != null) {
          balanceMap[character.characterId] = balance;
          Log.d('WALLET', 'getAllCharacterBalances - character ${character.characterId}: $balance ISK');
        }
      }

      Log.i('WALLET', 'getAllCharacterBalances - loaded balances for ${balanceMap.length} characters');
      Log.d('WALLET', 'getAllCharacterBalances() - SUCCESS');
      return balanceMap;
    } catch (e, stack) {
      Log.e('WALLET', 'getAllCharacterBalances() - FAILED', e, stack);
      rethrow;
    }
  }
}

/// Provider for the wallet repository.
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
});

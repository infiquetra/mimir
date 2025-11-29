import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
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
    try {
      // Fetch wallet balance from ESI.
      final balance = await _esiClient.getWalletBalance(characterId);

      // Record the balance snapshot.
      await _database.recordWalletBalance(characterId, balance);

      debugPrint('Wallet balance refreshed for character $characterId: $balance ISK');
      return balance;
    } catch (e) {
      debugPrint('Failed to refresh wallet balance for $characterId: $e');
      rethrow;
    }
  }

  /// Refreshes the wallet journal from ESI.
  Future<void> refreshWalletJournal(int characterId) async {
    try {
      // Fetch wallet journal from ESI (first page).
      final journalItems = await _esiClient.getWalletJournal(characterId);

      // Convert ESI items to database companions.
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
      await _database.insertWalletJournalEntries(companions);

      debugPrint(
          'Wallet journal refreshed for character $characterId: ${companions.length} entries');
    } catch (e) {
      debugPrint('Failed to refresh wallet journal for $characterId: $e');
      rethrow;
    }
  }

  /// Gets the latest wallet balance from the local database.
  Future<double?> getLatestWalletBalance(int characterId) {
    return _database.getLatestWalletBalance(characterId);
  }

  /// Watches the wallet journal for reactive updates.
  Stream<List<WalletJournalEntry>> watchWalletJournal(
    int characterId, {
    int limit = 50,
  }) {
    return _database.watchWalletJournal(characterId, limit: limit);
  }

  /// Gets the wallet journal from the local database.
  Future<List<WalletJournalEntry>> getWalletJournal(
    int characterId, {
    int limit = 50,
  }) {
    return _database.getWalletJournal(characterId, limit: limit);
  }
}

/// Provider for the wallet repository.
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
});

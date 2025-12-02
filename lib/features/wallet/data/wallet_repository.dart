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

  /// Refreshes wallet market transactions from ESI.
  Future<void> refreshWalletTransactions(int characterId) async {
    Log.d('WALLET', 'refreshWalletTransactions($characterId) - START');
    try {
      // Fetch wallet transactions from ESI.
      Log.d('WALLET', 'refreshWalletTransactions - fetching from ESI');
      final transactions = await _esiClient.getWalletTransactions(characterId);
      Log.i('WALLET',
          'refreshWalletTransactions - fetched ${transactions.length} transactions from ESI');

      // Convert ESI items to database companions.
      Log.d(
          'WALLET', 'refreshWalletTransactions - converting to database companions');
      final companions = transactions.map((item) {
        return WalletTransactionsCompanion.insert(
          transactionId: Value(item.transactionId),
          characterId: characterId,
          typeId: item.typeId,
          locationId: item.locationId,
          unitPrice: item.unitPrice,
          quantity: item.quantity,
          isBuy: item.isBuy,
          clientId: item.clientId,
          date: item.date,
          journalRefId: Value(item.journalRefId),
        );
      }).toList();

      // Insert entries (ignores duplicates via ON CONFLICT UPDATE).
      Log.d('WALLET', 'refreshWalletTransactions - saving to database');
      await _database.insertWalletTransactions(companions);
      Log.i('WALLET',
          'refreshWalletTransactions - saved ${companions.length} transactions');
      Log.d('WALLET', 'refreshWalletTransactions($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('WALLET', 'refreshWalletTransactions($characterId) - FAILED', e,
          stack);
      rethrow;
    }
  }

  /// Refreshes loyalty points from ESI.
  Future<void> refreshLoyaltyPoints(int characterId) async {
    Log.d('WALLET', 'refreshLoyaltyPoints($characterId) - START');
    try {
      // Fetch loyalty points from ESI.
      Log.d('WALLET', 'refreshLoyaltyPoints - fetching from ESI');
      final lpItems = await _esiClient.getLoyaltyPoints(characterId);
      Log.i('WALLET',
          'refreshLoyaltyPoints - fetched LP from ${lpItems.length} corporations');

      // Convert ESI items to database companions.
      Log.d('WALLET', 'refreshLoyaltyPoints - converting to database companions');
      final companions = lpItems.map((item) {
        return LoyaltyPointsCompanion.insert(
          characterId: characterId,
          corporationId: item.corporationId,
          loyaltyPoints: item.loyaltyPoints,
          lastUpdated: DateTime.now(),
        );
      }).toList();

      // Replace all loyalty points for this character.
      Log.d('WALLET', 'refreshLoyaltyPoints - saving to database');
      await _database.replaceLoyaltyPoints(characterId, companions);
      Log.i('WALLET',
          'refreshLoyaltyPoints - saved LP for ${companions.length} corporations');
      Log.d('WALLET', 'refreshLoyaltyPoints($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('WALLET', 'refreshLoyaltyPoints($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Refreshes PLEX count from assets (type_id 44992).
  Future<int> refreshPlexCount(int characterId) async {
    Log.d('WALLET', 'refreshPlexCount($characterId) - START');
    try {
      // Fetch character assets from ESI.
      Log.d('WALLET', 'refreshPlexCount - fetching assets from ESI');
      final assets = await _esiClient.getCharacterAssets(characterId);
      Log.i('WALLET', 'refreshPlexCount - fetched ${assets.length} assets from ESI');

      // Filter for PLEX (type_id 44992) and convert to companions.
      Log.d('WALLET', 'refreshPlexCount - filtering for PLEX (type_id 44992)');
      final plexAssets = assets.where((a) => a.typeId == 44992).toList();
      Log.i('WALLET',
          'refreshPlexCount - found ${plexAssets.length} PLEX asset stacks');

      final companions = plexAssets.map((item) {
        return AssetCacheCompanion.insert(
          itemId: Value(item.itemId),
          characterId: characterId,
          typeId: item.typeId,
          quantity: item.quantity,
          locationId: item.locationId,
          lastUpdated: DateTime.now(),
        );
      }).toList();

      // Clear old PLEX cache and insert new.
      Log.d('WALLET', 'refreshPlexCount - updating asset cache');
      await _database.clearAssetCache(characterId);
      if (companions.isNotEmpty) {
        await _database.upsertAssets(companions);
      }

      // Calculate total PLEX.
      final totalPlex =
          plexAssets.fold<int>(0, (sum, asset) => sum + asset.quantity);
      Log.i('WALLET', 'refreshPlexCount - total PLEX: $totalPlex');
      Log.d('WALLET', 'refreshPlexCount($characterId) - SUCCESS');
      return totalPlex;
    } catch (e, stack) {
      Log.e('WALLET', 'refreshPlexCount($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Gets the PLEX count from the local cache.
  Future<int> getPlexCount(int characterId) async {
    Log.d('WALLET', 'getPlexCount($characterId) - START');
    try {
      final count = await _database.getPlexCount(characterId);
      Log.i('WALLET', 'getPlexCount - found $count PLEX');
      Log.d('WALLET', 'getPlexCount($characterId) - SUCCESS');
      return count;
    } catch (e, stack) {
      Log.e('WALLET', 'getPlexCount($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Gets total loyalty points across all corporations.
  Future<int> getTotalLoyaltyPoints(int characterId) async {
    Log.d('WALLET', 'getTotalLoyaltyPoints($characterId) - START');
    try {
      final lpEntries = await _database.getLoyaltyPoints(characterId);
      final total =
          lpEntries.fold<int>(0, (sum, entry) => sum + entry.loyaltyPoints);
      Log.i('WALLET',
          'getTotalLoyaltyPoints - total: $total LP across ${lpEntries.length} corporations');
      Log.d('WALLET', 'getTotalLoyaltyPoints($characterId) - SUCCESS');
      return total;
    } catch (e, stack) {
      Log.e('WALLET', 'getTotalLoyaltyPoints($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Gets loyalty points by corporation.
  Future<List<LoyaltyPoint>> getLoyaltyPointsByCorporation(
      int characterId) async {
    Log.d('WALLET', 'getLoyaltyPointsByCorporation($characterId) - START');
    try {
      final lpEntries = await _database.getLoyaltyPoints(characterId);
      Log.i('WALLET',
          'getLoyaltyPointsByCorporation - found ${lpEntries.length} corporations');
      Log.d('WALLET', 'getLoyaltyPointsByCorporation($characterId) - SUCCESS');
      return lpEntries;
    } catch (e, stack) {
      Log.e('WALLET', 'getLoyaltyPointsByCorporation($characterId) - FAILED', e,
          stack);
      rethrow;
    }
  }

  /// Gets 30-day wallet summary (income/expenses).
  Future<WalletSummary> get30DaySummary(int characterId) async {
    Log.d('WALLET', 'get30DaySummary($characterId) - START');
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      Log.d('WALLET',
          'get30DaySummary - querying journal since ${thirtyDaysAgo.toIso8601String()}');

      // Get all journal entries from the last 30 days.
      final allEntries = await _database.getWalletJournal(characterId, limit: 10000);
      final recentEntries =
          allEntries.where((entry) => entry.date.isAfter(thirtyDaysAgo)).toList();
      Log.i('WALLET',
          'get30DaySummary - analyzing ${recentEntries.length} journal entries from last 30 days');

      // Calculate income and expenses.
      double income = 0;
      double expenses = 0;
      for (final entry in recentEntries) {
        if (entry.amount >= 0) {
          income += entry.amount;
        } else {
          expenses += entry.amount.abs();
        }
      }

      Log.i('WALLET',
          'get30DaySummary - income: $income ISK, expenses: $expenses ISK, net: ${income - expenses} ISK');
      Log.d('WALLET', 'get30DaySummary($characterId) - SUCCESS');
      return WalletSummary(income: income, expenses: expenses);
    } catch (e, stack) {
      Log.e('WALLET', 'get30DaySummary($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Watches wallet transactions for reactive updates.
  Stream<List<WalletTransaction>> watchWalletTransactions(
    int characterId, {
    int limit = 100,
  }) {
    Log.d('WALLET',
        'watchWalletTransactions($characterId, limit=$limit) - subscribed to stream');
    return _database.watchWalletTransactions(characterId, limit: limit);
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

/// Wallet summary for a time period (income/expenses).
class WalletSummary {
  final double income;
  final double expenses;

  const WalletSummary({
    required this.income,
    required this.expenses,
  });

  /// Net change (income - expenses).
  double get net => income - expenses;
}

/// Provider for the wallet repository.
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
});

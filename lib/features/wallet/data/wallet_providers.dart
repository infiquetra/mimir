import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import '../../../core/utils/formatters.dart';
import '../../characters/data/character_providers.dart';
import '../../characters/data/character_status_providers.dart';
import 'wallet_repository.dart';

/// Provider that streams the wallet journal for the active character.
final walletJournalProvider = StreamProvider<List<WalletJournalEntry>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('WALLET', 'walletJournalProvider - no active character, returning empty stream');
    return Stream.value([]);
  }

  Log.d('WALLET', 'walletJournalProvider - setting up stream for character ${activeCharacter.characterId}');
  final repository = ref.watch(walletRepositoryProvider);
  return repository.watchWalletJournal(activeCharacter.characterId);
});

/// Provider for refreshing wallet data (balance + journal) from ESI.
final refreshWalletProvider =
    FutureProvider.family<double, int>((ref, characterId) async {
  Log.i('WALLET', 'refreshWalletProvider - invoked for character $characterId');
  final repository = ref.read(walletRepositoryProvider);

  // Refresh both balance and journal.
  Log.d('WALLET', 'refreshWalletProvider - refreshing balance and journal');
  final balance = await repository.refreshWalletBalance(characterId);
  await repository.refreshWalletJournal(characterId);

  Log.i('WALLET', 'refreshWalletProvider - completed, balance: $balance ISK');
  return balance;
});

/// Provider for the current wallet balance.
///
/// Returns the balance from the most recent journal entry, or fetches from ESI.
final walletBalanceProvider = FutureProvider<double?>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('WALLET', 'walletBalanceProvider - no active character');
    return null;
  }

  Log.d('WALLET', 'walletBalanceProvider - fetching for character ${activeCharacter.characterId}');
  final repository = ref.read(walletRepositoryProvider);
  return repository.getLatestWalletBalance(activeCharacter.characterId);
});

/// Provider that formats a wallet balance as ISK.
///
/// Example: 1234567.89 → "1,234,567.89 ISK"
final formattedBalanceProvider =
    Provider.family<String, double>((ref, balance) {
  return formatIsk(balance);
});

/// Provider for PLEX count.
final plexCountProvider = FutureProvider<int>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('WALLET', 'plexCountProvider - no active character');
    return 0;
  }

  Log.d('WALLET',
      'plexCountProvider - fetching for character ${activeCharacter.characterId}');
  final repository = ref.read(walletRepositoryProvider);
  return repository.getPlexCount(activeCharacter.characterId);
});

/// Provider for total loyalty points across all corporations.
final totalLoyaltyPointsProvider = FutureProvider<int>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('WALLET', 'totalLoyaltyPointsProvider - no active character');
    return 0;
  }

  Log.d('WALLET',
      'totalLoyaltyPointsProvider - fetching for character ${activeCharacter.characterId}');
  final repository = ref.read(walletRepositoryProvider);
  return repository.getTotalLoyaltyPoints(activeCharacter.characterId);
});

/// Provider for loyalty points by corporation.
final loyaltyPointsByCorporationProvider =
    FutureProvider<List<LoyaltyPoint>>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('WALLET', 'loyaltyPointsByCorporationProvider - no active character');
    return [];
  }

  Log.d('WALLET',
      'loyaltyPointsByCorporationProvider - fetching for character ${activeCharacter.characterId}');
  final repository = ref.read(walletRepositoryProvider);
  return repository.getLoyaltyPointsByCorporation(activeCharacter.characterId);
});

/// Provider for 30-day wallet summary (income/expenses).
final walletSummaryProvider = FutureProvider<WalletSummary>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('WALLET', 'walletSummaryProvider - no active character');
    return const WalletSummary(income: 0, expenses: 0);
  }

  Log.d('WALLET',
      'walletSummaryProvider - fetching for character ${activeCharacter.characterId}');
  final repository = ref.read(walletRepositoryProvider);
  return repository.get30DaySummary(activeCharacter.characterId);
});

/// Provider that streams wallet transactions for the active character.
final walletTransactionsProvider =
    StreamProvider<List<WalletTransaction>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).value;
  if (activeCharacter == null) {
    Log.d('WALLET',
        'walletTransactionsProvider - no active character, returning empty stream');
    return Stream.value([]);
  }

  Log.d('WALLET',
      'walletTransactionsProvider - setting up stream for character ${activeCharacter.characterId}');
  final repository = ref.watch(walletRepositoryProvider);
  return repository.watchWalletTransactions(activeCharacter.characterId);
});

/// Filter for wallet journal transactions.
class TransactionFilter {
  final String? refType;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({
    this.refType,
    this.startDate,
    this.endDate,
  });

  /// Creates a filter for a specific date range.
  factory TransactionFilter.dateRange(int days) {
    final now = DateTime.now();
    return TransactionFilter(
      startDate: now.subtract(Duration(days: days)),
      endDate: now,
    );
  }

  /// Last 7 days filter.
  static TransactionFilter get last7Days => TransactionFilter.dateRange(7);

  /// Last 30 days filter.
  static TransactionFilter get last30Days => TransactionFilter.dateRange(30);

  /// Last 90 days filter.
  static TransactionFilter get last90Days => TransactionFilter.dateRange(90);
}

/// Filter for market transactions.
class MarketFilter {
  final bool? isBuy; // true = buy, false = sell, null = all
  final int? minQuantity;
  final double? minValue;
  final int? typeId;

  const MarketFilter({
    this.isBuy,
    this.minQuantity,
    this.minValue,
    this.typeId,
  });

  /// No filter (show all).
  static const MarketFilter all = MarketFilter();

  /// Buy transactions only.
  static const MarketFilter buys = MarketFilter(isBuy: true);

  /// Sell transactions only.
  static const MarketFilter sells = MarketFilter(isBuy: false);
}

/// Provider to resolve type IDs to item names.
///
/// Uses the CharacterStatusRepository's hybrid caching strategy
/// (memory → database → ESI) to efficiently resolve item names.
/// Works for ANY EVE type ID: ships, modules, skills, etc.
///
/// Returns the item name or "Unknown Item" if not found.
final itemNameProvider = FutureProvider.family<String, int>((ref, typeId) async {
  Log.d('WALLET.ITEM', 'itemNameProvider($typeId) - START');

  final repository = ref.watch(characterStatusRepositoryProvider);

  try {
    final name = await repository.resolveName(typeId);
    final result = name ?? 'Unknown Item';
    Log.d('WALLET.ITEM', 'itemNameProvider($typeId) → $result');
    return result;
  } catch (e, stack) {
    Log.e('WALLET.ITEM', 'itemNameProvider($typeId) - FAILED', e, stack);
    return 'Unknown Item';
  }
});

/// Provider to resolve location IDs to location names.
///
/// Uses the CharacterStatusRepository's hybrid caching strategy
/// (memory → database → ESI) to efficiently resolve location names.
///
/// Returns the location name or "Unknown Location" if not found.
final locationNameProvider = FutureProvider.family<String, int>((ref, locationId) async {
  Log.d('WALLET.LOCATION', 'locationNameProvider($locationId) - START');

  final repository = ref.watch(characterStatusRepositoryProvider);

  try {
    final name = await repository.resolveName(locationId);
    final result = name ?? 'Unknown Location';
    Log.d('WALLET.LOCATION', 'locationNameProvider($locationId) → $result');
    return result;
  } catch (e, stack) {
    Log.e('WALLET.LOCATION', 'locationNameProvider($locationId) - FAILED', e, stack);
    return 'Unknown Location';
  }
});

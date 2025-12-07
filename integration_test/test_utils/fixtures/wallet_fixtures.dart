import 'package:drift/drift.dart';
import 'package:mimir/core/database/app_database.dart';

/// Test fixtures for wallet data.
///
/// Provides pre-built wallet-related companion objects for integration tests:
/// - WalletJournalEntriesCompanion
/// - WalletTransactionsCompanion
/// - LoyaltyPointsCompanion
/// - AssetCacheCompanion
///
/// These align with MockEsiClient test data for consistency.
class WalletFixtures {
  // =========================================================================
  // Wallet Journal Fixtures
  // =========================================================================

  /// Bounty prize journal entry (100M ISK income).
  static WalletJournalEntriesCompanion journalBountyPrize({
    required int characterId,
  }) {
    return WalletJournalEntriesCompanion.insert(
      id: const Value(1),
      characterId: characterId,
      amount: 100000000.0,
      balance: 1500000000.0,
      refType: 'bounty_prizes',
      firstPartyId: Value(characterId),
      secondPartyId: const Value(null),
      description: const Value('Bounty prize'),
      date: DateTime.now().subtract(const Duration(hours: 1)),
    );
  }

  /// Market transaction journal entry (50M ISK expense).
  static WalletJournalEntriesCompanion journalMarketPurchase({
    required int characterId,
  }) {
    return WalletJournalEntriesCompanion.insert(
      id: const Value(2),
      characterId: characterId,
      amount: -50000000.0,
      balance: 1400000000.0,
      refType: 'market_transaction',
      firstPartyId: Value(characterId),
      secondPartyId: const Value(98765432),
      description: const Value('Market purchase'),
      date: DateTime.now().subtract(const Duration(hours: 3)),
    );
  }

  /// Player trading journal entry (25M ISK income).
  static WalletJournalEntriesCompanion journalPlayerTrade({
    required int characterId,
  }) {
    return WalletJournalEntriesCompanion.insert(
      id: const Value(3),
      characterId: characterId,
      amount: 25000000.0,
      balance: 1425000000.0,
      refType: 'player_trading',
      firstPartyId: Value(characterId),
      secondPartyId: const Value(11111111),
      description: const Value('Trade'),
      date: DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  /// Get all wallet journal entries for a character.
  static List<WalletJournalEntriesCompanion> allJournalEntries({
    required int characterId,
  }) {
    return [
      journalBountyPrize(characterId: characterId),
      journalMarketPurchase(characterId: characterId),
      journalPlayerTrade(characterId: characterId),
    ];
  }

  // =========================================================================
  // Wallet Transaction Fixtures
  // =========================================================================

  /// Market buy transaction - Rifter purchase.
  static WalletTransactionsCompanion transactionBuyRifter({
    required int characterId,
  }) {
    return WalletTransactionsCompanion.insert(
      transactionId: const Value(1),
      characterId: characterId,
      typeId: 587, // Rifter
      locationId: 60003760, // Jita IV - Moon 4 - Caldari Navy Assembly Plant
      unitPrice: 100000.0,
      quantity: 1,
      isBuy: true,
      clientId: 98765432,
      date: DateTime.now().subtract(const Duration(hours: 2)),
      journalRefId: const Value(2),
    );
  }

  /// Market sell transaction - PLEX sale.
  static WalletTransactionsCompanion transactionSellPlex({
    required int characterId,
  }) {
    return WalletTransactionsCompanion.insert(
      transactionId: const Value(2),
      characterId: characterId,
      typeId: 44992, // PLEX
      locationId: 60003760, // Jita
      unitPrice: 3500000.0,
      quantity: 10,
      isBuy: false,
      clientId: 11111111,
      date: DateTime.now().subtract(const Duration(days: 1)),
      journalRefId: const Value(3),
    );
  }

  /// Get all wallet transactions for a character.
  static List<WalletTransactionsCompanion> allTransactions({
    required int characterId,
  }) {
    return [
      transactionBuyRifter(characterId: characterId),
      transactionSellPlex(characterId: characterId),
    ];
  }

  // =========================================================================
  // Loyalty Points Fixtures
  // =========================================================================

  /// Serpentis Corporation loyalty points.
  static LoyaltyPointsCompanion loyaltySerpentis({
    required int characterId,
  }) {
    return LoyaltyPointsCompanion.insert(
      characterId: characterId,
      corporationId: 1000125, // Serpentis Corporation
      loyaltyPoints: 15000,
      lastUpdated: DateTime.now(),
    );
  }

  /// Caldari Navy loyalty points.
  static LoyaltyPointsCompanion loyaltyCaldariNavy({
    required int characterId,
  }) {
    return LoyaltyPointsCompanion.insert(
      characterId: characterId,
      corporationId: 1000035, // Caldari Navy
      loyaltyPoints: 8500,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get all loyalty points for a character.
  static List<LoyaltyPointsCompanion> allLoyaltyPoints({
    required int characterId,
  }) {
    return [
      loyaltySerpentis(characterId: characterId),
      loyaltyCaldariNavy(characterId: characterId),
    ];
  }

  // =========================================================================
  // Asset Cache Fixtures
  // =========================================================================

  /// PLEX asset cache entry (50 PLEX in Jita).
  static AssetCacheCompanion assetPlex({
    required int characterId,
  }) {
    return AssetCacheCompanion.insert(
      itemId: const Value(1001),
      characterId: characterId,
      typeId: 44992, // PLEX
      quantity: 50,
      locationId: 60003760, // Jita
      lastUpdated: DateTime.now(),
    );
  }

  /// Get all assets for a character.
  static List<AssetCacheCompanion> allAssets({
    required int characterId,
  }) {
    return [
      assetPlex(characterId: characterId),
    ];
  }

  // =========================================================================
  // Helper Methods
  // =========================================================================

  /// Insert full wallet data for a character (all tables).
  ///
  /// Returns a map of companion lists for batch insertion:
  /// - 'journal': List<WalletJournalEntriesCompanion>
  /// - 'transactions': List<WalletTransactionsCompanion>
  /// - 'loyaltyPoints': List<LoyaltyPointsCompanion>
  /// - 'assets': List<AssetCacheCompanion>
  static Map<String, List<Object>> fullWalletData({
    required int characterId,
  }) {
    return {
      'journal': allJournalEntries(characterId: characterId),
      'transactions': allTransactions(characterId: characterId),
      'loyaltyPoints': allLoyaltyPoints(characterId: characterId),
      'assets': allAssets(characterId: characterId),
    };
  }
}

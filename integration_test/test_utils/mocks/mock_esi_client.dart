import 'package:mimir/core/network/esi_client.dart';
import 'package:mocktail/mocktail.dart';

/// Mock ESI client for integration testing.
///
/// Provides pre-configured test data for common scenarios:
/// - Valid character data
/// - Skill queues (empty and active)
/// - Wallet balances and transactions
/// - Location and item name resolution
class MockEsiClient extends Mock implements EsiClient {
  // =========================================================================
  // Test Character Data
  // =========================================================================

  static final testCharacter = CharacterPublicInfo(
    corporationId: 98000001,
    birthday: DateTime(2015, 1, 1),
    name: 'Test Capsuleer',
    allianceId: 99000001,
    securityStatus: 5.0,
  );

  static final testCharacter2 = CharacterPublicInfo(
    corporationId: 98000002,
    birthday: DateTime(2016, 6, 15),
    name: 'Second Test Character',
    allianceId: null,
    securityStatus: -2.5,
  );

  // =========================================================================
  // Skill Queue Test Data
  // =========================================================================

  static final emptySkillQueue = <SkillQueueItem>[];

  static final activeSkillQueue = [
    SkillQueueItem(
      queuePosition: 0,
      skillId: 3301, // Mechanics
      finishedLevel: 5,
      startDate: DateTime.now().subtract(const Duration(hours: 2)),
      finishDate: DateTime.now().add(const Duration(hours: 6)),
      trainingStartSp: 226275,
      levelEndSp: 256000,
      levelStartSp: 181020,
    ),
    SkillQueueItem(
      queuePosition: 1,
      skillId: 3392, // Engineering
      finishedLevel: 4,
      startDate: DateTime.now().add(const Duration(hours: 6)),
      finishDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
      trainingStartSp: 22627,
      levelEndSp: 45255,
      levelStartSp: 5657,
    ),
    SkillQueueItem(
      queuePosition: 2,
      skillId: 3327, // Spaceship Command
      finishedLevel: 5,
      startDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
      finishDate: DateTime.now().add(const Duration(days: 3, hours: 12)),
      trainingStartSp: 0,
      levelEndSp: 256000,
      levelStartSp: 0,
    ),
  ];

  // =========================================================================
  // Wallet Test Data
  // =========================================================================

  static const walletBalance = 1500000000.0; // 1.5B ISK

  static final walletJournal = [
    WalletJournalItem(
      id: 1,
      amount: 100000000.0,
      balance: 1500000000.0,
      refType: 'bounty_prizes',
      firstPartyId: 12345678,
      secondPartyId: null,
      description: 'Bounty prize',
      date: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    WalletJournalItem(
      id: 2,
      amount: -50000000.0,
      balance: 1400000000.0,
      refType: 'market_transaction',
      firstPartyId: 12345678,
      secondPartyId: 98765432,
      description: 'Market purchase',
      date: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    WalletJournalItem(
      id: 3,
      amount: 25000000.0,
      balance: 1425000000.0,
      refType: 'player_trading',
      firstPartyId: 12345678,
      secondPartyId: 11111111,
      description: 'Trade',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static final walletTransactions = [
    WalletTransactionItem(
      transactionId: 1,
      typeId: 587, // Rifter
      locationId: 60003760, // Jita
      unitPrice: 100000.0,
      quantity: 1,
      isBuy: true,
      clientId: 98765432,
      date: DateTime.now().subtract(const Duration(hours: 2)),
      journalRefId: 2,
    ),
    WalletTransactionItem(
      transactionId: 2,
      typeId: 44992, // PLEX
      locationId: 60003760, // Jita
      unitPrice: 3500000.0,
      quantity: 10,
      isBuy: false,
      clientId: 11111111,
      date: DateTime.now().subtract(const Duration(days: 1)),
      journalRefId: 3,
    ),
  ];

  static final loyaltyPoints = [
    LoyaltyPointItem(
      corporationId: 1000125, // Serpentis Corporation
      loyaltyPoints: 15000,
    ),
    LoyaltyPointItem(
      corporationId: 1000035, // Caldari Navy
      loyaltyPoints: 8500,
    ),
  ];

  static final plexAssets = [
    AssetItem(
      itemId: 1001,
      typeId: 44992, // PLEX
      quantity: 50,
      locationId: 60003760, // Jita
      locationFlag: 'Hangar',
      isSingleton: false,
    ),
  ];

  // =========================================================================
  // Clone & Implant Test Data
  // =========================================================================

  static final cloneInfo = CharacterClones(
    homeLocation: HomeLocation(
      locationId: 60003760, // Jita
      locationType: 'station',
    ),
    lastCloneJumpDate: DateTime.now().subtract(const Duration(days: 3)),
    lastStationChangeDate: DateTime.now().subtract(const Duration(days: 1)),
    jumpClones: [
      JumpClone(
        jumpCloneId: 101,
        locationId: 60008494, // Amarr
        locationType: 'station',
        implants: [22118, 22119], // Basic implants
      ),
      JumpClone(
        jumpCloneId: 102,
        locationId: 60011866, // Dodixie
        locationType: 'station',
        implants: [],
      ),
    ],
  );

  static final implants = [
    22118, // Memory Augmentation - Basic
    22119, // Neural Boost - Basic
  ];

  // =========================================================================
  // Standings Test Data
  // =========================================================================

  static final standings = [
    Standing(
      fromId: 500001, // Caldari State
      fromType: 'faction',
      standing: 5.5,
    ),
    Standing(
      fromId: 500004, // Minmatar Republic
      fromType: 'faction',
      standing: -2.0,
    ),
    Standing(
      fromId: 1000125, // Serpentis Corporation
      fromType: 'npc_corp',
      standing: 3.2,
    ),
  ];

  // =========================================================================
  // Fleet Status Test Data
  // =========================================================================

  static final online = CharacterOnline(
    online: true,
    lastLogin: DateTime.now().subtract(const Duration(hours: 2)),
    lastLogout: DateTime.now().subtract(const Duration(hours: 8)),
    logins: 42,
  );

  static final offline = CharacterOnline(
    online: false,
    lastLogin: DateTime.now().subtract(const Duration(days: 1)),
    lastLogout: DateTime.now().subtract(const Duration(hours: 3)),
    logins: 25,
  );

  static final location = CharacterLocation(
    solarSystemId: 30000142, // Jita
    stationId: 60003760, // Jita IV - Moon 4
    structureId: null,
  );

  static final ship = CharacterShip(
    shipTypeId: 587, // Rifter
    shipTypeName: null, // Looked up from SDE
    shipItemId: 1234567890,
  );

  // =========================================================================
  // Name Resolution Test Data
  // =========================================================================

  static final nameResolutions = <int, String>{
    // Type IDs (items, ships, skills)
    587: 'Rifter',
    44992: 'PLEX',
    3301: 'Mechanics',
    3392: 'Engineering',
    3327: 'Spaceship Command',
    22118: 'Memory Augmentation - Basic',
    22119: 'Neural Boost - Basic',

    // Location IDs (stations, structures)
    60003760: 'Jita IV - Moon 4 - Caldari Navy Assembly Plant',
    60008494: 'Amarr VIII (Oris) - Emperor Family Academy',
    60011866: 'Dodixie IX - Moon 20 - Federation Navy Assembly Plant',
    30000142: 'Jita', // Solar system

    // Character/Corporation/Alliance IDs
    12345678: 'Test Capsuleer',
    98765432: 'Test Trader',
    11111111: 'Test Buyer',
    98000001: 'Test Corporation',
    98000002: 'Second Test Corporation',
    99000001: 'Test Alliance',

    // NPC Corporations and Factions
    500001: 'Caldari State',
    500004: 'Minmatar Republic',
    1000125: 'Serpentis Corporation',
    1000035: 'Caldari Navy',
  };

  // =========================================================================
  // Helper Methods for Test Setup
  // =========================================================================

  /// Sets up the mock to return the default test character.
  void setupDefaultCharacter(int characterId) {
    when(() => getCharacterPublicInfo(characterId))
        .thenAnswer((_) async => testCharacter);
  }

  /// Sets up the mock to return an active skill queue.
  void setupActiveSkillQueue(int characterId) {
    when(() => getSkillQueue(characterId))
        .thenAnswer((_) async => activeSkillQueue);
  }

  /// Sets up the mock to return an empty skill queue.
  void setupEmptySkillQueue(int characterId) {
    when(() => getSkillQueue(characterId))
        .thenAnswer((_) async => emptySkillQueue);
  }

  /// Sets up the mock to return wallet data.
  void setupWalletData(int characterId) {
    when(() => getWalletBalance(characterId))
        .thenAnswer((_) async => walletBalance);
    when(() => getWalletJournal(characterId))
        .thenAnswer((_) async => walletJournal);
    when(() => getWalletTransactions(characterId))
        .thenAnswer((_) async => walletTransactions);
    when(() => getLoyaltyPoints(characterId))
        .thenAnswer((_) async => loyaltyPoints);
  }

  /// Sets up the mock to return clone and implant data.
  void setupCloneData(int characterId) {
    when(() => getCharacterClones(characterId)).thenAnswer((_) async => cloneInfo);
    when(() => getCharacterImplants(characterId)).thenAnswer((_) async => implants);
  }

  /// Sets up the mock to return standings data.
  void setupStandings(int characterId) {
    when(() => getCharacterStandings(characterId)).thenAnswer((_) async => standings);
  }

  /// Sets up the mock to return fleet status data (online, location, ship).
  void setupFleetStatus(int characterId, {bool isOnline = true}) {
    when(() => getCharacterOnline(characterId))
        .thenAnswer((_) async => isOnline ? online : offline);
    when(() => getCharacterLocation(characterId))
        .thenAnswer((_) async => location);
    when(() => getCharacterShip(characterId))
        .thenAnswer((_) async => ship);
  }

  /// Sets up the mock to resolve names via universe/names endpoint.
  void setupNameResolution() {
    when(() => getUniverseNames(any())).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments[0] as List<int>;
      return ids
          .where((id) => nameResolutions.containsKey(id))
          .map((id) => UniverseName(
                id: id,
                name: nameResolutions[id]!,
                category: _getCategoryForId(id),
              ))
          .toList();
    });
  }

  /// Helper to determine category based on ID range.
  static String _getCategoryForId(int id) {
    if (id >= 1 && id < 100000) return 'inventory_type';
    if (id >= 30000000 && id < 40000000) return 'solar_system';
    if (id >= 60000000 && id < 70000000) return 'station';
    if (id >= 98000000 && id < 100000000) return 'corporation';
    if (id >= 99000000) return 'alliance';
    return 'character';
  }

  /// Sets up the mock with all default test data for a character.
  void setupFullCharacterData(int characterId) {
    setupDefaultCharacter(characterId);
    setupActiveSkillQueue(characterId);
    setupWalletData(characterId);
    setupCloneData(characterId);
    setupStandings(characterId);
    setupFleetStatus(characterId); // Fleet status (online, location, ship)
    setupNameResolution();
  }

  /// Sets up the mock to throw an error for the next call.
  void setupError(String methodName, Exception error) {
    // Example usage in tests:
    // mockEsiClient.setupError('getWalletBalance', EsiException('Network error', statusCode: 500));
  }
}

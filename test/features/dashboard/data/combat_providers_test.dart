import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/dashboard/data/combat_providers.dart';
import 'package:mimir/features/dashboard/data/zkillboard_client.dart';

class MockZkillboardClient extends Mock implements ZkillboardClient {}

class MockEsiClient extends Mock implements EsiClient {}

void main() {
  group('CombatStatsData', () {
    test('should calculate K/D ratio correctly', () {
      const stats = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      expect(stats.kdRatio, 2.0);
    });

    test('should handle zero deaths for K/D ratio', () {
      const stats = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 100,
        deaths: 0,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      expect(stats.kdRatio, 100.0);
    });

    test('should calculate danger rating correctly', () {
      const stats = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      expect(stats.dangerRating, 50);
    });

    test('should calculate net ISK correctly', () {
      const stats = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      expect(stats.netIsk, 5000000000.0);
    });

    test('should detect activity correctly', () {
      const statsWithActivity = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      const statsNoActivity = CombatStatsData(
        characterId: 1,
        characterName: 'Test Character',
        kills: 0,
        deaths: 0,
        iskDestroyed: 0.0,
        iskLost: 0.0,
      );

      expect(statsWithActivity.hasActivity, isTrue);
      expect(statsNoActivity.hasActivity, isFalse);
    });
  });

  group('AggregateCombatStats', () {
    test('should calculate overall K/D ratio correctly', () {
      const stats = AggregateCombatStats(
        totalKills: 200,
        totalDeaths: 100,
        totalIskDestroyed: 20000000000.0,
        totalIskLost: 10000000000.0,
        characterStats: [],
      );

      expect(stats.kdRatio, 2.0);
    });

    test('should handle zero deaths for overall K/D ratio', () {
      const stats = AggregateCombatStats(
        totalKills: 200,
        totalDeaths: 0,
        totalIskDestroyed: 20000000000.0,
        totalIskLost: 10000000000.0,
        characterStats: [],
      );

      expect(stats.kdRatio, 200.0);
    });

    test('should calculate overall danger rating correctly', () {
      const stats = AggregateCombatStats(
        totalKills: 200,
        totalDeaths: 100,
        totalIskDestroyed: 20000000000.0,
        totalIskLost: 10000000000.0,
        characterStats: [],
      );

      expect(stats.dangerRating, 100);
    });

    test('should calculate net ISK correctly', () {
      const stats = AggregateCombatStats(
        totalKills: 200,
        totalDeaths: 100,
        totalIskDestroyed: 20000000000.0,
        totalIskLost: 10000000000.0,
        characterStats: [],
      );

      expect(stats.netIsk, 10000000000.0);
    });

    test('should detect activity correctly', () {
      const statsWithActivity = AggregateCombatStats(
        totalKills: 200,
        totalDeaths: 100,
        totalIskDestroyed: 20000000000.0,
        totalIskLost: 10000000000.0,
        characterStats: [],
      );

      const statsNoActivity = AggregateCombatStats(
        totalKills: 0,
        totalDeaths: 0,
        totalIskDestroyed: 0.0,
        totalIskLost: 0.0,
        characterStats: [],
      );

      expect(statsWithActivity.hasActivity, isTrue);
      expect(statsNoActivity.hasActivity, isFalse);
    });

    test('should count active characters correctly', () {
      const char1 = CombatStatsData(
        characterId: 1,
        characterName: 'Character 1',
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      const char2 = CombatStatsData(
        characterId: 2,
        characterName: 'Character 2',
        kills: 0,
        deaths: 0,
        iskDestroyed: 0.0,
        iskLost: 0.0,
      );

      const stats = AggregateCombatStats(
        totalKills: 100,
        totalDeaths: 50,
        totalIskDestroyed: 10000000000.0,
        totalIskLost: 5000000000.0,
        characterStats: [char1, char2],
      );

      expect(stats.activeCharacterCount, 1);
    });
  });

  group('combatStatsProvider', () {
    late AppDatabase database;
    late MockZkillboardClient mockZkillboardClient;
    late MockEsiClient mockEsiClient;
    late ProviderContainer container;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      mockZkillboardClient = MockZkillboardClient();
      mockEsiClient = MockEsiClient();

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          zkillboardClientProvider.overrideWithValue(mockZkillboardClient),
          esiClientProvider.overrideWithValue(mockEsiClient),
        ],
      );
    });

    tearDown(() async {
      await database.close();
      container.dispose();
    });

    test('should fetch from zkillboard when no cache exists', () async {
      // Arrange
      const characterId = 12345;
      final character = CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98765,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/portrait.jpg',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      );
      await database.upsertCharacter(character);

      final zkbStats = const ZkillboardStats(
        kills: 100,
        deaths: 50,
        iskDestroyed: 10000000000.0,
        iskLost: 5000000000.0,
      );

      when(() => mockZkillboardClient.getCharacterStats(characterId))
          .thenAnswer((_) async => zkbStats);

      // Act
      final result = await container.read(combatStatsProvider(characterId).future);

      // Assert
      expect(result, isNotNull);
      expect(result!.characterId, characterId);
      expect(result.characterName, 'Test Character');
      expect(result.kills, 100);
      expect(result.deaths, 50);
      expect(result.iskDestroyed, 10000000000.0);
      expect(result.iskLost, 5000000000.0);

      verify(() => mockZkillboardClient.getCharacterStats(characterId)).called(1);

      // Verify data was cached
      final cached = await database.getCombatStats(characterId);
      expect(cached, isNotNull);
      expect(cached!.kills, 100);
      expect(cached.deaths, 50);
    }, skip: 'StreamProvider tests require widget context - moved to integration tests');

    test('should return cached data if fresh', () async {
      // Arrange
      const characterId = 12345;
      final character = CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98765,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/portrait.jpg',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      );
      await database.upsertCharacter(character);

      // Insert fresh cache
      await database.upsertCombatStats(
        CombatStatsCompanion.insert(
          characterId: Value(characterId),
          kills: const Value(75),
          deaths: const Value(25),
          iskDestroyed: const Value(8000000000.0),
          iskLost: const Value(2000000000.0),
          lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      );

      // Act
      final result = await container.read(combatStatsProvider(characterId).future);

      // Assert
      expect(result, isNotNull);
      expect(result!.kills, 75);
      expect(result.deaths, 25);

      // Should not call zkillboard API
      verifyNever(() => mockZkillboardClient.getCharacterStats(characterId));
    });

    test('should return null when character has no killboard data', () async {
      // Arrange
      const characterId = 12345;
      final character = CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98765,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/portrait.jpg',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      );
      await database.upsertCharacter(character);

      when(() => mockZkillboardClient.getCharacterStats(characterId))
          .thenAnswer((_) async => null);

      // Act
      final result = await container.read(combatStatsProvider(characterId).future);

      // Assert
      expect(result, isNull);

      // Verify zero-stats entry was cached
      final cached = await database.getCombatStats(characterId);
      expect(cached, isNotNull);
      expect(cached!.kills, 0);
      expect(cached.deaths, 0);
    });

    test('should return cached data on zkillboard error', () async {
      // Arrange
      const characterId = 12345;
      final character = CharactersCompanion.insert(
        characterId: const Value(characterId),
        name: 'Test Character',
        corporationId: 98765,
        corporationName: 'Test Corp',
        portraitUrl: 'https://example.com/portrait.jpg',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        lastUpdated: DateTime.now(),
      );
      await database.upsertCharacter(character);

      // Insert stale cache
      await database.upsertCombatStats(
        CombatStatsCompanion.insert(
          characterId: Value(characterId),
          kills: const Value(75),
          deaths: const Value(25),
          iskDestroyed: const Value(8000000000.0),
          iskLost: const Value(2000000000.0),
          lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );

      when(() => mockZkillboardClient.getCharacterStats(characterId))
          .thenThrow(const ZkillboardException('Server error', statusCode: 500));

      // Act
      final result = await container.read(combatStatsProvider(characterId).future);

      // Assert - should return cached data despite error
      expect(result, isNotNull);
      expect(result!.kills, 75);
      expect(result.deaths, 25);
    });
  });
}

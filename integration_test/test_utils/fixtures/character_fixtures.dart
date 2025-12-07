import 'package:drift/drift.dart';
import 'package:mimir/core/database/app_database.dart';

/// Test fixtures for character data.
///
/// Provides pre-built CharactersCompanion objects for integration tests.
/// These align with MockEsiClient test data for consistency.
class CharacterFixtures {
  // =========================================================================
  // Primary Test Character
  // =========================================================================

  /// Primary test character - "Test Capsuleer".
  ///
  /// Corp: Test Corporation (98000001)
  /// Alliance: Test Alliance (99000001)
  /// Security: 5.0
  static CharactersCompanion testCharacter({
    bool isActive = true,
  }) {
    return CharactersCompanion.insert(
      characterId: const Value(12345678),
      name: 'Test Capsuleer',
      corporationId: 98000001,
      corporationName: 'Test Corporation',
      allianceId: const Value(99000001),
      allianceName: const Value('Test Alliance'),
      factionId: const Value(null),
      securityStatus: const Value(5.0),
      portraitUrl:
          'https://images.evetech.net/characters/12345678/portrait?size=128',
      refreshToken: const Value('test_refresh_token_1'),
      accessToken: const Value('test_access_token_1'),
      tokenExpiry: DateTime.now().add(const Duration(minutes: 20)),
      lastUpdated: DateTime.now(),
      isActive: Value(isActive),
    );
  }

  // =========================================================================
  // Secondary Test Character
  // =========================================================================

  /// Secondary test character - "Second Test Character".
  ///
  /// Corp: Second Test Corporation (98000002)
  /// Alliance: None
  /// Security: -2.5 (outlaw)
  static CharactersCompanion testCharacter2({
    bool isActive = false,
  }) {
    return CharactersCompanion.insert(
      characterId: const Value(23456789),
      name: 'Second Test Character',
      corporationId: 98000002,
      corporationName: 'Second Test Corporation',
      allianceId: const Value(null),
      allianceName: const Value(null),
      factionId: const Value(null),
      securityStatus: const Value(-2.5),
      portraitUrl:
          'https://images.evetech.net/characters/23456789/portrait?size=128',
      refreshToken: const Value('test_refresh_token_2'),
      accessToken: const Value('test_access_token_2'),
      tokenExpiry: DateTime.now().add(const Duration(minutes: 20)),
      lastUpdated: DateTime.now(),
      isActive: Value(isActive),
    );
  }

  // =========================================================================
  // Helper Methods
  // =========================================================================

  /// Get a list of all test characters for multi-character tests.
  static List<CharactersCompanion> allCharacters() {
    return [
      testCharacter(isActive: true),
      testCharacter2(isActive: false),
    ];
  }

  /// Create a custom test character with override values.
  static CharactersCompanion customCharacter({
    required int characterId,
    required String name,
    required int corporationId,
    required String corporationName,
    int? allianceId,
    String? allianceName,
    double securityStatus = 0.0,
    bool isActive = false,
  }) {
    return CharactersCompanion.insert(
      characterId: Value(characterId),
      name: name,
      corporationId: corporationId,
      corporationName: corporationName,
      allianceId: Value(allianceId),
      allianceName: Value(allianceName),
      securityStatus: Value(securityStatus),
      portraitUrl:
          'https://images.evetech.net/characters/$characterId/portrait?size=128',
      refreshToken: Value('test_refresh_token_$characterId'),
      accessToken: Value('test_access_token_$characterId'),
      tokenExpiry: DateTime.now().add(const Duration(minutes: 20)),
      lastUpdated: DateTime.now(),
      isActive: Value(isActive),
    );
  }
}

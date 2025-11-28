import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/esi_client.dart';

/// Repository for managing character data.
///
/// Coordinates between:
/// - ESI client for fetching fresh data
/// - Local database for caching and offline access
class CharacterRepository {
  final AppDatabase _database;
  final EsiClient _esiClient;

  CharacterRepository({
    required AppDatabase database,
    required EsiClient esiClient,
  })  : _database = database,
        _esiClient = esiClient;

  /// Gets all characters from the local database.
  Future<List<Character>> getAllCharacters() {
    return _database.getAllCharacters();
  }

  /// Watches all characters for reactive updates.
  Stream<List<Character>> watchAllCharacters() {
    return _database.watchAllCharacters();
  }

  /// Gets the active character.
  Future<Character?> getActiveCharacter() {
    return _database.getActiveCharacter();
  }

  /// Watches the active character for reactive updates.
  Stream<Character?> watchActiveCharacter() {
    return _database.watchActiveCharacter();
  }

  /// Sets the active character.
  Future<void> setActiveCharacter(int characterId) {
    return _database.setActiveCharacter(characterId);
  }

  /// Refreshes a character's data from ESI.
  ///
  /// Fetches updated corporation/alliance info and updates the database.
  Future<void> refreshCharacter(int characterId) async {
    // Fetch public character info from ESI.
    final publicInfo = await _esiClient.getCharacterPublicInfo(characterId);

    // Fetch corporation name.
    final corpName = await _fetchCorporationName(publicInfo.corporationId);

    // Fetch alliance name if applicable.
    String? allianceName;
    if (publicInfo.allianceId != null) {
      allianceName = await _fetchAllianceName(publicInfo.allianceId!);
    }

    // Get existing character data to preserve token info.
    final existing = await _database
        .getAllCharacters()
        .then((chars) => chars.where((c) => c.characterId == characterId))
        .then((matches) => matches.isNotEmpty ? matches.first : null);

    if (existing == null) return;

    // Update the character in the database.
    final companion = CharactersCompanion(
      characterId: Value(characterId),
      name: Value(publicInfo.name),
      corporationId: Value(publicInfo.corporationId),
      corporationName: Value(corpName),
      allianceId: Value(publicInfo.allianceId),
      allianceName: Value(allianceName),
      portraitUrl: Value(_esiClient.getCharacterPortraitUrl(characterId)),
      tokenExpiry: Value(existing.tokenExpiry),
      lastUpdated: Value(DateTime.now()),
      isActive: Value(existing.isActive),
    );

    await _database.upsertCharacter(companion);
  }

  /// Deletes a character from the database.
  Future<void> deleteCharacter(int characterId) {
    return _database.deleteCharacter(characterId);
  }

  /// Fetches a corporation name from ESI.
  Future<String> _fetchCorporationName(int corporationId) async {
    try {
      final response = await _esiClient.publicGet<Map<String, dynamic>>(
        '/corporations/$corporationId/',
      );
      return response.data?['name'] as String? ?? 'Unknown Corporation';
    } catch (_) {
      return 'Unknown Corporation';
    }
  }

  /// Fetches an alliance name from ESI.
  Future<String> _fetchAllianceName(int allianceId) async {
    try {
      final response = await _esiClient.publicGet<Map<String, dynamic>>(
        '/alliances/$allianceId/',
      );
      return response.data?['name'] as String? ?? 'Unknown Alliance';
    } catch (_) {
      return 'Unknown Alliance';
    }
  }
}

/// Provider for the character repository.
final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  return CharacterRepository(
    database: ref.watch(databaseProvider),
    esiClient: ref.watch(esiClientProvider),
  );
});

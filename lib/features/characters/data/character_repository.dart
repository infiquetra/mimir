import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
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
  Future<List<Character>> getAllCharacters() async {
    Log.d('CHAR', 'getAllCharacters() - START');
    try {
      final characters = await _database.getAllCharacters();
      Log.i('CHAR', 'getAllCharacters - found ${characters.length} characters');
      Log.d('CHAR', 'getAllCharacters() - SUCCESS');
      return characters;
    } catch (e, stack) {
      Log.e('CHAR', 'getAllCharacters() - FAILED', e, stack);
      rethrow;
    }
  }

  /// Watches all characters for reactive updates.
  Stream<List<Character>> watchAllCharacters() {
    Log.d('CHAR', 'watchAllCharacters() - subscribed to stream');
    return _database.watchAllCharacters();
  }

  /// Gets the active character.
  Future<Character?> getActiveCharacter() async {
    Log.d('CHAR', 'getActiveCharacter() - START');
    try {
      final character = await _database.getActiveCharacter();
      Log.i('CHAR', 'getActiveCharacter - ${character != null ? "found ${character.name}" : "none active"}');
      Log.d('CHAR', 'getActiveCharacter() - SUCCESS');
      return character;
    } catch (e, stack) {
      Log.e('CHAR', 'getActiveCharacter() - FAILED', e, stack);
      rethrow;
    }
  }

  /// Watches the active character for reactive updates.
  Stream<Character?> watchActiveCharacter() {
    Log.d('CHAR', 'watchActiveCharacter() - subscribed to stream');
    return _database.watchActiveCharacter();
  }

  /// Sets the active character.
  Future<void> setActiveCharacter(int characterId) async {
    Log.d('CHAR', 'setActiveCharacter($characterId) - START');
    try {
      await _database.setActiveCharacter(characterId);
      Log.i('CHAR', 'setActiveCharacter - switched to character $characterId');
      Log.d('CHAR', 'setActiveCharacter($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('CHAR', 'setActiveCharacter($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Refreshes a character's data from ESI.
  ///
  /// Fetches updated corporation/alliance info and updates the database.
  Future<void> refreshCharacter(int characterId) async {
    Log.d('CHAR', 'refreshCharacter($characterId) - START');
    try {
      // Fetch public character info from ESI.
      Log.d('CHAR', 'refreshCharacter - fetching public info from ESI');
      final publicInfo = await _esiClient.getCharacterPublicInfo(characterId);
      Log.i('CHAR', 'refreshCharacter - fetched ${publicInfo.name}, corp=${publicInfo.corporationId}');

      // Fetch corporation name.
      Log.d('CHAR', 'refreshCharacter - fetching corporation name');
      final corpName = await _fetchCorporationName(publicInfo.corporationId);
      Log.i('CHAR', 'refreshCharacter - corporation: $corpName');

      // Fetch alliance name if applicable.
      String? allianceName;
      if (publicInfo.allianceId != null) {
        Log.d('CHAR', 'refreshCharacter - fetching alliance name');
        allianceName = await _fetchAllianceName(publicInfo.allianceId!);
        Log.i('CHAR', 'refreshCharacter - alliance: $allianceName');
      }

      // Get existing character data to preserve token info.
      Log.d('CHAR', 'refreshCharacter - loading existing character data');
      final existing = await _database
          .getAllCharacters()
          .then((chars) => chars.where((c) => c.characterId == characterId))
          .then((matches) => matches.isNotEmpty ? matches.first : null);

      if (existing == null) {
        Log.w('CHAR', 'refreshCharacter - character $characterId not found in database, skipping');
        return;
      }

      // Update the character in the database.
      Log.d('CHAR', 'refreshCharacter - saving to database');
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
      Log.i('CHAR', 'refreshCharacter - updated ${publicInfo.name} in database');
      Log.d('CHAR', 'refreshCharacter($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('CHAR', 'refreshCharacter($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Deletes a character from the database.
  Future<void> deleteCharacter(int characterId) async {
    Log.d('CHAR', 'deleteCharacter($characterId) - START');
    try {
      await _database.deleteCharacter(characterId);
      Log.i('CHAR', 'deleteCharacter - removed character $characterId');
      Log.d('CHAR', 'deleteCharacter($characterId) - SUCCESS');
    } catch (e, stack) {
      Log.e('CHAR', 'deleteCharacter($characterId) - FAILED', e, stack);
      rethrow;
    }
  }

  /// Fetches a corporation name from ESI.
  Future<String> _fetchCorporationName(int corporationId) async {
    Log.d('CHAR', '_fetchCorporationName($corporationId) - START');
    try {
      final response = await _esiClient.publicGet<Map<String, dynamic>>(
        '/corporations/$corporationId/',
      );
      final name = response.data?['name'] as String? ?? 'Unknown Corporation';
      Log.i('CHAR', '_fetchCorporationName - fetched: $name');
      Log.d('CHAR', '_fetchCorporationName($corporationId) - SUCCESS');
      return name;
    } catch (e, stack) {
      Log.w('CHAR', '_fetchCorporationName($corporationId) - FAILED, using fallback: $e');
      return 'Unknown Corporation';
    }
  }

  /// Fetches an alliance name from ESI.
  Future<String> _fetchAllianceName(int allianceId) async {
    Log.d('CHAR', '_fetchAllianceName($allianceId) - START');
    try {
      final response = await _esiClient.publicGet<Map<String, dynamic>>(
        '/alliances/$allianceId/',
      );
      final name = response.data?['name'] as String? ?? 'Unknown Alliance';
      Log.i('CHAR', '_fetchAllianceName - fetched: $name');
      Log.d('CHAR', '_fetchAllianceName($allianceId) - SUCCESS');
      return name;
    } catch (e, stack) {
      Log.w('CHAR', '_fetchAllianceName($allianceId) - FAILED, using fallback: $e');
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

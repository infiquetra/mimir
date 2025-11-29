import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/app_database.dart';
import 'oauth_service.dart';

/// Stored token data for a character.
class StoredTokens {
  /// The refresh token for obtaining new access tokens.
  final String refreshToken;

  /// When the current access token expires.
  final DateTime accessTokenExpiry;

  /// The current access token (may be expired).
  final String? accessToken;

  const StoredTokens({
    required this.refreshToken,
    required this.accessTokenExpiry,
    this.accessToken,
  });

  /// Whether the access token is expired or about to expire.
  bool get isAccessTokenExpired {
    // Consider expired if within 60 seconds of expiry.
    return DateTime.now().isAfter(
      accessTokenExpiry.subtract(const Duration(seconds: 60)),
    );
  }
}

/// Manages OAuth tokens for multiple characters using database storage.
///
/// Tokens are stored in the Characters table in the SQLite database,
/// which is accessible by all windows including sub-windows created
/// with desktop_multi_window.
///
/// This approach works in sub-windows where native plugins like
/// flutter_secure_storage are not available.
class TokenManager {
  final AppDatabase _database;

  TokenManager({required AppDatabase database}) : _database = database;

  /// Stores tokens for a character after successful authentication.
  Future<void> storeTokens({
    required int characterId,
    required TokenResponse tokenResponse,
  }) async {
    final expiry = DateTime.now().add(
      Duration(seconds: tokenResponse.expiresIn),
    );

    await _database.into(_database.characters).insertOnConflictUpdate(
          CharactersCompanion(
            characterId: Value(characterId),
            refreshToken: Value(tokenResponse.refreshToken),
            accessToken: Value(tokenResponse.accessToken),
            tokenExpiry: Value(expiry),
          ),
        );
  }

  /// Updates the access token for a character after refresh.
  Future<void> updateAccessToken({
    required int characterId,
    required TokenResponse tokenResponse,
  }) async {
    final expiry = DateTime.now().add(
      Duration(seconds: tokenResponse.expiresIn),
    );

    await (_database.update(_database.characters)
          ..where((c) => c.characterId.equals(characterId)))
        .write(
      CharactersCompanion(
        refreshToken: Value(tokenResponse.refreshToken),
        accessToken: Value(tokenResponse.accessToken),
        tokenExpiry: Value(expiry),
      ),
    );
  }

  /// Gets stored tokens for a character.
  Future<StoredTokens?> getTokens(int characterId) async {
    final character = await (_database.select(_database.characters)
          ..where((c) => c.characterId.equals(characterId)))
        .getSingleOrNull();

    if (character == null || character.refreshToken == null) {
      return null;
    }

    return StoredTokens(
      refreshToken: character.refreshToken!,
      accessTokenExpiry: character.tokenExpiry,
      accessToken: character.accessToken,
    );
  }

  /// Deletes tokens for a character (logout).
  Future<void> deleteTokens(int characterId) async {
    await (_database.update(_database.characters)
          ..where((c) => c.characterId.equals(characterId)))
        .write(
      const CharactersCompanion(
        refreshToken: Value(null),
        accessToken: Value(null),
      ),
    );
  }

  /// Gets the list of character IDs with stored tokens.
  Future<List<int>> getAuthenticatedCharacterIds() async {
    final characters = await (_database.select(_database.characters)
          ..where((c) => c.refreshToken.isNotNull()))
        .get();

    return characters.map((c) => c.characterId).toList();
  }

  /// Clears all stored tokens (full logout).
  Future<void> clearAll() async {
    await _database.update(_database.characters).write(
          const CharactersCompanion(
            refreshToken: Value(null),
            accessToken: Value(null),
          ),
        );
  }

  /// Migrates tokens from FlutterSecureStorage to database.
  ///
  /// This is a one-time migration for existing users who had tokens
  /// stored in secure storage before the database migration.
  ///
  /// Only runs in main window (where secure storage is available).
  /// Skips characters that already have tokens in database.
  /// Deletes from secure storage after successful migration.
  Future<void> migrateFromSecureStorage() async {
    // Can't access secure storage in sub-windows
    if (isSubWindow) {
      debugPrint('TokenManager: Skipping migration (sub-window)');
      return;
    }

    try {
      debugPrint('TokenManager: Starting migration from secure storage');

      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );

      // Get all characters from database
      final characters = await _database.getAllCharacters();
      debugPrint(
        'TokenManager: Found ${characters.length} characters to check',
      );

      var migratedCount = 0;
      for (final character in characters) {
        // Skip if already has tokens in database
        if (character.refreshToken != null) {
          debugPrint(
            'TokenManager: Character ${character.characterId} already has tokens in database',
          );
          continue;
        }

        // Try to read from secure storage
        final key = 'mimir_tokens_${character.characterId}';
        final data = await secureStorage.read(key: key);
        if (data == null) {
          debugPrint(
            'TokenManager: No secure storage data for character ${character.characterId}',
          );
          continue;
        }

        try {
          // Parse and write to database
          final tokens = json.decode(data) as Map<String, dynamic>;
          await (_database.update(_database.characters)
                ..where((c) => c.characterId.equals(character.characterId)))
              .write(
            CharactersCompanion(
              refreshToken: Value(tokens['refreshToken'] as String),
              accessToken: Value(tokens['accessToken'] as String?),
              tokenExpiry: Value(
                DateTime.parse(tokens['accessTokenExpiry'] as String),
              ),
            ),
          );

          // Delete from secure storage after successful migration
          await secureStorage.delete(key: key);

          migratedCount++;
          debugPrint(
            'TokenManager: Migrated tokens for character ${character.characterId}',
          );
        } catch (e) {
          debugPrint(
            'TokenManager: Failed to migrate character ${character.characterId}: $e',
          );
        }
      }

      debugPrint('TokenManager: Migration complete ($migratedCount migrated)');
    } catch (e, stack) {
      debugPrint('TokenManager: Migration failed: $e');
      debugPrint('TokenManager: Stack trace: $stack');
      // Don't throw - migration failures shouldn't block app startup
    }
  }
}

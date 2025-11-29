import 'package:drift/drift.dart';

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
}

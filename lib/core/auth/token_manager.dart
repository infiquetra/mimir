import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  Map<String, dynamic> toJson() => {
        'refreshToken': refreshToken,
        'accessTokenExpiry': accessTokenExpiry.toIso8601String(),
        'accessToken': accessToken,
      };

  factory StoredTokens.fromJson(Map<String, dynamic> json) {
    return StoredTokens(
      refreshToken: json['refreshToken'] as String,
      accessTokenExpiry: DateTime.parse(json['accessTokenExpiry'] as String),
      accessToken: json['accessToken'] as String?,
    );
  }
}

/// Manages secure storage of OAuth tokens for multiple characters.
///
/// Uses platform-specific secure storage:
/// - macOS/iOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Windows: Windows Credential Locker
/// - Linux: libsecret
///
/// Each character's tokens are stored independently, allowing multi-account support.
class TokenManager {
  final FlutterSecureStorage _storage;

  /// Key prefix for token storage.
  static const String _keyPrefix = 'mimir_tokens_';

  /// Key for storing the list of authenticated character IDs.
  static const String _characterListKey = 'mimir_authenticated_characters';

  TokenManager({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
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

  /// Stores tokens for a character after successful authentication.
  Future<void> storeTokens({
    required int characterId,
    required TokenResponse tokenResponse,
  }) async {
    final tokens = StoredTokens(
      refreshToken: tokenResponse.refreshToken,
      accessTokenExpiry: DateTime.now().add(
        Duration(seconds: tokenResponse.expiresIn),
      ),
      accessToken: tokenResponse.accessToken,
    );

    // Store the tokens.
    await _storage.write(
      key: _tokenKey(characterId),
      value: json.encode(tokens.toJson()),
    );

    // Add character to the list of authenticated characters.
    await _addToCharacterList(characterId);
  }

  /// Updates the access token for a character after refresh.
  Future<void> updateAccessToken({
    required int characterId,
    required TokenResponse tokenResponse,
  }) async {
    final existing = await getTokens(characterId);
    if (existing == null) {
      // No existing tokens, store as new.
      await storeTokens(
        characterId: characterId,
        tokenResponse: tokenResponse,
      );
      return;
    }

    final updated = StoredTokens(
      refreshToken: tokenResponse.refreshToken,
      accessTokenExpiry: DateTime.now().add(
        Duration(seconds: tokenResponse.expiresIn),
      ),
      accessToken: tokenResponse.accessToken,
    );

    await _storage.write(
      key: _tokenKey(characterId),
      value: json.encode(updated.toJson()),
    );
  }

  /// Gets stored tokens for a character.
  Future<StoredTokens?> getTokens(int characterId) async {
    final data = await _storage.read(key: _tokenKey(characterId));
    if (data == null) return null;

    try {
      return StoredTokens.fromJson(json.decode(data) as Map<String, dynamic>);
    } catch (_) {
      // Invalid data, clear it.
      await deleteTokens(characterId);
      return null;
    }
  }

  /// Deletes tokens for a character (logout).
  Future<void> deleteTokens(int characterId) async {
    await _storage.delete(key: _tokenKey(characterId));
    await _removeFromCharacterList(characterId);
  }

  /// Gets the list of character IDs with stored tokens.
  Future<List<int>> getAuthenticatedCharacterIds() async {
    final data = await _storage.read(key: _characterListKey);
    if (data == null) return [];

    try {
      final list = json.decode(data) as List<dynamic>;
      return list.cast<int>();
    } catch (_) {
      return [];
    }
  }

  /// Clears all stored tokens (full logout).
  Future<void> clearAll() async {
    final characterIds = await getAuthenticatedCharacterIds();
    for (final id in characterIds) {
      await _storage.delete(key: _tokenKey(id));
    }
    await _storage.delete(key: _characterListKey);
  }

  /// Generates the storage key for a character's tokens.
  String _tokenKey(int characterId) => '$_keyPrefix$characterId';

  /// Adds a character ID to the authenticated list.
  Future<void> _addToCharacterList(int characterId) async {
    final ids = await getAuthenticatedCharacterIds();
    if (!ids.contains(characterId)) {
      ids.add(characterId);
      await _storage.write(
        key: _characterListKey,
        value: json.encode(ids),
      );
    }
  }

  /// Removes a character ID from the authenticated list.
  Future<void> _removeFromCharacterList(int characterId) async {
    final ids = await getAuthenticatedCharacterIds();
    ids.remove(characterId);
    await _storage.write(
      key: _characterListKey,
      value: json.encode(ids),
    );
  }
}

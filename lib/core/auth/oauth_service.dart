import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/eve_config.dart';

/// Result of initiating an OAuth authorization request.
class AuthorizationRequest {
  /// The URL to open in the browser for user authentication.
  final Uri authorizationUrl;

  /// The PKCE code verifier (store this to exchange for tokens later).
  final String codeVerifier;

  /// The state parameter for CSRF protection.
  final String state;

  const AuthorizationRequest({
    required this.authorizationUrl,
    required this.codeVerifier,
    required this.state,
  });
}

/// Token response from EVE SSO.
class TokenResponse {
  /// The access token for ESI API calls.
  final String accessToken;

  /// The refresh token for obtaining new access tokens.
  final String refreshToken;

  /// Token type (always "Bearer").
  final String tokenType;

  /// Seconds until the access token expires.
  final int expiresIn;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

/// Character information extracted from JWT access token.
class JwtCharacterInfo {
  /// EVE character ID.
  final int characterId;

  /// Character name.
  final String characterName;

  /// Token expiration time.
  final DateTime expiresAt;

  /// Granted scopes.
  final List<String> scopes;

  const JwtCharacterInfo({
    required this.characterId,
    required this.characterName,
    required this.expiresAt,
    required this.scopes,
  });
}

/// OAuth 2.0 PKCE service for EVE SSO authentication.
///
/// Implements the Authorization Code flow with Proof Key for Code Exchange (PKCE)
/// as required by EVE Online's SSO for native applications.
///
/// Flow:
/// 1. [createAuthorizationRequest] - Generate PKCE challenge and authorization URL
/// 2. User authenticates in browser, gets redirected to callback URL
/// 3. [parseCallbackUrl] - Extract authorization code from callback
/// 4. [exchangeCodeForTokens] - Exchange code + verifier for tokens
/// 5. [parseAccessToken] - Extract character info from JWT
class OAuthService {
  final Dio _dio;

  OAuthService({Dio? dio}) : _dio = dio ?? Dio();

  /// Characters allowed in PKCE code verifier (RFC 7636).
  static const String _unreservedChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Creates an authorization request with PKCE challenge.
  ///
  /// Returns an [AuthorizationRequest] containing:
  /// - The authorization URL to open in the browser
  /// - The code verifier to store for token exchange
  /// - The state parameter for CSRF protection
  AuthorizationRequest createAuthorizationRequest() {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateState();

    final queryParams = {
      'response_type': 'code',
      'redirect_uri': EveConfig.redirectUri,
      'client_id': EveConfig.clientId,
      'scope': EveConfig.scopesString,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    };

    final authorizationUrl = Uri.parse(EveConfig.oauthAuthorizeUrl)
        .replace(queryParameters: queryParams);

    return AuthorizationRequest(
      authorizationUrl: authorizationUrl,
      codeVerifier: codeVerifier,
      state: state,
    );
  }

  /// Parses the callback URL to extract the authorization code.
  ///
  /// Returns the authorization code if successful, null if error or cancelled.
  /// Throws [OAuthException] if the state doesn't match or other errors occur.
  String? parseCallbackUrl(Uri callbackUrl, String expectedState) {
    final queryParams = callbackUrl.queryParameters;

    // Check for error response.
    if (queryParams.containsKey('error')) {
      final error = queryParams['error'];
      final description = queryParams['error_description'] ?? 'Unknown error';
      throw OAuthException('OAuth error: $error - $description');
    }

    // Verify state matches to prevent CSRF attacks.
    final returnedState = queryParams['state'];
    if (returnedState != expectedState) {
      throw OAuthException(
        'State mismatch: expected $expectedState, got $returnedState',
      );
    }

    return queryParams['code'];
  }

  /// Exchanges the authorization code for access and refresh tokens.
  ///
  /// [code] - The authorization code from the callback URL.
  /// [codeVerifier] - The PKCE code verifier from the original request.
  Future<TokenResponse> exchangeCodeForTokens({
    required String code,
    required String codeVerifier,
  }) async {
    debugPrint('Exchanging code for tokens at ${EveConfig.oauthTokenUrl}');
    try {
      final response = await _dio.post(
        EveConfig.oauthTokenUrl,
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': EveConfig.clientId,
          'code_verifier': codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Host': 'login.eveonline.com',
          },
        ),
      );

      debugPrint('Token exchange successful');
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('Token exchange DioException: ${e.type} - ${e.message}');
      debugPrint('Response: ${e.response?.data}');
      debugPrint('Error: ${e.error}');
      throw OAuthException(
        'Token exchange failed: ${e.response?.data ?? e.message}',
      );
    }
  }

  /// Refreshes an expired access token using the refresh token.
  Future<TokenResponse> refreshAccessToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        EveConfig.oauthTokenUrl,
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': EveConfig.clientId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Host': 'login.eveonline.com',
          },
        ),
      );

      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw OAuthException(
        'Token refresh failed: ${e.response?.data ?? e.message}',
      );
    }
  }

  /// Revokes a refresh token (for logout).
  Future<void> revokeToken(String refreshToken) async {
    try {
      await _dio.post(
        EveConfig.oauthRevokeUrl,
        data: {
          'token_type_hint': 'refresh_token',
          'token': refreshToken,
          'client_id': EveConfig.clientId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Host': 'login.eveonline.com',
          },
        ),
      );
    } on DioException catch (e) {
      // Revocation errors are non-critical - token may already be invalid.
      throw OAuthException(
        'Token revocation failed: ${e.response?.data ?? e.message}',
      );
    }
  }

  /// Parses the JWT access token to extract character information.
  ///
  /// EVE's access tokens are JWTs containing character ID and name in the payload.
  /// Note: We don't verify the JWT signature as we trust the EVE SSO server.
  JwtCharacterInfo parseAccessToken(String accessToken) {
    try {
      // JWT format: header.payload.signature
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        throw const OAuthException('Invalid JWT format');
      }

      // Decode the payload (middle part).
      final payload = _decodeBase64Url(parts[1]);
      final payloadJson = json.decode(payload) as Map<String, dynamic>;

      // Extract character info from "sub" claim.
      // Format: "CHARACTER:EVE:123456789"
      final sub = payloadJson['sub'] as String;
      final subParts = sub.split(':');
      if (subParts.length != 3 || subParts[0] != 'CHARACTER') {
        throw OAuthException('Invalid subject format in JWT: $sub');
      }
      final characterId = int.parse(subParts[2]);

      // Character name is in the "name" claim.
      final characterName = payloadJson['name'] as String;

      // Expiration time.
      final exp = payloadJson['exp'] as int;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

      // Scopes can be a space-separated string or array.
      final scopesClaim = payloadJson['scp'];
      final List<String> scopes;
      if (scopesClaim is String) {
        scopes = scopesClaim.split(' ');
      } else if (scopesClaim is List) {
        scopes = scopesClaim.cast<String>();
      } else {
        scopes = [];
      }

      return JwtCharacterInfo(
        characterId: characterId,
        characterName: characterName,
        expiresAt: expiresAt,
        scopes: scopes,
      );
    } catch (e) {
      if (e is OAuthException) rethrow;
      throw OAuthException('Failed to parse JWT: $e');
    }
  }

  /// Generates a cryptographically random code verifier for PKCE.
  ///
  /// The verifier is 64 characters from the unreserved character set.
  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List.generate(64, (_) => random.nextInt(_unreservedChars.length));
    return bytes.map((i) => _unreservedChars[i]).join();
  }

  /// Generates the code challenge from the verifier using SHA256.
  ///
  /// challenge = BASE64URL(SHA256(verifier))
  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a random state parameter for CSRF protection.
  String _generateState() {
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decodes a Base64URL encoded string (handles missing padding).
  String _decodeBase64Url(String input) {
    // Add padding if needed.
    var padded = input;
    switch (input.length % 4) {
      case 2:
        padded = '$input==';
        break;
      case 3:
        padded = '$input=';
        break;
    }
    final bytes = base64Url.decode(padded);
    return utf8.decode(bytes);
  }
}

/// Exception thrown for OAuth-related errors.
class OAuthException implements Exception {
  final String message;

  const OAuthException(this.message);

  @override
  String toString() => message;
}

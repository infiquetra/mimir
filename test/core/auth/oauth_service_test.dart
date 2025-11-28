import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/auth/oauth_service.dart';
import 'package:mimir/core/auth/token_manager.dart';
import 'package:mimir/core/config/eve_config.dart';

void main() {
  late OAuthService oauthService;

  setUp(() {
    oauthService = OAuthService();
  });

  group('OAuthService', () {
    group('createAuthorizationRequest', () {
      test('should generate valid authorization URL', () {
        final request = oauthService.createAuthorizationRequest();

        // Verify the URL has the correct base.
        expect(
          request.authorizationUrl.toString(),
          startsWith(EveConfig.oauthAuthorizeUrl),
        );

        // Verify required parameters are present.
        final params = request.authorizationUrl.queryParameters;
        expect(params['response_type'], equals('code'));
        expect(params['client_id'], equals(EveConfig.clientId));
        expect(params['redirect_uri'], equals(EveConfig.redirectUri));
        expect(params['scope'], equals(EveConfig.scopesString));
        expect(params['code_challenge_method'], equals('S256'));

        // Verify PKCE challenge is present.
        expect(params['code_challenge'], isNotEmpty);
        expect(params['state'], isNotEmpty);
      });

      test('should generate unique code verifier each time', () {
        final request1 = oauthService.createAuthorizationRequest();
        final request2 = oauthService.createAuthorizationRequest();

        expect(request1.codeVerifier, isNot(equals(request2.codeVerifier)));
      });

      test('should generate unique state each time', () {
        final request1 = oauthService.createAuthorizationRequest();
        final request2 = oauthService.createAuthorizationRequest();

        expect(request1.state, isNot(equals(request2.state)));
      });

      test('code verifier should be at least 43 characters', () {
        final request = oauthService.createAuthorizationRequest();

        expect(request.codeVerifier.length, greaterThanOrEqualTo(43));
      });
    });

    group('parseCallbackUrl', () {
      test('should extract authorization code from valid callback', () {
        final state = 'test_state_123';
        final callbackUrl = Uri.parse(
          '${EveConfig.redirectUri}?code=auth_code_456&state=$state',
        );

        final code = oauthService.parseCallbackUrl(callbackUrl, state);

        expect(code, equals('auth_code_456'));
      });

      test('should throw on state mismatch', () {
        final callbackUrl = Uri.parse(
          '${EveConfig.redirectUri}?code=auth_code&state=wrong_state',
        );

        expect(
          () => oauthService.parseCallbackUrl(callbackUrl, 'expected_state'),
          throwsA(isA<OAuthException>()),
        );
      });

      test('should throw on error response', () {
        final callbackUrl = Uri.parse(
          '${EveConfig.redirectUri}?error=access_denied&error_description=User%20cancelled',
        );

        expect(
          () => oauthService.parseCallbackUrl(callbackUrl, 'any_state'),
          throwsA(isA<OAuthException>()),
        );
      });
    });

    group('parseAccessToken', () {
      test('should parse valid EVE JWT token', () {
        // Create a mock EVE JWT token.
        final header = base64Url.encode(utf8.encode('{"alg":"RS256"}'));
        final payload = base64Url.encode(utf8.encode(json.encode({
          'sub': 'CHARACTER:EVE:12345678',
          'name': 'Test Pilot',
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'scp': ['esi-skills.read_skills.v1', 'esi-wallet.read_character_wallet.v1'],
        })));
        final signature = base64Url.encode(utf8.encode('fake_signature'));
        final token = '$header.$payload.$signature';

        final info = oauthService.parseAccessToken(token);

        expect(info.characterId, equals(12345678));
        expect(info.characterName, equals('Test Pilot'));
        expect(info.scopes, hasLength(2));
        expect(info.scopes, contains('esi-skills.read_skills.v1'));
      });

      test('should handle space-separated scopes string', () {
        final header = base64Url.encode(utf8.encode('{"alg":"RS256"}'));
        final payload = base64Url.encode(utf8.encode(json.encode({
          'sub': 'CHARACTER:EVE:12345678',
          'name': 'Test Pilot',
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'scp': 'esi-skills.read_skills.v1 esi-wallet.read_character_wallet.v1',
        })));
        final signature = base64Url.encode(utf8.encode('fake_signature'));
        final token = '$header.$payload.$signature';

        final info = oauthService.parseAccessToken(token);

        expect(info.scopes, hasLength(2));
      });

      test('should throw on invalid JWT format', () {
        expect(
          () => oauthService.parseAccessToken('invalid_token'),
          throwsA(isA<OAuthException>()),
        );
      });

      test('should throw on invalid subject format', () {
        final header = base64Url.encode(utf8.encode('{"alg":"RS256"}'));
        final payload = base64Url.encode(utf8.encode(json.encode({
          'sub': 'INVALID:FORMAT',
          'name': 'Test',
          'exp': 9999999999,
        })));
        final signature = base64Url.encode(utf8.encode('fake'));
        final token = '$header.$payload.$signature';

        expect(
          () => oauthService.parseAccessToken(token),
          throwsA(isA<OAuthException>()),
        );
      });
    });
  });

  group('TokenResponse', () {
    test('should parse from JSON', () {
      final json = {
        'access_token': 'test_access_token',
        'refresh_token': 'test_refresh_token',
        'token_type': 'Bearer',
        'expires_in': 1199,
      };

      final response = TokenResponse.fromJson(json);

      expect(response.accessToken, equals('test_access_token'));
      expect(response.refreshToken, equals('test_refresh_token'));
      expect(response.tokenType, equals('Bearer'));
      expect(response.expiresIn, equals(1199));
    });
  });

  group('StoredTokens', () {
    test('isAccessTokenExpired should be true when token is expired', () {
      final tokens = StoredTokens(
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().subtract(const Duration(minutes: 5)),
        accessToken: 'expired_token',
      );

      expect(tokens.isAccessTokenExpired, isTrue);
    });

    test('isAccessTokenExpired should be true within buffer period', () {
      final tokens = StoredTokens(
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().add(const Duration(seconds: 30)),
        accessToken: 'soon_expired',
      );

      expect(tokens.isAccessTokenExpired, isTrue);
    });

    test('isAccessTokenExpired should be false when token is valid', () {
      final tokens = StoredTokens(
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 10)),
        accessToken: 'valid_token',
      );

      expect(tokens.isAccessTokenExpired, isFalse);
    });

    test('should serialize and deserialize correctly', () {
      final original = StoredTokens(
        refreshToken: 'refresh_123',
        accessTokenExpiry: DateTime(2024, 1, 15, 12, 0, 0),
        accessToken: 'access_456',
      );

      final json = original.toJson();
      final restored = StoredTokens.fromJson(json);

      expect(restored.refreshToken, equals(original.refreshToken));
      expect(restored.accessToken, equals(original.accessToken));
      expect(
        restored.accessTokenExpiry.toIso8601String(),
        equals(original.accessTokenExpiry.toIso8601String()),
      );
    });
  });
}

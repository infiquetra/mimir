import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import 'codex_auth_store.dart';

const String codexClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
const String codexIssuer = 'https://auth.openai.com';
const String codexTokenEndpoint = '$codexIssuer/oauth/token';
const String codexDeviceVerificationUri = '$codexIssuer/codex/device';
const String codexDeviceRedirectUri = '$codexIssuer/deviceauth/callback';
const String codexDefaultBaseUrl = 'https://chatgpt.com/backend-api/codex';
const String codexDefaultModel = 'gpt-5.4';

final codexAuthStoreProvider = Provider<CodexAuthStore>((ref) {
  return CodexAuthStore();
});

final codexAuthServiceProvider = Provider<CodexAuthService>((ref) {
  return CodexAuthService(authStore: ref.watch(codexAuthStoreProvider));
});

enum CodexAuthStatusKind { unauthenticated, authenticated, expiring }

class CodexAuthStatus {
  const CodexAuthStatus({
    required this.kind,
    this.authFilePath,
    this.lastRefresh,
    this.expiresAt,
  });

  final CodexAuthStatusKind kind;
  final String? authFilePath;
  final String? lastRefresh;
  final DateTime? expiresAt;

  bool get isAuthenticated =>
      kind == CodexAuthStatusKind.authenticated ||
      kind == CodexAuthStatusKind.expiring;
}

class CodexRuntimeCredentials {
  const CodexRuntimeCredentials({
    required this.accessToken,
    required this.baseUrl,
    required this.lastRefresh,
  });

  final String accessToken;
  final String baseUrl;
  final String? lastRefresh;
}

class CodexDeviceAuthSession {
  const CodexDeviceAuthSession({
    required this.userCode,
    required this.deviceAuthId,
    required this.verificationUri,
    required this.interval,
  });

  final String userCode;
  final String deviceAuthId;
  final String verificationUri;
  final int interval;
}

class CodexAuthorizationExchange {
  const CodexAuthorizationExchange({
    required this.authorizationCode,
    required this.codeVerifier,
  });

  final String authorizationCode;
  final String codeVerifier;
}

class CodexAuthException implements Exception {
  const CodexAuthException(
    this.message, {
    required this.code,
    this.reloginRequired = false,
  });

  final String message;
  final String code;
  final bool reloginRequired;

  @override
  String toString() => message;
}

class CodexAuthCancelledException extends CodexAuthException {
  const CodexAuthCancelledException()
    : super('AI sign-in was cancelled.', code: 'codex_auth_cancelled');
}

class CodexAuthService {
  CodexAuthService({
    required CodexAuthStore authStore,
    Dio? dio,
    Future<void> Function(Duration duration)? delay,
  }) : _authStore = authStore,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  final CodexAuthStore _authStore;
  final Dio _dio;
  final Future<void> Function(Duration duration) _delay;

  Future<CodexAuthStatus> getStatus() async {
    Log.d('AUTH.CODEX', 'getStatus() - START');
    final authFilePath = await _authStore.authFilePath;
    try {
      final state = await _authStore.readState();
      final expiresAt = state.tokens.accessTokenExpiry;
      final kind = state.tokens.accessTokenIsExpiring()
          ? CodexAuthStatusKind.expiring
          : CodexAuthStatusKind.authenticated;
      Log.d('AUTH.CODEX', 'getStatus() - $kind');
      return CodexAuthStatus(
        kind: kind,
        authFilePath: authFilePath,
        lastRefresh: state.lastRefresh,
        expiresAt: expiresAt,
      );
    } on CodexAuthStoreException {
      Log.d('AUTH.CODEX', 'getStatus() - unauthenticated');
      return CodexAuthStatus(
        kind: CodexAuthStatusKind.unauthenticated,
        authFilePath: authFilePath,
      );
    }
  }

  Future<CodexDeviceAuthSession> startDeviceFlow() async {
    Log.i('AUTH.CODEX', 'startDeviceFlow() - requesting AI device code');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$codexIssuer/api/accounts/deviceauth/usercode',
        data: {'client_id': codexClientId},
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const CodexAuthException(
          'AI device code response was empty.',
          code: 'device_code_empty',
        );
      }
      final userCode = data['user_code'];
      final deviceAuthId = data['device_auth_id'];
      if (userCode is! String || userCode.trim().isEmpty) {
        throw const CodexAuthException(
          'AI device code response was missing user_code.',
          code: 'device_code_missing_user_code',
        );
      }
      if (deviceAuthId is! String || deviceAuthId.trim().isEmpty) {
        throw const CodexAuthException(
          'AI device code response was missing device_auth_id.',
          code: 'device_code_missing_device_auth_id',
        );
      }
      final interval = _parseInterval(data['interval']);
      Log.i('AUTH.CODEX', 'AI device code acquired');
      return CodexDeviceAuthSession(
        userCode: userCode.trim(),
        deviceAuthId: deviceAuthId.trim(),
        verificationUri: codexDeviceVerificationUri,
        interval: interval,
      );
    } on DioException catch (e, stack) {
      Log.e('AUTH.CODEX', 'AI device code request failed', e, stack);
      throw _authExceptionFromDio(
        e,
        fallbackCode: 'device_code_request_failed',
        fallbackMessage: 'Failed to request AI device code.',
      );
    }
  }

  Future<CodexAuthTokens> completeDeviceFlow(
    CodexDeviceAuthSession session, {
    bool Function()? shouldCancel,
  }) async {
    Log.i('AUTH.CODEX', 'completeDeviceFlow() - waiting for authorization');
    final exchange = await _pollForAuthorizationCode(
      session,
      shouldCancel: shouldCancel,
    );
    final tokens = await _exchangeAuthorizationCode(exchange);
    await _authStore.saveTokens(tokens);
    Log.i('AUTH.CODEX', 'AI device flow completed');
    return tokens;
  }

  Future<CodexRuntimeCredentials> resolveRuntimeCredentials({
    bool forceRefresh = false,
    bool refreshIfExpiring = true,
  }) async {
    Log.d(
      'AUTH.CODEX',
      'resolveRuntimeCredentials(forceRefresh=$forceRefresh) - START',
    );
    var state = await _authStore.readState();
    var tokens = state.tokens;
    final shouldRefresh =
        forceRefresh ||
        (refreshIfExpiring && tokens.accessTokenIsExpiring(skewSeconds: 120));
    if (shouldRefresh) {
      Log.i('AUTH.CODEX', 'Refreshing AI access token');
      tokens = await refreshTokens(tokens);
      state = await _authStore.readState();
    }
    Log.d('AUTH.CODEX', 'resolveRuntimeCredentials() - SUCCESS');
    return CodexRuntimeCredentials(
      accessToken: tokens.accessToken,
      baseUrl: codexDefaultBaseUrl,
      lastRefresh: state.lastRefresh,
    );
  }

  Future<CodexAuthTokens> refreshTokens(CodexAuthTokens tokens) async {
    Log.d('AUTH.CODEX', 'refreshTokens() - START');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        codexTokenEndpoint,
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': tokens.refreshToken,
          'client_id': codexClientId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const CodexAuthException(
          'AI token refresh response was empty.',
          code: 'codex_refresh_empty',
          reloginRequired: true,
        );
      }
      final accessToken = data['access_token'];
      if (accessToken is! String || accessToken.trim().isEmpty) {
        throw const CodexAuthException(
          'AI token refresh response was missing access_token.',
          code: 'codex_refresh_missing_access_token',
          reloginRequired: true,
        );
      }
      final nextRefreshToken = data['refresh_token'];
      final updated = CodexAuthTokens(
        accessToken: accessToken.trim(),
        refreshToken:
            nextRefreshToken is String && nextRefreshToken.trim().isNotEmpty
            ? nextRefreshToken.trim()
            : tokens.refreshToken,
      );
      await _authStore.saveTokens(updated);
      Log.i('AUTH.CODEX', 'AI token refresh completed');
      return updated;
    } on DioException catch (e, stack) {
      Log.e('AUTH.CODEX', 'AI token refresh failed', e, stack);
      throw _authExceptionFromDio(
        e,
        fallbackCode: 'codex_refresh_failed',
        fallbackMessage: 'AI token refresh failed.',
        reloginStatusCodes: const {400, 401, 403},
      );
    }
  }

  Future<bool> importCodexCliTokens() {
    Log.i('AUTH.CODEX', 'importAiCliTokens() requested');
    return _authStore.importCodexCliTokens();
  }

  Future<void> clear() => _authStore.clear();

  Future<CodexAuthorizationExchange> _pollForAuthorizationCode(
    CodexDeviceAuthSession session, {
    bool Function()? shouldCancel,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 15));
    while (DateTime.now().isBefore(deadline)) {
      if (shouldCancel?.call() ?? false) {
        Log.w('AUTH.CODEX', 'AI device flow cancelled');
        throw const CodexAuthCancelledException();
      }

      await _delay(Duration(seconds: session.interval));

      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$codexIssuer/api/accounts/deviceauth/token',
          data: {
            'device_auth_id': session.deviceAuthId,
            'user_code': session.userCode,
          },
          options: Options(
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) =>
                status != null && status >= 200 && status < 500,
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final code = data?['authorization_code'];
          final verifier = data?['code_verifier'];
          if (code is! String || code.trim().isEmpty) {
            throw const CodexAuthException(
              'AI device authorization response was missing authorization_code.',
              code: 'device_poll_missing_authorization_code',
            );
          }
          if (verifier is! String || verifier.trim().isEmpty) {
            throw const CodexAuthException(
              'AI device authorization response was missing code_verifier.',
              code: 'device_poll_missing_code_verifier',
            );
          }
          Log.i('AUTH.CODEX', 'AI device authorization approved');
          return CodexAuthorizationExchange(
            authorizationCode: code.trim(),
            codeVerifier: verifier.trim(),
          );
        }

        if (response.statusCode == 403 || response.statusCode == 404) {
          Log.d('AUTH.CODEX', 'AI device authorization pending');
          continue;
        }

        throw CodexAuthException(
          'AI device authorization failed with HTTP ${response.statusCode}.',
          code: 'device_poll_failed',
        );
      } on DioException catch (e, stack) {
        Log.e('AUTH.CODEX', 'AI device authorization poll failed', e, stack);
        throw _authExceptionFromDio(
          e,
          fallbackCode: 'device_poll_failed',
          fallbackMessage: 'AI device authorization polling failed.',
        );
      }
    }

    throw const CodexAuthException(
      'AI sign-in timed out after 15 minutes.',
      code: 'device_poll_timeout',
    );
  }

  Future<CodexAuthTokens> _exchangeAuthorizationCode(
    CodexAuthorizationExchange exchange,
  ) async {
    Log.d('AUTH.CODEX', '_exchangeAuthorizationCode() - START');
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        codexTokenEndpoint,
        data: {
          'grant_type': 'authorization_code',
          'code': exchange.authorizationCode,
          'redirect_uri': codexDeviceRedirectUri,
          'client_id': codexClientId,
          'code_verifier': exchange.codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const CodexAuthException(
          'AI token exchange response was empty.',
          code: 'token_exchange_empty',
        );
      }
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      if (accessToken is! String || accessToken.trim().isEmpty) {
        throw const CodexAuthException(
          'AI token exchange response was missing access_token.',
          code: 'token_exchange_missing_access_token',
        );
      }
      if (refreshToken is! String || refreshToken.trim().isEmpty) {
        throw const CodexAuthException(
          'AI token exchange response was missing refresh_token.',
          code: 'token_exchange_missing_refresh_token',
        );
      }
      Log.i('AUTH.CODEX', 'AI token exchange completed');
      return CodexAuthTokens(
        accessToken: accessToken.trim(),
        refreshToken: refreshToken.trim(),
      );
    } on DioException catch (e, stack) {
      Log.e('AUTH.CODEX', 'AI token exchange failed', e, stack);
      throw _authExceptionFromDio(
        e,
        fallbackCode: 'token_exchange_failed',
        fallbackMessage: 'AI token exchange failed.',
      );
    }
  }

  int _parseInterval(Object? raw) {
    if (raw is int) return raw < 3 ? 3 : raw;
    if (raw is num) return raw.toInt() < 3 ? 3 : raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed < 3 ? 3 : parsed;
    }
    return 5;
  }

  CodexAuthException _authExceptionFromDio(
    DioException error, {
    required String fallbackCode,
    required String fallbackMessage,
    Set<int> reloginStatusCodes = const {},
  }) {
    final statusCode = error.response?.statusCode;
    var code = fallbackCode;
    var message = fallbackMessage;
    var reloginRequired =
        statusCode != null && reloginStatusCodes.contains(statusCode);

    final body = error.response?.data;
    if (body is Map) {
      final errorBody = body['error'];
      if (errorBody is Map) {
        final nestedCode = errorBody['code'] ?? errorBody['type'];
        final nestedMessage = errorBody['message'];
        if (nestedCode is String && nestedCode.trim().isNotEmpty) {
          code = nestedCode.trim();
        }
        if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
          message = '$fallbackMessage ${nestedMessage.trim()}';
        }
      } else if (errorBody is String && errorBody.trim().isNotEmpty) {
        code = errorBody.trim();
        final description = body['error_description'] ?? body['message'];
        if (description is String && description.trim().isNotEmpty) {
          message = '$fallbackMessage ${description.trim()}';
        }
      }
    }

    if (code == 'invalid_grant' ||
        code == 'invalid_token' ||
        code == 'invalid_request' ||
        code == 'refresh_token_reused') {
      reloginRequired = true;
    }

    if (code == 'refresh_token_reused') {
      message =
          'AI refresh token was already consumed by another client. '
          'Sign in to AI again from Mimir.';
    }

    if (statusCode != null && !message.contains('HTTP')) {
      message = '$message (HTTP $statusCode)';
    }

    return CodexAuthException(
      message,
      code: code,
      reloginRequired: reloginRequired,
    );
  }
}

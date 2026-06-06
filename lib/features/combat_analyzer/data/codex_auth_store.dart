import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../../../core/logging/logger.dart';
import '../../../core/platform/app_paths.dart';

const String codexProviderId = 'openai-codex';
const String codexAuthMode = 'chatgpt';

class CodexAuthTokens {
  const CodexAuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory CodexAuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw const CodexAuthStoreException('AI auth is missing access_token.');
    }
    if (refreshToken is! String || refreshToken.trim().isEmpty) {
      throw const CodexAuthStoreException('AI auth is missing refresh_token.');
    }
    return CodexAuthTokens(
      accessToken: accessToken.trim(),
      refreshToken: refreshToken.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };

  DateTime? get accessTokenExpiry => jwtExpiry(accessToken);

  bool accessTokenIsExpiring({int skewSeconds = 120}) {
    final expiry = accessTokenExpiry;
    if (expiry == null) return false;
    final refreshAt = expiry.subtract(Duration(seconds: skewSeconds));
    return !DateTime.now().toUtc().isBefore(refreshAt);
  }
}

class CodexAuthState {
  const CodexAuthState({
    required this.tokens,
    required this.lastRefresh,
    required this.authMode,
  });

  final CodexAuthTokens tokens;
  final String? lastRefresh;
  final String authMode;
}

class CodexAuthStoreException implements Exception {
  const CodexAuthStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CodexAuthStore {
  CodexAuthStore({String? authFilePath}) : _authFilePath = authFilePath;

  final String? _authFilePath;

  Future<String> get authFilePath async {
    if (_authFilePath != null) return _authFilePath;
    return getMimirAuthFilePath();
  }

  Future<bool> hasTokens() async {
    Log.d('AUTH.CODEX', 'hasTokens() - START');
    try {
      await readState();
      Log.d('AUTH.CODEX', 'hasTokens() - true');
      return true;
    } on CodexAuthStoreException {
      Log.d('AUTH.CODEX', 'hasTokens() - false');
      return false;
    }
  }

  Future<CodexAuthState> readState() async {
    Log.d('AUTH.CODEX', 'readState() - START');
    final store = await _loadStore();
    final providers = store['providers'];
    if (providers is! Map) {
      throw const CodexAuthStoreException('AI auth store is invalid.');
    }
    final providerState = providers[codexProviderId];
    if (providerState is! Map) {
      throw const CodexAuthStoreException(
        'No AI credentials stored. Sign in to AI first.',
      );
    }
    final tokensJson = providerState['tokens'];
    if (tokensJson is! Map) {
      throw const CodexAuthStoreException(
        'AI auth state is missing tokens. Sign in again.',
      );
    }
    final state = CodexAuthState(
      tokens: CodexAuthTokens.fromJson(Map<String, dynamic>.from(tokensJson)),
      lastRefresh: providerState['last_refresh'] as String?,
      authMode: (providerState['auth_mode'] as String?) ?? codexAuthMode,
    );
    Log.d('AUTH.CODEX', 'readState() - SUCCESS');
    return state;
  }

  Future<void> saveTokens(CodexAuthTokens tokens, {String? lastRefresh}) async {
    Log.d('AUTH.CODEX', 'saveTokens() - START');
    final store = await _loadStore();
    final providers = _providers(store);
    providers[codexProviderId] = {
      'tokens': tokens.toJson(),
      'last_refresh': lastRefresh ?? _nowIso8601(),
      'auth_mode': codexAuthMode,
    };
    store['active_provider'] = codexProviderId;
    await _saveStore(store);
    Log.i('AUTH.CODEX', 'Saved AI auth state');
  }

  Future<void> clear() async {
    Log.d('AUTH.CODEX', 'clear() - START');
    final store = await _loadStore();
    final providers = _providers(store);
    providers.remove(codexProviderId);
    if (store['active_provider'] == codexProviderId) {
      store['active_provider'] = null;
    }
    await _saveStore(store);
    Log.i('AUTH.CODEX', 'Cleared AI auth state');
  }

  Future<bool> importCodexCliTokens() async {
    Log.d('AUTH.CODEX', 'importAiCliTokens() - START');
    final codexHome = Platform.environment['CODEX_HOME']?.trim();
    final home = Platform.environment['HOME']?.trim();
    final authPath = codexHome != null && codexHome.isNotEmpty
        ? p.join(codexHome, 'auth.json')
        : home == null || home.isEmpty
        ? null
        : p.join(home, '.codex', 'auth.json');
    if (authPath == null) {
      Log.d('AUTH.CODEX', 'No home path available for AI CLI import');
      return false;
    }

    final file = File(authPath);
    if (!await file.exists()) {
      Log.d('AUTH.CODEX', 'AI CLI auth file not found');
      return false;
    }

    try {
      final payload = jsonDecode(await file.readAsString());
      if (payload is! Map) return false;
      final tokensJson = payload['tokens'];
      if (tokensJson is! Map) return false;
      final tokens = CodexAuthTokens.fromJson(
        Map<String, dynamic>.from(tokensJson),
      );
      if (tokens.accessTokenIsExpiring(skewSeconds: 0)) {
        Log.w('AUTH.CODEX', 'AI CLI token is expired; skipping import');
        return false;
      }
      await saveTokens(tokens);
      Log.i('AUTH.CODEX', 'Imported AI CLI credentials into Mimir auth');
      return true;
    } catch (e, stack) {
      Log.e('AUTH.CODEX', 'Failed to import AI CLI credentials', e, stack);
      return false;
    }
  }

  Future<Map<String, dynamic>> _loadStore() async {
    final path = await authFilePath;
    final file = File(path);
    if (!await file.exists()) {
      return {'version': 1, 'providers': <String, dynamic>{}};
    }
    _chmod(file.parent.path, 0x1C0); // 0700
    _chmod(file.path, 0x180); // 0600

    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map) {
        final store = Map<String, dynamic>.from(raw);
        if (store['providers'] is! Map) {
          store['providers'] = <String, dynamic>{};
        }
        return store;
      }
    } catch (e, stack) {
      Log.e('AUTH.CODEX', 'Failed to parse auth store', e, stack);
      final corrupt = File('$path.corrupt');
      try {
        await file.copy(corrupt.path);
      } catch (_) {
        // Best-effort preservation only.
      }
    }
    return {'version': 1, 'providers': <String, dynamic>{}};
  }

  Future<void> _saveStore(Map<String, dynamic> store) async {
    final path = await authFilePath;
    final file = File(path);
    final directory = file.parent;
    await directory.create(recursive: true);
    _chmod(directory.path, 0x1C0); // 0700

    store['version'] = 1;
    store['updated_at'] = _nowIso8601();

    final payload = const JsonEncoder.withIndent('  ').convert(store);
    final tmpPath =
        '${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}.$pid';
    final tmpFile = File(tmpPath);
    try {
      final sink = tmpFile.openWrite(mode: FileMode.writeOnly);
      sink.write(payload);
      sink.write('\n');
      await sink.flush();
      await sink.close();
      _chmod(tmpFile.path, 0x180); // 0600
      if (await file.exists()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
      _chmod(file.path, 0x180); // 0600
    } finally {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
    }
  }

  Map<String, dynamic> _providers(Map<String, dynamic> store) {
    final existing = store['providers'];
    if (existing is Map) {
      final providers = Map<String, dynamic>.from(existing);
      store['providers'] = providers;
      return providers;
    }
    final providers = <String, dynamic>{};
    store['providers'] = providers;
    return providers;
  }

  String _nowIso8601() => DateTime.now().toUtc().toIso8601String();

  void _chmod(String path, int mode) {
    if (Platform.isWindows) return;
    try {
      final pathPointer = path.toNativeUtf8();
      try {
        final result = _posixChmod()(pathPointer, mode);
        if (result != 0) {
          Log.w('AUTH.CODEX', 'chmod failed for auth path');
        }
      } finally {
        calloc.free(pathPointer);
      }
    } catch (e) {
      Log.w('AUTH.CODEX', 'chmod unavailable: $e');
    }
  }
}

typedef _ChmodNative = Int32 Function(Pointer<Utf8> path, Uint32 mode);
typedef _ChmodDart = int Function(Pointer<Utf8> path, int mode);

_ChmodDart? _cachedPosixChmod;

_ChmodDart _posixChmod() {
  return _cachedPosixChmod ??= DynamicLibrary.process()
      .lookupFunction<_ChmodNative, _ChmodDart>('chmod');
}

DateTime? jwtExpiry(String token) {
  final claims = jwtClaims(token);
  final exp = claims?['exp'];
  if (exp is int) {
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }
  if (exp is num) {
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  }
  return null;
}

String? chatGptAccountIdFromAccessToken(String token) {
  final claims = jwtClaims(token);
  final auth = claims?['https://api.openai.com/auth'];
  if (auth is Map) {
    final accountId = auth['chatgpt_account_id'];
    if (accountId is String && accountId.trim().isNotEmpty) {
      return accountId.trim();
    }
  }
  return null;
}

@visibleForTesting
Map<String, dynamic>? jwtClaims(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    if (json is Map) {
      return Map<String, dynamic>.from(json);
    }
  } catch (_) {
    return null;
  }
  return null;
}

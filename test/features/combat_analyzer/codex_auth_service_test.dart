import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/codex_analysis_client.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_service.dart';
import 'package:mimir/features/combat_analyzer/data/codex_auth_store.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';

void main() {
  group('CodexAuthStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mimir_codex_store_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves Codex tokens in a Hermes-compatible provider block', () async {
      final store = CodexAuthStore(authFilePath: '${tempDir.path}/auth.json');

      await store.saveTokens(
        const CodexAuthTokens(accessToken: 'access', refreshToken: 'refresh'),
        lastRefresh: '2026-05-20T00:00:00Z',
      );

      final authFile = File('${tempDir.path}/auth.json');
      final payload =
          jsonDecode(await authFile.readAsString()) as Map<String, dynamic>;
      expect(payload['active_provider'], codexProviderId);
      expect(
        payload['providers'][codexProviderId]['tokens']['access_token'],
        'access',
      );
      expect(
        payload['providers'][codexProviderId]['tokens']['refresh_token'],
        'refresh',
      );
      expect(payload['providers'][codexProviderId]['auth_mode'], codexAuthMode);
      if (!Platform.isWindows) {
        final mode = (await authFile.stat()).mode & 0x1ff;
        expect(mode, 0x180);
      }
    });

    test('repairs broad auth file permissions on read', () async {
      if (Platform.isWindows) return;

      final authFile = File('${tempDir.path}/auth.json');
      await authFile.writeAsString(
        jsonEncode({
          'version': 1,
          'active_provider': codexProviderId,
          'providers': {
            codexProviderId: {
              'tokens': {'access_token': 'access', 'refresh_token': 'refresh'},
              'auth_mode': codexAuthMode,
            },
          },
        }),
      );
      await Process.run('chmod', ['644', authFile.path]);
      final store = CodexAuthStore(authFilePath: authFile.path);

      final state = await store.readState();

      expect(state.tokens.accessToken, 'access');
      final mode = (await authFile.stat()).mode & 0x1ff;
      expect(mode, 0x180);
    });
  });

  group('CodexAuthService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mimir_codex_service_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('runs Codex device flow and stores app-owned tokens', () async {
      final adapter = _QueuedDioAdapter([
        (options) {
          expect(options.path, '$codexIssuer/api/accounts/deviceauth/usercode');
          expect(options.data['client_id'], codexClientId);
          return _jsonResponse(200, {
            'user_code': 'ABCD-EFGH',
            'device_auth_id': 'device-123',
            'interval': 1,
          });
        },
        (options) {
          expect(options.path, '$codexIssuer/api/accounts/deviceauth/token');
          expect(options.data['device_auth_id'], 'device-123');
          expect(options.data['user_code'], 'ABCD-EFGH');
          return _jsonResponse(200, {
            'authorization_code': 'auth-code',
            'code_verifier': 'verifier',
          });
        },
        (options) {
          expect(options.path, codexTokenEndpoint);
          expect(options.data['grant_type'], 'authorization_code');
          expect(options.data['redirect_uri'], codexDeviceRedirectUri);
          return _jsonResponse(200, {
            'access_token': _jwt({'exp': _futureExp()}),
            'refresh_token': 'refresh-token',
          });
        },
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final store = CodexAuthStore(authFilePath: '${tempDir.path}/auth.json');
      final service = CodexAuthService(
        authStore: store,
        dio: dio,
        delay: (_) async {},
      );

      final session = await service.startDeviceFlow();
      expect(session.userCode, 'ABCD-EFGH');
      expect(session.verificationUri, codexDeviceVerificationUri);

      final tokens = await service.completeDeviceFlow(session);

      expect(tokens.refreshToken, 'refresh-token');
      final state = await store.readState();
      expect(state.tokens.refreshToken, 'refresh-token');
      expect(adapter.requests, hasLength(3));
    });

    test(
      'refreshes expiring tokens and preserves rotated refresh token',
      () async {
        final adapter = _QueuedDioAdapter([
          (options) {
            expect(options.path, codexTokenEndpoint);
            expect(options.data['grant_type'], 'refresh_token');
            expect(options.data['refresh_token'], 'old-refresh');
            return _jsonResponse(200, {
              'access_token': _jwt({'exp': _futureExp()}),
              'refresh_token': 'new-refresh',
            });
          },
        ]);
        final dio = Dio()..httpClientAdapter = adapter;
        final store = CodexAuthStore(authFilePath: '${tempDir.path}/auth.json');
        await store.saveTokens(
          CodexAuthTokens(
            accessToken: _jwt({'exp': _pastExp()}),
            refreshToken: 'old-refresh',
          ),
        );
        final service = CodexAuthService(authStore: store, dio: dio);

        final credentials = await service.resolveRuntimeCredentials();

        expect(credentials.accessToken, isNot(equals('old-access')));
        expect((await store.readState()).tokens.refreshToken, 'new-refresh');
        expect(adapter.requests, hasLength(1));
      },
    );
  });

  group('CodexAnalysisClient', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mimir_codex_analysis_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'posts Responses payload without chat-completions-only fields',
      () async {
        final adapter = _QueuedDioAdapter([
          (options) {
            expect(options.path, '$codexDefaultBaseUrl/responses');
            expect(options.headers['originator'], 'codex_cli_rs');
            expect(options.headers['ChatGPT-Account-ID'], 'acct_123');
            expect(options.headers['Accept'], 'text/event-stream');
            expect(options.data, isNot(contains('temperature')));
            expect(options.data, isNot(contains('max_output_tokens')));
            expect(options.data['model'], codexDefaultModel);
            expect(options.data['stream'], isTrue);
            return _textResponse(
              200,
              _sseOutputText(
                jsonEncode({
                  'summary': 'Summary',
                  'mistakes': 'Mistakes',
                  'improvements': 'Improvements',
                  'fits': 'Fits',
                }),
              ),
            );
          },
        ]);
        final analysisDio = Dio()..httpClientAdapter = adapter;
        final store = CodexAuthStore(authFilePath: '${tempDir.path}/auth.json');
        await store.saveTokens(
          CodexAuthTokens(
            accessToken: _jwt({
              'exp': _futureExp(),
              'https://api.openai.com/auth': {'chatgpt_account_id': 'acct_123'},
            }),
            refreshToken: 'refresh',
          ),
        );
        final authService = CodexAuthService(authStore: store, dio: Dio());
        final client = CodexAnalysisClient(
          authService: authService,
          dio: analysisDio,
        );

        final encounter = CombatLogParser.parseLines([
          'Listener: Pilot',
          '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Railgun - Hits',
          '[ 2026.05.20 20:00:05 ] (combat) 50 from Enemy - Blaster - Hits',
        ]).single;

        final result = await client.analyzeEncounter(
          model: codexDefaultModel,
          encounter: encounter,
        );

        expect(result.summary, 'Summary');
        expect(result.fits, 'Fits');
        expect(adapter.requests, hasLength(1));
      },
    );
  });
}

class _QueuedDioAdapter implements HttpClientAdapter {
  _QueuedDioAdapter(this._handlers);

  final List<ResponseBody Function(RequestOptions options)> _handlers;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_handlers.isEmpty) {
      return _jsonResponse(500, {'error': 'unexpected request'});
    }
    return _handlers.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _textResponse(int statusCode, String body) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    },
  );
}

String _sseOutputText(String text) {
  return [
    'event: response.output_text.delta',
    'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': text})}',
    '',
    'event: response.output_text.done',
    'data: ${jsonEncode({'type': 'response.output_text.done', 'text': text})}',
    '',
  ].join('\n');
}

String _jwt(Map<String, dynamic> claims) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

int _futureExp() =>
    DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .millisecondsSinceEpoch ~/
    1000;

int _pastExp() =>
    DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 5))
        .millisecondsSinceEpoch ~/
    1000;

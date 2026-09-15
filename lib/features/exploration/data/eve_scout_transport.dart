import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/config/app_config.dart';
import '../../../core/logging/logger.dart';

class EveScoutRequest {
  const EveScoutRequest({required this.uri, this.headers = const {}});

  final Uri uri;
  final Map<String, String> headers;
}

class FeedHttpResult {
  const FeedHttpResult({
    required this.statusCode,
    this.body = '',
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;

  bool get isNotModified => statusCode == 304;
}

abstract class EveScoutTransport {
  Future<FeedHttpResult> send(EveScoutRequest request);
}

class FeedRefreshOutcome {
  const FeedRefreshOutcome({
    required this.kind,
    this.revision,
    this.nextAttempt,
    this.payloadReceivedAt,
    this.lastValidatedAt,
    this.error,
  });

  final FeedRefreshKind kind;
  final int? revision;
  final DateTime? nextAttempt;
  final DateTime? payloadReceivedAt;
  final DateTime? lastValidatedAt;
  final String? error;
}

enum FeedRefreshKind {
  updated,
  validatedNotModified,
  usingCacheUntil,
  joinedRequest,
  failedWithCache,
  failedWithoutCache,
}

class HttpEveScoutTransport implements EveScoutTransport {
  HttpEveScoutTransport({
    this.timeout = const Duration(seconds: 15),
    this.maxBytes = 8 * 1024 * 1024,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory;

  final Duration timeout;
  final int maxBytes;
  final HttpClient Function()? _clientFactory;

  static String userAgent({String version = AppConfig.version}) {
    return 'Mimir/$version (+https://github.com/infiquetra/mimir)';
  }

  @override
  Future<FeedHttpResult> send(EveScoutRequest request) async {
    Log.d('EXPLORATION.FEED', 'HTTP GET ${request.uri.path}');
    final client = (_clientFactory ?? HttpClient.new)();
    client.autoUncompress = true;
    try {
      final httpRequest = await client.getUrl(request.uri).timeout(timeout);
      httpRequest.followRedirects = false;
      httpRequest.maxRedirects = 0;
      request.headers.forEach(httpRequest.headers.set);
      final response = await httpRequest.close().timeout(timeout);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const SocketException('Unexpected redirect');
      }
      final declared = response.contentLength;
      if (declared > maxBytes) {
        throw const FormatException('EVE-Scout response exceeded 8MiB.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw const FormatException('EVE-Scout response exceeded 8MiB.');
        }
      }
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) headers[name.toLowerCase()] = values.first;
      });
      return FeedHttpResult(
        statusCode: response.statusCode,
        body: utf8.decode(builder.takeBytes()),
        headers: headers,
      );
    } on TimeoutException {
      Log.w('EXPLORATION.FEED', 'HTTP deadline exceeded');
      return const FeedHttpResult(statusCode: 0, body: '');
    } finally {
      client.close(force: true);
    }
  }
}

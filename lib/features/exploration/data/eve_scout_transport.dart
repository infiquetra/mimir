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

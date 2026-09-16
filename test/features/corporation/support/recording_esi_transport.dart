class RecordingEsiResponse {
  const RecordingEsiResponse({
    required this.statusCode,
    this.body = '',
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// Recording ESI transport. Unexpected calls fail the test.
class RecordingEsiTransport {
  RecordingEsiTransport();

  final List<Uri> requests = [];
  final List<Map<String, String>> requestHeaders = [];
  final List<String> writes = [];
  bool failUnexpected = true;
  RecordingEsiResponse? nextResponse;

  Future<RecordingEsiResponse> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    requests.add(uri);
    requestHeaders.add(Map<String, String>.from(headers ?? const {}));
    if (nextResponse != null) {
      final response = nextResponse!;
      nextResponse = null;
      return response;
    }
    if (failUnexpected) {
      throw StateError('unexpected ESI HTTP: $uri');
    }
    return const RecordingEsiResponse(statusCode: 200, body: '{}');
  }

  void assertNoWrites() {
    if (writes.isNotEmpty) {
      throw StateError('unexpected ESI write: $writes');
    }
  }
}

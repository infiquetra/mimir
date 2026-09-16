import 'dart:convert';

import '../domain/corporation_decimal.dart';
import 'corporation_endpoint_registry.dart';

class CorporationEsiResponse {
  const CorporationEsiResponse({
    required this.statusCode,
    required this.body,
    required this.uri,
    this.headers = const {},
    this.decoded,
  });

  final int statusCode;
  final String body;
  final Uri uri;
  final Map<String, String> headers;
  final Object? decoded;
}

/// Naive decoder: [jsonDecode] before lexeme capture.
class LosslessEsiJsonDecoder {
  const LosslessEsiJsonDecoder();

  Object? decode(String body) => jsonDecode(body);
}

class CorporationEsiClient {
  CorporationEsiClient({
    required this.send,
    this.registry = const CorporationEndpointRegistry(),
    this.decoder = const LosslessEsiJsonDecoder(),
  });

  final Future<CorporationEsiResponse> Function(
    String method,
    Uri uri,
    Map<String, String> headers, [
    String? body,
  ])
  send;
  final CorporationEndpointRegistry registry;
  final LosslessEsiJsonDecoder decoder;

  Future<CorporationEsiResponse> request(
    CorporationEndpoint endpoint, {
    Map<String, String> path = const {},
    int? corporationId,
    int? characterId,
  }) async {
    var template = endpoint.pathTemplate;
    path.forEach((key, value) {
      template = template.replaceAll('{$key}', value);
    });
    if (corporationId != null) {
      template = template.replaceAll('{corporation_id}', '$corporationId');
    }
    if (characterId != null) {
      template = template.replaceAll('{character_id}', '$characterId');
    }
    final uri = Uri.parse('${CorporationEndpointRegistry.root}$template');
    final headers = <String, String>{
      'X-Tenant': CorporationEndpointRegistry.tenant,
      'User-Agent': 'Mimir-test',
    };
    final response = await send(endpoint.method, uri, headers);
    return CorporationEsiResponse(
      statusCode: response.statusCode,
      body: response.body,
      uri: uri,
      headers: headers,
      decoded: decoder.decode(response.body),
    );
  }
}

ExactDecimal? exactFromDecoded(Object? value) {
  if (value is ExactDecimal) return value;
  if (value is num) return ExactDecimal.fromNum(value);
  if (value is String) return ExactDecimal.parse(value);
  return null;
}

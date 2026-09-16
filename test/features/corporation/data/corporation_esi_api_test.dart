// C2 RED: CorporationEsiClient must hit the modern root, send compatibility
// headers, and preserve numeric lexemes before jsonDecode.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_endpoint_registry.dart';
import 'package:mimir/features/corporation/data/corporation_esi_api.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';

void main() {
  test(
    'sends X-Compatibility-Date 2026-08-18, X-Tenant, User-Agent, no /latest',
    () async {
      Uri? sentUri;
      Map<String, String>? sentHeaders;
      final api = CorporationEsiClient(
        send: (method, uri, headers, [body]) async {
          sentUri = uri;
          sentHeaders = headers;
          return CorporationEsiResponse(
            statusCode: 200,
            body: '{}',
            uri: uri,
            headers: headers,
          );
        },
      );
      final endpoint = const CorporationEndpointRegistry().lookup(
        'corporationPublic',
      )!;
      await api.request(endpoint, corporationId: 7001);
      expect(sentUri, isNotNull);
      expect(sentUri!.host, 'esi.evetech.net');
      expect(sentUri!.path.contains('/latest'), isFalse);
      expect(sentHeaders!['X-Compatibility-Date'], '2026-08-18');
      expect(sentHeaders!['X-Tenant'], 'tranquility');
      expect(sentHeaders!['User-Agent'], isNotEmpty);
    },
  );

  test('LosslessEsiJsonDecoder keeps 1.005 as ExactDecimal', () {
    const decoder = LosslessEsiJsonDecoder();
    final decoded =
        decoder.decode('{"unit_price":1.005,"id":900}') as Map<String, dynamic>;
    expect(decoded['unit_price'], isA<ExactDecimal>());
    expect((decoded['unit_price'] as ExactDecimal).toExactString(), '1.005');
    expect(decoded['id'], 900);
  });
}

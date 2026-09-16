// C0 RED harness: frozen T0 and unexpected ESI HTTP fail the test.
library;

import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';
import 'corporation_test_harness.dart';

void main() {
  late CorporationTestHarness harness;

  setUp(() async {
    harness = CorporationTestHarness();
    await harness.setUp();
  });

  tearDown(() async {
    await harness.tearDown();
  });

  test('clock is T0', () {
    expect(harness.clock.now(), kCorporationT0);
    expect(CorporationTestHarness.t0, DateTime.utc(2026, 9, 15, 12));
  });

  test('unexpected ESI HTTP is a harness failure', () async {
    await expectLater(
      () => harness.transport.get(
        Uri.parse('https://esi.evetech.net/latest/corporations/7001/'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('unexpected ESI HTTP'),
        ),
      ),
    );
    expect(harness.transport.requests, hasLength(1));
  });

  test('F1–F8 fixture files load', () {
    expect(F1Fixtures.allNine().map((row) => row.name).toList(), [
      'Ada',
      'Bea',
      'Cyra',
      'Dara',
      'Eren',
      'Finn',
      'Gale',
      'Hana',
      'Iona',
    ]);
    expect(F2Fixtures.currentProfile()['ticker'], 'HELI');
    expect(F3Fixtures.rows(), hasLength(11));
    expect(F4Fixtures.bay(), isNotEmpty);
    expect(F5Fixtures.balances(), hasLength(7));
    expect(F8Fixtures.widths, hasLength(4));
  });
}

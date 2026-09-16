// C2 RED: all-page validation, page-1-only 304, missing X-Pages, cursor loops.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_page_assembler.dart';
import 'package:mimir/features/corporation/domain/corporation_snapshot.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const assembler = CorporationPageAssembler();

  test('all pages share one generation or the snapshot is rejected', () {
    expect(
      assembler.acceptsMixedGeneration(const [
        AssembledPage(page: 1, statusCode: 200, xPages: 2, generation: 1),
        AssembledPage(page: 2, statusCode: 200, xPages: 2, generation: 2),
      ]),
      isFalse,
    );
  });

  test('page-1-only 304 does not renew the whole snapshot', () {
    final result = assembler.assemble(
      const [
        AssembledPage(page: 1, statusCode: 304, xPages: 2, items: [1]),
      ],
      payloadReceivedAt: kCorporationT0,
      validatedAt: kCorporationT0.add(const Duration(hours: 1)),
    );
    expect(result.outcome, isNot(RefreshOutcome.notModifiedRenewedAll));
    expect(result.envelope.complete, isFalse);
    expect(result.envelope.times.payloadReceivedAt, kCorporationT0);
  });

  test('missing X-Pages on a nonempty result is incomplete', () {
    final result = assembler.assemble(const [
      AssembledPage(page: 1, statusCode: 200, items: [1, 2]),
    ]);
    expect(result.envelope.complete, isFalse);
  });

  test('cursor pages reject loops and keep three unique ids', () {
    expect(
      assembler.followCursor([
        [900, 899],
        [899, 898],
        const <int>[],
      ]),
      [900, 899, 898],
    );
    expect(
      () => assembler.followCursor([
        [900, 899],
        [900, 899],
      ]),
      throwsA(isA<StateError>()),
    );
  });
}

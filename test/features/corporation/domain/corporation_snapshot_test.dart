// C0 RED contracts for SnapshotEnvelope, clocks, 304, and Date/Age math (F6).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_snapshot.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const freshness = SnapshotFreshness();

  group('SnapshotEnvelope times', () {
    test('absent timestamps are not time zero', () {
      const envelope = SnapshotEnvelope<List<int>>(payload: []);
      expect(envelope.times.payloadReceivedAt, isNull);
      expect(envelope.times.validatedAt, isNull);
      expect(envelope.complete, isTrue);
    });

    test('lease equality at T0+1h locks; T0+1h-1ms allows', () {
      final leaseEnd = kCorporationT0.add(const Duration(hours: 1));
      expect(
        freshness.offlineReadAllowed(
          now: leaseEnd.subtract(const Duration(milliseconds: 1)),
          leaseEndsAt: leaseEnd,
        ),
        isTrue,
      );
      expect(
        freshness.offlineReadAllowed(now: leaseEnd, leaseEndsAt: leaseEnd),
        isFalse,
      );
    });
  });

  group('F6 Date/Age freshness', () {
    test('Date plus Age is 12:58 not 13:00 or 12:56', () {
      final deadline = freshness.deadline(
        receivedAt: kCorporationT0,
        dateHeader: kCorporationT0.subtract(const Duration(seconds: 120)),
        ageSeconds: 120,
        maxAgeSeconds: 3600,
      );
      expect(deadline, DateTime.utc(2026, 9, 15, 12, 58));
    });

    test('page-1-only 304 does not renew the complete snapshot', () {
      expect(
        freshness.applyNotModified(pageOneOnly: true),
        isNot(RefreshOutcome.notModifiedRenewedAll),
      );
    });
  });

  group('PageEvidence and HistoryCoverage', () {
    test('missing X-Pages on a nonempty result is partial', () {
      const page = PageEvidence(page: 1, xPages: null, statusCode: 200);
      expect(page.xPages, isNull);
      expect(freshness.deriveComplete(const [1], const [page]), isFalse);
    });

    test('empty response is exhaustion, not a short page', () {
      const coverage = HistoryCoverage(
        complete: true,
        rowCount: 3,
        termination: 'empty-page',
      );
      expect(coverage.termination, 'empty-page');
      expect(coverage.complete, isTrue);
    });
  });
}

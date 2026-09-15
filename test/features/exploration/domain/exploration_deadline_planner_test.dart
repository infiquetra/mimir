// X5 RED contracts for ExplorationDeadlinePlanner (§4.8).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN uses exact +5m/+24h wakes and the +1ms ticks
// for origin 60s and EOL (expiresAt − 4h + 1ms).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_deadline_planner.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  group('ExplorationDeadlinePlanner §4.8', () {
    test('public stale and view-only fire at exact 5m and 24h', () {
      expect(
        ExplorationDeadlinePlanner.publicBecomesStale(kExplorationT0),
        F4Fixtures.staleAt,
      );
      expect(
        ExplorationDeadlinePlanner.publicBecomesViewOnly(kExplorationT0),
        F4Fixtures.twentyFourHours,
      );
    });

    test('local verification expires at verifiedAt + 24h exactly', () {
      final verified = DateTime.utc(2026, 9, 14, 12);
      expect(
        ExplorationDeadlinePlanner.localVerificationExpires(verified),
        kExplorationT0,
      );
    });

    test('current origin stops at observedAt + 60s + 1ms', () {
      expect(
        ExplorationDeadlinePlanner.currentOriginStopsBeingCurrent(
          kExplorationT0,
        ),
        kExplorationT0.add(const Duration(seconds: 60, milliseconds: 1)),
      );
    });

    test('EOL starts at expiresAt − 4h + 1ms; expiry is exact', () {
      expect(
        ExplorationDeadlinePlanner.stableBecomesEol(F3Fixtures.expiresAt),
        F3Fixtures.eolAt4hPlus1ms,
      );
      expect(
        ExplorationDeadlinePlanner.pastReportedExpiry(F3Fixtures.expiresAt),
        F3Fixtures.expiresAt,
      );
    });

    test('earliest wake is the next exact boundary', () {
      final next = ExplorationDeadlinePlanner.earliest(
        publicValidatedAt: kExplorationT0,
        originObservedAt: kExplorationT0,
        expiresAt: F3Fixtures.expiresAt,
      );
      expect(next, F4Fixtures.staleAt);
    });
  });
}

// C2 RED: 1h lease equality locks, 403 hides cache, self-roles do not
// deadlock, corporation 0 never requests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_authorization_repository.dart';
import 'package:mimir/features/corporation/domain/corporation_access.dart';
import 'package:mimir/features/corporation/domain/corporation_context.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';
import '../support/fake_corporation_clock.dart';

void main() {
  late FakeCorporationClock clock;
  late CorporationAuthorizationRepository repository;

  setUp(() {
    clock = FakeCorporationClock(now: kCorporationT0);
    repository = CorporationAuthorizationRepository(clock: clock.now);
  });

  test('lease allows at expiry-1ms and locks at equality', () {
    repository.recordSuccess(
      characterId: kCyraId,
      capability: Capability.assets,
      validatedAt: kCorporationT0,
    );
    final until = kCorporationT0.add(const Duration(hours: 1));
    clock.setNow(until.subtract(const Duration(milliseconds: 1)));
    expect(
      repository.isVisible(characterId: kCyraId, capability: Capability.assets),
      isTrue,
    );
    clock.setNow(until);
    expect(
      repository.isVisible(characterId: kCyraId, capability: Capability.assets),
      isFalse,
    );
  });

  test('403 denial hides cached payload and does not renew from cache', () {
    repository.recordSuccess(
      characterId: kCyraId,
      capability: Capability.assets,
      validatedAt: kCorporationT0,
    );
    repository.recordDenial(
      characterId: kCyraId,
      capability: Capability.assets,
    );
    expect(
      repository.isVisible(characterId: kCyraId, capability: Capability.assets),
      isFalse,
    );
    expect(repository.cacheReadRenewsLease(), isFalse);
  });

  test('self-role refresh does not require a corporate read permit', () {
    expect(repository.mayRefreshSelfRoles(hasCorporatePermit: false), isTrue);
  });

  test('corporation 0 and unselected character issue no requests', () {
    expect(
      repository.mayRequest(
        context: const CorporationContext(
          characterId: kAdaId,
          corporationId: 0,
        ),
        capability: Capability.assets,
      ),
      isFalse,
    );
    expect(
      repository.mayRequest(
        context: const CorporationContext(corporationId: kHeliosId),
        capability: Capability.roster,
      ),
      isFalse,
    );
    expect(repository.issuedRequests, isEmpty);
  });
}

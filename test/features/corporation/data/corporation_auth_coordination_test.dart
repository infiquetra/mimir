// C2 RED: wrong-subject callbacks rejected, cancel preserves grant,
// reauth quarantines then rebinds, scope reduction purges.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_authorization_coordinator.dart';
import 'package:mimir/features/corporation/domain/corporation_access.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  late CorporationAuthorizationCoordinator coordinator;

  setUp(() {
    coordinator = CorporationAuthorizationCoordinator();
    coordinator.start(
      operationId: 'op-1',
      intendedCharacterId: kCyraId,
      scopes: {'esi-assets.read_corporation_assets.v1'},
      grantEpoch: 1,
    );
  });

  test('wrong character callback is rejected and does not overwrite Cyra', () {
    final transition = coordinator.completeCallback(
      operationId: 'op-1',
      callbackCharacterId: kAdaId,
    );
    expect(transition, GrantTransition.unchanged);
    expect(coordinator.grants[kCyraId]?.status, 'pending');
    expect(coordinator.grants.containsKey(kAdaId), isFalse);
    expect(coordinator.grants[kCyraId]?.grantEpoch, 1);
  });

  test('cancelled OAuth preserves the existing valid grant', () {
    final transition = coordinator.cancel('op-1');
    expect(transition, isNot(GrantTransition.purged));
    expect(coordinator.grants[kCyraId], isNotNull);
    expect(coordinator.grants[kCyraId]!.status, 'cancelled');
    expect(coordinator.grants[kCyraId]!.grantEpoch, 1);
    expect(coordinator.grants[kCyraId]!.scopes, {
      'esi-assets.read_corporation_assets.v1',
    });
  });

  test(
    'same-owner reauth quarantines then rebinds; scope reduction purges',
    () {
      var transition = coordinator.reauthorize(
        characterId: kCyraId,
        newScopes: {
          'esi-assets.read_corporation_assets.v1',
          'esi-wallet.read_corporation_wallets.v1',
        },
      );
      expect(transition, GrantTransition.quarantined);
      expect(coordinator.grants[kCyraId]!.quarantined, isTrue);
      expect(coordinator.grants[kCyraId]!.grantEpoch, greaterThan(1));

      transition = coordinator.reauthorize(
        characterId: kCyraId,
        newScopes: {
          'esi-assets.read_corporation_assets.v1',
          'esi-wallet.read_corporation_wallets.v1',
        },
      );
      expect(transition, GrantTransition.rebound);
      expect(coordinator.grants[kCyraId]!.quarantined, isFalse);

      transition = coordinator.reauthorize(
        characterId: kCyraId,
        newScopes: {'esi-assets.read_corporation_assets.v1'},
      );
      expect(transition, GrantTransition.purged);
      expect(
        coordinator.grants[kCyraId]!.scopes.contains(
          'esi-wallet.read_corporation_wallets.v1',
        ),
        isFalse,
      );
    },
  );
}

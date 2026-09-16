// C0 RED contracts for context, grants, and capability evaluation (F1).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_access.dart';
import 'package:mimir/features/corporation/domain/corporation_context.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const evaluator = CapabilityEvaluator();

  AccessDecision decide(
    F1Character character,
    Capability capability, {
    int? ceo,
  }) {
    return evaluator.evaluate(
      context: character.context(),
      capability: capability,
      roles: character.evidence(),
      grantedScopes: character.grantedScopes,
      publicCeoId: ceo,
    );
  }

  bool allowed(AccessDecision decision) => decision is AccessAllowed;

  group('CorporationContext', () {
    test('corporation 0 is unresolved, not a member', () {
      const context = CorporationContext(characterId: kAdaId, corporationId: 0);
      expect(context.corporationId, 0);
      expect(context.isResolvedMember, isFalse);
      expect(context.membership, MembershipState.unresolved);
    });

    test('OwnerIncarnation uuid is not a reused numeric generation', () {
      const first = OwnerIncarnation(characterId: kCyraId, uuid: 'a');
      const readded = OwnerIncarnation(characterId: kCyraId, uuid: 'b');
      expect(first.uuid, isNot(readded.uuid));
      expect(first.uuid, isNot('incarnation-0'));
    });
  });

  group('F1 capability matrix', () {
    test('Ada has public/own/roster and locks private capabilities', () {
      final ada = F1Fixtures.ada();
      expect(allowed(decide(ada, Capability.publicProfile)), isTrue);
      expect(allowed(decide(ada, Capability.ownAccess)), isTrue);
      expect(allowed(decide(ada, Capability.roster)), isTrue);
      expect(allowed(decide(ada, Capability.assets)), isFalse);
      expect(allowed(decide(ada, Capability.tracking)), isFalse);
      expect(allowed(decide(ada, Capability.titles)), isFalse);
      expect(allowed(decide(ada, Capability.divisionNames)), isFalse);
      expect(allowed(decide(ada, Capability.structures)), isFalse);
      expect(allowed(decide(ada, Capability.wallets)), isFalse);
    });

    test('Bea unlocks roles but not tracking or Director features', () {
      final bea = F1Fixtures.bea();
      expect(allowed(decide(bea, Capability.roles)), isTrue);
      expect(allowed(decide(bea, Capability.tracking)), isFalse);
      expect(allowed(decide(bea, Capability.assets)), isFalse);
    });

    test('Cyra Director is eligible for requested read capabilities', () {
      final cyra = F1Fixtures.cyra();
      expect(allowed(decide(cyra, Capability.assets)), isTrue);
      expect(allowed(decide(cyra, Capability.wallets)), isTrue);
      expect(allowed(decide(cyra, Capability.structures)), isTrue);
    });

    test('Dara Station Manager sees structures, not assets or wallets', () {
      final dara = F1Fixtures.dara();
      expect(allowed(decide(dara, Capability.structures)), isTrue);
      expect(allowed(decide(dara, Capability.assets)), isFalse);
      expect(allowed(decide(dara, Capability.structureFuel)), isFalse);
      expect(allowed(decide(dara, Capability.wallets)), isFalse);
    });

    test('Eren and Finn get wallets but not corporate assets', () {
      for (final character in [F1Fixtures.eren(), F1Fixtures.finn()]) {
        expect(allowed(decide(character, Capability.wallets)), isTrue);
        expect(allowed(decide(character, Capability.assets)), isFalse);
        expect(allowed(decide(character, Capability.divisionNames)), isFalse);
      }
    });

    test('Gale Director without wallet scope cannot request wallets', () {
      final gale = F1Fixtures.gale();
      final decision = decide(gale, Capability.wallets);
      expect(decision, isA<AccessLocked>());
      expect((decision as AccessLocked).kind, AccessLockKind.missingScope);
      expect(
        evaluator
            .requestEligibility(
              capability: Capability.wallets,
              grantedScopes: gale.grantedScopes,
              roles: gale.evidence(),
            )
            .allowed,
        isFalse,
      );
    });

    test('Hana assigned hangar/account take does not unlock corp APIs', () {
      final hana = F1Fixtures.hana();
      expect(allowed(decide(hana, Capability.wallets)), isFalse);
      expect(allowed(decide(hana, Capability.assets)), isFalse);
    });

    test('malformed HQ Director and public CEO do not unlock Ada', () {
      final malformed = F1Fixtures.adaMalformedHqDirector();
      expect(allowed(decide(malformed, Capability.assets)), isFalse);
      expect(
        allowed(decide(F1Fixtures.ada(), Capability.assets, ceo: kAdaId)),
        isFalse,
      );
    });

    test('Iona 200 probe is role-list only; 403 is denied without retry', () {
      final iona = F1Fixtures.iona();
      final success = evaluator.evaluate(
        context: iona.context(),
        capability: Capability.roleListProbe,
        roles: iona.evidence(),
        grantedScopes: iona.grantedScopes,
        probeStatus: 200,
      );
      expect(success, isA<AccessAllowed>());
      expect(allowed(decide(iona, Capability.assets)), isFalse);

      final denied = evaluator.evaluate(
        context: iona.context(),
        capability: Capability.roleListProbe,
        roles: iona.evidence(),
        grantedScopes: iona.grantedScopes,
        probeStatus: 403,
      );
      expect(denied, isA<AccessLocked>());
      expect((denied as AccessLocked).kind, AccessLockKind.denied);
    });
  });

  group('F1 location role sets', () {
    test('Ada HQ/Base/Other stay distinct from General', () {
      final ada = F1Fixtures.ada();
      expect(ada.evidence().general, isEmpty);
      expect(ada.hq, ['Hangar_Query_1']);
      expect(ada.base, ['Hangar_Take_2']);
      expect(ada.other, ['Container_Take_3']);
      expect({
        ...ada.hq,
        ...ada.base,
        ...ada.other,
        ...ada.general,
      }, hasLength(3));
    });
  });
}

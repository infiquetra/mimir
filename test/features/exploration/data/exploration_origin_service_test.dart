// X6 RED contracts for ExplorationOriginService (P08).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §3.5:
// - interpretStrict maps every payload to Observed
// - Current stays valid at 60s+1ms via Duration.inSeconds
// - last-known JSON keeps station/tokens
// - manual origin is overwritten on refresh and character switch
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/exploration/data/exploration_origin_service.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  late DateTime clock;
  late ExplorationOriginService service;
  late ExplorationOriginController controller;

  setUp(() {
    clock = kExplorationT0;
    service = ExplorationOriginService(clock: () => clock);
    controller = ExplorationOriginController(service: service);
  });

  group('P08 getCharacterLocationStrict mapping', () {
    test(
      'esi_client declares getCharacterLocationStrict without nullable swallow',
      () {
        final source = File(
          'lib/core/network/esi_client.dart',
        ).readAsStringSync();
        expect(source.contains('getCharacterLocationStrict'), isTrue);
        expect(
          source.contains('await getCharacterLocation(characterId)'),
          isFalse,
        );
      },
    );

    test('401 and 403 map to auth', () {
      expect(
        service.interpretStrict(
          statusCode: 401,
          body: {'error': 'unauthorized'},
        ),
        isA<CharacterLocationFailed>().having(
          (r) => r.kind,
          'kind',
          CharacterLocationFailureKind.auth,
        ),
      );
      expect(
        service.interpretStrict(statusCode: 403, body: {'error': 'forbidden'}),
        isA<CharacterLocationFailed>().having(
          (r) => r.kind,
          'kind',
          CharacterLocationFailureKind.auth,
        ),
      );
    });

    test('transport failure maps to network', () {
      expect(
        service.interpretStrict(error: const SocketException('offline')),
        isA<CharacterLocationFailed>().having(
          (r) => r.kind,
          'kind',
          CharacterLocationFailureKind.network,
        ),
      );
    });

    test('non-int solar_system_id maps to malformed', () {
      expect(
        service.interpretStrict(
          statusCode: 200,
          body: {'solar_system_id': '9101'},
        ),
        isA<CharacterLocationFailed>().having(
          (r) => r.kind,
          'kind',
          CharacterLocationFailureKind.malformed,
        ),
      );
    });

    test('404 and empty body map to noLocation', () {
      expect(
        service.interpretStrict(statusCode: 404),
        isA<CharacterLocationFailed>().having(
          (r) => r.kind,
          'kind',
          CharacterLocationFailureKind.noLocation,
        ),
      );
      expect(
        service.interpretStrict(statusCode: 200, body: const {}),
        isA<CharacterLocationFailed>().having(
          (r) => r.kind,
          'kind',
          CharacterLocationFailureKind.noLocation,
        ),
      );
    });

    test('200 with solar_system_id is an observation', () {
      final result = service.interpretStrict(
        statusCode: 200,
        body: {'solar_system_id': kAlphaSystemId},
        observedAt: kExplorationT0,
      );
      expect(
        result,
        isA<CharacterLocationObserved>()
            .having((r) => r.systemId, 'systemId', kAlphaSystemId)
            .having((r) => r.observedAt, 'observedAt', kExplorationT0),
      );
    });
  });

  group('P08 Current 60s / 60s+1ms', () {
    test('observation is current at 60s and outdated at 60s+1ms', () {
      expect(
        service.isCurrentObservation(
          kExplorationT0,
          kExplorationT0.add(const Duration(seconds: 60)),
        ),
        isTrue,
      );
      expect(
        service.isCurrentObservation(
          kExplorationT0,
          kExplorationT0.add(const Duration(seconds: 60, milliseconds: 1)),
        ),
        isFalse,
      );
    });
  });

  group('P08 last-known persistence', () {
    test('stores only systemId and times, never tokens or station', () {
      final record = service.rememberLastKnown(
        CharacterLocationObserved(
          systemId: kAlphaSystemId,
          observedAt: kExplorationT0,
          stationId: 60003760,
          structureId: 99,
        ),
        accessToken: 'access-secret',
        refreshToken: 'refresh-secret',
      );
      final json = record.toPersistedJson();
      expect(
        json.keys,
        unorderedEquals(['systemId', 'observedAt', 'fetchedAt']),
      );
      expect(json['systemId'], kAlphaSystemId);
      expect(json.containsKey('accessToken'), isFalse);
      expect(json.containsKey('refreshToken'), isFalse);
      expect(json.containsKey('stationId'), isFalse);
      expect(json.containsKey('structureId'), isFalse);
    });
  });

  group('P08 manual origin survival', () {
    test('manual origin survives location refresh', () {
      controller.setManual(kAlphaSystemId);
      controller.applyLocation(
        CharacterLocationObserved(
          systemId: kTheraSystemId,
          observedAt: kExplorationT0,
        ),
        characterId: kCharacter7,
      );
      expect(controller.origin, isA<ManualOrigin>());
      expect((controller.origin as ManualOrigin).systemId, kAlphaSystemId);
    });

    test('manual origin survives character switch', () {
      controller.setManual(kAlphaSystemId);
      controller.switchCharacter(kCharacter8);
      expect(controller.origin, isA<ManualOrigin>());
      expect((controller.origin as ManualOrigin).systemId, kAlphaSystemId);
    });

    test('location failure does not auto-select last known', () {
      controller.applyLocation(
        CharacterLocationObserved(
          systemId: kAlphaSystemId,
          observedAt: kExplorationT0,
        ),
        characterId: kCharacter7,
      );
      controller.origin = const UnselectedOrigin();
      controller.applyLocation(
        const CharacterLocationFailed(CharacterLocationFailureKind.auth),
        characterId: kCharacter7,
      );
      expect(controller.origin, isNot(isA<LastKnownCharacterOrigin>()));
      expect(controller.origin, isA<UnselectedOrigin>());
    });
  });

  group('P09 in-flight location generation', () {
    test('character switch rejects a late location result', () async {
      final hold = Completer<CharacterLocationResult>();
      service = ExplorationOriginService(
        clock: () => clock,
        strictLocation: (_) => hold.future,
      );
      controller = ExplorationOriginController(service: service);
      final pending = controller.fetchCurrent(kCharacter7);
      controller.switchCharacter(kCharacter8);
      hold.complete(
        CharacterLocationObserved(
          systemId: kAlphaSystemId,
          observedAt: kExplorationT0,
        ),
      );
      await pending;
      expect(controller.published, isNull);
      expect(controller.origin, isNot(isA<CurrentCharacterOrigin>()));
    });
  });
}

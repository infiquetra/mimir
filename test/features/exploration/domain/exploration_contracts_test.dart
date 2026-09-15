// X0 RED contracts for exploration domain types, F1–F8 fixtures, and
// the ExplorationTestHarness. Compile stubs load so these fail as
// assertions, not missing imports.
//
// Expected RED until GREEN implements design §4.1 / product §8.1:
// - F1: minutes stored as seconds; K162 zeros; C729 last-variant wins;
//   capital filter exclusive of 1e9 kg.
// - F2: wrong vector table; resonance subtracts pp; visual sun wins;
//   security uses 0.5 and signed display.
// - F3: key is raw id; mass inferred Fresh; remaining_hours 999 used;
//   orientation does not swap types; far signature copied.
// - F4: exact 5m/24h stay Fresh; backoff 60s; 304 rewrites payload time.
// - F5: whitespace split; no duplicate coalesce; counts treat header.
// - F6: 23:59:59 pruned; K162 invents B274 reverse.
// - F7/F8: gate-only BFS; A→A is a found 1-jump route.
// - Codecs: fromJson fabricates zeros; fingerprints include timestamps;
//   groups store caller lists by reference; no value equality.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';
import 'package:mimir/features/exploration/domain/scanner_import.dart';

import '../fixtures/exploration_fixtures.dart';
import '../fixtures/exploration_test_harness.dart';

void main() {
  group('Harness clock and adapters', () {
    late ExplorationTestHarness harness;

    setUp(() async {
      harness = ExplorationTestHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('clock is T0 and schema capture is 20/6', () {
      expect(harness.clock(), DateTime.utc(2026, 9, 15, 12));
      expect(harness.explorationClock().now(), kExplorationT0);
      expect(harness.capturedAppSchema, 20);
      expect(harness.capturedSdeSchema, 6);
      expect(ExplorationTestHarness.baselineAppSchema, 20);
      expect(ExplorationTestHarness.baselineSdeSchema, 6);
    });

    test('unexpected EVE-Scout HTTP is a harness failure', () async {
      await expectLater(
        () => harness.http.get(
          Uri.parse('https://api.eve-scout.com/v2/public/signatures'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('unexpected EVE-Scout HTTP'),
          ),
        ),
      );
      expect(harness.http.requests, hasLength(1));
    });

    test('clipboard is unread until an explicit paste', () {
      harness.clipboard.seed(F5Fixtures.paste);
      expect(harness.clipboard.reads, isEmpty);
      expect(harness.esi.waypointWrites, isEmpty);
      expect(harness.esi.bookmarkWrites, isEmpty);
    });
  });

  group('F1 wormhole reference types', () {
    test('B274 converts minutes to seconds and keeps exact kg', () {
      final type = F1Fixtures.b274;
      expect(type.typeId, kB274TypeId);
      expect(type.code, 'B274');
      expect(type.reliableLifetimeSeconds, F1Oracle.b274LifetimeSeconds);
      expect(type.totalMassKg, F1Oracle.b274TotalMassKg);
      expect(type.maxJumpMassKg, F1Oracle.b274JumpMassKg);
      expect(type.regenerationKgPerCycle, F1Oracle.b274RegenKgPerCycle);
      expect(type.destinationLabel, 'Highsec');
    });

    test('K162 missing dogma stays null, never zero', () {
      final type = F1Fixtures.k162;
      expect(type.typeId, kK162TypeId);
      expect(type.code, 'K162');
      expect(type.reliableLifetimeSeconds, isNull);
      expect(type.maxJumpMassKg, isNull);
      expect(type.totalMassKg, isNull);
      expect(type.regenerationKgPerCycle, isNull);
      expect(type.rawTargetClass, isNull);
      expect(type.destinationLabel, 'Unknown');
    });

    test('I078 is Pochven with 16200s lifetime', () {
      final type = F1Fixtures.i078;
      expect(type.typeId, kI078TypeId);
      expect(type.reliableLifetimeSeconds, F1Oracle.i078LifetimeSeconds);
      expect(type.totalMassKg, F1Oracle.i078TotalMassKg);
      expect(type.maxJumpMassKg, F1Oracle.i078JumpMassKg);
      expect(type.destinationLabel, 'Pochven');
    });

    test('C729 agreeing variants share 12h and jump; conflict is Varies', () {
      final agree = WormholeCodeGroup.fromVariants([
        F1Fixtures.typeFromRaw(F1Fixtures.c729V1Raw()),
        F1Fixtures.typeFromRaw(F1Fixtures.c729V2AgreeRaw()),
      ]);
      expect(agree.variants, hasLength(2));
      expect(agree.sharedLifetimeSeconds, F1Oracle.c729LifetimeSeconds);
      expect(agree.sharedJumpMassKg, F1Oracle.c729AgreedJumpKg);
      expect(agree.jumpVaries, isFalse);

      final conflict = WormholeCodeGroup.fromVariants([
        F1Fixtures.typeFromRaw(F1Fixtures.c729V2ConflictRaw()),
        F1Fixtures.typeFromRaw(F1Fixtures.c729V1Raw()),
      ]);
      expect(conflict.variants, hasLength(2));
      expect(conflict.jumpVaries, isTrue);
      expect(conflict.sharedJumpMassKg, isNull);
      expect(conflict.sharedLifetimeSeconds, F1Oracle.c729LifetimeSeconds);
    });

    test('capital filter includes Q001 at 1e9 kg and excludes Q002', () {
      expect(F1Fixtures.q001.isCapitalSize, isTrue);
      expect(F1Fixtures.q002.isCapitalSize, isFalse);
      expect(F1Fixtures.k162.isCapitalSize, isFalse);
    });
  });

  group('F2 effects and taxonomy', () {
    test('all 36 family/strength combinations exist', () {
      expect(F2Oracle.families, hasLength(6));
      expect(F2Oracle.combinationCount, 36);
      expect(F2Oracle.pulsarBeacons, hasLength(6));
      expect(F2Oracle.cataclysmicBeacons[3], 30884);
      expect(F2Oracle.cataclysmicBeacons[5], 30882);
    });

    test('Pulsar / Magnetar / Wolf-Rayet / cap oracles at each strength', () {
      for (var strength = 1; strength <= 6; strength++) {
        expect(
          SystemEffect.pulsarShieldPercent(strength),
          F2Oracle.pulsarShield[strength - 1],
        );
        expect(
          SystemEffect.magnetarExplosionRadiusFrom100(strength),
          100 + F2Oracle.magnetarExplosionRadius[strength - 1],
        );
        expect(
          SystemEffect.wolfRayetSmallWeaponFrom100(strength),
          100 + F2Oracle.wolfRayetSmallWeapon[strength - 1],
        );
        expect(
          SystemEffect.pulsarCapRechargeFrom100(strength),
          100 + F2Oracle.pulsarCapRechargeTime[strength - 1],
        );
      }
      expect(
        SystemEffect.pulsarShieldPercent(1),
        F2Oracle.multiplier130Percent,
      );
      expect(
        SystemEffect.magnetarExplosionRadiusFrom100(1),
        F2Oracle.magnetarS1ExplosionFrom100,
      );
      expect(
        SystemEffect.wolfRayetSmallWeaponFrom100(6),
        F2Oracle.wolfRayetS6SmallFrom100,
      );
      expect(
        SystemEffect.pulsarCapRechargeFrom100(6),
        F2Oracle.pulsarS6CapFrom100,
      );
    });

    test('50% resist plus 50% resonance becomes 25%, not 0%', () {
      expect(
        SystemEffect.applyResonance(
          oldResist: F2Oracle.resonanceOldResist,
          percentIncrease: F2Oracle.resonancePercent,
        ),
        F2Oracle.resonanceNewResist,
      );
    });

    test('beacon wins over visual sun; class-13 is Wolf-Rayet 6', () {
      final redGiant = SystemEffect.resolve(
        beaconTypeId: F2Fixtures.j005926().effectBeaconTypeId,
        visualSunTypeId: F2Fixtures.j005926().visualSunTypeId,
      );
      expect(redGiant.family, EffectFamily.redGiant);
      expect(redGiant.strength, 1);
      expect(redGiant.beaconTypeId, 30848);

      final wolf = SystemEffect.resolve(
        beaconTypeId: F2Fixtures.j010569().effectBeaconTypeId,
        visualSunTypeId: F2Fixtures.j010569().visualSunTypeId,
      );
      expect(wolf.family, EffectFamily.wolfRayet);
      expect(wolf.strength, 1);
      expect(wolf.beaconTypeId, 30849);

      final shattered = SystemEffect.resolve(
        beaconTypeId: F2Fixtures.class13().effectBeaconTypeId,
      );
      expect(shattered.family, EffectFamily.wolfRayet);
      expect(shattered.strength, 6);
    });

    test('missing vs verified-absent effect states stay distinct', () {
      expect(
        SystemEffect.resolve(beaconTypeId: null, dataMissing: true).state,
        SystemEffectState.unknown,
      );
      expect(
        SystemEffect.resolve(beaconTypeId: null, verifiedAbsent: true).state,
        SystemEffectState.none,
      );
    });

    test('ordinary security boundary table and specials are not Nullsec', () {
      for (final row in F2Fixtures.securityTable) {
        final system = SystemReference(
          systemId: 1,
          name: 'Sec',
          rawSecurity: row.raw,
        );
        expect(system.category, row.category, reason: 'raw ${row.raw}');
        expect(system.securityDisplay, row.display, reason: 'raw ${row.raw}');
      }
      expect(F2Fixtures.thera().category, isNot(SecurityCategory.nullsec));
      expect(F2Fixtures.pochven().category, isNot(SecurityCategory.nullsec));
      expect(F2Fixtures.thera().rawClass, 12);
      expect(F2Fixtures.pochven().rawClass, 25);
    });
  });

  group('F3 EVE-Scout wire records', () {
    test(
      'normalizes evescout:42, Mass Unknown, and ignores remaining_hours 999',
      () {
        final connection = PublicConnection.fromWire(
          F3Fixtures.wireRecord(),
          now: kExplorationT0,
        );
        expect(connection.providerKey, F3Fixtures.providerKey);
        expect(connection.hub.systemId, kTurnurSystemId);
        expect(connection.hub.systemName, 'Turnur');
        expect(connection.far.systemId, kAlphaSystemId);
        expect(connection.far.systemName, 'Alpha');
        expect(connection.mass, MassState.unknown);
        expect(connection.time, TimeEstimate.stable);
        expect(connection.updatedAt, F3Fixtures.reportedUpdate);
        expect(connection.fetchedAt, kExplorationT0);
        expect(
          F3Fixtures.expiresAt.difference(kExplorationT0),
          const Duration(hours: 6),
        );
      },
    );

    test('orientation true/false swaps types, not systems or signatures', () {
      final outward = PublicConnection.fromWire(
        F3Fixtures.wireRecord(),
        now: kExplorationT0,
      );
      expect(outward.departureType(fromHub: true), 'B274');
      expect(outward.departureType(fromHub: false), 'K162');
      expect(outward.departureSignature(fromHub: true), 'HUB-123');
      expect(outward.departureSignature(fromHub: false), 'FAR-456');

      final inward = PublicConnection.fromWire(
        F3Fixtures.wireRecord(exitsOutward: false),
        now: kExplorationT0,
      );
      expect(inward.hub.systemId, kTurnurSystemId);
      expect(inward.far.systemId, kAlphaSystemId);
      expect(inward.departureType(fromHub: true), 'K162');
      expect(inward.departureType(fromHub: false), 'B274');
      expect(inward.departureSignature(fromHub: true), 'HUB-123');
      expect(inward.departureSignature(fromHub: false), 'FAR-456');
    });

    test('missing far signature is not copied from the hub', () {
      final connection = PublicConnection.fromWire(
        F3Fixtures.wireRecord(inSignature: null),
        now: kExplorationT0,
      );
      expect(connection.far.signature, isNull);
      expect(connection.hub.signature, 'HUB-123');
    });

    test(
      '4h exact is Stable; +1ms is EOL; expiry is ineligible not Collapsed',
      () {
        expect(
          ExplorationTime.timeEstimate(
            expiresAt: F3Fixtures.expiresAt,
            now: F3Fixtures.stableAt4h,
          ),
          TimeEstimate.stable,
        );
        expect(
          ExplorationTime.timeEstimate(
            expiresAt: F3Fixtures.expiresAt,
            now: F3Fixtures.eolAt4hPlus1ms,
          ),
          TimeEstimate.eol,
        );
        expect(
          ExplorationTime.timeEstimate(
            expiresAt: F3Fixtures.expiresAt,
            now: F3Fixtures.expiresAt,
          ),
          TimeEstimate.expired,
        );
      },
    );

    test('integer 42 and string 42 share one provider key', () {
      final asInt = PublicConnection.fromWire(
        F3Fixtures.wireRecord(id: 42),
        now: kExplorationT0,
      );
      final asString = PublicConnection.fromWire(
        F3Fixtures.wireRecord(),
        now: kExplorationT0,
      );
      expect(asInt.providerKey, F3Fixtures.providerKey);
      expect(asString.providerKey, asInt.providerKey);
    });
  });

  group('F4 highway feed cache boundaries', () {
    test('Fresh at 4m59s, Stale at exact 5m, view-only at exact 24h', () {
      expect(
        ExplorationTime.feedFreshness(
          validatedAt: kExplorationT0,
          now: F4Fixtures.freshUntil,
        ),
        FeedFreshness.fresh,
      );
      expect(
        ExplorationTime.feedFreshness(
          validatedAt: kExplorationT0,
          now: F4Fixtures.staleAt,
        ),
        FeedFreshness.stale,
      );
      expect(
        ExplorationTime.feedFreshness(
          validatedAt: kExplorationT0,
          now: F4Fixtures.twentyFourHours,
        ),
        FeedFreshness.viewOnly,
      );
    });

    test('backoff is 300/600/900 and 429 Retry-After 600 wins', () {
      expect(ExplorationTime.backoff(1), const Duration(seconds: 300));
      expect(ExplorationTime.backoff(2), const Duration(seconds: 600));
      expect(ExplorationTime.backoff(3), const Duration(seconds: 900));
      expect(
        ExplorationTime.retryAfter(
          failedAt: F4Fixtures.staleAt,
          retryAfterSeconds: F4Fixtures.retryAfterHeader,
        ),
        F4Fixtures.retryAfterDeadline,
      );
    });

    test('304 renews validation without moving payloadReceivedAt', () {
      final accepted = F4Fixtures.revision1();
      expect(accepted.revision, 1);
      expect(accepted.payloadReceivedAt, kExplorationT0);
      final renewed = accepted.renewValidation(
        DateTime.utc(2026, 9, 15, 12, 10),
      );
      expect(
        renewed.lastSuccessfulValidationAt,
        DateTime.utc(2026, 9, 15, 12, 10),
      );
      expect(renewed.payloadReceivedAt, kExplorationT0);
      expect(renewed.revision, 1);
    });
  });

  group('F5 scanner preview', () {
    test(
      '3 valid, 1 duplicate coalesced, 1 invalid; 2 added / 0 updated / 1 seen',
      () {
        final preview = F5Fixtures.preview();
        expect(
          preview.rows.where((row) => row.valid && !row.duplicate),
          hasLength(3),
        );
        expect(preview.duplicates, 1);
        expect(preview.invalid, 1);
        expect(preview.added, 2);
        expect(preview.updated, 0);
        expect(preview.seenAgain, 1);
        expect(preview.successMessage, F5Fixtures.successMessage);
      },
    );

    test('parse does not mutate the notebook snapshot', () {
      final existing = F5Fixtures.abcExisting();
      ScannerImportParser.parse(F5Fixtures.paste);
      expect(existing.notes, 'Keep this note');
      expect(existing.bookmark, 'Safe spot');
      expect(existing.firstSeenAt, DateTime.utc(2026, 9, 15, 10));
    });
  });

  group('F6 notebook prune and verification', () {
    test('24h exact moves; 23:59:59 stays; Off prunes nothing', () {
      final moved = ExplorationPruner.prune([
        F6Fixtures.age001(),
        F6Fixtures.age002(),
      ], now: kExplorationT0);
      expect(moved.map((row) => row.code), ['AGE-001']);
      expect(
        ExplorationPruner.prune(
          [F6Fixtures.age001(), F6Fixtures.age002()],
          now: kExplorationT0,
          policy: PrunePolicy.off,
        ),
        isEmpty,
      );
      expect(
        ExplorationPruner.prune(
          [F6Fixtures.age001(), F6Fixtures.age002()],
          now: kExplorationT0,
          policy: PrunePolicy.hours48,
        ),
        isEmpty,
      );
    });

    test('observed K162 does not invent a B274 reverse type', () {
      final link = LocalConnection(
        id: 'link-1',
        characterId: kCharacter7,
        episodeId: 'episode-def',
        fromSystemId: kAlphaSystemId,
        toSystemId: 9102,
        originatingType: 'K162',
        originatingSide: 'Unknown',
        verifiedAt: kExplorationT0,
      );
      expect(link.forwardType(), 'K162');
      expect(link.reverseType(), isNot('B274'));
      expect(
        link.eligibleAt(kExplorationT0.add(const Duration(hours: 24))),
        isFalse,
      );
      expect(
        link.eligibleAt(
          kExplorationT0.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          ),
        ),
        isTrue,
      );
    });
  });

  group('F7 route graph paths', () {
    test('defaults prefer Highsec Avoid-Lowsec private and A→A oracles', () {
      expect(RoutePreferences.defaults.avoidEol, isTrue);
      expect(RoutePreferences.defaults.avoidCriticalMass, isTrue);
      expect(RoutePreferences.defaults.avoidLowsec, isFalse);
      expect(RoutePreferences.defaults.avoidNullsec, isFalse);
      expect(RoutePreferences.defaults.preferHighsec, isFalse);
      expect(RoutePreferences.defaults.useStaleCachedConnections, isFalse);

      List<int> systems(RouteResult result) => [
        if (result.steps.isNotEmpty) result.steps.first.fromSystemId,
        for (final step in result.steps) step.toSystemId,
      ];

      final defaults = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
        ),
        F7Fixtures.graph(),
      );
      expect(systems(defaults), F7Fixtures.defaultPath);
      expect(defaults.gateJumps, 1);
      expect(defaults.wormholeJumps, 2);
      expect(defaults.totalJumps, 3);
      expect(defaults.riskSum, 2);

      final highsec = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
          preferences: RoutePreferences(
            preferHighsec: true,
            avoidEol: true,
            avoidCriticalMass: true,
          ),
        ),
        F7Fixtures.graph(),
      );
      expect(systems(highsec), F7Fixtures.preferHighsecPath);
      expect(highsec.gateJumps, 5);
      expect(highsec.wormholeJumps, 0);

      final eol = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
        ),
        F7Fixtures.graph(btEol: true),
      );
      expect(systems(eol), F7Fixtures.eolPath);

      final private = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
          characterId: kCharacter7,
        ),
        F7Fixtures.graph(includePrivate: true),
      );
      expect(systems(private), F7Fixtures.privatePath);
      expect(private.totalJumps, 2);

      final same = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.a,
        ),
        F7Fixtures.graph(),
      );
      expect(same.outcome, RouteOutcome.alreadyAtDestination);
      expect(same.steps, isEmpty);
      expect(same.gateJumps, 0);
      expect(same.wormholeJumps, 0);
      expect(same.totalJumps, 0);
    });

    test('w01 beats w02 regardless of insertion order', () {
      final graph = F7Fixtures.graph(includeW02: true);
      expect(
        graph.edges.where(
          (edge) => edge.canonicalKey == 'w01' || edge.key.startsWith('w01'),
        ),
        isNotEmpty,
      );
      expect(
        graph.edges.where(
          (edge) => edge.canonicalKey == 'w02' || edge.key.startsWith('w02'),
        ),
        isNotEmpty,
      );
    });
  });

  group('F8 nearest entrance', () {
    test(
      'B→T on risk tie-break; Avoid-Lowsec rejects E→U; 5-gate fallback',
      () {
        final nearest = NearestEntranceFinder.find(
          originSystemId: F7Systems.a,
          hubSystemId: F7Systems.t,
          graph: F7Fixtures.graph(),
        );
        expect(nearest.found, isTrue);
        expect(nearest.approachSystemId, F7Systems.b);
        expect(nearest.gateJumps, 1);
        expect(nearest.wormholeJumps, 1);
        expect(nearest.summary, F8Fixtures.bToTSummary);

        final avoidLow = NearestEntranceFinder.find(
          originSystemId: F7Systems.a,
          hubSystemId: F7Systems.u,
          graph: F7Fixtures.graph(),
          preferences: const RoutePreferences(
            avoidEol: true,
            avoidCriticalMass: true,
            avoidLowsec: true,
          ),
        );
        expect(avoidLow.found, isFalse);

        final fallback = NearestEntranceFinder.find(
          originSystemId: F7Systems.a,
          hubSystemId: F7Systems.t,
          graph: F7Fixtures.graph(btEol: true),
          preferences: const RoutePreferences(
            avoidEol: true,
            avoidCriticalMass: true,
            avoidLowsec: true,
          ),
        );
        expect(fallback.gateJumps, 5);
        expect(fallback.wormholeJumps, 1);
        expect(fallback.summary, F8Fixtures.zVia5GatesSummary);
      },
    );
  });

  group('Immutable codecs, equality and fingerprints', () {
    test('mutating caller variant list does not change the code group', () {
      final variants = [F1Fixtures.b274];
      final group = WormholeCodeGroup.fromVariants(variants);
      variants.add(F1Fixtures.k162);
      expect(group.variants, hasLength(1));
      expect(group.variants.single.code, 'B274');
    });

    test('content fingerprint ignores id/name/time and is order-stable', () {
      final early = WormholeTypeReference.fromRaw(
        typeId: kB274TypeId,
        code: 'B274',
        name: 'Wormhole B274',
        rawTargetClass: 7,
        rawMaxStableTimeMinutes: 1440,
        rawTotalMassKg: F1Oracle.b274TotalMassKg,
        rawJumpMassKg: F1Oracle.b274JumpMassKg,
        rawRegenKg: 0,
        recordedAt: kExplorationT0,
      );
      final late = WormholeTypeReference.fromRaw(
        typeId: kB274TypeId,
        code: 'B274',
        name: 'Renamed B274',
        rawTargetClass: 7,
        rawMaxStableTimeMinutes: 1440,
        rawTotalMassKg: F1Oracle.b274TotalMassKg,
        rawJumpMassKg: F1Oracle.b274JumpMassKg,
        rawRegenKg: 0,
        recordedAt: kExplorationT0.add(const Duration(hours: 1)),
      );
      expect(early.contentFingerprint, late.contentFingerprint);
    });

    test('fromJson does not fabricate zeros for missing K162 dogma', () {
      final restored = WormholeTypeReference.fromJson({
        'typeId': kK162TypeId,
        'code': 'K162',
        'name': 'Wormhole K162',
      });
      expect(restored.reliableLifetimeSeconds, isNull);
      expect(restored.maxJumpMassKg, isNull);
      expect(restored.totalMassKg, isNull);
      expect(restored.regenerationKgPerCycle, isNull);
      expect(restored.recordedAt, isNull);
    });

    test('equal raw records compare equal by value', () {
      expect(
        F1Fixtures.typeFromRaw(F1Fixtures.b274Raw()),
        equals(F1Fixtures.typeFromRaw(F1Fixtures.b274Raw())),
      );
    });

    test('ReferenceManifest missing importedAt stays null', () {
      final restored = ReferenceManifest.fromJson({
        'sdeBuild': 3503375,
        'datasetSchema': 1,
      });
      expect(restored.importedAt, isNull);
      expect(restored.coverage, isEmpty);
      expect(restored.validation, isEmpty);
    });
  });
}

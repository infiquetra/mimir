import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocator.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

import '../fixtures/attacker_matchup_fixtures.dart';

void main() {
  group('Incoming damage allocation D01–D02 D10–D13', () {
    test('D01 solo Confirmed source equals aggregate vector', () {
      final s1 = s1Solo();
      final allocation = _ready(s1.encounter);
      expect(allocation.sources, hasLength(1));
      final source = allocation.sources.single;
      expect(source.loggedDamage, 4000);
      expect(source.components, allocation.components);
      expect(source.components.total, DamageQuantity.fromInt(4000));
      expect(allocation.accountsForAllDamage, isTrue);
      expect(allocation.totalIncomingDamage, s1.encounter.totalDamageReceived);
      expect(allocation.sources.single.rawActorName, 'Artem S3');
    });

    test(
      'D02 Fixture A exact vectors and 60/40 shares ignore excluded events',
      () {
        final clean = _ready(s2Fleet().encounter);
        final noisy = _ready(s2Fleet(withExcludedEvents: true).encounter);
        _expectFixtureAVectors(clean);
        _expectFixtureAVectors(noisy);
        expect(clean.components.toJson(), noisy.components.toJson());
        expect(clean.totalIncomingDamage, 10000);
        expect(noisy.totalIncomingDamage, 10000);
        expect(clean.accountsForAllDamage, isTrue);
      },
    );

    test('D10 Fixture D weights by logged amount not hit count', () {
      final compact = _ready(s5MixedWeapons().encounter);
      final rearranged = _ready(s5MixedWeapons(rearrangeHits: true).encounter);
      expect(compact.components, rearranged.components);
      expect(
        compact.components[IncomingDamageType.em],
        DamageQuantity.fromInt(600),
      );
      expect(
        compact.components[IncomingDamageType.thermal],
        DamageQuantity.fromInt(400),
      );
      final withDrone = _ready(s5MixedWeapons(extraDroneActor: true).encounter);
      expect(
        withDrone.sources.map((s) => s.rawActorName),
        contains('Hobgoblin II'),
      );
      final artem = withDrone.sources.singleWhere(
        (s) => s.rawActorName == 'Artem S3',
      );
      expect(
        artem.components[IncomingDamageType.em],
        DamageQuantity.fromInt(600),
      );
      expect(
        artem.components[IncomingDamageType.thermal],
        DamageQuantity.fromInt(400),
      );
    });

    test('D11 partial coverage keeps untyped in the source total', () {
      final allocation = _ready(
        matchupEncounter([
          ('Alpha', 300, pureEmName, 4),
          ('Alpha', 100, 'Missing Weapon', 8),
        ]),
        extraWeapons: {
          normalizeCombatName('Missing Weapon'): unresolvedWeapon(
            'Missing Weapon',
            status: WeaponResolutionStatus.missingName,
          ),
        },
      );
      final source = allocation.sources.single;
      expect(source.loggedDamage, 400);
      expect(source.resolvedDamage, 300);
      expect(source.untypedDamage, 100);
      expect(
        source.components[IncomingDamageType.em],
        DamageQuantity.fromInt(300),
      );
      expect(source.components.total, DamageQuantity.fromInt(300));
    });

    test('D12 unknown weapons stay fully untyped with no pattern', () {
      final allocation = _ready(
        matchupEncounter([('Zed', 500, 'No Such Launcher', 4)]),
        extraWeapons: {
          normalizeCombatName('No Such Launcher'): unresolvedWeapon(
            'No Such Launcher',
            status: WeaponResolutionStatus.noExactType,
            reasonCode: 'noExactType',
          ),
        },
      );
      final source = allocation.sources.single;
      expect(source.resolvedDamage, 0);
      expect(source.untypedDamage, 500);
      expect(source.components.total, DamageQuantity.fromInt(0));
      expect(source.components.toPattern(), isNull);
      expect(
        source.weapons.single.resolution.status,
        WeaponResolutionStatus.noExactType,
      );
    });

    test('D13 Fixture C quarters and thirds conserve exactly', () {
      final c = _ready(fixtureC().encounter);
      final one = c.sources.singleWhere((s) => s.rawActorName == 'Omni One');
      final three = c.sources.singleWhere(
        (s) => s.rawActorName == 'Omni Three',
      );
      expect(
        one.components[IncomingDamageType.em],
        DamageQuantity(BigInt.one, BigInt.from(4)),
      );
      expect(
        three.components[IncomingDamageType.em],
        DamageQuantity(BigInt.from(3), BigInt.from(4)),
      );
      expect(c.components[IncomingDamageType.em], DamageQuantity.fromInt(1));
      expect(
        c.components[IncomingDamageType.thermal],
        DamageQuantity.fromInt(1),
      );
      expect(
        c.components[IncomingDamageType.kinetic],
        DamageQuantity.fromInt(1),
      );
      expect(
        c.components[IncomingDamageType.explosive],
        DamageQuantity.fromInt(1),
      );
      expect(one.components + three.components, c.components);

      final thirds = _ready(
        matchupEncounter([
          ('A', 1, thirdsMixName, 4),
          ('B', 1, thirdsMixName, 8),
          ('C', 1, thirdsMixName, 12),
        ]),
      );
      expect(
        thirds.components[IncomingDamageType.em],
        DamageQuantity.fromInt(1),
      );
      expect(thirds.accountsForAllDamage, isTrue);
      final json = thirds.components.toJson();
      expect(IncomingDamageVector.fromJson(json), thirds.components);
      final projected = one.components.projectLegacyInts();
      expect(projected.values.reduce((a, b) => a + b), one.resolvedDamage);
      expect(one.components.toPattern()!.em, closeTo(0.25, 1e-9));
    });
  });

  group('DamageQuantity and allocation invariants', () {
    test('rejects zero and negative denominators and invalid JSON', () {
      expect(() => DamageQuantity(BigInt.one, BigInt.zero), throwsA(anything));
      expect(
        () => DamageQuantity(BigInt.one, BigInt.from(-1)),
        throwsA(anything),
      );
      expect(
        () => DamageQuantity.fromJson(const {'n': '1', 'd': '0'}),
        throwsA(anything),
      );
      expect(DamageQuantity.fromSdeNumber(0), DamageQuantity.fromInt(0));
    });

    test('1e-7 scientific notation remains exact', () {
      expect(
        DamageQuantity.fromSdeNumber(1e-7),
        DamageQuantity(BigInt.one, BigInt.from(10000000)),
      );
    });

    test('integer overflow is rejected rather than wrapped', () {
      final encounter = matchupEncounter([('Overflow', 1, omniBeamName, 4)]);
      final huge = encounter.copyWith(
        events: [
          CombatEvent(
            id: 'e1',
            timestamp: encounter.startTime,
            second: 4,
            direction: CombatEventDirection.incoming,
            kind: CombatEventKind.damage,
            amount: 9007199254740992,
            targetName: 'Overflow',
            weaponName: omniBeamName,
            rawLine: 'overflow',
          ),
        ],
        aggregates: CombatAggregates(
          totalDamageDealt: 0,
          totalDamageReceived: 9007199254740992,
          cumulativeDamage: const [],
          damageByTarget: const {},
          damageByWeapon: const {omniBeamName: 9007199254740992},
          incomingBySource: const {'Overflow': 9007199254740992},
          hitQualityCounts: const {},
          outgoingHitQualityCounts: const {},
          incomingHitQualityCounts: const {},
          outgoingHitCount: 0,
          incomingHitCount: 1,
          peakOutgoingHit: 0,
          peakIncomingHit: 9007199254740992,
          averageOutgoingHit: 0,
          averageIncomingHit: 9007199254740992,
          missCount: 0,
          idleGapCount: 0,
          ewarEventCount: 0,
        ),
      );
      final result = IncomingDamageAllocator.allocate(
        encounter: huge,
        weapons: matchupWeaponTable(),
        sdeContentKey: matchupSdeContentKey,
      );
      expect(result, isA<IncomingAllocationInvalid>());
      expect(
        (result as IncomingAllocationInvalid).reasonCode,
        'integerOverflow',
      );
    });

    test('toFiniteDouble never yields Infinity for large rationals', () {
      final huge = DamageQuantity(BigInt.parse('1${'0' * 400}'), BigInt.one);
      expect(huge.toFiniteDouble().isFinite, isTrue);
    });

    test('collections are unmodifiable and keys ignore wall clock', () {
      final first = _ready(s2Fleet().encounter);
      final second = _ready(s2Fleet().encounter);
      expect(first.allocationKey, second.allocationKey);
      expect(
        () => first.sources.add(first.sources.first),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () =>
            first.sources.first.weapons.add(first.sources.first.weapons.first),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

IncomingDamageAllocation _ready(
  ParsedCombatEncounter encounter, {
  Map<String, IncomingWeaponResolution> extraWeapons = const {},
}) {
  final result = IncomingDamageAllocator.allocate(
    encounter: encounter,
    weapons: matchupWeaponTable(extraWeapons),
    sdeContentKey: matchupSdeContentKey,
  );
  expect(result, isA<IncomingAllocationReady>(), reason: '$result');
  return (result as IncomingAllocationReady).allocation;
}

void _expectFixtureAVectors(IncomingDamageAllocation allocation) {
  final kite = allocation.sources.singleWhere(
    (s) => s.rawActorName == 'Kite Mondeo',
  );
  final artem = allocation.sources.singleWhere(
    (s) => s.rawActorName == 'Artem S3',
  );
  expect(kite.loggedDamage, 6000);
  expect(artem.loggedDamage, 4000);
  expect(kite.components[IncomingDamageType.em], DamageQuantity.fromInt(4500));
  expect(
    kite.components[IncomingDamageType.thermal],
    DamageQuantity.fromInt(0),
  );
  expect(
    kite.components[IncomingDamageType.kinetic],
    DamageQuantity.fromInt(1500),
  );
  expect(
    kite.components[IncomingDamageType.explosive],
    DamageQuantity.fromInt(0),
  );
  expect(artem.components[IncomingDamageType.em], DamageQuantity.fromInt(0));
  expect(
    artem.components[IncomingDamageType.kinetic],
    DamageQuantity.fromInt(1000),
  );
  expect(
    artem.components[IncomingDamageType.explosive],
    DamageQuantity.fromInt(3000),
  );
  expect(
    allocation.components[IncomingDamageType.em],
    DamageQuantity.fromInt(4500),
  );
  expect(
    allocation.components[IncomingDamageType.kinetic],
    DamageQuantity.fromInt(2500),
  );
  expect(
    allocation.components[IncomingDamageType.explosive],
    DamageQuantity.fromInt(3000),
  );
  expect(kite.loggedDamage / allocation.totalIncomingDamage, 0.6);
  expect(artem.loggedDamage / allocation.totalIncomingDamage, 0.4);
  expect(kite.components + artem.components, allocation.components);
}

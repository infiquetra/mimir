// X1 RED contracts for the offline reference catalog (D01–D07).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §2.1 / §4.2:
// - D01: project() skips unpublished K162 and stores minutes as seconds.
// - D02: groupByCode keeps one type ID per code.
// - D03: untrimmed search, exclusive capital filter, cross-variant AND.
// - D04: incomplete 36-set and 10%×strength vectors without Vorton scopes.
// - D05: visual sun wins; class inheritance is region-first.
// - D06: missing statics become typical C2 assignments and route edges.
// - D07: wormhole class 7/12/25 far-sides collapse to Nullsec.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/domain/exploration_reference_deriver.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  final deriver = const ReferenceDeriver();
  final catalog = EffectCatalog();

  RawWormholeRecord rawFromF1(
    Map<String, dynamic> raw, {
    bool published = true,
  }) {
    return RawWormholeRecord(
      typeId: raw['typeId'] as int,
      code: raw['code'] as String,
      name: raw['name'] as String,
      published: published,
      rawTargetClass: raw['rawTargetClass'] as int?,
      rawTargetDistribution: raw['rawTargetDistribution'] as int?,
      rawMaxStableTimeMinutes: raw['rawMaxStableTimeMinutes'] as int?,
      rawTotalMassKg: (raw['rawTotalMassKg'] as num?)?.toDouble(),
      rawJumpMassKg: (raw['rawJumpMassKg'] as num?)?.toDouble(),
      rawRegenKg: (raw['rawRegenKg'] as num?)?.toDouble(),
    );
  }

  List<WormholeTypeReference> f1Catalog() {
    return deriver.projectCatalog([
      rawFromF1(F1Fixtures.b274Raw()),
      rawFromF1(F1Fixtures.k162Raw(), published: false),
      rawFromF1(F1Fixtures.i078Raw()),
      rawFromF1(F1Fixtures.c729V1Raw()),
      rawFromF1(F1Fixtures.c729V2ConflictRaw()),
      rawFromF1(F1Fixtures.q001Raw()),
      rawFromF1(F1Fixtures.q002Raw()),
    ]);
  }

  group('D01 F1 units and K162 unknowns', () {
    test('B274, I078, K162, Q001/Q002 project exact units and boundaries', () {
      final b274 = deriver.project(rawFromF1(F1Fixtures.b274Raw()));
      expect(b274, isNotNull);
      expect(b274!.typeId, kB274TypeId);
      expect(b274.code, 'B274');
      expect(b274.reliableLifetimeSeconds, F1Oracle.b274LifetimeSeconds);
      expect(b274.totalMassKg, F1Oracle.b274TotalMassKg);
      expect(b274.maxJumpMassKg, F1Oracle.b274JumpMassKg);
      expect(b274.regenerationKgPerCycle, F1Oracle.b274RegenKgPerCycle);
      expect(b274.destinationLabel, 'Highsec');

      final i078 = deriver.project(rawFromF1(F1Fixtures.i078Raw()));
      expect(i078, isNotNull);
      expect(i078!.reliableLifetimeSeconds, F1Oracle.i078LifetimeSeconds);
      expect(i078.destinationLabel, 'Pochven');
      expect(i078.maxJumpMassKg, F1Oracle.i078JumpMassKg);

      final k162 = deriver.project(
        rawFromF1(F1Fixtures.k162Raw(), published: false),
      );
      expect(k162, isNotNull);
      expect(k162!.code, 'K162');
      expect(k162.reliableLifetimeSeconds, isNull);
      expect(k162.maxJumpMassKg, isNull);
      expect(k162.totalMassKg, isNull);
      expect(k162.regenerationKgPerCycle, isNull);

      final q001 = deriver.project(rawFromF1(F1Fixtures.q001Raw()));
      final q002 = deriver.project(rawFromF1(F1Fixtures.q002Raw()));
      expect(q001, isNotNull);
      expect(q002, isNotNull);
      expect(q001!.isCapitalSize, isTrue);
      expect(q002!.isCapitalSize, isFalse);
    });
  });

  group('D02 C729 variant groups', () {
    test('agreeing and conflicting C729 variants keep every type ID', () {
      final agreeing = deriver.groupByCode(
        deriver.projectCatalog([
          rawFromF1(F1Fixtures.c729V2AgreeRaw()),
          rawFromF1(F1Fixtures.c729V1Raw()),
        ]),
      );
      expect(agreeing, hasLength(1));
      expect(agreeing.single.variants, hasLength(2));
      expect(
        agreeing.single.variants.map((type) => type.typeId),
        unorderedEquals([kC729V1TypeId, kC729V2TypeId]),
      );
      expect(
        agreeing.single.sharedLifetimeSeconds,
        F1Oracle.c729LifetimeSeconds,
      );
      expect(agreeing.single.sharedJumpMassKg, F1Oracle.c729AgreedJumpKg);
      expect(agreeing.single.jumpVaries, isFalse);

      final conflicting = deriver.groupByCode(
        deriver.projectCatalog([
          rawFromF1(F1Fixtures.c729V1Raw()),
          rawFromF1(F1Fixtures.c729V2ConflictRaw()),
        ]),
      );
      expect(conflicting.single.variants, hasLength(2));
      expect(conflicting.single.jumpVaries, isTrue);
      expect(conflicting.single.sharedJumpMassKg, isNull);
      expect(
        conflicting.single.sharedLifetimeSeconds,
        F1Oracle.c729LifetimeSeconds,
      );
    });
  });

  group('D03 deterministic search and filters', () {
    test('trim/case rank, Highsec, capital AND, and K162 mass exclusion', () {
      final types = f1Catalog();
      final padded = deriver.search(
        types,
        const TypeSearchQuery(text: ' b274 '),
      );
      expect(padded.map((group) => group.code), ['B274']);

      final highsec = deriver.search(
        types,
        const TypeSearchQuery(text: 'highsec', destinationLabel: 'Highsec'),
      );
      expect(highsec.map((group) => group.code), ['B274']);

      final capitalC1 = deriver.search(
        types,
        const TypeSearchQuery(rawTargetClass: 1, capitalOnly: true),
      );
      expect(capitalC1.map((group) => group.code), ['Q001']);

      final k162Mass = deriver.search(
        types,
        const TypeSearchQuery(text: 'K162', minJumpMassKg: 1),
      );
      expect(k162Mass, isEmpty);
    });

    test('destination and mass AND must match the same C729 variant', () {
      final types = deriver.projectCatalog([
        rawFromF1(F1Fixtures.c729V1Raw()),
        rawFromF1(F1Fixtures.c729V2ConflictRaw()),
      ]);
      final hits = deriver.search(
        types,
        const TypeSearchQuery(rawTargetClass: -1, minJumpMassKg: 415000000),
      );
      expect(hits, hasLength(1));
      expect(hits.single.variants, hasLength(1));
      expect(hits.single.variants.single.typeId, kC729V2TypeId);
    });
  });

  group('D04 effect vectors and resonance', () {
    test('all 36 family/strength sets match §4.2 vectors and scopes', () {
      final combinations = catalog.combinations();
      expect(combinations, hasLength(F2Oracle.combinationCount));
      expect(
        combinations.map((entry) => '${entry.$1.name}-${entry.$2}').toSet(),
        hasLength(36),
      );

      for (var strength = 1; strength <= 6; strength++) {
        expect(
          catalog.percentChange(
            family: EffectFamily.pulsar,
            strength: strength,
            attributeId: 146,
          ),
          F2Oracle.pulsarShield[strength - 1],
        );
        expect(
          catalog.percentChange(
            family: EffectFamily.pulsar,
            strength: strength,
            attributeId: 1500,
          ),
          F2Oracle.pulsarCapRechargeTime[strength - 1],
        );
        expect(
          catalog.percentChange(
            family: EffectFamily.magnetar,
            strength: strength,
            attributeId: 1967,
          ),
          F2Oracle.magnetarExplosionRadius[strength - 1],
        );
        expect(
          catalog.percentChange(
            family: EffectFamily.wolfRayet,
            strength: strength,
            attributeId: 1493,
          ),
          F2Oracle.wolfRayetSmallWeapon[strength - 1],
        );
        expect(
          catalog
              .scopes(family: EffectFamily.wolfRayet, strength: strength)
              .containsAll(EffectCatalog.vortonEffectIds),
          isTrue,
        );
      }

      expect(
        catalog.percentChange(
          family: EffectFamily.pulsar,
          strength: 1,
          attributeId: 146,
        ),
        F2Oracle.multiplier130Percent,
      );
      expect(
        100 +
            catalog.percentChange(
              family: EffectFamily.magnetar,
              strength: 1,
              attributeId: 1967,
            ),
        F2Oracle.magnetarS1ExplosionFrom100,
      );
      expect(
        100 +
            catalog.percentChange(
              family: EffectFamily.wolfRayet,
              strength: 6,
              attributeId: 1493,
            ),
        F2Oracle.wolfRayetS6SmallFrom100,
      );
      expect(
        100 +
            catalog.percentChange(
              family: EffectFamily.pulsar,
              strength: 6,
              attributeId: 1500,
            ),
        F2Oracle.pulsarS6CapFrom100,
      );
      expect(
        SystemEffect.applyResonance(
          oldResist: F2Oracle.resonanceOldResist,
          percentIncrease: F2Oracle.resonancePercent,
        ),
        F2Oracle.resonanceNewResist,
      );
    });
  });

  group('D05 class, beacon, and special systems', () {
    test('beacon wins visual sun; class-13 is Wolf-Rayet 6', () {
      final redGiant = deriver.effectForSystem(F2Fixtures.j005926());
      expect(redGiant.family, EffectFamily.redGiant);
      expect(redGiant.strength, 1);
      expect(redGiant.beaconTypeId, 30848);

      final wolf = deriver.effectForSystem(F2Fixtures.j010569());
      expect(wolf.family, EffectFamily.wolfRayet);
      expect(wolf.strength, 1);
      expect(wolf.beaconTypeId, 30849);

      final shattered = deriver.effectForSystem(F2Fixtures.class13());
      expect(shattered.family, EffectFamily.wolfRayet);
      expect(shattered.strength, 6);

      expect(
        deriver
            .effectForSystem(
              SystemReference(systemId: 1, name: 'Missing', rawClass: 5),
            )
            .state,
        SystemEffectState.unknown,
      );
      expect(
        SystemEffect.resolve(beaconTypeId: null, verifiedAbsent: true).state,
        SystemEffectState.none,
      );
    });

    test('class inheritance is system then constellation then region', () {
      expect(deriver.inheritClass(system: 13, constellation: 5, region: 4), 13);
      expect(
        deriver.inheritClass(system: null, constellation: 5, region: 4),
        5,
      );
      expect(
        deriver.inheritClass(system: null, constellation: null, region: 4),
        4,
      );
    });
  });

  group('D06 honest statics', () {
    test('missing or typical statics stay unavailable and create no edge', () {
      expect(
        deriver.staticsDisclosure(datasetPresent: false),
        'Static information unavailable',
      );
      expect(
        deriver.staticsDisclosure(datasetPresent: true, typicalClassOnly: true),
        'Static information unavailable',
      );
      expect(deriver.staticsCreateRouteEdge(datasetPresent: false), isFalse);
      expect(
        deriver.staticsCreateRouteEdge(
          datasetPresent: true,
          typicalClassOnly: true,
        ),
        isFalse,
      );
    });
  });

  group('D07 far-side categories and security boundaries', () {
    test('class 7/12/25 are not Nullsec; security table is exact', () {
      expect(deriver.farSideCategory(7), SecurityCategory.highsec);
      expect(deriver.farSideCategory(8), SecurityCategory.lowsec);
      expect(deriver.farSideCategory(9), SecurityCategory.nullsec);
      expect(deriver.farSideCategory(12), isNot(SecurityCategory.nullsec));
      expect(deriver.farSideCategory(25), isNot(SecurityCategory.nullsec));
      expect(deriver.farSideCategory(null), SecurityCategory.unknown);

      for (final row in F2Fixtures.securityTable) {
        expect(
          SystemReference.classifySecurity(row.raw),
          row.category,
          reason: 'raw ${row.raw}',
        );
        expect(
          SystemReference.formatSecurity(row.raw),
          row.display,
          reason: 'raw ${row.raw}',
        );
      }
      expect(F2Fixtures.thera().category, isNot(SecurityCategory.nullsec));
      expect(F2Fixtures.pochven().category, isNot(SecurityCategory.nullsec));
    });
  });
}

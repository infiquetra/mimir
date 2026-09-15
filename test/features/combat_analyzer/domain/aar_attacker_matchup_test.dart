import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup_deriver.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_actor_classifier.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocator.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/attacker_correlation_fixtures.dart';
import '../fixtures/attacker_matchup_fixtures.dart';

void main() {
  group('AarAttackerMatchupDeriver partition D01 D03–D09', () {
    test('D01 solo source and aggregate share pattern EHP and hole', () {
      final bundle = _derive(s1Solo());
      expect(bundle.attackers, hasLength(1));
      final attacker = bundle.attackers.single;
      expect(
        attacker.source.allocation.components,
        bundle.allocation.components,
      );
      expect(attacker.defense.primaryHole, bundle.aggregateDefense.primaryHole);
      expect(
        attacker.defense.ehp!.total,
        closeTo(bundle.aggregateDefense.ehp!.total, 1e-6),
      );
      expect(
        attacker.defense.pattern!.em,
        closeTo(bundle.aggregateDefense.pattern!.em, 1e-9),
      );
      expect(
        bundle.allocation.totalIncomingDamage,
        bundle.allocation.sources.single.loggedDamage,
      );
    });

    test(
      'D03 consumes shipped bands and rejects impossible shipType Confirmed',
      () {
        final s2 = s2Fleet();
        final probable = _derive(s2);
        expect(
          probable.attackers.every((a) => a.source.namedCardEligible),
          isTrue,
        );

        final shipTypeConfirmed = CorrelatedAttacker(
          actor: actor(
            'Sabre',
            cls: CombatActorClass.shipType,
            damage: 1100,
            typeId: 22456,
          ),
          participant: participant(
            key: 'a2',
            characterId: 9003,
            name: 'Dax Rho',
            shipTypeId: 22456,
            damageDone: 1100,
          ),
          confidence: AttackerCorrelationConfidence.confirmed,
          score: 0.90,
          signals: const [CorrelationSignal.ship],
        );
        final encounter = matchupEncounter([
          ('Sabre', 1100, artemAutocannonName, 4),
        ]);
        final km = detail(
          victim: victim(damageTaken: 1100),
          attackers: [
            attacker(
              characterId: 9003,
              characterName: 'Dax Rho',
              shipTypeId: 22456,
              damageDone: 1100,
              finalBlow: true,
            ),
          ],
        );
        final rejected = _deriveFrom(
          encounter: encounter,
          detail: km,
          correlation: AttackerCorrelation(
            killmailId: km.killmailId,
            selfIsVictim: true,
            correlated: [shipTypeConfirmed],
            unattributedActors: const [],
            uncorrelatedParticipants: const [],
            correlatedIncomingDamage: 1100,
            unattributedIncomingDamage: 0,
            npcIncomingDamage: 0,
            totalIncomingDamage: 1100,
            reasons: const {},
            correlatedAt: now,
          ),
        );
        expect(rejected.attackers, isEmpty);
        expect(rejected.unattributed, isNotEmpty);
        expect(rejected.unattributed.single.limitationCodes, isNotEmpty);

        for (final band in [
          (0.29, null),
          (0.30, AttackerCorrelationConfidence.possible),
          (0.50, AttackerCorrelationConfidence.probable),
          (0.75, AttackerCorrelationConfidence.confirmed),
        ]) {
          expect(AttackerCorrelationRules.bandFor(band.$1), band.$2);
        }
      },
    );

    test('D04 Possible moves to X and leaves M4 totals unchanged', () {
      final s3 = s3Residuals();
      expect(s3.correlation.correlatedIncomingDamage, 600);
      final bundle = _derive(s3);
      expect(bundle.attackers, hasLength(1));
      expect(bundle.attackers.single.source.allocation.rawActorName, 'Alpha');
      final xLogged = bundle.unattributed.fold<int>(
        0,
        (sum, source) => sum + source.allocation.loggedDamage,
      );
      expect(xLogged, 300);
      expect(
        bundle.unattributed.any(
          (source) =>
              source.identity?.confidence ==
              AttackerCorrelationConfidence.possible,
        ),
        isTrue,
      );
      expect(s3.correlation.correlatedIncomingDamage, 600);
      expect(bundle.attackers.single.source.namedCardEligible, isTrue);
      expect(
        bundle.unattributed.every((source) => !source.namedCardEligible),
        isTrue,
      );
    });

    test('D05 Fixture B A/X/N = 400/300/300 and NPC counted once', () {
      final bundle = _derive(s3Residuals());
      expect(bundle.attackers.single.source.allocation.loggedDamage, 400);
      expect(
        bundle.unattributed.fold<int>(
          0,
          (sum, source) => sum + source.allocation.loggedDamage,
        ),
        300,
      );
      expect(
        bundle.npc.fold<int>(
          0,
          (sum, source) => sum + source.allocation.loggedDamage,
        ),
        300,
      );
      expect(
        bundle.allocation.components[IncomingDamageType.em],
        DamageQuantity.fromInt(300),
      );
      expect(
        bundle.allocation.components[IncomingDamageType.kinetic],
        DamageQuantity.fromInt(200),
      );
      expect(
        bundle.allocation.components[IncomingDamageType.explosive],
        DamageQuantity.fromInt(200),
      );
      expect(bundle.allocation.untypedDamage, 300);
      expect(bundle.npc, hasLength(1));
      expect(bundle.npc.single.bucket, IncomingSourceBucket.npc);
    });

    test('D06 unknown source and local NPC without correlation stay typed', () {
      final encounter = matchupEncounter([
        ('Unknown', 100, 'Missing Weapon', 4),
        ('Serpentis Watchman', 300, explosiveChargeName, 8),
      ]);
      final allocation = _allocate(
        encounter,
        extraWeapons: {
          normalizeCombatName('Missing Weapon'): unresolvedWeapon(
            'Missing Weapon',
          ),
        },
      );
      final bundle = AarAttackerMatchupDeriver.derive(
        allocation: allocation,
        correlation: IncomingCorrelationContext(
          parsedEncounterId: encounter.id,
          selectedKillmailId: null,
          selfCharacterId: encounter.characterId,
          selfIsVictim: null,
          correlation: null,
          currentParticipants: const [],
          localActorTypes: Map<String, CombatTypeRef>.from(typeIndex().byName),
        ),
        pilotFit: fixtureAPilotFit(),
        pilotFitEvidence: fixtureAPilotFitEvidence(),
        pilotFitKey: 'fit-a',
        dependencyLimitations: const [],
      );
      expect(bundle.npc.single.allocation.loggedDamage, 300);
      expect(bundle.unattributed.single.allocation.loggedDamage, 100);
      expect(bundle.attackers, isEmpty);
    });

    test(
      'D07 third-party stays X; unobserved killmail damage is footer only',
      () {
        final encounter = matchupEncounter([
          ('Kite Mondeo', 1100, kitePulseName, 4),
        ]);
        final km = detail(
          victim: victim(damageTaken: 99999),
          attackers: [
            attacker(
              characterId: 9001,
              characterName: 'Artem S3',
              shipTypeId: 24702,
              damageDone: 88888,
              finalBlow: true,
            ),
          ],
        );
        final bundle = _deriveFrom(
          encounter: encounter,
          detail: km,
          correlation: correlate((encounter: encounter, detail: km)),
        );
        expect(bundle.unattributed.single.allocation.loggedDamage, 1100);
        expect(bundle.allocation.totalIncomingDamage, 1100);
        expect(bundle.notObserved, isNotEmpty);
        expect(
          bundle.notObserved.any((p) => p.characterName == 'Artem S3'),
          isTrue,
        );
      },
    );

    test('D08 victim return fire uses incoming events and the pilot fit', () {
      final s4 = s4Victory();
      final bundle = _derive(s4);
      expect(bundle.attackers, hasLength(1));
      expect(
        bundle.attackers.single.source.allocation.rawActorName,
        'Vex Kalari',
      );
      expect(bundle.attackers.single.defense.pilotFitKey, 'fit-a');
      expect(s4.detail.victim.damageTaken, 8000);
      expect(bundle.allocation.totalIncomingDamage, 4000);
      expect(
        bundle.allocation.sources.every((s) => s.rawActorName != 'Pilot'),
        isTrue,
      );
    });

    test(
      'D09 raw precedence; conflicting attribution falls back with a reason',
      () {
        final encounter = matchupEncounter([
          ('Artem S3', 1000, artemAutocannonName, 4),
          ('artem  s3', 500, artemAutocannonName, 8),
        ]);
        final km = detail(
          victim: victim(damageTaken: 1500),
          attackers: [
            attacker(
              characterId: 9001,
              characterName: 'Artem S3',
              shipTypeId: 24702,
              damageDone: 1500,
              finalBlow: true,
            ),
          ],
        );
        final bundle = _deriveFrom(
          encounter: encounter,
          detail: km,
          correlation: correlate((encounter: encounter, detail: km)),
        );
        expect(bundle.allocation.totalIncomingDamage, 1500);
        expect(bundle.allocation.sources, hasLength(2));
        expect(bundle.allocation.sources.map((s) => s.loggedDamage).toSet(), {
          1000,
          500,
        });
      },
    );
  });

  group('Defense composition D11 D14–D20', () {
    test('D11 partial A qualifies resolved-portion comparison', () {
      final s1 = s1Solo(partialUnknownWeapon: true);
      final bundle = _derive(s1);
      final attacker = bundle.attackers.single;
      expect(attacker.source.allocation.loggedDamage, 4000);
      expect(attacker.source.allocation.resolvedDamage, 3000);
      expect(attacker.source.allocation.untypedDamage, 1000);
      expect(attacker.defense.status, IncomingDefenseStatus.available);
      expect(attacker.defense.limitationCodes, contains('resolvedPortionOnly'));
      expect(attacker.defense.pattern!.explosive, closeTo(0.75, 1e-9));
    });

    test('D14 EHP is not scaled by source share', () {
      final em = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: IncomingDamageVector(
          em: DamageQuantity.fromInt(1000),
          thermal: DamageQuantity.fromInt(0),
          kinetic: DamageQuantity.fromInt(0),
          explosive: DamageQuantity.fromInt(0),
        ),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(),
        ),
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(em.ehp!.total, closeTo(1000, 1e-6));
      final scaled = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: IncomingDamageVector(
          em: DamageQuantity.fromInt(4000),
          thermal: DamageQuantity.fromInt(0),
          kinetic: DamageQuantity.fromInt(0),
          explosive: DamageQuantity.fromInt(0),
        ),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(),
        ),
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(scaled.ehp!.total, closeTo(em.ehp!.total, 1e-6));
      final fifty = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: IncomingDamageVector(
          em: DamageQuantity.fromInt(0),
          thermal: DamageQuantity.fromInt(0),
          kinetic: DamageQuantity.fromInt(0),
          explosive: DamageQuantity.fromInt(1000),
        ),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(explosive: 50),
        ),
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(fifty.ehp!.total, closeTo(2000, 1e-6));
    });

    test('D15 Fixture A oracle rejects share-weighted average EHP', () {
      final bundle = _derive(s2Fleet());
      final kite = bundle.attackers.singleWhere(
        (a) => a.source.allocation.rawActorName == 'Kite Mondeo',
      );
      final artem = bundle.attackers.singleWhere(
        (a) => a.source.allocation.rawActorName == 'Artem S3',
      );
      expect(kite.defense.ehp!.total, closeTo(1176.470588, 1e-6));
      expect(artem.defense.ehp!.total, closeTo(1428.571429, 1e-6));
      expect(bundle.aggregateDefense.ehp!.total, closeTo(1265.822785, 1e-6));
      expect(kite.defense.primaryHole, IncomingDamageType.em);
      expect(artem.defense.primaryHole, IncomingDamageType.explosive);
      expect(bundle.aggregateDefense.primaryHole, IncomingDamageType.em);
      expect(
        kite.defense.entries
            .singleWhere((e) => e.type == IncomingDamageType.em)
            .modeledPressure,
        closeTo(0.882352941, 1e-9),
      );
      expect(
        artem.defense.entries
            .singleWhere((e) => e.type == IncomingDamageType.explosive)
            .modeledPressure,
        closeTo(0.857142857, 1e-9),
      );
      expect(
        bundle.aggregateDefense.entries
            .singleWhere((e) => e.type == IncomingDamageType.em)
            .modeledPressure,
        closeTo(0.569620253, 1e-9),
      );
      expect(kite.defense.omniEhp!.total, closeTo(1333.333333, 1e-6));
      expect(artem.defense.omniEhp!.total, closeTo(1333.333333, 1e-6));
      expect(
        bundle.aggregateDefense.omniEhp!.total,
        closeTo(1333.333333, 1e-6),
      );
      final averaged =
          0.6 * kite.defense.ehp!.total + 0.4 * artem.defense.ehp!.total;
      expect(averaged, closeTo(1277.310924, 1e-6));
      expect(
        bundle.aggregateDefense.ehp!.total,
        isNot(closeTo(averaged, 1e-4)),
      );
      expect(
        kite.source.allocation.components + artem.source.allocation.components,
        bundle.allocation.components,
      );
      expect(
        bundle.allocation.components.total +
            DamageQuantity.fromInt(bundle.allocation.untypedDamage),
        DamageQuantity.fromInt(bundle.allocation.totalIncomingDamage),
      );
    });

    test('D16 multi-layer EHP sums; selected tank is shared', () {
      final defense = const DefenseProfile(
        shieldHp: 1000,
        armorHp: 500,
        hullHp: 250,
        shieldResists: ResistProfile(
          em: 0,
          thermal: 20,
          kinetic: 60,
          explosive: 20,
        ),
        armorResists: ResistProfile(
          em: 50,
          thermal: 50,
          kinetic: 50,
          explosive: 50,
        ),
        hullResists: ResistProfile(),
      );
      final result = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: sdeVector(em: 75, thermal: 0, kinetic: 25, explosive: 0),
        defense: defense,
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(
        result.ehp!.total,
        closeTo(
          result.ehp!.shield + result.ehp!.armor + result.ehp!.hull,
          1e-9,
        ),
      );
      expect(result.layer, TankLayer.shield);
      final bundle = _derive(
        s2Fleet(),
        fit: fixtureAPilotFit(defense: defense),
      );
      expect(bundle.attackers.map((a) => a.defense.layer).toSet(), {
        TankLayer.shield,
      });
    });

    test('D17 resist boundaries keep hole precedence', () {
      DamageMatchupAssessment assess(double resist, double mean) {
        final result = CombatDamageMatchupAnalyzer.analyzeIncoming(
          components: IncomingDamageVector(
            em: DamageQuantity.fromInt(1000),
            thermal: DamageQuantity.fromInt(0),
            kinetic: DamageQuantity.fromInt(0),
            explosive: DamageQuantity.fromInt(0),
          ),
          defense: DefenseProfile(
            shieldHp: 1000,
            shieldResists: ResistProfile(
              em: resist,
              thermal: mean,
              kinetic: mean,
              explosive: mean,
            ),
          ),
          tank: fixtureATank,
          pilotFitKey: 'fit-a',
        );
        return result.entries
            .singleWhere((e) => e.type == IncomingDamageType.em)
            .assessment;
      }

      expect(assess(20, 25), DamageMatchupAssessment.resistHole);
      expect(assess(19, 25), DamageMatchupAssessment.resistHole);
      expect(assess(21, 25), DamageMatchupAssessment.neutral);
      expect(assess(20, 25), DamageMatchupAssessment.resistHole);
      expect(assess(32, 25), DamageMatchupAssessment.strongResist);
    });

    test('D18 present holes only; ties use canonical enum order', () {
      final tied = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: sdeVector(em: 1, thermal: 1, kinetic: 0, explosive: 0),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 0,
            thermal: 0,
            kinetic: 80,
            explosive: 80,
          ),
        ),
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(tied.primaryHole, IncomingDamageType.em);
      final absentWeakest = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: sdeVector(em: 0, thermal: 0, kinetic: 1, explosive: 0),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 0,
            thermal: 50,
            kinetic: 50,
            explosive: 50,
          ),
        ),
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(absentWeakest.primaryHole, isNot(IncomingDamageType.em));
      final noHole = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: sdeVector(em: 1, thermal: 1, kinetic: 1, explosive: 1),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 80,
            thermal: 80,
            kinetic: 80,
            explosive: 80,
          ),
        ),
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(noHole.primaryHole, isNull);
      expect(noHole.pressureStatus, IncomingPressureStatus.available);
    });

    test('D19 unavailable and invalid guards do not invent quantities', () {
      final noFit = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: sdeVector(em: 1, thermal: 0, kinetic: 0, explosive: 0),
        defense: null,
        tank: null,
        pilotFitKey: null,
      );
      expect(noFit.status, IncomingDefenseStatus.pilotDefenseUnavailable);
      expect(noFit.ehp, isNull);
      expect(noFit.pattern, isNotNull);

      final zeroK = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: IncomingDamageVector(
          em: DamageQuantity.fromInt(0),
          thermal: DamageQuantity.fromInt(0),
          kinetic: DamageQuantity.fromInt(0),
          explosive: DamageQuantity.fromInt(0),
        ),
        defense: fixtureADefense,
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(zeroK.status, IncomingDefenseStatus.noTypedDamage);
      expect(zeroK.pattern, isNull);

      final unknownLayer = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: sdeVector(em: 1, thermal: 0, kinetic: 0, explosive: 0),
        defense: fixtureADefense,
        tank: const TankAssessment(
          layer: TankLayer.unknown,
          mode: TankMode.unfitted,
          shieldBoostHps: 0,
          armorRepairHps: 0,
          hullRepairHps: 0,
          shieldGainEhp: 0,
          armorGainEhp: 0,
          hullGainEhp: 0,
          reasoning: 'unknown',
        ),
        pilotFitKey: 'fit-a',
      );
      expect(unknownLayer.ehp, isNotNull);
      expect(unknownLayer.pressureStatus, IncomingPressureStatus.unknownLayer);
      expect(unknownLayer.primaryHole, isNull);

      final invulnerable = CombatDamageMatchupAnalyzer.analyzeIncoming(
        components: sdeVector(em: 1, thermal: 0, kinetic: 0, explosive: 0),
        defense: const DefenseProfile(
          shieldHp: 1000,
          shieldResists: ResistProfile(
            em: 100,
            thermal: 100,
            kinetic: 100,
            explosive: 100,
          ),
        ),
        tank: fixtureATank,
        pilotFitKey: 'fit-a',
      );
      expect(invulnerable.guardedLayers, isNotEmpty);
      expect(
        invulnerable.pressureStatus,
        anyOf(
          IncomingPressureStatus.zeroDenominator,
          IncomingPressureStatus.unavailable,
        ),
      );
    });

    test(
      'D20 determinism, isolation, and invalid totals withhold the bundle',
      () {
        final first = _derive(s2Fleet());
        final second = _derive(s2Fleet());
        expect(first.snapshotKey, second.snapshotKey);
        expect(
          first.attackers.map((a) => a.source.allocation.sourceId).toList(),
          second.attackers.map((a) => a.source.allocation.sourceId).toList(),
        );
        final solo = _derive(s1Solo());
        expect(solo.snapshotKey, isNot(first.snapshotKey));

        final mismatched = matchupEncounter([
          ('Kite Mondeo', 6000, kitePulseName, 4),
        ]);
        final broken = mismatched.copyWith(
          aggregates: CombatAggregates(
            totalDamageDealt: 0,
            totalDamageReceived: 9999,
            cumulativeDamage: const [],
            damageByTarget: const {},
            damageByWeapon: const {},
            incomingBySource: const {'Kite Mondeo': 6000},
            hitQualityCounts: const {},
            outgoingHitQualityCounts: const {},
            incomingHitQualityCounts: const {},
            outgoingHitCount: 0,
            incomingHitCount: 1,
            peakOutgoingHit: 0,
            peakIncomingHit: 6000,
            averageOutgoingHit: 0,
            averageIncomingHit: 6000,
            missCount: 0,
            idleGapCount: 0,
            ewarEventCount: 0,
          ),
        );
        final result = IncomingDamageAllocator.allocate(
          encounter: broken,
          weapons: matchupWeaponTable(),
          sdeContentKey: matchupSdeContentKey,
        );
        expect(result, isA<IncomingAllocationInvalid>());
        expect(
          (result as IncomingAllocationInvalid).reasonCode,
          'eventTotalsMismatch',
        );
      },
    );
  });
}

IncomingDamageAllocation _allocate(
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

AarIncomingMatchupBundle _derive(
  ({
    ParsedCombatEncounter encounter,
    EsiKillmailDetail detail,
    AttackerCorrelation correlation,
    CombatEnrichment enrichment,
  })
  scenario, {
  AarFitDerivation? fit,
}) {
  return _deriveFrom(
    encounter: scenario.encounter,
    detail: scenario.detail,
    correlation: scenario.correlation,
    fit: fit,
  );
}

AarIncomingMatchupBundle _deriveFrom({
  required ParsedCombatEncounter encounter,
  required EsiKillmailDetail detail,
  required AttackerCorrelation correlation,
  AarFitDerivation? fit,
  Map<String, IncomingWeaponResolution> extraWeapons = const {},
}) {
  final allocation = _allocate(encounter, extraWeapons: extraWeapons);
  return AarAttackerMatchupDeriver.derive(
    allocation: allocation,
    correlation: matchupCorrelationContext(
      encounter: encounter,
      detail: detail,
      correlation: correlation,
    ),
    pilotFit: fit ?? fixtureAPilotFit(),
    pilotFitEvidence: fixtureAPilotFitEvidence(),
    pilotFitKey: 'fit-a',
    dependencyLimitations: const [],
  );
}

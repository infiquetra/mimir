// W4 RED contracts for shared-context calculation and metric deltas.
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §6:
// - D08: ehpFor ignores the selected profile and uses stored Omni EHP.
// - D09: victim columns fall back to All V independently of pilot skills.
// - D10: volley includes drone/fighter DPS; unknown charges stay available.
// - D11: cap transition subtracts mixed units; percentDelta allows Infinity.
// - D12: CPU excess invalidates the fit; unknown modules still claim uplift.
// - P07: late results for older frame keys overwrite current numbers.
// - D06: drone/fighter deployment keeps input order and can merge tuples.
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_calculation.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_comparison.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart'
    hide AarFitSubject;
import 'package:mimir/features/combat_analyzer/domain/aar_fit_snapshot.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/damage_pattern.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_comparison_fixtures.dart';

void main() {
  DefenseProfile f3Defense(List<double> resistFractions) {
    final resists = ResistProfile(
      em: resistFractions[0] * 100,
      thermal: resistFractions[1] * 100,
      kinetic: resistFractions[2] * 100,
      explosive: resistFractions[3] * 100,
    );
    return DefenseProfile(
      shieldHp: F3Oracle.layerHp,
      armorHp: F3Oracle.layerHp,
      hullHp: F3Oracle.layerHp,
      shieldResists: resists,
      armorResists: resists,
      hullResists: resists,
    );
  }

  const emPattern = DamagePattern(
    em: 1,
    thermal: 0,
    kinetic: 0,
    explosive: 0,
    label: 'EM',
  );
  const m5Pattern = DamagePattern(
    em: 1,
    thermal: 0,
    kinetic: 0,
    explosive: 0,
    label: 'M5',
  );

  group('W4 D08 F3 EM/Omni/M5 EHP and pp deltas', () {
    test('EM profile matches F3 oracle at domain precision', () {
      final baseline = AarComparisonMetrics.ehpFor(
        f3Defense(F3Oracle.baselineResists),
        emPattern,
      );
      final target = AarComparisonMetrics.ehpFor(
        f3Defense(F3Oracle.targetResists),
        emPattern,
      );

      expect(baseline.shield, closeTo(F3Oracle.emBaselineLayerEhp, 1e-9));
      expect(baseline.armor, closeTo(F3Oracle.emBaselineLayerEhp, 1e-9));
      expect(baseline.hull, closeTo(F3Oracle.emBaselineLayerEhp, 1e-9));
      expect(baseline.total, closeTo(F3Oracle.emBaselineTotalEhp, 1e-9));
      expect(target.total, closeTo(F3Oracle.emTargetTotalEhp, 1e-9));

      final delta = AarComparisonMetrics.delta(baseline.total, target.total);
      final relative = AarComparisonMetrics.percentDelta(
        baseline.total,
        target.total,
      );
      final resist = AarComparisonMetrics.resistPp(
        F3Oracle.baselineResists[0],
        F3Oracle.targetResists[0],
      );
      expect(delta.value, closeTo(F3Oracle.emDeltaEhp, 1e-9));
      expect(relative.value, closeTo(F3Oracle.emDeltaPercent, 1e-9));
      expect(resist.value, closeTo(F3Oracle.emResistPp, 1e-9));
    });

    test('Omni profile matches F3 oracle at domain precision', () {
      final baseline = AarComparisonMetrics.ehpFor(
        f3Defense(F3Oracle.baselineResists),
        DamagePattern.omni,
      );
      final target = AarComparisonMetrics.ehpFor(
        f3Defense(F3Oracle.targetResists),
        DamagePattern.omni,
      );
      expect(baseline.total, closeTo(F3Oracle.omniBaselineEhp, 1e-9));
      expect(target.total, closeTo(F3Oracle.omniTargetEhp, 1e-9));
      expect(
        AarComparisonMetrics.delta(baseline.total, target.total).value,
        closeTo(F3Oracle.omniDeltaEhp, 1e-9),
      );
      expect(
        AarComparisonMetrics.percentDelta(baseline.total, target.total).value,
        closeTo(F3Oracle.omniDeltaPercent, 1e-9),
      );
    });

    test('M5 incoming allocation uses the same selected profile as EM', () {
      final baseline = AarComparisonMetrics.ehpFor(
        f3Defense(F3Oracle.baselineResists),
        m5Pattern,
      );
      final target = AarComparisonMetrics.ehpFor(
        f3Defense(F3Oracle.targetResists),
        m5Pattern,
      );
      expect(baseline.total, closeTo(F3Oracle.emBaselineTotalEhp, 1e-9));
      expect(target.total, closeTo(F3Oracle.emTargetTotalEhp, 1e-9));
      expect(baseline.pattern.label, 'M5');
    });

    test('presentation rounding is separate from domain math', () {
      final total = F3Oracle.omniBaselineEhp;
      final formatted = AarComparisonMetrics.formatEhp(total);
      final resist = AarComparisonMetrics.formatResistPp(F3Oracle.emResistPp);
      expect(formatted, isNot(total.toString()));
      expect(resist.toLowerCase(), contains('pp'));
      expect(
        AarComparisonMetrics.percentDelta(
          F3Oracle.omniBaselineEhp,
          F3Oracle.omniTargetEhp,
        ).value,
        closeTo(F3Oracle.omniDeltaPercent, 1e-12),
      );
    });
  });

  group('W4 D09 one common skill context', () {
    const known = [CharacterSkill(skillId: 3300, level: 5)];

    test('known pilot skills apply to every column including victim', () {
      final pilot = AarComparisonMetrics.commonSkills(
        cachedPilotSkills: known,
        opponentColumn: false,
        characterId: 42,
      );
      final victim = AarComparisonMetrics.commonSkills(
        cachedPilotSkills: known,
        opponentColumn: true,
        characterId: 42,
      );
      final proposal = AarComparisonMetrics.commonSkills(
        cachedPilotSkills: known,
        opponentColumn: false,
        characterId: 42,
      );
      expect(pilot.basis, AarSkillBasis.knownCharacter);
      expect(victim.basis, AarSkillBasis.knownCharacter);
      expect(proposal.basis, AarSkillBasis.knownCharacter);
      expect(victim.skills, known);
      expect(
        AarComparisonMetrics.skillDisclosure(victim, opponentColumn: true),
        'Modeled with comparison skills; opponent skills unknown',
      );
    });

    test('missing skills fall back together to All V', () {
      final pilot = AarComparisonMetrics.commonSkills(
        cachedPilotSkills: const [],
        opponentColumn: false,
      );
      final victim = AarComparisonMetrics.commonSkills(
        cachedPilotSkills: const [],
        opponentColumn: true,
      );
      expect(pilot.basis, AarSkillBasis.allFive);
      expect(victim.basis, AarSkillBasis.allFive);
      expect(pilot.basis, victim.basis);
    });
  });

  group('W4 D10 volley, DPS split and unknown charges', () {
    test('volley is turret/launcher only; DPS keeps the theoretical split', () {
      const stats = FittingStats(
        dpsGuns: 210,
        dpsMissiles: 40,
        dpsDrones: 102.4,
        dpsFighters: 15,
        dpsTotal: 367.4,
        volley: 890,
      );
      expect(AarComparisonMetrics.weaponVolley(stats), 890);
      expect(stats.dpsGuns, 210);
      expect(stats.dpsMissiles, 40);
      expect(stats.dpsDrones, 102.4);
      expect(stats.dpsFighters, 15);
      expect(stats.dpsTotal, closeTo(367.4, 1e-9));
      expect(AarComparisonMetrics.weaponVolley(stats), isNot(stats.dpsTotal));
    });

    test('unknown charges qualify offense instead of observed zero damage', () {
      final snapshot = AarComparisonFixtures.snapshotOf(
        Fitting(
          id: 'guns',
          name: 'guns',
          shipTypeId: kCmpHullH,
          shipName: 'Cmp H',
          highSlots: [
            AarComparisonFixtures.moduleA(chargeTypeId: null, chargeName: null),
          ],
        ),
        knowledge: FitInventoryKnowledge(
          groups: {
            FitInventoryGroup.high: const FitGroupKnowledge(
              completeness: InventoryCompleteness.partial,
            ),
          },
          occurrences: const [
            FitOccurrenceKnowledge(
              occurrenceKey: 'high:0',
              charge: ChargeKnowledge.unknown,
            ),
          ],
        ),
      );
      final qualification = AarComparisonMetrics.qualifyComputation(
        snapshot: snapshot,
        computation: CombatFitComputation(
          stats: const FittingStats(dpsGuns: 0, dpsTotal: 0, volley: 0),
          bareHullStats: const FittingStats(),
          tank: const TankAssessment(
            layer: TankLayer.shield,
            mode: TankMode.buffer,
            shieldBoostHps: 0,
            armorRepairHps: 0,
            hullRepairHps: 0,
            shieldGainEhp: 0,
            armorGainEhp: 0,
            hullGainEhp: 0,
            reasoning: 'fixture',
          ),
          coverage: _emptyCoverage(),
        ),
        context: const AarComparisonContext(
          skillFingerprint: 's',
          profileKey: 'omni',
          sdeRevision: '1',
          calculatorRevision: '1',
        ),
      );
      expect(qualification.offenseIncomplete, isTrue);
      expect(
        qualification.availability,
        isNot(AarMetricAvailability.available),
      );
      expect(qualification.confidentImprovement, isFalse);
    });
  });

  group('W4 D11 F4 cap/tank and nonfinite deltas', () {
    test('cap transition is labeled, not mixed-unit subtraction', () {
      const baseline = FittingStats(isCapStable: false, capacitorStable: 120);
      const target = FittingStats(isCapStable: true, capacitorStable: 35);
      expect(
        AarComparisonMetrics.capTransition(baseline: baseline, target: target),
        F4Oracle.capTransition,
      );
      expect(
        AarComparisonMetrics.capTransition(baseline: baseline, target: target),
        isNot('-85'),
      );
      expect(
        AarComparisonMetrics.capTransition(baseline: baseline, target: target),
        isNot(contains('85')),
      );
    });

    test('burst and peak passive stay HP/s; sustained is not modeled', () {
      const stats = FittingStats(
        defenses: DefenseProfile(
          effectiveShieldBoost: 100,
          peakShieldRecharge: 20,
        ),
      );
      expect(stats.defenses.effectiveShieldBoost, F4Oracle.burstRepairHps);
      expect(stats.defenses.peakShieldRecharge, F4Oracle.peakPassiveHps);
      expect(
        AarComparisonMetrics.sustainedRepairLabel(stats),
        F4Oracle.sustainedLabel,
      );
    });

    test(
      'zero and nonfinite denominators are unavailable, never NaN/Infinity',
      () {
        final zero = AarComparisonMetrics.percentDelta(0, 1500);
        final nan = AarComparisonMetrics.percentDelta(double.nan, 10);
        final inf = AarComparisonMetrics.percentDelta(double.infinity, 10);
        expect(zero.availability, AarMetricAvailability.unavailable);
        expect(zero.value, isNull);
        expect(nan.availability, AarMetricAvailability.unavailable);
        expect(inf.availability, AarMetricAvailability.unavailable);
        expect(zero.value?.isNaN, isNot(true));
        expect(zero.value?.isInfinite, isNot(true));
      },
    );
  });

  group('W4 D12 constraint warnings and unknown modules', () {
    test('CPU/PG excess warns without invalidating the computation', () {
      final snapshot = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f1Baseline(),
      );
      final qualification = AarComparisonMetrics.qualifyComputation(
        snapshot: snapshot,
        computation: CombatFitComputation(
          stats: const FittingStats(
            cpuUsed: 200,
            cpuMax: 155,
            powerUsed: 90,
            powerMax: 40,
            calibrationUsed: 10,
            calibrationMax: 400,
          ),
          bareHullStats: const FittingStats(),
          tank: const TankAssessment(
            layer: TankLayer.shield,
            mode: TankMode.buffer,
            shieldBoostHps: 0,
            armorRepairHps: 0,
            hullRepairHps: 0,
            shieldGainEhp: 0,
            armorGainEhp: 0,
            hullGainEhp: 0,
            reasoning: 'fixture',
          ),
          coverage: _emptyCoverage(),
        ),
        context: const AarComparisonContext(
          skillFingerprint: 's',
          profileKey: 'omni',
          sdeRevision: '1',
          calculatorRevision: '1',
        ),
      );
      expect(qualification.invalid, isFalse);
      expect(qualification.constraintWarning, isTrue);
      expect(
        AarComparisonMetrics.constraintsLegal(
          const FittingStats(cpuUsed: 200, cpuMax: 155),
        ),
        isFalse,
      );
    });

    test(
      'unknown module qualifies metrics and suppresses confident uplift',
      () {
        final snapshot = AarFitSnapshot(
          snapshotId: 'unknown-mod',
          encounterId: 'enc',
          fitting: AarComparisonFixtures.hullOnly(),
          source: AarFitSource.comparisonCapture,
          subject: const AarFitSubject(relation: AarFitSubjectRelation.pilot),
          knowledge: FitInventoryKnowledge(
            groups: {
              FitInventoryGroup.low: const FitGroupKnowledge(
                completeness: InventoryCompleteness.unknown,
                applicability: GroupApplicability.applicable,
              ),
            },
            unplacedEntries: const [
              UnresolvedOccupant(sourceEntryKey: 'low-0', label: 'unknown low'),
            ],
          ),
        );
        final qualification = AarComparisonMetrics.qualifyComputation(
          snapshot: snapshot,
          computation: CombatFitComputation(
            stats: const FittingStats(
              defenses: DefenseProfile(totalEhp: 9000),
              dpsTotal: 400,
            ),
            bareHullStats: const FittingStats(
              defenses: DefenseProfile(totalEhp: 800),
            ),
            tank: const TankAssessment(
              layer: TankLayer.shield,
              mode: TankMode.buffer,
              shieldBoostHps: 0,
              armorRepairHps: 0,
              hullRepairHps: 0,
              shieldGainEhp: 0,
              armorGainEhp: 0,
              hullGainEhp: 0,
              reasoning: 'fixture',
            ),
            coverage: _emptyCoverage(),
          ),
          context: const AarComparisonContext(
            skillFingerprint: 's',
            profileKey: 'omni',
            sdeRevision: '1',
            calculatorRevision: '1',
          ),
        );
        expect(qualification.availability, AarMetricAvailability.partial);
        expect(qualification.confidentImprovement, isFalse);
      },
    );
  });

  group('W4 P07 frame key invalidation', () {
    test('late results for an older key are rejected', () {
      final context = const AarComparisonContext(
        skillFingerprint: 'skills-v1',
        profileKey: 'omni',
        sdeRevision: 'sde-1',
        calculatorRevision: 'calc-1',
      );
      final key = AarComparisonFrame.requestKey(
        sourceFingerprints: const ['fit-old'],
        context: context,
      );
      final frame = AarComparisonFrame(key: key);
      final first = CombatFitComputation(
        stats: const FittingStats(dpsTotal: 100),
        bareHullStats: const FittingStats(),
        tank: const TankAssessment(
          layer: TankLayer.shield,
          mode: TankMode.buffer,
          shieldBoostHps: 0,
          armorRepairHps: 0,
          hullRepairHps: 0,
          shieldGainEhp: 0,
          armorGainEhp: 0,
          hullGainEhp: 0,
          reasoning: 'old',
        ),
        coverage: _emptyCoverage(),
        frameKey: key,
      );
      expect(frame.publish(key, 'baseline', first), isTrue);

      final staleKey = AarComparisonFrame.requestKey(
        sourceFingerprints: const ['fit-old'],
        context: const AarComparisonContext(
          skillFingerprint: 'skills-v1',
          profileKey: 'em',
          sdeRevision: 'sde-1',
          calculatorRevision: 'calc-1',
        ),
      );
      final late = CombatFitComputation(
        stats: const FittingStats(dpsTotal: 999),
        bareHullStats: const FittingStats(),
        tank: first.tank,
        coverage: _emptyCoverage(),
        frameKey: staleKey,
      );
      expect(frame.publish(staleKey, 'baseline', late), isFalse);
      expect(frame.columns['baseline']!.stats.dpsTotal, 100);
    });
  });

  group('W4 D06 canonical deployment sort', () {
    test('drone groups sort by type and deployment and are not merged', () {
      const later = DroneGroup(
        typeId: 2,
        typeName: 'B',
        quantity: 5,
        inBay: 4,
        inSpace: 1,
      );
      const earlier = DroneGroup(
        typeId: 1,
        typeName: 'A',
        quantity: 5,
        inBay: 5,
      );
      const sameTypeSpace = DroneGroup(
        typeId: 1,
        typeName: 'A',
        quantity: 5,
        inBay: 4,
        inSpace: 1,
      );
      final sorted = AarComparisonMetrics.canonicalDrones([
        later,
        sameTypeSpace,
        earlier,
      ]);
      expect(sorted.map((group) => group.typeId).toList(), [1, 1, 2]);
      expect(sorted[0].inSpace, 0);
      expect(sorted[1].inSpace, 1);
      expect(sorted, hasLength(3));
    });

    test('fighter groups keep distinct deployment tuples', () {
      const space = FighterGroup(
        typeId: 9,
        typeName: 'F',
        quantity: 3,
        inSpace: 2,
      );
      const bay = FighterGroup(typeId: 9, typeName: 'F', quantity: 3);
      final sorted = AarComparisonMetrics.canonicalFighters([space, bay]);
      expect(sorted, hasLength(2));
      expect(sorted.first.inSpace, 0);
      expect(sorted.last.inSpace, 2);
    });
  });
}

AarFitCoverage _emptyCoverage() {
  return const AarFitCoverage(
    highFitted: 0,
    highSlots: 0,
    medFitted: 0,
    medSlots: 0,
    lowFitted: 0,
    lowSlots: 0,
    rigFitted: 0,
    rigSlots: 0,
    subsystemFitted: 0,
    subsystemSlots: 0,
    unresolvedTypeIds: [],
    unresolvedNames: [],
  );
}

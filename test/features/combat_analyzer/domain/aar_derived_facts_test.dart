import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_derived_facts.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('AarDerivedFactsBuilder', () {
    final derivedAt = DateTime.utc(2026, 9, 11, 12);

    AarFitDerivation derivation({
      AarSkillBasis basis = AarSkillBasis.allFive,
      AarFitCoverage? coverage,
      List<String>? limitations,
    }) {
      final skills = AarSkillContext(
        basis: basis,
        skills: const [],
        characterId: basis == AarSkillBasis.knownCharacter ? 42 : null,
      );
      final limits =
          limitations ?? [skills.label, 'Module states assumed active'];
      return AarFitDerivation(
        role: FitEvidenceRole.pilot,
        subject: AarFitSubject.self,
        fitSource: EvidenceSource.manualFitImport,
        shipTypeId: 587,
        shipName: 'Rifter',
        skills: skills,
        stats: const FittingStats(
          cpuMax: 156.25,
          capacitorCapacity: 250,
          capacitorStable: 41,
          isCapStable: true,
          dpsTotal: 312.4,
          dpsGuns: 210,
          dpsDrones: 102.4,
          volley: 890,
          maxVelocity: 1234,
          signatureRadius: 42,
          alignTime: 4.7,
          defenses: DefenseProfile(
            shieldHp: 1550,
            armorHp: 450,
            hullHp: 350,
            shieldEhp: 2137,
            armorEhp: 667,
            hullEhp: 522,
            totalEhp: 12345,
            effectiveArmorRepair: 84.3,
            peakShieldRecharge: 6.3,
            shieldResists: ResistProfile(
              em: 0,
              thermal: 20,
              kinetic: 40,
              explosive: 50,
            ),
          ),
        ),
        baseline: const FittingStats(),
        tank: const TankAssessment(
          layer: TankLayer.armor,
          mode: TankMode.active,
          shieldBoostHps: 0,
          armorRepairHps: 84.3,
          hullRepairHps: 0,
          shieldGainEhp: 3586,
          armorGainEhp: 0,
          hullGainEhp: 0,
          reasoning:
              'Armor (active): 84.3 HP/s armor repair vs 0.0 shield boost, 0.0 hull repair; buffer gains shield +3,586 / armor +0 / hull +0 EHP.',
        ),
        coverage:
            coverage ??
            const AarFitCoverage(
              highFitted: 3,
              highSlots: 4,
              medFitted: 1,
              medSlots: 3,
              lowFitted: 0,
              lowSlots: 3,
              rigFitted: 0,
              rigSlots: 3,
              subsystemFitted: 0,
              subsystemSlots: 0,
              unresolvedTypeIds: [],
              unresolvedNames: [],
            ),
        derivedAt: derivedAt,
        limitations: limits,
      );
    }

    test('T7.1 T1.1 derivation emits >=8 dogmaDerivation facts for self', () {
      final facts = AarDerivedFactsBuilder.facts(
        derivation(),
        encounterId: 'enc-1',
      );
      expect(facts.length, greaterThanOrEqualTo(8));
      expect(facts.every((f) => f.id.startsWith('ev-derived-self-')), isTrue);
      expect(
        facts.every((f) => f.source == EvidenceSource.dogmaDerivation),
        isTrue,
      );
    });

    test(
      'T7.2 mixed ledger contains combatLog and dogmaDerivation sources',
      () {
        final derived = AarDerivedFactsBuilder.facts(
          derivation(),
          encounterId: 'enc-1',
        );
        final mixed = [
          const CombatEvidenceFact(
            id: 'ev-log-damage',
            label: 'Outgoing damage',
            value: '100',
            source: EvidenceSource.combatLog,
            confidence: EvidenceConfidence.proven,
          ),
          ...derived,
        ];
        expect(
          mixed.map((f) => f.source).toSet(),
          containsAll({
            EvidenceSource.combatLog,
            EvidenceSource.dogmaDerivation,
          }),
        );
      },
    );

    test('T7.3 unknownsFor with no evidence names opponent defense', () {
      const incoming = CombatDamageProfile(
        entries: [],
        unknownWeapons: [],
        totalProfiledDamage: 0,
      );
      final unknowns = AarDerivedFactsBuilder.unknownsFor(
        const AarDerivationBundle(),
        hasPilotEvidence: false,
        hasOpponentEvidence: false,
        incoming: incoming,
      );
      expect(
        unknowns.any(
          (u) =>
              u.category == AarUnknownCategory.opponentFit &&
              u.label == 'Opponent defense profile',
        ),
        isTrue,
      );
    });

    test('T7.4 unresolved module unknown names Type #id and floor', () {
      final d = derivation(
        coverage: const AarFitCoverage(
          highFitted: 3,
          highSlots: 4,
          medFitted: 1,
          medSlots: 3,
          lowFitted: 0,
          lowSlots: 3,
          rigFitted: 0,
          rigSlots: 3,
          subsystemFitted: 0,
          subsystemSlots: 0,
          unresolvedTypeIds: [99999],
          unresolvedNames: ['Mystery Gun'],
        ),
      );
      final unknowns = AarDerivedFactsBuilder.unknownsFor(
        AarDerivationBundle(self: d),
        hasPilotEvidence: true,
        hasOpponentEvidence: false,
        incoming: const CombatDamageProfile(
          entries: [],
          unknownWeapons: [],
          totalProfiledDamage: 0,
        ),
      );
      final moduleUnknown = unknowns.firstWhere(
        (u) => u.detail.toLowerCase().contains('floor'),
      );
      expect(moduleUnknown.detail, contains('Type #99999'));
    });

    test(
      'T2.4 allFive skills fact is assumes All V at reference confidence',
      () {
        final facts = AarDerivedFactsBuilder.facts(
          derivation(),
          encounterId: 'enc-1',
        );
        final skills = facts.firstWhere((f) => f.id.contains('-skills-'));
        expect(skills.value, contains('assumes All V'));
        expect(
          facts.every((f) => f.limitations.contains('assumes All V')),
          isTrue,
        );
        expect(
          facts.every((f) => f.confidence == EvidenceConfidence.reference),
          isTrue,
        );
      },
    );

    test('G.6 fact ids are deterministic and suffix the encounter id', () {
      final first = AarDerivedFactsBuilder.facts(
        derivation(),
        encounterId: 'enc-9',
      );
      final second = AarDerivedFactsBuilder.facts(
        derivation(),
        encounterId: 'enc-9',
      );
      expect(first, isNotEmpty);
      expect(first.map((f) => f.id).toList(), second.map((f) => f.id).toList());
      expect(first.every((f) => f.id.endsWith('-enc-9')), isTrue);
    });

    test('T7.5 fact values contain the numbers a stats panel would render', () {
      final facts = AarDerivedFactsBuilder.facts(
        derivation(),
        encounterId: 'enc-1',
        matchup: const CombatDamageMatchup(
          targetLabel: 'Rifter',
          layer: 'armor',
          summary: 'incoming',
          primaryHole: 'Thermal',
          entries: [],
        ),
      );
      final values = facts.map((f) => f.value).join(' | ');
      expect(values, contains('12,345'));
      expect(values, contains('Armor (active)'));
      expect(values, contains('84.3'));
      expect(values, contains('Stable at 41%'));
      expect(values, contains('312.4'));
    });
  });
}

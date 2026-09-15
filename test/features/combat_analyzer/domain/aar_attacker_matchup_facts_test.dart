import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup_deriver.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup_facts.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocator.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

import '../fixtures/attacker_matchup_fixtures.dart';

void main() {
  group('AarAttackerMatchupFacts', () {
    test('D04 Possible has no named defense fact', () {
      final bundle = _bundle(s3Residuals());
      final ledger = AarAttackerMatchupFacts.build(bundle);
      expect(ledger.facts.where((f) => f.id.contains('-defense')), isNotEmpty);
      expect(
        ledger.facts.where(
          (f) =>
              f.id.contains('-defense') &&
              (f.id.contains('bravo') ||
                  f.id.toLowerCase().contains('possible')),
        ),
        isEmpty,
      );
    });

    test('weakest-dependency confidence never exceeds derived', () {
      final allFive = _bundle(
        s2Fleet(),
        fit: fixtureAPilotFit(basis: AarSkillBasis.allFive),
      );
      final ledger = AarAttackerMatchupFacts.build(allFive);
      final defenseFacts = ledger.facts.where((f) => f.id.contains('-defense'));
      expect(defenseFacts, isNotEmpty);
      expect(
        defenseFacts.every(
          (f) =>
              f.confidence == EvidenceConfidence.reference ||
              f.confidence == EvidenceConfidence.unknown,
        ),
        isTrue,
      );
    });

    test('source removal removes M5 facts', () {
      final fleet = AarAttackerMatchupFacts.build(_bundle(s2Fleet()));
      final solo = AarAttackerMatchupFacts.build(_bundle(s1Solo()));
      expect(fleet.facts.any((f) => f.id.contains('logged')), isTrue);
      final fleetIds = fleet.facts.map((f) => f.id).toSet();
      final soloIds = solo.facts.map((f) => f.id).toSet();
      expect(fleetIds.length, greaterThan(soloIds.length));
      expect(
        fleet.facts.any(
          (f) => f.id.contains('kite') || f.label.contains('Kite'),
        ),
        isTrue,
      );
    });

    test('X and N have residual facts but no named defense', () {
      final ledger = AarAttackerMatchupFacts.build(_bundle(s3Residuals()));
      expect(ledger.facts.any((f) => f.id.contains('residual-x')), isTrue);
      expect(ledger.facts.any((f) => f.id.contains('residual-npc')), isTrue);
      expect(
        ledger.facts.where(
          (f) =>
              f.id.contains('-defense') &&
              (f.id.contains('residual-x') || f.id.contains('residual-npc')),
        ),
        isEmpty,
      );
    });

    test('fact IDs are stable across identical snapshots', () {
      final first = AarAttackerMatchupFacts.build(_bundle(s2Fleet()));
      final second = AarAttackerMatchupFacts.build(_bundle(s2Fleet()));
      expect(
        first.facts.map((f) => f.id).toList(),
        second.facts.map((f) => f.id).toList(),
      );
      expect(first.facts.every((f) => f.id.startsWith('ev-m5-')), isTrue);
    });
  });
}

AarIncomingMatchupBundle _bundle(
  ({
    ParsedCombatEncounter encounter,
    EsiKillmailDetail detail,
    AttackerCorrelation correlation,
    CombatEnrichment enrichment,
  })
  scenario, {
  AarFitDerivation? fit,
}) {
  final result = IncomingDamageAllocator.allocate(
    encounter: scenario.encounter,
    weapons: matchupWeaponTable(),
    sdeContentKey: matchupSdeContentKey,
  );
  final allocation = (result as IncomingAllocationReady).allocation;
  return AarAttackerMatchupDeriver.derive(
    allocation: allocation,
    correlation: matchupCorrelationContext(
      encounter: scenario.encounter,
      detail: scenario.detail,
      correlation: scenario.correlation,
    ),
    pilotFit: fit ?? fixtureAPilotFit(),
    pilotFitEvidence: fixtureAPilotFitEvidence(),
    pilotFitKey: 'fit-a',
    dependencyLimitations: const [],
  );
}

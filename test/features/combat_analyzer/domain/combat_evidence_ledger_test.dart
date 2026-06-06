import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('CombatEvidenceLedger', () {
    test('round trips evidence facts and grouped unknowns', () {
      final ledger = CombatEvidenceLedger(
        facts: [
          CombatEvidenceFact(
            id: 'ev-killmail-victim',
            label: 'Victim ship',
            value: 'Condor',
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            limitations: const ['Attacker fit is not exposed by killmail.'],
          ),
        ],
        unknowns: [
          AarUnknown(
            category: AarUnknownCategory.pilotFit,
            label: 'Pilot fit',
            detail: 'No confirmed historical fit was supplied.',
          ),
        ],
      );

      final decoded = CombatEvidenceLedger.fromJson(ledger.toJson());

      expect(decoded.facts.single.id, 'ev-killmail-victim');
      expect(decoded.facts.single.source, EvidenceSource.killmail);
      expect(decoded.facts.single.confidence, EvidenceConfidence.proven);
      expect(decoded.unknowns.single.category, AarUnknownCategory.pilotFit);
    });

    test('combat enrichment prompt includes ledger and pilot fit evidence', () {
      final enrichment = CombatEnrichment(
        parsedEncounterId: 'encounter-1',
        status: CombatEnrichmentStatus.logOnly,
        source: CombatEnrichmentSource.none,
        pilotFitEvidence: FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.confirmed,
          fitting: const Fitting(
            id: 'fit-1',
            name: 'Confirmed Rifter',
            shipTypeId: 587,
            shipName: 'Rifter',
          ),
          limitations: const ['User-confirmed manual import.'],
        ),
        evidenceLedger: const CombatEvidenceLedger(
          facts: [
            CombatEvidenceFact(
              id: 'ev-log-damage',
              label: 'Outgoing damage',
              value: '100',
              source: EvidenceSource.combatLog,
              confidence: EvidenceConfidence.proven,
            ),
          ],
        ),
      );

      final prompt = enrichment.toPromptJson();

      expect(prompt['evidenceLedger'], isA<Map<String, dynamic>>());
      expect(prompt['pilotFitEvidence'], isA<Map<String, dynamic>>());
      expect(
        (prompt['pilotFitEvidence'] as Map<String, dynamic>)['shipTypeId'],
        587,
      );
    });
  });
}

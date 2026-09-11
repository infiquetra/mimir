import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  group('Group B — dimension evaluators', () {
    group('D1 — Pilot fit', () {
      test('T2.1 D1 Complete: confirmed snapshot, derived, no unresolved', () {
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(
            enrichmentRow: enrichment(pilotFitEvidence: fitEvidence()),
            bundle: AarDerivationBundle(self: derivation()),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.complete,
          actions: const [],
        );
        expect(
          result.detail,
          startsWith('Current ship snapshot, confirmed for this fight'),
        );
      });

      test('T2.2 D1 Partial: unresolved modules', () {
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(
            enrichmentRow: enrichment(pilotFitEvidence: fitEvidence()),
            bundle: AarDerivationBundle(
              self: derivation(unresolvedTypeIds: const [99991, 99992]),
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(result.detail, contains('2 modules not in the SDE'));
      });

      test('T2.3 D1 Partial: All V skills', () {
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(
            enrichmentRow: enrichment(pilotFitEvidence: fitEvidence()),
            bundle: AarDerivationBundle(
              self: derivation(basis: AarSkillBasis.allFive),
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(result.detail, contains('skills assumed All V'));
      });

      test('T2.4 D1 Missing: no pilot fit', () {
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(enrichmentRow: enrichment(pilotFitEvidence: null)),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [
            AarEvidenceAction.useCurrentFit,
            AarEvidenceAction.importFit,
          ],
        );
        expect(result.detail, 'No pilot fit attached for this fight.');
      });

      test('T2.5 D1 Missing: derivation failed', () {
        const unknown = AarUnknown(
          category: AarUnknownCategory.pilotFit,
          label: 'Ship type not in SDE',
          detail: 'Ship type 12345 (Foo) is not in the bundled SDE.',
        );
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(
            enrichmentRow: enrichment(pilotFitEvidence: fitEvidence()),
            bundle: const AarDerivationBundle(unknowns: [unknown]),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [
            AarEvidenceAction.useCurrentFit,
            AarEvidenceAction.importFit,
          ],
        );
        expect(result.detail, unknown.detail);
      });

      test('B.5a D1 Inferred: unconfirmed snapshot', () {
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(
            enrichmentRow: enrichment(
              pilotFitEvidence: fitEvidence(
                confidence: EvidenceConfidence.reference,
                evidenceTime: DateTime.utc(2026, 9, 10, 18),
              ),
            ),
            bundle: AarDerivationBundle(self: derivation()),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.inferred,
          actions: const [
            AarEvidenceAction.useCurrentFit,
            AarEvidenceAction.importFit,
          ],
        );
        expect(result.detail, contains('2026-09-10 18:00 UTC'));
        expect(result.detail, contains('not confirmed'));
      });

      test('B.5b D1 Complete: own-loss killmail is the pilot fit (C4)', () {
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(
            encounter: encounterWith(characterId: 42),
            enrichmentRow: enrichment(
              victimCharacterId: 42,
              victimFitEvidence: fitEvidence(
                role: FitEvidenceRole.victim,
                source: EvidenceSource.killmail,
                confidence: EvidenceConfidence.proven,
              ),
            ),
            bundle: AarDerivationBundle(
              self: derivation(fitSource: EvidenceSource.killmail),
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.complete,
          actions: const [],
        );
        expect(result.detail, startsWith('Own loss killmail #1234567'));
      });

      test('B.5c D1 Missing when enrichment is null', () {
        final result = AarEvidenceScorer.pilotFit(
          aarInputs(hasEnrichment: false),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [
            AarEvidenceAction.useCurrentFit,
            AarEvidenceAction.importFit,
          ],
        );
      });
    });

    group('D2 — Combat log', () {
      test('T2.6 D2 Complete: 25 damage events, both directions', () {
        final result = AarEvidenceScorer.combatLog(
          encounterWith(incomingEvents: 13, outgoingEvents: 12),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.complete,
          actions: const [],
        );
        expect(result.detail, '25 damage events over 96s, both directions');
      });

      test('T2.7 D2 Partial: outgoing only', () {
        final result = AarEvidenceScorer.combatLog(
          encounterWith(incomingEvents: 0, outgoingEvents: 25),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(result.detail, endsWith('outgoing only'));
      });

      test('T2.8 D2 Partial: 8 damage events', () {
        final result = AarEvidenceScorer.combatLog(
          encounterWith(incomingEvents: 4, outgoingEvents: 4),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(result.detail, contains('(fewer than 20)'));
      });
    });

    group('D3 — Opponent identity', () {
      test('T2.9 D3 Complete: matched 0.92', () {
        final result = AarEvidenceScorer.opponentIdentity(aarInputs());
        _expectDimension(
          result,
          status: AarEvidenceStatus.complete,
          actions: const [],
        );
        expect(
          result.detail,
          'Killmail #1234567 matched (92%), victim Target Pilot',
        );
      });

      test('T2.10 D3 Partial: matched 0.55', () {
        final result = AarEvidenceScorer.opponentIdentity(
          aarInputs(enrichmentRow: enrichment(matchConfidence: 0.55)),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(
          result.detail,
          startsWith('Killmail #1234567 matched at low confidence (55%)'),
        );
      });

      test('T2.11 D3 Partial: ambiguous', () {
        final result = AarEvidenceScorer.opponentIdentity(
          aarInputs(
            enrichmentRow: enrichment(
              status: CombatEnrichmentStatus.ambiguous,
              killmailId: null,
              victimCharacterId: null,
              matchReason: 'Two killmails within 60s.',
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(
          result.detail,
          'Ambiguous killmail match: Two killmails within 60s.',
        );
      });

      test('T2.12 D3 Missing: needsReauth', () {
        final result = AarEvidenceScorer.opponentIdentity(
          aarInputs(
            enrichmentRow: enrichment(
              status: CombatEnrichmentStatus.needsReauth,
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [AarEvidenceAction.reauthorize],
        );
      });

      test('T2.13 D3 Unavailable: logOnly after a completed search', () {
        const reason = 'No ESI or zKill killmail matched this encounter.';
        final result = AarEvidenceScorer.opponentIdentity(
          aarInputs(enrichmentRow: _searchedNoKillmail(reason)),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.unavailable,
          actions: const [],
        );
        expect(result.detail, reason);
      });

      test('B.13a D3 Missing: not searched (null enrichment)', () {
        final result = AarEvidenceScorer.opponentIdentity(
          aarInputs(
            encounter: encounterWith(characterId: 42),
            hasEnrichment: false,
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [AarEvidenceAction.searchKillmails],
        );
        expect(
          result.detail,
          'Killmail search has not run for this encounter.',
        );
      });

      test('B.13b D3 Missing: logOnly row written before any search', () {
        final result = AarEvidenceScorer.opponentIdentity(
          aarInputs(
            enrichmentRow: enrichment(
              status: CombatEnrichmentStatus.logOnly,
              killmailSearchCompleted: false,
              matchReason: CombatEnrichment.uncachedMatchReason,
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [AarEvidenceAction.searchKillmails],
        );
      });

      test('B.13c D3 Unavailable: no authenticated character', () {
        final result = AarEvidenceScorer.opponentIdentity(
          aarInputs(
            encounter: encounterWith(characterId: null),
            hasEnrichment: false,
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.unavailable,
          actions: const [],
        );
      });
    });

    group('D4 — Opponent fit', () {
      test('T2.14 D4 Inferred: opponent derived from killmail', () {
        final result = AarEvidenceScorer.opponentFit(s1Inputs());
        _expectDimension(
          result,
          status: AarEvidenceStatus.inferred,
          actions: const [],
        );
        expect(
          result.detail,
          startsWith(
            'Killmail #1234567 shows destroyed and dropped modules only',
          ),
        );
      });

      test('T2.15 D4 Missing: identity not searched', () {
        final result = AarEvidenceScorer.opponentFit(
          aarInputs(hasEnrichment: false),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [AarEvidenceAction.searchKillmails],
        );
      });

      test('T2.16 D4 Unavailable: D3 Unavailable', () {
        final result = AarEvidenceScorer.opponentFit(
          aarInputs(
            enrichmentRow: _searchedNoKillmail(
              'No ESI or zKill killmail matched this encounter.',
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.unavailable,
          actions: const [],
        );
        expect(
          result.detail,
          'No opponent identified; there is no fit to derive.',
        );
      });

      test('B.16a D4 Unavailable: own loss (attacker fit not exposed)', () {
        final result = AarEvidenceScorer.opponentFit(
          aarInputs(
            encounter: encounterWith(characterId: 42),
            enrichmentRow: enrichment(
              victimCharacterId: 42,
              victimFitEvidence: fitEvidence(
                role: FitEvidenceRole.victim,
                source: EvidenceSource.killmail,
                confidence: EvidenceConfidence.proven,
              ),
            ),
            bundle: AarDerivationBundle(
              self: derivation(fitSource: EvidenceSource.killmail),
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.unavailable,
          actions: const [],
        );
        expect(
          result.detail,
          startsWith('Own loss killmail #1234567: attacker fittings'),
        );
      });

      test('B.16b D4 Partial: opponent ship not in SDE', () {
        const unknown = AarUnknown(
          category: AarUnknownCategory.opponentFit,
          label: 'Ship type not in SDE',
          detail: 'Ship type 12345 (Foo) is not in the bundled SDE.',
        );
        final result = AarEvidenceScorer.opponentFit(
          aarInputs(
            enrichmentRow: enrichment(
              victimFitEvidence: fitEvidence(
                role: FitEvidenceRole.victim,
                source: EvidenceSource.killmail,
                confidence: EvidenceConfidence.proven,
              ),
            ),
            bundle: const AarDerivationBundle(unknowns: [unknown]),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(result.detail, unknown.detail);
      });

      test('B.16c D4 Unavailable: ambiguous', () {
        final result = AarEvidenceScorer.opponentFit(
          aarInputs(
            enrichmentRow: enrichment(
              status: CombatEnrichmentStatus.ambiguous,
              killmailId: null,
              victimCharacterId: null,
              matchReason: 'Two killmails within 60s.',
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.unavailable,
          actions: const [],
        );
      });

      test('B.16d D4 Missing: needsReauth', () {
        final result = AarEvidenceScorer.opponentFit(
          aarInputs(
            enrichmentRow: enrichment(
              status: CombatEnrichmentStatus.needsReauth,
            ),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.missing,
          actions: const [AarEvidenceAction.reauthorize],
        );
      });
    });

    group('D5 — Damage profile', () {
      test('T2.17 D5 Complete: no unknown weapons, all sdeExact', () {
        final result = AarEvidenceScorer.damageProfile(
          aarInputs(
            encounter: encounterWith(incomingEvents: 12, outgoingEvents: 12),
            incoming: profile(profiled: 1200, resolved: const ['Railgun']),
            outgoing: profile(profiled: 1200, resolved: const ['Hobgoblin II']),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.complete,
          actions: const [],
        );
        expect(
          result.detail,
          'All 2 weapons resolved; 100% of damage typed from SDE attributes.',
        );
      });

      test('T2.18 D5 Partial: 2 of 14 unresolved, 85% typed', () {
        final result = AarEvidenceScorer.damageProfile(
          aarInputs(
            encounter: encounterWith(incomingEvents: 10, outgoingEvents: 10),
            incoming: profile(
              profiled: 700,
              resolved: kS1IncomingResolved,
              unknown: kS1UnknownWeapons,
            ),
            outgoing: profile(profiled: 1000, resolved: kS1OutgoingResolved),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.partial,
          actions: const [],
        );
        expect(
          result.detail,
          '2 of 14 weapons unresolved (Civilian Gatling Railgun, Unknown); 85% of damage typed.',
        );
      });

      test('T2.19 D5 Inferred: 60% typed', () {
        final result = AarEvidenceScorer.damageProfile(
          aarInputs(
            encounter: encounterWith(incomingEvents: 10, outgoingEvents: 10),
            incoming: profile(
              profiled: 200,
              resolved: const ['Railgun'],
              unknown: const ['Unknown'],
            ),
            outgoing: profile(profiled: 1000, resolved: const ['Railgun']),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.inferred,
          actions: const [],
        );
      });

      test('T2.20 D5 Unavailable: nothing typed', () {
        final result = AarEvidenceScorer.damageProfile(
          aarInputs(
            incoming: profile(
              profiled: 0,
              resolved: const [],
              unknown: const ['Unknown'],
            ),
            outgoing: profile(
              profiled: 0,
              resolved: const [],
              unknown: const ['Unknown'],
            ),
          ),
        );
        expect(result.status, AarEvidenceStatus.unavailable);
        expect(
          aarInputs(
            incoming: profile(
              profiled: 0,
              resolved: const [],
              unknown: const ['Unknown'],
            ),
          ).incoming.hasKnownDamageTypes,
          isFalse,
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.unavailable,
          actions: const [],
        );
        expect(
          result.detail,
          startsWith('None of the 1 weapons in this log resolve'),
        );
      });

      test('B.20a D5 Unavailable: no damage in either direction', () {
        final seed = encounterWith(incomingEvents: 0, outgoingEvents: 1);
        final encounter = seed.copyWith(
          events: [
            CombatEvent(
              id: 'e1',
              timestamp: seed.startTime,
              second: 0,
              direction: CombatEventDirection.outgoing,
              kind: CombatEventKind.miss,
              rawLine: 'Your Railgun misses Enemy completely',
              targetName: 'Enemy',
              weaponName: 'Railgun',
              hitQuality: 'Misses',
            ),
          ],
          aggregates: const CombatAggregates(
            totalDamageDealt: 0,
            totalDamageReceived: 0,
            cumulativeDamage: [
              CombatTimelinePoint(second: 0, outgoing: 0, incoming: 0),
            ],
            damageByTarget: {},
            damageByWeapon: {},
            incomingBySource: {},
            hitQualityCounts: {},
            outgoingHitQualityCounts: {},
            incomingHitQualityCounts: {},
            outgoingHitCount: 0,
            incomingHitCount: 0,
            peakOutgoingHit: 0,
            peakIncomingHit: 0,
            averageOutgoingHit: 0,
            averageIncomingHit: 0,
            missCount: 1,
            idleGapCount: 0,
            ewarEventCount: 0,
          ),
        );
        final result = AarEvidenceScorer.damageProfile(
          aarInputs(encounter: encounter),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.unavailable,
          actions: const [],
        );
        expect(result.detail, 'No damage recorded in either direction.');
      });

      test('B.20b D5 skips a direction with zero damage', () {
        final result = AarEvidenceScorer.damageProfile(
          aarInputs(
            encounter: encounterWith(incomingEvents: 10, outgoingEvents: 0),
            incoming: profile(profiled: 1000),
            outgoing: profile(profiled: 0, resolved: const []),
          ),
        );
        _expectDimension(
          result,
          status: AarEvidenceStatus.complete,
          actions: const [],
        );
      });
    });

    test('T2.21 every status carries non-empty detail', () {
      for (final inputs in _invariantInputs()) {
        for (final result in _evaluateAll(inputs)) {
          expect(
            result.detail.trim(),
            isNotEmpty,
            reason: '${result.dimension.name} detail was empty',
          );
        }
      }
    });

    test('T2.22 invariant I1: Missing ⇔ actionable', () {
      for (final inputs in _invariantInputs()) {
        for (final result in _evaluateAll(inputs)) {
          expect(
            result.status == AarEvidenceStatus.missing,
            result.actions.isNotEmpty,
            reason:
                '${result.dimension.name} status=${result.status.name} '
                'actions=${result.actions}',
          );
          if (result.status == AarEvidenceStatus.unavailable) {
            expect(result.actions, isEmpty);
          }
        }
      }
    });

    test('B.23 no dimension reads another\'s status', () {
      final fit = fitEvidence();
      final self = AarDerivationBundle(self: derivation());
      final matched = aarInputs(
        enrichmentRow: enrichment(
          status: CombatEnrichmentStatus.killmailMatched,
          pilotFitEvidence: fit,
        ),
        bundle: self,
      );
      final reauth = aarInputs(
        enrichmentRow: enrichment(
          status: CombatEnrichmentStatus.needsReauth,
          pilotFitEvidence: fit,
        ),
        bundle: self,
      );
      final matchedFit = AarEvidenceScorer.pilotFit(matched);
      final reauthFit = AarEvidenceScorer.pilotFit(reauth);
      expect(matchedFit.status, reauthFit.status);
      expect(matchedFit.detail, reauthFit.detail);
      expect(matchedFit.actions, reauthFit.actions);

      final s1 = s1Inputs();
      final emptyBundle = aarInputs(
        encounter: s1.encounter,
        enrichmentRow: s1.enrichment,
        bundle: const AarDerivationBundle.empty(),
        incoming: s1.incoming,
        outgoing: s1.outgoing,
      );
      final withS1Bundle = AarEvidenceScorer.damageProfile(s1);
      final withEmptyBundle = AarEvidenceScorer.damageProfile(emptyBundle);
      expect(withS1Bundle.status, withEmptyBundle.status);
      expect(withS1Bundle.detail, withEmptyBundle.detail);
      expect(withS1Bundle.actions, withEmptyBundle.actions);
    });
  });
}

CombatEnrichment _searchedNoKillmail(String reason) {
  return enrichment(
    status: CombatEnrichmentStatus.logOnly,
    source: CombatEnrichmentSource.none,
    killmailId: null,
    victimCharacterId: null,
    victimName: null,
    killmailSearchCompleted: true,
    matchReason: reason,
  );
}

void _expectDimension(
  AarEvidenceDimensionResult result, {
  required AarEvidenceStatus status,
  required List<AarEvidenceAction> actions,
}) {
  expect(result.status, status);
  expect(result.detail.trim(), isNotEmpty);
  expect(result.actions, actions);
}

List<AarEvidenceInputs> _invariantInputs() {
  return [
    s1Inputs(),
    s1bInputs(),
    s6Inputs(),
    s6Inputs(withPilotFit: false),
    s7Inputs(),
    aarInputs(hasEnrichment: false),
  ];
}

List<AarEvidenceDimensionResult> _evaluateAll(AarEvidenceInputs inputs) {
  return [
    AarEvidenceScorer.pilotFit(inputs),
    AarEvidenceScorer.combatLog(inputs.encounter),
    AarEvidenceScorer.opponentIdentity(inputs),
    AarEvidenceScorer.opponentFit(inputs),
    AarEvidenceScorer.damageProfile(inputs),
  ];
}

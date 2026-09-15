/// W0 RED contracts for AAR fit-comparison snapshots, knowledge, and
/// selection. Compile stubs load so these are assertion failures, not
/// missing-import errors.
///
/// Expected RED until GREEN implements design §2 / §9.1:
/// - Isolation: snapshot stores caller Fitting/knowledge/source lists
///   by reference (Freezed getters wrap, they do not copy).
/// - Fingerprints: naive `jsonEncode(toJson())` includes snapshotId,
///   display name, timestamps, and list order; omits knowledge; does
///   not split calculation vs content keys.
/// - Knowledge policies: capture stays unknown/order-only, legacy
///   evidence/saved/killmail/candidate adapters claim
///   `recordedComplete`, EFT claims recorded positions.
/// - D16: `fromJson` fabricates complete knowledge; generation parser
///   synthesizes a type-id-0 mock when the report key is absent.
/// - P05: killmail-first selector, no own-loss collapse, unknown
///   identity still falls back, reference promoted as fight fit.
/// Harness F1–F5 SDE mapping, injected clock, and production
/// composition pin-omission start green.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_comparison.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_proposal.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_snapshot.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_comparison_fixtures.dart';
import '../fixtures/fit_evidence_harness.dart';

void main() {
  group('W0 deep-copy isolation', () {
    test(
      'mutating caller module/drone/item lists does not change snapshot',
      () {
        final highSlots = <FittedModule>[AarComparisonFixtures.moduleA()];
        final medSlots = <FittedModule>[AarComparisonFixtures.moduleB()];
        final drones = <DroneGroup>[AarComparisonFixtures.dronesD()];
        final cargo = <CargoItem>[AarComparisonFixtures.ammo()];
        final fighters = <FighterGroup>[
          const FighterGroup(typeId: 1, typeName: 'F', quantity: 1),
        ];
        final fitting = Fitting(
          id: 'iso',
          name: 'iso',
          shipTypeId: kCmpHullH,
          shipName: 'Cmp H',
          highSlots: highSlots,
          medSlots: medSlots,
          drones: drones,
          cargo: cargo,
          fighters: fighters,
        );
        final snapshot = AarFitSnapshot(
          snapshotId: 'iso',
          encounterId: 'enc',
          fitting: fitting,
          source: AarFitSource.comparisonCapture,
          subject: const AarFitSubject(relation: AarFitSubjectRelation.pilot),
        );

        highSlots.add(AarComparisonFixtures.moduleA(slotIndex: 1));
        medSlots.add(AarComparisonFixtures.moduleC());
        drones.add(AarComparisonFixtures.dronesD(quantity: 2, inBay: 2));
        cargo.add(AarComparisonFixtures.paste());
        fighters.add(
          const FighterGroup(typeId: 2, typeName: 'F2', quantity: 2),
        );

        expect(snapshot.fitting.highSlots, hasLength(1));
        expect(snapshot.fitting.medSlots, hasLength(1));
        expect(snapshot.fitting.drones, hasLength(1));
        expect(snapshot.fitting.cargo, hasLength(1));
        expect(snapshot.fitting.fighters, hasLength(1));
      },
    );

    test('mutating knowledge and source lists does not change snapshot', () {
      final emptySlots = <int>[1];
      final unplaced = <UnresolvedOccupant>[
        const UnresolvedOccupant(sourceEntryKey: 'u1', label: 'one'),
      ];
      final occurrences = <FitOccurrenceKnowledge>[
        const FitOccurrenceKnowledge(occurrenceKey: 'high:0'),
      ];
      final groups = <FitInventoryGroup, FitGroupKnowledge>{
        FitInventoryGroup.high: FitGroupKnowledge(
          recordedEmptySlots: emptySlots,
          unresolvedOccupied: unplaced,
        ),
      };
      final sourceItemIds = <int>[10, 11];
      final limitations = <String>['lim-a'];
      final knowledge = FitInventoryKnowledge(
        groups: groups,
        unplacedEntries: unplaced,
        occurrences: occurrences,
      );
      final snapshot = AarFitSnapshot(
        snapshotId: 'iso-k',
        encounterId: 'enc',
        fitting: AarComparisonFixtures.hullOnly(),
        source: AarFitSource.comparisonCapture,
        subject: const AarFitSubject(relation: AarFitSubjectRelation.pilot),
        knowledge: knowledge,
        sourceItemIds: sourceItemIds,
        limitations: limitations,
      );

      emptySlots.add(2);
      unplaced.add(
        const UnresolvedOccupant(sourceEntryKey: 'u2', label: 'two'),
      );
      occurrences.add(const FitOccurrenceKnowledge(occurrenceKey: 'high:1'));
      groups[FitInventoryGroup.mid] = const FitGroupKnowledge();
      sourceItemIds.add(12);
      limitations.add('lim-b');

      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).recordedEmptySlots,
        [1],
      );
      expect(snapshot.knowledge.unplacedEntries, hasLength(1));
      expect(snapshot.knowledge.occurrences, hasLength(1));
      expect(
        snapshot.knowledge.groups.containsKey(FitInventoryGroup.mid),
        isFalse,
      );
      expect(snapshot.sourceItemIds, [10, 11]);
      expect(snapshot.limitations, ['lim-a']);
    });
  });

  group('W0 fingerprint stability', () {
    AarFitSnapshot base({
      String id = 'fp',
      String name = 'F1 Baseline',
      DateTime? recordedAt,
      Fitting? fitting,
      AarFitSubject? subject,
      FitInventoryKnowledge? knowledge,
    }) {
      return AarFitSnapshot(
        snapshotId: id,
        encounterId: 'enc-fp',
        fitting:
            fitting ?? AarComparisonFixtures.f1Baseline().copyWith(name: name),
        source: AarFitSource.comparisonCapture,
        subject:
            subject ??
            const AarFitSubject(
              characterId: 42,
              relation: AarFitSubjectRelation.pilot,
            ),
        recordedAt: recordedAt ?? DateTime.utc(2026, 9, 15, 12),
        knowledge: knowledge ?? AarComparisonFixtures.completeRecorded(),
      );
    }

    test(
      'permutations, renames, timestamps and ids share contentFingerprint',
      () {
        final canonical = base();
        final renamed = base(name: 'Display renamed');
        final retimed = base(recordedAt: DateTime.utc(2026, 9, 16, 1));
        final retagged = base(id: 'other-uuid');
        final permutedHighs = base(
          fitting: AarComparisonFixtures.f1Baseline().copyWith(
            name: 'F1 Baseline',
            highSlots: [
              AarComparisonFixtures.moduleA(slotIndex: 1),
              AarComparisonFixtures.moduleA(slotIndex: 0),
            ],
          ),
        );

        expect(renamed.contentFingerprint, canonical.contentFingerprint);
        expect(retimed.contentFingerprint, canonical.contentFingerprint);
        expect(retagged.contentFingerprint, canonical.contentFingerprint);
        expect(permutedHighs.contentFingerprint, canonical.contentFingerprint);
      },
    );

    test(
      'quantity, charge, state, knowledge and subject change contentFingerprint',
      () {
        final canonical = base();
        final quantity = base(
          fitting: AarComparisonFixtures.f1Baseline().copyWith(
            drones: [AarComparisonFixtures.dronesD(quantity: 3, inBay: 3)],
          ),
        );
        final charge = base(
          fitting: AarComparisonFixtures.f1Baseline().copyWith(
            highSlots: [
              AarComparisonFixtures.moduleA(
                chargeTypeId: kCmpChargeY,
                chargeName: 'Cmp Y',
              ),
              AarComparisonFixtures.moduleA(slotIndex: 1),
            ],
          ),
        );
        final state = base(
          fitting: AarComparisonFixtures.f1Baseline().copyWith(
            highSlots: [
              AarComparisonFixtures.moduleA(state: ModuleState.offline),
              AarComparisonFixtures.moduleA(slotIndex: 1),
            ],
          ),
        );
        final knowledge = base(
          knowledge: FitInventoryKnowledge(
            groups: {
              FitInventoryGroup.high: const FitGroupKnowledge(
                completeness: InventoryCompleteness.partial,
                positions: SlotPositionMeaning.recorded,
              ),
            },
            occurrences: const [
              FitOccurrenceKnowledge(
                occurrenceKey: 'high:0',
                charge: ChargeKnowledge.recordedIdentity,
              ),
            ],
          ),
        );
        final subject = base(
          subject: const AarFitSubject(
            characterId: 99,
            relation: AarFitSubjectRelation.pilot,
          ),
        );

        expect(
          quantity.contentFingerprint,
          isNot(canonical.contentFingerprint),
        );
        expect(charge.contentFingerprint, isNot(canonical.contentFingerprint));
        expect(state.contentFingerprint, isNot(canonical.contentFingerprint));
        expect(
          knowledge.contentFingerprint,
          isNot(canonical.contentFingerprint),
        );
        expect(subject.contentFingerprint, isNot(canonical.contentFingerprint));
      },
    );

    test('calculationFingerprint ignores subject and follows equipment', () {
      final equipment = base();
      final otherPilot = base(
        subject: const AarFitSubject(
          characterId: 99,
          relation: AarFitSubjectRelation.pilot,
        ),
      );
      final otherCharge = base(
        fitting: AarComparisonFixtures.f1Baseline().copyWith(
          highSlots: [
            AarComparisonFixtures.moduleA(
              chargeTypeId: kCmpChargeY,
              chargeName: 'Cmp Y',
            ),
            AarComparisonFixtures.moduleA(slotIndex: 1),
          ],
        ),
      );

      expect(
        otherPilot.calculationFingerprint,
        equipment.calculationFingerprint,
      );
      expect(
        otherCharge.calculationFingerprint,
        isNot(equipment.calculationFingerprint),
      );
      expect(
        otherPilot.contentFingerprint,
        isNot(equipment.contentFingerprint),
      );
    });
  });

  group('W0 knowledge policies per source', () {
    test('new ESI capture records physical indices and assumes state', () {
      final capture = AarFitSnapshot.fromCurrentCapture(
        encounterId: 'enc',
        fitting: AarComparisonFixtures.f1Baseline(),
        characterId: 42,
        recordedAt: DateTime.utc(2026, 9, 15, 12),
        sourceItemIds: [100, 101],
      );

      expect(
        capture.knowledge.group(FitInventoryGroup.high).positions,
        SlotPositionMeaning.recorded,
      );
      expect(
        capture.knowledge.group(FitInventoryGroup.high).completeness,
        InventoryCompleteness.recordedComplete,
      );
      expect(capture.knowledge.moduleState, StateKnowledge.assumed);
    });

    test('legacy FitEvidence without inventoryKnowledge stays unknown', () {
      final snapshot = AarFitSnapshot.fromFitEvidence(
        encounterId: 'enc',
        evidence: FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.confirmed,
          fitting: AarComparisonFixtures.hullOnly(),
        ),
      );

      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).completeness,
        InventoryCompleteness.unknown,
      );
      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).positions,
        isNot(SlotPositionMeaning.recorded),
      );
    });

    test('EFT import keeps order-only positions (D03)', () {
      final compact = Fitting(
        id: 'eft',
        name: 'EFT compact',
        shipTypeId: kCmpHullH,
        shipName: 'Cmp H',
        highSlots: [
          AarComparisonFixtures.moduleA(slotIndex: 0),
          AarComparisonFixtures.moduleA(slotIndex: 1),
        ],
      );
      final snapshot = AarFitSnapshot.fromEftImport(
        encounterId: 'enc',
        fitting: compact,
      );

      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).positions,
        SlotPositionMeaning.orderOnly,
      );
    });

    test('saved fitting empty JSON lists do not prove completeness', () {
      final fitting = Fitting.fromJson({
        'id': 'saved',
        'name': 'Saved',
        'shipTypeId': kCmpHullH,
        'shipName': 'Cmp H',
      });
      final snapshot = AarFitSnapshot.fromSavedFitting(
        encounterId: 'enc',
        fitting: fitting,
        savedFittingId: 'sf-1',
      );

      expect(fitting.highSlots, isEmpty);
      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).completeness,
        isNot(InventoryCompleteness.recordedComplete),
      );
    });

    test('killmail without items key stays unknown', () {
      final snapshot = AarFitSnapshot.fromKillmailVictim(
        encounterId: 'enc',
        fitting: AarComparisonFixtures.hullOnly(),
        killmailId: 777001,
        victimCharacterId: 99,
        itemsKeyPresent: false,
      );

      expect(snapshot.subject.identityKnown, isTrue);
      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).completeness,
        InventoryCompleteness.unknown,
      );
    });

    test('structured candidate omitted groups are not empty-complete', () {
      final raw = {
        'label': 'Armor alternative',
        'target': {
          'shipTypeId': kCmpHullH,
          'shipName': 'Cmp H',
          'groups': {
            'high': {'status': 'complete', 'items': <Map<String, dynamic>>[]},
          },
        },
      };
      final fitting = Fitting.fromJson({
        'id': 'cand',
        'name': 'Armor alternative',
        'shipTypeId': kCmpHullH,
        'shipName': 'Cmp H',
      });
      final snapshot = AarFitSnapshot.fromStructuredCandidate(
        encounterId: 'enc',
        fitting: fitting,
        raw: raw,
      );
      final proposal = AarFitProposal.fromRaw(
        raw: raw,
        encounterId: 'enc',
        proposalId: 'alternative-a',
        baselineSnapshotId: 'f-old',
        baselineFingerprint: 'fp',
      );

      expect(
        snapshot.knowledge.group(FitInventoryGroup.high).completeness,
        InventoryCompleteness.recordedComplete,
      );
      expect(
        snapshot.knowledge.group(FitInventoryGroup.mid).completeness,
        isNot(InventoryCompleteness.recordedComplete),
      );
      expect(proposal.status, isNot(AarProposalValidationStatus.validated));
    });
  });

  group('W0 D16 legacy JSON tolerance', () {
    test(
      'missing comparison keys deserialize without fabricating inventory',
      () {
        final decoded = AarFitSnapshot.fromJson({'encounterId': 'legacy-enc'});

        expect(decoded.encounterId, 'legacy-enc');
        expect(decoded.fitting.allModules, isEmpty);
        expect(decoded.fitting.drones, isEmpty);
        expect(decoded.fitting.cargo, isEmpty);
        expect(decoded.recordedAt, isNull);
        expect(decoded.sourceRef, isNull);
        expect(
          decoded.knowledge.group(FitInventoryGroup.high).completeness,
          InventoryCompleteness.unknown,
        );
      },
    );

    test('knowledge round-trips and name changes do not rewrite equipment', () {
      final original = AarFitSnapshot(
        snapshotId: 'rt',
        encounterId: 'enc',
        fitting: AarComparisonFixtures.f1Baseline(),
        source: AarFitSource.comparisonCapture,
        subject: const AarFitSubject(
          characterId: 42,
          relation: AarFitSubjectRelation.pilot,
        ),
        knowledge: FitInventoryKnowledge(
          groups: {
            FitInventoryGroup.mid: const FitGroupKnowledge(
              completeness: InventoryCompleteness.partial,
              positions: SlotPositionMeaning.recorded,
            ),
          },
        ),
      );
      final encoded =
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final roundTrip = AarFitSnapshot.fromJson(encoded);
      final renamedJson =
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
      final fittingJson = Map<String, dynamic>.from(
        renamedJson['fitting'] as Map,
      );
      fittingJson['name'] = 'Resolved display name';
      final highs = [
        for (final module in fittingJson['highSlots'] as List)
          {
            ...Map<String, dynamic>.from(module as Map),
            'typeName': 'Resolved A',
          },
      ];
      fittingJson['highSlots'] = highs;
      renamedJson['fitting'] = fittingJson;
      final renamed = AarFitSnapshot.fromJson(renamedJson);

      expect(
        roundTrip.knowledge.group(FitInventoryGroup.mid).completeness,
        InventoryCompleteness.partial,
      );
      expect(renamed.contentFingerprint, original.contentFingerprint);
    });

    test('legacy report loads and does not fabricate generation snapshots', () {
      final legacy = {
        'summary': 'Legacy summary',
        'mistakes': 'Mistake',
        'improvements': 'Improve',
        'fits': 'Fit',
      };
      final report = CombatAarReport.fromJson(legacy);
      final generation = AarFitGenerationRecord.fromReportJson(legacy);

      expect(report.summary, 'Legacy summary');
      expect(report.mistakesText, 'Mistake');
      expect(generation, isNull);
    });
  });

  group('W0 D07 completeness distinctions', () {
    test('empty complete, unknown, and unresolved occupied stay distinct', () {
      final emptyComplete = AarFitSnapshot(
        snapshotId: 'empty',
        encounterId: 'enc',
        fitting: AarComparisonFixtures.hullOnly(),
        source: AarFitSource.comparisonCapture,
        subject: const AarFitSubject(relation: AarFitSubjectRelation.pilot),
        knowledge: FitInventoryKnowledge.recordedComplete(),
      );
      final unknownLegacy = AarFitSnapshot.fromFitEvidence(
        encounterId: 'enc',
        evidence: const FitEvidence(
          role: FitEvidenceRole.pilot,
          source: EvidenceSource.manualFitImport,
          confidence: EvidenceConfidence.unknown,
          fitting: Fitting(
            id: 'legacy',
            name: 'legacy',
            shipTypeId: kCmpHullH,
            shipName: 'Cmp H',
          ),
        ),
      );
      final unresolved = AarComparisonFixtures.f5Partial();

      expect(
        emptyComplete.knowledge.group(FitInventoryGroup.high).completeness,
        InventoryCompleteness.recordedComplete,
      );
      expect(
        unknownLegacy.knowledge.group(FitInventoryGroup.high).completeness,
        InventoryCompleteness.unknown,
      );
      expect(
        unresolved.knowledge.group(FitInventoryGroup.mid).completeness,
        InventoryCompleteness.partial,
      );
      expect(
        unresolved.knowledge.group(FitInventoryGroup.mid).unresolvedOccupied,
        isNotEmpty,
      );
      expect(
        emptyComplete.knowledge.group(FitInventoryGroup.high).completeness,
        isNot(
          unknownLegacy.knowledge.group(FitInventoryGroup.high).completeness,
        ),
      );
    });
  });

  group('W0 P05 selection, dedup and fallback', () {
    test('own-loss victim aliases the fight-fit snapshot', () {
      final victim = AarComparisonFixtures.f5VictimP();
      final sources = AarComparisonSources.resolve(
        encounterPilotId: FitEvidenceHarness.characterAId,
        identityKnown: true,
        isVictory: false,
        victim: victim,
      );

      expect(sources.fightFit?.snapshot.snapshotId, victim.snapshotId);
      expect(sources.ownLossDeduplicated, isTrue);
      expect(
        sources.visibleEntries.where(
          (entry) =>
              entry.role == AarComparisonRole.fightFit ||
              entry.role == AarComparisonRole.victim,
        ),
        hasLength(1),
      );
    });

    test('victory keeps victim Q as opponent, not fight-fit fallback', () {
      final fight = AarComparisonFixtures.f5Fold();
      final victim = AarComparisonFixtures.f5VictimQ();
      final sources = AarComparisonSources.resolve(
        encounterPilotId: FitEvidenceHarness.characterAId,
        identityKnown: true,
        isVictory: true,
        attachedPilot: fight,
        victim: victim,
      );

      expect(sources.fightFit?.snapshot.snapshotId, fight.snapshotId);
      expect(sources.victim?.snapshot.subject.characterId, 99);
      expect(sources.ownLossDeduplicated, isFalse);
      expect(sources.victim?.role, AarComparisonRole.victim);
    });

    test('unknown identity cannot own-loss fallback', () {
      final victim = AarComparisonFixtures.f5VictimUnknown();
      final sources = AarComparisonSources.resolve(
        encounterPilotId: FitEvidenceHarness.characterAId,
        identityKnown: false,
        isVictory: false,
        victim: victim,
      );

      expect(victim.subject.identityKnown, isFalse);
      expect(sources.fightFit, isNull);
      expect(sources.victim, isNotNull);
      expect(sources.requiresExplicitBaselineSelection, isTrue);
    });

    test('reference stays Pilot reference fit, not historical fallback', () {
      final reference = AarComparisonFixtures.f5Reference();
      final sources = AarComparisonSources.resolve(
        encounterPilotId: FitEvidenceHarness.characterAId,
        identityKnown: true,
        reference: reference,
      );

      expect(sources.fightFit, isNull);
      expect(sources.reference?.label, 'Pilot reference fit');
      expect(sources.reference?.isHistoricalFallback, isFalse);
      expect(sources.requiresExplicitBaselineSelection, isTrue);
      expect(sources.legacyGenerationMissing, isTrue);
    });
  });

  group('W0 F1-F5 harness fixtures', () {
    late FitEvidenceHarness harness;

    setUp(() async {
      harness = FitEvidenceHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test(
      'F1-F5 types map to distinct SDE names, categories and slots',
      () async {
        expect(kCmpChargeW < kCmpChargeX, isTrue);
        expect(kCmpChargeX < kCmpChargeY, isTrue);
        expect(kCmpChargeY < kCmpChargeZ, isTrue);

        Future<void> expectType({
          required int typeId,
          required String name,
          required int categoryId,
          int? effectId,
        }) async {
          final type = await harness.sdeDb.getType(typeId);
          expect(type, isNotNull, reason: 'missing type $typeId');
          expect(type!.typeName, name);
          final group = await harness.sdeDb.getGroup(type.groupId);
          expect(group, isNotNull);
          expect(group!.categoryId, categoryId);
          if (effectId != null) {
            final effects = await harness.sdeDb.getTypeEffects(typeId);
            expect(effects, contains(effectId));
          }
        }

        await expectType(typeId: kCmpHullH, name: 'Cmp H', categoryId: 6);
        await expectType(typeId: kCmpHullH2, name: 'Cmp H2', categoryId: 6);
        await expectType(
          typeId: kCmpModuleA,
          name: 'Cmp A',
          categoryId: 7,
          effectId: 12,
        );
        await expectType(
          typeId: kCmpModuleB,
          name: 'Cmp B',
          categoryId: 7,
          effectId: 13,
        );
        await expectType(
          typeId: kCmpModuleC,
          name: 'Cmp C',
          categoryId: 7,
          effectId: 13,
        );
        await expectType(typeId: kCmpDroneD, name: 'Cmp D', categoryId: 18);
        await expectType(typeId: kCmpAmmo, name: 'Cmp Ammo', categoryId: 8);
        await expectType(typeId: kCmpPaste, name: 'Cmp Paste', categoryId: 8);
      },
    );

    test('injected clock and deterministic skills are recorded', () async {
      await harness.seedKnownSkills(levels: const {3300: 5, 3327: 4});
      final skills = await harness.appDb.getCharacterSkills(
        FitEvidenceHarness.characterAId,
      );
      expect(skills.map((skill) => skill.skillId), containsAll([3300, 3327]));
      expect(harness.discovery.fetches, isEmpty);
      expect(harness.codex.calls, 0);
    });

    test('production composition omits service and finite stream pins', () {
      expect(
        harness.overrides().length -
            harness.productionCompositionOverrides().length,
        3,
      );
      expect(
        FitEvidenceHarness.pinnedLiveSeams,
        containsAll([
          'combatEnrichmentServiceProvider',
          'aarSdeRevisionProvider',
          'aarLocalSkillsProvider',
        ]),
      );
    });
  });

  test('injected clock is used when seeding characters', () async {
    final harness = FitEvidenceHarness();
    harness.clock = () => DateTime.utc(2030, 1, 2, 3);
    await harness.setUp();
    addTearDown(harness.tearDown);
    final character = await harness.appDb.getCharacter(
      FitEvidenceHarness.characterAId,
    );
    expect(character, isNotNull);
    expect(character!.lastUpdated.toUtc(), DateTime.utc(2030, 1, 2, 3));
  });
}

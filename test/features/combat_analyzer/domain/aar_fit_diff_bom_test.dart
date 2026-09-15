// W3 RED contracts for inventory matching and bill of materials.
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §5.2 / §7.1:
// - D01: zip-by-index treats shuffled identical inventories as modified.
// - D02: input-list order pairs X→Z instead of canonical X→W / Y→Z.
// - D03: compact EFT slotIndex is treated as physical replacement.
// - D04: order-only and different-hull pairs still emit slot replacements.
// - D05: fitted-only BOM buys A on cargo-to-slot move; hulls omitted.
// - D06: drone/fighter rows ignore deployment and count groups as 1.
// - D07: missing groups count as zero; unresolved occupants are dropped.
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_bom.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_comparison.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_inventory_diff.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_snapshot.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../fixtures/aar_comparison_fixtures.dart';

const _fighterTypeId = 91601;

void main() {
  group('W3 D01 identical and shuffled inventories', () {
    test('identical complete fits have no changes and empty Changes BOM', () {
      final baseline = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f1Baseline(),
        snapshotId: 'base',
      );
      final candidate = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f1Baseline(),
        snapshotId: 'same',
      );
      final diff = FitInventoryDiff.compare(baseline, candidate);
      final bom = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: candidate,
      );

      expect(diff.sameHull, isTrue);
      expect(diff.changes, isEmpty);
      expect(diff.noChangesLabel, 'No recorded equipment changes');
      expect(bom.requirements, isEmpty);
      expect(bom.removals, isEmpty);
    });

    test('shuffled list order does not create changes', () {
      final baselineFit = Fitting(
        id: 'base',
        name: 'base',
        shipTypeId: kCmpHullH,
        shipName: 'Cmp H',
        highSlots: [
          AarComparisonFixtures.moduleA(
            slotIndex: 0,
            chargeTypeId: kCmpChargeX,
          ),
          AarComparisonFixtures.moduleA(
            slotIndex: 1,
            chargeTypeId: kCmpChargeY,
            chargeName: 'Cmp Y',
          ),
        ],
        cargo: [AarComparisonFixtures.ammo(), AarComparisonFixtures.paste()],
      );
      final shuffledFit = baselineFit.copyWith(
        highSlots: [
          AarComparisonFixtures.moduleA(
            slotIndex: 1,
            chargeTypeId: kCmpChargeY,
            chargeName: 'Cmp Y',
          ),
          AarComparisonFixtures.moduleA(
            slotIndex: 0,
            chargeTypeId: kCmpChargeX,
          ),
        ],
        cargo: [AarComparisonFixtures.paste(), AarComparisonFixtures.ammo()],
      );
      final baseline = AarComparisonFixtures.snapshotOf(
        baselineFit,
        snapshotId: 'base',
      );
      final shuffled = AarComparisonFixtures.snapshotOf(
        shuffledFit,
        snapshotId: 'shuf',
      );
      final diff = FitInventoryDiff.compare(baseline, shuffled);
      final bom = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: shuffled,
      );

      expect(diff.changes, isEmpty, reason: 'exact matches ignore list order');
      expect(bom.requirements, isEmpty);
      expect(bom.removals, isEmpty);
    });
  });

  group('W3 D02 F1 duplicates and canonical tie pairs', () {
    test(
      'F1 recorded mids produce expected module, drone and cargo deltas',
      () {
        final baseline = AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Baseline(),
          snapshotId: 'f1-b',
        );
        final target = AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Target(),
          snapshotId: 'f1-t',
        );
        final diff = FitInventoryDiff.compare(baseline, target);
        final highs = diff.group(FitInventoryGroup.high).rows;
        final mids = diff.group(FitInventoryGroup.mid).rows;

        expect(
          highs.where((row) => row.kind == FitChangeKind.unchanged),
          hasLength(1),
        );
        expect(
          highs.where((row) => row.kind == FitChangeKind.modified),
          hasLength(1),
        );
        final modified = highs.singleWhere(
          (row) => row.kind == FitChangeKind.modified,
        );
        expect(modified.beforeChargeTypeId, kCmpChargeX);
        expect(modified.afterChargeTypeId, kCmpChargeY);
        expect(modified.beforeState, ModuleState.active);
        expect(modified.afterState, ModuleState.offline);
        expect(modified.chargeQuantityUnknown, isTrue);

        expect(
          mids.where((row) => row.kind == FitChangeKind.replaced),
          hasLength(1),
        );
        expect(mids.single.beforeTypeId, kCmpModuleB);
        expect(mids.single.afterTypeId, kCmpModuleC);

        final drones = diff.group(FitInventoryGroup.drones).rows;
        expect(
          drones.where((row) => row.kind == FitChangeKind.removed),
          isNotEmpty,
        );
        expect(
          drones
              .where((row) => row.kind == FitChangeKind.removed)
              .single
              .quantity,
          2,
        );

        final cargo = diff.group(FitInventoryGroup.cargo).rows;
        expect(
          cargo.where(
            (row) =>
                row.kind == FitChangeKind.modified &&
                row.afterTypeId == kCmpAmmo,
          ),
          isNotEmpty,
        );
        expect(
          cargo.where(
            (row) =>
                row.kind == FitChangeKind.added && row.afterTypeId == kCmpPaste,
          ),
          isNotEmpty,
        );

        final bom = FitBillOfMaterials.fromSnapshots(
          baseline: baseline,
          target: target,
        );
        expect(bom.requirement(kCmpModuleC)?.requiredCount, 1);
        expect(bom.requirement(kCmpAmmo)?.requiredCount, 50);
        expect(bom.requirement(kCmpPaste)?.requiredCount, 20);
        expect(bom.requirement(kCmpModuleA), isNull);
        expect(bom.removal(kCmpModuleB)?.requiredCount, 1);
        expect(bom.removal(kCmpDroneD)?.requiredCount, 2);
        expect(bom.unquantifiedCharges, contains(kCmpChargeY));
      },
    );

    test('F1 tie variant pairs X→W and Y→Z under every permutation', () {
      const baselineOrders = [
        [0, 1],
        [1, 0],
      ];
      const targetOrders = [
        [0, 1],
        [1, 0],
      ];
      for (final baselineOrder in baselineOrders) {
        for (final targetOrder in targetOrders) {
          final diff = FitInventoryDiff.compare(
            AarComparisonFixtures.snapshotOf(
              AarComparisonFixtures.f1TieBaseline(order: baselineOrder),
              snapshotId: 'b-${baselineOrder.join()}',
              knowledge: AarComparisonFixtures.completeRecorded(
                positions: SlotPositionMeaning.orderOnly,
              ),
            ),
            AarComparisonFixtures.snapshotOf(
              AarComparisonFixtures.f1TieTarget(order: targetOrder),
              snapshotId: 't-${targetOrder.join()}',
              knowledge: AarComparisonFixtures.completeRecorded(
                positions: SlotPositionMeaning.orderOnly,
              ),
            ),
          );
          final modified = diff
              .group(FitInventoryGroup.high)
              .rows
              .where((row) => row.kind == FitChangeKind.modified)
              .toList();
          expect(
            modified,
            hasLength(2),
            reason: '$baselineOrder vs $targetOrder',
          );
          final pairs = {
            for (final row in modified)
              row.beforeChargeTypeId: row.afterChargeTypeId,
          };
          expect(
            pairs,
            {kCmpChargeX: kCmpChargeW, kCmpChargeY: kCmpChargeZ},
            reason:
                'canonical X→W and Y→Z, not list-order $baselineOrder/$targetOrder',
          );
        }
      }
    });
  });

  group('W3 D03 EFT order-only compact positions', () {
    test(
      'compact EFT indices do not invent replacements for the same multiset',
      () {
        final recorded = AarComparisonFixtures.snapshotOf(
          Fitting(
            id: 'rec',
            name: 'rec',
            shipTypeId: kCmpHullH,
            shipName: 'Cmp H',
            highSlots: [
              AarComparisonFixtures.moduleA(
                slotIndex: 0,
                chargeTypeId: kCmpChargeX,
              ),
              AarComparisonFixtures.moduleA(
                slotIndex: 2,
                chargeTypeId: kCmpChargeY,
                chargeName: 'Cmp Y',
              ),
            ],
          ),
          snapshotId: 'recorded',
          knowledge: AarComparisonFixtures.completeRecorded(),
        );
        final compact = AarComparisonFixtures.snapshotOf(
          Fitting(
            id: 'eft',
            name: 'eft',
            shipTypeId: kCmpHullH,
            shipName: 'Cmp H',
            highSlots: [
              AarComparisonFixtures.moduleA(
                slotIndex: 0,
                chargeTypeId: kCmpChargeY,
                chargeName: 'Cmp Y',
              ),
              AarComparisonFixtures.moduleA(
                slotIndex: 1,
                chargeTypeId: kCmpChargeX,
              ),
            ],
          ),
          snapshotId: 'compact',
          knowledge: AarComparisonFixtures.completeRecorded(
            positions: SlotPositionMeaning.orderOnly,
          ),
        );
        final diff = FitInventoryDiff.compare(recorded, compact);
        expect(diff.changes, isEmpty);
        expect(
          diff
              .group(FitInventoryGroup.high)
              .rows
              .where((row) => row.kind == FitChangeKind.replaced),
          isEmpty,
        );
      },
    );
  });

  group('W3 D04 recorded replacement vs order-only and hull change', () {
    test('recorded same-hull mids replace B with C', () {
      final diff = FitInventoryDiff.compare(
        AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Baseline(),
          snapshotId: 'b',
        ),
        AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Target(),
          snapshotId: 't',
        ),
      );
      final mids = diff.group(FitInventoryGroup.mid).rows;
      expect(diff.sameHull, isTrue);
      expect(mids.single.kind, FitChangeKind.replaced);
      expect(mids.single.beforeTypeId, kCmpModuleB);
      expect(mids.single.afterTypeId, kCmpModuleC);
    });

    test(
      'order-only mids emit added C and removed B, not a slot replacement',
      () {
        final knowledge = AarComparisonFixtures.completeRecorded(
          positions: SlotPositionMeaning.orderOnly,
        );
        final diff = FitInventoryDiff.compare(
          AarComparisonFixtures.snapshotOf(
            AarComparisonFixtures.f1Baseline(),
            snapshotId: 'b',
            knowledge: knowledge,
          ),
          AarComparisonFixtures.snapshotOf(
            AarComparisonFixtures.f1Target(),
            snapshotId: 't',
            knowledge: knowledge,
          ),
        );
        final mids = diff.group(FitInventoryGroup.mid).rows;
        expect(
          mids.where((row) => row.kind == FitChangeKind.replaced),
          isEmpty,
        );
        expect(
          mids.any(
            (row) =>
                row.kind == FitChangeKind.removed &&
                row.beforeTypeId == kCmpModuleB,
          ),
          isTrue,
        );
        expect(
          mids.any(
            (row) =>
                row.kind == FitChangeKind.added &&
                row.afterTypeId == kCmpModuleC,
          ),
          isTrue,
        );
      },
    );

    test('different hulls never synthesize slot replacements', () {
      final target = AarComparisonFixtures.f1Target();
      final diff = FitInventoryDiff.compare(
        AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Baseline(),
          snapshotId: 'b',
        ),
        AarComparisonFixtures.snapshotOf(
          target.copyWith(shipTypeId: kCmpHullH2, shipName: 'Cmp H2'),
          snapshotId: 't-h2',
        ),
      );
      expect(diff.sameHull, isFalse);
      expect(
        diff
            .group(FitInventoryGroup.mid)
            .rows
            .where((row) => row.kind == FitChangeKind.replaced),
        isEmpty,
      );
    });
  });

  group('W3 D05 F2 cargo reuse and hull oracles', () {
    test('cargo-to-slot A is visible in groups but not a Changes purchase', () {
      final baseline = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f2Baseline(),
        snapshotId: 'f2-b',
      );
      final target = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f2Target(),
        snapshotId: 'f2-t',
      );
      final diff = FitInventoryDiff.compare(baseline, target);
      expect(baseline.fitting.highSlots, hasLength(1));
      expect(target.fitting.highSlots, hasLength(2));
      expect([
        for (final row in diff.group(FitInventoryGroup.high).rows)
          '${row.kind.name}:${row.afterTypeId}',
      ], contains('added:$kCmpModuleA'));
      expect(
        diff
            .group(FitInventoryGroup.cargo)
            .rows
            .where(
              (row) =>
                  row.kind == FitChangeKind.removed &&
                  row.beforeTypeId == kCmpModuleA,
            ),
        isNotEmpty,
      );

      final changes = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: target,
      );
      expect(changes.requirement(kCmpModuleA), isNull);
      expect(changes.requirement(kCmpModuleC)?.requiredCount, 1);
      expect(changes.requirement(kCmpAmmo)?.requiredCount, 50);
      expect(changes.requirement(kCmpPaste)?.requiredCount, 20);

      final full = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: target,
        mode: AarBomMode.fullReplacement,
      );
      expect(full.requirement(kCmpHullH)?.requiredCount, 1);
      expect(full.requirement(kCmpModuleA)?.requiredCount, 2);
      expect(full.requirement(kCmpModuleC)?.requiredCount, 1);
      expect(full.requirement(kCmpAmmo)?.requiredCount, 150);
      expect(full.requirement(kCmpPaste)?.requiredCount, 20);
    });

    test('H2 variant nets +H2 −H and still buys no A', () {
      final baseline = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f2Baseline(),
        snapshotId: 'f2-b',
      );
      final target = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f2TargetH2(),
        snapshotId: 'f2-h2',
      );
      final changes = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: target,
      );
      expect(changes.requirement(kCmpHullH2)?.requiredCount, 1);
      expect(changes.removal(kCmpHullH)?.requiredCount, 1);
      expect(changes.requirement(kCmpModuleA), isNull);
      expect(changes.requirement(kCmpModuleC)?.requiredCount, 1);
      expect(changes.requirement(kCmpAmmo)?.requiredCount, 50);
      expect(changes.requirement(kCmpPaste)?.requiredCount, 20);

      final full = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: target,
        mode: AarBomMode.fullReplacement,
      );
      expect(full.requirement(kCmpHullH2)?.requiredCount, 1);
      expect(full.requirement(kCmpModuleA)?.requiredCount, 2);
      expect(full.requirement(kCmpAmmo)?.requiredCount, 150);
      expect(full.requirement(kCmpPaste)?.requiredCount, 20);
      expect(full.requirement(kCmpHullH), isNull);
    });
  });

  group('W3 D06 drone, fighter and loaded-charge quantities', () {
    test('quantity and deployment are separate; loaded Y is unquantified', () {
      final baseline = AarComparisonFixtures.snapshotOf(
        Fitting(
          id: 'b',
          name: 'b',
          shipTypeId: kCmpHullH,
          shipName: 'Cmp H',
          highSlots: [
            AarComparisonFixtures.moduleA(
              chargeTypeId: kCmpChargeY,
              chargeName: 'Cmp Y',
            ),
          ],
          drones: [
            AarComparisonFixtures.dronesD(quantity: 5, inBay: 5, inSpace: 0),
          ],
          fighters: [
            const FighterGroup(
              typeId: _fighterTypeId,
              typeName: 'Cmp F',
              quantity: 3,
              inSpace: 0,
            ),
          ],
        ),
        snapshotId: 'b',
      );
      final target = AarComparisonFixtures.snapshotOf(
        Fitting(
          id: 't',
          name: 't',
          shipTypeId: kCmpHullH,
          shipName: 'Cmp H',
          highSlots: [
            AarComparisonFixtures.moduleA(
              chargeTypeId: kCmpChargeY,
              chargeName: 'Cmp Y',
            ),
          ],
          drones: [
            AarComparisonFixtures.dronesD(quantity: 5, inBay: 3, inSpace: 2),
          ],
          fighters: [
            const FighterGroup(
              typeId: _fighterTypeId,
              typeName: 'Cmp F',
              quantity: 2,
              inSpace: 1,
            ),
          ],
        ),
        snapshotId: 't',
      );
      final diff = FitInventoryDiff.compare(baseline, target);
      final drones = diff.group(FitInventoryGroup.drones).rows;
      expect(
        drones.where((row) => row.kind == FitChangeKind.removed),
        isEmpty,
        reason: 'total D quantity is unchanged',
      );
      expect(drones, isNotEmpty);
      expect(drones.single.kind, FitChangeKind.modified);
      expect(drones.single.afterInSpace, 2);

      final fighters = diff.group(FitInventoryGroup.fighters).rows;
      expect(
        fighters.where((row) => row.kind == FitChangeKind.removed),
        isNotEmpty,
      );
      expect(
        fighters
            .where((row) => row.kind == FitChangeKind.removed)
            .single
            .quantity,
        1,
      );
      expect(
        fighters.any(
          (row) => row.kind == FitChangeKind.modified && row.afterInSpace == 1,
        ),
        isTrue,
      );

      final bom = FitBillOfMaterials.fromSnapshots(
        baseline: baseline,
        target: target,
      );
      expect(bom.requirement(kCmpDroneD), isNull);
      expect(bom.removal(_fighterTypeId)?.requiredCount, 1);
      expect(bom.unquantifiedCharges, contains(kCmpChargeY));
      expect(
        bom.requirement(kCmpChargeY),
        isNull,
        reason: 'loaded Y is not a drone/cargo purchase',
      );
    });
  });

  group('W3 D07 completeness and unresolved occupants', () {
    test(
      'unknown baseline does not count as zero; unresolved is preserved',
      () {
        final unknownBaseline = AarFitSnapshot(
          snapshotId: 'unknown',
          encounterId: 'enc',
          fitting: AarComparisonFixtures.hullOnly(),
          source: AarFitSource.killmailVictim,
          subject: const AarFitSubject(relation: AarFitSubjectRelation.victim),
          knowledge: FitInventoryKnowledge.unknown(),
        );
        final unresolved = AarComparisonFixtures.f5Partial();
        final completeTarget = AarComparisonFixtures.snapshotOf(
          AarComparisonFixtures.f1Target(),
          snapshotId: 'complete-t',
        );

        final unknownDiff = FitInventoryDiff.compare(
          unknownBaseline,
          completeTarget,
        );
        expect(
          unknownDiff.changes.every(
            (row) =>
                row.qualification == 'Present only in this record' ||
                row.qualification == 'Absent from supplied record',
          ),
          isTrue,
        );

        final unresolvedDiff = FitInventoryDiff.compare(
          unresolved,
          completeTarget,
        );
        expect(unresolvedDiff.unresolved, isNotEmpty);
        expect(unresolvedDiff.unresolved.single.kind, FitChangeKind.unresolved);

        final changes = FitBillOfMaterials.fromSnapshots(
          baseline: unknownBaseline,
          target: completeTarget,
        );
        expect(changes.complete, isFalse);
        expect(changes.heading, contains('Incomplete'));
        expect(
          changes.requirement(kCmpModuleA)?.requiredCount,
          isNull,
          reason: 'unknown baseline cannot prove a purchase quantity',
        );
        expect(
          changes.requirement(kCmpModuleA)?.qualification,
          'Not present in baseline record',
        );

        final full = FitBillOfMaterials.fromSnapshots(
          baseline: unknownBaseline,
          target: completeTarget,
          mode: AarBomMode.fullReplacement,
        );
        expect(full.complete, isTrue);
        expect(full.requirement(kCmpModuleA)?.requiredCount, 2);
        expect(full.requirement(kCmpModuleC)?.requiredCount, 1);
        expect(full.requirement(kCmpAmmo)?.requiredCount, 150);
      },
    );

    test('explicit complete empty baseline is distinct from unknown', () {
      final emptyComplete = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.hullOnly(),
        snapshotId: 'empty',
        knowledge: FitInventoryKnowledge.recordedComplete(),
      );
      final target = AarComparisonFixtures.snapshotOf(
        AarComparisonFixtures.f1Target(),
        snapshotId: 't',
      );
      final emptyBom = FitBillOfMaterials.fromSnapshots(
        baseline: emptyComplete,
        target: target,
      );
      final unknownBom = FitBillOfMaterials.fromSnapshots(
        baseline: AarFitSnapshot(
          snapshotId: 'unk',
          encounterId: 'enc',
          fitting: AarComparisonFixtures.hullOnly(),
          source: AarFitSource.killmailVictim,
          subject: const AarFitSubject(relation: AarFitSubjectRelation.victim),
          knowledge: FitInventoryKnowledge.unknown(),
        ),
        target: target,
      );
      expect(emptyBom.complete, isTrue);
      expect(emptyBom.requirement(kCmpModuleC)?.requiredCount, 1);
      expect(unknownBom.complete, isFalse);
      expect(unknownBom.requirement(kCmpModuleC)?.requiredCount, isNull);
    });
  });

  group('W3 extended total-order permutations', () {
    test(
      'unknown then recordedAbsent beat list order against two known charges',
      () {
        FittedModule a({int? charge, int slot = 0}) {
          return AarComparisonFixtures.moduleA(
            slotIndex: slot,
            chargeTypeId: charge,
            chargeName: charge == null ? null : 'c$charge',
          );
        }

        final baseline = AarComparisonFixtures.snapshotOf(
          Fitting(
            id: 'b',
            name: 'b',
            shipTypeId: kCmpHullH,
            shipName: 'Cmp H',
            highSlots: [
              a(charge: kCmpChargeX, slot: 0),
              a(slot: 1),
            ],
          ),
          snapshotId: 'b',
          knowledge: FitInventoryKnowledge(
            groups: {
              FitInventoryGroup.high: const FitGroupKnowledge(
                completeness: InventoryCompleteness.recordedComplete,
                positions: SlotPositionMeaning.orderOnly,
              ),
            },
            occurrences: const [
              FitOccurrenceKnowledge(
                occurrenceKey: 'high:0',
                charge: ChargeKnowledge.recordedIdentity,
              ),
              FitOccurrenceKnowledge(
                occurrenceKey: 'high:1',
                charge: ChargeKnowledge.unknown,
              ),
            ],
          ),
        );
        final target = AarComparisonFixtures.snapshotOf(
          Fitting(
            id: 't',
            name: 't',
            shipTypeId: kCmpHullH,
            shipName: 'Cmp H',
            highSlots: [
              a(charge: kCmpChargeW, slot: 0),
              a(slot: 1),
            ],
          ),
          snapshotId: 't',
          knowledge: FitInventoryKnowledge(
            groups: {
              FitInventoryGroup.high: const FitGroupKnowledge(
                completeness: InventoryCompleteness.recordedComplete,
                positions: SlotPositionMeaning.orderOnly,
              ),
            },
            occurrences: const [
              FitOccurrenceKnowledge(
                occurrenceKey: 'high:0',
                charge: ChargeKnowledge.recordedIdentity,
              ),
              FitOccurrenceKnowledge(
                occurrenceKey: 'high:1',
                charge: ChargeKnowledge.recordedAbsent,
              ),
            ],
          ),
        );
        final reversedTarget = AarComparisonFixtures.snapshotOf(
          Fitting(
            id: 't2',
            name: 't2',
            shipTypeId: kCmpHullH,
            shipName: 'Cmp H',
            highSlots: [
              a(slot: 0),
              a(charge: kCmpChargeW, slot: 1),
            ],
          ),
          snapshotId: 't2',
          knowledge: FitInventoryKnowledge(
            groups: {
              FitInventoryGroup.high: const FitGroupKnowledge(
                completeness: InventoryCompleteness.recordedComplete,
                positions: SlotPositionMeaning.orderOnly,
              ),
            },
            occurrences: const [
              FitOccurrenceKnowledge(
                occurrenceKey: 'high:0',
                charge: ChargeKnowledge.recordedAbsent,
              ),
              FitOccurrenceKnowledge(
                occurrenceKey: 'high:1',
                charge: ChargeKnowledge.recordedIdentity,
              ),
            ],
          ),
        );

        void expectCanonical(FitInventoryDiff diff) {
          final modified = diff
              .group(FitInventoryGroup.high)
              .rows
              .where((row) => row.kind == FitChangeKind.modified)
              .toList();
          final pairs = {
            for (final row in modified)
              row.beforeChargeTypeId: row.afterChargeTypeId,
          };
          expect(pairs.containsKey(kCmpChargeX), isTrue);
          expect(pairs[kCmpChargeX], kCmpChargeW);
          expect(
            modified.any((row) => row.beforeChargeTypeId == null),
            isTrue,
            reason: 'unknown charge pairs with recordedAbsent, not W',
          );
        }

        expectCanonical(FitInventoryDiff.compare(baseline, target));
        expectCanonical(FitInventoryDiff.compare(baseline, reversedTarget));
      },
    );

    test('recorded vs assumed equal state is not a list-order tie-break', () {
      final baseline = AarComparisonFixtures.snapshotOf(
        Fitting(
          id: 'b',
          name: 'b',
          shipTypeId: kCmpHullH,
          shipName: 'Cmp H',
          highSlots: [
            AarComparisonFixtures.moduleA(slotIndex: 0),
            AarComparisonFixtures.moduleA(
              slotIndex: 1,
              chargeTypeId: kCmpChargeY,
              chargeName: 'Cmp Y',
            ),
          ],
        ),
        snapshotId: 'b',
        knowledge: FitInventoryKnowledge(
          groups: {
            FitInventoryGroup.high: const FitGroupKnowledge(
              completeness: InventoryCompleteness.recordedComplete,
              positions: SlotPositionMeaning.orderOnly,
            ),
          },
          occurrences: const [
            FitOccurrenceKnowledge(
              occurrenceKey: 'high:0',
              charge: ChargeKnowledge.recordedIdentity,
              state: StateKnowledge.recorded,
            ),
            FitOccurrenceKnowledge(
              occurrenceKey: 'high:1',
              charge: ChargeKnowledge.recordedIdentity,
              state: StateKnowledge.assumed,
            ),
          ],
        ),
      );
      final target = AarComparisonFixtures.snapshotOf(
        Fitting(
          id: 't',
          name: 't',
          shipTypeId: kCmpHullH,
          shipName: 'Cmp H',
          highSlots: [
            AarComparisonFixtures.moduleA(
              slotIndex: 0,
              chargeTypeId: kCmpChargeY,
              chargeName: 'Cmp Y',
            ),
            AarComparisonFixtures.moduleA(slotIndex: 1),
          ],
        ),
        snapshotId: 't',
        knowledge: FitInventoryKnowledge(
          groups: {
            FitInventoryGroup.high: const FitGroupKnowledge(
              completeness: InventoryCompleteness.recordedComplete,
              positions: SlotPositionMeaning.orderOnly,
            ),
          },
          occurrences: const [
            FitOccurrenceKnowledge(
              occurrenceKey: 'high:0',
              charge: ChargeKnowledge.recordedIdentity,
              state: StateKnowledge.assumed,
            ),
            FitOccurrenceKnowledge(
              occurrenceKey: 'high:1',
              charge: ChargeKnowledge.recordedIdentity,
              state: StateKnowledge.recorded,
            ),
          ],
        ),
      );
      final diff = FitInventoryDiff.compare(baseline, target);
      expect(diff.changes, isEmpty);
    });
  });
}

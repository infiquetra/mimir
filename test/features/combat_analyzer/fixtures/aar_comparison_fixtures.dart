import 'package:drift/drift.dart' show Value;
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_snapshot.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/fitting/domain/models.dart';

/// Symbolic F1–F5 SDE type IDs. Distinct from live EVE IDs and from the
/// import-harness 587/2048/… set.
const kCmpHullH = 91001;
const kCmpHullH2 = 91002;
const kCmpModuleA = 91101;
const kCmpModuleB = 91201;
const kCmpModuleC = 91202;
const kCmpDroneD = 91301;
const kCmpAmmo = 91401;
const kCmpPaste = 91402;
const kCmpChargeW = 91501;
const kCmpChargeX = 91502;
const kCmpChargeY = 91503;
const kCmpChargeZ = 91504;

const kCmpHighGroupId = 9101;
const kCmpMidGroupId = 9102;
const kCmpPasteGroupId = 9103;

const kCmpTypeNames = <int, String>{
  kCmpHullH: 'Cmp H',
  kCmpHullH2: 'Cmp H2',
  kCmpModuleA: 'Cmp A',
  kCmpModuleB: 'Cmp B',
  kCmpModuleC: 'Cmp C',
  kCmpDroneD: 'Cmp D',
  kCmpAmmo: 'Cmp Ammo',
  kCmpPaste: 'Cmp Paste',
  kCmpChargeW: 'Cmp W',
  kCmpChargeX: 'Cmp X',
  kCmpChargeY: 'Cmp Y',
  kCmpChargeZ: 'Cmp Z',
};

/// Product §9.1 F3 oracles at domain precision.
class F3Oracle {
  static const layerHp = 1000.0;
  static const baselineResists = [0.50, 0.20, 0.40, 0.10];
  static const targetResists = [0.60, 0.20, 0.50, 0.10];
  static const emBaselineLayerEhp = 2000.0;
  static const emTargetLayerEhp = 2500.0;
  static const emBaselineTotalEhp = 6000.0;
  static const emTargetTotalEhp = 7500.0;
  static const emDeltaEhp = 1500.0;
  static const emDeltaPercent = 0.25;
  static const emResistPp = 10.0;
  static const omniBaselineEhp = 3000 / 0.7;
  static const omniTargetEhp = 3000 / 0.65;
  static const omniDeltaEhp = omniTargetEhp - omniBaselineEhp;
  static const omniDeltaPercent = omniDeltaEhp / omniBaselineEhp;
}

/// Product §9.1 F4 labels.
class F4Oracle {
  static const baselineTimeToEmptySeconds = 120.0;
  static const candidateStableFraction = 0.35;
  static const capTransition = 'Depleting → Modeled stable';
  static const burstRepairHps = 100.0;
  static const peakPassiveHps = 20.0;
  static const sustainedLabel = 'Not modeled';
  static const injectorLimitation = 'infinite-clip';
  static const horizonSeconds = 3600;
}

/// Product §9.1 F2 value oracles.
class F2Oracle {
  static const hullPrice = 100000000;
  static const aPrice = 1000000;
  static const cPrice = 2000000;
  static const ammoPrice = 10;
  static const changesPricedSubtotal = 2000500;
  static const changesPricedLines = '2/3';
  static const replacementPricedSubtotal = 104001500;
  static const replacementPricedLines = '4/5';
  static const pricedShortfall = 200;
}

class AarComparisonFixtures {
  static FittedModule moduleA({
    int slotIndex = 0,
    ModuleState state = ModuleState.active,
    int? chargeTypeId = kCmpChargeX,
    String? chargeName = 'Cmp X',
  }) {
    return FittedModule(
      typeId: kCmpModuleA,
      typeName: 'Cmp A',
      slotType: SlotType.high,
      slotIndex: slotIndex,
      state: state,
      chargeTypeId: chargeTypeId,
      chargeName: chargeName,
    );
  }

  static FittedModule moduleB({int slotIndex = 0}) {
    return FittedModule(
      typeId: kCmpModuleB,
      typeName: 'Cmp B',
      slotType: SlotType.med,
      slotIndex: slotIndex,
      state: ModuleState.active,
    );
  }

  static FittedModule moduleC({int slotIndex = 0}) {
    return FittedModule(
      typeId: kCmpModuleC,
      typeName: 'Cmp C',
      slotType: SlotType.med,
      slotIndex: slotIndex,
      state: ModuleState.active,
    );
  }

  static DroneGroup dronesD({
    int quantity = 5,
    int inBay = 5,
    int inSpace = 0,
  }) {
    return DroneGroup(
      typeId: kCmpDroneD,
      typeName: 'Cmp D',
      quantity: quantity,
      inBay: inBay,
      inSpace: inSpace,
    );
  }

  static CargoItem ammo({int quantity = 100}) {
    return CargoItem(
      typeId: kCmpAmmo,
      typeName: 'Cmp Ammo',
      quantity: quantity,
    );
  }

  static CargoItem paste({int quantity = 20}) {
    return CargoItem(
      typeId: kCmpPaste,
      typeName: 'Cmp Paste',
      quantity: quantity,
    );
  }

  static Fitting hullOnly({
    int shipTypeId = kCmpHullH,
    String name = 'Cmp H',
    String id = 'cmp-hull',
  }) {
    return Fitting(id: id, name: name, shipTypeId: shipTypeId, shipName: name);
  }

  static FitInventoryKnowledge completeRecorded({
    SlotPositionMeaning positions = SlotPositionMeaning.recorded,
  }) {
    return FitInventoryKnowledge.recordedComplete(positions: positions);
  }

  static Fitting f1Baseline() {
    return Fitting(
      id: 'f1-baseline',
      name: 'F1 Baseline',
      shipTypeId: kCmpHullH,
      shipName: 'Cmp H',
      highSlots: [moduleA(slotIndex: 0), moduleA(slotIndex: 1)],
      medSlots: [moduleB()],
      drones: [dronesD()],
      cargo: [ammo()],
    );
  }

  static Fitting f1Target() {
    return Fitting(
      id: 'f1-target',
      name: 'F1 Target',
      shipTypeId: kCmpHullH,
      shipName: 'Cmp H',
      highSlots: [
        moduleA(
          slotIndex: 1,
          state: ModuleState.offline,
          chargeTypeId: kCmpChargeY,
          chargeName: 'Cmp Y',
        ),
        moduleA(slotIndex: 0),
      ],
      medSlots: [moduleC()],
      drones: [dronesD(quantity: 3, inBay: 3)],
      cargo: [ammo(quantity: 150), paste()],
    );
  }

  static Fitting f1TieBaseline({List<int> order = const [0, 1]}) {
    final configs = [
      moduleA(
        slotIndex: 0,
        state: ModuleState.active,
        chargeTypeId: kCmpChargeX,
      ),
      moduleA(
        slotIndex: 1,
        state: ModuleState.offline,
        chargeTypeId: kCmpChargeY,
        chargeName: 'Cmp Y',
      ),
    ];
    return Fitting(
      id: 'f1-tie-baseline',
      name: 'F1 Tie Baseline',
      shipTypeId: kCmpHullH,
      shipName: 'Cmp H',
      highSlots: [for (final i in order) configs[i]],
    );
  }

  static Fitting f1TieTarget({List<int> order = const [0, 1]}) {
    final configs = [
      moduleA(
        slotIndex: 0,
        state: ModuleState.online,
        chargeTypeId: kCmpChargeZ,
        chargeName: 'Cmp Z',
      ),
      moduleA(
        slotIndex: 1,
        state: ModuleState.overloaded,
        chargeTypeId: kCmpChargeW,
        chargeName: 'Cmp W',
      ),
    ];
    return Fitting(
      id: 'f1-tie-target',
      name: 'F1 Tie Target',
      shipTypeId: kCmpHullH,
      shipName: 'Cmp H',
      highSlots: [for (final i in order) configs[i]],
    );
  }

  static Fitting f2Baseline() {
    return Fitting(
      id: 'f2-baseline',
      name: 'F2 Baseline',
      shipTypeId: kCmpHullH,
      shipName: 'Cmp H',
      highSlots: [moduleA()],
      cargo: [
        CargoItem(typeId: kCmpModuleA, typeName: 'Cmp A', quantity: 1),
        ammo(),
      ],
    );
  }

  static Fitting f2Target({
    int hullTypeId = kCmpHullH,
    String hullName = 'Cmp H',
  }) {
    return Fitting(
      id: 'f2-target',
      name: 'F2 Target',
      shipTypeId: hullTypeId,
      shipName: hullName,
      highSlots: [moduleA(slotIndex: 0), moduleA(slotIndex: 1)],
      medSlots: [moduleC()],
      cargo: [ammo(quantity: 150), paste()],
    );
  }

  static Fitting f2TargetH2() =>
      f2Target(hullTypeId: kCmpHullH2, hullName: 'Cmp H2');

  static AarFitSnapshot snapshotOf(
    Fitting fitting, {
    String snapshotId = 'snap',
    String encounterId = 'enc-cmp',
    AarFitSource source = AarFitSource.comparisonCapture,
    AarFitSubject? subject,
    DateTime? recordedAt,
    FitInventoryKnowledge? knowledge,
    List<int>? sourceItemIds,
  }) {
    return AarFitSnapshot(
      snapshotId: snapshotId,
      encounterId: encounterId,
      fitting: fitting,
      source: source,
      subject:
          subject ??
          const AarFitSubject(
            characterId: 42,
            relation: AarFitSubjectRelation.pilot,
          ),
      recordedAt: recordedAt,
      knowledge:
          knowledge ??
          FitInventoryKnowledge.recordedComplete(
            positions: SlotPositionMeaning.recorded,
          ),
      sourceItemIds: sourceItemIds ?? const [],
    );
  }

  static AarFitSnapshot f5Fold() {
    return AarFitSnapshot(
      snapshotId: 'f-old',
      encounterId: 'enc-f5',
      fitting: f1Baseline(),
      source: AarFitSource.evidenceAttachment,
      subject: const AarFitSubject(
        characterId: 42,
        relation: AarFitSubjectRelation.pilot,
      ),
      confidence: EvidenceConfidence.confirmed,
      knowledge: completeRecorded(),
    );
  }

  static AarFitSnapshot f5Fnew() {
    return AarFitSnapshot(
      snapshotId: 'f-new',
      encounterId: 'enc-f5',
      fitting: f1Target(),
      source: AarFitSource.evidenceAttachment,
      subject: const AarFitSubject(
        characterId: 42,
        relation: AarFitSubjectRelation.pilot,
      ),
      confidence: EvidenceConfidence.confirmed,
      knowledge: completeRecorded(),
    );
  }

  static AarFitSnapshot f5VictimQ() {
    return AarFitSnapshot.fromKillmailVictim(
      encounterId: 'enc-f5',
      fitting: hullOnly(),
      killmailId: 777001,
      victimCharacterId: 99,
    );
  }

  static AarFitSnapshot f5VictimP() {
    return AarFitSnapshot.fromKillmailVictim(
      encounterId: 'enc-f5',
      fitting: f1Baseline(),
      killmailId: 777002,
      victimCharacterId: 42,
    );
  }

  static AarFitSnapshot f5VictimUnknown() {
    return AarFitSnapshot.fromKillmailVictim(
      encounterId: 'enc-f5',
      fitting: hullOnly(),
      killmailId: 777003,
    );
  }

  static AarFitSnapshot f5Reference() {
    return AarFitSnapshot.fromFitEvidence(
      encounterId: 'enc-f5',
      evidence: FitEvidence(
        role: FitEvidenceRole.pilot,
        source: EvidenceSource.currentShipSnapshot,
        confidence: EvidenceConfidence.reference,
        fitting: f1Baseline(),
      ),
    );
  }

  static AarFitSnapshot f5Partial() {
    return AarFitSnapshot(
      snapshotId: 'f5-partial',
      encounterId: 'enc-f5',
      fitting: hullOnly(),
      source: AarFitSource.killmailVictim,
      subject: const AarFitSubject(
        characterId: 99,
        relation: AarFitSubjectRelation.victim,
      ),
      knowledge: FitInventoryKnowledge(
        groups: {
          FitInventoryGroup.mid: FitGroupKnowledge(
            completeness: InventoryCompleteness.partial,
            applicability: GroupApplicability.applicable,
            positions: SlotPositionMeaning.recorded,
            unresolvedOccupied: const [
              UnresolvedOccupant(
                sourceEntryKey: 'mid-0',
                group: FitInventoryGroup.mid,
                physicalIndex: 0,
                label: 'unresolved mid',
                quantityUnknown: true,
              ),
            ],
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
  }
}

/// Seed F1–F5 types with names, categories, and slot-effect metadata.
Future<void> seedComparisonSde(SdeDatabase sdeDb) async {
  await sdeDb.upsertGroups([
    SdeGroupsCompanion.insert(
      groupId: const Value(kCmpHighGroupId),
      groupName: 'Cmp High',
      categoryId: 7,
    ),
    SdeGroupsCompanion.insert(
      groupId: const Value(kCmpMidGroupId),
      groupName: 'Cmp Mid',
      categoryId: 7,
    ),
    SdeGroupsCompanion.insert(
      groupId: const Value(kCmpPasteGroupId),
      groupName: 'Cmp Paste',
      categoryId: 8,
    ),
  ]);
  await sdeDb.upsertTypes([
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpHullH),
      typeName: 'Cmp H',
      groupId: 25,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpHullH2),
      typeName: 'Cmp H2',
      groupId: 25,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpModuleA),
      typeName: 'Cmp A',
      groupId: kCmpHighGroupId,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpModuleB),
      typeName: 'Cmp B',
      groupId: kCmpMidGroupId,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpModuleC),
      typeName: 'Cmp C',
      groupId: kCmpMidGroupId,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpDroneD),
      typeName: 'Cmp D',
      groupId: 100,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpAmmo),
      typeName: 'Cmp Ammo',
      groupId: 83,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpPaste),
      typeName: 'Cmp Paste',
      groupId: kCmpPasteGroupId,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpChargeW),
      typeName: 'Cmp W',
      groupId: 83,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpChargeX),
      typeName: 'Cmp X',
      groupId: 83,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpChargeY),
      typeName: 'Cmp Y',
      groupId: 83,
    ),
    SdeTypesCompanion.insert(
      typeId: const Value(kCmpChargeZ),
      typeName: 'Cmp Z',
      groupId: 83,
    ),
  ]);
  await sdeDb.upsertTypeEffects([
    SdeTypeEffectsCompanion.insert(typeId: kCmpModuleA, effectId: 12),
    SdeTypeEffectsCompanion.insert(typeId: kCmpModuleB, effectId: 13),
    SdeTypeEffectsCompanion.insert(typeId: kCmpModuleC, effectId: 13),
  ]);
  await sdeDb.upsertTypeAttributes([
    SdeTypeAttributesCompanion.insert(
      typeId: kCmpHullH,
      attributeId: 12,
      value: 3,
    ),
    SdeTypeAttributesCompanion.insert(
      typeId: kCmpHullH,
      attributeId: 13,
      value: 3,
    ),
    SdeTypeAttributesCompanion.insert(
      typeId: kCmpHullH,
      attributeId: 14,
      value: 4,
    ),
    SdeTypeAttributesCompanion.insert(
      typeId: kCmpHullH2,
      attributeId: 12,
      value: 3,
    ),
    SdeTypeAttributesCompanion.insert(
      typeId: kCmpHullH2,
      attributeId: 13,
      value: 3,
    ),
    SdeTypeAttributesCompanion.insert(
      typeId: kCmpHullH2,
      attributeId: 14,
      value: 4,
    ),
  ]);
}

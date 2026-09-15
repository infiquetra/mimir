import '../../fitting/domain/models.dart';
import 'aar_fit_snapshot.dart';

enum FitChangeKind { added, removed, modified, unchanged, replaced, unresolved }

/// Compile stub for W3. GREEN replaces list-index pairing with the §5.2
/// exact-multiset then canonical-order algorithm.
class FitChangeRow {
  const FitChangeRow({
    required this.id,
    required this.group,
    required this.kind,
    this.beforeTypeId,
    this.afterTypeId,
    this.quantity = 1,
    this.beforeChargeTypeId,
    this.afterChargeTypeId,
    this.beforeState,
    this.afterState,
    this.beforeSlotIndex,
    this.afterSlotIndex,
    this.slotMeaning,
    this.beforeInBay,
    this.afterInBay,
    this.beforeInSpace,
    this.afterInSpace,
    this.chargeQuantityUnknown = false,
    this.qualification,
  });

  final String id;
  final FitInventoryGroup group;
  final FitChangeKind kind;
  final int? beforeTypeId;
  final int? afterTypeId;
  final int quantity;
  final int? beforeChargeTypeId;
  final int? afterChargeTypeId;
  final ModuleState? beforeState;
  final ModuleState? afterState;
  final int? beforeSlotIndex;
  final int? afterSlotIndex;
  final SlotPositionMeaning? slotMeaning;
  final int? beforeInBay;
  final int? afterInBay;
  final int? beforeInSpace;
  final int? afterInSpace;
  final bool chargeQuantityUnknown;
  final String? qualification;
}

class FitGroupDiff {
  const FitGroupDiff({required this.group, this.rows = const []});

  final FitInventoryGroup group;
  final List<FitChangeRow> rows;

  bool get hasChanges => rows.any((row) => row.kind != FitChangeKind.unchanged);
}

class FitInventoryDiff {
  const FitInventoryDiff({
    this.baselineSnapshotId,
    this.candidateSnapshotId,
    this.baselineFingerprint,
    this.candidateFingerprint,
    this.sameHull = true,
    this.groups = const [],
    this.unresolved = const [],
    this.limitations = const [],
  });

  final String? baselineSnapshotId;
  final String? candidateSnapshotId;
  final String? baselineFingerprint;
  final String? candidateFingerprint;
  final bool sameHull;
  final List<FitGroupDiff> groups;
  final List<FitChangeRow> unresolved;
  final List<String> limitations;

  Iterable<FitChangeRow> get allRows => [
    for (final group in groups) ...group.rows,
  ];

  Iterable<FitChangeRow> get changes =>
      allRows.where((row) => row.kind != FitChangeKind.unchanged);

  bool get hasRecordedChanges => changes.isNotEmpty;

  String? get noChangesLabel =>
      hasRecordedChanges ? null : 'No recorded equipment changes';

  FitGroupDiff group(FitInventoryGroup group) {
    return groups.firstWhere(
      (entry) => entry.group == group,
      orElse: () => FitGroupDiff(group: group),
    );
  }

  /// Naive: zip by input-list index and treat same-index type changes as
  /// replacements even for order-only or different-hull pairings.
  factory FitInventoryDiff.compare(
    AarFitSnapshot baseline,
    AarFitSnapshot candidate,
  ) {
    final sameHull =
        baseline.fitting.shipTypeId == candidate.fitting.shipTypeId;
    final groups = <FitGroupDiff>[
      _zipModules(
        FitInventoryGroup.high,
        baseline.fitting.highSlots,
        candidate.fitting.highSlots,
        baseline.knowledge.group(FitInventoryGroup.high).positions,
      ),
      _zipModules(
        FitInventoryGroup.mid,
        baseline.fitting.medSlots,
        candidate.fitting.medSlots,
        baseline.knowledge.group(FitInventoryGroup.mid).positions,
      ),
      _zipModules(
        FitInventoryGroup.low,
        baseline.fitting.lowSlots,
        candidate.fitting.lowSlots,
        baseline.knowledge.group(FitInventoryGroup.low).positions,
      ),
      _zipModules(
        FitInventoryGroup.rigs,
        baseline.fitting.rigSlots,
        candidate.fitting.rigSlots,
        baseline.knowledge.group(FitInventoryGroup.rigs).positions,
      ),
      _zipModules(
        FitInventoryGroup.subsystems,
        baseline.fitting.subsystems,
        candidate.fitting.subsystems,
        baseline.knowledge.group(FitInventoryGroup.subsystems).positions,
      ),
      _zipDrones(baseline.fitting.drones, candidate.fitting.drones),
      _zipFighters(baseline.fitting.fighters, candidate.fitting.fighters),
      _zipCargo(baseline.fitting.cargo, candidate.fitting.cargo),
    ];
    return FitInventoryDiff(
      baselineSnapshotId: baseline.snapshotId,
      candidateSnapshotId: candidate.snapshotId,
      baselineFingerprint: baseline.contentFingerprint,
      candidateFingerprint: candidate.contentFingerprint,
      sameHull: sameHull,
      groups: groups,
    );
  }

  static FitGroupDiff _zipModules(
    FitInventoryGroup group,
    List<FittedModule> baseline,
    List<FittedModule> candidate,
    SlotPositionMeaning positions,
  ) {
    final length = baseline.length > candidate.length
        ? baseline.length
        : candidate.length;
    final rows = <FitChangeRow>[];
    for (var i = 0; i < length; i++) {
      final before = i < baseline.length ? baseline[i] : null;
      final after = i < candidate.length ? candidate[i] : null;
      if (before != null && after != null) {
        if (before.typeId == after.typeId) {
          final sameConfig =
              before.chargeTypeId == after.chargeTypeId &&
              before.state == after.state;
          rows.add(
            FitChangeRow(
              id: '${group.name}:$i',
              group: group,
              kind: sameConfig
                  ? FitChangeKind.unchanged
                  : FitChangeKind.modified,
              beforeTypeId: before.typeId,
              afterTypeId: after.typeId,
              beforeChargeTypeId: before.chargeTypeId,
              afterChargeTypeId: after.chargeTypeId,
              beforeState: before.state,
              afterState: after.state,
              beforeSlotIndex: before.slotIndex,
              afterSlotIndex: after.slotIndex,
              slotMeaning: positions,
              chargeQuantityUnknown: after.chargeTypeId != null,
            ),
          );
        } else {
          rows.add(
            FitChangeRow(
              id: '${group.name}:$i',
              group: group,
              kind: FitChangeKind.replaced,
              beforeTypeId: before.typeId,
              afterTypeId: after.typeId,
              beforeSlotIndex: before.slotIndex,
              afterSlotIndex: after.slotIndex,
              slotMeaning: positions,
            ),
          );
        }
      } else if (after != null) {
        rows.add(
          FitChangeRow(
            id: '${group.name}:$i',
            group: group,
            kind: FitChangeKind.added,
            afterTypeId: after.typeId,
            afterChargeTypeId: after.chargeTypeId,
            afterState: after.state,
            afterSlotIndex: after.slotIndex,
            slotMeaning: positions,
          ),
        );
      } else if (before != null) {
        rows.add(
          FitChangeRow(
            id: '${group.name}:$i',
            group: group,
            kind: FitChangeKind.removed,
            beforeTypeId: before.typeId,
            beforeChargeTypeId: before.chargeTypeId,
            beforeState: before.state,
            beforeSlotIndex: before.slotIndex,
            slotMeaning: positions,
          ),
        );
      }
    }
    return FitGroupDiff(group: group, rows: rows);
  }

  static FitGroupDiff _zipDrones(
    List<DroneGroup> baseline,
    List<DroneGroup> candidate,
  ) {
    final length = baseline.length > candidate.length
        ? baseline.length
        : candidate.length;
    final rows = <FitChangeRow>[];
    for (var i = 0; i < length; i++) {
      final before = i < baseline.length ? baseline[i] : null;
      final after = i < candidate.length ? candidate[i] : null;
      if (before != null && after != null && before.typeId == after.typeId) {
        rows.add(
          FitChangeRow(
            id: 'drones:$i',
            group: FitInventoryGroup.drones,
            kind: before.quantity == after.quantity
                ? FitChangeKind.unchanged
                : FitChangeKind.modified,
            beforeTypeId: before.typeId,
            afterTypeId: after.typeId,
            quantity: 1,
            beforeInBay: before.inBay,
            afterInBay: after.inBay,
            beforeInSpace: before.inSpace,
            afterInSpace: after.inSpace,
          ),
        );
      } else if (after != null) {
        rows.add(
          FitChangeRow(
            id: 'drones:$i',
            group: FitInventoryGroup.drones,
            kind: FitChangeKind.added,
            afterTypeId: after.typeId,
            quantity: 1,
          ),
        );
      } else if (before != null) {
        rows.add(
          FitChangeRow(
            id: 'drones:$i',
            group: FitInventoryGroup.drones,
            kind: FitChangeKind.removed,
            beforeTypeId: before.typeId,
            quantity: 1,
          ),
        );
      }
    }
    return FitGroupDiff(group: FitInventoryGroup.drones, rows: rows);
  }

  static FitGroupDiff _zipFighters(
    List<FighterGroup> baseline,
    List<FighterGroup> candidate,
  ) {
    final length = baseline.length > candidate.length
        ? baseline.length
        : candidate.length;
    final rows = <FitChangeRow>[];
    for (var i = 0; i < length; i++) {
      final before = i < baseline.length ? baseline[i] : null;
      final after = i < candidate.length ? candidate[i] : null;
      if (before != null && after != null && before.typeId == after.typeId) {
        rows.add(
          FitChangeRow(
            id: 'fighters:$i',
            group: FitInventoryGroup.fighters,
            kind: before.quantity == after.quantity
                ? FitChangeKind.unchanged
                : FitChangeKind.modified,
            beforeTypeId: before.typeId,
            afterTypeId: after.typeId,
            quantity: 1,
            beforeInSpace: before.inSpace,
            afterInSpace: after.inSpace,
          ),
        );
      } else if (after != null) {
        rows.add(
          FitChangeRow(
            id: 'fighters:$i',
            group: FitInventoryGroup.fighters,
            kind: FitChangeKind.added,
            afterTypeId: after.typeId,
            quantity: 1,
          ),
        );
      } else if (before != null) {
        rows.add(
          FitChangeRow(
            id: 'fighters:$i',
            group: FitInventoryGroup.fighters,
            kind: FitChangeKind.removed,
            beforeTypeId: before.typeId,
            quantity: 1,
          ),
        );
      }
    }
    return FitGroupDiff(group: FitInventoryGroup.fighters, rows: rows);
  }

  static FitGroupDiff _zipCargo(
    List<CargoItem> baseline,
    List<CargoItem> candidate,
  ) {
    final length = baseline.length > candidate.length
        ? baseline.length
        : candidate.length;
    final rows = <FitChangeRow>[];
    for (var i = 0; i < length; i++) {
      final before = i < baseline.length ? baseline[i] : null;
      final after = i < candidate.length ? candidate[i] : null;
      if (before != null && after != null && before.typeId == after.typeId) {
        rows.add(
          FitChangeRow(
            id: 'cargo:$i',
            group: FitInventoryGroup.cargo,
            kind: before.quantity == after.quantity
                ? FitChangeKind.unchanged
                : FitChangeKind.modified,
            beforeTypeId: before.typeId,
            afterTypeId: after.typeId,
            quantity: after.quantity - before.quantity,
          ),
        );
      } else if (after != null) {
        rows.add(
          FitChangeRow(
            id: 'cargo:$i',
            group: FitInventoryGroup.cargo,
            kind: FitChangeKind.added,
            afterTypeId: after.typeId,
            quantity: after.quantity,
          ),
        );
      } else if (before != null) {
        rows.add(
          FitChangeRow(
            id: 'cargo:$i',
            group: FitInventoryGroup.cargo,
            kind: FitChangeKind.removed,
            beforeTypeId: before.typeId,
            quantity: before.quantity,
          ),
        );
      }
    }
    return FitGroupDiff(group: FitInventoryGroup.cargo, rows: rows);
  }
}

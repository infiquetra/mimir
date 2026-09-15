import '../../fitting/domain/models.dart';
import 'aar_fit_snapshot.dart';

enum FitChangeKind { added, removed, modified, unchanged, replaced, unresolved }

/// Objective inventory difference row. Stable [id] uses source IDs, canonical
/// occurrence tuples and duplicate ordinals — never input-list position.
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

  /// Deterministic §5.2 matching: exact multiset cancel, then same-type
  /// canonical pairing, then recorded-slot replacements on the same hull.
  factory FitInventoryDiff.compare(
    AarFitSnapshot baseline,
    AarFitSnapshot candidate,
  ) {
    final sameHull =
        baseline.fitting.shipTypeId == candidate.fitting.shipTypeId;
    final idSeq = <String, int>{};
    final groups = <FitGroupDiff>[
      for (final group in _moduleGroups)
        _diffModules(
          group: group,
          baseline: baseline,
          candidate: candidate,
          sameHull: sameHull,
          idSeq: idSeq,
        ),
      _diffQuantified(
        group: FitInventoryGroup.drones,
        baseline: baseline,
        candidate: candidate,
        totals: _droneTotals,
        idSeq: idSeq,
      ),
      _diffQuantified(
        group: FitInventoryGroup.fighters,
        baseline: baseline,
        candidate: candidate,
        totals: _fighterTotals,
        idSeq: idSeq,
      ),
      _diffQuantified(
        group: FitInventoryGroup.cargo,
        baseline: baseline,
        candidate: candidate,
        totals: _cargoTotals,
        idSeq: idSeq,
      ),
    ];
    return FitInventoryDiff(
      baselineSnapshotId: baseline.snapshotId,
      candidateSnapshotId: candidate.snapshotId,
      baselineFingerprint: baseline.contentFingerprint,
      candidateFingerprint: candidate.contentFingerprint,
      sameHull: sameHull,
      groups: groups,
      unresolved: _unresolvedRows(baseline, candidate, idSeq),
    );
  }
}

const _moduleGroups = [
  FitInventoryGroup.high,
  FitInventoryGroup.mid,
  FitInventoryGroup.low,
  FitInventoryGroup.rigs,
  FitInventoryGroup.subsystems,
];

const _presentOnly = 'Present only in this record';
const _absentFromSupplied = 'Absent from supplied record';

class _ModuleOccurrence {
  _ModuleOccurrence({
    required this.group,
    required this.module,
    required this.chargeKnowledge,
    required this.stateKnowledge,
    required this.positions,
  });

  final FitInventoryGroup group;
  final FittedModule module;
  final ChargeKnowledge chargeKnowledge;
  final StateKnowledge stateKnowledge;
  final SlotPositionMeaning positions;

  int get typeId => module.typeId;
  int get slotIndex => module.slotIndex;
  ModuleState get state => module.state;
  int? get chargeTypeId => module.chargeTypeId;
  bool get recordedSlots => positions == SlotPositionMeaning.recorded;
  bool get hasLoadedCharge =>
      chargeKnowledge == ChargeKnowledge.recordedIdentity &&
      chargeTypeId != null;

  /// Exact-match key omits slot: physical movement is not a different item.
  String get exactKey {
    final chargeId = chargeKnowledge == ChargeKnowledge.recordedIdentity
        ? '${chargeTypeId ?? 'none'}'
        : '';
    return '$typeId|${chargeKnowledge.name}|$chargeId|${state.name}|${stateKnowledge.name}';
  }

  String get canonicalTuple {
    final chargeId = chargeKnowledge == ChargeKnowledge.recordedIdentity
        ? '${chargeTypeId ?? 'none'}'
        : chargeKnowledge.name;
    final slot = recordedSlots ? '$slotIndex' : '-';
    return '$typeId|$chargeId|${state.name}|${stateKnowledge.name}|$slot';
  }

  /// Total order for remaining same-type pairing. Input position is excluded.
  int compareCanonical(_ModuleOccurrence other) {
    final charge = _compareCharge(other);
    if (charge != 0) return charge;
    final stateCmp = state.index.compareTo(other.state.index);
    if (stateCmp != 0) return stateCmp;
    if (recordedSlots && other.recordedSlots) {
      final slotCmp = slotIndex.compareTo(other.slotIndex);
      if (slotCmp != 0) return slotCmp;
    }
    return stateKnowledge.index.compareTo(other.stateKnowledge.index);
  }

  int _compareCharge(_ModuleOccurrence other) {
    final rank = _chargeRank(
      chargeKnowledge,
    ).compareTo(_chargeRank(other.chargeKnowledge));
    if (rank != 0) return rank;
    if (chargeKnowledge != ChargeKnowledge.recordedIdentity ||
        other.chargeKnowledge != ChargeKnowledge.recordedIdentity) {
      return 0;
    }
    return _compareNullableInt(chargeTypeId, other.chargeTypeId);
  }
}

int _chargeRank(ChargeKnowledge knowledge) {
  switch (knowledge) {
    case ChargeKnowledge.unknown:
      return 0;
    case ChargeKnowledge.recordedAbsent:
      return 1;
    case ChargeKnowledge.recordedIdentity:
      return 2;
  }
}

int _compareNullableInt(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

List<FittedModule> _modulesOf(Fitting fitting, FitInventoryGroup group) {
  switch (group) {
    case FitInventoryGroup.high:
      return fitting.highSlots;
    case FitInventoryGroup.mid:
      return fitting.medSlots;
    case FitInventoryGroup.low:
      return fitting.lowSlots;
    case FitInventoryGroup.rigs:
      return fitting.rigSlots;
    case FitInventoryGroup.subsystems:
      return fitting.subsystems;
    case FitInventoryGroup.drones:
    case FitInventoryGroup.fighters:
    case FitInventoryGroup.cargo:
      return const [];
  }
}

List<_ModuleOccurrence> _occurrences(
  AarFitSnapshot snapshot,
  FitInventoryGroup group,
) {
  final modules = _modulesOf(snapshot.fitting, group);
  final positions = snapshot.knowledge.group(group).positions;
  return [
    for (var i = 0; i < modules.length; i++)
      _ModuleOccurrence(
        group: group,
        module: modules[i],
        chargeKnowledge: _chargeKnowledge(snapshot, group, i, modules[i]),
        stateKnowledge: _stateKnowledge(snapshot, group, i),
        positions: positions,
      ),
  ];
}

ChargeKnowledge _chargeKnowledge(
  AarFitSnapshot snapshot,
  FitInventoryGroup group,
  int listIndex,
  FittedModule module,
) {
  final recorded = _occurrenceKnowledge(snapshot, group, listIndex);
  if (recorded != null) return recorded.charge;
  if (module.chargeTypeId != null) return ChargeKnowledge.recordedIdentity;
  if (snapshot.knowledge.group(group).completeness ==
      InventoryCompleteness.recordedComplete) {
    return ChargeKnowledge.recordedAbsent;
  }
  return ChargeKnowledge.unknown;
}

StateKnowledge _stateKnowledge(
  AarFitSnapshot snapshot,
  FitInventoryGroup group,
  int listIndex,
) {
  final recorded = _occurrenceKnowledge(snapshot, group, listIndex);
  if (recorded != null) return recorded.state;
  return snapshot.knowledge.moduleState ??
      (snapshot.knowledge.group(group).completeness ==
              InventoryCompleteness.recordedComplete
          ? StateKnowledge.recorded
          : StateKnowledge.assumed);
}

FitOccurrenceKnowledge? _occurrenceKnowledge(
  AarFitSnapshot snapshot,
  FitInventoryGroup group,
  int listIndex,
) {
  final key = '${group.name}:$listIndex';
  for (final occurrence in snapshot.knowledge.occurrences) {
    if (occurrence.occurrenceKey == key) return occurrence;
  }
  return null;
}

FitGroupDiff _diffModules({
  required FitInventoryGroup group,
  required AarFitSnapshot baseline,
  required AarFitSnapshot candidate,
  required bool sameHull,
  required Map<String, int> idSeq,
}) {
  final before = _occurrences(baseline, group);
  final after = _occurrences(candidate, group);
  final baselineInfo = baseline.knowledge.group(group);
  final candidateInfo = candidate.knowledge.group(group);
  final baselineRecorded =
      baselineInfo.positions == SlotPositionMeaning.recorded;
  final candidateRecorded =
      candidateInfo.positions == SlotPositionMeaning.recorded;
  final slotMeaning = baselineRecorded && candidateRecorded
      ? SlotPositionMeaning.recorded
      : SlotPositionMeaning.orderOnly;

  final remainingBefore = [...before];
  final remainingAfter = [...after];
  final rows = <FitChangeRow>[];

  // Step 1: cancel exact (type, charge knowledge/identity, state/knowledge).
  _cancelExact(
    remainingBefore: remainingBefore,
    remainingAfter: remainingAfter,
    emit: (left, right) {
      rows.add(
        _moduleRow(
          baseline: baseline,
          candidate: candidate,
          group: group,
          kind: FitChangeKind.unchanged,
          before: left,
          after: right,
          slotMeaning: slotMeaning,
          qualification: null,
          idSeq: idSeq,
        ),
      );
    },
  );

  // Step 2: remaining same-type — equal recorded slots, then canonical order.
  final leftoverBefore = <_ModuleOccurrence>[];
  final leftoverAfter = <_ModuleOccurrence>[];
  final beforeByType = _byType(remainingBefore);
  final afterByType = _byType(remainingAfter);
  final typeIds = {...beforeByType.keys, ...afterByType.keys}.toList()..sort();
  for (final typeId in typeIds) {
    final typeBefore = [...?beforeByType[typeId]];
    final typeAfter = [...?afterByType[typeId]];
    if (baselineRecorded && candidateRecorded) {
      _pairEqualSlots(
        typeBefore,
        typeAfter,
        emit: (left, right) {
          rows.add(
            _pairedModuleRow(
              baseline: baseline,
              candidate: candidate,
              group: group,
              before: left,
              after: right,
              slotMeaning: slotMeaning,
              idSeq: idSeq,
            ),
          );
        },
      );
    }
    typeBefore.sort((a, b) => a.compareCanonical(b));
    typeAfter.sort((a, b) => a.compareCanonical(b));
    final paired = typeBefore.length < typeAfter.length
        ? typeBefore.length
        : typeAfter.length;
    for (var i = 0; i < paired; i++) {
      rows.add(
        _pairedModuleRow(
          baseline: baseline,
          candidate: candidate,
          group: group,
          before: typeBefore[i],
          after: typeAfter[i],
          slotMeaning: slotMeaning,
          idSeq: idSeq,
        ),
      );
    }
    leftoverBefore.addAll(typeBefore.skip(paired));
    leftoverAfter.addAll(typeAfter.skip(paired));
  }

  // Step 3: different types only at equal recorded physical slots on same hull.
  if (sameHull && baselineRecorded && candidateRecorded) {
    _pairEqualSlots(
      leftoverBefore,
      leftoverAfter,
      emit: (left, right) {
        rows.add(
          _moduleRow(
            baseline: baseline,
            candidate: candidate,
            group: group,
            kind: FitChangeKind.replaced,
            before: left,
            after: right,
            slotMeaning: slotMeaning,
            qualification: null,
            idSeq: idSeq,
          ),
        );
      },
    );
  }

  // Step 4: remaining Added/Removed in deterministic type/source order.
  leftoverBefore.sort((a, b) => a.compareCanonical(b));
  leftoverAfter.sort((a, b) => a.compareCanonical(b));
  for (final item in leftoverBefore) {
    rows.add(
      _moduleRow(
        baseline: baseline,
        candidate: candidate,
        group: group,
        kind: FitChangeKind.removed,
        before: item,
        after: null,
        slotMeaning: slotMeaning,
        qualification: _presenceQualification(
          kind: FitChangeKind.removed,
          baselineGroup: baselineInfo,
          candidateGroup: candidateInfo,
        ),
        idSeq: idSeq,
      ),
    );
  }
  for (final item in leftoverAfter) {
    rows.add(
      _moduleRow(
        baseline: baseline,
        candidate: candidate,
        group: group,
        kind: FitChangeKind.added,
        before: null,
        after: item,
        slotMeaning: slotMeaning,
        qualification: _presenceQualification(
          kind: FitChangeKind.added,
          baselineGroup: baselineInfo,
          candidateGroup: candidateInfo,
        ),
        idSeq: idSeq,
      ),
    );
  }

  return FitGroupDiff(group: group, rows: rows);
}

void _cancelExact({
  required List<_ModuleOccurrence> remainingBefore,
  required List<_ModuleOccurrence> remainingAfter,
  required void Function(_ModuleOccurrence before, _ModuleOccurrence after)
  emit,
}) {
  final afterByKey = <String, List<_ModuleOccurrence>>{};
  for (final item in remainingAfter) {
    afterByKey.putIfAbsent(item.exactKey, () => []).add(item);
  }
  for (final list in afterByKey.values) {
    list.sort((a, b) => a.compareCanonical(b));
  }
  remainingBefore.sort((a, b) => a.compareCanonical(b));
  final consumedBefore = <_ModuleOccurrence>[];
  for (final item in remainingBefore) {
    final matches = afterByKey[item.exactKey];
    if (matches == null || matches.isEmpty) continue;
    final partner = matches.removeAt(0);
    consumedBefore.add(item);
    remainingAfter.remove(partner);
    emit(item, partner);
  }
  for (final item in consumedBefore) {
    remainingBefore.remove(item);
  }
}

Map<int, List<_ModuleOccurrence>> _byType(List<_ModuleOccurrence> items) {
  final map = <int, List<_ModuleOccurrence>>{};
  for (final item in items) {
    map.putIfAbsent(item.typeId, () => []).add(item);
  }
  return map;
}

void _pairEqualSlots(
  List<_ModuleOccurrence> before,
  List<_ModuleOccurrence> after, {
  required void Function(_ModuleOccurrence before, _ModuleOccurrence after)
  emit,
}) {
  final afterBySlot = <int, List<_ModuleOccurrence>>{};
  for (final item in after) {
    afterBySlot.putIfAbsent(item.slotIndex, () => []).add(item);
  }
  final consumedBefore = <_ModuleOccurrence>[];
  final consumedAfter = <_ModuleOccurrence>[];
  for (final item in before) {
    final matches = afterBySlot[item.slotIndex];
    if (matches == null || matches.isEmpty) continue;
    final partner = matches.removeAt(0);
    consumedBefore.add(item);
    consumedAfter.add(partner);
    emit(item, partner);
  }
  for (final item in consumedBefore) {
    before.remove(item);
  }
  for (final item in consumedAfter) {
    after.remove(item);
  }
}

FitChangeRow _pairedModuleRow({
  required AarFitSnapshot baseline,
  required AarFitSnapshot candidate,
  required FitInventoryGroup group,
  required _ModuleOccurrence before,
  required _ModuleOccurrence after,
  required SlotPositionMeaning slotMeaning,
  required Map<String, int> idSeq,
}) {
  final sameConfig =
      before.chargeKnowledge == after.chargeKnowledge &&
      before.chargeTypeId == after.chargeTypeId &&
      before.state == after.state &&
      before.stateKnowledge == after.stateKnowledge;
  return _moduleRow(
    baseline: baseline,
    candidate: candidate,
    group: group,
    kind: sameConfig ? FitChangeKind.unchanged : FitChangeKind.modified,
    before: before,
    after: after,
    slotMeaning: slotMeaning,
    qualification: null,
    idSeq: idSeq,
  );
}

FitChangeRow _moduleRow({
  required AarFitSnapshot baseline,
  required AarFitSnapshot candidate,
  required FitInventoryGroup group,
  required FitChangeKind kind,
  required _ModuleOccurrence? before,
  required _ModuleOccurrence? after,
  required SlotPositionMeaning slotMeaning,
  required String? qualification,
  required Map<String, int> idSeq,
}) {
  final beforeTuple = before?.canonicalTuple ?? '';
  final afterTuple = after?.canonicalTuple ?? '';
  return FitChangeRow(
    id: _stableId(
      idSeq,
      [
        baseline.snapshotId,
        candidate.snapshotId,
        group.name,
        kind.name,
        beforeTuple,
        afterTuple,
      ].join(':'),
    ),
    group: group,
    kind: kind,
    beforeTypeId: before?.typeId,
    afterTypeId: after?.typeId,
    beforeChargeTypeId: before?.chargeTypeId,
    afterChargeTypeId: after?.chargeTypeId,
    beforeState: before?.state,
    afterState: after?.state,
    beforeSlotIndex: before?.slotIndex,
    afterSlotIndex: after?.slotIndex,
    slotMeaning: slotMeaning,
    chargeQuantityUnknown:
        (before?.hasLoadedCharge ?? false) ||
        (after?.hasLoadedCharge ?? false) ||
        ((after?.chargeTypeId ?? before?.chargeTypeId) != null),
    qualification: qualification,
  );
}

class _TypeTotal {
  const _TypeTotal({required this.quantity, this.inBay, this.inSpace});

  final int quantity;
  final int? inBay;
  final int? inSpace;
}

Map<int, _TypeTotal> _droneTotals(AarFitSnapshot snapshot) {
  final sums = <int, List<int>>{};
  for (final drone in snapshot.fitting.drones) {
    final current = sums[drone.typeId] ?? [0, 0, 0];
    sums[drone.typeId] = [
      _checkedAdd(current[0], drone.quantity),
      _checkedAdd(current[1], drone.inBay),
      _checkedAdd(current[2], drone.inSpace),
    ];
  }
  return {
    for (final entry in sums.entries)
      entry.key: _TypeTotal(
        quantity: entry.value[0],
        inBay: entry.value[1],
        inSpace: entry.value[2],
      ),
  };
}

Map<int, _TypeTotal> _fighterTotals(AarFitSnapshot snapshot) {
  final sums = <int, List<int>>{};
  for (final fighter in snapshot.fitting.fighters) {
    final current = sums[fighter.typeId] ?? [0, 0];
    sums[fighter.typeId] = [
      _checkedAdd(current[0], fighter.quantity),
      _checkedAdd(current[1], fighter.inSpace),
    ];
  }
  return {
    for (final entry in sums.entries)
      entry.key: _TypeTotal(quantity: entry.value[0], inSpace: entry.value[1]),
  };
}

Map<int, _TypeTotal> _cargoTotals(AarFitSnapshot snapshot) {
  final sums = <int, int>{};
  for (final item in snapshot.fitting.cargo) {
    sums[item.typeId] = _checkedAdd(sums[item.typeId] ?? 0, item.quantity);
  }
  return {
    for (final entry in sums.entries)
      entry.key: _TypeTotal(quantity: entry.value),
  };
}

FitGroupDiff _diffQuantified({
  required FitInventoryGroup group,
  required AarFitSnapshot baseline,
  required AarFitSnapshot candidate,
  required Map<int, _TypeTotal> Function(AarFitSnapshot snapshot) totals,
  required Map<String, int> idSeq,
}) {
  final before = totals(baseline);
  final after = totals(candidate);
  final baselineInfo = baseline.knowledge.group(group);
  final candidateInfo = candidate.knowledge.group(group);
  final typeIds = {...before.keys, ...after.keys}.toList()..sort();
  final rows = <FitChangeRow>[];
  for (final typeId in typeIds) {
    final left = before[typeId] ?? const _TypeTotal(quantity: 0);
    final right = after[typeId] ?? const _TypeTotal(quantity: 0);
    final delta = right.quantity - left.quantity;
    final bothPresent = left.quantity > 0 && right.quantity > 0;
    if (left.quantity == 0 && right.quantity > 0) {
      rows.add(
        _quantityRow(
          baseline: baseline,
          candidate: candidate,
          group: group,
          kind: FitChangeKind.added,
          typeId: typeId,
          quantity: delta,
          before: left,
          after: right,
          qualification: _presenceQualification(
            kind: FitChangeKind.added,
            baselineGroup: baselineInfo,
            candidateGroup: candidateInfo,
          ),
          idSeq: idSeq,
        ),
      );
    } else if (delta < 0) {
      // Quantity drop is a removal of units, even when some remain.
      rows.add(
        _quantityRow(
          baseline: baseline,
          candidate: candidate,
          group: group,
          kind: FitChangeKind.removed,
          typeId: typeId,
          quantity: -delta,
          before: left,
          after: right,
          qualification: _presenceQualification(
            kind: FitChangeKind.removed,
            baselineGroup: baselineInfo,
            candidateGroup: candidateInfo,
          ),
          idSeq: idSeq,
        ),
      );
    } else if (bothPresent && delta > 0) {
      rows.add(
        _quantityRow(
          baseline: baseline,
          candidate: candidate,
          group: group,
          kind: FitChangeKind.modified,
          typeId: typeId,
          quantity: delta,
          before: left,
          after: right,
          qualification: null,
          idSeq: idSeq,
        ),
      );
    }
    final deploymentChanged = _deploymentChanged(left, right);
    final alreadyModified = bothPresent && delta > 0;
    if (deploymentChanged && !alreadyModified) {
      rows.add(
        _quantityRow(
          baseline: baseline,
          candidate: candidate,
          group: group,
          kind: FitChangeKind.modified,
          typeId: typeId,
          quantity: right.quantity < left.quantity
              ? right.quantity
              : left.quantity,
          before: left,
          after: right,
          qualification: null,
          idSeq: idSeq,
        ),
      );
    } else if (!deploymentChanged &&
        delta == 0 &&
        (left.quantity > 0 || right.quantity > 0)) {
      rows.add(
        _quantityRow(
          baseline: baseline,
          candidate: candidate,
          group: group,
          kind: FitChangeKind.unchanged,
          typeId: typeId,
          quantity: left.quantity,
          before: left,
          after: right,
          qualification: null,
          idSeq: idSeq,
        ),
      );
    }
  }
  return FitGroupDiff(group: group, rows: rows);
}

bool _deploymentChanged(_TypeTotal before, _TypeTotal after) {
  if (before.quantity == 0 || after.quantity == 0) return false;
  if (before.inSpace != after.inSpace) return true;
  // inBay that simply tracks a quantity change is not a deployment change.
  if (before.quantity == after.quantity && before.inBay != after.inBay) {
    return true;
  }
  return false;
}

FitChangeRow _quantityRow({
  required AarFitSnapshot baseline,
  required AarFitSnapshot candidate,
  required FitInventoryGroup group,
  required FitChangeKind kind,
  required int typeId,
  required int quantity,
  required _TypeTotal before,
  required _TypeTotal after,
  required String? qualification,
  required Map<String, int> idSeq,
}) {
  return FitChangeRow(
    id: _stableId(
      idSeq,
      [
        baseline.snapshotId,
        candidate.snapshotId,
        group.name,
        kind.name,
        typeId,
      ].join(':'),
    ),
    group: group,
    kind: kind,
    beforeTypeId: before.quantity > 0 || kind == FitChangeKind.removed
        ? typeId
        : null,
    afterTypeId: after.quantity > 0 || kind == FitChangeKind.added
        ? typeId
        : null,
    quantity: quantity,
    beforeInBay: before.inBay,
    afterInBay: after.inBay,
    beforeInSpace: before.inSpace,
    afterInSpace: after.inSpace,
    qualification: qualification,
  );
}

List<FitChangeRow> _unresolvedRows(
  AarFitSnapshot baseline,
  AarFitSnapshot candidate,
  Map<String, int> idSeq,
) {
  final rows = <FitChangeRow>[];
  void addFrom(AarFitSnapshot snapshot, {required bool fromBaseline}) {
    final occupants = <UnresolvedOccupant>[
      for (final group in FitInventoryGroup.values)
        ...snapshot.knowledge.group(group).unresolvedOccupied,
      ...snapshot.knowledge.unplacedEntries,
    ];
    for (final occupant in occupants) {
      // Unknown identity stays occupied; labels never cancel two unknowns.
      rows.add(
        FitChangeRow(
          id: _stableId(
            idSeq,
            [
              snapshot.snapshotId,
              occupant.sourceEntryKey,
              occupant.group?.name ?? 'unplaced',
              occupant.physicalIndex ?? '',
              FitChangeKind.unresolved.name,
            ].join(':'),
          ),
          group: occupant.group ?? FitInventoryGroup.cargo,
          kind: FitChangeKind.unresolved,
          beforeTypeId: fromBaseline ? occupant.typeId : null,
          afterTypeId: fromBaseline ? null : occupant.typeId,
          quantity: occupant.quantity ?? 1,
          qualification: occupant.label.isEmpty ? null : occupant.label,
        ),
      );
    }
  }

  addFrom(baseline, fromBaseline: true);
  addFrom(candidate, fromBaseline: false);
  return rows;
}

String? _presenceQualification({
  required FitChangeKind kind,
  required FitGroupKnowledge baselineGroup,
  required FitGroupKnowledge candidateGroup,
}) {
  final baselineIncomplete =
      baselineGroup.completeness != InventoryCompleteness.recordedComplete;
  final candidateIncomplete =
      candidateGroup.completeness != InventoryCompleteness.recordedComplete;
  if (kind == FitChangeKind.added && baselineIncomplete) {
    return _presentOnly;
  }
  if (kind == FitChangeKind.removed && candidateIncomplete) {
    return _absentFromSupplied;
  }
  if (kind == FitChangeKind.removed && baselineIncomplete) {
    return _absentFromSupplied;
  }
  if (kind == FitChangeKind.added && candidateIncomplete) {
    return _presentOnly;
  }
  return null;
}

String _stableId(Map<String, int> idSeq, String stem) {
  final ordinal = idSeq[stem] ?? 0;
  idSeq[stem] = ordinal + 1;
  return '$stem#$ordinal';
}

const _maxQuantity = 0x7fffffff;

int _checkedAdd(int a, int b) {
  if (a < 0 || b < 0) {
    throw StateError('quantity must be non-negative');
  }
  final sum = a + b;
  if (sum > _maxQuantity) {
    throw StateError('quantity overflow');
  }
  return sum;
}

import 'aar_fit_comparison.dart';
import 'aar_fit_snapshot.dart';

/// One physical type in a bill of materials. A missing count stays null; it is
/// never treated as zero.
class FitBomLine {
  const FitBomLine({
    required this.typeId,
    this.requiredCount,
    this.observedDelta,
    this.targetCount,
    this.quantityUnknown = false,
    this.qualification,
  });

  final int typeId;
  final int? requiredCount;
  final int? observedDelta;
  final int? targetCount;
  final bool quantityUnknown;
  final String? qualification;
}

class FitBillOfMaterials {
  const FitBillOfMaterials({
    this.targetSnapshotId,
    this.baselineSnapshotId,
    this.mode = AarBomMode.changes,
    this.complete = true,
    this.requirements = const [],
    this.removals = const [],
    this.unquantifiedCharges = const [],
    this.limitations = const [],
    this.heading,
  });

  final String? targetSnapshotId;
  final String? baselineSnapshotId;
  final AarBomMode mode;
  final bool complete;
  final List<FitBomLine> requirements;
  final List<FitBomLine> removals;
  final List<int> unquantifiedCharges;
  final List<String> limitations;
  final String? heading;

  FitBomLine? requirement(int typeId) {
    for (final line in requirements) {
      if (line.typeId == typeId) return line;
    }
    return null;
  }

  FitBomLine? removal(int typeId) {
    for (final line in removals) {
      if (line.typeId == typeId) return line;
    }
    return null;
  }

  /// Global physical counts across every group, then Changes or Full
  /// replacement arithmetic. Loaded charges without quantity stay unquantified.
  factory FitBillOfMaterials.fromSnapshots({
    required AarFitSnapshot baseline,
    required AarFitSnapshot target,
    AarBomMode mode = AarBomMode.changes,
  }) {
    final before = _physicalCounts(baseline);
    final after = _physicalCounts(target);
    final unquantified = {
      ...before.loadedCharges,
      ...after.loadedCharges,
    }.toList()..sort();
    final typeIds = {...before.counts.keys, ...after.counts.keys}.toList()
      ..sort();

    final requirements = <FitBomLine>[];
    final removals = <FitBomLine>[];
    var anyUnknown = false;

    for (final typeId in typeIds) {
      final baselineCount = before.counts[typeId] ?? 0;
      final targetCount = after.counts[typeId] ?? 0;
      final observedDelta = targetCount - baselineCount;
      final baselineExact = _typeCountExact(baseline, typeId);
      final targetExact = _typeCountExact(target, typeId);

      if (mode == AarBomMode.fullReplacement) {
        if (targetCount == 0 && targetExact) continue;
        final unknown = !targetExact;
        if (unknown) anyUnknown = true;
        requirements.add(
          FitBomLine(
            typeId: typeId,
            requiredCount: unknown ? null : targetCount,
            observedDelta: observedDelta,
            targetCount: targetCount,
            quantityUnknown: unknown,
            qualification: unknown ? 'Incomplete change list' : null,
          ),
        );
        continue;
      }

      final deltaExact = baselineExact && targetExact;
      if (observedDelta > 0 || (!deltaExact && targetCount > 0)) {
        final unknown = !deltaExact;
        if (unknown) anyUnknown = true;
        requirements.add(
          FitBomLine(
            typeId: typeId,
            requiredCount: unknown ? null : observedDelta,
            observedDelta: observedDelta,
            targetCount: targetCount,
            quantityUnknown: unknown,
            qualification: unknown
                ? (baselineCount == 0
                      ? 'Not present in baseline record'
                      : 'Incomplete change list')
                : null,
          ),
        );
      } else if (observedDelta < 0 || (!deltaExact && baselineCount > 0)) {
        final unknown = !deltaExact;
        if (unknown) anyUnknown = true;
        removals.add(
          FitBomLine(
            typeId: typeId,
            requiredCount: unknown ? null : -observedDelta,
            observedDelta: observedDelta,
            targetCount: targetCount,
            quantityUnknown: unknown,
            qualification: unknown ? 'Incomplete change list' : null,
          ),
        );
      }
    }

    final targetComplete = _snapshotCountsComplete(target);
    final baselineComplete = _snapshotCountsComplete(baseline);
    final complete = mode == AarBomMode.fullReplacement
        ? targetComplete && !anyUnknown
        : targetComplete && baselineComplete && !anyUnknown;

    return FitBillOfMaterials(
      targetSnapshotId: target.snapshotId,
      baselineSnapshotId: baseline.snapshotId,
      mode: mode,
      complete: complete,
      requirements: requirements,
      removals: removals,
      unquantifiedCharges: unquantified,
      heading: _heading(mode: mode, complete: complete),
    );
  }
}

class _PhysicalCounts {
  const _PhysicalCounts({required this.counts, required this.loadedCharges});

  final Map<int, int> counts;
  final Set<int> loadedCharges;
}

_PhysicalCounts _physicalCounts(AarFitSnapshot snapshot) {
  final counts = <int, int>{};
  final loadedCharges = <int>{};

  void add(int typeId, int quantity) {
    counts[typeId] = _checkedAdd(counts[typeId] ?? 0, quantity);
  }

  add(snapshot.fitting.shipTypeId, 1);
  for (final module in snapshot.fitting.allModules) {
    add(module.typeId, 1);
    final chargeId = module.chargeTypeId;
    if (chargeId != null) loadedCharges.add(chargeId);
  }
  for (final drone in snapshot.fitting.drones) {
    add(drone.typeId, drone.quantity);
  }
  for (final fighter in snapshot.fitting.fighters) {
    add(fighter.typeId, fighter.quantity);
  }
  for (final cargo in snapshot.fitting.cargo) {
    add(cargo.typeId, cargo.quantity);
  }
  return _PhysicalCounts(counts: counts, loadedCharges: loadedCharges);
}

bool _snapshotCountsComplete(AarFitSnapshot snapshot) {
  if (snapshot.knowledge.unplacedEntries.isNotEmpty) return false;
  for (final group in FitInventoryGroup.values) {
    final info = snapshot.knowledge.group(group);
    if (info.applicability == GroupApplicability.notApplicable) continue;
    if (info.completeness != InventoryCompleteness.recordedComplete) {
      return false;
    }
    if (info.unresolvedOccupied.isNotEmpty) return false;
  }
  return true;
}

/// A type's count is exact only when every unknown/incomplete group is
/// provably unable to contain it. Unknown-identity occupants taint every type.
bool _typeCountExact(AarFitSnapshot snapshot, int typeId) {
  for (final occupant in snapshot.knowledge.unplacedEntries) {
    if (occupant.typeId == null || occupant.typeId == typeId) {
      return false;
    }
  }
  for (final group in FitInventoryGroup.values) {
    final info = snapshot.knowledge.group(group);
    if (info.applicability == GroupApplicability.notApplicable) continue;
    final unresolvedTaint = info.unresolvedOccupied.any(
      (occupant) => occupant.typeId == null || occupant.typeId == typeId,
    );
    final incomplete =
        info.completeness != InventoryCompleteness.recordedComplete;
    if (!incomplete && !unresolvedTaint) continue;
    if (_groupProvablyCannotContain(group, typeId, snapshot)) continue;
    return false;
  }
  return true;
}

bool _groupProvablyCannotContain(
  FitInventoryGroup group,
  int typeId,
  AarFitSnapshot snapshot,
) {
  // Without SDE metadata the only proven exclusion is the fitted hull itself
  // living outside slot/drone/fighter groups. Cargo can hold any type.
  if (typeId == snapshot.fitting.shipTypeId &&
      group != FitInventoryGroup.cargo) {
    return true;
  }
  return false;
}

String _heading({required AarBomMode mode, required bool complete}) {
  if (mode == AarBomMode.fullReplacement) {
    return complete ? 'Full replacement' : 'Incomplete full replacement';
  }
  return complete ? 'Changes from baseline' : 'Incomplete change list';
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

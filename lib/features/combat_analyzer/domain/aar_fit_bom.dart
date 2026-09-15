import 'aar_fit_comparison.dart';
import 'aar_fit_snapshot.dart';

/// Compile stub for W3. GREEN nets physical counts across groups, keeps
/// unknown quantities nullable, and never treats missing records as zero.
class FitBomLine {
  const FitBomLine({
    required this.typeId,
    this.requiredCount = 0,
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

  /// Naive: fitted-module counts only, drone groups as 1, missing as zero.
  factory FitBillOfMaterials.fromSnapshots({
    required AarFitSnapshot baseline,
    required AarFitSnapshot target,
    AarBomMode mode = AarBomMode.changes,
  }) {
    final before = _fittedCounts(baseline);
    final after = _fittedCounts(target);
    final types = {...before.keys, ...after.keys};
    final requirements = <FitBomLine>[];
    final removals = <FitBomLine>[];
    for (final typeId in types) {
      final b = before[typeId] ?? 0;
      final a = after[typeId] ?? 0;
      if (mode == AarBomMode.fullReplacement) {
        if (a > 0) {
          requirements.add(
            FitBomLine(typeId: typeId, requiredCount: a, targetCount: a),
          );
        }
      } else {
        final delta = a - b;
        if (delta > 0) {
          requirements.add(
            FitBomLine(
              typeId: typeId,
              requiredCount: delta,
              observedDelta: delta,
              targetCount: a,
            ),
          );
        } else if (delta < 0) {
          removals.add(
            FitBomLine(
              typeId: typeId,
              requiredCount: -delta,
              observedDelta: delta,
              targetCount: a,
            ),
          );
        }
      }
    }
    return FitBillOfMaterials(
      targetSnapshotId: target.snapshotId,
      baselineSnapshotId: baseline.snapshotId,
      mode: mode,
      complete: true,
      requirements: requirements,
      removals: removals,
    );
  }

  static Map<int, int> _fittedCounts(AarFitSnapshot snapshot) {
    final counts = <int, int>{};
    void add(int typeId, int quantity) {
      counts[typeId] = (counts[typeId] ?? 0) + quantity;
    }

    for (final module in snapshot.fitting.allModules) {
      add(module.typeId, 1);
    }
    for (final drone in snapshot.fitting.drones) {
      add(drone.typeId, 1);
    }
    for (final fighter in snapshot.fitting.fighters) {
      add(fighter.typeId, 1);
    }
    return counts;
  }
}

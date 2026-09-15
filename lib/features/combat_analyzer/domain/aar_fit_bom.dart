import 'aar_fit_comparison.dart';

/// Type shell for W3 bill of materials. Algorithms land in W3.
class FitBillOfMaterials {
  const FitBillOfMaterials({
    this.targetSnapshotId,
    this.baselineSnapshotId,
    this.mode = AarBomMode.changes,
  });

  final String? targetSnapshotId;
  final String? baselineSnapshotId;
  final AarBomMode mode;
}

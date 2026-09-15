/// Type shell for W3 inventory matching. Algorithms land in W3.
class FitInventoryDiff {
  const FitInventoryDiff({
    this.baselineSnapshotId,
    this.candidateSnapshotId,
    this.baselineFingerprint,
    this.candidateFingerprint,
  });

  final String? baselineSnapshotId;
  final String? candidateSnapshotId;
  final String? baselineFingerprint;
  final String? candidateFingerprint;
}

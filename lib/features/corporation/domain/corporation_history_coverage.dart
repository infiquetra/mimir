/// Naive C6: pruned history is treated as still refetchable from ESI.
class WalletHistoryCoverage {
  const WalletHistoryCoverage({
    this.refetchableFromEsi = true,
    this.retainedDays = 365,
  });

  final bool refetchableFromEsi;
  final int retainedDays;
}

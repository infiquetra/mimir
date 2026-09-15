enum AarComparisonLayoutMode {
  stacked,
  baselinePlusOne,
  baselinePlusTwo,
  fourColumn,
}

AarComparisonLayoutMode aarComparisonLayoutModeForWidth(
  double width, {
  double textScale = 1.0,
}) {
  final effective = textScale <= 1 ? width : width / textScale;
  if (effective >= 1440) return AarComparisonLayoutMode.fourColumn;
  if (effective >= 1000) return AarComparisonLayoutMode.baselinePlusTwo;
  if (effective >= 720) return AarComparisonLayoutMode.baselinePlusOne;
  return AarComparisonLayoutMode.stacked;
}

String aarComparisonDisplayName({
  int? typeId,
  String? storedName,
  bool hull = false,
}) {
  final fallback = hull ? 'Unknown ship' : 'Unresolved module';
  final name = storedName?.trim() ?? '';
  if (name.isEmpty) return fallback;
  if (RegExp(r'^(Type|Ship) #\d+$').hasMatch(name)) return fallback;
  if (typeId != null) {
    final id = '$typeId';
    if (name == id || name.contains(id)) return fallback;
  }
  return name;
}

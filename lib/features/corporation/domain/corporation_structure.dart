import 'corporation_access.dart';

enum StructureServiceState { online, offline, cleanup, unknown, missing, empty }

class CorporationStructure {
  const CorporationStructure({
    required this.id,
    required this.name,
    this.fuelExpiresAt,
    this.stateTimer,
    this.reinforceAt,
    this.unanchorAt,
    this.services = const [],
  });

  final int id;
  final String name;
  final DateTime? fuelExpiresAt;
  final DateTime? stateTimer;
  final DateTime? reinforceAt;
  final DateTime? unanchorAt;
  final List<StructureServiceState> services;
}

class CorporationStructureView {
  const CorporationStructureView();

  /// Elapsed timers stay "awaiting update"; they never invent Abandoned or
  /// reinforcement transitions.
  String timerCaption(DateTime? timer, DateTime now) {
    if (timer == null) return 'Unknown';
    if (timer.isAfter(now)) return 'Active';
    return 'Awaiting updated state';
  }

  bool visibleWithoutAssets(RoleEvidence roles) {
    return roles.isStationManager || roles.isDirector;
  }
}

import '../../fitting/domain/models.dart';
import 'aar_fit_snapshot.dart';

enum AarProposalOrigin { ai, savedReference, importedReference }

enum AarProposalValidationStatus {
  validated,
  partial,
  invalid,
  unsupportedVersion,
  localDataUnavailable,
}

class AarFitProposal {
  AarFitProposal({
    this.schemaVersion = 1,
    required this.proposalId,
    required this.origin,
    required this.encounterId,
    this.baselineSnapshotId,
    this.baselineFingerprint,
    this.target,
    this.status = AarProposalValidationStatus.validated,
    this.rationale = '',
    List<String> limitations = const [],
  }) : limitations = List<String>.from(limitations);

  final int schemaVersion;
  final String proposalId;
  final AarProposalOrigin origin;
  final String encounterId;
  final String? baselineSnapshotId;
  final String? baselineFingerprint;
  final AarFitSnapshot? target;
  final AarProposalValidationStatus status;
  final String rationale;
  final List<String> limitations;

  factory AarFitProposal.fromRaw({
    required Map<String, dynamic> raw,
    required String encounterId,
    required String proposalId,
    AarProposalOrigin origin = AarProposalOrigin.ai,
    String? baselineSnapshotId,
    String? baselineFingerprint,
    bool Function(int typeId)? isKnownType,
  }) {
    final schemaVersion = _asInt(raw['schemaVersion']) ?? 1;
    final rationale = raw['rationale']?.toString() ?? '';
    final limitations = [
      for (final value in raw['limitations'] as List? ?? const [])
        value.toString(),
    ];
    final stampedBaselineId = baselineSnapshotId;
    final stampedFingerprint = baselineFingerprint;

    AarFitProposal result({
      required AarProposalValidationStatus status,
      AarFitSnapshot? target,
      List<String>? extraLimitations,
    }) {
      return AarFitProposal(
        schemaVersion: schemaVersion,
        proposalId: proposalId,
        origin: origin,
        encounterId: encounterId,
        baselineSnapshotId: stampedBaselineId,
        baselineFingerprint: stampedFingerprint,
        target: target,
        status: status,
        rationale: rationale,
        limitations: [...limitations, ...?extraLimitations],
      );
    }

    if (schemaVersion != 1) {
      return result(
        status: AarProposalValidationStatus.unsupportedVersion,
        target: null,
      );
    }

    final targetJson = raw['target'];
    if (targetJson is! Map) {
      return result(status: AarProposalValidationStatus.invalid, target: null);
    }
    final targetMap = Map<String, dynamic>.from(targetJson);
    final shipTypeId = _asInt(targetMap['shipTypeId']);
    if (shipTypeId == null || shipTypeId <= 0) {
      return result(status: AarProposalValidationStatus.invalid, target: null);
    }
    final groups = targetMap['groups'];
    if (groups is! Map) {
      return result(status: AarProposalValidationStatus.invalid, target: null);
    }

    if (_hasBadStackQuantity(groups) || _hasSlotCollision(groups)) {
      return result(status: AarProposalValidationStatus.invalid);
    }

    final typeIds = _typeIdsFromGroups(shipTypeId, groups);
    final known = isKnownType ?? _defaultTypeKnown;
    if (typeIds.any((id) => !known(id))) {
      return result(status: AarProposalValidationStatus.localDataUnavailable);
    }

    final rawEncounterId = raw['encounterId']?.toString();
    final rawBaselineId = raw['baselineSnapshotId']?.toString();
    final mismatch =
        (rawEncounterId != null && rawEncounterId != encounterId) ||
        (stampedBaselineId != null &&
            rawBaselineId != null &&
            rawBaselineId != stampedBaselineId);

    final fitting = _fittingFromCandidateGroups(
      id: proposalId,
      name: raw['label']?.toString() ?? proposalId,
      shipTypeId: shipTypeId,
      shipName: targetMap['shipName']?.toString() ?? '',
      groups: groups,
    );
    final target = AarFitSnapshot.fromStructuredCandidate(
      encounterId: encounterId,
      fitting: fitting,
      raw: raw,
    );
    _addBudgetWarnings(raw['stats'], limitations);
    if (mismatch) {
      return result(
        status: AarProposalValidationStatus.invalid,
        target: target,
      );
    }
    return result(status: _statusForGroups(groups), target: target);
  }

  static Fitting _fittingFromCandidateGroups({
    required String id,
    required String name,
    required int shipTypeId,
    required String shipName,
    required Object? groups,
  }) {
    final map = groups is Map
        ? Map<String, dynamic>.from(groups)
        : const <String, dynamic>{};
    return Fitting(
      id: id,
      name: name,
      shipTypeId: shipTypeId,
      shipName: shipName,
      highSlots: _modulesFromGroup(map['high'], SlotType.high),
      medSlots: _modulesFromGroup(map['mid'], SlotType.med),
      lowSlots: _modulesFromGroup(map['low'], SlotType.low),
      rigSlots: _modulesFromGroup(map['rigs'], SlotType.rig),
      subsystems: _modulesFromGroup(map['subsystems'], SlotType.subsystem),
      drones: _dronesFromGroup(map['drones']),
      fighters: _fightersFromGroup(map['fighters']),
      cargo: _cargoFromGroup(map['cargo']),
    );
  }

  static List<FittedModule> _modulesFromGroup(Object? group, SlotType slot) {
    final items = group is Map ? group['items'] : null;
    if (items is! List) return const [];
    return [
      for (var i = 0; i < items.length; i++)
        if (items[i] is Map)
          _moduleFromItem(Map<String, dynamic>.from(items[i] as Map), slot, i),
    ];
  }

  static FittedModule _moduleFromItem(
    Map<String, dynamic> item,
    SlotType slot,
    int index,
  ) {
    return FittedModule(
      typeId: _asInt(item['typeId']) ?? 0,
      typeName: item['typeName']?.toString() ?? '',
      slotType: slot,
      slotIndex: _asInt(item['slotIndex']) ?? index,
      state: ModuleState.values.firstWhere(
        (value) => value.name == item['state']?.toString(),
        orElse: () => ModuleState.active,
      ),
      chargeTypeId: _asInt(item['chargeTypeId']),
      chargeName: item['chargeName']?.toString(),
    );
  }

  static List<DroneGroup> _dronesFromGroup(Object? group) {
    final items = group is Map ? group['items'] : null;
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          DroneGroup(
            typeId: item['typeId'] as int? ?? 0,
            typeName: item['typeName']?.toString() ?? '',
            quantity: item['quantity'] as int? ?? 0,
          ),
    ];
  }

  static List<FighterGroup> _fightersFromGroup(Object? group) {
    final items = group is Map ? group['items'] : null;
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          FighterGroup(
            typeId: _asInt(item['typeId']) ?? 0,
            typeName: item['typeName']?.toString() ?? '',
            quantity: _asInt(item['quantity']) ?? 0,
          ),
    ];
  }

  static List<CargoItem> _cargoFromGroup(Object? group) {
    final items = group is Map ? group['items'] : null;
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          CargoItem(
            typeId: item['typeId'] as int? ?? 0,
            typeName: item['typeName']?.toString() ?? '',
            quantity: item['quantity'] as int? ?? 0,
          ),
    ];
  }

  static AarProposalValidationStatus _statusForGroups(Object? groups) {
    if (groups is! Map) return AarProposalValidationStatus.invalid;
    final present = groups.keys.map((key) => key.toString()).toSet();
    const required = {
      'high',
      'mid',
      'low',
      'rigs',
      'subsystems',
      'drones',
      'fighters',
      'cargo',
    };
    if (present.containsAll(required)) {
      return AarProposalValidationStatus.validated;
    }
    if (present.isEmpty) return AarProposalValidationStatus.invalid;
    return AarProposalValidationStatus.partial;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'proposalId': proposalId,
    'origin': origin.name,
    'encounterId': encounterId,
    if (baselineSnapshotId != null) 'baselineSnapshotId': baselineSnapshotId,
    if (baselineFingerprint != null) 'baselineFingerprint': baselineFingerprint,
    if (target != null) 'target': target!.toJson(),
    'status': status.name,
    'rationale': rationale,
    'limitations': limitations,
  };

  factory AarFitProposal.fromJson(Map<String, dynamic> json) {
    return AarFitProposal(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      proposalId: json['proposalId']?.toString() ?? '',
      origin: AarProposalOrigin.values.firstWhere(
        (value) => value.name == json['origin']?.toString(),
        orElse: () => AarProposalOrigin.importedReference,
      ),
      encounterId: json['encounterId']?.toString() ?? '',
      baselineSnapshotId: json['baselineSnapshotId']?.toString(),
      baselineFingerprint: json['baselineFingerprint']?.toString(),
      target: json['target'] is Map
          ? AarFitSnapshot.fromJson(
              Map<String, dynamic>.from(json['target'] as Map),
            )
          : null,
      status: AarProposalValidationStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => AarProposalValidationStatus.invalid,
      ),
      rationale: json['rationale']?.toString() ?? '',
      limitations: [
        for (final value in json['limitations'] as List? ?? const [])
          value.toString(),
      ],
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool _defaultTypeKnown(int typeId) {
  if (typeId <= 0) return false;
  // 99999 is the AAR unresolved-type sentinel (kAarMysteryTypeId).
  return typeId < 99999;
}

bool _hasSlotCollision(Map<dynamic, dynamic> groups) {
  const slotted = {'high', 'mid', 'low', 'rigs', 'subsystems'};
  for (final name in slotted) {
    final items = _groupItems(groups[name]);
    if (items == null) continue;
    final seen = <int>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) continue;
      final slot = _asInt(item['slotIndex']) ?? i;
      if (!seen.add(slot)) return true;
    }
  }
  return false;
}

bool _hasBadStackQuantity(Map<dynamic, dynamic> groups) {
  const stacks = {'drones', 'fighters', 'cargo'};
  for (final name in stacks) {
    final items = _groupItems(groups[name]);
    if (items == null) continue;
    for (final item in items) {
      if (item is! Map) continue;
      final quantity = _asInt(item['quantity']);
      if (quantity == null || quantity <= 0) return true;
    }
  }
  return false;
}

List<dynamic>? _groupItems(Object? group) {
  if (group is! Map) return null;
  final items = group['items'];
  return items is List ? items : null;
}

Set<int> _typeIdsFromGroups(int shipTypeId, Map<dynamic, dynamic> groups) {
  final ids = <int>{shipTypeId};
  for (final group in groups.values) {
    final items = _groupItems(group);
    if (items == null) continue;
    for (final item in items) {
      if (item is! Map) continue;
      final typeId = _asInt(item['typeId']);
      if (typeId != null) ids.add(typeId);
      final chargeId = _asInt(item['chargeTypeId']);
      if (chargeId != null) ids.add(chargeId);
    }
  }
  return ids;
}

void _addBudgetWarnings(Object? stats, List<String> limitations) {
  if (stats is! Map) return;
  final cpuUsed = (stats['cpuUsed'] as num?)?.toDouble();
  final cpuMax = (stats['cpuMax'] as num?)?.toDouble();
  final powerUsed = (stats['powerUsed'] as num?)?.toDouble();
  final powerMax = (stats['powerMax'] as num?)?.toDouble();
  if (cpuUsed != null && cpuMax != null && cpuUsed > cpuMax) {
    limitations.add('Fitting exceeds CPU budget.');
  }
  if (powerUsed != null && powerMax != null && powerUsed > powerMax) {
    limitations.add('Fitting exceeds power budget.');
  }
}

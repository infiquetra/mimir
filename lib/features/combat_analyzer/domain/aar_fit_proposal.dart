import '../../fitting/domain/models.dart';
import 'aar_fit_snapshot.dart';
import 'combat_evidence_ledger.dart';

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
  }) {
    final targetJson = raw['target'];
    final targetMap = targetJson is Map
        ? Map<String, dynamic>.from(targetJson)
        : const <String, dynamic>{};
    final groups = targetMap['groups'];
    final fitting = _fittingFromCandidateGroups(
      id: proposalId,
      name: raw['label']?.toString() ?? proposalId,
      shipTypeId: targetMap['shipTypeId'] as int? ?? 0,
      shipName: targetMap['shipName']?.toString() ?? '',
      groups: groups,
    );
    final generatedConfidence = raw['confidence']?.toString();
    return AarFitProposal(
      schemaVersion: raw['schemaVersion'] as int? ?? 1,
      proposalId: proposalId,
      origin: origin,
      encounterId: raw['encounterId']?.toString() ?? encounterId,
      baselineSnapshotId:
          raw['baselineSnapshotId']?.toString() ?? baselineSnapshotId,
      baselineFingerprint:
          raw['baselineFingerprint']?.toString() ?? baselineFingerprint,
      target: targetJson == null
          ? AarFitSnapshot.fromStructuredCandidate(
              encounterId: encounterId,
              fitting: fitting,
              raw: raw,
              confidence: generatedConfidence == 'confirmed'
                  ? EvidenceConfidence.confirmed
                  : null,
            )
          : AarFitSnapshot.fromStructuredCandidate(
              encounterId: encounterId,
              fitting: fitting,
              raw: raw,
              confidence: generatedConfidence == 'confirmed'
                  ? EvidenceConfidence.confirmed
                  : null,
            ),
      status: _statusForGroups(groups),
      rationale: raw['rationale']?.toString() ?? '',
    );
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
    final attrs = <int, double>{};
    final rawAttrs = item['attributes'];
    if (rawAttrs is Map) {
      for (final entry in rawAttrs.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = (entry.value as num?)?.toDouble();
        if (key != null && value != null) attrs[key] = value;
      }
    }
    return FittedModule(
      typeId: item['typeId'] as int? ?? 0,
      typeName: item['typeName']?.toString() ?? '',
      slotType: slot,
      slotIndex: item['slotIndex'] as int? ?? index,
      state: ModuleState.values.firstWhere(
        (value) => value.name == item['state']?.toString(),
        orElse: () => ModuleState.active,
      ),
      chargeTypeId: item['chargeTypeId'] as int?,
      chargeName: item['chargeName']?.toString(),
      attributes: attrs,
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

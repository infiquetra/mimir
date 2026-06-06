import '../../fitting/domain/models.dart';

enum EvidenceSource {
  combatLog,
  killmail,
  zkill,
  sde,
  currentShipSnapshot,
  manualFitImport,
}

enum EvidenceConfidence { proven, confirmed, derived, reference, unknown }

enum AarUnknownCategory {
  pilotFit,
  opponentFit,
  range,
  pilotingIntent,
  tankLayer,
  fleetContext,
  telemetry,
}

enum FitEvidenceRole { pilot, victim, opponent, reference }

class CombatEvidenceLedger {
  const CombatEvidenceLedger({this.facts = const [], this.unknowns = const []});

  final List<CombatEvidenceFact> facts;
  final List<AarUnknown> unknowns;

  bool get isEmpty => facts.isEmpty && unknowns.isEmpty;

  Map<String, dynamic> toJson() => {
    'facts': facts.map((fact) => fact.toJson()).toList(),
    'unknowns': unknowns.map((unknown) => unknown.toJson()).toList(),
  };

  factory CombatEvidenceLedger.fromJson(Map<String, dynamic> json) {
    return CombatEvidenceLedger(
      facts: _objectList(
        json['facts'],
      ).map(CombatEvidenceFact.fromJson).toList(),
      unknowns: _objectList(json['unknowns']).map(AarUnknown.fromJson).toList(),
    );
  }
}

class CombatEvidenceFact {
  const CombatEvidenceFact({
    required this.id,
    required this.label,
    required this.value,
    required this.source,
    required this.confidence,
    this.evidenceTime,
    this.limitations = const [],
  });

  final String id;
  final String label;
  final String value;
  final EvidenceSource source;
  final EvidenceConfidence confidence;
  final DateTime? evidenceTime;
  final List<String> limitations;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'value': value,
    'source': source.name,
    'confidence': confidence.name,
    if (evidenceTime != null)
      'evidenceTime': evidenceTime!.toUtc().toIso8601String(),
    'limitations': limitations,
  };

  factory CombatEvidenceFact.fromJson(Map<String, dynamic> json) {
    return CombatEvidenceFact(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      source: _enumFromName(
        EvidenceSource.values,
        json['source']?.toString(),
        EvidenceSource.combatLog,
      ),
      confidence: _enumFromName(
        EvidenceConfidence.values,
        json['confidence']?.toString(),
        EvidenceConfidence.unknown,
      ),
      evidenceTime: DateTime.tryParse(json['evidenceTime']?.toString() ?? ''),
      limitations: _stringList(json['limitations']),
    );
  }
}

class AarUnknown {
  const AarUnknown({
    required this.category,
    required this.label,
    required this.detail,
  });

  final AarUnknownCategory category;
  final String label;
  final String detail;

  Map<String, dynamic> toJson() => {
    'category': category.name,
    'label': label,
    'detail': detail,
  };

  factory AarUnknown.fromJson(Map<String, dynamic> json) {
    return AarUnknown(
      category: _enumFromName(
        AarUnknownCategory.values,
        json['category']?.toString(),
        AarUnknownCategory.telemetry,
      ),
      label: json['label']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
    );
  }
}

class FitEvidence {
  const FitEvidence({
    required this.role,
    required this.source,
    required this.confidence,
    required this.fitting,
    this.evidenceTime,
    this.limitations = const [],
  });

  final FitEvidenceRole role;
  final EvidenceSource source;
  final EvidenceConfidence confidence;
  final Fitting fitting;
  final DateTime? evidenceTime;
  final List<String> limitations;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'source': source.name,
    'confidence': confidence.name,
    'fitting': fitting.toJson(),
    if (evidenceTime != null)
      'evidenceTime': evidenceTime!.toUtc().toIso8601String(),
    'limitations': limitations,
  };

  Map<String, dynamic> toPromptJson() => {
    'role': role.name,
    'source': source.name,
    'confidence': confidence.name,
    'shipTypeId': fitting.shipTypeId,
    'shipName': fitting.shipName,
    'highSlots': _modulesForPrompt(fitting.highSlots),
    'medSlots': _modulesForPrompt(fitting.medSlots),
    'lowSlots': _modulesForPrompt(fitting.lowSlots),
    'rigSlots': _modulesForPrompt(fitting.rigSlots),
    'subsystems': _modulesForPrompt(fitting.subsystems),
    'drones': fitting.drones.map((drone) => drone.toJson()).toList(),
    'cargo': fitting.cargo.map((item) => item.toJson()).toList(),
    if (evidenceTime != null)
      'evidenceTime': evidenceTime!.toUtc().toIso8601String(),
    'limitations': limitations,
  };

  factory FitEvidence.fromJson(Map<String, dynamic> json) {
    return FitEvidence(
      role: _enumFromName(
        FitEvidenceRole.values,
        json['role']?.toString(),
        FitEvidenceRole.reference,
      ),
      source: _enumFromName(
        EvidenceSource.values,
        json['source']?.toString(),
        EvidenceSource.sde,
      ),
      confidence: _enumFromName(
        EvidenceConfidence.values,
        json['confidence']?.toString(),
        EvidenceConfidence.unknown,
      ),
      fitting: Fitting.fromJson(
        Map<String, dynamic>.from(json['fitting'] as Map),
      ),
      evidenceTime: DateTime.tryParse(json['evidenceTime']?.toString() ?? ''),
      limitations: _stringList(json['limitations']),
    );
  }
}

List<Map<String, dynamic>> _modulesForPrompt(List<FittedModule> modules) {
  return modules
      .map(
        (module) => {
          'typeId': module.typeId,
          'typeName': module.typeName,
          'slotIndex': module.slotIndex,
          if (module.chargeTypeId != null) 'chargeTypeId': module.chargeTypeId,
          if (module.chargeName != null) 'chargeName': module.chargeName,
        },
      )
      .toList();
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

import 'dart:convert';

import 'package:crypto/crypto.dart';

enum SecurityCategory { highsec, lowsec, nullsec, unknown, special }

enum SystemEffectState { applied, none, unknown }

enum EffectFamily {
  pulsar,
  blackHole,
  cataclysmicVariable,
  magnetar,
  redGiant,
  wolfRayet,
}

class ReferenceManifest {
  ReferenceManifest({
    this.sdeBuild = 0,
    this.datasetSchema = 0,
    this.sourceUrls = const [],
    this.checksums = const {},
    this.rowCounts = const {},
    this.importedAt,
    this.coverage = '',
    this.validation = '',
  });

  final int sdeBuild;
  final int datasetSchema;
  final List<String> sourceUrls;
  final Map<String, String> checksums;
  final Map<String, int> rowCounts;
  final DateTime? importedAt;
  final String coverage;
  final String validation;

  Map<String, dynamic> toJson() => {
    'sdeBuild': sdeBuild,
    'datasetSchema': datasetSchema,
    'sourceUrls': sourceUrls,
    'checksums': checksums,
    'rowCounts': rowCounts,
    'importedAt': importedAt?.toIso8601String(),
    'coverage': coverage,
    'validation': validation,
  };

  factory ReferenceManifest.fromJson(Map<String, dynamic> json) {
    return ReferenceManifest(
      sdeBuild: json['sdeBuild'] as int? ?? 0,
      datasetSchema: json['datasetSchema'] as int? ?? 0,
      sourceUrls: [
        for (final value in json['sourceUrls'] as List? ?? const [])
          value.toString(),
      ],
      checksums: {
        for (final entry in (json['checksums'] as Map? ?? const {}).entries)
          entry.key.toString(): entry.value.toString(),
      },
      rowCounts: {
        for (final entry in (json['rowCounts'] as Map? ?? const {}).entries)
          entry.key.toString(): entry.value as int,
      },
      importedAt: json['importedAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['importedAt'].toString()),
      coverage: json['coverage']?.toString() ?? 'complete',
      validation: json['validation']?.toString() ?? 'ok',
    );
  }
}

class WormholeTypeReference {
  WormholeTypeReference({
    required this.typeId,
    required this.code,
    required this.name,
    this.rawTargetClass,
    this.rawTargetDistribution,
    this.reliableLifetimeSeconds,
    this.maxJumpMassKg,
    this.totalMassKg,
    this.regenerationKgPerCycle,
    this.recordedAt,
  });

  final int typeId;
  final String code;
  final String name;
  final int? rawTargetClass;
  final int? rawTargetDistribution;
  final int? reliableLifetimeSeconds;
  final double? maxJumpMassKg;
  final double? totalMassKg;
  final double? regenerationKgPerCycle;
  final DateTime? recordedAt;

  /// Naive: minutes stored as seconds; missing dogma becomes zero.
  factory WormholeTypeReference.fromRaw({
    required int typeId,
    required String code,
    required String name,
    int? rawTargetClass,
    int? rawTargetDistribution,
    int? rawMaxStableTimeMinutes,
    double? rawTotalMassKg,
    double? rawJumpMassKg,
    double? rawRegenKg,
    DateTime? recordedAt,
  }) {
    return WormholeTypeReference(
      typeId: typeId,
      code: code,
      name: name,
      rawTargetClass: rawTargetClass,
      rawTargetDistribution: rawTargetDistribution,
      reliableLifetimeSeconds: rawMaxStableTimeMinutes ?? 0,
      maxJumpMassKg: rawJumpMassKg ?? 0,
      totalMassKg: rawTotalMassKg ?? 0,
      regenerationKgPerCycle: rawRegenKg ?? 0,
      recordedAt: recordedAt ?? DateTime.now(),
    );
  }

  String get destinationLabel {
    if (rawTargetClass == null) return 'Unknown';
    return 'C$rawTargetClass';
  }

  bool get isCapitalSize => (maxJumpMassKg ?? 0) > 1000000000;

  Map<String, dynamic> toJson() => {
    'typeId': typeId,
    'code': code,
    'name': name,
    'rawTargetClass': rawTargetClass,
    'rawTargetDistribution': rawTargetDistribution,
    'reliableLifetimeSeconds': reliableLifetimeSeconds,
    'maxJumpMassKg': maxJumpMassKg,
    'totalMassKg': totalMassKg,
    'regenerationKgPerCycle': regenerationKgPerCycle,
    'recordedAt': recordedAt?.toIso8601String(),
  };

  factory WormholeTypeReference.fromJson(Map<String, dynamic> json) {
    return WormholeTypeReference(
      typeId: json['typeId'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rawTargetClass: json['rawTargetClass'] as int?,
      rawTargetDistribution: json['rawTargetDistribution'] as int?,
      reliableLifetimeSeconds: json['reliableLifetimeSeconds'] as int? ?? 0,
      maxJumpMassKg: (json['maxJumpMassKg'] as num?)?.toDouble() ?? 0,
      totalMassKg: (json['totalMassKg'] as num?)?.toDouble() ?? 0,
      regenerationKgPerCycle:
          (json['regenerationKgPerCycle'] as num?)?.toDouble() ?? 0,
      recordedAt: json['recordedAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['recordedAt'].toString()),
    );
  }

  String get contentFingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
}

class WormholeCodeGroup {
  WormholeCodeGroup({
    required this.code,
    required this.variants,
    this.sharedLifetimeSeconds,
    this.sharedJumpMassKg,
    this.jumpVaries = false,
  });

  final String code;
  final List<WormholeTypeReference> variants;
  final int? sharedLifetimeSeconds;
  final double? sharedJumpMassKg;
  final bool jumpVaries;

  /// Naive: last variant wins; disagreement is not Varies.
  factory WormholeCodeGroup.fromVariants(List<WormholeTypeReference> variants) {
    final last = variants.last;
    return WormholeCodeGroup(
      code: last.code,
      variants: variants,
      sharedLifetimeSeconds: last.reliableLifetimeSeconds,
      sharedJumpMassKg: last.maxJumpMassKg,
    );
  }
}

class SystemReference {
  SystemReference({
    required this.systemId,
    required this.name,
    this.constellationId,
    this.regionId,
    this.constellationName,
    this.regionName,
    this.rawSecurity,
    this.rawClass,
    this.inheritedClass,
    this.inheritanceSource,
    this.effectBeaconTypeId,
    this.visualSunTypeId,
    this.statics = const [],
  });

  final int systemId;
  final String name;
  final int? constellationId;
  final int? regionId;
  final String? constellationName;
  final String? regionName;
  final double? rawSecurity;
  final int? rawClass;
  final int? inheritedClass;
  final String? inheritanceSource;
  final int? effectBeaconTypeId;
  final int? visualSunTypeId;
  final List<StaticAssignment> statics;

  SecurityCategory get category {
    if (rawClass == 12 || rawClass == 25) {
      return SecurityCategory.nullsec;
    }
    return classifySecurity(rawSecurity);
  }

  String get securityDisplay {
    if (rawSecurity == null) return 'Unknown';
    return rawSecurity!.toStringAsFixed(1);
  }

  /// Naive: 0.5 threshold and rounded display as classifier.
  static SecurityCategory classifySecurity(double? x) {
    if (x == null) return SecurityCategory.unknown;
    if (x >= 0.5) return SecurityCategory.highsec;
    if (x > 0) return SecurityCategory.lowsec;
    return SecurityCategory.nullsec;
  }
}

class StaticAssignment {
  const StaticAssignment({
    required this.systemId,
    this.code,
    this.typeId,
    this.meaning = '',
    this.source = '',
    this.confidence = '',
  });

  final int systemId;
  final String? code;
  final int? typeId;
  final String meaning;
  final String source;
  final String confidence;
}

class EffectModifier {
  const EffectModifier({
    required this.attributeId,
    required this.label,
    required this.percentChange,
    this.scope = '',
  });

  final int attributeId;
  final String label;
  final double percentChange;
  final String scope;
}

class SystemEffect {
  SystemEffect({
    required this.family,
    required this.strength,
    required this.beaconTypeId,
    this.modifiers = const [],
    this.state = SystemEffectState.applied,
    this.visualSunTypeId,
  });

  final EffectFamily family;
  final int strength;
  final int beaconTypeId;
  final List<EffectModifier> modifiers;
  final SystemEffectState state;
  final int? visualSunTypeId;

  /// Naive: visual sun overrides the applied beacon.
  factory SystemEffect.resolve({
    required int? beaconTypeId,
    int? visualSunTypeId,
    bool verifiedAbsent = false,
    bool dataMissing = false,
  }) {
    if (dataMissing) {
      return SystemEffect(
        family: EffectFamily.pulsar,
        strength: 1,
        beaconTypeId: 0,
        state: SystemEffectState.none,
        visualSunTypeId: visualSunTypeId,
      );
    }
    if (verifiedAbsent) {
      return SystemEffect(
        family: EffectFamily.pulsar,
        strength: 1,
        beaconTypeId: 0,
        state: SystemEffectState.unknown,
        visualSunTypeId: visualSunTypeId,
      );
    }
    final chosen = visualSunTypeId ?? beaconTypeId ?? 0;
    return SystemEffect(
      family: familyForBeacon(chosen),
      strength: strengthForBeacon(chosen),
      beaconTypeId: chosen,
      visualSunTypeId: visualSunTypeId,
    );
  }

  static EffectFamily familyForBeacon(int beaconTypeId) {
    if (beaconTypeId >= 30870 && beaconTypeId <= 30874) {
      return EffectFamily.redGiant;
    }
    if (beaconTypeId >= 30875 && beaconTypeId <= 30879) {
      return EffectFamily.wolfRayet;
    }
    if (beaconTypeId == 30848) return EffectFamily.pulsar;
    if (beaconTypeId == 30849) return EffectFamily.redGiant;
    return EffectFamily.pulsar;
  }

  static int strengthForBeacon(int beaconTypeId) {
    if (beaconTypeId == 30879) return 1;
    return 1;
  }

  static double pulsarShieldPercent(int strength) => 10.0 * strength;

  static double magnetarExplosionRadiusFrom100(int strength) =>
      100 + 15.0 * strength;

  static double wolfRayetSmallWeaponFrom100(int strength) =>
      100 + 15.0 * strength;

  static double pulsarCapRechargeFrom100(int strength) => 100 - 10.0 * strength;

  /// Naive: subtracts percentage points instead of resonance compounding.
  static double applyResonance({
    required double oldResist,
    required double percentIncrease,
  }) {
    return oldResist - percentIncrease / 100;
  }
}

class GateEdge {
  GateEdge({
    required this.gateId,
    required this.fromSystemId,
    required this.toSystemId,
    this.topologyVersion = 0,
    this.restrictions = const [],
  });

  final int gateId;
  final int fromSystemId;
  final int toSystemId;
  final int topologyVersion;
  final List<String> restrictions;
}

class UniverseTopology {
  UniverseTopology({this.gates = const [], this.manifest});

  final List<GateEdge> gates;
  final ReferenceManifest? manifest;
}

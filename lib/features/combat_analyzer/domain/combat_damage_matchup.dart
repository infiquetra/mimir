import '../../../core/logging/logger.dart';
import '../../fitting/domain/damage_pattern.dart';
import '../../fitting/domain/models.dart';
import 'combat_damage_profile.dart';
import 'damage_matchup_assessment.dart';
import 'damage_pattern_x.dart';
import 'incoming_damage_allocation.dart';
import 'incoming_damage_matchup.dart';
import 'tank_classifier.dart';

export 'damage_matchup_assessment.dart';

class CombatDamageMatchup {
  const CombatDamageMatchup({
    required this.targetLabel,
    required this.layer,
    required this.summary,
    required this.entries,
    this.pattern,
    this.ehpAgainstPattern,
    this.ehpOmni,
    this.primaryHole,
  });

  final String targetLabel;
  final String layer;
  final String summary;
  final List<CombatDamageMatchupEntry> entries;
  final DamagePattern? pattern;
  final LayeredEhp? ehpAgainstPattern;
  final LayeredEhp? ehpOmni;
  final String? primaryHole;

  Map<String, dynamic> toJson() => {
    'targetLabel': targetLabel,
    'layer': layer,
    'summary': summary,
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'primaryHole': primaryHole,
  };

  factory CombatDamageMatchup.fromJson(Map<String, dynamic> json) {
    return CombatDamageMatchup(
      targetLabel: json['targetLabel']?.toString() ?? '',
      layer: json['layer']?.toString() ?? 'unknown',
      summary: json['summary']?.toString() ?? '',
      entries: _objectList(
        json['entries'],
      ).map(CombatDamageMatchupEntry.fromJson).toList(),
      primaryHole: json['primaryHole']?.toString(),
    );
  }
}

class CombatDamageMatchupEntry {
  const CombatDamageMatchupEntry({
    required this.type,
    required this.amount,
    required this.percent,
    required this.assessment,
    required this.evidence,
    this.resistPercent,
    this.appliedPercent,
  });

  final String type;
  final int amount;
  final double percent;
  final double? resistPercent;
  final double? appliedPercent;
  final DamageMatchupAssessment assessment;
  final String evidence;

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'percent': percent,
    'resistPercent': resistPercent,
    'appliedPercent': appliedPercent,
    'assessment': assessment.name,
    'evidence': evidence,
  };

  factory CombatDamageMatchupEntry.fromJson(Map<String, dynamic> json) {
    return CombatDamageMatchupEntry(
      type: json['type']?.toString() ?? 'unknown',
      amount: _intFromJson(json['amount']),
      percent: _doubleFromJson(json['percent']),
      resistPercent: json.containsKey('resistPercent')
          ? _doubleOrNull(json['resistPercent'])
          : null,
      appliedPercent: json.containsKey('appliedPercent')
          ? _doubleOrNull(json['appliedPercent'])
          : null,
      assessment: _enumFromName(
        DamageMatchupAssessment.values,
        json['assessment']?.toString(),
        DamageMatchupAssessment.unknown,
      ),
      evidence: json['evidence']?.toString() ?? '',
    );
  }
}

class CombatDamageMatchupAnalyzer {
  static CombatDamageMatchup analyze({
    required CombatDamageProfile profile,
    required DefenseProfile? defense,
    TankAssessment? tank,
    required String targetLabel,
  }) {
    Log.d(
      'COMBAT',
      'CombatDamageMatchupAnalyzer.analyze target=$targetLabel '
          'entries=${profile.entries.length} defense=${defense != null} '
          'tank=${tank?.label}',
    );

    if (defense == null) {
      final entries = [
        for (final entry in profile.entries)
          CombatDamageMatchupEntry(
            type: entry.type,
            amount: entry.amount,
            percent: entry.percent,
            assessment: DamageMatchupAssessment.unknown,
            evidence: '${entry.source} into $targetLabel; defense unknown.',
          ),
      ];
      return CombatDamageMatchup(
        targetLabel: targetLabel,
        layer: 'unknown',
        summary: entries.isEmpty
            ? 'No damage type matchup could be derived for $targetLabel.'
            : 'Compared ${entries.length} damage types against $targetLabel with no defense profile.',
        entries: entries,
      );
    }

    final layer = tank != null ? tank.layer.name : _primaryLayer(defense);
    final layerUnknown = layer == 'unknown' || tank?.layer == TankLayer.unknown;
    final resists = switch (layer) {
      'shield' => defense.shieldResists,
      'armor' => defense.armorResists,
      'hull' => defense.hullResists,
      _ => const ResistProfile(),
    };
    final mean =
        (resists.em + resists.thermal + resists.kinetic + resists.explosive) /
        4;

    final weights = <int, double>{};
    var weightSum = 0.0;
    for (var i = 0; i < profile.entries.length; i++) {
      final entry = profile.entries[i];
      final resist = _resistForType(resists, entry.type);
      final weight = entry.percent * (1 - resist / 100);
      weights[i] = weight;
      weightSum += weight;
    }

    final entries = <CombatDamageMatchupEntry>[];
    for (var i = 0; i < profile.entries.length; i++) {
      final entry = profile.entries[i];
      final resist = _resistForType(resists, entry.type);
      final applied = layerUnknown
          ? null
          : (weightSum <= 0
                ? (profile.entries.isEmpty ? 0.0 : 1.0 / profile.entries.length)
                : weights[i]! / weightSum);
      entries.add(
        CombatDamageMatchupEntry(
          type: entry.type,
          amount: entry.amount,
          percent: entry.percent,
          resistPercent: layerUnknown ? null : resist,
          appliedPercent: applied,
          assessment: layerUnknown
              ? DamageMatchupAssessment.unknown
              : assessResist(resist, mean),
          evidence: '${entry.source} into $targetLabel $layer resist profile.',
        ),
      );
    }

    String? primaryHole;
    var bestApplied = -1.0;
    for (final entry in entries) {
      if (entry.assessment != DamageMatchupAssessment.resistHole) continue;
      final applied = entry.appliedPercent ?? 0;
      if (applied > bestApplied) {
        bestApplied = applied;
        primaryHole = entry.type;
      }
    }

    final pattern = profile.toDamagePattern();
    final ehpAgainstPattern = pattern == null
        ? null
        : defense.ehpAgainst(pattern);
    final ehpOmni = defense.ehpAgainst(DamagePattern.omni);

    return CombatDamageMatchup(
      targetLabel: targetLabel,
      layer: layer,
      summary: entries.isEmpty
          ? 'No damage type matchup could be derived for $targetLabel.'
          : 'Compared ${entries.length} damage types against $targetLabel $layer resists.',
      entries: entries,
      pattern: pattern,
      ehpAgainstPattern: ehpAgainstPattern,
      ehpOmni: ehpOmni,
      primaryHole: primaryHole,
    );
  }

  static AarIncomingDefenseMatchup analyzeIncoming({
    required IncomingDamageVector components,
    required DefenseProfile? defense,
    required TankAssessment? tank,
    required String? pilotFitKey,
  }) {
    Log.d(
      'AAR.MATCHUP',
      'analyzeIncoming typed=${!components.total.isZero} '
          'defense=${defense != null} tank=${tank?.layer.name}',
    );
    if (components.total.isZero) {
      return AarIncomingDefenseMatchup(
        status: IncomingDefenseStatus.noTypedDamage,
        pressureStatus: IncomingPressureStatus.unavailable,
        layer: tank?.layer ?? TankLayer.unknown,
        entries: const [],
        guardedLayers: const [],
        limitationCodes: const ['noTypedDamage'],
        pilotFitKey: pilotFitKey,
      );
    }

    final pattern = components.toPattern();
    if (pattern == null) {
      return AarIncomingDefenseMatchup(
        status: IncomingDefenseStatus.noTypedDamage,
        pressureStatus: IncomingPressureStatus.unavailable,
        layer: tank?.layer ?? TankLayer.unknown,
        entries: const [],
        guardedLayers: const [],
        limitationCodes: const ['noTypedDamage'],
        pilotFitKey: pilotFitKey,
      );
    }

    for (final type in IncomingDamageType.values) {
      final exact = components[type];
      if (!exact.isZero && (exact / components.total).toFiniteDouble() == 0) {
        return AarIncomingDefenseMatchup(
          status: IncomingDefenseStatus.numericPrecisionUnavailable,
          pressureStatus: IncomingPressureStatus.unavailable,
          pattern: pattern,
          layer: tank?.layer ?? TankLayer.unknown,
          entries: const [],
          guardedLayers: const [],
          limitationCodes: const ['numericPrecisionUnavailable'],
          pilotFitKey: pilotFitKey,
        );
      }
    }

    if (defense == null) {
      return AarIncomingDefenseMatchup(
        status: IncomingDefenseStatus.pilotDefenseUnavailable,
        pressureStatus: IncomingPressureStatus.unavailable,
        pattern: pattern,
        layer: tank?.layer ?? TankLayer.unknown,
        entries: [
          for (final type in IncomingDamageType.values)
            IncomingResistResult(
              type: type,
              profileFraction: (components[type] / components.total)
                  .toFiniteDouble(),
              assessment: DamageMatchupAssessment.unknown,
            ),
        ],
        guardedLayers: const [],
        limitationCodes: const ['pilotDefenseUnavailable'],
        pilotFitKey: pilotFitKey,
      );
    }

    if (!_defenseIsValid(defense)) {
      return AarIncomingDefenseMatchup(
        status: IncomingDefenseStatus.invalidDefense,
        pressureStatus: IncomingPressureStatus.unavailable,
        pattern: pattern,
        layer: tank?.layer ?? TankLayer.unknown,
        entries: const [],
        guardedLayers: const [],
        limitationCodes: const ['invalidDefense'],
        pilotFitKey: pilotFitKey,
      );
    }

    final guarded = <TankLayer>[];
    if (_layerQ(defense.shieldResists, pattern) <= 0 && defense.shieldHp > 0) {
      guarded.add(TankLayer.shield);
    }
    if (_layerQ(defense.armorResists, pattern) <= 0 && defense.armorHp > 0) {
      guarded.add(TankLayer.armor);
    }
    if (_layerQ(defense.hullResists, pattern) <= 0 && defense.hullHp > 0) {
      guarded.add(TankLayer.hull);
    }

    final ehp = defense.ehpAgainst(pattern);
    final omni = defense.ehpAgainst(DamagePattern.omni);
    if (!ehp.total.isFinite || !omni.total.isFinite) {
      return AarIncomingDefenseMatchup(
        status: IncomingDefenseStatus.numericPrecisionUnavailable,
        pressureStatus: IncomingPressureStatus.unavailable,
        pattern: pattern,
        layer: tank?.layer ?? TankLayer.unknown,
        entries: const [],
        guardedLayers: List.unmodifiable(guarded),
        limitationCodes: const ['numericPrecisionUnavailable'],
        pilotFitKey: pilotFitKey,
      );
    }

    final layer = tank?.layer ?? TankLayer.unknown;
    final layerUnknown = layer == TankLayer.unknown;
    final selectedResists = switch (layer) {
      TankLayer.shield => defense.shieldResists,
      TankLayer.armor => defense.armorResists,
      TankLayer.hull => defense.hullResists,
      TankLayer.unknown => const ResistProfile(),
    };
    final mean =
        (selectedResists.em +
            selectedResists.thermal +
            selectedResists.kinetic +
            selectedResists.explosive) /
        4;

    final fractions = <IncomingDamageType, double>{
      for (final type in IncomingDamageType.values)
        type: (components[type] / components.total).toFiniteDouble(),
    };
    final weights = <IncomingDamageType, double>{};
    var weightSum = 0.0;
    for (final type in IncomingDamageType.values) {
      final resist = _resistOf(selectedResists, type);
      final weight = fractions[type]! * (1 - resist / 100);
      weights[type] = weight;
      weightSum += weight;
    }

    IncomingPressureStatus pressureStatus;
    IncomingDamageType? primaryHole;
    if (layerUnknown) {
      pressureStatus = IncomingPressureStatus.unknownLayer;
    } else if (weightSum <= 0) {
      pressureStatus = IncomingPressureStatus.zeroDenominator;
    } else {
      pressureStatus = IncomingPressureStatus.available;
    }

    final entries = <IncomingResistResult>[
      for (final type in IncomingDamageType.values)
        IncomingResistResult(
          type: type,
          profileFraction: fractions[type]!,
          resistPercent: layerUnknown ? null : _resistOf(selectedResists, type),
          modeledPressure: pressureStatus == IncomingPressureStatus.available
              ? weights[type]! / weightSum
              : null,
          assessment: layerUnknown
              ? DamageMatchupAssessment.unknown
              : assessResist(_resistOf(selectedResists, type), mean),
        ),
    ];

    if (pressureStatus == IncomingPressureStatus.available) {
      IncomingDamageType? best;
      var bestPressure = -1.0;
      for (final entry in entries) {
        if (entry.assessment != DamageMatchupAssessment.resistHole) continue;
        if (entry.profileFraction <= 0) continue;
        final pressure = entry.modeledPressure ?? 0;
        if (best == null ||
            pressure > bestPressure ||
            (pressure == bestPressure && entry.type.index < best.index)) {
          best = entry.type;
          bestPressure = pressure;
        }
      }
      primaryHole = best;
    }

    final limitations = <String>[
      if (guarded.isNotEmpty) 'qNonPositiveFallback',
    ];

    return AarIncomingDefenseMatchup(
      status: IncomingDefenseStatus.available,
      pressureStatus: pressureStatus,
      pattern: pattern,
      ehp: ehp,
      omniEhp: omni,
      layer: layer,
      entries: List.unmodifiable(entries),
      primaryHole: primaryHole,
      guardedLayers: List.unmodifiable(guarded),
      limitationCodes: List.unmodifiable(limitations),
      pilotFitKey: pilotFitKey,
    );
  }

  static bool _defenseIsValid(DefenseProfile defense) {
    bool hpOk(double hp) => hp.isFinite && hp >= 0;
    bool resistOk(ResistProfile r) {
      for (final value in [r.em, r.thermal, r.kinetic, r.explosive]) {
        if (!value.isFinite || value < 0 || value > 100) return false;
      }
      return true;
    }

    if (!hpOk(defense.shieldHp) ||
        !hpOk(defense.armorHp) ||
        !hpOk(defense.hullHp)) {
      return false;
    }
    if (defense.shieldHp == 0 && defense.armorHp == 0 && defense.hullHp == 0) {
      return false;
    }
    return resistOk(defense.shieldResists) &&
        resistOk(defense.armorResists) &&
        resistOk(defense.hullResists);
  }

  static double _layerQ(ResistProfile r, DamagePattern p) {
    return p.em * (1 - r.em / 100) +
        p.thermal * (1 - r.thermal / 100) +
        p.kinetic * (1 - r.kinetic / 100) +
        p.explosive * (1 - r.explosive / 100);
  }

  static double _resistOf(ResistProfile resists, IncomingDamageType type) {
    return switch (type) {
      IncomingDamageType.em => resists.em,
      IncomingDamageType.thermal => resists.thermal,
      IncomingDamageType.kinetic => resists.kinetic,
      IncomingDamageType.explosive => resists.explosive,
    };
  }

  static String _primaryLayer(DefenseProfile defense) {
    final layers = <String, double>{
      'shield': defense.shieldHp,
      'armor': defense.armorHp,
      'hull': defense.hullHp,
    };
    final sorted = layers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.value <= 0 ? 'unknown' : sorted.first.key;
  }

  static double _resistForType(ResistProfile resists, String type) {
    return switch (type.toLowerCase()) {
      'em' => resists.em,
      'thermal' => resists.thermal,
      'kinetic' => resists.kinetic,
      'explosive' => resists.explosive,
      _ => 0,
    };
  }
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleFromJson(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  return _doubleFromJson(value);
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

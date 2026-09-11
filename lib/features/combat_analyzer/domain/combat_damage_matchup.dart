import '../../../core/logging/logger.dart';
import '../../fitting/domain/damage_pattern.dart';
import '../../fitting/domain/models.dart';
import 'combat_damage_profile.dart';
import 'damage_pattern_x.dart';
import 'tank_classifier.dart';

enum DamageMatchupAssessment { resistHole, neutral, strongResist, unknown }

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
              : _assessmentForResist(resist, mean),
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

  static DamageMatchupAssessment _assessmentForResist(
    double resist,
    double mean,
  ) {
    if (resist <= 20 || resist <= mean - 5) {
      return DamageMatchupAssessment.resistHole;
    }
    if (resist >= mean + 5) {
      return DamageMatchupAssessment.strongResist;
    }
    return DamageMatchupAssessment.neutral;
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

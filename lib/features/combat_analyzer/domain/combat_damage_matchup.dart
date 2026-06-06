import '../../fitting/domain/models.dart';
import 'combat_damage_profile.dart';

enum DamageMatchupAssessment { resistHole, neutral, strongResist, unknown }

class CombatDamageMatchup {
  const CombatDamageMatchup({
    required this.targetLabel,
    required this.layer,
    required this.summary,
    required this.entries,
  });

  final String targetLabel;
  final String layer;
  final String summary;
  final List<CombatDamageMatchupEntry> entries;

  Map<String, dynamic> toJson() => {
    'targetLabel': targetLabel,
    'layer': layer,
    'summary': summary,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory CombatDamageMatchup.fromJson(Map<String, dynamic> json) {
    return CombatDamageMatchup(
      targetLabel: json['targetLabel']?.toString() ?? '',
      layer: json['layer']?.toString() ?? 'unknown',
      summary: json['summary']?.toString() ?? '',
      entries: _objectList(
        json['entries'],
      ).map(CombatDamageMatchupEntry.fromJson).toList(),
    );
  }
}

class CombatDamageMatchupEntry {
  const CombatDamageMatchupEntry({
    required this.type,
    required this.amount,
    required this.percent,
    required this.resistPercent,
    required this.assessment,
    required this.evidence,
  });

  final String type;
  final int amount;
  final double percent;
  final double resistPercent;
  final DamageMatchupAssessment assessment;
  final String evidence;

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'percent': percent,
    'resistPercent': resistPercent,
    'assessment': assessment.name,
    'evidence': evidence,
  };

  factory CombatDamageMatchupEntry.fromJson(Map<String, dynamic> json) {
    return CombatDamageMatchupEntry(
      type: json['type']?.toString() ?? 'unknown',
      amount: _intFromJson(json['amount']),
      percent: _doubleFromJson(json['percent']),
      resistPercent: _doubleFromJson(json['resistPercent']),
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
    required DefenseProfile defense,
    required String targetLabel,
  }) {
    final layer = _primaryLayer(defense);
    final resists = switch (layer) {
      'shield' => defense.shieldResists,
      'armor' => defense.armorResists,
      'hull' => defense.hullResists,
      _ => const ResistProfile(),
    };
    final entries = profile.entries
        .map((entry) {
          final resist = _resistForType(resists, entry.type);
          return CombatDamageMatchupEntry(
            type: entry.type,
            amount: entry.amount,
            percent: entry.percent,
            resistPercent: resist,
            assessment: _assessmentForResist(resist),
            evidence:
                '${entry.source} into $targetLabel $layer resist profile.',
          );
        })
        .toList(growable: false);
    return CombatDamageMatchup(
      targetLabel: targetLabel,
      layer: layer,
      summary: entries.isEmpty
          ? 'No damage type matchup could be derived for $targetLabel.'
          : 'Compared ${entries.length} damage types against $targetLabel $layer resists.',
      entries: entries,
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

  static DamageMatchupAssessment _assessmentForResist(double resist) {
    if (resist >= 60) return DamageMatchupAssessment.strongResist;
    if (resist <= 20) return DamageMatchupAssessment.resistHole;
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

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

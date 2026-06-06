class CombatAarReport {
  const CombatAarReport({
    required this.headline,
    required this.summary,
    required this.outcomeAssessment,
    required this.keyMoments,
    required this.rankedMistakes,
    required this.recommendations,
    required this.fitAdvice,
    required this.trainingDrills,
    required this.damageAnalysis,
    required this.resourceTopicIds,
    required this.confidence,
    required this.unknowns,
  });

  static const int version = 3;

  static const Set<String> allowedResourceTopicIds = {
    'drone_application',
    'range_control',
    'transversal',
    'target_selection',
    'damage_application',
    'fit_tank_vs_application',
    'escape_decision',
  };

  final String headline;
  final String summary;
  final String outcomeAssessment;
  final List<AarKeyMoment> keyMoments;
  final List<AarMistake> rankedMistakes;
  final List<AarRecommendation> recommendations;
  final List<AarFitAdvice> fitAdvice;
  final List<AarTrainingDrill> trainingDrills;
  final AarDamageAnalysis damageAnalysis;
  final List<String> resourceTopicIds;
  final double confidence;
  final List<String> unknowns;

  String get mistakesText {
    if (rankedMistakes.isEmpty) return 'No combat mistakes were identified.';
    if (rankedMistakes.length == 1 &&
        rankedMistakes.single.title == 'Legacy Mistakes') {
      return rankedMistakes.single.impact;
    }
    return rankedMistakes
        .map(
          (mistake) =>
              '${mistake.rank}. ${mistake.title}: ${mistake.impact} ${mistake.correction}',
        )
        .join('\n');
  }

  String get improvementsText {
    if (recommendations.isEmpty) return 'No improvements were identified.';
    if (recommendations.length == 1 &&
        recommendations.single.title == 'Legacy Improvements') {
      return recommendations.single.details;
    }
    return recommendations
        .map(
          (recommendation) =>
              '${recommendation.title}: ${recommendation.details}',
        )
        .join('\n');
  }

  String get fitsText {
    if (fitAdvice.isEmpty) return 'No fitting advice was identified.';
    if (fitAdvice.length == 1 &&
        fitAdvice.single.title == 'Legacy Fit Advice') {
      return fitAdvice.single.details;
    }
    return fitAdvice
        .map((advice) => '${advice.title}: ${advice.details}')
        .join('\n');
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'headline': headline,
    'summary': summary,
    'outcomeAssessment': outcomeAssessment,
    'keyMoments': keyMoments.map((moment) => moment.toJson()).toList(),
    'rankedMistakes': rankedMistakes
        .map((mistake) => mistake.toJson())
        .toList(),
    'recommendations': recommendations
        .map((recommendation) => recommendation.toJson())
        .toList(),
    'fitAdvice': fitAdvice.map((advice) => advice.toJson()).toList(),
    'trainingDrills': trainingDrills.map((drill) => drill.toJson()).toList(),
    'damageAnalysis': damageAnalysis.toJson(),
    'resourceTopicIds': resourceTopicIds,
    'confidence': confidence,
    'unknowns': unknowns,
  };

  factory CombatAarReport.fromJson(Map<String, dynamic> json) {
    if (_looksLikeLegacyReport(json)) {
      return CombatAarReport.fromLegacy(
        summary: json['summary']?.toString() ?? 'No summary provided.',
        mistakes: json['mistakes']?.toString() ?? '',
        improvements: json['improvements']?.toString() ?? '',
        fits: json['fits']?.toString() ?? '',
      );
    }

    final resourceTopicIds = _stringList(
      json['resourceTopicIds'],
    ).where(allowedResourceTopicIds.contains).toList();
    return CombatAarReport(
      headline: _stringOrFallback(json['headline'], 'Combat Review'),
      summary: _stringOrFallback(json['summary'], 'No summary provided.'),
      outcomeAssessment: _stringOrFallback(
        json['outcomeAssessment'],
        'Outcome could not be assessed from the structured report.',
      ),
      keyMoments: _objectList(
        json['keyMoments'],
      ).map(AarKeyMoment.fromJson).toList(),
      rankedMistakes:
          _objectList(json['rankedMistakes']).map(AarMistake.fromJson).toList()
            ..sort((a, b) => a.rank.compareTo(b.rank)),
      recommendations: _objectList(
        json['recommendations'],
      ).map(AarRecommendation.fromJson).toList(),
      fitAdvice: _objectList(
        json['fitAdvice'],
      ).map(AarFitAdvice.fromJson).toList(),
      trainingDrills: _objectList(
        json['trainingDrills'],
      ).map(AarTrainingDrill.fromJson).toList(),
      damageAnalysis: AarDamageAnalysis.fromJson(
        _objectFromJson(json['damageAnalysis']),
      ),
      resourceTopicIds: resourceTopicIds,
      confidence: _doubleFromJson(json['confidence'], fallback: 0.5),
      unknowns: _stringList(json['unknowns']),
    );
  }

  factory CombatAarReport.fromLegacy({
    required String summary,
    required String mistakes,
    required String improvements,
    required String fits,
  }) {
    return CombatAarReport(
      headline: 'Combat Review',
      summary: summary,
      outcomeAssessment: summary,
      keyMoments: const [],
      rankedMistakes: mistakes.trim().isEmpty
          ? const []
          : [
              AarMistake(
                rank: 1,
                title: 'Legacy Mistakes',
                severity: 'medium',
                evidence: 'Legacy prose-only analysis',
                impact: mistakes,
                correction: '',
                eventIds: const [],
              ),
            ],
      recommendations: improvements.trim().isEmpty
          ? const []
          : [
              AarRecommendation(
                title: 'Legacy Improvements',
                details: improvements,
                linkedMistakeRank: null,
              ),
            ],
      fitAdvice: fits.trim().isEmpty
          ? const []
          : [
              AarFitAdvice(
                title: 'Legacy Fit Advice',
                details: fits,
                confidence: 'unknown',
                observedItems: const [],
                recommendedItems: const [],
                limitations: 'Generated before structured AAR reports.',
              ),
            ],
      trainingDrills: const [],
      damageAnalysis: const AarDamageAnalysis.empty(),
      resourceTopicIds: const [],
      confidence: 0.4,
      unknowns: const ['This is a legacy prose-only report.'],
    );
  }

  static bool _looksLikeLegacyReport(Map<String, dynamic> json) {
    return json.containsKey('mistakes') ||
        json.containsKey('improvements') ||
        json.containsKey('fits');
  }
}

class AarKeyMoment {
  const AarKeyMoment({
    required this.timestamp,
    required this.title,
    required this.details,
    required this.eventIds,
    this.relativeSecond,
    this.category = 'unknown',
    this.severity = 'medium',
  });

  final String timestamp;
  final String title;
  final String details;
  final List<String> eventIds;
  final int? relativeSecond;
  final String category;
  final String severity;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    if (relativeSecond != null) 'relativeSecond': relativeSecond,
    'category': category,
    'severity': severity,
    'title': title,
    'details': details,
    'eventIds': eventIds,
  };

  factory AarKeyMoment.fromJson(Map<String, dynamic> json) {
    return AarKeyMoment(
      timestamp: json['timestamp']?.toString() ?? '',
      relativeSecond: _nullableInt(json['relativeSecond']),
      category: _stringOrFallback(json['category'], 'unknown'),
      severity: _stringOrFallback(json['severity'], 'medium'),
      title: _stringOrFallback(json['title'], 'Key Moment'),
      details: _stringOrFallback(json['details'], ''),
      eventIds: _stringList(json['eventIds']),
    );
  }
}

class AarMistake {
  const AarMistake({
    required this.rank,
    required this.title,
    required this.severity,
    required this.evidence,
    required this.impact,
    required this.correction,
    required this.eventIds,
  });

  final int rank;
  final String title;
  final String severity;
  final String evidence;
  final String impact;
  final String correction;
  final List<String> eventIds;

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'title': title,
    'severity': severity,
    'evidence': evidence,
    'impact': impact,
    'correction': correction,
    'eventIds': eventIds,
  };

  factory AarMistake.fromJson(Map<String, dynamic> json) {
    return AarMistake(
      rank: _intFromJson(json['rank'], fallback: 99),
      title: _stringOrFallback(json['title'], 'Tactical Issue'),
      severity: _stringOrFallback(json['severity'], 'medium'),
      evidence: _stringOrFallback(json['evidence'], ''),
      impact: _stringOrFallback(json['impact'], ''),
      correction: _stringOrFallback(json['correction'], ''),
      eventIds: _stringList(json['eventIds']),
    );
  }
}

class AarRecommendation {
  const AarRecommendation({
    required this.title,
    required this.details,
    this.linkedMistakeRank,
  });

  final String title;
  final String details;
  final int? linkedMistakeRank;

  Map<String, dynamic> toJson() => {
    'title': title,
    'details': details,
    if (linkedMistakeRank != null) 'linkedMistakeRank': linkedMistakeRank,
  };

  factory AarRecommendation.fromJson(Map<String, dynamic> json) {
    return AarRecommendation(
      title: _stringOrFallback(json['title'], 'Recommendation'),
      details: _stringOrFallback(json['details'], ''),
      linkedMistakeRank: _nullableInt(json['linkedMistakeRank']),
    );
  }
}

class AarFitAdvice {
  const AarFitAdvice({
    required this.title,
    required this.details,
    required this.confidence,
    required this.observedItems,
    required this.recommendedItems,
    required this.limitations,
  });

  final String title;
  final String details;
  final String confidence;
  final List<String> observedItems;
  final List<String> recommendedItems;
  final String limitations;

  Map<String, dynamic> toJson() => {
    'title': title,
    'details': details,
    'confidence': confidence,
    'observedItems': observedItems,
    'recommendedItems': recommendedItems,
    'limitations': limitations,
  };

  factory AarFitAdvice.fromJson(Map<String, dynamic> json) {
    return AarFitAdvice(
      title: _stringOrFallback(json['title'], 'Fit Advice'),
      details: _stringOrFallback(json['details'], ''),
      confidence: _stringOrFallback(json['confidence'], 'unknown'),
      observedItems: _stringList(json['observedItems']),
      recommendedItems: _stringList(json['recommendedItems']),
      limitations: _stringOrFallback(json['limitations'], ''),
    );
  }
}

class AarTrainingDrill {
  const AarTrainingDrill({required this.title, required this.details});

  final String title;
  final String details;

  Map<String, dynamic> toJson() => {'title': title, 'details': details};

  factory AarTrainingDrill.fromJson(Map<String, dynamic> json) {
    return AarTrainingDrill(
      title: _stringOrFallback(json['title'], 'Training Drill'),
      details: _stringOrFallback(json['details'], ''),
    );
  }
}

class AarDamageAnalysis {
  const AarDamageAnalysis({
    required this.summary,
    required this.evidence,
    required this.damageTypes,
    required this.defenseNotes,
    required this.confidence,
    required this.unknowns,
  });

  const AarDamageAnalysis.empty()
    : summary = '',
      evidence = '',
      damageTypes = const [],
      defenseNotes = const [],
      confidence = 0,
      unknowns = const [];

  final String summary;
  final String evidence;
  final List<AarDamageTypeEntry> damageTypes;
  final List<AarDefenseNote> defenseNotes;
  final double confidence;
  final List<String> unknowns;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      evidence.trim().isEmpty &&
      damageTypes.isEmpty &&
      defenseNotes.isEmpty &&
      unknowns.isEmpty;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'evidence': evidence,
    'damageTypes': damageTypes.map((entry) => entry.toJson()).toList(),
    'defenseNotes': defenseNotes.map((note) => note.toJson()).toList(),
    'confidence': confidence,
    'unknowns': unknowns,
  };

  factory AarDamageAnalysis.fromJson(Map<String, dynamic> json) {
    return AarDamageAnalysis(
      summary: _stringOrFallback(json['summary'], ''),
      evidence: _stringOrFallback(json['evidence'], ''),
      damageTypes: _objectList(
        json['damageTypes'],
      ).map(AarDamageTypeEntry.fromJson).toList(),
      defenseNotes: _objectList(
        json['defenseNotes'],
      ).map(AarDefenseNote.fromJson).toList(),
      confidence: _doubleFromJson(json['confidence'], fallback: 0),
      unknowns: _stringList(json['unknowns']),
    );
  }
}

class AarDamageTypeEntry {
  const AarDamageTypeEntry({
    required this.type,
    required this.percent,
    required this.amount,
    required this.confidence,
    required this.source,
    required this.evidence,
  });

  final String type;
  final double percent;
  final int amount;
  final String confidence;
  final String source;
  final String evidence;

  Map<String, dynamic> toJson() => {
    'type': type,
    'percent': percent,
    'amount': amount,
    'confidence': confidence,
    'source': source,
    'evidence': evidence,
  };

  factory AarDamageTypeEntry.fromJson(Map<String, dynamic> json) {
    return AarDamageTypeEntry(
      type: _stringOrFallback(json['type'], 'unknown'),
      percent: _doubleFromJson(json['percent'], fallback: 0),
      amount: _intFromJson(json['amount'], fallback: 0),
      confidence: _stringOrFallback(json['confidence'], 'unknown'),
      source: _stringOrFallback(json['source'], 'unknown'),
      evidence: _stringOrFallback(json['evidence'], ''),
    );
  }
}

class AarDefenseNote {
  const AarDefenseNote({
    required this.layer,
    required this.note,
    required this.confidence,
    required this.evidence,
  });

  final String layer;
  final String note;
  final String confidence;
  final String evidence;

  Map<String, dynamic> toJson() => {
    'layer': layer,
    'note': note,
    'confidence': confidence,
    'evidence': evidence,
  };

  factory AarDefenseNote.fromJson(Map<String, dynamic> json) {
    return AarDefenseNote(
      layer: _stringOrFallback(json['layer'], 'unknown'),
      note: _stringOrFallback(json['note'], ''),
      confidence: _stringOrFallback(json['confidence'], 'unknown'),
      evidence: _stringOrFallback(json['evidence'], ''),
    );
  }
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _objectFromJson(Object? value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(value);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toList();
}

String _stringOrFallback(Object? value, String fallback) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

int _intFromJson(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _doubleFromJson(Object? value, {required double fallback}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

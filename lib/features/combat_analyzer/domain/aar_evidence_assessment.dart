enum AarEvidenceDimension {
  pilotFit,
  combatLog,
  opponentIdentity,
  opponentFit,
  damageProfile;

  int get weight => AarEvidenceRules.weights[this]!;

  String get label => switch (this) {
    AarEvidenceDimension.pilotFit => 'Pilot fit',
    AarEvidenceDimension.combatLog => 'Combat log',
    AarEvidenceDimension.opponentIdentity => 'Opponent identity',
    AarEvidenceDimension.opponentFit => 'Opponent fit',
    AarEvidenceDimension.damageProfile => 'Damage profile',
  };
}

enum AarEvidenceStatus {
  complete,
  partial,
  inferred,
  missing,
  unavailable;

  double? get credit => switch (this) {
    AarEvidenceStatus.complete => AarEvidenceRules.creditComplete,
    AarEvidenceStatus.partial => AarEvidenceRules.creditPartial,
    AarEvidenceStatus.inferred => AarEvidenceRules.creditInferred,
    AarEvidenceStatus.missing => AarEvidenceRules.creditMissing,
    AarEvidenceStatus.unavailable => null,
  };

  int get sortRank => switch (this) {
    AarEvidenceStatus.missing => 0,
    AarEvidenceStatus.partial => 1,
    AarEvidenceStatus.inferred => 2,
    AarEvidenceStatus.complete => 3,
    AarEvidenceStatus.unavailable => 4,
  };

  String get label => switch (this) {
    AarEvidenceStatus.complete => 'Complete',
    AarEvidenceStatus.partial => 'Partial',
    AarEvidenceStatus.inferred => 'Inferred',
    AarEvidenceStatus.missing => 'Missing',
    AarEvidenceStatus.unavailable => 'Unavailable',
  };
}

enum AarEvidenceBand {
  low,
  partial,
  good,
  complete;

  static AarEvidenceBand of(int score) {
    if (score >= AarEvidenceRules.bandCompleteMin) {
      return AarEvidenceBand.complete;
    }
    if (score >= AarEvidenceRules.bandGoodMin) return AarEvidenceBand.good;
    if (score >= AarEvidenceRules.bandPartialMin) {
      return AarEvidenceBand.partial;
    }
    return AarEvidenceBand.low;
  }

  String get label => switch (this) {
    AarEvidenceBand.low => 'Low',
    AarEvidenceBand.partial => 'Partial',
    AarEvidenceBand.good => 'Good',
    AarEvidenceBand.complete => 'Complete',
  };

  String get description => switch (this) {
    AarEvidenceBand.low =>
      'Analysis at this evidence level will produce general coaching, not specific fit advice.',
    AarEvidenceBand.partial =>
      'Analysis will cover damage and timeline. Fit-specific conclusions will be limited.',
    AarEvidenceBand.good =>
      'Most conclusions are supported; minor gaps remain.',
    AarEvidenceBand.complete =>
      'Fit-specific, quantitative conclusions are available.',
  };
}

enum AarEvidenceAction {
  useCurrentFit,
  importFit,
  searchKillmails,
  reauthorize;

  String get buttonLabel => switch (this) {
    AarEvidenceAction.useCurrentFit => 'Use Current Fit',
    AarEvidenceAction.importFit => 'Import Fit',
    AarEvidenceAction.searchKillmails => 'Search Killmails',
    AarEvidenceAction.reauthorize => 'Reauthorize Character',
  };

  String get hint => switch (this) {
    AarEvidenceAction.useCurrentFit ||
    AarEvidenceAction.importFit => 'Attaching your fit',
    AarEvidenceAction.searchKillmails => 'Searching for the killmail',
    AarEvidenceAction.reauthorize => 'Reauthorizing this character',
  };
}

/// Domain-side UTC formatter ('2026-09-10 18:00 UTC') used by D1 detail text.
String formatAarUtcMinute(DateTime value) {
  final utc = value.toUtc();
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute UTC';
}

abstract final class AarEvidenceRules {
  static const Map<AarEvidenceDimension, int> weights = {
    AarEvidenceDimension.pilotFit: 30,
    AarEvidenceDimension.combatLog: 20,
    AarEvidenceDimension.opponentIdentity: 15,
    AarEvidenceDimension.opponentFit: 20,
    AarEvidenceDimension.damageProfile: 15,
  };
  static const double creditComplete = 1.0;
  static const double creditPartial = 0.5;
  static const double creditInferred = 0.3;
  static const double creditMissing = 0.0;
  static const int bandCompleteMin = 90;
  static const int bandGoodMin = 75;
  static const int bandPartialMin = 40;
  static const int minDamageEventsForComplete = 20;
  static const double matchConfidenceComplete = 0.8;
  static const double minTypedFractionForPartial = 0.7;
  static const int reanalysisDelta = 10;
  static const int gateWarnBelow = 40;
  static const int gateAdviseBelow = 75;
  static const int collapseAtOrAbove = 90;
}

class AarStructuralLimit {
  const AarStructuralLimit({required this.label, required this.detail});

  final String label;
  final String detail;

  static const range = AarStructuralLimit(
    label: 'Engagement range',
    detail: 'Engagement range is not recorded in EVE combat logs.',
  );
}

class AarEvidenceDimensionResult {
  const AarEvidenceDimensionResult({
    required this.dimension,
    required this.status,
    required this.detail,
    this.actions = const [],
  });

  final AarEvidenceDimension dimension;
  final AarEvidenceStatus status;
  final String detail;
  final List<AarEvidenceAction> actions;

  int get weight => dimension.weight;

  double get earned => status.credit == null ? 0 : weight * status.credit!;

  int get pointsToComplete =>
      status == AarEvidenceStatus.unavailable ? 0 : (weight - earned).round();

  bool get isActionable => actions.isNotEmpty;
}

class AarEvidenceAssessment {
  const AarEvidenceAssessment({
    required this.dimensions,
    required this.score,
    required this.band,
    required this.capped,
    required this.earned,
    required this.available,
    this.structuralLimits = const [AarStructuralLimit.range],
  });

  final List<AarEvidenceDimensionResult> dimensions;
  final int score;
  final AarEvidenceBand band;
  final bool capped;
  final double earned;
  final int available;
  final List<AarStructuralLimit> structuralLimits;

  String get bandLabel => capped ? '${band.label} (capped)' : band.label;

  String get scoreLabel => '$score% $bandLabel';

  List<AarEvidenceDimensionResult> get ordered {
    final copy = [...dimensions];
    copy.sort((a, b) {
      final rank = a.status.sortRank.compareTo(b.status.sortRank);
      if (rank != 0) return rank;
      final byWeight = b.weight.compareTo(a.weight);
      if (byWeight != 0) return byWeight;
      return a.dimension.index.compareTo(b.dimension.index);
    });
    return copy;
  }

  AarEvidenceDimensionResult? get topGap {
    for (final row in ordered) {
      if (row.status == AarEvidenceStatus.missing ||
          row.status == AarEvidenceStatus.partial ||
          row.status == AarEvidenceStatus.inferred) {
        return row;
      }
    }
    return null;
  }

  AarEvidenceDimensionResult operator [](AarEvidenceDimension dimension) {
    for (final row in dimensions) {
      if (row.dimension == dimension) return row;
    }
    throw ArgumentError.value(dimension, 'dimension', 'not in assessment');
  }

  int projectedScoreIf(
    AarEvidenceDimension dimension,
    AarEvidenceStatus status,
  ) {
    var earnedTotal = 0.0;
    var availableTotal = 0;
    for (final row in dimensions) {
      final next = row.dimension == dimension
          ? AarEvidenceDimensionResult(
              dimension: row.dimension,
              status: status,
              detail: row.detail,
              actions: row.actions,
            )
          : row;
      if (next.status == AarEvidenceStatus.unavailable) continue;
      earnedTotal += next.earned;
      availableTotal += next.weight;
    }
    if (availableTotal == 0) return 0;
    return ((100 * earnedTotal) / availableTotal).round();
  }

  String get headline {
    final gap = topGap;
    final base = switch (band) {
      AarEvidenceBand.low => _lowHeadline(gap),
      AarEvidenceBand.partial =>
        'Analysis will cover damage and timeline. Fit-specific conclusions will be limited.',
      AarEvidenceBand.good =>
        'Most conclusions are supported; minor gaps remain.',
      AarEvidenceBand.complete =>
        'Fit-specific, quantitative conclusions are available.',
    };
    if (!capped) return base;
    AarEvidenceDimensionResult? firstUnavailable;
    for (final row in dimensions) {
      if (row.status == AarEvidenceStatus.unavailable) {
        firstUnavailable = row;
        break;
      }
    }
    if (firstUnavailable == null) return base;
    return '$base ${firstUnavailable.detail}';
  }

  String _lowHeadline(AarEvidenceDimensionResult? gap) {
    final lead =
        'Analysis at $score% evidence will produce general coaching, not specific fit advice.';
    if (gap == null) return lead;
    final projected = projectedScoreIf(
      gap.dimension,
      AarEvidenceStatus.complete,
    );
    final hint = gap.actions.isNotEmpty
        ? gap.actions.first.hint
        : 'Resolving ${gap.dimension.label}';
    return '$lead $hint would raise this to about $projected%.';
  }

  bool get collapsedByDefault => score >= AarEvidenceRules.collapseAtOrAbove;

  AarEvidenceSnapshot toSnapshot() {
    return AarEvidenceSnapshot(
      score: score,
      band: band,
      capped: capped,
      statuses: {for (final row in dimensions) row.dimension: row.status},
    );
  }

  String get logLine {
    final statuses = [
      for (final row in dimensions) '${row.dimension.name}=${row.status.name}',
    ].join(' ');
    return 'score=$score band=${band.name} capped=$capped $statuses';
  }
}

class AarEvidenceSnapshot {
  const AarEvidenceSnapshot({
    required this.score,
    required this.band,
    required this.capped,
    required this.statuses,
  });

  final int score;
  final AarEvidenceBand band;
  final bool capped;
  final Map<AarEvidenceDimension, AarEvidenceStatus> statuses;

  String get label =>
      capped ? '$score% ${band.label} (capped)' : '$score% ${band.label}';

  bool shouldOfferReanalysis(int currentScore) =>
      currentScore - score >= AarEvidenceRules.reanalysisDelta;

  Map<String, dynamic> toJson() => {
    'score': score,
    'band': band.name,
    'capped': capped,
    'statuses': {
      for (final entry in statuses.entries) entry.key.name: entry.value.name,
    },
  };

  static AarEvidenceSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final rawScore = map['score'];
    final score = rawScore is int
        ? rawScore
        : rawScore is num
        ? rawScore.toInt()
        : int.tryParse(rawScore?.toString() ?? '');
    if (score == null) return null;
    final band =
        _bandFromName(map['band']?.toString()) ?? AarEvidenceBand.of(score);
    final statuses = <AarEvidenceDimension, AarEvidenceStatus>{};
    final rawStatuses = map['statuses'];
    if (rawStatuses is Map) {
      for (final entry in rawStatuses.entries) {
        final dimension = _dimensionFromName(entry.key.toString());
        final status = _statusFromName(entry.value?.toString());
        if (dimension != null && status != null) {
          statuses[dimension] = status;
        }
      }
    }
    return AarEvidenceSnapshot(
      score: score,
      band: band,
      capped: map['capped'] == true,
      statuses: statuses,
    );
  }
}

AarEvidenceBand? _bandFromName(String? name) {
  for (final value in AarEvidenceBand.values) {
    if (value.name == name) return value;
  }
  return null;
}

AarEvidenceDimension? _dimensionFromName(String? name) {
  for (final value in AarEvidenceDimension.values) {
    if (value.name == name) return value;
  }
  return null;
}

AarEvidenceStatus? _statusFromName(String? name) {
  for (final value in AarEvidenceStatus.values) {
    if (value.name == name) return value;
  }
  return null;
}

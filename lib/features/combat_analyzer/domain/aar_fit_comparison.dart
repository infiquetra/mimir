import 'aar_fit_proposal.dart';
import 'aar_fit_snapshot.dart';
import 'combat_aar_report.dart';

enum AarComparisonRole {
  fightFit,
  currentSnapshot,
  victim,
  proposal,
  reference,
}

enum AarBomMode { changes, fullReplacement }

class AarComparisonContext {
  const AarComparisonContext({
    required this.skillFingerprint,
    required this.profileKey,
    required this.sdeRevision,
    required this.calculatorRevision,
  });

  final String skillFingerprint;
  final String profileKey;
  final String sdeRevision;
  final String calculatorRevision;
}

class AarComparisonSourceEntry {
  const AarComparisonSourceEntry({
    required this.id,
    required this.role,
    required this.snapshot,
    required this.label,
    this.aliasedRoles = const {},
    this.isHistoricalFallback = false,
  });

  final String id;
  final AarComparisonRole role;
  final AarFitSnapshot snapshot;
  final String label;
  final Set<AarComparisonRole> aliasedRoles;
  final bool isHistoricalFallback;

  bool get aliasesFightFit =>
      role == AarComparisonRole.victim &&
      aliasedRoles.contains(AarComparisonRole.fightFit);
}

class AarComparisonSources {
  AarComparisonSources({
    required this.entries,
    this.legacyGenerationMissing = false,
    this.requiresExplicitBaselineSelection = false,
  });

  final List<AarComparisonSourceEntry> entries;
  final bool legacyGenerationMissing;
  final bool requiresExplicitBaselineSelection;

  AarComparisonSourceEntry? _first(AarComparisonRole role) {
    for (final entry in entries) {
      if (entry.role == role) return entry;
    }
    return null;
  }

  AarComparisonSourceEntry? get fightFit => _first(AarComparisonRole.fightFit);

  AarComparisonSourceEntry? get currentSnapshot =>
      _first(AarComparisonRole.currentSnapshot);

  AarComparisonSourceEntry? get victim => _first(AarComparisonRole.victim);

  AarComparisonSourceEntry? get reference =>
      _first(AarComparisonRole.reference);

  List<AarComparisonSourceEntry> get visibleEntries => entries;

  bool get ownLossDeduplicated =>
      fightFit != null &&
      fightFit!.aliasedRoles.contains(AarComparisonRole.victim);

  factory AarComparisonSources.resolve({
    required int? encounterPilotId,
    bool identityKnown = true,
    bool isVictory = false,
    AarFitSnapshot? generationBaseline,
    AarFitSnapshot? attachedPilot,
    AarFitSnapshot? victim,
    AarFitSnapshot? currentCapture,
    AarFitSnapshot? reference,
    List<AarFitSnapshot> proposals = const [],
  }) {
    final identifiedOwnLoss =
        identityKnown &&
        !isVictory &&
        victim != null &&
        victim.subject.identityKnown &&
        (encounterPilotId == null ||
            victim.subject.characterId == encounterPilotId);
    final fightSnapshot =
        generationBaseline ??
        attachedPilot ??
        (identifiedOwnLoss ? victim : null);
    final collapsedOwnLoss =
        identifiedOwnLoss &&
        fightSnapshot != null &&
        fightSnapshot.snapshotId == victim.snapshotId;

    final entries = <AarComparisonSourceEntry>[];
    if (fightSnapshot != null) {
      entries.add(
        AarComparisonSourceEntry(
          id: fightSnapshot.snapshotId,
          role: AarComparisonRole.fightFit,
          snapshot: fightSnapshot,
          label: 'Fight fit',
          aliasedRoles: collapsedOwnLoss
              ? const {AarComparisonRole.victim}
              : const {},
        ),
      );
    }
    if (currentCapture != null) {
      entries.add(
        AarComparisonSourceEntry(
          id: currentCapture.snapshotId,
          role: AarComparisonRole.currentSnapshot,
          snapshot: currentCapture,
          label: 'Current snapshot',
        ),
      );
    }
    if (victim != null && !collapsedOwnLoss) {
      entries.add(
        AarComparisonSourceEntry(
          id: victim.snapshotId,
          role: AarComparisonRole.victim,
          snapshot: victim,
          label: 'Victim fit',
        ),
      );
    }
    if (reference != null) {
      entries.add(
        AarComparisonSourceEntry(
          id: reference.snapshotId,
          role: AarComparisonRole.reference,
          snapshot: reference,
          label: 'Pilot reference fit',
        ),
      );
    }
    for (final proposal in proposals) {
      entries.add(
        AarComparisonSourceEntry(
          id: proposal.snapshotId,
          role: AarComparisonRole.proposal,
          snapshot: proposal,
          label: 'AI proposal',
        ),
      );
    }
    return AarComparisonSources(
      entries: entries,
      legacyGenerationMissing: generationBaseline == null,
      requiresExplicitBaselineSelection: fightSnapshot == null,
    );
  }
}

class AarComparisonSelection {
  const AarComparisonSelection({
    this.baselineSourceId,
    this.visibleComparisonIds = const [],
    this.selectedProposalId,
    this.bomMode = AarBomMode.changes,
  });

  final String? baselineSourceId;
  final List<String> visibleComparisonIds;
  final String? selectedProposalId;
  final AarBomMode bomMode;

  factory AarComparisonSelection.fromSources(AarComparisonSources sources) {
    return AarComparisonSelection(
      baselineSourceId: sources.fightFit?.id,
      visibleComparisonIds: [
        for (final entry in sources.visibleEntries) entry.id,
      ],
    );
  }
}

class AarFitGenerationRecord {
  const AarFitGenerationRecord({this.selfBaseline, this.reason});

  final AarFitSnapshot? selfBaseline;
  final String? reason;

  static AarFitGenerationRecord? fromReportJson(Map<String, dynamic> json) {
    if (!json.containsKey('fitComparisonAtGeneration')) {
      return null;
    }
    final raw = json['fitComparisonAtGeneration'];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return AarFitGenerationRecord(
      selfBaseline: map.isEmpty ? null : AarFitSnapshot.fromJson(map),
      reason: map['reason']?.toString(),
    );
  }

  static AarFitGenerationRecord? fromReport(CombatAarReport report) {
    return fromReportJson(report.toJson());
  }
}

/// Owned comparison JSON envelope stored on [CombatEnrichment.fitComparison].
class AarFitComparisonState {
  const AarFitComparisonState({
    this.schemaVersion = 1,
    this.currentSnapshot,
    this.userProposal,
  });

  final int schemaVersion;
  final AarFitSnapshot? currentSnapshot;
  final AarFitProposal? userProposal;

  AarFitComparisonState withCurrentSnapshot(AarFitSnapshot? snapshot) {
    return AarFitComparisonState(
      schemaVersion: schemaVersion,
      currentSnapshot: snapshot,
      userProposal: userProposal,
    );
  }

  AarFitComparisonState withUserProposal(AarFitProposal? proposal) {
    return AarFitComparisonState(
      schemaVersion: schemaVersion,
      currentSnapshot: currentSnapshot,
      userProposal: proposal,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    if (currentSnapshot != null) 'currentSnapshot': currentSnapshot!.toJson(),
    if (userProposal != null) 'userProposal': userProposal!.toJson(),
  };

  factory AarFitComparisonState.fromJson(Map<String, dynamic> json) {
    return AarFitComparisonState(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      currentSnapshot: json['currentSnapshot'] is Map
          ? AarFitSnapshot.fromJson(
              Map<String, dynamic>.from(json['currentSnapshot'] as Map),
            )
          : null,
      userProposal: json['userProposal'] is Map
          ? AarFitProposal.fromJson(
              Map<String, dynamic>.from(json['userProposal'] as Map),
            )
          : null,
    );
  }
}

import '../../fitting/domain/models.dart';
import 'aar_fit_snapshot.dart';
import 'combat_aar_report.dart';

/// Compile stub for W0 selection/context/generation types.
/// GREEN implements identity-aware P05 selection and absent-key tolerance.
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

  /// Naive killmail-first selection: victim wins fight-fit, unknown identity
  /// still falls back, reference is promoted, own-loss is not collapsed.
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
    final entries = <AarComparisonSourceEntry>[];
    final fight = victim ?? attachedPilot ?? generationBaseline ?? reference;
    if (fight != null) {
      entries.add(
        AarComparisonSourceEntry(
          id: fight.snapshotId,
          role: AarComparisonRole.fightFit,
          snapshot: fight,
          label: 'Fight fit',
          isHistoricalFallback: identical(fight, reference),
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
    if (victim != null) {
      entries.add(
        AarComparisonSourceEntry(
          id: victim.snapshotId,
          role: AarComparisonRole.victim,
          snapshot: victim,
          label: 'Victim',
        ),
      );
    }
    if (reference != null) {
      entries.add(
        AarComparisonSourceEntry(
          id: reference.snapshotId,
          role: AarComparisonRole.reference,
          snapshot: reference,
          label: 'Fight fit',
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
      legacyGenerationMissing: false,
      requiresExplicitBaselineSelection: false,
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

/// Naive generation binder. GREEN returns null when the report JSON has no
/// `fitComparisonAtGeneration` key and never synthesizes type-id-0 content.
class AarFitGenerationRecord {
  const AarFitGenerationRecord({this.selfBaseline, this.reason});

  final AarFitSnapshot? selfBaseline;
  final String? reason;

  static AarFitGenerationRecord? fromReportJson(Map<String, dynamic> json) {
    return AarFitGenerationRecord(
      selfBaseline: AarFitSnapshot(
        snapshotId: 'mock-generation',
        encounterId: json['encounterId']?.toString() ?? 'mock',
        fitting: const Fitting(
          id: 'mock',
          name: 'Mock Generation Fit',
          shipTypeId: 0,
          shipName: 'Mock',
        ),
        source: AarFitSource.evidenceAttachment,
        subject: const AarFitSubject(relation: AarFitSubjectRelation.pilot),
      ),
      reason: 'legacy-inferred',
    );
  }

  static AarFitGenerationRecord? fromReport(CombatAarReport report) {
    return fromReportJson(report.toJson());
  }
}

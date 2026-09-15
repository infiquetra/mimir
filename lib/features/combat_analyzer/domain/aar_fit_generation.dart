import 'aar_fit_proposal.dart';
import 'aar_fit_snapshot.dart';
import 'combat_evidence_ledger.dart';

/// Compile stub for W2 generation binding. GREEN stores prepared snapshots,
/// derivation baseline reason, and calculation revisions without fabrication.
class AarFitGenerationRecord {
  const AarFitGenerationRecord({
    this.generationId,
    this.encounterId,
    this.preparedAt,
    this.selfBaseline,
    this.selfBaselineSnapshotId,
    this.reason,
    this.suppliedPilotFingerprint,
    this.derivationBaselineSnapshotId,
    this.calculatorRevision,
    this.sdeContentKey,
    this.victimSnapshot,
  });

  final String? generationId;
  final String? encounterId;
  final DateTime? preparedAt;
  final AarFitSnapshot? selfBaseline;
  final String? selfBaselineSnapshotId;
  final String? reason;
  final String? suppliedPilotFingerprint;
  final String? derivationBaselineSnapshotId;
  final String? calculatorRevision;
  final String? sdeContentKey;
  final AarFitSnapshot? victimSnapshot;

  Map<String, dynamic> toJson() => {
    if (generationId != null) 'generationId': generationId,
    if (encounterId != null) 'encounterId': encounterId,
    if (preparedAt != null) 'preparedAt': preparedAt!.toUtc().toIso8601String(),
    if (selfBaseline != null) 'selfBaseline': selfBaseline!.toJson(),
    if (selfBaselineSnapshotId != null)
      'selfBaselineSnapshotId': selfBaselineSnapshotId,
    if (reason != null) 'reason': reason,
    if (suppliedPilotFingerprint != null)
      'suppliedPilotFingerprint': suppliedPilotFingerprint,
    if (derivationBaselineSnapshotId != null)
      'derivationBaselineSnapshotId': derivationBaselineSnapshotId,
    if (calculatorRevision != null) 'calculatorRevision': calculatorRevision,
    if (sdeContentKey != null) 'sdeContentKey': sdeContentKey,
    if (victimSnapshot != null) 'victimSnapshot': victimSnapshot!.toJson(),
  };

  factory AarFitGenerationRecord.fromJson(Map<String, dynamic> json) {
    return AarFitGenerationRecord(
      generationId: json['generationId']?.toString(),
      encounterId: json['encounterId']?.toString(),
      preparedAt: DateTime.tryParse(json['preparedAt']?.toString() ?? ''),
      selfBaseline: json['selfBaseline'] is Map
          ? AarFitSnapshot.fromJson(
              Map<String, dynamic>.from(json['selfBaseline'] as Map),
            )
          : json['snapshotId'] != null
          ? AarFitSnapshot.fromJson(json)
          : null,
      selfBaselineSnapshotId: json['selfBaselineSnapshotId']?.toString(),
      reason: json['reason']?.toString(),
      suppliedPilotFingerprint: json['suppliedPilotFingerprint']?.toString(),
      derivationBaselineSnapshotId: json['derivationBaselineSnapshotId']
          ?.toString(),
      calculatorRevision: json['calculatorRevision']?.toString(),
      sdeContentKey: json['sdeContentKey']?.toString(),
      victimSnapshot: json['victimSnapshot'] is Map
          ? AarFitSnapshot.fromJson(
              Map<String, dynamic>.from(json['victimSnapshot'] as Map),
            )
          : null,
    );
  }

  static AarFitGenerationRecord? fromReportJson(Map<String, dynamic> json) {
    if (!json.containsKey('fitComparisonAtGeneration')) {
      return null;
    }
    final raw = json['fitComparisonAtGeneration'];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map.isEmpty) return null;
    return AarFitGenerationRecord.fromJson(map);
  }
}

/// Frozen comparison input built before the AI await.
class PreparedAarComparisonInput {
  const PreparedAarComparisonInput({
    required this.encounterId,
    required this.generationId,
    this.preparedAt,
    this.suppliedPilot,
    this.victim,
    this.derivationBaseline,
    this.derivationBaselineReason,
    this.calculatorRevision = 'unknown',
    this.sdeContentKey = 'sde-decimal-v1',
  });

  final String encounterId;
  final String generationId;
  final DateTime? preparedAt;
  final AarFitSnapshot? suppliedPilot;
  final AarFitSnapshot? victim;
  final AarFitSnapshot? derivationBaseline;
  final String? derivationBaselineReason;
  final String calculatorRevision;
  final String sdeContentKey;

  /// Naive: first non-null fit is both supplied pilot and derivation baseline.
  factory PreparedAarComparisonInput.fromEvidence({
    required String encounterId,
    FitEvidence? pilotFitEvidence,
    FitEvidence? victimFitEvidence,
    DateTime? preparedAt,
  }) {
    final supplied = pilotFitEvidence == null
        ? null
        : AarFitSnapshot.fromFitEvidence(
            encounterId: encounterId,
            evidence: pilotFitEvidence,
          );
    final victim = victimFitEvidence == null
        ? null
        : AarFitSnapshot.fromFitEvidence(
            encounterId: encounterId,
            evidence: victimFitEvidence,
          );
    final first = supplied ?? victim;
    return PreparedAarComparisonInput(
      encounterId: encounterId,
      generationId: 'gen-$encounterId',
      preparedAt: preparedAt,
      suppliedPilot: first,
      victim: victim,
      derivationBaseline: first,
      derivationBaselineReason: first == null
          ? 'none'
          : (supplied == null ? 'first-available' : 'pilot'),
    );
  }

  AarFitGenerationRecord toGenerationRecord() {
    return AarFitGenerationRecord(
      generationId: generationId,
      encounterId: encounterId,
      preparedAt: preparedAt,
      selfBaseline: derivationBaseline ?? suppliedPilot,
      selfBaselineSnapshotId: (derivationBaseline ?? suppliedPilot)?.snapshotId,
      reason: derivationBaselineReason,
      suppliedPilotFingerprint: suppliedPilot?.contentFingerprint,
      derivationBaselineSnapshotId: derivationBaseline?.snapshotId,
      calculatorRevision: calculatorRevision,
      sdeContentKey: sdeContentKey,
      victimSnapshot: victim,
    );
  }
}

class AarComparisonAdvice {
  /// Naive: any prepared baseline vs a missing current attachment is stale.
  static bool isStale({
    required FitEvidence? currentPilot,
    required AarFitGenerationRecord? generation,
    String? encounterId,
  }) {
    if (generation == null) return false;
    final prepared =
        generation.suppliedPilotFingerprint ??
        generation.selfBaseline?.contentFingerprint;
    if (currentPilot == null) {
      return prepared != null;
    }
    if (prepared == null) return false;
    final attached = AarFitSnapshot.fromFitEvidence(
      encounterId: encounterId ?? generation.encounterId ?? '',
      evidence: currentPilot,
    );
    return attached.contentFingerprint != prepared;
  }
}

/// Naive candidate adapter. GREEN validates before Fitting.fromJson defaults.
class AarFitCandidateValidator {
  const AarFitCandidateValidator();

  AarFitProposal validate(
    Map<String, dynamic> raw, {
    required String encounterId,
    required String proposalId,
    String? preparedBaselineId,
    String? preparedFingerprint,
    String? preparedEncounterId,
  }) {
    return AarFitProposal.fromRaw(
      raw: raw,
      encounterId: preparedEncounterId ?? encounterId,
      proposalId: proposalId,
      origin: AarProposalOrigin.ai,
      baselineSnapshotId: preparedBaselineId,
      baselineFingerprint: preparedFingerprint,
    );
  }
}

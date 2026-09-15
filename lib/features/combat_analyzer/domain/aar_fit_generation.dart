import '../../fitting/domain/models.dart';
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
    this.derivationInputRefs = const {},
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
  final Map<String, String> derivationInputRefs;

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
    if (derivationInputRefs.isNotEmpty)
      'derivationInputRefs': derivationInputRefs,
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
      derivationInputRefs: {
        if (json['derivationInputRefs'] is Map)
          for (final entry in (json['derivationInputRefs'] as Map).entries)
            entry.key.toString(): entry.value.toString(),
      },
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

  factory PreparedAarComparisonInput.fromEvidence({
    required String encounterId,
    FitEvidence? pilotFitEvidence,
    FitEvidence? victimFitEvidence,
    DateTime? preparedAt,
    int? selfCharacterId,
    int? victimCharacterId,
    bool? pilotDerivationFailed,
    String calculatorRevision = 'unknown',
    String sdeContentKey = 'sde-decimal-v1',
  }) {
    final at = preparedAt ?? DateTime.now().toUtc();
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
    final failed =
        pilotDerivationFailed ??
        (pilotFitEvidence != null && _pilotLooksUnderivable(pilotFitEvidence));
    final ownVictimEligible =
        victim != null &&
        (selfCharacterId == null ||
            (victimCharacterId != null &&
                selfCharacterId == victimCharacterId));
    final useVictimBaseline = failed && ownVictimEligible;
    return PreparedAarComparisonInput(
      encounterId: encounterId,
      generationId: 'gen-$encounterId-${at.microsecondsSinceEpoch}',
      preparedAt: at,
      suppliedPilot: supplied,
      victim: victim,
      derivationBaseline: useVictimBaseline ? victim : supplied,
      derivationBaselineReason: useVictimBaseline
          ? 'own-victim killmail after failed pilot derivation'
          : (supplied == null ? 'none' : 'pilot evidence'),
      calculatorRevision: calculatorRevision,
      sdeContentKey: sdeContentKey,
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
      derivationInputRefs: {
        if (suppliedPilot != null) 'suppliedPilot': suppliedPilot!.snapshotId,
        if (derivationBaseline != null)
          'derivationBaseline': derivationBaseline!.snapshotId,
        if (victim != null) 'victim': victim!.snapshotId,
      },
    );
  }

  Map<String, dynamic> toPromptJson({int vocabularyLimit = 512}) {
    final typeIds = <int>{};
    void addFitting(Fitting? fitting) {
      if (fitting == null) return;
      if (fitting.shipTypeId > 0) typeIds.add(fitting.shipTypeId);
      for (final module in fitting.allModules) {
        if (module.typeId > 0) typeIds.add(module.typeId);
        final chargeId = module.chargeTypeId;
        if (chargeId != null && chargeId > 0) typeIds.add(chargeId);
      }
      for (final drone in fitting.drones) {
        if (drone.typeId > 0) typeIds.add(drone.typeId);
      }
      for (final fighter in fitting.fighters) {
        if (fighter.typeId > 0) typeIds.add(fighter.typeId);
      }
      for (final cargo in fitting.cargo) {
        if (cargo.typeId > 0) typeIds.add(cargo.typeId);
      }
    }

    addFitting(suppliedPilot?.fitting);
    addFitting(victim?.fitting);
    addFitting(derivationBaseline?.fitting);
    final ordered = typeIds.toList()..sort();
    final truncated = ordered.length > vocabularyLimit;
    return {
      'schemaVersion': 1,
      'generationId': generationId,
      'encounterId': encounterId,
      if (preparedAt != null)
        'preparedAt': preparedAt!.toUtc().toIso8601String(),
      if (derivationBaseline != null) ...{
        'preparedBaselineSnapshotId': derivationBaseline!.snapshotId,
        'preparedBaselineFingerprint': derivationBaseline!.contentFingerprint,
      },
      if (suppliedPilot != null)
        'suppliedPilotFingerprint': suppliedPilot!.contentFingerprint,
      if (derivationBaselineReason != null)
        'derivationBaselineReason': derivationBaselineReason,
      'typeVocabulary': ordered.take(vocabularyLimit).toList(),
      'typeVocabularyTruncated': truncated,
      'typeVocabularyLimit': vocabularyLimit,
    };
  }
}

bool _pilotLooksUnderivable(FitEvidence evidence) {
  final typeId = evidence.fitting.shipTypeId;
  return typeId <= 0 || typeId >= 99999;
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
    bool Function(int typeId)? isKnownType,
  }) {
    return AarFitProposal.fromRaw(
      raw: raw,
      encounterId: preparedEncounterId ?? encounterId,
      proposalId: proposalId,
      origin: AarProposalOrigin.ai,
      baselineSnapshotId: preparedBaselineId,
      baselineFingerprint: preparedFingerprint,
      isKnownType: isKnownType,
    );
  }
}

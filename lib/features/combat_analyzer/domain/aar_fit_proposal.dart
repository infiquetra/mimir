import '../../fitting/domain/models.dart';
import 'aar_fit_snapshot.dart';

enum AarProposalOrigin { ai, savedReference, importedReference }

enum AarProposalValidationStatus {
  validated,
  partial,
  invalid,
  unsupportedVersion,
  localDataUnavailable,
}

class AarFitProposal {
  AarFitProposal({
    this.schemaVersion = 1,
    required this.proposalId,
    required this.origin,
    required this.encounterId,
    this.baselineSnapshotId,
    this.baselineFingerprint,
    this.target,
    this.status = AarProposalValidationStatus.validated,
    this.rationale = '',
    List<String> limitations = const [],
  }) : limitations = List<String>.from(limitations);

  final int schemaVersion;
  final String proposalId;
  final AarProposalOrigin origin;
  final String encounterId;
  final String? baselineSnapshotId;
  final String? baselineFingerprint;
  final AarFitSnapshot? target;
  final AarProposalValidationStatus status;
  final String rationale;
  final List<String> limitations;

  factory AarFitProposal.fromRaw({
    required Map<String, dynamic> raw,
    required String encounterId,
    required String proposalId,
    AarProposalOrigin origin = AarProposalOrigin.ai,
    String? baselineSnapshotId,
    String? baselineFingerprint,
  }) {
    final targetJson = raw['target'];
    final targetMap = targetJson is Map
        ? Map<String, dynamic>.from(targetJson)
        : const <String, dynamic>{};
    final groups = targetMap['groups'];
    final fitting = Fitting(
      id: proposalId,
      name: raw['label']?.toString() ?? proposalId,
      shipTypeId: targetMap['shipTypeId'] as int? ?? 0,
      shipName: targetMap['shipName']?.toString() ?? '',
    );
    return AarFitProposal(
      proposalId: proposalId,
      origin: origin,
      encounterId: encounterId,
      baselineSnapshotId: baselineSnapshotId,
      baselineFingerprint: baselineFingerprint,
      target: AarFitSnapshot.fromStructuredCandidate(
        encounterId: encounterId,
        fitting: fitting,
        raw: raw,
      ),
      status: _statusForGroups(groups),
      rationale: raw['rationale']?.toString() ?? '',
    );
  }

  static AarProposalValidationStatus _statusForGroups(Object? groups) {
    if (groups is! Map) return AarProposalValidationStatus.invalid;
    final present = groups.keys.map((key) => key.toString()).toSet();
    const required = {
      'high',
      'mid',
      'low',
      'rigs',
      'subsystems',
      'drones',
      'fighters',
      'cargo',
    };
    if (present.containsAll(required)) {
      return AarProposalValidationStatus.validated;
    }
    if (present.isEmpty) return AarProposalValidationStatus.invalid;
    return AarProposalValidationStatus.partial;
  }
}

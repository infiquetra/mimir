import '../../fitting/domain/models.dart';
import 'aar_fit_snapshot.dart';

/// Compile stub for W0 proposal envelopes.
/// GREEN validates group presence before [Fitting.fromJson] defaults.
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
    this.limitations = const [],
  });

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

  /// Naive: always validated and complete, even when groups are omitted.
  factory AarFitProposal.fromRaw({
    required Map<String, dynamic> raw,
    required String encounterId,
    required String proposalId,
    AarProposalOrigin origin = AarProposalOrigin.ai,
    String? baselineSnapshotId,
    String? baselineFingerprint,
  }) {
    final targetJson = raw['target'];
    final fitting = targetJson is Map
        ? Fitting.fromJson({
            'id': proposalId,
            'name': raw['label']?.toString() ?? proposalId,
            'shipTypeId': targetJson['shipTypeId'] ?? 0,
            'shipName': targetJson['shipName']?.toString() ?? '',
          })
        : const Fitting(id: '', name: '', shipTypeId: 0, shipName: '');
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
      status: AarProposalValidationStatus.validated,
      rationale: raw['rationale']?.toString() ?? '',
    );
  }
}

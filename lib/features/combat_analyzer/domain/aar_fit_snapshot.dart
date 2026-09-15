import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../fitting/domain/models.dart';
import 'combat_evidence_ledger.dart';

/// Compile stub for W0. GREEN replaces naive fingerprints, knowledge
/// policies, and list isolation with the design contracts.
enum AarFitSource {
  evidenceAttachment,
  comparisonCapture,
  killmailVictim,
  savedReference,
  importedProposal,
  aiProposal,
}

enum AarFitSubjectRelation { pilot, victim, reference }

enum FitInventoryGroup {
  high,
  mid,
  low,
  rigs,
  subsystems,
  drones,
  fighters,
  cargo,
}

enum InventoryCompleteness { recordedComplete, partial, unknown }

enum GroupApplicability { applicable, notApplicable, unknown }

enum SlotPositionMeaning { recorded, orderOnly }

enum ChargeKnowledge { recordedAbsent, recordedIdentity, unknown }

enum StateKnowledge { recorded, assumed }

class AarFitSubject {
  const AarFitSubject({
    this.characterId,
    this.identityKnown = true,
    required this.relation,
  });

  final int? characterId;
  final bool identityKnown;
  final AarFitSubjectRelation relation;
}

class AarFitSourceRef {
  const AarFitSourceRef({
    this.killmailId,
    this.victimCharacterId,
    this.savedFittingId,
    this.attachmentId,
    this.reportId,
  });

  final int? killmailId;
  final int? victimCharacterId;
  final String? savedFittingId;
  final String? attachmentId;
  final String? reportId;
}

class UnresolvedOccupant {
  const UnresolvedOccupant({
    required this.sourceEntryKey,
    this.typeId,
    this.quantity,
    this.quantityUnknown = false,
    this.group,
    this.physicalIndex,
    this.label = '',
  });

  final String sourceEntryKey;
  final int? typeId;
  final int? quantity;
  final bool quantityUnknown;
  final FitInventoryGroup? group;
  final int? physicalIndex;
  final String label;
}

class FitOccurrenceKnowledge {
  const FitOccurrenceKnowledge({
    required this.occurrenceKey,
    this.charge = ChargeKnowledge.unknown,
    this.state = StateKnowledge.assumed,
  });

  final String occurrenceKey;
  final ChargeKnowledge charge;
  final StateKnowledge state;
}

class FitGroupKnowledge {
  const FitGroupKnowledge({
    this.completeness = InventoryCompleteness.unknown,
    this.applicability = GroupApplicability.unknown,
    this.positions = SlotPositionMeaning.orderOnly,
    this.recordedEmptySlots = const [],
    this.unresolvedOccupied = const [],
  });

  final InventoryCompleteness completeness;
  final GroupApplicability applicability;
  final SlotPositionMeaning positions;
  final List<int> recordedEmptySlots;
  final List<UnresolvedOccupant> unresolvedOccupied;
}

class FitInventoryKnowledge {
  FitInventoryKnowledge({
    Map<FitInventoryGroup, FitGroupKnowledge>? groups,
    List<UnresolvedOccupant>? unplacedEntries,
    List<FitOccurrenceKnowledge>? occurrences,
    this.moduleState,
  }) : groups = groups ?? <FitInventoryGroup, FitGroupKnowledge>{},
       unplacedEntries = unplacedEntries ?? <UnresolvedOccupant>[],
       occurrences = occurrences ?? <FitOccurrenceKnowledge>[];

  final Map<FitInventoryGroup, FitGroupKnowledge> groups;
  final List<UnresolvedOccupant> unplacedEntries;
  final List<FitOccurrenceKnowledge> occurrences;
  final StateKnowledge? moduleState;

  factory FitInventoryKnowledge.unknown() => FitInventoryKnowledge();

  factory FitInventoryKnowledge.recordedComplete({
    SlotPositionMeaning positions = SlotPositionMeaning.recorded,
    StateKnowledge moduleState = StateKnowledge.recorded,
  }) {
    return FitInventoryKnowledge(
      groups: {
        for (final group in FitInventoryGroup.values)
          group: FitGroupKnowledge(
            completeness: InventoryCompleteness.recordedComplete,
            applicability: GroupApplicability.applicable,
            positions: positions,
          ),
      },
      moduleState: moduleState,
    );
  }

  FitGroupKnowledge group(FitInventoryGroup group) {
    return groups[group] ?? const FitGroupKnowledge();
  }
}

class AarFitSnapshot {
  AarFitSnapshot({
    this.schemaVersion = 1,
    required this.snapshotId,
    required this.encounterId,
    required this.fitting,
    required this.source,
    required this.subject,
    this.sourceRef,
    this.confidence,
    this.recordedAt,
    this.evidenceAt,
    FitInventoryKnowledge? knowledge,
    this.sourceItemIds = const [],
    this.limitations = const [],
  }) : knowledge = knowledge ?? FitInventoryKnowledge.unknown();

  final int schemaVersion;
  final String snapshotId;
  final String encounterId;
  final Fitting fitting;
  final AarFitSource source;
  final AarFitSubject subject;
  final AarFitSourceRef? sourceRef;
  final EvidenceConfidence? confidence;
  final DateTime? recordedAt;
  final DateTime? evidenceAt;
  final FitInventoryKnowledge knowledge;
  final List<int> sourceItemIds;
  final List<String> limitations;

  /// Naive: hashes the raw JSON envelope, including identity/name/time.
  String get contentFingerprint {
    final bytes = utf8.encode(jsonEncode(toJson()));
    return sha256.convert(bytes).toString();
  }

  /// Naive: not distinguished from [contentFingerprint].
  String get calculationFingerprint => contentFingerprint;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'snapshotId': snapshotId,
    'encounterId': encounterId,
    'fitting': fitting.toJson(),
    'source': source.name,
    'subject': {
      'characterId': subject.characterId,
      'identityKnown': subject.identityKnown,
      'relation': subject.relation.name,
    },
    if (sourceRef != null)
      'sourceRef': {
        'killmailId': sourceRef!.killmailId,
        'victimCharacterId': sourceRef!.victimCharacterId,
        'savedFittingId': sourceRef!.savedFittingId,
        'attachmentId': sourceRef!.attachmentId,
        'reportId': sourceRef!.reportId,
      },
    if (confidence != null) 'confidence': confidence!.name,
    if (recordedAt != null) 'recordedAt': recordedAt!.toUtc().toIso8601String(),
    if (evidenceAt != null) 'evidenceAt': evidenceAt!.toUtc().toIso8601String(),
    'limitations': limitations,
  };

  factory AarFitSnapshot.fromJson(Map<String, dynamic> json) {
    final fittingJson = json['fitting'];
    final fitting = fittingJson is Map
        ? Fitting.fromJson(Map<String, dynamic>.from(fittingJson))
        : const Fitting(id: '', name: '', shipTypeId: 0, shipName: '');
    return AarFitSnapshot(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      snapshotId: json['snapshotId']?.toString() ?? '',
      encounterId: json['encounterId']?.toString() ?? '',
      fitting: fitting,
      source: AarFitSource.values.firstWhere(
        (value) => value.name == json['source']?.toString(),
        orElse: () => AarFitSource.evidenceAttachment,
      ),
      subject: AarFitSubject(
        characterId: json['subject'] is Map
            ? json['subject']['characterId'] as int?
            : null,
        identityKnown: json['subject'] is Map
            ? json['subject']['identityKnown'] != false
            : true,
        relation: AarFitSubjectRelation.values.firstWhere(
          (value) =>
              value.name ==
              (json['subject'] is Map
                  ? json['subject']['relation']?.toString()
                  : null),
          orElse: () => AarFitSubjectRelation.pilot,
        ),
      ),
      recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? ''),
      evidenceAt: DateTime.tryParse(json['evidenceAt']?.toString() ?? ''),
      knowledge: FitInventoryKnowledge.recordedComplete(),
    );
  }

  static AarFitSnapshot fromCurrentCapture({
    required String encounterId,
    required Fitting fitting,
    required int characterId,
    DateTime? recordedAt,
    List<int> sourceItemIds = const [],
  }) {
    return AarFitSnapshot(
      snapshotId: 'cap-$encounterId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.comparisonCapture,
      subject: AarFitSubject(
        characterId: characterId,
        relation: AarFitSubjectRelation.pilot,
      ),
      recordedAt: recordedAt,
      sourceItemIds: sourceItemIds,
      knowledge: FitInventoryKnowledge.unknown(),
    );
  }

  static AarFitSnapshot fromFitEvidence({
    required String encounterId,
    required FitEvidence evidence,
    FitInventoryKnowledge? knowledge,
  }) {
    return AarFitSnapshot(
      snapshotId: 'ev-$encounterId-${evidence.source.name}',
      encounterId: encounterId,
      fitting: evidence.fitting,
      source: AarFitSource.evidenceAttachment,
      subject: AarFitSubject(
        relation: switch (evidence.role) {
          FitEvidenceRole.victim => AarFitSubjectRelation.victim,
          FitEvidenceRole.reference => AarFitSubjectRelation.reference,
          _ => AarFitSubjectRelation.pilot,
        },
      ),
      confidence: evidence.confidence,
      evidenceAt: evidence.evidenceTime,
      knowledge: knowledge ?? FitInventoryKnowledge.recordedComplete(),
    );
  }

  static AarFitSnapshot fromEftImport({
    required String encounterId,
    required Fitting fitting,
    DateTime? recordedAt,
  }) {
    return AarFitSnapshot(
      snapshotId: 'eft-$encounterId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.importedProposal,
      subject: const AarFitSubject(relation: AarFitSubjectRelation.reference),
      recordedAt: recordedAt,
      knowledge: FitInventoryKnowledge.recordedComplete(
        positions: SlotPositionMeaning.recorded,
      ),
    );
  }

  static AarFitSnapshot fromSavedFitting({
    required String encounterId,
    required Fitting fitting,
    required String savedFittingId,
  }) {
    return AarFitSnapshot(
      snapshotId: 'saved-$savedFittingId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.savedReference,
      subject: const AarFitSubject(relation: AarFitSubjectRelation.reference),
      sourceRef: AarFitSourceRef(savedFittingId: savedFittingId),
      knowledge: FitInventoryKnowledge.recordedComplete(),
    );
  }

  static AarFitSnapshot fromKillmailVictim({
    required String encounterId,
    required Fitting fitting,
    required int killmailId,
    int? victimCharacterId,
    bool itemsKeyPresent = true,
  }) {
    return AarFitSnapshot(
      snapshotId: 'km-$killmailId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.killmailVictim,
      subject: AarFitSubject(
        characterId: victimCharacterId,
        identityKnown: victimCharacterId != null,
        relation: AarFitSubjectRelation.victim,
      ),
      sourceRef: AarFitSourceRef(
        killmailId: killmailId,
        victimCharacterId: victimCharacterId,
      ),
      knowledge: FitInventoryKnowledge.recordedComplete(),
    );
  }

  static AarFitSnapshot fromStructuredCandidate({
    required String encounterId,
    required Fitting fitting,
    required Map<String, dynamic> raw,
  }) {
    return AarFitSnapshot(
      snapshotId: 'cand-$encounterId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.aiProposal,
      subject: const AarFitSubject(relation: AarFitSubjectRelation.reference),
      knowledge: FitInventoryKnowledge.recordedComplete(),
    );
  }
}

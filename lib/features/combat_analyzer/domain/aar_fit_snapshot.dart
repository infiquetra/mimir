import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../fitting/domain/models.dart';
import 'combat_evidence_ledger.dart';

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

  Map<String, dynamic> toJson() => {
    'characterId': characterId,
    'identityKnown': identityKnown,
    'relation': relation.name,
  };

  factory AarFitSubject.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AarFitSubject(relation: AarFitSubjectRelation.pilot);
    }
    return AarFitSubject(
      characterId: json['characterId'] as int?,
      identityKnown: json['identityKnown'] != false,
      relation: _enumFromName(
        AarFitSubjectRelation.values,
        json['relation']?.toString(),
        AarFitSubjectRelation.pilot,
      ),
    );
  }
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

  Map<String, dynamic> toJson() => {
    if (killmailId != null) 'killmailId': killmailId,
    if (victimCharacterId != null) 'victimCharacterId': victimCharacterId,
    if (savedFittingId != null) 'savedFittingId': savedFittingId,
    if (attachmentId != null) 'attachmentId': attachmentId,
    if (reportId != null) 'reportId': reportId,
  };

  factory AarFitSourceRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AarFitSourceRef();
    }
    return AarFitSourceRef(
      killmailId: json['killmailId'] as int?,
      victimCharacterId: json['victimCharacterId'] as int?,
      savedFittingId: json['savedFittingId']?.toString(),
      attachmentId: json['attachmentId']?.toString(),
      reportId: json['reportId']?.toString(),
    );
  }
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

  Map<String, dynamic> toJson() => {
    'sourceEntryKey': sourceEntryKey,
    if (typeId != null) 'typeId': typeId,
    if (quantity != null) 'quantity': quantity,
    'quantityUnknown': quantityUnknown,
    if (group != null) 'group': group!.name,
    if (physicalIndex != null) 'physicalIndex': physicalIndex,
    'label': label,
  };

  factory UnresolvedOccupant.fromJson(Map<String, dynamic> json) {
    return UnresolvedOccupant(
      sourceEntryKey: json['sourceEntryKey']?.toString() ?? '',
      typeId: json['typeId'] as int?,
      quantity: json['quantity'] as int?,
      quantityUnknown: json['quantityUnknown'] == true,
      group: json['group'] == null
          ? null
          : _enumFromName(
              FitInventoryGroup.values,
              json['group']?.toString(),
              FitInventoryGroup.cargo,
            ),
      physicalIndex: json['physicalIndex'] as int?,
      label: json['label']?.toString() ?? '',
    );
  }
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

  Map<String, dynamic> toJson() => {
    'occurrenceKey': occurrenceKey,
    'charge': charge.name,
    'state': state.name,
  };

  factory FitOccurrenceKnowledge.fromJson(Map<String, dynamic> json) {
    return FitOccurrenceKnowledge(
      occurrenceKey: json['occurrenceKey']?.toString() ?? '',
      charge: _enumFromName(
        ChargeKnowledge.values,
        json['charge']?.toString(),
        ChargeKnowledge.unknown,
      ),
      state: _enumFromName(
        StateKnowledge.values,
        json['state']?.toString(),
        StateKnowledge.assumed,
      ),
    );
  }
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

  bool get isOrderOnly => positions == SlotPositionMeaning.orderOnly;

  Map<String, dynamic> toJson() => {
    'completeness': completeness.name,
    'applicability': applicability.name,
    'positions': positions.name,
    'recordedEmptySlots': recordedEmptySlots,
    'unresolvedOccupied': [
      for (final occupant in unresolvedOccupied) occupant.toJson(),
    ],
  };

  factory FitGroupKnowledge.fromJson(Map<String, dynamic> json) {
    return FitGroupKnowledge(
      completeness: _enumFromName(
        InventoryCompleteness.values,
        json['completeness']?.toString(),
        InventoryCompleteness.unknown,
      ),
      applicability: _enumFromName(
        GroupApplicability.values,
        json['applicability']?.toString(),
        GroupApplicability.unknown,
      ),
      positions: _enumFromName(
        SlotPositionMeaning.values,
        json['positions']?.toString(),
        SlotPositionMeaning.orderOnly,
      ),
      recordedEmptySlots: [
        for (final value in json['recordedEmptySlots'] as List? ?? const [])
          value as int,
      ],
      unresolvedOccupied: [
        for (final value in json['unresolvedOccupied'] as List? ?? const [])
          if (value is Map)
            UnresolvedOccupant.fromJson(Map<String, dynamic>.from(value)),
      ],
    );
  }
}

class FitInventoryKnowledge {
  FitInventoryKnowledge({
    Map<FitInventoryGroup, FitGroupKnowledge>? groups,
    List<UnresolvedOccupant>? unplacedEntries,
    List<FitOccurrenceKnowledge>? occurrences,
    this.moduleState,
  }) : groups = {
         for (final entry in (groups ?? const {}).entries)
           entry.key: FitGroupKnowledge(
             completeness: entry.value.completeness,
             applicability: entry.value.applicability,
             positions: entry.value.positions,
             recordedEmptySlots: List<int>.from(entry.value.recordedEmptySlots),
             unresolvedOccupied: List<UnresolvedOccupant>.from(
               entry.value.unresolvedOccupied,
             ),
           ),
       },
       unplacedEntries = List<UnresolvedOccupant>.from(
         unplacedEntries ?? const [],
       ),
       occurrences = List<FitOccurrenceKnowledge>.from(occurrences ?? const []);

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

  Map<String, dynamic> toJson() => {
    'groups': {
      for (final entry in groups.entries) entry.key.name: entry.value.toJson(),
    },
    'unplacedEntries': [
      for (final occupant in unplacedEntries) occupant.toJson(),
    ],
    'occurrences': [for (final occurrence in occurrences) occurrence.toJson()],
    if (moduleState != null) 'moduleState': moduleState!.name,
  };

  factory FitInventoryKnowledge.fromJson(Map<String, dynamic>? json) {
    if (json == null) return FitInventoryKnowledge.unknown();
    final groupsJson = json['groups'];
    final groups = <FitInventoryGroup, FitGroupKnowledge>{};
    if (groupsJson is Map) {
      for (final entry in groupsJson.entries) {
        final group = _enumFromName(
          FitInventoryGroup.values,
          entry.key.toString(),
          FitInventoryGroup.cargo,
        );
        if (entry.value is Map) {
          groups[group] = FitGroupKnowledge.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    return FitInventoryKnowledge(
      groups: groups,
      unplacedEntries: [
        for (final value in json['unplacedEntries'] as List? ?? const [])
          if (value is Map)
            UnresolvedOccupant.fromJson(Map<String, dynamic>.from(value)),
      ],
      occurrences: [
        for (final value in json['occurrences'] as List? ?? const [])
          if (value is Map)
            FitOccurrenceKnowledge.fromJson(Map<String, dynamic>.from(value)),
      ],
      moduleState: json['moduleState'] == null
          ? null
          : _enumFromName(
              StateKnowledge.values,
              json['moduleState']?.toString(),
              StateKnowledge.assumed,
            ),
    );
  }
}

class AarFitSnapshot {
  AarFitSnapshot({
    this.schemaVersion = 1,
    required this.snapshotId,
    required this.encounterId,
    required Fitting fitting,
    required this.source,
    required this.subject,
    this.sourceRef,
    this.confidence,
    this.recordedAt,
    this.evidenceAt,
    FitInventoryKnowledge? knowledge,
    List<int> sourceItemIds = const [],
    List<String> limitations = const [],
  }) : fitting = _copyFitting(fitting),
       knowledge = FitInventoryKnowledge(
         groups: (knowledge ?? FitInventoryKnowledge.unknown()).groups,
         unplacedEntries:
             (knowledge ?? FitInventoryKnowledge.unknown()).unplacedEntries,
         occurrences:
             (knowledge ?? FitInventoryKnowledge.unknown()).occurrences,
         moduleState:
             (knowledge ?? FitInventoryKnowledge.unknown()).moduleState,
       ),
       sourceItemIds = List<int>.from(sourceItemIds),
       limitations = List<String>.from(limitations);

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

  String get contentFingerprint => _fingerprint(includeSubject: true);

  String get calculationFingerprint => _fingerprint(includeSubject: false);

  String _fingerprint({required bool includeSubject}) {
    final payload = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'shipTypeId': fitting.shipTypeId,
      if (includeSubject) 'subject': subject.toJson(),
      'items': _canonicalItems(),
      'knowledge': _canonicalKnowledge(),
    };
    final bytes = utf8.encode(jsonEncode(_canonicalize(payload)));
    return sha256.convert(bytes).toString();
  }

  List<Map<String, dynamic>> _canonicalItems() {
    final items = <Map<String, dynamic>>[
      ..._canonicalModules(FitInventoryGroup.high, fitting.highSlots),
      ..._canonicalModules(FitInventoryGroup.mid, fitting.medSlots),
      ..._canonicalModules(FitInventoryGroup.low, fitting.lowSlots),
      ..._canonicalModules(FitInventoryGroup.rigs, fitting.rigSlots),
      ..._canonicalModules(FitInventoryGroup.subsystems, fitting.subsystems),
      for (final drone in fitting.drones)
        {
          'group': FitInventoryGroup.drones.name,
          'typeId': drone.typeId,
          'quantity': drone.quantity,
          'inBay': drone.inBay,
          'inSpace': drone.inSpace,
        },
      for (final fighter in fitting.fighters)
        {
          'group': FitInventoryGroup.fighters.name,
          'typeId': fighter.typeId,
          'quantity': fighter.quantity,
          'inSpace': fighter.inSpace,
        },
      for (final cargo in fitting.cargo)
        {
          'group': FitInventoryGroup.cargo.name,
          'typeId': cargo.typeId,
          'quantity': cargo.quantity,
        },
    ];
    items.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return items;
  }

  List<Map<String, dynamic>> _canonicalModules(
    FitInventoryGroup group,
    List<FittedModule> modules,
  ) {
    final recorded =
        knowledge.group(group).positions == SlotPositionMeaning.recorded;
    return [
      for (final module in modules)
        {
          'group': group.name,
          'typeId': module.typeId,
          'state': module.state.name,
          'chargeTypeId': module.chargeTypeId,
          'quantity': 1,
          if (recorded) 'slotIndex': module.slotIndex,
        },
    ];
  }

  Map<String, dynamic> _canonicalKnowledge() {
    final groups = <String, dynamic>{};
    for (final group in FitInventoryGroup.values) {
      final info = knowledge.group(group);
      final unresolved = [
        for (final occupant in info.unresolvedOccupied) occupant.toJson(),
      ]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
      final empties = [...info.recordedEmptySlots]..sort();
      groups[group.name] = {
        'completeness': info.completeness.name,
        'applicability': info.applicability.name,
        'positions': info.positions.name,
        'recordedEmptySlots': empties,
        'unresolvedOccupied': unresolved,
      };
    }
    final unplaced = [
      for (final occupant in knowledge.unplacedEntries) occupant.toJson(),
    ]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    final occurrences = [
      for (final occurrence in knowledge.occurrences) occurrence.toJson(),
    ]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return {
      'groups': groups,
      'unplacedEntries': unplaced,
      'occurrences': occurrences,
      'moduleState': knowledge.moduleState?.name,
    };
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'snapshotId': snapshotId,
    'encounterId': encounterId,
    'fitting': fitting.toJson(),
    'source': source.name,
    'subject': subject.toJson(),
    if (sourceRef != null) 'sourceRef': sourceRef!.toJson(),
    if (confidence != null) 'confidence': confidence!.name,
    if (recordedAt != null) 'recordedAt': recordedAt!.toUtc().toIso8601String(),
    if (evidenceAt != null) 'evidenceAt': evidenceAt!.toUtc().toIso8601String(),
    'knowledge': knowledge.toJson(),
    'sourceItemIds': sourceItemIds,
    'limitations': limitations,
  };

  factory AarFitSnapshot.fromJson(Map<String, dynamic> json) {
    return AarFitSnapshot(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      snapshotId: json['snapshotId']?.toString() ?? '',
      encounterId: json['encounterId']?.toString() ?? '',
      fitting: _fittingFromJson(json['fitting']),
      source: _enumFromName(
        AarFitSource.values,
        json['source']?.toString(),
        AarFitSource.evidenceAttachment,
      ),
      subject: AarFitSubject.fromJson(
        json['subject'] is Map
            ? Map<String, dynamic>.from(json['subject'] as Map)
            : null,
      ),
      sourceRef: json['sourceRef'] is Map
          ? AarFitSourceRef.fromJson(
              Map<String, dynamic>.from(json['sourceRef'] as Map),
            )
          : null,
      confidence: json['confidence'] == null
          ? null
          : _enumFromName(
              EvidenceConfidence.values,
              json['confidence']?.toString(),
              EvidenceConfidence.unknown,
            ),
      recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? ''),
      evidenceAt: DateTime.tryParse(json['evidenceAt']?.toString() ?? ''),
      knowledge: json['knowledge'] is Map
          ? FitInventoryKnowledge.fromJson(
              Map<String, dynamic>.from(json['knowledge'] as Map),
            )
          : FitInventoryKnowledge.unknown(),
      sourceItemIds: [
        for (final value in json['sourceItemIds'] as List? ?? const [])
          value as int,
      ],
      limitations: [
        for (final value in json['limitations'] as List? ?? const [])
          value.toString(),
      ],
    );
  }

  static AarFitSnapshot fromCurrentCapture({
    required String encounterId,
    required Fitting fitting,
    required int characterId,
    DateTime? recordedAt,
    List<int> sourceItemIds = const [],
    String? snapshotId,
    FitInventoryKnowledge? knowledge,
    List<String> limitations = const [],
  }) {
    final emptyInventory =
        fitting.allModules.isEmpty &&
        fitting.drones.isEmpty &&
        fitting.fighters.isEmpty &&
        fitting.cargo.isEmpty;
    return AarFitSnapshot(
      snapshotId: snapshotId ?? 'cap-$encounterId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.comparisonCapture,
      subject: AarFitSubject(
        characterId: characterId,
        relation: AarFitSubjectRelation.pilot,
      ),
      recordedAt: recordedAt,
      sourceItemIds: sourceItemIds,
      knowledge:
          knowledge ??
          (emptyInventory
              ? FitInventoryKnowledge(
                  groups: {
                    for (final group in FitInventoryGroup.values)
                      group: FitGroupKnowledge(
                        completeness: InventoryCompleteness.unknown,
                        applicability: GroupApplicability.applicable,
                        positions: SlotPositionMeaning.recorded,
                      ),
                  },
                  moduleState: StateKnowledge.assumed,
                )
              : FitInventoryKnowledge.recordedComplete(
                  positions: SlotPositionMeaning.recorded,
                  moduleState: StateKnowledge.assumed,
                )),
      limitations: limitations,
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
      knowledge: knowledge ?? FitInventoryKnowledge.unknown(),
      limitations: evidence.limitations,
    );
  }

  static AarFitSnapshot fromEftImport({
    required String encounterId,
    required Fitting fitting,
    DateTime? recordedAt,
    String? snapshotId,
    FitInventoryKnowledge? knowledge,
  }) {
    return AarFitSnapshot(
      snapshotId: snapshotId ?? 'eft-$encounterId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.importedProposal,
      subject: const AarFitSubject(relation: AarFitSubjectRelation.reference),
      recordedAt: recordedAt,
      knowledge: knowledge ?? knowledgeForEftImport(fitting),
    );
  }

  static FitInventoryKnowledge knowledgeForEftImport(Fitting fitting) {
    return FitInventoryKnowledge(
      groups: {
        for (final group in FitInventoryGroup.values)
          if (_groupHasItems(fitting, group))
            group: FitGroupKnowledge(
              completeness: InventoryCompleteness.recordedComplete,
              applicability: GroupApplicability.applicable,
              positions: SlotPositionMeaning.orderOnly,
            ),
      },
      moduleState: StateKnowledge.assumed,
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
      knowledge: FitInventoryKnowledge.unknown(),
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
      knowledge: itemsKeyPresent
          ? FitInventoryKnowledge(
              groups: {
                for (final group in FitInventoryGroup.values)
                  if (_groupHasItems(fitting, group))
                    group: FitGroupKnowledge(
                      completeness: InventoryCompleteness.partial,
                      applicability: GroupApplicability.applicable,
                      positions: SlotPositionMeaning.recorded,
                    ),
              },
            )
          : FitInventoryKnowledge.unknown(),
    );
  }

  static AarFitSnapshot fromStructuredCandidate({
    required String encounterId,
    required Fitting fitting,
    required Map<String, dynamic> raw,
    EvidenceConfidence? confidence,
  }) {
    return AarFitSnapshot(
      snapshotId: 'cand-$encounterId',
      encounterId: encounterId,
      fitting: fitting,
      source: AarFitSource.aiProposal,
      subject: const AarFitSubject(relation: AarFitSubjectRelation.reference),
      confidence: confidence,
      knowledge: knowledgeFromCandidateRaw(raw),
    );
  }

  static FitInventoryKnowledge knowledgeFromCandidateRaw(
    Map<String, dynamic> raw,
  ) {
    final target = raw['target'];
    final groupsRaw = target is Map ? target['groups'] : null;
    if (groupsRaw is! Map) return FitInventoryKnowledge.unknown();
    final groups = <FitInventoryGroup, FitGroupKnowledge>{};
    for (final entry in groupsRaw.entries) {
      final group = _enumFromName(
        FitInventoryGroup.values,
        entry.key.toString(),
        FitInventoryGroup.cargo,
      );
      if (!_isKnownGroupName(entry.key.toString())) continue;
      final body = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : const <String, dynamic>{};
      final status = body['status']?.toString();
      groups[group] = FitGroupKnowledge(
        completeness: switch (status) {
          'complete' => InventoryCompleteness.recordedComplete,
          'partial' => InventoryCompleteness.partial,
          _ => InventoryCompleteness.unknown,
        },
        applicability: GroupApplicability.applicable,
        positions: SlotPositionMeaning.orderOnly,
      );
    }
    return FitInventoryKnowledge(groups: groups);
  }
}

Fitting _copyFitting(Fitting fitting) {
  return Fitting(
    id: fitting.id,
    name: fitting.name,
    description: fitting.description,
    shipTypeId: fitting.shipTypeId,
    shipName: fitting.shipName,
    highSlots: List<FittedModule>.from(fitting.highSlots),
    medSlots: List<FittedModule>.from(fitting.medSlots),
    lowSlots: List<FittedModule>.from(fitting.lowSlots),
    rigSlots: List<FittedModule>.from(fitting.rigSlots),
    subsystems: List<FittedModule>.from(fitting.subsystems),
    drones: List<DroneGroup>.from(fitting.drones),
    fighters: List<FighterGroup>.from(fitting.fighters),
    cargo: List<CargoItem>.from(fitting.cargo),
  );
}

Fitting _fittingFromJson(Object? json) {
  if (json is! Map) {
    return const Fitting(id: '', name: '', shipTypeId: 0, shipName: '');
  }
  final map = Map<String, dynamic>.from(json);
  map.putIfAbsent('id', () => '');
  map.putIfAbsent('name', () => '');
  map.putIfAbsent('shipTypeId', () => 0);
  map.putIfAbsent('shipName', () => '');
  return Fitting.fromJson(map);
}

bool _groupHasItems(Fitting fitting, FitInventoryGroup group) {
  return switch (group) {
    FitInventoryGroup.high => fitting.highSlots.isNotEmpty,
    FitInventoryGroup.mid => fitting.medSlots.isNotEmpty,
    FitInventoryGroup.low => fitting.lowSlots.isNotEmpty,
    FitInventoryGroup.rigs => fitting.rigSlots.isNotEmpty,
    FitInventoryGroup.subsystems => fitting.subsystems.isNotEmpty,
    FitInventoryGroup.drones => fitting.drones.isNotEmpty,
    FitInventoryGroup.fighters => fitting.fighters.isNotEmpty,
    FitInventoryGroup.cargo => fitting.cargo.isNotEmpty,
  };
}

bool _isKnownGroupName(String name) {
  for (final group in FitInventoryGroup.values) {
    if (group.name == name) return true;
  }
  return false;
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalize(value[key])};
  }
  if (value is List) {
    return [for (final item in value) _canonicalize(item)];
  }
  return value;
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

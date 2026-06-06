import '../../../core/network/esi_client.dart';
import '../../fitting/domain/models.dart';
import 'combat_evidence_ledger.dart';

enum CombatEnrichmentStatus { killmailMatched, ambiguous, logOnly, needsReauth }

enum CombatEnrichmentSource { none, esiRecent, zkillEsi, cache }

class CombatEnrichment {
  const CombatEnrichment({
    required this.parsedEncounterId,
    required this.status,
    required this.source,
    this.killmailId,
    this.killmailHash,
    this.killmailTime,
    this.solarSystemId,
    this.victimCharacterId,
    this.victimName,
    this.victimShipTypeId,
    this.finalBlowCharacterId,
    this.finalBlowName,
    this.finalBlowShipTypeId,
    this.totalValue,
    this.destroyedFit,
    this.pilotFitEvidence,
    this.victimFitEvidence,
    this.evidenceLedger = const CombatEvidenceLedger(),
    this.matchConfidence = 0,
    this.matchReason = '',
    this.limitations = const [],
    this.rawKillmail,
  });

  final String parsedEncounterId;
  final CombatEnrichmentStatus status;
  final CombatEnrichmentSource source;
  final int? killmailId;
  final String? killmailHash;
  final DateTime? killmailTime;
  final int? solarSystemId;
  final int? victimCharacterId;
  final String? victimName;
  final int? victimShipTypeId;
  final int? finalBlowCharacterId;
  final String? finalBlowName;
  final int? finalBlowShipTypeId;
  final double? totalValue;
  final Fitting? destroyedFit;
  final FitEvidence? pilotFitEvidence;
  final FitEvidence? victimFitEvidence;
  final CombatEvidenceLedger evidenceLedger;
  final double matchConfidence;
  final String matchReason;
  final List<String> limitations;
  final Map<String, dynamic>? rawKillmail;

  bool get hasMatchedKillmail =>
      status == CombatEnrichmentStatus.killmailMatched;

  String get badgeLabel {
    return switch (status) {
      CombatEnrichmentStatus.killmailMatched => 'Killmail matched',
      CombatEnrichmentStatus.ambiguous => 'Ambiguous evidence',
      CombatEnrichmentStatus.logOnly => 'Log-only',
      CombatEnrichmentStatus.needsReauth => 'Needs reauth',
    };
  }

  String get sourceLabel {
    return switch (source) {
      CombatEnrichmentSource.esiRecent => 'ESI recent killmails',
      CombatEnrichmentSource.zkillEsi => 'zKill discovery + ESI detail',
      CombatEnrichmentSource.cache => 'Cached evidence',
      CombatEnrichmentSource.none => 'Combat log only',
    };
  }

  Map<String, dynamic> toJson() => {
    'parsedEncounterId': parsedEncounterId,
    'status': status.name,
    'source': source.name,
    if (killmailId != null) 'killmailId': killmailId,
    if (killmailHash != null) 'killmailHash': killmailHash,
    if (killmailTime != null)
      'killmailTime': killmailTime!.toUtc().toIso8601String(),
    if (solarSystemId != null) 'solarSystemId': solarSystemId,
    if (victimCharacterId != null) 'victimCharacterId': victimCharacterId,
    if (victimName != null) 'victimName': victimName,
    if (victimShipTypeId != null) 'victimShipTypeId': victimShipTypeId,
    if (finalBlowCharacterId != null)
      'finalBlowCharacterId': finalBlowCharacterId,
    if (finalBlowName != null) 'finalBlowName': finalBlowName,
    if (finalBlowShipTypeId != null) 'finalBlowShipTypeId': finalBlowShipTypeId,
    if (totalValue != null) 'totalValue': totalValue,
    if (destroyedFit != null) 'destroyedFit': destroyedFit!.toJson(),
    if (pilotFitEvidence != null)
      'pilotFitEvidence': pilotFitEvidence!.toJson(),
    if (victimFitEvidence != null)
      'victimFitEvidence': victimFitEvidence!.toJson(),
    if (!evidenceLedger.isEmpty) 'evidenceLedger': evidenceLedger.toJson(),
    'matchConfidence': matchConfidence,
    'matchReason': matchReason,
    'limitations': limitations,
    if (rawKillmail != null) 'rawKillmail': rawKillmail,
  };

  Map<String, dynamic> toPromptJson() => {
    'status': status.name,
    'source': sourceLabel,
    'matchConfidence': matchConfidence,
    'matchReason': matchReason,
    if (killmailId != null) 'killmailId': killmailId,
    if (killmailTime != null)
      'killmailTime': killmailTime!.toUtc().toIso8601String(),
    if (victimCharacterId != null) 'victimCharacterId': victimCharacterId,
    if (victimName != null) 'victimName': victimName,
    if (victimShipTypeId != null) 'victimShipTypeId': victimShipTypeId,
    if (finalBlowCharacterId != null)
      'finalBlowCharacterId': finalBlowCharacterId,
    if (finalBlowName != null) 'finalBlowName': finalBlowName,
    if (finalBlowShipTypeId != null) 'finalBlowShipTypeId': finalBlowShipTypeId,
    if (destroyedFit != null)
      'destroyedVictimFit': {
        'shipTypeId': destroyedFit!.shipTypeId,
        'highSlots': _modulesForPrompt(destroyedFit!.highSlots),
        'medSlots': _modulesForPrompt(destroyedFit!.medSlots),
        'lowSlots': _modulesForPrompt(destroyedFit!.lowSlots),
        'rigSlots': _modulesForPrompt(destroyedFit!.rigSlots),
        'subsystems': _modulesForPrompt(destroyedFit!.subsystems),
        'drones': destroyedFit!.drones.map((drone) => drone.toJson()).toList(),
        'cargo': destroyedFit!.cargo.map((item) => item.toJson()).toList(),
      },
    if (pilotFitEvidence != null)
      'pilotFitEvidence': pilotFitEvidence!.toPromptJson(),
    if (victimFitEvidence != null)
      'victimFitEvidence': victimFitEvidence!.toPromptJson(),
    if (!evidenceLedger.isEmpty) 'evidenceLedger': evidenceLedger.toJson(),
    'limitations': limitations,
  };

  factory CombatEnrichment.fromJson(Map<String, dynamic> json) {
    return CombatEnrichment(
      parsedEncounterId: json['parsedEncounterId']?.toString() ?? '',
      status: _enumFromName(
        CombatEnrichmentStatus.values,
        json['status']?.toString(),
        CombatEnrichmentStatus.logOnly,
      ),
      source: _enumFromName(
        CombatEnrichmentSource.values,
        json['source']?.toString(),
        CombatEnrichmentSource.none,
      ),
      killmailId: _nullableInt(json['killmailId']),
      killmailHash: _nullableString(json['killmailHash']),
      killmailTime: DateTime.tryParse(json['killmailTime']?.toString() ?? ''),
      solarSystemId: _nullableInt(json['solarSystemId']),
      victimCharacterId: _nullableInt(json['victimCharacterId']),
      victimName: _nullableString(json['victimName']),
      victimShipTypeId: _nullableInt(json['victimShipTypeId']),
      finalBlowCharacterId: _nullableInt(json['finalBlowCharacterId']),
      finalBlowName: _nullableString(json['finalBlowName']),
      finalBlowShipTypeId: _nullableInt(json['finalBlowShipTypeId']),
      totalValue: _nullableDouble(json['totalValue']),
      destroyedFit: json['destroyedFit'] is Map
          ? Fitting.fromJson(
              Map<String, dynamic>.from(json['destroyedFit'] as Map),
            )
          : null,
      pilotFitEvidence: json['pilotFitEvidence'] is Map
          ? FitEvidence.fromJson(
              Map<String, dynamic>.from(json['pilotFitEvidence'] as Map),
            )
          : null,
      victimFitEvidence: json['victimFitEvidence'] is Map
          ? FitEvidence.fromJson(
              Map<String, dynamic>.from(json['victimFitEvidence'] as Map),
            )
          : null,
      evidenceLedger: json['evidenceLedger'] is Map
          ? CombatEvidenceLedger.fromJson(
              Map<String, dynamic>.from(json['evidenceLedger'] as Map),
            )
          : const CombatEvidenceLedger(),
      matchConfidence: _doubleFromJson(json['matchConfidence']),
      matchReason: json['matchReason']?.toString() ?? '',
      limitations: _stringList(json['limitations']),
      rawKillmail: json['rawKillmail'] is Map
          ? Map<String, dynamic>.from(json['rawKillmail'] as Map)
          : null,
    );
  }

  factory CombatEnrichment.fromKillmail({
    required String parsedEncounterId,
    required CombatEnrichmentSource source,
    required EsiKillmailDetail detail,
    required double confidence,
    required String reason,
    required Fitting destroyedFit,
    double? totalValue,
    List<String> limitations = const [],
  }) {
    final finalBlow = detail.attackers.where((attacker) => attacker.finalBlow);
    final blow = finalBlow.isEmpty ? null : finalBlow.first;
    final victimFitEvidence = FitEvidence(
      role: FitEvidenceRole.victim,
      source: EvidenceSource.killmail,
      confidence: EvidenceConfidence.proven,
      fitting: destroyedFit,
      evidenceTime: detail.killmailTime,
      limitations: const [
        'Killmail proves destroyed and dropped victim items only.',
      ],
    );
    return CombatEnrichment(
      parsedEncounterId: parsedEncounterId,
      status: CombatEnrichmentStatus.killmailMatched,
      source: source,
      killmailId: detail.killmailId,
      killmailHash: detail.killmailHash,
      killmailTime: detail.killmailTime,
      solarSystemId: detail.solarSystemId,
      victimCharacterId: detail.victim.characterId,
      victimName: detail.victim.characterName,
      victimShipTypeId: detail.victim.shipTypeId,
      finalBlowCharacterId: blow?.characterId,
      finalBlowName: blow?.characterName,
      finalBlowShipTypeId: blow?.shipTypeId,
      totalValue: totalValue,
      destroyedFit: destroyedFit,
      victimFitEvidence: victimFitEvidence,
      evidenceLedger: CombatEvidenceLedger(
        facts: [
          CombatEvidenceFact(
            id: 'ev-killmail-${detail.killmailId}',
            label: 'Matched killmail',
            value: '${detail.killmailId}',
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            evidenceTime: detail.killmailTime,
          ),
          CombatEvidenceFact(
            id: 'ev-victim-ship-${detail.killmailId}',
            label: 'Destroyed victim ship',
            value: '${detail.victim.shipTypeId}',
            source: EvidenceSource.killmail,
            confidence: EvidenceConfidence.proven,
            evidenceTime: detail.killmailTime,
          ),
          if (blow != null)
            CombatEvidenceFact(
              id: 'ev-final-blow-${detail.killmailId}',
              label: 'Final blow',
              value: blow.characterName ?? '${blow.characterId}',
              source: EvidenceSource.killmail,
              confidence: EvidenceConfidence.proven,
              evidenceTime: detail.killmailTime,
            ),
        ],
        unknowns: const [
          AarUnknown(
            category: AarUnknownCategory.opponentFit,
            label: 'Attacker fits',
            detail: 'Killmails do not expose full attacker fittings.',
          ),
        ],
      ),
      matchConfidence: confidence,
      matchReason: reason,
      limitations: limitations,
      rawKillmail: detail.toJson(),
    );
  }

  CombatEnrichment copyWith({
    CombatEnrichmentStatus? status,
    CombatEnrichmentSource? source,
    int? killmailId,
    String? killmailHash,
    DateTime? killmailTime,
    int? solarSystemId,
    int? victimCharacterId,
    String? victimName,
    int? victimShipTypeId,
    int? finalBlowCharacterId,
    String? finalBlowName,
    int? finalBlowShipTypeId,
    double? totalValue,
    Fitting? destroyedFit,
    FitEvidence? pilotFitEvidence,
    FitEvidence? victimFitEvidence,
    CombatEvidenceLedger? evidenceLedger,
    double? matchConfidence,
    String? matchReason,
    List<String>? limitations,
    Map<String, dynamic>? rawKillmail,
  }) {
    return CombatEnrichment(
      parsedEncounterId: parsedEncounterId,
      status: status ?? this.status,
      source: source ?? this.source,
      killmailId: killmailId ?? this.killmailId,
      killmailHash: killmailHash ?? this.killmailHash,
      killmailTime: killmailTime ?? this.killmailTime,
      solarSystemId: solarSystemId ?? this.solarSystemId,
      victimCharacterId: victimCharacterId ?? this.victimCharacterId,
      victimName: victimName ?? this.victimName,
      victimShipTypeId: victimShipTypeId ?? this.victimShipTypeId,
      finalBlowCharacterId: finalBlowCharacterId ?? this.finalBlowCharacterId,
      finalBlowName: finalBlowName ?? this.finalBlowName,
      finalBlowShipTypeId: finalBlowShipTypeId ?? this.finalBlowShipTypeId,
      totalValue: totalValue ?? this.totalValue,
      destroyedFit: destroyedFit ?? this.destroyedFit,
      pilotFitEvidence: pilotFitEvidence ?? this.pilotFitEvidence,
      victimFitEvidence: victimFitEvidence ?? this.victimFitEvidence,
      evidenceLedger: evidenceLedger ?? this.evidenceLedger,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      matchReason: matchReason ?? this.matchReason,
      limitations: limitations ?? this.limitations,
      rawKillmail: rawKillmail ?? this.rawKillmail,
    );
  }
}

List<Map<String, dynamic>> _modulesForPrompt(List<FittedModule> modules) {
  return modules
      .map(
        (module) => {
          'typeId': module.typeId,
          'slotIndex': module.slotIndex,
          if (module.chargeTypeId != null) 'chargeTypeId': module.chargeTypeId,
        },
      )
      .toList();
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

String? _nullableString(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return text;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

double _doubleFromJson(Object? value) => _nullableDouble(value) ?? 0;

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

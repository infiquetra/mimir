import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_damage_profile.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

const kS1IncomingResolved = [
  'Weapon 1',
  'Weapon 2',
  'Weapon 3',
  'Weapon 4',
  'Weapon 5',
  'Weapon 6',
  'Weapon 7',
  'Weapon 8',
  'Weapon 9',
];

const kS1OutgoingResolved = ['Outgoing 1', 'Outgoing 2', 'Outgoing 3'];

const kS1UnknownWeapons = ['Unknown', 'Civilian Gatling Railgun'];

final _derivedAt = DateTime.utc(2026, 9, 11, 12);

const _stats = FittingStats(
  cpuMax: 156.25,
  capacitorCapacity: 250,
  capacitorRecharge: 125000,
  capacitorStable: 41,
  isCapStable: true,
  dpsTotal: 312.4,
  dpsGuns: 210,
  dpsDrones: 102.4,
  volley: 890,
  maxVelocity: 1234,
  signatureRadius: 42,
  alignTime: 4.7,
  defenses: DefenseProfile(
    shieldHp: 1550,
    armorHp: 450,
    hullHp: 350,
    shieldEhp: 2137,
    armorEhp: 667,
    hullEhp: 522,
    totalEhp: 12345,
    effectiveArmorRepair: 84.3,
    peakShieldRecharge: 6.3,
    shieldResists: ResistProfile(
      em: 0,
      thermal: 20,
      kinetic: 40,
      explosive: 50,
    ),
  ),
);

const _tank = TankAssessment(
  layer: TankLayer.armor,
  mode: TankMode.active,
  shieldBoostHps: 0,
  armorRepairHps: 84.3,
  hullRepairHps: 0,
  shieldGainEhp: 3586,
  armorGainEhp: 0,
  hullGainEhp: 0,
  reasoning: 'Armor (active): 84.3 HP/s armor repair vs 0.0 shield boost.',
);

/// Parser-built encounter. Lines follow CombatLogParser._damageRegex.
ParsedCombatEncounter encounterWith({
  int incomingEvents = 12,
  int outgoingEvents = 12,
  int amount = 100,
  int? characterId = 42,
  String weapon = 'Railgun',
  int spacingSeconds = 4,
}) {
  final lines = <String>['Listener: Pilot'];
  var time = DateTime.utc(2026, 5, 20, 20);
  void addEvent(String direction) {
    lines.add(
      '[ ${_eveStamp(time)} ] (combat) $amount $direction Enemy - $weapon - Hits',
    );
    time = time.add(Duration(seconds: spacingSeconds));
  }

  for (var i = 0; i < incomingEvents; i++) {
    addEvent('from');
  }
  for (var i = 0; i < outgoingEvents; i++) {
    addEvent('to');
  }
  final parsed = CombatLogParser.parseLines(lines).single;
  if (characterId == null) return parsed;
  return parsed.copyWith(characterId: characterId);
}

CombatDamageProfile profile({
  required int profiled,
  List<String> resolved = const ['Railgun'],
  List<String> unknown = const [],
  CombatDamageConfidence confidence = CombatDamageConfidence.sdeExact,
}) {
  return CombatDamageProfile(
    entries: profiled > 0
        ? [
            CombatDamageTypeEstimate(
              type: 'kinetic',
              amount: profiled,
              percent: 1,
              confidence: confidence,
              source: resolved.isEmpty ? 'kinetic' : resolved.first,
              evidence: 'fixture',
            ),
          ]
        : const [],
    unknownWeapons: unknown,
    totalProfiledDamage: profiled,
    resolvedWeapons: resolved,
  );
}

FitEvidence fitEvidence({
  FitEvidenceRole role = FitEvidenceRole.pilot,
  EvidenceSource source = EvidenceSource.currentShipSnapshot,
  EvidenceConfidence confidence = EvidenceConfidence.confirmed,
  int shipTypeId = 587,
  DateTime? evidenceTime,
}) {
  return FitEvidence(
    role: role,
    source: source,
    confidence: confidence,
    fitting: Fitting(
      id: 'fit-$shipTypeId',
      name: 'Rifter',
      shipTypeId: shipTypeId,
      shipName: 'Rifter',
    ),
    evidenceTime: evidenceTime,
  );
}

AarFitDerivation derivation({
  AarFitSubject subject = AarFitSubject.self,
  EvidenceSource fitSource = EvidenceSource.currentShipSnapshot,
  AarSkillBasis basis = AarSkillBasis.knownCharacter,
  List<int> unresolvedTypeIds = const [],
}) {
  final skills = AarSkillContext(
    basis: basis,
    skills: const [],
    characterId: basis == AarSkillBasis.knownCharacter ? 42 : null,
  );
  return AarFitDerivation(
    role: subject == AarFitSubject.self
        ? FitEvidenceRole.pilot
        : FitEvidenceRole.opponent,
    subject: subject,
    fitSource: fitSource,
    shipTypeId: 587,
    shipName: 'Rifter',
    skills: skills,
    stats: _stats,
    baseline: const FittingStats(),
    tank: _tank,
    coverage: AarFitCoverage(
      highFitted: 3,
      highSlots: 3,
      medFitted: 3,
      medSlots: 3,
      lowFitted: 3,
      lowSlots: 3,
      rigFitted: 3,
      rigSlots: 3,
      subsystemFitted: 0,
      subsystemSlots: 0,
      unresolvedTypeIds: unresolvedTypeIds,
      unresolvedNames: const [],
    ),
    derivedAt: _derivedAt,
    limitations: [skills.label, 'Module states assumed active'],
  );
}

CombatEnrichment enrichment({
  CombatEnrichmentStatus status = CombatEnrichmentStatus.killmailMatched,
  double matchConfidence = 0.92,
  int? killmailId = 1234567,
  int? victimCharacterId = 777,
  String? victimName = 'Target Pilot',
  FitEvidence? pilotFitEvidence,
  FitEvidence? victimFitEvidence,
  bool killmailSearchCompleted = true,
  String matchReason = 'ESI recent killmail within the encounter window.',
  String parsedEncounterId = 'enc-1',
  CombatEnrichmentSource source = CombatEnrichmentSource.esiRecent,
}) {
  return CombatEnrichment(
    parsedEncounterId: parsedEncounterId,
    status: status,
    source: source,
    killmailId: killmailId,
    victimCharacterId: victimCharacterId,
    victimName: victimName,
    matchConfidence: matchConfidence,
    matchReason: matchReason,
    killmailSearchCompleted: killmailSearchCompleted,
    pilotFitEvidence: pilotFitEvidence,
    victimFitEvidence: victimFitEvidence,
  );
}

AarEvidenceInputs aarInputs({
  ParsedCombatEncounter? encounter,
  CombatEnrichment? enrichmentRow,
  bool hasEnrichment = true,
  AarDerivationBundle? bundle,
  CombatDamageProfile? incoming,
  CombatDamageProfile? outgoing,
}) {
  return AarEvidenceInputs(
    encounter: encounter ?? encounterWith(),
    enrichment: hasEnrichment ? (enrichmentRow ?? enrichment()) : null,
    bundle: bundle ?? const AarDerivationBundle.empty(),
    incoming: incoming ?? profile(profiled: 1200),
    outgoing: outgoing ?? profile(profiled: 1200),
  );
}

/// §2.5: kill, no pilot fit, opponent from killmail, 24 damage events, D5 partial.
AarEvidenceInputs s1Inputs({ParsedCombatEncounter? encounter}) {
  final enc = encounter ?? encounterWith();
  return AarEvidenceInputs(
    encounter: enc,
    enrichment: enrichment(
      parsedEncounterId: enc.id,
      victimFitEvidence: fitEvidence(
        role: FitEvidenceRole.victim,
        source: EvidenceSource.killmail,
        confidence: EvidenceConfidence.proven,
      ),
    ),
    bundle: AarDerivationBundle(
      opponent: derivation(
        subject: AarFitSubject.opponent,
        fitSource: EvidenceSource.killmail,
      ),
    ),
    incoming: profile(
      profiled: 900,
      resolved: kS1IncomingResolved,
      unknown: kS1UnknownWeapons,
    ),
    outgoing: profile(profiled: 1200, resolved: kS1OutgoingResolved),
  );
}

/// §2.7: own loss.
AarEvidenceInputs s1bInputs({
  AarSkillBasis basis = AarSkillBasis.knownCharacter,
}) {
  final enc = encounterWith();
  return AarEvidenceInputs(
    encounter: enc,
    enrichment: enrichment(
      parsedEncounterId: enc.id,
      matchConfidence: 0.9,
      killmailId: 2000,
      victimCharacterId: 42,
      victimName: 'Pilot',
      victimFitEvidence: fitEvidence(
        role: FitEvidenceRole.victim,
        source: EvidenceSource.killmail,
        confidence: EvidenceConfidence.proven,
      ),
    ),
    bundle: AarDerivationBundle(
      self: derivation(fitSource: EvidenceSource.killmail, basis: basis),
    ),
    incoming: profile(
      profiled: 900,
      resolved: kS1IncomingResolved,
      unknown: kS1UnknownWeapons,
    ),
    outgoing: profile(profiled: 1200, resolved: kS1OutgoingResolved),
  );
}

/// §2.6: searched, no killmail, optional confirmed fit, profile complete.
AarEvidenceInputs s6Inputs({bool withPilotFit = true}) {
  final enc = encounterWith();
  final fit = withPilotFit ? fitEvidence() : null;
  return AarEvidenceInputs(
    encounter: enc,
    enrichment: enrichment(
      parsedEncounterId: enc.id,
      status: CombatEnrichmentStatus.logOnly,
      source: CombatEnrichmentSource.none,
      matchConfidence: 0,
      killmailId: null,
      victimCharacterId: null,
      victimName: null,
      killmailSearchCompleted: true,
      matchReason: 'No ESI or zKill killmail matched this encounter.',
      pilotFitEvidence: fit,
    ),
    bundle: AarDerivationBundle(self: withPilotFit ? derivation() : null),
    incoming: profile(profiled: 1200, resolved: const ['Railgun']),
    outgoing: profile(profiled: 1200, resolved: const ['Hobgoblin II']),
  );
}

/// Every dimension Complete.
AarEvidenceInputs s7Inputs() {
  final enc = encounterWith();
  return AarEvidenceInputs(
    encounter: enc,
    enrichment: enrichment(
      parsedEncounterId: enc.id,
      pilotFitEvidence: fitEvidence(),
      victimFitEvidence: fitEvidence(
        role: FitEvidenceRole.victim,
        source: EvidenceSource.killmail,
        confidence: EvidenceConfidence.proven,
      ),
    ),
    bundle: AarDerivationBundle(
      self: derivation(),
      opponent: derivation(
        subject: AarFitSubject.opponent,
        fitSource: EvidenceSource.manualFitImport,
      ),
    ),
    incoming: profile(profiled: 1200, resolved: const ['Railgun']),
    outgoing: profile(profiled: 1200, resolved: const ['Hobgoblin II']),
  );
}

AarEvidenceDimensionResult row(
  AarEvidenceDimension d,
  AarEvidenceStatus s, {
  List<AarEvidenceAction>? actions,
}) {
  return AarEvidenceDimensionResult(
    dimension: d,
    status: s,
    detail: '${d.name} ${s.name}',
    actions: actions ?? _canonicalMissingActions(d, s),
  );
}

List<AarEvidenceDimensionResult> rows({
  required AarEvidenceStatus d1,
  required AarEvidenceStatus d2,
  required AarEvidenceStatus d3,
  required AarEvidenceStatus d4,
  required AarEvidenceStatus d5,
}) {
  return [
    row(AarEvidenceDimension.pilotFit, d1),
    row(AarEvidenceDimension.combatLog, d2),
    row(AarEvidenceDimension.opponentIdentity, d3),
    row(AarEvidenceDimension.opponentFit, d4),
    row(AarEvidenceDimension.damageProfile, d5),
  ];
}

List<AarEvidenceAction> _canonicalMissingActions(
  AarEvidenceDimension d,
  AarEvidenceStatus s,
) {
  if (s != AarEvidenceStatus.missing) return const [];
  return switch (d) {
    AarEvidenceDimension.pilotFit => const [
      AarEvidenceAction.useCurrentFit,
      AarEvidenceAction.importFit,
    ],
    AarEvidenceDimension.opponentIdentity || AarEvidenceDimension.opponentFit =>
      const [AarEvidenceAction.searchKillmails],
    _ => const [],
  };
}

String _eveStamp(DateTime t) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${t.year}.${pad(t.month)}.${pad(t.day)} ${pad(t.hour)}:${pad(t.minute)}:${pad(t.second)}';
}

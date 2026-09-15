import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_attacker_matchup.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_fit_derivation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_actor_classifier.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlation.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_attacker_correlator.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_enrichment.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_evidence_ledger.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import 'attacker_correlation_fixtures.dart';

const matchupSdeContentKey = 'sde-decimal-v1-test';
const kitePulseName = 'Kite Pulse';
const artemAutocannonName = 'Artem Autocannon';
const omniBeamName = 'Omni Beam';
const pureEmName = 'Pure EM Pulse';
const thermalDroneName = 'Thermal Drone';
const kineticChargeName = 'Kinetic Charge';
const explosiveChargeName = 'Explosive Charge';
const thirdsMixName = 'Thirds Mix';
const decimalMixName = 'Decimal Mix';

/// Fixture A shield defense: 1,000 HP, 0 armor/hull, resists 0/20/60/20%.
const fixtureADefense = DefenseProfile(
  shieldHp: 1000,
  armorHp: 0,
  hullHp: 0,
  shieldResists: ResistProfile(em: 0, thermal: 20, kinetic: 60, explosive: 20),
);

const fixtureATank = TankAssessment(
  layer: TankLayer.shield,
  mode: TankMode.buffer,
  shieldBoostHps: 0,
  armorRepairHps: 0,
  hullRepairHps: 0,
  shieldGainEhp: 0,
  armorGainEhp: 0,
  hullGainEhp: 0,
  reasoning: 'Fixture A explicit Shield tank.',
);

IncomingDamageVector sdeVector({
  required num em,
  required num thermal,
  required num kinetic,
  required num explosive,
}) {
  return IncomingDamageVector(
    em: DamageQuantity.fromSdeNumber(em),
    thermal: DamageQuantity.fromSdeNumber(thermal),
    kinetic: DamageQuantity.fromSdeNumber(kinetic),
    explosive: DamageQuantity.fromSdeNumber(explosive),
  );
}

IncomingWeaponResolution resolvedWeapon(
  String name, {
  required IncomingDamageVector attributes,
  int typeId = 91001,
}) {
  return IncomingWeaponResolution(
    normalizedName: normalizeCombatName(name),
    typeId: typeId,
    typeName: name,
    status: WeaponResolutionStatus.resolved,
    attributes: attributes,
  );
}

IncomingWeaponResolution unresolvedWeapon(
  String name, {
  WeaponResolutionStatus status = WeaponResolutionStatus.missingName,
  String? reasonCode,
}) {
  return IncomingWeaponResolution(
    normalizedName: normalizeCombatName(name),
    status: status,
    reasonCode: reasonCode ?? status.name,
  );
}

final kitePulseResolution = resolvedWeapon(
  kitePulseName,
  attributes: sdeVector(em: 75, thermal: 0, kinetic: 25, explosive: 0),
  typeId: 91011,
);
final artemAutocannonResolution = resolvedWeapon(
  artemAutocannonName,
  attributes: sdeVector(em: 0, thermal: 0, kinetic: 25, explosive: 75),
  typeId: 91012,
);
final omniBeamResolution = resolvedWeapon(
  omniBeamName,
  attributes: sdeVector(em: 1, thermal: 1, kinetic: 1, explosive: 1),
  typeId: 91013,
);
final pureEmResolution = resolvedWeapon(
  pureEmName,
  attributes: sdeVector(em: 1, thermal: 0, kinetic: 0, explosive: 0),
  typeId: 91014,
);
final thermalDroneResolution = resolvedWeapon(
  thermalDroneName,
  attributes: sdeVector(em: 0, thermal: 1, kinetic: 0, explosive: 0),
  typeId: 91015,
);
final kineticChargeResolution = resolvedWeapon(
  kineticChargeName,
  attributes: sdeVector(em: 0, thermal: 0, kinetic: 1, explosive: 0),
  typeId: 91016,
);
final explosiveChargeResolution = resolvedWeapon(
  explosiveChargeName,
  attributes: sdeVector(em: 0, thermal: 0, kinetic: 0, explosive: 1),
  typeId: 91017,
);
final thirdsMixResolution = resolvedWeapon(
  thirdsMixName,
  attributes: sdeVector(em: 1, thermal: 1, kinetic: 1, explosive: 0),
  typeId: 91018,
);
final decimalMixResolution = resolvedWeapon(
  decimalMixName,
  attributes: sdeVector(em: 0.1, thermal: 0.2, kinetic: 0, explosive: 0),
  typeId: 91019,
);

Map<String, IncomingWeaponResolution> matchupWeaponTable([
  Map<String, IncomingWeaponResolution> extra = const {},
]) {
  return {
    kitePulseResolution.normalizedName: kitePulseResolution,
    artemAutocannonResolution.normalizedName: artemAutocannonResolution,
    omniBeamResolution.normalizedName: omniBeamResolution,
    pureEmResolution.normalizedName: pureEmResolution,
    thermalDroneResolution.normalizedName: thermalDroneResolution,
    kineticChargeResolution.normalizedName: kineticChargeResolution,
    explosiveChargeResolution.normalizedName: explosiveChargeResolution,
    thirdsMixResolution.normalizedName: thirdsMixResolution,
    decimalMixResolution.normalizedName: decimalMixResolution,
    ...extra,
  };
}

AarFitDerivation fixtureAPilotFit({
  AarSkillBasis basis = AarSkillBasis.knownCharacter,
  DefenseProfile? defense,
  TankAssessment? tank,
}) {
  final skills = AarSkillContext(
    basis: basis,
    skills: const [],
    characterId: basis == AarSkillBasis.knownCharacter ? 42 : null,
  );
  return AarFitDerivation(
    role: FitEvidenceRole.pilot,
    subject: AarFitSubject.self,
    fitSource: EvidenceSource.currentShipSnapshot,
    shipTypeId: 587,
    shipName: 'Rifter',
    skills: skills,
    stats: FittingStats(defenses: defense ?? fixtureADefense),
    baseline: const FittingStats(),
    tank: tank ?? fixtureATank,
    coverage: const AarFitCoverage(
      highFitted: 3,
      highSlots: 4,
      medFitted: 3,
      medSlots: 3,
      lowFitted: 3,
      lowSlots: 3,
      rigFitted: 0,
      rigSlots: 3,
      subsystemFitted: 0,
      subsystemSlots: 0,
      unresolvedTypeIds: [],
      unresolvedNames: [],
    ),
    derivedAt: DateTime.utc(2026, 9, 14, 12),
    limitations: [skills.label],
  );
}

FitEvidence fixtureAPilotFitEvidence() {
  return FitEvidence(
    role: FitEvidenceRole.pilot,
    source: EvidenceSource.currentShipSnapshot,
    confidence: EvidenceConfidence.confirmed,
    fitting: const Fitting(
      id: 'fit-587',
      name: 'Rifter',
      shipTypeId: 587,
      shipName: 'Rifter',
    ),
    evidenceTime: DateTime.utc(2026, 9, 14, 12),
  );
}

ParsedCombatEncounter matchupEncounter(
  List<(String actor, int amount, String weapon, int second)> hits, {
  List<String> extraLines = const [],
  int? characterId = 42,
  String listener = 'Pilot',
}) {
  final lines = <String>['Listener: $listener'];
  for (final hit in hits) {
    final second = hit.$4.toString().padLeft(2, '0');
    lines.add(
      '[ 2026.05.20 20:00:$second ] (combat) ${hit.$2} from ${hit.$1} - ${hit.$3} - Hits',
    );
  }
  lines.addAll(extraLines);
  final parsed = CombatLogParser.parseLines(lines).single;
  if (characterId == null) return parsed;
  return parsed.copyWith(characterId: characterId);
}

const fixtureAExcludedLines = [
  '[ 2026.05.20 20:00:40 ] (combat) 999 to Enemy - Railgun - Hits',
  '[ 2026.05.20 20:00:41 ] (combat) Your Railgun misses Enemy completely.',
  '[ 2026.05.20 20:00:42 ] (combat) 0 from Kite Mondeo - Kite Pulse - Hits',
  '[ 2026.05.20 20:00:43 ] (combat) Warp scramble from Kite Mondeo',
  '[ 2026.05.20 20:00:44 ] (combat) Repairing 50 to Pilot',
];

/// S1 solo Confirmed source, 4,000 incoming, one resolved weapon.
({
  ParsedCombatEncounter encounter,
  EsiKillmailDetail detail,
  AttackerCorrelation correlation,
  CombatEnrichment enrichment,
})
s1Solo({bool partialUnknownWeapon = false}) {
  final hits = <(String, int, String, int)>[
    if (partialUnknownWeapon) ...[
      ('Artem S3', 3000, artemAutocannonName, 4),
      ('Artem S3', 1000, 'Missing Weapon', 8),
    ] else
      ('Artem S3', 4000, artemAutocannonName, 4),
  ];
  final encounter = matchupEncounter(hits);
  final km = detail(
    victim: victim(damageTaken: 4000),
    attackers: [
      attacker(
        characterId: 9001,
        characterName: 'Artem S3',
        shipTypeId: 24702,
        damageDone: 4000,
        finalBlow: true,
      ),
    ],
  );
  return (
    encounter: encounter,
    detail: km,
    correlation: correlate((encounter: encounter, detail: km)),
    enrichment: _owningEnrichment(encounter, km),
  );
}

/// S2 / Fixture A: Kite 6,000 @ 75/0/25/0 and Artem 4,000 @ 0/0/25/75.
({
  ParsedCombatEncounter encounter,
  EsiKillmailDetail detail,
  AttackerCorrelation correlation,
  CombatEnrichment enrichment,
})
s2Fleet({bool withExcludedEvents = false}) {
  final encounter = matchupEncounter([
    ('Kite Mondeo', 6000, kitePulseName, 4),
    ('Artem S3', 4000, artemAutocannonName, 8),
  ], extraLines: withExcludedEvents ? fixtureAExcludedLines : const []);
  final km = detail(
    victim: victim(damageTaken: 10000),
    attackers: [
      attacker(
        characterId: 9002,
        characterName: 'Kite Mondeo',
        shipTypeId: 34828,
        weaponTypeId: 2412,
        damageDone: 6000,
        finalBlow: true,
      ),
      attacker(
        characterId: 9001,
        characterName: 'Artem S3',
        shipTypeId: 24702,
        weaponTypeId: 2410,
        damageDone: 4000,
      ),
    ],
  );
  return (
    encounter: encounter,
    detail: km,
    correlation: correlate((encounter: encounter, detail: km)),
    enrichment: _owningEnrichment(encounter, km),
  );
}

/// S3 / Fixture B residuals: C 400, Possible 200, unnamed 100, NPC 300.
({
  ParsedCombatEncounter encounter,
  EsiKillmailDetail detail,
  AttackerCorrelation correlation,
  CombatEnrichment enrichment,
})
s3Residuals() {
  final encounter = matchupEncounter([
    ('Alpha', 300, pureEmName, 4),
    ('Alpha', 100, 'Missing Weapon', 6),
    ('Bravo', 200, kineticChargeName, 8),
    ('Unknown', 100, 'Missing Weapon', 10),
    ('Serpentis Watchman', 200, explosiveChargeName, 12),
    ('Serpentis Watchman', 100, 'Missing Weapon', 14),
  ]);
  final km = detail(
    victim: victim(damageTaken: 1000),
    attackers: [
      attacker(
        characterId: 1,
        characterName: 'Alpha',
        shipTypeId: 587,
        damageDone: 400,
        finalBlow: true,
      ),
      attacker(
        characterId: 2,
        characterName: 'Bravo',
        shipTypeId: 587,
        damageDone: 200,
      ),
      attacker(shipTypeId: 30001, damageDone: 300, factionId: 500020),
    ],
  );
  final correlation = AttackerCorrelation(
    killmailId: km.killmailId,
    selfIsVictim: true,
    correlated: [
      CorrelatedAttacker(
        actor: actor('Alpha', damage: 400, weapons: [pureEmName]),
        participant: participant(
          key: 'a0',
          characterId: 1,
          name: 'Alpha',
          shipTypeId: 587,
          damageDone: 400,
          finalBlow: true,
        ),
        confidence: AttackerCorrelationConfidence.confirmed,
        score: 0.95,
        signals: const [CorrelationSignal.name],
      ),
      CorrelatedAttacker(
        actor: actor('Bravo', damage: 200, weapons: [kineticChargeName]),
        participant: participant(
          key: 'a1',
          characterId: 2,
          name: 'Bravo',
          shipTypeId: 587,
          damageDone: 200,
        ),
        confidence: AttackerCorrelationConfidence.possible,
        score: 0.30,
        signals: const [CorrelationSignal.name],
      ),
    ],
    unattributedActors: [
      actor('Unknown', cls: CombatActorClass.unnamed, damage: 100),
      actor(
        'Serpentis Watchman',
        cls: CombatActorClass.npc,
        damage: 300,
        typeId: 30001,
      ),
    ],
    uncorrelatedParticipants: const [],
    correlatedIncomingDamage: 600,
    unattributedIncomingDamage: 100,
    npcIncomingDamage: 300,
    totalIncomingDamage: 1000,
    reasons: const {
      'actor:unknown': UncorrelatedReason.unnamed,
      'actor:serpentis watchman': UncorrelatedReason.npcActor,
    },
    correlatedAt: now,
  );
  return (
    encounter: encounter,
    detail: km,
    correlation: correlation,
    enrichment: _owningEnrichment(encounter, km, correlation: correlation),
  );
}

/// S4 victory: opposing victim return fire vs the user's pilot fit.
({
  ParsedCombatEncounter encounter,
  EsiKillmailDetail detail,
  AttackerCorrelation correlation,
  CombatEnrichment enrichment,
})
s4Victory() {
  final encounter = matchupEncounter([('Vex Kalari', 4000, kitePulseName, 4)]);
  final km = detail(
    victim: victim(
      characterId: 9000,
      characterName: 'Vex Kalari',
      shipTypeId: 587,
      damageTaken: 8000,
    ),
    attackers: [
      attacker(
        characterId: 42,
        characterName: 'Pilot',
        shipTypeId: 587,
        damageDone: 8000,
        finalBlow: true,
      ),
    ],
  );
  return (
    encounter: encounter,
    detail: km,
    correlation: correlate((encounter: encounter, detail: km)),
    enrichment: _owningEnrichment(encounter, km),
  );
}

/// S5 / Fixture D mixed weapons: 600 EM + 400 Thermal, optional extra drone actor.
({
  ParsedCombatEncounter encounter,
  EsiKillmailDetail detail,
  AttackerCorrelation correlation,
  CombatEnrichment enrichment,
})
s5MixedWeapons({bool rearrangeHits = false, bool extraDroneActor = false}) {
  final hits = rearrangeHits
      ? <(String, int, String, int)>[
          ('Artem S3', 200, pureEmName, 4),
          ('Artem S3', 200, thermalDroneName, 6),
          ('Artem S3', 400, pureEmName, 8),
          ('Artem S3', 200, thermalDroneName, 10),
        ]
      : <(String, int, String, int)>[
          ('Artem S3', 600, pureEmName, 4),
          ('Artem S3', 400, thermalDroneName, 8),
        ];
  if (extraDroneActor) {
    hits.add(('Hobgoblin II', 150, thermalDroneName, 12));
  }
  final encounter = matchupEncounter(hits);
  final km = detail(
    victim: victim(damageTaken: extraDroneActor ? 1150 : 1000),
    attackers: [
      attacker(
        characterId: 9001,
        characterName: 'Artem S3',
        shipTypeId: 24702,
        damageDone: 1000,
        finalBlow: true,
      ),
    ],
  );
  return (
    encounter: encounter,
    detail: km,
    correlation: correlate((encounter: encounter, detail: km)),
    enrichment: _owningEnrichment(encounter, km),
  );
}

/// Fixture C: 1 vs 3 omni events, plus optional extra fractional actors.
({
  ParsedCombatEncounter encounter,
  EsiKillmailDetail detail,
  AttackerCorrelation correlation,
  CombatEnrichment enrichment,
})
fixtureC({int oneDamage = 1, int threeDamage = 3}) {
  final encounter = matchupEncounter([
    ('Omni One', oneDamage, omniBeamName, 4),
    ('Omni Three', threeDamage, omniBeamName, 8),
  ]);
  final km = detail(
    victim: victim(damageTaken: oneDamage + threeDamage),
    attackers: [
      attacker(
        characterId: 11,
        characterName: 'Omni One',
        shipTypeId: 587,
        damageDone: oneDamage,
        finalBlow: true,
      ),
      attacker(
        characterId: 12,
        characterName: 'Omni Three',
        shipTypeId: 587,
        damageDone: threeDamage,
      ),
    ],
  );
  return (
    encounter: encounter,
    detail: km,
    correlation: correlate((encounter: encounter, detail: km)),
    enrichment: _owningEnrichment(encounter, km),
  );
}

IncomingCorrelationContext matchupCorrelationContext({
  required ParsedCombatEncounter encounter,
  required EsiKillmailDetail detail,
  AttackerCorrelation? correlation,
  Map<String, CombatTypeRef>? localActorTypes,
}) {
  final bound =
      correlation ?? correlate((encounter: encounter, detail: detail));
  return IncomingCorrelationContext(
    parsedEncounterId: encounter.id,
    selectedKillmailId: detail.killmailId,
    selfCharacterId: encounter.characterId,
    selfIsVictim: detail.victim.characterId == encounter.characterId,
    correlation: bound,
    currentParticipants: CombatAttackerCorrelator.participants(
      detail,
      selfCharacterId: encounter.characterId,
      typeIndex: typeIndex(),
    ),
    localActorTypes:
        localActorTypes ?? Map<String, CombatTypeRef>.from(typeIndex().byName),
  );
}

CombatEnrichment _owningEnrichment(
  ParsedCombatEncounter encounter,
  EsiKillmailDetail detail, {
  AttackerCorrelation? correlation,
}) {
  return CombatEnrichment(
    parsedEncounterId: encounter.id,
    status: CombatEnrichmentStatus.killmailMatched,
    source: CombatEnrichmentSource.zkillEsi,
    killmailId: detail.killmailId,
    killmailHash: detail.killmailHash ?? 'hash-matchup',
    victimCharacterId: detail.victim.characterId,
    victimName: detail.victim.characterName,
    rawKillmail: detail.toJson(),
    matchConfidence: 0.9,
    attackerCorrelation: correlation,
  );
}

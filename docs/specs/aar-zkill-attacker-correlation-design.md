# Design: Correlate zKill Attackers with Combat-Log Actors

**Status.** Design for Plan.
**Author.** Arch.
**Date.** 2026-09-11.
**Companion to.** `docs/specs/aar-zkill-attacker-correlation.md` (Product, "the spec").
**Base.** `develop` at 5a70b48 (Milestone 3 shipped and journalled).
**Scope.** The spec's WHAT stands. This document is the HOW: exact data contracts
and JSON, the three-stage pipeline with corrected weights and worked scenarios, the
service seam and provider, the evidence-scorer detail change, the widget anatomy,
verbatim test specifications for Groups A–I, and a TDD unit breakdown for Plan.

---

## 0. Evidence that changes the product spec — read first

The spec's grounding (§0.1–0.3) is right and its principle (unattributed beats
fabricated) is the spine of this design. Reading the code and the bundled data it
binds to shows one blocking gap and a handful of arithmetic and model corrections.

| # | Spec claim | What the code and data say | Resolution |
|---|---|---|---|
| C1 | §2.1 `npc` = "name resolves to an SDE type in an NPC faction/pirate group" | **The bundled SDE contains no NPC types.** `assets/sde/dogma.json` carries categories 6, 7, 8, 16, 18, 20, 22, 32, 87 only (probed). Category **11 (Entity)** — every rat, sentry and NPC ship — is absent, and `scripts/sde/generate_dogma_sde.py` also filters `published == '1'`, which excludes NPC entity types even if 11 were listed. `searchTypesByName('Serpentis Watchman')` returns nothing today. | **U0**: bundle category 11 **names only** (`typeId`, `typeName`, `groupId`; no description, no dogma; `published` ignored for 11) and bump `SdeService.bundledDogmaVersion` 2 → 3 (idempotent reload, precedent in DECISIONS). Estimated +0.3–0.4 MB. Classification reads `group.categoryId == 11` (§2.1). Without U0 every NPC actor defaults to `player` and lands `notOnKillmail` — a safe, honest failure, never a false attribution. |
| C2 | §0.3 "attacker names are already resolved … persisted" | `EsiKillmailAttacker.toJson()` and `EsiKillmailVictim.toJson()` **write** `character_name`, but neither `fromJson` **reads** it. `rawKillmail` round-trips through `EsiKillmailDetail.fromJson` with every name dropped. Product's D3 (re-correlate cached rows on next load) would therefore run without a single name signal. | Read `character_name` in both `fromJson`s (ESI never sends that key, so live parsing is unaffected). One line each. |
| C3 | §2.4 "exactly one **player** attacker" | NPC attackers on ESI killmails have no `character_id`; they carry `faction_id`, which `EsiKillmailAttacker.fromJson` does not parse. | Add `factionId` (additive) and `bool get isPlayer => characterId != null`. |
| C4 | §2.2 weights vs §2.5 thresholds vs R2.2.3/T2.1/T2.3 | S-NAME 0.60 cannot "alone reach `confirmed`" (0.75). S-SHIP 0.25 + S-DMG 0.20 = 0.45 cannot "reach `probable`" (0.50). S1's arithmetic adds S-DMG for a **victim** participant, whose damage *dealt* is not on the killmail. | Weights corrected so every stated outcome holds (§2.2, check table). S-NAME **0.75**, S-SHIP **0.30**, S-WEAP 0.20, S-DMG 0.20, S-TIME 0.15, S-SOLE 0.10. S1 = NAME + SOLE = 0.85. |
| C5 | S1 correlates "the victim actor"; §3.1 `CorrelatedAttacker.attacker: EsiKillmailAttacker` | On a **kill** the log actor shooting the user is the killmail **victim**, not an attacker. The pool must be attackers ∪ victim minus the user. | Own domain type `CombatKillmailParticipant` built from attackers and the victim (`isVictim`, `damageDone` null for the victim). The user's own entry is excluded. |
| C6 | §2.2 S-TIME "attacker has `finalBlow` and the actor dealt the last incoming damage event" | Only meaningful when the **user is the victim** (the last hit the user took is the final blow). On a kill, the user's incoming events are unrelated to the final blow on the victim. | S-TIME fires only when `selfIsVictim`. |
| C7 | R2.6.4 invariant; T1.7 "empty/`Unknown` names are excluded" | The parser writes `incomingBySource['Unknown']` for incoming hits with no source name (`combat_log_parser.dart:345`), and `totalDamageReceived == Σ incomingBySource.values` by construction. Excluding `Unknown` from classification is right; excluding its damage would break the invariant. | `CombatActorClass.unnamed` and `UncorrelatedReason.unnamed`: the actor is listed under `unattributedActors`, its damage in `unattributedIncomingDamage`, never scored. |
| C8 | S4 reason "`noLogPresence`'s inverse" | The enum has no such value; `belowThreshold` would conflate "no signal at all" with "weak signal". | `UncorrelatedReason.notOnKillmail` (best score 0 against every participant). `belowThreshold` = some signal, < 0.30. Also `npcAttacker` for non-player participants, which are listed but never paired. |
| C9 | §2.1 `shipType` = "resolves to a ship type **but the fight has player attackers**" | NPC hulls are category 11, player hulls category 6; the category already separates them. The extra condition adds nothing and makes the class depend on the killmail. | `shipType` = resolves to category 6. Unconditional. |
| C10 | §4.1 "D3 `ambiguous` → `partial`+ when correlation confirms an attacker" | Ambiguous enrichments store **no killmail** (`_enrichmentFromMatch` ambiguous branch: no `rawKillmail`, no victim, no id). Correlation cannot run on them. | Unreachable; dropped. In V1 correlation changes **no** D3/D4 status — detail text only (§4). Invariant I1 (Missing ⇔ action) is untouched because no new actions are introduced. |
| C11 | §7.1 "below the existing matchup section" and R7.3.1 "renders log actors plainly" when null | The Damage tab already ends with a `_BreakdownSection('Incoming Sources')` listing `incomingBySource` — exactly the null-case rendering. Two lists of the same actors would compete. No test pins that title. | The new section **replaces** `Incoming Sources` and sits directly after the matchup widgets (decision D5). Null case renders the same plain rows, no badges. |
| C12 | D3 "correlate on next load … confirm this does not trigger write amplification in `_save()`" | `loadEnrichment(id)` has no encounter (log actors) to correlate against, and `combatEnrichmentProvider` is keyed by id string across the screen and its invalidations. | `ensureAttackerCorrelation(encounter, enrichment)` on the service, called from analysis stage 4 and from a new `combatAttackerCorrelationProvider(encounter)`. Writes once per legacy killmail-matched row; on failure logs and does **not** write (so no retry storm of writes; a retry is one pure pass per screen open). |

Everything else in the spec — R2.1.x, R2.3.x, R2.5.x, R2.6.x, R3.x, R4.x, R5.x,
S1–S6, §7, AC1–AC6, §9 groups, D1/D2/D4, §11 — stands. Test IDs are kept where
they survive; corrected and added cases are marked.

---

## 1. Architecture

### 1.1 Component boundaries

```
scripts/sde/generate_dogma_sde.py   (edit)  NAME_ONLY_CATEGORIES = {11}; assets/sde/dogma.json regenerated
core/sde/sde_service.dart           (edit)  bundledDogmaVersion = 3
core/network/esi_client.dart        (edit)  fromJson reads character_name; attacker factionId + isPlayer

combat_analyzer/domain/                                pure Dart, no I/O, no DateTime.now(), no providers
  combat_attacker_correlation.dart     NEW   enums, AttackerCorrelationRules, CombatLogActor, CombatKillmailParticipant,
                                             CorrelatedAttacker, AttackerCorrelation (+ JSON)
  combat_actor_classifier.dart         NEW   CombatTypeRef, CombatActorTypeIndex, CombatActorClassifier   (Stage 1)
  combat_attacker_correlator.dart      NEW   CombatAttackerCorrelator: score() (Stage 2), assign() (Stage 3), correlate()
  combat_enrichment.dart              (edit) + attackerCorrelation: AttackerCorrelation?  (toJson/fromJson/copyWith/toPromptJson)
  aar_evidence_scorer.dart            (edit) D3 detail suffix when correlated (status unchanged)

combat_analyzer/data/
  combat_enrichment_service.dart      (edit) _enrichmentFromMatch → correlate after _withResolvedNames;
                                             ensureAttackerCorrelation(); ledger facts/unknowns; SDE type index
  combat_analysis_service.dart        (edit) stage 4: ensureAttackerCorrelation on the cached path
  combat_providers.dart               (edit) + combatAttackerCorrelationProvider(encounter)
  codex_analysis_client.dart          (edit) one system-prompt rule sentence (payload additive via toPromptJson)

combat_analyzer/presentation/
  widgets/aar_attacker_correlation_section.dart  NEW  provider shell + pure body + rows
  widgets/aar_matchup_section.dart              (edit) optional correlatedAttackerCount → blend advisory
  analysis_multipane_screen.dart                (edit) Damage tab: section after matchups, replaces 'Incoming Sources'
```

Dependency direction unchanged: presentation → data → domain. The domain files
import `esi_client.dart` only for the `EsiKillmailDetail`/`Attacker`/`Victim`
value types (as `combat_killmail_matcher.dart` already does).

### 1.2 Pipeline

```
ParsedCombatEncounter ──► Stage 1  CombatActorClassifier.classify(encounter, participants, typeIndex)
EsiKillmailDetail     ──►          → List<CombatLogActor>   (player | npc | shipType | ambiguous | unnamed)
CombatActorTypeIndex  ──►
                         Stage 2  CombatAttackerCorrelator.score(actor, participant, context)  per pair
                                  → PairScore { score, signals }     (only player/ambiguous/shipType actors × player participants)
                         Stage 3  CombatAttackerCorrelator.assign(...)
                                  greedy by score, ambiguity margin 0.10, one-to-one, deterministic tie-break
                                  → AttackerCorrelation  with  correlated + unattributed + npc == totalDamageReceived
```

The service builds `CombatActorTypeIndex` (the only I/O: SDE lookups, memoised
per call) and passes it in. Everything after that is pure and runs in Groups A–D
without a Flutter binding (spec D1).

### 1.3 Where it runs (spec D3, R3.2.3)

1. **New enrichments**: inside `_enrichmentFromMatch()` immediately after
   `_withResolvedNames(detail)`, before `CombatEnrichment.fromKillmail(...)` is
   copied with the ledger. Persisted by the existing `_save()`.
2. **Cached rows without correlation** (pre-milestone): `ensureAttackerCorrelation(encounter, enrichment)`
   — no-op unless `attackerCorrelation == null && status == killmailMatched && rawKillmail != null`.
   Called from `analyzeEncounter()` stage 4 (after `enrichEncounter`) and from
   `combatAttackerCorrelationProvider(encounter)` when the AAR screen opens.
3. Never from `loadEnrichment(id)` (C12).

### 1.4 Resolution of the spec's decisions and new ones

| | Decision | Resolution |
|---|---|---|
| D1 | Where does correlation run? | **Pure `domain/`, called from the service** with a pre-resolved `CombatActorTypeIndex` — the `CombatFitDeriver` pattern. |
| D2 | Cache SDE lookups? | **Yes, per call.** `_buildTypeIndex` memoises by normalised name and by type id inside one invocation; no persistent cache. |
| D3 | Re-run on cached enrichments? | **Lazily via `ensureAttackerCorrelation`** (C12). One write per legacy row; failures do not write. |
| D4 | Per-attacker matchup split? | **Not in V1.** `CombatDamageMatchupAnalyzer` untouched; `AarMatchupSection` gains an advisory when ≥ 2 correlate (R4.3.2). Queued. |
| D5 *(new)* | Replace `Incoming Sources`? | **Yes** (C11). The section covers the null case with plain rows. |
| D6 *(new)* | Bundle category 11? | **Yes, names only** (C1). Full dogma for ~6k entity types would add several MB for no consumer. |
| D7 *(new)* | Signal weights | **Corrected** (C4). Constants live in `AttackerCorrelationRules`. |
| D8 *(new)* | Participant pool | **Attackers ∪ victim, minus the user** (C5). NPC participants are listed, never paired. |

---

## 2. The three stages — exact rules

### 2.1 Stage 1 — Actor classification (`CombatActorClassifier`)

Inputs: `encounter` (events + `aggregates.incomingBySource`), `participants`
(§3.2), `typeIndex` (§3.3). Normalisation everywhere is the resolver's:
`trim → collapse whitespace → lowercase` (`_normalizeTypeName`, prior art).

For each key `name` of `incomingBySource` (sorted by damage desc, then name asc):

| # | Condition | Class | `resolvedTypeId` |
|---|---|---|---|
| 1 | `norm(name)` is empty or `'unknown'` | `unnamed` | null |
| 2 | `norm(name)` equals `norm(p.characterName)` of a player participant **and** `typeIndex.byName[norm(name)]` exists | `ambiguous` (scored as `player`) | the type |
| 3 | `norm(name)` equals a player participant's name | `player` | null |
| 4 | `typeIndex.byName[norm(name)].categoryId == 11` | `npc` | the type |
| 5 | `typeIndex.byName[norm(name)].categoryId == 6` | `shipType` | the type |
| 6 | otherwise (unresolvable, or resolves to a non-ship/non-entity category such as a drone) | `player` | null |

Per actor the classifier also collects, from incoming damage events whose
`targetName` normalises to the same key: `weaponNames` (distinct, sorted),
`firstSeen`/`lastSeen` (event timestamps), `damageDealt` (= `incomingBySource[name]`).
Rule 6 is the spec's default; a drone-named actor cannot match by name and lands
`notOnKillmail`, which is the honest outcome (limitation, §10).

### 2.2 Stage 2 — Signals (`CombatAttackerCorrelator.score`)

Pairs are formed only between actors of class `player`, `ambiguous`, `shipType`
and participants with `isPlayer == true`. `npc` and `unnamed` actors and
non-player participants are never scored (R2.1.2 and its inverse).

`AttackerCorrelationRules` (one place, R2.2.1):

| Signal | Weight | Fires when |
|---|---|---|
| `name` | **0.75** | `norm(actor.displayName) == norm(participant.characterName)` (participant name non-null) |
| `ship` | **0.30** | `actor.resolvedTypeId != null && actor.resolvedTypeId == participant.shipTypeId` (only `shipType` actors can satisfy this) |
| `weapon` | 0.20 | any actor weapon `w` in the index with `w.typeId == participant.weaponTypeId` **or** `w.groupId == participant.weaponGroupId` (both non-null) |
| `damage` | 0.20 / 0.10 | `participant.damageDone != null && > 0 && actor.damageDealt > 0`; `r = min/max`; `r >= 0.60` → 0.20; `r >= 0.35` → 0.10; else nothing (never negative, R2.3.3). Victim participants have `damageDone == null` → never fires (C5). |
| `timing` | 0.15 | `context.selfIsVictim && participant.finalBlow && context.lastIncomingActor == norm(actor.displayName)` (C6) |
| `sole` | 0.10 | `context.playerParticipantCount == 1 && context.playerActorCount == 1` (actors of class `player` or `ambiguous`) — R2.4.1 holds because the actor must itself be player-class |

`score = clamp(Σ weights, 0, 1)`; `signals` = the fired list in table order.
Thresholds: `confirmed >= 0.75`, `probable >= 0.50`, `possible >= 0.30`; below → not correlated.
`ambiguityMargin = 0.10`, `damageRatioFull = 0.60`, `damageRatioHalf = 0.35`.
Cap: an actor of class `shipType` never exceeds `probable` (R2.1.3); the raw
`score` is kept, `confidence` is capped.

**Consistency check (every spec outcome, with the corrected weights):**

| Case | Sum | Band | Spec requirement |
|---|---|---|---|
| name alone | 0.75 | confirmed | T2.1, R2.2.3 |
| damage alone | 0.20 | none | T2.2, R2.2.2 |
| ship + damage | 0.50 | probable | T2.3, S2 Sabre |
| ship alone | 0.30 | possible | — |
| ship + weapon + damage + timing (shipType actor) | 0.85 → capped | probable | R2.1.3 |
| weapon + damage + timing + sole (player actor, no name) | 0.65 | probable | — |
| name + sole (S1 victim participant) | 0.85 | confirmed | AC1.1 |
| name + damage + timing (S2 Kite Mondeo) | 1.10 → 1.00 | confirmed | AC1.2 |

### 2.3 Stage 3 — Assignment (`CombatAttackerCorrelator.assign`)

```
pool_actors        = actors with class ∈ {player, ambiguous, shipType}
pool_participants  = participants with isPlayer
pairs              = all (a, p) with score >= 0.30, sorted by
                     score desc, p.damageDone desc (null last), p.characterId asc, a.displayName asc     (R2.5.3)
loop while pairs non-empty:
  P1 = pairs.first
  conflicts = pairs.skip(1).where(q => (q.actor == P1.actor || q.participant == P1.participant)
                                       && P1.score - q.score < ambiguityMargin)
  if conflicts.isEmpty:
      correlated += P1 (confidence from score, capped for shipType)
      remove P1.actor and P1.participant from pools; drop every pair touching either
  else:
      if any conflict shares P1.actor:        reasons['actor:<name>'] = ambiguous; remove P1.actor; drop its pairs
      if any conflict shares P1.participant:  reasons['participant:<key>'] = ambiguous; remove P1.participant; drop its pairs
      (members of the conflicting pairs that were not marked stay in the pools)
after loop:
  remaining pool actors:      bestScore(actor) == 0 → notOnKillmail; else → belowThreshold
                              (bestScore = max score against ANY player participant, computed before assignment,
                               so an actor that lost its only candidate to a stronger pair still reads belowThreshold)
  remaining pool participants: noLogPresence
  npc actors → reasons npcActor;  unnamed actors → unnamed;  non-player participants → npcAttacker
```

Accounting:

```
correlatedIncomingDamage   = Σ correlated[i].actor.damageDealt
npcIncomingDamage          = Σ damage of actors with class npc
unattributedIncomingDamage = Σ damage of every other actor not correlated (player/ambiguous/shipType/unnamed)
invariant: correlated + unattributed + npc == encounter.totalDamageReceived         (R2.6.4, T3.6)
```

The invariant holds by construction because every `incomingBySource` key becomes
exactly one actor and every actor lands in exactly one of the three sums.

### 2.4 Worked scenarios (fixtures in §7.0)

**S1 — solo kill.** Killmail: victim Vex Kalari (7001, Rifter 587), attackers [user 42]. Log: `Vex Kalari` 300 dmg.
Participants after excluding the user: [victim]. Player actors = 1, player participants = 1 → `sole`.
Pair: name 0.75 + sole 0.10 = **0.85 confirmed**, signals `[name, sole]`. Accounting 300 + 0 + 0 = 300.

**S2 — loss, three attackers, one ship-type actor.** Killmail (user is victim): Artem S3 (9001, Hurricane 24702, 4,200), Kite Mondeo (9002, Jackdaw 34828, 3,100, final blow), Dax Rho (9003, Sabre 22456, 1,250), Pell Ivo (9004, Hurricane, 2,000, engaged before the log). Log: `Artem S3` 4,200, `Kite Mondeo` 3,100 (last incoming hit), `Sabre` 1,100.
- Artem: name + damage(ratio 1.0) = 0.95 confirmed.
- Kite: name + damage + timing = 1.00 confirmed.
- `Sabre` (shipType 22456) ↔ Dax Rho: ship 0.30 + damage (1100/1250 = 0.88) 0.20 = **0.50 probable**; ↔ Pell Ivo (Hurricane): 0.
- Pell Ivo → uncorrelated `noLogPresence`. Accounting 8,400 + 0 + 0 = 8,400.

**S3 — fleet.** 12 player attackers, 7 actors: four name matches (confirmed), two ship-type actors with distinct hulls and ratio ≥ 0.6 (probable), one `Sabre` actor facing **two** Sabre attackers with equal signals (ship + damage = 0.50 each) → conflict on the actor within margin → actor `ambiguous`, both attackers remain and end `noLogPresence`. Four attackers never in the log → `noLogPresence` (six uncorrelated including the two Sabres; the spec's "five" does not sum to twelve with one ambiguous actor facing two hulls). Unattributed = the Sabre actor's damage.

**S4 — third party.** Loss; killmail attacker Artem only. Log: `Artem S3` 4,200, `Kite Mondeo` 1,100. Kite scores 0 against Artem → `notOnKillmail`, 1,100 unattributed.

**S5 — NPC and player.** Killmail attackers: Artem (9001, 3,000), NPC (no character, factionId 500020, shipTypeId 30001 "Serpentis Watchman" in the index, 1,400). Log: `Artem S3` 3,000, `Serpentis Watchman` 1,400. Watchman → `npc` (index category 11); Artem: name + damage + sole = 1.05 → **1.00 confirmed** (player participants = 1, player actors = 1). NPC participant → `npcAttacker`. Accounting 3,000 + 0 + 1,400 = 4,400.

**S6 — no killmail.** `attackerCorrelation` stays null; nothing runs.

---

## 3. Domain contracts (`lib/features/combat_analyzer/domain`)

### 3.1 `combat_attacker_correlation.dart`

```dart
enum CombatActorClass { player, npc, shipType, ambiguous, unnamed }              // C7 adds unnamed
enum AttackerCorrelationConfidence { confirmed, probable, possible; String get label; }
enum UncorrelatedReason { belowThreshold, ambiguous, npcActor, noLogPresence, notOnKillmail, npcAttacker, unnamed }
enum CorrelationSignal {
  name, ship, weapon, damage, timing, sole;
  double get weight => AttackerCorrelationRules.weights[this]!;
  String get label;   // 'name match' | 'ship type match' | 'weapon type match' | 'damage proportion' | 'final blow timing' | 'sole participant'
}

abstract final class AttackerCorrelationRules {
  static const Map<CorrelationSignal, double> weights = {
    CorrelationSignal.name: 0.75, CorrelationSignal.ship: 0.30, CorrelationSignal.weapon: 0.20,
    CorrelationSignal.damage: 0.20, CorrelationSignal.timing: 0.15, CorrelationSignal.sole: 0.10,
  };
  static const double damageHalfWeight = 0.10;
  static const double damageRatioFull = 0.60;
  static const double damageRatioHalf = 0.35;
  static const double confirmedThreshold = 0.75;
  static const double probableThreshold = 0.50;
  static const double possibleThreshold = 0.30;
  static const double ambiguityMargin = 0.10;      // mirrors CombatKillmailMatcher.ambiguityMargin
  static const int entityCategoryId = 11;
  static const int shipCategoryId = 6;
  static AttackerCorrelationConfidence? bandFor(double score);
}

class CombatLogActor {
  const CombatLogActor({ required this.displayName, required this.actorClass, required this.damageDealt,
    this.weaponNames = const [], this.firstSeen, this.lastSeen, this.resolvedTypeId, this.resolvedGroupId });
  final String displayName;              // as it appeared in the log
  final CombatActorClass actorClass;
  final int damageDealt;                 // incomingBySource[displayName]
  final List<String> weaponNames;        // distinct, sorted
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final int? resolvedTypeId;
  final int? resolvedGroupId;
  String get key => normalizeCombatName(displayName);
  bool get isScorable => actorClass == CombatActorClass.player || actorClass == CombatActorClass.ambiguous || actorClass == CombatActorClass.shipType;
  Map<String, dynamic> toJson();  factory CombatLogActor.fromJson(Map<String, dynamic>);
}

class CombatKillmailParticipant {
  const CombatKillmailParticipant({ required this.key, this.characterId, this.characterName, this.shipTypeId,
    this.shipTypeName, this.weaponTypeId, this.weaponGroupId, this.damageDone, required this.finalBlow,
    required this.isVictim, this.factionId });
  final String key;                      // 'a<index>' for attackers (killmail order), 'v' for the victim
  final int? characterId;
  final String? characterName;
  final int? shipTypeId;
  final String? shipTypeName;            // from the type index when known (display + NPC pairing), else null
  final int? weaponTypeId;
  final int? weaponGroupId;              // from the type index
  final int? damageDone;                 // attackers: damageDone; victim: null (C5)
  final bool finalBlow;
  final bool isVictim;
  final int? factionId;
  bool get isPlayer => characterId != null;
  factory CombatKillmailParticipant.fromAttacker(EsiKillmailAttacker a, int index, {CombatTypeRef? ship, CombatTypeRef? weapon});
  factory CombatKillmailParticipant.fromVictim(EsiKillmailVictim v, {CombatTypeRef? ship});
  Map<String, dynamic> toJson();  factory CombatKillmailParticipant.fromJson(Map<String, dynamic>);
}

class CorrelatedAttacker {
  const CorrelatedAttacker({ required this.actor, required this.participant, required this.confidence,
    required this.score, required this.signals });
  final CombatLogActor actor;
  final CombatKillmailParticipant participant;
  final AttackerCorrelationConfidence confidence;   // capped for shipType actors
  final double score;                               // raw clamped sum
  final List<CorrelationSignal> signals;            // R3.1.1
  List<String> get signalLabels => signals.map((s) => s.label).toList();
  Map<String, dynamic> toJson();  factory CorrelatedAttacker.fromJson(Map<String, dynamic>);
}

class AttackerCorrelation {
  const AttackerCorrelation({ required this.killmailId, required this.selfIsVictim, required this.correlated,
    required this.unattributedActors, required this.uncorrelatedParticipants, required this.correlatedIncomingDamage,
    required this.unattributedIncomingDamage, required this.npcIncomingDamage, required this.totalIncomingDamage,
    required this.reasons, required this.correlatedAt, this.rulesVersion = 1 });
  final int killmailId;
  final bool selfIsVictim;                                   // drives UI copy (C5, R7.3.3)
  final List<CorrelatedAttacker> correlated;                 // sorted by actor.damageDealt desc
  final List<CombatLogActor> unattributedActors;             // includes npc and unnamed actors
  final List<CombatKillmailParticipant> uncorrelatedParticipants;   // spec's uncorrelatedAttackers; includes NPC participants
  final int correlatedIncomingDamage;
  final int unattributedIncomingDamage;
  final int npcIncomingDamage;
  final int totalIncomingDamage;                             // encounter.totalDamageReceived at correlation time
  final Map<String, UncorrelatedReason> reasons;             // keys 'actor:<key>' | 'participant:<key>'
  final DateTime correlatedAt;                               // passed in by the service (no DateTime.now() in domain)
  final int rulesVersion;

  bool get accountsForAllDamage => correlatedIncomingDamage + unattributedIncomingDamage + npcIncomingDamage == totalIncomingDamage;
  List<CombatKillmailParticipant> get uncorrelatedPlayerParticipants;   // isPlayer
  List<CombatKillmailParticipant> get npcParticipants;                  // !isPlayer
  int get identifiedCount => correlated.length;
  String get summaryLine;   // '3 identified · 1 unattributed' / with ' · 1,400 NPC' when npc > 0

  Map<String, dynamic> toJson();
  static AttackerCorrelation? fromJson(Object? json);   // null when not a Map or killmailId missing; unknown enum names skipped
  Map<String, dynamic> toPromptJson();                  // compact block, §4.4
}

String normalizeCombatName(String value);   // trim, collapse whitespace, lowercase — same as the resolver
```

JSON shape (`toJson`, all keys stable, enum `.name` strings, timestamps UTC ISO-8601):

```json
{
  "killmailId": 1234567, "selfIsVictim": true, "rulesVersion": 1,
  "correlated": [{
    "actor": {"displayName": "Artem S3", "actorClass": "player", "damageDealt": 4200,
              "weaponNames": ["Heavy Missile"], "firstSeen": "2026-05-20T20:00:04.000Z", "lastSeen": "…"},
    "participant": {"key": "a0", "characterId": 9001, "characterName": "Artem S3", "shipTypeId": 24702,
                    "shipTypeName": "Hurricane", "weaponTypeId": 2410, "weaponGroupId": 385,
                    "damageDone": 4200, "finalBlow": false, "isVictim": false},
    "confidence": "confirmed", "score": 0.95, "signals": ["name", "damage"]
  }],
  "unattributedActors": [ … CombatLogActor … ],
  "uncorrelatedParticipants": [ … CombatKillmailParticipant … ],
  "correlatedIncomingDamage": 8400, "unattributedIncomingDamage": 0, "npcIncomingDamage": 0, "totalIncomingDamage": 8400,
  "reasons": {"participant:a3": "noLogPresence"},
  "correlatedAt": "2026-09-11T12:00:00.000Z"
}
```

### 3.2 `combat_actor_classifier.dart`

```dart
class CombatTypeRef {
  const CombatTypeRef({required this.typeId, required this.typeName, required this.groupId, required this.categoryId});
  final int typeId; final String typeName; final int groupId; final int categoryId;
}

class CombatActorTypeIndex {
  const CombatActorTypeIndex({this.byName = const {}, this.byId = const {}});
  final Map<String, CombatTypeRef> byName;   // normalised type name → ref (actor names, weapon names)
  final Map<int, CombatTypeRef> byId;        // type id → ref (participant ship and weapon ids)
  static const empty = CombatActorTypeIndex();
}

class CombatActorClassifier {
  static List<CombatLogActor> classify({
    required ParsedCombatEncounter encounter,
    required List<CombatKillmailParticipant> participants,
    required CombatActorTypeIndex typeIndex,
  });   // §2.1; returns actors sorted by damageDealt desc, displayName asc
}
```

### 3.3 `combat_attacker_correlator.dart`

```dart
class CorrelationContext {
  const CorrelationContext({required this.selfIsVictim, required this.lastIncomingActor,
    required this.playerActorCount, required this.playerParticipantCount});
  final bool selfIsVictim;
  final String? lastIncomingActor;      // normalised name of the actor on the last incoming damage event (by timestamp, then event order)
  final int playerActorCount;           // actors of class player or ambiguous
  final int playerParticipantCount;     // participants with isPlayer
}

class PairScore {
  const PairScore({required this.actor, required this.participant, required this.score, required this.signals});
  final CombatLogActor actor; final CombatKillmailParticipant participant; final double score; final List<CorrelationSignal> signals;
  AttackerCorrelationConfidence? get band;         // uncapped
  AttackerCorrelationConfidence? get cappedBand;   // probable ceiling for shipType actors
}

class CombatAttackerCorrelator {
  const CombatAttackerCorrelator();

  /// Logs `[COMBAT.CORRELATE] ℹ️` with every scored pair and the final buckets (R5.5).
  AttackerCorrelation correlate({
    required ParsedCombatEncounter encounter,
    required EsiKillmailDetail detail,
    required CombatActorTypeIndex typeIndex,
    required DateTime now,
  });

  static List<CombatKillmailParticipant> participants(EsiKillmailDetail detail, {required int? selfCharacterId, required CombatActorTypeIndex typeIndex});
  static CorrelationContext contextFor(ParsedCombatEncounter encounter, List<CombatLogActor> actors, List<CombatKillmailParticipant> participants, {required bool selfIsVictim});
  static PairScore score({required CombatLogActor actor, required CombatKillmailParticipant participant, required CorrelationContext context, required CombatActorTypeIndex typeIndex});
  static AttackerCorrelation assign({required List<CombatLogActor> actors, required List<CombatKillmailParticipant> participants,
    required List<PairScore> pairs, required int totalIncomingDamage, required int killmailId, required bool selfIsVictim, required DateTime now});
}
```

`correlate` = classify → participants → context → all pair scores → assign.
`selfIsVictim = detail.victim.characterId == encounter.characterId`.

### 3.4 `combat_enrichment.dart` (edit)

```dart
final AttackerCorrelation? attackerCorrelation;          // absent-tolerant (R3.2.1)
// toJson:  if (attackerCorrelation != null) 'attackerCorrelation': attackerCorrelation!.toJson()
// fromJson: attackerCorrelation: AttackerCorrelation.fromJson(json['attackerCorrelation'])
// copyWith: + AttackerCorrelation? attackerCorrelation
// toPromptJson: if (attackerCorrelation != null) 'attackerCorrelation': attackerCorrelation!.toPromptJson()   (R5.1, §4.4)
```

### 3.5 `core/network/esi_client.dart` (edit)

```dart
// EsiKillmailAttacker
final int? factionId;                                   // json['faction_id']
bool get isPlayer => characterId != null;
// fromJson: characterName: json['character_name'] as String?, factionId: json['faction_id'] as int?
// toJson:   if (factionId != null) 'faction_id': factionId
// EsiKillmailVictim.fromJson: characterName: json['character_name'] as String?
```

---

## 4. Data layer

### 4.1 `combat_enrichment_service.dart`

```dart
/// Correlates when a matched killmail exists and no correlation is stored; saves once. Never throws.
Future<CombatEnrichment> ensureAttackerCorrelation(ParsedCombatEncounter encounter, CombatEnrichment enrichment);

Future<AttackerCorrelation?> _correlateOrNull(ParsedCombatEncounter encounter, EsiKillmailDetail detail);   // R5.4: try/catch → Log.e, null
Future<CombatActorTypeIndex> _buildTypeIndex(ParsedCombatEncounter encounter, EsiKillmailDetail detail);
CombatEvidenceLedger _correlationLedger(AttackerCorrelation correlation);
```

`_enrichmentFromMatch` (matched branch), after `final detail = await _withResolvedNames(...)`:

```dart
final correlation = await _correlateOrNull(encounter, detail);
final base = CombatEnrichment.fromKillmail(...);                       // unchanged factory
final ledger = _mergeLedgers(_baselineLedger(encounter), base.evidenceLedger);
return base.copyWith(
  attackerCorrelation: correlation,
  evidenceLedger: correlation == null ? ledger : _mergeLedgers(ledger, _correlationLedger(correlation)),
);
```

`_buildTypeIndex` (the only I/O, SDE reads via `_sdeService.database`):
- names = distinct normalised `incomingBySource` keys ∪ distinct incoming `weaponName`s (excluding empty/`unknown`);
  for each: `searchTypesByName(name, limit: 20)` → exact normalised match (prior art) → `getGroup(groupId)` → `CombatTypeRef`; memo per name.
- ids = participants' `shipTypeId` ∪ `weaponTypeId` (non-null) → `getType(id)` + `getGroup` → `byId`; memo per id.
- No ESI calls (R5.3). Missing types are simply absent from the index.

`ensureAttackerCorrelation`:
```
if enrichment.attackerCorrelation != null || enrichment.status != killmailMatched || enrichment.rawKillmail == null → return enrichment
detail = EsiKillmailDetail.fromJson(rawKillmail)           // names survive thanks to C2
correlation = await _correlateOrNull(encounter, detail)
if correlation == null → return enrichment                  // no write on failure (C12)
return _save(enrichment.copyWith(attackerCorrelation: correlation,
             evidenceLedger: _mergeLedgers(enrichment.evidenceLedger, _correlationLedger(correlation))))
```

`_correlationLedger` (spec §3.3):
- one fact per correlated attacker: `id = 'ev-correlated-attacker-<killmailId>-<characterId>'` (participant `characterId`; for the victim participant `'ev-correlated-victim-<killmailId>-<characterId>'`), `label 'Correlated attacker'`, `value '<actor.displayName> (<shipTypeName ?? 'Type #id'>) — <damage> damage — <signal labels joined ", ">'`, `source killmail`, `confidence`: confirmed → `proven`, probable → `derived`, possible → `reference`, `evidenceTime = correlatedAt`.
- unknown `opponentFit` / label `'Attackers absent from combat log'` / detail `'<n> killmail attackers dealt no logged damage: <names or Type #ids>'` when `uncorrelatedPlayerParticipants` non-empty;
- unknown `telemetry` / label `'Unattributed incoming damage'` / detail `'<amount> damage from <k> log actors could not be matched to a killmail attacker (<names>)'` when `unattributedIncomingDamage > 0`.
Labels are stable so `_mergeLedgers` de-duplicates on re-runs; neither label collides with the M3 `_fitFailure` labels.

Logging (R5.5): `_correlateOrNull` logs `Log.i('COMBAT.CORRELATE', ...)` per scored pair
(`actor=<name> participant=<key> score=0.95 signals=name,damage`) and one summary line
(`correlated=2 unattributed=1 npc=0 uncorrelated=1 damage=8400/0/0 total=8400`); the
correlator itself logs the same at `Log.d` so pure tests can capture it (T9.1).

### 4.2 `combat_analysis_service.dart`

Stage 4, after `enrichEncounter(...)`: `enrichment = await _enrichmentService.ensureAttackerCorrelation(encounter, enrichment);`.
Nothing else changes; the prompt receives the enriched object as before (its
`toPromptJson` now carries the additive block).

### 4.3 `combat_providers.dart`

```dart
final combatAttackerCorrelationProvider =
    FutureProvider.family<AttackerCorrelation?, ParsedCombatEncounter>((ref, encounter) async {
  Log.d('COMBAT.CORRELATE', 'combatAttackerCorrelationProvider(encounter=${encounter.id}) - START');
  final enrichment = await ref.watch(combatEnrichmentProvider(encounter.id).future);
  if (enrichment == null) return null;
  final ensured = await ref.read(combatEnrichmentServiceProvider).ensureAttackerCorrelation(encounter, enrichment);
  return ensured.attackerCorrelation;
});
```

It does not invalidate `combatEnrichmentProvider` (the write, if any, is read on the
next natural reload), so there is no loop.

### 4.4 Prompt (`CombatEnrichment.toPromptJson`, additive; R5.1)

```json
"attackerCorrelation": {
  "selfIsVictim": true,
  "correlated": [{"actor": "Artem S3", "characterId": 9001, "shipTypeId": 24702, "damage": 4200,
                  "confidence": "confirmed", "signals": ["name match", "damage proportion"]}],
  "unattributedIncomingDamage": 0, "npcIncomingDamage": 0,
  "uncorrelatedAttackerCount": 1, "uncorrelatedAttackers": [{"characterId": 9004, "shipTypeId": 24702, "damageDone": 2000}]
}
```

Lives inside the existing `killmailEvidence` object; no top-level key is added (the
M3 T4.6 key-set test stays green). One sentence is appended to the system prompt
rules: *"`attackerCorrelation` lists which combat-log actors map to killmail
participants and with what confidence; attribute damage to a named attacker only
when it is listed as correlated, and treat unattributed damage as unknown."*

### 4.5 `scripts/sde/generate_dogma_sde.py` and `sde_service.dart` (U0)

```python
NAME_ONLY_CATEGORIES = {11}   # Entity: NPC ships, sentries, structures — names for combat-log actor classification
```
- Categories/groups: include `TARGET_CATEGORIES ∪ NAME_ONLY_CATEGORIES`.
- Types: for groups of name-only categories, ignore `published`, emit `{typeId, typeName, groupId}` only (no `description`, no attributes, no effects; skip mass/volume).
- `SdeService.bundledDogmaVersion = 3`. The existing metadata gate reloads idempotently (sde_service_test line ~348 covers the mismatch path).
- Gate: `dogma.json` growth < 1 MB; `searchTypesByName('Serpentis Watchman')` exact-matches a type whose group is category 11.

---

## 5. Evidence scorer (`aar_evidence_scorer.dart`, edit)

Status logic is untouched (C10, R4.2.1, T6.4). `opponentIdentity()` appends a
suffix to the `matchedHigh` and `matchedLow` details when
`enrichment.attackerCorrelation?.correlated` is non-empty:

```
'; <n> of <m> log actors identified on the killmail (<Artem S3 confirmed, Kite Mondeo confirmed, Sabre probable>)'
```
where `m` = actors with class ≠ npc/unnamed, listed in `correlated` order, and — when
`selfIsVictim` and `n > 0` — the further suffix `'; attacker hulls known, fits not exposed by killmails'`
(R4.2.2, AC4.4). `opponentFit()` is not changed at all.

---

## 6. Presentation

### 6.1 `widgets/aar_attacker_correlation_section.dart`

```dart
/// Provider shell (T8.7): watches combatAttackerCorrelationProvider(encounter) with .when(skipLoadingOnReload: true).
class AarAttackerCorrelationSection extends ConsumerWidget { const AarAttackerCorrelationSection({super.key, required this.encounter}); }
//   data:    (c) => AarAttackerCorrelationBody(correlation: c, incomingBySource: encounter.aggregates.incomingBySource)
//   loading: () => LinearProgressIndicator (Key 'aar-attackers-loading')
//   error:   (e, s) => AarAttackerCorrelationBody(correlation: null, ...) + one line 'Attacker correlation unavailable' (Key 'aar-attackers-error')

/// Pure body (Group H renders this directly).
class AarAttackerCorrelationBody extends ConsumerStatefulWidget {   // Consumer for itemNameProvider; state for the collapsed list
  const AarAttackerCorrelationBody({super.key, required this.correlation, required this.incomingBySource});
}
```

Anatomy (spec §7.1), `Card` like `AarDerivedStatsPanel`:
- Header: `Attackers` + `correlation.summaryLine` (Key `aar-attackers-summary`). Null correlation → header `Incoming Sources` and **no** summary counts (R7.3.1, T8.5).
- Correlated rows (Key `aar-attacker-row-<participant.key>`): `EveTypeIcon(shipTypeId)`, `actor.displayName`, ship name via `ref.watch(itemNameProvider(shipTypeId)).when(data: name, loading: 'Loading…', error: 'Type #id')` (R7.2.2), damage with thousands separator, badge (icon + colour per §7.2, Key `aar-attacker-badge-<key>`, text `confidence.label`), secondary line `signalLabels.join(', ')` (R7.2.1).
- Null-correlation rows (Key `aar-actor-row-<normalised name>`): name + damage only, no badge, no icon.
- Bucket rows: `NPC damage` (only when `npcIncomingDamage > 0`, Key `aar-attackers-npc`), `Unattributed` (only when `> 0`, Key `aar-attackers-unattributed`) each followed by the actor names in that bucket with their reason word (`not on the killmail`, `ambiguous`, `below threshold`, `unnamed`).
- Collapsed list (Key `aar-attackers-uncorrelated-toggle`): label `'<n> attacker(s) not present in your combat log'` when `selfIsVictim`, else `'<n> other attacker(s) on this kill'` (singular when `n == 1`); expanding shows one row per uncorrelated **player** participant (name or `Type #`, ship via `itemNameProvider`, `damageDone`) with the `remove_circle_outline` badge; NPC participants are listed under the NPC row instead.
- Footer note when `selfIsVictim && correlated.isNotEmpty` (Key `aar-attackers-fits-note`): `'Attacker fits are not exposed by killmails; hulls shown are ship types only.'` (R7.3.3, AC4.4).

Every `build` logs `Log.d('COMBAT.UI', ...)`.

### 6.2 `widgets/aar_matchup_section.dart` (edit)

`const AarMatchupSection({super.key, required this.matchup, this.correlatedAttackerCount = 0})`.
When `correlatedAttackerCount >= 2`, the first child is a `Text` (Key `aar-matchup-blend-advisory`,
`EveColors.warning`): `'Incoming profile is a blend across <n> attackers; the named resist hole is aggregate, not per attacker.'` (R4.3.2).

### 6.3 `analysis_multipane_screen.dart` (edit)

- `_matchupWidgets`: pass `correlatedAttackerCount` from `ref.watch(combatAttackerCorrelationProvider(encounter)).when(data: (c) => c?.correlated.length ?? 0, loading: () => 0, error: (_, _) => 0)` to the **self** matchup only (it is the incoming profile).
- `_buildDamageTabContent`: after `..._matchupWidgets(encounter)` insert `AarAttackerCorrelationSection(encounter: encounter)` + 16 px; delete the trailing `_BreakdownSection(title: 'Incoming Sources', ...)` and its spacer (D5).

---

## 7. Test specifications

Layering: pure unit → wiring → widget → screen. Names are the verbatim
`test(...)`/`testWidgets(...)` descriptions.

### 7.0 Fixtures — `test/features/combat_analyzer/fixtures/attacker_correlation_fixtures.dart`

```dart
/// Incoming-only encounter from parser lines: one line per (actor, amount, weapon, second).
ParsedCombatEncounter incomingEncounter(List<(String actor, int amount, String weapon, int second)> hits,
    {int? characterId = 42, String listener = 'Pilot'});
// '[ 2026.05.20 20:00:<ss> ] (combat) <amount> from <actor> - <weapon> - Hits'

EsiKillmailAttacker attacker({int? characterId, String? characterName, int? shipTypeId, int? weaponTypeId,
    int damageDone = 0, bool finalBlow = false, int? factionId});
EsiKillmailVictim victim({int? characterId = 42, String? characterName = 'Pilot', int shipTypeId = 587, int damageTaken = 0});
EsiKillmailDetail detail({int killmailId = 1234567, required EsiKillmailVictim victim, required List<EsiKillmailAttacker> attackers});

/// Hand-built index. Ships: Rifter 587/25, Sabre 22456/541, Hurricane 24702/419, Jackdaw 34828/1305 (category 6);
/// Entities: 'Serpentis Watchman' 30001/group 2001 (category 11); weapons: 'Heavy Missile' 2410/group 385, 'Light Missile' 2412/385,
/// '425mm AutoCannon II' 2905/55, 'Scourge Rocket' 2514/384.
CombatActorTypeIndex typeIndex();
CombatTypeRef ref(int typeId, String name, int groupId, int categoryId);

// Scenario builders return (encounter, detail) pairs; §2.4 numbers exactly.
({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s1Kill();
({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s2Loss();
({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s3Fleet();   // 12 attackers, 7 actors, two Sabre attackers with equal signals
({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s4ThirdParty();
({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s5NpcMix();
final now = DateTime.utc(2026, 9, 11, 12);
AttackerCorrelation correlate(({ParsedCombatEncounter encounter, EsiKillmailDetail detail}) s) =>
    const CombatAttackerCorrelator().correlate(encounter: s.encounter, detail: s.detail, typeIndex: typeIndex(), now: now);

// Pure pair builders for Group B
CombatLogActor actor(String name, {CombatActorClass cls = CombatActorClass.player, int damage = 1000, List<String> weapons = const [], int? typeId});
CombatKillmailParticipant participant({String key = 'a0', int? characterId = 9001, String? name = 'Artem S3', int? shipTypeId = 24702,
    int? weaponTypeId, int? weaponGroupId, int? damageDone = 1000, bool finalBlow = false, bool isVictim = false});
CorrelationContext context({bool selfIsVictim = true, String? lastIncomingActor, int playerActorCount = 2, int playerParticipantCount = 2});
```

### 7.1 Group A — `domain/combat_actor_classifier_test.dart` (pure)

- **T1.1** `name matching a resolved attacker classifies player` — actor `Artem S3`, participant name `Artem S3` → `player`, `resolvedTypeId == null`.
- **T1.2** `name resolving to a category 11 type classifies npc` — `Serpentis Watchman` → `npc`, `resolvedTypeId == 30001`.
- **T1.3** `name resolving to a category 6 type classifies shipType` — `Sabre` → `shipType`, `resolvedTypeId == 22456` (no player-attacker precondition, C9).
- **T1.4** `unresolvable name with no attacker match defaults to player` — `Kite Mondeo` with no participants → `player`.
- **T1.5** `name matching both a type and an attacker classifies ambiguous` — participant named `Sabre` plus index entry → `ambiguous`; `isScorable == true`.
- **T1.6** `classification is exact normalised match, not substring` — index has `Sabre` and `Sabre Fleet Issue`; actor `Sabre` → 22456; actor `sabre  ` (extra spaces) → 22456; actor `Sabre Fleet` → `player`.
- **T1.7** `empty and Unknown names classify unnamed and keep their damage` — `incomingBySource` containing `'Unknown': 150` → one actor `unnamed`, `damageDealt 150`.
- **A.8** `actor carries distinct sorted weapons and first/last seen` — three hits from `Artem S3` with weapons `Heavy Missile`, `Heavy Missile`, `425mm AutoCannon II` at seconds 4/8/12 → `weaponNames == ['425mm AutoCannon II', 'Heavy Missile']`, `firstSeen.second == 4`, `lastSeen.second == 12`.
- **A.9** `actors are sorted by damage desc then name` — three actors → order deterministic across 100 runs.
- **A.10** `every actor gets exactly one class` (AC2.1) — S5 → each `incomingBySource` key appears once with a non-null class.

### 7.2 Group B — `domain/attacker_correlator_signals_test.dart` (pure; `score`)

- **T2.1** `name alone reaches confirmed` — `actor('Artem S3')`, `participant(name: 'Artem S3', damageDone: null)`, context counts 2/2 → `score 0.75`, `band confirmed`, `signals [name]`.
- **T2.2** `damage alone does not correlate` — `actor('Zed', damage: 1000)`, `participant(name: 'Other', damageDone: 1000)` → `score 0.20`, `band null`.
- **T2.3** `ship + damage reaches probable, not confirmed` — `actor('Sabre', cls: shipType, typeId: 22456, damage: 1100)`, `participant(shipTypeId: 22456, damageDone: 1250, name: 'Dax Rho')` → `0.50`, `band probable`, `cappedBand probable`.
- **T2.4** `damage awards full at 0.60, half at 0.35, none at 0.20` — ratios via damages (600/1000 → 0.20; 350/1000 → 0.10; 200/1000 → 0).
- **T2.5** `damage mismatch never subtracts` — name match with damages 100 vs 10,000 → `score 0.75` (not lower).
- **T2.6** `timing fires only for final-blow participant, last incoming actor, self victim` — four cases: all true → +0.15; `finalBlow false` → 0; `lastIncomingActor` other → 0; `selfIsVictim false` → 0.
- **T2.7** `sole fires for 1 player participant and 1 player actor` — context 1/1 → +0.10.
- **T2.8** `sole does not fire for a shipType actor or when counts differ` — `actor(cls: shipType)` with context 1/1 → no `sole`; context 2/1 → no `sole` (R2.4.1).
- **T2.9** `weapon fires on exact type and on shared group` — actor weapons `['Heavy Missile']` (2410/385): participant `weaponTypeId 2410` → +0.20; `weaponTypeId 2412, weaponGroupId 385` → +0.20; `weaponTypeId 2905, weaponGroupId 55` → 0.
- **T2.10** `weights are named constants with the documented values` — `weights[name] 0.75`, `[ship] 0.30`, `[weapon] 0.20`, `[damage] 0.20`, `[timing] 0.15`, `[sole] 0.10`; thresholds 0.75/0.50/0.30; margin 0.10.
- **B.11** `shipType actor is capped at probable` — ship + weapon + damage + timing = 0.85 → `band confirmed`, `cappedBand probable`.
- **B.12** `victim participant never earns damage` — `participant(isVictim: true, damageDone: null)` with any actor damage → no `damage` signal (C5).
- **B.13** `score is clamped to 1.0` — name + damage + timing + sole = 1.20 → `1.0`.
- **B.14** `null participant name is no signal, not a mismatch` — `participant(name: null)` → no `name`; other signals unaffected.

### 7.3 Group C — `domain/attacker_correlator_test.dart` (pure; `assign` and `correlate`)

- **T3.1** `greedy assignment fixes the highest pair first` — two actors, two participants with cross scores 0.95/0.60/0.55/0.90 → pairs (A→X 0.95), (B→Y 0.90).
- **T3.2** `one-to-one in both directions` — actors A (`Artem S3`, player, 4,200) and B (`Hurricane`, shipType 24702, 2,600); participants X (Artem, Hurricane, damageDone 4,200) and Y (Pell Ivo, Hurricane, damageDone 2,000). Scores: A→X name + damage = 0.95; B→X ship + damage (2600/4200 = 0.62) = 0.50; B→Y ship + damage (2000/2600 = 0.77) = 0.50. Result: A→X `confirmed` (0.95 − 0.50 ≥ margin, so no conflict), B→X dropped with X, then B→Y `probable`; every actor and participant appears at most once in `correlated` (AC1.3).
- **T3.3** `ties within 0.10 assign neither` — S3's two Sabre attackers vs the `Sabre` actor (0.50 each) → `reasons['actor:sabre'] == ambiguous`; both attackers `noLogPresence`.
- **T3.4** `deterministic across 100 runs including tie-break order` — S3 → identical `toJson()` strings 100×; and with participants supplied in reversed order.
- **T3.5** `sub-threshold pairs land in belowThreshold` — actor with only a weapon signal (0.20) → `reasons['actor:<key>'] == belowThreshold`.
- **T3.6** `damage invariant holds` — for S1–S5: `correlated + unattributed + npc == encounter.totalDamageReceived` and `accountsForAllDamage`.
- **T3.7** `uncorrelated participants listed with noLogPresence` — S2 → Pell Ivo present with `reasons['participant:a3'] == noLogPresence`.
- **T3.8** `NPC damage bucketed separately` — S5 → `npcIncomingDamage 1400`, `unattributedIncomingDamage 0`, NPC participant `reasons['participant:a1'] == npcAttacker`.
- **T3.9** `empty attacker list → all actors unattributed, no crash` — detail with attackers `[]` and victim = user → every actor `notOnKillmail`; `correlated.isEmpty`.
- **T3.10** `empty log actors → all participants uncorrelated, no crash` — encounter with no incoming events → every player participant `noLogPresence`; totals 0.
- **C.11** `notOnKillmail vs belowThreshold` — S4 Kite (score 0) → `notOnKillmail`; an actor with a weapon-only signal → `belowThreshold`.
- **C.12** `the user is excluded from participants` — S1 → `participants` has one entry (the victim), none with `characterId 42`.
- **C.13** `correlated list sorted by actor damage desc` — S2 → `[Artem S3, Kite Mondeo, Sabre]`.
- **C.14** `unnamed damage is unattributed with reason unnamed` — encounter with an `Unknown` source → `reasons['actor:unknown'] == unnamed`, damage counted in `unattributedIncomingDamage`.

### 7.4 Group D — `domain/attacker_correlation_scenarios_test.dart` (pure; §2.4 verbatim)

- **T4.1** `S1 solo kill` — one correlation `Vex Kalari`, `confirmed`, `score 0.85`, `signals [name, sole]`, `selfIsVictim false`, participant `isVictim true`.
- **T4.2** `S2 loss with three attackers and a ship-type actor` — Artem `confirmed 0.95 [name, damage]`; Kite `confirmed 1.0 [name, damage, timing]`; Sabre `probable 0.50 [ship, damage]` and never confirmed; Pell Ivo `noLogPresence`; totals 8,400/0/0.
- **T4.3** `S3 fleet` — 6 correlated (4 confirmed, 2 probable), `Sabre` actor `ambiguous`, 6 uncorrelated participants (4 absent + 2 Sabres), `uncorrelatedPlayerParticipants.length == 6`, unattributed == the Sabre actor's damage.
- **T4.4** `S4 third party absent from the killmail` — Kite `notOnKillmail`, unattributed 1,100, Artem confirmed.
- **T4.5** `S5 NPC and player mixed` — Watchman `npc`, never correlated; Artem `confirmed 1.0 [name, damage, sole]`; npc 1,400.
- **T4.6** `S6 no killmail → null` — `CombatEnrichment(status: logOnly).attackerCorrelation == null`; `AttackerCorrelation.fromJson(null) == null`.
- **D.7** `JSON round-trip for every scenario` — `AttackerCorrelation.fromJson(jsonDecode(jsonEncode(c.toJson())))` deep-equals `c` (compare `toJson()` maps) for S1–S5 (R3.1.2).
- **D.8** `fromJson tolerates unknown enum names and missing keys` — a `correlated` entry with `confidence: 'certain'` is skipped; missing `reasons` → `{}`; missing `killmailId` → null.

### 7.5 Group E — `data/combat_enrichment_service_test.dart` (extend; Drift in-memory)

Harness: the existing `setUp` plus a `FakeEsiClient extends EsiClient` overriding
`getKillmailDetail` (returns the S2 detail **without** names, counts calls) and
`resolveNames` (returns character names, counts calls). Seed the SDE with the §7.0
types and groups (categories 6 and 11) via `upsertCategories/Groups/Types`. Seed the
zKill search cache so no discovery call happens: `saveSearchCache(characterId: 42,
year: 2026, month: 5, direction: 'losses', page: 1, response: [ref.toJson()])`,
page 2 → `[]`, and `'kills'` page 1 → `[]`. No token → `_hasKillmailScope` false → ESI
recent skipped.

- **T5.1** `enrichEncounter correlates after name resolution and persists` — `enrichEncounter(s2.encounter)` → `attackerCorrelation != null`, Artem `confirmed` (proves names were resolved first), `loadEnrichment(id).attackerCorrelation` equal.
- **T5.2** `attackerCorrelation round-trips through CombatEnrichment JSON` — `CombatEnrichment.fromJson(e.toJson()).attackerCorrelation!.toJson()` deep-equals.
- **T5.3** `pre-milestone JSON without the field loads with null` — a v-M3 enrichment map (no key) → `attackerCorrelation == null`, no throw (AC5.1).
- **T5.4** `no new network calls during correlation` — after T5.1, `FakeEsiClient` counts: `getKillmailDetail == 1`, `resolveNames == 1`, nothing else; `ensureAttackerCorrelation` on the loaded row → counts unchanged (R5.3).
- **T5.5** `correlation failure leaves enrichment intact` — inject a throwing `CombatAttackerCorrelator` (constructor parameter `correlator` with default) → `enrichEncounter` returns `killmailMatched` with `attackerCorrelation == null`, victim fit evidence present; a `Log.e` line captured via `debugPrint`.
- **T5.6** `evidence facts emitted per correlated attacker` — ledger has `ev-correlated-attacker-1234567-9001` (`proven`), `-9002` (`proven`), `-9003` (`derived`); unknowns contain `'Attackers absent from combat log'`; running `ensureAttackerCorrelation` again adds no duplicates.
- **E.7** `ensureAttackerCorrelation backfills a cached row once` — save an enrichment with `rawKillmail` (names present in JSON) and `attackerCorrelation: null`; call → correlated, saved (`loadEnrichment` shows it), second call returns the same object without `saveEnrichment` (spy repository counts writes == 1).
- **E.8** `ensureAttackerCorrelation is a no-op for logOnly and for rows without rawKillmail`.
- **E.9** `rawKillmail names survive the round-trip` (C2) — `EsiKillmailDetail.fromJson(detail.toJson()).attackers.first.characterName == 'Artem S3'`; victim likewise; `factionId` round-trips (`test/core/network/esi_client_test.dart` or this file).
- **E.10** `analysis stage 4 ensures correlation` (`combat_analysis_service_test.dart`, extend T9.2 harness) — cached enrichment with `rawKillmail`, no correlation → after `analyzeEncounter`, `loadEnrichment` has correlation and the captured prompt contains `killmailEvidence.attackerCorrelation`.

### 7.6 Group F — `domain/aar_evidence_dimensions_test.dart` (extend)

Use the M3 `enrichment(...)` fixture with a new optional `attackerCorrelation` parameter.

- **T6.1** `D4 unchanged when user is victim even with confirmed correlations` — S1b inputs (own loss) with S2's correlation attached → `opponentFit` status and detail identical to the no-correlation result.
- **T6.2** `D3 detail enumerates correlated attackers` — matchedHigh + S2 correlation → detail contains `'; 3 of 3 log actors identified on the killmail (Artem S3 confirmed, Kite Mondeo confirmed, Sabre probable)'` and `'; attacker hulls known, fits not exposed by killmails'`; status `complete`.
- **T6.3** `D3/D4 unchanged when user is attacker` — S1 inputs (kill) with S1 correlation → statuses equal; D3 detail gains only the enumeration suffix (no fits note).
- **T6.4** `completeness score unchanged by correlation` — `assess(s1bInputs())` score == score with correlation attached; same for S1 and S7.
- **T6.5** `all Milestone 3 scorer tests still pass unchanged` — no edits to existing expectations (CI).
- **F.6** `no new actions are introduced` (I1) — every row's `actions` list equal with and without correlation.

### 7.7 Group G — `data/combat_analysis_service_test.dart` (extend)

- **T7.1** `existing v4 fields byte-identical with null correlation; additive with correlation` — for an enrichment without correlation the prompt string equals the M3 baseline built from the same inputs; with correlation, every pre-existing key of `payload['killmailEvidence']` deep-equals and the only new key is `attackerCorrelation`; top-level keys ⊆ the M3 set.
- **T7.2** `correlation block omitted when null` — `'attackerCorrelation'` absent from `enrichment.toPromptJson()` and from the prompt string.
- **G.3** `system prompt contains the attribution rule sentence` — `contains('attackerCorrelation lists which combat-log actors')`.

### 7.8 Group H — `presentation/aar_attacker_correlation_section_test.dart`

Pump `AarAttackerCorrelationBody(correlation: c, incomingBySource: …)` inside
`ProviderScope(overrides: [itemNameProvider(24702).overrideWith((_) async => 'Hurricane'), …])` and `MaterialApp`.

- **T8.1** `correlated rows render badge, ship, damage, signals` — S2 → row `aar-attacker-row-a0` shows `Artem S3`, `Hurricane`, `4,200`, `Confirmed`, `name match, damage proportion`.
- **T8.2** `badge colours map per §7.2` — confirmed `check_circle`/`EveColors.success`; probable `help_outline`/`EveColors.warning`; possible `warning_amber`/`EveColors.warning`; uncorrelated `remove_circle_outline`/`EveColors.textSecondary`.
- **T8.3** `uncorrelated list collapsed but expandable` — S2 → `aar-attackers-uncorrelated-toggle` text `'1 attacker not present in your combat log'`, rows absent; tap → `Pell Ivo` row visible.
- **T8.4** `NPC and unattributed rows render distinctly` — S5 → `aar-attackers-npc` with `1,400`; S4 → `aar-attackers-unattributed` with `1,100` and `Kite Mondeo — not on the killmail`.
- **T8.5** `null correlation renders plain actors, no badges, no counts` — `correlation: null`, `incomingBySource {'Artem S3': 300}` → row `aar-actor-row-artem s3`, no `Confirmed`/`Probable` text, no `'0 identified'`, header `Incoming Sources`.
- **T8.6** `ship names resolve via itemNameProvider` — with the override → `Hurricane`; with an erroring override → `Type #24702`; never both.
- **T8.7** `loading and error states via .when()` — provider shell with a never-completing override → `aar-attackers-loading`; throwing override → `aar-attackers-error` and plain actor rows.
- **T8.8** `matchup advisory renders at ≥ 2 correlated` — `AarMatchupSection(matchup: m, correlatedAttackerCount: 2)` → `aar-matchup-blend-advisory`; with 1 → absent.
- **T8.9** `attacker-fits-unavailable note renders on a loss` — S2 → `aar-attackers-fits-note`; S1 (kill) → absent.
- **H.10** `kill wording for other attackers` — S1 with one extra fleetmate attacker → toggle text `'1 other attacker on this kill'`.
- **H.11** `screen: section renders after the matchups and Incoming Sources is gone` (`analysis_multipane_evidence_test.dart`, extend) — Damage tab → `find.byType(AarAttackerCorrelationSection)` `dy` > matchup `dy`; `find.text('Incoming Sources')` findsNothing when correlation non-null.

### 7.9 Group I — `domain/attacker_correlation_logging_test.dart`

Capture `debugPrint` as in M3's logging test.

- **T9.1** `correlate logs [COMBAT.CORRELATE] with per-pair scores and signals` — S2 → lines matching `'[COMBAT.CORRELATE] … actor=Sabre participant=a2 score=0.50 signals=ship,damage'` and a summary `'correlated=3 unattributed=0 npc=0 uncorrelated=1'`.
- **I.2** `service logs at info on enrichment` — Group E T5.1 captures a `'[COMBAT.CORRELATE] ℹ️'` summary line.

### 7.10 U0 — `test/core/sde/real_sde_entity_types_test.dart`

- **U0.1** `bundled dogma.json includes category 11 names` — load `assets/sde/dogma.json` from disk (pattern of `real_sde_defense_test.dart`), seed an in-memory `SdeDatabase`, `searchTypesByName('Serpentis Watchman')` exact-normalised match exists and `getGroup(type.groupId).categoryId == 11`; the type has no attributes (`getTypeAttributes` empty).
- **U0.2** `bundledDogmaVersion is 3` and `sde_service_test` re-import on mismatch still green.

### 7.11 Regression (AC5.5)

`flutter test` green with no edits to existing expectations except the three
files marked "extend"; `flutter analyze` clean; M3's T4.6 key-set test unchanged.

---

## 8. Unit breakdown for Plan (TDD; RED → GREEN → REFACTOR)

Tiering by work shape (judgement → Opus; mechanical → Sonnet). Atomic commits per
unit, `type(scope): description`, no attribution lines.

**U0 [P1] SDE: bundle category 11 names** — Sonnet (generator edit is mechanical; regeneration needs network access to the SDE CSVs).
- RED: §7.10 U0.1/U0.2 (fail: no such type, version 2).
- GREEN: `NAME_ONLY_CATEGORIES`, regenerate `dogma.json`, `bundledDogmaVersion = 3`.
- REFACTOR: none. Gate: asset growth < 1 MB, `flutter test test/core/sde`.
- Commit: `feat(sde): bundle category 11 entity type names for combat-log actor classification`.

**U1 [P1] Domain: models, classifier, correlator** — Opus.
- RED: `attacker_correlation_fixtures.dart`, Groups A, B, C, D, I T9.1.
- GREEN: `combat_attacker_correlation.dart`, `combat_actor_classifier.dart`, `combat_attacker_correlator.dart`.
- REFACTOR: extract the pair-sort comparator and the reason bookkeeping into private helpers; confirm no `DateTime.now()`.
- Commit: `feat(combat): add pure attacker correlator with actor classification and unattributed accounting`.

**U1b [P1] Models: ESI names/faction and enrichment field** — Sonnet.
- RED: E.9, T5.2, T5.3, D.7/D.8 (JSON parts).
- GREEN: `esi_client.dart` fromJson/factionId/isPlayer; `CombatEnrichment.attackerCorrelation` (toJson/fromJson/copyWith/toPromptJson).
- Commit: `feat(combat): persist attacker correlation on enrichment; keep killmail names through JSON`.

**U2 [SEQ after U0, U1, U1b] Service, ledger, provider, prompt** — Opus (the `_enrichmentFromMatch` seam and ledger merge need judgement).
- RED: Group E (T5.1–T5.6, E.7, E.8, E.10), Group G, I.2.
- GREEN: `_buildTypeIndex`, `_correlateOrNull`, `ensureAttackerCorrelation`, `_correlationLedger`, stage-4 call, `combatAttackerCorrelationProvider`, system-prompt sentence.
- REFACTOR: share the exact-normalised SDE lookup with `CombatDamageProfileResolver` if trivially extractable; otherwise leave (two call sites, same eight lines).
- Commit: `feat(combat): correlate killmail attackers with combat-log actors during enrichment`.

**U3 [SEQ after U2] Evidence scorer detail** — Sonnet.
- RED: Group F. GREEN: `_correlationSuffix` in `opponentIdentity()`. Commit: `feat(combat): enumerate correlated attackers in the opponent identity detail`.

**U4 [SEQ after U2] UI section, matchup advisory, screen wiring** — Sonnet.
- RED: Group H. GREEN: `aar_attacker_correlation_section.dart`, `AarMatchupSection.correlatedAttackerCount`, Damage tab wiring, `Incoming Sources` removed.
- Commit: `feat(combat): show correlated attackers with confidence badges in the AAR damage tab`.

**U5 [P2 after U4] Journal** — Sonnet. §9. Commit: `docs(journal): closeout zKill attacker correlation`.

**U6 [SEQ] Closing gate** — Sonnet. `flutter analyze`; full `flutter test`; manual macOS check on a real loss with ≥ 2 attackers: badges and signals visible, summary counts add up to Damage Taken, advisory shown above the self matchup, a pre-milestone cached AAR gains correlation on first open and the second open causes no write (watch `[COMBAT.ENRICH] Saved enrichment cache` in logs).

U0, U1 and U1b run in parallel; U2 is the join. U3 and U4 can run in parallel after U2.

---

## 9. Journal protocol on ship (spec §11 plus)

- ARCHIVE: QUEUED P2 "Correlate zKill attackers with combat-log actors" as SHIPPED, revised effort (spec §0.4), classification stage unanticipated, and **the bundled SDE had no NPC types** (C1).
- LEARNINGS: (1) *combat logs name the displayed entity, not the pilot* (spec §11); (2) *killmails expose victim fits only* (spec §11); (3) *the SDE bundle is scoped by consumer, so a new consumer must audit categories first* — categories 11 was absent, unpublished, and needed a names-only path; (4) *`toJson` writing a field that `fromJson` ignores is a silent data loss on cache round-trips* — `character_name` was lost for every cached killmail; rule: round-trip tests for every persisted value type.
- DECISIONS: D5 (replace `Incoming Sources`), D6 (names-only category 11), D7 (weights corrected to make the stated outcomes arithmetically true), D8 (participant pool includes the victim).
- QUEUE P2: per-attacker incoming damage profile and matchup (spec D4). QUEUE P3: reference fits for correlated hulls (spec §11); ESI `inventory_type` name resolution as a fallback when a log actor is not in the bundled SDE; drone-named log actors (rule 6 limitation).

---

## 10. Out of scope, stated

Per-attacker matchup re-derivation; the ship-vs-ship diagram; outgoing-side
correlation beyond the primary victim; attacker fit inference; new network calls;
changing any existing prompt field; migrating the `combat_encounter_enrichments`
table (the JSON column absorbs the new field); classification of drone- or
structure-named log actors beyond the default rule.

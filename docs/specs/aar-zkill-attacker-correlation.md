# Milestone Spec: Correlate zKill Attackers with Combat-Log Actors

**Status.** Draft for Arch.
**Author.** Product.
**Date.** 2026-09-11.
**Priority.** P2 (QUEUED.md).
**Estimated effort.** Two to three days (QUEUED says one to two; see §0.4).
**Depends on.** Milestone 2 (fit derivation), Milestone 3 (evidence completeness), both merged.
**Refs.** `docs/specs/aar-fit-simulation-and-defense-profiles.md`;
`docs/specs/aar-evidence-completeness-score.md`;
`lib/features/combat_analyzer/domain/combat_killmail_matcher.dart`;
`lib/features/combat_analyzer/domain/parsed_combat_encounter.dart`.

---

## 0. Grounding: what the two sources actually contain

Correlation heuristics are only as good as the fields that exist. I read the parser, its
real-log fixtures, and the ESI killmail models before writing §2, and three findings
reshape the milestone.

### 0.1 The combat log does not name pilots — it names *whatever the client displays*

`CombatLogParser._damageRegex` (`combat_log_parser.dart:18`) is:

```dart
RegExp(r'^(\d+) (to|from) (.*?) - (.*?) - (.*)$')
```

Group 3 becomes `CombatEvent.targetName`. What lands there depends on the engagement:

- **PvE:** the real fixture at `combat_log_parser_test.dart:47-49` yields
  `targetName: 'Serpentis Watchman'` — an **NPC ship type name**, not a pilot.
- **PvP:** `combat_killmail_matcher_test.dart:79` uses `targetName: 'Artem S3'` — a
  **player character name**.

So the same field holds two categorically different kinds of identifier, and **nothing in
the log marks which**. A correlator that assumes "targetName is a pilot name" will
confidently map NPC damage onto player attackers. In an intel tool that is the Pathfinder
failure mode — plausible-looking fabricated attribution.

**Consequence.** §2.1 makes actor *classification* (player vs NPC vs ambiguous) a
mandatory first stage that runs before any matching. This is the single largest piece of
work in the milestone and it is not in the QUEUED description.

### 0.2 The log has no per-attacker damage split on the incoming side — it has exactly that

Correction to a natural assumption: the log **does** split incoming damage by source.
`CombatAggregates.incomingBySource` (`parsed_combat_encounter.dart`) is a
`Map<String, int>` built at `combat_log_parser.dart:345` from `event.targetName` on
incoming events. So for a multi-attacker fight we have, per displayed actor name, the
total damage that actor dealt to us and the timestamps of each hit.

The killmail gives us `EsiKillmailAttacker.damageDone` per attacker. **These are directly
comparable quantities**, which is what makes damage-based correlation viable rather than
speculative. §2.3 uses it.

### 0.3 Attacker names are already resolved — but only sometimes

`EsiKillmailAttacker.fromJson` (`esi_client.dart`) does **not** parse `character_name`;
the field is populated later by `_withResolvedNames()`
(`combat_enrichment_service.dart:616-645`), which calls `resolveNames()` and rebuilds
each attacker via `copyWith`. That call is wrapped in a try/catch that returns the
**unresolved** detail on failure (line 643).

So `characterName` is present in the common case and absent when name resolution failed,
when the attacker is an NPC or structure (no `characterId`), or when the attacker is
deliberately anonymous. The correlator must treat a null name as "no name signal", never
as "no match".

`CombatKillmailMatcher._matchesEncounterName` (line 196) already does exactly this kind
of normalized name comparison against log actor names. **That function is the prior art
for this milestone** and its scoring shape (accumulate weighted signals, threshold,
ambiguity margin) should be reused rather than reinvented.

### 0.4 Why the estimate moves to two to three days

QUEUED says one to two days. The actor-classification stage (§0.1) is a substantial
addition, and the `Unattributed` bucket (§2.6) plus the asymmetry in §4.2 each need their
own tests. The correlation scorer itself is a day; classification and the evidence/UI
integration are the rest.

### 0.5 The ship-vs-ship diagram does not exist

The brief says correlation "grounds ship-vs-ship diagrams". A repo-wide grep for
`shipVsShip|ship_vs_ship|ShipVsShip|diagram` returns nothing in `lib/`. That diagram is
a **future consumer** of this milestone's output, tracked separately in QUEUED as "Fit
comparison visuals for AAR reports". This spec produces the correlation data it will
need and explicitly does not build it (§1.4).

---

## 1. Product perspective

### 1.1 The problem in user terms

A user reviews a fight they lost to three attackers. The AAR says they took 8,400 damage.
The killmail lists a Hurricane, a Jackdaw, and a Sabre. The combat log says
`4,200 from Artem S3`, `3,100 from Kite Mondeo`, `1,100 from Sabre`.

The user has to do the join in their head, and they cannot fully do it — the log's third
entry says "Sabre" (a ship type) while the killmail lists a character. Meanwhile the
analyzer treats all incoming damage as one undifferentiated pool, so its resist-hole
analysis blends a Hurricane's projectiles with a Jackdaw's missiles as though one ship
fired both.

That last point is the real cost. Milestone 2 derives EHP against an incoming damage
profile. When that profile is a blend of three ships, the "resist hole" it names is an
artifact of the blend, not a property of any actual attacker.

### 1.2 The governing principle

Milestones 2 and 3 established, in order:

> Every quantitative claim must be attributable to a derivation the user can inspect, or
> explicitly labelled as an unknown.

> The user must see what the analysis can conclude before spending anything on it.

This milestone adds the attribution dimension:

> **Every attributed claim must name the specific attacker it is about, and an attacker
> the tool cannot confidently identify must be shown as unattributed rather than folded
> silently into an aggregate.**

The second clause is the one that matters. The tempting design is to assign every log
actor to *some* killmail attacker and call it done. That produces a tidy UI and wrong
intel. §2.6's `Unattributed` bucket is non-negotiable.

### 1.3 What changes for the user

**Before:** "You took 8,400 damage." Three attackers on the killmail, no link between
them and the log. Matchup analysis blends all incoming damage.

**After:** "You took 8,400 damage from 3 attackers: Artem S3 (Hurricane, 4,200 — high
confidence), Kite Mondeo (Jackdaw, 3,100 — high confidence), and 1,100 unattributed."
Each correlated attacker carries a confidence badge, and the user can see the basis.

### 1.4 Non-goals

- **Not** building the ship-vs-ship diagram (§0.5).
- **Not** per-attacker matchup *re-derivation* in V1. Correlation produces the data; the
  matchup continues to use the aggregate profile. Splitting the matchup per attacker is
  queued as follow-up (§10). This keeps the milestone bounded and avoids destabilising
  Milestone 2's shipped derivation path.
- **Not** correlating the pilot's *outgoing* damage to victims beyond the primary victim.
- **Not** new network calls. Killmail detail and name resolution already happen.
- **Not** inferring attacker fits beyond what the killmail already proves.
- **Not** changing prompt schema v4's existing fields (additive only, R5.1).

---

## 2. Correlation rules and heuristics

### 2.1 Stage 1 — Classify log actors (mandatory, runs first)

Every distinct actor name from `incomingBySource` keys is classified before matching:

| Class | Test | Example |
| --- | --- | --- |
| `player` | Name matches a resolved killmail attacker `characterName` (normalized), **or** does not resolve to an SDE type name | `Artem S3` |
| `npc` | Name resolves to an SDE type in an NPC faction/pirate group | `Serpentis Watchman` |
| `shipType` | Name resolves to an SDE ship type but the fight has player attackers | `Sabre` |
| `ambiguous` | Resolves to an SDE type **and** matches an attacker name | rare; treat as `player` |

SDE lookup uses the existing `searchTypesByName()` (`sde_database.dart:324`) with exact
normalized comparison, mirroring
`CombatDamageProfileResolver._lookupDamageAttributes()` (line 153-165), which already
does precisely this normalize-then-exact-match for weapon names.

- **R2.1.1** Classification MUST run before correlation and MUST be recorded per actor.
- **R2.1.2** `npc` actors MUST NOT be correlated to player attackers under any signal.
- **R2.1.3** `shipType` actors MAY correlate to an attacker via ship-type match (§2.2),
  but MUST cap at `probable` confidence — a ship-type name identifies a hull, not a pilot.

### 2.2 Stage 2 — Signals

Each (log actor, killmail attacker) pair accumulates weighted signals. Weights follow
`CombatKillmailMatcher.score()`'s established shape.

| Signal | Weight | Rule |
| --- | --- | --- |
| **S-NAME** Exact name match | **0.60** | Normalized actor name == attacker `characterName`. Decisive on its own. |
| **S-SHIP** Ship type match | 0.25 | Actor name normalizes to the SDE type name of attacker `shipTypeId`. |
| **S-WEAP** Weapon consistency | 0.20 | A weapon seen on that actor's incoming events resolves to attacker `weaponTypeId`, or shares its SDE group. |
| **S-DMG** Damage proportion | 0.20 | Ratio of `incomingBySource[actor]` to `attacker.damageDone` within tolerance (§2.3). |
| **S-TIME** Final-blow timing | 0.15 | Attacker has `finalBlow == true` and the actor dealt the last incoming damage event. |
| **S-SOLE** Uniqueness bonus | 0.10 | Exactly one player attacker and exactly one player log actor (§2.4). |

Confidence is the clamped sum, thresholded per §2.5.

- **R2.2.1** Weights MUST be named constants in one place (following M3's R1.3).
- **R2.2.2** A pair MUST NOT be correlated on S-DMG alone. Damage proportion is
  corroborating evidence, never primary — two attackers can deal similar damage.
- **R2.2.3** S-NAME is the only signal sufficient alone to reach `confirmed`.

### 2.3 Damage proportion tolerance

The log records damage **as the client displayed it**; the killmail records damage as the
server computed it. They differ legitimately — the log may start mid-fight, and killmail
damage includes hits from before the user's log began.

- **R2.3.1** Compare ratios, not absolutes: `min(a,b)/max(a,b)` on
  `incomingBySource[actor]` vs `attacker.damageDone`.
- **R2.3.2** Award S-DMG at ratio ≥ 0.60. Award half weight at ≥ 0.35.
- **R2.3.3** A mismatch MUST NOT subtract confidence — a partial log is expected, not
  evidence against a match.

### 2.4 The 1v1 shortcut

When the killmail has exactly one player attacker and the log has exactly one `player`
actor, S-SOLE applies. Combined with any second signal this clears `confirmed`.

- **R2.4.1** S-SOLE MUST NOT apply when NPC attackers are present alongside the single
  player attacker unless the log actor is classified `player`.

### 2.5 Confidence bands and assignment

| Band | Threshold | Meaning |
| --- | --- | --- |
| `confirmed` | ≥ 0.75 | Name match, or strong multi-signal agreement |
| `probable` | ≥ 0.50 | Multiple corroborating signals, no name |
| `possible` | ≥ 0.30 | One weak signal; shown but not relied upon |
| *(none)* | < 0.30 | Not correlated |

Assignment is **globally one-to-one and greedy by descending confidence**: the
highest-confidence pair is fixed first, both participants are removed from the pool, and
scoring repeats.

- **R2.5.1** One log actor MUST map to at most one killmail attacker, and vice versa.
- **R2.5.2** When two pairs tie within a 0.10 ambiguity margin (mirroring
  `CombatKillmailMatcher.ambiguityMargin`), **neither** is assigned; both drop to
  `Unattributed` with reason `ambiguous`.
- **R2.5.3** Assignment MUST be deterministic. Ties at equal confidence break by
  descending `damageDone`, then ascending `characterId`, so results never depend on map
  iteration order.

### 2.6 The Unattributed bucket

- **R2.6.1** Log damage from actors correlating to nothing above threshold MUST be
  reported as `unattributedIncomingDamage`, never distributed across attackers.
- **R2.6.2** Killmail attackers with no log actor MUST be listed as
  `uncorrelatedAttackers` — they are real (the killmail proves it) but absent from the
  user's log, which is normal for attackers who engaged outside the log window.
- **R2.6.3** Damage from `npc`-classified actors MUST be reported separately as
  `npcIncomingDamage` (S5).
- **R2.6.4** These three totals plus all correlated damage MUST equal
  `totalDamageReceived` exactly. This is an arithmetic invariant, tested by T3.6.

---

## 3. Data models and enrichment state

All new types live in `lib/features/combat_analyzer/domain/`.

### 3.1 New types

```
enum CombatActorClass { player, npc, shipType, ambiguous }

enum AttackerCorrelationConfidence { confirmed, probable, possible }

enum UncorrelatedReason { belowThreshold, ambiguous, npcActor, noLogPresence }

class CombatLogActor {
  final String displayName;          // as it appeared in the log
  final CombatActorClass actorClass;
  final int damageDealt;             // from incomingBySource
  final List<String> weaponNames;    // distinct weapons seen
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int? resolvedTypeId;         // when classified npc/shipType
}

class CorrelatedAttacker {
  final CombatLogActor actor;
  final EsiKillmailAttacker attacker;
  final AttackerCorrelationConfidence confidence;
  final double score;
  final List<String> signals;        // e.g. ['name match', 'ship type match']
}

class AttackerCorrelation {
  final List<CorrelatedAttacker> correlated;
  final List<CombatLogActor> unattributedActors;
  final List<EsiKillmailAttacker> uncorrelatedAttackers;
  final int unattributedIncomingDamage;
  final int npcIncomingDamage;
  final Map<String, UncorrelatedReason> reasons;
  final DateTime correlatedAt;
}
```

- **R3.1.1** `CorrelatedAttacker.signals` MUST name every signal that fired, so the UI
  can show the basis without recomputation (mirrors M2's inspectable-derivation rule).
- **R3.1.2** `AttackerCorrelation` MUST be JSON round-trippable, following the existing
  hand-written `toJson`/`fromJson` convention in this feature (these domain classes are
  plain Dart, not freezed — match the surrounding code).

### 3.2 Enrichment integration

`CombatEnrichment` gains one nullable field:

```dart
final AttackerCorrelation? attackerCorrelation;
```

- **R3.2.1** It MUST be nullable and absent-tolerant. Cached enrichments written before
  this milestone deserialize with `null` and MUST NOT error (R5.2).
- **R3.2.2** It MUST be included in `toJson`/`fromJson` and `copyWith`.
- **R3.2.3** Correlation MUST run inside `CombatEnrichmentService` after
  `_withResolvedNames()` (so names are available) and be persisted by `_save()`.
- **R3.2.4** Correlation MUST NOT trigger new network calls (R5.3).

### 3.3 Evidence ledger facts

Each correlated attacker emits a `CombatEvidenceFact`:

- `id`: `ev-correlated-attacker-{killmailId}-{characterId}`
- `source`: `EvidenceSource.killmail`
- `confidence`: `proven` for `confirmed`, `derived` for `probable`, `reference` for
  `possible`
- `value`: e.g. `Artem S3 (Hurricane) — 4,200 damage — name match, ship type match`

An `AarUnknown` is emitted per unattributed bucket with category
`AarUnknownCategory.opponentFit` (for uncorrelated attackers) or `telemetry` (for
unattributed log damage).

---

## 4. Impact on evidence assessment and matchups

### 4.1 What legitimately changes

The brief asks how correlation elevates Opponent Identity to Complete and Opponent Fit to
Inferred/Complete. Having read the shipped scorer, the honest answer is **narrower than
the brief assumes**, and I want to be explicit rather than overstate it.

`AarEvidenceScorer.opponentIdentity()` (`aar_evidence_scorer.dart:191`) already returns
`complete` whenever a killmail matched at ≥ 0.8 confidence. In that common case
**correlation cannot elevate it — it is already Complete.** Correlation improves the
*detail text*, not the status.

Where it genuinely changes the score:

- **D3 Opponent Identity — `ambiguous` → `partial`+.** When the killmail match was
  ambiguous but correlation confirms a specific attacker by name, identity is better
  established than the ambiguous match alone implies.
- **D3 — multi-attacker detail.** Complete-but-blended becomes Complete-and-enumerated.

### 4.2 The asymmetry Arch must not paper over

`opponentFit()` (line 240) derives the opponent fit from the **victim's** destroyed fit on
the matched killmail. That works when the *opponent lost*. In the user's-loss case (S2,
S3), the victim is the user — and **killmails do not expose attacker fittings at all**.
`CombatEnrichment.fromKillmail` already records exactly this as a standing unknown
(`combat_enrichment.dart`: "Killmails do not expose full attacker fittings.").

**So correlation cannot elevate Opponent Fit on a loss.** It identifies *who* attacked
and *what hull* they flew; it cannot reveal their modules. Claiming otherwise would
manufacture the confident-but-wrong output this project deleted the Pathfinder mock over.

- **R4.2.1** Correlation MUST NOT change D4 Opponent Fit status when the user is the
  killmail victim.
- **R4.2.2** A correlated attacker's known `shipTypeId` MAY be surfaced as ship identity,
  and MUST be labelled as hull-only, not a fit.
- **R4.2.3** When the user is the *attacker* and the opponent is the victim, D4 behaviour
  is unchanged from Milestone 3 — the destroyed fit already drives it.

### 4.3 Matchup impact

Per §1.4, V1 does not re-derive the matchup per attacker. Correlation adds attribution
*around* the existing aggregate.

- **R4.3.1** `CombatDamageMatchupAnalyzer` behaviour MUST be unchanged in V1.
- **R4.3.2** When ≥ 2 attackers correlate, the matchup section MUST display an advisory
  that the incoming profile is a blend across attackers and the named resist hole is
  therefore aggregate (§1.1's real cost, surfaced honestly rather than fixed).
- **R4.3.3** The per-attacker split is queued as follow-up (§10).

---

## 5. Compatibility rules

- **R5.1** Prompt schema v4 changes are **additive only**. A new optional
  `attackerCorrelation` block may be added; no existing field changes shape. Guarded by
  the existing prompt tests.
- **R5.2** Enrichments cached before this milestone MUST load without error and present
  as "not correlated", never as "zero attackers".
- **R5.3** Correlation MUST NOT introduce network I/O.
- **R5.4** Correlation failure MUST be non-fatal: on exception, log at `Log.e`, persist
  `null` correlation, and leave the rest of enrichment intact.
- **R5.5** Per CLAUDE.md, all new public methods log with tag `[COMBAT.CORRELATE]`;
  the correlation outcome logs at `Log.i` with per-pair scores and signals (M3's R6.2
  precedent — a user asking "why is this attacker unattributed?" must be answerable from
  logs).

---

## 6. User scenarios

### S1 — 1v1 solo kill (user is the attacker)

User kills a Rifter solo. Killmail: one attacker (the user), victim Rifter with a
destroyed fit. Log: one actor, `Vex Kalari`, matching the victim's name.

Correlation confirms the victim actor by name (S-NAME 0.60 + S-SOLE 0.10 + S-DMG 0.20 =
`confirmed`). Opponent Fit stays Complete/Inferred from the destroyed fit as in
Milestone 3. The user sees "Vex Kalari (Rifter) — confirmed".

**Acceptance.** AC1.1, AC2.1, AC4.3.

### S2 — 1v1 loss with multiple attackers on the killmail

User dies. Killmail lists three attackers; the log shows two actors by name and one
`shipType` actor ("Sabre").

- Two correlate at `confirmed` via S-NAME.
- The Sabre actor correlates at `probable` via S-SHIP + S-DMG, capped by R2.1.3.
- The third killmail attacker (who engaged before the log window) appears under
  `uncorrelatedAttackers`.

Opponent Fit stays unchanged per R4.2.1 — the user is the victim, so no attacker fits
exist. The UI shows three identified attackers with badges and states that fits are not
available for attackers.

**Acceptance.** AC1.2, AC2.2, AC3.2, AC4.1, AC5.2.

### S3 — Fleet engagement

Twelve killmail attackers, seven log actors. Four correlate `confirmed`, two `probable`,
one is `ambiguous` under R2.5.2 and drops to unattributed. Five killmail attackers never
appear in the log.

The UI lists correlated attackers sorted by damage, collapses the uncorrelated list
behind "5 attackers not present in your combat log", and shows the unattributed damage
total. The matchup advisory (R4.3.2) fires.

**Acceptance.** AC1.3, AC2.3, AC3.3, AC5.3, AC6.2.

### S4 — Third-party damage

A third party lands mid-fight and contributes damage. Their actor appears in the log but
they are not on the killmail (they didn't land a final blow on anything). Their damage
lands in `unattributedIncomingDamage` with reason `noLogPresence`'s inverse — a log actor
with no killmail counterpart.

The user sees "1,100 damage from Kite Mondeo — not on the killmail", which is the correct
and useful answer: someone shot them who isn't recorded on this kill.

**Acceptance.** AC1.4, AC3.4, AC6.1.

### S5 — NPC and player damage mixed

User fights a player while rats shoot them. Log actors: `Artem S3` (player) and
`Serpentis Watchman` (NPC). Killmail lists the player plus an NPC corporation attacker.

Classification (§2.1) marks the Watchman `npc`. Its damage goes to `npcIncomingDamage`
and is **never** correlated to the player attacker (R2.1.2). The UI separates "NPC
damage: 1,400" from player attackers.

This is the scenario that justifies the classification stage: without it, S-DMG and
S-TIME could plausibly bind `Serpentis Watchman` to a player attacker.

**Acceptance.** AC1.5, AC2.4, AC3.5, AC6.3.

### S6 — No killmail

Log-only encounter. No correlation runs; `attackerCorrelation` stays null. The UI shows
log actors with no correlation badges and no implication that correlation failed.

**Acceptance.** AC1.6, AC5.4.

---

## 7. UI affordances

### 7.1 Attacker list

A new `AarAttackerCorrelationSection` in
`lib/features/combat_analyzer/presentation/widgets/`, rendered in the AAR multi-pane
screen below the existing matchup section.

```
┌──────────────────────────────────────────────────────────┐
│ Attackers                        3 identified · 1 unknown │
├──────────────────────────────────────────────────────────┤
│ [icon] Artem S3            Hurricane      4,200  ✓ Confirmed│
│        name match, ship type match, damage proportion     │
│ [icon] Kite Mondeo         Jackdaw        3,100  ✓ Confirmed│
│        name match, final blow timing                      │
│ [icon] Sabre               Sabre          1,100  ~ Probable │
│        ship type match, damage proportion                 │
├──────────────────────────────────────────────────────────┤
│ NPC damage                                       1,400    │
│ Unattributed                                       200    │
│ ▸ 5 attackers not present in your combat log             │
└──────────────────────────────────────────────────────────┘
```

### 7.2 Confidence badges

Reuse `EveColors`, matching `aar_derived_stats_panel.dart`:

| Confidence | Icon | Colour |
| --- | --- | --- |
| `confirmed` | `Icons.check_circle` | `EveColors.success` |
| `probable` | `Icons.help_outline` | `EveColors.warning` |
| `possible` | `Icons.warning_amber` | `EveColors.warning` |
| uncorrelated | `Icons.remove_circle_outline` | `EveColors.textSecondary` |

- **R7.2.1** Every correlated row MUST show its signal list (R3.1.1) as secondary text.
- **R7.2.2** Ship names MUST resolve via `itemNameProvider` with `.when()`, never raw
  IDs (CLAUDE.md pitfall 1 and 4).
- **R7.2.3** `AsyncValue` MUST use `.when(data:, loading:, error:)`.

### 7.3 Honest empty and partial states

- **R7.3.1** When correlation is null (S6, or pre-milestone cache), the section MUST NOT
  render an empty attacker list implying zero attackers. It renders log actors plainly
  with no badges.
- **R7.3.2** Uncorrelated killmail attackers MUST be reachable (collapsed list), never
  hidden entirely — they are proven participants.
- **R7.3.3** The section MUST state that attacker fits are unavailable on a loss
  (R4.2.2), so a user does not read "Hurricane" as a known fit.

---

## 8. Acceptance criteria

### AC1 — Correlation correctness

- **AC1.1** S1: single player actor and attacker correlate at `confirmed`.
- **AC1.2** S2: two name matches at `confirmed`; ship-type actor at `probable`, never
  `confirmed` (R2.1.3).
- **AC1.3** S3: correlation is one-to-one; no attacker or actor appears twice (R2.5.1).
- **AC1.4** S4: a log actor absent from the killmail lands in unattributed, not forced
  onto an attacker.
- **AC1.5** S5: NPC actors are never correlated to player attackers (R2.1.2).
- **AC1.6** S6: with no killmail, correlation is null and no error is raised.
- **AC1.7** Assignment is deterministic across 100 runs on identical input (R2.5.3).
- **AC1.8** Ambiguous ties within 0.10 assign neither (R2.5.2).

### AC2 — Classification

- **AC2.1** Every log actor receives exactly one `CombatActorClass`.
- **AC2.2** A name matching a resolved attacker classifies `player`.
- **AC2.3** A name resolving to an SDE NPC type classifies `npc`.
- **AC2.4** NPC damage is reported in `npcIncomingDamage`, separate from unattributed.
- **AC2.5** Classification runs before correlation (R2.1.1).

### AC3 — Damage accounting

- **AC3.1** Correlated + unattributed + NPC damage == `totalDamageReceived` exactly
  (R2.6.4).
- **AC3.2** Uncorrelated killmail attackers are listed, not dropped (R2.6.2).
- **AC3.3** A damage-ratio mismatch never reduces confidence (R2.3.3).
- **AC3.4** Unattributed damage is never distributed across attackers (R2.6.1).
- **AC3.5** NPC damage never counts toward a player attacker's total.

### AC4 — Evidence assessment

- **AC4.1** D4 Opponent Fit is unchanged when the user is the victim (R4.2.1).
- **AC4.2** D3 detail text enumerates correlated attackers when ≥ 1 correlates.
- **AC4.3** D3/D4 behaviour is unchanged when the user is the attacker (R4.2.3).
- **AC4.4** A correlated attacker's hull is labelled hull-only, never a fit (R4.2.2).
- **AC4.5** Evidence facts are emitted per correlated attacker with confidence mapped
  per §3.3.

### AC5 — Compatibility

- **AC5.1** Pre-milestone cached enrichments load with null correlation, no error
  (R5.2).
- **AC5.2** Prompt v4 existing fields are byte-identical for the same input (R5.1).
- **AC5.3** No new network calls during correlation (R5.3).
- **AC5.4** Correlation failure leaves the rest of enrichment intact (R5.4).
- **AC5.5** All existing combat_analyzer tests pass unchanged; `flutter analyze` clean.

### AC6 — UI

- **AC6.1** Correlated attackers render with badge, ship name, damage, and signal list.
- **AC6.2** Uncorrelated attackers are collapsed but reachable (R7.3.2).
- **AC6.3** NPC and unattributed damage render as distinct rows.
- **AC6.4** Null correlation renders plain actors with no badges (R7.3.1).
- **AC6.5** Ship names resolve via `itemNameProvider` with `.when()` (R7.2.2).
- **AC6.6** The multi-attacker matchup advisory renders when ≥ 2 correlate (R4.3.2).

---

## 9. Test groups

Following the M2/M3 layering: pure unit → wiring → UI.

### Group A — Classification (pure unit)

`test/features/combat_analyzer/domain/combat_actor_classifier_test.dart`

- **T1.1** `Artem S3` with a matching attacker name → `player`.
- **T1.2** `Serpentis Watchman` resolving to an NPC SDE type → `npc`.
- **T1.3** `Sabre` resolving to a ship type, fight has player attackers → `shipType`.
- **T1.4** Unresolvable name, no attacker match → `player` (default per §2.1).
- **T1.5** Name matching both an SDE type and an attacker → `ambiguous`, treated `player`.
- **T1.6** Classification uses exact normalized match, not substring (guards against
  `Sabre` matching `Sabre Fleet Issue`).
- **T1.7** Empty/`Unknown` actor names are excluded.

### Group B — Signal scoring (pure unit)

`test/features/combat_analyzer/domain/attacker_correlator_signals_test.dart`

- **T2.1** S-NAME alone reaches `confirmed` (R2.2.3).
- **T2.2** S-DMG alone does not correlate (R2.2.2).
- **T2.3** S-SHIP + S-DMG reaches `probable`, not `confirmed`.
- **T2.4** S-DMG awards full weight at ratio 0.60, half at 0.35, none at 0.20.
- **T2.5** A damage mismatch does not subtract (R2.3.3).
- **T2.6** S-TIME fires only for the final-blow attacker and last incoming event.
- **T2.7** S-SOLE fires for 1 player attacker + 1 player actor.
- **T2.8** S-SOLE does not fire when an NPC attacker is present with a non-player actor
  (R2.4.1).
- **T2.9** S-WEAP fires on exact weapon type and on shared SDE group.
- **T2.10** Weights are named constants summing as documented (R2.2.1).

### Group C — Assignment and accounting (pure unit)

`test/features/combat_analyzer/domain/attacker_correlator_test.dart`

- **T3.1** Greedy descending assignment picks the highest pair first.
- **T3.2** One-to-one enforced both directions (R2.5.1).
- **T3.3** Ties within 0.10 assign neither (R2.5.2).
- **T3.4** Deterministic across 100 runs, including tie-break order (R2.5.3).
- **T3.5** Sub-threshold pairs land in unattributed with `belowThreshold`.
- **T3.6** **Damage invariant:** correlated + unattributed + NPC == `totalDamageReceived`
  (R2.6.4).
- **T3.7** Uncorrelated attackers listed with `noLogPresence`.
- **T3.8** NPC damage bucketed separately (R2.6.3).
- **T3.9** Empty killmail attacker list → all actors unattributed, no crash.
- **T3.10** Empty log actors → all attackers uncorrelated, no crash.

### Group D — Scenario fixtures (pure unit)

`test/features/combat_analyzer/domain/attacker_correlation_scenarios_test.dart`

- **T4.1** S1 1v1 kill.
- **T4.2** S2 loss, three attackers, one ship-type actor.
- **T4.3** S3 fleet, 12 attackers / 7 actors.
- **T4.4** S4 third party absent from killmail.
- **T4.5** S5 NPC + player mixed.
- **T4.6** S6 no killmail → null correlation.

### Group E — Enrichment integration

`test/features/combat_analyzer/data/combat_enrichment_service_test.dart` (extend)

- **T5.1** Correlation runs after `_withResolvedNames()` and is persisted (R3.2.3).
- **T5.2** Round-trips through `toJson`/`fromJson` (R3.1.2).
- **T5.3** Pre-milestone JSON without the field loads with null (R5.2, AC5.1).
- **T5.4** No new network calls — mock ESI client records zero extra calls (R5.3).
- **T5.5** Thrown correlation error is caught; enrichment otherwise intact (R5.4).
- **T5.6** Evidence facts emitted per correlated attacker (AC4.5).

### Group F — Evidence assessment

`test/features/combat_analyzer/domain/aar_evidence_dimensions_test.dart` (extend)

- **T6.1** D4 unchanged when user is victim, even with confirmed correlations (R4.2.1).
- **T6.2** D3 detail enumerates correlated attackers.
- **T6.3** D3/D4 unchanged when user is attacker (R4.2.3).
- **T6.4** Completeness score is unchanged by correlation in the victim case — guards
  against accidentally inflating the M3 score.
- **T6.5** All Milestone 3 scorer tests still pass unchanged.

### Group G — Prompt compatibility

`test/features/combat_analyzer/data/combat_analysis_service_test.dart` (extend)

- **T7.1** Existing v4 fields byte-identical for the same input (R5.1, AC5.2).
- **T7.2** The correlation block is additive and omitted when null.

### Group H — UI

`test/features/combat_analyzer/presentation/aar_attacker_correlation_section_test.dart`

- **T8.1** Correlated rows render badge, ship, damage, signals.
- **T8.2** Confidence badge colours map per §7.2.
- **T8.3** Uncorrelated list collapsed but expandable (R7.3.2).
- **T8.4** NPC and unattributed rows render distinctly.
- **T8.5** Null correlation renders plain actors, no badges, no "0 attackers" (R7.3.1).
- **T8.6** Ship names use `itemNameProvider` with `.when()`; no raw `Type #` in the happy
  path (R7.2.2).
- **T8.7** Loading and error states handled via `.when()` (R7.2.3).
- **T8.8** Multi-attacker matchup advisory renders at ≥ 2 correlated (R4.3.2).
- **T8.9** Attacker-fits-unavailable note renders on a loss (R7.3.3).

### Group I — Logging

- **T9.1** Correlation logs at `Log.i` with tag `[COMBAT.CORRELATE]`, including per-pair
  scores and signals (R5.5).

---

## 10. Decisions for Arch

### D1 — Where does correlation run? **Recommend: `domain/` pure, called from the service.**

The correlator needs SDE lookups for classification, which is I/O. Recommend the pattern
Milestone 2 used for `CombatFitDeriver`: a pure `domain/` correlator taking pre-resolved
type data, with the service doing the SDE resolution and passing it in. Keeps Groups A–D
runnable without a Flutter binding (AC1.7's 100-run determinism test needs this).

### D2 — Should classification cache SDE lookups? **Recommend: yes, per-encounter.**

A fleet fight has many actors and repeated names. A simple per-call memo on normalized
name is sufficient; no persistent cache needed.

### D3 — Re-run correlation on cached enrichments? **Recommend: lazily, on next load.**

Pre-milestone enrichments have null correlation. Options: backfill-on-migration, or
correlate on next load when null and a killmail exists. Recommend the latter — no
migration, and the cost is one correlation pass. Arch should confirm this does not
trigger a write amplification problem in `_save()`.

### D4 — Per-attacker matchup split? **Recommend: not in V1 (§1.4).**

It is the natural follow-up and the real fix for §1.1's blended-profile problem, but it
requires splitting the incoming damage profile by actor and re-running the matchup per
attacker, which touches Milestone 2's shipped derivation path. Ship correlation first,
then split with correlation data proven. Queued in §11.

---

## 11. Journal protocol on ship

- Move the QUEUED P2 entry "Correlate zKill attackers with combat-log actors" to
  `ARCHIVE.md` as SHIPPED, noting the revised effort (§0.4) and that the actor
  classification stage was not anticipated in the original entry.
- Record a LEARNINGS entry for §0.1: **EVE combat logs name the displayed entity, not the
  pilot** — an NPC ship type and a player character name occupy the same field with no
  marker distinguishing them. Any future feature joining log actors to external data must
  classify before matching. This is the milestone's most reusable finding.
- Record a LEARNINGS entry for §4.2: killmails expose victim fits only, so attacker fit
  derivation is impossible on a loss regardless of correlation quality. This bounds the
  "Fit comparison visuals" QUEUED entry.
- Queue as P2: per-attacker damage profile split and per-attacker matchup (D4, §1.4).
- Queue as P3: using correlated attacker ship types to seed reference fits for attacker
  hulls, clearly labelled as reference rather than evidence.

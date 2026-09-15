# Milestone 5: Per-Attacker Incoming Damage Profile and Defense Matchup

**Status.** Product specification complete; ready for technical design. Implementation pending.
**Author.** Product.
**Date.** 2026-09-14.
**Priority.** P2.
**Baseline.** Milestone 4 merged through `d2dd731`.
**Dependencies.** Shipped fit derivation, evidence completeness, and attacker correlation.

This document defines the product contract for Milestone 5. MUST denotes a release
requirement. Examples use synthetic damage inputs; a hull name alone never establishes
its ammunition or damage split.

### Grounding and authority

| Source | Contract used here |
| --- | --- |
| [Milestone 4 product spec](aar-zkill-attacker-correlation.md), §0.2, §1.1, D4 | Incoming events already identify displayed source actors; splitting matchups was deliberately deferred. |
| [Milestone 4 design](aar-zkill-attacker-correlation-design.md), §0, §2, §10 | Corrected confidence rules, victim-inclusive participant pool, NPC partition, and deferred drone ownership. These corrections supersede the earlier product spec's scoring examples. |
| [Correlation domain](../../lib/features/combat_analyzer/domain/combat_attacker_correlation.dart) | Actor/participant identities, Confirmed/Probable/Possible bands, and scalar accounting. |
| [Damage profile resolver](../../lib/features/combat_analyzer/data/combat_damage_profile_resolver.dart) | Exact normalized weapon-name lookup in SDE; logged amounts weight the resolved type attributes. Unknown weapons are excluded from typed components. |
| [Damage matchup](../../lib/features/combat_analyzer/domain/combat_damage_matchup.dart) and [damage pattern](../../lib/features/fitting/domain/damage_pattern.dart) | Resist classification, modeled pressure, and layered weighted EHP. |
| [Fit deriver](../../lib/features/combat_analyzer/domain/combat_fit_deriver.dart) and [derivation service](../../lib/features/combat_analyzer/data/combat_fit_derivation_service.dart) | Reusable pilot defense, skill assumptions, tank layer, evidence precedence, and limitations. |
| [Matchup widget](../../lib/features/combat_analyzer/presentation/widgets/aar_matchup_section.dart) and [providers](../../lib/features/combat_analyzer/data/combat_providers.dart) | Current aggregate matchup and advisory when at least two participants correlate. |
| [Queued work](../engineering-journal/QUEUED.md#per-attacker-incoming-damage-profile-and-matchup) | Milestone 5 scope; separate follow-ups for reference fits, drone ownership, and application simulation. |

## 1. Product Perspective & Problem Statement

### 1.1 The misleading fleet blend

A pilot loses to Kite Mondeo in a Jackdaw and Artem S3 in a Hurricane. Their logged
weapons imply different damage mixes: EM/Kinetic missiles and Explosive/Kinetic
projectiles. The current AAR combines these into one incoming profile, then names a
resist hole and computes EHP against that combined profile.

An aggregate such as 35% EM, 25% Thermal, 20% Kinetic, and 20% Explosive can describe a
fight's overall estimated composition. It does not describe a particular attacker.
It cannot answer whether the Jackdaw pressured the pilot's EM weakness or whether the
Hurricane was hitting a stronger defense. That illustrative four-type blend would
also require Thermal-bearing evidence; the two example mixes alone cannot produce it.

The aggregate calculation is useful as a labeled reference. The misleading claim is
assigning its result to an individual attacker. Fleet composition and each attacker's
logged contribution change the aggregate EHP even when the pilot's fit and every
individual attacker's profile stay unchanged. EHP is nonlinear: an average of attacker
EHP values is not EHP against their combined profile.

Milestone 4 solved identity correlation and exposed an aggregate-blend advisory. This
milestone uses that correlation to separate the damage and defense comparisons.

### 1.2 Governing principle

> **Every attributed claim must name the specific attacker it concerns. Defense
> calculations must reflect that attacker's actual applied weapon profile, using only
> that attacker's logged incoming events and explicit evidence limitations.**

Here, “actual applied weapon profile” means the observed weapon mix, weighted by the
damage amounts recorded in the pilot's log. The log does not measure four separate
damage-type amounts per hit. Mimir estimates those components from the exact logged
weapon/ammunition type's SDE attributes. These are **SDE-derived estimates weighted by
logged damage**, not recovered pre-resistance volleys or measured post-resistance
damage by type. Identity confidence, weapon resolution, and fit provenance are separate.

The product must answer: **Who dealt this damage, what typed profile can we establish,
and how does my recorded fit compare against that profile?** An unknown remains visible
where any part of that chain lacks evidence.

### 1.3 User outcome and release boundary

The Damage tab provides a complete incoming overview plus inspectable matchups for
eligible attackers, without requiring AI analysis. The user can compare two attackers
while seeing how much incoming damage has uncertain identity or unresolved types.
This specification changes incoming profile derivation and its consumers. It preserves
Milestone 4 identity scoring and the existing pilot-fit selection policy.

## 2. User Scenarios

### S1 — Solo engagement

One Confirmed attacker deals all 4,000 logged incoming damage. Every logged weapon
resolves. Its canonical four-type vector, normalized split, modeled EHP, and primary
hole MUST equal the Aggregate Overview's defense reference using the same pilot fit.
The sole attacker card opens automatically. No multi-source blend advisory appears.
If some weapons are unresolved, both views show identical partial coverage; neither
claims to represent the attacker's complete profile.

### S2 — Fleet loss with distinct weapon types

Kite Mondeo (Jackdaw, Confirmed) deals 6,000 damage: 75% EM and 25% Kinetic. Artem S3
(Hurricane, Probable) deals 4,000: 25% Kinetic and 75% Explosive. These are explicit
synthetic weapon-event fixtures, not hull defaults or a claim about a single missile.
The Jackdaw mix may span ammunition changes during the encounter.

| Source | Logged damage | Share of all incoming | EM | Thermal | Kinetic | Explosive |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Kite Mondeo | 6,000 | 60% | 4,500 | 0 | 1,500 | 0 |
| Artem S3 | 4,000 | 40% | 0 | 0 | 1,000 | 3,000 |
| Aggregate | 10,000 | 100% | 4,500 | 0 | 2,500 | 3,000 |

The pilot sees two cards, 75/0/25/0 and 0/0/25/75. Each independently compares with the
same pilot defense. No card uses the aggregate 45/0/25/30 split. The quantitative
oracle in §7.1 yields different EHP and hole results for the two attackers.

### S3 — Fleet fight with Unattributed and NPC components

The fight contains a Confirmed player, a Possible player correlation, an unknown source,
and a classified NPC. The Confirmed player's card is available if it has typed damage.
The Possible actor appears under **Unattributed for matchup**, with its existing
Possible candidate visible only as correlation evidence. NPC damage has its own bucket.

All positive incoming events contribute exactly once to the overview. Both residual
buckets may contain resolved four-type components and untyped damage. Neither produces
a named player EHP or hole claim. A classified NPC with an unknown weapon contributes
to **NPC + untyped**, not to a second Unattributed amount. A player absent from the
killmail remains Unattributed even if their displayed name looks like a pilot name.

### S4 — Kill engagement: the pilot won

The pilot appears among the killmail attackers and the defeated victim fired back.
Milestone 4 can correlate that incoming actor with the victim participant. Mimir shows
**Your defense vs Vex Kalari (Rifter)** using Vex's incoming log events and the pilot's
fit. `isVictim` does not disqualify the opposing participant.

The user's outgoing damage and the victim's `damageTaken` never supply this incoming
profile. A victim participant has no killmail `damageDone`; it is not needed. The
existing **Your outgoing damage vs Vex Kalari's defense** comparison remains separate.
If the pilot's own fit is missing, the incoming card still shows identity and profile
with EHP unavailable, even when the defeated victim's full fit is available.

### S5 — Mixed weapons, ammunition changes, or drones

One eligible actor's incoming events include a missile weapon dealing 600 damage and a
drone weapon dealing 400. Both resolve. Mimir weights their type ratios 60:40, rather
than averaging weapon names, counting hits, or using theoretical weapon DPS. Multiple
ammunition types observed during the fight contribute with their own logged amounts.

The expanded card lists each observed weapon contribution and unresolved remainder.
Drone weapon events already attached to that correlated actor can participate normally.
A separately displayed drone actor is not merged into the pilot because a hull or
killmail weapon could use that drone. M5 consumes existing valid correlation evidence
with its confidence intact; it introduces no new launching-pilot inference. Otherwise
the separately displayed actor stays in the appropriate residual bucket.

## 3. Behavioral Rules & Invariants

### 3.1 Event ownership and perspective

- **R1 — Event source.** Include positive `isIncomingDamage` events from this parsed
  encounter only. On incoming events, `CombatEvent.targetName` is the source actor.
  Exclude outgoing damage, misses, zero amounts, repairs, capacitor events, and e-war.
  Log amounts are authoritative for totals and weights; killmail `damageDone` only
  supports the existing correlation process.
- **R2 — Exactly one owner.** Partition each event once by its recorded source actor,
  retaining raw display-name provenance. Consume Milestone 4's assignment and final
  confidence band. Do not re-score identities, join actors merely by hull, or assign
  unlogged killmail damage to make numbers agree.
- **R3 — Aliases and stale inputs.** Raw parser source keys and normalized correlation
  keys are different: trim/case/whitespace variants can collide. An unambiguous raw
  actor match takes precedence; normalized fallback is permitted only when unique.
  Never fan one event into multiple rows. Inconsistent actor totals, conflicting
  mappings, or a correlation from another encounter/killmail make affected attribution
  unavailable. Preserve events under Unattributed while deriving their types; report
  the mismatch and allow local refresh. Do not silently repair Milestone 4 identities.
- **R4 — Pilot defense.** Every incoming card uses `AarDerivationBundle.self`, with its
  existing fit precedence, known-character/All V skills, tank classification, and
  limitations. Derive it once for the snapshot and reuse it. The target never becomes
  the attacking ship. Correlation alone reveals no attacker fitting.

### 3.2 Confidence and eligibility

Confirmed, Probable, and Possible are correlation bands. Unattributed and NPC are
accounting categories. Use the shipped bands, not a new numeric score test that could
bypass the ship-type cap.

| Existing evidence | Accounting in M5 | Named incoming card | Numerical matchup |
| --- | --- | --- | --- |
| Confirmed, positive logged damage | Attributed attacker | Yes; Confirmed badge | When typed damage and usable pilot defense exist |
| Probable, positive logged damage | Attributed attacker | Yes; Probable badge and conditional wording | Same calculation, with identity uncertainty visible |
| Possible | Unattributed for matchup, subrow “Possible match” | No named defense card; preserve candidate details | No attacker EHP/hole claim |
| No assignment, ambiguous, unknown/empty name, absent from killmail | Unattributed for matchup | Raw source evidence only | No attacker EHP/hole claim |
| Classified NPC | NPC | NPC source breakdown only | No player or individual NPC matchup in M5 |
| Killmail participant without incoming log presence | Outside incoming accounting | “Not observed in this log” footer | None; no fabricated zero-damage matchup |
| Correlation unavailable/not performed | Unattributed, with locally established NPCs separate | Plain source rows with availability explanation | Aggregate reference only if profile/fit allow it |

- **R5 — Preserve M4 confidence.** Thresholds remain Confirmed ≥0.75, Probable ≥0.50,
  Possible ≥0.30; a `shipType` actor remains capped at Probable. M5 does not modify the
  stored correlation or its scalar totals when it applies its stricter display gate.
- **R6 — Profile coverage gate.** An eligible attacker with zero resolved damage gets
  a card explaining “Damage types unresolved” and no four-type percentages, EHP, or
  hole. Any positive resolved amount permits a partial-profile comparison: no arbitrary
  damage-share or coverage threshold hides evidence. If coverage is below 100%, every
  numerical comparison is labeled **Resolved portion only** with the covered amount
  and percentage. Zero coverage never defaults to omni or another attacker's profile.
- **R7 — Missing fit.** A usable profile does not depend on fitting availability.
  Missing/failed pilot fit leaves the card's amounts and type split visible, with
  “Pilot defense unavailable.” Unknown tank layer suppresses layer pressure and hole;
  layered EHP may remain available when valid HP and resists exist. Do not display zero
  EHP as a stand-in for unavailable data.

### 3.3 Damage resolution and exact conservation

Let `T` be total logged incoming damage. For each source bucket `b`, let `D_b` be its
logged total, `C_b,t` its canonical typed amount for `t ∈ {EM, Thermal, Kinetic,
Explosive}`, `K_b = Σ_t C_b,t` its resolved total, and `U_b` its untyped amount.

`A` is the set of Confirmed/Probable attacker buckets, `X` is Unattributed for matchup
(including Possible), and `N` is NPC. X and N can retain separate actor subrows.

```text
For each bucket: D_b = K_b + U_b = Σ_t C_b,t + U_b
For every type:  C_aggregate,t = Σ_(a in A) C_a,t + C_X,t + C_N,t
Untyped:        U_aggregate   = Σ_(a in A) U_a   + U_X   + U_N
All incoming:   T = Σ_(a in A) D_a + D_X + D_N
                 = Σ_t C_aggregate,t + U_aggregate
```

All amount equalities MUST hold **exactly**, before display formatting, with no
epsilon allowance for a dropped or duplicated damage unit. Unknown damage is an
explicit extra component; assigning it invented EM/Thermal/Kinetic/Explosive fractions
would violate the evidence contract even if a total happened to balance.

For a valid M4 snapshot, `D_X = unattributedIncomingDamage + Possible damage` and
`Σ D_a = correlatedIncomingDamage − Possible damage`. M4's `unattributedActors` list
also contains NPC actors: filter those out before deriving X or NPC is double-counted.
When R3 rejects stale attribution, derive M5 buckets from events and visibly mark the
rejection rather than claiming they reproduce that stale M4 partition.

- **R8 — Weapon evidence.** Resolve each distinct normalized logged weapon/ammunition
  name by exact SDE type match and positive damage attributes. Weight its ratio by
  logged damage for that source. Ship type, a turret/launcher group, a killmail's single
  weapon ID, doctrine, or an LLM guess cannot fill missing charge/type evidence. An
  unresolved weapon or absent/nonpositive attribute vector contributes its entire
  logged amount to U. A local lookup error is unavailable evidence, not a known zero.
- **R9 — Allocate once, retain fractions.** Build one canonical incoming component
  allocation and have aggregate and per-attacker consumers read it. Components are
  fractional estimates even though logged event totals are integers. Preserve those
  fractions through source allocation and aggregation using a lossless amount
  representation, such as exact rational quantities from the SDE attribute ratios.
  Architecture selects the representation; independently rounded integers or separately
  accumulated floating-point approximations do not satisfy the exact amount contract.
  Allocate before combining actors into X/N; group membership never changes a source's
  components. Normalize these same canonical components for EHP and pressure, converting
  to numerical calculation precision only at the formula boundary. One damage unit from
  an omni weapon remains 0.25 of each type and a 25/25/25/25 profile; rounding it to one
  EM unit would invent a weapon profile.
- **R10 — Rounding and legacy behavior.** The existing resolver independently rounds
  type entries and its total; that cannot guarantee conservation. M5 MUST replace this
  behavior for the incoming calculation path with R9. Round only at presentation or an
  explicitly separate legacy integer serialization boundary. If legacy fields require
  integers, use a deterministic projection (largest fractional remainder, ties in
  EM/Thermal/Kinetic/Explosive order); never feed that projection back into the canonical
  vector, matchup, or new evidence block. Differences from M4's rounding are permitted
  and must have regression fixtures. Solo equality concerns the new shared aggregate
  and per-source result. Outgoing profile behavior remains outside this change.
- **R11 — Denominators.** Damage share is `D_b / T`, including untyped and all residual
  damage in T. Coverage is `K_b / D_b`. The four-type split is `p_b,t = C_b,t / K_b`,
  summing to 1 when K is positive. Its denominator is resolved damage, never all
  incoming damage. For T=0 show the empty state; for K=0 omit the split. Keep fractional
  component precision until display formatting; displayed component amounts may carry
  decimals and must be marked as rounded when necessary. Negative/nonfinite inputs are
  invalid, not damage that can be silently clamped into a plausible profile.

### 3.4 Per-attacker EHP, resist assessment, and hole pressure

Reuse the existing mathematical definitions in `CombatDamageMatchupAnalyzer` and
`DefenseProfile.ehpAgainst`, evaluated separately for each eligible profile. The
implementation must ensure both consume the same canonical `p_a,t` (today profile
percentages and integer-amount normalization can differ).

For defense layer `l`, HP `H_l`, resist percentage `R_l,t`, and fraction `p_a,t`:

```text
q_a,l       = Σ_t p_a,t × (1 − R_l,t / 100)
EHP_a,l     = H_l / q_a,l                 when q_a,l > 0
EHP_a,total = EHP_a,shield + EHP_a,armor + EHP_a,hull
EHP_omni    = the same calculation with 25/25/25/25
```

- **R12 — EHP basis.** Show total layered EHP, with per-layer values inspectable. Use
  the same pilot-fit snapshot for every card and omni reference. Do not multiply EHP
  by attacker share, add attacker EHPs together, average them into aggregate EHP, or
  treat them as simultaneous survival time. Repairs, reloads, range, tracking,
  signature/application, overheat, and module-state changes during the fight are not
  added to this static comparison.
- **R13 — Numeric guard.** Preserve the shared engine's finite fallback `EHP_a,l = H_l`
  when `q_a,l <= 0`; mark that layer/result as a calculation limitation. Never present
  it as a physical invulnerability or resistance estimate. Reject invalid HP/resist
  inputs (negative HP, nonfinite values, resists outside 0–100) with an unavailable
  comparison. All-zero HP is unavailable. This milestone does not silently change
  the shared engine's guard semantics.

For the pilot's selected tank layer L, define mean resist `m = Σ_t R_L,t / 4`.
Classify a type as **hole** if `R_L,t <= 20` or `R_L,t <= m − 5`; otherwise **strong**
if `R_L,t >= m + 5`; otherwise **neutral**. Values are percentage points, matching the
shipped analyzer. The hole branch has precedence.

```text
w_a,t = p_a,t × (1 − R_L,t / 100)
pressure_a,t = w_a,t / Σ_t w_a,t           when the denominator is positive
```

- **R14 — Primary hole.** Among types with `p_a,t > 0` classified as holes, select the
  largest modeled pressure. Exact ties use EM, Thermal, Kinetic, Explosive. No qualifying
  type means **No resist hole pressured by this profile**. An absent damage type never
  wins just because it is the pilot's weakest resist. Unknown layer or zero pressure
  denominator means pressure and primary hole unavailable; do not expose the current
  analyzer's equal-share fallback as measured pressure.
- **R15 — Honest labels.** Pressure means **Modeled share after [layer] resists**.
  It is a comparison using an SDE-derived profile weighted by already-applied logged
  damage. It is not another measurement of actual damage taken. Replace the current
  incoming wording “% of damage taken” in this surface. A hole belongs to the pilot's
  defense against a named source; it is not a weakness of the attacker's ship.

### 3.5 Aggregate coexistence and lifecycle

- **R16 — Overview plus cards.** Always show the Aggregate Overview for positive
  incoming damage. It describes the encounter and includes X/N/U. A collapsed
  **Aggregate defense reference** may show EHP and hole against resolved aggregate
  components, explicitly labeled as a combined-source estimate. Named cards are the
  primary defense comparison. Single-source fights retain the compact overview but
  need not repeat the identical aggregate defense detail in an expanded panel.
- **R17 — Blend advisory.** When more than one positive logged source contributes,
  the aggregate reference says **Combined incoming profile; individual attackers can
  pressure different resists.** This includes one eligible attacker plus Possible,
  Unattributed, or NPC sources, even when fewer than two participants correlate.
  Unknown type coverage has its own warning. No combined-profile warning appears
  inside a named attacker's own matchup.
- **R18 — Reactive derivation.** Recompute from current local encounter events,
  correlation, SDE revision, pilot fit, skill basis, and module assumptions. Fit changes
  affect defense results; identity changes affect grouping/eligibility; weapon resolution
  affects coverage and vectors. Never show another encounter's or fit's stale numbers
  under the new identity. Resolve weapons once per distinct normalized name per
  snapshot, and reuse pilot defense; expanding a card triggers no analysis or refetch.
- **R19 — Failure scope.** Loading, unavailable, partial, and failed are distinct from
  zero. Name failures do not prevent numerical derivation. Correlation failure preserves
  plain source rows and aggregate typing; pilot-fit failure preserves profiles. A single
  unresolved weapon preserves other known components. If event totals themselves are
  inconsistent, withhold the quantitative bundle and explain the inconsistency rather
  than asserting conservation. Existing report/history and outgoing analysis remain usable.

## 4. UI/UX Requirements

### 4.1 Placement and interaction

Within **AAR → Damage → Incoming damage and your defense**, use one vertical list of
expandable source cards. The current correlated-attacker rows become the source headers
for these cards; preserve their correlation details and unmatched-participant footer.
Do not add a second competing ranking below the existing Incoming Sources/correlation
list. The incoming aggregate matchup moves into the labeled overview/reference.

```text
Incoming damage and your defense
  Aggregate Overview                        10,000 logged damage
  EM 45.0% · Thermal 0.0% · Kinetic 25.0% · Explosive 30.0%
  Typed coverage 100.0% · Attributed for matchup 100.0%
  Unattributed for matchup 0 · NPC 0 · Untyped 0
  ▸ Aggregate defense reference

  ▾ Kite Mondeo · Jackdaw · Confirmed         6,000 · 60.0% of incoming
    Your defense vs Kite Mondeo
    Profile 75.0 / 0.0 / 25.0 / 0.0 · Typed coverage 100.0%
    Your EHP vs Kite Mondeo 1,176 · Omni reference 1,333
    Primary resist hole vs Kite Mondeo: EM · Shield
    EM: 0.0% resist · Modeled share after shield resists 88.2%
    ▸ Weapons, correlation evidence, and fit assumptions

  ▸ Artem S3 · Hurricane · Probable          4,000 · 40.0% of incoming
  ▸ Unattributed for matchup                 [only when positive]
  ▸ NPC                                     [only when positive]
  ▸ Killmail participants not observed in this log

Your outgoing damage vs [victim]'s defense   [existing separate comparison]
```

The wireframe uses §7.1's synthetic shield-only defense, not real hull statistics.

- Sort attacker headers by logged damage descending, then normalized participant name,
  then stable participant identity. Residual X/N groups follow named sources. Keep
  observed raw actor names available as provenance, including “Logged as Sabre.”
- Open the largest eligible card initially, including the sole card in a solo fight.
  Allow multiple cards open for comparison. Preserve user expansion choices while
  viewing the same encounter; reset for a different encounter. No persisted preference,
  horizontal attacker tabs, or fixed multi-column fleet layout is required.
- Keep all contributors accessible in large fleets through a scrollable/lazy list.
  Do not silently drop low-damage actors or show an unexplained top-N total.

### 4.2 Card content and labels

| Field | Display requirement |
| --- | --- |
| Attacker identity | Prefer resolved participant character name. Resolve ship type with `itemNameProvider`; keep a resolved cached name during loading where available. Never show numeric character, item, ship, or skill IDs. |
| Missing name | “Character name unavailable” with “Logged as [actor]”; ship fallback “Unknown ship.” This is missing presentation data, not a new confidence band. Internal stable identity still scopes the card. |
| Confidence | Text badge Confirmed/Probable; expandable original signals. Probable comparison says “Assuming this actor is [name]” before numerical claims. A confidence badge never labels the whole damage/fit calculation as observed. |
| Damage contribution | Localized integer damage and percentage **of all logged incoming damage**. Tooltip/detail identifies the denominator. No killmail damage substitution. |
| Type split | Four labeled entries, EM / Thermal / Kinetic / Explosive, including zero components when K>0. Use consistent existing damage colors plus text; no color-only meaning. |
| Coverage | Resolved amount / actor total, percentage, and untyped remainder; label “SDE-derived from logged weapons.” Partial coverage stays visible above EHP, including in summary text. |
| EHP | “Your EHP vs [name]”; layered total rounded for display, per-layer detail, and same-fit omni reference. “Resolved portion only” qualifies partial profiles. |
| Resist hole | “Your primary [layer] resist hole vs [name]: [type]”, or the explicit no-hole/unavailable states from §3.4. Show resist percentage and modeled pressure in detail. |
| Weapon evidence | Each logged weapon, its logged damage/share of this actor, exact-SDE resolution status, type split if resolved, and source events/time span. Unknown entries retain their amounts. |
| Defense evidence | Pilot fit source and ship, known skills or All V basis, chosen tank layer, module-state assumptions, unresolved modules, and other existing derivation limitations. |

All displayed names, including those in evidence text, follow the repository's name
resolution rule. A name failure must not expose legacy `Type #…` fallback text through
a detail panel. Ship identity is a hull fact; preserve the explanation that killmails
do not expose attacker fittings.

### 4.3 Residuals, loading, and accessibility

- X/N headers show amount and encounter share, with typed coverage and four-type split
  in expanded details when available. X explains that Possible matches are included
  because identity is insufficient for a named matchup. Candidate details say “Possible
  match to [name]”; never “Damage dealt by [candidate]” as a settled fact.
- “Untyped” is a resolution subtotal spanning attacker/X/N buckets. Explain that it is
  already included in total incoming damage; it is not an additional attacker bucket.
- Use scoped loading indicators and Riverpod `.when()` handling. Missing data explains
  what is unavailable; retry is local and non-blocking. Fit import and user-initiated
  killmail search link to existing evidence-checklist actions instead of adding a new
  mandatory flow. No automatic zKill search or AI request occurs on opening the tab.
- Percentages display one decimal place. Display-only largest-remainder allocation to
  tenths makes a complete four-way split total 100.0%; calculations use original ratios.
  Independent contribution percentages may total 99.9/100.1 after rounding, with a
  rounding note in details. No UI value, bar, or denominator may become NaN/Infinity.
- At 360 logical pixels, labels wrap and metrics stack with no horizontal overflow.
  At desktop widths, the same card may arrange metrics side by side. Support keyboard
  focus, Enter/Space expansion, screen-reader names and expanded state, sufficient
  contrast, and 200% text scaling. Long character/weapon names remain accessible.
- Provide stable semantic/widget identifiers for overview, aggregate advisory, actor
  card, confidence, coverage, type split, EHP, hole, residual buckets, and error/empty
  states. Keys derive from encounter and stable actor/participant identity, not rank.

## 5. Evidence Ledger & Prompt Schema Considerations

### 5.1 Deterministic client-side derivations

**All amounts, splits, EHP, pressure, and primary-hole selection are deterministic
client-side derivations.** The LLM explains supplied results; it never allocates damage,
chooses attacker identity, fills unknown ammunition, or calculates a different defense.
Calculation code belongs in the existing domain/derivation pattern, with SDE and
repository access in the data layer. The UI and prompt consume the same result bundle.

The implementation needs a per-source result carrying identity/provenance, original
confidence, incoming total, canonical four-vector, resolved/untyped totals, weapon
contributions, matchup eligibility, nullable defense results, and limitations. Aggregate
and residual results must reconcile against it. Existing `CombatLogActor.weaponNames`
is a distinct-name list with no damage weights; it cannot be the calculation input.

The existing `CombatDamageProfile` lacks an untyped amount and coverage denominator,
and its type-entry `amount` is an integer. `toDamagePattern()` normalizes those rounded
amounts today; M5's incoming calculation needs fractional components through that seam.
The current `CombatDamageMatchup.toJson()` omits its `pattern`, `ehpAgainstPattern`,
and `ehpOmni`. Wrapping those models without an explicit richer result/serialization
contract is insufficient. Architecture may choose model names and internal storage,
but must satisfy the amount, provenance, and snapshot contracts here.

### 5.2 Evidence ledger

Add inspectable, stable-ID evidence for each eligible source's damage/profile and
defense comparison, referencing the encounter, source actor, correlation fact,
weapon resolution, and pilot-fit derivation. Fact IDs are encounter/participant scoped
and deterministic; recomputation replaces the same derived facts rather than appending
duplicates. Changed evidence removes stale matchup facts from the current bundle.

| Claim | Evidence treatment |
| --- | --- |
| Logged amount and source string | Observed combat-log evidence, limited to this encounter's recorded interval |
| Named participant mapping | Preserve M4 Confirmed → proven, Probable → derived, Possible → reference for identity only |
| Four-type components | Derived estimate from logged weights and exact SDE attributes; record coverage and unresolved weapons |
| EHP, tank layer, pressure, primary hole | Dogma/profile-derived facts with pilot-fit and skill assumptions; never “proven damage taken” |
| Partial profile, insufficient identity, missing/invalid defense | Explicit limitations/unknowns; omit unsupported numerical claims |

If a combined fact has one confidence field, it must not exceed its least-certain
dependency. Preserve structured identity and profile coverage separately so a Confirmed
name cannot promote estimated EHP to observed evidence. Possible candidates and residual
sources may have amount/type facts but never named defense-matchup facts.

M5 adds evidence detail; it does not change evidence-score weights, completeness bands,
Opponent Fit status, or the Missing-if-actionable rule. Attacker identification still
does not establish their fit. No user must spend an AI request to inspect these facts.

### 5.3 Prompt v4: additive input, unchanged output schema

**Keep `mimir.combat_aar_input.v4`. Add one optional input block
`damageMatchups.perAttackerIncoming`; no v5 or report-output schema change is required.**
Existing `damageMatchups.self`, `damageMatchups.opponent`, `killmailEvidence.attackerCorrelation`,
and other field shapes remain compatible. The existing self matchup remains aggregate
and must be identified as such in its evidence/prompt instructions. The new block is
present whenever a valid M5 bundle exists, including residual-only bundles; absence
means unavailable/legacy, never “zero attackers.”

The additive block MUST convey these semantics (exact nested field names belong to design):

1. Encounter/pilot identity and derivation basis/version; total incoming, resolved and
   untyped amounts; aggregate four-vector and fit provenance reference. Preserve
   fractional component quantities losslessly in the new contract (design may choose
   an exact numerator/denominator representation alongside readable decimal ratios).
   Do not present rounded legacy integer entries as the canonical source of truth.
2. Every Confirmed/Probable positive contributor: stable source/participant identity,
   human-readable available names, confidence and evidence IDs, amount/share,
   four-vector/normalized split, coverage, eligibility, and limitations.
3. Where available, numerical layered EHP, omni reference, tank layer, per-type resist
   and modeled pressure, and primary hole. Explicitly serialize these values; the
   existing matchup serializer alone does not include them. Unavailable fields are
   null/omitted with reasons, not zero or omni substitution.
4. Unattributed-for-matchup and NPC totals, typed components, untyped amounts, and
   identity/coverage limitations, with Possible contributions identified as uncertain.

Update prompt instructions to attribute claims only to an eligible named source and
its supplied profile; qualify Probable identities and partial coverage; keep incoming
pilot defense separate from outgoing victim defense; and never use the aggregate as
an individual's profile. The full local event set supplies calculations even when the
existing prompt event list is truncated. Do not truncate the quantitative source rows
silently or allow the model to infer omitted damage from an abbreviated transcript.

### 5.4 Cache, persistence, and diagnostics

New deterministic views work on previously cached reports from locally available
events/evidence. Preserve lazy M4 correlation backfill. No Drift migration, mandatory
report regeneration, or AI request is required. Existing AI prose and its evidence-at-
generation snapshot remain historical; display the existing provenance distinction
when live evidence changes. Do not rewrite a cached report to suggest it used M5 facts.
An explicit user-requested analysis uses the new block; opening/expanding cards does not.

Any cached calculation must be invalidated by relevant event, correlation, pilot-fit,
skill-basis, module-assumption, SDE, or derivation-rule changes. A pure local result can
remain in provider memory; durable caching is not a product requirement. Existing
name-resolution calls are permitted for presentation; M5 introduces no external
lookup requirement for quantitative derivation.

Implementation MUST use the shared logger with `[AAR.MATCHUP]` (and existing component
tags where appropriate) for derivation entry/outcome, coverage, bucket totals,
invariant failures, provider state changes, and caught errors with stack traces.
Record enough source and snapshot context to explain why a card is absent or partial.
Do not log raw combat transcripts or authentication material solely for this feature.

## 6. Acceptance Criteria

There are **28 release criteria**. The tests in §7 describe future implementation
verification; this specification does not claim those tests are already implemented.

### 6.1 Functional (F01–F10)

| ID | Acceptance criterion | Verification |
| --- | --- | --- |
| F01 | Positive incoming events are partitioned exactly once using log amounts; outgoing, misses, zero damage, repair and e-war events never enter a profile. | D01, D02, D09 |
| F02 | Confirmed/Probable bands permit named cards; Possible remains identity-uncertain; shipType caps are honored without re-scoring M4. | D03, D04, U03 |
| F03 | Possible, unassigned, NPC, unnamed and absent-killmail sources follow §3.2, preserving all observed damage and avoiding NPC double-counting. | D05, D06, D07 |
| F04 | Solo profiles equal the new aggregate; distinct fleet profiles and mixed weapons use only their own source's events and logged weights. | D01, D02, D10, U01, U02 |
| F05 | On a won fight the victim's return fire compares against the pilot; the user's outgoing comparison stays separate. | D08, P09, U05 |
| F06 | Zero/partial weapon coverage and missing/failed pilot defense yield the specified profile/unknown states without invented types, ownership, EHP, or holes. | D06, D11, D12, D19, P06, P07, U04 |
| F07 | Fit, skills, SDE, events, correlation and encounter changes update results coherently; card expansion reuses the same calculation. | D20, P03, P04, P05, U10 |
| F08 | Existing cached reports open without new AI calls or migrations; null/failed correlation preserves useful aggregate/source views and historical report provenance. | P01, P02, P09, U06 |
| F09 | Ledger and additive v4 input preserve original fields, scope every new claim to evidence, serialize numerical EHP explicitly, and do not upgrade evidence scores or attacker-fit completeness. | P08, P09 |
| F10 | Local derivation reuses weapon lookups and pilot defense, preserves failures as distinct states, and emits feature-tagged diagnostics for totals/coverage/errors. | P06, P07, P10 |

### 6.2 Quantitative (Q01–Q10)

| ID | Acceptance criterion | Verification |
| --- | --- | --- |
| Q01 | Per-type C/P attacker + Unattributed-for-matchup + NPC components equal aggregate components exactly. | D02, D04, D05, D13, D20 |
| Q02 | Every bucket and the encounter satisfy typed + untyped = logged total; no zero/unknown amount is silently dropped or counted twice. | D05, D06, D11, D12, D13 |
| Q03 | Source contributions use all incoming damage as denominator; type splits use resolved source damage; coverage uses source total. | D02, D04, D11, U07 |
| Q04 | Exact SDE weapon vectors are weighted by logged amount, with no hull defaults, killmail damage substitution, or guessed ammunition. | D02, D07, D10, D12 |
| Q05 | Fractional component allocation conserves amounts exactly; tiny hits retain the evidenced weapon ratio; display/legacy rounding cannot affect calculations. | D13, D20, U07 |
| Q06 | Layered EHP equals §3.4's formula and §7.1's oracle, using the same profile as pressure and no share scaling or averaging of EHPs. | D14, D15, D16 |
| Q07 | Primary layer and fit/skill assumptions are identical across incoming cards; changing the pilot fit changes the appropriate EHP/pressure values. | D16, D19, P03, P04 |
| Q08 | Resist classification preserves ≤20, mean−5, and mean+5 boundaries; the greatest pressure among present hole types wins, with stable ties and no-hole behavior. | D17, D18 |
| Q09 | Missing profile/layer, zero pressure denominator, invalid values, all-zero HP, and denominator guards never produce fabricated certainty, NaN, Infinity, or an accidental omni matchup. | D12, D19, U04, U06 |
| Q10 | Identical snapshots yield identical vectors, ordering, fact IDs and calculated results regardless of map order or UI expansion; inconsistent attribution cannot corrupt conservation. | D09, D20, P08, U10 |

### 6.3 Presentation (V01–V08)

| ID | Acceptance criterion | Verification |
| --- | --- | --- |
| V01 | Damage tab has an Aggregate Overview plus expandable source cards in one ranking, with a separately labeled outgoing comparison. | U01, U02, U05 |
| V02 | Every named card shows resolved character/ship identity or honest fallback, correlation badge, logged amount/share, four-type split, coverage, and applicable defense results. | U01, U02, U03, U04, U08 |
| V03 | Probable identity and partial-profile qualifiers remain attached to numerical claims; Possible candidates never appear as settled named matchups. | U03, U04 |
| V04 | Multi-source aggregate reference is labeled for all source combinations; individual cards never inherit an aggregate hole/advisory. Solo has no blend warning. | U01, U02, U03 |
| V05 | Expanded evidence exposes observed weapons, unresolved amounts, correlation signals, fit source/skills/module assumptions, layer resists, and modeled pressure with no raw EVE IDs. | U04, U08 |
| V06 | Loading, empty, partial, unavailable and error states use scoped explanations; existing analysis and evidence actions remain usable without automatic AI/killmail requests. | P01, P06, U06 |
| V07 | Cards work at 360px and desktop widths, with 200% text scaling, long names, keyboard and screen-reader interaction, and textual damage/confidence labels. | U09 |
| V08 | Largest contributor opens initially; users can expand multiple cards; order/keys stay stable and all fleet contributors remain accessible with correct totals. | U02, U10 |

## 7. Test Scenarios & Test Matrix

### 7.1 Shared fixtures and numeric oracles

Build fixtures from parsed incoming events plus controlled SDE vectors, correlation,
and defense inputs. Reuse [M4 scenario fixtures](../../test/features/combat_analyzer/fixtures/attacker_correlation_fixtures.dart)
for perspective/identity where suitable. Synthetic ratios keep tests independent of
future EVE balance changes. These are requirements for domain, provider/service,
and widget/integration tests, not instructions to hit live ESI or run an LLM.

**Fixture A — distinct weapons.** Use S2's 6,000/4,000 events. Synthetic pilot defense:
shield HP 1,000; armor/hull HP 0; shield resists EM 0%, Thermal 20%, Kinetic 60%,
Explosive 20%; tank layer explicitly Shield. Zero-HP layers contribute zero.

| Result | Kite: 75/0/25/0 | Artem: 0/0/25/75 | Aggregate: 45/0/25/30 |
| --- | ---: | ---: | ---: |
| Shield resonance denominator | 0.85 | 0.70 | 0.79 |
| Total EHP | 1,176.470588… | 1,428.571429… | 1,265.822785… |
| Primary pressured hole | EM | Explosive | EM |
| Pressure on that hole | 88.235294…% | 85.714286…% | 56.962025…% |

Omni EHP is `1,000 / 0.75 = 1,333.333333…` in every card. The source-share-weighted
average of attacker EHP is `1,277.310924…`, which MUST NOT replace aggregate EHP.
Assert raw EHP within `1e-6` and normalized/pressure values within `1e-9`; amount
conservation uses exact quantity equality. UI expectations use §4.3 formatting.

**Fixture B — residuals and partial types.** All incoming = 1,000. Confirmed A deals
400 (300 resolved EM, 100 untyped); Possible B deals 200 resolved Kinetic; unnamed X
deals 100 untyped; NPC N deals 300 (200 resolved Explosive, 100 untyped).

```text
M4 scalar accounting: correlated 600 + unattributed 100 + NPC 300 = 1,000
M5 matchup accounting: attributed 400 + Unattributed-for-matchup 300 + NPC 300 = 1,000
Aggregate (EM, Thermal, Kinetic, Explosive) = (300, 0, 200, 200)
Typed 700 + untyped 300 = 1,000; aggregate typed coverage = 70%
A: incoming share 40%; typed coverage 75%; resolved split 100% EM
```

**Fixture C — fractional conservation.** One raw actor has 1 resolved damage with four
equal type fractions. Canonical amounts are `(0.25, 0.25, 0.25, 0.25)`, with resolved
total 1. Another actor deals 3 via the same mix: `(0.75, 0.75, 0.75, 0.75)`. Aggregate
amounts are `(1, 1, 1, 1)`; both actors and the aggregate retain an omni profile and
omni EHP. With Fixture A's defense, EM has the largest modeled pressure (one third),
so all three profiles identify the same EM hole while retaining the four-way split.
Also test 2 and 4 damage: the profile, EHP, and pressure remain identical at each scale.
No source becomes pure EM through integer rounding. Include thirds and other repeating
fractions to verify lossless accumulation, not just binary-exact quarter fractions.

**Fixture D — mixed weapons.** One actor deals 600 via a 100% EM weapon and 400 via a
100% Thermal drone weapon: vector `(600, 400, 0, 0)`. Change hit counts without changing
those totals: the profile stays 60/40/0/0. Add a separately named uncorrelated drone
actor: its contribution stays separate.

### 7.2 Domain tests — 20 cases

| ID | Scenario/input | Required assertion |
| --- | --- | --- |
| D01 | Solo Confirmed source, one resolved weapon | Source equals aggregate vector, pattern, EHP and hole; incoming-only ownership. |
| D02 | Fixture A plus unrelated outgoing, miss, repair, zero and e-war events | Exact source/aggregate vectors and 60/40 shares; excluded events affect none of them. |
| D03 | Bands immediately below/at 0.30, 0.50 and 0.75; high-score shipType capped Probable | Consume shipped final bands; only C/P eligible; cap preserved even above Confirmed score. |
| D04 | Possible source with fully resolved weapon | Retain M4 correlated amount, place damage once in M5 X, preserve candidate evidence, emit no named matchup. |
| D05 | Fixture B including NPC inside M4 unattributedActors | Exact M4-to-M5 accounting and four-vector; NPC not counted twice; untyped NPC stays NPC. |
| D06 | Empty/Unknown actor, missing weapon, and locally classified NPC without correlation | All amounts retained; identity and type unknowns are independent; no fabricated assignment. |
| D07 | Third-party actor absent from killmail; killmail-only participant with large damageDone | Observed third party remains X; absent participant creates no profile and changes no log total. |
| D08 | Won fight with victim participant and user excluded | Victim incoming events produce source profile; victim damageTaken/user outgoing never enter it. |
| D09 | Raw name variants sharing a normalized key; duplicate/conflicting or stale correlation | Each event counted once; unique raw/normalized joins honored; conflicting attribution falls back with a reason. |
| D10 | Fixture D, ammunition switch, same weapon used by two sources, separately named drone | Logged-amount weighting; no cross-source mixing or inferred drone-owner merge; accepted correlation retains its original confidence. |
| D11 | Eligible actor with known and unknown weapons | Known vector plus untyped equals actor total; profile normalizes only known amount; partial comparison and coverage supplied. |
| D12 | All weapons unknown; exact-name mismatch; matching launcher without positive damage attributes | No pattern/EHP/hole; full amount untyped; no guessed ammo, zero coverage, or omni substitution. |
| D13 | Fixture C plus thirds, fractional mixes, many actors, and optional legacy integer projection | Exact bucket/type/aggregate conservation under random input order; tiny-hit profiles/EHP remain omni; integer projection never affects formulas. |
| D14 | Pure EM and pure Explosive; HP 1,000 with respective resists 0% and 50% | EHP 1,000 and 2,000; zero resists yield raw HP; scaling a source's amount alone does not change EHP. |
| D15 | Fixture A | Full numeric oracle including pressure, omni, aggregate EHP and rejection of averaged EHP. |
| D16 | Multiple positive defense layers; fixed tank classification | Total equals sum of weighted layer EHP; pressure uses the fixed selected layer, not each attacker's preferred layer. |
| D17 | Resists at/below/above 20%, mean−5 and mean+5 | Existing hole/strong/neutral boundaries and hole precedence retained. |
| D18 | Two present holes with unequal/equal pressure; lowest resist on absent type; no qualifying hole | Greatest eligible pressure wins; canonical tie order; absent type never wins; explicit no-hole result. |
| D19 | No fit, unknown layer, zero HP, q=0, nonfinite/negative values, out-of-range resists | Distinct unavailable states; valid unknown-layer EHP retained; q=0 finite guard flagged; no manufactured pressure/hole. |
| D20 | Repeat/reorder valid snapshots; alter one input snapshot; inconsistent event/aggregate total | Identical inputs deterministic; changes isolated correctly; invalid total prevents a claimed reconciled numerical bundle. |

### 7.3 Provider and service tests — 10 cases

| ID | Scenario/input | Required assertion |
| --- | --- | --- |
| P01 | Cached M4 report/enrichment opened before AI analysis | M5 derives locally; no new AI/zKill request, no report mutation or database migration. |
| P02 | Legacy matched enrichment with null correlation; null/log-only or failed backfill | Existing lazy backfill reused; plain/residual and aggregate views remain; no write/invalidation loop. |
| P03 | Pilot fit replaced/imported; own-loss fit competes with explicit pilot evidence | Existing fit precedence used; all card defense values refresh together; amounts/profiles unchanged. |
| P04 | Known-character skills change or fall back to All V; module assumptions change | Defense and provenance invalidate together; no confidence upgrade from identity or stale EHP. |
| P05 | SDE initialization/update, changed events, or correlation Possible→Probable | Coverage/profiles/grouping update; no new damage, stale facts, or duplicate source; fit reused when unchanged. |
| P06 | Delayed/error SDE lookup for one weapon; whole resolver failure; recovery | Per-weapon failure becomes untyped with reason; global failure is an unavailable state; retry is scoped and non-blocking. |
| P07 | Fit derivation fails while correlation/profile succeeds, and converse | Independent useful data retained; errors never become zero amounts/zero EHP; correct logs and limitations. |
| P08 | Build ledger and prompt from valid full, partial, residual-only and empty bundles | UI and serialized numbers agree; EHP explicit; stable fact IDs replace stale facts; v4 additions optional; old field shapes and scoring unchanged. |
| P09 | Legacy prompt/report round-trip, kill perspective, stale report evidence, truncated prompt events | Existing input/output fields compatible; historical report provenance retained; incoming/outgoing scopes correct; calculations use complete local events. |
| P10 | Many attackers sharing weapons; repeated card expansion; success and invariant-failure runs | One lookup per distinct normalized weapon per snapshot; one pilot-defense derivation; no expansion I/O; feature-tagged totals/coverage/errors logged. |

### 7.4 UI and integration tests — 10 cases

| ID | Scenario/input | Required assertion |
| --- | --- | --- |
| U01 | Solo full-coverage eligible source | Overview and one expanded card agree; required metrics present; no blend advisory or duplicate source ranking. |
| U02 | Fixture A fleet; open both cards | Distinct correct values; damage-descending initial order; aggregate reference labeled; each card retains its own hole/profile. |
| U03 | C/P/Possible/NPC/unattributed mix, then one C plus a residual source | Correct badges/conditional wording and totals; Possible candidate only in uncertain details; combined-source warning even with one eligible card. |
| U04 | Partial coverage, no typed damage, missing defense, unknown layer, no pressured hole | Correct distinct messages; partial qualifier alongside EHP; no fabricated zero/omni; inspectable weapon and fit evidence. |
| U05 | Won fight with returning-fire victim and outgoing matchup | “Your defense vs [victim]” and outgoing-victim-defense labels remain distinct; each uses the correct fit/profile. |
| U06 | Zero incoming, no correlation, loading, provider error and retry | Clear scoped states; source/overview fallback when usable; other report/actions remain usable; no automatic AI/search. |
| U07 | Fractional shares/type ratios; Fixture B with untyped subtotal | Split totals 100.0%; denominator labels/rounding note correct; untyped not added as extra damage; no NaN/Infinity. |
| U08 | Character/ship names load, fail and recover; hull actor alias; evidence expansion | Names or honest fallbacks everywhere; “Logged as” provenance and signals; no numeric IDs, including detail text. |
| U09 | 360px and desktop; 200% text; long names; keyboard and screen reader | No overflow/trapped focus; all values accessible; expansion state announced; meaning conveyed without color. |
| U10 | Large fleet, equal amounts/names, expanded cards during refresh and encounter switch | All sources reachable, deterministic keys/order, expansion preserved per encounter, no stale results under a new source. |

### 7.5 Release validation

Execute the 40 cases above (parameterization may create additional individual tests),
the existing M4 correlation/perspective suites, incoming resolver/matchup/fit tests,
provider prompt-compatibility tests, and relevant Damage-tab widget tests. Run
`flutter analyze` and the repository's required test checks before implementation
ships. Verify the Damage tab visually on macOS and at the narrow/text-scale fixtures.
Prioritize complete coverage of partitioning, eligibility, numerical guards, and
perspective; retain the repository's minimum 80% coverage requirement.

## 8. Product Decisions & Non-Goals

### 8.1 Settled product decisions

| ID | Decision | Rationale / revisit condition |
| --- | --- | --- |
| D1 | Deterministic incoming-event derivation; same bundle serves UI and prompt. | Quantitative claims must be reproducible without an LLM. |
| D2 | Named cards for Confirmed/Probable; Possible included in Unattributed for matchup without mutating M4. | Distinguishes tentative identity from actionable comparison while conserving damage. Revisit only with an explicit attribution-policy change. |
| D3 | Keep all typed residual components and explicit untyped amounts; no invented four-way split. | Identity uncertainty and weapon-resolution uncertainty are independent. |
| D4 | Any positive typed coverage permits a qualified partial comparison. | A low-volume known portion can still be inspected; visible amount/coverage prevents a completeness claim. No arbitrary hidden threshold. |
| D5 | Shared fractional incoming allocation, lossless conservation, and rounding only at presentation/legacy boundaries. | One canonical calculation avoids contradictory totals and invented tiny-hit weapon profiles. |
| D6 | Vertical expandable source cards with compact aggregate overview and collapsed aggregate defense reference. | Supports fleet-size lists, simultaneous comparison, and narrow layouts without duplicate rankings. |
| D7 | Always compare incoming sources with pilot defense; preserve victim return-fire support. | “Attacker” describes the incoming damage role, not merely membership in killmail.attackers. |
| D8 | Preserve existing EHP/tank/resist definitions; tighten zero-type, tie, invalid-data and labeling behavior as specified. | Prevents aggregate reuse and misleading pressure claims while keeping the fitting model consistent. |
| D9 | Optional additive perAttackerIncoming input within v4; unchanged report output and historical caches. | Makes new evidence usable by AI while keeping local views independent of regeneration. |
| D10 | No new evidence-score dimensions, fit inference, or external quantitative lookup requirements. | This milestone makes existing evidence more specific; it does not create missing attacker fittings. |

These product choices are resolved for technical design. Architecture selects concrete
model/provider boundaries, dependency keys, and widget composition while preserving
the externally observable rules and numerical oracles. A conflict must be surfaced
against a numbered rule rather than resolved by silently weakening evidence or totals.

### 8.2 Non-goals

- New correlation weights, many-to-one alias ownership, manual attacker reassignment,
  drone-owner inference, or additional killmail discovery heuristics.
- Inferring attacker modules, charges, skills, fits, or doctrine from a hull; reference
  fits remain separate queued work. A killmail weapon ID is not an ammunition history.
- Reconstructing true pre-resistance volleys or measured post-resistance type damage;
  time-resolved ammunition/loadout reconstruction beyond observed per-event weapons.
- Turret tracking, missile/drone application, range, velocity, angular/sig effects,
  active-tank survival time, reload/overheat simulation, or recommendations proving a
  different fit would have won.
- Individual NPC matchups, outgoing damage de-aggregation across multiple victims,
  ship-vs-ship diagrams, fit comparison editors, exported reports, or new AI output fields.
- Changing evidence completeness scoring, auto-running analysis/search, forcing cached
  report regeneration, adding a Drift schema migration, or persisting card preferences.

### 8.3 Journal and completion protocol

Link this specification from the queued per-attacker item while implementation is
pending. Keep the item queued until M5 behavior and validation ship; a completed spec
alone is not a shipped feature. Record the canonical allocation, confidence gate,
profile-estimation limitation, and additive-v4 decision in the engineering journal,
linking here instead of duplicating the full contract. On implementation completion,
archive the queued item as SHIPPED with commit and validation evidence, and record
any new parser, SDE, or cache findings in the same change set.

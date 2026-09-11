# Correlate zKill Attackers with Combat-Log Actors — Implementation Plan

## Goal

Ship QUEUED.md P2 "Correlate zKill Attackers with Combat-Log Actors" as an attribution milestone over the killmail + log data Milestones 2–3 already produce: for every encounter with a matched killmail, identify which `incomingBySource` log actors are which killmail attackers (player, NPC, ship-type, ambiguous, unnamed), accumulate confidence from named signals, assign one-to-one with ambiguity handling, account all `totalDamageReceived` across correlated + unattributed + NPC, persist the result on `CombatEnrichment.attackerCorrelation`, and surface it in the AAR damage tab with evidence-ledger facts — without new network I/O, prompt-schema breakage, or per-attacker matchup re-derivation in V1.

## Success Criteria

- Encounter with a matched killmail shows `Attackers N identified · M unattributed` with per-attacker badge (`Confirmed ≥0.75`, `Probable ≥0.50`, `Possible ≥0.30`), ship via `itemNameProvider`, signals listed, and `correlated + unattributed + npc == totalDamageReceived`.
- Loss with `Sabre`-named actor correlates that actor via ship-type + damage at `probable` (capped), not `confirmed`; NPC actor `Serpentis Watchman` never correlates to a player attacker and lands in the NPC bucket.
- Fleet with two equal-signal `Sabre` actors: ambiguity within `0.10` assigns neither; both land `Unattributed`/`ambiguous` and both attackers stay `noLogPresence`.
- Third-party log actor absent from the killmail lands `notOnKillmail` and 1,100 unattributed; `uncorrelatedAttackers` collapse shows "N attacker(s) not present in your combat log".
- No-killmail encounter: `attackerCorrelation` stays `null`, section renders plain actor rows (`Incoming Sources` replacement) with no badges.
- Cached enrichments written before this milestone load with `attackerCorrelation == null` and gain correlation on first screen open / analysis stage 4 with a single persisted write; core scorer and prompt tests stay additive.
- `flutter analyze` clean, `flutter test` (full suite including new groups A–I + U0) green; every new public method logs `[COMBAT.CORRELATE]` / `[COMBAT.ENRICH]` / `[COMBAT.UI]` per CLAUDE.md.

## Context And Current Facts

**Sources inspected for this plan:** `docs/specs/aar-zkill-attacker-correlation.md` (Product, 2026-09-11), `docs/specs/aar-zkill-attacker-correlation-design.md` (Arch HOW, same date, §0 C1–C12 + §2–§9), `lib/features/combat_analyzer/domain/combat_enrichment.dart` (has `killmailSearchCompleted`, `rawKillmail`, `pilot/victimFitEvidence`, `matchConfidence/matchReason`; `toJson` JSON-round-trips, `copyWith` preserved), `lib/features/combat_analyzer/data/combat_enrichment_service.dart` (674 lines: `_enrichmentFromMatch` → `_withResolvedNames` → `_save`, `_mergeLedgers`, `_loadOrCreateEnrichment`; `ensureAttackerCorrelation` does not yet exist), `lib/features/combat_analyzer/domain/parsed_combat_encounter.dart` / `combat_log_parser.dart:18` (`CombatLogParser._damageRegex` → `CombatEvent.targetName` + `CombatAggregates.incomingBySource` Map<String,int> + `totalDamageReceived`), `core/network/esi_client.dart` (`EsiKillmailAttacker/Detail/Victim` — `characterName` not yet read in `fromJson`, `factionId` not parsed, `damageDone` on attackers only), `core/sde/sde_service.dart` / `scripts/sde/generate_dogma_sde.py` (`TARGET_CATEGORIES` today `{6,7,8,16,18,20,22,32,87}` + `NAME_ONLY {11}` at develop:5a70b48; `bundledDogmaVersion = 3` after Milestone 3; `SdeDatabase.searchTypesByName` + `getGroup`/`getType` are the exact-match lookup prior art used by `CombatDamageProfileResolver._lookupDamageAttributes`), `lib/features/combat_analyzer/domain/combat_damage_matchup.dart` / `AarEvidenceScorer` (Derivation milestone shipped: scorer already appends correlation detail to D3 without changing status), `lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart` / `Damage tab` (ends with `_BreakdownSection('Incoming Sources')` listing `incomingBySource` — the null-case rendering this milestone replaces; D5 decision), `docs/engineering-journal/QUEUED.md` (P2 entry; worth-it-when Milestones 2+3 merged — now merged at develop:5a70b48).

**Spec conflict resolved:** Product spec §2.1–2.5 and the design's probed table agree on the principle (unattributed beats fabricated), the six signals, and the invariant. Design §0 C1–C12 corrects twelve binding mismatches where product rules read fields the shipped bundle does not carry. This plan adopts the design as contract: bundled SDE needs category 11 names (C1, U0); `character_name` round-trip (C2) and `factionId`/`isPlayer` (C3) are one-line `esi_client` fixes; weights must be `0.75/0.30/0.20/0.20/0.15/0.10` for the stated outcomes to hold (C4 → S1 0.85, T2.1 confirmed by name alone); participant pool is attackers ∪ victim minus the user (C5); timing only on victim (C6); `Unnamed` vs `Unknown` (C7) and `notOnKillmail` vs `belowThreshold` (C8); `shipType` unconditional on category 6 (C9); correlation does not elevate D3/D4 status (C10, §4); replace `Incoming Sources` (C11/D5); lazy correlation via `ensureAttackerCorrelation` not `_save` hot-loop (C12).

**What prior milestones gave us:** `CombatAggregates.incomingBySource` already splits incoming damage per displayed actor; `EsiKillmailAttacker.damageDone` is directly comparable; `CombatKillmailMatcher._matchesEncounterName` is normalized-name prior art whose 0.10 `ambiguityMargin` shape is reused; name resolution (`_withResolvedNames` → `resolveNames` → `copyWith`) already happens before this milestone's insertion point.

## Constraints And Non-goals

- No new network calls — `EsiClient.getKillmailDetail` + `resolveNames` + cached SDE reads only (R5.3); missing SDE types simply absent from the index.
- No per-attacker matchup re-derivation in V1 — matchup uses the aggregate profile; section shows a blend advisory when ≥2 attackers correlate (R4.3.2); queued as P2 (D4).
- No ship-vs-ship diagram — future consumer of `AttackerCorrelation`, tracked as "Fit comparison visuals" P2 (product §0.5).
- No attacker fit inference — killmails expose only victim fits; `R4.2.2` hull-only label only, with "Attacker fits are not exposed by killmails" note.
- Prompt schema v4 changes additive only — `killmailEvidence.attackerCorrelation` optional block plus one system-prompt rule sentence (R5.1, T7.1 key-set guard); T4.6 before-=-after test.
- No Drift table migration — `AttackerCorrelation?` lives inside the JSON column; `fromJson(null)` → `null` (R3.2.1, R5.2).
- Non-fatal correlation — exception → `Log.e`, `null`, enrichment otherwise intact (R5.4).
- Must not invent failures from file existence or byte sizes; bare opener "test"/"hi" conversational.

## Key Decisions

| # | Decision | Choice | Rejected alternative | Why |
|---|----------|--------|----------------------|-----|
| 1 | NPC classification without bundled data | **U0**: bundle category 11 names only (`typeId/typeName/groupId`, ignore `published`, no dogma; `SdeService.bundledDogmaVersion 2→3`); classifier reads `group.categoryId == 11` | Hard-coded NPC name list or regex heuristic | Bundled SDE at Milestone 3 has categories 6,7,8,16,18,20,22,32,87 only — `searchTypesByName('Serpentis Watchman')` returns nothing, so every NPC defaults to `player`. Only SDE-true classification makes R2.1.2 safe; "names only" keeps asset <1 MB. |
| 2 | Killmail names lost on cache round-trip | **Parse `character_name` in both `EsiKillmailAttacker.fromJson` / `Victim.fromJson`** | Re-resolve names on every load | `toJson` wrote `character_name`, `fromJson` ignored it — every cached enrichment re-correlated without name signals, degrading to damage-only. ESI never sends that key live, so live parsing unaffected. |
| 3 | Signal weights | **`name 0.75, ship 0.30, weapon 0.20, damage 0.20, timing 0.15, sole 0.10`**; caps/ceilings per §2.2; `damageRatio 0.60/0.35`, `ambiguityMargin 0.10`, thresholds `0.75/0.50/0.30` | Product's 0.60/0.25 as printed | With 0.60/0.25 the stated outcomes fail: name-alone ≠ confirmed, ship+damage ≠ probable, S1 ≠ 0.85. Corrected constants live in `AttackerCorrelationRules` (R2.2.1) and are pinned by T2.10 and the S1/S2 tables. |
| 4 | Participant pool | **Attackers ∪ victim, minus the user participant, wrapped as `CombatKillmailParticipant(isVictim, damageDone null for victim)`** | Attackers only | On a kill the incoming actor is the **victim**, not an attacker (C5). Excluding the victim makes S1 unmatchable; including the user makes every self-hit self-correlate. NPC participants (`factionId`) listed but never paired. |
| 5 | Replace Incoming Sources | **Replace** `_BreakdownSection('Incoming Sources')` with `AarAttackerCorrelationSection` directly after matchups; null correlation renders the same plain name+damage rows | Two lists of same actors on one tab | One source of "who hit me" prevents competing rankings; the title is not pinned by any test so removal is non-breaking (C11/D5, T8.5). |
| 6 | Where correlation runs | **Pure `domain/` pipeline (`CombatActorClassifier` + `CombatAttackerCorrelator`) called from `CombatEnrichmentService` with a pre-resolved `CombatActorTypeIndex`; also `ensureAttackerCorrelation(encounter, enrichment)` from `combatAttackerCorrelationProvider` + analysis stage 4** | Domain doing SDE I/O, or provider doing enrichment writes in a loop | Keeps Groups A–D pure (no `DateTime.now()`, no providers); lazily backfills pre-milestone `killmailMatched` rows once per legacy row, no retry storm (C12/D3). |
| 7 | Evidence scorer vs correlation | **D3 detail suffix enumerates correlated attackers; D4 status unchanged; no new actions** | Promote D3 `ambiguous→partial` or D4 to `Inferred` via correlation | Ambiguous enrichments store no killmail to correlate (C10); attacker fits not exposed on a loss (R4.2.1), so status elevation would be false. Invariant I1 (Missing⇔action) preserved. |
| 8 | Timing scope | **`S-TIME` only when `selfIsVictim`** | Timing always | Last-hit correlation is meaningful only when the last hit the user took is the killmail final blow — a kill's incoming timing is unrelated (C6). |

## Recommended Approach

**Classification first, attribution second, integration last — with the floor fixed before the pipeline is wired.** U0 unblocks honest classification at all (C1); then domain scoring and models (U1) pin the invariant and the five signal weights; in parallel, the two JSON carriers (U1b) unblock persisted correlation. The service/ledger/provider join (U2) is the only piece that touches I/O and is the point where pre-milestone rows backfill — it must land before any detail suffix or UI. Scorer detail (U3) is a single-line suffix change; the UI section (U4) replaces the existing breakdown only after the provider is live, so the Damage tab is never double-listed. Journal (U5) follows the UI because its LEARNINGS cite categories. This is Milestone 3's proven TDD layering (pure unit → wiring → widget → screen) with two parallel cuts — U1+U1b and U3+U4 — so no branch carries a spec ambiguity.

## Work Plan

Units are **[SEQ]** sequential or **[P1]/[P2]** parallel as in `aar-zkill-attacker-correlation-design.md:8`. Each lists **RED→GREEN→REFACTOR** TDD; the test-author must land the RED suite and observe it failing **for the named reason** before the dev branch starts. Commits are atomic per unit (`type(scope): description`, no attribution lines).

### [P1] U0 — SDE: bundle category 11 names

**Tests first (RED).** (§7.10) `test/core/sde/real_sde_entity_types_test.dart` U0.1/U0.2 and `core/sde/sde_service_test` version bump — fail: `searchTypesByName('Serpentis Watchman')` empty, `bundledDogmaVersion` 2, asset without category 11 name.

**Dev (RED → GREEN).** `scripts/sde/generate_dogma_sde.py` — add `NAME_ONLY_CATEGORIES = {11}`, union into categories/groups, types with no dogma/attributes (`published` ignored for 11, emit `typeId/typeName/groupId` only); regenerate `assets/sde/dogma.json`; `core/sde/sde_service.dart` `bundledDogmaVersion = 3`.

**Gate:** asset growth <1 MB, `flutter test test/core/sde` GREEN.

**Owner:** `scripts/sde/` + `core/sde/` — Sonnet.

### [P1] U1 — Domain: models, classifier, correlator

**Tests first (RED).** `test/features/combat_analyzer/fixtures/attacker_correlation_fixtures.dart` (helpers `incomingEncounter`/`attacker`/`victim`/`detail`/`typeIndex` + scenario builders `s1Kill`/`s2Loss`/`s3Fleet`/`s4ThirdParty`/`s5NpcMix`/`actor`/`participant`/`context`), then Groups A–D + I T9.1 (§7.1–7.4, §7.9) — fail: contracts missing, 0.75 not 0.60, `shipType` not `player`, no `unnamed`, invariant check missing.

**Dev (RED → GREEN).** `lib/features/combat_analyzer/domain/combat_attacker_correlation.dart` (`CombatActorClass` 5 incl. `unnamed`, `AttackerCorrelationConfidence`, `UncorrelatedReason` 7, `CorrelationSignal` 6 with labels, `AttackerCorrelationRules` one-place constants, `CombatLogActor(key,isScorable,toJson/fromJson)`, `CombatKillmailParticipant(isPlayer,isVictim,key,ship/weapon ids,factionId,toJson/fromJson)`, `CorrelatedAttacker(signals)`, `AttackerCorrelation(correlated/unattributed/uncorrelated/reasons/damage sums/invariant/summaryLine/toJson/fromJson/toPromptJson,rulesVersion)`), `combat_actor_classifier.dart` (`CombatTypeRef`, `CombatActorTypeIndex.byName/byId`, `CombatActorClassifier.classify` per §2.1 — exact normalized match, `npc` ahead of `shipType`, `ambiguous`, `unnamed`, sorted actors, weapons+timestamps per actor), `combat_attacker_correlator.dart` (`CorrelationContext`, `PairScore(band/cappedBand)`, `CombatAttackerCorrelator.correlate/participants/contextFor/score/assign` per §2.2–2.3 — six signals, caps, `ambiguityMargin 0.10`, greedy one-to-one deterministic tie-break, `reasons` map, three-sum invariant).

**Gate:** Groups A–D/I RED→GREEN; S1 0.85 confirmed `[name,sole]`, S2 three rows 0.95/1.00/0.50, S3 fleet `ambiguous` + `notOnKillmail`, S4 `notOnKillmail`, S5 NPC 1,400, `T3.6 accountsForAllDamage`, JSON round-trip D.7, `unknown` toleration.

**Owner:** `domain/combat_analyzer/` — Opus.

### [P1] U1b — Models: ESI names/faction and enrichment field

*Parallel with U1 (no file overlap).*

**Tests first (RED).** Group E JSON rows E.9, T5.2, T5.3, D.7/D.8 — fail: `character_name` dropped, `factionId` absent, `attackerCorrelation` missing in `toJson`.

**Dev (RED → GREEN).** `core/network/esi_client.dart` — `EsiKillmailAttacker.fromJson` reads `character_name` + `faction_id` as `factionId` + `bool isPlayer => characterId != null`, writes `faction_id` in `toJson`; same read for `Victim`. `domain/combat_enrichment.dart` — field `AttackerCorrelation? attackerCorrelation` (nullable, absent-tolerant `fromJson`, `copyWith`, `toJson` conditional, `toPromptJson` additive compact block §4.4).

**Gate:** `E.9` names survive round-trip; `T5.2` enrichment JSON round-trip; `T5.3` pre-milestone JSON → null.

**Owner:** `core/network/` + `domain/combat_enrichment.dart` — Sonnet.

### [SEQ after U0, U1, U1b] U2 — Service, ledger, provider, prompt

**Tests first (RED).** Group E (T5.1–T5.6, E.7/E.8/E.10) + Group G (T7.1/T7.2/G.3) + Group I I.2 — fail: no correlation after `enrichEncounter`, `ensureAttackerCorrelation` not found, `attackerCorrelation` absent from prompt, `correlate logs` absent.

**Dev (RED → GREEN).** `data/combat_enrichment_service.dart` — `_buildTypeIndex` (names via `searchTypesByName` exact normalized + `getGroup`, ids via `getType`+`getGroup`, memoised, no ESI), `_correlateOrNull` (try/catch→`Log.e`, `Log.i [COMBAT.CORRELATE]` per-pair + summary at `Log.d` inside correlator), `ensureAttackerCorrelation(encounter, enrichment)` (guard `null||!killmailMatched||rawKillmail null`→no-op; decode→correlate→`_save` with `_correlationLedger`'s two ledger entries `attackerCorrelation:~.score*`? no — `_mergeLedgers(correlate ledger)`, single-write backfill; failure no-write), patch `_enrichmentFromMatch` to correlate after `_withResolvedNames` and carry correlation into `fromKillmail`+`_mergeLedgers`; `combat_analysis_service.dart` stage 4 `ensureAttackerCorrelation` on the cached path; `combat_providers.dart` `combatAttackerCorrelationProvider(encounter)` (not invalidating the enrichment provider per C12); `codex_analysis_client.dart` one system-prompt sentence.

**Gate:** T5.1 correlated after resolved names, T5.4 no new network calls, E.7 single write, E.8 no-ops, E.10 stage-4 ensured, G.3 sentence, T7.1 prompt additive and key-set guarded.

**Owner:** `data/` — Opus on the enrichment seam, Sonnet elsewhere.

### [SEQ after U2] U3 — Evidence scorer detail

**Tests first (RED).** Group F (T6.1–T6.5, F.6) — fail: D3 detail unchanged with correlation present, score would have moved.

**Dev (RED → GREEN).** `domain/aar_evidence_scorer.dart` — `opponentIdentity()` appends `'; N of M log actors identified on the killmail (…)` plus `'; attacker hulls known, fits not exposed by killmails'` when `selfIsVictim && correlated non-empty` (§5, §4.1); `opponentFit()` untouched (C10/R4.2.1); no new actions → I1 preserved.

**Gate:** T6.2 enumeration suffix, T6.4 score identical, F.6 I1 holds.

**Owner:** `domain/aar_evidence_scorer.dart` — Sonnet.

### [SEQ after U2] U4 — UI section, matchup advisory, screen wiring

*Can run parallel with U3 after U2 (no file overlap on the scorer detail).*

**Tests first (RED).** Group H (§7.8) — fail: section absent, badge keys absent, toggle missing, `Incoming Sources` still rendered, advisory absent.

**Dev (RED → GREEN).** `presentation/widgets/aar_attacker_correlation_section.dart` (`AarAttackerCorrelationSection` provider shell with `.when(skipLoadingOnReload:true)` + `AarAttackerCorrelationBody` pure body: header `summaryLine` / `Incoming Sources` fallback, correlated rows `aar-attacker-row-<key>` with `EveTypeIcon` + `itemNameProvider.when` + badge `aar-attacker-badge-<key>` + signals, null-correlation rows `aar-actor-row-<name>`, bucket rows `aar-attackers-npc/unattributed`, collapsed `aar-attackers-uncorrelated-toggle`, footer `aar-attackers-fits-note`; null renders plain actors). `widgets/aar_matchup_section.dart` — `correlatedAttackerCount` param → advisory `aar-matchup-blend-advisory` when ≥2. `analysis_multipane_screen.dart` — `_matchupWidgets` reads `combatAttackerCorrelationProvider.when(0 fallback)` for self matchup; `_buildDamageTabContent` inserts section after matchups and deletes `Incoming Sources`.

**Gate:** T8.1 badges+ship+damage+signals, T8.5 null plain rows, T8.7 when/loading/error, H.11 section after matchups and no `Incoming Sources` when correlated.

**Owner:** `presentation/` — Sonnet.

### [P2 after U4] U5 — Journal

**Tests:** none — verified by file content review.

**Dev.** As in `aar-zkill-attacker-correlation-design.md:9`: `ARCHIVE.md` → QUEUED P2 as SHIPPED (revised effort §0.4 + classification stage + bundled-SDE C1); `LEARNINGS.md` → four entries (log names the displayed entity not the pilot; killmails expose victim fits only; bundle scoped by consumer → audit categories; `toJson`/`fromJson` asymmetry is silent data loss, add round-trip tests); `DECISIONS.md` → D5–D8; `QUEUED.md` → P2 per-attacker profile/matchup, P3 reference fits / inventory_type fallback / drone-named actors. Same change set per `AGENTS.md`.

**Gate:** `git diff --stat docs/engineering-journal/` shows P2 removed/`ARCHIVE` SHIPPED/`LEARNINGS` four entries.

**Owner:** `docs/engineering-journal/` — Sonnet.

### [SEQ] U6 — Closing gate

**Dev.** `flutter analyze` clean, full `flutter test` green, `dart format .`; manual macOS check on a real loss with ≥2 attackers: badges+signals visible, summary counts sum to Damage Taken, advisory shown above self matchup, pre-milestone cached AAR gains correlation on first open and second open causes no write (watch `[COMBAT.ENRICH] Saved enrichment cache`).

**Gate:** `analyze` + `test` logs pasted into HANDOFF; LEARNINGS notes manual check done or deferred.

**Owner:** repo root — Sonnet.

## Validation Plan

Each unit's gate is **RED before GREEN** — implementation is blocked until the unit's test-author suite is observed failing for the named reason. Existing tests are regression-locked: no edits to existing expectations except the listed `extend` files gaining cases.

| Unit | RED suite (test-author lands first) | GREEN implementation check | Exact command / expected evidence |
|------|--------------------------------------|----------------------------|-----------------------------------|
| U0 | `real_sde_entity_types_test` U0.1/U0.2 + `sde_service_test` version bump — fail: no such type, version 2 | SDE 11 names + version 3 | `flutter test test/core/sde/real_sde_entity_types_test.dart test/core/sde/sde_service_test.dart` → `U0.1` exact match category 11, no attributes, growth <1 MB; `bundledDogmaVersion 3` |
| U1 | `combat_actor_classifier_test` A + `attacker_correlator_signals_test` B + `attacker_correlator_test` C + `attacker_correlation_scenarios_test` D + `attacker_correlation_logging_test` T9.1 — fail: contracts/configs missing | Pure domain | `flutter test test/features/combat_analyzer/domain/combat_actor_classifier_test.dart test/features/combat_analyzer/domain/attacker_correlator_signals_test.dart test/features/combat_analyzer/domain/attacker_correlator_test.dart test/features/combat_analyzer/domain/attacker_correlation_scenarios_test.dart test/features/combat_analyzer/domain/attacker_correlation_logging_test.dart` → all RED→GREEN; S1 0.85 `[name,sole]`, S2 0.95/1.00/0.50, S3 `ambiguous`, D.7 round-trip, T3.6 invariant |
| U1b | `esi_client_test` + `combat_enrichment_test` (JSON) — fail: `character_name` dropped, `factionId` absent | ESI names + field | `flutter test test/core/network/esi_client_test.dart test/features/combat_analyzer/domain/combat_enrichment_test.dart --name "E.9\|T5.2\|T5.3\|D.7"` → `E.9` round-trip, `T5.2` enrichment JSON round-trip, `D.7` `fromJson(null)==null` |
| U2 | `combat_enrichment_service_test` Group E + `combat_analysis_service_test` E.10 + `attacker_correlation_logging_test` I.2 — fail: no correlation after enrich, counts changed | Service + backfill + prompt | `flutter test test/features/combat_analyzer/data/combat_enrichment_service_test.dart test/features/combat_analyzer/data/combat_analysis_service_test.dart --name "T5.\|E.7\|E.10\|T9.1\|I.2"` → T5.1 single resolved Artem, E.7 one write, T5.4 no network, T9.1 `[COMBAT.CORRELATE]` per-pair + summary; `grep codex_analysis_client` no new top-level prompt key except `attackerCorrelation` block |
| U3 | `aar_evidence_dimensions_test` Group F — fail: detail suffix absent | Scorer detail | `flutter test test/features/combat_analyzer/domain/aar_evidence_dimensions_test.dart --name "T6\."` → `T6.2` suffix enumerates `Artem S3 confirmed, Kite Mondeo confirmed, Sabre probable` + fits note; `T6.4` scorer score identical |
| U4 | `aar_attacker_correlation_section_test` Group H — fail: section/badge/toggle absent | Widgets + screen wiring | `flutter test test/features/combat_analyzer/presentation/aar_attacker_correlation_section_test.dart test/features/combat_analyzer/presentation/analysis_multipane_evidence_test.dart --name "T8.\|H.11"` → `T8.5 null plain actors`, `H.11` section after matchups and no `Incoming Sources` |
| U5 | — (docs review) | Journal | `git diff --stat docs/engineering-journal/` shows P2 removed/`ARCHIVE` SHIPPED/`LEARNINGS` four entries |
| U6 | — | Closing | `flutter analyze` clean; `flutter test` full suite GREEN (no edits to existing expectations except `extend` files); pasted logs + manual macOS check notes in HANDOFF |

**Highest-risk validation:** `attacker_correlator` T3.6 three-sum invariant (`correlated + unattributed + npc == totalDamageReceived`) — if `Unknown`/`unnamed` damage is double-counted or leaked, the invariant fires and every S2/S4/S5 scenario's summary is silently wrong. Second-risk: U0 SDE 11 names — if the generator emits the wrong `categoryId`, every NPC actor stays `player` and `T1.2`/`S5` fail.

## Risks / Rollback

- **SDE 11 bloat or mis-categorization (U0).** Regeneration brings ~6k types; drop `published==1` check only for 11 and emit no dogma or describe per `generate_dogma_sde.py` diff. Rollback: revert `NAME_ONLY_CATEGORIES` and `bundledDogmaVersion`; classifier degrades to always-`player`.
- **Name asymmetry regressing T2.1/T4.1 (U1).** Normalized comparison must match `_normalizeTypeName` (`trim → collapse whitespace → lowercase`). Mitigation: T1.6/T2.10 pin weights and normalization; `searchTypesByName` prior art identical path.
- **Ambiguity handling mis-applied (U1).** Greedy with 0.10 margin must mark both sides of a tie as `ambiguous`/`belowThreshold`, not just drop the second. Mitigation: T3.3 S3 Sabre case plus `T3.4` 100-run determinism across input order; single `assign` entry point.
- **Enrichment write storm (U2 C12).** `ensureAttackerCorrelation` writes only once per legacy `killmailMatched` row; failure path returns enrichment without writing. Mitigation: I.2 + E.7 single-write spy; provider does not re-invalidate enrichment. Rollback: gate the provider behind a feature flag, return `null` correlation.
- **Prompt-key guard breach (U2).** Snapshot flag must not leak into `mimir.combat_aar_input.v4` top-level keys. Mitigation: T7.1 before=after key-set test; `killmailEvidence.attackerCorrelation` additive only per R5.1.
- **Device reading vs client expectation (U3).** `selfIsVictim` drives wording "attacker(s) not present in your combat log" vs "other attacker(s) on this kill" (H.10). Mitigation: S1 vs S2 fixtures pin both branches.

## Open Questions

None after local discovery — every question in spec §8 was closed by design §0–§5 contracts and the `develop:5a70b48` probed tables. Remaining product-confirmation items (reference fits for correlated hulls, inventory_type name fallback, drone-named actors) are carried as queued P3 follow-ups (§10), not blockers.

---
*Plan file:* `.agents/plans/2026-09-11-aar-zkill-attacker-correlation.md` — canonical body is the reply above. Reviewer prompts: verify `Missing ⇔ actionable` is untouched, `AttackerCorrelationRules` one-place constants match §2.2, `combatAttackerCorrelationProvider` does not hot-loop writes, SDE 11 names are category 11, `character_name` round-trips, and `Incoming Sources` is replaced.

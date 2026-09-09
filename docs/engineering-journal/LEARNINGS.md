# Learnings - Mimir

> **Empirical findings + mechanisms + fixes + validations.** When something
> turns out to be true that was not obvious about Mimir, Flutter, EVE APIs,
> combat logs, SDE, zKill, Codex/AI integration, or local macOS behavior, it
> goes here.
>
> **Append new entries to the top.** Most-recent first. Format:
>
> ```markdown
> ## YYYY-MM-DD
>
> ### Short descriptive title
>
> **Author.** {agent-name}
> **Context.** One paragraph framing the situation.
> **Evidence.** Specific file, test, command, log excerpt, issue, commit, or plan.
> **Mechanism.** Why it happened or why it is true.
> **Fix (or queued).** Concrete action, commit hash, or QUEUED.md ref.
> **Validation.** What proved the fix.
> **What surprised.** Optional note on the mistaken prior assumption.
> **Generalizable rule.** The lesson stripped from this specific incident.
> **Refs.** Cross-links to DECISIONS / QUEUED / narratives / related entries.
> ```
>
> Not every entry needs every subheader, but evidence and mechanism matter.
> If a prior learning is invalidated, correct it inline and move the old version
> to `ARCHIVE.md` as SUPERSEDED. Never silently overwrite history.

---

### 2026-09-08

### Cap boosters fire on demand, not on a cadence (pyfa capSim injector port)

**Author.** Qwen Code
**Context.** Cap stability was wrong for booster fits: the simulator ignored
cap gains, so a fit that stays alive on Cap Booster 400s read as unstable.
**Evidence.** pyfa `eos/capSim.py`: injector activations are popped like any
module but postponed into `awaitingInjectors` when `cap - capNeed > capacity`
(overshoot), fired the moment a drain cannot be paid (`capNeed > cap`), and
used to top up after spending; gains travel as negative capNeed. The SDE
keeps the gain on the charge (capacitorBonus 67, e.g. 400 GJ) and the reload
on the module (reactivation delay 1795, 10s on cap boosters), and pyfa adds
that delay to every module's cycle time.
**Mechanism.** Boosters are reserve capacity, not repeating supply: firing
them on a cadence wastes gains to overshoot and misreports stability.
**Fix.** CapSimulator gained `injectors` with postpone/fire/top-up logic and
an awaiting-set signature inside the period-wrap stability check; DogmaEngine
collects injectors from fitted booster charges and adds 1795 to every cycle.
Clips stay infinite (fittings carry no charge quantities) — documented.
**Validation.** cap_simulator_test (60 GJ/s drain unstable alone, stable with
a 400 GJ/10s booster; boosters alone hold 100%) and dogma_engine_test (a
loaded booster stabilizes an otherwise unstable drain); 433 tests green.
**What surprised.** The gain/reload split across charge and module, and that
reactivation delay joins every module's cycle, not just boosters'.
**Generalizable rule.** Port reserve-resource semantics (on-demand firing)
before cadence semantics, and check where each number lives in the SDE.
**Refs.** ARCHIVE SHIPPED 2026-09-08 cap injectors entry; QUEUED clip reloads.

### Production-wiring widget tests need runAsync for Drift isolates and a grown test surface

**Author.** Qwen Code
**Context.** Locking the fitting-stats chain (SdeService -> providers ->
engine -> StatsPanel) against the dead-`effects` bug class required a widget
test that uses the real Drift-backed service instead of fixtures.
**Evidence.** First attempt hung with no output: `SdeDatabase`'s
`NativeDatabase.memory()` answers from a background isolate, and port
replies never reach a future that started inside the widget-test FakeAsync
zone (provider futures kick off during `pumpWidget`). A later failure showed
the lazy `ListView` in StatsPanel stopping mid-section: Scaffold bodies give
tight window-height constraints, so an oversized `SizedBox` is ignored and
only ~600px of rows build.
**Mechanism.** FakeAsync pumps virtual time but does not turn the real event
loop, so isolate/port and sqflite work must run inside `tester.runAsync`;
and lazy slivers only build children within viewport+cacheExtent of the
real surface size.
**Fix.** Resolve the provider chain in a bare `ProviderContainer` inside one
`runAsync` block, then render StatsPanel against the resolved stats with
`tester.view.physicalSize` grown (1200x2400) so every row lays out.
**Validation.** `fitting_stats_production_wiring_test.dart`: Tristan with
loaded autocannon + Warriors + DDA II yields dps 50.4 (guns 3.4, drones 47.0)
and renders OFFENSE/DRONES rows; 430 tests green.
**What surprised.** A fit that looks fine in fixtures can be correctly
rejected by the engine: Warriors on a Rifter produce 0 drone DPS because the
Rifter's drone bandwidth is 0 — the test had to move to a Tristan.
**Generalizable rule.** Widget tests over real services: wrap isolate-backed
async in runAsync before pumpWidget, and size the surface for lazy lists.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; HANDOFF next step.

### modifierInfo's skillTypeID is a target filter, not the scaling skill

**Author.** Qwen Code
**Context.** The first drone/amp increment scaled every skill-linked modifier
by the linked skill's level, which made Rifter's racial bonus scale with
Small Projectile Turret instead of Minmatar Frigate (a character with SPT V
and MF 0 would have gotten the full bonus).
**Evidence.** Bundled data: Rifter effect 7248 carries `skillTypeID: 3302`,
and 3302 is Small Projectile Turret (skills.json), while the Rifter's own
required skill (attribute 182) is 3329 = Minmatar Frigate; the turret's
attribute 182 is 3302. pyfa's handlers confirm the split: `Effect7248`
filters `requiresSkill('Small Projectile Turret')` and scales with
`skill='Minmatar Frigate'`, while `Effect6556` (drone damage amp) and
`Effect3656`/`Effect889` filter by skill and apply the value raw.
**Mechanism.** CCP's resolved modifiers publish one skill link — the skill
targets must require (pyfa's filter). Ship-owned racial bonuses scale with
the ship's own required skill (attributes 182/183/184); module-owned bonuses
(amps, enhancers, BCS rof) apply raw.
**Fix.** DogmaEngine routes with `ownerIsShip`: ship-owned modifiers scale
with `shipSkillLevel` (from the ship's required-skill attributes),
module-owned apply raw; `skillTypeID` filters targets via their required
skills. Operator 4 joined 0 as postMul (heat sink/BCS family, pyfa
Effect91/763 multiply handlers), and BCS-style `charID` modifiers on 212
multiply loaded missile damage components like pyfa's filteredChargeMultiply.
**Validation.** `dogma_engine_test.dart` (filter vs scaling, amp raw, heat
sink op 4, BCS missile multiply) and `real_sde_weapon_test.dart` (Rifter at
Minmatar Frigate V from bundled data; Warrior II + DDA II = 47 DPS);
429 tests green.
**What surprised.** One field serving as filter while the scaling skill lives
only on the owner ship — the data alone is ambiguous without pyfa.
**Generalizable rule.** When two publishers disagree in shape, use the
reference implementation's handlers to disambiguate field semantics.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; LEARNINGS 2026-09-08
modifierInfo entry.

### The SDE publishes resolved dogma modifiers; dgmExpressions is retired and fuzzwork moved to csv/

**Author.** Qwen Code
**Context.** Unlocking DPS/volley/optimal needed ship weapon bonuses, which
were assumed to live in dogma expression trees (the plan was to bundle
`dgmExpressions` and evaluate them pyfa-style).
**Evidence.** fuzzwork `csv/dgmExpressions.csv` is header-only (1 row);
`csv/dgmEffects.csv` carries a `modifierInfo` column with CCP's resolved
modifiers, e.g. Rifter effect 5779:
`{"domain": "shipID", "func": "LocationRequiredSkillModifier", "modifiedAttributeID": 158, "modifyingAttributeID": 587, "operation": 6, "skillTypeID": 3302}`.
Separately, the old flat `*.csv.bz2` URLs 404 since the dump moved to `csv/`
plain files (verified 2026-09-08), which would have broken regeneration.
**Mechanism.** CCP replaced expression-tree publication with pre-resolved
modifier lists per effect, including skill linkage (`skillTypeID`) and group
restrictions (`groupID`); func + domain encode the routing: `ItemModifier` +
`shipID` = owner modifies the ship (hardeners, damage control), `Location*`/
`Owner*` + `shipID` = owner modifies fitted modules (racial weapon bonuses,
tracking enhancers), `charID` = owner modifies loaded charges (missile
damage bonuses), `itemID` = self only.
**Fix.** `scripts/sde/generate_dogma_sde.py` fetches the new `csv/` layout and
bundles `assets/sde/effect_modifiers.json` (2090 effects, 1984 with
modifiers); DogmaEngine routes by func/domain instead of evaluating trees.
**Validation.** `test/features/fitting/domain/real_sde_weapon_test.dart`
loads the bundled assets from disk and reproduces Rifter's traits
(-7.5%/level rof, +10%/level falloff at skill 3302) end to end.
**What surprised.** The expression-tree port was unnecessary: the retired
table's replacement is strictly better data (resolved, skill-aware).
**Generalizable rule.** Re-check the data source before porting an
evaluation engine; publishers sometimes replace trees with resolved facts.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry; QUEUED drone DPS.

### Production fitting stats silently ignored every module bonus (effects never populated)

**Author.** Qwen Code
**Context.** While wiring ship bonuses I traced why the engine's module
modifier loop could never fire in the app although tests passed.
**Evidence.** `SdeService.getModuleType` built `ModuleType` without `effects`
(model default `[]`), so `fittingStatsProvider`'s `effectIds` list was always
empty and `ensureEffectModifiers([])` returned `{}`; only hand-built test
fixtures had effects.
**Mechanism.** The Drift table `SdeTypeEffects` was seeded and read for slot
detection (`getTypeEffects`), but nobody mapped those rows into the model, so
hardener/damage-control/propulsion bonuses were absent from real stats while
every unit test constructed modules with effects and stayed green.
**Fix.** `getModuleType`/`getShipType` now populate `effects` (names from the
bundled effect metadata); the stats provider also resolves charge types so
missile/turret damage has its source data.
**Validation.** `test/core/sde/sde_service_test.dart` asserts seeded effect
rows surface on `ShipType.effects` with bundled names; full suite 422 green.
**What surprised.** A test suite can be fully green while a production path
is dead, when fixtures bypass the very mapping that is missing.
**Generalizable rule.** Fixture-built tests must be paired with at least one
test that walks the real repository/service mapping.
**Refs.** DECISIONS 2026-09-08 bundled-modifiers entry.

### Capacitor stability is an event simulation, not a formula (pyfa eos/capSim.py port)

**Author.** Qwen Code
**Context.** The stats panel's "Stable" row needed cap stability, which has no
closed form once module cycles repeat against the recharge curve.
**Evidence.** pyfa's `eos/capSim.py` (fetched 2026-09-07): recharge between
events is `cap = ((1 + (sqrt(cap/C) - 1) * exp(-dt/tau))^2) * C` with
`tau = rechargeTime / 5`; identical modules are staggered as one activation
every duration/count; stability is detected when the cap at a whole LCM period
is no lower than at the previous one; negative cap ends the sim as unstable
with time-to-empty.
**Mechanism.** The recharge curve is nonlinear, so average-rate maths cannot
answer "does this fit hold cap"; only stepping through activations can.
**Fix.** `lib/features/fitting/domain/cap_simulator.dart` ports that algorithm
(repeating drains only: no cap injectors, no reloads — documented in the
class); DogmaEngine feeds it per-module capacitorNeed (6) and duration (73,
milliseconds) and reports stable percent or seconds-to-empty; the panel shows
percent when stable, seconds when not, dash when unmodelled.
**Validation.** Five simulator tests (empty, light, overwhelming, stagger
equivalence, monotonic stability) plus two engine-level tests.
**Generalizable rule.** When a reference implementation exists (pyfa), port
its algorithm and pin behaviour with tests rather than re-deriving approximations.
**Refs.** QUEUED 2026-09-07 cap-stable entry (now shipped).

### Dogma operator semantics come from live ESI; some bonuses hide in expression trees

**Author.** Qwen Code
**Context.** Making module resist/EHP modification real required knowing how
each effect transforms ship attributes, which the bundled SDE does not store
(it carries effect IDs only).
**Evidence.** Live `GET /dogma/effects/{id}/` on 2026-09-07: effect 5230
(EM Shield Hardener II) uses operator 6 with modifying attributes 984-987 whose
local values are percent units (-55); effect 2302 (Damage Control) uses
operator 0 mapping module resonances onto ship resonances (0.85); effect 6731
(moduleBonusAfterburner) returns an EMPTY modifier list while the module's
speedFactor attribute is 135 on a 1MN AB II.
**Mechanism.** Operator 6 is postPercent (confirmed by the percent-unit bonus
attributes); operator 0 must be postMul, since postPercent would make a 0.85
resonance bonus a no-op and assignment would overwrite better base resonances.
Effects with empty modifier lists encode their bonus in pre/post expression
trees, which ESI does not publish (only expression IDs), so they cannot be
derived from ESI alone.
**Fix.** Engine applies cached ESI modifiers (new SdeEffectModifiers table,
SDE schema v6) with {6: postPercent + stacking penalty on resonances,
0: postMul}; the earlier guessed `speedFactor` multiplication was removed —
with the real value of 135 it would have multiplied speed by 136. Propulsion
is nonetheless modelled via a small curated map for the two expression-tree
effects (6730 MWD, 6731 AB): speedFactor is percent units and the bundled SDE
values (AB I 115, AB II 135, MWD I 500, MWD II 510) match the in-game
multipliers x2.15/x2.35/x6/x6.1. Unknown propulsion-style effects are ignored
rather than guessed. (Amended inline 2026-09-07; earlier text said velocity
stays base+skills.)
**Validation.** Engine tests pin postPercent, postMul, stacking-penalty and
domain-filtering maths; three consecutive full-suite runs green (404 tests).
**Generalizable rule.** Check a dogma attribute's units and operator against
live data before applying any "attribute times factor" maths.
**Refs.** DECISIONS 2026-09-07 "Fitting tank math is data-driven";
QUEUED P2 expression-tree entry.

### ESI cannot write the skill queue — verified against the live OpenAPI spec

**Author.** Qwen Code
**Context.** The 2026-09-07 audit listed "zero authenticated ESI writes" as the
top capability gap and proposed pushing skill plans to the game.
**Evidence.** `https://esi.evetech.net/meta/openapi.json` fetched 2026-09-07:
34 write operations in total, none under `/characters/{id}/skillqueue` or
`/characters/{id}/skills` (both GET-only), and the only skill scopes are
`esi-skills.read_skills.v1` and `esi-skills.read_skillqueue.v1`.
**Mechanism.** CCP never exposed skill-queue management over ESI, so every EVE
companion app — not just Mimir — is read-only for skills. The audit item was a
platform property misread as a product gap.
**Fix.** Shipped the writes ESI does support instead: save-fitting-to-EVE and
autopilot waypoints, both behind an explicit confirmation dialog.
**Generalizable rule.** Verify a capability against the live spec before
planning a feature around it; a missing endpoint is invisible from the client.
**Refs.** DECISIONS 2026-09-07 "Phase 6 writes"; QUEUED Maybe entry.

## 2026-09-07

### ESI removed GET /search/; POST /universe/ids/ is the supported replacement

**Author.** Qwen Code
**Context.** The Market Browser's default tab could never return a result, and
the Intel watch-list dialog had no way to resolve names at all.
**Evidence.** `curl 'https://esi.evetech.net/latest/search/?categories=inventory_type&search=tritanium'`
returns 404. `POST /universe/ids/` with `["Jita","Amarr"]` returns
`{"systems":[{"id":30000142,"name":"Jita"},...]}`; with `["Tritanium"]` it
returns `inventory_types:[{"id":34,...}]`.
**Mechanism.** The standalone public search route was withdrawn from ESI.
`/universe/ids/` is the supported public name-resolution endpoint and returns
category-keyed maps; it matches whole names, not substrings.
**Fix.** 6b2e06d (market search: SDE substring first, `/universe/ids/` to
augment), d903ff9 (watch-list name resolution).
**Validation.** Provider tests plus live curl against the running endpoint.
**What surprised.** The solar-system key is `systems`, not `solar_systems`.
**Generalizable rule.** Verify an EVE endpoint against the live service before
building on it; a 404 can sit behind a green build for months.
**Refs.** DECISIONS 2026-09-07 "Dead inferior UI..."; QUEUED P2 mapper entry.

### Golden tests race async providers; pin the providers, do not add a tolerance

**Author.** Qwen Code
**Context.** The Skills goldens failed roughly half of full-suite runs with
"Pixel test failed, 0.00%, 3px diff" yet passed every time in isolation.
**Evidence.** The isolated diff image contained a single speck at the top bar,
where the unallocated-SP value renders; `unallocatedSpProvider` logs showed it
resolving during the capture window.
**Mechanism.** FutureProviders resolve on a pump phase that shifts with the
tests that ran earlier in the same process, so the capture sometimes caught the
top bar mid-resolution.
**Fix.** ce94c20 pins unallocatedSp, totalSkillPoints and queueStats to fixed
AsyncValues for both Skills goldens.
**Validation.** Ten consecutive full-suite runs green.
**What surprised.** A `LocalFileComparator` subclass with a percentage tolerance
made *every* golden fail with "Could not be compared against non-existent
file": the wrapper's `getGoldenBytes` threw before its tolerance logic ran.
That attempt was reverted.
**Generalizable rule.** Make golden inputs deterministic at the provider level;
comparison tolerances treat the symptom and can break golden path resolution.
**Refs.** ce94c20.

### Drift watch() streams do not emit inside bare test() containers here

**Author.** Qwen Code
**Context.** Provider-level tests for saved fittings awaited
`savedFittingsProvider(null).future` and timed out at 30s, while the identical
providers behave under `testWidgets`.
**Evidence.** TimeoutException plus "StreamProvider ... disposed during loading
state, yet no value could be emitted" in
test/features/fitting/presentation/fitting_save_load_test.dart before the fix.
**Mechanism.** Not fully root-caused; the first stream emission never arrives
under the plain test zone in this project's setup.
**Fix.** 959808b asserts persistence through one-shot repository reads
(`getFittings`), and `saveCurrent` resolves the active character with
`characterRepository.getActiveCharacter()` instead of the character stream.
**Validation.** Six fast, stable provider tests.
**Generalizable rule.** In provider unit tests prefer one-shot reads; keep
stream assertions in widget tests where a binding drives the loop.
**Refs.** 959808b.

### ReorderableListView.onReorderItem pre-adjusts newIndex

**Author.** Qwen Code
**Context.** Migrating off the deprecated `onReorder` looked mechanical.
**Evidence.** Flutter SDK reorderable_list.dart: the `onReorder` path passes the
raw drop index while `onReorderItem` passes the index computed after removing
the dragged item.
**Mechanism.** Keeping the app's historical `if (newIndex > oldIndex) newIndex -= 1`
correction on top of the pre-adjusted index shifts every downward drag one slot
early, silently corrupting plan order.
**Fix.** 9d221e2 removes the manual correction with a comment saying why.
**Generalizable rule.** When a deprecation changes a callback's parameter
semantics, read the SDK call site before migrating.
**Refs.** 9d221e2.

### TestApp rendered Flutter's default light theme while the app ships dark

**Author.** Qwen Code
**Context.** Every golden and integration test rendered a theme no user sees.
**Evidence.** sub_window_app.dart hardcodes `AppTheme.darkTheme()`; the
regenerated light-theme Industry golden showed a white-on-white "No Industry
Jobs" empty state.
**Mechanism.** TestApp's MaterialApp declared no theme, so tests got Flutter's
light default.
**Fix.** 9d221e2 sets `AppTheme.darkTheme()` in TestApp and regenerates all
baselines in the shipped theme.
**Validation.** Dark baselines reviewed visually; contrast problems became
visible instead of hidden.
**Generalizable rule.** A test harness must render the shipped theme, or the
suite validates a product that does not exist.
**Refs.** 9d221e2.

## 2026-05-21

### macOS Flutter sub-windows need explicit plugin and config boundaries

**Author.** Codex
**Context.** Combat Analyzer runs as a desktop sub-window. Several failures
looked like UI or scanner bugs, but the root cause was sub-window/plugin
boundary behavior on macOS.

**Evidence.** The recovery checkpoint recorded two concrete faults:
`shared_preferences` produced a sub-window plugin-channel error, and the folder
picker did nothing until native plugin registration was added for
`desktop_multi_window` sub-windows. The scanner later moved selected directory
state into app-support `combat_analyzer.json` instead of relying on
`SharedPreferences`.

**Mechanism.** Each desktop sub-window has its own Flutter engine. Plugins that
work in the main engine are not automatically safe in sub-windows unless the
native side registers them for that engine. Config needed by sub-windows should
also live in a file/database surface the sub-window can read directly.

**Fix.** Register generated plugins for macOS sub-windows and use
app-support JSON for Combat Analyzer config.

**Validation.** Folder selection started working from the Combat Analyzer
window, and scanner state loaded from the saved config instead of getting stuck
behind "scanner not ready" behavior.

**Generalizable rule.** For multi-window Flutter desktop features, assume
plugin registration and state access are per-engine concerns. Prefer database
or app-support files for cross-window state, and verify native plugin
registration for any UI action launched from a sub-window.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`.

### EVE gamelog folders are mostly non-combat and need cached classification

**Author.** Codex
**Context.** The initial log scanner found many files but either showed
non-combat events or appeared empty depending on directory and parser readiness.

**Evidence.** The recovery checkpoint recorded
`/Users/jefcox/Documents/EVE/logs/Gamelogs` with 1,419 timestamped gamelog
files, but only 56 classified as combat logs and 1,363 classified as
non-combat. Those 56 combat logs produced 295 displayable encounters.

**Mechanism.** EVE gamelogs include timestamped files for many client events,
not just combat. Filename shape proves "EVE gamelog", not "combat log".
Scanning every historical file on startup is wasteful, and showing every
timestamped file pollutes the AAR list with skill redemption and other
non-combat events.

**Fix.** Filter by actual combat-damage content and persist a classification
cache keyed by file path, modified time, and size. Cap initial scans to newest
files and recheck changed files.

**Validation.** Combat Analyzer loaded only combat-bearing logs, and unchanged
non-combat files were skipped on refresh without rereading their contents.

**Generalizable rule.** Treat game-log filename patterns as a broad source
filter only. Use content classification plus a file fingerprint cache before
building UI or sending data to AI.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`;
`tasks/todo.md`.

### Combat logs are a primary source but not a complete AAR evidence source

**Author.** Codex
**Context.** The combat analyzer initially produced useful AAR prose from EVE
combat logs, but reports still had many unknowns even after zKill/killmail
matching. The user wanted a path to resolve those unknowns instead of having
the AI guess.

**Evidence.** AAR enrichment implementation added
`lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`,
`combat_fit_snapshot_mapper.dart`, `combat_damage_matchup.dart`, and v3 prompt
payload support in `lib/features/combat_analyzer/data/codex_analysis_client.dart`.
Focused checks passed:
`flutter test test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`
and
`dart analyze lib/features/combat_analyzer lib/features/fitting/domain/format_parser.dart test/features/combat_analyzer test/features/fitting/domain/format_parser_test.dart`.

**Mechanism.** EVE combat logs prove event timing, damage lines, hits, misses,
weapons, and actors seen by the local client. They do not contain range,
transversal, tank layer depletion, pilot intent, historical pilot fit, full
opponent fit, or all ship/dogma modifiers. Killmails add destroyed-fit and
attacker/victim context, but they still do not prove the surviving pilot's fit
or the live range/application situation.

**Fix.** Added an evidence ledger and fit evidence model so AARs can separate
proven facts, user-confirmed facts, reference snapshots, derived facts, and
open unknowns. Added manual EFT/DNA fit import and current active ship snapshot
capture as explicit evidence-gathering paths.

**Validation.** Domain tests cover ledger serialization, current-ship asset
snapshot mapping, damage matchup classification, and SDE-backed EFT parsing.
Combat analyzer tests plus fitting parser tests pass.

**What surprised.** zKill/killmail enrichment reduced some unknowns but did
not eliminate the highest-value one for learning: the pilot's actual fit at
fight time.

**Generalizable rule.** Treat each EVE source as evidence with scope and
confidence. Do not let the AI collapse "unknown" into narrative certainty;
surface the missing evidence and give the user a way to resolve it.

**Refs.** [DECISIONS 2026-05-21](DECISIONS.md#combat-aar-v3-uses-evidence-ledger-and-fit-evidence-before-deeper-simulation);
[QUEUED AAR simulation work](QUEUED.md#p1--aar-fit-simulation-and-defense-profile-derivation);
[AAR plan checkpoint](../../.codex/plans/2026-05-21-combat-analyzer-aar.md).

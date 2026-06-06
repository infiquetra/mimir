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

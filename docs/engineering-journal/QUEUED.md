# Queued Work - Mimir

> **Future-work items by priority with explicit worth-it-when triggers.** When a
> promising idea surfaces but we do not build it right now, it goes here.
>
> Format:
>
> ```markdown
> ### Short title
>
> **Author.** {agent-name}
> **Priority.** P0 / P1 / P2 / P3 / Maybe.
> **Effort.** Rough estimate.
> **Worth it when.** Specific trigger that makes this pressing.
> **Context.** What surfaced this and what should be remembered.
> **Refs.** Related entries, files, tests, plans, issues, or PRs.
> ```
>
> When work ships, move the entry to `ARCHIVE.md` as SHIPPED. When consciously
> rejected, move it to `ARCHIVE.md` as REJECTED. Never silently delete.

---

## P0 - Must Ship Before Next Release

<!-- P0 entries go here. -->

## P1 - Urgent

### AAR fit simulation and defense profile derivation

**Author.** Codex
**Priority.** P1
**Effort.** Several days to a week depending on whether the existing dogma
engine is sufficient or pyfa-grade behavior needs a deeper port.
**Worth it when.** Before presenting AAR recommendations as mechanically
trustworthy fit advice rather than AI coaching prose.
**Context.** The evidence ledger can now carry pilot and victim fits, but Mimir
still needs deterministic derivation for EHP, resists, tank layer, capacitor,
range envelope, speed, signature, and damage application. Without this, the AI
can discuss fits but cannot reliably quantify why one fit wins a matchup.
**Refs.** [LEARNINGS 2026-05-21](LEARNINGS.md#combat-logs-are-a-primary-source-but-not-a-complete-aar-evidence-source);
`lib/features/combat_analyzer/domain/combat_damage_matchup.dart`;
`lib/features/fitting/domain/dogma_engine.dart`;
`.codex/plans/2026-05-21-combat-analyzer-aar.md`.

### AAR evidence completeness score and pre-analysis checklist

**Author.** Codex
**Priority.** P1
**Effort.** Half-day to a day.
**Worth it when.** As soon as users routinely re-analyze reports after adding
fits or killmail evidence.
**Context.** The analyzer should tell the user what evidence is missing before
spending AI time: pilot fit, killmail match, opponent fit, range telemetry
limitations, tank profile, and confidence level. This makes unknowns actionable
instead of burying them in prose.
**Refs.** `lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`;
`lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart`.

## P2 - Important

### AAR fit import and capture UI tests

**Author.** Codex
**Priority.** P2
**Effort.** Half-day to a day.
**Worth it when.** Before making further AAR UI changes around evidence,
re-analysis, or fit comparison.
**Context.** The domain and parser tests cover evidence ledger, snapshot
mapping, matchup classification, and EFT parsing. The UI controls for manual
fit import, current fit snapshot, and "use current fit for this fight" still
need provider-overridden widget coverage that exercises ESI assets, SDE, and
enrichment storage together.
**Refs.** `lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart`;
`test/features/combat_analyzer/domain/combat_fit_snapshot_mapper_test.dart`;
`.codex/plans/2026-05-21-combat-analyzer-aar.md`.

### Correlate zKill attackers with combat-log actors

**Author.** Codex
**Priority.** P2
**Effort.** One to two days.
**Worth it when.** AARs frequently include multiple opponents or when the same
named actor appears across combat logs and killmails.
**Context.** Killmails expose attackers, ships, weapons, and damage done. The
combat log exposes local observed actors and timings. Correlating those sources
can reduce opponent-fit unknowns and make ship-vs-ship diagrams more useful.
**Refs.** `lib/features/combat_analyzer/domain/combat_killmail_matcher.dart`;
`lib/features/combat_analyzer/domain/combat_killmail_fit_mapper.dart`.

### Fit comparison visuals for AAR reports

**Author.** Codex
**Priority.** P2
**Effort.** One to three days.
**Worth it when.** Fit evidence and derived fit stats are available enough to
make visual deltas more accurate than prose.
**Context.** The user wants AARs to show current fit, fight-time fit, killmail
victim fit, and recommended changes side by side with module icons, stats, and
bill-of-materials style recommendations.
**Refs.** `lib/features/combat_analyzer/presentation/analysis_multipane_screen.dart`;
`lib/features/fitting/presentation/widgets/fitting_editor.dart`.

## P3 - Nice To Have

<!-- P3 entries go here. -->

## Maybe

<!-- Speculative entries go here. -->

# Decisions - Mimir

> **Architecture, prompt-design, and process decisions.** When we commit to a
> path over alternatives, capture the rationale, rejected alternatives, and
> revisit conditions.
>
> **Append new entries to the top.** Format:
>
> ```markdown
> ## YYYY-MM-DD
>
> ### Short title (commit hash or pending)
>
> **Author.** {agent-name}
> **Decision.** What we picked.
> **Rejected alternatives.** What we considered and did not pick.
> **Rationale.** Why this won.
> **Revisit when.** Conditions that would change the decision.
> **Refs.** Related files, tests, plans, issues, PRs, LEARNINGS, or QUEUED entries.
> ```
>
> If new evidence invalidates a decision, update it inline and move the
> pre-correction version to `ARCHIVE.md` as SUPERSEDED.

---

## 2026-09-07

### Fabricated intel data is deleted, not gated (59f031b, d903ff9)

**Author.** Qwen Code
**Decision.** Remove MapperSyncCard, PathfinderClient and DiscordRpcService
outright; record the real-integration intent in QUEUED.md instead.
**Rejected alternatives.** Gating the mock behind a dev flag; keeping the card
with an honest "not connected" state.
**Rationale.** In an intel tool a confidently false "Connected to Pathfinder"
badge is worse than no card. A permanently disabled card is clutter, and a flag
invites the mock back into production builds.
**Revisit when.** A maintained public wormhole-mapper API with a understood auth
model exists (QUEUED.md P2 entry).
**Refs.** 59f031b; QUEUED.md "Real wormhole-mapper integration".

### SDE updates replace only the skill slice (e6c7837)

**Author.** Qwen Code
**Decision.** `SdeDatabase.deleteSkillSlice` (skill types by group plus their
prerequisites) runs inside the update transaction; `clearAll()` is gone from the
update path, and `sdeServiceProvider` is invalidated on apply.
**Rejected alternatives.** clearAll + re-import; keeping clearAll and refetching
dogma/industry from somewhere (no source exists in the payload).
**Rationale.** The update payload carries skills only. Wiping the dogma and
industry tables it cannot restore left Ship Fitting at zeros and Industry
lookups empty until restart.
**Revisit when.** Update payloads start carrying dogma/industry data.
**Refs.** e6c7837; test/core/sde/sde_database_skill_slice_test.dart.

### Dead inferior UI is deleted; dead valuable UI is wired (34b0f4c, 8e99f4f)

**Author.** Qwen Code
**Decision.** Wire OverviewTab into the Characters window as an Overview tab;
delete PriceCheckerPanel.
**Rejected alternatives.** Wiring both; deleting both.
**Rationale.** OverviewTab carries information nowhere else in the app (current
ship, location, online status, clone summary). PriceCheckerPanel's only unique
behaviour was asking for a raw numeric Type ID — the anti-pattern the project
rule forbids — duplicating what MarketBrowserPanel already does by name.
**Revisit when.** Price checking needs a flow the Browser cannot express.
**Refs.** 8e99f4f; 34b0f4c.

### Saved fittings resolve the character with a one-shot read (959808b)

**Author.** Qwen Code
**Decision.** `FittingController.saveCurrent` calls
`characterRepository.getActiveCharacter()`; the dialog streams
`savedFittingsProvider(characterId)`, which includes character-null shared fits.
**Rejected alternatives.** Awaiting `activeCharacterProvider.future` in the
write path.
**Rationale.** A write must not hold a stream subscription, and that stream
never settles outside a widget tree (LEARNINGS 2026-09-07).
**Revisit when.** Cross-character fit sharing grows a UI of its own.
**Refs.** 959808b.

## 2026-05-21

### Combat analysis is explicit and cache-first; list loading must not call AI (commit: pending)

**Author.** Codex
**Decision.** Opening Combat Analyzer or loading the encounter list must only
scan and parse local logs. AI analysis happens only when the user clicks the
analyze/re-analyze action, and cached AARs are displayed without resending the
encounter.

**Rejected alternatives.**
- Auto-analyze every discovered encounter. This risks surprise token use,
  privacy leakage, long startup times, and repeated AI calls over historical
  logs.
- Re-analyze whenever a parsed encounter is opened. This makes cached reports
  meaningless and hides cost/latency behind navigation.

**Rationale.** Combat logs can contain a large history. The correct user model
is browse locally first, then choose which fight deserves AI time. Cache state
also lets the UI mark which encounters already have AARs.

**Revisit when.** Only if Mimir adds a clearly labeled batch-analysis workflow
with limits, progress, cancellation, and an explicit cost/privacy confirmation.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`;
`.codex/plans/2026-05-21-combat-analyzer-aar.md`.

### AI auth is Mimir-owned app auth, not Codex CLI mutation (commit: pending)

**Author.** Codex
**Decision.** Mimir owns its own `auth.json` for AI/Codex login, following the
Hermes-style provider shape, refresh logic, owner-only file permissions, and
Codex-specific device flow. Codex CLI credentials may be imported only as an
optional migration path.

**Rejected alternatives.**
- Write directly to `~/.codex/auth.json`. This risks refresh-token rotation
conflicts with the CLI and makes app behavior depend on another tool's store.
- Store Codex access tokens as a generic `llmApiKey`. That conflates ChatGPT
device OAuth with normal OpenAI API keys and breaks refresh semantics.
- Use normal `/v1/chat/completions` request shape for Codex. That produced
HTTP 400s and does not match the backend contract used by Codex/Hermes.

**Rationale.** App-owned credentials make lifecycle, permissions, and refresh
behavior auditable. The Codex backend needs Codex-specific headers and streamed
Responses handling, so it should be modeled as a distinct AI provider path.

**Revisit when.** OpenAI publishes a stable app-OAuth API or Codex backend
contract for third-party clients. Keep direct OpenAI API-key support separate
from ChatGPT/Codex device OAuth.

**Refs.** `.codex/plans/2026-05-20-combat-analyzer-recovery.md`;
`test/features/combat_analyzer/codex_auth_service_test.dart`.

### Combat AAR v3 uses evidence ledger and fit evidence before deeper simulation (commit: pending)

**Author.** Codex
**Decision.** The combat analyzer AAR contract now sends an explicit evidence
ledger plus pilot/victim fit evidence to the AI. The report version moved to
v3, and the UI exposes fit import/current-fit snapshot actions before
re-analysis.

**Rejected alternatives.**
- Keep pushing all unknown-resolution into prompt prose. That would make the
  model guess about missing fit/range/tank facts and would be hard to audit.
- Jump straight to pyfa-grade fit simulation before the evidence model exists.
  That would create a larger implementation with weak provenance and no clear
  way to distinguish confirmed, reference, and inferred inputs.
- Treat current ship snapshot as proven fight-time fit. That is incorrect
  unless the user confirms the snapshot represents the fight.

**Rationale.** Evidence provenance is the base layer. Once every fact has a
source and confidence, later SDE/dogma simulation can enrich the AAR without
erasing the difference between combat-log proof, killmail proof, user-confirmed
fit, and inference.

**Revisit when.** If Mimir gains reliable historical fitting data or a full
dogma simulation engine, add deterministic derived facts to the ledger but keep
the provenance model. Do not collapse back to unstructured prompt-only evidence.

**Refs.** `lib/features/combat_analyzer/domain/combat_evidence_ledger.dart`;
`lib/features/combat_analyzer/data/codex_analysis_client.dart`;
`test/features/combat_analyzer/domain/combat_evidence_ledger_test.dart`;
[LEARNINGS 2026-05-21](LEARNINGS.md#combat-logs-are-a-primary-source-but-not-a-complete-aar-evidence-source);
[QUEUED AAR fit simulation](QUEUED.md#p1--aar-fit-simulation-and-defense-profile-derivation).

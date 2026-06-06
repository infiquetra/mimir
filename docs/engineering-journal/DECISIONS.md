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

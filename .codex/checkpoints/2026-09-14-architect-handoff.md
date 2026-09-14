# Mimir architect handoff

Date: 2026-09-14 (America/Indiana/Indianapolis)

## Assignment and custody

Jeff requested that this agent take over the architect in the other pane of the
current Herdr tab, collect its context, and close that pane. This transfers the
architect role; Lead continues to own implementation orchestration.

- Incoming architect: Codex, pane `wB:pE`, initially named `arch-2`.
- Outgoing architect: Claude, pane `wB:p8`, named `arch`.
- Both panes were confirmed in tab `wB:t8`, workspace `wB`, with this repository
  as cwd. The outgoing session ID is `1c82e6e0-1767-49a3-9645-e29c550d9467`.
- A handoff prompt was submitted through Herdr's atomic agent prompt command.
  Claude responded `Login expired`; no fresh handoff was available. Context was
  recovered from its visible history, committed documents, Git, and relevant
  Lead/Product pane output. Authentication was not changed.
- Outgoing history's claim that the Milestone 4 documents were uncommitted is
  stale: commit `56a3893` contains the product spec, design, and plan.

## Canonical records

Read the design's section 0 before interpreting the companion product spec:
these sections record corrections grounded in the code and bundled SDE.

- Current product spec: [attacker correlation](../../docs/specs/aar-zkill-attacker-correlation.md).
- Current technical contract: [attacker correlation design](../../docs/specs/aar-zkill-attacker-correlation-design.md).
- Current execution plan: [Milestone 4 plan](../../.agents/plans/2026-09-11-aar-zkill-attacker-correlation.md).
- Prior design: [skill cycle bonuses and fighters](../../docs/specs/fitting-completion-skill-rof-and-fighters-design.md).
- Prior design: [fit simulation and defense profiles](../../docs/specs/aar-fit-simulation-and-defense-profiles-design.md).
- Prior design: [evidence completeness and checklist](../../docs/specs/aar-evidence-completeness-score-design.md).
- Shipped architecture and follow-ups: [engineering journal](../../docs/engineering-journal/README.md).
- Repository requirements: [AGENTS.md](../../AGENTS.md) and [CLAUDE.md](../../CLAUDE.md).

`tasks/todo.md` is an older broad roadmap; its unchecked milestone entries do not
override the current plan, Git history, or journal.

## Current implementation snapshot

Branch: `feature/aar-zkill-attacker-correlation`.

- U0: category 11 entity names bundled, GREEN `7750b2e`.
- U1: pure models/classifier/correlator, GREEN `c149326`.
- U1b: ESI names/faction round-trip and enrichment field, GREEN `67855f3`.
- Lead's visible history reports U0, U1, and U1b reviewed and approved.
- U2: service, ledger, provider, and prompt RED `4ed0654`; GREEN `ffb74a7`
  committed during this handoff by the existing implementation team. Lead was
  running focused validation; its result and U2 review were not yet confirmed.
- Next planned work: U3 scorer detail and U4 UI (can proceed in parallel after
  U2's gate), then U5 journal and U6 final checks/manual macOS verification.
- At the final source snapshot there were no tracked modifications; untracked
  `.claude/saga/` and `.hermes/` belong to existing work and were preserved.
- No application code was changed or tests run by the incoming architect.

## Architectural contracts to preserve

1. Classify the displayed log actor before matching. NPC names require bundled
   SDE category 11; missing names must degrade conservatively. Domain code is
   deterministic and performs no database or network I/O.
2. Candidate participants are attackers plus the victim, excluding the user.
   On a kill the opposing log actor may be the victim. NPC participants never
   pair with players. Final-blow timing applies only when the user is the victim.
3. Signal weights: name 0.75, ship 0.30, weapon 0.20, damage 0.20, timing 0.15,
   sole participant 0.10. Thresholds: confirmed 0.75, probable 0.50, possible
   0.30; ambiguity margin 0.10. Preserve the design's confidence caps.
4. Correlated + unattributed + NPC incoming damage must equal total received.
   Empty/Unknown actors contribute unattributed damage. Ambiguous assignments
   must not fabricate attribution.
5. Correlate after resolved killmail names. Preserve `character_name` and
   `faction_id` through JSON. `ensureAttackerCorrelation(encounter, enrichment)`
   handles legacy cached rows; `loadEnrichment(id)` lacks encounter inputs.
   Backfill once, do not write on failure, and avoid provider invalidation loops.
6. The optional correlation block is additive under existing prompt v4
   `killmailEvidence`. No new network calls or Drift migration. Correlation
   failure is non-fatal and must preserve existing evidence and enrichment.
7. Correlation changes evidence detail only, with no status, score, or action
   changes. Preserve Missing iff actionable. Killmails reveal the victim's fit;
   attacker hull identification does not reveal attacker modules.
8. Replace the Damage tab's Incoming Sources with the correlation section.
   Null correlation retains plain actor rows; show a blend advisory for two or
   more correlated participants. Per-attacker matchups remain deferred.
9. Preserve the earlier shared fitting-input loader and pure derivation layer,
   weighted EHP formula, explicit known-skills/All V provenance, and nonblocking
   evidence checklist. Journal records govern shipped decisions.
10. Add feature-tagged logging for code changes, use Riverpod `.when()` states,
    and resolve EVE IDs to names. The design's raw `Type #...` error fallback
    conflicts with the repository's no-raw-ID rule; resolve that conflict in U4
    using the repository rule before authoring the fallback/test expectations.

## Decision status and team routing

The old architect requested Product confirmation for corrected weights, replacing
Incoming Sources, and the S3 absent-attacker count correction. The committed
implementation plan adopts the design corrections and states no open blocking
questions. No separate Product acknowledgement was seen; do not reopen already
adopted implementation choices solely because the older pane recap is stale.

Observed team ownership (rediscover live names/IDs before future commands):

- `lead`, `wB:p3`: orchestration, unit gates, reviewer dispatch.
- `product`, `wB:p9`: product requirements.
- Planner was `plan`, `wB:p7`; that name stopped resolving during this handoff.
- `dev-1`, `wB:p4`: U2 GREEN implementation.
- `dev-2`, `wB:p5`: U1b GREEN; `dev-3`, `wB:p6`: additional developer.
- Reviewer, `wB:pA`: code review; no live name was advertised in the inventory.
- `test-author`, `wB:pB`: RED tests; `tester`, `wB:pD`: validation.

Architect's next responsibility is to resolve concrete design/implementation
questions from Lead, Plan, reviewers, or Product against these contracts. Do not
duplicate work already assigned to developers or claim pending gates have passed.

## Handoff checklist

- [x] Resolve caller and exact sibling through Herdr core.
- [x] Recover architect history, canonical designs, current plan, and live status.
- [x] Preserve context before closing the outgoing pane.
- [x] Close `wB:p8` and verify only the incoming pane remains in `wB:t8`.
- [x] Transfer the live name `arch` to `wB:pE`.

## Review

Context capture is complete. Herdr confirmed closure of `wB:p8`; the tab inventory
then showed only `wB:pE`, and `agent get arch` resolved to this Codex session.
The outgoing terminal was closed as requested; its canonical design documents and
this handoff remain in the repository. No application source was changed.

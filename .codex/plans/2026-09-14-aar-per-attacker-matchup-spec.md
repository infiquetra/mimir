# Milestone 5 product specification plan

Date: 2026-09-14
Baseline: `develop` at `d2dd731` (Milestone 4 merged).
Deliverable: `docs/specs/aar-per-attacker-matchup.md`.

## Authorization and scope

The user requests the complete specification now. Produce the requested product
artifact and the repository's required tracking/journal cross-references. No
application implementation, schema migration, release, or PR is part of this task.
Preserve existing untracked `.claude/saga/` and `.hermes/` work.
The repository tracks the case-insensitive local `.Codex` directory as `.codex`;
use that tracked spelling in portable links and Git paths.

## Steps

1. [P1] Read the requested source files and inspect damage resolution, EHP, hole
   assessment, fit provenance, provider composition, and the current prompt.
2. [P1] Have a read-only explorer check correlation identity, confidence, NPC,
   ambiguity, and kill/loss perspective contracts against the canonical design.
3. [SEQ] Write §§1–8: product problem; five scenarios; accounting and confidence
   invariants; concrete UI; deterministic evidence and schema policy; 28 acceptance
   criteria; 40 test cases; settled decisions and non-goals.
4. [P2] Have an independent agent review the draft for contract contradictions,
   testable requirements, and evidence overclaims. Verify arithmetic and references
   locally while that review runs.
5. [SEQ] Resolve findings, add concise README and journal links, and keep the
   implementation queued. Update todo review and context/checkpoint records.
6. [SEQ] Check the documentation diff and commit only this task's files.

## Validation

Check eight requested sections, five scenarios, 28 distinct acceptance criteria,
40 distinct domain/provider/UI tests, criterion traceability, local Markdown links,
worked arithmetic, and whitespace. Flutter runtime checks are unnecessary for
this documentation-only change; the test matrix specifies future implementation
verification rather than claiming those tests already exist or passed.

## Review

Completed all steps. Independent review passed after changing typed components to
lossless fractional quantities, preventing integer rounding from inventing a weapon
profile at small damage amounts. Verified numerical oracles, 200 randomized exact
conservation examples, all criterion/test references, specification links, table
structure, and whitespace. Implementation remains queued; no application code changed.

# Milestone 5 technical design checkpoint

Date: 2026-09-14 (America/Indiana/Indianapolis)
Baseline: `ed9e1ff`, branch `feature/aar-per-attacker-matchup`.

## Completed

- Authored [technical design](../../docs/specs/aar-per-attacker-matchup-design.md)
  from Product, handoff, prior designs and current domain/data/UI code.
- Six requested sections preserve ten architecture contracts, five scenarios,
  28 acceptance mappings and 40 domain/provider/UI RED/GREEN cases with U1–U4.
- Chose reduced BigInt rational allocation, separate validated M4 partition,
  reused local pilot-fit snapshot, explicit guarded incoming math, in-memory evidence
  and optional v4 payload. Cards are available before AI and preserve report history.
- Required supporting changes include local-only modifier lookups, per-subject fit
  error isolation, atomic lazy-backfill merge, coherent SDE revisions across windows
  and no raw-ID display paths. These are design instructions, not implemented code.
- Independent domain/integration reviews completed and all reported gaps addressed.
  Verified worked EHP/pressure oracles, 200 exact-rational conservation examples,
  all AC/test identifiers, local links, tables/fences, JSON sample and whitespace.
- README and journal cross-reference the design. M5 implementation remains queued.

## Limits and continuation

No application source changes, Flutter suites, deployment, PR or feature shipment.
Legacy M4 correlation has no original event fingerprint; the design explicitly
distinguishes structural compatibility from proof of original event lineage.
The implementation team should execute U1–U4 and capture actual runtime/visual evidence.
Existing untracked `.claude/saga/` and `.hermes/` files were preserved.

# Exploration Module Product handoff

Date: 2026-09-15
Branch / inspected baseline: `feature/exploration-module` / `aec65c6`.

## Completed

[Authoritative specification](../../docs/specs/exploration-module.md): eight
requested sections, S1–S9, R1–R32, AC1–AC40, F1–F8, 24 domain cases, 18 provider
cases and 18 UI cases. Documentation links, journal, plan and task review updated.
User decision: new tray-launched Exploration window with adaptive navigation
between Database, Thera & Turnur, Signature Tracker and Route Planner. Keep
character selection separate. Do not introduce an app-wide feature shell.

## Grounding and settled contracts

- Context library inspected at `3813f1a`; primary SDE build `3503375` and public
  EVE-Scout OpenAPI `2.1.55` verified. Sources and exact values are in the spec.
- Local universe/gate data is a required new foundation; existing SDE name/security
  placeholders do not satisfy offline lookup. Per-system statics need a separate
  source or an explicit Unavailable state.
- Legacy public endpoint returned 404; use v2 public signatures. Hub is `out_system`.
  Missing public mass status remains Unknown. K162 has no fixed type limits.
- Separate payload receipt, successful feed validation and upstream observation
  clocks. Five-minute shared request limit; routing eligibility ages without fetch.
- Clipboard preview is scoped, explicit and atomic. Rescans preserve annotations;
  cleanup moves expired observations to Trash. Only explicit destination verification
  creates a local edge, with its own 24-hour verification lifetime.
- Routes combine directed gates, eligible public edges and selected-character
  verified links. Canonical ranking, constraint handling and exact fixture outputs
  are defined; route results never promise safety or traversal.

## Validation

Two independent reviewers confirmed all findings resolved. Checked requirement,
criterion and test traceability; all local references; table structure and JSON;
186 displayed effect values; twelve route oracles; lifetime and resonance arithmetic.
No runtime application code changed and no Flutter suite ran for this specification.
The 60 implementation test cases are requirements, not claims of passing tests.

## Next steps

Plan produces architecture and estimates phases 4a–4d against the verified seams.
Test-Author builds the synthetic fixtures and mapped RED tests. Implementation,
responsive visual validation and tester signoff remain pending in QUEUED.md.
Fit comparison visuals and prior AAR initiatives are already shipped.

Preserve unrelated `.claude/saga/` and `.hermes/` files. No remote publication or
private mapper integration is part of this documentation task.

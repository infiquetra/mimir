# Corporation Module Product handoff

Date: 2026-09-15 (local)
Branch / inspected baseline: `feature/corporation-module` / `ccfe79b`.

## Completed

[Authoritative specification](../../docs/specs/corporation-module.md): eight
sections, phases 4e–4h, S1–S10, R1–R32, AC1–AC40, F1–F8 and 60 cases with
T01–T60 aliases (D01–D20, P01–P20, U01–U12, O01–O08). README, journal, plan and
task review updated. Dedicated tray-launched Corporation window is ID 15 with
Overview & Roster, Assets, Structures and Wallets plus active character selection.

## Grounding and decisions

- Context library `3813f1a`; current ESI OpenAPI effective version `2026-08-18`;
  CCP SDE build `3503375`. URLs and exact contract facts are in the specification.
- Basic roster is member-accessible with scope. Assets/division names require
  Director; structures require Station Manager or Director; wallets permit
  Accountant/Junior Accountant/Director. Scopes and roles remain distinct.
- Current public profile tax fields are percentages, not the legacy fraction;
  current CEO/alliance/founded fields can be absent. Pin explicit adapters.
- Private cache reads use selected character/corporation/capability/grant context
  and at most one-hour authorization leases. Known denial invalidates immediately.
  No automatic alt-token fallback. Public cached data remains readable offline.
- Ordinary token refresh preserves grant generation. Same-owner reauthorization
  quarantines unaffected retained history until a fresh capability check allows
  rebinding. Scope loss/departure/deletion still purges affected ownership.
- Complete page publication, distinct payload/source/validation clocks, durable
  multi-window request coordination and server cache/rate limits are mandatory.
- Structure expiry is separate from asset-observed fuel and modeled rates. Q/R is
  static stock endurance at its source time, not a new countdown when opened.
  Calculate previews; Save estimate persists. Critical alerts follow fresh ESI
  expiry, rearm only on fresh recovery and deduplicate durably.
- Corporate wallet decimal values, division identities, pagination, nulls and
  history coverage are explicit; journal/trade sums never reconstruct balance.

## Validation

Both independent reviewers confirmed their findings resolved. Checked current
ESI contracts, source SDE fuel facts, F3 distinct-asset sums, F4 service/stock and
threshold/episode arithmetic, F5 exact Decimal accounting, F6 cache deadlines,
60 identifiers/aliases, full AC mapping, JSON, local links, tables and whitespace.
No application files changed; no Flutter runtime suites ran. These 60 test cases
are implementation requirements, not claims of a verified feature.

## Next steps

Plan writes architecture and estimates phases 4e–4h with shared-file ownership.
Test-Author builds F1–F8 fixtures and mapped RED tests through real endpoints,
Drift/providers and the subwindow. Implementation and tester signoff remain queued.
Preserve unrelated `.claude/saga/` and `.hermes/`. No push, PR, management writes or
remote publication is part of this documentation task.

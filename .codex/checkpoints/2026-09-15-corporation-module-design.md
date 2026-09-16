# Corporation Module technical architecture handoff

Date: 2026-09-15 local. Branch: `feature/corporation-module`.
Product: `0abc4f6`; application baseline: `ccfe79b`.
Deliverable: [authoritative technical design](../../docs/specs/corporation-module-design.md).

## Completed

Seven requested sections; C0–C10 with file ownership, dependencies and RED/GREEN
gates; exact AC1–AC40 and T01–T60 mappings retaining D01–D20/P01–P20/U01–U12/O01–O08.
README, engineering journal, queue, plan, tasks and state updated in this change set.
No application implementation or runtime verification is claimed.

## Binding decisions

1. Actual installed Riverpod 3.0.3, Drift 2.31.0, AppDatabase 21→22, SDE 7.
2. Private authority is tenant/character/non-reused incarnation/corporation/grant/
   capability/resource; public references separate. No corporation-only cache.
3. Request eligibility and visibility permits differ. One-hour endpoint/required
   role evidence bounds offline access; normal refreshable token expiry alone does
   not shorten it. Known invalidation wins; equality locks.
4. Actual verified scopes, general/location/grantable roles and endpoint success
   remain distinct. NPC management prohibition does not hide authorized self data.
5. Atomic migration, central delete/switch/membership/grant transitions and CAS
   fences protect against late requests, auth callbacks and delete/re-add.
6. A logical dataset lease owns pagination/publication; subordinate page keys do
   not permit duplicate rounds. SQLite revisions/claims work across engines;
   event hints and connection-local Drift streams are not authority.
7. Raw exact decimal decoding precedes double conversion; bound digits/exponents;
   no REAL money accumulation. Asset trees honor location_type and conserve rows.
8. Reported expiry, observed bay and dated Q/R/manual scenarios are separate.
   Minimum supported fuel family requires a reviewed source manifest and proven
   ESI-label bundle/fitted-instance mapping, not guessed names.
9. Durable in-app alert episodes work without native opt-in. Main-only opt-in
   monitoring and generic native notifications use at-most-once handoff; ambiguous
   crash claims cannot guarantee OS delivery and are not automatically replayed.
10. Window 15 uses actual SubWindowApp/selector/visibility, no global SDE barrier;
    guarded `.when()` VMs, no raw visible IDs or formulas/private prior-owner data.

## Reviews and verification

Two independent read-only source/design reviews. Incorporated token/read eligibility,
whole-job ownership, self-capability, asset location_type, malformed history rollback,
numeric exponent bounds, clock-tick alert, real provider name, scenario CAS/busy
cancel and hidden-main revision findings. Mechanical checks compare all 60 case/AC
associations to Product and all 40 inverse rows; tables/links/JSON/whitespace and
independent F3/F4/F5/F6 arithmetic checked. Runtime tests not run (documentation only).

## Next work

Plan assigns named Test-Author/Dev/Reviewer/Tester for C0–C10 and shared-file ownership.
C0 establishes fixtures/harness and fuel evidence; C1 owns DB22, C2 auth/transport/
repositories, C3 roster, C4 assets, C5 fuel/alerts, C6 wallets, C7 window, C8/C9 views,
C10 release evidence. Preserve every Product variant and independent oracle.
Native OS permission/window checks, full-size p95 benchmarks and all executable
acceptance gates remain pending. Do not infer production-ready shared adapters from
Exploration's shipped label; the design lists the concrete inspected gaps.

Unrelated `.claude/saga/` and `.hermes/` were present and are not part of this commit.

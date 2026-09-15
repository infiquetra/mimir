# Exploration Module technical architecture handoff

Date: 2026-09-15. Role: Arch. Workspace context: wB / wB:pE.
Branch: `feature/exploration-module`.
Product commit: `287c8e7`; application baseline: `aec65c6`.

## Delivered

Authoritative [technical design](../../docs/specs/exploration-module-design.md),
all nine requested sections, X0–X10 work units, AC1–AC40 and T01–T60 traceability.
Product's D/P/U identifiers remain intact through an explicit alias bijection.
Fit comparison visuals are already shipped; Exploration implementation is pending.

## Decisions to preserve

1. Window ID14 appended; dedicated tray window, adaptive separate character/module
   navigation. Existing0–13 remain unchanged. Feature-scoped reference readiness
   keeps notebook and cached public views accessible on SDE failure.
2. SDE6→7 adds complete pinned exploration/universe/gate/effect data with manifest
   checksums/counts; atomic slice publication, version ordering and no downgrade.
   Group consensus loads every variant; effect beacon/scopes are authoritative.
3. AppDatabase20→21 stores feed, notebook episodes/links/scopes/receipts/preferences
   and last-known locations. Explicit UTC milliseconds, atomic bootstrap/version
   publication, partial active-code uniqueness and central character cleanup.
4. One all-hubs public v2 feed shared with Intel. SQLite claim/fence,15s abortable
   request,60s lease,≥300s attempt spacing/backoff;200/304 validation clock separate
   from payload/report times. Events are hints; reread revisions on resume and
   active5s local polls, never fetch from an observer notification.
5. No public mass inference. Validation5m/24h, local verification24h, expiry and
   EOL boundaries are local-clock inputs. Current origin valid through60s exactly;
   afterward block new current results until explicit refresh/Last known/manual.
6. Parser preview is write-free and scoped; selected apply is transactional with
   revisions and durable idempotency. Episode UUID owns links. Pruning is soft,
   window-scoped across selected-character notebooks; explicit verification alone
   creates/renews eligible links. Receipts survive selected hard deletion.
7. Pure tuple-cost Dijkstra preserves directed parallel edges and whole-path ties.
   Raw graph cache is separate from time/preference assessment. Diagnostic BFS
   disables only user avoids, never source eligibility. Nearest appends hub transit
   to one gate-only approach search under the identical objective.
8. Immutable source/time/request fingerprints, latest-result rejection, `.when()`
   branches and formula-free ViewModels. Private scopes never retain previous-pilot
   content. Busy commit freezes input and disables misleading Cancel/dismiss.
9. No raw numeric EVE names, no automatic clipboard/network writes, no mapper sync,
   no waypoint/bookmark writes, no Safe/ETA/ship-transit promise.

## Work units

- X0 contracts/fixtures/harness.
- X1 offline reference schema/extraction/import.
- X2 AppDatabase migration and ownership foundation.
- X3 shared public feed/client/cache.
- X4 notebook/parser/verification.
- X5 graph/eligibility/routing/nearest.
- X6 origin/providers/ViewModels/deadlines.
- X7 window/character/visibility integration.
- X8 reference/public UI and Intel adapter.
- X9 notebook/route UI.
- X10 release evidence/journal closeout.

X1/X2/X5/X7 can run after X0; X3/X4 need X2; X6 composes real seams;
X8/X9 follow X6/X7; X10 requires all. Shared file ownership is explicit in §7.

## Verification performed for this documentation

- Complete Product/source grounding and public read-only API probe: HTTP200,
  Cache-Control300s, ETag; OpenAPI2.1.55. No live pilot records copied into fixtures.
- Two independent reviews passed after corrections; no remaining material blocker.
- Checked all40 Product AC-to-case associations, all60 aliases,22 test file keys,
  nine main sections, table structure and local links/anchors.
- Independent documentation check reproduced12 synthetic Product route oracles.
- Documentation whitespace/staged-scope checks; no application implementation.

No Flutter runtime suites or performance benchmarks ran. The full dataset counts/
checksums must be generated from the pinned archive in X1; none were invented here.
No supplementary static source selected; honest Unavailable is supported.

## Next

Plan assigns units and owners. Test-Author produces RED evidence, Dev GREEN,
Reviewer contract/race review and Tester actual host/native/migration/offline/
responsive/performance evidence. Keep QUEUED until those gates pass. Preserve
unrelated untracked `.claude/saga/` and `.hermes/` directories.

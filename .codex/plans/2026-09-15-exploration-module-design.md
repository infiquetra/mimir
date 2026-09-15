# Exploration Module technical architecture plan

Date: 2026-09-15
Baseline: `feature/exploration-module`, Product commit `287c8e7`, application base `aec65c6`.

## Scope

Author and commit `docs/specs/exploration-module-design.md`. Product remains
authoritative. No application implementation or runtime test claims in this task.
The user's request authorizes this documentation plan and its execution.

## Tasks

- [x] Read Product requirements, fixtures and all acceptance/test cases.
- [x] [P1] Ground SDE/reference/routing seams (domain explorer).
- [x] [P1] Ground window, persistence and lifecycle seams (integration explorer).
- [x] [P1] Verify public API, cache, notebook and provider contracts (Arch).
- [x] [SEQ] Write nine-section design with typed contracts and X-unit ownership.
- [x] [SEQ] Map AC1–AC40 and canonical T01–T60 aliases to Product D/P/U cases.
- [x] [P2] Independent architecture review and deterministic documentation checks.
- [x] [SEQ] Update journal, README and handoff state without claiming shipment.
- [x] [CHECKPOINT] Save checkpoint and commit documentation only.

## Review

Completed the nine-section design with X0–X10, 40 AC rows and a bijection from
T01–T60 to Product D01–D24/P01–P18/U01–U18. Both independent reviews passed after
resolving variant paging, stale-origin gating, graph-cache/diagnostic separation,
version ordering, atomic migrations, window-scoped prune, idempotency tombstones,
full-character revision observation and busy cancellation. Checked source/API
contracts, all AC associations, file keys, Markdown structure/links and twelve
synthetic route oracles. Runtime tests were not run: documentation only.

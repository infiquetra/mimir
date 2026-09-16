# Corporation Module technical architecture plan

Date: 2026-09-15. Branch: `feature/corporation-module`.
Product: `0abc4f6`; application baseline: `ccfe79b`.

## Scope

Author and commit `docs/specs/corporation-module-design.md` with the requested
seven sections, C0–C10 and exact Product AC/test mappings. No application changes.
The user's request authorizes this documentation work and commit.

## Tasks

- [x] Read complete Product contract, F1–F8 and all 60 test cases.
- [x] [P1] Ground assets/fuel/wallet domain seams (domain explorer).
- [x] [P1] Ground database/window/provider/auth lifecycle seams (integration explorer).
- [x] [P1] Verify ESI contracts and design capability/cache/auth enforcement (Arch).
- [x] [SEQ] Write complete architecture, schemas, algorithms and UI/service seams.
- [x] [SEQ] Map AC1–AC40, T01–T60 and D/P/U/O IDs to C0–C10/test files.
- [x] [P2] Independent design reviews and documentation/oracle checks.
- [x] [SEQ] Update README/journal and handoff state; implementation stays pending.
- [x] [CHECKPOINT] Save checkpoint and include exact documentation scope in commit.

## Notes

The installed branch uses Riverpod 3, not the request's historical 2.0 label.
Review actual shipped seams; do not assume Exploration's release status proves
every provider/visibility adapter is durable production wiring.

## Review

Complete. Two independent source/design reviews; seven sections, 40 exact reverse
AC rows and 60 mapped D/P/U/O cases, with real-boundary TDD and C0–C10 ownership.
Resolved findings are reflected in the design and checkpoint. Only documentation
changed; implementation, executable tests, fuel-mapping proof, native evidence and
recorded performance targets remain pending.

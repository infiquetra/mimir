# AAR fit import and capture UI tests: product handoff plan

Date: 2026-09-14
Baseline: `develop` at `7db3630`; user confirms Milestone 5 verified and merged.
Deliverable: `docs/specs/aar-fit-import-capture-ui-tests.md`.

## Scope and authorization

The user requests the product perspective, grounded scenarios, matrix, and acceptance
criteria for Test-Author and Plan. Produce that documentation now. Application fixes
and test implementation belong to the subsequent execution plan. Preserve unrelated
`.claude/saga/` and `.hermes/` files and historical tracking records.

## Tasks

- [P1] Inspect current screen handlers, checklist, scoring, refresh and provenance.
- [P1] Delegate read-only analysis of existing tests, service/parser/asset contracts,
  and gaps to `fit_evidence_tests`.
- [SEQ] Write the product handoff, distinguishing shipped behavior, required regression
  coverage, and desired behavior that may need narrowly scoped fixes.
- [P2] Independently review the draft while checking scenario/criterion traceability,
  exact snackbar strings, numeric score examples, and local links.
- [SEQ] Link README and queued work, record durable findings, finalize tracking, and
  commit the documentation only.

## Validation

Source inspection and document checks; no live ESI/OAuth/AI calls and no claim that
new tests or application fixes have been implemented. Keep the queued item open.

## Review

Complete: nine scenarios, 24 acceptance criteria, 36 test cases. Independent review
and follow-up passed. Checked existing success/service-error strings, score arithmetic,
matrix uniqueness and traceability, table structure, links, and whitespace. Product
explicitly distinguishes live confirmed capture from service/legacy reference capture,
and baseline behavior from required validation/retention/concurrency hardening.

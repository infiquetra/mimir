# AAR fit import and capture UI tests: Product handoff complete

Date: 2026-09-14 (America/Indiana/Indianapolis)
Baseline: `develop` at `7db3630`
Branch: `chore/aar-fit-import-capture-ui-test-spec`

## Delivered

[Product contract](../../docs/specs/aar-fit-import-capture-ui-tests.md) with current
screen/service grounding, nine scenarios, feedback messages, AC1–AC24, T01–T36, and
test fixture/work sequencing guidance. User reports Milestone 5 verified and merged;
this handoff addresses the next P2 queued item.

## Important findings and decisions

- The live checklist exposes Import Fit and confirmed Use Current Fit only. The
  unconfirmed snapshot mode remains service/legacy compatibility, with Inferred evidence.
- Current AAR import can silently drop entries and routes colon-containing EFT to DNA.
  Product requires faithful-or-rejected input, preserving intentional hull-only fits.
- Successful empty inventory is a qualified hull-only capture; failed inventory never saves.
- Save completion, live evidence/defense refresh, and explicit AI re-analysis are separate.
- Forced enrichment refresh can overwrite the attached pilot fit. This is independently
  confirmed by source inspection; a runtime regression test and fix remain pending.
- New tests must cross real parser/ESI-mapper/repository/provider seams and the actual
  re-analysis flow, with external clients faked. Counter-only screen mocks are insufficient.
- Explicit analysis during a pending attachment waits for completion; delayed refresh
  cannot overwrite the final saved fit.

## Verification and next steps

Independent review passed. Verified 24 unique criteria, 36 unique referenced tests,
nine scenarios, table structure, links, existing snackbar/service-error strings, score
arithmetic, and whitespace. No Flutter runtime tests ran and no application code changed.
Test-Author and Plan own test implementation and narrowly scoped fixes next. Keep the
queue item open until verification; the spec is not a shipped test suite.

Existing `.claude/saga/` and `.hermes/` files remain untouched. No push, PR, or deployment
was requested. Historical Milestone 5 records are preserved.

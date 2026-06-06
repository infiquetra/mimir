# AGENTS.md

This file provides guidance to Codex when working with code in this repository.
Also read `CLAUDE.md`; it contains the Mimir architecture, build commands,
testing patterns, logging rules, and EVE-specific implementation guidance.

## Engineering Journal - AUTO-MAINTAIN

Living documentation at [`docs/engineering-journal/`](docs/engineering-journal/).
The pattern follows the original local exemplar in
`../home-lab/docs/engineering-journal/` and the reusable templates in
`../infiquetra-sdlc/templates/engineering-journal/`. The directory is the
engineering journal; the files inside are its sections.

| File | Purpose |
|------|---------|
| [LEARNINGS.md](docs/engineering-journal/LEARNINGS.md) | Empirical findings, mechanisms, fixes, and validations |
| [DECISIONS.md](docs/engineering-journal/DECISIONS.md) | Architecture and prompt-design decisions with rationale and revisit conditions |
| [QUEUED.md](docs/engineering-journal/QUEUED.md) | Future-work items by priority with concrete "worth it when" triggers |
| [ARCHIVE.md](docs/engineering-journal/ARCHIVE.md) | Shipped, rejected, and superseded journal items |
| [narratives/](docs/engineering-journal/narratives/) | Longer-form companion docs, design walkthroughs, and post-incident write-ups |
| [audits/](docs/engineering-journal/audits/) | Dated deep-dive audits or substantial review snapshots |

**Maintenance rules (Codex: follow these without being asked):**

1. **After a significant run or implementation** that produces a surprising
   result, bug, confirmed hypothesis, design insight, or integration gotcha,
   add a dated entry to `LEARNINGS.md`. Include evidence and the mechanism,
   not just the observation. Add a **Generalizable rule** line when useful.

2. **After committing to an architecture, prompt, data-contract, or process
   decision** such as choosing a schema version, prompt contract, parser
   strategy, API integration, cache strategy, or UI state model, add an entry
   to `DECISIONS.md` with rejected alternatives, rationale, and revisit-when.
   If no commit exists yet, write `commit: pending` and update it after commit.

3. **Whenever a promising idea surfaces but is not built now**, add it to
   `QUEUED.md` with priority, rough effort, worth-it-when trigger, and context.
   Do not rely on chat history or transient plans for important future work.

4. **When a queued item ships**, move it to `ARCHIVE.md` as SHIPPED with the
   date and commit/PR when available.

5. **When a queued item is rejected**, move it to `ARCHIVE.md` as REJECTED with
   the reason and revisit conditions.

6. **When a prior learning or decision is invalidated**, update the original
   entry inline and move the pre-correction version to `ARCHIVE.md` as
   SUPERSEDED. Never silently overwrite history.

7. **When something needs a longer write-up than fits in a core entry**, create
   `docs/engineering-journal/narratives/YYYY-MM-DD-short-slug.md` and link to
   it from the relevant entry.

Each core file contains its own format guidance. New entries should be concise,
newest-first, and evidence-backed. The journal is part of normal engineering
work; update it in the same change set as the implementation or discovery.

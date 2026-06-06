# Engineering Journal - Mimir

Living documentation for the Mimir Flutter EVE companion app. This journal
prevents repo-local knowledge loss across sessions, maintainers, and agents.

The journal is the directory; the core files plus `narratives/` and `audits/`
are its sections. Pattern adopted from the original local exemplar at
`../home-lab/docs/engineering-journal/` and the reusable scaffold at
`../infiquetra-sdlc/templates/engineering-journal/`.

## Files In This Folder

| File | What it holds | When to update |
|------|---------------|----------------|
| [LEARNINGS.md](LEARNINGS.md) | Empirical findings, mechanisms, fixes, and validations | When a run or implementation reveals something non-obvious |
| [DECISIONS.md](DECISIONS.md) | Architecture and prompt-design choices with rationale and revisit conditions | When Mimir commits to a path over alternatives |
| [QUEUED.md](QUEUED.md) | Future work by priority with "worth it when" triggers | When useful work is deferred |
| [ARCHIVE.md](ARCHIVE.md) | Shipped, rejected, and superseded items | When queued items ship or are rejected, or old entries are invalidated |
| [narratives/](narratives/) | Longer-form companion docs | When a topic needs standalone context |
| [audits/](audits/) | Dated deep-dive audits or substantial review snapshots | When a larger review or test run produces reusable findings |

## How To Maintain

The repo-level [`AGENTS.md`](../../AGENTS.md) tells Codex to maintain this
journal without being asked. The short version:

- Significant run or implementation with a non-obvious result: update `LEARNINGS.md`.
- Architecture, prompt, or data-contract decision: update `DECISIONS.md`.
- Good idea deferred: update `QUEUED.md`.
- Queued item ships or is rejected: move it to `ARCHIVE.md`.
- Old learning or decision is invalidated: correct inline and archive the prior version.
- Longer write-up needed: add a dated file under `narratives/` and link to it.

Keep entries newest-first, concise, and evidence-backed.

## Quick Navigation By Topic

- Combat analyzer AAR evidence ledger and fit evidence -> [DECISIONS](DECISIONS.md#combat-aar-v3-uses-evidence-ledger-and-fit-evidence-before-deeper-simulation)
- Combat logs as incomplete evidence -> [LEARNINGS](LEARNINGS.md#combat-logs-are-a-primary-source-but-not-a-complete-aar-evidence-source)
- Mimir-owned AI auth -> [DECISIONS](DECISIONS.md#ai-auth-is-mimir-owned-app-auth-not-codex-cli-mutation)
- Combat-log classification cache -> [LEARNINGS](LEARNINGS.md#eve-gamelog-folders-are-mostly-non-combat-and-need-cached-classification)
- Deferred AAR inference and simulation work -> [QUEUED](QUEUED.md#p1--aar-fit-simulation-and-defense-profile-derivation)

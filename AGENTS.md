# AGENTS.md

This file provides guidance to Codex when working with code in this repository.
Also read `CLAUDE.md`; it contains the Mimir architecture, build commands,
testing patterns, logging rules, and EVE-specific implementation guidance.

## 📓 Engineering journal — auto-maintain

Living journal at [`docs/engineering-journal/`](docs/engineering-journal/) (`LEARNINGS.md` / `DECISIONS.md` / `QUEUED.md` / `ARCHIVE.md` / `narratives/` / `audits/`). Follow the [shared engineering-journal practice](https://github.com/infiquetra/infiquetra-sdlc/blob/main/docs/process/engineering-journal.md) for the full pattern, and maintain it without being asked — capture durable learnings and decisions in the same change set that ships the work.

Repo-specific signals worth a `LEARNINGS.md` entry: prompt-contract and parser-strategy surprises, schema-version changes, EVE API integration gotchas, and cache-strategy or UI-state-model decisions.

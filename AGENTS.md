# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Purpose

Mimir is a Flutter-based EVE Online companion app (macOS first, mobile to follow):
character dashboard, skill-queue monitoring, wallet history, and multi-character
switching. Also read `CLAUDE.md`; it carries the full Mimir architecture, the
data-refresh and AsyncValue patterns, logging rules, and the EVE ID-resolution
guidance that this file deliberately does not duplicate.

## Commands

```bash
flutter pub get          # install dependencies
flutter run -d macos     # run on macOS
flutter test             # run unit + widget tests
flutter analyze          # static analysis
dart format .            # format
```

## Repo-specific rule

Every code change MUST add appropriate debug logging via
`package:mimir/core/logging/logger.dart` with a `[FEATURE]` tag (see `CLAUDE.md`
> Debug Logging Requirements). Resolve EVE numeric IDs to names — never display
raw IDs (`skillNameProvider` for skills, `itemNameProvider`/`locationNameProvider`
otherwise).

## 📓 Engineering journal — auto-maintain

Living journal at [`docs/engineering-journal/`](docs/engineering-journal/) (`LEARNINGS.md` / `DECISIONS.md` / `QUEUED.md` / `ARCHIVE.md` / `narratives/` / `audits/`). Follow the [shared engineering-journal practice](https://github.com/infiquetra/infiquetra-sdlc/blob/main/docs/process/engineering-journal.md) for the full pattern, and maintain it without being asked — capture durable learnings and decisions in the same change set that ships the work.

Repo-specific signals worth a `LEARNINGS.md` entry: prompt-contract and parser-strategy surprises, schema-version changes, EVE API integration gotchas, and cache-strategy or UI-state-model decisions.

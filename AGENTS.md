# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Purpose

Mimir is a Rust/egui EVE Online companion app (the Flutter app was retired on
the `rust-rewrite` branch; see `docs/rust-rewrite-design.md`): character
dashboard, skill-queue monitoring, wallet history, and multi-character
switching.

## Commands

```bash
cargo run -- --demo      # demo mode, bundled sample data
cargo run                # live mode (EVE SSO)
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt
```

## Repo-specific rule

Every code change MUST add appropriate `tracing` debug logging with a
bracketed feature tag (`[AUTH]`, `[ESI]`, `[WALLET]`, `[SKILLS]`, `[CHAR]`,
`[DB]`, `[DEMO]`, `[UI]`, `[STARTUP]`). Never log access or refresh tokens.
Resolve EVE numeric IDs to names — never display raw IDs (`Sde::skill_name`
for skills, `NameResolver::name`/`location_name` otherwise; unresolved shows
`Unknown Item`/`Unknown Location`).

## 📓 Engineering journal — auto-maintain

Living journal at [`docs/engineering-journal/`](docs/engineering-journal/) (`LEARNINGS.md` / `DECISIONS.md` / `QUEUED.md` / `ARCHIVE.md` / `narratives/` / `audits/`). Follow the [shared engineering-journal practice](https://github.com/infiquetra/infiquetra-sdlc/blob/main/docs/process/engineering-journal.md) for the full pattern, and maintain it without being asked — capture durable learnings and decisions in the same change set that ships the work.

Repo-specific signals worth a `LEARNINGS.md` entry: prompt-contract and parser-strategy surprises, schema-version changes, EVE API integration gotchas, and cache-strategy or UI-state-model decisions.

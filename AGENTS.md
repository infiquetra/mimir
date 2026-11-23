# AGENTS.md

Guidance for coding agents working in this repository.

## Purpose

Mimir is a Rust/egui EVE Online companion application (single-window desktop
app; the Flutter app was retired on the `rust-rewrite` branch — see
`docs/rust-rewrite-design.md`):

- Multi-character dashboard and character switching
- Skill queue monitoring, bundled SDE skill catalogue, and local skill plans
- Wallet balance, analytics, journal, and market transactions
- Assets, market orders/history, trade calculator, industry, planetary colonies,
  ship fittings (EFT import/edit/save + stats), exploration reference, and settings

## Commands

```bash
cargo run -- --demo                  # bundled offline demo data (in-memory DB)
cargo run -- --demo --view <name>    # start demo directly on a named view (e.g. fittings)
cargo run                            # live mode (EVE SSO PKCE + OS keyring)
cargo test                           # unit + integration tests
cargo clippy --all-targets -- -D warnings
cargo fmt --check                    # use `cargo fmt` to apply formatting
cargo build
./scripts/bundle-macos.sh --install --open   # macOS only: package Mimir.app, install, launch
```

All PRs run `CI/Analyze`, `CI/Test`, and `CI/Build (macOS)`.

## Architecture & Data Flow

```
ESI API (reqwest + JWKS-verified OAuth2)
  -> src/app/shell.rs background workers
  -> src/storage/ (SQLite via rusqlite, live mode only)
  -> src/app/state.rs (AppState / LoadState<T>)
  -> src/ui/ (egui immediate-mode views)
```

Key directories:

- `src/main.rs` — CLI flags (`--demo`, `--view`), tracing buffer setup, Tokio
  runtime, SQLite opening (`open_in_memory()` in demo mode; `db::db_path()`
  when live), `eframe::run_native`
- `src/app/` — `state.rs` (`AppState`, `View` enum + `--view` CLI lookup,
  `LoadState`) and `shell.rs` (`MimirApp` frame loop, background
  ESI/auth/portrait workers, keyboard nav)
- `src/auth/` — EVE SSO OAuth2 PKCE (`oauth.rs`), loopback callback server,
  JWT/JWKS verification, OS keyring / fallback token storage (`TokenStore`)
- `src/esi/` — rate-limited/cached ESI HTTP client (`client.rs`), paginated
  endpoint walkers (`endpoints.rs`), serde models (`models.rs`)
- `src/storage/` — SQLite schema (`schema.sql`), connection helpers (`db.rs`),
  CRUD repositories (`repositories.rs`)
- `src/names/` — `NameResolver` (`/universe/names/` + DB cache) and bundled
  static extracts (`sde.rs`, `fitting_types.rs`, `industry_ref.rs`,
  `planet_schematics.rs`, `exploration_ref.rs`)
- `src/fitting/` — EFT/DNA parser/editor/writer, slot layout, ship
  stat/resource/tank/capacitor/nav-targeting calculators (resources, DPS,
  resistances, EHP, capacitor stability, peak recharge, active repair)
- `src/skills/` — local skill plans (`plans.rs`), prerequisite resolver, and
  training time estimates
- `src/demo/` — offline demo bundle loader (`assets/demo/*.json`) and state
  seeding, loaded cleanly into memory
- `src/ui/` — immediate-mode egui view modules (`dashboard`, `characters`,
  `skills`, `wallet`, `assets`, `market`, `industry`, `planets`, `fittings`,
  `settings`, `exploration`) plus shared `widgets` and `portraits`

## Repo-specific rules

1. **Tracing logs**: Every code change MUST include appropriate `tracing` debug
   logging with a bracketed feature tag from the canonical `LOG_TAGS`: `[AUTH]`,
   `[ESI]`, `[ASSETS]`, `[WALLET]`, `[SKILLS]`, `[CHAR]`, `[MARKET]`,
   `[INDUSTRY]`, `[PI]`, `[FITTING]`, `[EXPLORE]`, `[DB]`, `[DEMO]`,
   `[PORTRAIT]`, `[UI]`, `[STARTUP]`, `[PLANS]`. Never log access or refresh
   tokens, secrets, or CSRF state values.
2. **EVE ID resolution**: Never display raw numeric EVE IDs in UI or logs.
   Use `Sde::skill_name` / `Sde::skill_name_quiet` for skills and `NameResolver`
   (`name` -> `Unknown Item`, `location_name` -> `Unknown Location`) otherwise;
   unresolved entries show `Unknown Item` / `Unknown Location`.
3. **Async/UI discipline**: Keep `AppState` transitions atomic on character
   switches, removals, and demo exit so stale character data cannot bleed
   between characters or into `mimir.db`.
4. **Keyboard focus and text input**: Gate single-key navigation (`1`-`9`, `0`,
   `E`, `/`, PageUp/PageDown) with
   `self.state.text_input_focused || ctx.wants_keyboard_input()` so typing in
   egui text widgets is never swallowed.
5. **Demo isolation**: Never open or mutate `db::db_path()` or persist
   `startup_view` while `demo` is true.
6. **UI copy locks**: Many strings and error counts in `src/ui/*` and
   `src/fitting/*` are pinned verbatim by unit/integration tests and design
   specs — verify with `cargo test` after any wording edit.
7. **Verification**: Always pass `cargo fmt --check`, `cargo clippy
   --all-targets -- -D warnings`, `cargo test`, and `cargo build` before PRs.

## 📓 Engineering journal — auto-maintain

Living journal at [`docs/engineering-journal/`](docs/engineering-journal/) (`LEARNINGS.md` / `DECISIONS.md` / `QUEUED.md` / `ARCHIVE.md` / `narratives/` / `audits/`). Follow the [shared engineering-journal practice](https://github.com/infiquetra/infiquetra-sdlc/blob/main/docs/process/engineering-journal.md) for the full pattern, and maintain it without being asked — capture durable learnings and decisions in the same change set that ships the work.

Repo-specific signals worth a `LEARNINGS.md` entry: prompt-contract and parser-strategy surprises, schema-version changes, EVE API integration gotchas, and cache-strategy or UI-state-model decisions.

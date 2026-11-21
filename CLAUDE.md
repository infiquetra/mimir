# CLAUDE.md

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
cargo run -- --demo --view fittings  # start demo directly on a named view
cargo run                            # live mode (EVE SSO PKCE + OS keyring)
cargo test                           # unit + integration tests
cargo clippy --all-targets -- -D warnings
cargo fmt --check
cargo build
```

## Architecture

- `src/main.rs` — CLI flags (`--demo`, `--view`), tracing buffer setup, Tokio
  runtime, SQLite opening (`open_in_memory()` in demo mode; `db::db_path()`
  when live), `eframe::run_native`
- `src/app/` — `state.rs` (`AppState`, `View`, `LoadState`) and `shell.rs`
  (`MimirApp` frame loop, background ESI/auth/portrait workers, keyboard nav)
- `src/auth/` — EVE SSO OAuth2 PKCE, loopback callback server, JWT/JWKS
  verification, OS keyring / fallback token storage
- `src/esi/` — ESI HTTP client (`client.rs`), paginated endpoints
  (`endpoints.rs`), serde models (`models.rs`)
- `src/storage/` — SQLite schema (`schema.sql`), connection helpers (`db.rs`),
  CRUD repositories (`repositories.rs`)
- `src/names/` — `NameResolver` (`/universe/names/` + DB cache) and bundled
  static extracts (`sde.rs`, `fitting_types.rs`, `industry_ref.rs`,
  `planet_schematics.rs`, `exploration_ref.rs`)
- `src/fitting/` — EFT parser/editor/writer, DNA, slot layout, resources, DPS,
  resistances, EHP, capacitor stability, peak recharge, active repair, nav/targeting
- `src/skills/` — local skill plans, prerequisites, and training time estimates
- `src/demo/` — offline demo bundle loader (`assets/demo/`) and state seeding
- `src/ui/` — immediate-mode egui panels per view plus `widgets.rs` & `portraits.rs`

## Repo-Specific Rules

1. **Tracing logs**: Every code change MUST include appropriate `tracing`
   logging with a bracketed feature tag (`[AUTH]`, `[ESI]`, `[ASSETS]`,
   `[WALLET]`, `[SKILLS]`, `[CHAR]`, `[MARKET]`, `[INDUSTRY]`, `[PI]`,
   `[FITTING]`, `[EXPLORE]`, `[DB]`, `[DEMO]`, `[PORTRAIT]`, `[UI]`,
   `[STARTUP]`, `[PLANS]`). Never log access or refresh tokens.
2. **EVE ID resolution**: Never display raw numeric EVE IDs in UI or logs.
   Use `Sde::skill_name` / `Sde::skill_name_quiet` for skills and `NameResolver`
   (`name` -> `Unknown Item`, `location_name` -> `Unknown Location`) otherwise.
3. **Async/UI discipline**: Keep `AppState` transitions atomic on character
   switches, removals, and demo exit so stale character data cannot bleed
   between characters or into `mimir.db`.
4. **Verification**: Always pass `cargo fmt --check`, `cargo clippy
   --all-targets -- -D warnings`, `cargo test`, and `cargo build` before PRs.
5. **Engineering journal**: Maintain `docs/engineering-journal/DECISIONS.md`
   and `LEARNINGS.md` in the same change set that ships durable decisions or
   non-obvious fixes.

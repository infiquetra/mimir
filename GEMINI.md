# GEMINI.md

Guidance for Gemini agents working in this repository.

## Purpose

Mimir is a single-window Rust/egui desktop companion for EVE Online (the Flutter
app was retired on the `rust-rewrite` branch; see `docs/rust-rewrite-design.md`).

## Build & Verification Commands

```bash
cargo run -- --demo                  # bundled offline demo mode (in-memory DB)
cargo run -- --demo --view <name>    # open demo directly on a specific view
cargo run                            # live mode (EVE SSO login in-app)
cargo test                           # unit + integration tests
cargo clippy --all-targets -- -D warnings
cargo fmt --check
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
- `src/app/` — `AppState`, `View` enum + `--view` CLI lookup, `MimirApp` shell
- `src/auth/` — OAuth2 PKCE (`oauth.rs`), callback HTTP listener, JWT/JWKS verifier, keyring `TokenStore`
- `src/esi/` — rate-limited/cached HTTP client (`client.rs`), endpoint walkers (`endpoints.rs`), serde models (`models.rs`)
- `src/fitting/` — EFT/DNA parsing, fitting editor, ship stat/resource/tank/capacitor/nav-targeting calculators
- `src/names/` — bundled SDE/reference extracts (`sde.rs`, `fitting_types.rs`, `industry_ref.rs`, `planet_schematics.rs`, `exploration_ref.rs`) and `NameResolver`
- `src/skills/` — local skill plans (`plans.rs`), prerequisite resolver, training estimator
- `src/demo/` — offline sample data (`assets/demo/*.json`) seeded cleanly into memory
- `src/ui/` — view modules (`dashboard`, `characters`, `skills`, `wallet`, `assets`, `market`, `industry`, `planets`, `fittings`, `settings`, `exploration`) plus shared `widgets` and `portraits`

## Mandatory Conventions

- **Structured tracing with bracketed tags**: Every change must emit relevant `tracing` logs using the canonical `LOG_TAGS` (`[AUTH]`, `[ESI]`, `[ASSETS]`, `[WALLET]`, `[SKILLS]`, `[CHAR]`, `[MARKET]`, `[INDUSTRY]`, `[PI]`, `[FITTING]`, `[EXPLORE]`, `[DB]`, `[DEMO]`, `[PORTRAIT]`, `[UI]`, `[STARTUP]`, `[PLANS]`). Never log tokens, secrets, or CSRF state values.
- **No raw EVE IDs in UI**: Resolve skills through `Sde` and all other types/locations/entities through `NameResolver` (`Unknown Item` / `Unknown Location` fallbacks).
- **Keyboard focus & text input**: Gate single-key navigation (`1`-`9`, `0`, `E`, `/`, PageUp/PageDown) with `self.state.text_input_focused || ctx.wants_keyboard_input()` so typing in egui text widgets is never swallowed.
- **Demo isolation**: Never open or mutate `db::db_path()` or persist `startup_view` while `demo` is true.
- **UI copy locks**: Many strings and error counts in `src/ui/*` and `src/fitting/*` are pinned verbatim by unit/integration tests and design specs — verify with `cargo test` after any wording edit.
- **Engineering journal**: Keep `docs/engineering-journal/{DECISIONS,LEARNINGS}.md` current in the same commit/PR when making architectural choices or fixing non-obvious bugs.

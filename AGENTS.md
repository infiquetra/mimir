# AGENTS.md

Guidance for coding agents (Muse, Claude Code, Codex, OpenCode, Cursor, Hermes, and Antigravity/Gemini) working in this repository.

## Purpose & Brand Identity

**Alidade** (repository slug `infiquetra/mimir`, context library [`infiquetra/mimir-context-library`](https://github.com/infiquetra/mimir-context-library), governed on GitHub Project #16) is a native Rust desktop astrometric, industrial, and fitting companion for EVE Online.

- **Current baseline (`main`)**: Single-window Rust `eframe`/`egui` app (`Cargo.toml`, `src/`) with multi-character dashboard, EVE SSO OAuth2 PKCE + JWKS verification, OS keyring token store, SQLite offline cache (`rusqlite`), skills/plans, wallet analytics, assets, market orders/trade calculator, industry calculators, planetary summaries, saved/imported ship fittings, and offline exploration reference (the legacy Flutter app was retired on `rust-rewrite`; see `docs/rust-rewrite-design.md`).
- **Target architecture (`STRATEGY.md` & `mimir-context-library`)**: `egui 0.37` + `eframe` on native `wgpu` (Metal on macOS), Rerun-inspired `DesignTokens` + `egui_tiles` workspace, `egui_wgpu::CallbackTrait` 120 fps 2D/3D star maps & WGSL polar envelopes, `egui-snarl` + `kurbo`/`lyon` Sankey-DAG industry/PI pipelines, dynamic `SDE over HTTP`, real-time local EVE log + clipboard telemetry, and solver-backed AI copilots (Home Lab local OpenAI-compatible endpoints + OS keyring BYOK).

## Mandatory Multi-Agent UI & Visualization Skills

Whenever touching `src/ui/`, `src/app/shell.rs`, `Cargo.toml` UI/graphics crates, shaders, visual layouts, or UI tests, you **MUST** read and follow the repository skills in `.agents/skills/` (also linked at `.claude/skills/` and `.cursor/skills/`, and installable into **Muse** via `python3 scripts/stage-muse-skills.py --install`):

| Skill | Path | Mandatory Trigger |
|---|---|---|
| **`alidade-ui-design`** | [`.agents/skills/alidade-ui-design/SKILL.md`](.agents/skills/alidade-ui-design/SKILL.md) | Any UI layout, theme, typography, color token, navigation, docking, or view redesign. Enforces the HTML/Canvas Prototype Gate in `mimir-context-library/platform-specs/ui-mockups/`, strict 3-size body typography with tabular numerals, Rerun-style zero-clutter dark `DesignTokens`, and "less text, more visual" information density. |
| **`alidade-wgpu-viz`** | [`.agents/skills/alidade-wgpu-viz/SKILL.md`](.agents/skills/alidade-wgpu-viz/SKILL.md) | Building or modifying node/DAG/Sankey graphs (`petgraph` + `dagre` + `egui-snarl` + `kurbo`/`lyon`), 2D/3D star maps (`egui_wgpu::CallbackTrait` + `kiddo`), radial fitting wheels, WGSL polar envelopes, or `egui_plot` timelines. |
| **`alidade-visual-qa`** | [`.agents/skills/alidade-visual-qa/SKILL.md`](.agents/skills/alidade-visual-qa/SKILL.md) | Verifying any UI or visual change. Enforces Tier 1 headless `egui_kittest` snapshot + AccessKit label gates in `cargo test` AND Tier 2 locked SSH visual verification inside the hidden `macos-test-02` UTM guest (`--demo --view <name>`). **Never open GUI test windows on the operator's host Mac.** |

## Commands

```bash
cargo run -- --demo                        # bundled offline demo data (in-memory DB)
cargo run -- --demo --view <name>          # start demo directly on a named view (e.g. fittings)
cargo run                                  # live mode (EVE SSO PKCE + OS keyring)
cargo test                                 # unit + integration tests
cargo clippy --all-targets -- -D warnings  # zero-warning lint gate
cargo fmt --check                          # use `cargo fmt` to apply formatting
cargo build
./scripts/bundle-macos.sh --install --open # macOS packaging (run GUI launches inside UTM guest during automated QA!)
python3 scripts/stage-muse-skills.py --check # verify Muse skill bundle projection
```

All PRs target `main` and run `CI/Analyze`, `CI/Test`, and `CI/Build (macOS)`.

## Architecture & Data Flow

```
ESI OpenAPI + SDE-over-HTTP + Local EVE Logs
  -> src/app/shell.rs background workers
  -> src/storage/ (SQLite via rusqlite, live mode only)
  -> src/app/state.rs (AppState / LoadState<T>)
  -> src/ui/ (egui views + wgpu spatial/flow canvases)
```

Key directories:

- `src/main.rs` — CLI flags (`--demo`, `--view`), tracing buffer setup, Tokio runtime, SQLite opening (`open_in_memory()` in demo mode; `db::db_path()` when live), `eframe::run_native`
- `src/app/` — `state.rs` (`AppState`, `View` enum + `--view` CLI lookup, `LoadState`) and `shell.rs` (`MimirApp` / Alidade frame loop, background ESI/auth/portrait workers, keyboard nav)
- `src/auth/` — EVE SSO OAuth2 PKCE (`oauth.rs`), loopback callback server, JWT/JWKS verification, OS keyring / `0600` fallback token storage (`TokenStore`)
- `src/esi/` — rate-limited/cached ESI HTTP client (`client.rs`), endpoint walkers (`endpoints.rs`), serde models (`models.rs`)
- `src/storage/` — SQLite schema (`schema.sql`), connection helpers (`db.rs`), CRUD repositories (`repositories.rs`)
- `src/names/` — `NameResolver` (`universe/names` + DB cache) and SDE catalogues (`sde.rs`, `fitting_types.rs`, `industry_ref.rs`, `planet_schematics.rs`, `exploration_ref.rs`)
- `src/fitting/` — EFT/DNA parser/editor/writer, slot layout, ship stat/resource/tank/capacitor/nav-targeting calculators
- `src/skills/` — local skill plans (`plans.rs`), prerequisite resolver, and training time estimates
- `src/demo/` — offline demo bundle loader (`assets/demo/*.json`) and state seeding
- `src/ui/` — immediate-mode egui view modules + shared `theme`, `widgets`, and `portraits`

## Repo-Specific Invariants

1. **Tracing logs**: Every code change MUST include appropriate `tracing` debug logging with a bracketed feature tag from `LOG_TAGS`: `[AUTH]`, `[ESI]`, `[ASSETS]`, `[WALLET]`, `[SKILLS]`, `[CHAR]`, `[MARKET]`, `[INDUSTRY]`, `[PI]`, `[FITTING]`, `[EXPLORE]`, `[DB]`, `[DEMO]`, `[PORTRAIT]`, `[UI]`, `[STARTUP]`, `[PLANS]`, `[SDE]`. Never log access/refresh tokens, API keys, or CSRF state values.
2. **EVE ID resolution**: Never display raw numeric EVE IDs in UI or logs. Use `Sde::skill_name` / `Sde::skill_name_quiet` for skills and `NameResolver` (`name` -> `Unknown Item`, `location_name` -> `Unknown Location`) otherwise.
3. **Async/UI discipline**: Keep `AppState` transitions atomic on character switches, removals, and demo exit so stale character data cannot bleed across characters or into live SQLite.
4. **Keyboard focus and text input**: Gate single-key navigation (`1`-`9`, `0`, `E`, `/`, PageUp/PageDown) with `self.state.text_input_focused || ctx.wants_keyboard_input()`.
5. **Demo & host-desktop isolation**: Never open or mutate `db::db_path()` or persist `startup_view` while `demo` is true. Never pop GUI windows or run desktop input/screen capture on the operator's host Mac—use headless `egui_kittest` on host and SSH into `macos-test-02` UTM guest for full window QA.
6. **Solver-grounded AI**: Any AI copilot workflow (AAR, fitting, Pantry, industry, mining) must validate candidate outputs through deterministic Rust domain solvers before rendering; never present unverified LLM math as game truth, and keep list/view navigation strictly free of automatic LLM network calls.
7. **UI copy locks & verification**: Existing strings and counts in `src/ui/*` and `src/fitting/*` are pinned by unit/integration tests—update tests intentionally alongside approved UI redesign slices and always pass `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build` before PRs.

## Engineering Journal — Auto-Maintain

Living journal at [`docs/engineering-journal/`](docs/engineering-journal/) (`LEARNINGS.md` / `DECISIONS.md` / `QUEUED.md` / `ARCHIVE.md` / `narratives/` / `audits/`). Follow the [shared engineering-journal practice](https://github.com/infiquetra/infiquetra-sdlc/blob/main/docs/process/engineering-journal.md) and capture durable learnings and decisions in the same change set that ships the work.

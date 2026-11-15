# Mimir Rust Rewrite — Design (90-minute buildable increment)

Status: design only. No Rust code is created by this document.
Repo: `/home/jefcox/workspace/infiquetra/mimir` (Flutter today, branch `develop`).
Host verified: Linux `dev-4`, `rustc 1.99.1`, `cargo 1.99.1`. macOS is the
product target but is **unverified from this host** (no Mac, UTM, Tailscale,
or SSH route reachable); everything below must `cargo build` and
`cargo test` on Linux first.

## 1. Decisions (each with the reason)

| Decision | Choice | Why (inspected evidence) |
|---|---|---|
| Language / shape | Pure Rust, one binary crate `mimir`, no Dart/Flutter, no JavaScript frontend | Task constraint. Single binary keeps the 90-minute increment shippable. |
| GUI | **eframe / egui** (immediate mode), one window with switchable views | Default per task; no inspected evidence forces another pure-Rust GUI. egui needs no retained widget tree, no async UI runtime, and renders identically on Linux and macOS, which is what a Linux-built, macOS-targeted app needs. Rejected: iced (Elm architecture costs more boilerplate per view), Slint/Dioxus/Tauri (extra markup/JS/WebView surface, violates no-JS spirit), raw winit+wgpu (weeks, not 90 minutes). |
| Windows model | **One egui window, left character rail + view switcher** replaces Flutter's 16 `desktop_multi_window` windows + tray host (`lib/main.dart`, `lib/core/window/window_types.dart`, `lib/core/tray/tray_service.dart`) | egui multi-window + tray is the highest-risk item for 90 minutes. One window preserves every screen's *content* (parity of function) and defers tray/multi-window (parity of chrome) to a named follow-up. This is a deliberate, recorded deviation — see the parity map. |
| Async + HTTP | `tokio` (multi-thread runtime owned beside egui) + `reqwest` (rustls, json) | Task constraint. Mirrors Dio in `lib/core/network/esi_client.dart` (base `https://esi.evetech.net/latest`, `datasource=tranquility`, 30 s timeouts, Bearer auth, `X-ESI-Error-Limit-*` tracking). rustls avoids a system OpenSSL dependency on both hosts. |
| Auth | EVE SSO OAuth2 + PKCE (S256), localhost callback `127.0.0.1:54321/callback`, browser opened via `open` crate | Exactly the shipped Flutter primary path (`lib/core/auth/oauth_service.dart`, `lib/core/auth/auth_providers.dart`, `oauth_callback_server.dart`); the `eveauth-mimir://` deep-link path is dropped (needs native URL-scheme registration; localhost needs none). No client secret; public PKCE client id carried over from `lib/core/config/eve_config.dart` (value not reproduced here; it is public by design). |
| Token storage | OS keyring via `keyring` crate; fallback file `tokens.json` with mode `0600` in the app data dir when no keyring backend answers (headless Linux) | Task constraint. Strictly better than Flutter's current plaintext tokens inside `mimir.db` (`lib/core/auth/token_manager.dart`, `app_database.dart` Characters row) — do not replicate that. |
| Cache | **rusqlite with `bundled` SQLite**, one file `mimir.db` in the app data dir | Flutter already proves this shape (Drift/SQLite `mimir.db`, schema v22, 72 tables). SQLite gives the wallet 30-day aggregates and name-cache lookups as SQL instead of hand-rolled JSON scans, and `bundled` removes the system-libsqlite risk on macOS. JSON files rejected: every aggregate/filter becomes bespoke code and concurrent refresh writes need hand-made locking. |
| Offline demo | `--demo` flag / first-run "Try demo" button loads bundled sample data (`assets/demo/*.json`, compiled in with `include_str!`) into an in-memory/temp DB; no EVE credentials, no network | Task constraint; also the only way to verify UI on this host without a live EVE login. Demo data uses invented characters, never real player data. |
| Logging | `tracing` + `tracing-subscriber` (env-filter), every log line carries a bracketed tag: `[AUTH] [ESI] [WALLET] [SKILLS] [CHAR] [DB] [DEMO] [UI] [STARTUP]` | Ports `lib/core/logging/logger.dart` (`Log.d/i/w/e` + `[FEATURE]` tags, `CLAUDE.md` Debug Logging Requirements). **Access and refresh tokens are never logged** — token types implement a redacted `Debug`. |
| ID resolution | Skills: bundled SDE extract `assets/sde/skills.json` (id → name/group). Everything else: `POST /universe/names/` with SQLite `universe_names` cache; structures via authenticated `GET /universe/structures/{id}/` (403 → "Unknown Location") | Ports the two-system rule in `CLAUDE.md` (EVE ID Resolution) and `lib/features/wallet/data/wallet_providers.dart` (`itemNameProvider`/`locationNameProvider` → `Unknown Item`/`Unknown Location`). **The UI never shows a raw numeric ID**; unresolved skills show `Skill #<id>` only as the SDE-miss fallback, matching Flutter. |
| First-auth scopes | `publicData` + `esi-skills.read_skills.v1` + `esi-skills.read_skillqueue.v1` + `esi-wallet.read_character_wallet.v1` + `esi-clones.read_implants.v1` | Resolves the context-library conflict (09 vs ADR-007) in favor of ADR-007 least-privilege + implants for the training calculator. The full 18-scope union in `EveConfig.scopesString` and the 10 corporation scopes become **progressive step-up** requests when those views are first opened. |

Offline-crate warning (from the host probe): the local cargo cache (730
crates) contains `tokio`, `serde`, `tracing`, `chrono`, `anyhow`,
`thiserror`, `url`, `sha2`, `base64`, `rand` — but **not** `eframe`/`egui`,
`reqwest`, `rusqlite`, `keyring`, or `oauth2`. The first build therefore
needs live crates.io access (or vendoring). The scaffold step must prove
`cargo fetch` before the four builders start; if the network is refused,
stop and report — do not silently substitute a different GUI.

## 2. Exact crate dependency list (`Cargo.toml`, scaffold-owned)

```toml
[package]
name = "mimir"
version = "0.1.0"
edition = "2021"

[dependencies]
eframe = "0.29"            # egui app shell (default features: glow, wayland+x11 on Linux)
egui = "0.29"
egui_extras = { version = "0.29", features = ["image"] }
tokio = { version = "1", features = ["rt-multi-thread", "macros", "sync", "time", "net"] }
reqwest = { version = "0.12", default-features = false, features = ["json", "rustls-tls"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rusqlite = { version = "0.32", features = ["bundled"] }
keyring = "3"
oauth2 = "4"               # PKCE primitives only; HTTP goes through our reqwest client
sha2 = "0.10"
base64 = "0.22"
rand = "0.8"
url = "2"
chrono = { version = "0.4", features = ["serde"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
anyhow = "1"
thiserror = "2"
directories = "5"          # per-OS app data dir (replaces path_provider)
open = "5"                 # open system browser for SSO
image = "0.25"             # decode portraits/icons fetched from images.evetech.net

[dev-dependencies]
tempfile = "3"             # temp DBs / token files in tests
```

Pinning rule: builders do not add dependencies. A missing crate is a
scaffold change request, not a local edit (keeps `Cargo.lock` conflict-free
across four parallel builders).

## 3. Full `src/` module tree (exact file paths)

```text
Cargo.toml                                  (scaffold)
Cargo.lock                                  (scaffold, committed)
src/main.rs                                 (scaffold)  eframe entry, tracing init, tokio runtime
src/lib.rs                                  (scaffold)  module declarations + re-exports only
src/config.rs                               (F1) EveConfig port: URLs, scopes, timeouts, client id
src/error.rs                                (F1) EsiError / AuthError / AppError (thiserror)
src/auth/mod.rs                             (F1)
src/auth/oauth.rs                           (F1) PKCE verifier/challenge, state, authorize URL, code+refresh exchange, revoke, JWT claims parse (no signature verify, same as Flutter)
src/auth/callback_server.rs                 (F1) tokio TcpListener 127.0.0.1:54321/callback, success HTML page
src/auth/token_store.rs                     (F1) keyring primary, 0600 file fallback, redacted Debug
src/esi/mod.rs                              (F1)
src/esi/client.rs                           (F1) reqwest client: /latest + tranquility, Bearer, auto-refresh 60s buffer, X-ESI-Error-Limit tracking
src/esi/models.rs                           (F1) serde models (character, skills, skillqueue, wallet, journal, transactions, loyalty, location, ship, online, clones, implants, standings, universe names)
src/esi/endpoints.rs                        (F1) typed calls for the Phase-1 endpoint set in section 5
src/storage/mod.rs                          (F2)
src/storage/db.rs                           (F2) rusqlite open/migrate (schema v1), app-data path resolution
src/storage/schema.sql                      (F2) DDL: characters, skill_queue, character_skills, wallet_balances, wallet_journal, wallet_transactions, loyalty_points, universe_names, app_settings
src/storage/repositories.rs                 (F2) typed CRUD + watch-style reload helpers per table
src/names/mod.rs                            (F2)
src/names/sde.rs                            (F2) bundled skills.json loader: skill name/group lookup
src/names/resolver.rs                       (F2) memory -> DB -> POST /universe/names/; structure fallback; Unknown Item/Location
src/app/mod.rs                              (F3)
src/app/state.rs                            (F3) AppState: characters, active id, per-view LoadState<T> (Loading/Ready/Empty/Error)
src/app/shell.rs                            (F3) eframe App impl: character rail, view switcher, top bar (refresh, demo banner, offline banner)
src/ui/mod.rs                               (F3)
src/ui/dashboard.rs                         (F3) combined wealth, training overview, next skills finishing, wallet trend summary
src/ui/characters.rs                        (F3) character list/detail, add-character (SSO) view, delete/logout
src/ui/skills.rs                            (F3) skill queue + catalogue (SDE groups), total/unallocated SP
src/ui/wallet.rs                            (F3) balance cards (ISK/PLEX/LP), journal + transactions tables with filters
src/ui/settings.rs                          (F3) startup behavior, demo toggle, log view entry, about
src/ui/widgets.rs                           (F3) empty/error/loading panels, ISK + countdown formatting
src/demo/mod.rs                             (F4)
src/demo/data.rs                            (F4) include_str! loaders + seed-into-DB
assets/demo/characters.json                 (F4)
assets/demo/skillqueue.json                 (F4)
assets/demo/wallet.json                  (F4) balances + journal + transactions
assets/demo/names.json                      (F4) pre-resolved universe names for demo rows
assets/sde/skills.json                      (F2 data; F4 may extend rows only via F2)
tests/esi_models.rs                         (F4) fixture JSON -> model parse tests
tests/storage_roundtrip.rs                  (F4) temp-DB repository round-trips
tests/demo_seed.rs                          (F4) demo seed loads, UI state non-empty, no raw-ID strings
tests/fixtures/*.json                       (F4) recorded ESI-shaped payloads (invented data)
```

Runtime wiring (scaffold, `src/main.rs`): build the tokio runtime, open the
DB, construct `EsiClient` + `TokenStore` + `NameResolver`, hand them to
`MimirApp` behind `Arc`; egui never blocks — refreshes are
`tokio::spawn` tasks that send results over an `std::sync::mpsc` channel the
UI drains each frame (`[ESI]`/`[STARTUP]` tracing on every hop). Startup
refresh fires for the **active character only** (character, skills,
skill queue, wallet balance/journal/transactions/loyalty), failures logged
and shown per-view, never fatal — the `startupRefreshProvider` contract in
`lib/app.dart`. No periodic poll loop in the increment; refresh is
startup + manual button + the per-view TTL checks noted in the parity map.

## 4. File-ownership table — four builders, zero overlapping files

Scaffold (done first, alone, ~10 min): `Cargo.toml`, `Cargo.lock`,
`src/main.rs`, `src/lib.rs`, empty `mod.rs` stubs, `.gitignore` (`/target`).
Scaffold proves `cargo fetch && cargo build` on this Linux host before any
builder starts. After scaffold, nobody edits scaffold files; a needed
change (new module, new dependency) goes back to the scaffold owner.

| Builder | Mission | Owned files (exclusive) |
|---|---|---|
| F1 — ESI + auth + models | Config, PKCE OAuth, token store, ESI client + Phase-1 endpoints/models | `src/config.rs`, `src/error.rs`, `src/auth/mod.rs`, `src/auth/oauth.rs`, `src/auth/callback_server.rs`, `src/auth/token_store.rs`, `src/esi/mod.rs`, `src/esi/client.rs`, `src/esi/models.rs`, `src/esi/endpoints.rs` |
| F2 — Storage + name resolution | SQLite schema/repositories, SDE skill names, universe-name resolver | `src/storage/mod.rs`, `src/storage/db.rs`, `src/storage/schema.sql`, `src/storage/repositories.rs`, `src/names/mod.rs`, `src/names/sde.rs`, `src/names/resolver.rs`, `assets/sde/skills.json` |
| F3 — UI views | egui shell, app state, Dashboard/Characters/Skills/Wallet/Settings views, shared widgets | `src/app/mod.rs`, `src/app/state.rs`, `src/app/shell.rs`, `src/ui/mod.rs`, `src/ui/dashboard.rs`, `src/ui/characters.rs`, `src/ui/skills.rs`, `src/ui/wallet.rs`, `src/ui/settings.rs`, `src/ui/widgets.rs` |
| F4 — Demo data + integration tests | Bundled demo fixtures + seeding, all `tests/` | `src/demo/mod.rs`, `src/demo/data.rs`, `assets/demo/characters.json`, `assets/demo/skillqueue.json`, `assets/demo/wallet.json`, `assets/demo/names.json`, `tests/esi_models.rs`, `tests/storage_roundtrip.rs`, `tests/demo_seed.rs`, `tests/fixtures/*.json` |

Cross-builder contracts (fixed by scaffold in `src/lib.rs` doc comment,
changed only by scaffold owner): F1 exposes `EsiClient`, `TokenStore`,
model structs; F2 exposes repository functions + `NameResolver::name(id)`;
F3 consumes both through `AppState`; F4 seeds through F2 repositories
only (never raw SQL in demo code). Every public function logs entry/exit
at debug with its feature tag (`[ESI]`, `[WALLET]`, …); tokens never appear
in any log or `Debug` output (F1 owns the redaction newtypes).

Suggested 90-minute clock: scaffold 0–10; F1–F4 parallel 10–60 against
stub traits; integration (wire real F1/F2 into F3, run F4 tests) 60–80;
`cargo test` + `cargo clippy` + demo-mode smoke run 80–90.

## 5. Flutter → Rust parity map (every D1 checklist item)

Phase 1 = in the 90-minute increment. Deferred = designed-for (module slot
named), not built in this increment; each lands later as one new
`src/ui/<view>.rs` + endpoints on the same client/repositories.

| # | Flutter (inspected) | Rust | Phase |
|---|---|---|---|
| 1 | Tray host + 16 multi-windows (`lib/main.dart`, `window_types.dart`, `tray_service.dart`); **no go_router routes in code** (CLAUDE.md routing text is stale) | One eframe window + view switcher (`src/app/shell.rs`); tray deferred (`tray-icon` crate later, new scaffold dep) | 1 (window) / Deferred (tray, multi-window) |
| 2 | Character rail + active switch (`character_nav_rail.dart`, `character_providers.dart`, `Characters.isActive`) | Left rail in shell; `characters.is_active`; `[CHAR]` logs | 1 |
| 3 | Dashboard 8 cards: wealth, training, quick actions, fleet, wallet trends, timeline, combat, PI (`standalone_dashboard_screen.dart`) | `src/ui/dashboard.rs`: combined wealth, training overview, next-skills, 30-day wallet trend (SQL aggregate port of `walletTrendsProvider`); fleet/combat/PI cards deferred | 1 (4 cards) / Deferred (fleet, zKill combat, PI cards) |
| 4 | Characters window: portrait panel, Overview/Details tabs, clones/implants/standings/attributes, online/location/ship | `src/ui/characters.rs` list+detail (portrait via `images.evetech.net`); clones/implants/standings endpoints in F1, detail sections deferred | 1 (list/detail/add/delete) / Deferred (sub-tabs) |
| 5 | Skills window: queue sidebar, catalogue groups, plans, SP totals (`skills_screen.dart`, `skill_providers.dart`) | `src/ui/skills.rs`: queue list, catalogue by SDE group, total/unallocated SP; skill plans deferred | 1 / Deferred (plans) |
| 6 | Wallet window: ISK/PLEX/LP/EverMarks cards, Overview/Transactions/Market tabs, filters (`wallet_screen.dart`, `wallet_providers.dart`) | `src/ui/wallet.rs`: balance + journal/transactions tables, 7/30/90-day + ref-type filter; PLEX-from-assets + LP deferred | 1 (ISK, journal, transactions) / Deferred (PLEX, LP, EverMarks) |
| 7 | Assets, PI, Industry, Market, Fitting, Intel, Combat Analyzer, Exploration windows | New views `src/ui/{assets,pi,industry,market,fitting,intel,combat,exploration}.rs` + F1 endpoints; Combat Analyzer's log-parser/LLM stack is a separate project slice | Deferred (all) |
| 8 | Corporation window: second ESI stack (root base + compatibility-date `2026-08-18`), 10 extra scopes, capability gating | Separate `EsiClient` profile (root base + `X-Compatibility-Date`) + step-up auth; own follow-up design | Deferred |
| 9 | Onboarding 3-step wizard + Settings (startup behavior, SDE update card, About) | First-run panel in shell (Add character / Try demo); `src/ui/settings.rs` (startup view choice, about); SDE downloadable updates deferred (bundled extract only) | 1 (first-run, settings core) / Deferred (SDE updater) |
| 10 | Auth: PKCE S256, state CSRF, localhost `54321` callback primary, deep-link secondary, JWT parse, logout+revoke (`oauth_service.dart`, `auth_providers.dart`) | `src/auth/*` — localhost path only; JWT claims parse without signature verify (same as Flutter, noted risk); revoke best-effort on logout; states idle/awaiting/exchanging/success/error in `AppState` | 1 |
| 11 | Tokens plaintext in DB + secure-storage migration; 60 s refresh buffer, 1199 s lifetime | Keyring + `0600` fallback file (section 1); same 60 s/1199 s constants (`src/config.rs`); no migration needed (greenfield store) | 1 |
| 12 | Scopes: 18-scope union at login; corp 10 never requested; write scopes 403 → re-authorize prompt | Least-privilege first auth (section 1); step-up per deferred view; 403 surfaces "Re-authorize" action in the owning view | 1 |
| 13 | ESI client: `/latest` + tranquility, 30 s timeout, error-limit headers persisted, ~40 endpoints + writes (fittings, waypoint) | Phase-1 endpoint set (§ below) in `src/esi/endpoints.rs`; error-limit remaining/reset kept in `app_settings`; writes deferred with their views | 1 (reads) / Deferred (writes) |
| 14 | ID→name: SDE for skills, `/universe/names/` + DB cache otherwise, structure auth fallback, `Unknown Item/Location` | `src/names/*` (section 1); F4 test asserts no rendered raw IDs in demo state | 1 |
| 15 | Persistence: Drift `mimir.db` v22, 72 tables; `pending_auth.json`; cross-window event files | rusqlite `mimir.db` schema v1, 9 tables (§3); pending PKCE state in memory (single process — no file needed); no cross-window files (one window) | 1 |
| 16 | Refresh: startup (active char), manual dual-mode, per-provider TTLs; EveConfig interval constants defined-but-unused | Startup + manual refresh button per view; TTL constants in `src/config.rs` actually consulted (skill queue 300 s, wallet 600 s, character 21600 s); no invented global poll | 1 |
| 17 | Empty/loading/error: shared `EmptyState`, No-Character / Empty / Error+Retry per screen | `src/ui/widgets.rs` three panels + `LoadState<T>` in `src/app/state.rs`; no-character state offers Add / Demo | 1 |
| 18 | Logging: `Log.d/i/w/e` `[FEATURE]` tags, `kDebugMode` only; raw `debugPrint` leaks in auth files | `tracing` always compiled in, `RUST_LOG`-style env filter; tags `[AUTH][ESI][WALLET][SKILLS][CHAR][DB][DEMO][UI][STARTUP]`; tokens redacted by type | 1 |
| 19 | Tests: ~200 Dart tests, goldens, patrol, integration (pass state unknown — never run in discovery) | F4's three integration tests + per-module unit tests (section 7) | 1 |
| 20 | External feeds: zKillboard/RedisQ, EveScout, OpenAI/Codex (combat), GitHub SDE releases | Out of increment; each deferred view brings its own client module | Deferred |

Phase-1 ESI endpoint set (F1, all under `https://esi.evetech.net/latest`,
`datasource=tranquility`): `GET /characters/{id}/`, `/skills/`,
`/skillqueue/`, `/attributes/`, `/wallet/`, `/wallet/journal/` (paged),
`/wallet/transactions/`, `/loyalty/points/`, `/location/`, `/ship/`,
`/online/`, `/clones/`, `/implants/`, `/standings/`,
`POST /universe/names/`, `POST /universe/ids/`,
`GET /universe/stations/{id}/`, auth `GET /universe/structures/{id}/`,
`GET /corporations/{id}/`, `GET /alliances/{id}/`. Portraits/icons from
`https://images.evetech.net` (`characters/{id}/portrait?size=128` etc.),
fetched asynchronously, cached on disk under the app cache dir, decoded
off the UI thread.

## 6. Improvements the Flutter app lacks (max five, each tied to files)

1. **Multi-character overview grid** — one screen comparing every
   character's wallet, training skill + finish, queue length, location and
   ship (Flutter shows one active character per window; the dashboard only
   aggregates wealth). Files: `src/ui/dashboard.rs` (overview section),
   queries in `src/storage/repositories.rs`.
2. **Skill-queue finish countdowns** — live `Xd Xh Xm` countdown to the
   current skill and to queue end, ticking every frame from stored
   `finish_date` (Flutter shows static dates/times). Files:
   `src/ui/widgets.rs` (`countdown` formatter), `src/ui/skills.rs`,
   `src/ui/dashboard.rs`.
3. **Wallet analytics summary** — 30-day income/expense/net per ref-type
   with top counterparties resolved to names (Flutter has raw tables and a
   balance trend only). Files: aggregate queries in
   `src/storage/repositories.rs`, rendering in `src/ui/wallet.rs`.
4. **Keyboard-first navigation** — `1–5` switch views, `Ctrl/Cmd+R`
   refresh, `/` focuses search, arrows move in tables (Flutter is
   pointer-first). Files: `src/app/shell.rs` (global keys),
   `src/ui/skills.rs` / `src/ui/wallet.rs` (search focus).
5. **Structured log view** — in-app filterable `tracing` output (tag +
   level filters) instead of console-only `debugPrint`. Files: log-capture
   layer wired in `src/main.rs` (scaffold), panel in `src/ui/settings.rs`.

## 7. Test plan

| Layer | Owner | What | Command |
|---|---|---|---|
| Unit (in-module `#[cfg(test)]`) | F1 | PKCE challenge vs known vector; JWT claims parse (valid/expired/malformed); token expiry buffer math; token `Debug` redaction asserts no token substring | `cargo test` |
| Unit | F2 | Schema migration on empty + reopened DB; repository CRUD; resolver cache hit/miss/fallback names; SDE skill lookup hit + `Skill #<id>` miss | `cargo test` |
| Unit | F3 | ISK formatting, countdown formatting, `LoadState` transitions (pure logic only — no egui harness in 90 min) | `cargo test` |
| Integration | F4 | `tests/esi_models.rs`: every F1 model parses its fixture; `tests/storage_roundtrip.rs`: seed→read equality per table on a temp DB; `tests/demo_seed.rs`: demo seed populates all views' state and no display string equals a bare numeric ID | `cargo test --tests` |
| Static gates | scaffold/CI | Zero warnings treated as done-criteria for owned files | `cargo clippy -- -D warnings`, `cargo fmt --check` |
| Manual smoke (Linux host) | integrator | `cargo run -- --demo` opens window; all five views render demo data; keyboard nav works; `RUST_LOG=debug` shows `[DEMO]/[DB]` lines and no token text. Live-SSO smoke is a follow-up once run on macOS with a real account (unverifiable here) | `cargo run -- --demo` |

No golden/screenshot tests in the increment (Flutter's goldens do not
transfer); add `egui_kittest` later if UI regression coverage is wanted.

## 8. Exact Flutter/Dart paths to delete (after Rust Phase 1 is verified)

Delete in one later commit — **not** during the build, and not before
`cargo test` + demo smoke pass; keep git history (no rewrite) so the
Flutter tree stays recoverable.

```text
lib/                      (all Dart sources: app.dart, main.dart, core/, features/)
test/                     (Dart unit/widget/golden/patrol tests)
integration_test/
android/  ios/  macos/  linux/  windows/  web/     (Flutter platform runners)
pubspec.yaml  pubspec.lock
analysis_options.yaml  dart_test.yaml  .metadata
parse_test.dart  parse_test2.dart  parse_test3.dart
test_opt.dart  test_regex.dart  test_output.txt  test_auth.py  wait.sh
assets/fonts/             (egui ships its own fonts; re-add only if branding requires)
```

Keep: `assets/sde/` (source for regenerating `assets/sde/skills.json`),
`assets/icons/` (tray/EVE icons reusable by egui image loading), `docs/`,
`scripts/` (audit per-script before deleting), `CLAUDE.md`/`AGENTS.md`
(update in the same deletion commit: Rust commands `cargo test` /
`cargo clippy` / `cargo fmt`, tracing tags, ID-resolution rule unchanged),
`.github/` (replace Flutter CI jobs with cargo jobs in that commit).

Also update the engineering journal in the deletion commit
(`docs/engineering-journal/DECISIONS.md`: Rust/egui/SQLite choices +
revisit conditions; `LEARNINGS.md`: localhost-PKCE and plaintext-token
findings), per the repo's auto-maintain rule.

## 9. Risks and open items (named, not hidden)

- Crates.io reachability from this host is **unproven** and the five key
  crates are not in the local cache — scaffold's `cargo fetch` is the
  gate; a refusal stops the build (report, do not substitute GUI).
- macOS build/run/notarization and the keyring backend (macOS Keychain vs
  Linux secret-service) are unverifiable from this Linux host; first Mac
  run is a scheduled follow-up, and the `0600` fallback must be exercised
  there too.
- JWT signature is not verified (faithful port of Flutter); add JWKS
  verification against `login.eveonline.com` as a hardening follow-up.
- Deferred parity is large (11 of 15 Flutter features); Phase 1 parity
  claim covers only Dashboard/Characters/Skills/Wallet/Settings + auth,
  exactly the P0 set in the context library's priority matrix.
- EVE developer-portal registration must list
  `http://127.0.0.1:54321/callback` for the existing client id (Flutter
  already relies on this port); verify before the first live-SSO smoke.


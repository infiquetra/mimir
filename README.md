# Mimir

A cross-platform EVE Online companion app that unifies character management, skill planning, market tools, and industry features into a single, modern application.

[![CI](https://github.com/infiquetra/mimir/actions/workflows/ci.yml/badge.svg)](https://github.com/infiquetra/mimir/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

## Overview

Mimir aims to replace the need for multiple disconnected EVE tools (EVEMon, Pyfa, jEveAssets, etc.) with a unified, cross-platform experience. Built in Rust with egui (eframe) as a single-window desktop app. The earlier Flutter implementation was retired on the `rust-rewrite` branch; see `docs/rust-rewrite-design.md` for the parity map and deferred features.

### What works today (Rust Phase 1)

- **Multi-character dashboard**: every authorized character with wallet balance, current training skill and finish countdown, queue length, and total skill points; click to switch
- **Characters**: EVE SSO sign-in (OAuth2 PKCE on localhost), character detail with resolved corporation/alliance names, logout and delete. The same view shows read-only character detail — online status, current location and ship, attributes, active implants, jump clones, and standings, all with resolved names — and the dashboard location/ship cell fills from the same data. Attributes and active implants load with the scopes first sign-in already grants; jump clones, standings, location, ship, and online state need the step-up scopes `esi-clones.read_clones.v1`, `esi-characters.read_standings.v1`, `esi-location.read_location.v1`, `esi-location.read_ship_type.v1`, and `esi-location.read_online.v1`, which first sign-in deliberately does not request. When a character lacks them, the Characters view offers "Re-authorize with EVE SSO" (the same step-up flow as Assets: approving as a different character is rejected and nothing is saved), and a missing scope degrades only its own section. This step-up path, like the Assets one below, has not been live-verified against a real EVE account yet. Access-token signatures are verified against EVE's published JWKS signing keys (issuer, audience, and expiry checked) before any token is saved at sign-in, step-up, and refresh; a token that fails verification is rejected and nothing is saved. This verification is covered by the test suite with locally generated keys but has not been live-verified against a real EVE account yet
- **Skills**: training queue with per-skill countdowns and progress, trained-skill catalogue grouped and searchable from the bundled SDE extract
- **Wallet**: balance, journal and transactions with resolved counterparty/item/location names, period filters, income/expense/net analytics by reference type and counterparty, loyalty points
- **Assets**: character asset list grouped by resolved location with search and custom ship names. Reading assets needs the EVE SSO scope `esi-assets.read_assets.v1`, which first sign-in deliberately does not request. The live view is reachable after an in-app step-up grant: when a character lacks the scope, the Assets view offers "Re-authorize with EVE SSO", which opens EVE SSO in your browser asking for the already-granted scopes plus this one; approving as a different character is rejected and nothing is saved. This step-up path has not been live-verified against a real EVE account yet. `--demo` mode shows the full view with sample data
- **Market**: read-only market view for one item type at a time. Public regional orders and price history in five hub regions (The Forge, Domain, Sinq Laison, Metropolis, Heimatar) need no sign-in and no EVE scope. Your own open orders need the EVE SSO scope `esi-markets.read_character_orders.v1`, which first sign-in deliberately does not request; when a character lacks it, the Market view offers "Re-authorize with EVE SSO" through the same step-up flow as Assets (approving as a different character is rejected and nothing is saved), and a missing scope affects only that one section. Item name lookup needs the item's exact EVE name. Nothing market-related is stored, no order can be placed, and there is no profit or valuation feature. This path has not been live-verified against a real EVE account yet. `--demo` mode shows the full view with sample data
- **Settings**: startup view, keyboard shortcuts (1-7 views, Ctrl/Cmd+R refresh, `/` search, PgUp/PgDn character cycle), filterable in-app log view
- **Offline-first**: refreshes persist to local SQLite and render from cache at next launch; `--demo` mode runs the full UI on bundled sample data with no credentials or network

### Roadmap (specified, not yet ported from the retired Flutter app)

- **Market Tools**: profit analysis (not implemented; price checking for one item at a time and reading your own open orders are in the Market view above)
- **Industry & Planetary Industry**: Blueprint browser, manufacturing calculator, PI management
- **Fitting**: Ship fitting simulator with EFT/Pyfa import/export
- **Intel, Combat Analyzer, Exploration, Corporation**: see the specifications below and `docs/rust-rewrite-design.md`

## Status

**Rust rewrite in active development.** Phase 1 (dashboard, characters, skills, wallet, assets, market, settings, EVE SSO auth, ESI client, local persistence, demo mode) is implemented and covered by the Rust test suite (`cargo test`). Fitting, industry, exploration, corporation, and the other modules below were implemented in the retired Flutter app; their specifications are retained as the porting roadmap and they are **not** present in the Rust build yet. Visual verification on macOS (the primary target) is still pending; the Linux build is compile- and test-verified.

See the [mimir-context-library](https://github.com/infiquetra/mimir-context-library) repository for detailed specifications and roadmap.

### Corporation specification

- [Corporation Module Product specification](docs/specs/corporation-module.md) — role-aware profile/roster, assets/hangars, structures/fuel and wallets in dedicated window 15; 32 requirements, 40 acceptance criteria and 60 mapped tests; implementation pending.
- [Corporation Module technical design](docs/specs/corporation-module-design.md) — schema 22, character-owned authorization leases, exact accounting, fuel provenance, responsive Window 15 and real-boundary test architecture; C0–C10 with complete AC1–AC40 and T01–T60 traceability; implementation pending.

### Exploration specification

- [Exploration Module Product specification](docs/specs/exploration-module.md) — tray-launched window, offline reference, Thera/Turnur connections, local signatures and routing; nine workflows, 32 requirements, 40 acceptance criteria and 60 test cases; complete (shipped 2026-09-15).
- [Exploration Module technical design](docs/specs/exploration-module-design.md) — versioned offline reference, shared durable feed, scoped notebook transactions, deterministic routing and responsive window; X0–X10 units with complete AC1–AC40 and T01–T60 traceability; complete (shipped 2026-09-15).

### AAR specifications

- [Fit comparison visuals product specification](docs/specs/aar-fit-comparison-visuals.md) — source snapshots, responsive comparisons, module diffs, tactical stats and materials; 30 acceptance criteria and 46 test cases; complete.
- [Fit comparison visuals technical design](docs/specs/aar-fit-comparison-visuals-design.md) — independent source/history storage, neutral shared calculations, exact diffs/BOM, responsive provider/UI seams and W0–W7 TDD gates; complete.
- [Fit import and capture UI test product contract](docs/specs/aar-fit-import-capture-ui-tests.md) — current controls, user expectations, 24 acceptance criteria, and 36 test scenarios; complete.
- [Fit import and capture UI test technical design](docs/specs/aar-fit-import-capture-ui-tests-design.md) — strict AAR parsing, atomic fit retention, real screen/storage harness, and U0–U5 TDD gates; complete.
- [Milestone 5: Per-Attacker Incoming Damage Profile and Defense Matchup](docs/specs/aar-per-attacker-matchup.md) — product contract, acceptance criteria, and test matrix; complete.
- [Milestone 5 technical design](docs/specs/aar-per-attacker-matchup-design.md) — exact damage accounting, model/provider/UI contracts, additive v4 evidence, and TDD units; complete.

## Getting Started

### Prerequisites

- Rust toolchain (stable, with `rustfmt` and `clippy`)
- Linux GUI build libraries for egui (xcb/wayland/xkbcommon development packages)

### Development Setup

```bash
# Clone the repository
git clone https://github.com/infiquetra/mimir.git
cd mimir

# Run with bundled demo data (no EVE credentials, no network)
cargo run -- --demo
# (equivalently: MIMIR_DEMO=1 cargo run)

# Run live: sign in with EVE SSO from the Characters view
cargo run
```

### Running Tests

```bash
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt --check
```

### Building for Release

```bash
cargo build --release   # binary at target/release/mimir
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is dual-licensed:

- **Open Source**: [AGPL-3.0](LICENSE) for open source and personal use
- **Commercial**: See [COMMERCIAL_LICENSE.md](COMMERCIAL_LICENSE.md) for proprietary use

## EVE Online

This application uses data from EVE Online under the [CCP Developer License](https://developers.eveonline.com/license-agreement).

> CCP hf. All rights reserved. "EVE", "EVE Online", "CCP", and all related logos and images are trademarks or registered trademarks of CCP hf.

## Links

- [Blueprint & Specifications](https://github.com/infiquetra/mimir-context-library)
- [ESI API Documentation](https://docs.esi.evetech.net/)
- [EVE Developers](https://developers.eveonline.com/)

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
- **Assets**: character asset list grouped by resolved location with search and custom ship names. Reading assets needs the EVE SSO scope `esi-assets.read_assets.v1`, which first sign-in deliberately does not request. The live view is reachable after an in-app step-up grant: when a character lacks the scope, the Assets view offers "Re-authorize with EVE SSO", which opens EVE SSO in your browser asking for the already-granted scopes plus this one; approving as a different character is rejected and nothing is saved. Locations inside player-built structures resolve by name once the character also grants `esi-universe.read_structures.v1` through the same step-up flow, offered from this view; until then, and for structures the character cannot dock at, those locations honestly read "Unknown Location" (resolved names are shared with Wallet, Industry, and character location once looked up). This step-up path has not been live-verified against a real EVE account yet. `--demo` mode shows the full view with sample data
- **Market**: read-only market view for one item type at a time. Public regional orders and price history in five hub regions (The Forge, Domain, Sinq Laison, Metropolis, Heimatar) need no sign-in and no EVE scope. Your own open orders need the EVE SSO scope `esi-markets.read_character_orders.v1`, which first sign-in deliberately does not request; when a character lacks it, the Market view offers "Re-authorize with EVE SSO" through the same step-up flow as Assets (approving as a different character is rejected and nothing is saved), and a missing scope affects only that one section. Item name lookup needs the item's exact EVE name. Nothing market-related is stored, no order can be placed, and there is no profit or valuation feature. This path has not been live-verified against a real EVE account yet. `--demo` mode shows the full view with sample data
- **Industry**: read-only industry view for the active character. Industry jobs show activity and status in words, facility names, and finish countdowns; the blueprint library is searchable (originals and copies, sorted by name) with efficiency and run information. Both sections need the EVE SSO scopes `esi-characters.read_blueprints.v1` and `esi-industry.read_character_jobs.v1`, which first sign-in deliberately does not request; when a character lacks them, the Industry view offers "Re-authorize with EVE SSO" through the same step-up flow as Assets (approving as a different character is rejected and nothing is saved), and a missing scope affects only its own section. Nothing industry-related is stored, no job can be started, cancelled, or delivered, and there is no production, cost, or profit calculator. This path has not been live-verified against a real EVE account yet. `--demo` mode shows the full view with sample data
- **Planets**: read-only Planetary Industry view for the active character. The colonies list shows resolved solar-system names, the planet type in words, upgrade level, pin count, and last-update date; selecting one colony shows its summary — pin counts by resolved pin type, extractor products, and stored items aggregated from pin contents. Both sections need the EVE SSO scope `esi-planets.manage_planets.v1`, which first sign-in deliberately does not request; when a character lacks it, the Planets view offers "Re-authorize with EVE SSO" through the same step-up flow as Assets (approving as a different character is rejected and nothing is saved), and a missing scope affects only its own section. Nothing planetary is stored, no colony can be edited or created, no extractor can be restarted, and there is no production or setup calculator. This path has not been live-verified against a real EVE account yet. `--demo` mode shows the full view with sample data
- **Fittings**: saved-fittings library for the active character. Saved fittings are listed searchable by fitting name and resolved ship name; selecting one shows its items with resolved names grouped by slot section, and "Copy as EFT" copies the selected fitting to the clipboard in EFT format (items whose names have not resolved yet are skipped with a disclosed count, never shown as numbers). EFT text or a DNA fitting link can also be pasted or typed into the view to see a local imported fitting — every ship and module name is resolved against a bundled catalogue, any line or DNA segment that cannot be imported is shown with its reason instead of being dropped, and the result can be copied back as EFT; importing makes no network calls and needs no EVE scope. An imported fitting or a copy of a saved fitting can now be saved to EVE, and a saved fitting can be deleted from EVE, each behind an explicit in-view confirmation; items EVE cannot represent are named in that confirmation and left out, never silently, and after a save or delete the list refreshes from EVE (EVE caches the list for up to five minutes, so a change can take that long to appear). Reading fittings needs the EVE SSO scope `esi-fittings.read_fittings.v1`, which first sign-in deliberately does not request; when a character lacks it, the Fittings view offers "Re-authorize with EVE SSO" through the same step-up flow as Assets (approving as a different character is rejected and nothing is saved), and a missing scope affects only this view. Saving and deleting additionally need the separate scope `esi-fittings.write_fittings.v1`, which first sign-in also deliberately does not request and which is offered through the same step-up flow when a character lacks it; demo mode performs no writes. Nothing fitting-related is stored locally: an imported fitting is kept only in memory on this device until you save it to EVE. There are no fitting statistics (no DPS, tank, or capacitor numbers). This path, including the new save and delete writes, has not been live-verified against a real EVE account yet. `--demo` mode shows the full view with sample data
- **Exploration**: read-only offline wormhole reference (types by code with destination and mass limits, J-space and special systems, and the six system-effect families) from bundled CCP SDE data. It needs no sign-in and no EVE scope, makes no network calls, and stores nothing. Live connection feeds, a signature notebook, and route planning are not implemented
- **Settings**: startup view, keyboard shortcuts (1-9, 0, E views, Ctrl/Cmd+R refresh, `/` search, PgUp/PgDn character cycle), filterable in-app log view
- **Offline-first**: refreshes persist to local SQLite and render from cache at next launch; `--demo` mode runs the full UI on bundled sample data with no credentials or network

### Roadmap (specified, not yet ported from the retired Flutter app)

- **Market Tools**: profit analysis (not implemented; price checking for one item at a time and reading your own open orders are in the Market view above)
- **Planetary Industry**: PI management — colony edits, extractor restarts (not implemented; the read-only colonies list and one selected colony's pin, extractor, and stored-item summary are in the Planets view above) — and production/setup calculators (not implemented)
- **Fitting**: Ship fitting simulator with fitting statistics, fitting editing in EVE, and Pyfa import (not implemented; the saved-fittings library with EFT export to the clipboard, local in-memory EFT import and local in-memory DNA link import, and saving an imported fitting or a copy to EVE, plus deleting a saved fitting, are in the Fittings view above)
- **Exploration (live features)**: live Thera/Turnur connection feeds, live mapping and signature tracking, a signature notebook, and route planning (not implemented; the read-only offline wormhole reference is in the Exploration view above)
- **Intel, Combat Analyzer, Corporation**: see the specifications below and `docs/rust-rewrite-design.md`

## Status

**Rust rewrite in active development.** Phase 1 (dashboard, characters, skills, wallet, assets, market, industry, planets, fittings, the read-only offline Exploration reference, settings, EVE SSO auth, ESI client, local persistence, demo mode) is implemented and covered by the Rust test suite (`cargo test`). Corporation and the other modules below were implemented in the retired Flutter app; their specifications are retained as the porting roadmap and they are **not** present in the Rust build yet. Of the Flutter exploration module, only the offline reference browser above is in the Rust build; its live connection feeds, signature notebook, and route planning are not present yet. The saved-fittings library, local in-memory EFT import, and save-a-copy/delete writes to EVE above are the only fitting features in the Rust build; the fitting simulator is not present yet. Visual verification on macOS (the primary target) is still pending; the Linux build is compile- and test-verified.

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

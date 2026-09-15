# Mimir

A cross-platform EVE Online companion app that unifies character management, skill planning, market tools, and industry features into a single, modern application.

[![CI](https://github.com/infiquetra/mimir/actions/workflows/ci.yml/badge.svg)](https://github.com/infiquetra/mimir/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

## Overview

Mimir aims to replace the need for multiple disconnected EVE tools (EVEMon, Pyfa, jEveAssets, etc.) with a unified, cross-platform experience. Built with Flutter for native performance on iOS, Android, macOS, Windows, Linux, and Web.

### Key Features (Planned)

- **Character Management**: Multi-character support with skill queue monitoring
- **Skill Planning**: Browse skills, plan training, optimize attributes
- **Market Tools**: Price checking, trade tracking, profit analysis
- **Industry**: Blueprint browser, manufacturing calculator, PI management
- **Fitting**: Ship fitting simulator with EFT/Pyfa import/export

## Status

**Currently in active development**
- Phase 1 & 2 (Foundational/Essential Tools): Complete
- Phase 3 (Market Tools): Backend complete, UI pending
- Phase 4 (Ship Fitting): Backend complete (Dogma Engine, Formats), UI pending

See the [mimir-context-library](https://github.com/infiquetra/mimir-context-library) repository for detailed specifications and roadmap.

### Exploration specification

- [Exploration Module Product specification](docs/specs/exploration-module.md) — tray-launched window, offline reference, Thera/Turnur connections, local signatures and routing; nine workflows, 32 requirements, 40 acceptance criteria and 60 test cases; implementation pending.
- [Exploration Module technical design](docs/specs/exploration-module-design.md) — versioned offline reference, shared durable feed, scoped notebook transactions, deterministic routing and responsive window; X0–X10 units with complete AC1–AC40 and T01–T60 traceability; implementation pending.

### AAR specifications

- [Fit comparison visuals product specification](docs/specs/aar-fit-comparison-visuals.md) — source snapshots, responsive comparisons, module diffs, tactical stats and materials; 30 acceptance criteria and 46 test cases; complete.
- [Fit comparison visuals technical design](docs/specs/aar-fit-comparison-visuals-design.md) — independent source/history storage, neutral shared calculations, exact diffs/BOM, responsive provider/UI seams and W0–W7 TDD gates; complete.
- [Fit import and capture UI test product contract](docs/specs/aar-fit-import-capture-ui-tests.md) — current controls, user expectations, 24 acceptance criteria, and 36 test scenarios; complete.
- [Fit import and capture UI test technical design](docs/specs/aar-fit-import-capture-ui-tests-design.md) — strict AAR parsing, atomic fit retention, real screen/storage harness, and U0–U5 TDD gates; complete.
- [Milestone 5: Per-Attacker Incoming Damage Profile and Defense Matchup](docs/specs/aar-per-attacker-matchup.md) — product contract, acceptance criteria, and test matrix; complete.
- [Milestone 5 technical design](docs/specs/aar-per-attacker-matchup-design.md) — exact damage accounting, model/provider/UI contracts, additive v4 evidence, and TDD units; complete.

## Getting Started

### Prerequisites

- Flutter SDK 3.24+
- Dart SDK 3.5+

### Development Setup

```bash
# Clone the repository
git clone https://github.com/infiquetra/mimir.git
cd mimir

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Running Tests

```bash
flutter test
```

### Building for Release

```bash
# macOS
flutter build macos --release

# iOS
flutter build ios --release

# Android
flutter build apk --release

# Web
flutter build web --release
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

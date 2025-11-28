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

**Currently in early development (Phase 1)**

See the [mimir-blueprint](https://github.com/infiquetra/mimir-blueprint) repository for detailed specifications and roadmap.

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

- [Blueprint & Specifications](https://github.com/infiquetra/mimir-blueprint)
- [ESI API Documentation](https://docs.esi.evetech.net/)
- [EVE Developers](https://developers.eveonline.com/)

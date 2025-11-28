# Contributing to Mimir

Thank you for your interest in contributing to Mimir! This document provides guidelines for contributing to the project.

## Getting Started

### Prerequisites

- Flutter SDK 3.24+
- Dart SDK 3.5+
- An IDE with Flutter support (VS Code, Android Studio, or IntelliJ)

### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/mimir.git
   cd mimir
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Branch Strategy

We use a gitflow-inspired branching model:

- `main` - Stable releases only
- `develop` - Integration branch for features
- `feature/*` - New features
- `bugfix/*` - Bug fixes
- `hotfix/*` - Emergency production fixes

### Creating a Feature Branch

```bash
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name
```

## Making Changes

### Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter analyze` before committing
- Format code with `dart format .`

### Commit Messages

Use conventional commit format:

```
type(scope): description

[optional body]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
- `feat(skills): add skill queue notifications`
- `fix(auth): resolve token refresh race condition`
- `docs(readme): update installation instructions`

### Testing

- Write tests for new features
- Ensure existing tests pass: `flutter test`
- Aim for meaningful test coverage on business logic

## Pull Request Process

1. Update documentation if needed
2. Ensure all tests pass
3. Fill out the PR template completely
4. Request review from maintainers
5. Address review feedback

### PR Requirements

- PRs must target `develop` (not `main`)
- All CI checks must pass
- At least one approval required
- No merge conflicts

## EVE Online Data

When working with EVE Online data:

- Follow [CCP's Developer License](https://developers.eveonline.com/license-agreement)
- Never store or transmit sensitive player data unnecessarily
- Respect ESI rate limits
- Include proper CCP attribution where required

## Questions?

- Open a [Discussion](https://github.com/infiquetra/mimir/discussions) for questions
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the AGPL-3.0 license.

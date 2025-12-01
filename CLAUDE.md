# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Mimir is a Flutter-based EVE Online companion application for macOS (and eventually mobile). It provides:
- Character overview dashboard
- Skill queue monitoring
- Wallet balance and transaction history
- Multi-character support with character switching

## Build Commands

```bash
# Run on macOS
flutter run -d macos

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .
```

## Architecture

### State Management
Uses **Riverpod** for state management:
- `Provider` for services/repositories
- `FutureProvider` for async data
- `StateNotifierProvider` for complex state
- `ref.watch()` for reactive dependencies, `ref.read()` for one-time reads

### Data Flow
```
ESI API → Repository (fetch + cache) → Database (Drift) → Provider → UI
```

### Key Directories
- `lib/core/` - Shared infrastructure (database, auth, DI, routing, theme, widgets)
- `lib/features/` - Feature modules (characters, skills, wallet, dashboard)
- `lib/app.dart` - App root and startup refresh
- `test/` - Unit and widget tests

### Feature Module Structure
Each feature follows:
```
features/
└── feature_name/
    ├── data/
    │   ├── feature_repository.dart  # Data fetching and caching
    │   └── feature_providers.dart   # Riverpod providers
    └── presentation/
        ├── feature_screen.dart      # Main screen
        └── widgets/                  # Feature-specific widgets
```

## Data Refresh Patterns

### Dual-Mode Refresh
All screens with refreshable data implement BOTH mechanisms:
1. **Pull-to-refresh**: `RefreshIndicator` wrapping scrollable content (mobile-friendly)
2. **AppBar button**: `RefreshAppBarAction` in the app bar (desktop-friendly)

This ensures the app works well on both mobile (touch) and desktop (click).

### Startup Refresh
On app startup, the `startupRefreshProvider` in `lib/app.dart` automatically refreshes all data for the active character:
- Character info
- Skill queue
- Wallet balance and journal

### Implementation Pattern
```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Screen Title'),
    actions: [
      if (characterId != null)
        RefreshAppBarAction(
          onRefresh: () => _refresh(ref, characterId),
        ),
      if (isMobile) const CharacterSelector(),
    ],
  ),
  body: RefreshIndicator(
    onRefresh: () => _refresh(ref, characterId),
    child: ListView/CustomScrollView(...),
  ),
)
```

### Refresh Scope by Screen

| Screen | What Gets Refreshed |
|--------|---------------------|
| Dashboard | Character + Skills + Wallet (all) |
| Skills | Skill queue only |
| Wallet | Balance + Journal |

### Empty/Error State Patterns

**No Character State**:
- Icon: Feature-specific or `Icons.person_off_outlined`
- Heading: "No Character Selected"
- Description: Contextual message
- NO refresh button (AppBar covers it)

**Empty Data State**:
- Icon: Feature-specific
- Heading: Feature-specific message
- Description: Explanation
- NO refresh button (AppBar covers it)

**Error State**:
- Icon: `Icons.error_outline`
- Heading: "Failed to Load [Feature]"
- Description: Error message
- CTA: "Retry" button (in addition to AppBar refresh)

## Navigation

Uses **go_router** with `StatefulShellRoute.indexedStack` for:
- Adaptive navigation (bottom bar on mobile, rail on desktop)
- State preservation across tab switches
- Deep link support for OAuth callbacks

### Character Selector Placement
- Desktop (≥600px): In NavigationRail's `leading` slot
- Mobile (<600px): In each screen's AppBar `actions`

## Database (Drift)

Local SQLite database at `lib/core/database/`:
- `app_database.dart` - Schema and initialization
- Tables: Characters, SkillQueueEntries, WalletJournalEntries, WalletBalances
- Uses reactive streams (`watch...()`) for live updates

## Authentication

OAuth2 flow with PKCE for ESI API:
- `lib/core/auth/oauth_service.dart` - Token management
- `lib/core/auth/deep_link_handler.dart` - OAuth callback handling
- Tokens stored securely in keychain

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/database/app_database_test.dart

# Run with coverage
flutter test --coverage
```

## Code Style

- Dart format with default settings
- Prefer `const` constructors where possible
- Use `final` for immutable variables
- Follow Effective Dart guidelines

## 🔍 Debug Logging Requirements

**MANDATORY**: Every code change MUST include appropriate debug logging.

### Logging Rules

1. **Use the Log utility**: `import 'package:mimir/core/logging/logger.dart';`
2. **Tag format**: `[FEATURE]` or `[FEATURE.COMPONENT]`
3. **Log levels**:
   - `Log.d()` - Debug: Method entry/exit, state changes
   - `Log.i()` - Info: Important operations (fetch, save, navigation)
   - `Log.w()` - Warning: Unexpected but handled situations
   - `Log.e()` - Error: Caught exceptions (include stack trace)

### What MUST Be Logged

- Every public method entry (with parameters)
- State changes in providers
- API calls (request and response status)
- Database operations
- User interactions (button presses, navigation)
- Error catches (with stack trace)
- Lifecycle events (init, dispose)

### Standard Tags

| Tag | Usage |
|-----|-------|
| `[AUTH]` | Authentication, OAuth, tokens |
| `[CHAR]` | Character management |
| `[SKILLS]` | Skill queue |
| `[WALLET]` | Wallet/transactions |
| `[DB]` | Database operations |
| `[ESI]` | API calls |
| `[WINDOW]` | Window management |
| `[TRAY]` | System tray |
| `[ROUTER]` | Navigation |
| `[DASH]` | Dashboard |

### Example

```dart
Future<void> refreshSkillQueue(int characterId) async {
  Log.d('SKILLS', 'refreshSkillQueue($characterId) - START');
  try {
    final skills = await esiClient.getSkillQueue(characterId);
    Log.i('SKILLS', 'Fetched ${skills.length} skills from ESI');
    await database.saveSkillQueue(characterId, skills);
    Log.d('SKILLS', 'refreshSkillQueue($characterId) - SUCCESS');
  } catch (e, stack) {
    Log.e('SKILLS', 'refreshSkillQueue($characterId) - FAILED', e, stack);
    rethrow;
  }
}
```

### Why This Matters

Without comprehensive logging:
- Debugging takes hours longer (like the tray menu issue)
- Silent failures go unnoticed
- No visibility into what the app is actually doing
- Cannot diagnose user-reported issues

With proper logging:
- See exactly what happens at every step
- Catch issues immediately in development
- Diagnose production issues from user logs
- Understand performance bottlenecks

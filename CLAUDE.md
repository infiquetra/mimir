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

### Unit and Widget Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/database/app_database_test.dart

# Run with coverage
flutter test --coverage
```

### Integration Tests

Integration tests validate end-to-end functionality with realistic data flow and user interactions.

```bash
# Run all integration tests
flutter test integration_test/

# Run specific screen tests
flutter test integration_test/screens/dashboard/

# Run bug regression tests
flutter test integration_test/bug_regression/
```

**Test Structure**:
```
integration_test/
├── test_utils/
│   ├── mocks/
│   │   └── mock_esi_client.dart     # Mock ESI API responses
│   ├── fixtures/
│   │   ├── character_fixtures.dart  # Test character data
│   │   ├── wallet_fixtures.dart     # Test wallet data
│   │   └── skill_fixtures.dart      # Test skill queue data
│   ├── test_app.dart                # TestApp wrapper with provider overrides
│   └── pump_helpers.dart            # Common test utilities
├── screens/                         # Per-screen integration tests
│   ├── dashboard/
│   ├── characters/
│   ├── wallet/
│   ├── skills/
│   ├── settings/
│   └── onboarding/
└── bug_regression/                  # Tests encoding historical bugs
    ├── layout_overflow_test.dart
    ├── async_value_handling_test.dart
    ├── eve_id_resolution_test.dart
    └── image_size_test.dart
```

### When to Create Tests

**ALWAYS create/update tests for:**

1. **New screens** - Integration test for navigation and data flow
2. **Bug fixes** - Regression test in `bug_regression/` folder to prevent recurrence
3. **UI changes** - Update visual validation checklist
4. **Provider changes** - Test loading/error/data states with AsyncValue

### Integration Test Pattern

Use `TestApp` wrapper for consistent test environment:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mimir/features/dashboard/presentation/dashboard_screen.dart';
import '../../test_utils/fixtures/character_fixtures.dart';
import '../../test_utils/fixtures/skill_fixtures.dart';
import '../../test_utils/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Screen', () {
    testWidgets('renders with data', (tester) async {
      const characterId = 12345;

      await tester.pumpWidget(
        TestApp(
          initialCharacter: CharacterFixtures.testCharacter(),
          setupDatabase: (db) async {
            // Insert test data into in-memory database
            await db.batch((batch) {
              batch.insertAll(
                db.skillQueueEntries,
                SkillFixtures.activeQueue(characterId: characterId),
              );
            });
            await db.recordWalletBalance(characterId, 1500000000.0);
          },
          home: const StandaloneDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify UI elements
      expect(find.byType(CombinedWealthCard), findsOneWidget);
      expect(find.text('1,500,000,000 ISK'), findsOneWidget);
    });

    testWidgets('handles no character', (tester) async {
      await tester.pumpWidget(
        const TestApp(
          initialCharacter: null,
          home: StandaloneDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Character Selected'), findsOneWidget);
    });
  });
}
```

### Bug Regression Tests

When fixing bugs, create regression tests to prevent recurrence:

**Example: Layout Overflow Prevention**
```dart
testWidgets('TabBarView no overflow (commit 62a6320)', (tester) async {
  // ... setup ...

  // Verify TabBarView is wrapped in Expanded to prevent overflow
  final column = tester.widget<Column>(
    find.ancestor(of: find.byType(TabBarView), matching: find.byType(Column)),
  );
  expect(
    column.children.any((child) => child is Expanded && child.child is TabBarView),
    isTrue,
    reason: 'TabBarView should be wrapped in Expanded to prevent overflow',
  );
});
```

**Example: AsyncValue Handling**
```dart
testWidgets('Skills loading state shows spinner (commit 03216e6)', (tester) async {
  // ... setup with delayed provider ...

  // Verify loading indicator appears
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.text('Skill #'), findsNothing, reason: 'Should not crash with .value on loading');
});
```

**Example: EVE ID Resolution**
```dart
testWidgets('Skill names use SDE (skillNameProvider)', (tester) async {
  // ... setup ...

  // Verify skill names are resolved, not raw IDs
  expect(find.textContaining('Skill #'), findsNothing);
  expect(find.text('Mechanics V'), findsOneWidget);
});
```

### Visual Validation

Complement integration tests with semantic screenshot analysis using the visual-validator agent.

**Visual validation checklists** are located in `.claude/visual-validation/checklists/`:
- `dashboard.yaml` - Dashboard screen (7 cards, ISK formatting, responsive grid)
- `characters.yaml` - Character screen (40/60 split, portrait loading)
- `wallet.yaml` - Wallet screen (balance cards, TabBarView, transaction display)
- `skills.yaml` - Skills screen (queue display, training highlight)
- `settings.yaml` - Settings screen (3 sections, radio buttons)
- `onboarding.yaml` - Onboarding wizard (3 steps, navigation)

**To validate a screen:**
```
@visual-validator Validate the [screen] screen
```

The visual-validator agent will:
1. Take a screenshot of the screen
2. Perform semantic analysis using the checklist
3. Report issues like:
   - Layout overflow or spacing problems
   - Unresolved IDs ("Item #12345" instead of item name)
   - Missing icons or images
   - Incorrect color coding
   - Empty states without helpful messages

### Test Coverage Goals

**Screen Integration Tests** (43 total test cases):
- Dashboard: 8 tests
- Characters: 9 tests
- Wallet: 8 tests
- Skills: 7 tests
- Settings: 5 tests
- Onboarding: 6 tests

**Bug Regression Tests** (4 categories):
- Layout overflow prevention
- AsyncValue handling (loading/error states)
- EVE ID resolution (SDE vs ESI)
- Image size normalization

### Common Test Patterns

**Testing Empty States:**
```dart
testWidgets('shows empty state when no data', (tester) async {
  await tester.pumpWidget(const TestApp(
    initialCharacter: null,
    home: ScreenToTest(),
  ));

  expect(find.text('No Character Selected'), findsOneWidget);
  expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
});
```

**Testing Responsive Layouts:**
```dart
testWidgets('adapts to narrow viewport', (tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;

  // ... test layout adapts ...

  addTearDown(tester.view.resetPhysicalSize);
});
```

**Testing AsyncValue States:**
```dart
testWidgets('handles loading state', (tester) async {
  // Use delayed completer to test loading state
  final completer = Completer<Data>();

  await tester.pumpWidget(TestApp(
    overrides: [
      dataProvider.overrideWith((_) => completer.future),
    ],
    home: ScreenToTest(),
  ));

  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  completer.complete(testData);
  await tester.pumpAndSettle();

  expect(find.text('Data Loaded'), findsOneWidget);
});
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

## 🎯 EVE ID Resolution (CRITICAL)

EVE Online uses numeric IDs for everything. This app has TWO systems for resolving IDs to names:

### SDE (Static Data Export) - LOCAL, Skills Only
- **Use for**: Skill names ONLY
- **Provider**: `skillNameProvider`
- **Source**: Bundled database, no network needed
- **Fallback**: "Skill #`<id>`"

### ESI (EVE Swagger Interface) - NETWORK, Everything Else
- **Use for**: Items, ships, stations, characters, corporations
- **Provider**: `itemNameProvider`, `locationNameProvider`
- **Source**: ESI `/universe/names/` endpoint with caching
- **Fallback**: "Unknown Item" or "Unknown Location"

### Decision Table
| Data Type | Provider to Use |
|-----------|-----------------|
| Skill names | `skillNameProvider` |
| Item/module/ship names | `itemNameProvider` |
| Station names | `locationNameProvider` |
| Structure names | `locationNameProvider` (falls back gracefully) |

## Widget Type Selection

| Need | Widget Type |
|------|-------------|
| Display data from providers | `ConsumerWidget` |
| Display data + local state | `ConsumerStatefulWidget` |
| Display only passed props | `StatelessWidget` |

**Rule**: If you need `ref.watch()`, use `ConsumerWidget`.

## AsyncValue Handling Pattern

ALWAYS use `.when()` for FutureProvider/StreamProvider data:

```dart
final nameAsync = ref.watch(itemNameProvider(typeId));

nameAsync.when(
  data: (name) => Text(name),
  loading: () => ShimmerPlaceholder(),  // Or loading indicator
  error: (_, __) => Text('Item #$typeId'),  // Fallback with raw ID
)
```

**NEVER** do this:
```dart
// WRONG - crashes on loading/error
Text(nameAsync.value ?? 'Unknown')
```

## EVE Icon Widgets

| Widget | Use Case | Image Server Path |
|--------|----------|-------------------|
| `EveTypeIcon` | Items, ships, modules | `/types/{id}/icon` |
| `EveSkillIcon` | Skills (with caching) | `/types/{id}/icon` |
| `CharacterAvatar` | Character portraits | `/characters/{id}/portrait` |
| `CorporationLogo` | Corp logos | `/corporations/{id}/logo` |
| `FactionLogo` | Faction logos | `/corporations/{id}/logo` |

**Note**: EVE Image Server only accepts sizes: 32, 64, 128, 256, 512, 1024
Widgets auto-normalize to nearest valid size.

## ⚠️ Common Pitfalls

### Pitfall 1: Displaying Raw IDs
**WRONG**: `Text('Item: ${transaction.typeId}')`
**RIGHT**: Use `itemNameProvider` with `.when()` fallback

### Pitfall 2: Using SDE for Non-Skills
**WRONG**: `skillNameProvider` for ships/items (returns null!)
**RIGHT**: Use `itemNameProvider` for non-skill items

### Pitfall 3: StatelessWidget with Providers
**WRONG**: `class MyWidget extends StatelessWidget` + `ref.watch()`
**RIGHT**: Use `ConsumerWidget` if you need providers

### Pitfall 4: Missing Loading States
**WRONG**: `Text(asyncValue.value ?? 'default')`
**RIGHT**: Use `.when(data:, loading:, error:)` pattern

### Pitfall 5: N+1 Queries in Repositories
**WRONG**: Looping through characters and querying DB for each
```dart
for (final char in characters) {
  final data = await db.getData(char.id);  // N queries!
}
```
**RIGHT**: Single query with batch fetch or JOIN
```dart
final allData = await db.getAllData();  // 1 query
final grouped = groupBy(allData, (d) => d.characterId);
```

### Pitfall 6: Memory Filtering vs SQL Filtering
**WRONG**: Fetch all data, filter in Dart
```dart
final all = await db.getAll(limit: 10000);
final filtered = all.where((x) => x.date.isAfter(cutoff));
```
**RIGHT**: Push filters to SQL
```dart
final filtered = await db.getAllSince(cutoff);  // WHERE in SQL
```

### Pitfall 7: Singleton State in Multi-Window
**WRONG**: Rate limits, caches, or counters as instance variables
- In multi-window (isolate) architecture, each window gets separate state

**RIGHT**: Store shared state in SQLite database
- Database is the single source of truth across all windows
```dart
// WRONG - instance variable (not shared)
class EsiClient {
  int _errorLimitRemain = 100;  // Separate per window!
}

// RIGHT - database table (shared)
class EsiRateLimits extends Table {
  TextColumn get endpoint => text()();
  IntColumn get remaining => integer()();
}
```

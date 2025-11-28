import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mimir/app.dart';
import 'package:mimir/core/auth/deep_link_handler.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';

/// Mock deep link handler for testing.
class MockDeepLinkHandler extends DeepLinkHandler {
  MockDeepLinkHandler() : super(ref: _MockRef());

  @override
  Future<void> initialize() async {
    // No-op for tests.
  }
}

/// Minimal mock ref for deep link handler.
class _MockRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late AppDatabase testDatabase;

  setUp(() {
    testDatabase = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDatabase.close();
  });

  testWidgets('App should render without errors', (WidgetTester tester) async {
    // Build our app with test overrides.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDatabase),
          deepLinkHandlerProvider.overrideWithValue(MockDeepLinkHandler()),
        ],
        child: const MimirApp(),
      ),
    );

    // Wait for the app to settle.
    await tester.pumpAndSettle();

    // Verify the app renders (Dashboard should be visible in the app bar or navigation).
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('App should show navigation items', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDatabase),
          deepLinkHandlerProvider.overrideWithValue(MockDeepLinkHandler()),
        ],
        child: const MimirApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify navigation destinations exist.
    expect(find.text('Skills'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Common test pump helpers for integration tests.
///
/// Provides utilities for:
/// - Waiting for async operations
/// - Triggering pull-to-refresh
/// - Scrolling and finding widgets
/// - Handling async value loading states

/// Pump frames until a condition is met or timeout.
///
/// Useful for waiting for async operations to complete.
///
/// Example:
/// ```dart
/// await pumpUntil(
///   tester,
///   () => find.text('Loaded!').evaluate().isNotEmpty,
///   timeout: const Duration(seconds: 5),
/// );
/// ```
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();

  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException(
        'pumpUntil timeout after ${timeout.inSeconds}s',
        timeout,
      );
    }

    await tester.pump(interval);
  }

  stopwatch.stop();
}

/// Trigger pull-to-refresh on a RefreshIndicator.
///
/// Simulates a drag gesture to trigger the refresh callback.
///
/// Example:
/// ```dart
/// await triggerPullToRefresh(tester);
/// await tester.pumpAndSettle();
/// expect(find.text('Updated data'), findsOneWidget);
/// ```
Future<void> triggerPullToRefresh(WidgetTester tester) async {
  // Find the RefreshIndicator.
  final refreshIndicatorFinder = find.byType(RefreshIndicator);
  expect(refreshIndicatorFinder, findsOneWidget);

  // Drag down to trigger refresh.
  await tester.drag(refreshIndicatorFinder, const Offset(0, 300));
  await tester.pump();
}

/// Wait for all CircularProgressIndicators to disappear.
///
/// Useful for waiting for loading states to complete.
///
/// Example:
/// ```dart
/// await waitForLoadingToComplete(tester);
/// expect(find.byType(CircularProgressIndicator), findsNothing);
/// ```
Future<void> waitForLoadingToComplete(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await pumpUntil(
    tester,
    () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    timeout: timeout,
  );
}

/// Scroll until a widget is visible.
///
/// Useful for finding widgets in long lists or scrollable content.
///
/// Example:
/// ```dart
/// await scrollUntilVisible(
///   tester,
///   find.text('Hidden Item'),
///   scrollable: find.byType(ListView),
/// );
/// ```
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder item, {
  required Finder scrollable,
  double scrollDelta = 300.0,
  int maxScrolls = 50,
}) async {
  for (var i = 0; i < maxScrolls; i++) {
    if (item.evaluate().isNotEmpty) {
      break;
    }

    await tester.drag(scrollable, Offset(0, -scrollDelta));
    await tester.pump();
  }

  expect(item, findsOneWidget, reason: 'Item not found after $maxScrolls scrolls');
}

/// Tap a widget and wait for the tap to complete.
///
/// Useful for tapping buttons that trigger async operations.
///
/// Example:
/// ```dart
/// await tapAndSettle(tester, find.text('Refresh'));
/// await waitForLoadingToComplete(tester);
/// ```
Future<void> tapAndSettle(
  WidgetTester tester,
  Finder finder, {
  Duration settleDuration = const Duration(milliseconds: 500),
}) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(settleDuration);
}

/// Wait for text to appear on screen.
///
/// Useful for waiting for async data to load and display.
///
/// Example:
/// ```dart
/// await waitForText(tester, 'Test Capsuleer');
/// expect(find.text('Test Capsuleer'), findsOneWidget);
/// ```
Future<void> waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await pumpUntil(
    tester,
    () => find.text(text).evaluate().isNotEmpty,
    timeout: timeout,
  );
}

/// Wait for a widget type to appear on screen.
///
/// Useful for waiting for specific widgets to load.
///
/// Example:
/// ```dart
/// await waitForWidget(tester, EveSkillIcon);
/// expect(find.byType(EveSkillIcon), findsWidgets);
/// ```
Future<void> waitForWidget(
  WidgetTester tester,
  Type widgetType, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await pumpUntil(
    tester,
    () => find.byType(widgetType).evaluate().isNotEmpty,
    timeout: timeout,
  );
}

/// Verify no overflow errors occurred during the test.
///
/// Call this at the end of layout-related tests to ensure no RenderFlex overflows.
///
/// Example:
/// ```dart
/// testWidgets('wallet screen has no overflow', (tester) async {
///   await tester.pumpWidget(TestApp(home: const WalletScreen()));
///   await tester.pumpAndSettle();
///   verifyNoOverflowErrors();
/// });
/// ```
void verifyNoOverflowErrors() {
  // Flutter test framework captures overflow errors automatically.
  // If any overflow occurred, the test will have already failed with
  // an error message like "RenderFlex overflowed by 123 pixels".
  // This is a no-op helper that serves as documentation.
}

/// Extension methods for WidgetTester to add convenience methods.
extension WidgetTesterExtensions on WidgetTester {
  /// Pump and wait for all animations and async operations to complete.
  ///
  /// Combines pumpAndSettle with a longer timeout for slow operations.
  Future<void> pumpAndSettleLong({
    Duration duration = const Duration(seconds: 10),
  }) async {
    await pumpAndSettle(duration);
  }
}

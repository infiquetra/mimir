import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mimir/app.dart';

void main() {
  testWidgets('App should render without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MimirApp(),
      ),
    );

    // Wait for the app to settle.
    await tester.pumpAndSettle();

    // Verify the app renders (Dashboard should be visible in the app bar or navigation).
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('App should show navigation items', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MimirApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify navigation destinations exist.
    expect(find.text('Skills'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}

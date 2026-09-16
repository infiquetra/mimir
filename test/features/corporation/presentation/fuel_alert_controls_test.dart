// C9 RED: T48 / U08 severity, permission copy, generic native text, ack.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_structures_view.dart';

void main() {
  Future<void> pumpAlerts(
    WidgetTester tester, {
    Duration remaining = const Duration(hours: 72),
    bool permissionDenied = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FuelAlertControls(
            remaining: remaining,
            permissionDenied: permissionDenied,
            structureName: 'Alpha Works',
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('72h exact is Low and 24h exact is Critical', (tester) async {
    await pumpAlerts(tester, remaining: const Duration(hours: 72));
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Normal'), findsNothing);
    await pumpAlerts(tester, remaining: const Duration(hours: 24));
    expect(find.text('Critical'), findsOneWidget);
  });

  testWidgets('permission denial keeps in-app fuel warnings', (tester) async {
    await pumpAlerts(tester, permissionDenied: true);
    expect(
      find.textContaining(
        'Notifications are disabled. Fuel warnings remain available here.',
      ),
      findsWidgets,
    );
  });

  testWidgets('native copy is generic and never names Alpha Works', (
    tester,
  ) async {
    await pumpAlerts(tester);
    expect(find.textContaining('Corporation fuel alert'), findsWidgets);
    expect(
      find.textContaining(
        'A structure needs fuel attention. Open Mimir to verify current status.',
      ),
      findsWidgets,
    );
    expect(find.textContaining('Alpha Works'), findsNothing);
  });

  testWidgets('Acknowledge dismisses the active warning episode', (
    tester,
  ) async {
    await pumpAlerts(tester, remaining: const Duration(hours: 24));
    expect(find.text('Critical'), findsOneWidget);
    await tester.tap(find.text('Acknowledge'));
    await tester.pump();
    expect(find.text('Critical'), findsNothing);
  });
}

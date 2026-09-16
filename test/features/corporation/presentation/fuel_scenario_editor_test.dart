// C9 RED: T47 / U07 Calculate/Cancel/Save, 72h beside 60h, zero-rate validation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_fuel_calculator.dart';
import 'package:mimir/features/corporation/presentation/views/corporation_structures_view.dart';

void main() {
  Future<void> pumpEditor(
    WidgetTester tester, {
    FuelScenarioDraft? draft,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FuelScenarioEditor(draft: draft)),
      ),
    );
    await tester.pump();
  }

  testWidgets('Calculate does not save; Cancel restores; Save commits', (
    tester,
  ) async {
    final draft = FuelScenarioDraft(savedRate: 20);
    await pumpEditor(tester, draft: draft);
    await tester.enterText(find.byKey(const Key('fuel-rate-field')), '18');
    await tester.tap(find.text('Calculate'));
    await tester.pump();
    expect(draft.savedRate, 20);
    expect(draft.previewRate, 18);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(draft.savedRate, 20);
    expect(draft.previewRate, isNull);
    await tester.enterText(find.byKey(const Key('fuel-rate-field')), '18');
    await tester.tap(find.text('Calculate'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(draft.savedRate, 18);
    expect(find.text('Fuel estimate saved.'), findsOneWidget);
    expect(find.textContaining('not a refuel or stock update'), findsWidgets);
  });

  testWidgets('dated 72h endurance sits beside ESI 60h countdown', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(find.textContaining('72h'), findsWidgets);
    expect(find.textContaining('60h'), findsWidgets);
    expect(find.textContaining('3.00'), findsWidgets);
  });

  testWidgets('zero rate is Not modeled, not a 0h horizon', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(find.byKey(const Key('fuel-rate-field')), '0');
    await tester.tap(find.text('Calculate'));
    await tester.pump();
    expect(find.text('0h'), findsNothing);
    expect(find.textContaining('Not modeled'), findsWidgets);
  });
}

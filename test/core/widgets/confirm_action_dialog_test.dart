import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/widgets/confirm_action_dialog.dart';

void main() {
  testWidgets('confirmAction only returns true on explicit confirmation', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await confirmAction(
                  context,
                  title: 'Save fit to EVE?',
                  message: 'This writes to your character.',
                  confirmLabel: 'Save to EVE',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    // Cancelling must not confirm.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Save fit to EVE?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Dismissing the dialog must not confirm either.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Only the confirm button confirms.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to EVE'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('warnings are shown to the user before confirming', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => confirmAction(
                context,
                title: 'Set in-game destination?',
                message: 'Changes your autopilot.',
                warnings: ['Rig X has no ESI slot flag and will be left out.'],
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(
      find.text('Rig X has no ESI slot flag and will be left out.'),
      findsOneWidget,
    );
  });
}

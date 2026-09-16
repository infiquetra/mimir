// C8 RED: T42 / U02 F8 context states and exact Product §6.6 copy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_context.dart';
import 'package:mimir/features/corporation/presentation/views/overview_roster_view.dart';

void main() {
  Future<void> pumpView(WidgetTester tester, OverviewRosterView view) async {
    await tester.pumpWidget(MaterialApp(home: view));
    await tester.pump();
  }

  testWidgets('no character shows No Character Selected copy', (tester) async {
    await pumpView(
      tester,
      const OverviewRosterView(
        hasCharacter: false,
        membership: MembershipState.noCharacter,
      ),
    );
    expect(find.text('No Character Selected'), findsOneWidget);
    expect(
      find.text('Select a character to view their corporation.'),
      findsOneWidget,
    );
    expect(find.textContaining('Helios'), findsNothing);
    expect(find.textContaining('3 members'), findsNothing);
  });

  testWidgets('unresolved membership shows Resolving corporation', (
    tester,
  ) async {
    await pumpView(
      tester,
      const OverviewRosterView(membership: MembershipState.unresolved),
    );
    expect(find.textContaining('Resolving corporation'), findsWidgets);
    expect(find.textContaining('Corporation #0'), findsNothing);
    expect(find.textContaining('Corporation 0'), findsNothing);
    expect(find.textContaining('#0'), findsNothing);
  });

  testWidgets('NPC corporation shows Management data unavailable', (
    tester,
  ) async {
    await pumpView(
      tester,
      const OverviewRosterView(membership: MembershipState.npc),
    );
    expect(find.text('Management data unavailable'), findsOneWidget);
    expect(
      find.text(
        'Private management views are not available for this corporation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('closed corporation uses the same management-unavailable copy', (
    tester,
  ) async {
    await pumpView(
      tester,
      const OverviewRosterView(membership: MembershipState.closed),
    );
    expect(find.text('Management data unavailable'), findsOneWidget);
    expect(
      find.text(
        'Private management views are not available for this corporation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('missing scope shows Authorization required and Authorize', (
    tester,
  ) async {
    await pumpView(tester, const OverviewRosterView(missingScope: true));
    expect(find.textContaining('Authorization required'), findsWidgets);
    expect(find.text('Authorize'), findsOneWidget);
  });
}

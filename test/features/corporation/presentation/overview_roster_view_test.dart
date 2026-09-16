// C8 RED: T44 / U04 F2 profile, roster, join, activity, titles, My access.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_roster.dart';
import 'package:mimir/features/corporation/presentation/views/overview_roster_view.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  Future<void> pumpView(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    OverviewRosterView? view,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(home: view ?? const OverviewRosterView()),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'profile card shows Helios Research, HELI, tax 10%/5.6%, Alpha Station',
    (tester) async {
      await pumpView(tester);
      expect(find.textContaining('Helios Research'), findsWidgets);
      expect(find.textContaining('HELI'), findsWidgets);
      expect(find.textContaining('ISK 10%'), findsWidgets);
      expect(find.textContaining('LP 5.6%'), findsWidgets);
      expect(find.textContaining('Alpha Station'), findsWidgets);
      expect(find.textContaining('6001'), findsNothing);
    },
  );

  testWidgets('legacy tax 0.10 renders as 10%', (tester) async {
    await pumpView(tester, view: const OverviewRosterView(legacyTax: true));
    expect(find.textContaining('10%'), findsWidgets);
    expect(find.textContaining('0.10%'), findsNothing);
  });

  testWidgets(
    'roster lists Ada and Bea, discloses 3 members (2 listed), no 99',
    (tester) async {
      await pumpView(tester);
      expect(find.textContaining('Ada'), findsWidgets);
      expect(find.textContaining('Bea'), findsWidgets);
      expect(find.textContaining('3 members (2 listed)'), findsWidgets);
      expect(find.textContaining('99'), findsNothing);
      expect(find.textContaining('#1'), findsNothing);
      expect(find.textContaining('#2'), findsNothing);
    },
  );

  testWidgets('Ada join is 1 Sep 2026; Bea join is unavailable', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.textContaining('1 Sep 2026'), findsWidgets);
    expect(find.textContaining('1 Jan'), findsNothing);
    expect(find.textContaining('unavailable'), findsWidgets);
  });

  testWidgets('tracking start 2 Sep overrides public history', (tester) async {
    await pumpView(
      tester,
      view: OverviewRosterView(trackingJoin: DateTime.utc(2026, 9, 2)),
    );
    expect(find.textContaining('2 Sep 2026'), findsWidgets);
  });

  testWidgets('7-day filter includes Ada at T0 and excludes at T0+1ms', (
    tester,
  ) async {
    await pumpView(
      tester,
      view: OverviewRosterView(
        now: kCorporationT0,
        activityBucket: ActivityBucket.last7,
      ),
    );
    expect(find.textContaining('Ada'), findsWidgets);
    await pumpView(
      tester,
      view: OverviewRosterView(
        now: kCorporationT0.add(const Duration(milliseconds: 1)),
        activityBucket: ActivityBucket.last7,
      ),
    );
    expect(find.textContaining('Ada'), findsNothing);
  });

  testWidgets(
    'missing login is Not reported; future login is Unknown, never Online',
    (tester) async {
      await pumpView(tester);
      expect(find.textContaining('Not reported'), findsWidgets);
      expect(find.textContaining('Unknown'), findsWidgets);
      expect(find.text('Online'), findsNothing);
      expect(find.textContaining('Online'), findsNothing);
    },
  );

  testWidgets('locked titles and tracking keep roster with §6.6 copy', (
    tester,
  ) async {
    await pumpView(
      tester,
      view: const OverviewRosterView(titlesLocked: true, trackingLocked: true),
    );
    expect(find.textContaining('title unavailable'), findsWidgets);
    expect(find.textContaining('Activity locked'), findsWidgets);
    expect(find.textContaining('Title #'), findsNothing);
    expect(find.textContaining('Ada'), findsWidgets);
    expect(find.textContaining('Bea'), findsWidgets);
    expect(find.textContaining('Director'), findsNothing);
  });

  testWidgets('My Access caption is My NPC standings', (tester) async {
    await pumpView(tester);
    expect(find.textContaining('My NPC standings'), findsWidgets);
  });

  testWidgets('no raw numeric IDs in the overview UI', (tester) async {
    await pumpView(tester);
    expect(find.textContaining('6001'), findsNothing);
    expect(find.textContaining('Item #'), findsNothing);
    expect(find.textContaining('Member #'), findsNothing);
  });

  testWidgets('320px width does not overflow', (tester) async {
    await pumpView(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}

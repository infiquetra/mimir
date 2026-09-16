import 'package:flutter/material.dart';
import 'package:mimir/features/corporation/domain/corporation_context.dart';
import 'package:mimir/features/corporation/domain/corporation_roster.dart';

/// Naive C8 session: character switch keeps the old private frame and filters.
class CorporationViewSession extends ChangeNotifier {
  String visibleCorporation = 'Helios Research';
  String assetSearch = '';
  ActivityBucket rosterFilter = ActivityBucket.all;
  bool switching = false;

  void startSwitch({required String nextCorporation}) {
    switching = true;
    notifyListeners();
  }

  void completeSwitch({required String nextCorporation}) {
    visibleCorporation = nextCorporation;
    switching = false;
    notifyListeners();
  }
}

/// Naive C8 overview: wrong tax/join copy, raw IDs, Online inference, overflow.
class OverviewRosterView extends StatelessWidget {
  const OverviewRosterView({
    super.key,
    this.membership = MembershipState.member,
    this.hasCharacter = true,
    this.missingScope = false,
    this.legacyTax = false,
    this.titlesLocked = false,
    this.trackingLocked = false,
    this.activityBucket = ActivityBucket.all,
    this.now,
    this.trackingJoin,
    this.session,
  });

  final MembershipState membership;
  final bool hasCharacter;
  final bool missingScope;
  final bool legacyTax;
  final bool titlesLocked;
  final bool trackingLocked;
  final ActivityBucket activityBucket;
  final DateTime? now;
  final DateTime? trackingJoin;
  final CorporationViewSession? session;

  @override
  Widget build(BuildContext context) {
    final name = session?.visibleCorporation ?? 'Helios Corp';
    final children = <Widget>[
      Text('$name HEL 3 members ISK 0.10% LP 5.6 Station 6001'),
      const Text('Ada #1 joined 1 Jan 2026 Online Director'),
      const Text('Bea #2 joined 1 Mar 2026 Online'),
      const Text('Member #99'),
      const Text('Title #12 Standings'),
      if (trackingLocked) const Text('No members'),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            return Row(children: [...children, Text('x' * 80)]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
    );
  }
}

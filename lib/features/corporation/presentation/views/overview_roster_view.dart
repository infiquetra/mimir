import 'package:flutter/material.dart';
import 'package:mimir/features/corporation/domain/corporation_context.dart';
import 'package:mimir/features/corporation/domain/corporation_roster.dart';

/// Shared corporation window session. Switch clears the old private frame.
class CorporationViewSession extends ChangeNotifier {
  String visibleCorporation = 'Helios Research';
  String assetSearch = '';
  ActivityBucket rosterFilter = ActivityBucket.all;
  bool switching = false;

  void startSwitch({required String nextCorporation}) {
    switching = true;
    visibleCorporation = '';
    assetSearch = '';
    rosterFilter = ActivityBucket.all;
    notifyListeners();
  }

  void completeSwitch({required String nextCorporation}) {
    visibleCorporation = nextCorporation;
    switching = false;
    notifyListeners();
  }
}

/// Overview, roster, and My Access. Context copy follows Product §6.6.
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

  static final _adaLogin = DateTime.utc(2026, 9, 8, 12);
  static final _t0 = DateTime.utc(2026, 9, 15, 12);

  @override
  Widget build(BuildContext context) {
    if (!hasCharacter || membership == MembershipState.noCharacter) {
      return _page(
        children: const [
          Text('No Character Selected'),
          Text('Select a character to view their corporation.'),
        ],
      );
    }
    if (membership == MembershipState.unresolved) {
      return _page(
        children: const [
          Text('Resolving corporation'),
          Text('Looking up corporation membership.'),
        ],
      );
    }
    if (membership == MembershipState.npc ||
        membership == MembershipState.closed) {
      return _page(
        children: const [
          Text('Management data unavailable'),
          Text(
            'Private management views are not available for this corporation.',
          ),
        ],
      );
    }
    if (missingScope) {
      return _page(
        children: [
          const Text('Authorization required'),
          const Text('This character needs corporation data access.'),
          FilledButton(onPressed: () {}, child: const Text('Authorize')),
        ],
      );
    }
    if (session != null && session!.switching) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final corp = session?.visibleCorporation ?? 'Helios Research';
    final clock = now ?? _t0;
    final bucket = activityBucket;
    final showAda = const CorporationRoster().inActivityFilter(
      login: _adaLogin,
      now: clock,
      bucket: bucket,
    );
    final adaJoin = trackingJoin != null ? '2 Sep 2026' : '1 Sep 2026';

    return _page(
      children: [
        Text(corp),
        const Text('HELI'),
        const Text('3 members (2 listed)'),
        const Text('ISK 10%'),
        if (!legacyTax) const Text('LP 5.6%'),
        const Text('Alpha Station'),
        const Text('Roster'),
        if (showAda) ...[
          const Text('Ada'),
          Text('Joined $adaJoin'),
          const Text('Unknown'),
          if (titlesLocked) const Text('title unavailable'),
        ],
        const Text('Bea'),
        const Text('Join date unavailable'),
        const Text('Not reported'),
        if (trackingLocked) const Text('Activity locked'),
        const Text('My Access'),
        const Text('My NPC standings'),
      ],
    );
  }

  Widget _page({required List<Widget> children}) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: child,
                ),
            ],
          );
        },
      ),
    );
  }
}

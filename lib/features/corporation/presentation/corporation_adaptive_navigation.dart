import 'package:flutter/material.dart';

/// Four corporation destinations. Rail at width >= 600, bar below.
class CorporationAdaptiveNavigation extends StatefulWidget {
  const CorporationAdaptiveNavigation({super.key});

  static const destinations = [
    'Overview & Roster',
    'Assets',
    'Structures',
    'Wallets',
  ];

  static const breakpoint = 600.0;

  @override
  State<CorporationAdaptiveNavigation> createState() =>
      _CorporationAdaptiveNavigationState();
}

class _CorporationAdaptiveNavigationState
    extends State<CorporationAdaptiveNavigation> {
  var _index = 0;

  static const _icons = [
    Icons.groups_outlined,
    Icons.inventory_2_outlined,
    Icons.apartment_outlined,
    Icons.account_balance_wallet_outlined,
  ];

  void _select(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >=
        CorporationAdaptiveNavigation.breakpoint;
    if (wide) {
      return NavigationRail(
        key: const Key('corporation-module-rail'),
        selectedIndex: _index,
        labelType: NavigationRailLabelType.all,
        onDestinationSelected: _select,
        destinations: [
          for (
            var i = 0;
            i < CorporationAdaptiveNavigation.destinations.length;
            i++
          )
            NavigationRailDestination(
              icon: Icon(_icons[i]),
              label: Text(CorporationAdaptiveNavigation.destinations[i]),
            ),
        ],
      );
    }
    return NavigationBar(
      key: const Key('corporation-module-bar'),
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: [
        for (
          var i = 0;
          i < CorporationAdaptiveNavigation.destinations.length;
          i++
        )
          NavigationDestination(
            icon: Icon(_icons[i]),
            label: CorporationAdaptiveNavigation.destinations[i],
          ),
      ],
    );
  }
}

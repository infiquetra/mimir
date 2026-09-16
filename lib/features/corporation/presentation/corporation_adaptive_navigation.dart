import 'package:flutter/material.dart';

import 'views/corporation_assets_view.dart';
import 'views/corporation_structures_view.dart';
import 'views/corporation_wallets_view.dart';
import 'views/overview_roster_view.dart';

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

  Widget _buildBody(int index) {
    switch (index) {
      case 0:
        return const OverviewRosterView();
      case 1:
        return const CorporationAssetsView();
      case 2:
        return const CorporationStructuresView();
      case 3:
        return const CorporationWalletsView();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >=
        CorporationAdaptiveNavigation.breakpoint;
    if (wide) {
      return Row(
        children: [
          NavigationRail(
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
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildBody(_index)),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: _buildBody(_index)),
        NavigationBar(
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
        ),
      ],
    );
  }
}

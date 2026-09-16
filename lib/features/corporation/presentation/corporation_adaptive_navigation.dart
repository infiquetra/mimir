import 'package:flutter/material.dart';

/// Naive C7: always a NavigationBar, wrong labels, selection never updates.
class CorporationAdaptiveNavigation extends StatefulWidget {
  const CorporationAdaptiveNavigation({super.key});

  static const destinations = ['Overview', 'Hangars', 'Fuel', 'ISK'];

  @override
  State<CorporationAdaptiveNavigation> createState() =>
      _CorporationAdaptiveNavigationState();
}

class _CorporationAdaptiveNavigationState
    extends State<CorporationAdaptiveNavigation> {
  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      key: const Key('corporation-module-bar'),
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      destinations: [
        for (final label in CorporationAdaptiveNavigation.destinations)
          NavigationDestination(icon: const Icon(Icons.circle), label: label),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Naive X7 shell: always a character rail and module NavigationRail.
class ExplorationScreen extends StatelessWidget {
  const ExplorationScreen({super.key});

  static const destinations = [
    'Database',
    'Connections',
    'Signatures',
    'Routes',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(
            key: Key('exploration-character-rail'),
            width: 60,
            child: Center(child: Text('Chars')),
          ),
          NavigationRail(
            key: const Key('exploration-module-rail'),
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: [
              for (final label in destinations)
                NavigationRailDestination(
                  icon: const Icon(Icons.circle_outlined),
                  label: Text(label),
                ),
            ],
          ),
          const Expanded(child: Center(child: Text('Exploration'))),
        ],
      ),
    );
  }
}

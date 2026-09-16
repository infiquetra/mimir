import 'package:flutter/material.dart';

import '../../../core/logging/logger.dart';
import '../../../core/widgets/character_nav_rail.dart';
import 'public_highways_view.dart';
import 'wormhole_database_view.dart';

/// Exploration window shell: adaptive character selector and four destinations.
///
/// View bodies are owned by later units; this unit only establishes the host
/// layout, usable-width breakpoints, and destination chrome.
class ExplorationScreen extends StatefulWidget {
  const ExplorationScreen({super.key});

  static const destinations = [
    'Database',
    'Connections',
    'Signatures',
    'Routes',
  ];

  static const _moduleBreakpoint = 600.0;

  @override
  State<ExplorationScreen> createState() => _ExplorationScreenState();
}

class _ExplorationScreenState extends State<ExplorationScreen> {
  int _index = 0;
  var _loggedMount = false;

  static const _destinationIcons = [
    Icons.menu_book_outlined,
    Icons.hub_outlined,
    Icons.fingerprint,
    Icons.alt_route,
  ];

  @override
  Widget build(BuildContext context) {
    if (!_loggedMount) {
      _loggedMount = true;
      Log.i('EXPLORATION.WINDOW', 'ExplorationScreen mounted');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth;
        final showCharacterRail =
            usableWidth >= ExplorationScreen._moduleBreakpoint;
        final moduleWidth = showCharacterRail
            ? usableWidth - CharacterNavRail.width
            : usableWidth;
        final showModuleRail =
            moduleWidth >= ExplorationScreen._moduleBreakpoint;

        Log.d(
          'EXPLORATION.WINDOW',
          'layout usable=$usableWidth module=$moduleWidth '
              'characterRail=$showCharacterRail moduleRail=$showModuleRail',
        );

        return Scaffold(
          appBar: showCharacterRail
              ? null
              : AppBar(
                  title: const Text('Exploration'),
                  actions: const [_CompactCharacterMenu()],
                ),
          body: Row(
            children: [
              if (showCharacterRail) const _CharacterRailSlot(),
              if (showModuleRail)
                NavigationRail(
                  key: const Key('exploration-module-rail'),
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (
                      var i = 0;
                      i < ExplorationScreen.destinations.length;
                      i++
                    )
                      NavigationRailDestination(
                        icon: Icon(_destinationIcons[i]),
                        label: Text(ExplorationScreen.destinations[i]),
                      ),
                  ],
                ),
              Expanded(child: _destinationBody()),
            ],
          ),
          bottomNavigationBar: showModuleRail
              ? null
              : NavigationBar(
                  key: const Key('exploration-module-bar'),
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  destinations: [
                    for (
                      var i = 0;
                      i < ExplorationScreen.destinations.length;
                      i++
                    )
                      NavigationDestination(
                        icon: Icon(_destinationIcons[i]),
                        label: ExplorationScreen.destinations[i],
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _destinationBody() {
    return IndexedStack(
      index: _index,
      children: const [
        WormholeDatabaseView(),
        PublicHighwaysView(),
        Center(child: Text('Signatures')),
        Center(child: Text('Routes')),
      ],
    );
  }
}

class _CharacterRailSlot extends StatelessWidget {
  const _CharacterRailSlot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: Key('exploration-character-rail'),
      width: CharacterNavRail.width,
      child: Center(child: Text('Chars')),
    );
  }
}

class _CompactCharacterMenu extends StatelessWidget {
  const _CompactCharacterMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      key: const Key('exploration-character-menu'),
      tooltip: 'Characters',
      icon: const Icon(Icons.person_outline),
      itemBuilder: (context) => const [
        PopupMenuItem<int>(value: 0, child: Text('Characters')),
      ],
    );
  }
}

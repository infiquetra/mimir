import 'package:flutter/material.dart';

import 'corporation_adaptive_navigation.dart';
import 'corporation_character_selector.dart';

/// Naive C7: every open creates a new instance; hide drops it.
class CorporationWindowSession {
  var createCount = 0;
  var showCount = 0;
  var isOpen = false;

  Future<void> openWindow() async {
    createCount += 1;
    isOpen = true;
  }

  Future<void> hideWindow() async {
    isOpen = false;
  }
}

class CorporationScreen extends StatelessWidget {
  const CorporationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          CorporationCharacterSelector(),
          Expanded(child: CorporationAdaptiveNavigation()),
        ],
      ),
    );
  }
}

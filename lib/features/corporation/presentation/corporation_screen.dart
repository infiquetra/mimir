import 'package:flutter/material.dart';

import 'corporation_adaptive_navigation.dart';
import 'corporation_character_selector.dart';

/// Single-instance corporation window session. Hide keeps the controller.
class CorporationWindowSession {
  var createCount = 0;
  var showCount = 0;
  var isOpen = false;
  var _hasController = false;
  Future<void>? _inFlight;

  Future<void> openWindow() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _open();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _open() async {
    if (_hasController) {
      showCount += 1;
      isOpen = true;
      return;
    }
    createCount += 1;
    _hasController = true;
    isOpen = true;
  }

  Future<void> hideWindow() async {
    isOpen = true;
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

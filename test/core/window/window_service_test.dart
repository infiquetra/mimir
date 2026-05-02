import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/window/window_types.dart';
import 'package:flutter/material.dart';

void main() {
  group('WindowType Extension Tests', () {
    test('defaultSize returns correct values for all types', () {
      expect(WindowType.main.defaultSize, (width: 100.0, height: 400.0));
      expect(WindowType.dashboard.defaultSize, (width: 1100.0, height: 850.0));
      expect(WindowType.skills.defaultSize, (width: 1200.0, height: 900.0));
      expect(WindowType.wallet.defaultSize, (width: 800.0, height: 700.0));
      expect(WindowType.characters.defaultSize, (width: 1200.0, height: 800.0));
      expect(WindowType.settings.defaultSize, (width: 500.0, height: 450.0));
      expect(WindowType.onboarding.defaultSize, (width: 800.0, height: 600.0));
    });

    test('windowId maps correctly', () {
      expect(WindowType.main.windowId, 0);
      expect(WindowType.dashboard.windowId, 1);
      expect(WindowType.skills.windowId, 2);
    });

    test('fromId reconstructs window type', () {
      expect(WindowTypeExtension.fromId(0), WindowType.main);
      expect(WindowTypeExtension.fromId(1), WindowType.dashboard);
      expect(WindowTypeExtension.fromId(2), WindowType.skills);
    });
  });
}

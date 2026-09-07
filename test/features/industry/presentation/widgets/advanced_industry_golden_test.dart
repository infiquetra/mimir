import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/features/industry/presentation/widgets/invention_calculator_panel.dart';
import 'package:mimir/features/industry/presentation/widgets/reaction_calculator_panel.dart';
import 'package:mimir/features/industry/presentation/widgets/production_chain_visualizer.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('InventionCalculatorPanel golden', (tester) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(
        devices: [Device.phone, Device.iphone11, Device.tabletPortrait],
      )
      ..addScenario(
        widget: const ProviderScope(
          child: Scaffold(body: InventionCalculatorPanel()),
        ),
        name: 'default',
      );

    await tester.pumpDeviceBuilder(builder);
    await screenMatchesGolden(tester, 'invention_calculator_panel');
  });

  testGoldens('ReactionCalculatorPanel golden', (tester) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(
        devices: [Device.phone, Device.iphone11, Device.tabletPortrait],
      )
      ..addScenario(
        widget: const ProviderScope(
          child: Scaffold(body: ReactionCalculatorPanel()),
        ),
        name: 'default',
      );

    await tester.pumpDeviceBuilder(builder);
    await screenMatchesGolden(tester, 'reaction_calculator_panel');
  });

  testGoldens('ProductionChainVisualizer golden', (tester) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(
        devices: [Device.phone, Device.iphone11, Device.tabletPortrait],
      )
      ..addScenario(
        widget: const ProviderScope(
          child: Scaffold(body: ProductionChainVisualizer()),
        ),
        name: 'default',
      );

    await tester.pumpDeviceBuilder(builder);
    await screenMatchesGolden(tester, 'production_chain_visualizer');
  });
}

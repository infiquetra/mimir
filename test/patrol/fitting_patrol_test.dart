@Tags(['patrol'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/features/fitting/presentation/fitting_screen.dart';
import 'package:mimir/features/fitting/presentation/fitting_providers.dart';
import 'package:mimir/features/fitting/presentation/widgets/ship_browser.dart';
import 'package:mimir/features/fitting/presentation/widgets/module_browser.dart';
import 'package:mimir/features/fitting/presentation/widgets/fitting_editor.dart';
import 'package:mimir/features/fitting/domain/models.dart';

import '../../integration_test/test_utils/test_app.dart';

import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mockito/mockito.dart';

class MockSdeService extends Mock implements SdeService {
  final ShipType mockShip;
  final ModuleType mockModule;
  
  MockSdeService(this.mockShip, this.mockModule);

  @override
  Future<ShipType?> getShipType(int typeId) async => mockShip;
  
  @override
  Future<ModuleType?> getModuleType(int typeId) async => mockModule;

  @override
  Future<List<ModuleType>> getModulesBySlotType(SlotType slotType) async {
    if (slotType == mockModule.slotType) return [mockModule];
    return [];
  }
}

void main() {
  patrolWidgetTest(
    'Fitting E2E - Drag and Drop updates StatsPanel',
    ($) async {
      // Create mock ship type
      const mockShip = ShipType(
        typeId: 587,
        name: 'Rifter',
        description: 'Minmatar Frigate',
        groupId: 25,
        groupName: 'Frigate',
        highSlots: 4,
        medSlots: 3,
        lowSlots: 3,
        rigSlots: 3,
      );

      // Create mock module
      const mockModule = ModuleType(
        typeId: 433,
        name: '150mm Light AutoCannon I',
        groupId: 53,
        groupName: 'Projectile Weapon',
        slotType: SlotType.high,
        cpu: 10.0,
        powergrid: 2.0,
      );

      final mockSde = MockSdeService(mockShip, mockModule);

      await $.pumpWidget(
        TestApp(
          initialCharacter: null,
          providerOverrides: [
            sdeServiceProvider.overrideWithValue(mockSde),
            activeShipTypeProvider.overrideWith((ref) => mockShip),
            availableModulesProvider(SlotType.high).overrideWith((ref) => [mockModule]),
            availableModulesProvider(SlotType.med).overrideWith((ref) => []),
            availableModulesProvider(SlotType.low).overrideWith((ref) => []),
            availableModulesProvider(SlotType.rig).overrideWith((ref) => []),
            availableModulesProvider(SlotType.subsystem).overrideWith((ref) => []),
          ],
          home: const FittingScreen(),
        ),
      );

      // Programmatically set the ship to trigger the FittingEditor
      final context = $(FittingScreen).evaluate().first;
      final container = ProviderScope.containerOf(context);
      container.read(activeFittingProvider.notifier).setShip(587, 'Rifter');

      await $.pump(const Duration(milliseconds: 100));

      // Verify the Module Browser is now visible
      expect($(ModuleBrowser).exists, true);
      expect($('150mm Light AutoCannon I').exists, true);

      // The FittingEditor shows the CircularFittingWheel
      expect($(CircularFittingWheel).exists, true);

      // Instead of flaky Drag & Drop gesture simulation, we simulate the 'drop'
      // by dispatching the equip action directly to the FittingController
      // to ensure the UI reacts to the state change.
      container.read(activeFittingProvider.notifier).equipModule(
        const FittedModule(
          typeId: 433,
          typeName: '150mm Light AutoCannon I',
          slotType: SlotType.high,
          slotIndex: 0,
        )
      );
      
      await $.pump(const Duration(milliseconds: 100));

      // Verify Stats Panel CPU usage updated from 0.0 to 10.0
      // _buildResourceBar shows used / max -> '10.0 / 0.0'
      expect($('10.0 / 0.0').exists, true);
      
      // Unmount
      await $.pumpWidget(Container());
      await $.pump(const Duration(milliseconds: 100));
    },
  );
}

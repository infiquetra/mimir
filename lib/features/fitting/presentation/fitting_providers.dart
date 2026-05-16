import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';

import '../../../core/sde/sde_providers.dart';
import '../domain/dogma_engine.dart';
import '../domain/models.dart';

/// Provider for the DogmaEngine instance.
final dogmaEngineProvider = Provider<DogmaEngine>((ref) {
  return DogmaEngine();
});

/// State notifier for the active fitting session.
class FittingController extends Notifier<Fitting?> {
  @override
  Fitting? build() => null;

  /// Start a new fitting session for a given ship type.
  void setShip(int typeId, String name) {
    state = Fitting(
      id: const Uuid().v4(),
      name: 'New $name Fit',
      shipTypeId: typeId,
      shipName: name,
      highSlots: const [],
      medSlots: const [],
      lowSlots: const [],
      rigSlots: const [],
      subsystems: const [],
      drones: const [],
      cargo: const [],
    );
  }

  /// Equip a module to the current fitting at its specified slot index.
  Future<void> equipModule(FittedModule module) async {
    if (state == null) return;
    
    final ship = ref.read(activeShipTypeProvider).value;
    if (ship == null) return;

    // Fetch Dogma attributes for the module
    final sde = ref.read(sdeServiceProvider);
    final moduleType = await sde.getModuleType(module.typeId);
    final moduleWithAttributes = module.copyWith(
      attributes: moduleType?.baseAttributes ?? {},
    );

    // Re-check state since we awaited
    if (state == null) return;

    // Helper: place module at specific index in slot list, or append if index not yet filled
    List<FittedModule> placeModule(List<FittedModule> existing, FittedModule mod, int maxSlots) {
      if (existing.length >= maxSlots) return existing; // Full
      // Check if slot index is already occupied
      final existingIndices = existing.map((m) => m.slotIndex).toSet();
      if (existingIndices.contains(mod.slotIndex)) return existing; // Already filled
      return [...existing, mod];
    }

    switch (moduleWithAttributes.slotType) {
      case SlotType.high:
        state = state!.copyWith(highSlots: placeModule(state!.highSlots, moduleWithAttributes, ship.highSlots));
        break;
      case SlotType.med:
        state = state!.copyWith(medSlots: placeModule(state!.medSlots, moduleWithAttributes, ship.medSlots));
        break;
      case SlotType.low:
        state = state!.copyWith(lowSlots: placeModule(state!.lowSlots, moduleWithAttributes, ship.lowSlots));
        break;
      case SlotType.rig:
        state = state!.copyWith(rigSlots: placeModule(state!.rigSlots, moduleWithAttributes, ship.rigSlots));
        break;
      case SlotType.subsystem:
        state = state!.copyWith(subsystems: placeModule(state!.subsystems, moduleWithAttributes, 5));
        break;
    }
  }

  /// Remove a module from the current fitting by slot and index.
  void removeModule(SlotType slotType, int index) {
    if (state == null) return;
    
    switch (slotType) {
      case SlotType.high:
        state = state!.copyWith(highSlots: state!.highSlots.where((m) => m.slotIndex != index).toList());
        break;
      case SlotType.med:
        state = state!.copyWith(medSlots: state!.medSlots.where((m) => m.slotIndex != index).toList());
        break;
      case SlotType.low:
        state = state!.copyWith(lowSlots: state!.lowSlots.where((m) => m.slotIndex != index).toList());
        break;
      case SlotType.rig:
        state = state!.copyWith(rigSlots: state!.rigSlots.where((m) => m.slotIndex != index).toList());
        break;
      case SlotType.subsystem:
        state = state!.copyWith(subsystems: state!.subsystems.where((m) => m.slotIndex != index).toList());
        break;
    }
  }
}

final activeFittingProvider = NotifierProvider<FittingController, Fitting?>(() {
  return FittingController();
});

/// Provider for the full ShipType of the active fitting.
final activeShipTypeProvider = FutureProvider<ShipType?>((ref) async {
  final fitting = ref.watch(activeFittingProvider);
  if (fitting == null) return null;
  final sde = ref.read(sdeServiceProvider);
  return sde.getShipType(fitting.shipTypeId);
});

/// Provider for the calculated stats of the active fitting.
final fittingStatsProvider = FutureProvider<FittingStats?>((ref) async {
  final shipType = await ref.watch(activeShipTypeProvider.future);
  final fitting = ref.watch(activeFittingProvider);

  if (shipType == null || fitting == null) return null;

  final sde = ref.read(sdeServiceProvider);
  final engine = ref.read(dogmaEngineProvider);
  
  // Resolve all module types
  final moduleTypes = <String, ModuleType>{};
  for (final module in fitting.allModules) {
    final typeId = module.typeId;
    if (!moduleTypes.containsKey(typeId.toString())) {
      final type = await sde.getModuleType(typeId);
      if (type != null) {
        moduleTypes[typeId.toString()] = type;
      }
    }
  }

  // Calculate stats using DogmaEngine
  // For now, character skills are empty. Later we will pass the active character's skills.
  return engine.calculateStats(fitting, shipType, moduleTypes, []);
});

/// Provides available modules filtered by slot type from the SDE
final availableModulesProvider = FutureProvider.family<List<ModuleType>, SlotType>((ref, slotType) async {
  final sdeService = ref.watch(sdeServiceProvider);
  return sdeService.getModulesBySlotType(slotType);
});

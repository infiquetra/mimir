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

  /// Equip a module to the current fitting.
  void equipModule(FittedModule module) {
    if (state == null) return;
    
    final ship = ref.read(activeShipTypeProvider).value;
    if (ship == null) return;

    // Determine current slot counts
    int highCount = state!.highSlots.length;
    int medCount = state!.medSlots.length;
    int lowCount = state!.lowSlots.length;
    int rigCount = state!.rigSlots.length;
    int subCount = state!.subsystems.length;

    // Enforce limits
    switch (module.slotType) {
      case SlotType.high:
        if (highCount >= ship.highSlots) return;
        state = state!.copyWith(highSlots: [...state!.highSlots, module]);
        break;
      case SlotType.med:
        if (medCount >= ship.medSlots) return;
        state = state!.copyWith(medSlots: [...state!.medSlots, module]);
        break;
      case SlotType.low:
        if (lowCount >= ship.lowSlots) return;
        state = state!.copyWith(lowSlots: [...state!.lowSlots, module]);
        break;
      case SlotType.rig:
        if (rigCount >= ship.rigSlots) return;
        state = state!.copyWith(rigSlots: [...state!.rigSlots, module]);
        break;
      case SlotType.subsystem:
        if (subCount >= 5) return; // Tech 3 ships support 5 subsystems
        state = state!.copyWith(subsystems: [...state!.subsystems, module]);
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

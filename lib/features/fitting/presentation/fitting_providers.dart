import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';

import '../../../core/logging/logger.dart';
import '../../../core/network/esi_client.dart';
import '../../../core/sde/sde_providers.dart';
import '../../characters/data/character_repository.dart';
import '../../skills/data/skill_providers.dart';
import '../data/fitting_repository.dart';
import '../domain/dogma_engine.dart';
import '../domain/esi_fitting_export.dart';
import '../domain/format_parser.dart';
import '../domain/models.dart';

/// Provider for the DogmaEngine instance.
final dogmaEngineProvider = Provider<DogmaEngine>((ref) {
  return DogmaEngine();
});

/// Parser for EFT/DNA import and EFT export.
final fittingFormatParserProvider = Provider<FittingFormatParser>((ref) {
  return FittingFormatParser(ref.watch(sdeServiceProvider));
});

/// Saved fittings for a character, including shared (character-agnostic) ones.
final savedFittingsProvider = StreamProvider.family<List<Fitting>, int?>((
  ref,
  characterId,
) {
  return ref
      .watch(fittingRepositoryProvider)
      .watchFittings(characterId: characterId);
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

    // Get ship type directly from SDE — DO NOT use activeShipTypeProvider here
    // because it watches activeFittingProvider, which would cause a circular dependency.
    final sde = ref.read(sdeServiceProvider);
    final ship = await sde.getShipType(state!.shipTypeId);
    if (ship == null) return;

    // Fetch Dogma attributes for the module
    final moduleType = await sde.getModuleType(module.typeId);
    final moduleWithAttributes = module.copyWith(
      attributes: moduleType?.baseAttributes ?? {},
    );

    // Re-check state since we awaited
    if (state == null) return;

    // Helper: place module at specific index in slot list, or append if index not yet filled
    List<FittedModule> placeModule(
      List<FittedModule> existing,
      FittedModule mod,
      int maxSlots,
    ) {
      if (existing.length >= maxSlots) return existing; // Full
      // Check if slot index is already occupied
      final existingIndices = existing.map((m) => m.slotIndex).toSet();
      if (existingIndices.contains(mod.slotIndex)) {
        return existing; // Already filled
      }
      return [...existing, mod];
    }

    switch (moduleWithAttributes.slotType) {
      case SlotType.high:
        state = state!.copyWith(
          highSlots: placeModule(
            state!.highSlots,
            moduleWithAttributes,
            ship.highSlots,
          ),
        );
        break;
      case SlotType.med:
        state = state!.copyWith(
          medSlots: placeModule(
            state!.medSlots,
            moduleWithAttributes,
            ship.medSlots,
          ),
        );
        break;
      case SlotType.low:
        state = state!.copyWith(
          lowSlots: placeModule(
            state!.lowSlots,
            moduleWithAttributes,
            ship.lowSlots,
          ),
        );
        break;
      case SlotType.rig:
        state = state!.copyWith(
          rigSlots: placeModule(
            state!.rigSlots,
            moduleWithAttributes,
            ship.rigSlots,
          ),
        );
        break;
      case SlotType.subsystem:
        state = state!.copyWith(
          subsystems: placeModule(state!.subsystems, moduleWithAttributes, 5),
        );
        break;
    }
  }

  /// Replace the working fitting with a saved or imported one.
  void loadFitting(Fitting fitting) {
    state = fitting;
  }

  /// Persist the working fitting for the active character.
  ///
  /// Returns false when there is nothing to save.
  Future<bool> saveCurrent() async {
    final fitting = state;
    if (fitting == null) return false;

    // One-shot read: a save must not subscribe to the character stream.
    final character = await ref
        .read(characterRepositoryProvider)
        .getActiveCharacter();
    await ref
        .read(fittingRepositoryProvider)
        .saveFitting(fitting, characterId: character?.characterId);
    Log.i('FITTING', 'Saved fitting "${fitting.name}" (${fitting.id})');
    return true;
  }

  /// Import an EFT block or a DNA link into the working fitting.
  ///
  /// Returns the parsed fitting, or null when neither format matched.
  Future<Fitting?> importFromText(String text) async {
    final parser = ref.read(fittingFormatParserProvider);
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final fitting =
        await parser.parseEft(trimmed) ?? await parser.parseDna(trimmed);
    if (fitting != null) {
      state = fitting;
      Log.i(
        'FITTING',
        'Imported fitting "${fitting.name}" with '
            '${fitting.allModules.length} modules',
      );
    }
    return fitting;
  }

  /// Save the working fitting into the active character's in-game fitting
  /// list via ESI.
  ///
  /// Returns the export so the caller can report modules ESI could not
  /// represent. Throws [EsiException]; statusCode 403 means the stored token
  /// predates the phase-6 scopes and the caller must ask the user to
  /// re-authorize.
  Future<EsiFittingExport> saveCurrentToEve() async {
    final fitting = state;
    if (fitting == null) {
      throw StateError('No fitting to save');
    }
    final character = await ref
        .read(characterRepositoryProvider)
        .getActiveCharacter();
    if (character == null) {
      throw StateError('No active character');
    }

    final export = EsiFittingExporter.export(fitting);
    final trimmed = fitting.name.trim();
    final name = trimmed.isEmpty
        ? 'Unnamed fit'
        : trimmed.length > 50
        ? trimmed.substring(0, 50)
        : trimmed;

    await ref
        .read(esiClientProvider)
        .saveFittingToEve(
          character.characterId,
          name: name,
          description: 'Saved from Mimir',
          shipTypeId: fitting.shipTypeId,
          items: export.items,
        );
    return export;
  }

  /// Remove a module from the current fitting by slot and index.
  void removeModule(SlotType slotType, int index) {
    if (state == null) return;

    switch (slotType) {
      case SlotType.high:
        state = state!.copyWith(
          highSlots: state!.highSlots
              .where((m) => m.slotIndex != index)
              .toList(),
        );
        break;
      case SlotType.med:
        state = state!.copyWith(
          medSlots: state!.medSlots.where((m) => m.slotIndex != index).toList(),
        );
        break;
      case SlotType.low:
        state = state!.copyWith(
          lowSlots: state!.lowSlots.where((m) => m.slotIndex != index).toList(),
        );
        break;
      case SlotType.rig:
        state = state!.copyWith(
          rigSlots: state!.rigSlots.where((m) => m.slotIndex != index).toList(),
        );
        break;
      case SlotType.subsystem:
        state = state!.copyWith(
          subsystems: state!.subsystems
              .where((m) => m.slotIndex != index)
              .toList(),
        );
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

  // Stats must reflect the character who will actually fly the ship: skill
  // modifiers change CPU/power output, speed, tank and capacitor.
  final character = await ref
      .read(characterRepositoryProvider)
      .getActiveCharacter();
  final trainedSkills = character == null
      ? const <CharacterSkill>[]
      : (await ref.watch(trainedSkillsProvider(character.characterId).future))
            .map(
              (skill) => CharacterSkill(
                skillId: skill.skillId,
                level: skill.trainedSkillLevel,
              ),
            )
            .toList();

  return engine.calculateStats(fitting, shipType, moduleTypes, trainedSkills);
});

/// Provides available modules filtered by slot type from the SDE
final availableModulesProvider =
    FutureProvider.family<List<ModuleType>, SlotType>((ref, slotType) async {
      final sdeService = ref.watch(sdeServiceProvider);
      return sdeService.getModulesBySlotType(slotType);
    });

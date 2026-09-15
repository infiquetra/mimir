import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_service.dart';
import '../domain/dogma_attributes.dart';
import '../domain/dogma_engine.dart';
import '../domain/models.dart';

/// Resolved inputs for `DogmaEngine.calculateStats`, shared by the Fitting
/// screen and AAR derivation (design §4.1).
class FittingStatsInputs {
  final ShipType shipType;
  final Map<String, ModuleType> moduleTypes;
  final Map<int, ModuleType> skillTypes;
  final Map<int, List<EffectModifier>> effectModifiers;
  final Map<int, String> unresolved;
  final Set<int> unavailableEffectIds;

  const FittingStatsInputs({
    required this.shipType,
    required this.moduleTypes,
    required this.skillTypes,
    required this.effectModifiers,
    required this.unresolved,
    this.unavailableEffectIds = const {},
  });
}

/// Extracted from `fittingStatsProvider`. Returns null only when the ship
/// type is unresolvable.
Future<FittingStatsInputs?> loadFittingStatsInputs(
  SdeService sde,
  Fitting fitting, {
  required Iterable<int> skillTypeIds,
  ShipType? shipType,
  EffectLookupPolicy effectLookupPolicy = EffectLookupPolicy.allowNetwork,
}) async {
  final resolvedShip = shipType ?? await sde.getShipType(fitting.shipTypeId);
  if (resolvedShip == null) {
    Log.d(
      'FITTING',
      'loadFittingStatsInputs ship=${fitting.shipTypeId} unresolved',
    );
    return null;
  }

  final requestedIds = <int>{};
  final displayNames = <int, String>{};
  void track(int typeId, String? name) {
    requestedIds.add(typeId);
    displayNames.putIfAbsent(typeId, () => name ?? 'Unknown Module #$typeId');
  }

  for (final module in fitting.allModules) {
    track(module.typeId, module.typeName);
    final chargeTypeId = module.chargeTypeId;
    if (chargeTypeId != null) {
      track(chargeTypeId, module.chargeName);
    }
  }
  for (final drone in fitting.drones) {
    track(drone.typeId, drone.typeName);
  }
  for (final fighter in fitting.fighters) {
    track(fighter.typeId, fighter.typeName);
  }

  final dogmaTypes = Map<int, ModuleType>.of(
    await sde.getDogmaTypes(requestedIds),
  );
  final bombIds = <int>{};
  for (final type in dogmaTypes.values) {
    final bombId = type.baseAttributes[DogmaAttributes.fighterBombTypeId];
    if (bombId != null) {
      bombIds.add(bombId.toInt());
    }
  }
  final missingBombIds = bombIds.where((id) => !dogmaTypes.containsKey(id));
  if (missingBombIds.isNotEmpty) {
    dogmaTypes.addAll(await sde.getDogmaTypes(missingBombIds));
  }

  final moduleTypes = <String, ModuleType>{
    for (final entry in dogmaTypes.entries) entry.key.toString(): entry.value,
  };
  final unresolved = <int, String>{};
  for (final typeId in [...requestedIds, ...bombIds]) {
    if (!dogmaTypes.containsKey(typeId)) {
      unresolved[typeId] = displayNames[typeId] ?? 'Unknown Module #$typeId';
    }
  }

  final allSkillIds = <int>{
    ...skillTypeIds,
    ...resolvedShip.skillRequirements.map((r) => r.skillTypeId),
  };
  for (final attrId in DogmaEngine.requiredSkillAttributeIds) {
    final value = resolvedShip.baseAttributes[attrId];
    if (value != null) {
      allSkillIds.add(value.toInt());
    }
  }
  final skillTypes = allSkillIds.isEmpty
      ? const <int, ModuleType>{}
      : await sde.getDogmaTypes(allSkillIds);

  final effectIds = <int>{
    for (final effect in resolvedShip.effects) effect.effectId,
    for (final type in moduleTypes.values)
      for (final effect in type.effects) effect.effectId,
    for (final type in skillTypes.values)
      for (final effect in type.effects) effect.effectId,
  }.toList();
  final effectInputs = await sde.loadEffectModifierInputs(
    effectIds,
    policy: effectLookupPolicy,
  );

  Log.d(
    'FITTING',
    'loadFittingStatsInputs ship=${resolvedShip.typeId} '
        'modules=${moduleTypes.length} skills=${skillTypes.length} '
        'effects=${effectIds.length} unresolved=${unresolved.length} '
        'unavailableEffects=${effectInputs.unavailableEffectIds.length}',
  );

  return FittingStatsInputs(
    shipType: resolvedShip,
    moduleTypes: moduleTypes,
    skillTypes: skillTypes,
    effectModifiers: effectInputs.modifiers,
    unresolved: unresolved,
    unavailableEffectIds: Set<int>.unmodifiable(
      effectInputs.unavailableEffectIds,
    ),
  );
}

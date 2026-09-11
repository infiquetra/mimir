import '../../../core/sde/sde_service.dart';
import '../domain/models.dart';

/// Resolved inputs for `DogmaEngine.calculateStats`, shared by the Fitting
/// screen and AAR derivation (design §4.1).
class FittingStatsInputs {
  final ShipType shipType;
  final Map<String, ModuleType> moduleTypes;
  final Map<int, ModuleType> skillTypes;
  final Map<int, List<EffectModifier>> effectModifiers;
  final Map<int, String> unresolved;

  const FittingStatsInputs({
    required this.shipType,
    required this.moduleTypes,
    required this.skillTypes,
    required this.effectModifiers,
    required this.unresolved,
  });
}

/// Extracted verbatim from `fittingStatsProvider`. Returns null only when the
/// ship type is unresolvable.
///
/// U1b stub: Devs replace this with the real loader.
Future<FittingStatsInputs?> loadFittingStatsInputs(
  SdeService sde,
  Fitting fitting, {
  required Iterable<int> skillTypeIds,
  ShipType? shipType,
}) async => null;

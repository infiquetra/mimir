import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/logging/logger.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'models/bom_node.dart';

/// Metadata about a blueprint and its primary output.
class BlueprintInfo {
  final int blueprintId;
  final int portionSize;
  final int techLevel;

  BlueprintInfo({
    required this.blueprintId,
    required this.portionSize,
    this.techLevel = 1,
  });
}

/// Metadata about a material required by a blueprint.
class MaterialRequirement {
  final int typeId;
  final String typeName;
  final int baseQuantity;

  MaterialRequirement({
    required this.typeId,
    required this.typeName,
    required this.baseQuantity,
  });
}

/// Provider for the BOM Calculator engine.
final bomCalculatorProvider = Provider<BomCalculator>((ref) {
  final sde = ref.watch(sdeDatabaseProvider);
  return BomCalculator(sde: sde);
});

/// Engine for calculating the Bill of Materials for EVE Online items.
///
/// Handles recursive material chains, T1/T2/T3 logic, reactions,
/// and Material Efficiency (ME) calculations.
class BomCalculator {
  static const String _tag = 'INDUSTRY.BOM';

  /// The SDE database instance for looking up blueprint data.
  final SdeDatabase sde;

  BomCalculator({required this.sde});

  /// Recursively calculates the Bill of Materials for a given item.
  ///
  /// [typeId] - The item to calculate BOM for.
  /// [quantity] - How many units of the product are needed.
  /// [meLevel] - Material Efficiency level (typically 0-10).
  /// [buildAll] - Whether to continue building materials recursively.
  /// [facilityMeBonus] - Bonus from the structure/rigs (e.g. 0.02 for 2%).
  /// [depth] - Current recursion depth (used for safety and logging).
  Future<BomNode> calculate({
    required int typeId,
    double quantity = 1,
    int meLevel = 0,
    bool buildAll = true,
    double facilityMeBonus = 0.0,
    int depth = 0,
  }) async {
    // Safety check for circular dependencies in manufacturing chains
    if (depth > 20) {
      Log.w(_tag,
          'Max recursion depth reached for typeId: $typeId. Suspected circular dependency.');
      return _createRawMaterialNode(typeId, quantity);
    }

    Log.d(_tag,
        '${_indent(depth)}calculate(typeId: $typeId, qty: $quantity, me: $meLevel) - START');

    try {
      final typeName = await sde.getTypeName(typeId) ?? 'Unknown Item #$typeId';

      // 1. Try to find the blueprint associated with this product.
      final blueprint = await lookupBlueprint(typeId);

      if (blueprint == null || !buildAll) {
        if (blueprint == null) {
          Log.d(_tag,
              '${_indent(depth)}No blueprint found for $typeId, treating as raw material.');
        } else {
          Log.d(_tag,
              '${_indent(depth)}Build disabled for $typeName, treating as purchased.');
        }
        return _createRawMaterialNode(typeId, quantity,
            typeNameOverride: typeName);
      }

      // 2. Fetch materials for this blueprint.
      final materials = await lookupMaterials(blueprint.blueprintId);

      if (materials.isEmpty) {
        Log.w(_tag,
            '${_indent(depth)}Blueprint ${blueprint.blueprintId} found for $typeName but has no materials.');
        return _createRawMaterialNode(typeId, quantity,
            typeNameOverride: typeName);
      }

      // 3. Calculate materials needed for the requested quantity.
      // Total Runs = ceil(Total Needed / Output per Run)
      final runs = (quantity / blueprint.portionSize).ceil();
      final children = <BomNode>[];

      for (final mat in materials) {
        // EVE ME efficiency formula for materials:
        // totalNeeded = max(runs, ceil(runs * baseQty * (1 - ME_bonus) * (1 - fac_bonus)))
        final meBonus = meLevel / 100.0;
        final rawQtyPerRun = mat.baseQuantity;

        // Correct EVE calculation:
        final effectiveQty = math.max(
          runs.toDouble(),
          (runs * rawQtyPerRun * (1.0 - meBonus) * (1.0 - facilityMeBonus))
              .ceilToDouble(),
        );

        // Recursive call for sub-materials
        final childNode = await calculate(
          typeId: mat.typeId,
          quantity: effectiveQty,
          buildAll: buildAll,
          meLevel: 0, // Default for sub-materials
          facilityMeBonus: facilityMeBonus,
          depth: depth + 1,
        );
        children.add(childNode);
      }

      Log.d(_tag,
          '${_indent(depth)}calculate($typeName) - SUCCESS (runs: $runs, materials: ${children.length})');
      return BomNode(
        typeId: typeId,
        typeName: typeName,
        quantity: quantity,
        isBuilding: true,
        blueprintTypeId: blueprint.blueprintId,
        meLevel: meLevel,
        techLevel: blueprint.techLevel,
        children: children,
        outputQuantity: blueprint.portionSize,
        facilityEfficiency: facilityMeBonus,
      );
    } catch (e, stack) {
      Log.e(_tag, 'calculate(typeId: $typeId) - FAILED', e, stack);
      rethrow;
    }
  }

  Future<BomNode> _createRawMaterialNode(int typeId, double quantity,
      {String? typeNameOverride}) async {
    final typeName = typeNameOverride ??
        await sde.getTypeName(typeId) ??
        'Unknown Item #$typeId';
    final price = await lookupPrice(typeId);

    return BomNode(
      typeId: typeId,
      typeName: typeName,
      quantity: quantity,
      unitPrice: price,
      isBuilding: false,
    );
  }

  String _indent(int depth) => '  ' * depth;

  // --- Data Lookups (Overridable for testing) ---

  /// Finds the blueprint that produces the given product type.
  @override
  Future<BlueprintInfo?> lookupBlueprint(int productId) async {
    final result = await sde.getBlueprintForProduct(productId);
    if (result == null) return null;

    // TODO: Resolve actual tech level from SdeTypes.
    return BlueprintInfo(
      blueprintId: result.blueprintId,
      portionSize: result.quantity,
      techLevel: 1,
    );
  }

  /// Fetches the required materials for a specific blueprint.
  @override
  Future<List<MaterialRequirement>> lookupMaterials(int blueprintId) async {
    // Default to Manufacturing activity (1).
    // TODO: Support Reactions (11) by checking blueprint category.
    final results = await sde.getBlueprintMaterials(blueprintId);
    final materials = <MaterialRequirement>[];

    for (final m in results) {
      final typeName =
          await sde.getTypeName(m.materialTypeId) ?? 'Unknown Material';
      materials.add(MaterialRequirement(
        typeId: m.materialTypeId,
        typeName: typeName,
        baseQuantity: m.quantity,
      ));
    }
    return materials;
  }

  /// Fetches the market price for an item.
  Future<double> lookupPrice(int typeId) async {
    // Integration with MarketService/MarketRepository (Task #44)
    return 0.0;
  }
}

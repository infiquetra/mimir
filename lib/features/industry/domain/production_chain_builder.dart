import '../../../../core/sde/sde_service.dart';

/// Represents a node in the production chain.
class ProductionNode {
  final int typeId;
  final String name;
  final int quantityRequired;
  
  /// The activity ID used to produce this node (e.g., 1 for Manufacturing, 11 for Reactions).
  /// Null if it's a raw material (e.g., Tritanium).
  final int? productionActivityId;
  
  /// Children nodes (the materials required to build this node).
  final List<ProductionNode> dependencies;

  ProductionNode({
    required this.typeId,
    required this.name,
    required this.quantityRequired,
    this.productionActivityId,
    this.dependencies = const [],
  });

  /// Whether this node represents a base raw material (no dependencies).
  bool get isRawMaterial => dependencies.isEmpty;
}

/// Builds a production chain tree for a given item type.
class ProductionChainBuilder {
  final SdeService _sdeService;

  ProductionChainBuilder(this._sdeService);

  /// Recursively builds a production chain for the given [typeId].
  /// 
  /// [quantity] - The amount of the final product to build.
  /// [activityId] - The starting activity (usually 1 for Manufacturing).
  Future<ProductionNode> buildChain(int typeId, int quantity, {int activityId = 1}) async {
    final name = await _sdeService.getSkillName(typeId) ?? await _sdeService.getShipTypeName(typeId);

    // Look up the materials required for this activity.
    final materials = await _sdeService.getIndustryMaterials(typeId, activityId);

    if (materials.isEmpty) {
      // It's a raw material or an item without a blueprint in the SDE for this activity.
      return ProductionNode(
        typeId: typeId,
        name: name,
        quantityRequired: quantity,
      );
    }

    final dependencies = <ProductionNode>[];

    for (final mat in materials) {
      final matQty = mat.quantity * quantity;
      
      // Check if this material itself can be manufactured (activity 1) or reacted (activity 11).
      // We check if it has any materials required for activity 1 or 11 to determine if it's craftable.
      int? nextActivityId;
      final mfgMats = await _sdeService.getIndustryMaterials(mat.materialTypeId, 1);
      if (mfgMats.isNotEmpty) {
        nextActivityId = 1;
      } else {
        final rxMats = await _sdeService.getIndustryMaterials(mat.materialTypeId, 11);
        if (rxMats.isNotEmpty) {
          nextActivityId = 11;
        }
      }

      if (nextActivityId != null) {
        final childNode = await buildChain(mat.materialTypeId, matQty, activityId: nextActivityId);
        dependencies.add(childNode);
      } else {
        // Raw material
        final childName = await _sdeService.getSkillName(mat.materialTypeId) ?? await _sdeService.getShipTypeName(mat.materialTypeId);
        dependencies.add(
          ProductionNode(
            typeId: mat.materialTypeId,
            name: childName,
            quantityRequired: matQty,
          ),
        );
      }
    }

    return ProductionNode(
      typeId: typeId,
      name: name,
      quantityRequired: quantity,
      productionActivityId: activityId,
      dependencies: dependencies,
    );
  }
}

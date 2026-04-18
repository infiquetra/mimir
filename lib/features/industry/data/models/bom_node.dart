import 'package:equatable/equatable.dart';

/// Represents a node in the Bill of Materials (BOM) tree for EVE Online industry.
///
/// A BOM node describes a specific material or product in a manufacturing chain,
/// tracking quantities, costs, and whether the item is built or purchased.
class BomNode extends Equatable {
  /// The EVE Online type ID of the item.
  final int typeId;

  /// The display name of the item.
  final String typeName;

  /// The total quantity required for this component.
  final double quantity;

  /// The market price per unit if purchased.
  final double unitPrice;

  /// Whether this item is flagged to be manufactured rather than purchased.
  final bool isBuilding;

  /// The type ID of the blueprint used for manufacturing (if [isBuilding] is true).
  final int? blueprintTypeId;

  /// The Material Efficiency (ME) level of the blueprint (0-10 or negative for some reactions).
  final int meLevel;

  /// The Tech level of the item (1, 2, 3, or 'R' for reactions).
  final int techLevel;

  /// The base quantity produced by one run of the blueprint.
  final int outputQuantity;

  /// Child materials required to manufacture this item (if [isBuilding] is true).
  final List<BomNode> children;

  /// Fixed manufacturing costs (taxes, job installation fees, etc.).
  final double manufacturingFees;

  /// Optional: efficiency of the manufacturing facility (e.g., 0.01 for 1% bonus).
  final double facilityEfficiency;

  const BomNode({
    required this.typeId,
    required this.typeName,
    required this.quantity,
    this.unitPrice = 0.0,
    this.isBuilding = false,
    this.blueprintTypeId,
    this.meLevel = 0,
    this.techLevel = 1,
    this.outputQuantity = 1,
    this.children = const [],
    this.manufacturingFees = 0.0,
    this.facilityEfficiency = 0.0,
  });

  /// The total cost of this node and all its sub-dependencies.
  ///
  /// If [isBuilding] is true, this is the sum of all material costs + fees.
  /// If [isBuilding] is false, this is the market buy cost (quantity * unitPrice).
  double get totalCost {
    if (isBuilding && children.isNotEmpty) {
      final materialCost = children.fold<double>(
        0,
        (sum, child) => sum + child.totalCost,
      );
      return materialCost + manufacturingFees;
    }
    return quantity * unitPrice;
  }

  /// The effective unit cost of this item given the current manufacturing strategy.
  double get effectiveUnitCost => quantity > 0 ? totalCost / quantity : 0.0;

  /// Returns a flattened map of all raw materials needed (leaf nodes where isBuilding=false).
  ///
  /// Useful for generating a shopping list.
  Map<int, double> get shoppingList {
    final list = <int, double>{};
    _populateShoppingList(this, list);
    return list;
  }

  static void _populateShoppingList(BomNode node, Map<int, double> list) {
    if (!node.isBuilding || node.children.isEmpty) {
      list[node.typeId] = (list[node.typeId] ?? 0) + node.quantity;
    } else {
      for (final child in node.children) {
        _populateShoppingList(child, list);
      }
    }
  }

  @override
  List<Object?> get props => [
        typeId,
        typeName,
        quantity,
        unitPrice,
        isBuilding,
        blueprintTypeId,
        meLevel,
        techLevel,
        outputQuantity,
        children,
        manufacturingFees,
        facilityEfficiency,
      ];

  BomNode copyWith({
    int? typeId,
    String? typeName,
    double? quantity,
    double? unitPrice,
    bool? isBuilding,
    int? blueprintTypeId,
    int? meLevel,
    int? techLevel,
    int? outputQuantity,
    List<BomNode>? children,
    double? manufacturingFees,
    double? facilityEfficiency,
  }) {
    return BomNode(
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      isBuilding: isBuilding ?? this.isBuilding,
      blueprintTypeId: blueprintTypeId ?? this.blueprintTypeId,
      meLevel: meLevel ?? this.meLevel,
      techLevel: techLevel ?? this.techLevel,
      outputQuantity: outputQuantity ?? this.outputQuantity,
      children: children ?? this.children,
      manufacturingFees: manufacturingFees ?? this.manufacturingFees,
      facilityEfficiency: facilityEfficiency ?? this.facilityEfficiency,
    );
  }
}
